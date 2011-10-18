#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <libpq-fe.h>
#include <apr_strings.h>

#include "set.h"
#include "libcrange.h"
#include "range.h"

const char** functions_provided(libcrange* lr)
{
    static const char* functions[] = {"group", 0};
    return functions;
}

range* rangefunc_group(range_request* rr, range** r)
{
    range* ret;
    const char** members;
    int i;
    PGconn *conn;
    int errors = 0;

    apr_pool_t* pool = range_request_pool(rr);
    libcrange* lr = range_request_lr(rr);

    ret = range_new(rr);
    members = range_get_hostnames(pool, r[0]);

    const char* default_namespace = libcrange_getcfg(lr, "default_namespace");
    if (!default_namespace)
        default_namespace = "yst";
    
    if (!(conn = (PGconn *)libcrange_get_cache(lr, "pgsql:conn"))) {
        const char* pgsql_user = libcrange_getcfg(lr, "pgsql_user");
        const char* pgsql_db = libcrange_getcfg(lr, "pgsql_db");
        const char* pgsql_passwd = libcrange_getcfg(lr, "pgsql_passwd");
        const char* pgsql_host = libcrange_getcfg(lr, "pgsql_host");
        const char* pgsql_port = libcrange_getcfg(lr, "pgsql_port");

        if (!pgsql_user) {
            range_request_warn(rr, "pgsql no user specified");
            errors++;
        }

        if (!pgsql_db) {
            range_request_warn(rr, "pgsql no db specified");
            errors++;
        }

        if (!pgsql_passwd) {
            range_request_warn(rr, "pgsql no passwd specified");
            errors++;
        }

        if (!pgsql_host)
            pgsql_host = "localhost";

        if (!pgsql_port)
            pgsql_port = "5432";

        if (errors)
            return ret;

        char* conninfo = apr_psprintf
            (pool, "host=%s port=%s user=%s password=%s dbname=%s",
             pgsql_host, pgsql_port, pgsql_user, pgsql_passwd,
             pgsql_db);

        if (!(conn = PQconnectdb(conninfo))) {
            range_request_warn(rr, "pgsql dbname=%s: can't connect",
                               pgsql_db);
            return ret;
        }

        if (PQstatus(conn) != CONNECTION_OK) {
            range_request_warn(rr, "pgsql connection: %s",
                               PQerrorMessage(conn));
            return ret;
        }

        libcrange_set_cache(lr, "pgsql:conn", conn);
    }

    for (i = 0; members[i]; i++) { /* for each gemgroup */
        int all = strcmp(members[i], "ALL") == 0;
        PGresult* result;
        int row, rows;
        const char* query;
        
        if (all) 
            query = apr_psprintf(pool, "select distinct element "
                                "from velementgroups where namespace='%s'",
                                default_namespace);
        else 
            query = apr_psprintf(pool, "select element from velementgroups "
                                "where namespace='%s' and groupname='%s'",
                                default_namespace, members[i]);

        result = PQexec(conn, query);
        if (!result) {
            range_request_warn(rr, "pgsql_group: %s",
                               PQerrorMessage(conn));
            return ret;
        }

        if (( PQresultStatus(result) != PGRES_COMMAND_OK ) &&
            ( PQresultStatus(result) != PGRES_TUPLES_OK ))
        {
            range_request_warn(rr, "pgsql_group: %s",
                               PQerrorMessage(conn));
            return ret;
        }

        rows = PQntuples(result);
        for (row=0; row < rows; ++row) {
            const char* element = PQgetvalue(result, row, 0);
            range_add(ret, element);
        }
        
        PQclear(result);
    }

    return ret;
}
