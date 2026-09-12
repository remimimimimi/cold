	.global _start
	.text
_start:
	lea common_max(%rip), %rax
	lea regular_wins(%rip), %rcx
	mov $60, %eax
	xor %edi, %edi
	syscall

	.section .rodata
	.quad common_max
	.quad regular_wins
