/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#ifndef RANGE_COMPRESS_H
#define RANGE_COMPRESS_H

struct range_request;
struct range;

const char* do_range_compress(struct range_request* rr, const struct range* r);

#endif /* RANGE_COMPRESS_H */
