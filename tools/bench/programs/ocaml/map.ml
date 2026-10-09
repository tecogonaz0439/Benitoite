module M = Map.Make(Int)
module S = Set.Make(Int)
let () =
  let count = int_of_string Sys.argv.(1) in
  let seed = ref 1 in
  let keys = Array.init count (fun _ ->
    seed := (!seed * 48271 + 11) mod 2147483647;
    !seed) in
  let m = ref M.empty and s = ref S.empty in
  Array.iter (fun key -> m := M.add key key !m) keys;
  Array.iter (fun key -> s := S.add key !s) keys;
  let map_found = Array.fold_left (fun acc key -> acc + if M.find_opt key !m <> None then 1 else 0) 0 keys in
  let set_found = Array.fold_left (fun acc key -> acc + if S.mem key !s then 1 else 0) 0 keys in
  Array.iteri (fun index key -> if index mod 2 = 0 then begin
    m := M.remove key !m; s := S.remove key !s
  end) keys;
  Printf.printf "%d\n%d\n%d\n%d\n" (M.cardinal !m) (S.cardinal !s) map_found set_found
