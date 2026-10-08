// cplx: a complex number re + im i. #import <math>   using math::complex;
//   cplx a = cplx::make(1.0, 2.0);   cplx b = a * a + cplx::make(0.0, 1.0);   double r = b.abs();
struct cplx {
    double re;
    double im;
    static cplx make(double re, double im) {
        cplx r;
        r.re = re;
        r.im = im;
        return r;
    }
    static cplx from_polar(double r, double theta) { return cplx::make(r * Math::cos(theta), r * Math::sin(theta)); }
    operator cplx add(self, cplx o) { return cplx::make(self.re + o.re, self.im + o.im); }
    operator cplx sub(self, cplx o) { return cplx::make(self.re - o.re, self.im - o.im); }
    operator cplx mul(self, cplx o) { return cplx::make(self.re * o.re - self.im * o.im, self.re * o.im + self.im * o.re); }
    operator cplx div(self, cplx o) {
        double d = o.re * o.re + o.im * o.im;
        return cplx::make((self.re * o.re + self.im * o.im) / d, (self.im * o.re - self.re * o.im) / d);
    }
    operator cplx neg(self) { return cplx::make(0.0 - self.re, 0.0 - self.im); }
    operator bool eq(self, cplx o) { return self.re == o.re && self.im == o.im; }
    cplx conj(self) { return cplx::make(self.re, 0.0 - self.im); }
    double abs(self) { return Math::sqrt(self.re * self.re + self.im * self.im); }
    // the angle, -pi..pi
    double arg(self) { return Math::atan2(self.im, self.re); }
    cplx exp(self) { return cplx::from_polar(Math::exp(self.re), self.im); }
    // the whole power n >= 0
    cplx powi(self, int n) {
        cplx r = cplx::make(1.0, 0.0);
        cplx b = self^;
        int k = n;
        while k > 0 {
            if k % 2 == 1 { r = r * b; }
            b = b * b;
            k = k / 2;
        }
        return r;
    }
}
