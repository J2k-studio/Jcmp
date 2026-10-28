// sprite 0.1.0 -- pictures for games: a Sprite is a picture with see-through dots; draw it, a part of it (a sprite sheet), turned, scaled.
//   #import <deflate>  #import <png>  #import <gamej>  #import <sprite>   (needs jcmp 1.2.1.0; license: MPL-2.0)
//   bool ok; Sprite hero = Sprites::load("hero.png", @ok);   hero.draw(g, 10, 20);   hero.draw_part(g, 16, 0, 16, 16, 40, 40, false);   // the second tile of a sheet
//   Sprite tile = hero.cut(32, 0, 16, 16);   tile.draw_scaled(g, 0, 0, 3);
// The dots are numbers 0xAARRGGBB (alpha 255 = solid, 0 = see-through, between = mixed with what is on the screen). The drawing is clipped to the screen.
// blit* draw on any int[] of w * h dots (0xRRGGBB, like the screen of <gamej>), so that they can be used and tested without a window.

struct Sprite {
    int w;
    int h;
    int[] argb;

    // one dot of the sprite on the screen buffer: alpha 0 skips it, 255 puts it, between mixes it with what was there
    static void put(int[] dst, int dw, int dh, int x, int y, int c) {
        if x < 0 || y < 0 || x >= dw || y >= dh { return; }
        int a = (c >> 24) & 255;
        if a == 0 { return; }
        int at = y * dw + x;
        if a == 255 { dst[at] = c & 16777215; return; }
        int d = dst[at];
        int ia = 255 - a;
        int r = ((((c >> 16) & 255) * a) + (((d >> 16) & 255) * ia) + 127) / 255;
        int g = ((((c >> 8) & 255) * a) + (((d >> 8) & 255) * ia) + 127) / 255;
        int b = (((c & 255) * a) + ((d & 255) * ia) + 127) / 255;
        dst[at] = (r << 16) | (g << 8) | b;
    }

    // the whole sprite at (x, y)
    void blit(self, int[] dst, int dw, int dh, int x, int y) {
        self.blit_part(dst, dw, dh, 0, 0, self.w, self.h, x, y, false);
    }

    // the part (sx, sy, sw, sh) of the sprite at (x, y); flip turns it left to right
    void blit_part(self, int[] dst, int dw, int dh, int sx, int sy, int sw, int sh, int x, int y, bool flip) {
        for j in 0..sh {
            int yy = y + j;
            if yy < 0 || yy >= dh { continue; }
            int srow = (sy + j) * self.w;
            for i in 0..sw {
                int ii = i;
                if flip { ii = sw - 1 - i; }
                int px = sx + ii;
                if px < 0 || px >= self.w || sy + j < 0 || sy + j >= self.h { continue; }
                Sprite::put(dst, dw, dh, x + i, yy, self.argb[srow + px]);
            }
        }
    }

    // the whole sprite made bigger by a whole number (pixels stay sharp)
    void blit_scaled(self, int[] dst, int dw, int dh, int x, int y, int scale) {
        if scale < 1 { return; }
        for j in 0..self.h {
            int srow = j * self.w;
            for i in 0..self.w {
                int c = self.argb[srow + i];
                for v in 0..scale {
                    for u in 0..scale { Sprite::put(dst, dw, dh, x + i * scale + u, y + j * scale + v, c); }
                }
            }
        }
    }

    void draw(self, Game g, int x, int y) { self.blit(g.px, g.w, g.h, x, y); }
    void draw_part(self, Game g, int sx, int sy, int sw, int sh, int x, int y, bool flip) { self.blit_part(g.px, g.w, g.h, sx, sy, sw, sh, x, y, flip); }
    void draw_scaled(self, Game g, int x, int y, int scale) { self.blit_scaled(g.px, g.w, g.h, x, y, scale); }

    // a new sprite made of a part of this one (a tile of a sheet)
    Sprite cut(self, int sx, int sy, int sw, int sh) {
        Sprite t;
        t.w = sw;
        t.h = sh;
        t.argb = arr(sw * sh + 1);
        for j in 0..sh {
            for i in 0..sw {
                int c = 0;
                int px = sx + i;
                int py = sy + j;
                if px >= 0 && py >= 0 && px < self.w && py < self.h { c = self.argb[py * self.w + px]; }
                t.argb.push(c);
            }
        }
        return t;
    }
}

struct Sprites {
    // the sprite of a decoded picture
    static Sprite from_image(Image im) {
        Sprite s;
        s.w = im.w;
        s.h = im.h;
        s.argb = arr(im.w * im.h + 1);
        for i in 0..(im.w * im.h) {
            int o = i * 4;
            int c = ((im.px[o + 3] & 255) << 24) | ((im.px[o] & 255) << 16) | ((im.px[o + 1] & 255) << 8) | (im.px[o + 2] & 255);
            s.argb.push(c);
        }
        return s;
    }

    // a PNG file; ok = false when it cannot be read
    static Sprite load(String path, bool^ ok) {
        Sprite s;
        s.w = 0;
        s.h = 0;
        s.argb = arr(1);
        ok[0] = false;
        Result<String, Error> r = Fs::read_bytes(path);
        if !r.is_ok() { return s; }
        String data = r.take();
        bool good = false;
        Image im = Png::decode(data, @good);
        if !good { return s; }
        ok[0] = true;
        return Sprites::from_image(im);
    }
}
