; Read bitmap image file header
; nasm -f elf64 bmp_read.asm
; ld -o bmp_read bmp_read.o
; e.g. "./bmp_read ./image.bmp"

section .data

	; error messages

	usage           db      'Enter bitmap file name.', 0x0a
	usageLen        equ     $-usage

	errorFNF        db      'File not found.', 0x0a
	errorFNFLen     equ     $-errorFNF

	errorDenied     db      'Permission denied.', 0x0a
	errorDeniedLen  equ     $-errorDenied

	errorRead       db      'Error reading file.', 0x0a
	errorReadLen    equ     $-errorRead

	errorFormat     db      "Doesn't look like a BMP file.", 0x0a
	errorFormatLen  equ     $-errorFormat

	; output buffers. Numbers from the BMP header will be converted to text string
	; and inserted in here for display.

	outWidth 	    db 'The image width (pixels) is: '
	outWidth_len 	equ $-outWidth
	outWidth_s 	    times 10 db 0               ; extra space at the end for the number string

	outHeight 	    db 'The image height (pixels) is: '
	outHeight_len 	equ $-outHeight
	outHeight_s 	times 10 db 0

	outbpp 		    db 'The bits per pixel is: '
	outbpp_len 	    equ $-outbpp
	outbpp_s 	    times 10 db 0

	outXRes 	    db 'The X resolution is: '
	outXRes_len 	equ $-outXRes
	outXRes_s 	    times 10 db 0

	outYRes 	    db 'The Y resolution is: '
	outYRes_len 	equ $-outYRes
	outYRes_s 	    times 10 db 0

	; a temp buffer for conversion between number and its string representation

	scratch 	    times 10 db 0	; should be plenty of room (!)
	scratchLen 	    equ $-scratch
	scratchend 	    db 0

section .bss

	; bitmap file header

	BMP_ident           resb        2       ; 'BM'
	BMP_file_size       resb        4       ; size of file
	BMP_res1            resb        2       ; 'reserved'
	BMP_res2            resb        2       ; 'reserved'    
	BMP_img_offset      resb        4       ; offset to image data
	BMP_header_size     resb        4       ; header size
	BMP_width           resb        4       ; image width
	BMP_height          resb        4       ; image height
	BMP_planes          resb        2       ; number of planes
	BMP_bpp             resb        2       ; bits per pixel
	BMP_compression     resb        4       ; compression
	BMP_img_size        resb        4       ; image size
	BMP_x_res           resb        4       ; x resolution
	BMP_y_res           resb        4       ; y resolution
	BMP_num_cols        resb        4       ; number of colours
	BMP_imp_cols        resb        4       ; important colours?

section .text

global _start

_start:

	pop rax                     ; number of params passed to program (plus the program name itself)
	cmp rax, 2                  ; therefore expecting 2 params: the program name and the filename of the bitmap file to read
	jne show_usage              ; error: user not using program correctly

	pop rdi                     ; skip past program name
	pop rdi                     ; should be pointer to supplied bitmap filename

	; open the specified file
	mov rax, 2                  ; 'open': rdi is already set with pointer to filename
	mov rsi, 0                  ; flags: O_RDONLY
	mov rdx, 0              
	syscall

	; check for open errors
	; on my system:-
	; -2 is file not found
	; -13 is permission denied

	cmp rax, -2             
	je fnf_error                ; error: file not found

	cmp rax, -13
	je denied_error             ; error: permission denied
    
proceed:

	mov r8, rax                 ; preserve file descriptor

	; read header data from the file

	mov rax, 0              ; 'read'
	mov rdi, r8             ; retrieve file descriptor
	mov rsi, BMP_ident      ; memory location to read to
	mov rdx, 54             ; read entire bitmap header, 54 bytes
	syscall

	cmp rax, 54             ; check all 54 bytes have been read
	jne read_error          ; error: for some reason could not read the required number of bytes

	; close the file
	mov rax, 3                  ; 'close'
	mov rdi, r8                 ; restore file descriptor
	syscall

inspect_header:

	; check for magic identifier
	mov ax, [BMP_ident]
	cmp ax, 'BM'
	jne format_error	; error: not a BMP file

	; if we've got this far, let's just say it's ok

	; display width of image
	mov eax, [BMP_width]	; mov'ing 32 bits to eax should 0 upper half of rax as well
	mov r9, outWidth	    ; setup buffers
	mov r10, outWidth_len
	mov r11, outWidth_s
	call display_line

	; display height of image
	mov eax, [BMP_height]
	mov r9, outHeight
	mov r10, outHeight_len
	mov r11, outHeight_s
	call display_line
    
	; display bits per pixel
	movzx rax, word [BMP_bpp]
	mov r9, outbpp
	mov r10, outbpp_len
	mov r11, outbpp_s
	call display_line

	; display X resolution of image
	mov eax, [BMP_x_res]
	mov r9, outXRes
	mov r10, outXRes_len
	mov r11, outXRes_s
	call display_line

	; display Y resolution of image
	mov eax, [BMP_y_res]
	mov r9, outYRes
	mov r10, outYRes_len
	mov r11, outYRes_s
	call display_line
 
 	; call it a day
exit:

	mov rax, 0x3c
	mov rdi, 0
	syscall

;;;;;;;;;;;;;;;;;;;;;;;;
;;; error messages ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;

show_usage:

	mov rsi, usage          
	mov rdx, usageLen   
	jmp write_and_exit

fnf_error:

	mov rsi, errorFNF
	mov rdx, errorFNFLen
	jmp write_and_exit

denied_error:

	mov rsi, errorDenied
	mov rdx, errorDeniedLen
	jmp write_and_exit

read_error:

	mov rsi, errorRead
	mov rdx, errorReadLen
	jmp write_and_exit

format_error:

	mov rsi, errorFormat
	mov rdx, errorFormatLen   
	jmp write_and_exit

write_and_exit:
	; assume rsi and rdx set correctly
	mov rax, 1
	mov rdi, 1
	syscall
	jmp exit

; routine to display a line of info about the bitmap
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
				

