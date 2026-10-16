// Num: conversions between numbers and text.
// text to numbers, as a Result (String.to_int() / to_double() throw instead)
struct Num {
    static Result<int, Error> parse_int(String s) {
        int v = 0;
        try { v = s.to_int(); } catch (e) {
            return Result<int, Error>::Err(Error::make(ErrorKind::Parse, "not a whole number: " + s));
        }
        return Result<int, Error>::Ok(v);
    }
    static Result<double, Error> parse_double(String s) {
        double v = 0.0;
        try { v = s.to_double(); } catch (e) {
            return Result<double, Error>::Err(Error::make(ErrorKind::Parse, "not a number: " + s));
        }
        return Result<double, Error>::Ok(v);
    }
}

// num: the short names (Num::num.parse_int(text), with  using Num;  num.parse_int(text)); a text that is not a number is thrown
struct __Num {
    static int parse_int(String s) { return Num::parse_int(s).take(); }
    static Result<int, Error> try_parse_int(String s) { return Num::parse_int(s); }
    static double parse_double(String s) { return Num::parse_double(s).take(); }
    static Result<double, Error> try_parse_double(String s) { return Num::parse_double(s); }
}
