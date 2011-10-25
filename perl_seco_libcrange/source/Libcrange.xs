/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.  
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include <libcrange.h>

static libcrange*
__get_libcrange_ptr( SV *var )
{
    if (!(sv_isobject((SV*)var) && sv_derived_from((SV*)var,"Seco::Libcrange")))
        return 0;
    HV*  h = (HV *)SvRV( var );
    SV** lr = hv_fetch(h,"__libcrange_ptr", strlen("__libcrange_ptr"),0);
    if(!lr)
        return 0;
    return INT2PTR(libcrange*, SvIV(*lr));
}

MODULE = Seco::Libcrange	PACKAGE = Seco::Libcrange
PROTOTYPES: ENABLE
BOOT:
   apr_initialize();

SV* 
new(class,config)
   char* class;
   char* config;

   INIT:
        SV*        iv;
        HV*        myself;
        HV*        stash;

   CODE:
   apr_pool_t* lr_pool = NULL;
   apr_pool_create(&lr_pool,NULL);
   libcrange *lcr = libcrange_new(lr_pool,config);
   myself = newHV();
   iv = newSViv(PTR2IV(lcr));
   hv_store( myself, "__libcrange_ptr",strlen("__libcrange_ptr"), iv, 0 );
   /* Return a blessed reference to the HV */
   RETVAL = newRV_noinc( (SV *)myself );
   stash = gv_stashpv( class, TRUE );
   sv_bless( (SV *)RETVAL, stash );
   OUTPUT:
     RETVAL


void
expand(self,range)
    SV*   self
	char* range
    INIT:
      libcrange *lr;

    PPCODE:
    lr = __get_libcrange_ptr(self);
    if( lr == NULL || range == NULL)
       XSRETURN_UNDEF;
    apr_pool_t* req_pool = NULL;
    apr_pool_create(&req_pool,NULL);
	range_request *rr = range_expand(lr,req_pool,range);
    if (rr == NULL) 
    {
        apr_pool_destroy(req_pool);
        XSRETURN_UNDEF;
    }
    if ( range_request_has_warnings(rr) 
          && 
         SvTRUE(get_sv("Seco::Libcrange::raise_exceptions",TRUE)))
    {
        apr_pool_destroy(req_pool);
        croak("%s", range_request_warnings(rr));
    }
    const char **nodes = range_request_nodes(rr);
    if (nodes == NULL)
    {
      apr_pool_destroy(req_pool);
      XSRETURN_UNDEF;
    }
    while (*nodes) 
    {
        XPUSHs(sv_2mortal(newSVpv(*nodes++, 0)));
    }
    apr_pool_destroy(req_pool); 


SV* 
compress_xs(self,nodes)
    SV* self
    SV* nodes
    INIT:
    const char ** node_lst;
    char *range;
    I32 num_nodes;
    int i;
    SV *ret;
    libcrange *lr;

    CODE:
    lr = __get_libcrange_ptr(self);
    if( lr == NULL)
       XSRETURN_UNDEF;
    if ((!SvROK(nodes)) || (SvTYPE(SvRV(nodes)) != SVt_PVAV)
        || ((num_nodes = av_len((AV *)SvRV(nodes))) < 0))
        XSRETURN_UNDEF;
    node_lst = malloc(sizeof(char*) * (num_nodes + 2));
    apr_pool_t* req_pool = NULL;
    apr_pool_create(&req_pool,NULL);
    for (i=0; i<=num_nodes; i++) {
      char* node = SvPV_nolen(*av_fetch((AV *)SvRV(nodes), i, 0));
      node_lst[i] = node;
    }
    node_lst[num_nodes + 1] = NULL;
    range = range_compress(lr,req_pool,node_lst);
    free(node_lst);
    apr_pool_destroy(req_pool);
    if (NULL == range)
      XSRETURN_UNDEF;
    RETVAL = newSVpv(range, 0);
   /* free(range); */
    OUTPUT:
      RETVAL
