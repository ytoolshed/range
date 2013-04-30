#include "netblock.h"
#include "set.h"
#include <pcre.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <ctype.h>
#include <apr_strings.h>

#define IMASK(n) (0 - (1 << (32 - n)))
#define NETMASK_RE "^\"?(\\d+\\.\\d+\\.\\d+\\.\\d+)/(\\d+)\"?$"
#define IP_RE "^\\d+\\.\\d+\\.\\d+\\.\\d+$"
#define TWO_FIELDS_RE "^(\\S+)\\s+(\\S+)"

#define NET_COLO_CACHE "net:netkey-netcolo"
#define COLO_NET_CACHE "net:colo-netblock"

static pcre* netmask_re = 0;
static pcre* ip_re = 0;
static pcre* two_fields_re = 0;

static void compile_regexes()
{
    if (!netmask_re) {
        int err_offset;
        const char* error;
        netmask_re = pcre_compile(NETMASK_RE, 0, &error, &err_offset, NULL);
        assert(netmask_re);

        ip_re = pcre_compile(IP_RE, 0, &error, &err_offset, NULL);
        assert(ip_re);

        two_fields_re = pcre_compile(TWO_FIELDS_RE, 0, &error, &err_offset, NULL);
        assert(two_fields_re);
    }
}

static set* read_netblocks(libcrange* lr)
{
    set* result;
    set* colo_nets;

    FILE* fp;
    char line[4096];
    int line_no;
    apr_pool_t* pool;
    range_request* rr;
    const char* yst_ip_list = libcrange_getcfg(lr, "yst_ip_list");
    if (!yst_ip_list) yst_ip_list = YST_IP_LIST;
    
    if ((result = libcrange_get_cache(lr, NET_COLO_CACHE)) != 0)
        return result;

    pool = libcrange_get_pool(lr);
    compile_regexes();
    result = set_new(pool, 0);
    colo_nets = set_new(pool, 0);

    fp = fopen(yst_ip_list, "r");
    if (!fp) {
        fprintf(stderr, "%s: %s", yst_ip_list,
                strerror(errno));
        return set_new(pool, 0);
    }

    line_no = 0;
    rr = range_request_new(lr, pool);
    while (fgets(line, sizeof line, fp)) {
        int count;
        int ovector[30];
        int n;
        char* p = line;
        const char* colo;
        const char* netblock_str;
        char* key;
        set_element* elt;
        range* r;
        netblock* net;
        net_colo* nc = apr_palloc(pool, sizeof(net_colo));

        ++line_no;
        p = line;
        while (*p && isspace(*p)) ++p;
        if (*p == '#') continue;
        n = strlen(p);
        if (p[n - 1] != '\n') {
            fprintf(stderr, "%s: line %d is too long.\n",
                    yst_ip_list, line_no);
            fclose(fp);
            return set_new(pool, 0);
        }
        count = pcre_exec(two_fields_re, NULL, p, n,
                          0, 0, ovector, 30);
        if (count < 3) continue;

        colo = &p[ovector[2]];
        p[ovector[3]] = '\0';

        netblock_str = &p[ovector[4]];
        p[ovector[5]] = '\0';

        net = netblock_from_string(pool, netblock_str);
        nc->net = net;
        nc->colo = apr_pstrdup(pool, colo);

        key = apr_psprintf(pool, "%x/%d", net->base, net->bits);
        set_add(result, key, nc);
        elt = set_get(colo_nets, colo);
        if (!elt) {
            r = range_new(rr);
            r->quoted = 1;
            set_add(colo_nets, colo, r);
        }
        else
            r = elt->data;
        range_add(r, net->str);
    }
    fclose(fp);

    libcrange_set_cache(lr, COLO_NET_CACHE, colo_nets);
    libcrange_set_cache(lr, NET_COLO_CACHE, result);
    return result;
}

net_colo* netcolo_for_ip(libcrange* lr, const ip* node_ip)
{
    int bits;
    set* netblocks;
    unsigned bin_ip;

    assert(lr);
    assert(node_ip);
    netblocks = read_netblocks(lr);
    bin_ip = node_ip->binary;
    for (bits=32; bits > 0; --bits) {
        char netmask[32];
        set_element* elt;
        unsigned base = bin_ip & IMASK(bits);
        sprintf(netmask, "%x/%d", base, bits);
        elt = set_get(netblocks, netmask);
        if (elt)
            return elt->data;
    }
    return NULL;
}

char* netblock_key(const netblock* block, char* buf, size_t n)
{
    snprintf(buf, n, "%x/%d", block->base, block->bits);
    buf[n - 1] = '\0';
    return buf;
}

const char* netblock_to_str(const netblock* block)
{
    assert(block);
    return block->str;
}

netblock* netblock_from_string(apr_pool_t* pool, const char* netmask)
{
    int count;
    int ovector[30];
    const char* base;
    const char* bits;
    int len = strlen(netmask);
    netblock* result = apr_palloc(pool, sizeof(netblock));

    compile_regexes();
    count = pcre_exec(netmask_re, NULL, netmask, len,
                      0, 0, ovector, 30);
    if (count > 0) {
        pcre_get_substring(netmask, ovector, count, 1, &base);
        pcre_get_substring(netmask, ovector, count, 2, &bits);

        result->base = str2ip(base);
        result->bits = atoi(bits);

        result->str = apr_pstrdup(pool, netmask);
    }
    else {
        char* repr = apr_palloc(pool, len + 4);
        count = pcre_exec(ip_re, NULL, netmask, len,
                          0, 0, ovector, 30);
        /* FIXME: deal with errors */
        if (count <= 0) {
            printf("ERROR: [%s] trying to parse a netblock\n", netmask);
            abort();
        }

        result->bits = 32;
        pcre_get_substring(netmask, ovector, count, 0, &base);
        result->base = str2ip(base);
        pcre_free_substring(base);

        strcpy(repr, netmask);
        strcat(repr, "/32");
        result->str = repr;
    }

    return result;
}

range* netblocks_for_dc(range_request* rr, const char* dc)
{
    set* colo_nets;
    set_element* elt;
    libcrange* lr = range_request_lr(rr);
    
    read_netblocks(lr); /* make sure the caches are up-to-date */

    colo_nets = libcrange_get_cache(lr, COLO_NET_CACHE);
    elt = set_get(colo_nets, dc);
    if (elt)
        return elt->data;
    else {
        range_request_warn_type(rr, "NO_DC", dc);
        return range_new(rr);
    }
}
