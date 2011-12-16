/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#ifndef _PERL_FUNCTIONS_H
#define _PERL_FUNCTIONS_H

#include "librange.h"
#include "set.h"
#include "range.h"

int add_functions_from_perlmodule(librange* lr, apr_pool_t* pool,
                                  set* perlfunctions,
                                  const char* module, const char* prefix);

range* perl_function(range_request* rr,
                     const char* funcname, const range** r);

#endif
