; Display "Hello, world!" a random number of times
; nasm -f elf64 hello_world_rand.asm
; ld -o hello_world_rand hello_world_rand.o
; e.g. "./hello_world_rand"

section .data

    hello           db      'Hello, world!', 0x0a   
    helloLen        equ     $-hello

    errMsg          db      'Could not open file', 0x0a
    errMsgLen       equ     $-errMsg

    ; this little program doesn't need to draw from /dev/random
    randSrc         db      '/dev/urandom', 0x0
    randNum         db      0

section .text

    global _start

_start:

    ; open the source of 'randomness'
    mov rax, 2              ; 'open'
    mov rdi, randSrc        ; pointer to filename
    mov rsi, 0              ; flags: 0 is O_RDONLY on my system
    mov rdx, 0              
    syscall
    
    cmp rax, -2             ; file not found           
    je open_error
    cmp rax, -13            ; permission denied
    je open_error

    mov rbx, rax            ; save the file descriptor

    ; read a byte
    mov rax, 0              ; 'read'
    mov rdi, rbx            ; file descriptor
    mov rsi, randNum        ; memory location to read to
    mov rdx, 1              ; read 1 byte
    push rbx                ; preserve file descriptor in rbx
    syscall                 ; execute
    pop rbx

    ; close it
    mov rax, 3              ; 'close'
    mov rdi, rbx            ; file descriptor
    syscall

    ; put the random number into the loop counter
    movzx rcx, byte [randNum]   
    cmp rcx, 0
    je exit                 ; if rcx is zero just exit without showing anything.

hello_loop:

    mov rax, 1              ; 'write'
    mov rdi, 1              ; to STDOUT
    mov rsi, hello          ; pointer to char buffer
    mov rdx, helloLen       ; length of string to write
    push rcx                ; preserve counter as syscall seems to bork it
    syscall                     
    pop rcx                 ; restore counter
    dec rcx                 ; and loop
    jnz hello_loop
    jmp exit

open_error:

    ; display a simple message if could not open

    mov rax, 1
    mov rdi, 1
    mov rsi, errMsg
    mov rdx, errMsgLen
    syscall

exit:

    mov rax, 0x3c           ; exit the program 
    mov rdi, 0
    syscall
				
