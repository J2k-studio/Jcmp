b j2k_start
.align 32
j2k_print_int:
sub sp, sp, #48
str x30, [sp, #40]
mov x1, 0
cmp x0, 0
b.ge j2k_pi1
mov x2, 0
sub x0, x2, x0
mov x1, 1
j2k_pi1:
mov x3, 40
mov x4, 10
j2k_pi2:
udiv x5, x0, x4
mul x6, x5, x4
sub x6, x0, x6
add x6, x6, #48
sub x3, x3, #1
add x7, sp, #0
add x7, x7, x3
strb x6, [x7, #0]
mov x0, x5
cmp x0, 0
b.ne j2k_pi2
cmp x1, 0
b.eq j2k_pi3
sub x3, x3, #1
add x7, sp, #0
add x7, x7, x3
mov x6, 45
strb x6, [x7, #0]
j2k_pi3:
mov x2, 40
sub x2, x2, x3
add x1, sp, #0
add x1, x1, x3
ldr x0, [x28, #864]
add x0, x0, #1
bl __wr
ldr x30, [sp, #40]
add sp, sp, #48
ret
j2k_print_str:
mov x1, x0
mov x2, 0
j2k_ps1:
add x3, x1, x2
ldrb x4, [x3, #0]
cmp x4, 0
b.eq j2k_ps2
add x2, x2, #1
b j2k_ps1
j2k_ps2:
ldr x0, [x28, #864]
add x0, x0, #1
b __wr
.align 32
j2k_print_char:
sub sp, sp, #16
str x30, [sp, #8]
strb x0, [sp, #0]
add x1, sp, #0
ldr x0, [x28, #864]
add x0, x0, #1
mov x2, 1
bl __wr
ldr x30, [sp, #8]
add sp, sp, #16
ret
j2k_copy16:
j2k_copy:
cmp x2, 0
b.eq j2k_cp2
j2k_cp1:
ldr x4, [x0, #0]
str x4, [x3, #0]
add x0, x0, #8
add x3, x3, #8
sub x2, x2, #8
cmp x2, 0
b.ne j2k_cp1
j2k_cp2:
ret
.align 32
__panic:
sub sp, sp, #0000144
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #128]
str x20, [x29, #96]
str x0, [x29, #16]
bl __flush
mov x0, 0
str x0, [x29, #24]
L8954:
ldr x0, [x29, #24]
ldr x1, [x29, #16]
add x0, x0, x1
ldrb x0, [x0, #0]
cmp x0, 0
b.eq L8956
ldr x0, [x29, #24]
add x0, x0, #1
str x0, [x29, #24]
b L8954
L8956:
mov x19, 64
add x20, x28, #70016
mov x3, 7
mov x8, 64
mov x0, 2
mov x1, x20
mov x2, 7
svc 0
mov x19, 64
ldr x20, [x29, #16]
ldr x3, [x29, #24]
mov x8, 64
mov x0, 2
mov x1, x20
mov x2, x3
svc 0
mov x19, 64
add x20, x28, #70024
mov x3, 1
mov x8, 64
mov x0, 2
mov x1, x20
mov x2, 1
svc 0
str x29, [x29, #32]
adr x0, j2k_fntab
str x0, [x29, #40]
mov x0, 0
str x0, [x29, #48]
L8969:
ldr x0, [x29, #32]
mov x1, 4096
cmp x0, x1
b.le L9013
ldr x0, [x29, #48]
cmp x0, 24
b.ge L9013
ldr x0, [x29, #32]
ldr x0, [x0, #8]
str x0, [x29, #56]
mov x0, -1
str x0, [x29, #64]
mov x0, 0
str x0, [x29, #72]
L8975:
ldr x0, [x29, #72]
mov x1, 2
mul x0, x0, x1
lsl x0, x0, #3
ldr x1, [x29, #40]
add x0, x0, x1
ldr x0, [x0, #0]
cmp x0, 0
b.eq L8979
ldr x0, [x29, #72]
mov x1, 2
mul x0, x0, x1
lsl x0, x0, #3
ldr x1, [x29, #40]
add x0, x0, x1
ldr x0, [x0, #0]
ldr x1, [x29, #56]
cmp x0, x1
b.ge L8978
ldr x0, [x29, #72]
str x0, [x29, #64]
L8978:
ldr x0, [x29, #72]
add x0, x0, #1
str x0, [x29, #72]
b L8975
L8979:
ldr x0, [x29, #64]
cmp x0, 0
b.lt L9013
ldr x0, [x29, #64]
mov x1, 2
mul x0, x0, x1
add x0, x0, #1
lsl x0, x0, #3
ldr x1, [x29, #40]
add x0, x0, x1
ldr x0, [x0, #0]
str x0, [x29, #80]
mov x19, 64
add x20, x28, #70032
mov x3, 5
mov x8, 64
mov x0, 2
mov x1, x20
mov x2, 5
svc 0
mov x0, 0
str x0, [x29, #88]
ldr x0, [x29, #80]
ldrb x0, [x0, #0]
cmp x0, 95
b.ne L8991
ldr x0, [x29, #80]
ldrb x0, [x0, #1]
cmp x0, 95
b.ne L8991
mov x0, 2
str x0, [x29, #88]
L8991:
ldr x0, [x29, #88]
ldr x1, [x29, #80]
add x0, x0, x1
ldrb x0, [x0, #0]
cmp x0, 0
b.eq L9008
ldr x0, [x29, #88]
ldr x1, [x29, #80]
add x0, x0, x1
ldrb x0, [x0, #0]
cmp x0, 95
b.ne L9002
ldr x0, [x29, #88]
add x0, x0, #1
ldr x1, [x29, #80]
add x0, x0, x1
ldrb x0, [x0, #0]
cmp x0, 95
b.ne L9002
mov x19, 64
add x20, x28, #70040
mov x3, 2
mov x8, 64
mov x0, 2
mov x1, x20
mov x2, 2
svc 0
ldr x0, [x29, #88]
add x0, x0, #2
str x0, [x29, #88]
b L8991
L9002:
mov x19, 64
ldr x0, [x29, #88]
ldr x1, [x29, #80]
add x20, x0, x1
mov x3, 1
mov x8, 64
mov x0, 2
mov x1, x20
mov x2, 1
svc 0
ldr x0, [x29, #88]
add x0, x0, #1
str x0, [x29, #88]
b L8991
L9008:
mov x19, 64
add x20, x28, #70048
mov x3, 1
mov x8, 64
mov x0, 2
mov x1, x20
mov x2, 1
svc 0
ldr x0, [x29, #32]
ldr x0, [x0, #0]
str x0, [x29, #32]
ldr x0, [x29, #48]
add x0, x0, #1
str x0, [x29, #48]
b L8969
L9013:
mov x1, 134
mov x0, 94
mov x19, x0
mov x20, x1
bl __flush
mov x1, x20
mov x8, x19
mov x0, x1
svc 0
L8952:
ldr x19, [x29, #128]
ldr x20, [x29, #96]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000144
ret
.align 32
Mem__alloc:
sub sp, sp, #0000064
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #40]
str x20, [x29, #48]
mov x9, x0
add x0, x28, #69456
ldr x0, [x0, #0]
cmp x0, 0
b.ne L9028
add x0, x28, #66984
ldr x0, [x0, #0]
cmp x0, 0
b.ne L9028
mov x0, x9
cmp x0, 0
b.le L9028
cmp x0, 2032
b.gt L9028
add x0, x0, #15
asr x0, x0, #4
mov x1, 16
mul x0, x0, x1
add x0, x0, #16
mov x1, 4
asr x0, x0, #4
add x0, x28, x0, lsl #3
add x0, x0, #67200
ldr x0, [x0, #0]
mov x8, x0
add x0, x28, x0, lsl #3
add x0, x0, #69264
ldr x0, [x0, #0]
mov x19, x0
cmp x0, 0
b.eq L9028
mov x20, x0
add x0, x28, x8, lsl #3
add x10, x0, #69264
ldr x0, [x20, #8]
str x0, [x10, #0]
mov x1, 0
str x1, [x20, #8]
add x3, x28, #66992
ldr x0, [x3, #0]
add x0, x0, #1
str x0, [x3, #0]
add x0, x19, #16
b L9030
L9028:
mov x0, x9
bl Mem__alloc_general
L9030:
L9018:
ldr x19, [x29, #40]
ldr x20, [x29, #48]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000064
ret
.align 32
Mem__alloc_general:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
mov x19, x0
add x0, x28, #69456
ldr x0, [x0, #0]
cmp x0, 0
b.eq L175
mov x0, x19
bl Mem__dbg_alloc
b L173
L175:
L174:
add x0, x28, #66984
ldr x0, [x0, #0]
cmp x0, 0
b.ne L178
mov x0, x19
bl Mem__alloc_raw
b L173
L178:
L177:
L180:
add x10, x28, #66976
mov x11, 0
mov x2, 1
mov x1, x11
mov x0, x10
L182:
ldaxr x3, [x0]
cmp x3, x1
b.ne L183
stlxr w4, x2, [x0]
cmp x4, 0
b.ne L182
L183:
dmb ish
cmp x3, 0
b.eq L181
mov x0, 124
cmp x0, 93
b.eq L185
cmp x0, 94
b.ne L186
L185:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L186:
mov x8, x0
svc 0
b L180
L181:
mov x0, x19
bl Mem__alloc_raw
mov x9, x0
add x10, x28, #66976
mov x1, 0
mov x0, x10
L187:
ldaxr x3, [x0]
stlxr w4, x1, [x0]
cmp x4, 0
b.ne L187
L188:
dmb ish
mov x0, x9
b L173
bl j2k_noret
L173:
ldr x19, [x29, #16]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
Mem__bump:
sub sp, sp, #0000064
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
mov x19, x0
add x0, x28, #66432
ldr x0, [x0, #0]
mov x1, x19
add x10, x0, x1
add x0, x28, #66440
ldr x0, [x0, #0]
cmp x10, x0
b.le L9042
mov x20, 1048576
mov x0, x1
mov x1, 1048576
cmp x0, x1
b.le L9035
add x0, x0, #4095
asr x2, x0, #63
lsr x2, x2, #52
add x2, x0, x2
asr x2, x2, #12
mov x1, 4096
mul x20, x2, x1
L9035:
mov x6, 0
mov x8, 222
mov x0, 0
mov x1, x20
mov x2, 3
mov x3, 34
mov x4, -1
mov x5, 0
svc 0
mov x9, x0
cmp x0, 0
b.ge L9041
mov x0, 0
b L9044
L9041:
add x3, x28, #66432
str x9, [x3, #0]
add x0, x9, x20
add x3, x28, #66440
str x0, [x3, #0]
L9042:
add x0, x28, #66432
ldr x2, [x0, #0]
add x0, x2, x19
add x3, x28, #66432
str x0, [x3, #0]
mov x0, x2
L9044:
L9031:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000064
ret
.align 32
Mem__alloc_raw:
sub sp, sp, #0000064
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #24]
mov x9, x0
cmp x0, 0
b.gt L9048
mov x0, 0
b L9054
L9048:
add x0, x9, #15
asr x0, x0, #4
mov x1, 16
mul x0, x0, x1
add x0, x0, #16
mov x19, x0
cmp x0, 2048
b.le L9050
bl Mem__alloc_big
b L9054
L9050:
mov x1, 4
asr x0, x19, #4
add x0, x28, x0, lsl #3
add x0, x0, #67200
ldr x0, [x0, #0]
mov x9, x0
add x0, x28, x0, lsl #3
add x0, x0, #69264
ldr x0, [x0, #0]
str x0, [x29, #40]
cmp x0, 0
b.eq L9052
mov x8, x0
add x0, x28, x9, lsl #3
add x10, x0, #69264
ldr x0, [x8, #8]
str x0, [x10, #0]
mov x1, 0
str x1, [x8, #8]
add x3, x28, #66992
ldr x0, [x3, #0]
add x0, x0, #1
str x0, [x3, #0]
ldr x0, [x29, #40]
add x0, x0, #16
b L9054
L9052:
add x0, x28, x9, lsl #3
add x0, x0, #67008
ldr x0, [x0, #0]
bl Mem__alloc_new
L9054:
L9045:
ldr x19, [x29, #24]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000064
ret
.align 32
Mem__alloc_new:
sub sp, sp, #0000048
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
mov x19, x0
bl Mem__bump
mov x9, x0
cmp x0, 0
b.ne L9058
mov x0, 0
b L9060
L9058:
add x3, x28, #66992
ldr x0, [x3, #0]
add x0, x0, #1
str x0, [x3, #0]
str x19, [x9, #0]
mov x1, 0
str x1, [x9, #8]
add x0, x9, #16
L9060:
L9055:
ldr x19, [x29, #16]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000048
ret
.align 32
Mem__alloc_direct:
sub sp, sp, #0000080
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #24]
add x0, x0, #4095
asr x2, x0, #63
lsr x2, x2, #52
add x2, x0, x2
asr x2, x2, #12
mov x1, 4096
mul x0, x2, x1
mov x19, x0
mov x2, x0
mov x6, 0
mov x8, 222
mov x0, 0
mov x1, x2
mov x2, 3
mov x3, 34
mov x4, -1
mov x5, 0
svc 0
mov x9, x0
cmp x0, 0
b.ge L9072
mov x1, -4096
cmp x0, x1
b.le L9072
mov x0, 0
b L9077
L9072:
mov x10, x9
str x19, [x10, #0]
mov x1, 0
str x1, [x10, #8]
mov x19, 0
L9073:
add x0, x28, x19, lsl #3
add x0, x0, #66456
ldr x0, [x0, #0]
cmp x0, 0
b.eq L9075
add x19, x19, #1
b L9073
L9075:
add x0, x28, x19, lsl #3
add x10, x0, #66456
str x9, [x10, #0]
add x3, x28, #66968
ldr x0, [x3, #0]
add x0, x0, #1
str x0, [x3, #0]
add x3, x28, #66992
ldr x0, [x3, #0]
add x0, x0, #1
str x0, [x3, #0]
add x0, x9, #16
L9077:
L9061:
ldr x19, [x29, #24]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000080
ret
.align 32
Mem__free_direct:
sub sp, sp, #0000080
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #24]
str x20, [x29, #32]
str x21, [x29, #48]
mov x9, x0
mov x19, x1
mov x20, 0
add x16, x28, #66456
mov x21, x16
L9080:
cmp x20, 64
b.ge L9088
ldr x0, [x21, #0]
cmp x0, x9
b.eq L9082
add x20, x20, #1
mov x15, x21
add x16, x15, #8
mov x21, x16
b L9080
L9082:
add x0, x28, x20, lsl #3
add x0, x0, #66456
mov x1, 0
str x1, [x0, #0]
add x3, x28, #66968
ldr x0, [x3, #0]
sub x0, x0, #1
str x0, [x3, #0]
mov x2, x19
mov x8, 215
mov x0, x9
mov x1, x2
svc 0
mov x0, 1
b L9090
L9088:
mov x0, 0
L9090:
L9078:
ldr x19, [x29, #24]
ldr x20, [x29, #32]
ldr x21, [x29, #48]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000080
ret
.align 32
Mem__alloc_big:
sub sp, sp, #0000112
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #48]
str x21, [x29, #56]
mov x19, x0
mov x1, 262144
cmp x0, x1
b.lt L9101
add x0, x28, #66968
ldr x0, [x0, #0]
cmp x0, 64
b.ge L9101
mov x0, x19
bl Mem__alloc_direct
cmp x0, 0
b.ne L9118
L9101:
mov x9, 0
add x0, x28, #66448
ldr x8, [x0, #0]
L9102:
mov x0, x8
cmp x0, 0
b.eq L9114
mov x20, x0
ldr x0, [x0, #0]
mov x1, x19
cmp x0, x1
b.ge L9104
mov x9, x8
ldr x8, [x8, #8]
b L9102
L9104:
ldr x0, [x20, #0]
mov x1, x19
sub x0, x0, x1
cmp x0, 64
b.lt L9109
add x0, x8, x1
mov x21, x0
mov x10, x0
ldr x0, [x20, #0]
sub x0, x0, x1
str x0, [x10, #0]
add x10, x10, #8
ldr x0, [x20, #8]
str x0, [x10, #0]
str x19, [x20, #0]
cmp x9, 0
b.ne L9107
add x3, x28, #66448
str x21, [x3, #0]
L9112:
mov x1, 0
str x1, [x20, #8]
add x3, x28, #66992
ldr x0, [x3, #0]
add x0, x0, #1
str x0, [x3, #0]
add x0, x8, #16
b L9118
L9107:
str x21, [x9, #8]
b L9112
L9109:
cmp x9, 0
b.ne L9111
ldr x0, [x20, #8]
add x3, x28, #66448
str x0, [x3, #0]
b L9112
L9111:
ldr x0, [x20, #8]
str x0, [x9, #8]
b L9112
L9114:
mov x0, x19
bl Mem__bump
mov x9, x0
cmp x0, 0
b.ne L9116
mov x0, 0
b L9118
L9116:
add x3, x28, #66992
ldr x0, [x3, #0]
add x0, x0, #1
str x0, [x3, #0]
str x19, [x9, #0]
mov x1, 0
str x1, [x9, #8]
add x0, x9, #16
L9118:
L9093:
ldr x19, [x29, #16]
ldr x20, [x29, #48]
ldr x21, [x29, #56]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000112
ret
.align 32
Mem__free:
sub sp, sp, #0000064
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #32]
str x20, [x29, #48]
mov x9, x0
add x0, x28, #69456
ldr x0, [x0, #0]
cmp x0, 0
b.ne L9133
add x0, x28, #66984
ldr x0, [x0, #0]
cmp x0, 0
b.ne L9133
mov x0, x9
cmp x0, 0
b.eq L9133
sub x0, x0, #16
mov x8, x0
mov x19, x0
ldr x0, [x0, #0]
str x0, [x29, #40]
mov x1, 1
and x0, x0, #1
cmp x0, 0
b.ne L9133
ldr x0, [x29, #40]
cmp x0, 2048
b.gt L9133
mov x1, 4
asr x0, x0, #4
add x0, x28, x0, lsl #3
add x0, x0, #68232
ldr x0, [x0, #0]
mov x20, x0
cmp x0, 0
b.lt L9133
add x3, x28, #67000
ldr x0, [x3, #0]
add x0, x0, #1
str x0, [x3, #0]
add x0, x28, x20, lsl #3
add x0, x0, #69264
ldr x0, [x0, #0]
str x0, [x19, #8]
add x0, x28, x20, lsl #3
add x10, x0, #69264
mov x0, x8
str x0, [x10, #0]
b L9134
L9133:
mov x0, x9
bl Mem__free_general
L9134:
L9119:
ldr x19, [x29, #32]
ldr x20, [x29, #48]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000064
ret
.align 32
Mem__free_general:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
mov x19, x0
add x0, x28, #69456
ldr x0, [x0, #0]
cmp x0, 0
b.eq L9138
mov x0, x19
bl Mem__dbg_free
b L9139
L9138:
mov x0, x19
bl Mem__free_now
L9139:
L9135:
ldr x19, [x29, #16]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
Mem__free_now:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
mov x19, x0
add x0, x28, #66984
ldr x0, [x0, #0]
cmp x0, 0
b.ne L286
mov x0, x19
bl Mem__free_raw
b L284
L286:
L285:
L288:
add x10, x28, #66976
mov x11, 0
mov x2, 1
mov x1, x11
mov x0, x10
L290:
ldaxr x3, [x0]
cmp x3, x1
b.ne L291
stlxr w4, x2, [x0]
cmp x4, 0
b.ne L290
L291:
dmb ish
cmp x3, 0
b.eq L289
mov x0, 124
cmp x0, 93
b.eq L293
cmp x0, 94
b.ne L294
L293:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L294:
mov x8, x0
svc 0
b L288
L289:
mov x0, x19
bl Mem__free_raw
add x10, x28, #66976
mov x1, 0
mov x0, x10
L295:
ldaxr x3, [x0]
stlxr w4, x1, [x0]
cmp x4, 0
b.ne L295
L296:
dmb ish
mov x0, x3
L284:
ldr x19, [x29, #16]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
Mem__free_raw:
sub sp, sp, #0000080
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #24]
str x20, [x29, #32]
str x21, [x29, #40]
cmp x0, 0
b.eq L9156
sub x0, x0, #16
mov x19, x0
mov x20, x0
ldr x0, [x0, #0]
mov x21, x0
mov x1, 1
and x0, x0, #1
cmp x0, 0
b.eq L9145
mov x0, x19
bl Mem__free_piece
b L9156
L9145:
add x3, x28, #67000
ldr x0, [x3, #0]
add x0, x0, #1
str x0, [x3, #0]
mov x1, 262144
cmp x21, x1
b.lt L9152
add x0, x28, #66968
ldr x0, [x0, #0]
cmp x0, 0
b.le L9152
mov x1, x21
mov x0, x19
bl Mem__free_direct
cmp x0, 0
b.ne L9156
L9152:
mov x0, x21
cmp x0, 2048
b.gt L9155
mov x1, 4
asr x0, x0, #4
add x0, x28, x0, lsl #3
add x0, x0, #68232
ldr x0, [x0, #0]
mov x9, x0
cmp x0, 0
b.lt L9155
add x0, x28, x9, lsl #3
add x0, x0, #69264
ldr x0, [x0, #0]
str x0, [x20, #8]
add x0, x28, x9, lsl #3
add x10, x0, #69264
mov x0, x19
str x0, [x10, #0]
b L9156
L9155:
mov x0, x19
bl Mem__free_big
L9156:
L9140:
ldr x19, [x29, #24]
ldr x20, [x29, #32]
ldr x21, [x29, #40]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000080
ret
Mem__free_big:
mov x9, x0
mov x8, x0
mov x4, 0
add x0, x28, #66448
ldr x2, [x0, #0]
L9159:
mov x0, x2
cmp x0, 0
b.eq L9165
cmp x0, x9
b.ge L9165
mov x4, x0
ldr x2, [x0, #8]
b L9159
L9165:
str x2, [x8, #8]
cmp x2, 0
b.eq L9171
mov x10, x9
ldr x0, [x8, #0]
add x0, x10, x0
cmp x0, x2
b.ne L9171
mov x10, x8
ldr x11, [x8, #0]
ldr x0, [x2, #0]
add x0, x11, x0
str x0, [x10, #0]
ldr x0, [x2, #8]
str x0, [x8, #8]
L9171:
cmp x4, 0
b.ne L9173
mov x0, x9
add x3, x28, #66448
str x0, [x3, #0]
b L9176
L9173:
mov x2, x4
mov x10, x4
ldr x0, [x4, #0]
add x0, x10, x0
cmp x0, x9
b.ne L9175
ldr x11, [x2, #0]
ldr x0, [x8, #0]
add x0, x11, x0
str x0, [x10, #0]
ldr x0, [x8, #8]
str x0, [x2, #8]
b L9176
L9175:
mov x0, x9
str x0, [x2, #8]
L9176:
L9157:
ret
Mem__free_piece:
mov x9, x0
mov x8, x0
ldr x0, [x0, #0]
and x0, x0, #2
cmp x0, 0
b.ne L9183
mov x10, x8
ldr x0, [x8, #0]
orr x0, x0, #2
str x0, [x10, #0]
ldr x0, [x8, #0]
sub x1, x0, #3
ldr x0, [x8, #8]
mov x8, x0
sub x0, x0, #16
mov x4, x0
ldr x0, [x0, #8]
and x3, x0, #4294967295
ldr x0, [x4, #8]
asr x18, x0, #32
add x10, x9, x1
add x0, x8, x3
cmp x10, x0
b.ne L9182
sub x11, x9, x8
mov x1, 4294967296
mul x0, x18, x1
add x0, x11, x0
str x0, [x4, #8]
b L9183
L9182:
str x18, [x9, #16]
sub x0, x9, x8
add x0, x0, #1
mov x1, 4294967296
mul x0, x0, x1
add x0, x3, x0
str x0, [x4, #8]
L9183:
L9177:
ret
.align 32
Mem__dbg_where:
sub sp, sp, #0000080
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x29, [x29, #16]
adr x0, j2k_fntab
str x0, [x29, #24]
mov x0, 0
str x0, [x29, #32]
L9186:
ldr x0, [x29, #16]
mov x1, 4096
cmp x0, x1
b.le L9214
ldr x0, [x29, #32]
cmp x0, 12
b.ge L9214
ldr x0, [x29, #16]
ldr x0, [x0, #8]
str x0, [x29, #40]
mov x0, -1
str x0, [x29, #48]
mov x0, 0
str x0, [x29, #56]
L9192:
ldr x0, [x29, #56]
mov x1, 2
mul x0, x0, x1
lsl x0, x0, #3
ldr x1, [x29, #24]
add x0, x0, x1
ldr x0, [x0, #0]
cmp x0, 0
b.eq L9196
ldr x0, [x29, #56]
mov x1, 2
mul x0, x0, x1
lsl x0, x0, #3
ldr x1, [x29, #24]
add x0, x0, x1
ldr x0, [x0, #0]
ldr x1, [x29, #40]
cmp x0, x1
b.ge L9195
ldr x0, [x29, #56]
str x0, [x29, #48]
L9195:
ldr x0, [x29, #56]
add x0, x0, #1
str x0, [x29, #56]
b L9192
L9196:
ldr x0, [x29, #48]
cmp x0, 0
b.lt L9197
ldr x0, [x29, #48]
mov x1, 2
mul x0, x0, x1
add x0, x0, #1
lsl x0, x0, #3
ldr x1, [x29, #24]
add x0, x0, x1
ldr x0, [x0, #0]
str x0, [x29, #64]
ldrb x0, [x0, #0]
cmp x0, 95
b.ne L9201
ldr x0, [x29, #64]
ldrb x0, [x0, #1]
cmp x0, 95
b.ne L9201
mov x0, 1
L9202:
str x0, [x29, #72]
ldr x0, [x29, #64]
ldrb x0, [x0, #0]
cmp x0, 77
b.ne L9211
ldr x0, [x29, #64]
ldrb x0, [x0, #1]
cmp x0, 101
b.ne L9211
ldr x0, [x29, #64]
ldrb x0, [x0, #2]
cmp x0, 109
b.ne L9211
ldr x0, [x29, #64]
ldrb x0, [x0, #3]
cmp x0, 95
b.ne L9211
ldr x0, [x29, #64]
ldrb x0, [x0, #4]
cmp x0, 95
b.ne L9211
mov x0, 1
str x0, [x29, #72]
L9211:
ldr x0, [x29, #72]
cmp x0, 0
b.eq L9212
ldr x0, [x29, #16]
ldr x0, [x0, #0]
str x0, [x29, #16]
ldr x0, [x29, #32]
add x0, x0, #1
str x0, [x29, #32]
b L9186
L9197:
add x0, x28, #70056
b L9216
L9201:
mov x0, 0
b L9202
L9212:
ldr x0, [x29, #64]
b L9216
L9214:
add x0, x28, #70064
L9216:
L9184:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000080
ret
Mem__dbg_find:
mov x9, x0
add x0, x28, #69464
ldr x0, [x0, #0]
cmp x0, 0
b.ne L9220
mov x0, -1
b L9229
L9220:
asr x0, x9, #4
and x8, x0, #32767
mov x4, 0
L9221:
mov x1, 32768
cmp x4, x1
b.ge L9227
add x0, x28, #69464
ldr x2, [x0, #0]
mov x1, 3
mul x0, x8, x1
add x0, x2, x0, lsl #3
ldr x0, [x0, #0]
cmp x0, x9
b.eq L9223
cmp x0, 0
b.eq L9225
add x0, x8, #1
and x8, x0, #32767
add x4, x4, #1
b L9221
L9223:
mov x0, x8
b L9229
L9225:
mov x0, -1
b L9229
L9227:
mov x0, -1
L9229:
L9217:
ret
Mem__dbg_free_place:
mov x9, x0
add x0, x28, #69464
ldr x0, [x0, #0]
cmp x0, 0
b.ne L9233
mov x0, -1
b L9244
L9233:
asr x0, x9, #4
and x9, x0, #32767
mov x8, 0
L9234:
mov x1, 32768
cmp x8, x1
b.ge L9242
add x0, x28, #69464
ldr x2, [x0, #0]
mov x1, 3
mul x0, x9, x1
add x0, x2, x0, lsl #3
ldr x0, [x0, #0]
cmp x0, 0
b.eq L9240
mov x1, -1
cmp x0, x1
b.eq L9240
add x0, x9, #1
and x9, x0, #32767
add x8, x8, #1
b L9234
L9240:
mov x0, x9
b L9244
L9242:
mov x0, -1
L9244:
L9230:
ret
.align 32
Mem__dbg_guard_alloc:
sub sp, sp, #0000096
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #24]
str x20, [x29, #32]
add x0, x0, #15
asr x0, x0, #4
mov x1, 16
mul x0, x0, x1
mov x19, x0
add x0, x0, #16
add x0, x0, #4095
asr x0, x0, #12
mov x20, x0
add x0, x0, #1
mov x1, 4096
mul x2, x0, x1
mov x6, 0
mov x8, 222
mov x0, 0
mov x1, x2
mov x2, 3
mov x3, 34
mov x4, -1
mov x5, 0
svc 0
str x0, [x29, #40]
cmp x0, 0
b.ge L9256
mov x1, -4096
cmp x0, x1
b.le L9256
mov x0, 0
b L9262
L9256:
ldr x10, [x29, #40]
mov x1, 4096
mul x0, x20, x1
str x0, [x29, #72]
add x0, x10, x0
str x0, [x29, #64]
mov x3, 0
mov x8, 226
mov x1, 4096
mov x2, 0
svc 0
ldr x0, [x29, #64]
sub x0, x0, x19
mov x2, x0
sub x10, x0, #16
add x0, x19, #16
str x0, [x10, #0]
mov x1, 0
str x1, [x10, #8]
mov x0, x2
L9262:
L9245:
ldr x19, [x29, #24]
ldr x20, [x29, #32]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000096
ret
.align 32
Mem__dbg_alloc:
sub sp, sp, #0000096
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
str x21, [x29, #32]
str x22, [x29, #48]
mov x19, x0
mov x20, 0
mov x21, 0
cmp x19, 0
b.le L9273
add x0, x28, #70008
ldr x0, [x0, #0]
mov x1, 12000
cmp x0, x1
b.ge L9273
add x0, x28, #66984
ldr x0, [x0, #0]
cmp x0, 0
b.ne L9273
add x0, x28, #69480
ldr x0, [x0, #0]
cmp x0, 0
b.ne L9273
mov x0, x19
bl Mem__dbg_guard_alloc
mov x20, x0
cmp x0, 0
b.eq L9273
add x3, x28, #70008
ldr x0, [x3, #0]
add x0, x0, #1
str x0, [x3, #0]
add x3, x28, #66992
ldr x0, [x3, #0]
add x0, x0, #1
mov x1, x0
str x0, [x3, #0]
mov x21, 1
L9273:
cmp x20, 0
b.ne L9275
mov x0, x19
bl Mem__alloc_locked
mov x20, x0
L9275:
mov x0, x20
cmp x0, 0
b.eq L9279
bl Mem__dbg_where
mov x19, x0
sub x22, x20, #16
mov x0, x20
bl Mem__dbg_free_place
mov x9, x0
cmp x0, 0
b.ge L9278
add x3, x28, #69480
mov x1, 1
str x1, [x3, #0]
L9279:
mov x0, x20
b L9281
L9278:
add x3, x28, #69472
ldr x0, [x3, #0]
add x0, x0, #1
str x0, [x3, #0]
add x0, x28, #69464
ldr x8, [x0, #0]
mov x1, 3
mul x0, x9, x1
mov x9, x0
lsl x0, x0, #3
add x10, x0, x8
str x20, [x10, #0]
add x0, x28, #69464
ldr x8, [x0, #0]
add x0, x9, #1
lsl x0, x0, #3
add x10, x0, x8
ldr x0, [x22, #0]
mov x8, x0
and x0, x0, #-4
sub x11, x0, #16
mov x1, 1099511627776
mul x0, x21, x1
add x0, x11, x0
str x0, [x10, #0]
add x0, x28, #69464
ldr x8, [x0, #0]
add x0, x9, #2
lsl x0, x0, #3
add x10, x0, x8
str x19, [x10, #0]
b L9279
L9281:
L9263:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x21, [x29, #32]
ldr x22, [x29, #48]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000096
ret
.align 32
Mem__alloc_locked:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
mov x19, x0
add x0, x28, #66984
ldr x0, [x0, #0]
cmp x0, 0
b.ne L497
mov x0, x19
bl Mem__alloc_raw
b L495
L497:
L496:
L499:
add x10, x28, #66976
mov x11, 0
mov x2, 1
mov x1, x11
mov x0, x10
L501:
ldaxr x3, [x0]
cmp x3, x1
b.ne L502
stlxr w4, x2, [x0]
cmp x4, 0
b.ne L501
L502:
dmb ish
cmp x3, 0
b.eq L500
mov x0, 124
cmp x0, 93
b.eq L504
cmp x0, 94
b.ne L505
L504:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L505:
mov x8, x0
svc 0
b L499
L500:
mov x0, x19
bl Mem__alloc_raw
mov x9, x0
add x10, x28, #66976
mov x1, 0
mov x0, x10
L506:
ldaxr x3, [x0]
stlxr w4, x1, [x0]
cmp x4, 0
b.ne L506
L507:
dmb ish
mov x0, x9
b L495
bl j2k_noret
L495:
ldr x19, [x29, #16]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
Mem__dbg_intact:
sub sp, sp, #0000080
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
mov x8, x0
sub x0, x0, #16
ldr x0, [x0, #0]
and x0, x0, #-4
sub x0, x0, #16
asr x2, x0, #63
lsr x2, x2, #61
add x2, x0, x2
asr x2, x2, #3
mov x9, x2
str x8, [x29, #40]
mov x4, 0
mov x16, -2459565876494606883
mov x3, x16
mov x18, x8
L9284:
cmp x4, x9
b.ge L9288
ldr x0, [x18, #0]
cmp x0, x3
b.ne L9286
add x4, x4, #1
add x18, x18, #8
b L9284
L9286:
mov x0, 0
b L9290
L9288:
mov x0, 1
L9290:
L9282:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000080
ret
.align 32
Mem__dbg_free:
sub sp, sp, #0000208
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
str x21, [x29, #72]
str x22, [x29, #32]
str x23, [x29, #88]
str x24, [x29, #120]
mov x19, x0
cmp x0, 0
b.eq L9319
bl Mem__dbg_find
mov x20, x0
cmp x0, 0
b.lt L9306
add x0, x28, #69464
ldr x21, [x0, #0]
mov x1, 3
mul x0, x20, x1
add x0, x0, #1
add x0, x21, x0, lsl #3
ldr x0, [x0, #0]
mov x22, x0
mov x1, -1
cmp x0, x1
b.ne L9300
add x0, x28, #70072
bl __panic
L9300:
mov x0, x22
mov x1, 1099511627776
cmp x0, x1
b.lt L9306
mov x1, 1099511627776
sub x0, x0, x1
mov x8, x0
add x0, x0, #16
add x0, x0, #4095
asr x2, x0, #12
add x0, x28, #69464
ldr x21, [x0, #0]
mov x1, 3
mul x0, x20, x1
add x0, x0, #1
add x0, x21, x0, lsl #3
mov x1, -1
str x1, [x0, #0]
add x3, x28, #69472
ldr x0, [x3, #0]
sub x0, x0, #1
str x0, [x3, #0]
add x3, x28, #67000
ldr x0, [x3, #0]
add x0, x0, #1
str x0, [x3, #0]
mov x21, 226
add x10, x19, x8
mov x1, 4096
mul x0, x2, x1
mov x9, x0
sub x0, x10, x0
mov x3, 0
mov x8, 226
mov x1, x9
mov x2, 0
svc 0
b L9319
L9306:
sub x0, x19, #16
mov x20, x0
ldr x0, [x0, #0]
mov x1, 1
and x0, x0, #1
cmp x0, 0
b.eq L9308
sub x0, x19, #16
bl Mem__free_piece
b L9319
L9308:
mov x0, x19
bl Mem__dbg_find
str x0, [x29, #64]
cmp x0, 0
b.lt L9310
add x0, x28, #69464
ldr x21, [x0, #0]
ldr x0, [x29, #64]
mov x1, 3
mul x0, x0, x1
add x0, x21, x0, lsl #3
mov x1, -1
str x1, [x0, #0]
add x3, x28, #69472
ldr x0, [x3, #0]
sub x0, x0, #1
str x0, [x3, #0]
L9312:
ldr x0, [x20, #0]
and x0, x0, #-4
sub x0, x0, #16
asr x2, x0, #63
lsr x2, x2, #61
add x2, x0, x2
asr x2, x2, #3
mov x21, x2
mov x22, x19
mov x23, 0
mov x16, -2459565876494606883
mov x24, x16
mov x15, x22
L9313:
cmp x23, x21
b.ge L9315
str x24, [x22, #0]
add x23, x23, #1
mov x16, x22
add x22, x16, #8
b L9313
L9310:
add x0, x28, #69480
ldr x0, [x0, #0]
cmp x0, 0
b.ne L9312
add x0, x28, #70120
bl __panic
L9315:
add x0, x28, #70000
ldr x0, [x0, #0]
and x20, x0, #63
add x3, x28, #70000
ldr x0, [x3, #0]
add x0, x0, #1
str x0, [x3, #0]
add x0, x28, x20, lsl #3
add x0, x0, #69488
ldr x21, [x0, #0]
add x0, x28, x20, lsl #3
add x10, x0, #69488
str x19, [x10, #0]
add x3, x28, #67000
ldr x0, [x3, #0]
add x0, x0, #1
mov x1, x0
str x0, [x3, #0]
mov x0, x21
cmp x0, 0
b.eq L9319
bl Mem__dbg_intact
cmp x0, 0
b.ne L9318
add x0, x28, #70200
bl __panic
L9318:
add x3, x28, #67000
ldr x0, [x3, #0]
sub x0, x0, #1
mov x1, x0
str x0, [x3, #0]
mov x0, x21
bl Mem__free_now
L9319:
L9294:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x21, [x29, #72]
ldr x22, [x29, #32]
ldr x23, [x29, #88]
ldr x24, [x29, #120]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000208
ret
.align 32
Mem__copy:
sub sp, sp, #0000112
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #80]
str x20, [x29, #88]
str x21, [x29, #104]
mov x9, x0
mov x8, x2
mov x4, x0
mov x3, x1
mov x18, 0
cmp x2, 8
b.lt L9329
str x1, [x29, #72]
mov x0, x2
asr x2, x2, #63
lsr x2, x2, #61
add x2, x0, x2
asr x2, x2, #3
mov x19, x2
mov x20, 0
mov x21, x1
mov x16, x9
L9326:
cmp x20, x19
b.ge L9328
mov x10, x9
ldr x0, [x21, #0]
str x0, [x10, #0]
add x20, x20, #1
add x21, x21, #8
mov x15, x9
add x16, x15, #8
mov x9, x16
b L9326
L9328:
mov x1, 8
mul x18, x19, x1
L9329:
mov x0, x18
cmp x0, x8
b.ge L9331
add x10, x0, x4
add x0, x18, x3
ldrb x0, [x0, #0]
strb x0, [x10, #0]
add x18, x18, #1
b L9329
L9331:
L9323:
ldr x19, [x29, #80]
ldr x20, [x29, #88]
ldr x21, [x29, #104]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000112
ret
.align 32
__Arr__nullerr:
sub sp, sp, #0000016
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
add x0, x28, #70240
bl __panic
L9334:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000016
ret
.align 32
__Arr__make:
sub sp, sp, #0000096
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #32]
mov x19, x0
mov x20, x1
cmp x1, 4
b.ge L9340
mov x20, 4
L9340:
mul x0, x20, x19
mov x1, x0
add x0, x0, #32
bl Mem__alloc
str x0, [x29, #40]
add x1, x29, #48
ldr x2, [x27, #784]
str x2, [x29, #48]
add x2, x29, #40
str x2, [x29, #56]
adr x2, Mem__free
str x2, [x29, #64]
mov x2, 0
str x2, [x29, #72]
str x1, [x27, #784]
ldr x0, [x29, #40]
cmp x0, 0
b.ne L9342
add x0, x28, #70272
bl __panic
L9342:
ldr x0, [x29, #40]
mov x1, 0
str x1, [x0, #0]
ldr x0, [x29, #40]
str x20, [x0, #8]
ldr x0, [x29, #40]
add x10, x0, #16
ldr x0, [x29, #40]
add x0, x0, #32
str x0, [x10, #0]
ldr x0, [x29, #40]
add x10, x0, #24
mov x3, x10
str x19, [x10, #0]
ldr x19, [x29, #40]
mov x1, 0
str x1, [x29, #40]
ldr x0, [x29, #40]
bl Mem__free
ldr x1, [x29, #48]
str x1, [x27, #784]
mov x0, x19
L9337:
ldr x19, [x29, #16]
ldr x20, [x29, #32]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000096
ret
.align 32
__Arr__grow:
sub sp, sp, #0000064
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #32]
str x21, [x29, #40]
mov x19, x0
mov x9, x1
mov x10, x1
ldr x1, [x0, #8]
mov x0, x10
cmp x10, x1
b.le L9355
ldr x0, [x19, #8]
mov x1, 2
mul x0, x0, x1
mov x20, x0
mov x1, x9
cmp x0, x1
b.ge L9350
mov x20, x1
L9350:
mov x10, x20
ldr x0, [x19, #24]
mul x0, x10, x0
bl Mem__alloc
mov x21, x0
cmp x0, 0
b.ne L9352
add x0, x28, #70288
bl __panic
L9352:
mov x9, x21
ldr x1, [x19, #16]
ldr x10, [x19, #0]
ldr x0, [x19, #24]
mul x2, x10, x0
mov x0, x9
bl Mem__copy
ldr x10, [x19, #16]
add x0, x19, #32
mov x1, x0
cmp x10, x0
b.eq L9354
ldr x0, [x19, #16]
bl Mem__free
L9354:
str x21, [x19, #16]
mov x0, x20
str x0, [x19, #8]
L9355:
L9345:
ldr x19, [x29, #16]
ldr x20, [x29, #32]
ldr x21, [x29, #40]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000064
ret
.align 32
__Arr__slot:
sub sp, sp, #0000064
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #24]
mov x19, x0
cmp x0, 0
b.ne L9359
add x0, x28, #70304
bl __panic
L9359:
mov x9, x19
ldr x0, [x19, #0]
add x1, x0, #1
mov x0, x9
bl __Arr__grow
ldr x10, [x19, #16]
ldr x11, [x19, #0]
ldr x0, [x19, #24]
mul x0, x11, x0
add x9, x10, x0
mov x10, x19
ldr x0, [x19, #0]
add x0, x0, #1
str x0, [x10, #0]
mov x0, x9
L9356:
ldr x19, [x29, #24]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000064
ret
.align 32
__Arr__free:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
mov x19, x0
mov x9, x0
cmp x0, 0
b.eq L9368
ldr x10, [x0, #16]
add x0, x9, #32
mov x1, x0
cmp x10, x0
b.eq L9367
ldr x0, [x9, #16]
bl Mem__free
L9367:
mov x0, x19
bl Mem__free
L9368:
L9362:
ldr x19, [x29, #16]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
__Str__make:
sub sp, sp, #0000096
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #80]
mov x19, 1
add x1, x0, #1
mov x0, 1
bl __Arr__make
str x0, [x29, #24]
add x1, x29, #32
ldr x2, [x27, #784]
str x2, [x29, #32]
add x2, x29, #24
str x2, [x29, #40]
adr x2, Mem__free
str x2, [x29, #48]
mov x2, 0
str x2, [x29, #56]
str x1, [x27, #784]
ldr x0, [x29, #24]
ldr x0, [x0, #16]
mov x3, x0
mov x1, 0
strb x1, [x0, #0]
ldr x19, [x29, #24]
mov x1, 0
str x1, [x29, #24]
ldr x0, [x29, #24]
bl Mem__free
ldr x1, [x29, #32]
str x1, [x27, #784]
mov x0, x19
L9369:
ldr x19, [x29, #80]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000096
ret
__Str__textlen:
mov x9, x0
mov x8, 0
L9375:
add x0, x8, x9
ldrb x0, [x0, #0]
cmp x0, 0
b.eq L9377
add x8, x8, #1
b L9375
L9377:
mov x0, x8
L9373:
ret
.align 32
__Str__check:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
cmp x0, 0
b.ne L9383
add x0, x28, #70352
bl __panic
L9383:
L9380:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
__Str__ptr:
sub sp, sp, #0000080
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
str x21, [x29, #32]
mov x19, x0
mov x20, x1
mov x21, x2
cmp x1, 1
b.ne L9387
cmp x0, 0
b.ne L9395
add x0, x28, #70352
bl __panic
L9387:
cmp x20, 2
b.ne L9389
mov x1, 8
mul x0, x21, x1
mov x9, x0
add x0, x28, x0
add x10, x0, #70336
strb x19, [x10, #0]
add x0, x9, #1
add x0, x28, x0
add x0, x0, #70336
mov x1, 0
strb x1, [x0, #0]
add x10, x28, #70336
add x0, x10, x9
b L9391
L9389:
mov x0, x19
b L9391
L9395:
ldr x0, [x19, #16]
L9391:
L9384:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x21, [x29, #32]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000080
ret
.align 32
__Str__len:
sub sp, sp, #0000064
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
mov x19, x0
mov x20, x1
cmp x1, 1
b.ne L9399
cmp x0, 0
b.ne L9407
add x0, x28, #70352
bl __panic
L9399:
cmp x20, 2
b.ne L9401
mov x0, 1
b L9403
L9401:
mov x0, x19
bl __Str__textlen
b L9403
L9407:
ldr x0, [x19, #0]
L9403:
L9396:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000064
ret
.align 32
__Str__push_int:
sub sp, sp, #0000192
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x0, [x29, #16]
str x1, [x29, #24]
str x2, [x29, #32]
mov x0, 0
str x0, [x29, #64]
mov x0, 0
str x0, [x29, #72]
ldr x0, [x29, #32]
cmp x0, 0
b.ne L9415
ldr x0, [x29, #24]
cmp x0, 0
b.ge L9415
mov x0, 1
str x0, [x29, #72]
L9415:
ldr x0, [x29, #24]
str x0, [x29, #80]
ldr x0, [x29, #72]
cmp x0, 1
b.ne L9417
mov x0, 0
ldr x1, [x29, #80]
sub x0, x0, x1
str x0, [x29, #80]
L9417:
ldr x0, [x29, #80]
cmp x0, 0
b.ne L9419
mov x0, 48
strb x0, [x29, #40]
mov x0, 1
str x0, [x29, #64]
L9419:
ldr x0, [x29, #80]
cmp x0, 0
b.ls L9421
ldr x0, [x29, #64]
add x0, x29, x0
add x0, x0, #40
str x0, [x29, #176]
ldr x0, [x29, #80]
mov x1, 10
udiv x2, x0, x1
mul x2, x2, x1
sub x0, x0, x2
add x0, x0, #48
ldr x3, [x29, #176]
strb x0, [x3, #0]
ldr x0, [x29, #64]
add x0, x0, #1
str x0, [x29, #64]
ldr x0, [x29, #80]
mov x1, 10
udiv x0, x0, x1
str x0, [x29, #80]
b L9419
L9421:
ldr x0, [x29, #72]
cmp x0, 1
b.ne L9423
ldr x0, [x29, #16]
str x0, [x29, #176]
mov x1, 45
ldr x0, [x29, #176]
bl __Str__push
L9423:
ldr x0, [x29, #64]
cmp x0, 0
b.le L9425
ldr x0, [x29, #64]
sub x0, x0, #1
str x0, [x29, #64]
ldr x0, [x29, #16]
str x0, [x29, #176]
ldr x0, [x29, #64]
add x0, x29, x0
ldrb x1, [x0, #40]
ldr x0, [x29, #176]
str x0, [x29, #96]
str x1, [x29, #104]
cmp x0, 0
b.eq L9430
ldr x0, [x29, #96]
str x0, [x29, #112]
str x0, [x29, #144]
ldr x0, [x0, #0]
add x1, x0, #2
ldr x0, [x29, #144]
bl __Arr__grow
ldr x0, [x29, #112]
ldr x1, [x0, #16]
ldr x0, [x29, #112]
ldr x0, [x0, #0]
add x10, x0, x1
ldr x0, [x29, #104]
strb x0, [x10, #0]
ldr x0, [x29, #112]
mov x10, x0
ldr x0, [x0, #0]
add x0, x0, #1
str x0, [x10, #0]
ldr x0, [x10, #0]
add x0, x0, x1
mov x1, 0
strb x1, [x0, #0]
b L9423
L9430:
add x0, x28, #70352
bl __panic
L9425:
L9408:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000192
ret
.align 32
__Str__from_int:
sub sp, sp, #0000112
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
str x21, [x29, #96]
mov x19, x0
mov x20, x1
mov x0, 24
bl __Str__make
str x0, [x29, #32]
add x1, x29, #40
ldr x2, [x27, #784]
str x2, [x29, #40]
add x2, x29, #32
str x2, [x29, #48]
adr x2, Mem__free
str x2, [x29, #56]
mov x2, 0
str x2, [x29, #64]
str x1, [x27, #784]
ldr x21, [x29, #32]
str x19, [x29, #80]
mov x2, x20
ldr x1, [x29, #80]
mov x0, x21
bl __Str__push_int
ldr x21, [x29, #32]
mov x1, 0
str x1, [x29, #32]
ldr x0, [x29, #32]
bl Mem__free
ldr x1, [x29, #40]
str x1, [x27, #784]
mov x0, x21
L9433:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x21, [x29, #96]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000112
ret
.align 32
__Str__from:
sub sp, sp, #0000112
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
str x21, [x29, #96]
mov x19, x0
bl __Str__textlen
mov x20, x0
bl __Str__make
str x0, [x29, #32]
add x1, x29, #40
ldr x2, [x27, #784]
str x2, [x29, #40]
add x2, x29, #32
str x2, [x29, #48]
adr x2, Mem__free
str x2, [x29, #56]
mov x2, 0
str x2, [x29, #64]
str x1, [x27, #784]
ldr x0, [x29, #32]
ldr x21, [x0, #16]
mov x2, x20
mov x1, x19
mov x0, x21
bl Mem__copy
ldr x0, [x29, #32]
ldr x1, [x0, #16]
add x0, x20, x1
mov x1, 0
strb x1, [x0, #0]
ldr x10, [x29, #32]
mov x3, x10
str x20, [x10, #0]
ldr x21, [x29, #32]
mov x1, 0
str x1, [x29, #32]
ldr x0, [x29, #32]
bl Mem__free
ldr x1, [x29, #40]
str x1, [x27, #784]
mov x0, x21
L9437:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x21, [x29, #96]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000112
ret
.align 32
__Str__clone:
sub sp, sp, #0000048
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
add x2, x28, #70376
mov x3, 0
mov x1, 1
bl __Str__cat
L9441:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000048
ret
.align 32
__Str__cat:
sub sp, sp, #0000144
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #56]
str x20, [x29, #104]
str x21, [x29, #32]
str x22, [x29, #40]
str x23, [x29, #128]
str x24, [x29, #112]
str x25, [x29, #48]
str x0, [x29, #16]
str x1, [x29, #24]
mov x21, x2
mov x22, x3
mov x23, x0
mov x24, x1
bl __Str__len
mov x25, x0
mov x23, x21
mov x24, x22
mov x1, x22
mov x0, x23
bl __Str__len
mov x19, x0
mov x1, x19
add x0, x25, x1
bl __Str__make
str x0, [x29, #64]
add x1, x29, #72
ldr x2, [x27, #784]
str x2, [x29, #72]
add x2, x29, #64
str x2, [x29, #80]
adr x2, Mem__free
str x2, [x29, #88]
mov x2, 0
str x2, [x29, #96]
str x1, [x27, #784]
ldr x0, [x29, #64]
ldr x0, [x0, #16]
mov x20, x0
mov x23, x0
ldr x24, [x29, #16]
ldr x1, [x29, #24]
mov x2, 0
mov x0, x24
bl __Str__ptr
mov x1, x0
mov x2, x25
mov x0, x23
bl Mem__copy
add x23, x20, x25
mov x24, x21
mov x1, x22
mov x2, 1
mov x0, x24
bl __Str__ptr
mov x24, x0
mov x2, x19
mov x1, x24
mov x0, x23
bl Mem__copy
add x0, x25, x19
add x0, x0, x20
mov x1, 0
strb x1, [x0, #0]
ldr x10, [x29, #64]
add x0, x25, x19
mov x3, x10
str x0, [x10, #0]
ldr x23, [x29, #64]
mov x1, 0
str x1, [x29, #64]
ldr x0, [x29, #64]
bl Mem__free
ldr x1, [x29, #72]
str x1, [x27, #784]
mov x0, x23
L9445:
ldr x19, [x29, #56]
ldr x20, [x29, #104]
ldr x21, [x29, #32]
ldr x22, [x29, #40]
ldr x23, [x29, #128]
ldr x24, [x29, #112]
ldr x25, [x29, #48]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000144
ret
.align 32
__Str__append:
sub sp, sp, #0000128
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
str x21, [x29, #32]
str x22, [x29, #40]
str x23, [x29, #112]
str x24, [x29, #96]
str x25, [x29, #56]
mov x19, x0
mov x20, x1
mov x21, x2
cmp x0, 0
b.ne L9462
add x0, x28, #70352
bl __panic
L9451:
mov x1, x19
cmp x20, x1
b.ne L9456
mov x0, x19
bl __Str__clone
mov x22, x0
mov x23, x19
mov x24, x22
mov x2, 1
mov x1, x22
mov x0, x23
bl __Str__append
mov x0, x22
bl __Arr__free
mov x0, x19
b L9458
L9456:
mov x22, x19
mov x23, x20
mov x24, x21
mov x1, x21
mov x0, x23
bl __Str__len
mov x25, x0
mov x23, x20
mov x1, x21
mov x2, 1
mov x0, x23
bl __Str__ptr
str x0, [x29, #64]
mov x23, x22
ldr x0, [x22, #0]
add x0, x0, x25
add x0, x0, #1
mov x24, x0
mov x1, x0
mov x0, x23
bl __Arr__grow
ldr x10, [x22, #16]
ldr x0, [x22, #0]
add x23, x10, x0
ldr x24, [x29, #64]
mov x2, x25
mov x1, x24
mov x0, x23
bl Mem__copy
mov x1, x25
ldr x0, [x22, #0]
add x0, x0, x1
str x0, [x22, #0]
ldr x1, [x22, #16]
ldr x0, [x22, #0]
add x0, x0, x1
mov x1, 0
strb x1, [x0, #0]
mov x0, x19
b L9458
L9462:
cmp x21, 1
b.ne L9456
b L9451
L9458:
L9449:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x21, [x29, #32]
ldr x22, [x29, #40]
ldr x23, [x29, #112]
ldr x24, [x29, #96]
ldr x25, [x29, #56]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000128
ret
.align 32
__Str__push:
sub sp, sp, #0000096
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
mov x19, x0
mov x20, x1
cmp x0, 0
b.ne L9469
add x0, x28, #70352
bl __panic
L9469:
str x19, [x29, #80]
ldr x0, [x19, #0]
add x1, x0, #2
ldr x0, [x29, #80]
bl __Arr__grow
ldr x1, [x19, #16]
ldr x0, [x19, #0]
add x10, x0, x1
strb x20, [x10, #0]
mov x10, x19
ldr x0, [x19, #0]
add x0, x0, #1
str x0, [x10, #0]
ldr x0, [x10, #0]
add x10, x0, x1
mov x0, 0
mov x1, 0
strb x1, [x10, #0]
L9463:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000096
ret
.align 32
__Str__c:
sub sp, sp, #0000048
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
mov x2, 0
mov x1, 1
bl __Str__ptr
L9470:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000048
ret
__Str__isspace:
cmp x0, 32
b.eq L9480
cmp x0, 9
b.eq L9480
cmp x0, 10
b.eq L9480
cmp x0, 13
b.eq L9480
mov x0, 0
b L9483
L9480:
mov x0, 1
L9483:
L9474:
ret
.align 32
__Str__to_int:
sub sp, sp, #0000112
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #96]
str x21, [x29, #24]
str x22, [x29, #40]
str x23, [x29, #48]
str x24, [x29, #56]
mov x19, x0
mov x20, x0
mov x2, 0
mov x1, 1
bl __Str__ptr
mov x21, x0
mov x0, x19
mov x20, x0
mov x1, 1
bl __Str__len
mov x19, x0
mov x22, 0
L9486:
mov x0, x22
cmp x0, x19
b.ge L9492
add x0, x0, x21
ldrb x0, [x0, #0]
cmp x0, 32
b.eq L9491
cmp x0, 9
b.eq L9491
cmp x0, 10
b.eq L9491
cmp x0, 13
b.ne L9492
L9491:
add x22, x22, #1
b L9486
L9492:
mov x23, 0
mov x0, x22
cmp x0, x19
b.ge L9504
mov x1, x21
add x0, x0, x1
ldrb x0, [x0, #0]
cmp x0, 45
b.eq L9501
add x0, x22, x1
ldrb x0, [x0, #0]
cmp x0, 43
b.eq L9501
L9504:
mov x0, x22
mov x1, x19
cmp x0, x1
b.ge L9510
mov x1, x21
add x0, x0, x1
ldrb x0, [x0, #0]
cmp x0, 48
b.lt L9510
add x0, x22, x1
ldrb x0, [x0, #0]
cmp x0, 57
b.gt L9510
L9511:
mov x24, 0
L9512:
mov x0, x22
cmp x0, x19
b.ge L9519
mov x1, x21
add x0, x0, x1
ldrb x0, [x0, #0]
cmp x0, 48
b.lt L9519
add x0, x22, x1
ldrb x0, [x0, #0]
cmp x0, 57
b.gt L9519
mov x1, 10
mul x20, x24, x1
add x0, x22, x21
ldrb x0, [x0, #0]
sub x1, x0, #48
add x24, x20, x1
add x22, x22, #1
b L9512
L9501:
add x0, x22, x21
ldrb x0, [x0, #0]
cmp x0, 45
b.ne L9503
mov x23, 1
L9503:
add x22, x22, #1
b L9504
L9510:
add x0, x28, #70384
bl j2k_throw
b L9511
L9519:
mov x0, x22
cmp x0, x19
b.ge L9525
add x0, x0, x21
ldrb x0, [x0, #0]
cmp x0, 32
b.eq L9524
cmp x0, 9
b.eq L9524
cmp x0, 10
b.eq L9524
cmp x0, 13
b.ne L9525
L9524:
add x22, x22, #1
b L9519
L9525:
mov x1, x19
cmp x22, x1
b.eq L9527
add x0, x28, #70400
bl j2k_throw
L9527:
cmp x23, 1
b.ne L9529
mov x0, 0
sub x0, x0, x24
b L9531
L9529:
mov x0, x24
L9531:
L9484:
ldr x19, [x29, #16]
ldr x20, [x29, #96]
ldr x21, [x29, #24]
ldr x22, [x29, #40]
ldr x23, [x29, #48]
ldr x24, [x29, #56]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000112
ret
.align 32
__flush:
sub sp, sp, #0000064
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #24]
str x20, [x29, #32]
ldr x19, [x28, #880]
mov x1, 0
str x1, [x28, #880]
mov x20, 0
L9554:
mov x0, x20
cmp x0, x19
b.ge L9562
add x0, x28, #896
add x2, x0, x20
sub x3, x19, x20
mov x8, 64
mov x0, 1
mov x1, x2
mov x2, x3
svc 0
cmp x0, 0
b.le L9562
add x20, x20, x0
b L9554
L9562:
L9552:
ldr x19, [x29, #24]
ldr x20, [x29, #32]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000064
ret
.align 32
__wr:
sub sp, sp, #0000224
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #24]
str x20, [x29, #32]
str x21, [x29, #160]
str x22, [x29, #168]
str x23, [x29, #40]
str x24, [x29, #48]
mov x9, x0
mov x19, x1
mov x20, x2
cmp x0, 1
b.eq L9570
mov x21, x0
mov x22, x1
mov x3, x2
mov x8, 64
svc 0
b L9607
L9570:
mov x23, x28
ldr x0, [x28, #888]
mov x24, x0
cmp x0, 0
b.ne L9578
mov x24, 1
mov x21, 1
mov x22, 21505
add x3, x29, #56
mov x8, 29
mov x0, 1
mov x1, 21505
mov x2, x3
svc 0
cmp x0, 0
b.ne L9577
mov x24, 2
L9577:
add x10, x23, #888
mov x3, x10
str x24, [x10, #0]
L9578:
cmp x24, 2
b.ne L9589
mov x24, 0
L9580:
mov x0, x24
cmp x0, x20
b.ge L9607
mov x21, 1
add x22, x19, x24
sub x3, x20, x24
mov x8, 64
mov x0, 1
mov x1, x22
mov x2, x3
svc 0
cmp x0, 0
b.le L9607
add x24, x24, x0
b L9580
L9589:
ldr x0, [x23, #880]
add x0, x0, x20
mov x1, 65536
cmp x0, x1
b.le L9591
bl __flush
L9591:
mov x1, 65536
cmp x20, x1
b.lt L9602
mov x24, 0
mov x21, 1
L9593:
mov x0, x24
cmp x0, x20
b.ge L9607
add x22, x19, x24
sub x3, x20, x24
mov x8, 64
mov x0, 1
mov x1, x22
mov x2, x3
svc 0
cmp x0, 0
b.le L9607
add x24, x24, x0
b L9593
L9602:
add x10, x28, #896
ldr x0, [x23, #880]
add x9, x10, x0
mov x21, 0
mov x22, x20
L9605:
mov x0, x21
cmp x0, x22
b.ge L9606
add x10, x0, x9
add x0, x21, x19
ldrb x0, [x0, #0]
strb x0, [x10, #0]
add x21, x21, #1
b L9605
L9606:
mov x1, x20
ldr x0, [x23, #880]
add x0, x0, x1
str x0, [x23, #880]
L9607:
L9563:
ldr x19, [x29, #24]
ldr x20, [x29, #32]
ldr x21, [x29, #160]
ldr x22, [x29, #168]
ldr x23, [x29, #40]
ldr x24, [x29, #48]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000224
ret
.align 32
__print_bool:
sub sp, sp, #0000112
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #96]
str x20, [x29, #80]
cmp x0, 0
b.eq L9618
ldr x0, [x28, #864]
add x19, x0, #1
add x20, x28, #74696
mov x2, 4
mov x1, x20
mov x0, x19
bl __wr
b L9613
L9618:
ldr x0, [x28, #864]
add x19, x0, #1
add x20, x28, #74704
mov x2, 5
mov x1, x20
mov x0, x19
bl __wr
L9613:
L9609:
ldr x19, [x29, #96]
ldr x20, [x29, #80]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000112
ret
.align 32
__print_ptr:
sub sp, sp, #0000144
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x0, [x29, #16]
mov x0, 22
str x0, [x29, #48]
ldr x0, [x29, #16]
cmp x0, 0
b.ne L9625
ldr x0, [x29, #48]
add x0, x29, x0
add x0, x0, #24
str x0, [x29, #128]
mov x1, 48
strb x1, [x0, #0]
ldr x0, [x29, #48]
sub x0, x0, #1
str x0, [x29, #48]
L9625:
ldr x0, [x29, #16]
str x0, [x29, #56]
mov x0, 0
str x0, [x29, #64]
L9626:
ldr x0, [x29, #64]
cmp x0, 16
b.ge L9635
ldr x0, [x29, #56]
cmp x0, 0
b.eq L9635
ldr x0, [x29, #56]
and x0, x0, #15
str x0, [x29, #72]
cmp x0, 10
b.ge L9633
ldr x0, [x29, #48]
add x0, x29, x0
add x10, x0, #24
ldr x1, [x29, #72]
add x0, x1, #48
uxtb x0, x0
strb x0, [x10, #0]
L9634:
ldr x0, [x29, #48]
sub x0, x0, #1
str x0, [x29, #48]
ldr x0, [x29, #56]
asr x0, x0, #4
and x0, x0, #1152921504606846975
str x0, [x29, #56]
ldr x0, [x29, #64]
add x0, x0, #1
str x0, [x29, #64]
b L9626
L9633:
ldr x0, [x29, #48]
add x0, x29, x0
add x10, x0, #24
ldr x1, [x29, #72]
add x0, x1, #87
uxtb x0, x0
strb x0, [x10, #0]
b L9634
L9635:
ldr x0, [x29, #48]
add x0, x29, x0
add x0, x0, #24
str x0, [x29, #128]
mov x1, 120
strb x1, [x0, #0]
ldr x0, [x29, #48]
sub x0, x0, #1
str x0, [x29, #48]
add x0, x29, x0
add x0, x0, #24
str x0, [x29, #128]
mov x3, x0
mov x1, 48
strb x1, [x0, #0]
ldr x0, [x29, #48]
sub x0, x0, #1
str x0, [x29, #48]
ldr x0, [x28, #864]
add x0, x0, #1
str x0, [x29, #128]
ldr x0, [x29, #48]
add x0, x0, #1
add x0, x29, x0
add x0, x0, #24
str x0, [x29, #112]
mov x0, 22
ldr x1, [x29, #48]
sub x2, x0, x1
ldr x1, [x29, #112]
ldr x0, [x29, #128]
bl __wr
L9622:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000144
ret
__out_fd:
ldr x0, [x28, #864]
add x0, x0, #1
L9641:
ret
.align 32
Sys__call:
sub sp, sp, #0000096
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #80]
str x20, [x29, #88]
mov x19, x0
cmp x0, 93
b.eq L9648
cmp x0, 94
b.ne L9649
L9648:
mov x19, x0
mov x20, x1
bl __flush
mov x0, x19
mov x1, x20
L9649:
mov x8, x0
mov x0, x1
mov x1, x2
mov x2, x3
mov x3, x4
mov x4, x5
mov x5, x6
svc 0
L9645:
ldr x19, [x29, #80]
ldr x20, [x29, #88]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000096
ret
.align 32
Sys__read:
sub sp, sp, #0000064
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #24]
str x20, [x29, #32]
mov x9, x0
mov x19, x1
mov x20, x2
cmp x2, 0
b.ge L9656
mov x0, -22
b L9668
L9656:
cmp x20, 0
b.le L9662
cmp x19, 0
b.ne L9662
mov x0, -14
b L9668
L9662:
mov x3, x20
mov x8, 63
mov x0, x9
mov x1, x19
mov x2, x3
svc 0
L9668:
L9653:
ldr x19, [x29, #24]
ldr x20, [x29, #32]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000064
ret
.align 32
Sys__isatty:
sub sp, sp, #0000128
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
mov x9, x0
add x3, x29, #24
mov x8, 29
mov x1, 21505
mov x2, x3
svc 0
L9669:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000128
ret
.align 32
Sys__window_size:
sub sp, sp, #0000048
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
mov x9, x0
str x1, [x29, #24]
cmp x1, 0
b.ne L9680
mov x0, -14
b L9686
L9680:
mov x1, x9
ldr x3, [x29, #24]
mov x8, 29
mov x0, x1
mov x1, 21523
mov x2, x3
svc 0
L9686:
L9677:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000048
ret
.align 32
Sys__nanosleep:
sub sp, sp, #0000048
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
mov x9, x0
cmp x0, 0
b.ne L9690
mov x0, -14
b L9696
L9690:
mov x0, x9
mov x2, 0
mov x8, 101
mov x1, 0
svc 0
L9696:
L9687:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000048
ret
.align 32
Sys__ppoll:
sub sp, sp, #0000064
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
mov x9, x1
cmp x0, 0
b.eq L9703
cmp x1, 0
b.lt L9703
mov x5, 8
mov x8, 73
mov x3, 0
mov x4, 8
svc 0
b L9710
L9703:
mov x0, -22
L9710:
L9697:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000064
ret
.align 32
Sys__clock_gettime:
sub sp, sp, #0000048
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
mov x9, x0
str x1, [x29, #24]
cmp x1, 0
b.ne L9714
mov x0, -14
b L9720
L9714:
mov x1, x9
ldr x2, [x29, #24]
mov x8, 113
mov x0, x1
mov x1, x2
svc 0
L9720:
L9711:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000048
ret
.align 32
Option__String__Some:
sub sp, sp, #0000096
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #80]
mov x19, x0
mov x9, x1
mov x1, 0
str x1, [x29, #32]
str x1, [x29, #40]
add x1, x29, #48
ldr x2, [x27, #784]
str x2, [x29, #48]
add x2, x29, #32
str x2, [x29, #56]
adr x2, Option__String__free
str x2, [x29, #64]
mov x2, 1
str x2, [x29, #72]
str x1, [x27, #784]
mov x0, 0
str x0, [x29, #32]
mov x0, x9
bl __Str__clone
mov x20, x0
ldr x0, [x29, #40]
bl __Arr__free
str x20, [x29, #40]
add x0, x29, #32
mov x2, x19
ldr x1, [x29, #32]
str x1, [x2, #0]
ldr x1, [x29, #40]
str x1, [x2, #8]
mov x1, 0
str x1, [x29, #32]
str x1, [x29, #40]
mov x20, x0
bl Option__String__free
ldr x1, [x29, #48]
str x1, [x27, #784]
mov x0, x20
L9721:
ldr x19, [x29, #16]
ldr x20, [x29, #80]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000096
ret
.align 32
Option__String__None:
sub sp, sp, #0000096
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #80]
mov x9, x0
mov x1, 0
str x1, [x29, #24]
str x1, [x29, #32]
add x1, x29, #40
ldr x2, [x27, #784]
str x2, [x29, #40]
add x2, x29, #24
str x2, [x29, #48]
adr x2, Option__String__free
str x2, [x29, #56]
mov x2, 1
str x2, [x29, #64]
str x1, [x27, #784]
mov x0, 1
str x0, [x29, #24]
add x0, x29, #24
mov x2, x9
ldr x1, [x29, #24]
str x1, [x2, #0]
ldr x1, [x29, #32]
str x1, [x2, #8]
mov x1, 0
str x1, [x29, #24]
str x1, [x29, #32]
mov x19, x0
bl Option__String__free
ldr x1, [x29, #40]
str x1, [x27, #784]
mov x0, x19
L9725:
ldr x19, [x29, #80]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000096
ret
.align 32
Option__String__free:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
mov x19, x0
ldr x0, [x0, #0]
cmp x0, 0
b.ne L9734
ldr x0, [x19, #8]
bl __Arr__free
mov x0, x19
mov x2, 0
str x2, [x0, #8]
L9734:
L9729:
ldr x19, [x29, #16]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
Env__get:
sub sp, sp, #0000288
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
str x21, [x29, #32]
str x22, [x29, #40]
str x23, [x29, #264]
str x24, [x29, #64]
mov x19, x0
mov x20, x1
ldr x9, [x28, #0]
ldr x0, [x9, #0]
add x21, x0, #1
mov x0, x1
cmp x1, 0
b.ne L9738
add x0, x28, #70240
bl __panic
L9738:
ldr x22, [x0, #0]
mov x0, x20
mov x2, 0
mov x1, 1
bl __Str__ptr
mov x8, x0
L9739:
mov x1, 8
mul x0, x21, x1
mov x20, x0
ldr x9, [x28, #0]
add x9, x9, x0
ldr x0, [x9, #8]
mov x23, x0
mov x1, 0
cmp x0, 0
b.eq L9755
mov x0, x20
ldr x9, [x28, #0]
add x9, x9, x0
ldr x20, [x9, #8]
mov x24, 0
L9741:
mov x0, x24
cmp x0, x22
b.ge L9747
add x0, x0, x20
ldrb x10, [x0, #0]
add x0, x24, x8
ldrb x0, [x0, #0]
cmp x10, x0
b.ne L9747
add x24, x24, #1
b L9741
L9747:
mov x0, x24
cmp x0, x22
b.ne L9754
mov x1, x20
add x0, x0, x1
ldrb x0, [x0, #0]
cmp x0, 61
b.eq L9752
L9754:
add x21, x21, #1
b L9739
L9752:
add x0, x28, #75016
bl __Str__from
str x0, [x29, #72]
add x1, x29, #80
ldr x2, [x27, #784]
str x2, [x29, #80]
add x2, x29, #72
str x2, [x29, #88]
adr x2, __Arr__free
str x2, [x29, #96]
mov x2, 0
str x2, [x29, #104]
str x1, [x27, #784]
ldr x23, [x29, #72]
add x0, x20, x22
add x1, x0, #1
mov x0, x23
mov x2, 0
bl __Str__append
add x23, x29, #112
ldr x1, [x29, #72]
add x0, x29, #112
bl Option__String__Some
add x0, x29, #112
add x1, x29, #128
ldr x2, [x27, #784]
str x2, [x29, #128]
str x0, [x29, #136]
adr x2, Option__String__free
str x2, [x29, #144]
mov x2, 1
str x2, [x29, #152]
str x1, [x27, #784]
mov x3, x19
mov x2, 16
ldr x16, [x29, #112]
str x16, [x3, #0]
ldr x15, [x29, #120]
str x15, [x3, #8]
mov x1, 0
str x1, [x29, #112]
str x1, [x29, #120]
mov x23, x0
add x0, x29, #112
bl Option__String__free
ldr x0, [x29, #72]
bl __Arr__free
ldr x1, [x29, #80]
str x1, [x27, #784]
mov x0, x23
b L9757
L9755:
add x0, x29, #160
bl Option__String__None
add x0, x29, #160
add x1, x29, #176
ldr x2, [x27, #784]
str x2, [x29, #176]
str x0, [x29, #184]
adr x2, Option__String__free
str x2, [x29, #192]
mov x2, 1
str x2, [x29, #200]
str x1, [x27, #784]
mov x3, x19
mov x2, 16
ldr x16, [x29, #160]
str x16, [x3, #0]
ldr x15, [x29, #168]
str x15, [x3, #8]
mov x1, 0
str x1, [x29, #160]
str x1, [x29, #168]
mov x23, x0
add x0, x29, #160
bl Option__String__free
ldr x1, [x29, #176]
str x1, [x27, #784]
mov x0, x23
L9757:
L9735:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x21, [x29, #32]
ldr x22, [x29, #40]
ldr x23, [x29, #264]
ldr x24, [x29, #64]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000288
ret
.align 32
Term__cols:
sub sp, sp, #0000064
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #48]
mov x19, 1
add x1, x29, #16
mov x0, 1
bl Sys__window_size
cmp x0, 0
b.ge L9768
mov x0, 80
b L9772
L9768:
ldrb x0, [x29, #18]
and x19, x0, #255
ldrb x0, [x29, #19]
and x0, x0, #255
orr x0, x19, x0, lsl #8
mov x9, x0
cmp x0, 10
b.ge L9770
mov x0, 80
b L9772
L9770:
mov x0, x9
L9772:
L9765:
ldr x19, [x29, #48]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000064
ret
.align 32
Term__rows:
sub sp, sp, #0000064
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #48]
mov x19, 1
add x1, x29, #16
mov x0, 1
bl Sys__window_size
cmp x0, 0
b.ge L9776
mov x0, 24
b L9780
L9776:
ldrb x0, [x29, #16]
and x19, x0, #255
ldrb x0, [x29, #17]
and x0, x0, #255
orr x0, x19, x0, lsl #8
mov x9, x0
cmp x0, 5
b.ge L9778
mov x0, 24
b L9780
L9778:
mov x0, x9
L9780:
L9773:
ldr x19, [x29, #48]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000064
ret
.align 32
Input__ready:
sub sp, sp, #0000128
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
mov x9, x0
mov x0, 4294967296
str x0, [x29, #24]
mov x0, x9
cmp x0, 0
b.lt L9786
mov x4, 2361183241434822607
smulh x2, x0, x4
str x2, [x29, #64]
asr x2, x2, #7
str x2, [x29, #56]
lsr x3, x2, #63
add x2, x2, x3
mov x8, x2
str x2, [x29, #32]
add x0, x29, #32
add x10, x0, #8
mov x3, 1000
msub x0, x2, x3, x9
mov x1, 1000000
mul x0, x0, x1
mov x3, x10
str x0, [x29, #40]
add x2, x29, #32
mov x1, 1
add x0, x29, #24
bl Sys__ppoll
mov x16, x0
mov x0, 1
cmp x16, 0
b.gt L9790
mov x0, 0
b L9790
L9786:
mov x2, 0
mov x1, 1
add x0, x29, #24
bl Sys__ppoll
mov x15, x0
mov x0, 1
cmp x15, 0
b.gt L9790
mov x0, 0
L9790:
L9781:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000128
ret
.align 32
Time__now_ms:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
add x1, x29, #16
mov x0, 0
bl Sys__clock_gettime
ldr x0, [x29, #16]
mov x1, 1000
mul x10, x0, x1
ldr x0, [x29, #24]
mov x4, 4835703278458516699
smulh x2, x0, x4
asr x2, x2, #18
lsr x3, x2, #63
add x2, x2, x3
add x0, x10, x2
L9791:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
Time__sleep_ms:
sub sp, sp, #0000080
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
mov x9, x0
mov x4, 2361183241434822607
smulh x2, x0, x4
str x2, [x29, #64]
asr x2, x2, #7
str x2, [x29, #56]
lsr x3, x2, #63
add x2, x2, x3
mov x8, x2
str x2, [x29, #24]
add x0, x29, #24
add x10, x0, #8
mov x3, 1000
msub x0, x2, x3, x9
mov x1, 1000000
mul x0, x0, x1
mov x3, x10
mov x1, x0
str x0, [x29, #32]
add x0, x29, #24
bl Sys__nanosleep
L9795:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000080
ret
Key__up:
mov x0, 257
L9798:
ret
Key__down:
mov x0, 258
L9801:
ret
.align 32
game_raw_on:
sub sp, sp, #0000160
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #120]
str x20, [x29, #112]
str x21, [x29, #104]
str x22, [x29, #96]
ldr x0, [x28, #75128]
cmp x0, 0
b.ne L9815
mov x0, 0
bl Sys__isatty
cmp x0, 0
b.ne L9815
add x19, x28, #75064
mov x0, 29
mov x1, 0
mov x2, 21505
mov x3, x19
mov x4, 0
mov x5, 0
mov x6, 0
bl Sys__call
mov x0, 0
mov x9, x0
mov x16, 64
mov x15, -9223372036854775777
cmp x16, x15
b.lt L9821
mov x16, 33
mov x20, x16
add x21, x28, #75064
add x22, x29, #16
L9819:
ldr q17, [x21, #0]
str q17, [x22, #0]
ldr q17, [x21, #16]
str q17, [x22, #16]
add x21, x21, #32
add x22, x22, #32
add x16, x9, #32
mov x9, x16
mov x15, x20
cmp x16, x15
b.lt L9819
L9821:
add x1, x29, #16
L9811:
mov x0, x9
cmp x0, 64
b.ge L9814
add x8, x0, x1
add x0, x9, x28
ldrb x0, [x0, #75064]
strb x0, [x8, #0]
add x9, x9, #1
b L9811
L9814:
ldrb x0, [x29, #28]
mov x1, 244
and x0, x0, x1
strb x0, [x29, #28]
add x19, x29, #16
mov x0, 29
mov x1, 0
mov x2, 21506
add x3, x29, #16
mov x4, 0
mov x5, 0
mov x6, 0
bl Sys__call
mov x0, 1
str x0, [x28, #75128]
L9815:
L9804:
ldr x19, [x29, #120]
ldr x20, [x29, #112]
ldr x21, [x29, #104]
ldr x22, [x29, #96]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000160
ret
.align 32
game_raw_off:
sub sp, sp, #0000016
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
ldr x0, [x28, #75128]
cmp x0, 0
b.eq L9828
add x3, x28, #75064
mov x0, 29
mov x1, 0
mov x2, 21506
mov x4, 0
mov x5, 0
mov x6, 0
bl Sys__call
mov x0, 0
str x0, [x28, #75128]
L9828:
L9822:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000016
ret
.align 32
game_byte:
sub sp, sp, #0000048
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
bl Input__ready
cmp x0, 0
b.ne L9834
mov x0, -1
b L9839
L9834:
mov x0, 0
add x1, x29, #24
mov x2, 1
bl Sys__read
cmp x0, 0
b.le L9835
ldrb x0, [x29, #24]
and x0, x0, #255
b L9839
L9835:
mov x0, -2
L9839:
L9829:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000048
ret
.align 32
game_font:
sub sp, sp, #0000016
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
add x0, x28, #75144
bl __Str__from
L9840:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000016
ret
Game__rgb:
and x0, x0, #255
lsl x8, x0, #16
and x0, x1, #255
orr x8, x8, x0, lsl #8
and x0, x2, #255
orr x0, x8, x0
L9843:
ret
.align 32
Game__open:
sub sp, sp, #0000560
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #552]
str x21, [x29, #544]
str x22, [x29, #240]
str x23, [x29, #256]
str x24, [x29, #264]
str x25, [x29, #344]
mov x19, x0
mov x1, 0
str x1, [x29, #32]
str x1, [x29, #40]
str x1, [x29, #48]
str x1, [x29, #56]
str x1, [x29, #64]
str x1, [x29, #72]
str x1, [x29, #80]
str x1, [x29, #88]
str x1, [x29, #96]
str x1, [x29, #104]
str x1, [x29, #112]
str x1, [x29, #120]
str x1, [x29, #128]
str x1, [x29, #136]
str x1, [x29, #144]
bl Term__cols
str x0, [x29, #48]
bl Term__rows
str x0, [x29, #56]
mov x0, 1
mov x20, x0
bl Sys__isatty
cmp x0, 0
b.eq L9848
L9850:
mov x0, 0
L9851:
str x0, [x28, #75136]
mov x0, 0
str x0, [x29, #128]
add x20, x29, #152
add x0, x28, #75472
bl __Str__from
str x0, [x29, #168]
add x1, x29, #176
ldr x2, [x27, #784]
str x2, [x29, #176]
add x2, x29, #168
str x2, [x29, #184]
adr x2, __Arr__free
str x2, [x29, #192]
mov x2, 0
str x2, [x29, #200]
str x1, [x27, #784]
mov x21, x0
mov x0, x20
mov x1, x21
bl Env__get
add x0, x29, #152
add x1, x29, #208
ldr x2, [x27, #784]
str x2, [x29, #208]
str x0, [x29, #216]
adr x2, Option__String__free
str x2, [x29, #224]
mov x2, 1
str x2, [x29, #232]
str x1, [x27, #784]
mov x22, x0
ldr x0, [x29, #152]
cmp x0, 0
b.eq L9854
ldr x0, [x29, #152]
cmp x0, 1
b.eq L9856
L9856:
ldr x0, [x28, #75136]
cmp x0, 0
b.ne L9860
ldr x0, [x29, #128]
cmp x0, 0
b.eq L9858
L9860:
ldr x0, [x28, #75136]
cmp x0, 0
b.ne L9863
mov x0, 80
str x0, [x29, #48]
mov x0, 24
str x0, [x29, #56]
L9863:
ldr x0, [x29, #48]
str x0, [x29, #32]
ldr x0, [x29, #56]
mov x1, 2
mul x0, x0, x1
str x0, [x29, #40]
ldr x8, [x29, #32]
ldr x0, [x29, #40]
mul x0, x8, x0
add x1, x0, #1
mov x0, 8
bl __Arr__make
mov x20, x0
str x0, [x29, #64]
ldr x8, [x29, #32]
ldr x0, [x29, #40]
mul x0, x8, x0
add x1, x0, #1
mov x0, 8
bl __Arr__make
mov x20, x0
mov x2, x0
str x0, [x29, #72]
mov x23, 0
ldr x8, [x29, #32]
ldr x0, [x29, #40]
mul x24, x8, x0
L9864:
mov x1, x24
cmp x23, x1
b.ge L9867
ldr x20, [x29, #64]
mov x21, 0
mov x0, x20
mov x25, x0
cmp x0, 0
b.eq L9877
mov x9, x0
ldr x0, [x0, #0]
add x1, x0, #1
mov x0, x9
bl __Arr__grow
ldr x10, [x25, #16]
ldr x11, [x25, #0]
ldr x0, [x25, #24]
mul x0, x11, x0
add x9, x10, x0
mov x10, x25
ldr x0, [x25, #0]
add x0, x0, #1
str x0, [x10, #0]
mov x2, x9
str x21, [x9, #0]
ldr x20, [x29, #72]
mov x1, 1
mov x0, -1
mov x21, x0
mov x0, x20
mov x25, x0
cmp x0, 0
b.eq L9892
mov x9, x0
ldr x0, [x0, #0]
add x1, x0, #1
mov x0, x9
bl __Arr__grow
ldr x10, [x25, #16]
ldr x11, [x25, #0]
ldr x0, [x25, #24]
mul x0, x11, x0
add x9, x10, x0
mov x10, x25
ldr x0, [x25, #0]
add x0, x0, #1
str x0, [x10, #0]
mov x2, x9
str x21, [x9, #0]
add x23, x23, #1
b L9864
L9848:
mov x0, 0
mov x20, x0
bl Sys__isatty
cmp x0, 0
b.ne L9850
mov x0, 1
b L9851
L9854:
ldr x1, [x22, #8]
mov x0, x1
bl __Str__to_int
str x0, [x29, #128]
add x0, x29, #152
bl Option__String__free
ldr x0, [x29, #168]
bl __Arr__free
ldr x1, [x29, #176]
str x1, [x27, #784]
b L9856
L9858:
mov x0, 1
str x0, [x29, #128]
b L9860
L9867:
mov x1, 512
mov x0, 8
bl __Arr__make
mov x20, x0
str x0, [x29, #80]
mov x1, 512
mov x0, 8
bl __Arr__make
mov x20, x0
mov x2, x0
str x0, [x29, #88]
mov x22, 0
mov x16, 100000
mov x23, x16
mov x15, -100000
mov x24, x15
L9868:
cmp x22, 512
b.ge L9871
ldr x20, [x29, #80]
mov x1, x23
mov x21, x24
mov x0, x20
mov x25, x0
cmp x0, 0
b.eq L9883
mov x9, x0
ldr x0, [x0, #0]
add x1, x0, #1
mov x0, x9
bl __Arr__grow
ldr x10, [x25, #16]
ldr x11, [x25, #0]
ldr x0, [x25, #24]
mul x0, x11, x0
add x9, x10, x0
mov x10, x25
ldr x0, [x25, #0]
add x0, x0, #1
str x0, [x10, #0]
mov x2, x9
mov x1, x21
str x1, [x9, #0]
ldr x20, [x29, #88]
mov x21, 0
mov x0, x20
mov x25, x0
cmp x0, 0
b.eq L9898
mov x9, x0
ldr x0, [x0, #0]
add x1, x0, #1
mov x0, x9
bl __Arr__grow
ldr x10, [x25, #16]
ldr x11, [x25, #0]
ldr x0, [x25, #24]
mul x0, x11, x0
add x9, x10, x0
mov x10, x25
ldr x0, [x25, #0]
add x0, x0, #1
str x0, [x10, #0]
mov x2, x9
mov x1, x21
str x1, [x9, #0]
add x22, x22, #1
b L9868
L9871:
mov x0, 1
str x0, [x29, #96]
mov x0, 1
str x0, [x29, #97]
mov x0, 0
str x0, [x29, #104]
mov x0, 16
str x0, [x29, #120]
mov x17, 4580268907426851324
fmov d0, x17
fmov x0, d0
str x0, [x29, #136]
bl Time__now_ms
str x0, [x29, #112]
add x0, x28, #75144
bl __Str__from
str x0, [x29, #288]
add x1, x29, #296
ldr x2, [x27, #784]
str x2, [x29, #296]
add x2, x29, #288
str x2, [x29, #304]
adr x2, __Arr__free
str x2, [x29, #312]
mov x2, 0
str x2, [x29, #320]
str x1, [x27, #784]
mov x1, 0
str x1, [x29, #288]
mov x20, x0
ldr x0, [x29, #144]
bl __Arr__free
mov x2, x20
str x2, [x29, #144]
ldr x1, [x29, #296]
str x1, [x27, #784]
ldr x0, [x28, #75136]
cmp x0, 0
b.ne L9872
L9874:
add x0, x29, #32
mov x2, x19
ldr x1, [x29, #32]
str x1, [x2, #0]
ldr x1, [x29, #40]
str x1, [x2, #8]
ldr x1, [x29, #48]
str x1, [x2, #16]
ldr x1, [x29, #56]
str x1, [x2, #24]
ldr x1, [x29, #64]
str x1, [x2, #32]
ldr x1, [x29, #72]
str x1, [x2, #40]
ldr x1, [x29, #80]
str x1, [x2, #48]
ldr x1, [x29, #88]
str x1, [x2, #56]
ldr x1, [x29, #96]
str x1, [x2, #64]
ldr x1, [x29, #104]
str x1, [x2, #72]
ldr x1, [x29, #112]
str x1, [x2, #80]
ldr x1, [x29, #120]
str x1, [x2, #88]
ldr x1, [x29, #128]
str x1, [x2, #96]
ldr x1, [x29, #136]
str x1, [x2, #104]
ldr x1, [x29, #144]
str x1, [x2, #112]
b L9875
L9872:
bl game_raw_on
add x0, x28, #75488
bl j2k_print_str
b L9874
L9877:
add x0, x28, #70304
bl __panic
L9883:
add x0, x28, #70304
bl __panic
L9892:
add x0, x28, #70304
bl __panic
L9898:
add x0, x28, #70304
bl __panic
L9875:
L9846:
ldr x19, [x29, #16]
ldr x20, [x29, #552]
ldr x21, [x29, #544]
ldr x22, [x29, #240]
ldr x23, [x29, #256]
ldr x24, [x29, #264]
ldr x25, [x29, #344]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000560
ret
Game__running:
ldr x0, [x0, #64]
L9904:
ret
.align 32
Game__close:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
mov x19, x0
ldr x0, [x28, #75136]
cmp x0, 0
b.ne L9909
L9911:
mov x0, 0
str x0, [x19, #64]
b L9912
L9909:
add x0, x28, #75512
bl j2k_print_str
bl game_raw_off
b L9911
L9912:
L9907:
ldr x19, [x29, #16]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
Game__note_key:
sub sp, sp, #0000048
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
str x21, [x29, #32]
mov x19, x0
mov x20, x1
mov x21, x2
mov x0, x1
cmp x1, 0
b.lt L9924
mov x1, 512
cmp x0, 512
b.ge L9924
ldr x0, [x19, #48]
cmp x0, 0
b.ne L9921
add x0, x28, #70240
bl __panic
L9921:
mov x8, x0
lsl x0, x20, #3
ldr x1, [x8, #16]
add x8, x0, x1
mov x1, x8
str x21, [x8, #0]
ldr x0, [x19, #56]
cmp x0, 0
b.ne L9923
add x0, x28, #70240
bl __panic
L9923:
mov x8, x0
lsl x0, x20, #3
ldr x1, [x8, #16]
add x8, x0, x1
mov x0, 1
str x0, [x8, #0]
L9924:
L9913:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x21, [x29, #32]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000048
ret
.align 32
Game__begin:
sub sp, sp, #0000480
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
str x21, [x29, #32]
str x22, [x29, #72]
str x23, [x29, #464]
str x24, [x29, #64]
str x25, [x29, #352]
mov x19, x0
bl Time__now_ms
mov x20, x0
mov x9, x20
ldr x0, [x19, #80]
sub x0, x9, x0
scvtf d0, x0
mov x17, 4652007308841189376
fmov d1, x17
fdiv d0, d0, d1
str d0, [x19, #104]
ldr d0, [x19, #104]
mov x17, 4591870180066957722
fmov d1, x17
fcmp d0, d1
b.gt L9933
L9935:
str x20, [x19, #80]
mov x21, 0
L9936:
mov x1, 512
cmp x21, 512
b.ge L9941
ldr x0, [x19, #56]
cmp x0, 0
b.ne L9939
add x0, x28, #70240
bl __panic
L9933:
mov x17, 4591870180066957722
fmov d0, x17
str d0, [x19, #104]
b L9935
L9939:
mov x8, x0
lsl x0, x21, #3
ldr x1, [x8, #16]
add x8, x0, x1
mov x0, 0
str x0, [x8, #0]
add x21, x21, #1
b L9936
L9941:
ldr x0, [x28, #75136]
cmp x0, 0
b.eq L10000
mov x16, 2361183241434822607
str x16, [x29, #440]
mov x15, 1000000
str x15, [x29, #432]
L9946:
mov x23, 0
mov x0, 4294967296
str x0, [x29, #88]
mov x0, 0
ldr x4, [x29, #440]
smulh x2, x0, x4
asr x2, x2, #7
str x2, [x29, #96]
add x0, x29, #96
add x10, x0, #8
mov x0, 0
mov x3, 1000
msub x0, x2, x3, x0
ldr x1, [x29, #432]
mul x0, x0, x1
mov x3, x10
str x0, [x29, #104]
add x2, x29, #96
mov x1, 1
add x0, x29, #88
bl Sys__ppoll
cmp x0, 0
b.le L10006
mov x0, 0
mov x23, x0
bl Input__ready
cmp x0, 0
b.ne L10018
mov x0, -1
L10024:
str x0, [x29, #48]
cmp x0, 0
b.lt L10000
cmp x0, 3
b.eq L9952
cmp x0, 27
b.eq L9956
cmp x0, 65
b.ge L9995
L9998:
mov x23, x19
ldr x25, [x29, #48]
mov x21, x20
mov x0, x23
mov x1, x25
mov x2, x21
bl Game__note_key
b L9946
L9952:
mov x0, 0
str x0, [x19, #64]
b L9946
L9956:
mov x0, 8
mov x23, x0
bl Input__ready
cmp x0, 0
b.ne L10029
mov x0, -1
L9957:
mov x23, x19
mov x25, 27
mov x21, x20
mov x1, 27
mov x2, x21
str x23, [x29, #176]
mov x22, x1
str x2, [x29, #192]
ldr x0, [x23, #48]
cmp x0, 0
b.ne L10043
bl __Arr__nullerr
L10043:
mov x8, x0
lsl x0, x22, #3
ldr x1, [x8, #16]
add x8, x0, x1
ldr x0, [x29, #192]
str x0, [x8, #0]
ldr x0, [x29, #176]
ldr x0, [x0, #56]
cmp x0, 0
b.ne L10045
bl __Arr__nullerr
L10045:
mov x8, x0
lsl x0, x22, #3
ldr x1, [x8, #16]
add x8, x0, x1
mov x0, 1
str x0, [x8, #0]
mov x0, 0
str x0, [x19, #64]
b L9946
L9960:
cmp x0, 91
b.eq L9962
cmp x0, 79
b.eq L9962
cmp x0, 93
b.ne L9946
mov x0, 30
mov x23, x0
bl Input__ready
cmp x0, 0
b.ne L10122
mov x0, -1
L10128:
mov x22, x0
L9981:
cmp x22, 0
b.ge L9982
L9985:
cmp x22, 27
b.ne L9946
mov x0, 8
mov x23, x0
bl game_byte
b L9946
L9962:
mov x0, 8
mov x23, x0
bl Input__ready
cmp x0, 0
b.ne L10052
mov x0, -1
L10058:
mov x24, x0
cmp x0, 65
b.eq L9963
cmp x0, 66
b.eq L9965
cmp x0, 67
b.eq L9967
cmp x0, 68
b.eq L9969
mov x23, 8
L9971:
mov x0, x24
cmp x0, 48
b.lt L9946
cmp x0, 59
b.gt L9946
mov x0, x23
bl Input__ready
cmp x0, 0
b.ne L10111
mov x0, -1
L10117:
mov x24, x0
b L9971
L9963:
mov x23, x19
mov x25, 257
mov x21, x20
mov x1, 257
mov x2, x21
str x23, [x29, #240]
mov x24, x1
str x2, [x29, #256]
ldr x0, [x23, #48]
cmp x0, 0
b.ne L10066
bl __Arr__nullerr
L10066:
mov x8, x0
lsl x0, x24, #3
ldr x1, [x8, #16]
add x8, x0, x1
ldr x0, [x29, #256]
str x0, [x8, #0]
ldr x0, [x29, #240]
ldr x0, [x0, #56]
cmp x0, 0
b.ne L10068
bl __Arr__nullerr
L10068:
mov x8, x0
lsl x0, x24, #3
ldr x1, [x8, #16]
add x8, x0, x1
mov x0, 1
str x0, [x8, #0]
b L9946
L9965:
mov x23, x19
mov x25, 258
mov x21, x20
mov x1, 258
mov x2, x21
str x23, [x29, #272]
mov x24, x1
str x2, [x29, #288]
ldr x0, [x23, #48]
cmp x0, 0
b.ne L10078
bl __Arr__nullerr
L10078:
mov x8, x0
lsl x0, x24, #3
ldr x1, [x8, #16]
add x8, x0, x1
ldr x0, [x29, #288]
str x0, [x8, #0]
ldr x0, [x29, #272]
ldr x0, [x0, #56]
cmp x0, 0
b.ne L10080
bl __Arr__nullerr
L10080:
mov x8, x0
lsl x0, x24, #3
ldr x1, [x8, #16]
add x8, x0, x1
mov x0, 1
str x0, [x8, #0]
b L9946
L9967:
mov x23, x19
mov x25, 259
mov x21, x20
mov x1, 259
mov x2, x21
str x23, [x29, #304]
mov x24, x1
str x2, [x29, #320]
ldr x0, [x23, #48]
cmp x0, 0
b.ne L10090
bl __Arr__nullerr
L10090:
mov x8, x0
lsl x0, x24, #3
ldr x1, [x8, #16]
add x8, x0, x1
ldr x0, [x29, #320]
str x0, [x8, #0]
ldr x0, [x29, #304]
ldr x0, [x0, #56]
cmp x0, 0
b.ne L10092
bl __Arr__nullerr
L10092:
mov x8, x0
lsl x0, x24, #3
ldr x1, [x8, #16]
add x8, x0, x1
mov x0, 1
str x0, [x8, #0]
b L9946
L9969:
mov x23, x19
mov x21, x20
mov x1, 260
mov x2, x21
mov x21, x23
mov x24, x1
mov x25, x2
ldr x0, [x23, #48]
cmp x0, 0
b.ne L10102
bl __Arr__nullerr
L10102:
mov x8, x0
lsl x0, x24, #3
ldr x1, [x8, #16]
add x8, x0, x1
str x25, [x8, #0]
ldr x0, [x21, #56]
cmp x0, 0
b.ne L10104
bl __Arr__nullerr
L10104:
mov x8, x0
lsl x0, x24, #3
ldr x1, [x8, #16]
add x8, x0, x1
mov x0, 1
str x0, [x8, #0]
b L9946
L9982:
mov x0, x22
cmp x0, 7
b.eq L9985
cmp x0, 27
b.eq L9985
mov x0, 30
mov x23, x0
bl game_byte
mov x22, x0
b L9981
L9995:
cmp x0, 90
b.gt L9998
add x0, x0, #32
str x0, [x29, #48]
b L9998
L10006:
mov x0, 0
b L10000
L10018:
mov x0, 0
add x1, x29, #120
mov x2, 1
bl Sys__read
cmp x0, 0
b.le L10019
ldrb x0, [x29, #120]
and x0, x0, #255
b L10024
L10019:
mov x0, -2
b L10024
L10029:
mov x0, 0
add x1, x29, #152
mov x2, 1
bl Sys__read
cmp x0, 0
b.le L10030
ldrb x0, [x29, #152]
and x0, x0, #255
cmp x0, 0
b.lt L9957
b L9960
L10030:
b L9957
L10052:
mov x0, 0
add x1, x29, #216
mov x2, 1
bl Sys__read
cmp x0, 0
b.le L10053
ldrb x0, [x29, #216]
and x0, x0, #255
b L10058
L10053:
mov x0, -2
b L10058
L10111:
mov x0, 0
add x1, x29, #376
mov x2, 1
bl Sys__read
cmp x0, 0
b.le L10112
ldrb x0, [x29, #376]
and x0, x0, #255
b L10117
L10112:
mov x0, -2
b L10117
L10122:
mov x0, 0
add x1, x29, #408
mov x2, 1
bl Sys__read
cmp x0, 0
b.le L10123
ldrb x0, [x29, #408]
and x0, x0, #255
b L10128
L10123:
mov x0, -2
b L10128
L10000:
L9931:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x21, [x29, #32]
ldr x22, [x29, #72]
ldr x23, [x29, #464]
ldr x24, [x29, #64]
ldr x25, [x29, #352]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000480
ret
.align 32
Game__hit:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #24]
mov x9, x0
mov x19, x1
mov x0, x1
cmp x1, 0
b.ge L10133
L10138:
mov x0, 0
b L10140
L10133:
mov x1, 512
cmp x0, 512
b.ge L10138
ldr x0, [x9, #56]
cmp x0, 0
b.ne L10136
add x0, x28, #70240
bl __panic
L10136:
mov x8, x0
lsl x0, x19, #3
ldr x1, [x8, #16]
add x0, x0, x1
ldr x0, [x0, #0]
cmp x0, 1
b.ne L10138
mov x0, 1
L10140:
L10131:
ldr x19, [x29, #24]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
Game__held:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
mov x19, x0
mov x20, x1
cmp x1, 0
b.ge L10146
L10151:
mov x0, 0
b L10153
L10146:
cmp x1, 512
b.ge L10151
bl Time__now_ms
mov x8, x0
ldr x0, [x19, #48]
cmp x0, 0
b.ne L10149
add x0, x28, #70240
bl __panic
L10149:
mov x9, x0
lsl x0, x20, #3
ldr x1, [x9, #16]
add x0, x0, x1
ldr x0, [x0, #0]
sub x0, x8, x0
cmp x0, 180
b.ge L10151
mov x0, 1
L10153:
L10144:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
Game__clear:
sub sp, sp, #0000048
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #24]
str x20, [x29, #32]
str x21, [x29, #40]
mov x9, x0
mov x19, x1
mov x20, 0
ldr x8, [x9, #0]
ldr x0, [x9, #8]
mul x21, x8, x0
L10159:
mov x0, x20
mov x1, x21
cmp x0, x1
b.ge L10165
ldr x0, [x9, #32]
cmp x0, 0
b.eq L10166
mov x8, x0
lsl x0, x20, #3
ldr x1, [x8, #16]
add x8, x0, x1
str x19, [x8, #0]
add x20, x20, #1
b L10159
L10166:
add x0, x28, #70240
bl __panic
L10165:
L10157:
ldr x19, [x29, #24]
ldr x20, [x29, #32]
ldr x21, [x29, #40]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000048
ret
.align 32
Game__pixel:
sub sp, sp, #0000048
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #24]
str x21, [x29, #32]
mov x19, x0
mov x20, x1
mov x21, x2
str x3, [x29, #40]
mov x0, x1
cmp x1, 0
b.lt L10180
mov x0, x2
cmp x2, 0
b.lt L10180
mov x8, x20
ldr x1, [x19, #0]
mov x0, x8
cmp x8, x1
b.ge L10180
mov x8, x21
ldr x1, [x19, #8]
mov x0, x8
cmp x8, x1
b.ge L10180
ldr x0, [x19, #32]
cmp x0, 0
b.ne L10179
add x0, x28, #70240
bl __panic
L10179:
mov x8, x0
mov x9, x21
ldr x0, [x19, #0]
mul x0, x9, x0
add x0, x0, x20
lsl x0, x0, #3
ldr x1, [x8, #16]
add x8, x0, x1
ldr x0, [x29, #40]
str x0, [x8, #0]
L10180:
L10169:
ldr x19, [x29, #16]
ldr x20, [x29, #24]
ldr x21, [x29, #32]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000048
ret
.align 32
Game__rect:
sub sp, sp, #0000128
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
str x20, [x29, #120]
str x21, [x29, #112]
str x22, [x29, #72]
str x23, [x29, #80]
str x24, [x29, #88]
str x25, [x29, #96]
mov x19, x0
str x5, [x29, #56]
str x1, [x29, #64]
mov x22, x2
add x23, x1, x3
add x24, x2, x4
cmp x1, 0
b.lt L10186
L10188:
cmp x22, 0
b.lt L10189
L10191:
mov x8, x23
ldr x0, [x19, #0]
cmp x8, x0
b.gt L10192
L10194:
mov x8, x24
ldr x0, [x19, #8]
cmp x8, x0
b.gt L10195
L10197:
mov x25, x22
str x24, [x29, #104]
mov x20, x23
L10198:
mov x0, x25
ldr x1, [x29, #104]
cmp x0, x1
b.ge L10208
ldr x21, [x29, #64]
mov x9, x25
L10200:
mov x1, x20
cmp x21, x1
b.lt L10201
add x25, x25, #1
b L10198
L10186:
mov x0, 0
str x0, [x29, #64]
b L10188
L10189:
mov x22, 0
b L10191
L10192:
ldr x23, [x19, #0]
b L10194
L10195:
ldr x24, [x19, #8]
b L10197
L10201:
ldr x0, [x19, #32]
cmp x0, 0
b.eq L10209
mov x8, x0
ldr x0, [x19, #0]
mul x0, x9, x0
add x0, x0, x21
lsl x0, x0, #3
ldr x1, [x8, #16]
add x8, x0, x1
ldr x0, [x29, #56]
str x0, [x8, #0]
add x21, x21, #1
b L10200
L10209:
add x0, x28, #70240
bl __panic
L10208:
L10184:
ldr x19, [x29, #16]
ldr x20, [x29, #120]
ldr x21, [x29, #112]
ldr x22, [x29, #72]
ldr x23, [x29, #80]
ldr x24, [x29, #88]
ldr x25, [x29, #96]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000128
ret
.align 32
Game__line:
sub sp, sp, #0000192
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #72]
str x20, [x29, #24]
str x21, [x29, #32]
str x22, [x29, #88]
str x23, [x29, #104]
str x24, [x29, #96]
str x25, [x29, #64]
str x0, [x29, #16]
mov x20, x1
mov x21, x2
str x3, [x29, #40]
str x4, [x29, #48]
str x5, [x29, #56]
sub x0, x3, x1
mov x25, x0
cmp x0, 0
b.lt L10216
L10218:
ldr x0, [x29, #48]
sub x0, x0, x21
mov x19, x0
cmp x0, 0
b.lt L10219
L10221:
mov x0, 1
str x0, [x29, #80]
mov x0, x20
ldr x1, [x29, #40]
cmp x0, x1
b.gt L10222
L10224:
mov x22, 1
mov x0, x21
ldr x1, [x29, #48]
cmp x0, x1
b.gt L10225
L10227:
sub x24, x25, x19
mov x0, 0
sub x0, x0, x19
str x0, [x29, #144]
L10229:
ldr x8, [x29, #16]
str x20, [x29, #168]
str x21, [x29, #160]
ldr x0, [x29, #56]
ldr x1, [x29, #168]
ldr x2, [x29, #160]
mov x3, x0
mov x23, x8
str x1, [x29, #120]
str x2, [x29, #128]
str x0, [x29, #136]
cmp x1, 0
b.lt L10254
cmp x2, 0
b.lt L10254
ldr x0, [x8, #0]
cmp x1, x0
b.ge L10254
ldr x0, [x23, #8]
mov x1, x0
cmp x2, x0
b.ge L10254
ldr x0, [x23, #32]
cmp x0, 0
b.eq L10255
mov x8, x0
ldr x9, [x29, #128]
ldr x0, [x23, #0]
mul x0, x9, x0
ldr x1, [x29, #120]
add x0, x0, x1
lsl x0, x0, #3
ldr x1, [x8, #16]
add x8, x0, x1
ldr x0, [x29, #136]
str x0, [x8, #0]
L10254:
mov x0, x20
ldr x1, [x29, #40]
cmp x0, x1
b.eq L10230
L10234:
mov x0, 2
mul x0, x0, x24
mov x23, x0
mov x8, x0
ldr x0, [x29, #144]
cmp x8, x0
b.gt L10235
L10237:
mov x1, x25
cmp x23, x1
b.ge L10229
add x24, x24, x1
add x21, x21, x22
b L10229
L10216:
mov x0, 0
sub x25, x0, x25
b L10218
L10219:
mov x0, 0
sub x19, x0, x19
b L10221
L10222:
mov x0, -1
str x0, [x29, #80]
b L10224
L10225:
mov x0, -1
mov x22, x0
b L10227
L10230:
mov x0, x21
ldr x1, [x29, #48]
cmp x0, x1
b.eq L10242
b L10234
L10235:
sub x24, x24, x19
mov x0, x20
ldr x1, [x29, #80]
add x20, x0, x1
b L10237
L10255:
add x0, x28, #70240
bl __panic
L10242:
L10214:
ldr x19, [x29, #72]
ldr x20, [x29, #24]
ldr x21, [x29, #32]
ldr x22, [x29, #88]
ldr x23, [x29, #104]
ldr x24, [x29, #96]
ldr x25, [x29, #64]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000192
ret
.align 32
Game__circle:
sub sp, sp, #0000208
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #112]
str x20, [x29, #120]
str x21, [x29, #96]
str x22, [x29, #176]
str x23, [x29, #48]
str x24, [x29, #104]
str x25, [x29, #72]
str x0, [x29, #16]
str x1, [x29, #24]
str x2, [x29, #32]
str x3, [x29, #40]
mov x23, x4
mov x0, 0
sub x0, x0, x3
str x0, [x29, #56]
add x0, x3, #1
str x0, [x29, #64]
mov x0, 0
ldr x1, [x29, #40]
sub x0, x0, x1
str x0, [x29, #136]
ldr x0, [x29, #40]
add x0, x0, #1
str x0, [x29, #80]
ldr x0, [x29, #40]
ldr x1, [x29, #40]
mul x0, x0, x1
str x0, [x29, #128]
str x0, [x29, #152]
L10261:
ldr x0, [x29, #56]
ldr x1, [x29, #64]
cmp x0, x1
b.ge L10272
ldr x25, [x29, #136]
ldr x0, [x29, #80]
ldr x0, [x29, #56]
ldr x1, [x29, #56]
mul x0, x0, x1
str x0, [x29, #160]
ldr x0, [x29, #152]
ldr x0, [x29, #32]
ldr x1, [x29, #56]
add x0, x0, x1
str x0, [x29, #144]
mov x22, x0
L10263:
mov x0, x25
ldr x1, [x29, #80]
cmp x0, x1
b.lt L10264
ldr x0, [x29, #56]
add x0, x0, #1
str x0, [x29, #56]
b L10261
L10264:
mul x8, x25, x25
ldr x0, [x29, #160]
add x8, x8, x0
ldr x0, [x29, #152]
cmp x8, x0
b.le L10265
L10268:
add x25, x25, #1
b L10263
L10265:
ldr x8, [x29, #16]
ldr x0, [x29, #24]
add x21, x0, x25
mov x1, x21
mov x2, x22
mov x3, x23
mov x21, x8
mov x24, x1
mov x19, x2
mov x20, x23
cmp x1, 0
b.lt L10268
cmp x2, 0
b.lt L10268
ldr x0, [x8, #0]
cmp x1, x0
b.ge L10268
ldr x0, [x21, #8]
mov x1, x0
cmp x2, x0
b.ge L10268
ldr x0, [x21, #32]
cmp x0, 0
b.eq L10285
mov x8, x0
mov x9, x19
ldr x0, [x21, #0]
mul x0, x9, x0
add x0, x0, x24
lsl x0, x0, #3
ldr x1, [x8, #16]
add x8, x0, x1
str x20, [x8, #0]
b L10268
L10285:
add x0, x28, #70240
bl __panic
L10272:
L10259:
ldr x19, [x29, #112]
ldr x20, [x29, #120]
ldr x21, [x29, #96]
ldr x22, [x29, #176]
ldr x23, [x29, #48]
ldr x24, [x29, #104]
ldr x25, [x29, #72]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000208
ret
.align 32
Game__text:
sub sp, sp, #0000112
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x0, [x29, #96]
str x1, [x29, #88]
str x2, [x29, #80]
mov x8, x4
ldr x0, [x29, #96]
ldr x1, [x29, #88]
ldr x2, [x29, #80]
mov x5, 1
bl Game__text_scaled
L10290:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000112
ret
.align 32
Game__text_scaled:
sub sp, sp, #0000208
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #88]
str x20, [x29, #24]
str x21, [x29, #144]
str x22, [x29, #192]
str x23, [x29, #168]
str x24, [x29, #96]
str x25, [x29, #64]
str x0, [x29, #16]
mov x20, x1
str x2, [x29, #32]
str x3, [x29, #40]
str x4, [x29, #48]
str x5, [x29, #56]
mov x25, 0
mov x0, x3
cmp x3, 0
b.ne L10296
add x0, x28, #70240
bl __panic
L10296:
ldr x0, [x0, #0]
str x0, [x29, #72]
mov x0, 4
ldr x1, [x29, #56]
mul x21, x0, x1
ldr x22, [x29, #16]
ldr x23, [x29, #56]
L10297:
mov x0, x25
ldr x1, [x29, #72]
cmp x0, x1
b.ge L10323
ldr x0, [x29, #40]
cmp x0, 0
b.eq L10328
mov x8, x0
mov x0, x25
ldr x1, [x8, #16]
add x0, x0, x1
ldrb x0, [x0, #0]
and x0, x0, #255
mov x9, x0
cmp x0, 97
b.ge L10301
L10304:
mov x0, x9
cmp x0, 32
b.lt L10306
cmp x0, 95
b.gt L10306
L10308:
sub x0, x9, #32
mov x1, 5
mul x19, x0, x1
mov x24, 0
mov x0, x23
L10309:
mov x1, 5
cmp x24, 5
b.lt L10310
add x20, x20, x21
add x25, x25, #1
b L10297
L10301:
cmp x0, 122
b.gt L10304
sub x9, x0, #32
b L10304
L10306:
mov x9, 63
b L10308
L10310:
ldr x0, [x29, #16]
ldr x0, [x0, #112]
cmp x0, 0
b.eq L10331
mov x8, x0
add x0, x19, x24
ldr x1, [x8, #16]
add x0, x0, x1
ldrb x0, [x0, #0]
sub x0, x0, #48
str x0, [x29, #112]
mov x0, 0
str x0, [x29, #120]
mov x0, x24
ldr x1, [x29, #56]
mul x9, x0, x1
ldr x8, [x29, #32]
add x0, x8, x9
mov x9, x0
str x0, [x29, #176]
mov x0, x23
L10313:
ldr x0, [x29, #120]
cmp x0, 3
b.lt L10314
add x24, x24, #1
b L10309
L10314:
ldr x8, [x29, #112]
mov x0, 2
ldr x1, [x29, #120]
sub x0, x0, x1
asr x0, x8, x0
and x0, x0, #1
cmp x0, 0
b.ne L10315
L10318:
ldr x0, [x29, #120]
add x0, x0, #1
str x0, [x29, #120]
b L10313
L10315:
mov x8, x20
ldr x0, [x29, #120]
ldr x1, [x29, #56]
mul x0, x0, x1
add x9, x8, x0
ldr x0, [x29, #176]
ldr x5, [x29, #48]
mov x0, x22
mov x1, x9
ldr x2, [x29, #176]
mov x3, x23
mov x4, x3
bl Game__rect
b L10318
L10323:
mov x0, x20
b L10324
L10328:
add x0, x28, #70240
bl __panic
L10331:
add x0, x28, #70240
bl __panic
L10324:
L10293:
ldr x19, [x29, #88]
ldr x20, [x29, #24]
ldr x21, [x29, #144]
ldr x22, [x29, #192]
ldr x23, [x29, #168]
ldr x24, [x29, #96]
ldr x25, [x29, #64]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000208
ret
.align 32
Game__art:
sub sp, sp, #0000208
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #88]
str x20, [x29, #96]
str x21, [x29, #112]
str x22, [x29, #136]
str x23, [x29, #128]
str x24, [x29, #56]
str x25, [x29, #64]
str x0, [x29, #16]
str x1, [x29, #24]
str x2, [x29, #32]
str x3, [x29, #40]
str x4, [x29, #48]
mov x24, 0
mov x25, 0
mov x0, 0
str x0, [x29, #72]
mov x0, x3
cmp x3, 0
b.ne L10340
add x0, x28, #70240
bl __panic
L10340:
ldr x0, [x0, #0]
str x0, [x29, #80]
L10341:
ldr x0, [x29, #72]
ldr x1, [x29, #80]
cmp x0, x1
b.ge L10384
ldr x0, [x29, #40]
cmp x0, 0
b.eq L10388
mov x8, x0
ldr x0, [x29, #72]
ldr x1, [x8, #16]
add x0, x0, x1
ldrb x0, [x0, #0]
and x0, x0, #255
mov x19, x0
cmp x0, 10
b.eq L10345
cmp x0, 46
b.ne L10349
L10381:
add x25, x25, #1
L10382:
ldr x0, [x29, #72]
add x0, x0, #1
str x0, [x29, #72]
b L10341
L10345:
add x24, x24, #1
mov x25, 0
b L10382
L10349:
cmp x0, 32
b.eq L10381
mov x20, 0
L10351:
mov x1, 7
add x8, x20, #7
ldr x0, [x29, #48]
cmp x0, 0
b.eq L10391
ldr x0, [x0, #0]
mov x1, x0
cmp x8, x0
b.gt L10381
ldr x0, [x29, #48]
cmp x0, 0
b.eq L10394
mov x8, x0
mov x0, x20
ldr x1, [x8, #16]
add x0, x0, x1
ldrb x0, [x0, #0]
and x0, x0, #255
cmp x0, x19
b.eq L10357
add x20, x20, #7
b L10351
L10357:
mov x19, 0
mov x21, 0
L10358:
mov x1, 6
cmp x21, 6
b.lt L10359
ldr x8, [x29, #16]
ldr x0, [x29, #24]
add x0, x0, x25
str x0, [x29, #192]
ldr x0, [x29, #32]
add x0, x0, x24
str x0, [x29, #184]
mov x0, x19
ldr x1, [x29, #192]
ldr x2, [x29, #184]
mov x3, x0
mov x23, x8
str x1, [x29, #152]
str x2, [x29, #160]
str x0, [x29, #168]
cmp x1, 0
b.lt L10381
cmp x2, 0
b.lt L10381
ldr x0, [x8, #0]
cmp x1, x0
b.ge L10381
ldr x0, [x23, #8]
mov x1, x0
cmp x2, x0
b.ge L10381
ldr x0, [x23, #32]
cmp x0, 0
b.eq L10412
mov x8, x0
ldr x9, [x29, #160]
ldr x0, [x23, #0]
mul x0, x9, x0
ldr x1, [x29, #152]
add x0, x0, x1
lsl x0, x0, #3
ldr x1, [x8, #16]
add x8, x0, x1
ldr x0, [x29, #168]
str x0, [x8, #0]
b L10381
L10359:
ldr x0, [x29, #48]
cmp x0, 0
b.eq L10397
mov x8, x0
add x0, x20, #2
add x0, x0, x21
ldr x1, [x8, #16]
add x0, x0, x1
ldrb x0, [x0, #0]
and x23, x0, #255
mov x22, 0
mov x0, x23
cmp x0, 48
b.ge L10362
L10364:
cmp x23, 97
b.ge L10365
L10367:
cmp x23, 65
b.ge L10368
L10373:
mov x1, 16
mul x0, x19, x1
add x19, x0, x22
add x21, x21, #1
b L10358
L10362:
cmp x0, 57
b.gt L10364
sub x22, x0, #48
b L10373
L10365:
mov x0, x23
cmp x0, 102
b.gt L10367
sub x22, x0, #87
b L10373
L10368:
mov x0, x23
cmp x0, 70
b.gt L10373
sub x22, x0, #55
b L10373
L10388:
add x0, x28, #70240
bl __panic
L10391:
add x0, x28, #70240
bl __panic
L10394:
add x0, x28, #70240
bl __panic
L10397:
add x0, x28, #70240
bl __panic
L10412:
add x0, x28, #70240
bl __panic
L10384:
L10337:
ldr x19, [x29, #88]
ldr x20, [x29, #96]
ldr x21, [x29, #112]
ldr x22, [x29, #136]
ldr x23, [x29, #128]
ldr x24, [x29, #56]
ldr x25, [x29, #64]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000208
ret
.align 32
Game__overlap:
sub sp, sp, #0000080
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #48]
str x20, [x29, #56]
mov x9, x0
mov x18, x1
mov x19, x4
mov x20, x5
mov x8, x0
add x0, x4, x6
cmp x8, x0
b.lt L10417
L10421:
mov x0, 0
b L10423
L10417:
add x0, x9, x2
cmp x19, x0
b.ge L10421
add x0, x5, x7
cmp x18, x0
b.ge L10421
add x0, x18, x3
cmp x20, x0
b.ge L10421
mov x0, 1
L10423:
L10415:
ldr x19, [x29, #48]
ldr x20, [x29, #56]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000080
ret
.align 32
Game__end:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #16]
mov x19, x0
ldr x0, [x28, #75136]
cmp x0, 0
b.ne L10426
L10428:
mov x8, x19
ldr x0, [x19, #72]
add x0, x0, #1
str x0, [x8, #72]
ldr x0, [x19, #96]
cmp x0, 0
b.gt L10429
L10432:
bl Time__now_ms
mov x8, x0
ldr x0, [x19, #80]
sub x0, x8, x0
mov x9, x0
mov x8, x0
ldr x1, [x19, #88]
cmp x8, x1
b.ge L10437
ldr x0, [x28, #75136]
cmp x0, 0
b.eq L10437
ldr x0, [x19, #88]
mov x1, x9
sub x0, x0, x1
bl Time__sleep_ms
b L10437
L10426:
mov x0, x19
bl Game__present
b L10428
L10429:
ldr x8, [x19, #72]
ldr x0, [x19, #96]
cmp x8, x0
b.lt L10432
mov x0, 0
str x0, [x19, #64]
b L10432
L10437:
L10424:
ldr x19, [x29, #16]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
Game__present:
sub sp, sp, #0000912
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #128]
str x20, [x29, #896]
str x21, [x29, #72]
str x22, [x29, #784]
str x23, [x29, #136]
str x24, [x29, #96]
str x25, [x29, #112]
str x0, [x29, #16]
add x0, x28, #75536
bl __Str__from
str x0, [x29, #24]
add x1, x29, #32
ldr x2, [x27, #784]
str x2, [x29, #32]
add x2, x29, #24
str x2, [x29, #40]
adr x2, __Arr__free
str x2, [x29, #48]
mov x2, 0
str x2, [x29, #56]
str x1, [x27, #784]
mov x0, -5
str x0, [x29, #64]
mov x0, -5
mov x21, x0
mov x0, -1
str x0, [x29, #80]
mov x0, -1
str x0, [x29, #88]
mov x24, 0
ldr x0, [x29, #16]
ldr x0, [x0, #24]
str x0, [x29, #104]
L10440:
mov x0, x24
ldr x1, [x29, #104]
cmp x0, x1
b.ge L10474
mov x25, 0
ldr x0, [x29, #16]
ldr x0, [x0, #0]
str x0, [x29, #120]
mov x0, 2
mov x1, x24
mul x0, x0, x1
str x0, [x29, #776]
mov x0, 2
mul x0, x0, x1
str x0, [x29, #768]
mov x0, 2
mul x0, x0, x1
str x0, [x29, #760]
mov x0, 2
mul x0, x0, x1
str x0, [x29, #752]
mov x0, 2
mul x0, x0, x1
str x0, [x29, #744]
mov x0, 2
mul x0, x0, x1
str x0, [x29, #736]
L10442:
mov x0, x25
ldr x1, [x29, #120]
cmp x0, x1
b.lt L10443
add x24, x24, #1
b L10440
L10443:
ldr x0, [x29, #16]
ldr x0, [x0, #32]
cmp x0, 0
b.eq L10483
mov x8, x0
ldr x9, [x29, #776]
ldr x0, [x29, #16]
ldr x0, [x0, #0]
mul x0, x9, x0
add x0, x0, x25
lsl x0, x0, #3
ldr x1, [x8, #16]
add x0, x0, x1
ldr x19, [x0, #0]
ldr x0, [x29, #16]
ldr x0, [x0, #32]
cmp x0, 0
b.eq L10486
mov x8, x0
ldr x0, [x29, #768]
add x9, x0, #1
ldr x0, [x29, #16]
ldr x0, [x0, #0]
mul x0, x9, x0
add x0, x0, x25
lsl x0, x0, #3
ldr x1, [x8, #16]
add x0, x0, x1
ldr x23, [x0, #0]
ldr x0, [x29, #16]
ldr x0, [x0, #40]
cmp x0, 0
b.eq L10489
mov x8, x0
ldr x9, [x29, #760]
ldr x0, [x29, #16]
ldr x0, [x0, #0]
mul x0, x9, x0
add x0, x0, x25
lsl x0, x0, #3
ldr x1, [x8, #16]
add x0, x0, x1
ldr x0, [x0, #0]
str x0, [x29, #144]
ldr x0, [x29, #16]
ldr x0, [x0, #40]
cmp x0, 0
b.eq L10492
mov x8, x0
ldr x0, [x29, #752]
add x9, x0, #1
ldr x0, [x29, #16]
ldr x0, [x0, #0]
mul x0, x9, x0
add x0, x0, x25
lsl x0, x0, #3
ldr x1, [x8, #16]
add x0, x0, x1
ldr x0, [x0, #0]
str x0, [x29, #152]
mov x0, x19
ldr x1, [x29, #144]
cmp x0, x1
b.eq L10452
L10456:
ldr x0, [x29, #16]
ldr x0, [x0, #40]
cmp x0, 0
b.eq L10495
mov x8, x0
ldr x9, [x29, #744]
ldr x0, [x29, #16]
ldr x0, [x0, #0]
mul x0, x9, x0
add x0, x0, x25
lsl x0, x0, #3
ldr x1, [x8, #16]
add x8, x0, x1
mov x1, x8
str x19, [x8, #0]
ldr x0, [x29, #16]
ldr x0, [x0, #40]
cmp x0, 0
b.eq L10498
mov x8, x0
ldr x0, [x29, #736]
add x9, x0, #1
ldr x0, [x29, #16]
ldr x0, [x0, #0]
mul x0, x9, x0
add x0, x0, x25
lsl x0, x0, #3
ldr x1, [x8, #16]
add x8, x0, x1
str x23, [x8, #0]
cmp x21, x24
b.ne L10462
ldr x8, [x29, #64]
sub x0, x25, #1
cmp x8, x0
b.ne L10462
L10464:
ldr x0, [x29, #80]
cmp x0, x19
b.ne L10465
L10467:
ldr x0, [x29, #88]
cmp x0, x23
b.ne L10468
L10470:
ldr x20, [x29, #24]
add x1, x28, #75632
mov x0, x20
mov x2, 0
bl __Str__append
mov x21, x24
str x25, [x29, #64]
L10471:
add x25, x25, #1
b L10442
L10452:
mov x0, x23
ldr x1, [x29, #152]
cmp x0, x1
b.eq L10471
b L10456
L10462:
ldr x20, [x29, #24]
add x1, x28, #75544
mov x0, x20
mov x2, 0
bl __Str__append
ldr x20, [x29, #24]
add x21, x24, #1
mov x22, 1
mov x1, 25
mov x0, 1
bl __Arr__make
str x0, [x29, #680]
add x1, x29, #688
ldr x2, [x27, #784]
str x2, [x29, #688]
add x2, x29, #680
str x2, [x29, #696]
adr x2, __Arr__free
str x2, [x29, #704]
mov x2, 0
str x2, [x29, #712]
str x1, [x27, #784]
ldr x0, [x29, #680]
ldr x0, [x0, #16]
mov x3, x0
mov x1, 0
strb x1, [x0, #0]
ldr x22, [x29, #680]
mov x1, 0
str x1, [x29, #680]
ldr x0, [x29, #680]
bl Mem__free
ldr x1, [x29, #688]
str x1, [x27, #784]
str x22, [x29, #496]
add x1, x29, #504
ldr x2, [x27, #784]
str x2, [x29, #504]
add x2, x29, #496
str x2, [x29, #512]
adr x2, __Arr__free
str x2, [x29, #520]
mov x2, 0
str x2, [x29, #528]
str x1, [x27, #784]
ldr x22, [x29, #496]
mov x2, 0
mov x1, x21
mov x0, x22
bl __Str__push_int
ldr x22, [x29, #496]
mov x1, 0
str x1, [x29, #496]
ldr x0, [x29, #496]
bl Mem__free
ldr x1, [x29, #504]
str x1, [x27, #784]
mov x0, x22
str x0, [x29, #160]
add x1, x29, #168
ldr x2, [x27, #784]
str x2, [x29, #168]
add x2, x29, #160
str x2, [x29, #176]
adr x2, __Arr__free
str x2, [x29, #184]
mov x2, 0
str x2, [x29, #192]
str x1, [x27, #784]
mov x1, x0
mov x0, x20
mov x2, 1
bl __Str__append
ldr x0, [x29, #160]
bl __Arr__free
ldr x1, [x29, #168]
str x1, [x27, #784]
ldr x20, [x29, #24]
add x1, x28, #75552
mov x0, x20
mov x2, 0
bl __Str__append
ldr x20, [x29, #24]
add x0, x25, #1
mov x1, 0
bl __Str__from_int
str x0, [x29, #200]
add x1, x29, #208
ldr x2, [x27, #784]
str x2, [x29, #208]
add x2, x29, #200
str x2, [x29, #216]
adr x2, __Arr__free
str x2, [x29, #224]
mov x2, 0
str x2, [x29, #232]
str x1, [x27, #784]
mov x1, x0
mov x0, x20
mov x2, 1
bl __Str__append
ldr x0, [x29, #200]
bl __Arr__free
ldr x1, [x29, #208]
str x1, [x27, #784]
ldr x20, [x29, #24]
add x1, x28, #75560
mov x0, x20
mov x2, 0
bl __Str__append
b L10464
L10465:
ldr x20, [x29, #24]
add x1, x28, #75568
mov x0, x20
mov x2, 0
bl __Str__append
ldr x20, [x29, #24]
asr x0, x19, #16
and x0, x0, #255
mov x1, 0
mov x21, x0
mov x0, 24
bl __Str__make
str x0, [x29, #560]
add x1, x29, #568
ldr x2, [x27, #784]
str x2, [x29, #568]
add x2, x29, #560
str x2, [x29, #576]
adr x2, __Arr__free
str x2, [x29, #584]
mov x2, 0
str x2, [x29, #592]
str x1, [x27, #784]
ldr x22, [x29, #560]
mov x2, 0
mov x1, x21
mov x0, x22
bl __Str__push_int
ldr x22, [x29, #560]
mov x1, 0
str x1, [x29, #560]
ldr x0, [x29, #560]
bl Mem__free
ldr x1, [x29, #568]
str x1, [x27, #784]
mov x0, x22
str x0, [x29, #240]
add x1, x29, #248
ldr x2, [x27, #784]
str x2, [x29, #248]
add x2, x29, #240
str x2, [x29, #256]
adr x2, __Arr__free
str x2, [x29, #264]
mov x2, 0
str x2, [x29, #272]
str x1, [x27, #784]
mov x1, x0
mov x0, x20
mov x2, 1
bl __Str__append
ldr x0, [x29, #240]
bl __Arr__free
ldr x1, [x29, #248]
str x1, [x27, #784]
ldr x20, [x29, #24]
add x1, x28, #75576
mov x0, x20
mov x2, 0
bl __Str__append
ldr x20, [x29, #24]
asr x0, x19, #8
and x0, x0, #255
mov x1, 0
bl __Str__from_int
str x0, [x29, #280]
add x1, x29, #288
ldr x2, [x27, #784]
str x2, [x29, #288]
add x2, x29, #280
str x2, [x29, #296]
adr x2, __Arr__free
str x2, [x29, #304]
mov x2, 0
str x2, [x29, #312]
str x1, [x27, #784]
mov x1, x0
mov x0, x20
mov x2, 1
bl __Str__append
ldr x0, [x29, #280]
bl __Arr__free
ldr x1, [x29, #288]
str x1, [x27, #784]
ldr x20, [x29, #24]
add x1, x28, #75584
mov x0, x20
mov x2, 0
bl __Str__append
ldr x20, [x29, #24]
and x0, x19, #255
mov x1, 0
bl __Str__from_int
str x0, [x29, #320]
add x1, x29, #328
ldr x2, [x27, #784]
str x2, [x29, #328]
add x2, x29, #320
str x2, [x29, #336]
adr x2, __Arr__free
str x2, [x29, #344]
mov x2, 0
str x2, [x29, #352]
str x1, [x27, #784]
mov x1, x0
mov x0, x20
mov x2, 1
bl __Str__append
ldr x0, [x29, #320]
bl __Arr__free
ldr x1, [x29, #328]
str x1, [x27, #784]
ldr x20, [x29, #24]
add x1, x28, #75592
mov x0, x20
mov x2, 0
bl __Str__append
str x19, [x29, #80]
b L10467
L10468:
ldr x20, [x29, #24]
add x1, x28, #75600
mov x0, x20
mov x2, 0
bl __Str__append
ldr x20, [x29, #24]
asr x0, x23, #16
and x0, x0, #255
mov x1, 0
mov x19, x0
mov x0, 24
bl __Str__make
str x0, [x29, #624]
add x1, x29, #632
ldr x2, [x27, #784]
str x2, [x29, #632]
add x2, x29, #624
str x2, [x29, #640]
adr x2, __Arr__free
str x2, [x29, #648]
mov x2, 0
str x2, [x29, #656]
str x1, [x27, #784]
ldr x21, [x29, #624]
mov x2, 0
mov x1, x19
mov x0, x21
bl __Str__push_int
ldr x21, [x29, #624]
mov x1, 0
str x1, [x29, #624]
ldr x0, [x29, #624]
bl Mem__free
ldr x1, [x29, #632]
str x1, [x27, #784]
mov x0, x21
str x0, [x29, #360]
add x1, x29, #368
ldr x2, [x27, #784]
str x2, [x29, #368]
add x2, x29, #360
str x2, [x29, #376]
adr x2, __Arr__free
str x2, [x29, #384]
mov x2, 0
str x2, [x29, #392]
str x1, [x27, #784]
mov x1, x0
mov x0, x20
mov x2, 1
bl __Str__append
ldr x0, [x29, #360]
bl __Arr__free
ldr x1, [x29, #368]
str x1, [x27, #784]
ldr x20, [x29, #24]
add x1, x28, #75608
mov x0, x20
mov x2, 0
bl __Str__append
ldr x20, [x29, #24]
asr x0, x23, #8
and x0, x0, #255
mov x1, 0
bl __Str__from_int
str x0, [x29, #400]
add x1, x29, #408
ldr x2, [x27, #784]
str x2, [x29, #408]
add x2, x29, #400
str x2, [x29, #416]
adr x2, __Arr__free
str x2, [x29, #424]
mov x2, 0
str x2, [x29, #432]
str x1, [x27, #784]
mov x1, x0
mov x0, x20
mov x2, 1
bl __Str__append
ldr x0, [x29, #400]
bl __Arr__free
ldr x1, [x29, #408]
str x1, [x27, #784]
ldr x20, [x29, #24]
add x1, x28, #75616
mov x0, x20
mov x2, 0
bl __Str__append
ldr x20, [x29, #24]
and x0, x23, #255
mov x1, 0
bl __Str__from_int
str x0, [x29, #440]
add x1, x29, #448
ldr x2, [x27, #784]
str x2, [x29, #448]
add x2, x29, #440
str x2, [x29, #456]
adr x2, __Arr__free
str x2, [x29, #464]
mov x2, 0
str x2, [x29, #472]
str x1, [x27, #784]
mov x1, x0
mov x0, x20
mov x2, 1
bl __Str__append
ldr x0, [x29, #440]
bl __Arr__free
ldr x1, [x29, #448]
str x1, [x27, #784]
ldr x20, [x29, #24]
add x1, x28, #75624
mov x0, x20
mov x2, 0
bl __Str__append
str x23, [x29, #88]
b L10470
L10474:
ldr x0, [x29, #24]
cmp x0, 0
b.ne L10476
add x0, x28, #70240
bl __panic
L10476:
ldr x0, [x0, #0]
cmp x0, 0
b.gt L10477
L10481:
ldr x0, [x29, #24]
bl __Arr__free
ldr x1, [x29, #32]
str x1, [x27, #784]
b L10482
L10477:
ldr x20, [x29, #24]
add x1, x28, #75640
mov x0, x20
mov x2, 0
bl __Str__append
ldr x0, [x29, #24]
cmp x0, 0
b.ne L10479
add x0, x28, #70240
bl __panic
L10479:
ldr x0, [x0, #16]
bl j2k_print_str
b L10481
L10483:
add x0, x28, #70240
bl __panic
L10486:
add x0, x28, #70240
bl __panic
L10489:
add x0, x28, #70240
bl __panic
L10492:
add x0, x28, #70240
bl __panic
L10495:
add x0, x28, #70240
bl __panic
L10498:
add x0, x28, #70240
bl __panic
L10482:
L10438:
ldr x19, [x29, #128]
ldr x20, [x29, #896]
ldr x21, [x29, #72]
ldr x22, [x29, #784]
ldr x23, [x29, #136]
ldr x24, [x29, #96]
ldr x25, [x29, #112]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000912
ret
.align 32
main:
sub sp, sp, #0000800
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
add x23, x29, #16
add x0, x28, #75648
bl __Str__from
str x0, [x29, #136]
add x1, x29, #144
ldr x2, [x27, #784]
str x2, [x29, #144]
add x2, x29, #136
str x2, [x29, #152]
adr x2, __Arr__free
str x2, [x29, #160]
mov x2, 0
str x2, [x29, #168]
str x1, [x27, #784]
mov x24, x0
mov x0, x23
mov x1, x24
bl Game__open
ldr x1, [x29, #16]
str x1, [x29, #176]
ldr x1, [x29, #24]
str x1, [x29, #184]
ldr x1, [x29, #32]
str x1, [x29, #192]
ldr x1, [x29, #40]
str x1, [x29, #200]
ldr x1, [x29, #48]
str x1, [x29, #208]
ldr x1, [x29, #56]
str x1, [x29, #216]
ldr x1, [x29, #64]
str x1, [x29, #224]
ldr x1, [x29, #72]
str x1, [x29, #232]
ldr x1, [x29, #80]
str x1, [x29, #240]
ldr x1, [x29, #88]
str x1, [x29, #248]
ldr x1, [x29, #96]
str x1, [x29, #256]
ldr x1, [x29, #104]
str x1, [x29, #264]
ldr x1, [x29, #112]
str x1, [x29, #272]
ldr x1, [x29, #120]
str x1, [x29, #280]
ldr x1, [x29, #128]
str x1, [x29, #288]
ldr x0, [x29, #136]
bl __Arr__free
ldr x1, [x29, #144]
str x1, [x27, #784]
fmovi d0, 52
fmov d8, d0
fmovi d0, 36
fmov d9, d0
fmovi d0, 62
fmov d10, d0
fmovi d0, 49
fmov d11, d0
mov x25, 10
mov x0, 0
str x0, [x29, #336]
mov x16, 660510
str x16, [x29, #720]
L10526:
add x23, x29, #176
ldr x0, [x29, #240]
cmp x0, 0
b.eq L10555
add x0, x29, #176
mov x23, x0
bl Game__begin
add x23, x29, #176
mov x24, 257
add x0, x29, #176
mov x1, 257
str x0, [x29, #656]
str x1, [x29, #664]
bl Time__now_ms
mov x8, x0
ldr x0, [x29, #656]
ldr x0, [x0, #48]
cmp x0, 0
b.ne L10602
bl __Arr__nullerr
L10602:
mov x9, x0
ldr x0, [x29, #664]
lsl x0, x0, #3
ldr x1, [x9, #16]
add x0, x0, x1
ldr x0, [x0, #0]
sub x0, x8, x0
cmp x0, 180
b.lt L10529
add x23, x29, #176
mov x24, 119
mov x1, 119
str x1, [x29, #536]
ldr x0, [x29, #232]
cmp x0, 0
b.eq L10608
mov x8, x0
ldr x0, [x29, #536]
lsl x0, x0, #3
ldr x1, [x8, #16]
add x0, x0, x1
ldr x0, [x0, #0]
cmp x0, 1
b.eq L10529
L10531:
add x23, x29, #176
mov x24, 258
add x0, x29, #176
mov x1, 258
str x0, [x29, #672]
str x1, [x29, #680]
bl Time__now_ms
mov x8, x0
ldr x0, [x29, #672]
ldr x0, [x0, #48]
cmp x0, 0
b.ne L10615
bl __Arr__nullerr
L10615:
mov x9, x0
ldr x0, [x29, #680]
lsl x0, x0, #3
ldr x1, [x9, #16]
add x0, x0, x1
ldr x0, [x0, #0]
sub x0, x8, x0
cmp x0, 180
b.lt L10533
add x23, x29, #176
mov x24, 115
mov x1, 115
str x1, [x29, #552]
ldr x0, [x29, #232]
cmp x0, 0
b.eq L10621
mov x8, x0
ldr x0, [x29, #552]
lsl x0, x0, #3
ldr x1, [x8, #16]
add x0, x0, x1
ldr x0, [x0, #0]
cmp x0, 1
b.eq L10533
L10535:
cmp x25, 0
b.lt L10536
L10538:
mov x8, x25
ldr x0, [x29, #184]
sub x0, x0, #12
cmp x8, x0
b.gt L10539
L10541:
ldr d0, [x29, #280]
fmadd d0, d10, d0, d8
fmov d8, d0
fmov d23, d9
fmov d22, d11
ldr d0, [x29, #280]
fmadd d0, d22, d0, d23
fmov d9, d0
fmovi d1, 112
fcmp d0, d1
b.mi L10543
fmov d24, d0
ldr x0, [x29, #184]
sub x0, x0, #2
scvtf d0, x0
fcmp d24, d0
b.gt L10543
L10545:
ldr x0, [x29, #176]
sub x0, x0, #2
scvtf d0, x0
fcmp d8, d0
b.gt L10546
L10548:
mov x24, x25
fcvtzs x19, d8
fmov d28, d9
fcvtzs x0, d28
mov x21, x0
mov x1, x24
mov x4, x19
mov x5, x0
add x0, x4, #2
cmp x0, 2
b.gt L10587
L10551:
fmov d29, d8
mov x17, 0
fmov d1, x17
fcmp d29, d1
b.mi L10552
L10554:
add x23, x29, #176
mov x22, 20
mov x20, 30
ldr x24, [x29, #720]
add x0, x29, #176
mov x1, x24
str x0, [x29, #688]
str x1, [x29, #696]
mov x0, 0
str x0, [x29, #704]
ldr x8, [x29, #176]
ldr x0, [x29, #184]
mul x0, x8, x0
str x0, [x29, #712]
L10625:
ldr x0, [x29, #704]
ldr x1, [x29, #712]
cmp x0, x1
b.lt L10626
add x23, x29, #176
mov x24, 2
mov x22, x25
mov x20, 2
mov x19, 12
mov x21, 255
mov x0, 255
mov x1, 255
mov x2, 255
bl Game__rgb
mov x5, x0
mov x0, x23
mov x1, 2
mov x2, x22
mov x3, 2
mov x4, 12
bl Game__rect
add x23, x29, #176
fcvtzs x24, d8
fcvtzs x22, d9
mov x20, 1
mov x19, 255
mov x21, 200
mov x0, 255
mov x1, 200
mov x2, 60
bl Game__rgb
mov x4, x0
mov x0, x23
mov x1, x24
mov x2, x22
mov x3, 1
bl Game__circle
add x23, x29, #176
mov x24, 2
mov x22, 1
add x20, x28, #75656
ldr x0, [x29, #336]
mov x1, 0
bl __Str__from_int
str x0, [x29, #344]
add x1, x29, #352
ldr x2, [x27, #784]
str x2, [x29, #352]
add x2, x29, #344
str x2, [x29, #360]
adr x2, __Arr__free
str x2, [x29, #368]
mov x2, 0
str x2, [x29, #376]
str x1, [x27, #784]
mov x2, x0
mov x0, x20
mov x1, 0
mov x3, 1
bl __Str__cat
str x0, [x29, #384]
add x1, x29, #392
ldr x2, [x27, #784]
str x2, [x29, #392]
add x2, x29, #384
str x2, [x29, #400]
adr x2, __Arr__free
str x2, [x29, #408]
mov x2, 0
str x2, [x29, #416]
str x1, [x27, #784]
mov x20, x0
mov x19, 120
mov x21, 220
mov x0, 120
mov x1, 220
mov x2, 255
bl Game__rgb
mov x4, x0
mov x0, x23
mov x1, 2
mov x2, 1
mov x3, x20
bl Game__text
ldr x0, [x29, #384]
bl __Arr__free
ldr x0, [x29, #344]
bl __Arr__free
ldr x1, [x29, #352]
str x1, [x27, #784]
add x23, x29, #176
ldr x0, [x29, #176]
sub x24, x0, #8
mov x22, 3
add x0, x28, #75664
bl __Str__from
str x0, [x29, #424]
add x1, x29, #432
ldr x2, [x27, #784]
str x2, [x29, #432]
add x2, x29, #424
str x2, [x29, #440]
adr x2, __Arr__free
str x2, [x29, #448]
mov x2, 0
str x2, [x29, #456]
str x1, [x27, #784]
mov x20, x0
add x0, x28, #75680
bl __Str__from
str x0, [x29, #464]
add x1, x29, #472
ldr x2, [x27, #784]
str x2, [x29, #472]
add x2, x29, #464
str x2, [x29, #480]
adr x2, __Arr__free
str x2, [x29, #488]
mov x2, 0
str x2, [x29, #496]
str x1, [x27, #784]
mov x4, x0
mov x0, x23
mov x1, x24
mov x2, 3
mov x3, x20
bl Game__art
ldr x0, [x29, #464]
bl __Arr__free
ldr x0, [x29, #424]
bl __Arr__free
ldr x1, [x29, #432]
str x1, [x27, #784]
add x23, x29, #176
mov x24, 0
ldr x0, [x29, #184]
sub x22, x0, #1
ldr x0, [x29, #176]
sub x20, x0, #1
ldr x0, [x29, #184]
sub x19, x0, #1
mov x21, 80
mov x0, 80
mov x1, 80
mov x2, 80
bl Game__rgb
mov x21, x0
mov x0, x23
mov x1, 0
mov x2, x22
mov x3, x20
mov x4, x19
mov x5, x21
bl Game__line
add x0, x29, #176
mov x23, x0
bl Game__end
b L10526
L10529:
sub x25, x25, #2
b L10531
L10533:
add x25, x25, #2
b L10535
L10536:
mov x25, 0
b L10538
L10539:
ldr x0, [x29, #184]
sub x25, x0, #12
b L10541
L10543:
mov x17, 0
fmov d0, x17
fsub d11, d0, d11
b L10545
L10546:
mov x17, 0
fmov d0, x17
fsub d0, d0, d10
fmov d10, d0
b L10548
L10549:
mov x17, 0
fmov d0, x17
fsub d0, d0, d10
fmov d10, d0
ldr x0, [x29, #336]
add x0, x0, #1
str x0, [x29, #336]
fmovi d0, 20
fmov d8, d0
b L10551
L10552:
fmovi d0, 52
fmov d8, d0
mov x0, 0
str x0, [x29, #336]
b L10554
L10555:
add x0, x29, #176
mov x23, x0
bl Game__close
mov x0, 0
b L10556
L10587:
cmp x4, 4
b.ge L10551
add x0, x5, #2
cmp x1, x0
b.ge L10551
add x0, x1, #12
cmp x5, x0
b.lt L10549
b L10551
L10608:
add x0, x28, #70240
bl __panic
L10621:
add x0, x28, #70240
bl __panic
L10626:
ldr x0, [x29, #688]
ldr x0, [x0, #32]
cmp x0, 0
b.ne L10628
bl __Arr__nullerr
L10628:
mov x8, x0
ldr x0, [x29, #704]
lsl x0, x0, #3
ldr x1, [x8, #16]
add x8, x0, x1
ldr x0, [x29, #696]
str x0, [x8, #0]
ldr x0, [x29, #704]
add x0, x0, #1
str x0, [x29, #704]
b L10625
L10556:
mov x23, x0
bl __flush
mov x0, 0
mov x8, 94
svc 0
j2k_noret:
mov x0, x28
add x0, x0, #75696
b __panic
.align 32
j2k_segv:
sub sp, sp, #128
bl __flush
mov x3, 2334392281553859954
str x3, [sp, #0]
mov x3, 8295694776786907749
str x3, [sp, #8]
mov x3, 8386111998637467493
str x3, [sp, #16]
mov x3, 7815259819630030697
str x3, [sp, #24]
mov x3, 2336361558313541748
str x3, [sp, #32]
mov x3, 3202733835756859248
str x3, [sp, #40]
mov x3, 8007518212045697824
str x3, [sp, #48]
mov x3, 3204152171263321462
str x3, [sp, #56]
mov x3, 8248096844080639776
str x3, [sp, #64]
mov x3, 8223695464128935017
str x3, [sp, #72]
mov x3, 8749489599856009573
str x3, [sp, #80]
mov x3, 2860248308212768
str x3, [sp, #88]
mov x0, 2
add x1, sp, #0
mov x2, 95
mov x8, 64
svc 0
mov x0, 139
mov x8, 94
svc 0
j2k_try_enter:
ldr x1, [x27, #8]
cmp x1, 24
b.ge j2k_exc_full
mov x2, 32
mul x2, x1, x2
add x3, x27, #0
add x3, x3, x2
add x4, sp, #0
str x4, [x3, #16]
str x29, [x3, #24]
str x30, [x3, #32]
ldr x4, [x27, #784]
str x4, [x3, #40]
add x1, x1, #1
str x1, [x27, #8]
mov x0, 0
ret
j2k_exc_full:
mov x0, 2
mov x8, 94
svc 0
j2k_try_leave:
ldr x1, [x27, #8]
sub x1, x1, #1
str x1, [x27, #8]
ret
j2k_throw:
str x0, [x27, #0]
ldr x1, [x27, #8]
cmp x1, 0
b.eq j2k_uncaught
sub x1, x1, #1
str x1, [x27, #8]
mov x2, 32
mul x2, x1, x2
add x3, x27, #0
add x3, x3, x2
sub sp, sp, #16
str x3, [sp, #0]
ldr x9, [x3, #40]
str x9, [sp, #8]
j2k_th1:
ldr x5, [x27, #784]
ldr x9, [sp, #8]
cmp x5, x9
b.eq j2k_th3
cmp x5, 0
b.eq j2k_th3
ldr x6, [x5, #0]
str x6, [x27, #784]
ldr x7, [x5, #8]
ldr x8, [x5, #16]
ldr x10, [x5, #24]
mov x0, x7
cmp x10, 0
b.ne j2k_th2
ldr x0, [x7, #0]
j2k_th2:
cmp x10, 2
b.ne j2k_th4
mov x29, x7
j2k_th4:
blr x8
b j2k_th1
j2k_th3:
ldr x3, [sp, #0]
add sp, sp, #16
ldr x4, [x3, #16]
ldr x29, [x3, #24]
ldr x30, [x3, #32]
add sp, x4, #0
mov x0, 1
ret
.align 32
j2k_uncaught:
sub sp, sp, #16
stp x0, x1, [sp, #0]
bl __flush
ldp x0, x1, [sp, #0]
add sp, sp, #16
mov x6, x0
sub sp, sp, #64
mov x3, 8388068059820289653
str x3, [sp, #0]
mov x3, 7598822052043711776
str x3, [sp, #8]
mov x3, 540700271
str x3, [sp, #16]
mov x0, 2
add x1, sp, #0
mov x2, 20
mov x8, 64
svc 0
mov x2, 0
j2k_unc1:
add x3, x6, x2
ldrb x4, [x3, #0]
cmp x4, 0
b.eq j2k_unc2
add x2, x2, #1
b j2k_unc1
j2k_unc2:
mov x0, 2
mov x1, x6
mov x8, 64
svc 0
mov x4, 10
strb x4, [sp, #0]
mov x0, 2
add x1, sp, #0
mov x2, 1
mov x8, 64
svc 0
mov x0, 1
mov x8, 94
svc 0
j2k_start:
mov x28, 268435456
add x27, x28, #72
add x9, sp, #0
str x9, [x28, #0]
sub sp, sp, #64
adr x0, j2k_segv
str x0, [sp, #0]
mov x0, 134217728
str x0, [sp, #8]
mov x0, 0
str x0, [sp, #16]
str x0, [sp, #24]
mov x0, 11
add x1, sp, #0
mov x2, 0
mov x3, 8
mov x8, 134
svc 0
mov x9, 75744
add x0, x28, x9
str x0, [sp, #32]
mov x0, 0
str x0, [sp, #40]
mov x0, 32768
str x0, [sp, #48]
add x0, sp, #32
mov x1, 0
mov x8, 132
svc 0
add sp, sp, #64
mov x9, 32
str x9, [x28, #67008]
mov x9, 48
str x9, [x28, #67016]
mov x9, 64
str x9, [x28, #67024]
mov x9, 80
str x9, [x28, #67032]
mov x9, 96
str x9, [x28, #67040]
mov x9, 112
str x9, [x28, #67048]
mov x9, 128
str x9, [x28, #67056]
mov x9, 160
str x9, [x28, #67064]
mov x9, 192
str x9, [x28, #67072]
mov x9, 224
str x9, [x28, #67080]
mov x9, 256
str x9, [x28, #67088]
mov x9, 320
str x9, [x28, #67096]
mov x9, 384
str x9, [x28, #67104]
mov x9, 448
str x9, [x28, #67112]
mov x9, 512
str x9, [x28, #67120]
mov x9, 640
str x9, [x28, #67128]
mov x9, 768
str x9, [x28, #67136]
mov x9, 896
str x9, [x28, #67144]
mov x9, 1024
str x9, [x28, #67152]
mov x9, 1280
str x9, [x28, #67160]
mov x9, 1536
str x9, [x28, #67168]
mov x9, 1792
str x9, [x28, #67176]
mov x9, 2048
str x9, [x28, #67184]
mov x9, 2048
str x9, [x28, #67192]
mov x9, 1
str x9, [x28, #67224]
mov x9, 2
str x9, [x28, #67232]
mov x9, 3
str x9, [x28, #67240]
mov x9, 4
str x9, [x28, #67248]
mov x9, 5
str x9, [x28, #67256]
mov x9, 6
str x9, [x28, #67264]
mov x9, 7
str x9, [x28, #67272]
mov x9, 7
str x9, [x28, #67280]
mov x9, 8
str x9, [x28, #67288]
mov x9, 8
str x9, [x28, #67296]
mov x9, 9
str x9, [x28, #67304]
mov x9, 9
str x9, [x28, #67312]
mov x9, 10
str x9, [x28, #67320]
mov x9, 10
str x9, [x28, #67328]
mov x9, 11
str x9, [x28, #67336]
mov x9, 11
str x9, [x28, #67344]
mov x9, 11
str x9, [x28, #67352]
mov x9, 11
str x9, [x28, #67360]
mov x9, 12
str x9, [x28, #67368]
mov x9, 12
str x9, [x28, #67376]
mov x9, 12
str x9, [x28, #67384]
mov x9, 12
str x9, [x28, #67392]
mov x9, 13
str x9, [x28, #67400]
mov x9, 13
str x9, [x28, #67408]
mov x9, 13
str x9, [x28, #67416]
mov x9, 13
str x9, [x28, #67424]
mov x9, 14
str x9, [x28, #67432]
mov x9, 14
str x9, [x28, #67440]
mov x9, 14
str x9, [x28, #67448]
mov x9, 14
str x9, [x28, #67456]
mov x9, 15
str x9, [x28, #67464]
mov x9, 15
str x9, [x28, #67472]
mov x9, 15
str x9, [x28, #67480]
mov x9, 15
str x9, [x28, #67488]
mov x9, 15
str x9, [x28, #67496]
mov x9, 15
str x9, [x28, #67504]
mov x9, 15
str x9, [x28, #67512]
mov x9, 15
str x9, [x28, #67520]
mov x9, 16
str x9, [x28, #67528]
mov x9, 16
str x9, [x28, #67536]
mov x9, 16
str x9, [x28, #67544]
mov x9, 16
str x9, [x28, #67552]
mov x9, 16
str x9, [x28, #67560]
mov x9, 16
str x9, [x28, #67568]
mov x9, 16
str x9, [x28, #67576]
mov x9, 16
str x9, [x28, #67584]
mov x9, 17
str x9, [x28, #67592]
mov x9, 17
str x9, [x28, #67600]
mov x9, 17
str x9, [x28, #67608]
mov x9, 17
str x9, [x28, #67616]
mov x9, 17
str x9, [x28, #67624]
mov x9, 17
str x9, [x28, #67632]
mov x9, 17
str x9, [x28, #67640]
mov x9, 17
str x9, [x28, #67648]
mov x9, 18
str x9, [x28, #67656]
mov x9, 18
str x9, [x28, #67664]
mov x9, 18
str x9, [x28, #67672]
mov x9, 18
str x9, [x28, #67680]
mov x9, 18
str x9, [x28, #67688]
mov x9, 18
str x9, [x28, #67696]
mov x9, 18
str x9, [x28, #67704]
mov x9, 18
str x9, [x28, #67712]
mov x9, 19
str x9, [x28, #67720]
mov x9, 19
str x9, [x28, #67728]
mov x9, 19
str x9, [x28, #67736]
mov x9, 19
str x9, [x28, #67744]
mov x9, 19
str x9, [x28, #67752]
mov x9, 19
str x9, [x28, #67760]
mov x9, 19
str x9, [x28, #67768]
mov x9, 19
str x9, [x28, #67776]
mov x9, 19
str x9, [x28, #67784]
mov x9, 19
str x9, [x28, #67792]
mov x9, 19
str x9, [x28, #67800]
mov x9, 19
str x9, [x28, #67808]
mov x9, 19
str x9, [x28, #67816]
mov x9, 19
str x9, [x28, #67824]
mov x9, 19
str x9, [x28, #67832]
mov x9, 19
str x9, [x28, #67840]
mov x9, 20
str x9, [x28, #67848]
mov x9, 20
str x9, [x28, #67856]
mov x9, 20
str x9, [x28, #67864]
mov x9, 20
str x9, [x28, #67872]
mov x9, 20
str x9, [x28, #67880]
mov x9, 20
str x9, [x28, #67888]
mov x9, 20
str x9, [x28, #67896]
mov x9, 20
str x9, [x28, #67904]
mov x9, 20
str x9, [x28, #67912]
mov x9, 20
str x9, [x28, #67920]
mov x9, 20
str x9, [x28, #67928]
mov x9, 20
str x9, [x28, #67936]
mov x9, 20
str x9, [x28, #67944]
mov x9, 20
str x9, [x28, #67952]
mov x9, 20
str x9, [x28, #67960]
mov x9, 20
str x9, [x28, #67968]
mov x9, 21
str x9, [x28, #67976]
mov x9, 21
str x9, [x28, #67984]
mov x9, 21
str x9, [x28, #67992]
mov x9, 21
str x9, [x28, #68000]
mov x9, 21
str x9, [x28, #68008]
mov x9, 21
str x9, [x28, #68016]
mov x9, 21
str x9, [x28, #68024]
mov x9, 21
str x9, [x28, #68032]
mov x9, 21
str x9, [x28, #68040]
mov x9, 21
str x9, [x28, #68048]
mov x9, 21
str x9, [x28, #68056]
mov x9, 21
str x9, [x28, #68064]
mov x9, 21
str x9, [x28, #68072]
mov x9, 21
str x9, [x28, #68080]
mov x9, 21
str x9, [x28, #68088]
mov x9, 21
str x9, [x28, #68096]
mov x9, 22
str x9, [x28, #68104]
mov x9, 22
str x9, [x28, #68112]
mov x9, 22
str x9, [x28, #68120]
mov x9, 22
str x9, [x28, #68128]
mov x9, 22
str x9, [x28, #68136]
mov x9, 22
str x9, [x28, #68144]
mov x9, 22
str x9, [x28, #68152]
mov x9, 22
str x9, [x28, #68160]
mov x9, 22
str x9, [x28, #68168]
mov x9, 22
str x9, [x28, #68176]
mov x9, 22
str x9, [x28, #68184]
mov x9, 22
str x9, [x28, #68192]
mov x9, 22
str x9, [x28, #68200]
mov x9, 22
str x9, [x28, #68208]
mov x9, 22
str x9, [x28, #68216]
mov x9, 22
str x9, [x28, #68224]
mov x9, -1
str x9, [x28, #68232]
mov x9, -1
str x9, [x28, #68240]
mov x9, 1
str x9, [x28, #68256]
mov x9, 2
str x9, [x28, #68264]
mov x9, 3
str x9, [x28, #68272]
mov x9, 4
str x9, [x28, #68280]
mov x9, 5
str x9, [x28, #68288]
mov x9, 6
str x9, [x28, #68296]
mov x9, -1
str x9, [x28, #68304]
mov x9, 7
str x9, [x28, #68312]
mov x9, -1
str x9, [x28, #68320]
mov x9, 8
str x9, [x28, #68328]
mov x9, -1
str x9, [x28, #68336]
mov x9, 9
str x9, [x28, #68344]
mov x9, -1
str x9, [x28, #68352]
mov x9, 10
str x9, [x28, #68360]
mov x9, -1
str x9, [x28, #68368]
mov x9, -1
str x9, [x28, #68376]
mov x9, -1
str x9, [x28, #68384]
mov x9, 11
str x9, [x28, #68392]
mov x9, -1
str x9, [x28, #68400]
mov x9, -1
str x9, [x28, #68408]
mov x9, -1
str x9, [x28, #68416]
mov x9, 12
str x9, [x28, #68424]
mov x9, -1
str x9, [x28, #68432]
mov x9, -1
str x9, [x28, #68440]
mov x9, -1
str x9, [x28, #68448]
mov x9, 13
str x9, [x28, #68456]
mov x9, -1
str x9, [x28, #68464]
mov x9, -1
str x9, [x28, #68472]
mov x9, -1
str x9, [x28, #68480]
mov x9, 14
str x9, [x28, #68488]
mov x9, -1
str x9, [x28, #68496]
mov x9, -1
str x9, [x28, #68504]
mov x9, -1
str x9, [x28, #68512]
mov x9, -1
str x9, [x28, #68520]
mov x9, -1
str x9, [x28, #68528]
mov x9, -1
str x9, [x28, #68536]
mov x9, -1
str x9, [x28, #68544]
mov x9, 15
str x9, [x28, #68552]
mov x9, -1
str x9, [x28, #68560]
mov x9, -1
str x9, [x28, #68568]
mov x9, -1
str x9, [x28, #68576]
mov x9, -1
str x9, [x28, #68584]
mov x9, -1
str x9, [x28, #68592]
mov x9, -1
str x9, [x28, #68600]
mov x9, -1
str x9, [x28, #68608]
mov x9, 16
str x9, [x28, #68616]
mov x9, -1
str x9, [x28, #68624]
mov x9, -1
str x9, [x28, #68632]
mov x9, -1
str x9, [x28, #68640]
mov x9, -1
str x9, [x28, #68648]
mov x9, -1
str x9, [x28, #68656]
mov x9, -1
str x9, [x28, #68664]
mov x9, -1
str x9, [x28, #68672]
mov x9, 17
str x9, [x28, #68680]
mov x9, -1
str x9, [x28, #68688]
mov x9, -1
str x9, [x28, #68696]
mov x9, -1
str x9, [x28, #68704]
mov x9, -1
str x9, [x28, #68712]
mov x9, -1
str x9, [x28, #68720]
mov x9, -1
str x9, [x28, #68728]
mov x9, -1
str x9, [x28, #68736]
mov x9, 18
str x9, [x28, #68744]
mov x9, -1
str x9, [x28, #68752]
mov x9, -1
str x9, [x28, #68760]
mov x9, -1
str x9, [x28, #68768]
mov x9, -1
str x9, [x28, #68776]
mov x9, -1
str x9, [x28, #68784]
mov x9, -1
str x9, [x28, #68792]
mov x9, -1
str x9, [x28, #68800]
mov x9, -1
str x9, [x28, #68808]
mov x9, -1
str x9, [x28, #68816]
mov x9, -1
str x9, [x28, #68824]
mov x9, -1
str x9, [x28, #68832]
mov x9, -1
str x9, [x28, #68840]
mov x9, -1
str x9, [x28, #68848]
mov x9, -1
str x9, [x28, #68856]
mov x9, -1
str x9, [x28, #68864]
mov x9, 19
str x9, [x28, #68872]
mov x9, -1
str x9, [x28, #68880]
mov x9, -1
str x9, [x28, #68888]
mov x9, -1
str x9, [x28, #68896]
mov x9, -1
str x9, [x28, #68904]
mov x9, -1
str x9, [x28, #68912]
mov x9, -1
str x9, [x28, #68920]
mov x9, -1
str x9, [x28, #68928]
mov x9, -1
str x9, [x28, #68936]
mov x9, -1
str x9, [x28, #68944]
mov x9, -1
str x9, [x28, #68952]
mov x9, -1
str x9, [x28, #68960]
mov x9, -1
str x9, [x28, #68968]
mov x9, -1
str x9, [x28, #68976]
mov x9, -1
str x9, [x28, #68984]
mov x9, -1
str x9, [x28, #68992]
mov x9, 20
str x9, [x28, #69000]
mov x9, -1
str x9, [x28, #69008]
mov x9, -1
str x9, [x28, #69016]
mov x9, -1
str x9, [x28, #69024]
mov x9, -1
str x9, [x28, #69032]
mov x9, -1
str x9, [x28, #69040]
mov x9, -1
str x9, [x28, #69048]
mov x9, -1
str x9, [x28, #69056]
mov x9, -1
str x9, [x28, #69064]
mov x9, -1
str x9, [x28, #69072]
mov x9, -1
str x9, [x28, #69080]
mov x9, -1
str x9, [x28, #69088]
mov x9, -1
str x9, [x28, #69096]
mov x9, -1
str x9, [x28, #69104]
mov x9, -1
str x9, [x28, #69112]
mov x9, -1
str x9, [x28, #69120]
mov x9, 21
str x9, [x28, #69128]
mov x9, -1
str x9, [x28, #69136]
mov x9, -1
str x9, [x28, #69144]
mov x9, -1
str x9, [x28, #69152]
mov x9, -1
str x9, [x28, #69160]
mov x9, -1
str x9, [x28, #69168]
mov x9, -1
str x9, [x28, #69176]
mov x9, -1
str x9, [x28, #69184]
mov x9, -1
str x9, [x28, #69192]
mov x9, -1
str x9, [x28, #69200]
mov x9, -1
str x9, [x28, #69208]
mov x9, -1
str x9, [x28, #69216]
mov x9, -1
str x9, [x28, #69224]
mov x9, -1
str x9, [x28, #69232]
mov x9, -1
str x9, [x28, #69240]
mov x9, -1
str x9, [x28, #69248]
mov x9, 22
str x9, [x28, #69256]
mov x9, 9071397899755888
str x9, [x28, #70016]
mov x9, 10
str x9, [x28, #70024]
mov x9, 139391475744
str x9, [x28, #70032]
mov x9, 14906
str x9, [x28, #70040]
mov x9, 10
str x9, [x28, #70048]
mov x9, 63
str x9, [x28, #70056]
mov x9, 63
str x9, [x28, #70064]
mov x9, 2334675641768964710
str x9, [x28, #70072]
mov x9, 2336070161932623969
str x9, [x28, #70080]
mov x9, 2338328219647830132
str x9, [x28, #70088]
mov x9, 8532470133442244462
str x9, [x28, #70096]
mov x9, 7234299918454635109
str x9, [x28, #70104]
mov x9, 111477645603872
str x9, [x28, #70112]
mov x9, 2334675641768964710
str x9, [x28, #70120]
mov x9, 2336070161932623969
str x9, [x28, #70128]
mov x9, 2338328219647830132
str x9, [x28, #70136]
mov x9, 8532470133442244462
str x9, [x28, #70144]
mov x9, 7234299918454635109
str x9, [x28, #70152]
mov x9, 2318339385834566688
str x9, [x28, #70160]
mov x9, 7594230556005528175
str x9, [x28, #70168]
mov x9, 8026294645362139236
str x9, [x28, #70176]
mov x9, 2336646318805509485
str x9, [x28, #70184]
mov x9, 427071138913
str x9, [x28, #70192]
mov x9, 2336070161932623969
str x9, [x28, #70200]
mov x9, 8388361636925366647
str x9, [x28, #70208]
mov x9, 7310580662471124340
str x9, [x28, #70216]
mov x9, 8314057368378351730
str x9, [x28, #70224]
mov x9, 110386656470560
str x9, [x28, #70232]
mov x9, 7020682340064389236
str x9, [x28, #70240]
mov x9, 7021800530504804717
str x9, [x28, #70248]
mov x9, 7815273814025642105
str x9, [x28, #70256]
mov x9, 108
str x9, [x28, #70264]
mov x9, 7863397576860792175
str x9, [x28, #70272]
mov x9, 521610947941
str x9, [x28, #70280]
mov x9, 7863397576860792175
str x9, [x28, #70288]
mov x9, 521610947941
str x9, [x28, #70296]
mov x9, 7020682340064389236
str x9, [x28, #70304]
mov x9, 7021800530504804717
str x9, [x28, #70312]
mov x9, 7815273814025642105
str x9, [x28, #70320]
mov x9, 108
str x9, [x28, #70328]
mov x9, 7598263421702072436
str x9, [x28, #70352]
mov x9, 8461736429932799854
str x9, [x28, #70360]
mov x9, 27756
str x9, [x28, #70368]
mov x9, 8461736351404158830
str x9, [x28, #70384]
mov x9, 1919246957
str x9, [x28, #70392]
mov x9, 8461736351404158830
str x9, [x28, #70400]
mov x9, 1919246957
str x9, [x28, #70408]
mov x9, 1702195828
str x9, [x28, #74696]
mov x9, 435728179558
str x9, [x28, #74704]
mov x9, 1
str x9, [x28, #75024]
mov x9, 3617008633280213040
str x9, [x28, #75144]
mov x9, 3832616266501534256
str x9, [x28, #75152]
mov x9, 3690478013217453367
str x9, [x28, #75160]
mov x9, 3833184731142370614
str x9, [x28, #75168]
mov x9, 3472328304851367218
str x9, [x28, #75176]
mov x9, 3617010836632121905
str x9, [x28, #75184]
mov x9, 3472333802459640882
str x9, [x28, #75192]
mov x9, 3616443484303669042
str x9, [x28, #75200]
mov x9, 3472328296345120820
str x9, [x28, #75208]
mov x9, 3761686775621365808
str x9, [x28, #75216]
mov x9, 3618134563336041783
str x9, [x28, #75224]
mov x9, 3978706207458670386
str x9, [x28, #75232]
mov x9, 3546361734253066033
str x9, [x28, #75240]
mov x9, 3762536698210432817
str x9, [x28, #75248]
mov x9, 3544668469166814519
str x9, [x28, #75256]
mov x9, 3978146556107240759
str x9, [x28, #75264]
mov x9, 3472330495284492081
str x9, [x28, #75272]
mov x9, 3617571587595841586
str x9, [x28, #75280]
mov x9, 3617569414275608625
str x9, [x28, #75288]
mov x9, 3616446787251089969
str x9, [x28, #75296]
mov x9, 3978141058532324663
str x9, [x28, #75304]
mov x9, 3690195451613951285
str x9, [x28, #75312]
mov x9, 3834029164679410740
str x9, [x28, #75320]
mov x9, 3762536711078557494
str x9, [x28, #75328]
mov x9, 3689913968013620278
str x9, [x28, #75336]
mov x9, 3617014152397534517
str x9, [x28, #75344]
mov x9, 3833184718240692018
str x9, [x28, #75352]
mov x9, 3761688987596830261
str x9, [x28, #75360]
mov x9, 3834310635428459831
str x9, [x28, #75368]
mov x9, 3617856378253948213
str x9, [x28, #75376]
mov x9, 3834025857571501366
str x9, [x28, #75384]
mov x9, 3689913976637240118
str x9, [x28, #75392]
mov x9, 3617008663445713460
str x9, [x28, #75400]
mov x9, 3834031359441319218
str x9, [x28, #75408]
mov x9, 3834594309394543925
str x9, [x28, #75416]
mov x9, 3617856378304083253
str x9, [x28, #75424]
mov x9, 3906648591945904690
str x9, [x28, #75432]
mov x9, 3544953255546336308
str x9, [x28, #75440]
mov x9, 3833182519217435441
str x9, [x28, #75448]
mov x9, 3976731454493175856
str x9, [x28, #75456]
mov x9, 4706901935554117959
str x9, [x28, #75472]
mov x9, 5457229
str x9, [x28, #75480]
mov x9, 7510091235206322971
str x9, [x28, #75488]
mov x9, 6564959857554709275
str x9, [x28, #75496]
mov x9, 18994
str x9, [x28, #75504]
mov x9, 3620712798783298331
str x9, [x28, #75512]
mov x9, 3760559837035587637
str x9, [x28, #75520]
mov x9, 27705
str x9, [x28, #75528]
mov x9, 23323
str x9, [x28, #75544]
mov x9, 59
str x9, [x28, #75552]
mov x9, 72
str x9, [x28, #75560]
mov x9, 16662253553277723
str x9, [x28, #75568]
mov x9, 59
str x9, [x28, #75576]
mov x9, 59
str x9, [x28, #75584]
mov x9, 109
str x9, [x28, #75592]
mov x9, 16662253553343259
str x9, [x28, #75600]
mov x9, 59
str x9, [x28, #75608]
mov x9, 59
str x9, [x28, #75616]
mov x9, 109
str x9, [x28, #75624]
mov x9, 8427234
str x9, [x28, #75632]
mov x9, 1831885595
str x9, [x28, #75640]
mov x9, 1735290704
str x9, [x28, #75648]
mov x9, 35482105758547
str x9, [x28, #75656]
mov x9, 8246779255723291182
str x9, [x28, #75664]
mov x9, 51069076769394
str x9, [x28, #75672]
mov x9, 3473454214223897458
str x9, [x28, #75680]
mov x9, 7598807797348048993
str x9, [x28, #75696]
mov x9, 7234298801746374255
str x9, [x28, #75704]
mov x9, 8391735975095138080
str x9, [x28, #75712]
mov x9, 7597135470210150944
str x9, [x28, #75720]
mov x9, 7809653110277695342
str x9, [x28, #75728]
mov x9, 25973
str x9, [x28, #75736]
b main
j2k_fntab:
.quad __panic
.quad j2k_fs0
.quad Mem__alloc
.quad j2k_fs1
.quad Mem__alloc_general
.quad j2k_fs2
.quad Mem__bump
.quad j2k_fs3
.quad Mem__alloc_raw
.quad j2k_fs4
.quad Mem__alloc_new
.quad j2k_fs5
.quad Mem__alloc_direct
.quad j2k_fs6
.quad Mem__free_direct
.quad j2k_fs7
.quad Mem__alloc_big
.quad j2k_fs8
.quad Mem__free
.quad j2k_fs9
.quad Mem__free_general
.quad j2k_fs10
.quad Mem__free_now
.quad j2k_fs11
.quad Mem__free_raw
.quad j2k_fs12
.quad Mem__free_big
.quad j2k_fs13
.quad Mem__free_piece
.quad j2k_fs14
.quad Mem__dbg_where
.quad j2k_fs15
.quad Mem__dbg_find
.quad j2k_fs16
.quad Mem__dbg_free_place
.quad j2k_fs17
.quad Mem__dbg_guard_alloc
.quad j2k_fs18
.quad Mem__dbg_alloc
.quad j2k_fs19
.quad Mem__alloc_locked
.quad j2k_fs20
.quad Mem__dbg_intact
.quad j2k_fs21
.quad Mem__dbg_free
.quad j2k_fs22
.quad Mem__copy
.quad j2k_fs23
.quad __Arr__nullerr
.quad j2k_fs24
.quad __Arr__make
.quad j2k_fs25
.quad __Arr__grow
.quad j2k_fs26
.quad __Arr__slot
.quad j2k_fs27
.quad __Arr__free
.quad j2k_fs28
.quad __Str__make
.quad j2k_fs29
.quad __Str__textlen
.quad j2k_fs30
.quad __Str__check
.quad j2k_fs31
.quad __Str__ptr
.quad j2k_fs32
.quad __Str__len
.quad j2k_fs33
.quad __Str__push_int
.quad j2k_fs34
.quad __Str__from_int
.quad j2k_fs35
.quad __Str__from
.quad j2k_fs36
.quad __Str__clone
.quad j2k_fs37
.quad __Str__cat
.quad j2k_fs38
.quad __Str__append
.quad j2k_fs39
.quad __Str__push
.quad j2k_fs40
.quad __Str__c
.quad j2k_fs41
.quad __Str__isspace
.quad j2k_fs42
.quad __Str__to_int
.quad j2k_fs43
.quad __flush
.quad j2k_fs44
.quad __wr
.quad j2k_fs45
.quad __print_bool
.quad j2k_fs46
.quad __print_ptr
.quad j2k_fs47
.quad __out_fd
.quad j2k_fs48
.quad Sys__call
.quad j2k_fs49
.quad Sys__read
.quad j2k_fs50
.quad Sys__isatty
.quad j2k_fs51
.quad Sys__window_size
.quad j2k_fs52
.quad Sys__nanosleep
.quad j2k_fs53
.quad Sys__ppoll
.quad j2k_fs54
.quad Sys__clock_gettime
.quad j2k_fs55
.quad Option__String__Some
.quad j2k_fs56
.quad Option__String__None
.quad j2k_fs57
.quad Option__String__free
.quad j2k_fs58
.quad Env__get
.quad j2k_fs59
.quad Term__cols
.quad j2k_fs60
.quad Term__rows
.quad j2k_fs61
.quad Input__ready
.quad j2k_fs62
.quad Time__now_ms
.quad j2k_fs63
.quad Time__sleep_ms
.quad j2k_fs64
.quad Key__up
.quad j2k_fs65
.quad Key__down
.quad j2k_fs66
.quad game_raw_on
.quad j2k_fs67
.quad game_raw_off
.quad j2k_fs68
.quad game_byte
.quad j2k_fs69
.quad game_font
.quad j2k_fs70
.quad Game__rgb
.quad j2k_fs71
.quad Game__open
.quad j2k_fs72
.quad Game__running
.quad j2k_fs73
.quad Game__close
.quad j2k_fs74
.quad Game__note_key
.quad j2k_fs75
.quad Game__begin
.quad j2k_fs76
.quad Game__hit
.quad j2k_fs77
.quad Game__held
.quad j2k_fs78
.quad Game__clear
.quad j2k_fs79
.quad Game__pixel
.quad j2k_fs80
.quad Game__rect
.quad j2k_fs81
.quad Game__line
.quad j2k_fs82
.quad Game__circle
.quad j2k_fs83
.quad Game__text
.quad j2k_fs84
.quad Game__text_scaled
.quad j2k_fs85
.quad Game__art
.quad j2k_fs86
.quad Game__overlap
.quad j2k_fs87
.quad Game__end
.quad j2k_fs88
.quad Game__present
.quad j2k_fs89
.quad main
.quad j2k_fs90
.quad 0
.quad 0
j2k_fs0:
.asciz "__panic"
j2k_fs1:
.asciz "Mem__alloc"
j2k_fs2:
.asciz "Mem__alloc_general"
j2k_fs3:
.asciz "Mem__bump"
j2k_fs4:
.asciz "Mem__alloc_raw"
j2k_fs5:
.asciz "Mem__alloc_new"
j2k_fs6:
.asciz "Mem__alloc_direct"
j2k_fs7:
.asciz "Mem__free_direct"
j2k_fs8:
.asciz "Mem__alloc_big"
j2k_fs9:
.asciz "Mem__free"
j2k_fs10:
.asciz "Mem__free_general"
j2k_fs11:
.asciz "Mem__free_now"
j2k_fs12:
.asciz "Mem__free_raw"
j2k_fs13:
.asciz "Mem__free_big"
j2k_fs14:
.asciz "Mem__free_piece"
j2k_fs15:
.asciz "Mem__dbg_where"
j2k_fs16:
.asciz "Mem__dbg_find"
j2k_fs17:
.asciz "Mem__dbg_free_place"
j2k_fs18:
.asciz "Mem__dbg_guard_alloc"
j2k_fs19:
.asciz "Mem__dbg_alloc"
j2k_fs20:
.asciz "Mem__alloc_locked"
j2k_fs21:
.asciz "Mem__dbg_intact"
j2k_fs22:
.asciz "Mem__dbg_free"
j2k_fs23:
.asciz "Mem__copy"
j2k_fs24:
.asciz "__Arr__nullerr"
j2k_fs25:
.asciz "__Arr__make"
j2k_fs26:
.asciz "__Arr__grow"
j2k_fs27:
.asciz "__Arr__slot"
j2k_fs28:
.asciz "__Arr__free"
j2k_fs29:
.asciz "__Str__make"
j2k_fs30:
.asciz "__Str__textlen"
j2k_fs31:
.asciz "__Str__check"
j2k_fs32:
.asciz "__Str__ptr"
j2k_fs33:
.asciz "__Str__len"
j2k_fs34:
.asciz "__Str__push_int"
j2k_fs35:
.asciz "__Str__from_int"
j2k_fs36:
.asciz "__Str__from"
j2k_fs37:
.asciz "__Str__clone"
j2k_fs38:
.asciz "__Str__cat"
j2k_fs39:
.asciz "__Str__append"
j2k_fs40:
.asciz "__Str__push"
j2k_fs41:
.asciz "__Str__c"
j2k_fs42:
.asciz "__Str__isspace"
j2k_fs43:
.asciz "__Str__to_int"
j2k_fs44:
.asciz "__flush"
j2k_fs45:
.asciz "__wr"
j2k_fs46:
.asciz "__print_bool"
j2k_fs47:
.asciz "__print_ptr"
j2k_fs48:
.asciz "__out_fd"
j2k_fs49:
.asciz "Sys__call"
j2k_fs50:
.asciz "Sys__read"
j2k_fs51:
.asciz "Sys__isatty"
j2k_fs52:
.asciz "Sys__window_size"
j2k_fs53:
.asciz "Sys__nanosleep"
j2k_fs54:
.asciz "Sys__ppoll"
j2k_fs55:
.asciz "Sys__clock_gettime"
j2k_fs56:
.asciz "Option__String__Some"
j2k_fs57:
.asciz "Option__String__None"
j2k_fs58:
.asciz "Option__String__free"
j2k_fs59:
.asciz "Env__get"
j2k_fs60:
.asciz "Term__cols"
j2k_fs61:
.asciz "Term__rows"
j2k_fs62:
.asciz "Input__ready"
j2k_fs63:
.asciz "Time__now_ms"
j2k_fs64:
.asciz "Time__sleep_ms"
j2k_fs65:
.asciz "Key__up"
j2k_fs66:
.asciz "Key__down"
j2k_fs67:
.asciz "game_raw_on"
j2k_fs68:
.asciz "game_raw_off"
j2k_fs69:
.asciz "game_byte"
j2k_fs70:
.asciz "game_font"
j2k_fs71:
.asciz "Game__rgb"
j2k_fs72:
.asciz "Game__open"
j2k_fs73:
.asciz "Game__running"
j2k_fs74:
.asciz "Game__close"
j2k_fs75:
.asciz "Game__note_key"
j2k_fs76:
.asciz "Game__begin"
j2k_fs77:
.asciz "Game__hit"
j2k_fs78:
.asciz "Game__held"
j2k_fs79:
.asciz "Game__clear"
j2k_fs80:
.asciz "Game__pixel"
j2k_fs81:
.asciz "Game__rect"
j2k_fs82:
.asciz "Game__line"
j2k_fs83:
.asciz "Game__circle"
j2k_fs84:
.asciz "Game__text"
j2k_fs85:
.asciz "Game__text_scaled"
j2k_fs86:
.asciz "Game__art"
j2k_fs87:
.asciz "Game__overlap"
j2k_fs88:
.asciz "Game__end"
j2k_fs89:
.asciz "Game__present"
j2k_fs90:
.asciz "main"
.bss 108512
