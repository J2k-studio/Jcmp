// spritebatch 0.1.0 -- many sprites drawn in order: a texture atlas and a batch.   #import <deflate> <png> <gamej> <sprite> <spritebatch>   (needs jcmp 1.2.1.0; license: MPL-2.0)
//   Atlas a = Atlas::make(256, 256);                 // one big picture; small sprites are packed into it row by row
//   int hero = a.add(Sprites::load("hero.png", @ok)); int tree = a.add(tree_sprite);     // the number of the sprite, or -1 when the atlas is full
//   SpriteBatch b = SpriteBatch::make(a);
//   b.view(cam_x, cam_y, 320, 180);                  // optional: sprites outside this window are dropped
//   b.add(tree, 100, 40, 1);  b.add(hero, 50, 60, 2);  b.add_flip(hero, 80, 60, 2, true);      // sprite, x, y, layer (0..15; a higher layer is drawn later = in front)
//   b.flush(game);                                   // draws everything, layer by layer (the same layer in the order of add), then empties the batch
//   b.count (sprites waiting), b.drawn (sprites drawn by the last flush), b.flush_to(int[] dst, w, h) for any buffer, b.clear().
// The atlas keeps the sprites in one Sprite (a.sheet), so a graphics chip can take it as ONE texture and the batch is one draw call.

struct Atlas {
    int w;
    int h;
    Sprite sheet;
    int[] rx;
    int[] ry;
    int[] rw;
    int[] rh;
    int pen_x;
    int pen_y;
    int row_h;

    static Atlas make(int w, int h) {
        Atlas a;
        a.w = w;
        a.h = h;
        a.sheet.w = w;
        a.sheet.h = h;
        a.sheet.argb = arr(w * h + 1);
        for i in 0..(w * h) { a.sheet.argb.push(0); }
        a.rx = arr(8);
        a.ry = arr(8);
        a.rw = arr(8);
        a.rh = arr(8);
        a.pen_x = 0;
        a.pen_y = 0;
        a.row_h = 0;
        return a;
    }

    int count(self) { return self.rx.len; }

    // packs a sprite; the number of it, or -1 when there is no room
    int add(self, Sprite s) {
        if s.w > self.w || s.h > self.h { return -1; }
        int px = self.pen_x;
        int py = self.pen_y;
        int rh = self.row_h;
        if px + s.w > self.w {
            px = 0;
            py += rh;
            rh = 0;
        }
        if py + s.h > self.h { return -1; }
        self.pen_x = px;
        self.pen_y = py;
        self.row_h = rh;
        for y in 0..s.h {
            for x in 0..s.w {
                self.sheet.argb[(self.pen_y + y) * self.w + self.pen_x + x] = s.argb[y * s.w + x];
            }
        }
        self.rx.push(self.pen_x);
        self.ry.push(self.pen_y);
        self.rw.push(s.w);
        self.rh.push(s.h);
        self.pen_x += s.w;
        if s.h > self.row_h { self.row_h = s.h; }
        return self.rx.len - 1;
    }
}

struct SpriteBatch {
    Atlas atlas;
    int[] items;                  // 5 numbers a sprite: layer, id, x, y, flip
    int count;
    int drawn;
    bool has_view;
    int vx;
    int vy;
    int vw;
    int vh;

    static SpriteBatch make(Atlas a) {
        SpriteBatch b;
        b.atlas = a;
        b.items = arr(64);
        b.count = 0;
        b.drawn = 0;
        b.has_view = false;
        return b;
    }

    // only sprites that touch this window are kept
    void view(self, int x, int y, int w, int h) {
        self.has_view = true;
        self.vx = x;
        self.vy = y;
        self.vw = w;
        self.vh = h;
    }

    void add(self, int id, int x, int y, int layer) { self.add_flip(id, x, y, layer, false); }

    void add_flip(self, int id, int x, int y, int layer, bool flip) {
        if id < 0 || id >= self.atlas.rx.len { return; }
        if layer < 0 { layer = 0; }
        if layer > 15 { layer = 15; }
        if self.has_view {
            if x + self.atlas.rw[id] <= self.vx || y + self.atlas.rh[id] <= self.vy || x >= self.vx + self.vw || y >= self.vy + self.vh { return; }
        }
        self.items.push(layer);
        self.items.push(id);
        self.items.push(x);
        self.items.push(y);
        if flip { self.items.push(1); } else { self.items.push(0); }
        self.count += 1;
    }

    void clear(self) {
        self.items.clear();
        self.count = 0;
    }

    // the order of drawing: layer by layer, inside a layer as added (a counting sort)
    int[] order(self) {
        int[] start = arr(17);
        for l in 0..17 { start.push(0); }
        for i in 0..self.count { start[self.items[i * 5] + 1] += 1; }
        for l in 1..17 { start[l] += start[l - 1]; }
        int[] o = arr(self.count + 1);
        for i in 0..self.count { o.push(0); }
        for i in 0..self.count {
            int l = self.items[i * 5];
            o[start[l]] = i;
            start[l] += 1;
        }
        return o;
    }

    void flush_to(self, int[] dst, int dw, int dh) {
        int[] o = self.order();
        for k in 0..self.count {
            int i = o[k] * 5;
            int id = self.items[i + 1];
            self.atlas.sheet.blit_part(dst, dw, dh, self.atlas.rx[id], self.atlas.ry[id], self.atlas.rw[id], self.atlas.rh[id], self.items[i + 2], self.items[i + 3], self.items[i + 4] == 1);
        }
        self.drawn = self.count;
        self.clear();
    }

    void flush(self, Game g) { self.flush_to(g.px, g.w, g.h); }
}
