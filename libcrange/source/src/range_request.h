/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#ifndef _RANGE_REQUEST_H
#define _RANGE_REQUEST_H

#include "libcrange.h"

/* range request interface to be used by modules and
 * internal libcrange functions */

struct range;

range_request* range_request_new(libcrange* lr, apr_pool_t* pool);
void range_request_warn(range_request* rr, const char* fmt, ...);
void range_request_warn_type(range_request* rr, const char* type, const char* node);
int range_request_warn_enabled(range_request* rr);
void range_request_disable_warns(range_request* rr);
void range_request_enable_warns(range_request* rr);

apr_pool_t* range_request_pool(range_request* rr);
apr_pool_t* range_request_lr_pool(range_request* rr);
void range_request_set(range_request* rr, struct range* r);
struct range* range_request_results(range_request* rr);

#endif

