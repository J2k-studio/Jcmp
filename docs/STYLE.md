# Writing J2K short and clear

Short is good when a person can still see what it does. These are the habits of the language (the options for more are in `design/30-less-to-write.md`). Every example compiles.

## 1. Say a value in the text: `{ }` inside a string
```jk
#import <stdlib>
using stdlib;

int main() {
    int n = 3;
    String name = "tea";
    jout << "n={n}, the next is {n + 1}, {name} has {name.len} letters\n";
    return 0;
}
```
Output:
```
n=3, the next is 4, tea has 3 letters
```
Not: `jout << "n=" << n << ", the next is " << n + 1 << ...`. (`{{` and `}}` write a brace.)

## 2. A default for a missing value: `.or(default)`
```jk
#import <stdlib>
using stdlib;

int main() {
    String home = Env::get("J2K_NOT_SET_XYZ").or("/tmp");
    int n = Num::parse_int("12x").or(-1);
    jout << "{home} {n}\n";
    return 0;
}
```
Output:
```
/tmp -1
```
Not an eight line `switch` to read an `Option`.

## 3. The smaller, the larger, the absolute value: `min` `max` `abs` `clamp`
```jk
#import <stdlib>
using stdlib;

int main() {
    int w = 40;
    int h = 25;
    jout << "{min(w, h)} {max(w, h)} {abs(h - w)} {clamp(w, 0, 30)} {max(2.5, 1.5)}\n";
    return 0;
}
```
Output:
```
25 40 15 30 2.500000
```
Not `int m = w; if h < w { m = h; }`.

## 4. Pass an array where a pointer is wanted without a cast
`@buf` already becomes the `char^` (or `int^`) that a function asks for when the element type is the same. A cast is only for changing the element type.
```jk-no
char out[32];
Crypto::sha256(text.c(), text.len, @out);        // not (char^)@out
```

## 5. The short module names return the value
`fs.read_text(path)` returns the text and throws an error that `try` / `catch` can take; `Fs::read_text(path)` returns a `Result` for a person who wants the error as a value. Use the short one first; do not add `.unwrap()` to the long one just to get the text.

## 6. Names and shape
Functions, variables and fields in `snake_case`; types in `CamelCase`; one statement on a line; `else` after the `}` of the `if` on the same line or the next one; a method says `(self)` and a field is `self.x` (this is how J2K shows where a name comes from); a bit exclusive-or is `xor`.

## 7. Coming (decided in `syntax-design.md` section 109, built in 1.3.x)
`var x = expr;` (the type from the value), `double m = if h < w { h } else { w };`, the array literal `["-c", cmd]`, and the types `i16` / `u16`. Until then the long forms stay valid.
