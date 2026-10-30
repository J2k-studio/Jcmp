// vulkan 0.3.0 -- the first step of Vulkan from J2K, on the real driver (no app needed).   #import <vulkan>   (needs  jcmp -dyn  and the library native)
//   Vk vk = Vk::open();                              // makes an instance and looks at the first graphics chip
//   if !vk.ok { cout << vk.log << "\n"; return; }
//   cout << vk.device_name << " " << vk.api_text() << " memory " << vk.memory_mb << " MB compute " << vk.has_compute << "\n";
//   vk.close();
// 0.2.0: a logical device and a queue (`vk.make_device()`), buffers in memory the CPU and the GPU both see (`VkBuf b = vk.make_buffer(bytes)`, `b.upload(float^ p, n)`,
//   `b.download(float^ p, n)`), and the text of every VkResult (`vk_result_text(rc)`).
// 0.3.0: a compute pipeline from SPIR-V words: `Compute c = vk.make_compute(spirv, 3)` (the shader reads the storage buffers 0, 1, 2 of set 0), `c.bind(0, buf0)` ..., `c.run(gx, gy, gz)`
//   (waits until the GPU is done). `VkShaders::vector_add()` is a SPIR-V shader that makes c[i] = a[i] + b[i] (local size 64).
// It shows how every Vulkan call is made: a structure built in memory (Vk::struct_* helpers), a function found by name (vk.fn("vkName")),
// and Native::call1 .. call8. The next steps (device, queue, buffer, compute pipeline, swapchain) are written the same way.
#import <native>

String vk_result_text(int rc) {
    if rc == 0 { return "VK_SUCCESS"; }
    if rc == 1 { return "VK_NOT_READY"; }
    if rc == 2 { return "VK_TIMEOUT"; }
    if rc == -1 { return "VK_ERROR_OUT_OF_HOST_MEMORY"; }
    if rc == -2 { return "VK_ERROR_OUT_OF_DEVICE_MEMORY"; }
    if rc == -3 { return "VK_ERROR_INITIALIZATION_FAILED"; }
    if rc == -4 { return "VK_ERROR_DEVICE_LOST"; }
    if rc == -5 { return "VK_ERROR_MEMORY_MAP_FAILED"; }
    if rc == -6 { return "VK_ERROR_LAYER_NOT_PRESENT"; }
    if rc == -7 { return "VK_ERROR_EXTENSION_NOT_PRESENT"; }
    if rc == -8 { return "VK_ERROR_FEATURE_NOT_PRESENT"; }
    if rc == -9 { return "VK_ERROR_INCOMPATIBLE_DRIVER"; }
    if rc == -10 { return "VK_ERROR_TOO_MANY_OBJECTS"; }
    if rc == -11 { return "VK_ERROR_FORMAT_NOT_SUPPORTED"; }
    return "VkResult " + str(rc);
}


struct VkBuf {
    bool ok;                         // no String inside: a VkBuf can be passed by value (bind) and used afterwards
    int device;
    int buffer;
    int memory;
    int ptr;                         // the memory as the CPU sees it
    int size;                        // bytes
    int free_buffer;
    int free_memory;

    void upload(self, float^ src, int n) {
        float^ dst = (float^)self.ptr;
        for i in 0..n { dst[i] = src[i]; }
    }
    void download(self, float^ dst, int n) {
        float^ src = (float^)self.ptr;
        for i in 0..n { dst[i] = src[i]; }
    }
    void destroy(self) {
        if self.ok {
            Native::call3(self.free_buffer, self.device, self.buffer, 0);
            Native::call3(self.free_memory, self.device, self.memory, 0);
            self.ok = false;
        }
    }
}

struct VkShaders {
    // SPIR-V of: layout(local_size_x = 64) buffer A { float a[]; } ... c[i] = a[i] + b[i]  (made by hand; bindings 0, 1, 2 of set 0)
    static int[] vector_add() {
        int[] w = arr(200);
        w.push(119734787);
        w.push(65536);
        w.push(0);
        w.push(28);
        w.push(0);
        w.push(131089);
        w.push(1);
        w.push(196622);
        w.push(0);
        w.push(1);
        w.push(393231);
        w.push(5);
        w.push(1);
        w.push(1852399981);
        w.push(0);
        w.push(2);
        w.push(393232);
        w.push(1);
        w.push(17);
        w.push(64);
        w.push(1);
        w.push(1);
        w.push(262215);
        w.push(2);
        w.push(11);
        w.push(28);
        w.push(262215);
        w.push(9);
        w.push(6);
        w.push(4);
        w.push(327752);
        w.push(10);
        w.push(0);
        w.push(35);
        w.push(0);
        w.push(196679);
        w.push(10);
        w.push(3);
        w.push(262215);
        w.push(13);
        w.push(34);
        w.push(0);
        w.push(262215);
        w.push(13);
        w.push(33);
        w.push(0);
        w.push(262215);
        w.push(14);
        w.push(34);
        w.push(0);
        w.push(262215);
        w.push(14);
        w.push(33);
        w.push(1);
        w.push(262215);
        w.push(15);
        w.push(34);
        w.push(0);
        w.push(262215);
        w.push(15);
        w.push(33);
        w.push(2);
        w.push(131091);
        w.push(3);
        w.push(196641);
        w.push(4);
        w.push(3);
        w.push(196630);
        w.push(5);
        w.push(32);
        w.push(262165);
        w.push(6);
        w.push(32);
        w.push(0);
        w.push(262167);
        w.push(7);
        w.push(6);
        w.push(3);
        w.push(262176);
        w.push(8);
        w.push(1);
        w.push(7);
        w.push(262203);
        w.push(8);
        w.push(2);
        w.push(1);
        w.push(196637);
        w.push(9);
        w.push(5);
        w.push(196638);
        w.push(10);
        w.push(9);
        w.push(262176);
        w.push(11);
        w.push(2);
        w.push(10);
        w.push(262176);
        w.push(12);
        w.push(2);
        w.push(5);
        w.push(262203);
        w.push(11);
        w.push(13);
        w.push(2);
        w.push(262203);
        w.push(11);
        w.push(14);
        w.push(2);
        w.push(262203);
        w.push(11);
        w.push(15);
        w.push(2);
        w.push(262176);
        w.push(16);
        w.push(1);
        w.push(6);
        w.push(262187);
        w.push(6);
        w.push(17);
        w.push(0);
        w.push(327734);
        w.push(3);
        w.push(1);
        w.push(0);
        w.push(4);
        w.push(131320);
        w.push(18);
        w.push(327745);
        w.push(16);
        w.push(19);
        w.push(2);
        w.push(17);
        w.push(262205);
        w.push(6);
        w.push(20);
        w.push(19);
        w.push(393281);
        w.push(12);
        w.push(21);
        w.push(13);
        w.push(17);
        w.push(20);
        w.push(262205);
        w.push(5);
        w.push(22);
        w.push(21);
        w.push(393281);
        w.push(12);
        w.push(23);
        w.push(14);
        w.push(17);
        w.push(20);
        w.push(262205);
        w.push(5);
        w.push(24);
        w.push(23);
        w.push(327809);
        w.push(5);
        w.push(25);
        w.push(22);
        w.push(24);
        w.push(393281);
        w.push(12);
        w.push(26);
        w.push(15);
        w.push(17);
        w.push(20);
        w.push(196670);
        w.push(26);
        w.push(25);
        w.push(65789);
        w.push(65592);
        return w;
    }
}

struct Compute {
    bool ok;
    String error;
    int device;
    int nbuf;
    int layout;
    int pipeline;
    int dset;
    int cmd;
    int queue;
    int fn_update;
    int fn_submit;
    int fn_wait;
    int fn_begin;
    int fn_end;
    int fn_bindp;
    int fn_binds;
    int fn_dispatch;
    int module;
    int setlayout;
    int pool;
    int cpool;
    int d_pipeline;
    int d_playout;
    int d_slayout;
    int d_pool;
    int d_cpool;
    int d_module;

    // buffer number `binding` of the shader is the buffer b
    void bind(self, int binding, VkBuf b) {            // b is copied: a struct that has a method called free would be freed at the end of the call
        // VkDescriptorBufferInfo: buffer 0, offset 8, range 16
        int info = (int)Mem::alloc(32);
        Native::poke64(info, b.buffer);
        Native::poke64(info + 8, 0);
        Native::poke64(info + 16, b.size);
        // VkWriteDescriptorSet (64 bytes): sType 35 at 0, dstSet 16, dstBinding 24, descriptorCount 32, descriptorType 36 (7 = storage buffer), pBufferInfo 48
        int wr = (int)Mem::alloc(72);
        for i in 0..9 { Native::poke64(wr + i * 8, 0); }
        Native::poke32(wr, 35);
        Native::poke64(wr + 16, self.dset);
        Native::poke32(wr + 24, binding);
        Native::poke32(wr + 32, 1);
        Native::poke32(wr + 36, 7);
        Native::poke64(wr + 48, info);
        Native::call5(self.fn_update, self.device, 1, wr, 0, 0);
    }

    // destroy what make_compute made (call it before vk.close())
    void destroy(self) {
        if self.ok {
            Native::call3(self.d_pipeline, self.device, self.pipeline, 0);
            Native::call3(self.d_playout, self.device, self.layout, 0);
            Native::call3(self.d_slayout, self.device, self.setlayout, 0);
            Native::call3(self.d_pool, self.device, self.pool, 0);       // the set goes with its pool
            Native::call3(self.d_cpool, self.device, self.cpool, 0);     // the command buffer goes with its pool
            Native::call3(self.d_module, self.device, self.module, 0);
            self.ok = false;
        }
    }

    // one run: gx * gy * gz groups; it returns when the GPU is done (false and `error` when a call fails)
    bool run(self, int gx, int gy, int gz) {
        self.error = "";
        // VkCommandBufferBeginInfo: sType 42 at 0
        int bi = (int)Mem::alloc(32);
        for i in 0..4 { Native::poke64(bi + i * 8, 0); }
        Native::poke32(bi, 42);
        int rc = Native::call2(self.fn_begin, self.cmd, bi);
        if rc != 0 { self.error = "vkBeginCommandBuffer: " + vk_result_text(rc); return false; }
        Native::call3(self.fn_bindp, self.cmd, 1, self.pipeline);
        int pset = (int)Mem::alloc(16);
        Native::poke64(pset, self.dset);
        Native::call8(self.fn_binds, self.cmd, 1, self.layout, 0, 1, pset, 0, 0);
        Native::call4(self.fn_dispatch, self.cmd, gx, gy, gz);
        rc = Native::call1(self.fn_end, self.cmd);
        if rc != 0 { self.error = "vkEndCommandBuffer: " + vk_result_text(rc); return false; }
        // VkSubmitInfo (72 bytes): sType 4 at 0, commandBufferCount 40, pCommandBuffers 48
        int pcmd = (int)Mem::alloc(16);
        Native::poke64(pcmd, self.cmd);
        int si = (int)Mem::alloc(80);
        for i in 0..10 { Native::poke64(si + i * 8, 0); }
        Native::poke32(si, 4);
        Native::poke32(si + 40, 1);
        Native::poke64(si + 48, pcmd);
        rc = Native::call4(self.fn_submit, self.queue, 1, si, 0);
        if rc != 0 { self.error = "vkQueueSubmit: " + vk_result_text(rc); return false; }
        rc = Native::call1(self.fn_wait, self.queue);
        if rc != 0 { self.error = "vkQueueWaitIdle: " + vk_result_text(rc); return false; }
        return true;
    }
}

struct Vk {
    int lib;
    int instance;
    int phys;
    bool ok;
    String log;
    String device_name;
    int api_version;
    int vendor_id;
    int device_type;                 // 0 other, 1 integrated, 2 discrete, 3 virtual, 4 cpu
    int memory_mb;
    bool has_compute;
    int queue_families;
    int family;                      // the queue family that does compute
    int device;                      // the logical device (0 until make_device)
    int queue;
    int mem_props;                   // a copy of VkPhysicalDeviceMemoryProperties

    int fn(self, String name) {
        int gp = Native::sym(self.lib, "vkGetInstanceProcAddr");
        int a = Native::call2(gp, self.instance, (int)name.c());
        if a == 0 { a = Native::sym(self.lib, name); }
        return a;
    }

    String api_text(self) { return str(self.api_version >> 22) + "." + str((self.api_version >> 12) & 1023) + "." + str(self.api_version & 4095); }

    static Vk open() {
        Vk vk;
        vk.ok = false;
        vk.log = "";
        vk.device_name = "";
        vk.lib = Native::open("libvulkan.so");
        if vk.lib == 0 { vk.log = "libvulkan.so not found (build the program with jcmp -dyn)"; return vk; }
        // VkApplicationInfo: sType 0, pNext 8, pApplicationName 16, applicationVersion 24, pEngineName 32, engineVersion 40, apiVersion 44 (48 bytes)
        int app = (int)Mem::alloc(64);
        for i in 0..8 { Native::poke64(app + i * 8, 0); }
        Native::poke32(app, 0);                                          // VK_STRUCTURE_TYPE_APPLICATION_INFO
        Native::poke64(app + 16, (int)"Jaric".c());
        Native::poke32(app + 44, 4198400);                               // VK_API_VERSION_1_1
        // VkInstanceCreateInfo: sType 1 at 0, pApplicationInfo at 24 (64 bytes)
        int ici = (int)Mem::alloc(80);
        for i in 0..10 { Native::poke64(ici + i * 8, 0); }
        Native::poke32(ici, 1);
        Native::poke64(ici + 24, app);
        int pinst = (int)Mem::alloc(16);
        Native::poke64(pinst, 0);
        int create = Native::sym(vk.lib, "vkCreateInstance");
        int rc = Native::call3(create, ici, 0, pinst);
        if rc != 0 { vk.log = "vkCreateInstance failed: " + str(rc); return vk; }
        vk.instance = Native::peek64(pinst);
        int enum_dev = vk.fn("vkEnumeratePhysicalDevices");
        int pcount = (int)Mem::alloc(16);
        Native::poke32(pcount, 0);
        Native::call3(enum_dev, vk.instance, pcount, 0);
        int n = Native::peek32(pcount);
        if n == 0 { vk.log = "no physical device"; return vk; }
        int devs = (int)Mem::alloc(n * 8 + 16);
        Native::call3(enum_dev, vk.instance, pcount, devs);
        vk.phys = Native::peek64(devs);
        // VkPhysicalDeviceProperties: apiVersion 0, driverVersion 4, vendorID 8, deviceID 12, deviceType 16, deviceName 20 (256 bytes)
        int props = (int)Mem::alloc(1024);
        for i in 0..128 { Native::poke64(props + i * 8, 0); }
        Native::call2(vk.fn("vkGetPhysicalDeviceProperties"), vk.phys, props);
        vk.api_version = Native::peek32(props);
        vk.vendor_id = Native::peek32(props + 8);
        vk.device_type = Native::peek32(props + 16);
        vk.device_name = Native::text(props + 20);
        // VkPhysicalDeviceMemoryProperties: memoryTypeCount 0, memoryTypes 4 (32 x 8), memoryHeapCount 260, memoryHeaps 264 (16 x 16: size 8, flags 4)
        int mem = (int)Mem::alloc(1024);
        for i in 0..128 { Native::poke64(mem + i * 8, 0); }
        Native::call2(vk.fn("vkGetPhysicalDeviceMemoryProperties"), vk.phys, mem);
        int heaps = Native::peek32(mem + 260);
        int total = 0;
        for i in 0..heaps { total = total + Native::peek64(mem + 264 + i * 16) / 1048576; }
        vk.memory_mb = total;
        // the queue families: VkQueueFamilyProperties 24 bytes each, queueFlags at 0 (bit 2 = compute)
        int qcount = (int)Mem::alloc(16);
        Native::poke32(qcount, 0);
        int qf = vk.fn("vkGetPhysicalDeviceQueueFamilyProperties");
        Native::call3(qf, vk.phys, qcount, 0);
        int qn = Native::peek32(qcount);
        vk.queue_families = qn;
        int qprops = (int)Mem::alloc(qn * 24 + 32);
        Native::call3(qf, vk.phys, qcount, qprops);
        vk.has_compute = false;
        for i in 0..qn { if (Native::peek32(qprops + i * 24) & 2) != 0 { vk.has_compute = true; } }
        vk.ok = true;
        return vk;
    }

    static String result_text(int rc) { return vk_result_text(rc); }

    // the logical device with one queue of the compute family
    bool make_device(self) {
        if !self.ok { return false; }
        if self.device != 0 { return true; }
        int qcount = (int)Mem::alloc(16);
        Native::poke32(qcount, 0);
        int qf = self.fn("vkGetPhysicalDeviceQueueFamilyProperties");
        Native::call3(qf, self.phys, qcount, 0);
        int qn = Native::peek32(qcount);
        int qprops = (int)Mem::alloc(qn * 24 + 32);
        Native::call3(qf, self.phys, qcount, qprops);
        self.family = -1;
        for i in 0..qn { if self.family < 0 && (Native::peek32(qprops + i * 24) & 2) != 0 { self.family = i; } }
        if self.family < 0 { self.log = "no queue family that does compute"; return false; }
        int prio = (int)Mem::alloc(16);
        Native::poke32(prio, 1065353216);                                 // 1.0f
        // VkDeviceQueueCreateInfo (40 bytes): sType 2 at 0, queueFamilyIndex 20, queueCount 24, pQueuePriorities 32
        int qci = (int)Mem::alloc(48);
        for i in 0..6 { Native::poke64(qci + i * 8, 0); }
        Native::poke32(qci, 2);
        Native::poke32(qci + 20, self.family);
        Native::poke32(qci + 24, 1);
        Native::poke64(qci + 32, prio);
        // VkDeviceCreateInfo (72 bytes): sType 3 at 0, queueCreateInfoCount 20, pQueueCreateInfos 24
        int dci = (int)Mem::alloc(80);
        for i in 0..10 { Native::poke64(dci + i * 8, 0); }
        Native::poke32(dci, 3);
        Native::poke32(dci + 20, 1);
        Native::poke64(dci + 24, qci);
        int pdev = (int)Mem::alloc(16);
        Native::poke64(pdev, 0);
        int rc = Native::call4(self.fn("vkCreateDevice"), self.phys, dci, 0, pdev);
        if rc != 0 { self.log = "vkCreateDevice: " + vk_result_text(rc); return false; }
        self.device = Native::peek64(pdev);
        int pq = (int)Mem::alloc(16);
        Native::poke64(pq, 0);
        Native::call4(self.fn("vkGetDeviceQueue"), self.device, self.family, 0, pq);
        self.queue = Native::peek64(pq);
        // keep the memory types
        self.mem_props = (int)Mem::alloc(1024);
        for i in 0..128 { Native::poke64(self.mem_props + i * 8, 0); }
        Native::call2(self.fn("vkGetPhysicalDeviceMemoryProperties"), self.phys, self.mem_props);
        return true;
    }

    // a compute pipeline from SPIR-V words (the entry point is called main); the shader uses the storage buffers 0 .. nbuf - 1 of set 0
    Compute make_compute(self, int[] spirv, int nbuf) {
        Compute c;
        c.ok = false;
        c.error = "";
        if self.device == 0 && !self.make_device() { c.error = self.log + ""; return c; }
        c.device = self.device;
        c.queue = self.queue;
        c.nbuf = nbuf;
        int bytes = spirv.len * 4;
        int code = (int)Mem::alloc(bytes + 16);
        for i in 0..spirv.len { Native::poke32(code + i * 4, spirv[i]); }
        // VkShaderModuleCreateInfo: sType 16 at 0, codeSize 24, pCode 32
        int smi = (int)Mem::alloc(48);
        for i in 0..5 { Native::poke64(smi + i * 8, 0); }
        Native::poke32(smi, 16);
        Native::poke64(smi + 24, bytes);
        Native::poke64(smi + 32, code);
        int p1 = (int)Mem::alloc(16);
        Native::poke64(p1, 0);
        int rc = Native::call4(self.fn("vkCreateShaderModule"), self.device, smi, 0, p1);
        if rc != 0 { c.error = "vkCreateShaderModule: " + vk_result_text(rc); return c; }
        int module = Native::peek64(p1);
        c.module = module;
        // the layout of the set: nbuf storage buffers. VkDescriptorSetLayoutBinding (24 bytes): binding 0, type 4 (7), count 8, stages 12 (32 = compute)
        int binds = (int)Mem::alloc(nbuf * 24 + 16);
        for i in 0..nbuf {
            int o = binds + i * 24;
            Native::poke64(o, 0); Native::poke64(o + 8, 0); Native::poke64(o + 16, 0);
            Native::poke32(o, i);
            Native::poke32(o + 4, 7);
            Native::poke32(o + 8, 1);
            Native::poke32(o + 12, 32);
        }
        // VkDescriptorSetLayoutCreateInfo: sType 32 at 0, bindingCount 20, pBindings 24
        int dsl = (int)Mem::alloc(48);
        for i in 0..5 { Native::poke64(dsl + i * 8, 0); }
        Native::poke32(dsl, 32);
        Native::poke32(dsl + 20, nbuf);
        Native::poke64(dsl + 24, binds);
        Native::poke64(p1, 0);
        rc = Native::call4(self.fn("vkCreateDescriptorSetLayout"), self.device, dsl, 0, p1);
        if rc != 0 { c.error = "vkCreateDescriptorSetLayout: " + vk_result_text(rc); return c; }
        int setlayout = Native::peek64(p1);
        c.setlayout = setlayout;
        // VkPipelineLayoutCreateInfo: sType 30 at 0, setLayoutCount 20, pSetLayouts 24
        int psl = (int)Mem::alloc(16);
        Native::poke64(psl, setlayout);
        int pli = (int)Mem::alloc(64);
        for i in 0..8 { Native::poke64(pli + i * 8, 0); }
        Native::poke32(pli, 30);
        Native::poke32(pli + 20, 1);
        Native::poke64(pli + 24, psl);
        Native::poke64(p1, 0);
        rc = Native::call4(self.fn("vkCreatePipelineLayout"), self.device, pli, 0, p1);
        if rc != 0 { c.error = "vkCreatePipelineLayout: " + vk_result_text(rc); return c; }
        c.layout = Native::peek64(p1);
        // VkComputePipelineCreateInfo (96 bytes): sType 29 at 0; stage (VkPipelineShaderStageCreateInfo, 48 bytes) at 24: sType 18, stage 44 (32), module 48, pName 56; layout 72
        int cpi = (int)Mem::alloc(112);
        for i in 0..14 { Native::poke64(cpi + i * 8, 0); }
        Native::poke32(cpi, 29);
        Native::poke32(cpi + 24, 18);
        Native::poke32(cpi + 44, 32);
        Native::poke64(cpi + 48, module);
        Native::poke64(cpi + 56, (int)"main".c());
        Native::poke64(cpi + 72, c.layout);
        Native::poke64(p1, 0);
        rc = Native::call6(self.fn("vkCreateComputePipelines"), self.device, 0, 1, cpi, 0, p1);
        if rc != 0 { c.error = "vkCreateComputePipelines: " + vk_result_text(rc); return c; }
        c.pipeline = Native::peek64(p1);
        // a pool with one set of nbuf storage buffers. VkDescriptorPoolSize: type 0 (7), count 4. VkDescriptorPoolCreateInfo: sType 33, maxSets 20, poolSizeCount 24, pPoolSizes 32
        int ps = (int)Mem::alloc(16);
        Native::poke32(ps, 7);
        Native::poke32(ps + 4, nbuf);
        int dpi = (int)Mem::alloc(48);
        for i in 0..5 { Native::poke64(dpi + i * 8, 0); }
        Native::poke32(dpi, 33);
        Native::poke32(dpi + 20, 1);
        Native::poke32(dpi + 24, 1);
        Native::poke64(dpi + 32, ps);
        Native::poke64(p1, 0);
        rc = Native::call4(self.fn("vkCreateDescriptorPool"), self.device, dpi, 0, p1);
        if rc != 0 { c.error = "vkCreateDescriptorPool: " + vk_result_text(rc); return c; }
        int pool = Native::peek64(p1);
        c.pool = pool;
        // VkDescriptorSetAllocateInfo: sType 34, descriptorPool 16, descriptorSetCount 24, pSetLayouts 32
        int dai = (int)Mem::alloc(48);
        for i in 0..5 { Native::poke64(dai + i * 8, 0); }
        Native::poke32(dai, 34);
        Native::poke64(dai + 16, pool);
        Native::poke32(dai + 24, 1);
        Native::poke64(dai + 32, psl);
        Native::poke64(p1, 0);
        rc = Native::call3(self.fn("vkAllocateDescriptorSets"), self.device, dai, p1);
        if rc != 0 { c.error = "vkAllocateDescriptorSets: " + vk_result_text(rc); return c; }
        c.dset = Native::peek64(p1);
        // a command pool and one command buffer. VkCommandPoolCreateInfo: sType 39, flags 16 (2 = reset), queueFamilyIndex 20
        int cpo = (int)Mem::alloc(32);
        for i in 0..4 { Native::poke64(cpo + i * 8, 0); }
        Native::poke32(cpo, 39);
        Native::poke32(cpo + 16, 2);
        Native::poke32(cpo + 20, self.family);
        Native::poke64(p1, 0);
        rc = Native::call4(self.fn("vkCreateCommandPool"), self.device, cpo, 0, p1);
        if rc != 0 { c.error = "vkCreateCommandPool: " + vk_result_text(rc); return c; }
        int cpool = Native::peek64(p1);
        c.cpool = cpool;
        // VkCommandBufferAllocateInfo: sType 40, commandPool 16, level 24 (0), commandBufferCount 28
        int cai = (int)Mem::alloc(48);
        for i in 0..4 { Native::poke64(cai + i * 8, 0); }
        Native::poke32(cai, 40);
        Native::poke64(cai + 16, cpool);
        Native::poke32(cai + 28, 1);
        Native::poke64(p1, 0);
        rc = Native::call3(self.fn("vkAllocateCommandBuffers"), self.device, cai, p1);
        if rc != 0 { c.error = "vkAllocateCommandBuffers: " + vk_result_text(rc); return c; }
        c.cmd = Native::peek64(p1);
        c.fn_update = self.fn("vkUpdateDescriptorSets");
        c.fn_submit = self.fn("vkQueueSubmit");
        c.fn_wait = self.fn("vkQueueWaitIdle");
        c.fn_begin = self.fn("vkBeginCommandBuffer");
        c.fn_end = self.fn("vkEndCommandBuffer");
        c.fn_bindp = self.fn("vkCmdBindPipeline");
        c.fn_binds = self.fn("vkCmdBindDescriptorSets");
        c.fn_dispatch = self.fn("vkCmdDispatch");
        c.d_pipeline = self.fn("vkDestroyPipeline");
        c.d_playout = self.fn("vkDestroyPipelineLayout");
        c.d_slayout = self.fn("vkDestroyDescriptorSetLayout");
        c.d_pool = self.fn("vkDestroyDescriptorPool");
        c.d_cpool = self.fn("vkDestroyCommandPool");
        c.d_module = self.fn("vkDestroyShaderModule");
        c.ok = true;
        return c;
    }

    // the index of a memory type that is in the bits and has all the flags (bit 0 device local, 1 host visible, 2 host coherent), or -1
    int memory_type(self, int bits, int flags) {
        int n = Native::peek32(self.mem_props);
        for i in 0..n {
            if (bits & (1 << i)) != 0 && (Native::peek32(self.mem_props + 4 + i * 8) & flags) == flags { return i; }
        }
        return -1;
    }

    // a buffer of this many bytes (for storage and for copies) in memory that both the CPU and the GPU see (host visible and coherent, device local when there is such a type);
    // the CPU reads and writes it through b.ptr
    VkBuf make_buffer(self, int bytes) {
        VkBuf b;
        b.ok = false;
        self.log = "";
        b.size = bytes;
        if self.device == 0 && !self.make_device() { self.log = self.log + ""; return b; }
        b.device = self.device;
        // VkBufferCreateInfo (56 bytes): sType 12 at 0, size 24, usage 32 (storage 0x20 | transfer src 1 | dst 2), sharingMode 36
        int ci = (int)Mem::alloc(64);
        for i in 0..8 { Native::poke64(ci + i * 8, 0); }
        Native::poke32(ci, 12);
        Native::poke64(ci + 24, bytes);
        Native::poke32(ci + 32, 35);
        int pb = (int)Mem::alloc(16);
        Native::poke64(pb, 0);
        int rc = Native::call4(self.fn("vkCreateBuffer"), self.device, ci, 0, pb);
        if rc != 0 { self.log = "vkCreateBuffer: " + vk_result_text(rc); return b; }
        b.buffer = Native::peek64(pb);
        int req = (int)Mem::alloc(32);
        for i in 0..4 { Native::poke64(req + i * 8, 0); }
        Native::call3(self.fn("vkGetBufferMemoryRequirements"), self.device, b.buffer, req);
        int need = Native::peek64(req);
        int bits = Native::peek32(req + 16);
        int t = self.memory_type(bits, 7);
        if t < 0 { t = self.memory_type(bits, 6); }
        if t < 0 { self.log = "no memory the CPU and the GPU both see"; return b; }
        // VkMemoryAllocateInfo: sType 5 at 0, allocationSize 16, memoryTypeIndex 24
        int ai = (int)Mem::alloc(48);
        for i in 0..4 { Native::poke64(ai + i * 8, 0); }
        Native::poke32(ai, 5);
        Native::poke64(ai + 16, need);
        Native::poke32(ai + 24, t);
        int pm = (int)Mem::alloc(16);
        Native::poke64(pm, 0);
        rc = Native::call4(self.fn("vkAllocateMemory"), self.device, ai, 0, pm);
        if rc != 0 { self.log = "vkAllocateMemory: " + vk_result_text(rc); return b; }
        b.memory = Native::peek64(pm);
        rc = Native::call4(self.fn("vkBindBufferMemory"), self.device, b.buffer, b.memory, 0);
        if rc != 0 { self.log = "vkBindBufferMemory: " + vk_result_text(rc); return b; }
        int pp = (int)Mem::alloc(16);
        Native::poke64(pp, 0);
        rc = Native::call6(self.fn("vkMapMemory"), self.device, b.memory, 0, bytes, 0, pp);
        if rc != 0 { self.log = "vkMapMemory: " + vk_result_text(rc); return b; }
        b.ptr = Native::peek64(pp);
        b.free_buffer = self.fn("vkDestroyBuffer");
        b.free_memory = self.fn("vkFreeMemory");
        b.ok = true;
        return b;
    }

    void close(self) {
        if self.ok {
            if self.device != 0 {
                Native::call2(self.fn("vkDestroyDevice"), self.device, 0);
                self.device = 0;
            }
            Native::call2(self.fn("vkDestroyInstance"), self.instance, 0);
            self.ok = false;
        }
    }
}
