// Map<K,V> and Set<T>: hash tables (open addressing, linear probing). K and T can be int, char, double,
// pointers or String. Both have a free(self) method, so a local one is freed at the end of its block.

struct Map<K, V> {
    K[] keys;
    V[] vals;
    int[] st;                  // 0 empty, 1 used, 2 deleted
    int len;                   // how many keys
    int used;                  // used + deleted places

    // the place of key k, or -1
    int find(self, K k) {
        if self.st == null { return -1; }
        int mask = self.st.len - 1;
        int i = __hash(k) & mask;
        while true {
            int s = self.st[i];
            if s == 0 { return -1; }
            if s == 1 && self.keys[i] == k { return i; }
            i = (i + 1) & mask;
        }
        return -1;
    }
    bool has(self, K k) {
        return self.find(k) >= 0;
    }
    // the value of key k (throws "key not found")
    V get(self, K k) {
        int i = self.find(k);
        if i < 0 { throw "key not found"; }
        return self.vals[i];
    }
    // the value of key k as an Option: Some(value) or None
    Option<V> try_get(self, K k) {
        int i = self.find(k);
        if i < 0 { return Option<V>::None; }
        return Option<V>::Some(self.vals[i]);
    }
    void put(self, K k, V v) {
        if self.st == null { self.rehash(8); }
        if (self.used + 1) * 4 > self.st.len * 3 { self.rehash(self.st.len * 2); }
        int mask = self.st.len - 1;
        int i = __hash(k) & mask;
        int tomb = -1;
        while true {
            int s = self.st[i];
            if s == 0 { break; }
            if s == 2 && tomb < 0 { tomb = i; }
            if s == 1 && self.keys[i] == k {
                self.vals[i] = v;
                return;
            }
            i = (i + 1) & mask;
        }
        if tomb >= 0 {
            i = tomb;
        } else {
            self.used += 1;
        }
        self.keys[i] = k;
        self.vals[i] = v;
        self.st[i] = 1;
        self.len += 1;
    }
    // true if key k was there
    bool remove(self, K k) {
        int i = self.find(k);
        if i < 0 { return false; }
        self.st[i] = 2;
        self.len -= 1;
        return true;
    }
    void rehash(self, int cap) {
        K[] ok = self.keys;
        V[] ov = self.vals;
        int[] os = self.st;
        self.keys = arr(cap);
        self.keys.resize(cap);
        self.vals = arr(cap);
        self.vals.resize(cap);
        self.st = arr(cap);
        self.st.resize(cap);
        self.len = 0;
        self.used = 0;
        if os != null {
            for i in 0..os.len {
                if os[i] == 1 { self.put(ok[i], ov[i]); }
            }
            ok.free();
            ov.free();
            os.free();
        }
    }
    // a new array with the keys (in table order)
    K[] keys_list(self) {
        K[] r = arr(self.len + 1);
        if self.st != null {
            for i in 0..self.st.len {
                if self.st[i] == 1 { r.push(self.keys[i]); }
            }
        }
        return r;
    }
    V[] values_list(self) {
        V[] r = arr(self.len + 1);
        if self.st != null {
            for i in 0..self.st.len {
                if self.st[i] == 1 { r.push(self.vals[i]); }
            }
        }
        return r;
    }
    void free(self) {
        self.keys.free();
        self.vals.free();
        self.st.free();
        self.len = 0;
        self.used = 0;
    }
}

struct Set<T> {
    T[] items;
    int[] st;
    int len;
    int used;

    int find(self, T x) {
        if self.st == null { return -1; }
        int mask = self.st.len - 1;
        int i = __hash(x) & mask;
        while true {
            int s = self.st[i];
            if s == 0 { return -1; }
            if s == 1 && self.items[i] == x { return i; }
            i = (i + 1) & mask;
        }
        return -1;
    }
    bool has(self, T x) {
        return self.find(x) >= 0;
    }
    // true if x was new
    bool add(self, T x) {
        if self.find(x) >= 0 { return false; }
        if self.st == null { self.rehash(8); }
        if (self.used + 1) * 4 > self.st.len * 3 { self.rehash(self.st.len * 2); }
        int mask = self.st.len - 1;
        int i = __hash(x) & mask;
        while self.st[i] == 1 { i = (i + 1) & mask; }
        if self.st[i] == 0 { self.used += 1; }
        self.items[i] = x;
        self.st[i] = 1;
        self.len += 1;
        return true;
    }
    bool remove(self, T x) {
        int i = self.find(x);
        if i < 0 { return false; }
        self.st[i] = 2;
        self.len -= 1;
        return true;
    }
    void rehash(self, int cap) {
        T[] oi = self.items;
        int[] os = self.st;
        self.items = arr(cap);
        self.items.resize(cap);
        self.st = arr(cap);
        self.st.resize(cap);
        self.len = 0;
        self.used = 0;
        if os != null {
            for i in 0..os.len {
                if os[i] == 1 { self.add(oi[i]); }
            }
            oi.free();
            os.free();
        }
    }
    T[] items_list(self) {
        T[] r = arr(self.len + 1);
        if self.st != null {
            for i in 0..self.st.len {
                if self.st[i] == 1 { r.push(self.items[i]); }
            }
        }
        return r;
    }
    void free(self) {
        self.items.free();
        self.st.free();
        self.len = 0;
        self.used = 0;
    }
}

// ---------------------------------------------------------------------------------------------- sorting and searching
// Written with the type: sort_by<int>(a, less). `less(x, y)` is true when x must come before y; the sort is stable (merge sort, one
// buffer of the same length) and takes n log n steps.

void sort_by<T>(T[] a, bool(T, T)^ less) {
    int n = a.len;
    if n < 2 { return; }
    T[] tmp = arr(n);
    tmp.resize(n);
    int width = 1;
    while width < n {
        int lo = 0;
        while lo < n {
            int mid = lo + width;
            if mid > n { mid = n; }
            int hi = lo + width * 2;
            if hi > n { hi = n; }
            int i = lo;
            int j = mid;
            int k = lo;
            while i < mid && j < hi {
                if less(a[j], a[i]) {
                    tmp[k] = a[j];
                    j += 1;
                } else {
                    tmp[k] = a[i];
                    i += 1;
                }
                k += 1;
            }
            while i < mid { tmp[k] = a[i]; i += 1; k += 1; }
            while j < hi { tmp[k] = a[j]; j += 1; k += 1; }
            lo += width * 2;
        }
        for q in 0..n { a[q] = tmp[q]; }
        width *= 2;
    }
    tmp.free();
}

// the first place i of the sorted array a where a[i] >= x (a.len when there is none)
int lower_bound<T>(T[] a, T x) {
    int lo = 0;
    int hi = a.len;
    while lo < hi {
        int mid = lo + (hi - lo) / 2;
        if a[mid] < x { lo = mid + 1; } else { hi = mid; }
    }
    return lo;
}

// the first place i where a[i] > x
int upper_bound<T>(T[] a, T x) {
    int lo = 0;
    int hi = a.len;
    while lo < hi {
        int mid = lo + (hi - lo) / 2;
        if a[mid] <= x { lo = mid + 1; } else { hi = mid; }
    }
    return lo;
}

// the place of x in the sorted array a, or -1
int binary_search<T>(T[] a, T x) {
    int i = lower_bound<T>(a, x);
    if i < a.len && a[i] == x { return i; }
    return -1;
}

// ---------------------------------------------------------------------------------------------- Queue, Deque, Heap
// Queue<T>: first in, first out (a ring buffer). Deque<T>: also at the front. Heap<T>: the smallest element (by `<`) comes out first.
// Each has len and free(self); pop / front / back on an empty one throw "empty".

struct Queue<T> {
    T[] items;
    int head;
    int len;

    void push(self, T x) {
        if self.items == null { self.items = arr(8); self.items.resize(8); }
        int cap = self.items.len;
        if self.len == cap {
            T[] bigger = arr(cap * 2);
            bigger.resize(cap * 2);
            for i in 0..self.len { bigger[i] = self.items[(self.head + i) % cap]; }
            self.items.free();
            self.items = bigger;
            self.head = 0;
            cap = cap * 2;
        }
        self.items[(self.head + self.len) % cap] = x;
        self.len += 1;
    }
    T front(self) {
        if self.len == 0 { throw "empty"; }
        return self.items[self.head];
    }
    T pop(self) {
        if self.len == 0 { throw "empty"; }
        T x = self.items[self.head];
        self.head = (self.head + 1) % self.items.len;
        self.len -= 1;
        return x;
    }
    void free(self) {
        self.items.free();
        self.head = 0;
        self.len = 0;
    }
}

struct Deque<T> {
    T[] items;
    int head;
    int len;

    void grow(self) {
        if self.items == null { self.items = arr(8); self.items.resize(8); }
        int cap = self.items.len;
        if self.len == cap {
            T[] bigger = arr(cap * 2);
            bigger.resize(cap * 2);
            for i in 0..self.len { bigger[i] = self.items[(self.head + i) % cap]; }
            self.items.free();
            self.items = bigger;
            self.head = 0;
        }
    }
    void push_back(self, T x) {
        self.grow();
        int cap = self.items.len;
        self.items[(self.head + self.len) % cap] = x;
        self.len += 1;
    }
    void push_front(self, T x) {
        self.grow();
        int cap = self.items.len;
        self.head = (self.head + cap - 1) % cap;
        self.items[self.head] = x;
        self.len += 1;
    }
    T front(self) {
        if self.len == 0 { throw "empty"; }
        return self.items[self.head];
    }
    T back(self) {
        if self.len == 0 { throw "empty"; }
        return self.items[(self.head + self.len - 1) % self.items.len];
    }
    T pop_front(self) {
        if self.len == 0 { throw "empty"; }
        T x = self.items[self.head];
        self.head = (self.head + 1) % self.items.len;
        self.len -= 1;
        return x;
    }
    T pop_back(self) {
        if self.len == 0 { throw "empty"; }
        self.len -= 1;
        return self.items[(self.head + self.len) % self.items.len];
    }
    // the element number i from the front
    T get(self, int i) {
        if i < 0 || i >= self.len { throw "index out of range"; }
        return self.items[(self.head + i) % self.items.len];
    }
    void free(self) {
        self.items.free();
        self.head = 0;
        self.len = 0;
    }
}

struct Heap<T> {
    T[] items;
    int len;

    void push(self, T x) {
        if self.items == null { self.items = arr(8); }
        self.items.push(x);
        int i = self.len;
        self.len += 1;
        while i > 0 {
            int p = (i - 1) / 2;
            if self.items[i] < self.items[p] {
                T t = self.items[i];
                self.items[i] = self.items[p];
                self.items[p] = t;
                i = p;
            } else {
                i = 0;
            }
        }
    }
    T top(self) {
        if self.len == 0 { throw "empty"; }
        return self.items[0];
    }
    T pop(self) {
        if self.len == 0 { throw "empty"; }
        T r = self.items[0];
        self.len -= 1;
        self.items[0] = self.items[self.len];
        self.items.pop();
        int i = 0;
        bool go = true;
        while go {
            int l = i * 2 + 1;
            int m = i;
            if l < self.len && self.items[l] < self.items[m] { m = l; }
            if l + 1 < self.len && self.items[l + 1] < self.items[m] { m = l + 1; }
            if m == i {
                go = false;
            } else {
                T t = self.items[i];
                self.items[i] = self.items[m];
                self.items[m] = t;
                i = m;
            }
        }
        return r;
    }
    void free(self) {
        self.items.free();
        self.len = 0;
    }
}

// ---------------------------------------------------------------------------------------------- Span<T>
// A view of a part of an array: no copy, no ownership (nothing to free; do not `push` to the array while a span of it is alive).
//   Span<int> s = span<int>(a, 1, 5);      // the elements 1, 2, 3, 4 of a
//   s.get(0)  s.set(0, 9)  s.len  s.sub(1, 3)  s.to_array()
// A write through the span changes the array. The index is checked (throws "span index out of range").

struct Span<T> {
    T[] base;
    int off;
    int len;

    T get(self, int i) {
        if i < 0 || i >= self.len { throw "span index out of range"; }
        return self.base[self.off + i];
    }
    void set(self, int i, T x) {
        if i < 0 || i >= self.len { throw "span index out of range"; }
        self.base[self.off + i] = x;
    }
    // the part lo .. hi of this span (a view of the same array)
    Span<T> sub(self, int lo, int hi) {
        if lo < 0 || hi > self.len || lo > hi { throw "span range out of range"; }
        Span<T> r = {self.base, self.off + lo, hi - lo};
        return r;
    }
    // a new array with a copy of the elements (the caller frees it)
    T[] to_array(self) {
        T[] r = arr(self.len + 1);
        for i in 0..self.len { r.push(self.base[self.off + i]); }
        return r;
    }
}

Span<T> span<T>(T[] a, int lo, int hi) {
    if lo < 0 || hi > a.len || lo > hi { throw "span range out of range"; }
    Span<T> r = {a, lo, hi - lo};
    return r;
}


// JSON: Json::parse(text) gives a document, a table of nodes; a node is a number (-1 means "none").
//   JsonDoc doc = Json::parse(text)?;
//   int name = doc.get(doc.root(), "name");          String s = doc.text(name);
//   int first = doc.at(doc.get(doc.root(), "list"), 0);    double d = doc.number(first);
//   String out = doc.dump(doc.root());               // back to (compact) JSON text
// json_quote(s) makes a JSON string literal; json_num_text(x) is a number as text.
// helpers (also reachable as Json::quote and Json::num_text)
String json_int_text(int v) {
    String r = "";
    if v < 0 {
        r.push('-');
        v = 0 - v;
    }
    char buf[24];
    int n = 0;
    if v == 0 {
        buf[0] = '0';
        n = 1;
    }
    while v > 0 {
        buf[n] = (char)('0' + v % 10);
        n += 1;
        v = v / 10;
    }
    while n > 0 {
        n -= 1;
        r.push(buf[n]);
    }
    return r;
}
// a number as the shortest text that reads back the same (up to 15 digits); nan and inf are null
String json_num_text(double x) {
    if x != x || x > 1.0e22 || x < -1.0e22 { return "null"; }
    String r = "";
    if x < 0.0 {
        r.push('-');
        x = 0.0 - x;
    }
    if x < 9.0e15 {
        int ip = (int)x;
        r.append(json_int_text(ip));
        double fp = x - (double)ip;
        if fp > 0.0 {
            String f = "";
            int k = 0;
            while k < 15 && fp > 0.0 {
                fp = fp * 10.0;
                int d = (int)fp;
                f.push((char)('0' + d));
                fp = fp - (double)d;
                k += 1;
            }
            // drop zeros at the end
            int cut = f.len;
            while cut > 0 && f[cut - 1] == '0' { cut -= 1; }
            if cut > 0 {
                r.push('.');
                r.append(f.slice(0, cut));
            }
        }
        return r;
    }
    // very large numbers: whole digits only
    r.append(json_int_text((int)(x / 1.0e10)));
    r.append("0000000000");
    return r;
}
// a JSON string literal for s (with the quotes)
String json_quote(String s) {
    String r = "\"";
    String hex = "0123456789abcdef";
    for i in 0..s.len {
        char c = s[i];
        if c == '"' {
            r.append("\\\"");
        } else if c == 92 {
            r.append("\\\\");
        } else if c == 10 {
            r.append("\\n");
        } else if c == 13 {
            r.append("\\r");
        } else if c == 9 {
            r.append("\\t");
        } else if c < 32 {
            r.append("\\u00");
            r.push(hex[c / 16]);
            r.push(hex[c % 16]);
        } else {
            r.push(c);
        }
    }
    r.push('"');
    return r;
}

struct JsonDoc {
    String src;
    int pos;
    String err;
    int[] kind;                  // 0 null, 1 false, 2 true, 3 number, 4 string, 5 array, 6 object
    double[] num;
    String[] txt;                // the value of a string node
    String[] key;                // the name of a node that is a member of an object
    int[] first;                 // the first child (array, object)
    int[] last;
    int[] next;                  // the next brother
    void free(self) {
        self.src.free();
        self.err.free();
        self.kind.free();
        self.num.free();
        self.txt.free();
        self.key.free();
        self.first.free();
        self.last.free();
        self.next.free();
    }
    // ---- reading (JsonDoc is made by Json::parse)
    int fail(self, String m) {
        if self.err.len == 0 {
            String t = m;
            t.append(" at byte ");
            t.append(json_int_text(self.pos));
            self.err = t;
        }
        return -1;
    }
    void skip_ws(self) {
        while self.pos < self.src.len {
            char c = self.src[self.pos];
            if c == 32 || c == 10 || c == 13 || c == 9 {
                self.pos += 1;
            } else {
                return;
            }
        }
    }
    // a new node; its text and name are stored with it
    int add(self, int k, String t, String name) {
        self.kind.push(k);
        self.num.push(0.0);
        self.txt.push(t);
        self.key.push(name);
        self.first.push(-1);
        self.last.push(-1);
        self.next.push(-1);
        return self.kind.len - 1;
    }
    // puts node c at the end of the children of node p
    void link(self, int p, int c) {
        if self.first[p] < 0 {
            self.first[p] = c;
        } else {
            self.next[self.last[p]] = c;
        }
        self.last[p] = c;
    }
    bool word(self, String w) {
        if self.pos + w.len > self.src.len { return false; }
        for i in 0..w.len {
            if self.src[self.pos + i] != w[i] { return false; }
        }
        self.pos += w.len;
        return true;
    }
    int value(self, String name) {
        self.skip_ws();
        if self.pos >= self.src.len { return self.fail("unexpected end of the text"); }
        char c = self.src[self.pos];
        if c == '{' { return self.object(name); }
        if c == '[' { return self.array(name); }
        if c == '"' {
            String s = self.string_lit();
            if self.err.len > 0 { return -1; }
            return self.add(4, s, name);
        }
        if self.word("true") { return self.add(2, "", name); }
        if self.word("false") { return self.add(1, "", name); }
        if self.word("null") { return self.add(0, "", name); }
        if c == '-' || (c >= '0' && c <= '9') { return self.number_lit(name); }
        return self.fail("unexpected character");
    }
    int number_lit(self, String name) {
        int a = self.pos;
        if self.src[self.pos] == '-' { self.pos += 1; }
        while self.pos < self.src.len {
            char c = self.src[self.pos];
            if (c >= '0' && c <= '9') || c == '.' || c == 'e' || c == 'E' || c == '+' || c == '-' {
                self.pos += 1;
            } else {
                break;
            }
        }
        double v = 0.0;
        try { v = self.src.slice(a, self.pos).to_double(); } catch (e) {
            return self.fail("bad number");
        }
        int n = self.add(3, "", name);
        self.num[n] = v;
        return n;
    }
    int hex4(self) {
        if self.pos + 4 > self.src.len { return -1; }
        int v = 0;
        for i in 0..4 {
            char c = self.src[self.pos + i];
            int d = -1;
            if c >= '0' && c <= '9' { d = c - '0'; }
            if c >= 'a' && c <= 'f' { d = c - 'a' + 10; }
            if c >= 'A' && c <= 'F' { d = c - 'A' + 10; }
            if d < 0 { return -1; }
            v = v * 16 + d;
        }
        self.pos += 4;
        return v;
    }
    // the string at pos (which is the opening quote); the text is decoded; err is set on a mistake
    String string_lit(self) {
        String r = "";
        self.pos += 1;
        while true {
            if self.pos >= self.src.len {
                self.fail("the string is not closed");
                return r;
            }
            char c = self.src[self.pos];
            self.pos += 1;
            if c == '"' { return r; }
            if c < 32 {
                self.fail("a control character in a string");
                return r;
            }
            if c != 92 {
                r.push(c);
            } else {
                if self.pos >= self.src.len {
                    self.fail("the string is not closed");
                    return r;
                }
                char e = self.src[self.pos];
                self.pos += 1;
                if e == 'n' { r.push((char)10); }
                else if e == 't' { r.push((char)9); }
                else if e == 'r' { r.push((char)13); }
                else if e == 'b' { r.push((char)8); }
                else if e == 'f' { r.push((char)12); }
                else if e == '"' || e == 92 || e == '/' { r.push(e); }
                else if e == 'u' {
                    int cp = self.hex4();
                    if cp < 0 {
                        self.fail("bad \\u escape");
                        return r;
                    }
                    if cp >= 0xD800 && cp <= 0xDBFF && self.pos + 1 < self.src.len && self.src[self.pos] == 92 && self.src[self.pos + 1] == 'u' {
                        int save = self.pos;
                        self.pos += 2;
                        int lo = self.hex4();
                        if lo >= 0xDC00 && lo <= 0xDFFF {
                            cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                        } else {
                            self.pos = save;
                        }
                    }
                    if cp < 0x80 {
                        r.push((char)cp);
                    } else if cp < 0x800 {
                        r.push((char)(0xC0 | (cp >> 6)));
                        r.push((char)(0x80 | (cp & 63)));
                    } else if cp < 0x10000 {
                        r.push((char)(0xE0 | (cp >> 12)));
                        r.push((char)(0x80 | ((cp >> 6) & 63)));
                        r.push((char)(0x80 | (cp & 63)));
                    } else {
                        r.push((char)(0xF0 | (cp >> 18)));
                        r.push((char)(0x80 | ((cp >> 12) & 63)));
                        r.push((char)(0x80 | ((cp >> 6) & 63)));
                        r.push((char)(0x80 | (cp & 63)));
                    }
                } else {
                    self.fail("unknown escape");
                    return r;
                }
            }
        }
        return r;
    }
    int array(self, String name) {
        int me = self.add(5, "", name);
        self.pos += 1;
        self.skip_ws();
        if self.pos < self.src.len && self.src[self.pos] == ']' {
            self.pos += 1;
            return me;
        }
        while true {
            int c = self.value("");
            if c < 0 { return -1; }
            self.link(me, c);
            self.skip_ws();
            if self.pos >= self.src.len { return self.fail("the array is not closed"); }
            char d = self.src[self.pos];
            self.pos += 1;
            if d == ']' { return me; }
            if d != ',' { return self.fail("a , or ] was expected"); }
        }
        return me;
    }
    int object(self, String name) {
        int me = self.add(6, "", name);
        self.pos += 1;
        self.skip_ws();
        if self.pos < self.src.len && self.src[self.pos] == '}' {
            self.pos += 1;
            return me;
        }
        while true {
            self.skip_ws();
            if self.pos >= self.src.len || self.src[self.pos] != '"' { return self.fail("a name in quotes was expected"); }
            String k = self.string_lit();
            if self.err.len > 0 { return -1; }
            self.skip_ws();
            if self.pos >= self.src.len || self.src[self.pos] != ':' { return self.fail("a : was expected"); }
            self.pos += 1;
            int c = self.value(k);
            if c < 0 { return -1; }
            self.link(me, c);
            self.skip_ws();
            if self.pos >= self.src.len { return self.fail("the object is not closed"); }
            char d = self.src[self.pos];
            self.pos += 1;
            if d == '}' { return me; }
            if d != ',' { return self.fail("a , or } was expected"); }
        }
        return me;
    }

    // ---- looking at a document (n is a node; -1 or a wrong kind gives an empty answer)
    int root(self) { return 0; }
    // 0 null, 1 false, 2 true, 3 number, 4 string, 5 array, 6 object; -1 for no node
    int kind_of(self, int n) {
        if n < 0 || n >= self.kind.len { return -1; }
        return self.kind[n];
    }
    int len(self, int n) {
        int k = self.kind_of(n);
        if k != 5 && k != 6 { return 0; }
        int c = self.first[n];
        int count = 0;
        while c >= 0 {
            count += 1;
            c = self.next[c];
        }
        return count;
    }
    // the i-th element of an array or member of an object (counted from 0), or -1
    int at(self, int n, int i) {
        int k = self.kind_of(n);
        if k != 5 && k != 6 { return -1; }
        int c = self.first[n];
        while c >= 0 && i > 0 {
            c = self.next[c];
            i -= 1;
        }
        return c;
    }
    // the member of an object with this name, or -1
    int get(self, int n, String name) {
        if self.kind_of(n) != 6 { return -1; }
        int c = self.first[n];
        while c >= 0 {
            if self.key[c] == name { return c; }
            c = self.next[c];
        }
        return -1;
    }
    bool has(self, int n, String name) { return self.get(n, name) >= 0; }
    // the name of a node that is a member of an object
    String name_of(self, int n) {
        if n < 0 || n >= self.kind.len { return ""; }
        String r = "";
        r.append(self.key[n]);
        return r;
    }
    String text(self, int n) {
        if self.kind_of(n) != 4 { return ""; }
        String r = "";
        r.append(self.txt[n]);
        return r;
    }
    double number(self, int n) {
        if self.kind_of(n) != 3 { return 0.0; }
        return self.num[n];
    }
    int integer(self, int n) { return (int)self.number(n); }
    bool boolean(self, int n) { return self.kind_of(n) == 2; }
    bool is_null(self, int n) { return self.kind_of(n) == 0; }

    // ---- writing: the node and what is below it as compact JSON text
    String dump(self, int n) {
        String r = "";
        int k = self.kind_of(n);
        if k <= 0 {
            r.append("null");
        } else if k == 1 {
            r.append("false");
        } else if k == 2 {
            r.append("true");
        } else if k == 3 {
            r.append(json_num_text(self.num[n]));
        } else if k == 4 {
            r.append(json_quote(self.txt[n]));
        } else if k == 5 {
            r.push('[');
            int c = self.first[n];
            while c >= 0 {
                if c != self.first[n] { r.push(','); }
                r.append(self.dump(c));
                c = self.next[c];
            }
            r.push(']');
        } else {
            r.push('{');
            int c = self.first[n];
            while c >= 0 {
                if c != self.first[n] { r.push(','); }
                r.append(json_quote(self.key[c]));
                r.push(':');
                r.append(self.dump(c));
                c = self.next[c];
            }
            r.push('}');
        }
        return r;
    }
}

// the entry points: Json::parse(text), Json::quote(s), Json::num_text(x)
struct Json {
    static String quote(String s) { return json_quote(s); }
    static String num_text(double x) { return json_num_text(x); }
    static Result<JsonDoc, Error> parse(String text) {
        JsonDoc j;
        j.src = text;
        j.pos = 0;
        j.err = "";
        j.kind = arr(16);
        j.num = arr(16);
        j.txt = arr(16);
        j.key = arr(16);
        j.first = arr(16);
        j.last = arr(16);
        j.next = arr(16);
        int root = j.value("");
        if root >= 0 {
            j.skip_ws();
            if j.pos < j.src.len { root = j.fail("extra text after the value"); }
        }
        if root < 0 {
            return Result<JsonDoc, Error>::Err(Error::make(ErrorKind::Parse, j.err));
        }
        return Result<JsonDoc, Error>::Ok(j);
    }
}

// json: Json::json.parse(text), with  using Json;  json.parse(text). A text that is not JSON is thrown as an error; try_parse returns the Result.

// Csv: one line of comma separated values, with "quoted, fields" and "" for a quote inside a field.
//   String[] f = Csv::split_line("a,\"b,c\",d");      // a  b,c  d
//   String line = Csv::join_line(f);                  // a,"b,c",d
struct Csv {
    static String[] split_line(String line) {
        String[] out = arr(4);
        String cur = "";
        bool quoted = false;
        int i = 0;
        while i < line.len {
            char c = line[i];
            if quoted {
                if c == '"' {
                    if i + 1 < line.len && line[i + 1] == '"' {
                        cur.push('"');
                        i += 1;
                    } else {
                        quoted = false;
                    }
                } else {
                    cur.push(c);
                }
            } else if c == '"' {
                quoted = true;
            } else if c == ',' {
                out.push(cur);
                cur = "";
            } else if c != 13 {
                cur.push(c);
            }
            i += 1;
        }
        out.push(cur);
        return out;
    }
    static String quote_field(String f) {
        bool need = false;
        for i in 0..f.len {
            char c = f[i];
            if c == ',' || c == '"' || c == 10 || c == 13 { need = true; }
        }
        if !need { return f; }
        String r = "\"";
        for i in 0..f.len {
            if f[i] == '"' { r.push('"'); }
            r.push(f[i]);
        }
        r.push('"');
        return r;
    }
    static String join_line(String[] fields) {
        String r = "";
        for i in 0..fields.len {
            if i > 0 { r.push(','); }
            r += Csv::quote_field(fields[i]);
        }
        return r;
    }
}

// csv: the short names (Csv::csv.split(line), with  using Csv;  csv.split(line))

// Toml: the simple part of TOML for settings: [sections], key = "text" | number | true | false, # comments.
// A key is written section.key (a key before any section is written alone).
//   String cfg = Fs::read_text("app.toml").unwrap();
//   Option<String> name = Toml::get(cfg, "server.name");      Option<int> port = Toml::get_int(cfg, "server.port");
struct Toml {
    // the value of the key as it is written (a quoted text without its quotes), or None
    static Option<String> get(String text, String key) {
        String section = "";
        int pos = 0;
        while pos <= text.len {
            int end = pos;
            while end < text.len && text[end] != 10 { end += 1; }
            String line = text.slice(pos, end);
            pos = end + 1;
            String t = line.trim();
            if t.len == 0 || t[0] == '#' { continue; }
            if t[0] == '[' {
                int close = t.find("]");
                if close > 1 { section = t.slice(1, close).trim(); }
                continue;
            }
            int eq = t.find("=");
            if eq < 1 { continue; }
            String k = t.slice(0, eq).trim();
            String full = k;
            if section.len > 0 { full = section + "." + k; }
            if full != key { continue; }
            String v = t.slice(eq + 1, t.len).trim();
            if v.len >= 2 && v[0] == '"' {
                String r = "";
                int i = 1;
                while i < v.len && v[i] != '"' {
                    if v[i] == '\\' && i + 1 < v.len {
                        i += 1;
                        if v[i] == 'n' { r.push(10); }
                        else if v[i] == 't' { r.push(9); }
                        else { r.push(v[i]); }
                    } else {
                        r.push(v[i]);
                    }
                    i += 1;
                }
                return Option<String>::Some(r);
            }
            // a value without quotes ends at a comment
            int hash = v.find("#");
            if hash >= 0 { v = v.slice(0, hash).trim(); }
            return Option<String>::Some(v);
        }
        return Option<String>::None;
    }
    static Option<int> get_int(String text, String key) {
        Option<String> v = Toml::get(text, key);
        if v.is_none() { return Option<int>::None; }
        String s = v.unwrap();
        if s.len == 0 { return Option<int>::None; }
        int i = 0;
        int sign = 1;
        if s[0] == '-' {
            sign = -1;
            i = 1;
        }
        if i >= s.len { return Option<int>::None; }
        int n = 0;
        while i < s.len {
            if s[i] == '_' {
                i += 1;
                continue;
            }
            if s[i] < '0' || s[i] > '9' { return Option<int>::None; }
            n = n * 10 + (s[i] - '0');
            i += 1;
        }
        return Option<int>::Some(n * sign);
    }
    static Option<bool> get_bool(String text, String key) {
        Option<String> v = Toml::get(text, key);
        if v.is_none() { return Option<bool>::None; }
        String s = v.unwrap();
        if s == "true" { return Option<bool>::Some(true); }
        if s == "false" { return Option<bool>::Some(false); }
        return Option<bool>::None;
    }
    static Option<double> get_double(String text, String key) {
        Option<String> v = Toml::get(text, key);
        if v.is_none() { return Option<double>::None; }
        String s = v.unwrap();
        if s.len == 0 { return Option<double>::None; }
        int i = 0;
        double sign = 1.0;
        if s[0] == '-' {
            sign = -1.0;
            i = 1;
        }
        double n = 0.0;
        bool digits = false;
        while i < s.len && s[i] >= '0' && s[i] <= '9' {
            n = n * 10.0 + (double)(s[i] - '0');
            digits = true;
            i += 1;
        }
        if i < s.len && s[i] == '.' {
            i += 1;
            double f = 0.1;
            while i < s.len && s[i] >= '0' && s[i] <= '9' {
                n = n + f * (double)(s[i] - '0');
                f = f / 10.0;
                digits = true;
                i += 1;
            }
        }
        if !digits || i != s.len { return Option<double>::None; }
        return Option<double>::Some(n * sign);
    }
}

// toml: the short names (Toml::toml.get(text, key), with  using Toml;  toml.get(text, key)); get returns an Option, get_or a value

// the short names of the data unit (csv, json, toml): <module>_<name>, the compiler adds the prefix
struct __Data {
    static String[] csv_split(String line) { return Csv::split_line(line); }
    static String csv_quote(String f) { return Csv::quote_field(f); }
    static String csv_join(String[] fields) { return Csv::join_line(fields); }
    static JsonDoc json_parse(String text) { return Json::parse(text).take(); }
    static Result<JsonDoc, Error> json_try_parse(String text) { return Json::parse(text); }
    static String json_quote(String s) { return Json::quote(s); }
    static String json_num_text(double x) { return Json::num_text(x); }
    static Option<String> toml_get(String text, String key) { return Toml::get(text, key); }
    static String toml_get_or(String text, String key, String fallback) {
        Option<String> v = Toml::get(text, key);
        switch v {
            Option::Some(s): return s;
            Option::None: return fallback;
        }
        return fallback;
    }
    static Option<int> toml_get_int(String text, String key) { return Toml::get_int(text, key); }
    static Option<bool> toml_get_bool(String text, String key) { return Toml::get_bool(text, key); }
    static Option<double> toml_get_double(String text, String key) { return Toml::get_double(text, key); }
}

