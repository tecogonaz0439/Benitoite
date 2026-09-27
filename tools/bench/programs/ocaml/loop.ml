let rec count_up current finish total =
  if current < finish then
    count_up (current + 1) finish (total + current)
  else
    total

let () =
  let count = int_of_string Sys.argv.(1) in
  print_endline (string_of_int (count_up 0 count 0))
