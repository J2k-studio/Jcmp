// Crypto: the hashes and the key derivation that TLS needs, on raw bytes (a pointer and a length; the answer goes to a buffer the caller gives).
//   SHA-384 / SHA-512 (FIPS 180-4), HMAC (RFC 2104), HKDF (RFC 5869). Tested with the vectors of the RFCs (test/t456_crypto.jk).
//   char out[48];   Crypto::sha384(data, n, @out);
// Designed by the assistant (2026-10-17, the first pieces of TLS for jget: docs/design/17-tls.md), adjustable. Not constant time.
struct Crypto {
    static void sha512_init(int^ h) {
        h[0] = 7640891576956012808;
        h[1] = -4942790177534073029;
        h[2] = 4354685564936845355;
        h[3] = -6534734903238641935;
        h[4] = 5840696475078001361;
        h[5] = -7276294671716946913;
        h[6] = 2270897969802886507;
        h[7] = 6620516959819538809;
    }
    static void sha384_init(int^ h) {
        h[0] = -3766243637369397544;
        h[1] = 7105036623409894663;
        h[2] = -7973340178411365097;
        h[3] = 1526699215303891257;
        h[4] = 7436329637833083697;
        h[5] = -8163818279084223215;
        h[6] = -2662702644619276377;
        h[7] = 5167115440072839076;
    }
    static void sha512_constants(int^ k) {
        k[0] = 4794697086780616226;
        k[1] = 8158064640168781261;
        k[2] = -5349999486874862801;
        k[3] = -1606136188198331460;
        k[4] = 4131703408338449720;
        k[5] = 6480981068601479193;
        k[6] = -7908458776815382629;
        k[7] = -6116909921290321640;
        k[8] = -2880145864133508542;
        k[9] = 1334009975649890238;
        k[10] = 2608012711638119052;
        k[11] = 6128411473006802146;
        k[12] = 8268148722764581231;
        k[13] = -9160688886553864527;
        k[14] = -7215885187991268811;
        k[15] = -4495734319001033068;
        k[16] = -1973867731355612462;
        k[17] = -1171420211273849373;
        k[18] = 1135362057144423861;
        k[19] = 2597628984639134821;
        k[20] = 3308224258029322869;
        k[21] = 5365058923640841347;
        k[22] = 6679025012923562964;
        k[23] = 8573033837759648693;
        k[24] = -7476448914759557205;
        k[25] = -6327057829258317296;
        k[26] = -5763719355590565569;
        k[27] = -4658551843659510044;
        k[28] = -4116276920077217854;
        k[29] = -3051310485924567259;
        k[30] = 489312712824947311;
        k[31] = 1452737877330783856;
        k[32] = 2861767655752347644;
        k[33] = 3322285676063803686;
        k[34] = 5560940570517711597;
        k[35] = 5996557281743188959;
        k[36] = 7280758554555802590;
        k[37] = 8532644243296465576;
        k[38] = -9096487096722542874;
        k[39] = -7894198246740708037;
        k[40] = -6719396339535248540;
        k[41] = -6333637450476146687;
        k[42] = -4446306890439682159;
        k[43] = -4076793802049405392;
        k[44] = -3345356375505022440;
        k[45] = -2983346525034927856;
        k[46] = -860691631967231958;
        k[47] = 1182934255886127544;
        k[48] = 1847814050463011016;
        k[49] = 2177327727835720531;
        k[50] = 2830643537854262169;
        k[51] = 3796741975233480872;
        k[52] = 4115178125766777443;
        k[53] = 5681478168544905931;
        k[54] = 6601373596472566643;
        k[55] = 7507060721942968483;
        k[56] = 8399075790359081724;
        k[57] = 8693463985226723168;
        k[58] = -8878714635349349518;
        k[59] = -8302665154208450068;
        k[60] = -8016688836872298968;
        k[61] = -6606660893046293015;
        k[62] = -4685533653050689259;
        k[63] = -4147400797238176981;
        k[64] = -3880063495543823972;
        k[65] = -3348786107499101689;
        k[66] = -1523767162380948706;
        k[67] = -757361751448694408;
        k[68] = 500013540394364858;
        k[69] = 748580250866718886;
        k[70] = 1242879168328830382;
        k[71] = 1977374033974150939;
        k[72] = 2944078676154940804;
        k[73] = 3659926193048069267;
        k[74] = 4368137639120453308;
        k[75] = 4836135668995329356;
        k[76] = 5532061633213252278;
        k[77] = 6448918945643986474;
        k[78] = 6902733635092675308;
        k[79] = 7801388544844847127;
    }
    // the 64-bit right rotation (the shift of a whole number is arithmetic, so the high bits are cut)
    static int rotr64(int x, int n) {
        return ((x >> n) & ((1 << (64 - n)) - 1)) | (x << (64 - n));
    }
    static int shr64(int x, int n) {
        return (x >> n) & ((1 << (64 - n)) - 1);
    }
    static int load64(char^ p) {
        int v = 0;
        for i in 0..8 { v = (v << 8) | (p[i] & 255); }
        return v;
    }
    static void store64(char^ p, int v) {
        for i in 0..8 { p[i] = (char)((v >> (56 - i * 8)) & 255); }
    }
    // one block of 128 bytes; h: the 8 words of the state; k: the 80 constants; w: 80 words of room
    static void sha512_block(int^ h, int^ k, int^ w, char^ blk) {
        for t in 0..16 { w[t] = Crypto::load64(blk + t * 8); }
        for t in 16..80 {
            int x = w[t - 15];
            int s0 = Crypto::rotr64(x, 1) xor Crypto::rotr64(x, 8) xor Crypto::shr64(x, 7);
            int y = w[t - 2];
            int s1 = Crypto::rotr64(y, 19) xor Crypto::rotr64(y, 61) xor Crypto::shr64(y, 6);
            w[t] = w[t - 16] + s0 + w[t - 7] + s1;
        }
        int a = h[0];
        int b = h[1];
        int c = h[2];
        int d = h[3];
        int e = h[4];
        int f = h[5];
        int g = h[6];
        int hh = h[7];
        for t in 0..80 {
            int S1 = Crypto::rotr64(e, 14) xor Crypto::rotr64(e, 18) xor Crypto::rotr64(e, 41);
            int ch = (e & f) xor ((~e) & g);
            int t1 = hh + S1 + ch + k[t] + w[t];
            int S0 = Crypto::rotr64(a, 28) xor Crypto::rotr64(a, 34) xor Crypto::rotr64(a, 39);
            int maj = (a & b) xor (a & c) xor (b & c);
            int t2 = S0 + maj;
            hh = g;
            g = f;
            f = e;
            e = d + t1;
            d = c;
            c = b;
            b = a;
            a = t1 + t2;
        }
        h[0] = h[0] + a;
        h[1] = h[1] + b;
        h[2] = h[2] + c;
        h[3] = h[3] + d;
        h[4] = h[4] + e;
        h[5] = h[5] + f;
        h[6] = h[6] + g;
        h[7] = h[7] + hh;
    }
    // the digest of n bytes: bits = 512 (64 bytes out) or 384 (48 bytes out)
    static void sha512_family(int bits, char^ data, int n, char^ out) {
        int h[8];
        int k[80];
        int w[80];
        if bits == 384 { Crypto::sha384_init((int^)@h); } else { Crypto::sha512_init((int^)@h); }
        Crypto::sha512_constants((int^)@k);
        int pos = 0;
        while n - pos >= 128 {
            Crypto::sha512_block((int^)@h, (int^)@k, (int^)@w, data + pos);
            pos += 128;
        }
        char tail[256];
        for i in 0..256 { tail[i] = 0; }
        int tn = n - pos;
        for i in 0..tn { tail[i] = data[pos + i]; }
        tail[tn] = (char)128;
        int m = 128;
        if tn >= 112 { m = 256; }
        int total_bits = n * 8;
        for i in 0..8 { tail[m - 1 - i] = (char)((total_bits >> (i * 8)) & 255); }
        Crypto::sha512_block((int^)@h, (int^)@k, (int^)@w, (char^)@tail);
        if m == 256 { Crypto::sha512_block((int^)@h, (int^)@k, (int^)@w, (char^)@tail + 128); }
        int words = 8;
        if bits == 384 { words = 6; }
        for i in 0..words { Crypto::store64(out + i * 8, h[i]); }
    }
    static void sha384(char^ data, int n, char^ out) { Crypto::sha512_family(384, data, n, out); }
    static void sha512(char^ data, int n, char^ out) { Crypto::sha512_family(512, data, n, out); }
    // SHA-256 on raw bytes (the digest of 32 bytes goes to out)
    static void sha256(char^ data, int n, char^ out) {
        int st[136];
        Sha256::init((int^)@st);
        Sha256::constants((int^)@st);
        int pos = 0;
        while n - pos >= 64 {
            Sha256::block((int^)@st, data + pos);
            pos += 64;
        }
        char buf[128];
        for i in 0..128 { buf[i] = 0; }
        int tn = n - pos;
        for i in 0..tn { buf[i] = data[pos + i]; }
        buf[tn] = (char)128;
        int m = 64;
        if tn >= 56 { m = 128; }
        int bits = n * 8;
        for i in 0..8 { buf[m - 1 - i] = (char)((bits >> (i * 8)) & 255); }
        Sha256::block((int^)@st, (char^)@buf);
        if m == 128 { Sha256::block((int^)@st, (char^)@buf + 64); }
        for i in 0..8 {
            for j in 0..4 { out[i * 4 + j] = (char)((st[i] >> (24 - j * 8)) & 255); }
        }
    }
    // the digest of the algorithm alg (256, 384 or 512); the number of bytes it gives
    static int hash(int alg, char^ data, int n, char^ out) {
        if alg == 256 { Crypto::sha256(data, n, out); return 32; }
        if alg == 384 { Crypto::sha384(data, n, out); return 48; }
        Crypto::sha512(data, n, out);
        return 64;
    }
    static int hash_size(int alg) {
        if alg == 256 { return 32; }
        if alg == 384 { return 48; }
        return 64;
    }
    // HMAC (RFC 2104) with the hash alg; out gets hash_size(alg) bytes
    static void hmac(int alg, char^ key, int klen, char^ msg, int mlen, char^ out) {
        int bs = 64;
        if alg != 256 { bs = 128; }
        int hs = Crypto::hash_size(alg);
        char k0[128];
        for i in 0..128 { k0[i] = 0; }
        if klen > bs {
            Crypto::hash(alg, key, klen, (char^)@k0);
        } else {
            for i in 0..klen { k0[i] = key[i]; }
        }
        char^ inner = (char^)Mem::alloc(bs + mlen + 1);
        for i in 0..bs { inner[i] = (char)(k0[i] xor 54); }
        for i in 0..mlen { inner[bs + i] = msg[i]; }
        char ih[64];
        Crypto::hash(alg, inner, bs + mlen, (char^)@ih);
        Mem::free((void^)inner);
        char outer[192];
        for i in 0..bs { outer[i] = (char)(k0[i] xor 92); }
        for i in 0..hs { outer[bs + i] = ih[i]; }
        Crypto::hash(alg, (char^)@outer, bs + hs, out);
    }
    // HKDF-Extract (RFC 5869): prk = HMAC(salt, ikm); an empty salt is hash_size zero bytes
    static void hkdf_extract(int alg, char^ salt, int slen, char^ ikm, int ilen, char^ prk) {
        if slen == 0 {
            char zeros[64];
            for i in 0..64 { zeros[i] = 0; }
            Crypto::hmac(alg, (char^)@zeros, Crypto::hash_size(alg), ikm, ilen, prk);
        } else {
            Crypto::hmac(alg, salt, slen, ikm, ilen, prk);
        }
    }
    // HKDF-Expand: length bytes of output keying material (length <= 255 * hash_size)
    static void hkdf_expand(int alg, char^ prk, int plen, char^ info, int ilen, char^ okm, int length) {
        int hs = Crypto::hash_size(alg);
        char^ buf = (char^)Mem::alloc(hs + ilen + 2);
        char t[64];
        int tn = 0;
        int done = 0;
        int counter = 1;
        while done < length {
            for i in 0..tn { buf[i] = t[i]; }
            for i in 0..ilen { buf[tn + i] = info[i]; }
            buf[tn + ilen] = (char)counter;
            Crypto::hmac(alg, prk, plen, buf, tn + ilen + 1, (char^)@t);
            tn = hs;
            int take = length - done;
            if take > hs { take = hs; }
            for i in 0..take { okm[done + i] = t[i]; }
            done += take;
            counter += 1;
        }
        Mem::free((void^)buf);
    }
    // ---------------------------------------------------------------- ChaCha20 and Poly1305 (RFC 8439)
    static int rotl32(int x, int n) {
        x = x & 0xFFFFFFFF;
        return ((x << n) | (x >> (32 - n))) & 0xFFFFFFFF;
    }
    static int le32(char^ p) {
        return (p[0] & 255) | ((p[1] & 255) << 8) | ((p[2] & 255) << 16) | ((p[3] & 255) << 24);
    }
    static void put_le32(char^ p, int v) {
        p[0] = (char)(v & 255);
        p[1] = (char)((v >> 8) & 255);
        p[2] = (char)((v >> 16) & 255);
        p[3] = (char)((v >> 24) & 255);
    }
    static void chacha_quarter(int^ x, int a, int b, int c, int d) {
        x[a] = (x[a] + x[b]) & 0xFFFFFFFF; x[d] = Crypto::rotl32(x[d] xor x[a], 16);
        x[c] = (x[c] + x[d]) & 0xFFFFFFFF; x[b] = Crypto::rotl32(x[b] xor x[c], 12);
        x[a] = (x[a] + x[b]) & 0xFFFFFFFF; x[d] = Crypto::rotl32(x[d] xor x[a], 8);
        x[c] = (x[c] + x[d]) & 0xFFFFFFFF; x[b] = Crypto::rotl32(x[b] xor x[c], 7);
    }
    // one block of 64 bytes of the key stream: key 32 bytes, nonce 12 bytes
    static void chacha20_block(char^ key, int counter, char^ nonce, char^ out) {
        int s[16];
        s[0] = 0x61707865;
        s[1] = 0x3320646e;
        s[2] = 0x79622d32;
        s[3] = 0x6b206574;
        for i in 0..8 { s[4 + i] = Crypto::le32(key + i * 4); }
        s[12] = counter & 0xFFFFFFFF;
        for i in 0..3 { s[13 + i] = Crypto::le32(nonce + i * 4); }
        int x[16];
        for i in 0..16 { x[i] = s[i]; }
        for r in 0..10 {
            Crypto::chacha_quarter((int^)@x, 0, 4, 8, 12);
            Crypto::chacha_quarter((int^)@x, 1, 5, 9, 13);
            Crypto::chacha_quarter((int^)@x, 2, 6, 10, 14);
            Crypto::chacha_quarter((int^)@x, 3, 7, 11, 15);
            Crypto::chacha_quarter((int^)@x, 0, 5, 10, 15);
            Crypto::chacha_quarter((int^)@x, 1, 6, 11, 12);
            Crypto::chacha_quarter((int^)@x, 2, 7, 8, 13);
            Crypto::chacha_quarter((int^)@x, 3, 4, 9, 14);
        }
        for i in 0..16 { Crypto::put_le32(out + i * 4, (x[i] + s[i]) & 0xFFFFFFFF); }
    }
    // data xor key stream (encrypts and decrypts); the first block uses `counter`; out may be the same buffer as in
    static void chacha20_xor(char^ key, int counter, char^ nonce, char^ in, int n, char^ out) {
        char block[64];
        int pos = 0;
        while pos < n {
            Crypto::chacha20_block(key, counter, nonce, (char^)@block);
            counter += 1;
            int take = n - pos;
            if take > 64 { take = 64; }
            for i in 0..take { out[pos + i] = (char)(in[pos + i] xor block[i]); }
            pos += take;
        }
    }
    // Poly1305 of n bytes with the one-time key (32 bytes); the tag (16 bytes) goes to out
    static void poly1305(char^ key, char^ msg, int n, char^ out) {
        int r0 = Crypto::le32(key) & 0x3ffffff;
        int r1 = (Crypto::le32(key + 3) >> 2) & 0x3ffff03;
        int r2 = (Crypto::le32(key + 6) >> 4) & 0x3ffc0ff;
        int r3 = (Crypto::le32(key + 9) >> 6) & 0x3f03fff;
        int r4 = (Crypto::le32(key + 12) >> 8) & 0x00fffff;
        int s1 = r1 * 5;
        int s2 = r2 * 5;
        int s3 = r3 * 5;
        int s4 = r4 * 5;
        int h0 = 0;
        int h1 = 0;
        int h2 = 0;
        int h3 = 0;
        int h4 = 0;
        char blk[17];
        int pos = 0;
        while pos < n {
            int take = n - pos;
            int hibit = 1 << 24;
            if take >= 16 {
                take = 16;
                for i in 0..16 { blk[i] = msg[pos + i]; }
            } else {
                for i in 0..17 { blk[i] = 0; }
                for i in 0..take { blk[i] = msg[pos + i]; }
                blk[take] = (char)1;
                hibit = 0;
            }
            blk[16] = 0;
            h0 += Crypto::le32((char^)@blk) & 0x3ffffff;
            h1 += (Crypto::le32((char^)@blk + 3) >> 2) & 0x3ffffff;
            h2 += (Crypto::le32((char^)@blk + 6) >> 4) & 0x3ffffff;
            h3 += (Crypto::le32((char^)@blk + 9) >> 6) & 0x3ffffff;
            h4 += (Crypto::le32((char^)@blk + 12) >> 8) | hibit;
            int d0 = h0 * r0 + h1 * s4 + h2 * s3 + h3 * s2 + h4 * s1;
            int d1 = h0 * r1 + h1 * r0 + h2 * s4 + h3 * s3 + h4 * s2;
            int d2 = h0 * r2 + h1 * r1 + h2 * r0 + h3 * s4 + h4 * s3;
            int d3 = h0 * r3 + h1 * r2 + h2 * r1 + h3 * r0 + h4 * s4;
            int d4 = h0 * r4 + h1 * r3 + h2 * r2 + h3 * r1 + h4 * r0;
            int c = d0 >> 26;
            h0 = d0 & 0x3ffffff;
            d1 += c;
            c = d1 >> 26;
            h1 = d1 & 0x3ffffff;
            d2 += c;
            c = d2 >> 26;
            h2 = d2 & 0x3ffffff;
            d3 += c;
            c = d3 >> 26;
            h3 = d3 & 0x3ffffff;
            d4 += c;
            c = d4 >> 26;
            h4 = d4 & 0x3ffffff;
            h0 += c * 5;
            c = h0 >> 26;
            h0 = h0 & 0x3ffffff;
            h1 += c;
            pos += take;
        }
        int c2 = h1 >> 26;
        h1 = h1 & 0x3ffffff;
        h2 += c2;
        c2 = h2 >> 26;
        h2 = h2 & 0x3ffffff;
        h3 += c2;
        c2 = h3 >> 26;
        h3 = h3 & 0x3ffffff;
        h4 += c2;
        c2 = h4 >> 26;
        h4 = h4 & 0x3ffffff;
        h0 += c2 * 5;
        c2 = h0 >> 26;
        h0 = h0 & 0x3ffffff;
        h1 += c2;
        int g0 = h0 + 5;
        c2 = g0 >> 26;
        g0 = g0 & 0x3ffffff;
        int g1 = h1 + c2;
        c2 = g1 >> 26;
        g1 = g1 & 0x3ffffff;
        int g2 = h2 + c2;
        c2 = g2 >> 26;
        g2 = g2 & 0x3ffffff;
        int g3 = h3 + c2;
        c2 = g3 >> 26;
        g3 = g3 & 0x3ffffff;
        int g4 = h4 + c2 - (1 << 26);
        if g4 >= 0 {              // h >= p: use h - p
            h0 = g0;
            h1 = g1;
            h2 = g2;
            h3 = g3;
            h4 = g4 & 0x3ffffff;
        }
        int f0 = (h0 | (h1 << 26)) & 0xFFFFFFFF;
        int f1 = ((h1 >> 6) | (h2 << 20)) & 0xFFFFFFFF;
        int f2 = ((h2 >> 12) | (h3 << 14)) & 0xFFFFFFFF;
        int f3 = ((h3 >> 18) | (h4 << 8)) & 0xFFFFFFFF;
        int f = f0 + Crypto::le32(key + 16);
        Crypto::put_le32(out, f & 0xFFFFFFFF);
        f = f1 + Crypto::le32(key + 20) + (f >> 32);
        Crypto::put_le32(out + 4, f & 0xFFFFFFFF);
        f = f2 + Crypto::le32(key + 24) + (f >> 32);
        Crypto::put_le32(out + 8, f & 0xFFFFFFFF);
        f = f3 + Crypto::le32(key + 28) + (f >> 32);
        Crypto::put_le32(out + 12, f & 0xFFFFFFFF);
    }
    // the data that Poly1305 signs in the AEAD: aad, padding to 16, ciphertext, padding to 16, the two lengths (8 bytes each)
    static void aead_tag(char^ key, char^ nonce, char^ aad, int alen, char^ ct, int clen, char^ tag) {
        char otk[64];
        Crypto::chacha20_block(key, 0, nonce, (char^)@otk);
        int apad = (16 - alen % 16) % 16;
        int cpad = (16 - clen % 16) % 16;
        int total = alen + apad + clen + cpad + 16;
        char^ m = (char^)Mem::alloc(total + 1);
        int p = 0;
        for i in 0..alen { m[p] = aad[i]; p += 1; }
        for i in 0..apad { m[p] = (char)0; p += 1; }
        for i in 0..clen { m[p] = ct[i]; p += 1; }
        for i in 0..cpad { m[p] = (char)0; p += 1; }
        for i in 0..8 { m[p] = (char)((alen >> (i * 8)) & 255); p += 1; }
        for i in 0..8 { m[p] = (char)((clen >> (i * 8)) & 255); p += 1; }
        Crypto::poly1305((char^)@otk, m, total, tag);
        Mem::free((void^)m);
    }
    // ChaCha20-Poly1305 AEAD (RFC 8439): encrypts n bytes of in into out (the same size) and writes the 16 bytes tag
    static void aead_seal(char^ key, char^ nonce, char^ aad, int alen, char^ in, int n, char^ out, char^ tag) {
        Crypto::chacha20_xor(key, 1, nonce, in, n, out);
        Crypto::aead_tag(key, nonce, aad, alen, out, n, tag);
    }
    // checks the tag of the n bytes of ciphertext and decrypts them into out; false (and out is not written) when the tag is wrong
    static bool aead_open(char^ key, char^ nonce, char^ aad, int alen, char^ ct, int n, char^ tag, char^ out) {
        char want[16];
        Crypto::aead_tag(key, nonce, aad, alen, ct, n, (char^)@want);
        int diff = 0;
        for i in 0..16 { diff = diff | (want[i] xor tag[i]); }
        if diff != 0 { return false; }
        Crypto::chacha20_xor(key, 1, nonce, ct, n, out);
        return true;
    }
    // ---------------------------------------------------------------- X25519 (RFC 7748; the numbers are 16 limbs of 16 bits, after TweetNaCl)
    static void gf_car(int^ o) {
        for i in 0..16 {
            o[i] += 65536;
            int c = o[i] >> 16;
            if i < 15 { o[i + 1] += c - 1; } else { o[0] += 38 * (c - 1); }
            o[i] -= c << 16;
        }
    }
    static void gf_sel(int^ p, int^ q, int b) {
        int c = ~(b - 1);
        for i in 0..16 {
            int t = c & (p[i] xor q[i]);
            p[i] = p[i] xor t;
            q[i] = q[i] xor t;
        }
    }
    static void gf_pack(char^ o, int^ n) {
        int t[16];
        int m[16];
        for i in 0..16 { t[i] = n[i]; }
        Crypto::gf_car((int^)@t);
        Crypto::gf_car((int^)@t);
        Crypto::gf_car((int^)@t);
        for j in 0..2 {
            m[0] = t[0] - 0xffed;
            for i in 1..15 {
                m[i] = t[i] - 0xffff - ((m[i - 1] >> 16) & 1);
                m[i - 1] = m[i - 1] & 0xffff;
            }
            m[15] = t[15] - 0x7fff - ((m[14] >> 16) & 1);
            int b = (m[15] >> 16) & 1;
            m[14] = m[14] & 0xffff;
            Crypto::gf_sel((int^)@t, (int^)@m, 1 - b);
        }
        for i in 0..16 {
            o[2 * i] = (char)(t[i] & 255);
            o[2 * i + 1] = (char)(t[i] >> 8);
        }
    }
    static void gf_unpack(int^ o, char^ n) {
        for i in 0..16 { o[i] = (n[2 * i] & 255) + ((n[2 * i + 1] & 255) << 8); }
        o[15] = o[15] & 0x7fff;
    }
    static void gf_add(int^ o, int^ a, int^ b) { for i in 0..16 { o[i] = a[i] + b[i]; } }
    static void gf_sub(int^ o, int^ a, int^ b) { for i in 0..16 { o[i] = a[i] - b[i]; } }
    static void gf_mul(int^ o, int^ a, int^ b) {
        int t[31];
        for i in 0..31 { t[i] = 0; }
        for i in 0..16 {
            for j in 0..16 { t[i + j] += a[i] * b[j]; }
        }
        for i in 0..15 { t[i] += 38 * t[i + 16]; }
        for i in 0..16 { o[i] = t[i]; }
        Crypto::gf_car(o);
        Crypto::gf_car(o);
    }
    static void gf_inv(int^ o, int^ x) {
        int c[16];
        for i in 0..16 { c[i] = x[i]; }
        int a = 253;
        while a >= 0 {
            Crypto::gf_mul((int^)@c, (int^)@c, (int^)@c);
            if a != 2 && a != 4 { Crypto::gf_mul((int^)@c, (int^)@c, x); }
            a -= 1;
        }
        for i in 0..16 { o[i] = c[i]; }
    }
    // q = n * p on Curve25519 (n: 32 bytes, p: 32 bytes, q: 32 bytes)
    static void x25519(char^ q, char^ n, char^ p) {
        char z[32];
        for i in 0..32 { z[i] = n[i]; }
        z[31] = (char)((n[31] & 127) | 64);
        z[0] = (char)(z[0] & 248);
        int x[80];
        int a[16];
        int b[16];
        int c[16];
        int d[16];
        int e[16];
        int f[16];
        int k[16];
        Crypto::gf_unpack((int^)@x, p);
        for i in 0..16 {
            b[i] = x[i];
            a[i] = 0;
            c[i] = 0;
            d[i] = 0;
            k[i] = 0;
        }
        a[0] = 1;
        d[0] = 1;
        k[0] = 0xdb41;
        k[1] = 1;
        int i = 254;
        while i >= 0 {
            int r = ((z[i >> 3] & 255) >> (i & 7)) & 1;
            Crypto::gf_sel((int^)@a, (int^)@b, r);
            Crypto::gf_sel((int^)@c, (int^)@d, r);
            Crypto::gf_add((int^)@e, (int^)@a, (int^)@c);
            Crypto::gf_sub((int^)@a, (int^)@a, (int^)@c);
            Crypto::gf_add((int^)@c, (int^)@b, (int^)@d);
            Crypto::gf_sub((int^)@b, (int^)@b, (int^)@d);
            Crypto::gf_mul((int^)@d, (int^)@e, (int^)@e);
            Crypto::gf_mul((int^)@f, (int^)@a, (int^)@a);
            Crypto::gf_mul((int^)@a, (int^)@c, (int^)@a);
            Crypto::gf_mul((int^)@c, (int^)@b, (int^)@e);
            Crypto::gf_add((int^)@e, (int^)@a, (int^)@c);
            Crypto::gf_sub((int^)@a, (int^)@a, (int^)@c);
            Crypto::gf_mul((int^)@b, (int^)@a, (int^)@a);
            Crypto::gf_sub((int^)@c, (int^)@d, (int^)@f);
            Crypto::gf_mul((int^)@a, (int^)@c, (int^)@k);
            Crypto::gf_add((int^)@a, (int^)@a, (int^)@d);
            Crypto::gf_mul((int^)@c, (int^)@c, (int^)@a);
            Crypto::gf_mul((int^)@a, (int^)@d, (int^)@f);
            Crypto::gf_mul((int^)@d, (int^)@b, (int^)@x);
            Crypto::gf_mul((int^)@b, (int^)@e, (int^)@e);
            Crypto::gf_sel((int^)@a, (int^)@b, r);
            Crypto::gf_sel((int^)@c, (int^)@d, r);
            i -= 1;
        }
        int inv[16];
        Crypto::gf_inv((int^)@inv, (int^)@c);
        Crypto::gf_mul((int^)@a, (int^)@a, (int^)@inv);
        Crypto::gf_pack(q, (int^)@a);
    }
    // the public key of a private key (32 random bytes): n * 9
    static void x25519_public(char^ pub, char^ priv) {
        char base[32];
        for i in 0..32 { base[i] = (char)0; }
        base[0] = (char)9;
        Crypto::x25519(pub, priv, (char^)@base);
    }
    // ---------------------------------------------------------------- TLS 1.3 client (RFC 8446), cipher suite TLS_CHACHA20_POLY1305_SHA256, key exchange X25519
    // A connection is a block of memory (its address is the handle). The numbers (8 bytes each) are at the offsets 0..120, the keys after them.
    //   0 fd  8 write sequence  16 read sequence  24 write encrypted?  32 read encrypted?  40 bytes waiting in inbuf  48 plain bytes ready  56 where the plain bytes start
    //   64 inbuf (address)  72 plainbuf (address)  80 transcript (address)  88 transcript length  96 certificates (address)  104 certificates length  112 peer closed?
    //   392 cipher suite  400 CertificateVerify (address)  408 its size  416 transcript hash at CertificateVerify (32)  128 write key (32)  160 write iv (12)  176 read key (32)  208 read iv (12)  224 client handshake secret (32)  256 server handshake secret (32)  288 handshake secret (32)
    static int tls_geti(char^ c, int off) {
        int^ p = (int^)(c + off);
        return p[0];
    }
    static void tls_seti(char^ c, int off, int v) {
        int^ p = (int^)(c + off);
        p[0] = v;
    }
    static void tls_put16(char^ p, int v) { p[0] = (char)((v >> 8) & 255); p[1] = (char)(v & 255); }
    static void tls_put24(char^ p, int v) { p[0] = (char)((v >> 16) & 255); p[1] = (char)((v >> 8) & 255); p[2] = (char)(v & 255); }
    static int tls_get16(char^ p) { return ((p[0] & 255) << 8) | (p[1] & 255); }
    static int tls_get24(char^ p) { return ((p[0] & 255) << 16) | ((p[1] & 255) << 8) | (p[2] & 255); }
    // HKDF-Expand-Label (RFC 8446 7.1) with SHA-256: out gets length bytes
    static void tls_expand_label(char^ secret, String label, char^ context, int clen, char^ out, int length) {
        char info[128];
        String full = "tls13 " + label;
        Crypto::tls_put16((char^)@info, length);
        info[2] = (char)full.len;
        for i in 0..full.len { info[3 + i] = full[i]; }
        info[3 + full.len] = (char)clen;
        for i in 0..clen { info[4 + full.len + i] = context[i]; }
        Crypto::hkdf_expand(256, secret, 32, (char^)@info, 4 + full.len + clen, out, length);
    }
    // Derive-Secret: the label and the hash of the transcript
    static void tls_derive(char^ secret, String label, char^ transcript, int tlen, char^ out) {
        char h[32];
        Crypto::sha256(transcript, tlen, (char^)@h);
        Crypto::tls_expand_label(secret, label, (char^)@h, 32, out, 32);
    }
    static void tls_random(char^ p, int n) {
        int got = Sys::random(p, n);
        if got != n {
            int fd = Sys::open_read("/dev/urandom");
            if fd >= 0 {
                Sys::read(fd, p, n);
                Sys::close(fd);
            }
        }
    }
    // n bytes from the socket into p (false when the other side closes first)
    static bool tls_read_exact(int fd, char^ p, int n) {
        int got = 0;
        while got < n {
            int r = Sys::read(fd, p + got, n - got);
            while r == 0 - 4 { r = Sys::read(fd, p + got, n - got); }
            if r <= 0 { return false; }
            got += r;
        }
        return true;
    }
    static bool tls_write_all(int fd, char^ p, int n) {
        int off = 0;
        while off < n {
            int r = Sys::write(fd, p + off, n - off);
            while r == 0 - 4 { r = Sys::write(fd, p + off, n - off); }
            if r <= 0 { return false; }
            off += r;
        }
        return true;
    }
    // append a handshake message to the transcript
    static void tls_transcript(char^ c, char^ msg, int n) {
        char^ t = (char^)Crypto::tls_geti(c, 80);
        int len = Crypto::tls_geti(c, 88);
        for i in 0..n { t[len + i] = msg[i]; }
        Crypto::tls_seti(c, 88, len + n);
    }
    static void tls_nonce(char^ iv, int seq, char^ out) {
        for i in 0..12 { out[i] = iv[i]; }
        for i in 0..8 { out[11 - i] = (char)(out[11 - i] xor ((seq >> (i * 8)) & 255)); }
    }
    // send one record: type, content n bytes; encrypted when the write side has keys
    static bool tls_send_record(char^ c, int type, char^ data, int n) {
        int fd = Crypto::tls_geti(c, 0);
        char^ rec = (char^)Mem::alloc(n + 64);
        if Crypto::tls_geti(c, 24) == 0 {
            rec[0] = (char)type;
            rec[1] = (char)3;
            rec[2] = (char)3;
            if type == 22 { rec[2] = (char)1; }              // the first record (the ClientHello) says 3.1, the others 3.3
            Crypto::tls_put16(rec + 3, n);
            for i in 0..n { rec[5 + i] = data[i]; }
            bool ok = Crypto::tls_write_all(fd, rec, 5 + n);
            Mem::free((void^)rec);
            return ok;
        }
        int inner = n + 1;
        char^ plain = (char^)Mem::alloc(inner + 1);
        for i in 0..n { plain[i] = data[i]; }
        plain[n] = (char)type;
        rec[0] = (char)23;
        rec[1] = (char)3;
        rec[2] = (char)3;
        Crypto::tls_put16(rec + 3, inner + 16);
        char nonce[12];
        int seq = Crypto::tls_geti(c, 8);
        Crypto::tls_nonce(c + 160, seq, (char^)@nonce);
        if Crypto::tls_geti(c, 392) == 0x1301 {
            Crypto::gcm_seal(c + 128, (char^)@nonce, rec, 5, plain, inner, rec + 5, rec + 5 + inner);
        } else {
            Crypto::aead_seal(c + 128, (char^)@nonce, rec, 5, plain, inner, rec + 5, rec + 5 + inner);
        }
        Crypto::tls_seti(c, 8, seq + 1);
        bool ok2 = Crypto::tls_write_all(fd, rec, 5 + inner + 16);
        Mem::free((void^)plain);
        Mem::free((void^)rec);
        return ok2;
    }
    // read one record into plainbuf: gives the content type (the inner one when it was encrypted) and sets plain length at 48; -1 when the line is closed or the record is bad
    static int tls_read_record(char^ c) {
        int fd = Crypto::tls_geti(c, 0);
        char^ inbuf = (char^)Crypto::tls_geti(c, 64);
        char^ plain = (char^)Crypto::tls_geti(c, 72);
        char hdr[5];
        if !Crypto::tls_read_exact(fd, (char^)@hdr, 5) { return -1; }
        int type = hdr[0] & 255;
        int len = Crypto::tls_get16((char^)@hdr + 3);
        if len > 17000 { return -1; }
        if !Crypto::tls_read_exact(fd, inbuf, len) { return -1; }
        if type == 20 || Crypto::tls_geti(c, 32) == 0 {
            for i in 0..len { plain[i] = inbuf[i]; }
            Crypto::tls_seti(c, 48, len);
            return type;
        }
        if type != 23 || len < 17 { return -1; }
        char nonce[12];
        int seq = Crypto::tls_geti(c, 16);
        Crypto::tls_nonce(c + 208, seq, (char^)@nonce);
        int clen = len - 16;
        bool opened = false;
        if Crypto::tls_geti(c, 392) == 0x1301 {
            opened = Crypto::gcm_open(c + 176, (char^)@nonce, (char^)@hdr, 5, inbuf, clen, inbuf + clen, plain);
        } else {
            opened = Crypto::aead_open(c + 176, (char^)@nonce, (char^)@hdr, 5, inbuf, clen, inbuf + clen, plain);
        }
        if !opened { return -1; }
        Crypto::tls_seti(c, 16, seq + 1);
        int end = clen;
        while end > 0 && plain[end - 1] == 0 { end -= 1; }
        if end == 0 { return -1; }
        Crypto::tls_seti(c, 48, end - 1);
        return plain[end - 1] & 255;
    }
    static void tls_set_keys(char^ c, int write, char^ secret) {
        int koff = 176;
        if write == 1 { koff = 128; }
        int klen = 32;
        if Crypto::tls_geti(c, 392) == 0x1301 { klen = 16; }
        Crypto::tls_expand_label(secret, "key", "".c(), 0, c + koff, klen);
        Crypto::tls_expand_label(secret, "iv", "".c(), 0, c + koff + 32, 12);
    }
    // starts TLS on a socket that is connected (fd): gives the handle of the connection. host is the name for the server (SNI) and for the check of the certificate.
    // insecure = 1: the certificate is NOT checked (only for tests against a server of your own). On a failure the socket is closed.
    static Result<int, Error> tls_connect(int fd, String host, int insecure) {
        int cv = (int)Mem::alloc(512);            // not a pointer variable that owns the memory: the block must stay after this function
        char^ c = (char^)cv;
        for i in 0..512 { c[i] = (char)0; }
        Crypto::tls_seti(c, 0, fd);
        Crypto::tls_seti(c, 64, (int)Mem::alloc(18000));
        Crypto::tls_seti(c, 72, (int)Mem::alloc(18000));
        Crypto::tls_seti(c, 80, (int)Mem::alloc(65536));
        char priv[32];
        char pub[32];
        char rnd[32];
        char sid[32];
        Crypto::tls_random((char^)@priv, 32);
        Crypto::tls_random((char^)@rnd, 32);
        Crypto::tls_random((char^)@sid, 32);
        Crypto::x25519_public((char^)@pub, (char^)@priv);
        // ClientHello
        char ch[600];
        int p = 4;
        ch[p] = (char)3; ch[p + 1] = (char)3; p += 2;
        for i in 0..32 { ch[p + i] = rnd[i]; }
        p += 32;
        ch[p] = (char)32; p += 1;
        for i in 0..32 { ch[p + i] = sid[i]; }
        p += 32;
        ch[p] = (char)0; ch[p + 1] = (char)4; ch[p + 2] = (char)0x13; ch[p + 3] = (char)3; ch[p + 4] = (char)0x13; ch[p + 5] = (char)1; p += 6;     // TLS_CHACHA20_POLY1305_SHA256, TLS_AES_128_GCM_SHA256
        ch[p] = (char)1; ch[p + 1] = (char)0; p += 2;                                                   // no compression
        int ext0 = p;
        p += 2;
        // server_name
        Crypto::tls_put16((char^)@ch + p, 0); Crypto::tls_put16((char^)@ch + p + 2, host.len + 5);
        Crypto::tls_put16((char^)@ch + p + 4, host.len + 3); ch[p + 6] = (char)0; Crypto::tls_put16((char^)@ch + p + 7, host.len);
        for i in 0..host.len { ch[p + 9 + i] = host[i]; }
        p += 9 + host.len;
        // supported_groups: x25519
        Crypto::tls_put16((char^)@ch + p, 10); Crypto::tls_put16((char^)@ch + p + 2, 4); Crypto::tls_put16((char^)@ch + p + 4, 2); Crypto::tls_put16((char^)@ch + p + 6, 0x1d);
        p += 8;
        // signature_algorithms
        Crypto::tls_put16((char^)@ch + p, 13); Crypto::tls_put16((char^)@ch + p + 2, 16); Crypto::tls_put16((char^)@ch + p + 4, 14);
        Crypto::tls_put16((char^)@ch + p + 6, 0x0403); Crypto::tls_put16((char^)@ch + p + 8, 0x0503); Crypto::tls_put16((char^)@ch + p + 10, 0x0804);
        Crypto::tls_put16((char^)@ch + p + 12, 0x0805); Crypto::tls_put16((char^)@ch + p + 14, 0x0806); Crypto::tls_put16((char^)@ch + p + 16, 0x0401);
        Crypto::tls_put16((char^)@ch + p + 18, 0x0501);
        p += 20;
        // supported_versions: TLS 1.3
        Crypto::tls_put16((char^)@ch + p, 43); Crypto::tls_put16((char^)@ch + p + 2, 3); ch[p + 4] = (char)2; Crypto::tls_put16((char^)@ch + p + 5, 0x0304);
        p += 7;
        // key_share: x25519
        Crypto::tls_put16((char^)@ch + p, 51); Crypto::tls_put16((char^)@ch + p + 2, 38); Crypto::tls_put16((char^)@ch + p + 4, 36);
        Crypto::tls_put16((char^)@ch + p + 6, 0x1d); Crypto::tls_put16((char^)@ch + p + 8, 32);
        for i in 0..32 { ch[p + 10 + i] = pub[i]; }
        p += 42;
        Crypto::tls_put16((char^)@ch + ext0, p - ext0 - 2);
        ch[0] = (char)1;
        Crypto::tls_put24((char^)@ch + 1, p - 4);
        Crypto::tls_transcript(c, (char^)@ch, p);
        if !Crypto::tls_send_record(c, 22, (char^)@ch, p) { return Crypto::tls_fail(c, "cannot send to " + host); }
        // ServerHello
        int type = Crypto::tls_read_record(c);
        char^ plain = (char^)Crypto::tls_geti(c, 72);
        while type == 20 { type = Crypto::tls_read_record(c); }
        if type == 21 { return Crypto::tls_fail(c, "the server sent an alert (" + str(plain[1] & 255) + ")"); }
        if type != 22 || Crypto::tls_geti(c, 48) < 40 || (plain[0] & 255) != 2 { return Crypto::tls_fail(c, "the server did not answer with a TLS ServerHello"); }
        int shlen = Crypto::tls_get24(plain + 1);
        Crypto::tls_transcript(c, plain, 4 + shlen);
        int q = 4 + 2 + 32;
        int sidlen = plain[q] & 255;
        q += 1 + sidlen;
        int suite = Crypto::tls_get16(plain + q);
        q += 3;                                  // the suite and the compression
        if suite != 0x1303 && suite != 0x1301 { return Crypto::tls_fail(c, "the server chose a cipher suite that is not written (" + str(suite) + ")"); }
        Crypto::tls_seti(c, 392, suite);
        int extlen = Crypto::tls_get16(plain + q);
        q += 2;
        int endx = q + extlen;
        char spub[32];
        bool gotkey = false;
        bool v13 = false;
        while q + 4 <= endx {
            int et = Crypto::tls_get16(plain + q);
            int el = Crypto::tls_get16(plain + q + 2);
            if et == 43 && el == 2 && Crypto::tls_get16(plain + q + 4) == 0x0304 { v13 = true; }
            if et == 51 && el == 36 && Crypto::tls_get16(plain + q + 4) == 0x1d {
                for i in 0..32 { spub[i] = plain[q + 8 + i]; }
                gotkey = true;
            }
            q += 4 + el;
        }
        if !v13 || !gotkey { return Crypto::tls_fail(c, "the server does not speak TLS 1.3 with X25519"); }
        char shared[32];
        Crypto::x25519((char^)@shared, (char^)@priv, (char^)@spub);
        // the key schedule up to the handshake traffic keys
        char zeros[32];
        for i in 0..32 { zeros[i] = (char)0; }
        char early[32];
        Crypto::hkdf_extract(256, (char^)@zeros, 0, (char^)@zeros, 32, (char^)@early);
        char empty_hash[32];
        Crypto::sha256("".c(), 0, (char^)@empty_hash);
        char derived[32];
        Crypto::tls_expand_label((char^)@early, "derived", (char^)@empty_hash, 32, (char^)@derived, 32);
        Crypto::hkdf_extract(256, (char^)@derived, 32, (char^)@shared, 32, c + 288);
        char^ tr = (char^)Crypto::tls_geti(c, 80);
        Crypto::tls_derive(c + 288, "c hs traffic", tr, Crypto::tls_geti(c, 88), c + 224);
        Crypto::tls_derive(c + 288, "s hs traffic", tr, Crypto::tls_geti(c, 88), c + 256);
        Crypto::tls_set_keys(c, 0, c + 256);
        Crypto::tls_seti(c, 32, 1);
        Crypto::tls_seti(c, 16, 0);
        // the rest of the server's flight (encrypted)
        char^ hs = (char^)Mem::alloc(70000);
        int hslen = 0;
        int hsdone = 0;
        bool finished = false;
        bool cert_seen = false;
        while !finished {
            type = Crypto::tls_read_record(c);
            if type == 20 { type = 0 - 2; }
            if type == 0 - 2 { }
            else if type == 21 { Mem::free((void^)hs); return Crypto::tls_fail(c, "the server sent an alert (" + str(plain[1] & 255) + ")"); }
            else if type != 22 { Mem::free((void^)hs); return Crypto::tls_fail(c, "the handshake of " + host + " broke off"); }
            else {
                int pl = Crypto::tls_geti(c, 48);
                for i in 0..pl { hs[hslen + i] = plain[i]; }
                hslen += pl;
                while hslen - hsdone >= 4 && !finished {
                    int mt = hs[hsdone] & 255;
                    int ml = Crypto::tls_get24(hs + hsdone + 1);
                    if hslen - hsdone < 4 + ml { break; }
                    char^ msg = hs + hsdone;
                    if mt == 11 {
                        // Certificate: the list of certificates is kept for the check
                        int certs = Crypto::tls_geti(c, 96);
                        if certs == 0 {
                            int cbv = (int)Mem::alloc(ml + 8);
                            char^ cb = (char^)cbv;
                            for i in 0..ml { cb[i] = msg[4 + i]; }
                            Crypto::tls_seti(c, 96, cbv);
                            Crypto::tls_seti(c, 104, ml);
                        }
                        cert_seen = true;
                    }
                    if mt == 15 && Crypto::tls_geti(c, 400) == 0 {
                        // CertificateVerify: kept for the check, with the hash of the transcript up to the Certificate
                        int cvv = (int)Mem::alloc(ml + 8);
                        char^ cvb = (char^)cvv;
                        for i in 0..ml { cvb[i] = msg[4 + i]; }
                        Crypto::tls_seti(c, 400, cvv);
                        Crypto::tls_seti(c, 408, ml);
                        Crypto::sha256(tr, Crypto::tls_geti(c, 88), c + 416);
                    }
                    if mt == 20 {
                        // Finished: HMAC of the transcript so far with the server finished key
                        char fk[32];
                        char th[32];
                        char want[32];
                        Crypto::tls_expand_label(c + 256, "finished", "".c(), 0, (char^)@fk, 32);
                        Crypto::sha256(tr, Crypto::tls_geti(c, 88), (char^)@th);
                        Crypto::hmac(256, (char^)@fk, 32, (char^)@th, 32, (char^)@want);
                        int diff = 0;
                        for i in 0..32 { diff = diff | (want[i] xor msg[4 + i]); }
                        if ml != 32 || diff != 0 { Mem::free((void^)hs); return Crypto::tls_fail(c, "the Finished message of " + host + " is wrong"); }
                        finished = true;
                    }
                    Crypto::tls_transcript(c, msg, 4 + ml);
                    hsdone += 4 + ml;
                }
            }
        }
        Mem::free((void^)hs);
        if !cert_seen { return Crypto::tls_fail(c, "the server sent no certificate"); }
        if insecure == 0 {
            String why = Crypto::tls_check_server(c, host);
            if why.len > 0 { return Crypto::tls_fail(c, why); }
        }
        // our Finished, then the traffic keys of the application data
        char cfk[32];
        char cth[32];
        char fin[40];
        Crypto::tls_expand_label(c + 224, "finished", "".c(), 0, (char^)@cfk, 32);
        Crypto::sha256(tr, Crypto::tls_geti(c, 88), (char^)@cth);
        fin[0] = (char)20;
        Crypto::tls_put24((char^)@fin + 1, 32);
        Crypto::hmac(256, (char^)@cfk, 32, (char^)@cth, 32, (char^)@fin + 4);
        char ccs[1];
        ccs[0] = (char)1;
        Crypto::tls_send_record(c, 20, (char^)@ccs, 1);
        Crypto::tls_set_keys(c, 1, c + 224);
        Crypto::tls_seti(c, 24, 1);
        Crypto::tls_seti(c, 8, 0);
        if !Crypto::tls_send_record(c, 22, (char^)@fin, 36) { return Crypto::tls_fail(c, "cannot send to " + host); }
        char d2[32];
        char master[32];
        Crypto::tls_expand_label(c + 288, "derived", (char^)@empty_hash, 32, (char^)@d2, 32);
        Crypto::hkdf_extract(256, (char^)@d2, 32, (char^)@zeros, 32, (char^)@master);
        char cap[32];
        char sap[32];
        Crypto::tls_derive((char^)@master, "c ap traffic", tr, Crypto::tls_geti(c, 88) - 0, (char^)@cap);
        Crypto::tls_derive((char^)@master, "s ap traffic", tr, Crypto::tls_geti(c, 88) - 0, (char^)@sap);
        Crypto::tls_set_keys(c, 1, (char^)@cap);
        Crypto::tls_set_keys(c, 0, (char^)@sap);
        Crypto::tls_seti(c, 8, 0);
        Crypto::tls_seti(c, 16, 0);
        Crypto::tls_seti(c, 48, 0);
        Crypto::tls_seti(c, 56, 0);
        return Result<int, Error>::Ok((int)c);
    }
    // the check of what the server sent: the chain of certificates (trusted, named, in date) and the signature of CertificateVerify made with the key of the first one. "" when good.
    static String tls_check_server(char^ c, String host) {
        char^ certs = (char^)Crypto::tls_geti(c, 96);
        int clen = Crypto::tls_geti(c, 104);
        char^ cv = (char^)Crypto::tls_geti(c, 400);
        int cvlen = Crypto::tls_geti(c, 408);
        if certs == null || clen < 8 || cv == null { return "the server sent no certificate or no proof of its key"; }
        // Certificate: context (1 byte, 0), the list (3 bytes of size), each entry: 3 bytes of size, the certificate, 2 bytes of size, extensions
        int cap = clen + 64;
        int cbv = (int)Mem::alloc(cap);
        char^ chain = (char^)cbv;
        int w = 0;
        int pos = 1 + 3;
        while pos + 3 <= clen {
            int n = Crypto::tls_get24(certs + pos);
            pos += 3;
            if n <= 0 || pos + n + 2 > clen { Mem::free((void^)chain); return "the certificates are damaged"; }
            chain[w] = (char)((n >> 24) & 255);
            chain[w + 1] = (char)((n >> 16) & 255);
            chain[w + 2] = (char)((n >> 8) & 255);
            chain[w + 3] = (char)(n & 255);
            for i in 0..n { chain[w + 4 + i] = certs[pos + i]; }
            w += 4 + n;
            pos += n;
            pos += 2 + Crypto::tls_get16(certs + pos);
        }
        String why = Crypto::x509_check_chain(chain, w, host, 0);
        if why.len > 0 { Mem::free((void^)chain); return why; }
        // the signature of CertificateVerify: 64 spaces, the text, 0, the hash of the transcript
        char content[160];
        for i in 0..64 { content[i] = ' '; }
        String label = "TLS 1.3, server CertificateVerify";
        for i in 0..label.len { content[64 + i] = label[i]; }
        content[64 + label.len] = (char)0;
        for i in 0..32 { content[65 + label.len + i] = c[416 + i]; }
        int clen2 = 65 + label.len + 32;
        int first = ((chain[0] & 255) << 24) | ((chain[1] & 255) << 16) | ((chain[2] & 255) << 8) | (chain[3] & 255);
        int ox[28];
        if !Crypto::x509_parse(chain + 4, first, (int^)@ox) { Mem::free((void^)chain); return "the certificate cannot be read"; }
        int scheme = Crypto::tls_get16(cv);
        int siglen = Crypto::tls_get16(cv + 2);
        bool ok = false;
        if siglen + 4 <= cvlen {
            ok = Crypto::x509_check_sig(chain + 4, (int^)@ox, scheme, (char^)@content, clen2, cv + 4, siglen);
        }
        Mem::free((void^)chain);
        if !ok { return "the server did not prove that it owns the key of its certificate (the signature of the handshake is wrong)"; }
        return "";
    }
    // close the socket and free the memory of the connection
    static void tls_release(char^ c) {
        Sys::close(Crypto::tls_geti(c, 0));
        Mem::free((void^)Crypto::tls_geti(c, 64));
        Mem::free((void^)Crypto::tls_geti(c, 72));
        Mem::free((void^)Crypto::tls_geti(c, 80));
        if Crypto::tls_geti(c, 96) != 0 { Mem::free((void^)Crypto::tls_geti(c, 96)); }
        if Crypto::tls_geti(c, 400) != 0 { Mem::free((void^)Crypto::tls_geti(c, 400)); }
        Mem::free((void^)c);
    }
    static Result<int, Error> tls_fail(char^ c, String why) {
        Crypto::tls_release(c);
        return Result<int, Error>::Err(Error::make(ErrorKind::Io, why));
    }
    // send data over the connection
    static bool tls_send(int h, String data) {
        char^ c = (char^)h;
        int off = 0;
        while off < data.len {
            int take = data.len - off;
            if take > 16000 { take = 16000; }
            if !Crypto::tls_send_record(c, 23, data.c() + off, take) { return false; }
            off += take;
        }
        return true;
    }
    // the next piece of application data ("" when the server closed the connection)
    static String tls_recv(int h) {
        char^ c = (char^)h;
        char^ plain = (char^)Crypto::tls_geti(c, 72);
        while true {
            int type = Crypto::tls_read_record(c);
            if type < 0 { return ""; }
            if type == 23 {
                String r = "";
                int n = Crypto::tls_geti(c, 48);
                for i in 0..n { r.push(plain[i]); }
                return r;
            }
            if type == 21 { return ""; }
        }
        return "";
    }
    static void tls_close(int h) {
        char^ c = (char^)h;
        char alert[2];
        alert[0] = (char)1;
        alert[1] = (char)0;
        Crypto::tls_send_record(c, 21, (char^)@alert, 2);
        Crypto::tls_release(c);
    }
    // ---------------------------------------------------------------- AES-128 and GCM (FIPS 197, NIST SP 800-38D)
    static void aes_sbox(char^ out) { Crypto::unhex("637c777bf26b6fc53001672bfed7ab76ca82c97dfa5947f0add4a2af9ca472c0b7fd9326363ff7cc34a5e5f171d8311504c723c31896059a071280e2eb27b27509832c1a1b6e5aa0523bd6b329e32f8453d100ed20fcb15b6acbbe394a4c58cfd0efaafb434d338545f9027f503c9fa851a3408f929d38f5bcb6da2110fff3d2cd0c13ec5f974417c4a77e3d645d197360814fdc222a908846eeb814de5e0bdbe0323a0a4906245cc2d3ac629195e479e7c8376d8dd54ea96c56f4ea657aae08ba78252e1ca6b4c6e8dd741f4bbd8b8a703eb5664803f60e613557b986c11d9ee1f8981169d98e949b1e87e9ce5528df8ca1890dbfe6426841992d0fb054bb16", out); }
    static int aes_xtime(int a) {
        a = a << 1;
        if (a & 256) != 0 { a = a xor 0x11b; }
        return a & 255;
    }
    // the 11 round keys of a 16 byte key into rk (176 bytes); sb: the S-box (256 bytes)
    static void aes_expand(char^ key, char^ rk, char^ sb) {
        for i in 0..16 { rk[i] = key[i]; }
        int rcon = 1;
        for i in 4..44 {
            char t[4];
            for j in 0..4 { t[j] = rk[(i - 1) * 4 + j]; }
            if i % 4 == 0 {
                char first = t[0];
                t[0] = (char)(sb[t[1] & 255] xor rcon);
                t[1] = sb[t[2] & 255];
                t[2] = sb[t[3] & 255];
                t[3] = sb[first & 255];
                rcon = Crypto::aes_xtime(rcon);
            }
            for j in 0..4 { rk[i * 4 + j] = (char)(rk[(i - 4) * 4 + j] xor t[j]); }
        }
    }
    // one block of 16 bytes encrypted (in and out may be the same)
    static void aes_encrypt(char^ rk, char^ sb, char^ in, char^ out) {
        char s[16];
        for i in 0..16 { s[i] = (char)(in[i] xor rk[i]); }
        for round in 1..11 {
            char t[16];
            // SubBytes and ShiftRows
            for c in 0..4 {
                for r in 0..4 { t[c * 4 + r] = sb[s[((c + r) % 4) * 4 + r] & 255]; }
            }
            if round < 10 {
                for c in 0..4 {
                    int a0 = t[c * 4] & 255;
                    int a1 = t[c * 4 + 1] & 255;
                    int a2 = t[c * 4 + 2] & 255;
                    int a3 = t[c * 4 + 3] & 255;
                    int all = a0 xor a1 xor a2 xor a3;
                    s[c * 4] = (char)(a0 xor all xor Crypto::aes_xtime(a0 xor a1));
                    s[c * 4 + 1] = (char)(a1 xor all xor Crypto::aes_xtime(a1 xor a2));
                    s[c * 4 + 2] = (char)(a2 xor all xor Crypto::aes_xtime(a2 xor a3));
                    s[c * 4 + 3] = (char)(a3 xor all xor Crypto::aes_xtime(a3 xor a0));
                }
            } else {
                for i in 0..16 { s[i] = t[i]; }
            }
            for i in 0..16 { s[i] = (char)(s[i] xor rk[round * 16 + i]); }
        }
        for i in 0..16 { out[i] = s[i]; }
    }
    // multiplication in GF(2^128) of GCM: x = x * h (both as 16 bytes, big-endian bit order of the standard)
    static void ghash_mul(char^ x, char^ h) {
        int zh = 0;
        int zl = 0;
        int vh = 0;
        int vl = 0;
        for i in 0..8 { vh = (vh << 8) | (h[i] & 255); vl = (vl << 8) | (h[8 + i] & 255); }
        for i in 0..128 {
            int bit = ((x[i / 8] & 255) >> (7 - i % 8)) & 1;
            if bit == 1 { zh = zh xor vh; zl = zl xor vl; }
            int lsb = vl & 1;
            vl = ((vl >> 1) & 0x7FFFFFFFFFFFFFFF) | (vh << 63);
            vh = (vh >> 1) & 0x7FFFFFFFFFFFFFFF;
            if lsb == 1 { vh = vh xor (0xE1 << 56); }
        }
        for i in 0..8 {
            x[i] = (char)((zh >> (56 - i * 8)) & 255);
            x[8 + i] = (char)((zl >> (56 - i * 8)) & 255);
        }
    }
    // GHASH of the aad and the ciphertext, then the tag = E(J0) xor GHASH
    static void gcm_tag(char^ rk, char^ sb, char^ h, char^ j0, char^ aad, int alen, char^ ct, int clen, char^ tag) {
        char x[16];
        for i in 0..16 { x[i] = (char)0; }
        int pos = 0;
        while pos < alen {
            int take = alen - pos;
            if take > 16 { take = 16; }
            for i in 0..take { x[i] = (char)(x[i] xor aad[pos + i]); }
            Crypto::ghash_mul((char^)@x, h);
            pos += take;
        }
        pos = 0;
        while pos < clen {
            int take = clen - pos;
            if take > 16 { take = 16; }
            for i in 0..take { x[i] = (char)(x[i] xor ct[pos + i]); }
            Crypto::ghash_mul((char^)@x, h);
            pos += take;
        }
        char lens[16];
        int abits = alen * 8;
        int cbits = clen * 8;
        for i in 0..8 { lens[i] = (char)((abits >> (56 - i * 8)) & 255); lens[8 + i] = (char)((cbits >> (56 - i * 8)) & 255); }
        for i in 0..16 { x[i] = (char)(x[i] xor lens[i]); }
        Crypto::ghash_mul((char^)@x, h);
        char ej[16];
        Crypto::aes_encrypt(rk, sb, j0, (char^)@ej);
        for i in 0..16 { tag[i] = (char)(x[i] xor ej[i]); }
    }
    // counter mode starting at the counter block cb (the last 4 bytes are the counter); in -> out
    static void gcm_ctr(char^ rk, char^ sb, char^ cb0, char^ in, int n, char^ out) {
        char cb[16];
        for i in 0..16 { cb[i] = cb0[i]; }
        int pos = 0;
        while pos < n {
            int ctr = ((cb[12] & 255) << 24) | ((cb[13] & 255) << 16) | ((cb[14] & 255) << 8) | (cb[15] & 255);
            ctr = (ctr + 1) & 0xFFFFFFFF;
            cb[12] = (char)((ctr >> 24) & 255);
            cb[13] = (char)((ctr >> 16) & 255);
            cb[14] = (char)((ctr >> 8) & 255);
            cb[15] = (char)(ctr & 255);
            char ks[16];
            Crypto::aes_encrypt(rk, sb, (char^)@cb, (char^)@ks);
            int take = n - pos;
            if take > 16 { take = 16; }
            for i in 0..take { out[pos + i] = (char)(in[pos + i] xor ks[i]); }
            pos += take;
        }
    }
    // AES-128-GCM with a 12 byte iv: encrypts n bytes of in into out, writes the 16 bytes tag
    static void gcm_seal(char^ key, char^ iv, char^ aad, int alen, char^ in, int n, char^ out, char^ tag) {
        char sb[256];
        char rk[176];
        Crypto::aes_sbox((char^)@sb);
        Crypto::aes_expand(key, (char^)@rk, (char^)@sb);
        char h[16];
        char zero[16];
        for i in 0..16 { zero[i] = (char)0; }
        Crypto::aes_encrypt((char^)@rk, (char^)@sb, (char^)@zero, (char^)@h);
        char j0[16];
        for i in 0..12 { j0[i] = iv[i]; }
        j0[12] = (char)0; j0[13] = (char)0; j0[14] = (char)0; j0[15] = (char)1;
        Crypto::gcm_ctr((char^)@rk, (char^)@sb, (char^)@j0, in, n, out);
        Crypto::gcm_tag((char^)@rk, (char^)@sb, (char^)@h, (char^)@j0, aad, alen, out, n, tag);
    }
    // checks the tag and decrypts; false (out not written) when the tag is wrong
    static bool gcm_open(char^ key, char^ iv, char^ aad, int alen, char^ ct, int n, char^ tag, char^ out) {
        char sb[256];
        char rk[176];
        Crypto::aes_sbox((char^)@sb);
        Crypto::aes_expand(key, (char^)@rk, (char^)@sb);
        char h[16];
        char zero[16];
        for i in 0..16 { zero[i] = (char)0; }
        Crypto::aes_encrypt((char^)@rk, (char^)@sb, (char^)@zero, (char^)@h);
        char j0[16];
        for i in 0..12 { j0[i] = iv[i]; }
        j0[12] = (char)0; j0[13] = (char)0; j0[14] = (char)0; j0[15] = (char)1;
        char want[16];
        Crypto::gcm_tag((char^)@rk, (char^)@sb, (char^)@h, (char^)@j0, aad, alen, ct, n, (char^)@want);
        int diff = 0;
        for i in 0..16 { diff = diff | (want[i] xor tag[i]); }
        if diff != 0 { return false; }
        Crypto::gcm_ctr((char^)@rk, (char^)@sb, (char^)@j0, ct, n, out);
        return true;
    }
    // ---------------------------------------------------------------- big numbers (Montgomery arithmetic) for RSA and the curves
    // A number is an array of n limbs of 28 bits, the least significant first. The modulus must be odd.
    static void bn_from_bytes(int^ a, int n, char^ b, int len) {
        for i in 0..n { a[i] = 0; }
        int acc = 0;
        int bits = 0;
        int idx = 0;
        int i = len - 1;
        while i >= 0 {
            acc = acc | ((b[i] & 255) << bits);
            bits += 8;
            while bits >= 28 {
                if idx < n { a[idx] = acc & 0xFFFFFFF; }
                idx += 1;
                acc = acc >> 28;
                bits -= 28;
            }
            i -= 1;
        }
        if bits > 0 && idx < n { a[idx] = acc & 0xFFFFFFF; }
    }
    // the number as len bytes, big-endian (it must fit)
    static void bn_to_bytes(int^ a, int n, char^ out, int len) {
        for i in 0..len { out[i] = (char)0; }
        int acc = 0;
        int bits = 0;
        int pos = len - 1;
        for i in 0..n {
            acc = acc | (a[i] << bits);
            bits += 28;
            while bits >= 8 {
                if pos >= 0 { out[pos] = (char)(acc & 255); }
                pos -= 1;
                acc = acc >> 8;
                bits -= 8;
            }
        }
        if bits > 0 && pos >= 0 { out[pos] = (char)(acc & 255); }
    }
    static int bn_cmp(int^ a, int^ b, int n) {
        int i = n - 1;
        while i >= 0 {
            if a[i] > b[i] { return 1; }
            if a[i] < b[i] { return -1; }
            i -= 1;
        }
        return 0;
    }
    static bool bn_is_zero(int^ a, int n) {
        for i in 0..n { if a[i] != 0 { return false; } }
        return true;
    }
    // a = a - b (the borrow out is returned)
    static int bn_sub(int^ a, int^ b, int n) {
        int borrow = 0;
        for i in 0..n {
            int x = a[i] - b[i] - borrow;
            if x < 0 { x += 0x10000000; borrow = 1; } else { borrow = 0; }
            a[i] = x;
        }
        return borrow;
    }
    // a = a + b (the carry out is returned)
    static int bn_add(int^ a, int^ b, int n) {
        int carry = 0;
        for i in 0..n {
            int x = a[i] + b[i] + carry;
            a[i] = x & 0xFFFFFFF;
            carry = x >> 28;
        }
        return carry;
    }
    // -m^-1 mod 2^28
    static int mont_n0(int m0) {
        int inv = m0;
        for k in 0..5 { inv = (inv * (2 - m0 * inv)) & 0xFFFFFFF; }
        return (0 - inv) & 0xFFFFFFF;
    }
    // r = a * b / R mod m   (R = 2^(28 n)); r may be the same array as a or b
    static void mont_mul(int^ r, int^ a, int^ b, int^ m, int n, int n0) {
        int t[160];
        for i in 0..n + 2 { t[i] = 0; }
        for i in 0..n {
            int carry = 0;
            int bi = b[i];
            for j in 0..n {
                int x = t[j] + a[j] * bi + carry;
                t[j] = x & 0xFFFFFFF;
                carry = x >> 28;
            }
            int x2 = t[n] + carry;
            t[n] = x2 & 0xFFFFFFF;
            t[n + 1] = x2 >> 28;
            int mq = (t[0] * n0) & 0xFFFFFFF;
            int y = t[0] + mq * m[0];
            carry = y >> 28;
            for j in 1..n {
                y = t[j] + mq * m[j] + carry;
                t[j - 1] = y & 0xFFFFFFF;
                carry = y >> 28;
            }
            y = t[n] + carry;
            t[n - 1] = y & 0xFFFFFFF;
            carry = y >> 28;
            t[n] = t[n + 1] + carry;
        }
        // t < 2m: one subtraction at most
        int ge = 0;
        if t[n] != 0 { ge = 1; } else if Crypto::bn_cmp((int^)@t, m, n) >= 0 { ge = 1; }
        if ge == 1 { Crypto::bn_sub((int^)@t, m, n); }
        for i in 0..n { r[i] = t[i]; }
    }
    // rr = R^2 mod m (by doubling), n0 is returned
    static int mont_setup(int^ m, int n, int^ rr) {
        for i in 0..n { rr[i] = 0; }
        rr[0] = 1;
        int total = 2 * 28 * n;
        for step in 0..total {
            int carry = 0;
            for i in 0..n {
                int x = (rr[i] << 1) | carry;
                rr[i] = x & 0xFFFFFFF;
                carry = x >> 28;
            }
            if carry == 1 || Crypto::bn_cmp(rr, m, n) >= 0 { Crypto::bn_sub(rr, m, n); }
        }
        return Crypto::mont_n0(m[0]);
    }
    // out = base ^ e mod m, e given as bytes (big-endian); base < m
    static void mont_pow(int^ out, int^ base, char^ e, int elen, int^ m, int n, int^ rr, int n0) {
        int one[160];
        int bm[160];
        int r[160];
        for i in 0..n { one[i] = 0; }
        one[0] = 1;
        Crypto::mont_mul((int^)@bm, base, rr, m, n, n0);
        Crypto::mont_mul((int^)@r, (int^)@one, rr, m, n, n0);            // 1 in the Montgomery form
        for i in 0..elen {
            int byte = e[i] & 255;
            int k = 7;
            while k >= 0 {
                Crypto::mont_mul((int^)@r, (int^)@r, (int^)@r, m, n, n0);
                if ((byte >> k) & 1) == 1 { Crypto::mont_mul((int^)@r, (int^)@r, (int^)@bm, m, n, n0); }
                k -= 1;
            }
        }
        Crypto::mont_mul(out, (int^)@r, (int^)@one, m, n, n0);
    }
    // ---------------------------------------------------------------- RSA signatures (RFC 8017), checking only
    // the public key as big-endian bytes: modulus nb (nlen), exponent eb (elen). halg: 256, 384 or 512 (the hash of the signed message).
    static bool rsa_public(char^ nb, int nlen, char^ eb, int elen, char^ sig, int slen, char^ em) {
        while nlen > 0 && nb[0] == 0 { nb += 1; nlen -= 1; }
        if nlen < 64 || nlen > 512 || slen != nlen { return false; }
        int n = (nlen * 8 + 27) / 28;
        int m[160];
        int rr[160];
        int s[160];
        int x[160];
        Crypto::bn_from_bytes((int^)@m, n, nb, nlen);
        if (m[0] & 1) == 0 { return false; }
        Crypto::bn_from_bytes((int^)@s, n, sig, slen);
        if Crypto::bn_cmp((int^)@s, (int^)@m, n) >= 0 { return false; }
        int n0 = Crypto::mont_setup((int^)@m, n, (int^)@rr);
        Crypto::mont_pow((int^)@x, (int^)@s, eb, elen, (int^)@m, n, (int^)@rr, n0);
        Crypto::bn_to_bytes((int^)@x, n, em, nlen);
        return true;
    }
    // the DigestInfo prefix of a hash (RFC 8017 9.2); the length
    static int rsa_prefix(int halg, char^ out) {
        String hex = "";
        if halg == 256 { hex = "3031300d060960864801650304020105000420"; }
        else if halg == 384 { hex = "3041300d060960864801650304020205000430"; }
        else { hex = "3051300d060960864801650304020305000440"; }
        int n = hex.len / 2;
        for i in 0..n {
            int hi = hex[2 * i] - '0';
            int lo = hex[2 * i + 1] - '0';
            if hi > 9 { hi = hi - 39; }
            if lo > 9 { lo = lo - 39; }
            out[i] = (char)(hi * 16 + lo);
        }
        return n;
    }
    // RSASSA-PKCS1-v1_5: the signature of the message msg
    static bool rsa_verify_pkcs1(char^ nb, int nlen, char^ eb, int elen, int halg, char^ msg, int mlen, char^ sig, int slen) {
        while nlen > 0 && nb[0] == 0 { nb += 1; nlen -= 1; }
        char em[512];
        if !Crypto::rsa_public(nb, nlen, eb, elen, sig, slen, (char^)@em) { return false; }
        char h[64];
        int hl = Crypto::hash(halg, msg, mlen, (char^)@h);
        char pre[24];
        int pl = Crypto::rsa_prefix(halg, (char^)@pre);
        int tlen = pl + hl;
        if nlen < tlen + 11 { return false; }
        // 00 01 FF .. FF 00 prefix hash
        int diff = 0;
        if em[0] != 0 || em[1] != 1 { diff = 1; }
        int ps = nlen - tlen - 3;
        for i in 0..ps { if (em[2 + i] & 255) != 255 { diff = 1; } }
        if em[2 + ps] != 0 { diff = 1; }
        for i in 0..pl { if em[3 + ps + i] != pre[i] { diff = 1; } }
        for i in 0..hl { if em[3 + ps + pl + i] != h[i] { diff = 1; } }
        return diff == 0;
    }
    // MGF1 (RFC 8017 B.2.1): length bytes from the seed
    static void mgf1(int halg, char^ seed, int slen, char^ out, int length) {
        int hl = Crypto::hash_size(halg);
        char^ buf = (char^)Mem::alloc(slen + 8);
        for i in 0..slen { buf[i] = seed[i]; }
        char h[64];
        int done = 0;
        int counter = 0;
        while done < length {
            buf[slen] = (char)((counter >> 24) & 255);
            buf[slen + 1] = (char)((counter >> 16) & 255);
            buf[slen + 2] = (char)((counter >> 8) & 255);
            buf[slen + 3] = (char)(counter & 255);
            Crypto::hash(halg, buf, slen + 4, (char^)@h);
            int take = length - done;
            if take > hl { take = hl; }
            for i in 0..take { out[done + i] = h[i]; }
            done += take;
            counter += 1;
        }
        Mem::free((void^)buf);
    }
    // RSASSA-PSS with MGF1 and a salt as long as the hash (what TLS 1.3 uses): the signature of the message msg
    static bool rsa_verify_pss(char^ nb, int nlen, char^ eb, int elen, int halg, char^ msg, int mlen, char^ sig, int slen) {
        while nlen > 0 && nb[0] == 0 { nb += 1; nlen -= 1; }
        char emfull[512];
        if !Crypto::rsa_public(nb, nlen, eb, elen, sig, slen, (char^)@emfull) { return false; }
        // modBits: the bits of the modulus
        int modbits = nlen * 8;
        int top = nb[0] & 255;
        while top < 128 { top = top << 1; modbits -= 1; }
        int embits = modbits - 1;
        int emlen = (embits + 7) / 8;
        char^ em = (char^)@emfull + (nlen - emlen);
        int hl = Crypto::hash_size(halg);
        int sl = hl;
        if emlen < hl + sl + 2 { return false; }
        if (em[emlen - 1] & 255) != 188 { return false; }
        int dblen = emlen - hl - 1;
        char^ hh = em + dblen;
        int cut = 8 * emlen - embits;
        if cut > 0 && ((em[0] & 255) >> (8 - cut)) != 0 { return false; }
        char^ db = (char^)Mem::alloc(dblen + 8);
        Crypto::mgf1(halg, hh, hl, db, dblen);
        for i in 0..dblen { db[i] = (char)(db[i] xor em[i]); }
        if cut > 0 { db[0] = (char)(db[0] & (255 >> cut)); }
        int bad = 0;
        int zeros = dblen - sl - 1;
        for i in 0..zeros { if db[i] != 0 { bad = 1; } }
        if db[zeros] != 1 { bad = 1; }
        char mprime[200];
        for i in 0..8 { mprime[i] = (char)0; }
        char mh[64];
        Crypto::hash(halg, msg, mlen, (char^)@mh);
        for i in 0..hl { mprime[8 + i] = mh[i]; }
        for i in 0..sl { mprime[8 + hl + i] = db[zeros + 1 + i]; }
        char h2[64];
        Crypto::hash(halg, (char^)@mprime, 8 + hl + sl, (char^)@h2);
        for i in 0..hl { if h2[i] != hh[i] { bad = 1; } }
        Mem::free((void^)db);
        return bad == 0;
    }
    // ---------------------------------------------------------------- ECDSA on P-256 and P-384 (checking only; the curves a = -3)
    static int unhex(String h, char^ out) {
        int n = h.len / 2;
        for i in 0..n {
            int hi = h[2 * i] - '0';
            int lo = h[2 * i + 1] - '0';
            if hi > 9 { hi = hi - 39; }
            if lo > 9 { lo = lo - 39; }
            out[i] = (char)(hi * 16 + lo);
        }
        return n;
    }
    // the constants of a curve (256 or 384) as big-endian bytes: which = 0 p, 1 n, 2 Gx, 3 Gy, 4 b
    static String ec_const(int curve, int which) {
        if curve == 256 {
            if which == 0 { return "ffffffff00000001000000000000000000000000ffffffffffffffffffffffff"; }
            if which == 1 { return "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551"; }
            if which == 2 { return "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296"; }
            if which == 3 { return "4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5"; }
            return "5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b";
        }
        if which == 0 { return "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeffffffff0000000000000000ffffffff"; }
        if which == 1 { return "ffffffffffffffffffffffffffffffffffffffffffffffffc7634d81f4372ddf581a0db248b0a77aecec196accc52973"; }
        if which == 2 { return "aa87ca22be8b05378eb1c71ef320ad746e1d3b628ba79b9859f741e082542a385502f25dbf55296c3a545e3872760ab7"; }
        if which == 3 { return "3617de4a96262c6f5d9e98bf9292dc29f8f41dbd289a147ce9da3113b5f0b8c00a60b1ce1d7e819d7a431d7c90ea0e5f"; }
        return "b3312fa7e23ee7e4988e056be3f82d19181d9c6efe8141120314088f5013875ac656398d8a2ed19d2a85c8edd3ec2aef";
    }
    // modular addition / subtraction of numbers below m
    static void fe_add(int^ r, int^ a, int^ b, int^ m, int n) {
        int t[16];
        for i in 0..n { t[i] = a[i]; }
        int carry = Crypto::bn_add((int^)@t, b, n);
        if carry == 1 || Crypto::bn_cmp((int^)@t, m, n) >= 0 { Crypto::bn_sub((int^)@t, m, n); }
        for i in 0..n { r[i] = t[i]; }
    }
    static void fe_sub(int^ r, int^ a, int^ b, int^ m, int n) {
        int t[16];
        for i in 0..n { t[i] = a[i]; }
        int borrow = Crypto::bn_sub((int^)@t, b, n);
        if borrow == 1 { Crypto::bn_add((int^)@t, m, n); }
        for i in 0..n { r[i] = t[i]; }
    }
    // points in Jacobian coordinates: 3 numbers of 16 limbs in one array (x at 0, y at 16, z at 32); z = 0 is the point at infinity.
    // The context: pm (the prime) at 0, prr at 16, [pn0, n] at 32,33 ; the numbers are in the Montgomery form.
    static void ec_double(int^ r, int^ pt, int^ ctx) {
        int^ pm = ctx;
        int^ prr = ctx + 128;
        int n0 = ctx[32];
        int n = ctx[33];
        int^ x1 = pt;
        int^ y1 = pt + 128;
        int^ z1 = pt + 256;
        int delta[16];
        int gamma[16];
        int beta[16];
        int alpha[16];
        int t1[16];
        int t2[16];
        Crypto::mont_mul((int^)@delta, z1, z1, pm, n, n0);
        Crypto::mont_mul((int^)@gamma, y1, y1, pm, n, n0);
        Crypto::mont_mul((int^)@beta, x1, (int^)@gamma, pm, n, n0);
        Crypto::fe_sub((int^)@t1, x1, (int^)@delta, pm, n);
        Crypto::fe_add((int^)@t2, x1, (int^)@delta, pm, n);
        Crypto::mont_mul((int^)@alpha, (int^)@t1, (int^)@t2, pm, n, n0);
        Crypto::fe_add((int^)@t1, (int^)@alpha, (int^)@alpha, pm, n);
        Crypto::fe_add((int^)@alpha, (int^)@t1, (int^)@alpha, pm, n);               // alpha = 3 (x - delta)(x + delta)
        int x3[16];
        int y3[16];
        int z3[16];
        Crypto::mont_mul((int^)@t1, (int^)@alpha, (int^)@alpha, pm, n, n0);
        Crypto::fe_add((int^)@t2, (int^)@beta, (int^)@beta, pm, n);
        Crypto::fe_add((int^)@t2, (int^)@t2, (int^)@t2, pm, n);                       // 4 beta
        Crypto::fe_add((int^)@x3, (int^)@t2, (int^)@t2, pm, n);                       // 8 beta
        Crypto::fe_sub((int^)@x3, (int^)@t1, (int^)@x3, pm, n);                       // x3 = alpha^2 - 8 beta
        Crypto::fe_add((int^)@t1, y1, z1, pm, n);
        Crypto::mont_mul((int^)@z3, (int^)@t1, (int^)@t1, pm, n, n0);
        Crypto::fe_sub((int^)@z3, (int^)@z3, (int^)@gamma, pm, n);
        Crypto::fe_sub((int^)@z3, (int^)@z3, (int^)@delta, pm, n);                  // z3 = (y + z)^2 - gamma - delta
        Crypto::fe_sub((int^)@t1, (int^)@t2, (int^)@x3, pm, n);
        Crypto::mont_mul((int^)@y3, (int^)@alpha, (int^)@t1, pm, n, n0);
        Crypto::mont_mul((int^)@t1, (int^)@gamma, (int^)@gamma, pm, n, n0);
        Crypto::fe_add((int^)@t1, (int^)@t1, (int^)@t1, pm, n);
        Crypto::fe_add((int^)@t1, (int^)@t1, (int^)@t1, pm, n);
        Crypto::fe_add((int^)@t1, (int^)@t1, (int^)@t1, pm, n);                       // 8 gamma^2
        Crypto::fe_sub((int^)@y3, (int^)@y3, (int^)@t1, pm, n);
        for i in 0..n { r[i] = x3[i]; r[16 + i] = y3[i]; r[32 + i] = z3[i]; }
    }
    static void ec_add(int^ r, int^ p1, int^ p2, int^ ctx) {
        int^ pm = ctx;
        int n0 = ctx[32];
        int n = ctx[33];
        if Crypto::bn_is_zero(p1 + 256, n) { for i in 0..48 { r[i] = p2[i]; } return; }
        if Crypto::bn_is_zero(p2 + 256, n) { for i in 0..48 { r[i] = p1[i]; } return; }
        int z1z1[16];
        int z2z2[16];
        int u1[16];
        int u2[16];
        int s1[16];
        int s2[16];
        int t[16];
        Crypto::mont_mul((int^)@z1z1, p1 + 256, p1 + 256, pm, n, n0);
        Crypto::mont_mul((int^)@z2z2, p2 + 256, p2 + 256, pm, n, n0);
        Crypto::mont_mul((int^)@u1, p1, (int^)@z2z2, pm, n, n0);
        Crypto::mont_mul((int^)@u2, p2, (int^)@z1z1, pm, n, n0);
        Crypto::mont_mul((int^)@t, p2 + 256, (int^)@z2z2, pm, n, n0);
        Crypto::mont_mul((int^)@s1, p1 + 128, (int^)@t, pm, n, n0);
        Crypto::mont_mul((int^)@t, p1 + 256, (int^)@z1z1, pm, n, n0);
        Crypto::mont_mul((int^)@s2, p2 + 128, (int^)@t, pm, n, n0);
        int h[16];
        int rr[16];
        Crypto::fe_sub((int^)@h, (int^)@u2, (int^)@u1, pm, n);
        Crypto::fe_sub((int^)@rr, (int^)@s2, (int^)@s1, pm, n);
        if Crypto::bn_is_zero((int^)@h, n) {
            if Crypto::bn_is_zero((int^)@rr, n) { Crypto::ec_double(r, p1, ctx); return; }
            for i in 0..48 { r[i] = 0; }                  // P + (-P) = infinity
            return;
        }
        int h2[16];
        int h3[16];
        int v[16];
        int x3[16];
        int y3[16];
        int z3[16];
        Crypto::mont_mul((int^)@h2, (int^)@h, (int^)@h, pm, n, n0);
        Crypto::mont_mul((int^)@h3, (int^)@h, (int^)@h2, pm, n, n0);
        Crypto::mont_mul((int^)@v, (int^)@u1, (int^)@h2, pm, n, n0);
        Crypto::mont_mul((int^)@x3, (int^)@rr, (int^)@rr, pm, n, n0);
        Crypto::fe_sub((int^)@x3, (int^)@x3, (int^)@h3, pm, n);
        Crypto::fe_sub((int^)@x3, (int^)@x3, (int^)@v, pm, n);
        Crypto::fe_sub((int^)@x3, (int^)@x3, (int^)@v, pm, n);
        Crypto::fe_sub((int^)@t, (int^)@v, (int^)@x3, pm, n);
        Crypto::mont_mul((int^)@y3, (int^)@rr, (int^)@t, pm, n, n0);
        Crypto::mont_mul((int^)@t, (int^)@s1, (int^)@h3, pm, n, n0);
        Crypto::fe_sub((int^)@y3, (int^)@y3, (int^)@t, pm, n);
        Crypto::mont_mul((int^)@t, p1 + 256, p2 + 256, pm, n, n0);
        Crypto::mont_mul((int^)@z3, (int^)@t, (int^)@h, pm, n, n0);
        for i in 0..n { r[i] = x3[i]; r[16 + i] = y3[i]; r[32 + i] = z3[i]; }
    }
    // r = k * pt, k as limbs (kn limbs)
    static void ec_mul(int^ r, int^ k, int kn, int^ pt, int^ ctx) {
        int acc[48];
        for i in 0..48 { acc[i] = 0; }
        int bit = kn * 28 - 1;
        while bit >= 0 {
            Crypto::ec_double((int^)@acc, (int^)@acc, ctx);
            if ((k[bit / 28] >> (bit % 28)) & 1) == 1 { Crypto::ec_add((int^)@acc, (int^)@acc, pt, ctx); }
            bit -= 1;
        }
        for i in 0..48 { r[i] = acc[i]; }
    }
    // ECDSA (FIPS 186-4 6.4): the public key is the point (qx, qy) as big-endian bytes of the size of the curve; e: the hash of the message (bytes);
    // r and s: the two numbers of the signature (bytes). curve: 256 or 384.
    static bool ecdsa_verify(int curve, char^ qx, char^ qy, char^ hash, int hlen, char^ rb, int rlen, char^ sb, int slen) {
        int size = 32;
        if curve == 384 { size = 48; }
        int n = (size * 8 + 27) / 28;
        if rlen > size || slen > size || rlen == 0 || slen == 0 { return false; }
        char buf[48];
        int pm[16];
        int prr[16];
        int nm[16];
        int nrr[16];
        int gx[16];
        int gy[16];
        int bb[16];
        Crypto::unhex(Crypto::ec_const(curve, 0), (char^)@buf);
        Crypto::bn_from_bytes((int^)@pm, n, (char^)@buf, size);
        Crypto::unhex(Crypto::ec_const(curve, 1), (char^)@buf);
        Crypto::bn_from_bytes((int^)@nm, n, (char^)@buf, size);
        int pn0 = Crypto::mont_setup((int^)@pm, n, (int^)@prr);
        int nn0 = Crypto::mont_setup((int^)@nm, n, (int^)@nrr);
        int ctx[40];
        for i in 0..16 { ctx[i] = pm[i]; ctx[16 + i] = prr[i]; }
        ctx[32] = pn0;
        ctx[33] = n;
        // the point Q, below p, on the curve
        int q[48];
        int qxn[16];
        int qyn[16];
        Crypto::bn_from_bytes((int^)@qxn, n, qx, size);
        Crypto::bn_from_bytes((int^)@qyn, n, qy, size);
        if Crypto::bn_cmp((int^)@qxn, (int^)@pm, n) >= 0 || Crypto::bn_cmp((int^)@qyn, (int^)@pm, n) >= 0 { return false; }
        int one[16];
        for i in 0..16 { one[i] = 0; }
        one[0] = 1;
        for i in 0..48 { q[i] = 0; }
        Crypto::mont_mul((int^)@q, (int^)@qxn, (int^)@prr, (int^)@pm, n, pn0);
        Crypto::mont_mul((int^)@q + 128, (int^)@qyn, (int^)@prr, (int^)@pm, n, pn0);
        Crypto::mont_mul((int^)@q + 256, (int^)@one, (int^)@prr, (int^)@pm, n, pn0);          // z = 1
        // y^2 = x^3 - 3x + b
        Crypto::unhex(Crypto::ec_const(curve, 4), (char^)@buf);
        Crypto::bn_from_bytes((int^)@bb, n, (char^)@buf, size);
        int bm[16];
        Crypto::mont_mul((int^)@bm, (int^)@bb, (int^)@prr, (int^)@pm, n, pn0);
        int lhs[16];
        int rhs[16];
        int t[16];
        Crypto::mont_mul((int^)@lhs, (int^)@q + 128, (int^)@q + 128, (int^)@pm, n, pn0);
        Crypto::mont_mul((int^)@t, (int^)@q, (int^)@q, (int^)@pm, n, pn0);
        Crypto::mont_mul((int^)@rhs, (int^)@t, (int^)@q, (int^)@pm, n, pn0);
        Crypto::fe_sub((int^)@rhs, (int^)@rhs, (int^)@q, (int^)@pm, n);
        Crypto::fe_sub((int^)@rhs, (int^)@rhs, (int^)@q, (int^)@pm, n);
        Crypto::fe_sub((int^)@rhs, (int^)@rhs, (int^)@q, (int^)@pm, n);
        Crypto::fe_add((int^)@rhs, (int^)@rhs, (int^)@bm, (int^)@pm, n);
        if Crypto::bn_cmp((int^)@lhs, (int^)@rhs, n) != 0 { return false; }
        // r and s are in 1 .. n-1
        int r[16];
        int s[16];
        Crypto::bn_from_bytes((int^)@r, n, rb, rlen);
        Crypto::bn_from_bytes((int^)@s, n, sb, slen);
        if Crypto::bn_is_zero((int^)@r, n) || Crypto::bn_is_zero((int^)@s, n) { return false; }
        if Crypto::bn_cmp((int^)@r, (int^)@nm, n) >= 0 || Crypto::bn_cmp((int^)@s, (int^)@nm, n) >= 0 { return false; }
        // e: the leftmost `size` bytes of the hash, as a number below n
        char eb[48];
        for i in 0..size { eb[i] = (char)0; }
        if hlen >= size {
            for i in 0..size { eb[i] = hash[i]; }
        } else {
            for i in 0..hlen { eb[size - hlen + i] = hash[i]; }
        }
        int e[16];
        Crypto::bn_from_bytes((int^)@e, n, (char^)@eb, size);
        if Crypto::bn_cmp((int^)@e, (int^)@nm, n) >= 0 { Crypto::bn_sub((int^)@e, (int^)@nm, n); }
        // w = s^-1 mod n, u1 = e w, u2 = r w
        char nm2[48];
        Crypto::unhex(Crypto::ec_const(curve, 1), (char^)@nm2);
        nm2[size - 1] = (char)(nm2[size - 1] - 2);            // n - 2 (the last byte of n is above 2)
        int w[16];
        Crypto::mont_pow((int^)@w, (int^)@s, (char^)@nm2, size, (int^)@nm, n, (int^)@nrr, nn0);
        int u1[16];
        int u2[16];
        Crypto::mont_mul((int^)@t, (int^)@e, (int^)@nrr, (int^)@nm, n, nn0);
        Crypto::mont_mul((int^)@u1, (int^)@t, (int^)@w, (int^)@nm, n, nn0);
        Crypto::mont_mul((int^)@t, (int^)@r, (int^)@nrr, (int^)@nm, n, nn0);
        Crypto::mont_mul((int^)@u2, (int^)@t, (int^)@w, (int^)@nm, n, nn0);
        // R = u1 G + u2 Q
        int g[48];
        for i in 0..48 { g[i] = 0; }
        Crypto::unhex(Crypto::ec_const(curve, 2), (char^)@buf);
        Crypto::bn_from_bytes((int^)@gx, n, (char^)@buf, size);
        Crypto::unhex(Crypto::ec_const(curve, 3), (char^)@buf);
        Crypto::bn_from_bytes((int^)@gy, n, (char^)@buf, size);
        Crypto::mont_mul((int^)@g, (int^)@gx, (int^)@prr, (int^)@pm, n, pn0);
        Crypto::mont_mul((int^)@g + 128, (int^)@gy, (int^)@prr, (int^)@pm, n, pn0);
        Crypto::mont_mul((int^)@g + 256, (int^)@one, (int^)@prr, (int^)@pm, n, pn0);
        int r1[48];
        int r2[48];
        int sum[48];
        Crypto::ec_mul((int^)@r1, (int^)@u1, n, (int^)@g, (int^)@ctx);
        Crypto::ec_mul((int^)@r2, (int^)@u2, n, (int^)@q, (int^)@ctx);
        Crypto::ec_add((int^)@sum, (int^)@r1, (int^)@r2, (int^)@ctx);
        if Crypto::bn_is_zero((int^)@sum + 256, n) { return false; }
        // x = X / Z^2, then mod n, compared with r
        char pm2[48];
        Crypto::unhex(Crypto::ec_const(curve, 0), (char^)@pm2);
        pm2[size - 1] = (char)(pm2[size - 1] - 2);             // p - 2
        int zi[16];
        int zi2[16];
        Crypto::mont_pow((int^)@zi, (int^)@sum + 256, (char^)@pm2, size, (int^)@pm, n, (int^)@prr, pn0);
        // zi is z^-1 in the normal form; the z in the sum is in the Montgomery form, so mont_pow gave (zR)^(p-2) = z^-1 R^-1: fix with R^2
        Crypto::mont_mul((int^)@zi, (int^)@zi, (int^)@prr, (int^)@pm, n, pn0);            // z^-1 R^-1 * R^2 / R = z^-1 (normal form)
        Crypto::mont_mul((int^)@zi, (int^)@zi, (int^)@prr, (int^)@pm, n, pn0);            // now in the Montgomery form
        Crypto::mont_mul((int^)@zi2, (int^)@zi, (int^)@zi, (int^)@pm, n, pn0);
        int xa[16];
        Crypto::mont_mul((int^)@xa, (int^)@sum, (int^)@zi2, (int^)@pm, n, pn0);
        Crypto::mont_mul((int^)@xa, (int^)@xa, (int^)@one, (int^)@pm, n, pn0);            // out of the Montgomery form
        if Crypto::bn_cmp((int^)@xa, (int^)@nm, n) >= 0 { Crypto::bn_sub((int^)@xa, (int^)@nm, n); }
        return Crypto::bn_cmp((int^)@xa, (int^)@r, n) == 0;
    }
    // a DER signature (SEQUENCE { INTEGER r, INTEGER s }) of a message that is hashed here with halg
    static bool ecdsa_verify_der(int curve, char^ qx, char^ qy, int halg, char^ msg, int mlen, char^ sig, int slen) {
        if slen < 8 || (sig[0] & 255) != 0x30 { return false; }
        int p = 2;
        if (sig[1] & 255) == 0x81 { p = 3; }
        if (sig[p] & 255) != 2 { return false; }
        int rl = sig[p + 1] & 255;
        char^ rp = sig + p + 2;
        int q = p + 2 + rl;
        if q + 2 > slen || (sig[q] & 255) != 2 { return false; }
        int sl = sig[q + 1] & 255;
        char^ sp = sig + q + 2;
        if q + 2 + sl > slen { return false; }
        while rl > 1 && rp[0] == 0 { rp += 1; rl -= 1; }
        while sl > 1 && sp[0] == 0 { sp += 1; sl -= 1; }
        char h[64];
        int hl = Crypto::hash(halg, msg, mlen, (char^)@h);
        return Crypto::ecdsa_verify(curve, qx, qy, (char^)@h, hl, rp, rl, sp, sl);
    }
    // ---------------------------------------------------------------- X.509 certificates (DER), the chain, the names, the dates
    // the element at p (avail bytes follow): its total size, or -1; info gets [tag, header size, content size]
    static int der_elem(char^ p, int avail, int^ info) {
        if avail < 2 { return -1; }
        int tag = p[0] & 255;
        int l = p[1] & 255;
        int hdr = 2;
        if (l & 128) != 0 {
            int nb = l & 127;
            if nb == 0 || nb > 3 || avail < 2 + nb { return -1; }
            l = 0;
            for i in 0..nb { l = (l << 8) | (p[2 + i] & 255); }
            hdr = 2 + nb;
        }
        if hdr + l > avail || (tag & 31) == 31 { return -1; }
        info[0] = tag;
        info[1] = hdr;
        info[2] = l;
        return hdr + l;
    }
    static bool bytes_equal(char^ a, char^ b, int n) {
        int diff = 0;
        for i in 0..n { diff = diff | (a[i] xor b[i]); }
        return diff == 0;
    }
    // does the OID (the content bytes at p, n long) equal the hex text?
    static bool oid_is(char^ p, int n, String hex) {
        if hex.len != n * 2 { return false; }
        char t[24];
        Crypto::unhex(hex, (char^)@t);
        return Crypto::bytes_equal(p, (char^)@t, n);
    }
    // the fields of a certificate (offsets into the DER bytes `c`, 0 when absent):
    //  0 tbs offset  1 tbs size   2 outer signature algorithm (oid content offset)  3 its size   4 signature bits  5 size   6 issuer (whole element)  7 size   8 subject  9 size
    //  10 notBefore (content)  11 size  12 tag   13 notAfter  14 size  15 tag   16 key algorithm oid  17 size   18 key parameters oid (content)  19 size   20 public key bits  21 size
    //  22 subjectAltName extension value (the content of its OCTET STRING)  23 size   24 basicConstraints: -1 absent, 0 not a CA, 1 a CA
    static bool x509_parse(char^ c, int len, int^ o) {
        int info[3];
        for i in 0..28 { o[i] = 0; }
        o[24] = -1;
        int total = Crypto::der_elem(c, len, (int^)@info);
        if total < 0 || info[0] != 0x30 { return false; }
        int base = info[1];
        int end = base + info[2];
        int tbs = base;
        int e = Crypto::der_elem(c + tbs, end - tbs, (int^)@info);
        if e < 0 || info[0] != 0x30 { return false; }
        o[0] = tbs;
        o[1] = e;
        int tbs_in = tbs + info[1];
        int tbs_end = tbs + e;
        // the signature algorithm and the signature
        int q = tbs + e;
        int e2 = Crypto::der_elem(c + q, end - q, (int^)@info);
        if e2 < 0 || info[0] != 0x30 { return false; }
        int ai = q + info[1];
        int e3 = Crypto::der_elem(c + ai, q + e2 - ai, (int^)@info);
        if e3 < 0 || info[0] != 6 { return false; }
        o[2] = ai + info[1];
        o[3] = info[2];
        q += e2;
        e2 = Crypto::der_elem(c + q, end - q, (int^)@info);
        if e2 < 0 || info[0] != 3 || info[2] < 2 { return false; }
        o[4] = q + info[1] + 1;
        o[5] = info[2] - 1;
        // inside the tbs
        q = tbs_in;
        e = Crypto::der_elem(c + q, tbs_end - q, (int^)@info);
        if e < 0 { return false; }
        if info[0] == 0xA0 {
            q += e;
            e = Crypto::der_elem(c + q, tbs_end - q, (int^)@info);
            if e < 0 { return false; }
        }
        q += e;                                                          // the serial number was in e
        e = Crypto::der_elem(c + q, tbs_end - q, (int^)@info);           // the signature algorithm
        if e < 0 { return false; }
        q += e;
        e = Crypto::der_elem(c + q, tbs_end - q, (int^)@info);           // the issuer
        if e < 0 || info[0] != 0x30 { return false; }
        o[6] = q;
        o[7] = e;
        q += e;
        e = Crypto::der_elem(c + q, tbs_end - q, (int^)@info);           // the validity
        if e < 0 || info[0] != 0x30 { return false; }
        int vq = q + info[1];
        int vend = q + e;
        q += e;
        int e4 = Crypto::der_elem(c + vq, vend - vq, (int^)@info);
        if e4 < 0 { return false; }
        o[10] = vq + info[1];
        o[11] = info[2];
        o[12] = info[0];
        vq += e4;
        e4 = Crypto::der_elem(c + vq, vend - vq, (int^)@info);
        if e4 < 0 { return false; }
        o[13] = vq + info[1];
        o[14] = info[2];
        o[15] = info[0];
        e = Crypto::der_elem(c + q, tbs_end - q, (int^)@info);           // the subject
        if e < 0 || info[0] != 0x30 { return false; }
        o[8] = q;
        o[9] = e;
        q += e;
        e = Crypto::der_elem(c + q, tbs_end - q, (int^)@info);           // the public key info
        if e < 0 || info[0] != 0x30 { return false; }
        int kq = q + info[1];
        int kend = q + e;
        q += e;
        int e5 = Crypto::der_elem(c + kq, kend - kq, (int^)@info);       // its algorithm
        if e5 < 0 || info[0] != 0x30 { return false; }
        int aq = kq + info[1];
        int aend = kq + e5;
        kq += e5;
        int e6 = Crypto::der_elem(c + aq, aend - aq, (int^)@info);
        if e6 < 0 || info[0] != 6 { return false; }
        o[16] = aq + info[1];
        o[17] = info[2];
        aq += e6;
        if aq < aend {
            e6 = Crypto::der_elem(c + aq, aend - aq, (int^)@info);
            if e6 >= 0 && info[0] == 6 {
                o[18] = aq + info[1];
                o[19] = info[2];
            }
        }
        e5 = Crypto::der_elem(c + kq, kend - kq, (int^)@info);
        if e5 < 0 || info[0] != 3 || info[2] < 2 { return false; }
        o[20] = kq + info[1] + 1;
        o[21] = info[2] - 1;
        // the extensions: [3] { SEQUENCE OF { oid, critical?, OCTET STRING } }
        while q < tbs_end {
            e = Crypto::der_elem(c + q, tbs_end - q, (int^)@info);
            if e < 0 { return false; }
            if info[0] == 0xA3 {
                int sq = q + info[1];
                int send = q + e;
                int e7 = Crypto::der_elem(c + sq, send - sq, (int^)@info);
                if e7 < 0 || info[0] != 0x30 { return false; }
                int xq = sq + info[1];
                int xend = sq + e7;
                while xq < xend {
                    int ee = Crypto::der_elem(c + xq, xend - xq, (int^)@info);
                    if ee < 0 || info[0] != 0x30 { return false; }
                    int iq = xq + info[1];
                    int iend = xq + ee;
                    int e8 = Crypto::der_elem(c + iq, iend - iq, (int^)@info);
                    if e8 >= 0 && info[0] == 6 {
                        int ooff = iq + info[1];
                        int olen = info[2];
                        iq += e8;
                        e8 = Crypto::der_elem(c + iq, iend - iq, (int^)@info);
                        if e8 >= 0 && info[0] == 1 {
                            iq += e8;
                            e8 = Crypto::der_elem(c + iq, iend - iq, (int^)@info);
                        }
                        if e8 >= 0 && info[0] == 4 {
                            int voff = iq + info[1];
                            int vlen = info[2];
                            if Crypto::oid_is(c + ooff, olen, "551d11") { o[22] = voff; o[23] = vlen; }
                            if Crypto::oid_is(c + ooff, olen, "551d13") {
                                o[24] = 0;
                                int bi[3];
                                int b1 = Crypto::der_elem(c + voff, vlen, (int^)@bi);
                                if b1 >= 0 && bi[0] == 0x30 && bi[2] > 0 {
                                    int b2 = Crypto::der_elem(c + voff + bi[1], bi[2], (int^)@bi);
                                    if b2 >= 0 && bi[0] == 1 && bi[2] == 1 && c[voff + 2 + 2] != 0 { o[24] = 1; }
                                }
                            }
                        }
                    }
                    xq += ee;
                }
            }
            q += e;
        }
        return true;
    }
    // days since 1970-01-01 of a date (the civil calendar)
    static int days_from_civil(int y, int m, int d) {
        if m <= 2 { y -= 1; }
        int era = y / 400;
        if y < 0 { era = (y - 399) / 400; }
        int yoe = y - era * 400;
        int mp = m + 9;
        if m > 2 { mp = m - 3; }
        int doy = (153 * mp + 2) / 5 + d - 1;
        int doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        return era * 146097 + doe - 719468;
    }
    static int two(char^ p) { return (p[0] - '0') * 10 + (p[1] - '0'); }
    // the seconds since 1970 of a UTCTime (tag 0x17: YYMMDDHHMMSSZ) or GeneralizedTime (tag 0x18: YYYYMMDDHHMMSSZ); -1 when it is not understood
    static int der_time(char^ p, int n, int tag) {
        int y = 0;
        int k = 0;
        if tag == 0x17 {
            if n < 13 { return -1; }
            y = Crypto::two(p);
            if y < 50 { y += 2000; } else { y += 1900; }
            k = 2;
        } else if tag == 0x18 {
            if n < 15 { return -1; }
            y = Crypto::two(p) * 100 + Crypto::two(p + 2);
            k = 4;
        } else {
            return -1;
        }
        int mo = Crypto::two(p + k);
        int d = Crypto::two(p + k + 2);
        int h = Crypto::two(p + k + 4);
        int mi = Crypto::two(p + k + 6);
        int sec = Crypto::two(p + k + 8);
        return Crypto::days_from_civil(y, mo, d) * 86400 + h * 3600 + mi * 60 + sec;
    }
    static int unix_now() {
        int ts[2];
        Sys::clock_gettime(0, @ts);
        return ts[0];
    }
    static char lower_c(char c) {
        if c >= 'A' && c <= 'Z' { return (char)(c + 32); }
        return c;
    }
    // does a name of the certificate (a dNSName, may start with *.) cover the host?
    static bool host_matches(char^ pat, int plen, String host) {
        String p = "";
        for i in 0..plen { p.push(Crypto::lower_c(pat[i])); }
        String h = "";
        for i in 0..host.len { h.push(Crypto::lower_c(host[i])); }
        if p.starts_with("*.") {
            int dot = h.find(".");
            if dot <= 0 { return false; }
            return h.slice(dot, h.len) == p.slice(1, p.len);
        }
        return p == h;
    }
    // is the host named in the subjectAltName extension of the certificate?
    static bool x509_names_host(char^ c, int^ o, String host) {
        if o[22] == 0 { return false; }
        int info[3];
        int e = Crypto::der_elem(c + o[22], o[23], (int^)@info);
        if e < 0 || info[0] != 0x30 { return false; }
        int q = o[22] + info[1];
        int end = o[22] + e;
        while q < end {
            int e2 = Crypto::der_elem(c + q, end - q, (int^)@info);
            if e2 < 0 { return false; }
            if info[0] == 0x82 && Crypto::host_matches(c + q + info[1], info[2], host) { return true; }
            q += e2;
        }
        return false;
    }
    // the public key of a certificate: the kind (1 RSA, 2 P-256, 3 P-384, 0 not supported)
    static int x509_key_kind(char^ c, int^ o) {
        if Crypto::oid_is(c + o[16], o[17], "2a864886f70d010101") { return 1; }
        if Crypto::oid_is(c + o[16], o[17], "2a8648ce3d0201") {
            if o[19] > 0 {
                bool p256 = Crypto::oid_is(c + o[18], o[19], "2a8648ce3d030107");
                bool p384 = Crypto::oid_is(c + o[18], o[19], "2b81040022");
                if p256 && o[21] == 65 { return 2; }
                if p384 && o[21] == 97 { return 3; }
            }
        }
        return 0;
    }
    // verifies `msg` (mlen bytes) signed with the key of the certificate cs (parsed in os): by the signature scheme of TLS (0x0804 ...) or by an X.509 algorithm (scheme 1 sha256WithRSA, 2 sha384WithRSA, 3 sha512WithRSA, 4 ecdsa-sha256, 5 ecdsa-sha384, 6 ecdsa-sha512)
    static bool x509_check_sig(char^ cs, int^ os, int scheme, char^ msg, int mlen, char^ sig, int slen) {
        int kind = Crypto::x509_key_kind(cs, os);
        if kind == 0 { return false; }
        int info[3];
        char^ key = cs + os[20];
        if kind == 1 {
            // SEQUENCE { INTEGER n, INTEGER e }
            int e = Crypto::der_elem(key, os[21], (int^)@info);
            if e < 0 || info[0] != 0x30 { return false; }
            int q = info[1];
            int end = e;
            int e1 = Crypto::der_elem(key + q, end - q, (int^)@info);
            if e1 < 0 || info[0] != 2 { return false; }
            char^ nb = key + q + info[1];
            int nlen = info[2];
            q += e1;
            int e2 = Crypto::der_elem(key + q, end - q, (int^)@info);
            if e2 < 0 || info[0] != 2 { return false; }
            char^ eb = key + q + info[1];
            int elen = info[2];
            if scheme == 1 || scheme == 2 || scheme == 3 {
                int halg = 256;
                if scheme == 2 { halg = 384; }
                if scheme == 3 { halg = 512; }
                return Crypto::rsa_verify_pkcs1(nb, nlen, eb, elen, halg, msg, mlen, sig, slen);
            }
            if scheme == 0x0804 { return Crypto::rsa_verify_pss(nb, nlen, eb, elen, 256, msg, mlen, sig, slen); }
            if scheme == 0x0805 { return Crypto::rsa_verify_pss(nb, nlen, eb, elen, 384, msg, mlen, sig, slen); }
            if scheme == 0x0806 { return Crypto::rsa_verify_pss(nb, nlen, eb, elen, 512, msg, mlen, sig, slen); }
            return false;
        }
        int curve = 256;
        int size = 32;
        if kind == 3 { curve = 384; size = 48; }
        if (key[0] & 255) != 4 { return false; }
        int halg = 0;
        if scheme == 4 || scheme == 0x0403 { halg = 256; }
        if scheme == 5 || scheme == 0x0503 { halg = 384; }
        if scheme == 6 || scheme == 0x0603 { halg = 512; }
        if halg == 0 { return false; }
        if (scheme == 0x0403 && curve != 256) || (scheme == 0x0503 && curve != 384) { return false; }
        return Crypto::ecdsa_verify_der(curve, key + 1, key + 1 + size, halg, msg, mlen, sig, slen);
    }
    // the scheme number (see x509_check_sig) of the signature algorithm of a certificate; 0 when it is not supported
    static int x509_sig_scheme(char^ c, int^ o) {
        char^ p = c + o[2];
        int n = o[3];
        if Crypto::oid_is(p, n, "2a864886f70d01010b") { return 1; }
        if Crypto::oid_is(p, n, "2a864886f70d01010c") { return 2; }
        if Crypto::oid_is(p, n, "2a864886f70d01010d") { return 3; }
        if Crypto::oid_is(p, n, "2a8648ce3d040302") { return 4; }
        if Crypto::oid_is(p, n, "2a8648ce3d040303") { return 5; }
        if Crypto::oid_is(p, n, "2a8648ce3d040304") { return 6; }
        return 0;
    }
    // is the certificate c (parsed in o) valid at the time `now`?
    static bool x509_valid_at(char^ c, int^ o, int now) {
        int nb = Crypto::der_time(c + o[10], o[11], o[12]);
        int na = Crypto::der_time(c + o[13], o[14], o[15]);
        return nb >= 0 && na >= 0 && now >= nb && now <= na;
    }
    // is the certificate `c` signed by the certificate `i`? (the issuer name, the signature, and that i may sign certificates)
    static bool x509_signed_by(char^ c, int^ o, char^ i, int^ oi, int now) {
        if o[7] != oi[9] || !Crypto::bytes_equal(c + o[6], i + oi[8], o[7]) { return false; }
        if oi[24] == 0 { return false; }                      // a certificate that says it is not a CA
        if !Crypto::x509_valid_at(i, oi, now) { return false; }
        int scheme = Crypto::x509_sig_scheme(c, o);
        if scheme == 0 { return false; }
        return Crypto::x509_check_sig(i, oi, scheme, c + o[0], o[1], c + o[4], o[5]);
    }
    // ---------------------------------------------------------------- base 64 and the files of trusted certificates
    static int b64_value(int c) {
        if c >= 'A' && c <= 'Z' { return c - 'A'; }
        if c >= 'a' && c <= 'z' { return c - 'a' + 26; }
        if c >= '0' && c <= '9' { return c - '0' + 52; }
        if c == '+' { return 62; }
        if c == '/' { return 63; }
        return -1;
    }
    // the bytes of a base 64 text (spaces and line ends are skipped); out must have room for n * 3 / 4 bytes
    static int b64_decode(char^ in, int n, char^ out) {
        int acc = 0;
        int bits = 0;
        int w = 0;
        for i in 0..n {
            int v = Crypto::b64_value(in[i] & 255);
            if v >= 0 {
                acc = (acc << 6) | v;
                bits += 6;
                if bits >= 8 {
                    out[w] = (char)((acc >> (bits - 8)) & 255);
                    w += 1;
                    bits -= 8;
                }
            }
        }
        return w;
    }
    // a whole file as text, "" when it cannot be read
    static String read_text(String path) {
        int fd = Sys::open_read(path.c());
        if fd < 0 { return ""; }
        char buf[8192];
        String r = "";
        while true {
            int n = Sys::read(fd, @buf, 8192);
            if n <= 0 { break; }
            for i in 0..n { r.push(buf[i]); }
        }
        Sys::close(fd);
        return r;
    }
    static int find_from(String s, String x, int from) {
        if from >= s.len { return -1; }
        int k = s.slice(from, s.len).find(x);
        if k < 0 { return -1; }
        return from + k;
    }
    // the certificates of a PEM text one after the other (DER, each prefixed by its size as 4 bytes, big-endian) in out; the number of bytes written
    static int pem_to_der_list(String text, char^ out, int cap) {
        int w = 0;
        int pos = 0;
        String begin = "-----BEGIN CERTIFICATE-----";
        String endm = "-----END CERTIFICATE-----";
        while true {
            int b = Crypto::find_from(text, begin, pos);
            if b < 0 { break; }
            int e = Crypto::find_from(text, endm, b);
            if e < 0 { break; }
            int start = b + begin.len;
            if w + 4 + (e - start) * 3 / 4 + 8 > cap { break; }
            int n = Crypto::b64_decode(text.c() + start, e - start, out + w + 4);
            out[w] = (char)((n >> 24) & 255);
            out[w + 1] = (char)((n >> 16) & 255);
            out[w + 2] = (char)((n >> 8) & 255);
            out[w + 3] = (char)(n & 255);
            w += 4 + n;
            pos = e + endm.len;
        }
        return w;
    }
    // ---------------------------------------------------------------- the trust store and the check of a chain
    static String env_value(String name) {
        int i = argc() + 1;
        while arg(i) != null {
            char^ e = (char^)arg(i);
            int k = 0;
            while k < name.len && e[k] == name[k] { k += 1; }
            if k == name.len && e[k] == '=' {
                String v = "";
                int j = k + 1;
                while e[j] != 0 { v.push(e[j]); j += 1; }
                return v;
            }
            i += 1;
        }
        return "";
    }
    // the names of the files of a folder, one per line ("" when it is not a folder)
    static String list_dir(String path) {
        int fd = Sys::open_dir(path.c());
        if fd < 0 { return ""; }
        char buf[4096];
        String r = "";
        while true {
            int n = Sys::getdents(fd, @buf, 4096);
            if n <= 0 { break; }
            int pos = 0;
            while pos < n {
                int reclen = (buf[pos + 16] & 255) | ((buf[pos + 17] & 255) << 8);
                String name = "";
                int k = pos + 19;
                while buf[k] != 0 { name.push(buf[k]); k += 1; }
                if name != "." && name != ".." { r.append(name + "\n"); }
                pos += reclen;
            }
        }
        Sys::close(fd);
        return r;
    }
    // the texts (PEM) in which the trusted certificates are: the files of J2K_CA (a file or a folder) or, when it is not set, the usual places
    static String[] ca_files() {
        String[] r = arr(0);
        String own = Crypto::env_value("J2K_CA");
        if own.len > 0 { r.push(own); return r; }
        String ssl = Crypto::env_value("SSL_CERT_FILE");
        if ssl.len > 0 { r.push(ssl); }
        String prefix = Crypto::env_value("PREFIX");
        if prefix.len > 0 { r.push(prefix + "/etc/tls/cert.pem"); }
        r.push("/etc/ssl/certs/ca-certificates.crt");
        r.push("/etc/ssl/cert.pem");
        r.push("/etc/pki/tls/certs/ca-bundle.crt");
        r.push("/system/etc/security/cacerts");
        return r;
    }
    // is the certificate `last` (parsed in ol) trusted: is it in the store, or signed by a certificate of the store?
    static bool trusted_by_store(char^ last, int lastlen, int^ ol, int now) {
        String[] places = Crypto::ca_files();
        for pi in 0..places.len {
            String listing = Crypto::list_dir(places[pi]);
            String[] texts = arr(0);
            if listing.len > 0 {
                String[] names = listing.split("\n");
                for ni in 0..names.len {
                    if names[ni].len > 0 { texts.push(Crypto::read_text(places[pi] + "/" + names[ni])); }
                }
            } else {
                texts.push(Crypto::read_text(places[pi]));
            }
            for ti in 0..texts.len {
                if texts[ti].len < 100 { continue; }
                int cap = texts[ti].len + 4096;
                int bv = (int)Mem::alloc(cap);
                char^ buf = (char^)bv;
                int w = Crypto::pem_to_der_list(texts[ti], buf, cap);
                int pos = 0;
                int found = 0;
                while pos + 4 <= w && found == 0 {
                    int n = ((buf[pos] & 255) << 24) | ((buf[pos + 1] & 255) << 16) | ((buf[pos + 2] & 255) << 8) | (buf[pos + 3] & 255);
                    char^ cand = buf + pos + 4;
                    int oc[28];
                    if Crypto::x509_parse(cand, n, (int^)@oc) {
                        // the same certificate, or the same subject with the same key (a root that the server sent signed by an older root), or signed by it
                        bool same_key = oc[9] == ol[9] && oc[21] == ol[21] && Crypto::bytes_equal(cand + oc[8], last + ol[8], oc[9]) && Crypto::bytes_equal(cand + oc[20], last + ol[20], oc[21]);
                        if same_key && Crypto::x509_valid_at(cand, (int^)@oc, now) { found = 1; }
                        else if Crypto::x509_signed_by(last, ol, cand, (int^)@oc, now) { found = 1; }
                    }
                    pos += 4 + n;
                }
                Mem::free((void^)buf);
                if found == 1 { return true; }
            }
        }
        return false;
    }
    // the check of a chain: `chain` is the certificates one after the other, each as 4 bytes of size (big-endian) and the DER bytes, the server's certificate first.
    // Gives "" when the chain is good, else the reason. The host must be named in the first certificate; now: seconds since 1970 (0: the clock of this computer).
    static String x509_check_chain(char^ chain, int chainlen, String host, int now) {
        if now == 0 { now = Crypto::unix_now(); }
        int cofs[10];
        int clen[10];
        int count = 0;
        int pos = 0;
        while pos + 4 <= chainlen && count < 10 {
            int n = ((chain[pos] & 255) << 24) | ((chain[pos + 1] & 255) << 16) | ((chain[pos + 2] & 255) << 8) | (chain[pos + 3] & 255);
            if n <= 0 || pos + 4 + n > chainlen { return "the certificates are damaged"; }
            cofs[count] = pos + 4;
            clen[count] = n;
            count += 1;
            pos += 4 + n;
        }
        if count == 0 { return "the server sent no certificate"; }
        int ox[300];
        for i in 0..count {
            if !Crypto::x509_parse(chain + cofs[i], clen[i], (int^)@ox + i * 224) { return "a certificate cannot be read"; }
        }
        if !Crypto::x509_valid_at(chain + cofs[0], (int^)@ox, now) { return "the certificate of " + host + " is not valid at this time (expired, or the clock of this computer is wrong)"; }
        if !Crypto::x509_names_host(chain + cofs[0], (int^)@ox, host) { return "the certificate is not made for the name " + host; }
        // from the server's certificate upwards: each one signed by the next, until one is trusted (it is in the trusted list, or signed by a certificate of it)
        for j in 0..count {
            if j > 0 && !Crypto::x509_signed_by(chain + cofs[j - 1], (int^)@ox + (j - 1) * 224, chain + cofs[j], (int^)@ox + j * 224, now) {
                return "a certificate of the chain is not signed by the next one";
            }
            if Crypto::trusted_by_store(chain + cofs[j], clen[j], (int^)@ox + j * 224, now) { return ""; }
        }
        return "the certificate of " + host + " is not trusted: no certificate of the trusted list (J2K_CA, or the system's) signs the chain";
    }
    // bytes as lower case hex
    static String hex(char^ p, int n) {
        String digits = "0123456789abcdef";
        String r = "";
        for i in 0..n {
            r.push(digits[(p[i] >> 4) & 15]);
            r.push(digits[p[i] & 15]);
        }
        return r;
    }
}
