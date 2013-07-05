/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include "libcrange.h"
#include <apr_pools.h>

int main(int argc, char const* const* argv)
{
    apr_pool_t* pool;
    struct range_request* rr;
    const char **nodes;
    int expand_flag = 0;
    int c;
    int debug = 0;
    struct libcrange *lr;
    char *config_file = NULL;

    apr_app_initialize(&argc, &argv, NULL);
    atexit(apr_terminate);
    apr_pool_create(&pool, NULL);

    while ((c = getopt (argc, argv, "edc:")) != -1) {
      switch (c)
      {
        case 'e':
          expand_flag = 1;
          break;
        case 'd':
          debug = 1;
          break;
        case 'c':
          config_file = optarg;
          break;
        case '?':
          fprintf (stderr, "Usage: crange [-e] <range>\n\n");
          return 1;
        default:
          abort ();
      }
    }

    debug && printf("DEBUG: argc: %d and optind: %d\n", argc, optind);
    if (optind + 1 != argc) {
      fprintf (stderr, "Usage: crange [-e] [-c] <range>\n\n");
      return 1;
    }

    config_file = config_file ? config_file : LIBCRANGE_CONF;
    debug && printf("DEBUG: using config_file of '%s'\n", config_file);
    lr = libcrange_new(pool, config_file);

    if (debug) {
        printf("DEBUG: after libcrange_new have an lr with attrs:\n");
        printf("DEBUG: lr->default_domain: %s\n", lr->default_domain);
        printf("DEBUG: lr->confdir: %s\n", lr->confdir);
        printf("DEBUG: lr->config_file: %s\n", lr->config_file);
        printf("DEBUG: lr->funcdir: %s\n", lr->funcdir);
        printf("DEBUG: lr->want_caching: %d\n", lr->want_caching);
        dump_hash_values(lr->vars);
        fprintf(stderr, "DEBUG: lr->vars: ");
        set_dump(lr->vars);
    }

    rr = range_expand(lr, pool, argv[argc-1]);
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
