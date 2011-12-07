
type  ('a, 'b) memo = { get : ('a -> 'b) ; clear : (unit -> unit) }

let memoize f =
  let cache = Hashtbl.create 19 in
  let clear_cache () = Hashtbl.clear cache in
  let f' n =
    try Hashtbl.find cache n
    with Not_found ->
      let fn = (f n) in
	Hashtbl.add cache n fn;
	fn in
    { get = f' ; clear = clear_cache }
