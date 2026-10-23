# 作業 F5R の結果

2026-10-23、実装担当。B_WORK と開始時の HEAD は `7fdc02eb40c33dade9a39b4d8bff7ef7f7a4ede5`、ブランチは `mod011/F5R` である。開始時の差分はなかった。[RV-F4](../reviews/RV-F4.md) の M1 と L1〜L7 を対象とし、F5 の結果と実装を照合した。

## 各指摘への対応

| 指摘 | 対応と確認 |
|---|---|
| M1 | F5 で三条件とも実装済みであり、交換器と manifest は変更しなかった。`tests/desugar_export/exchange.rs` は書式付き String も `formatted: {ty, spec}` とし、kind・align・sign・alternate・zero・width・precision の七欄を出す。省略した width・precision は null、変換頭は `%Format.<型名>` の直接の primName である。`desugar_export.rs` の通常の書き出しは corpus 14・sidecar 6 である。`formatted_interpolation_order.bnt` は routing・exchange の両 manifest で対象内4定義として登録されている。行の追加だけで済ませた状態ではなく、書式を保持する実装と、独立した表層・コア、全14頭、書式付き String の脱落を検出する検査がある。今回も work の desugar_export と、Rust の書き出しを読む独立交換検査が成功した。 |
| L1 | `runtime_builtins.rs` の「F4b 前」を除き、raw の内部頭を確かめるテストと、表層の型選択・定数評価を確かめる `formatted_interpolation_connects_constants_and_both_evaluators` の分担を記した。 |
| L2 | `base/format.rs`・`builtins/table.rs`・`runtime_builtins.rs` の D29 と study の参照を、現行の設計書 02-06「書式化の内部頭」と 03-06「書式付き補間の内部書式化」へ置き換えた。 |
| L3 | F5 後も残っていた FormatSpec・Surface/Syntax・Exchange/Builtins のコメントを「書式化の内部頭」「書式化の関数」へそろえた。FormatSpec の算法・シグネチャのコメントも同じ語にした。コメントを除去して基準版と比較し、3ファイルの定義・定理の本文に変更がないことを確認した。 |
| L4 | 予算のテスト名を `formatted_interpolation_uses_display_width_and_checks_limits` へ変更した。コメントは表示幅と出力バイト数、論理上限、共有予算、128バイトの見込みの誤用を確かめる内容に合わせた。確保前の順序は、このテストでは区別できず、読解で確認する事項であることも記した。入力・期待値・予算は変えていない。 |
| L5 | 手書き Skill の説明を、`benitoite check` が E0262 と E0468 を実行前に報告する文へ修正した。 |
| L6 | `EvalError` は Limit・Arithmetic・Duplicate・Unavailable だけであり、既存の内部エラーの手段はなかった。RV-F4 の代案に従い、`format_value` の decode・prepare・parts の失敗と未対応の値の分岐は型検査後には到達しないこと、既存の Unavailable へまとめることをコメントに記した。定数評価のエラー伝播の拡張は行っていない。 |
| L7 | `1(2)` の結果を `+s` で補間する入力で E0468 の欠落を再現した。空集合の書式では、zonk 後の Error に対する早期の抑制と、回復した型に対する抑制の両方を外した。それ以外の書式と書式なしの回復は保つ。既存の回復表へ `+s` の1行を追加し、3原因との21入力で確認した。02-05 の回復の説明も合わせた。 |

## L7 の再現とテストの作成時の関門

CLI の入力は次のとおりである。`sample` だけで最初に試した実行は main 不在の E0414 も報告したため、独立した main を加えた同じ入力で再確認した。

```text
function sample() -> String
 bind value <- 1(2)
 return "${value:+s}"
end function
function main() -> Unit
 return ()
end function
```

修正前は終了2で E0403 だけを報告し、修正後は同じ終了2で E0403 と E0468 を報告した。E0468 の主位置はコロンを含む `:+s`、関連位置は値であり、「この書式はどの型も受け入れない」という注記が残る。

既存の `interpolation_formats_preserve_recovery` の表へ1行だけ加えた。守る契約は、型に依存しない不適合を診断済み原因の回復で失わず、型に依存する不適合の抑制を保つことである。従来の `.2f` だけの表は空集合の書式を通らず、抑えすぎを検出しなかった。公開の `pipeline::check_text` を本物の各段へ接続し、E0403 または E0467 と E0468 の件数、主位置、実行用プログラムがないことを確認する。テスト専用の公開API・フラグ・差し込み口は増やしていない。追加行は修正前に期待した E0468 の欠落で失敗し、修正後に成功した。

最初の実装修正では回復した型の分岐だけを直したため、同じテストが引き続き失敗した。先行する zonk 後の Error の早期終了にも同じ例外を適用して解消した。既存の入力・期待結果・ignore・時間制限は緩めていない。テストの削除・追加テスト関数の新設は行っていない。

## 検査の指定と結果

コマンドはリポジトリの根から実行した。rtk の包みは省略して記す。外側の時間は `/usr/bin/time -p` で測った。作業末の指定は [plan.md「検査の割り当て」](../plan.md#検査の割り当て) の work F5R の行に加えた。

```sh
scripts/check.sh --level work --base 7fdc02eb40c33dade9a39b4d8bff7ef7f7a4ede5 --test declarations --test runtime_builtins --test golden --test desugar_export --test skill_docs --test skill_examples --test spec_examples
```

| コマンド・対象 | 終了状態・結果 | 外側の時間 |
|---|---|---|
| `cargo test -p benitoite --test declarations interpolation_formats_preserve_recovery -- --nocapture`（修正前） | 101。追加行の最初の原因 SourceLocation.here で E0467 だけとなり、期待する2件との差で失敗 | 7.86秒 |
| `cargo run -p benitoite -- check /private/tmp/benitoite-f5r-l7.bnt`（main 追加前、修正前） | 2。E0403 と main 不在の E0414。E0468 は欠落 | 16.70秒 |
| `target/debug/benitoite check /private/tmp/benitoite-f5r-l7.bnt`（main 追加後、修正前） | 2。E0403 のみ。指定の `1(2)` による欠落を再現 | 0.06秒 |
| 同じ回復表の局所テスト（回復分岐だけの初回修正） | 101。zonk 後の Error の早期終了にも対応が必要だった | 4.51秒 |
| 同じ回復表の局所テスト（両方の抑制を修正後） | 0。1テスト・21入力成功 | 7.73秒 |
| `target/debug/benitoite check /private/tmp/benitoite-f5r-l7.bnt`（修正後） | 2。E0403 と独立した E0468 を報告 | 1.09秒 |
| `cargo fmt --all` | 0 | 2.25秒 |
| work の同じ指定に `--dry-run` を追加 | 0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally・formal_build を選択。分類不能による停止なし | 0.07秒 |
| work | 0。指定した全項目成功。Lean の既定 `lake build` と sorry の不使用の確認を含む | 256.82秒 |
| `python3 -B formal/tests/test_batch5_exchange.py --rust-dir target/formal-batch5` | 0。独立検査8件成功。今回の Rust 出力32定義・書式付き28箇所・書式付き String 3箇所・脱落0件、全14頭を確認し、六入口の照合も成功 | 2.18秒 |
| 読み取り専用 Python による Lean のコメント除去比較と Markdown の静的確認 | Lean 3ファイルの本文一致。Markdown は初回にコード内をリンクと誤認し1、コードを除いて再実行して0。plan・02-05 の既存見出し、リンク先103件、フェンス、末尾空白を確認 | 初回0.21秒、再実行0.11秒 |
| `python3 -B /private/tmp/benitoite-f5r-static.py` | 0。Lean 3ファイルの本文一致と、上記2文書・idioms・本記録の4文書の相対リンク106件、既存見出し、フェンス、末尾空白を確認 | 0.08秒 |
| `git diff --check` | 0 | 0.02秒 |

work の lib は1,271件成功・21件 ignored、統合は declarations が24件成功・1件 ignored、desugar_export が30件成功・1件 ignored、golden が2件、runtime_builtins が23件、skill_docs が8件、skill_examples が3件、spec_examples が7件成功した。交換の全件書き出しを行う ignored の検査は実行していない。

fmt・clippy・ソース規約・生成 Skill の照合・仕様集計・Lean の既定ビルドも成功した。局所の交換入力は work の `export_batch5_formats` で今回書き出したものを用いた。全件比較を再実行した結果ではない。

本番の Rust はコメントを含め12行追加・4行削除、テストは11行追加・6行削除である。consts.rs の cfg(test) 部分をテストに数えた。テストの削除による整理は行っていない。

## 計画からのずれと申し送り

- plan.md に作業 F5R の節と work 行がなかったため、依頼文と RV-F4 を作業範囲とし、検査の割り当てに具体的な work 行を加えた。M1 の確認に交換の読者を、L5 の修正に Skill 文書と実行例を、L3 に Lean の既定ビルドを含めた。
- 言語の規則、成功入力の型・エフェクト、交換形式、Lean の主定理の前提・結論、公理は変更していない。ヒープの不変条件・安全点を越える保持方式も変更していない。全件の `check-formal.sh`、heap/stress、change・release は本作業の実行には含めていない。F5 の K1 を今回の実行結果として扱っていない。
- 作業途中に `decisions.md` の変更と未追跡の `reviews/RV-F5.md` が現れた。いずれも本担当の変更ではなく、そのまま保持した。
- private とそれを指すリンク、docs/todo、過去の文書は読んでいない。git は基準の本文・状態・差分・HEAD・ブランチ名の読み取りにだけ使用し、変更操作はしていない。

本作業の範囲に未実施の検査、担当する失敗、設計者の判断を要する未決事項は残っていない。L6 はレビューが認めたコメントによる対応であり、実行時と同じ内部エラーの伝播へ変更したものではない。取り込み・独立レビュー・受け入れと後続の全体検査は取りまとめが担当する。

## 取りまとめの性能の比較 short（F5R の取り込みの後）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --state after=678aba50ae8f6ad52d0bdb26e7847d62bcbb7b5c --name batch5-f5r`（比べる元は decisions.md の D41）。
- 終了 0、外側の時間 108 秒（ビルドを含む）。
- 判定: 63 点が「判定不能」、残りが「達成」（しきい値の内側）。W1 比で higher-1-300 +4.2%、classes-300 +3.9%、functions-modules-1000-1 +3.7%。退行の疑いはない。これが G1 の前の最後の short である。
- 記録: `tools/bench/results/2026-10-23-678aba50-batch5-f5r/`（手元の絶対パスは `<repo>` に伏せた）。
