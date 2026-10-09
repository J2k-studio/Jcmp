// The prelude: read in front of every program (unused functions are left out).
// Mem: a small heap. Every block has a 16-byte header: [size, next-free].
int std_heap_cur;
int std_heap_end;
int std_free_list;
int std_mem_lock;                 // 0 free, 1 taken (threads share the heap)
int std_mt;                       // 1 once a thread was started: only then the heap is locked
int std_alloc_n;                  // blocks given out / given back (the -d build reports the difference at the end)
int std_free_n;
int std_cls[24] = {32, 48, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, 448, 512, 640, 768, 896, 1024, 1280, 1536, 1792, 2048, 2048};   // the size classes (with the header)
int std_cls_of[129] = {0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 11, 11, 12, 12, 12, 12, 13, 13, 13, 13, 14, 14, 14, 14, 15, 15, 15, 15, 15, 15, 15, 15, 16, 16, 16, 16, 16, 16, 16, 16, 17, 17, 17, 17, 17, 17, 17, 17, 18, 18, 18, 18, 18, 18, 18, 18, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22};     // by need / 16: the class of a block (-1: bigger than the biggest class)
int std_cls_exact[129] = {-1, -1, 0, 1, 2, 3, 4, 5, 6, -1, 7, -1, 8, -1, 9, -1, 10, -1, -1, -1, 11, -1, -1, -1, 12, -1, -1, -1, 13, -1, -1, -1, 14, -1, -1, -1, -1, -1, -1, -1, 15, -1, -1, -1, -1, -1, -1, -1, 16, -1, -1, -1, -1, -1, -1, -1, 17, -1, -1, -1, -1, -1, -1, -1, 18, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 19, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 20, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 21, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 22};  // by size / 16: the class whose size is exactly this, or -1
int std_free_cls[24];              // the free blocks of each class
int std_debug;                     // 1 in a -d build: the checks of Mem (a block freed twice, written after it was freed, the places of the leaks)
int std_dbg_tab[98304];            // the live blocks in a -d build: [address, size, the function that made it], 32768 places (open addressing)
int std_dbg_n;                     // how many live blocks the table holds
int std_dbg_full;                  // 1: the table was full once (the checks that need it are off)
int std_dbg_quar[64];              // the last blocks that were freed (a -d build keeps them filled with 221 for a while)
int std_dbg_qi;

// a bug in the program (a null array, a position out of range, ...): say so and stop; try/catch cannot catch it
void __panic(char^ msg) {
    int n = 0;
    while msg[n] != 0 { n += 1; }
    syscall(64, 2, "panic: ", 7);
    syscall(64, 2, msg, n);
    syscall(64, 2, "\n", 1);
    // the functions that were running, innermost first (the frames are linked: [fp] = caller's fp, [fp + 8] = return address)
    int^ fp = (int^)__fp();
    int^ tab = (int^)__fntab();
    int depth = 0;
    while (int)fp > 4096 && depth < 24 {
        int ret = fp[1];
        int best = 0 - 1;
        int k = 0;
        while tab[k * 2] != 0 {
            if tab[k * 2] < ret { best = k; }
            k += 1;
        }
        if best < 0 { break; }
        char^ name = (char^)tab[best * 2 + 1];
        syscall(64, 2, "  at ", 5);
        int i = 0;
        if name[0] == '_' && name[1] == '_' { i = 2; }              // a name of the library: __Arr__nullerr is shown as Arr::nullerr
        while name[i] != 0 {
            if name[i] == '_' && name[i + 1] == '_' {
                syscall(64, 2, "::", 2);
                i += 2;
            } else {
                syscall(64, 2, @name[i], 1);
                i += 1;
            }
        }
        syscall(64, 2, "\n", 1);
        fp = (int^)fp[0];
        depth += 1;
    }
    syscall(94, 134);
}

struct Mem {
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
    static void^ alloc(int n) {
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
    static void^ alloc_big(int need) {
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
    // give a block from alloc back (null is ignored)
    static void free(void^ p) {
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
    static void^ dbg_alloc(int n) {
        void^ r = Mem::alloc_locked(n);
        if (int)r != 0 {
            char^ where = Mem::dbg_where();
            int^ hh = (int^)((int)r - 16);
            int sl = Mem::dbg_free_place((int)r);
            if sl < 0 {
                std_dbg_full = 1;
            } else {
                std_dbg_n += 1;
                std_dbg_tab[sl * 3] = (int)r;
                std_dbg_tab[sl * 3 + 1] = hh[0] - 16;
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
            if a > 0 {
                Mem::dbg_text("  leak: ");
                Mem::dbg_num(std_dbg_tab[i * 3 + 1]);
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

// Dynamic arrays (T[] x = arr(n)): a header [length, capacity, data, element size]
// points to the elements. The header stays where it is, so every copy of the
// variable sees the same array; only the data block moves when it grows.
struct __Arr {
    static void nullerr() {
        __panic("the dynamic array is null");
    }
    static void^ make(int esize, int cap) {
        int^ h = (int^)Mem::alloc(32);
        if (int)h == 0 { __panic("out of memory"); }
        int c = cap;
        if c < 4 { c = 4; }
        h[0] = 0;
        h[1] = c;
        h[2] = (int)Mem::alloc(c * esize);
        h[3] = esize;
        if h[2] == 0 { __panic("out of memory"); }
        return (void^)h;
    }
    // room for at least `need` elements
    static void grow(int^ h, int need) {
        if need <= h[1] { return; }
        int c = h[1] * 2;
        if c < need { c = need; }
        int nd = (int)Mem::alloc(c * h[3]);
        if nd == 0 { __panic("out of memory"); }
        Mem::copy((void^)nd, (void^)h[2], h[0] * h[3]);
        Mem::free((void^)h[2]);
        h[2] = nd;
        h[1] = c;
    }
    // append one element: returns the address of its (new) place
    static void^ slot(void^ hv) {
        int^ h = (int^)hv;
        if (int)h == 0 { __panic("the dynamic array is null"); }
        __Arr::grow(h, h[0] + 1);
        int at = h[2] + h[0] * h[3];
        h[0] += 1;
        return (void^)at;
    }
    // remove the last element: returns the address where it still is
    static void^ pop(void^ hv) {
        int^ h = (int^)hv;
        if (int)h == 0 { __panic("the dynamic array is null"); }
        if h[0] == 0 { __panic("pop from an empty array"); }
        h[0] -= 1;
        return (void^)(h[2] + h[0] * h[3]);
    }
    static void resize(void^ hv, int n) {
        int^ h = (int^)hv;
        if (int)h == 0 { __panic("the dynamic array is null"); }
        if n < 0 { __panic("negative array size"); }
        __Arr::grow(h, n);
        if n > h[0] { Mem::set((void^)(h[2] + h[0] * h[3]), 0, (n - h[0]) * h[3]); }
        h[0] = n;
    }
    // ---- numbers in an array: kind 0 signed, 1 unsigned (also pointers), 2 float, 3 double
    // the bits of element i as a whole number (sign or zero extended; the IEEE bits for a float)
    static int get(int^ h, int i, int kind) {
        char^ d = (char^)(h[2] + i * h[3]);
        int es = h[3];
        int v = 0;
        int k = es - 1;
        while k >= 0 {
            v = v * 256 + d[k];
            k -= 1;
        }
        if kind == 0 && es < 8 {
            int sh = 64 - es * 8;
            v = (v shl sh) shr sh;
        }
        return v;
    }
    static void put(int^ h, int i, int bits) {
        char^ d = (char^)(h[2] + i * h[3]);
        int k = 0;
        while k < h[3] {
            d[k] = bits & 255;
            bits = bits shr 8;
            k += 1;
        }
    }
    // a before b ?
    static bool less(int a, int b, int kind) {
        if kind == 0 { return a < b; }
        if kind == 1 { return (a xor -9223372036854775807 - 1) < (b xor -9223372036854775807 - 1); }
        if kind == 2 {
            int x = a;
            int y = b;
            float^ fx = (float^)@x;
            float^ fy = (float^)@y;
            return fx[0] < fy[0];
        }
        int x2 = a;
        int y2 = b;
        double^ dx = (double^)@x2;
        double^ dy = (double^)@y2;
        return dx[0] < dy[0];
    }
    static void insert(void^ hv, int i, int bits) {
        if (int)hv == 0 { __panic("the dynamic array is null"); }
        int^ h = (int^)hv;
        if i < 0 || i > h[0] { __panic("insert position out of range"); }
        __Arr::grow(h, h[0] + 1);
        int k = h[0];
        while k > i {
            __Arr::put(h, k, __Arr::get(h, k - 1, 1));
            k -= 1;
        }
        __Arr::put(h, i, bits);
        h[0] += 1;
    }
    static void remove(void^ hv, int i) {
        if (int)hv == 0 { __panic("the dynamic array is null"); }
        int^ h = (int^)hv;
        if i < 0 || i >= h[0] { __panic("remove position out of range"); }
        int k = i;
        while k + 1 < h[0] {
            __Arr::put(h, k, __Arr::get(h, k + 1, 1));
            k += 1;
        }
        h[0] -= 1;
    }
    // the place of the first element equal to bits, or -1
    static int index(void^ hv, int bits, int kind) {
        if (int)hv == 0 { __panic("the dynamic array is null"); }
        int^ h = (int^)hv;
        int i = 0;
        while i < h[0] {
            int e = __Arr::get(h, i, kind);
            if !__Arr::less(e, bits, kind) && !__Arr::less(bits, e, kind) { return i; }
            i += 1;
        }
        return 0 - 1;
    }
    static void sort(void^ hv, int kind) {
        if (int)hv == 0 { __panic("the dynamic array is null"); }
        int^ h = (int^)hv;
        int n = h[0];
        int start = n / 2 - 1;
        while start >= 0 {
            __Arr::sift(h, start, n, kind);
            start -= 1;
        }
        int end = n - 1;
        while end > 0 {
            int t = __Arr::get(h, 0, kind);
            __Arr::put(h, 0, __Arr::get(h, end, kind));
            __Arr::put(h, end, t);
            __Arr::sift(h, 0, end, kind);
            end -= 1;
        }
    }
    static void sift(int^ h, int root, int n, int kind) {
        while true {
            int child = root * 2 + 1;
            if child >= n { return; }
            if child + 1 < n && __Arr::less(__Arr::get(h, child, kind), __Arr::get(h, child + 1, kind), kind) { child += 1; }
            int a = __Arr::get(h, root, kind);
            int b = __Arr::get(h, child, kind);
            if !__Arr::less(a, b, kind) { return; }
            __Arr::put(h, root, b);
            __Arr::put(h, child, a);
            root = child;
        }
    }
    // a copy of an array of numbers / pointers
    static void^ clone(void^ hv) {
        if (int)hv == 0 { __panic("the dynamic array is null"); }
        int^ h = (int^)hv;
        int^ r = (int^)__Arr::make(h[3], h[0]);
        Mem::copy((void^)r[2], (void^)h[2], h[0] * h[3]);
        r[0] = h[0];
        return (void^)r;
    }
    // a copy of an array whose elements own memory: the elements move to the copy, the old array is empty afterwards
    static void^ clone_move(void^ hv) {
        void^ r = __Arr::clone(hv);
        int^ h = (int^)hv;
        h[0] = 0;
        return r;
    }
    // every element is freed with f (a struct that frees itself), then the array
    static void free_each(void^ hv, void(void^)^ f) {
        int^ h = (int^)hv;
        if (int)h == 0 { return; }
        int i = 0;
        while i < h[0] {
            f((void^)(h[2] + i * h[3]));
            i += 1;
        }
        __Arr::free(hv);
    }
    // give the elements and the header back (null is ignored)
    static void free(void^ hv) {
        int^ h = (int^)hv;
        if (int)h == 0 { return; }
        Mem::free((void^)h[2]);
        Mem::free(hv);
    }
}

// String: a dynamic array of char (header [length, capacity, data, 1]) whose data always ends
// in a 0 byte after the length, so that the data is also a C-style text (cout, c()).
// An operand is a text (kind 0), another String (kind 1) or one character (kind 2).
char std_str_ch[16];
struct __Str {
    static void^ make(int cap) {
        int^ h = (int^)__Arr::make(1, cap + 1);
        char^ d = (char^)h[2];
        d[0] = 0;
        return (void^)h;
    }
    static int textlen(char^ t) {
        int n = 0;
        while t[n] != 0 { n += 1; }
        return n;
    }
    static void check(void^ hv) {
        if (int)hv == 0 { __panic("the String is null"); }
    }
    // the characters of an operand
    static char^ ptr(void^ x, int k, int slot) {
        if k == 1 {
            __Str::check(x);
            int^ h = (int^)x;
            return (char^)h[2];
        }
        if k == 2 {
            std_str_ch[slot * 8] = (int)x;
            std_str_ch[slot * 8 + 1] = 0;
            return @std_str_ch + slot * 8;
        }
        return (char^)x;
    }
    static int len(void^ x, int k) {
        if k == 1 {
            __Str::check(x);
            int^ h = (int^)x;
            return h[0];
        }
        if k == 2 { return 1; }
        return __Str::textlen((char^)x);
    }
    // the whole number v written at the end of r (u = 1: v is read as an unsigned number)
    static void push_int(void^ r, int v, int u) {
        char d[24];
        int n = 0;
        int neg = 0;
        if u == 0 && v < 0 { neg = 1; }
        u64 m = (u64)v;
        if neg == 1 { m = (u64)0 - m; }
        if m == 0 {
            d[0] = '0';
            n = 1;
        }
        while m > 0 {
            d[n] = '0' + (int)(m % 10);
            n += 1;
            m = m / 10;
        }
        if neg == 1 { __Str::push(r, '-'); }
        while n > 0 {
            n -= 1;
            __Str::push(r, d[n]);
        }
    }
    // a new String with the whole number v (u = 1: v is read as an unsigned number)
    static void^ from_int(int v, int u) {
        void^ r = __Str::make(24);
        __Str::push_int(r, v, u);
        return r;
    }
    // a new String with one character
    static void^ from_char(int c) {
        void^ r = __Str::make(2);
        __Str::push(r, c);
        return r;
    }
    // the digits of n written with exactly `width` digits (leading zeros), without the trailing zeros: for the part after the point
    static void frac_digits(void^ r, int n, int width) {
        char d[24];
        int k = width;
        while k > 0 {
            k -= 1;
            d[k] = '0' + n % 10;
            n = n / 10;
        }
        int last = width;
        while last > 0 && d[last - 1] == '0' { last -= 1; }
        int i = 0;
        while i < last {
            __Str::push(r, d[i]);
            i += 1;
        }
    }
    // a new String with a decimal number: up to 15 significant digits, no zeros at the end (0.1, 2.5, 100, 1.5e+20, nan, inf)
    static void^ from_double(double x) {
        void^ r = __Str::make(32);
        if x != x {
            __Str::append(r, "nan", 0);
            return r;
        }
        if x == 0.0 {
            __Str::push(r, '0');
            return r;
        }
        if x < 0.0 {
            __Str::push(r, '-');
            x = 0.0 - x;
        }
        if x - x != 0.0 {
            __Str::append(r, "inf", 0);
            return r;
        }
        if x >= 1.0e15 || x < 1.0e-5 {
            // the form  d.ddde+XX : bring the number into 1 .. 10
            int e = 0;
            while x >= 10.0 {
                x = x / 10.0;
                e += 1;
            }
            while x < 1.0 {
                x = x * 10.0;
                e -= 1;
            }
            int d0 = (int)x;
            int f = (int)((x - (double)d0) * 1.0e14 + 0.5);
            if f >= 100000000000000 {
                f -= 100000000000000;
                d0 += 1;
            }
            if d0 >= 10 {
                d0 = 1;
                e += 1;
            }
            __Str::push(r, '0' + d0);
            if f > 0 {
                __Str::push(r, '.');
                __Str::frac_digits(r, f, 14);
            }
            __Str::push(r, 'e');
            if e < 0 {
                __Str::push(r, '-');
                e = 0 - e;
            } else {
                __Str::push(r, '+');
            }
            if e < 10 { __Str::push(r, '0'); }
            __Str::push_int(r, e, 0);
            return r;
        }
        int ip = (int)x;
        double frac = x - (double)ip;
        // the number of digits after the point: 15 digits in all
        int fd = 15;
        int t = ip;
        while t > 0 {
            fd -= 1;
            t = t / 10;
        }
        if ip == 0 {
            double q = frac;
            int zeros = 0;
            while q < 0.1 && zeros < 6 {
                q = q * 10.0;
                zeros += 1;
            }
            fd = 15 + zeros;
        }
        if fd < 0 { fd = 0; }
        int pw = 1;
        int k = 0;
        while k < fd {
            pw = pw * 10;
            k += 1;
        }
        int f = (int)(frac * (double)pw + 0.5);
        if f >= pw {
            f -= pw;
            ip += 1;
        }
        __Str::push_int(r, ip, 0);

        if f > 0 {
            __Str::push(r, '.');
            __Str::frac_digits(r, f, fd);
        }
        return r;
    }
    // a new String holding a copy of the text
    static void^ from(char^ t) {
        int n = __Str::textlen(t);
        int^ h = (int^)__Str::make(n);
        Mem::copy((void^)h[2], (void^)t, n);
        char^ d = (char^)h[2];
        d[n] = 0;
        h[0] = n;
        return (void^)h;
    }
    // a copy of a String
    static void^ clone(void^ x) {
        return __Str::cat(x, 1, (void^)"", 0);
    }
    // a new String: a followed by b
    static void^ cat(void^ a, int ka, void^ b, int kb) {
        int na = __Str::len(a, ka);
        int nb = __Str::len(b, kb);
        int^ h = (int^)__Str::make(na + nb);
        char^ d = (char^)h[2];
        Mem::copy((void^)d, (void^)__Str::ptr(a, ka, 0), na);
        Mem::copy((void^)(d + na), (void^)__Str::ptr(b, kb, 1), nb);
        d[na + nb] = 0;
        h[0] = na + nb;
        return (void^)h;
    }
    // a followed by b, in a (returns a)
    static void^ append(void^ a, void^ b, int kb) {
        __Str::check(a);
        if kb == 1 && (int)b == (int)a {                 // s.append(s): the data may move
            void^ same = __Str::clone(a);
            __Str::append(a, same, 1);
            __Arr::free(same);
            return a;
        }
        int^ h = (int^)a;
        int nb = __Str::len(b, kb);
        char^ src = __Str::ptr(b, kb, 1);
        __Arr::grow(h, h[0] + nb + 1);
        Mem::copy((void^)(h[2] + h[0]), (void^)src, nb);
        h[0] += nb;
        char^ d = (char^)h[2];
        d[h[0]] = 0;
        return a;
    }
    static void push(void^ a, int c) {
        __Str::check(a);
        int^ h = (int^)a;
        __Arr::grow(h, h[0] + 2);
        char^ d = (char^)h[2];
        d[h[0]] = c;
        h[0] += 1;
        d[h[0]] = 0;
    }
    static int pop(void^ a) {
        __Str::check(a);
        int^ h = (int^)a;
        if h[0] == 0 { __panic("pop from an empty String"); }
        h[0] -= 1;
        char^ d = (char^)h[2];
        int c = d[h[0]];
        d[h[0]] = 0;
        return c;
    }
    static void clear(void^ a) {
        __Str::check(a);
        int^ h = (int^)a;
        h[0] = 0;
        char^ d = (char^)h[2];
        d[0] = 0;
    }
    // 1 if the two operands hold the same characters
    static int eq(void^ a, int ka, void^ b, int kb) {
        int na = __Str::len(a, ka);
        int nb = __Str::len(b, kb);
        if na != nb { return 0; }
        char^ pa = __Str::ptr(a, ka, 0);
        char^ pb = __Str::ptr(b, kb, 1);
        int i = 0;
        while i < na {
            if pa[i] != pb[i] { return 0; }
            i += 1;
        }
        return 1;
    }
    // -1, 0 or 1: a is before, the same as, or after b (by the codes of the bytes, like strcmp)
    static int order(void^ a, int ka, void^ b, int kb) {
        int na = __Str::len(a, ka);
        int nb = __Str::len(b, kb);
        char^ pa = __Str::ptr(a, ka, 0);
        char^ pb = __Str::ptr(b, kb, 1);
        int i = 0;
        while i < na && i < nb {
            int ca = pa[i] & 255;
            int cb = pb[i] & 255;
            if ca < cb { return 0 - 1; }
            if ca > cb { return 1; }
            i += 1;
        }
        if na < nb { return 0 - 1; }
        if na > nb { return 1; }
        return 0;
    }
    // the first place of t in s at or after `from`, or -1
    static int find(void^ s, void^ t, int kt) {
        int ns = __Str::len(s, 1);
        int nt = __Str::len(t, kt);
        char^ ps = __Str::ptr(s, 1, 0);
        char^ pt = __Str::ptr(t, kt, 1);
        int i = 0;
        while i + nt <= ns {
            int j = 0;
            while j < nt && ps[i + j] == pt[j] { j += 1; }
            if j == nt { return i; }
            i += 1;
        }
        return 0 - 1;
    }
    // a new String: the characters a .. b - 1
    static void^ slice(void^ s, int a, int b) {
        int n = __Str::len(s, 1);
        if a < 0 || b > n || a > b { __panic("String slice out of range"); }
        int^ h = (int^)__Str::make(b - a);
        char^ d = (char^)h[2];
        char^ ps = __Str::ptr(s, 1, 0);
        Mem::copy((void^)d, (void^)(ps + a), b - a);
        d[b - a] = 0;
        h[0] = b - a;
        return (void^)h;
    }
    static char^ c(void^ s) {
        return __Str::ptr(s, 1, 0);
    }
    // hash of a whole number / of a String (FNV-1a over the bytes)
    static int hashint(int x) {
        int h = x * -7046029254386353131;
        return h xor (h shr 29);
    }
    static int hash(void^ s) {
        char^ p = __Str::ptr(s, 1, 0);
        int h = -3750763034362895579;
        int i = 0;
        while p[i] != 0 {
            h = (h xor p[i]) * 1099511628211;
            i += 1;
        }
        return h xor (h shr 29);
    }
    // String[]: n places (new ones are null, cut ones are freed)
    static void aresize(void^ hv, int n) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        if n < 0 { __panic("negative array size"); }
        int^ el = (int^)h[2];
        int i = n;
        while i < h[0] {
            __Arr::free((void^)el[i]);
            i += 1;
        }
        __Arr::grow(h, n);
        el = (int^)h[2];
        i = h[0];
        while i < n {
            el[i] = 0;
            i += 1;
        }
        h[0] = n;
    }
    // -1, 0, 1: a before, equal to, after b (bytes)
    static int cmp(void^ a, void^ b) {
        char^ pa = __Str::ptr(a, 1, 0);
        char^ pb = __Str::ptr(b, 1, 1);
        int i = 0;
        while pa[i] != 0 && pa[i] == pb[i] { i += 1; }
        if pa[i] == pb[i] { return 0; }
        if pa[i] < pb[i] { return 0 - 1; }
        return 1;
    }

    // ---- more String functions (the bytes are treated as ASCII where case matters)
    static bool isspace(int c) {
        return c == 32 || c == 9 || c == 10 || c == 13;
    }
    // a new String: s without the white space at both ends
    static void^ trim(void^ s) {
        int n = __Str::len(s, 1);
        char^ p = __Str::ptr(s, 1, 0);
        int a = 0;
        int b = n;
        while a < b && __Str::isspace(p[a]) { a += 1; }
        while b > a && __Str::isspace(p[b - 1]) { b -= 1; }
        return __Str::slice(s, a, b);
    }
    // ---- UTF-8: len counts bytes; these work on characters (code points)
    // the upper case of a code point (ASCII, Latin-1, Latin Extended-A, Greek, Cyrillic); others stay
    static int cp_upper(int c) {
        if c < 128 {
            if c >= 'a' && c <= 'z' { return c - 32; }
            return c;
        }
        if c >= 0xE0 && c <= 0xFE && c != 0xF7 { return c - 32; }
        if c == 0xFF { return 0x178; }
        if c >= 0x100 && c <= 0x137 && c != 0x130 && c != 0x131 && c % 2 == 1 { return c - 1; }
        if c >= 0x139 && c <= 0x148 && c % 2 == 0 { return c - 1; }
        if c >= 0x14A && c <= 0x177 && c % 2 == 1 { return c - 1; }
        if c >= 0x17A && c <= 0x17E && c % 2 == 0 { return c - 1; }
        if c == 0x3C2 { return 0x3A3; }
        if c >= 0x3B1 && c <= 0x3C9 { return c - 32; }
        if c >= 0x430 && c <= 0x44F { return c - 32; }
        if c >= 0x450 && c <= 0x45F { return c - 80; }
        return c;
    }
    static int cp_lower(int c) {
        if c < 128 {
            if c >= 'A' && c <= 'Z' { return c + 32; }
            return c;
        }
        if c >= 0xC0 && c <= 0xDE && c != 0xD7 { return c + 32; }
        if c == 0x178 { return 0xFF; }
        if c >= 0x100 && c <= 0x137 && c != 0x130 && c != 0x131 && c % 2 == 0 { return c + 1; }
        if c >= 0x139 && c <= 0x148 && c % 2 == 1 { return c + 1; }
        if c >= 0x14A && c <= 0x177 && c % 2 == 0 { return c + 1; }
        if c >= 0x179 && c <= 0x17D && c % 2 == 1 { return c + 1; }
        if c >= 0x391 && c <= 0x3A9 && c != 0x3A2 { return c + 32; }
        if c >= 0x410 && c <= 0x42F { return c + 32; }
        if c >= 0x400 && c <= 0x40F { return c + 80; }
        return c;
    }
    // r (a fresh copy) changed in place to upper (up = 1) or lower case; every mapped letter keeps its size
    static void map_case(void^ r, int up) {
        char^ p = __Str::ptr(r, 1, 0);
        int i = 0;
        while p[i] != 0 {
            int b = p[i] & 255;
            if b < 128 {
                if up == 1 { p[i] = (char)__Str::cp_upper(b); } else { p[i] = (char)__Str::cp_lower(b); }
                i += 1;
            } else if b >= 0xC2 && b <= 0xDF && (p[i + 1] & 0xC0) == 0x80 {
                int c = ((b & 0x1F) << 6) | (p[i + 1] & 0x3F);
                if up == 1 { c = __Str::cp_upper(c); } else { c = __Str::cp_lower(c); }
                p[i] = (char)(0xC0 | (c >> 6));
                p[i + 1] = (char)(0x80 | (c & 0x3F));
                i += 2;
            } else {
                i += 1;
            }
        }
    }
    static void^ upper(void^ s) {
        void^ r = __Str::clone(s);
        __Str::map_case(r, 1);
        return r;
    }
    static void^ lower(void^ s) {
        void^ r = __Str::clone(s);
        __Str::map_case(r, 0);
        return r;
    }
    // the number of characters (code points)
    static int count(void^ s) {
        char^ p = __Str::ptr(s, 1, 0);
        int n = __Str::len(s, 1);
        int k = 0;
        int i = 0;
        while i < n {
            if (p[i] & 0xC0) != 0x80 { k += 1; }
            i += 1;
        }
        return k;
    }
    // the size in bytes of the character that starts at byte i
    static int cp_size(char^ p, int i, int n) {
        int b = p[i] & 255;
        int k = 1;
        if b >= 0xF0 { k = 4; } else if b >= 0xE0 { k = 3; } else if b >= 0xC0 { k = 2; }
        if i + k > n { k = n - i; }
        return k;
    }
    // a String[] with every character as a String of its own
    static void^ chars(void^ s) {
        void^ r = __Arr::make(8, 4);
        char^ p = __Str::ptr(s, 1, 0);
        int n = __Str::len(s, 1);
        int i = 0;
        while i < n {
            int k = __Str::cp_size(p, i, n);
            __Str::apush(r, __Str::slice(s, i, i + k));
            i += k;
        }
        return r;
    }
    // the character number idx (counted from 0) as a String
    static void^ char_at(void^ s, int idx) {
        char^ p = __Str::ptr(s, 1, 0);
        int n = __Str::len(s, 1);
        int i = 0;
        int k = 0;
        while i < n {
            int sz = __Str::cp_size(p, i, n);
            if k == idx { return __Str::slice(s, i, i + sz); }
            i += sz;
            k += 1;
        }
        __panic("char_at: the position is out of range");
        return __Str::make(1);
    }
    static int starts_with(void^ s, void^ x, int kx) {
        int ns = __Str::len(s, 1);
        int nx = __Str::len(x, kx);
        if nx > ns { return 0; }
        char^ ps = __Str::ptr(s, 1, 0);
        char^ px = __Str::ptr(x, kx, 1);
        int i = 0;
        while i < nx {
            if ps[i] != px[i] { return 0; }
            i += 1;
        }
        return 1;
    }
    static int ends_with(void^ s, void^ x, int kx) {
        int ns = __Str::len(s, 1);
        int nx = __Str::len(x, kx);
        if nx > ns { return 0; }
        char^ ps = __Str::ptr(s, 1, 0);
        char^ px = __Str::ptr(x, kx, 1);
        int i = 0;
        while i < nx {
            if ps[ns - nx + i] != px[i] { return 0; }
            i += 1;
        }
        return 1;
    }
    // a new String: every a in s replaced by b
    static void^ replace(void^ s, void^ a, int ka, void^ b, int kb) {
        int na = __Str::len(a, ka);
        if na == 0 { __panic("replace: the text to look for is empty"); }
        void^ r = __Str::make(__Str::len(s, 1));
        int ns = __Str::len(s, 1);
        char^ ps = __Str::ptr(s, 1, 0);
        char^ pa = __Str::ptr(a, ka, 1);
        int i = 0;
        while i < ns {
            int j = 0;
            while j < na && i + j < ns && ps[i + j] == pa[j] { j += 1; }
            if j == na {
                __Str::append(r, b, kb);
                i += na;
            } else {
                __Str::push(r, ps[i]);
                i += 1;
            }
        }
        return r;
    }
    // a new String: s repeated n times
    static void^ repeat(void^ s, int n) {
        void^ r = __Str::make(__Str::len(s, 1) * (n + 1));
        int i = 0;
        while i < n {
            __Str::append(r, s, 1);
            i += 1;
        }
        return r;
    }
    // the whole String as a number (an optional sign and digits); throws "not a number"
    static int to_int(void^ s) {
        char^ p = __Str::ptr(s, 1, 0);
        int n = __Str::len(s, 1);
        int i = 0;
        while i < n && __Str::isspace(p[i]) { i += 1; }
        int neg = 0;
        if i < n && (p[i] == '-' || p[i] == '+') {
            if p[i] == '-' { neg = 1; }
            i += 1;
        }
        if i >= n || p[i] < '0' || p[i] > '9' { throw "not a number"; }
        int v = 0;
        while i < n && p[i] >= '0' && p[i] <= '9' {
            v = v * 10 + (p[i] - '0');
            i += 1;
        }
        while i < n && __Str::isspace(p[i]) { i += 1; }
        if i != n { throw "not a number"; }
        if neg == 1 { return 0 - v; }
        return v;
    }
    // the whole String as a decimal number (sign, digits, a point, digits, e and an exponent); throws "not a number"
    static double to_double(void^ s) {
        char^ p = __Str::ptr(s, 1, 0);
        int n = __Str::len(s, 1);
        int i = 0;
        while i < n && __Str::isspace(p[i]) { i += 1; }
        int neg = 0;
        if i < n && (p[i] == '-' || p[i] == '+') {
            if p[i] == '-' { neg = 1; }
            i += 1;
        }
        double v = 0.0;
        int any = 0;
        while i < n && p[i] >= '0' && p[i] <= '9' {
            v = v * 10.0 + (double)(p[i] - '0');
            any = 1;
            i += 1;
        }
        if i < n && p[i] == '.' {
            i += 1;
            double scale = 0.1;
            while i < n && p[i] >= '0' && p[i] <= '9' {
                v = v + (double)(p[i] - '0') * scale;
                scale = scale / 10.0;
                any = 1;
                i += 1;
            }
        }
        if any == 0 { throw "not a number"; }
        if i < n && (p[i] == 'e' || p[i] == 'E') {
            i += 1;
            int eneg = 0;
            if i < n && (p[i] == '-' || p[i] == '+') {
                if p[i] == '-' { eneg = 1; }
                i += 1;
            }
            if i >= n || p[i] < '0' || p[i] > '9' { throw "not a number"; }
            int e = 0;
            while i < n && p[i] >= '0' && p[i] <= '9' {
                e = e * 10 + (p[i] - '0');
                i += 1;
            }
            while e > 0 {
                if eneg == 1 { v = v / 10.0; } else { v = v * 10.0; }
                e -= 1;
            }
        }
        while i < n && __Str::isspace(p[i]) { i += 1; }
        if i != n { throw "not a number"; }
        if neg == 1 { return 0.0 - v; }
        return v;
    }
    // a String[] with the pieces of s between the separators (an empty separator throws)
    static void^ split(void^ s, void^ sep, int ksep) {
        int nsep = __Str::len(sep, ksep);
        if nsep == 0 { __panic("split: the separator is empty"); }
        void^ r = __Arr::make(8, 4);
        int ns = __Str::len(s, 1);
        char^ ps = __Str::ptr(s, 1, 0);
        char^ pp = __Str::ptr(sep, ksep, 1);
        int start = 0;
        int i = 0;
        while i + nsep <= ns {
            int j = 0;
            while j < nsep && ps[i + j] == pp[j] { j += 1; }
            if j == nsep {
                __Str::apush(r, __Str::slice(s, start, i));
                i += nsep;
                start = i;
            } else {
                i += 1;
            }
        }
        __Str::apush(r, __Str::slice(s, start, ns));
        return r;
    }
    // a new String: the elements of a String[] with sep between them
    static void^ ajoin(void^ hv, void^ sep, int ksep) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        int^ el = (int^)h[2];
        void^ r = __Str::make(16);
        int i = 0;
        while i < h[0] {
            if i > 0 { __Str::append(r, sep, ksep); }
            __Str::append(r, (void^)el[i], 1);
            i += 1;
        }
        return r;
    }

    // ---- String[] : an array whose elements are String headers owned by the array
    // a deep copy of a String[] (every String is copied)
    static void^ aclone(void^ hv) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        void^ rv = __Arr::make(8, h[0]);
        int^ el = (int^)h[2];
        int i = 0;
        while i < h[0] {
            if el[i] == 0 {
                int^ slot = (int^)__Arr::slot(rv);
                slot[0] = 0;
            } else {
                __Str::apush(rv, __Str::clone((void^)el[i]));
            }
            i += 1;
        }
        return rv;
    }
    static void aprep(void^ hv) {
        if (int)hv == 0 { __panic("the array is null"); }
    }
    // the elements and the array are given back
    static void free_all(void^ hv) {
        int^ h = (int^)hv;
        if (int)h == 0 { return; }
        int^ el = (int^)h[2];
        int i = 0;
        while i < h[0] {
            __Arr::free((void^)el[i]);
            i += 1;
        }
        __Arr::free(hv);
    }
    static void clear_all(void^ hv) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        int^ el = (int^)h[2];
        int i = 0;
        while i < h[0] {
            __Arr::free((void^)el[i]);
            i += 1;
        }
        h[0] = 0;
    }
    // append s (the array takes it over)
    static void apush(void^ hv, void^ s) {
        __Str::aprep(hv);
        int^ slot = (int^)__Arr::slot(hv);
        slot[0] = (int)s;
    }
    // remove the last one and give it to the caller
    static void^ apop(void^ hv) {
        __Str::aprep(hv);
        int^ slot = (int^)__Arr::pop(hv);
        return (void^)slot[0];
    }
    // put s (taken over) at place i
    static void ainsert(void^ hv, int i, void^ s) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        if i < 0 || i > h[0] { __panic("insert position out of range"); }
        __Arr::grow(h, h[0] + 1);
        int^ el = (int^)h[2];
        int k = h[0];
        while k > i {
            el[k] = el[k - 1];
            k -= 1;
        }
        el[i] = (int)s;
        h[0] += 1;
    }
    // remove the one at place i (it is freed)
    static void aremove(void^ hv, int i) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        if i < 0 || i >= h[0] { __panic("remove position out of range"); }
        int^ el = (int^)h[2];
        __Arr::free((void^)el[i]);
        int k = i;
        while k + 1 < h[0] {
            el[k] = el[k + 1];
            k += 1;
        }
        h[0] -= 1;
    }
    // the place of the first element equal to the operand, or -1
    static int aindex(void^ hv, void^ x, int kx) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        int^ el = (int^)h[2];
        int i = 0;
        while i < h[0] {
            if __Str::eq((void^)el[i], 1, x, kx) == 1 { return i; }
            i += 1;
        }
        return 0 - 1;
    }
    // sort ascending (heap sort, no extra memory)
    static void asort(void^ hv) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        int^ el = (int^)h[2];
        int n = h[0];
        int start = n / 2 - 1;
        while start >= 0 {
            __Str::asift(el, start, n);
            start -= 1;
        }
        int end = n - 1;
        while end > 0 {
            int t = el[0];
            el[0] = el[end];
            el[end] = t;
            __Str::asift(el, 0, end);
            end -= 1;
        }
    }
    static void asift(int^ el, int root, int n) {
        while true {
            int child = root * 2 + 1;
            if child >= n { return; }
            if child + 1 < n && __Str::cmp((void^)el[child], (void^)el[child + 1]) < 0 { child += 1; }
            if __Str::cmp((void^)el[root], (void^)el[child]) >= 0 { return; }
            int t = el[root];
            el[root] = el[child];
            el[child] = t;
            root = child;
        }
    }
}

// Reading the keyboard (cin >> x, cinf >> x): a buffer over file descriptor 0.
char std_in_buf[4096];
int std_in_pos;
int std_in_len;

struct __In {
    // the next byte without taking it, or -1 at the end of the input
    static int peek() {
        if std_in_pos >= std_in_len {
            int n = syscall(63, 0, @std_in_buf, 4096);
            if n <= 0 { return -1; }
            std_in_len = n;
            std_in_pos = 0;
        }
        return std_in_buf[std_in_pos];
    }
    static bool space(int c) {
        return c == 32 || c == 9 || c == 10 || c == 13;
    }
    // skip white space: the first character of the next word, or -1
    static int start() {
        int c = __In::peek();
        while c >= 0 && __In::space(c) {
            std_in_pos += 1;
            c = __In::peek();
        }
        return c;
    }
    // a word into a String
    static void str(void^ h) {
        int c = __In::start();
        if c < 0 { throw "end of input"; }
        __Str::clear(h);
        while c >= 0 && !__In::space(c) {
            __Str::push(h, c);
            std_in_pos += 1;
            c = __In::peek();
        }
    }
    // a whole number (an error unless lo <= value <= hi; no limits when lo > hi; uns = 1: no minus sign)
    static int num(int lo, int hi, int uns) {
        int c = __In::start();
        if c < 0 { throw "end of input"; }
        int neg = 0;
        if c == '-' || c == '+' {
            if c == '-' { neg = 1; }
            std_in_pos += 1;
            c = __In::peek();
        }
        if c < '0' || c > '9' { throw "invalid input"; }
        if neg == 1 && uns == 1 { throw "invalid input"; }
        int v = 0;
        while c >= '0' && c <= '9' {
            v = v * 10 + (c - '0');
            std_in_pos += 1;
            c = __In::peek();
        }
        if c >= 0 && !__In::space(c) { throw "invalid input"; }
        if neg == 1 { v = 0 - v; }
        if lo <= hi && (v < lo || v > hi) { throw "number out of range"; }
        return v;
    }
    // a decimal number: 12  -3.5  .5  2e-3
    static double fnum() {
        int c = __In::start();
        if c < 0 { throw "end of input"; }
        int neg = 0;
        if c == '-' || c == '+' {
            if c == '-' { neg = 1; }
            std_in_pos += 1;
            c = __In::peek();
        }
        int mant = 0;
        int exp = 0;
        int seen = 0;
        while c >= '0' && c <= '9' {
            seen = 1;
            if mant < 100000000000000000 { mant = mant * 10 + (c - '0'); } else { exp += 1; }
            std_in_pos += 1;
            c = __In::peek();
        }
        if c == '.' {
            std_in_pos += 1;
            c = __In::peek();
            while c >= '0' && c <= '9' {
                seen = 1;
                if mant < 100000000000000000 {
                    mant = mant * 10 + (c - '0');
                    exp -= 1;
                }
                std_in_pos += 1;
                c = __In::peek();
            }
        }
        if seen == 0 { throw "invalid input"; }
        if c == 'e' || c == 'E' {
            std_in_pos += 1;
            c = __In::peek();
            int eneg = 0;
            if c == '-' || c == '+' {
                if c == '-' { eneg = 1; }
                std_in_pos += 1;
                c = __In::peek();
            }
            if c < '0' || c > '9' { throw "invalid input"; }
            int ev = 0;
            while c >= '0' && c <= '9' {
                if ev < 10000 { ev = ev * 10 + (c - '0'); }
                std_in_pos += 1;
                c = __In::peek();
            }
            if eneg == 1 { exp -= ev; } else { exp += ev; }
        }
        if c >= 0 && !__In::space(c) { throw "invalid input"; }
        double v = (double)mant;
        while exp > 0 {
            v = v * 10.0;
            exp -= 1;
        }
        while exp < 0 {
            v = v / 10.0;
            exp += 1;
        }
        if neg == 1 { v = -v; }
        return v;
    }
    // one character
    static int ch() {
        int c = __In::start();
        if c < 0 { throw "end of input"; }
        std_in_pos += 1;
        return c;
    }
    static int put(char^ buf, int at, char^ s) {
        int i = 0;
        while s[i] != 0 {
            buf[at] = s[i];
            at += 1;
            i += 1;
        }
        return at;
    }
    static int putnum(char^ buf, int at, int v) {
        char d[24];
        int n = 0;
        if v == 0 {
            d[0] = '0';
            n = 1;
        }
        while v > 0 {
            d[n] = '0' + v % 10;
            v = v / 10;
            n += 1;
        }
        while n > 0 {
            n -= 1;
            buf[at] = d[n];
            at += 1;
        }
        return at;
    }
    // a word into dst (room for cap characters including the 0): longer words are cut
    static int word(char^ dst, int cap, char^ name) {
        int c = __In::start();
        if c < 0 { throw "end of input"; }
        int n = 0;
        int cut = 0;
        while c >= 0 && !__In::space(c) {
            if n < cap - 1 {
                dst[n] = c;
                n += 1;
            } else {
                cut = 1;
            }
            std_in_pos += 1;
            c = __In::peek();
        }
        dst[n] = 0;
        if cut == 1 {
            char m[200];
            int at = __In::put(@m, 0, "warning: input truncated — '");
            at = __In::put(@m, at, name);
            at = __In::put(@m, at, "' accepts max ");
            at = __In::putnum(@m, at, cap - 1);
            at = __In::put(@m, at, " characters (char[");
            at = __In::putnum(@m, at, cap);
            at = __In::put(@m, at, "] - 1 for \\0)\n");
            syscall(64, 2, @m, at);
        }
        return n;
    }
}

// #multithread for i in a..b { ... }: the iterations are shared among several threads.
struct __Mt {
    // how many threads the machine can run at once (1 .. 16)
    static int cores() {
        char mask[128];
        int n = syscall(123, 0, 128, @mask);               // sched_getaffinity
        if n <= 0 { return 4; }
        int c = 0;
        for i in 0..n {
            int b = mask[i];
            while b != 0 {
                c += b & 1;
                b = b >> 1;
            }
        }
        if c < 1 { c = 1; }
        if c > 16 { c = 16; }
        return c;
    }
    // worker = the address of the compiled loop body (it gets a block [frame of the caller, from, to]);
    // runs it on several threads, each with its own part of lo..hi, and waits for all of them
    static void run(int worker, int fp, int lo, int hi) {
        int n = hi - lo;
        if n <= 0 { return; }
        int parts = __Mt::cores();
        if parts > n { parts = n; }
        int size = 1048576;
        int^ blk = (int^)Mem::alloc(parts * 64);          // per part: [0] frame [1] from [2] to [3] thread id [4] stack
        if (int)blk == 0 { __panic("out of memory"); }
        for p in 0..parts {
            blk[p * 8] = fp;
            blk[p * 8 + 1] = lo + n * p / parts;
            blk[p * 8 + 2] = lo + n * (p + 1) / parts;
            blk[p * 8 + 3] = 0;
            int base = syscall(222, 0, size, 3, 34, -1, 0);
            if base < 0 { throw "cannot start the threads of the #multithread loop"; }
            blk[p * 8 + 4] = base;
            int top = base + size - 1024;
            std_mt = 1;
            int tid = __thread_start(worker, (int)blk + p * 64, top, (int)blk + p * 64 + 24, top);
            if tid < 0 { throw "cannot start the threads of the #multithread loop"; }
        }
        for p in 0..parts {
            while blk[p * 8 + 3] != 0 {
                syscall(98, (int)blk + p * 64 + 24, 0, blk[p * 8 + 3], 0, 0, 0);
            }
            syscall(215, blk[p * 8 + 4], size);
        }
    }
}
