/*
 * Program to demo features in LowFat with redzone.
 *
 */

#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) 
{
	// allocation region: 8 + 32 = 40, round up to 48
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
		// valid write inside buf, no error
		buf[2] = to_write;
		break;
	case 2: 
		// valid write inside another_buf, no error. The offset is chosen because 
		// the distance between the two allocated object should be 48 bytes.
		buf[49] = to_write;
		break;
	case 3:
		// valid write to unused region in the buf allocation, no error
		buf[10] = to_write;
		break;
	case 4:
		// ERROR: underflow to own redzone
		buf[-2] = to_write;
		break;
	case 5:
		// ERROR: overflow, but is catched as underflow to another_buf redzone
		buf[47] = to_write;
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
