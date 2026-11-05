# The graphics chip: `<gpu>`, `<canvas2d>`, OpenGL ES, Vulkan

J2K reaches the graphics chip in four ways. Which one to use depends on where the program runs.
The examples were run on the author's phone (Kirin 990 with a Mali GPU, Termux, 2026-11-05) unless
the block says `jk-no`, which means it needs the Jaric app or a screen and was not run.

| Library | What it is | Runs here (Termux) |
|---|---|---|
| `<gpu>` | commands sent to the Jaric app, which draws them with OpenGL ES | no: `Gpu::open` says there is no chip |
| `<canvas2d>` + `<glcanvas>` | one 2D drawing interface on OpenGL ES 3 (or 2) | yes, off screen |
| `<opengl3>` | OpenGL ES 3.1 functions, a compute shader too | yes, off screen |
| `<vulkan>` | Vulkan: device, buffers, compute pipelines | yes (compute only) |

## 1. `<gpu>`: the chip through the Jaric app

`Gpu::open(w, h)` opens a picture of `w x h` dots that the Jaric app shows. Outside the app it is not ok:

```jk
#import <stdlib>
#import <gpu>
void main() {
    Gpu g = Gpu::open(320, 180);
    if !g.ok() { jout << "no graphics chip here\n"; return; }
    jout << "chip: " << g.renderer << "\n";
    g.close();
}
```

Output (in Termux):

```
no graphics chip here
```

A program for the app has a frame loop like this (`jk-no`: it needs the app and a picture file):

```jk-no
#import <gpu>
void main() {
    Gpu g = Gpu::open(320, 180);     // a picture of 320 x 180 logical pixels, scaled to the screen
    if !g.ok() { return; }
    g.load(1, "ship.png");           // a picture file becomes the texture 1
    while g.running() {
        g.begin();                   // touches and keys, g.dt
        g.clear(Gpu::rgb(10, 20, 40));
        g.rect(10, 10, 50, 30, Gpu::rgb(255, 200, 60));
        g.tri(100, 100, 140, 100, 120, 60, Gpu::rgb(255, 0, 0));
        g.image(1, 150, 90, 32, 32, Gpu::rgb(255, 255, 255));
        g.end();                     // sends the picture to the chip and waits for the next one
    }
    g.close();
}
```

Colours are `0xAARRGGBB` (`Gpu::rgb(r, g, b)` is opaque, `Gpu::rgba` has alpha). Touch: `g.touching()`,
`g.tapped()`, `g.touch_x`, `g.touch_y`. The commands are written to a file and the app draws them, so
the chip does the work and the program does little.

## 2. `<canvas2d>` on OpenGL ES: one drawing code, several backends

`Canvas2d` is an interface: `begin`, `clear`, `rect`, `tri`, `line`, `circle`, `end`. A game is written
against it once. `GlCanvas` (from `<glcanvas>`) is the backend on OpenGL ES; the Jaric app's backend is
`AppCanvas` (`<gpu>`). Coordinates are dots, `(0, 0)` at the top left.

```jk
#import <stdlib>
#import <opengl3>
#import <canvas2d>
#import <glcanvas>

void draw_scene(Canvas2d^ c) {
    c^.begin();
    c^.clear(Color::rgb(10, 20, 40));
    c^.rect(10.0, 10.0, 50.0, 30.0, Color::rgb(255, 200, 60));
    c^.circle(100.0, 60.0, 20.0, Color::rgb(255, 255, 255));
    c^.end();                                  // the frame is drawn here
}

int main() {
    Gl gl = Gl::open(160, 120, 3, 1);          // off screen (in the app: Gl::attach)
    if !gl.ok { jout << "no GL: " << gl.log << "\n"; return 1; }
    GlCanvas c;
    c.init();
    c.setup(gl, 160.0, 120.0);
    Canvas2d^ cv = @c;
    draw_scene(cv);
    jout << "draw calls in the frame: " << c.draws << "\n";
    String px = gl.read_pixels(30, 120 - 25, 1, 1);     // the rectangle, y counted from the bottom
    jout << "rect pixel " << (px[0] & 255) << " " << (px[1] & 255) << " " << (px[2] & 255) << "\n";
    return 0;
}
```

Output:

```
draw calls in the frame: 1
rect pixel 255 200 60
```

Every shape of a frame goes into one buffer and is drawn with one call (`c.draws` counts them). The
batch holds 8192 triangles; a fuller frame is drawn in parts. Pictures: `GlCanvas` loads PNG files
and `image()` draws them (see `std/glcanvas.j`). `c.has_instancing()` and `c.has_shaders()` tell what a
backend can do.

Text on any backend: `canvas_text(c, x, y, "SCORE 10", 2.0, colour)` with a 3 x 5 font (capitals,
digits, signs).

## 3. `<opengl3>`: OpenGL ES from J2K

`Gl::open(w, h, major, minor)` makes an off-screen context (`3, 1` for ES 3.1, `2, 0` for ES 2).
Inside an app, `Gl::attach(w, h)` uses the context the app made. A program that imports `<opengl3>` is
built as a dynamic executable by itself (no `-dyn` flag needed). This is a triangle, then a compute
shader that doubles and adds one (from the repository test `t513`):

```jk
#import <stdlib>
#import <opengl3>
int main() {
    Gl gl = Gl::open(64, 64, 3, 1);
    if !gl.ok { jout << "no GL: " << gl.log << "\n"; return 1; }
    String vs = "#version 300 es\nlayout(location = 0) in vec2 pos;\nvoid main() { gl_Position = vec4(pos, 0.0, 1.0); }\n";
    String fs = "#version 300 es\nprecision mediump float;\nout vec4 color;\nvoid main() { color = vec4(1.0, 0.5, 0.0, 1.0); }\n";
    int prog = gl.program(vs, fs);
    if prog == 0 { jout << "shader: " << gl.log << "\n"; return 1; }
    gl.clear_color(0.0, 0.0, 0.0, 1.0);
    gl.clear_color_buffer();
    gl.use(prog);
    Floats tri = Floats::make(6);
    tri.set(0, -1.0); tri.set(1, -1.0); tri.set(2, 1.0); tri.set(3, -1.0); tri.set(4, 0.0); tri.set(5, 1.0);
    gl.draw_triangles(tri, 3);
    String px = gl.read_pixels(32, 20, 1, 1);
    jout << "triangle pixel " << (px[0] & 255) << " " << (px[1] & 255) << " " << (px[2] & 255) << " " << (px[3] & 255) << "\n";
    String out = gl.read_pixels(1, 62, 1, 1);
    jout << "corner pixel   " << (out[0] & 255) << " " << (out[1] & 255) << " " << (out[2] & 255) << "\n";
    // a compute shader: v[i] = v[i] * 2 + 1
    String cs = "#version 310 es\nlayout(local_size_x = 8) in;\nlayout(std430, binding = 0) buffer Data { float v[]; };\nvoid main() { uint i = gl_GlobalInvocationID.x; v[i] = v[i] * 2.0 + 1.0; }\n";
    Floats data = Floats::make(16);
    for i in 0..16 { data.set(i, (float)i); }
    Floats res = gl.compute(cs, data, 2, 1, 1);
    jout << "compute: " << res.get(0) << " " << res.get(1) << " " << res.get(5) << " " << res.get(15) << "\n";
    return 0;
}
```

Output:

```
triangle pixel 255 128 0 255
corner pixel   0 0 0
compute: 1.000000 3.000000 11.000000 31.000000
```

`Gl` methods (from `std/opengl3.j`): `open`, `attach`, `resize`, `close`, `viewport`, `clear_color`,
`clear_color_buffer`, `clear_all`, `enable`, `disable`, `blend_alpha`, `blend_additive`, `finish`,
`error`, `shader`, `program`, `use`, `uniform`, `attrib`, `uniform1f` .. `uniform4f`, `uniform1i`,
`uniform_matrix4`, `gen_buffer`, `bind_buffer`, `buffer_data`, `buffer_data_ints`, `vertex_attrib`,
`draw_arrays`, `draw_triangles`, `draw_elements`, `draw_arrays_instanced`, `vertex_divisor`,
`gen_texture`, `bind_texture`, `texture_params`, `make_texture`, `make_target_texture`,
`gen_framebuffer`, `bind_framebuffer`, `make_framebuffer`, `gen_vertex_array`, `bind_vertex_array`,
`read_pixels`, `compute`, `fn(name)`.

The C functions the library calls by name are: glActiveTexture, glAttachShader, glBindBuffer,
glBindBufferBase, glBindFramebuffer, glBindTexture, glBindVertexArray, glBlendFunc, glBufferData,
glCheckFramebufferStatus, glClear, glClearColor, glCompileShader, glCreateProgram, glCreateShader,
glDisable, glDispatchCompute, glDrawArrays, glDrawArraysInstanced, glDrawElements, glEnable,
glEnableVertexAttribArray, glFinish, glFramebufferTexture2D, glGenBuffers, glGenFramebuffers,
glGenTextures, glGenVertexArrays, glGetAttribLocation, glGetError, glGetProgramInfoLog, glGetProgramiv,
glGetShaderInfoLog, glGetShaderiv, glGetString, glGetUniformLocation, glLinkProgram, glMapBufferRange,
glMemoryBarrier, glPixelStorei, glReadPixels, glShaderSource, glTexImage2D, glTexParameteri,
glUniform1f, glUniform1i, glUniform2f, glUniform3f, glUniform4f, glUniformMatrix4fv, glUnmapBuffer,
glUseProgram, glVertexAttribDivisor, glVertexAttribPointer, glViewport. Any other one: `gl.fn("glName")`
and `Native::call1` .. `call8` (see [LANGUAGE.md](LANGUAGE.md) and `<native>`).

**The file `std/gpu.j` has no OpenGL ES calls.** It is the `<gpu>` library of section 1; the OpenGL
ES calls are all in `std/opengl3.j`.

## 4. `<vulkan>`: compute only

`Vk::open()` makes an instance and looks at the first chip (`ok`, `device_name`, `api_text()`,
`memory_mb`, `has_compute`, `family`). `make_device()` makes a logical device and a queue, `make_buffer(bytes)`
a buffer the CPU and the GPU both see (`upload`, `download`), and `make_compute(spirv, n)` a compute
pipeline whose `n` storage buffers are bound with `bind(i, buffer)` and run with `run(gx, gy, gz)`.

```jk
#import <stdlib>
#import <vulkan>
int main() {
    Vk vk = Vk::open();
    if !vk.ok { jout << vk.log << "\n"; return 1; }
    if !vk.make_device() { jout << vk.log << "\n"; return 1; }
    int n = 4096;
    VkBuf a = vk.make_buffer(n * 4);
    VkBuf b = vk.make_buffer(n * 4);
    VkBuf c = vk.make_buffer(n * 4);
    float^ x = (float^)Mem::alloc(n * 4);
    float^ y = (float^)Mem::alloc(n * 4);
    float^ z = (float^)Mem::alloc(n * 4);
    for i in 0..n { x[i] = (float)i; y[i] = 0.5; z[i] = 0.0; }
    a.upload(x, n);
    b.upload(y, n);
    c.upload(z, n);
    Compute k = vk.make_compute(VkShaders::vector_add(), 3);     // a SPIR-V program: c[i] = a[i] + b[i]
    if !k.ok { jout << "pipeline: " << k.error << "\n"; return 1; }
    k.bind(0, a);
    k.bind(1, b);
    k.bind(2, c);
    if !k.run(n / 64, 1, 1) { jout << k.error << "\n"; return 1; }     // waits until the GPU is done
    c.download(z, n);
    bool ok = true;
    for i in 0..n { if z[i] != x[i] + 0.5 { ok = false; } }
    jout << "vector add on the GPU matches the CPU: " << ok << "\n";
    return 0;
}
```

Output:

```
vector add on the GPU matches the CPU: true
```

Run with `-dyn` is not needed when the program imports `<vulkan>` (the library imports `<native>`).
The repository test `t564` also copies a million floats to the GPU and back (equal) and checks the
result text of `VK_ERROR_DEVICE_LOST` (`Vk::result_text(-4)`).

**Limits.** `std/vulkan.j` (0.3.0) has no swapchain and no graphics pipeline: nothing draws a window
with Vulkan yet. Compute works; `vk.log` holds the message when a step fails.

## 5. A frame loop, and what limits it

| Path | Per frame | Limit |
|---|---|---|
| `<gpu>` | commands written to a file, the app draws them | the picture size given to `Gpu::open` |
| `<canvas2d>` on `GlCanvas` | one buffer, one draw call | 8192 triangles per batch |
| `<opengl3>` | your calls | ES 3.1 on this phone; `gl.fn` for the rest |
| `<vulkan>` | `run` waits for the GPU | compute only |

Not measured here: frame rates, the cost of `read_pixels`, the cost of a `<gpu>` frame, and any
comparison with C or with a native game engine. [PERFORMANCE.md](PERFORMANCE.md) will hold numbers
when they exist.

## See also

* [APP_PACKAGING.md](APP_PACKAGING.md) for an app that draws with OpenGL ES (`render = "gl"`)
* [UI.md](UI.md) for the widgets of an app
* [NPU.md](NPU.md) for the NPU of the phone
