	.extern my_const

	.global _start
	.text
_start:
	mov my_const(%rip), %rdi
	mov $60, %rax
	syscall
