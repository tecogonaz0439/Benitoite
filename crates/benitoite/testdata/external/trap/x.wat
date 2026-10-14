(component (core module $m (func (export "f") unreachable))
(core instance $i (instantiate $m))
(func (export "f") (canon lift (core func $i "f"))))
