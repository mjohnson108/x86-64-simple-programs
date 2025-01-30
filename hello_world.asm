; Display "Hello, world!"
; nasm -f elf64 hello_world.asm
; ld -o hello_world hello_world.o

section .data

    hello           db      'Hello, world!', 0x0a           ; 0x0a is newline char
    helloLen        equ     $-hello

section .text

    global _start

_start:

    mov rax, 1          ; write
    mov rdi, 1          ; to stdout
    mov rsi, hello      ; pointer to string
    mov rdx, helloLen   ; number of characters to write
    syscall             ; execute

    mov rax, 0x3c       ; exit as before
    mov rdi, 0
    syscall
				
