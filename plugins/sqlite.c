#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sqlite3.h>
#include <apr_strings.h>
#include <apr_tables.h>
#include <sys/stat.h>

#include "set.h"
#include "librange.h"
#include "range.h"
char* _join_elements(apr_pool_t* pool, char sep, set* the_set);


const char** functions_provided(librange* lr)
{
    static const char* functions[] = {"mem", "cluster", "clusters",
                                      "get_cluster", "get_groups",
                                      "has", "allclusters", 0};
    return functions;
}

#define KEYVALUE_SQL "select key, value from clusters where cluster=?"
#define HAS_SQL "select cluster from clusters where key=? and value=?"
#define ALLCLUSTER_SQL "select distinct cluster from clusters"

sqlite3* _open_db(range_request* rr) 
{
    sqlite3* db;
    librange* lr = range_request_lr(rr);
    int err;
    
    /* open the db */
    if (!(db = librange_get_cache(lr, "sqlite:nodes"))) {
        const char* sqlite_db_path = librange_getcfg(lr, "sqlitedb");
        if (!sqlite_db_path) sqlite_db_path = LIBRANGE_SQLITE_DB;
        
        err = sqlite3_open(sqlite_db_path, &db);
        assert(err == SQLITE_OK);
        librange_set_cache(lr, "sqlite:nodes", db);
    }

    return db;
}


static set* _cluster_keys(range_request* rr, apr_pool_t* pool,
                          const char* cluster)
{
    set* sections;
    sqlite3* db;
    sqlite3_stmt* stmt;
    int err;
    
    /* our return set */
    sections = set_new(pool, 0);

    db = _open_db(rr);
    
    /* prepare our select */
    err = sqlite3_prepare(db, KEYVALUE_SQL, strlen(KEYVALUE_SQL),
                          &stmt, NULL);
    assert(err == SQLITE_OK);

    /* for each key/value pair in cluster */
    sqlite3_bind_text(stmt, 1, cluster, strlen(cluster), SQLITE_STATIC);
    while(sqlite3_step(stmt) == SQLITE_ROW) {
        /* add it to the return */
        const char* key = (const char*)sqlite3_column_text(stmt, 0);
        const char* value = (const char*)sqlite3_column_text(stmt, 1);
        set_add(sections, key, apr_psprintf(pool, "%s", value));
    }
    sqlite3_finalize(stmt);

    /* Add the magic "KEYS" index */
    set_add(sections, "KEYS", _join_elements(pool, ',', sections));
    
    return sections;
}

typedef struct cache_entry
{
    time_t mtime;
    apr_pool_t* pool;
    set* sections;
} cache_entry;

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

static range* _expand_cluster(range_request* rr,
                              const char* cluster, const char* section)
{
    struct stat st;
    const char* res;
    librange* lr = range_request_lr(rr);
    set* cache = librange_get_cache(lr, "nodescf:cluster_keys");
    apr_pool_t* req_pool = range_request_pool(rr);
    apr_pool_t* lr_pool = range_request_lr_pool(rr);

    cache_entry* e;

    if (!cache) {
        cache = set_new(lr_pool, 0);
        librange_set_cache(lr, "nodescf:cluster_keys", cache);
    }

    if (stat("/etc/range.sqlite", &st) == -1) {
        range_request_warn_type(rr, "NOCLUSTERDEF", cluster);
        return range_new(rr);
    }

    e = set_get_data(cache, cluster);
    if (!e) {
        e = apr_palloc(lr_pool, sizeof(struct cache_entry));
        apr_pool_create(&e->pool, lr_pool);
        e->sections = _cluster_keys(rr, e->pool, cluster);
        e->mtime = st.st_mtime;
        set_add(cache, cluster, e);
    }
    else {
        time_t cached_mtime = e->mtime;
        if (cached_mtime != st.st_mtime) {
            apr_pool_clear(e->pool);
            e->sections = _cluster_keys(rr, e->pool, cluster);
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

/* get a list of all clusters */
static const char** _all_clusters(range_request* rr)
{
    sqlite3 *db;
    sqlite3_stmt *stmt;
    int err, n, i;
    apr_pool_t* pool = range_request_pool(rr);
    set* clusters = set_new(pool, 0);
    set_element** elts;
    const char** table;
    
    db = _open_db(rr);
    err = sqlite3_prepare(db, ALLCLUSTER_SQL, strlen(ALLCLUSTER_SQL),
                          &stmt, NULL);
    assert(err == SQLITE_OK);

    /* for each cluster */
    while(sqlite3_step(stmt) == SQLITE_ROW) {
        const char* cluster = (const char*)sqlite3_column_text(stmt, 0);
        set_add(clusters, cluster, 0);
    }
    sqlite3_finalize(stmt);
    
    n = clusters->members;
    table = apr_palloc(pool, sizeof(char*) * (n + 1));
    table[n] = NULL;

    elts = set_members(clusters);
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
    sqlite3* db;
    sqlite3_stmt* stmt;
    int err;
    range* ret = range_new(rr);
    apr_pool_t* pool = range_request_pool(rr);
    const char** tag_names = range_get_hostnames(pool, r[0]);
    const char** tag_values = range_get_hostnames(pool, r[1]);

    const char* tag_name = tag_names[0];
    const char* tag_value = tag_values[0];

    const char** all_clusters = _all_clusters(rr);
    const char** cluster = all_clusters;
    int warn_enabled = range_request_warn_enabled(rr);

    db = _open_db(rr);
    err = sqlite3_prepare(db, HAS_SQL, strlen(HAS_SQL), &stmt,
                          NULL);
    assert(err == SQLITE_OK);

    sqlite3_bind_text(stmt, 1, tag_name, strlen(tag_name), SQLITE_STATIC);
    sqlite3_bind_text(stmt, 2, tag_value, strlen(tag_value), SQLITE_STATIC);

    while(sqlite3_step(stmt) == SQLITE_ROW) {
        const char* answer = (const char*)sqlite3_column_text(stmt, 0);
        range_add(ret, answer);
    }

    sqlite3_finalize(stmt);

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
        range* nodes_r = _expand_cluster(rr, *p_cl, "CLUSTER");
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



