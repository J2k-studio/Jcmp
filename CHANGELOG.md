# Changelog

## 0.9.58
* **A real register allocator** (`jcmp/jc_regs.j`): a live variable analysis (a backward dataflow over the lines and jumps of a function), the live interval of every local, and a **linear scan** over the intervals. Locals whose lives do not meet share a register, so more than seven locals can live in registers over a function; if the registers are all taken, the local that is used least stays in memory. Whole numbers and pointers go to `x19`..`x25`, doubles to `d8`..`d15`.
* **Doubles stay in floating point registers:** the left operand of a float operation waits in `d16`, `d17`, ... (before: in an x register or on the stack), the operands of an operation go to `d0` and `d1` without a trip through x0, and the optimiser (value numbering of registers, copy forwarding, removing moves that nothing reads, `ldr dN, [..]` / `str dN, [..]` instead of a load and a move) removes most of the moves between x and d registers. The assembler knows `fmov dN, dM`, `ldr dN, [..]` and `str dN, [..]`.
* **More plain code is kept in registers:** the left operand also waits in a register when the right operand is a path through a struct (`b[j].x`, `p.pos.y`) and a call of `__fsqrt` / `__ffloor` / `__fceil` / `__ftrunc`; `add xA, xA, #N` before a load or store goes into the address (`ldr x0, [x0, #8]`); a dead `add x0, x29, #N` in front of a load is not an address-taken slot any more.
* **Fixed (an old gap):** `b.len` on an array parameter of structs (`void f(Body b[])`) did not compile ("this value has no fields").
* **The mascot:** when the Moon is the letter J its shadow on the Earth is a J too (before: a circle).
* Measured (ms, `clang -O2` in brackets): `fib(35)` 87 -> 72 (61), a sieve of 5 million 60 (76), a 200 x 200 matrix product 36 -> 30 (28), a Mandelbrot set 72 -> 49 (47), n-body 593 -> 321 (115), gcd 339 -> 347 (262). Test `t267` (n-body on an array of structs, checked against a C program).

## 0.9.57
* **Faster floats and array access:** a float literal is worked out when the program is compiled (`0.5` is one `mov` of its bits, before: five instructions at run time; checked against Python bit by bit, test `t266`). The left operand of an operator waits in a register also when the right operand is an array element, a float, a cast or a group of plain things (before: pushed on the stack). The base address of a global or local array with a big offset is added after the index (no push). 
* **Register pass, second step:** the old value of a register is saved in the frame slot of the variable that moved (no change of `sp`); a variable needs 4 weighted uses (was 6); the moves that are left are removed more often (a copied register is used directly: `mov x1, x20 / mul x0, x0, x1` becomes `mul x0, x0, x20`, `cmp` on registers), and the search for "not needed afterwards" follows up to 400 lines.
* Measured (ms, `clang -O2` in brackets): `fib(35)` 99 -> 87 (65), 300 million `s = s + i % 7` 767 -> 747 (200), a sieve of 5 million 98 -> 60 (75), a 200 x 200 matrix product 62 -> 36 (30).

## 0.9.56
* **Faster code, third step: a register pass** (`jcmp/jc_regs.j`, `-noregs` switches it off). In a function, the whole-number locals that are used most (weighted by how deep in loops they are used, at most seven) live in the registers `x19`..`x25` instead of the stack frame; the registers are saved at the start and given back at the end of the function. The compiler tells the pass which locals are plain 8-byte values; a local whose address is taken, a function with owners/`defer` (the cleanup chain), with a `#multithread` loop, and every program with `try`/`catch` are left alone. A second part removes the moves that are left (`mov x0, x19 / mov x10, x0` becomes `mov x10, x19`, `cmp` on registers, `add x20, x10, x0`) after finding out that the register is not needed afterwards by following the code. Test `t265`.
* Measured (ms, `clang -O2` in brackets): `fib(35)` 105 -> 99 (65), 300 million `s = s + i % 7` 881 -> 767 (200), a sieve of 5 million 143 -> 98 (79), a 200 x 200 matrix product 85 -> 62 (28).

## 0.9.55
* **`jcmp -space` is the pixel picture now** (colour, half-block pixels). The compiler looks at the terminal (`COLORTERM=truecolor` or `24bit`) and, if there is no 24-bit colour, shows the ASCII picture instead. `jcmp -space ascii` forces the characters, `jcmp -space pxg` gives white, grey and black pixels; a speed number can follow.
* The J is a little smaller and has the colour of the Moon; the orbit line is gone: only the Earth and the Moon (and the stars) are left.

## 0.9.54
* **The mascot in pixels (two ways to compare):** `jcmp -space px` draws it with half-block pixels in colour (blue sea, green land, white clouds, warm city lights, a gold J, a blue air glow); `jcmp -space pxg` draws the same picture in white, grey and black. Plain `jcmp -space` is still the ASCII picture. A speed number can follow (`jcmp -space px 600`). Needs a terminal with 24-bit colour.

## 0.9.53
* **The mascot's Moon follows its phase:** at a full Moon there is no letter; as the Moon wanes or waxes the J fades in on the surface, and from a half Moon down to a thin crescent the Moon itself becomes the letter J (drawn flat, facing us, glowing).

## 0.9.52
* **`examples/solar.jk` is in colour now** and no longer dull: every ball is lit by the sun and has its own surface (continents, clouds and ice caps on the Earth, bands and the red spot on Jupiter, the rusty Mars, the grey Mercury and Moon, the cream clouds of Venus), the rings of Saturn go behind and in front of the ball, a sun with a limb and a corona, faint orbits, an asteroid belt, twinkling coloured stars, glow and vignette. It uses `Screen` (like the black hole) and takes the size of the terminal. Test `t242`.
* **The mascot (`jcmp -space`)** has an air glow round the lit edge of the Earth and the lights of the cities on its night side.

## 0.9.51
* **`str(x)`** makes a `String` from a number, a character, a `bool` or another String: `str(42)`, `str(-7)`, `str(2.5)`, `str(1.5e20)` (`1.5e+20`), `str('x')`, `str(true)`, an unsigned `u64` up to 18446744073709551615. Floating point numbers print with up to 15 significant digits and no zeros at the end. Test `t262`.
* **Any number of array parameters, in any place:** `int dot(int a[], int b[])`, `void scale(int a[], int k, int out[])` (before, one array parameter and it had to be the last). Methods too. Test `t263`.
* **`move(ps[i])` on an element of an array** of a struct that frees itself: the element goes to a new owner and the array slot is emptied (`Person t = move(ps[1]);`). Test `t264`.
* **Fixed:** a local array of structs that free themselves now starts as zeros, so `ps[0] = make(...)` no longer frees garbage.

## 0.9.50.1
* **Docs:** the status tables of `README.md` and `README.th.md` (they still said that dynamic arrays, `cin` and threads were missing) and a section "The standard library at a glance" in `docs/LANGUAGE.md` now describe what the language and the libraries really have.

## 0.9.50
* **Two functions with the same name are an error** ("this function is defined twice"). Before, the second one silently replaced the first, which hid a fault in 0.9.49 (a new library function got the name of an old one and three tests failed). Test `t261`.
* Faster `x += e`, `x -= e`, ... on a plain variable: the peephole pass makes the six lines into four (300 million `s = s + i % 7`: 1030 -> 882 ms).

## 0.9.49
* **Strings can be ordered:** `a < b`, `a > b`, `a <= b`, `a >= b` on a `String`, a text, or a mix (by the codes of the bytes, like `strcmp`; a capital letter comes before a small one, `"é"` after `"z"`). Sorting a `String[]` with `<` works (test `t256`).
* **Fixed:** `@name` where `name` is a variable bound in a `switch` to a struct that frees itself (`Result::Ok(doc)`) is now the pointer to that struct (before, the address of the binding itself); so `total(@doc, ...)` works.
* The trace of a panic shows library names without the leading underscores (`Arr::nullerr`, was `::Arr::nullerr`).
* **Four larger test programs** whose output was checked against Python (8 queens and the longest Collatz chain, word counts and text functions, numerical integration and a determinant, generics with JSON and exceptions): `t257` - `t260`.

## 0.9.48
* **Fixed (an old fault):** a loop `for i in lo..hi` with a **variable** at the start of the range did not compile ("this value has no fields"), only a number worked (`for i in 0..hi`). `for i in lo..hi`, `for i in lo + 1..hi + 1`, `for i in 0 - r..r` work now (test `t255`).
* **gfx, drawing and effects on `Screen`:** `line` (Bresenham), `rect`, `fill_rect`, `circle`, `fill_circle`, `blend` (mix a colour into a dot), `gradient_v`; effects on the whole picture: `vignette`, `scanlines`, `brightness`, `invert`; `lit()` counts the dots that are not black. Checked by counting (a diagonal of 20 dots, a rectangle of 24, a filled circle of radius 5 of 81 dots, a circle border of 28).

## 0.9.47
* **More of the math library** (parts chosen as before with `using math::NAME;`; `using math;` takes all): **`quat`** (rotations as quaternions: `quat::from_axis_angle`, the product `q * r` (turn by `r`, then by `q`), `conj`, `normalize`, `rotate(vec3)`, `slerp`), **`complex`** (`cplx`: `+ - * /`, `-z`, `==`, `conj`, `abs`, `arg`, `exp`, `powi`, `from_polar`) and **`stats`** (`Stats::sum mean min max variance stddev median` on a `double[]`). Checked by hand: a quarter turn about y turns (1, 0, 0) into (0, 0, -1), (1 + 2i)(3 - i) = 5 + 5i, e^(i pi) = -1, (1 + i)^4 = -4.

## 0.9.46
* **Fixed (an old fault):** an index that contains `.len`, like `a[a.len - 1]`, gave the address of the element instead of the element (for a String, a `T[]`, and a fixed array): the `len` inside the index left the "finished" mark of the outer lvalue on. `v[v.len - 1]`, `s[s.len - 1]` and `m[m.len - 1][2]` work now (test `t252`).
* **Standard library:** `Path` (`join name parent ext stem`), `Hex` (`encode`, `decode` as a `Result`) and `Base64` (`encode`, `decode` as a `Result`), checked against `base64` and `xxd`.
* A clearer message when `self` is used in a method that does not have it as its first parameter (`int name(self) { ... }`).

## 0.9.45
* **Faster code, second step:** a **peephole pass** (`jcmp/jc_peep.j`, `-nopeep` switches it off) shortens the assembler text of the whole program: a store followed by a load of the same place, a push that is popped at once, `mov x1, N` + `add/sub/cmp`, a comparison used as a condition (`cmp` + one conditional branch instead of making 0 or 1 and testing it), a jump to the next line, a store with its address worked out first, and the left operand that waited in a register. **Loops** have a better shape: the condition at the bottom (`for i in a..b` and the C form), one jump a turn instead of three. **Array elements**: the index is worked out first and the base address is added after (no push), a power-of-two element size is a shift; the **address of the target of an assignment** waits in a register when the right side has no call. A division by a literal does not load the divisor any more.
* Measured (ms, best of 3; `clang -O2` in brackets): `fib(35)` 211 -> 93 (71), 300 million `s = s + i % 7` 1554 -> 1030 (232), a sieve of 5 million 276 -> 144 (72), a 200 x 200 matrix product 130 -> 80 (28).

## 0.9.44
* **Faster code (first step of the speed work):** the left operand of a binary operator no longer goes through the stack when the right operand is made of plain numbers and variables: it waits in a register (`x10`..`x14`), and a right operand that is one number or one variable is loaded straight into `x1`; a variable is read with one instruction (`ldr x0, [x29, #N]`, not an address and a load); assigning to a plain variable no longer pushes its address; `/` and `%` by a whole-number literal use a multiplication (`smulh`) and a shift instead of the slow `sdiv` (checked against `sdiv` on 164 000 values, edges of 64 bits included). New instructions in the assembler: `msub`, `madd`, `smulh`, and `lsl/lsr/asr` with a number.
* Measured against `clang` on this phone (best of 3, ms): `fib(35)` 211 -> 136, a loop of 300 million `s = s + i % 7` 1554 -> 1105, a sieve of 5 million 276 -> 186, a 200 x 200 matrix product 130 -> 89 (`clang -O2`: 71, 232, 72, 28). The programs are in `tools/bench` (private).
* The results are the same as before: a test with many forms of expressions (precedence, calls with side effects in operands, floats, chars, arrays) must give the same output as the old compiler.

## 0.9.43
* **A call can go on after a value in parentheses:** `(a + b).dot(c)`, `(s + t).len`, `(u * 2.0).z`, `(a + b).length()`.
* **`-v` on a struct** calls its `operator ... neg(self)`; `vec2/3/4` have it.
* **`2.0 * v`** is the same as `v.mul(2.0)` (a number on the left of `*` and a struct on the right); a number on the left of `/` is still an error that says so.
* Docs: a section on operator methods and the math libraries in `docs/LANGUAGE.md`.

## 0.9.42
* **The mascot is real ASCII art:** the shading uses a rich ramp of 66 different characters, letters and signs, from light to dense (`.'`^",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$`), not only a few dots; and the **edges** of the Earth and the Moon are drawn with characters that follow the line, chosen by which quarters of the cell the shape covers: the right limb of a ball is `)`, the left `(`, the top `"`, the bottom `_`, the diagonals `/` and `\`.

## 0.9.41
* **The mascot is smoother and more real:** four rays for every character (2 x 2, averaged) so that the edges of the Earth and the Moon and the steps of light are smooth; a **dither** (a fine 4 x 4 pattern of Bayer) chooses between the two nearest characters of the ramp, so a slow change of light looks like a smooth gradient; the edge between day and night is soft; the Earth has **lands with shores, clouds that drift faster than the ground**, ice at the poles and a bright spot of the Sun on the sea; the Moon has **craters** (a darker floor, a lighter rim) besides its dark seas.

## 0.9.40
* **The mascot (`jcmp -space`) redone as asked:** the **Earth** in the middle (a ball with sea, lands, ice at the poles, turning on its axis), the **Moon** going round it and **the letter J on the Moon**: the J is raised from the Moon's surface and turns with the Moon about the Moon's own axis (a turn in 40 s of the film; there is a J on the front and one on the back so that one of them is always turned to us; the J glows a little, like a logo, even where the Sun does not light the Moon). The shading is the ramp ` .:-=+*#%@` by the angle between the surface and a **fixed Sun** (from the left and the front); what the Sun does not light is left black, so the Moon shows its phases.
* **Slower:** the default is `1 s = 30 min` of real time (x1800; before x7200); the Earth turns in 48 s, the Moon goes through its phases in 23.6 minutes; `jcmp -space N` sets N. The Moon starts where the **real Moon is now** (its phase is computed from the clock of the computer: a new moon was on 2000-01-06 18:14 UTC, the month is 29.530588853 days) and the **real UTC clock and date** are shown, next to how much time has passed in the film.
* **The lines under the picture:** the real time, the time scale (`1 s = 30.0 min (x1800)`, the turn of the Earth, the cycle of the Moon in the film), the phase of the Moon and the real light times (Sun 8 min 19 s, Moon 1.28 s), and the **scale** of the picture (`1 row = 855 km`; the Moon is drawn at 1.70 Earth radii with the radius 0.62, real 60 and 0.27, so that it fits and the J can be read).
* **Sizes:** 50 x 20 characters, or finer in a bigger terminal: 60 x 24 (62 columns, 29 rows), 76 x 30 (78 x 35), 100 x 40 (104 x 46); zoom the terminal out (smaller letters) to get a bigger picture.

## 0.9.39
* **Finer picture where the terminal is big enough:** the mascot is 50 x 20 characters in a small terminal, **60 x 24** from 62 columns and 28 rows, and **76 x 30** from 78 columns and 34 rows. The globe and the Moon are the same size compared with the picture, but every character is smaller, so there is more detail.
* **The Moon is made of digits** (`1 7 3 5 2 9 6 0 8 @`), the Earth of letters, so that they can be told at a glance, and the word `MOON` stands under the Moon. **What the Sun does not light is left black**: a crescent or a half moon shows only the lit part (no earthshine and no rim on the dark side).

## 0.9.38
* **The Earth is fuller and the Moon easy to see:** the shading uses a ramp of letters only (`. : - + c v u n x z X Y U J C L Q 0 O Z m w q p d b k h a o M W & 8 % B @ $ #`, no thin punctuation) and a curve that lifts the middle tones; the sea and its lines are brighter, the grey of the characters starts higher, there is more light on the night side. The Moon is bigger (radius 0.40 of the Earth's, a little more than real 0.27, still not to scale), brighter, its dark side shows the light of the Earth, and its edge is lined so that the whole disc can be seen even as a crescent.
* The lines under the picture are shorter (`x7200  Earth 11.9 s  Moon 5.4 min`, `UTC 14:29:23  +27.7 min`).

## 0.9.37
* **The mascot (`jcmp -space`) is the Earth with the Moon, with real times.** The ring is gone. The Earth (with the letter J raised on it, in black, white and grey) **turns on its axis** (west to east, the axis leans its real 23.44 degrees) and **goes round the Sun**, and the **Moon** goes round the Earth (its orbit leans 5.14 degrees) and **shows its phases**: new, crescent, half (quarter), gibbous, full, waxing or waning, from the real angle between the Sun and the Moon. When the J turns to the far side only the plain globe is seen; on the night side it is dark. The Moon and the Earth throw shadows on each other (eclipses). The times are real: one turn of the Earth 23.93 h (86 164.1 s), one turn of the Moon 27.32 days, one year 365.26 days; the film is `N` times faster than real time (`jcmp -space N`, default 7200: the Earth turns in 12 s, the Moon in 5.4 min) and the lines under the picture say the times for this speed, the Earth time (UTC clock and how much time has passed in the film), the phase of the Moon and the real **time the light needs**: Sun to Earth 499 s (8 min 19 s, from 149 597 870.7 km / 299 792.458 km/s), Moon to Earth 1.28 s; the Sun that lights the Earth is where it was 499 s before. The Moon is drawn nearer and a little bigger than real (not to scale) so that it fits.

## 0.9.36
* **The mascot is a globe with the letter J on it** (the J as the world), in **black, white and grey only** (no more orange): a ball shaded with the sun on one side and a grey night on the other, with fine lines of latitude and longitude, a white letter J raised from the surface (the shading bends at the edges of the letter so that it stands out), a glow at the rim, a spot of reflected light on the sea. The sun goes slowly round the globe so the light and the shadow move over the J; the globe rocks a little so that the letter seems to be on its surface. A thin ring leans round it like the axis of the Earth (23.44 degrees); its gas goes round with Kepler's law and the real mass of the Earth (GM = 398 600 km^3/s^2, 1.2415e-3 rad/s at the surface, 1500 times faster in the film), the globe throws its shadow on the ring and the ring on the globe, and the sun glints on it here and there in whitish grey. Without a 24-bit colour terminal it is plain characters.
* Less clutter than 0.9.35: no belts, small moons or ringlets.

## 0.9.35
* **Fixed (serious, my mistake in the release of 0.9.34):** the source of 0.9.34 on GitHub had a half-written change in `jcmp/jc_logo.j` and could not be compiled (the released binary `jcmp` was fine). This release has a source that builds (`./bootstrap.sh` passes) and the finished change: 
* **The mascot, more detail:** the J hangs lower, so that the plane of the rings crosses its upper part and its tail shows below; finer shading with a long ramp of 68 characters; belts of clouds on the planet that turn with it; fine ringlets in the rings, the thin F ring and the Encke gap; three small moons that run beside the rings at their real distances (Prometheus, Pandora, Janus) with Kepler speeds; **shadows are grey** (the night side, the shadow of the rings and of the planet), and the sun **glints on the rings** here and there in whitish grey.

## 0.9.34
* **The mascot is 50 x 20 characters** and shows **Earth time** under the picture: the clock of the computer now (UTC, `HH:MM:SS`) and how many hours have passed on the planet in the film (`film = 12.4 h`, from the speed N).

## 0.9.33
* **The mascot looks like a lit planet:** with a 24-bit colour terminal (`COLORTERM=truecolor`, as in Termux) the characters get colours: the J has a day side (warm gold), a night side (dark blue) with a soft edge between, a bluish glow at its rim where the atmosphere is seen edge-on, and a small bright spot of reflected light; the rings are sand-coloured (the C ring greyer); the shadow cast by the rings and by the planet is bluish dark; stars are pale blue-white. Without that variable it stays plain characters.
* **`jcmp -space N`:** N is how many times faster than real time the planet and rings go (default 1500; 4000 was too fast to read the letter). The line under the picture says it. Saturn's real ring radii, Kepler speeds from its real mass, its 10.56 hour day and its 26.73 degree tilt are used at any speed.

## 0.9.32
* **The mascot with real physics (Saturn's numbers):** the rings have their real radii (C ring 74 658 - 92 000 km, B ring to 117 580 km, the Cassini division to 122 170 km, A ring to 136 775 km, the planet 60 268 km) and their gas goes round with Kepler's law and Saturn's real mass (GM = 3.793e7 km^3/s^2: omega = 4.16e-4 rad/s at one planet radius, falling with radius^-1.5). The planet turns once in its real 10.56 hours, and its axis leans its real 26.73 degrees. The film runs 4000 times faster than real time (written under the picture). The view does not swing any more: all the motion is real motion, so the J turns as the planet does.
* Array lists (`double a[3] = {1.0, 2.0, 3.0};`) are confirmed by the owner (docs/syntax-design.md section 56).

## 0.9.31
* **The mascot is Saturn:** the solid J is the planet; it has rings like Saturn's (a faint inner ring, a bright broad ring, a dark gap, an outer ring) whose gas goes round by Kepler's law (the inner part is faster, in clumps that move from left to right in front). Light and shadow: the J is lit from above, the rings throw a shadow on the lower part of the J, and the J throws its shadow on the rings. The view swings and breathes with two slow motions that do not repeat together, so the turning no longer looks stiff.

## 0.9.30
* **The mascot (`jcmp -space`) in 3D (isometric):** a solid J (an extruded letter) seen from above at the isometric angle, lit from above so that its top faces, front and sides get different characters (`.:-=+*#%@`), with four small balls that go round it on dotted ellipses by Kepler's laws (the J is at a focus; a ball is faster near the J; period ~ radius^1.5). The view turns a little to and fro, which makes the picture look solid; the J and the balls hide the orbit dots behind them. Every character is one ray into the scene (ray marching with distance functions), written in J2K inside the compiler.
## 0.9.29
* **The mascot (`jcmp -space`) like Saturn:** the J is the planet and four thin rings (with a gap, like Saturn's) lean 45 degrees round it, a little slanted. The ring stays where it is; its gas goes round, the inner rings faster, as clumps of brighter characters. A cleaner, slimmer J with a hook that curls up. Under the picture: `created by J2k-studio`, and how to stop.

## 0.9.28
* **The mascot:** `jcmp -space` shows the J2K logo in ASCII style until you press Ctrl-C or Enter: a J drawn with shaded characters (`.:-=+*#%@`) and a soft halo, a ring that leans 45 degrees and turns round it (in front of and behind the letter), twinkling stars, 24 frames a second. It reads the size of the terminal first and shows a small picture (48 x 18 characters) in the middle. It is written in J2K inside the compiler without any library (`jcmp/jc_logo.j`). `-spcae` and `-speac` do the same; it is not listed in `-help`. Plain characters: it works in any terminal (at least 50 x 20).
## 0.9.27
* **Example `examples/logo.jk`:** the J2K logo: a glowing J, a ring tilted 45 degrees that turns around it (with two beads running on it), twinkling stars, 24 frames a second (paced by the clock). Small and of a fixed size (64 x 40 dots, about 25 KB of memory).
* `Screen.add(x, y, r, g, b)` adds light to a dot.

## 0.9.26
* **Array lists:** `double dist[3] = {12.0, 18.0, 25.0};`, `int primes[] = {2, 3, 5};` (size counted), also for global arrays (constants). Values not given are zero. One dimension, not structs yet (docs/syntax-design.md section 56, waiting for the owner's confirmation of the form).
* **Colour in gfx:** `using gfx::screen;` gives `Screen::make(w, h)`: a picture of rgb dots (`set`, `set_packed`, `get`, `clear`, `glow` = bloom, `frame`, `show`, `begin`, `end`); two dots in each character cell with 24-bit colour codes. `Screen::rgb(r, g, b)` packs a colour. `using gfx::canvas;` still gives the character `Canvas`; `using gfx;` gives both.
* **Terminal (stdlib):** `Term::cols()`, `Term::rows()`, `Term::key_pressed()` (a line + Enter typed; nothing is waited for and the terminal is not changed). The examples stop on Ctrl-C or Enter.
* **Examples:** `examples/blackhole.jk` is the colour version (hot red-orange gas, bluer where it comes towards us, the thin blue ring of light that went round the hole, glow, stars; it takes the size of the terminal); the character version is `examples/blackhole_ascii.jk`. `Math::min_int`, `Math::max_int`.
* **Docs:** conditions have no parentheses and `{` ends them (no ambiguity); array lists.
* **Housekeeping:** `ship.sh` refuses to release while untracked files lie in the folder (a binary and private files had been committed by mistake in 0.9.20 - 0.9.25).

## 0.9.25
* **Examples run until Ctrl-C** when no number of frames is given (`solar`, `blackhole`; `solar 300` stops after 300 frames). Before, they stopped by themselves after a fixed number of frames.
* **Solar system:** every orbit fits the screen; planets move on ellipses by Kepler's law and are lit by the sun (the side away from the sun is dark); moons, the ring of Saturn, an asteroid belt, twinkling stars.
* **Black hole:** the disk is hotter inside (T ~ r^-3/4), turns faster inside, the side that comes towards us is brighter (Doppler boost) and light that climbs out of the hole loses energy; two rays per character smooth the edges; the view nods slowly.
* **gfx:** `Canvas.ball_lit(centre, radius, ramp, to_light)` lights a ball from a given direction; the shadow side still shows the faintest character.

## 0.9.24
* **gfx library:** `#import <gfx>` once, then `using gfx::canvas;` (loads `math::vector` too). `Canvas::make(w, h)`, `clear`, `put`, `get`, `text`, `plot(vec3, char)` (perspective, nearest wins), `line`, `ball(centre, radius, ramp)` (shaded ball), `frame`, `show`, `clear_screen`, `free`. Fields `view` and `wide` set the perspective and the character shape.
* **Examples:** `examples/solar.jk` is shorter with the Canvas; new `examples/blackhole.jk`: every character follows a ray of light bent by gravity (the disk around the hole shows up bent over the top).

## 0.9.23
* **Example `examples/solar.jk`:** an animated ASCII solar system (sun, five planets, orbits, shading, perspective, z-buffer) written with `vec3`, `mat3` and operators. Run: `jcmp examples/solar.jk -o solar && ./solar` (needs a terminal of 100 x 37).

## 0.9.22
* **`vec`:** `vec pos = {1.0, 2.0, 3.0};` is a `vec3` (the number of values says which: 2, 3 or 4). Elsewhere (parameters, fields, results) write `vec2`, `vec3`, `vec4`.
* **Swizzle:** `v.xy`, `v.zyx`, `v.xxyy`, `c.rgb` make a new vector from some components of a `vec2/3/4` (letters of `xyzw` or of `rgba`, not mixed); a single letter (`v.r`, `v.y`) is the component itself and can be assigned. A swizzle with several letters is read only.

## 0.9.21
* **JSON (stdlib):** `Json::parse(text)` gives a `Result<JsonDoc, Error>` (an error says what and at which byte); a `JsonDoc` is a table of nodes (a node is a number, -1 = none): `root get at len has name_of text number integer boolean is_null kind_of dump`. `Json::quote(s)` and `Json::num_text(x)` make JSON text. Strings are decoded (`\n`, `\u00e9`, surrogate pairs to UTF-8).
* **Fixed:** a data enum member with a parameter named `s` (`Name(String s)`) clashed with a name made by the compiler.
* **Fixed:** `return v;` of a name bound in a case to a struct that frees itself (for example `Result<JsonDoc, Error>::unwrap`) is a move now: the struct is copied out and the enum's copy is emptied. Before, `Result<T, E>` with such a `T` did not compile.
* Warnings about passing a large struct by value are not given for generic instances.

## 0.9.20
* **Operator methods:** a struct method declared with the word `operator` can be used with an operator: `+` calls `add`, `-` calls `sub`, `*` calls `mul`, `/` calls `div`, `==` / `!=` call `eq`; `a += b` (also `-= *= /=`) is `a = a.add(b)`. Example: `operator vec3 add(self, vec3 o) { ... }`, then `p = a + b * 2.0;`. A struct on the left only (`v * 2.0`); `2.0 * v` is an error that says so. A method without `operator` is never called by an operator.
* **Renamed:** the math types are `vec2 vec3 vec4 mat3 mat4` (lower case), and their `add sub mul div eq` are operators.

## 0.9.19
* **One import for the math library:** `#import <math>` once, then `using math::vector;`, `using math::matrix;` or `using math;` choose the parts (only those are compiled in). This replaces `#import <vector>` / `#import <matrix>` of 0.9.18.

## 0.9.18
* **Math libraries:** `#import <vector>` gives `Vec2`, `Vec3`, `Vec4` (make, zero, splat, add, sub, mul, div, neg, dot, cross, length, distance, normalize, lerp, min, max, abs, reflect, eq); `#import <matrix>` gives `Mat3`, `Mat4` (identity, scale, rotate_x/y/z, mul, mul_vec, transpose, and for `Mat4` translate, point, direction, project, perspective, look_at). Operators (`a + b`, `pos += vel * dt`) and swizzle come later (docs/syntax-design.md section 55).
* Warnings inside the built-in libraries are no longer shown to the user.

## 0.9.17
* **`Sha256`:** `Sha256::hex(text)` and `Sha256::file(path)` (a `Result`) give the SHA-256 digest as 64 hex digits. Checked against `sha256sum`, also on a 1 MB binary.

## 0.9.16
* **`Proc`:** `Proc::run(cmd, args)` runs a program and returns its exit code; `Proc::output(cmd, args)` returns what it printed. The program is looked for in `PATH` unless its name has a `/`; 127 means it could not be started.

## 0.9.15
* **UTF-8 text:** `s.count()` (characters), `s.chars()` (a `String[]`, one character each), `s.char_at(i)`; `upper()` / `lower()` handle Latin-1, Latin Extended-A, Greek and Cyrillic. `len` still counts bytes.

## 0.9.14
* **`Num::parse_int(s)` / `Num::parse_double(s)`** return a `Result<…, Error>` (kind `Parse`) instead of throwing, so `int n = Num::parse_int(s)?;` works.

## 0.9.13
* **A panic prints where it happened:** after `panic: <what>` the running functions follow, innermost first (`  at inner`, `  at outer`, `  at main`; methods as `Type::name`).
* **`using enum` works for data enums:** after `using enum Shape`, `switch` can use the short member names (`Circle(r):`).
* The limit of structs in one program is 256 (was 80).
* New in the assembler/compiler: `.quad`, `.asciz`, and the built-in `__fp()` / `__fntab()` (used by the trace).

## 0.9.12.1
* **Methods and `.len` on any String / array expression:** `"  text ".trim().len`, `s.trim().upper()`, `Env::args().len`, `words().join("+")`, `"MiXed".upper()` (before, only on variables and on the result of a call).
* A moved value that is used again by a method call (`b = a; a.len()`) gets the `-Wmoved` warning, like a plain read.

## 0.9.12
* **`Math` is complete:** `exp log log2 log10 pow sin cos tan asin acos atan atan2 sinh cosh tanh cbrt hypot fmod round sign clamp lerp radians degrees pi tau e inf nan is_nan is_inf powi from_bits to_bits`. Checked against known values to 12 digits.
* **Changed:** `Math::pow(x, y)` takes two decimals (like C). The old `pow(x, n)` with a whole-number exponent is now `Math::powi(x, n)` (and fast: by squaring, negative n allowed).
* **Fixed:** a decimal literal with an exponent beyond 18 (for example `0.00004539992976248485`, which is 4539992976248485e-20) gave a wrong value; it is exact now (to e22).
* **Fixed:** a forward call that returns a decimal could not be mixed with a decimal in an expression (`0.0 - f()` with `f` written later).

## 0.9.11
* **Fixed (serious):** names of functions longer than 23 characters were cut short by the assembler, so two functions whose names start the same way (for example `Result__String___Error__Ok` and `...__free`) could be taken for one. Names up to 63 characters are exact now (a longer one is an error).
* **Standard library:** `Fs` (read_text, read_lines, write_text, append_text, exists, size, remove, rename), `Dir` (exists, make, make_all, remove, list, current), `Env` (get, args), `Time` (now_ms, mono_ns, sleep_ms), `Random` (seed, next, range, unit).
* The value a call returns is looked at directly: `Env::get("HOME").is_some()`, `f().trim()`. A value that frees itself and is not used is freed at the end of the statement.
* `(Name::call() + 1)` in parentheses is not mistaken for a cast; `(char^)p` is a text.

## 0.9.10
* **Bugs are panics:** dividing by zero, a null/freed array or String, a position out of range, `pop` of an empty list, `unwrap` of `None`/`Err`, a function that ends without `return`, no memory: `panic: <what>` and exit code 134; `try`/`catch` cannot catch them. New: `panic("text")`, `assert(condition, "text")` (std), `Map.try_get(k)` (an `Option`).

## 0.9.9
* **`defer`:** `defer statement;` / `defer { ... }` runs when the block is left (end, `return`, `break`, `continue`, or a `throw` passing through), last defer first, with the variables as they are then.

## 0.9.8
* **`Option<T>` and `Result<T, E>`** (std) with the standard `Error` (`kind`, `message`) and **`expr?`**: an `Err` / `None` returns from the function at once, the content of an `Ok` / `Some` is the value. Methods `is_ok is_err is_some is_none unwrap or`.
* **Values that free themselves are moved:** a struct with `free(self)` (and a data enum that holds a String, an array or such a struct) is moved by `=`, by a by-value parameter and by `return`; a fresh value from a call is taken over.
* In a `switch` a member that frees itself is named by a pointer. The cleanup of a `throw` and the end of a function also free the parameters of that kind.

## 0.9.7
* **Enums that carry values:** `enum class Shape { Circle(double r), Rect(double w, double h), Empty; ...methods };`, built with `Shape::Rect(2.0, 3.0)`, taken apart with `switch s { Shape::Rect(w, h): ... }`. They can be generic (`enum class Maybe<T> { Some(T value), Nothing }`). The first step of the error model (`Option`, `Result`, `?` follow).

## 0.9.6
* **More String methods:** `trim`, `upper`, `lower`, `replace`, `repeat`, `starts_with`, `ends_with`, `contains`, `to_int`, `to_double`, `split` (gives a `String[]`) and `join` on a `String[]`.

## 0.9.5
* **Where the program goes:** `jcmp sub/test.jk -o sub/` (or `-o sub` when `sub` is a folder) writes `sub/test`; `jcmp test.jk sub/test` also names the program (a second name that ends in `.jasm` still means only the assembler text).

## 0.9.4
* **`-o` is optional:** `jcmp test.jk` writes the program `test` (the name of the source without `.jk` / `.j`, in the current folder). `-o name` still chooses the name.

## 0.9.3
* **A missing `;` is reported where it is missing:** `expected ';' at the end of line 4 (it is missing there)` with the `^` right after the last token of that line (before, the message pointed at the next line and talked about `<<`).
* **A program file that cannot be written has a clear message:** `cannot write the program file 'test' (a folder with that name, a program that is running, or no permission?)` (before: `j2k_asm: error at line 155 ... parse or I/O error`).

## 0.9.2
* **A generic function finds its types from the arguments:** `largest(3, 9)`, `swap(@x, @y)`, `first(names)`. Numbers, chars, texts, variables, `@variable` and arrays are understood; anything else, a mix of types (`largest(1, 2.5)`) or a `T` that no parameter shows must be written with `<type>`. A struct (`Box<int>`) is still always written.

## 0.9.1
* **A lambda is written like a function without a name** (the way functions are declared: result type first, no `->`): `int(int a, int b) { return a + b; }`, `void() { ... }`. The form of 0.9.0, `(int a, int b) -> int { ... }`, still works with a warning.

## 0.9.0
* **Lambdas:** a function without a name where you use it: `(int a, int b) -> int { return a + b; }`, `() -> void { ... }`. It gives a function pointer, so it can be passed to a function or kept in `int(int, int)^ f = ...;`. It cannot use the variables around it (a clear message says so).
* `->` is a token now.

## 0.8.1
* **A `throw` frees what the left functions owned:** arrays, Strings, `alloc` blocks, Strings made inside a statement and structs with `free(self)` are freed on the way to the `catch` (innermost first). Before, they leaked. Cost: about ten instructions when an owner is made.
* Warnings are bright yellow now (a fixed colour that does not depend on the terminal theme).

## 0.8.0
* **`#import`** (with the `#`, like `#define`): `#import <stdlib>`, `#import "file"`. A plain `import` still works with a warning `[-Wimport]`; a later version makes the `#` required.
* **`cout` and `cin` handle every type**, decimals included. `coutf` and `cinf` still work with a warning `[-Wdeprecated]`.
* **A function that must return a value but has no `return` at all is an error** (`make it void, or return something`). A path that reaches the end without `return` still throws at run time (0.7.1).
* New warnings: `-Wunused` (a local variable that is declared and never used).
* Removed the check "cout cannot print a float" (floats print with `cout` now).

## 0.7.1
* **A function that ends without `return`** (and returns a value) now throws `a function ended without returning a value` instead of giving a junk number. A normal `return` costs nothing extra. `main` without `return` still gives 0, as in C.
* A missing `<<` in `cout` (or `>>` in `cin`) is explained: `expected ';' or '<<' here (is a '<<' missing between two values?)`.

## 0.7.0
* **`import <library>`** for libraries and **`import "file"`** for your own files. A library is looked up in `-I`, `J2K_PATH`, `~/.j2k/lib` and the `lib` folder next to the compiler.
* **`std` is now `stdlib`:** `import <stdlib>`, `using stdlib`, `using stdlib::math`. `cpu` is `import <cpu>`. The old forms (`import std`, `using std`, a bare `import cpu`) still work with a warning (`[-Wdeprecated]`, `[-Wimport]`).

## 0.6.0
* **Collections:** `Map<K,V>` (`put get has remove len keys_list values_list`), `Set<T>` (`add has remove len items_list`) in the standard library; keys can be numbers, chars, pointers or Strings. `get` throws `key not found`.
* **`String[]`**: an array of Strings (it owns them). **List methods** on every dynamic array: `insert`, `remove`, `sort`, `contains`, `index_of`.
* **`for x in list { }`** over a dynamic array, a `String[]`, a String (its characters), a fixed array or a list returned by a call.
* **A struct with a method `free(self)` is freed by the compiler** at the end of the block of a local variable (also on `return`, `break`, `continue`). It starts zeroed and cannot be copied, passed or returned by value.
* Warnings are yellow (they were orange).

## 0.5.0
* **Names of the decimal types:** `float` (32 bit) and `double` (64 bit), as in C. `f32` and `f64` still work, with a warning `[-Wdeprecated]`.
* **`cout`, `coutf`, `cin`, `cinf` need `import std` and `using std`.** A program without them gets the warning `[-Wstd]` (a later version makes it an error). Update your programs: put `import std` and `using std` at the top.
* `using std` makes `Sys`, `Mem`, `Str`, `Math` and `File` usable without the prefix; a name that is in two of them (`write`) is an error that tells you to write `File::write`.

## 0.4.0
* **`String`**: text that grows. `String s = "hi";`, `a + b`, `a == b`, `s += x`, `s.len`, `s[i]`, `push pop append clear find slice c`, `cin >> s`. `String b = a;` makes a copy; Strings are freed at the end of their block, and a String made by an expression is freed at the end of the statement.
* **Generics** (since 0.3.1) are described in the tour (`docs/LANGUAGE.md`) and the tutorial (lessons 12 and 13).
* Functions that return `char^` (a text) can be printed with `cout`.

## 0.3.3
* **Fixed:** declaring a name twice in a block (or a local with the name of a global) reported the error at the *next* statement; it now points at the name that is declared again.

## 0.3.2
* **Division by zero throws** `"division by zero"` (catchable with `try`/`catch`) instead of silently giving 0. A literal divisor other than 0 costs nothing.
* **A crash tells why:** a null pointer or a stack overflow prints `runtime error: segmentation fault (null pointer or stack overflow)` and exits with 139.
* **New warning `-Wuninit`:** a variable declared without a value is read before anything was written to it.
* **Messages are easier to read:** errors in red, warnings in yellow (only when the output is a terminal; `-color` / `-nocolor` choose), and the source line has its line number: ` 12 | code` with a `^` under the place.

## 0.3.1
* **Fixed:** calling a function that does not exist (for example `alloc` without `import std` / `using std::mem`) ended with a message from the assembler; it is now `error: unknown function 'name'` at the call.
* **Fixed:** `cout << f()` printed a number when `f` returns `char`.
* The limit of structs is 80 (was 64); generic instances count. An error inside a generic instance points at the place of the use.
* **Generics**: `T max<T>(T a, T b)`, `struct Box<T>`, `struct Pair<A, B>`; the type is written at every use (`max<int>(1, 2)`, `Box<f64> b;`). A generic must be written before its first use.

## 0.3.0
* **Threads**: `import cpu` gives `Thread` (create, join, detach) and `Mutex` (futex based). Every thread has its own `try`/`catch` state and its own 1 MB stack; the heap (`alloc`/`free`) is safe to use from several threads.
* **`#multithread`** in front of `for i in a..b { ... }`: the iterations are shared among the CPU cores and the loop ends when all of them are done. `break`, `return` and a nested `#multithread` inside the body are errors.
* Built-in atomic helpers used by the library (`__cas`, `__xchg`, `__fetch_add`).

## 0.2.2
* The release files are named `jcmp` and `j2k_asm` (no more `-linux-arm64` in the name of the program); the bundle is still `jcmp-<version>-linux-arm64.tar.gz`. `install.sh` also installs older releases.
* New release file `jcmp.tar.gz` (only the program, with its executable bit): `curl -fL .../jcmp.tar.gz | tar xz -C ../bin`.
* `jcmp -version` and `jcmp -help` (one or two dashes: `-version`, `--version`, also `-v`, `-h`); the help is a short list of the options.

## 0.2.1
* Fixed: a character literal (`'J'`) that came after a decimal literal (`2.5`) was taken for a decimal number.
* New: a step-by-step tutorial, `docs/TUTORIAL.md` (and `docs/TUTORIAL.th.md` in Thai); every program in it is compiled and run.

## 0.2.0
* **Dynamic arrays**: `T[] x = arr(n)` with `len cap push pop resize clear free`, indexing (bounds-checked with `-d`), struct and pointer elements.
* **Memory that frees itself**: a local variable declared from `alloc(...)` / `arr(...)` is freed at the end of its block (also on `return`, `break`, `continue`); `move(p)`, warnings `-Wleak` and `-Wmoved`, and a leak report in `-d` builds.
* **Input**: `cin >> a >> b;` and `cinf >> x;` (the type of the variable decides what is read; bad input throws text).
* **Function pointers** (`int(int, int)^ op = add;`), unsigned types (`u8 u32 u64`), `sizeof`, `try`/`catch`/`throw`, `T^^`, 16 parameters, structs returned by methods.
* Smaller programs: functions that `main` cannot reach (most of `std`) are left out.
* `install.sh` options `--dir`, `--version`, `--with-assembler`.


## 0.1.0 — first release
* The compiler is written in J2K and compiles itself (self-hosting).
* One command from source to an ARM64 Linux executable (the assembler is built in).
* Language: `int i32 i8 u8 u32 u64 char bool f32 f64`, arrays (3 dimensions), pointers, `T^^`, function pointers,
  structs with methods, enums, `switch`, `for`/`while`, `try`/`catch`/`throw`, `sizeof`, `#define`, imports (`.j` components).
* Dynamic arrays `T[] x = arr(n)`; memory owned by local variables is freed automatically at the end of the block.
* Standard library: `Sys`, `Mem`, `Str`, `Math`, `File`.
* Messages like `file:line:col: error: ...` with the source line; warnings and `-st`; `-d` array bounds checks.
