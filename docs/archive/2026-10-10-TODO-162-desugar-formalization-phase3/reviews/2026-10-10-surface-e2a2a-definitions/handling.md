# 指摘の扱い（段階 E2a-2a）

Opus（`response.md`）と Astra（`response-astra.md`）がレビューした。両者とも、`opPrim` が返す型引数の `AtomsIn` が健全性の前提から漏れていることを高として挙げた。Opus はそれ以外に高を挙げず、両者とも、この点を前提に加えれば E2a-2b へ進んでよいと判断した。

| 指摘 | 重さ | 扱い |
|---|---|---|
| Opus 1・Astra 1. `opPrim` の型引数の `AtomsIn` | 高 | Opus の案 (a) を採る。健全性の前提に `OpPrimTypeArgs opPrim : ∀ o t b ts, opPrim o t = some (b, ts) → ts = o.typeArgs t` を置き、`E_Binary` の型引数の比較を要らなくする。具体的な `makeOpPrim` はこれを満たす（E2c で確かめる）。理由: 比較と原子の保存の両方が要らなくなり、Astra の案（入力型の `AtomsIn` から返り値の `AtomsIn` を導く契約）より前提が少ない |
| Opus 2. 型の結び | 中 | E2a-2b の最初に `tyJoin` と健全性・保存の補題を加え、`ite`・`elseIf` の結果に使う |
| Opus 3. エフェクトの差 | 中 | E2a-2b の最初に `diffEff` と三つの補題を加え、`handle` の ε の初期値と反復に使う |
| Opus 4. `AtomsIn` を運ぶ補題と前提をまとめる定義 | 中 | E2a-2b の最初に加える（`Tys.AtomsIn` の所属の言い換え、`Env.AtomsIn` と環境の操作、`Declarations.AtomsIn`・`Builtins.AtomsIn`、式の注釈の述語） |
| Opus 5. `sorry` の 9 件は成り立つ | 低 | E2b-1 で、示された手順で証明する |
| Opus 6. `singleEff_eq` の前提の形 | 低 | E2a-2b で `atoms.contains` の形の版を加える |
| Opus 7. `handle` の型 t | 低 | t を本体と各節の型の結び（`tyJoin`）で求める。事前点検の方針の控え（本体の最小の型）を改める |
