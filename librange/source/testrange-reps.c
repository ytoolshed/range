#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "range.h"


int main(int argc, char **argv) {
	struct nodes_t *result;
	long int i;
    char * compressed;
	if (argc < 2) {
		printf("argc is %d, needs args\n", argc);
		exit(1);
	}
	range_startup();
	printf("hello world\n");
	while (1) {
	result = range_expand(argv[1]);
	}
	return 0;
}
