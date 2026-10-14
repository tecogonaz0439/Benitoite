(component (core module $m (memory 1) (func (export "f") i32.const 1024 memory.grow drop))
(core instance $i (instantiate $m))
(func (export "f") (canon lift (core func $i "f"))))
