(component
  (core module $m
    (func (export "add") (param i64 i64) (result i64)
      local.get 0 local.get 1 i64.add)
    (func (export "top") (result i64) i64.const 7))
  (core instance $i (instantiate $m))
  (func $add (param "byte-start" s64) (param "b" s64) (result s64)
    (canon lift (core func $i "add")))
  (func $top (result s64) (canon lift (core func $i "top")))
  (instance $api (export "add" (func $add)))
  (export "bnt:test/api@1.2.0" (instance $api))
  (export "top" (func $top)))
