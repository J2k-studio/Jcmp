// The prelude: read in front of every program (unused functions are left out).
// Mem: a small heap. Every block has a 16-byte header: [size, next-free].
i64 std_heap_cur;
i64 std_heap_end;
i64 std_free_list;
i64 std_direct[64];                // blocks of 256 KB and more that have pages of their own (given back to the system by free)
i64 std_direct_n;
i64 std_mem_lock;                 // 0 free, 1 taken (threads share the heap)
i64 std_mt;                       // 1 once a thread was started: only then the heap is locked
i64 std_alloc_n;                  // blocks given out / given back (the -d build reports the difference at the end)
i64 std_free_n;
i64 std_cls[24] = {32, 48, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, 448, 512, 640, 768, 896, 1024, 1280, 1536, 1792, 2048, 2048};   // the size classes (with the header)
i64 std_cls_of[129] = {0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 11, 11, 12, 12, 12, 12, 13, 13, 13, 13, 14, 14, 14, 14, 15, 15, 15, 15, 15, 15, 15, 15, 16, 16, 16, 16, 16, 16, 16, 16, 17, 17, 17, 17, 17, 17, 17, 17, 18, 18, 18, 18, 18, 18, 18, 18, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22};     // by need / 16: the class of a block (-1: bigger than the biggest class)
i64 std_cls_exact[129] = {-1, -1, 0, 1, 2, 3, 4, 5, 6, -1, 7, -1, 8, -1, 9, -1, 10, -1, -1, -1, 11, -1, -1, -1, 12, -1, -1, -1, 13, -1, -1, -1, 14, -1, -1, -1, -1, -1, -1, -1, 15, -1, -1, -1, -1, -1, -1, -1, 16, -1, -1, -1, -1, -1, -1, -1, 17, -1, -1, -1, -1, -1, -1, -1, 18, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 19, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 20, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 21, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 22};  // by size / 16: the class whose size is exactly this, or -1
i64 std_free_cls[24];              // the free blocks of each class
i64 std_debug;                     // 1 in a -d build: the checks of Mem (a block freed twice, written after it was freed, the places of the leaks)
i64^ std_dbg_tab;                  // the live blocks in a -d build: [address, size, the function that made it], 32768 places (open addressing); 768 KB from mmap in debug_on (a big array here would push the arrays of the program far from the base of the globals)
i64 std_dbg_n;                     // how many live blocks the table holds
i64 std_dbg_full;                  // 1: the table was full once (the checks that need it are off)
i64 std_dbg_quar[64];              // the last blocks that were freed (a -d build keeps them filled with 221 for a while)
i64 std_dbg_qi;
i64 std_guard_n;                   // how many blocks of a -d build live in pages of their own (a guard page after each; at most 12000)

// a bug in the program (a null array, a position out of range, ...): say so and stop; try/catch cannot catch it
void __panic(char^ msg) {
    __flush();
    i64 n = 0;
    while msg[n] != 0 { n += 1; }
    syscall(64, 2, "panic: ", 7);
    syscall(64, 2, msg, n);
    syscall(64, 2, "\n", 1);
    // the functions that were running, innermost first (the frames are linked: [fp] = caller's fp, [fp + 8] = return address)
    i64^ fp = (i64^)__fp();
    i64^ tab = (i64^)__fntab();
    i64 depth = 0;
    while (i64)fp > 4096 && depth < 24 {
        i64 ret = fp[1];
        i64 best = 0 - 1;
        i64 k = 0;
        while tab[k * 2] != 0 {
            if tab[k * 2] < ret { best = k; }
            k += 1;
        }
        if best < 0 { break; }
        char^ name = (char^)tab[best * 2 + 1];
        syscall(64, 2, "  at ", 5);
        i64 i = 0;
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
        fp = (i64^)fp[0];
        depth += 1;
    }
    syscall(94, 134);
}


// Cpu: instructions of the CPU that have no other way in (the compiler puts the instruction where the call is)
struct Cpu {
    static void wait() { __cpu_wait(); }                  // wfi: sleep until an interrupt
    static void event() { __cpu_event(); }                // wfe: sleep until an event
    static void send_event() { __cpu_send_event(); }      // sev
    static void pause() { __cpu_pause(); }                // yield: "I am spinning" (pause on x86)
    static void nop() { __cpu_nop(); }
    // crc32 (the polynomial of zip / png / ethernet) and crc32c (Castagnoli: iSCSI, ext4): the crc so far and the next 8 bytes (or 1 byte);
    // they need  #require cpu "crc32"  (ARM64). Start with crc = 0xFFFFFFFF and flip the bits of the end result (~crc & 0xFFFFFFFF).
    static i64 crc32(i64 crc, i64 data) { return __cpu_crc32(crc, data); }
    static i64 crc32c(i64 crc, i64 data) { return __cpu_crc32c(crc, data); }
    static i64 crc32_u8(i64 crc, i64 data) { return __cpu_crc32_u8(crc, data); }
    static i64 crc32c_u8(i64 crc, i64 data) { return __cpu_crc32c_u8(crc, data); }
    // what `#require cpu "crc32"` runs at the start of main: the bits of AT_HWCAP (the auxiliary vector after the environment); bit 7 is crc32
    static void require_check() {
        i64 i = argc() + 1;
        while (i64)arg(i) != 0 { i += 1; }
        i += 1;
        i64 cap = 0;
        while (i64)arg(i) != 0 {
            if (i64)arg(i) == 16 { cap = (i64)arg(i + 1); }
            i += 2;
        }
        if ((cap >> 7) & 1) == 0 {
            char^ msg = "this program needs the CPU extension crc32 (#require cpu \"crc32\"), and this CPU does not have it\n";
            i64 n = 0;
            while msg[n] != 0 { n += 1; }
            syscall(64, 2, msg, n);
            syscall(93, 1);
        }
    }
    static void speculation_barrier() { __cpu_speculation_barrier(); }   // nothing after it runs ahead of the branches before it (dsb nsh + isb; Spectre)
    static void isb() { __cpu_isb(); }                    // the instructions after it see what happened before
    static i64 counter() { return __cpu_counter(); }      // the system counter (cntvct_el0): ticks since boot, no system call
    static i64 frequency() { return __cpu_frequency(); }  // its ticks per second
    static i64 id() { return __cpu_id(); }                // the number of this core
}

// Atomic: operations on a whole number in memory that no other thread can break (all are sequentially consistent)
struct Atomic {
    static i64 load(i64^ p) { return __atomic_load(p); }                  // ldar
    static void store(i64^ p, i64 v) { __atomic_store(p, v); }            // stlr
    static i64 add(i64^ p, i64 v) { return __fetch_add(p, v); }          // the value it had before
    static i64 sub(i64^ p, i64 v) { return __fetch_sub(p, v); }
    static i64 swap(i64^ p, i64 v) { return __xchg(p, v); }
    static i64 cas(i64^ p, i64 old, i64 nw) { return __cas(p, old, nw); }  // the value it had; it was changed if that is old
    static i64 bit_and(i64^ p, i64 v) { return __fetch_and(p, v); }
    static i64 bit_or(i64^ p, i64 v) { return __fetch_or(p, v); }
    static i64 bit_xor(i64^ p, i64 v) { return __fetch_xor(p, v); }
}

// Cache: the data cache by address (the line that holds the address)
struct Cache {
    static void clean(i64^ p) { __cache_clean(p); }                       // write the line back (dc cvac)
    static void invalidate(i64^ p) { __cache_invalidate(p); }             // throw the line away (dc ivac)
    static void clean_invalidate(i64^ p) { __cache_clean_invalidate(p); }
    static void prefetch(i64^ p) { __cache_prefetch(p); }                 // the line at the address is wanted soon (prfm pldl1keep; pld on ARM32); never an error
    static void zero(i64^ p) { __cache_zero(p); }                         // fill the block with zeros (dc zva)
    static void clean_code(i64^ p) { __cache_clean_code(p); }
    static void invalidate_code(i64^ p) { __cache_invalidate_code(p); }
}

// the results of the wide arithmetic of Bit (a function gives one struct: there is no tuple)
struct BitCarry { i64 sum; i64 c; }          // add_carry / sub_borrow: the result and the carry (the borrow) out, 0 or 1
struct BitWide { i64 lo; i64 hi; }           // mul_wide: the 128-bit product of two numbers (unsigned): the low and the high 64 bits
struct BitDivRem { i64 q; i64 r; }           // div_rem: the quotient and the remainder (signed, the quotient goes towards 0)

// Bit: the work on the bits of a whole number, each is one instruction of the CPU (the compiler puts the instruction where the call is)
struct Bit {
    // a + b + carry_in (0 or 1): the sum (cut to 64 bits) and the carry out. A number of many words is added word by word with it.
    static BitCarry add_carry(i64 a, i64 b, i64 jin) {
        BitCarry r;
        i64 top = 1 << 63;
        i64 s = a + b;
        i64 c = 0;
        if (s xor top) < (a xor top) { c = 1; }          // the sum is smaller than a (as unsigned numbers): it wrapped
        i64 s2 = s + jin;
        if jin == 1 && s2 == 0 { c = 1; }
        r.sum = s2;
        r.c = c;
        return r;
    }
    // a - b - borrow_in (0 or 1): the difference (cut to 64 bits) and the borrow out (1 when a < b + borrow_in as unsigned numbers)
    static BitCarry sub_borrow(i64 a, i64 b, i64 bin) {
        BitCarry r;
        i64 top = 1 << 63;
        i64 bw = 0;
        if (a xor top) < (b xor top) { bw = 1; }
        if a == b && bin == 1 { bw = 1; }
        r.sum = a - b - bin;
        r.c = bw;
        return r;
    }
    // the high 64 bits of the 128-bit product of a and b taken as unsigned numbers
    static i64 mul_hi(i64 a, i64 b) {
        i64 m = 4294967295;
        i64 a0 = a & m;
        i64 a1 = (a >> 32) & m;
        i64 b0 = b & m;
        i64 b1 = (b >> 32) & m;
        i64 p00 = a0 * b0;
        i64 p01 = a0 * b1;
        i64 p10 = a1 * b0;
        i64 p11 = a1 * b1;
        i64 mid = ((p00 >> 32) & m) + (p01 & m) + (p10 & m);
        return p11 + ((p01 >> 32) & m) + ((p10 >> 32) & m) + ((mid >> 32) & m);
    }
    // the whole 128-bit product (unsigned): lo = the low 64 bits, hi = the high 64 bits
    static BitWide mul_wide(i64 a, i64 b) {
        BitWide r;
        r.lo = a * b;
        r.hi = Bit::mul_hi(a, b);
        return r;
    }
    // a / b and a % b together (signed; b must not be 0)
    static BitDivRem div_rem(i64 a, i64 b) {
        BitDivRem r;
        r.q = a / b;
        r.r = a - r.q * b;
        return r;
    }
    // a + b that stops at the largest or the smallest number instead of wrapping (signed)
    static i64 add_sat(i64 a, i64 b) {
        i64 s = a + b;
        if ((a xor s) & (b xor s)) < 0 {
            if a < 0 { return 1 << 63; }
            return (1 << 63) - 1;
        }
        return s;
    }

    // how many bits 0 there are in front of the first bit 1 (64 for 0)
    static i64 clz(i64 x) { return __clz(x); }
    // how many bits 0 there are after the last bit 1 (64 for 0)
    static i64 ctz(i64 x) { return __ctz(x); }
    // how many bits are 1
    static i64 popcount(i64 x) { return __popcount(x); }
    // the bits turned left / right by k places (the bits that fall out come in on the other side; k is taken modulo 64)
    static i64 rotl(i64 x, i64 k) { return __rotl(x, k); }
    static i64 rotr(i64 x, i64 k) { return __rotr(x, k); }
    // the 8 bytes in the other order
    static i64 bswap(i64 x) { return __bswap(x); }
}


struct Mem {
    // the order of the memory accesses (dmb): barrier = all, barrier_read = loads before, barrier_write = stores before, barrier_full = dsb
    static void barrier() { __mem_barrier(); }
    static void barrier_read() { __mem_barrier_read(); }
    static void barrier_write() { __mem_barrier_write(); }
    static void barrier_full() { __mem_barrier_full(); }
    // the size class of a block of `need` bytes (header included, a multiple of 16): the smallest class that is big enough, or -1 if the
    // block is bigger than the biggest class
    static i64 class_of(i64 need) {
        return std_cls_of[need / 16];
    }
    // the class whose size is exactly `size`, or -1
    static i64 exact_class(i64 size) {
        if size > 2048 { return 0 - 1; }
        return std_cls_exact[size / 16];
    }
    // n bytes, not cleared (null if the system has no memory left)
    // The common case is written out here (one thread, a small block that a free list has): no other function is called.
    static void^ alloc(i64 n) {
        if (std_debug | std_mt) == 0 && n > 0 && n <= 2032 {
            i64 c = std_cls_of[(n + 31) >> 4];             // (n + 31) >> 4 is the size with the header in 16-byte steps
            i64 h = std_free_cls[c];
            if h != 0 {
                i64^ hd = (i64^)h;
                std_free_cls[c] = hd[1];
                hd[1] = 0;
                return (void^)(h + 16);                    // the counters of the leak report are kept only in the -d build (dbg_alloc)
            }
        }
        return Mem::alloc_general(n);
    }
    static void^ alloc_general(i64 n) {
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
    static i64 bump(i64 need) {
        if std_heap_cur + need > std_heap_end {
            i64 chunk = 1048576;
            if need > chunk { chunk = (need + 4095) / 4096 * 4096; }
            i64 base = syscall(222, 0, chunk, 3, 34, -1, 0);      // mmap: anonymous, read + write
            if base < 0 { return 0; }
            std_heap_cur = base;
            std_heap_end = base + chunk;
        }
        i64 blk = std_heap_cur;
        std_heap_cur = std_heap_cur + need;
        return blk;
    }
    // Small blocks (up to 2048 bytes with the header) have size classes: a list of free blocks for each size, so that alloc and free
    // take a few instructions. Bigger blocks are on one list, ordered by address: first fit, a block is split when the rest is at
    // least 64 bytes, and a freed block is joined with the free blocks next to it.
    static void^ alloc_raw(i64 n) {
        if n <= 0 { return null; }
        i64 need = ((n + 15) >> 4) * 16 + 16;
        if need > 2048 { return Mem::alloc_big(need); }
        i64 c = std_cls_of[need >> 4];
        i64 h = std_free_cls[c];
        if h != 0 {
            i64^ hd = (i64^)h;
            std_free_cls[c] = hd[1];
            hd[1] = 0;
            std_alloc_n += 1;
            return (void^)(h + 16);
        }
        return Mem::alloc_new(std_cls[c]);
    }
    // a new small block from the chunk
    static void^ alloc_new(i64 csize) {
        i64 blk = Mem::bump(csize);
        if blk == 0 { return null; }
        std_alloc_n += 1;
        i64^ head = (i64^)blk;
        head[0] = csize;
        head[1] = 0;
        return (void^)(blk + 16);
    }
    // a block of `need` bytes (more than 2048) from the list of big blocks, or from the chunk
    // a block of 256 KB or more: pages of its own, returned to the system when it is freed (null: the old way is used)
    static void^ alloc_direct(i64 need) {
        i64 len = (need + 4095) / 4096 * 4096;
        i64 mb = syscall(222, 0, len, 3, 34, -1, 0);
        if mb < 0 && mb > -4096 { return null; }
        i64^ mh = (i64^)mb;
        mh[0] = len;
        mh[1] = 0;
        i64 di = 0;
        while std_direct[di] != 0 { di += 1; }
        std_direct[di] = mb;
        std_direct_n += 1;
        std_alloc_n += 1;
        return (void^)(mb + 16);
    }
    // the block blk (size bytes with its header) is one of those? then it goes back to the system
    static bool free_direct(i64 blk, i64 size) {
        i64 dj = 0;
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
    static void^ alloc_big(i64 need) {
        if need >= 262144 && std_direct_n < 64 {
            void^ dr = Mem::alloc_direct(need);
            if (i64)dr != 0 { return dr; }
        }
        i64 prev = 0;
        i64 cur = std_free_list;
        while cur != 0 {
            i64^ hdr = (i64^)cur;
            if hdr[0] >= need {
                if hdr[0] - need >= 64 {
                    // split: the rest stays on the list in the place of this block
                    i64 rest = cur + need;
                    i64^ rh = (i64^)rest;
                    rh[0] = hdr[0] - need;
                    rh[1] = hdr[1];
                    hdr[0] = need;
                    if prev == 0 {
                        std_free_list = rest;
                    } else {
                        i64^ before = (i64^)prev;
                        before[1] = rest;
                    }
                } else if prev == 0 {
                    std_free_list = hdr[1];
                } else {
                    i64^ before2 = (i64^)prev;
                    before2[1] = hdr[1];
                }
                hdr[1] = 0;
                std_alloc_n += 1;
                return (void^)(cur + 16);
            }
            prev = cur;
            cur = hdr[1];
        }
        i64 nb = Mem::bump(need);
        if nb == 0 { return null; }
        std_alloc_n += 1;
        i64^ nh = (i64^)nb;
        nh[0] = need;
        nh[1] = 0;
        return (void^)(nb + 16);
    }
    // give a block from alloc back (null is ignored); the common case (one thread, a small block of a class) is written out here
    static void free(void^ p) {
        if (std_debug | std_mt) == 0 && (i64)p != 0 {
            i64 blk = (i64)p - 16;
            i64^ head = (i64^)blk;
            i64 size = head[0];
            if (size & 1) == 0 && size <= 2048 {
                i64 c = std_cls_exact[size >> 4];
                if c >= 0 {
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
        if (i64)p == 0 { return; }
        i64 blk = (i64)p - 16;
        i64^ head = (i64^)blk;
        i64 size = head[0];
        if (size & 1) != 0 {
            Mem::free_piece(blk);
            return;
        }
        std_free_n += 1;
        if size >= 262144 && std_direct_n > 0 {
            if Mem::free_direct(blk, size) { return; }
        }
        if size <= 2048 {
            i64 c = std_cls_exact[size >> 4];
            if c >= 0 {
                head[1] = std_free_cls[c];
                std_free_cls[c] = blk;
                return;
            }
        }
        Mem::free_big(blk);
    }
    // a big block: into the list in the order of the addresses, joined with the neighbours that are free
    static void free_big(i64 blk) {
        i64^ head = (i64^)blk;
        i64 prev = 0;
        i64 cur = std_free_list;
        while cur != 0 && cur < blk {
            prev = cur;
            i64^ ch = (i64^)cur;
            cur = ch[1];
        }
        head[1] = cur;
        if cur != 0 && blk + head[0] == cur {
            i64^ nx = (i64^)cur;
            head[0] = head[0] + nx[0];
            head[1] = nx[1];
        }
        if prev == 0 {
            std_free_list = blk;
        } else {
            i64^ pv = (i64^)prev;
            if prev + pv[0] == blk {
                pv[0] = pv[0] + head[0];
                pv[1] = head[1];
            } else {
                pv[1] = blk;
            }
        }
    }
    // like alloc, and every byte is 0
    static void^ alloc0(i64 n) {
        void^ r = Mem::alloc(n);
        if (i64)r != 0 { Mem::set(r, 0, n); }
        return r;
    }
    // A block can be a pool (alloc[int^ a = 32]): pieces are taken from it with alloc[a[12] >> int^ p]. A piece has a header of its own
    // [size + 1 (a piece) (+ 2 once it is given back), the pool]. The word `next` of the header of the pool holds, in its low 32 bits, how
    // many bytes are taken and, in its high 32 bits, the first piece that was given back (its place in the pool + 1; 0 = none; the
    // pieces are linked by the first word of their room). Freeing a piece gives back only that piece (the last one taken gives the room
    // back at once); freeing the pool frees everything. null if the pool has not that much room.
    static void^ take(void^ pool, i64 bytes) {
        if (i64)pool == 0 { return null; }
        i64^ ph = (i64^)((i64)pool - 16);
        i64 need = ((bytes + 15) >> 4) * 16 + 16;
        i64 used = ph[1] & 4294967295;
        i64 first = ph[1] >> 32;
        i64 prev = 0;
        i64 cur = first;
        while cur != 0 {
            i64 at0 = (i64)pool + cur - 1;
            i64^ cp = (i64^)at0;
            i64^ room = (i64^)(at0 + 16);
            if (cp[0] & -4) >= need {
                if prev == 0 { first = room[0]; } else { i64^ pr = (i64^)((i64)pool + prev - 1 + 16); pr[0] = room[0]; }
                cp[0] = cp[0] - 2;                             // a piece in use again
                ph[1] = used + first * 4294967296;
                return (void^)(at0 + 16);
            }
            prev = cur;
            cur = room[0];
        }
        if used + need > ph[0] - 16 { return null; }
        i64 at = (i64)pool + used;
        i64^ piece = (i64^)at;
        piece[0] = need + 1;
        piece[1] = (i64)pool;
        ph[1] = used + need + first * 4294967296;
        return (void^)(at + 16);
    }
    static void free_piece(i64 blk) {
        i64^ piece = (i64^)blk;
        if (piece[0] & 2) != 0 { return; }                // given back already
        piece[0] = piece[0] | 2;
        i64 size = piece[0] - 3;
        i64 pool = piece[1];
        i64^ ph = (i64^)(pool - 16);
        i64 used = ph[1] & 4294967295;
        i64 first = ph[1] >> 32;
        if blk + size == pool + used {
            ph[1] = (blk - pool) + first * 4294967296;     // the last piece: the room is free again
        } else {
            i64^ room = (i64^)(blk + 16);
            room[0] = first;
            ph[1] = used + ((blk - pool) + 1) * 4294967296;
        }
    }
    // p = a block of `bytes` bytes with the old content; slot is the address of p (grow[p = n])
    static void grow_slot(i64^ slot, i64 bytes) {
        i64 old = slot[0];
        if old == 0 {
            slot[0] = (i64)Mem::alloc(bytes);
            return;
        }
        i64^ oh = (i64^)(old - 16);
        i64 have = (oh[0] & -4) - 16;
        i64 nb = (i64)Mem::alloc(bytes);                       // an int, not a pointer variable: this function does not own the new block
        if nb == 0 { return; }
        i64 n = have;
        if bytes < n { n = bytes; }
        Mem::copy((void^)nb, (void^)old, n);
        Mem::free((void^)old);
        slot[0] = nb;
    }
    // free[p = n] in a -d build: the block must be able to hold n bytes
    static void check_size(void^ p, i64 bytes) {
        if (i64)p != 0 {
            i64^ h = (i64^)((i64)p - 16);
            if bytes > (h[0] & -4) - 16 { __panic("free[p = n]: the block is smaller than n"); }
        }
    }
    // ---- the checks of a -d build (the program calls debug_on first)
    static void debug_on() {
        std_debug = 1;
        std_dbg_tab = (i64^)syscall(222, 0, 786432, 3, 34, -1, 0);
        if (i64)std_dbg_tab < 0 && (i64)std_dbg_tab > -4096 { std_dbg_tab = null; std_dbg_full = 1; std_guard_n = 12000; }
    }
    static void dbg_text(char^ t) {
        i64 n = 0;
        while t[n] != 0 { n += 1; }
        syscall(64, 2, t, n);
    }
    static void dbg_num(i64 v) {
        char d[24];
        i64 k = 23;
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
        i64^ fp = (i64^)__fp();
        i64^ tab = (i64^)__fntab();
        i64 depth = 0;
        while (i64)fp > 4096 && depth < 12 {
            i64 ret = fp[1];
            i64 best = 0 - 1;
            i64 k = 0;
            while tab[k * 2] != 0 {
                if tab[k * 2] < ret { best = k; }
                k += 1;
            }
            if best < 0 { return "?"; }
            char^ name = (char^)tab[best * 2 + 1];
            bool lib = name[0] == '_' && name[1] == '_';
            if name[0] == 'M' && name[1] == 'e' && name[2] == 'm' && name[3] == '_' && name[4] == '_' { lib = true; }
            if !lib { return name; }
            fp = (i64^)fp[0];
            depth += 1;
        }
        return "?";
    }
    // the place of the block `addr` in the table, or -1 if it is not there
    static i64 dbg_find(i64 addr) {
        if (i64)std_dbg_tab == 0 { return 0 - 1; }
        i64 h = (addr >> 4) & 32767;
        i64 tries = 0;
        while tries < 32768 {
            i64 a = std_dbg_tab[h * 3];
            if a == addr { return h; }
            if a == 0 { return 0 - 1; }
            h = (h + 1) & 32767;
            tries += 1;
        }
        return 0 - 1;
    }
    // a place for the block `addr`: the first one that is free (never used, or a block that was freed), -1 if there is none
    static i64 dbg_free_place(i64 addr) {
        if (i64)std_dbg_tab == 0 { return 0 - 1; }
        i64 h = (addr >> 4) & 32767;
        i64 tries = 0;
        while tries < 32768 {
            i64 a = std_dbg_tab[h * 3];
            if a == 0 || a == 0 - 1 { return h; }
            h = (h + 1) & 32767;
            tries += 1;
        }
        return 0 - 1;
    }
    // -d: a block of its own pages that ends where a page that nobody may touch begins: a write or a read past its end is a fault at once,
    // and a freed block is made untouchable (a read or write after free is a fault at once too). The header is [size, 0] as for any block;
    // the table of the live blocks remembers (bit 40 of the size) that the block has pages of its own.
    static void^ dbg_guard_alloc(i64 n) {
        i64 sz = ((n + 15) >> 4) * 16;
        i64 pages = (sz + 16 + 4095) >> 12;
        i64 base = syscall(222, 0, (pages + 1) * 4096, 3, 34, -1, 0);
        if base < 0 && base > -4096 { return null; }
        syscall(226, base + pages * 4096, 4096, 0);
        i64 blk = base + pages * 4096 - sz;
        i64^ hh = (i64^)(blk - 16);
        hh[0] = sz + 16;
        hh[1] = 0;
        return (void^)blk;
    }
    static void^ dbg_alloc(i64 n) {
        void^ r = null;
        i64 guarded = 0;
        if n > 0 && std_guard_n < 12000 && std_mt == 0 && std_dbg_full == 0 {
            r = Mem::dbg_guard_alloc(n);
            if (i64)r != 0 {
                std_guard_n += 1;
                std_alloc_n += 1;
                guarded = 1;
            }
        }
        if (i64)r == 0 { r = Mem::alloc_locked(n); }
        if (i64)r != 0 {
            char^ where = Mem::dbg_where();
            i64^ hh = (i64^)((i64)r - 16);
            i64 sl = Mem::dbg_free_place((i64)r);
            if sl < 0 {
                std_dbg_full = 1;
            } else {
                std_dbg_n += 1;
                std_dbg_tab[sl * 3] = (i64)r;
                std_dbg_tab[sl * 3 + 1] = (hh[0] & -4) - 16 + guarded * 1099511627776;
                std_dbg_tab[sl * 3 + 2] = (i64)where;
            }
        }
        return r;
    }
    static void^ alloc_locked(i64 n) {
        if std_mt == 0 { return Mem::alloc_raw(n); }
        while __cas(@std_mem_lock, 0, 1) != 0 {
            syscall(124);
        }
        void^ r = Mem::alloc_raw(n);
        __xchg(@std_mem_lock, 0);
        return r;
    }
    // are the 221 that a freed block was filled with all there?
    static bool dbg_intact(i64 blk) {
        i64^ hh = (i64^)(blk - 16);
        i64 words = ((hh[0] & -4) - 16) / 8;
        i64^ w = (i64^)blk;
        i64 i = 0;
        while i < words {
            if w[i] != -2459565876494606883 { return false; }
            i += 1;
        }
        return true;
    }
    static void dbg_free(void^ p) {
        if (i64)p == 0 { return; }
        i64 gs = Mem::dbg_find((i64)p);
        if gs >= 0 {
            i64 gsz = std_dbg_tab[gs * 3 + 1];
            if gsz == 0 - 1 { __panic("free of a block that is not alive: freed twice"); }
            if gsz >= 1099511627776 {
                // a block with a guard page: the table keeps its place (marked as freed), no page of it may be touched again
                i64 size = gsz - 1099511627776;
                i64 pages = (size + 16 + 4095) >> 12;
                std_dbg_tab[gs * 3 + 1] = 0 - 1;
                std_dbg_n -= 1;
                std_free_n += 1;
                syscall(226, (i64)p + size - pages * 4096, pages * 4096, 0);
                return;
            }
        }
        i64^ hh = (i64^)((i64)p - 16);
        if (hh[0] & 1) != 0 {
            Mem::free_piece((i64)p - 16);
            return;
        }
        i64 sl = Mem::dbg_find((i64)p);
        if sl >= 0 {
            std_dbg_tab[sl * 3] = 0 - 1;                  // a place that held a block (the places after it stay reachable)
            std_dbg_n -= 1;
        } else if std_dbg_full == 0 {
            __panic("free of a block that is not alive: freed twice, or it did not come from alloc");
        }
        // filled with 221 and kept for a while: a write into it is found when it leaves
        i64 words = ((hh[0] & -4) - 16) / 8;
        i64^ w = (i64^)p;
        i64 i = 0;
        while i < words {
            w[i] = -2459565876494606883;
            i += 1;
        }
        i64 q = std_dbg_qi & 63;
        std_dbg_qi += 1;
        i64 old = std_dbg_quar[q];
        std_dbg_quar[q] = (i64)p;
        std_free_n += 1;
        if old != 0 {
            if !Mem::dbg_intact(old) { __panic("a block was written after it was freed"); }
            std_free_n -= 1;                               // free_raw counts it
            Mem::free_now((void^)old);
        }
    }
    // -d : at the end of main, say which blocks were never given back
    static void report() {
        i64 q = 0;
        i64 quarantined = 0;
        while q < 64 {
            if std_dbg_quar[q] != 0 {
                if !Mem::dbg_intact(std_dbg_quar[q]) { __panic("a block was written after it was freed"); }
                quarantined += 1;
            }
            q += 1;
        }
        i64 n = std_alloc_n - std_free_n;
        if n <= 0 { return; }
        Mem::dbg_text("debug: memory blocks never freed: ");
        Mem::dbg_num(n);
        Mem::dbg_text("\n");
        i64 shown = 0;
        i64 i = 0;
        while i < 32768 && shown < 20 {
            i64 a = std_dbg_tab[i * 3];
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
    static void set(void^ p, i64 value, i64 n) {
        char^ q = (char^)p;
        i64 i = 0;
        if n >= 8 {
            i64^ w = (i64^)p;
            i64 pat = (value & 255) * 72340172838076673;
            i64 words = n / 8;
            i64 j = 0;
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
    static void copy(void^ dst, void^ src, i64 n) {
        char^ d = (char^)dst;
        char^ s = (char^)src;
        i64 i = 0;
        if n >= 8 {
            i64^ dw = (i64^)dst;
            i64^ sw = (i64^)src;
            i64 words = n / 8;
            i64 j = 0;
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
    // The first data block is part of the block of the header (the data starts 32 bytes after it): one allocation for a new array.
    // When the array grows the data moves to a block of its own; `h[2] == h + 32` tells which one it is.
    static void^ make(i64 esize, i64 cap) {
        i64 c = cap;
        if c < 4 { c = 4; }
        i64 hv = (i64)Mem::alloc(32 + c * esize);         // a plain number, not a pointer variable: no cleanup record for it
        if hv == 0 { __panic("out of memory"); }
        i64^ h = (i64^)hv;
        h[0] = 0;
        h[1] = c;
        h[2] = hv + 32;
        h[3] = esize;
        return (void^)hv;
    }
    // room for at least `need` elements
    static void grow(i64^ h, i64 need) {
        if need <= h[1] { return; }
        i64 c = h[1] * 2;
        if c < need { c = need; }
        i64 nd = (i64)Mem::alloc(c * h[3]);
        if nd == 0 { __panic("out of memory"); }
        Mem::copy((void^)nd, (void^)h[2], h[0] * h[3]);
        if h[2] != (i64)h + 32 { Mem::free((void^)h[2]); }
        h[2] = nd;
        h[1] = c;
    }
    // append one element: returns the address of its (new) place
    static void^ slot(void^ hv) {
        i64^ h = (i64^)hv;
        if (i64)h == 0 { __panic("the dynamic array is null"); }
        __Arr::grow(h, h[0] + 1);
        i64 at = h[2] + h[0] * h[3];
        h[0] += 1;
        return (void^)at;
    }
    // remove the last element: returns the address where it still is
    static void^ pop(void^ hv) {
        i64^ h = (i64^)hv;
        if (i64)h == 0 { __panic("the dynamic array is null"); }
        if h[0] == 0 { __panic("pop from an empty array"); }
        h[0] -= 1;
        return (void^)(h[2] + h[0] * h[3]);
    }
    static void resize(void^ hv, i64 n) {
        i64^ h = (i64^)hv;
        if (i64)h == 0 { __panic("the dynamic array is null"); }
        if n < 0 { __panic("negative array size"); }
        __Arr::grow(h, n);
        if n > h[0] { Mem::set((void^)(h[2] + h[0] * h[3]), 0, (n - h[0]) * h[3]); }
        h[0] = n;
    }
    // ---- numbers in an array: kind 0 signed, 1 unsigned (also pointers), 2 float, 3 double
    // the bits of element i as a whole number (sign or zero extended; the IEEE bits for a float)
    static i64 get(i64^ h, i64 i, i64 kind) {
        char^ d = (char^)(h[2] + i * h[3]);
        i64 es = h[3];
        i64 v = 0;
        i64 k = es - 1;
        while k >= 0 {
            v = v * 256 + d[k];
            k -= 1;
        }
        if kind == 0 && es < 8 {
            i64 sh = 64 - es * 8;
            v = (v shl sh) shr sh;
        }
        return v;
    }
    static void put(i64^ h, i64 i, i64 bits) {
        char^ d = (char^)(h[2] + i * h[3]);
        i64 k = 0;
        while k < h[3] {
            d[k] = bits & 255;
            bits = bits shr 8;
            k += 1;
        }
    }
    // a before b ?
    static bool less(i64 a, i64 b, i64 kind) {
        if kind == 0 { return a < b; }
        if kind == 1 { return (a xor -9223372036854775807 - 1) < (b xor -9223372036854775807 - 1); }
        if kind == 2 {
            i64 x = a;
            i64 y = b;
            float^ fx = (float^)@x;
            float^ fy = (float^)@y;
            return fx[0] < fy[0];
        }
        i64 x2 = a;
        i64 y2 = b;
        double^ dx = (double^)@x2;
        double^ dy = (double^)@y2;
        return dx[0] < dy[0];
    }
    static void insert(void^ hv, i64 i, i64 bits) {
        if (i64)hv == 0 { __panic("the dynamic array is null"); }
        i64^ h = (i64^)hv;
        if i < 0 || i > h[0] { __panic("insert position out of range"); }
        __Arr::grow(h, h[0] + 1);
        i64 k = h[0];
        while k > i {
            __Arr::put(h, k, __Arr::get(h, k - 1, 1));
            k -= 1;
        }
        __Arr::put(h, i, bits);
        h[0] += 1;
    }
    static void remove(void^ hv, i64 i) {
        if (i64)hv == 0 { __panic("the dynamic array is null"); }
        i64^ h = (i64^)hv;
        if i < 0 || i >= h[0] { __panic("remove position out of range"); }
        i64 k = i;
        while k + 1 < h[0] {
            __Arr::put(h, k, __Arr::get(h, k + 1, 1));
            k += 1;
        }
        h[0] -= 1;
    }
    // the place of the first element equal to bits, or -1
    static i64 index(void^ hv, i64 bits, i64 kind) {
        if (i64)hv == 0 { __panic("the dynamic array is null"); }
        i64^ h = (i64^)hv;
        i64 i = 0;
        while i < h[0] {
            i64 e = __Arr::get(h, i, kind);
            if !__Arr::less(e, bits, kind) && !__Arr::less(bits, e, kind) { return i; }
            i += 1;
        }
        return 0 - 1;
    }
    static void sort(void^ hv, i64 kind) {
        if (i64)hv == 0 { __panic("the dynamic array is null"); }
        i64^ h = (i64^)hv;
        i64 n = h[0];
        i64 start = n / 2 - 1;
        while start >= 0 {
            __Arr::sift(h, start, n, kind);
            start -= 1;
        }
        i64 end = n - 1;
        while end > 0 {
            i64 t = __Arr::get(h, 0, kind);
            __Arr::put(h, 0, __Arr::get(h, end, kind));
            __Arr::put(h, end, t);
            __Arr::sift(h, 0, end, kind);
            end -= 1;
        }
    }
    static void sift(i64^ h, i64 root, i64 n, i64 kind) {
        while true {
            i64 child = root * 2 + 1;
            if child >= n { return; }
            if child + 1 < n && __Arr::less(__Arr::get(h, child, kind), __Arr::get(h, child + 1, kind), kind) { child += 1; }
            i64 a = __Arr::get(h, root, kind);
            i64 b = __Arr::get(h, child, kind);
            if !__Arr::less(a, b, kind) { return; }
            __Arr::put(h, root, b);
            __Arr::put(h, child, a);
            root = child;
        }
    }
    // a copy of an array of numbers / pointers
    static void^ clone(void^ hv) {
        if (i64)hv == 0 { __panic("the dynamic array is null"); }
        i64^ h = (i64^)hv;
        i64^ r = (i64^)__Arr::make(h[3], h[0]);
        Mem::copy((void^)r[2], (void^)h[2], h[0] * h[3]);
        r[0] = h[0];
        return (void^)r;
    }
    // a copy of an array whose elements own memory: the elements move to the copy, the old array is empty afterwards
    static void^ clone_move(void^ hv) {
        void^ r = __Arr::clone(hv);
        i64^ h = (i64^)hv;
        h[0] = 0;
        return r;
    }
    // every element is freed with f (a struct that frees itself), then the array
    static void free_each(void^ hv, void(void^)^ f) {
        i64^ h = (i64^)hv;
        if (i64)h == 0 { return; }
        i64 i = 0;
        while i < h[0] {
            f((void^)(h[2] + i * h[3]));
            i += 1;
        }
        __Arr::free(hv);
    }
    // give the elements and the header back (null is ignored)
    static void free(void^ hv) {
        i64^ h = (i64^)hv;
        if (i64)h == 0 { return; }
        if h[2] != (i64)h + 32 { Mem::free((void^)h[2]); }
        Mem::free(hv);
    }
}


// String: a dynamic array of char (header [length, capacity, data, 1]) whose data always ends
// in a 0 byte after the length, so that the data is also a C-style text (jout, c()).
// An operand is a text (kind 0), another String (kind 1) or one character (kind 2).
char std_str_ch[16];
struct __Str {
    static void^ make(i64 cap) {
        i64^ h = (i64^)__Arr::make(1, cap + 1);
        char^ d = (char^)h[2];
        d[0] = 0;
        return (void^)h;
    }
    static i64 textlen(char^ t) {
        i64 n = 0;
        while t[n] != 0 { n += 1; }
        return n;
    }
    static void check(void^ hv) {
        if (i64)hv == 0 { __panic("the String is null"); }
    }
    // the characters of an operand
    static char^ ptr(void^ x, i64 k, i64 slot) {
        if k == 1 {
            __Str::check(x);
            i64^ h = (i64^)x;
            return (char^)h[2];
        }
        if k == 2 {
            std_str_ch[slot * 8] = (i64)x;
            std_str_ch[slot * 8 + 1] = 0;
            return @std_str_ch + slot * 8;
        }
        return (char^)x;
    }
    static i64 len(void^ x, i64 k) {
        if k == 1 {
            __Str::check(x);
            i64^ h = (i64^)x;
            return h[0];
        }
        if k == 2 { return 1; }
        return __Str::textlen((char^)x);
    }
    // the whole number v written at the end of r (u = 1: v is read as an unsigned number)
    static void push_int(void^ r, i64 v, i64 u) {
        char d[24];
        i64 n = 0;
        i64 neg = 0;
        if u == 0 && v < 0 { neg = 1; }
        u64 m = (u64)v;
        if neg == 1 { m = (u64)0 - m; }
        if m == 0 {
            d[0] = '0';
            n = 1;
        }
        while m > 0 {
            d[n] = '0' + (i64)(m % 10);
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
    static void^ from_int(i64 v, i64 u) {
        void^ r = __Str::make(24);
        __Str::push_int(r, v, u);
        return r;
    }
    // a new String with one character
    static void^ from_char(i64 c) {
        void^ r = __Str::make(2);
        __Str::push(r, c);
        return r;
    }
    // the digits of n written with exactly `width` digits (leading zeros), without the trailing zeros: for the part after the point
    static void frac_digits(void^ r, i64 n, i64 width) {
        char d[24];
        i64 k = width;
        while k > 0 {
            k -= 1;
            d[k] = '0' + n % 10;
            n = n / 10;
        }
        i64 last = width;
        while last > 0 && d[last - 1] == '0' { last -= 1; }
        i64 i = 0;
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
            i64 e = 0;
            while x >= 10.0 {
                x = x / 10.0;
                e += 1;
            }
            while x < 1.0 {
                x = x * 10.0;
                e -= 1;
            }
            i64 d0 = (i64)x;
            i64 f = (i64)((x - (double)d0) * 1.0e14 + 0.5);
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
        i64 ip = (i64)x;
        double frac = x - (double)ip;
        // the number of digits after the point: 15 digits in all
        i64 fd = 15;
        i64 t = ip;
        while t > 0 {
            fd -= 1;
            t = t / 10;
        }
        if ip == 0 {
            double q = frac;
            i64 zeros = 0;
            while q < 0.1 && zeros < 6 {
                q = q * 10.0;
                zeros += 1;
            }
            fd = 15 + zeros;
        }
        if fd < 0 { fd = 0; }
        i64 pw = 1;
        i64 k = 0;
        while k < fd {
            pw = pw * 10;
            k += 1;
        }
        i64 f = (i64)(frac * (double)pw + 0.5);
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
        i64 n = __Str::textlen(t);
        i64^ h = (i64^)__Str::make(n);
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
    static void^ cat(void^ a, i64 ka, void^ b, i64 kb) {
        i64 na = __Str::len(a, ka);
        i64 nb = __Str::len(b, kb);
        i64^ h = (i64^)__Str::make(na + nb);
        char^ d = (char^)h[2];
        Mem::copy((void^)d, (void^)__Str::ptr(a, ka, 0), na);
        Mem::copy((void^)(d + na), (void^)__Str::ptr(b, kb, 1), nb);
        d[na + nb] = 0;
        h[0] = na + nb;
        return (void^)h;
    }
    // a followed by b, in a (returns a)
    static void^ append(void^ a, void^ b, i64 kb) {
        __Str::check(a);
        if kb == 1 && (i64)b == (i64)a {                 // s.append(s): the data may move
            void^ same = __Str::clone(a);
            __Str::append(a, same, 1);
            __Arr::free(same);
            return a;
        }
        i64^ h = (i64^)a;
        i64 nb = __Str::len(b, kb);
        char^ src = __Str::ptr(b, kb, 1);
        __Arr::grow(h, h[0] + nb + 1);
        Mem::copy((void^)(h[2] + h[0]), (void^)src, nb);
        h[0] += nb;
        char^ d = (char^)h[2];
        d[h[0]] = 0;
        return a;
    }
    static void push(void^ a, i64 c) {
        __Str::check(a);
        i64^ h = (i64^)a;
        __Arr::grow(h, h[0] + 2);
        char^ d = (char^)h[2];
        d[h[0]] = c;
        h[0] += 1;
        d[h[0]] = 0;
    }
    static i64 pop(void^ a) {
        __Str::check(a);
        i64^ h = (i64^)a;
        if h[0] == 0 { __panic("pop from an empty String"); }
        h[0] -= 1;
        char^ d = (char^)h[2];
        i64 c = d[h[0]];
        d[h[0]] = 0;
        return c;
    }
    static void clear(void^ a) {
        __Str::check(a);
        i64^ h = (i64^)a;
        h[0] = 0;
        char^ d = (char^)h[2];
        d[0] = 0;
    }
    // 1 if the two operands hold the same characters
    static i64 eq(void^ a, i64 ka, void^ b, i64 kb) {
        i64 na = __Str::len(a, ka);
        i64 nb = __Str::len(b, kb);
        if na != nb { return 0; }
        char^ pa = __Str::ptr(a, ka, 0);
        char^ pb = __Str::ptr(b, kb, 1);
        i64 i = 0;
        while i < na {
            if pa[i] != pb[i] { return 0; }
            i += 1;
        }
        return 1;
    }
    // -1, 0 or 1: a is before, the same as, or after b (by the codes of the bytes, like strcmp)
    static i64 order(void^ a, i64 ka, void^ b, i64 kb) {
        i64 na = __Str::len(a, ka);
        i64 nb = __Str::len(b, kb);
        char^ pa = __Str::ptr(a, ka, 0);
        char^ pb = __Str::ptr(b, kb, 1);
        i64 i = 0;
        while i < na && i < nb {
            i64 ca = pa[i] & 255;
            i64 cb = pb[i] & 255;
            if ca < cb { return 0 - 1; }
            if ca > cb { return 1; }
            i += 1;
        }
        if na < nb { return 0 - 1; }
        if na > nb { return 1; }
        return 0;
    }
    // the first place of t in s at or after `from`, or -1
    static i64 find(void^ s, void^ t, i64 kt) {
        i64 ns = __Str::len(s, 1);
        i64 nt = __Str::len(t, kt);
        char^ ps = __Str::ptr(s, 1, 0);
        char^ pt = __Str::ptr(t, kt, 1);
        i64 i = 0;
        while i + nt <= ns {
            i64 j = 0;
            while j < nt && ps[i + j] == pt[j] { j += 1; }
            if j == nt { return i; }
            i += 1;
        }
        return 0 - 1;
    }
    // a new String: the characters a .. b - 1
    static void^ slice(void^ s, i64 a, i64 b) {
        i64 n = __Str::len(s, 1);
        if a < 0 || b > n || a > b { __panic("String slice out of range"); }
        i64^ h = (i64^)__Str::make(b - a);
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
    static i64 hashint(i64 x) {
        i64 h = x * -7046029254386353131;
        return h xor (h shr 29);
    }
    static i64 hash(void^ s) {
        char^ p = __Str::ptr(s, 1, 0);
        i64 h = -3750763034362895579;
        i64 i = 0;
        while p[i] != 0 {
            h = (h xor p[i]) * 1099511628211;
            i += 1;
        }
        return h xor (h shr 29);
    }
    // String[]: n places (new ones are null, cut ones are freed)
    static void aresize(void^ hv, i64 n) {
        __Str::aprep(hv);
        i64^ h = (i64^)hv;
        if n < 0 { __panic("negative array size"); }
        i64^ el = (i64^)h[2];
        i64 i = n;
        while i < h[0] {
            __Arr::free((void^)el[i]);
            i += 1;
        }
        __Arr::grow(h, n);
        el = (i64^)h[2];
        i = h[0];
        while i < n {
            el[i] = 0;
            i += 1;
        }
        h[0] = n;
    }
    // -1, 0, 1: a before, equal to, after b (bytes)
    static i64 cmp(void^ a, void^ b) {
        char^ pa = __Str::ptr(a, 1, 0);
        char^ pb = __Str::ptr(b, 1, 1);
        i64 i = 0;
        while pa[i] != 0 && pa[i] == pb[i] { i += 1; }
        if pa[i] == pb[i] { return 0; }
        if pa[i] < pb[i] { return 0 - 1; }
        return 1;
    }

    // ---- more String functions (the bytes are treated as ASCII where case matters)
    static bool isspace(i64 c) {
        return c == 32 || c == 9 || c == 10 || c == 13;
    }
    // a new String: s without the white space at both ends
    static void^ trim(void^ s) {
        i64 n = __Str::len(s, 1);
        char^ p = __Str::ptr(s, 1, 0);
        i64 a = 0;
        i64 b = n;
        while a < b && __Str::isspace(p[a]) { a += 1; }
        while b > a && __Str::isspace(p[b - 1]) { b -= 1; }
        return __Str::slice(s, a, b);
    }
    // ---- UTF-8: len counts bytes; these work on characters (code points)
    // the upper case of a code point (ASCII, Latin-1, Latin Extended-A, Greek, Cyrillic); others stay
    static i64 cp_upper(i64 c) {
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
    static i64 cp_lower(i64 c) {
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
    static void map_case(void^ r, i64 up) {
        char^ p = __Str::ptr(r, 1, 0);
        i64 i = 0;
        while p[i] != 0 {
            i64 b = p[i] & 255;
            if b < 128 {
                if up == 1 { p[i] = (char)__Str::cp_upper(b); } else { p[i] = (char)__Str::cp_lower(b); }
                i += 1;
            } else if b >= 0xC2 && b <= 0xDF && (p[i + 1] & 0xC0) == 0x80 {
                i64 c = ((b & 0x1F) << 6) | (p[i + 1] & 0x3F);
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
    static i64 count(void^ s) {
        char^ p = __Str::ptr(s, 1, 0);
        i64 n = __Str::len(s, 1);
        i64 k = 0;
        i64 i = 0;
        while i < n {
            if (p[i] & 0xC0) != 0x80 { k += 1; }
            i += 1;
        }
        return k;
    }
    // the size in bytes of the character that starts at byte i
    static i64 cp_size(char^ p, i64 i, i64 n) {
        i64 b = p[i] & 255;
        i64 k = 1;
        if b >= 0xF0 { k = 4; } else if b >= 0xE0 { k = 3; } else if b >= 0xC0 { k = 2; }
        if i + k > n { k = n - i; }
        return k;
    }
    // a String[] with every character as a String of its own
    static void^ chars(void^ s) {
        void^ r = __Arr::make(8, 4);
        char^ p = __Str::ptr(s, 1, 0);
        i64 n = __Str::len(s, 1);
        i64 i = 0;
        while i < n {
            i64 k = __Str::cp_size(p, i, n);
            __Str::apush(r, __Str::slice(s, i, i + k));
            i += k;
        }
        return r;
    }
    // the character number idx (counted from 0) as a String
    static void^ char_at(void^ s, i64 idx) {
        char^ p = __Str::ptr(s, 1, 0);
        i64 n = __Str::len(s, 1);
        i64 i = 0;
        i64 k = 0;
        while i < n {
            i64 sz = __Str::cp_size(p, i, n);
            if k == idx { return __Str::slice(s, i, i + sz); }
            i += sz;
            k += 1;
        }
        __panic("char_at: the position is out of range");
        return __Str::make(1);
    }
    static i64 starts_with(void^ s, void^ x, i64 kx) {
        i64 ns = __Str::len(s, 1);
        i64 nx = __Str::len(x, kx);
        if nx > ns { return 0; }
        char^ ps = __Str::ptr(s, 1, 0);
        char^ px = __Str::ptr(x, kx, 1);
        i64 i = 0;
        while i < nx {
            if ps[i] != px[i] { return 0; }
            i += 1;
        }
        return 1;
    }
    static i64 ends_with(void^ s, void^ x, i64 kx) {
        i64 ns = __Str::len(s, 1);
        i64 nx = __Str::len(x, kx);
        if nx > ns { return 0; }
        char^ ps = __Str::ptr(s, 1, 0);
        char^ px = __Str::ptr(x, kx, 1);
        i64 i = 0;
        while i < nx {
            if ps[ns - nx + i] != px[i] { return 0; }
            i += 1;
        }
        return 1;
    }
    // a new String: every a in s replaced by b
    static void^ replace(void^ s, void^ a, i64 ka, void^ b, i64 kb) {
        i64 na = __Str::len(a, ka);
        if na == 0 { __panic("replace: the text to look for is empty"); }
        void^ r = __Str::make(__Str::len(s, 1));
        i64 ns = __Str::len(s, 1);
        char^ ps = __Str::ptr(s, 1, 0);
        char^ pa = __Str::ptr(a, ka, 1);
        i64 i = 0;
        while i < ns {
            i64 j = 0;
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
    static void^ repeat(void^ s, i64 n) {
        void^ r = __Str::make(__Str::len(s, 1) * (n + 1));
        i64 i = 0;
        while i < n {
            __Str::append(r, s, 1);
            i += 1;
        }
        return r;
    }
    // the whole String as a number (an optional sign and digits); throws "not a number"
    static i64 to_int(void^ s) {
        char^ p = __Str::ptr(s, 1, 0);
        i64 n = __Str::len(s, 1);
        i64 i = 0;
        while i < n && __Str::isspace(p[i]) { i += 1; }
        i64 neg = 0;
        if i < n && (p[i] == '-' || p[i] == '+') {
            if p[i] == '-' { neg = 1; }
            i += 1;
        }
        if i >= n || p[i] < '0' || p[i] > '9' { throw "not a number"; }
        i64 v = 0;
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
        i64 n = __Str::len(s, 1);
        i64 i = 0;
        while i < n && __Str::isspace(p[i]) { i += 1; }
        i64 neg = 0;
        if i < n && (p[i] == '-' || p[i] == '+') {
            if p[i] == '-' { neg = 1; }
            i += 1;
        }
        double v = 0.0;
        i64 any = 0;
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
            i64 eneg = 0;
            if i < n && (p[i] == '-' || p[i] == '+') {
                if p[i] == '-' { eneg = 1; }
                i += 1;
            }
            if i >= n || p[i] < '0' || p[i] > '9' { throw "not a number"; }
            i64 e = 0;
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
    static void^ split(void^ s, void^ sep, i64 ksep) {
        i64 nsep = __Str::len(sep, ksep);
        if nsep == 0 { __panic("split: the separator is empty"); }
        void^ r = __Arr::make(8, 4);
        i64 ns = __Str::len(s, 1);
        char^ ps = __Str::ptr(s, 1, 0);
        char^ pp = __Str::ptr(sep, ksep, 1);
        i64 start = 0;
        i64 i = 0;
        while i + nsep <= ns {
            i64 j = 0;
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
    static void^ ajoin(void^ hv, void^ sep, i64 ksep) {
        __Str::aprep(hv);
        i64^ h = (i64^)hv;
        i64^ el = (i64^)h[2];
        void^ r = __Str::make(16);
        i64 i = 0;
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
        i64^ h = (i64^)hv;
        void^ rv = __Arr::make(8, h[0]);
        i64^ el = (i64^)h[2];
        i64 i = 0;
        while i < h[0] {
            if el[i] == 0 {
                i64^ slot = (i64^)__Arr::slot(rv);
                slot[0] = 0;
            } else {
                __Str::apush(rv, __Str::clone((void^)el[i]));
            }
            i += 1;
        }
        return rv;
    }
    static void aprep(void^ hv) {
        if (i64)hv == 0 { __panic("the array is null"); }
    }
    // the elements and the array are given back
    static void free_all(void^ hv) {
        i64^ h = (i64^)hv;
        if (i64)h == 0 { return; }
        i64^ el = (i64^)h[2];
        i64 i = 0;
        while i < h[0] {
            __Arr::free((void^)el[i]);
            i += 1;
        }
        __Arr::free(hv);
    }
    static void clear_all(void^ hv) {
        __Str::aprep(hv);
        i64^ h = (i64^)hv;
        i64^ el = (i64^)h[2];
        i64 i = 0;
        while i < h[0] {
            __Arr::free((void^)el[i]);
            i += 1;
        }
        h[0] = 0;
    }
    // append s (the array takes it over)
    static void apush(void^ hv, void^ s) {
        __Str::aprep(hv);
        i64^ slot = (i64^)__Arr::slot(hv);
        slot[0] = (i64)s;
    }
    // remove the last one and give it to the caller
    static void^ apop(void^ hv) {
        __Str::aprep(hv);
        i64^ slot = (i64^)__Arr::pop(hv);
        return (void^)slot[0];
    }
    // put s (taken over) at place i
    static void ainsert(void^ hv, i64 i, void^ s) {
        __Str::aprep(hv);
        i64^ h = (i64^)hv;
        if i < 0 || i > h[0] { __panic("insert position out of range"); }
        __Arr::grow(h, h[0] + 1);
        i64^ el = (i64^)h[2];
        i64 k = h[0];
        while k > i {
            el[k] = el[k - 1];
            k -= 1;
        }
        el[i] = (i64)s;
        h[0] += 1;
    }
    // remove the one at place i (it is freed)
    static void aremove(void^ hv, i64 i) {
        __Str::aprep(hv);
        i64^ h = (i64^)hv;
        if i < 0 || i >= h[0] { __panic("remove position out of range"); }
        i64^ el = (i64^)h[2];
        __Arr::free((void^)el[i]);
        i64 k = i;
        while k + 1 < h[0] {
            el[k] = el[k + 1];
            k += 1;
        }
        h[0] -= 1;
    }
    // the place of the first element equal to the operand, or -1
    static i64 aindex(void^ hv, void^ x, i64 kx) {
        __Str::aprep(hv);
        i64^ h = (i64^)hv;
        i64^ el = (i64^)h[2];
        i64 i = 0;
        while i < h[0] {
            if __Str::eq((void^)el[i], 1, x, kx) == 1 { return i; }
            i += 1;
        }
        return 0 - 1;
    }
    // sort ascending (heap sort, no extra memory)
    static void asort(void^ hv) {
        __Str::aprep(hv);
        i64^ h = (i64^)hv;
        i64^ el = (i64^)h[2];
        i64 n = h[0];
        i64 start = n / 2 - 1;
        while start >= 0 {
            __Str::asift(el, start, n);
            start -= 1;
        }
        i64 end = n - 1;
        while end > 0 {
            i64 t = el[0];
            el[0] = el[end];
            el[end] = t;
            __Str::asift(el, 0, end);
            end -= 1;
        }
    }
    static void asift(i64^ el, i64 root, i64 n) {
        while true {
            i64 child = root * 2 + 1;
            if child >= n { return; }
            if child + 1 < n && __Str::cmp((void^)el[child], (void^)el[child + 1]) < 0 { child += 1; }
            if __Str::cmp((void^)el[root], (void^)el[child]) >= 0 { return; }
            i64 t = el[root];
            el[root] = el[child];
            el[child] = t;
            root = child;
        }
    }
}


// Reading the keyboard (jin >> x, cinf >> x): a buffer over file descriptor 0.
char std_in_buf[4096];
i64 std_in_pos;
i64 std_in_len;
char std_in_err[160];              // the text of the last input error (thrown; it must stay alive while the stack is unwound)
i64 std_in_en;

struct __In {
    // the next byte without taking it, or -1 at the end of the input
    static i64 peek() {
        if std_in_pos >= std_in_len {
            i64 n = syscall(63, 0, @std_in_buf, 4096);
            if n <= 0 { return -1; }
            std_in_len = n;
            std_in_pos = 0;
        }
        return std_in_buf[std_in_pos];
    }
    static bool space(i64 c) {
        return c == 32 || c == 9 || c == 10 || c == 13;
    }
    static void err_put(char^ s) {
        i64 i = 0;
        while s[i] != 0 && std_in_en < 150 {
            std_in_err[std_in_en] = s[i];
            std_in_en += 1;
            i += 1;
        }
        std_in_err[std_in_en] = 0;
    }
    // throw "invalid input: <what> was expected, but found 'x'": c is the character that was found. The wrong word stays in the input
    // (a program that catches the error skips it with  jin >> word;  see test t173)
    static void bad(char^ what, i64 c) {
        std_in_en = 0;
        __In::err_put("invalid input: ");
        __In::err_put(what);
        __In::err_put(" was expected, but found ");
        if c < 0 || c == 10 || c == 13 {
            __In::err_put("the end of the line");
        } else {
            char one[4];
            one[0] = 39;
            one[1] = (char)c;
            one[2] = 39;
            one[3] = 0;
            __In::err_put((char^)@one);
        }
        throw (char^)@std_in_err;
    }
    // skip white space: the first character of the next word, or -1
    static i64 start() {
        i64 c = __In::peek();
        while c >= 0 && __In::space(c) {
            std_in_pos += 1;
            c = __In::peek();
        }
        return c;
    }
    // a word into a String
    static void str(void^ h) {
        i64 c = __In::start();
        if c < 0 { throw "end of input: a word was expected, but the input has ended"; }
        __Str::clear(h);
        while c >= 0 && !__In::space(c) {
            __Str::push(h, c);
            std_in_pos += 1;
            c = __In::peek();
        }
    }
    // a whole number (an error unless lo <= value <= hi; no limits when lo > hi; uns = 1: no minus sign)
    static i64 num(i64 lo, i64 hi, i64 uns) {
        i64 c = __In::start();
        if c < 0 { throw "end of input: a whole number was expected, but the input has ended"; }
        i64 neg = 0;
        if c == '-' || c == '+' {
            if c == '-' { neg = 1; }
            std_in_pos += 1;
            c = __In::peek();
        }
        if c < '0' || c > '9' { __In::bad("a whole number", c); }
        if neg == 1 && uns == 1 { __In::bad("a number without a minus sign", '-'); }
        i64 v = 0;
        while c >= '0' && c <= '9' {
            v = v * 10 + (c - '0');
            std_in_pos += 1;
            c = __In::peek();
        }
        if c >= 0 && !__In::space(c) { __In::bad("the end of the number", c); }
        if neg == 1 { v = 0 - v; }
        if lo <= hi && (v < lo || v > hi) { throw "number out of range for this variable (the type cannot hold it)"; }
        return v;
    }
    // a decimal number: 12  -3.5  .5  2e-3
    static double fnum() {
        i64 c = __In::start();
        if c < 0 { throw "end of input: a number was expected, but the input has ended"; }
        i64 neg = 0;
        if c == '-' || c == '+' {
            if c == '-' { neg = 1; }
            std_in_pos += 1;
            c = __In::peek();
        }
        i64 mant = 0;
        i64 exp = 0;
        i64 seen = 0;
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
        if seen == 0 { __In::bad("a number", c); }
        if c == 'e' || c == 'E' {
            std_in_pos += 1;
            c = __In::peek();
            i64 eneg = 0;
            if c == '-' || c == '+' {
                if c == '-' { eneg = 1; }
                std_in_pos += 1;
                c = __In::peek();
            }
            if c < '0' || c > '9' { __In::bad("the digits of the exponent", c); }
            i64 ev = 0;
            while c >= '0' && c <= '9' {
                if ev < 10000 { ev = ev * 10 + (c - '0'); }
                std_in_pos += 1;
                c = __In::peek();
            }
            if eneg == 1 { exp -= ev; } else { exp += ev; }
        }
        if c >= 0 && !__In::space(c) { __In::bad("the end of the number", c); }
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
    static i64 ch() {
        i64 c = __In::start();
        if c < 0 { throw "end of input"; }
        std_in_pos += 1;
        return c;
    }
    static i64 put(char^ buf, i64 at, char^ s) {
        i64 i = 0;
        while s[i] != 0 {
            buf[at] = s[i];
            at += 1;
            i += 1;
        }
        return at;
    }
    static i64 putnum(char^ buf, i64 at, i64 v) {
        char d[24];
        i64 n = 0;
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
    static i64 word(char^ dst, i64 cap, char^ name) {
        i64 c = __In::start();
        if c < 0 { throw "end of input"; }
        i64 n = 0;
        i64 cut = 0;
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
            i64 at = __In::put(@m, 0, "warning: input truncated — '");
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


// Printing a double that is 2^64 or more (coutf calls this from j2k_print_f64): d.dddddde+NN, the sign is written by the caller.

// ---- the standard output is buffered (64 KB in the global area: the word 110 = bytes used, 111 = the mode: 0 not looked at,
// 1 buffered, 2 not buffered). A terminal is not buffered (a program that talks to a person); a thread makes it unbuffered.
// It is written out at the end of the program, before the standard error text of a panic / uncaught exception / crash, before a new process
// (fork / execve) and before Sys::write.
void __flush() {
    i64^ g = (i64^)__gl();
    i64 n = g[110];
    g[110] = 0;
    i64 off = 0;
    while off < n {
        i64 r = syscall(64, 1, (char^)(__gl() + 896 + off), n - off);
        if r <= 0 { break; }
        off += r;
    }
}

// the same as write(fd, p, n) for the program's output
void __wr(i64 fd, char^ p, i64 n) {
    if fd != 1 {
        syscall(64, fd, p, n);
        return;
    }
    i64^ g = (i64^)__gl();
    i64 mode = g[111];
    if mode == 0 {
        char t[64];
        mode = 1;
        if syscall(29, 1, 21505, @t) == 0 { mode = 2; }
        g[111] = mode;
    }
    if mode == 2 {
        i64 off = 0;
        while off < n {
            i64 r = syscall(64, 1, p + off, n - off);
            if r <= 0 { break; }
            off += r;
        }
        return;
    }
    if g[110] + n > 16384 { __flush(); }
    if n >= 16384 {
        i64 off2 = 0;
        while off2 < n {
            i64 r2 = syscall(64, 1, p + off2, n - off2);
            if r2 <= 0 { break; }
            off2 += r2;
        }
        return;
    }
    char^ dst = (char^)(__gl() + 896 + g[110]);
    for i in 0..n { dst[i] = p[i]; }
    g[110] += n;
}

// a thread is made: from now on every write goes straight out (no lock around the buffer)
void __out_unbuffer() {
    __flush();
    i64^ g = (i64^)__gl();
    g[111] = 2;
}

// jout << a bool: true or false
void __print_bool(i64 v) {
    if v != 0 {
        __wr(__out_fd(), "true", 4);
    } else {
        __wr(__out_fd(), "false", 5);
    }
}

// jout << a pointer or an address: 0x and the digits in hex (0x0 for null)
void __print_ptr(i64 v) {
    char buf[24];
    i64 at = 22;
    if v == 0 {
        buf[at] = '0';
        at -= 1;
    }
    i64 x = v;
    i64 k = 0;
    while k < 16 && x != 0 {
        i64 d = x & 15;
        if d < 10 { buf[at] = (char)(48 + d); } else { buf[at] = (char)(87 + d); }
        at -= 1;
        x = (x >> 4) & 1152921504606846975;
        k += 1;
    }
    buf[at] = 'x';
    at -= 1;
    buf[at] = '0';
    at -= 1;
    __wr(__out_fd(), @buf[at + 1], 22 - at);
}

// the file that jout writes to: 1, or 2 inside a statement with jerr (the word at 864 of the global area, 0 or 1, plus 1)
i64 __out_fd() {
    i64^ gout = (i64^)__gl();
    return gout[108] + 1;
}

struct __Fp {
    static void huge(i64 bits) {
        double fl[1];
        i64^ fb = (i64^)@fl[0];
        fb[0] = bits;
        double d = fl[0];
        i64 e10 = 0;
        while d >= 1.0e23 {
            d = d / 1.0e22;
            e10 += 22;
        }
        while d >= 10.0 {
            d = d / 10.0;
            e10 += 1;
        }
        i64 m = (i64)(d * 1000000.0 + 0.5);
        if m >= 10000000 {
            m = m / 10;
            e10 += 1;
        }
        char buf[32];
        i64 n = 0;
        buf[n] = (char)(48 + m / 1000000);
        n += 1;
        buf[n] = '.';
        n += 1;
        i64 div = 100000;
        while div > 0 {
            buf[n] = (char)(48 + m / div % 10);
            n += 1;
            div = div / 10;
        }
        buf[n] = 'e';
        n += 1;
        buf[n] = '+';
        n += 1;
        if e10 >= 100 {
            buf[n] = (char)(48 + e10 / 100);
            n += 1;
        }
        buf[n] = (char)(48 + e10 / 10 % 10);
        n += 1;
        buf[n] = (char)(48 + e10 % 10);
        n += 1;
        __wr(__out_fd(), @buf, n);
    }
}

// #multithread for i in a..b { ... }: the iterations are shared among several threads.
struct __Mt {
    // how many threads the machine can run at once (1 .. 16)
    static i64 cores() {
        char mask[128];
        i64 n = syscall(123, 0, 128, @mask);               // sched_getaffinity
        if n <= 0 { return 4; }
        i64 c = 0;
        for i in 0..n {
            i64 b = mask[i];
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
    static void run(i64 worker, i64 fp, i64 lo, i64 hi) {
        i64 n = hi - lo;
        if n <= 0 { return; }
        i64 parts = __Mt::cores();
        if parts > n { parts = n; }
        i64 size = 1048576;
        i64^ blk = (i64^)Mem::alloc(parts * 64);          // per part: [0] frame [1] from [2] to [3] thread id [4] stack
        if (i64)blk == 0 { __panic("out of memory"); }
        for p in 0..parts {
            blk[p * 8] = fp;
            blk[p * 8 + 1] = lo + n * p / parts;
            blk[p * 8 + 2] = lo + n * (p + 1) / parts;
            blk[p * 8 + 3] = 0;
            i64 base = syscall(222, 0, size, 3, 34, -1, 0);
            if base < 0 { throw "cannot start the threads of the #multithread loop"; }
            blk[p * 8 + 4] = base;
            i64 top = base + size - 1024;
            std_mt = 1;
            __out_unbuffer();
            i64 tid = __thread_start(worker, (i64)blk + p * 64, top, (i64)blk + p * 64 + 24, top);
            if tid < 0 { throw "cannot start the threads of the #multithread loop"; }
        }
        for p in 0..parts {
            while blk[p * 8 + 3] != 0 {
                syscall(98, (i64)blk + p * 64 + 24, 0, blk[p * 8 + 3], 0, 0, 0);
            }
            syscall(215, blk[p * 8 + 4], size);
        }
    }
}

// The routines that the ARM32 target needs and that the ARM64 target has as assembly in the compiler (docs/design/15-arm32.md).
// They are written in J2K and made by the same back end as the program; the compiler calls them by name (__a32_*) for the operations that
// a 32 bit machine has no instruction for (division, the high half of a product) and for the printing of jout.
// Nothing here is used by the ARM64 target: a function that nobody calls is not made.

// unsigned 64-bit a / b, a % b (0 when b is 0); the numbers below 2^52 are divided as doubles (exact: a / b is never rounded up to the next
// whole number when a < 2^52), the others by shift and subtract
i64 __a32_udiv(i64 a, i64 b) {
    if b == 0 { return 0; }
    if a >= 0 && a < 4503599627370496 && b > 0 && b < 4503599627370496 {
        double da = (double)a;
        double db = (double)b;
        return (i64)(da / db);
    }
    i64 top = 1 << 63;
    i64 bt = b xor top;
    i64 q = 0;
    i64 r = 0;
    i64 i = 63;
    while i >= 0 {
        i64 carry = (r >> 63) & 1;
        r = (r << 1) | ((a >> i) & 1);
        if carry == 1 || (r xor top) >= bt {
            r = r - b;
            q = q | (1 << i);
        }
        i -= 1;
    }
    return q;
}

i64 __a32_umod(i64 a, i64 b) {
    if b == 0 { return 0; }
    if a >= 0 && a < 4503599627370496 && b > 0 && b < 4503599627370496 {
        double da = (double)a;
        double db = (double)b;
        i64 q = (i64)(da / db);
        return a - q * b;
    }
    i64 top = 1 << 63;
    i64 bt = b xor top;
    i64 r = 0;
    i64 i = 63;
    while i >= 0 {
        i64 carry = (r >> 63) & 1;
        r = (r << 1) | ((a >> i) & 1);
        if carry == 1 || (r xor top) >= bt {
            r = r - b;
        }
        i -= 1;
    }
    return r;
}

// signed division: the quotient goes towards 0, the remainder has the sign of a
i64 __a32_sdiv(i64 a, i64 b) {
    if b == 0 { return 0; }
    i64 neg = 0;
    if a < 0 { a = 0 - a; neg = 1 - neg; }
    if b < 0 { b = 0 - b; neg = 1 - neg; }
    i64 q = __a32_udiv(a, b);
    if neg == 1 { return 0 - q; }
    return q;
}

i64 __a32_smod(i64 a, i64 b) {
    if b == 0 { return 0; }
    i64 neg = 0;
    if a < 0 { a = 0 - a; neg = 1; }
    if b < 0 { b = 0 - b; }
    i64 r = __a32_umod(a, b);
    if neg == 1 { return 0 - r; }
    return r;
}

// __a32_mulhs (the high 64 bits of the signed 128-bit product a * b) is a routine by hand in the back end (jc_a32.j, a32_emit_exc)

// the start: the stack has 4-byte words (argc, the pointers of argv, 0, the pointers of the environment, 0); the programs (argc(), arg(i), Env)
// read 8-byte words: a copy in that form is made and the entry gives its address to the global area
i64 __a32_fixargs(i64 sp) {
    i32^ old = (i32^)sp;
    i64 w = (old[0] & 4294967295) + 2;
    while (old[w] & 4294967295) != 0 { w += 1; }
    // after the environment come the pairs of the auxiliary vector: (1 << 17) of AT_HWCAP (16) says that the CPU has udiv / sdiv (the global area is at 0x10000000, the flag at 872)
    i64 k = w + 1;
    while (old[k] & 4294967295) != 0 {
        if (old[k] & 4294967295) == 16 && ((old[k + 1] & 4294967295) & 131072) != 0 {
            i64^ gflag = (i64^)268435456;
            gflag[109] = 1;
        }
        k += 2;
    }
    i64 mem = syscall(222, 0, (w + 2) * 8, 3, 34, -1, 0);
    i64^ nw = (i64^)mem;
    i64 j = 0;
    while j <= w {
        nw[j] = old[j] & 4294967295;
        j += 1;
    }
    return mem;
}

// the copy of j2k_copy / j2k_copy16 (source, -, bytes (a multiple of 8), destination)
void __a32_copy(i64 s, i64 u, i64 n, i64 d) {
    i64^ ps = (i64^)s;
    i64^ pd = (i64^)d;
    i64 k = 0;
    while k * 8 < n {
        pd[k] = ps[k];
        k += 1;
    }
}

void __a32_copy16(i64 s, i64 u, i64 n, i64 d) {
    __a32_copy(s, u, n, d);
}

void __a32_divzero() {
    __panic("division by zero");
}

// the signal handler for SIGSEGV (called by the entry stub with the arguments of the kernel put in our own form)
void __a32_hex(i64 v) {
    char b[16];
    i64 i = 7;
    while i >= 0 {
        i64 dgt = (v >> (4 * i)) & 15;
        if dgt < 10 { b[7 - i] = '0' + dgt; } else { b[7 - i] = 'a' + dgt - 10; }
        i -= 1;
    }
    b[8] = 0;
    syscall(64, 2, @b, 8);
}

void __a32_segv(i64 sig, i64 info, i64 uc) {
    i32^ c = (i32^)uc;
    i32^ si = (i32^)info;
    __a32_errtext("segmentation fault: pc=0x");
    __a32_hex(c[23]);
    __a32_errtext(" lr=0x");
    __a32_hex(c[22]);
    __a32_errtext(" address=0x");
    __a32_hex(si[3]);
    __a32_errtext("\n");
    syscall(94, 139);
}

void __a32_errtext(char^ s) {
    __flush();
    i64 n = 0;
    while s[n] != 0 { n += 1; }
    syscall(64, 2, s, n);
}

void __a32_print_str(char^ s) {
    i64 n = 0;
    while s[n] != 0 { n += 1; }
    __wr(__out_fd(), s, n);
}

void __a32_print_char(i64 c) {
    char b[8];
    b[0] = c;
    __wr(__out_fd(), @b, 1);
}

void __a32_print_int(i64 v) {
    char buf[32];
    i64 at = 31;
    i64 u = v;
    bool neg = false;
    if v < 0 {
        neg = true;
        u = 0 - v;
    }
    if u == 0 {
        buf[at] = '0';
        at -= 1;
    }
    while u != 0 {
        i64 q = __a32_udiv(u, 10);
        buf[at] = '0' + (u - q * 10);
        at -= 1;
        u = q;
    }
    if neg {
        buf[at] = '-';
        at -= 1;
    }
    __wr(__out_fd(), @buf[at + 1], 31 - at);
}

// the end of a function that has to give a value and did not (the ARM64 target jumps to j2k_noret)
void __a32_noret() {
    __panic("a function ended without giving a value");
}

// ---- double precision numbers by their bits (the ARM32 target has no instruction for these in VFPv3)
// the whole number part, towards 0 (the bits of the double in, a 64-bit whole number out; 0 for a NaN, the limit for a number that is too big)
i64 __a32_d2i(i64 bits) {
    i64 e = ((bits >> 52) & 2047) - 1023;
    if e < 0 { return 0; }
    i64 m = (bits & 4503599627370495) | 4503599627370496;
    i64 v = 0;
    if e >= 63 {
        v = 9223372036854775807;
        if bits < 0 { return 0 - v - 1; }
        return v;
    }
    if e >= 52 { v = m << (e - 52); } else { v = m >> (52 - e); }
    if bits < 0 { return 0 - v; }
    return v;
}

// the number with the fraction cut off (bits in, bits out)
i64 __a32_trunc(i64 bits) {
    i64 e = ((bits >> 52) & 2047) - 1023;
    i64 sign = bits & (1 << 63);
    if e < 0 { return sign; }
    if e >= 52 { return bits; }
    i64 mask = (1 << (52 - e)) - 1;
    return bits & (mask xor (0 - 1));
}

i64 __a32_floor(i64 bits) {
    i64 t = __a32_trunc(bits);
    if bits >= 0 || t == bits { return t; }
    double fl[2];
    i64^ fb = (i64^)@fl[0];
    fb[0] = t;
    fl[1] = fl[0] - 1.0;
    return fb[1];
}

i64 __a32_ceil(i64 bits) {
    i64 t = __a32_trunc(bits);
    if bits < 0 || t == bits { return t; }
    double fl[2];
    i64^ fb = (i64^)@fl[0];
    fb[0] = t;
    fl[1] = fl[0] + 1.0;
    return fb[1];
}

// unsigned decimal print of a 64-bit number
void __a32_print_uint(i64 v) {
    char buf[32];
    i64 at = 31;
    if v == 0 {
        buf[at] = '0';
        at -= 1;
    }
    while v != 0 {
        i64 q = __a32_udiv(v, 10);
        buf[at] = '0' + (v - q * 10);
        at -= 1;
        v = q;
    }
    __wr(__out_fd(), @buf[at + 1], 31 - at);
}

// jout of a double: the same text as j2k_print_f64 of the ARM64 target (6 decimals; infinity, nan; 2^64 and more as d.dddddde+NN)
void __a32_print_f64(i64 bits) {
    i64 e = (bits >> 52) & 2047;
    if e == 2047 {
        if (bits & 4503599627370495) != 0 {
            __a32_print_str("nan");
            return;
        }
        if bits < 0 { __a32_print_char(45); }
        __a32_print_str("inf");
        return;
    }
    if bits < 0 {
        __a32_print_char(45);
        bits = bits & 9223372036854775807;
    }
    double fl[1];
    i64^ fb = (i64^)@fl[0];
    fb[0] = bits;
    double d = fl[0];
    if d < 9223372036854775808.0 {
        i64 ip = (i64)d;
        double fr = (d - (double)ip) * 1000000.0 + 0.5;
        i64 f = (i64)fr;
        if f >= 1000000 {
            f -= 1000000;
            ip += 1;
        }
        __a32_print_int(ip);
        __a32_print_char(46);
        i64 div = 100000;
        while div > 0 {
            i64 dg = f / div;
            f = f - dg * div;
            __a32_print_char(48 + dg);
            div = div / 10;
        }
        return;
    }
    if d < 18446744073709551616.0 {
        i64 u = (i64)(d - 9223372036854775808.0) + (1 << 63);
        __a32_print_uint(u);
        __a32_print_str(".000000");
        return;
    }
    __Fp::huge(bits);
}

// a throw that no try block catches: the text goes to the standard error and the program stops with 1
void __a32_uncaught(char^ msg) {
    __a32_errtext("uncaught exception: ");
    __a32_errtext(msg);
    __a32_errtext("\n");
    syscall(94, 1);
}

// ---- the system calls of the program: the structures that the ARM64 table passes (timespec with 64-bit fields ...) have 32-bit fields here
i64 __a32_sys(i64 nr, i64 a0, i64 a1, i64 a2, i64 a3, i64 a4, i64 a5) {
    if nr == 101 {                                     // nanosleep(req, rem)
        i64^ rq = (i64^)a0;
        i32 b[2];
        if a0 != 0 {
            b[0] = (i32)rq[0];
            b[1] = (i32)rq[1];
            return __syscall_raw(nr, (i64)@b, a1, a2, a3, a4, a5);
        }
    }
    if nr == 115 {                                     // clock_nanosleep(clock, flags, req, rem)
        i64^ rq2 = (i64^)a2;
        i32 b2[2];
        if a2 != 0 {
            b2[0] = (i32)rq2[0];
            b2[1] = (i32)rq2[1];
            return __syscall_raw(nr, a0, a1, (i64)@b2, a3, a4, a5);
        }
    }
    if nr == 113 {                                     // clock_gettime(clock, ts)
        i32 b3[2];
        b3[0] = 0;
        b3[1] = 0;
        i64 rc = __syscall_raw(nr, a0, (i64)@b3, a2, a3, a4, a5);
        i64^ ts = (i64^)a1;
        if a1 != 0 && rc == 0 {
            ts[0] = b3[0];
            ts[1] = b3[1];
        }
        return rc;
    }
    if nr == 169 {                                     // gettimeofday(tv, tz)
        i32 b4[2];
        b4[0] = 0;
        b4[1] = 0;
        i64 rc4 = __syscall_raw(nr, (i64)@b4, a1, a2, a3, a4, a5);
        i64^ tv = (i64^)a0;
        if a0 != 0 && rc4 == 0 {
            tv[0] = b4[0];
            tv[1] = b4[1];
        }
        return rc4;
    }
    if nr == 73 {                                      // ppoll(fds, n, timeout, sigmask, size)
        i64^ rq5 = (i64^)a2;
        i32 b5[2];
        if a2 != 0 {
            b5[0] = (i32)rq5[0];
            b5[1] = (i32)rq5[1];
            return __syscall_raw(nr, a0, a1, (i64)@b5, a3, a4, a5);
        }
    }
    if nr == 221 {                                     // execve(path, argv, envp): the arrays of pointers have 4-byte entries here
        i64^ pa = (i64^)a1;
        i64^ pe = (i64^)a2;
        i32 av[256];
        i32 ev[512];
        i64 ia = 0;
        if a1 != 0 {
            while pa[ia] != 0 && ia < 255 {
                av[ia] = (i32)pa[ia];
                ia += 1;
            }
        }
        av[ia] = 0;
        i64 ie = 0;
        if a2 != 0 {
            while pe[ie] != 0 && ie < 511 {
                ev[ie] = (i32)pe[ie];
                ie += 1;
            }
        }
        ev[ie] = 0;
        return __syscall_raw(nr, a0, (i64)@av, (i64)@ev, a3, a4, a5);
    }
    return __syscall_raw(nr, a0, a1, a2, a3, a4, a5);
}

