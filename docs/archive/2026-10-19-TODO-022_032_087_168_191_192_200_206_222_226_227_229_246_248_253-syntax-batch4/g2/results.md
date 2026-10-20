# G2 の実装と検査

基準B_WORK: `367ef0268ed92d6ee8b0b751be32f6c02ddaf8ff`（開始時のmerge-base）。コミットとdocs/todoの変更は行わない。

新しい実行入力は属性20件以下、sink3件以下、handleの入れ子3以下とする。既存のVM局所と指定統合は先行作業のstress用サイズを保つ。出力の待ちは一つの文字列で既存バッファの1 MiB上限を越える必要があるので、リストや再帰を増やさず2 MiBの文字列二件を使い、stressでも同じバッファ境界を検査する。

## 実装

Log.bntにToLogValueの12実装、attribute、debug/info/warn/error、withAttributes/withTextLogger/withSinksを追加した。幅付き整数とByteはIntegerへ、Float32はFloatへ損失なく広げ、UnsignedInteger64はUnsignedIntegerの値を保持する。通常のhandle・節・resumeとエフェクト行を使う。

既定emit/enabledを既存のIO処理へ接続した。ハンドラ探索を終えて未処理の操作だけがこの入口へ来る。Info以上の記録を、非公開の純粋な書式関数で整形し、改行を含めて既存のstderrバッファへ一度渡す。JSONの引用処理、文字列上限の検査、既存の待ち・中断・最後の書き出し・R0202を共有する。参照評価も既存BuiltinBridgeから同じ既定処理を使うので、VM/参照評価の振り分けや新しい根の仕組みは加えていない。

現行設計03-07・02-08/09・06-04、07-04の対象外の対応表、生成Skillを更新した。07-04では通常の型付け・ハンドラの例の保証と、Rustの書式・実IOの検査を区別した。formalの定義・主定理・公理・Assumptionsは変えていない。

## テストの作成時の関門と途中の検査

書式・水準・属性の順序/重複・捕捉の一回性・送り直し・sinkの列順/空列/enabledの論理和・sinkのFailの後続未実行をio_modesの公開入口へ集めた。既存のLogはG1で宣言と明示ハンドラだけであり、既定処理・標準補助・sinkを検査していなかった。runtime_builtinsでは実行時の変換の値と引数の一回評価、writerをidleまで止めた状態のバッファ待ちと出力順、実際の出力先の失敗とR0202/終了1を検査する。実装の私有関数やテスト専用の本番APIは使わない。declarationsは外側効果の静的な拒否を、test_commandはJSONのstderr欄の捕捉を、cli_processは別プロセスの実CLIを担当する。desugar_exportは通常の型/脱糖/標準宣言の交換と独立参照評価への接続を担当し、書式の期待を重ねない。

途中はtest_commandのlog_handlers_receive、io_modes/runtime_builtins/declarations/test_command/cli_processのlog_、desugar_exportのexport_batch4_log_standard、runtime_builtinsのlog_large_recordsだけを直接実行した。最終の局所実行はいずれも成功した。局所試行の外側の時間は一括計測していない。試行中にListの旧名concat・lambdaのラベルsinkを現行のconcatenate・valueへ直した。既定書式の試行で既存Float表示のNaN/Infinityとの不一致を検出し、Logの契約のnan/inf/-infへ直した。新規の失敗テストの初期期待はstdoutのR0201を誤用していたため、既存Consoleのstderrの厳密なR0202へ修正した。test実行器の試行では存在しないshow-outputオプションを使っていたため、既存のJSON報告のstdout/stderr欄の厳密な比較へ直した。既存のassert・期待・ignoreは弱めていない。

## 計画からのずれ

R191に、非公開の共有書式組み込み一件、Byte/狭い非負整数の広げ先、組み込み登録の厳密な件数の更新、lint_defaultを全ターゲットclippyへ置き換える判断を記した。組み込み表の変更は末尾の部分3→4、全489→490、権限別[414,16,59]→[415,16,59]であり、既存の厳密なassertを維持している。

## 作業末の検査の進行

G2行を固定した同じ基準のdry-runで確認した。spec_examples/reference_examples/skill_docsは全統合のtests_relatedに包含されるため、check.shの重複の省略に従った。最初のclippyは成功し、workはfmt成功後、lib全件の1242成功・4失敗・既存ignore21件で止まった。失敗はR192の四件であり、個別に修正確認を通した。typeckの一件の成功は `cargo test -p benitoite --lib typeck::traits::tests::standard_library_sources_and_dictionary_contracts -- --nocapture`（終了0、外側の一括計時なし）、ほか三件の終了状態と時間はcommands.jsonlへ記録した。

resolveの修正確認では、最初に存在しない定数名を使ったコンパイル誤りと、名前解決時のソース宣言をBuiltinEffectと誤認した期待を、実際のEffectへ直した。続くclippyがCopyの型へのcloneを拒否したため、その不要なcloneだけを除いて成功を確認した。いずれも本番の振る舞いは変えていない。成功済みのlib全件を繰り返さず、fmt/lintと未実行のwork単位を同じ基準で続行した。

## 作業末の最終結果

作業末の指定をすべて完了した。全統合40ターゲットは340成功・既存ignore9件、doc_defaultはcompile_failを含め34成功・既存ignore1件であった。lib全件の最初の1242成功に、修正した四件の個別成功を合わせ、対象の1246件を確認した。全ターゲットclippy、fmt、source_rules、skill_generated、spec_tallyも成功した。spec_tallyの未記入の初回リリース受け入れ条件はなかった。

補完のheap-verifyとheap-verify+gc-stressは、それぞれvm::の局所lib160成功・既存ignore6件、io_modes/runtime_builtins/vm_handlersの三統合ターゲット27成功・ignore0件である。全lib・全統合の特殊構成やcheck-heap全体は追加せず、G2の名指しの範囲を守った。GC本体・障壁・根の仕組みは変えていない。

次の表はPythonのmonotonicで計ったコマンド全体の外側の時間である。コマンドの完全な引数は[commands.jsonl](commands.jsonl)に保存した。最初のworkは[work.log](work.log)、未実行分への続きは[work-rest.log](work-rest.log)に残した。dry-runは最初のworkと同じ基準・指定、およびlibを除いた継続の指定へそれぞれ--dry-runを付け、名指しと重複の省略を確認した。

| コマンドの識別 | 終了状態 | 外側の時間 |
|---|---:|---:|
| clippy（最初） | 0 | 5.611秒 |
| work | 1 | 96.736秒 |
| fix-codegen | 0 | 0.192秒 |
| fix-modules | 0 | 0.112秒 |
| fix-resolve（最初） | 101 | 0.214秒 |
| fix-resolve（修正後） | 0 | 4.801秒 |
| clippy（テスト修正後） | 101 | 3.179秒 |
| clippy（不要なcloneの除去後） | 0 | 3.034秒 |
| work-rest | 0 | 411.600秒 |
| heap-vm | 0 | 42.860秒 |
| heap-integration | 0 | 74.452秒 |
| stress-vm | 0 | 44.814秒 |
| stress-integration | 0 | 32.596秒 |
| exchange | 0 | 1.069秒 |

計測した作業末の合計は721.270秒である。実装と途中の局所試行、上に明記したtypeckの局所修正確認はこの合計に含めていない。生成は `cargo run -p benitoite --example gen_skill` で行い、workのskill_generatedで再生成が差分を増やさないことを確認した。

## 局所交換と申し送り

workの `export_batch4_log_standard` が `target/formal-batch3/g2/` へcorpus13/sidecar5の五形式を書き出した。最後に `python3 -B crates/benitoite/tests/desugar_export/check_batch3.py --rust-dir target/formal-batch3/g2 --report <D>/g2/exchange-results.json` で再照合した。固定manifestのg2は1入力10定義・表層10件・Coverage単体1件・プログラムCoverage1件を要求し、coverageDiff/coverageProgramDiff/desugarDiff/builtinCheck/surfaceCheck/surfaceCheckAllの六入口で一致した。不一致・対象外・除外・燃料切れは0である。標準宣言・通常の操作と完全なハンドラ・送り直し・標準補助の署名・外側効果・展開済み位置を通し、同じ入力のVMと独立参照評価も両IO方式で一致した。入力ハッシュと報告は[exchange-results.json](exchange-results.json)、集約は[局所の接続記録](../results.md)に保存した。

G2を完了した。G3以降はLogの既定処理と標準補助が接続済みの状態から進められる。版上げ・英日リファレンスと手書きSkillの翻訳・改造全体のchange/release・全形式化比較は計画どおり後続へ残す。今回の局所成功をそれらの完了とは扱わない。コミットとdocs/todoの変更は行っていない。

Rust/BNTと交換manifestの差分は、本番280行追加・9行削除、テスト538行追加・9行削除である。新規の独立入力63行も含む。テストの削除行は既存の期待の差し替えであり、テストの削除や新しいignoreはない。テスト専用の本番APIも追加していない。
