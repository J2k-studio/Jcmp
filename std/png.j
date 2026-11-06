// png 0.1.0 -- reads PNG pictures.   #import <deflate>   #import <png>   (needs jcmp 1.2.1.0; license: MPL-2.0)
//   bool ok; Image im = Png::decode(Fs::read_bytes("hero.png").unwrap(), @ok);   im.w, im.h, im.px (4 bytes for each dot: red, green, blue, alpha)
// All the kinds of PNG without interlacing: grey, grey + alpha, red green blue, with alpha, and palettes (also tRNS), 1 to 16 bits for each part (16 bits are cut to 8).
// A picture with Adam7 interlacing gives ok = false (it comes later). The bytes live in a String (a byte is s[i] & 255).

struct Image {
    i64 w;
    i64 h;
    String px;                        // w * h * 4 bytes: red, green, blue, alpha of each dot, row by row from the top

    // one part of the dot (x, y), 0 to 255
    i64 red(self, i64 x, i64 y) { return self.px[(y * self.w + x) * 4] & 255; }
    i64 green(self, i64 x, i64 y) { return self.px[(y * self.w + x) * 4 + 1] & 255; }
    i64 blue(self, i64 x, i64 y) { return self.px[(y * self.w + x) * 4 + 2] & 255; }
    i64 alpha(self, i64 x, i64 y) { return self.px[(y * self.w + x) * 4 + 3] & 255; }
}

i64 png_be32(String s, i64 at) { return ((s[at] & 255) << 24) | ((s[at + 1] & 255) << 16) | ((s[at + 2] & 255) << 8) | (s[at + 3] & 255); }

i64 png_paeth(i64 a, i64 b, i64 c) {
    i64 p = a + b - c;
    i64 pa = p - a;
    if pa < 0 { pa = 0 - pa; }
    i64 pb = p - b;
    if pb < 0 { pb = 0 - pb; }
    i64 pc = p - c;
    if pc < 0 { pc = 0 - pc; }
    if pa <= pb && pa <= pc { return a; }
    if pb <= pc { return b; }
    return c;
}

// one part (sample) number k of the row at row_at: 1, 2, 4, 8 or 16 bits; the result is cut to 0..255 (and scaled when the part has fewer bits)
i64 png_sample(String raw, i64 row_at, i64 k, i64 depth, bool scale) {
    if depth == 8 { return raw[row_at + k] & 255; }
    if depth == 16 { return raw[row_at + k * 2] & 255; }
    i64 bit = k * depth;
    i64 b = raw[row_at + bit / 8] & 255;
    i64 shift = 8 - depth - (bit % 8);
    i64 v = (b >> shift) & ((1 << depth) - 1);
    if scale {
        if depth == 1 { return v * 255; }
        if depth == 2 { return v * 85; }
        return v * 17;
    }
    return v;
}

struct Png {
    static Image decode(String data, bool^ ok) {
        Image im;
        ok[0] = false;
        im.w = 0;
        im.h = 0;
        im.px = "";
        if data.len < 33 { return im; }
        i64 sig[8];
        sig[0] = 137; sig[1] = 80; sig[2] = 78; sig[3] = 71; sig[4] = 13; sig[5] = 10; sig[6] = 26; sig[7] = 10;
        for i in 0..8 { if (data[i] & 255) != sig[i] { return im; } }
        i64 w = 0;
        i64 h = 0;
        i64 depth = 0;
        i64 ctype = 0;
        i64 interlace = 0;
        String idat = "";
        String pal = "";
        String trns = "";
        i64 at = 8;
        while at + 12 <= data.len {
            i64 len = png_be32(data, at);
            if len < 0 || at + 12 + len > data.len { return im; }
            i64 t0 = data[at + 4] & 255;
            i64 t1 = data[at + 5] & 255;
            i64 t2 = data[at + 6] & 255;
            i64 t3 = data[at + 7] & 255;
            i64 body = at + 8;
            if t0 == 73 && t1 == 72 && t2 == 68 && t3 == 82 {                 // IHDR
                if len < 13 { return im; }
                w = png_be32(data, body);
                h = png_be32(data, body + 4);
                depth = data[body + 8] & 255;
                ctype = data[body + 9] & 255;
                interlace = data[body + 12] & 255;
            } else if t0 == 80 && t1 == 76 && t2 == 84 && t3 == 69 {          // PLTE
                for k in 0..len { pal.push(data[body + k]); }
            } else if t0 == 116 && t1 == 82 && t2 == 78 && t3 == 83 {         // tRNS
                for k in 0..len { trns.push(data[body + k]); }
            } else if t0 == 73 && t1 == 68 && t2 == 65 && t3 == 84 {          // IDAT
                for k in 0..len { idat.push(data[body + k]); }
            } else if t0 == 73 && t1 == 69 && t2 == 78 && t3 == 68 {          // IEND
                break;
            }
            at += 12 + len;
        }
        if w < 1 || h < 1 || w > 16384 || h > 16384 || interlace != 0 || idat.len < 7 { return im; }
        i64 channels = 1;
        if ctype == 2 { channels = 3; }
        if ctype == 4 { channels = 2; }
        if ctype == 6 { channels = 4; }
        if ctype != 0 && ctype != 2 && ctype != 3 && ctype != 4 && ctype != 6 { return im; }
        if depth != 1 && depth != 2 && depth != 4 && depth != 8 && depth != 16 { return im; }
        bool good = false;
        String raw = dfl_inflate_raw(idat, 2, idat.len - 4, @good);               // a zlib stream: two bytes in front, four of check at the end
        if !good { return im; }
        i64 bpp_bits = channels * depth;
        i64 rowbytes = (w * bpp_bits + 7) / 8;
        i64 step = bpp_bits / 8;
        if step < 1 { step = 1; }
        if raw.len < h * (rowbytes + 1) { return im; }
        // take the filters away, row by row (in place)
        for y in 0..h {
            i64 rs = y * (rowbytes + 1);
            i64 f = raw[rs] & 255;
            i64 row = rs + 1;
            i64 prev = row - (rowbytes + 1);
            for i in 0..rowbytes {
                i64 cur = raw[row + i] & 255;
                i64 a = 0;
                if i >= step { a = raw[row + i - step] & 255; }
                i64 b = 0;
                if y > 0 { b = raw[prev + i] & 255; }
                i64 c = 0;
                if y > 0 && i >= step { c = raw[prev + i - step] & 255; }
                i64 v = cur;
                if f == 1 { v = cur + a; }
                else if f == 2 { v = cur + b; }
                else if f == 3 { v = cur + (a + b) / 2; }
                else if f == 4 { v = cur + png_paeth(a, b, c); }
                raw[row + i] = (char)(v & 255);
            }
        }
        // to red, green, blue, alpha
        String px = "";
        for i in 0..(w * h * 4) { px.push((char)0); }
        i64 tkey = 0 - 1;                                                         // a grey colour that is see-through (tRNS of a grey picture)
        i64 tr = 0 - 1;
        i64 tg = 0 - 1;
        i64 tb = 0 - 1;
        if ctype == 0 && trns.len >= 2 { tkey = ((trns[0] & 255) << 8) | (trns[1] & 255); }
        if ctype == 2 && trns.len >= 6 {
            tr = ((trns[0] & 255) << 8) | (trns[1] & 255);
            tg = ((trns[2] & 255) << 8) | (trns[3] & 255);
            tb = ((trns[4] & 255) << 8) | (trns[5] & 255);
        }
        for y in 0..h {
            i64 row = y * (rowbytes + 1) + 1;
            for x in 0..w {
                i64 o = (y * w + x) * 4;
                i64 r = 0;
                i64 g = 0;
                i64 b = 0;
                i64 a = 255;
                if ctype == 0 {
                    i64 v = png_sample(raw, row, x, depth, true);
                    r = v; g = v; b = v;
                    if tkey >= 0 {
                        i64 full = 0;
                        if depth == 16 { full = ((raw[row + x * 2] & 255) << 8) | (raw[row + x * 2 + 1] & 255); } else { full = png_sample(raw, row, x, depth, false); }
                        if full == tkey { a = 0; }
                    }
                } else if ctype == 2 {
                    r = png_sample(raw, row, x * 3, depth, true);
                    g = png_sample(raw, row, x * 3 + 1, depth, true);
                    b = png_sample(raw, row, x * 3 + 2, depth, true);
                    if tr >= 0 {
                        i64 fr = 0;
                        i64 fg = 0;
                        i64 fb = 0;
                        if depth == 16 {
                            fr = ((raw[row + x * 6] & 255) << 8) | (raw[row + x * 6 + 1] & 255);
                            fg = ((raw[row + x * 6 + 2] & 255) << 8) | (raw[row + x * 6 + 3] & 255);
                            fb = ((raw[row + x * 6 + 4] & 255) << 8) | (raw[row + x * 6 + 5] & 255);
                        } else {
                            fr = png_sample(raw, row, x * 3, depth, false);
                            fg = png_sample(raw, row, x * 3 + 1, depth, false);
                            fb = png_sample(raw, row, x * 3 + 2, depth, false);
                        }
                        if fr == tr && fg == tg && fb == tb { a = 0; }
                    }
                } else if ctype == 3 {
                    i64 idx = png_sample(raw, row, x, depth, false);
                    if idx * 3 + 2 < pal.len { r = pal[idx * 3] & 255; g = pal[idx * 3 + 1] & 255; b = pal[idx * 3 + 2] & 255; }
                    if idx < trns.len { a = trns[idx] & 255; }
                } else if ctype == 4 {
                    i64 v = png_sample(raw, row, x * 2, depth, true);
                    r = v; g = v; b = v;
                    a = png_sample(raw, row, x * 2 + 1, depth, true);
                } else {
                    r = png_sample(raw, row, x * 4, depth, true);
                    g = png_sample(raw, row, x * 4 + 1, depth, true);
                    b = png_sample(raw, row, x * 4 + 2, depth, true);
                    a = png_sample(raw, row, x * 4 + 3, depth, true);
                }
                px[o] = (char)r;
                px[o + 1] = (char)g;
                px[o + 2] = (char)b;
                px[o + 3] = (char)a;
            }
        }
        im.w = w;
        im.h = h;
        im.px = px;
        ok[0] = true;
        return im;
    }
}
