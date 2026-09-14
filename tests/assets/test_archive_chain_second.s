	.global second
	.type second,@function

	.text
second:
	mov $43, %rax
	ret
	.size second, .-second
