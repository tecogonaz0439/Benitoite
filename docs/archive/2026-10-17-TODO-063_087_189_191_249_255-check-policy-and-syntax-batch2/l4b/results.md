# L4b 交換11/4・六入口と段2の回帰

2026-10-18追記: R66・R68の取りまとめの判断を反映し、L4bc2の修正後の旧出力の全比較をL4bc3で一度実行した。文字以外の比較は一致し、文字の全不一致がcharacterの型を含むことを機械的に確認した。L4bの実装側の関門は判断後の条件で完了した。RV2の独立レビューは取りまとめへ残す。[L4bc3の結果と続行先](../l4bc3/results.md)。以下は初回の停止時の記録として保つ。

区切りで止めて報告する。L4bの実装と独立入力はできているが、旧Rust出力との全比較が文字の不一致を検出し、planのL4bの停止条件に当たった。L4bとRV2を完了とはしない。既定のlake buildはsorryなしで成功している。

基準BはL4a取り込み後の `affb710656ee011d1a49dd75f993d536dfd237c6` に固定した。コミットとdocs/todoの変更は行っていない。

## テスト追加前の四問

1. 守る契約は、五形式の11/4の必須情報を六つの実CLIが保持・検査すること、旧版への新情報の混入を拒否すること、独立した期待コア・NoFail・網羅性に一致することである。六入口の終了状態と報告を境界にする。
2. Fail内部を読まない、異なるエラー型を落とす、NoFailを本文から補う、辞書の宣言位置や節の所属を混同する、直接呼び出しと値化の潜在効果を取り違える、旧版の未知の欄として新情報を読み捨てる退行を検出する。
3. 既存の交換テストはcorpus8/9/10・他四形式2/3であり、11/4の欄を持たない。CLIの実行の準備をtest_named_exchange.pyと共有し、新規入力は必要な実装一件と新契約の六定義へ絞った。元の旧版のテストは変えていない。--rust-dirの出力不在も失敗とし、未接続のRustを成功扱いしない。
4. 本番の公開範囲・フラグ・差し込み口を増やさない。本物の六入口を使い、期待コアと判定は手で定める。PythonはRustの局所出力を読むだけで、Cargoを再起動しない。

## できたこと

- Exchangeの型と効果を相互再帰にし、Failのエラー型、標準raise・非再開の捕捉、辞書付きの操作、節の辞書の所属を変換・書き戻しへ接続した。有限支持上の正規化を使い、名前・行・Failの並びと重複だけをそろえ、異なる型の欠落は不一致とする。
- corpus11/他四形式4を追加し、corpus8/9/10・他四形式2/3を維持した。新欄の混入・必須欄欠落・Bool以外のNoFail・行の個数と範囲・辞書の型番号・節の個数と所属を拒否する。署名からQを再計算して照合する。表層の単一FailとReleaseの複数Failの上限を分けている。
- 五つの独立JSONとtest_batch2_exchange.pyを追加した。手書きの七定義、coverage三件・coverage-program二件を六入口へ渡し、正例と変異した負例、異なるFailの欠落を確認した。O2/F3の--rust-dirの入力の五ファイルと版・入力名の契約も実装した。
- 交換契約、formal/README、07-04と01-12の接続状態の説明をそろえた。lakefileはすでに全六入口を含むため変更しない。01-12の規則・見出し・コード例は変更していない。Rustの処理系とテストも変更していない。
- Core・Release・Surfaceの主な定理と健全性11件、網羅性の定理、Builtins.Assumptionsに差分はない。READMEの30件の公理の確認で、propext・Classical.choice・Quot.sound以外とsorryAxがないことを確認した。独立レビューへ渡す照合資料は [review-notes.md](review-notes.md) に置いた。

## 途中の検査と修正

途中はExchange.Syntax・Exchange.Convert、読者を含む六入口だけをlake buildでビルドし、変更に関係するtest_named_exchange.pyの受理・契約名と新しい自己検査を実行した。最初の根からのlake実行はツールチェーンを選べずOperation not permittedとなり、formal/を作業ディレクトリにして成功した。相互再帰のAPI名・新構成子の分岐・ヘルパーの引数・初期の編集スクリプトの作業ディレクトリを修正した。

新規の手書きの期待コアでは、raiseを直接のCallHeadにせず、関数値を引数より先に評価する既存の間接呼び出しの定義にそろえた。opDictsは直接の頭ではlambdaEffectsを増やさず、値化で作るラムダの潜在効果だけを記録する。新規入力の件数情報と負例の拒否位置も実際の契約へそろえた。既存のassertの削除・期待値の緩和・ignoreの追加はない。

途中の試行の全経過時間は採取しておらず、結果の引用には使わない。

## 完了に向けて実行した検査

| コマンド | 終了状態 | 外側の時間・結果 |
|---|---:|---|
| `scripts/check.sh --level work --base affb710656ee011d1a49dd75f993d536dfd237c6 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.017秒。[選択の記録](dry-run.log) |
| 上記から--dry-runを外した指定 | 0 | 20.091秒。仕様網羅性の自己検査・集計、仕様例7件、六入口と全ライブラリを含む既定のlake build、sorryの拒否が成功。[workの記録](work-check.log) |
| `python3 -B formal/tests/test_batch2_exchange.py` | 0 | 6.073秒。7件すべて成功。[独立入力の記録](batch2-exchange.log) |
| formal/で `lake env lean /private/tmp/l4b_axioms.lean` | 0 | 0.689秒。30言明の公理を確認。[入力の控え](axioms.lean)、[記録](axioms-final.log) |
| `scripts/check-formal.sh` | 1 | 749.555秒。文字の網羅性・表層検査・manifestの不一致。[全比較の記録](formal-regression.log) |

公理の確認を最初に根から `lake -d formal env lean` として呼んだ実行は終了1、1.367秒だった。formal/を作業ディレクトリにした呼び出しで成功した。workの失敗ではない。実際のコマンド・時間は [timings.jsonl](timings.jsonl) に残す。

作業末のwork三単位と新規自己検査は各一度だけ実行した。Rustのソースとテストを変更していないため、lib全件・clippy・fmtは追加していない。指定のないcheck.sh全体とgc-stressは実行していない。01-12・07-04の最後の文章の修正は接続状態の説明だけで、検査が読むコード例・見出し・テストの印は変えていない。

## 不一致と停止理由

旧Rustのcoverageの通常入力は10020件中887件、view付きは10028件中886件が不一致だった。いずれも燃料切れは0である。確認した `golden/character` は反例表示の `_` と `\u{0}` の差、`boundary/surrogate` は全域後の分岐の非選択と必ず照合する束縛の差である。表示だけの差ではなく、網羅性・非選択・必ず照合の判定の差も含む。L4aで先行した文字全域のLeanの規則と、P1より前のRustの判定が一致しない。

同じ全比較で、脱糖はgolden 975定義・乱択72778定義が全件一致し、不一致0だった。組み込みの1352入力は欠落・宣言の誤り・要約の不一致0、プログラム内の網羅性22453件も全件一致した。既存の交換自己検査はwidth 4件・named 13件・extensible 22件・try 8件が成功し、Rustのcoverage_export 2件とdesugar_export 17件も成功した。

表層検査はmatched=51640・mismatched=12・outOfScope=19・q11=1・lazyRestriction=0・preparationFailure=0で、Q11の分類の一致はtrueだった。12件はハンドラを使う定義の `effect exceeds the allowed effect` であり、文字の表示の差と同一視しない。全12件の報告とc12-builtin-portの一入力分のcorpus・builtins・stdlibを [surface-mismatches.json](surface-mismatches.json) に保存した。原因は未確定であり、対象外への変更や期待値の緩和はしない。

最後のcheck_named.pyは `testdata/fmt/header.bnt` のroutingManifestの照合で止まった。実際のexcludedはE0908・E0910、固定記録はE0910だけだった。両辺を [routing-mismatch.json](routing-mismatch.json) に保存した。manifestを実出力へ機械的にそろえる変更は行わない。したがってper-program final exportsの照合全体は成功していない。

最小の再現例と実際の両辺の報告、全不一致の欄別の集計、元の報告のパスとSHA-256は [coverage-mismatches.json](coverage-mismatches.json) に保存した。一時的なtarget/のログだけを根拠にしていない。これは成功結果の別状態への引用ではない。

planのL4bの「corpusの比較が一件でも不一致」の停止条件に従う。旧入力を対象外へ逃がす、期待値を変える、差を無視して完了とする変更は行わない。受け入れ条件に文字の未接続をどう反映するかは [R66](../decisions.md#r66-l4bの旧出力の全比較で検出した文字の不一致) として取りまとめへ渡す。

## 残りと次に続ける手順

1. 設計者・取りまとめが、L4a先行とP1でのRust接続を前提に、L4bの旧出力の全比較の成功条件を決める。表層の12件とroutingManifestの差も別に調べ、必要な修正と再検査を割り当てる。L4bの範囲へRustの文字判定の実装を独断で取り込まない。
2. 独立したRV2最終レビューで、定義・言明・仮定と写し、今回の交換契約と実際の検査結果を照合する。実装者の自己点検をOpusのレビューの完了とはしない。
3. O2は11/4の版切り替えと操作の辞書のRust出力、F3はFailとNoFailの実値、P1は文字の判定・表示と三項目の全比較を接続する。[exchange-contract.md](exchange-contract.md) にファイル名・必須欄・局所出力を固定した。今回の旧出力の比較を、新機能のRustの証拠へ引用しない。

最終のローカルリンクの参照先184件は存在を確認した（0.003秒）。最初の簡易検査はコード中の型の記法をリンクと誤検出したため、コードを除いて確認した。`git diff --check` は終了0、0.025秒で成功した。
