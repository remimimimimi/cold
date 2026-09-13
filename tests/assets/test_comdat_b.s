	.section .rodata.my_const,"aG",@progbits,my_const,comdat

	.global my_const
	.type my_const, @object

my_const:
	.quad 1
	.size my_const, .-my_const
