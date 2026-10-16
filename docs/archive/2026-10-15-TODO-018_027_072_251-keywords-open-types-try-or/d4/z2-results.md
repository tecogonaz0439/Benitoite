# Z2 の修正と確認

## 修正の範囲

G2 の指摘 1〜8 を修正した。Exchange の型・本体・定数に宣言側の package を保持し、型には標準の Result/Option を表示名から区別する builtin を必須で加えた。Lean で extensible かつ本体と所属が異なる全型を求め、受け取った view と完全照合する。標準型の開放、型情報の欠落、関数とメソッドの view の重複を拒否し、旧版の既定値は形式ごとの既知の欄の経路だけで補う。

CoverageExtension.lean に構成子追加の関係、追加後の値についての特殊化と補題 U、拡張後の Exhaustive の定理を加えた。現在の健全性の定理の言明と、Val・Inhabits・実行の規則は変更していない。01-12・02-05・07-04、contracts、p2 の定理対応、plan の D6b と G2-report の対応節を揃えた。

設計者の合意（2026-10-16）を decisions に記録した。計画の補足は R33（必須の所属・標準型の識別と view の再計算）、R34（変更前の構成子一覧の完全性も保持する）、R35（外部参照可能な定数と、Rust が定数内の match を拒否する範囲）に記す。Rust の書き出しを 9/3/3 へ上げる作業は D6b に残す。

## test-audit の関門

追加した主な退行テストは、六つの交換入口で view の指定漏れ・作者側の余分な指定・Result/Option の開放を拒否する契約と、脱糖単独で型情報の欠落・重複 view を拒否する契約を守る。従来のテストは指定先の存在と属性だけを確認し、パッケージから必要な指定を求めていなかったため、この失敗を検出できなかった。修正前の実行ファイルへ四つの追加テストを渡し、27 ケースの失敗、エラー 0 を確認した。修正後は全て成功する。

既存の assert の削除、期待値の緩和、ignore の追加はない。属性と型表の食い違いの検査は、対象の view 自体を有効に保ってから表の不一致を検査する。空表を除いた場合は、型表との比較より先に data 型の情報欠落で拒否するため、その明確な拒否理由へ期待を更新した。独立入力の外部 view は同じ作者の全 extensible 型を含むように揃え、元の期待結果と件数を維持した。新しい Rust の本体コードとテストはない。

## 検査

| 検査 | 結果 |
|---|---|
| cargo test -p benitoite --lib | 成功。1,156 passed、0 failed、既存 ignored 21 |
| cargo test -p benitoite --test desugar_export --test coverage_export --test spec_examples | 成功。22 passed、0 failed、既存 ignored 2（書き出しは下記の全件比較でも実行） |
| cargo clippy --all-targets | 成功 |
| cargo fmt --check | 成功 |
| formal/ で lake build | 成功（162 jobs）。sorry なし |
| test_extensible_exchange.py / test_named_exchange.py / test_width_exchange.py | 成功。19 / 12 / 4 件 |
| 公理依存 | 36 モジュール・7,108 宣言、予期しない公理 0。z2-axioms-summary.json と z2-theorems.lean に記録 |
| bash scripts/check-formal.sh | 成功、終了状態 0。約 14 分。ignore を含め coverage_export 2 件・desugar_export 15 件、独立入力 19/12/4 件、六入口と manifest の完全一致 |

全件比較は 1,727 入力・73,733 定義・22,438 網羅性項目で一致した。独立した網羅性入力は 10,020 件が一致し、燃料切れ 0。表層の全件検査は matched 51,636、既存の outOfScope 19、q11 1、mismatched/preparationFailure/lazyRestriction 0 で、分類理由まで manifest と一致した。検査エラーによる既存の除外 381 件も維持した。

出力は target/desugar-diff/run-71187/ と target/coverage-diff/run-71187/、全体のログは target/z2-review/check-formal.log にある。変更した処理系の Rust の本体とテストはともに 0 行。Lean の交換入力の Python テストは extensible の既存 14 件に 5 件を加えた（extensible 14→19、named 12 と width 4 は維持）。

scripts/check.sh（dry-run を含む）と gc-stress の構成は実行していない。コミットと docs/todo/ の変更は行っていない。

## 申し送り

D6b は型と各本体の package、標準型を解決した builtin（result/option/ordinary）、全型について再計算した view を出す。dataTypes と dataDecls は同じ宣言順を使う。負の入力と定数の適用範囲は plan に追記済みである。Z2 の定理と必須欄を、G3 の前の修正確認へ渡す。
