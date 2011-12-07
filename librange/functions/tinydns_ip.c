#include <netdb.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <pcre.h>
#include <apr_strings.h>
#include <limits.h>
#include <sys/stat.h>

#include "range_request.h"
#include "set.h"
#include "libcrange.h"
#include "tinydns_ip.h"

typedef struct cache_entry
{
    time_t mtime;
    apr_pool_t* pool;
    set* hosts_ip;
    set* cnames;
} cache_entry;

static cache_entry* _dummy_cache_entry(apr_pool_t* pool)
{
    cache_entry* e = apr_palloc(pool, sizeof(cache_entry));
    e->mtime = 0;
    e->cnames = e->hosts_ip = set_new(pool, 0);
    return e;
}

static cache_entry* tinydns_read(libcrange* lr)
{
    const char* error;
    int offset;
    static pcre* a_re = NULL;
    static pcre* cname_re = NULL;

    apr_pool_t* pool = libcrange_get_pool(lr);
    cache_entry* e;
    struct stat st;
    char line[8192];
    FILE* fp;
    const char* dns_file = libcrange_getcfg(lr, "dns_data_file");
    if (!dns_file) dns_file = DNS_FILE;

    if (stat(dns_file, &st) < 0) {
        fprintf(stderr, "Can't stat %s", dns_file);
        /* dummy cache */
        return _dummy_cache_entry(pool);
    }

    e = libcrange_get_cache(lr, "dns:tinydns_data");
    if (e && e->mtime == st.st_mtime)
        return e;

    if (!e) {
        e = apr_palloc(pool, sizeof(cache_entry));
        apr_pool_create(&e->pool, pool);
        libcrange_set_cache(lr, "dns:tinydns_data", e);
    }
    else
        apr_pool_clear(e->pool);

    e->mtime = st.st_mtime;
    e->hosts_ip = set_new(e->pool, 50000);
    e->cnames = set_new(e->pool, 1000);

    if (!a_re) {
	a_re = pcre_compile(A_RE, 0, &error, &offset, NULL);
	cname_re = pcre_compile(CNAME_RE, 0, &error, &offset, NULL);
    }

    fp = fopen(dns_file, "r");
    if (!fp) {
        fprintf(stderr, "Can't open %s: %s", dns_file, strerror(errno));
        return _dummy_cache_entry(pool);;
    }

    while (fgets(line, sizeof line, fp)) {
        int ovector[30];
        int count;
        int len;

        line[sizeof line - 1] = '\0';
        len = strlen(line);
        if (len+1 >= sizeof(line) && line[len - 1] != '\n') {
            /* incomplete line */
            fprintf(stderr, "%s: lines > %d chars not supported\n", dns_file,
                    sizeof line);
            exit(-1);
        }

	count = pcre_exec(a_re, NULL, line, len,
			  0, 0, ovector, 30);
	if (count > 0) {
            char* host = &line[ovector[2]];
            char* ip = &line[ovector[4]];
            line[ovector[3]] = line[ovector[5]] = '\0'; 

	    set_add(e->hosts_ip, host, ip_new(e->pool, ip));
	} else {
	    count = pcre_exec(cname_re, NULL, line, len,
			      0, 0, ovector, 30);
	    if (count > 0) {
                char* alias = &line[ovector[2]];
                char* canon = &line[ovector[4]];
                line[ovector[3]] = line[ovector[5]] = '\0';

		set_add(e->cnames, alias, apr_pstrdup(e->pool, canon));
	    }
	}
    }

    return e;
}

ip* tinydns_get_ip(range_request* rr,  const char* hostname)
{
    struct hostent* h;
    apr_pool_t* pool = range_request_pool(rr);
    
    if (isdigit(hostname[0]))
	return ip_new(pool, hostname);

    h = gethostbyname(hostname);
    if (!h)
        return NULL;

    if (h->h_addrtype != AF_INET || h->h_length != 4)
        /* no IPv4 addresses */
        return NULL;

    return ip_new(pool, apr_psprintf(pool,
                                     "%u.%u.%u.%u",
                                     ((unsigned char*)h->h_addr)[0],
                                     ((unsigned char*)h->h_addr)[1],
                                     ((unsigned char*)h->h_addr)[2],
                                     ((unsigned char*)h->h_addr)[3]));
}


ip_host** tinydns_all_ip_hosts(libcrange* lr, apr_pool_t* pool)
{
    ip_host** result;
    ip_host** p;
    set_element** hosts;
    cache_entry* e = tinydns_read(lr);

    p = result = apr_palloc(pool, sizeof(ip_host*) * (e->hosts_ip->members + 1));
    for (hosts = set_members(e->hosts_ip); *hosts; ++hosts) {
	const char* host = (*hosts)->name;
	const ip* host_ip = (*hosts)->data;
	ip_host* iph = apr_palloc(pool, sizeof(ip_host));
	iph->hostname = host;
	iph->ip = host_ip;
	*p++ = iph;
    }
    *p = NULL;

    return result;
}

ip* ip_new(apr_pool_t* pool, const char* ipaddr)
{
    ip* i;

    i = apr_palloc(pool, sizeof(ip));
    i->binary = str2ip(ipaddr);
    i->str = apr_pstrdup(pool, ipaddr);

    return i;
}

unsigned str2ip(const char* str)
{
    unsigned a, b, c, d;
    if (sscanf(str, "%u.%u.%u.%u", &a, &b, &c, &d) == 4)
	return (a<<24) + (b<<16) + (c<<8) + d;

    return 0;
}
