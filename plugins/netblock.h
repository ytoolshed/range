#ifndef NETBLOCK_H
#define NETBLOCK_H

#include "librange.h"
#include "range.h"
#include "tinydns_ip.h"

/* #define IP_LIST "/etc/ip-list" */
#ifndef LIBRANGE_IP_LIST
#error LIBRANGE_IP_LIST
#endif

typedef struct netblock
{
    unsigned base;
    int bits;
    const char* str;
} netblock;

typedef struct net_colo
{
    netblock* net;
    const char* colo;
} net_colo;

net_colo* netcolo_for_ip(librange* lr, const ip* node_ip);
const char* netblock_to_str(const netblock* block);
netblock* netblock_from_string(apr_pool_t* pool, const char* netmask);
char* netblock_key(const netblock* block, char* buf, size_t n);

range* netblocks_for_dc(range_request* lr, const char* dc);

#endif
