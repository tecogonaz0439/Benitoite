# 作業 A2 の結果

- 実施日: 2026-10-23。
- 基準 B_WORK と作業中の HEAD: `f5bab7a412145538becc1ec27b1ef948ce1115a9`。
- A2 の実装と作業末の検査を完了した。git の変更操作、private の読み書き、docs/todo の更新、公開操作は行っていない。

## 実行した検査

作業末の自動選択には次のコマンドを使った。

```sh
scripts/check.sh --level work --base f5bab7a412145538becc1ec27b1ef948ce1115a9 --test declarations --test checked_args --test golden --test property_library --test external_signals --test vm_handlers --test io_modes
```

途中停止後、変更したテストと未実施の検査を次の指定で続行した。直前の実行から変えたのは `tests/declarations.rs` の A1 の一時防御の対照だけであり、成功済みの lib と checked_args の入力は変えていない。この同一作業の途中停止では、この二つを再実行していない。

```sh
scripts/check.sh --level work --base f5bab7a412145538becc1ec27b1ef948ce1115a9 --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples --test declarations --test golden --test property_library --test external_signals --test vm_handlers --test io_modes
```

外側の時間は `/usr/bin/time -p` の real である。dry-run は各実行の指定へ `--dry-run` を加えた。

| 実行 | 終了状態 | 外側の時間 | 結果 |
|---|---|---|---|
| 自動選択の dry-run、初回 | 0 | 0.08 秒 | fmt、lint_default、lib_default、指定7統合対象、source_rules、skill_generated、spec_tally、spec_examples を選択 |
| 自動選択の本実行、初回 | 1 | 11.46 秒 | fmt 成功後、追加テストの網羅しない match により lint_default で停止 |
| 自動選択の dry-run、修正後 | 0 | 0.07 秒 | 同じ検査を選択 |
| 自動選択の本実行、修正後 | 1 | 130.18 秒 | fmt・lint・lib・checked_args 成功後、declarations に残っていた A1 の拒否の期待で停止 |
| 続行の dry-run | 0 | 0.01 秒 | 上記 only の各検査と未完了の6統合対象を確認 |
| 続行の本実行 | 0 | 102.31 秒 | 選択した検査すべて成功 |

成功した件数は、lib 1,261 件（既存の ignore 21 件）、checked_args 10 件、declarations 16 件、external_signals 3 件、golden 2 件、io_modes 11 件、property_library 15 件（既存の ignore 2 件）、vm_handlers 5 件、spec_examples 7 件である。統合7対象の成功は計62件である。source_rules の二検査、Skill 生成物の一致、仕様テスト集計の自己検査と本番集計も成功し、初回リリース版の未記入の完了条件はなかった。既存の ignore と制限時間は変えていない。

途中の局所検査は次のとおりである。局所検査と整形・生成の外側の時間は計測していない。

| コマンド | 結果 |
|---|---|
| `rtk cargo test --test declarations file_uses --no-fail-fast` | 開発中に8回実行。最後の2回は各6件成功。先行する失敗は下記の旧期待と新しい検査入力・期待の修正による |
| `rtk cargo test --test declarations --test vm_handlers --test io_modes file_uses --no-fail-fast` | declarations は NoFail の期待の不足で失敗。VM・IO は各1件成功。修正後は作業末の全対象で確認 |
| `rtk cargo fmt --all` | 整形を適用。最終の fmt 検査は作業末の入口で成功 |
| `rtk cargo run -p benitoite --example gen_skill` | 生成成功。実際の差分は diagnostics.md のみ。作業末でも再生成と一致を確認 |
| `git diff --check` | 成功 |
| Python による文書の静的確認 | 追加した相対リンクと見出し参照、変更した設計書のフェンスと末尾空白に問題なし |

## 失敗と修正

- 型検査前の防御を外した直後は、A1 の「通常ファイルの uses を拒否する」という旧期待が失敗した。通常ファイルの成功と package.bnt の拒否を分けた。宣言収集にも残っていた旧期待は作業末で判明し、`uses Log[Integer]` を E0513 で拒否する対照へ変更した。宣言収集と通常の check が同じ診断と位置を返す検査は保った。
- 新しい検査入力を、型の別名の `alias` から `type`、改名禁止の組み込みモジュールの import から通常の import、関数末尾の値から明示的な return へ修正した。NoFail の負の対照では、不足した Fail の E0501 と行の条件の E0515 がともに独立した誤りであることを確認して期待へ明記した。途中に試した handle の対照は呼び出しと捕捉の両方で NoFail を要求するため、直接呼び出す対照へ戻した。
- 初回の作業末の clippy が指摘した新テストの `_ => None` は、Item の全バリアントを明記して修正した。
- 文書の最初の静的確認は、既存の説明用コードにある `[...] (...)` のリンク表記までリンク先として扱って失敗した。リンクの確認対象を追加行に限定し、変更文書全体のフェンスと空白の確認は保った。文書をまとめて編集する補助スクリプトの文字コードエラーと、順序が逆のパッチ適用の失敗でも文書は変更されず、個別のパッチで反映した。

## 計画との差と申し送り

- 計画の列挙にある章に加え、02-03「構文解析の結果」の A1 の一時防御の説明を現在の接続状態へ直した。既存の見出しは改名していない。
- 宣言収集の共通の出力は `TypeckOutput.effective_effects: BindingMap<EffectiveEffects>` である。`effects` は Scheme と同じ合併後の効果行、`origins` は元の効果ごとの正規化済みの効果・修飾名・span・file の印、`wrote_io_all` は両リストを合わせた印である。元の `Module.file_uses` と `FnDecl.uses` は変更していない。NoFail と本体の効果の処理は合併後の Scheme を使う。
- A3 はこの表を入口の許可・報告・IO.All の縮小警告へ接続する。今回は型検査の入口・公開性・外部宣言を接続した。共通宣言の位置を一関数の自動編集の範囲に使わない。
- A4 の `src/cli/tools/package/mod.rs`、A5 の `examples/derive_inventory/mod.rs`、A6 の `src/cli/tools/formatter/mod.rs` と `examples/try_actions_inventory.rs` の未対応の防御は残した。A2 が外す `src/modules/load.rs` の防御は残っていない。package.bnt のファイル宣言の拒否も保った。
- テストの主な境界は公開の宣言収集と check である。型と元位置・適用範囲・既存の制約は declarations、非再開ハンドラまでの接続は vm_handlers、実 IO と子タスクの完了順は io_modes が受け持つ。本番のテスト専用の公開口は増やしていない。本番 Rust は223行追加・76行削除、統合テストは401行追加・16行削除である。
- ヒープの保持方式・安全点と Lean の規則は変更していないため、局所の特殊構成・check-heap・check-formal は A2 では追加実行しない。言語の規則、主な定理、公理について取りまとめへ判断を求める停止事項はない。
- 取り込み後の short 測定、独立レビュー、受け入れは計画どおり取りまとめ担当である。本記録をそれらの完了の証拠にはしていない。

## 取りまとめの性能の比較 short（A2 の取り込みの後）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --state after=508a9b629f46908c2c4d2c4ac9a31b728a8a5734 --name batch5-a2`（比べる元は decisions.md の D41）。
- 終了 0、外側の時間 107 秒（ビルドを含む）。
- 判定: 66 点すべてが「判定不能」（差し引きが計時のぶれ以下）。退行の疑いはない。
- 記録: `tools/bench/results/2026-10-23-508a9b62-batch5-a2/`（手元の絶対パスは `<repo>` に伏せた）。
