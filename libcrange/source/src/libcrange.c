/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#include <assert.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <dlfcn.h>
#include <pcre.h>
#include <errno.h>
#include <apr_pools.h>
#include <apr_strings.h>

#include "libcrange.h"
#include "range.h"
#include "range_compress.h"
#include "perl_functions.h"
#include "range_request.h"

libcrange* static_lr = NULL;
static int initd = 0;

static int parse_config_file(libcrange* lr);
libcrange* libcrange_new(apr_pool_t* pool, const char* config_file)
{
    libcrange* lr;

    if (!initd) {
        initd = 1;
        apr_initialize();
        atexit(apr_terminate);
    }

    lr = apr_palloc(pool, sizeof(libcrange));
    lr->pool = pool;
    lr->caches = set_new(pool, 0);
    lr->default_domain = NULL;
    lr->funcdir = LIBCRANGE_FUNCDIR;
    lr->want_caching = 1;
    lr->config_file = config_file ? config_file : LIBCRANGE_CONF;
    lr->functions = set_new(pool, 0);
    lr->perl_functions = NULL;
    lr->vars = set_new(pool, 0);

    if (access(lr->config_file, R_OK) != 0)
        return lr; /* no config file, don't load any modules */

    if (parse_config_file(lr) < 0)
        return NULL;

    return lr;
}

char* libcrange_get_pcre_substring(apr_pool_t* pool, const char* string,
                             int offsets[], int substr)
{
    int idx = substr * 2;
    char* new_str;
    int size = offsets[idx+1] - offsets[idx];
    
    if (size == 0)
        return "";
    
    new_str = apr_palloc(pool, size + 1);
    memcpy(new_str, &string[offsets[idx]], size);
    new_str[size] = '\0';
    return new_str;
}

apr_pool_t* libcrange_get_pool(libcrange* lr)
{
    return lr->pool;
}

const char* libcrange_get_default_domain(libcrange* lr)
{
    assert(lr);
    return lr->default_domain;
}

static apr_pool_t* static_pool = NULL;
static void destroy_static_pool(void)
{
    apr_pool_destroy(static_pool);
}

libcrange* get_static_lr(void)
{
    if (static_lr == NULL) {
        apr_pool_create(&static_pool, NULL);
        static_lr = libcrange_new(static_pool, NULL);
        atexit(destroy_static_pool);
    }

    return static_lr;
}

void libcrange_set_default_domain(libcrange* lr, const char* domain)
{
    lr->default_domain = apr_pstrdup(lr->pool, domain);
}

const char* libcrange_get_perl_module(libcrange* lr, const char* funcname)
{
    assert(lr);
    if (lr->perl_functions)
        return set_get_data(lr->perl_functions, funcname);
    else
        return NULL;
}

void* libcrange_get_function(libcrange* lr, const char* funcname)
{
    set* functions;
    assert(lr);
    assert(funcname);

    functions = lr->functions;
    return set_get_data(functions, funcname);
}


void* libcrange_get_cache(libcrange* lr, const char* name)
{
    set_element* se;
    if (lr == NULL) lr = get_static_lr();

    if ((se = set_get(lr->caches, name)))
        return se->data;
    else
        return NULL;
}

void libcrange_clear_caches(libcrange* lr)
{
    if (lr == NULL) lr = get_static_lr();
    lr->caches = set_new(lr->pool, 317);
}

void libcrange_set_cache(libcrange* lr, const char* name, void* data)
{
    if (lr == NULL) lr = get_static_lr();
    if (lr->want_caching)
        set_add(lr->caches, name, data);
}

const char* range_compress(libcrange* lr, apr_pool_t* p, const char** nodes)
{
    range* r;
    range_request* rr;

    if (lr == NULL) lr = get_static_lr();
    assert(lr);

    rr = range_request_new(lr, p);

    r = range_from_hostnames(rr, nodes);
    return do_range_compress(rr, r);
}

range_request* range_expand(libcrange* lr, apr_pool_t* pool, const char* text)
{
    range_request* rr;

    if (lr == NULL) lr = get_static_lr();
    assert(lr);

    rr = range_request_new(lr, pool);
    do_range_expand(rr, text);

    return rr;
}

range_request* range_expand_rr(range_request* rr, const char* text)
{
    assert(rr);
    do_range_expand(rr, text);
    return rr;
}

void libcrange_want_caching(libcrange* lr, int want)
{
    if (lr == NULL) lr = get_static_lr();
    lr->want_caching = want;
}

const char* libcrange_get_version(void)
{
    return LIBCRANGE_VERSION;
}

const char* libcrange_getcfg(libcrange* lr, const char* what)
{
    if (lr == NULL) lr = get_static_lr();

    return set_get_data(lr->vars, what);
}

static const char** get_function_names(libcrange* lr, void *handle,
                                       const char* module)
{
    const char** (*f)(libcrange*);
    const char* err;

    *(void **)(&f) = dlsym(handle, "functions_provided");
    if ((err = dlerror()) != NULL) {
        fprintf(stderr, "Module %s: error getting functions_provided()\n",
                module);
        return NULL;
    }

    return (*f)(lr);
}

static int add_function(libcrange* lr, set* functions, void* handle,
                        const char* module, const char* prefix,
                        const char* function)
{
    void *f; /* it's actually a function pointer but since we're adding it
              * to a set, let's leave it as void * */
    const char* err;
    char function_name[512] = "rangefunc_";
    strncat(function_name, function, sizeof function_name);
    function_name[sizeof function_name - 1] = '\0';

    f = dlsym(handle, function_name);
    if ((err = dlerror()) != NULL) {
        fprintf(stderr, "Module %s: error getting %s\n",
                module, function_name);
        return 1;
    }

    /* reusing function_name */
    assert(strlen(prefix) < 16);
    assert(strlen(function) < 256);

    strcpy(function_name, prefix);
    strcat(function_name, function);
    set_add(functions, function_name, f);
    return 0;
}

static int add_functions_from_module(libcrange* lr, set* functions,
                                     const char* module, const char* prefix)
{
    void* handle;
    char filename[512];
    const char** all_functions;

    snprintf(filename,
             sizeof filename,
             "%s/%s.so",
             /* if absolute path, don't use funcdir
 *              bit of a hack. FIXME need better handling
 *              for setting funcdir and other implied paths
 *              in the conf
             */
             module[0] == '/' ? "" : lr->funcdir,
             module);
    filename[sizeof filename - 1] = '\0';

    if (access(filename, R_OK) != 0) {
        fprintf(stderr, "module %s (can't read %s.)\n",
                module, filename);
        return 1;
    }

    if ((handle = dlopen(filename, RTLD_NOW)) == NULL) {
        fprintf(stderr, "%s: can't dlopen: %s\n", filename, dlerror());
        return 1;
    }

    dlerror(); /* Clear any existing errors */

    all_functions = get_function_names(lr, handle, module);
    if (all_functions == NULL)
        return 1;

    while (*all_functions) {
        int err = add_function(lr, functions, handle,
                               module, prefix, *all_functions++);
        if (err != 0)
            return err;
    }

    return 0;
}

#define LOADMODULE_RE "^\\s*loadmodule\\s+([-\\S]+)(?:\\s+prefix=([-\\w]+))?\\s*$"
#define PERLMODULE_RE "^\\s*perlmodule\\s+([-\\S]+)(?:\\s+prefix=([-\\w]+))?\\s*$"
#define VAR_RE "^\\s*([-\\w]+)\\s*=\\s*(\\S+)\\s*$"

static int parse_config_file(libcrange* lr)
{
    int ovector[30];
    const char* error;
    int err_offset;
    int line_no = 0;
    char line[256];
    pcre* loadmodule_re;
    pcre* perlmodule_re;
    pcre* var_re;
    FILE* fp;
    const char* config_file;

    set* functions;
    set* perl_functions = NULL;
    set* vars;

    assert(lr);
    assert(lr->config_file);

    config_file = lr->config_file;

    if (config_file == NULL) return 0;
    fp = fopen(config_file, "r");
    if (!fp) {
        fprintf(stderr, "%s: (%d) %s\n",
                config_file, errno, strerror(errno));
        return -1;
    }

    functions = lr->functions;
    vars = lr->vars;

    /* compile the regex */
    loadmodule_re = pcre_compile(LOADMODULE_RE, 0, &error,
                                  &err_offset, NULL);
    var_re = pcre_compile(VAR_RE, 0, &error,
                          &err_offset, NULL);

    perlmodule_re = pcre_compile(PERLMODULE_RE, 0, &error,
                                  &err_offset, NULL);
    assert(loadmodule_re);
    assert(var_re);
    assert(perlmodule_re);

    while (fgets(line, sizeof line, fp)) {
        int err;
        int count;
        int n = strlen(line);
        const char* module;
        const char* prefix;
        const char* var;
        const char* value;

        ++line_no;
        if (line[n - 1] != '\n') {
            fprintf(stderr, "%s:%d line too long - aborting\n",
                    lr->config_file, line_no);
            fclose(fp);
            return -1;
        }
        if (line[0] == '#') continue;

        line[--n] = '\0'; /* chop */
        if (!n) continue;

        /* if it's a loadmodule line */
        count = pcre_exec(loadmodule_re, NULL, line, n,
                          0, 0, ovector, 30);
        if (count > 1) {
            module = &line[ovector[2]];
            line[ovector[3]] = '\0';
            if (count > 2) {
                prefix = &line[ovector[4]];
                line[ovector[5]] = '\0';
            }
            else
                prefix = "";

            err = add_functions_from_module(lr, functions, module, prefix);

            if (err) {
                fclose(fp);
                return -1;
            }

            continue;
        }

        /* var = expression */
        count = pcre_exec(var_re, NULL, line, n,
                          0, 0, ovector, 30);
        if (count > 1) {
            var = &line[ovector[2]];
            line[ovector[3]] = '\0';

            value = &line[ovector[4]];
            line[ovector[5]] = '\0';

            set_add(vars, var, apr_pstrdup(lr->pool, value));

            continue;
        }

        /* perlmodule */
        count = pcre_exec(perlmodule_re, NULL, line, n,
                          0, 0, ovector, 30);
        if (count > 1) {
            module = &line[ovector[2]];
            line[ovector[3]] = '\0';
            if (count > 2) {
                prefix = &line[ovector[4]];
                line[ovector[5]] = '\0';
            }
            else
                prefix = "";

            if (!perl_functions)
                perl_functions = set_new(lr->pool, 0);

            err = add_functions_from_perlmodule(lr, lr->pool,
                                                perl_functions, module, prefix);

            if (err) {
                fclose(fp);
                return -1;
            }

            continue;
        }

        /* don't know how to parse: not a loadmoule or var=value */
        fprintf(stderr, "%s:%d syntax error [%s]\n",
                lr->config_file, line_no, line);
        fclose(fp);
        return -1;
    }

    fclose(fp);

    lr->perl_functions = perl_functions;
    lr->functions = functions;
    lr->vars = vars;
    return 0;
}
