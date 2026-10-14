# The standard library in categories

`#import <stdlib>` reads everything below (unused functions are left out of the program). A category reads only its own part
and what that part needs, so a small program is compiled with less text:

```jk
#import <text>
#import <data>          // Map, Set, Queue ... (also reads core, number and text)
```

| category | what it holds | needs |
|---|---|---|
| `core` | `Sys` (system calls), `Option`, `Result`, `Error`, `ErrorKind`, `Arena` (memory handed out in a row, given back at once); the memory routines (`Mem`, dynamic arrays, `String`) are always there | - |
| `number` | `Math` (functions of numbers, constants), `Num` (numbers from text) | core |
| `text` | `Str` (0-terminated text), `Hex`, `Base64`, `Fmt` (fixed digits, padding, thousands, hex, percent, bytes), `Regex` (a small pattern matcher) | core |
| `files` | `File`, `Fs` (whole files, `Result`), `Dir` (folders), `Path` | core, text |
| `system` | `Env` (arguments, environment), `Proc` (run a program), `Term` (the terminal), `Log` (messages with a level, on standard error) | core, text |
| `time` | `Time` (clock, sleep), `Random`, `Date` (calendar date and time from and to seconds since 1970) | core |
| `data` | `Map`, `Set`, `Queue`, `Deque`, `Heap`, `Span`, `Json`, `JsonDoc`, `Csv` (one line of values), `Toml` (settings: `[section]`, `key = value`) | core, number, text |
| `crypto` | `Sha256` | core, text, files |
| `net` | `Net` (TCP sockets over IPv4: listen, accept, connect, send, recv; a socket pair inside the program; no name lookup) | core, text |

Other libraries are named as before: `#import <math>` (`vector`, `matrix`, `quat`, `complex`, `stats`: chosen with
`using math::vector;`), `<gfx>` (`canvas`, `screen`), `<cpu>` (threads), `<simd>`.

`Sys::name` is a system register when `Sys` has no function of that name; `Sys::write(...)` calls the function.

## Examples

```jk
#import <text>
cout << Fmt::fixed(3.14159, 2) << " " << Fmt::thousands(1234567) << " " << Fmt::percent(0.256, 1) << "\n";   // 3.14 1,234,567 25.6%
cout << Regex::find_text("[0-9]+", "room 42, floor 7") << "\n";                                           // 42
```

```jk
#import <time>
Date d;  d.set_unix(1709211909);  cout << d.text() << " " << d.weekday() << "\n";    // 2024-02-29 13:05:09 4  (4 = Thursday)
```

```jk
#import <data>
String cfg = "[server]\nport = 8080\n";
cout << Toml::get_int(cfg, "server.port").unwrap() << "\n";                 // 8080
```
