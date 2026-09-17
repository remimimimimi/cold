	.global _start
	.extern required

	.text
_start:
	call required
	cmp $42, %rax
	jne .Lfail

	mov local_value@GOTPCREL(%rip), %rax
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

	.local local_value
	.type local_value,@object
local_value:
	.quad 42
	.size local_value, .-local_value

	.type pointer,@object
pointer:
	.quad local_value
	.size pointer, .-pointer
