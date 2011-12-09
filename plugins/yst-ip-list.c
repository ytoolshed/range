#include <stdio.h>
#include <string.h>

#include "set.h"
#include "librange.h"
#include "range.h"
#include "tinydns_ip.h"
#include "hosts-netblocks.h"

const char** functions_provided(libcrange* lr)
{
    static const char* functions[] = {"vlan", "dc", "hosts_v", "hosts_dc", "vlans_dc", 0};
    return functions;
}

range* rangefunc_vlans_dc(range_request* rr, range** r)
{
    range* result = range_new(rr);
    apr_pool_t* pool = range_request_pool(rr);
    const char** members = range_get_hostnames(pool, r[0]);
    int i;

    for (i=0; members[i]; ++i) {
        const char* dc = members[i];
        range_union_inplace(rr, result, netblocks_for_dc(rr, dc));
    }
    return result;
}

range* rangefunc_hosts_dc(range_request* rr, range** r)
{
    int i;
    range* result = range_new(rr);
    apr_pool_t* pool = range_request_pool(rr);
    const char** members = range_get_hostnames(pool, r[0]);

    for (i = 0; members[i]; ++i) {
        const char* dc = members[i];
        range_union_inplace(rr, result, hosts_in_dc(rr, dc));
    }
    return result;
}

range* rangefunc_hosts_v(range_request* rr, range** r)
{
    int i;
    range* result = range_new(rr);
    apr_pool_t* pool = range_request_pool(rr);
    const char** members = range_get_hostnames(pool, r[0]);

    for (i = 0; members[i]; ++i) {
        char net_key[32];
        const char* net = members[i];
        const netblock* blk = netblock_from_string(pool, net);
        netblock_key(blk, net_key, sizeof net_key);
        range_union_inplace(rr, result, hosts_in_netblock(rr, net_key));
    }
    return result;
}

range* rangefunc_vlan(range_request* rr, range** r)
{
    range* ret;
    const char** members;
    apr_pool_t* pool = range_request_pool(rr);
    int i;

    members = range_get_hostnames(pool, r[0]);
    ret = range_new(rr);
    ret->quoted = 1;

    for (i = 0; members[i]; ++i) { /* for each node */
        const char* node = members[i];
        const netblock* block = netblock_for_host(rr, node);
        if (block)
            range_add(ret, block->str);
        else
            range_request_warn_type(rr, "HOST_NO_NETBLOCK", node);
    }

    return ret;
}

range* rangefunc_dc(range_request* rr, range **r)
{
    range* ret;
    const char** members;
    apr_pool_t* pool = range_request_pool(rr);
    int i;

    members = range_get_hostnames(pool, r[0]);
    ret = range_new(rr);

    for (i = 0; members[i]; ++i) { /* for each node */
        const char* node = members[i];
        const char* dc = dc_for_host(rr, node);
        if (dc)
            range_add(ret, dc);
        else
            range_request_warn_type(rr, "NO_COLO", node);
    }

    return ret;
}
