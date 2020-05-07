// to check asm and compare for non-pow2 and optimized
int h(int * p) {
    return p[3];
}

// to check how many base() operations are performed
int f(int *p)
{
    int i, s = 0;
    for (i = 0; i < 10; i++)
        s += p[i];
    return s;
}

int g(int *p, int *q)
{
    int s = 0;
    s += p[1];
    q[1] = 333;
    s += p[1];
    return s;
}

// to check whether emitting check if pointer has no arithmetic to it
int arith(int *p)
{
    int s = 0;
    s += p[0];
    return s;
}

// to check field access
struct node_t {
	int a, b;
};

int s(struct node_t *p) {
	int x = p -> a;
	int y = p -> b;
	return x + y;
}
