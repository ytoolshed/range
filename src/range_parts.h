/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#ifndef RANGE_PARTS_H
#define RANGE_PARTS_H

#include <apr_pools.h>

typedef struct node_parts_int
{
    const char* prefix;
    const char* domain;
    int num;
    const char* num_str;
    const char* full_name;
} node_parts_int;

node_parts_int* node_to_parts(apr_pool_t* pool, const char* node_name);
void init_range_parts(void);

#define NUMBERED_NODE_RE   "^([-\\w.]*?)(\\d+)(\\.[-A-Za-z\\d.]*[-A-Za-z]+[-A-Za-z\\d.]*)?$"

#endif
