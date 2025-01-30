# x86-64-simple-programs

Various assembly language programs written while exploring the various syscalls available on Linux. A table of syscalls is available here: https://blog.rchapman.org/posts/Linux_System_Call_Table_for_x86_64/

## exit.asm

To stop a program the kernel has to be asked to do it using sys_exit. 

## hello_world.asm

This program displays "Hello, world!" using sys_write.

## hello_world_param.asm

This program displays "Hello, world!" a number of times, specified by command line parameter. In Linux, the kernel puts pointers to parameters passed to a program onto the stack. The parameter appears as a text string and has to be converted to a number for the display loop.

## hello_world_rand.asm

This program displays "Hello, world!" a random number of times. In Linux it is possible to get random numbers from the /dev/random and /dev/urandom files. This program uses sys_open to open the /dev/urandom file and checks for a couple of error codes.

## xor_cipher.asm

This program uses sys_read and sys_write to take read from STDIN, XOR it with a key, and write it to STDOUT. XOR is a symmetric operation, so the encoded data produced can be passed back through the program to generate the original input.

## bmp_read.asm

This program reads and displays some information from a bitmap file header.

## guess_number.asm

Using the techniques developed in the previous programs, a simple game can be created. This program pulls a random number (0-255) and asks the player to guess it in a certain number of tries, responding "higher" or "lower" to help the player.

## bmp_write.asm

This program creates a bitmap file of the specified height and width, filling it with the specified colour. It makes use of the mmap syscall to allocate some memory. This uses 32 bits per pixel uncompressed, so if large heights and widths are passed to it, a large file will be created.
