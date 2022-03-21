;		[PRINTF]

global _start


section .text

;--------------------------------------
_start:

		call prp_jmp_table
	br1:
		push '!'
		push test_str
		push ma_str
		call printf
	br2:
		sub rsp, 2 * stack_allign	; free stack from fuction arguments
	br3:
		call exit
;--------------------------------------



;--------------------------------------
%macro  multipush 1-* 

  %rep  %0 
        push    %1 
  %rotate 1 
  %endrep 

%endmacro
;--------------------------------------



;--------------------------------------
%macro  multipop 1-* 

  %rep  %0 
        pop    %1 
  %rotate 1 
  %endrep 

%endmacro
;--------------------------------------



;--------------------------------------
exit:
	
	mov rax, 60
	mov rdi, 0
	
	syscall
;--------------------------------------


;--------------------------------------
;		[PRINTF] (cdecl)
;--------------------------------------
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
;--------------------------------------
;[params]:
;
;	1 - formatted string adress in DS
;
;	... - format params	
;--------------------------------------
;
;	rcx - number of written chars
;	or
;	FFFF - if format error occured
;--------------------------------------
printf:

				;[PROLOG]
		push rbp
		mov rbp, rsp
		
		;multipush rax, rbx, rdx, rdi, rsi, r14, r15
		
		stack_allign equ 8	; bytes
		
		
		mov r15, stack_allign * 2

		mov r14, [rbp + r15]	; grab format string
		add r15, stack_allign
		
		xor rcx, rcx


	str_scan:
	
		cmp byte [r14], 0
		je str_end 
		
		cmp byte [r14], '%'		
		je frmt_proc
		
		jmp common_char
		
					
	str_end:
	
		;multipop r15, r14, rsi, rdi, rdx, rbx, rax

				;[EPILOG]
		pop rbp
		ret


	frmt_proc:
	
		inc r14

		xor rbx, rbx
		mov bl, [r14]
		sub bl, 'b'
		shl rbx, 4	; to make an address

		jmp jmp_table[rbx]		


	common_char:
	
		mov rax, 1	; write
		mov rsi, r14
		mov rdi, 1	; stdout
		mov rdx, 1	; number of bytes
		
		syscall
		
		
		inc rcx	
		inc r14
		jmp str_scan	


	chr_proc:
	
		mov rax, 1	; write
		
		mov rsi, rbp	; mov rsi + rbp <- pointer to char arg
		add rsi, r15
		add r15, stack_allign	; mov to next stack argument
		
		mov rdi, 1	; stdout
		mov rdx, 1	; number of bytes
		
		syscall
		
		
		inc rcx		
		inc r14		; Next str symbol
		jmp str_scan
		

	str_proc:
		
		mov rdi, [rbp + r15]
		call strlen	; length -> rdx
		
		mov rax, 1	; write (rdi = stdout, rsi = str_pointer, rdx = bytes num)
		
		mov rdi, 1	; stdout
		
		mov rsi, [rbp + r15]	; string pointer -> rsi
		add r15, stack_allign
		
		syscall
		
		inc rcx
		inc r14
		jmp str_scan


	dec_proc:
	
		push qword [rbp + r15]
		sub r15, stack_allign

		push 10d
		
		jmp int_proc


	hex_proc:
	
		push qword [rbp + r15]
		sub r15, stack_allign
		
		push 16d
		
		jmp int_proc	


	oct_proc:
	
		push qword [rbp + r15]
		sub r15, stack_allign
		
		push 8d
		
		jmp int_proc

		
	bin_proc:
	
		push qword [rbp + r15]
		sub r15, stack_allign
		
		push 2d
		
		jmp int_proc


	int_proc:
	
		push integer
				
		call itoa_stack
		
		mov rdx, integer
		mov AH, 09h
		int 21h
		
		inc rcx
		
		inc rdi
		jmp str_scan


	prc_proc:
	
		mov DL, '%'
		mov AH, 02h
		int 21h
		
		inc rcx
		
		inc rdi
		jmp str_scan


	alert_unknwn_frmt:
	
		mov rdx, alert_unknwn_frmt_str
		mov rax, 1	; write
		int 21h
				
		xor rcx, rcx
		dec rcx
		jmp str_end		

alert_unknwn_frmt_str db '%[ERROR:Unknown format]', 0
;--------------------------------------


	
;--------------------------------------
%macro SET_JMP 2

		mov rax, %2
		mov rbx, (%1 - 'b')
		shl rbx, 4
		mov jmp_table[rbx], rax

%endmacro
;--------------------------------------
;		[PRP_JMP_TABLE]
;
;[descript]:
;
;	Prepares jmp_table for printf
;
;--------------------------------------
prp_jmp_table:

		xor rbx, rbx
		
		bit_depth equ 8	; byte
		
		SET_JMP 'c', chr_proc

		SET_JMP 's', str_proc
		
		;SET_JMP 'd', dec_proc
		
		;SET_JMP 'o', oct_proc
		
		;SET_JMP 'b', bin_proc
		
		;SET_JMP 'x', hex_proc
		
		;SET_JMP '%', prc_proc
		
		ret
;--------------------------------------



;------------------------------------------------
;		[ITOA via stack]
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
;------------------------------------------------
itoa_stack:

			;[PROLOG]
			
		push rbp
		mov rbp, rsp
				
		multipush rdi, rbx, rax


			;[PARAMS]
			
		mov rdi, [rbp - 2 * stack_allign]
		mov rbx, [rbp - 3 * stack_allign]
		mov rax, [rbp - 4 * stack_allign]
		
		call itoa

		multipop rax, rbx, rdi	
					;[EPILOG]
		pop rbp	
							
		ret 8
;------------------------------------------------


;------------------------------------------------
;		[itoa]
;
;[params]:
;
;	rax - integer to print
;
;	rbx - base (to)
;
;	rdi -/ enough memory to store stringed-integer
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
itoa:

		multipush rax,rbx,rcx,rdx,rdi,rdi,rbp

		mov rbp, rdi	

	.poka:		
		xor rdx, rdx			
		div rbx
		
		xchg rdi, rdx
		mov dl, ma_alpha[rdi]
		mov [rdi], dl
		inc rdi
		
		cmp rax, 0 
		jne .poka
		
		mov cl, 0
		mov [rdi], cl

		sub rdi, rbp	; Prepare rcx argument for prerevorot()
		mov rcx, rdi
		mov rdi, rbp
		
		call perevorot
		
		
		multipop rbp,rdi,rdi,rdx,rcx,rbx,rax

		ret
;--------------------------------------


;--------------------------------------
;		[perevorot]
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
;--------------------------------------
perevorot:
		
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
	
		multipop rbp,rdi,rdx,rcx,rbx

		ret
;--------------------------------------


;=======================================	
	
	
;--------------------------------------
;		[strlen]
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
	
	multipop rdi, rcx, rax
	
	ret
;--------------------------------------


;=======================================


;--------------------------------------
section .data

ma_alpha db '0123456789ABCDEF'
integer db 17 DUP(0)
jmp_table dq ('x' - 'b' + 1) DUP(alert_unknwn_frmt)

test_str db 'milk packets with fat', 0
ma_str db '%s %c', 0
