(component
        (core module $m (memory (export "memory") 1)
    (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 2048)
    (global $calls (mut i32) (i32.const 0))
            (func (export "run") (param i32 i64 f32 i32) (result i32)
                global.get $calls i32.const 1 i32.add global.set $calls
                i32.const 1024 local.get 0 i32.const 1 i32.add i32.store8
                i32.const 1032 local.get 1 global.get $calls i64.extend_i32_u i64.add i64.store
                i32.const 1040 local.get 2 f32.neg f32.store
                i32.const 1044 local.get 3 i32.const 1 i32.add i32.store
                i32.const 1025 i32.const 127 i32.store8
                i32.const 1024))
        (core instance $i (instantiate $m))
        (type $t (tuple f32 char))
        (type $r0 (record (field "a" s8) (field "b" u64) (field "c" $t)))
        (export $r "record-type" (type $r0))
        (func (export "run") (param "x" $r) (result $r)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))
