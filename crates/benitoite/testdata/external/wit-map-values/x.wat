;; 鍵を z,a,z の順で返す。先の z の値も転送の予算と検査の対象になる。
(component
  (core module $m
    (memory (export "memory") 1)
    (global $at (mut i32) (i32.const 1024))
    (data (i32.const 100) "zaz")
    (func (export "realloc") (param i32 i32 i32 i32) (result i32)
      (local $p i32)
      global.get $at local.get 2 i32.const 1 i32.sub i32.add
      i32.const 0 local.get 2 i32.sub i32.and local.tee $p
      local.get 3 i32.add global.set $at local.get $p)
    (func (export "result") (param i32 i32) (result i32)
      i32.const 0 i32.const 16 i32.store
      i32.const 4 i32.const 3 i32.store
      i32.const 16 i32.const 100 i32.store
      i32.const 20 i32.const 1 i32.store
      i32.const 24 i64.const 1 i64.store
      i32.const 32 i32.const 101 i32.store
      i32.const 36 i32.const 1 i32.store
      i32.const 40 i64.const 2 i64.store
      i32.const 48 i32.const 102 i32.store
      i32.const 52 i32.const 1 i32.store
      i32.const 56 i64.const 3 i64.store
      i32.const 0)
    (func (export "echo") (param i32 i32) (result i32)
      i32.const 0 local.get 0 i32.store
      i32.const 4 local.get 1 i32.store i32.const 0)
    (func (export "first") (param i32 i32) (result i64)
      local.get 1 i32.eqz
      if (result i64) i64.const -1
      else local.get 0 i32.load i32.load8_u i64.extend_i32_u end)
    (func (export "bad") (result i32)
      i32.const 0 i32.const 16 i32.store
      i32.const 4 i32.const 2 i32.store
      i32.const 16 i64.const 1 i64.store
      i32.const 24 i32.const 55296 i32.store
      i32.const 32 i64.const 1 i64.store
      i32.const 40 i32.const 65 i32.store i32.const 0))
  (core instance $i (instantiate $m))
  (type $map (map string s64))
  (func (export "result") (param "v" $map) (result $map)
    (canon lift (core func $i "result") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (func (export "echo") (param "v" $map) (result $map)
    (canon lift (core func $i "echo") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (func (export "first") (param "v" $map) (result s64)
    (canon lift (core func $i "first") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (func (export "bad") (result (map s64 char))
    (canon lift (core func $i "bad") (memory (core memory $i "memory")))))
