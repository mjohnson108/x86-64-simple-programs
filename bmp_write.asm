; Create a bitmap image of the specified size and colour
; nasm -f elf64 bmp_write.asm
; ld -o bmp_write bmp_write.o
; e.g. "./bmp_write 32 24 00ff9933 ./test.bmp"

section .data

	; bitmap file header
	; Various parts of this will be updated in the code 
	BMP_ident 		    db		'BM'
	BMP_file_size 		dd		0		
	BMP_res1 		    dw		0
	BMP_res2 		    dw		0
	BMP_img_offset 		dd		0
	BMP_initial_len 	equ		$-BMP_ident
	BMP_header_size 	dd		0		
	BMP_width 		    dd		0
	BMP_height 		    dd		0
	BMP_planes 		    dw		1
	BMP_bpp 		    dw		32
	BMP_compression 	dd		0
	BMP_img_size 		dd		0 
	BMP_x_res 		    dd		2835
	BMP_y_res 		    dd		2835
	BMP_num_cols 		dd		0
	BMP_imp_cols 		dd		0
	BMP_header_len 		equ		$-BMP_ident

	; show some usage if incorrect number of parameters
	usage_str 		    db		'Please pass width, height, colour (ARGB) and output file name as parameters.', 0x0a, 'E.g. "./bmp_write 1024 768 00ff0066 ./image.bmp"', 0x0a
	usage_len 		    equ		$-usage_str

	; various error messages
	number_error_str 	db		'Error in height/width parameters.', 0x0a
	number_error_len 	equ		$-number_error_str

	colour_error_str 	db		'Error in colour parameter (must be hex string).', 0x0a
	colour_error_len 	equ		$-colour_error_str

	map_f_str 		    db		'mmap failed.', 0x0a
	map_f_len 		    equ		$-map_f_str

	file_error_str 		db		'Error writing to output file.', 0x0a
	file_error_len 		equ		$-file_error_str

section .bss

	; some non-header data associated with the bitmap
	BMP_pixel_size		resd		1	; size of the bitmap in pixels
	BMP_data_ptr		resq		1 	; pointer to memory from mmap, for image data
	pixel_colour		resd		1	; ARGB in four bytes

	; pointers to params passed into program
	width_str_ptr		resq		1		
	height_str_ptr		resq		1	
	colour_str_ptr		resq		1
	out_file_ptr		resq		1

section .text

global _start

_start:

	pop rax			    ; process input parameters
	cmp rax, 5 
	jne usage

	pop rsi				; skip past program name

	; get pointers to the strings entered for width, height, colour
	pop rsi				; width
	mov [width_str_ptr], rsi
	pop rsi				; height
	mov [height_str_ptr], rsi
	pop rsi				; colour
	mov [colour_str_ptr], rsi
	pop rsi				; output file name
	mov [out_file_ptr], rsi

	; convert width string from parameters into a number
	mov rsi, [width_str_ptr]
	call string_to_num
	mov [BMP_width], ecx
	
	; convert height string from parameters into a number
	mov rsi, [height_str_ptr]
	call string_to_num
	mov [BMP_height], ecx

	; convert colour string into a 4-byte value 
	mov rsi, [colour_str_ptr]
	call hex_string_to_num
	mov [pixel_colour], ecx

	; perform some calculations for the bitmap header and image size
	mov dword [BMP_img_offset], BMP_header_len 	; image data is right after header
	mov dword [BMP_header_size], BMP_header_len-BMP_initial_len
	mov eax, [BMP_width]
	mov ecx, [BMP_height]
	mul ecx 			        ; image size in pixels is width*height
	mov [BMP_pixel_size], eax	
	sal eax, 2			        ; image size in bytes is image size * 4 (32 bpp)
	mov [BMP_img_size], eax
	add eax, BMP_header_len	    ; file size is image size in bytes plus header size
	mov [BMP_file_size], eax	

	; setup for mmap. Use this syscall to allocate some memory to write the
    ; pixel data to before copying that out to the destination file
	mov rax, 9			        ; mmap is syscall 9
	mov rdi, 0 			        ; let the kernel choose where the memory starts
	mov esi, [BMP_img_size] 	; the size in bytes that we want
	mov rdx, 3 			        ; memory protection: PROT_READ | PROT_WRITE
	mov r10, 34 			    ; flags: MAP_PRIVATE | MAP_ANONYMOUS
	mov r8, -1 			        ; no file descriptor
	mov r9, 0 			        ; no offset
	syscall	

	cmp rax, -1			        ; if returns -1 then map failed. Otherwise contains the starting address of the memory we wanted
	je map_failed
	mov [BMP_data_ptr], rax		; save address

	; because we are filling with one colour, we can use rep stos
	mov rdi, rax
	mov eax, [pixel_colour] 	; 1 pixel: argb
	mov ecx, [BMP_pixel_size] 
	rep stosd

	; open the specified file for writing. 
	; Create and truncate the file if necessary and apply some basic permissions
	mov rax, 2
	mov rdi, [out_file_ptr]
	mov rsi, 0o1101 		    ; flags: O_TRUNC | O_CREAT | O_WRONLY
	mov rdx, 0o0664			    ; permissions: -rw-rw-r--
	syscall

	cmp rax, -13
	je exit

	mov r8, rax			        ; file descriptor

	; write out the file
	; header first
	mov rsi, BMP_ident
	mov rdx, BMP_header_len 
	mov rax, 1
	mov rdi, r8 
	syscall

	; check to make sure the entire header was written
	cmp rax, BMP_header_len
	jne file_write_error

	; write out the image data image data
	mov rsi, [BMP_data_ptr]
	mov edx, [BMP_img_size]
	mov rax, 1
	mov rdi, r8
	syscall

	; check to make sure all the image data was written
	cmp eax, [BMP_img_size]
	jne file_write_error

	; close the file
	mov rax, 3
	mov rdi, r8
	syscall

    ; done
exit:

	mov rax, 0x3c
	mov rdi, 0
	syscall

;;;;;;;;;

usage:
	mov rsi, usage_str
	mov rdx, usage_len
	call write_out
	jmp exit

map_failed:
	mov rsi, map_f_str
	mov rdx, map_f_len
	call write_out
	jmp exit

file_write_error:
	mov rsi, file_error_str
	mov rdx, file_error_len
	call write_out
	jmp exit

number_error:
	mov rsi, number_error_str
	mov rdx, number_error_len
	call write_out
	jmp exit

colour_error:
	mov rsi, colour_error_str
	mov rdx, colour_error_len
	call write_out
	jmp exit

write_out:
	mov rax, 1
	mov rdi, 1
	syscall
	ret

;;;;;;;;

string_to_num:
	mov rcx, 0			        ; rcx will be the final number
atoi_loop:
	movzx rbx, byte [rsi]       ; get the char pointed to by rsi
	cmp rbx, 0x30               ; Check if char is below '0' 
	jl number_error
	cmp rbx, 0x39               ; Check if char is above '9'
	jg number_error
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

hex_string_to_num:
	mov rcx, 0
hex_loop:
	movzx rax, byte [rsi]
	cmp rax, 0x30
	jl colour_error
	cmp rax, 0x39
	jg try_a_to_f
	sub rax, 0x30
	jmp add_nibble
try_a_to_f:
	and ax, 0b11011111 		    ; convert lowercase to upper through bitmask
	cmp rax, 0x41			    ; 'A'
	jl colour_error
	cmp rax, 0x46			    ; 'F'
	jg colour_error
	sub rax, 0x37			    ; offset to 0x0a
add_nibble:
	add rcx, rax 
 	movzx rax, byte [rsi+1]		; check for end of string
	cmp rax, 0
	je done_hex
	sal rcx, 4			        ; multiply by 16, because hex 
	inc rsi
	jmp hex_loop
done_hex:
	; rcx is the number
	ret

				
