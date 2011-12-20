(* parse admins.cf *)
open Memoize
open Range_utils
  
exception AdminsErr of string

let boothost_file_memo =
  memoize (
    fun () ->
      let boothosts_cf =
	if is_file "/usr/local/jumpstart/conf/admins.cf" then
	  "/usr/local/jumpstart/conf/admins.cf"
	else
	  "/JumpStart/conf/admins.cf" in
      let ch = open_in boothosts_cf in
      let netblock_boothost = Hashtbl.create 253 in
      let boothost_netblock = Hashtbl.create 253 in
      let boothost_re = Pcre.regexp "^([-\\w.]+):\\s*$" and
	  netmask_re = Pcre.regexp "^\\s+-\\s+(\\d+\\.\\d+\\.\\d+\\.\\d+/\\d+)\\s*$" and
	  cur_boothost = ref "" in
	
      let rec loop () =
	let line = input_line ch in
	  if Pcre.pmatch ~rex:boothost_re line then
	    cur_boothost := (Pcre.extract ~rex:boothost_re ~full_match:false line).(0)
	  else
	    if Pcre.pmatch ~rex:netmask_re line then begin
	      let netmask = (Pcre.extract ~rex:netmask_re ~full_match:false line).(0) in
	      let net = (Netmask.netmask_of_string netmask) in
		Hashtbl.add netblock_boothost net !cur_boothost;
		Hashtbl.add boothost_netblock !cur_boothost net
	    end;
	  loop () in
      let header = input_line ch in
	if header <> "---" then
	  raise (AdminsErr ("Wrong header admins.cf: " ^ header));
	try
	  loop ();
	with
	    End_of_file -> (netblock_boothost, boothost_netblock))

let boothosts_for_netblock netblock =
  let hash, _ = boothost_file_memo.get () in
    try
      Some (Hashtbl.find_all hash (Netmask.netmask_of_string netblock))
    with Not_found ->
      do_warning "NOBOOTHOST_NETBLOCK" netblock;
      None
	
let netblocks_for_boothost boothost =
  let _, hash = boothost_file_memo.get () in
    try
      Some (List.map Netmask.string_of_netmask (Hashtbl.find_all hash boothost))
    with Not_found ->
      do_warning "NONETBLOCK_BOOTHOST" boothost;
      None

let all_boothosts () =
  let _, hash = boothost_file_memo.get () in
    hash_keys hash
    
let clear_cache () = boothost_file_memo.clear ()
