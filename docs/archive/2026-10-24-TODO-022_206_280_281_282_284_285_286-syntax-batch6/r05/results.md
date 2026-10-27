# R05 の結果

2026-10-24。基準 B_WORK は `aa34661888c28590dfcb06c84482b33e791c1259`。着手時の HEAD は基準と同じで、ブランチは `mod012/R05`、作業ツリーに差分はなかった。

## 実行したコマンドと結果

外側の時間は `/usr/bin/time -p` の real である。コマンドは `rtk proxy` を通した。作業ディレクトリは、明示した Lean ビルド以外はリポジトリの根である。

| コマンド | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `cargo run -p benitoite --example gen_skill` | 0 | 3.23秒 | 公開宣言と doc から生成参照を再生成。内容が変わった生成物は `skill/references/stdlib/Log.md` のみ |
| `cargo test -p benitoite --test stdlib_doc_examples` | 0 | 6.98秒 | 追加した公開 doc 例の局所試行。1テスト成功、抽出した18例成功 |
| `lake build`（`formal/` 内） | 0 | 0.40秒 | 既定ビルド成功、296 jobs。Lean のソース・定義・言明・仮定は変更なし |
| `scripts/check.sh --level work --base aa34661888c28590dfcb06c84482b33e791c1259 --dry-run` | 0 | 0.07秒 | 6ファイルの差分から下記7単位を選択。停止・指定誤りなし |
| `scripts/check.sh --level work --base aa34661888c28590dfcb06c84482b33e791c1259` | 0 | 558.62秒 | 選択された全検査が成功 |
| `python3 -B crates/benitoite/tests/desugar_export/check_batch3.py --rust-dir target/formal-batch3/g2 --report target/formal-batch3/g2-exchange-results.json` | 0 | 1.24秒 | 1入力・11定義で六入口が一致 |
| `git diff --check` | 0 | 未計測 | 空白の誤りなし |

work が選択した検査は、`fmt`、`lint_default`（lib・tests・examples）、`lib_default`、`tests_related`（全統合）、`source_rules`、`skill_generated`、`spec_tally` である。lib は1271成功・0失敗・21 ignored。全統合は40入口、合計378成功・0失敗・10 ignored。ignored は既存の指定のまま実行していない。

全統合には `stdlib_doc_examples`、`reference_examples`、`skill_examples`、`skill_docs`、`desugar_export`、`io_modes` を含む。`batch3::export_batch4_log_standard` が五形式を書き出し、公開関数の直接呼び出しを含む同じ入力を VM と参照評価器の Direct／Request 両方式で比較した。`BENITOITE_DESUGAR_DIFF_DIR` は未設定で、計画どおり既定の `target/formal-batch3/g2/` を使った。

## Log の局所交換

入力は `crates/benitoite/tests/desugar_export/batch4/log-standard.bnt`。公開関数を直接呼ぶ純粋な `formatted() -> String` を追加したため、manifest の定義数・表層検査数は10から11へ増えた。

| 入口 | 件数と結果 |
|---|---|
| `coverageDiff` | 1件一致、不一致0、fuelExhausted 0 |
| `coverageProgramDiff` | 1件一致、不一致0、fuelExhausted 0 |
| `desugarDiff` | 11定義一致、不一致・対象外・除外はいずれも0 |
| `builtinCheck` | 1入力、94 summary comparisons、summaryMismatchCount 0、errors なし |
| `surfaceCheck` | 1入力・11定義、ok true |
| `surfaceCheckAll` | 11件一致、不一致・対象外・q11・lazyRestriction・preparationFailure はいずれも0 |

表層・コアの関数参照はともに `Log.formatRecord` であり、組み込み表では同じ名前、引数名 `record`、`Log.Record` の型に対応する `data:497`、戻り値 `String`、`kind: pure`、空のエフェクトとして出力された。新しい組み込みは追加していない。

五形式の SHA-256 は次のとおりである。比較件数とハッシュは本記録に保存し、一時的な出力先だけを記録の根拠にしない。

| ファイル（`target/formal-batch3/g2/` 内） | SHA-256 |
|---|---|
| `corpus.json` | `f8abe9504fe8e7e5c85e93a2ed247eeb53b7fe62a839c132a690bc25a83a88c6` |
| `builtins.json` | `05ea9dfc536f6dfa9443d3133d407df30f39c9b70d1b54ca4b3e7d3db222cf68` |
| `stdlib.json` | `823f42d8f9147147a0705160fd151c91bfff65d66e198f19c2f1fc3bc5f41d42` |
| `coverage.json` | `85ad908a217046d0c3c12f078e125efdafe4f4d42b1473476f4f84a66bae5441` |
| `coverage-program.json` | `5ad372a7d061266ec749a5a6a44ac302e066c61bbd9d651ad9285d0eac4db069` |

## 計画からのずれと申し送り

- 計画の R05 の列挙に加え、`tests/stdlib_doc_examples.rs` の期待件数を更新した。標準 doc へ実行例を一つ追加するために必要な変更であり、新しい検査器は加えていない。追加した例は、公開境界からの呼び出し・純粋性・Debug の整形・属性の重複順・改行と引用符のエスケープ・末尾改行のない結果を確認する。細かな書式の境界は既存の `io_modes` が受け持ち、交換入力では六入口と VM／参照評価の接続を確認する。本番の差し込み口は追加していない。
- 生成物は `gen_skill` で更新した。既存の `@builtin("Log.formatRecord")`、署名、Rust の整形処理は維持し、公開性と doc だけを変更した。03-07 に公開関数の契約を反映した。
- 検査失敗・再修正・未解決の設計判断はない。work は一度だけ実行した。局所 doc 試行の後、計画どおり全統合でも同じ入口を検査した。
- R06 は公開した `Log.formatRecord` を使って Writer と JSON の文書例を追加できる。R06 で交換入力を変更した場合は、計画 T-L に従って書き出しと六入口比較を更新する。
- 独立レビュー・受け入れは取りまとめ担当で未実施。取り込み後の short 測定は計画の「性能比較のshort」に従って取りまとめが B_AFTER を固定して行う。R06 後の stage、改造全体の change、最終候補の release も各担当の時期に実施する。
- git の変更操作、`private/` の読み取り、docs/todo の更新は行っていない。

## 取り込み後の short（取りまとめ）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8 --state after=958fbbd3228c8d379304fea16f4c00129a026a3b --name syntax-batch6-r05`。終了0、外側の時間 3分10秒（両版のビルドを含む）。ほかの作業は動かしていない。
- 出力の照合は全節で成功した。66 件の比較はすべて「判定不能」（差し引きが計時のぶれか閾値の10%・2msの大きい方以下）で、退行の疑いはない。
- 記録: `tools/bench/results/2026-10-24-958fbbd3-syntax-batch6-r05/`（手元の絶対パスは `<repo>`・`<home>` に伏せた）。
