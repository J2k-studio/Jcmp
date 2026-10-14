// Csv: one line of comma separated values, with "quoted, fields" and "" for a quote inside a field.
//   String[] f = Csv::split_line("a,\"b,c\",d");      // a  b,c  d
//   String line = Csv::join_line(f);                  // a,"b,c",d
struct Csv {
    static String[] split_line(String line) {
        String[] out = arr(4);
        String cur = "";
        bool quoted = false;
        int i = 0;
        while i < line.len {
            char c = line[i];
            if quoted {
                if c == '"' {
                    if i + 1 < line.len && line[i + 1] == '"' {
                        cur.push('"');
                        i += 1;
                    } else {
                        quoted = false;
                    }
                } else {
                    cur.push(c);
                }
            } else if c == '"' {
                quoted = true;
            } else if c == ',' {
                out.push(cur);
                cur = "";
            } else if c != 13 {
                cur.push(c);
            }
            i += 1;
        }
        out.push(cur);
        return out;
    }
    static String quote_field(String f) {
        bool need = false;
        for i in 0..f.len {
            char c = f[i];
            if c == ',' || c == '"' || c == 10 || c == 13 { need = true; }
        }
        if !need { return f; }
        String r = "\"";
        for i in 0..f.len {
            if f[i] == '"' { r.push('"'); }
            r.push(f[i]);
        }
        r.push('"');
        return r;
    }
    static String join_line(String[] fields) {
        String r = "";
        for i in 0..fields.len {
            if i > 0 { r.push(','); }
            r += Csv::quote_field(fields[i]);
        }
        return r;
    }
}
