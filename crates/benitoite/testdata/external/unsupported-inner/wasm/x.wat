;; 標準 Pair に対応する二要素の tuple と、利用者定義の三欄を照合する。
(component
  (core module $m
    (memory (export "memory") 1)
    (func (export "realloc") (param i32 i32 i32 i32) (result i32) unreachable)
    (func (export "f") (param i32 i32 i32) (result i32) unreachable))
  (core instance $i (instantiate $m))
  (type $t (option (list (tuple s64 string))))
  (func (export "f") (param "value" $t) (result $t)
    (canon lift (core func $i "f") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))
