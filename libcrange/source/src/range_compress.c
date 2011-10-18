/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#include "range_sort.h"

#include "range_compress.h"
#include "range.h"
#include "range_parts.h"
#include "range_request.h"

#include <string.h>
#include <stdio.h>
#include <apr_strings.h>

static node_parts_int* init_prev_parts(apr_pool_t* pool)
{
    node_parts_int* result = apr_palloc(pool, sizeof(node_parts_int));
    result->prefix = result->domain = result->num_str = result->full_name = "";
    result->num = -2;
    return result;
}

static const char* ignore_common_prefix(apr_pool_t* pool, int n1, int n2)
{
    char* s1 = apr_itoa(pool, n1);
    char* s2 = apr_itoa(pool, n2);
    int n, len1, len2;
    len1 = strlen(s1);
    len2 = strlen(s2);
    if (len1 < len2) return s2;
    n = 0;
    while (n < len1 && s1[n] == s2[n]) ++n;
    return s2 + n;
}

static const char* fmt_group(apr_pool_t* pool, node_parts_int* parts, int count)
{
    return apr_psprintf(pool, "%s%s-%s%s", parts->prefix, parts->num_str,
                        ignore_common_prefix(pool, parts->num, parts->num + count),
            parts->domain);
}

const char* do_range_compress(range_request* rr, const range* r)
{
    int i;
    #define MAX_NUM_GROUPS 65536
    const char* groups[MAX_NUM_GROUPS];
    int num_groups = 0;
    int count;
    char* result;
    char* presult;
    int result_size;
    const char** sorted_nodes;
    int n = r->nodes->members;
    apr_pool_t* pool = range_request_pool(rr);
    node_parts_int* prev = init_prev_parts(pool);
    int prev_num_str_len = -1;

    if (n == 0) return "";

    sorted_nodes = do_range_sort(rr, r);
    init_range_parts();

    count = 0;
    for (i=0; i<n; ++i) {
        node_parts_int* parts = node_to_parts(pool, sorted_nodes[i]);
        if (strcmp(parts->prefix, prev->prefix) == 0 &&
            strcmp(parts->domain,  prev->domain) == 0 &&
            (parts->num == prev->num + count + 1) &&
	    strlen(parts->num_str) == prev_num_str_len) count++;
        else {
            if (*prev->full_name) {
                if (count > 0)
                    groups[num_groups] = fmt_group(pool, prev, count);
                else
                    groups[num_groups] = prev->full_name;
                ++num_groups;
                if (num_groups == MAX_NUM_GROUPS) {
                    range_request_warn(rr, "%s\n", "too many compressed groups");
                    return "";
                }
            }
            prev = parts;
            if (prev->num_str)
                prev_num_str_len = strlen(prev->num_str);
            count = 0;
        }
    }
    if (count > 0)
        groups[num_groups] = fmt_group(pool, prev, count);
    else
        groups[num_groups] = prev->full_name;
    
    /* num_groups is 1 less than the # of groups */
    result_size = num_groups; /* commas */
    for (i=0; i<=num_groups; ++i) result_size += strlen(groups[i]);
    presult = result = apr_palloc(pool, result_size + 1);
    
    for (i=0; i<num_groups; ++i) {
        strcpy(presult, groups[i]);
        presult += strlen(groups[i]);
        *presult++ = ',';
    }
    
    /* add the last one */
    strcpy(presult, groups[num_groups]);
    return result;
}
