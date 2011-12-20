#ifndef NODESCF_H
#define NODESCF_H

#include "librange.h"
#include "set.h"
#include "filecache.h"

#define GROUP_RE "^([A-Za-z0-9_\\-]+)"
#define INCLUDE_RE "^\\s+INCLUDE\\s+([^#]+)"
#define EXCLUDE_RE "^\\s+EXCLUDE\\s+([^#\\s]+)"
#define DOLLAR_RE "([^\\$]*)\\$(\\w+)"

struct set *nodescf_read(librange *lr, char *filename, char *cname);
int nodescf_replace_dollars(librange *lr, filecache *fc, char *clustername);

#endif
