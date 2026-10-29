// glcanvas 0.2.1 -- the Canvas2d interface on OpenGL ES 3 (and on ES 2): every shape of a frame goes into one buffer and is drawn with ONE call.   #import <opengl3> <canvas2d> <glcanvas>   (license: MPL-2.0)
//   0.2.1: image_rot (a picture turned about its middle; a method of GlCanvas, not of the interface).
//   0.2.0: pictures (load a PNG, image()), the same code on an OpenGL ES 2 context (Gl::open(w, h, 2, 0)): no vertex arrays, shaders of GLSL 100.
//   Gl gl = Gl::open(320, 180, 3, 1);                      // off-screen; in an app: Gl::attach(w, h)
//   GlCanvas c; c.init(); c.setup(gl, 320.0, 180.0);       // sets the shader, the buffer and the size of the surface in dots
//   Canvas2d^ cv = @c;   cv^.begin(); cv^.rect(...); cv^.end();       // c.draws counts the draw calls of the last frame (1 for a whole frame)
// The batch holds 8192 triangles; when it is full it is drawn and started again (one more call).

#import <deflate>
#import <png>

struct GlCanvas impl Canvas2d {
    Gl gl;
    int prog;
    int vao;
    int vbo;
    int loc_size;
    Floats buf;
    int n;                          // floats in the batch
    int draws;                      // draw calls made by the last end()
    double w;
    double h;
    bool ready;
    int clear_color;
    bool wants_clear;
    bool es3;                       // false: OpenGL ES 2 (no vertex arrays, GLSL 100)
    int prog_tex;                   // the shader of the pictures
    int vbo_tex;
    int loc_tex_size;
    int loc_tex_tint;
    int loc_tex_sampler;
    int[] pics;                     // picture number -> GL texture
    int a_pos;                      // the places of the attributes (ES 2 gives them out itself)
    int a_col;
    int t_pos;
    int t_uv;

    void init(self) {
        self.n = 0;
        self.draws = 0;
        self.ready = false;
        self.wants_clear = false;
        self.clear_color = 0xff000000;
    }

    void setup(self, Gl gl, double w, double h) {
        self.gl = gl;
        self.w = w;
        self.h = h;
        self.es3 = gl.major >= 3;
        String vs = "";
        String fs = "";
        String vs2 = "";
        String fs2 = "";
        if self.es3 {
            vs = "#version 300 es\nlayout(location = 0) in vec2 pos;\nlayout(location = 1) in vec4 col;\nuniform vec2 size;\nout vec4 v_col;\nvoid main() { v_col = col; gl_Position = vec4(pos.x / size.x * 2.0 - 1.0, 1.0 - pos.y / size.y * 2.0, 0.0, 1.0); }\n";
            fs = "#version 300 es\nprecision mediump float;\nin vec4 v_col;\nout vec4 color;\nvoid main() { color = v_col; }\n";
            vs2 = "#version 300 es\nlayout(location = 0) in vec2 pos;\nlayout(location = 1) in vec2 uv;\nuniform vec2 size;\nout vec2 v_uv;\nvoid main() { v_uv = uv; gl_Position = vec4(pos.x / size.x * 2.0 - 1.0, 1.0 - pos.y / size.y * 2.0, 0.0, 1.0); }\n";
            fs2 = "#version 300 es\nprecision mediump float;\nuniform sampler2D tex;\nuniform vec4 tint;\nin vec2 v_uv;\nout vec4 color;\nvoid main() { color = texture(tex, v_uv) * tint; }\n";
        } else {
            vs = "attribute vec2 pos;\nattribute vec4 col;\nuniform vec2 size;\nvarying vec4 v_col;\nvoid main() { v_col = col; gl_Position = vec4(pos.x / size.x * 2.0 - 1.0, 1.0 - pos.y / size.y * 2.0, 0.0, 1.0); }\n";
            fs = "precision mediump float;\nvarying vec4 v_col;\nvoid main() { gl_FragColor = v_col; }\n";
            vs2 = "attribute vec2 pos;\nattribute vec2 uv;\nuniform vec2 size;\nvarying vec2 v_uv;\nvoid main() { v_uv = uv; gl_Position = vec4(pos.x / size.x * 2.0 - 1.0, 1.0 - pos.y / size.y * 2.0, 0.0, 1.0); }\n";
            fs2 = "precision mediump float;\nuniform sampler2D tex;\nuniform vec4 tint;\nvarying vec2 v_uv;\nvoid main() { gl_FragColor = texture2D(tex, v_uv) * tint; }\n";
        }
        self.prog = gl.program(vs, fs);
        if self.prog == 0 { return; }
        self.prog_tex = gl.program(vs2, fs2);
        if self.prog_tex == 0 { return; }
        self.loc_size = gl.uniform(self.prog, "size");
        self.a_pos = gl.attrib(self.prog, "pos");
        self.a_col = gl.attrib(self.prog, "col");
        self.t_pos = gl.attrib(self.prog_tex, "pos");
        self.t_uv = gl.attrib(self.prog_tex, "uv");
        self.loc_tex_size = gl.uniform(self.prog_tex, "size");
        self.loc_tex_tint = gl.uniform(self.prog_tex, "tint");
        self.loc_tex_sampler = gl.uniform(self.prog_tex, "tex");
        self.buf = Floats::make(6 * 3 * 8192);
        self.pics = arr(8);
        self.pics.push(0);                                         // the picture number 0 is not used
        if self.es3 {
            self.vao = gl.gen_vertex_array();
            gl.bind_vertex_array(self.vao);
        }
        self.vbo = gl.gen_buffer();
        gl.bind_buffer(34962, self.vbo);
        Native::call4(gl.fn("glBufferData"), 34962, self.buf.n * 4, 0, 35048);
        self.vbo_tex = gl.gen_buffer();
        gl.bind_buffer(34962, self.vbo_tex);
        Native::call4(gl.fn("glBufferData"), 34962, 6 * 4 * 4, 0, 35048);
        gl.bind_buffer(34962, self.vbo);
        self.attribs();
        self.ready = true;
    }

    // the two attributes of the shape shader: pos (2 floats) and col (4 floats) in the bound buffer
    void attribs(self) {
        self.gl.vertex_attrib(self.a_pos, 2, 6, 0);
        self.gl.vertex_attrib(self.a_col, 4, 6, 2);
    }

    // one vertex: x, y, r, g, b, a (the colour as numbers from 0 to 1)
    void vertex(self, double x, double y, int argb) {
        if self.n + 6 > self.buf.n { self.flush(); }
        double a = (double)((argb >> 24) & 255) / 255.0;
        double r = (double)((argb >> 16) & 255) / 255.0;
        double g = (double)((argb >> 8) & 255) / 255.0;
        double b = (double)(argb & 255) / 255.0;
        self.buf.set(self.n, (float)x);
        self.buf.set(self.n + 1, (float)y);
        self.buf.set(self.n + 2, (float)r);
        self.buf.set(self.n + 3, (float)g);
        self.buf.set(self.n + 4, (float)b);
        self.buf.set(self.n + 5, (float)a);
        self.n += 6;
    }

    // send the batch to the chip and draw it
    void flush(self) {
        if self.n == 0 || !self.ready { self.n = 0; return; }
        self.gl.use(self.prog);
        self.gl.uniform2f(self.loc_size, self.w, self.h);
        if self.es3 { self.gl.bind_vertex_array(self.vao); }
        self.gl.bind_buffer(34962, self.vbo);
        if !self.es3 { self.attribs(); }
        Native::call4(self.gl.fn("glBufferSubData"), 34962, 0, self.n * 4, self.buf.ptr);
        self.gl.blend_alpha();
        self.gl.draw_arrays(4, 0, self.n / 6);
        self.draws += 1;
        self.n = 0;
    }

    void begin(self) {
        self.n = 0;
        self.draws = 0;
        self.gl.viewport(0, 0, (int)self.w, (int)self.h);
    }
    void clear(self, int argb) {
        self.flush();
        double a = (double)((argb >> 24) & 255) / 255.0;
        double r = (double)((argb >> 16) & 255) / 255.0;
        double g = (double)((argb >> 8) & 255) / 255.0;
        double b = (double)(argb & 255) / 255.0;
        self.gl.clear_color(r, g, b, a);
        self.gl.clear_color_buffer();
    }
    void rect(self, double x, double y, double w, double h, int argb) {
        self.vertex(x, y, argb);
        self.vertex(x + w, y, argb);
        self.vertex(x + w, y + h, argb);
        self.vertex(x, y, argb);
        self.vertex(x + w, y + h, argb);
        self.vertex(x, y + h, argb);
    }
    void tri(self, double x0, double y0, double x1, double y1, double x2, double y2, int argb) {
        self.vertex(x0, y0, argb);
        self.vertex(x1, y1, argb);
        self.vertex(x2, y2, argb);
    }
    // a line of the given width: a thin rectangle along the line
    void line(self, double x0, double y0, double x1, double y1, double width, int argb) {
        double dx = x1 - x0;
        double dy = y1 - y0;
        double len = Math::sqrt(dx * dx + dy * dy);
        if len < 0.000001 { return; }
        double nx = 0.0 - dy / len * width * 0.5;
        double ny = dx / len * width * 0.5;
        self.vertex(x0 + nx, y0 + ny, argb);
        self.vertex(x1 + nx, y1 + ny, argb);
        self.vertex(x1 - nx, y1 - ny, argb);
        self.vertex(x0 + nx, y0 + ny, argb);
        self.vertex(x1 - nx, y1 - ny, argb);
        self.vertex(x0 - nx, y0 - ny, argb);
    }
    // a fan of 32 triangles
    void circle(self, double cx, double cy, double r, int argb) {
        double step = 6.283185307179586 / 32.0;
        for i in 0..32 {
            double a0 = step * (double)i;
            double a1 = step * (double)(i + 1);
            self.vertex(cx, cy, argb);
            self.vertex(cx + r * Math::cos(a0), cy + r * Math::sin(a0), argb);
            self.vertex(cx + r * Math::cos(a1), cy + r * Math::sin(a1), argb);
        }
    }
    void end(self) { self.flush(); }
    bool has_instancing(self) { return self.es3; }
    bool has_shaders(self) { return true; }

    // a PNG file becomes a picture number (-1 when the file cannot be read)
    int load(self, String path) {
        Result<String, Error> r = Fs::read_bytes(path);
        if !r.is_ok() { return 0 - 1; }
        String data = r.take();
        bool good = false;
        Image im = Png::decode(data, @good);
        if !good { return 0 - 1; }
        int tex = self.gl.make_texture(im.w, im.h, im.px, true);
        self.pics.push(tex);
        return self.pics.len - 1;
    }

    // the picture in the box (x, y, w, h); drawn at once (the shapes before it are drawn first, so the order is kept)
    void image(self, int pic, double x, double y, double w, double h, int tint) {
        self.image_rot(pic, x + w * 0.5, y + h * 0.5, w, h, 0.0, tint);
    }

    // the picture in a box of w x h dots whose middle is (cx, cy), turned by `angle` radians (clockwise on the screen, about the middle)
    void image_rot(self, int pic, double cx, double cy, double w, double h, double angle, int tint) {
        if pic <= 0 || pic >= self.pics.len || !self.ready { return; }
        self.flush();
        Floats q = Floats::make(24);
        double ca = Math::cos(angle);
        double sa = Math::sin(angle);
        double hx[6] = {0.0 - 0.5, 0.5, 0.5, 0.0 - 0.5, 0.5, 0.0 - 0.5};
        double hy[6] = {0.0 - 0.5, 0.0 - 0.5, 0.5, 0.0 - 0.5, 0.5, 0.5};
        double us[6] = {0.0, 1.0, 1.0, 0.0, 1.0, 0.0};
        double vs[6] = {0.0, 0.0, 1.0, 0.0, 1.0, 1.0};
        for i in 0..6 {
            double px = hx[i] * w;
            double py = hy[i] * h;
            q.set(i * 4, (float)(cx + px * ca - py * sa));
            q.set(i * 4 + 1, (float)(cy + px * sa + py * ca));
            q.set(i * 4 + 2, (float)us[i]);
            q.set(i * 4 + 3, (float)vs[i]);
        }
        self.gl.use(self.prog_tex);
        self.gl.uniform2f(self.loc_tex_size, self.w, self.h);
        double a = (double)((tint >> 24) & 255) / 255.0;
        double r = (double)((tint >> 16) & 255) / 255.0;
        double g = (double)((tint >> 8) & 255) / 255.0;
        double b = (double)(tint & 255) / 255.0;
        self.gl.uniform4f(self.loc_tex_tint, r, g, b, a);
        self.gl.bind_texture(0, self.pics[pic]);
        self.gl.uniform1i(self.loc_tex_sampler, 0);
        if self.es3 { self.gl.bind_vertex_array(self.vao); }
        self.gl.bind_buffer(34962, self.vbo_tex);
        Native::call4(self.gl.fn("glBufferSubData"), 34962, 0, 24 * 4, q.ptr);
        self.gl.vertex_attrib(self.t_pos, 2, 4, 0);
        self.gl.vertex_attrib(self.t_uv, 2, 4, 2);
        self.gl.blend_alpha();
        self.gl.draw_arrays(4, 0, 6);
        self.draws += 1;
        self.gl.bind_buffer(34962, self.vbo);
        self.attribs();
    }
}
