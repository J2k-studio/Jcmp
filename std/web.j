// web 0.1.0 -- an HTTP client for the APIs of the web (any method, headers, a body, the status), over http and https.   #import <web>   (needs <net>; license: MPL-2.0)
//   HttpResponse r = Web::request("POST", "https://api.example.org/x", "Authorization: Bearer KEY", "{\"a\":1}")?;
//   cout << r.status << " " << r.body << "\n";          // r.header("content-type") reads a header of the answer
//   Web::get(url, headers)    Web::post_json(url, headers, json)    Web::post_form(url, headers, "a=1&b=2")
// One request, one connection (Connection: close); redirects (301 302 303 307 308) are followed up to 5 times; chunked answers are put together.
// An answer with a status of 400 or more is NOT an error here (r.status says it, r.body has the text of the API); only a connection that fails is an Error.

#import <net>

struct HttpResponse {
    int status;
    String head;                       // the lines of the header, without the status line, each ended by \r\n
    String body;

    // the value of a header of the answer ("" when it is not there); the name in any case
    String header(self, String name) {
        String key = Net::http_lower_ascii("\r\n" + name + ":");
        String lh = Net::http_lower_ascii("\r\n" + self.head);
        int at = lh.find(key);
        if at < 0 { return ""; }
        int from = at + key.len;
        int end = Net::http_find_from(lh, "\r\n", from);
        if end < 0 { end = lh.len; }
        String v = ("\r\n" + self.head).slice(from, end);
        return v.trim();
    }
}

struct Web {
    static Result<HttpResponse, Error> bad(ErrorKind k, String why) {
        return Result<HttpResponse, Error>::Err(Error::make(k, why));
    }

    static Result<HttpResponse, Error> request_at(String method, String url, String headers, String body, int depth) {
        if depth > 5 { return Web::bad(ErrorKind::Invalid, "too many redirects"); }
        int secure = 0;
        int plen = 7;
        int port = 80;
        if url.starts_with("https://") { secure = 1; plen = 8; port = 443; }
        else if !url.starts_with("http://") { return Web::bad(ErrorKind::Invalid, "not an http or https address: " + url); }
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
                if ps[i] < '0' || ps[i] > '9' { return Web::bad(ErrorKind::Invalid, "bad port in " + url); }
                port = port * 10 + (ps[i] - '0');
            }
        }
        if host.len == 0 { return Web::bad(ErrorKind::Invalid, "no host in " + url); }
        int h = 0;
        switch Net::http_open(host, port, secure) {
            Result::Ok(x): { h = x; }
            Result::Err(e): { return Web::bad(e.kind, e.message); }
        }
        String req = method + " " + path + " HTTP/1.1\r\nHost: " + hostport + "\r\nUser-Agent: j2k-web\r\nAccept: */*\r\nConnection: close\r\n";
        if headers.len > 0 { req = req + headers + "\r\n"; }
        if body.len > 0 || method == "POST" || method == "PUT" || method == "PATCH" { req = req + "Content-Length: " + str(body.len) + "\r\n"; }
        req = req + "\r\n" + body;
        switch Net::http_chan_send(secure, h, req) {
            Result::Ok(n): { }
            Result::Err(e): { Net::http_chan_close(secure, h); return Web::bad(e.kind, e.message); }
        }
        String all = "";
        switch Net::http_read_all(secure, h) {
            Result::Ok(t): { all = t; }
            Result::Err(e): { Net::http_chan_close(secure, h); return Web::bad(e.kind, e.message); }
        }
        Net::http_chan_close(secure, h);
        int he = all.find("\r\n\r\n");
        if he < 0 { return Web::bad(ErrorKind::Parse, "the answer of " + host + " has no header"); }
        String head = all.slice(0, he);
        String rbody = all.slice(he + 4, all.len);
        if head.len < 12 || !head.starts_with("HTTP/") { return Web::bad(ErrorKind::Parse, "the answer of " + host + " is not HTTP"); }
        int code = 0;
        for i in 9..12 {
            if head[i] < '0' || head[i] > '9' { return Web::bad(ErrorKind::Parse, "bad status line from " + host); }
            code = code * 10 + (head[i] - '0');
        }
        int eol = head.find("\r\n");
        String lines = "";
        if eol >= 0 { lines = head.slice(eol + 2, head.len) + "\r\n"; }
        String lh = Net::http_lower_ascii(head);
        if code == 301 || code == 302 || code == 303 || code == 307 || code == 308 {
            int li = lh.find("\r\nlocation:");
            if li >= 0 {
                int ls = li + 11;
                int le = Net::http_find_from(head, "\r\n", ls);
                if le < 0 { le = head.len; }
                String loc = head.slice(ls, le).trim();
                if loc.starts_with("/") { loc = scheme + hostport + loc; }
                String m2 = method;
                String b2 = body;
                if code == 301 || code == 302 || code == 303 { if method != "GET" && method != "HEAD" { m2 = "GET"; b2 = ""; } }
                return Web::request_at(m2, loc, headers, b2, depth + 1);
            }
        }
        if lh.contains("\r\ntransfer-encoding: chunked") {
            int ok[1];
            String d = Net::http_unchunk(rbody, @ok);
            if ok[0] == 0 { return Web::bad(ErrorKind::Parse, "the chunks of " + url + " are damaged"); }
            rbody = d;
        }
        HttpResponse r;
        r.status = code;
        r.head = lines;
        r.body = rbody;
        return Result<HttpResponse, Error>::Ok(r);
    }

    static Result<HttpResponse, Error> request(String method, String url, String headers, String body) {
        return Web::request_at(method, url, headers, body, 0);
    }
    static Result<HttpResponse, Error> get(String url, String headers) { return Web::request_at("GET", url, headers, "", 0); }
    static Result<HttpResponse, Error> post_json(String url, String headers, String json) {
        String h = "Content-Type: application/json";
        if headers.len > 0 { h = h + "\r\n" + headers; }
        return Web::request_at("POST", url, h, json, 0);
    }
    static Result<HttpResponse, Error> post_form(String url, String headers, String form) {
        String h = "Content-Type: application/x-www-form-urlencoded";
        if headers.len > 0 { h = h + "\r\n" + headers; }
        return Web::request_at("POST", url, h, form, 0);
    }
    // text for a query: letters, digits and - _ . ~ stay, the other bytes become %XX
    static String url_encode(String s) {
        String hex = "0123456789ABCDEF";
        String r = "";
        for i in 0..s.len {
            int c = s[i] & 255;
            bool keep = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~';
            if keep { r.push((char)c); }
            else { r.push('%'); r.push(hex[c >> 4]); r.push(hex[c & 15]); }
        }
        return r;
    }
}
