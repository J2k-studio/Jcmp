// Dynamic arrays (T[] x = arr(n)): a header [length, capacity, data, element size]
// points to the elements. The header stays where it is, so every copy of the
// variable sees the same array; only the data block moves when it grows.
struct __Arr {
    static void nullerr() {
        __panic("the dynamic array is null");
    }
    // The first data block is part of the block of the header (the data starts 32 bytes after it): one allocation for a new array.
    // When the array grows the data moves to a block of its own; `h[2] == h + 32` tells which one it is.
    static void^ make(i64 esize, i64 cap) {
        i64 c = cap;
        if c < 4 { c = 4; }
        i64 hv = (i64)Mem::alloc(32 + c * esize);         // a plain number, not a pointer variable: no cleanup record for it
        if hv == 0 { __panic("out of memory"); }
        i64^ h = (i64^)hv;
        h[0] = 0;
        h[1] = c;
        h[2] = hv + 32;
        h[3] = esize;
        return (void^)hv;
    }
    // room for at least `need` elements
    static void grow(i64^ h, i64 need) {
        if need <= h[1] { return; }
        i64 c = h[1] * 2;
        if c < need { c = need; }
        i64 nd = (i64)Mem::alloc(c * h[3]);
        if nd == 0 { __panic("out of memory"); }
        Mem::copy((void^)nd, (void^)h[2], h[0] * h[3]);
        if h[2] != (i64)h + 32 { Mem::free((void^)h[2]); }
        h[2] = nd;
        h[1] = c;
    }
    // append one element: returns the address of its (new) place
    static void^ slot(void^ hv) {
        i64^ h = (i64^)hv;
        if (i64)h == 0 { __panic("the dynamic array is null"); }
        __Arr::grow(h, h[0] + 1);
        i64 at = h[2] + h[0] * h[3];
        h[0] += 1;
        return (void^)at;
    }
    // remove the last element: returns the address where it still is
    static void^ pop(void^ hv) {
        i64^ h = (i64^)hv;
        if (i64)h == 0 { __panic("the dynamic array is null"); }
        if h[0] == 0 { __panic("pop from an empty array"); }
        h[0] -= 1;
        return (void^)(h[2] + h[0] * h[3]);
    }
    static void resize(void^ hv, i64 n) {
        i64^ h = (i64^)hv;
        if (i64)h == 0 { __panic("the dynamic array is null"); }
        if n < 0 { __panic("negative array size"); }
        __Arr::grow(h, n);
        if n > h[0] { Mem::set((void^)(h[2] + h[0] * h[3]), 0, (n - h[0]) * h[3]); }
        h[0] = n;
    }
    // ---- numbers in an array: kind 0 signed, 1 unsigned (also pointers), 2 float, 3 double
    // the bits of element i as a whole number (sign or zero extended; the IEEE bits for a float)
    static i64 get(i64^ h, i64 i, i64 kind) {
        char^ d = (char^)(h[2] + i * h[3]);
        i64 es = h[3];
        i64 v = 0;
        i64 k = es - 1;
        while k >= 0 {
            v = v * 256 + d[k];
            k -= 1;
        }
        if kind == 0 && es < 8 {
            i64 sh = 64 - es * 8;
            v = (v shl sh) shr sh;
        }
        return v;
    }
    static void put(i64^ h, i64 i, i64 bits) {
        char^ d = (char^)(h[2] + i * h[3]);
        i64 k = 0;
        while k < h[3] {
            d[k] = bits & 255;
            bits = bits shr 8;
            k += 1;
        }
    }
    // a before b ?
    static bool less(i64 a, i64 b, i64 kind) {
        if kind == 0 { return a < b; }
        if kind == 1 { return (a xor -9223372036854775807 - 1) < (b xor -9223372036854775807 - 1); }
        if kind == 2 {
            i64 x = a;
            i64 y = b;
            float^ fx = (float^)@x;
            float^ fy = (float^)@y;
            return fx[0] < fy[0];
        }
        i64 x2 = a;
        i64 y2 = b;
        double^ dx = (double^)@x2;
        double^ dy = (double^)@y2;
        return dx[0] < dy[0];
    }
    static void insert(void^ hv, i64 i, i64 bits) {
        if (i64)hv == 0 { __panic("the dynamic array is null"); }
        i64^ h = (i64^)hv;
        if i < 0 || i > h[0] { __panic("insert position out of range"); }
        __Arr::grow(h, h[0] + 1);
        i64 k = h[0];
        while k > i {
            __Arr::put(h, k, __Arr::get(h, k - 1, 1));
            k -= 1;
        }
        __Arr::put(h, i, bits);
        h[0] += 1;
    }
    static void remove(void^ hv, i64 i) {
        if (i64)hv == 0 { __panic("the dynamic array is null"); }
        i64^ h = (i64^)hv;
        if i < 0 || i >= h[0] { __panic("remove position out of range"); }
        i64 k = i;
        while k + 1 < h[0] {
            __Arr::put(h, k, __Arr::get(h, k + 1, 1));
            k += 1;
        }
        h[0] -= 1;
    }
    // the place of the first element equal to bits, or -1
    static i64 index(void^ hv, i64 bits, i64 kind) {
        if (i64)hv == 0 { __panic("the dynamic array is null"); }
        i64^ h = (i64^)hv;
        i64 i = 0;
        while i < h[0] {
            i64 e = __Arr::get(h, i, kind);
            if !__Arr::less(e, bits, kind) && !__Arr::less(bits, e, kind) { return i; }
            i += 1;
        }
        return 0 - 1;
    }
    static void sort(void^ hv, i64 kind) {
        if (i64)hv == 0 { __panic("the dynamic array is null"); }
        i64^ h = (i64^)hv;
        i64 n = h[0];
        i64 start = n / 2 - 1;
        while start >= 0 {
            __Arr::sift(h, start, n, kind);
            start -= 1;
        }
        i64 end = n - 1;
        while end > 0 {
            i64 t = __Arr::get(h, 0, kind);
            __Arr::put(h, 0, __Arr::get(h, end, kind));
            __Arr::put(h, end, t);
            __Arr::sift(h, 0, end, kind);
            end -= 1;
        }
    }
    static void sift(i64^ h, i64 root, i64 n, i64 kind) {
        while true {
            i64 child = root * 2 + 1;
            if child >= n { return; }
            if child + 1 < n && __Arr::less(__Arr::get(h, child, kind), __Arr::get(h, child + 1, kind), kind) { child += 1; }
            i64 a = __Arr::get(h, root, kind);
            i64 b = __Arr::get(h, child, kind);
            if !__Arr::less(a, b, kind) { return; }
            __Arr::put(h, root, b);
            __Arr::put(h, child, a);
            root = child;
        }
    }
    // a copy of an array of numbers / pointers
    static void^ clone(void^ hv) {
        if (i64)hv == 0 { __panic("the dynamic array is null"); }
        i64^ h = (i64^)hv;
        i64^ r = (i64^)__Arr::make(h[3], h[0]);
        Mem::copy((void^)r[2], (void^)h[2], h[0] * h[3]);
        r[0] = h[0];
        return (void^)r;
    }
    // a copy of an array whose elements own memory: the elements move to the copy, the old array is empty afterwards
    static void^ clone_move(void^ hv) {
        void^ r = __Arr::clone(hv);
        i64^ h = (i64^)hv;
        h[0] = 0;
        return r;
    }
    // every element is freed with f (a struct that frees itself), then the array
    static void free_each(void^ hv, void(void^)^ f) {
        i64^ h = (i64^)hv;
        if (i64)h == 0 { return; }
        i64 i = 0;
        while i < h[0] {
            f((void^)(h[2] + i * h[3]));
            i += 1;
        }
        __Arr::free(hv);
    }
    // give the elements and the header back (null is ignored)
    static void free(void^ hv) {
        i64^ h = (i64^)hv;
        if (i64)h == 0 { return; }
        if h[2] != (i64)h + 32 { Mem::free((void^)h[2]); }
        Mem::free(hv);
    }
}

