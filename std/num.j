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
