// Toml: the simple part of TOML for settings: [sections], key = "text" | number | true | false, # comments.
// A key is written section.key (a key before any section is written alone).
//   String cfg = Fs::read_text("app.toml").unwrap();
//   Option<String> name = Toml::get(cfg, "server.name");      Option<int> port = Toml::get_int(cfg, "server.port");
struct Toml {
    // the value of the key as it is written (a quoted text without its quotes), or None
    static Option<String> get(String text, String key) {
        String section = "";
        int pos = 0;
        while pos <= text.len {
            int end = pos;
            while end < text.len && text[end] != 10 { end += 1; }
            String line = text.slice(pos, end);
            pos = end + 1;
            String t = line.trim();
            if t.len == 0 || t[0] == '#' { continue; }
            if t[0] == '[' {
                int close = t.find("]");
                if close > 1 { section = t.slice(1, close).trim(); }
                continue;
            }
            int eq = t.find("=");
            if eq < 1 { continue; }
            String k = t.slice(0, eq).trim();
            String full = k;
            if section.len > 0 { full = section + "." + k; }
            if full != key { continue; }
            String v = t.slice(eq + 1, t.len).trim();
            if v.len >= 2 && v[0] == '"' {
                String r = "";
                int i = 1;
                while i < v.len && v[i] != '"' {
                    if v[i] == '\\' && i + 1 < v.len {
                        i += 1;
                        if v[i] == 'n' { r.push(10); }
                        else if v[i] == 't' { r.push(9); }
                        else { r.push(v[i]); }
                    } else {
                        r.push(v[i]);
                    }
                    i += 1;
                }
                return Option<String>::Some(r);
            }
            // a value without quotes ends at a comment
            int hash = v.find("#");
            if hash >= 0 { v = v.slice(0, hash).trim(); }
            return Option<String>::Some(v);
        }
        return Option<String>::None;
    }
    static Option<int> get_int(String text, String key) {
        Option<String> v = Toml::get(text, key);
        if v.is_none() { return Option<int>::None; }
        String s = v.unwrap();
        if s.len == 0 { return Option<int>::None; }
        int i = 0;
        int sign = 1;
        if s[0] == '-' {
            sign = -1;
            i = 1;
        }
        if i >= s.len { return Option<int>::None; }
        int n = 0;
        while i < s.len {
            if s[i] == '_' {
                i += 1;
                continue;
            }
            if s[i] < '0' || s[i] > '9' { return Option<int>::None; }
            n = n * 10 + (s[i] - '0');
            i += 1;
        }
        return Option<int>::Some(n * sign);
    }
    static Option<bool> get_bool(String text, String key) {
        Option<String> v = Toml::get(text, key);
        if v.is_none() { return Option<bool>::None; }
        String s = v.unwrap();
        if s == "true" { return Option<bool>::Some(true); }
        if s == "false" { return Option<bool>::Some(false); }
        return Option<bool>::None;
    }
    static Option<double> get_double(String text, String key) {
        Option<String> v = Toml::get(text, key);
        if v.is_none() { return Option<double>::None; }
        String s = v.unwrap();
        if s.len == 0 { return Option<double>::None; }
        int i = 0;
        double sign = 1.0;
        if s[0] == '-' {
            sign = -1.0;
            i = 1;
        }
        double n = 0.0;
        bool digits = false;
        while i < s.len && s[i] >= '0' && s[i] <= '9' {
            n = n * 10.0 + (double)(s[i] - '0');
            digits = true;
            i += 1;
        }
        if i < s.len && s[i] == '.' {
            i += 1;
            double f = 0.1;
            while i < s.len && s[i] >= '0' && s[i] <= '9' {
                n = n + f * (double)(s[i] - '0');
                f = f / 10.0;
                digits = true;
                i += 1;
            }
        }
        if !digits || i != s.len { return Option<double>::None; }
        return Option<double>::Some(n * sign);
    }
}
