#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"


#include <libcrange.h>

/*

Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.

*/

static void expand(long ptr, const char* range)
{
 dXSARGS;
 range_request* rr = (range_request*) ptr;
 const char** nodes;

 sp = mark;
 rr = range_expand_rr(rr, range);
 nodes = range_request_nodes(rr);
 while (*nodes)
   XPUSHs(sv_2mortal(newSVpv(*nodes++, 0)));

 PUTBACK;
}

#define LR(rr) (range_request_lr((range_request*)rr))
#define RR(rr) ((range_request*)rr)

MODULE = Libcrange		PACKAGE = Libcrange		

PROTOTYPES: DISABLE

void
expand(rr, range)
    long rr
    const char* range
  PREINIT:
    I32* temp;
  PPCODE:
    temp = PL_markstack_ptr++;
    expand(rr, range);
    if (PL_markstack_ptr != temp) {
      PL_markstack_ptr = temp;
      XSRETURN_EMPTY;
    }
    return;

const char*
get_var(rr, var)
    long rr
    const char* var
  CODE:
    RETVAL = libcrange_getcfg(LR(rr), var);
  OUTPUT:
    RETVAL

void
warn_type(rr, type, msg)
    long rr
    const char* type
    const char* msg
  CODE:
    range_request_warn_type(RR(rr), type, msg);

void
warn(rr, msg)
    long rr
    const char* msg
  CODE:
    range_request_warn(RR(rr), "%s", msg);
