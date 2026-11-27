// os 0.1.0 -- the upper layer of a machine without an operating system (a #target program, docs/BARE.md): Console, Pool and Heap.   #import <os>   using Console;
//
//   #target virt { entry 0x40000000; ram 0x40100000 1M; stack 64K; heap 256K; console 0x09000000; exit 0x09100000; }     (the #target line comes first in the file)
//   #import <os>
//   using Console;
//   fn main() {
//       line("hello");                                  // Console::line  (using Console; makes the name short)
//       i64^ a = (i64^)Heap::alloc(80);                 // zeroed, 16-byte aligned, or null; Heap::free(a) gives it back
//       Pool p;  p.init(TARGET_HEAP_START, 4096);       // blocks in a row, all given back at once (Pool::reset)
//       return 0;
//   }
//
// These are services that you may use instead of jout and alloc: they ask nobody and call nothing, so they work even when the lower layer (os_write, os_map ...)
// is not written yet, or in a program that must not use the runtime. Console writes to the console register of the target (nothing when there is none), Pool gives
// blocks in a row from a range and takes them all back, Heap is alloc and free from a range of your own.

char __console @ TARGET_CONSOLE;

struct Console {
    static fnv put(char c) { if TARGET_CONSOLE != 0 { __console = c; } }

    static fnv print(char^ s) {
        i64 i = 0;
        while s[i] != 0 { Console::put(s[i]); i += 1; }
    }

    static fnv line(char^ s) {
        Console::print(s);
        Console::put(10);
    }

    // a whole number in decimal (a minus sign for a negative one)
    static fnv num(i64 n) {
        if n < 0 {
            Console::put('-');
            if n == (1 << 63) { Console::print("9223372036854775808"); return; }
            n = 0 - n;
        }
        Console::unum(n);
    }

    static fnv unum(i64 n) {
        if n >= 10 { Console::unum(n / 10); }
        Console::put((char)(48 + n % 10));
    }

    // the number in hexadecimal with 0x in front (the digits of the value only, 0x0 for 0)
    static fnv hex(i64 v) {
        Console::put('0');
        Console::put('x');
        bool started = false;
        i64 shift = 60;
        while shift >= 0 {
            i64 d = (v >> shift) & 15;
            if d != 0 || started || shift == 0 {
                started = true;
                if d < 10 { Console::put((char)(48 + d)); } else { Console::put((char)(87 + d)); }
            }
            shift -= 4;
        }
    }
}

struct Pool {
    i64 base;
    i64 size;
    i64 used;

    fnv init(self, i64 start, i64 bytes) {
        self.base = start;
        self.size = bytes;
        self.used = 0;
    }

    void^ take(self, i64 bytes) {
        i64 n = (bytes + 7) / 8 * 8;
        if self.used + n > self.size { return null; }
        i64^ p = (i64^)(self.base + self.used);
        i64 w = 0;
        while w < n / 8 { p[w] = 0; w += 1; }
        self.used += n;
        return (void^)p;
    }

    fnv reset(self) { self.used = 0; }

    i64 left(self) { return self.size - self.used; }
}

i64 __heap_first;
i64 __heap_end;

struct Heap {
    static fnv init(i64 start, i64 bytes) {
        start = (start + 15) / 16 * 16;
        bytes = bytes / 16 * 16;
        if bytes < 32 { __heap_first = 0; __heap_end = 0; return; }
        __heap_first = start;
        __heap_end = start + bytes;
        i64^ h = (i64^)start;
        h[0] = bytes - 16;
        h[1] = 0;
    }

    static fnv ensure() {
        if __heap_first == 0 { Heap::init(TARGET_HEAP_START, TARGET_HEAP_SIZE); }
    }

    static void^ alloc(i64 n) {
        Heap::ensure();
        if __heap_first == 0 { return null; }
        n = (n + 15) / 16 * 16;
        if n == 0 { n = 16; }
        i64 at = __heap_first;
        while at < __heap_end {
            i64^ h = (i64^)at;
            i64 size = h[0];
            if h[1] == 0 && size >= n {
                if size >= n + 32 {                       // cut the rest into a free block of its own
                    i64^ rest = (i64^)(at + 16 + n);
                    rest[0] = size - n - 16;
                    rest[1] = 0;
                    h[0] = n;
                }
                h[1] = 1;
                i64^ p = (i64^)(at + 16);
                i64 w = 0;
                while w < h[0] / 8 { p[w] = 0; w += 1; }
                return (void^)p;
            }
            at = at + 16 + size;
        }
        return null;
    }

    static fnv free(void^ p) {
        if p == null || __heap_first == 0 { return; }
        i64^ h = (i64^)((i64)p - 16);
        h[1] = 0;
        // neighbours that are free join: one pass over the blocks
        i64 at = __heap_first;
        while at < __heap_end {
            i64^ a = (i64^)at;
            i64 next = at + 16 + a[0];
            if a[1] == 0 && next < __heap_end {
                i64^ b = (i64^)next;
                if b[1] == 0 {
                    a[0] = a[0] + 16 + b[0];
                    continue;
                }
            }
            at = next;
        }
    }

    // the bytes that can still be taken, in all the free blocks together
    static i64 left() {
        Heap::ensure();
        i64 total = 0;
        i64 at = __heap_first;
        while __heap_first != 0 && at < __heap_end {
            i64^ h = (i64^)at;
            if h[1] == 0 { total += h[0]; }
            at = at + 16 + h[0];
        }
        return total;
    }
}
