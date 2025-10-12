; vim: set ft=nasm:
DEFAULT REL

section .data
	zero: dq 0

align 64
	rgb2y: times 4 dd 0.29889531,  0.58662247,  0.11448223, 0.0
	rgb2i: times 4 dd 0.59597799, -0.27417610, -0.32180189, 0.0
	rgb2q: times 4 dd 0.21147017, -0.52261711,  0.31114694, 0.0

	delta_coef: times 4 dd 0.5053, 0.299, 0.1957, 0.0

	max_delta: dd 352.15 ; 35215.0 * 0.1^2

	pixel1: dq 0b1111
	pixel2: dq 0b11111111
	pixel3: dq 0b111111111111

section .text
global vxdiff

vxdiff:
	; RDI base image pixels encoded in RGBA8 format
	; RSI second image pixels encoded in RGBA8 format
	; RDX base image width in pixels
	; RCX second image width in pixels
	; R8 base image height in pixels
	; R9 second image height in pixels
	push rbp
	mov rbp, rsp
	push rbx
	push r12
	push r13
	push r14
	push r15
	sub rsp, 24 ; locals + stack realignment to 16-byte boundary

	; local vars:
	%define OVERFLOWED_Y QWORD[rsp+0] ; number of columns in the base image that overflow the second image

	mov rax, 0b0001000100010001000100010001000100010001000100010001000100010001
	kmovq k1, rax ; Rs
	kshiftlq k2, k1, 1 ; Gs
	kshiftlq k3, k2, 1 ; Bs
	kshiftlq k4, k3, 1 ; As
	knotq k5, k4 ; RGBs

	mov al, 1
	vpbroadcastb zmm3, al
	vpxorq zmm0, zmm0, zmm0
	vpsubb zmm31, zmm0, zmm3 ; 255
	vpmovzxbd zmm30, xmm31
	vcvtudq2ps zmm30, zmm30 ; 255.0f
	vpmovzxbd zmm3, xmm3
	vcvtudq2ps zmm3, zmm3
	vdivps zmm3, zmm3, zmm30 ; 1/255.0f

	vmovups zmm7, [rgb2y]
	vmovups zmm8, [rgb2i]
	vmovups zmm9, [rgb2q]

	vbroadcastss xmm28, [max_delta]

	vmovups zmm29, [delta_coef]

	mov r15, rdx ; base image width

	mov rax, rcx
	cmp rdx, rcx
	cmovl rcx, rdx

	mov r13, rdx
	sub r13, rcx ; base image pointer increment after x loop end
	shl r13, 2
	mov r14, rax
	sub r14, rcx ; second image pointer increment after x loop end
	shl r14, 2

	mov r12, rcx ; number of x loop iterations

	mov rax, r8
	sub rax, r9
	cmovs rax, [zero]
	mov OVERFLOWED_Y, rax
	mov rax, r8
	cmp r9, r8
	cmovl rax, r9
	mov r15, rax

	xor rbx, rbx ; number of differences found
	mov rax, rdx
	mul OVERFLOWED_Y
	add rbx, rax ; include overflowed rows

	mov rdx, r15 ; number of y iterations

	jmp .y_loop

.x_leftovers:
	; handles pixels in a row that is not divisible by 4
	mov r15, rcx
	shl r15, 2
	test rcx, rcx
	jz .next_row
	dec rcx
	cmovz rax, [pixel1]
	dec rcx
	cmovz rax, [pixel2]
	dec rcx
	cmovz rax, [pixel3]
	kmov k6, rax
	vxorps xmm1, xmm1, xmm1
	vxorps xmm2, xmm2, xmm2
	vmovdqu8 xmm1 {k6}, [rdi]
	vmovdqu8 xmm2 {k6}, [rsi]
	add rsi, r15
	add rdi, r15
	xor rcx, rcx
	jmp .x_loop_body

.next_row:
	add rdi, r13
	add rsi, r14
	mov r15, r13
	shr r15, 2
	add rbx, r15 ; include overflowed pixels in current row

.y_loop:
	; loops over columns
	cmp rdx, 0
	jle .done

	dec rdx
	mov rcx, r12

.x_loop:
	; loops over pixels in a row
	cmp rcx, 4
	jl .x_leftovers

	vmovdqu8 xmm1, [rdi]
	vmovdqu8 xmm2, [rsi]

	add rdi, 16
	add rsi, 16
	sub rcx, 4

.x_loop_body:
	; replace pixels having alpha=0 with white
	kxor k6, k6, k6
	kxor k7, k7, k7
	vpcmpequb k6 {k4}, xmm1, xmm0
	kshiftlb k6, k6, 1
	kor k7, k7, k6
	kshiftlb k6, k6, 1
	kor k7, k7, k6
	kshiftlb k6, k6, 1
	kor k7, k7, k6
	vmovdqu8 xmm1 {k7}, xmm31
	;
	kxor k6, k6, k6
	kxor k7, k7, k7
	vpcmpequb k6 {k4}, xmm2, xmm0
	kshiftlb k6, k6, 1
	kor k7, k7, k6
	kshiftlb k6, k6, 1
	kor k7, k7, k6
	kshiftlb k6, k6, 1
	kor k7, k7, k6
	vmovdqu8 xmm2 {k7}, xmm31

	; convert bytes to floats
	vpmovzxbd zmm1, xmm1
	vcvtudq2ps zmm1, zmm1
	vpmovzxbd zmm2, xmm2
	vcvtudq2ps zmm2, zmm2

	; normalise alpha
	vmulps zmm1 {k4}, zmm1, zmm3
	vmulps zmm2 {k4}, zmm2, zmm3

	; blend rgb with white pixel using alpha
	vsubps zmm1 {k5}, zmm1, zmm30
	vshufps zmm10, zmm1, zmm1, 0xff
	vmulps zmm1 {k5}, zmm1, zmm10
	vaddps zmm1 {k5}, zmm1, zmm30
	;
	vsubps zmm2 {k5}, zmm2, zmm30
	vshufps zmm20, zmm2, zmm2, 0xff
	vmulps zmm2 {k5}, zmm2, zmm20
	vaddps zmm2 {k5}, zmm2, zmm30

	; rgb to yiq
	vmulps zmm10, zmm1, zmm7 ; y
	vmulps zmm11, zmm1, zmm8 ; i
	vmulps zmm12, zmm1, zmm9 ; q
	vmulps zmm20, zmm2, zmm7 ; y
	vmulps zmm21, zmm2, zmm8 ; i
	vmulps zmm22, zmm2, zmm9 ; q

	; yiq(R)
	vxorps zmm13, zmm13, zmm13
	vshufps zmm13 {k1}, zmm10, zmm10, 0b00000000
	vshufps zmm13 {k2}, zmm11, zmm11, 0b00000000
	vshufps zmm13 {k3}, zmm12, zmm12, 0b00000000
	; yiq(G)
	vxorps zmm14, zmm14, zmm14
	vshufps zmm14 {k1}, zmm10, zmm10, 0b00000001
	vshufps zmm14 {k2}, zmm11, zmm11, 0b00000100
	vshufps zmm14 {k3}, zmm12, zmm12, 0b00010000
	; yiq(B)
	vxorps zmm15, zmm15, zmm15
	vshufps zmm15 {k1}, zmm10, zmm10, 0b00000010
	vshufps zmm15 {k2}, zmm11, zmm11, 0b00001000
	vshufps zmm15 {k3}, zmm12, zmm12, 0b00100000

	; yiq(R)
	vxorps zmm23, zmm23, zmm23
	vshufps zmm23 {k1}, zmm20, zmm20, 0b00000000
	vshufps zmm23 {k2}, zmm21, zmm21, 0b00000000
	vshufps zmm23 {k3}, zmm22, zmm22, 0b00000000
	; yiq(G)
	vxorps zmm24, zmm24, zmm24
	vshufps zmm24 {k1}, zmm20, zmm20, 0b00000001
	vshufps zmm24 {k2}, zmm21, zmm21, 0b00000100
	vshufps zmm24 {k3}, zmm22, zmm22, 0b00010000
	; yiq(B)
	vxorps zmm25, zmm25, zmm25
	vshufps zmm25 {k1}, zmm20, zmm20, 0b00000010
	vshufps zmm25 {k2}, zmm21, zmm21, 0b00001000
	vshufps zmm25 {k3}, zmm22, zmm22, 0b00100000

	; yiq
	vaddps zmm16, zmm13, zmm14
	vaddps zmm16, zmm16, zmm15
	vaddps zmm26, zmm23, zmm24
	vaddps zmm26, zmm26, zmm25

	; YIQ diff
	vsubps zmm16, zmm16, zmm26

	; YIQ*YIQ
	vmulps zmm16, zmm16, zmm16
	; YIQ*YIQ * delta coef
	vmulps zmm16, zmm16, zmm29

	vxorps zmm17, zmm17, zmm17
	vxorps zmm18, zmm18, zmm18
	vxorps zmm19, zmm19, zmm19
	vshufps zmm17 {k1}, zmm16, zmm16, 0b10101010
	vshufps zmm18 {k1}, zmm16, zmm16, 0b01010101
	vshufps zmm19 {k1}, zmm16, zmm16, 0b00000000

	; delta
	vaddps zmm16, zmm19, zmm18
	vaddps zmm16, zmm16, zmm17

	vcompressps zmm16 {k1}, zmm16
	vcmpgtps k6, xmm16, xmm28
	kmov eax, k6
	popcnt eax, eax

	add rbx, rax
	jmp .x_loop

.done:
	mov eax, ebx
	add rsp, 24
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	pop rbp
	ret
