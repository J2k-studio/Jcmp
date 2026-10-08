// jc_logo.j -- the mascot: jcmp -space shows the J2K logo in ASCII style and in 3D: the Earth with the letter J raised on it,
// in black, white and grey, that turns on its axis and goes round the Sun, with the Moon that goes round it and shows its
// phases (full, half, crescent). The times are real: the turn of the Earth (23.93 hours), the month (27.32 days), the light
// of the Sun (8 min 19 s) and of the Moon (1.28 s); the film runs N times faster than real time.
// 50 x 20 characters, 24 frames a second, all in J2K with no library. Stops on Ctrl-C or Enter.
#define LW 50
#define LH 20
#define LN 1000

char lg_ch[LN];              // 50 x 20 characters of the picture
int lg_col[LN];              // the colour of each character (0xRRGGBB, grey), used if the terminal has 24-bit colour
double lg_dep[LN];           // how far from the eye what is drawn in each cell is
int lg_color_on;             // 1: use the colours
double lg_fx;                // the view: forward, right and up
double lg_fy;
double lg_fz;
double lg_rx;
double lg_ry;
double lg_rz;
double lg_ux;
double lg_uy;
double lg_uz;
double lg_ax;                // the axis of the Earth
double lg_ay;
double lg_az;
double lg_vx;                // the result of lg_rot
double lg_vy;
double lg_vz;
char lg_buf[49152];          // the text of one frame
int lg_len;
char lg_cap[400];            // four lines of text under the picture, 100 characters each
int lg_cl[4];
int lg_cn;
double lg_sx[60];            // the stars: place, speed and phase of the twinkling
double lg_sy[60];
double lg_sf[60];
double lg_sp[60];
char lg_ramp2[96];           // a long ramp of characters from empty to dense: many steps of shade
int lg_n2;
int lg_cols;                 // the size of the terminal, read once
int lg_rows;

double lg_abs(double x) {
    if x < 0.0 { return 0.0 - x; }
    return x;
}

double lg_min(double a, double b) {
    if b < a { return b; }
    return a;
}

double lg_clamp(double x, double lo, double hi) {
    if x < lo { return lo; }
    if x > hi { return hi; }
    return x;
}

// sine by its series (the angle is brought into -pi..pi first)
double lg_sin(double x) {
    double pi = 3.141592653589793;
    while x > pi { x = x - 2.0 * pi; }
    while x < 0.0 - pi { x = x + 2.0 * pi; }
    double x2 = x * x;
    double term = x;
    double sum = x;
    int k = 1;
    while k < 9 {
        term = 0.0 - term * x2 / (double)((2 * k) * (2 * k + 1));
        sum = sum + term;
        k += 1;
    }
    return sum;
}

double lg_cos(double x) {
    return lg_sin(x + 1.570796326794897);
}

// the angle of the point (x, z) round the middle, -pi..pi (a series: good to about 0.005)
double lg_atan2(double z, double x) {
    double pi = 3.141592653589793;
    double ax = lg_abs(x);
    double az = lg_abs(z);
    double mx = ax;
    double mn = az;
    if az > ax {
        mx = az;
        mn = ax;
    }
    if mx == 0.0 { return 0.0; }
    double a = mn / mx;
    double s2 = a * a;
    double r = ((-0.0464964749 * s2 + 0.15931422) * s2 - 0.327622764) * s2 * a + a;
    if az > ax { r = 1.570796326794897 - r; }
    if x < 0.0 { r = pi - r; }
    if z < 0.0 { r = 0.0 - r; }
    return r;
}

// how close the point (x, y) is to the letter J (0 = far, 1 = inside the stroke); y is down; the letter fills -1..1
double lg_j(double x, double y) {
    double d = 9.0;
    double bx = lg_clamp(x, 0.0 - 0.18, 0.46);                                  // the top bar
    d = lg_min(d, __fsqrt((x - bx) * (x - bx) + (y + 0.80) * (y + 0.80)));
    double sy = lg_clamp(y, 0.0 - 0.80, 0.30);                                  // the stem
    d = lg_min(d, __fsqrt((x - 0.14) * (x - 0.14) + (y - sy) * (y - sy)));
    double cx = x + 0.17;                                                       // the hook: a half circle, curling up at its end
    double cy = y - 0.30;
    if cy >= 0.0 {
        d = lg_min(d, lg_abs(__fsqrt(cx * cx + cy * cy) - 0.31));
    } else if cx < 0.0 {
        double ey = lg_clamp(y, 0.12, 0.30);
        d = lg_min(d, __fsqrt((x + 0.48) * (x + 0.48) + (y - ey) * (y - ey)));
    }
    return lg_clamp(1.0 - (d - 0.15) / 0.07, 0.0, 1.0);
}

void lg_text(char^ s) {
    int i = 0;
    while s[i] != 0 && lg_len < 49000 {
        lg_buf[lg_len] = s[i];
        lg_len += 1;
        i += 1;
    }
}

void lg_num(int v) {
    char d[24];
    int n = 0;
    if v == 0 {
        d[0] = '0';
        n = 1;
    }
    while v > 0 {
        d[n] = '0' + v % 10;
        n += 1;
        v = v / 10;
    }
    while n > 0 {
        n -= 1;
        lg_buf[lg_len] = d[n];
        lg_len += 1;
    }
}

// ---- the lines of text under the picture
void lg_cbegin(int n) {
    lg_cn = n;
    lg_cl[n] = 0;
}

void lg_ct(char^ s) {
    int i = 0;
    while s[i] != 0 && lg_cl[lg_cn] < 99 {
        lg_cap[lg_cn * 100 + lg_cl[lg_cn]] = s[i];
        lg_cl[lg_cn] += 1;
        i += 1;
    }
}

void lg_cnum(int v) {
    char d[24];
    int n = 0;
    if v == 0 {
        d[0] = '0';
        n = 1;
    }
    while v > 0 {
        d[n] = '0' + v % 10;
        n += 1;
        v = v / 10;
    }
    while n > 0 {
        n -= 1;
        char one[2];
        one[0] = d[n];
        one[1] = 0;
        lg_ct(@one);
    }
}

// a number with one decimal: 12.3
void lg_cdec(double v) {
    if v < 0.0 { v = 0.0; }
    int w = (int)v;
    lg_cnum(w);
    lg_ct(".");
    lg_cnum((int)((v - (double)w) * 10.0));
}

// a time given in seconds: "12.0 s", or "5.5 min" from two minutes on, or "1.2 h"
void lg_cdur(double s) {
    if s < 120.0 {
        lg_cdec(s);
        lg_ct(" s");
    } else if s < 7200.0 {
        lg_cdec(s / 60.0);
        lg_ct(" min");
    } else {
        lg_cdec(s / 3600.0);
        lg_ct(" h");
    }
}

// HH:MM:SS of the clock of the computer now (UTC)
void lg_cclock() {
    char ts[16];
    syscall(113, 0, @ts);
    int sec = 0;
    int k = 7;
    while k >= 0 {
        sec = sec * 256 + (ts[k] & 255);
        k -= 1;
    }
    int day = sec % 86400;
    char t8[10];
    t8[0] = '0' + day / 36000;
    t8[1] = '0' + (day / 3600) % 10;
    t8[2] = ':';
    t8[3] = '0' + ((day % 3600) / 60) / 10;
    t8[4] = '0' + ((day % 3600) / 60) % 10;
    t8[5] = ':';
    t8[6] = '0' + (day % 60) / 10;
    t8[7] = '0' + (day % 60) % 10;
    t8[8] = 0;
    lg_ct(@t8);
}

void lg_find_color() {
    lg_color_on = 0;
    int i = argc() + 1;
    while arg(i) != null {
        char^ e = arg(i);
        if e[0] == 'C' && e[1] == 'O' && e[2] == 'L' && e[3] == 'O' && e[4] == 'R' && e[5] == 'T' && e[6] == 'E' && e[7] == 'R' && e[8] == 'M' && e[9] == '=' {
            if e[10] == 't' || e[10] == '2' { lg_color_on = 1; }
        }
        i += 1;
    }
}

// the character for a brightness 0..1 (a long ramp: many steps of shade)
char lg_pick(double v) {
    if v < 0.0 { v = 0.0; }
    if v > 1.0 { v = 1.0; }
    v = v * (1.7 - 0.7 * v);                                // lifts the middle: fuller, less thin
    int k = (int)(v * (double)(lg_n2 - 1) + 0.5);
    if k > lg_n2 - 1 { k = lg_n2 - 1; }
    return lg_ramp2[k];
}

// grey, as a colour number
int lg_grey(double v) {
    if v < 0.0 { v = 0.0; }
    if v > 1.0 { v = 1.0; }
    int g = (int)(70.0 + 185.0 * v);
    return (g << 16) | (g << 8) | g;
}

void lg_read_size() {
    char ws[8];
    lg_cols = 80;
    lg_rows = 24;
    if syscall(29, 1, 21523, @ws) == 0 {
        int r = (ws[0] & 255) | ((ws[1] & 255) << 8);
        int c = (ws[2] & 255) | ((ws[3] & 255) << 8);
        if r >= 5 { lg_rows = r; }
        if c >= 10 { lg_cols = c; }
    }
}

// the picture as text, in the middle of the terminal (every line is put in place with a cursor move)
void lg_show() {
    int left = (lg_cols - LW) / 2 + 1;
    int top = (lg_rows - LH - 4) / 2 + 1;
    if left < 1 { left = 1; }
    if top < 1 { top = 1; }
    lg_len = 0;
    int y = 0;
    while y < LH {
        lg_buf[lg_len] = 27;
        lg_len += 1;
        lg_text("[");
        lg_num(top + y);
        lg_text(";");
        lg_num(left);
        lg_text("H");
        int x = 0;
        int last = 0 - 1;
        while x < LW {
            if lg_color_on == 1 {
                int c = lg_col[y * LW + x];
                if lg_ch[y * LW + x] == ' ' { c = 0; }
                if c != last {
                    lg_buf[lg_len] = 27;
                    lg_len += 1;
                    lg_text("[38;2;");
                    lg_num((c >> 16) & 255);
                    lg_text(";");
                    lg_num((c >> 8) & 255);
                    lg_text(";");
                    lg_num(c & 255);
                    lg_text("m");
                    last = c;
                }
            }
            lg_buf[lg_len] = lg_ch[y * LW + x];
            lg_len += 1;
            x += 1;
        }
        if lg_color_on == 1 {
            lg_buf[lg_len] = 27;
            lg_len += 1;
            lg_text("[0m");
        }
        y += 1;
    }
    // the four lines under the picture, each in the middle (the old text of the line is wiped first)
    int n = 0;
    while n < 4 {
        lg_buf[lg_len] = 27;
        lg_len += 1;
        lg_text("[");
        lg_num(top + LH + n);
        lg_text(";1H");
        lg_buf[lg_len] = 27;
        lg_len += 1;
        lg_text("[2K");
        lg_buf[lg_len] = 27;
        lg_len += 1;
        lg_text("[");
        lg_num(top + LH + n);
        lg_text(";");
        int col = left + (LW - lg_cl[n]) / 2;
        if col < 1 { col = 1; }
        lg_num(col);
        lg_text("H");
        int k = 0;
        while k < lg_cl[n] {
            lg_buf[lg_len] = lg_cap[n * 100 + k];
            lg_len += 1;
            k += 1;
        }
        n += 1;
    }
    syscall(64, 1, @lg_buf, lg_len);
}

// true if a line was typed (nothing is waited for; the terminal is not changed)
bool lg_key() {
    char pfd[8];
    char ts[16];
    int i = 0;
    while i < 8 {
        pfd[i] = 0;
        i += 1;
    }
    i = 0;
    while i < 16 {
        ts[i] = 0;
        i += 1;
    }
    pfd[4] = 1;
    if syscall(73, @pfd, 1, @ts, 0, 8) <= 0 { return false; }
    if (pfd[6] & 1) == 0 { return false; }
    char b[64];
    return syscall(63, 0, @b, 64) > 0;
}

int lg_now() {
    char ts[16];
    syscall(113, 1, @ts);                                   // the clock that only goes forward
    int sec = 0;
    int nsec = 0;
    int k = 7;
    while k >= 0 {
        sec = sec * 256 + (ts[k] & 255);
        nsec = nsec * 256 + (ts[8 + k] & 255);
        k -= 1;
    }
    return sec * 1000000000 + nsec;
}

void lg_sleep_ns(int ns) {
    char ts[16];
    int sec = ns / 1000000000;
    int nsec = ns % 1000000000;
    int k = 0;
    while k < 8 {
        ts[k] = (sec >> (8 * k)) & 255;
        ts[8 + k] = (nsec >> (8 * k)) & 255;
        k += 1;
    }
    syscall(101, @ts, 0);
}

// the vector (x, y, z) turned about the axis of the Earth by the angle a: the result is in lg_vx, lg_vy, lg_vz
void lg_rot(double x, double y, double z, double a) {
    double c = lg_cos(a);
    double s = lg_sin(a);
    double dot = lg_ax * x + lg_ay * y + lg_az * z;
    double cx = lg_ay * z - lg_az * y;
    double cy = lg_az * x - lg_ax * z;
    double cz = lg_ax * y - lg_ay * x;
    lg_vx = x * c + cx * s + lg_ax * dot * (1.0 - c);
    lg_vy = y * c + cy * s + lg_ay * dot * (1.0 - c);
    lg_vz = z * c + cz * s + lg_az * dot * (1.0 - c);
}

// where a ray from (ox, oy, oz) along (dx, dy, dz) first meets the ball with the middle (cx, cy, cz) and radius r (1000 if it does not)
double lg_ball(double ox, double oy, double oz, double dx, double dy, double dz, double cx, double cy, double cz, double r) {
    double px = ox - cx;
    double py = oy - cy;
    double pz = oz - cz;
    double b = px * dx + py * dy + pz * dz;
    double c = px * px + py * py + pz * pz - r * r;
    double disc = b * b - c;
    if disc <= 0.0 { return 1000.0; }
    double t = 0.0 - b - __fsqrt(disc);
    if t < 0.0 { return 1000.0; }
    return t;
}

// the name of the phase of the Moon: k = the lit part (0..1), waxing = 1 if it grows
void lg_phase_name(double k, int waxing) {
    if k < 0.04 { lg_ct("new moon"); return; }
    if k > 0.96 { lg_ct("full moon"); return; }
    if k > 0.46 && k < 0.54 {
        if waxing == 1 { lg_ct("first quarter (half)"); } else { lg_ct("last quarter (half)"); }
        return;
    }
    if waxing == 1 { lg_ct("waxing "); } else { lg_ct("waning "); }
    if k < 0.5 { lg_ct("crescent"); } else { lg_ct("gibbous"); }
}

// the logo: frames = 0 runs until Ctrl-C or Enter; speed = how many times faster than real time the film runs
void lg_run(int frames, int speed) {
    if speed < 1 { speed = 7200; }
    double ts = (double)speed;
    lg_find_color();
    char^ rp = " .:-+cvunxzXYUJCLQ0OZmwqpdbkhaoMW&8%B@$#";
    lg_n2 = 0;
    while rp[lg_n2] != 0 && lg_n2 < 90 {
        lg_ramp2[lg_n2] = rp[lg_n2];
        lg_n2 += 1;
    }
    int seed = 4242;
    int i = 0;
    while i < 60 {
        seed = (seed * 1103515245 + 12345) & 2147483647;
        lg_sx[i] = (double)((seed >> 8) % 1000) / 1000.0 * (double)LW;
        seed = (seed * 1103515245 + 12345) & 2147483647;
        lg_sy[i] = (double)((seed >> 8) % 1000) / 1000.0 * (double)LH;
        seed = (seed * 1103515245 + 12345) & 2147483647;
        lg_sf[i] = 1.5 + (double)((seed >> 8) % 1000) / 1000.0 * 4.0;
        seed = (seed * 1103515245 + 12345) & 2147483647;
        lg_sp[i] = (double)((seed >> 8) % 1000) / 1000.0 * 6.283;
        i += 1;
    }
    lg_read_size();
    char clear[8];
    clear[0] = 27;
    clear[1] = '[';
    clear[2] = '2';
    clear[3] = 'J';
    clear[4] = 0;
    write_out(@clear);
    double pi = 3.141592653589793;
    double tau = 2.0 * pi;
    double cxs = (double)LW / 2.0;
    double cys = (double)LH / 2.0;
    double unit = (double)LH * 0.33;                      // rows for the radius of the Earth (a character is twice as high as wide)
    // the view: from a little above, looking at the middle (all rays parallel)
    double pitch = 0.42;
    double sinp = lg_sin(pitch);
    double cosp = lg_cos(pitch);
    lg_fx = 0.0;
    lg_fy = 0.0 - sinp;
    lg_fz = cosp;
    lg_rx = 1.0;
    lg_ry = 0.0;
    lg_rz = 0.0;
    lg_ux = 0.0;
    lg_uy = cosp;
    lg_uz = sinp;
    // the real numbers
    double day_s = 86164.1;                               // one turn of the Earth (a sidereal day), seconds
    double month_s = 27.321661 * 86400.0;                 // one turn of the Moon round the Earth (a sidereal month)
    double year_s = 365.25636 * 86400.0;                  // one turn of the Earth round the Sun
    double sun_km = 149597870.7;                          // the Sun is that far,
    double moon_km = 384400.0;                            // and the Moon
    double c_kms = 299792.458;                            // the speed of light, km/s
    double sun_delay = sun_km / c_kms;                    // 499 s: the sunlight we see left the Sun that long ago
    double moon_delay = moon_km / c_kms;                  // 1.28 s
    // the axis of the Earth leans 23.44 degrees from the line to the pole of the orbit
    double tilt = 23.44 * pi / 180.0;
    lg_ax = 0.0;                                          // the north pole leans towards us, so that the J stays upright on the face
    lg_ay = lg_cos(tilt);
    lg_az = 0.0 - lg_sin(tilt);
    // the letter J sits on the Earth, in the middle of the face that looks at us at the start: c0, with east and north there
    double c0x = 0.0;
    double c0y = 0.0;
    double c0z = 0.0 - 1.0;
    double ex = c0y * lg_az - c0z * lg_ay;                // east = c0 x axis (to the right of the face that looks at us)
    double ey = c0z * lg_ax - c0x * lg_az;
    double ez = c0x * lg_ay - c0y * lg_ax;
    double el = __fsqrt(ex * ex + ey * ey + ez * ez);
    ex = ex / el;
    ey = ey / el;
    ez = ez / el;
    double nx0 = ey * c0z - ez * c0y;                     // north = east x c0
    double ny0 = ez * c0x - ex * c0z;
    double nz0 = ex * c0y - ey * c0x;
    double rm = 0.40;                                     // the Moon (drawn bigger than real, 0.27, and nearer: not to scale)
    double dm = 1.80;
    double mtilt = 0.0897;                                // its orbit leans 5.14 degrees
    int frame = 0;
    int t0 = lg_now();
    while frames == 0 || frame < frames {
        double t = (double)frame / 24.0;
        double real_s = t * ts;                           // the seconds that have passed on the Earth
        // where the Sun is (seen from the Earth), as an angle in the plane of the orbit: it goes round once in a year.
        // The light we see left the Sun sun_delay seconds ago.
        double lam_s = 4.0 + tau * (real_s - sun_delay) / year_s;
        double lx = lg_cos(lam_s);
        double lz = lg_sin(lam_s);
        double ly = 0.0;
        // the Moon: an angle round the Earth, one turn in a month; it starts a little ahead of the Sun (a waxing crescent)
        double lam_m = lam_s + 1.1 + tau * real_s / month_s - tau * real_s / year_s;
        double mx = dm * lg_cos(lam_m);
        double mz = dm * lg_sin(lam_m);
        double my = dm * lg_sin(lam_m) * mtilt;
        // the Earth turns on its axis
        double spin = 0.0 - 0.15 - tau * real_s / day_s;       // west to east: the face we see goes from left to right
        // the stars first
        i = 0;
        while i < LN {
            lg_ch[i] = ' ';
            lg_col[i] = 0;
            lg_dep[i] = 1000.0;
            i += 1;
        }
        i = 0;
        while i < 60 {
            double tw = 0.5 + 0.5 * lg_sin(t * lg_sf[i] + lg_sp[i]);
            char c = ' ';
            if tw > 0.35 { c = '.'; }
            if tw > 0.65 { c = '+'; }
            if tw > 0.9 { c = '*'; }
            lg_ch[(int)lg_sy[i] * LW + (int)lg_sx[i]] = c;
            lg_col[(int)lg_sy[i] * LW + (int)lg_sx[i]] = lg_grey(0.35 + 0.55 * tw);
            i += 1;
        }
        int y = 0;
        while y < LH {
            int x = 0;
            while x < LW {
                double xs = ((double)x + 0.5 - cxs) / (unit * 2.0);
                double ys = ((double)y + 0.5 - cys) / unit;
                double ox = lg_rx * xs - lg_ux * ys - lg_fx * 6.0;
                double oy = lg_ry * xs - lg_uy * ys - lg_fy * 6.0;
                double oz = lg_rz * xs - lg_uz * ys - lg_fz * 6.0;
                double te = lg_ball(ox, oy, oz, lg_fx, lg_fy, lg_fz, 0.0, 0.0, 0.0, 1.0);
                double tm = lg_ball(ox, oy, oz, lg_fx, lg_fy, lg_fz, mx, my, mz, rm);
                if te < 999.0 && te <= tm {
                    // the Earth
                    double hx = ox + lg_fx * te;
                    double hy = oy + lg_fy * te;
                    double hz = oz + lg_fz * te;
                    // the point as it was before the Earth turned: its place on the surface
                    lg_rot(hx, hy, hz, 0.0 - spin);
                    double p0x = lg_vx;
                    double p0y = lg_vy;
                    double p0z = lg_vz;
                    double facing = p0x * c0x + p0y * c0y + p0z * c0z;               // near the face with the J: 1
                    double jx = (p0x * ex + p0y * ey + p0z * ez) * 0.95;
                    double jy = 0.0 - (p0x * nx0 + p0y * ny0 + p0z * nz0) * 0.95 + 0.06;
                    double cov = 0.0;
                    double dcx = 0.0;
                    double dcy = 0.0;
                    if facing > 0.15 {
                        cov = lg_j(jx, jy);
                        double e = 0.03;
                        dcx = (lg_j(jx + e, jy) - lg_j(jx - e, jy)) / (2.0 * e);
                        dcy = (lg_j(jx, jy + e) - lg_j(jx, jy - e)) / (2.0 * e);
                    }
                    // the normal: the ball's, bent at the edges of the letter so that it stands out (in the frame of the surface, then turned back)
                    double bump = 0.30;
                    double qx = p0x - bump * (dcx * ex * 0.95 - dcy * nx0 * 0.95);
                    double qy = p0y - bump * (dcx * ey * 0.95 - dcy * ny0 * 0.95);
                    double qz = p0z - bump * (dcx * ez * 0.95 - dcy * nz0 * 0.95);
                    double ql = __fsqrt(qx * qx + qy * qy + qz * qz);
                    lg_rot(qx / ql, qy / ql, qz / ql, spin);
                    double nx = lg_vx;
                    double ny = lg_vy;
                    double nz = lg_vz;
                    double lam = nx * lx + ny * ly + nz * lz;
                    if lam < 0.0 { lam = 0.0; }
                    // the Moon may hide the Sun (an eclipse of the Sun)
                    if lam > 0.0 {
                        double ts2 = lg_ball(hx, hy, hz, lx, ly, lz, mx, my, mz, rm);
                        if ts2 < 999.0 { lam = lam * 0.12; }
                    }
                    // the paint: the sea is mid grey with fine lines of latitude and longitude, the letter is white
                    double albedo = 0.52;
                    double lat = lg_abs(lg_sin(p0x * lg_ax * 9.4248 + p0y * lg_ay * 9.4248 + p0z * lg_az * 9.4248));
                    double lon = lg_abs(lg_sin((lg_atan2(p0x * ex + p0y * ey + p0z * ez, p0x * c0x + p0y * c0y + p0z * c0z) + 3.1416) * 6.0));
                    if lat < 0.07 || lon < 0.06 { albedo = 0.40; }
                    albedo = albedo + (1.0 - albedo) * cov;
                    // the glow at the rim, a small bright spot of reflected light on the sea
                    double ndv = 0.0 - (nx * lg_fx + ny * lg_fy + nz * lg_fz);
                    if ndv < 0.0 { ndv = 0.0; }
                    double rim = 1.0 - ndv;
                    rim = rim * rim * rim;
                    double hx2 = lx - lg_fx;
                    double hy2 = ly - lg_fy;
                    double hz2 = lz - lg_fz;
                    double hl = __fsqrt(hx2 * hx2 + hy2 * hy2 + hz2 * hz2);
                    double refl = 0.0;
                    if hl > 0.0 {
                        double nh = (nx * hx2 + ny * hy2 + nz * hz2) / hl;
                        if nh > 0.0 {
                            double n2 = nh * nh;
                            n2 = n2 * n2;
                            n2 = n2 * n2;
                            refl = n2 * n2 * (1.0 - cov);
                        }
                    }
                    double bright = 0.11 + 0.90 * lam * albedo + 0.18 * rim * (0.2 + lam) + 0.35 * refl;
                    if bright > 1.0 { bright = 1.0; }
                    lg_ch[y * LW + x] = lg_pick(bright);
                    lg_col[y * LW + x] = lg_grey(bright);
                    lg_dep[y * LW + x] = te;
                } else if tm < 999.0 {
                    // the Moon: always the same face to the Earth (it turns once a month); its dark patches are the seas of lava
                    double hx = ox + lg_fx * tm;
                    double hy = oy + lg_fy * tm;
                    double hz = oz + lg_fz * tm;
                    double nx = (hx - mx) / rm;
                    double ny = (hy - my) / rm;
                    double nz = (hz - mz) / rm;
                    double lam = nx * lx + ny * ly + nz * lz;
                    if lam < 0.0 { lam = 0.0; }
                    double rim_m = 1.0 + (nx * lg_fx + ny * lg_fy + nz * lg_fz);       // 0 in the middle of the disc, 1 at its edge
                    // the shadow of the Earth (an eclipse of the Moon)
                    if lam > 0.0 {
                        double ts2 = lg_ball(hx, hy, hz, lx, ly, lz, 0.0, 0.0, 0.0, 1.0);
                        if ts2 < 999.0 { lam = lam * 0.10; }
                    }
                    // the patches: fixed on the Moon, so they turn with its orbit
                    double ca = lg_cos(lam_m);
                    double sa = lg_sin(lam_m);
                    double mxl = nx * ca + nz * sa;
                    double mzl = 0.0 - nx * sa + nz * ca;
                    double patch = lg_sin(mxl * 4.0 + 1.0) * lg_sin(ny * 5.0 + 0.5) * lg_sin(mzl * 3.0 + 2.0);
                    double albedo = 0.95;
                    if patch > 0.18 { albedo = 0.60; }
                    double bright = 0.16 + 0.88 * lam * albedo;                // the dark side is not black: light of the Earth
                    if rim_m > 0.55 { bright = bright + 0.18; }                  // a thin rim so that the whole disc can be seen
                    if bright > 1.0 { bright = 1.0; }
                    lg_ch[y * LW + x] = lg_pick(bright);
                    lg_col[y * LW + x] = lg_grey(bright);
                    lg_dep[y * LW + x] = tm;
                }
                x += 1;
            }
            y += 1;
        }
        // the orbit of the Moon: faint dots, hidden where the Earth or the Moon is in front
        int n = 0;
        while n < 120 {
            double a = (double)n * tau / 120.0;
            double wx = dm * lg_cos(a);
            double wz = dm * lg_sin(a);
            double wy = wz * mtilt;
            double sxr = wx * lg_rx + wy * lg_ry + wz * lg_rz;
            double syr = wx * lg_ux + wy * lg_uy + wz * lg_uz;
            int dx = (int)(cxs + sxr * unit * 2.0);
            int dy = (int)(cys - syr * unit);
            if dx >= 0 && dx < LW && dy >= 0 && dy < LH {
                if lg_ch[dy * LW + dx] == ' ' || lg_ch[dy * LW + dx] == '.' {
                    lg_ch[dy * LW + dx] = '.';
                    lg_col[dy * LW + dx] = lg_grey(0.30);
                }
            }
            n += 1;
        }
        // how much of the Moon is lit as we see it from the Earth, and whether it grows
        double mex = mx;
        double mez = mz;
        double ml = __fsqrt(mex * mex + my * my + mez * mez);
        double cth = (mex * lx + my * ly + mez * lz) / ml;              // the angle between the Moon and the Sun, seen from the Earth
        double lit = (1.0 - cth) / 2.0;
        double dl = lam_m - lam_s;
        while dl > pi { dl = dl - tau; }
        while dl < 0.0 - pi { dl = dl + tau; }
        int waxing = 0;
        if dl > 0.0 { waxing = 1; }
        // the four lines under the picture
        lg_cbegin(0);
        lg_ct("by J2k-studio  (Ctrl-C/Enter: stop)");
        lg_cbegin(1);
        lg_ct("x");
        lg_cnum(speed);
        lg_ct("  Earth ");
        lg_cdur(day_s / ts);
        lg_ct("  Moon ");
        lg_cdur(month_s / ts);
        lg_cbegin(2);
        lg_ct("UTC ");
        lg_cclock();
        lg_ct("  +");
        lg_cdur(real_s);
        lg_cbegin(3);
        lg_ct("Moon: ");
        lg_phase_name(lit, waxing);
        lg_ct(" ");
        lg_cnum((int)(lit * 100.0 + 0.5));
        lg_ct("%  light Sun ");
        lg_cnum((int)(sun_delay / 60.0));
        lg_ct("m");
        lg_cnum((int)sun_delay % 60);
        lg_ct("s Moon ");
        lg_cdec(moon_delay);
        lg_ct("s");
        lg_show();
        if frames == 0 && lg_key() { frame = 0 - 1; break; }
        frame += 1;
        int due = t0 + frame * 41666666;
        int now = lg_now();
        if due > now { lg_sleep_ns(due - now); }
    }
}
