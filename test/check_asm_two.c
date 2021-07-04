// to check field access
struct node_t {
	int a, b;
};

int s(struct node_t *p) {
	int x = p -> a;
	int y = p -> b;
	return x + y;
}

int f(int *p) {
    int x = p[2];
    int y = p[3];
    return x + y;
}
