// The prelude: read in front of every program (unused functions are left out).
// Mem: a small heap. Every block has a 16-byte header: [size, next-free].
int std_heap_cur;
int std_heap_end;
int std_free_list;
int std_mem_lock;                 // 0 free, 1 taken (threads share the heap)
int std_alloc_n;                  // blocks given out / given back (the -d build reports the difference at the end)
int std_free_n;

struct Mem {
    static void lock_heap() {
        while __cas(@std_mem_lock, 0, 1) != 0 {
            syscall(124);                  // sched_yield: let the thread that holds the heap finish
        }
    }
    static void unlock_heap() {
        __xchg(@std_mem_lock, 0);
    }
    // n bytes, not cleared (null if the system has no memory left)
    static void^ alloc(int n) {
        Mem::lock_heap();
        void^ r = Mem::alloc_raw(n);
        Mem::unlock_heap();
        return r;
    }
    static void^ alloc_raw(int n) {
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
        Mem::lock_heap();
        Mem::free_raw(p);
        Mem::unlock_heap();
    }
    static void free_raw(void^ p) {
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
        if (int)hv == 0 { throw "the dynamic array is null"; }
        int^ h = (int^)hv;
        if i < 0 || i > h[0] { throw "insert position out of range"; }
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
        if (int)hv == 0 { throw "the dynamic array is null"; }
        int^ h = (int^)hv;
        if i < 0 || i >= h[0] { throw "remove position out of range"; }
        int k = i;
        while k + 1 < h[0] {
            __Arr::put(h, k, __Arr::get(h, k + 1, 1));
            k += 1;
        }
        h[0] -= 1;
    }
    // the place of the first element equal to bits, or -1
    static int index(void^ hv, int bits, int kind) {
        if (int)hv == 0 { throw "the dynamic array is null"; }
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
        if (int)hv == 0 { throw "the dynamic array is null"; }
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
    // give the elements and the header back (null is ignored)
    static void free(void^ hv) {
        int^ h = (int^)hv;
        if (int)h == 0 { return; }
        Mem::free((void^)h[2]);
        Mem::free(hv);
    }
}

// String: a dynamic array of char (header [length, capacity, data, 1]) whose data always ends
// in a 0 byte after the length, so that the data is also a C-style text (cout, c()).
// An operand is a text (kind 0), another String (kind 1) or one character (kind 2).
char std_str_ch[16];
struct __Str {
    static void^ make(int cap) {
        int^ h = (int^)__Arr::make(1, cap + 1);
        char^ d = (char^)h[2];
        d[0] = 0;
        return (void^)h;
    }
    static int textlen(char^ t) {
        int n = 0;
        while t[n] != 0 { n += 1; }
        return n;
    }
    static void check(void^ hv) {
        if (int)hv == 0 { throw "the String is null"; }
    }
    // the characters of an operand
    static char^ ptr(void^ x, int k, int slot) {
        if k == 1 {
            __Str::check(x);
            int^ h = (int^)x;
            return (char^)h[2];
        }
        if k == 2 {
            std_str_ch[slot * 8] = (int)x;
            std_str_ch[slot * 8 + 1] = 0;
            return @std_str_ch + slot * 8;
        }
        return (char^)x;
    }
    static int len(void^ x, int k) {
        if k == 1 {
            __Str::check(x);
            int^ h = (int^)x;
            return h[0];
        }
        if k == 2 { return 1; }
        return __Str::textlen((char^)x);
    }
    // a new String holding a copy of the text
    static void^ from(char^ t) {
        int n = __Str::textlen(t);
        int^ h = (int^)__Str::make(n);
        Mem::copy((void^)h[2], (void^)t, n);
        char^ d = (char^)h[2];
        d[n] = 0;
        h[0] = n;
        return (void^)h;
    }
    // a copy of a String
    static void^ clone(void^ x) {
        return __Str::cat(x, 1, (void^)"", 0);
    }
    // a new String: a followed by b
    static void^ cat(void^ a, int ka, void^ b, int kb) {
        int na = __Str::len(a, ka);
        int nb = __Str::len(b, kb);
        int^ h = (int^)__Str::make(na + nb);
        char^ d = (char^)h[2];
        Mem::copy((void^)d, (void^)__Str::ptr(a, ka, 0), na);
        Mem::copy((void^)(d + na), (void^)__Str::ptr(b, kb, 1), nb);
        d[na + nb] = 0;
        h[0] = na + nb;
        return (void^)h;
    }
    // a followed by b, in a (returns a)
    static void^ append(void^ a, void^ b, int kb) {
        __Str::check(a);
        if kb == 1 && (int)b == (int)a {                 // s.append(s): the data may move
            void^ same = __Str::clone(a);
            __Str::append(a, same, 1);
            __Arr::free(same);
            return a;
        }
        int^ h = (int^)a;
        int nb = __Str::len(b, kb);
        char^ src = __Str::ptr(b, kb, 1);
        __Arr::grow(h, h[0] + nb + 1);
        Mem::copy((void^)(h[2] + h[0]), (void^)src, nb);
        h[0] += nb;
        char^ d = (char^)h[2];
        d[h[0]] = 0;
        return a;
    }
    static void push(void^ a, int c) {
        __Str::check(a);
        int^ h = (int^)a;
        __Arr::grow(h, h[0] + 2);
        char^ d = (char^)h[2];
        d[h[0]] = c;
        h[0] += 1;
        d[h[0]] = 0;
    }
    static int pop(void^ a) {
        __Str::check(a);
        int^ h = (int^)a;
        if h[0] == 0 { throw "pop from an empty String"; }
        h[0] -= 1;
        char^ d = (char^)h[2];
        int c = d[h[0]];
        d[h[0]] = 0;
        return c;
    }
    static void clear(void^ a) {
        __Str::check(a);
        int^ h = (int^)a;
        h[0] = 0;
        char^ d = (char^)h[2];
        d[0] = 0;
    }
    // 1 if the two operands hold the same characters
    static int eq(void^ a, int ka, void^ b, int kb) {
        int na = __Str::len(a, ka);
        int nb = __Str::len(b, kb);
        if na != nb { return 0; }
        char^ pa = __Str::ptr(a, ka, 0);
        char^ pb = __Str::ptr(b, kb, 1);
        int i = 0;
        while i < na {
            if pa[i] != pb[i] { return 0; }
            i += 1;
        }
        return 1;
    }
    // the first place of t in s at or after `from`, or -1
    static int find(void^ s, void^ t, int kt) {
        int ns = __Str::len(s, 1);
        int nt = __Str::len(t, kt);
        char^ ps = __Str::ptr(s, 1, 0);
        char^ pt = __Str::ptr(t, kt, 1);
        int i = 0;
        while i + nt <= ns {
            int j = 0;
            while j < nt && ps[i + j] == pt[j] { j += 1; }
            if j == nt { return i; }
            i += 1;
        }
        return 0 - 1;
    }
    // a new String: the characters a .. b - 1
    static void^ slice(void^ s, int a, int b) {
        int n = __Str::len(s, 1);
        if a < 0 || b > n || a > b { throw "String slice out of range"; }
        int^ h = (int^)__Str::make(b - a);
        char^ d = (char^)h[2];
        char^ ps = __Str::ptr(s, 1, 0);
        Mem::copy((void^)d, (void^)(ps + a), b - a);
        d[b - a] = 0;
        h[0] = b - a;
        return (void^)h;
    }
    static char^ c(void^ s) {
        return __Str::ptr(s, 1, 0);
    }
    // hash of a whole number / of a String (FNV-1a over the bytes)
    static int hashint(int x) {
        int h = x * -7046029254386353131;
        return h xor (h shr 29);
    }
    static int hash(void^ s) {
        char^ p = __Str::ptr(s, 1, 0);
        int h = -3750763034362895579;
        int i = 0;
        while p[i] != 0 {
            h = (h xor p[i]) * 1099511628211;
            i += 1;
        }
        return h xor (h shr 29);
    }
    // String[]: n places (new ones are null, cut ones are freed)
    static void aresize(void^ hv, int n) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        if n < 0 { throw "negative array size"; }
        int^ el = (int^)h[2];
        int i = n;
        while i < h[0] {
            __Arr::free((void^)el[i]);
            i += 1;
        }
        __Arr::grow(h, n);
        el = (int^)h[2];
        i = h[0];
        while i < n {
            el[i] = 0;
            i += 1;
        }
        h[0] = n;
    }
    // -1, 0, 1: a before, equal to, after b (bytes)
    static int cmp(void^ a, void^ b) {
        char^ pa = __Str::ptr(a, 1, 0);
        char^ pb = __Str::ptr(b, 1, 1);
        int i = 0;
        while pa[i] != 0 && pa[i] == pb[i] { i += 1; }
        if pa[i] == pb[i] { return 0; }
        if pa[i] < pb[i] { return 0 - 1; }
        return 1;
    }

    // ---- String[] : an array whose elements are String headers owned by the array
    static void aprep(void^ hv) {
        if (int)hv == 0 { throw "the array is null"; }
    }
    // the elements and the array are given back
    static void free_all(void^ hv) {
        int^ h = (int^)hv;
        if (int)h == 0 { return; }
        int^ el = (int^)h[2];
        int i = 0;
        while i < h[0] {
            __Arr::free((void^)el[i]);
            i += 1;
        }
        __Arr::free(hv);
    }
    static void clear_all(void^ hv) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        int^ el = (int^)h[2];
        int i = 0;
        while i < h[0] {
            __Arr::free((void^)el[i]);
            i += 1;
        }
        h[0] = 0;
    }
    // append s (the array takes it over)
    static void apush(void^ hv, void^ s) {
        __Str::aprep(hv);
        int^ slot = (int^)__Arr::slot(hv);
        slot[0] = (int)s;
    }
    // remove the last one and give it to the caller
    static void^ apop(void^ hv) {
        __Str::aprep(hv);
        int^ slot = (int^)__Arr::pop(hv);
        return (void^)slot[0];
    }
    // put s (taken over) at place i
    static void ainsert(void^ hv, int i, void^ s) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        if i < 0 || i > h[0] { throw "insert position out of range"; }
        __Arr::grow(h, h[0] + 1);
        int^ el = (int^)h[2];
        int k = h[0];
        while k > i {
            el[k] = el[k - 1];
            k -= 1;
        }
        el[i] = (int)s;
        h[0] += 1;
    }
    // remove the one at place i (it is freed)
    static void aremove(void^ hv, int i) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        if i < 0 || i >= h[0] { throw "remove position out of range"; }
        int^ el = (int^)h[2];
        __Arr::free((void^)el[i]);
        int k = i;
        while k + 1 < h[0] {
            el[k] = el[k + 1];
            k += 1;
        }
        h[0] -= 1;
    }
    // the place of the first element equal to the operand, or -1
    static int aindex(void^ hv, void^ x, int kx) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        int^ el = (int^)h[2];
        int i = 0;
        while i < h[0] {
            if __Str::eq((void^)el[i], 1, x, kx) == 1 { return i; }
            i += 1;
        }
        return 0 - 1;
    }
    // sort ascending (heap sort, no extra memory)
    static void asort(void^ hv) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        int^ el = (int^)h[2];
        int n = h[0];
        int start = n / 2 - 1;
        while start >= 0 {
            __Str::asift(el, start, n);
            start -= 1;
        }
        int end = n - 1;
        while end > 0 {
            int t = el[0];
            el[0] = el[end];
            el[end] = t;
            __Str::asift(el, 0, end);
            end -= 1;
        }
    }
    static void asift(int^ el, int root, int n) {
        while true {
            int child = root * 2 + 1;
            if child >= n { return; }
            if child + 1 < n && __Str::cmp((void^)el[child], (void^)el[child + 1]) < 0 { child += 1; }
            if __Str::cmp((void^)el[root], (void^)el[child]) >= 0 { return; }
            int t = el[root];
            el[root] = el[child];
            el[child] = t;
            root = child;
        }
    }
}

// Reading the keyboard (cin >> x, cinf >> x): a buffer over file descriptor 0.
char std_in_buf[4096];
int std_in_pos;
int std_in_len;

struct __In {
    // the next byte without taking it, or -1 at the end of the input
    static int peek() {
        if std_in_pos >= std_in_len {
            int n = syscall(63, 0, @std_in_buf, 4096);
            if n <= 0 { return -1; }
            std_in_len = n;
            std_in_pos = 0;
        }
        return std_in_buf[std_in_pos];
    }
    static bool space(int c) {
        return c == 32 || c == 9 || c == 10 || c == 13;
    }
    // skip white space: the first character of the next word, or -1
    static int start() {
        int c = __In::peek();
        while c >= 0 && __In::space(c) {
            std_in_pos += 1;
            c = __In::peek();
        }
        return c;
    }
    // a word into a String
    static void str(void^ h) {
        int c = __In::start();
        if c < 0 { throw "end of input"; }
        __Str::clear(h);
        while c >= 0 && !__In::space(c) {
            __Str::push(h, c);
            std_in_pos += 1;
            c = __In::peek();
        }
    }
    // a whole number (an error unless lo <= value <= hi; no limits when lo > hi; uns = 1: no minus sign)
    static int num(int lo, int hi, int uns) {
        int c = __In::start();
        if c < 0 { throw "end of input"; }
        int neg = 0;
        if c == '-' || c == '+' {
            if c == '-' { neg = 1; }
            std_in_pos += 1;
            c = __In::peek();
        }
        if c < '0' || c > '9' { throw "invalid input"; }
        if neg == 1 && uns == 1 { throw "invalid input"; }
        int v = 0;
        while c >= '0' && c <= '9' {
            v = v * 10 + (c - '0');
            std_in_pos += 1;
            c = __In::peek();
        }
        if c >= 0 && !__In::space(c) { throw "invalid input"; }
        if neg == 1 { v = 0 - v; }
        if lo <= hi && (v < lo || v > hi) { throw "number out of range"; }
        return v;
    }
    // a decimal number: 12  -3.5  .5  2e-3
    static double fnum() {
        int c = __In::start();
        if c < 0 { throw "end of input"; }
        int neg = 0;
        if c == '-' || c == '+' {
            if c == '-' { neg = 1; }
            std_in_pos += 1;
            c = __In::peek();
        }
        int mant = 0;
        int exp = 0;
        int seen = 0;
        while c >= '0' && c <= '9' {
            seen = 1;
            if mant < 100000000000000000 { mant = mant * 10 + (c - '0'); } else { exp += 1; }
            std_in_pos += 1;
            c = __In::peek();
        }
        if c == '.' {
            std_in_pos += 1;
            c = __In::peek();
            while c >= '0' && c <= '9' {
                seen = 1;
                if mant < 100000000000000000 {
                    mant = mant * 10 + (c - '0');
                    exp -= 1;
                }
                std_in_pos += 1;
                c = __In::peek();
            }
        }
        if seen == 0 { throw "invalid input"; }
        if c == 'e' || c == 'E' {
            std_in_pos += 1;
            c = __In::peek();
            int eneg = 0;
            if c == '-' || c == '+' {
                if c == '-' { eneg = 1; }
                std_in_pos += 1;
                c = __In::peek();
            }
            if c < '0' || c > '9' { throw "invalid input"; }
            int ev = 0;
            while c >= '0' && c <= '9' {
                if ev < 10000 { ev = ev * 10 + (c - '0'); }
                std_in_pos += 1;
                c = __In::peek();
            }
            if eneg == 1 { exp -= ev; } else { exp += ev; }
        }
        if c >= 0 && !__In::space(c) { throw "invalid input"; }
        double v = (double)mant;
        while exp > 0 {
            v = v * 10.0;
            exp -= 1;
        }
        while exp < 0 {
            v = v / 10.0;
            exp += 1;
        }
        if neg == 1 { v = -v; }
        return v;
    }
    // one character
    static int ch() {
        int c = __In::start();
        if c < 0 { throw "end of input"; }
        std_in_pos += 1;
        return c;
    }
    static int put(char^ buf, int at, char^ s) {
        int i = 0;
        while s[i] != 0 {
            buf[at] = s[i];
            at += 1;
            i += 1;
        }
        return at;
    }
    static int putnum(char^ buf, int at, int v) {
        char d[24];
        int n = 0;
        if v == 0 {
            d[0] = '0';
            n = 1;
        }
        while v > 0 {
            d[n] = '0' + v % 10;
            v = v / 10;
            n += 1;
        }
        while n > 0 {
            n -= 1;
            buf[at] = d[n];
            at += 1;
        }
        return at;
    }
    // a word into dst (room for cap characters including the 0): longer words are cut
    static int word(char^ dst, int cap, char^ name) {
        int c = __In::start();
        if c < 0 { throw "end of input"; }
        int n = 0;
        int cut = 0;
        while c >= 0 && !__In::space(c) {
            if n < cap - 1 {
                dst[n] = c;
                n += 1;
            } else {
                cut = 1;
            }
            std_in_pos += 1;
            c = __In::peek();
        }
        dst[n] = 0;
        if cut == 1 {
            char m[200];
            int at = __In::put(@m, 0, "warning: input truncated — '");
            at = __In::put(@m, at, name);
            at = __In::put(@m, at, "' accepts max ");
            at = __In::putnum(@m, at, cap - 1);
            at = __In::put(@m, at, " characters (char[");
            at = __In::putnum(@m, at, cap);
            at = __In::put(@m, at, "] - 1 for \\0)\n");
            syscall(64, 2, @m, at);
        }
        return n;
    }
}

// #multithread for i in a..b { ... }: the iterations are shared among several threads.
struct __Mt {
    // how many threads the machine can run at once (1 .. 16)
    static int cores() {
        char mask[128];
        int n = syscall(123, 0, 128, @mask);               // sched_getaffinity
        if n <= 0 { return 4; }
        int c = 0;
        for i in 0..n {
            int b = mask[i];
            while b != 0 {
                c += b & 1;
                b = b >> 1;
            }
        }
        if c < 1 { c = 1; }
        if c > 16 { c = 16; }
        return c;
    }
    // worker = the address of the compiled loop body (it gets a block [frame of the caller, from, to]);
    // runs it on several threads, each with its own part of lo..hi, and waits for all of them
    static void run(int worker, int fp, int lo, int hi) {
        int n = hi - lo;
        if n <= 0 { return; }
        int parts = __Mt::cores();
        if parts > n { parts = n; }
        int size = 1048576;
        int^ blk = (int^)Mem::alloc(parts * 64);          // per part: [0] frame [1] from [2] to [3] thread id [4] stack
        if (int)blk == 0 { throw "out of memory"; }
        for p in 0..parts {
            blk[p * 8] = fp;
            blk[p * 8 + 1] = lo + n * p / parts;
            blk[p * 8 + 2] = lo + n * (p + 1) / parts;
            blk[p * 8 + 3] = 0;
            int base = syscall(222, 0, size, 3, 34, -1, 0);
            if base < 0 { throw "cannot start the threads of the #multithread loop"; }
            blk[p * 8 + 4] = base;
            int top = base + size - 1024;
            int tid = __thread_start(worker, (int)blk + p * 64, top, (int)blk + p * 64 + 24, top);
            if tid < 0 { throw "cannot start the threads of the #multithread loop"; }
        }
        for p in 0..parts {
            while blk[p * 8 + 3] != 0 {
                syscall(98, (int)blk + p * 64 + 24, 0, blk[p * 8 + 3], 0, 0, 0);
            }
            syscall(215, blk[p * 8 + 4], size);
        }
    }
}
