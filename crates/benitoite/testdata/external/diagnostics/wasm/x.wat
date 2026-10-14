(component
  (core module $m
    (func (export "add") (param i64 i64) (result i64)
      local.get 0 local.get 1 i64.add))
  (core instance $i (instantiate $m))
  (func (export "add") (param "a" s64) (param "b" s64) (result s64)
    (canon lift (core func $i "add"))))
