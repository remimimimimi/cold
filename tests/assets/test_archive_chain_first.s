	.global first
	.extern second
	.type first,@function

	.text
first:
	call second
	ret
	.size first, .-first
