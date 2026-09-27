let () =
  let count = int_of_string Sys.argv.(1) in
  let values = Stdlib.List.init count (fun value -> value) in
  let mapped = Stdlib.List.map (fun value -> value * 3) values in
  let filtered = Stdlib.List.filter (fun value -> value mod 2 = 0) mapped in
  let total =
    Stdlib.List.fold_left (fun accumulator value -> accumulator + value) 0 filtered
  in
  print_endline (string_of_int total)
