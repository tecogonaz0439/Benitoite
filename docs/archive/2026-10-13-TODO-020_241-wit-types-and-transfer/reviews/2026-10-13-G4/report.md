# P15〜P18（変換・標準関数・ビット演算・型クラス・正の名前のモジュール）のレビュー

2026-10-13、Opus 5.5。範囲は `git diff fba89e96 974c77fe -- crates`（生成物を除く）。cargo は走らせていない。

変換・ビット演算・型クラスの意味に重大な誤りはない（狭い整数の parse の字句、floorDivide・floorModulo の境界、u64 と Integer・Decimal の変換の全域、Float32 の縮小の丸めと NaN・無限大・負の零、シフト量の範囲、`Order[Float32]` の NaN の全順序、別名による二重の実装の拒否、正の名前のモジュールの転送）。VM と参照インタプリタは本体を共有する。弱めたテストはない。

## High

1. `builtins/table.rs` の `table_names_parts_capabilities_and_schemes_are_consistent`: P18 が `PARTS` の末尾に `width_bits::DECLS`（39 件）を加えたのに期待値を直しておらず、`cargo test --lib` で失敗する。P18 の完了の条件がこのテストを含まなかった。`lengths` に 39 を加え、件数を 54・483・`[410, 16, 57]` にする。

## Medium

1. 新しい標準モジュール（`Integer8.bnt` ほか 11 個）の `///`・`//!` が日本語で、gen_skill が英語の Skill の参照の文書へそのまま写している。既存のモジュールに揃えて英語に直し、作り直す。

## Low

1. `table.rs` の `INTERPOLATION` の doc コメントが、特例を消した後の形と合わない。
2. `Integer64.bnt` のシフトの引数の型を `n: Integer64` にしており、`Integer.bnt` の `n: Integer` と表記が揃わない。
3. `float32.rs`・`unsigned_integer64.rs` の `as` による変換は意図した丸めだが、AGENTS.md の「`as` は収まることが明らかな箇所に限る」の例外なので、根拠をコメントに一行足す。
