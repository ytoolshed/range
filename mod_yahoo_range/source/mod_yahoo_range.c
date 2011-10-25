/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#include <lwes.h>

#include <httpd.h>
#include <http_config.h>
#include <http_log.h>
#include <http_request.h>
#include <http_protocol.h>

#include <apr_strings.h>

#include <ctype.h>
#include <time.h>
#include <unistd.h>
#include <libcrange.h>
#include <sys/time.h>

static struct lwes_emitter *emitter;
static int log_requests = 0;
static int range_ttl = 3600;
static int range_rtl = 2000;
static int log_lwes = 0;
static int range_lwes_ttl = 16;
static char *range_lwes_addr = NULL;
static int range_lwes_port = 0;
static int range_lwes_error = 0;
static char *range_lwes_host_header = NULL;

/* time in seconds when this child started */
static time_t time_started = 0;

/* Emit an LWES event describing this request */
static void send_lwes(request_rec * r, struct timeval *diff, int err, int warn)
{
    struct lwes_event *event;
    const char *userAgent = "UNKNOWN";
    const char *client_ip = NULL;

    /* If we previously failed to create the LWES emitter, don't keep trying */
    if (range_lwes_error)
        return;

    /* We create the LWES emitter the first time through. */
    if (emitter == NULL) {
        emitter = lwes_emitter_create_with_ttl(range_lwes_addr, "0.0.0.0",
                                               range_lwes_port, 0, 60,
                                               range_lwes_ttl);
        /* If we failed to create the emitter, log an error and mark a flag
           so we don't continue to retry. */
        if (emitter == NULL) {
            range_lwes_error = 1;
            ap_log_rerror(APLOG_MARK, APLOG_CRIT, 0, r,
                          "Failed to create LWES emitter");
            return;
        }
    }

    /* Create an empty event for emission. */
    event = lwes_event_create(NULL, "Ranged::Serve");
    if (event == NULL) {
        ap_log_rerror(APLOG_MARK, APLOG_CRIT, 0, r,
                      "Failed to create LWES event");
        return;
    }

    /* Check the headers for some fields. */
    if (r->headers_in != NULL) {
        /* Grab the user agent from the headers. If it wasn't passed in,
           it'll default to "UNKNOWN". */
        userAgent = apr_table_get(r->headers_in, "User-Agent");
        if (userAgent == NULL) {
            userAgent = "UNKNOWN";
        }
        /* If we were asked to override the client IP with an HTTP header,
           check for the header and fetch the value. */
        if (range_lwes_host_header != NULL) {
            client_ip = apr_table_get(r->headers_in, range_lwes_host_header);
        }
    }

    /* If we were supposed to override the client IP with an HTTP header,
       but the header didn't exist, OR if we aren't overriding, set the
       client IP to the real remote connection IP. */
    if ((range_lwes_host_header != NULL && client_ip == NULL) ||
            range_lwes_host_header == NULL) {
        client_ip = r->connection->remote_ip;
    }

    /* Set the various LWES event fields that we'll be emitting. */
    lwes_event_set_STRING(event, "ua", userAgent);
    lwes_event_set_STRING(event, "client", client_ip);
    lwes_event_set_U_INT_16(event, "serve", 1);
    lwes_event_set_U_INT_16(event, "error", err);
    lwes_event_set_U_INT_16(event, "warning", warn);
    lwes_event_set_U_INT_64(event, "tts",
                            (diff->tv_sec * 1000000) + diff->tv_usec);

    /* Send the LWES event, and clean up. */
    lwes_emitter_emit(emitter, event);
    lwes_event_destroy(event);
}

static int timeval_subtract(struct timeval *result, struct timeval *end,
                            struct timeval *start)
{
    if (end->tv_usec < start->tv_usec) {
        int nsec = (start->tv_usec - end->tv_usec) / 1000000 + 1;
        start->tv_usec -= 1000000 * nsec;
        start->tv_sec += nsec;
    }
    if (end->tv_usec - start->tv_usec > 1000000) {
        int nsec = (end->tv_usec - start->tv_usec) / 1000000;
        start->tv_usec += 1000000 * nsec;
        start->tv_sec -= nsec;
    }
    result->tv_sec = end->tv_sec - start->tv_sec;
    result->tv_usec = end->tv_usec - start->tv_usec;
    return end->tv_sec < start->tv_sec;
}

static char *read_post_data(request_rec * r)
{
     char* range = NULL;
     char* range_ret = NULL;  /* actual range which will be returned */
     int bytes_inserted;
     apr_size_t bufsize;
     apr_size_t post_data_size = 0;

     /* setup client to allow Apache to read request body, CHUNKED is supported :)*/ 
     if (ap_setup_client_block(r,REQUEST_CHUNKED_DECHUNK) != OK) {
           ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, "mod_range: ap_setup_client_block failed.");
           return ""; 
     }
                                    
     /* Allocate 1MB initiially*/    
     bufsize = 1024 * 1024;
     range = (char*) malloc(bufsize+1);

     /*If client has data to send*/
     if( ap_should_client_block(r) ) {
         while(1) {
              /* read the data */
              bytes_inserted = ap_get_client_block(r, range, bufsize); 
              
              if( bytes_inserted == 0 )
                   break;
                                                                                                             
              if (bytes_inserted == -1) {
                  ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r, "mod_range: ap_get_client_block failed.");
                  free(range);
                  return ""; 
              }
                                                                          
              post_data_size += bytes_inserted;
                                                                                                                                   
              /*Allocate more if required, on > 7K*/
              if (post_data_size >= bufsize - (7 * 1024) ){
                  bufsize += bufsize;
                  range = (char *) realloc(range,bufsize);
              }
        } /* end of while(1) */
        range[post_data_size] = '\0';
    }
    /*copy range to range_ret*/
    range_ret = apr_pstrdup(r->pool,range);
    /*unescape post params*/
    ap_unescape_url(range_ret);
    free(range);
    return range_ret;
}

static int range_handler(request_rec * r)
{
    range_request *rr;
    char *range;
    int wants_list = 0;
    int wants_expand = 0;
    int warn = 0;
    struct timeval t;
    struct timeval end_t;
    struct timeval diff_t;
    timerclear(&end_t);
    timerclear(&diff_t);

    if (strcmp(r->handler, "server-range"))
        return DECLINED;

    if (r->method_number != M_GET && r->method_number != M_POST) {
        if (log_lwes)
            send_lwes(r, &diff_t, 1, warn);
        return HTTP_METHOD_NOT_ALLOWED;
    }

    wants_list = strcmp(r->path_info, "/list") == 0;
    if (!wants_list)
        wants_expand = strcmp(r->path_info, "/expand") == 0;

    if (!wants_list && !wants_expand)
        return DECLINED;

    if (log_requests || log_lwes || !time_started) {
        gettimeofday(&t, NULL);
        if (!time_started)
            time_started = t.tv_sec;
    }

    ap_set_content_type(r, "text/plain");
    if (r->method_number == M_GET) {
        if(r->args != NULL ) {
            /* unescape GET params*/
            ap_unescape_url(r->args);
            range = r->args;
        }
        else
            range = "";
    }
    else
        range = read_post_data(r);

    rr = range_expand(NULL, r->pool, range);
    gettimeofday(&end_t, NULL);
    timeval_subtract(&diff_t, &end_t, &t);

    if (log_requests) {
        double diff;
        diff = end_t.tv_sec * 1000000.0 + end_t.tv_usec -
            (t.tv_sec * 1000000.0 + t.tv_usec);

        diff /= 1E6;
        ap_log_rerror(APLOG_MARK, APLOG_NOTICE, 0, r,
                      "%s -- %0.3fs", range, diff);
    }

    if (range_request_has_warnings(rr)) {
        warn = 1;
        const char *warnings = range_request_warnings(rr);
        char *header = (char *)warnings;
        if (strlen(warnings) > 2048) {
            header = apr_palloc(r->pool, 2048);
            memcpy(header, warnings, 2047);
            header[2047] = '\0';
        }

        apr_table_t *headers = r->headers_out;
        apr_table_add(headers, "RangeException", header);
    }

    if (wants_list) {
        const char **nodes = range_request_nodes(rr);
        while (*nodes) {
            ap_rputs(*nodes++, r);
            ap_rputc('\n', r);
        }
    }
    else {
        const char *compressed = range_request_compressed(rr);
        ap_rputs(compressed, r);
    }

    /* 
       if (--range_rtl < 1 || (end_t.tv_sec - time_started) > range_ttl) {
       pid_t pid = getpid(); ap_log_rerror(APLOG_MARK, APLOG_NOTICE, 0, r,
       "range gracefully restarting %u", pid); } */

    if (log_lwes)
        send_lwes(r, &diff_t, 0, warn);

    return OK;
}

static const char *range_log_requests(cmd_parms * cmd, void *dummy, int flag)
{
    log_requests = flag;
    return NULL;
}

static const char *range_log_lwes(cmd_parms * cmd, void *dummy, int flag)
{
    log_lwes = flag;
    return NULL;
}

static const char *range_set_lwes_port(cmd_parms * cmd, void *dummy,
                                       const char *arg)
{
    int port = atoi(arg);
    if (port < 1) {
        return "RangeLwesPort must be > 0";
    }

    range_lwes_port = port;
    return NULL;
}

static const char *range_set_lwes_addr(cmd_parms * cmd, void *dummy,
                                       const char *arg)
{
    range_lwes_addr = strdup(arg);
    return NULL;
}

static const char *range_set_lwes_ttl(cmd_parms * cmd, void *dummy,
                                      const char *arg)
{
    int ttl = atoi(arg);
    if (ttl < 0) {
        return "RangeLwesTimeToLive must be >= 0";
    }

    range_lwes_ttl = ttl;
    return NULL;
}

static const char *range_set_lwes_host_header(cmd_parms * cmd, void *dummy,
                                              const char *arg)
{
    range_lwes_host_header = strdup(arg);
    return NULL;
}

static const char *range_set_ttl(cmd_parms * cmd, void *dummy, const char *arg)
{
    int ttl = atoi(arg);
    if (ttl < 1) {
        return "RangeTimeToLive must be > 0";
    }

    range_ttl = ttl;
    return NULL;
}

static const char *range_set_rtl(cmd_parms * cmd, void *dummy, const char *arg)
{
    int rtl = atoi(arg);
    if (rtl < 1) {
        return "RangeRequestsToServe must be > 0";
    }

    range_rtl = rtl;
    return NULL;
}

static const command_rec config_range_cmds[] = {
    AP_INIT_FLAG("RangeLogRequests", range_log_requests, NULL, RSRC_CONF,
                 "On or Off to enable or disable (default) logging"),
    AP_INIT_FLAG("RangeLogLwes", range_log_lwes, NULL, RSRC_CONF,
                 "On or Off to enable or disable (default) "
                 "logging via LWES emission"),
    AP_INIT_TAKE1("RangeLwesAddr", range_set_lwes_addr, NULL, RSRC_CONF,
                  "Multicast address for sending LWES events"),
    AP_INIT_TAKE1("RangeLwesPort", range_set_lwes_port, NULL, RSRC_CONF,
                  "Multicast port for sending LWES events"),
    AP_INIT_TAKE1("RangeLwesTimeToLive", range_set_lwes_ttl, NULL, RSRC_CONF,
                  "TTL setting for emitted multicast packets (default 16)"),
    AP_INIT_TAKE1("RangeLwesHostHeader", range_set_lwes_host_header, NULL,
                  RSRC_CONF, "Override LWES-logged client IP using this header"
                  " (defaults to unused, if header does not exist, real client"
                  " IP will be used)"),
    AP_INIT_TAKE1("RangeTimeToLive", range_set_ttl, NULL, RSRC_CONF,
                  "the number of seconds an httpd child should live "
                  "(default 3600)"),
    AP_INIT_TAKE1("RangeRequestsToServe", range_set_rtl, NULL, RSRC_CONF,
                  "the number of requests an httpd child should serve "
                  "(default 2000)"),
    {NULL}
};

static void register_hooks(apr_pool_t * p)
{
    ap_hook_handler(range_handler, NULL, NULL, APR_HOOK_MIDDLE);
}

module AP_MODULE_DECLARE_DATA range_module = {
    STANDARD20_MODULE_STUFF,
    NULL,                       /* create per-directory config structure */
    NULL,                       /* merge per-directory config structures */
    NULL,                       /* create per-server config structure */
    NULL,                       /* merge per-server config structures */
    config_range_cmds,          /* command apr_table_t */
    register_hooks              /* register hooks */
};
