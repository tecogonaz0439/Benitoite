(component (core module $m (memory (export "memory") 1) (func (export "f") (result i32) i32.const 0 i32.const 5 i32.store8 i32.const 0))
(core instance $i (instantiate $m))
(type $result (option s64))
(func (export "f") (result $result) (canon lift (core func $i "f") (memory (core memory $i "memory")))))
