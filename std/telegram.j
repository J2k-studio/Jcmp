// telegram 0.1.0 -- a bot of Telegram in J2K.   #import <telegram>   (needs <web>, <json>; license: MPL-2.0)
//   Telegram bot = Telegram::bot("123456:ABC-token-from-BotFather");
//   bot.send(chat, "hello")?;                                     // a message to a chat (the number of the chat)
//   int next = 0;
//   while true {
//       TgUpdates up = bot.poll(next, 25)?;                       // waits up to 25 seconds for news (long polling)
//       for i in 0..up.count() {
//           TgMessage m = up.get(i);                              // m.chat  m.from  m.text  m.update_id
//           bot.send(m.chat, "you said: " + m.text)?;
//           next = m.update_id + 1;
//       }
//   }
// bot.me() asks who the bot is; Telegram::bot_at(base, token) uses another server (a test server: "http://127.0.0.1:8081").
// The messages are text only in this first version (other updates are skipped, but their numbers are counted: up.next says where to go on).

#import <net>
#import <web>

struct TgMessage {
    int update_id;
    int chat;                          // the number of the chat to answer to
    String from;                       // the first name (or the username) of who wrote
    String text;
}

struct TgUpdates {
    TgMessage[] list;
    int next;                          // the offset for the next poll (the biggest update_id + 1; the one you gave when there was nothing)

    int count(self) { return self.list.len; }
    TgMessage get(self, int i) { return self.list[i]; }
}

struct Telegram {
    String base;
    String token;

    static Telegram bot(String token) {
        Telegram t;
        t.base = "https://api.telegram.org";
        t.token = token;
        return t;
    }
    static Telegram bot_at(String base, String token) {
        Telegram t;
        t.base = base;
        t.token = token;
        return t;
    }

    String url(self, String method) { return self.base + "/bot" + self.token + "/" + method; }

    // one call of the API: the answer must be {"ok":true,"result":...}; the text of the answer, or the reason
    Result<String, Error> call(self, String method, String json) {
        Result<HttpResponse, Error> rr = Web::post_json(self.url(method), "", json);
        HttpResponse resp;
        switch rr {
            Result::Ok(r): { resp = r; }
            Result::Err(e): { return Result<String, Error>::Err(Error::make(e.kind, e.message)); }
        }
        Result<JsonDoc, Error> pj = Json::parse(resp.body);
        switch pj {
            Result::Ok(d): {
                int okn = d.get(0, "ok");
                bool is_ok = false;
                if okn >= 0 { is_ok = d.boolean(okn); }
                if !is_ok {
                    String why = "";
                    int dn = d.get(0, "description");
                    if dn >= 0 { why = d.text(dn); }
                    if why.len == 0 { why = "HTTP " + str(resp.status); }
                    return Result<String, Error>::Err(Error::make(ErrorKind::Io, "Telegram: " + why));
                }
                return Result<String, Error>::Ok(resp.body);
            }
            Result::Err(e): { return Result<String, Error>::Err(Error::make(ErrorKind::Parse, "Telegram sent no JSON (HTTP " + str(resp.status) + ")")); }
        }
        return Result<String, Error>::Err(Error::make(ErrorKind::Parse, "no answer"));
    }

    // who the bot is: the user name
    Result<String, Error> me(self) {
        Result<String, Error> r = self.call("getMe", "{}");
        switch r {
            Result::Ok(text): {
              Result<JsonDoc, Error> pj = Json::parse(text);
              switch pj {
                Result::Ok(d): {
                int res = d.get(0, "result");
                String uname = "";
                if res >= 0 {
                    int un = d.get(res, "username");
                    if un >= 0 { uname = d.text(un); }
                }
                return Result<String, Error>::Ok(uname);
                }
                Result::Err(e2): { return Result<String, Error>::Err(Error::make(e2.kind, e2.message)); }
              }
            }
            Result::Err(e): { return Result<String, Error>::Err(Error::make(e.kind, e.message)); }
        }
        return Result<String, Error>::Ok("");
    }

    // a message of text to a chat
    Result<int, Error> send(self, int chat, String text) {
        String body = "{\"chat_id\":" + str(chat) + ",\"text\":" + Json::quote(text) + "}";
        Result<String, Error> r = self.call("sendMessage", body);
        switch r {
            Result::Ok(d): { return Result<int, Error>::Ok(1); }
            Result::Err(e): { return Result<int, Error>::Err(Error::make(e.kind, e.message)); }
        }
        return Result<int, Error>::Ok(1);
    }

    // the news since the offset; seconds is how long the server may wait for a message (0: answer at once)
    Result<TgUpdates, Error> poll(self, int offset, int seconds) {
        String body = "{\"offset\":" + str(offset) + ",\"timeout\":" + str(seconds) + ",\"allowed_updates\":[\"message\"]}";
        Result<String, Error> r = self.call("getUpdates", body);
        switch r {
            Result::Ok(answer): {
              Result<JsonDoc, Error> pj = Json::parse(answer);
              switch pj {
                Result::Ok(d): {
                TgUpdates u;
                u.list = arr(4);
                u.next = offset;
                int res = d.get(0, "result");
                int n = 0;
                if res >= 0 { n = d.len(res); }
                for i in 0..n {
                    int up = d.at(res, i);
                    int id = 0;
                    int idn = d.get(up, "update_id");
                    if idn >= 0 { id = d.integer(idn); }
                    if id + 1 > u.next { u.next = id + 1; }
                    int msg = d.get(up, "message");
                    if msg < 0 { continue; }
                    String text = "";
                    int tn = d.get(msg, "text");
                    if tn >= 0 { text = d.text(tn); }
                    if text.len == 0 { continue; }
                    TgMessage m;
                    m.update_id = id;
                    m.chat = 0;
                    int chn = d.get(msg, "chat");
                    if chn >= 0 {
                        int cid = d.get(chn, "id");
                        if cid >= 0 { m.chat = d.integer(cid); }
                    }
                    String who = "";
                    int frn = d.get(msg, "from");
                    if frn >= 0 {
                        int fnn = d.get(frn, "first_name");
                        if fnn >= 0 { who = d.text(fnn); }
                        if who.len == 0 {
                            int unn = d.get(frn, "username");
                            if unn >= 0 { who = d.text(unn); }
                        }
                    }
                    m.from = who;
                    m.text = text;
                    u.list.push(m);
                }
                return Result<TgUpdates, Error>::Ok(u);
                }
                Result::Err(e2): { return Result<TgUpdates, Error>::Err(Error::make(e2.kind, e2.message)); }
              }
            }
            Result::Err(e): { return Result<TgUpdates, Error>::Err(Error::make(e.kind, e.message)); }
        }
        TgUpdates empty;
        empty.list = arr(1);
        empty.next = offset;
        return Result<TgUpdates, Error>::Ok(empty);
    }
}
