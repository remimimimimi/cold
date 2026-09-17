	.global _start
	.extern __tls_get_addr

	.text
_start:
	leaq tls_local@TLSLD(%rip), %rdi
	call __tls_get_addr@PLT
	leaq tls_local@DTPOFF(%rax), %rax
	cmpq $42, (%rax)
	setne %dil
	mov $60, %rax
	syscall

	.section .tdata,"awT",@progbits
	.align 8
tls_local:
	.quad 42
