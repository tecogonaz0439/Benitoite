(component
  (core module $m
    (memory (export "memory") 1)
    (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 1024)
    (func (export "f") (param i32) (result i32) local.get 0 i32.const 7 i32.add)
    (func (export "typed") (result i64) i64.const 7)
    (func (export "void"))
    (func (export "tail") (param i64 i32 i32 f64) (result i32)
      i32.const 0 local.get 1 i32.const 8 i32.add i32.store
      i32.const 4 local.get 2 i32.const 1 i32.sub i32.store i32.const 0))
  (core instance $i (instantiate $m))
  (type $ints (list s64)) (type $floats (list f64))
  (func (export "f") (param "x" u32) (result u32) (canon lift (core func $i "f")))
  (func (export "typed") (result s64) (canon lift (core func $i "typed")))
  (func (export "void") (canon lift (core func $i "void")))
  (func (export "tail-ints") (param "n" s64) (param "xs" $ints) (param "extra" f64) (result $ints)
    (canon lift (core func $i "tail") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (func (export "tail-floats") (param "n" s64) (param "xs" $floats) (param "extra" f64) (result $floats)
    (canon lift (core func $i "tail") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))
