;; 独立した ABI の配置で各欄へ異なる数を足し、順序の誤りを検出する。
(component
  (core module $m
    (memory (export "memory") 1)
    (func (export "realloc") (param i32 i32 i32 i32) (result i32) i32.const 1024)
    (func (export "tuple1") (param i64) (result i64) local.get 0 i64.const 11 i64.add)
    (func (export "tuple4") (param i64 i64 i64 i64) (result i32)
      i32.const 256 local.get 0 i64.const 11 i64.add i64.store
      i32.const 264 local.get 1 i64.const 12 i64.add i64.store
      i32.const 272 local.get 2 i64.const 13 i64.add i64.store
      i32.const 280 local.get 3 i64.const 14 i64.add i64.store
      i32.const 256)
    (func (export "tuple17") (param i32) (result i32)
      i32.const 256 local.get 0 i64.load offset=0 i64.const 11 i64.add i64.store
      i32.const 264 local.get 0 i64.load offset=8 i64.const 12 i64.add i64.store
      i32.const 272 local.get 0 i64.load offset=16 i64.const 13 i64.add i64.store
      i32.const 280 local.get 0 i64.load offset=24 i64.const 14 i64.add i64.store
      i32.const 288 local.get 0 i64.load offset=32 i64.const 15 i64.add i64.store
      i32.const 296 local.get 0 i64.load offset=40 i64.const 16 i64.add i64.store
      i32.const 304 local.get 0 i64.load offset=48 i64.const 17 i64.add i64.store
      i32.const 312 local.get 0 i64.load offset=56 i64.const 18 i64.add i64.store
      i32.const 320 local.get 0 i64.load offset=64 i64.const 19 i64.add i64.store
      i32.const 328 local.get 0 i64.load offset=72 i64.const 20 i64.add i64.store
      i32.const 336 local.get 0 i64.load offset=80 i64.const 21 i64.add i64.store
      i32.const 344 local.get 0 i64.load offset=88 i64.const 22 i64.add i64.store
      i32.const 352 local.get 0 i64.load offset=96 i64.const 23 i64.add i64.store
      i32.const 360 local.get 0 i64.load offset=104 i64.const 24 i64.add i64.store
      i32.const 368 local.get 0 i64.load offset=112 i64.const 25 i64.add i64.store
      i32.const 376 local.get 0 i64.load offset=120 i64.const 26 i64.add i64.store
      i32.const 384 local.get 0 i64.load offset=128 i64.const 27 i64.add i64.store
      i32.const 256)
  )
  (core instance $i (instantiate $m))
  (type $t1 (tuple s64))
  (func (export "tuple1") (param "v" $t1) (result $t1)
    (canon lift (core func $i "tuple1") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (type $t4 (tuple s64 s64 s64 s64))
  (func (export "tuple4") (param "v" $t4) (result $t4)
    (canon lift (core func $i "tuple4") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
  (type $t17 (tuple s64 s64 s64 s64 s64 s64 s64 s64 s64 s64 s64 s64 s64 s64 s64 s64 s64))
  (func (export "tuple17") (param "v" $t17) (result $t17)
    (canon lift (core func $i "tuple17") (memory (core memory $i "memory")) (realloc (core func $i "realloc"))))
)
