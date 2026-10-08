// The prelude: read in front of every program (unused functions are left out).
// Mem: a small heap. Every block has a 16-byte header: [size, next-free].
int std_heap_cur;
int std_heap_end;
int std_free_list;
int std_alloc_n;                  // blocks given out / given back (the -d build reports the difference at the end)
int std_free_n;

struct Mem {
    // n bytes, not cleared (null if the system has no memory left)
    static void^ alloc(int n) {
        if n <= 0 { return null; }
        int need = (n + 15) / 16 * 16 + 16;
        int prev = 0;
        int cur = std_free_list;
        while cur != 0 {
            int^ hdr = (int^)cur;
            if hdr[0] >= need {
                if prev == 0 {
                    std_free_list = hdr[1];
                } else {
                    int^ before = (int^)prev;
                    before[1] = hdr[1];
                }
                std_alloc_n += 1;
                return (void^)(cur + 16);
            }
            prev = cur;
            cur = hdr[1];
        }
        if std_heap_cur + need > std_heap_end {
            int chunk = 1048576;
            if need > chunk { chunk = (need + 4095) / 4096 * 4096; }
            int base = syscall(222, 0, chunk, 3, 34, -1, 0);      // mmap: anonymous, read + write
            if base < 0 { return null; }
            std_heap_cur = base;
            std_heap_end = base + chunk;
        }
        int blk = std_heap_cur;
        std_heap_cur = std_heap_cur + need;
        std_alloc_n += 1;
        int^ head = (int^)blk;
        head[0] = need;
        return (void^)(blk + 16);
    }
    // give a block from alloc back (null is ignored)
    static void free(void^ p) {
        if (int)p == 0 { return; }
        int blk = (int)p - 16;
        int^ head = (int^)blk;
        head[1] = std_free_list;
        std_free_list = blk;
        std_free_n += 1;
    }
    // -d : at the end of main, say how many blocks were never given back
    static void report() {
        int n = std_alloc_n - std_free_n;
        if n <= 0 { return; }
        char d[24];
        int k = 23;
        d[k] = 10;
        while n > 0 {
            k -= 1;
            d[k] = '0' + n % 10;
            n = n / 10;
        }
        syscall(64, 2, "debug: memory blocks never freed: ", 34);
        syscall(64, 2, @d + k, 24 - k);
    }
    static void set(void^ p, int value, int n) {
        char^ q = (char^)p;
        int i = 0;
        while i < n {
            q[i] = value;
            i += 1;
        }
    }
    static void copy(void^ dst, void^ src, int n) {
        char^ d = (char^)dst;
        char^ s = (char^)src;
        int i = 0;
        while i < n {
            d[i] = s[i];
            i += 1;
        }
    }
}

// Dynamic arrays (T[] x = arr(n)): a header [length, capacity, data, element size]
// points to the elements. The header stays where it is, so every copy of the
// variable sees the same array; only the data block moves when it grows.
struct __Arr {
    static void nullerr() {
        throw "the dynamic array is null";
    }
    static void^ make(int esize, int cap) {
        int^ h = (int^)Mem::alloc(32);
        if (int)h == 0 { throw "out of memory"; }
        int c = cap;
        if c < 4 { c = 4; }
        h[0] = 0;
        h[1] = c;
        h[2] = (int)Mem::alloc(c * esize);
        h[3] = esize;
        if h[2] == 0 { throw "out of memory"; }
        return (void^)h;
    }
    // room for at least `need` elements
    static void grow(int^ h, int need) {
        if need <= h[1] { return; }
        int c = h[1] * 2;
        if c < need { c = need; }
        int nd = (int)Mem::alloc(c * h[3]);
        if nd == 0 { throw "out of memory"; }
        Mem::copy((void^)nd, (void^)h[2], h[0] * h[3]);
        Mem::free((void^)h[2]);
        h[2] = nd;
        h[1] = c;
    }
    // append one element: returns the address of its (new) place
    static void^ slot(void^ hv) {
        int^ h = (int^)hv;
        if (int)h == 0 { throw "the dynamic array is null"; }
        __Arr::grow(h, h[0] + 1);
        int at = h[2] + h[0] * h[3];
        h[0] += 1;
        return (void^)at;
    }
    // remove the last element: returns the address where it still is
    static void^ pop(void^ hv) {
        int^ h = (int^)hv;
        if (int)h == 0 { throw "the dynamic array is null"; }
        if h[0] == 0 { throw "pop from an empty array"; }
        h[0] -= 1;
        return (void^)(h[2] + h[0] * h[3]);
    }
    static void resize(void^ hv, int n) {
        int^ h = (int^)hv;
        if (int)h == 0 { throw "the dynamic array is null"; }
        if n < 0 { throw "negative array size"; }
        __Arr::grow(h, n);
        if n > h[0] { Mem::set((void^)(h[2] + h[0] * h[3]), 0, (n - h[0]) * h[3]); }
        h[0] = n;
    }
    // give the elements and the header back (null is ignored)
    static void free(void^ hv) {
        int^ h = (int^)hv;
        if (int)h == 0 { return; }
        Mem::free((void^)h[2]);
        Mem::free(hv);
    }
}
