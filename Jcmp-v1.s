// Jcmp-v1.s — J2K Compiler v1 (Phase 1 ขั้น 3 — เขียนต่อในไฟล์เดียวนี้ไปเรื่อยๆ
// ตาม sub-step, ไม่แยกไฟล์ตามเวอร์ชันย่อยอีกต่อไปตามที่ Jao กำหนด)
//
// Sub-step ที่รวมอยู่ในไฟล์นี้แล้ว:
//   v1.1 (2026-08-21): if / else if / else
//   v1.2 (2026-08-21): while, break/continue, compound assignment (++ -- += -=)
//
// ต่อยอดจาก Jcmp v0 (ตัวแปร/arithmetic/return) — syntax ทั้งหมดเป็น subset ของ
// syntax-design.md ที่ล็อคไว้แล้ว (ข้อ 7 if/else, ข้อ 18 while/for, ข้อ 19
// compound assignment, ข้อ 20 break/continue) ไม่มีการคิด syntax ใหม่
// เขียนด้วย ARM64 asm ล้วน, build ด้วย as/ld ตรงๆ (bootstrap เหมือน v0/j2k_asm)
//
// pipeline: Jcmp-v1 (.jk -> .jasm)  -->  j2k_asm_v0.3 (.jasm -> ELF)
// (j2k_asm v0.3 รองรับ b.eq/b.ne/b.lt/b.ge/b.gt/b.le อยู่แล้ว — ไม่ต้องแก้
// assembler เพิ่มเลยสำหรับ if/while)
//
// Syntax ใหม่ที่เพิ่ม (subset ของ syntax-design.md ข้อ 7/18/19/20 ที่ล็อคไว้แล้ว):
//   if x > 5 {
//       ...
//   } else if x == 3 {
//       ...
//   } else {
//       ...
//   }
//
//   while x < 10 {
//       ...
//       x++;
//       if x == 5 { break; }
//       if x == 3 { continue; }
//   }
//
// ข้อจำกัดของ v1.1 (if/else, ตั้งใจ เพิ่มเติมจาก v0):
//   - เงื่อนไข "A op B": A (ฝั่งซ้าย) ต้องเป็นชื่อตัวแปรเสมอ (ตรงกับข้อจำกัด
//     เดียวกับ arithmetic expression ที่มีอยู่แล้ว — สอดคล้องกับที่ cmp ใน
//     j2k_asm ต้องการ register เป็น operand แรกเสมอ) B เป็นตัวแปรหรือตัวเลขได้
//   - comparison operator รองรับ == != < > <= >= (ไม่มี &&/|| ใน v1.1 นี้)
//   - ตัวแปรยังเป็น flat global (ไม่มี block scoping จริง — ตัวแปรที่ประกาศใน
//     if-block ยังมองเห็น/ใช้ต่อได้นอก block ด้วย เป็นข้อจำกัดที่ตั้งใจ รอ v1.x
//     ถัดไปค่อยทำ scope จริง)
//   - `return` ไม่ได้บังคับให้เป็น statement สุดท้ายอีกต่อไป (เพราะอยู่ใน
//     if-block ได้) แต่ยังคงมีความหมายเดิม: emit exit-sequence ตรงจุดที่เจอ
//     โค้ดหลัง return (ถ้ามี) จะยัง compile แต่ unreachable ตอนรันจริง
//
// ข้อจำกัดของ v1.2 (while/break/continue/compound-assign, ตั้งใจ):
//   - `while` ใช้เงื่อนไขกฎเดียวกับ `if` (LHS ต้องเป็นตัวแปร)
//   - รองรับ compound assignment แค่ `++` `--` `+=` `-=` — **`*=` และ `/=` ยัง
//     ไม่รองรับ** เพราะ j2k_asm v0.3 ยังไม่มี mnemonic `mul`/`udiv`/`sdiv` เลย
//     (ใช้ `*=`/`/=` ในโค้ด .jk จะได้ parse_error) — ต้องขยาย j2k_asm ก่อนถึง
//     จะรองรับได้ เป็นงานแยกต่างหากที่ยังไม่ได้ทำ
//   - `break`/`continue` นอก loop ใดๆ เลย -> parse_error
//   - ยังไม่มี `for` (ทั้ง C-style และ range-style) — เก็บไว้ sub-step ถัดไป
//
// Build:
//   as -o Jcmp-v1.o Jcmp-v1.s
//   ld -o Jcmp Jcmp-v1.o
//   chmod +x Jcmp
//
// ทดสอบตัวอย่าง (test_if.jk):
//   i main() {
//       i x = 10;
//       if x > 5 {
//           return 1;
//       } else {
//           return 0;
//       }
//   }
// คาด: ./test_if_out ; echo $? --> 1
//
// ทดสอบ else-if (test_elif.jk):
//   i main() {
//       i x = 3;
//       if x == 1 {
//           return 10;
//       } else if x == 3 {
//           return 30;
//       } else {
//           return 99;
//       }
//   }
// คาด: ./test_elif_out ; echo $? --> 30
//
// ทดสอบ while (test_while.jk) — บวกเลขไปเรื่อยๆ จนถึง 5:
//   i main() {
//       i sum = 0;
//       i i = 0;
//       while i < 5 {
//           sum += i;
//           i++;
//       }
//       return sum;
//   }
// คาด: ./test_while_out ; echo $? --> 10   (0+1+2+3+4)
//
// ทดสอบ break/continue (test_breakcontinue.jk):
//   i main() {
//       i i = 0;
//       i sum = 0;
//       while i < 10 {
//           i++;
//           if i == 7 { break; }
//           if i == 3 { continue; }
//           sum += i;
//       }
//       return sum;
//   }
// คาด: 1+2+4+5+6 = 18 (ข้าม 3 ด้วย continue, หยุดก่อนบวก 7 ด้วย break)
// ./test_breakcontinue_out ; echo $? --> 18

    .global _start
    .text

_start:
    ldr     x0, [sp]
    cmp     x0, #3
    b.lt    usage_error

    ldr     x25, [sp, #16]              // x25 = input .jk path
    ldr     x26, [sp, #24]              // x26 = output .jasm path

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
    mov     x23, x0                     // bytes read

    mov     x0, x19
    mov     x8, #57                     // close
    svc     #0

    adrp    x21, input_buf
    add     x21, x21, :lo12:input_buf
    add     x20, x21, x23               // x20 = end of input (unused beyond this
                                         // point in v0 — parser trusts well-formed
                                         // input and stops at matching '}')

    adrp    x22, output_buf
    add     x22, x22, :lo12:output_buf
    mov     x27, x22                    // x27 = output_buf base (length calc later)

    adrp    x28, symtab
    add     x28, x28, :lo12:symtab
    mov     x17, #0                     // x17 = symbol count
    mov     x18, #1                     // x18 = next free register number (x1..x7)
    mov     x16, #0                     // x16 = global label counter (for if/else/while)
    mov     x15, #0                     // x15 = loop-context stack depth (0 = not in a loop)

    // ---- parse header: "i" ws "main" ws "(" ws ")" ws "{" ----
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #'i'
    b.ne    parse_error
    add     x21, x21, #1
    bl      skip_ws
    adrp    x1, kw_main
    add     x1, x1, :lo12:kw_main
    mov     x2, #4
    bl      match_word
    cmp     x0, #1
    b.ne    parse_error
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #'('
    b.ne    parse_error
    add     x21, x21, #1
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #')'
    b.ne    parse_error
    add     x21, x21, #1
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #'{'
    b.ne    parse_error
    add     x21, x21, #1

    // ---- parse body via parse_block (handles nested if/else, decl, return) ----
    bl      parse_block                 // consumes statements up to and including
                                         // the matching '}' of main()
    b       compile_done

// ==================== statement / block parsing (v1.1: if/else) ====================

// parse_block: caller must have already consumed the opening '{'. Loops
// parsing statements until (and consuming) the matching '}'. Recursive —
// used for main()'s body AND for if/else-if/else bodies (nested if works via
// normal call-stack recursion, each parse_if_chain invocation has its own
// stack frame so nested ifs don't clobber each other's label numbers).
//
// v1.1 statement dispatch:
//   '}'      -> end of this block
//   'r'      -> return statement
//   "if"     -> if/else-if/else chain (checked as 'i' + 'f' + non-identifier
//               boundary char, to distinguish from "i " variable declaration)
//   'i' (else) -> variable declaration
parse_block:
    stp     x29, x30, [sp, #-16]!
pb_loop:
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #'}'
    b.eq    pb_end
    cmp     w0, #'i'
    b.eq    pb_i_dispatch

    // try each keyword with word-boundary matching (non-destructive on
    // failure) BEFORE falling back to "it's an identifier -> assignment
    // statement". This matters now that variable names like "count" (starts
    // with 'c', same as "continue") or "result"/"row" (starts with 'r', same
    // as "return") are realistic — a bare first-letter peek would misroute
    // them, so we do a real keyword comparison here instead.
    adrp    x1, kw_return
    add     x1, x1, :lo12:kw_return
    mov     x2, #6
    bl      match_word
    cmp     x0, #1
    b.eq    pb_return

    adrp    x1, kw_while
    add     x1, x1, :lo12:kw_while
    mov     x2, #5
    bl      match_word
    cmp     x0, #1
    b.eq    pb_while

    adrp    x1, kw_break
    add     x1, x1, :lo12:kw_break
    mov     x2, #5
    bl      match_word
    cmp     x0, #1
    b.eq    pb_break

    adrp    x1, kw_continue
    add     x1, x1, :lo12:kw_continue
    mov     x2, #8
    bl      match_word
    cmp     x0, #1
    b.eq    pb_continue

    b       pb_assign

pb_i_dispatch:
    ldrb    w0, [x21, #1]
    cmp     w0, #'f'
    b.ne    pb_i_not_if
    ldrb    w0, [x21, #2]
    cmp     w0, #'a'
    b.lt    pb_bc2
    cmp     w0, #'z'
    b.le    pb_i_not_if                 // identifier starting "if..." (e.g.
                                         // "iffy") — not the "if" keyword,
                                         // fall through to the same check below
pb_bc2:
    cmp     w0, #'A'
    b.lt    pb_bc3
    cmp     w0, #'Z'
    b.le    pb_i_not_if
pb_bc3:
    cmp     w0, #'0'
    b.lt    pb_bc4
    cmp     w0, #'9'
    b.le    pb_i_not_if
pb_bc4:
    cmp     w0, #'_'
    b.eq    pb_i_not_if
    bl      parse_if_chain
    b       pb_loop
pb_i_not_if:
    // Not "if". Could still be the `i` TYPE keyword starting a declaration
    // ("i x = 5;") OR a plain identifier that happens to start with 'i' used
    // in an assignment statement — most commonly a variable literally named
    // "i" (extremely common loop counter, e.g. "i++;"), or "index", "item",
    // etc. The type keyword `i` is always followed immediately by whitespace
    // before the variable name; anything else means it's just an identifier.
    ldrb    w0, [x21, #1]
    cmp     w0, #' '
    b.eq    pb_decl
    cmp     w0, #9                      // tab
    b.eq    pb_decl
    b       pb_assign
pb_decl:
    bl      parse_decl_stmt
    b       pb_loop
pb_return:
    // keyword already consumed by match_word above
    bl      parse_return_stmt
    b       pb_loop
pb_while:
    // keyword already consumed by match_word above
    bl      parse_while_stmt
    b       pb_loop
pb_break:
    bl      parse_break_stmt
    b       pb_loop
pb_continue:
    bl      parse_continue_stmt
    b       pb_loop
pb_assign:
    bl      parse_assign_stmt
    b       pb_loop
pb_end:
    add     x21, x21, #1                // consume '}'
    ldp     x29, x30, [sp], #16
    ret

// parse_decl_stmt: "i NAME = A [op B];" — same logic as v0's try_decl, just
// refactored into a callable subroutine that returns to its caller (parse_block)
// instead of jumping back to a fixed loop label.
// registers used across calls here: x12=kindA x13=valA x14=opchar x9=kindB x10=valB
parse_decl_stmt:
    stp     x29, x30, [sp, #-16]!
    add     x21, x21, #1                // consume 'i'
    bl      skip_ws
    bl      parse_ident                 // -> name_buf
    bl      save_lhs_name               // protect name from parse_operand's own
                                         // use of name_buf below
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #'='
    b.ne    parse_error
    add     x21, x21, #1
    bl      skip_ws
    bl      parse_operand               // x0=kindA, x1=valA
    mov     x12, x0
    mov     x13, x1
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #';'
    b.eq    pds_single

    mov     x14, x0
    add     x21, x21, #1
    bl      skip_ws
    bl      parse_operand               // x0=kindB, x1=valB
    mov     x9, x0
    mov     x10, x1
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #';'
    b.ne    parse_error
    add     x21, x21, #1

    cmp     x18, #8
    b.ge    parse_error                 // too many variables (max 7)
    mov     x1, x18
    bl      symtab_add
    mov     x24, x18
    add     x18, x18, #1

    mov     x0, x24
    mov     x1, x12
    mov     x2, x13
    bl      emit_mov_line
    mov     x0, x14
    mov     x1, x24
    mov     x2, x9
    mov     x3, x10
    bl      emit_binop_line
    ldp     x29, x30, [sp], #16
    ret

pds_single:
    add     x21, x21, #1                // consume ';'
    cmp     x18, #8
    b.ge    parse_error
    mov     x1, x18
    bl      symtab_add
    mov     x24, x18
    add     x18, x18, #1
    mov     x0, x24
    mov     x1, x12
    mov     x2, x13
    bl      emit_mov_line
    ldp     x29, x30, [sp], #16
    ret

// parse_return_stmt: "return A [op B];" — emits the value into x0 then the
// fixed exit sequence. v1.1 CHANGE from v0: this no longer jumps straight to
// compile_done — it just emits code and returns normally, since `return` can
// now appear inside an if/else block with more (unreachable-at-runtime, but
// still syntactically-present) code after it. The program still always
// terminates via this emitted `svc` at runtime regardless of where it sits.
// registers used across calls here: x12=kindA x13=valA x14=opchar x9=kindB x10=valB
parse_return_stmt:
    stp     x29, x30, [sp, #-16]!
    // NOTE: "return" keyword already matched+consumed by parse_block's
    // dispatch (word-boundary-safe match_word) before calling here.
    bl      skip_ws
    bl      parse_operand               // x0=kindA, x1=valA
    mov     x12, x0
    mov     x13, x1
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #';'
    b.eq    prs_single

    mov     x14, x0                     // op char
    add     x21, x21, #1
    bl      skip_ws
    bl      parse_operand               // x0=kindB, x1=valB
    mov     x9, x0
    mov     x10, x1
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #';'
    b.ne    parse_error
    add     x21, x21, #1

    mov     x0, #0                      // target reg = x0
    mov     x1, x12
    mov     x2, x13
    bl      emit_mov_line
    mov     x0, x14
    mov     x1, #0
    mov     x2, x9
    mov     x3, x10
    bl      emit_binop_line
    b       prs_finish

prs_single:
    add     x21, x21, #1                // consume ';'
    mov     x0, #0
    mov     x1, x12
    mov     x2, x13
    bl      emit_mov_line

prs_finish:
    adrp    x0, code_exit
    add     x0, x0, :lo12:code_exit
    mov     x1, #code_exit_len
    bl      emit_bytes
    ldp     x29, x30, [sp], #16
    ret

// parse_cmp_op: reads one of == != < > <= >= at x21, advances x21 past it,
// returns opcode 0-5 in x0 (0==, 1!=, 2<, 3>, 4<=, 5>=). Unknown -> parse_error.
parse_cmp_op:
    ldrb    w0, [x21]
    cmp     w0, #'='
    b.ne    pco_bang
    ldrb    w1, [x21, #1]
    cmp     w1, #'='
    b.ne    parse_error
    add     x21, x21, #2
    mov     x0, #0
    ret
pco_bang:
    cmp     w0, #'!'
    b.ne    pco_lt
    ldrb    w1, [x21, #1]
    cmp     w1, #'='
    b.ne    parse_error
    add     x21, x21, #2
    mov     x0, #1
    ret
pco_lt:
    cmp     w0, #'<'
    b.ne    pco_gt
    ldrb    w1, [x21, #1]
    cmp     w1, #'='
    b.eq    pco_le
    add     x21, x21, #1
    mov     x0, #2
    ret
pco_le:
    add     x21, x21, #2
    mov     x0, #4
    ret
pco_gt:
    cmp     w0, #'>'
    b.ne    parse_error
    ldrb    w1, [x21, #1]
    cmp     w1, #'='
    b.eq    pco_ge
    add     x21, x21, #1
    mov     x0, #3
    ret
pco_ge:
    add     x21, x21, #2
    mov     x0, #5
    ret

// parse_if_chain: cursor x21 already at 'i' of "if". Handles the full
// if / else-if* / else? chain, emitting cmp + inverse-branch + block code +
// jump-to-end + label defs, using j2k_asm v0.3's b.eq/b.ne/b.lt/b.ge/b.gt/b.le
// (already supported — no assembler changes needed).
//
// Limitation (documented, consistent with the existing "A op B, A must be a
// variable" rule used elsewhere): the LEFT side of a condition must be a
// variable (matches j2k_asm's `cmp xA, ...` form, which always takes a
// register as its first operand) — e.g. `if 5 > x { ... }` is NOT supported,
// write `if x < 5 { ... }` instead.
//
// Stack frame locals: [sp,#16]=Lend  [sp,#24]=Lnext (current branch target)
parse_if_chain:
    stp     x29, x30, [sp, #-32]!
    mov     x0, x16
    add     x16, x16, #1
    str     x0, [sp, #16]               // Lend
    add     x21, x21, #2                // consume "if"

pic_branch_loop:
    bl      skip_ws
    bl      parse_operand               // condition LHS: x0=kind, x1=val
    cmp     x0, #1
    b.ne    parse_error                 // LHS must be a variable, not a literal
    mov     x12, x1                     // regA (x12/x13/x14/x9 — safe across the
                                         // next parse_operand call below, which
                                         // internally uses x0-x8 as scratch via
                                         // parse_ident/symtab_find)
    bl      skip_ws
    bl      parse_cmp_op                // x0 = opcode 0-5
    mov     x13, x0                     // opcode
    bl      skip_ws
    bl      parse_operand               // condition RHS: x0=kindB, x1=valB
    mov     x14, x0                     // kindB
    mov     x9, x1                      // valB

    mov     x0, x12                     // regA
    mov     x1, x14                     // kindB
    mov     x2, x9                      // valB
    bl      emit_cmp_line

    mov     x0, x16
    add     x16, x16, #1
    str     x0, [sp, #24]               // Lnext
    mov     x0, x13                     // opcode
    ldr     x1, [sp, #24]
    bl      emit_inverse_branch

    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #'{'
    b.ne    parse_error
    add     x21, x21, #1
    bl      parse_block                 // consumes up to and including '}'

    ldr     x0, [sp, #16]               // Lend
    bl      emit_jump
    ldr     x0, [sp, #24]               // Lnext
    bl      emit_label_def

    bl      skip_ws
    adrp    x1, kw_else
    add     x1, x1, :lo12:kw_else
    mov     x2, #4
    bl      match_word
    cmp     x0, #1
    b.ne    pic_finish
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #'i'
    b.ne    pic_plain_else
    ldrb    w0, [x21, #1]
    cmp     w0, #'f'
    b.ne    pic_plain_else
    add     x21, x21, #2                // consume "if"
    b       pic_branch_loop

pic_plain_else:
    ldrb    w0, [x21]
    cmp     w0, #'{'
    b.ne    parse_error
    add     x21, x21, #1
    bl      parse_block

pic_finish:
    ldr     x0, [sp, #16]               // Lend
    bl      emit_label_def
    ldp     x29, x30, [sp], #32
    ret

// ==================== v1.2: while / break / continue / compound assignment ====================

// Loop-context stack (global, .bss): each entry is 16 bytes (Lstart:8 +
// Lend:8). x15 = current stack depth (0 = not inside any loop). Pushed by
// parse_while_stmt before parsing its body, popped after — this correctly
// tracks the INNERMOST enclosing loop across arbitrary nesting because it's
// real memory, synchronized with the call-stack recursion of parse_block.
push_loop_ctx:
    // x0=Lstart, x1=Lend
    adrp    x2, loop_stack
    add     x2, x2, :lo12:loop_stack
    lsl     x3, x15, #4
    add     x2, x2, x3
    str     x0, [x2]
    str     x1, [x2, #8]
    add     x15, x15, #1
    ret

pop_loop_ctx:
    sub     x15, x15, #1
    ret

// current_loop_lend / current_loop_lstart: x0 = Lend/Lstart of the innermost
// active loop. Caller (break/continue) must check x15!=0 first (checked by
// parse_break_stmt/parse_continue_stmt directly, not here).
current_loop_lend:
    sub     x0, x15, #1
    lsl     x0, x0, #4
    adrp    x1, loop_stack
    add     x1, x1, :lo12:loop_stack
    add     x1, x1, x0
    ldr     x0, [x1, #8]
    ret

current_loop_lstart:
    sub     x0, x15, #1
    lsl     x0, x0, #4
    adrp    x1, loop_stack
    add     x1, x1, :lo12:loop_stack
    add     x1, x1, x0
    ldr     x0, [x1]
    ret

// parse_while_stmt: cursor already past "while" (consumed by parse_block's
// dispatch). "while A op B { block }" — same condition rules as if (LHS must
// be a variable). Lstart/Lend are kept on THIS frame's stack (not registers)
// so they survive the recursive bl parse_block call for the loop body no
// matter how deeply it nests (same fix as parse_if_chain's Lend/Lnext).
parse_while_stmt:
    stp     x29, x30, [sp, #-32]!
    mov     x0, x16
    add     x16, x16, #1
    str     x0, [sp, #16]               // Lstart
    bl      skip_ws
    bl      parse_operand               // condition LHS: x0=kind, x1=val
    cmp     x0, #1
    b.ne    parse_error                 // LHS must be a variable
    mov     x12, x1                     // regA (transient — not needed after
                                         // the emit_cmp_line call below, so
                                         // it's fine to hold it in x12 even
                                         // though x12 gets reused by nested
                                         // statements inside the loop body,
                                         // since we never read it again)
    bl      skip_ws
    bl      parse_cmp_op
    mov     x13, x0                     // opcode (same reasoning — transient)
    bl      skip_ws
    bl      parse_operand               // condition RHS: x0=kindB, x1=valB
    mov     x14, x0
    mov     x9, x1

    ldr     x0, [sp, #16]               // Lstart:
    bl      emit_label_def

    mov     x0, x12
    mov     x1, x14
    mov     x2, x9
    bl      emit_cmp_line

    mov     x0, x16
    add     x16, x16, #1
    str     x0, [sp, #24]               // Lend
    mov     x0, x13
    ldr     x1, [sp, #24]
    bl      emit_inverse_branch

    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #'{'
    b.ne    parse_error
    add     x21, x21, #1

    ldr     x0, [sp, #16]
    ldr     x1, [sp, #24]
    bl      push_loop_ctx
    bl      parse_block                 // Lstart/Lend safely on this frame's
                                         // stack throughout — untouched no
                                         // matter what nested statements do
    bl      pop_loop_ctx

    ldr     x0, [sp, #16]               // back to Lstart
    bl      emit_jump
    ldr     x0, [sp, #24]               // Lend:
    bl      emit_label_def

    ldp     x29, x30, [sp], #32
    ret

// parse_break_stmt: cursor already past "break". "break;" -> jump to
// innermost loop's Lend. Error if used outside any loop.
parse_break_stmt:
    stp     x29, x30, [sp, #-16]!
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #';'
    b.ne    parse_error
    add     x21, x21, #1
    cmp     x15, #0
    b.eq    parse_error                 // break outside any loop
    bl      current_loop_lend
    bl      emit_jump
    ldp     x29, x30, [sp], #16
    ret

// parse_continue_stmt: cursor already past "continue". "continue;" -> jump
// to innermost loop's Lstart (re-checks the condition). Error if used
// outside any loop.
parse_continue_stmt:
    stp     x29, x30, [sp, #-16]!
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #';'
    b.ne    parse_error
    add     x21, x21, #1
    cmp     x15, #0
    b.eq    parse_error                 // continue outside any loop
    bl      current_loop_lstart
    bl      emit_jump
    ldp     x29, x30, [sp], #16
    ret

// parse_assign_stmt: "NAME++;" / "NAME--;" / "NAME += A;" / "NAME -= A;"
// (compound assignment — section 19 of syntax-design.md). NAME must already
// be a declared variable (symtab_find errors if not).
//
// LIMITATION (documented, not silently skipped): `*=` and `/=` are NOT
// supported yet — j2k_asm v0.3 has no `mul`/`udiv`/`sdiv` mnemonic to emit
// them with. Using `*=` or `/=` is a parse_error in this version. Extending
// j2k_asm with those mnemonics is a separate, explicit follow-up task.
parse_assign_stmt:
    stp     x29, x30, [sp, #-16]!
    bl      parse_ident                 // -> name_buf
    bl      symtab_find                 // x0 = reg (parse_error if undefined)
    mov     x12, x0                     // reg (transient, not held across any
                                         // further recursive/heavy call below)
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #'+'
    b.eq    pas_plus
    cmp     w0, #'-'
    b.eq    pas_minus
    cmp     w0, #'*'
    b.eq    pas_unsupported
    cmp     w0, #'/'
    b.eq    pas_unsupported
    b       parse_error

pas_plus:
    ldrb    w0, [x21, #1]
    cmp     w0, #'+'
    b.eq    pas_inc
    cmp     w0, #'='
    b.eq    pas_pluseq
    b       parse_error
pas_inc:
    add     x21, x21, #2
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #';'
    b.ne    parse_error
    add     x21, x21, #1
    mov     x0, #'+'
    mov     x1, x12
    mov     x2, #0                      // kind=immediate
    mov     x3, #1                      // value=1
    bl      emit_binop_line
    ldp     x29, x30, [sp], #16
    ret

pas_minus:
    ldrb    w0, [x21, #1]
    cmp     w0, #'-'
    b.eq    pas_dec
    cmp     w0, #'='
    b.eq    pas_minuseq
    b       parse_error
pas_dec:
    add     x21, x21, #2
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #';'
    b.ne    parse_error
    add     x21, x21, #1
    mov     x0, #'-'
    mov     x1, x12
    mov     x2, #0
    mov     x3, #1
    bl      emit_binop_line
    ldp     x29, x30, [sp], #16
    ret

pas_pluseq:
    add     x21, x21, #2
    bl      skip_ws
    bl      parse_operand               // x0=kind, x1=val
    mov     x9, x0
    mov     x10, x1
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #';'
    b.ne    parse_error
    add     x21, x21, #1
    mov     x0, #'+'
    mov     x1, x12
    mov     x2, x9
    mov     x3, x10
    bl      emit_binop_line
    ldp     x29, x30, [sp], #16
    ret

pas_minuseq:
    add     x21, x21, #2
    bl      skip_ws
    bl      parse_operand
    mov     x9, x0
    mov     x10, x1
    bl      skip_ws
    ldrb    w0, [x21]
    cmp     w0, #';'
    b.ne    parse_error
    add     x21, x21, #1
    mov     x0, #'-'
    mov     x1, x12
    mov     x2, x9
    mov     x3, x10
    bl      emit_binop_line
    ldp     x29, x30, [sp], #16
    ret

pas_unsupported:
    b       parse_error                 // *= and /= — see limitation note above

// ==================== errors ====================
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

compile_done:
    sub     x1, x22, x27                // length of generated .jasm text
    mov     x0, x26                     // output path
    bl      write_output
    mov     x0, #0
    mov     x8, #93
    svc     #0

// ==================== leaf helpers (only x0-x4 scratch; x21 advanced as documented) ====================

skip_ws:
    ldrb    w0, [x21]
    cmp     w0, #32
    b.eq    sw_adv
    cmp     w0, #9
    b.eq    sw_adv
    cmp     w0, #10
    b.eq    sw_adv
    ret
sw_adv:
    add     x21, x21, #1
    b       skip_ws

parse_number:
    mov     x0, #0
pn_loop:
    ldrb    w1, [x21]
    sub     w2, w1, #48
    cmp     w2, #9
    b.hi    pn_done
    mov     x3, #10
    mul     x0, x0, x3
    add     x0, x0, x2
    add     x21, x21, #1
    b       pn_loop
pn_done:
    ret

parse_ident:
    adrp    x1, name_buf
    add     x1, x1, :lo12:name_buf
    mov     x2, #0
pi_loop:
    ldrb    w0, [x21]
    cmp     w0, #'a'
    b.lt    pi_cu
    cmp     w0, #'z'
    b.le    pi_store
pi_cu:
    cmp     w0, #'A'
    b.lt    pi_cd
    cmp     w0, #'Z'
    b.le    pi_store
pi_cd:
    cmp     w0, #'0'
    b.lt    pi_cus
    cmp     w0, #'9'
    b.le    pi_store
pi_cus:
    cmp     w0, #'_'
    b.eq    pi_store
    b       pi_pad
pi_store:
    cmp     x2, #23
    b.ge    pi_skip
    strb    w0, [x1, x2]
pi_skip:
    add     x2, x2, #1
    add     x21, x21, #1
    b       pi_loop
pi_pad:
    mov     x3, x2
pi_pad_loop:
    cmp     x3, #24
    b.ge    pi_done
    strb    wzr, [x1, x3]
    add     x3, x3, #1
    b       pi_pad_loop
pi_done:
    mov     x0, x2
    ret

// save_lhs_name: copies name_buf (24 bytes) -> lhs_name_buf. Called right
// after parsing a declared variable's name, to protect it from being
// overwritten later by parse_operand's own internal use of name_buf when
// reading the RHS expression's identifier operands.
save_lhs_name:
    adrp    x0, name_buf
    add     x0, x0, :lo12:name_buf
    adrp    x1, lhs_name_buf
    add     x1, x1, :lo12:lhs_name_buf
    mov     x2, #0
sln_loop:
    cmp     x2, #24
    b.ge    sln_done
    ldrb    w3, [x0, x2]
    strb    w3, [x1, x2]
    add     x2, x2, #1
    b       sln_loop
sln_done:
    ret

emit_bytes:
    // x0=ptr, x1=len — writes to [x22], advances x22
    mov     x2, #0
eb_loop:
    cmp     x2, x1
    b.ge    eb_done
    ldrb    w3, [x0, x2]
    strb    w3, [x22], #1
    add     x2, x2, #1
    b       eb_loop
eb_done:
    ret

// ==================== non-leaf helpers ====================

// match_word: x1=ptr to keyword, x2=len. Advances x21 by len ONLY if the len
// chars at x21 match AND the following char is not an identifier char (word
// boundary check, so "returnFoo" does not match "return"). Returns x0=1/0.
match_word:
    stp     x29, x30, [sp, #-16]!
    mov     x3, #0
mw_loop:
    cmp     x3, x2
    b.ge    mw_boundary
    ldrb    w0, [x21, x3]
    ldrb    w4, [x1, x3]
    cmp     w0, w4
    b.ne    mw_fail
    add     x3, x3, #1
    b       mw_loop
mw_boundary:
    ldrb    w0, [x21, x3]
    cmp     w0, #'a'
    b.lt    mw_bc2
    cmp     w0, #'z'
    b.le    mw_fail
mw_bc2:
    cmp     w0, #'A'
    b.lt    mw_bc3
    cmp     w0, #'Z'
    b.le    mw_fail
mw_bc3:
    cmp     w0, #'0'
    b.lt    mw_bc4
    cmp     w0, #'9'
    b.le    mw_fail
mw_bc4:
    cmp     w0, #'_'
    b.eq    mw_fail
    add     x21, x21, x2
    mov     x0, #1
    ldp     x29, x30, [sp], #16
    ret
mw_fail:
    mov     x0, #0
    ldp     x29, x30, [sp], #16
    ret

// parse_operand: reads at x21 — a decimal literal (kind=0) or an identifier
// that must already be a declared variable (kind=1, value=its register
// number). Returns x0=kind, x1=value. Undefined variable -> parse_error.
parse_operand:
    stp     x29, x30, [sp, #-16]!
    ldrb    w0, [x21]
    cmp     w0, #'0'
    b.lt    po_ident
    cmp     w0, #'9'
    b.gt    po_ident
    bl      parse_number
    mov     x1, x0
    mov     x0, #0
    ldp     x29, x30, [sp], #16
    ret
po_ident:
    bl      parse_ident
    bl      symtab_find
    mov     x1, x0
    mov     x0, #1
    ldp     x29, x30, [sp], #16
    ret

// symtab_add: x1=register number. Uses lhs_name_buf (saved by save_lhs_name,
// protected from being overwritten by parse_operand's own use of name_buf)
// + x17 (count) + x28 (table base). Appends 32-byte entry (24-byte name +
// 8-byte reg), increments x17.
symtab_add:
    mov     x0, x17
    lsl     x0, x0, #5
    add     x0, x28, x0
    adrp    x2, lhs_name_buf
    add     x2, x2, :lo12:lhs_name_buf
    mov     x3, #0
sa_copy:
    cmp     x3, #24
    b.ge    sa_regstore
    ldrb    w4, [x2, x3]
    strb    w4, [x0, x3]
    add     x3, x3, #1
    b       sa_copy
sa_regstore:
    str     x1, [x0, #24]
    add     x17, x17, #1
    ret

// symtab_find: looks up name_buf in table (x28, count x17). Returns register
// number in x0. Undefined variable -> parse_error (hard error).
symtab_find:
    mov     x4, #0
sf_loop:
    cmp     x4, x17
    b.ge    sf_notfound
    mov     x0, x4
    lsl     x0, x0, #5
    add     x0, x28, x0
    adrp    x1, name_buf
    add     x1, x1, :lo12:name_buf
    mov     x2, #0
sf_cmp:
    cmp     x2, #24
    b.ge    sf_match
    ldrb    w3, [x0, x2]
    ldrb    w5, [x1, x2]
    cmp     w3, w5
    b.ne    sf_next
    add     x2, x2, #1
    b       sf_cmp
sf_next:
    add     x4, x4, #1
    b       sf_loop
sf_match:
    ldr     x0, [x0, #24]
    ret
sf_notfound:
    b       parse_error

// emit_decimal: x0=value (unsigned). Writes decimal ASCII to [x22], advances
// x22. Only clobbers x0-x4 (never x5/x6/x7 — relied on by emit_mov_line and
// emit_binop_line to hold state across this call).
emit_decimal:
    stp     x29, x30, [sp, #-48]!
    cmp     x0, #0
    b.ne    ed_nonzero
    mov     w1, #'0'
    strb    w1, [x22], #1
    ldp     x29, x30, [sp], #48
    ret
ed_nonzero:
    mov     x1, x0
    mov     x2, #0
    add     x3, sp, #16
ed_loop:
    cmp     x1, #0
    b.eq    ed_write
    mov     x4, #10
    udiv    x0, x1, x4
    msub    x4, x0, x4, x1
    add     w4, w4, #'0'
    strb    w4, [x3, x2]
    add     x2, x2, #1
    mov     x1, x0
    b       ed_loop
ed_write:
    sub     x2, x2, #1
ed_write_loop:
    ldrb    w4, [x3, x2]
    strb    w4, [x22], #1
    cmp     x2, #0
    b.eq    ed_done
    sub     x2, x2, #1
    b       ed_write_loop
ed_done:
    ldp     x29, x30, [sp], #48
    ret

// emit_operand: x0=kind (0=immediate,1=register), x1=value. Kind 0 emits
// decimal(value). Kind 1 emits "x"+decimal(value). Only x0-x4 scratch.
emit_operand:
    stp     x29, x30, [sp, #-16]!
    cmp     x0, #1
    b.eq    eo_reg
    mov     x0, x1
    bl      emit_decimal
    b       eo_done
eo_reg:
    mov     w2, #'x'
    strb    w2, [x22], #1
    mov     x0, x1
    bl      emit_decimal
eo_done:
    ldp     x29, x30, [sp], #16
    ret

// emit_mov_line: x0=targetReg, x1=kind, x2=value. Emits "mov x{target}, {operand}\n"
emit_mov_line:
    stp     x29, x30, [sp, #-16]!
    mov     x5, x0
    mov     x6, x1
    mov     x7, x2
    adrp    x0, str_mov
    add     x0, x0, :lo12:str_mov
    mov     x1, #4
    bl      emit_bytes
    mov     w0, #'x'
    strb    w0, [x22], #1
    mov     x0, x5
    bl      emit_decimal
    adrp    x0, str_comma_sp
    add     x0, x0, :lo12:str_comma_sp
    mov     x1, #2
    bl      emit_bytes
    mov     x0, x6
    mov     x1, x7
    bl      emit_operand
    mov     w0, #10
    strb    w0, [x22], #1
    ldp     x29, x30, [sp], #16
    ret

// emit_binop_line: x0=opchar('+'/'-'), x1=targetReg, x2=kind, x3=value.
// Emits "add x{t}, x{t}, {operand}\n" or "sub ..." accordingly.
emit_binop_line:
    stp     x29, x30, [sp, #-16]!
    mov     x5, x1
    mov     x6, x2
    mov     x7, x3
    cmp     x0, #'+'
    b.eq    ebl_add
    adrp    x0, str_sub
    add     x0, x0, :lo12:str_sub
    b       ebl_op
ebl_add:
    adrp    x0, str_add
    add     x0, x0, :lo12:str_add
ebl_op:
    mov     x1, #4
    bl      emit_bytes
    mov     w0, #'x'
    strb    w0, [x22], #1
    mov     x0, x5
    bl      emit_decimal
    adrp    x0, str_comma_sp
    add     x0, x0, :lo12:str_comma_sp
    mov     x1, #2
    bl      emit_bytes
    mov     w0, #'x'
    strb    w0, [x22], #1
    mov     x0, x5
    bl      emit_decimal
    adrp    x0, str_comma_sp
    add     x0, x0, :lo12:str_comma_sp
    mov     x1, #2
    bl      emit_bytes
    mov     x0, x6
    mov     x1, x7
    bl      emit_operand
    mov     w0, #10
    strb    w0, [x22], #1
    ldp     x29, x30, [sp], #16
    ret

// emit_cmp_line: x0=regA, x1=kindB, x2=valB. Emits "cmp x{regA}, {operand}\n"
emit_cmp_line:
    stp     x29, x30, [sp, #-16]!
    mov     x5, x0
    mov     x6, x1
    mov     x7, x2
    adrp    x0, str_cmp
    add     x0, x0, :lo12:str_cmp
    mov     x1, #4
    bl      emit_bytes
    mov     w0, #'x'
    strb    w0, [x22], #1
    mov     x0, x5
    bl      emit_decimal
    adrp    x0, str_comma_sp
    add     x0, x0, :lo12:str_comma_sp
    mov     x1, #2
    bl      emit_bytes
    mov     x0, x6
    mov     x1, x7
    bl      emit_operand
    mov     w0, #10
    strb    w0, [x22], #1
    ldp     x29, x30, [sp], #16
    ret

// emit_inverse_branch: x0=opcode(0-5, from parse_cmp_op), x1=label number.
// Emits "b.{inverse-cond} L{num}\n" — the branch taken when the condition is
// FALSE, to skip over the if-body. Inverse mapping: ==→ne  !=→eq  <→ge  >→le
// <=→gt  >=→lt (matches cond_table order below, opcode indexes it directly).
emit_inverse_branch:
    stp     x29, x30, [sp, #-16]!
    mov     x6, x0                      // opcode
    mov     x5, x1                      // label num
    adrp    x0, str_b_dot
    add     x0, x0, :lo12:str_b_dot
    mov     x1, #2
    bl      emit_bytes
    adrp    x2, cond_table
    add     x2, x2, :lo12:cond_table
    lsl     x3, x6, #1
    add     x0, x2, x3
    mov     x1, #2
    bl      emit_bytes
    mov     w0, #' '
    strb    w0, [x22], #1
    mov     w0, #'L'
    strb    w0, [x22], #1
    mov     x0, x5
    bl      emit_decimal
    mov     w0, #10
    strb    w0, [x22], #1
    ldp     x29, x30, [sp], #16
    ret

// emit_jump: x0=label number. Emits "b L{num}\n" (unconditional).
emit_jump:
    stp     x29, x30, [sp, #-16]!
    mov     x5, x0
    mov     w0, #'b'
    strb    w0, [x22], #1
    mov     w0, #' '
    strb    w0, [x22], #1
    mov     w0, #'L'
    strb    w0, [x22], #1
    mov     x0, x5
    bl      emit_decimal
    mov     w0, #10
    strb    w0, [x22], #1
    ldp     x29, x30, [sp], #16
    ret

// emit_label_def: x0=label number. Emits "L{num}:\n"
emit_label_def:
    stp     x29, x30, [sp, #-16]!
    mov     x5, x0
    mov     w0, #'L'
    strb    w0, [x22], #1
    mov     x0, x5
    bl      emit_decimal
    mov     w0, #':'
    strb    w0, [x22], #1
    mov     w0, #10
    strb    w0, [x22], #1
    ldp     x29, x30, [sp], #16
    ret

// write_output: x0=path ptr, x1=length. Opens (O_WRONLY|O_CREAT|O_TRUNC,
// mode 0644), writes output_buf[0..length), closes.
write_output:
    stp     x29, x30, [sp, #-16]!
    mov     x5, x0
    mov     x6, x1
    mov     x0, #-100
    mov     x1, x5
    mov     x2, #577
    mov     x3, #420
    mov     x8, #56
    svc     #0
    cmp     x0, #0
    b.lt    io_error
    mov     x7, x0

    mov     x0, x7
    adrp    x1, output_buf
    add     x1, x1, :lo12:output_buf
    mov     x2, x6
    mov     x8, #64
    svc     #0

    mov     x0, x7
    mov     x8, #57
    svc     #0

    ldp     x29, x30, [sp], #16
    ret

    .data
    .align 4
kw_main:
    .ascii "main"
kw_return:
    .ascii "return"
kw_else:
    .ascii "else"
kw_while:
    .ascii "while"
kw_break:
    .ascii "break"
kw_continue:
    .ascii "continue"
str_mov:
    .ascii "mov "
str_add:
    .ascii "add "
str_sub:
    .ascii "sub "
str_cmp:
    .ascii "cmp "
str_b_dot:
    .ascii "b."
str_comma_sp:
    .ascii ", "
// cond_table: inverse-condition 2-char codes, indexed by opcode*2
// opcode: 0==  1!=  2<  3>  4<=  5>=
// inverse: 0->ne 1->eq 2->ge 3->le 4->gt 5->lt
cond_table:
    .ascii "ne"
    .ascii "eq"
    .ascii "ge"
    .ascii "le"
    .ascii "gt"
    .ascii "lt"
code_exit:
    .ascii "mov x8, 93\nsvc 0\n"
code_exit_len = . - code_exit

msg_usage:
    .ascii "usage: Jcmp-v1 <input.jk> <output.jasm>\n"
msg_usage_len = . - msg_usage

msg_error:
    .ascii "Jcmp-v1: parse or I/O error\n"
msg_error_len = . - msg_error

    .bss
    .align 4
input_buf:
    .skip 4096
output_buf:
    .skip 8192
symtab:
    .skip 256
name_buf:
    .skip 32
lhs_name_buf:
    .skip 32
loop_stack:
    .skip 256
