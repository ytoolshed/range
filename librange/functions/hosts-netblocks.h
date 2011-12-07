#ifndef HOSTS_NETBLOCKS_H
#define HOSTS_NETBLOCKS_H

#include "libcrange.h"
#include "range.h"
#include "netblock.h"

range* hosts_in_netblock(range_request* rr, const char* netblock_key);
const netblock* netblock_for_host(range_request* rr, const char* host);
range* hosts_in_dc(range_request* rr, const char* dc);
const char* dc_for_host(range_request* rr, const char* host);

#endif
