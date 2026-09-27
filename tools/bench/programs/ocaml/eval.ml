type expr =
  | Lit of int
  | Add of expr * expr
  | Inc of expr
  | Scale of expr * int

let rec build_expression depth =
  if depth = 0 then Lit 1
  else
    let smaller = build_expression (depth - 1) in
    match depth mod 3 with
    | 0 -> Add (smaller, Lit depth)
    | 1 -> Inc smaller
    | _ -> Scale (smaller, 1)

let rec evaluate expression =
  match expression with
  | Lit value -> value
  | Add (left, right) -> evaluate left + evaluate right
  | Inc inner -> evaluate inner + 1
  | Scale (inner, factor) -> evaluate inner * factor

(* 式の深さは固定し、入力の回数だけ評価を繰り返す。 *)
let rec repeat_evaluate expression count total =
  if count = 0 then total
  else
    (* 同じ式の評価を最適化で一度にまとめさせない。 *)
    repeat_evaluate expression (count - 1)
      (total + evaluate (Sys.opaque_identity expression))

let () =
  let count = int_of_string Sys.argv.(1) in
  let expression = build_expression 500 in
  print_endline (string_of_int (repeat_evaluate expression count 0))
