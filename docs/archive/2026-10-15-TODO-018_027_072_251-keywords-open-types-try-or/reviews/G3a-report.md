# G3a のレビュー（2026-10-16、Opus 5.5 のサブエージェント）

対象: D5・D6a・D6b・D6c（`git diff c7019760 a4bea589`）。ファイルは変えず、cargo・lake は走らせていない。【重大】なし。反例は見つからなかった。

確かめた点: パッケージの境界（`coverage_view` は名前解決と同じ `resolve::same_package`。根と利用者モジュール、標準ライブラリと Prelude、同じ依存の中の別モジュールは同じパッケージ）。ラムダ・guard・lazy は同じ `Body.module` を引き継ぎ、実装メソッドは束縛の所属を使い、定数は E0433 で match を書けない。型の別名とジェネリックな型引数は確定後の型の束縛番号で判定する（推測。テストはない）。`case A | other`、ガード付きを数えないこと、入れ子の Option・リスト・レコードの欄、E0602・E0608 はテストどおり。getter・レコードの更新・try は `typeck::patterns` を通らないので閉じたまま。既存の assert と manifest の件数は増えただけ。旧版の負の検査も残る。規約違反なし。

【中】
1. 仕様と設計書の他の章が古いまま。`01-spec/01-01-lexical.md:103`（「`extensible` は属性としては受理しない」）、`02-impl/02-03-frontend.md:75`（「未知の名前として拒否する」）、同 164 行の属性の検査の表に `extensible` がない、`02-impl/02-10-diagnostics.md:112` の E08nn に E0817 がない、`06-06-agent-skills.md:58` が「未受理」のまま。修正案: 01-02 に合わせて書き換え、E0817 を加える。
2. 使われない分岐を持つプログラムを最後まで実行していない。`testdata/packages/d6c-extensible-external.mode` と `testdata/eval/d6c-extensible.mode` はどちらも `check` で、外の `case other -> 2` が判定の木・liveness・VM・参照インタプリタを通っていない。`ir/decision.rs:516-536` は数が 0 の分岐を捨てるだけで壊れそうにない（推測）。修正案: external の例を `run` にして `.out` を付け、data の `case other` とレコードのパターンの後の `case _` の両方を含める（D8 で入れるならその完了条件に書く）。

【軽】
3. 古いコメント: `src/types/mod.rs:246`「属性の接続までは `false`」、`src/typeck/pattern_ext.rs` のテストの「属性はまだ未受理なので」、`src/typeck/patterns.rs` のテストの「属性を受理する前でも」。
4. `CHANGELOG.md:9` のバッククォートが閉じていない。
5. `src/diag/codes.rs:852,879` の future の help が一重引用符（ほかはバッククォート）。E0607（bind）に付く「変数か `_` を加える」は bind の左辺に分岐を足せないので誤解を招く（`testdata/packages/d6c-extensible-missing.diag.json` の 3 件目）。修正案: バッククォートに揃え、E0607 は「`match` にして `_` の分岐を加える」旨にする（設計の変更）。
6. `01-spec/01-12-core-calculus.md` の 197・451 行に Rust の判定・書き出しの版の話が加わった（01-spec に実装方式を書かない）。07-04 か 02-05 へ移す。
7. 境界のテストが足りない: 同じパッケージの別モジュールから照合して閉じたままになることを処理系を通して確かめた例、`type K = Types.Kind` を通した照合、ジェネリックな型引数、`@extensible @deprecated("...")` の併用。
8. Rust は標準ライブラリで Result・Option に `@extensible` を書いても受理する（拒否は Lean の `validateDataTypes` だけ）。任意: 型表を作る段で処理系の不具合として扱う。

## 対応

- 【中】1: 01-01・02-03 の属性の説明と検査の表を受理済みの仕様へ直し、02-10 に E0817 を追記した。06-06 は D7 で修正済みであることを確認した。
- 【中】2: D8 の `d8-extensible-run` が data の `case other` を CLI の二方式・VM/参照インタプリタへ通していたことを確認し、同じ入力へ外部 record の既知パターン後の `case _` と出力 7 を追加した。従来の check 用入力は維持した。
- 【軽】3: types/mod.rs・pattern_ext.rs・patterns.rs の三つのコメントを、受理済みの属性と各テストの現在の目的に合わせた。
- 【軽】4: CHANGELOG の E0817 の括弧内のコード囲みを修正した。
- 【軽】5: E0601/E0607 の future の help のコード囲みをバッククォートへ統一し、E0607 は `match ... with` とガードなしの `case _ ->` を案内する文言へ変更した。厳密な単体テスト・JSON/文章の golden と Skill の生成物も更新した（R43）。
- 【軽】6: 01-12 の Rust と交換形式の版・接続の説明を、既存の説明と重複しないよう 07-04 へ移した。形式化した定義・定理の写しは維持した。
- 【軽】7: 同パッケージの別モジュールと型の別名は D8 の実ソースによる表で検査済みであることを確認し、ジェネリックな拡張可能型と欄の型引数への代入の二行、構文解析の表に `@extensible @deprecated("use another")` の行を追加した（R45）。
- 【軽】8: 解決済みの標準型の束縛番号で Result・Option を識別し、誤った指定を型表への登録前に内部診断として返して検査を止めるようにした。修正前の受理による退行テストの失敗と、修正後の拒否・利用者の同名型の受理を確認した（R44）。

検査: `cargo test -p benitoite --lib --test golden --test coverage_export --test desugar_export --test spec_examples --test skill_docs --test skill_examples --test reference_examples` は 1,200 件成功・既存の ignore 23 件で完了した。最後の補強後もジェネリックな欄の単体テストと `cargo test -p benitoite --lib`（1,162 件成功・既存の ignore 21 件）を再実行した。`cargo clippy --all-targets`・`cargo fmt --check`・`git diff --check` は成功した。標準型の退行テストは修正前の受理によって失敗することを確認済みである。二つの manifest は HEAD の JSON と比較し、追加した match 一件とその合計以外に差がないことを確認した。

既存の assert の削除・期待値の緩和・ignore の追加はない。削除したテストと、削除の候補にしたテストはない。Rust の本番コードは +27/-5 行、Rust のテストは +105/-11 行である（コメントと期待する文言・表の拡張による置換を含む）。Skill は `cargo run -p benitoite --example gen_skill` で再生成した。formal/ と docs/todo/ は変更せず、コミットも作成していない。依頼どおり scripts/check.sh（dry-run を含む）と gc-stress の構成の検査は実行していない。共通検査・gc-stress と、形式化全体の再照合はオーケストレータへ申し送る。
