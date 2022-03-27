//		[C-call of assembler function]

// #include <stdio.h>

extern "C" void printf_c (const char* format_str, ...);

int main ()
	{
	
	const char* test_str = "%d %s %b";
	printf_c (test_str, 44, "hello", 255);
	
	return 0;
	}