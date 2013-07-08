/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <pcre.h>
#include <apr_strings.h>
#include "range.h"
#include "range_request.h"
#include "set.h"
#include "range_parser.h"
#include "range_scanner.h"
#include "perl_functions.h"
#include "ast.h"
#include "range_request.h"

int yyparse(void*);

static range_request* current_rr;
void yyerror(const char* s)
{
    range_request_warn(current_rr, "%s", s);
}

void range_destroy(range* r)
{
    set_destroy(r->nodes);
}

range* range_from_set(range_request* rr, set* s)
{
    apr_pool_t* p = range_request_pool(rr);
    range* r = apr_palloc(p, sizeof(range));
    r->nodes = s;
    r->quoted = 0;
    return r;
}

range* copy_range(apr_pool_t* pool, const range* r)
{
    range* new_range = apr_palloc(pool, sizeof(range));
    new_range->quoted = r->quoted;
    new_range->nodes = set_new(pool, 0);
    set_union_inplace(new_range->nodes, r->nodes);
    return new_range;
}

range* do_range_expand(range_request* rr, const char* text)
{
    yyscan_t scanner;
    struct range_extras extra;
    int result;

    if (text == NULL) {
        range* r = range_new(rr);
        range_request_set(rr, r);
        return r;
    }
    current_rr = rr;
    extra.rr = rr;

    yylex_init(&scanner);
    yyset_extra(&extra, scanner);
    yy_scan_string(text, scanner);
    result = yyparse(scanner);
    yylex_destroy(scanner);
    current_rr = NULL;

    if (result != 0) {
        range* r = range_new(rr);
        range_request_warn(rr, "parsing [%s]", text);
        range_request_set(rr, r);
        return r;
    }

    range_request_set(rr, range_evaluate(rr, extra.theast));
    return range_request_results(rr);
}

range* range_add(range* r, const char* text)
{
    assert(text);
    set_add(r->nodes, text, NULL);
    return r;
}

range* range_remove(range* r, const char* text)
{
    set_remove(r->nodes, text);
    return r;
}

const char** range_get_hostnames(apr_pool_t* pool, const range* r)
{
    const char** ret;
    set_element **members;
    int i;

    ret = apr_palloc(pool, sizeof(char*) * (r->nodes->members + 1));
    members = set_members(r->nodes);
    if (r->quoted) {
        for (i = 0; members[i]; i++) 
            ret[i] = apr_psprintf(pool, "\"%s\"", members[i]->name);
        ret[i] = NULL;
    } else {
        for (i = 0; members[i]; i++)
            ret[i] = members[i]->name;
        ret[i] = NULL;
    }
    return ret;
}

range* range_from_hostnames(range_request* rr,
                            const char** names)
{
    range* r;
    int i;

    r = range_new(rr);
    for(i = 0; names[i]; i++) 
        range_add(r, names[i]);

    return r;
}

range* range_new(range_request* rr)
{
    apr_pool_t* pool = range_request_pool(rr);
    range* r = apr_palloc(pool, sizeof(range));
    r->nodes = set_new(pool, 0);
    r->quoted = 0;
    return r;
}

range* range_from_null(range_request* rr)
{
    return range_new(rr);
}

range* range_from_match(range_request* rr,
                        const range* r, const char* regex)
{
    range* ret;
    int i;
    int err_offset;
    int ovector[30];
    int count;
    const char* error;
    const char** members;
    pcre* re;
    apr_pool_t* pool = range_request_pool(rr);
    
    members = range_get_hostnames(pool, r);
    ret = range_new(rr);

    re = pcre_compile(regex, 0, &error, &err_offset, NULL);
    if (!re) {
        range_request_warn(rr, "regex [%s] [%s]", regex, error);
        return ret;
    }

    for (i = 0; members[i]; i++) {
        count = pcre_exec(re, NULL, members[i],
                          strlen(members[i]), 0, 0, ovector, 30);
        if (count > 0) /* it matched */
            range_add(ret, members[i]);
    }
    pcre_free(re);

    return ret;
}

range* range_from_literal(range_request* rr,
                          const char* literal)
{
    range* r = range_new(rr);
    range_add(r, literal);
    return r;
}

range* range_from_nonrange_literal(range_request* rr,
                                   const char* literal)
{
    range* r = range_new(rr);
    range_add(r, literal);
    r->quoted = 1;
    return r;
}

range* range_from_braces(range_request* rr,
                         const range* r1, const range* r2, const range* r3)
{
    int i, j, k;
    set_element** m1;
    set_element** m2;
    set_element** m3;
    set* temp = NULL;
    range* bigrange;
    char* bundle;
    apr_pool_t* pool = range_request_pool(rr);
    
    if(r1->nodes->members == 0) {
        if(!temp) {
            temp = set_new(pool, 1);
            set_add(temp, "", NULL);
        }
        m1 = set_members(temp);
    } else m1 = set_members(r1->nodes);

    if(r2->nodes->members == 0) {
        if(!temp) {
            temp = set_new(pool, 1);
            set_add(temp, "", NULL);
        }
        m2 = set_members(temp);
    } else m2 = set_members(r2->nodes);

    if(r3->nodes->members == 0) {
        if(!temp) {
            temp = set_new(pool, 1);
            set_add(temp, "", NULL);
        }
        m3 = set_members(temp);
    } else m3 = set_members(r3->nodes);

    bigrange = range_new(rr);

    for(i = 0; m1[i]; i++)
        for(j = 0; m2[j]; j++)
            for(k = 0; m3[k]; k++) {
                bundle = apr_pstrcat(pool,
                                    m1[i]->name, m2[j]->name,
                                     m3[k]->name, NULL);
                range_add(bigrange, bundle);
            }

    if (temp) set_destroy(temp);
    bigrange->quoted = r1->quoted || r2->quoted || r3->quoted;
    return bigrange;
}

range* range_from_union(range_request* rr,
                        const range* r1, const range* r2)
{
    range* r3 = range_new(rr);
    apr_pool_t* pool = range_request_pool(rr);
    
    r3->nodes = set_union(pool, r1->nodes, r2->nodes);
    r3->quoted = r1->quoted || r2->quoted;
    return r3;
}

void range_union_inplace(range_request* rr,
                         range* dst, const range* src)
{
    set_union_inplace(dst->nodes, src->nodes);
}

range* range_from_inter(range_request* rr,
                        const range* r1, const range* r2)
{
    range* r3 = range_new(rr);
    apr_pool_t* pool = range_request_pool(rr);
    
    r3->nodes = set_intersect(pool, r1->nodes, r2->nodes);
    r3->quoted = r1->quoted || r2->quoted;
    return r3;
}

void range_diff_inplace(range_request* rr,
                        range* dst, const range* r2)
{
    set_diff_inplace(dst->nodes, r2->nodes);
}

range* range_from_diff(range_request* rr,
                       const range* r1, const range* r2)
{
    range* r3 = range_new(rr);
    apr_pool_t* pool = range_request_pool(rr);
    
    r3->nodes = set_diff(pool, r1->nodes, r2->nodes);
    r3->quoted = r1->quoted || r2->quoted;
    return r3;
}

static rangeparts *rangeparts_new(apr_pool_t* pool)
{
    rangeparts* rp;

    rp = apr_palloc(pool, sizeof(rangeparts));
    rp->prefix = NULL;
    rp->first = 0;
    rp->last = 0;
    rp->domain = NULL;

    return rp;
}

rangeparts *rangeparts_from_hostname(range_request* rr,
                                     const char* hostname)
{
    pcre* re;
    const char* error;
    rangeparts* rangeparts;
    int offset, count;
    int offsets[128];
    static pcre* regex_node = NULL;
    apr_pool_t* pool = range_request_pool(rr);
    
    if (!regex_node) 
        regex_node = pcre_compile(NODE_RE, 0, &error, &offset, NULL);

    re = regex_node;
    count = pcre_exec(re, NULL, hostname, strlen(hostname),
                      0, 0, offsets, sizeof(offsets)/sizeof(int));
    if (count > 0) {
        /*
         * 1 == prefix
         * 2 == range start
         * 3 == domain, maybe
         * 4 == range specifier: - or ..
         * 5 == range end
         * 6 == domain, maybe
         */
        rangeparts = rangeparts_new(pool);

        rangeparts->prefix = libcrange_get_pcre_substring(pool, hostname, offsets, 1);
        rangeparts->first = libcrange_get_pcre_substring(pool, hostname, offsets, 2);
        rangeparts->last =  libcrange_get_pcre_substring(pool, hostname, offsets, 5);
        
        if ((offsets[7] - offsets[6]) > 0) {
            /* if we have a domain */
            rangeparts->domain = libcrange_get_pcre_substring(pool, hostname, offsets, 3);
        } else if ((offsets[13] - offsets[12]) > 0) {
            rangeparts->domain = libcrange_get_pcre_substring(pool, hostname, offsets, 6);
        } else {
            rangeparts->domain = "";
        }
        /*
        if (hostname[offsets[8]] == '-') {
            range_request_warn_type(rr, "DEPRECATED_SYNTAX", hostname);
        }
        */
        
        return rangeparts;
    }

    return NULL;
}

range* range_from_rangeparts(range_request* rr,
                             const rangeparts* parts)
{
    int i;
    int f, l, firstlength, lastlength, length;
    range* r;
    char* pad1 = "";
    char* first;
    char* last;
    char* tmpstr;
    apr_pool_t* pool = range_request_pool(rr);
    
    r = range_new(rr);

    firstlength = strlen(parts->first);
    lastlength = strlen(parts->last);
    first = parts->first;
    last = parts->last;

    if (firstlength > lastlength) {
        pad1 = apr_palloc(pool, firstlength - lastlength + 1);
        for(i=0; i < (firstlength - lastlength); i++)
            pad1[i] = parts->first[i];
        pad1[i] = '\0';
        first = parts->first + i;
    }

    f = atoi(first);
    l = atoi(last);

    length = firstlength > lastlength ? lastlength : firstlength;

    for(i=f; i<=l; i++) {
        tmpstr = apr_psprintf(pool, "%s%s%0*d%s",
                             parts->prefix, pad1, length, i, parts->domain);
        range_add(r, tmpstr);
    }

    return r;
}

range* range_from_group(range_request* rr,
                        const range* r)
{
    const range* rl[2];
    range* ret;

    rl[0] = r;
    rl[1] = NULL;

    ret = range_from_function(rr, "group", rl);

    return ret;
}

range* range_from_function(range_request* rr,
                           const char* funcname, const range** r)
{
    range* ret;
    range* (*f)(range_request*, const range**);
    const char* perl_module;
    libcrange* lr = range_request_lr(rr);
    
    perl_module = libcrange_get_perl_module(lr, funcname);
    if (perl_module)
        ret = perl_function(rr, funcname, r);
    else {
        f = libcrange_get_function(lr, funcname);
        if (!f) {
        range_request_warn_type(rr, "NO_FUNCTION", funcname);
            return range_new(rr);
        }
        ret = (*f)(rr, r);
    }
    return ret;
}

/* true iff range **r has exactly expected_ranges elements before its null termination */
int validate_range_args(range_request* rr, range** r, int expected_ranges) {
    int i=0;
    if (0 == expected_ranges && NULL == r[1]) {
        // even 0 range functions have an arg. FIXME- why is this?
        return 1;
    }
    for (i=0; i < expected_ranges; i++) {
        if (NULL == r[i]) {
            /* not enough args*/
            return 0;
        }
    }
    if (NULL != r[i]) {
        /* too many args */
        return 0;
    }
    return 1;
}
