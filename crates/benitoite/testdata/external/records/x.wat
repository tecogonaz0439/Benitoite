;; 呼び出しごとのメモリに、判別子と平らなペイロードを分けて書く。
(component
  (core module $m
    (memory (export "memory") 1)
    (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 1024)
    (func (export "point") (param i64 i64) (result i32)
      i32.const 0 local.get 0 i64.const 1 i64.add i64.store
      i32.const 8 local.get 1 i64.const 2 i64.add i64.store i32.const 0)
    (func (export "shape") (param i32 i64 i64) (result i32)
      i32.const 0 local.get 0 i32.store8
      i32.const 8 local.get 1 i64.store
      i32.const 16 local.get 2 i64.store i32.const 0)
    (func (export "color") (param i32) (result i32)
      local.get 0 i32.const 1 i32.add i32.const 3 i32.rem_u)
    (func (export "ordering") (param i32) (result i32)
      local.get 0 i32.const 1 i32.add i32.const 3 i32.rem_u)
    (func (export "plain") (param i32) (result i32)
      local.get 0 i32.const 1 i32.xor)
    (func (export "result") (param i32 i64 i64) (result i32)
      i32.const 0 local.get 0 i32.store8
      local.get 0 if
        i32.const 8 local.get 1 i32.wrap_i64 i32.store8
        i32.const 16 local.get 2 i64.store
      else
        i32.const 8 local.get 1 i64.store
      end i32.const 0))
  (core instance $i (instantiate $m))
  (type $p0 (record (field "byte-start" s64) (field "y" s64)))
  (export $p "point" (type $p0))
  (type $s (variant (case "circle" s64) (case "rect" $p) (case "empty")))
  (type $c (enum "red" "green" "blue-ish"))
  (type $ordering (enum "less" "equal" "greater"))
  (type $plain (variant (case "on" ) (case "off")))
  (type $e (variant (case "not-found" s64) (case "empty")))
  (type $r (result s64 (error $e)))
  (type $o (option $p))
  (func (export "move-point") (param "p" $p) (result $p)
    (canon lift (core func $i "point") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (func $shape (param "s" $s) (result $s)
    (canon lift (core func $i "shape") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (func $color (param "c" $c) (result $c) (canon lift (core func $i "color")))
  (func $ordering-f (param "o" $ordering) (result $ordering) (canon lift (core func $i "ordering")))
  (func $plain-f (param "v" $plain) (result $plain) (canon lift (core func $i "plain")))
  (func $result (param "r" $r) (result $r)
    (canon lift (core func $i "result") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (func $option (param "o" $o) (result $o)
    (canon lift (core func $i "shape") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (instance $api
    (export "point" (type $p))
    (export "shape" (type $s))
    (export "color" (type $c))
    (export "plain" (type $plain))
    (export "ordering" (type $ordering))
    (export "my-error" (type $e))
    (export "echo-shape" (func $shape))
    (export "next-color" (func $color))
    (export "flip-plain" (func $plain-f))
    (export "echo-ordering" (func $ordering-f))
    (export "result" (func $result))
    (export "option" (func $option)))
  (export "bnt:test/shapes" (instance $api)))
