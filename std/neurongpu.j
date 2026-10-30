// neurongpu 0.1.0 -- the matrix product of <neuron> on the GPU (a compute shader, tiles of 16 x 16).   #import <neurongpu>
//   NeuronGpu::enable(16000000);  // from now on Tensor32.matmul (and so Graph.matmul, Linear, Gpt) uses the GPU for products with m * k * n >= 16000000
//   NeuronGpu::disable();         // back to the CPU
// The limit is in multiply-adds (m * k * n). On a Kirin 990 the GPU wins from about 256 x 256 x 256 (16.7 million; 1.5 times faster, 2.4 times at 512);
// below that sending the numbers costs more than the product. If there is no GPU (or no GL), enable returns false
// and the CPU is used as before. The numbers are float32 on both sides; the last digits of a sum may differ from the CPU.
#import <neuron>
#import <opengl3>
#import <compute>

Gl ng_gl;
Kernel ng_k;
GpuBuffer ng_ga;
GpuBuffer ng_gb;
GpuBuffer ng_gc;
GpuBuffer ng_gd;
int ng_ready;
int ng_cap_c;                 // the numbers the buffer of the result holds now

int ng_matmul(float^ a, float^ b, float^ c, int m, int k, int n) {
    if ng_ready != 1 { return 0; }
    Floats fa;
    fa.ptr = (int)a;
    fa.n = m * k;
    Floats fb;
    fb.ptr = (int)b;
    fb.n = k * n;
    Floats fd = Floats::make(4);
    fd.set(0, (float)m);
    fd.set(1, (float)k);
    fd.set(2, (float)n);
    fd.set(3, 0.0);
    ng_ga.write(fa);
    ng_gb.write(fb);
    ng_gd.write(fd);
    Mem::free((void^)fd.ptr);
    if m * n > ng_cap_c {
        Floats fc;
        fc.ptr = (int)c;
        fc.n = m * n;
        ng_gc.write(fc);
        ng_cap_c = m * n;
    }
    ng_k.run((n + 15) / 16, (m + 15) / 16, 1);
    ng_gl.bind_buffer(37074, ng_gc.id);
    Native::call1(ng_gl.fn("glMemoryBarrier"), 0xffffffff);
    int mapped = Native::call4(ng_gl.fn("glMapBufferRange"), 37074, 0, m * n * 4, 1);
    if mapped == 0 { return 0; }
    float^ src = (float^)mapped;
    for i in 0..m * n { c[i] = src[i]; }
    Native::call1(ng_gl.fn("glUnmapBuffer"), 37074);
    return 1;
}

struct NeuronGpu {
    static bool enable(int min_work) {
        if ng_ready != 1 {
            ng_gl = Gl::open(64, 64, 3, 1);
            if !ng_gl.ok { return false; }
            String src = "#version 310 es\nprecision highp float;\nlayout(local_size_x = 16, local_size_y = 16) in;\n";
            src = src + "layout(std430, binding = 0) readonly buffer A { float a[]; };\nlayout(std430, binding = 1) readonly buffer B { float b[]; };\n";
            src = src + "layout(std430, binding = 2) buffer C { float c[]; };\nlayout(std430, binding = 3) readonly buffer D { float d[]; };\n";
            src = src + "shared float ta[16][16];\nshared float tb[16][16];\n";
            src = src + "void main() {\n uint M = uint(d[0]); uint K = uint(d[1]); uint N = uint(d[2]);\n";
            src = src + " uint row = gl_GlobalInvocationID.y; uint col = gl_GlobalInvocationID.x; uint lr = gl_LocalInvocationID.y; uint lc = gl_LocalInvocationID.x;\n float acc = 0.0;\n";
            src = src + " for (uint t = 0u; t < (K + 15u) / 16u; t++) {\n  uint ac = t * 16u + lc; uint br = t * 16u + lr;\n";
            src = src + "  ta[lr][lc] = (row < M && ac < K) ? a[row * K + ac] : 0.0;\n  tb[lr][lc] = (br < K && col < N) ? b[br * N + col] : 0.0;\n  barrier();\n";
            src = src + "  for (uint q = 0u; q < 16u; q++) { acc += ta[lr][q] * tb[q][lc]; }\n  barrier();\n }\n";
            src = src + " if (row < M && col < N) { c[row * N + col] = acc; }\n}\n";
            ng_k = Kernel::make(ng_gl, src);
            if !ng_k.ok { return false; }
            Floats one = Floats::make(16);
            ng_ga = GpuBuffer::make(ng_gl, 0, one);
            ng_gb = GpuBuffer::make(ng_gl, 1, one);
            ng_gc = GpuBuffer::make(ng_gl, 2, one);
            ng_gd = GpuBuffer::make(ng_gl, 3, one);
            ng_cap_c = 0;
            ng_ready = 1;
        }
        nt_gpu_fn = ng_matmul;
        nt_gpu_min = min_work;
        nt_gpu_on = 1;
        return true;
    }
    static void disable() { nt_gpu_on = 0; }
}
