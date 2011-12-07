(* parse the tinydns root/data file *)
open Memoize
open Range_utils
open Int64
  
type ip = { binary: int64; repr: string }

(* have to do 64 bit arithmetic because 32 bit ints are signed
   and the default int uses an extra bit so we only have 30 usable bits *)
let quad2int ip =
  Scanf.sscanf ip "%d.%d.%d.%d"
    (fun a b c d ->
       (add
	  (add
	     (shift_left (of_int a) 24)
	     (shift_left (of_int b) 16))
	  (add
	     (shift_left (of_int c) 8)
	     (of_int d))))

let ip_of_string str = 
    { binary=quad2int str; repr=str }

let int_of_ip ip = ip.binary
let string_of_ip ip = ip.repr  

let dns_read_memo =
  memoize (
    fun () ->
      let hosts_ip = Hashtbl.create 99997 in
      let cnames = Hashtbl.create 23433 in
      let ch = open_in "/etc/service/tinydns/root/data" in
      let a_rec_re = Pcre.regexp "^\\+([^:]+):([\\d.]+):0" in
      let cname_rec_re = Pcre.regexp "^C([^:]+):([^:]+)\\.:0" in
      let rec loop () =
	let ln = input_line ch in
	  begin
	    try
	      let res = Pcre.extract ~full_match:false ~rex:a_rec_re ln in
		Hashtbl.add hosts_ip res.(0) (ip_of_string res.(1))
	    with Not_found -> (
	      try
		let res = Pcre.extract ~full_match:false ~rex:cname_rec_re ln in
		  Hashtbl.add cnames res.(0) res.(1)
	      with Not_found -> ();
	    );
	  end;
	  loop() in
	try
	  loop ();
	with
	    End_of_file -> close_in ch;
	      (hosts_ip, cnames));;

let fqdn host =
  if ends_with ".com" host then host
  else if ends_with ".net" host then host
  else host ^ ".inktomisearch.com"

(* If the first character is a digit, we return it unmodified, since
   chances are it is an IP.
   Maybe I should do a full blown regex (^[\d.]+$) - and actually benchmark
   the cost of it but for now this will do *)
let get_ip host =
  if host.[0] >= '0' && host.[0] <= '9' then Some (ip_of_string host)
  else 
    let (a, c) = dns_read_memo.get () in
    let rec resolve_cname host =
      if Hashtbl.mem c host then
	resolve_cname (Hashtbl.find c host)
      else
	host in
    let real_name = resolve_cname (fqdn host) in
      try
	Some (Hashtbl.find a real_name)
      with Not_found -> 
	do_warning "NOTINYDNS" real_name;
	None

	  
let clean_up hostname =
  let remove_domain host domain =
      let n = String.length host in
	if ends_with domain host then 
	  String.sub host 0 (n - (String.length domain))
	else
	  host in
  let n = String.length hostname in
  let final_char = hostname.[n - 1] in
  let host_no_dot =
    if final_char = '.' then
      String.sub hostname 0 (n - 1)
    else
      hostname in
  let inkt = remove_domain host_no_dot ".inktomisearch.com" in
  let yst = remove_domain inkt ".yst.corp.yahoo.com" in
    yst

(* return a list of all the IPs (with the hostnames associated with them) *)
let all_ip_hosts () =
  match dns_read_memo.get() with
      a_records, _ ->
	Hashtbl.fold (fun k v a -> (v,clean_up k) :: a) a_records []

let clear_cache () = dns_read_memo.clear ()

