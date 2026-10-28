// compute 0.1.0 -- GPU compute that is compiled once and run many times on numbers that stay on the chip.   #import <opengl3> <compute>   (needs jcmp -dyn; license: MPL-2.0)
//   Gl gl = Gl::open(64, 64, 3, 1);
//   Kernel k = Kernel::make(gl, glsl_source);           // "#version 310 es ... layout(std430, binding = 0) buffer A { float a[]; };  layout(std430, binding = 1) buffer B { float b[]; };"
//   if !k.ok { cout << k.error << "\n"; return; }
//   GpuBuffer a = GpuBuffer::make(gl, 0, data);         // binding 0; `data` is a Floats; it is sent once
//   k.run(gx, gy, gz);                                  // one run = gx * gy * gz groups of the size written in the shader (local_size_x ...); many runs without copying
//   Floats out = a.read();                              // the numbers come back only when you ask
//   a.write(more);                                      // send new numbers (same size) when the program changes them
// A buffer keeps its number (binding) for the shader; use the bindings 0, 1, 2 ... for several buffers. Compile errors: k.error holds the log of the driver.

struct GpuBuffer {
    Gl gl;
    int id;
    int binding;
    int n;                       // numbers (4 bytes each)

    static GpuBuffer make(Gl gl, int binding, Floats data) {
        GpuBuffer b;
        b.gl = gl;
        b.binding = binding;
        b.n = data.n;
        b.id = gl.gen_buffer();
        gl.bind_buffer(37074, b.id);                                      // GL_SHADER_STORAGE_BUFFER
        gl.buffer_data(37074, data, 35048);                               // GL_DYNAMIC_DRAW
        Native::call3(gl.fn("glBindBufferBase"), 37074, binding, b.id);
        return b;
    }

    // new numbers of the same count
    void write(self, Floats data) {
        self.gl.bind_buffer(37074, self.id);
        self.gl.buffer_data(37074, data, 35048);
        Native::call3(self.gl.fn("glBindBufferBase"), 37074, self.binding, self.id);
    }

    Floats read(self) {
        Floats out = Floats::make(self.n);
        self.gl.bind_buffer(37074, self.id);
        Native::call1(self.gl.fn("glMemoryBarrier"), 0xffffffff);
        int mapped = Native::call4(self.gl.fn("glMapBufferRange"), 37074, 0, self.n * 4, 1);       // GL_MAP_READ_BIT
        if mapped != 0 {
            char^ src_p = (char^)mapped;
            char^ dst_p = (char^)out.ptr;
            for i in 0..self.n * 4 { dst_p[i] = src_p[i]; }
            Native::call1(self.gl.fn("glUnmapBuffer"), 37074);
        }
        return out;
    }
}

struct Kernel {
    Gl gl;
    int prog;
    bool ok;
    String error;

    static Kernel make(Gl gl, String src) {
        Kernel k;
        k.gl = gl;
        k.ok = false;
        k.error = "";
        int sh = gl.shader(37305, src);                                   // GL_COMPUTE_SHADER
        if sh == 0 {
            k.error = gl.log + "";
            return k;
        }
        k.prog = Native::call0(gl.fn("glCreateProgram"));
        Native::call2(gl.fn("glAttachShader"), k.prog, sh);
        Native::call1(gl.fn("glLinkProgram"), k.prog);
        int st = (int)Mem::alloc(16);
        Native::poke32(st, 0);
        Native::call3(gl.fn("glGetProgramiv"), k.prog, 35714, st);
        if Native::peek32(st) == 0 {
            k.error = "the compute program does not link";
            return k;
        }
        k.ok = true;
        return k;
    }

    void run(self, int gx, int gy, int gz) {
        if !self.ok { return; }
        self.gl.use(self.prog);
        Native::call3(self.gl.fn("glDispatchCompute"), gx, gy, gz);
        Native::call1(self.gl.fn("glMemoryBarrier"), 0xffffffff);
    }
}
