;		[Call C-functions from assembly]

global main

extern sum

extern printf


section .text


;--------------------------------------


main:

		push rbp
		mov rbp, rsp

	%if 0	
		mov rdi, ma_str
		mov rsi, str_arg
		mov rdx, '!'
		
		call printf
	%endif 
	
	%if 1
		mov rdi, 5
		mov rsi, 6
		
		call sum
	%endif
		
		pop rbp
		mov rax, 0

		ret
		
		
;--------------------------------------


section .data

	ma_str db 'Hello %s %c', 0x0a, 0
	str_arg db 'World', 0

;--------------------------------------

section .data

