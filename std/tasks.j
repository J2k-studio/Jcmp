// tasks 0.1.0 -- a function that runs on its own thread and gives a value (Task), and a queue between threads (Channel<T>).   #import <cpu>  #import <tasks>   (needs jcmp 1.2.1.0; license: MPL-2.0)
//   int square(void^ arg) { int n = (int)arg; return n * n; }
//   Task t = Task::run(square, (void^)12);       // starts at once on a new thread
//   ...other work...
//   int r = t.wait();                            // 144; waits if it is not ready; call it once. t.ready() tells without waiting.
//   Channel<int> c = Channel<int>::make();       // an unbounded queue; many writers and readers are fine
//   c.send(5);   int v = c.receive();            // receive() waits until a value comes, or returns the zero value when the channel is closed and empty
//   bool got; int w = c.try_receive(@got);       // never waits
//   c.close();   c.is_closed();                  // after close(), send() is ignored and receive() drains what is left
// A task must not throw out of its function (catch inside). A Channel is a handle: copies of it share the queue.

void task_main(void^ arg) {
    int^ b = (int^)arg;                                  // [0] function, [1] argument, [2] result, [3] done
    int(void^)^ f = (int(void^)^)b[0];
    int r = f((void^)b[1]);
    b[2] = r;
    Atomic::add(@b[3], 1);
}

struct Task {
    int^ blk;
    Thread th;
    bool waited;

    static Task run(int(void^)^ f, void^ arg) {
        Task t;
        t.blk = (int^)Mem::alloc(32);
        t.blk[0] = (int)f;
        t.blk[1] = (int)arg;
        t.blk[2] = 0;
        t.blk[3] = 0;
        t.waited = false;
        t.th = Thread::create(task_main, (void^)@t.blk[0]);
        return t;
    }

    bool ready(self) { return self.blk[3] != 0; }

    // the value of the function; waits for it
    int wait(self) {
        if !self.waited {
            self.th.join();
            self.waited = true;
        }
        return self.blk[2];
    }
}

struct Channel<T> {
    int^ state;                  // [0] mutex, [1] closed
    T[] items;
    int^ head;                   // [0] index of the next item to read

    static Channel<T> make() {
        Channel<T> c;
        c.state = (int^)Mem::alloc(16);
        c.state[0] = 0;
        c.state[1] = 0;
        c.items = arr(16);
        c.head = (int^)Mem::alloc(8);
        c.head[0] = 0;
        return c;
    }

    void send(self, T v) {
        int^ w = @self.state[0];
        while __cas(w, 0, 1) != 0 { Thread::yield(); }
        if self.state[1] == 0 { self.items.push(v); }
        __xchg(w, 0);
    }

    T try_receive(self, bool^ got) {
        T zero;
        int^ w = @self.state[0];
        while __cas(w, 0, 1) != 0 { Thread::yield(); }
        if self.head[0] < self.items.len {
            T v = self.items[self.head[0]];
            self.head[0] += 1;
            __xchg(w, 0);
            got[0] = true;
            return v;
        }
        __xchg(w, 0);
        got[0] = false;
        return zero;
    }

    T receive(self) {
        T zero;
        while true {
            bool got = false;
            T v = self.try_receive(@got);
            if got { return v; }
            if self.state[1] != 0 {
                bool again = false;
                T v2 = self.try_receive(@again);
                if again { return v2; }
                return zero;
            }
            Thread::sleep(1);
        }
        return zero;
    }

    void close(self) { __xchg(@self.state[1], 1); }
    bool is_closed(self) { return self.state[1] != 0; }
}
