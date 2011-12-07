/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#include <assert.h>
#include <stdarg.h>
#include <apr_strings.h>

#include "range_request.h"
#include "range.h"
#include "libcrange.h"
#include "set.h"
#include "range_compress.h"

struct range_request {
    apr_pool_t* pool;
    char* warnings;
    set* warn_type;
    int warn_enabled;
    struct libcrange* lr;
    range* r;
};

range_request* range_request_new(struct libcrange* lr, apr_pool_t* pool) 
{
    range_request* res = apr_palloc(pool, sizeof(range_request));
    res->lr = lr;
    res->pool = pool;
    res->warnings = NULL;
    res->warn_type = NULL;
    res->warn_enabled = 1;
    res->r = NULL;

    return res;
}

int range_request_warn_enabled(range_request* rr) 
{
    return rr->warn_enabled;
}

void range_request_disable_warns(range_request* rr)
{
    rr->warn_enabled = 0;
}

void range_request_enable_warns(range_request* rr) 
{
    rr->warn_enabled = 1;
}

const char* range_request_compressed(range_request* rr)
{
    return do_range_compress(rr, rr->r);
}

range* range_request_results(range_request* rr)
{
    return rr->r;
}


libcrange* range_request_lr(range_request* rr)
{
    return rr->lr;
}

int range_request_has_warnings(range_request* rr)
{
    return rr->warnings || rr->warn_type;
}

const char* range_request_warnings(range_request* rr)
{
    /* for each of the different warning types, create a
     * warning of the type NO_CLUSTER: ks321-9 | NO_IP: pain,haides
     */
    char* result = NULL;
    if (!rr->warnings && !rr->warn_type) return "";
    
    if (rr->warn_type) {
        set_element** members = set_members(rr->warn_type);
        while (*members) {
            if (result) 
                result = apr_psprintf(rr->pool, "%s | %s: %s", result,
                                      (*members)->name,
                                      do_range_compress(rr, (*members)->data));
            else
                result = apr_psprintf(rr->pool, "%s: %s", (*members)->name,
                                      do_range_compress(rr, (*members)->data));
            members++;
        }
    }

    if (!rr->warnings) return result;

    if (result)
        result = apr_psprintf(rr->pool, "%s | %s", result, rr->warnings);
    else
        result = rr->warnings;

    return result;
}

const char** range_request_nodes(range_request* rr)
{
    assert(rr->r);
    return range_get_hostnames(rr->pool, rr->r);
}

void range_request_warn(range_request* rr, const char* fmt, ...)
{
    va_list ap;
    char* p = rr->warnings;
    char* warn;

    if (!rr->warn_enabled) return;
    
    va_start(ap, fmt);
    warn = apr_pvsprintf(rr->pool, fmt, ap);
    va_end(ap);

    if (p)
        rr->warnings = apr_psprintf(rr->pool, "%s|%s", p, warn);
    else
        rr->warnings = warn;
}

void range_request_warn_type(range_request* rr, const char* type, const char* node)
{
    range* nodes;

    if (!rr->warn_enabled) return;

    if (!rr->warn_type)
        rr->warn_type = set_new(rr->pool, 0);

    /* nodes that generated a particular warning type */
    nodes = set_get_data(rr->warn_type, type);

    if (!nodes) {
        nodes = range_new(rr);
        set_add(rr->warn_type, type, nodes);
    }

    range_add(nodes, node);
}

apr_pool_t* range_request_pool(range_request* rr)
{
    return rr->pool;
}

apr_pool_t* range_request_lr_pool(range_request* rr)
{
    return libcrange_get_pool(rr->lr);
}

void range_request_set(range_request* rr, range* r)
{
    rr->r = r;
}

