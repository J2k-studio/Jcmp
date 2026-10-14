// Log: messages for the person who runs the program, on the error output (standard error), with a level.
//   Log::set_level(2);    Log::info("not shown");    Log::error("shown: " + str(code));
// levels: 0 debug, 1 info, 2 warn, 3 error (the default is 1)
int std_log_level = 1;

struct Log {
    static void set_level(int level) { std_log_level = level; }
    static int level() { return std_log_level; }
    static void write(int level, String name, String msg) {
        if level < std_log_level { return; }
        String line = "[" + name + "] " + msg + "\n";
        Sys::write(2, line.c(), line.len);
    }
    static void debug(String msg) { Log::write(0, "debug", msg); }
    static void info(String msg) { Log::write(1, "info", msg); }
    static void warn(String msg) { Log::write(2, "warn", msg); }
    static void error(String msg) { Log::write(3, "error", msg); }
}
