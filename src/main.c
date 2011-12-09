/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#include <stdio.h>
#include <stdlib.h>
#include "librange.h"
#include <apr_pools.h>

int main(int argc, char const* const* argv)
{
    apr_pool_t* pool;
    struct range_request* rr;

    apr_app_initialize(&argc, &argv, NULL);
    atexit(apr_terminate);
    apr_pool_create(&pool, NULL);

    rr = range_expand(NULL, pool, argv[1]);
    printf("%s\n", range_request_compressed(rr));

    if (range_request_has_warnings(rr))
        printf("%s\n", range_request_warnings(rr));

    apr_pool_destroy(pool);
    return 0;
}
