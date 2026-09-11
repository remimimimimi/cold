	.globl _start
	.extern answer

	.section .text
_start:
	mov answer(%rip), %edi
	mov $60, %eax
	syscall
