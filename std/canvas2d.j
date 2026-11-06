// canvas2d 0.2.0 -- one interface for drawing 2D, so that a game is written once and runs on every graphics backend.   #import <canvas2d>   (license: MPL-2.0)
//   void draw_scene(Canvas2d^ c) {
//       c^.begin();  c^.clear(Color::rgb(10, 20, 40));
//       c^.rect(10.0, 10.0, 50.0, 30.0, Color::rgb(255, 200, 60));
//       c^.circle(100.0, 60.0, 20.0, Color::rgba(255, 255, 255, 128));
//       c^.line(0.0, 0.0, 100.0, 100.0, 2.0, Color::rgb(255, 0, 0));
//       c^.end();                                           // the frame is drawn here
//   }
// The backends (each one is a struct that says  impl Canvas2d ):  GlCanvas (OpenGL ES 3, <glcanvas>), AppCanvas (the commands of the Jaric app, <gpu>).
// Text: canvas_text(c, x, y, "SCORE 10", 2.0, colour) draws with a 3 x 5 font (capitals, digits, signs) in squares of `scale` dots, on any backend.
// Coordinates are dots of the surface: (0, 0) is the top left, y grows downwards. Colours are 0xAARRGGBB (Color::rgb is opaque).
// has_instancing() / has_shaders() tell what the backend can do, so that a game can choose a cheaper way where it cannot.

itf Canvas2d {
    void begin(self);
    void clear(self, i64 argb);
    void rect(self, double x, double y, double w, double h, i64 argb);
    void tri(self, double x0, double y0, double x1, double y1, double x2, double y2, i64 argb);
    void line(self, double x0, double y0, double x1, double y1, double width, i64 argb);
    void circle(self, double cx, double cy, double r, i64 argb);
    void end(self);
    bool has_instancing(self);
    bool has_shaders(self);
    i64 load(self, String path);                                                                // a PNG file becomes a picture number (-1: not loaded)
    void image(self, i64 pic, double x, double y, double w, double h, i64 tint);                // the picture in a box; tint 0xFFFFFFFF = as it is
}

// text drawn by a font (the library <font> has one): <ui> draws its words through it when you give it one (u.font(...)); y is the top of the line, px the size
itf Text2d {
    double text_width(self, String s, double px);
    double text_height(self, double px);
    double text_draw(self, Canvas2d^ c, double x, double y, String s, double px, i64 color);
}

struct Color {
    static i64 rgb(i64 r, i64 g, i64 b) { return 0xff000000 | ((r & 255) << 16) | ((g & 255) << 8) | (b & 255); }
    static i64 rgba(i64 r, i64 g, i64 b, i64 a) { return ((a & 255) << 24) | ((r & 255) << 16) | ((g & 255) << 8) | (b & 255); }
}

// the 3 x 5 font of the letters from ASCII 32 to 95: five digits (one for each row of three dots) for each letter
String canvas_font() { return "00000222025500057575367365124525253220001222142224052500272000024007000000211244755572622771747717175571174717747577111175757757170202002024124210707042124713027574725755656563444365556746477464434553557557222711152556554444757755655552555265644255636565534216722225555755552557755525555222712476444644211311132500000007"; }

// text in squares of `scale` dots; returns the x after the last letter
double canvas_text(Canvas2d^ c, double x, double y, String s, double scale, i64 argb) {
    String font = canvas_font();
    for i in 0..s.len {
        i64 ch = s[i] & 255;
        if ch >= 97 && ch <= 122 { ch = ch - 32; }
        if ch < 32 || ch > 95 { ch = 63; }
        i64 g = (ch - 32) * 5;
        for ry in 0..5 {
            i64 bits = font[g + ry] - 48;
            for rx in 0..3 {
                if ((bits >> (2 - rx)) & 1) != 0 { c^.rect(x + (double)rx * scale, y + (double)ry * scale, scale, scale, argb); }
            }
        }
        x += 4.0 * scale;
    }
    return x;
}
