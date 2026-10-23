# 作業 F5 の結果

2026-10-23。基準 B_WORK と開始時の HEAD は `b621fa1a86ce75191ab7ef4564441e61adbbceb6`、ブランチは `mod011/F5` である。git の変更操作、private の読み書き、処理系の src の変更は行っていない。

## 変更と作成時の関門

Rust の補間の交換出力を corpus 14 / sidecar 6 とし、書式付きの String を含む `formatted`、解析済みの七指定、省略を保持した。通常の Rust 出力を読む検証器と exchange/routing manifest も新しい世代にそろえた。独立した Coverage の全件入力は従来の版4を保つ。

新しい局所入力は全14型と追加の11書式、書式なしとの混在・連続補間、ファイル uses と個別 uses の同等な二入力である。独立した25関数の表層・コアと比較し、実際に出力した表に14の頭がそろうことを確認する。既存のランタイムテストは交換の読み落としを検出しないため、この契約は交換の境界で検査する。期待コアは Rust の脱糖から作らず、既存の手書き入力を用いる。本番の差し込み口は追加しない。

Lean の Convert では指定型に対応する `%Format.<型名>` と型・エフェクト引数なしの primName を要求し、E2 の準備では同じ入力の組み込み表への登録を検査する。主定理の前提・結論、公理、Builtins.Assumptions は変更していない。07-04 の表記と小例の参照先も直した。

## 実行した検査

| コマンド・対象 | 終了状態 | 外側の時間 |
|---|---|---|
| `cargo test --test desugar_export export_batch5_formats -- --nocapture`（rtk 経由） | 0、1件成功 | 未計測。テスト本体0.66秒 |
| `python3 -B formal/tests/test_batch5_exchange.py Batch5ExchangeTests.test_formatted_head_identity_and_membership`（変更前の既存 Lean 実行器） | 1、5変異が期待した準備段階の拒否にならないことを再現 | ツール呼び出し約0.5秒、Python 内側0.421秒 |
| `cd formal && lake build desugarDiff builtinCheck surfaceCheck surfaceCheckAll coverageDiff coverageProgramDiff` | 0 | 外側は未計測 |
| `python3 -B formal/tests/test_batch5_exchange.py --rust-dir target/formal-batch5` | 最初は1、新規 manifest の独立網羅性の件数を3と誤記。既存書き出しはワイルドカード1件であり、1へ修正して0 | 外側は未計測。再実行の独立検査8件は1.897秒 |
| `scripts/check.sh --level work --base b621fa1a86ce75191ab7ef4564441e61adbbceb6 --test desugar_export --test coverage_export --dry-run` | 0 | ツール呼び出し約0.1秒 |
| 同じ指定から `--dry-run` を除いた work（初回） | 1、clippy が新規テストの不要な参照を2箇所検出 | 7.996秒 |
| 不要な参照を修正した同じ work | 0 | 115.767秒 |
| `scripts/check-formal.sh`（K1、出力先は `target/f5-k1/{desugar,coverage}`） | 0、六入口・独立入力・全定義・manifest の全比較が成功 | 1,009.203秒（約16分49秒） |
| `target/debug/benitoite check crates/benitoite/testdata/patterns/match_on_error_type.bnt` | 既存の E0401 と独立した E0601 を確認。先に誤った `--diagnostic-format=json` を付けた呼び出しは引数エラーであり、通常CLIで再実行 | ツール呼び出し約0.1秒 |
| `bash -n scripts/check-formal.sh`、`git diff --check`、07-04 の相対リンクのファイル・フェンス・末尾空白の静的確認 | 0 | ツール呼び出し約0.1秒 |

work は既定 lib 1,271件成功・21件 ignored、coverage_export 3件成功・1件 ignored、desugar_export 30件成功・1件 ignored である。fmt、clippy、規約、生成 Skill の照合、仕様集計、Lean の既定ビルドも成功した。全件の形式化書き出しを行う ignored の検査は K1 が担当する。

局所の Rust 入力は32定義・formatted 28箇所、書式付き String 3箇所、書式付き String の stringExpr への脱落0件である。全14の頭を出力された表で確認し、builtinCheck の名前と固定シグネチャの照合を通した。ファイル宣言と個別宣言では、宣言・NoFail・本体・組み込み表が一致し、双方をE2へ通した。apply の行パラメータは noFail=true である。

K1 は 1,790入力（golden 790・random 1,000）・73,840定義を照合した。脱糖は golden 1,062定義・random 72,778定義が一致し、不一致・対象外は0件である。組み込み表の要約比較は141,998件、不一致0件である。表層検査は51,729件成功、既存の対象外19件・Q11分類1件、不一致・準備失敗0件であり、既存の分類理由もmanifestと一致した。プログラム内の網羅性22,482件が一致し、独立した閉じた入力とview付きの網羅性全件も一致した。新しい局所32定義と追加されたgoldenの4定義はすべて対象内である。

件数・構成・ツールチェーン・終了状態・外側の時間と、全件および局所入力・manifestのSHA-256を [k1-summary.json](k1-summary.json) に保存した。一時ディレクトリのログだけを成功の根拠にはしていない。局所試行の一部は外側の時間を取り損ねたため未計測と記した。主要なworkとK1は外側を計測した。

## レビューの申し送りへの対応

- M1: Convert の名前・直接の primName の照合と、E2 準備の表への登録の検査を追加した。名前の違い・別名・通常関数・型引数・表の欠落を本物の入口で検査する。変更前の実行器で5変異の失敗を確認した。CheckExamples の typedInput に、名前を照合しない表層の小例である注記を加えた。
- L4・RV-F13 L7: Rust の登録表だけでなく、実際の交換ファイルの14頭を独立した期待集合と照合し、Lean の builtinCheck も通す。F3の結果は引用していない。
- L5: Exchange/Syntax・Builtins・CheckInput の宣言型と Rust の書き出しを読んだ。利用者の名前は name 等の文字列値、names 等の配列、supers/dictParams 等の組の配列に入る。名前がオブジェクトのキーになる辞書欄はない。Rust の annotations のキーも &'static str の固定分類であり、利用者の名前ではない。したがって Version.lean の全木での rejectFields を変更しない。
- L6: Rust 入力の照合モードで書式付き String の保持と脱落0件を検査し、結果を出力する。
- L1〜L3: 07-04 の句点の後の半角空白を除き、固定シグネチャ・書式化の内部頭・読み取りにそろえた。用語集の「書式化」を使い、小例の位置を CheckPredicates.lean の FormatExamples と明記した。

## 計画からのずれと後続への申し送り

F4bの既存入力 formatted_interpolation_order.bnt の追加を、routing と exchange manifest に反映した。増分は1入力・4定義であり、既存の対象外の分類・網羅性の期待件数は変更していない。C2で既に追加された match_on_error_type の独立した E0601 を、元の E0401 に加えて両manifestの除外理由へ追記した。既存の .diag.json と通常CLIの実出力で2診断を確認しており、検査エラーによる除外という分類・件数は保つ。

通常の Rust 出力を14/6へ切り替えるため、既存の第2・3弾の Rust 出力モードと不正な版の検査も追随させた。数と幅のランタイム本体を変えず、局所 heap/stress と性能測定は追加していない。実装判断の停止事項はない。

K1 と manifest の最終照合は終了0で完了した。段 S-F の引用可否と受け入れ、独立レビューは取りまとめが担当する。今回 src は変更していない。G1・Z1、版上げ、commit・取り込み・docs/todo・公開操作は担当外である。
