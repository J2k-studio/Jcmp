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
sub sp, sp, #0000096
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x0, [x29, #16]
bl __flush
mov x0, 0
str x0, [x29, #24]
L2:
ldr x0, [x29, #24]
ldr x1, [x29, #16]
add x0, x0, x1
ldrb x0, [x0, #0]
cmp x0, 0
b.eq L3
mov x1, 1
ldr x0, [x29, #24]
add x0, x0, x1
str x0, [x29, #24]
b L2
L3:
mov x10, 64
mov x11, 2
add x12, x28, #70016
mov x3, 7
mov x2, x12
mov x1, x11
mov x0, x10
cmp x0, 93
b.eq L5
cmp x0, 94
b.ne L6
L5:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L6:
mov x8, x0
mov x0, x1
mov x1, x2
mov x2, x3
svc 0
mov x10, 64
mov x11, 2
ldr x12, [x29, #16]
ldr x3, [x29, #24]
mov x2, x12
mov x1, x11
mov x0, x10
cmp x0, 93
b.eq L7
cmp x0, 94
b.ne L8
L7:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L8:
mov x8, x0
mov x0, x1
mov x1, x2
mov x2, x3
svc 0
mov x10, 64
mov x11, 2
add x12, x28, #70024
mov x3, 1
mov x2, x12
mov x1, x11
mov x0, x10
cmp x0, 93
b.eq L9
cmp x0, 94
b.ne L10
L9:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L10:
mov x8, x0
mov x0, x1
mov x1, x2
mov x2, x3
svc 0
str x29, [x29, #32]
adr x0, j2k_fntab
str x0, [x29, #40]
mov x0, 0
str x0, [x29, #48]
L11:
ldr x0, [x29, #32]
mov x1, 4096
cmp x0, x1
b.le L14
ldr x0, [x29, #48]
cmp x0, 24
b.ge L14
mov x0, 1
b L15
L14:
mov x0, 0
L15:
cmp x0, 0
b.eq L12
ldr x0, [x29, #32]
ldr x0, [x0, #8]
str x0, [x29, #56]
mov x0, 0
sub x0, x0, #1
str x0, [x29, #64]
mov x0, 0
str x0, [x29, #72]
L17:
ldr x0, [x29, #72]
mov x1, 2
mul x0, x0, x1
lsl x0, x0, #3
ldr x1, [x29, #40]
add x0, x0, x1
ldr x0, [x0, #0]
cmp x0, 0
b.eq L18
ldr x0, [x29, #72]
mov x1, 2
mul x0, x0, x1
lsl x0, x0, #3
ldr x1, [x29, #40]
add x0, x0, x1
ldr x0, [x0, #0]
ldr x1, [x29, #56]
cmp x0, x1
b.ge L21
ldr x0, [x29, #72]
str x0, [x29, #64]
L21:
L20:
mov x1, 1
ldr x0, [x29, #72]
add x0, x0, x1
str x0, [x29, #72]
b L17
L18:
ldr x0, [x29, #64]
cmp x0, 0
b.lt L12
L24:
L23:
ldr x0, [x29, #64]
mov x1, 2
mul x0, x0, x1
add x0, x0, #1
lsl x0, x0, #3
ldr x1, [x29, #40]
add x0, x0, x1
ldr x0, [x0, #0]
str x0, [x29, #80]
mov x10, 64
mov x11, 2
add x12, x28, #70032
mov x3, 5
mov x2, x12
mov x1, x11
mov x0, x10
cmp x0, 93
b.eq L26
cmp x0, 94
b.ne L27
L26:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L27:
mov x8, x0
mov x0, x1
mov x1, x2
mov x2, x3
svc 0
mov x0, 0
str x0, [x29, #88]
ldr x0, [x29, #80]
ldrb x0, [x0, #0]
cmp x0, 95
b.ne L31
ldr x0, [x29, #80]
ldrb x0, [x0, #1]
cmp x0, 95
b.ne L31
mov x0, 1
b L32
L31:
mov x0, 0
L32:
cmp x0, 0
b.eq L29
mov x0, 2
str x0, [x29, #88]
L29:
L28:
L34:
ldr x0, [x29, #88]
ldr x1, [x29, #80]
add x0, x0, x1
ldrb x0, [x0, #0]
cmp x0, 0
b.eq L35
ldr x0, [x29, #88]
ldr x1, [x29, #80]
add x0, x0, x1
ldrb x0, [x0, #0]
cmp x0, 95
b.ne L40
ldr x0, [x29, #88]
add x0, x0, #1
ldr x1, [x29, #80]
add x0, x0, x1
ldrb x0, [x0, #0]
cmp x0, 95
b.ne L40
mov x0, 1
b L41
L40:
mov x0, 0
L41:
cmp x0, 0
b.eq L38
mov x10, 64
mov x11, 2
add x12, x28, #70040
mov x3, 2
mov x2, x12
mov x1, x11
mov x0, x10
cmp x0, 93
b.eq L43
cmp x0, 94
b.ne L44
L43:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L44:
mov x8, x0
mov x0, x1
mov x1, x2
mov x2, x3
svc 0
mov x1, 2
ldr x0, [x29, #88]
add x0, x0, x1
str x0, [x29, #88]
b L37
L38:
mov x10, 64
mov x11, 2
ldr x0, [x29, #88]
ldr x1, [x29, #80]
add x12, x0, x1
mov x3, 1
mov x2, x12
mov x1, x11
mov x0, x10
cmp x0, 93
b.eq L45
cmp x0, 94
b.ne L46
L45:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L46:
mov x8, x0
mov x0, x1
mov x1, x2
mov x2, x3
svc 0
mov x1, 1
ldr x0, [x29, #88]
add x0, x0, x1
str x0, [x29, #88]
L37:
b L34
L35:
mov x10, 64
mov x11, 2
add x12, x28, #70048
mov x3, 1
mov x2, x12
mov x1, x11
mov x0, x10
cmp x0, 93
b.eq L47
cmp x0, 94
b.ne L48
L47:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L48:
mov x8, x0
mov x0, x1
mov x1, x2
mov x2, x3
svc 0
ldr x0, [x29, #32]
ldr x0, [x0, #0]
str x0, [x29, #32]
mov x1, 1
ldr x0, [x29, #48]
add x0, x0, x1
str x0, [x29, #48]
b L11
L12:
mov x10, 94
mov x1, 134
mov x0, x10
cmp x0, 93
b.eq L49
cmp x0, 94
b.ne L50
L49:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L50:
mov x8, x0
mov x0, x1
svc 0
L1:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000096
ret
.align 32
__flush:
sub sp, sp, #0000048
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #24]
str x20, [x29, #32]
mov x9, x28
ldr x19, [x28, #880]
mov x0, 0
str x0, [x9, #880]
mov x20, 0
L1662:
mov x0, x20
cmp x0, x19
b.ge L1663
mov x10, 64
mov x11, 1
add x0, x28, #896
add x12, x0, x20
sub x3, x19, x20
mov x2, x12
mov x1, x11
mov x0, x10
cmp x0, 93
b.eq L1665
cmp x0, 94
b.ne L1666
L1665:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L1666:
mov x8, x0
mov x0, x1
mov x1, x2
mov x2, x3
svc 0
mov x9, x0
cmp x0, 0
b.le L1663
L1668:
L1667:
add x20, x20, x9
b L1662
L1663:
L1661:
ldr x19, [x29, #24]
ldr x20, [x29, #32]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000048
ret
.align 32
__wr:
sub sp, sp, #0000176
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x19, [x29, #24]
str x20, [x29, #32]
str x21, [x29, #40]
str x22, [x29, #48]
str x23, [x29, #168]
mov x9, x0
mov x19, x1
mov x20, x2
cmp x0, 1
b.eq L1672
mov x10, 64
mov x11, x9
mov x12, x19
mov x3, x20
mov x2, x12
mov x1, x11
mov x0, x10
cmp x0, 93
b.eq L1674
cmp x0, 94
b.ne L1675
L1674:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L1675:
mov x8, x0
mov x0, x1
mov x1, x2
mov x2, x3
svc 0
b L1670
L1672:
L1671:
mov x21, x28
ldr x0, [x28, #888]
mov x22, x0
cmp x0, 0
b.ne L1677
mov x22, 1
mov x10, 29
mov x11, 1
mov x12, 21505
add x3, x29, #56
mov x2, x12
mov x1, x11
mov x0, x10
cmp x0, 93
b.eq L1681
cmp x0, 94
b.ne L1682
L1681:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L1682:
mov x8, x0
mov x0, x1
mov x1, x2
mov x2, x3
svc 0
cmp x0, 0
b.ne L1680
mov x22, 2
L1680:
L1679:
add x3, x21, #888
str x22, [x3, #0]
L1677:
L1676:
cmp x22, 2
b.ne L1685
mov x22, 0
L1687:
mov x0, x22
cmp x0, x20
b.ge L1688
mov x10, 64
mov x11, 1
add x12, x19, x22
sub x3, x20, x22
mov x2, x12
mov x1, x11
mov x0, x10
cmp x0, 93
b.eq L1690
cmp x0, 94
b.ne L1691
L1690:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L1691:
mov x8, x0
mov x0, x1
mov x1, x2
mov x2, x3
svc 0
mov x9, x0
cmp x0, 0
b.le L1688
L1693:
L1692:
add x22, x22, x9
b L1687
L1688:
b L1670
L1685:
L1684:
ldr x0, [x21, #880]
add x0, x0, x20
mov x1, 65536
cmp x0, x1
b.le L1696
bl __flush
L1696:
L1695:
mov x1, 65536
cmp x20, x1
b.lt L1699
mov x22, 0
L1701:
mov x0, x22
cmp x0, x20
b.ge L1702
mov x10, 64
mov x11, 1
add x12, x19, x22
sub x3, x20, x22
mov x2, x12
mov x1, x11
mov x0, x10
cmp x0, 93
b.eq L1704
cmp x0, 94
b.ne L1705
L1704:
sub sp, sp, #16
str x0, [sp, #0]
str x1, [sp, #8]
bl __flush
ldr x0, [sp, #0]
ldr x1, [sp, #8]
add sp, sp, #16
L1705:
mov x8, x0
mov x0, x1
mov x1, x2
mov x2, x3
svc 0
mov x9, x0
cmp x0, 0
b.le L1702
L1707:
L1706:
add x22, x22, x9
b L1701
L1702:
b L1670
L1699:
L1698:
add x10, x28, #896
ldr x1, [x21, #880]
add x9, x10, x1
mov x22, 0
mov x23, x20
b L1713
L1710:
add x10, x22, x9
add x0, x22, x19
ldrb x0, [x0, #0]
strb x0, [x10, #0]
L1711:
add x22, x22, #1
L1713:
cmp x22, x23
b.lt L1710
L1712:
mov x1, x20
ldr x0, [x21, #880]
add x0, x0, x1
str x0, [x21, #880]
L1670:
ldr x19, [x29, #24]
ldr x20, [x29, #32]
ldr x21, [x29, #40]
ldr x22, [x29, #48]
ldr x23, [x29, #168]
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000176
ret
.align 32
__print_bool:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x0, [x29, #16]
cmp x0, 0
b.eq L1717
bl __out_fd
add x11, x28, #74352
mov x2, 4
mov x1, x11
bl __wr
b L1716
L1717:
bl __out_fd
add x11, x28, #74360
mov x2, 5
mov x1, x11
bl __wr
L1716:
L1715:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
__print_ptr:
sub sp, sp, #0000080
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x0, [x29, #16]
mov x0, 22
str x0, [x29, #48]
ldr x0, [x29, #16]
cmp x0, 0
b.ne L1721
ldr x0, [x29, #48]
add x0, x29, x0
add x0, x0, #24
sub sp, sp, #16
str x0, [sp, #0]
mov x0, 48
ldr x3, [sp, #0]
add sp, sp, #16
strb x0, [x3, #0]
mov x1, 1
ldr x0, [x29, #48]
sub x0, x0, x1
str x0, [x29, #48]
L1721:
L1720:
ldr x0, [x29, #16]
str x0, [x29, #56]
mov x0, 0
str x0, [x29, #64]
L1723:
ldr x0, [x29, #64]
cmp x0, 16
b.ge L1726
ldr x0, [x29, #56]
cmp x0, 0
b.eq L1726
mov x0, 1
b L1727
L1726:
mov x0, 0
L1727:
cmp x0, 0
b.eq L1724
ldr x0, [x29, #56]
mov x1, 15
and x0, x0, x1
str x0, [x29, #72]
cmp x0, 10
b.ge L1730
ldr x0, [x29, #48]
add x0, x29, x0
add x10, x0, #24
mov x0, 48
ldr x1, [x29, #72]
add x0, x0, x1
uxtb x0, x0
strb x0, [x10, #0]
b L1729
L1730:
ldr x0, [x29, #48]
add x0, x29, x0
add x10, x0, #24
mov x0, 87
ldr x1, [x29, #72]
add x0, x0, x1
uxtb x0, x0
mov x3, x10
strb x0, [x3, #0]
L1729:
mov x1, 1
ldr x0, [x29, #48]
sub x0, x0, x1
str x0, [x29, #48]
ldr x0, [x29, #56]
mov x1, 4
asr x0, x0, x1
mov x1, 1152921504606846975
and x0, x0, x1
str x0, [x29, #56]
mov x1, 1
ldr x0, [x29, #64]
add x0, x0, x1
str x0, [x29, #64]
b L1723
L1724:
ldr x0, [x29, #48]
add x0, x29, x0
add x0, x0, #24
sub sp, sp, #16
str x0, [sp, #0]
mov x0, 120
ldr x3, [sp, #0]
add sp, sp, #16
strb x0, [x3, #0]
mov x1, 1
ldr x0, [x29, #48]
sub x0, x0, x1
str x0, [x29, #48]
add x0, x29, x0
add x0, x0, #24
sub sp, sp, #16
str x0, [sp, #0]
mov x0, 48
ldr x3, [sp, #0]
add sp, sp, #16
strb x0, [x3, #0]
mov x1, 1
ldr x0, [x29, #48]
sub x0, x0, x1
str x0, [x29, #48]
bl __out_fd
mov x10, x0
ldr x0, [x29, #48]
add x0, x0, #1
add x0, x29, x0
add x11, x0, #24
mov x0, 22
ldr x1, [x29, #48]
sub x2, x0, x1
mov x1, x11
mov x0, x10
bl __wr
L1719:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000080
ret
.align 32
__out_fd:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
str x28, [x29, #16]
ldr x0, [x28, #864]
add x0, x0, #1
b L1732
bl j2k_noret
L1732:
ldr x29, [sp, #0]
ldr x30, [sp, #8]
add sp, sp, #0000032
ret
.align 32
main:
sub sp, sp, #0000032
str x29, [sp, #0]
str x30, [sp, #8]
add x29, sp, #0
mov x0, 1
str x0, [x29, #16]
add x0, x29, #16
add x10, x0, #1
mov x0, 1
str x0, [x10, #0]
add x0, x29, #16
add x10, x0, #8
mov x0, 7
mov x3, x10
mov x1, x0
str x1, [x3, #0]
ldr x0, [x29, #16]
cmp x0, 0
b.eq L2069
add x0, x29, #16
add x0, x0, #1
ldr x0, [x0, #0]
cmp x0, 0
b.eq L2069
mov x0, 1
b L2070
L2069:
mov x0, 0
L2070:
cmp x0, 0
b.eq L2068
add x0, x29, #16
ldr x0, [x0, #8]
b L2066
L2068:
L2067:
mov x0, 1
b L2066
mov x0, 0
L2066:
sub sp, sp, #16
str x0, [sp, #0]
bl __flush
ldr x0, [sp, #0]
add sp, sp, #16
mov x8, 94
svc 0
j2k_noret:
mov x0, x28
add x0, x0, #74368
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
mov x9, 74416
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
mov x9, 1702195828
str x9, [x28, #74352]
mov x9, 435728179558
str x9, [x28, #74360]
mov x9, 7598807797348048993
str x9, [x28, #74368]
mov x9, 7234298801746374255
str x9, [x28, #74376]
mov x9, 8391735975095138080
str x9, [x28, #74384]
mov x9, 7597135470210150944
str x9, [x28, #74392]
mov x9, 7809653110277695342
str x9, [x28, #74400]
mov x9, 25973
str x9, [x28, #74408]
b main
j2k_fntab:
.quad __panic
.quad j2k_fs0
.quad __flush
.quad j2k_fs1
.quad __wr
.quad j2k_fs2
.quad __print_bool
.quad j2k_fs3
.quad __print_ptr
.quad j2k_fs4
.quad __out_fd
.quad j2k_fs5
.quad main
.quad j2k_fs6
.quad 0
.quad 0
j2k_fs0:
.asciz "__panic"
j2k_fs1:
.asciz "__flush"
j2k_fs2:
.asciz "__wr"
j2k_fs3:
.asciz "__print_bool"
j2k_fs4:
.asciz "__print_ptr"
j2k_fs5:
.asciz "__out_fd"
j2k_fs6:
.asciz "main"
.bss 107184
