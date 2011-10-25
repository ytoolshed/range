open Scanf
open Int64
exception NetmaskErr of string

let imask_array = Array.make 33 0L
let init_imask =
  let imask n =
    sub
      (shift_left 1L 32)
      (shift_left 1L (32 - n)) in
    for i = 0 to 32 do
      imask_array.(i) <- imask i
    done

type netmask = { base: int64; bits: int }
(* return a binary representation of the netmask *)
let netmask_of_string netmask =
  let netmask_parts =
    let rex = Pcre.regexp "^(\\d+\\.\\d+\\.\\d+\\.\\d+)/(\\d+)$" in
      try
	Pcre.extract ~rex ~full_match:false netmask
      with Not_found ->
	let rex = Pcre.regexp "^\\d+\\.\\d+\\.\\d+\\.\\d+$" in
	  if Pcre.pmatch ~rex netmask then
	    [| netmask ; "32" |]
	  else
	    raise (NetmaskErr ("netmask: " ^ netmask)) in
	let net_base = Tinydns.quad2int netmask_parts.(0) and
	    net_bits = int_of_string netmask_parts.(1) in
	let net_mask = imask_array.(net_bits) in
	  { base=logand net_base net_mask; bits = net_bits }

let string_of_netmask netmask =
  let b = netmask.base in
    Printf.sprintf "%d.%d.%d.%d/%d"
      (to_int (shift_right (logand b 0xff000000L) 24)) 
      (to_int (shift_right (logand b 0x00ff0000L) 16))
      (to_int (shift_right (logand b 0x0000ff00L) 8))
      (to_int (logand b 0x000000ffL))
      netmask.bits

let host_in_netblock netblock ip =
  let binary_ip = Tinydns.int_of_ip ip and
      imask = imask_array.(netblock.bits) in
    (logand binary_ip imask) = netblock.base

(* find the netblock for the given IP *)
let find_netblock ip hash =
  let binary_ip = Tinydns.int_of_ip ip in
  let rec find_it n bits =
    if bits < 0 then None
    else
      let search_bits = logand n (imask_array.(bits)) in
      let net = { base=search_bits; bits=bits } in
	if Hashtbl.mem hash net then
	  Some (Hashtbl.find hash net)
	else
	  find_it n (bits - 1) in
    find_it binary_ip 32
