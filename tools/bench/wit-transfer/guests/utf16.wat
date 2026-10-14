(component
  (core module $m
    (memory (export "memory") 1)
    (global $next (mut i32) (i32.const 2048))
    ;; 入力と出力を別々に確保し、大きな比較入力でも固定の一ページへ収めない。
    (func $allocate (export "realloc") (param i32 i32 i32 i32) (result i32)
      (local $ptr i32) (local $end i32) (local $pages i32)
      global.get $next local.get 2 i32.const 1 i32.sub i32.add
      i32.const 0 local.get 2 i32.sub i32.and local.tee $ptr
      local.get 3 i32.add local.tee $end
      local.get $ptr i32.lt_u if unreachable end
      local.get $end i32.const 65535 i32.add i32.const 16 i32.shr_u local.set $pages
      local.get $pages memory.size i32.gt_u if
        local.get $pages memory.size i32.sub memory.grow i32.const -1 i32.eq if unreachable end
      end
      ;; UTF-16 の変換は確保済み領域の拡張を要求するため、古い内容を保つ。
      local.get 0 if
        local.get $ptr local.get 0
        local.get 1 local.get 3 i32.lt_u
        if (result i32) local.get 1 else local.get 3 end
        memory.copy
      end
      local.get $end global.set $next local.get $ptr)
    (func $run (export "run") (param $ptr i32) (param $len i32) (result i32) (local $n i32) (local $a i32)
      local.get $len i32.eqz
      if
        i32.const 16 i32.const 0 i32.store
        i32.const 20 i32.const 0 i32.store
      else
        local.get $len i32.const 3 i32.and if unreachable end
        (block $done (loop $units
          local.get $n local.get $len i32.ge_u br_if $done
          local.get $ptr local.get $n i32.const 2 i32.mul i32.add local.set $a
          local.get $a i32.load16_u i32.const 65 i32.ne if unreachable end
          local.get $a i32.load16_u offset=2 i32.const 26085 i32.ne if unreachable end
          local.get $a i32.load16_u offset=4 i32.const 55357 i32.ne if unreachable end
          local.get $a i32.load16_u offset=6 i32.const 56832 i32.ne if unreachable end
          local.get $a i32.const 26085 i32.store16
          local.get $a i32.const 55357 i32.store16 offset=2
          local.get $a i32.const 56832 i32.store16 offset=4
          local.get $a i32.const 33 i32.store16 offset=6
          local.get $n i32.const 4 i32.add local.set $n br $units))
        i32.const 16 local.get $ptr i32.store
        i32.const 20 local.get $len i32.store
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
