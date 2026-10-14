;; 鍵を z,a,z の順で返す。先の z の値も転送の予算と検査の対象になる。
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
    (data (i32.const 100) "zaz")
    (func (export "result") (param i32 i32) (result i32)
      i32.const 0 i32.const 16 i32.store
      i32.const 4 i32.const 3 i32.store
      i32.const 16 i32.const 100 i32.store
      i32.const 20 i32.const 1 i32.store
      i32.const 24 i64.const 1 i64.store
      i32.const 32 i32.const 101 i32.store
      i32.const 36 i32.const 1 i32.store
      i32.const 40 i64.const 2 i64.store
      i32.const 48 i32.const 102 i32.store
      i32.const 52 i32.const 1 i32.store
      i32.const 56 i64.const 3 i64.store
      i32.const 0)
    (func (export "echo") (param i32 i32) (result i32) (local $n i32) (local $p i32)
      ;; 欄の値を変更して、引数を渡さず固定の答えを返す誤りも検出する。
      (block $done (loop $next
        local.get $n local.get 1 i32.ge_u br_if $done
        local.get 0 local.get $n i32.const 16 i32.mul i32.add local.set $p
        local.get $p local.get $p i64.load offset=8 i64.const 7 i64.add i64.store offset=8
        local.get $n i32.const 1 i32.add local.set $n br $next))
      i32.const 0 local.get 0 i32.store
      i32.const 4 local.get 1 i32.store i32.const 0)
    (func (export "first") (param i32 i32) (result i64)
      local.get 1 i32.eqz
      if (result i64) i64.const -1
      else local.get 0 i32.load i32.load8_u i64.extend_i32_u end)
    (func (export "bad") (result i32)
      i32.const 0 i32.const 16 i32.store
      i32.const 4 i32.const 2 i32.store
      i32.const 16 i64.const 1 i64.store
      i32.const 24 i32.const 55296 i32.store
      i32.const 32 i64.const 1 i64.store
      i32.const 40 i32.const 65 i32.store i32.const 0))
  (core instance $i (instantiate $m))
  (type $map (map string s64))
  (func (export "result") (param "v" $map) (result $map)
    (canon lift (core func $i "result") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (func (export "echo") (param "v" $map) (result $map)
    (canon lift (core func $i "echo") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (func (export "first") (param "v" $map) (result s64)
    (canon lift (core func $i "first") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (func (export "bad") (result (map s64 char))
    (canon lift (core func $i "bad") (memory (core memory $i "memory")))))
