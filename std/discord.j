// discord 0.2.0 -- a bot of Discord in J2K: REST (send, read messages by asking) and the live Gateway (events as they happen).   #import <discord>   (needs <web>, <websocket>; license: MPL-2.0)
//   Discord bot = Discord::bot("TOKEN-of-the-bot");
//   bot.send(channel, "hello")?;                              // channel: the number of the channel (as text: Discord numbers are big)
//   DcMessages ms = bot.messages(channel, last_id, 20)?;       // the messages after last_id ("" = the newest ones), oldest first
//   for i in 0..ms.count() { DcMessage m = ms.get(i); cout << m.author << ": " << m.text << "\n"; }
//   last_id = ms.last;                                         // the number of the newest one seen (give it next time)
// The bot must be invited to the server and, to read the text of messages, "Message Content Intent" must be on in the developer portal.
//
// The Gateway (a WebSocket): the bot hears messages the moment they are written, with no asking.
//   DiscordGateway gw = Gw::connect("TOKEN", Gw::intents())?;           // INTENTS = servers, server messages, direct messages, message text
//   while true {
//       DcEvent e = gw.next(1000);                                    // waits at most 1000 ms; the heartbeat is sent by next() itself
//       if e.kind == "MESSAGE_CREATE" && !e.by_bot { bot.send(e.channel, "you said: " + e.text); }
//       if e.kind == "CLOSED" || e.kind == "RECONNECT" || e.kind == "INVALID_SESSION" { break; }     // connect again
//   }
// e.kind is "" when nothing came, "READY", "MESSAGE_CREATE" (e.id, e.channel, e.author, e.by_bot, e.text) or the name of any other event (e.raw has its JSON).
// Call next() often (the heartbeat goes out only inside it). No resume yet: after "CLOSED" connect again.
// Discord::bot_at(base, token) uses another server (a test server). Rate limits: Discord answers 429 when you ask too fast; the error says so.

#import <net>
#import <web>
#import <websocket>
#import <time>

struct DcMessage {
    String id;                         // the number of the message (text)
    String author;                     // the user name of who wrote
    bool by_bot;                       // true when a bot wrote it (answer only to people: do not answer to yourself)
    String text;
}

struct DcMessages {
    DcMessage[] list;
    String last;                       // the id of the newest message in the list ("" when it is empty)

    int count(self) { return self.list.len; }
    DcMessage get(self, int i) { return self.list[i]; }
}

struct Discord {
    String base;
    String token;

    static Discord bot(String token) {
        Discord d;
        d.base = "https://discord.com/api/v10";
        d.token = token;
        return d;
    }
    static Discord bot_at(String base, String token) {
        Discord d;
        d.base = base;
        d.token = token;
        return d;
    }

    String auth(self) { return "Authorization: Bot " + self.token; }

    // the text of the answer of a call, or the reason (with the "message" that Discord gives)
    Result<String, Error> call(self, String method, String path, String json) {
        Result<HttpResponse, Error> rr = Web::request(method, self.base + path, self.auth() + "\r\nContent-Type: application/json", json);
        switch rr {
            Result::Ok(r): {
                if r.status >= 200 && r.status < 300 { return Result<String, Error>::Ok(r.body); }
                String why = "HTTP " + str(r.status);
                Result<JsonDoc, Error> pj = Json::parse(r.body);
                switch pj {
                    Result::Ok(d): {
                        int mn = d.get(0, "message");
                        if mn >= 0 { why = "Discord: " + d.text(mn) + " (HTTP " + str(r.status) + ")"; }
                    }
                    Result::Err(e2): { }
                }
                return Result<String, Error>::Err(Error::make(ErrorKind::Io, why));
            }
            Result::Err(e): { return Result<String, Error>::Err(Error::make(e.kind, e.message)); }
        }
        return Result<String, Error>::Err(Error::make(ErrorKind::Io, "no answer"));
    }

    // a message of text to a channel
    Result<int, Error> send(self, String channel, String text) {
        String body = "{\"content\":" + Json::quote(text) + "}";
        Result<String, Error> r = self.call("POST", "/channels/" + channel + "/messages", body);
        switch r {
            Result::Ok(t): { return Result<int, Error>::Ok(1); }
            Result::Err(e): { return Result<int, Error>::Err(Error::make(e.kind, e.message)); }
        }
        return Result<int, Error>::Ok(1);
    }

    // the messages of a channel after the message `after` (text; "" for the newest ones), at most `limit` (1 to 100), the oldest first
    Result<DcMessages, Error> messages(self, String channel, String after, int limit) {
        String path = "/channels/" + channel + "/messages?limit=" + str(limit);
        if after.len > 0 { path = path + "&after=" + after; }
        Result<String, Error> r = self.call("GET", path, "");
        switch r {
            Result::Ok(answer): {
                Result<JsonDoc, Error> pj = Json::parse(answer);
                switch pj {
                    Result::Ok(d): {
                        DcMessages ms;
                        ms.list = arr(4);
                        ms.last = after;
                        int n = d.len(0);
                        int i = n - 1;
                        while i >= 0 {                                      // Discord gives the newest first: the list is turned over
                            int node = d.at(0, i);
                            DcMessage m;
                            m.id = "";
                            int idn = d.get(node, "id");
                            if idn >= 0 { m.id = d.text(idn); }
                            m.text = "";
                            int tn = d.get(node, "content");
                            if tn >= 0 { m.text = d.text(tn); }
                            m.author = "";
                            m.by_bot = false;
                            int an = d.get(node, "author");
                            if an >= 0 {
                                int un = d.get(an, "username");
                                if un >= 0 { m.author = d.text(un); }
                                int bn = d.get(an, "bot");
                                if bn >= 0 { m.by_bot = d.boolean(bn); }
                            }
                            ms.list.push(m);
                            ms.last = m.id;
                            i -= 1;
                        }
                        return Result<DcMessages, Error>::Ok(ms);
                    }
                    Result::Err(e2): { return Result<DcMessages, Error>::Err(Error::make(ErrorKind::Parse, "Discord sent no JSON")); }
                }
            }
            Result::Err(e): { return Result<DcMessages, Error>::Err(Error::make(e.kind, e.message)); }
        }
        DcMessages empty;
        empty.list = arr(1);
        empty.last = after;
        return Result<DcMessages, Error>::Ok(empty);
    }
}

struct DcEvent {
    String kind;                       // "" nothing, "READY", "MESSAGE_CREATE", "CLOSED", "RECONNECT", "INVALID_SESSION", or another event name
    String id;                         // MESSAGE_CREATE: the number of the message
    String channel;                    // the number of the channel
    String author;
    bool by_bot;
    String text;
    String raw;                        // the JSON of "d" for any event
}

struct DiscordGateway {
    WebSocket ws;
    String token;
    int intents;
    int interval;                      // ms between heartbeats (0 until Discord says hello)
    int next_beat;                     // the time (ms) of the next heartbeat
    int seq;                           // the last sequence number seen (-1: none)
    bool identified;

    static DcEvent event(String kind) {
        DcEvent e;
        e.kind = kind + "";
        e.id = "";
        e.channel = "";
        e.author = "";
        e.by_bot = false;
        e.text = "";
        e.raw = "";
        return e;
    }

    void beat(self) {
        String d = "null";
        if self.seq >= 0 { d = str(self.seq); }
        self.ws.send_text("{\"op\":1,\"d\":" + d + "}");
        self.next_beat = Time::now_ms() + self.interval;
    }

    // the next event, waiting at most wait_ms (the heartbeat is sent when it is due)
    DcEvent next(self, int wait_ms) {
        int deadline = Time::now_ms() + wait_ms;
        while true {
            int now = Time::now_ms();
            if self.interval > 0 && now >= self.next_beat { self.beat(); }
            int left = deadline - now;
            if left < 0 { left = 0; }
            int slice = left;
            if self.interval > 0 {
                int to_beat = self.next_beat - now;
                if to_beat < 0 { to_beat = 0; }
                if to_beat < slice { slice = to_beat; }
            }
            WsMessage m = self.ws.recv_wait(slice);
            if m.kind == 8 { return DiscordGateway::event("CLOSED"); }
            if m.kind == 0 {
                if Time::now_ms() >= deadline { return DiscordGateway::event(""); }
                continue;
            }
            int op = 0 - 1;
            String t = "";
            String body = "";
            int sq = 0 - 1;
            int hb = 0;
            Result<JsonDoc, Error> pj = Json::parse(m.text);
            switch pj {
                Result::Ok(d): {
                    int on = d.get(0, "op");
                    if on >= 0 { op = d.integer(on); }
                    int tn = d.get(0, "t");
                    if tn >= 0 && !d.is_null(tn) { t = d.text(tn) + ""; }
                    int sn = d.get(0, "s");
                    if sn >= 0 && !d.is_null(sn) { sq = d.integer(sn); }
                    int dn = d.get(0, "d");
                    if dn >= 0 {
                        body = d.dump(dn) + "";
                        int hn = d.get(dn, "heartbeat_interval");
                        if hn >= 0 { hb = d.integer(hn); }
                    }
                }
                Result::Err(e): { continue; }
            }
            if sq >= 0 { self.seq = sq; }
            if op == 10 {
                self.interval = hb;
                if self.interval <= 0 { self.interval = 40000; }
                self.next_beat = Time::now_ms() + self.interval / 2;
                String ident = "{\"op\":2,\"d\":\x7b\"token\":" + Json::quote(self.token) + ",\"intents\":" + str(self.intents);
                ident = ident + ",\"properties\":\x7b\"os\":\"linux\",\"browser\":\"j2k\",\"device\":\"j2k\"\x7d\x7d\x7d";
                self.ws.send_text(ident);
                self.identified = true;
                continue;
            }
            if op == 1 { self.beat(); continue; }
            if op == 7 { return DiscordGateway::event("RECONNECT"); }
            if op == 9 { return DiscordGateway::event("INVALID_SESSION"); }
            if op != 0 { continue; }
            DcEvent ev = DiscordGateway::event(t);
            ev.raw = body;
            if t == "MESSAGE_CREATE" {
                Result<JsonDoc, Error> pm = Json::parse(body);
                switch pm {
                    Result::Ok(d2): {
                        int idn = d2.get(0, "id");
                        if idn >= 0 { ev.id = d2.text(idn) + ""; }
                        int chn = d2.get(0, "channel_id");
                        if chn >= 0 { ev.channel = d2.text(chn) + ""; }
                        int cn = d2.get(0, "content");
                        if cn >= 0 { ev.text = d2.text(cn) + ""; }
                        int an = d2.get(0, "author");
                        if an >= 0 {
                            int un = d2.get(an, "username");
                            if un >= 0 { ev.author = d2.text(un) + ""; }
                            int bn = d2.get(an, "bot");
                            if bn >= 0 { ev.by_bot = d2.boolean(bn); }
                        }
                    }
                    Result::Err(e3): { }
                }
            }
            return ev;
        }
        return DiscordGateway::event("");
    }

    void close(self) { self.ws.close(); }
}

struct Gw {
    // servers (1), server messages (512), direct messages (4096) and the text of messages (32768)
    static int intents() { return 1 + 512 + 4096 + 32768; }

    static Result<DiscordGateway, Error> connect_at(String url, String token, int intents) {
        Result<WebSocket, Error> r = Ws::connect(url, "");
        switch r {
            Result::Ok(w): {
                DiscordGateway g;
                g.ws = w;
                g.token = token + "";
                g.intents = intents;
                g.interval = 0;
                g.next_beat = 0;
                g.seq = 0 - 1;
                g.identified = false;
                return Result<DiscordGateway, Error>::Ok(g);
            }
            Result::Err(e): { return Result<DiscordGateway, Error>::Err(Error::make(e.kind, e.message)); }
        }
        return Result<DiscordGateway, Error>::Err(Error::make(ErrorKind::Io, "connect failed"));
    }

    static Result<DiscordGateway, Error> connect(String token, int intents) {
        return Gw::connect_at("wss://gateway.discord.gg/?v=10&encoding=json", token, intents);
    }
}
