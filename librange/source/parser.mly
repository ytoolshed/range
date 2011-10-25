%token <string * string * string * string> RANGE
%token <string> LITERAL
%token <string * string> FUNCTION
%token <string> REGEX FILTER
%token HOSTGROUP
%token UNION DIFF INTER INTER_HP NOT
%token ADMIN GET_CLUSTER GET_GROUP FUNCTION
%token CLUSTER_EXP COLON
%token LPAREN RPAREN LBRACE RBRACE
%token EOL
%left FUNCTION
%left UNION DIFF INTER   /* lowest precendence */
%left INTER_HP           /* inter. medium precedence */
%left NOT                /* negation operator */
%nonassoc CLUSTER_EXP HOSTGROUP ADMIN GET_CLUSTER GET_GROUP /* highest */
%left COLON
%left LBRACE RBRACE

%start main
%type <Ast.expr> main  /* the parser will return an AST */
%%

main:
    rangeexpr EOL      { $1 }
;

rangeexpr:
    | { Ast.EmptyExpr }
    | LITERAL { Ast.Literal $1 }
    | LITERAL LITERAL { Ast.Literal ($1 ^ $2) }
    | RANGE { match $1 with (prefix, start, finish, domain) ->
        Ast.Range (prefix, start, finish, domain) }
    | LPAREN rangeexpr RPAREN { Ast.Parens $2 }
    | rangeexpr UNION rangeexpr { Ast.Union ($1, $3) }
    | rangeexpr LBRACE rangeexpr RBRACE rangeexpr { Ast.Braces ($1, $3, $5) }
    | REGEX { Ast.Regex $1 }
    | rangeexpr DIFF rangeexpr { Ast.Diff ($1, $3) }
    | rangeexpr INTER rangeexpr { Ast.Inter ($1, $3) }
    | rangeexpr INTER_HP rangeexpr { Ast.Inter ($1, $3) }
    | CLUSTER_EXP rangeexpr COLON rangeexpr 
        { Ast.Cluster ($2, $4) }
    | CLUSTER_EXP rangeexpr { Ast.Cluster ($2, (Ast.Literal "CLUSTER")) }
    | ADMIN rangeexpr { Ast.Admin $2 }
    | HOSTGROUP rangeexpr { Ast.HostGroup $2 }
    | GET_CLUSTER rangeexpr { Ast.GetCluster $2 }
    | NOT rangeexpr { 
	Ast.Diff ((Ast.Cluster ((Ast.Literal "GROUPS"), (Ast.Literal "ALL"))), 
		  $2) }
    | GET_GROUP rangeexpr { Ast.GetGroup $2 }
    | FUNCTION { Ast.Function (fst($1), snd($1)) }
;

