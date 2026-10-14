(module
  (import "cm32p2|_ex_bnt:test/counter@0.1" "cell_new" (func $new (param i32) (result i32)))
  (import "cm32p2|_ex_bnt:test/second@0.1" "cell_new" (func $new2 (param i32) (result i32)))
  (memory (export "cm32p2_memory") 1)
  ;; ページ 0 は戻り値の領域とし、対象 k はページ k の先頭に値を置く。
  (global $live (mut i32) (i32.const 0))
  (global $free (mut i32) (i32.const 0))
  (func $alloc (param $v i64) (result i32) (local $rep i32)
    global.get $free
    if
      global.get $free local.set $rep
      local.get $rep i32.const 16 i32.shl i32.load offset=8 global.set $free
    else
      i32.const 1 memory.grow local.set $rep
    end
    local.get $rep i32.const 16 i32.shl local.get $v i64.store
    global.get $live i32.const 1 i32.add global.set $live
    local.get $rep call $new)
  (func (export "cm32p2|bnt:test/counter@0.1|[constructor]cell") (param i64) (result i32)
    local.get 0 call $alloc)
  (func (export "cm32p2|bnt:test/counter@0.1|[static]cell.make") (param i64) (result i32)
    i32.const 0 i32.const 1 i32.store8
    i32.const 4 local.get 0 call $alloc i32.store
    i32.const 0)
  (func (export "cm32p2|bnt:test/counter@0.1|[method]cell.get") (param i32) (result i64)
    local.get 0 i32.const 16 i32.shl i64.load)
  (func (export "cm32p2|bnt:test/counter@0.1|[method]cell.bump") (param i32 i64) (result i64)
    local.get 0 i32.const 16 i32.shl
    local.get 0 i32.const 16 i32.shl i64.load local.get 1 i64.add
    i64.store
    local.get 0 i32.const 16 i32.shl i64.load)
  (func (export "cm32p2|bnt:test/counter@0.1|[method]cell.pair") (param i32 i32) (result i64)
    local.get 0 i32.const 16 i32.shl i64.load
    local.get 1 i32.const 16 i32.shl i64.load i64.add)
  (func (export "cm32p2|bnt:test/counter@0.1|[method]cell.take") (param i32 i32) (result i64)
    i64.const 0)
  (func (export "cm32p2|bnt:test/counter@0.1|[method]cell.live") (param i32) (result i64)
    global.get $live i64.extend_i32_u)
  (func (export "cm32p2|bnt:test/counter@0.1|[static]cell.count") (result i64)
    global.get $live i64.extend_i32_u)
  (func (export "cm32p2|bnt:test/counter@0.1|other") (param i64) (result i64)
    local.get 0)
  (func (export "cm32p2|bnt:test/counter@0.1|cell_dtor") (param $rep i32)
    local.get $rep i32.const 16 i32.shl global.get $free i32.store offset=8
    local.get $rep global.set $free
    global.get $live i32.const 1 i32.sub global.set $live)
  (func (export "cm32p2|bnt:test/second@0.1|[constructor]cell") (result i32)
    i32.const 0 call $new2)
  (func (export "cm32p2|bnt:test/second@0.1|cell_dtor") (param i32))
  (func (export "cm32p2_realloc") (param i32 i32 i32 i32) (result i32) unreachable)
)
