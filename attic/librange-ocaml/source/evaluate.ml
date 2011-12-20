open Memoize
open Printf
open Range_utils

exception SyntaxErr of string
exception RangeErr of string
exception FuncErr of string

module StrSet = Set.Make(String)

let do_caching = ref true
let want_caching t = do_caching := t

let use_ranged = ref false
let want_ranged t = use_ranged := t
  
(* return a list of directories under this path with nodes.cf files *)
let get_cluster_dirs path =
  let dh = Unix.opendir path in
  let entries = ref [] in
    try
      while true do
        let entry = (Unix.readdir dh) in
          match entry.[0] with
            | '.' -> ()
            | _ -> let fullname = path ^ "/" ^ entry in
                if is_dir fullname && is_file (fullname ^ "/nodes.cf")
                then entries := entry::!entries;
      done;
      []
    with End_of_file -> Unix.closedir dh; !entries;;


(* create a set from a list of strings *)
let set_of_list lst =
  let rec set_of_list_rec lst acc =
    match lst with
      | [] -> acc
      | hd::tl -> set_of_list_rec tl (StrSet.add hd acc) in
    set_of_list_rec lst StrSet.empty;;

let range_altpath = ref ""
let range_set_altpath s = range_altpath := s

let file_exists f = try (Unix.stat f).Unix.st_kind = Unix.S_REG
with Unix.Unix_error _ -> false

let get_cluster_file cluster =
  let alt = !range_altpath in
  let locations = [alt ^ "/" ^ cluster ^  "/tools/conf/nodes.cf";
                   alt ^ "/" ^ cluster ^ "/nodes.cf";
                   "/home/seco/tools/conf/" ^ cluster ^ "/nodes.cf";
                   "/usr/local/gemclient/" ^ cluster ^ "/nodes.cf"] in
    List.find file_exists locations

let ignore_clusters_file () =
  let alt = !range_altpath in
  let locations = [
    alt ^ "/all/tools/conf/IGNORE";
    alt ^ "/all/IGNORE";
    "/home/seco/tools/conf/all/IGNORE"] in
    List.find file_exists locations

(* Dirs to ignore for whoismycluster *)
(* TODO Add a warning when IGNORE is not found *)
let ignore_dirs_memo =
  memoize
    (fun () ->
       try
         let mark_cluster hash cluster = Hashtbl.add hash cluster true in
         let c = read_big_file (ignore_clusters_file()) in
         let h = Hashtbl.create (List.length c) in
           List.iter (mark_cluster h) c;
           h
       with Not_found -> Hashtbl.create 1)

(* Should we consider this directory for whoismycluster *)
let interesting_dir dir =
  let h = ignore_dirs_memo.get () in
    not (Hashtbl.mem h dir);;

let read_cluster_file cluster =
  try
    read_big_file (get_cluster_file cluster)
  with Not_found -> (
    do_warning "NOCLUSTERDEF" cluster;
    [""]
  )

(* get the location of the vips.cf file *)
let get_vips_file cluster =
  let alt = !range_altpath in
  let locations = [ alt ^ "/" ^ cluster ^ "/tools/conf/vips.cf";
                    alt ^ "/" ^ cluster ^ "/vips.cf";
                    "/home/seco/tools/conf/" ^ cluster ^ "/vips.cf"] in
    List.find file_exists locations

(* create a set with the vips for a given cluster *)
let get_cluster_vips_field cluster field =
  try
    set_of_list (List.map (fun ln -> List.nth (Pcre.split ln) field)
                   (good_lines (read_big_file (get_vips_file cluster))))
  with
      Not_found -> StrSet.empty

(* create a set with the vips for a given cluster *)
let get_cluster_vips cluster =
  get_cluster_vips_field cluster 0

let get_cluster_viphosts cluster =
  get_cluster_vips_field cluster 1

(* utility function to get the key of a hash w/o raising Not_found *)   
let find_key h key =
  try Hashtbl.find h key
  with Not_found -> ""

(* how deep are we recursing *)
let eval_recursion = ref 0

(* Construct a set for the given range *)
let range prefix start finish domain =
  let len = String.length start
  and len_end = String.length finish in
  let padded_end =
    if len > len_end then
      (String.sub start 0 (len - len_end)) ^ finish
    else finish in
  let istart = int_of_string(start) and
      iend = int_of_string(padded_end) in
  let fmt_node pre n suf =
    pre ^ (pad0 n len) ^ suf in
  let rec add_elts set i =
    if i < iend then
      add_elts (StrSet.add (fmt_node prefix i domain) set) (i+1)
    else
      StrSet.add (fmt_node prefix iend domain) set in
    if istart < iend then
      add_elts StrSet.empty istart
    else if istart = iend then
      StrSet.singleton (prefix ^ start ^ domain)
    else
      StrSet.singleton (prefix ^ start ^ "-" ^ finish ^ domain)

let union a b = StrSet.union a b
let diff a b = StrSet.diff a b
let inter a b = StrSet.inter a b
let literal str = StrSet.singleton str
let elements a = StrSet.elements a
(* braces generates all the combinations of pre_set ^ mid_set ^ post_set *)
let braces pre_set_arg mid_set_arg post_set_arg =
  (* return a set with a single element 'default' if the given set is empty *)
  let empty_set set default = match (StrSet.cardinal set) with
    | 0 -> StrSet.singleton default
    | _ -> set in
  let pre_set = empty_set pre_set_arg "" and
      mid_set = empty_set mid_set_arg "" and
      post_set = empty_set post_set_arg "" in
    StrSet.fold
      (fun post a_post ->
         union
           (StrSet.fold
              (fun pre a_pre ->
                 union
                   (StrSet.fold
                      (fun x a_mid -> StrSet.add (pre ^ x ^ post) a_mid)
                      mid_set StrSet.empty)
                   a_pre)
              pre_set StrSet.empty)
           a_post)
      post_set StrSet.empty

let rec optimize expr =
  match expr with
      (* Optimizations here *)
    | Ast.Inter(e, Ast.Regex re) -> Ast.Filter ((optimize e), re)
    | Ast.Diff(e, Ast.Regex re) -> Ast.NotFilter ((optimize e), re)
(* don't know how to optimize these so we just copy them *)
    | Ast.Braces(pre, e, post) -> Ast.Braces (pre, (optimize e), post)
    | Ast.HostGroup hg -> Ast.HostGroup (optimize hg)
    | Ast.Parens expr -> Ast.Parens (optimize expr)
    | Ast.Union (a, b) -> Ast.Union ((optimize a),(optimize b))
    | Ast.Diff (a, b) -> Ast.Diff ((optimize a),(optimize b))
    | Ast.Inter (a, b) -> Ast.Inter ((optimize a),(optimize b))
    | Ast.Cluster (c, k) -> Ast.Cluster ((optimize c),(optimize k))
    | Ast.Admin nodes -> Ast.Admin (optimize nodes)
    | Ast.GetCluster nodes -> Ast.GetCluster (optimize nodes)
    | Ast.Filter (nodes, re) -> Ast.Filter ((optimize nodes), re)
    | Ast.NotFilter (nodes, re) -> Ast.NotFilter ((optimize nodes), re)
    | Ast.GetGroup nodes -> Ast.GetGroup (optimize nodes)
    | _ -> expr;;

let rec evaluate expr =
  match expr with
    | Ast.EmptyExpr -> StrSet.empty
    | Ast.Literal s -> StrSet.singleton s
    | Ast.Range (prefix, start, finish, domain)
      -> range prefix start finish domain
    | Ast.Braces (pre, elts, post)
      -> braces (evaluate pre) (evaluate elts) (evaluate post)
    | Ast.Regex re
      -> regex re
    | Ast.HostGroup hg -> hostsgroups_of (evaluate hg)
    | Ast.Parens expr -> evaluate expr
    | Ast.Union (a, b) -> union (evaluate a) (evaluate b)
    | Ast.Diff (a, b) -> diff (evaluate a) (evaluate b)
    | Ast.Inter (a, b) -> inter (evaluate a) (evaluate b)
    | Ast.Cluster (clusters, keys) -> exp_clusters (evaluate clusters) (evaluate keys)
    | Ast.Admin nodes -> admin_of (evaluate nodes)
    | Ast.GetCluster nodes -> fast_cluster_of (evaluate nodes)
    | Ast.Filter (nodes, re) -> filter (evaluate nodes) re
    | Ast.NotFilter (nodes, re) -> notfilter (evaluate nodes) re
    | Ast.GetGroup nodes -> groups_of (evaluate nodes)
    | Ast.Function (name, args) -> eval_func name args
and expr_of_string s =
  let lexbuf = Lexing.from_string s in
    Parser.main Lexer.token lexbuf
and eval_string_not_memo s =
  match String.length s with
    | 0 -> StrSet.empty
    | _ ->
        try evaluate (optimize (expr_of_string s))
        with Parsing.Parse_error ->
          raise (SyntaxErr (sprintf "Syntax error: [%s]" s));
and eval_memo = Hashtbl.create 1023
and clear_eval_cache () = Hashtbl.clear eval_memo
and eval_string s =
    try
      Hashtbl.find eval_memo s
    with Not_found ->
      incr eval_recursion;
      if !eval_recursion > 32 then
        raise (RangeErr("Recursion Too Deep: " ^ s));
      let res = eval_string_not_memo s in
        Hashtbl.add eval_memo s res ;
        decr eval_recursion;
        res
and cluster_keys_memo = Hashtbl.create 511
and clear_cluster_keys_cache () = Hashtbl.clear cluster_keys_memo
and cluster_keys_not_memo cluster =
  let cur_range = ref [] and
      cur_key = ref "" and
      h : (string, string) Hashtbl.t = Hashtbl.create 19 in
  let parsed_cur_range () =
    let key_re = Pcre.regexp "\\$(\\w+)" and
        cluster_subst = Pcre.subst ("%" ^ cluster ^ ":$1") and
        r = String.concat "," (List.rev !cur_range) in
      Pcre.replace ~rex:key_re ~itempl:cluster_subst r in
  let add_cur_key hash =
    if String.length !cur_key > 0
    then Hashtbl.add hash !cur_key (parsed_cur_range ())
    else () in
  let inc_re = Pcre.regexp "^\\s+INCLUDE\\s+" and
      exc_re = Pcre.regexp "^\\s+EXCLUDE\\s+" in
  let include_line ln = Pcre.pmatch ~rex:inc_re ln and
      exclude_line ln = Pcre.pmatch ~rex:exc_re ln in
  let get_include_line ln = Pcre.replace ~rex:inc_re ln and
      get_exclude_line ln = "-(" ^ (Pcre.replace ~rex:exc_re ln) ^ ")" in
  let process_line line =
    let c = line.[0] in
      if c = ' ' || c = '\t' then
        if include_line line then
          cur_range :=  (get_include_line line)::!cur_range
        else
          if exclude_line line then
            cur_range := (get_exclude_line line)::!cur_range
          else 
            do_warning "SYNTAXERROR" (cluster ^ ": [" ^ line ^ "]")
      else begin
        add_cur_key h;
        cur_key := line;
        cur_range := [];
      end in

    List.iter process_line (good_lines (read_cluster_file cluster));
    add_cur_key h;
    h
and cluster_keys cluster =
  try
    Hashtbl.find cluster_keys_memo cluster
  with Not_found ->
    let keys = cluster_keys_not_memo cluster in
      Hashtbl.add cluster_keys_memo cluster keys ;
      keys
and expand_one_cluster cluster key =
  match key with
    | "VIPS" ->  get_cluster_vips cluster
    | "VIPHOSTS" -> get_cluster_viphosts cluster
    | _ -> let ckeys = cluster_keys(cluster) in
        if key = "KEYS" then set_of_list (hash_keys ckeys)
        else eval_string (match key with
                            | "DOWN" -> "%" ^ cluster ^ ":ALL,-%" ^ cluster ^ ":CLUSTER"
                            | "UP" -> "%" ^ cluster ^ ":CLUSTER"
                            | _  -> find_key ckeys key)
and exp_clusters cls keys =
  let exp_cl_keys c =
    StrSet.fold (fun k ka -> union (expand_one_cluster c k) ka)
      keys StrSet.empty in
    StrSet.fold (fun c ca -> union (exp_cl_keys c) ca) cls StrSet.empty
and all_nodes () = expand_one_cluster "GROUPS" "ALL"
and filter nodes re =
  let rex=Pcre.regexp re in
    StrSet.filter (fun x -> Pcre.pmatch ~rex x) nodes
and notfilter nodes re =
  let rex=Pcre.regexp re in
    StrSet.filter (fun x -> not (Pcre.pmatch ~rex x)) nodes
and regex re = filter (all_nodes ()) re
and hostsgroups_of hg =
  StrSet.fold (fun x a -> union (
                 match x.[0] with
                     'a'..'z' -> expand_one_cluster "HOSTS" x
                   | _ -> expand_one_cluster "GROUPS" x
               ) a) hg
    StrSet.empty
and admins_hash_memo = ref None
and clear_admins_hash_cache () = admins_hash_memo := None
and admins_hash () = match !admins_hash_memo with
    None ->
      let add_node h a n = Hashtbl.add h n a in
      let add_nodes_from_admin h a =
        let nodes = expand_one_cluster "HOSTS" a in
          List.iter (add_node h a) (StrSet.elements nodes) in
      let h = Hashtbl.create 21073 in
      let admins = expand_one_cluster "HOSTS" "KEYS" in
        StrSet.iter (add_nodes_from_admin h) admins;
        admins_hash_memo := Some h;
        h
  | Some hash -> hash
and admin_of nodes =
  let admin_for node =
    let h = admins_hash () in
      try Some (Hashtbl.find h node)
      with Not_found ->
        do_warning "NOADMIN" node;
        None in
  let rec admins node_lst acc =
    match node_lst with
      | [] -> acc
      | hd::tl -> match (admin_for hd) with
            Some a -> admins tl (StrSet.add a acc)
          | None -> admins tl acc in
    admins (StrSet.elements nodes) StrSet.empty
and cluster_hash_memo = ref None
and clear_cluster_hash_cache () = cluster_hash_memo := None
and cluster_hash lst = match !cluster_hash_memo with
    None ->
      let add_cluster h cl =
        let add_node h n = Hashtbl.add h n cl in
        let cl_nodes = expand_one_cluster cl "ALL" in
          StrSet.iter (add_node h) cl_nodes in
      let h = Hashtbl.create 41073 in
        List.iter (add_cluster h) lst;
        cluster_hash_memo := Some h;
        h
  | Some hash -> hash
(* TODO use alt_path *)
and all_clusters =
  memoize (fun () ->
      let dir = "/home/seco/tools/conf" in
      List.filter interesting_dir (get_cluster_dirs dir))
and get_all_clusters nodes =
  let cl = all_clusters.get() in
  let all_cluster_for node =
    let node_cl_hash = cluster_hash(cl) in
      try
        Some (Hashtbl.find_all node_cl_hash node)
      with Not_found ->
        do_warning "NOCLUSTER" node;
        None in
  let rec clusters node_lst acc =
    match node_lst with
      | [] -> acc
      | node :: tl -> match (all_cluster_for node) with
          | None -> clusters tl acc
          | Some c -> clusters tl (StrSet.union (set_of_list c) acc) in
    clusters (StrSet.elements nodes) StrSet.empty
and fast_cluster_of nodes =
  let cl = all_clusters.get() in
  let node_cl_hash = cluster_hash(cl) in
  let best_guess_re = Pcre.regexp "^([a-z]+\\d\\d\\d)" in
  let fast_cluster_for node =
    try
      let res = Pcre.extract ~rex:best_guess_re ~full_match:false node in
      let potential_cluster = res.(0) in
      if Hashtbl.mem node_cl_hash potential_cluster then (
          let prev_warnings = Range_utils.want_warnings false in
          let cl_nodes = expand_one_cluster potential_cluster "ALL" in
            ignore (Range_utils.want_warnings prev_warnings);
            if StrSet.mem node cl_nodes then
              Some potential_cluster
            else None)
      else
        None
    with Not_found -> None in
  let slow_cluster_for node =
      try
        Some (Hashtbl.find node_cl_hash node)
      with Not_found ->
        do_warning "NOCLUSTER" node;
        None in
  let rec clusters node_lst acc =
    match node_lst with
      | [] -> acc
      | node :: tl -> match (fast_cluster_for node) with
          | None ->
              (match (slow_cluster_for node) with
                 | None -> clusters tl acc
                 | Some c -> clusters tl (StrSet.add c acc))
          | Some c -> clusters tl (StrSet.add c acc) in
    clusters (StrSet.elements nodes) StrSet.empty 
and eval_func name args =
  match name with
    | "mem" ->
        begin
          let comma = Pcre.regexp "\\s*[,;]\\s*" in
          let arg_list = Pcre.split ~rex:comma args in
            match arg_list with
                cluster :: rest ->
                  let range = (String.concat "," rest) in
                    member_of cluster (eval_string range)
              | _ -> raise (FuncErr("Invalid arguments to #mem: " ^ args))
        end
    | "boot_v" -> boothost_for_vlan (eval_string args)
    | "vlan" -> netblocks (eval_string args)
    | "bh" -> eval_string ("boot_v(vlan(" ^ args ^ "))") (* just a shorthand *)
    | "dc" -> colos (eval_string args)
    | "clusters" -> get_all_clusters (eval_string args)
    | "allclusters" -> list_all_clusters ()
    | "v_dc" | "vlans_dc" -> vlans_for_dc (eval_string args)
    | "ip" -> resolve_ips (eval_string args)
    | "v_boot" -> vlans_for_boothost (eval_string args)
    | "hosts_v" -> hosts_in_vlan (eval_string args)
    | "hosts_dc" -> hosts_in_dc (eval_string args)
    | "boot" | "boothosts" -> all_boothosts ()
    | "q" -> StrSet.singleton args
    | "has" ->
        begin
          try
            let rex = Pcre.regexp "(.+?)[,;]\\s*(.+)" in
            let res = Pcre.extract ~full_match:false ~rex args in
            let lbl = res.(0) and range = res.(1) in
              has_label lbl (eval_string range)
          with Not_found -> raise (FuncErr("Invalid arguments to #has: " ^ args))
        end
    | "count" -> StrSet.singleton (string_of_int (StrSet.cardinal (eval_string args)))
    | "lim" | "limit" ->
        begin
          try
            let comma = Pcre.regexp "^(\\d+)[,;](.+)$" in
            let arg_ary = Pcre.extract ~full_match:false ~rex:comma args in
            let n = arg_ary.(0) in
            let range = arg_ary.(1) in
            let int_n = int_of_string n in
            let res_set = eval_string range in
            let elts = ref 0 in
            let limit_set =
              StrSet.filter (fun x -> (incr elts; !elts <= int_n)) res_set in
              limit_set
          with Not_found -> raise (FuncErr("Invalid arguments to #lim: " ^ args))
        end
    | _ as x -> raise (FuncErr("Invalid function " ^ x))
and member_of cluster nodes =
  let node_elements = StrSet.elements nodes in
  let groups = expand_one_cluster cluster "KEYS" in
  let any_node_in this_set =
    let rec node_in node_lst =
      match node_lst with
        | [] -> false
        | hd::tl -> if StrSet.mem hd this_set then
            true
          else
            node_in tl in
      node_in node_elements in
  let rec g_n group_lst acc =
    match group_lst with
      | [] -> acc
      | hd::tl ->
          let group = expand_one_cluster cluster hd in
            if any_node_in group then
              g_n tl (StrSet.add hd acc)
            else
              g_n tl acc in
    g_n (StrSet.elements groups) StrSet.empty
and groups_of nodes =
  member_of "GROUPS" nodes
and resolve_ips nodes =
  StrSet.fold (
    fun node acc -> match (Tinydns.get_ip node) with
      | None -> acc
      | Some ip -> StrSet.add (Tinydns.string_of_ip ip) acc
  ) nodes StrSet.empty
and netblocks nodes =
  StrSet.fold (
    fun node acc ->
      match (Hosts_netblocks.netblock_for_host node) with
        | None ->
            (match (Tinydns.get_ip node) with
               | None -> acc
               | Some ip ->
                   match (Netblocks.find_netblock ip) with
                     | None -> acc
                     | Some (net, _) -> StrSet.add net acc)
        | Some net -> StrSet.add net acc)
    nodes StrSet.empty
and colos nodes =
  StrSet.fold (
    fun node acc ->
      match (Tinydns.get_ip node) with
        | None -> acc
        | Some ip ->
            match (Netblocks.find_netblock ip) with
                None -> acc
              | Some (_, colo) -> StrSet.add colo acc
  ) nodes StrSet.empty
and vlans_for_boothost boothosts =
  StrSet.fold (
    fun boothost acc ->
      match (Admins.netblocks_for_boothost boothost) with
        | None -> acc
        | Some blocks -> StrSet.union acc (set_of_list blocks)
  ) boothosts StrSet.empty
and all_boothosts () = set_of_list (Admins.all_boothosts())
and boothost_for_vlan vlans =
  StrSet.fold (
    fun vlan acc ->
      match (Admins.boothosts_for_netblock vlan) with
        | None -> acc
        | Some boothosts -> StrSet.union acc (set_of_list boothosts)
  ) vlans StrSet.empty
and hosts_in_vlan vlans =
  StrSet.fold (fun vlan acc -> match Hosts_netblocks.hosts_in_netblock vlan with
                   None -> acc
                 | Some lst -> StrSet.union acc (set_of_list lst))
    vlans StrSet.empty
and vlans_for_dc dcs =
  StrSet.fold (
    fun dc acc ->
      let netblocks = set_of_list (Netblocks.vlans_for_dc dc) in
        StrSet.union acc netblocks) dcs StrSet.empty
and hosts_in_dc dcs =
  StrSet.fold (
    fun dc acc ->
      let netblocks_dc = set_of_list (Netblocks.vlans_for_dc dc) in
        StrSet.union acc (hosts_in_vlan netblocks_dc)) dcs StrSet.empty
and has_label lbl elts =
  (* pick a random element - hopefully it should be only one *)
  let matches_label cluster = StrSet.subset elts (expand_one_cluster cluster lbl) in
  let cluster_lst = all_clusters.get() in
    StrSet.filter matches_label (set_of_list cluster_lst)

and list_all_clusters () =
  set_of_list (all_clusters.get())
    
let node_regex = Pcre.regexp (
  "^([-\\w.]*?)" (* prefix *)
  ^ "(\\d+)"     (* followed by the node number *)
  ^ "(\\.[-A-Za-z\\d.]*[-A-Za-z]+[-A-Za-z\\d.]*)?" (* optional domain *)
  ^ "$" (* end of string *)
)

let sort_nodes a =
  let n_to_tuple n =
    try
      let ary = Pcre.extract ~full_match:false ~rex:node_regex n in
        ary.(0), ary.(2), int_of_string(ary.(1)), n
    with Not_found -> "", "", 0, n in
  let mapped = Array.map n_to_tuple a in
    Array.fast_sort compare mapped ;
    Array.map (fun tup -> match tup with _,_,_,n -> n) mapped

(* Remove duplicates from a sorted string array *)
let unique nodes =
  let seen = ref None and
      result_lst = ref [] in
    Array.iter
      (fun x ->
         ( match !seen with
             | None -> result_lst := x :: !result_lst
             | Some node when Some x <> !seen -> result_lst := x :: !result_lst
             | _ -> (* Ignore if it's the = to the prev value *) () );
         seen := Some x) nodes;
    Array.of_list (List.rev !result_lst)

let compress_range nodes separator =
  let ignore_common_prefix num1 num2 =
    let str1 = string_of_int num1 and
        str2 = string_of_int num2 in
    let n = ref 0 and
        l1 = String.length str1 and
        l2 = String.length str2 in
      if l1 < l2 then
        str2
      else let min_len = min l1 l2 in
        while (!n < min_len && str1.[!n] = str2.[!n]) do
          incr n
        done;
        String.sub str2 !n (l2 - !n) in

  (* Converts a nodename to an array that has
     (prefix) (domain) (nodenumber as string) (nodenumber as integer) *)
  let n_to_tuple n =
    try
      let ary = Pcre.extract ~full_match:false ~rex:node_regex n in
        ary.(0), ary.(2), ary.(1), int_of_string(ary.(1))
    with Not_found -> n, "", "", -2 in

  (* the previously seen prefix, node as int, node as str, domain, count
     groups is a list of the components *)
  let prev_pre = ref "" and
      prev_inum = ref (-2) and
      prev_num = ref "" and
      prev_suf = ref "" and
      prev_n = ref "" and
      count = ref 0 and
      groups = ref [] in

  (* add another component (like node) to our list of results *)
  let add_one () =
    groups := !prev_n :: !groups in

  (* add a group (like node1-10) to our list of results *)
  let add_group () =
    let b = Buffer.create 256 in
      Buffer.add_string b !prev_pre;
      Buffer.add_string b !prev_num;
      Buffer.add_char b '-';
      Buffer.add_string b (ignore_common_prefix !prev_inum (!prev_inum + !count));
      Buffer.add_string b !prev_suf;
      groups := (Buffer.contents b)::!groups in

  (* process a node *)
  let do_node n =
    let t = n_to_tuple n in
      match t with
          pre, suf, num, inum ->
            if (pre = !prev_pre) && (suf = !prev_suf) &&
              (inum = (!prev_inum + !count + 1)) then
                incr count
            else begin
              if String.length !prev_n > 0 then
                if !count > 0 then
                  add_group ()
                else
                  add_one ();
              prev_n := n;
              prev_pre := pre;
              prev_num := num;
              prev_inum := inum;
              prev_suf := suf;
              count := 0
            end in
    match Array.length nodes with
      | 0 -> ""
      | _ ->
          Array.iter do_node (unique (sort_nodes nodes));
          (* Add the last group/node to our results *)
          if !count > 0 then
            add_group ()
          else
            add_one ();
          (* Return a comma separated list of nodes *)
          String.concat separator (List.rev !groups)

let compress_set set =
  compress_range (Array.of_list (StrSet.elements set))

(* note that most of the caches are manually implemented as hashes
   because for some reason ocaml refuses to accept memoize in the RHS of
   let rec ... and ... - probably too complex to check for types
*)
let clear_caches () =
  clear_eval_cache ();
  clear_cluster_keys_cache ();
  clear_admins_hash_cache ();
  clear_cluster_hash_cache ();
  ignore_dirs_memo.clear ();
  all_clusters.clear ();
  Admins.clear_cache ();
  Netblocks.clear_cache ();
  Tinydns.clear_cache ()

let debug_out lvl msg =
  if lvl > 0 then (eprintf "librange: %s\n"  msg; flush stderr)

let expand_range str =
  let runparam =
      try
        int_of_string (Sys.getenv "LIBRANGE_DEBUG")
      with _ -> 0 in
    let start_time = ref 0.0 in
      if runparam > 1 then
        start_time := Unix.gettimeofday();
      eval_recursion := 0 ;
      if not !do_caching then (
        debug_out runparam "Clearing caches";
        clear_caches () ;
      );
      let res = Array.of_list (StrSet.elements (eval_string str)) in
        if runparam > 1 then (
          let elapsed_time = Unix.gettimeofday() -. !start_time in
            if elapsed_time > 0.1 then (
              debug_out runparam
                (sprintf "expand_range(%s) COMPLETED in %.2f" str elapsed_time);
              if runparam > 2 then (
                Gc.print_stat stderr;
                flush stderr)));
        res

let sorted_expand_range str =
  let array = expand_range str in
    sort_nodes array

let want_warnings = Range_utils.want_warnings
let set_warning_callback = Range_utils.set_warning_callback  
