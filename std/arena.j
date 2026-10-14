// Arena: memory handed out in a row from one block and given back all at once.
//   Arena a;  a.init(4096);  int^ p = (int^)a.take(80);  ...  a.reset();  ...  a.free();
// take gives 8-byte aligned memory (zeroed), or null when the block is full.
struct Arena {
    int^ base;
    int size;
    int used;
    void init(self, int bytes) {
        self.base = (int^)Mem::alloc(bytes);
        self.size = bytes;
        self.used = 0;
    }
    void^ take(self, int bytes) {
        int n = (bytes + 7) / 8 * 8;
        if self.base == null || self.used + n > self.size { return null; }
        char^ b = (char^)self.base;
        void^ p = (void^)@b[self.used];
        Mem::set(p, 0, n);
        self.used += n;
        return p;
    }
    // everything taken so far is given back (the block stays)
    void reset(self) { self.used = 0; }
    int left(self) { return self.size - self.used; }
    void free(self) {
        if self.base != null { Mem::free((void^)self.base); }
        self.base = null;
        self.size = 0;
        self.used = 0;
    }
}
