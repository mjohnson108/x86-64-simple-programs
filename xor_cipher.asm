; xor_cipher.asm
; nasm -f elf64 xor_cipher.asm
; ld -o xor_cipher xor_cipher.o
; cat some_text | ./xor_cipher > some_text.enc
; cat some_text.enc | ./xor_cipher > some_text.unenc

section .data

    key     dq      0xcafefeeddeadbeef      ; some key to xor with
    input   dq      0x0                     ; space for read buffer
    output  dq      0x0                     ; space for writeout buffer
    buf_len equ     8                       ; buffer length

section .text

    global _start

_start:

    mov rax, 0              ; 'read'
    mov rdi, 0              ; from stdin
    mov rsi, input          ; into input buffer 
    mov rdx, buf_len        ; buf_len bytes 
    syscall
    ; rax has the number of bytes actually read
    cmp rax, 0              ; got nothing?
    jz exit                 ; if so, exit

    ; xor the input buffer with the key and put in the output buffer

    mov rdx, rax            ; save the number of bytes read
    mov rcx, 0              ; loop counter
    
    ; process xor byte-by-byte in case we received fewer bytes than buffer permits
    ; rcx is both the loop counter and index into the buffers

xor_loop:

    mov al, [input+rcx]     ; char from input buffer
    xor al, [key+rcx]       ; xor with corresponding part of key
    mov [output+rcx], al    ; put result into output buffer

    inc rcx                 ; handle the loop
    cmp rcx, rdx
    jle xor_loop       

    ; done

    mov rax, 1              ; 'write'
    mov rdi, 1              ; to stdout
    mov rsi, output         ; from the output buffer
                            ; rdx already set with number of chars from rax returned from read above
    syscall

    jmp _start              ; loop to get more input from stdin

exit:

    mov rax, 0x3c           ; exit the program 
    mov rdi, 0
    syscall
				
