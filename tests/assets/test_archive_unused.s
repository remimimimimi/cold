	.global unused
	.type unused, @function

	.text
unused:
	mov $31, %rax
	ret
	.size unused, .-unused
