#ifndef TINYDNS_IP_H
#define TINYDNS_IP_H

#include "libcrange.h"

#define A_RE "^\\+([^:]+):([^:]+):0"
#define CNAME_RE "^C([^:]+):([^:]+)\\.:0"
#define DNS_FILE "/export/crawlspace/tinydns-data/root/data"

typedef struct ip
{
    unsigned binary;
    const char* str;
} ip;

typedef struct ip_host
{
    const ip* ip;
    const char* hostname;
} ip_host;

unsigned str2ip(const char* str);
ip* ip_new(apr_pool_t* pool, const char* ipaddr);
ip* tinydns_get_ip(range_request* rr, const char* hostname);
ip_host** tinydns_all_ip_hosts(libcrange* lr, apr_pool_t* pool);


#endif
