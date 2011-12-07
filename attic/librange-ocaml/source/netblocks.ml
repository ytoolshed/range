open Range_utils
open Memoize

exception NetmaskErr of string
let netmask_colo_memo =
  memoize (
    fun () ->
      let netmask_colo = Hashtbl.create 611 in
      let colo_netmask = Hashtbl.create 37 in
      let lines = good_lines (read_file "/etc/yst-ip-list") in

      let rec parse_netblocks lines =
	match lines with
	  | line :: rest ->
	    begin
	      let fields = Pcre.split line in
		match fields with
		  | colo :: netmask_str :: rest ->
		      let netmask = Netmask.netmask_of_string netmask_str in
			Hashtbl.add netmask_colo netmask (netmask_str, colo);
			Hashtbl.add colo_netmask colo netmask_str
		  | _ -> raise (NetmaskErr ("yst-ip-list: " ^ line))
	    end;
	      parse_netblocks rest
	  | [] -> () in
	parse_netblocks lines;
	netmask_colo, colo_netmask)

let find_netblock ip =
  let netmask_colo, _ = netmask_colo_memo.get () in
    Netmask.find_netblock ip netmask_colo

let vlans_for_dc dc =
  let _, colo_netmask = netmask_colo_memo.get () in
    Hashtbl.find_all colo_netmask dc
      
let clear_cache () = netmask_colo_memo.clear ()
