// opengl3 0.3.0 -- OpenGL ES 3.1 (and 2.0) from J2K, on the real driver of the phone: no app is needed.   #import <opengl3>
//   (needs jcmp 1.2.3 for the automatic dynamic build, or jcmp -dyn before; the library native; license: MPL-2.0)
//   0.2.0: textures (make_texture, make_target_texture), framebuffers (render to a texture), vertex arrays, indices (Ints, draw_elements), instancing, additive blending; native 0.1.1 has call9 (glTexImage2D).
//   0.3.0: Gl::attach(w, h) uses the OpenGL ES context that an app made current (the game is a .so loaded by a GLSurfaceView); a program that imports <opengl3> needs no -dyn.
//   Gl gl = Gl::open(256, 256, 3, 1);               // an off-screen context (EGL pbuffer): width, height, ES version 3.1 (or 2, 0)
//   gl.clear_color(0.1, 0.2, 0.4, 1.0);   gl.clear_color_buffer();
//   int prog = gl.program(vertex_source, fragment_source);        // 0 and gl.log when a shader does not compile
//   gl.use(prog);   gl.draw_triangles(vertices (a Floats), 3);
//   String rgba = gl.read_pixels(0, 0, 256, 256);   // 4 bytes per pixel, the first row is the bottom
//   gl.compute(source, 64, 1, 1);                    // OpenGL ES 3.1: a compute shader (GLSL) on the graphics chip
// The functions are the ones of the OpenGL ES API in a J2K spelling (gl.gen_buffer = glGenBuffers ...); `gl.fn("glName")` gives any other
// function of the library (call it with Native::call1 .. call8). The picture can be shown through the app with  gfx  (the pixels).
#import <native>

struct Floats {
    i64 ptr;                    // the memory (4 bytes per number)
    i64 n;
    static Floats make(i64 count) {
        Floats f;
        f.ptr = (i64)Mem::alloc(count * 4 + 16);
        f.n = count;
        return f;
    }
    void set(self, i64 i, float v) {
        float^ p = (float^)self.ptr;
        p[i] = v;
    }
    float get(self, i64 i) {
        float^ p = (float^)self.ptr;
        return p[i];
    }
}

// whole numbers of 4 bytes, for the indices of a mesh
struct Ints {
    i64 ptr;
    i64 n;
    static Ints make(i64 count) {
        Ints f;
        f.ptr = (i64)Mem::alloc(count * 4 + 16);
        f.n = count;
        return f;
    }
    void set(self, i64 i, i64 v) {
        i64^ p = (i64^)self.ptr;
        char^ c = (char^)self.ptr;
        c[i * 4] = (char)(v & 255);
        c[i * 4 + 1] = (char)((v >> 8) & 255);
        c[i * 4 + 2] = (char)((v >> 16) & 255);
        c[i * 4 + 3] = (char)((v >> 24) & 255);
    }
}

struct Gl {
    i64 egl;                    // the handle of libEGL.so
    i64 gles;                   // the handle of libGLESv3.so
    i64 dpy;
    i64 ctx;
    i64 surf;
    i64 w;
    i64 h;
    i64 major;
    i64 minor;
    bool ok;
    String log;
    String renderer;
    i64[] fns;                  // a cache: the addresses of the functions by name
    String[] names;

    i64 fn(self, String name) {
        for i in 0..self.names.len { if self.names[i] == name { return self.fns[i]; } }
        i64 a = Native::sym(self.gles, name);
        if a == 0 && self.egl != 0 {
            i64 gp = Native::sym(self.egl, "eglGetProcAddress");
            if gp != 0 { a = Native::call1(gp, (i64)name.c()); }
        }
        self.names.push(name + "");
        self.fns.push(a);
        return a;
    }

    static Gl open(i64 w, i64 h, i64 major, i64 minor) {
        Gl g;
        g.w = w;
        g.h = h;
        g.major = major;
        g.minor = minor;
        g.ok = false;
        g.log = "";
        g.renderer = "";
        g.fns = arr(64);
        g.names = arr(64);
        g.egl = Native::open("libEGL.so");
        g.gles = Native::open("libGLESv3.so");
        if g.gles == 0 { g.gles = Native::open("libGLESv2.so"); }
        if g.egl == 0 || g.gles == 0 { g.log = "libEGL / libGLES not found (a program that imports <native> or <opengl3> is made dynamic by the compiler)"; return g; }
        i64 get_display = Native::sym(g.egl, "eglGetDisplay");
        i64 initialize = Native::sym(g.egl, "eglInitialize");
        i64 bind_api = Native::sym(g.egl, "eglBindAPI");
        i64 choose = Native::sym(g.egl, "eglChooseConfig");
        i64 make_pbuffer = Native::sym(g.egl, "eglCreatePbufferSurface");
        i64 make_ctx = Native::sym(g.egl, "eglCreateContext");
        i64 make_current = Native::sym(g.egl, "eglMakeCurrent");
        g.dpy = Native::call1(get_display, 0);
        if g.dpy == 0 { g.log = "eglGetDisplay failed"; return g; }
        i64 ver[4];
        ver[0] = 0; ver[1] = 0;
        if Native::call3(initialize, g.dpy, (i64)@ver, (i64)@ver + 4) == 0 { g.log = "eglInitialize failed"; return g; }
        Native::call1(bind_api, 12448);                              // EGL_OPENGL_ES_API
        i64 renderable = 4;                                          // EGL_OPENGL_ES2_BIT
        if major >= 3 { renderable = 64; }                           // EGL_OPENGL_ES3_BIT
        // EGL_SURFACE_TYPE, PBUFFER; RENDERABLE_TYPE; RGBA 8888; NONE  (32-bit entries)
        i64 words[16];
        words[0] = 12339; words[1] = 1;
        words[2] = 12352; words[3] = renderable;
        words[4] = 12324; words[5] = 8;
        words[6] = 12323; words[7] = 8;
        words[8] = 12322; words[9] = 8;
        words[10] = 12321; words[11] = 8;
        words[12] = 12344;
        // the attribute list as 32-bit integers in memory
        i64 a32 = (i64)Mem::alloc(128);
        for i in 0..13 { Native::poke32(a32 + i * 4, words[i]); }
        i64 cfg_ptr = (i64)Mem::alloc(16);
        i64 cnt_ptr = (i64)Mem::alloc(16);
        Native::poke64(cfg_ptr, 0);
        Native::poke32(cnt_ptr, 0);
        if Native::call5(choose, g.dpy, a32, cfg_ptr, 1, cnt_ptr) == 0 || Native::peek32(cnt_ptr) == 0 { g.log = "no EGL configuration for off-screen drawing"; return g; }
        i64 cfg = Native::peek64(cfg_ptr);
        i64 pb = (i64)Mem::alloc(32);
        Native::poke32(pb, 12375); Native::poke32(pb + 4, w);        // EGL_WIDTH
        Native::poke32(pb + 8, 12374); Native::poke32(pb + 12, h);   // EGL_HEIGHT
        Native::poke32(pb + 16, 12344);
        g.surf = Native::call3(make_pbuffer, g.dpy, cfg, pb);
        if g.surf == 0 { g.log = "eglCreatePbufferSurface failed"; return g; }
        i64 cx = (i64)Mem::alloc(32);
        Native::poke32(cx, 12440); Native::poke32(cx + 4, major);    // EGL_CONTEXT_CLIENT_VERSION
        i64 n = 8;
        if major >= 3 && minor > 0 { Native::poke32(cx + 8, 12539); Native::poke32(cx + 12, minor); n = 16; }   // EGL_CONTEXT_MINOR_VERSION
        Native::poke32(cx + n, 12344);
        g.ctx = Native::call4(make_ctx, g.dpy, cfg, 0, cx);
        if g.ctx == 0 { g.log = "eglCreateContext failed: this phone has no OpenGL ES " + str(major) + "." + str(minor); return g; }
        if Native::call4(make_current, g.dpy, g.surf, g.surf, g.ctx) == 0 { g.log = "eglMakeCurrent failed"; return g; }
        g.ok = true;
        i64 gs = g.fn("glGetString");
        i64 r = Native::call1(gs, 7937);                             // GL_RENDERER
        if r != 0 { g.renderer = Native::text(r); }
        return g;
    }

    // Use the OpenGL ES context that is already current in this thread (an Android app made it: GLSurfaceView calls the game on its GL thread).
    // Nothing is created here; close() does not destroy anything. Give the size of the surface with resize().
    static Gl attach(i64 w, i64 h) {
        Gl g;
        g.w = w;
        g.h = h;
        g.major = 3;
        g.minor = 0;
        g.ok = false;
        g.log = "";
        g.renderer = "";
        g.fns = arr(64);
        g.names = arr(64);
        g.egl = 0;
        g.dpy = 0;
        g.ctx = 0;
        g.surf = 0;
        g.gles = Native::open("libGLESv3.so");
        if g.gles == 0 { g.gles = Native::open("libGLESv2.so"); }
        if g.gles == 0 { g.log = "libGLES not found"; return g; }
        g.ok = true;
        i64 r = Native::call1(g.fn("glGetString"), 7937);          // GL_RENDERER (0 when no context is current)
        if r == 0 { g.ok = false; g.log = "no OpenGL ES context is current in this thread"; return g; }
        g.renderer = Native::text(r);
        return g;
    }
    void resize(self, i64 w, i64 h) { self.w = w; self.h = h; self.viewport(0, 0, w, h); }

    void close(self) {
        if self.ok && self.egl != 0 {
            i64 mc = Native::sym(self.egl, "eglMakeCurrent");
            Native::call4(mc, self.dpy, 0, 0, 0);
            self.ok = false;
        }
        if self.egl == 0 { self.ok = false; }                       // attached: the app owns the context
    }

    // ---- state and clearing
    void viewport(self, i64 x, i64 y, i64 w, i64 h) { Native::call4(self.fn("glViewport"), x, y, w, h); }
    void clear_color(self, double r, double g, double b, double a) { Native::callf4(self.fn("glClearColor"), (float)r, (float)g, (float)b, (float)a); }
    void clear_color_buffer(self) { Native::call1(self.fn("glClear"), 16384); }
    void clear_all(self) { Native::call1(self.fn("glClear"), 16640); }
    void enable(self, i64 cap) { Native::call1(self.fn("glEnable"), cap); }
    void disable(self, i64 cap) { Native::call1(self.fn("glDisable"), cap); }
    void blend_alpha(self) { Native::call1(self.fn("glEnable"), 3042); Native::call2(self.fn("glBlendFunc"), 770, 771); }
    void finish(self) { Native::call0(self.fn("glFinish")); }
    i64 error(self) { return Native::call0(self.fn("glGetError")); }

    // ---- shaders
    i64 shader(self, i64 kind, String src) {
        i64 s = Native::call1(self.fn("glCreateShader"), kind);
        i64 p = (i64)Mem::alloc(16);
        Native::poke64(p, (i64)src.c());
        Native::call4(self.fn("glShaderSource"), s, 1, p, 0);
        Native::call1(self.fn("glCompileShader"), s);
        i64 st = (i64)Mem::alloc(16);
        Native::poke32(st, 0);
        Native::call3(self.fn("glGetShaderiv"), s, 35713, st);      // GL_COMPILE_STATUS
        if Native::peek32(st) == 0 {
            i64 buf = (i64)Mem::alloc(2048);
            Native::call4(self.fn("glGetShaderInfoLog"), s, 2000, 0, buf);
            self.log = Native::text(buf);
            return 0;
        }
        return s;
    }
    // a program from the sources of a vertex and a fragment shader; 0 when it fails (the text is in gl.log)
    i64 program(self, String vs, String fs) {
        i64 a = self.shader(35633, vs);
        if a == 0 { return 0; }
        i64 b = self.shader(35632, fs);
        if b == 0 { return 0; }
        i64 p = Native::call0(self.fn("glCreateProgram"));
        Native::call2(self.fn("glAttachShader"), p, a);
        Native::call2(self.fn("glAttachShader"), p, b);
        Native::call1(self.fn("glLinkProgram"), p);
        i64 st = (i64)Mem::alloc(16);
        Native::poke32(st, 0);
        Native::call3(self.fn("glGetProgramiv"), p, 35714, st);     // GL_LINK_STATUS
        if Native::peek32(st) == 0 {
            i64 buf = (i64)Mem::alloc(2048);
            Native::call4(self.fn("glGetProgramInfoLog"), p, 2000, 0, buf);
            self.log = Native::text(buf);
            return 0;
        }
        return p;
    }
    void use(self, i64 prog) { Native::call1(self.fn("glUseProgram"), prog); }
    i64 uniform(self, i64 prog, String name) { return Native::call2(self.fn("glGetUniformLocation"), prog, (i64)name.c()); }
    i64 attrib(self, i64 prog, String name) { return Native::call2(self.fn("glGetAttribLocation"), prog, (i64)name.c()); }
    void uniform1f(self, i64 loc, double x) { Native::calli_f1(self.fn("glUniform1f"), loc, (float)x); }
    void uniform2f(self, i64 loc, double x, double y) { Native::calli_f2(self.fn("glUniform2f"), loc, (float)x, (float)y); }
    void uniform3f(self, i64 loc, double x, double y, double z) { Native::calli_f3(self.fn("glUniform3f"), loc, (float)x, (float)y, (float)z); }
    void uniform4f(self, i64 loc, double x, double y, double z, double w) { Native::calli_f4(self.fn("glUniform4f"), loc, (float)x, (float)y, (float)z, (float)w); }
    void uniform1i(self, i64 loc, i64 v) { Native::call2(self.fn("glUniform1i"), loc, v); }
    void uniform_matrix4(self, i64 loc, Floats m) { Native::call4(self.fn("glUniformMatrix4fv"), loc, 1, 0, m.ptr); }

    // ---- buffers and drawing
    i64 gen_buffer(self) {
        i64 p = (i64)Mem::alloc(16);
        Native::call2(self.fn("glGenBuffers"), 1, p);
        return Native::peek32(p);
    }
    void bind_buffer(self, i64 target, i64 buf) { Native::call2(self.fn("glBindBuffer"), target, buf); }
    // target: 34962 array, 35044 = STATIC_DRAW ...; the data is a Floats
    void buffer_data(self, i64 target, Floats data, i64 usage) { Native::call4(self.fn("glBufferData"), target, data.n * 4, data.ptr, usage); }
    void vertex_attrib(self, i64 index, i64 size, i64 stride_floats, i64 offset_floats) {
        Native::call2(self.fn("glEnableVertexAttribArray"), index, 0);
        Native::call6(self.fn("glVertexAttribPointer"), index, size, 5126, 0, stride_floats * 4, offset_floats * 4);
    }
    void draw_arrays(self, i64 mode, i64 first, i64 count) { Native::call3(self.fn("glDrawArrays"), mode, first, count); }
    // triangles from a Floats of 2 numbers (x, y) per vertex, drawn with the attribute 0 (a simple shader reads  in vec2 pos)
    void draw_triangles(self, Floats v, i64 count) {
        i64 b = self.gen_buffer();
        self.bind_buffer(34962, b);
        self.buffer_data(34962, v, 35044);
        self.vertex_attrib(0, 2, 2, 0);
        self.draw_arrays(4, 0, count);
    }

    // ---- textures, targets to draw into, vertex arrays, indices, instances
    i64 gen_texture(self) {
        i64 p = (i64)Mem::alloc(16);
        Native::call2(self.fn("glGenTextures"), 1, p);
        return Native::peek32(p);
    }
    // unit 0, 1, 2 ... (the shader reads  uniform sampler2D  with uniform1i(loc, unit))
    void bind_texture(self, i64 unit, i64 tex) {
        Native::call1(self.fn("glActiveTexture"), 33984 + unit);
        Native::call2(self.fn("glBindTexture"), 3553, tex);
    }
    void texture_params(self, bool linear, bool repeat) {
        i64 f = 9728;
        if linear { f = 9729; }
        i64 wrap = 33071;
        if repeat { wrap = 10497; }
        Native::call3(self.fn("glTexParameteri"), 3553, 10241, f);
        Native::call3(self.fn("glTexParameteri"), 3553, 10240, f);
        Native::call3(self.fn("glTexParameteri"), 3553, 10242, wrap);
        Native::call3(self.fn("glTexParameteri"), 3553, 10243, wrap);
    }
    // a texture from the bytes red, green, blue, alpha of w x h dots (the first row is the bottom row of the texture: v = 0)
    i64 make_texture(self, i64 w, i64 h, String rgba, bool linear) {
        i64 tex = self.gen_texture();
        self.bind_texture(0, tex);
        self.texture_params(linear, false);
        Native::call2(self.fn("glPixelStorei"), 3317, 1);
        Native::call9(self.fn("glTexImage2D"), 3553, 0, 6408, w, h, 0, 6408, 5121, (i64)rgba.c());
        return tex;
    }
    // an empty texture that can be drawn into (see make_framebuffer)
    i64 make_target_texture(self, i64 w, i64 h, bool linear) {
        i64 tex = self.gen_texture();
        self.bind_texture(0, tex);
        self.texture_params(linear, false);
        Native::call9(self.fn("glTexImage2D"), 3553, 0, 6408, w, h, 0, 6408, 5121, 0);
        return tex;
    }
    i64 gen_framebuffer(self) {
        i64 p = (i64)Mem::alloc(16);
        Native::call2(self.fn("glGenFramebuffers"), 1, p);
        return Native::peek32(p);
    }
    // 0 is the default framebuffer
    void bind_framebuffer(self, i64 fbo) { Native::call2(self.fn("glBindFramebuffer"), 36160, fbo); }
    // a framebuffer whose colour is the texture; 0 when it is not complete
    i64 make_framebuffer(self, i64 tex) {
        i64 fbo = self.gen_framebuffer();
        self.bind_framebuffer(fbo);
        Native::call5(self.fn("glFramebufferTexture2D"), 36160, 36064, 3553, tex, 0);
        if Native::call1(self.fn("glCheckFramebufferStatus"), 36160) != 36053 { return 0; }
        return fbo;
    }
    i64 gen_vertex_array(self) {
        i64 p = (i64)Mem::alloc(16);
        Native::call2(self.fn("glGenVertexArrays"), 1, p);
        return Native::peek32(p);
    }
    void bind_vertex_array(self, i64 vao) { Native::call1(self.fn("glBindVertexArray"), vao); }
    // indices: the buffer bound to 34963 (element array) before draw_elements
    void buffer_data_ints(self, i64 target, Ints data, i64 usage) { Native::call4(self.fn("glBufferData"), target, data.n * 4, data.ptr, usage); }
    void draw_elements(self, i64 mode, i64 count) { Native::call4(self.fn("glDrawElements"), mode, count, 5125, 0); }
    // an attribute that changes once per instance (d = 1) instead of once per vertex
    void vertex_divisor(self, i64 index, i64 d) { Native::call2(self.fn("glVertexAttribDivisor"), index, d); }
    void draw_arrays_instanced(self, i64 mode, i64 first, i64 count, i64 instances) { Native::call4(self.fn("glDrawArraysInstanced"), mode, first, count, instances); }
    // light adds up (fire, glow, bloom)
    void blend_additive(self) { Native::call1(self.fn("glEnable"), 3042); Native::call2(self.fn("glBlendFunc"), 770, 1); }

    // ---- reading the picture
    // the pixels of a rectangle: 4 bytes each (red, green, blue, alpha), the first row is the bottom one
    String read_pixels(self, i64 x, i64 y, i64 w, i64 h) {
        i64 n = w * h * 4;
        i64 buf = (i64)Mem::alloc(n + 16);
        Native::call7(self.fn("glReadPixels"), x, y, w, h, 6408, 5121, buf);
        String r = "";
        char^ p = (char^)buf;
        for i in 0..n { r.push(p[i]); }
        return r;
    }

    // ---- OpenGL ES 3.1: a compute shader that works on a buffer of 32-bit numbers (binding 0)
    // The source is GLSL ("#version 310 es ..." with  layout(std430, binding = 0) buffer Data { float v[]; };). The numbers go to the chip, the shader
    // runs on groups x y z, the numbers come back. Returns the buffer after the run.
    Floats compute(self, String src, Floats data, i64 gx, i64 gy, i64 gz) {
        i64 sh = self.shader(37305, src);                             // GL_COMPUTE_SHADER
        if sh == 0 { return data; }
        i64 p = Native::call0(self.fn("glCreateProgram"));
        Native::call2(self.fn("glAttachShader"), p, sh);
        Native::call1(self.fn("glLinkProgram"), p);
        i64 st = (i64)Mem::alloc(16);
        Native::poke32(st, 0);
        Native::call3(self.fn("glGetProgramiv"), p, 35714, st);
        if Native::peek32(st) == 0 { self.log = "the compute program does not link"; return data; }
        i64 b = self.gen_buffer();
        self.bind_buffer(37074, b);                                   // GL_SHADER_STORAGE_BUFFER
        self.buffer_data(37074, data, 35048);                         // GL_DYNAMIC_DRAW
        Native::call3(self.fn("glBindBufferBase"), 37074, 0, b);
        self.use(p);
        Native::call3(self.fn("glDispatchCompute"), gx, gy, gz);
        Native::call1(self.fn("glMemoryBarrier"), 0xffffffff);
        Floats out = Floats::make(data.n);
        i64 mapped = Native::call4(self.fn("glMapBufferRange"), 37074, 0, data.n * 4, 1);   // GL_MAP_READ_BIT
        if mapped != 0 {
            for i in 0..data.n * 4 {
                char^ src_p = (char^)mapped;
                char^ dst_p = (char^)out.ptr;
                dst_p[i] = src_p[i];
            }
            Native::call1(self.fn("glUnmapBuffer"), 37074);
        }
        return out;
    }
}
