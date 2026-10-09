let () =
  let length = int_of_string Sys.argv.(1) in
  let count = int_of_string Sys.argv.(2) in
  let values = Array.init length Fun.id in
  let seed = ref 1 and total = ref 0 in
  for _ = 1 to count do
    seed := (!seed * 48271 + 11) mod 2147483647;
    total := !total + values.(!seed mod length)
  done;
  Printf.printf "%d\n" !total
