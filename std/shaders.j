// shaders 0.1.0 -- shader source from files: #include, #define from the program, and a check for a changed file (hot reload).   #import <shaders>   (needs jcmp 1.2.1.0; license: MPL-2.0)
//   ShaderFile fs = ShaderFile::make("shaders/water.frag");     // reads the file; every line   #include "common.glsl"   is replaced by that file (looked up beside it)
//   fs.define("TILE", "16");  fs.define("USE_FOG", "1");        // becomes   #define TILE 16   after the #version line (if the text has one) or at the top
//   int prog = gl.program(vs.text(), fs.text());                // <opengl3>; the text is plain GLSL
//   if fs.changed() { fs.reload(); prog = gl.program(vs.text(), fs.text()); }     // call it once a second while developing: true when a file (or an include) changed
//   fs.ok (false when a file could not be read), fs.error (the reason), fs.text().
// An include loop (a file that includes itself) stops at depth 8 with an error. The library needs no graphics chip: it only makes text.

String shader_dir(String path) {
    int cut = -1;
    for i in 0..path.len { if path[i] == '/' { cut = i; } }
    if cut < 0 { return ""; }
    return path.slice(0, cut + 1);
}

// the text of a file with the includes written in; err collects the first problem; names collects every file that was read
String shader_expand(String path, int depth, String[] names, String[] err) {
    if depth > 8 {
        if err.len == 0 { err.push("too many nested #include (a loop?) at " + path); }
        return "";
    }
    Result<String, Error> r = Fs::read_text(path);
    if r.is_err() {
        if err.len == 0 { err.push("cannot read " + path); }
        return "";
    }
    String src = r.take();
    names.push(path + "");
    String dir = shader_dir(path);
    String out = "";
    String[] lines = src.split("\n");
    for i in 0..lines.len {
        String line = lines[i];
        String t = line.trim();
        if t.starts_with("#include") {
            int a = -1;
            int b = -1;
            for k in 0..t.len {
                if t[k] == '"' { if a < 0 { a = k; } else { b = k; } }
            }
            if a < 0 || b < 0 {
                if err.len == 0 { err.push("bad #include in " + path + " line " + str(i + 1)); }
            } else {
                out = out + shader_expand(dir + t.slice(a + 1, b), depth + 1, names, err);
                out = out + "\n";
            }
        } else {
            out = out + line + "\n";
        }
    }
    return out;
}

struct ShaderFile {
    String path;
    String src;                   // after the includes
    String[] names;               // the files that were read
    String[] contents;            // what they held (to see a change)
    String[] def_names;
    String[] def_values;
    bool ok;
    String error;

    static ShaderFile make(String path) {
        ShaderFile s;
        s.path = path + "";
        s.names = arr(4);
        s.contents = arr(4);
        s.def_names = arr(4);
        s.def_values = arr(4);
        s.reload();
        return s;
    }

    void reload(self) {
        String[] names = arr(4);
        String[] err = arr(1);
        self.src = shader_expand(self.path, 0, names, err) + "";
        self.names = names;
        self.contents = arr(4);
        for i in 0..self.names.len {
            Result<String, Error> r = Fs::read_text(self.names[i]);
            if r.is_ok() { self.contents.push(r.take() + ""); } else { self.contents.push(""); }
        }
        self.ok = err.len == 0;
        if self.ok { self.error = ""; } else { self.error = err[0] + ""; }
    }

    // true when a file of this shader holds other text than at the last reload
    bool changed(self) {
        for i in 0..self.names.len {
            Result<String, Error> r = Fs::read_text(self.names[i]);
            if r.is_err() { return true; }
            if r.take() != self.contents[i] { return true; }
        }
        return false;
    }

    void define(self, String name, String value) {
        for i in 0..self.def_names.len {
            if self.def_names[i] == name { self.def_values[i] = value + ""; return; }
        }
        self.def_names.push(name + "");
        self.def_values.push(value + "");
    }

    // the GLSL text with the #define lines after the #version line
    String text(self) {
        String defs = "";
        for i in 0..self.def_names.len { defs = defs + "#define " + self.def_names[i] + " " + self.def_values[i] + "\n"; }
        if defs.len == 0 { return self.src + ""; }
        String[] lines = self.src.split("\n");
        String out = "";
        bool done = false;
        for i in 0..lines.len {
            if i == lines.len - 1 && lines[i].len == 0 { break; }
            out = out + lines[i] + "\n";
            String lt = lines[i].trim();
            bool is_version = lt.starts_with("#version");
            if !done && is_version {
                out = out + defs;
                done = true;
            }
        }
        if !done { out = defs + out; }
        return out;
    }
}
