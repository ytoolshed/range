(* show warnings true/false *)
val want_warnings : bool -> bool

(* print a warning if the user said 'want_warnings true' *)
val do_warning : string -> string -> unit

(* instead of printing the warning, just call this function instead *)
val set_warning_callback : (string -> string -> unit) -> unit

(* -d <path> *)
val is_dir : string -> bool

(* -e <file> *)
val is_file : string -> bool

(* like sprintf %0<len>d n *)
val pad0 : int -> int -> string

(* get the keys of a hash a list *)
val hash_keys : ('a, 'b) Hashtbl.t -> 'a list

(* begins_with <substr> <str> *)
val begins_with : string -> string -> bool
(* ends_with <substr> <str> *)
val ends_with : string -> string -> bool

(* read a file, returning a list of lines *)
val read_file : string -> string list

(* read a file following $INCLUDE directives *)
val read_big_file : string -> string list

(* return a list of lines that are not comments and not blank *)
val good_lines : string list -> string list

val hash_keys : ('a, 'b) Hashtbl.t -> 'a list
val hash_values : ('a, 'b) Hashtbl.t -> 'b list
  
