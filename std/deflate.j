// deflate 0.1.0 -- CRC-32, DEFLATE (inflate + a compressor) and gzip.   #import <deflate>   (needs jcmp 1.1.0.0; license: MPL-2.0)
//   String z = Deflate::compress(data);   bool ok; String d = Deflate::decompress(z, ok);      // raw RFC 1951 bytes
//   String g = Gzip::pack(data);   String d2 = Gzip::unpack(g, ok);                             // .gz (RFC 1952), CRC checked
//   int c = Crc32::of(data);
// Bytes live in a String (it may hold any byte); read a byte as  s[i] & 255.  The compressor uses LZ77 with the fixed codes.

int[] dfl_crc_tab;
bool dfl_crc_ready;
void dfl_crc_init() {
    if dfl_crc_ready { return; }
    dfl_crc_ready = true;
    dfl_crc_tab = arr(256);
    for n in 0..256 {
        int c = n;
        for k in 0..8 {
            if (c & 1) != 0 { c = 3988292384 xor (c >> 1); } else { c = c >> 1; }
        }
        dfl_crc_tab.push(c);
    }
}
int dfl_crc_add(int crc, int b) {
    return dfl_crc_tab[(crc xor b) & 255] xor (crc >> 8);
}
int dfl_crc32_of(String data, int from, int to) {
    dfl_crc_init();
    int c = 4294967295;
    for i in from..to { c = dfl_crc_add(c, data[i] & 255); }
    return c xor 4294967295;
}

// ---------------------------------------------------------------- inflate (the method of RFC 1951)
String dfl_inf_src;
int dfl_inf_pos;
int dfl_inf_end;
int dfl_inf_buf;
int dfl_inf_cnt;
bool dfl_inf_bad;
String dfl_inf_out;

int dfl_inf_bits(int need) {
    int v = dfl_inf_buf;
    while dfl_inf_cnt < need {
        if dfl_inf_pos >= dfl_inf_end { dfl_inf_bad = true; return 0; }
        v = v | ((dfl_inf_src[dfl_inf_pos] & 255) << dfl_inf_cnt);
        dfl_inf_pos += 1;
        dfl_inf_cnt += 8;
    }
    dfl_inf_buf = v >> need;
    dfl_inf_cnt -= need;
    return v & ((1 << need) - 1);
}

// a table of codes: count[len] = how many codes have that length; sym = the symbols in the order of their codes
int[] dfl_fix_lcount;
int[] dfl_fix_lsym;
int[] dfl_fix_dcount;
int[] dfl_fix_dsym;

void dfl_huff_build(int[] lengths, int n, int[] count, int[] sym) {
    for i in 0..16 { count[i] = 0; }
    for i in 0..n { count[lengths[i]] += 1; }
    int[] offs = arr(16);
    for i in 0..16 { offs.push(0); }
    for i in 1..15 { offs[i + 1] = offs[i] + count[i]; }
    for i in 0..n {
        if lengths[i] != 0 { sym[offs[lengths[i]]] = i; offs[lengths[i]] += 1; }
    }
}

int dfl_huff_decode(int[] count, int[] sym) {
    int code = 0;
    int first = 0;
    int index = 0;
    for len in 1..16 {
        code = code | dfl_inf_bits(1);
        if dfl_inf_bad { return 0 - 1; }
        int c = count[len];
        if code - c < first { return sym[index + (code - first)]; }
        index += c;
        first += c;
        first = first << 1;
        code = code << 1;
    }
    return 0 - 1;
}

int[] dfl_len_base;
int[] dfl_len_extra;
int[] dfl_dist_base;
int[] dfl_dist_extra;
bool dfl_inf_ready;
void dfl_inf_tables() {
    if dfl_inf_ready { return; }
    dfl_inf_ready = true;
    dfl_len_base = arr(29);
    dfl_len_extra = arr(29);
    int[] lb = arr(29);
    String ls = "3 4 5 6 7 8 9 10 11 13 15 17 19 23 27 31 35 43 51 59 67 83 99 115 131 163 195 227 258";
    String[] lp = ls.split(" ");
    for i in 0..29 { dfl_len_base.push(lp[i].to_int()); }
    String es = "0 0 0 0 0 0 0 0 1 1 1 1 2 2 2 2 3 3 3 3 4 4 4 4 5 5 5 5 0";
    String[] ep = es.split(" ");
    for i in 0..29 { dfl_len_extra.push(ep[i].to_int()); }
    dfl_dist_base = arr(30);
    dfl_dist_extra = arr(30);
    String ds = "1 2 3 4 5 7 9 13 17 25 33 49 65 97 129 193 257 385 513 769 1025 1537 2049 3073 4097 6145 8193 12289 16385 24577";
    String[] dp = ds.split(" ");
    for i in 0..30 { dfl_dist_base.push(dp[i].to_int()); }
    String xs = "0 0 0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9 10 10 11 11 12 12 13 13";
    String[] xp = xs.split(" ");
    for i in 0..30 { dfl_dist_extra.push(xp[i].to_int()); }
    // the fixed codes
    int[] l = arr(288);
    for i in 0..288 {
        if i < 144 { l.push(8); } else if i < 256 { l.push(9); } else if i < 280 { l.push(7); } else { l.push(8); }
    }
    dfl_fix_lcount = arr(16);
    for i in 0..16 { dfl_fix_lcount.push(0); }
    dfl_fix_lsym = arr(288);
    for i in 0..288 { dfl_fix_lsym.push(0); }
    dfl_huff_build(l, 288, dfl_fix_lcount, dfl_fix_lsym);
    int[] d = arr(30);
    for i in 0..30 { d.push(5); }
    dfl_fix_dcount = arr(16);
    for i in 0..16 { dfl_fix_dcount.push(0); }
    dfl_fix_dsym = arr(30);
    for i in 0..30 { dfl_fix_dsym.push(0); }
    dfl_huff_build(d, 30, dfl_fix_dcount, dfl_fix_dsym);
}

bool dfl_inf_codes(int[] lc, int[] ls, int[] dc, int[] ds) {
    while true {
        int sym = dfl_huff_decode(lc, ls);
        if sym < 0 { return false; }
        if sym < 256 { dfl_inf_out.push((char)sym); }
        else if sym == 256 { return true; }
        else {
            sym -= 257;
            if sym >= 29 { return false; }
            int len = dfl_len_base[sym] + dfl_inf_bits(dfl_len_extra[sym]);
            int ds2 = dfl_huff_decode(dc, ds);
            if ds2 < 0 || ds2 >= 30 { return false; }
            int dist = dfl_dist_base[ds2] + dfl_inf_bits(dfl_dist_extra[ds2]);
            if dfl_inf_bad || dist > dfl_inf_out.len { return false; }
            for k in 0..len { dfl_inf_out.push(dfl_inf_out[dfl_inf_out.len - dist]); }
        }
    }
    return true;
}

// the bytes of src[from, to) are a raw deflate stream; the result is the data, or ok = false
String dfl_inflate_raw(String src, int from, int to, bool^ ok) {
    dfl_inf_tables();
    dfl_inf_src = src;
    dfl_inf_pos = from;
    dfl_inf_end = to;
    dfl_inf_buf = 0;
    dfl_inf_cnt = 0;
    dfl_inf_bad = false;
    dfl_inf_out = "";
    ok[0] = false;
    bool last = false;
    while !last {
        last = dfl_inf_bits(1) == 1;
        int type = dfl_inf_bits(2);
        if dfl_inf_bad { return ""; }
        if type == 0 {
            dfl_inf_buf = 0;
            dfl_inf_cnt = 0;
            if dfl_inf_pos + 4 > dfl_inf_end { return ""; }
            int n = (dfl_inf_src[dfl_inf_pos] & 255) | ((dfl_inf_src[dfl_inf_pos + 1] & 255) << 8);
            dfl_inf_pos += 4;
            if dfl_inf_pos + n > dfl_inf_end { return ""; }
            for i in 0..n { dfl_inf_out.push(dfl_inf_src[dfl_inf_pos + i]); }
            dfl_inf_pos += n;
        } else if type == 1 {
            if !dfl_inf_codes(dfl_fix_lcount, dfl_fix_lsym, dfl_fix_dcount, dfl_fix_dsym) { return ""; }
        } else if type == 2 {
            int nlen = dfl_inf_bits(5) + 257;
            int ndist = dfl_inf_bits(5) + 1;
            int ncode = dfl_inf_bits(4) + 4;
            if dfl_inf_bad || nlen > 286 || ndist > 30 { return ""; }
            int[] order = arr(19);
            String os = "16 17 18 0 8 7 9 6 10 5 11 4 12 3 13 2 14 1 15";
            String[] op = os.split(" ");
            for i in 0..19 { order.push(op[i].to_int()); }
            int[] lengths = arr(320);
            for i in 0..320 { lengths.push(0); }
            for i in 0..ncode { lengths[order[i]] = dfl_inf_bits(3); }
            int[] cc = arr(16);
            for i in 0..16 { cc.push(0); }
            int[] cs = arr(19);
            for i in 0..19 { cs.push(0); }
            dfl_huff_build(lengths, 19, cc, cs);
            int[] ll = arr(320);
            for i in 0..320 { ll.push(0); }
            int idx = 0;
            while idx < nlen + ndist {
                int sym = dfl_huff_decode(cc, cs);
                if sym < 0 { return ""; }
                if sym < 16 { ll[idx] = sym; idx += 1; }
                else {
                    int prev = 0;
                    int rep = 0;
                    if sym == 16 {
                        if idx == 0 { return ""; }
                        prev = ll[idx - 1];
                        rep = 3 + dfl_inf_bits(2);
                    } else if sym == 17 { rep = 3 + dfl_inf_bits(3); }
                    else { rep = 11 + dfl_inf_bits(7); }
                    if idx + rep > nlen + ndist { return ""; }
                    for i in 0..rep { ll[idx] = prev; idx += 1; }
                }
            }
            int[] lc = arr(16);
            for i in 0..16 { lc.push(0); }
            int[] lsym = arr(288);
            for i in 0..288 { lsym.push(0); }
            dfl_huff_build(ll, nlen, lc, lsym);
            int[] dl = arr(30);
            for i in 0..30 { dl.push(ll[nlen + i]); }
            int[] dc = arr(16);
            for i in 0..16 { dc.push(0); }
            int[] dsym = arr(30);
            for i in 0..30 { dsym.push(0); }
            dfl_huff_build(dl, ndist, dc, dsym);
            if !dfl_inf_codes(lc, lsym, dc, dsym) { return ""; }
        } else { return ""; }
        if dfl_inf_bad { return ""; }
    }
    ok[0] = true;
    return dfl_inf_out;
}

// ---------------------------------------------------------------- deflate (a compressor: LZ77 with a hash chain, the fixed codes)
String dfl_def_out;
int dfl_def_buf;
int dfl_def_cnt;
void dfl_def_put(int value, int nbits) {                  // bits go from the low end
    dfl_def_buf = dfl_def_buf | (value << dfl_def_cnt);
    dfl_def_cnt += nbits;
    while dfl_def_cnt >= 8 {
        dfl_def_out.push((char)(dfl_def_buf & 255));
        dfl_def_buf = dfl_def_buf >> 8;
        dfl_def_cnt -= 8;
    }
}
int dfl_rev_bits(int code, int n) {
    int r = 0;
    for i in 0..n { r = (r << 1) | ((code >> i) & 1); }
    return r;
}
void dfl_def_lit(int sym) {                               // the fixed code of a literal or length symbol (0 .. 287): the code goes from its high bit
    if sym < 144 { dfl_def_put(dfl_rev_bits(48 + sym, 8), 8); }
    else if sym < 256 { dfl_def_put(dfl_rev_bits(400 + sym - 144, 9), 9); }
    else if sym < 280 { dfl_def_put(dfl_rev_bits(sym - 256, 7), 7); }
    else { dfl_def_put(dfl_rev_bits(192 + sym - 280, 8), 8); }
}

String dfl_deflate_raw(String data) {
    dfl_inf_tables();
    dfl_def_out = "";
    dfl_def_buf = 0;
    dfl_def_cnt = 0;
    int n = data.len;
    dfl_def_put(1, 1);                                    // the last block
    dfl_def_put(1, 2);                                    // fixed codes
    int[] head = arr(65536);
    for i in 0..65536 { head.push(0 - 1); }
    int[] prev = arr(32768);
    for i in 0..32768 { prev.push(0 - 1); }
    int i = 0;
    while i < n {
        int best = 0;
        int bdist = 0;
        if i + 2 < n {
            int h = (((data[i] & 255) << 8) xor ((data[i + 1] & 255) << 4) xor (data[i + 2] & 255)) & 65535;
            int cand = head[h];
            int tries = 0;
            while cand >= 0 && i - cand <= 32768 && tries < 48 {
                int m = 0;
                while m < 258 && i + m < n && data[cand + m] == data[i + m] { m += 1; }
                if m > best { best = m; bdist = i - cand; if m == 258 { break; } }
                cand = prev[cand & 32767];
                tries += 1;
            }
            prev[i & 32767] = head[h];
            head[h] = i;
        }
        if best >= 3 {
            int ls = 28;
            while dfl_len_base[ls] > best { ls -= 1; }
            dfl_def_lit(257 + ls);
            dfl_def_put(best - dfl_len_base[ls], dfl_len_extra[ls]);
            int ds = 29;
            while dfl_dist_base[ds] > bdist { ds -= 1; }
            dfl_def_put(dfl_rev_bits(ds, 5), 5);
            dfl_def_put(bdist - dfl_dist_base[ds], dfl_dist_extra[ds]);
            for k in 1..best {                         // the places inside the match go into the chain too
                int p = i + k;
                if p + 2 < n {
                    int h2 = (((data[p] & 255) << 8) xor ((data[p + 1] & 255) << 4) xor (data[p + 2] & 255)) & 65535;
                    prev[p & 32767] = head[h2];
                    head[h2] = p;
                }
            }
            i += best;
        } else {
            dfl_def_lit(data[i] & 255);
            i += 1;
        }
    }
    dfl_def_lit(256);
    if dfl_def_cnt > 0 { dfl_def_out.push((char)(dfl_def_buf & 255)); }
    return dfl_def_out;
}


struct Crc32 {
    static int of(String data) { return dfl_crc32_of(data, 0, data.len); }
}

struct Deflate {
    static String compress(String data) { return dfl_deflate_raw(data); }
    static String decompress(String z, bool^ ok) { return dfl_inflate_raw(z, 0, z.len, ok); }
}

struct Gzip {
    static String pack(String data) {
        String r = "";
        r.push((char)31); r.push((char)139); r.push((char)8); r.push((char)0);
        for i in 0..4 { r.push((char)0); }
        r.push((char)0); r.push((char)255);
        r.append(dfl_deflate_raw(data));
        int c = dfl_crc32_of(data, 0, data.len);
        for i in 0..4 { r.push((char)((c >> (8 * i)) & 255)); }
        for i in 0..4 { r.push((char)((data.len >> (8 * i)) & 255)); }
        return r;
    }
    // ok = false when the header, the CRC or the length is wrong
    static String unpack(String g, bool^ ok) {
        ok[0] = false;
        if g.len < 18 { return ""; }
        if (g[0] & 255) != 31 || (g[1] & 255) != 139 || (g[2] & 255) != 8 { return ""; }
        int flg = g[3] & 255;
        int p = 10;
        if (flg & 4) != 0 { p += 2 + (g[p] & 255) + ((g[p + 1] & 255) << 8); }
        if (flg & 8) != 0 { while p < g.len && g[p] != 0 { p += 1; } p += 1; }
        if (flg & 16) != 0 { while p < g.len && g[p] != 0 { p += 1; } p += 1; }
        if (flg & 2) != 0 { p += 2; }
        if p >= g.len - 8 { return ""; }
        bool ok2;
        String d = dfl_inflate_raw(g, p, g.len - 8, @ok2);
        if !ok2 { return ""; }
        int q = g.len - 8;
        int crc = (g[q] & 255) | ((g[q + 1] & 255) << 8) | ((g[q + 2] & 255) << 16) | ((g[q + 3] & 255) << 24);
        if crc != dfl_crc32_of(d, 0, d.len) { return ""; }
        ok[0] = true;
        return d;
    }
}
