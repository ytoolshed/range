open Evaluate

let parse_range range = compress_range (expand_range range);;

Callback.register "ocaml_parse_range" parse_range;;
Callback.register "ocaml_expand_range" expand_range;;
Callback.register "ocaml_compress_range" compress_range;;
Callback.register "ocaml_sorted_expand_range" sorted_expand_range;;
Callback.register "ocaml_range_set_altpath" range_set_altpath;;
Callback.register "ocaml_want_caching" want_caching;;
Callback.register "ocaml_want_warnings" want_warnings;;
Callback.register "ocaml_clear_caches" clear_caches;;

