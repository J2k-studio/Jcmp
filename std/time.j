// Time and random numbers: Time (clock, sleep), Random (a generator).
struct Time {
    // milliseconds since 1970 (the clock of the computer)
    static int now_ms() {
        int ts[2];
        syscall(113, 0, @ts);
        return ts[0] * 1000 + ts[1] / 1000000;
    }
    // a clock that only goes forward, in nanoseconds: for measuring how long something takes
    static int mono_ns() {
        int ts[2];
        syscall(113, 1, @ts);
        return ts[0] * 1000000000 + ts[1];
    }
    static void sleep_ms(int ms) {
        int ts[2];
        ts[0] = ms / 1000;
        ts[1] = ms % 1000 * 1000000;
        syscall(101, @ts, 0);
    }
}

u64 std_rand_state;

struct Random {
    // start the series from a number (the same number gives the same series)
    static void seed(int s) {
        std_rand_state = (u64)s;
        if std_rand_state == 0 { std_rand_state = 88172645463325252; }
    }
    // the next number: 0 or more (xorshift64)
    static int next() {
        if std_rand_state == 0 { Random::seed(Time::mono_ns() + Time::now_ms()); }
        u64 x = std_rand_state;
        x = x xor (x shl 13);
        x = x xor (x shr 7);
        x = x xor (x shl 17);
        std_rand_state = x;
        return (int)(x shr 1);
    }
    // a number from lo up to (not including) hi
    static int range(int lo, int hi) {
        if hi <= lo { return lo; }
        return lo + Random::next() % (hi - lo);
    }
    // a decimal number from 0 up to (not including) 1
    static double unit() {
        return (double)(Random::next() shr 10) / 9.007199254740992e15;
    }
}

// time, random: the short names (Time::time.now_ms(), with  using Time;  time.now_ms()  and  random.range(1, 6))
struct __Time {
    static int now_ms() { return Time::now_ms(); }
    static int mono_ns() { return Time::mono_ns(); }
    static void sleep_ms(int ms) { Time::sleep_ms(ms); }
}
struct __Random {
    static void seed(int s) { Random::seed(s); }
    static int next() { return Random::next(); }
    static int range(int lo, int hi) { return Random::range(lo, hi); }
    static double unit() { return Random::unit(); }
}
