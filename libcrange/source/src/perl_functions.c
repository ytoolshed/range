/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#include "perl_functions.h"
#include <apr_strings.h>

#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#define _QUOTEME(x) #x
#define QUOTEME(x) _QUOTEME(x)

#ifndef MODULE_PATH
 #define MODULE_PATH /var/libcrange/perl
#endif

#define PERLBOOT                                                        \
    "use strict;"                                                       \
    "use lib qw(" QUOTEME(MODULE_PATH) ");"                                  \
    "BEGIN{ push @INC, $ENV{PERLLIB} if $ENV{PERLLIB} };"                                  \
    "BEGIN{ push @INC, $ENV{PERL5LIB} if $ENV{PERL5LIB} };"                                  \
    "our %_FUNCTIONS;"                                                  \
    "sub ::libcrange_load_file {  my ( $lib, $prefix, $module ) = @_;"  \
    "  require qq($module.pm);"                                         \
    "  my @functions = $module->functions_provided;"                    \
    "  my @mapped_functions = map { qq($prefix$_) } @functions; "       \
    "  for (@functions) { $_FUNCTIONS{qq($prefix$_)} = \\&{qq(${module}::$_)}; }" \
    "  return @mapped_functions;"                                       \
    "}"                                                                 \
    "sub ::libcrange_call_func {"                                       \
    "  my $rr = shift;"                                                 \
    "  my $func = shift;"                                               \
    "  my @args = @_;"                                                  \
    "  my $fun_ref = $_FUNCTIONS{$func};"                               \
    "  die qq(No function $func\\n) unless $fun_ref;"                   \
    "  return $fun_ref->($rr, @args);"                                  \
    "}"

static void lr_init_shared_libs(pTHX);
static PerlInterpreter* perl_interp = NULL;

static const char**
get_exported_functions(libcrange* lr, apr_pool_t* pool,
                       const char* module, const char* prefix)
{
    int i, count;
    const char** functions;
    dSP;

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSViv((IVTYPE)lr)));
    XPUSHs(sv_2mortal(newSVpv(prefix, 0)));
    XPUSHs(sv_2mortal(newSVpv(module, 0)));
    PUTBACK;

    count = call_pv("::libcrange_load_file", G_EVAL | G_ARRAY);

    SPAGAIN;

    if (SvTRUE(ERRSV)) {
        fprintf(stderr, "Calling ::libcrange_load_file: %s", SvPV_nolen(ERRSV));
        functions = NULL;
    }
    else {
        functions = apr_palloc(pool, sizeof(char*) * (count + 1));
        functions[count] = NULL;

        for (i=0; i<count; ++i) {
            STRLEN n_a;
            functions[i] = apr_pstrdup(pool, POPpx);
            n_a = n_a; /* removed unused warning - needed for older perls */
        }
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return functions;
}

static void destruct_perl(void)
{
    PerlInterpreter* org_perl = PERL_GET_CONTEXT;

    if (!perl_interp) return;
    PERL_SET_CONTEXT(perl_interp);

    perl_destruct(perl_interp);
    perl_free(perl_interp);

    PERL_SET_CONTEXT(org_perl);
}

int add_functions_from_perlmodule(libcrange* lr, apr_pool_t* pool,
                                  set* perlfunctions,
                                  const char* module, const char* prefix)
{
    const char** exported_functions;
    const char** p;
    const char* module_copy = apr_pstrdup(pool, module);

    PerlInterpreter* org_perl = PERL_GET_CONTEXT;

    if (!perl_interp) {
        char* args[] = { "", "-e", PERLBOOT };

        perl_interp = perl_alloc();
        perl_construct(perl_interp);
        atexit(destruct_perl);
        perl_parse(perl_interp, lr_init_shared_libs,
                   sizeof(args) / sizeof(char*), args, NULL);
    }
    PERL_SET_CONTEXT(perl_interp);

    /* let's get the list of functions exported by this module */
    p = exported_functions = get_exported_functions(lr, pool,
                                                    module, prefix);

    PERL_SET_CONTEXT(org_perl);
    if (!p) return 0;

    while (*p) {
        /* function prefixFUNCTIONNAME implemented by module 'module' */
        set_add(perlfunctions, *p, (void*)module_copy);
        ++p;
    }

    return 0;
}

SV* range_to_array_ref(apr_pool_t* pool, const range* r)
{
    int i, n;
    const char** nodes;
    SV* result;
    AV* array;

    array = newAV();
    assert(r);

    n = r->nodes->members;
    av_unshift(array, n);

    nodes = range_get_hostnames(pool, r);
    for (i=0; i<n; i++) {
        av_store(array, i, newSVpv(nodes[i], 0));
    }

    assert(av_len(array) == (n - 1));
    result = newRV_noinc((SV*)array);
    return result;
}

static range* _perl_function(range_request* rr,
                     const char* funcname, const range** r)
{
    dSP;
    const range** p_r = r;
    range* ret = range_new(rr);
    SV* sv_range;
    int i, count;

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSViv((IVTYPE)rr)));
    XPUSHs(sv_2mortal(newSVpv(funcname, 0)));
    while (*p_r) {
        sv_range = range_to_array_ref(range_request_pool(rr), *p_r);
        XPUSHs(sv_2mortal(sv_range));
        ++p_r;
    }
    PUTBACK;

    count = call_pv("::libcrange_call_func", G_EVAL | G_ARRAY);

    SPAGAIN;

    if (SvTRUE(ERRSV)) {
        range_request_warn(rr, "Calling ::libcrange_call_func: %s",
                       SvPV_nolen(ERRSV));

    }
    else {
        for (i=0; i<count; ++i) {
            STRLEN n_a;
            char* node = POPpx; /* easier to check whether it's not null */
            assert(node);
            range_add(ret, node);
            n_a = n_a; /* removed unused warning - needed for older perls */
        }
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return ret;
}

range* perl_function(range_request* rr,
                     const char* funcname, const range** r)
{
    range* result;
    PerlInterpreter* org_perl = PERL_GET_CONTEXT;
    PERL_SET_CONTEXT(perl_interp);

    result = _perl_function(rr, funcname, r);

    PERL_SET_CONTEXT(org_perl);
    return result;
}


EXTERN_C void boot_DynaLoader (pTHX_ CV* cv);

static void lr_init_shared_libs(pTHX)
{
    char *file = __FILE__;

    /* DynaLoader is a special case */
    newXS("DynaLoader::boot_DynaLoader", boot_DynaLoader, file);
}
