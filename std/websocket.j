// websocket 0.2.0 -- a WebSocket client (RFC 6455) over ws and wss.   #import <websocket>   (needs <net>; license: MPL-2.0)
//   WebSocket ws = Ws::connect("wss://gateway.discord.gg/?v=10&encoding=json", "")?;
//   ws.send_text("{\"op\":1}");
//   WsMessage m = ws.recv()?;           // m.kind: 1 text, 2 binary, 8 closed (m.text = the reason); pings are answered by recv itself
//   WsMessage w = ws.recv_wait(500);    // waits at most 500 ms: kind 0 when nothing came (to send a heartbeat in between)
//   ws.close();
// recv waits for the next whole message (fragments are put together). It is blocking: use a thread (<tasks>) when the program has other work.
// The answer "Sec-WebSocket-Accept" is not checked (no SHA-1 yet); the status 101 is.

#import <net>

struct WsMessage {
    int kind;                          // 1 text, 2 binary, 8 the connection was closed
    String text;                       // the bytes of the message
}

struct WebSocket {
    static WsMessage msg(int kind, String text) {
        WsMessage m;
        m.kind = kind;
        m.text = text + "";
        return m;
    }

    int secure;
    int h;
    bool open;
    String buf;                        // bytes read but not used yet

    // more bytes in buf until it has n; false when the connection is gone
    bool need(self, int n) {
        while self.buf.len < n {
            String piece = "";
            switch Net::http_chan_recv(self.secure, self.h, 8192) {
                Result::Ok(t): { piece = t; }
                Result::Err(e): { self.open = false; return false; }
            }
            if piece.len == 0 { self.open = false; return false; }
            self.buf = self.buf + piece;
        }
        return true;
    }

    // one frame: opcode 1 text, 2 binary, 8 close, 9 ping, 10 pong; the bytes are masked as a client must
    bool send_frame(self, int op, String data) {
        if !self.open { return false; }
        String f = "";
        f.push((char)(128 + op));
        int n = data.len;
        if n < 126 { f.push((char)(128 + n)); }
        else if n < 65536 { f.push((char)(128 + 126)); f.push((char)((n >> 8) & 255)); f.push((char)(n & 255)); }
        else {
            f.push((char)(128 + 127));
            for k in 0..8 { f.push((char)((n >> (8 * (7 - k))) & 255)); }
        }
        char mk[4];
        Sys::random(@mk, 4);
        for k in 0..4 { f.push(mk[k]); }
        for i in 0..n { f.push((char)((data[i] xor mk[i % 4]) & 255)); }
        switch Net::http_chan_send(self.secure, self.h, f) {
            Result::Ok(x): { return true; }
            Result::Err(e): { self.open = false; return false; }
        }
        return false;
    }

    bool send_text(self, String text) { return self.send_frame(1, text); }
    bool send_binary(self, String data) { return self.send_frame(2, data); }

    // the next message; ping is answered, pong is skipped; a close frame (or a lost connection) gives kind 8
    WsMessage recv(self) {
        String msg = "";
        int kind = 0;
        while true {
            if !self.need(2) { return WebSocket::msg(8, "connection lost"); }
            int b0 = self.buf[0] & 255;
            int b1 = self.buf[1] & 255;
            int op = b0 & 15;
            bool fin = (b0 & 128) != 0;
            int len = b1 & 127;
            int p = 2;
            if len == 126 {
                if !self.need(4) { return WebSocket::msg(8, "connection lost"); }
                len = ((self.buf[2] & 255) << 8) | (self.buf[3] & 255);
                p = 4;
            } else if len == 127 {
                if !self.need(10) { return WebSocket::msg(8, "connection lost"); }
                len = 0;
                for k in 2..10 { len = (len << 8) | (self.buf[k] & 255); }
                p = 10;
            }
            if !self.need(p + len) { return WebSocket::msg(8, "connection lost"); }
            String payload = self.buf.slice(p, p + len) + "";
            String left = self.buf.slice(p + len, self.buf.len) + "";
            self.buf = left;
            if op == 9 { self.send_frame(10, payload); continue; }
            if op == 10 { continue; }
            if op == 8 {
                self.send_frame(8, "");
                self.open = false;
                String why = "";
                if payload.len > 2 { why = payload.slice(2, payload.len) + ""; }
                return WebSocket::msg(8, why);
            }
            if op == 1 || op == 2 { kind = op; msg = payload; } else { msg = msg + payload; }
            if fin { return WebSocket::msg(kind, msg); }
        }
        return WebSocket::msg(8, "");
    }

    // the file number under the connection (for a TLS connection: the socket below it)
    int fd(self) {
        if self.secure == 0 { return self.h; }
        return Crypto::tls_geti((char^)self.h, 0);
    }

    // like recv, but waits at most ms milliseconds for something to arrive: kind 0 and text "" when nothing came (the connection stays open)
    WsMessage recv_wait(self, int ms) {
        if self.open && self.buf.len < 2 {
            char pfd[8];
            char ts[16];
            for i in 0..8 { pfd[i] = 0; }
            for i in 0..16 { ts[i] = 0; }
            int f = self.fd();
            pfd[0] = (char)(f & 255);
            pfd[1] = (char)((f >> 8) & 255);
            pfd[2] = (char)((f >> 16) & 255);
            pfd[3] = (char)((f >> 24) & 255);
            pfd[4] = 1;                                     // POLLIN
            int sec = ms / 1000;
            int nsec = (ms % 1000) * 1000000;
            for k in 0..8 { ts[k] = (char)((sec >> (8 * k)) & 255); }
            for k in 0..8 { ts[8 + k] = (char)((nsec >> (8 * k)) & 255); }
            int rc = Sys::ppoll(@pfd, 1, @ts);
            if rc <= 0 { return WebSocket::msg(0, ""); }
        }
        return self.recv();
    }

    void close(self) {
        if self.open { self.send_frame(8, ""); }
        self.open = false;
        Net::http_chan_close(self.secure, self.h);
    }
}

// Ws::connect makes a WebSocket (a separate struct: a struct cannot give a Result of itself from its own functions)
struct Ws {
    static Result<WebSocket, Error> bad(ErrorKind k, String why) {
        return Result<WebSocket, Error>::Err(Error::make(k, why));
    }

    // headers: extra lines for the handshake, separated by \r\n ("" for none)
    static Result<WebSocket, Error> connect(String url, String headers) {
        int secure = 0;
        int plen = 5;
        int port = 80;
        if url.starts_with("wss://") { secure = 1; plen = 6; port = 443; }
        else if !url.starts_with("ws://") { return Ws::bad(ErrorKind::Invalid, "not a ws or wss address: " + url); }
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
                if ps[i] < '0' || ps[i] > '9' { return Ws::bad(ErrorKind::Invalid, "bad port in " + url); }
                port = port * 10 + (ps[i] - '0');
            }
        }
        if host.len == 0 { return Ws::bad(ErrorKind::Invalid, "no host in " + url); }
        int h = 0;
        switch Net::http_open(host, port, secure) {
            Result::Ok(x): { h = x; }
            Result::Err(e): { return Ws::bad(e.kind, e.message); }
        }
        char kb[16];
        Sys::random(@kb, 16);
        String raw = "";
        for i in 0..16 { raw.push(kb[i]); }
        String req = "GET " + path + " HTTP/1.1\r\nHost: " + hostport + "\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: " + Base64::encode(raw) + "\r\nSec-WebSocket-Version: 13\r\nUser-Agent: j2k-websocket\r\n";
        if headers.len > 0 { req = req + headers + "\r\n"; }
        req = req + "\r\n";
        switch Net::http_chan_send(secure, h, req) {
            Result::Ok(n): { }
            Result::Err(e): { Net::http_chan_close(secure, h); return Ws::bad(e.kind, e.message); }
        }
        String got = "";
        int he = 0 - 1;
        while he < 0 {
            String piece = "";
            switch Net::http_chan_recv(secure, h, 4096) {
                Result::Ok(t): { piece = t; }
                Result::Err(e): { Net::http_chan_close(secure, h); return Ws::bad(e.kind, e.message); }
            }
            if piece.len == 0 { Net::http_chan_close(secure, h); return Ws::bad(ErrorKind::Io, host + " closed the connection in the handshake"); }
            got = got + piece;
            he = got.find("\r\n\r\n");
        }
        String head = got.slice(0, he);
        if !head.starts_with("HTTP/1.1 101") {
            Net::http_chan_close(secure, h);
            String line = head;
            int eol = head.find("\r\n");
            if eol >= 0 { line = head.slice(0, eol); }
            return Ws::bad(ErrorKind::Io, "the server did not upgrade: " + line);
        }
        WebSocket ws;
        ws.secure = secure;
        ws.h = h;
        ws.open = true;
        ws.buf = got.slice(he + 4, got.len) + "";
        return Result<WebSocket, Error>::Ok(ws);
    }

}
