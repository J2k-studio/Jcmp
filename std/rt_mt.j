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
