# J2K cookbook

Short programs that do one useful thing each. Every program here was compiled and run (jcmp 1.2.11); the text under it is what it printed. Copy one into a file, then:

```
jcmp name.jk -o name && ./name
```

The same files are in `examples/cookbook/`.

## Read a file line by line

```jk
// Read a file line by line, count the lines and the words, show the longest line.
#import <stdlib>
using stdlib;

int main() {
    String path = "r01_lines.jk";                       // this very file
    String[] lines = Fs::read_lines(path).take();       // take(): the value, or stop with a message when the file cannot be read
    int words = 0;
    String longest = "";
    for i in 0..lines.len {
        words += lines[i].split(" ").len;
        if lines[i].len > longest.len { longest = lines[i] + ""; }
    }
    jout << lines.len << " lines, " << words << " words\n";
    jout << "longest: " << longest.len << " characters\n";
    return 0;
}
```

Output:

```
17 lines, 185 words
longest: 129 characters
```

## Errors as values: Result

```jk
// Errors as values: Result<T, Error>. switch looks at both cases; take() is for "this cannot fail here".
#import <stdlib>
using stdlib;

i64 main() {
    switch Fs::read_text("no/such/file.txt") {
        Result::Ok(text): { jout << "read " << text.len << " bytes\n"; }
        Result::Err(e): { jout << "could not read: " << e.message << "\n"; }
    }
    Result<i64, Error> r = Fs::write_text("_cook_tmp.txt", "hello\n");
    switch r {
        Result::Ok(n): { jout << "wrote " << n << " bytes\n"; }
        Result::Err(e): { jout << "could not write: " << e.message << "\n"; }
    }
    jout << Fs::read_text("_cook_tmp.txt").take().len << "\n";
    return 0;
}
```

Output:

```
could not read: cannot open no/such/file.txt: there is no file or folder with this name (error 2)
wrote 6 bytes
6
```

## Lay out numbers and text

```jk
// Lay out numbers and text: fmt (digits), tohex, tobin, pad (left aligned), padl (right aligned), and the long names in Fmt.
#import <stdlib>
using stdlib;

int main() {
    String[] names = arr(3);
    names.push("apple"); names.push("kiwi"); names.push("watermelon");
    double[] prices = arr(3);
    prices.push(1.5); prices.push(0.25); prices.push(12.0);
    for i in 0..names.len {
        jout << pad(names[i], 12) << padl(fmt(prices[i], 2), 8) << "\n";
    }
    jout << tohex(255) << " " << tobin(10) << " " << Fmt::thousands(1234567) << " " << Fmt::percent(0.256, 1) << " " << Fmt::bytes(1536) << "\n";
    return 0;
}
```

Output:

```
apple           1.50
kiwi            0.25
watermelon     12.00
ff 1010 1,234,567 25.6% 1.5 KB
```

## A struct with methods, and sorting

```jk
// A struct with methods, an array of them, and sorting by a field.
#import <stdlib>
using stdlib;

struct Player {
    String name;
    int score;
    void add(self, int points) { self.score += points; }
    String describe(self) { return self.name + ": " + str(self.score); }
}

int main() {
    Player[] ps = arr(4);
    String[] names = arr(3);
    names.push("Mali"); names.push("Somchai"); names.push("Nok");
    for i in 0..names.len {
        Player p;
        p.name = names[i] + "";
        p.score = (i * 7) % 5;
        ps.push(p);
    }
    ps[0].add(10);
    // a bubble sort on the score, highest first
    for a in 0..ps.len {
        for b in 0..ps.len - 1 - a {
            if ps[b].score < ps[b + 1].score {
                Player t = ps[b];
                ps[b] = ps[b + 1];
                ps[b + 1] = t;
            }
        }
    }
    for i in 0..ps.len { jout << ps[i].describe() << "\n"; }
    return 0;
}
```

Output:

```
Mali: 10
Nok: 4
Somchai: 2
```

## An enum that carries values

```jk
// An enum that carries values, and switch over it.
#import <stdlib>
using stdlib;

enum class Shape {
    Circle(double r),
    Rect(double w, double h),
    Dot
}

double area(Shape s) {
    switch s {
        Shape::Circle(r): { return 3.14159 * r * r; }
        Shape::Rect(w, h): { return w * h; }
        Shape::Dot: { return 0.0; }
    }
    return 0.0;
}

int main() {
    jout << fmt(area(Shape::Circle(2.0)), 2) << " " << fmt(area(Shape::Rect(3.0, 4.5)), 2) << " " << fmt(area(Shape::Dot), 2) << "\n";
    return 0;
}
```

Output:

```
12.57 13.50 0.00
```

## Count with a Map, and a Set

```jk
// Count words with a Map, then list them in order.
#import <stdlib>
using stdlib;

int main() {
    String text = "the cat and the dog and the bird";
    Map<String, int> count;
    String[] words = text.split(" ");
    for i in 0..words.len {
        if count.has(words[i]) { count.put(words[i], count.get(words[i]) + 1); }
        else { count.put(words[i], 1); }
    }
    String[] keys = count.keys_list();
    // sort the keys (a bubble sort: the list is short)
    for a in 0..keys.len {
        for b in 0..keys.len - 1 - a {
            if keys[b] > keys[b + 1] { String t = keys[b] + ""; keys[b] = keys[b + 1] + ""; keys[b + 1] = t; }
        }
    }
    for i in 0..keys.len { jout << pad(keys[i], 6) << count.get(keys[i]) << "\n"; }
    Set<int> seen;
    int dup = 0;
    int[] nums = arr(6);
    nums.push(3); nums.push(1); nums.push(3); nums.push(2); nums.push(1); nums.push(3);
    for i in 0..nums.len { if !seen.add(nums[i]) { dup += 1; } }
    jout << seen.len << " different, " << dup << " repeats\n";
    return 0;
}
```

Output:

```
and   2
bird  1
cat   1
dog   1
the   3
3 different, 3 repeats
```

## Read JSON

```jk
// Read JSON, look inside, write it back.
#import <stdlib>
using stdlib;

int main() {
    String src = "{\"name\": \"j2k\", \"version\": 1.2, \"tags\": [\"fast\", \"small\"], \"ok\": true}";
    JsonDoc doc = Json::parse(src).take();
    jout << doc.text(doc.get(doc.root(), "name")) << " " << doc.number(doc.get(doc.root(), "version")) << "\n";
    int tags = doc.get(doc.root(), "tags");
    for i in 0..doc.len(tags) { jout << "tag " << doc.text(doc.at(tags, i)) << "\n"; }
    jout << doc.dump(doc.root()).len << "\n";
    return 0;
}
```

Output:

```
j2k 1.200000
tag fast
tag small
76
```

## Measure time and wait

```jk
// Measure time, wait, and print dates.
#import <stdlib>
using stdlib;

int fib(int n) { if n < 2 { return n; } return fib(n - 1) + fib(n - 2); }

int main() {
    int t0 = Time::mono_ns();
    int f = fib(27);
    int ms = (Time::mono_ns() - t0) / 1000000;
    jout << "fib(27) = " << f << "\n";
    jout << "it took a measurable time: " << (ms >= 0) << "\n";
    Time::sleep_ms(20);
    jout << "slept\n";
    return 0;
}
```

Output:

```
fib(27) = 196418
it took a measurable time: true
slept
```

## Run another program, arguments, environment

```jk
// Run another program and keep what it prints; read the command line and the environment.
#import <stdlib>
using stdlib;

int main() {
    String[] a = Env::args();
    jout << "arguments: " << a.len - 1 << "\n";
    String[] args = arr(2);
    args.push("hello from echo");
    String out = Proc::output("echo", args).take();
    jout << "echo said: " << out.trim() << "\n";
    switch Env::get("HOME") {
        Option::Some(h): { jout << "HOME is set\n"; }
        Option::None: { jout << "no HOME\n"; }
    }
    return 0;
}
```

Output:

```
arguments: 0
echo said: hello from echo
HOME is set
```

## Threads: Task and Channel

```jk
// Work on several threads: a Task gives a value, a Channel carries values between threads.
#import <stdlib>
#import <cpu>
#import <tasks>
using stdlib;

int square(void^ arg) {
    int n = (int)arg;
    return n * n;
}

int main() {
    Task a = Task::run(square, (void^)12);
    Task b = Task::run(square, (void^)7);
    jout << a.wait() + b.wait() << "\n";
    Channel<int> c = Channel<int>::make();
    c.send(5);
    c.send(6);
    c.close();
    int sum = 0;
    bool got = true;
    while got {
        int v = c.try_receive(@got);
        if got { sum += v; }
    }
    jout << sum << "\n";
    return 0;
}
```

Output:

```
193
11
```

## An interface (itf)

```jk
// An interface (itf): different structs answer the same call.
#import <stdlib>
using stdlib;

itf Animal {
    String sound(self);
    int legs(self);
}
struct Dog impl Animal {
    void init(self) { }
    String sound(self) { return "woof"; }
    int legs(self) { return 4; }
}
struct Bird impl Animal {
    void init(self) { }
    String sound(self) { return "tweet"; }
    int legs(self) { return 2; }
}

void introduce(Animal^ a) { jout << a^.sound() << " on " << a^.legs() << " legs\n"; }

int main() {
    Dog d;
    Bird b;
    introduce(@d);
    introduce(@b);
    return 0;
}
```

Output:

```
woof on 4 legs
tweet on 2 legs
```

## Text

```jk
// Text: pieces, search, change, build.
#import <stdlib>
using stdlib;

int main() {
    String s = "  J2K is a small, fast language  ";
    String t = s.trim();
    jout << "[" << t << "] " << t.len << "\n";
    jout << t.upper() << " | " << t.lower() << "\n";
    jout << t.find("small") << " " << t.slice(0, 3) << " " << (t.find("fast") >= 0) << "\n";
    String[] parts = t.split(" ");
    jout << parts.len << " words, the last is " << parts[parts.len - 1] << "\n";
    String r = "";
    for i in 0..parts.len { r += parts[i].slice(0, 1); }
    jout << r << "\n";
    jout << str(42) + "/" + str(7) << " " << "12".to_int() + 1 << "\n";
    return 0;
}
```

Output:

```
[J2K is a small, fast language] 29
J2K IS A SMALL, FAST LANGUAGE | j2k is a small, fast language
9 J2K true
6 words, the last is language
Jiasfl
42/7 13
```

## A generic struct and a lambda

```jk
// A generic struct and a lambda.
#import <stdlib>
using stdlib;

struct Pair<A, B> {
    A first;
    B second;
}

int apply_twice(int(int)^ f, int x) { return f(f(x)); }

int main() {
    Pair<String, int> p;
    p.first = "age";
    p.second = 31;
    jout << p.first << "=" << p.second << "\n";
    jout << apply_twice(int(int v) { return v * 3; }, 5) << "\n";
    return 0;
}
```

Output:

```
age=31
45
```

## try / catch and defer

```jk
// try / catch for errors that are thrown, defer for cleanup on every way out.
#import <stdlib>
using stdlib;

int parse(String s) {
    if s.len == 0 { throw "empty text"; }
    return s.to_int();
}

int main() {
    String[] inputs = arr(2);
    inputs.push("41"); inputs.push("");
    for i in 0..inputs.len {
        defer { jout << "done with " << i << "\n"; }
        try {
            jout << parse(inputs[i]) + 1 << "\n";
        } catch (e) {
            jout << "caught: " << e << "\n";
        }
    }
    return 0;
}
```

Output:

```
42
done with 0
caught: empty text
done with 1
```

## Bits and bytes

```jk
// Bits and bytes.
#import <stdlib>
using stdlib;

int main() {
    int flags = 0;
    flags = flags | (1 << 3);
    flags = flags | 1;
    jout << flags << " " << tobin(flags) << " " << ((flags >> 3) & 1) << "\n";
    int x = 0xF0F0;
    jout << tohex(x xor 0xFFFF) << " " << tohex(x & 0xFF00) << "\n";
    char buf[4];
    buf[0] = 'J'; buf[1] = '2'; buf[2] = 'K'; buf[3] = 0;
    jout << (int)buf[0] << " " << (int)buf[2] << "\n";
    return 0;
}
```

Output:

```
9 1001 1
f0f f000
74 75
```
