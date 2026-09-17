	.global _start

	.text
_start:
	xor %rdi, %rdi
	mov $60, %rax
	syscall

	.section .tdata,"awT",@progbits
	.align 32
tls_data:
	.quad 42

	.section .tbss,"awT",@nobits
	.align 64
tls_bss:
	.zero 24
