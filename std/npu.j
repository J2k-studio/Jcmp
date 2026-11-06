// npu 0.1.0 -- the NPU of the phone through NNAPI: a layer with FIXED weights, y = x * W^T + bias.   #import <npu>   (a program that uses it is built like one that uses <native>)
//   if Npu::available() {
//       NpuLinear l = NpuLinear::make(w, bias, 64, 256, 256);   // w: 256 x 256 numbers (row i = the weights of output i), bias: 256 numbers or null; 64 rows of x at a time
//       l.run(x, y);                                            // x: 64 x 256, y: 64 x 256 (float32 in, float32 out)
//       l.destroy();
//   }
// What was measured on a Kirin 990 (docs/design/26): one product of 512 x 512 x 512 in 8.8 ms (our NEON CPU 37 ms, the GPU 15 ms), 256 in 4.6 ms (CPU 5.5, GPU 3.6),
// 128 in 3.2 ms (CPU 1.0; a call costs about 3 ms, so for one row at a time (m = 1) the CPU wins; from 8 rows the NPU is level or faster). Making the model for a weight matrix takes about 70 ms (measured with 256 x 256 and 512 x 512), so use it for inference
// (the weights stay) and not for training (the weights change at every step). The NPU computes in half precision: numbers above 65504 overflow and the digits are about 3.
// The weights must be constants of the model: NNAPI on this phone refuses a model whose weights are an input (error 4). Biggest size tried: 512; 1024 was too slow.
// Without NNAPI or without an NPU device `available()` is false and `make` gives a layer with ok = false: the program goes on with the CPU.
#import <native>

i64 npu_lib;
i64 npu_dev;                  // the NNAPI device that is the NPU (the first one that is not the reference CPU), or 0
i64 npu_tried;
i64 npu_f_model_create;
i64 npu_f_add_operand;
i64 npu_f_set_value;
i64 npu_f_add_operation;
i64 npu_f_identify;
i64 npu_f_relax;
i64 npu_f_finish;
i64 npu_f_comp_create;
i64 npu_f_comp_finish;
i64 npu_f_exec_create;
i64 npu_f_exec_input;
i64 npu_f_exec_output;
i64 npu_f_exec_compute;
i64 npu_f_model_free;
i64 npu_f_comp_free;
i64 npu_f_exec_free;

// find NNAPI and the NPU device once
void npu_init() {
    if npu_tried == 1 { return; }
    npu_tried = 1;
    npu_lib = Native::open("libneuralnetworks.so");
    if npu_lib == 0 { return; }
    i64 cnt = (i64)Mem::alloc(16);
    Native::poke32(cnt, 0);
    i64 f = Native::sym(npu_lib, "ANeuralNetworks_getDeviceCount");
    if f == 0 || Native::call1(f, cnt) != 0 { npu_lib = 0; return; }
    i64 getd = Native::sym(npu_lib, "ANeuralNetworks_getDevice");
    i64 nameof = Native::sym(npu_lib, "ANeuralNetworksDevice_getName");
    i64 pdev = (i64)Mem::alloc(16);
    i64 pname = (i64)Mem::alloc(16);
    i64 found = 0;
    for i in 0..Native::peek32(cnt) {
        Native::poke64(pdev, 0);
        Native::call2(getd, i, pdev);
        Native::poke64(pname, 0);
        Native::call2(nameof, Native::peek64(pdev), pname);
        String nm = Native::text(Native::peek64(pname));
        if found == 0 && !(nm == "nnapi-reference") { found = Native::peek64(pdev); }
    }
    npu_dev = found;
    npu_f_model_create = Native::sym(npu_lib, "ANeuralNetworksModel_create");
    npu_f_add_operand = Native::sym(npu_lib, "ANeuralNetworksModel_addOperand");
    npu_f_set_value = Native::sym(npu_lib, "ANeuralNetworksModel_setOperandValue");
    npu_f_add_operation = Native::sym(npu_lib, "ANeuralNetworksModel_addOperation");
    npu_f_identify = Native::sym(npu_lib, "ANeuralNetworksModel_identifyInputsAndOutputs");
    npu_f_relax = Native::sym(npu_lib, "ANeuralNetworksModel_relaxComputationFloat32toFloat16");
    npu_f_finish = Native::sym(npu_lib, "ANeuralNetworksModel_finish");
    npu_f_comp_create = Native::sym(npu_lib, "ANeuralNetworksCompilation_createForDevices");
    npu_f_comp_finish = Native::sym(npu_lib, "ANeuralNetworksCompilation_finish");
    npu_f_exec_create = Native::sym(npu_lib, "ANeuralNetworksExecution_create");
    npu_f_exec_input = Native::sym(npu_lib, "ANeuralNetworksExecution_setInput");
    npu_f_exec_output = Native::sym(npu_lib, "ANeuralNetworksExecution_setOutput");
    npu_f_exec_compute = Native::sym(npu_lib, "ANeuralNetworksExecution_compute");
    npu_f_model_free = Native::sym(npu_lib, "ANeuralNetworksModel_free");
    npu_f_comp_free = Native::sym(npu_lib, "ANeuralNetworksCompilation_free");
    npu_f_exec_free = Native::sym(npu_lib, "ANeuralNetworksExecution_free");
    if npu_f_comp_create == 0 || npu_f_exec_compute == 0 || npu_f_relax == 0 { npu_dev = 0; }
}

// the type of an operand: type 3 is a tensor of float32, 1 a number of 32 bits (a scalar has no dimensions)
i64 npu_type(i64 type, i64 d0, i64 d1) {
    i64 t = (i64)Mem::alloc(48);
    for i in 0..6 { Native::poke64(t + i * 8, 0); }
    Native::poke32(t, type);
    i64 nd = 0;
    if d0 > 0 { nd = 1; }
    if d1 > 0 { nd = 2; }
    Native::poke32(t + 4, nd);
    i64 dims = t + 32;
    Native::poke32(dims, d0);
    Native::poke32(dims + 4, d1);
    if nd > 0 { Native::poke64(t + 8, dims); }                  // a scalar has no dimensions: the pointer must be null
    return t;
}

struct NpuLinear {
    bool ok;
    i64 code;                 // 0 when it worked, else the NNAPI error of the step that failed (or -1: no NPU)
    i64 model;
    i64 comp;
    i64 m;
    i64 k;
    i64 n;

    // w: n x k numbers (row-major), bias: n numbers or null; x has m rows
    static NpuLinear make(float^ w, float^ bias, i64 m, i64 k, i64 n) {
        NpuLinear l;
        l.ok = false;
        l.code = -1;
        l.m = m; l.k = k; l.n = n;
        npu_init();
        if npu_dev == 0 { return l; }
        i64 pm = (i64)Mem::alloc(16);
        Native::poke64(pm, 0);
        i64 rc = Native::call1(npu_f_model_create, pm);
        if rc != 0 { l.code = rc; return l; }
        i64 model = Native::peek64(pm);
        l.model = model;
        rc = Native::call2(npu_f_add_operand, model, npu_type(3, m, k));            // 0 the input x
        rc = rc + Native::call2(npu_f_add_operand, model, npu_type(3, n, k));       // 1 the weights
        rc = rc + Native::call2(npu_f_add_operand, model, npu_type(3, n, 0));       // 2 the bias
        rc = rc + Native::call2(npu_f_add_operand, model, npu_type(1, 0, 0));      // 3 the activation (none)
        rc = rc + Native::call2(npu_f_add_operand, model, npu_type(3, m, n));       // 4 the output
        float^ b0 = bias;
        if bias == null {
            b0 = (float^)Mem::alloc(n * 4 + 16);
            for i in 0..n { b0[i] = 0.0; }
        }
        i64 act = (i64)Mem::alloc(16);
        Native::poke32(act, 0);
        rc = rc + Native::call4(npu_f_set_value, model, 1, (i64)w, n * k * 4);
        rc = rc + Native::call4(npu_f_set_value, model, 2, (i64)b0, n * 4);
        rc = rc + Native::call4(npu_f_set_value, model, 3, act, 4);
        i64 ins = (i64)Mem::alloc(32);
        Native::poke32(ins, 0); Native::poke32(ins + 4, 1); Native::poke32(ins + 8, 2); Native::poke32(ins + 12, 3);
        i64 outs = (i64)Mem::alloc(16);
        Native::poke32(outs, 4);
        rc = rc + Native::call6(npu_f_add_operation, model, 9, 4, ins, 1, outs);        // 9: FULLY_CONNECTED
        i64 in0 = (i64)Mem::alloc(16);
        Native::poke32(in0, 0);
        rc = rc + Native::call5(npu_f_identify, model, 1, in0, 1, outs);
        rc = rc + Native::call2(npu_f_relax, model, 1);
        rc = rc + Native::call1(npu_f_finish, model);
        if rc != 0 { l.code = rc; return l; }
        i64 devs = (i64)Mem::alloc(16);
        Native::poke64(devs, npu_dev);
        i64 pc = (i64)Mem::alloc(16);
        Native::poke64(pc, 0);
        rc = Native::call4(npu_f_comp_create, model, devs, 1, pc);
        if rc != 0 { l.code = rc; return l; }
        l.comp = Native::peek64(pc);
        rc = Native::call1(npu_f_comp_finish, l.comp);
        if rc != 0 { l.code = rc; return l; }
        l.code = 0;
        l.ok = true;
        return l;
    }

    // y (m x n) = x (m x k) * W^T + bias; false when the NPU says no
    bool run(self, float^ x, float^ y) {
        if !self.ok { return false; }
        i64 pe = (i64)Mem::alloc(16);
        Native::poke64(pe, 0);
        if Native::call2(npu_f_exec_create, self.comp, pe) != 0 { return false; }
        i64 ex = Native::peek64(pe);
        i64 rc = Native::call5(npu_f_exec_input, ex, 0, 0, (i64)x, self.m * self.k * 4);
        rc = rc + Native::call5(npu_f_exec_output, ex, 0, 0, (i64)y, self.m * self.n * 4);
        if rc == 0 { rc = Native::call1(npu_f_exec_compute, ex); }
        if npu_f_exec_free != 0 { Native::call1(npu_f_exec_free, ex); }
        return rc == 0;
    }

    void destroy(self) {
        if self.ok {
            if npu_f_comp_free != 0 { Native::call1(npu_f_comp_free, self.comp); }
            if npu_f_model_free != 0 { Native::call1(npu_f_model_free, self.model); }
            self.ok = false;
        }
    }
}

struct Npu {
    // true when NNAPI has a device that is not the reference CPU
    static bool available() {
        npu_init();
        return npu_dev != 0;
    }
}
