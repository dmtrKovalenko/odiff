; vim: set ft=nasm:
DEFAULT REL

section .rodata
align 64

rgb2y:          dd 0.29889531,  0.58662247,  0.11448223, 0.0
rgb2i:          dd 0.59597799, -0.27417610, -0.32180189, 0.0
rgb2q:          dd 0.21147017, -0.52261711,  0.31114694, 0.0

delta_coef:     dd 0.5053, 0.299, 0.1957, 0.0

max_delta:      dd 352.15
one_over_255:   dd 0.00392156862745098039
float255:       dd 255.0

pixel_masks:
    dq 0
    dq 0xF
    dq 0xFF
    dq 0xFFF

section .text
global vxdiff

vxdiff:
    ; RDI = base image pixels encoded in RGBA8 format
    ; RSI = second image pixels encoded in RGBA8 format
    ; RDX = base image width in pixels
    ; RCX = second image width in pixels
    ; R8  = base image height in pixels
    ; R9  = second image height in pixels

    push        rbx
    push        r12
    push        r13
    push        r14
    push        r15

    ; Setup channel mask registers: k1=R, k2=G, k3=B, k4=A, k5=RGB
    mov         rax, 0x1111111111111111
    kmovq       k1, rax
    kshiftlq    k2, 1, k1
    kshiftlq    k3, 1, k2
    kshiftlq    k4, 1, k3
    knotq       k5, k4

    ; Broadcast float constants to ZMM registers
    vbroadcastss zmm3,  [one_over_255]
    vbroadcastss zmm30, [float255]
    vbroadcastss zmm28, [max_delta]

    vbroadcastf32x4 zmm7,  [rgb2y]
    vbroadcastf32x4 zmm8,  [rgb2i]
    vbroadcastf32x4 zmm9,  [rgb2q]
    vbroadcastf32x4 zmm29, [delta_coef]

    ; common width -> r12
    mov         r12, rdx
    cmp         rcx, r12
    cmovb       r12, rcx

    ; row padding increments
    mov         r13, rdx
    sub         r13, r12
    shl         r13, 2

    mov         r14, rcx
    sub         r14, r12
    shl         r14, 2

    ; min height -> r15, overflow rows -> r11
    xor         r11d, r11d
    mov         r15, r8

    cmp         r8, r9
    jbe         .have_overflow

    mov         r11, r8
    sub         r11, r9
    mov         r15, r9

.have_overflow:

    ; initial diff count = overflow_rows * base_width
    mov         rax, r11
    mul         rdx
    mov         rbx, rax

    ; y loop counter
    mov         rdx, r15

align 32
.y_loop:
    test        rdx, rdx
    jz          .done

    dec         rdx
    mov         rcx, r12

align 32
.x_loop:
    cmp         rcx, 4
    jb          .x_leftovers

    vmovdqu8    xmm1, [rdi]
    vmovdqu8    xmm2, [rsi]

    add         rdi, 16
    add         rsi, 16

    sub         rcx, 4
    jmp         .x_loop_body

.x_leftovers:
    test        rcx, rcx
    jz          .next_row

    mov         rax, rcx
    shl         rax, 2

    mov         r11, [pixel_masks + rcx*8]
    kmovq       k6, r11

    vmovdqu8    xmm1{k6}{z}, [rdi]
    vmovdqu8    xmm2{k6}{z}, [rsi]

    add         rdi, rax
    add         rsi, rax

    xor         ecx, ecx

.x_loop_body:
    ; convert bytes to floats
    vpmovzxbd   zmm1, xmm1
    vcvtudq2ps  zmm1, zmm1
    vpmovzxbd   zmm2, xmm2
    vcvtudq2ps  zmm2, zmm2

    ; normalise alpha
    vmulps      zmm1{k4}, zmm1, zmm3
    vmulps      zmm2{k4}, zmm2, zmm3

    ; blend rgb with white pixel using alpha
    vsubps      zmm1{k5}, zmm1, zmm30
    vshufps     zmm10, zmm1, zmm1, 0xff
    vmulps      zmm1{k5}, zmm1, zmm10
    vaddps      zmm1{k5}, zmm1, zmm30

    vsubps      zmm2{k5}, zmm2, zmm30
    vshufps     zmm20, zmm2, zmm2, 0xff
    vmulps      zmm2{k5}, zmm2, zmm20
    vaddps      zmm2{k5}, zmm2, zmm30

    ; rgb to yiq
    vmulps      zmm10, zmm1, zmm7 ; y
    vmulps      zmm11, zmm1, zmm8 ; i
    vmulps      zmm12, zmm1, zmm9 ; q
    vmulps      zmm20, zmm2, zmm7 ; y
    vmulps      zmm21, zmm2, zmm8 ; i
    vmulps      zmm22, zmm2, zmm9 ; q

    ; yiq(R) for img1
    vxorps      zmm13, zmm13, zmm13
    vshufps     zmm13{k1}, zmm10, zmm10, 0b00000000
    vshufps     zmm13{k2}, zmm11, zmm11, 0b00000000
    vshufps     zmm13{k3}, zmm12, zmm12, 0b00000000
    ; yiq(G) for img1
    vxorps      zmm14, zmm14, zmm14
    vshufps     zmm14{k1}, zmm10, zmm10, 0b00000001
    vshufps     zmm14{k2}, zmm11, zmm11, 0b00000100
    vshufps     zmm14{k3}, zmm12, zmm12, 0b00010000
    ; yiq(B) for img1
    vxorps      zmm15, zmm15, zmm15
    vshufps     zmm15{k1}, zmm10, zmm10, 0b00000010
    vshufps     zmm15{k2}, zmm11, zmm11, 0b00001000
    vshufps     zmm15{k3}, zmm12, zmm12, 0b00100000

    ; yiq(R) for img2
    vxorps      zmm23, zmm23, zmm23
    vshufps     zmm23{k1}, zmm20, zmm20, 0b00000000
    vshufps     zmm23{k2}, zmm21, zmm21, 0b00000000
    vshufps     zmm23{k3}, zmm22, zmm22, 0b00000000
    ; yiq(G) for img2
    vxorps      zmm24, zmm24, zmm24
    vshufps     zmm24{k1}, zmm20, zmm20, 0b00000001
    vshufps     zmm24{k2}, zmm21, zmm21, 0b00000100
    vshufps     zmm24{k3}, zmm22, zmm22, 0b00010000
    ; yiq(B) for img2
    vxorps      zmm25, zmm25, zmm25
    vshufps     zmm25{k1}, zmm20, zmm20, 0b00000010
    vshufps     zmm25{k2}, zmm21, zmm21, 0b00001000
    vshufps     zmm25{k3}, zmm22, zmm22, 0b00100000

    ; yiq sums
    vaddps      zmm16, zmm13, zmm14
    vaddps      zmm16, zmm16, zmm15
    vaddps      zmm26, zmm23, zmm24
    vaddps      zmm26, zmm26, zmm25

    ; YIQ diff
    vsubps      zmm16, zmm16, zmm26

    ; YIQ*YIQ
    vmulps      zmm16, zmm16, zmm16
    ; YIQ*YIQ * delta coef
    vmulps      zmm16, zmm16, zmm29

    vxorps      zmm17, zmm17, zmm17
    vxorps      zmm18, zmm18, zmm18
    vxorps      zmm19, zmm19, zmm19
    vshufps     zmm17{k1}, zmm16, zmm16, 0b10101010
    vshufps     zmm18{k1}, zmm16, zmm16, 0b01010101
    vshufps     zmm19{k1}, zmm16, zmm16, 0b00000000

    ; delta sum
    vaddps      zmm16, zmm19, zmm18
    vaddps      zmm16, zmm16, zmm17

    vcmpps      k6{k1}, zmm16, zmm28, 6
    kmovd       eax, k6
    popcnt      eax, eax

    add         rbx, rax

    test        rcx, rcx
    jnz         .x_loop

.next_row:
    add         rdi, r13
    add         rsi, r14

    mov         rax, r13
    shr         rax, 2
    add         rbx, rax

    jmp         .y_loop

.done:
    mov         rax, rbx

    pop         r15
    pop         r14
    pop         r13
    pop         r12
    pop         rbx
    ret
