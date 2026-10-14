(component (core module $m (memory (export "memory") 1)
    (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 2048)
        (func (export "run") (param $case i32) (param $value i64) (param $second i32) (result i32)
            i32.const 1024 i32.const 204 i32.const 16 memory.fill
            local.get $case i32.const 0 i32.eq if
                local.get $value i64.eqz i32.eqz if unreachable end
                local.get $second if unreachable end
                i32.const 1024 i32.const 5 i32.store8
                i32.const 1032 i32.const 13 i32.store16
                i32.const 1034 i32.const 17 i32.store8
            end
            local.get $case i32.const 1 i32.eq if
                local.get $value i64.const 4294967289 i64.ne if unreachable end
                local.get $second if unreachable end
                i32.const 1024 i32.const 1 i32.store8
                i32.const 1032 i32.const -8 i32.store
            end
            local.get $case i32.const 2 i32.eq if
                local.get $value i64.const 2147483648 i64.ne if unreachable end
                local.get $second if unreachable end
                i32.const 1024 i32.const 2 i32.store8
                i32.const 1032 f32.const -1.5 f32.store
            end
            local.get $case i32.const 3 i32.eq if
                local.get $value i64.const 4609434218613702656 i64.ne if unreachable end
                local.get $second if unreachable end
                i32.const 1024 i32.const 3 i32.store8
                i32.const 1032 f64.const -1.5 f64.store
            end
            local.get $case i32.const 4 i32.eq if
                local.get $value i64.const -9223372036854775808 i64.ne if unreachable end
                local.get $second if unreachable end
                i32.const 1024 i32.const 4 i32.store8
                i32.const 1032 i64.const -9223372036854775807 i64.store
            end
            local.get $case i32.const 5 i32.eq if
                local.get $value i64.const 9 i64.ne if unreachable end
                local.get $second i32.const 11 i32.ne if unreachable end
                i32.const 1024 i32.const 0 i32.store8
            end
            i32.const 1024))
        (core instance $i (instantiate $m)) (type $p (tuple u16 u8))
        (type $v0 (variant (case "empty") (case "signed" s32) (case "single" f32)
            (case "double" f64) (case "wide" u64) (case "pair" $p)))
        (export $v "value-type" (type $v0))
        (func (export "run") (param "x" $v) (result $v)
            (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))
