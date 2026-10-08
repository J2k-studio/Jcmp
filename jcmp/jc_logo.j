// jc_logo.j -- the mascot: jcmp -space shows the J2K logo in ASCII style and in 3D: a globe with the letter J raised on it, shaded in
// black, white and grey (the light goes slowly round it), a thin ring that turns by Kepler's law, twinkling stars, 24 frames a second. Small and of a fixed size (50 x 20 characters), in the middle of the terminal,
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
    return lg_clamp(1.0 - (d - 0.15) / 0.07, 0.0, 1.0);
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
    lg_text("HEarth: real mass and tilt, time x");
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

// the rings of the globe (an imaginary ring with real Kepler speeds): how bright the gas is at radius r (units of the globe's radius)
double lg_ring(double r) {
    if r < 1.30 || r > 1.55 { return 0.0; }
    if r < 1.38 { return 0.55; }
    if r < 1.43 { return 0.0; }                              // a gap
    return 0.40;
}

// grey to a colour number
int lg_grey(double v) {
    if v < 0.0 { v = 0.0; }
    if v > 1.0 { v = 1.0; }
    int g = (int)(30.0 + 225.0 * v);
    return (g << 16) | (g << 8) | g;
}

// the logo: frames = 0 runs until Ctrl-C or Enter; speed = how many times faster than real time the ring and the light go
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
    double cxs = (double)LW / 2.0;
    double cys = (double)LH / 2.0;
    double unit = (double)LH * 0.42;                      // rows for the radius of the globe (a character is twice as high as wide)
    // the view: from a little above, looking at the middle of the globe (all rays parallel)
    double pitch = 0.42;
    double sinp = lg_sin(pitch);
    double cosp = lg_cos(pitch);
    lg_fx = 0.0;
    lg_fy = 0.0 - sinp;
    lg_fz = cosp;
    lg_rx = 1.0;
    lg_ry = 0.0;
    lg_rz = 0.0;
    lg_ux = 0.0;                                          // up on the picture = forward x right
    lg_uy = cosp;
    lg_uz = sinp;
    // the ring leans like the axis of the Earth, 23.44 degrees: N is the normal of its plane, e1 and e2 lie in it
    double nsx = 0.3978;
    double nsy = 0.9175;
    double e1x = 0.9175;
    double e1y = 0.0 - 0.3978;
    // Earth: GM = 398600 km3/s2, radius 6371 km: omega = sqrt(GM / R3) = 1.2415e-3 rad/s at the surface; the film is faster by lg_ts
    double om0 = 0.0012415 * lg_ts;
    int frame = 0;
    int t0 = lg_now();
    while frames == 0 || frame < frames {
        double t = (double)frame / 24.0;
        lg_t = t;
        // the sun goes slowly round the globe, from the left side to the right and back: the shadow moves over the J
        double sa = 0.0 - 0.55 + 0.95 * lg_sin(t * 0.35);
        double lx = lg_sin(sa) * 0.9;
        double ly = 0.45;
        double lz = 0.0 - lg_cos(sa) * 0.9;               // towards the viewer
        double ll = __fsqrt(lx * lx + ly * ly + lz * lz);
        lx = lx / ll;
        ly = ly / ll;
        lz = lz / ll;
        // a little rocking of the globe, so that the J seems to be on its surface
        double lib = 0.22 * lg_sin(t * 0.5);
        double libp = 0.08 * lg_sin(t * 0.37 + 1.0);
        double cl = lg_cos(lib);
        double sl = lg_sin(lib);
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
                // the globe: a ball of radius 1 at the middle
                double bq = ox * lg_fx + oy * lg_fy + oz * lg_fz;
                double cq = ox * ox + oy * oy + oz * oz - 1.0;
                double disc = bq * bq - cq;
                double tg = 1000.0;
                if disc > 0.0 { tg = 0.0 - bq - __fsqrt(disc); }
                // the ring: where the ray meets its plane
                double tp = 1000.0;
                double rr = 0.0;
                double ra = 0.0;
                double band = 0.0;
                double qx = 0.0;
                double qy = 0.0;
                double qz = 0.0;
                double den = lg_fx * nsx + lg_fy * nsy;
                if lg_abs(den) > 0.0001 {
                    tp = 0.0 - (ox * nsx + oy * nsy) / den;
                    qx = ox + lg_fx * tp;
                    qy = oy + lg_fy * tp;
                    qz = oz + lg_fz * tp;
                    double u1 = qx * e1x + qy * e1y;
                    double u2 = qz;
                    rr = __fsqrt(u1 * u1 + u2 * u2);
                    band = lg_ring(rr);
                    ra = lg_atan2(u2, u1);
                }
                if band > 0.0 && tp < tg {
                    // a thin ring: its gas goes round (Kepler: faster inside), in clumps
                    int sub = (int)(rr * 40.0);
                    double sr = ((double)sub + 0.5) / 40.0;
                    double omega = om0 / (sr * __fsqrt(sr));
                    double clump = 0.5 + 0.5 * lg_sin(4.0 * (ra - omega * t) + 5.0 * (double)sub);
                    double v = band * (0.50 + 0.50 * clump);
                    // the shadow of the globe on the ring
                    int shadow = 0;
                    double sb = qx * lx + qy * ly + qz * lz;
                    double sc = qx * qx + qy * qy + qz * qz - 1.0;
                    if sb < 0.0 && sb * sb - sc > 0.0 { shadow = 1; }
                    if shadow == 1 { v = v * 0.15; }
                    // the sun glints on the ring here and there (whitish grey)
                    double gl = (0.0 - sb) / __fsqrt(qx * qx + qy * qy + qz * qz);
                    double gg = 0.0;
                    if shadow == 0 && gl > 0.0 {
                        double g2 = gl * gl * gl * gl * gl * gl;
                        gg = g2 * g2 * (0.3 + 0.7 * clump * clump);
                    }
                    double val = v + gg * 0.5;
                    lg_ch[y * LW + x] = lg_pick(val);
                    lg_col[y * LW + x] = lg_grey(0.25 + 0.75 * val);
                    lg_dep[y * LW + x] = tp;
                } else if tg < 999.0 {
                    double hx = ox + lg_fx * tg;
                    double hy = oy + lg_fy * tg;
                    double hz = oz + lg_fz * tg;
                    // the globe is rocked: its own coordinates
                    double gx = hx * cl + hz * sl;
                    double gz = 0.0 - hx * sl + hz * cl;
                    double gy = hy + libp * gz;
                    // the letter J on the front of the globe: seen from the viewer, raised from the surface
                    double sxv = gx * lg_rx + gy * lg_ry + gz * lg_rz;               // to the right
                    double syv = gx * lg_ux + gy * lg_uy + gz * lg_uz;               // up
                    double facing = 0.0 - (hx * lg_fx + hy * lg_fy + hz * lg_fz);     // 1 in the middle, 0 at the edge
                    double jx = sxv * 0.95;
                    double jy = (0.0 - syv) * 0.95 + 0.06;
                    double cov = 0.0;
                    double dcx = 0.0;
                    double dcy = 0.0;
                    if facing > 0.15 {
                        cov = lg_j(jx, jy);
                        double e = 0.03;
                        dcx = (lg_j(jx + e, jy) - lg_j(jx - e, jy)) / (2.0 * e);
                        dcy = (lg_j(jx, jy + e) - lg_j(jx, jy - e)) / (2.0 * e);
                    }
                    // the normal: the ball's, bent at the edges of the letter so that it stands out
                    double nx = hx;
                    double ny = hy;
                    double nz = hz;
                    double bump = 0.30;
                    nx = nx - bump * dcx * lg_rx * 0.95 + bump * dcy * lg_ux * 0.95;
                    ny = ny - bump * dcx * lg_ry * 0.95 + bump * dcy * lg_uy * 0.95;
                    nz = nz - bump * dcx * lg_rz * 0.95 + bump * dcy * lg_uz * 0.95;
                    double nl = __fsqrt(nx * nx + ny * ny + nz * nz);
                    nx = nx / nl;
                    ny = ny / nl;
                    nz = nz / nl;
                    double lam = nx * lx + ny * ly + nz * lz;
                    if lam < 0.0 { lam = 0.0; }
                    // the shadow of the ring on the globe
                    double dl = lx * nsx + ly * nsy;
                    if lg_abs(dl) > 0.0001 {
                        double ts2 = 0.0 - (hx * nsx + hy * nsy) / dl;
                        if ts2 > 0.0 {
                            double kx = hx + lx * ts2;
                            double ky = hy + ly * ts2;
                            double kz = hz + lz * ts2;
                            double w1 = kx * e1x + ky * e1y;
                            double rad2 = __fsqrt(w1 * w1 + kz * kz);
                            if lg_ring(rad2) > 0.0 { lam = lam * 0.30; }
                        }
                    }
                    // the paint: the sea is mid grey with fine lines of latitude and longitude, the letter is white
                    double albedo = 0.34;
                    double lat = lg_abs(lg_sin(gy * 9.4248));
                    double lon = lg_abs(lg_sin((lg_atan2(gz, gx) + 3.1416) * 6.0));
                    if lat < 0.07 || lon < 0.06 { albedo = 0.26; }
                    albedo = albedo + (1.0 - albedo) * cov;
                    // the glow at the rim, a small bright spot of reflected light on the sea
                    double rim = 1.0 - lg_abs(facing);
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
                    double bright = 0.05 + 0.92 * lam * albedo + 0.22 * rim * (0.2 + lam) + 0.35 * refl;
                    if bright > 1.0 { bright = 1.0; }
                    lg_ch[y * LW + x] = lg_pick(bright);
                    lg_col[y * LW + x] = lg_grey(bright);
                    lg_dep[y * LW + x] = tg;
                }
                x += 1;
            }
            y += 1;
        }
        lg_show();
        if frames == 0 && lg_key() { frame = 0 - 1; break; }
        frame += 1;
        int due = t0 + frame * 41666666;
        int now = lg_now();
        if due > now { lg_sleep_ns(due - now); }
    }
}
