; Exit the program
; nasm -f elf64 exit.asm
; ld -o exit exit.o

section .text

    global _start

_start:

    mov rax, 0x3c   ; syscall 60 is exit
    mov rdi, 0      ; this is the exit status
    syscall         ; call the kernel to execute

