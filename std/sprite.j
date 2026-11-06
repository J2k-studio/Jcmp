// sprite 0.1.0 -- pictures for games: a Sprite is a picture with see-through dots; draw it, a part of it (a sprite sheet), turned, scaled.
//   #import <deflate>  #import <png>  #import <gamej>  #import <sprite>   (needs jcmp 1.2.1.0; license: MPL-2.0)
//   bool ok; Sprite hero = Sprites::load("hero.png", @ok);   hero.draw(g, 10, 20);   hero.draw_part(g, 16, 0, 16, 16, 40, 40, false);   // the second tile of a sheet
//   Sprite tile = hero.cut(32, 0, 16, 16);   tile.draw_scaled(g, 0, 0, 3);
// The dots are numbers 0xAARRGGBB (alpha 255 = solid, 0 = see-through, between = mixed with what is on the screen). The drawing is clipped to the screen.
// blit* draw on any int[] of w * h dots (0xRRGGBB, like the screen of <gamej>), so that they can be used and tested without a window.

struct Sprite {
    i64 w;
    i64 h;
    i64[] argb;

    // one dot of the sprite on the screen buffer: alpha 0 skips it, 255 puts it, between mixes it with what was there
    static void put(i64[] dst, i64 dw, i64 dh, i64 x, i64 y, i64 c) {
        if x < 0 || y < 0 || x >= dw || y >= dh { return; }
        i64 a = (c >> 24) & 255;
        if a == 0 { return; }
        i64 at = y * dw + x;
        if a == 255 { dst[at] = c & 16777215; return; }
        i64 d = dst[at];
        i64 ia = 255 - a;
        i64 r = ((((c >> 16) & 255) * a) + (((d >> 16) & 255) * ia) + 127) / 255;
        i64 g = ((((c >> 8) & 255) * a) + (((d >> 8) & 255) * ia) + 127) / 255;
        i64 b = (((c & 255) * a) + ((d & 255) * ia) + 127) / 255;
        dst[at] = (r << 16) | (g << 8) | b;
    }

    // the whole sprite at (x, y)
    void blit(self, i64[] dst, i64 dw, i64 dh, i64 x, i64 y) {
        self.blit_part(dst, dw, dh, 0, 0, self.w, self.h, x, y, false);
    }

    // the part (sx, sy, sw, sh) of the sprite at (x, y); flip turns it left to right
    void blit_part(self, i64[] dst, i64 dw, i64 dh, i64 sx, i64 sy, i64 sw, i64 sh, i64 x, i64 y, bool flip) {
        for j in 0..sh {
            i64 yy = y + j;
            if yy < 0 || yy >= dh { continue; }
            i64 srow = (sy + j) * self.w;
            for i in 0..sw {
                i64 ii = i;
                if flip { ii = sw - 1 - i; }
                i64 px = sx + ii;
                if px < 0 || px >= self.w || sy + j < 0 || sy + j >= self.h { continue; }
                Sprite::put(dst, dw, dh, x + i, yy, self.argb[srow + px]);
            }
        }
    }

    // the whole sprite made bigger by a whole number (pixels stay sharp)
    void blit_scaled(self, i64[] dst, i64 dw, i64 dh, i64 x, i64 y, i64 scale) {
        if scale < 1 { return; }
        for j in 0..self.h {
            i64 srow = j * self.w;
            for i in 0..self.w {
                i64 c = self.argb[srow + i];
                for v in 0..scale {
                    for u in 0..scale { Sprite::put(dst, dw, dh, x + i * scale + u, y + j * scale + v, c); }
                }
            }
        }
    }

    void draw(self, Game g, i64 x, i64 y) { self.blit(g.px, g.w, g.h, x, y); }
    void draw_part(self, Game g, i64 sx, i64 sy, i64 sw, i64 sh, i64 x, i64 y, bool flip) { self.blit_part(g.px, g.w, g.h, sx, sy, sw, sh, x, y, flip); }
    void draw_scaled(self, Game g, i64 x, i64 y, i64 scale) { self.blit_scaled(g.px, g.w, g.h, x, y, scale); }

    // a new sprite made of a part of this one (a tile of a sheet)
    Sprite cut(self, i64 sx, i64 sy, i64 sw, i64 sh) {
        Sprite t;
        t.w = sw;
        t.h = sh;
        t.argb = arr(sw * sh + 1);
        for j in 0..sh {
            for i in 0..sw {
                i64 c = 0;
                i64 px = sx + i;
                i64 py = sy + j;
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
            i64 o = i * 4;
            i64 c = ((im.px[o + 3] & 255) << 24) | ((im.px[o] & 255) << 16) | ((im.px[o + 1] & 255) << 8) | (im.px[o + 2] & 255);
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
