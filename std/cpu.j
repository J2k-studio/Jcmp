// cpu: threads and locks.   import cpu    using cpu::thread    using cpu::mutex
//
//   void work(void^ arg) { ... }
//   Thread t = create(work, @data);   t.join();      or  t.detach();
//   Mutex m;   m.lock();  ...  m.unlock();
//
// A Thread value is a handle: copies of it refer to the same thread. The thread runs on its own
// 1 MB stack (taken from the system); join() gives the stack back. A detached thread cannot free its
// own stack, so that memory stays until the program ends.

struct Mutex {
    int state;                         // 0 free, 1 taken, 2 taken and somebody waits

    void init(self) {
        self.state = 0;
    }
    void lock(self) {
        int^ w = @self.state;
        int c = __cas(w, 0, 1);
        if c == 0 { return; }
        if c != 2 { c = __xchg(w, 2); }
        while c != 0 {
            syscall(98, w, 128, 2, 0, 0, 0);           // futex wait: sleep while the word is 2
            c = __xchg(w, 2);
        }
    }
    void unlock(self) {
        int^ w = @self.state;
        int old = __xchg(w, 0);
        if old == 2 { syscall(98, w, 129, 1, 0, 0, 0); }     // futex wake: one waiter
    }
    // true if the lock was free and is now yours
    bool try_lock(self) {
        int^ w = @self.state;
        return __cas(w, 0, 1) == 0;
    }
}

struct Thread {
    int^ cb;                           // [0] thread id (the kernel makes it 0 when the thread ends), [1] stack, [2] size, [3] detached

    // start function(arg) in a new thread
    static Thread create(void(void^)^ f, void^ arg) {
        int size = 1048576;
        int base = syscall(222, 0, size, 3, 34, -1, 0);       // mmap: the stack (zeroed)
        if base < 0 { throw "cannot create the thread: no memory for its stack"; }
        int^ cb = (int^)Mem::alloc(32);
        if (int)cb == 0 { throw "cannot create the thread: out of memory"; }
        cb[1] = base;
        cb[2] = size;
        cb[3] = 0;
        int block = base + size - 1024;                        // the thread's own block (try/catch state) at the top
        int tid = __thread_start(f, arg, block, (int)cb, block);
        if tid < 0 {
            syscall(215, base, size);
            Mem::free(cb);
            throw "cannot create the thread";
        }
        Thread t;
        t.cb = cb;
        return t;
    }
    // wait until the thread has ended
    void join(self) {
        int^ cb = self.cb;
        if (int)cb == 0 { throw "join: this is not a running or finished thread"; }
        if cb[3] != 0 { throw "cannot join a detached thread"; }
        while cb[0] != 0 {
            syscall(98, cb, 0, cb[0], 0, 0, 0);                // futex wait (not the private kind: the kernel wakes the shared one at thread exit)
        }
        syscall(215, cb[1], cb[2]);                            // give the stack back
        Mem::free(cb);
        self.cb = null;
    }
    // let the thread run on its own; it cannot be joined any more
    void detach(self) {
        int^ cb = self.cb;
        if (int)cb == 0 { throw "detach: this is not a thread"; }
        if cb[3] != 0 { throw "the thread is already detached"; }
        cb[3] = 1;
    }
    bool is_running(self) {
        int^ cb = self.cb;
        if (int)cb == 0 { return false; }
        return cb[0] != 0;
    }
    // pause the calling thread for ms milliseconds
    static void sleep(int ms) {
        int ts[2];
        ts[0] = ms / 1000;
        ts[1] = ms % 1000 * 1000000;
        syscall(101, @ts, 0);
    }
    static void yield() {
        syscall(124);
    }
    static int id() {
        return syscall(178);
    }
}
