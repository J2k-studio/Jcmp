// j2k_asm_v1.s
// J2K Assembler v1 — Phase 1 ขั้น 1 (ต่อจาก v0.2)
// เพิ่มจาก v0.2: label definition (name:), branch (b, b.cond, bl), ldr/str
// (register + unsigned immediate offset, 64-bit only, offset ต้องหาร 8 ลงตัว)
//
// สถาปัตยกรรม: TWO-PASS
//   Pass 1 (x15=1): เดินซ้ำ source ทั้งไฟล์ นับตำแหน่ง (x16, byte offset) ของทุก
//                    instruction, บันทึก label -> address ลงตาราง (x27/x28)
//                    ไม่เขียนอะไรลง code_buf เลย
//   Pass 2 (x15=2): เดินซ้ำรอบสอง คราวนี้ encode จริงและเขียนลง code_buf (x22)
//                    branch คำนวณ offset จากตาราง label ที่ pass 1 สร้างไว้แล้ว
//                    (รองรับทั้ง forward และ backward reference)
//
// ข้อจำกัดที่ตั้งใจไว้ (เพื่อความง่ายของ v0.3 — ปรับได้ใน v0.4 ถ้าจำเป็น):
//   - Label ต้องขึ้นต้นด้วยตัวอักษรหรือ '_' (ไม่รองรับ label ตัวเลขล้วนแบบ "1:")
//   - ldr/str รองรับเฉพาะ x-register (64-bit), unsigned offset, offset % 8 == 0
//   - ยังไม่มี ldrb/strb, ยังไม่มี pre/post-index addressing
//
// Mnemonic ที่รองรับตอนนี้ (เพิ่มจาก v0.2):
//   label:                      (label definition)
//   b   label                   (unconditional branch)
//   b.eq/b.ne/b.lt/b.ge/b.gt/b.le/b.hi/b.ls  label   (conditional branch)
//   bl  label                   (branch and link)
//   ldr xD, [xN]        ldr xD, [xN, #imm]   (imm % 8 == 0)
//   str xD, [xN]        str xD, [xN, #imm]   (imm % 8 == 0)
//
// Build (one-time bootstrap step, ตามข้อ 32 syntax-design.md):
//   as -o j2k_asm_v1.o j2k_asm_v1.s
//   ld -o j2k_asm_v1 j2k_asm_v1.o
//   chmod +x j2k_asm_v1
//
// ทดสอบตัวอย่าง (test3.jasm) — loop นับ 0..5 แล้ว exit ด้วยค่าตัวนับ:
//   mov x0, 0
//   mov x1, 5
//   loop:
//   cmp x0, x1
//   b.ge done
//   add x0, x0, 1
//   b loop
//   done:
//   mov x8, 93
//   svc 0
// คาดว่า: ./out3 ; echo $? --> 5
//
// ldr/str: v0.3 ยังไม่มี syntax จองหน่วยความจำ (buffer) ในภาษา jasm เอง ดังนั้น
// การเทส ldr/str จริงจังต้องรอ mnemonic สำหรับจอง/อ้างอิง memory เพิ่มเติมก่อน
// (ยังไม่ได้ออกแบบ — ค้างไว้คิดต่อ ถามผมได้ถ้าต้องการออกแบบตอนนี้)

    .global _start
    .text

_start:
    ldr     x0, [sp]
    cmp     x0, #3
    b.lt    usage_error

    ldr     x25, [sp, #16]              // x25 = input path
    ldr     x26, [sp, #24]              // x26 = output path

    mov     x0, #-100
    mov     x1, x25
    mov     x2, #0
    mov     x3, #0
    mov     x8, #56                     // openat
    svc     #0
    cmp     x0, #0
    b.lt    io_error
    mov     x19, x0

    mov     x0, x19
    adrp    x1, input_buf
    add     x1, x1, :lo12:input_buf
    mov     x2, #4096
    mov     x8, #63                     // read
    svc     #0
    cmp     x0, #0
    b.lt    io_error
    mov     x23, x0

    mov     x0, x19
    mov     x8, #57                     // close
    svc     #0

    adrp    x21, input_buf
    add     x21, x21, :lo12:input_buf
    add     x20, x21, x23               // x20 = end of input

    adrp    x27, label_table
    add     x27, x27, :lo12:label_table

    // ---- pass 1: build label table, count instruction positions only ----
    mov     x15, #1
    mov     x16, #0
    mov     x28, #0

parse_loop:
    cmp     x21, x20
    b.ge    parse_done

    ldrb    w0, [x21]
    cmp     w0, #32
    b.eq    skip_ws
    cmp     w0, #10
    b.eq    skip_ws
    cmp     w0, #9
    b.eq    skip_ws
    b       try_label

skip_ws:
    add     x21, x21, #1
    b       parse_loop

// ==================== label definition detection ====================
try_label:
    bl      peek_is_label
    cmp     x0, #1
    b.ne    try_mov
    bl      parse_label_name
    add     x21, x21, #1                // consume ':'
    cmp     x15, #1
    b.ne    label_done
    bl      add_label
label_done:
    bl      skip_spaces
    cmp     x21, x20
    b.ge    parse_loop
    ldrb    w0, [x21]
    cmp     w0, #10
    b.eq    parse_loop
    b       try_mov

try_mov:
    ldrb    w0, [x21, #0]
    cmp     w0, #'m'
    b.ne    try_add
    ldrb    w0, [x21, #1]
    cmp     w0, #'o'
    b.ne    try_add
    ldrb    w0, [x21, #2]
    cmp     w0, #'v'
    b.ne    try_add
    add     x21, x21, #3
    bl      handle_mov
    b       skip_to_eol

try_add:
    ldrb    w0, [x21, #0]
    cmp     w0, #'a'
    b.ne    try_sub
    ldrb    w0, [x21, #1]
    cmp     w0, #'d'
    b.ne    try_sub
    ldrb    w0, [x21, #2]
    cmp     w0, #'d'
    b.ne    try_sub
    add     x21, x21, #3
    bl      handle_add
    b       skip_to_eol

try_sub:
    ldrb    w0, [x21, #0]
    cmp     w0, #'s'
    b.ne    try_cmp
    ldrb    w0, [x21, #1]
    cmp     w0, #'u'
    b.ne    try_cmp
    ldrb    w0, [x21, #2]
    cmp     w0, #'b'
    b.ne    try_cmp
    add     x21, x21, #3
    bl      handle_sub
    b       skip_to_eol

try_cmp:
    ldrb    w0, [x21, #0]
    cmp     w0, #'c'
    b.ne    try_ldr
    ldrb    w0, [x21, #1]
    cmp     w0, #'m'
    b.ne    try_ldr
    ldrb    w0, [x21, #2]
    cmp     w0, #'p'
    b.ne    try_ldr
    add     x21, x21, #3
    bl      handle_cmp
    b       skip_to_eol

try_ldr:
    ldrb    w0, [x21, #0]
    cmp     w0, #'l'
    b.ne    try_str
    ldrb    w0, [x21, #1]
    cmp     w0, #'d'
    b.ne    try_str
    ldrb    w0, [x21, #2]
    cmp     w0, #'r'
    b.ne    try_str
    add     x21, x21, #3
    bl      handle_ldr
    b       skip_to_eol

try_str:
    ldrb    w0, [x21, #0]
    cmp     w0, #'s'
    b.ne    try_branch
    ldrb    w0, [x21, #1]
    cmp     w0, #'t'
    b.ne    try_branch
    ldrb    w0, [x21, #2]
    cmp     w0, #'r'
    b.ne    try_branch
    add     x21, x21, #3
    bl      handle_str
    b       skip_to_eol

try_branch:
    ldrb    w0, [x21, #0]
    cmp     w0, #'b'
    b.ne    try_svc
    add     x21, x21, #1
    bl      handle_branch
    b       skip_to_eol

try_svc:
    ldrb    w0, [x21, #0]
    cmp     w0, #'s'
    b.ne    parse_error
    ldrb    w0, [x21, #1]
    cmp     w0, #'v'
    b.ne    parse_error
    ldrb    w0, [x21, #2]
    cmp     w0, #'c'
    b.ne    parse_error
    add     x21, x21, #3
    bl      handle_svc
    // fallthrough

skip_to_eol:
    cmp     x21, x20
    b.ge    parse_loop
    ldrb    w0, [x21]
    cmp     w0, #10
    b.eq    parse_loop
    add     x21, x21, #1
    b       skip_to_eol

parse_done:
    cmp     x15, #1
    b.eq    start_pass2

    // ---- pass 2 finished: write ELF ----
    mov     x23, x16                    // total bytes emitted = final instruction offset
    bl      write_elf

    mov     x0, #0
    mov     x8, #93
    svc     #0

start_pass2:
    mov     x15, #2
    mov     x16, #0
    adrp    x21, input_buf
    add     x21, x21, :lo12:input_buf
    adrp    x22, code_buf
    add     x22, x22, :lo12:code_buf
    b       parse_loop

// ==================== leaf helpers (no nested bl — no stack frame needed) ====================

skip_spaces:
    ldrb    w0, [x21]
    cmp     w0, #32
    b.eq    1f
    cmp     w0, #9
    b.eq    1f
    ret
1:  add     x21, x21, #1
    b       skip_spaces

parse_number:
    mov     x0, #0
2:  ldrb    w1, [x21]
    sub     w2, w1, #48
    cmp     w2, #9
    b.hi    3f
    mov     x3, #10
    mul     x0, x0, x3
    add     x0, x0, x2
    add     x21, x21, #1
    b       2b
3:  ret

// peek_is_label: does NOT move x21. Returns x0=1 if an identifier starting at
// x21 (letter/'_' first char, then letters/digits/'_') is immediately followed
// by ':'. Returns x0=0 otherwise. Uses x6 as scratch cursor only.
peek_is_label:
    mov     x6, x21
    ldrb    w0, [x6]
    cmp     w0, #'a'
    b.lt    pil_upper
    cmp     w0, #'z'
    b.le    pil_scan
pil_upper:
    cmp     w0, #'A'
    b.lt    pil_us
    cmp     w0, #'Z'
    b.le    pil_scan
pil_us:
    cmp     w0, #'_'
    b.eq    pil_scan
    mov     x0, #0
    ret
pil_scan:
    add     x6, x6, #1
pil_loop:
    ldrb    w0, [x6]
    cmp     w0, #'a'
    b.lt    pil_cu
    cmp     w0, #'z'
    b.le    pil_adv
pil_cu:
    cmp     w0, #'A'
    b.lt    pil_cd
    cmp     w0, #'Z'
    b.le    pil_adv
pil_cd:
    cmp     w0, #'0'
    b.lt    pil_cus
    cmp     w0, #'9'
    b.le    pil_adv
pil_cus:
    cmp     w0, #'_'
    b.eq    pil_adv
    b       pil_end
pil_adv:
    add     x6, x6, #1
    b       pil_loop
pil_end:
    cmp     w0, #':'
    b.eq    pil_yes
    mov     x0, #0
    ret
pil_yes:
    mov     x0, #1
    ret

// parse_label_name: advances x21 through the identifier (does NOT consume the
// trailing ':'), copies up to 23 chars into label_name_buf (zero-padded to 24
// bytes total). Returns length in x0 (unused by callers, kept for clarity).
parse_label_name:
    adrp    x1, label_name_buf
    add     x1, x1, :lo12:label_name_buf
    mov     x2, #0
pln_loop:
    ldrb    w0, [x21]
    cmp     w0, #'a'
    b.lt    pln_cu
    cmp     w0, #'z'
    b.le    pln_store
pln_cu:
    cmp     w0, #'A'
    b.lt    pln_cd
    cmp     w0, #'Z'
    b.le    pln_store
pln_cd:
    cmp     w0, #'0'
    b.lt    pln_cus
    cmp     w0, #'9'
    b.le    pln_store
pln_cus:
    cmp     w0, #'_'
    b.eq    pln_store
    b       pln_pad
pln_store:
    cmp     x2, #23
    b.ge    pln_skip
    strb    w0, [x1, x2]
pln_skip:
    add     x2, x2, #1
    add     x21, x21, #1
    b       pln_loop
pln_pad:
    mov     x3, x2
pln_pad_loop:
    cmp     x3, #24
    b.ge    pln_done
    strb    wzr, [x1, x3]
    add     x3, x3, #1
    b       pln_pad_loop
pln_done:
    mov     x0, x2
    ret

// finish_instr: called by every instruction handler right after building the
// encoded word in w2. In pass 1 (x15==1) it only advances x16 (position
// counter) and does NOT touch code_buf. In pass 2 (x15==2) it writes w2 to
// [x22] (post-increment) AND advances x16. This is what makes label addresses
// computed in pass 1 line up exactly with real write positions in pass 2.
finish_instr:
    cmp     x15, #1
    b.eq    fi_count
    str     w2, [x22], #4
fi_count:
    add     x16, x16, #4
    ret

// ==================== non-leaf helpers (call other subroutines -> need LR saved) ====================

// parse_register: expects 'x' at x21, then decimal digits -> x0 = register number, advances x21
parse_register:
    stp     x29, x30, [sp, #-16]!
    ldrb    w0, [x21]
    cmp     w0, #'x'
    b.ne    pr_err
    add     x21, x21, #1
    bl      parse_number
    ldp     x29, x30, [sp], #16
    ret
pr_err:
    ldp     x29, x30, [sp], #16
    b       parse_error

// add_label: reads label_name_buf + x16 (current position, = label's address),
// appends a 32-byte entry (24-byte name + 8-byte address) at x27 + x28*32,
// then increments x28. Pass-1-only caller (see label_done).
add_label:
    mov     x0, x28
    lsl     x0, x0, #5
    add     x0, x27, x0
    adrp    x1, label_name_buf
    add     x1, x1, :lo12:label_name_buf
    mov     x2, #0
al_copy:
    cmp     x2, #24
    b.ge    al_addr
    ldrb    w3, [x1, x2]
    strb    w3, [x0, x2]
    add     x2, x2, #1
    b       al_copy
al_addr:
    str     x16, [x0, #24]
    add     x28, x28, #1
    ret

// find_label: looks up label_name_buf in the table (x27, count x28). Returns
// address in x0. Undefined label -> parse_error (hard error, no silent
// fallback). Pass-2-only caller.
find_label:
    mov     x4, #0
fl_loop:
    cmp     x4, x28
    b.ge    fl_notfound
    mov     x0, x4
    lsl     x0, x0, #5
    add     x0, x27, x0
    adrp    x1, label_name_buf
    add     x1, x1, :lo12:label_name_buf
    mov     x2, #0
fl_cmp:
    cmp     x2, #24
    b.ge    fl_match
    ldrb    w3, [x0, x2]
    ldrb    w5, [x1, x2]
    cmp     w3, w5
    b.ne    fl_next
    add     x2, x2, #1
    b       fl_cmp
fl_next:
    add     x4, x4, #1
    b       fl_loop
fl_match:
    ldr     x0, [x0, #24]
    ret
fl_notfound:
    b       parse_error

// parse_cond: reads exactly 2 letters at x21 (eq/ne/lt/ge/gt/le/hi/ls),
// advances x21 by 2, returns ARM64 condition-code nibble in x0. Unknown
// condition -> parse_error.
parse_cond:
    ldrb    w0, [x21]
    ldrb    w1, [x21, #1]
    add     x21, x21, #2
    cmp     w0, #'e'
    b.ne    pc_n
    cmp     w1, #'q'
    b.ne    pc_err
    mov     x0, #0x0
    ret
pc_n:
    cmp     w0, #'n'
    b.ne    pc_l
    cmp     w1, #'e'
    b.ne    pc_err
    mov     x0, #0x1
    ret
pc_l:
    cmp     w0, #'l'
    b.ne    pc_g
    cmp     w1, #'t'
    b.eq    pc_lt
    cmp     w1, #'e'
    b.eq    pc_le
    cmp     w1, #'s'
    b.eq    pc_ls
    b       pc_err
pc_lt:
    mov     x0, #0xB
    ret
pc_le:
    mov     x0, #0xD
    ret
pc_ls:
    mov     x0, #0x9
    ret
pc_g:
    cmp     w0, #'g'
    b.ne    pc_h
    cmp     w1, #'t'
    b.eq    pc_gt
    cmp     w1, #'e'
    b.eq    pc_ge
    b       pc_err
pc_gt:
    mov     x0, #0xC
    ret
pc_ge:
    mov     x0, #0xA
    ret
pc_h:
    cmp     w0, #'h'
    b.ne    pc_err
    cmp     w1, #'i'
    b.ne    pc_err
    mov     x0, #0x8
    ret
pc_err:
    b       parse_error

// ---- handle_mov: "mov xD, IMM" or "mov xD, xS"  (cursor x21 already past "mov") ----
handle_mov:
    stp     x29, x30, [sp, #-16]!
    bl      skip_spaces
    bl      parse_register              // x0 = Rd
    mov     x24, x0
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #','
    b.ne    hm_err
    add     x21, x21, #1
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #'x'
    b.eq    hm_reg

    bl      parse_number                // x0 = imm16
    mov     w2, #0xD280
    lsl     w2, w2, #16                 // 0xD2800000  (MOVZ base)
    lsl     w3, w0, #5
    orr     w2, w2, w3
    orr     w2, w2, w24
    bl      finish_instr
    b       hm_done
hm_reg:
    bl      parse_register              // x0 = Rm
    mov     w2, #0xAA00
    lsl     w2, w2, #16                 // 0xAA000000  (ORR shifted-reg base, "MOV" alias)
    lsl     w3, w0, #16
    orr     w2, w2, w3
    mov     w4, #31
    lsl     w4, w4, #5                  // Rn = xzr(31)
    orr     w2, w2, w4
    orr     w2, w2, w24
    bl      finish_instr
hm_done:
    ldp     x29, x30, [sp], #16
    ret
hm_err:
    ldp     x29, x30, [sp], #16
    b       parse_error

// ---- handle_add: "add xD, xA, xB" or "add xD, xA, IMM" ----
handle_add:
    stp     x29, x30, [sp, #-16]!
    bl      skip_spaces
    bl      parse_register              // Rd
    mov     x24, x0
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #','
    b.ne    ha_err
    add     x21, x21, #1
    bl      skip_spaces
    bl      parse_register              // Rn
    mov     x9, x0
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #','
    b.ne    ha_err
    add     x21, x21, #1
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #'x'
    b.eq    ha_reg

    bl      parse_number                // imm12
    mov     w2, #0x9100
    lsl     w2, w2, #16                 // 0x91000000  (ADD immediate base)
    lsl     w3, w0, #10
    orr     w2, w2, w3
    lsl     w4, w9, #5
    orr     w2, w2, w4
    orr     w2, w2, w24
    bl      finish_instr
    b       ha_done
ha_reg:
    bl      parse_register              // Rm
    mov     w2, #0x8B00
    lsl     w2, w2, #16                 // 0x8B000000  (ADD shifted-register base)
    lsl     w3, w0, #16
    orr     w2, w2, w3
    lsl     w4, w9, #5
    orr     w2, w2, w4
    orr     w2, w2, w24
    bl      finish_instr
ha_done:
    ldp     x29, x30, [sp], #16
    ret
ha_err:
    ldp     x29, x30, [sp], #16
    b       parse_error

// ---- handle_sub: "sub xD, xA, xB" or "sub xD, xA, IMM" ----
handle_sub:
    stp     x29, x30, [sp, #-16]!
    bl      skip_spaces
    bl      parse_register              // Rd
    mov     x24, x0
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #','
    b.ne    hs_err
    add     x21, x21, #1
    bl      skip_spaces
    bl      parse_register              // Rn
    mov     x9, x0
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #','
    b.ne    hs_err
    add     x21, x21, #1
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #'x'
    b.eq    hs_reg

    bl      parse_number                // imm12
    mov     w2, #0xD100
    lsl     w2, w2, #16                 // 0xD1000000  (SUB immediate base)
    lsl     w3, w0, #10
    orr     w2, w2, w3
    lsl     w4, w9, #5
    orr     w2, w2, w4
    orr     w2, w2, w24
    bl      finish_instr
    b       hs_done
hs_reg:
    bl      parse_register              // Rm
    mov     w2, #0xCB00
    lsl     w2, w2, #16                 // 0xCB000000  (SUB shifted-register base)
    lsl     w3, w0, #16
    orr     w2, w2, w3
    lsl     w4, w9, #5
    orr     w2, w2, w4
    orr     w2, w2, w24
    bl      finish_instr
hs_done:
    ldp     x29, x30, [sp], #16
    ret
hs_err:
    ldp     x29, x30, [sp], #16
    b       parse_error

// ---- handle_cmp: "cmp xA, xB" or "cmp xA, IMM"  (== SUBS xzr, xA, ...) ----
handle_cmp:
    stp     x29, x30, [sp, #-16]!
    bl      skip_spaces
    bl      parse_register              // Rn
    mov     x9, x0
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #','
    b.ne    hc_err
    add     x21, x21, #1
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #'x'
    b.eq    hc_reg

    bl      parse_number                // imm12
    mov     w2, #0xF100
    lsl     w2, w2, #16                 // 0xF1000000  (SUBS immediate base, Rd=xzr)
    lsl     w3, w0, #10
    orr     w2, w2, w3
    lsl     w4, w9, #5
    orr     w2, w2, w4
    mov     w5, #31
    orr     w2, w2, w5
    bl      finish_instr
    b       hc_done
hc_reg:
    bl      parse_register              // Rm
    mov     w2, #0xEB00
    lsl     w2, w2, #16                 // 0xEB000000  (SUBS shifted-register base, Rd=xzr)
    lsl     w3, w0, #16
    orr     w2, w2, w3
    lsl     w4, w9, #5
    orr     w2, w2, w4
    mov     w5, #31
    orr     w2, w2, w5
    bl      finish_instr
hc_done:
    ldp     x29, x30, [sp], #16
    ret
hc_err:
    ldp     x29, x30, [sp], #16
    b       parse_error

// ---- handle_ldr: "ldr xD, [xN]" or "ldr xD, [xN, #imm]"  (imm % 8 == 0) ----
handle_ldr:
    stp     x29, x30, [sp, #-16]!
    bl      skip_spaces
    bl      parse_register              // Rt
    mov     x24, x0
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #','
    b.ne    hl_err
    add     x21, x21, #1
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #'['
    b.ne    hl_err
    add     x21, x21, #1
    bl      skip_spaces
    bl      parse_register              // Rn
    mov     x9, x0
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #']'
    b.eq    hl_noimm
    cmp     w0, #','
    b.ne    hl_err
    add     x21, x21, #1
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #'#'
    b.ne    hl_err
    add     x21, x21, #1
    bl      parse_number                // x0 = imm (bytes)
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #']'
    b.ne    hl_err
    add     x21, x21, #1
    mov     x1, x0
    and     x1, x1, #7
    cmp     x1, #0
    b.ne    hl_err                      // offset must be multiple of 8
    lsr     x0, x0, #3                  // imm12 = imm/8
    b       hl_encode
hl_noimm:
    add     x21, x21, #1
    mov     x0, #0
hl_encode:
    mov     w2, #0xF940
    lsl     w2, w2, #16                 // 0xF9400000  (LDR immediate, 64-bit, unsigned offset)
    lsl     w3, w0, #10
    orr     w2, w2, w3
    lsl     w4, w9, #5
    orr     w2, w2, w4
    orr     w2, w2, w24
    bl      finish_instr
    ldp     x29, x30, [sp], #16
    ret
hl_err:
    ldp     x29, x30, [sp], #16
    b       parse_error

// ---- handle_str: "str xD, [xN]" or "str xD, [xN, #imm]"  (imm % 8 == 0) ----
handle_str:
    stp     x29, x30, [sp, #-16]!
    bl      skip_spaces
    bl      parse_register              // Rt
    mov     x24, x0
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #','
    b.ne    hst_err
    add     x21, x21, #1
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #'['
    b.ne    hst_err
    add     x21, x21, #1
    bl      skip_spaces
    bl      parse_register              // Rn
    mov     x9, x0
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #']'
    b.eq    hst_noimm
    cmp     w0, #','
    b.ne    hst_err
    add     x21, x21, #1
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #'#'
    b.ne    hst_err
    add     x21, x21, #1
    bl      parse_number                // x0 = imm (bytes)
    bl      skip_spaces
    ldrb    w0, [x21]
    cmp     w0, #']'
    b.ne    hst_err
    add     x21, x21, #1
    mov     x1, x0
    and     x1, x1, #7
    cmp     x1, #0
    b.ne    hst_err                     // offset must be multiple of 8
    lsr     x0, x0, #3
    b       hst_encode
hst_noimm:
    add     x21, x21, #1
    mov     x0, #0
hst_encode:
    mov     w2, #0xF900
    lsl     w2, w2, #16                 // 0xF9000000  (STR immediate, 64-bit, unsigned offset)
    lsl     w3, w0, #10
    orr     w2, w2, w3
    lsl     w4, w9, #5
    orr     w2, w2, w4
    orr     w2, w2, w24
    bl      finish_instr
    ldp     x29, x30, [sp], #16
    ret
hst_err:
    ldp     x29, x30, [sp], #16
    b       parse_error

// ---- handle_branch: cursor x21 already past leading 'b'. Handles:
//      "b label"          -> B          (unconditional)
//      "bl label"         -> BL         (branch and link)
//      "b.cond label"     -> B.cond     (conditional)
// Delta is computed only in pass 2 (label table is only complete after pass 1).
handle_branch:
    stp     x29, x30, [sp, #-16]!
    mov     x10, #0xE                   // sentinel for "unconditional" (unused as real cond code here)
    mov     x11, #0                     // 0 = plain/cond branch, 1 = BL
    ldrb    w0, [x21]
    cmp     w0, #'l'
    b.ne    hb_dot
    add     x21, x21, #1
    mov     x11, #1
    b       hb_target
hb_dot:
    cmp     w0, #'.'
    b.ne    hb_target                   // plain 'b' unconditional, no dot
    add     x21, x21, #1
    bl      parse_cond                  // x0 = cond nibble
    mov     x10, x0
hb_target:
    bl      skip_spaces
    bl      parse_label_name            // advances x21 past label name (needed both passes)
    cmp     x15, #1
    b.eq    hb_count
    bl      find_label                  // x0 = target byte offset
    sub     x0, x0, x16                 // delta = target - current position
    asr     x0, x0, #2                  // instruction-count offset
    cmp     x11, #1
    b.eq    hb_bl
    cmp     x10, #0xE
    b.eq    hb_b
    // b.cond
    mov     w2, #0x5400
    lsl     w2, w2, #16                 // 0x54000000
    and     w3, w0, #0x7FFFF
    lsl     w3, w3, #5
    orr     w2, w2, w3
    orr     w2, w2, w10
    b       hb_finish
hb_b:
    mov     w2, #0x1400
    lsl     w2, w2, #16                 // 0x14000000
    and     w3, w0, #0x3FFFFFF
    orr     w2, w2, w3
    b       hb_finish
hb_bl:
    mov     w2, #0x9400
    lsl     w2, w2, #16                 // 0x94000000
    and     w3, w0, #0x3FFFFFF
    orr     w2, w2, w3
    b       hb_finish
hb_count:
    mov     w2, #0                      // dummy — not written in pass 1
hb_finish:
    bl      finish_instr
    ldp     x29, x30, [sp], #16
    ret

// ---- handle_svc: "svc IMM" ----
handle_svc:
    stp     x29, x30, [sp, #-16]!
    bl      skip_spaces
    bl      parse_number
    mov     w2, #0xD400
    lsl     w2, w2, #16                 // 0xD4000000
    lsl     w3, w0, #5
    orr     w2, w2, w3
    orr     w2, w2, #1
    bl      finish_instr
    ldp     x29, x30, [sp], #16
    ret

// ---- write_elf: patch filesz/memsz, write header+code to output file ----
write_elf:
    stp     x29, x30, [sp, #-16]!

    adrp    x0, elf_header
    add     x0, x0, :lo12:elf_header
    mov     x1, #120
    add     x1, x1, x23
    str     x1, [x0, #96]
    str     x1, [x0, #104]

    mov     x0, #-100
    mov     x1, x26
    mov     x2, #577
    mov     x3, #493
    mov     x8, #56
    svc     #0
    cmp     x0, #0
    b.lt    io_error
    mov     x20, x0

    mov     x0, x20
    adrp    x1, elf_header
    add     x1, x1, :lo12:elf_header
    mov     x2, #120
    mov     x8, #64
    svc     #0

    mov     x0, x20
    adrp    x1, code_buf
    add     x1, x1, :lo12:code_buf
    mov     x2, x23
    mov     x8, #64
    svc     #0

    mov     x0, x20
    mov     x8, #57
    svc     #0

    ldp     x29, x30, [sp], #16
    ret

usage_error:
    mov     x0, #2
    adrp    x1, msg_usage
    add     x1, x1, :lo12:msg_usage
    mov     x2, #msg_usage_len
    mov     x8, #64
    svc     #0
    mov     x0, #1
    mov     x8, #93
    svc     #0

io_error:
parse_error:
    mov     x0, #2
    adrp    x1, msg_error
    add     x1, x1, :lo12:msg_error
    mov     x2, #msg_error_len
    mov     x8, #64
    svc     #0
    mov     x0, #1
    mov     x8, #93
    svc     #0

    .data
    .align 4
elf_header:
    .byte   0x7f, 0x45, 0x4c, 0x46
    .byte   2, 1, 1, 0
    .byte   0,0,0,0,0,0,0,0
    .hword  2
    .hword  0xb7
    .word   1
    .quad   0x400078
    .quad   64
    .quad   0
    .word   0
    .hword  64
    .hword  56
    .hword  1
    .hword  0
    .hword  0
    .hword  0
    .word   1
    .word   5
    .quad   0
    .quad   0x400000
    .quad   0x400000
    .quad   0
    .quad   0
    .quad   0x10000

msg_usage:
    .ascii "usage: j2k_asm <input.jasm> <output_elf>\n"
msg_usage_len = . - msg_usage

msg_error:
    .ascii "j2k_asm: parse or I/O error\n"
msg_error_len = . - msg_error

    .bss
    .align 4
input_buf:
    .skip 4096
code_buf:
    .skip 8192
label_table:
    .skip 8192
label_name_buf:
    .skip 32
