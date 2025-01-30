; Display "Hello, world!" a specified number of times
; nasm -f elf64 hello_world_param.asm
; ld -o hello_world_param hello_world_param.o
; e.g. "./hello_world_param 15"

section .data

    hello           db      'Hello, world!', 0x0a   
    helloLen        equ     $-hello

    usage           db      'Enter how many times to say "Hello, world!"', 0x0a
    usageLen        equ     $-usage

section .text

    global _start

_start:

    pop rax                     ; number of params passed to program (plus the program name itself)
    cmp rax, 2                  ; therefore expecting 2 params: the program name and the number of times to display "Hello, world!"
    jne show_usage              ; show the usage if we don't get the correct number of parameters

    pop rsi                     ; pointer to program name, not interested in this
    pop rsi                     ; pointer to first param: should be the number we want

    ; already we have the issue of converting a text string to number
    ; accumulate number in rcx
    mov rcx, 0

    ; we're going to make some serious assumptions about the nature/format of the text string number passed in

atoi_loop:

    movzx rbx, byte [rsi]       ; get the char pointed to by rsi
    cmp rbx, 0x30               ; Check if char is below '0' (ASCII)
    jl show_usage
    cmp rbx, 0x39               ; Check if char is above '9'
    jg show_usage
    sub rbx, 0x30               ; adjust to actual number by subtracting ASCII offset to 0
    add rcx, rbx                ; accumulate number in rcx, a register often used for counting
    
    movzx rbx, byte [rsi+1]     ; check the next char to see if the string continues
    cmp rbx, 0                  ; parameter string should be null-terminated
    je get_on_with_hellos       ; if it's null we're done converting
    
    imul rcx, 10                ; multiply rcx by ten
    inc rsi                     ; increment pointer to get next char when we loop
    jmp atoi_loop               ; keep going

get_on_with_hellos:

    cmp rcx, 0
    je exit                 ; if rcx is zero just exit without showing anything. This is the logical output for a parameter of 0 anyway

hello_loop:

    mov rax, 1              ; 'write'
    mov rdi, 1              ; to STDOUT
    mov rsi, hello          ; pointer to char buffer
    mov rdx, helloLen       ; length of string to write
    push rcx                ; preserve counter as syscall seems to bork it
    syscall                     
    pop rcx                 ; restore counter
    dec rcx                 ; decrement
    jnz hello_loop          ; and loop until zero
    jmp exit                ; skip displaying the usage

show_usage:

    mov rax, 1              ; write to STDOUT as above
    mov rdi, 1
    mov rsi, usage          ; but display the usage, such as it is
    mov rdx, usageLen   
    syscall

exit:
    mov rax, 0x3c           ; exit the program 
    mov rdi, 0
    syscall
				
