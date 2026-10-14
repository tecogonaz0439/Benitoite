(component (core module $m (memory (export "memory") 1) (func (export "f") (result i32) i32.const 4 i32.const 2147483647 i32.store i32.const 0))
(core instance $i (instantiate $m))

(func (export "f") (result string) (canon lift (core func $i "f") (memory (core memory $i "memory")))))
