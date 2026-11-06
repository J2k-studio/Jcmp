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

