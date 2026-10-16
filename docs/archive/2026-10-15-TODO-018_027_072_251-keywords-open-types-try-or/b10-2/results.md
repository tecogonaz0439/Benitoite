# B10-2 実装結果

## 目的と変更

報告付きの終了要求を Request 方式へ接続し、採用した終了だけに原因・任意の説明・位置を保持する。

- `crates/benitoite/src/vm/dispatch/tasks/io.rs`: `ReturnToExecutor` の暫定拒否を除いた。外側へ返す前に報告を所有した文字列にし、既存の `Request.die_failure` に保持する。応答の処理では要求から取り出し、Direct と同じ停止の採用条件を使う。通常の要求には情報を付けない。
- `crates/benitoite/src/vm/exit_report_tests.rs`: 説明の無し・空・複数行、不正な内部入力の既存の表を両方式で検査する。Request の待機中に報告のレジスタを空にして GC を行い、要求が所有した情報で終了できることを確認する。採用済みの別の終了・Internal・Interrupt の維持と、`run_program` が返す `RunEnd` の対照も加えた。
- `crates/benitoite/src/refinterp/exit_report_tests.rs`: 既存の処理・再開・破棄・再入・後の独立した exit の表に Request を加えた。準備のコアの構築を共通化し、二つのタスクの終了要求を両方式・両順序で比較する。Task.race の取り消し後に古い要求を再配送し、後の通常の exit に報告が残らないことも確認する。タスクを使う入力は参照インタプリタでは実行しない。
- `docs/design/02-impl/02-08-vm.md`・`02-11-embedding.md`: RequestId ごとの所有・完了・取り消し、採用した停止結果だけへの移動を反映した。

要求の取り出し・失効と停止理由の優先順位は既存の実装で足りるため、runtime/io・sched・run の本番部分は変更していない。型・公開シグネチャ・大域の状態・ヒープ外の Value を追加していない。本番の parser は die を受理しない。

## test-audit の作成時の関門

1. 守る契約は、RequestId に属する所有、待機中のヒープからの独立、完了・取り消し後の再配送の無効化、採用した停止への情報の限定、Direct/Request の一致、RunEnd への保持である。
2. 報告の読み捨て、応答時の報告レジスタの再読み出し、別の要求の原因・説明の転記、取り消し後の呼び出し、Internal/Interrupt への混入、通常の exit と報告付きの exit の混同を捕まえる。
3. 既存の表を拡張し、ハンドラの契約を重複した新しいテストにしなかった。要求の所有・停止の採用は VM の実行境界、タスクの競合・取り消しは本物のスケジューラを使う VM の実行境界で検査する。RunEnd は VM の結果を写す別の契約なので `run_program` でも確認する。従来の通常の exit の検査では、報告の有無や内容を観察できない。
4. 本番の API・フラグ・可視性をテストのために増やしていない。外部の実行順序には既存の Dispatcher と ScheduleHandle を使い、実際の VM・キュー・スケジューラをつなぐ。先に採用された停止の対照には、既存のテストと同じく RunState に停止理由を置く。待機中のレジスタの整理には既存の cfg(test) の補助を使う。

`request_exit_report_survives_collection_and_is_consumed_once` は実装の接続前に失敗した。期待する要求を返す代わりに `Internal("exit report Request execution is not connected")` で停止し、未接続の拒否が原因であることを確認した。接続後は同じ検査が成功した。

## 期待値と診断の対応

言語仕様上の診断コード・主文・help・主副位置に変更はない。golden の期待値、既存の不正な内部入力の拒否、裸の try の検査は変更していない。

| 対象 | 旧 | 新 | 理由・既存の検査の維持先 |
|---|---|---|---|
| 報告付き Request の有効な内部入力 | `StopReason::Error`、`Stop::Internal("exit report Request execution is not connected")`。実行結果にすると終了状態 3 | `StopReason::Exit { code: 1, die_failure: Some(...) }`。終了状態 1 | B10-2 が指定する暫定拒否の除去。旧テストの assert は `run_program` の終了の厳密な確認へ変更し、原因・説明・位置も比較する。未接続という暫定状態自体の拒否は不要になった |
| 不正な操作・終了状態・型・レジスタ範囲・短い報告表 | 内部エラーとして拒否 | 同じ理由で拒否 | 既存の全入力と期待する内部エラーの文を維持し、Request にも適用した |
| Direct と参照インタプリタ、処理・再開・再入後の結果 | 原因・説明・位置を含む既存の期待結果 | 同じ期待結果 | 既存の assert を維持し、Request も同じ値と比較する |

比較の緩和、assert の撤去、ignore/skip の追加は行っていない。テストの準備では、最初に VM の非公開欄を別モジュールから参照した箇所と、Task.race のエフェクト宣言の不足を修正した。

既存の表を拡張し、独立した契約のテストを五件加えた。Rust の本番部分は 13 行追加・19 行削除（差し引き 6 行減）、テスト部分は 454 行追加・107 行削除（差し引き 347 行増）である。テストの削除行は、表への方式の追加に伴う字下げ、共通化した準備、計画どおりに除いた暫定拒否の期待の書き換えであり、assert の撤去ではない。

## 検査

コマンドはリポジトリの根から rtk 経由で実行した。Rust の検査と重い形式化の検査は直列で実行した。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 最終 1,180 件成功、既存の ignore 21 件、失敗 0。74.14 秒 |
| `cargo test -p benitoite --test runtime_builtins --test random_programs --test golden` | 3 スイート・13 件成功、失敗 0。107.55 秒 |
| `cargo clippy --workspace --all-targets` | 成功。警告・誤りなし |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |
| `bash scripts/check-formal.sh` | 成功。863.37 秒。冒頭の `formal/` の `lake build` を含み、sorry の警告なし。六入口・独立入力・破損入力・manifest の照合がすべて成功 |

構文の章・標準ライブラリ・診断の表・仕様の例・利用者向けの例は変更していないため、gen_skill と各例の追加検査は不要である。

最初の clippy が新しいテストの包括的な match を拒否したため、`VmStep::Finished` と `VmStep::Stopped` を明示した。再実行で成功し、この修正後に lib 全体も再確認した。統合テストの対象となる本番の Rust と入力は、統合テストの成功後に変えていない。

形式化の出力は `target/desugar-diff/run-65595/` と `target/coverage-diff/run-65595/` にある。

| 形式化の入口・入力 | 件数と結果 |
|---|---|
| `coverageDiff` | 通常 10,020 件・view 付き 10,028 件が一致。不一致・fuelExhausted 0 |
| `desugarDiff` | 1,736 入力のうち golden 349 件・random 1,000 件が対象。既存の check error の除外 387 件。範囲外・不一致 0。定義は golden 968 件・random 72,778 件が一致 |
| `builtinCheck` | 対象 1,349 入力。summary の比較 72,468 件、不一致・非収束 0。既存の不透明型の引数と State の仮定を維持 |
| `coverageProgramDiff` | match 16,417 件・bind 6,036 件、計 22,453 件が一致。不一致・対象外・fuelExhausted 0 |
| `surfaceCheckAll` | 51,645 件一致、不一致・準備失敗・lazyRestriction 0。既存の対象外 19 件・q11 1 件を維持 |
| `surfaceCheck` と最終の照合 | 1,736 入力の識別名・対象外理由・scope・coverage と、入力ごとの全結果が一致。73,746 定義・22,453 coverage entries を維持 |
| 独立した交換形式・破損入力 | width・named・extensible・try の独立入力が成功。契約の破損 3 件、hole/pipe の破損 6 件、名前付きの破損 6 件は意図した理由で拒否。外部パッケージの IOErrorKind view と定数宣言の識別も一致 |

通常の corpus 9・型表 3・網羅性 3 と独立した try の入力を維持し、最終の manifest は六入口と一致した。対象内件数・対象外理由を下方修正していない。Lean の定義・証明・axiom・sorry/admit/native_decide は変更していない。全コーパスの書き出しは 562.409 秒、最後の個別照合は 201 秒であった。

## 計画との差と申し送り

R4・R56・R58 の範囲で接続でき、計画と異なる設計判断はない。decisions.md に新しい R は追加していない。B10-3 の標準 Show、B10a の型・脱糖・交換出力、B11/B12 の本番ソースからの終了・解放・flush・test runner の検査は後の作業である。今回の内部入力の実行を、それらの検査の代わりには数えない。

コミット、docs/todo の変更、scripts/check.sh（dry-run を含む）、gc-stress の構成の検査は、依頼に従って行っていない。共通の検査と取り込みはオーケストレータへ引き継ぐ。
