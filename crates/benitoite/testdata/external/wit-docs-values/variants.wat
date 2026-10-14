;; tuple の欄を別々に変更し、構成子の分配とは独立した期待値を作る。
(component
  (core module $m
    (memory (export "memory") 1)
    (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 1024)
    (func (export "fields") (param i32 i64 i64) (result i32)
      i32.const 0 local.get 0 i32.store8
      i32.const 8 local.get 1 i64.const 11 i64.add i64.store
      i32.const 16 local.get 2 i64.const 22 i64.add i64.store
      i32.const 0)
    (func (export "single") (param i32 i64) (result i32)
      i32.const 0 local.get 0 i32.store8
      i32.const 8 local.get 1 i64.const 12 i64.add i64.store
      i32.const 0))
  (core instance $i (instantiate $m))
  (type $t0 (variant (case "value" (tuple s64 s64)) (case "empty")))
  (export $t "fields-type" (type $t0))
  (type $s0 (variant (case "value" s64)))
  (export $s "single-type" (type $s0))
  (func (export "fields") (param "v" $t) (result $t)
    (canon lift (core func $i "fields") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (func (export "single") (param "v" $s) (result $s)
    (canon lift (core func $i "single") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))
