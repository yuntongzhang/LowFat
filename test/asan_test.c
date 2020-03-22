/*
 * Program to ensure proper features of ASAN are enabled.
 *
 */

#include <stdio.h>
#include <stdlib.h>

int global[8] = { 20, 21, 22, 23, 24, 25, 26, 27 };

void print_arr(char*, int*, size_t);
int main(int argc, char **argv) 
{
    int *heap = (int *)malloc(sizeof(int)*8);
    int *uaf = (int *)malloc(sizeof(int)*8);
    int i;
    for (i = 0; i < 8; i++) {
        heap[i] = i;
        uaf[i] = i;
    }
    free(uaf);

    int stack[8] = { 10, 11, 12, 13, 14, 15, 16, 17 };

    int pos = 10;
    int to_write = 99;
    int choice = atoi(argv[1]);
    switch (choice) 
    {
    case 1:
        // heap protection enabled
        heap[pos] = to_write;
        break;
    case 2:
        // stack protection disabled
        stack[pos] = to_write;
        break;
    case 3:
        // global protection disabled
        global[pos] = to_write;
        break;
    case 4: 
        // UAF disbaled
        uaf[1] = to_write;
        break;
    default:
        break;
    }

    print_arr("heap", heap, 8);
    print_arr("stack", stack, 8);
    print_arr("global", global, 8);
    free(heap);
	return 0;
}

void print_arr(char *name, int *arr, size_t size) {
    int i;
    fprintf(stderr, "%s: [", name);
    for (i = 0; i < size; i++) {
        fprintf(stderr, "%d,", arr[i]);
    }
    fprintf(stderr, "]\n");
}