// Net: TCP sockets (IPv4, addresses written as numbers: "127.0.0.1"; there is no name lookup).
//   server:  int l = Net::tcp_listen(8080)?;   int c = Net::accept(l)?;   String req = Net::recv(c, 4096)?;   Net::send(c, "hi")?;
//   client:  int s = Net::tcp_connect("127.0.0.1", 8080)?;   Net::send(s, "hello")?;   Net::close(s);
// the state of the progress line (the speed of the last moments)
int net_pg_t;
int net_pg_b;
int net_pg_sp;

struct Net {
    static Error fail(String what, int e) {
        return Error::from_errno(e, what);
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
        int fd = Sys::socket_tcp();
        if fd < 0 { return Result<int, Error>::Err(Net::fail("cannot make a socket", fd)); }
        int one = 1;
        Sys::setsockopt(fd, 1, 2, @one, 4);
        char sa[16];
        Net::make_addr(@sa, 0, 0, 0, 0, port);
        int r = Sys::bind(fd, @sa, 16);
        if r < 0 {
            Sys::close(fd);
            return Result<int, Error>::Err(Net::fail("cannot use the port", r));
        }
        r = Sys::listen(fd, 16);
        if r < 0 {
            Sys::close(fd);
            return Result<int, Error>::Err(Net::fail("cannot listen", r));
        }
        return Result<int, Error>::Ok(fd);
    }
    // the port that the socket is bound to
    static int port_of(int fd) {
        char sa[16];
        int len = 16;
        int r = Sys::getsockname(fd, @sa, @len);
        if r < 0 { return r; }
        return ((sa[2] & 255) << 8) | (sa[3] & 255);
    }
    static Result<int, Error> accept(int fd) {
        // accept4 (242), not accept (202): the filter of Android kills a program that makes the plain accept call ("Bad system call")
        int c = Sys::accept(fd);
        while c == 0 - 4 { c = Sys::accept(fd); }          // interrupted by a signal: again
        if c < 0 { return Result<int, Error>::Err(Net::fail("accept failed", c)); }
        return Result<int, Error>::Ok(c);
    }
    static Result<int, Error> tcp_connect(String ip, int port) {
        int a[4];
        if !Net::parse_ip(ip, @a) { return Result<int, Error>::Err(Error::make(ErrorKind::Invalid, "not an address like 127.0.0.1: " + ip)); }
        int fd = Sys::socket_tcp();
        if fd < 0 { return Result<int, Error>::Err(Net::fail("cannot make a socket", fd)); }
        char sa[16];
        Net::make_addr(@sa, a[0], a[1], a[2], a[3], port);
        int r = Sys::connect(fd, @sa, 16);
        if r < 0 {
            Sys::close(fd);
            return Result<int, Error>::Err(Net::fail("cannot connect to " + ip, r));
        }
        return Result<int, Error>::Ok(fd);
    }
    // two sockets that are joined to each other (a connection inside the program)
    static Result<int, Error> pair(int^ out) {
        i32 fds[2];                        // the system writes two 32-bit numbers
        int r = Sys::socketpair(@fds);
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
            int n = Sys::write(fd, @p[done], data.len - done);
            while n == 0 - 4 { n = Sys::write(fd, @p[done], data.len - done); }
            if n < 0 { return Result<int, Error>::Err(Net::fail("send failed", n)); }
            if n == 0 { break; }
            done += n;
        }
        return Result<int, Error>::Ok(done);
    }
    // what arrived (at most max bytes; "" when the other side closed)
    static Result<String, Error> recv(int fd, int max) {
        char^ b = (char^)Mem::alloc(max + 1);
        int n = Sys::read(fd, b, max);
        while n == 0 - 4 { n = Sys::read(fd, b, max); }
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
        Sys::close(fd);
    }
    // ---- names and pages: Net::dns.lookup("example.com"), Net::http.get("http://...") (designed by the assistant for jget, 2026-10-17, adjustable)
    // dns: A records over UDP port 53, no cache. A name that is already an address stays; localhost, the hosts files, then the name server.
    // http: GET over plain TCP (no https yet: TLS is not written), redirects followed, chunked answers decoded.
    static bool dns_is_ip(String s) {
        int a[4];
        return Net::parse_ip(s, @a);
    }
    // the first address after the word `nameserver` in a resolv.conf text
    static String dns_nameserver_in(String text) {
        String[] lines = text.split("\n");
        for i in 0..lines.len {
            String l = lines[i].trim();
            if l.starts_with("nameserver") {
                String ip = l.slice(10, l.len).trim();
                if Net::dns_is_ip(ip) { return ip; }
            }
        }
        return "";
    }
    // the value of an environment variable, or "" (the net unit does not need the system unit)
    static String dns_env(String name) {
        int i = argc() + 1;
        while arg(i) != null {
            char^ e = (char^)arg(i);
            int k = 0;
            while k < name.len && e[k] == name[k] { k += 1; }
            if k == name.len && e[k] == '=' {
                String v = "";
                int j = k + 1;
                while e[j] != 0 {
                    v.push(e[j]);
                    j += 1;
                }
                return v;
            }
            i += 1;
        }
        return "";
    }
    // a whole small file as a text, or "" when it cannot be read (the net unit does not need the files unit)
    static String dns_read(String path) {
        int fd = Sys::open_read(path.c());
        if fd < 0 { return ""; }
        char buf[4096];
        String r = "";
        while true {
            int n = Sys::read(fd, @buf, 4096);
            if n <= 0 { break; }
            for i in 0..n { r.push(buf[i]); }
        }
        Sys::close(fd);
        return r;
    }
    // the name server to ask: J2K_DNS, then the resolv.conf files, else 1.1.1.1
    static String dns_server() {
        String e = Net::dns_env("J2K_DNS");
        if Net::dns_is_ip(e) { return e; }
        String ns = Net::dns_nameserver_in(Net::dns_read("/etc/resolv.conf"));
        if ns.len > 0 { return ns; }
        String prefix = Net::dns_env("PREFIX");
        if prefix.len > 0 {
            ns = Net::dns_nameserver_in(Net::dns_read(prefix + "/etc/resolv.conf"));
            if ns.len > 0 { return ns; }
        }
        return "1.1.1.1";
    }
    // the address that a hosts file (a text with lines "address name name ...") gives to the name, or ""
    static String dns_hosts_in(String text, String name) {
        String[] lines = text.split("\n");
        for i in 0..lines.len {
            String l = lines[i].trim();
            if l.len == 0 || l.starts_with("#") { continue; }
            String[] w = l.split(" ");
            if w.len < 2 || !Net::dns_is_ip(w[0]) { continue; }
            for k in 1..w.len {
                if w[k].trim() == name { return w[0]; }
            }
        }
        return "";
    }
    // the question: the header and one question for the A record of the name
    static String dns_build_query(String name, int id) {
        String q = "";
        q.push((char)((id >> 8) & 255));
        q.push((char)(id & 255));
        q.push((char)1);          // recursion desired
        q.push((char)0);
        q.push((char)0);
        q.push((char)1);          // one question
        for i in 0..6 { q.push((char)0); }
        String[] parts = name.split(".");
        for i in 0..parts.len {
            q.push((char)parts[i].len);
            q.append(parts[i]);
        }
        q.push((char)0);
        q.push((char)0);
        q.push((char)1);          // type A
        q.push((char)0);
        q.push((char)1);          // class IN
        return q;
    }
    // the position after the name that starts at p (a name ends with 0, or with a pointer of two bytes)
    static int dns_skip_name(String r, int p) {
        while p < r.len {
            int c = r[p] & 255;
            if c == 0 { return p + 1; }
            if (c & 192) == 192 { return p + 2; }
            p += c + 1;
        }
        return p;
    }
    // the first A record of an answer, as "a.b.c.d", or "" when there is none
    static String dns_parse_answer(String r) {
        if r.len < 12 { return ""; }
        if (r[3] & 15) != 0 { return ""; }
        int qd = ((r[4] & 255) << 8) | (r[5] & 255);
        int an = ((r[6] & 255) << 8) | (r[7] & 255);
        int p = 12;
        for q in 0..qd {
            p = Net::dns_skip_name(r, p) + 4;
        }
        for a in 0..an {
            p = Net::dns_skip_name(r, p);
            if p + 10 > r.len { return ""; }
            int type = ((r[p] & 255) << 8) | (r[p + 1] & 255);
            int rdlen = ((r[p + 8] & 255) << 8) | (r[p + 9] & 255);
            p += 10;
            if type == 1 && rdlen == 4 && p + 4 <= r.len {
                return str(r[p] & 255) + "." + str(r[p + 1] & 255) + "." + str(r[p + 2] & 255) + "." + str(r[p + 3] & 255);
            }
            p += rdlen;
        }
        return "";
    }
    // ask the name server (UDP), up to three times, waiting 3 seconds each time
    static Result<String, Error> dns_ask(String server, String name) {
        int sv[4];
        if !Net::parse_ip(server, @sv) { return Result<String, Error>::Err(Error::make(ErrorKind::Invalid, "the name server is not an address: " + server)); }
        int ts[2];
        Sys::clock_gettime(1, @ts);
        int id = (ts[1] / 1000) & 65535;
        String q = Net::dns_build_query(name, id);
        int fd = Sys::socket_udp();          // a datagram socket
        if fd < 0 { return Result<String, Error>::Err(Net::fail("cannot make a socket", fd)); }
        char sa[16];
        Net::make_addr(@sa, sv[0], sv[1], sv[2], sv[3], 53);
        int cr = Sys::connect(fd, @sa, 16);
        if cr < 0 {
            Sys::close(fd);
            return Result<String, Error>::Err(Net::fail("cannot reach the name server " + server, cr));
        }
        Sys::set_receive_timeout(fd, 3);        // wait at most 3 seconds for an answer
        char buf[1500];
        for attempt in 0..3 {
            Sys::write(fd, q.c(), q.len);
            int n = Sys::read(fd, @buf, 1500);
            if n > 12 && (buf[0] & 255) == ((id >> 8) & 255) && (buf[1] & 255) == (id & 255) {
                String r = "";
                for i in 0..n { r.push(buf[i]); }
                Sys::close(fd);
                String ip = Net::dns_parse_answer(r);
                if ip.len == 0 { return Result<String, Error>::Err(Error::make(ErrorKind::NotFound, "no address for " + name)); }
                return Result<String, Error>::Ok(ip);
            }
        }
        Sys::close(fd);
        return Result<String, Error>::Err(Error::make(ErrorKind::Io, "the name server " + server + " did not answer"));
    }
    static Result<String, Error> dns_try_lookup(String name) {
        if Net::dns_is_ip(name) { return Result<String, Error>::Ok(name); }
        if name == "localhost" { return Result<String, Error>::Ok("127.0.0.1"); }
        String h = Net::dns_hosts_in(Net::dns_read("/etc/hosts"), name);
        if h.len > 0 { return Result<String, Error>::Ok(h); }
        String prefix = Net::dns_env("PREFIX");
        if prefix.len > 0 {
            h = Net::dns_hosts_in(Net::dns_read(prefix + "/etc/hosts"), name);
            if h.len > 0 { return Result<String, Error>::Ok(h); }
        }
        return Net::dns_ask(Net::dns_server(), name);
    }
    // the same, thrown as a text when it fails
    static String dns_lookup(String name) {
        switch Net::dns_try_lookup(name) {
            Result::Ok(a): return a;
            Result::Err(e): Error::raise(e.message.c());
        }
        return "";
    }
    static String http_lower_ascii(String s) {
        String r = "";
        for i in 0..s.len {
            char c = s[i];
            if c >= 'A' && c <= 'Z' { c = (char)(c + 32); }
            r.push(c);
        }
        return r;
    }
    static int http_find_from(String s, String x, int from) {
        if from >= s.len { return -1; }
        int k = s.slice(from, s.len).find(x);
        if k < 0 { return -1; }
        return from + k;
    }
    static int http_hex_value(char c) {
        if c >= '0' && c <= '9' { return c - '0'; }
        if c >= 'a' && c <= 'f' { return c - 'a' + 10; }
        if c >= 'A' && c <= 'F' { return c - 'A' + 10; }
        return -1;
    }
    // the body of a chunked answer ("size in hex CRLF data CRLF ... 0 CRLF CRLF"); false in ok[0] when it is damaged
    static String http_unchunk(String body, int^ ok) {
        String out = "";
        int p = 0;
        ok[0] = 0;
        while p < body.len {
            int e = Net::http_find_from(body, "\r\n", p);
            if e < 0 { return out; }
            int size = 0;
            int k = p;
            while k < e && Net::http_hex_value(body[k]) >= 0 {
                size = size * 16 + Net::http_hex_value(body[k]);
                k += 1;
            }
            if k == p { return out; }
            if size == 0 { ok[0] = 1; return out; }
            if e + 2 + size > body.len { return out; }
            out.append(body.slice(e + 2, e + 2 + size));
            p = e + 2 + size + 2;
        }
        return out;
    }
    // one connection, plain (secure 0: h is the socket) or TLS (secure 1: h is the handle of Crypto::tls_connect)
    static Result<int, Error> http_open(String host, int port, int secure) {
        String ip = "";
        switch Net::dns_try_lookup(host) {
            Result::Ok(a): { ip = a; }
            Result::Err(e): { return Result<int, Error>::Err(Error::make(e.kind, e.message)); }
        }
        int fd = 0;
        switch Net::tcp_connect(ip, port) {
            Result::Ok(c): { fd = c; }
            Result::Err(e): { return Result<int, Error>::Err(Error::make(e.kind, e.message)); }
        }
        if secure == 0 { return Result<int, Error>::Ok(fd); }
        return Crypto::tls_connect(fd, host, 0);
    }
    static Result<int, Error> http_chan_send(int secure, int h, String data) {
        if secure == 0 { return Net::send(h, data); }
        if Crypto::tls_send(h, data) { return Result<int, Error>::Ok(data.len); }
        return Result<int, Error>::Err(Error::make(ErrorKind::Io, "send failed"));
    }
    static Result<String, Error> http_chan_recv(int secure, int h, int max) {
        if secure == 0 { return Net::recv(h, max); }
        return Result<String, Error>::Ok(Crypto::tls_recv(h));
    }
    static void http_chan_close(int secure, int h) {
        if secure == 0 { Net::close(h); } else { Crypto::tls_close(h); }
    }
    static Result<String, Error> http_read_all(int secure, int h) {
        String all = "";
        while true {
            Result<String, Error> r = Net::http_chan_recv(secure, h, 65536);
            switch r {
                Result::Ok(chunk): {
                    if chunk.len == 0 { return Result<String, Error>::Ok(all); }
                    all.append(chunk);
                }
                Result::Err(e): { return Result<String, Error>::Err(Error::make(e.kind, e.message)); }
            }
        }
        return Result<String, Error>::Ok(all);
    }
    static Result<String, Error> http_fetch(String url, int depth) {
        if depth > 5 { return Result<String, Error>::Err(Error::make(ErrorKind::Invalid, "too many redirects")); }
        int secure = 0;
        int plen = 7;
        int port = 80;
        if url.starts_with("https://") { secure = 1; plen = 8; port = 443; }
        else if !url.starts_with("http://") {
            return Result<String, Error>::Err(Error::make(ErrorKind::Invalid, "not an http or https address: " + url));
        }
        String scheme = "http://";
        if secure == 1 { scheme = "https://"; }
        String rest = url.slice(plen, url.len);
        int slash = rest.find("/");
        String hostport = rest;
        String path = "/";
        if slash >= 0 {
            hostport = rest.slice(0, slash);
            path = rest.slice(slash, rest.len);
        }
        String host = hostport;
        int colon = hostport.find(":");
        if colon >= 0 {
            host = hostport.slice(0, colon);
            String ps = hostport.slice(colon + 1, hostport.len);
            port = 0;
            for i in 0..ps.len {
                if ps[i] < '0' || ps[i] > '9' { return Result<String, Error>::Err(Error::make(ErrorKind::Invalid, "bad port in " + url)); }
                port = port * 10 + (ps[i] - '0');
            }
        }
        if host.len == 0 { return Result<String, Error>::Err(Error::make(ErrorKind::Invalid, "no host in " + url)); }
        int h = 0;
        switch Net::http_open(host, port, secure) {
            Result::Ok(x): { h = x; }
            Result::Err(e): { return Result<String, Error>::Err(Error::make(e.kind, e.message)); }
        }
        String req = "GET " + path + " HTTP/1.1\r\nHost: " + hostport + "\r\nUser-Agent: jget\r\nAccept: */*\r\nConnection: close\r\n\r\n";
        switch Net::http_chan_send(secure, h, req) {
            Result::Ok(n): { }
            Result::Err(e): { Net::http_chan_close(secure, h); return Result<String, Error>::Err(Error::make(e.kind, e.message)); }
        }
        String all = "";
        switch Net::http_read_all(secure, h) {
            Result::Ok(t): { all = t; }
            Result::Err(e): { Net::http_chan_close(secure, h); return Result<String, Error>::Err(Error::make(e.kind, e.message)); }
        }
        Net::http_chan_close(secure, h);
        int he = all.find("\r\n\r\n");
        if he < 0 { return Result<String, Error>::Err(Error::make(ErrorKind::Parse, "the answer of " + host + " has no header")); }
        String head = all.slice(0, he);
        String body = all.slice(he + 4, all.len);
        String lh = Net::http_lower_ascii(head);
        if head.len < 12 || !head.starts_with("HTTP/") {
            return Result<String, Error>::Err(Error::make(ErrorKind::Parse, "the answer of " + host + " is not HTTP"));
        }
        int code = 0;
        for i in 9..12 {
            if head[i] < '0' || head[i] > '9' { return Result<String, Error>::Err(Error::make(ErrorKind::Parse, "bad status line from " + host)); }
            code = code * 10 + (head[i] - '0');
        }
        if code == 301 || code == 302 || code == 303 || code == 307 || code == 308 {
            int li = lh.find("\r\nlocation:");
            if li < 0 { return Result<String, Error>::Err(Error::make(ErrorKind::Parse, "a redirect without a place")); }
            int ls = li + 11;
            int le = Net::http_find_from(head, "\r\n", ls);
            if le < 0 { le = head.len; }
            String loc = head.slice(ls, le).trim();
            if loc.starts_with("/") { loc = scheme + hostport + loc; }
            return Net::http_fetch(loc, depth + 1);
        }
        if code >= 400 {
            return Result<String, Error>::Err(Error::make(ErrorKind::NotFound, "HTTP " + str(code) + " from " + url));
        }
        if lh.contains("\r\ntransfer-encoding: chunked") {
            int ok[1];
            String d = Net::http_unchunk(body, @ok);
            if ok[0] == 0 { return Result<String, Error>::Err(Error::make(ErrorKind::Parse, "the chunks of " + url + " are damaged")); }
            return Result<String, Error>::Ok(d);
        }
        return Result<String, Error>::Ok(body);
    }
    // the parts of an http:// address: [host, host:port, path, port]; one text (the reason) when it cannot be used
    static String[] http_split(String url) {
        String[] r = arr(0);
        int secure = 0;
        int plen = 7;
        int port = 80;
        if url.starts_with("https://") { secure = 1; plen = 8; port = 443; }
        else if !url.starts_with("http://") { r.push("not an http or https address: " + url); return r; }
        String rest = url.slice(plen, url.len);
        int slash = rest.find("/");
        String hostport = rest;
        String path = "/";
        if slash >= 0 {
            hostport = rest.slice(0, slash);
            path = rest.slice(slash, rest.len);
        }
        String host = hostport;
        int colon = hostport.find(":");
        if colon >= 0 {
            host = hostport.slice(0, colon);
            String ps = hostport.slice(colon + 1, hostport.len);
            port = 0;
            for i in 0..ps.len {
                if ps[i] < '0' || ps[i] > '9' { r.push("bad port in " + url); return r; }
                port = port * 10 + (ps[i] - '0');
            }
        }
        if host.len == 0 { r.push("no host in " + url); return r; }
        r.push(host);
        r.push(hostport);
        r.push(path);
        r.push(str(port));
        r.push(str(secure));
        return r;
    }
    // 1.2 MB, 340.5 KB, 17 B
    static String http_size_text(int n) {
        if n < 1024 { return str(n) + " B"; }
        if n < 1048576 { return str(n / 1024) + "." + str((n % 1024) * 10 / 1024) + " KB"; }
        return str(n / 1048576) + "." + str((n % 1048576) * 10 / 1048576) + " MB";
    }
    // 3:07 or 1:02:03
    static String http_time_text(int sec) {
        if sec < 0 { sec = 0; }
        int h = sec / 3600;
        int m = (sec % 3600) / 60;
        int s2 = sec % 60;
        String ms = str(m);
        String ss = str(s2);
        if ss.len < 2 { ss = "0" + ss; }
        if h > 0 {
            if ms.len < 2 { ms = "0" + ms; }
            return str(h) + ":" + ms + ":" + ss;
        }
        return ms + ":" + ss;
    }
    // the progress line on the error output (replaces the line before it):
    //   [#########>               ]  45%  1.2 MB / 2.7 MB  340.5 KB/s  ETA 0:04
    //   [###########]  100%  2.7 MB in 0:03  (840.1 KB/s)                       (last = 1)
    //   [      <###>      ]  257.2 KB  666.4 KB/s  0:01                          (the size is not known)
    // The speed is the speed of the last second or so (not the average of everything), the bar fits the width of the terminal.
    static void http_show_progress(int done, int total, int ms, int last) {
        // the width of the bar from the width of the terminal
        char ws[8];
        int width = 20;
        if Sys::window_size(2, @ws) == 0 {
            int cols = (ws[2] & 255) | ((ws[3] & 255) << 8);
            if cols > 0 { width = cols - 56; }
            if width < 8 { width = 8; }
            if width > 30 { width = 30; }
        }
        // the speed of the last moments
        if ms < 300 { net_pg_t = 0; net_pg_b = 0; net_pg_sp = 0; }
        if ms - net_pg_t >= 500 {
            int now_sp = (done - net_pg_b) * 1000 / (ms - net_pg_t);
            if net_pg_sp == 0 { net_pg_sp = now_sp; } else { net_pg_sp = (net_pg_sp * 2 + now_sp) / 3; }
            net_pg_t = ms;
            net_pg_b = done;
        }
        int speed = net_pg_sp;
        int ms1 = ms;
        if ms1 < 1 { ms1 = 1; }
        int avg = done * 1000 / ms1;
        if speed == 0 { speed = avg; }
        String line = "\r";
        String bar = "";
        if total > 0 {
            int pct = done * 100 / total;
            int filled = pct * width / 100;
            for i in 0..width {
                if i < filled { bar.push('#'); } else if i == filled && last == 0 { bar.push('>'); } else { bar.push(' '); }
            }
            String ps = str(pct);
            while ps.len < 3 { ps = " " + ps; }
            if last == 1 {
                line = line + "[" + bar + "] " + ps + "%  " + Net::http_size_text(done) + " in " + Net::http_time_text(ms / 1000) + "  (" + Net::http_size_text(avg) + "/s)";
            } else {
                String eta = "--:--";
                if speed > 0 { eta = Net::http_time_text((total - done) / speed); }
                line = line + "[" + bar + "] " + ps + "%  " + Net::http_size_text(done) + " / " + Net::http_size_text(total) + "  " + Net::http_size_text(speed) + "/s  ETA " + eta;
            }
        } else {
            // the size is not known: a block goes to and fro
            int span = width - 5;
            if span < 1 { span = 1; }
            int pos = (ms / 120) % (2 * span);
            if pos > span { pos = 2 * span - pos; }
            for i in 0..width {
                if i >= pos && i < pos + 5 { bar.push('#'); } else { bar.push(' '); }
            }
            if last == 1 {
                line = line + "[" + bar + "] " + Net::http_size_text(done) + " in " + Net::http_time_text(ms / 1000) + "  (" + Net::http_size_text(avg) + "/s)";
            } else {
                line = line + "[" + bar + "] " + Net::http_size_text(done) + "  " + Net::http_size_text(speed) + "/s  " + Net::http_time_text(ms / 1000);
            }
        }
        line.push((char)27);                     // ESC [ K : erase the rest of the line
        line.push('[');
        line.push('K');
        Sys::write(2, line.c(), line.len);
    }
    static int http_now_ms() {
        int ts[2];
        Sys::clock_gettime(1, @ts);
        return ts[0] * 1000 + ts[1] / 1000000;
    }
    static void http_write_all(int fd, String s) {
        int off = 0;
        char^ p = s.c();
        while off < s.len {
            int n = Sys::write(fd, @p[off], s.len - off);
            if n <= 0 { return; }
            off += n;
        }
    }
    // fetch the page into the file `path` as it arrives (written to path.part first, then renamed); show: 1 = a progress bar on the error
    // output when it is a terminal, 0 = never. Redirects and chunked answers are followed. Gives the number of bytes.
    static Result<int, Error> http_download_to(String url, String path, int show, int depth) {
        if depth > 5 { return Result<int, Error>::Err(Error::make(ErrorKind::Invalid, "too many redirects")); }
        String[] u = Net::http_split(url);
        if u.len == 1 { return Result<int, Error>::Err(Error::make(ErrorKind::Invalid, u[0])); }
        String host = u[0];
        String hostport = u[1];
        String rpath = u[2];
        int port = u[3].to_int();
        int secure = u[4].to_int();
        String scheme = "http://";
        if secure == 1 { scheme = "https://"; }
        int fd = 0;
        switch Net::http_open(host, port, secure) {
            Result::Ok(c): { fd = c; }
            Result::Err(e): { return Result<int, Error>::Err(Error::make(e.kind, e.message)); }
        }
        String req = "GET " + rpath + " HTTP/1.1\r\nHost: " + hostport + "\r\nUser-Agent: jget\r\nAccept: */*\r\nConnection: close\r\n\r\n";
        switch Net::http_chan_send(secure, fd, req) {
            Result::Ok(n): { }
            Result::Err(e): { Net::http_chan_close(secure, fd); return Result<int, Error>::Err(Error::make(e.kind, e.message)); }
        }
        // the header
        String buf = "";
        int he = -1;
        while he < 0 {
            switch Net::http_chan_recv(secure, fd, 65536) {
                Result::Ok(c): {
                    if c.len == 0 { Net::http_chan_close(secure, fd); return Result<int, Error>::Err(Error::make(ErrorKind::Parse, "the answer of " + host + " has no header")); }
                    buf.append(c);
                    he = buf.find("\r\n\r\n");
                }
                Result::Err(e): { Net::http_chan_close(secure, fd); return Result<int, Error>::Err(Error::make(e.kind, e.message)); }
            }
            if he < 0 && buf.len > 65536 { Net::http_chan_close(secure, fd); return Result<int, Error>::Err(Error::make(ErrorKind::Parse, "the header of " + host + " is too long")); }
        }
        String head = buf.slice(0, he);
        String lh = Net::http_lower_ascii(head);
        if head.len < 12 || !head.starts_with("HTTP/") { Net::http_chan_close(secure, fd); return Result<int, Error>::Err(Error::make(ErrorKind::Parse, "the answer of " + host + " is not HTTP")); }
        int code = 0;
        for i in 9..12 {
            if head[i] < '0' || head[i] > '9' { Net::http_chan_close(secure, fd); return Result<int, Error>::Err(Error::make(ErrorKind::Parse, "bad status line from " + host)); }
            code = code * 10 + (head[i] - '0');
        }
        if code == 301 || code == 302 || code == 303 || code == 307 || code == 308 {
            Net::http_chan_close(secure, fd);
            int li = lh.find("\r\nlocation:");
            if li < 0 { return Result<int, Error>::Err(Error::make(ErrorKind::Parse, "a redirect without a place")); }
            int ls = li + 11;
            int le = Net::http_find_from(head, "\r\n", ls);
            if le < 0 { le = head.len; }
            String loc = head.slice(ls, le).trim();
            if loc.starts_with("/") { loc = scheme + hostport + loc; }
            return Net::http_download_to(loc, path, show, depth + 1);
        }
        if code >= 400 { Net::http_chan_close(secure, fd); return Result<int, Error>::Err(Error::make(ErrorKind::NotFound, "HTTP " + str(code) + " from " + url)); }
        int total = -1;
        int cl = lh.find("\r\ncontent-length:");
        if cl >= 0 {
            total = 0;
            int q = cl + 17;
            while q < lh.len && lh[q] == ' ' { q += 1; }
            while q < lh.len && lh[q] >= '0' && lh[q] <= '9' {
                total = total * 10 + (lh[q] - '0');
                q += 1;
            }
        }
        bool chunked = lh.contains("\r\ntransfer-encoding: chunked");
        if chunked { total = -1; }
        String tmp = path + ".part";
        int wf = Sys::open_write(tmp.c());
        if wf < 0 { Net::http_chan_close(secure, fd); return Result<int, Error>::Err(Net::fail("cannot write " + tmp, wf)); }
        char termios[64];
        bool tty = show == 1 && Sys::isatty(2) == 0;
        int t0 = Net::http_now_ms();
        int last = t0;
        int done = 0;
        int cmode = 0;                 // chunked: 0 the size line, 1 the data, 2 the CRLF after the data, 3 the end
        int csize = 0;
        int cskip = 0;
        String cline = "";
        String data = buf.slice(he + 4, buf.len);
        bool finished = false;
        bool failed = false;
        while !finished {
            if data.len > 0 {
                if !chunked {
                    Net::http_write_all(wf, data);
                    done += data.len;
                    if total >= 0 && done >= total { finished = true; }
                } else {
                    int p = 0;
                    while p < data.len && cmode != 3 {
                        if cmode == 0 {
                            char c = data[p];
                            p += 1;
                            if c == '\n' {
                                int sz = 0;
                                for k in 0..cline.len {
                                    int hv = Net::http_hex_value(cline[k]);
                                    if hv < 0 { break; }
                                    sz = sz * 16 + hv;
                                }
                                cline = "";
                                csize = sz;
                                if sz == 0 { cmode = 3; } else { cmode = 1; }
                            } else if c != '\r' {
                                cline.push(c);
                            }
                        } else if cmode == 1 {
                            int take = data.len - p;
                            if take > csize { take = csize; }
                            Net::http_write_all(wf, data.slice(p, p + take));
                            done += take;
                            p += take;
                            csize -= take;
                            if csize == 0 { cmode = 2; cskip = 2; }
                        } else {
                            p += 1;
                            cskip -= 1;
                            if cskip == 0 { cmode = 0; }
                        }
                    }
                    if cmode == 3 { finished = true; }
                }
                if tty {
                    int now = Net::http_now_ms();
                    if now - last >= 100 { Net::http_show_progress(done, total, now - t0, 0); last = now; }
                }
            }
            if !finished {
                switch Net::http_chan_recv(secure, fd, 65536) {
                    Result::Ok(c): {
                        if c.len == 0 { finished = true; if chunked || (total >= 0 && done < total) { failed = true; } }
                        data = c;
                    }
                    Result::Err(e): { finished = true; failed = true; }
                }
            }
        }
        Net::http_chan_close(secure, fd);
        Sys::close(wf);
        if tty {
            Net::http_show_progress(done, total, Net::http_now_ms() - t0, 1);
            Sys::write(2, "\n", 1);
        }
        if failed {
            Sys::unlink(tmp.c());
            return Result<int, Error>::Err(Error::make(ErrorKind::Io, "the download of " + url + " stopped before the end (" + str(done) + " bytes)"));
        }
        int rr = Sys::rename(tmp.c(), path.c());
        if rr < 0 {
            Sys::unlink(tmp.c());
            return Result<int, Error>::Err(Net::fail("cannot write " + path, rr));
        }
        return Result<int, Error>::Ok(done);
    }
    static Result<int, Error> http_try_download(String url, String path, int show) {
        return Net::http_download_to(url, path, show, 0);
    }
    // the same, thrown as a text when it fails
    static int http_download(String url, String path, int show) {
        switch Net::http_try_download(url, path, show) {
            Result::Ok(n): return n;
            Result::Err(e): Error::raise(e.message.c());
        }
        return 0;
    }
    static Result<String, Error> http_try_get(String url) {
        return Net::http_fetch(url, 0);
    }
    // the same, thrown as a text when it fails
    static String http_get(String url) {
        switch Net::http_try_get(url) {
            Result::Ok(b): return b;
            Result::Err(e): Error::raise(e.message.c());
        }
        return "";
    }
}

// Tcp: the short way (module name `tcp`, written  tcp.listen(8080)  or  Tcp::listen(8080)).
// Designed by the assistant at the owner's request (2026-10-16), adjustable. An error is thrown as a text (catch it with try/catch;
// an uncaught one stops the program with the text). The functions that return a Result instead are try_listen, try_accept, ...
//   int l = tcp.listen(8080);   int c = tcp.accept(l);   String req = tcp.recv(c);   tcp.send(c, "hello");   tcp.close(c);
//   int s = tcp.connect("127.0.0.1", 8080);
struct Tcp {
    // throw the message of the error (copied to a buffer that stays alive while the stack is unwound)
    static void fail(char^ msg) {
        Error::raise(msg);
    }
    static int take(Result<int, Error> r) {
        switch r {
            Result::Ok(v): return v;
            Result::Err(e): Tcp::fail(e.message.c());
        }
        return 0;
    }
    static int listen(int port) { return Tcp::take(Net::tcp_listen(port)); }
    static int accept(int l) { return Tcp::take(Net::accept(l)); }
    static int connect(String ip, int port) { return Tcp::take(Net::tcp_connect(ip, port)); }
    static int send(int c, String data) { return Tcp::take(Net::send(c, data)); }
    static String recv_max(int c, int max) {
        Result<String, Error> r = Net::recv(c, max);
        switch r {
            Result::Ok(v): return v;
            Result::Err(e): Tcp::fail(e.message.c());
        }
        return "";
    }
    static String recv(int c) { return Tcp::recv_max(c, 4096); }
    static int port_of(int l) { return Net::port_of(l); }
    static void close(int c) { Net::close(c); }
    static Result<int, Error> try_listen(int port) { return Net::tcp_listen(port); }
    static Result<int, Error> try_accept(int l) { return Net::accept(l); }
    static Result<int, Error> try_connect(String ip, int port) { return Net::tcp_connect(ip, port); }
    static Result<int, Error> try_send(int c, String data) { return Net::send(c, data); }
    static Result<String, Error> try_recv(int c) { return Net::recv(c, 4096); }
}

// Listener and Connection: the formal names of the two sides of a TCP line (docs/syntax-design.md 79.1). Nothing closes by itself:
// the owner calls close() (it gives 0, or the number of the system error) or frees the line another way. A failure is thrown as a text.
//   Listener l = Listener::on(8080);   Connection c = l.accept();   String request = c.receive();   c.send("hello");   c.close();   l.close();
//   Connection s = Connection::to("127.0.0.1", 8080);
// Designed by the assistant (the names Listener::on and Connection::to), adjustable.
struct Connection {
    int fd;
    static Connection to(String ip, int port) {
        Connection c;
        c.fd = Tcp::connect(ip, port);
        return c;
    }
    String receive(self) { return Tcp::recv(self.fd); }
    String receive_max(self, int max) { return Tcp::recv_max(self.fd, max); }
    int send(self, String data) { return Tcp::send(self.fd, data); }
    int close(self) { return Sys::close(self.fd); }
}
struct Listener {
    int fd;
    static Listener on(int port) {
        Listener l;
        l.fd = Tcp::listen(port);
        return l;
    }
    int port(self) { return Net::port_of(self.fd); }
    Connection accept(self) {
        Connection c;
        c.fd = Tcp::accept(self.fd);
        return c;
    }
    int close(self) { return Sys::close(self.fd); }
}

