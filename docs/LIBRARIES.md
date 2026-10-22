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

void main() {
    // Result: a call that can fail gives a value or an error; you choose what to do
    Result<String, Error> r = Fs::read_text("/no/such/file");
    switch r {
        Result::Ok(text): cout << "read " << text.len << " bytes\n";
        Result::Err(e): cout << "failed: " << e.message << "\n";
    }
    // Arena: many small things, freed all at once
    Arena a;
    a.init(4096);
    int^ x = (int^)a.take(8);
    x[0] = 42;
    cout << x[0] << " from the arena\n";
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

void main() {
    cout << Math::sqrt(2.0) << " " << Math::pow(2.0, 10.0) << " " << Math::floor(-2.5) << "\n";
    cout << Math::min(3.0, 1.5) << " " << Math::abs(-4.25) << " " << Math::clamp(15.0, 0.0, 10.0) << "\n";
    Result<int, Error> n = Num::parse_int("1234");
    cout << n.unwrap() + 1 << "\n";
    Result<double, Error> d = Num::parse_double("2.5");
    cout << d.unwrap() * 2.0 << "\n";
    cout << Num::parse_int("12x").is_err() << "\n";
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

void main() {
    String s = "  The quick brown fox  ";
    String t = s.trim();
    cout << t.upper() << " | " << t.len << " | " << t.find("quick") << "\n";
    String[] words = t.split(" ");
    cout << words.len << " words, the last is " << words[words.len - 1] << "\n";
    cout << words.join("-") << "\n";
    cout << Fmt::pad_left("7", 3, '0') << " " << Fmt::fixed(3.14159, 2) << " " << Fmt::thousands(1234567) << "\n";
    cout << Regex::matches("[a-z]+@[a-z]+\\.com", "ann@mail.com") << " " << Regex::find_text("[0-9]+", "room 42") << "\n";
    cout << Hex::encode("Hi") << " " << Base64::encode("Man") << "\n";
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

**Tip.** `Regex` is a backtracking matcher meant for common cases; for a plain word, `String.find` is much faster.

<a id="files"></a>
## Files and folders: `Fs`, `Dir`, `Path`

`Fs` reads and writes whole files (`read_text`, `read_lines`, `write_text`, `append_text`, `size`, `exists`, `remove`, `rename`), `Dir` makes, lists and removes folders, and `Path` builds and splits names (`join`, `name`, `parent`, `ext`, `stem`). Everything that can fail gives a `Result`.

```jk
#import <stdlib>

void main() {
    Dir::make_all("tl_dir/sub");
    Fs::write_text(Path::join("tl_dir/sub", "a.txt"), "one\ntwo\n").unwrap();
    Fs::append_text("tl_dir/sub/a.txt", "three\n").unwrap();
    String[] lines = Fs::read_lines("tl_dir/sub/a.txt").unwrap();
    cout << lines.len << " lines, size " << Fs::size("tl_dir/sub/a.txt").unwrap() << "\n";
    String[] names = Dir::list("tl_dir/sub").unwrap();
    cout << names[0] << " " << Path::ext("tl_dir/sub/a.txt") << " " << Path::stem("a.txt") << "\n";
    Fs::remove("tl_dir/sub/a.txt");
    Dir::remove("tl_dir/sub");
    Dir::remove("tl_dir");
    cout << Fs::exists("tl_dir") << "\n";
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

void main() {
    String[] a = Env::args();
    cout << "arguments: " << a.len << "\n";
    cout << Env::get("J2K_NO_SUCH_VARIABLE").is_none() << "\n";
    String[] args = arr(0);
    args.push("from a child process");
    cout << Proc::output("echo", args).unwrap();
    String[] none = arr(0);
    int code = Proc::run("true", none).unwrap();
    cout << "exit code " << code << "\n";
    cout << (Term::cols() > 0) << "\n";
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

**Tip.** Messages for the person go to `cout`; messages about the program (errors, progress) go to `cerr` or `Log`, so that `program > file` keeps the results clean.

<a id="time"></a>
## Time: `Time`, `Random`, `Date`

`Time::now_ms()` is the wall clock, `Time::mono_ns()` a clock that only goes forward (use it to measure), `Time::sleep_ms` waits. `Random` gives numbers from a seed, so a run can be repeated. `Date` is a day and a time on the calendar (UTC), from and to seconds since 1970.

```jk
#import <stdlib>

void main() {
    int t0 = Time::mono_ns();
    Time::sleep_ms(10);
    cout << (Time::mono_ns() - t0 >= 10000000) << "\n";
    Random::seed(7);
    int r = Random::range(1, 7);
    cout << (r >= 1 && r < 7) << " " << (Random::unit() < 1.0) << "\n";
    Date d;
    d.set_unix(1700000000);
    cout << d.text() << " " << d.weekday() << "\n";
    d.add_days(30);
    cout << d.text() << "\n";
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

void main() {
    String[] names = arr(2);
    names.push("ann"); names.push("bob");
    Map<String, int> ages;
    ages.put("ann", 31);
    Set<int> seen;
    seen.add(3); seen.add(3);
    cout << names.len << " " << ages.get("ann") << " " << seen.len << "\n";
    JsonDoc doc = Json::parse("{\"name\": \"J2K\", \"tags\": [\"a\", \"b\"]}").unwrap();
    cout << doc.text(doc.get(doc.root(), "name")) << " " << doc.len(doc.get(doc.root(), "tags")) << "\n";
    String[] f = Csv::split_line("x,\"y,z\",w");
    cout << f.len << " " << f[1] << "\n";
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

void main() {
    cout << Sha256::hex("abc") << "\n";
    cout << Base64::encode("hello") << " " << Hex::encode("hello") << "\n";
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

void work(void^ arg) {
    for i in 0..1000 { Atomic::add(@total, 1); }
}

void main() {
    Thread a = create(work, null);
    Thread b = create(work, null);
    a.join();
    b.join();
    cout << total << "\n";
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

void main() {
    vec3 a = {1.0, 2.0, 3.0};
    vec3 b = {4.0, 5.0, 6.0};
    vec3 c = a + b * 2.0;
    cout << c.x << " " << c.y << " " << c.z << " " << c.zyx.x << "\n";
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
        Result::Ok(body): cout << body.len << " bytes\n";
        Result::Err(e): cerr << "failed: " << e.message << "\n";
    }
}
```

**Tip.** Put a time limit on anything that waits for the network, and do not read a whole answer of unknown size into memory without a limit.

