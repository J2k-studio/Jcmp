// Stats: numbers about a list of numbers (double[]). #import <math>   using math::stats;
//   double[] xs = arr(3);   xs.push(2.0);   xs.push(4.0);   xs.push(9.0);   double m = Stats::mean(xs);
struct Stats {
    static double sum(double[] xs) {
        double s = 0.0;
        for i in 0..xs.len { s += xs[i]; }
        return s;
    }
    static double mean(double[] xs) {
        if xs.len == 0 { return 0.0; }
        return Stats::sum(xs) / (double)xs.len;
    }
    static double min(double[] xs) {
        if xs.len == 0 { return 0.0; }
        double m = xs[0];
        for i in 1..xs.len { if xs[i] < m { m = xs[i]; } }
        return m;
    }
    static double max(double[] xs) {
        if xs.len == 0 { return 0.0; }
        double m = xs[0];
        for i in 1..xs.len { if xs[i] > m { m = xs[i]; } }
        return m;
    }
    // the variance of the whole list (divided by n)
    static double variance(double[] xs) {
        if xs.len == 0 { return 0.0; }
        double m = Stats::mean(xs);
        double s = 0.0;
        for i in 0..xs.len { s += (xs[i] - m) * (xs[i] - m); }
        return s / (double)xs.len;
    }
    static double stddev(double[] xs) { return Math::sqrt(Stats::variance(xs)); }
    // the middle value (the mean of the two middle ones if the number is even)
    static double median(double[] xs) {
        int n = xs.len;
        if n == 0 { return 0.0; }
        double[] c = arr(n);
        for i in 0..n { c.push(xs[i]); }
        for i in 1..n {
            double v = c[i];
            int j = i - 1;
            while j >= 0 && c[j] > v {
                c[j + 1] = c[j];
                j -= 1;
            }
            c[j + 1] = v;
        }
        double r = c[n / 2];
        if n % 2 == 0 { r = (c[n / 2 - 1] + c[n / 2]) / 2.0; }
        c.free();
        return r;
    }
}
