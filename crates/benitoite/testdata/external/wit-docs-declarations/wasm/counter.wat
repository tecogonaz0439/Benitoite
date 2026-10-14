(component
  (core module $main (;0;)
    (type (;0;) (func (param i32) (result i32)))
    (type (;1;) (func (param i64) (result i32)))
    (type (;2;) (func (param i32) (result i64)))
    (type (;3;) (func (param i32 i64) (result i64)))
    (type (;4;) (func (param i32 i32) (result i64)))
    (type (;5;) (func (result i64)))
    (type (;6;) (func (param i64) (result i64)))
    (type (;7;) (func (param i32)))
    (type (;8;) (func (result i32)))
    (type (;9;) (func (param i32 i32 i32 i32) (result i32)))
    (import "cm32p2|_ex_bnt:test/counter@0.1" "cell_new" (func $new (;0;) (type 0) (param i32) (result i32)))
    (import "cm32p2|_ex_bnt:test/second@0.1" "cell_new" (func $new2 (;1;) (type 0) (param i32) (result i32)))
    (memory (;0;) 1)
    (global $live (;0;) (mut i32) i32.const 0)
    (global $free (;1;) (mut i32) i32.const 0)
    (export "cm32p2_memory" (memory 0))
    (export "cm32p2|bnt:test/counter@0.1|[constructor]cell" (func 3))
    (export "cm32p2|bnt:test/counter@0.1|[static]cell.make" (func 4))
    (export "cm32p2|bnt:test/counter@0.1|[method]cell.get" (func 5))
    (export "cm32p2|bnt:test/counter@0.1|[method]cell.bump" (func 6))
    (export "cm32p2|bnt:test/counter@0.1|[method]cell.pair" (func 7))
    (export "cm32p2|bnt:test/counter@0.1|[method]cell.take" (func 8))
    (export "cm32p2|bnt:test/counter@0.1|[method]cell.live" (func 9))
    (export "cm32p2|bnt:test/counter@0.1|[static]cell.count" (func 10))
    (export "cm32p2|bnt:test/counter@0.1|other" (func 11))
    (export "cm32p2|bnt:test/counter@0.1|cell_dtor" (func 12))
    (export "cm32p2|bnt:test/second@0.1|[constructor]cell" (func 13))
    (export "cm32p2|bnt:test/second@0.1|cell_dtor" (func 14))
    (export "cm32p2_realloc" (func 15))
    (func $alloc (;2;) (type 1) (param $v i64) (result i32)
      (local $rep i32)
      global.get $free
      if ;; label = @1
        global.get $free
        local.set $rep
        local.get $rep
        i32.const 16
        i32.shl
        i32.load offset=8
        global.set $free
      else
        i32.const 1
        memory.grow
        local.set $rep
      end
      local.get $rep
      i32.const 16
      i32.shl
      local.get $v
      i64.store
      global.get $live
      i32.const 1
      i32.add
      global.set $live
      local.get $rep
      call $new
    )
    (func (;3;) (type 1) (param i64) (result i32)
      local.get 0
      call $alloc
    )
    (func (;4;) (type 1) (param i64) (result i32)
      i32.const 0
      i32.const 1
      i32.store8
      i32.const 4
      local.get 0
      call $alloc
      i32.store
      i32.const 0
    )
    (func (;5;) (type 2) (param i32) (result i64)
      local.get 0
      i32.const 16
      i32.shl
      i64.load
    )
    (func (;6;) (type 3) (param i32 i64) (result i64)
      local.get 0
      i32.const 16
      i32.shl
      local.get 0
      i32.const 16
      i32.shl
      i64.load
      local.get 1
      i64.add
      i64.store
      local.get 0
      i32.const 16
      i32.shl
      i64.load
    )
    (func (;7;) (type 4) (param i32 i32) (result i64)
      local.get 0
      i32.const 16
      i32.shl
      i64.load
      local.get 1
      i32.const 16
      i32.shl
      i64.load
      i64.add
    )
    (func (;8;) (type 4) (param i32 i32) (result i64)
      i64.const 0
    )
    (func (;9;) (type 2) (param i32) (result i64)
      global.get $live
      i64.extend_i32_u
    )
    (func (;10;) (type 5) (result i64)
      global.get $live
      i64.extend_i32_u
    )
    (func (;11;) (type 6) (param i64) (result i64)
      local.get 0
    )
    (func (;12;) (type 7) (param $rep i32)
      local.get $rep
      i32.const 16
      i32.shl
      global.get $free
      i32.store offset=8
      local.get $rep
      global.set $free
      global.get $live
      i32.const 1
      i32.sub
      global.set $live
    )
    (func (;13;) (type 8) (result i32)
      i32.const 0
      call $new2
    )
    (func (;14;) (type 7) (param i32))
    (func (;15;) (type 9) (param i32 i32 i32 i32) (result i32)
      unreachable
    )
    (@producers
      (processed-by "wit-component" "0.261.0")
    )
  )
  (core module $wit-component-shim-module (;1;)
    (type (;0;) (func (param i32)))
    (table (;0;) 2 2 funcref)
    (export "0" (func $dtor-cell))
    (export "1" (func $"#func1 dtor-cell"))
    (export "$imports" (table 0))
    (func $dtor-cell (;0;) (type 0) (param i32)
      local.get 0
      i32.const 0
      call_indirect (type 0)
    )
    (func $"#func1 dtor-cell" (@name "dtor-cell") (;1;) (type 0) (param i32)
      local.get 0
      i32.const 1
      call_indirect (type 0)
    )
    (@producers
      (processed-by "wit-component" "0.261.0")
    )
  )
  (core instance $wit-component-shim-instance (;0;) (instantiate $wit-component-shim-module))
  (alias core export $wit-component-shim-instance "0" (core func $dtor-cell (;0;)))
  (type $cell (;0;) (resource (rep i32) (dtor $dtor-cell)))
  (alias core export $wit-component-shim-instance "1" (core func $"#core-func1 dtor-cell" (@name "dtor-cell") (;1;)))
  (type $"#type1 cell" (@name "cell") (;1;) (resource (rep i32) (dtor $"#core-func1 dtor-cell")))
  (core func $resource.new (;2;) (canon resource.new $cell))
  (core instance $cm32p2|_ex_bnt:test/counter@0.1 (;1;)
    (export "cell_new" (func $resource.new))
  )
  (core func $"#core-func3 resource.new" (@name "resource.new") (;3;) (canon resource.new $"#type1 cell"))
  (core instance $cm32p2|_ex_bnt:test/second@0.1 (;2;)
    (export "cell_new" (func $"#core-func3 resource.new"))
  )
  (core instance $main (;3;) (instantiate $main
      (with "cm32p2|_ex_bnt:test/counter@0.1" (instance $cm32p2|_ex_bnt:test/counter@0.1))
      (with "cm32p2|_ex_bnt:test/second@0.1" (instance $cm32p2|_ex_bnt:test/second@0.1))
    )
  )
  (alias core export $main "cm32p2_memory" (core memory $memory (;0;)))
  (core module $wit-component-fixup (;2;)
    (type (;0;) (func (param i32)))
    (import "actual" "0" (func $0 (;0;) (type 0) (param i32)))
    (import "actual" "1" (func $1 (;1;) (type 0) (param i32)))
    (import "shim" "$imports" (table (;0;) 2 2 funcref))
    (elem (;0;) (i32.const 0) func $0 $1)
    (@producers
      (processed-by "wit-component" "0.261.0")
    )
  )
  (alias core export $main "cm32p2|bnt:test/counter@0.1|cell_dtor" (core func $cm32p2|bnt:test/counter@0.1|cell_dtor (;4;)))
  (alias core export $main "cm32p2|bnt:test/second@0.1|cell_dtor" (core func $cm32p2|bnt:test/second@0.1|cell_dtor (;5;)))
  (core instance $actual (;4;)
    (export "0" (func $cm32p2|bnt:test/counter@0.1|cell_dtor))
    (export "1" (func $cm32p2|bnt:test/second@0.1|cell_dtor))
  )
  (core instance $fixup (;5;) (instantiate $wit-component-fixup
      (with "actual" (instance $actual))
      (with "shim" (instance $wit-component-shim-instance))
    )
  )
  (type (;2;) (own $cell))
  (type (;3;) (func (param "start" s64) (result 2)))
  (alias core export $main "cm32p2|bnt:test/counter@0.1|[constructor]cell" (core func $"cm32p2|bnt:test/counter@0.1|[constructor]cell" (;6;)))
  (func $"[constructor]cell" (;0;) (type 3) (canon lift (core func $"cm32p2|bnt:test/counter@0.1|[constructor]cell")))
  (type (;4;) (func (result s64)))
  (alias core export $main "cm32p2|bnt:test/counter@0.1|[static]cell.count" (core func $"cm32p2|bnt:test/counter@0.1|[static]cell.count" (;7;)))
  (func $"[static]cell.count" (;1;) (type 4) (canon lift (core func $"cm32p2|bnt:test/counter@0.1|[static]cell.count")))
  (type (;5;) (option 2))
  (type (;6;) (func (param "start" s64) (result 5)))
  (alias core export $main "cm32p2|bnt:test/counter@0.1|[static]cell.make" (core func $"cm32p2|bnt:test/counter@0.1|[static]cell.make" (;8;)))
  (func $"[static]cell.make" (;2;) (type 6) (canon lift (core func $"cm32p2|bnt:test/counter@0.1|[static]cell.make") (memory $memory)))
  (type (;7;) (borrow $cell))
  (type (;8;) (func (param "self" 7) (result s64)))
  (alias core export $main "cm32p2|bnt:test/counter@0.1|[method]cell.get" (core func $"cm32p2|bnt:test/counter@0.1|[method]cell.get" (;9;)))
  (func $"[method]cell.get" (;3;) (type 8) (canon lift (core func $"cm32p2|bnt:test/counter@0.1|[method]cell.get")))
  (type (;9;) (func (param "self" 7) (param "by" s64) (result s64)))
  (alias core export $main "cm32p2|bnt:test/counter@0.1|[method]cell.bump" (core func $"cm32p2|bnt:test/counter@0.1|[method]cell.bump" (;10;)))
  (func $"[method]cell.bump" (;4;) (type 9) (canon lift (core func $"cm32p2|bnt:test/counter@0.1|[method]cell.bump")))
  (type (;10;) (func (param "self" 7) (param "other" 7) (result s64)))
  (alias core export $main "cm32p2|bnt:test/counter@0.1|[method]cell.pair" (core func $"cm32p2|bnt:test/counter@0.1|[method]cell.pair" (;11;)))
  (func $"[method]cell.pair" (;5;) (type 10) (canon lift (core func $"cm32p2|bnt:test/counter@0.1|[method]cell.pair")))
  (type (;11;) (func (param "self" 7) (param "other" 2) (result s64)))
  (alias core export $main "cm32p2|bnt:test/counter@0.1|[method]cell.take" (core func $"cm32p2|bnt:test/counter@0.1|[method]cell.take" (;12;)))
  (func $"[method]cell.take" (;6;) (type 11) (canon lift (core func $"cm32p2|bnt:test/counter@0.1|[method]cell.take")))
  (alias core export $main "cm32p2|bnt:test/counter@0.1|[method]cell.live" (core func $"cm32p2|bnt:test/counter@0.1|[method]cell.live" (;13;)))
  (func $"[method]cell.live" (;7;) (type 8) (canon lift (core func $"cm32p2|bnt:test/counter@0.1|[method]cell.live")))
  (type (;12;) (func (param "x" s64) (result s64)))
  (alias core export $main "cm32p2|bnt:test/counter@0.1|other" (core func $cm32p2|bnt:test/counter@0.1|other (;14;)))
  (func $other (;8;) (type 12) (canon lift (core func $cm32p2|bnt:test/counter@0.1|other)))
  (component $bnt:test/counter@0.1.0-shim-component (;0;)
    (import "import-type-cell" (type (;0;) (sub resource)))
    (type (;1;) (own 0))
    (type (;2;) (func (param "start" s64) (result 1)))
    (import "import-constructor-cell" (func (;0;) (type 2)))
    (type (;3;) (func (result s64)))
    (import "import-static-cell-count" (func (;1;) (type 3)))
    (type (;4;) (option 1))
    (type (;5;) (func (param "start" s64) (result 4)))
    (import "import-static-cell-make" (func (;2;) (type 5)))
    (type (;6;) (borrow 0))
    (type (;7;) (func (param "self" 6) (result s64)))
    (import "import-method-cell-get" (func (;3;) (type 7)))
    (type (;8;) (func (param "self" 6) (param "by" s64) (result s64)))
    (import "import-method-cell-bump" (func (;4;) (type 8)))
    (type (;9;) (func (param "self" 6) (param "other" 6) (result s64)))
    (import "import-method-cell-pair" (func (;5;) (type 9)))
    (type (;10;) (func (param "self" 6) (param "other" 1) (result s64)))
    (import "import-method-cell-take" (func (;6;) (type 10)))
    (import "import-method-cell-live" (func (;7;) (type 7)))
    (type (;11;) (func (param "x" s64) (result s64)))
    (import "import-func-other" (func (;8;) (type 11)))
    (export (;12;) "cell" (type 0))
    (type (;13;) (own 12))
    (type (;14;) (func (param "start" s64) (result 13)))
    (export (;9;) "[constructor]cell" (func 0) (func (type 14)))
    (type (;15;) (func (result s64)))
    (export (;10;) "[static]cell.count" (func 1) (func (type 15)))
    (type (;16;) (option 13))
    (type (;17;) (func (param "start" s64) (result 16)))
    (export (;11;) "[static]cell.make" (func 2) (func (type 17)))
    (type (;18;) (borrow 12))
    (type (;19;) (func (param "self" 18) (result s64)))
    (export (;12;) "[method]cell.get" (func 3) (func (type 19)))
    (type (;20;) (func (param "self" 18) (param "by" s64) (result s64)))
    (export (;13;) "[method]cell.bump" (func 4) (func (type 20)))
    (type (;21;) (func (param "self" 18) (param "other" 18) (result s64)))
    (export (;14;) "[method]cell.pair" (func 5) (func (type 21)))
    (type (;22;) (func (param "self" 18) (param "other" 13) (result s64)))
    (export (;15;) "[method]cell.take" (func 6) (func (type 22)))
    (export (;16;) "[method]cell.live" (func 7) (func (type 19)))
    (type (;23;) (func (param "x" s64) (result s64)))
    (export (;17;) "other" (func 8) (func (type 23)))
  )
  (instance $bnt:test/counter@0.1.0-shim-instance (;0;) (instantiate $bnt:test/counter@0.1.0-shim-component
      (with "import-constructor-cell" (func $"[constructor]cell"))
      (with "import-static-cell-count" (func $"[static]cell.count"))
      (with "import-static-cell-make" (func $"[static]cell.make"))
      (with "import-method-cell-get" (func $"[method]cell.get"))
      (with "import-method-cell-bump" (func $"[method]cell.bump"))
      (with "import-method-cell-pair" (func $"[method]cell.pair"))
      (with "import-method-cell-take" (func $"[method]cell.take"))
      (with "import-method-cell-live" (func $"[method]cell.live"))
      (with "import-func-other" (func $other))
      (with "import-type-cell" (type $cell))
    )
  )
  (export $bnt:test/counter@0.1.0 (;1;) "bnt:test/counter@0.1.0" (instance $bnt:test/counter@0.1.0-shim-instance))
  (type (;13;) (own $"#type1 cell"))
  (type (;14;) (func (result 13)))
  (alias core export $main "cm32p2|bnt:test/second@0.1|[constructor]cell" (core func $"cm32p2|bnt:test/second@0.1|[constructor]cell" (;15;)))
  (func $"#func9 [constructor]cell" (@name "[constructor]cell") (;9;) (type 14) (canon lift (core func $"cm32p2|bnt:test/second@0.1|[constructor]cell")))
  (component $bnt:test/second@0.1.0-shim-component (;1;)
    (import "import-type-cell" (type (;0;) (sub resource)))
    (type (;1;) (own 0))
    (type (;2;) (func (result 1)))
    (import "import-constructor-cell" (func (;0;) (type 2)))
    (export (;3;) "cell" (type 0))
    (type (;4;) (own 3))
    (type (;5;) (func (result 4)))
    (export (;1;) "[constructor]cell" (func 0) (func (type 5)))
  )
  (instance $bnt:test/second@0.1.0-shim-instance (;2;) (instantiate $bnt:test/second@0.1.0-shim-component
      (with "import-constructor-cell" (func $"#func9 [constructor]cell"))
      (with "import-type-cell" (type $"#type1 cell"))
    )
  )
  (export $bnt:test/second@0.1.0 (;3;) "bnt:test/second@0.1.0" (instance $bnt:test/second@0.1.0-shim-instance))
  (@producers
    (processed-by "wit-component" "0.261.0")
  )
)
