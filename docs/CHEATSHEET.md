# J2K cheat sheet

One page of the things you use every day. Every line of the program below compiles and runs (`jcmp cheat.jk -o cheat && ./cheat`).

```jk
#import <stdlib>
using stdlib;

struct Point { int x; int y; }
enum class Color { Red, Green, Blue };

int add(int a, int b) { return a + b; }

void main() {
    // variables
    int n = 3;
    double d = 2.5;
    bool ok = n > 2 && d < 3.0;
    String s = "hi";
    // text
    jout << "n = " << n << ", " << s + "!" << ", " << ok << "\n";
    // if / loops
    if n == 3 { jout << "three\n"; } else if n == 4 { jout << "four\n"; } else { jout << "other\n"; }
    for i in 0..3 { jout << i << " "; }
    jout << "\n";
    int k = 0;
    while k < 3 { k += 1; }
    // arrays
    int[] a = arr(4);
    a.push(10); a.push(20);
    jout << a.len << " " << a[1] << "\n";
    // structs and enums
    Point p = {1, 2};
    p.x = 5;
    Color c = Color::Green;
    jout << p.x + p.y << " " << (c == Color::Green) << "\n";
    // functions
    jout << add(2, 3) << "\n";
    // text to number
    jout << "42".to_int() + 1 << "\n";
}
```

Output:

```
n = 3, hi!, true
three
0 1 2 
2 20
7 true
5
43
```

## Commands

| What | Command |
|---|---|
| Build and run | `jcmp prog.jk -o prog && ./prog` |
| Read the code that was made | `jcmp prog.jk --emit-asm prog.jasm` |
| Index checks while testing | `jcmp -d prog.jk -o prog` |
| Turn off an optimisation to look for a fault | `-novec`, `-nofma`, `-nopeep`, `-noir` |
| Format the source | `jcmp fmt prog.jk` |
| Install a library or tool | `jc install NAME` |

## Where to read more

[BASICS.md](BASICS.md) (start here), [TUTORIAL.md](TUTORIAL.md) (150+ lessons), [COOKBOOK.md](COOKBOOK.md) (recipes), [LANGUAGE.md](LANGUAGE.md) (everything), [PERFORMANCE.md](PERFORMANCE.md) (fast code), [GUIDES.md](GUIDES.md) (the guides).
