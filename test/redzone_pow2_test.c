/*
 * Program to demo features in LowFat with redzone.
 * For pow2 version due to different region sizes.
 *
 */

#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) 
{
	// allocation size is (8+32=40) -> in the LowFat sub-heap region of size 64 (pow2).
	char *buf = (char *)malloc(sizeof(char)*8);
	char *another_buf = (char *)malloc(sizeof(char)*8);

	// fill in the two buffers
	int i;
	for (i = 0; i < 8; i++) {
		buf[i] = 'a';
		another_buf[i] = 'b';
	}

	char to_write = 'z';
	int choice = atoi(argv[1]); 
	switch (choice)
	{
	case 1: 
		// valid write inside buf, should never report as error.
		buf[2] = to_write;
		break;
	case 2: 
		// pointer arithmetic: valid write inside another_buf, should not be error.
		// red-LowFat does not report as error -> not false positive (FP) here.
		// The offset 65 is chosen because distance between starting address
		// of the two allocations is 64 bytes (in power-of-two red-LowFat).
		buf[65] = to_write;
		break;
	case 3:
		// same as case 2 but in a different form. 
		// should not be error, and red-LowFat does not report it -> no FP here.		
		*(buf+65) = to_write;
		break;
	case 4:
		// invalid write into un-allocated space, should be error.
		// red-LowFat detects this and report as error -> true positive (TP).		
		another_buf[35] = to_write;
		break;
	default:
		break;
	}

	// for reference
	printf("buf         = \"%s\"\n", buf);
	printf("another_buf = \"%s\"\n", another_buf);
	printf("diff        = %ld\n", another_buf - buf);
	return 0;
}
