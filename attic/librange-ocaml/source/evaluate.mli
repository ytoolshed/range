(* Public interface for the range parser *)
val range_set_altpath : string -> unit
val expand_range : string -> string array
val sorted_expand_range : string -> string array
val compress_range : string array -> string -> string
val want_caching : bool -> unit
val want_warnings : bool -> bool
val set_warning_callback : (string -> string -> unit) -> unit
val clear_caches : unit -> unit
