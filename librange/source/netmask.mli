type netmask
val netmask_of_string : string -> netmask
val string_of_netmask : netmask -> string
val find_netblock : Tinydns.ip -> (netmask, 'a) Hashtbl.t -> 'a option
val host_in_netblock : netmask -> Tinydns.ip -> bool
