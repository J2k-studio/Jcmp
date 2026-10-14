// Regex: a small pattern matcher (a backtracking one), for the common cases.
//   Regex::matches("[a-z]+@[a-z]+\\.com", "ann@mail.com") -> true     (the whole text)
//   Regex::find("[0-9]+", "room 42, floor 7") -> 5                    (where the first match starts, or -1)
//   Regex::find_text("[0-9]+", "room 42, floor 7") -> "42"
// Pattern: a character, . (any), \d \w \s (and \D \W \S), [abc] [a-z] [^0-9], x* x+ x? on one thing, ^ $, \. (a character
// that has a meaning), and | between the whole alternatives.
struct Regex {
    // does the character c belong to the class at p[i] (a \d, \w, \s, a [..] set, a . or a literal)? the length of the item in rl
    static int item_len(String p, int i) {
        char c = p[i];
        if c == '\\' { return 2; }
        if c == '[' {
            int j = i + 1;
            if j < p.len && p[j] == '^' { j += 1; }
            if j < p.len && p[j] == ']' { j += 1; }
            while j < p.len && p[j] != ']' { j += 1; }
            return j + 1 - i;
        }
        return 1;
    }
    static bool class_has(char e, char c) {
        if e == 'd' { return c >= '0' && c <= '9'; }
        if e == 'w' { return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'; }
        if e == 's' { return c == ' ' || c == 9 || c == 10 || c == 13; }
        return false;
    }
    // does the single item p[i .. i + n) match the character c?
    static bool item_matches(String p, int i, int n, char c) {
        char e = p[i];
        if e == '.' { return c != 10; }
        if e == '\\' {
            char k = p[i + 1];
            if k == 'd' || k == 'w' || k == 's' { return Regex::class_has(k, c); }
            if k == 'D' { return !Regex::class_has('d', c); }
            if k == 'W' { return !Regex::class_has('w', c); }
            if k == 'S' { return !Regex::class_has('s', c); }
            if k == 'n' { return c == 10; }
            if k == 't' { return c == 9; }
            return c == k;
        }
        if e == '[' {
            int j = i + 1;
            bool neg = false;
            if p[j] == '^' {
                neg = true;
                j += 1;
            }
            bool hit = false;
            int end = i + n - 1;
            while j < end {
                char a = p[j];
                if a == '\\' && j + 1 < end {
                    char k = p[j + 1];
                    if k == 'd' || k == 'w' || k == 's' {
                        if Regex::class_has(k, c) { hit = true; }
                    } else if k == c {
                        hit = true;
                    }
                    j += 2;
                } else if j + 2 < end && p[j + 1] == '-' {
                    if c >= a && c <= p[j + 2] { hit = true; }
                    j += 3;
                } else {
                    if c == a { hit = true; }
                    j += 1;
                }
            }
            return hit != neg;
        }
        return c == e;
    }
    // the end of a match of p[pi .. pe) at t[ti ..], or -1 (backtracking)
    static int m(String p, int pi, int pe, String t, int ti) {
        if pi >= pe { return ti; }
        if p[pi] == '$' && pi + 1 == pe {
            if ti == t.len { return ti; }
            return -1;
        }
        int n = Regex::item_len(p, pi);
        int after = pi + n;
        char q = 0;
        if after < pe { q = p[after]; }
        if q == '*' || q == '+' || q == '?' {
            int rest = after + 1;
            int count = 0;
            int pos = ti;
            int maxn = 1000000;
            if q == '?' { maxn = 1; }
            // as many as possible first, then fewer
            while count < maxn && pos < t.len && Regex::item_matches(p, pi, n, t[pos]) {
                pos += 1;
                count += 1;
            }
            int least = 0;
            if q == '+' { least = 1; }
            while count >= least {
                int r = Regex::m(p, rest, pe, t, ti + count);
                if r >= 0 { return r; }
                count -= 1;
            }
            return -1;
        }
        if ti < t.len && Regex::item_matches(p, pi, n, t[ti]) {
            return Regex::m(p, after, pe, t, ti + 1);
        }
        return -1;
    }
    // the end of the match of the alternative that starts at `from`, trying each `|` branch; the pattern is p[a .. e)
    static int match_here(String p, String t, int ti) {
        int start = 0;
        int i = 0;
        // top level `|` (not inside [ ])
        while i <= p.len {
            bool at_end = i == p.len;
            if !at_end && p[i] == '[' {
                i += Regex::item_len(p, i);
                continue;
            }
            if !at_end && p[i] == '\\' {
                i += 2;
                continue;
            }
            if at_end || p[i] == '|' {
                int ps = start;
                int r = -1;
                if ps < i && p[ps] == '^' {
                    if ti == 0 { r = Regex::m(p, ps + 1, i, t, ti); }
                } else {
                    r = Regex::m(p, ps, i, t, ti);
                }
                if r >= 0 { return r; }
                start = i + 1;
            }
            i += 1;
        }
        return -1;
    }
    // the position where the first match starts (-1: none)
    static int find(String p, String t) {
        for s in 0..t.len + 1 {
            int r = Regex::match_here(p, t, s);
            if r >= 0 { return s; }
        }
        return -1;
    }
    // the text of the first match ("" when there is none: use find to tell the difference)
    static String find_text(String p, String t) {
        for s in 0..t.len + 1 {
            int r = Regex::match_here(p, t, s);
            if r >= 0 { return t.slice(s, r); }
        }
        return "";
    }
    // does the pattern match the whole text?
    static bool matches(String p, String t) {
        // each alternative must end at the end of the text: add the end anchor to every branch by trying the ends
        int start = 0;
        int i = 0;
        while i <= p.len {
            bool at_end = i == p.len;
            if !at_end && p[i] == '[' {
                i += Regex::item_len(p, i);
                continue;
            }
            if !at_end && p[i] == '\\' {
                i += 2;
                continue;
            }
            if at_end || p[i] == '|' {
                int ps = start;
                int pe = i;
                if ps < pe && p[ps] == '^' { ps += 1; }
                int r = Regex::m(p, ps, pe, t, 0);
                if r == t.len { return true; }
                // a shorter match was found first: the whole text may still match another way
                if r >= 0 && r != t.len {
                    // try every end: the matcher returns the first; check by anchoring with $
                    String anchored = p.slice(ps, pe) + "$";
                    if Regex::m(anchored, 0, anchored.len, t, 0) == t.len { return true; }
                }
                start = i + 1;
            }
            i += 1;
        }
        return false;
    }
}
