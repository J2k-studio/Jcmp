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

// Bit: the work on the bits of a whole number, each is one instruction of the CPU (the compiler puts the instruction where the call is)
struct Bit {
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

