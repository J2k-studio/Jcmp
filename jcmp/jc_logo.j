// jc_logo.j -- the mascot: jcmp -space shows the J2K logo in ASCII style: a J drawn with shaded characters, a ring that
// leans 45 degrees and turns round it, twinkling stars, 24 frames a second. Small and of a fixed size (48 x 18 characters), in the middle of the terminal,
// all in J2K with no library. Stops on Ctrl-C or Enter.

#define LW 48
#define LH 18
#define LN 864
char lg_ch[LN];            // 48 x 18 characters of the picture
double lg_jm[LN];          // the letter J: how much of each cell it covers (0..1), made once
double lg_jb[LN];          // the same, blurred: the soft halo
double lg_jt[LN];
char lg_buf[8192];           // the text of one frame
int lg_len;
double lg_sx[60];            // the stars: place, speed and phase of the twinkling
double lg_sy[60];
double lg_sf[60];
double lg_sp[60];
char lg_ramp[16];            // " .:-=+*#%@": from nothing to the brightest

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
    double bx = lg_clamp(x, 0.0 - 0.20, 0.50);                                  // the top bar
    d = lg_min(d, __fsqrt((x - bx) * (x - bx) + (y + 0.82) * (y + 0.82)));
    double sy = lg_clamp(y, 0.0 - 0.82, 0.28);                                  // the stem
    d = lg_min(d, __fsqrt((x - 0.20) * (x - 0.20) + (y - sy) * (y - sy)));
    double cx = x + 0.15;                                                       // the hook: half a circle
    double cy = y - 0.28;
    if cy >= 0.0 {
        d = lg_min(d, lg_abs(__fsqrt(cx * cx + cy * cy) - 0.35));
    } else if cx < 0.0 {
        d = lg_min(d, __fsqrt((x + 0.50) * (x + 0.50) + (y - 0.28) * (y - 0.28)));
    }
    return lg_clamp(1.0 - (d - 0.11) / 0.05, 0.0, 1.0);
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

// the character for a brightness 0..1
char lg_pick(double v) {
    if v < 0.0 { v = 0.0; }
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
    int top = (lg_rows - LH - 1) / 2 + 1;
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
        while x < LW {
            lg_buf[lg_len] = lg_ch[y * LW + x];
            lg_len += 1;
            x += 1;
        }
        y += 1;
    }
    lg_buf[lg_len] = 27;
    lg_len += 1;
    lg_text("[");
    lg_num(top + LH);
    lg_text(";");
    lg_num(left + LW / 2 - 12);
    lg_text("H J2K - Ctrl-C or Enter to stop");
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

// the logo: frames = 0 runs until Ctrl-C or Enter
void lg_run(int frames) {
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
    double pi = 3.141592653589793;
    double cxs = (double)LW / 2.0;
    double cys = (double)LH / 2.0;
    double unit = (double)LH * 0.40;                    // rows for one unit of the picture; a character is twice as high as wide
    // the letter J once: each cell is looked at in 3 x 3 places
    int y = 0;
    while y < LH {
        int x = 0;
        while x < LW {
            double sum = 0.0;
            int sj = 0;
            while sj < 3 {
                int si = 0;
                while si < 3 {
                    double fx = ((double)x + ((double)si + 0.5) / 3.0 - cxs) / (unit * 2.0);
                    double fy = ((double)y + ((double)sj + 0.5) / 3.0 - cys) / unit;
                    sum = sum + lg_j(fx, fy);
                    si += 1;
                }
                sj += 1;
            }
            lg_jm[y * LW + x] = sum / 9.0;
            x += 1;
        }
        y += 1;
    }
    // the halo: a blur of J (3 cells across, 1 up and down, twice)
    i = 0;
    while i < LN {
        lg_jb[i] = lg_jm[i];
        i += 1;
    }
    int rounds = 0;
    while rounds < 3 {
        y = 0;
        while y < LH {
            int x = 0;
            while x < LW {
                double sum = 0.0;
                int cnt = 0;
                int dy = 0 - 1;
                while dy < 2 {
                    int dx = 0 - 2;
                    while dx < 3 {
                        int xx = x + dx;
                        int yy = y + dy;
                        if xx >= 0 && xx < LW && yy >= 0 && yy < LH {
                            sum = sum + lg_jb[yy * LW + xx];
                            cnt += 1;
                        }
                        dx += 1;
                    }
                    dy += 1;
                }
                lg_jt[y * LW + x] = sum / (double)cnt;
                x += 1;
            }
            y += 1;
        }
        i = 0;
        while i < LN {
            lg_jb[i] = lg_jt[i];
            i += 1;
        }
        rounds += 1;
    }
    lg_read_size();                                       // first the size of the terminal, then the picture in its middle
    char clear[8];
    clear[0] = 27;
    clear[1] = '[';
    clear[2] = '2';
    clear[3] = 'J';
    clear[4] = 0;
    write_out(@clear);
    double c45 = 0.7071067811865476;
    double cz = lg_cos(0.0 - 22.0 * pi / 180.0);
    double sz = lg_sin(0.0 - 22.0 * pi / 180.0);
    int frame = 0;
    int t0 = lg_now();
    while frames == 0 || frame < frames {
        double t = (double)frame / 24.0;
        double pulse = 0.85 + 0.15 * lg_sin(t * 2.0);
        // the halo and the stars
        i = 0;
        while i < LN {
            double h = lg_jb[i] * 1.5 * pulse;
            if h > 0.16 {
                lg_ch[i] = lg_pick(h * 0.7);
            } else {
                lg_ch[i] = ' ';
            }
            i += 1;
        }
        i = 0;
        while i < 60 {
            int sx = (int)lg_sx[i];
            int sy = (int)lg_sy[i];
            if lg_ch[sy * LW + sx] == ' ' {
                double tw = 0.5 + 0.5 * lg_sin(t * lg_sf[i] + lg_sp[i]);
                char c = ' ';
                if tw > 0.35 { c = '.'; }
                if tw > 0.65 { c = '+'; }
                if tw > 0.9 { c = '*'; }
                lg_ch[sy * LW + sx] = c;
            }
            i += 1;
        }
        double cy_ = lg_cos(t * 0.6);                        // the ring turns slowly round the letter
        double sy_ = lg_sin(t * 0.6);
        int pass = 0;
        while pass < 2 {
            if pass == 1 {
                // the letter, in front of the back of the ring
                i = 0;
                while i < LN {
                    double m = lg_jm[i];
                    if m > 0.18 {
                        lg_ch[i] = lg_pick(0.55 + 0.45 * m * pulse);
                    }
                    i += 1;
                }
            }
            i = 0;
            while i < 720 {
                double a = (double)i * 2.0 * pi / 720.0;
                double px = 0.95 * lg_cos(a);
                double pz = 0.95 * lg_sin(a);
                double ly = 0.0 - pz * c45;                       // lean 45 degrees towards us
                double lz = pz * c45;
                double sx2 = px * cz - ly * sz;                   // a little sideways
                double sy2 = px * sz + ly * cz;
                double qx = sx2 * cy_ + lz * sy_;                 // turn round the up axis
                double qz = 0.0 - sx2 * sy_ + lz * cy_;
                double qy = sy2;
                int behind = 0;
                if qz > 0.0 { behind = 1; }
                if (pass == 0 && behind == 1) || (pass == 1 && behind == 0) {
                    double persp = 1.0 / (1.0 + 0.25 * qz);
                    int dx = (int)(cxs + qx * persp * unit * 2.0 * 1.35);
                    int dy = (int)(cys + qy * persp * unit * 1.35);
                    double depth = 0.5 - 0.5 * qz;
                    double bead = 0.0;
                    double da = lg_sin((a - t * 2.2) * 0.5);
                    if da * da > 0.985 { bead = 0.3; }
                    lg_dot(dx, dy, 0.30 + 0.55 * depth + bead);
                }
                i += 1;
            }
            pass += 1;
        }
        lg_show();
        if frames == 0 && lg_key() { frame = 0 - 1; break; }
        frame += 1;
        int due = t0 + frame * 41666666;
        int now = lg_now();
        if due > now { lg_sleep_ns(due - now); }
    }
}
