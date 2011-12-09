#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sqlite3.h>

#include "set.h"
#include "librange.h"
#include "range.h"

const char** functions_provided(libcrange* lr)
{
    static const char* functions[] = {"group", 0};
    return functions;
}

#define ALL_NODES_SQL "select name from nodes"
#define RANGE_FROM_TAGS "select range from tags where name=?"

range* rangefunc_group(range_request* rr, range** r)
{
    range* ret;
    const char** members;
    int i, err;
    sqlite3* db;
    sqlite3_stmt* tag_stmt;
    sqlite3_stmt* all_nodes_stmt;
    apr_pool_t* pool = range_request_pool(rr);
    libcrange* lr = range_request_lr(rr);
    
    ret = range_new(rr);
    members = range_get_hostnames(pool, r[0]);

    if (!(db = libcrange_get_cache(lr, "sqlite:nodes"))) {
	const char* sqlite_db_path = libcrange_getcfg(lr, "sqlitedb");
	if (!sqlite_db_path) sqlite_db_path = DEFAULT_SQLITE_DB;

	err = sqlite3_open(sqlite_db_path, &db);
	if (err != SQLITE_OK) {
	    fprintf(stderr, "%s: %s\n", sqlite_db_path, sqlite3_errmsg(db));
	    return ret;
	}

	libcrange_set_cache(lr, "sqlite:nodes", db);
    }


    /* prepare our selects */
    err = sqlite3_prepare(db, ALL_NODES_SQL, strlen(ALL_NODES_SQL),
                          &all_nodes_stmt, NULL);
    if (err != SQLITE_OK) {
        fprintf(stderr, "%s: %s\n", ALL_NODES_SQL, sqlite3_errmsg(db));
        abort();
    }

    err = sqlite3_prepare(db, RANGE_FROM_TAGS, strlen(RANGE_FROM_TAGS),
                          &tag_stmt, NULL);
    assert(err == SQLITE_OK);

    /* for each group */
    for (i = 0; members[i]; ++i) {
        sqlite3_stmt* stmt;
        if (strcmp(members[i], "ALL") == 0) {
            stmt = all_nodes_stmt;
        } else {
            stmt = tag_stmt;
            /* bind the current group name */
            sqlite3_bind_text(tag_stmt, 1, members[i], strlen(members[i]), SQLITE_STATIC);
        }

        while (sqlite3_step(stmt) == SQLITE_ROW) {
            range* this_group;
            const char* result = (const char*)sqlite3_column_text(stmt, 0);
            if (stmt == all_nodes_stmt) {
                range_add(ret, result);
            } else {
                this_group = do_range_expand(rr, result);
                set_union_inplace(ret->nodes, this_group->nodes);
            }
        }
        sqlite3_reset(stmt);
    }
    sqlite3_finalize(all_nodes_stmt);
    sqlite3_finalize(tag_stmt);

    return ret;
}
