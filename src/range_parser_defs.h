/*
Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms
*/

#ifndef RANGE_PARSER_DEFS_H
#define RANGE_PARSER_DEFS_H

typedef union YYSTYPE {
    struct rangeast *rangeast;
    struct rangeparts *rangeparts;
    char *strconst;
} YYSTYPE;
#define YYSTYPE_IS_DECLARED 1

typedef struct YYLTYPE
{
  int first_line;
  int first_column;
  int last_line;
  int last_column;
} YYLTYPE;
#define YYLTYPE_IS_DECLARED 1

void yyerror(const char* s);
int yylex(YYSTYPE* yylval_param, YYLTYPE* yylloc_param, void* yyscanner);


#endif
