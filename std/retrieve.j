// retrieve 0.1.0 -- search in your own texts (BM25): the documents, the READMEs, the examples.   #import <retrieve>
//   Retrieve r = Retrieve::make();
//   r.add("LANGUAGE.md", text_of_the_file);           // cut into passages at blank lines and at lines that start with #
//   r.build();                                        // once, after the last add
//   Hits h = r.search("how do I open a file", 3);     // the best 3 passages
//   for i in 0..h.n { cout << h.names[i] << "  " << h.scores[i] << "\n" << h.texts[i] << "\n"; }
// Words are lower-case letters and digits (and _); Thai and other text without spaces is cut into pairs of characters, so a Thai question finds a Thai passage.
// A word that is in every passage counts for nothing; a word that is in few passages counts a lot (BM25 with k1 = 1.5, b = 0.75).

struct Hits {
    String[] names;
    String[] texts;
    double[] scores;
    int n;
}

struct Retrieve {
    String[] pname;                 // the document of a passage
    String[] ptext;
    int[] pstart;                   // the passage p has the terms tok[pstart[p] .. pstart[p + 1] - 1]
    int[] tok;
    Map<String, int> ids;           // a term -> its number
    int[] df;                       // in how many passages a term is
    int nterms;
    double avglen;
    bool built;

    static Retrieve make() {
        Retrieve r;
        r.pname = arr(64);
        r.ptext = arr(64);
        r.pstart = arr(64);
        r.tok = arr(4096);
        r.df = arr(1024);
        r.nterms = 0;
        r.avglen = 1.0;
        r.built = false;
        return r;
    }

    int term_id(self, String t, bool create) {
        if self.ids.has(t) { return self.ids.get(t); }
        if !create { return -1; }
        int id = self.nterms;
        self.nterms += 1;
        self.ids.put(t + "", id);
        self.df.push(0);
        return id;
    }

    // the terms of a text, pushed into out (as term numbers; unknown terms are made when create is true, else skipped)
    void terms_of(self, String text, int[] out, bool create) {
        String word = "";
        String[] run = arr(8);                      // the characters of a run of Thai (or other) text
        int i = 0;
        int n = text.len;
        while i <= n {
            int c = 0;
            if i < n { c = text[i]; }
            if c < 0 { c = c + 256; }
            bool alnum = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_';
            if c >= 'A' && c <= 'Z' { alnum = true; c = c + 32; }
            if alnum {
                self.flush_run(run, out, create);
                word.push((char)c);
                i += 1;
            } else if c >= 128 {
                if word.len > 0 { self.push_term(word, out, create); word.clear(); }
                int len = 1;
                if c >= 240 { len = 4; } else if c >= 224 { len = 3; } else if c >= 192 { len = 2; }
                if i + len > n { len = n - i; }
                run.push(text.slice(i, i + len));
                i += len;
            } else {
                if word.len > 0 { self.push_term(word, out, create); word.clear(); }
                self.flush_run(run, out, create);
                i += 1;
            }
        }
    }

    void push_term(self, String w, int[] out, bool create) {
        int id = self.term_id(w, create);
        if id >= 0 { out.push(id); }
    }

    // pairs of the characters of a run (one character alone when the run has one)
    void flush_run(self, String[] run, int[] out, bool create) {
        if run.len == 1 {
            self.push_term(run[0], out, create);
        } else {
            for k in 0..run.len - 1 { self.push_term(run[k] + run[k + 1], out, create); }
        }
        run.clear();
    }

    void add_passage(self, String doc, String text) {
        if text.len < 3 { return; }
        self.pstart.push(self.tok.len);
        self.pname.push(doc + "");
        self.ptext.push(text + "");
        self.terms_of(text, self.tok, true);
    }

    // a document is cut into passages at blank lines and before every line that starts with #
    void add(self, String doc, String text) {
        String cur = "";
        String[] lines = text.split("\n");
        for li in 0..lines.len {
            String line = lines[li];
            bool blank = line.trim().len == 0;
            bool head = line.len > 0 && line[0] == '#';
            if (blank || head) && cur.len > 0 {
                self.add_passage(doc, cur);
                cur.clear();
            }
            if !blank {
                if cur.len > 0 { cur.push('\n'); }
                cur.append(line);
            }
        }
        if cur.len > 0 { self.add_passage(doc, cur); }
    }

    void build(self) {
        self.pstart.push(self.tok.len);
        int np = self.pname.len;
        self.df = arr(self.nterms + 1);
        for t in 0..self.nterms + 1 { self.df.push(0); }
        for p in 0..np {
            int a = self.pstart[p];
            int b = self.pstart[p + 1];
            // count a term once for each passage
            for i in a..b {
                int t = self.tok[i];
                bool seen = false;
                for j in a..i { if self.tok[j] == t { seen = true; break; } }
                if !seen { self.df[t] += 1; }
            }
        }
        self.avglen = 1.0;
        if np > 0 { self.avglen = (double)self.tok.len / (double)np; }
        self.built = true;
    }

    Hits search(self, String query, int k) {
        Hits h;
        h.names = arr(k + 1);
        h.texts = arr(k + 1);
        h.scores = arr(k + 1);
        h.n = 0;
        if !self.built { return h; }
        int[] q = arr(16);
        self.terms_of(query, q, false);
        int np = self.pname.len;
        double[] score = arr(np + 1);
        for p in 0..np { score.push(0.0); }
        for qi in 0..q.len {
            int t = q[qi];
            double idf = Math::log(((double)np - (double)self.df[t] + 0.5) / ((double)self.df[t] + 0.5) + 1.0);
            for p in 0..np {
                int a = self.pstart[p];
                int b = self.pstart[p + 1];
                int tf = 0;
                for i in a..b { if self.tok[i] == t { tf += 1; } }
                if tf > 0 {
                    double len = (double)(b - a);
                    double ftf = (double)tf;
                    score[p] += idf * ftf * 2.5 / (ftf + 1.5 * (0.25 + 0.75 * len / self.avglen));
                }
            }
        }
        for r in 0..k {
            int best = -1;
            double bs = 0.0;
            for p in 0..np { if score[p] > bs { bs = score[p]; best = p; } }
            if best < 0 { break; }
            h.names.push(self.pname[best] + "");
            h.texts.push(self.ptext[best] + "");
            h.scores.push(bs);
            h.n += 1;
            score[best] = 0.0;
        }
        return h;
    }
}
