type step = { step : int -> int }
let rec repeat dictionary count value =
  if count = 0 then value
  else repeat dictionary (count - 1) (dictionary.step value)
let () =
  let dictionary = { step = (fun value -> (value * 17 + 11) mod 65521) } in
  Printf.printf "%d\n" (repeat dictionary (int_of_string Sys.argv.(1)) 1)
