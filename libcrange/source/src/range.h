/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#ifndef RANGE_H
#define RANGE_H

#include "libcrange.h"
#include "range_request.h"
#include "set.h"

#define NODE_RE "^"                                                     \
    /* valid hostname chars for a prefix */                             \
    "([-\\w.]*?)"                                                       \
    /* beginning of range */                                            \
    "(\\d+)"                                                            \
    /* an optional domain */                                            \
    "(\\.[-A-Za-z\\d.]*[-A-Za-z]+[-A-Za-z\\d.]*)?"                      \
    /* our range indicator: warn when using the deprecated - */         \
    "(-|\\.\\.)"                                                        \
    /* if they used a prefix, they can repeat it here */                \
    "\\1?"                                                              \
    /* the end of the range */                                          \
    "(\\d+)"                                                            \
    /* they can repeat the domain used before, or specify one now */    \
    "((?(3)\\3|(?:\\.[-A-Za-z\\d.]+)?))$"

typedef struct rangeparts
{
    char* prefix;
    char* first;
    char* last;
    char* domain;
} rangeparts;

typedef struct range
{
    set* nodes;
    int quoted;
} range;

typedef struct range_extras
{
    struct range_request* rr;
    char string_buf[32768];
    char* string_buf_ptr;
    struct rangeast* theast;
} range_extras;

typedef struct rangelist
{
    struct range* range;
    struct rangelist* next;
} funcargs;

#define range_members(r) ((r)->nodes->members)

range* copy_range(apr_pool_t* pool, const range* r);
range* do_range_expand(range_request* rr, const char* text);
const char** range_get_hostnames(apr_pool_t* pool, const range* r);
range* range_new(range_request* rr);

void range_union_inplace(range_request* rr, range* r1, const range* r2);
void range_diff_inplace(range_request* rr, range* r1, const range* r2);

rangeparts* rangeparts_from_hostname(range_request* rr, const char* hostname);
range* range_add(range* r, const char* text);
range* range_remove(range* r, const char* text);

range* range_from_match(range_request* rr,
                        const range* r, const char* regex);
range* range_from_hostnames(range_request* rr,
                            const char** names);
range* range_from_literal(range_request* rr,
                          const char* literal);
range* range_from_nonrange_literal(range_request* rr,
                                   const char* literal);
range* range_from_rangeparts(range_request* rr,
                             const rangeparts* parts);
range* range_from_parens(range_request* rr,
                         const range* r);
range* range_from_union(range_request* rr,
                        const range* r1, const range* r2);
range* range_from_braces(range_request* rr,
                         const range* left, const range* center,
                         const range* right);
range* range_from_diff(range_request* rr,
                       const range* r1, const range* r2);
range* range_from_inter(range_request* rr,
                        const range* r1, const range* r2);
range* range_from_group(range_request* rr,
                        const range* r);
range* range_from_function(range_request* rr,
                           const char* funcname, const range** r);
range* range_from_set(range_request* rr, set* s);

void range_destroy(range* r);

#endif
