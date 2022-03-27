//		[Call C-function from assembly]

#include <stdio.h>

// [extern "C"] is used to avoid mangling

extern "C" int sum (int a, int b)
	{
	printf ("%d", a + b);
	
	return a + b;
	}