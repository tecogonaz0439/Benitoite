let rec print_lines current finish =
  if current < finish then (
    print_endline ("line " ^ string_of_int current);
    print_lines (current + 1) finish)

let () =
  let count_text = Sys.argv.(1) in
  let count = int_of_string count_text in
  print_lines 0 count;
  print_endline ("done " ^ count_text)
