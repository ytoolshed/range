%{
#include <pcre.h>
#include <string.h>
#include <apr_strings.h>
#include "libcrange.h"
#include "range.h"
#include "range_parser.h"

#define YY_EXTRA_TYPE range_extras *
%}

%option reentrant bison-locations bison-bridge
%option batch noyywrap
%option stack warn nounput
%option header="range_scanner.h"
%x regex
%x quote
%x singlequote
%x doublequote

%%

[ \t] /* ignore */;
\n return tEOL;

\/ {
  yy_push_state(regex, yyscanner);
  yyextra->string_buf_ptr = yyextra->string_buf;
}
<regex>\\(\/|\\) {
  *(yyextra->string_buf_ptr++) = yytext[1];
}
<regex>\\(.|\n) {
  *(yyextra->string_buf_ptr++) = '\\';
  *(yyextra->string_buf_ptr++) = yytext[1];
}
<regex>[^\\/]+ {
  int n = strlen(yytext);
  memcpy(yyextra->string_buf_ptr, yytext, n);
  yyextra->string_buf_ptr += n;
}
<regex>\/ {
   yy_top_state(yyscanner);
   yy_pop_state(yyscanner);
   *(yyextra->string_buf_ptr) = '\0';
   yylval->strconst = apr_pstrdup(range_request_pool(yyextra->rr),
						    yyextra->string_buf);
   return tREGEX;
}
q\( {
  yy_push_state(quote, yyscanner);
  yyextra->string_buf_ptr = yyextra->string_buf;
}
<quote>\\(.|\n) {
  *(yyextra->string_buf_ptr++) = yytext[1];
}
<quote>[^\\)]+ {
  int n = strlen(yytext);
  memcpy(yyextra->string_buf_ptr, yytext, n);
  yyextra->string_buf_ptr += n;
}
<quote>\) {
  yy_top_state(yyscanner);
  yy_pop_state(yyscanner);
  *(yyextra->string_buf_ptr) = '\0';
  yylval->strconst = apr_pstrdup(range_request_pool(yyextra->rr),
                                 yyextra->string_buf);
  return tNONRANGE_LITERAL;
}


\' {
  yy_push_state(singlequote, yyscanner);
  yyextra->string_buf_ptr = yyextra->string_buf;
}
<singlequote>\\(.|\n) {
  *(yyextra->string_buf_ptr++) = yytext[1];
}
<singlequote>[^\\']+ {
  int n = strlen(yytext);
  memcpy(yyextra->string_buf_ptr, yytext, n);
  yyextra->string_buf_ptr += n;
}
<singlequote>\' {
  yy_top_state(yyscanner);
  yy_pop_state(yyscanner);
  *(yyextra->string_buf_ptr) = '\0';
  yylval->strconst = apr_pstrdup(range_request_pool(yyextra->rr),
						   yyextra->string_buf);
  return tNONRANGE_LITERAL;
}

\" {
  yy_push_state(doublequote, yyscanner);
  yyextra->string_buf_ptr = yyextra->string_buf;
}
<doublequote>\\(.|\n) {
  *(yyextra->string_buf_ptr++) = yytext[1];
}
<doublequote>[^\\"]+ {
  int n = strlen(yytext);
  memcpy(yyextra->string_buf_ptr, yytext, n);
  yyextra->string_buf_ptr += n;
}
<doublequote>\" {
  yy_top_state(yyscanner);
  yy_pop_state(yyscanner);
  *(yyextra->string_buf_ptr) = '\0';
  yylval->strconst = apr_pstrdup(range_request_pool(yyextra->rr),
                                 yyextra->string_buf);
  return tNONRANGE_LITERAL;
}



[a-zA-Z0-9_\.:][a-zA-Z0-9_\.:\-]+ {
   rangeparts* r;
   if((r = rangeparts_from_hostname(yyextra->rr, yytext)))
   {
     yylval->rangeparts = r;
     return tRANGEPARTS;
   } else {
     yylval->strconst = apr_pstrdup(range_request_pool(yyextra->rr), yytext);
     return tLITERAL;
   }
}

[a-zA-Z0-9_\.:]+ {
   yylval->strconst = apr_pstrdup(range_request_pool(yyextra->rr), yytext);
   return tLITERAL;
}

"&" return tINTER;
"," return tUNION;
"(" return tLPAREN;
")" return tRPAREN;
"{" return tLBRACE;
"}" return tRBRACE;
"^" return tADMIN;
"#" return tHASH;
"%" return tCLUSTER;
"@" return tGROUP;
"*" return tGET_CLUSTER;
"!" return tNOT;
"?" return tGET_GROUP;
".." return tDIFF;
";" return tSEMI;

%%
