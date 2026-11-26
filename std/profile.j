// profile 0.2.0 -- timers by name, for a frame or a function (a start and a stop cost about 0.2 to 0.4 us).   #import <profile>   (needs jcmp 1.2.1.0; license: MPL-2.0)
//   Profile p = Profile::make();
//   int t = p.start();   ...work...   p.stop("physics", t);      // adds the time of this run to the timer "physics"
//   int id = p.timer("physics");  ...  p.stop_id(id, t);         // the same with no search by name (the fastest: for a function that runs a million times)
//   p.frame();                                                    // call once a frame: counts frames
//   jout << p.report();                                           // one line a timer: name, calls, total ms, average us, share
//   p.total_us("physics"), p.calls("physics"), p.average_us("physics"), p.frames, p.reset();
// Times are read from the system counter of the CPU (cntvct_el0, no system call: 60 to 120 ns a read on the development phone, where the counter runs at
// 1.92 MHz: one tick is 0.52 us, so one run shorter than that counts as 0 or 1 tick; the sum over many runs is right) and given in microseconds.
// Profile::make_exact() reads the monotonic clock instead (a system call: 0.44 us a read, but the time is in ns): for a few long runs. A timer that does not exist yet is made by its first stop().

struct Profile {
    String[] names;
    i64[] calls_of;
    i64[] total_ns;          // ticks of the system counter (the name is old: use total_us())
    i64 frames;
    i64 freq;                // ticks in a second
    i64 exact;               // 1: the ticks are the ns of the monotonic clock

    static Profile make() {
        Profile p;
        p.names = arr(8);
        p.calls_of = arr(8);
        p.total_ns = arr(8);
        p.frames = 0;
        p.freq = Cpu::frequency();
        if p.freq <= 0 { p.freq = 1000000000; }
        p.exact = 0;
        return p;
    }

    // timers that read the monotonic clock (ns, but slower to read)
    static Profile make_exact() {
        Profile p = Profile::make();
        p.freq = 1000000000;
        p.exact = 1;
        return p;
    }

    // the start mark to give to stop()
    i64 now(self) {
        if self.exact == 1 { return Time::mono_ns(); }
        return Cpu::counter();
    }

    i64 start(self) { return self.now(); }

    // the nanoseconds of some ticks
    i64 ns_of(self, i64 ticks) { return (i64)((double)ticks * 1000000000.0 / (double)self.freq); }

    i64 index(self, String name) {
        for i in 0..self.names.len {
            if self.names[i] == name { return i; }
        }
        return -1;
    }

    // adds the time since the mark t to the timer `name`; returns that time in ns
    i64 stop(self, String name, i64 t) {
        i64 d = self.now() - t;
        self.add_ticks(name, d);
        return self.ns_of(d);
    }

    // the number of a timer (it is made when it does not exist): give it to stop_id() to skip the search by name
    i64 timer(self, String name) {
        i64 i = self.index(name);
        if i < 0 {
            self.names.push(name + "");
            self.calls_of.push(0);
            self.total_ns.push(0);
            i = self.names.len - 1;
        }
        return i;
    }

    // stop() for a timer that has a number
    i64 stop_id(self, i64 id, i64 t) {
        i64 d = self.now() - t;
        self.calls_of[id] = self.calls_of[id] + 1;
        self.total_ns[id] = self.total_ns[id] + d;
        return d;
    }

    void add_ticks(self, String name, i64 d) {
        i64 i = self.timer(name);
        self.calls_of[i] = self.calls_of[i] + 1;
        self.total_ns[i] = self.total_ns[i] + d;
    }

    // adds a time that was measured somewhere else, in ns
    void add_ns(self, String name, i64 d) {
        self.add_ticks(name, (i64)((double)d * (double)self.freq / 1000000000.0));
    }

    void frame(self) { self.frames += 1; }

    i64 calls(self, String name) {
        i64 i = self.index(name);
        if i < 0 { return 0; }
        return self.calls_of[i];
    }

    i64 total_us(self, String name) {
        i64 i = self.index(name);
        if i < 0 { return 0; }
        return self.ns_of(self.total_ns[i]) / 1000;
    }

    i64 average_us(self, String name) {
        i64 i = self.index(name);
        if i < 0 || self.calls_of[i] == 0 { return 0; }
        return self.ns_of(self.total_ns[i]) / self.calls_of[i] / 1000;
    }

    void reset(self) {
        for i in 0..self.names.len { self.calls_of[i] = 0; self.total_ns[i] = 0; }
        self.frames = 0;
    }

    // one line a timer, in the order they were first used
    String report(self) {
        i64 all = 0;
        for i in 0..self.names.len { all += self.total_ns[i]; }
        String r = "timer            calls   total ms   avg us   share\n";
        for i in 0..self.names.len {
            i64 share = 0;
            if all > 0 { share = self.total_ns[i] * 100 / all; }
            r = r + self.names[i] + "  " + stg(self.calls_of[i]) + "  " + stg(self.ns_of(self.total_ns[i]) / 1000000) + "  " + stg(self.average_us(self.names[i])) + "  " + stg(share) + "%\n";
        }
        if self.frames > 0 { r = r + "frames: " + stg(self.frames) + "\n"; }
        return r;
    }
}
