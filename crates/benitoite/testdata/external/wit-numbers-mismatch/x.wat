;; 幅だけが異なる型と、同じ幅で符号が異なる型を拒否する。
(component
  (core module $m
    (func (export "signed-byte") (param i32) (result i32) local.get 0)
    (func (export "single") (param f32) (result f32) local.get 0))
  (core instance $i (instantiate $m))
  (func (export "signed-byte") (param "v" s8) (result s8) (canon lift (core func $i "signed-byte")))
  (func (export "single") (param "v" f32) (result f32) (canon lift (core func $i "single"))))
