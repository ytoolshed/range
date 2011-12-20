#include <assert.h>
#include <pcre.h>
#include <stdio.h>
#include <dirent.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/stat.h>
#include <apr_strings.h>
#include <apr_tables.h>
#include "librange.h"
#include "range.h"

static const char* nodescf_path = "/etc/range";

const char** functions_provided(librange* lr)
{
    static const char* functions[] = {"mem", "cluster", "clusters",
                                      "group", "get_admin", "get_cluster",
                                      "get_groups", "has", "allclusters", 0 };

    /* initialize our path to the nodes database */

    /* First try env variable */
    const char* altpath = getenv( "LIBRANGE_NODESCF_PATH" );

    /* Next try variable from config file */
    if( ! altpath )
        altpath = librange_getcfg(lr, "nodescf_path");

    /* If no alternative was specified, keep the default */
    if (altpath)
        nodescf_path = altpath;

    return functions;
}


typedef struct cache_entry
{
    time_t mtime;
    apr_pool_t* pool;
    set* sections;
} cache_entry;

static set* _get_ignore_set(range_request* rr)
{
    char line[32768];
    apr_pool_t* pool = range_request_pool(rr);
    const char* ignore_path = apr_psprintf(pool, "%s/all/IGNORE", nodescf_path);
    set* ret = set_new(pool, 0);
    FILE* fp = fopen(ignore_path, "r");
    if (!fp) return ret;

    while (fgets(line, sizeof line, fp) != NULL) {
        int len;
        char* p;
        line[sizeof line - 1] = '\0';
        len = strlen(line);

        if (!len) continue;
        if (line[len - 1] == '\n')
            line[--len] = '\0';

        for (p = line; *p; ++p)
            if (*p == '#') {
                *p = '\0';
                len = strlen(line);
                break;
            }

        if (!len) continue;

        for (p = &line[len - 1]; isspace(*p); --p) {
            --len;
            *p = '\0';
        }
        if (len <= 0) continue;

        set_add(ret, line, 0);
    }
    fclose(fp);

    return ret;
}

#define INCLUDE_RE "^\\s+INCLUDE\\s+(.+)"
#define EXCLUDE_RE "^\\s+EXCLUDE\\s+(.+)"

static pcre* include_re = NULL;
static pcre* exclude_re = NULL;

static char* _substitute_dollars(apr_pool_t* pool,
                                 const char* cluster, const char* line)
{
    static char buf[262144];
    char* dst = buf;
    int len = strlen(cluster);
    int in_regex = 0;
    char c;
    assert(line);
    assert(cluster);

    while ((c = *line) != '\0') {
        if (!in_regex && c == '$') {
            strcpy(dst, "cluster(");
            dst += sizeof("cluster(") - 1;
            strcpy(dst, cluster);
            dst += len;
            *dst++ = ':';
            c = *++line;
            while (isalnum(c) || c == '_') {
                *dst++ = c;
                c = *++line;
            }
            *dst++ = ')';
        }
        else if (c == '/') {
            in_regex = !in_regex;
            *dst++ = *line++;
        }
        else {
            *dst++ = *line++;
        }
    }
    *dst = '\0';
    return buf;
}

char* _join_elements(apr_pool_t* pool, char sep, set* the_set)
{
    set_element** members = set_members(the_set);
    set_element** p = members;
    int total;
    char* result;
    char* p_res;

    total = 0;
    while (*p) {
        total += strlen((*p)->name) + 1;
        ++p;
    }
    if (!total) return NULL;

    p = members;
    p_res = result = apr_palloc(pool, total);
    while (*p) {
        int len = strlen((*p)->name);
        strcpy(p_res, (*p)->name);
        ++p;
        p_res += len;
        *p_res++ = sep;
    }

    *--p_res = '\0';
    return result;
}

static pcre* vips_re = NULL;

typedef struct vips 
{
    time_t mtime;
    apr_pool_t* pool;
    set* vips;
    set* viphosts;
} vips;

static vips* _empty_vips(range_request* rr)
{
    apr_pool_t* pool = range_request_pool(rr);
    vips* v = apr_palloc(pool, sizeof(*v));
    v->vips = v->viphosts = set_new(pool, 0);
    return v;
}

static vips* _parse_cluster_vips(range_request* rr, const char* cluster)
{
    struct stat st;
    int ovector[30];
    char line[32768];
    int line_no;
    FILE* fp;
    apr_pool_t* req_pool = range_request_pool(rr);
    apr_pool_t* lr_pool = range_request_lr_pool(rr);
    librange* lr = range_request_lr(rr);
    set* cache = librange_get_cache(lr, "nodescf:cluster_vips");
    const char* vips_path = apr_psprintf(req_pool, "%s/%s/vips.cf",
                                         nodescf_path, cluster);
    vips* v;
    
    if (!cache) {
        cache = set_new(lr_pool, 0);
        librange_set_cache(lr, "nodescf:cluster_vips", cache);
    }

    if (stat(vips_path, &st) == -1) {
        range_request_warn_type(rr, "NOVIPS", cluster);
        return _empty_vips(rr);
    }

    v = set_get_data(cache, vips_path);
    if (!v) {
        v = apr_palloc(lr_pool, sizeof(struct vips));
        apr_pool_create(&v->pool, lr_pool);
        v->vips = set_new(v->pool, 0);
        v->viphosts = set_new(v->pool, 0);
        v->mtime = st.st_mtime;
        set_add(cache, vips_path, v);
    }
    else {
        time_t cached_mtime = v->mtime;
        if (cached_mtime != st.st_mtime) {
            apr_pool_clear(v->pool);
            v->vips = set_new(v->pool, 0);
            v->viphosts = set_new(v->pool, 0);
            v->mtime = st.st_mtime;
        }
        else /* current cached copy is good */
            return v;
    }

    /* create / update the current cached copy */
    fp = fopen(vips_path, "r");
    if (!fp) {
        range_request_warn_type(rr, "NOVIPS", cluster);
        return _empty_vips(rr);
    }

    if (!vips_re) {
        const char* error;
        vips_re = pcre_compile("^(\\S+)\\s+(\\S+)\\s+(\\S+)\\s*$", 0, &error,
                               ovector, NULL);
        assert(vips_re);
    }

    line_no = 0;
    while (fgets(line, sizeof line, fp)) {
        int len;
        int count;
        char* p;

        line_no++;
        line[sizeof line - 1] = '\0';
        len = strlen(line);
        if (len+1 >= sizeof(line) && line[len - 1] != '\n') {
            /* incomplete line */
            fprintf(stderr, "%s:%d lines > 32767 chars not supported\n", vips_path, line_no);
            exit(-1);
        }

        line[--len] = '\0'; /* get rid of the \n */
        for (p = line; *p; ++p)
            if (*p == '#') {
                *p = '\0';
                break;
            }

        len = strlen(line);
        if (len == 0) continue;

        for (p = &line[len - 1]; isspace(*p); --p) {
            *p = '\0';
            --len;
        }

        if (!*line) continue;

        /* 68.142.248.161 as301000 eth0:1 */
        count = pcre_exec(vips_re, NULL, line, len, 0, 0, ovector, 30);
        if (count == 4) {
            line[ovector[3]] = '\0';
            line[ovector[5]] = '\0';
            line[ovector[7]] = '\0';

            set_add(v->vips, &line[ovector[2]], 0);
            set_add(v->viphosts, &line[ovector[4]], 0);
        }
    }

    fclose(fp);
    return v;
}

static range* _cluster_vips(range_request* rr, const char* cluster)
{
    vips* v = _parse_cluster_vips(rr, cluster);
    return range_from_set(rr, v->vips);
}

static range* _cluster_viphosts(range_request* rr, const char* cluster)
{
    vips* v = _parse_cluster_vips(rr, cluster);
    return range_from_set(rr, v->viphosts);
}

static set* _cluster_keys(range_request* rr, apr_pool_t* pool,
                          const char* cluster, const char* cluster_file)
{
    char line[32768];
    char* p;
    int ovector[30];
    apr_array_header_t* working_range;
    set* sections;
    char* section;
    char* cur_section;
    apr_pool_t* req_pool = range_request_pool(rr);
    int line_no;
    FILE* fp = fopen(cluster_file, "r");

    if (!fp) {
        range_request_warn(rr, "%s: %s not readable", cluster, cluster_file);
        return set_new(pool, 0);
    }

    if (!include_re) {
        const char* error;
        include_re = pcre_compile(INCLUDE_RE, 0, &error, ovector, NULL);
        assert(include_re);

        exclude_re = pcre_compile(EXCLUDE_RE, 0, &error, ovector, NULL);
        assert(exclude_re);
    }

    sections = set_new(pool, 0);
    section = cur_section = NULL;


    working_range = apr_array_make(req_pool, 1, sizeof(char*));
    line_no = 0;
    while (fgets(line, sizeof line, fp)) {
        int len;
        int count;
        line_no++;
        line[sizeof line - 1] = '\0';
        len = strlen(line);
        if (len+1 >= sizeof(line) && line[len - 1] != '\n') {
            /* incomplete line */
            fprintf(stderr, "%s:%d lines > 32767 chars not supported\n", cluster_file, line_no);
            exit(-1);
        }

        line[--len] = '\0'; /* get rid of the \n */
        for (p = line; *p; ++p)
            if (*p == '#') {
                *p = '\0';
                break;
            }

        len = strlen(line);
        if (len == 0) continue;

        for (p = &line[len - 1]; isspace(*p); --p) {
            *p = '\0';
            --len;
        }

        if (!*line) continue;

        if (!(isspace(*line))) {
            cur_section = apr_pstrdup(pool, line);
            continue;
        }

        if (section && strcmp(cur_section, section) != 0) {
            set_add(sections, section, 
                    apr_array_pstrcat(pool, working_range, ','));
            working_range = apr_array_make(req_pool, 1, sizeof(char*));
        }

        section = cur_section;
        count = pcre_exec(include_re, NULL, line, len,
                          0, 0, ovector, 30);
        if (count > 0) {
            line[ovector[3]] = '\0';
            *(char**)apr_array_push(working_range) =
                apr_psprintf(pool, "(%s)",
                             _substitute_dollars(pool, cluster, &line[ovector[2]]));
            continue;
        }

        count = pcre_exec(exclude_re, NULL, line, len,
                          0, 0, ovector, 30);
        if (count > 0) {
            line[ovector[3]] = '\0';
            *(char**)apr_array_push(working_range) =
                apr_psprintf(pool, "-(%s)",
                             _substitute_dollars(pool, cluster, &line[ovector[2]]));
        }

    }
    fclose(fp);

    if (cur_section)
        set_add(sections, cur_section,
                apr_array_pstrcat(pool, working_range, ','));

    set_add(sections, "KEYS", _join_elements(pool, ',', sections));
    set_add(sections, "UP", set_get_data(sections, "CLUSTER"));
    if (set_get(sections, "ALL") && set_get(sections, "CLUSTER"))
        set_add(sections, "DOWN",
                apr_psprintf(pool, "(%s)-(%s)",
                             (char*)set_get_data(sections, "ALL"),
                             (char*)set_get_data(sections, "CLUSTER")));
    return sections;
}

static range* _expand_cluster(range_request* rr,
                              const char* cluster, const char* section)
{
    struct stat st;
    const char* res;
    librange* lr = range_request_lr(rr);
    set* cache = librange_get_cache(lr, "nodescf:cluster_keys");
    apr_pool_t* req_pool = range_request_pool(rr);
    apr_pool_t* lr_pool = range_request_lr_pool(rr);

    const char* cluster_file;
    cache_entry* e;

    if (strcmp(section, "VIPS") == 0)
        return _cluster_vips(rr, cluster);

    if (strcmp(section, "VIPHOSTS") == 0)
        return _cluster_viphosts(rr, cluster);
    
    cluster_file = apr_psprintf(req_pool, "%s/%s/nodes.cf", nodescf_path, cluster);
    if (!cache) {
        cache = set_new(lr_pool, 0);
        librange_set_cache(lr, "nodescf:cluster_keys", cache);
    }

    if (stat(cluster_file, &st) == -1) {
        range_request_warn_type(rr, "NOCLUSTERDEF", cluster);
        return range_new(rr);
    }
    
    e = set_get_data(cache, cluster_file);
    if (!e) {
        e = apr_palloc(lr_pool, sizeof(struct cache_entry));
        apr_pool_create(&e->pool, lr_pool);
        e->sections = _cluster_keys(rr, e->pool, cluster, cluster_file);
        e->mtime = st.st_mtime;
        set_add(cache, cluster_file, e);
    }
    else {
        time_t cached_mtime = e->mtime;
        if (cached_mtime != st.st_mtime) {
            apr_pool_clear(e->pool);
            e->sections = _cluster_keys(rr, e->pool, cluster, cluster_file);
            e->mtime = st.st_mtime;
        } 
    }

    res = set_get_data(e->sections, section);

    if (!res) {
        char* cluster_section = apr_psprintf(req_pool,
                                             "%s:%s", cluster, section);
        range_request_warn_type(rr, "NOCLUSTER", cluster_section);
        return range_new(rr);
    }

    return do_range_expand(rr, res);
}

static const char** _all_clusters(range_request* rr)
{
    DIR* dir;
    struct dirent* dir_entry;
    apr_pool_t* pool = range_request_pool(rr);
    set* res = set_new(pool, 0);
    set* ignore = _get_ignore_set(rr);
    char nodes_cf_buf[8192];
    set_element** elts;
    const char** table;
    int i, n;

    dir = opendir(nodescf_path);
    if (!dir) {
        range_request_warn(rr, "%s: can't opendir", nodescf_path);
        return NULL;
    }

    while ( (dir_entry = readdir(dir)) != NULL) {
        const char* cluster = dir_entry->d_name;
        if (set_get(ignore, cluster) != NULL) continue;

        snprintf(nodes_cf_buf, sizeof nodes_cf_buf, "%s/%s/nodes.cf",
                 nodescf_path, cluster);
        nodes_cf_buf[sizeof nodes_cf_buf - 1] = '\0';
        if (access(nodes_cf_buf, R_OK) == 0)
            set_add(res, cluster, 0);
    }

    closedir(dir);

    n = res->members;
    table = apr_palloc(pool, sizeof(char*) * (n + 1));
    table[n] = NULL;

    elts = set_members(res);
    for (i=0; i<n; i++) {
        const char* name = (*elts++)->name;
        table[i] = name;
    }

    return table;
}

range* rangefunc_allclusters(range_request* rr, range** r)
{
    range* ret = range_new(rr);

    const char** all_clusters = _all_clusters(rr);
    const char** cluster = all_clusters;
    int warn_enabled = range_request_warn_enabled(rr);

    if (!cluster) return ret;

    range_request_disable_warns(rr);
    while (*cluster) {
        range_add(ret, *cluster);
        cluster++;
    }
    if (warn_enabled) range_request_enable_warns(rr);

    return ret;
}

range* rangefunc_has(range_request* rr, range** r)
{
    range* ret = range_new(rr);
    apr_pool_t* pool = range_request_pool(rr);
    const char** tag_names = range_get_hostnames(pool, r[0]);
    const char** tag_values = range_get_hostnames(pool, r[1]);

    const char* tag_name = tag_names[0];
    const char* tag_value = tag_values[0];

    const char** all_clusters = _all_clusters(rr);
    const char** cluster = all_clusters;
    int warn_enabled = range_request_warn_enabled(rr);

    if (!cluster) return ret;

    range_request_disable_warns(rr);
    while (*cluster) {
        range* vals = _expand_cluster(rr, *cluster, tag_name);
        if (set_get(vals->nodes, tag_value) != NULL) {
            range_add(ret, *cluster);
        }
        cluster++;
    }
    if (warn_enabled) range_request_enable_warns(rr);

    return ret;
}


range* rangefunc_mem(range_request* rr, range** r)
{
    range* ret = range_new(rr);
    apr_pool_t* pool = range_request_pool(rr);
    const char** clusters = range_get_hostnames(pool, r[0]);
    const char* cluster = clusters[0];
    const char** wanted = range_get_hostnames(pool, r[1]);
    
    range* keys = _expand_cluster(rr, cluster, "KEYS");
    const char** all_sections = range_get_hostnames(pool, keys);
    const char** p_section = all_sections;

  SECTION:
    while (*p_section) {
        range* r_s = _expand_cluster(rr, cluster, *p_section);
        const char** p_wanted = wanted;
        while (*p_wanted) {
            if (set_get(r_s->nodes, *p_wanted) != NULL) {
                range_add(ret, *p_section++);
                goto SECTION;
            }
            ++p_wanted;
        }
        ++p_section;
    }

    return ret;
}

range* rangefunc_cluster(range_request* rr, range** r)
{
    range* ret = range_new(rr);
    apr_pool_t* pool = range_request_pool(rr);
    const char** clusters = range_get_hostnames(pool, r[0]);
    const char** p = clusters;

    while (*p) {
        const char* colon = strchr(*p, ':');
        range* r1;
        if (colon) {
            int len = strlen(*p);
            int cluster_len = colon - *p;
            int section_len = len - cluster_len - 1;

            char* cl = apr_palloc(pool, cluster_len + 1);
            char* sec = apr_palloc(pool, section_len + 1);

            memcpy(cl, *p, cluster_len);
            cl[cluster_len] = '\0';
            memcpy(sec, colon + 1, section_len);
            sec[section_len] = '\0';

            r1 = _expand_cluster(rr, cl, sec);
        }
        else 
            r1 = _expand_cluster(rr, *p, "CLUSTER");

        if (range_members(r1) > range_members(ret)) {
            /* swap them */
            range* tmp = r1;
            r1 = ret;
            ret = tmp;
        }
        range_union_inplace(rr, ret, r1);
        range_destroy(r1);
        ++p;
    }
    return ret;
}

range* rangefunc_group(range_request* rr, range** r)
{
    range* ret = range_new(rr);
    apr_pool_t* pool = range_request_pool(rr);
    const char** groups = range_get_hostnames(pool, r[0]);

    while (*groups) {
        if (islower(*groups[0]))
            range_union_inplace(rr, ret, _expand_cluster(rr, "HOSTS", *groups));
        else
            range_union_inplace(rr, ret, _expand_cluster(rr, "GROUPS", *groups));
        ++groups;
    }
    return ret;
}

range* rangefunc_get_admin(range_request* rr, range** r)
{
    range* n = r[0];
    apr_pool_t* pool = range_request_pool(rr);
    const char** in_nodes = range_get_hostnames(pool, n);

    range* ret = range_new(rr);
    set* node_admin = set_new(pool, 40000);
    range* admins_r = _expand_cluster(rr, "HOSTS", "KEYS");
    const char** admins = range_get_hostnames(pool, admins_r);
    const char** p_admin = admins;

    while (*p_admin) {
        range* nodes_r = _expand_cluster(rr, "HOSTS", *p_admin);
        const char** nodes = range_get_hostnames(pool, nodes_r);
        const char** p_nodes = nodes;

        while (*p_nodes) {
            set_add(node_admin, *p_nodes, (void*)*p_admin);
            ++p_nodes;
        }
        ++p_admin;
    }

    while (*in_nodes) {
        const char* admin = set_get_data(node_admin, *in_nodes);
        if (!admin) {
            range_request_warn_type(rr, "NO_ADMIN", *in_nodes);
        }
        else {
            range_add(ret, admin);
        }
        in_nodes++;
    }

    return ret;
}

static set* _get_clusters(range_request* rr)
{
    const char** all_clusters = _all_clusters(rr);
    const char** p_cl = all_clusters;
    apr_pool_t* pool = range_request_pool(rr);
    set* node_cluster = set_new(pool, 40000);
    
    if(p_cl == NULL) {
        return node_cluster;
    }
    
    while (*p_cl) {
        range* nodes_r = _expand_cluster(rr, *p_cl, "ALL");
        const char** nodes = range_get_hostnames(pool, nodes_r);
        const char** p_nodes = nodes;

        while (*p_nodes) {
            apr_array_header_t* clusters = set_get_data(node_cluster, *p_nodes);

            if (!clusters) {
                clusters = apr_array_make(pool, 1, sizeof(char*));
                set_add(node_cluster, *p_nodes, clusters);
            }

            *(const char**)apr_array_push(clusters) = *p_cl;
            ++p_nodes;
        }
        ++p_cl;
    }

    return node_cluster;
}

range* rangefunc_get_cluster(range_request* rr, range** r)
{
    range* ret = range_new(rr);
    apr_pool_t* pool = range_request_lr_pool(rr);
    const char** nodes = range_get_hostnames(pool, r[0]);
    const char** p_nodes = nodes;
    set* node_cluster = _get_clusters(rr);
    
    while (*p_nodes) {
        apr_array_header_t* clusters = set_get_data(node_cluster, *p_nodes);
        if (!clusters)
            range_request_warn_type(rr, "NO_CLUSTER", *p_nodes);
        else {
            /* just get one */
            const char* cluster = ((const char**)clusters->elts)[0];
            assert(cluster);
            range_add(ret, cluster);
        }
        ++p_nodes;
    }

    return ret;
}

range* rangefunc_clusters(range_request* rr, range** r)
{
    range* ret = range_new(rr);
    apr_pool_t* pool = range_request_pool(rr);
    const char** nodes = range_get_hostnames(pool, r[0]);
    const char** p_nodes = nodes;
    set* node_cluster = _get_clusters(rr);
    
    while (*p_nodes) {
        apr_array_header_t* clusters = set_get_data(node_cluster, *p_nodes);
        if (!clusters)
            range_request_warn_type(rr, "NO_CLUSTER", *p_nodes);
        else {
            /* get all */
            int i;
            for (i=0; i<clusters->nelts; ++i) {
                const char* cluster = ((const char**)clusters->elts)[i];
                range_add(ret, cluster);
            }
        }
        ++p_nodes;
    }

    return ret;
}

range* rangefunc_get_groups(range_request* rr, range** r)
{
    range* n = r[0];
    apr_pool_t* pool = range_request_pool(rr);
    const char** in_nodes = range_get_hostnames(pool, n);

    range* ret = range_new(rr);
    set* node_group = set_new(pool, 40000);
    range* groups_r = _expand_cluster(rr, "GROUPS", "KEYS");
    const char** groups = range_get_hostnames(pool, groups_r);
    const char** p_group = groups;

    while (*p_group) {
        range* nodes_r = _expand_cluster(rr, "GROUPS", *p_group);
        const char** nodes = range_get_hostnames(pool, nodes_r);
        const char** p_nodes = nodes;

        while (*p_nodes) {
            apr_array_header_t* my_groups = set_get_data(node_group, *p_nodes);
            if (!my_groups) {
                my_groups = apr_array_make(pool, 4, sizeof(char*));
                set_add(node_group, *p_nodes, my_groups);
            }
            *(const char**)apr_array_push(my_groups) = *p_group;
            ++p_nodes;
        }
        ++p_group;
    }

    while (*in_nodes) {
        apr_array_header_t* my_groups = set_get_data(node_group, *in_nodes);
        if (!my_groups) 
            range_request_warn_type(rr, "NO_GROUPS", *in_nodes);
        else {
            int i;
            for (i=0; i<my_groups->nelts; ++i)
                range_add(ret, ((const char**)my_groups->elts)[i]);
        }
        in_nodes++;
    }

    return ret;
}
