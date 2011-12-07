#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "range.h"

/*

Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.

*/

MODULE = Seco::AwesomeRange	PACKAGE = Seco::AwesomeRange

BOOT:
	range_startup();
	sv_setsv( get_sv("Seco::AwesomeRange::librange_version", TRUE),
	          newSVpv(LIBRANGE_VERSION, 0)
                );

void
range_set_altpath(path)
        char* path
    CODE:
    range_clear_exception();
	range_set_altpath(path);
	if (range_get_exception() && SvTRUE( get_sv("Seco::AwesomeRange::raise_exceptions", TRUE) )) {
	   		croak("%s", range_get_exception());
    }
    sv_setpv( get_sv("Seco::AwesomeRange::errno", TRUE), range_get_exception() );


void
range_expand(range)
	char* range
    INIT:
        const char** res;
	int i;
    PPCODE:
    range_clear_exception();
	res = range_expand(range);
    if (range_get_exception() && SvTRUE( get_sv("Seco::AwesomeRange::raise_exceptions", TRUE) )) {
      croak("%s", range_get_exception());
    }
    sv_setpv( get_sv("Seco::AwesomeRange::errno", TRUE),
              range_get_exception()
              );
    if (NULL == res)
      XSRETURN_UNDEF;
    for (i=0; res[i] != NULL; i++) 
     XPUSHs(sv_2mortal(newSVpv(res[i], 0)));
    range_free_nodes(res);

void
range_expand_sorted(range)
	char* range
    INIT:
        const char ** res;
	int i;
    PPCODE:
    range_clear_exception();
	res = range_expand_sorted(range);
    if (range_get_exception() && SvTRUE( get_sv("Seco::AwesomeRange::raise_exceptions", TRUE) )) {
	   		croak("%s", range_get_exception());
    }
    sv_setpv( get_sv("Seco::AwesomeRange::errno", TRUE),
              range_get_exception()
              );
    if (NULL == res)
      XSRETURN_UNDEF;
    for (i=0; res[i] != NULL; i++)
     XPUSHs(sv_2mortal(newSVpv(res[i], 0)));
     range_free_nodes(res);

SV *
range_compress_xs(nodes, separator)
	SV* nodes
        char* separator
     INIT:
        const char ** node_lst;
	char *range;
	I32 num_nodes;
	int i;
	SV *ret;
/* only accept arrayref. In perl, ref any list sent */
/* FIXME make throw exception or something better if Seco::AwesomeRange::raise_exceptions on */
	if ((!SvROK(nodes)) || (SvTYPE(SvRV(nodes)) != SVt_PVAV)
	    || ((num_nodes = av_len((AV *)SvRV(nodes))) < 0)) 
	    XSRETURN_UNDEF;
        node_lst = malloc(sizeof(char*) * (num_nodes + 2));
     CODE:
    for (i=0; i<=num_nodes; i++) {
		
      char* node = SvPV_nolen(*av_fetch((AV *)SvRV(nodes), i, 0));
      node_lst[i] = node;
    }
    node_lst[num_nodes + 1] = NULL;
    range_clear_exception();
    range = range_compress(node_lst, separator);
    free(node_lst);
    if (range_get_exception() && SvTRUE( get_sv("Seco::AwesomeRange::raise_exceptions", TRUE) )) {
      croak("%s", range_get_exception());
    }
    sv_setpv( get_sv("Seco::AwesomeRange::errno", TRUE),
              range_get_exception()
              );
    if (NULL == range)
      XSRETURN_UNDEF;
	RETVAL = newSVpv(range, 0);
    free(range);
     OUTPUT:
        RETVAL

void
range_clear_caches()
    CODE:
    range_clear_exception();
    range_clear_caches();
    if (range_get_exception() && SvTRUE(get_sv("Seco::AwesomeRange::raise_exceptions", TRUE))) {
      croak("%s", range_get_exception());
    }
    sv_setpv( get_sv("Seco::AwesomeRange::errno", TRUE),
              range_get_exception()
              );
    


void
range_want_caching(want)
        int want;
    CODE:
    range_clear_exception();
	range_want_caching(want);
    if (range_get_exception() && SvTRUE(get_sv("Seco::AwesomeRange::raise_exceptions", TRUE))) {
      croak("%s", range_get_exception());
    }
    sv_setpv( get_sv("Seco::AwesomeRange::errno", TRUE),
              range_get_exception()
              );

void
range_want_warnings(want)
        int want;
    CODE:
    range_clear_exception();
	range_want_warnings(want);
    if (range_get_exception() && SvTRUE(get_sv("Seco::AwesomeRange::raise_exceptions", TRUE))) {
      croak("%s", range_get_exception());
    }
    sv_setpv( get_sv("Seco::AwesomeRange::errno", TRUE),
              range_get_exception()
              );

SV *
range_get_version()
    CODE:
        RETVAL = newSVpv(range_get_version(), 0);
     OUTPUT:
        RETVAL

