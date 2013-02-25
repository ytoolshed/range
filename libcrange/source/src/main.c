/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#include <stdio.h>
#include <stdlib.h>
#include "libcrange.h"
#include <apr_pools.h>

int main(int argc, char const* const* argv)
{
    apr_pool_t* pool;
    struct range_request* rr;
    const char **nodes;
    int expand_flag = 0;
    int c;

    apr_app_initialize(&argc, &argv, NULL);
    atexit(apr_terminate);
    apr_pool_create(&pool, NULL);

    while ((c = getopt (argc, argv, "e")) != -1) {
      switch (c)
      {
        case 'e':
          expand_flag = 1;
          break;
        case '?':
          fprintf (stderr, "Usage: crange [-e] <range>\n\n");
          return 1;
        default:
          abort ();
      }
    }

    if (argc > 3) {
      fprintf (stderr, "Usage: crange [-e] <range>\n\n");
      return 1;
    }

    rr = range_expand(NULL, pool, argv[argc-1]);
    if (expand_flag == 1) {
      nodes = range_request_nodes(rr);
      while (*nodes) {
        printf("%s\n", *nodes++);
      }
    } else {
      printf("%s\n", range_request_compressed(rr));
    }

    if (range_request_has_warnings(rr))
      printf("%s\n", range_request_warnings(rr));

    apr_pool_destroy(pool);
    return 0;
}
