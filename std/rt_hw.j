// Cpu: instructions of the CPU that have no other way in (the compiler puts the instruction where the call is)
struct Cpu {
    static void wait() { __cpu_wait(); }                  // wfi: sleep until an interrupt
    static void event() { __cpu_event(); }                // wfe: sleep until an event
    static void send_event() { __cpu_send_event(); }      // sev
    static void pause() { __cpu_pause(); }                // yield: "I am spinning" (pause on x86)
    static void nop() { __cpu_nop(); }
    static void isb() { __cpu_isb(); }                    // the instructions after it see what happened before
    static int counter() { return __cpu_counter(); }      // the system counter (cntvct_el0): ticks since boot, no system call
    static int frequency() { return __cpu_frequency(); }  // its ticks per second
    static int id() { return __cpu_id(); }                // the number of this core
}

// Atomic: operations on a whole number in memory that no other thread can break (all are sequentially consistent)
struct Atomic {
    static int load(int^ p) { return __atomic_load(p); }                  // ldar
    static void store(int^ p, int v) { __atomic_store(p, v); }            // stlr
    static int add(int^ p, int v) { return __fetch_add(p, v); }          // the value it had before
    static int sub(int^ p, int v) { return __fetch_sub(p, v); }
    static int swap(int^ p, int v) { return __xchg(p, v); }
    static int cas(int^ p, int old, int nw) { return __cas(p, old, nw); }  // the value it had; it was changed if that is old
    static int bit_and(int^ p, int v) { return __fetch_and(p, v); }
    static int bit_or(int^ p, int v) { return __fetch_or(p, v); }
    static int bit_xor(int^ p, int v) { return __fetch_xor(p, v); }
}

// Cache: the data cache by address (the line that holds the address)
struct Cache {
    static void clean(int^ p) { __cache_clean(p); }                       // write the line back (dc cvac)
    static void invalidate(int^ p) { __cache_invalidate(p); }             // throw the line away (dc ivac)
    static void clean_invalidate(int^ p) { __cache_clean_invalidate(p); }
    static void zero(int^ p) { __cache_zero(p); }                         // fill the block with zeros (dc zva)
    static void clean_code(int^ p) { __cache_clean_code(p); }
    static void invalidate_code(int^ p) { __cache_invalidate_code(p); }
}

// the results of the wide arithmetic of Bit (a function gives one struct: there is no tuple)
struct BitCarry { int sum; int c; }          // add_carry / sub_borrow: the result and the carry (the borrow) out, 0 or 1
struct BitWide { int lo; int hi; }           // mul_wide: the 128-bit product of two numbers (unsigned): the low and the high 64 bits
struct BitDivRem { int q; int r; }           // div_rem: the quotient and the remainder (signed, the quotient goes towards 0)

// Bit: the work on the bits of a whole number, each is one instruction of the CPU (the compiler puts the instruction where the call is)
struct Bit {
    // a + b + carry_in (0 or 1): the sum (cut to 64 bits) and the carry out. A number of many words is added word by word with it.
    static BitCarry add_carry(int a, int b, int cin) {
        BitCarry r;
        int top = 1 << 63;
        int s = a + b;
        int c = 0;
        if (s xor top) < (a xor top) { c = 1; }          // the sum is smaller than a (as unsigned numbers): it wrapped
        int s2 = s + cin;
        if cin == 1 && s2 == 0 { c = 1; }
        r.sum = s2;
        r.c = c;
        return r;
    }
    // a - b - borrow_in (0 or 1): the difference (cut to 64 bits) and the borrow out (1 when a < b + borrow_in as unsigned numbers)
    static BitCarry sub_borrow(int a, int b, int bin) {
        BitCarry r;
        int top = 1 << 63;
        int bw = 0;
        if (a xor top) < (b xor top) { bw = 1; }
        if a == b && bin == 1 { bw = 1; }
        r.sum = a - b - bin;
        r.c = bw;
        return r;
    }
    // the high 64 bits of the 128-bit product of a and b taken as unsigned numbers
    static int mul_hi(int a, int b) {
        int m = 4294967295;
        int a0 = a & m;
        int a1 = (a >> 32) & m;
        int b0 = b & m;
        int b1 = (b >> 32) & m;
        int p00 = a0 * b0;
        int p01 = a0 * b1;
        int p10 = a1 * b0;
        int p11 = a1 * b1;
        int mid = ((p00 >> 32) & m) + (p01 & m) + (p10 & m);
        return p11 + ((p01 >> 32) & m) + ((p10 >> 32) & m) + ((mid >> 32) & m);
    }
    // the whole 128-bit product (unsigned): lo = the low 64 bits, hi = the high 64 bits
    static BitWide mul_wide(int a, int b) {
        BitWide r;
        r.lo = a * b;
        r.hi = Bit::mul_hi(a, b);
        return r;
    }
    // a / b and a % b together (signed; b must not be 0)
    static BitDivRem div_rem(int a, int b) {
        BitDivRem r;
        r.q = a / b;
        r.r = a - r.q * b;
        return r;
    }
    // a + b that stops at the largest or the smallest number instead of wrapping (signed)
    static int add_sat(int a, int b) {
        int s = a + b;
        if ((a xor s) & (b xor s)) < 0 {
            if a < 0 { return 1 << 63; }
            return (1 << 63) - 1;
        }
        return s;
    }

    // how many bits 0 there are in front of the first bit 1 (64 for 0)
    static int clz(int x) { return __clz(x); }
    // how many bits 0 there are after the last bit 1 (64 for 0)
    static int ctz(int x) { return __ctz(x); }
    // how many bits are 1
    static int popcount(int x) { return __popcount(x); }
    // the bits turned left / right by k places (the bits that fall out come in on the other side; k is taken modulo 64)
    static int rotl(int x, int k) { return __rotl(x, k); }
    static int rotr(int x, int k) { return __rotr(x, k); }
    // the 8 bytes in the other order
    static int bswap(int x) { return __bswap(x); }
}

