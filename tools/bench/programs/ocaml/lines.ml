let () =
  let channel = open_in_bin Sys.argv.(1) in
  let text = really_input_string channel (in_channel_length channel) in
  close_in channel;
  let lines = Stdlib.String.split_on_char '\n' text in
  let line_count =
    if Stdlib.String.length text = 0 then 0
    else
      let count = Stdlib.List.length lines in
      if Stdlib.String.get text (Stdlib.String.length text - 1) = '\n' then count - 1
      else count
  in
  print_endline (string_of_int line_count)
