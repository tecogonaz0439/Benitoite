let rec fibonacci n =
  if n < 2 then n else fibonacci (n - 1) + fibonacci (n - 2)

let () =
  let count = int_of_string Sys.argv.(1) in
  print_endline (string_of_int (fibonacci count))
