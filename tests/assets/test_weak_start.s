	.global _start
	.type _start, @function
	.text
_start:
	mov sym_strong(%rip), %edi
	add sym_unique(%rip), %edi
	add sym_weak(%rip), %edi
	mov $60, %eax
	syscall

	.size _start, .-_start
