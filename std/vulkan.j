// vulkan 0.1.0 -- the first step of Vulkan from J2K, on the real driver (no app needed).   #import <vulkan>   (needs  jcmp -dyn  and the library native)
//   Vk vk = Vk::open();                              // makes an instance and looks at the first graphics chip
//   if !vk.ok { cout << vk.log << "\n"; return; }
//   cout << vk.device_name << " " << vk.api_text() << " memory " << vk.memory_mb << " MB compute " << vk.has_compute << "\n";
//   vk.close();
// It shows how every Vulkan call is made: a structure built in memory (Vk::struct_* helpers), a function found by name (vk.fn("vkName")),
// and Native::call1 .. call8. The next steps (device, queue, buffer, compute pipeline, swapchain) are written the same way.
#import <native>

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

    void close(self) {
        if self.ok {
            Native::call2(self.fn("vkDestroyInstance"), self.instance, 0);
            self.ok = false;
        }
    }
}
