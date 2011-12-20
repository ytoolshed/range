type ip
val get_ip : string -> ip option
val clear_cache : unit -> unit
val fqdn : string -> string
val all_ip_hosts : unit -> (ip * string) list
val int_of_ip : ip -> int64
val string_of_ip : ip -> string
val quad2int : string -> int64
