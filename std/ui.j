// ui 0.2.0 -- the screens of an app: buttons, switches, sliders, progress bars, tabs and lists, with a modern look: rounded corners, soft shadows,
// gradients, glow, a background of slow moving light, a light under the finger and small animations. Immediate mode: you call the widgets every
// frame, in the order you want them from the top down; a widget draws itself and says what happened.   #import <ui>   (license: MPL-2.0)
//   Ui u;                                                        // one for the app
//   game_init:   u.start();                                      game_touch(a, x, y, id):  u.touch(a, x, y);
//   game_frame:  Canvas2d^ c = glapp_canvas();  c^.begin();
//                u.begin(c, (double)glapp_w(), (double)glapp_h());      // paints the background too
//                u.title("MY APP");
//                if u.button("START") { play = true; }
//                u.toggle("SOUND", @sound);  u.slider("SPEED", @speed, 0.0, 10.0);  u.progress("LOADING", 0.4);
//                u.cols(2);  u.button("A");  u.button("B");  u.end_cols();
//                u.end();  c^.end();
// u.fit(400.0) makes the sizes of the UI for a surface 400 dots wide and scales them to the real surface (the touch too).
// Looks: u.theme(0) midnight (default), 1 aurora, 2 sunset, 3 light, 4 neon;  u.th.quality 2 (all effects), 1 (fewer), 0 (flat and fast);
// u.th.bgstyle 0 flat, 1 gradient, 2 gradient with moving light. Words: u.font(@font, 28.0) gives a <font> (any size, lower case, Thai); without
// it the small letters of <canvas2d> are drawn (capitals only).
// Sizes are dots of the surface; u.th holds the colours and sizes. Needs the compiler 1.2.12 or newer.
#import <canvas2d>

double uifx_row;               // the height of a row of a rounded corner (set by Ui.begin: finer when the surface is bigger than the design)

// colour and shape helpers (colours are 0xAARRGGBB)
struct UiFx {
    static double clamp01(double v) {
        if v < 0.0 { return 0.0; }
        if v > 1.0 { return 1.0; }
        return v;
    }
    // the colour between a and b (t = 0 is a, 1 is b), every channel including the alpha
    static i64 mix(i64 a, i64 b, double t) {
        double k = UiFx::clamp01(t);
        i64 aa = (i64)((double)((a >> 24) & 255) * (1.0 - k) + (double)((b >> 24) & 255) * k + 0.5);
        i64 rr = (i64)((double)((a >> 16) & 255) * (1.0 - k) + (double)((b >> 16) & 255) * k + 0.5);
        i64 gg = (i64)((double)((a >> 8) & 255) * (1.0 - k) + (double)((b >> 8) & 255) * k + 0.5);
        i64 bb = (i64)((double)(a & 255) * (1.0 - k) + (double)(b & 255) * k + 0.5);
        return ((aa & 255) << 24) | ((rr & 255) << 16) | ((gg & 255) << 8) | (bb & 255);
    }
    // the same colour with the alpha a (0..1)
    static i64 alpha(i64 col, double a) {
        i64 al = (i64)(UiFx::clamp01(a) * 255.0 + 0.5);
        return (al << 24) | (col & 0xffffff);
    }
    // a rounded rectangle from the top colour to the bottom colour, drawn as rows (a row of the corner is 1 dot high, a flat part `step` dots);
    // hfrac < 1 draws only the upper part of it (for a gloss)
    static void round_rect(Canvas2d^ c, double x, double y, double w, double h, double r, i64 top, i64 bot, double hfrac, double step) {
        if r > w / 2.0 { r = w / 2.0; }
        if r > h / 2.0 { r = h / 2.0; }
        double hh = h * hfrac;
        bool solid = ((top >> 24) & 255) == 255 && ((bot >> 24) & 255) == 255;
        double yy = 0.0;
        while yy < hh {
            double lim = h - r;
            double rh = step;
            double crow = 1.0;
            if uifx_row > 0.0 { crow = uifx_row; }
            if yy < r { lim = r; rh = crow; }
            else if yy >= h - r { lim = h; rh = crow; }
            if yy + rh > lim { rh = lim - yy; }
            if yy + rh > hh { rh = hh - yy; }
            if rh <= 0.0 { break; }
            double mid = yy + rh / 2.0;
            double inset = 0.0;
            if mid < r {
                double dy = r - mid;
                inset = r - Math::sqrt(r * r - dy * dy);
            } else if mid > h - r {
                double dy2 = mid - (h - r);
                inset = r - Math::sqrt(r * r - dy2 * dy2);
            }
            double ext = 0.0;
            if solid && yy + rh < hh { ext = 0.5; }              // a little overlap, so that no seam shows between two rows
            c^.rect(x + inset, y + yy, w - 2.0 * inset, rh + ext, UiFx::mix(top, bot, mid / h));
            yy += rh;
        }
    }
    static void fill(Canvas2d^ c, double x, double y, double w, double h, double r, i64 col) {
        UiFx::round_rect(c, x, y, w, h, r, col, col, 1.0, 4.0);
    }
    // a soft round light: many circles on top of each other, each with a little alpha; the centre gets `strength` (0..1)
    static void glow(Canvas2d^ c, double cx, double cy, double r, i64 col, double strength, i64 layers) {
        double a = strength * 1.3 / (double)layers;
        for i in 0..layers {
            double rr = r * (double)(i + 1) / (double)layers;
            c^.circle(cx, cy, rr, UiFx::alpha(col, a));
        }
    }
    // a soft shadow under a rounded box: bigger and bigger boxes with a little alpha
    static void shadow(Canvas2d^ c, double x, double y, double w, double h, double r, i64 col, double spread, double dy, i64 layers) {
        double a = 0.5 / (double)layers;
        for i in 0..layers {
            double g = spread * (double)(layers - i) / (double)layers;
            UiFx::round_rect(c, x - g, y - g + dy, w + 2.0 * g, h + 2.0 * g, r + g, UiFx::alpha(col, a), UiFx::alpha(col, a), 1.0, 3.0);
        }
    }
}

// draws in the units of a design width (400 dots wide, say) on a surface of any size: everything is multiplied by k on its way to the real canvas
struct UiScale impl Canvas2d {
    Canvas2d^ c;
    double k;
    void init(self) { self.k = 1.0; }
    void begin(self) { }
    void end(self) { }
    void clear(self, i64 argb) { self.c^.clear(argb); }
    void rect(self, double x, double y, double w, double h, i64 argb) { self.c^.rect(x * self.k, y * self.k, w * self.k, h * self.k, argb); }
    void tri(self, double x0, double y0, double x1, double y1, double x2, double y2, i64 argb) {
        self.c^.tri(x0 * self.k, y0 * self.k, x1 * self.k, y1 * self.k, x2 * self.k, y2 * self.k, argb);
    }
    void line(self, double x0, double y0, double x1, double y1, double width, i64 argb) {
        self.c^.line(x0 * self.k, y0 * self.k, x1 * self.k, y1 * self.k, width * self.k, argb);
    }
    void circle(self, double cx, double cy, double r, i64 argb) { self.c^.circle(cx * self.k, cy * self.k, r * self.k, argb); }
    bool has_instancing(self) { return self.c^.has_instancing(); }
    bool has_shaders(self) { return self.c^.has_shaders(); }
    i64 load(self, String path) { return self.c^.load(path); }
    void image(self, i64 pic, double x, double y, double w, double h, i64 tint) { self.c^.image(pic, x * self.k, y * self.k, w * self.k, h * self.k, tint); }
}

struct UiTheme {
    i64 bg;                    // the top of the background
    i64 bg2;                   // the bottom of the background
    i64 panel;                 // the top of a box (a switch, a slider, a list row)
    i64 panel2;                // the bottom of a box
    i64 border;                // the thin line round a box
    i64 accent;                // the main colour (buttons, a switch that is on, a filled bar)
    i64 hot;                   // the lighter colour of the same family (a pressed button, the end of a bar)
    i64 text;
    i64 dim;                   // quiet text and the track of a bar
    i64 glow;                  // the colour of the lights
    i64 shadow;                // the colour of the shadows
    i64 blob1;                 // the three lights of the background
    i64 blob2;
    i64 blob3;
    double pad;                // the space at the edges
    double gap;                // the space between widgets
    double row_h;              // the height of a button or a switch
    double scale;              // the size of a dot of the letters
    double radius;             // the roundness of the corners
    i64 quality;               // 2: all effects, 1: fewer layers, 0: flat
    i64 bgstyle;               // 0 flat, 1 gradient, 2 gradient with moving light
}

struct Ui {
    UiTheme th;
    Canvas2d^ c;
    double w;
    double h;
    double x;                  // the layout cursor: left edge of the cell, top, width of the cell
    double y;
    double cw;
    double left;               // the left edge and the width of the whole column
    double full;
    i64 ncols;                 // 0: not in a row of columns
    i64 col;
    double row_top;
    double row_max;
    i64 id;                    // the number of the widget being made in this frame
    i64 held;                  // the widget that the finger went down on (0: none)
    bool down;                 // events since the last frame
    bool up;
    bool moving;
    i64 tx;
    i64 ty;
    i64 state;                 // 1: the finger is down now
    double t;                  // seconds since start (the animations)
    double dt;                 // seconds since the last frame
    i64 last_ms;
    bool auto_time;            // true: the clock is the real clock; set_time() makes it manual (tests, pictures)
    double hov[64];            // 0..1 per widget: how much it is lit (a finger on it), eased
    double pos[64];            // 0..1 per widget: a switch that moves
    double light;              // 0..1: the light under the finger
    double rip_x;              // a ring that grows where a finger was lifted
    double rip_y;
    double rip_t;              // its age in seconds (< 0: none)
    Text2d^ fnt;               // the font of the words (null: the small built-in letters)
    double fpx;
    double design;             // the width that the sizes are made for (0: no scaling: one unit is one dot of the surface)
    double k;                  // surface dots for one unit
    UiScale sc;
    Canvas2d^ real;            // the canvas of the app

    void start(self) {
        self.theme(0);
        self.th.pad = 24.0;
        self.th.gap = 16.0;
        self.th.row_h = 72.0;
        self.th.scale = 4.0;
        self.th.radius = 18.0;
        self.th.quality = 2;
        self.th.bgstyle = 2;
        self.held = 0;
        self.state = 0;
        self.down = false;
        self.up = false;
        self.moving = false;
        self.t = 0.0;
        self.dt = 0.016;
        self.last_ms = 0;
        self.auto_time = true;
        self.light = 0.0;
        self.rip_t = 0.0 - 1.0;
        self.fnt = null;
        self.fpx = 26.0;
        self.design = 0.0;
        self.sc.init();
        self.k = 1.0;
        for i in 0..64 { self.hov[i] = 0.0; self.pos[i] = 0.0; }
    }

    // the colours: 0 midnight, 1 aurora, 2 sunset, 3 light, 4 neon
    void theme(self, i64 n) {
        if n == 1 {
            self.th.bg = 0xff06121a; self.th.bg2 = 0xff0d2a30; self.th.panel = 0xff16343c; self.th.panel2 = 0xff102a31; self.th.border = 0x3366ffe0;
            self.th.accent = 0xff1fcfa5; self.th.hot = 0xff7dffe3; self.th.text = 0xffeafffa; self.th.dim = 0xff7fa8a8;
            self.th.glow = 0xff2de0b5; self.th.shadow = 0xff000000; self.th.blob1 = 0xff12a58a; self.th.blob2 = 0xff5b3fd6; self.th.blob3 = 0xff1d6fd1;
        } else if n == 2 {
            self.th.bg = 0xff170d1d; self.th.bg2 = 0xff3a1735; self.th.panel = 0xff4a2142; self.th.panel2 = 0xff3a1a37; self.th.border = 0x33ffb08a;
            self.th.accent = 0xffff6b6b; self.th.hot = 0xffffa97a; self.th.text = 0xfffff3ee; self.th.dim = 0xffc79aa8;
            self.th.glow = 0xffff7a6b; self.th.shadow = 0xff000000; self.th.blob1 = 0xffff7a3d; self.th.blob2 = 0xffd4337f; self.th.blob3 = 0xff7a3dd6;
        } else if n == 3 {
            self.th.bg = 0xfff4f6fc; self.th.bg2 = 0xffe2e8f8; self.th.panel = 0xffffffff; self.th.panel2 = 0xfff2f5fc; self.th.border = 0x22202a50;
            self.th.accent = 0xff3d6bff; self.th.hot = 0xff7c9bff; self.th.text = 0xff1b2140; self.th.dim = 0xff6b7392;
            self.th.glow = 0xff3d6bff; self.th.shadow = 0xff2a3566; self.th.blob1 = 0xffb9c8ff; self.th.blob2 = 0xffffc9e6; self.th.blob3 = 0xffbff3e4;
        } else if n == 4 {
            self.th.bg = 0xff05030f; self.th.bg2 = 0xff140a2e; self.th.panel = 0xff1d1240; self.th.panel2 = 0xff150d33; self.th.border = 0x55ff2e9a;
            self.th.accent = 0xffff2e9a; self.th.hot = 0xff00e5ff; self.th.text = 0xfff5eeff; self.th.dim = 0xff9a8ac2;
            self.th.glow = 0xffff2e9a; self.th.shadow = 0xff000000; self.th.blob1 = 0xffff2e9a; self.th.blob2 = 0xff00b8ff; self.th.blob3 = 0xff8a2eff;
        } else {
            self.th.bg = 0xff0a0f1f; self.th.bg2 = 0xff151d3a; self.th.panel = 0xff222c52; self.th.panel2 = 0xff192244; self.th.border = 0x335b8cff;
            self.th.accent = 0xff4f86ff; self.th.hot = 0xff9bbcff; self.th.text = 0xfff2f5ff; self.th.dim = 0xff8a94b8;
            self.th.glow = 0xff5b8cff; self.th.shadow = 0xff000000; self.th.blob1 = 0xff3a5bd9; self.th.blob2 = 0xff1fa3a3; self.th.blob3 = 0xff8a4fd6;
        }
    }

    // the sizes of this UI are made for a surface `design` dots wide (400 is a good number); on a wider surface everything grows (the touch follows)
    void fit(self, double design_w) { self.design = design_w; }

    // the clock by hand (tests, pictures): seconds since the start
    void set_time(self, double seconds) {
        self.auto_time = false;
        self.dt = seconds - self.t;
        if self.dt < 0.0 { self.dt = 0.0; }
        self.t = seconds;
    }

    // call from game_touch: 1 down, 2 move, 3 up
    void touch(self, i64 action, i64 x, i64 y) {
        self.tx = (i64)((double)x / self.k);
        self.ty = (i64)((double)y / self.k);
        if action == 1 { self.down = true; self.state = 1; }
        if action == 2 { self.moving = true; }
        if action == 3 { self.up = true; self.state = 0; }
    }
    // paints the background, advances the clock; call it first in every frame
    void begin(self, Canvas2d^ c, double w, double h) {
        self.real = c;
        self.c = c;
        self.k = 1.0;
        self.w = w;
        self.h = h;
        uifx_row = 0.0;
        if self.design > 0.0 {
            self.k = w / self.design;
            self.sc.c = c;
            self.sc.k = self.k;
            self.c = @self.sc;
            self.w = self.design;
            self.h = h / self.k;
            uifx_row = 1.0 / self.k;
            if uifx_row < 0.3 { uifx_row = 0.3; }
            if uifx_row > 1.0 { uifx_row = 1.0; }
        }
        if self.auto_time {
            i64 now = Time::now_ms();
            if self.last_ms != 0 { self.dt = (double)(now - self.last_ms) / 1000.0; }
            if self.dt > 0.1 { self.dt = 0.1; }
            if self.dt < 0.0 { self.dt = 0.0; }
            self.last_ms = now;
            self.t += self.dt;
        }
        self.left = self.th.pad;
        self.full = self.w - 2.0 * self.th.pad;
        self.x = self.left;
        self.cw = self.full;
        self.y = self.th.pad;
        self.ncols = 0;
        self.id = 0;
        // the light under the finger and the ring after a tap
        double target = 0.0;
        if self.state == 1 { target = 1.0; }
        self.light += (target - self.light) * UiFx::clamp01(self.dt * 14.0);
        if self.rip_t >= 0.0 { self.rip_t += self.dt; if self.rip_t > 0.6 { self.rip_t = 0.0 - 1.0; } }
        if self.up { self.rip_x = (double)self.tx; self.rip_y = (double)self.ty; self.rip_t = 0.0; }
        self.paint_bg();
    }

    void paint_bg(self) {
        Canvas2d^ cv = self.c;
        if self.th.bgstyle == 0 || self.th.quality == 0 {
            cv^.rect(0.0, 0.0, self.w, self.h, self.th.bg);
            return;
        }
        i64 n = 32;
        double sh = self.h / (double)n;
        for i in 0..n {
            cv^.rect(0.0, (double)i * sh, self.w, sh + 1.0, UiFx::mix(self.th.bg, self.th.bg2, ((double)i + 0.5) / (double)n));
        }
        if self.th.bgstyle >= 2 {
            i64 layers = 10;
            if self.th.quality >= 2 { layers = 18; }
            double s = self.w;
            if self.h < s { s = self.h; }
            UiFx::glow(cv, self.w * 0.22 + Math::sin(self.t * 0.31) * self.w * 0.16, self.h * 0.22 + Math::cos(self.t * 0.23) * self.h * 0.07, s * 0.85, self.th.blob1, 0.42, layers);
            UiFx::glow(cv, self.w * 0.82 + Math::cos(self.t * 0.27 + 1.0) * self.w * 0.14, self.h * 0.55 + Math::sin(self.t * 0.19 + 2.0) * self.h * 0.09, s * 0.8, self.th.blob2, 0.34, layers);
            UiFx::glow(cv, self.w * 0.4 + Math::sin(self.t * 0.17 + 4.0) * self.w * 0.2, self.h * 0.95 + Math::cos(self.t * 0.21) * self.h * 0.05, s * 0.9, self.th.blob3, 0.36, layers);
        }
    }

    // draws the lights that go over the widgets (call it last in the frame); the touch is cleared
    void end(self) {
        Canvas2d^ cv = self.c;
        if self.th.quality > 0 {
            if self.light > 0.02 {
                UiFx::glow(cv, (double)self.tx, (double)self.ty, 110.0, self.th.glow, 0.20 * self.light, 6);
            }
            if self.rip_t >= 0.0 {
                double k = self.rip_t / 0.6;
                double rr = 20.0 + 80.0 * k;
                cv^.circle(self.rip_x, self.rip_y, rr, UiFx::alpha(self.th.glow, 0.22 * (1.0 - k)));
                cv^.circle(self.rip_x, self.rip_y, rr - 3.0, UiFx::alpha(self.th.bg, 0.0));
            }
        }
        if self.up { self.held = 0; }
        self.down = false;
        self.up = false;
        self.moving = false;
    }
    bool inside(self, double bx, double by, double bw, double bh) {
        double fx = (double)self.tx;
        double fy = (double)self.ty;
        return fx >= bx && fx < bx + bw && fy >= by && fy < by + bh;
    }
    // a font for the words (a <font> Font, or anything that implements Text2d); px is the size of the letters in dots. Without one the 3 x 5 letters of
    // <canvas2d> are used (capitals only).
    void font(self, Text2d^ f, double px) {
        self.fnt = f;
        self.fpx = px;
    }
    // the width of a text in units
    double text_w(self, String s) {
        if self.fnt != null { return self.fnt^.text_width(s, self.fpx * self.k) / self.k; }
        return (double)s.len * 4.0 * self.th.scale;
    }
    // the height of a line of text in units
    double text_h(self) {
        if self.fnt != null { return self.fnt^.text_height(self.fpx * self.k) / self.k; }
        return 5.0 * self.th.scale;
    }
    void text(self, double x, double y, String s, i64 color) {
        if self.fnt != null { self.fnt^.text_draw(self.real, x * self.k, y * self.k, s, self.fpx * self.k, color); return; }
        canvas_text(self.c, x, y, s, self.th.scale, color);
    }
    // the place of the next widget of height hh: (self.x, self.y, self.cw); advance() moves on
    void advance(self, double hh) {
        if self.ncols > 0 {
            if hh > self.row_max { self.row_max = hh; }
            self.col += 1;
            self.x = self.left + (double)self.col * (self.full + self.th.gap) / (double)self.ncols;
        } else {
            self.y += hh + self.th.gap;
        }
    }
    void cols(self, i64 n) {
        self.ncols = n;
        self.col = 0;
        self.row_top = self.y;
        self.row_max = 0.0;
        self.cw = (self.full - (double)(n - 1) * self.th.gap) / (double)n;
        self.x = self.left;
    }
    void end_cols(self) {
        self.y = self.row_top + self.row_max + self.th.gap;
        self.ncols = 0;
        self.x = self.left;
        self.cw = self.full;
    }
    void spacer(self, double hh) { self.y += hh; }

    // the eased 0..1 value of a widget that is lit while the finger is on it
    double lit(self, i64 wid, bool on) {
        double target = 0.0;
        if on { target = 1.0; }
        i64 i = wid & 63;
        self.hov[i] += (target - self.hov[i]) * UiFx::clamp01(self.dt * 16.0);
        return self.hov[i];
    }

    // a box with a soft shadow, a gradient and a thin line round it
    void box(self, double bx, double by, double bw, double bh, double lift) {
        Canvas2d^ cv = self.c;
        double r = self.th.radius;
        if self.th.quality >= 1 {
            i64 layers = 3;
            if self.th.quality >= 2 { layers = 5; }
            UiFx::shadow(cv, bx, by, bw, bh, r, self.th.shadow, 10.0 + 6.0 * lift, 5.0, layers);
        }
        UiFx::fill(cv, bx - 1.0, by - 1.0, bw + 2.0, bh + 2.0, r + 1.0, self.th.border);
        UiFx::round_rect(cv, bx, by, bw, bh, r, self.th.panel, self.th.panel2, 1.0, 3.0);
    }

    void title(self, String s) {
        Canvas2d^ cv = self.c;
        double bar = self.th.row_h + self.th.pad;
        if self.th.quality >= 1 {
            UiFx::glow(cv, self.w * 0.3, bar * 0.5, self.w * 0.7, self.th.glow, 0.25, 6);
        }
        UiFx::round_rect(cv, 0.0, 0.0 - self.th.radius, self.w, bar + self.th.radius, self.th.radius, UiFx::mix(self.th.accent, self.th.bg, 0.15), UiFx::mix(self.th.accent, self.th.bg, 0.55), 1.0, 4.0);
        cv^.rect(0.0, bar, self.w, 2.0, UiFx::alpha(self.th.hot, 0.55));
        self.text(self.th.pad, self.th.pad, s, 0xffffffff);
        self.y = self.th.row_h + self.th.pad + self.th.gap + self.th.pad;
    }
    void label(self, String s) {
        self.text(self.x, self.y, s, self.th.text);
        self.advance(self.text_h());
    }
    // quiet text
    void caption(self, String s) {
        self.text(self.x, self.y, s, self.th.dim);
        self.advance(self.text_h());
    }
    void separator(self) {
        self.c^.rect(self.x, self.y + 2.0, self.cw, 2.0, UiFx::alpha(self.th.dim, 0.35));
        self.y += 4.0 + self.th.gap;
    }
    bool button(self, String s) {
        self.id += 1;
        double by = self.y;
        double bh = self.th.row_h;
        bool in_box = self.inside(self.x, by, self.cw, bh);
        if self.down && in_box { self.held = self.id; }
        bool clicked = self.up && self.held == self.id && in_box;
        bool pressed = self.held == self.id && self.state == 1;
        double a = self.lit(self.id, pressed);
        Canvas2d^ cv = self.c;
        double r = self.th.radius;
        double off = a * 2.0;
        if self.th.quality >= 1 {
            // a halo that grows with the light on the button
            UiFx::glow(cv, self.x + self.cw / 2.0, by + bh / 2.0 + off, self.cw * 0.5 + 18.0, self.th.glow, 0.18 + 0.22 * a, 5);
            i64 layers = 3;
            if self.th.quality >= 2 { layers = 5; }
            UiFx::shadow(cv, self.x, by + off, self.cw, bh, r, self.th.shadow, 12.0 - 4.0 * a, 7.0, layers);
        }
        i64 top = UiFx::mix(self.th.hot, self.th.accent, 0.35 - 0.3 * a);
        i64 bot = UiFx::mix(self.th.accent, self.th.bg, 0.3);
        UiFx::round_rect(cv, self.x, by + off, self.cw, bh, r, top, bot, 1.0, 3.0);
        UiFx::round_rect(cv, self.x + 2.0, by + off + 2.0, self.cw - 4.0, bh * 0.5, r - 2.0, 0x38ffffff, 0x00ffffff, 1.0, 2.0);     // the gloss
        double tw = self.text_w(s);
        self.text(self.x + (self.cw - tw) / 2.0, by + off + (bh - self.text_h()) / 2.0, s, 0xffffffff);
        self.advance(bh);
        return clicked;
    }
    // a switch: a tap changes *v; returns true when it changed
    bool toggle(self, String s, bool^ v) {
        self.id += 1;
        double by = self.y;
        double bh = self.th.row_h;
        bool in_box = self.inside(self.x, by, self.cw, bh);
        if self.down && in_box { self.held = self.id; }
        bool changed = self.up && self.held == self.id && in_box;
        if changed { v^ = !v^; }
        i64 i = self.id & 63;
        double target = 0.0;
        if v^ { target = 1.0; }
        self.pos[i] += (target - self.pos[i]) * UiFx::clamp01(self.dt * 12.0);
        double k = self.pos[i];
        double a = self.lit(self.id, self.held == self.id && self.state == 1);
        self.box(self.x, by, self.cw, bh, a);
        self.text(self.x + 20.0, by + (bh - self.text_h()) / 2.0, s, self.th.text);
        double sw = 88.0;
        double sh = 44.0;
        double sx = self.x + self.cw - sw - 20.0;
        double sy = by + (bh - sh) / 2.0;
        i64 off = UiFx::mix(self.th.dim, self.th.bg, 0.55);
        UiFx::round_rect(self.c, sx, sy, sw, sh, sh / 2.0, UiFx::mix(off, self.th.hot, k * 0.8), UiFx::mix(off, self.th.accent, k), 1.0, 2.0);
        double kx = sx + sh / 2.0 + k * (sw - sh);
        if self.th.quality >= 1 && k > 0.02 { UiFx::glow(self.c, kx, sy + sh / 2.0, 34.0, self.th.glow, 0.55 * k, 5); }
        self.c^.circle(kx, sy + sh / 2.0 + 1.5, 19.0, UiFx::alpha(0xff000000, 0.25));
        self.c^.circle(kx, sy + sh / 2.0, 18.0, 0xfffcfdff);
        self.advance(bh);
        return changed;
    }
    // a slider from lo to hi: dragging sets *v; returns true when it changed
    bool slider(self, String s, double^ v, double lo, double hi) {
        self.id += 1;
        double by = self.y;
        double bh = self.th.row_h;
        bool in_box = self.inside(self.x, by, self.cw, bh);
        if self.down && in_box { self.held = self.id; }
        bool changed = false;
        double tx0 = self.x + 24.0;
        double tw = self.cw - 48.0;
        bool mine = self.held == self.id;
        if mine && (self.state == 1 || self.up) {
            double f = ((double)self.tx - tx0) / tw;
            if f < 0.0 { f = 0.0; }
            if f > 1.0 { f = 1.0; }
            double nv = lo + f * (hi - lo);
            if nv != v^ { v^ = nv; changed = true; }
        }
        double a = self.lit(self.id, mine && self.state == 1);
        self.box(self.x, by, self.cw, bh, a);
        self.text(self.x + 20.0, by + 10.0, s, self.th.text);
        double f2 = 0.0;
        if hi > lo { f2 = (v^ - lo) / (hi - lo); }
        double ty = by + bh - 26.0;
        UiFx::fill(self.c, tx0, ty, tw, 10.0, 5.0, UiFx::alpha(self.th.dim, 0.35));
        if tw * f2 > 10.0 { UiFx::round_rect(self.c, tx0, ty, tw * f2, 10.0, 5.0, self.th.hot, self.th.accent, 1.0, 2.0); }
        else { UiFx::fill(self.c, tx0, ty, 10.0, 10.0, 5.0, self.th.accent); }
        double kx = tx0 + tw * f2;
        if self.th.quality >= 1 { UiFx::glow(self.c, kx, ty + 5.0, 30.0 + 14.0 * a, self.th.glow, 0.5 + 0.3 * a, 5); }
        self.c^.circle(kx, ty + 6.5, 15.0 + 2.0 * a, UiFx::alpha(0xff000000, 0.25));
        self.c^.circle(kx, ty + 5.0, 14.0 + 2.0 * a, 0xfffcfdff);
        self.advance(bh);
        return changed;
    }
    // a bar that shows f (0..1)
    void progress(self, String s, double f) {
        double bh = self.th.row_h;
        self.box(self.x, self.y, self.cw, bh, 0.0);
        self.text(self.x + 20.0, self.y + 10.0, s, self.th.text);
        double tx0 = self.x + 24.0;
        double tw = self.cw - 48.0;
        double ty = self.y + bh - 26.0;
        double k = UiFx::clamp01(f);
        UiFx::fill(self.c, tx0, ty, tw, 12.0, 6.0, UiFx::alpha(self.th.dim, 0.35));
        if tw * k > 12.0 {
            UiFx::round_rect(self.c, tx0, ty, tw * k, 12.0, 6.0, self.th.hot, self.th.accent, 1.0, 2.0);
            if self.th.quality >= 1 { UiFx::glow(self.c, tx0 + tw * k, ty + 6.0, 20.0, self.th.glow, 0.3, 4); }
        }
        self.advance(bh);
    }
    // a row of tabs (names are joined with | in one text, for example "Home|Search|Me") with a pill that slides to the chosen one, stretching a little
    // while it moves; a tap on a tab sets *sel; true when it changed
    bool tabs(self, String names, i64^ sel) {
        self.id += 1;
        i64 n = 1;
        for i in 0..names.len { if names[i] == '|' { n += 1; } }
        double bh = self.th.row_h - 8.0;
        double tw = self.cw / (double)n;
        bool changed = false;
        i64 slot = self.id & 63;
        // the pill: its place (in tabs, 0 .. n - 1) follows the chosen tab with an ease
        if self.pos[slot] > (double)(n - 1) { self.pos[slot] = (double)(n - 1); }
        double want = (double)sel^;
        double dist = want - self.pos[slot];
        self.pos[slot] += dist * UiFx::clamp01(self.dt * 11.0);
        if Math::abs(want - self.pos[slot]) < 0.002 { self.pos[slot] = want; }
        double moving = Math::abs(want - self.pos[slot]);
        if moving > 1.0 { moving = 1.0; }
        self.box(self.x, self.y, self.cw, bh, 0.0);
        double stretch = 14.0 * moving;
        double pw = tw - 12.0 + stretch;
        double px = self.x + self.pos[slot] * tw + 6.0 - stretch / 2.0;
        if self.th.quality >= 1 { UiFx::glow(self.c, px + pw / 2.0, self.y + bh / 2.0, pw * 0.75, self.th.glow, 0.28, 5); }
        UiFx::round_rect(self.c, px, self.y + 6.0, pw, bh - 12.0, (bh - 12.0) / 2.0, self.th.hot, self.th.accent, 1.0, 3.0);
        UiFx::round_rect(self.c, px + 2.0, self.y + 8.0, pw - 4.0, (bh - 12.0) * 0.5, (bh - 16.0) / 2.0, 0x38ffffff, 0x00ffffff, 1.0, 2.0);
        i64 k = 0;
        i64 start = 0;
        for i in 0..names.len + 1 {
            if i == names.len || names[i] == '|' {
                String one = names.slice(start, i);
                double bx = self.x + (double)k * tw;
                if self.down && self.inside(bx, self.y, tw, bh) { self.held = self.id; }
                if self.up && self.held == self.id && self.inside(bx, self.y, tw, bh) && sel^ != k { sel^ = k; changed = true; }
                // the text turns white as the pill comes
                double near = 1.0 - Math::abs(self.pos[slot] - (double)k);
                if near < 0.0 { near = 0.0; }
                self.text(bx + (tw - self.text_w(one)) / 2.0, self.y + (bh - self.text_h()) / 2.0, one, UiFx::mix(self.th.dim, 0xffffffff, near));
                k += 1;
                start = i + 1;
            }
        }
        self.advance(bh);
        return changed;
    }
    // a row of a list: a title, a quiet line under it, and an arrow; true when it was tapped
    bool item(self, String s, String sub) {
        self.id += 1;
        double by = self.y;
        double bh = self.th.row_h + 16.0;
        bool in_box = self.inside(self.x, by, self.cw, bh);
        if self.down && in_box { self.held = self.id; }
        bool clicked = self.up && self.held == self.id && in_box;
        double a = self.lit(self.id, self.held == self.id && self.state == 1);
        self.box(self.x, by, self.cw, bh, a);
        self.text(self.x + 20.0, by + 14.0, s, self.th.text);
        self.text(self.x + 20.0, by + bh - 14.0 - self.text_h(), sub, self.th.dim);
        double ax = self.x + self.cw - 36.0;
        double ay = by + bh / 2.0;
        self.c^.line(ax, ay - 10.0, ax + 10.0, ay, 4.0, UiFx::alpha(self.th.hot, 0.5 + 0.5 * a));
        self.c^.line(ax + 10.0, ay, ax, ay + 10.0, 4.0, UiFx::alpha(self.th.hot, 0.5 + 0.5 * a));
        self.advance(bh);
        return clicked;
    }
}
