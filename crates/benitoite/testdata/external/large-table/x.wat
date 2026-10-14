(component (core module $m (table 20000 funcref) (func (export "f")))
(core instance $i (instantiate $m))

(func (export "f") (canon lift (core func $i "f"))))
