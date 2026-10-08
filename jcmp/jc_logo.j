// jc_logo.j -- the mascot: jcmp -space shows the J2K logo in ASCII style and in 3D (isometric): a solid J, lit from above and
// shaded with characters, with bodies that go round it by Kepler's laws, twinkling stars, 24 frames a second. Small and of a fixed size (50 x 20 characters), in the middle of the terminal,
// all in J2K with no library. Stops on Ctrl-C or Enter.

#define LW 50
#define LH 20
#define LN 1000
char lg_ch[LN];            // 50 x 20 characters of the picture
double lg_dep[LN];         // how far from the eye what is drawn in each cell is (to hide the dots of the orbits behind the J)
double lg_bx[4];           // the bodies that go round: their places
double lg_by[4];
double lg_bz[4];
double lg_fx;              // the view: forward, right and up (the up and down of the picture)
double lg_fy;
double lg_fz;
double lg_rx;
double lg_ry;
double lg_rz;
double lg_ux;
double lg_uy;
double lg_uz;
double lg_t;               // seconds of the film so far
double lg_ts;              // how many times faster than real time the film runs
int lg_col[LN];            // the colour of each character (0xRRGGBB), used if the terminal has 24-bit colour
int lg_color_on;           // 1: use the colours
double lg_cs;              // the planet turns about its axis: cos and sin of the angle now
double lg_sn;
char lg_buf[49152];           // the text of one frame
int lg_len;
double lg_sx[60];            // the stars: place, speed and phase of the twinkling
double lg_sy[60];
double lg_sf[60];
double lg_sp[60];
char lg_ramp[16];
char lg_ramp2[96];           // a long ramp of characters from empty to dense: many steps of shade
int lg_n2;            // " .:-=+*#%@": from nothing to the brightest

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

// how close the point (x, y) is to the letter J (0 = far, 1 = inside the stroke); the letter fills -1..1
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
        double ey = lg_clamp(y, 0.12, 0.30);                                    // the end of the hook goes a little up
        d = lg_min(d, __fsqrt((x + 0.48) * (x + 0.48) + (y - ey) * (y - ey)));
    }
    return lg_clamp(1.0 - (d - 0.085) / 0.05, 0.0, 1.0);
}

void lg_text(char^ s) {
    int i = 0;
    while s[i] != 0 && lg_len < 131000 {
        lg_buf[lg_len] = s[i];
        lg_len += 1;
        i += 1;
    }
}

void lg_num(int v) {
    char d[8];
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

int lg_mix(int a, int b, double f) {
    if f < 0.0 { f = 0.0; }
    if f > 1.0 { f = 1.0; }
    int r = (int)((double)((a >> 16) & 255) * (1.0 - f) + (double)((b >> 16) & 255) * f);
    int g = (int)((double)((a >> 8) & 255) * (1.0 - f) + (double)((b >> 8) & 255) * f);
    int bl = (int)((double)(a & 255) * (1.0 - f) + (double)(b & 255) * f);
    return (r << 16) | (g << 8) | bl;
}

int lg_scale(int a, double f) {
    int r = (int)((double)((a >> 16) & 255) * f);
    int g = (int)((double)((a >> 8) & 255) * f);
    int b = (int)((double)(a & 255) * f);
    if r > 255 { r = 255; }
    if g > 255 { g = 255; }
    if b > 255 { b = 255; }
    return (r << 16) | (g << 8) | b;
}

// does the terminal say it has 24-bit colour? (COLORTERM=truecolor or 24bit in the environment)
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

// the character for a brightness 0..1
char lg_pick(double v) {
    if v < 0.0 { v = 0.0; }
    int k = (int)(v * (double)(lg_n2 - 1) + 0.5);
    if k > lg_n2 - 1 { k = lg_n2 - 1; }
    return lg_ramp2[k];
}
    int k = (int)(v * 9.99);
    if k > 9 { k = 9; }
    return lg_ramp[k];
}

// puts a ring dot in a cell (the brighter character wins)
void lg_dot(int x, int y, double v) {
    if x < 0 || x >= LW || y < 0 || y >= LH { return; }
    char c = lg_pick(v);
    int at = y * LW + x;
    int old = 0;
    int k = 0;
    while k < 10 {
        if lg_ramp[k] == lg_ch[at] { old = k; }
        k += 1;
    }
    int now = 0;
    k = 0;
    while k < 10 {
        if lg_ramp[k] == c { now = k; }
        k += 1;
    }
    if now >= old { lg_ch[at] = c; }
}

// HH:MM:SS of the clock of the computer now (UTC)
void lg_clock() {
    char ts[16];
    syscall(113, 0, @ts);                                   // the real-time clock
    int sec = 0;
    int k = 7;
    while k >= 0 {
        sec = sec * 256 + (ts[k] & 255);
        k -= 1;
    }
    int day = sec % 86400;
    int h = day / 3600;
    int m = (day % 3600) / 60;
    int sc = day % 60;
    lg_buf[lg_len] = '0' + h / 10;
    lg_buf[lg_len + 1] = '0' + h % 10;
    lg_buf[lg_len + 2] = ':';
    lg_buf[lg_len + 3] = '0' + m / 10;
    lg_buf[lg_len + 4] = '0' + m % 10;
    lg_buf[lg_len + 5] = ':';
    lg_buf[lg_len + 6] = '0' + sc / 10;
    lg_buf[lg_len + 7] = '0' + sc % 10;
    lg_len += 8;
}

int lg_cols;                 // the size of the terminal, read once
int lg_rows;

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
    // under the picture: who made it, and how to stop
    lg_buf[lg_len] = 27;
    lg_len += 1;
    lg_text("[");
    lg_num(top + LH);
    lg_text(";");
    lg_num(left + LW / 2 - 11);
    lg_text("Hcreated by J2k-studio");
    lg_buf[lg_len] = 27;
    lg_len += 1;
    lg_text("[");
    lg_num(top + LH + 1);
    lg_text(";");
    lg_num(left + LW / 2 - 12);
    lg_text("H(Ctrl-C or Enter to stop)");
    lg_buf[lg_len] = 27;
    lg_len += 1;
    lg_text("[");
    lg_num(top + LH + 2);
    lg_text(";");
    lg_num(left + LW / 2 - 21);
    lg_text("Hreal Saturn speeds, time x");
    lg_num((int)lg_ts);
    // the time on Earth: the clock now (UTC), and how much time has passed on the planet in the film
    lg_buf[lg_len] = 27;
    lg_len += 1;
    lg_text("[");
    lg_num(top + LH + 3);
    lg_text(";");
    lg_num(left + LW / 2 - 19);
    lg_text("HEarth time (UTC) ");
    lg_clock();
    lg_text("  film = ");
    double hours = lg_t * lg_ts / 3600.0;
    lg_num((int)hours);
    lg_text(".");
    lg_num((int)((hours - (double)(int)hours) * 10.0));
    lg_text(" h");
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
    double r = ((-0.0464964749 * s2 + 0.15931422) * s2 - 0.327622764) * s2 * a + a;       // atan(a), a in 0..1
    if az > ax { r = 1.570796326794897 - r; }
    if x < 0.0 { r = pi - r; }
    if z < 0.0 { r = 0.0 - r; }
    return r;
}

// the distance from the point (x, y, z) (y up) to the solid J: a letter with a stroke 0.23 wide and 0.34 deep
double lg_jsd(double xw, double y0, double zw) {
    double x0 = xw * lg_cs + zw * lg_sn;                   // the planet turns: look at the letter turned back
    double z0 = 0.0 - xw * lg_sn + zw * lg_cs;
    double k = 0.80;                                       // the letter is drawn at 1 / 0.62 times its size
    double x = x0 * k;
    double y = y0 * k - 0.12;                             // the letter hangs down: the plane of the rings crosses its upper part, and its tail shows below
    double z = z0 * k;
    double yd = 0.0 - y;
    double d = 9.0;
    double bx = lg_clamp(x, 0.0 - 0.18, 0.46);
    d = lg_min(d, __fsqrt((x - bx) * (x - bx) + (yd + 0.80) * (yd + 0.80)));
    double sy = lg_clamp(yd, 0.0 - 0.80, 0.30);
    d = lg_min(d, __fsqrt((x - 0.14) * (x - 0.14) + (yd - sy) * (yd - sy)));
    double cx = x + 0.17;
    double cy = yd - 0.30;
    if cy >= 0.0 {
        d = lg_min(d, lg_abs(__fsqrt(cx * cx + cy * cy) - 0.31));
    } else if cx < 0.0 {
        double ey = lg_clamp(yd, 0.12, 0.30);
        d = lg_min(d, __fsqrt((x + 0.48) * (x + 0.48) + (yd - ey) * (yd - ey)));
    }
    double a = d - 0.125;                                  // across the stroke
    double b = lg_abs(z) - 0.17;                           // through the depth
    double oa = a;
    double ob = b;
    if oa < 0.0 { oa = 0.0; }
    if ob < 0.0 { ob = 0.0; }
    double inside = a;
    if b > inside { inside = b; }
    if inside > 0.0 { inside = 0.0; }
    return (inside + __fsqrt(oa * oa + ob * ob)) / k;
}

// the distance to the nearest body (a small ball); which = its number
int lg_which;
double lg_balls(double x, double y, double z) {
    double best = 9.0;
    int i = 0;
    while i < 4 {
        double dx = x - lg_bx[i];
        double dy = y - lg_by[i];
        double dz = z - lg_bz[i];
        double d = __fsqrt(dx * dx + dy * dy + dz * dz) - 0.115;
        if d < best {
            best = d;
            lg_which = i;
        }
        i += 1;
    }
    return best;
}

double lg_scene(double x, double y, double z) {
    return lg_jsd(x, y, z);
}

// the rings of the planet: how bright the gas is at radius r (0 = no ring there). Like Saturn: a faint inner ring, a bright
// broad ring, a dark gap, and an outer ring
double lg_ring(double r) {
    double km = r / 0.85 * 60268.0;                         // the planet is 60268 km in radius and 0.85 units here
    if km > 139700.0 && km < 140700.0 { return 0.55; }      // the thin F ring
    if km < 74658.0 || km > 136775.0 { return 0.0; }       // the C ring starts, the A ring ends
    if km > 133300.0 && km < 133900.0 { return 0.0; }      // the Encke gap in the A ring
    if km < 92000.0 { return 0.30; }                        // C ring
    if km < 117580.0 { return 0.78; }                       // B ring
    if km < 122170.0 { return 0.0; }                        // the Cassini division
    return 0.52;                                            // A ring
}

// the logo: frames = 0 runs until Ctrl-C or Enter; speed = how many times faster than real time the planet and rings go
void lg_run(int frames, int speed) {
    if speed < 1 { speed = 1500; }
    lg_ts = (double)speed;
    lg_find_color();
    char^ rp = " .'`^,:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$";
    lg_n2 = 0;
    while rp[lg_n2] != 0 && lg_n2 < 90 {
        lg_ramp2[lg_n2] = rp[lg_n2];
        lg_n2 += 1;
    }
    lg_ramp[0] = ' ';
    lg_ramp[1] = '.';
    lg_ramp[2] = ':';
    lg_ramp[3] = '-';
    lg_ramp[4] = '=';
    lg_ramp[5] = '+';
    lg_ramp[6] = '*';
    lg_ramp[7] = '#';
    lg_ramp[8] = '%';
    lg_ramp[9] = '@';
    lg_ramp[10] = 0;
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
    lg_read_size();                                       // first the size of the terminal, then the picture in its middle
    char clear[8];
    clear[0] = 27;
    clear[1] = '[';
    clear[2] = '2';
    clear[3] = 'J';
    clear[4] = 0;
    write_out(@clear);
    double cxs = (double)LW / 2.0;
    double cys = (double)LH / 2.0;
    double unit = (double)LH * 0.29;                      // rows for one unit of the scene (a character is twice as high as wide)
    // the light: from above, a little from the left and the front (y is up)
    double lx = 0.0 - 0.42;
    double ly = 0.80;
    double lz = 0.0 - 0.43;
    double ln = __fsqrt(lx * lx + ly * ly + lz * lz);
    lx = lx / ln;
    ly = ly / ln;
    lz = lz / ln;
    int frame = 0;
    int t0 = lg_now();
    while frames == 0 || frame < frames {
        double t = (double)frame / 24.0;
        lg_t = t;
        double pulse = 0.9 + 0.1 * lg_sin(t * 2.0);
        // the view turns a little to and fro: that is what makes it look solid
        // the view does not move: all the motion is the planet's and the rings' own. The planet turns once in 10.56 hours
        // (real time), lg_ts times faster here; its axis leans 26.73 degrees.
        double yaw = 0.7853981633974483;
        double sinp = 0.5773502691896258;                       // looking down at the isometric angle
        double cosp = 0.816496580927726;
        lg_fx = lg_sin(yaw) * cosp;
        lg_fy = 0.0 - sinp;
        lg_fz = lg_cos(yaw) * cosp;
        lg_rx = lg_cos(yaw);
        lg_ry = 0.0;
        lg_rz = 0.0 - lg_sin(yaw);
        double spin = 0.0001653 * lg_ts * t;
        lg_cs = lg_cos(spin);
        lg_sn = lg_sin(spin);
        lg_ux = lg_fy * lg_rz - lg_fz * lg_ry;            // up = forward x right
        lg_uy = lg_fz * lg_rx - lg_fx * lg_rz;
        lg_uz = lg_fx * lg_ry - lg_fy * lg_rx;
        // the axis leans: turn the picture plane by 26.73 degrees
        double cr = 0.8933;
        double sr2 = 0.4497;
        double nrx = lg_rx * cr + lg_ux * sr2;
        double nry = lg_ry * cr + lg_uy * sr2;
        double nrz = lg_rz * cr + lg_uz * sr2;
        double nux = 0.0 - lg_rx * sr2 + lg_ux * cr;
        double nuy = 0.0 - lg_ry * sr2 + lg_uy * cr;
        double nuz = 0.0 - lg_rz * sr2 + lg_uz * cr;
        lg_rx = nrx;
        lg_ry = nry;
        lg_rz = nrz;
        lg_ux = nux;
        lg_uy = nuy;
        lg_uz = nuz;
        // the stars first
        i = 0;
        while i < LN {
            lg_ch[i] = ' ';
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
            lg_col[(int)lg_sy[i] * LW + (int)lg_sx[i]] = lg_scale(14739711, 0.45 + 0.55 * tw);        // pale blue-white
            i += 1;
        }
        // every character: a ray goes into the scene (the picture is isometric: all rays are parallel)
        int y = 0;
        while y < LH {
            int x = 0;
            while x < LW {
                double xs = ((double)x + 0.5 - cxs) / (unit * 2.0);
                double ys = ((double)y + 0.5 - cys) / unit;
                double ox = lg_rx * xs - lg_ux * ys - lg_fx * 4.0;
                double oy = lg_ry * xs - lg_uy * ys - lg_fy * 4.0;
                double oz = lg_rz * xs - lg_uz * ys - lg_fz * 4.0;
                // the planet (the letter): march along the ray
                double tt = 0.0;
                int step = 0;
                int hit = 0;
                while step < 48 && tt < 8.0 {
                    double d = lg_jsd(ox + lg_fx * tt, oy + lg_fy * tt, oz + lg_fz * tt);
                    if d < 0.006 {
                        hit = 1;
                        break;
                    }
                    tt = tt + d * 0.9;
                    step += 1;
                }
                // the rings: the ray meets the flat plane y = 0 at one place
                double tp = 1000.0;
                double rr = 0.0;
                double ra = 0.0;
                double band = 0.0;
                double qx = 0.0;
                double qz = 0.0;
                if lg_abs(lg_fy) > 0.0001 {
                    tp = 0.0 - oy / lg_fy;
                    qx = ox + lg_fx * tp;
                    qz = oz + lg_fz * tp;
                    rr = __fsqrt(qx * qx + qz * qz);
                    band = lg_ring(rr);
                    ra = lg_atan2(qz, qx);
                }
                if band > 0.0 && (hit == 0 || tp < tt) {
                    // a ring: its gas goes round (Kepler: the inner part is faster), here and there in clumps
                    int sub = (int)(rr * 28.0);
                    double sr = ((double)sub + 0.5) / 28.0;
                    // Kepler with Saturn's real mass: omega = sqrt(GM / r^3) = 4.1626e-4 rad/s at one planet radius, / rho^1.5;
                    // the film runs lg_ts times faster than real time
                    double rho = sr / 0.85;
                    double omega = 0.00041626 * lg_ts / (rho * __fsqrt(rho));
                    double clump = 0.5 + 0.5 * lg_sin(5.0 * (ra - omega * t) + 7.0 * (double)sub);
                    double kmv = rr / 0.85 * 60268.0;
                    double ringlet = 0.84 + 0.16 * lg_sin(kmv / 420.0);       // fine rings, side by side
                    double v = band * (0.55 + 0.45 * clump) * ringlet;
                    // the shadow of the planet: a ray from here towards the light meets the letter?
                    double sd = 0.12;
                    int shadow = 0;
                    int ss = 0;
                    while ss < 24 && sd < 3.5 {
                        double dd = lg_jsd(qx + lx * sd, ly * sd, qz + lz * sd);
                        if dd < 0.01 {
                            shadow = 1;
                            break;
                        }
                        sd = sd + dd * 0.9 + 0.01;
                        ss += 1;
                    }
                    int tint = 14267522;                                   // the B ring: warm sand
                    if band < 0.4 { tint = 9863790; }                      // the C ring: darker, greyer
                    if band > 0.4 && band < 0.7 { tint = 12624508; }       // the A ring
                    if shadow == 1 { v = v * 0.16; }
                    lg_ch[y * LW + x] = lg_pick(v * pulse * 1.15);
                    lg_col[y * LW + x] = lg_scale(tint, 0.35 + 0.9 * v * pulse);
                    if shadow == 1 { lg_col[y * LW + x] = lg_mix(lg_col[y * LW + x], 1317434, 0.6); }     // the shadow is bluish dark
                    lg_dep[y * LW + x] = tp;
                } else if hit == 1 {
                    double hx = ox + lg_fx * tt;
                    double hy = oy + lg_fy * tt;
                    double hz = oz + lg_fz * tt;
                    // the direction the surface faces: the slope of the distance
                    double e = 0.015;
                    double nx = lg_jsd(hx + e, hy, hz) - lg_jsd(hx - e, hy, hz);
                    double ny = lg_jsd(hx, hy + e, hz) - lg_jsd(hx, hy - e, hz);
                    double nz = lg_jsd(hx, hy, hz + e) - lg_jsd(hx, hy, hz - e);
                    double nl = __fsqrt(nx * nx + ny * ny + nz * nz);
                    if nl > 0.0 {
                        nx = nx / nl;
                        ny = ny / nl;
                        nz = nz / nl;
                    }
                    double lam = nx * lx + ny * ly + nz * lz;
                    if lam < 0.0 { lam = 0.0; }
                    // the shadow of the rings: below the plane of the rings, a ray towards the light crosses them
                    if hy < 0.0 {
                        double tq = 0.0 - hy / ly;
                        double cx2 = hx + lx * tq;
                        double cz2 = hz + lz * tq;
                        if lg_ring(__fsqrt(cx2 * cx2 + cz2 * cz2)) > 0.0 { lam = lam * 0.22; }
                    }
                    // like a globe: a day side, a night side with a soft edge between, a glow at the rim where the atmosphere
                    // is seen edge on, and a small bright spot of reflected light
                    double ndv = 0.0 - (nx * lg_fx + ny * lg_fy + nz * lg_fz);
                    if ndv < 0.0 { ndv = 0.0; }
                    double rim = 1.0 - ndv;
                    rim = rim * rim * rim;
                    double refl = 0.0;
                    double hx2 = lx - lg_fx;
                    double hy2 = ly - lg_fy;
                    double hz2 = lz - lg_fz;
                    double hl = __fsqrt(hx2 * hx2 + hy2 * hy2 + hz2 * hz2);
                    if hl > 0.0 {
                        double nh = (nx * hx2 + ny * hy2 + nz * hz2) / hl;
                        if nh > 0.0 { refl = nh * nh * nh * nh * nh * nh * nh * nh * nh * nh; }
                    }
                    double day = lam;
                    if day > 1.0 { day = 1.0; }
                    // the belts of the clouds: stripes round the planet, a little wavy, that turn with it
                    double bx = hx * lg_cs + hz * lg_sn;
                    double bz = 0.0 - hx * lg_sn + hz * lg_cs;
                    double belt = 0.5 + 0.5 * lg_sin(hy * 14.0 + 0.8 * lg_sin(bx * 6.0 + bz * 4.0) + 1.0);
                    double bright = (0.08 + 0.80 * day) * (0.84 + 0.22 * belt) + 0.25 * rim * (0.30 + day) + 0.30 * refl;
                    if bright > 1.0 { bright = 1.0; }
                    lg_ch[y * LW + x] = lg_pick(bright * pulse);
                    int c = lg_mix(1778228, 16245412, day);                // from a dark night blue to warm gold
                    c = lg_mix(c, 13476196, belt * 0.45 * day);            // the belts are a little browner
                    c = lg_mix(c, 9482495, rim * 0.5);                     // a bluish glow at the edge
                    c = lg_mix(c, 16777215, refl * 0.8);
                    lg_col[y * LW + x] = lg_scale(c, 0.6 + 0.4 * pulse);
                    lg_dep[y * LW + x] = tt;
                }
                x += 1;
            }
            y += 1;
        }
        // the small moons that run beside the rings (their real distances): Prometheus 139 350 km, Pandora 141 700 km,
        // Janus 151 472 km; Kepler's law with Saturn's mass, like the rings. A moon hides behind the planet or a ring.
        int mo = 0;
        while mo < 3 {
            double mkm = 139350.0;
            double mph = 0.4;
            char mch = 'o';
            if mo == 1 { mkm = 141700.0; mph = 2.6; }
            if mo == 2 { mkm = 151472.0; mph = 4.5; mch = '*'; }
            double mr = mkm / 60268.0 * 0.85;
            double mrho = mkm / 60268.0;
            double mom = 0.00041626 * lg_ts / (mrho * __fsqrt(mrho));
            double ma = mph + mom * t;
            double mx = mr * lg_cos(ma);
            double mz = mr * lg_sin(ma);
            double sxr = mx * lg_rx + mz * lg_rz;
            double syr = mx * lg_ux + mz * lg_uz;
            int mdx = (int)(cxs + sxr * unit * 2.0);
            int mdy = (int)(cys - syr * unit);
            if mdx >= 0 && mdx < LW && mdy >= 0 && mdy < LH {
                double md = mx * lg_fx + mz * lg_fz;
                if md < lg_dep[mdy * LW + mdx] + 0.02 {
                    lg_ch[mdy * LW + mdx] = mch;
                    lg_col[mdy * LW + mdx] = 15132390;
                    lg_dep[mdy * LW + mdx] = md;
                }
            }
            mo += 1;
        }
        lg_show();
        if frames == 0 && lg_key() { frame = 0 - 1; break; }
        frame += 1;
        int due = t0 + frame * 41666666;
        int now = lg_now();
        if due > now { lg_sleep_ns(due - now); }
    }
}
