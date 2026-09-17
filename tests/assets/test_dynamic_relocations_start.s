	.global _start
	.extern shared_value

	.text
_start:
	mov shared_value@GOTPCREL(%rip), %rax
	cmpq $42, (%rax)
	jne .Lfail

	mov pointer(%rip), %rax
	cmpq $42, (%rax)
	jne .Lfail

	xor %rdi, %rdi
	jmp .Lexit

.Lfail:
	mov $1, %rdi

.Lexit:
	mov $60, %rax
	syscall

	.data
	.align 8
pointer:
	.quad shared_value
