	.global _start

	.text
_start:
	mov ro_value(%rip), %rax
	add data_value(%rip), %rax
	mov %rax, bss_value(%rip)
	cmpq $42, bss_value(%rip)
	jne .Lfail

	mov $60, %eax
	xor %edi, %edi
	syscall

.Lfail:
	mov $60, %eax
	mov $1, %edi
	syscall

	.section .rodata
	.balign 32
ro_value:
	.quad 17

	.data
	.balign 64
data_value:
	.quad 25

	.bss
	.balign 128
bss_value:
	.zero 8

	.section .note.GNU-stack,"",@progbits
