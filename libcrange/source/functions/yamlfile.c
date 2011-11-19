/* yamlfile.c: yaml file cluster definiton support for range
   adapted from nodescf.c ebourget@linkedin.com

Redistribution and use of this software in source and binary forms,
with or without modification, are permitted provided that the following
conditions are met:

* Redistributions of source code must retain the above
  copyright notice, this list of conditions and the
  following disclaimer.

* Redistributions in binary form must reproduce the above
  copyright notice, this list of conditions and the
  following disclaimer in the documentation and/or other
  materials provided with the distribution.

* Neither the name of Yahoo! Inc. nor the names of its
  contributors may be used to endorse or promote products
  derived from this software without specific prior
  written permission of Yahoo! Inc.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
DAMAGE.
   
   Requires libyaml

   By default, cluster files go into /etc/range/ *.yaml.  An example:

ALL:
  - r4,r2,r3

CLUSTER:
  - r10

BUBBA:
  - 1..10

BLARG: '1.0.2'

If a key is a scalar, that value is used as the value; if it's a list,
the key will be composed of all elements set-added together.

*/

#include <assert.h>
#include <yaml.h>
#include <pcre.h>
#include <stdio.h>
#include <dirent.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/stat.h>
#include <apr_strings.h>
#include <apr_tables.h>
#include "libcrange.h"
#include "range.h"

static const char* yaml_path = LIBCRANGE_YAML_DIR;

/* List of functions that are provided by this module */
const char** functions_provided(libcrange* lr)
{
    static const char* functions[] = {"mem", "cluster", "clusters",
                                      "get_cluster", "get_groups",
                                      "has", "allclusters", 0 };

    /* initialize our path to the nodes database */

    /* First try env variable */
    const char* altpath = getenv( "LIBCRANGE_YAML_PATH" );

    /* Next try variable from config file */
    if( ! altpath )
        altpath = libcrange_getcfg(lr, "yaml_path");

    /* If no alternative was specified, keep the default */
    if (altpath)
        yaml_path = altpath;

    return functions;
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

/* this is where the magic happens */
static set* _cluster_keys(range_request* rr, apr_pool_t* pool,
                          const char* cluster, const char* cluster_file)
{
    apr_array_header_t* working_range;
    set* sections;
    char* section;
    char* cur_section;
    apr_pool_t* req_pool = range_request_pool(rr);
    yaml_node_t *node;
    yaml_node_t *rootnode;
    yaml_node_t *keynode;
    yaml_node_t *valuenode;
    yaml_parser_t parser;
    yaml_node_item_t *item;
    yaml_node_pair_t *pair;
    
    yaml_document_t document;
    
    FILE* fp = fopen(cluster_file, "r");

    /* make sure we can open the file and parse it */
    if (!fp) {
        range_request_warn(rr, "%s: %s not readable", cluster, cluster_file);
        return set_new(pool, 0);
    }

    if (!yaml_parser_initialize(&parser)) {
        range_request_warn(rr, "%s: cannot initialize yaml parser", cluster);
        fclose(fp);
        return set_new(pool, 0);
    }

    yaml_parser_set_input_file(&parser, fp);
    if(!yaml_parser_load(&parser, &document)) {
        range_request_warn(rr, "%s: malformatted cluster definition %s",
                           cluster, cluster_file);
        fclose(fp);
        yaml_parser_delete(&parser);
        return set_new(pool, 0);
    }
    fclose(fp);
    
    rootnode = yaml_document_get_root_node(&document);
    /* make sure it's just a simple dictionary */
    if(rootnode->type != YAML_MAPPING_NODE) {
        range_request_warn(rr, "%s: malformatted cluster definition %s",
                           cluster, cluster_file);
        yaml_document_delete(&document);
        yaml_parser_delete(&parser);
        return set_new(pool, 0);
    }

    /* "sections" refers to cluster sections - %cluster:SECTION
       it's what we're going to return */
    sections = set_new(pool, 0);
    section = cur_section = NULL;

    for(pair = rootnode->data.mapping.pairs.start;
        pair < rootnode->data.mapping.pairs.top;
        pair++) { /* these are the keys */
        keynode = yaml_document_get_node(&document, pair->key);
        /* cur_section is the keyname - the WHATEVER in %cluster:WHATEVER */
        cur_section = apr_pstrdup(pool, (char *)(keynode->data.scalar.value));
        valuenode = yaml_document_get_node(&document, pair->value);
        /* if the value is a scalar, that's our answer */
        if(valuenode->type == YAML_SCALAR_NODE) {
            set_add(sections, cur_section,
                    apr_psprintf(pool, "%s", valuenode->data.scalar.value));
        } else if (valuenode->type == YAML_SEQUENCE_NODE) {
            /* otherwise, glue together all the values in the list */
            working_range = apr_array_make(req_pool, 1, sizeof(char*));
            for(item = valuenode->data.sequence.items.start;
                item < valuenode->data.sequence.items.top;
                item++) {
                node = yaml_document_get_node(&document, (int)*item);
                if(node->type != YAML_SCALAR_NODE) { /* only scalars allowed */
                    range_request_warn(rr,
                                       "%s: malformed cluster definition %s",
                                       cluster, cluster_file);
                    yaml_document_delete(&document);
                    yaml_parser_delete(&parser);
                    return set_new(pool, 0);
                } else { /* add to the working set */
                    /* include it in () because we're going to comma it
                       together later */
                    *(char**)apr_array_push(working_range) =
                        apr_psprintf(pool, "(%s)", node->data.scalar.value);
                }
            }
            /* glue the list items together with commas */
            set_add(sections, cur_section,
                    apr_array_pstrcat(pool, working_range, ','));
        }
    }

    /* Add a "KEYS" toplevel key that lists all the other keys */
    /* TODO: make an error if somebody tries to specify KEYS manually? */
    set_add(sections, "KEYS", _join_elements(pool, ',', sections));
    yaml_document_delete(&document);
    yaml_parser_delete(&parser);
    return sections;
}

static range* _expand_cluster(range_request* rr,
                              const char* cluster, const char* section)
{
    struct stat st;
    const char* res;
    libcrange* lr = range_request_lr(rr);
    set* cache = libcrange_get_cache(lr, "nodescf:cluster_keys");
    apr_pool_t* req_pool = range_request_pool(rr);
    apr_pool_t* lr_pool = range_request_lr_pool(rr);

    const char* cluster_file;
    cache_entry* e;

    cluster_file = apr_psprintf(req_pool, "%s/%s.yaml", yaml_path, cluster);
    if (!cache) {
        cache = set_new(lr_pool, 0);
        libcrange_set_cache(lr, "nodescf:cluster_keys", cache);
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

/* get a list of all clusters */
static const char** _all_clusters(range_request* rr)
{
    DIR* dir;
    struct dirent* dir_entry;
    apr_pool_t* pool = range_request_pool(rr);
    set* res = set_new(pool, 0);
    char nodes_cf_buf[8192];
    set_element** elts;
    const char** table;
    char *cname;
    int i, n;

    /* check in the cluster dir, by default /etc/range */
    dir = opendir(yaml_path);
    if (!dir) {
        range_request_warn(rr, "%s: can't opendir", yaml_path);
        return NULL;
    }

    while ( (dir_entry = readdir(dir)) != NULL) {
        const char* cluster = dir_entry->d_name;
        snprintf(nodes_cf_buf, sizeof nodes_cf_buf, "%s/%s",
                 yaml_path, cluster);
        
        nodes_cf_buf[sizeof nodes_cf_buf - 1] = '\0';

        /* it's only a cluster if it's .yaml */
        if(!strcmp(nodes_cf_buf+ (strlen(nodes_cf_buf) - 5),
                   ".yaml")) {
            if (access(nodes_cf_buf, R_OK) == 0) {
                /* cut the yaml out */
                cname = apr_psprintf(pool, "%s", cluster);
                cname[strlen(cname)-5] = '\0';
                set_add(res, cname, 0);
            }
        }
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


