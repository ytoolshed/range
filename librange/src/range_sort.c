/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#include "range_sort.h"
#include "range_parts.h"
#include "range_request.h"
#include "range.h"

#include <assert.h>
#include <string.h>
#include <stdlib.h>

static int compare_parts(const node_parts_int** ptr_a, const node_parts_int** ptr_b)
{
    int pre, domain, num;
    const node_parts_int* a = *ptr_a;
    const node_parts_int* b = *ptr_b;

    pre = strcmp(a->prefix, b->prefix);
    if (pre) return pre;

    domain = strcmp(a->domain, b->domain);
    if (domain) return domain;

    num = a->num - b->num;
    if (num) return num;

    return strcmp(a->full_name, b->full_name);
}

const char** do_range_sort(range_request* rr, const range* r)
{
    const char** result;
    int n = r->nodes->members;
    apr_pool_t* pool = range_request_pool(rr);
    node_parts_int** parts = apr_palloc(pool, n * sizeof(node_parts_int*));
    set_element** members = set_members(r->nodes);
    int i;

    init_range_parts();
    for (i=0; i<n; ++i)
        parts[i] = node_to_parts(pool, members[i]->name);

    qsort(parts, n, sizeof(node_parts_int*),
          (int (*) (const void*, const void*)) compare_parts);

    result = apr_palloc(pool, sizeof(char*) * (n + 1));
    for (i=0; i<n; ++i) result[i] = parts[i]->full_name;
    result[n] = NULL;

    return result;
}
