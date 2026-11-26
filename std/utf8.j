// utf8 0.1.0 -- text as characters, not bytes: count, read, cut, change case, and how many columns a text takes on a screen.   #import <utf8>   (license: MPL-2.0)
//   int n = Utf8::len("สวัสดี");              // 6 characters (the .len of a str is 18 bytes)
//   int c = Utf8::at(s, 1);                   // the code point of the second character (U+0E27 is 3623)
//   str t = Utf8::slice(s, 1, 4);             // the characters 1, 2 and 3 (not the bytes)
//   str u = Utf8::upper("straße ñ é");        // letters of ASCII, Latin-1, Greek and Cyrillic (other letters stay as they are)
//   int w = Utf8::text_width(s);              // the columns on a terminal: a Thai mark that sits over a letter takes 0, a Chinese character 2
// A text that is not valid UTF-8 is read byte by byte (every bad byte is one character, U+FFFD); nothing stops or fails.
// The functions work on a str and give new texts; positions are byte positions where the name says `pos`, character numbers everywhere else.

struct Utf8 {
    // the number of bytes of a character that starts with this byte (1 to 4), 0 when the byte cannot start one
    static int size(int lead) {
        lead = lead & 255;
        if lead < 128 { return 1; }
        if lead >= 194 && lead <= 223 { return 2; }
        if lead >= 224 && lead <= 239 { return 3; }
        if lead >= 240 && lead <= 244 { return 4; }
        return 0;
    }

    // how many bytes the character at byte position pos takes (1 when the bytes there are not valid UTF-8)
    static int width_at(str s, int pos) {
        int n = Utf8::size(s[pos]);
        if n <= 1 || pos + n > s.len { return 1; }
        for int k = 1; k < n; k++ {
            if (s[pos + k] & 192) != 128 { return 1; }
        }
        return n;
    }

    // the code point that starts at byte position pos (65533 for a bad byte)
    static int decode(str s, int pos) {
        int n = Utf8::width_at(s, pos);
        int b0 = s[pos] & 255;
        if n == 1 {
            if b0 < 128 { return b0; }
            return 65533;
        }
        int cp = 0;
        if n == 2 { cp = b0 & 31; }
        else if n == 3 { cp = b0 & 15; }
        else { cp = b0 & 7; }
        for int k = 1; k < n; k++ { cp = (cp << 6) | (s[pos + k] & 63); }
        return cp;
    }

    // the byte position of the character after the one at pos
    static int next(str s, int pos) { return pos + Utf8::width_at(s, pos); }

    // a text of one character
    static str encode(int cp) {
        str r = "";
        if cp < 0 || cp > 1114111 || (cp >= 55296 && cp <= 57343) { cp = 65533; }
        if cp < 128 { r.push(cp); }
        else if cp < 2048 { r.push(192 | (cp >> 6)); r.push(128 | (cp & 63)); }
        else if cp < 65536 { r.push(224 | (cp >> 12)); r.push(128 | ((cp >> 6) & 63)); r.push(128 | (cp & 63)); }
        else { r.push(240 | (cp >> 18)); r.push(128 | ((cp >> 12) & 63)); r.push(128 | ((cp >> 6) & 63)); r.push(128 | (cp & 63)); }
        return r;
    }

    // the number of characters
    static int len(str s) {
        int n = 0;
        int p = 0;
        while p < s.len { p = Utf8::next(s, p); n += 1; }
        return n;
    }

    // true when every byte belongs to a well formed character (overlong forms and the surrogates are not checked)
    static bool valid(str s) {
        int p = 0;
        while p < s.len {
            int b = s[p] & 255;
            if b >= 128 && Utf8::width_at(s, p) == 1 { return false; }
            p = Utf8::next(s, p);
        }
        return true;
    }

    // the byte position of character number index (s.len when the text has fewer characters)
    static int pos_of(str s, int index) {
        int p = 0;
        int i = 0;
        while i < index && p < s.len { p = Utf8::next(s, p); i += 1; }
        return p;
    }

    // the code point of character number index (-1 when there is none)
    static int at(str s, int index) {
        if index < 0 { return -1; }
        int p = Utf8::pos_of(s, index);
        if p >= s.len { return -1; }
        return Utf8::decode(s, p);
    }

    // the characters from number from up to (not including) number to
    static str slice(str s, int from, int to) {
        str r = "";
        if from < 0 { from = 0; }
        int p = Utf8::pos_of(s, from);
        int i = from;
        while i < to && p < s.len {
            int q = Utf8::next(s, p);
            while p < q { r.push(s[p]); p += 1; }
            i += 1;
        }
        return r;
    }

    // the text with its characters in the opposite order (a mark that sits on a Thai letter is a character of its own: it moves too)
    static str reverse(str s) {
        str r = "";
        int n = Utf8::len(s);
        int i = n - 1;
        while i >= 0 {
            int p = Utf8::pos_of(s, i);
            int q = Utf8::next(s, p);
            while p < q { r.push(s[p]); p += 1; }
            i -= 1;
        }
        return r;
    }

    static bool is_thai(int cp) { return cp >= 3584 && cp <= 3711; }

    // a mark that is drawn on the letter before it, or a character that takes no place (0 columns)
    static bool is_mark(int cp) {
        if cp == 3633 || (cp >= 3636 && cp <= 3642) || (cp >= 3655 && cp <= 3662) { return true; }       // Thai: sara a, i..uu, mai taikhu..yamakkan
        if cp >= 768 && cp <= 879 { return true; }                                                         // the combining marks of Latin
        if cp >= 8203 && cp <= 8207 { return true; }                                                       // zero width space, joiners, direction marks
        if cp >= 65024 && cp <= 65039 { return true; }                                                     // variation selectors
        return false;
    }

    // a character that takes two columns (Chinese, Japanese, Korean, the wide forms, the emoji)
    static bool is_wide(int cp) {
        if cp < 4352 { return false; }
        return (cp <= 4447) || (cp >= 11904 && cp <= 42191) || (cp >= 44032 && cp <= 55203) || (cp >= 63744 && cp <= 64255)
            || (cp >= 65040 && cp <= 65049) || (cp >= 65072 && cp <= 65135) || (cp >= 65280 && cp <= 65376) || (cp >= 65504 && cp <= 65510)
            || (cp >= 126976 && cp <= 127231) || (cp >= 127744 && cp <= 128591) || (cp >= 129280 && cp <= 129535) || (cp >= 131072 && cp <= 262141);
    }

    // the columns one character takes on a terminal: 0, 1 or 2
    static int width(int cp) {
        if cp == 0 { return 0; }
        if cp < 32 || (cp >= 127 && cp < 160) { return 0; }
        if Utf8::is_mark(cp) { return 0; }
        if Utf8::is_wide(cp) { return 2; }
        return 1;
    }

    // the columns of a whole text
    static int text_width(str s) {
        int w = 0;
        int p = 0;
        while p < s.len { w += Utf8::width(Utf8::decode(s, p)); p = Utf8::next(s, p); }
        return w;
    }

    static int lower_cp(int c) {
        if c >= 65 && c <= 90 { return c + 32; }
        if c >= 192 && c <= 222 && c != 215 { return c + 32; }
        if c >= 913 && c <= 937 { return c + 32; }
        if c >= 1040 && c <= 1071 { return c + 32; }
        if c >= 1024 && c <= 1039 { return c + 80; }
        return c;
    }

    static int upper_cp(int c) {
        if c >= 97 && c <= 122 { return c - 32; }
        if c >= 224 && c <= 254 && c != 247 { return c - 32; }
        if c >= 945 && c <= 969 && c != 962 { return c - 32; }
        if c >= 1072 && c <= 1103 { return c - 32; }
        if c >= 1104 && c <= 1119 { return c - 80; }
        return c;
    }

    static str lower(str s) {
        str r = "";
        int p = 0;
        while p < s.len {
            int q = Utf8::next(s, p);
            int c = Utf8::decode(s, p);
            if c < 128 || Utf8::lower_cp(c) == c || c == 65533 {
                while p < q { r.push(s[p]); p += 1; }
            } else {
                r.append(Utf8::encode(Utf8::lower_cp(c)));
            }
            p = q;
        }
        return r;
    }

    static str upper(str s) {
        str r = "";
        int p = 0;
        while p < s.len {
            int q = Utf8::next(s, p);
            int c = Utf8::decode(s, p);
            if c < 128 {
                r.push(Utf8::upper_cp(c));
            } else if Utf8::upper_cp(c) == c || c == 65533 {
                while p < q { r.push(s[p]); p += 1; }
            } else {
                r.append(Utf8::encode(Utf8::upper_cp(c)));
            }
            p = q;
        }
        return r;
    }
}
