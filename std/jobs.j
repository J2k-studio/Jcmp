// jobs 0.1.0 -- run many small jobs on several threads.   #import <cpu>  #import <jobs>   (needs jcmp 1.2.1.0; license: MPL-2.0)
//   void work(void^ arg) { int i = (int)arg; ... }          // job number i (0 .. count-1)
//   Jobs::run(1000, 4, work);                                // 1000 jobs on 4 threads; returns when all are done; the calling thread works too
//   Jobs::run_all(1000, work);                               // the same with one thread a core (Jobs::cores())
// Jobs are taken one by one from a shared counter, so slow and fast jobs balance by themselves.
// A job must not throw out of its function (catch inside). The jobs share memory: guard shared data with Mutex or Atomic.

void jobs_worker(void^ arg) {
    int^ b = (int^)arg;                        // [0] next job, [1] count, [2] the function
    void(void^)^ f = (void(void^)^)b[2];
    while true {
        int i = Atomic::add(b, 1);
        if i >= b[1] { return; }
        f((void^)i);
    }
}

struct Jobs {
    // the number of cores this program may use
    static int cores() {
        return __Mt::cores();
    }

    // count jobs on `threads` threads (the caller is one of them)
    static void run(int count, int threads, void(void^)^ f) {
        if count <= 0 { return; }
        if threads < 1 { threads = 1; }
        if threads > count { threads = count; }
        int b[3];
        b[0] = 0;
        b[1] = count;
        b[2] = (int)f;
        Thread ts[64];
        int extra = threads - 1;
        if extra > 63 { extra = 63; }
        for k in 0..extra { ts[k] = Thread::create(jobs_worker, (void^)@b[0]); }
        jobs_worker((void^)@b[0]);
        for k in 0..extra { ts[k].join(); }
    }

    static void run_all(int count, void(void^)^ f) {
        Jobs::run(count, Jobs::cores(), f);
    }
}
