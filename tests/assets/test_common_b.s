	.comm common_max,32,32

	.data
	.balign 8
	.global regular_wins
	.type regular_wins,@object
	.size regular_wins,8
regular_wins:
	.quad 0x0123456789abcdef
