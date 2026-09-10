	.globl _start

	.text
_start:
	lea target-4(%rip), %rax
	cmp pointer(%rip), %rax
	setne %dil
	mov $60, %eax
	syscall

	.data
target:
	.long 7

pointer:
	.quad target-4
