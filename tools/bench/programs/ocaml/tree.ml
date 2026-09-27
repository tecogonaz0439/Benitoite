type tree =
  | Leaf of int
  | Branch of tree * tree

let rec build_tree depth =
  if depth = 0 then Leaf 1
  else Branch (build_tree (depth - 1), build_tree (depth - 1))

let rec sum_leaves tree =
  match tree with
  | Leaf value -> value
  | Branch (left, right) -> sum_leaves left + sum_leaves right

let () =
  let depth = int_of_string Sys.argv.(1) in
  print_endline (string_of_int (sum_leaves (build_tree depth)))
