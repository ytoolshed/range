%{
#include <stdio.h>
#include "range.h"
#include "ast.h"

#define YYPARSE_PARAM scanner
#define YYLEX_PARAM scanner
#include "range_parser_defs.h"

%}

%pure-parser
%locations
%error-verbose
%start main

%token tGROUP tUNION tDIFF tINTER tNOT tADMIN tGET_CLUSTER
%token tGET_GROUP tCLUSTER tCOLON tLPAREN tRPAREN tSEMI
%token tLBRACE tRBRACE tEOL tCOLON tERROR tHASH tEOF tWHITESPACE

%token <strconst> tLITERAL tREGEX tNONRANGE_LITERAL
%token <rangeparts> tRANGEPARTS

%left tREGEX
%left tUNION tDIFF tINTER
%left tNOT
%nonassoc tCLUSTER tGROUP tADMIN tGET_CLUSTER tGET_GROUP
%left tCOLON
%left tSEMI
%left tLBRACE tRBRACE

%type <rangeast> rangeexpr
%type <rangeast> main
%type <rangeast> funcargs

%union {
    struct rangeast *rangeast;
    struct rangeparts *rangeparts;
    char *strconst;
};

%%
main : rangeexpr
{
    (*((range_extras**)scanner))->theast = $1;
};

rangeexpr : {
    range_extras* e = *(range_extras**)scanner;
    $$ = range_ast_new(range_request_pool(e->rr), AST_NOTHING);
}
| tREGEX
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_REGEX);
    r->data.string = $1;
    $$ = r;
}
| tLITERAL
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_LITERAL);
    r->data.string = $1;
    $$ = r;
}
| tNONRANGE_LITERAL
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_NONRANGE_LITERAL);
    r->data.string = $1;
    $$ = r;
}
| tRANGEPARTS
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_PARTS);
    r->data.parts = $1;
    $$ = r;
}
| tLPAREN rangeexpr tRPAREN
{
    $$ = $2;
}
| rangeexpr tUNION rangeexpr
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_UNION);
    $1->next = $3;
    r->children = $1;
    $$ = r;
}
| rangeexpr tLBRACE rangeexpr tRBRACE rangeexpr
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_BRACES);
    $1->next = $3;
    $3->next = $5;
    r->children = $1;
    $$ = r;
}
| rangeexpr tDIFF rangeexpr
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_DIFF);
    $1->next = $3;
    r->children = $1;
    $$ = r;
}
| rangeexpr tINTER rangeexpr
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_INTER);
    $1->next = $3;
    r->children = $1;
    $$ = r;
}
| tCLUSTER rangeexpr
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_FUNCTION);
    r->data.string = "cluster";
    r->children = $2;
    $$ = r;
}
| tADMIN rangeexpr
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_FUNCTION);
    r->data.string = "get_admin";
    r->children = $2;
    $$ = r;
}
| tGROUP rangeexpr
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_FUNCTION);
    r->data.string = "group";
    r->children = $2;
    $$ = r;
}
| tGET_CLUSTER rangeexpr
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_FUNCTION);
    r->data.string = "get_cluster";
    r->children = $2;
    $$ = r;
}
| tNOT rangeexpr
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_NOT);
    r->children = $2;
    $$ = r;
}
| tGET_GROUP rangeexpr
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_FUNCTION);
    r->data.string = "get_groups";
    r->children = $2;
    $$ = r;
}
| tLITERAL tLPAREN funcargs tRPAREN
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_FUNCTION);
    r->data.string = $1;
    r->children = $3;
    $$ = r;
}
| tHASH tLITERAL tLPAREN funcargs tRPAREN
{
    range_extras* e = *(range_extras**)scanner;
    rangeast *r = range_ast_new(range_request_pool(e->rr), AST_FUNCTION);
    r->data.string = $2;
    r->children = $4;
    $$ = r;
};

funcargs: rangeexpr
{
    $$ = $1;
}
| rangeexpr tSEMI funcargs
{
    $1->next = $3;
    $$ = $1;
};




%%
