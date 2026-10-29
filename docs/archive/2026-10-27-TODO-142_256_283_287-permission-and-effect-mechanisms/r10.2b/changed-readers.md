# 変更したファイルと読者

基準は `a26ed29afaeb444325da1daf362d9fe7ad12b18b`。列挙するパスはリポジトリの根からである。

| ファイル | 読む内容 |
|---|---|
| `crates/benitoite/examples/derive_inventory/mod.rs` | 依存する型名を探索するパターンの追随。表示は共有のTy::showを使う |
| `crates/benitoite/examples/derive_inventory/schema.rs` | 旧スキーマへ表せない添字を既存のエラーで拒否。Topの既存構築を追随 |
| `crates/benitoite/src/builtins/table.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/bytecode/codegen/emit.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/bytecode/codegen/tests.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/cli/inspection.rs` | 先行レビュー軽1。Topの利用者エフェクトをファイル由来から除く |
| `crates/benitoite/src/cli/tools/test_runner/docs/prepare.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/cli/tools/test_runner/mod.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/external/check.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/external/expansion.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/external/tests.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/external/types.rs` | WITへ変換できない非Topの型を明示的に拒否。子の展開は同じ添字を保持 |
| `crates/benitoite/src/ir/check.rs` | 確定型の範囲変数と資源の非Topを拒否。不変の添字の公開境界テスト |
| `crates/benitoite/src/ir/core_ir.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/ir/decision.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/ir/decision/arena.rs` | 添字の共有データと範囲の文字列のメモリを保守的に計上 |
| `crates/benitoite/src/ir/decision/rows.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/ir/desugar.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/ir/desugar/decls.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/ir/desugar/die_tests.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/ir/desugar/effects.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/ir/desugar/exprs.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/ir/desugar/tests.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/runtime/assert.rs` | 実行時の検査用の型代入で添字を保持。値の表現による分類は型名を使う |
| `crates/benitoite/src/runtime/assert/tests.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/builders.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/calls.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/consts.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/context.rs` | 型から推論型への代入で添字を保持。修飾名の探索は型名だけを使う |
| `crates/benitoite/src/typeck/decls.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/effects/mod.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/effects/special.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/effects/tests.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/external.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/generate.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/infer.rs` | 推論型の添字 |
| `crates/benitoite/src/typeck/interval/discovery.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/interval/domain.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/interval/fixed_domain.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/interval/flow/independent.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/interval/flow/range/tables_tests.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/limits.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/pattern_ext.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/patterns.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/solve.rs` | 展開・単一化・Fail内部の確定・診断に添字を保持 |
| `crates/benitoite/src/typeck/solve/effect_key.rs` | 制約の構造の鍵に添字を保持 |
| `crates/benitoite/src/typeck/solve/provenance.rs` | 診断の由来・既知の不一致・回復に添字を保持 |
| `crates/benitoite/src/typeck/tests.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/tests/interpolation_formats.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/traits/collect.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/traits/impls.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/typeck/traits/solve.rs` | 辞書の対象の添字の照合・型の確定での保持 |
| `crates/benitoite/src/typeck/traits/tests.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/src/types/builtin.rs` | 不変の添字の格納、標準署名の範囲変数と具体化 |
| `crates/benitoite/src/types/mod.rs` | 型の添字、構造の比較・代入・表示、署名の具体化と整形式性、公開APIのテスト |
| `crates/benitoite/src/vm/builder_tests.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/tests/coverage_export.rs` | 旧版へ非Topを混ぜず明示的に拒否。既存のTop構築を追随 |
| `crates/benitoite/tests/desugar_export.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/tests/desugar_export/builtins.rs` | 補助表の束縛の移し替えで添字を保持 |
| `crates/benitoite/tests/desugar_export/exchange.rs` | 旧版へ非Topを混ぜず明示的に拒否。既存のTop構築を追随 |
| `crates/benitoite/tests/desugar_export/lib.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/tests/desugar_export/named.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/tests/named_arguments.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `crates/benitoite/tests/runtime_builtins.rs` | 既存構築の明示のTop、または型名の分類・子の走査のパターンの追随 |
| `docs/design/02-impl/02-05-typechecker.md` | 格納・添字の保持・コアIRの検査の反映 |
| `docs/design/02-impl/02-06-ir-and-lowering.md` | 格納・添字の保持・コアIRの検査の反映 |

読んだが変更を要しなかった読者として、VMの実行本体・バイトコード検証器・参照実行器は既存の値の表現と命令を使い、型を保持する箇所は共有のTyを複写する。コード生成が型名を読むのは命令・実行時の表現を選ぶためである。静的な型を再構築して添字をTopへ戻す変換は加えていない。examples/try_actions_inventory.rsのTy::Con(..)も既存の分類のままでよい。
