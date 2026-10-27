(component
  (type $r (resource (rep i32)))
  (core func $new (canon resource.new $r))
  (core func $drop (canon resource.drop $r))
  (core module $m
    (import "r" "new" (func $new (param i32) (result i32)))
    (import "r" "drop" (func $drop (param i32)))
    (global $last (mut i32) (i32.const 0))
    (global $live (mut i32) (i32.const 0))
    (func (export "allocate") (param $n i32) (param $release i32) (result i32)
      local.get $release
      if
        global.get $last call $drop
        global.get $live i32.const 1 i32.sub global.set $live
      end
      block $done
        loop $again
          local.get $n i32.eqz br_if $done
          i32.const 0 call $new global.set $last
          global.get $live i32.const 1 i32.add global.set $live
          local.get $n i32.const 1 i32.sub local.set $n
          br $again
        end
      end
      global.get $live))
  (core instance $r (export "new" (func $new)) (export "drop" (func $drop)))
  (core instance $i (instantiate $m (with "r" (instance $r))))
  (func (export "allocate") (param "n" u32) (param "release" bool) (result u32)
    (canon lift (core func $i "allocate"))))
