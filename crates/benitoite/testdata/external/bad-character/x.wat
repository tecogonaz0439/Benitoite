(component (core module $m (func (export "f") (result i32) i32.const 55296))
(core instance $i (instantiate $m))

(func (export "f") (result char) (canon lift (core func $i "f"))))
