	.extern required
	.global _start

	.text
_start:
	call required
	mov %rax, %rdi
	mov $60, %rax
	syscall
