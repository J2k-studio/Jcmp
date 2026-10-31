#include <cstdio>
#include <cstdlib>
#include <vector>
static int fib(int n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }
int main(int argc, char **argv) {
    int w = atoi(argv[1]);
    if (w == 0) printf("%d\n", fib(35));
    if (w == 1) { std::vector<float> x(1000, 1.5f); float s = 0; for (int r = 0; r < 20000; r++) for (int k = 0; k < 1000; k++) s += x[k]; printf("%f\n", s); }
    if (w == 2) { std::vector<float> x(1000, 1.5f), y(1000, 0.f); for (int r = 0; r < 20000; r++) for (int k = 0; k < 1000; k++) y[k] = y[k] * 0.5f + x[k]; printf("%f\n", y[7]); }
    if (w == 3) { std::vector<long> x(1000); for (int i = 0; i < 1000; i++) x[i] = i; long s = 0; for (int r = 0; r < 20000; r++) for (int k = 0; k < 1000; k++) s += x[k]; printf("%ld\n", s); }
    if (w == 4) { int n = 5000000; std::vector<char> f(n + 1, 1); long c = 0; for (long i = 2; i <= n; i++) if (f[i]) { c++; for (long j = i * 2; j <= n; j += i) f[j] = 0; } printf("%ld\n", c); }
    if (w == 5) { long s = 0; for (int r = 0; r < 1000000; r++) { std::vector<long> t; t.reserve(8); t.push_back(r); t.push_back(2); s += t[0] + t[1]; } printf("%ld\n", s); }
    return 0;
}
