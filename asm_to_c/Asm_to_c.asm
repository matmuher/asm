;		[PRINTF]

; global _start

global printf_c

section .text


;--------------------------------------


%macro  args_push 1-* 

	mov rax, %0	; get args num
	
	%rep  %0 
	
		%rotate -1 
        	push %1 
 	
	%endrep 

%endmacro


;--------------------------------------


; _start turned off to avoid multiple definition
; while linking with asm_to_C.cpp

%if 0

_start: 
	
	args_push ma_str, 15
	;args_push ma_str, test_str, '!', 15, 15, 15, 15
	call printf
	sub rsp, rax	; free stack from fuction arguments
	
	args_push int_print, r13
	call printf
	sub rsp, rax
	
	call exit

%endif


;--------------------------------------


%macro  multipush 1-* 

	%rep %0
		push %1 
		%rotate 1 
	%endrep 

%endmacro


;--------------------------------------


%macro  multipop 1-* 

	%rep  %0 
		%rotate -1 
        	pop %1 
	%endrep 
	
%endmacro


;--------------------------------------


exit:
	
	mov rax, 60
	mov rdi, 0
	
	syscall
	
	
;--------------------------------------
;
;
;		[PRINTF_C] (fastcall process)
;[descript]:
;	
;	Wrap for printf (): gets argumets as for stdcall
;	and transfers them to cdecl format
;
;
;--------------------------------------

printf_c:

	push r9
	push r8
	push rcx
	push rdx
	push rsi
	push rdi
	
	call printf
	
	add rax, 1
	add rsp, 6 * STACK_ALLIGN
	
	nop
	
	ret
	
	
;--------------------------------------
;
;
;		[PRINTF] (cdecl)
;
;[descript]:
;
;	Prints string concerning specifiers:
;	
;	%h - hexadecimal
;	%d - decimals
;	%o - octal
;	%b - binary
;
;	%c - char
;	%s - string ($-ended)
;
;	%% - percent
;
;[params]:
;
;	1 - formatted string adress in DS
;
;	... - format params	
;
;[return]:
;
;	r13 - number of written chars
;	or
;	FFFF (if format error occured)
;
;
;--------------------------------------

printf:

				;[PROLOG]
		push rbp
		mov rbp, rsp
		
		
		multipush rax, rbx, rdx, rdi, rsi, r14, r15	; Save registers
		
		
		%ifndef JMP_TABLE	; Create jmp_table if not created yet
		
			call prp_jmp_table
			%define JMP_TABLE
			
		%endif
		
		
		STDOUT equ 1	; Redirects output to terminal
		
		CHAR_SIZE equ 1	; Bytes
		
		WRITE_CMD equ 1	; Code of write syscall
		
		TO_ADDRESS_FACTOR equ 3	; Is used to go from format char to jmp_table address
		
		STACK_ALLIGN equ 8	; Bytes
		
		
		mov r15, STACK_ALLIGN * 2	; Offset to get arguments from stack
						; concerning ret address and previous rbp are in stack
						
		mov r14, [rbp + r15]	; Grab format string
		add r15, STACK_ALLIGN
		
		xor r13, r13	; Written chars counter


	str_scan:
	
		cmp byte [r14], 0
		je str_end 
		
		cmp byte [r14], '%'		
		je frmt_proc
		
		jmp common_char
		
					
	str_end:
	
		multipop rax, rbx, rdx, rdi, rsi, r14, r15

				;[EPILOG]
		pop rbp
		ret


	frmt_proc:
	
		inc r14

		cmp byte [r14], '%'
		je percent_proc
		
				;[PROCESS NON-PERCENT FORMAT]
		xor rbx, rbx
		mov bl, [r14]
		sub bl, 'b'
		shl rbx, TO_ADDRESS_FACTOR	; to make an address

		jmp jmp_table[rbx]		


	common_char:
	
		mov rax, WRITE_CMD
		mov rdi, STDOUT
		mov rsi, r14	; String to write from
		mov rdx, CHAR_SIZE
		
		syscall
		
		
		inc r13	
		inc r14
		jmp str_scan	


	chr_proc:
	
		mov rax, WRITE_CMD
		
		lea rsi, [rbp + r15]
		add r15, STACK_ALLIGN
		
		mov rdi, STDOUT
		mov rdx, CHAR_SIZE
		
		syscall
		
		
		inc r13		
		inc r14		; Next str symbol
		jmp str_scan
		

	str_proc:
		
		mov rdi, [rbp + r15]
		call strlen	; Length -> rdx
		add r13, rdx	; Take in account argument str length
		
		mov rax, WRITE_CMD
		mov rdi, STDOUT
		mov rsi, [rbp + r15]	; string pointer -> rsi
		add r15, STACK_ALLIGN
		
		syscall
		
		inc r14
		jmp str_scan


	dec_proc:
	
		mov rax, [rbp + r15]
		add r15, STACK_ALLIGN

		mov rbx, 10d
		mov rdi, integer
		
		call itoa
		
		jmp int_proc


	hex_proc:
	
		mov rax, [rbp + r15]
		add r15, STACK_ALLIGN

		mov cl, 4d	; 16 = 2 ^ [4]
		mov rdi, integer
		call itoa2
		
		jmp int_proc


	oct_proc:
	
		mov rax, [rbp + r15]
		add r15, STACK_ALLIGN

		mov cl, 3d	; 8 = 2 ^ [3]
		mov rdi, integer
		call itoa2
		
		jmp int_proc
		
	bin_proc:
	
		mov rax, [rbp + r15]
		add r15, STACK_ALLIGN

		mov cl, 1d	; 2 = 2 ^ [1]
		mov rdi, integer
		call itoa2
		
		jmp int_proc


	int_proc:
		
		mov rdi, integer
		call strlen
		add r13, rdx	; Take in account length of str(int)
		
		mov rax, WRITE_CMD
		mov rdi, STDOUT
		mov rsi, integer
		
		syscall

		inc r14
		jmp str_scan


	percent_proc:
	
		jmp common_char


	alert_unknwn_frmt:
			
		mov rax, WRITE_CMD
		mov rdi, STDOUT
		mov rsi, alert_unknwn_frmt_str
		mov rdx, 24	; Length of error message
		
		syscall
				
		xor r13, r13
		dec r13
		jmp str_end		


alert_unknwn_frmt_str db '%[ERROR:Unknown format]', 0x0a, 0


;--------------------------------------
;
;
;		[SET_JMP]:macros
;
;
;[descript]:
;
;	Converts letter arg (1st) into address
;	Than puts procedure arg (2nd) into this address in jmp_table
;
;
;--------------------------------------

%macro SET_JMP 2

		xor rbx, rbx
		mov rax, %2
		mov rbx, (%1 - 'b')
		shl rbx, TO_ADDRESS_FACTOR
		mov qword jmp_table[rbx], rax

%endmacro


;--------------------------------------
;
;
;		[PRP_JMP_TABLE]
;
;[descript]:
;
;	Prepares jmp_table for printf
;
;
;--------------------------------------

prp_jmp_table:

		xor rbx, rbx
		
		SET_JMP 'c', chr_proc

		SET_JMP 's', str_proc
		
		SET_JMP 'd', dec_proc
		
		SET_JMP 'o', oct_proc
		
		SET_JMP 'b', bin_proc
		
		SET_JMP 'x', hex_proc
		
		
		ret
		
		
;--------------------------------------
;
;
;		[ITOA_STACK]
;
;[params]:
;
;	1) integer to print
;
;	2) base (in which base should be transfered)
;	
;	3) offset in segment
;
;[return]:
;
;	puts string in user's memory
;
;
;--------------------------------------

itoa_stack:

				;[PROLOG]	
		push rbp
		mov rbp, rsp
				
		multipush rax, rbx, rdi	


				;[PARAMS]
					
		mov rdi, [rbp + 2 * STACK_ALLIGN]
		mov rbx, [rbp + 3 * STACK_ALLIGN]
		mov rax, [rbp + 4 * STACK_ALLIGN]
		
		call itoa

		multipop rax, rbx, rdi	
					;[EPILOG]
		pop rbp	
							
		ret STACK_ALLIGN * 3
		
		
;--------------------------------------
;
;
;		[ITOA]
;
;[params]:
;
;	rax - integer to print
;
;	rbx - base (to)
;
;	rdi - enough memory to store stringed-integer
;
;[return]:
;
;	puts string in user's memory
;
;[destroy]:
;
;	rax, rbx, rcx, rdx, rdi, rdi, rbp
;
;
;--------------------------------------

itoa:

		multipush rax, rbx, rcx, rdx, rdi, rbp

		mov rbp, rdi	
		
	.poka:		
		xor rdx, rdx			
		idiv rbx
		
		mov cl, ma_alpha[rdx]	; char (rax % rbx) -> rcx
		mov [byte rdi], cl
		inc rdi
		
		cmp rax, 0 
		jne .poka
		
		mov cl, 0
		mov [rdi], cl

		sub rdi, rbp	; Calculate length
		mov rcx, rdi
		mov rdi, rbp	; Recover source pointer
		
		call reverse_str
		
		
		multipop rax, rbx, rcx, rdx, rdi, rbp

		ret


;--------------------------------------
;
;
;		[ITOA2]
;
;[params]:
;
;	rax - integer to print
;
;	cl - base (2's degree)
;
;	rdi - enough memory to store stringed-integer
;
;[return]:
;
;	puts string in user's memory
;
;[destroy]:
;
;	rax, rbx, rcx, rdx, rdi, rdi, rbp
;
;--------------------------------------
itoa2:

		multipush rax, rbx, rcx, rdx, rdi, rbp, r13

		mov rbp, rdi	
		; rax - argument integer
		
		mov dl, cl
		
		mov r13, 1
		
	.make_mask:
			
		dec dl
		cmp dl, 0
		je .mask_is_ready
	
		shl r13, 1
		inc r13
		
		jmp .make_mask
		
	.mask_is_ready:
	
		
	.poka:		
		mov rdx, rax
		and rdx, r13
		
		shr rax, cl
		
		mov bl, ma_alpha[rdx]	; char (rax % rbx) -> rcx
		mov [byte rdi], bl
		inc rdi
		
		cmp rax, 0 
		jne .poka
		
		mov bl, 0
		mov [rdi], bl

		sub rdi, rbp	; Calculate length
		mov rcx, rdi
		mov rdi, rbp	; Recover source pointer
		
		call reverse_str
		
		multipop rax, rbx, rcx, rdx, rdi, rbp, r13

		ret


;--------------------------------------
;
;
;		[REVERSE_STR]
;
;[descript]:
;
;	Reverse string
;
;[params]:
;
;	rcx - length of string
;
;	rdi - adress of string to be reversed
;
;[return]:
;
;	reversed string stored in user's adress
;
;[destroy]:
;
;	rbx, rcx, rdx, rdi, rbp
;
;
;--------------------------------------

reverse_str:
		
		multipush rbx, rcx, rdx, rdi, rbp
	
		mov rbp, rdi
		dec rcx
		add rbp, rcx	; Now rbp points to end of string

	.poka:
		mov dl, [rdi]
		mov bl, [rbp]
		mov [rbp], dl
		mov [rdi], bl

		dec rbp
		inc rdi
		
		cmp rbp, rdi
		jg .poka			
	
		multipop rbx, rcx, rdx, rdi, rbp

		ret

	
;--------------------------------------
;
;
;		[STRLEN]
;
;[params]:
;
;	rdi - address of string to len
;
;[return]:
;
;	rdx - string length
;
;[destroy]:
;
;	rax, rcx, rdi
;
;
;--------------------------------------

strlen:
	
	multipush rax, rcx, rdi

	MAX_STR_LEN equ 200d
	mov al, 0
	mov rcx, MAX_STR_LEN
	mov rdx, rdi
	repne scasb
	
	sub rdi, rdx
	xchg rdx, rdi
	dec rdx		; '\0' is not concerned
	
	multipop rax, rcx, rdi
	
	ret


;--------------------------------------


section .data

ma_alpha db '0123456789ABCDEF'

integer db 'aboba_squad', 0

jmp_table dq ('x' - 'b' + 1) DUP(alert_unknwn_frmt)

test_str db 'meow', 0
ma_str db '%d', 0x0a, 0
int_print db '%d', 0

