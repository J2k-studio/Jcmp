// tilemap 0.1.0 -- the world of a 2D game made of tiles (a Terraria or Stardew kind of world): layers, chunks, changes, saving.   #import <tilemap>   (needs jcmp 1.2.1.0; license: MPL-2.0)
//   TileMap m = TileMap::make(2000, 600, 2);   m.set(0, 10, 20, 5);   int t = m.get(0, 10, 20);       // 2000 x 600 tiles, 2 layers (0 ground, 1 things on it); a tile is a number 0..65535
//   if m.dirty(0, 10, 20) { ... }   m.clean();                                                        // which chunks changed since the last clean (to draw or save only those)
//   m.save("world.jw"); TileMap w = TileMap::load("world.jw", @ok);
// The tiles are kept in chunks of 16 x 16 for each layer (a chunk that was never changed takes no room), so a big world is small in memory and a change marks one chunk.
// The numbers mean what the game says; 0 is empty. Outside the world every tile is 0 and set() does nothing.

struct TileMap {
    int w;
    int h;
    int layers;
    int cw;                          // chunks across
    int ch;                          // chunks down
    int[] chunk_of;                  // layer * cw * ch + chunk -> index in data + 1 (0: the chunk is empty)
    int[] data;                      // the chunks that exist, 256 tiles each
    int[] dirty_flag;                // layer * cw * ch + chunk -> 1 when changed since clean()
    int nchunks;

    static TileMap make(int w, int h, int layers) {
        TileMap m;
        m.w = w;
        m.h = h;
        m.layers = layers;
        m.cw = (w + 15) / 16;
        m.ch = (h + 15) / 16;
        int total = layers * m.cw * m.ch;
        m.chunk_of = arr(total + 1);
        m.dirty_flag = arr(total + 1);
        for i in 0..total { m.chunk_of.push(0); m.dirty_flag.push(0); }
        m.data = arr(256);
        m.nchunks = 0;
        return m;
    }

    bool inside(self, int layer, int x, int y) {
        return layer >= 0 && layer < self.layers && x >= 0 && y >= 0 && x < self.w && y < self.h;
    }

    int get(self, int layer, int x, int y) {
        if !self.inside(layer, x, y) { return 0; }
        int c = layer * self.cw * self.ch + (y / 16) * self.cw + (x / 16);
        int at = self.chunk_of[c];
        if at == 0 { return 0; }
        return self.data[(at - 1) * 256 + (y % 16) * 16 + (x % 16)];
    }

    void set(self, int layer, int x, int y, int tile) {
        if !self.inside(layer, x, y) { return; }
        int c = layer * self.cw * self.ch + (y / 16) * self.cw + (x / 16);
        int at = self.chunk_of[c];
        if at == 0 {
            if tile == 0 { return; }                                   // nothing to write in a chunk that is empty
            for i in 0..256 { self.data.push(0); }
            self.nchunks += 1;
            at = self.nchunks;
            self.chunk_of[c] = at;
        }
        int k = (at - 1) * 256 + (y % 16) * 16 + (x % 16);
        if self.data[k] != tile {
            self.data[k] = tile & 65535;
            self.dirty_flag[c] = 1;
        }
    }

    // changed since the last clean()
    bool dirty(self, int layer, int x, int y) {
        if !self.inside(layer, x, y) { return false; }
        return self.dirty_flag[layer * self.cw * self.ch + (y / 16) * self.cw + (x / 16)] == 1;
    }

    void clean(self) {
        for i in 0..self.dirty_flag.len { self.dirty_flag[i] = 0; }
    }

    // how many chunks hold something (the memory is this * 256 * 8 bytes)
    int used_chunks(self) { return self.nchunks; }

    // a rectangle of one layer
    void fill(self, int layer, int x, int y, int rw, int rh, int tile) {
        for j in 0..rh { for i in 0..rw { self.set(layer, x + i, y + j, tile); } }
    }

    // the world as text: a header, then for each chunk that exists  layer chunk  and its 256 numbers (the file of a save; small, readable)
    void save(self, String path) {
        String s = "tilemap 1 " + str(self.w) + " " + str(self.h) + " " + str(self.layers) + "\n";
        int total = self.layers * self.cw * self.ch;
        for c in 0..total {
            int at = self.chunk_of[c];
            if at == 0 { continue; }
            s.append("c " + str(c));
            for k in 0..256 { s.append(" "); s.append(str(self.data[(at - 1) * 256 + k])); }
            s.append("\n");
        }
        Fs::write_text(path, s);
    }

    static TileMap load(String path, bool^ ok) {
        TileMap m = TileMap::make(1, 1, 1);
        ok[0] = false;
        Result<String, Error> r = Fs::read_text(path);
        if !r.is_ok() { return m; }
        String s = r.take();
        String[] lines = s.split("\n");
        if lines.len < 1 { return m; }
        String[] head = lines[0].split(" ");
        if head.len < 5 || head[0] != "tilemap" { return m; }
        m = TileMap::make(head[2].to_int(), head[3].to_int(), head[4].to_int());
        for li in 1..lines.len {
            if lines[li].len < 3 { continue; }
            String[] f = lines[li].split(" ");
            if f.len < 258 || f[0] != "c" { continue; }
            int c = f[1].to_int();
            int per = m.cw * m.ch;
            int layer = c / per;
            int inlayer = c % per;
            int cy = inlayer / m.cw;
            int cx = inlayer % m.cw;
            for k in 0..256 {
                int t = f[2 + k].to_int();
                if t != 0 { m.set(layer, cx * 16 + (k % 16), cy * 16 + (k / 16), t); }
            }
        }
        m.clean();
        ok[0] = true;
        return m;
    }
}
