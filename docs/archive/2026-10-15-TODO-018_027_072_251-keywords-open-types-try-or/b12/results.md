# B12 実装結果

## 変更と検査の分担

型保存では扱わない評価・停止・解放・報告の契約を、ソースから本物の処理系へ通す検査で補った。本番の実装、公開 API、Lean の規則と証明は変更していない。

| 契約 | 持ち主と確認する内容 |
|---|---|
| 入力の一回性・成功側の未評価 | `ir/desugar/die_tests.rs` の既存表を VM の Direct/Request でも実行する。State の出力が `1` で、停止する説明・Show を持つ Result.Ok と Option.Some が成功することを確認 |
| 説明→Show→exit の順 | 同じ表で説明の `1 div 0` と Show の `2 div 0` の停止理由・位置を対照にする。停止した場合は報告付きの exit に進まない |
| 純粋な説明・Show の一回性 | 既存の `die_failure_core_has_one_message_then_one_cause_and_canonical_exit` を維持。独立した期待コアと失敗側の let・成功側の本体・辞書・標準 exit を比較する。純粋な重複評価は結果だけでは区別できないため、実行検査だけに置き換えない |
| 原因と説明 | String の引用符・改行と引用符のエスケープ、None の固定原因、説明の無し・空・非空を参照側と VM の二方式で比較。Option.None の空の説明を既存表に追加 |
| ハンドラと State | `refinterp/exit_report_tests.rs` にソースの表を追加。失敗側の入力一回をハンドラから観測し、処理・再入・外側のハンドラ・その後の通常 exit が die 情報を残さないことを確認 |
| 再開・取消済み要求・競合停止 | 先行する独立コアとバイトコードの検査を維持。`exit_report_is_owned_only_by_the_default_call` は再開後の通常 exit、`competing_exit_reports_belong_only_to_the_selected_request` は二方式と配送順、`cancelled_exit_report_does_not_leak_into_a_later_exit` は旧 RequestId の再配送を確認。`request_exit_report_does_not_replace_an_adopted_stop` は中断・Internal・別の exit の採用を確認 |
| 子タスク・貸し出し中の Writer・取消し | `builtins/funcs/file/resource_tests.rs` の取消し入力の準備を共用する。第二の子タスクの die で全体を止め、第一の子タスクの書き込みの返却を待ち、資源を一回だけ解放して実ファイルへ転送する。取消した継続の出力がなく、仕事と要求が残らないことを二方式で確認 |
| flush 失敗・遅い中断・writer の panic | `runtime/run.rs` の既存表に通常 exit と die を追加。IO の失敗と転送中の中断では採用した終了状態と die 情報を保ち、writer の panic で Internal を採る場合は情報を捨てることを二方式で確認 |
| 実 CLI の報告順・状態 | `tests/cli_process.rs` で子プロセスだけのファイルサイズ制限を設定し、二つの実 Writer の解放を失敗させる。run では閉じたソケットへの最終転送も失敗させる。die→内側の解放失敗→外側の解放失敗→flush 失敗の文章/JSON と状態1を二方式で確認 |
| 実 test runner の継続・捕捉出力 | 同じ CLI 入力の `test` で、die 一回、解放の注記、捕捉出力の順を確認。JSON の既存の exit の分類・message・exitCode・notes と die、捕捉出力、次の成功テストを確認。B11 の `test_command` のソース入力と通常 exit の検査も維持 |

Process.exit の戻り型はハンドラの節で剛体となるため、`resume(())` はソースの型検査で受理されない。再開は既存の型を消去した独立コアの検査が担当し、ソースに裏口を設けない。これは B10-1 の検査で既に区別した範囲である。

実 CLI の資源制限・ソケットを使う検査は Unix 用である。プラットフォームに依存しない評価・ハンドラ・終了結果・資源解放の検査は lib に残す。OS のエラー文字列は固定せず、報告の種類・コード・位置・順序・件数・終了状態を比較する。

## test-audit の作成時の関門

1. 観測対象は上表の公開の脱糖結果、実行器の結果・出力、実ファイルの内容、CLI の文章/JSON・終了状態である。期待値はソースと契約から独立に定める。
2. 成功側の説明の先読み、コード生成での原因・説明の欠落、ハンドラ後の情報の持ち越し、停止中に貸し出した資源の破棄・二重解放、writer の panic 後の情報の残存、報告順の逆転・二重報告・後続テストの未実行を捕まえる。
3. 既存の表を拡張し、コアの一回性と実行器の順序を分担する。従来の通常の取消しは全体の停止中の解放を、構造化した RunEnd の描画検査は実際の解放・flush 失敗との接続を確認しないため、この二点には本物の入力を追加する。
4. 本番のフラグ・公開 API・内部の段の置き換えは加えない。既存の OS の仕事の筋書きだけを再利用する。CLI は本番のバイナリを起動する。

テストの削除・ignore の追加・期待値の緩和はない。既存の assert はすべて維持した。通常の取消し入力の準備は、第二のタスクの式と追加のエフェクトを指定する非公開の補助へまとめた。裸の try の既存の成功・失敗の検査は変更していない。

## 診断・計画との対応

仕様上の診断変更はない。R70 の test runner の文章表示と06-04の反映は、R72 に従って B11 で先行して完了しているため、B12 では実際の解放失敗を伴うソースで検査した。通常 exit と JSON の仕様は変更していない。新しい設計判断を要する計画からのずれはない。

## 検査

依頼に従って scripts/check.sh（dry-run を含む）と gc-stress の構成は実行していない。formal/ は変更していないが、計画の B12 に従って check-formal.sh も実行した。

```sh
cargo test -p benitoite --lib --test golden --test test_command --test random_programs --test cli_process --no-fail-fast
cargo test -p benitoite --test cli_process
cargo clippy --workspace --all-targets
cargo test -p benitoite --lib
cargo fmt --all --check
git diff --check
```

| 検査 | 結果 |
|---|---|
| lib | 最終1,194件成功、78.47秒。既存の長い21件は既定どおり未実行 |
| golden | 2件成功、56.39秒。通常の全入力の比較を含む |
| test_command | 18件成功、0.90秒 |
| random_programs | 3件成功、49.86秒。既存の60秒の制限内で、件数・時間・環境変数の変更なし |
| cli_process | 集計の assert の追加後も全10件成功、6.31秒 |
| clippy --workspace --all-targets | 成功、2.81秒 |
| fmt --all --check / git diff --check | 成功 |

統合した一式の後、CLI の集計と二つの解放失敗の順序の assert を補い、cli_process 全体を再実行した。clippy が追加テストの列挙型のワイルドカード分岐を拒否したため、Finished/Stopped の列挙へ直し、最終の clippy・lib 全体・fmt を再実行した。本番の振る舞いを変える修正はない。新規入力の作成中には、ラムダの引数名の不一致と解放報告の表記・位置の期待の誤りも修正した。

Rust のテストの差分は498行追加・6行削除、本番のコードは0行の増減である。削除した6行は入力の準備と表の拡張、およびコメントの更新に伴う置換であり、assert の削除はない。ログは `/private/tmp/b12-rust-final.log`・`b12-cli-final.log`・`b12-clippy-final.log`・`b12-lib-final.log` に置いた。

次の形式化の検査も終了状態0で成功した。lake build は成功し、Lean の定義と証明の変更、新しい sorry・axiom・admit・native_decide はない。

```sh
BENITOITE_DESUGAR_DIFF_DIR=target/desugar-diff/b12-final \
BENITOITE_COVERAGE_DIFF_DIR=target/coverage-diff/b12-final \
bash scripts/check-formal.sh
```

| 六入口 | 結果 |
|---|---|
| coverageDiff | 通常10,020件・view付き10,028件が一致。不一致・fuelExhausted 0 |
| desugarDiff | golden 352入力・975定義、random 1,000入力・72,778定義が一致。全1,741入力のうち対象1,352、静的検査エラー389、範囲外0 |
| builtinCheck | 対象1,352入力、summary 比較72,600件が一致。不一致・非収束0 |
| coverageProgramDiff | match 16,417件・bind 6,036件、合計22,453件が一致。不一致・範囲外・fuelExhausted 0 |
| surfaceCheckAll | 51,652件一致。不一致・準備失敗・lazyRestriction 0。既存の対象外19件・q11 1件を維持 |
| surfaceCheck と最終 manifest | 全1,741入力・73,753定義・22,453 coverage entries の対応が一致。corpus 10・型表3・網羅性3と六入口の件数・対象外理由はB11と同じ |

交換形式の独立入力46件、通常の書き出し17件のテストも成功した。契約の破損3件、hole/pipe の破損6件、名前付きの破損6件を意図した理由で拒否し、外部型の view の欠落の拒否も成功した。manifest・件数・対象外理由は変更していない。

全件の書き出しは563.181秒、最後の入力ごとの比較と集約結果・破損入力の照合は202秒だった。出力は `target/desugar-diff/b12-final/`・`target/coverage-diff/b12-final/`、ログは `/private/tmp/b12-formal.log` に置いた。

## 申し送り

B13 の現行文書・英語 reference・手書き Skill の整備と、B14 の段末検査を後続へ引き継ぐ。オーケストレータが最後に実行する scripts/check.sh と gc-stress 構成の検査は未実行である。コミットと docs/todo の変更は行っていない。
