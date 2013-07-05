/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#include <stdlib.h>
#include <stdio.h>
#include "ast.h"
#include "range.h"
#include "libcrange.h"

rangeast* range_ast_new(apr_pool_t* pool, rangetype type)
{
    rangeast* r = (rangeast *)apr_palloc(pool, sizeof(rangeast));
    r->children = NULL;
    r->next = NULL;
    r->type = type;

    return r;
}

range* range_evaluate(range_request* rr, const rangeast* ast)
{
    range* r;
    int i;
    rangeast* rtmp;
    range** ranges;
    range* r1;
    range* r2;
    range* r3;
    apr_pool_t* pool = range_request_pool(rr);
    
    switch (ast->type) {
        case AST_LITERAL:
            r = range_from_literal(rr, ast->data.string);
            return r;
        case AST_NONRANGE_LITERAL:
            r = range_from_nonrange_literal(rr, ast->data.string);
            return r;
        case AST_UNION:
            r1 = range_evaluate(rr, ast->children);
            r2 = range_evaluate(rr, ast->children->next);
            if (range_members(r1) > range_members(r2)) {
                range_union_inplace(rr, r1, r2);
                range_destroy(r2);
                return r1;
            } else {
                range_union_inplace(rr, r2, r1);
                range_destroy(r1);
                return r2;
            }
        case AST_GROUP:
            r1 = range_evaluate(rr, ast->children);
            r = range_from_group(rr, r1);
            range_destroy(r1);
            return r;
        case AST_DIFF:
            r1 = range_evaluate(rr, ast->children);
            if (ast->children->next->type == AST_REGEX) 
                r2 = range_from_match(rr, r1, ast->children->next->data.string);
            else
                r2 = range_evaluate(rr, ast->children->next);
            range_diff_inplace(rr, r1, r2);
            return r1;
        case AST_INTER:
            r1 = range_evaluate(rr, ast->children);
            if (ast->children->next->type == AST_REGEX)
                r2 = range_from_match(rr, r1, ast->children->next->data.string);
            else
                r2 = range_evaluate(rr, ast->children->next);
            r = range_from_inter(rr, r1, r2);
            range_destroy(r1);
            range_destroy(r2);
            return r;
        case AST_NOT:
            ranges = (range **)apr_palloc(pool, sizeof(range *) * (2));
            ranges[0] = range_from_literal(rr, "all:CLUSTER");
            ranges[1] = NULL;
            r1 = range_from_function(rr, "cluster", (const range**)ranges);
            r2 = range_evaluate(rr, ast->children);
            range_diff_inplace(rr, r1, r2);
            range_destroy(r2);
            range_destroy(ranges[0]);
            return r1;
        case AST_REGEX:
            ranges = (range **)apr_palloc(pool, sizeof(range *) * (2));
            ranges[0] = range_from_literal(rr, "all:CLUSTER");
            ranges[1] = NULL;
            r1 = range_from_function(rr, "cluster", (const range**)ranges);
            r = range_from_match(rr, r1, ast->data.string);
            range_destroy(r1);
            range_destroy(ranges[0]);
            return r;
        case AST_PARTS:
            r = range_from_rangeparts(rr, ast->data.parts);
            return r;
        case AST_BRACES:
            r1 = range_evaluate(rr, ast->children);
            r2 = range_evaluate(rr, ast->children->next);
            r3 = range_evaluate(rr, ast->children->next->next);
            r = range_from_braces(rr, r1, r2, r3);
            range_destroy(r1);
            range_destroy(r2);
            range_destroy(r3);
            return r;
        case AST_FUNCTION:
            i=0;
            for (rtmp = ast->children; rtmp; rtmp = rtmp->next)
                i++;

            ranges = (range **)apr_palloc(pool, sizeof(range *) * (i+1));
            ranges[i] = NULL;
            i=0;
            for (rtmp = ast->children; rtmp; rtmp = rtmp->next) {
                ranges[i++] = range_evaluate(rr, rtmp);
            }
            ranges[i++] = NULL;

            r = range_from_function(rr, ast->data.string, (const range**)ranges);
            for (i=0; ranges[i]; i++) range_destroy(ranges[i]);

            return r;
        case AST_NOTHING:
            r = range_new(rr);
            return r;
        default:
            fprintf(stderr, "ERROR IN LIBCRANGE: Corrupted AST\n");
            abort();
    }
}
