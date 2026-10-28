// profile 0.1.0 -- timers by name, for a frame or a function.   #import <profile>   (needs jcmp 1.2.1.0; license: MPL-2.0)
//   Profile p = Profile::make();
//   int t = p.start();   ...work...   p.stop("physics", t);      // adds the time of this run to the timer "physics"
//   p.frame();                                                    // call once a frame: counts frames
//   cout << p.report();                                           // one line a timer: name, calls, total ms, average us, share
//   p.total_us("physics"), p.calls("physics"), p.average_us("physics"), p.frames, p.reset();
// Times are in microseconds (monotonic clock). A timer that does not exist yet is made by its first stop().

struct Profile {
    String[] names;
    int[] calls_of;
    int[] total_ns;
    int frames;

    static Profile make() {
        Profile p;
        p.names = arr(8);
        p.calls_of = arr(8);
        p.total_ns = arr(8);
        p.frames = 0;
        return p;
    }

    // the start mark to give to stop()
    int start(self) { return Time::mono_ns(); }

    int index(self, String name) {
        for i in 0..self.names.len {
            if self.names[i] == name { return i; }
        }
        return -1;
    }

    // adds the time since the mark t to the timer `name`; returns that time in ns
    int stop(self, String name, int t) {
        int d = Time::mono_ns() - t;
        self.add_ns(name, d);
        return d;
    }

    void add_ns(self, String name, int d) {
        int i = self.index(name);
        if i < 0 {
            self.names.push(name + "");
            self.calls_of.push(0);
            self.total_ns.push(0);
            i = self.names.len - 1;
        }
        self.calls_of[i] = self.calls_of[i] + 1;
        self.total_ns[i] = self.total_ns[i] + d;
    }

    void frame(self) { self.frames += 1; }

    int calls(self, String name) {
        int i = self.index(name);
        if i < 0 { return 0; }
        return self.calls_of[i];
    }

    int total_us(self, String name) {
        int i = self.index(name);
        if i < 0 { return 0; }
        return self.total_ns[i] / 1000;
    }

    int average_us(self, String name) {
        int i = self.index(name);
        if i < 0 || self.calls_of[i] == 0 { return 0; }
        return self.total_ns[i] / self.calls_of[i] / 1000;
    }

    void reset(self) {
        for i in 0..self.names.len { self.calls_of[i] = 0; self.total_ns[i] = 0; }
        self.frames = 0;
    }

    // one line a timer, in the order they were first used
    String report(self) {
        int all = 0;
        for i in 0..self.names.len { all += self.total_ns[i]; }
        String r = "timer            calls   total ms   avg us   share\n";
        for i in 0..self.names.len {
            int share = 0;
            if all > 0 { share = self.total_ns[i] * 100 / all; }
            r = r + self.names[i] + "  " + str(self.calls_of[i]) + "  " + str(self.total_ns[i] / 1000000) + "  " + str(self.average_us(self.names[i])) + "  " + str(share) + "%\n";
        }
        if self.frames > 0 { r = r + "frames: " + str(self.frames) + "\n"; }
        return r;
    }
}
