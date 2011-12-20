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
	result = expand_range(argv[1]);
    printf("done with expand range\n");
    if (result) {
      printf("got %d nodes\n", result->length);
      for (i = 0; i < result->length ; i++) {
        printf("string: '%s'\n", result->nodes[i]);
      }
    } else {
      printf("got exception!\n");
      fflush(NULL);
      printf("got ex, index: %d\n", get_exception());
      fflush(NULL);
      printf("got threw ex '%s'\n", get_exception_string());
      exit(88);
    }
    printf("now to compress it:\n");
    compressed = compress_range(result);
    free_nodes(result);
    printf("freed result ok!\n");
    if (compressed) {
      printf("compressed: '%s'\n", compressed);
    } else {
      printf("compressed threw exception\n");
      exit(89);
    }
    free(compressed);
    printf("freed compressed string\n");
    result = sorted_expand_range(argv[1]);
    for (i = 0; i < result->length ; i++) {
      printf("sort: '%s'\n", result->nodes[i]);
    }
    free_nodes(result);
    printf("freed result ok!\n");
    set_range_altpath("/tmp");
    /*    printf("parsed %%ks301,&/0$/: '%s'\n", parse_range("%ks301,&/0$/")); */
    printf("sleeping for 5 seconds ... ");
    fflush(NULL);
    sleep(5);
    printf("now setting up for big loop\n");
    for (i = 0; i < 30000; i++) {
      result = expand_range(argv[1]);
      free_nodes(result);
    }
    printf("sleeping for 10 more seconds ... ");
    fflush(NULL);
    sleep(10);
    printf("done!\n");
	return 0;
}
