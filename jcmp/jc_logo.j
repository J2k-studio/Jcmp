// jc_logo.j -- the mascot: jcmp -space shows the J2K logo in ASCII style and in 3D: the Earth in the middle, the Moon that goes round it
// with the letter J on its surface (the Moon turns on its own axis, the J turns with it), shaded in black, white and grey with
// the characters  .:-=+*#%@  by the angle to a fixed Sun. The Moon starts where the real Moon is now (its real phase, from the
// clock), and the film runs N times faster than real time (said under the picture; default 1 s = 30 min). Small, 24 frames a
// second, all in J2K with no library. Stops on Ctrl-C or Enter.
// the picture has the size the terminal allows: 50 x 20 (small), 60 x 24, 76 x 30 or 100 x 40 (finer: every character is smaller
// compared with the globe, so there is more detail)
#define LW lg_w
#define LH lg_h
#define LN 4096
#define LCELLS (lg_w * lg_h)

int lg_w;
int lg_h;
char lg_ch[LN];              // characters of the picture
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
char lg_buf[131072];          // the text of one frame
int lg_len;
char lg_cap[600];            // five lines of text under the picture, 100 characters each
int lg_cl[5];
int lg_cn;
double lg_crx[14];           // craters of the Moon: place on the surface and size
double lg_cry[14];
double lg_crz[14];
double lg_crr[14];
double lg_sx[60];            // the stars: place, speed and phase of the twinkling
double lg_sy[60];
double lg_sf[60];
double lg_sp[60];
char lg_ramp2[96];
char lg_ramp_m[16];          // the Moon is made of digits: 1 7 3 5 2 9 6 0 8 @           // a long ramp of characters from empty to dense: many steps of shade
int lg_n2;
int lg_nm;
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
    while s[i] != 0 && lg_len < 130000 {
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

// YYYY-MM-DD HH:MM:SS (UTC) of a time given as seconds since 1970
void lg_cdate(int sec) {
    int days = sec / 86400;
    int day = sec % 86400;
    int z = days + 719468;                                  // the civil calendar from the number of days
    int era = z / 146097;
    int doe = z - era * 146097;
    int yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    int y = yoe + era * 400;
    int doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    int mp = (5 * doy + 2) / 153;
    int d = doy - (153 * mp + 2) / 5 + 1;
    int m = mp + 3;
    if mp >= 10 { m = mp - 9; }
    if m <= 2 { y = y + 1; }
    char t[24];
    t[0] = '0' + (y / 1000) % 10;
    t[1] = '0' + (y / 100) % 10;
    t[2] = '0' + (y / 10) % 10;
    t[3] = '0' + y % 10;
    t[4] = '-';
    t[5] = '0' + m / 10;
    t[6] = '0' + m % 10;
    t[7] = '-';
    t[8] = '0' + d / 10;
    t[9] = '0' + d % 10;
    t[10] = ' ';
    t[11] = '0' + (day / 3600) / 10;
    t[12] = '0' + (day / 3600) % 10;
    t[13] = ':';
    t[14] = '0' + ((day % 3600) / 60) / 10;
    t[15] = '0' + ((day % 3600) / 60) % 10;
    t[16] = ':';
    t[17] = '0' + (day % 60) / 10;
    t[18] = '0' + (day % 60) % 10;
    t[19] = 0;
    lg_ct(@t);
}

// the seconds since 1970 now (the clock of the computer, UTC)
int lg_unix() {
    char ts[16];
    syscall(113, 0, @ts);
    int sec = 0;
    int k = 7;
    while k >= 0 {
        sec = sec * 256 + (ts[k] & 255);
        k -= 1;
    }
    return sec;
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

// the same with a 4 x 4 dither (the pattern of Bayer): the cell at (x, y) takes the character above or below the exact shade, in a
// fine pattern, so that slow changes of the light look smooth
char lg_pick_at(double v, int x, int y) {
    if v < 0.0 { v = 0.0; }
    if v > 1.0 { v = 1.0; }
    v = v * (1.7 - 0.7 * v);
    double kf = v * (double)(lg_n2 - 1);
    int k = (int)kf;
    double fr = kf - (double)k;
    int bi = (x % 4) * 4 + (y % 4);
    int bm[16];
    bm[0] = 0;  bm[1] = 8;  bm[2] = 2;  bm[3] = 10;
    bm[4] = 12; bm[5] = 4;  bm[6] = 14; bm[7] = 6;
    bm[8] = 3;  bm[9] = 11; bm[10] = 1; bm[11] = 9;
    bm[12] = 15; bm[13] = 7; bm[14] = 13; bm[15] = 5;
    double th = ((double)bm[bi] + 0.5) / 16.0;
    if fr > th { k += 1; }
    if k > lg_n2 - 1 { k = lg_n2 - 1; }
    return lg_ramp2[k];
}

// the character for the edge of a shape that covers some of the four quarters of a cell (1 = top left, 2 = top right, 4 = bottom left,
// 8 = bottom right): the character looks like the line that cuts the cell
char lg_edge_char(int m) {
    if m == 1 { return '\''; }
    if m == 2 { return '`'; }
    if m == 4 { return ','; }
    if m == 8 { return '.'; }
    if m == 3 { return '_'; }                       // the top half is covered: the line is at the bottom
    if m == 12 { return '"'; }                      // the bottom half is covered: the line is at the top
    if m == 5 { return ')'; }                       // the left half is covered: the right limb of a ball
    if m == 10 { return '('; }                      // the right half: the left limb
    if m == 7 || m == 14 { return '/'; }
    if m == 11 || m == 13 { return '\\'; }
    if m == 9 { return ';'; }
    return ':';
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
    int top = (lg_rows - LH - 5) / 2 + 1;
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
    while n < 5 {
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
    if speed < 1 { speed = 1800; }
    double ts = (double)speed;
    lg_find_color();
    char^ rp = " .'`^\",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$";
    lg_n2 = 0;
    while rp[lg_n2] != 0 && lg_n2 < 90 {
        lg_ramp2[lg_n2] = rp[lg_n2];
        lg_n2 += 1;
    }
    int seed = 4242;
    int i = 0;
    while i < 60 {
        seed = (seed * 1103515245 + 12345) & 2147483647;
        lg_sx[i] = (double)((seed >> 8) % 1000) / 1000.0;               // 0..1 of the width
        seed = (seed * 1103515245 + 12345) & 2147483647;
        lg_sy[i] = (double)((seed >> 8) % 1000) / 1000.0;               // 0..1 of the height
        seed = (seed * 1103515245 + 12345) & 2147483647;
        lg_sf[i] = 1.5 + (double)((seed >> 8) % 1000) / 1000.0 * 4.0;
        seed = (seed * 1103515245 + 12345) & 2147483647;
        lg_sp[i] = (double)((seed >> 8) % 1000) / 1000.0 * 6.283;
        i += 1;
    }
    // the craters of the Moon: places on the surface from a fixed random sequence
    i = 0;
    while i < 14 {
        seed = (seed * 1103515245 + 12345) & 2147483647;
        double za = (double)((seed >> 8) % 2000) / 1000.0 - 1.0;
        seed = (seed * 1103515245 + 12345) & 2147483647;
        double fa = (double)((seed >> 8) % 6283) / 1000.0;
        double rz = __fsqrt(1.0 - za * za);
        lg_crx[i] = rz * lg_cos(fa);
        lg_cry[i] = za;
        lg_crz[i] = rz * lg_sin(fa);
        seed = (seed * 1103515245 + 12345) & 2147483647;
        lg_crr[i] = 0.10 + (double)((seed >> 8) % 1000) / 1000.0 * 0.16;
        i += 1;
    }
    lg_read_size();
    lg_w = 50;
    lg_h = 20;
    if lg_cols >= 62 && lg_rows >= 29 {
        lg_w = 60;
        lg_h = 24;
    }
    if lg_cols >= 78 && lg_rows >= 35 {
        lg_w = 76;
        lg_h = 30;
    }
    if lg_cols >= 104 && lg_rows >= 46 {
        lg_w = 100;
        lg_h = 40;
    }
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
    // the scale: the Earth and the Moon with its orbit have to fit in the width; the Earth has the radius 1
    double dm = 1.70;                                     // the Moon is drawn at 1.70 Earth radii (real 60.3: not to scale, or it would be off the screen)
    double rm = 0.62;                                     // and with the radius 0.62 of the Earth's (real 0.273), so that the J on it can be read
    double unit = (double)LW / 10.2;                       // rows for the radius of the Earth (a character is twice as high as wide)
    double km_row = 6371.0 / unit;                        // kilometres in one row of the picture
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
    double solar_day = 86400.0;                           // one turn of the Earth, seen from the Sun (the Sun is frozen in this picture)
    double synodic = 29.530588853 * 86400.0;              // the Moon goes once round the Earth and back to the same phase
    double sun_km = 149597870.7;
    double moon_km = 384400.0;
    double c_kms = 299792.458;
    double sun_delay = sun_km / c_kms;                    // 499 s
    double moon_delay = moon_km / c_kms;                  // 1.28 s
    // the Sun: a fixed direction (from the left and the front), in the plane of the orbits
    double lam_s = 3.9;
    double lx = lg_cos(lam_s);
    double lz = lg_sin(lam_s);
    double ly = 0.0;
    // the axis of the Earth leans 23.44 degrees (its north pole towards us a little)
    double tilt = 23.44 * pi / 180.0;
    lg_ax = 0.0;
    lg_ay = lg_cos(tilt);
    lg_az = 0.0 - lg_sin(tilt);
    // the Moon turns on its own axis (it leans 6.68 degrees); the letter J is on the face that looks at us at the start
    double mtilt_ax = 6.68 * pi / 180.0;
    double max_ = 0.0;
    double may = lg_cos(mtilt_ax);
    double maz = 0.0 - lg_sin(mtilt_ax);
    double c0x = 0.0;
    double c0y = 0.0;
    double c0z = 0.0 - 1.0;
    double ex = c0y * maz - c0z * may;                    // east = c0 x axis
    double ey = c0z * max_ - c0x * maz;
    double ez = c0x * may - c0y * max_;
    double el = __fsqrt(ex * ex + ey * ey + ez * ez);
    ex = ex / el;
    ey = ey / el;
    ez = ez / el;
    double nx0 = ey * c0z - ez * c0y;                     // north = east x c0
    double ny0 = ez * c0x - ex * c0z;
    double nz0 = ex * c0y - ey * c0x;
    double moon_spin_s = 40.0;                            // the Moon turns once in 40 seconds of the film (an artist's number: the real Moon turns once a month, locked to the Earth)
    double mtilt = 0.0897;                                // the orbit of the Moon leans 5.14 degrees
    // where the real Moon is now: the phase from the clock (a new moon was on 2000-01-06 18:14 UTC, JD 2451550.26)
    int unix0 = lg_unix();
    double jd = (double)unix0 / 86400.0 + 2440587.5;
    double cyc = (jd - 2451550.26) / 29.530588853;
    cyc = cyc - (double)(int)cyc;
    if cyc < 0.0 { cyc = cyc + 1.0; }
    double theta0 = tau * cyc;                            // the angle of the Moon ahead of the Sun
    int frame = 0;
    int t0 = lg_now();
    while frames == 0 || frame < frames {
        double t = (double)frame / 24.0;
        double real_s = t * ts;                           // the time that has passed on the Earth since the start, seconds
        // the Moon goes round the Earth: relative to the fixed Sun one turn is the synodic month
        double lam_m = lam_s + theta0 + tau * real_s / synodic;
        double mx = dm * lg_cos(lam_m);
        double mz = dm * lg_sin(lam_m);
        double my = dm * lg_sin(lam_m) * mtilt;
        double espin = 0.0 - tau * real_s / solar_day;    // the Earth turns west to east: the face we see goes from left to right
        double mspin = 0.0 - tau * t / moon_spin_s;       // the Moon the same way, about its own axis
        // the stars first
        i = 0;
        while i < LCELLS {
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
            int sxs = (int)(lg_sx[i] * (double)LW);
            int sys = (int)(lg_sy[i] * (double)LH);
            if sxs < LW && sys < LH {
                lg_ch[sys * LW + sxs] = c;
                lg_col[sys * LW + sxs] = lg_grey(0.35 + 0.55 * tw);
            }
            i += 1;
        }
        int y = 0;
        while y < LH {
            int x = 0;
            while x < LW {
                // four rays for each character (2 x 2), averaged: smooth edges and smooth shades
                double sumb = 0.0;
                int mask = 0;                                          // which of the four rays found something that shows (1 2 / 4 8)
                int lit_n = 0;
                double dmin = 1000.0;
                int sj = 0;
                while sj < 2 {
                    int si = 0;
                    while si < 2 {
                        double xs = ((double)x + ((double)si + 0.5) / 2.0 - cxs) / (unit * 2.0);
                        double ys = ((double)y + ((double)sj + 0.5) / 2.0 - cys) / unit;
                        double ox = lg_rx * xs - lg_ux * ys - lg_fx * 6.0;
                        double oy = lg_ry * xs - lg_uy * ys - lg_fy * 6.0;
                        double oz = lg_rz * xs - lg_uz * ys - lg_fz * 6.0;
                        double te = lg_ball(ox, oy, oz, lg_fx, lg_fy, lg_fz, 0.0, 0.0, 0.0, 1.0);
                        double tm = lg_ball(ox, oy, oz, lg_fx, lg_fy, lg_fz, mx, my, mz, rm);
                        if te < 999.0 && te <= tm {
                            // the Earth: a ball with the sea, the lands, clouds and the ice of the poles, turning on its axis
                            double hx = ox + lg_fx * te;
                            double hy = oy + lg_fy * te;
                            double hz = oz + lg_fz * te;
                            double lam = hx * lx + hy * ly + hz * lz;
                            if lam < 0.0 { lam = 0.0; }
                            lam = lam * (1.3 - 0.3 * lam);                       // the edge of the night is soft
                            // the Moon may hide the Sun (an eclipse of the Sun)
                            if lam > 0.0 {
                                double ts2 = lg_ball(hx, hy, hz, lx, ly, lz, mx, my, mz, rm);
                                if ts2 < 999.0 { lam = lam * 0.12; }
                            }
                            lg_ax = 0.0;
                            lg_ay = lg_cos(tilt);
                            lg_az = 0.0 - lg_sin(tilt);
                            lg_rot(hx, hy, hz, 0.0 - espin);
                            double p0x = lg_vx;
                            double p0y = lg_vy;
                            double p0z = lg_vz;
                            double lat = p0x * lg_ax + p0y * lg_ay + p0z * lg_az;               // the sine of the latitude
                            double land = lg_sin(p0x * 2.6 + 1.0) * lg_sin(p0y * 3.1 + 0.5) * lg_sin(p0z * 2.3 + 2.0)
                                + 0.35 * lg_sin(p0x * 7.0 + 2.0) * lg_sin(p0z * 6.0 + p0y * 5.0);
                            double albedo = 0.50;
                            if land > 0.10 { albedo = 0.80; }
                            if land > 0.10 && land < 0.18 { albedo = 0.65; }                      // the shore
                            // the clouds drift a little faster than the ground
                            double cl = lg_sin(p0x * 3.3 + 2.0 * lg_sin(p0y * 2.5 + 0.9 * t) + 1.0) * lg_sin(p0z * 2.9 + 1.5 * lg_sin(p0x * 3.1) + 0.5 * t);
                            if cl > 0.30 { albedo = albedo + (1.0 - albedo) * lg_clamp((cl - 0.30) * 3.0, 0.0, 1.0); }
                            if lat > 0.86 || lat < 0.0 - 0.86 { albedo = 0.97; }                // the ice of the poles
                            double ndv = 0.0 - (hx * lg_fx + hy * lg_fy + hz * lg_fz);
                            if ndv < 0.0 { ndv = 0.0; }
                            double rim = 1.0 - ndv;
                            rim = rim * rim * rim;
                            // a bright spot of the Sun on the sea
                            double hx2 = lx - lg_fx;
                            double hy2 = ly - lg_fy;
                            double hz2 = lz - lg_fz;
                            double hl = __fsqrt(hx2 * hx2 + hy2 * hy2 + hz2 * hz2);
                            double refl = 0.0;
                            if hl > 0.0 && land <= 0.10 && cl <= 0.30 {
                                double nh = (hx * hx2 + hy * hy2 + hz * hz2) / hl;
                                if nh > 0.0 {
                                    double n2 = nh * nh;
                                    n2 = n2 * n2;
                                    n2 = n2 * n2;
                                    refl = n2 * n2;
                                }
                            }
                            double bright = 0.07 + 0.90 * lam * albedo + 0.20 * rim * (0.15 + lam) + 0.30 * refl;
                            // the lights of the cities: on the land that the Sun does not light, small bright points
                            double night = 1.0 - lg_clamp(lam * 4.0, 0.0, 1.0);
                            if night > 0.0 && land > 0.10 && lat < 0.80 && lat > 0.0 - 0.80 && cl < 0.30 {
                                double ct = lg_sin(p0x * 21.0 + 1.0) * lg_sin(p0y * 17.0 + 2.0) * lg_sin(p0z * 19.0 + 0.5);
                                if ct > 0.40 { bright = bright + lg_clamp((ct - 0.40) * 3.0, 0.0, 0.5) * night; }
                            }
                            if bright > 1.0 { bright = 1.0; }
                            sumb = sumb + bright;
                            mask = mask | (1 << (sj * 2 + si));
                            lit_n += 1;
                            if te < dmin { dmin = te; }
                        } else if tm < 999.0 {
                            // the Moon: craters and dark seas, the letter J on its surface, turning with it
                            double hx = ox + lg_fx * tm;
                            double hy = oy + lg_fy * tm;
                            double hz = oz + lg_fz * tm;
                            double nx = (hx - mx) / rm;
                            double ny = (hy - my) / rm;
                            double nz = (hz - mz) / rm;
                            lg_ax = max_;
                            lg_ay = may;
                            lg_az = maz;
                            lg_rot(nx, ny, nz, 0.0 - mspin);
                            double p0x = lg_vx;
                            double p0y = lg_vy;
                            double p0z = lg_vz;
                            // the letter is on two opposite faces of the Moon (a J on the front and one on the back, each the right way
                            // round for someone who looks at it), so that one of them is always turned towards us
                            double facing = p0x * c0x + p0y * c0y + p0z * c0z;
                            double sgn = 1.0;
                            if facing < 0.0 {
                                sgn = 0.0 - 1.0;
                                facing = 0.0 - facing;
                            }
                            double jx = sgn * (p0x * ex + p0y * ey + p0z * ez) * 0.95;
                            double jy = 0.0 - (p0x * nx0 + p0y * ny0 + p0z * nz0) * 0.95 + 0.06;
                            double cov = 0.0;
                            double dcx = 0.0;
                            double dcy = 0.0;
                            if facing > 0.15 {
                                cov = lg_j(jx, jy);
                                double e = 0.03;
                                dcx = sgn * (lg_j(jx + e, jy) - lg_j(jx - e, jy)) / (2.0 * e);
                                dcy = (lg_j(jx, jy + e) - lg_j(jx, jy - e)) / (2.0 * e);
                            }
                            // the normal, bent at the edges of the letter so that it stands out of the surface
                            double bump = 0.30;
                            double qx = p0x - bump * (dcx * ex * 0.95 - dcy * nx0 * 0.95);
                            double qy = p0y - bump * (dcx * ey * 0.95 - dcy * ny0 * 0.95);
                            double qz = p0z - bump * (dcx * ez * 0.95 - dcy * nz0 * 0.95);
                            double ql = __fsqrt(qx * qx + qy * qy + qz * qz);
                            lg_rot(qx / ql, qy / ql, qz / ql, mspin);
                            double lam = lg_vx * lx + lg_vy * ly + lg_vz * lz;
                            if lam < 0.0 { lam = 0.0; }
                            // the shadow of the Earth (an eclipse of the Moon)
                            if lam > 0.0 {
                                double ts2 = lg_ball(hx, hy, hz, lx, ly, lz, 0.0, 0.0, 0.0, 1.0);
                                if ts2 < 999.0 { lam = lam * 0.10; }
                            }
                            // the grey of the Moon with a few dark seas and craters (a bright rim, a darker floor), the letter white
                            double patch = lg_sin(p0x * 4.0 + 1.0) * lg_sin(p0y * 5.0 + 0.5) * lg_sin(p0z * 3.0 + 2.0);
                            double albedo = 0.66;
                            if patch > 0.18 { albedo = 0.44; }
                            int ci = 0;
                            while ci < 14 {
                                double cdx = p0x - lg_crx[ci];
                                double cdy = p0y - lg_cry[ci];
                                double cdz = p0z - lg_crz[ci];
                                double cd = __fsqrt(cdx * cdx + cdy * cdy + cdz * cdz);
                                double crr = lg_crr[ci];
                                if cd < crr { albedo = albedo * 0.72; }
                                else if cd < crr * 1.3 { albedo = albedo * 1.22; }
                                ci += 1;
                            }
                            if albedo > 1.0 { albedo = 1.0; }
                            albedo = albedo + (1.0 - albedo) * cov;
                            // what the Sun does not light is left black
                            double bright = lam * albedo;
                            // the letter J glows a little (like a logo), so that it can be read even in the dark part; the rest is left black
                            if bright < 0.55 * cov { bright = 0.55 * cov; }
                            if bright > 1.0 { bright = 1.0; }
                            if bright > 0.04 {
                                sumb = sumb + bright;
                                mask = mask | (1 << (sj * 2 + si));
                                lit_n += 1;
                                if tm < dmin { dmin = tm; }
                            }
                        } else {
                            // the air of the Earth: a thin glow round the edge of the ball on the side that the Sun lights
                            double along = ox * lg_fx + oy * lg_fy + oz * lg_fz;
                            double px = ox - lg_fx * along;
                            double py = oy - lg_fy * along;
                            double pz = oz - lg_fz * along;
                            double pd = __fsqrt(px * px + py * py + pz * pz);
                            if pd > 1.0 && pd < 1.11 {
                                double sun_side = (px * lx + py * ly + pz * lz) / pd + 0.25;
                                double fade = (1.11 - pd) / 0.11;
                                double bright = 0.55 * sun_side * fade * fade;
                                if bright > 0.05 {
                                    if bright > 1.0 { bright = 1.0; }
                                    sumb = sumb + bright;
                                    mask = mask | (1 << (sj * 2 + si));
                                    lit_n += 1;
                                }
                            }
                        }
                        si += 1;
                    }
                    sj += 1;
                }
                if mask == 15 {
                    // the cell is full: a character of the ramp by the shade
                    double v = sumb / 4.0;
                    lg_ch[y * LW + x] = lg_pick_at(v, x, y);
                    lg_col[y * LW + x] = lg_grey(v);
                    lg_dep[y * LW + x] = dmin;
                } else if mask != 0 {
                    // the edge of a shape: a character that follows the line (the right limb of a ball is ')', the top of a ball '"', ...)
                    double v = sumb / (double)lit_n;
                    lg_ch[y * LW + x] = lg_edge_char(mask);
                    lg_col[y * LW + x] = lg_grey(0.30 + 0.70 * v);
                    lg_dep[y * LW + x] = dmin;
                }
                x += 1;
            }
            y += 1;
        }
        // the orbit of the Moon: faint dots
        int n = 0;
        while n < 140 {
            double a = (double)n * tau / 140.0;
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
        // the word MOON under the Moon, and EARTH under the Earth
        double mqx = mx * lg_rx + my * lg_ry + mz * lg_rz;
        double mqy = mx * lg_ux + my * lg_uy + mz * lg_uz;
        int lcx = (int)(cxs + mqx * unit * 2.0);
        int lcy = (int)(cys - mqy * unit + rm * unit + 1.5);
        char^ word = "MOON";
        int wi = 0;
        while wi < 4 {
            int wx2 = lcx - 2 + wi;
            if wx2 >= 0 && wx2 < LW && lcy >= 0 && lcy < LH {
                if lg_ch[lcy * LW + wx2] == ' ' || lg_ch[lcy * LW + wx2] == '.' {
                    lg_ch[lcy * LW + wx2] = word[wi];
                    lg_col[lcy * LW + wx2] = lg_grey(0.70);
                }
            }
            wi += 1;
        }
        // how much of the Moon is lit as we see it from the Earth, and whether it grows
        double ml = __fsqrt(mx * mx + my * my + mz * mz);
        double cth = (mx * lx + my * ly + mz * lz) / ml;
        double lit = (1.0 - cth) / 2.0;
        double dl = lam_m - lam_s;
        while dl > pi { dl = dl - tau; }
        while dl < 0.0 - pi { dl = dl + tau; }
        int waxing = 0;
        if dl > 0.0 { waxing = 1; }
        // the five lines under the picture
        lg_cbegin(0);
        lg_ct("by J2k-studio  (Ctrl-C/Enter: stop)");
        lg_cbegin(1);
        lg_ct("UTC now ");
        lg_cdate(lg_unix());
        lg_ct("   film +");
        lg_cdur(real_s);
        lg_cbegin(2);
        lg_ct("time: 1 s = ");
        lg_cdur(ts);
        lg_ct(" (x");
        lg_cnum(speed);
        lg_ct(")  Earth turn ");
        lg_cdur(solar_day / ts);
        lg_ct("  Moon cycle ");
        lg_cdur(synodic / ts);
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
        lg_cbegin(4);
        lg_ct("scale: 1 row = ");
        lg_cnum((int)km_row);
        lg_ct(" km; Moon at 1.70R, size 0.62R (real 60R, 0.27R)");
        lg_show();
        if frames == 0 && lg_key() { frame = 0 - 1; break; }
        frame += 1;
        int due = t0 + frame * 41666666;
        int now = lg_now();
        if due > now { lg_sleep_ns(due - now); }
    }
}
