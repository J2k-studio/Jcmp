// ui 0.1.0 -- buttons, labels, switches and sliders for the screens of an app (immediate mode: you call the widgets every frame, in the order you want them
// from the top down; a widget draws itself and says what happened).   #import <ui>   (license: MPL-2.0)
//   Ui u;                                                        // one for the app
//   game_init:   u.start();                                      game_touch(a, x, y, id):  u.touch(a, x, y);
//   game_frame:  Canvas2d^ c = glapp_canvas();  c^.begin();  c^.clear(u.th.bg);
//                u.begin(c, (double)glapp_w(), (double)glapp_h());
//                u.title("MY APP");
//                if u.button("START") { play = true; }
//                u.toggle("SOUND", @sound);  u.slider("SPEED", @speed, 0.0, 10.0);
//                u.cols(2);  u.button("A");  u.button("B");  u.end_cols();
//                u.end();  c^.end();
// Text is drawn by canvas_text (capitals, digits, signs); a font library can replace u.text() later. Sizes are dots of the surface; u.th holds the colours and sizes.
#import <canvas2d>

struct UiTheme {
    int bg;
    int panel;
    int accent;
    int hot;
    int text;
    int dim;
    double pad;                // the space at the edges
    double gap;                // the space between widgets
    double row_h;              // the height of a button or a switch
    double scale;              // the size of a dot of the letters
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
    int ncols;                 // 0: not in a row of columns
    int col;
    double row_top;
    double row_max;
    int id;                    // the number of the widget being made in this frame
    int held;                  // the widget that the finger went down on (0: none)
    bool down;                 // events since the last frame
    bool up;
    bool moving;
    int tx;
    int ty;
    int state;                 // 1: the finger is down now

    void start(self) {
        self.th.bg = Color::rgb(18, 22, 34);
        self.th.panel = Color::rgb(40, 48, 72);
        self.th.accent = Color::rgb(45, 95, 170);
        self.th.hot = Color::rgb(80, 140, 230);
        self.th.text = Color::rgb(240, 244, 255);
        self.th.dim = Color::rgb(140, 150, 175);
        self.th.pad = 24.0;
        self.th.gap = 16.0;
        self.th.row_h = 72.0;
        self.th.scale = 4.0;
        self.held = 0;
        self.state = 0;
        self.down = false;
        self.up = false;
        self.moving = false;
    }
    // call from game_touch: 1 down, 2 move, 3 up
    void touch(self, int action, int x, int y) {
        self.tx = x;
        self.ty = y;
        if action == 1 { self.down = true; self.state = 1; }
        if action == 2 { self.moving = true; }
        if action == 3 { self.up = true; self.state = 0; }
    }
    void begin(self, Canvas2d^ c, double w, double h) {
        self.c = c;
        self.w = w;
        self.h = h;
        self.left = self.th.pad;
        self.full = w - 2.0 * self.th.pad;
        self.x = self.left;
        self.cw = self.full;
        self.y = self.th.pad;
        self.ncols = 0;
        self.id = 0;
    }
    void end(self) {
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
    // the width of a text in dots
    double text_w(self, String s) { return (double)s.len * 4.0 * self.th.scale; }
    void text(self, double x, double y, String s, int color) { canvas_text(self.c, x, y, s, self.th.scale, color); }
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
    void cols(self, int n) {
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
    void title(self, String s) {
        self.c^.rect(0.0, 0.0, self.w, self.th.row_h + self.th.pad, self.th.accent);
        self.text(self.th.pad, self.th.pad, s, self.th.text);
        self.y = self.th.row_h + self.th.pad + self.th.gap + self.th.pad;
    }
    void label(self, String s) {
        self.text(self.x, self.y, s, self.th.text);
        self.advance(5.0 * self.th.scale);
    }
    bool button(self, String s) {
        self.id += 1;
        double by = self.y;
        double bh = self.th.row_h;
        bool in_box = self.inside(self.x, by, self.cw, bh);
        if self.down && in_box { self.held = self.id; }
        bool clicked = self.up && self.held == self.id && in_box;
        int colour = self.th.accent;
        if self.held == self.id { colour = self.th.hot; }
        self.c^.rect(self.x, by, self.cw, bh, colour);
        double tw = self.text_w(s);
        self.text(self.x + (self.cw - tw) / 2.0, by + (bh - 5.0 * self.th.scale) / 2.0, s, self.th.text);
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
        self.c^.rect(self.x, by, self.cw, bh, self.th.panel);
        self.text(self.x + 16.0, by + (bh - 5.0 * self.th.scale) / 2.0, s, self.th.text);
        double sw = 96.0;
        double sx = self.x + self.cw - sw - 16.0;
        int track = self.th.dim;
        if v^ { track = self.th.accent; }
        self.c^.rect(sx, by + bh / 2.0 - 16.0, sw, 32.0, track);
        double kx = sx + 4.0;
        if v^ { kx = sx + sw - 28.0 - 4.0; }
        self.c^.rect(kx, by + bh / 2.0 - 12.0, 28.0, 24.0, self.th.text);
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
        double tx0 = self.x + 16.0;
        double tw = self.cw - 32.0;
        bool mine = self.held == self.id;
        if mine && (self.state == 1 || self.up) {
            double f = ((double)self.tx - tx0) / tw;
            if f < 0.0 { f = 0.0; }
            if f > 1.0 { f = 1.0; }
            double nv = lo + f * (hi - lo);
            if nv != v^ { v^ = nv; changed = true; }
        }
        self.c^.rect(self.x, by, self.cw, bh, self.th.panel);
        self.text(self.x + 16.0, by + 8.0, s, self.th.text);
        double f2 = 0.0;
        if hi > lo { f2 = (v^ - lo) / (hi - lo); }
        self.c^.rect(tx0, by + bh - 24.0, tw, 8.0, self.th.dim);
        self.c^.rect(tx0, by + bh - 24.0, tw * f2, 8.0, self.th.accent);
        self.c^.rect(tx0 + tw * f2 - 8.0, by + bh - 32.0, 16.0, 24.0, self.th.text);
        self.advance(bh);
        return changed;
    }
}
