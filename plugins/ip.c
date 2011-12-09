#include "librange.h"
#include "range.h"
#include "tinydns_ip.h"

const char** functions_provided(libcrange* lr)
{
    static const char* functions[] = {"ip", 0};
    return functions;
}

range* rangefunc_ip(range_request* rr, range** r)
{
    range* ret;
    const char** members;
    int i;
    ip* ip;
    apr_pool_t* pool = range_request_pool(rr);
    
    ret = range_new(rr);
    members = range_get_hostnames(pool, r[0]);
    for (i = 0; members[i]; i++) {
        ip = tinydns_get_ip(rr, members[i]);
        if (ip)
            range_add(ret, ip->str);
        else
            range_request_warn_type(rr, "NOTINYDNS", members[i]);
    }
    return ret;
}
