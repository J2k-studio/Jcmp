// Dynamic arrays (T[] x = arr(n)): a header [length, capacity, data, element size]
// points to the elements. The header stays where it is, so every copy of the
// variable sees the same array; only the data block moves when it grows.
struct __Arr {
    static void nullerr() {
        __panic("the dynamic array is null");
    }
    // The first data block is part of the block of the header (the data starts 32 bytes after it): one allocation for a new array.
    // When the array grows the data moves to a block of its own; `h[2] == h + 32` tells which one it is.
    static void^ make(int esize, int cap) {
        int c = cap;
        if c < 4 { c = 4; }
        int^ h = (int^)Mem::alloc(32 + c * esize);
        if (int)h == 0 { __panic("out of memory"); }
        h[0] = 0;
        h[1] = c;
        h[2] = (int)h + 32;
        h[3] = esize;
        return (void^)h;
    }
    // room for at least `need` elements
    static void grow(int^ h, int need) {
        if need <= h[1] { return; }
        int c = h[1] * 2;
        if c < need { c = need; }
        int nd = (int)Mem::alloc(c * h[3]);
        if nd == 0 { __panic("out of memory"); }
        Mem::copy((void^)nd, (void^)h[2], h[0] * h[3]);
        if h[2] != (int)h + 32 { Mem::free((void^)h[2]); }
        h[2] = nd;
        h[1] = c;
    }
    // append one element: returns the address of its (new) place
    static void^ slot(void^ hv) {
        int^ h = (int^)hv;
        if (int)h == 0 { __panic("the dynamic array is null"); }
        __Arr::grow(h, h[0] + 1);
        int at = h[2] + h[0] * h[3];
        h[0] += 1;
        return (void^)at;
    }
    // remove the last element: returns the address where it still is
    static void^ pop(void^ hv) {
        int^ h = (int^)hv;
        if (int)h == 0 { __panic("the dynamic array is null"); }
        if h[0] == 0 { __panic("pop from an empty array"); }
        h[0] -= 1;
        return (void^)(h[2] + h[0] * h[3]);
    }
    static void resize(void^ hv, int n) {
        int^ h = (int^)hv;
        if (int)h == 0 { __panic("the dynamic array is null"); }
        if n < 0 { __panic("negative array size"); }
        __Arr::grow(h, n);
        if n > h[0] { Mem::set((void^)(h[2] + h[0] * h[3]), 0, (n - h[0]) * h[3]); }
        h[0] = n;
    }
    // ---- numbers in an array: kind 0 signed, 1 unsigned (also pointers), 2 float, 3 double
    // the bits of element i as a whole number (sign or zero extended; the IEEE bits for a float)
    static int get(int^ h, int i, int kind) {
        char^ d = (char^)(h[2] + i * h[3]);
        int es = h[3];
        int v = 0;
        int k = es - 1;
        while k >= 0 {
            v = v * 256 + d[k];
            k -= 1;
        }
        if kind == 0 && es < 8 {
            int sh = 64 - es * 8;
            v = (v shl sh) shr sh;
        }
        return v;
    }
    static void put(int^ h, int i, int bits) {
        char^ d = (char^)(h[2] + i * h[3]);
        int k = 0;
        while k < h[3] {
            d[k] = bits & 255;
            bits = bits shr 8;
            k += 1;
        }
    }
    // a before b ?
    static bool less(int a, int b, int kind) {
        if kind == 0 { return a < b; }
        if kind == 1 { return (a xor -9223372036854775807 - 1) < (b xor -9223372036854775807 - 1); }
        if kind == 2 {
            int x = a;
            int y = b;
            float^ fx = (float^)@x;
            float^ fy = (float^)@y;
            return fx[0] < fy[0];
        }
        int x2 = a;
        int y2 = b;
        double^ dx = (double^)@x2;
        double^ dy = (double^)@y2;
        return dx[0] < dy[0];
    }
    static void insert(void^ hv, int i, int bits) {
        if (int)hv == 0 { __panic("the dynamic array is null"); }
        int^ h = (int^)hv;
        if i < 0 || i > h[0] { __panic("insert position out of range"); }
        __Arr::grow(h, h[0] + 1);
        int k = h[0];
        while k > i {
            __Arr::put(h, k, __Arr::get(h, k - 1, 1));
            k -= 1;
        }
        __Arr::put(h, i, bits);
        h[0] += 1;
    }
    static void remove(void^ hv, int i) {
        if (int)hv == 0 { __panic("the dynamic array is null"); }
        int^ h = (int^)hv;
        if i < 0 || i >= h[0] { __panic("remove position out of range"); }
        int k = i;
        while k + 1 < h[0] {
            __Arr::put(h, k, __Arr::get(h, k + 1, 1));
            k += 1;
        }
        h[0] -= 1;
    }
    // the place of the first element equal to bits, or -1
    static int index(void^ hv, int bits, int kind) {
        if (int)hv == 0 { __panic("the dynamic array is null"); }
        int^ h = (int^)hv;
        int i = 0;
        while i < h[0] {
            int e = __Arr::get(h, i, kind);
            if !__Arr::less(e, bits, kind) && !__Arr::less(bits, e, kind) { return i; }
            i += 1;
        }
        return 0 - 1;
    }
    static void sort(void^ hv, int kind) {
        if (int)hv == 0 { __panic("the dynamic array is null"); }
        int^ h = (int^)hv;
        int n = h[0];
        int start = n / 2 - 1;
        while start >= 0 {
            __Arr::sift(h, start, n, kind);
            start -= 1;
        }
        int end = n - 1;
        while end > 0 {
            int t = __Arr::get(h, 0, kind);
            __Arr::put(h, 0, __Arr::get(h, end, kind));
            __Arr::put(h, end, t);
            __Arr::sift(h, 0, end, kind);
            end -= 1;
        }
    }
    static void sift(int^ h, int root, int n, int kind) {
        while true {
            int child = root * 2 + 1;
            if child >= n { return; }
            if child + 1 < n && __Arr::less(__Arr::get(h, child, kind), __Arr::get(h, child + 1, kind), kind) { child += 1; }
            int a = __Arr::get(h, root, kind);
            int b = __Arr::get(h, child, kind);
            if !__Arr::less(a, b, kind) { return; }
            __Arr::put(h, root, b);
            __Arr::put(h, child, a);
            root = child;
        }
    }
    // a copy of an array of numbers / pointers
    static void^ clone(void^ hv) {
        if (int)hv == 0 { __panic("the dynamic array is null"); }
        int^ h = (int^)hv;
        int^ r = (int^)__Arr::make(h[3], h[0]);
        Mem::copy((void^)r[2], (void^)h[2], h[0] * h[3]);
        r[0] = h[0];
        return (void^)r;
    }
    // a copy of an array whose elements own memory: the elements move to the copy, the old array is empty afterwards
    static void^ clone_move(void^ hv) {
        void^ r = __Arr::clone(hv);
        int^ h = (int^)hv;
        h[0] = 0;
        return r;
    }
    // every element is freed with f (a struct that frees itself), then the array
    static void free_each(void^ hv, void(void^)^ f) {
        int^ h = (int^)hv;
        if (int)h == 0 { return; }
        int i = 0;
        while i < h[0] {
            f((void^)(h[2] + i * h[3]));
            i += 1;
        }
        __Arr::free(hv);
    }
    // give the elements and the header back (null is ignored)
    static void free(void^ hv) {
        int^ h = (int^)hv;
        if (int)h == 0 { return; }
        if h[2] != (int)h + 32 { Mem::free((void^)h[2]); }
        Mem::free(hv);
    }
}

