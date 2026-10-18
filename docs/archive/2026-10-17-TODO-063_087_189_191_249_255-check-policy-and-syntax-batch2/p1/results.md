# P1 の実装記録

基準 B: `04e82f6f8d7510b0aca968c4573fee0e249cd62e`（F3・RV3取り込み後）。コミットと docs/todo の変更は行わない。

## テスト作成時の関門の四問

1. 独立IR検査の効果包含、CLIのE0419・E0601、文字の網羅性・束縛・非選択・診断位置、範囲による実行と交換の契約を守る。
2. 脱糖がFailのhandleの本体の残りの効果を落とす、usesの重複を黙って除く、文字に無条件の残りの値を置く、サロゲートを不足とする、欄の相関・ガード・将来の構成子を失う、全域の範囲でコード生成が内部エラーになる退行を捕まえる。
3. 既存の表を拡張し、実ソースの診断は型検査境界、範囲と既定分岐の実行は既存のIRの差分実行境界、CLIの正確な表示はgolden、交換固有の欠落は実ソースから六入口への出力で確かめる。表層の型検査を通る正例だけではIRの誤った効果を捕まえられないため、IRの変異を一件加える。
4. 公開API・本番の差し込み口・フラグは増やさない。測定のexampleは一時的に配置して削除し、再現用のソースだけをp1へ残す。

## 実装と判断

RV3中1・軽1・軽2を最初に修正した。IRの変異テストは修正前に包含の欠落によってassertが失敗し、修正後に成功した。goldenの重複は同型でE0419、既存の異型のE0514は保つ。vm_handlersの既存の表は元の直接束縛で実行し、期待値を保つ。

文字の有効な値域全体を区間分割し、未被覆の文字を実在する最小の文字で表示する。全域を覆う範囲は単独と入れ子・束縛で受理し、ガード・複数欄の相関・将来の構成子は維持する。Integerは変更しない。判定の木は全域の文字だけ既定分岐なしで作れ、未被覆のコア入力を内部エラーとして拒否する。既存テストの期待の変更はR87の意味の変更によるもので、assertの削除・期待の緩和・ignoreの追加はない。

実ソースの文字全域の範囲と束縛を局所の交換へ加え、辞書・Fail・文字の六入口の比較と独立batch2入力を全比較のスクリプトに接続した。現行設計・英語の例・Skillの手書きの説明と診断の生成元をそろえ、gen_skillで再生成した。版と訳の更新はV1へ残す。

## 計画との差と途中の失敗

- R86: RV3の最初の修正をP1へ含めた。IRテスト準備のConsoleのimportと旧名printlnを修正した後、意図した欠落の失敗を確認した。
- R87: 文字全域と後続の `_` の期待を決定済みの新しい意味へ更新した。実ソースのRust文字列のUnicodeエスケープを修正した。範囲だけのshadowは従来のE0337なので、Pairの変数を実際に再束縛する対照へ変えた。
- R88: 自動dry-runの8単位からlint_defaultを除き、開始時の全36統合を名指ししたworkと、全targetのclippyを別に割り当てた。
- R89: 短い型検査測定を実施した。結果はtypeck-performance.mdと二つのCSVへ記録した。開始版にFailureモジュールがない入力は比較に含めない。RV3軽4の深い型の費用は未修正の観察として記録した。
- work初回は追加したリファレンス例に実行結果のブロックがなく停止した。検査だけのブロックへ変えた再開もmain不足のE0414で停止した。pureなmainを加えた後、reference_examplesを含む残り10統合ターゲット・後段の4単位だけを再開し成功した。lib・fmt・それまでに通った統合を重ねていない。goldenの新規spec印を実在する見出しへ直した後は、その一件だけを照合し、E0419と位置・削除案の期待が成功した。
- R90: 接続を閉じるため、01-12・07-04に残る段2の「未接続」の説明も実装へそろえた。formal/の規則・定理・公理・仮定は変えない。

## 作業末の検査

自動 dry-run は8単位を選び、R88の名指しの dry-run は7単位と全36統合ターゲットを選んで終了0となった。work初回はリファレンスの例で止まり、同じリファレンスの修正後にもmain不足で止まったため、未実行の部分だけを再開した。最終的に既定libは1,208件成功・失敗0件・既存ignored21件、全36統合ターゲットも成功した。fmt・ソース規約・生成Skillの照合・仕様集計・既定のLeanビルドも成功し、sorryはない。全targetのclippyは警告なしで成功した。

| 検査 | 終了状態 | 外側の時間 |
|---|---:|---:|
| work初回（reference_examplesのブロック指定で停止） | 1 | 293.459秒 |
| 残りの再開初回（同じ例のmain不足で停止） | 1 | 2.265秒 |
| 修正後の残りの再開 | 0 | 125.808秒 |
| cargo clippy --all-targets | 0 | 8.435秒 |
| scripts/check-formal.sh全体 | 0 | 972.693秒 |

実行した主なコマンドは次のとおりである。work-command.txt・work-resume-command.txtとcheck-times.jsonにも実引数を保存した。後の再開のdry-runも同じ指定で確認した。

```sh
scripts/check.sh --level work --base 04e82f6f8d7510b0aca968c4573fee0e249cd62e --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,formal_build --test build_info --test call_allocations --test cli_process --test coverage_export --test desugar_export --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells
scripts/check.sh --level work --base 04e82f6f8d7510b0aca968c4573fee0e249cd62e --only tests_related,source_rules,skill_generated,spec_tally,formal_build --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells
cargo clippy --all-targets
BENITOITE_DESUGAR_DIFF_DIR=target/p1-formal-desugar BENITOITE_COVERAGE_DIFF_DIR=target/p1-formal-coverage scripts/check-formal.sh
```

全比較は一度実行し終了0だった。通常の網羅性10,020件・view付き10,028件は、不一致0件・燃料切れ0件で一致した。L4bの文字の既知差は残らない。脱糖73,761定義、組み込みの効果要約72,736比較、プログラム内の22,456照合、表層の51,658件の一致を確認した。表層の既存の対象外19件とQ11の1件は分類・理由を維持し、不一致・準備失敗・lazy制約は0件だった。全1,770入力の固定manifest、単一表層検査、既存の17入力の失敗期待、名前・穴・パイプ等の変異の拒否、外部パッケージ、独立batch2入力と実ソースの辞書・Fail・文字の六入口も成功した。

manifestにはF1/F2/P1の29入力（受理3・診断による拒否26）を追加し、8定義・6表層検査・3照合を加算した。既存入力の振り分け・件数・対象外の理由は変更していない。追加分と既存の差がないことをmanifest-delta.jsonへ保存した。全件の書き出し中に完了済みのgolden部分のメタデータを照合し、最終の固定記録の照合より前にmanifestを更新した。後段のcheck_named.pyが更新後のmanifest全体を検証した。

件数はformal-summary.json、全比較のログはformal.log、workの各対象の終了状態はwork-summary.logへ保存した。基準・未コミット差分と未追跡入力のSHA-256、生成した交換入力と六実行ファイルのSHA-256はrelation-state.jsonへ記録する。判断者はCodex、日付は2026-10-18である。同じ作業ツリーで実行し、その後は結果の記録だけを追記する。別の状態へ引用するときはこれらの関係入力を照合する。

途中の局所検査は、IRの変異（修正前の失敗と修正後の成功）、p1-duplicate-failureのgolden、vm_handlers、character_・typeck::pattern・extensible_source_patterns_keep_package_and_nested_contextのlib、export_batch2_character、nonexhaustive_literalsとp1-characterのgolden、文字の局所六入口である。準備中の失敗と修正は上に記した。作業末にlib全件等を別途重ねず、失敗後は失敗した部分と未実行の部分だけを走らせた。新規goldenのspec印の訂正後も、その一件だけを再確認し成功した。

変更したMarkdownの相対ファイルリンク476件、check-formal.shのbashの構文、check_named.pyのPythonの構文を確認した。最終のgit diff --checkも成功した。本番Rustは99行追加・32行削除、同居するテストとtests/testdata（Pythonとmanifestを含む）は1,035行追加・19行削除である。既存のテストの削除・assertの削除・ignoreの追加はない。

## 後続への申し送り

189・249・191の段3〜5のRust/Leanの接続を閉じた。Integerの全域判定は従来のままであり、TODO-191の全体の閉鎖は行わない。G1a以降へ進める。RV4、版と訳・CHANGELOG全体の整理、changeと公開候補の照合は後続の担当である。

RV3軽3の短い測定では、900呼び出しの型検査は開始版24.279ms、現在版47.784ms（約1.97倍）、現在版でFailureを取り込む場合60.107msだった。3種類の入力だけで二乗の増加とは断定しない。最適化の採否と軽4の深い型の費用は取りまとめへ残す。測定条件・制約・入力と生の標本はtypeck-performance.md・typeck_probe.rs・二つのCSVに保存した。

G2〜G4とV1で標準宣言・例・生成物が変わるため、P1の成功を最終状態へ無条件に引用しない。移行の分類と外部利用者向けの処置はmigration.mdに記した。コミットとdocs/todoの変更は行っていない。
