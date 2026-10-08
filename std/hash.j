// SHA-256 (FIPS 180-4): a 256-bit fingerprint of data, as 64 hex digits.
//   String h = Sha256::hex("abc");            // ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
//   String f = Sha256::file("jcmp")?;         // the same for a file (any bytes)
struct Sha256 {
    static void init(int^ st) {
        st[0] = 0x6a09e667;
        st[1] = 0xbb67ae85;
        st[2] = 0x3c6ef372;
        st[3] = 0xa54ff53a;
        st[4] = 0x510e527f;
        st[5] = 0x9b05688c;
        st[6] = 0x1f83d9ab;
        st[7] = 0x5be0cd19;
    }
    static void constants(int^ st) {
        st[8] = 0x428a2f98;
        st[9] = 0x71374491;
        st[10] = 0xb5c0fbcf;
        st[11] = 0xe9b5dba5;
        st[12] = 0x3956c25b;
        st[13] = 0x59f111f1;
        st[14] = 0x923f82a4;
        st[15] = 0xab1c5ed5;
        st[16] = 0xd807aa98;
        st[17] = 0x12835b01;
        st[18] = 0x243185be;
        st[19] = 0x550c7dc3;
        st[20] = 0x72be5d74;
        st[21] = 0x80deb1fe;
        st[22] = 0x9bdc06a7;
        st[23] = 0xc19bf174;
        st[24] = 0xe49b69c1;
        st[25] = 0xefbe4786;
        st[26] = 0x0fc19dc6;
        st[27] = 0x240ca1cc;
        st[28] = 0x2de92c6f;
        st[29] = 0x4a7484aa;
        st[30] = 0x5cb0a9dc;
        st[31] = 0x76f988da;
        st[32] = 0x983e5152;
        st[33] = 0xa831c66d;
        st[34] = 0xb00327c8;
        st[35] = 0xbf597fc7;
        st[36] = 0xc6e00bf3;
        st[37] = 0xd5a79147;
        st[38] = 0x06ca6351;
        st[39] = 0x14292967;
        st[40] = 0x27b70a85;
        st[41] = 0x2e1b2138;
        st[42] = 0x4d2c6dfc;
        st[43] = 0x53380d13;
        st[44] = 0x650a7354;
        st[45] = 0x766a0abb;
        st[46] = 0x81c2c92e;
        st[47] = 0x92722c85;
        st[48] = 0xa2bfe8a1;
        st[49] = 0xa81a664b;
        st[50] = 0xc24b8b70;
        st[51] = 0xc76c51a3;
        st[52] = 0xd192e819;
        st[53] = 0xd6990624;
        st[54] = 0xf40e3585;
        st[55] = 0x106aa070;
        st[56] = 0x19a4c116;
        st[57] = 0x1e376c08;
        st[58] = 0x2748774c;
        st[59] = 0x34b0bcb5;
        st[60] = 0x391c0cb3;
        st[61] = 0x4ed8aa4a;
        st[62] = 0x5b9cca4f;
        st[63] = 0x682e6ff3;
        st[64] = 0x748f82ee;
        st[65] = 0x78a5636f;
        st[66] = 0x84c87814;
        st[67] = 0x8cc70208;
        st[68] = 0x90befffa;
        st[69] = 0xa4506ceb;
        st[70] = 0xbef9a3f7;
        st[71] = 0xc67178f2;
    }
    static int rotr(int x, int n) {
        return ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;
    }
    // one block of 64 bytes at p
    static void block(int^ st, char^ p) {
        for i in 0..16 {
            st[72 + i] = ((p[i * 4] & 255) << 24) | ((p[i * 4 + 1] & 255) << 16) | ((p[i * 4 + 2] & 255) << 8) | (p[i * 4 + 3] & 255);
        }
        for i in 16..64 {
            int s0 = Sha256::rotr(st[72 + i - 15], 7) xor Sha256::rotr(st[72 + i - 15], 18) xor (st[72 + i - 15] >> 3);
            int s1 = Sha256::rotr(st[72 + i - 2], 17) xor Sha256::rotr(st[72 + i - 2], 19) xor (st[72 + i - 2] >> 10);
            st[72 + i] = (st[72 + i - 16] + s0 + st[72 + i - 7] + s1) & 0xFFFFFFFF;
        }
        int a = st[0];
        int b = st[1];
        int c = st[2];
        int d = st[3];
        int e = st[4];
        int f = st[5];
        int g = st[6];
        int hh = st[7];
        for i in 0..64 {
            int s1 = Sha256::rotr(e, 6) xor Sha256::rotr(e, 11) xor Sha256::rotr(e, 25);
            int ch = (e & f) xor ((e xor 0xFFFFFFFF) & g);
            int t1 = (hh + s1 + ch + st[8 + i] + st[72 + i]) & 0xFFFFFFFF;
            int s0 = Sha256::rotr(a, 2) xor Sha256::rotr(a, 13) xor Sha256::rotr(a, 22);
            int maj = (a & b) xor (a & c) xor (b & c);
            int t2 = (s0 + maj) & 0xFFFFFFFF;
            hh = g;
            g = f;
            f = e;
            e = (d + t1) & 0xFFFFFFFF;
            d = c;
            c = b;
            b = a;
            a = (t1 + t2) & 0xFFFFFFFF;
        }
        st[0] = (st[0] + a) & 0xFFFFFFFF;
        st[1] = (st[1] + b) & 0xFFFFFFFF;
        st[2] = (st[2] + c) & 0xFFFFFFFF;
        st[3] = (st[3] + d) & 0xFFFFFFFF;
        st[4] = (st[4] + e) & 0xFFFFFFFF;
        st[5] = (st[5] + f) & 0xFFFFFFFF;
        st[6] = (st[6] + g) & 0xFFFFFFFF;
        st[7] = (st[7] + hh) & 0xFFFFFFFF;
    }
    // the last bytes (tn < 64) of a message of total bytes, padded; then the digest as hex
    static String finish(int^ st, char^ tail, int tn, int total) {
        char buf[128];
        for i in 0..128 { buf[i] = 0; }
        for i in 0..tn { buf[i] = tail[i]; }
        buf[tn] = (char)128;
        int n = 64;
        if tn >= 56 { n = 128; }
        int bits = total * 8;
        for i in 0..8 { buf[n - 1 - i] = (char)((bits >> (i * 8)) & 255); }
        Sha256::block(st, (char^)@buf);
        if n == 128 { Sha256::block(st, (char^)@buf + 64); }
        String digits = "0123456789abcdef";
        String r = "";
        for i in 0..8 {
            for j in 0..8 {
                int nib = (st[i] >> (28 - j * 4)) & 15;
                r.push(digits[nib]);
            }
        }
        return r;
    }
    // the digest of the bytes of a String
    static String hex(String s) {
        int st[136];                 // h (8), k (64), w (64)
        Sha256::init((int^)@st);
        Sha256::constants((int^)@st);
        char^ p = s.c();
        int n = s.len;
        int pos = 0;
        while n - pos >= 64 {
            Sha256::block((int^)@st, p + pos);
            pos += 64;
        }
        return Sha256::finish((int^)@st, p + pos, n - pos, n);
    }
    // the digest of the bytes of a file
    static Result<String, Error> file(String path) {
        int fd = syscall(56, -100, path.c(), 0, 0);
        if fd < 0 { return Result<String, Error>::Err(Fs::error(fd, "cannot open ", path)); }
        int st[136];                 // h (8), k (64), w (64)
        Sha256::init((int^)@st);
        Sha256::constants((int^)@st);
        char buf[4096];
        int total = 0;
        int have = 0;
        bool more = true;
        while more {
            // fill the buffer (a read may give less than asked)
            have = 0;
            while have < 4096 {
                int n = syscall(63, fd, (char^)@buf + have, 4096 - have);
                if n < 0 {
                    syscall(57, fd);
                    return Result<String, Error>::Err(Fs::error(n, "cannot read ", path));
                }
                if n == 0 {
                    more = false;
                    break;
                }
                have += n;
            }
            total += have;
            int pos = 0;
            while have - pos >= 64 {
                Sha256::block((int^)@st, (char^)@buf + pos);
                pos += 64;
            }
            if !more {
                syscall(57, fd);
                return Result<String, Error>::Ok(Sha256::finish((int^)@st, (char^)@buf + pos, have - pos, total));
            }
        }
        return Result<String, Error>::Ok("");
    }
}
