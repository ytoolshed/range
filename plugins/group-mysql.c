#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <mysql/mysql.h>
#include <apr_strings.h>

#include "set.h"
#include "librange.h"
#include "range.h"

const char** functions_provided(librange* lr)
{
    static const char* functions[] = {"group", 0};
    return functions;
}

range* rangefunc_group(range_request* rr, range** r)
{
    range *ret;
    const char **members;
    int i;
    MYSQL *conn;
    MYSQL_ROW row;
    MYSQL_RES *res;
    apr_pool_t* pool = range_request_pool(rr);
    librange* lr = range_request_lr(rr);
    
    ret = range_new(rr);
    members = range_get_hostnames(pool, r[0]);

    if(!(conn = (MYSQL *)librange_get_cache(lr, "mysql:nodes"))) {
	const char* mysql_user = librange_getcfg(lr, "mysqluser");
	const char* mysql_db = librange_getcfg(lr, "mysqldb");
	const char* mysql_passwd = librange_getcfg(lr, "mysqlpasswd");

	conn = mysql_init(NULL);
	mysql_real_connect(conn, "docking", mysql_user, mysql_passwd,
			   mysql_db, 0, NULL, 0);
	librange_set_cache(lr, "mysql:nodes", conn);
    }
    for(i = 0; members[i]; i++) { /* for each gemgroup */
        int all = strcmp(members[i], "ALL") == 0;

	if (all) {
	    const char* query = "select name from nodes";
	    if (mysql_query(conn, query)) {
		fprintf(stderr, "query: %s failed: %s\n",
                        query, mysql_error(conn));
                return range_new(rr);
	    }
	} else {
	    const char* query = apr_psprintf(pool,
                                             "select range from tags where name='%s'",
                                             members[i]);
	    if (mysql_query(conn, query)) {
		fprintf(stderr, "query: %s failed: %s\n",
                        query, mysql_error(conn));
                return range_new(rr);
	    }
	}
	res = mysql_store_result(conn);
	assert(res);
	while ((row = mysql_fetch_row(res)) != NULL) {
            range* this_group;
	    const char* result = row[0];
            if (all) {
                range_add(ret, result);
            } else {
                this_group = do_range_expand(rr, result);
                set_union_inplace(ret->nodes, this_group->nodes);
            }
	}
        mysql_free_result(res);
    }

    return ret;
}
