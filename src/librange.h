/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#ifndef LIBRANGE_H
#define LIBRANGE_H

#include <apr_pools.h>

#ifdef __cplusplus
extern "C"
{
#endif

#define LIBRANGE_VERSION "1.1"

/* stealing from http://www.gnu.org/prep/standards/html_node/Directory-Variables.html */
// #define LIBRANGE_CONF "@PREFIX@/etc/librange.conf"
// #define DEFAULT_SQLITE_DB "/usr/local/var/librange/range.sqlite"
// #define LIBRANGE_FUNCDIR "/usr/lib/librange"

struct librange;
typedef struct librange librange;

struct range_request;
typedef struct range_request range_request;

/* These are the commonly used functions - pass lr == NULL unless
 * you're doing something special */
const char* range_compress(librange* lr, apr_pool_t* pool,
                           const char** nodes);

struct range_request* range_expand(librange* lr, apr_pool_t* pool,
                                   const char* text);


struct range_request* range_expand_rr(range_request* rr, const char* text);

/* return a compressed version of this range_request results */
const char* range_request_compressed(struct range_request* rr);

/* the warnings for this range request */
const char* range_request_warnings(struct range_request* rr);

/* the result as a NULL terminated array of strings */
const char** range_request_nodes(struct range_request* rr);

/* did we generate warnings */
int range_request_has_warnings(struct range_request* rr);

/* get the current library version */
const char* librange_get_version(void);

/* get the librange* from this range_request */
struct librange* range_request_lr(range_request* rr);

/* these functions are mostly used by the modules */
librange* librange_new(apr_pool_t* pool, const char* config_file);
apr_pool_t* librange_get_pool(librange* lr);
void librange_set_cache(librange* lr, const char *name, void *data);
void* librange_get_cache(librange* lr, const char *name);
void librange_clear_caches(librange* lr);
void librange_want_caching(librange* lr, int want);
const char* librange_getcfg(librange* lr, const char* what);
void librange_set_default_domain(librange* lr, const char* domain);
const char* librange_get_perl_module(librange* lr, const char* funcname);
const char* librange_get_default_domain(librange* lr);
void* librange_get_function(librange* lr, const char* funcname);
char* librange_get_pcre_substring(apr_pool_t* pool, const char* string,
                                   int offsets[], int substr);

#ifdef __cplusplus
}
#endif

#endif
