// native 0.1.1 -- call the libraries of the system (Vulkan, OpenGL ES, OpenCL, libc ...) from J2K.   #import <native>   (needs jcmp 1.1.1 or newer; license: MPL-2.0)
//   int lib = Native::open("libvulkan.so");              // 0 when it is not there
//   int fn = Native::sym(lib, "vkEnumerateInstanceVersion");
//   int rc = Native::call1(fn, (int)@version);           // call1 .. call9: integer and pointer arguments, the result in x0
// It works in a program built with  jcmp -dyn  (a dynamic executable: the loader of Android gives it libdl.so and libc.so) and in a
// shared library (-l) that Android loads. A static program (the default) has no libdl: Native::open gives 0 there.
// How: the memory of libdl.so is read (the maps of the process and its ELF tables) to find dlopen and dlsym, then they are called
// through function pointers. Floating point arguments: callf1 .. callf4 (float arguments), callfd (double). Memory: peek / poke.

int native_dlopen;
int native_dlsym;
bool native_ready;

int native_rd8(int a) { char^ p = (char^)a; return p[0] & 255; }
int native_rd16(int a) { return native_rd8(a) | (native_rd8(a + 1) << 8); }
int native_rd32(int a) { return native_rd16(a) | (native_rd16(a + 2) << 16); }
int native_rd64(int a) { return native_rd32(a) | (native_rd32(a + 4) << 32); }

bool native_name_is(int a, String s) {
    for i in 0..s.len { if native_rd8(a + i) != (s[i] & 255) { return false; } }
    return native_rd8(a + s.len) == 0;
}

// the base address of a library in the maps of this process; 0 when it is not loaded
int native_base_of(String lib) {
    int fd = Sys::open_read("/proc/self/maps".c());
    if fd < 0 { return 0; }
    String t = "";
    char buf[4096];
    int n = Sys::read(fd, @buf, 4096);
    while n > 0 { for i in 0..n { t.push(buf[i]); } n = Sys::read(fd, @buf, 4096); }
    Sys::close(fd);
    String[] lines = t.split("\n");
    for i in 0..lines.len {
        String l = lines[i];
        if l.ends_with(lib) {
            int dash = l.find("-");
            String hex = l.slice(0, dash);
            int v = 0;
            for k in 0..hex.len {
                int c = hex[k] & 255;
                int d = 0;
                if c >= 48 && c <= 57 { d = c - 48; } else { d = c - 87; }
                v = v * 16 + d;
            }
            return v;
        }
    }
    return 0;
}

// the address of a function that a loaded library exports (its dynamic section and symbol table are read from memory)
int native_sym_in(int base, String name) {
    int phoff = native_rd64(base + 32);
    int phnum = native_rd16(base + 56);
    int phsz = native_rd16(base + 54);
    int dyn = 0;
    for i in 0..phnum {
        int ph = base + phoff + i * phsz;
        if native_rd32(ph) == 2 { dyn = base + native_rd64(ph + 16); }
    }
    if dyn == 0 { return 0; }
    int strtab = 0;
    int symtab = 0;
    int k = 0;
    while native_rd64(dyn + k * 16) != 0 {
        int tag = native_rd64(dyn + k * 16);
        int val = native_rd64(dyn + k * 16 + 8);
        if val < base { val = val + base; }
        if tag == 5 { strtab = val; }
        if tag == 6 { symtab = val; }
        k += 1;
    }
    if strtab == 0 || symtab == 0 { return 0; }
    int nsyms = (strtab - symtab) / 24;
    if nsyms <= 0 || nsyms > 100000 { nsyms = 4000; }
    for i in 0..nsyms {
        int s = symtab + i * 24;
        int nm = native_rd32(s);
        if native_rd64(s + 8) != 0 && native_name_is(strtab + nm, name) { return base + native_rd64(s + 8); }
    }
    return 0;
}

bool native_start() {
    if native_ready { return native_dlopen != 0; }
    native_ready = true;
    int base = native_base_of("libdl.so");
    if base == 0 { return false; }
    native_dlopen = native_sym_in(base, "dlopen");
    native_dlsym = native_sym_in(base, "dlsym");
    if native_dlopen == 0 || native_dlsym == 0 { native_dlopen = 0; return false; }
    return true;
}

// Calls of C functions that take floating point arguments. J2K passes a float as its bits in an integer register; the C convention wants it in s0, s1 ...
// These small naked functions move the bits there and jump to the C function (which returns to the caller of the helper).
// call9: a C function with 9 arguments (glTexImage2D ...): the first six go in registers, the last three are in a block of three numbers;
// the trampoline puts them where the C function looks (x6, x7 and the 9th on the stack, AAPCS64) and calls it.
naked int native_call9(int fn, int a1, int a2, int a3, int a4, int a5, int a6, int^ blk) {
    sp -= 32;
    [sp + 8] = x30;
    x16 = x0;
    x9 = x7;
    x0 = x1;
    x1 = x2;
    x2 = x3;
    x3 = x4;
    x4 = x5;
    x5 = x6;
    x6 = [x9 + 0];
    x7 = [x9 + 8];
    x10 = [x9 + 16];
    [sp + 0] = x10;
    Cpu::inst("blr", x16);
    x30 = [sp + 8];
    sp += 32;
    ret;
}
naked void native_cf1(int fn, int a) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("fmov", s0, w1);
    Cpu::inst("br", x16);
}
naked void native_cf2(int fn, int a, int b) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("fmov", s0, w1);
    Cpu::inst("fmov", s1, w2);
    Cpu::inst("br", x16);
}
naked void native_cf3(int fn, int a, int b, int c) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("fmov", s0, w1);
    Cpu::inst("fmov", s1, w2);
    Cpu::inst("fmov", s2, w3);
    Cpu::inst("br", x16);
}
naked void native_cf4(int fn, int a, int b, int c, int d) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("fmov", s0, w1);
    Cpu::inst("fmov", s1, w2);
    Cpu::inst("fmov", s2, w3);
    Cpu::inst("fmov", s3, w4);
    Cpu::inst("br", x16);
}
// an integer argument first (x0), then floats (s0 ...)
naked void native_cif1(int fn, int a, int x) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("mov", x0, x1);
    Cpu::inst("fmov", s0, w2);
    Cpu::inst("br", x16);
}
naked void native_cif2(int fn, int a, int x, int y) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("mov", x0, x1);
    Cpu::inst("fmov", s0, w2);
    Cpu::inst("fmov", s1, w3);
    Cpu::inst("br", x16);
}
naked void native_cif3(int fn, int a, int x, int y, int z) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("mov", x0, x1);
    Cpu::inst("fmov", s0, w2);
    Cpu::inst("fmov", s1, w3);
    Cpu::inst("fmov", s2, w4);
    Cpu::inst("br", x16);
}
naked void native_cif4(int fn, int a, int x, int y, int z, int w) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("mov", x0, x1);
    Cpu::inst("fmov", s0, w2);
    Cpu::inst("fmov", s1, w3);
    Cpu::inst("fmov", s2, w4);
    Cpu::inst("fmov", s3, w5);
    Cpu::inst("br", x16);
}

// the 32 bits of a float (J2K keeps the bits in an integer register, but a float cannot be given to a parameter of a naked function)
int native_fbits(float x) {
    float t = x;
    char^ p = (char^)@t;
    return (p[0] & 255) | ((p[1] & 255) << 8) | ((p[2] & 255) << 16) | ((p[3] & 255) << 24);
}

struct Native {
    // the handle of a library (0: not found, or this program cannot load libraries: build it with jcmp -dyn)
    static int open(String lib) {
        if !native_start() { return 0; }
        int(int, int)^ f = (int(int, int)^)native_dlopen;
        return f((int)lib.c(), 2);                       // RTLD_NOW
    }
    // the address of a function (0 when there is none)
    static int sym(int handle, String name) {
        if !native_start() || handle == 0 { return 0; }
        int(int, int)^ f = (int(int, int)^)native_dlsym;
        return f(handle, (int)name.c());
    }
    static int call0(int fn) { int()^ f = (int()^)fn; return f(); }
    static int call1(int fn, int a) { int(int)^ f = (int(int)^)fn; return f(a); }
    static int call2(int fn, int a, int b) { int(int, int)^ f = (int(int, int)^)fn; return f(a, b); }
    static int call3(int fn, int a, int b, int c) { int(int, int, int)^ f = (int(int, int, int)^)fn; return f(a, b, c); }
    static int call4(int fn, int a, int b, int c, int d) { int(int, int, int, int)^ f = (int(int, int, int, int)^)fn; return f(a, b, c, d); }
    static int call5(int fn, int a, int b, int c, int d, int e) { int(int, int, int, int, int)^ f = (int(int, int, int, int, int)^)fn; return f(a, b, c, d, e); }
    static int call6(int fn, int a, int b, int c, int d, int e, int g) { int(int, int, int, int, int, int)^ f = (int(int, int, int, int, int, int)^)fn; return f(a, b, c, d, e, g); }
    static int call7(int fn, int a, int b, int c, int d, int e, int g, int h) { int(int, int, int, int, int, int, int)^ f = (int(int, int, int, int, int, int, int)^)fn; return f(a, b, c, d, e, g, h); }
    static int call8(int fn, int a, int b, int c, int d, int e, int g, int h, int i) { int(int, int, int, int, int, int, int, int)^ f = (int(int, int, int, int, int, int, int, int)^)fn; return f(a, b, c, d, e, g, h, i); }
    // nine integer or pointer arguments (glTexImage2D, glTexSubImage2D)
    static int call9(int fn, int a, int b, int c, int d, int e, int g, int h, int i, int j) {
        int blk[3];
        blk[0] = h;
        blk[1] = i;
        blk[2] = j;
        return native_call9(fn, a, b, c, d, e, g, @blk[0]);
    }
    // float arguments (OpenGL: glClearColor, glUniform4f ...); the result is dropped
    static void callf1(int fn, float a) { native_cf1(fn, native_fbits(a)); }
    static void callf2(int fn, float a, float b) { native_cf2(fn, native_fbits(a), native_fbits(b)); }
    static void callf3(int fn, float a, float b, float c) { native_cf3(fn, native_fbits(a), native_fbits(b), native_fbits(c)); }
    static void callf4(int fn, float a, float b, float c, float d) { native_cf4(fn, native_fbits(a), native_fbits(b), native_fbits(c), native_fbits(d)); }
    // an integer argument first, then floats (OpenGL: glUniform1f(location, x) ...)
    static void calli_f1(int fn, int a, float x) { native_cif1(fn, a, native_fbits(x)); }
    static void calli_f2(int fn, int a, float x, float y) { native_cif2(fn, a, native_fbits(x), native_fbits(y)); }
    static void calli_f3(int fn, int a, float x, float y, float z) { native_cif3(fn, a, native_fbits(x), native_fbits(y), native_fbits(z)); }
    static void calli_f4(int fn, int a, float x, float y, float z, float w) { native_cif4(fn, a, native_fbits(x), native_fbits(y), native_fbits(z), native_fbits(w)); }
    // the text (a C string ending with 0) at an address
    static String text(int a) { String r = ""; r.append((char^)a); return r; }
    // the memory of the process
    static int peek8(int a) { return native_rd8(a); }
    static int peek32(int a) { return native_rd32(a); }
    static int peek64(int a) { return native_rd64(a); }
    static void poke32(int a, int v) { char^ p = (char^)a; p[0] = (char)(v & 255); p[1] = (char)((v >> 8) & 255); p[2] = (char)((v >> 16) & 255); p[3] = (char)((v >> 24) & 255); }
    static void poke64(int a, int v) { Native::poke32(a, v & 4294967295); Native::poke32(a + 4, (v >> 32) & 4294967295); }
}
