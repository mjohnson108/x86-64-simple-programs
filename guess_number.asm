; Guess a number game
; nasm -f elf64 guess_number.asm
; ld -o guess_number guess_number.o
; e.g. "./guess_number" or "./guess_number 20" to specify the number of tries

section .data

	greeting	    db 'Hello! I have thought of a number between 0 and 255. Try to guess it. You have this number of attempts: '
	greeting_len	equ $-greeting
	greeting_s	    times 10 db 0

	equal_str	    db 'Correct! You guessed the number.', 0x0a
	equal_str_len	equ $-equal_str

	sorry		    db "Sorry, you didn't guess the number within the number of goes.", 0x0a, "The number was: "
	sorry_len	    equ $-sorry
	sorry_s		    times 4 db 0

	higher_str	    db 'Higher!', 0x0a
	higher_str_len	equ $-higher_str

	lower_str	    db 'Lower!', 0x0a
	lower_str_len	equ $-lower_str

	input_buffer 	times 10 db 0
	buf_len		    equ $-input_buffer
	null_char	    db 0

	scratch		    times 10 db 0 
	scratchLen	    equ $-scratch
	scratchend	    db 0

    randSrc         db      '/dev/urandom', 0x0
	num_to_guess	db 0    ; will be filled in from /dev/urandom
	num_of_goes	    db 10	; default the number of goes to 10

section .text

	global _start

_start:

	; check if the player has passed the number of goes they want as a parameter.
	pop rax
	cmp rax, 2
	jne begin 	; if not use the default and start the game

	pop rsi                     
	pop rsi                     	

	call string_to_num

	mov [num_of_goes], cl 

begin:

	; come up with number for the player to guess
    ; read a byte from /dev/urandom

	mov rax, 2              ; 'open'
	mov rdi, randSrc        ; pointer to filename
	mov rsi, 0              ; O_RDONLY
	mov rdx, 0              
	syscall
    
	cmp rax, -2             ; file not found           
	je exit 
	cmp rax, -13            ; permission denied
	je exit

	mov rbx, rax            ; save the file descriptor

	; read a byte
	mov rax, 0              ; 'read'
	mov rdi, rbx            ; file descriptor
	mov rsi, num_to_guess   ; memory location to read to
	mov rdx, 1              ; read 1 byte
	push rbx                ; just in case
	syscall
	pop rbx

	; close it
	mov rax, 3              ; 'close'
	mov rdi, rbx            ; file descriptor
	syscall
	
	; greet the player and tell them how many goes they have
	movzx rax, byte [num_of_goes]		 
	mov r9, greeting	
	mov r10, greeting_len
	mov r11, greeting_s
	call display_line

player_input:	; mainloop

	; player enters a number
	call read_string

	; convert it from a string to a number in rcx
	mov rsi, input_buffer 
	call string_to_num

	; compare the guess to the chosen number 
	movzx rbx, byte [num_to_guess]
	cmp rcx, rbx
	je got_it		    ; if it's equal player has guessed correctly
	jl higher		    ; tell them to guess a higher number
	jg lower		    ; tell them to guess a lower number

loop_around:

	sub byte [num_of_goes], 1
	jnz player_input

no_more_goes:

	; player has not guessed the number. Tell them what it is and exit
	movzx rax, byte [num_to_guess]		 
	mov r9, sorry		
	mov r10, sorry_len
	mov r11, sorry_s
	call display_line

exit:

	mov rax, 0x3c           ; exit the program 
	mov rdi, 0
	syscall

;;;;;;;;
	

got_it:

	mov rsi, equal_str
	mov rdx, equal_str_len
	call write_out
	jmp exit

higher:
	mov rsi, higher_str
	mov rdx, higher_str_len
	call write_out
	jmp loop_around

lower:
	mov rsi, lower_str
	mov rdx, lower_str_len
	call write_out
	jmp loop_around

write_out:
	
	mov rax, 1
	mov rdi, 1
	syscall
	ret

;;;;;;;;

read_string:
	; player is going to enter something in the terminal
	mov rcx, 0		; count number of chars entered
get_char:
	; read a char into the buffer
	mov rax, 0		; read
	mov rdi, 0		; from stdin
	mov rdx, 1		; 1 char
	mov rsi, input_buffer	; calculate the current offset into input buffer
	add rsi, rcx		; fill it up one char at a time until newline entered
	push rsi		; preserve the pointer
	push rcx		; and the counter
	syscall
	pop rcx			; restore
	pop rsi
	cmp rax, 0		; check for nothing read (?)
	je exit;		; for now just quit
	inc rcx			; increment counter
	movzx rax, byte [rsi]		; check for newline entered
	cmp rax, 0x0a
	je done_read		; break out of loop when user hits return 
	cmp rcx, buf_len
	jge exit;		    ; let's not read beyond the end of the buffer
	jmp get_char		; continue
done_read:
	mov byte [rsi], 0
	ret

;;;;;;;;

string_to_num:
	mov rcx, 0			        ; rcx will be the final number
atoi_loop:
	movzx rbx, byte [rsi]       ; get the char pointed to by rsi
	cmp rbx, 0x30               ; Check if char is below '0' 
	jl exit
	cmp rbx, 0x39               ; Check if char is above '9'
	jg exit
	sub rbx, 0x30               ; adjust to actual number by subtracting ASCII offset to 0
	add rcx, rbx                ; accumulate number in rcx
	movzx rbx, byte [rsi+1]     ; check the next char to see if the string continues
	cmp rbx, 0                  ; string should be null-terminated
	je done_string			    ; if it's null we're done converting
	imul rcx, 10                ; multiply rcx by ten
	inc rsi                     ; increment pointer to get next char when we loop
	jmp atoi_loop
done_string:
	; rcx is the number
	ret

;;;;;;;;

display_line:
	; 1. Convert number to string in scratch buffer
	mov r8, 10		    ; we divide repeatedly by 10 to convert number to string
	mov rdi, scratchend	; start from the end of the scratch buffer and work back
	mov rcx, 0		    ; this will contain the final number of chars
itoa_inner:
	dec rdi			    ; going backwards in memory
	mov rdx, 0		    ; set up the division: rax already set coming into procedure
	div r8			    ; divide by ten
	add rdx, 0x30	    ; offset the remainder of the division to get the required ascii char
	mov [rdi], dl		; write the ascii char to the scratch buffer
	inc rcx			    ; keep track of the number of chars produced
	cmp rcx, scratchLen	; try not to overfeed the buffer
	je itoa_done		; break out if we reach the end of the buffer 
	cmp rax, 0		    ; otherwise keep dividing until nothing left 
	jne itoa_inner
itoa_done:
	; 2. Copy contents of scratch buffer into correct place in output string
	; rdi now points to beginning of char string and rcx is the number of chars
	; copy number into display buffer
	mov rsi, rdi
	mov rdi, r11            ; r11 is set coming into procedure, points to where in memory the number string should go
	; rcx already set from above
	mov r8, rcx;		    ; preserve number of chars in number string 
	rep movsb		        ; copy the number string to the output buffer
	mov byte [rdi], 0x0a	; and put a newline on the end of it
show_num:
	; 3. Write the complete final string to stdout
	mov rsi, r9		    ; pointer to final char buffer, r9 is set coming into procedure
	; calculate number of chars to display
	mov rdx, r10 		; length of the preamble, r10 set coming into procedure
	add rdx, r8		    ; plus length of the number string we just made
	inc rdx			    ; plus one for newline char
	mov rax, 1		    ; write
	mov rdi, 1		    ; to stdout
	syscall             ; execute
	ret                 ; done

				
