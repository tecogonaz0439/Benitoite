(component
  (core module $m (memory (export "memory") 1) (func (export "point") (param i64 i64) (result i32) unreachable))
  (core instance $i (instantiate $m))
  (type $p0 (record (field "byte-start" s64) (field "y" s64)))
  (export $p "point" (type $p0))
  (func (export "move-point") (param "p" $p) (result $p) (canon lift (core func $i "point") (memory (core memory $i "memory")))))
