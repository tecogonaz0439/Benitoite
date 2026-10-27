# R08 の作業結果

2026-10-24。基準 B_WORK と着手時の HEAD は `a4d4990712233357a456c5ff112fb1b430464ac8`、ブランチは `mod012/R08`。着手時の差分はなかった。R01〜R07 の実装・現行文書・先行結果を D9〜D14 と照合し、[集約結果](../results.md#r08-相乗りの接続の照合)と [独立レビュー依頼](../reviews/RV-R08-request.md)へ引き渡しを記録した。

## 実行した検査

コマンドは明示した Lean ビルド以外、リポジトリの根で実行した。各コマンドに `/usr/bin/time -p rtk proxy` を付け、外側の実時間を採った。表ではこの共通部分を省く。`<tmp>` はリポジトリ外の一時ディレクトリであり、静的点検のためだけのスクリプトを置いた。局所検査は今回の接続確認として新たに実行し、先行結果を引用して検査を省いたものではない。

| コマンド | 終了状態・結果 | 外側の実時間 |
|---|---|---:|
| `scripts/check.sh --level work --base a4d4990712233357a456c5ff112fb1b430464ac8 --dry-run`（着手時） | 0。差分なし、検査対象なし | 0.07秒 |
| `cargo build -p benitoite --bin benitoite --example derive_inventory` | 0。実 CLI・inventory のビルド成功 | 3.16秒 |
| `python3 -B scripts/check/test_policy.py` | 0。22テスト成功。新水準の対象選択、三シェル構文、旧 only/full の固定記録等を検査 | 17.66秒 |
| `python3 -B tools/derive/test_derive.py` | 0。実 inventory・formatter・通常 check/test を使う49テスト全て成功。事前拒否と非書き込み、Show/Order の受理、複数対象、空設定、対象外の依存先、receipt 復旧・再適用・旧版拒否を含む | 85.18秒 |
| `cargo test -p benitoite --test property_library --test reference_examples --test skill_docs --test skill_examples --test spec_examples --test stdlib_doc_examples` | 0。順に15/1/8/3/7/1件、計35件成功・失敗0。Property の長いテスト2件は既存の ignore のまま。仕様例・英語/Skill の Writer/JSON 例・標準 doc の公開関数例と生成文書を検査 | 33.86秒 |
| `cargo test -p benitoite --test desugar_export batch3::export_batch4_log_standard` | 0。1件成功、他の30件はフィルタ対象外。公開関数の直接呼び出しを含む入力を VM/参照評価の Direct/Request で比較し、既定の g2 へ五形式を書き出し | 2.54秒 |
| `cargo run -p benitoite --example gen_skill` | 0。生成参照と bundle を再生成し、再生成後の git diff は差分なし・終了0 | 0.77秒 |
| `lake build`（`formal/` 内） | 0。既定ビルド成功、296 jobs | 0.15秒 |
| `python3 -B crates/benitoite/tests/desugar_export/check_batch3.py --rust-dir target/formal-batch3/g2 --report target/formal-batch3/g2-exchange-results.json` | 0。今回書き出した1入力・11定義で六入口が一致 | 0.23秒 |
| `python3 -B <tmp>/benitoite-r08-doc-check.py`（記録作成前） | 0。現行文書13点と集約結果の計14文書、相対リンク/アンカー363件、フェンス、末尾空白、手元の絶対パスと非公開文書へのリンクの不在を確認。英語/Skill の Log 節、版7件の対応、01-03の一般規則、旧固定記録・登録表/help・Lean の B0 からの不変も確認 | 0.16秒 |
| 同じ静的点検（記録作成後） | 0。追加した本記録とレビュー依頼を含む16文書、相対リンク/アンカー371件を確認 | 0.18秒 |
| `scripts/check.sh --level work --base a4d4990712233357a456c5ff112fb1b430464ac8 --dry-run`（作業末） | 0。文書3ファイルの差分だけで、自動検査対象なし | 0.10秒 |
| `scripts/check.sh --level work --base a4d4990712233357a456c5ff112fb1b430464ac8` | 0。計画の「記録だけ」の指定を一度実行。文書だけで検査対象なし、selected checks passed | 0.08秒 |
| `git diff --check` | 0。追跡ファイルの差分の空白検査に成功。未追跡の本記録・レビュー依頼の空白は上の静的点検で確認 | 0.05秒 |

方針自己検査・derive 自己検査・Cargo の関連テストは、互いに入力を書き換えない独立のプロセスとして一部並行で実行した。時間は各コマンドの外側の実測であり、その和を R08 全体の経過時間とはしない。失敗はなかった。新しい Rust/Python のテスト、検査用の本番の差し込み口は追加していない。

作業末の work の実行後に加えたのは、上表の終了状態・時間の記録だけである。処理系・検査入力は変更しておらず、work や局所テストの再実行は不要と判断した。

## Log の今回の局所比較

入力は `crates/benitoite/tests/desugar_export/batch4/log-standard.bnt`。`BENITOITE_DESUGAR_DIFF_DIR` は未設定とし、既存の g2 manifest と既定経路を使った。今回の書き出し・既定 Lean ビルド・比較の順に実行した結果であり、古い target の出力だけを根拠にはしていない。

| 入口 | 件数と結果 |
|---|---|
| coverageDiff | 1件一致、不一致0、fuelExhausted 0 |
| coverageProgramDiff | 1件一致、不一致・対象外・fuelExhausted は0 |
| desugarDiff | 11定義一致、不一致・対象外・除外は0 |
| builtinCheck | 1入力、94 summary comparisons、summaryMismatchCount 0、errors なし |
| surfaceCheck | 1入力・11定義、ok true |
| surfaceCheckAll | 11件一致、不一致・対象外・q11・lazyRestriction・preparationFailure は0 |

五形式の SHA-256 は次のとおりである。

| ファイル（`target/formal-batch3/g2/` 内） | SHA-256 |
|---|---|
| corpus.json | `f8abe9504fe8e7e5c85e93a2ed247eeb53b7fe62a839c132a690bc25a83a88c6` |
| builtins.json | `05ea9dfc536f6dfa9443d3133d407df30f39c9b70d1b54ca4b3e7d3db222cf68` |
| stdlib.json | `823f42d8f9147147a0705160fd151c91bfff65d66e198f19c2f1fc3bc5f41d42` |
| coverage.json | `85ad908a217046d0c3c12f078e125efdafe4f4d42b1473476f4f84a66bae5441` |
| coverage-program.json | `5ad372a7d061266ec749a5a6a44ac302e066c61bbd9d651ad9285d0eac4db069` |

## 計画からのずれと申し送り

- R08 の指定範囲内であり、変更は本改造の集約結果・本記録・レビュー依頼の三文書だけである。必要な関連文書の修正、Rust/Lean/生成器/検査方針/テストの修正はなかった。作業末の work は計画の「記録だけ」の指定を使い、Rust の全 lib・lint・特殊構成を足さない。R08 の完了条件に従って、既存の自己検査と文書例、生成参照、Log の局所比較を直接実行して接続を確認した。
- R03 の受理入力10ケースの旧新の本文・意味ハッシュ・記録の一致と、R05/R06 の結果は先行記録として照合した。旧新比較自体は R08 で再実行しておらず、新たな測定結果や stage への引用にはしない。D11 の版定数・現行文書・既存記録の検査との矛盾は見つからなかった。
- S-R2/S-R3 は集約結果に取りまとめの実行記録がある。S-R1 の証拠は、R08 が直接実行した方針自己検査22件である。R01 の work 結果の引用ではない。stage の入口と dry-run は通していないが、選ぶ単位と中身は同じであり、S-R1 の追加実行は不要である。独立レビューと stage の受け入れは取りまとめの担当であり、依頼記録を用意した。
- 言語規則・Lean の主な定理の前提/結論の変更、公理の追加が必要な点、担当範囲の未解決の検査失敗はない。JSON の形式は利用側の例であり、Log→Json の依存や専用ハンドラは加えない。実行時の権限制御を実装したとは扱わない。
- 日本語訳は計画どおり Z01a で同期する。derive の現行版・事前拒否と対処・復旧の順序、および Log の二例とその限界を英語版へそろえる。06-06・03-08 の訂正に対応する訳の有無と、Skill の主語の明示も確認する。U01 は後続の新しい警告の厳格モードへの影響を別途棚卸しする。R08 の結果は改造全体の change・最終の形式化比較・release の完了を示さない。
- private/ とそこを指すスキルのリンクは読んでいない。git は状態・差分・旧ソースの読み取りだけに使い、add・commit・branch・merge・stash・reset・checkout 等の変更操作は行っていない。
