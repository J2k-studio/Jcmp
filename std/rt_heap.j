// The prelude: read in front of every program (unused functions are left out).
// Mem: a small heap. Every block has a 16-byte header: [size, next-free].
int std_heap_cur;
int std_heap_end;
int std_free_list;
int std_direct[64];                // blocks of 256 KB and more that have pages of their own (given back to the system by free)
int std_direct_n;
int std_mem_lock;                 // 0 free, 1 taken (threads share the heap)
int std_mt;                       // 1 once a thread was started: only then the heap is locked
int std_alloc_n;                  // blocks given out / given back (the -d build reports the difference at the end)
int std_free_n;
int std_cls[24] = {32, 48, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, 448, 512, 640, 768, 896, 1024, 1280, 1536, 1792, 2048, 2048};   // the size classes (with the header)
int std_cls_of[129] = {0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 11, 11, 12, 12, 12, 12, 13, 13, 13, 13, 14, 14, 14, 14, 15, 15, 15, 15, 15, 15, 15, 15, 16, 16, 16, 16, 16, 16, 16, 16, 17, 17, 17, 17, 17, 17, 17, 17, 18, 18, 18, 18, 18, 18, 18, 18, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22};     // by need / 16: the class of a block (-1: bigger than the biggest class)
int std_cls_exact[129] = {-1, -1, 0, 1, 2, 3, 4, 5, 6, -1, 7, -1, 8, -1, 9, -1, 10, -1, -1, -1, 11, -1, -1, -1, 12, -1, -1, -1, 13, -1, -1, -1, 14, -1, -1, -1, -1, -1, -1, -1, 15, -1, -1, -1, -1, -1, -1, -1, 16, -1, -1, -1, -1, -1, -1, -1, 17, -1, -1, -1, -1, -1, -1, -1, 18, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 19, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 20, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 21, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 22};  // by size / 16: the class whose size is exactly this, or -1
int std_free_cls[24];              // the free blocks of each class
int std_debug;                     // 1 in a -d build: the checks of Mem (a block freed twice, written after it was freed, the places of the leaks)
int^ std_dbg_tab;                  // the live blocks in a -d build: [address, size, the function that made it], 32768 places (open addressing); 768 KB from mmap in debug_on (a big array here would push the arrays of the program far from the base of the globals)
int std_dbg_n;                     // how many live blocks the table holds
int std_dbg_full;                  // 1: the table was full once (the checks that need it are off)
int std_dbg_quar[64];              // the last blocks that were freed (a -d build keeps them filled with 221 for a while)
int std_dbg_qi;
int std_guard_n;                   // how many blocks of a -d build live in pages of their own (a guard page after each; at most 12000)

// a bug in the program (a null array, a position out of range, ...): say so and stop; try/catch cannot catch it
void __panic(char^ msg) {
    int n = 0;
    while msg[n] != 0 { n += 1; }
    syscall(64, 2, "panic: ", 7);
    syscall(64, 2, msg, n);
    syscall(64, 2, "\n", 1);
    // the functions that were running, innermost first (the frames are linked: [fp] = caller's fp, [fp + 8] = return address)
    int^ fp = (int^)__fp();
    int^ tab = (int^)__fntab();
    int depth = 0;
    while (int)fp > 4096 && depth < 24 {
        int ret = fp[1];
        int best = 0 - 1;
        int k = 0;
        while tab[k * 2] != 0 {
            if tab[k * 2] < ret { best = k; }
            k += 1;
        }
        if best < 0 { break; }
        char^ name = (char^)tab[best * 2 + 1];
        syscall(64, 2, "  at ", 5);
        int i = 0;
        if name[0] == '_' && name[1] == '_' { i = 2; }              // a name of the library: __Arr__nullerr is shown as Arr::nullerr
        while name[i] != 0 {
            if name[i] == '_' && name[i + 1] == '_' {
                syscall(64, 2, "::", 2);
                i += 2;
            } else {
                syscall(64, 2, @name[i], 1);
                i += 1;
            }
        }
        syscall(64, 2, "\n", 1);
        fp = (int^)fp[0];
        depth += 1;
    }
    syscall(94, 134);
}

