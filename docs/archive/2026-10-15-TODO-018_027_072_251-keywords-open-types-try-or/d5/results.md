# D5 Rust の型表とパッケージの比較

## 目的と変更

属性を受理する前に、拡張の指定と本体の所属を後の網羅性の判定へ渡すための情報を用意した。開始時の HEAD は `c7019760`、作業ツリーは clean だった。AGENTS.md、共通の関門 K と作業 D5、design.md の変更範囲とパッケージ境界、decisions.md の R7・R12・R33〜R35、P2 の型と依存の調査を確認した。

| ファイル | 変更 |
|---|---|
| `src/types/mod.rs` | `AdtDef.extensible: bool` を追加 |
| `src/typeck/decls.rs`、`typeck/patterns.rs`、`src/ir/check.rs`、`ir/decision.rs`、`src/types/mod.rs`、`tests/coverage_export.rs` | 既存の全 9 か所の `AdtDef` の構築に `false` を明示。ソースから集める data・record は閉じたまま |
| `src/resolve/{mod,collect,lookup}.rs` | パッケージの比較を `resolve::same_package` へ移し、既存の公開範囲の判定から共用 |
| `src/typeck/context.rs`、`generate.rs`、`consts.rs`、`traits/{solve,impls}.rs` | `Body::new` に所属の `ModuleId` を渡して保持。関数・実装メソッド・定数は宣言の束縛、制約の補助検査は元の本体または実装の所属を使う |
| `src/typeck/patterns.rs` | `CoverageView` と `coverage_view` を追加。拡張の指定が真で本体と所属が異なる型を、束縛番号の集合として集める。公開境界の表形式のテストを一つ追加 |
| `docs/design/02-impl/02-05-typechecker.md` | 本体の所属と型表の指定、view 生成だけを用意し判定には未接続である現状を反映 |
| この記録 | 関門への回答、検査、後続への申し送り |

`src/` と `tests/` は `crates/benitoite/` の下を指す。lambda・guard・lazy は `Body::block_in` / `expr_in` で同じ本体を使い、エフェクトと戻り先だけを差し替えるため、所属を変える処理は加えていない。`owner` がない定数や補助の検査でも、所属を推測しない。

## test-audit の作成時の関門

1. 守る契約は、型表の拡張指定と所属から、照合する本体の view を作ることである。主となる境界は `typeck::patterns::coverage_view` の公開の出力とする。
2. 捕まえる退行は、根と依存の同名モジュールの混同、標準のモジュールの分断、同じ依存の内部モジュールの分断、異なる依存の混同、指定のない型の混入、record の取りこぼしである。設定ファイルと存在しない ID を同じパッケージにする誤りも確かめる。期待する束縛番号の集合は本番の比較関数を使わずに書いた。
3. 既存のテストには view 生成の入口がなかったため、一つの表形式のテストを追加した。既存の公開範囲は resolve・package_command・golden、閉じた型の脱糖は desugar_export の既存の検査を使う。まだ判定に接続していない本体の所属について、内部の欄だけを読むテストは加えない。
4. テスト専用の公開 API・フラグ・差し込み口は追加していない。新しい二つの公開の補助と型は D5 の準備そのものである。既存の assert の削除、期待値の変更、ignore の追加はない。

削除したテストと、削除候補にしたテストはない。本番の Rust は 70 行追加・34 行削除（差し引き 36 行増）、テストの Rust は 81 行追加・削除 0 である。既存のテストデータへの変更は型表の新しい欄を `false` で埋めるだけであり、期待値を作り直していない。

不具合修正の作業ではなく、準備の追加である。新しいテストの初回コンパイルでは `BindingMap::get_mut` が存在せず失敗したため、既存の `get`・`insert` を使う準備へ直した。本番の型表 API は増やしていない。

## 検査

実行前に検査内容を報告した。指定に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成は実行していない。Lean・構文の章・標準ライブラリ・診断の表・Skill は変更していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,157 passed、0 failed、既存 ignored 21。78.20 秒 |
| `cargo test -p benitoite --lib resolve::` | 成功。41 passed、0 failed。0.77 秒 |
| `cargo test -p benitoite --test package_command --test golden --test desugar_export` | 成功。3 suite 合計 29 passed、0 failed、既存 ignored 1。57.23 秒 |
| `cargo test -p benitoite --test coverage_export` | 成功。1 passed、0 failed、既存 ignored 1。0.06 秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |

実装中の整形には `cargo fmt --all` を実行した。最終差分で既存の assert・期待値・ignore・交換形式の版に変更がないことを確認した。

## 計画との差と申し送り

計画からのずれと診断の仕様変更はない。属性の受理・将来の形・判定への view の接続・交換形式の版は、この作業では変更していない。判断を追加する必要はなく、decisions.md の R 番号の追加もない。

D6a では本体の `module` と `coverage_view` からソースの match/bind ごとの view を作り、再帰・到達可能性・選択肢の判定へ同じ参照を渡す。getter・record 更新・try の合成照合は閉じたままにする。D6b の所属と builtin の出力、D6c の属性受理の順序は計画どおりである。コミットと docs/todo/ の変更は行っていない。
