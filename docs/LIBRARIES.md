# The libraries, by category

How to use each part of the standard library, with a program that compiles and runs. For every function see [API.md](API.md); for the language see [LANGUAGE.md](LANGUAGE.md); for lessons see [TUTORIAL.md](TUTORIAL.md). Every program below was compiled and run to produce the output shown.

| Category | What it is for |
|---|---|
| [The core](#core) | The core: `Result`, `Option`, `Arena`, `Sys` |
| [Numbers](#number) | Numbers: `Math` and `Num` |
| [Text](#text) | Text: `String`, `Fmt`, `Regex`, `Hex`, `Base64` |
| [Files and folders](#files) | Files and folders: `Fs`, `Dir`, `Path` |
| [The system](#system) | The system: `Env`, `Proc`, `Term`, `Log`, `read` |
| [Time](#time) | Time: `Time`, `Random`, `Date` |
| [Data](#data) | Data: collections, `Json`, `Csv`, `Toml` |
| [Hashes](#crypto) | Hashes: `Sha256`, `Hash` |
| [Threads and atomics](#cpu) | Threads and atomics: `#import <cpu>` |
| [Vectors and matrices](#mathlib) | Vectors and matrices: `#import <math>` |

<a id="core"></a>
## The core: `Result`, `Option`, `Arena`, `Sys`

The core is what every other library stands on. **`Result<T, Error>`** is the answer of a call that can fail for outside reasons (a file that is not there, a number that is not a number): you either have the value or an `Error` with a `kind` and a `message`. You take it apart with `switch`, pass it on with `?`, or ask for the value with `unwrap()` (which stops the program on an error). **`Option<T>`** is a value that may be missing. **`Arena`** gives out memory from one block and takes it all back at once, the right tool for many small things that live and die together. **`Sys`** has a named function for each call to the operating system.

```jk
#import <stdlib>

fnv main() {
    // Result: a call that can fail gives a value or an error; you choose what to do
    Result<String, Error> r = Fs::read_text("/no/such/file");
    switch r {
        Result::Ok(text): jout << "read " << text.len << " bytes\n";
        Result::Err(e): jout << "failed: " << e.message << "\n";
    }
    // Arena: many small things, freed all at once
    Arena a;
    a.init(4096);
    int^ x = (int^)a.take(8);
    x[0] = 42;
    jout << x[0] << " from the arena\n";
    a.free();
}
```

Output:

```
failed: cannot open /no/such/file: there is no file or folder with this name (error 2)
42 from the arena
```

**Tip.** Use `Result` for anything that touches the outside world, and `switch` when you want to say what happens on failure.

<a id="number"></a>
## Numbers: `Math` and `Num`

`Math` is the mathematics of `double`: `sqrt`, `pow`, `floor`, `ceil`, `abs`, `min`, `max`, `clamp`, `sin`, `cos`, `exp`, `log` and more, each a single call (many are one CPU instruction). `Num` turns text into numbers: `parse_int` and `parse_double` give a `Result`, because a text may not be a number.

```jk
#import <stdlib>

fnv main() {
    jout << Math::sqrt(2.0) << " " << Math::pow(2.0, 10.0) << " " << Math::floor(-2.5) << "\n";
    jout << Math::min(3.0, 1.5) << " " << Math::abs(-4.25) << " " << Math::clamp(15.0, 0.0, 10.0) << "\n";
    Result<i64, Error> n = Num::parse_int("1234");
    jout << n.unwrap() + 1 << "\n";
    Result<double, Error> d = Num::parse_double("2.5");
    jout << d.unwrap() * 2.0 << "\n";
    jout << Num::parse_int("12x").is_err() << "\n";
}
```

Output:

```
1.414214 1024.000000 -3.000000
1.500000 4.250000 10.000000
1235
5.000000
true
```

**Tip.** Never trust a number that comes from outside (a file, the keyboard, the network): parse it with `Num` and look at the `Result`.

<a id="text"></a>
## Text: `String`, `Fmt`, `Regex`, `Hex`, `Base64`

A `String` owns its bytes and frees them itself. It has the methods you expect: `trim`, `upper`, `lower`, `find`, `split`, `join`, `replace`, `slice`, `starts_with`, and `len` counts bytes while `count()` counts characters. `Fmt` writes numbers the way people read them (`fixed`, `pad_left`, `thousands`, `hex`, `percent`, `bytes`). `Regex` is a small regular-expression matcher (`matches`, `find`, `find_text`). `Hex` and `Base64` turn bytes into text and back.

```jk
#import <stdlib>

fnv main() {
    String s = "  The quick brown fox  ";
    String t = s.trim();
    jout << t.upper() << " | " << t.len << " | " << t.find("quick") << "\n";
    String[] words = t.split(" ");
    jout << words.len << " words, the last is " << words[words.len - 1] << "\n";
    jout << words.join("-") << "\n";
    jout << Fmt::pad_left("7", 3, '0') << " " << Fmt::fixed(3.14159, 2) << " " << Fmt::thousands(1234567) << "\n";
    jout << Regex::matches("[a-z]+@[a-z]+\\.com", "ann@mail.com") << " " << Regex::find_text("[0-9]+", "room 42") << "\n";
    jout << Hex::encode("Hi") << " " << Base64::encode("Man") << "\n";
}
```

Output:

```
THE QUICK BROWN FOX | 19 | 4
4 words, the last is fox
The-quick-brown-fox
007 3.14 1,234,567
true 42
4869 TWFu
```

**Layout inside `jout`.** There is no format string: ordinary functions of `Fmt` have short names for the stream, `fmt(x, 2)` (digits after the point), `tohex(n)`, `tobin(n)`, `pad(s, w)` (left aligned) and `padl(s, w)` (right aligned, for numbers), for example `jout << pad("tea", 8) << padl(fmt(1.5, 2), 7) << " " << tohex(255) << "\n";` prints `tea         1.50 ff`. The long names: `Fmt::fixed`, `Fmt::pad_left(s, w, '0')`, `Fmt::thousands`, `Fmt::percent`, `Fmt::bytes`, `Fmt::base(n, b)`. Tutorial lesson 83 has a table. If your program already has a function with one of these names (for example its own `pad`), yours is the one that runs (1.2.13); the library keeps working for the other names.

**Regex** (a backtracking matcher for the common cases): a character, `.`, `\d \w \s` (and `\D \W \S`), `[abc] [a-z] [^0-9]`, `^ $`, `x* x+ x? x{n} x{n,} x{n,m}` (a `?` after them makes them lazy), groups `( ... )` and `(?: ... )` with `|` inside and a quantifier after, and `|` between alternatives. `Regex::matches` (the whole text), `find` (where), `find_text`, `find_all` (every match), `count`, `replace(p, text, with)` and `split(p, text)`. There are no captures yet. A pattern that could repeat for ever is stopped.

**Tip.** `Regex` is a backtracking matcher meant for common cases; for a plain word, `String.find` is much faster.

<a id="files"></a>
## Files and folders: `Fs`, `Dir`, `Path`

`Fs` reads and writes whole files (`read_text`, `read_lines`, `write_text`, `append_text`, `size`, `exists`, `remove`, `rename`), `Dir` makes, lists and removes folders, and `Path` builds and splits names (`join`, `name`, `parent`, `ext`, `stem`). Everything that can fail gives a `Result`.

```jk
#import <stdlib>

fnv main() {
    Dir::make_all("tl_dir/sub");
    Fs::write_text(Path::join("tl_dir/sub", "a.txt"), "one\ntwo\n").unwrap();
    Fs::append_text("tl_dir/sub/a.txt", "three\n").unwrap();
    String[] lines = Fs::read_lines("tl_dir/sub/a.txt").unwrap();
    jout << lines.len << " lines, size " << Fs::size("tl_dir/sub/a.txt").unwrap() << "\n";
    String[] names = Dir::list("tl_dir/sub").unwrap();
    jout << names[0] << " " << Path::ext("tl_dir/sub/a.txt") << " " << Path::stem("a.txt") << "\n";
    Fs::remove("tl_dir/sub/a.txt");
    Dir::remove("tl_dir/sub");
    Dir::remove("tl_dir");
    jout << Fs::exists("tl_dir") << "\n";
}
```

Output:

```
3 lines, size 14
a.txt txt a
false
```

**Tip.** `Path::join` puts the separator in the right place; do not join paths with `+`.

<a id="system"></a>
## The system: `Env`, `Proc`, `Term`, `Log`, `read`

`Env::args()` is the list of arguments of the program and `Env::get(name)` an environment variable (an `Option`). `Proc::run` starts another program and gives its exit code, `Proc::output` gives what it wrote. `Term` knows the size of the terminal. `Log` writes messages to the standard error with a level. The keyboard has its own module, `read` (lesson 8 of the tutorial).

```jk
#import <stdlib>

fnv main() {
    String[] a = Env::args();
    jout << "arguments: " << a.len << "\n";
    jout << Env::get("J2K_NO_SUCH_VARIABLE").is_none() << "\n";
    String[] args = arr(0);
    args.push("from a child process");
    jout << Proc::output("echo", args).unwrap();
    String[] none = arr(0);
    int code = Proc::run("true", none).unwrap();
    jout << "exit code " << code << "\n";
    jout << (Term::cols() > 0) << "\n";
    Log::set_level(2);
    Log::error("this goes to the standard error");
}
```

Output:

```
arguments: 1
true
from a child process
exit code 0
true
```

**Tip.** Messages for the person go to `jout`; messages about the program (errors, progress) go to `jerr` or `Log`, so that `program > file` keeps the results clean.

<a id="time"></a>
## Time: `Time`, `Random`, `Date`

`Time::now_ms()` is the wall clock, `Time::mono_ns()` a clock that only goes forward (use it to measure), `Time::sleep_ms` waits. `Random` gives numbers from a seed, so a run can be repeated. `Date` is a day and a time on the calendar (UTC), from and to seconds since 1970.

```jk
#import <stdlib>

fnv main() {
    int t0 = Time::mono_ns();
    Time::sleep_ms(10);
    jout << (Time::mono_ns() - t0 >= 10000000) << "\n";
    Random::seed(7);
    int r = Random::range(1, 7);
    jout << (r >= 1 && r < 7) << " " << (Random::unit() < 1.0) << "\n";
    Date d;
    d.set_unix(1700000000);
    jout << d.text() << " " << d.weekday() << "\n";
    d.add_days(30);
    jout << d.text() << "\n";
}
```

Output:

```
true
true true
2023-11-14 22:13:20 2
2023-12-14 22:13:20
```

**Tip.** For a stopwatch always use `mono_ns`: the wall clock can be set back.

<a id="data"></a>
## Data: collections, `Json`, `Csv`, `Toml`

Lists are dynamic arrays (`T[]`, `String[]`), and `Map<K, V>` and `Set<T>` are hash tables. All of them free what they hold. `Json::parse` reads JSON into a document that you walk with node numbers; `Csv` splits and joins lines of comma separated values; `Toml` reads a configuration file.

```jk
#import <stdlib>

fnv main() {
    String[] names = arr(2);
    names.push("ann"); names.push("bob");
    Map<String, int> ages;
    ages.put("ann", 31);
    Set<int> seen;
    seen.add(3); seen.add(3);
    jout << names.len << " " << ages.get("ann") << " " << seen.len << "\n";
    JsonDoc doc = Json::parse("{\"name\": \"J2K\", \"tags\": [\"a\", \"b\"]}").unwrap();
    jout << doc.text(doc.get(doc.root(), "name")) << " " << doc.len(doc.get(doc.root(), "tags")) << "\n";
    String[] f = Csv::split_line("x,\"y,z\",w");
    jout << f.len << " " << f[1] << "\n";
}
```

Output:

```
2 31 1
```

**Tip.** A wrong name in a JSON document gives node `-1` and an empty answer, not a crash: check with `has` when it matters.

<a id="crypto"></a>
## Hashes: `Sha256`, `Hash`

`Sha256::hex(text)` is the SHA-256 hash of a text and `Sha256::file(path)` of a file. `Hash` has the other hashes the library offers. For secrets (passwords, keys) use the `crypto` category (`#import <crypto>`), not a plain hash.

```jk
#import <stdlib>

fnv main() {
    jout << Sha256::hex("abc") << "\n";
    jout << Base64::encode("hello") << " " << Hex::encode("hello") << "\n";
}
```

Output:

```
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
aGVsbG8= 68656c6c6f
```

**Tip.** A hash is not an encryption: it cannot be turned back, and it is not a safe way to store a password by itself.

<a id="cpu"></a>
## Threads and atomics: `#import <cpu>`

`Thread` runs a function at the same time as the others (`create`, `join`, `detach`). `Atomic::` operations (`add`, `cas`, `load`, `store`) change a shared number in one step that nobody can break; `Mem::barrier()` orders memory accesses. The CPU level has its own lessons in the tutorial (34 for threads and atomics, 42 to 46 for locks, queues and context switches).

```jk
#import <stdlib>
#import <cpu>
using cpu::thread;

int total;

fnv work(void^ arg) {
    for i in 0..1000 { Atomic::add(@total, 1); }
}

fnv main() {
    Thread a = create(work, null);
    Thread b = create(work, null);
    a.join();
    b.join();
    jout << total << "\n";
}
```

Output:

```
2000
```

**Tip.** Share as little as you can: give each thread its own data and join them; use an atomic for a counter and a lock-free queue for a stream.

<a id="mathlib"></a>
## Vectors and matrices: `#import <math>`

`using math::vector;` gives `vec2`, `vec3`, `vec4` with the operators `+ - *`, and the parts can be picked with letters (`c.zyx`). `math::matrix` (`mat3`, `mat4`), `math::quat` (rotations), `math::complex` and `math::stats` come with the same import.

```jk
#import <stdlib>
#import <math>
using math::vector;

fnv main() {
    vec3 a = {1.0, 2.0, 3.0};
    vec3 b = {4.0, 5.0, 6.0};
    vec3 c = a + b * 2.0;
    jout << c.x << " " << c.y << " " << c.z << " " << c.zyx.x << "\n";
}
```

Output:

```
9.000000 12.000000 15.000000 15.000000
```

**Tip.** These are plain structs with operator methods: the compiler turns the loops over them into SIMD instructions.

<a id="net"></a>
## Network: `Net`, `Tcp`, `http`, `https`

`#import <net>`. `Net::http.get(url)` fetches a page over HTTP or HTTPS (TLS 1.3, with the certificate checked) and gives the body as a `String`; `Net::http.try_get(url)` gives a `Result` instead of stopping. `Tcp::connect(ip, port)` opens a connection and `Net::dns` finds addresses. A program that talks to the network should always handle the `Result`: a network fails far more often than a disk.

```jk-no
#import <net>

void main() {
    Result<String, Error> r = Net::http_try_get("https://example.com/");
    switch r {
        Result::Ok(body): jout << body.len << " bytes\n";
        Result::Err(e): jerr << "failed: " << e.message << "\n";
    }
}
```

**Tip.** Put a time limit on anything that waits for the network, and do not read a whole answer of unknown size into memory without a limit.


## The graphics chip and the libraries of the phone: `<native>`, `<opengl3>`, `<vulkan>`, `<gpu>`, `<gamej>`

These libraries come with `jc lib install NAME`. The first three talk to the real driver and need a program built with `jcmp -dyn` (a dynamic executable; it works in Termux and in the Jaric app, with no other app). Tutorial: lessons 61 to 66.

* **`<native>`** — `Native::open("libname.so")` (handle, 0 if none), `Native::sym(handle, "name")` (address of a function), `Native::call0 .. call8` (whole numbers and pointers), `Native::callf1 .. callf4` and `calli_f1 .. calli_f4` (float arguments), `Native::peek8 peek32 peek64`, `poke32 poke64`, `Native::text(address)`.
* **`<opengl3>`** — OpenGL ES 3.1 (or 2.0) off screen: `Gl::open(w, h, 3, 1)`, `gl.clear_color`, `gl.program(vertex, fragment)`, `gl.use`, `gl.draw_triangles(Floats, n)`, `gl.read_pixels`, `gl.compute(source, Floats, gx, gy, gz)` (compute shaders), `gl.fn("glName")` for any other function; `Floats::make(n)`, `set`, `get`.
* **`<vulkan>`** — `Vk::open()`: an instance and the first chip (`device_name`, `api_text()`, `memory_mb`, `has_compute`); the rest of Vulkan is built with `Native`.
* **`<gpu>`** — the chip through the Jaric app: `Gpu::open(w, h)`, `clear rect tri tri_colors circle line image image_part load`, touches and keys; one batch of commands per picture.
* **`<gamej>`** — Jaric Engine, a small game engine: `Game::open`, the loop `begin()` / `end()`, `clear rect circle line text art`, `held hit touching tapped`, `Game::overlap`, `sound`; `makej init -game` makes a project with five lessons.


## The screens of an app: `<ui>`, `<glapp>`, `<canvas2d>`

An app made with `makej init -apk` is a shared library (`libgame.so`) that an Android activity calls: `<glapp>` gives it the surface, the touches and the keyboard, `<canvas2d>` draws (`rect tri line circle image`, `canvas_text`), `<ui>` makes the usual parts of a screen. All three come with `jc lib install NAME` (`jc lib install ui` brings the others).

* **`<glapp>`** — you define `game_init(w, h)`, `game_resize(w, h)`, `game_frame(ms)`, `game_touch(action, x, y, id)`; `glapp_canvas()`, `glapp_w()`, `glapp_h()`; text input with `glapp_on_key(f)` and `glapp_keyboard(true)`.
* **`<canvas2d>`** — `Canvas2d^ c`: `begin clear rect tri line circle load image end`; `Color::rgb(r, g, b)`, `Color::rgba`; `canvas_text(c, x, y, "TEXT", scale, colour)` (a 3 x 5 font: capitals, digits, signs).
* **`<ui>`** — `Ui u`: `start`, `touch`, `begin(c, w, h)`, `title`, `label`, `button` (true on a click), `toggle(text, @flag)`, `slider(text, @value, lo, hi)`, `cols(n)` / `end_cols`, `spacer`, `end`; the colours and sizes are in `u.th`. See [UI.md](UI.md) for a whole screen and for testing it without a phone.

**Tip.** `apkj build` makes the apk of such an app without `aapt2`, `ecj`, `d8` or `apksigner` (tutorial lesson 85).

## Text as characters: `#import <utf8>` (1.2.40)

A `str` is bytes: `"สวัสดี".len` is 18 although a reader sees 6 letters. `<utf8>` counts, reads, cuts and changes the case of a text by **characters**, and says how many
columns it takes on a terminal (a Thai mark that is drawn on a letter takes 0, a Chinese character 2). A byte that is not valid UTF-8 is one character (U+FFFD); nothing fails.

```jk
#import <stdlib>
#import <utf8>

i32 main() {
    str th = "สวัสดี";
    jout << th.len << " " << Utf8::len(th) << "\n";                       // 18 6
    jout << Utf8::at(th, 1) << "\n";                                      // 3623 (U+0E27, the second character)
    jout << Utf8::slice("aé€😀z", 1, 4) << "\n";                           // é€😀
    jout << Utf8::upper("straße ñ é") << " " << Utf8::lower("ÀÉÑ Δ Ж") << "\n";   // STRAßE Ñ É àéñ δ ж
    jout << Utf8::text_width(th) << " " << Utf8::text_width("日本") << "\n";   // 4 4
    jout << Utf8::encode(0x20AC) << " " << Utf8::valid(th) << "\n";         // € true
    return 0;
}
```
`size`, `width_at`, `decode`, `next` and `pos_of` work on byte positions (to walk a text yourself); `len`, `at`, `slice`, `reverse` work on character numbers.
Case change covers ASCII, Latin-1, Greek and Cyrillic; other letters stay as they are.

## Shapes that touch: `#import <geom>` (1.2.38)

Boxes, circles, segments, rays and polygons: the questions that a game or a picker asks. Everything is plain numbers (doubles); `y` grows downwards; touching edges count as a hit.

```jk
#import <stdlib>
#import <geom>

i32 main() {
    // two boxes (x, y = the top left corner, then the width and the height)
    jout << Geom::rect_hit(0.0, 0.0, 10.0, 10.0, 5.0, 5.0, 10.0, 10.0) << "\n";                // true
    // how far must the first box move to leave the second? the shorter way: p.x or p.y
    Push p = Geom::rect_push(0.0, 0.0, 10.0, 10.0, 8.0, 0.0, 10.0, 10.0);
    jout << p.hit << " " << p.x << " " << p.y << "\n";                                           // true -2.000000 0.000000
    // a ray from (0, 5) to the right, against a box that starts at x = 10: it is hit after 10 lengths of (1, 0)
    jout << Geom::ray_rect(0.0, 5.0, 1.0, 0.0, 10.0, 0.0, 5.0, 10.0) << "\n";                    // 10.000000
    double xs[4] = {0.0, 10.0, 10.0, 0.0};
    double ys[4] = {0.0, 0.0, 10.0, 10.0};
    jout << Geom::point_in_polygon(5.0, 5.0, @xs, @ys, 4) << "\n";                               // true
    return 0;
}
```

| Function | Answer |
|---|---|
| `rect_hit(ax, ay, aw, ah, bx, by, bw, bh)` | do two boxes touch |
| `circle_hit(ax, ay, ar, bx, by, br)`, `circle_rect(cx, cy, r, rx, ry, rw, rh)` | circle against circle, circle against box |
| `point_in_rect`, `point_in_circle`, `point_in_polygon(px, py, xs, ys, n)` | is a point inside (any polygon, even-odd rule) |
| `rect_push(...)` | `Push {hit, x, y}`: the shorter move that takes box a out of box b |
| `dist`, `dist_point_segment` | distances |
| `segments_hit(ax, ay, bx, by, cx, cy, dx, dy)` | do two segments cross |
| `ray_rect`, `ray_circle` | the distance along a ray where it enters the shape (0 when it starts inside, -1 when it misses) |
| `polygon_area(xs, ys, n)` | the area (the sign tells which way the points go round) |

## Random numbers that you own: `#import <rng>` (1.2.38)

`Random::` is one series for the whole program. `Rng` is a series of its own: the same seed gives the same numbers on every phone, which is what tests, replays and games need.

```jk
#import <stdlib>
#import <rng>

i32 main() {
    Rng r = Rng::make(42);                 // the same number: the same series
    jout << r.range(1, 7) << " " << r.range(1, 7) << "\n";      // a die, twice
    double g = r.normal(10.0, 2.0);        // a bell curve: the mean and the spread
    jout << (g > 0.0) << "\n";            // true: about 10, only 1 time in a million below 0
    i64 cards[5] = {1, 2, 3, 4, 5};
    r.shuffle(@cards, 5);                  // a new order
    jout << (r.chance(0.5) || !r.chance(0.5)) << "\n";          // true
    return 0;
}
```
`bits` (64 random bits), `range(lo, hi)`, `pick(n)`, `unit()` (0 up to 1), `between(lo, hi)`, `chance(p)`, `normal(mean, spread)`, `shuffle(array, n)`. The series is SplitMix64: every seed is good, and the numbers can be checked against any other language that has it.

## More shapes for any picture: `#import <draw2d>` (1.2.38)

Ellipses, boxes with round corners, rings, arcs, Bezier curves, polygons, gradients and outlines, made of the triangles, lines and boxes of `Canvas2d`, so they work on every backend (OpenGL, memory, ...).

```jk
#import <stdlib>
#import <canvas2d>
#import <softcanvas>
#import <draw2d>

i32 main() {
    SoftCanvas sc;
    sc.make(60, 60);                                   // a picture in memory
    Canvas2d^ c = @sc;
    draw_ellipse(c, 30.0, 30.0, 20.0, 10.0, 0xffff0000);
    draw_rrect(c, 5.0, 40.0, 50.0, 15.0, 6.0, 0xff00aaff);
    draw_gradient_h(c, 0.0, 0.0, 60.0, 6.0, 0xffff0000, 0xff0000ff);
    jout << (sc.get(30, 30) == 0xffff0000) << "\n";   // true: the middle of the ellipse is red
    return 0;
}
```
`draw_ellipse`, `draw_rrect(c, x, y, w, h, radius, colour)`, `draw_ring`, `draw_arc(c, cx, cy, r, from, to, width, colour)`, `draw_bezier`, `draw_polygon` (convex), `draw_gradient_h` / `_v` / `_radial`, `draw_rect_stroke`, `draw_mix(a, b, t)`. An opaque colour has no seams; a see-through colour may show faint lines where two triangles meet.


## Examples of the other libraries (the doc check compiles and runs them)

**`<deflate>`: compress, gzip and CRC-32.**

```jk
#import <stdlib>
#import <deflate>

i32 main() {
    String data = "aaaaaaaaaabbbbbbbbbbaaaaaaaaaabbbbbbbbbbaaaaaaaaaabbbbbbbbbb";
    String z = Deflate::compress(data);                  // raw DEFLATE bytes (RFC 1951)
    bool ok = false;
    String back = Deflate::decompress(z, @ok);
    jout << (z.len < data.len) << " " << ok << " " << (back == data) << "\n";           // true true true
    String g = Gzip::pack(data);                           // a .gz file (RFC 1952)
    bool ok2 = false;
    String again = Gzip::unpack(g, @ok2);
    jout << ok2 << " " << (again == data) << " " << Crc32::of("123456789") << "\n";      // true true 3421780262
    return 0;
}
```

**`<tilemap>`, `<phys2d>` and `<profile>`: a world of tiles, a body that falls in it, and the time of each part.**

```jk
#import <stdlib>
#import <tilemap>
#import <phys2d>
#import <profile>

i32 main() {
    TileMap m = TileMap::make(100, 50, 2);               // 100 x 50 tiles, 2 layers
    for x in 0..100 { m.set(0, x, 40, 1); }              // a floor: tile number 1 (the numbers 1..99 are solid below)
    Body b = Body::make(50.0, 0.0, 8.0, 16.0);           // x, y, width, height in dots (tiles are 16 dots)
    Profile p = Profile::make();
    for step in 0..120 {
        i64 t = p.start();
        b.step(m, 0, 16, 99, 1.0 / 60.0, 900.0);        // the layer 0, tiles of 16 dots, solid up to 99, one frame, gravity
        p.stop("physics", t);
        p.frame();
    }
    jout << b.on_ground << " " << (b.y > 623.0 && b.y <= 624.0) << "\n";                // true true: it fell and stands on the floor (40 * 16 - 16)
    jout << p.calls("physics") << " " << p.frames << "\n";                              // 120 120
    return 0;
}
```

## The other libraries, from their sources

<!-- libdoc: the chapters below are made from the sources by tools/libdoc.py; write an example by hand under a chapter when you can -->

### `<deflate>`

CRC-32, DEFLATE (inflate + a compressor) and gzip.   #import <deflate>   (needs jcmp 1.1.0.0; license: MPL-2.0)

```text
  String z = Deflate::compress(data);   bool ok; String d = Deflate::decompress(z, ok);      // raw RFC 1951 bytes
  String g = Gzip::pack(data);   String d2 = Gzip::unpack(g, ok);                             // .gz (RFC 1952), CRC checked
  int c = Crc32::of(data);
Bytes live in a String (it may hold any byte); read a byte as  s[i] & 255.  The compressor uses LZ77 with the fixed codes.
```

What it offers:

* `Crc32::of(String data)` returns `i64`
* `Deflate::compress(String data)` returns `String`
* `Deflate::decompress(String z, bool^ ok)` returns `String`
* `Gzip::pack(String data)` returns `String`
* `Gzip::unpack(String g, bool^ ok)` returns `String` — ok = false when the header, the CRC or the length is wrong


### `<fsdir>`

Files and folders: Fs (whole files), Dir (folders). Needs the core (Result, Error) and text (Str).

```text
an Error for the system error number e (a negative number from a system call is fine) and what was being done
```

What it offers:

* `Fs::error(i64 e, String what, String path)` returns `Error`
* `Fs::read_text(String path)` returns `Result<String, Error>` — the whole file as a String
* `Fs::read_bytes(String path)` returns `Result<String, Error>` — the whole file as bytes in a String: any byte, also zero (read_text stops at a zero byte)
* `Fs::write_bytes(String path, String data)` returns `Result<i64, Error>` — write the bytes of a String (any byte) to the file (made or emptied); Ok(the number of bytes)
* `Fs::read_lines(String path)` returns `Result<String[], Error>` — the lines of a file (without the line ends)
* `Fs::write_text(String path, String text)` returns `Result<i64, Error>` — write the text to the file (made or emptied); Ok(the number of bytes)
* `Fs::append_text(String path, String text)` returns `Result<i64, Error>` — add the text at the end of the file (made if needed)
* `Fs::put(String path, String text, i64 flags)` returns `Result<i64, Error>`
* `Fs::exists(String path)` returns `bool`
* `Fs::size(String path)` returns `Result<i64, Error>` — the size of a file in bytes
* `Fs::remove(String path)` returns `Result<i64, Error>`
* `Fs::rename(String from, String to)` returns `Result<i64, Error>`
* `Dir::exists(String path)` returns `bool`
* `Dir::make(String path)` returns `Result<i64, Error>`
* `Dir::make_all(String path)` returns `Result<i64, Error>` — the folder and the ones above it (like mkdir -p)
* `Dir::remove(String path)` returns `Result<i64, Error>` — remove an empty folder
* `Dir::list(String path)` returns `Result<String[], Error>` — the names in a folder (not . and ..), in order
* `Dir::current()` returns `Result<String, Error>`


### `<glcanvas>`

the Canvas2d interface on OpenGL ES 3 (and on ES 2): every shape of a frame goes into one buffer and is drawn with ONE call.   #import <opengl3> <canvas2d> <glcanvas>   (license: MPL-2.0)

```text
  0.2.1: image_rot (a picture turned about its middle; a method of GlCanvas, not of the interface).
  0.2.0: pictures (load a PNG, image()), the same code on an OpenGL ES 2 context (Gl::open(w, h, 2, 0)): no vertex arrays, shaders of GLSL 100.
  Gl gl = Gl::open(320, 180, 3, 1);                      // off-screen; in an app: Gl::attach(w, h)
  GlCanvas c; c.init(); c.setup(gl, 320.0, 180.0);       // sets the shader, the buffer and the size of the surface in dots
  Canvas2d^ cv = @c;   cv^.begin(); cv^.rect(...); cv^.end();       // c.draws counts the draw calls of the last frame (1 for a whole frame)
The batch holds 8192 triangles; when it is full it is drawn and started again (one more call).
```

What it offers:

* `GlCanvas.init()` returns `void`
* `GlCanvas.setup(Gl gl, double w, double h)` returns `void`
* `GlCanvas.attribs()` returns `void` — the two attributes of the shape shader: pos (2 floats) and col (4 floats) in the bound buffer
* `GlCanvas.vertex(double x, double y, i64 argb)` returns `void` — one vertex: x, y, r, g, b, a (the colour as numbers from 0 to 1)
* `GlCanvas.flush()` returns `void` — send the batch to the chip and draw it
* `GlCanvas.begin()` returns `void`
* `GlCanvas.clear(i64 argb)` returns `void`
* `GlCanvas.rect(double x, double y, double w, double h, i64 argb)` returns `void`
* `GlCanvas.tri(double x0, double y0, double x1, double y1, double x2, double y2, i64 argb)` returns `void`
* `GlCanvas.line(double x0, double y0, double x1, double y1, double width, i64 argb)` returns `void` — a line of the given width: a thin rectangle along the line
* `GlCanvas.circle(double cx, double cy, double r, i64 argb)` returns `void` — a fan of 32 triangles
* `GlCanvas.end()` returns `void`
* `GlCanvas.has_instancing()` returns `bool`
* `GlCanvas.has_shaders()` returns `bool`
* `GlCanvas.load(String path)` returns `i64` — a PNG file becomes a picture number (-1 when the file cannot be read)
* `GlCanvas.image(i64 pic, double x, double y, double w, double h, i64 tint)` returns `void` — the picture in the box (x, y, w, h); drawn at once (the shapes before it are drawn first, so the order is kept)
* `GlCanvas.image_rot(i64 pic, double cx, double cy, double w, double h, double angle, i64 tint)` returns `void` — the picture in a box of w x h dots whose middle is (cx, cy), turned by `angle` radians (clockwise on the screen, about the middle)


### `<mlp>`

train a small network in a few lines (on top of <neuron>).   #import <mlp>

```text
  int[] sizes = arr(3);  sizes.push(2); sizes.push(16); sizes.push(1);
  Mlp net = Mlp::make(sizes, Mlp::TANH(), 1);                  // layers 2 -> 16 -> 1; the activation between them; the seed
  net.fit(x, y, 300, 0.01);                                   // x: Tensor32 (rows of inputs), y: Tensor32 (rows of outputs); 300 epochs, learning rate
  Tensor32 p = net.predict(x);                                // the outputs
  double e = net.loss_on(x, y);                               // the mean squared error
For classes (the last layer gives one number for each class, the labels are 0 .. classes - 1):
  Mlp c = Mlp::make(sizes, Mlp::RELU(), 1);   c.fit_classes(x, labels, 100, 0.01);   double a = c.accuracy(x, labels);   int k = c.classify_row(x, 0);
  net.save("net.mlp");   Mlp m = Mlp::load("net.mlp");
Settings (change a field before fit): net.batch (rows in a step, 32), net.decay (weight decay of AdamW, 0.0), net.clip (largest gradient norm, 5.0),
net.every (print the loss every this many epochs, 0 = silent, the default), net.cosine (1: the learning rate falls along a cosine to a tenth).
fit returns the last loss; net.history has the loss of every epoch. The rows are shuffled in every epoch.
```

What it offers:

* `Mlp::RELU()` returns `i64`
* `Mlp::TANH()` returns `i64`
* `Mlp::SIGMOID()` returns `i64`
* `Mlp::GELU()` returns `i64`
* `Mlp::make(i64[] sizes, i64 act, i64 seed)` returns `Mlp`
* `Mlp.forward(i64 x)` returns `i64` — the output node for the input node x
* `Mlp.predict(Tensor32 x)` returns `Tensor32`
* `Mlp.loss_on(Tensor32 x, Tensor32 y)` returns `double`
* `Mlp.classify_row(Tensor32 x, i64 row)` returns `i64`
* `Mlp.accuracy(Tensor32 x, i64[] labels)` returns `double`
* `Mlp.rate_at(i64 epoch, i64 epochs, double lr)` returns `double`
* `Mlp.fit(Tensor32 x, Tensor32 y, i64 epochs, double lr)` returns `double` — mean squared error; y has the outputs of every row
* `Mlp.fit_classes(Tensor32 x, i64[] labels, i64 epochs, double lr)` returns `double` — softmax cross entropy; labels[r] is the class of row r
* `Mlp.run(Tensor32 x, Tensor32 y, i64[] labels, i64 kind, i64 epochs, double lr)` returns `double`
* `Mlp.save(String path)` returns `bool`
* `Mlp::load(String path)` returns `Mlp`


### `<npu>`

the NPU of the phone through NNAPI: a layer with FIXED weights, y = x * W^T + bias.   #import <npu>   (a program that uses it is built like one that uses <native>)

```text
  if Npu::available() {
      NpuLinear l = NpuLinear::make(w, bias, 64, 256, 256);   // w: 256 x 256 numbers (row i = the weights of output i), bias: 256 numbers or null; 64 rows of x at a time
      l.run(x, y);                                            // x: 64 x 256, y: 64 x 256 (float32 in, float32 out)
      l.destroy();
  }
What was measured on a Kirin 990 (docs/design/26): one product of 512 x 512 x 512 in 8.8 ms (our NEON CPU 37 ms, the GPU 15 ms), 256 in 4.6 ms (CPU 5.5, GPU 3.6),
128 in 3.2 ms (CPU 1.0; a call costs about 3 ms, so for one row at a time (m = 1) the CPU wins; from 8 rows the NPU is level or faster). Making the model for a weight matrix takes about 70 ms (measured with 256 x 256 and 512 x 512), so use it for inference
(the weights stay) and not for training (the weights change at every step). The NPU computes in half precision: numbers above 65504 overflow and the digits are about 3.
The weights must be constants of the model: NNAPI on this phone refuses a model whose weights are an input (error 4). Biggest size tried: 512; 1024 was too slow.
Without NNAPI or without an NPU device `available()` is false and `make` gives a layer with ok = false: the program goes on with the CPU.
```

What it offers:

* `NpuLinear::make(float^ w, float^ bias, i64 m, i64 k, i64 n)` returns `NpuLinear` — w: n x k numbers (row-major), bias: n numbers or null; x has m rows
* `NpuLinear.run(float^ x, float^ y)` returns `bool` — y (m x n) = x (m x k) * W^T + bias; false when the NPU says no
* `NpuLinear.destroy()` returns `void`
* `Npu::available()` returns `bool` — true when NNAPI has a device that is not the reference CPU


### `<phys2d>`

a body that falls and walks in a world of tiles, and a camera that follows it.   #import <tilemap>  #import <phys2d>   (needs jcmp 1.2.1.0; license: MPL-2.0)

```text
  Body b = Body::make(50.0, 0.0, 8.0, 16.0);        // x, y, width, height in dots (the top left corner)
  b.vx = 120.0;  b.jump(300.0);                       // speed in dots a second; jump() gives an upward speed when the body stands on something
  b.step(world, 0, 16, 99, 1.0 / 60.0, 900.0);       // the tile layer 0; tiles are 16 dots; the numbers 1..99 are solid; dt in seconds; gravity in dots a second a second
  b.on_ground, b.hit_x, b.hit_y tell what it touched in the last step.
  Camera c = Camera::make(320, 180);   c.follow(b.x, b.y, 0.15);   c.limit(2000 * 16, 600 * 16);   int sx = c.screen_x(wx); int sy = c.screen_y(wy);
The body is moved one axis at a time and put against the tile it meets (no passing through at speeds below one tile in a step).
```

What it offers:

* `Body::make(double x, double y, double w, double h)` returns `Body`
* `Body::blocked(TileMap m, i64 layer, i64 ts, i64 solid_max, double bx, double by, double bw, double bh)` returns `bool` — is there a solid tile in the world where the box (bx, by, bw, bh) is
* `Body.jump(double speed)` returns `void`
* `Body.step(TileMap m, i64 layer, i64 ts, i64 solid_max, double dt, double gravity)` returns `void`
* `Camera::make(i64 vw, i64 vh)` returns `Camera`
* `Camera.limit(i64 world_w, i64 world_h)` returns `void` — the world is this big: the camera does not show beyond it
* `Camera.follow(double tx, double ty, double smooth)` returns `void` — goes toward the point that is in the middle of the view: smooth = the part of the way in one call (1.0 at once, 0.1 slowly)
* `Camera.screen_x(double wx)` returns `i64`
* `Camera.screen_y(double wy)` returns `i64`
* `Camera.world_x(i64 sx)` returns `double`
* `Camera.world_y(i64 sy)` returns `double`


### `<profile>`

timers by name, for a frame or a function (a start and a stop cost about 0.2 to 0.4 us).   #import <profile>   (needs jcmp 1.2.1.0; license: MPL-2.0)

```text
  Profile p = Profile::make();
  int t = p.start();   ...work...   p.stop("physics", t);      // adds the time of this run to the timer "physics"
  int id = p.timer("physics");  ...  p.stop_id(id, t);         // the same with no search by name (the fastest: for a function that runs a million times)
  p.frame();                                                    // call once a frame: counts frames
  jout << p.report();                                           // one line a timer: name, calls, total ms, average us, share
  p.total_us("physics"), p.calls("physics"), p.average_us("physics"), p.frames, p.reset();
Times are read from the system counter of the CPU (cntvct_el0, no system call: 60 to 120 ns a read on the development phone, where the counter runs at
1.92 MHz: one tick is 0.52 us, so one run shorter than that counts as 0 or 1 tick; the sum over many runs is right) and given in microseconds.
Profile::make_exact() reads the monotonic clock instead (a system call: 0.44 us a read, but the time is in ns): for a few long runs. A timer that does not exist yet is made by its first stop().
```

What it offers:

* `Profile::make()` returns `Profile`
* `Profile::make_exact()` returns `Profile` — timers that read the monotonic clock (ns, but slower to read)
* `Profile.now()` returns `i64` — the start mark to give to stop()
* `Profile.start()` returns `i64`
* `Profile.ns_of(i64 ticks)` returns `i64` — the nanoseconds of some ticks
* `Profile.index(String name)` returns `i64`
* `Profile.stop(String name, i64 t)` returns `i64` — adds the time since the mark t to the timer `name`; returns that time in ns
* `Profile.timer(String name)` returns `i64` — the number of a timer (it is made when it does not exist): give it to stop_id() to skip the search by name
* `Profile.stop_id(i64 id, i64 t)` returns `i64` — stop() for a timer that has a number
* `Profile.add_ticks(String name, i64 d)` returns `void`
* `Profile.add_ns(String name, i64 d)` returns `void` — adds a time that was measured somewhere else, in ns
* `Profile.frame()` returns `void`
* `Profile.calls(String name)` returns `i64`
* `Profile.total_us(String name)` returns `i64`
* `Profile.average_us(String name)` returns `i64`
* `Profile.reset()` returns `void`
* `Profile.report()` returns `String` — one line a timer, in the order they were first used

### `<qr>`

reads QR codes from a picture (a photo from the camera, a screenshot): the dots in, the text out.   #import <qr>   (license: MPL-2.0)

```text
  bool ok; String text = Qr::scan(im.px, im.w, im.h, @ok);        // im.px: 4 bytes for each dot, red green blue alpha (the Image of <png>)
  ok = false: no code was found or it could not be read (Qr::error() says which)
Versions 1 to 40, the four levels of error correction (Reed-Solomon, mistakes are repaired), the modes numeric, alphanumeric and bytes (UTF-8 text),
any turning, a tilt that a flat sheet gives (a straight-on view with a little tilt), the light of a photo (a local threshold).
Not yet: mirrored codes, white on black, Kanji mode, the strong perspective of a code seen from the side.
```

What it offers:

* `Qr::error()` returns `String`
* `Qr::scan(String px, i64 w, i64 h, bool^ ok)` returns `String`


### `<retrieve>`

search in your own texts (BM25): the documents, the READMEs, the examples.   #import <retrieve>

```text
  Retrieve r = Retrieve::make();
  r.add("LANGUAGE.md", text_of_the_file);           // cut into passages at blank lines and at lines that start with #
  r.build();                                        // once, after the last add
  Hits h = r.search("how do I open a file", 3);     // the best 3 passages
  for i in 0..h.n { jout << h.names[i] << "  " << h.scores[i] << "\n" << h.texts[i] << "\n"; }
Words are lower-case letters and digits (and _); Thai and other text without spaces is cut into pairs of characters, so a Thai question finds a Thai passage.
A word that is in every passage counts for nothing; a word that is in few passages counts a lot (BM25 with k1 = 1.5, b = 0.75).
```

What it offers:

* `Retrieve::make()` returns `Retrieve`
* `Retrieve.term_id(String t, bool create)` returns `i64`
* `Retrieve.terms_of(String text, i64[] out, bool create)` returns `void` — the terms of a text, pushed into out (as term numbers; unknown terms are made when create is true, else skipped)
* `Retrieve.push_term(String w, i64[] out, bool create)` returns `void`
* `Retrieve.flush_run(String[] run, i64[] out, bool create)` returns `void` — pairs of the characters of a run (one character alone when the run has one)
* `Retrieve.add_passage(String doc, String text)` returns `void`
* `Retrieve.add(String doc, String text)` returns `void` — a document is cut into passages at blank lines and before every line that starts with #
* `Retrieve.build()` returns `void`
* `Retrieve.search(String query, i64 k)` returns `Hits`


### `<sprite>`

pictures for games: a Sprite is a picture with see-through dots; draw it, a part of it (a sprite sheet), turned, scaled.

```text
  #import <deflate>  #import <png>  #import <gamej>  #import <sprite>   (needs jcmp 1.2.1.0; license: MPL-2.0)
  bool ok; Sprite hero = Sprites::load("hero.png", @ok);   hero.draw(g, 10, 20);   hero.draw_part(g, 16, 0, 16, 16, 40, 40, false);   // the second tile of a sheet
  Sprite tile = hero.cut(32, 0, 16, 16);   tile.draw_scaled(g, 0, 0, 3);
The dots are numbers 0xAARRGGBB (alpha 255 = solid, 0 = see-through, between = mixed with what is on the screen). The drawing is clipped to the screen.
blit* draw on any int[] of w * h dots (0xRRGGBB, like the screen of <gamej>), so that they can be used and tested without a window.
```

What it offers:

* `Sprite::put(i64[] dst, i64 dw, i64 dh, i64 x, i64 y, i64 c)` returns `void` — one dot of the sprite on the screen buffer: alpha 0 skips it, 255 puts it, between mixes it with what was there
* `Sprite.blit(i64[] dst, i64 dw, i64 dh, i64 x, i64 y)` returns `void` — the whole sprite at (x, y)
* `Sprite.blit_part(i64[] dst, i64 dw, i64 dh, i64 sx, i64 sy, i64 sw, i64 sh, i64 x, i64 y, bool flip)` returns `void` — the part (sx, sy, sw, sh) of the sprite at (x, y); flip turns it left to right
* `Sprite.blit_scaled(i64[] dst, i64 dw, i64 dh, i64 x, i64 y, i64 scale)` returns `void` — the whole sprite made bigger by a whole number (pixels stay sharp)
* `Sprite.draw(Game g, i64 x, i64 y)` returns `void`
* `Sprite.draw_part(Game g, i64 sx, i64 sy, i64 sw, i64 sh, i64 x, i64 y, bool flip)` returns `void`
* `Sprite.draw_scaled(Game g, i64 x, i64 y, i64 scale)` returns `void`
* `Sprite.cut(i64 sx, i64 sy, i64 sw, i64 sh)` returns `Sprite` — a new sprite made of a part of this one (a tile of a sheet)
* `Sprites::from_image(Image im)` returns `Sprite` — the sprite of a decoded picture
* `Sprites::load(String path, bool^ ok)` returns `Sprite` — a PNG file; ok = false when it cannot be read


### `<spritebatch>`

many sprites drawn in order: a texture atlas and a batch.   #import <deflate> <png> <gamej> <sprite> <spritebatch>   (needs jcmp 1.2.1.0; license: MPL-2.0)

```text
  Atlas a = Atlas::make(256, 256);                 // one big picture; small sprites are packed into it row by row
  int hero = a.add(Sprites::load("hero.png", @ok)); int tree = a.add(tree_sprite);     // the number of the sprite, or -1 when the atlas is full
  SpriteBatch b = SpriteBatch::make(a);
  b.view(cam_x, cam_y, 320, 180);                  // optional: sprites outside this window are dropped
  b.add(tree, 100, 40, 1);  b.add(hero, 50, 60, 2);  b.add_flip(hero, 80, 60, 2, true);      // sprite, x, y, layer (0..15; a higher layer is drawn later = in front)
  b.flush(game);                                   // draws everything, layer by layer (the same layer in the order of add), then empties the batch
  b.count (sprites waiting), b.drawn (sprites drawn by the last flush), b.flush_to(int[] dst, w, h) for any buffer, b.clear().
The atlas keeps the sprites in one Sprite (a.sheet), so a graphics chip can take it as ONE texture and the batch is one draw call.
```

What it offers:

* `Atlas::make(i64 w, i64 h)` returns `Atlas`
* `Atlas.count()` returns `i64`
* `Atlas.add(Sprite s)` returns `i64` — packs a sprite; the number of it, or -1 when there is no room
* `SpriteBatch::make(Atlas a)` returns `SpriteBatch`
* `SpriteBatch.view(i64 x, i64 y, i64 w, i64 h)` returns `void` — only sprites that touch this window are kept
* `SpriteBatch.add(i64 id, i64 x, i64 y, i64 layer)` returns `void`
* `SpriteBatch.add_flip(i64 id, i64 x, i64 y, i64 layer, bool flip)` returns `void`
* `SpriteBatch.clear()` returns `void`
* `SpriteBatch.order()` returns `i64[]` — the order of drawing: layer by layer, inside a layer as added (a counting sort)
* `SpriteBatch.flush_to(i64[] dst, i64 dw, i64 dh)` returns `void`
* `SpriteBatch.flush(Game g)` returns `void`


### `<tilemap>`

the world of a 2D game made of tiles (a Terraria or Stardew kind of world): layers, chunks, changes, saving.   #import <tilemap>   (needs jcmp 1.2.1.0; license: MPL-2.0)

```text
  TileMap m = TileMap::make(2000, 600, 2);   m.set(0, 10, 20, 5);   int t = m.get(0, 10, 20);       // 2000 x 600 tiles, 2 layers (0 ground, 1 things on it); a tile is a number 0..65535
  if m.dirty(0, 10, 20) { ... }   m.clean();                                                        // which chunks changed since the last clean (to draw or save only those)
  m.save("world.jw"); TileMap w = TileMap::load("world.jw", @ok);
The tiles are kept in chunks of 16 x 16 for each layer (a chunk that was never changed takes no room), so a big world is small in memory and a change marks one chunk.
The numbers mean what the game says; 0 is empty. Outside the world every tile is 0 and set() does nothing.
```

What it offers:

* `TileMap::make(i64 w, i64 h, i64 layers)` returns `TileMap`
* `TileMap.inside(i64 layer, i64 x, i64 y)` returns `bool`
* `TileMap.get(i64 layer, i64 x, i64 y)` returns `i64`
* `TileMap.set(i64 layer, i64 x, i64 y, i64 tile)` returns `void`
* `TileMap.dirty(i64 layer, i64 x, i64 y)` returns `bool` — changed since the last clean()
* `TileMap.clean()` returns `void`
* `TileMap.used_chunks()` returns `i64` — how many chunks hold something (the memory is this * 256 * 8 bytes)
* `TileMap.fill(i64 layer, i64 x, i64 y, i64 rw, i64 rh, i64 tile)` returns `void` — a rectangle of one layer
* `TileMap.save(String path)` returns `void` — the world as text: a header, then for each chunk that exists  layer chunk  and its 256 numbers (the file of a save; small, readable)
* `TileMap::load(String path, bool^ ok)` returns `TileMap`



## Without an operating system: `#import <os>` (1.2.41.2)

One library for a program with a `#target` line (a board, a kernel, or the emulator `jemu --system`; `BARE.md`). It has three parts, and each is called by its own name:

| part | what it is | the calls |
|---|---|---|
| `Console` | text to the console register of the target | `put(c)`, `print(text)`, `line(text)`, `num(n)`, `hex(n)` |
| `Heap` | `alloc` and `free` of any size from the heap range of the target (first fit, free neighbours join) | `alloc(n)`, `free(p)`, `left()`, `init(start, bytes)` |
| `Pool` | blocks in a row from a range you give, all given back at once | `init(start, bytes)`, `take(n)`, `reset()`, `left()` |

```jk
#target virt {
    entry 0x40000000;
    ram 0x40100000 1M;
    stack 64K;
    heap 64K;
    console 0x09000000;
    exit 0x09100000;
}
#import <os>
using Console;                           // the names of Console without the prefix: line(...), num(...)

fn main() {
    line("hello");
    i64^ a = (i64^)Heap::alloc(80);      // or  using Heap;  and  alloc(80)
    a[9] = 1234;
    num(a[9]); put(10);
    Heap::free((void^)a);
    return 0;                            // written to the exit device
}
```

Call a part with its name (`Console::line("x")`) or write `using Console;` once and call it without the name (`line("x")`), as with `using Mem;`. Nothing is loaded that you do not use. Nothing in `<os>` calls an operating system. A target without a `console` line writes nothing with `Console`. Put the `#target` line first in the file.
