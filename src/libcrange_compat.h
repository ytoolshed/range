/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#ifndef LIBCRANGE_COMPAT_H
#define LIBCRANGE_COMPAT_H

#ifdef LIBCRANGE_COMPAT
#include <apr_pools.h>

#ifdef __cplusplus
extern "C"
{
#endif

//#define LIBCRANGE_VERSION "1.0"
#define LIBCRANGE_VERSION LIBRANGE_VERSION

//struct libcrange;
//typedef struct libcrange libcrange;
/* get the libcrange* from this range_request */
//struct libcrange* range_request_lr(range_request* rr);
#define libcrange librange

/* get the current library version */
//const char* libcrange_get_version(void);
#define libcrange_get_version librange_get_version


/* these functions are mostly used by the modules */
//libcrange* libcrange_new(apr_pool_t* pool, const char* config_file);
#define libcrange_new librange_new

//apr_pool_t* libcrange_get_pool(libcrange* lr);
#define libcrange_get_pool librange_get_pool

//void libcrange_set_cache(libcrange* lr, const char *name, void *data);
#define libcrange_set_cache librange_set_cache

//void* libcrange_get_cache(libcrange* lr, const char *name);
#define libcrange_get_cache librange_get_cache

//void libcrange_clear_caches(libcrange* lr);
#define libcrange_clear_caches librange_clear_caches

//void libcrange_want_caching(libcrange* lr, int want);
#define libcrange_want_caching librange_want_caching

//const char* libcrange_getcfg(libcrange* lr, const char* what);
#define libcrange_getcfg librange_getcfg

//void libcrange_set_default_domain(libcrange* lr, const char* domain);
#define libcrange_set_default_domain librange_set_default_domain

//const char* libcrange_get_perl_module(libcrange* lr, const char* funcname);
#define libcrange_get_perl_module librange_get_perl_module

//const char* libcrange_get_default_domain(libcrange* lr);
#define libcrange_get_default_domain librange_get_default_domain

//void* libcrange_get_function(libcrange* lr, const char* funcname);
#define libcrange_get_function librange_get_function

//char* libcrange_get_pcre_substring(apr_pool_t* pool, const char* string,
//                                   int offsets[], int substr);
#define libcrange_get_pcre_substring librange_get_pcre_substring

#ifdef __cplusplus
}
#endif
#endif  // LIBCRANGE_COMPAT
#endif
