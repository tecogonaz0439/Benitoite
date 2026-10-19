# H1: docの元位置と共通の例の抽出

基準のコミット（B_WORK）は `caac60a21c77d7d643ea24f2710f94302fe7579a`。開始時の差分はない。コミットとdocs/todoの変更は行わない。

## 変更

DocComment.textの既存の内容を保ち、各行の結合本文内の範囲・元の接頭辞とCRLF/LFを含む範囲・接頭辞だけを除いた本文の範囲をDocLineへ保存した。実行用に抽出するときにだけ一空白と改行を正規化する。元ソースへ戻す表の検索は二分探索とし、例ごとの表の切り出しでは各断片の両端を直接変換する。一つの表の切り出しで、断片ごとに元表全体を検索する二乗の処理を避けた。

cli/tools/doc_examplesへ読み取り用の共通APIを加えた。四モード、出力の最終改行、stderr省略時の空、diagnosticの非空行の包含とコメントでの実在Eコードを扱う。形式不良はE0260として元コメントに位置を付ける。モジュール・公開/非公開の宣言・構成子・欄・型クラスのメソッド・実装の関数・エフェクトの操作を元位置順に一度ずつ収集する。import先を辿らず、元モジュールの宣言を例へコピーしない。

仮想入力の一次・補助位置と履歴を元コメントへ戻し、対応しない合成範囲は例全体へ戻す。コメントを対象に含む修正案は案全体の自動編集を外し、説明を保つ。別ファイルだけの修正案と位置は保つ。tests/doc_examplesは同じ抽出・期待型を使い、filesのアダプタと既存の実行器を残した。従来の閉じ忘れのassertは、共通抽出の成功を要求する同じ検査としてMarkdownアダプタに残した。

01-01・01-02・02-02と07-04の外側の対応を更新した。Skillのdoc表示は一空白だけを除いて字下げを保ち、gen_skillで診断の生成文書を更新した。標準ソース・正式モデル・型付き表層・GC/VMの意味は変えない。

## test-auditの作成時の四問

1. 共通抽出の公開APIで、四モードと期待の解釈、形式不良の診断、UTF-8の元位置、全種類の付属docの収集を守る。通常testの入口では、docの不正な印を実行用に解析しないことを守る。
2. 本文の字下げや最終改行の喪失、stderrの省略の誤解、Eコードの検査漏れ、CRLFやUnicodeでの位置のずれ、補助位置の仮想番号の残存、コメントを壊す編集、非公開/メンバーdocの抽出漏れで失敗する。
3. 新しい抽出と位置表の契約は既存のMarkdown実行器では観察できないため、本体の公開境界に6件を置いた。通常testの非抽出は別のCLI契約として1件を置き、Skillの字下げは既存テストへassertを足した。既存のassert・期待・ignoreを弱めない。
4. テスト用の公開口やフラグは足さない。公開APIはH2のtest_runnerと既存のMarkdown検査が使う読み取りの境界であり、字句・構文解析も本物を接続する。

## 局所の検査

- `cargo test -p benitoite --lib cli::tools::doc_examples::tests`: 初回は新規のUnicodeの列番号の手計算（30）が実際の32と食い違い、5成功・1失敗。新規の期待を32へ訂正し、位置表の検索・切り出しを整理した後は終了0、6件成功（0.01秒）。
- `cargo test -p benitoite --test test_command ordinary_test_does_not_parse_documentation_examples`: 終了0、1件成功（0.08秒）。
- `cargo test -p benitoite --lib cli::tools::skill::generate::tests::doc_lines_lose_leading_spaces`: 終了0、1件成功。既存の期待を保ち、フェンス内の字下げと空行のassertを追加した。
- `cargo run -p benitoite --example gen_skill`: 終了0。編集としてのcargo fmtも終了0。

局所検査の外側の時間は未計測。上の秒数はテスト部分の表示である。

## 作業末の検査

R176に従い、ASTの大きさ変更に対するrelease_stackを通常のwork相当の指定へ加え、dry-runで選択と重複の省略を確認してから一度実行した。外側の時間は/usr/bin/time -pで計測した。

| コマンド | 終了 | 外側の時間 | 結果 |
|---|---|---|---|
| `scripts/check.sh --level work --base caac60a21c77d7d643ea24f2710f94302fe7579a --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,release_stack --test '*' --dry-run` | 0 | 未計測（1秒未満） | fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally・release_stackを選択。spec_examplesは全統合に含まれるため重複を省略 |
| 上と同じwork（--dry-runなし） | 0 | 519.57秒 | lib 1217件成功・既存ignore 21件。39統合ターゲットは297件成功・既存ignore 8件。局所release_stackは所定の10件成功。fmt・通常lint・規約・生成Skill・仕様集計も成功 |
| `cargo clippy --all-targets` | 0 | 12.71秒 | example・binを含む全ターゲットのlint成功 |

workは `cargo test -p benitoite --lib`、`cargo test -p benitoite --test '*'`、`cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep`、`cargo fmt --all --check` を各一度実行した。spec_examples・reference_examples・skill_examplesとtest_commandはこの全統合に含む。release_stackの最適化構成は成功10件・失敗0件であり、実行部分21.04秒である。workの再実行や失敗後の補完はない。作業末の検査枠の外側の時間は計532.28秒。

変更した現行設計4ファイルの相対リンクを読み取りで照合し、存在しない参照先は0件であった。git diff --checkも終了0。最終の結果記録以外のコード・生成物は、検査開始後に変更していない。正式モデルのformal/は変更しておらず、lake build・gc-stress・change・全形式化比較・公開候補のreleaseは実行していない。局所release_stackの成功を公開の受け入れ完了とは扱わない。

テストを削除していない。既存のassert・期待値・ignoreを保ち、Markdownの閉じ忘れのassertを共通抽出の成功を要求する形で移した。新規テストは本体の抽出境界に6件、通常testのCLIに1件である。本番Rust（単体テスト部分を除く）は621行追加・8行削除、テスト（Markdownの共有アダプタを含む）は391行追加・122行削除である。削除したアダプタの抽出・期待型は本体へ移し、実行時の照合のassertと既存の例の期待は保った。

## 計画との差と申し送り

開始版・DocComment.textの互換を保つ正規化の時点・修正案の扱い・release_stackと追加clippyをR176へ記録し、planのH1行も同じ指定にそろえた。H2はextract(module)の同じ一覧と各DocExample.source/expectation/span/source_mapを、仮想モジュールの読み込み・事前許可・実行・報告へ接続する。map_diagnosticには実際の仮想FileIdを渡す。--docのCLI・実行・機械可読報告は本作業では接続していない。H3の標準docの代表例と件数、V1の訳、取りまとめのchange・全形式化比較・releaseは各担当へ渡す。
