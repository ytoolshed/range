open Memoize;;

let hosts_vlan_hash =
  memoize
    (fun () ->
       let h_v = Hashtbl.create 41113 in
       let v_h = Hashtbl.create 1097 in
       let ip_hosts = Tinydns.all_ip_hosts () in
	 List.iter (fun (ip,host) -> match Netblocks.find_netblock ip with
			None -> ignore ()
		      | Some (net, _) ->
			  Hashtbl.add h_v host net;
			  Hashtbl.add v_h net host) ip_hosts;
	 (h_v, v_h))


let hosts_in_netblock blk =
  let _, v_h = hosts_vlan_hash.get () in
    try
      Some (Hashtbl.find_all v_h blk)
    with Not_found -> None

let netblock_for_host host =
  let h_v, _ = hosts_vlan_hash.get () in
    try 
      Some (Hashtbl.find h_v host)
    with Not_found -> None
    


