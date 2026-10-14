(component
  (core module $m (func (export "f") (param i32) (result i32) local.get 0))
  (core instance $i (instantiate $m))
  (func (export "f") (param "a" s64) (result s64)
    (canon lift (core func $i "f"))))
