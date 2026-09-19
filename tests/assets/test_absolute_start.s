	.globl _start
	.set answer, 42

	.text
_start:
	mov $answer, %edi
	sub $42, %edi
	mov $60, %eax
	syscall

	.data
pointer:
	.quad answer
