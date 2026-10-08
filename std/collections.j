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
