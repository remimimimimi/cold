	.global required
	.type required,@function

	.text
required:
	mov $42, %rax
	ret
	.size required, .-required
