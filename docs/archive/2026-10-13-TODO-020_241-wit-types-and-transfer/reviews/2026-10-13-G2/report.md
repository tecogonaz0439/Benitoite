# P5〜P10（名前・字句・型検査・定数・即値・定数のコード生成）のレビュー

2026-10-13、Opus 5.5。範囲は `git diff 2881083a 239948ef -- crates`（生成物を除く）。

High の問題はない。`Value`・`Slot` は 16 バイトのままで、回収をまたいだ保持・u64 の上半分・f32 のビットの保存もテストがある。等値と鍵の経路は黙って誤った結果を返さない。P9・P10 で速さのために足した先頭の分岐（`Slot::raw`・`set_raw`、`retime_checked`、`LoadK` の Int、`immediate_constant`）は元の分岐と同じ結果になる。字句（`0xfff32` は十六進の整数、`1e-3f32` は受理、`1f32` は E0127）、最小値の直接の負号、Float32 のリテラルの一度だけの丸め、定数の評価（MIN div -1 のあふれ、除数 0）、型の集合と別名、unsafe と文言の規約は問題がない。

## Medium

1. `typeck/solve.rs` の bounds の `INT_DIV`: 型がまだ決まっていない `div`・`mod` の被演算子を、最後でない段で `Integer` に決める（`+`・`*` は待つ）。幅を開いた後、`lambda(a, b) return a div b end lambda` に `Integer8` を渡すと型の不一致になる。型変数のときは待ち、最後の段でだけ `Integer` に決め、両方のテストを加える。
2. `typeck/generate.rs` の `pending_number` と `solve.rs` の `pending_bound_number`: 止める仕組みが型の単位で、演算の種類を区別しない。P11 で `Integer8` を外すと、等値・鍵・補間・順序もまとめて開き、実行時に `Stop::Internal` になりうる。型と演算の種類の組で判定する形に改める。
3. `typeck/solve.rs` の `numeric_width` の案内: 接尾辞の案内を出す条件が `pending_number` に頼っており、止める集合が空になると `Integer32` と `Integer` の不一致で案内が出なくなる。止める仕組みと切り離す。

## Low

1. `vm/dispatch.rs` の `LoadK`: Int 以外の定数で `#[inline(never)]` の関数を毎回呼び、キャッシュ済みの定数でも参照が一回増えた。fib・loop では測れない。Float を先頭の分岐に加え、キャッシュの参照を先に行う順序に戻す。
2. `typeck/generate.rs` の U8 の負号の診断が `invalid_negation` と同じ内容を重ねている。呼び出しにまとめる。
3. 新しいコメントの多くに設計書の章と節の引用がない（`classify_width_literal`、`NUMBER_TYPE_NAMES`、`integer_range` など）。設計書に反映するときに付ける。
4. `typeck/consts.rs` の W0402: 式の型がないと空の型名の診断になる。型がなければ診断を出さないか、処理系の不具合として扱う。
5. `diag/codes.rs` の E0445 のラベルが「numeric literal」だが、指すのは式全体である。仮の診断なので P14 で消すまでの扱いでよい。
