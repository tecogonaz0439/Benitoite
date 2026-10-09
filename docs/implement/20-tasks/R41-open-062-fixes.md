# R41 OPEN-062 の再現した項目と、報告の段の位置の不具合を直す

- 依存する作業: [R30](R30-open-062-reproduction.md)、[C12](C12-golden-runtime.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 小〜中（200〜600 行。テストを含む）
- ブランチ: impl/R41-open-062-fixes

## 目的

R30 の再現テストで再現した OPEN-062 の項目と、C12 が見つけた報告の段の位置の不具合を直す。設計書は、設計者の判断を受けてオーケストレータが改めた（[ADR 0319](../../design/decisions/0319-task-results-and-pure-guarantee-under-switching.md)、[ADR 0320](../../design/decisions/0320-output-transfer-at-budget-switch.md)）。本作業は、その決定に処理系とテストを合わせる。

## 読む設計書の節

- [エフェクト](../../design/01-spec/01-07-effects.md)の純粋な関数の保証（ADR 0319 で狭めた段落）
- [並行処理](../../design/01-spec/01-11-concurrency.md)の「タスクを起動する関数」（`Task.race`・`Task.withTimeout` の型、`Task.allOk` の結果の段落）
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「出力のバッファ」の転送の時点の表（ADR 0320 で加えた行）
- [仮想機械](../../design/02-impl/02-08-vm.md)の「実行時エラーの情報の記録」の 2、[診断](../../design/02-impl/02-10-diagnostics.md)の実行時エラーの報告の段（呼び出した位置を持たない段は名前だけを示す）
- ADR 0319・0320・0325

## 直すもの

| 番号 | 直すこと | 手がかり |
|---|---|---|
| 1 | `Task.race`・`Task.withTimeout` の型のエフェクトに `State` を加え、`uses Clock.Time, State, E` にする（ADR 0319 の決定 3） | 10-14・10-12 の写しは直してある（ADR 0319）。`src/prelude/stdlib/Task.bnt` を写しに合わせる。型検査は宣言から型を作るので、宣言を直せば足りる見込み（型検査やコード生成に関数ごとの特別扱いを加えない） |
| 2 | 1 に合わせて、`Task.race`・`Task.withTimeout` を呼ぶ既存のスクリプトとテストの `uses` に `State` を加える（`uses IO.All` と書いたものは変えなくてよい。`IO.All` は `State` を含む） | 直す箇所の目安: `testdata/concurrency/c12-race-and-timeout.bnt` の `main`、`src/vm/dispatch/tasks/io/output_tests.rs`（622 行付近）、`src/vm/dispatch/tasks/io/tests.rs`（438・637 行付近）、`src/vm/dispatch/tasks/tests/cancellation.rs`（101・111・279・283・872・1410 行付近）。設計書の例（`cargo test --test spec_examples` が落ちるものは、例の `uses` を直す。例の直しは型を合わせるだけにする） |
| 3 | タスクが予算を使い切って切り替わるとき、バッファに出力があれば両方のバッファの中身の転送を依頼する（ADR 0320） | 予算を使い切ったときの `switch_inner`（`vm/dispatch/tasks.rs`。`#[cold]`）の `Switch::Yield` の場合に、`rt.stdout` と `rt.stderr` の `request_transfer` を呼ぶ。`request_transfer` は空なら送らないので、空かを調べる公開の関数を加えずにそのまま呼んでよい。命令ごと・呼び出しごとの経路（CALL・TAILCALL・RETURN の速い経路、ループの頭）には処理を加えない |
| 4 | 実行時エラーの報告の trace で、各タスク（`main` のタスクを含む）の積み重ねの最も外側の段が location を持つ不具合を直し、名前だけを示す（location は null。ADR 0325） | `c12-inherited-non-tail` の原因は、`vm/dispatch/tasks.rs` の 520 行付近でタスクの最初の枠を `call_site: Some(at)`（起動の命令）で積むことである。`c12-task-error` の 12:44–12:53 は起動の位置ではなく、ラムダの中の末尾呼び出し `divide(0)` の位置である（`vm/dispatch.rs` の 1251 行付近の TAILCALL が `call_site` を上書きする）。直し方は ADR 0325 に従い、報告を作る処理（`runtime/report.rs` の `call_trace`。`vm/state.rs` の `stop_info` は外側の区画の `calls[0]` を最後に並べる）で、各タスクの積み重ねの最も外側の段を位置なしにする。TAILCALL の速い経路は変えない。`tasks.rs` の 520 行付近の `call_site` を `None` にするかは任せる。`None` にする場合は、`cancellation.rs` の 1020 行付近の `call_site.unwrap()` のテストを、`task.spawner` から位置を取る形に直してよい。起動の履歴（taskOrigins）には起動の位置を残す |

## R30 のテストの扱い

取り込み済みの `tests/open_062.rs` は次の形である。

- R01 の二件は、ADR 0319 の決定 1・2 に合わせ、「値を返したときは同じ値」と「止まるときは実行時エラーで止まる（どの実行時エラーかは問わない）」を確かめる形で、通る。
- `handle` の中の `Task.race` の一件は、型検査の誤り（`State` が `uses` にない）になることを確かめる形に書き換えられ、`#[ignore = "R41 で直す（ADR 0319 の決定 3）"]` が付いている。
- 準備を知らせる行の一件は、`#[ignore = "R41 で直す（ADR 0320）"]` が付いている。

本作業は、後の二件の `#[ignore]` を外し、通ることを確かめる。

## 受け入れテスト

- R30 の二件（`Task.race` の型検査の誤り、準備を知らせる行）が `#[ignore]` なしで通る（両方の IO の方式で）。
- `Task.race`・`Task.withTimeout` を `uses Clock.Time` だけの関数から呼ぶと、`State` が `uses` にない型の誤りになる（`check` のゴールデンテストを一件。期待する診断コードは型検査の既存のエフェクトの不足の診断に合わせる）。
- 予算を使い切った切り替えで転送を依頼することを、出力先が端末でない場合の VM の単体テストで確かめる（別のタスクが計算を続ける間に、短い出力が出力先に届く）。
- 報告の trace のタスクの最初の段が location を持たないことを確かめるゴールデンテストを二件加える（C12 が外した `c12-inherited-non-tail` の形と、末尾呼び出しで最初の段が置き換わる `c12-task-error` の形。期待値は設計書から決める）。
- `main` が末尾呼び出しした場合も、trace の最も外側の段が location を持たないことを確かめるテストを加える（ADR 0325）。
- 既存のテストが、2 の `uses` の直しを除いて期待を変えずに通る。

## 完了条件

- `scripts/check.sh` が通る（`check-heap.sh` は、VM を変えるのでオーケストレータが取り込みのときに走らせる）
- 受け入れテストのすべての場合を確かめるテストがある
- 完了の報告に、直した箇所の一覧、`uses` を直した既存のスクリプトとテストの一覧、短い測定と機械語の数（3 で VM を変えるため。始めた版と交互に fib(30)・loop 300 万回を 5 回以上、`run_until_exit` の頭の命令の数と退避の数）を書く

## 確認の観点

- 1 で、型検査やコード生成に `Task.race` の特別扱いを加えていないか（標準ライブラリとの疎結合）。
- 3 の転送の依頼が予算を使い切った遅い経路だけにあり、速い経路に加わっていないか。
- 4 で、起動の履歴の位置を消していないか。
- D11 が同じ `runtime/report.rs` の `main_frame`（`call_trace` の近く）を ADR 0324 で変える予定である。R41 は `call_trace` の変更にとどめる。

## 難易度の理由

直すことはどれも局所的だが、1 は既存のスクリプトの `uses` の直しが 4 ファイル約 10 箇所に及び、3 は VM の切り替えの経路に触れ、4 は報告の形を変える。
