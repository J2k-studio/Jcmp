
// JSON: Json::parse(text) gives a document, a table of nodes; a node is a number (-1 means "none").
//   JsonDoc doc = Json::parse(text)?;
//   int name = doc.get(doc.root(), "name");          String s = doc.text(name);
//   int first = doc.at(doc.get(doc.root(), "list"), 0);    double d = doc.number(first);
//   String out = doc.dump(doc.root());               // back to (compact) JSON text
// json_quote(s) makes a JSON string literal; json_num_text(x) is a number as text.
// helpers (also reachable as Json::quote and Json::num_text)
String json_int_text(i64 v) {
    String r = "";
    if v < 0 {
        r.push('-');
        v = 0 - v;
    }
    char buf[24];
    i64 n = 0;
    if v == 0 {
        buf[0] = '0';
        n = 1;
    }
    while v > 0 {
        buf[n] = (char)('0' + v % 10);
        n += 1;
        v = v / 10;
    }
    while n > 0 {
        n -= 1;
        r.push(buf[n]);
    }
    return r;
}
// a number as the shortest text that reads back the same (up to 15 digits); nan and inf are null
String json_num_text(double x) {
    if x != x || x > 1.0e22 || x < -1.0e22 { return "null"; }
    String r = "";
    if x < 0.0 {
        r.push('-');
        x = 0.0 - x;
    }
    if x < 9.0e15 {
        i64 ip = (i64)x;
        r.append(json_int_text(ip));
        double fp = x - (double)ip;
        if fp > 0.0 {
            String f = "";
            i64 k = 0;
            while k < 15 && fp > 0.0 {
                fp = fp * 10.0;
                i64 d = (i64)fp;
                f.push((char)('0' + d));
                fp = fp - (double)d;
                k += 1;
            }
            // drop zeros at the end
            i64 cut = f.len;
            while cut > 0 && f[cut - 1] == '0' { cut -= 1; }
            if cut > 0 {
                r.push('.');
                r.append(f.slice(0, cut));
            }
        }
        return r;
    }
    // very large numbers: whole digits only
    r.append(json_int_text((i64)(x / 1.0e10)));
    r.append("0000000000");
    return r;
}
// a JSON string literal for s (with the quotes)
String json_quote(String s) {
    String r = "\"";
    String hex = "0123456789abcdef";
    for i in 0..s.len {
        char c = s[i];
        if c == '"' {
            r.append("\\\"");
        } else if c == 92 {
            r.append("\\\\");
        } else if c == 10 {
            r.append("\\n");
        } else if c == 13 {
            r.append("\\r");
        } else if c == 9 {
            r.append("\\t");
        } else if c < 32 {
            r.append("\\u00");
            r.push(hex[c / 16]);
            r.push(hex[c % 16]);
        } else {
            r.push(c);
        }
    }
    r.push('"');
    return r;
}

struct JsonDoc {
    String src;
    i64 pos;
    String err;
    i64[] kind;                  // 0 null, 1 false, 2 true, 3 number, 4 string, 5 array, 6 object
    double[] num;
    String[] txt;                // the value of a string node
    String[] key;                // the name of a node that is a member of an object
    i64[] first;                 // the first child (array, object)
    i64[] last;
    i64[] next;                  // the next brother
    void free(self) {
        self.src.free();
        self.err.free();
        self.kind.free();
        self.num.free();
        self.txt.free();
        self.key.free();
        self.first.free();
        self.last.free();
        self.next.free();
    }
    // ---- reading (JsonDoc is made by Json::parse)
    i64 fail(self, String m) {
        if self.err.len == 0 {
            String t = m;
            t.append(" at byte ");
            t.append(json_int_text(self.pos));
            self.err = t;
        }
        return -1;
    }
    void skip_ws(self) {
        while self.pos < self.src.len {
            char c = self.src[self.pos];
            if c == 32 || c == 10 || c == 13 || c == 9 {
                self.pos += 1;
            } else {
                return;
            }
        }
    }
    // a new node; its text and name are stored with it
    i64 add(self, i64 k, String t, String name) {
        self.kind.push(k);
        self.num.push(0.0);
        self.txt.push(t);
        self.key.push(name);
        self.first.push(-1);
        self.last.push(-1);
        self.next.push(-1);
        return self.kind.len - 1;
    }
    // puts node c at the end of the children of node p
    void link(self, i64 p, i64 c) {
        if self.first[p] < 0 {
            self.first[p] = c;
        } else {
            self.next[self.last[p]] = c;
        }
        self.last[p] = c;
    }
    bool word(self, String w) {
        if self.pos + w.len > self.src.len { return false; }
        for i in 0..w.len {
            if self.src[self.pos + i] != w[i] { return false; }
        }
        self.pos += w.len;
        return true;
    }
    i64 value(self, String name) {
        self.skip_ws();
        if self.pos >= self.src.len { return self.fail("unexpected end of the text"); }
        char c = self.src[self.pos];
        if c == '{' { return self.object(name); }
        if c == '[' { return self.array(name); }
        if c == '"' {
            String s = self.string_lit();
            if self.err.len > 0 { return -1; }
            return self.add(4, s, name);
        }
        if self.word("true") { return self.add(2, "", name); }
        if self.word("false") { return self.add(1, "", name); }
        if self.word("null") { return self.add(0, "", name); }
        if c == '-' || (c >= '0' && c <= '9') { return self.number_lit(name); }
        return self.fail("unexpected character");
    }
    i64 number_lit(self, String name) {
        i64 a = self.pos;
        if self.src[self.pos] == '-' { self.pos += 1; }
        while self.pos < self.src.len {
            char c = self.src[self.pos];
            if (c >= '0' && c <= '9') || c == '.' || c == 'e' || c == 'E' || c == '+' || c == '-' {
                self.pos += 1;
            } else {
                break;
            }
        }
        double v = 0.0;
        try { v = self.src.slice(a, self.pos).to_double(); } catch (e) {
            return self.fail("bad number");
        }
        i64 n = self.add(3, "", name);
        self.num[n] = v;
        return n;
    }
    i64 hex4(self) {
        if self.pos + 4 > self.src.len { return -1; }
        i64 v = 0;
        for i in 0..4 {
            char c = self.src[self.pos + i];
            i64 d = -1;
            if c >= '0' && c <= '9' { d = c - '0'; }
            if c >= 'a' && c <= 'f' { d = c - 'a' + 10; }
            if c >= 'A' && c <= 'F' { d = c - 'A' + 10; }
            if d < 0 { return -1; }
            v = v * 16 + d;
        }
        self.pos += 4;
        return v;
    }
    // the string at pos (which is the opening quote); the text is decoded; err is set on a mistake
    String string_lit(self) {
        String r = "";
        self.pos += 1;
        while true {
            if self.pos >= self.src.len {
                self.fail("the string is not closed");
                return r;
            }
            char c = self.src[self.pos];
            self.pos += 1;
            if c == '"' { return r; }
            if c < 32 {
                self.fail("a control character in a string");
                return r;
            }
            if c != 92 {
                r.push(c);
            } else {
                if self.pos >= self.src.len {
                    self.fail("the string is not closed");
                    return r;
                }
                char e = self.src[self.pos];
                self.pos += 1;
                if e == 'n' { r.push((char)10); }
                else if e == 't' { r.push((char)9); }
                else if e == 'r' { r.push((char)13); }
                else if e == 'b' { r.push((char)8); }
                else if e == 'f' { r.push((char)12); }
                else if e == '"' || e == 92 || e == '/' { r.push(e); }
                else if e == 'u' {
                    i64 cp = self.hex4();
                    if cp < 0 {
                        self.fail("bad \\u escape");
                        return r;
                    }
                    if cp >= 0xD800 && cp <= 0xDBFF && self.pos + 1 < self.src.len && self.src[self.pos] == 92 && self.src[self.pos + 1] == 'u' {
                        i64 save = self.pos;
                        self.pos += 2;
                        i64 lo = self.hex4();
                        if lo >= 0xDC00 && lo <= 0xDFFF {
                            cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                        } else {
                            self.pos = save;
                        }
                    }
                    if cp < 0x80 {
                        r.push((char)cp);
                    } else if cp < 0x800 {
                        r.push((char)(0xC0 | (cp >> 6)));
                        r.push((char)(0x80 | (cp & 63)));
                    } else if cp < 0x10000 {
                        r.push((char)(0xE0 | (cp >> 12)));
                        r.push((char)(0x80 | ((cp >> 6) & 63)));
                        r.push((char)(0x80 | (cp & 63)));
                    } else {
                        r.push((char)(0xF0 | (cp >> 18)));
                        r.push((char)(0x80 | ((cp >> 12) & 63)));
                        r.push((char)(0x80 | ((cp >> 6) & 63)));
                        r.push((char)(0x80 | (cp & 63)));
                    }
                } else {
                    self.fail("unknown escape");
                    return r;
                }
            }
        }
        return r;
    }
    i64 array(self, String name) {
        i64 me = self.add(5, "", name);
        self.pos += 1;
        self.skip_ws();
        if self.pos < self.src.len && self.src[self.pos] == ']' {
            self.pos += 1;
            return me;
        }
        while true {
            i64 c = self.value("");
            if c < 0 { return -1; }
            self.link(me, c);
            self.skip_ws();
            if self.pos >= self.src.len { return self.fail("the array is not closed"); }
            char d = self.src[self.pos];
            self.pos += 1;
            if d == ']' { return me; }
            if d != ',' { return self.fail("a , or ] was expected"); }
        }
        return me;
    }
    i64 object(self, String name) {
        i64 me = self.add(6, "", name);
        self.pos += 1;
        self.skip_ws();
        if self.pos < self.src.len && self.src[self.pos] == '}' {
            self.pos += 1;
            return me;
        }
        while true {
            self.skip_ws();
            if self.pos >= self.src.len || self.src[self.pos] != '"' { return self.fail("a name in quotes was expected"); }
            String k = self.string_lit();
            if self.err.len > 0 { return -1; }
            self.skip_ws();
            if self.pos >= self.src.len || self.src[self.pos] != ':' { return self.fail("a : was expected"); }
            self.pos += 1;
            i64 c = self.value(k);
            if c < 0 { return -1; }
            self.link(me, c);
            self.skip_ws();
            if self.pos >= self.src.len { return self.fail("the object is not closed"); }
            char d = self.src[self.pos];
            self.pos += 1;
            if d == '}' { return me; }
            if d != ',' { return self.fail("a , or } was expected"); }
        }
        return me;
    }

    // ---- looking at a document (n is a node; -1 or a wrong kind gives an empty answer)
    i64 root(self) { return 0; }
    // 0 null, 1 false, 2 true, 3 number, 4 string, 5 array, 6 object; -1 for no node
    i64 kind_of(self, i64 n) {
        if n < 0 || n >= self.kind.len { return -1; }
        return self.kind[n];
    }
    i64 len(self, i64 n) {
        i64 k = self.kind_of(n);
        if k != 5 && k != 6 { return 0; }
        i64 c = self.first[n];
        i64 count = 0;
        while c >= 0 {
            count += 1;
            c = self.next[c];
        }
        return count;
    }
    // the i-th element of an array or member of an object (counted from 0), or -1
    i64 at(self, i64 n, i64 i) {
        i64 k = self.kind_of(n);
        if k != 5 && k != 6 { return -1; }
        i64 c = self.first[n];
        while c >= 0 && i > 0 {
            c = self.next[c];
            i -= 1;
        }
        return c;
    }
    // the member of an object with this name, or -1
    i64 get(self, i64 n, String name) {
        if self.kind_of(n) != 6 { return -1; }
        i64 c = self.first[n];
        while c >= 0 {
            if self.key[c] == name { return c; }
            c = self.next[c];
        }
        return -1;
    }
    bool has(self, i64 n, String name) { return self.get(n, name) >= 0; }
    // the name of a node that is a member of an object
    String name_of(self, i64 n) {
        if n < 0 || n >= self.kind.len { return ""; }
        String r = "";
        r.append(self.key[n]);
        return r;
    }
    String text(self, i64 n) {
        if self.kind_of(n) != 4 { return ""; }
        String r = "";
        r.append(self.txt[n]);
        return r;
    }
    double number(self, i64 n) {
        if self.kind_of(n) != 3 { return 0.0; }
        return self.num[n];
    }
    i64 integer(self, i64 n) { return (i64)self.number(n); }
    bool boolean(self, i64 n) { return self.kind_of(n) == 2; }
    bool is_null(self, i64 n) { return self.kind_of(n) == 0; }

    // ---- writing: the node and what is below it as compact JSON text
    String dump(self, i64 n) {
        String r = "";
        i64 k = self.kind_of(n);
        if k <= 0 {
            r.append("null");
        } else if k == 1 {
            r.append("false");
        } else if k == 2 {
            r.append("true");
        } else if k == 3 {
            r.append(json_num_text(self.num[n]));
        } else if k == 4 {
            r.append(json_quote(self.txt[n]));
        } else if k == 5 {
            r.push('[');
            i64 c = self.first[n];
            while c >= 0 {
                if c != self.first[n] { r.push(','); }
                r.append(self.dump(c));
                c = self.next[c];
            }
            r.push(']');
        } else {
            r.push('{');
            i64 c = self.first[n];
            while c >= 0 {
                if c != self.first[n] { r.push(','); }
                r.append(json_quote(self.key[c]));
                r.push(':');
                r.append(self.dump(c));
                c = self.next[c];
            }
            r.push('}');
        }
        return r;
    }
}

// the entry points: Json::parse(text), Json::quote(s), Json::num_text(x)
struct Json {
    static String quote(String s) { return json_quote(s); }
    static String num_text(double x) { return json_num_text(x); }
    static Result<JsonDoc, Error> parse(String text) {
        JsonDoc j;
        j.src = text;
        j.pos = 0;
        j.err = "";
        j.kind = arr(16);
        j.num = arr(16);
        j.txt = arr(16);
        j.key = arr(16);
        j.first = arr(16);
        j.last = arr(16);
        j.next = arr(16);
        i64 root = j.value("");
        if root >= 0 {
            j.skip_ws();
            if j.pos < j.src.len { root = j.fail("extra text after the value"); }
        }
        if root < 0 {
            return Result<JsonDoc, Error>::Err(Error::make(ErrorKind::Parse, j.err));
        }
        return Result<JsonDoc, Error>::Ok(j);
    }
}

// json: Json::json.parse(text), with  using Json;  json.parse(text). A text that is not JSON is thrown as an error; try_parse returns the Result.
