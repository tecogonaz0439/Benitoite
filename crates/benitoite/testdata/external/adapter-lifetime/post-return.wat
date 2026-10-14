(component
  (core module $m
    (memory (export "memory") 1)
    (global $calls (mut i32) (i32.const 0))
    (global $posts (mut i32) (i32.const 0))
    (func (export "realloc") (param i32 i32 i32 i32) (result i32)
      i32.const 2048)
    (func $run (export "run") (result i32)
      global.get $calls i32.const 1 i32.add global.set $calls
      i32.const 128 global.get $calls i32.const 48 i32.add i32.store8
      i32.const 129 i32.const 33 i32.store8
      i32.const 16 i32.const 128 i32.store
      i32.const 20 i32.const 2 i32.store
      i32.const 16)
    (func (export "run-adapter") (param i32) (result i32) call $run)
    (func (export "post") (param i32)
      local.get 0 i32.const 16 i32.ne if unreachable end
      global.get $posts if unreachable end
      i32.const 128 i32.load8_u i32.const 49 i32.ne if unreachable end
      i32.const 128 i32.const 255 i32.const 2 memory.fill
      i32.const 16 i32.const 255 i32.const 8 memory.fill
      i32.const 1 global.set $posts))
  (core instance $i (instantiate $m))
  (func (export "run") (result string)
    (canon lift (core func $i "run")
      (memory (core memory $i "memory"))
      (realloc (core func $i "realloc"))
      (post-return (core func $i "post"))))
  (func (export "run-adapter") (param "ignored" bool) (result string)
    (canon lift (core func $i "run-adapter")
      (memory (core memory $i "memory"))
      (realloc (core func $i "realloc"))
      (post-return (core func $i "post")))))
