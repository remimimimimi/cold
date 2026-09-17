	.global shared_value
	.type shared_value,@object

	.data
	.align 8
shared_value:
	.quad 42
	.size shared_value, .-shared_value
