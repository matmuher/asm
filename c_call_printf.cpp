//		[C-call of assembler function]

#include <stdio.h>

extern "C" void printf_c (const char* format_str, ...);

int main ()
	{
	br2:{}
	const char* a = "%d %s %d";
	printf_c (a, 44, "hello", 255);
	
	return 0;
	}