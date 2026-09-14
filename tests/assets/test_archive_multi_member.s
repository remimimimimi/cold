	.global first
	.type first,@function
	.global second
	.type second,@function

	.text
first:
	mov $20, %rax
	ret
	.size first, .-first

second:
	mov $22, %rax
	ret
	.size second, .-second
