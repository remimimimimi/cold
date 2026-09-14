	.extern first
	.extern second
	.global _start

	.text
_start:
	call first
	push %rax
	call second
	pop %rdi
	add %rax, %rdi
	mov $60, %rax
	syscall
