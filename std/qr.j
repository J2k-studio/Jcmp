// qr 0.1.0 -- reads QR codes from a picture (a photo from the camera, a screenshot): the dots in, the text out.   #import <qr>   (license: MPL-2.0)
//   bool ok; String text = Qr::scan(im.px, im.w, im.h, @ok);        // im.px: 4 bytes for each dot, red green blue alpha (the Image of <png>)
//   ok = false: no code was found or it could not be read (Qr::error() says which)
// Versions 1 to 40, the four levels of error correction (Reed-Solomon, mistakes are repaired), the modes numeric, alphanumeric and bytes (UTF-8 text),
// any turning, a tilt that a flat sheet gives (a straight-on view with a little tilt), the light of a photo (a local threshold).
// Not yet: mirrored codes, white on black, Kanji mode, the strong perspective of a code seen from the side.

String qr_err;
int qr_rs_cache_done = 0;
String[] qr_rs_rows;
String[] qr_al_rows;
int qr_exp[512];
int qr_log[256];
int qr_gf_done = 0;
int qr_m[31329];                       // the modules (1 = dark) of the code that is read, row by row
int qr_f[31329];                       // 1 where a dot belongs to a pattern of the code and not to the data
int qr_cx[200]; int qr_cy[200]; int qr_cm[200]; int qr_cn[200];     // the candidates of the finder patterns: centre, module size (x 1000), votes
int qr_ncand = 0;

String qr_rs_table() {
    String s = "";
    s += "1:26:19;1:26:16;1:26:13;1:26:9;1:44:34;1:44:28;1:44:22;1:44:16;1:70:55;1:70:44;2:35:17;2:35:13;1:100:80;2:50:32;";
    s += "2:50:24;4:25:9;1:134:108;2:67:43;2:33:15,2:34:16;2:33:11,2:34:12;2:86:68;4:43:27;4:43:19;4:43:15;2:98:78;4:49:31;";
    s += "2:32:14,4:33:15;4:39:13,1:40:14;2:121:97;2:60:38,2:61:39;4:40:18,2:41:19;4:40:14,2:41:15;2:146:116;3:58:36,2:59:37;";
    s += "4:36:16,4:37:17;4:36:12,4:37:13;2:86:68,2:87:69;4:69:43,1:70:44;6:43:19,2:44:20;6:43:15,2:44:16;4:101:81;1:80:50,4:81:51;";
    s += "4:50:22,4:51:23;3:36:12,8:37:13;2:116:92,2:117:93;6:58:36,2:59:37;4:46:20,6:47:21;7:42:14,4:43:15;4:133:107;8:59:37,1:60:38;";
    s += "8:44:20,4:45:21;12:33:11,4:34:12;3:145:115,1:146:116;4:64:40,5:65:41;11:36:16,5:37:17;11:36:12,5:37:13;5:109:87,1:110:88;";
    s += "5:65:41,5:66:42;5:54:24,7:55:25;11:36:12,7:37:13;5:122:98,1:123:99;7:73:45,3:74:46;15:43:19,2:44:20;3:45:15,13:46:16;";
    s += "1:135:107,5:136:108;10:74:46,1:75:47;1:50:22,15:51:23;2:42:14,17:43:15;5:150:120,1:151:121;9:69:43,4:70:44;17:50:22,1:51:23;";
    s += "2:42:14,19:43:15;3:141:113,4:142:114;3:70:44,11:71:45;17:47:21,4:48:22;9:39:13,16:40:14;3:135:107,5:136:108;3:67:41,13:68:42;";
    s += "15:54:24,5:55:25;15:43:15,10:44:16;4:144:116,4:145:117;17:68:42;17:50:22,6:51:23;19:46:16,6:47:17;2:139:111,7:140:112;";
    s += "17:74:46;7:54:24,16:55:25;34:37:13;4:151:121,5:152:122;4:75:47,14:76:48;11:54:24,14:55:25;16:45:15,14:46:16;6:147:117,4:148:118;";
    s += "6:73:45,14:74:46;11:54:24,16:55:25;30:46:16,2:47:17;8:132:106,4:133:107;8:75:47,13:76:48;7:54:24,22:55:25;22:45:15,13:46:16;";
    s += "10:142:114,2:143:115;19:74:46,4:75:47;28:50:22,6:51:23;33:46:16,4:47:17;8:152:122,4:153:123;22:73:45,3:74:46;8:53:23,26:54:24;";
    s += "12:45:15,28:46:16;3:147:117,10:148:118;3:73:45,23:74:46;4:54:24,31:55:25;11:45:15,31:46:16;7:146:116,7:147:117;";
    s += "21:73:45,7:74:46;1:53:23,37:54:24;19:45:15,26:46:16;5:145:115,10:146:116;19:75:47,10:76:48;15:54:24,25:55:25;23:45:15,25:46:16;";
    s += "13:145:115,3:146:116;2:74:46,29:75:47;42:54:24,1:55:25;23:45:15,28:46:16;17:145:115;10:74:46,23:75:47;10:54:24,35:55:25;";
    s += "19:45:15,35:46:16;17:145:115,1:146:116;14:74:46,21:75:47;29:54:24,19:55:25;11:45:15,46:46:16;13:145:115,6:146:116;";
    s += "14:74:46,23:75:47;44:54:24,7:55:25;59:46:16,1:47:17;12:151:121,7:152:122;12:75:47,26:76:48;39:54:24,14:55:25;22:45:15,41:46:16;";
    s += "6:151:121,14:152:122;6:75:47,34:76:48;46:54:24,10:55:25;2:45:15,64:46:16;17:152:122,4:153:123;29:74:46,14:75:47;";
    s += "49:54:24,10:55:25;24:45:15,46:46:16;4:152:122,18:153:123;13:74:46,32:75:47;48:54:24,14:55:25;42:45:15,32:46:16;";
    s += "20:147:117,4:148:118;40:75:47,7:76:48;43:54:24,22:55:25;10:45:15,67:46:16;19:148:118,6:149:119;18:75:47,31:76:48;";
    s += "34:54:24,34:55:25;20:45:15,61:46:16";
    return s;
}

String qr_al_table() {
    String s = "";
    s += ";6,18;6,22;6,26;6,30;6,34;6,22,38;6,24,42;6,26,46;6,28,50;6,30,54;6,32,58;6,34,62;6,26,46,66;6,26,48,70;6,26,50,74;";
    s += "6,30,54,78;6,30,56,82;6,30,58,86;6,34,62,90;6,28,50,72,94;6,26,50,74,98;6,30,54,78,102;6,28,54,80,106;6,32,58,84,110;";
    s += "6,30,58,86,114;6,34,62,90,118;6,26,50,74,98,122;6,30,54,78,102,126;6,26,52,78,104,130;6,30,56,82,108,134;6,34,60,86,112,138;";
    s += "6,30,58,86,114,142;6,34,62,90,118,146;6,30,54,78,102,126,150;6,24,50,76,102,128,154;6,28,54,80,106,132,158;6,32,58,84,110,136,162;";
    s += "6,26,54,82,110,138,166;6,30,58,86,114,142,170";
    return s;
}

void qr_setup() {
    if qr_gf_done == 1 { return; }
    qr_gf_done = 1;
    int x = 1;
    for i in 0..255 {
        qr_exp[i] = x;
        qr_log[x] = i;
        x = x << 1;
        if x >= 256 { x = x xor 285; }
    }
    for i in 255..512 { qr_exp[i] = qr_exp[i - 255]; }
    qr_rs_rows = qr_rs_table().split(";");
    qr_al_rows = qr_al_table().split(";");
}

int qr_mul(int a, int b) {
    if a == 0 || b == 0 { return 0; }
    return qr_exp[qr_log[a] + qr_log[b]];
}

int qr_div(int a, int b) {
    if a == 0 { return 0; }
    return qr_exp[qr_log[a] + 255 - qr_log[b]];
}

// repairs the n bytes of one block (data and then the ecn bytes of correction); false when it is too damaged
bool qr_rs_fix(int^ d, int n, int ecn) {
    int syn[256];
    bool clean = true;
    for i in 0..ecn {
        int r = 0;
        int xa = qr_exp[i];
        for j in 0..n { r = qr_mul(r, xa) xor d[j]; }
        syn[i] = r;
        if r != 0 { clean = false; }
    }
    if clean { return true; }
    // Berlekamp-Massey: the locator polynomial c (c[0] = 1)
    int c[256]; int bp[256]; int tp[256];
    for i in 0..256 { c[i] = 0; bp[i] = 0; }
    c[0] = 1; bp[0] = 1;
    int el = 0; int m = 1; int bb = 1;
    for nn in 0..ecn {
        int dd = syn[nn];
        for i in 1..(el + 1) { dd = dd xor qr_mul(c[i], syn[nn - i]); }
        if dd == 0 { m += 1; continue; }
        int coef = qr_div(dd, bb);
        if 2 * el <= nn {
            for i in 0..256 { tp[i] = c[i]; }
            for i in 0..(256 - m) { c[i + m] = c[i + m] xor qr_mul(coef, bp[i]); }
            el = nn + 1 - el;
            for i in 0..256 { bp[i] = tp[i]; }
            bb = dd;
            m = 1;
        } else {
            for i in 0..(256 - m) { c[i + m] = c[i + m] xor qr_mul(coef, bp[i]); }
            m += 1;
        }
    }
    if el * 2 > ecn { return false; }
    // the places of the errors: j is a place when the locator is zero at the inverse of its power
    int pos[256]; int found = 0;
    for j in 0..n {
        int deg = n - 1 - j;
        int xi = qr_exp[(255 - deg) % 255];
        int v = 0;
        int xp = 1;
        for i in 0..(el + 1) { v = v xor qr_mul(c[i], xp); xp = qr_mul(xp, xi); }
        if v == 0 { pos[found] = j; found += 1; if found > el { return false; } }
    }
    if found != el { return false; }
    // omega = syn * c mod x^ecn
    int om[256];
    for i in 0..ecn {
        int v = 0;
        for k in 0..(i + 1) { if k <= el { v = v xor qr_mul(c[k], syn[i - k]); } }
        om[i] = v;
    }
    for k in 0..found {
        int deg = n - 1 - pos[k];
        int xk = qr_exp[deg % 255];
        int xi = qr_exp[(255 - deg) % 255];
        int ov = 0; int xp = 1;
        for i in 0..ecn { ov = ov xor qr_mul(om[i], xp); xp = qr_mul(xp, xi); }
        int dv = 0; xp = 1;
        for i in 1..(el + 1) {
            if i % 2 == 1 { dv = dv xor qr_mul(c[i], xp); }
            if i % 2 == 0 { xp = xp; }
            if i % 2 == 1 { xp = qr_mul(xp, qr_mul(xi, xi)); }
        }
        if dv == 0 { return false; }
        int mag = qr_mul(xk, qr_div(ov, dv));
        d[pos[k]] = d[pos[k]] xor mag;
    }
    // check
    for i in 0..ecn {
        int r = 0;
        int xa = qr_exp[i];
        for j in 0..n { r = qr_mul(r, xa) xor d[j]; }
        if r != 0 { return false; }
    }
    return true;
}

// ---------- the picture: dark and light, then the three squares in the corners

int qr_abs(int x) { if x < 0 { return 0 - x; } return x; }

// 1 = dark: a dot is dark when it is clearly darker than the mean of the dots round it (a window of about an eighth of the picture)
void qr_binarize(String px, int w, int h, char^ bin) {
    int^ ii = (int^)alloc((w + 1) * (h + 1) * 8);
    for x in 0..(w + 1) { ii[x] = 0; }
    for y in 0..h {
        int row = 0;
        ii[(y + 1) * (w + 1)] = 0;
        for x in 0..w {
            int o = (y * w + x) * 4;
            int g = ((px[o] & 255) * 299 + (px[o + 1] & 255) * 587 + (px[o + 2] & 255) * 114) / 1000;
            row += g;
            ii[(y + 1) * (w + 1) + x + 1] = ii[y * (w + 1) + x + 1] + row;
        }
    }
    int s = w;
    if h > s { s = h; }
    s = s / 8;
    if s < 16 { s = 16; }
    int half = s / 2;
    for y in 0..h {
        int y0 = y - half; if y0 < 0 { y0 = 0; }
        int y1 = y + half + 1; if y1 > h { y1 = h; }
        for x in 0..w {
            int x0 = x - half; if x0 < 0 { x0 = 0; }
            int x1 = x + half + 1; if x1 > w { x1 = w; }
            int sum = ii[y1 * (w + 1) + x1] - ii[y0 * (w + 1) + x1] - ii[y1 * (w + 1) + x0] + ii[y0 * (w + 1) + x0];
            int cnt = (x1 - x0) * (y1 - y0);
            int o = (y * w + x) * 4;
            int g = ((px[o] & 255) * 299 + (px[o + 1] & 255) * 587 + (px[o + 2] & 255) * 114) / 1000;
            if g * cnt * 100 < sum * 92 { bin[y * w + x] = (char)1; } else { bin[y * w + x] = (char)0; }
        }
    }
}

// the five runs 1 : 1 : 3 : 1 : 1 (dark, light, dark, light, dark): the module size x 1000, or 0
int qr_ratio(int a, int b, int c, int d, int e) {
    int total = a + b + c + d + e;
    if total < 7 || a < 1 || b < 1 || c < 1 || d < 1 || e < 1 { return 0; }
    int m = total * 1000 / 7;
    int tol = m / 2;
    if qr_abs(a * 1000 - m) > tol || qr_abs(b * 1000 - m) > tol || qr_abs(d * 1000 - m) > tol || qr_abs(e * 1000 - m) > tol { return 0; }
    if qr_abs(c * 1000 - 3 * m) > 3 * tol { return 0; }
    return m;
}

// along the line through (x, y) in the direction (dx, dy): the runs round a dark dot; the middle of the middle run (x 1000, along the line) and the module size, or -1
int qr_cross(char^ bin, int w, int h, int x, int y, int dx, int dy, int^ mid) {
    if bin[y * w + x] == 0 { return 0 - 1; }
    int runs[5];
    for i in 0..5 { runs[i] = 0; }
    // back from the middle
    int k = 0;
    int px = x; int py = y;
    while px >= 0 && py >= 0 && px < w && py < h && bin[py * w + px] != 0 { k += 1; px -= dx; py -= dy; }
    int back = k - 1;
    runs[2] = k;
    k = 0;
    while px >= 0 && py >= 0 && px < w && py < h && bin[py * w + px] == 0 { k += 1; px -= dx; py -= dy; }
    runs[1] = k;
    k = 0;
    while px >= 0 && py >= 0 && px < w && py < h && bin[py * w + px] != 0 { k += 1; px -= dx; py -= dy; }
    runs[0] = k;
    // forward
    int f = 0;
    px = x + dx; py = y + dy;
    while px >= 0 && py >= 0 && px < w && py < h && bin[py * w + px] != 0 { f += 1; px += dx; py += dy; }
    runs[2] += f;
    k = 0;
    while px >= 0 && py >= 0 && px < w && py < h && bin[py * w + px] == 0 { k += 1; px += dx; py += dy; }
    runs[3] = k;
    k = 0;
    while px >= 0 && py >= 0 && px < w && py < h && bin[py * w + px] != 0 { k += 1; px += dx; py += dy; }
    runs[4] = k;
    int m = qr_ratio(runs[0], runs[1], runs[2], runs[3], runs[4]);
    if m == 0 { return 0 - 1; }
    // the middle of the middle run, along the line (positions x 1000 from the start (x, y), counting the dots)
    int start = 0 - back;                      // the first dot of the middle run, as a step from (x, y)
    int endp = f;                              // the last
    mid[0] = (start + endp) * 500 + 500 * 0;
    return m;
}

void qr_add_cand(int cx, int cy, int m) {
    for i in 0..qr_ncand {
        if qr_abs(qr_cx[i] - cx) < m * 3 / 2 && qr_abs(qr_cy[i] - cy) < m * 3 / 2 && qr_abs(qr_cm[i] - m) < m / 2 + 1 {
            int n = qr_cn[i];
            qr_cx[i] = (qr_cx[i] * n + cx) / (n + 1);
            qr_cy[i] = (qr_cy[i] * n + cy) / (n + 1);
            qr_cm[i] = (qr_cm[i] * n + m) / (n + 1);
            qr_cn[i] = n + 1;
            return;
        }
    }
    if qr_ncand >= 200 { return; }
    qr_cx[qr_ncand] = cx; qr_cy[qr_ncand] = cy; qr_cm[qr_ncand] = m; qr_cn[qr_ncand] = 1;
    qr_ncand += 1;
}

// all the places that look like a finder pattern (x 1000 for the centre)
void qr_find(char^ bin, int w, int h) {
    qr_ncand = 0;
    int runs[2000];
    int starts[2000];
    for y in 0..h {
        int n = 0;
        int x = 0;
        while x < w && n < 1990 {
            int c = bin[y * w + x];
            int s = x;
            while x < w && bin[y * w + x] == c { x += 1; }
            starts[n] = s;
            runs[n] = x - s;
            if c == 0 { starts[n] = 0 - 1 - s; }          // a negative start marks a light run
            n += 1;
        }
        for i in 0..(n - 4) {
            if starts[i] < 0 { continue; }
            int m = qr_ratio(runs[i], runs[i + 1], runs[i + 2], runs[i + 3], runs[i + 4]);
            if m == 0 { continue; }
            int cxr = starts[i] + runs[i] + runs[i + 1] + runs[i + 2] / 2;
            int mid[1];
            int mv = qr_cross(bin, w, h, cxr, y, 0, 1, @mid);
            if mv < 0 { continue; }
            int cyf = y * 1000 + mid[0];
            int cyr = cyf / 1000;
            int mh = qr_cross(bin, w, h, cxr, cyr, 1, 0, @mid);
            if mh < 0 { continue; }
            qr_add_cand(cxr * 1000 + mid[0], cyf, (mv + mh) / 2);
        }
    }
}

// ---------- the grid and the bits

int qr_get(int x, int y, int n) { return qr_m[y * n + x]; }

void qr_mark_function(int n, int ver) {
    for i in 0..(n * n) { qr_f[i] = 0; }
    for y in 0..9 { for x in 0..9 { qr_f[y * n + x] = 1; } }
    for y in 0..9 { for x in (n - 8)..n { qr_f[y * n + x] = 1; } }
    for y in (n - 8)..n { for x in 0..9 { qr_f[y * n + x] = 1; } }
    for i in 0..n { qr_f[6 * n + i] = 1; qr_f[i * n + 6] = 1; }
    if ver >= 2 {
        String[] ap = qr_al_rows[ver - 1].split(",");
        int cnt = ap.len;
        for a in 0..cnt {
            for b in 0..cnt {
                int ay = ap[a].to_int(); int ax = ap[b].to_int();
                if (a == 0 && b == 0) || (a == 0 && b == cnt - 1) || (a == cnt - 1 && b == 0) { continue; }
                for dy in 0..5 { for dx in 0..5 { qr_f[(ay - 2 + dy) * n + ax - 2 + dx] = 1; } }
            }
        }
    }
    if ver >= 7 {
        for i in 0..6 { for j in 0..3 { qr_f[i * n + n - 11 + j] = 1; qr_f[(n - 11 + j) * n + i] = 1; } }
    }
}

int qr_popcount(int v) { int c = 0; while v != 0 { c += v & 1; v = v >> 1; } return c; }

// the 15 bits of the format of the data bits (2 of the level, 3 of the mask)
int qr_format_word(int data5) {
    int v = data5 << 10;
    for i in 0..5 {
        if ((v >> (14 - i)) & 1) != 0 { v = v xor (1335 << (4 - i)); }
    }
    return ((data5 << 10) | v) xor 21522;
}

// the bits 0 or 1 of the format of one of the two copies; -1 when no format is near
int qr_read_format(int n, int copy) {
    int bits = 0;
    if copy == 0 {
        for i in 0..6 { bits = (bits << 1) | qr_get(i, 8, n); }
        bits = (bits << 1) | qr_get(7, 8, n);
        bits = (bits << 1) | qr_get(8, 8, n);
        bits = (bits << 1) | qr_get(8, 7, n);
        for j in 0..6 { bits = (bits << 1) | qr_get(8, 5 - j, n); }
    } else {
        for j in 0..7 { bits = (bits << 1) | qr_get(8, n - 1 - j, n); }
        for i in 0..8 { bits = (bits << 1) | qr_get(n - 8 + i, 8, n); }
    }
    int best = 0 - 1; int bd = 4;
    for d in 0..32 {
        int dist = qr_popcount(bits xor qr_format_word(d));
        if dist < bd { bd = dist; best = d; }
    }
    return best;
}

bool qr_mask_hit(int mask, int row, int col) {
    if mask == 0 { return (row + col) % 2 == 0; }
    if mask == 1 { return row % 2 == 0; }
    if mask == 2 { return col % 3 == 0; }
    if mask == 3 { return (row + col) % 3 == 0; }
    if mask == 4 { return (row / 2 + col / 3) % 2 == 0; }
    if mask == 5 { return (row * col) % 2 + (row * col) % 3 == 0; }
    if mask == 6 { return ((row * col) % 2 + (row * col) % 3) % 2 == 0; }
    return ((row + col) % 2 + (row * col) % 3) % 2 == 0;
}

String qr_alnum() { return "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"; }

// the modules are in qr_m: the text, or ok = false
String qr_decode_grid(int n, bool^ ok) {
    ok[0] = false;
    int ver = (n - 17) / 4;
    int fmt = qr_read_format(n, 0);
    if fmt < 0 { fmt = qr_read_format(n, 1); }
    if fmt < 0 { qr_err = "the format of the code is not readable"; return ""; }
    int ecbits = fmt >> 3;
    int mask = fmt & 7;
    int ec = 0;                          // the index 0 L, 1 M, 2 Q, 3 H of the table
    if ecbits == 1 { ec = 0; } else if ecbits == 0 { ec = 1; } else if ecbits == 3 { ec = 2; } else { ec = 3; }
    qr_mark_function(n, ver);
    // the codewords, in the zigzag of the standard
    int^ cw = (int^)alloc(4000 * 8);
    int ncw = 0;
    int cur = 0; int nb = 0;
    bool up = true;
    int j = n - 1;
    while j > 0 {
        if j == 6 { j -= 1; }
        for count in 0..n {
            int i = count;
            if up { i = n - 1 - count; }
            for col in 0..2 {
                int xx = j - col;
                if qr_f[i * n + xx] == 0 {
                    int bit = qr_m[i * n + xx];
                    if qr_mask_hit(mask, i, xx) { bit = bit xor 1; }
                    cur = (cur << 1) | bit; nb += 1;
                    if nb == 8 { if ncw < 3990 { cw[ncw] = cur; ncw += 1; } cur = 0; nb = 0; }
                }
            }
        }
        up = !up;
        j -= 2;
    }
    // the blocks of this version and level
    String[] groups = qr_rs_rows[(ver - 1) * 4 + ec].split(",");
    int nblocks = 0; int total = 0;
    int bt[200]; int bd[200];
    for g in 0..groups.len {
        String[] f = groups[g].split(":");
        int cnt = f[0].to_int(); int tot = f[1].to_int(); int dat = f[2].to_int();
        for q in 0..cnt { bt[nblocks] = tot; bd[nblocks] = dat; nblocks += 1; total += tot; }
    }
    if total > ncw { qr_err = "too few bits for this version"; return ""; }
    // deinterleave: the data bytes of the blocks one by one, then the bytes of correction
    int^ blocks = (int^)alloc(nblocks * 256 * 8);
    int maxd = 0;
    for b in 0..nblocks { if bd[b] > maxd { maxd = bd[b]; } }
    int at = 0;
    for i in 0..maxd {
        for b in 0..nblocks { if i < bd[b] { blocks[b * 256 + i] = cw[at]; at += 1; } }
    }
    int maxe = 0;
    for b in 0..nblocks { if bt[b] - bd[b] > maxe { maxe = bt[b] - bd[b]; } }
    for i in 0..maxe {
        for b in 0..nblocks { if i < bt[b] - bd[b] { blocks[b * 256 + bd[b] + i] = cw[at]; at += 1; } }
    }
    String data = "";
    for b in 0..nblocks {
        if !qr_rs_fix(@blocks[b * 256], bt[b], bt[b] - bd[b]) { qr_err = "the code is too damaged to repair"; return ""; }
        for i in 0..bd[b] { data.push((char)blocks[b * 256 + i]); }
    }
    // the stream: modes
    int pos = 0;
    int nbits = data.len * 8;
    String out = "";
    while pos + 4 <= nbits {
        int mode = 0;
        for i in 0..4 { mode = (mode << 1) | (((data[(pos + i) / 8] & 255) >> (7 - (pos + i) % 8)) & 1); }
        pos += 4;
        if mode == 0 { break; }
        if mode == 7 {                                       // ECI: the number is skipped
            int first = 0;
            for i in 0..8 { first = (first << 1) | (((data[(pos + i) / 8] & 255) >> (7 - (pos + i) % 8)) & 1); }
            if (first & 128) == 0 { pos += 8; } else if (first & 64) == 0 { pos += 16; } else { pos += 24; }
            continue;
        }
        int cbits = 0;
        if mode == 1 { if ver <= 9 { cbits = 10; } else if ver <= 26 { cbits = 12; } else { cbits = 14; } }
        else if mode == 2 { if ver <= 9 { cbits = 9; } else if ver <= 26 { cbits = 11; } else { cbits = 13; } }
        else if mode == 4 { if ver <= 9 { cbits = 8; } else { cbits = 16; } }
        else if mode == 8 { if ver <= 9 { cbits = 8; } else if ver <= 26 { cbits = 10; } else { cbits = 12; } }
        else { qr_err = "a kind of data that is not read (mode " + str(mode) + ")"; return out; }
        if pos + cbits > nbits { break; }
        int cnt = 0;
        for i in 0..cbits { cnt = (cnt << 1) | (((data[(pos + i) / 8] & 255) >> (7 - (pos + i) % 8)) & 1); }
        pos += cbits;
        if mode == 4 {
            for k in 0..cnt {
                if pos + 8 > nbits { break; }
                int v = 0;
                for i in 0..8 { v = (v << 1) | (((data[(pos + i) / 8] & 255) >> (7 - (pos + i) % 8)) & 1); }
                out.push((char)v);
                pos += 8;
            }
        } else if mode == 2 {
            String at2 = qr_alnum();
            int left = cnt;
            while left >= 2 && pos + 11 <= nbits {
                int v = 0;
                for i in 0..11 { v = (v << 1) | (((data[(pos + i) / 8] & 255) >> (7 - (pos + i) % 8)) & 1); }
                out.push(at2[v / 45]); out.push(at2[v % 45]);
                pos += 11; left -= 2;
            }
            if left == 1 && pos + 6 <= nbits {
                int v = 0;
                for i in 0..6 { v = (v << 1) | (((data[(pos + i) / 8] & 255) >> (7 - (pos + i) % 8)) & 1); }
                out.push(at2[v]);
                pos += 6;
            }
        } else if mode == 1 {
            int left = cnt;
            while left > 0 {
                int take = 3; int nb2 = 10;
                if left == 2 { take = 2; nb2 = 7; } else if left == 1 { take = 1; nb2 = 4; }
                if pos + nb2 > nbits { break; }
                int v = 0;
                for i in 0..nb2 { v = (v << 1) | (((data[(pos + i) / 8] & 255) >> (7 - (pos + i) % 8)) & 1); }
                String ds = str(v);
                while ds.len < take { ds = "0" + ds; }
                out.append(ds);
                pos += nb2; left -= take;
            }
        } else {
            pos += cnt * 13;                                  // Kanji: skipped
        }
    }
    ok[0] = true;
    return out;
}

// the grid of n x n modules from the three centres (x 1000) by an affine map, read from the dark / light dots
bool qr_sample(char^ bin, int w, int h, int n, int ax, int ay, int bx, int by, int cx, int cy) {
    // a = top left, b = top right, c = bottom left; the centre of a finder is at module (3.5, 3.5) from the corner
    double span = (double)(n - 7);
    double ux = (double)(bx - ax) / 1000.0 / span;
    double uy = (double)(by - ay) / 1000.0 / span;
    double vx = (double)(cx - ax) / 1000.0 / span;
    double vy = (double)(cy - ay) / 1000.0 / span;
    double x0 = (double)ax / 1000.0;
    double y0 = (double)ay / 1000.0;
    for r in 0..n {
        for c in 0..n {
            int dark = 0;
            int seen = 0;
            for k in 0..5 {
                double ox = 0.0; double oy = 0.0;
                if k == 1 { ox = 0.25; } else if k == 2 { ox = 0.0 - 0.25; } else if k == 3 { oy = 0.25; } else if k == 4 { oy = 0.0 - 0.25; }
                double mx = (double)c + 0.5 - 3.5 + ox;
                double my = (double)r + 0.5 - 3.5 + oy;
                int px = (int)(x0 + mx * ux + my * vx + 0.5);
                int py = (int)(y0 + mx * uy + my * vy + 0.5);
                if px < 0 || py < 0 || px >= w || py >= h { return false; }
                seen += 1;
                if bin[py * w + px] != 0 { dark += 1; }
            }
            if dark * 2 > seen { qr_m[r * n + c] = 1; } else { qr_m[r * n + c] = 0; }
        }
    }
    return true;
}

// the alignment pattern near the place (px, py) (x 1000) given by the first map: the centre (x 1000) where the 5 x 5 pattern fits best, or -1
int qr_align(char^ bin, int w, int h, int px, int py, double ux, double uy, double vx, double vy, int^ outx, int^ outy) {
    double ms = Math::sqrt(ux * ux + uy * uy);
    int best = 0 - 1; int bx = 0; int by = 0;
    double step = ms / 3.0;
    if step < 1.0 { step = 1.0; }
    int cnt = (int)(7.0 * ms / step);
    for iy in 0..(cnt + 1) {
        for ix in 0..(cnt + 1) {
            double cx = (double)px / 1000.0 + ((double)ix * step - 3.5 * ms);
            double cy = (double)py / 1000.0 + ((double)iy * step - 3.5 * ms);
            int score = 0;
            for dy in 0..5 {
                for dx in 0..5 {
                    double mx = (double)(dx - 2);
                    double my = (double)(dy - 2);
                    int sx = (int)(cx + mx * ux + my * vx + 0.5);
                    int sy = (int)(cy + mx * uy + my * vy + 0.5);
                    if sx < 0 || sy < 0 || sx >= w || sy >= h { score = 0 - 100; break; }
                    int ax = dx - 2; if ax < 0 { ax = 0 - ax; }
                    int ay = dy - 2; if ay < 0 { ay = 0 - ay; }
                    int ring = ax; if ay > ring { ring = ay; }
                    int want = 1;
                    if ring == 1 { want = 0; }
                    if (bin[sy * w + sx] != 0) == (want == 1) { score += 1; }
                }
            }
            if score > best { best = score; bx = (int)(cx * 1000.0); by = (int)(cy * 1000.0); }
        }
    }
    if best < 22 { return 0 - 1; }
    outx[0] = bx; outy[0] = by;
    return best;
}

// a projective map from the four points of the code: module coordinates (m[k]) to the picture (p[k]) -> h[8]; false when it is not solvable
bool qr_homography(double^ mx, double^ my, double^ pxs, double^ pys, double^ hh) {
    double a[72];
    for i in 0..72 { a[i] = 0.0; }
    for k in 0..4 {
        int r0 = (2 * k) * 9; int r1 = (2 * k + 1) * 9;
        a[r0 + 0] = mx[k]; a[r0 + 1] = my[k]; a[r0 + 2] = 1.0;
        a[r0 + 6] = 0.0 - mx[k] * pxs[k]; a[r0 + 7] = 0.0 - my[k] * pxs[k]; a[r0 + 8] = pxs[k];
        a[r1 + 3] = mx[k]; a[r1 + 4] = my[k]; a[r1 + 5] = 1.0;
        a[r1 + 6] = 0.0 - mx[k] * pys[k]; a[r1 + 7] = 0.0 - my[k] * pys[k]; a[r1 + 8] = pys[k];
    }
    for c in 0..8 {
        int piv = c;
        for r in (c + 1)..8 {
            double v1 = a[r * 9 + c]; if v1 < 0.0 { v1 = 0.0 - v1; }
            double v2 = a[piv * 9 + c]; if v2 < 0.0 { v2 = 0.0 - v2; }
            if v1 > v2 { piv = r; }
        }
        double pv = a[piv * 9 + c]; if pv < 0.0 { pv = 0.0 - pv; }
        if pv < 0.000000001 { return false; }
        if piv != c { for j in 0..9 { double t = a[c * 9 + j]; a[c * 9 + j] = a[piv * 9 + j]; a[piv * 9 + j] = t; } }
        for r in 0..8 {
            if r == c { continue; }
            double f = a[r * 9 + c] / a[c * 9 + c];
            for j in c..9 { a[r * 9 + j] = a[r * 9 + j] - f * a[c * 9 + j]; }
        }
    }
    for i in 0..8 { hh[i] = a[i * 9 + 8] / a[i * 9 + i]; }
    return true;
}

// the modules sampled through the projective map
bool qr_sample_h(char^ bin, int w, int h, int n, double^ hh) {
    for r in 0..n {
        for c in 0..n {
            int dark = 0;
            for k in 0..5 {
                double ox = 0.0; double oy = 0.0;
                if k == 1 { ox = 0.25; } else if k == 2 { ox = 0.0 - 0.25; } else if k == 3 { oy = 0.25; } else if k == 4 { oy = 0.0 - 0.25; }
                double mx = (double)c + 0.5 + ox;
                double my = (double)r + 0.5 + oy;
                double den = hh[6] * mx + hh[7] * my + 1.0;
                if den < 0.0000001 && den > 0.0 - 0.0000001 { return false; }
                int px = (int)((hh[0] * mx + hh[1] * my + hh[2]) / den + 0.5);
                int py = (int)((hh[3] * mx + hh[4] * my + hh[5]) / den + 0.5);
                if px < 0 || py < 0 || px >= w || py >= h { return false; }
                if bin[py * w + px] != 0 { dark += 1; }
            }
            if dark * 2 > 5 { qr_m[r * n + c] = 1; } else { qr_m[r * n + c] = 0; }
        }
    }
    return true;
}

// the second try: the alignment pattern near the bottom right gives a fourth point, and so the tilt of the code
String qr_try_aligned(char^ bin, int w, int h, int n, int ax, int ay, int bx, int by, int cx, int cy, bool^ ok) {
    ok[0] = false;
    double span = (double)(n - 7);
    double ux = (double)(bx - ax) / 1000.0 / span;
    double uy = (double)(by - ay) / 1000.0 / span;
    double vx = (double)(cx - ax) / 1000.0 / span;
    double vy = (double)(cy - ay) / 1000.0 / span;
    // where the last alignment pattern should be: module (n - 6.5, n - 6.5), the finder centre being at (3.5, 3.5)
    double off = (double)n - 6.5 - 3.5;
    int px = (int)(((double)ax / 1000.0 + off * ux + off * vx) * 1000.0);
    int py = (int)(((double)ay / 1000.0 + off * uy + off * vy) * 1000.0);
    int dx = 0; int dy = 0;
    if qr_align(bin, w, h, px, py, ux, uy, vx, vy, @dx, @dy) < 0 { return ""; }
    double mx[4]; double my[4]; double pxs[4]; double pys[4]; double hh[8];
    mx[0] = 3.5; my[0] = 3.5; pxs[0] = (double)ax / 1000.0; pys[0] = (double)ay / 1000.0;
    mx[1] = (double)n - 3.5; my[1] = 3.5; pxs[1] = (double)bx / 1000.0; pys[1] = (double)by / 1000.0;
    mx[2] = 3.5; my[2] = (double)n - 3.5; pxs[2] = (double)cx / 1000.0; pys[2] = (double)cy / 1000.0;
    mx[3] = (double)n - 6.5; my[3] = (double)n - 6.5; pxs[3] = (double)dx / 1000.0; pys[3] = (double)dy / 1000.0;
    if !qr_homography(@mx, @my, @pxs, @pys, @hh) { return ""; }
    if !qr_sample_h(bin, w, h, n, @hh) { return ""; }
    return qr_decode_grid(n, ok);
}

// the timing patterns (the row and the column 6 alternate dark and light) are a check of the size of the grid
bool qr_timing_ok(int n) {
    int good = 0; int total = 0;
    for i in 8..(n - 8) {
        int want = 1 - (i % 2);
        total += 2;
        if qr_m[6 * n + i] == want { good += 1; }
        if qr_m[i * n + 6] == want { good += 1; }
    }
    return good * 100 >= total * 85;
}

int qr_dist(int x1, int y1, int x2, int y2) {
    double dx = (double)(x1 - x2) / 1000.0;
    double dy = (double)(y1 - y2) / 1000.0;
    return (int)(Math::sqrt(dx * dx + dy * dy) * 1000.0);
}

struct Qr {
    static String error() { return qr_err; }

    static String scan(String px, int w, int h, bool^ ok) {
        ok[0] = false;
        qr_setup();
        qr_err = "no QR code found";
        if w < 21 || h < 21 || px.len < w * h * 4 { return ""; }
        char^ bin = (char^)alloc(w * h + 8);
        qr_binarize(px, w, h, bin);
        qr_find(bin, w, h);
        // the candidates that were seen in more than one row, the strongest first
        int idx[200]; int ni = 0;
        for i in 0..qr_ncand { if qr_cn[i] >= 2 { idx[ni] = i; ni += 1; } }
        for i in 0..ni { for j in (i + 1)..ni { if qr_cn[idx[j]] > qr_cn[idx[i]] { int t = idx[i]; idx[i] = idx[j]; idx[j] = t; } } }
        if ni > 12 { ni = 12; }
        // every triple: a corner with two others at the same distance, a right angle between them
        for i in 0..ni {
            for j in 0..ni {
                for k in (j + 1)..ni {
                    if i == j || i == k { continue; }
                    int a = idx[i]; int b = idx[j]; int c = idx[k];
                    int dab = qr_dist(qr_cx[a], qr_cy[a], qr_cx[b], qr_cy[b]);
                    int dac = qr_dist(qr_cx[a], qr_cy[a], qr_cx[c], qr_cy[c]);
                    int dbc = qr_dist(qr_cx[b], qr_cy[b], qr_cx[c], qr_cy[c]);
                    if dab == 0 || dac == 0 { continue; }
                    if qr_abs(dab - dac) * 100 > (dab + dac) * 12 { continue; }             // the two sides are about the same
                    // the third side is the diagonal: sqrt(2) times
                    int diag = (int)(Math::sqrt(2.0) * (double)(dab + dac) / 2.0);
                    if qr_abs(dbc - diag) * 100 > diag * 15 { continue; }
                    // which of b, c is on the right: (b - a) x (c - a) > 0 in the picture (y is down)
                    double ex = (double)(qr_cx[b] - qr_cx[a]); double ey = (double)(qr_cy[b] - qr_cy[a]);
                    double fx = (double)(qr_cx[c] - qr_cx[a]); double fy = (double)(qr_cy[c] - qr_cy[a]);
                    int tr = b; int bl = c;
                    if ex * fy - ey * fx < 0.0 { tr = c; bl = b; }
                    double msz = (double)(qr_cm[a] + qr_cm[b] + qr_cm[c]) / 3000.0;
                    double dim = (double)(dab + dac) / 2000.0 / msz + 7.0;
                    int ver = (int)((dim - 17.0) / 4.0 + 0.5);
                    if ver < 1 || ver > 40 { continue; }
                    // the size is an estimate (a turned code looks bigger along the axes): the versions near it, the nearest first
                    for tryv in 0..7 {
                        int dv = 0;
                        if tryv == 1 { dv = 1; } else if tryv == 2 { dv = 0 - 1; } else if tryv == 3 { dv = 2; } else if tryv == 4 { dv = 0 - 2; } else if tryv == 5 { dv = 3; } else if tryv == 6 { dv = 0 - 3; }
                        int v2 = ver + dv;
                        if v2 < 1 || v2 > 40 { continue; }
                        int n = 17 + 4 * v2;
                        bool good = false;
                        if qr_sample(bin, w, h, n, qr_cx[a], qr_cy[a], qr_cx[tr], qr_cy[tr], qr_cx[bl], qr_cy[bl]) && qr_timing_ok(n) {
                            String text = qr_decode_grid(n, @good);
                            if good { ok[0] = true; return text; }
                        }
                        if v2 >= 2 {
                            String t3 = qr_try_aligned(bin, w, h, n, qr_cx[a], qr_cy[a], qr_cx[tr], qr_cy[tr], qr_cx[bl], qr_cy[bl], @good);
                            if good { ok[0] = true; return t3; }
                        }
                    }
                }
            }
        }
        return "";
    }
}
