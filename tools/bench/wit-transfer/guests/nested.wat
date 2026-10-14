(component
  (core module $m (memory (export "memory") 1)
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
    (func (export "run") (param $p i32) (param $len i32) (result i32)
      (local $i i32) (local $j i32) (local $child i32) (local $count i32) (local $a i32)
      (block $outer-done (loop $outer
        local.get $i local.get $len i32.ge_u br_if $outer-done
        local.get $p local.get $i i32.const 8 i32.mul i32.add local.tee $a i32.load local.set $child
        local.get $a i32.load offset=4 local.set $count
        i32.const 0 local.set $j
        (block $inner-done (loop $inner
          local.get $j local.get $count i32.ge_u br_if $inner-done
          local.get $child local.get $j i32.const 2 i32.mul i32.add local.tee $a
          local.get $a i32.load16_u i32.const 1 i32.add i32.store16
          local.get $j i32.const 1 i32.add local.set $j br $inner))
        local.get $i i32.const 1 i32.add local.set $i br $outer))
      i32.const 16 local.get $p i32.store
      i32.const 20 local.get $len i32.store i32.const 16))
  (core instance $i (instantiate $m))
  (type $inner (list u16)) (type $outer (list $inner))
  (func (export "run") (param "xs" $outer) (result $outer)
    (canon lift (core func $i "run") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))
