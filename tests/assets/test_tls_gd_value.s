	.global tls_value
	.type tls_value,@tls_object

	.section .tdata,"awT",@progbits
	.align 8
tls_value:
	.quad 42
	.size tls_value, .-tls_value
