// Option<T> and Result<T,E>: a value that may be missing, or an operation that may fail, as a value.
//   Option<int> a = Option<int>::Some(5);   Option<int> b = Option<int>::None;
//   Result<int, Error> r = parse(text);     int n = parse(text)?;      (? returns the error to the caller)
// switch takes a value apart:  switch r { Result::Ok(v): ...; Result::Err(e): ...; }

enum class ErrorKind { Other, NotFound, Denied, Invalid, Parse, Io };

// the usual error: what went wrong (kind) and a message
struct Error {
    ErrorKind kind;
    String message;
    static Error make(ErrorKind kind, String message) {
        Error e;
        e.kind = kind;
        e.message = message;
        return e;
    }
    void free(self) {
        self.message.free();
    }
};

enum class Option<T> { Some(T value), None;
    bool is_some(self) { return self.__tag == 0; }
    bool is_none(self) { return self.__tag == 1; }
    // the value (throws if there is none)
    T unwrap(self) {
        switch self^ {
            Option::Some(v): return v;
            Option::None: throw "unwrap of a None";
        }
        throw "unwrap of a None";
    }
    // the value, or fallback
    T or(self, T fallback) {
        switch self^ {
            Option::Some(v): return v;
            Option::None: return fallback;
        }
        return fallback;
    }
};

enum class Result<T, E> { Ok(T value), Err(E error);
    bool is_ok(self) { return self.__tag == 0; }
    bool is_err(self) { return self.__tag == 1; }
    // the value (throws if it is an error)
    T unwrap(self) {
        switch self^ {
            Result::Ok(v): return v;
            Result::Err(e): throw "unwrap of an Err";
        }
        throw "unwrap of an Err";
    }
    // the value, or fallback
    T or(self, T fallback) {
        switch self^ {
            Result::Ok(v): return v;
            Result::Err(e): return fallback;
        }
        return fallback;
    }
};
