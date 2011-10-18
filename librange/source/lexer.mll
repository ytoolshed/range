{
    open Parser
    open Printf
    open Pcre
    open Range_utils
    let re_buf = Buffer.create 256
    let args_buf = Buffer.create 1024
      (* optional prefix + digits + optional domain dash same prefix (optional) +
       * digits + same optional domain if there was one, or an optional domain  *)
    let node_regex = regexp
      "^([-\\w.]*?)(\\d+)(\\.[-A-Za-z\\d.]*[-A-Za-z]+[-A-Za-z\\d.]*)?-\\1?(\\d+)((?(3)\\3|(?:\\.[-A-Za-z\\d.]+)?))$"
}

let digit = ['0'-'9']
let letter = ['a'-'z' 'A'-'Z']
let hostchar = letter | digit | '_' | '.' (* no dashes *)
let hostchard = hostchar | '-'

rule token = parse
    | [' ' '\t' '\n'] { token lexbuf }
    | '#'? ((letter | '_')+ as name) '(' { FUNCTION (name, (args 1 lexbuf)) }

    (* optimization: don't use pcre unless the expression has a '-' *)
    | (hostchar+ as literal) { LITERAL(literal) } 
    | (hostchar hostchard* as range) {
    try
      let res = extract ~full_match:false ~rex:node_regex range in
      let pref = res.(0) and fst = res.(1) and dom = res.(2) and 
          lst = res.(3) and dom' = res.(4)
      in RANGE(pref, fst, lst, (if dom = "" then dom' else dom))
    with Not_found -> LITERAL(range) }
    | ",-" { DIFF }  (* to keep people happy *)
    | ",&" { INTER } (* to keep people happy *)
    | '&' { INTER_HP } (* Higher precedence intersection *)
    | ',' { UNION }
    | '(' { LPAREN }
    | ')' { RPAREN }
    | '{' { LBRACE }
    | '}' { RBRACE }
    | '/' { REGEX (in_regex lexbuf) }
    | ':' { COLON }
    | '^' { ADMIN }
    | '%' { CLUSTER_EXP }
    | '@' { HOSTGROUP }
    | '*' { GET_CLUSTER }
    | '!' { NOT }
    | '?' { GET_GROUP }
    | hostchar+ as x { LITERAL (x) } 
    | eof { EOL }
    | "-" { DIFF }  (* this might break things *)
    | _ as c { do_warning "LEXER" (Printf.sprintf "Invalid character: '%c'" c); token lexbuf }
and in_regex = parse
    (* End of the regex *)
    | '/' { let r = Buffer.contents re_buf in
            Buffer.clear re_buf;
            r }
    | '\\' ( '\\' | '/' as c) {
        Buffer.add_char re_buf c;
        in_regex lexbuf }
    | _ as c {
        Buffer.add_char re_buf c;
        in_regex lexbuf }
    | eof { do_warning "LEXER" "Need end of regex delimiter"; "INVALID_REGEX" }
and args n = parse
  | '(' { 
      Buffer.add_char args_buf '(';
      args (n + 1) lexbuf }
  | ')' { 
      Buffer.add_char args_buf ')';
      match n with
	  0 -> do_warning "LEXER" "Need open parens first"; "INVALID_ARGS"
	| 1 ->
	    let r = Buffer.contents args_buf in
	      Buffer.clear args_buf;
	      String.sub r 0 ((String.length r) - 1) (* get rid of the parens *)
	| _ -> args (n - 1) lexbuf }
  | _ as c {
      Buffer.add_char args_buf c;
      args n lexbuf }
  | eof { do_warning "LEXER" "Need closing parens"; "INVALID_ARGS" }

