// Mat3, Mat4: square matrices of doubles, row by row; a vector is a column: v' = M.mul_vec(v), and M.mul(N) applies N first. #import <matrix>

struct Mat3 {
    double m[9];                 // row by row: m[row * 3 + column]
    static Mat3 identity() {
        Mat3 r;
        for i in 0..9 { r.m[i] = 0.0; }
        r.m[0] = 1.0;
        r.m[4] = 1.0;
        r.m[8] = 1.0;
        return r;
    }
    static Mat3 zero() {
        Mat3 r;
        for i in 0..9 { r.m[i] = 0.0; }
        return r;
    }
    double get(self, int row, int col) { return self.m[row * 3 + col]; }
    Mat3 mul(self, Mat3 o) {
        Mat3 r;
        for i in 0..3 {
            for j in 0..3 {
                double s = 0.0;
                for k in 0..3 { s += self.m[i * 3 + k] * o.m[k * 3 + j]; }
                r.m[i * 3 + j] = s;
            }
        }
        return r;
    }
    Vec3 mul_vec(self, Vec3 v) {
        Vec3 r;
        r.x = self.m[0] * v.x + self.m[1] * v.y + self.m[2] * v.z;
        r.y = self.m[3] * v.x + self.m[4] * v.y + self.m[5] * v.z;
        r.z = self.m[6] * v.x + self.m[7] * v.y + self.m[8] * v.z;
        return r;
    }
    Mat3 transpose(self) {
        Mat3 r;
        for i in 0..3 { for j in 0..3 { r.m[j * 3 + i] = self.m[i * 3 + j]; } }
        return r;
    }

    static Mat3 scale(double x, double y, double z) {
        Mat3 r = Mat3::identity();
        r.m[0] = x;
        r.m[4] = y;
        r.m[8] = z;
        return r;
    }
    // rotation about the X axis, the angle in radians (counter-clockwise looking against the axis)
    static Mat3 rotate_x(double a) {
        Mat3 r = Mat3::identity();
        double c = Math::cos(a);
        double s = Math::sin(a);
        r.m[4] = c;
        r.m[5] = 0.0 - s;
        r.m[7] = s;
        r.m[8] = c;
        return r;
    }
    // rotation about the Y axis, the angle in radians (counter-clockwise looking against the axis)
    static Mat3 rotate_y(double a) {
        Mat3 r = Mat3::identity();
        double c = Math::cos(a);
        double s = Math::sin(a);
        r.m[8] = c;
        r.m[6] = 0.0 - s;
        r.m[2] = s;
        r.m[0] = c;
        return r;
    }
    // rotation about the Z axis, the angle in radians (counter-clockwise looking against the axis)
    static Mat3 rotate_z(double a) {
        Mat3 r = Mat3::identity();
        double c = Math::cos(a);
        double s = Math::sin(a);
        r.m[0] = c;
        r.m[1] = 0.0 - s;
        r.m[3] = s;
        r.m[4] = c;
        return r;
    }
    double determinant(self) {
        return self.m[0] * (self.m[4] * self.m[8] - self.m[5] * self.m[7])
             - self.m[1] * (self.m[3] * self.m[8] - self.m[5] * self.m[6])
             + self.m[2] * (self.m[3] * self.m[7] - self.m[4] * self.m[6]);
    }
}

struct Mat4 {
    double m[16];                 // row by row: m[row * 4 + column]
    static Mat4 identity() {
        Mat4 r;
        for i in 0..16 { r.m[i] = 0.0; }
        r.m[0] = 1.0;
        r.m[5] = 1.0;
        r.m[10] = 1.0;
        r.m[15] = 1.0;
        return r;
    }
    static Mat4 zero() {
        Mat4 r;
        for i in 0..16 { r.m[i] = 0.0; }
        return r;
    }
    double get(self, int row, int col) { return self.m[row * 4 + col]; }
    Mat4 mul(self, Mat4 o) {
        Mat4 r;
        for i in 0..4 {
            for j in 0..4 {
                double s = 0.0;
                for k in 0..4 { s += self.m[i * 4 + k] * o.m[k * 4 + j]; }
                r.m[i * 4 + j] = s;
            }
        }
        return r;
    }
    Vec4 mul_vec(self, Vec4 v) {
        Vec4 r;
        r.x = self.m[0] * v.x + self.m[1] * v.y + self.m[2] * v.z + self.m[3] * v.w;
        r.y = self.m[4] * v.x + self.m[5] * v.y + self.m[6] * v.z + self.m[7] * v.w;
        r.z = self.m[8] * v.x + self.m[9] * v.y + self.m[10] * v.z + self.m[11] * v.w;
        r.w = self.m[12] * v.x + self.m[13] * v.y + self.m[14] * v.z + self.m[15] * v.w;
        return r;
    }
    Mat4 transpose(self) {
        Mat4 r;
        for i in 0..4 { for j in 0..4 { r.m[j * 4 + i] = self.m[i * 4 + j]; } }
        return r;
    }

    static Mat4 scale(double x, double y, double z) {
        Mat4 r = Mat4::identity();
        r.m[0] = x;
        r.m[5] = y;
        r.m[10] = z;
        return r;
    }
    // rotation about the X axis, the angle in radians (counter-clockwise looking against the axis)
    static Mat4 rotate_x(double a) {
        Mat4 r = Mat4::identity();
        double c = Math::cos(a);
        double s = Math::sin(a);
        r.m[5] = c;
        r.m[6] = 0.0 - s;
        r.m[9] = s;
        r.m[10] = c;
        return r;
    }
    // rotation about the Y axis, the angle in radians (counter-clockwise looking against the axis)
    static Mat4 rotate_y(double a) {
        Mat4 r = Mat4::identity();
        double c = Math::cos(a);
        double s = Math::sin(a);
        r.m[10] = c;
        r.m[8] = 0.0 - s;
        r.m[2] = s;
        r.m[0] = c;
        return r;
    }
    // rotation about the Z axis, the angle in radians (counter-clockwise looking against the axis)
    static Mat4 rotate_z(double a) {
        Mat4 r = Mat4::identity();
        double c = Math::cos(a);
        double s = Math::sin(a);
        r.m[0] = c;
        r.m[1] = 0.0 - s;
        r.m[4] = s;
        r.m[5] = c;
        return r;
    }
    static Mat4 translate(double x, double y, double z) {
        Mat4 r = Mat4::identity();
        r.m[3] = x;
        r.m[7] = y;
        r.m[11] = z;
        return r;
    }
    // a point (w = 1): moved, rotated and scaled; the w is left as it is
    Vec3 point(self, Vec3 p) {
        return Vec3::make(self.m[0] * p.x + self.m[1] * p.y + self.m[2] * p.z + self.m[3], self.m[4] * p.x + self.m[5] * p.y + self.m[6] * p.z + self.m[7], self.m[8] * p.x + self.m[9] * p.y + self.m[10] * p.z + self.m[11]);
    }
    // a direction (w = 0): not moved
    Vec3 direction(self, Vec3 d) {
        return Vec3::make(self.m[0] * d.x + self.m[1] * d.y + self.m[2] * d.z, self.m[4] * d.x + self.m[5] * d.y + self.m[6] * d.z, self.m[8] * d.x + self.m[9] * d.y + self.m[10] * d.z);
    }
    // a point through a projection: divided by w (x, y, z in -1..1 are inside the view)
    Vec3 project(self, Vec3 p) {
        Vec4 q = self.mul_vec(Vec4::make(p.x, p.y, p.z, 1.0));
        if q.w == 0.0 { return Vec3::make(q.x, q.y, q.z); }
        return Vec3::make(q.x / q.w, q.y / q.w, q.z / q.w);
    }
    // perspective: fov_y in radians, aspect = width / height, the view looks down -z, z in -1..1 (like OpenGL)
    static Mat4 perspective(double fov_y, double aspect, double near, double far) {
        Mat4 r = Mat4::zero();
        double f = 1.0 / Math::tan(fov_y / 2.0);
        r.m[0] = f / aspect;
        r.m[5] = f;
        r.m[10] = (far + near) / (near - far);
        r.m[11] = 2.0 * far * near / (near - far);
        r.m[14] = 0.0 - 1.0;
        return r;
    }
    // the camera at eye looks at center, up says where up is
    static Mat4 look_at(Vec3 eye, Vec3 center, Vec3 up) {
        Vec3 f = center.sub(eye).normalize();
        Vec3 s = f.cross(up).normalize();
        Vec3 u = s.cross(f);
        Mat4 r = Mat4::identity();
        r.m[0] = s.x;
        r.m[1] = s.y;
        r.m[2] = s.z;
        r.m[4] = u.x;
        r.m[5] = u.y;
        r.m[6] = u.z;
        r.m[8] = 0.0 - f.x;
        r.m[9] = 0.0 - f.y;
        r.m[10] = 0.0 - f.z;
        r.m[3] = 0.0 - s.dot(eye);
        r.m[7] = 0.0 - u.dot(eye);
        r.m[11] = f.dot(eye);
        return r;
    }
}
