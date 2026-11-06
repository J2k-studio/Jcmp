// native 0.1.1 -- call the libraries of the system (Vulkan, OpenGL ES, OpenCL, libc ...) from J2K.   #import <native>   (needs jcmp 1.1.1 or newer; license: MPL-2.0)
//   int lib = Native::open("libvulkan.so");              // 0 when it is not there
//   int fn = Native::sym(lib, "vkEnumerateInstanceVersion");
//   int rc = Native::call1(fn, (int)@version);           // call1 .. call9: integer and pointer arguments, the result in x0
// It works in a program built with  jcmp -dyn  (a dynamic executable: the loader of Android gives it libdl.so and libc.so) and in a
// shared library (-l) that Android loads. A static program (the default) has no libdl: Native::open gives 0 there.
// How: the memory of libdl.so is read (the maps of the process and its ELF tables) to find dlopen and dlsym, then they are called
// through function pointers. Floating point arguments: callf1 .. callf4 (float arguments), callfd (double). Memory: peek / poke.

i64 native_dlopen;
i64 native_dlsym;
bool native_ready;

i64 native_rd8(i64 a) { char^ p = (char^)a; return p[0] & 255; }
i64 native_rd16(i64 a) { return native_rd8(a) | (native_rd8(a + 1) << 8); }
i64 native_rd32(i64 a) { return native_rd16(a) | (native_rd16(a + 2) << 16); }
i64 native_rd64(i64 a) { return native_rd32(a) | (native_rd32(a + 4) << 32); }

bool native_name_is(i64 a, String s) {
    for i in 0..s.len { if native_rd8(a + i) != (s[i] & 255) { return false; } }
    return native_rd8(a + s.len) == 0;
}

// the base address of a library in the maps of this process; 0 when it is not loaded
i64 native_base_of(String lib) {
    i64 fd = Sys::open_read("/proc/self/maps".c());
    if fd < 0 { return 0; }
    String t = "";
    char buf[4096];
    i64 n = Sys::read(fd, @buf, 4096);
    while n > 0 { for i in 0..n { t.push(buf[i]); } n = Sys::read(fd, @buf, 4096); }
    Sys::close(fd);
    String[] lines = t.split("\n");
    for i in 0..lines.len {
        String l = lines[i];
        if l.ends_with(lib) {
            i64 dash = l.find("-");
            String hex = l.slice(0, dash);
            i64 v = 0;
            for k in 0..hex.len {
                i64 c = hex[k] & 255;
                i64 d = 0;
                if c >= 48 && c <= 57 { d = c - 48; } else { d = c - 87; }
                v = v * 16 + d;
            }
            return v;
        }
    }
    return 0;
}

// the address of a function that a loaded library exports (its dynamic section and symbol table are read from memory)
i64 native_sym_in(i64 base, String name) {
    i64 phoff = native_rd64(base + 32);
    i64 phnum = native_rd16(base + 56);
    i64 phsz = native_rd16(base + 54);
    i64 dyn = 0;
    for i in 0..phnum {
        i64 ph = base + phoff + i * phsz;
        if native_rd32(ph) == 2 { dyn = base + native_rd64(ph + 16); }
    }
    if dyn == 0 { return 0; }
    i64 strtab = 0;
    i64 symtab = 0;
    i64 k = 0;
    while native_rd64(dyn + k * 16) != 0 {
        i64 tag = native_rd64(dyn + k * 16);
        i64 val = native_rd64(dyn + k * 16 + 8);
        if val < base { val = val + base; }
        if tag == 5 { strtab = val; }
        if tag == 6 { symtab = val; }
        k += 1;
    }
    if strtab == 0 || symtab == 0 { return 0; }
    i64 nsyms = (strtab - symtab) / 24;
    if nsyms <= 0 || nsyms > 100000 { nsyms = 4000; }
    for i in 0..nsyms {
        i64 s = symtab + i * 24;
        i64 nm = native_rd32(s);
        if native_rd64(s + 8) != 0 && native_name_is(strtab + nm, name) { return base + native_rd64(s + 8); }
    }
    return 0;
}

bool native_start() {
    if native_ready { return native_dlopen != 0; }
    native_ready = true;
    i64 base = native_base_of("libdl.so");
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
naked i64 native_call9(i64 fn, i64 a1, i64 a2, i64 a3, i64 a4, i64 a5, i64 a6, i64^ blk) {
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
naked void native_cf1(i64 fn, i64 a) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("fmov", s0, w1);
    Cpu::inst("br", x16);
}
naked void native_cf2(i64 fn, i64 a, i64 b) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("fmov", s0, w1);
    Cpu::inst("fmov", s1, w2);
    Cpu::inst("br", x16);
}
naked void native_cf3(i64 fn, i64 a, i64 b, i64 c) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("fmov", s0, w1);
    Cpu::inst("fmov", s1, w2);
    Cpu::inst("fmov", s2, w3);
    Cpu::inst("br", x16);
}
naked void native_cf4(i64 fn, i64 a, i64 b, i64 c, i64 d) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("fmov", s0, w1);
    Cpu::inst("fmov", s1, w2);
    Cpu::inst("fmov", s2, w3);
    Cpu::inst("fmov", s3, w4);
    Cpu::inst("br", x16);
}
// an integer argument first (x0), then floats (s0 ...)
naked void native_cif1(i64 fn, i64 a, i64 x) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("mov", x0, x1);
    Cpu::inst("fmov", s0, w2);
    Cpu::inst("br", x16);
}
naked void native_cif2(i64 fn, i64 a, i64 x, i64 y) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("mov", x0, x1);
    Cpu::inst("fmov", s0, w2);
    Cpu::inst("fmov", s1, w3);
    Cpu::inst("br", x16);
}
naked void native_cif3(i64 fn, i64 a, i64 x, i64 y, i64 z) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("mov", x0, x1);
    Cpu::inst("fmov", s0, w2);
    Cpu::inst("fmov", s1, w3);
    Cpu::inst("fmov", s2, w4);
    Cpu::inst("br", x16);
}
naked void native_cif4(i64 fn, i64 a, i64 x, i64 y, i64 z, i64 w) {
    Cpu::inst("mov", x16, x0);
    Cpu::inst("mov", x0, x1);
    Cpu::inst("fmov", s0, w2);
    Cpu::inst("fmov", s1, w3);
    Cpu::inst("fmov", s2, w4);
    Cpu::inst("fmov", s3, w5);
    Cpu::inst("br", x16);
}

// the 32 bits of a float (J2K keeps the bits in an integer register, but a float cannot be given to a parameter of a naked function)
i64 native_fbits(float x) {
    float t = x;
    char^ p = (char^)@t;
    return (p[0] & 255) | ((p[1] & 255) << 8) | ((p[2] & 255) << 16) | ((p[3] & 255) << 24);
}

struct Native {
    // the handle of a library (0: not found, or this program cannot load libraries: build it with jcmp -dyn)
    static i64 open(String lib) {
        if !native_start() { return 0; }
        i64(i64, i64)^ f = (i64(i64, i64)^)native_dlopen;
        return f((i64)lib.c(), 2);                       // RTLD_NOW
    }
    // the address of a function (0 when there is none)
    static i64 sym(i64 handle, String name) {
        if !native_start() || handle == 0 { return 0; }
        i64(i64, i64)^ f = (i64(i64, i64)^)native_dlsym;
        return f(handle, (i64)name.c());
    }
    static i64 call0(i64 fn) { i64()^ f = (i64()^)fn; return f(); }
    static i64 call1(i64 fn, i64 a) { i64(i64)^ f = (i64(i64)^)fn; return f(a); }
    static i64 call2(i64 fn, i64 a, i64 b) { i64(i64, i64)^ f = (i64(i64, i64)^)fn; return f(a, b); }
    static i64 call3(i64 fn, i64 a, i64 b, i64 c) { i64(i64, i64, i64)^ f = (i64(i64, i64, i64)^)fn; return f(a, b, c); }
    static i64 call4(i64 fn, i64 a, i64 b, i64 c, i64 d) { i64(i64, i64, i64, i64)^ f = (i64(i64, i64, i64, i64)^)fn; return f(a, b, c, d); }
    static i64 call5(i64 fn, i64 a, i64 b, i64 c, i64 d, i64 e) { i64(i64, i64, i64, i64, i64)^ f = (i64(i64, i64, i64, i64, i64)^)fn; return f(a, b, c, d, e); }
    static i64 call6(i64 fn, i64 a, i64 b, i64 c, i64 d, i64 e, i64 g) { i64(i64, i64, i64, i64, i64, i64)^ f = (i64(i64, i64, i64, i64, i64, i64)^)fn; return f(a, b, c, d, e, g); }
    static i64 call7(i64 fn, i64 a, i64 b, i64 c, i64 d, i64 e, i64 g, i64 h) { i64(i64, i64, i64, i64, i64, i64, i64)^ f = (i64(i64, i64, i64, i64, i64, i64, i64)^)fn; return f(a, b, c, d, e, g, h); }
    static i64 call8(i64 fn, i64 a, i64 b, i64 c, i64 d, i64 e, i64 g, i64 h, i64 i) { i64(i64, i64, i64, i64, i64, i64, i64, i64)^ f = (i64(i64, i64, i64, i64, i64, i64, i64, i64)^)fn; return f(a, b, c, d, e, g, h, i); }
    // nine integer or pointer arguments (glTexImage2D, glTexSubImage2D)
    static i64 call9(i64 fn, i64 a, i64 b, i64 c, i64 d, i64 e, i64 g, i64 h, i64 i, i64 j) {
        i64 blk[3];
        blk[0] = h;
        blk[1] = i;
        blk[2] = j;
        return native_call9(fn, a, b, c, d, e, g, @blk[0]);
    }
    // float arguments (OpenGL: glClearColor, glUniform4f ...); the result is dropped
    static void callf1(i64 fn, float a) { native_cf1(fn, native_fbits(a)); }
    static void callf2(i64 fn, float a, float b) { native_cf2(fn, native_fbits(a), native_fbits(b)); }
    static void callf3(i64 fn, float a, float b, float c) { native_cf3(fn, native_fbits(a), native_fbits(b), native_fbits(c)); }
    static void callf4(i64 fn, float a, float b, float c, float d) { native_cf4(fn, native_fbits(a), native_fbits(b), native_fbits(c), native_fbits(d)); }
    // an integer argument first, then floats (OpenGL: glUniform1f(location, x) ...)
    static void calli_f1(i64 fn, i64 a, float x) { native_cif1(fn, a, native_fbits(x)); }
    static void calli_f2(i64 fn, i64 a, float x, float y) { native_cif2(fn, a, native_fbits(x), native_fbits(y)); }
    static void calli_f3(i64 fn, i64 a, float x, float y, float z) { native_cif3(fn, a, native_fbits(x), native_fbits(y), native_fbits(z)); }
    static void calli_f4(i64 fn, i64 a, float x, float y, float z, float w) { native_cif4(fn, a, native_fbits(x), native_fbits(y), native_fbits(z), native_fbits(w)); }
    // the text (a C string ending with 0) at an address
    static String text(i64 a) { String r = ""; r.append((char^)a); return r; }
    // the memory of the process
    static i64 peek8(i64 a) { return native_rd8(a); }
    static i64 peek32(i64 a) { return native_rd32(a); }
    static i64 peek64(i64 a) { return native_rd64(a); }
    static void poke32(i64 a, i64 v) { char^ p = (char^)a; p[0] = (char)(v & 255); p[1] = (char)((v >> 8) & 255); p[2] = (char)((v >> 16) & 255); p[3] = (char)((v >> 24) & 255); }
    static void poke64(i64 a, i64 v) { Native::poke32(a, v & 4294967295); Native::poke32(a + 4, (v >> 32) & 4294967295); }
}
