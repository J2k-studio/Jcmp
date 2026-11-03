# 1. The computer and the bit

**Everything in a computer is a number, and every number is a row of bits.** A bit is a wire that is off (0) or on (1). Eight bits make a byte, which can hold 256 different patterns, 0 to 255.

## Numbers
Binary counts like decimal, with two digits. `1011` is 1 x 8 + 0 x 4 + 1 x 2 + 1 x 1 = 11. Hexadecimal (base 16) writes four bits as one digit: `0xB` is `1011`, `0xFF` is `11111111`, 255.

```jk
#import <stdlib>
int main() {
    int n = 11;
    jout << n << " in binary is " << Fmt::bin(n) << " and in hex " << Fmt::hex(n) << "\n";
    jout << "255 is " << Fmt::bin(255) << "\n";
    jout << "1 << 10 is " << (1 << 10) << "\n";        // shifting left doubles: 2 to the power 10
    return 0;
}
```
A negative number is stored by the rule of **two's complement**: -1 is all ones. A real number (`double`) is stored as sign, exponent and fraction (IEEE 754): that is why `0.1 + 0.2` is not exactly 0.3. Lessons 76 to 78 of the tutorial show both with programs.

## Letters, colours, pictures
A letter is a number agreed by everyone: `A` is 65 in ASCII; Thai and emoji use UTF-8, where one letter takes one to four bytes. A colour is three numbers (red, green, blue), a byte each. A picture is a long row of such numbers. A sound is a row of numbers, 44100 of them every second. **The meaning is not in the bits; it is in the program that reads them.**

## Memory
The memory is a very long row of bytes, each with an address (a number). A variable is a place with an address; a pointer is a variable that holds an address. `int` takes 8 bytes in J2K; an array is bytes one after the other.

## Questions
1. How many different numbers fit in 10 bits? In 32 bits?
2. Why does a `float` (32 bits) show 7 good decimal digits and a `double` (64 bits) 15?
3. Write the number 200 in binary by hand, then check it with `Fmt::bin(200)`.
4. The three bytes `E0 B8 81` are one Thai letter in UTF-8. Which letter? (Look at `s.count()` and `s.len` of the same text in J2K.)
