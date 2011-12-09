/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#include <assert.h>
#include <string.h>
#include <pcre.h>
#include "range_parts.h"
#include "librange.h"
#include <apr_strings.h>

static pcre* num_node_re = 0;

node_parts_int* node_to_parts(apr_pool_t* pool, const char* node_name)
{
    int offsets[64];
    int count;
    node_parts_int* result = apr_palloc(pool, sizeof(node_parts_int));
    result->full_name = node_name;
    count = pcre_exec(num_node_re, NULL, node_name, strlen(node_name),
                      0, 0, offsets, sizeof(offsets) / sizeof(int));
    if (count > 0) {
        result->prefix = libcrange_get_pcre_substring(pool, node_name, offsets, 1);
        result->num_str = libcrange_get_pcre_substring(pool, node_name, offsets, 2);
        result->num = atoi(result->num_str);
        result->domain = count > 3 ? libcrange_get_pcre_substring(pool, node_name, offsets, 3) : "";
    }
    else {
        result->prefix = "";
        result->domain = "";
        result->num_str = NULL;
        result->num = 0;
    }
    return result;
}

void init_range_parts(void)
{
    if (!num_node_re) {
        int offsets[20];
        const char* error;
        num_node_re = pcre_compile(NUMBERED_NODE_RE, 0, &error, offsets, NULL);
    }
    assert(num_node_re);
}
