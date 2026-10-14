(component (core module $m (memory (export "memory") 1) (data (i32.const 16) "\ff\fe") (func (export "f") (result i32) i32.const 0 i32.const 16 i32.store i32.const 4 i32.const 2 i32.store i32.const 0))
(core instance $i (instantiate $m))

(func (export "f") (result string) (canon lift (core func $i "f") (memory (core memory $i "memory")))))
