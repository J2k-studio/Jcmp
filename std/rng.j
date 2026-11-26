// rng 0.1.0 -- random numbers that you own: each Rng has its own series, the same seed gives the same series (for games, tests, AI).   #import <rng>   (license: MPL-2.0)
//   Rng r = Rng::make(42);              // the same number: the same numbers, on every phone
//   i64 d = r.range(1, 7);              // 1 .. 6          double u = r.unit();      // 0 up to (not including) 1
//   double g = r.normal(0.0, 1.0);      // a bell curve (mean, spread)           bool b = r.chance(0.25);      // true one time in four
//   r.shuffle(list, n);                 // the n numbers of an array of i64 in a new order          i64 k = r.pick(n);      // an index 0 .. n - 1
// The series is SplitMix64 (a number goes in, a well mixed number comes out: no weak seeds, 2^64 different series); Random:: (the global one) is for quick use.

struct Rng {
    u64 state;

    static Rng make(i64 seed) {
        Rng r;
        r.state = (u64)seed;
        return r;
    }

    // the next 64 bits
    u64 bits(self) {
        self.state = self.state + 0x9E3779B97F4A7C15;
        u64 z = self.state;
        z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9;
        z = (z xor (z shr 27)) * 0x94D049BB133111EB;
        return z xor (z shr 31);
    }

    // a whole number from lo up to (not including) hi
    i64 range(self, i64 lo, i64 hi) {
        if hi <= lo { return lo; }
        u64 span = (u64)(hi - lo);
        return lo + (i64)(self.bits() % span);
    }

    // an index 0 .. n - 1
    i64 pick(self, i64 n) { return self.range(0, n); }

    // a number from 0 up to (not including) 1 (53 bits, all of them used)
    double unit(self) { return (double)(self.bits() shr 11) / 9007199254740992.0; }

    // a number from lo up to hi
    double between(self, double lo, double hi) { return lo + (hi - lo) * self.unit(); }

    // true with the chance p (0 .. 1)
    bool chance(self, double p) { return self.unit() < p; }

    // a bell curve: the mean and the spread (the polar method of Marsaglia; two numbers are used for one result)
    double normal(self, double mean, double spread) {
        double u = 0.0;
        double v = 0.0;
        double s = 0.0;
        while true {
            u = self.unit() * 2.0 - 1.0;
            v = self.unit() * 2.0 - 1.0;
            s = u * u + v * v;
            if s > 0.0 && s < 1.0 { break; }
        }
        return mean + spread * u * Math::sqrt(0.0 - 2.0 * Math::log(s) / s);
    }

    // the n numbers of the array in a new order (Fisher-Yates)
    void shuffle(self, i64^ a, i64 n) {
        i64 i = n - 1;
        while i > 0 {
            i64 j = self.range(0, i + 1);
            i64 t = a[i];
            a[i] = a[j];
            a[j] = t;
            i -= 1;
        }
    }
}
