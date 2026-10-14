// Net: TCP sockets (IPv4, addresses written as numbers: "127.0.0.1"; there is no name lookup).
//   server:  int l = Net::tcp_listen(8080)?;   int c = Net::accept(l)?;   String req = Net::recv(c, 4096)?;   Net::send(c, "hi")?;
//   client:  int s = Net::tcp_connect("127.0.0.1", 8080)?;   Net::send(s, "hello")?;   Net::close(s);
struct Net {
    static Error fail(String what, int e) {
        int code = e;
        if code < 0 { code = 0 - code; }
        ErrorKind k = ErrorKind::Io;
        if code == 111 || code == 113 || code == 110 { k = ErrorKind::NotFound; }
        if code == 13 || code == 1 { k = ErrorKind::Denied; }
        if code == 22 || code == 97 { k = ErrorKind::Invalid; }
        return Error::make(k, what + " (error " + str(code) + ")");
    }
    // the four numbers of "a.b.c.d" in a[0..3]; false when it is not an address
    static bool parse_ip(String s, int^ a) {
        int part = 0;
        int digits = 0;
        int n = 0;
        for i in 0..s.len + 1 {
            char c = 0;
            if i < s.len { c = s[i]; }
            if c >= '0' && c <= '9' {
                n = n * 10 + (c - '0');
                digits += 1;
                if n > 255 || digits > 3 { return false; }
            } else if c == '.' || i == s.len {
                if digits == 0 || part > 3 { return false; }
                a[part] = n;
                part += 1;
                n = 0;
                digits = 0;
            } else {
                return false;
            }
        }
        return part == 4;
    }
    // sockaddr_in in 16 bytes: family 2, the port and the address in network order
    static void make_addr(char^ sa, int a0, int a1, int a2, int a3, int port) {
        for i in 0..16 { sa[i] = 0; }
        sa[0] = 2;
        sa[2] = (char)((port >> 8) & 255);
        sa[3] = (char)(port & 255);
        sa[4] = (char)a0;
        sa[5] = (char)a1;
        sa[6] = (char)a2;
        sa[7] = (char)a3;
    }
    // a socket that listens on the port (0: the system picks one; Net::port_of tells which) on every address of this computer
    static Result<int, Error> tcp_listen(int port) {
        int fd = syscall(198, 2, 1, 0);
        if fd < 0 { return Result<int, Error>::Err(Net::fail("cannot make a socket", fd)); }
        int one = 1;
        syscall(208, fd, 1, 2, @one, 4);
        char sa[16];
        Net::make_addr(@sa, 0, 0, 0, 0, port);
        int r = syscall(200, fd, @sa, 16);
        if r < 0 {
            syscall(57, fd);
            return Result<int, Error>::Err(Net::fail("cannot use the port", r));
        }
        r = syscall(201, fd, 16);
        if r < 0 {
            syscall(57, fd);
            return Result<int, Error>::Err(Net::fail("cannot listen", r));
        }
        return Result<int, Error>::Ok(fd);
    }
    // the port that the socket is bound to
    static int port_of(int fd) {
        char sa[16];
        int len = 16;
        int r = syscall(204, fd, @sa, @len);
        if r < 0 { return r; }
        return ((sa[2] & 255) << 8) | (sa[3] & 255);
    }
    static Result<int, Error> accept(int fd) {
        int c = syscall(202, fd, 0, 0);
        if c < 0 { return Result<int, Error>::Err(Net::fail("accept failed", c)); }
        return Result<int, Error>::Ok(c);
    }
    static Result<int, Error> tcp_connect(String ip, int port) {
        int a[4];
        if !Net::parse_ip(ip, @a) { return Result<int, Error>::Err(Error::make(ErrorKind::Invalid, "not an address like 127.0.0.1: " + ip)); }
        int fd = syscall(198, 2, 1, 0);
        if fd < 0 { return Result<int, Error>::Err(Net::fail("cannot make a socket", fd)); }
        char sa[16];
        Net::make_addr(@sa, a[0], a[1], a[2], a[3], port);
        int r = syscall(203, fd, @sa, 16);
        if r < 0 {
            syscall(57, fd);
            return Result<int, Error>::Err(Net::fail("cannot connect to " + ip, r));
        }
        return Result<int, Error>::Ok(fd);
    }
    // two sockets that are joined to each other (a connection inside the program)
    static Result<int, Error> pair(int^ out) {
        i32 fds[2];                        // the system writes two 32-bit numbers
        int r = syscall(199, 1, 1, 0, @fds);
        if r < 0 { return Result<int, Error>::Err(Net::fail("cannot make a socket pair", r)); }
        out[0] = fds[0];
        out[1] = fds[1];
        return Result<int, Error>::Ok(0);
    }
    // all of the text is sent (the number of bytes)
    static Result<int, Error> send(int fd, String data) {
        int done = 0;
        while done < data.len {
            char^ p = data.c();
            int n = syscall(64, fd, @p[done], data.len - done);
            if n < 0 { return Result<int, Error>::Err(Net::fail("send failed", n)); }
            if n == 0 { break; }
            done += n;
        }
        return Result<int, Error>::Ok(done);
    }
    // what arrived (at most max bytes; "" when the other side closed)
    static Result<String, Error> recv(int fd, int max) {
        char^ b = (char^)Mem::alloc(max + 1);
        int n = syscall(63, fd, b, max);
        if n < 0 {
            Mem::free((void^)b);
            return Result<String, Error>::Err(Net::fail("receive failed", n));
        }
        String r = "";
        for i in 0..n { r.push(b[i]); }
        Mem::free((void^)b);
        return Result<String, Error>::Ok(r);
    }
    static void close(int fd) {
        syscall(57, fd);
    }
}
