#include "hosts-netblocks.h"
#include "netblock.h"
#include "set.h"
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#define HOSTS_NETBLOCK_CACHE "yst-ip-list:hosts_netblocks"
#define HOSTS_DC_CACHE "yst-ip-list:hosts_dc"
#define DC_HOSTS_CACHE "yst-ip-list:dc_hosts"
#define NETBLOCK_HOSTS_CACHE "yst-ip-list:netblocks_hosts"

static void init_caches(librange* lr)
{
    const char* default_domain;
    apr_pool_t* pool = librange_get_pool(lr);
    range_request* rr;
    
    /* Create a netblock -> hosts mapping */
    ip_host** all_hosts = tinydns_all_ip_hosts(lr, pool);
    set* hn = set_new(pool, 100000); /* hosts networks */
    set* hd = set_new(pool, 100000); /* hosts datacenter */
    set* nh = set_new(pool, 1500) ;  /* network hosts */
    set* dh = set_new(pool, 0);      /* datacenter hosts */

    assert(all_hosts);
    rr = range_request_new(lr, pool);
    default_domain = librange_get_default_domain(lr);
    while (*all_hosts) {
        char short_hostname[512];
        int len_hostname;
        char net_key[32];
        set_element* elt;
        range* r;
        ip_host* iph = *all_hosts++;

        const netblock* block;
        const net_colo* nc = netcolo_for_ip(lr, iph->ip);
        if (!nc) continue;

        strncpy(short_hostname, iph->hostname, sizeof short_hostname);
        short_hostname[sizeof short_hostname - 1] = '\0';
        len_hostname = strlen(short_hostname);
        if (short_hostname[len_hostname - 1] == '.')
            /* remove '.' at the end adjusting len */
            short_hostname[--len_hostname] = '\0';

        if (default_domain) {
            /* remove default_domain */
            int len_domain = strlen(default_domain);
            if (len_hostname > len_domain) {
                if (strcmp(&short_hostname[len_hostname - len_domain],
                           default_domain) == 0)
                    short_hostname[len_hostname - len_domain - 1] = '\0';
            }
        }

        block = nc->net;
        set_add(hn, short_hostname, (void*)block);
        set_add(hn, iph->ip->str, (void*)block);
        set_add(hd, short_hostname, (void*)(nc->colo));
        set_add(hd, iph->ip->str, (void*)(nc->colo));

        elt = set_get(nh, netblock_key(block, net_key, sizeof net_key));
        if (!elt) {
            r = range_new(rr);
            set_add(nh, net_key, r);
        }
        else
            r = elt->data;
        range_add(r, short_hostname);

        elt = set_get(dh, nc->colo);
        if (!elt) {
            r = range_new(rr);
            set_add(dh, nc->colo, r);
        }
        else
            r = elt->data;
        range_add(r, short_hostname);
    }
    librange_set_cache(lr, HOSTS_NETBLOCK_CACHE, hn);
    librange_set_cache(lr, NETBLOCK_HOSTS_CACHE, nh);
    librange_set_cache(lr, DC_HOSTS_CACHE, dh);
    librange_set_cache(lr, HOSTS_DC_CACHE, hd);
}

static set* hosts_netblocks(librange* lr)
{
    set* hn = librange_get_cache(lr, HOSTS_NETBLOCK_CACHE);
    if (!hn) {
        init_caches(lr);
        hn = librange_get_cache(lr, HOSTS_NETBLOCK_CACHE);
    }
    return hn;
}

static set* netblock_hosts(librange* lr)
{
    set* nh = librange_get_cache(lr, NETBLOCK_HOSTS_CACHE);
    if (!nh) {
        init_caches(lr);
        nh = librange_get_cache(lr, NETBLOCK_HOSTS_CACHE);
    }
    return nh;
}

static set* datacenter_hosts(librange* lr)
{
    set* dh = librange_get_cache(lr, DC_HOSTS_CACHE);
    if (!dh) {
        init_caches(lr);
        dh = librange_get_cache(lr, DC_HOSTS_CACHE);
    }
    return dh;
}

static set* hosts_dc(librange* lr)
{
    set* hd = librange_get_cache(lr, HOSTS_DC_CACHE);
    if (!hd) {
        init_caches(lr);
        hd = librange_get_cache(lr, HOSTS_DC_CACHE);
    }
    return hd;
}

range* hosts_in_netblock(range_request* rr, const char* netblock_key)
{
    librange* lr = range_request_lr(rr);
    set* nh = netblock_hosts(lr);
    set_element* elt = set_get(nh, netblock_key);
    if (elt)
        return elt->data;

    range_request_warn_type(rr, "NETBLOCK_NOT_FOUND", netblock_key);
    return range_new(rr);
}

range* hosts_in_dc(range_request* rr, const char* dc)
{
    librange* lr = range_request_lr(rr);
    set* dh = datacenter_hosts(lr);
    set_element* elt = set_get(dh, dc);
    if (elt)
        return elt->data;

    range_request_warn_type(rr, "DC_NOT_FOUND", dc);
    return range_new(rr);
}

const netblock* netblock_for_host(range_request* rr, const char* host)
{
    librange* lr = range_request_lr(rr);
    set* hn = hosts_netblocks(lr);
    set_element* block = set_get(hn, host);

    if (block) return block->data;
    return NULL;
}

const char* dc_for_host(range_request* rr, const char* host)
{
    librange* lr = range_request_lr(rr);
    set* hd = hosts_dc(lr);
    set_element* dc = set_get(hd, host);
    if (dc) return dc->data;
    return NULL;
}
