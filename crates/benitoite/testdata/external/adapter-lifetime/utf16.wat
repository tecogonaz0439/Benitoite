(component
  (core module $m
    (memory (export "memory") 1)
    (func (export "realloc") (param i32 i32 i32 i32) (result i32)
      i32.const 2048)
    (data (i32.const 128) "\e5\65\3d\d8\00\de\21\00")
    (func $run (export "run") (param $ptr i32) (param $len i32) (result i32)
      local.get $len i32.eqz
      if
        i32.const 16 i32.const 0 i32.store
        i32.const 20 i32.const 0 i32.store
      else
        local.get $len i32.const 4 i32.ne if unreachable end
        local.get $ptr i32.load16_u i32.const 65 i32.ne if unreachable end
        local.get $ptr i32.load16_u offset=2 i32.const 26085 i32.ne if unreachable end
        local.get $ptr i32.load16_u offset=4 i32.const 55357 i32.ne if unreachable end
        local.get $ptr i32.load16_u offset=6 i32.const 56832 i32.ne if unreachable end
        i32.const 16 i32.const 128 i32.store
        i32.const 20 i32.const 4 i32.store
      end
      i32.const 16)
    (func (export "run-adapter") (param i32 i32 i32) (result i32)
      local.get 1 local.get 2 call $run))
  (core instance $i (instantiate $m))
  (func (export "run") (param "text" string) (result string)
    (canon lift (core func $i "run")
      (memory (core memory $i "memory"))
      (realloc (core func $i "realloc")) string-encoding=utf16))
  (func (export "run-adapter") (param "ignored" bool) (param "text" string) (result string)
    (canon lift (core func $i "run-adapter")
      (memory (core memory $i "memory"))
      (realloc (core func $i "realloc")) string-encoding=utf16)))
