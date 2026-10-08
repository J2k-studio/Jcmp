// quat: a rotation in 3D as four numbers (a quaternion x, y, z, w). #import <math>   using math::quat;
//   quat q = quat::from_axis_angle(vec3::make(0.0, 1.0, 0.0), Math::pi() / 2.0);   (a quarter turn about the y axis)
//   vec3 v = q.rotate(vec3::make(1.0, 0.0, 0.0));         q * r  turns by r first, then by q
struct quat {
    double x;
    double y;
    double z;
    double w;
    static quat make(double x, double y, double z, double w) {
        quat r;
        r.x = x;
        r.y = y;
        r.z = z;
        r.w = w;
        return r;
    }
    static quat identity() { return quat::make(0.0, 0.0, 0.0, 1.0); }
    // a turn of the angle (radians) about an axis (it need not have length 1)
    static quat from_axis_angle(vec3 axis, double angle) {
        vec3 a = axis.normalize();
        double s = Math::sin(angle / 2.0);
        return quat::make(a.x * s, a.y * s, a.z * s, Math::cos(angle / 2.0));
    }
    // the Hamilton product: this turn after the other
    operator quat mul(self, quat o) {
        return quat::make(
            self.w * o.x + self.x * o.w + self.y * o.z - self.z * o.y,
            self.w * o.y - self.x * o.z + self.y * o.w + self.z * o.x,
            self.w * o.z + self.x * o.y - self.y * o.x + self.z * o.w,
            self.w * o.w - self.x * o.x - self.y * o.y - self.z * o.z);
    }
    operator bool eq(self, quat o) { return self.x == o.x && self.y == o.y && self.z == o.z && self.w == o.w; }
    quat conj(self) { return quat::make(0.0 - self.x, 0.0 - self.y, 0.0 - self.z, self.w); }
    double dot(self, quat o) { return self.x * o.x + self.y * o.y + self.z * o.z + self.w * o.w; }
    double length(self) { return Math::sqrt(self.dot(self^)); }
    quat normalize(self) {
        double l = self.length();
        if l == 0.0 { return quat::identity(); }
        return quat::make(self.x / l, self.y / l, self.z / l, self.w / l);
    }
    // the vector turned by this rotation
    vec3 rotate(self, vec3 v) {
        quat p = quat::make(v.x, v.y, v.z, 0.0);
        quat r = self.mul(p).mul(self.conj());
        return vec3::make(r.x, r.y, r.z);
    }
    // between this rotation (t = 0) and the other (t = 1), by the shortest way on the sphere
    quat slerp(self, quat o, double t) {
        double d = self.dot(o);
        quat b = o;
        if d < 0.0 {
            b = quat::make(0.0 - o.x, 0.0 - o.y, 0.0 - o.z, 0.0 - o.w);
            d = 0.0 - d;
        }
        if d > 0.9995 {
            // nearly the same: a straight line, then made length 1
            return quat::make(self.x + (b.x - self.x) * t, self.y + (b.y - self.y) * t, self.z + (b.z - self.z) * t, self.w + (b.w - self.w) * t).normalize();
        }
        double th = Math::acos(d);
        double s = Math::sin(th);
        double ka = Math::sin((1.0 - t) * th) / s;
        double kb = Math::sin(t * th) / s;
        return quat::make(self.x * ka + b.x * kb, self.y * ka + b.y * kb, self.z * ka + b.z * kb, self.w * ka + b.w * kb);
    }
}
