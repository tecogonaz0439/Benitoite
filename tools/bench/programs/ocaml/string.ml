let () =
  let count = int_of_string Sys.argv.(1) in
  let buffer = Buffer.create (count * 2 + 10) in
  Buffer.add_string buffer "start,";
  for _index = 1 to count do
    Buffer.add_string buffer "x,"
  done;
  Buffer.add_string buffer "end";
  let text = Buffer.contents buffer in
  let fields = Stdlib.String.split_on_char ',' text in
  print_endline (string_of_int (Stdlib.List.length fields))
