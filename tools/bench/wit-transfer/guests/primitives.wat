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
    (func (export "boolean") (param i32) (result i32) local.get 0 i32.eqz)
    (func (export "character") (param i32) (result i32) local.get 0 i32.const 1 i32.add)
    (func (export "string") (param $p i32) (param $len i32) (result i32) (local $out i32)
      i32.const 0 i32.const 0 i32.const 1 local.get $len i32.const 1 i32.add call $allocate local.set $out
      local.get $out local.get $p local.get $len memory.copy
      local.get $out local.get $len i32.add i32.const 33 i32.store8
      i32.const 16 local.get $out i32.store
      i32.const 20 local.get $len i32.const 1 i32.add i32.store i32.const 16)
    (func (export "bytes") (param $p i32) (param $len i32) (result i32) (local $n i32) (local $a i32)
      (block $done (loop $next
        local.get $n local.get $len i32.ge_u br_if $done
        local.get $p local.get $n i32.add local.tee $a
        local.get $a i32.load8_u i32.const 255 i32.xor i32.store8
        local.get $n i32.const 1 i32.add local.set $n br $next))
      i32.const 16 local.get $p i32.store
      i32.const 20 local.get $len i32.store i32.const 16))
  (core instance $i (instantiate $m))
  (func (export "boolean") (param "v" bool) (result bool) (canon lift (core func $i "boolean")))
  (func (export "character") (param "v" char) (result char) (canon lift (core func $i "character")))
  (type $bytes (list u8))
  (func (export "string") (param "v" string) (result string)
    (canon lift (core func $i "string") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (func (export "bytes") (param "v" $bytes) (result $bytes)
    (canon lift (core func $i "bytes") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (core module $wrapper
    (import "m" "bytes" (func $bytes (param i32 i32) (result i32)))
    (func (export "bytes-adapter") (param i32 i32 i32) (result i32) local.get 1 local.get 2 call $bytes))
  (core instance $w (instantiate $wrapper (with "m" (instance $i))))
  (func (export "bytes-adapter") (param "ignored" bool) (param "v" $bytes) (result $bytes)
    (canon lift (core func $w "bytes-adapter") (memory (core memory $i "memory")) (realloc (core func $i "realloc")))))
