	.global _start
	.extern tls_value
	.extern __tls_get_addr

	.text
_start:
	leaq tls_value@TLSGD(%rip), %rdi
	call __tls_get_addr@PLT
	cmpq $42, (%rax)
	setne %dil
	mov $60, %rax
	syscall
