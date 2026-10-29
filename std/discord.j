// discord 0.1.0 -- a bot of Discord in J2K (the REST part: send and read messages by asking; the live Gateway comes later).   #import <discord>   (needs <web>; license: MPL-2.0)
//   Discord bot = Discord::bot("TOKEN-of-the-bot");
//   bot.send(channel, "hello")?;                              // channel: the number of the channel (as text: Discord numbers are big)
//   DcMessages ms = bot.messages(channel, last_id, 20)?;       // the messages after last_id ("" = the newest ones), oldest first
//   for i in 0..ms.count() { DcMessage m = ms.get(i); cout << m.author << ": " << m.text << "\n"; }
//   last_id = ms.last;                                         // the number of the newest one seen (give it next time)
// The bot must be invited to the server and, to read the text of messages, "Message Content Intent" must be on in the developer portal.
// Discord::bot_at(base, token) uses another server (a test server). Rate limits: Discord answers 429 when you ask too fast; the error says so.

#import <net>
#import <web>

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
