;; ゲストは受け取った各要素を変更する。空のリストではメモリを読まず、戻り値の記述だけを作る。
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
    (func (export "flip-s8") (param $ptr i32) (param $len i32) (result i32)
      (local $pos i32) (local $addr i32)
      (block $end (loop $next
        local.get $pos local.get $len i32.ge_u br_if $end
        local.get $ptr local.get $pos i32.const 1 i32.mul i32.add local.tee $addr
        local.get $addr i32.load8_s i32.const 1 i32.xor i32.store8
        local.get $pos i32.const 1 i32.add local.set $pos br $next))
      i32.const 0 local.get $ptr i32.store
      i32.const 4 local.get $len i32.store i32.const 0)
    (func (export "flip-s16") (param $ptr i32) (param $len i32) (result i32)
      (local $pos i32) (local $addr i32)
      (block $end (loop $next
        local.get $pos local.get $len i32.ge_u br_if $end
        local.get $ptr local.get $pos i32.const 2 i32.mul i32.add local.tee $addr
        local.get $addr i32.load16_s i32.const 1 i32.xor i32.store16
        local.get $pos i32.const 1 i32.add local.set $pos br $next))
      i32.const 0 local.get $ptr i32.store
      i32.const 4 local.get $len i32.store i32.const 0)
    (func (export "flip-s32") (param $ptr i32) (param $len i32) (result i32)
      (local $pos i32) (local $addr i32)
      (block $end (loop $next
        local.get $pos local.get $len i32.ge_u br_if $end
        local.get $ptr local.get $pos i32.const 4 i32.mul i32.add local.tee $addr
        local.get $addr i32.load i32.const 1 i32.xor i32.store
        local.get $pos i32.const 1 i32.add local.set $pos br $next))
      i32.const 0 local.get $ptr i32.store
      i32.const 4 local.get $len i32.store i32.const 0)
    (func (export "flip-u16") (param $ptr i32) (param $len i32) (result i32)
      (local $pos i32) (local $addr i32)
      (block $end (loop $next
        local.get $pos local.get $len i32.ge_u br_if $end
        local.get $ptr local.get $pos i32.const 2 i32.mul i32.add local.tee $addr
        local.get $addr i32.load16_u i32.const 1 i32.xor i32.store16
        local.get $pos i32.const 1 i32.add local.set $pos br $next))
      i32.const 0 local.get $ptr i32.store
      i32.const 4 local.get $len i32.store i32.const 0)
    (func (export "flip-u32") (param $ptr i32) (param $len i32) (result i32)
      (local $pos i32) (local $addr i32)
      (block $end (loop $next
        local.get $pos local.get $len i32.ge_u br_if $end
        local.get $ptr local.get $pos i32.const 4 i32.mul i32.add local.tee $addr
        local.get $addr i32.load i32.const 1 i32.xor i32.store
        local.get $pos i32.const 1 i32.add local.set $pos br $next))
      i32.const 0 local.get $ptr i32.store
      i32.const 4 local.get $len i32.store i32.const 0)
    (func (export "flip-u64") (param $ptr i32) (param $len i32) (result i32)
      (local $pos i32) (local $addr i32)
      (block $end (loop $next
        local.get $pos local.get $len i32.ge_u br_if $end
        local.get $ptr local.get $pos i32.const 8 i32.mul i32.add local.tee $addr
        local.get $addr i64.load i64.const 1 i64.xor i64.store
        local.get $pos i32.const 1 i32.add local.set $pos br $next))
      i32.const 0 local.get $ptr i32.store
      i32.const 4 local.get $len i32.store i32.const 0)
    (func (export "negate-f32") (param $ptr i32) (param $len i32) (result i32)
      (local $pos i32) (local $addr i32)
      (block $end (loop $next
        local.get $pos local.get $len i32.ge_u br_if $end
        local.get $ptr local.get $pos i32.const 4 i32.mul i32.add local.tee $addr
        local.get $addr f32.load f32.neg f32.store
        local.get $pos i32.const 1 i32.add local.set $pos br $next))
      i32.const 0 local.get $ptr i32.store
      i32.const 4 local.get $len i32.store i32.const 0)
  )
  (core instance $i (instantiate $m))
  (type $s8 (list s8))
  (func (export "flip-s8") (param "v" $s8) (result $s8)
    (canon lift (core func $i "flip-s8") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (type $s16 (list s16))
  (func (export "flip-s16") (param "v" $s16) (result $s16)
    (canon lift (core func $i "flip-s16") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (type $s32 (list s32))
  (func (export "flip-s32") (param "v" $s32) (result $s32)
    (canon lift (core func $i "flip-s32") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (type $u16 (list u16))
  (func (export "flip-u16") (param "v" $u16) (result $u16)
    (canon lift (core func $i "flip-u16") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (type $u32 (list u32))
  (func (export "flip-u32") (param "v" $u32) (result $u32)
    (canon lift (core func $i "flip-u32") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (type $u64 (list u64))
  (func (export "flip-u64") (param "v" $u64) (result $u64)
    (canon lift (core func $i "flip-u64") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (type $f32 (list f32))
  (func (export "negate-f32") (param "v" $f32) (result $f32)
    (canon lift (core func $i "negate-f32") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
)
