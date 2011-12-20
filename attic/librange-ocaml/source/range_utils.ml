let do_warnings = ref false

let want_warnings t =
  let prev_value = !do_warnings in
    do_warnings := t;
    prev_value

(* print a warning if the user called 'want_warnings true' *)
let print_warning warn_type node = 
  Printf.eprintf "%s: %s\n" warn_type node;
  flush stderr

let warning_callback = ref print_warning

let set_warning_callback f = warning_callback := f
  
let do_warning warn_type node =
  if !do_warnings then
    !warning_callback warn_type node

let is_dir x =
  let st = Unix.stat x in
    st.Unix.st_kind = Unix.S_DIR;;

let is_file x =
  try
    let st = Unix.stat x in
      st.Unix.st_kind = Unix.S_REG
  with Unix.Unix_error _ -> false

(* like sprintf %0<len>d n *)
let pad0 n len =
  let s = string_of_int n in
  let ls = String.length s in
  let b = Buffer.create 16 in
    for i = ls to (len - 1) do
      Buffer.add_char b '0'
    done;
    Buffer.add_string b s;
    Buffer.contents b 

(* get the keys of a hash as a list *)
let hash_keys hash = Hashtbl.fold (fun k _ acc -> k::acc) hash []

(* true if 'str' begins with 'substr' *)  
let begins_with substr str =
  let l1 = String.length substr and
      l2 = String.length str in
    if l1 > l2 then false
    else
      let leftstr = String.sub str 0 l1 in
	leftstr = substr

(* true if 'str' ends with 'substr' *)
let ends_with substr str =
  let l1 = String.length substr and
      l2 = String.length str in
    if l1 > l2 then false
    else
      let rightstr = String.sub str (l2 - l1) l1 in
	rightstr = substr
	  
(* read a file returning a list of lines *)
let read_file filename =
  let ch = open_in filename and
      lines = ref [] in
  let rec loop () = 
    let ln = input_line ch in
      lines := ln :: !lines;
      loop () in
    try
      loop ();
    with
	End_of_file -> close_in ch; List.rev !lines

(* read a file - following $INCLUDE if needed *)
let rec read_big_file filename =
  let get_reldir_name fn =
    try (String.sub fn 0 (String.rindex fn '/')) ^ "/" with _ -> "" and
      get_file_name ln =
    let inc_re = Pcre.regexp "\\$INCLUDE\\s+\"([^\"]+)\"" in
      (Pcre.extract ~full_match:false ~rex:inc_re ln).(0) and
      ch = open_in filename and
      lines = ref [] in
    try
      let rec loop () =
	let ln = input_line ch in
	  if begins_with "$INCLUDE" ln then
	    begin
	      let inc_fn = get_file_name ln in
	      let included_file_name = 
		if inc_fn.[0] = '/' then inc_fn 
		else (get_reldir_name filename) ^ inc_fn in
		lines := (List.rev
			    (read_big_file included_file_name)) @
		  !lines
	    end
	  else
            lines := ln::!lines;
	  loop () in
	loop ()
    with
	End_of_file -> close_in ch; List.rev !lines

(* return a list of lines that are not comments and not blank *)
let good_lines lines =
  let comment_re = Pcre.regexp "#.*" and
      end_blank_re = Pcre.regexp "\\s+$" in
  let fix_line line = Pcre.replace ~rex:end_blank_re
    (Pcre.replace ~rex:comment_re line) in
    List.filter (fun l -> String.length l > 0)
      (List.map fix_line lines)

let hash_keys h =
  Hashtbl.fold (fun k _ acc -> k :: acc) h []

let hash_values h =
  Hashtbl.fold (fun _ v acc -> v :: acc) h []
