// Time and random numbers: Time (clock, sleep), Random (a generator).
struct Time {
    // milliseconds since 1970 (the clock of the computer)
    static i64 now_ms() {
        i64 ts[2];
        Sys::clock_gettime(0, @ts);
        return ts[0] * 1000 + ts[1] / 1000000;
    }
    // a clock that only goes forward, in nanoseconds: for measuring how long something takes
    static i64 mono_ns() {
        i64 ts[2];
        Sys::clock_gettime(1, @ts);
        return ts[0] * 1000000000 + ts[1];
    }
    static void sleep_ms(i64 ms) {
        i64 ts[2];
        ts[0] = ms / 1000;
        ts[1] = ms % 1000 * 1000000;
        Sys::nanosleep(@ts);
    }
}

u64 std_rand_state;

struct Random {
    // start the series from a number (the same number gives the same series)
    static void seed(i64 s) {
        std_rand_state = (u64)s;
        if std_rand_state == 0 { std_rand_state = 88172645463325252; }
    }
    // the next number: 0 or more (xorshift64)
    static i64 next() {
        if std_rand_state == 0 { Random::seed(Time::mono_ns() + Time::now_ms()); }
        u64 x = std_rand_state;
        x = x xor (x shl 13);
        x = x xor (x shr 7);
        x = x xor (x shl 17);
        std_rand_state = x;
        return (i64)(x shr 1);
    }
    // a number from lo up to (not including) hi
    static i64 range(i64 lo, i64 hi) {
        if hi <= lo { return lo; }
        return lo + Random::next() % (hi - lo);
    }
    // a decimal number from 0 up to (not including) 1
    static double unit() {
        return (double)(Random::next() shr 10) / 9.007199254740992e15;
    }
}

// time, random: the short names (Time::time.now_ms(), with  using Time;  time.now_ms()  and  random.range(1, 6))

// the short names of the time unit (time, random): <module>_<name>, the compiler adds the prefix
struct __TimeM {
    static i64 time_now_ms() { return Time::now_ms(); }
    static i64 time_mono_ns() { return Time::mono_ns(); }
    static void time_sleep_ms(i64 ms) { Time::sleep_ms(ms); }
    static void random_seed(i64 s) { Random::seed(s); }
    static i64 random_next() { return Random::next(); }
    static i64 random_range(i64 lo, i64 hi) { return Random::range(lo, hi); }
    static double random_unit() { return Random::unit(); }
}

// Date: a day and a time on the calendar (the Gregorian calendar, UTC), from and to seconds since 1970.
//   Date d;  d.set_unix(86400 * 365);  jout << d.text() << " " << d.weekday() << "\n";     // 1971-01-01 00:00:00 5
struct Date {
    i64 year;
    i64 month;           // 1 .. 12
    i64 day;             // 1 .. 31
    i64 hour;
    i64 minute;
    i64 second;

    static bool is_leap(i64 y) {
        if y % 400 == 0 { return true; }
        if y % 100 == 0 { return false; }
        return y % 4 == 0;
    }
    static i64 days_in_month(i64 y, i64 m) {
        if m == 2 {
            if Date::is_leap(y) { return 29; }
            return 28;
        }
        if m == 4 || m == 6 || m == 9 || m == 11 { return 30; }
        return 31;
    }
    // the number of days from 1970-01-01 to the day y-m-d (negative before it)
    static i64 days_from_civil(i64 y, i64 m, i64 d) {
        i64 yy = y;
        if m <= 2 { yy = yy - 1; }
        i64 era = 0;
        if yy >= 0 { era = yy / 400; } else { era = (yy - 399) / 400; }
        i64 yoe = yy - era * 400;
        i64 mp = m - 3;
        if m <= 2 { mp = m + 9; }
        i64 doy = (153 * mp + 2) / 5 + d - 1;
        i64 doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        return era * 146097 + doe - 719468;
    }
    // the date and the time of `secs` seconds since 1970-01-01 00:00:00
    void set_unix(self, i64 secs) {
        i64 days = secs / 86400;
        i64 rest = secs % 86400;
        if rest < 0 {
            rest += 86400;
            days -= 1;
        }
        i64 z = days + 719468;
        i64 era = 0;
        if z >= 0 { era = z / 146097; } else { era = (z - 146096) / 146097; }
        i64 doe = z - era * 146097;
        i64 yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        i64 y = yoe + era * 400;
        i64 doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        i64 mp = (5 * doy + 2) / 153;
        i64 d = doy - (153 * mp + 2) / 5 + 1;
        i64 m = mp + 3;
        if mp >= 10 { m = mp - 9; }
        if m <= 2 { y = y + 1; }
        self.year = y;
        self.month = m;
        self.day = d;
        self.hour = rest / 3600;
        self.minute = rest % 3600 / 60;
        self.second = rest % 60;
    }
    // seconds since 1970-01-01 00:00:00
    i64 unix(self) {
        return Date::days_from_civil(self.year, self.month, self.day) * 86400 + self.hour * 3600 + self.minute * 60 + self.second;
    }
    // 0 Sunday .. 6 Saturday
    i64 weekday(self) {
        i64 days = Date::days_from_civil(self.year, self.month, self.day);
        i64 w = (days + 4) % 7;
        if w < 0 { w += 7; }
        return w;
    }
    // the day of the year, 1 .. 366
    i64 day_of_year(self) {
        return Date::days_from_civil(self.year, self.month, self.day) - Date::days_from_civil(self.year, 1, 1) + 1;
    }
    void add_days(self, i64 n) {
        self.set_unix(self.unix() + n * 86400);
    }
    // "2024-02-29 13:05:09"
    String text(self) {
        String m = str(self.month);
        String d = str(self.day);
        String h = str(self.hour);
        String mi = str(self.minute);
        String s = str(self.second);
        String r = str(self.year) + "-";
        if m.len < 2 { r += "0"; }
        r += m + "-";
        if d.len < 2 { r += "0"; }
        r += d + " ";
        if h.len < 2 { r += "0"; }
        r += h + ":";
        if mi.len < 2 { r += "0"; }
        r += mi + ":";
        if s.len < 2 { r += "0"; }
        r += s;
        return r;
    }
}

