	.global _start
	.extern required

	.text
_start:
	call required
	cmp $42, %rax
	setne %dil
	mov $60, %eax
	syscall
