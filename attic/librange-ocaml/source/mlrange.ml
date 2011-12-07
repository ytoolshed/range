open Evaluate

let do_count = ref false
let do_expand = ref false
let range = ref ""

let _ =
  let warn_hash = Hashtbl.create 1733 in
  let add_warning warn_type node =
    if Hashtbl.mem warn_hash warn_type then
      let new_list = node :: (Hashtbl.find warn_hash warn_type) in
	Hashtbl.replace warn_hash warn_type new_list
    else
      Hashtbl.add warn_hash warn_type (node::[]) in
    
  let print_warnings () =
    let node_list nl =
      let ary_nodes = Array.of_list nl in
	compress_range ary_nodes in
      
    let print_warn w nl =
      print_endline ("  " ^ w ^ ": " ^ (node_list nl)) in
      
      if Hashtbl.length warn_hash > 0 then
	begin
	  print_endline "WARNINGS";
	  Hashtbl.iter
	    (fun k v -> print_warn k v)
	    warn_hash
	end in

  let args = [ ("--count", Arg.Set do_count, "\tcount the nodes");
	       ("-c", Arg.Set do_count, "\t\tcount the nodes");
	       ("--expand", Arg.Set do_expand, "\tprint the nodes one per line");
	       ("-e", Arg.Set do_expand, "\t\tprint the nodes one per line")
	     ] in
    Arg.parse args (fun r -> range := r) "Usage: range [options] <secorange>\nWhere options are:";
    want_caching true;
    want_warnings true;
    set_warning_callback add_warning;

    if !range = "" then print_endline "Need a range to parse."
    else begin
      let nodes = expand_range !range in
	if !do_count then
	  Printf.printf "%d\n" (Array.length nodes)
	else if !do_expand then
	  Array.iter print_endline nodes
	else
	  print_endline (compress_range nodes);
    end;
    
    print_warnings ();;


