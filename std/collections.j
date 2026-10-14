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
