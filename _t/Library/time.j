// Time and random numbers: Time (clock, sleep), Random (a generator).
struct Time {
    // milliseconds since 1970 (the clock of the computer)
    static int now_ms() {
        int ts[2];
        Sys::clock_gettime(0, @ts);
        return ts[0] * 1000 + ts[1] / 1000000;
    }
    // a clock that only goes forward, in nanoseconds: for measuring how long something takes
    static int mono_ns() {
        int ts[2];
        Sys::clock_gettime(1, @ts);
        return ts[0] * 1000000000 + ts[1];
    }
    static void sleep_ms(int ms) {
        int ts[2];
        ts[0] = ms / 1000;
        ts[1] = ms % 1000 * 1000000;
        Sys::nanosleep(@ts);
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

// the short names of the time unit (time, random): <module>_<name>, the compiler adds the prefix
struct __TimeM {
    static int time_now_ms() { return Time::now_ms(); }
    static int time_mono_ns() { return Time::mono_ns(); }
    static void time_sleep_ms(int ms) { Time::sleep_ms(ms); }
    static void random_seed(int s) { Random::seed(s); }
    static int random_next() { return Random::next(); }
    static int random_range(int lo, int hi) { return Random::range(lo, hi); }
    static double random_unit() { return Random::unit(); }
}

// Date: a day and a time on the calendar (the Gregorian calendar, UTC), from and to seconds since 1970.
//   Date d;  d.set_unix(86400 * 365);  cout << d.text() << " " << d.weekday() << "\n";     // 1971-01-01 00:00:00 5
struct Date {
    int year;
    int month;           // 1 .. 12
    int day;             // 1 .. 31
    int hour;
    int minute;
    int second;

    static bool is_leap(int y) {
        if y % 400 == 0 { return true; }
        if y % 100 == 0 { return false; }
        return y % 4 == 0;
    }
    static int days_in_month(int y, int m) {
        if m == 2 {
            if Date::is_leap(y) { return 29; }
            return 28;
        }
        if m == 4 || m == 6 || m == 9 || m == 11 { return 30; }
        return 31;
    }
    // the number of days from 1970-01-01 to the day y-m-d (negative before it)
    static int days_from_civil(int y, int m, int d) {
        int yy = y;
        if m <= 2 { yy = yy - 1; }
        int era = 0;
        if yy >= 0 { era = yy / 400; } else { era = (yy - 399) / 400; }
        int yoe = yy - era * 400;
        int mp = m - 3;
        if m <= 2 { mp = m + 9; }
        int doy = (153 * mp + 2) / 5 + d - 1;
        int doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        return era * 146097 + doe - 719468;
    }
    // the date and the time of `secs` seconds since 1970-01-01 00:00:00
    void set_unix(self, int secs) {
        int days = secs / 86400;
        int rest = secs % 86400;
        if rest < 0 {
            rest += 86400;
            days -= 1;
        }
        int z = days + 719468;
        int era = 0;
        if z >= 0 { era = z / 146097; } else { era = (z - 146096) / 146097; }
        int doe = z - era * 146097;
        int yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        int y = yoe + era * 400;
        int doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        int mp = (5 * doy + 2) / 153;
        int d = doy - (153 * mp + 2) / 5 + 1;
        int m = mp + 3;
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
    int unix(self) {
        return Date::days_from_civil(self.year, self.month, self.day) * 86400 + self.hour * 3600 + self.minute * 60 + self.second;
    }
    // 0 Sunday .. 6 Saturday
    int weekday(self) {
        int days = Date::days_from_civil(self.year, self.month, self.day);
        int w = (days + 4) % 7;
        if w < 0 { w += 7; }
        return w;
    }
    // the day of the year, 1 .. 366
    int day_of_year(self) {
        return Date::days_from_civil(self.year, self.month, self.day) - Date::days_from_civil(self.year, 1, 1) + 1;
    }
    void add_days(self, int n) {
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

