# F1 の実装記録

基準 B: `b82caa092cb83c3ce058dd1ced2979cdf3548fea`（O2 取り込み後）。コミットと docs/todo の変更は行わない。

テスト作成時の関門の四問:

1. 公開の型検査・CLI の診断で型付き Fail とシグネチャ由来の NoFail を検査し、golden の実行・参照実行・独立 IR 検査・整形の比較で捕捉と再 raise を確認する。
2. Fail 内の代入漏れ、行への Fail の混入、節の E まで rigid にする誤り、節の再 raise を消す誤り、resume の許可を捕まえる。
3. 既存の通常の操作には固定 E と NoFail がなく、この契約を検査できない。新しい正負入力を既存の golden 実行器へ追加し、IR を改変する負例だけを独立検査器の境界に置く。
4. 本番の公開範囲・注入・フラグは増やさない。

## 実装した範囲

- 型引数付き EffectRef、標準の宣言表の Fail/raise、EffectSet の失敗型、Scheme の NoFail を接続した。名前の綴りではなく標準宣言の束縛で識別する。
- 型と行の代入、包含、失敗型の不変の単一化、具体化後の型・効果と期待型の検査を追加した。NoFail はシグネチャだけから計算する。関数型をエラー値とする場合には、呼び出しの解決の途中にも型と行の情報を伝える。
- Fail の節は E を固定し T だけを剛な型とする。IR の固定エラー型・操作の種類・継続の利用不能を独立に検査し、実行は既存の操作番号と非再開の経路を使う。VM の根や継続の保存領域は変更していない。
- E0513〜E0518、formatter、現行設計・英語リファレンス・生成 Skill をそろえた。golden は正例 1・負例 22 の計 23 件を追加した。関数型のエラー、Show のないレコード、再 raise、部分適用、パイプ、各種の行の違反を含む。型検査の別モジュールの正負、同じ綴りの利用者の操作、改変した IR も検査する。

整形の追加 case の四問: 型付きエフェクトの角括弧の空白と字下げを守る。ラムダの uses だけ AST の役割付けを辿らない退行を捕まえる。既存の表には型引数付きの効果参照がなかったため、その CASES へ入力と正確な期待値を足した。本番の差し込み口は増やさない。修正前の実テストの失敗と、修正後の成功を確認した。

## 完了の検査

同じ基準・名指しへ --dry-run を付けて選択を確認した。下記の最終 work と lint は、期待型の受け入れを補った最終の Rust の状態で実行した。検査後の編集はこの結果の記録だけである。

```sh
scripts/check.sh --level work --base b82caa092cb83c3ce058dd1ced2979cdf3548fea --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs,release_stack --test build_info --test call_allocations --test cli_process --test coverage_export --test desugar_export --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells
cargo clippy --all-targets
```

| 検査 | 終了 | 外側の時間 | 結果 |
|---|---:|---:|---|
| 最終 work F1 | 0 | 503.938 秒 | lib 1204 件成功、既存の ignore 21 件。全 36 統合ターゲット成功。fmt・規約・Skill 再生成の照合・仕様集計・release_stack 10 件成功。spec_examples/reference_examples/skill_docs は全統合に含め、重ねて実行しない |
| 最終 cargo clippy --all-targets | 0 | 5.504 秒 | 全ターゲットの lint 成功 |
| ローカルリンクと git diff --check | 0 | 1 秒未満 | Markdown のコードを除く 480 個のローカルリンクのパスに欠落なし。追加した見出しの参照も確認 |

作業中は関係する対象だけを実行した。主なコマンドは `cargo test -p benitoite --lib syntax::parser::types::tests`、`cargo test -p benitoite --lib failure_row_contract_survives_modules_and_higher_order_values`、`cargo test -p benitoite --lib failure_clause_error_type_kind_and_unavailable_continuation_are_checked`、`cargo test -p benitoite --lib deep_list_patterns_stay_within_the_normal_stack`、`cargo test -p benitoite --lib cli::tools::formatter::`、`BENITOITE_GOLDEN_FILTER=handlers/f1- cargo test -p benitoite --test golden golden_suite -- --nocapture` である。いずれも最終的に終了 0。最後の二つはそれぞれ 31 テスト・23 ケースが成功した。局所探索の外側の時間は未計測であり、最終の work と lint の外側の時間を上表に記録した。

## 失敗と修正・計画からのずれ

- R78: 既存の E0209 の回復診断を保持するため、二つ目以降の型引数付き参照は修飾名で書く。既存の assert と期待値は変更していない。
- R79: lint_default は依頼の all-targets と一致しないため除き、cargo clippy --all-targets を別に実行する。開始時に統合ターゲットを列挙し直し、計画の 36 件と一致した。
- R80: 最初の work（終了 1、44.805 秒）は、既存の深さ 450 のリストパターンでスタックオーバーフローした。単一化の効果制約の一時値を再帰の振り分けから補助へ分け、同じ深さ・通常のスレッドで成功させた。関数型の注釈の分岐も補助へ分けた。テストの深さ・assert・スタック設定は変更していない。
- スタックの修正後の work（終了 1、307.792 秒）は lib と 26 統合ターゲットが成功した後、新しい英語の例に output ブロックがないため reference_examples が失敗した。例に main と期待出力 3 を加えた。残りの対象と、その後の整形修正で古くなった対象だけを再実行した work は終了 0（214.906 秒）となった。ラムダの複数行の型引数の整形も、追加した CASES の修正前の失敗を確認してから補った。
- R81: 最後の照合で、純粋な値を Fail と未保証の Rest を持つ局所注釈へ流す入力が終了 0 となることを確認した。期待型を受け入れる位置に署名由来の NoFail の直接検査を加え、E0515 の golden を追加した。これが共有の注釈処理を変えたため、上表の最終 work と lint で全読者を再確認した。既に追加した組み込みの値の負例も、注釈の時点の正確な診断位置へそろえた。

変更後だけを測った結果で失敗が消えたことにはせず、上記のスタック・整形・期待型の失敗を実際に確認した。既存のテストの削除、assert の削除、期待の緩和、ignore の追加はない。Lean の規則・定理・仮定は変更せず、formal/ のビルドと全比較、全件の heap/stress、all-targets の test は実行していない。

## 後続への申し送り

- F2 は登録済みの標準 Fail/raise を使い、Failure.bnt に通常の fromResult/toResult を実装する。現在の標準表には未接続の toResult を置いていない。解放・タスク・lazy と局所特殊構成は F2 の割り当てに従う。
- F3 は EffectSet.failures、Scheme.no_fail、ClauseInfo/Clause.failure_type、OpDef.failure を交換の実データへ接続する。11/4 の Fail/NoFail の出力と CLI の入口の照合は、計画どおり後続へ残す。
- 版と訳の更新は V1 の担当へ残す。コミットと docs/todo の変更は行っていない。
