(component (core module $m (memory (export "memory") 10)
(func (export "f") (result i32)
 i32.const 0 i32.const 1024 i32.store i32.const 4 i32.const 2 i32.store
 i32.const 1024 i32.const 2048 i32.store i32.const 1028 i32.const 600000 i32.store
 i32.const 1032 i32.const 2048 i32.store i32.const 1036 i32.const 600000 i32.store
 i32.const 0))
(core instance $i (instantiate $m))
(type $result (list (list u8)))
(func (export "f") (result $result) (canon lift (core func $i "f") (memory (core memory $i "memory")))))
