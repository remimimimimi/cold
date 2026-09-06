.globl _start
.text
_start:
    xor %edi, %edi
    mov $60, %eax
    syscall
