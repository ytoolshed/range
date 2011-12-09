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
// #define DEFAULT_SQLITE_DB "/usr/local/var/libcrange/range.sqlite"
// #define LIBRANGE_FUNCDIR "/usr/lib/libcrange"

struct libcrange;
typedef struct libcrange libcrange;

struct range_request;
typedef struct range_request range_request;

/* These are the commonly used functions - pass lr == NULL unless
 * you're doing something special */
const char* range_compress(libcrange* lr, apr_pool_t* pool,
                           const char** nodes);

struct range_request* range_expand(libcrange* lr, apr_pool_t* pool,
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
const char* libcrange_get_version(void);

/* get the libcrange* from this range_request */
struct libcrange* range_request_lr(range_request* rr);

/* these functions are mostly used by the modules */
libcrange* libcrange_new(apr_pool_t* pool, const char* config_file);
apr_pool_t* libcrange_get_pool(libcrange* lr);
void libcrange_set_cache(libcrange* lr, const char *name, void *data);
void* libcrange_get_cache(libcrange* lr, const char *name);
void libcrange_clear_caches(libcrange* lr);
void libcrange_want_caching(libcrange* lr, int want);
const char* libcrange_getcfg(libcrange* lr, const char* what);
void libcrange_set_default_domain(libcrange* lr, const char* domain);
const char* libcrange_get_perl_module(libcrange* lr, const char* funcname);
const char* libcrange_get_default_domain(libcrange* lr);
void* libcrange_get_function(libcrange* lr, const char* funcname);
char* libcrange_get_pcre_substring(apr_pool_t* pool, const char* string,
                                   int offsets[], int substr);

#ifdef __cplusplus
}
#endif

#endif
