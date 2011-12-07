/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#ifndef SET_H
#define SET_H

#include <sys/types.h>
#include <apr_pools.h>

typedef struct set_element
{
    const char* name;
    void* data;
    struct set_element* next;
} set_element;

typedef struct set
{
    size_t hashsize;
    struct set_element** table;
    size_t members;
    apr_pool_t* pool;
} set;

char* set_dump(const set* s);
set_element* set_add(set* theset, const char* name, void* data);
set_element* set_get(const set* theset, const char* name);
void* set_get_data(const set* theset, const char* name);

set_element** set_members(const set* s);
set* set_remove(set* theset, const char* name);
set* set_new(apr_pool_t* pool, int hashsize);
void set_destroy(set* s);
set* set_union(apr_pool_t* pool, const set* s1, const set* s2);
void set_union_inplace(set* s, const set* s2);
set* set_intersect(apr_pool_t* pool, const set* s1, const set* s2);
set* set_diff(apr_pool_t* pool, const set* s1, const set* s2);
void set_diff_inplace(set* s, const set* s2);

#endif
