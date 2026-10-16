struct Mem {
    // the order of the memory accesses (dmb): barrier = all, barrier_read = loads before, barrier_write = stores before, barrier_full = dsb
    static void barrier() { __mem_barrier(); }
    static void barrier_read() { __mem_barrier_read(); }
    static void barrier_write() { __mem_barrier_write(); }
    static void barrier_full() { __mem_barrier_full(); }
    // the size class of a block of `need` bytes (header included, a multiple of 16): the smallest class that is big enough, or -1 if the
    // block is bigger than the biggest class
    static int class_of(int need) {
        return std_cls_of[need / 16];
    }
    // the class whose size is exactly `size`, or -1
    static int exact_class(int size) {
        if size > 2048 { return 0 - 1; }
        return std_cls_exact[size / 16];
    }
    // n bytes, not cleared (null if the system has no memory left)
    // The common case is written out here (one thread, a small block that a free list has): no other function is called.
    static void^ alloc(int n) {
        if std_debug == 0 && std_mt == 0 && n > 0 && n <= 2032 {
            int need = ((n + 15) >> 4) * 16 + 16;
            int c = std_cls_of[need >> 4];
            int h = std_free_cls[c];
            if h != 0 {
                int^ hd = (int^)h;
                std_free_cls[c] = hd[1];
                hd[1] = 0;
                std_alloc_n += 1;
                return (void^)(h + 16);
            }
        }
        return Mem::alloc_general(n);
    }
    static void^ alloc_general(int n) {
        if std_debug != 0 { return Mem::dbg_alloc(n); }
        if std_mt == 0 { return Mem::alloc_raw(n); }          // one thread only: no lock
        while __cas(@std_mem_lock, 0, 1) != 0 {
            syscall(124);                  // sched_yield: let the thread that holds the heap finish
        }
        void^ r = Mem::alloc_raw(n);
        __xchg(@std_mem_lock, 0);
        return r;
    }
    // the next `need` bytes of the chunk that is in use (a new chunk from the system when it is full)
    static int bump(int need) {
        if std_heap_cur + need > std_heap_end {
            int chunk = 1048576;
            if need > chunk { chunk = (need + 4095) / 4096 * 4096; }
            int base = syscall(222, 0, chunk, 3, 34, -1, 0);      // mmap: anonymous, read + write
            if base < 0 { return 0; }
            std_heap_cur = base;
            std_heap_end = base + chunk;
        }
        int blk = std_heap_cur;
        std_heap_cur = std_heap_cur + need;
        return blk;
    }
    // Small blocks (up to 2048 bytes with the header) have size classes: a list of free blocks for each size, so that alloc and free
    // take a few instructions. Bigger blocks are on one list, ordered by address: first fit, a block is split when the rest is at
    // least 64 bytes, and a freed block is joined with the free blocks next to it.
    static void^ alloc_raw(int n) {
        if n <= 0 { return null; }
        int need = ((n + 15) >> 4) * 16 + 16;
        if need > 2048 { return Mem::alloc_big(need); }
        int c = std_cls_of[need >> 4];
        int h = std_free_cls[c];
        if h != 0 {
            int^ hd = (int^)h;
            std_free_cls[c] = hd[1];
            hd[1] = 0;
            std_alloc_n += 1;
            return (void^)(h + 16);
        }
        return Mem::alloc_new(std_cls[c]);
    }
    // a new small block from the chunk
    static void^ alloc_new(int csize) {
        int blk = Mem::bump(csize);
        if blk == 0 { return null; }
        std_alloc_n += 1;
        int^ head = (int^)blk;
        head[0] = csize;
        head[1] = 0;
        return (void^)(blk + 16);
    }
    // a block of `need` bytes (more than 2048) from the list of big blocks, or from the chunk
    // a block of 256 KB or more: pages of its own, returned to the system when it is freed (null: the old way is used)
    static void^ alloc_direct(int need) {
        int len = (need + 4095) / 4096 * 4096;
        int mb = syscall(222, 0, len, 3, 34, -1, 0);
        if mb < 0 && mb > -4096 { return null; }
        int^ mh = (int^)mb;
        mh[0] = len;
        mh[1] = 0;
        int di = 0;
        while std_direct[di] != 0 { di += 1; }
        std_direct[di] = mb;
        std_direct_n += 1;
        std_alloc_n += 1;
        return (void^)(mb + 16);
    }
    // the block blk (size bytes with its header) is one of those? then it goes back to the system
    static bool free_direct(int blk, int size) {
        int dj = 0;
        while dj < 64 {
            if std_direct[dj] == blk {
                std_direct[dj] = 0;
                std_direct_n -= 1;
                syscall(215, blk, size);
                return true;
            }
            dj += 1;
        }
        return false;
    }
    static void^ alloc_big(int need) {
        if need >= 262144 && std_direct_n < 64 {
            void^ dr = Mem::alloc_direct(need);
            if (int)dr != 0 { return dr; }
        }
        int prev = 0;
        int cur = std_free_list;
        while cur != 0 {
            int^ hdr = (int^)cur;
            if hdr[0] >= need {
                if hdr[0] - need >= 64 {
                    // split: the rest stays on the list in the place of this block
                    int rest = cur + need;
                    int^ rh = (int^)rest;
                    rh[0] = hdr[0] - need;
                    rh[1] = hdr[1];
                    hdr[0] = need;
                    if prev == 0 {
                        std_free_list = rest;
                    } else {
                        int^ before = (int^)prev;
                        before[1] = rest;
                    }
                } else if prev == 0 {
                    std_free_list = hdr[1];
                } else {
                    int^ before2 = (int^)prev;
                    before2[1] = hdr[1];
                }
                hdr[1] = 0;
                std_alloc_n += 1;
                return (void^)(cur + 16);
            }
            prev = cur;
            cur = hdr[1];
        }
        int nb = Mem::bump(need);
        if nb == 0 { return null; }
        std_alloc_n += 1;
        int^ nh = (int^)nb;
        nh[0] = need;
        nh[1] = 0;
        return (void^)(nb + 16);
    }
    // give a block from alloc back (null is ignored); the common case (one thread, a small block of a class) is written out here
    static void free(void^ p) {
        if std_debug == 0 && std_mt == 0 && (int)p != 0 {
            int blk = (int)p - 16;
            int^ head = (int^)blk;
            int size = head[0];
            if (size & 1) == 0 && size <= 2048 {
                int c = std_cls_exact[size >> 4];
                if c >= 0 {
                    std_free_n += 1;
                    head[1] = std_free_cls[c];
                    std_free_cls[c] = blk;
                    return;
                }
            }
        }
        Mem::free_general(p);
    }
    static void free_general(void^ p) {
        if std_debug != 0 {
            Mem::dbg_free(p);
            return;
        }
        Mem::free_now(p);
    }
    static void free_now(void^ p) {
        if std_mt == 0 {
            Mem::free_raw(p);
            return;
        }
        while __cas(@std_mem_lock, 0, 1) != 0 {
            syscall(124);
        }
        Mem::free_raw(p);
        __xchg(@std_mem_lock, 0);
    }
    static void free_raw(void^ p) {
        if (int)p == 0 { return; }
        int blk = (int)p - 16;
        int^ head = (int^)blk;
        int size = head[0];
        if (size & 1) != 0 {
            Mem::free_piece(blk);
            return;
        }
        std_free_n += 1;
        if size >= 262144 && std_direct_n > 0 {
            if Mem::free_direct(blk, size) { return; }
        }
        if size <= 2048 {
            int c = std_cls_exact[size >> 4];
            if c >= 0 {
                head[1] = std_free_cls[c];
                std_free_cls[c] = blk;
                return;
            }
        }
        Mem::free_big(blk);
    }
    // a big block: into the list in the order of the addresses, joined with the neighbours that are free
    static void free_big(int blk) {
        int^ head = (int^)blk;
        int prev = 0;
        int cur = std_free_list;
        while cur != 0 && cur < blk {
            prev = cur;
            int^ ch = (int^)cur;
            cur = ch[1];
        }
        head[1] = cur;
        if cur != 0 && blk + head[0] == cur {
            int^ nx = (int^)cur;
            head[0] = head[0] + nx[0];
            head[1] = nx[1];
        }
        if prev == 0 {
            std_free_list = blk;
        } else {
            int^ pv = (int^)prev;
            if prev + pv[0] == blk {
                pv[0] = pv[0] + head[0];
                pv[1] = head[1];
            } else {
                pv[1] = blk;
            }
        }
    }
    // like alloc, and every byte is 0
    static void^ alloc0(int n) {
        void^ r = Mem::alloc(n);
        if (int)r != 0 { Mem::set(r, 0, n); }
        return r;
    }
    // A block can be a pool (alloc[int^ a = 32]): pieces are taken from it with alloc[a[12] >> int^ p]. A piece has a header of its own
    // [size + 1 (a piece) (+ 2 once it is given back), the pool]. The word `next` of the header of the pool holds, in its low 32 bits, how
    // many bytes are taken and, in its high 32 bits, the first piece that was given back (its place in the pool + 1; 0 = none; the
    // pieces are linked by the first word of their room). Freeing a piece gives back only that piece (the last one taken gives the room
    // back at once); freeing the pool frees everything. null if the pool has not that much room.
    static void^ take(void^ pool, int bytes) {
        if (int)pool == 0 { return null; }
        int^ ph = (int^)((int)pool - 16);
        int need = ((bytes + 15) >> 4) * 16 + 16;
        int used = ph[1] & 4294967295;
        int first = ph[1] >> 32;
        int prev = 0;
        int cur = first;
        while cur != 0 {
            int at0 = (int)pool + cur - 1;
            int^ cp = (int^)at0;
            int^ room = (int^)(at0 + 16);
            if (cp[0] & -4) >= need {
                if prev == 0 { first = room[0]; } else { int^ pr = (int^)((int)pool + prev - 1 + 16); pr[0] = room[0]; }
                cp[0] = cp[0] - 2;                             // a piece in use again
                ph[1] = used + first * 4294967296;
                return (void^)(at0 + 16);
            }
            prev = cur;
            cur = room[0];
        }
        if used + need > ph[0] - 16 { return null; }
        int at = (int)pool + used;
        int^ piece = (int^)at;
        piece[0] = need + 1;
        piece[1] = (int)pool;
        ph[1] = used + need + first * 4294967296;
        return (void^)(at + 16);
    }
    static void free_piece(int blk) {
        int^ piece = (int^)blk;
        if (piece[0] & 2) != 0 { return; }                // given back already
        piece[0] = piece[0] | 2;
        int size = piece[0] - 3;
        int pool = piece[1];
        int^ ph = (int^)(pool - 16);
        int used = ph[1] & 4294967295;
        int first = ph[1] >> 32;
        if blk + size == pool + used {
            ph[1] = (blk - pool) + first * 4294967296;     // the last piece: the room is free again
        } else {
            int^ room = (int^)(blk + 16);
            room[0] = first;
            ph[1] = used + ((blk - pool) + 1) * 4294967296;
        }
    }
    // p = a block of `bytes` bytes with the old content; slot is the address of p (grow[p = n])
    static void grow_slot(int^ slot, int bytes) {
        int old = slot[0];
        if old == 0 {
            slot[0] = (int)Mem::alloc(bytes);
            return;
        }
        int^ oh = (int^)(old - 16);
        int have = (oh[0] & -4) - 16;
        int nb = (int)Mem::alloc(bytes);                       // an int, not a pointer variable: this function does not own the new block
        if nb == 0 { return; }
        int n = have;
        if bytes < n { n = bytes; }
        Mem::copy((void^)nb, (void^)old, n);
        Mem::free((void^)old);
        slot[0] = nb;
    }
    // free[p = n] in a -d build: the block must be able to hold n bytes
    static void check_size(void^ p, int bytes) {
        if (int)p != 0 {
            int^ h = (int^)((int)p - 16);
            if bytes > (h[0] & -4) - 16 { __panic("free[p = n]: the block is smaller than n"); }
        }
    }
    // ---- the checks of a -d build (the program calls debug_on first)
    static void debug_on() {
        std_debug = 1;
        std_dbg_tab = (int^)syscall(222, 0, 786432, 3, 34, -1, 0);
        if (int)std_dbg_tab < 0 && (int)std_dbg_tab > -4096 { std_dbg_tab = null; std_dbg_full = 1; std_guard_n = 12000; }
    }
    static void dbg_text(char^ t) {
        int n = 0;
        while t[n] != 0 { n += 1; }
        syscall(64, 2, t, n);
    }
    static void dbg_num(int v) {
        char d[24];
        int k = 23;
        d[k] = 32;
        if v == 0 {
            k -= 1;
            d[k] = '0';
        }
        while v > 0 {
            k -= 1;
            d[k] = '0' + v % 10;
            v = v / 10;
        }
        syscall(64, 2, @d + k, 24 - k - 1);
    }
    // the name of the first function in the chain of the callers that is not a function of the library
    static char^ dbg_where() {
        int^ fp = (int^)__fp();
        int^ tab = (int^)__fntab();
        int depth = 0;
        while (int)fp > 4096 && depth < 12 {
            int ret = fp[1];
            int best = 0 - 1;
            int k = 0;
            while tab[k * 2] != 0 {
                if tab[k * 2] < ret { best = k; }
                k += 1;
            }
            if best < 0 { return "?"; }
            char^ name = (char^)tab[best * 2 + 1];
            bool lib = name[0] == '_' && name[1] == '_';
            if name[0] == 'M' && name[1] == 'e' && name[2] == 'm' && name[3] == '_' && name[4] == '_' { lib = true; }
            if !lib { return name; }
            fp = (int^)fp[0];
            depth += 1;
        }
        return "?";
    }
    // the place of the block `addr` in the table, or -1 if it is not there
    static int dbg_find(int addr) {
        if (int)std_dbg_tab == 0 { return 0 - 1; }
        int h = (addr >> 4) & 32767;
        int tries = 0;
        while tries < 32768 {
            int a = std_dbg_tab[h * 3];
            if a == addr { return h; }
            if a == 0 { return 0 - 1; }
            h = (h + 1) & 32767;
            tries += 1;
        }
        return 0 - 1;
    }
    // a place for the block `addr`: the first one that is free (never used, or a block that was freed), -1 if there is none
    static int dbg_free_place(int addr) {
        if (int)std_dbg_tab == 0 { return 0 - 1; }
        int h = (addr >> 4) & 32767;
        int tries = 0;
        while tries < 32768 {
            int a = std_dbg_tab[h * 3];
            if a == 0 || a == 0 - 1 { return h; }
            h = (h + 1) & 32767;
            tries += 1;
        }
        return 0 - 1;
    }
    // -d: a block of its own pages that ends where a page that nobody may touch begins: a write or a read past its end is a fault at once,
    // and a freed block is made untouchable (a read or write after free is a fault at once too). The header is [size, 0] as for any block;
    // the table of the live blocks remembers (bit 40 of the size) that the block has pages of its own.
    static void^ dbg_guard_alloc(int n) {
        int sz = ((n + 15) >> 4) * 16;
        int pages = (sz + 16 + 4095) >> 12;
        int base = syscall(222, 0, (pages + 1) * 4096, 3, 34, -1, 0);
        if base < 0 && base > -4096 { return null; }
        syscall(226, base + pages * 4096, 4096, 0);
        int blk = base + pages * 4096 - sz;
        int^ hh = (int^)(blk - 16);
        hh[0] = sz + 16;
        hh[1] = 0;
        return (void^)blk;
    }
    static void^ dbg_alloc(int n) {
        void^ r = null;
        int guarded = 0;
        if n > 0 && std_guard_n < 12000 && std_mt == 0 && std_dbg_full == 0 {
            r = Mem::dbg_guard_alloc(n);
            if (int)r != 0 {
                std_guard_n += 1;
                std_alloc_n += 1;
                guarded = 1;
            }
        }
        if (int)r == 0 { r = Mem::alloc_locked(n); }
        if (int)r != 0 {
            char^ where = Mem::dbg_where();
            int^ hh = (int^)((int)r - 16);
            int sl = Mem::dbg_free_place((int)r);
            if sl < 0 {
                std_dbg_full = 1;
            } else {
                std_dbg_n += 1;
                std_dbg_tab[sl * 3] = (int)r;
                std_dbg_tab[sl * 3 + 1] = (hh[0] & -4) - 16 + guarded * 1099511627776;
                std_dbg_tab[sl * 3 + 2] = (int)where;
            }
        }
        return r;
    }
    static void^ alloc_locked(int n) {
        if std_mt == 0 { return Mem::alloc_raw(n); }
        while __cas(@std_mem_lock, 0, 1) != 0 {
            syscall(124);
        }
        void^ r = Mem::alloc_raw(n);
        __xchg(@std_mem_lock, 0);
        return r;
    }
    // are the 221 that a freed block was filled with all there?
    static bool dbg_intact(int blk) {
        int^ hh = (int^)(blk - 16);
        int words = ((hh[0] & -4) - 16) / 8;
        int^ w = (int^)blk;
        int i = 0;
        while i < words {
            if w[i] != -2459565876494606883 { return false; }
            i += 1;
        }
        return true;
    }
    static void dbg_free(void^ p) {
        if (int)p == 0 { return; }
        int gs = Mem::dbg_find((int)p);
        if gs >= 0 {
            int gsz = std_dbg_tab[gs * 3 + 1];
            if gsz == 0 - 1 { __panic("free of a block that is not alive: freed twice"); }
            if gsz >= 1099511627776 {
                // a block with a guard page: the table keeps its place (marked as freed), no page of it may be touched again
                int size = gsz - 1099511627776;
                int pages = (size + 16 + 4095) >> 12;
                std_dbg_tab[gs * 3 + 1] = 0 - 1;
                std_dbg_n -= 1;
                std_free_n += 1;
                syscall(226, (int)p + size - pages * 4096, pages * 4096, 0);
                return;
            }
        }
        int^ hh = (int^)((int)p - 16);
        if (hh[0] & 1) != 0 {
            Mem::free_piece((int)p - 16);
            return;
        }
        int sl = Mem::dbg_find((int)p);
        if sl >= 0 {
            std_dbg_tab[sl * 3] = 0 - 1;                  // a place that held a block (the places after it stay reachable)
            std_dbg_n -= 1;
        } else if std_dbg_full == 0 {
            __panic("free of a block that is not alive: freed twice, or it did not come from alloc");
        }
        // filled with 221 and kept for a while: a write into it is found when it leaves
        int words = ((hh[0] & -4) - 16) / 8;
        int^ w = (int^)p;
        int i = 0;
        while i < words {
            w[i] = -2459565876494606883;
            i += 1;
        }
        int q = std_dbg_qi & 63;
        std_dbg_qi += 1;
        int old = std_dbg_quar[q];
        std_dbg_quar[q] = (int)p;
        std_free_n += 1;
        if old != 0 {
            if !Mem::dbg_intact(old) { __panic("a block was written after it was freed"); }
            std_free_n -= 1;                               // free_raw counts it
            Mem::free_now((void^)old);
        }
    }
    // -d : at the end of main, say which blocks were never given back
    static void report() {
        int q = 0;
        int quarantined = 0;
        while q < 64 {
            if std_dbg_quar[q] != 0 {
                if !Mem::dbg_intact(std_dbg_quar[q]) { __panic("a block was written after it was freed"); }
                quarantined += 1;
            }
            q += 1;
        }
        int n = std_alloc_n - std_free_n;
        if n <= 0 { return; }
        Mem::dbg_text("debug: memory blocks never freed: ");
        Mem::dbg_num(n);
        Mem::dbg_text("\n");
        int shown = 0;
        int i = 0;
        while i < 32768 && shown < 20 {
            int a = std_dbg_tab[i * 3];
            if a > 0 && std_dbg_tab[i * 3 + 1] != 0 - 1 {
                Mem::dbg_text("  leak: ");
                Mem::dbg_num(std_dbg_tab[i * 3 + 1] & 1099511627775);
                Mem::dbg_text(" bytes made in ");
                Mem::dbg_text((char^)std_dbg_tab[i * 3 + 2]);
                Mem::dbg_text("\n");
                shown += 1;
            }
            i += 1;
        }
    }
    // n bytes of p are set to value (8 bytes at a time while it goes, then the rest)
    static void set(void^ p, int value, int n) {
        char^ q = (char^)p;
        int i = 0;
        if n >= 8 {
            int^ w = (int^)p;
            int pat = (value & 255) * 72340172838076673;
            int words = n / 8;
            int j = 0;
            while j < words {
                w[j] = pat;
                j += 1;
            }
            i = words * 8;
        }
        while i < n {
            q[i] = value;
            i += 1;
        }
    }
    // n bytes from src to dst, forward (8 bytes at a time while it goes, then the rest); the two areas may overlap only if dst is before src
    static void copy(void^ dst, void^ src, int n) {
        char^ d = (char^)dst;
        char^ s = (char^)src;
        int i = 0;
        if n >= 8 {
            int^ dw = (int^)dst;
            int^ sw = (int^)src;
            int words = n / 8;
            int j = 0;
            while j < words {
                dw[j] = sw[j];
                j += 1;
            }
            i = words * 8;
        }
        while i < n {
            d[i] = s[i];
            i += 1;
        }
    }
}

