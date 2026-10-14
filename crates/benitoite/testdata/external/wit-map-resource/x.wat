;; 三つの所有対象を同じ鍵を含む map で返し、解放を別の呼び出しで観察する。
(component
  (core module $counter
    (global $drops (mut i64) (i64.const 0))
    (func (export "drop") (param i32)
      global.get $drops i64.const 1 i64.add global.set $drops)
    (func (export "read") (param i32 i32) (result i64) global.get $drops)
    (memory (export "memory") 1)
    (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 1024))
  (core instance $counter (instantiate $counter))
  (type $r (resource (rep i32) (dtor (core func $counter "drop"))))
  (export $cell "cell" (type $r))
  (core func $new (canon resource.new $r))
  (core module $maker
    (import "host" "new" (func $new (param i32) (result i32)))
    (import "host" "memory" (memory 1))
    (func (export "make") (result i32)
      i32.const 0 i32.const 16 i32.store
      i32.const 4 i32.const 3 i32.store
      i32.const 16 i64.const 2 i64.store
      i32.const 24 i32.const 10 call $new i32.store
      i32.const 32 i64.const 1 i64.store
      i32.const 40 i32.const 20 call $new i32.store
      i32.const 48 i64.const 2 i64.store
      i32.const 56 i32.const 30 call $new i32.store i32.const 0))
  (alias core export $counter "memory" (core memory $memory))
  (core instance $host
    (export "new" (func $new))
    (export "memory" (memory $memory)))
  (core instance $maker (instantiate $maker (with "host" (instance $host))))
  (func (export "make") (result (map s64 (own $cell)))
    (canon lift (core func $maker "make") (memory (core memory $counter "memory"))))
  (func (export "read") (param "v" (map s64 (borrow $cell))) (result s64)
    (canon lift (core func $counter "read") (memory (core memory $counter "memory")) (realloc (core func $counter "realloc")))))
