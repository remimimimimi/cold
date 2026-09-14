	.global _start
	.extern first

	.text
_start:
	call first
	mov %rax, %rdi
	mov $60, %rax
	syscall
