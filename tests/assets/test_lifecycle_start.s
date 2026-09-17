	.global _start
	.global _init
	.global _fini

	.data
	.align 8
state:
	.quad 0

	.section .init,"ax",@progbits
_init:
	addq $1, state(%rip)
	ret

	.section .fini,"ax",@progbits
_fini:
	ret

	.text
constructor:
	addq $2, state(%rip)
	ret

destructor:
	ret

_start:
	xor %rdi, %rdi
	mov $60, %rax
	syscall

	.section .init_array,"aw",@init_array
	.align 8
	.quad constructor

	.section .fini_array,"aw",@fini_array
	.align 8
	.quad destructor
