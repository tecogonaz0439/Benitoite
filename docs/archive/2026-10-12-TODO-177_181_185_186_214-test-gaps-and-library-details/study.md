# 調査

点ごとの今の状態と直し方を、項目ごとの部に分けて書く。2026-10-12 に Opus のサブエージェントが項目ごとに調べた結果であり、行番号は調べた時点のものである。各部の「設計者に決めてもらう点」の答えは `decisions.md` にある（部の中の推奨と答えが違うときは `decisions.md` を正とする）。部の終わりの「作業の分け方の案」は、`plan.md` で作業をまとめ直した。

## TODO-214 の調査（`with` で束縛したリソースで、`close` の待ちが取り消されたときの解放の失敗）

調べた版: ブランチ `san_benito`（eb8dac11 の時点の作業ディレクトリ）。ファイルは変えず、cargo も走らせていない。行番号はこの版のものである。

設計者の決定: 今のまま `with` の解放の失敗（実行時エラー `ReleaseFailed`）として報告する。01-10（必要なら 02-09）に書き、Direct と Request の両方で、VM を通す再現テストで固定する。

### 1. 今の振る舞いを作るコードの流れ

#### 1.1 流れ（Direct の形）

TODO-214 の筋書きは、`Task.race` の一つ目のタスクが `with w = try File.openWriter(...) do bind _ <- File.closeWriter(w) ... end with` を実行し、二つ目のタスクが先に終わって一つ目を取り消すものである。

1. `File.closeWriter` は state の組み込みの関数で、`crates/benitoite/src/builtins/funcs/file.rs:1153-1169` が `services().begin_close(writer)` を呼ぶ。VM の実装は `crates/benitoite/src/vm/state.rs:335-358`（`begin_close`）。
2. `begin_close` は `ResourceTable::request_release`（`crates/benitoite/src/runtime/io/resources.rs:226-310`）を呼ぶ。`FileWriter` は、状態を `Releasing(op)` にし、番号を `release_jobs` に加え、`ReleaseStart::Blocking` を返す（同 281-283 行）。`begin_close` は `CloseStep::Wait(StateWait::Resource(id))` を返す（state.rs 351-352 行）。
3. VM は、`StateWait::Resource(id)` を `WaitReason::Release(id)` に替えてタスクを待たせる（`crates/benitoite/src/vm/dispatch/tasks.rs:454`、`park`）。待ちが解けたら、同じ組み込みの関数をもう一度呼ぶ（`builtins/iface.rs:362-363` の `begin_close` の説明）。
4. 解放の仕事は、待ちの位置の処理（`crates/benitoite/src/vm/dispatch/tasks/io.rs:615-631`）が `take_release_job` で取り出し、作業用のスレッドへ出す。
5. ほかのタスクが勝ち、`Task.race` が一つ目のタスクを取り消す。`cancel::request`（`crates/benitoite/src/vm/dispatch/tasks/cancel.rs:57`）は、待つ理由が `WaitReason::Release(_)` のタスクを起こさない。この判定は、解放の枠の待ちと `close` の関数の待ちを区別しない。タスクは解放の完了まで待ち続ける。
6. 解放の仕事が失敗で終わる。`ops::accept_completion`（`crates/benitoite/src/runtime/io/ops.rs:216`）が `finish_release` を呼び、状態を `Released` にし、理由を `release_failure` に置く（resources.rs 339-347 行）。続けて `wake_all(WaitReason::Release(id))` がタスクを起こす（tasks/io.rs 659-662 行）。`prune_released` は、`release_failure` が残る項目を表から除かない（resources.rs 453-464 行）。
7. 起きたタスクは取り消しの要求を持つので、命令を実行する前に `cancel::begin`（cancel.rs 96-120 行）が、原因 `Cancel` の `UnwindWork` を作る。`closeWriter` の呼び出しはやり直さない。したがって、`close` の側の `take_release_failure` は呼ばれない。
8. 枠を辿る処理（`crates/benitoite/src/vm/dispatch/unwinding.rs:185`）が `with` の解放の枠で `unwind_release` を呼ぶ。`request_release` は `Released` の項目に `AlreadyReleased` を返す。`crates/benitoite/src/vm/unwind.rs:166-177` の分岐で、`take_release_failure` が手順 6 の理由を取り出し、`dispatch::resource::release_failure`（`crates/benitoite/src/vm/dispatch/resource.rs:103-124`）が原因 `Cancel` の失敗として `log.failures` に加える。
9. 辿り終えると、原因が `Stop` でなく `log.failures` が空でないので、`Stop::Runtime(RuntimeError::ReleaseFailed(..))` を返す（unwinding.rs 264-268 行）。プログラムはこの実行時エラーで止まる。報告の理由は `"fake flush failure"`、種類は `FileWriter`、開いた位置は `openWriter` の呼び出しである（unwind.rs 159-164 行が項目の `opened_at` を使う）。

X4 のレビュー（所見 2）の説明との違い: レビューは「枠も `InProgress` で解放の完了を待つ」とした（手順 2）。コードでは、手順 5 のとおり取り消しの要求が `close` の待ちを外さないので、タスクは解放の完了まで `close` の待ちのまま止まり、枠を辿るのは完了の後である。枠は `InProgress` を見ず、最初から `AlreadyReleased` を見る。結果（`ReleaseFailed "fake flush failure"`）は同じである。

`with` で束縛していない版（`cancelled_close_discards_release_failure_in_both_io_modes`、`crates/benitoite/src/builtins/funcs/file/resource_tests.rs:965`）では、手順 8 の解放の枠がないので、誰も理由を取り出さない。これが 01-10 の「捨てる」の実装である（後述の 2.4 のとおり、厳密には「残したまま誰も取りに来ない」）。

#### 1.2 Request の形でも同じ報告になるか

なると判断する。理由は次のとおり。

- Direct と Request の違いは、IO の要求の振り分けの部品（`runtime/io/mod.rs:166-199` の `DirectDispatcher`・`RequestDispatcher`、`runtime/io/services.rs:218-219`）だけである。Request の形では、IO の操作（ここでは `openWriter` を差し替えた `Test.openFailingWriter`）の要求を外側の実行器に返す。
- 筋書きに関わるほかの処理は、形によらない。`closeWriter` は state の組み込みの関数で、IO の要求を作らない。解放の仕事は、振り分けの部品を通らず、どちらの形でも `rt.parts.workers.submit` で直接出す（tasks/io.rs 615-631 行）。取り消し・`wake_all`・枠を辿る処理・`ReleaseFailed` への変換にも、形による分岐はない。
- 同じ筋書きの `bind` の版は、同じスケジュール（`[PickTask(1), PickTask(1), PickTask(2)]`）で両方の形を通っている。`with` の版が加えるのは `USE` と枠だけで、待ちの位置を増やさない。

コードからは差が見つからないが、実行では確かめていない。再現テスト（4 節）で確かめる。もし Request で違う結果になれば、スケジュールの消費の違い（`consumed` の失敗）か、`Test.openFailingWriter` の要求の扱いの違いが疑わしい。そのときは処理系を直さず、実装者が記録を添えて報告する。

### 2. 「先に取りに来た方が受け取る」仕組みで、二重の報告や失う筋書きがほかにないか

`release_failure` は項目に一つだけあり、`finish_release` だけが書き、`take_release_failure` が一度だけ取り出す。同じリソースの解放を求めた側（解放の枠、`close` の関数、`File.closeReader` などの `begin_release`）が、`AlreadyReleased` を見たときに取り出す。

#### 2.1 二重の報告になる筋書き

見つからなかった。

- `close` の呼び手が取り消されずに待つ場合: 完了で起きた `closeWriter` が `begin_close` をもう一度呼び、`AlreadyReleased` で理由を取り出して `Result.Error` を返す（state.rs 346-347 行）。後で `with` の枠が `AlreadyReleased` を見ても、理由は残っていないので `Popped` になる。この場面は `with_reports_release_failure_unless_close_has_already_returned_it`（resource_tests.rs の `close = true` の版、両方の形）が固定している。
- `with` の戻りの解放が失敗したとき: 戻りの `RELEASE` で失敗した枠は元の位置に戻し（`vm/dispatch/resource.rs` の `Release` の分岐）、止める手順で同じ枠をもう一度辿る。ブロックする解放なら、戻りの処理が理由を取り出して `Err` を返した後なので、二度目は理由がなく `Popped`。即時の失敗（`ReleaseStart::Done(Err)`）は、そもそも `release_failure` に書かない（resources.rs 305-306 行のコメント）。二重にはならない。
- 止める手順と取り消しの間の移行: `UnwindWork::escalate` は `log` を保ち、同じ枠を二度処理しない（02-08「止める手順」の決まり）。

#### 2.2 失う筋書き

`with` で束縛したリソースでは見つからなかった。`with` の解放の枠は、どの原因で辿っても必ず `request_release` を呼び、`AlreadyReleased` なら理由を取り出す。したがって、理由がまだ残っていれば、枠が必ず受け取る。

#### 2.3 誰が受け取るかがスケジュールで変わる筋書き（報告は一度）

解放の完了を待つ側が二つあると、`wake_all` で両方が起き、先に選ばれた方が理由を受け取る。報告は一度だが、報告の形が変わる。

- 二つのタスクが同じリソースに `closeWriter` を呼んで待つ: 先に選ばれた方が `Result.Error`、もう一方は `Result.Ok(())`。01-10「解放したリソースの使用」の「解放済みのリソースに呼ぶと `Result.Ok(())`」と合う。
- `with` で束縛したタスク A が `with` を抜け（枠が `InProgress` で待つ）、そのリソースを捕えた別のタスク B が `closeWriter` で待つ: A が先なら A で `ReleaseFailed`（実行時エラー）、B が先なら B に `Result.Error` で、A の `with` は成功する。
- 今回の決定とは矛盾しない。どちらでも一度だけ報告し、`with` の側で受け取れば実行時エラーにする。ただし、結果がスケジュールで変わることは仕様に書いていない。同じリソースを複数のタスクから閉じるのは珍しく、今回は扱わないでよい（5 節の点 2）。

#### 2.4 取り消した `close` の理由を、後の `close` が受け取る筋書き（01-10 との食い違い）

`with` で束縛していないリソースで、取り消した `close` の理由は「捨てる」と 01-10 にある。実装は捨てずに項目に残すので、同じリソースに後で `close` を呼ぶと、その理由を受け取る。

例: `main` が `bind w <- try File.openWriter(...)` で開き、`Task.race` の一つ目のラムダが `w` を捕えて `File.closeWriter(w)` を呼ぶ。待つ間に取り消される。`race` の後に `main` が `File.closeWriter(w)` を呼ぶと、`AlreadyReleased` で残った理由を取り出し、`Result.Error("fake flush failure")` を返す（state.rs 346-347 行）。01-10 の二つの規則（取り消しの失敗を捨てる、解放済みのリソースへの `close` は `Result.Ok(())`）のどちらとも食い違う。

`with` で束縛したリソースでも、`with` の枠が取り消したタスクの外（親のタスク）にあり、ブロックの中で親が `closeWriter` を呼ぶと、子の取り消した `close` の理由を親の `closeWriter` が `Result.Error` で受け取る。失いはせず、`with` の持ち主に届くので、今回の決定の趣旨（見落とさせない）には沿う。ただし「`with` の解放の失敗として報告する」という文とは形が違う。

この筋書きは実行で確かめていない（コードから読んだ）。今回の改造で直すかは 5 節の点 1。

#### 2.5 止める手順の場合

`closeWriter` の待ちの間に止める手順が始まると、`begin_stop_all`（tasks.rs 1049-1090 行）は解放の完了の待ちを保つ（`waiting: Some(Release)`）。完了の後に枠を辿り、`with` の枠が理由を取り出し、原因 `Stop` の失敗として止める理由の報告に加える。`with` で束縛していなければ、誰も取り出さず、実行を終えるときに `close_all_silently` が捨てる。どちらも 01-10 の第二段落と「止まるときに解放するのは `with` で束縛したリソースだけ」に合う。今回の決定の文で、止める場合も同じ扱いになることを書ける（3 節の案は「その `with` を抜けるときの解放の失敗」とし、原因ごとの扱いは上の段落に委ねる）。

### 3. 設計書に足す文の案

#### 3.1 01-10「解放の失敗」（必須）

最後の【決定】（`with` で束縛していないリソースの文）の直後に、一段落足す。

> 【決定】`with` で束縛したリソースについて、`close` などの関数が解放を待つ間に呼んだタスクが取り消されたときは、その解放の失敗を、そのリソースの `with` のブロックを抜けるときの解放の失敗として扱う。呼んだタスクの取り消しでそのブロックを抜けるときは、取り消しの解放の失敗として実行時エラーにする。理由: `close` の結果を受け取る続きは捨てられたが、`with` で束縛したリソースの解放の失敗は、ブロックを抜けるときに報告して見落とさせないためである。

注記:
- 「そのリソースの `with` のブロックを抜けるとき」とすれば、枠が別のタスクにある場合（2.4 の後半）と止める手順（2.5）も、上の第一・第二段落の規則に委ねられる。ただし、2.4 の後半のように、ブロックの中の後の `close` が先に受け取る場合をこの文は含まない。点 1 で今は直さないと決めるなら、この文の後に「ただし、ブロックを抜ける前に同じリソースの `close` などの関数をもう一度呼んだときは、その関数が失敗を `Result.Error` で返す。」と足すか、docs/todo の項目に回す（5 節の点 1）。
- 01-spec に実装の方式の記述（`release_failure` の表など）を入れない。

#### 3.2 02-09（必須）

1. 「リソースの追跡」の、解放の失敗のまとめの 4 点目（close の関数が始めた解放の失敗）の後に、一点足す。

> - close の関数を呼んだタスクが解放の完了を待つ間に取り消されたときは、失敗の理由をリソースの表の項目に残す。後で同じリソースの解放を求めた側（解放の枠、close の関数）のうち先に来た方が取り出し、その側の規則で扱う。`with` の解放の枠が取り出したときは、その枠を辿る原因に従って扱う（[リソース管理](../01-spec/01-10-resources.md)の「解放の失敗」）。どの側も取り出さなければ、実行を終えるときに項目と一緒に捨てる。

2. 「タスクの待ちと取り消し」の取り消しの手順の 1 点目の「ただし、解放の枠が解放の完了を待つ待ちは外さない」を、「ただし、解放の完了を待つ待ちは、解放の枠の待ちも close の関数の待ちも外さない」に改める。コード（cancel.rs 57 行）は両方を同じ `WaitReason::Release` で扱い、どちらも外さない。今の文は close の関数の待ちに触れておらず、02-08 の一般の規則（待っていれば進められるタスクに戻す）が当てはまるように読める。

#### 3.3 02-08「取り消し」（推奨。3.2 の 2 と同じ食い違い）

`docs/design/02-impl/02-08-vm.md:310` の「解放の枠の処理が解放の完了（または解放の前の返却）を待っているタスクは、要求で待ちを外さない。」を、「解放の枠の処理か close の関数が解放の完了（または解放の前の返却）を待っているタスクは、要求で待ちを外さない。」に改める。close の関数の待ちでは、解放が終わってから取り消しの手順に移り、close の関数の呼び出しはやり直さない、と添えるとよい。依頼の範囲（01-10 と 02-09）の外なので、設計者の了承を得てから直す（5 節の点 3）。

#### 3.4 リファレンスと標準ライブラリの文書

要らないと判断する。

- `docs/reference/benitoite.md` は、`with` で束縛していないリソースの取り消した `close` の扱いも書いていない（805 行の Writer の失敗の状態の段落と、652 行の `with` の段落だけ）。今回は振る舞いを変えないので、利用者が知る必要は増えない。CHANGELOG も要らない。
- `crates/benitoite/src/prelude/stdlib/IO/File.bnt:72-73` の `closeWriter` の `///` は、取り消しを扱わない。取り消しはどの関数にも当たる一般の規則で、`closeWriter` だけに書くと `closeReader`・`Http.closeListener` との釣り合いが崩れる。`gen_skill` の作り直しも要らない。

### 4. 再現テストの案

#### 4.1 外した `with` の版の在りか

コミットした版には残っていない。X4 の実装者の報告（スクラッチパッドの `orch5/X4-report.md` の 93 行）に、「同じ筋書きで `with` にした版は、Direct モードで `"fake flush failure"` を理由とする `ReleaseFailed` になった」「最終テストには `bind` 版だけを残した」とある。`bind` 版は `crates/benitoite/src/builtins/funcs/file/resource_tests.rs:962-1010` の `cancelled_close_discards_release_failure_in_both_io_modes` である。

#### 4.2 置き場所と形

同じテストを、束縛の仕方（`bind` と `with`）の表の形に改める（test-audit の「表の形のテストに行を足す」）。新しいテストを別に足さない。準備（スケジュール、`release_workers`、`open_failing_writer` の差し替え）がまったく同じだからである。

- テストの名前: `cancelled_close_release_failure_is_dropped_unless_with_bound_in_both_io_modes` などに改める（名前が確かめることより多くを約束しないように）。`git grep` では、この名前を参照する箇所は resource_tests.rs の定義だけである。
- 関門のコメントを改める。例: 「関門: closeWriter を待つタスクを取り消すと、with で束縛していなければ解放の失敗を捨て、with で束縛していれば取り消しの解放の失敗（ReleaseFailed）にする（設計書 01-10「解放の失敗」）。書き込み待ちの取り消しではこの経路を通らない。解放の外部の仕事だけを保留する。」

ラムダの本体の二つの版:

```text
// bind（今のまま）
   bind w <- try File.openWriter("unused",File.WriteMode.Replace)
   bind _ <- File.closeWriter(w)
   Reference.set(continued,true)
   return Result.Ok(1)

// with
   with w = try File.openWriter("unused",File.WriteMode.Replace) do
    bind _ <- File.closeWriter(w)
    Reference.set(continued,true)
    return Result.Ok(1)
   end with
```

`uses File.Write,State,Clock.Time` は今のまま（`Task.race` に `Clock.Time` が要る。X4 の報告の 95 行）。

#### 4.3 偽の解放

既存の部品をそのまま使う。

- `FailRelease`（resource_tests.rs 476-484 行）: `release` が常に `Err("fake flush failure")` を返す `OsResource`。
- `Test.openFailingWriter`（同 605-623 行）: `FailRelease` を `ResourceKind::FileWriter` として登録する。`FileWriter` なので `request_release` は `Blocking` を返し、作業用のスレッドを通る。`rt.builtin_overrides` で `Benitoite.IO.File.openWriter` を差し替える。
- `release_workers(&mut rt, &script, false, true)`（同 843-866 行）: 解放の仕事を保留し、進められるタスクがなくなったとき（勝者が終わり、取り消したタスクが close の待ちに残る位置）に許す。`idle` の中の `"released before cancellation"` の確かめが、取り消しより先に解放しないことを保証する。
- スケジュールは今のまま `[PickTask(1), PickTask(1), PickTask(2)]`。

#### 4.4 確かめる結果

両方の形（`ExecMode::Direct`・`ExecMode::Request`）で、次を確かめる。

- `bind` の版（今のまま）: `VmStep::Finished(MainOutcome::Ok)`。
- `with` の版: `VmStep::Stopped(StopEnd { reason: StopReason::Error(info), release_failures, .. })` で、
  - `info.stop` が `Stop::Runtime(RuntimeError::ReleaseFailed(failures))`、
  - `failures.len() == 1`、`failures[0].kind == ResourceKind::FileWriter`、`failures[0].reason == "fake flush failure"`、`failures[0].opened_at.is_some()`、
  - `release_failures.is_empty()`（止める途中の解放の失敗として二重に載らない。2.1 の確かめ）。
- 共通: `*delayed.borrow()`（取り消しの後に解放を許した）、`jobs.borrow().len() == 1`、`*count.lock().unwrap() == 1`（解放は一度だけ。`with` の枠がもう一度解放しない）、`consumed(&script)`。
- `with` の版では `main` が `Result` を返す前に止まるので、`continued` の値は観察しない（停止で十分に「続きを実行していない」ことが分かる）。

診断の文言（`ReleaseFailed` の報告の英語の文）は、この単体の境界では作られない。文言は `diag::codes` の表と CLI の報告の既存のテストが持ち主であり、この契約（取り消しの解放の失敗になること）とは独立なので、ここでは `RuntimeError::ReleaseFailed` とその中身までを確かめる。

#### 4.5 作成時の関門（test-audit）

1. 守る契約: 01-10 に足す【決定】（`with` で束縛したリソースの取り消した `close` の失敗を、取り消しの解放の失敗として報告する）。
2. 捕まえる退行: 取り消した `close` の理由を捨てる変更（たとえば、取り消しで `release_failure` を消す、`unwind.rs` の `AlreadyReleased` の分岐が理由を見なくなる）、二重に報告する変更、Request の形だけで経路が変わる変更。
3. 既存のテストが捕まえない理由: `bind` の版は枠がなく、`with_reports_release_failure_unless_close_has_already_returned_it` は取り消しを含まない。`cancellation.rs` の `cancellation_removes_lend_waiters_but_preserves_release_waits` は待ちを外さないことだけを確かめ、理由の行き先を見ない。
4. 本番の差し込み口: 要らない。

退行の確かめ: 実装者は、一時的に `unwind.rs:168` の `take_release_failure` の結果を捨てる（`AlreadyReleased` で常に `Popped`）ように変えて、`with` の版が意図した理由（`Finished(Ok)` になる）で落ちることを確かめ、戻す。

### 5. 設計者に決めてもらう点

#### 点 1: 2.4 の「取り消した `close` の理由を、後の `close` が受け取る」を今回直すか

- 推奨: 今回は直さず、docs/todo の新しい項目にする。01-10 には、点 1 に触れない 3.1 の文だけを足す。
- 理由: 直すには、理由の受け取り手を待つ側ごとに区別する必要がある（TODO-214 の「決めること」の 2 点目）。取り消したタスクが close の待ちにいたことを、取り消しの手順の時点で覚えておき、そのタスクの枠に同じリソースの解放の枠がなければ理由を消す、などの変更になる。枠が別のタスクにある場合（2.4 の後半）の扱いも決める必要があり、30〜60 分の作業に収まらない。今の振る舞いは失敗を失わず、食い違いは「捨てるはずの失敗が後の `close` で現れる」側にとどまる。
- 代替: 今回、`with` で束縛していないリソースの場合に限り、取り消しの手順の始めで理由を消す。枠の有無を調べる処理が要り、別のタスクの枠の場合を誤って捨てる危険がある。

#### 点 2: 2.3 の「誰が受け取るかがスケジュールで変わる」ことを仕様に書くか

- 推奨: 書かない。docs/todo の点 1 の項目に含める。
- 理由: 同じリソースを複数のタスクから閉じる使い方は珍しく、どの場合も一度だけ報告する。

#### 点 3: 02-08「取り消し」の文も直すか（3.3）

- 推奨: 直す。02-09 の 3.2 の 2 と同じ変更で行う。
- 理由: 今回の振る舞い（close の待ちを外さず、解放の完了の後に取り消しの手順に移る）は、`with` の枠が理由を受け取る前提である。02-08 の今の文からは、close の待ちが外れて枠が `InProgress` で待つように読め、X4 のレビューもそう説明した。

### 6. Codex（GPT-6.1-Sol）に渡す作業

#### 作業 Y214（目安 30〜60 分）

前提として読むもの: AGENTS.md、`.claude/skills/test-audit/SKILL.md`、本書の 1・3・4 節、`docs/design/01-spec/01-10-resources.md` の「解放の失敗」、`docs/design/02-impl/02-09-runtime.md` の「タスクの待ちと取り消し」「リソースの追跡」、`docs/design/02-impl/02-08-vm.md` の「取り消し」（点 3 を了承したとき）。

内容:

1. `crates/benitoite/src/builtins/funcs/file/resource_tests.rs` の `cancelled_close_discards_release_failure_in_both_io_modes` を、束縛の仕方（`bind`・`with`）の表の形に改め、名前と関門のコメントを改める（4.2）。`with` の版は 4.4 の結果を、Direct と Request の両方で確かめる。本番のコードは変えない。
2. 退行の確かめ: `crates/benitoite/src/vm/unwind.rs` の `ReleaseStart::AlreadyReleased` の分岐で理由を捨てるよう一時的に変え、`with` の版が `Finished(Ok)` で落ちることを確かめてから戻す（報告に、落ちたときの出力の要点を書く）。
3. 設計書: 01-10「解放の失敗」に 3.1 の段落を足す。02-09 に 3.2 の 1・2 を反映する。点 3 を了承したときは、02-08「取り消し」の 310 行も 3.3 のとおり改める。文章はスキル `japanese-tech-writing` に従い、常体、【決定】の後に「理由:」を 1〜3 文。
4. Request の形で結果が Direct と違ったときは、処理系を直さず、作業を止めて結果（`VmStep` の中身と `script.record()`）を報告する。

してはならないこと: 本番のコードの変更、リファレンス・`File.bnt`・CHANGELOG の変更（3.4）、ほかのテストの変更、コミット（オーケストレータが行う）。

完了の条件（リポジトリの根で実行する）:

```sh
cargo test -p benitoite --lib builtins::funcs::file::resource_tests
cargo test -p benitoite --lib --no-default-features --features gc-mark-sweep,heap-verify,gc-stress builtins::funcs::file::resource_tests
cargo test -p benitoite --lib vm::dispatch::tasks::tests::cancellation
cargo clippy -p benitoite --all-targets -- -D warnings
cargo fmt --all -- --check
scripts/check.sh --dry-run
```

- 1・2 行目で、改めたテストが両方の構成で通ること（`with` の版を含む）。
- 3 行目は、取り消しの周辺のテストに影響がないことの確かめ（本番のコードを変えないので通るはず）。
- `scripts/check.sh --dry-run` の出力（選ばれる検査と理由）を報告に添える。本番の検査（`check.sh` の実行）はオーケストレータが設計者に知らせてから行う。
- 設計書の ` ```text ` のブロックは変えないので、`cargo test --test spec_examples` は要らない（変えた場合は実行する）。

## TODO-181 の調査（ゴールデンテスト・差分テスト・参照インタプリタの穴）

調べた版: ブランチ san_benito の eb8dac11。コードは読むだけで、ビルドもテストも走らせていない。パスは、`src/`・`tests/`・`testdata/` で始まるものは `crates/benitoite/` を起点とし、ほかはリポジトリの根を起点とする。行番号は 2026-10-12 時点のものである。

前提として読んだもの: AGENTS.md、`.claude/skills/test-audit/SKILL.md`、07-03「テストの設計の原則」「差分テスト」、02-08「参照インタプリタ」、`docs/todo/sources/later-issues.md` の 17・18・19・28・30・32・35・36・51・85・95・98。

### 一覧

| 節 | 今も当てはまるか | 分類 |
|---|---|---|
| 1. 参照インタプリタの費用（17・35） | 当てはまる。ただし `list_hof_long` を遅くしている主な原因は根の読み直しではなく、リストの写しである | 実装の直し（根の読み直しと毎回の回収）。リストの写しは「扱わない」を推す（設計者が決める） |
| 2. 参照の値の世代（36 (c)） | 当てはまる。今の組み込みの関数では起きない | 実装の直し（小さい。テストなし）か、扱わない |
| 3. 未使用の継続の解放のテスト（18） | 当てはまる。二度目の `resume` の位置はゴールデンの差分比較が確かめている | テストの直し |
| 4. 巻き戻し中の `Stop::Internal`（19） | 当てはまる。ただし差分テストを誤って通すことはない | 文書だけ（コメントと `debug_assert`） |
| 5. CLI の報告のテスト（28） | 並べ替えは要確認。JSON の 1 件 1 行は確かめ済み。転送の失敗の `Exited` の分岐はテストがない。shebang のテストの名前は直っている | テストの直し（一部は既に直っている） |
| 6. lines の入力（30） | 当てはまる | テストの直し（実行器） |
| 7. 差分テストの作業ディレクトリ（32） | 当てはまる（三点とも） | テストの直し（実行器） |
| 8. 集計の表示と脱糖のテストの空振り（51） | 当てはまる（(a)(b) とも） | テストの直し |
| 9. fmt の古い `.formatted`（85） | 当てはまる。今は古いファイルがない | テストの直し（実行器） |
| 10. L40 の細部（95） | 当てはまる | テストの直し（testdata）。相対パスの program のゴールデンは「扱わない」を推す |
| 11. 受け入れ例の細部（98） | 当てはまる | テストの直し（testdata）。"1 orders" は「扱わない」を推す |

---

### 1. 参照インタプリタの費用（later-issues の 17・35）

#### 今のコードの箇所

- `src/refinterp/convert.rs:86-160` の `BuiltinBridge::call_decl`。
  - 101-107 行: 呼び出しのたびに `roots` の全体（`0..roots.len()`）を読んで `opaque` の `Vec` に集める。
  - 109-112 行: 引数を `to_heap_with`（176 行〜）で丸ごと変換用のヒープへ写す。`Value::List` は要素をすべて確保し直し、`list::from_values` で RRB の木を作り直す（245-253 行・297-306 行）。`Map`・`Set`・`Str`・`Bytes` も同じく丸ごと写す。
  - 146-155 行: 結果を `from_heap_with` で戻す。中身を見せない値（`ObjKind::Opaque`・`Host`・`NetworkError`）は `roots.push` で根に積み、`Value::Opaque(番号)` にする。根は `Drop`（168-173 行）まで減らない。
  - 158 行: 呼び出しのたびに `self.heap.collect(&self.roots)` で回収する。
- `tests/golden.rs:40-44` の `EXPENSIVE_REFERENCE_CASES` が `testdata/eval/list_hof_long.bnt` を差分比較から外し、605-606 行で理由 "reference list conversion cost" として数える。

#### 指摘が今も当てはまるか

当てはまる。ただし、項目の文は二つの費用を一つにまとめており、`list_hof_long` を遅くしているのは後者である。

1. 根の読み直し（17）: 根は中身を見せない値を返す組み込みの関数（`src/builtins/funcs/random.rs`・`regex.rs` の `alloc_opaque`、HTTP の `Host`）を呼ぶたびに増え、減らない。呼び出しのたびに全部を読み、158 行の回収も全部の根を辿る。乱数の生成器を回すループのように中身を見せない値を作り続けるプログラムでは、呼び出しの回数と根の数の積の時間がかかり、メモリも増え続ける。
2. リストの写し（35）: `List.map`・`filter`・`fold` は標準ライブラリの Benitoite のコード（`src/prelude/stdlib/List.bnt:60-100`）で、要素ごとに `get(xs, i)` を呼び、`map` は `append(acc, y)` も呼ぶ。参照インタプリタでは、その呼び出しのたびに 5 万要素のリストを丸ごと写し（`to_heap_with`）、回収で捨てる。5 万要素では、`get` が約 15 万回と `append` が約 5 万回で、1 回あたり O(n) なので、要素の写しは合わせて約 10^10 回になる。`list_hof_long` は中身を見せない値を作らないので根は空のままであり、根の読み直しを直しても、このケースは速くならない。

#### 直し方の案

(A) 根の読み直しと毎回の回収をやめる（推す。小さい）

- `to_heap_with` の引数 `opaque: &[HeapValue<'e>]` を `roots: &RootStack` に替え、`Value::Opaque(n)` に出会ったときだけ `roots.get(ctx, RootIdx(n))` で読む。`call_decl` の 101-107 行の `opaque` の収集を消す。`from_heap_with` の閉包は `roots.push` を使うので、`to_heap` を終えてから可変で借りる今の順のままでよい。
- 158 行の回収を毎回行わず、`self.heap.collect_requested()`（`Heap` の公開の関数。`src/runtime/heap/ctx.rs:331`）が真のときだけ行う。`gc-stress` の構成では常に真なので、回収の強制の検査は弱まらない。`take_fault` の確かめは毎回行う。`convert.rs` の先頭の `//!` のコメント（「成功・停止・終了のいずれでも回収する」）を、回収の予算に従う旨に直す。
- 根を手放す仕組み（`Value::Opaque` を `Rc` の取っ手にして、落ちたら根を空ける）は加えない。`Value` の型の変更が `value.rs`・`eval.rs`・`pattern.rs` に広がるからである。根が減らないことは残る弱さとして、`call_decl` のコメントに書く。
- 見込みの効果: 中身を見せない値を作り続けるプログラムで、二次の時間がなくなる（メモリが増え続けることは残る）。`list_hof_long` には効かない。
- テスト: 振る舞いを変えない直しなので、テストを足さない（test-audit の関門 1 に答えられない）。`refinterp` の単体テストと、差分テストを含むゴールデンテストが通ることで確かめる。ゴールデンテストのうち乱数（`l40-random-seeded`）と正規表現（`l40-regex` など）のケースが、中身を見せない値の経路を通る。

(B) リストの写しを減らす（大きい。設計者が決める）

- 案: `Rc` の同一性で変換の結果を覚える。`Value::List(Rc<Values>)`（`Map`・`Set` も同じ）を写すときに、`Rc::as_ptr` を鍵、`Weak` と変換用のヒープの根の番号を値とする表を引く。`Weak` を `upgrade` して `Rc::ptr_eq` で一致すれば、写さずに覚えた根の値を使う。結果のリストを戻したときも、新しい `Rc` と根を表に入れる。覚える根は `roots` と別の `RootStack` に置き、`Weak` が死んだ項目が半分を超えたら詰め直す。小さいリスト（例えば 64 要素未満）は覚えない。
- 見込みの効果: `get(xs, i)` は 1 回目の後 O(1) になる。`append(acc, y)` は引数の側は O(1) になるが、結果を `Vec` に戻す `from_heap_with` が O(i) のままなので、`map` の部分に約 n²/2 = 1.25×10^9 回の要素の写しが残る。測っていないが、数十秒の見込みであり、ゴールデンテストの全体（約 27 秒）と同じかそれより長い。
- 費用と危険: 02-08「参照インタプリタ」は値の表現を共有しないことを【決定】としている。覚える表は評価に変換用のヒープを使わせないので、この決定には反しない。しかし、表の正しさは `Values` が書き換えられないこと（`Rc::get_mut`・`make_mut` を使っていないこと。今は使っていない）に頼る。根を詰め直す処理も要る。組み込みの関数が引数のヒープの値を書き換える不具合があれば、覚えた写しを通じて参照の側にも同じ誤りが現れる。ただし、07-03「差分テスト」は組み込みの関数の不具合を差分テストの対象外としているので、検出力の損失は小さい。
- 直した後に `EXPENSIVE_REFERENCE_CASES` から外せるか: 二次の部分が残るので、普段の検査に含めるのは難しい。外すとしても「全体の検査でだけ比べる」になる見込みで、そのためには測定が要る。

(C) 扱わない（(B) の代わりとして推す）

- 理由: (1) 費用は「組み込みの関数を呼ぶときだけ値を変換する」という 02-08 の設計から来ており、変換をやめずに二次の時間をなくす方法がない（(B) でも二次が残る）。(2) `list_hof_long` の目的は、ファイルの 2 行目のコメントのとおり、VM の 64 KiB の上限と長さに比例した入れ子の検出であり、参照インタプリタとの比較ではない。CLI の二方式の検査とコア IR の検査は残っている。(3) 同じ高階関数の意味は、`testdata/eval/f15_nested_capture_and_long_list.bnt`（512 要素の `List.map`・`List.fold`）と `testdata/eval/list_hof_order.bnt` が差分比較している。
- (C) にするときの直し: `tests/golden.rs:40-43` のコメントから「docs/todo の TODO-181 で扱い、直すまで」を除き、外す理由（参照インタプリタは組み込みの関数を呼ぶたびに引数を写すので、長いリストに組み込みの関数を繰り返し呼ぶケースは二次の時間になる）を、恒久の理由として書く。07-03「差分テスト」の比べる対象を定めた段落に、「参照インタプリタは組み込みの関数を呼ぶたびに引数を変換するので、長いリストへの組み込みの関数の呼び出しを繰り返すケースは、実行器の中の一覧に名前で書いて差分比較から外す。CLI の二方式とコア IR の検査は残す」という一文を加える（今の 07-03 には、この一覧の定めがない。回収の強制の除外は 334 行に定めがある）。

#### 設計者に決めてもらう点

- (B) を行うか、(C) で閉じるか。推す案は (A) と (C) の組み合わせである。理由: (B) は表と根の詰め直しを加えても二次の時間が残り、`list_hof_long` を普段の検査に戻せない。差分比較で得るものは、短いケースが既に確かめている内容と重なる。

---

### 2. 参照の値の世代（later-issues の 36 の (c)）

#### 今のコードの箇所

`src/refinterp/convert.rs:44-50` の `struct RefValue(u32)`。番号は、`call_decl` の中の局所の `references`（100 行）の位置である。`to_heap_with` の 219-224 行で関数と位置の値を積み、`from_heap_with` の閉包（147-152 行）で同じ呼び出しの `references` から引く。

#### 指摘が今も当てはまるか

当てはまる。ある呼び出しで作った `RefValue` を含むヒープの対象が、中身を見せない値の中に残って根に積まれ、後の呼び出しの結果に再び現れると、後の呼び出しの `references` の別の値を黙って引く。今の組み込みの関数で中身を見せない値を作るのは `Random` と `Regex` と HTTP の `Host` であり、どれも引数の関数を中に保持しない。タスクを起動する組み込みの関数は変換の前に `Unsupported` にしている（`eval.rs` の `builtin`）。このため、今は起きない。

#### 分類と直し方

実装の直し（小さい）か、扱わない。直すなら、`BuiltinBridge` に呼び出しの番号 `generation: u64` を持たせ、`call_decl` の初めに増やす。`RefValue { generation, index }` とし、`from_heap_with` の閉包で番号が今の呼び出しと違えば `invalid_conversion()`（`Stop::Internal`）を返す。テストは足さない。本番の経路では届かない誤りの経路なので、テストのための組み込みの関数の差し込み（`#[cfg(test)]` の `overrides`）で作っても、test-audit の「本番の経路では届かない拒否を確かめている」に当たる。

#### 設計者に決めてもらう点

- 直すか扱わないか。推す案は、節 1 の (A) と同じ作業で直すことである。理由: `call_decl` の同じ箇所を変え、数行で済み、将来、引数の関数を保持する組み込みの関数を加えたときに黙って誤った値を引くことを防げる。

---

### 3. 未使用の継続の解放のテスト（later-issues の 18）

#### 今のコードの箇所

- `src/refinterp/tests.rs:549-581` の `discarded_nested_continuations_release_their_resources` は、節が値で終わる場合（E-DropRel）だけを確かめる。
- `src/refinterp/tests.rs:582-640` の `release_failures_preserve_primary_stop_exit_and_order` と、518-548 行の `releases_run_once_inside_out_on_each_kind_of_unwinding` は、`with` の解放を正常・escape・実行時エラー・exit で確かめるが、継続を含まない。
- 実装: `src/refinterp/eval.rs:367-386` の `drop_cont`。呼ぶ側は `State::Return`（696-699 行）、`State::Escape`（739-742 行）、`unwind`（908-925 行。`State::Error` の 759 行と `State::Exit` の 769 行から呼ぶ）。
- 二度目の `resume`: `src/refinterp/tests.rs:257-277` の `continuation_cannot_be_resumed_twice` は `origin: Some(_)` だけを確かめる。

#### 指摘が今も当てはまるか

E-EscDropRel・E-ErrDropRel・E-ExitDropRel（01-12 の 839 行の段落「`escape`、実行時エラーの状態、終了の状態が `drop κ` の枠を通るとき」）に当たる単体テストはない。当てはまる。

二度目の `resume` の位置は、ゴールデンテスト `testdata/handlers/c12-resume-twice.bnt`（方式 `run`、`.diag.json` が 17 行 7 列を主な位置として固定）が差分比較の対象であり、`tests/golden/differential.rs` の `compare_results` が VM と参照インタプリタの停止の位置（`user_span`）を比べている。参照インタプリタが位置を誤れば、そこで落ちる。単体テストで位置まで確かめる必要は薄い。

#### 分類と直し方

テストの直し。`discarded_nested_continuations_release_their_resources` を表の形のテストにし、内側の節（`case pause() -> ...`）の本体を次の 4 行で替える。

| 版 | 節の本体 | 期待する結果 |
|---|---|---|
| 値で終わる（E-DropRel） | 今の `abort()` → `resume(())`（外側の節が値で終わる） | `Finished(Ok)`、解放 `inner\nouter\n` |
| escape（E-EscDropRel） | `if true then return Result.Ok(()) end if` の後に `resume(())` | `Finished(Ok)`、解放は同じ |
| 実行時エラー（E-ErrDropRel） | `bind _ <- 1 div 0` の後に `resume(())` | `Stopped { stop: DivisionByZero, release_failures: [] }`、解放は同じ |
| exit（E-ExitDropRel） | `Process.exit(3)` の後に `resume(())` | `Exited { status: 3, release_failures: [] }`、解放は同じ |

- 要点は、`with inner = ...` の中で `pause()` を呼んで継続を作り、その継続を `resume` しないまま節から抜けることである。escape・エラー・exit の版は、外側の `abort` を通さずに内側の節から直接抜けてよい。ただし、入れ子の `drop` の枠（drop の枠の中の drop）も通したいので、少なくとも一つの版は、今のテストと同じく外側の操作を呼んで二重の `drop` を作ってから抜ける形にする。
- `main` の `uses` に `Process.Exit` を加える（518 行のテストと同じ）。
- 関門の 2 への答え: `State::Escape` の 739-742 行、`unwind` の 915 行の `drop_cont` の呼び出しを消す退行で落ちる。Codex に、各版について該当の行を一時的に消して落ちることを確かめさせる。
- 二度目の `resume` の位置は単体テストに足さない（ゴールデンの差分比較が確かめている。test-audit の「同じ契約を通り過ぎる層ごとに書かない」）。項目を閉じるときに、その根拠を書く。

---

### 4. 巻き戻し中の `Stop::Internal`（later-issues の 19）

#### 今のコードの箇所

- `src/refinterp/eval.rs:162-177` の `run` のループ。176 行の `state = self.step(state, io).unwrap_or_else(|s| error(s, at));` が、`step` の `Err` を新しい `Halt` にする。
- `State::Error`（751-761 行）と `State::Exit`（762-771 行）は `self.unwind(frame, ...)?` を呼ぶ。`unwind`（908-925 行）は、解放の失敗のうち `ReleaseFailed` 以外の停止（912-913 行）と、`drop_cont` の `Stop::Internal` を `Err` で返す。
- 同じ分岐の行が連続するという前提: `State::Match`（634-664 行）の 648-655 行。ガードが偽のとき、次の行を「今の行と分岐の番号が違う最初の行」とする。

#### 指摘が今も当てはまるか

当てはまる。巻き戻しの途中で `Err` が返ると、176 行が元の停止（`h.stop`）と、それまでに集めた `release_failures` を捨て、`Stop::Internal` の新しい `Halt` で巻き戻しを続ける。ただし、`Stop::Internal` は参照インタプリタの不具合であり、`tests/golden/differential.rs` の `compare_results` は参照の側の `Stop::Internal` を必ず `Failed` にする。差分テストを誤って通すことはなく、失われるのは不具合を調べるための情報だけである。

同じ分岐の行が連続する前提は、`src/ir/core_ir.rs:298` のコメント（「表層の分岐の選択肢ごとに一つ、元の順に並べる」）から成り立つが、コア IR の検査器（`src/ir/check.rs:1105-1130` の `match_comp`）は連続を確かめない。前提が破れると、ガードが偽の分岐の後の選択肢を再び試し、ガードを二度評価する。

#### 分類と直し方

文書だけ（コメントと `debug_assert`）。

- 176 行の直前に、巻き戻しの途中の `Stop::Internal` が元の停止を置き換えることと、それでよい理由（`Stop::Internal` は参照インタプリタの不具合で、差分テストは必ず失敗にする）をコメントで書く。調べやすさのために、`unwind` の `Err` を、元の停止の種類を説明に含めた `Stop::Internal` に包んでもよい。ただし、包む処理は `State::Error`・`State::Exit` の二か所に要り、得るものが小さいので、推す案はコメントだけである。
- 648 行の前に、行の並びの前提（選択肢は元の順に並び、同じ分岐の選択肢は連続する。01-12 と `core_ir.rs` の `MatchRow` のコメント）を書き、`debug_assert!` で、`m.rows` で同じ `arm` の行が連続することを確かめる（例: `rows.windows(2)` で分岐の番号が戻らない、つまり番号が単調に増えることを確かめる。選択肢は元の順に並ぶので、分岐の番号は減らない）。`debug_assert` はテストのビルドで働くので、ゴールデンの差分比較のすべての `match` で確かめることになる。
- テストは足さない。

#### 設計者に決めてもらう点

- コア IR の検査器（`ir/check.rs`）に「同じ分岐の行が連続する」検査を加える案もある。推さない。検査器は 07-04 の Lean の規則と対応づけている範囲に近く、変えると形式化の対応の確認が要る。参照インタプリタの `debug_assert` で足りる。

---

### 5. CLI の報告のテスト（later-issues の 28）

#### 今のコードの箇所と、今も当てはまるか

- 並べ替え: 実装は `src/pipeline.rs:302-322` の `append_stage`（`sort_by_key` は 312 行）。テストは `src/pipeline.rs:596-640` の `checking_sorts_each_stage_and_stops_before_later_errors`。二つのファイル（`main.bnt` が FileId 0、`Lib/Text.bnt` が FileId 1）にそれぞれ二つの E0301 を置き、位置が昇順で、最初が FileId 0 であることを確かめる。各ファイルの中では、診断は出る順と位置の順が同じ見込みである。名前解決がモジュールを依存の順（`Lib/Text` が先）に処理するなら、ファイルをまたぐ順で並べ替えを確かめていることになるが、処理の順を読み切れていない。**要確認**。
- JSON の 1 件 1 行を 2 件以上で: 確かめ済み。`tests/golden.rs:441-463` の `split_actual` は標準エラー出力を行に分け、`{` で始まり `}` で終わる行を 1 件の診断とし、期待値の `.diag.json` の行の並びと比べる。2 件の診断が 1 行に出れば、行の数が合わずに落ちる。2 行以上の `.diag.json` は多い（`testdata/lexical/int_malformed.diag.json` は 7 行、`float_malformed` は 6 行）。
- 最後の転送の失敗の `Exited`・`Interrupted` の分岐: 実装は `src/runtime/run.rs:509-525` の `flush_failure`。`Exited(_)` と `Interrupted` は 520-522 行の一つの分岐である。テストはない。`src/runtime/report.rs:1243-1259` のテストは報告の組み立て（`write_failed`・`add_flush_failure`）だけを確かめる。`tests/cli_process.rs:384-408` の `broken_pipe_is_a_runtime_error` は、`main` が値で終わる場合（`Returned` の分岐、終了状態 1、R0201）だけを確かめる。当てはまる。
- `f18_implicit_shebang` の名前: 直っている。今のテストは `src/cli/mod.rs:966-991` の `run_implicit_shebang_directory_and_request_execution` で、981 行の `vec![path.as_os_str().to_owned()]` が `run` を省いた省略形を確かめている。

#### 分類と直し方

テストの直し（JSON の行と shebang は「既に直っている」）。

- 並べ替え: まず、312 行の `sort_by_key` を一時的に消して、今のテストが落ちるかを確かめる。落ちれば今のままでよい（落ちることを確かめた旨を記録に残す）。落ちなければ、一つの段が位置の逆順に診断を出す入力を探して加える。候補は、型検査が関数を依存の順に検査する場合（後ろに書いた関数を先に検査し、その誤りが先に出る）である。どの入力が逆順になるかは、`sort_by_key` を消した状態で試して決める。
- `Exited` の分岐: `tests/cli_process.rs` の `broken_pipe_is_a_runtime_error` を表の形にし、本体の後に `Process.exit(3)` を呼ぶ版（`uses Console.Write, Process.Exit`）を加える。期待は、終了状態 3 と、標準エラー出力の R0201 である。`Interrupted` は同じ分岐なので、別のテストを足さない（シグナルとパイプの閉じを組み合わせるテストは、費用に比べて得るものがない）。
- 危険: `Console.write` が書き出しの完了を待つ作りなら、パイプの失敗が実行中に実行時エラーとして現れ、`Exited` に届かない（終了状態 1）。80 KiB の書き込みがパイプを溢れさせる今の作り方で、`Process.exit(3)` に届くかは、Codex が実際に試して確かめる。届かないときは、この点を「扱わない」とし、理由（最後の転送の失敗を `Exited` で起こす方法がテストの外から作れない）を記録する。テストのための失敗する出力先（`OutputTarget` の新しい種類）は加えない（test-audit の関門 4）。

---

### 6. ベンチマークの差分テストの lines の入力（later-issues の 30）

#### 今のコードの箇所

- `tools/bench/programs/lines.args.small` の中身は `tools/bench/programs/lines-small.txt`（リポジトリの根からの相対パス）。
- `tests/golden.rs:154-213` のベンチマークの差分テスト。187 行の `let directory = fs::canonicalize(dir)` で、ベンチマークのディレクトリ（`../../tools/bench/programs`）を基準のディレクトリにする。
- `tools/bench/programs/lines.bnt` は、読み込みに失敗すると `Result.Error(...)` を返して `main` の誤りで終わる。
- `tools/bench/run.py:371-373` の `small_arguments` も同じ `.args.small` を読み、CLI に渡す。`tools/bench/README.md:51` は「`lines.args.small` は `tools/bench/programs/lines-small.txt` を指す」と書く。

#### 指摘が今も当てはまるか

当てはまる。VM と参照インタプリタはどちらも `tools/bench/programs/tools/bench/programs/lines-small.txt` を開こうとして失敗し、同じ `MainError` で終わって一致する。ベンチマークの差分テストは期待値のファイルを持たず、二つの結果が一致すれば通るので、この失敗を見逃す。

#### 分類と直し方

テストの直し（実行器）。

- 基準のディレクトリをリポジトリの根にする（推す）。187 行を `fs::canonicalize("../..")` にする。`.args.small` を `lines-small.txt` に直す案は、`run.py --verify` と README が根からの相対パスを前提にしているので、両方を直す必要があり、範囲が広がる。ほかのベンチマークはファイルを読まないので、基準のディレクトリを変えても結果は変わらない。
- 加えて、ベンチマークの差分テストでは VM が値で終わること（`EndKind::Returned`）を求める。ベンチマークはどれも正常に終わるプログラムであり、両側が同じ失敗で一致して通ることを、この確かめで防げる。`differential::compare` に引数（例えば `require_returned: bool`）を加え、`compare_on_stage` の VM の実行の直後に、真で `vm.end != EndKind::Returned` なら `Comparison::Failed` を返す。`run` のゴールデンと `tests/random_programs.rs` は偽を渡す（期待値のファイルか、生成の側で確かめている）。真偽の引数が `expected_limit` と二つ並ぶので、小さな構造体か列挙にまとめてもよい。
- 既存のテストへの影響: 退行テストとしての確かめは、`require_returned` を先に入れて、基準のディレクトリを直す前に `lines.bnt` で落ちることを確かめ、直した後に通ることを確かめる、の順で行う。直した後、VM と参照インタプリタはどちらも 3 行を読んで `3` を出力する見込みで、差分は出ない見込みである（`File.readText` と `String.lines` は組み込みの関数で、両側が同じ本体を呼ぶ）。`tasks` は参照の側が `Unsupported` で `Excluded` になるが、VM は値で終わるので、新しい確かめには当たらない。
- README の 51 行は今の記述のままで正しくなる。

---

### 7. 差分テストの作業ディレクトリ（later-issues の 32）

#### 今のコードの箇所

- `tests/golden.rs:579-645`: 一つの `with_directory`（582 行）の中で `run::run_input(..., directory)` を作り、`differential::compare`（625 行）に渡す。
- `tests/golden/differential.rs:86-118`: `compare_on_stage` が VM を走らせた後（88-102 行）、同じ `input`（同じ作業ディレクトリ）で参照インタプリタを走らせる（114-118 行）。
- 外した件数の表示: `tests/golden.rs:215-240` の `eprintln!`。`cargo test` は通ったテストの出力を捕らえるので、`--nocapture` を与えないと見えない。
- 書き直し（bless）: `tests/golden.rs:362-372` の `load_case` が `.exit` のないケースを `missing .exit` の誤りにするので、`BENITOITE_BLESS=1` でも新しいケースの期待値を起こせない。

#### 指摘が今も当てはまるか

三点とも当てはまる。ただし、今のテストで VM の残したファイルが参照の側の結果を変えている例は見つからなかった。ファイルを書くゴールデン（`testdata/io/c12-write-append.bnt`・`l40-file-paths.bnt`・`l40-file-resources.bnt`、`testdata/acceptance/test_replaces_effects.bnt` など）は、`writeText` で上書きしてから追記するか、最後に `File.removeTree("work")` で片付けており、今は同じ結果になる。VM の側が途中で失敗したときや、追記から始めるテストを加えたときに、参照の側の結果が変わる。

#### 分類と直し方

テストの直し（実行器）。

- 作業ディレクトリ: `differential::compare` に、参照の側を走らせる前に呼ぶ準備の閉包 `prepare_reference: Box<dyn FnOnce() -> Result<(), String> + Send>` を加え、`compare_on_stage` の 114 行の前で呼ぶ（誤りなら `Comparison::Failed`）。ゴールデンは、作業ディレクトリの中身を消して `.files` を写し直す閉包を渡す（`with_directory` と `copy_files` の処理を補助の関数に分けて共有する）。`tests/random_programs.rs:88` は何もしない閉包を渡す。閉包を受け取る代わりに参照の側に別のディレクトリを使う案は、ディレクトリのパスが出力に現れるテストで差が出うるので推さない。
- 既存のテストへの影響: 上のとおり、今のテストは片付けるか上書きするので、差は出ない見込みである。出たら、そのテストが VM の残したファイルに頼っていたことになり、テストの側を直す。
- 外した件数の表示: 推す案は、`eprintln!` に加えて、集計を `env!("CARGO_TARGET_TMPDIR")`（統合テストに Cargo が与える一時ディレクトリ）の下の `golden-summary.txt` に書くことである。07-03「ゴールデンテスト」に、外した件数をそのファイルで確かめられることを一文で書く。別案は、07-03 か `scripts/check.sh` に `-- --nocapture` を書くことであるが、ほかのテストの出力も混ざる。
- 書き直しで `.exit` のないケース: `load_case` に `bless` を渡し、書き直しのときに限り、`.exit` がなければ仮の 0 を期待値にして読み進める。書き直しは期待値と比べずに `write_expected` で `.exit` を書くので、仮の値は残らない。書き直しでないときは、今のとおり `missing .exit` の誤りにする（07-03 の「`.exit` は必須」）。テストは足さない（実行器そのもののテストになり、test-audit の境界の外である）。手で一度、`.exit` のない一時のケースで書き直しを試して確かめる。

#### 設計者に決めてもらう点

- 外した件数を見せる方法（集計のファイルか、`--nocapture` を手順に書くか、今のままか）。推す案は集計のファイルである。理由: `check.sh` の出力を変えず、件数を後から読める。

---

### 8. 集計の表示と脱糖のテストの空振り（later-issues の 51）

#### (a) 集計の表示

##### 今のコードの箇所

- `tests/golden.rs:647-668`: `check` の方式で成功したケースのコア IR の検査の結果を、`validate_core(program, Comparison::Matched)` で得て、`Matched` なら `summary.check_core_matched += 1`（665 行）とし、さらに `summary.record(result, ...)`（667 行）で `summary.matched` にも数える。
- `tests/golden.rs:85-91` の `Summary::record`、`tests/golden.rs:216-219` の表示「golden: N cases; core IR/differential: M matched」と「check mode core IR: K matched」。

##### 指摘が今も当てはまるか

当てはまる。`M` に、差分比較をしていない `check` のケースの数 `K` が含まれ、二重に数える。

##### 直し方

テストの直し。665-667 行を、結果で分ける `match` にする。`Matched` は `check_core_matched` だけを増やし、`Failed` は `failures` に積み、`Excluded` は来ない（`validate_core` の第二引数が `Matched` なので）。表示の 217 行を「differential: M matched」に改め、`run` で外したケース（`validate_core(program, Comparison::Excluded(..))`）のコア IR の検査は外した件数に数えるので、表示の意味がそれと一致することを確かめる。ベンチマークの差分比較（199-206 行）も `summary.matched` に数えるので、表示は「golden と bench の differential」になる。表示だけの直しで、テストの合否は変わらない。

#### (b) 脱糖のテストの空振り

##### 今のコードの箇所

`src/ir/desugar/tests.rs:102-150` の `result_types_follow_function_boundaries_and_stay_out_of_other_positions`。`compile` は `desugar_files` を呼び、脱糖の後のコア IR の検査で誤りがあれば落ちる。脱糖の側は `src/ir/desugar.rs:210-216` の `result_ty` が、`Position::Tail`・`Result` では関数の結果の型（`return_ty`）を、`Other` では式の型を `if`・`match` の型として付ける。`src/ir/desugar/effects.rs:170-173` の `with` が本体の位置を決め、206・235・265 行が `lazy`・`handle` の本体・節の本体を `Other` にする。

##### 指摘が今も当てはまるか

当てはまる。関数 `nested` の結果の型は `Integer` である。Other の位置の `with`（126-129 行）の最後の式は `1`（`Integer`）、`handle` の本体（131-133 行）の最後は `ping()`、節（135-137 行）の最後は `resume(())` で、どれも `if`・`match` ではない。位置を誤って `Result` にしても、型の注釈が付く `if`・`match` がないか、付いても型が同じなので、コア IR の検査は通る。

##### 直し方

テストの直し。Other の位置の最後の式を、結果の型（`Integer`）と違う型の `if` か `match` にする。

- 126-129 行の `with`: `bind label <- with inner = TaskGroup.open() do if c then return 3 end if; if c then "a" else "b" end if end with` のように、最後を `String` の `if` にする（後で `n` を使っている 139 行は、別の `Integer` の値を返すように直す）。
- `handle` の本体と節: 本体の最後を `if c then ping() else ping() end if` にしても型が `Unit` なので、`handle` の結果の型を `Integer` 以外にする形（例えば `bind flag2 <- handle ... if c then true else false end if with case ping() -> ... resume(()) end handle`）にする。節の最後の式は `resume` の結果の型になるので、`match` で `resume` を包む形にする。具体の形は型検査が通るように Codex が決める。
- 関門の 2 への答え: `effects.rs:171` の `Position::Other => Position::Other` を `Position::Result` にする退行、206・235・265 行の `Position::Other` を `Position::Result` にする退行で、コア IR の検査が `if`・`match` の型の不一致を報告して落ちる。Codex に、それぞれ一時的に変えて落ちることを確かめさせる。
- 形式化への影響: テストの入力だけを変え、脱糖も 01-12 も変えないので、`check-formal.sh` は要らない。

---

### 9. fmt のゴールデンの古い `.formatted`（later-issues の 85）

#### 今のコードの箇所

- `tests/golden/formatting.rs:74-90`: 元のファイルごとに `formatted_path` を引いて比べるだけで、元のない `.formatted/` の中のファイルを見ない。
- `tests/golden/formatting.rs:132-156` の `bless_formatted`: 元のファイルに対応するものだけを書くか消し、空のディレクトリを消す（158 行〜の `remove_empty_dirs`）。元のない古いファイルは、書き直しのときも消さない（項目の「書き直しのときだけ消す」は不正確である）。
- `fmt-check` の方式のケースに `.formatted` があっても、誤りにしない。

#### 指摘が今も当てはまるか

当てはまる。今の `testdata` には古いファイルはない（`testdata/fmt/` の 8 件と `testdata/acceptance/fmt_comments.formatted` は、どれも元のファイルがある。ディレクトリのテスト `testdata/fmt/directory.formatted/` の中のファイルにも、すべて元がある）。

#### 直し方

テストの直し（実行器）。`formatting.rs` に `stale_formatted(case, originals) -> TestResult<Vec<PathBuf>>` を加える。

- ディレクトリのテストでは、`<名前>.formatted/` の下のファイルのうち、相対パスが `originals` にないものを返す。
- `fmt-check` の方式では、`<名前>.formatted` があれば（ファイルでもディレクトリでも）返す。
- 書き直しでないときは、返したパスごとに `failures` に「stale .formatted」を積む。書き直しのときは消し、その後に `remove_empty_dirs` を呼ぶ。
- 既存のテストへの影響: 古いファイルがないので、落ちない見込みである。関門の 2 への答えとして、Codex に一時の古いファイルを置いて落ちることを確かめさせる（確かめた後に消す）。

---

### 10. L40 のゴールデンの細部（later-issues の 95）

#### 今のコードの箇所と、今も当てはまるか

- 相対パスの program の解決: 実装は `src/builtins/funcs/process.rs:288`（`program` が `/` を含む相対パスなら、子の作業ディレクトリから辿る。03-07 の 204 行）。単体テストは `src/builtins/funcs/process/external_tests.rs:311` の `command_resolves_directory_relative_program_and_environment` で、基準のディレクトリが絶対パスと相対パスの両方の場合に `./tool` を確かめている。ゴールデンには `"./` で program を指すテストがない（`"./` を含むのは `testdata/stdlib/l40-path.bnt` と `testdata/syntax/c11-import-*.bnt` で、どれも Process ではない）。当てはまる。
- `testdata/io/l40-clock-handled.bnt:10` の `Clock.sleep(1000000)`: 当てはまる。ハンドラの `case Clock.sleep(_)` が効かない退行では約 17 分止まる。しかも、`sleep` の節は出力に何も残さないので、`sleep` の差し替えだけが壊れた退行は、17 分待った後に通ってしまう。
- 同 5 行の `import Benitoite.Trait`: 未使用である。ファイルに `Trait.` の使用がない。未使用の取り込みは警告にならない（このケースは `.diag.json` を持たず終了状態 0 である）。
- `testdata/stdlib/l40-collections.bnt:1` と `testdata/io/l40-file-paths.bnt:1` の印「01-07 IO が起きる時期と順序」: 当てはまる。前者は `Map`・`Set` と `Trait.Show` を確かめ、IO の時期を確かめていない。後者は File の関数と `IOErrorKind` を確かめる。

#### 分類と直し方

テストの直し（testdata）。

- `l40-clock-handled.bnt`: `Clock.sleep(2000)` にし、節を `case Clock.sleep(ms) -> ` の形で出力に残す（例えば節で `Console.writeLine("slept ${Integer.toString(ms)}")` を書いてから `resume(())`。`main` は `Console.Write` を持つので節から書ける）。`.stdout` に 1 行を加える。こうすれば、`sleep` の差し替えが壊れた退行は、2 秒の後に出力の違いで落ちる。参照インタプリタの側も同じ節を通るので、差分比較は保たれる。
- 同 5 行の `import Benitoite.Trait` を消す。
- 印: `l40-collections.bnt` は「01-06 標準の型クラス（初回リリース版）」（01-06 の 455 行の見出し）に替える案を推す（`Trait.Show.show` で `Map`・`Set` を表示している）。`l40-file-paths.bnt` は「01-07 IO の失敗」（82 行）か「01-07 IO を行う組み込み関数」（145 行）に替える。替えた後に `python3 tools/spec-coverage/spec_coverage.py` を走らせ、「01-07 IO が起きる時期と順序」を指すテストが残ること（`c12-write-append.bnt` などがある）を確かめる。見出しは集計の対象になる第 3・第 4 の見出しで、文字列が一致しなければならない。
- 相対パスの program のゴールデン: 「扱わない」を推す（次の項）。

#### 設計者に決めてもらう点

- 相対パスの program のゴールデンを足すか。推す案は扱わないことである。理由: 解決の規則は単体テストが基準のディレクトリの二つの形で確かめており、CLI が基準のディレクトリを正しく渡すことは、相対パスでファイルを読むゴールデン（`c12-write-append.bnt` など）が確かめている。ゴールデンを足しても、捕まえる退行が既存のテストと重なる（test-audit の関門 3）。足すなら、`l40-process-commands.files/sub/` に実行の権限を付けたシェルスクリプトを置き、`Process.command("./tool.sh", [])` を `workingDirectory: Option.Some("sub")` で呼ぶ 1 行を加える（`copy_files` の `fs::copy` は Unix で権限の印を写す）。
- L40 の作業文書の完了条件に `RUNTIME_VIEW_CASES` を書き足す件（later-issues の 95 の最後）は、作業文書が `docs/archive/` に保管済みで読み取り専用なので、扱わない。

---

### 11. 受け入れ例の細部（later-issues の 98 の Linux 以外の分）

#### 今のコードの箇所と、今も当てはまるか

- `testdata/acceptance/process_shell.bnt:9`: `... | LC_ALL=C sort | tr 'a-z' 'A-Z'`。`tr` に `LC_ALL=C` がない。当てはまる。
- `testdata/acceptance/fmt_comments.bnt:1` の印は「01-01 コメント」だけ、`testdata/acceptance/test_replaces_effects.bnt:1` の印は「01-07 利用者が定義するエフェクトとハンドラ（初回リリース版）」だけである。当てはまる。仕様の見出しは「01-02 ドキュメントコメント（初回リリース版）」（01-02 の 698 行）と「01-06 エフェクトの宣言とハンドラの型付け（初回リリース版）」（01-06 の 487 行）で、項目の文の見出しの名前には「（初回リリース版）」が抜けている。
- `testdata/acceptance/json_summary.stdout` の `tool: 1 orders, 4300`: 当てはまる。出力は `json_summary.bnt:33` の型板 `"${category}: ${Pair.first(entry)} orders, ..."` から来る。

#### 分類と直し方

テストの直し（testdata）。

- `process_shell.bnt:9` の `tr` の前に `LC_ALL=C` を置く。出力は変わらない。
- 二つのファイルの印の行の後に、`// spec: 01-02 ドキュメントコメント（初回リリース版）` と `// spec: 01-06 エフェクトの宣言とハンドラの型付け（初回リリース版）` をそれぞれ加える。印は先頭のコメントの並びの中に置く（その後の印は読まれない）。`fmt_comments.bnt` は `fmt` の方式なので、印の行を加えると整形の期待値 `fmt_comments.formatted` にも同じ行を加える必要がある。`fmt_comments_check.bnt` が同じ内容を持つなら、そちらも揃える。`python3 tools/spec-coverage/spec_coverage.py` で印が実在の見出しを指すことを確かめる。
- "1 orders": 「扱わない」を推す。

#### 設計者に決めてもらう点

- "1 orders" を直すか。推す案は扱わないことである。理由: 00-03 の完了条件の「LLM が JSON の集計スクリプトを書く」に対応する受け入れ例で、`acceptance/INDEX.md:23` が完了条件の行と結び付けている。表記を直すには、スクリプトの型板か入力のデータを変えることになり、受け入れ例の中身を利用者に見えない理由で変える。単数と複数を出し分ける処理を加えると、例が長くなる。直すなら、型板を `"${category}: orders ${...}, amount ${...}"` のような数に依存しない形に替え、`.stdout` を作り直す。

---

### 作業の分け方の案

Codex（GPT-6.1-Sol）に一つずつ渡す。どれも各 30〜60 分の見込みで、互いに独立しているが、W3 と W4 はどちらも `tests/golden.rs` を変えるので、続けて行う。ゴールデンテストは、前の改造の記録で `cargo test -p benitoite --test golden` が約 27 秒だった（`docs/archive/2026-10-12-TODO-182_183_184-test-reliability-and-io-details/reviews/2026-10-12-X3/handling.md`。ビルドの時間を含まない）。ゴールデンの一部だけを走らせるときは、環境変数 `BENITOITE_GOLDEN_FILTER=<パスの一部>` を使う。全体の検査（`scripts/check.sh`）は、最後に一度オーケストレータが走らせる。

#### W1 参照インタプリタの変換の費用（節 1 の (A)・(C)、節 2）

- 内容: `call_decl` の根の読み直しをやめ、回収を予算に従わせる。`RefValue` に呼び出しの番号を持たせる（設計者が直すと決めたとき）。`EXPENSIVE_REFERENCE_CASES` のコメントと 07-03「差分テスト」に、外す理由を恒久の理由として書く（(C) に決めたとき）。`convert.rs` の `//!` のコメントを直す。
- 完了の条件:
  - `cargo test -p benitoite --lib refinterp::`
  - `cargo test -p benitoite --test golden`
  - `cargo test -p benitoite --test random_programs`
  - `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --lib refinterp::`（回収の強制で、予算に従わせた回収が根を取りこぼさないことを確かめる。features の値は `scripts/check.sh` の 22 行・301 行に従う）

#### W2 参照インタプリタのテストとコメント（節 3・4）

- 内容: 未使用の継続の解放の表の形のテスト（4 版）。各版について、該当の `drop_cont` の呼び出しを一時的に消して落ちることを確かめる。`run` のループの 176 行のコメント、`State::Match` の行の前提のコメントと `debug_assert`。
- 完了の条件:
  - `cargo test -p benitoite --lib refinterp::`
  - `cargo test -p benitoite --test golden`（`debug_assert` を全部の `match` で通す）

#### W3 ゴールデンの実行器: 入力と作業ディレクトリ（節 6・7 の作業ディレクトリ）

- 内容: ベンチマークの基準のディレクトリをリポジトリの根にする。`differential::compare` に `require_returned` と `prepare_reference` を加え、ゴールデン・ベンチマーク・`random_programs` の呼び出しを直す。`require_returned` を先に入れて `lines` で落ちることを確かめてから、基準のディレクトリを直す。
- 完了の条件:
  - `cargo test -p benitoite --test golden`
  - `cargo test -p benitoite --test random_programs`
  - `BENITOITE_GOLDEN_FILTER=lines cargo test -p benitoite --test golden -- --nocapture`（出力に lines のケースの失敗がなく、差分比較の一致の件数に数えられていること）

#### W4 ゴールデンの実行器: 集計・書き直し・古い `.formatted`（節 7 の残り・節 8 (a)・節 9）

- 内容: `check` のコア IR の検査を差分比較の件数から外し、表示を改める。外した件数を集計のファイルに書く（設計者が決めたとき）。書き直しで `.exit` のないケースを起こせるようにする。古い `.formatted` を誤りにし、書き直しで消す。一時の古いファイルと `.exit` のない一時のケースで、手で確かめる（確かめた後に消す）。
- 完了の条件:
  - `cargo test -p benitoite --test golden -- --nocapture`（表示の件数が、golden の差分比較と check のコア IR で分かれていること）
  - `BENITOITE_GOLDEN_FILTER=testdata/fmt cargo test -p benitoite --test golden`

#### W5 段ごとのテストと CLI のテスト（節 5・節 8 (b)）

- 内容: 脱糖のテストの Other の位置の最後の式を、型の違う `if`・`match` にし、位置を誤る退行（`effects.rs:171`・206・235・265 行）で落ちることを確かめる。`pipeline` の並べ替えのテストが `sort_by_key` を消すと落ちるかを確かめ、落ちなければ逆順の入力を加える。`broken_pipe_is_a_runtime_error` に `Process.exit(3)` の版を加える（届かなければ扱わないとして記録する）。
- 完了の条件:
  - `cargo test -p benitoite --lib ir::desugar::`
  - `cargo test -p benitoite --lib pipeline::tests::checking_sorts_each_stage_and_stops_before_later_errors`
  - `cargo test -p benitoite --test cli_process`

#### W6 testdata の細部（節 10・11）

- 内容: `l40-clock-handled.bnt` の `sleep` を 2 秒にして節を出力に残し、未使用の取り込みを消す。`l40-collections.bnt`・`l40-file-paths.bnt` の印を替える。`process_shell.bnt` の `tr` に `LC_ALL=C` を付ける。`fmt_comments.bnt`（と `.formatted`）・`test_replaces_effects.bnt` に印を加える。
- 完了の条件:
  - `BENITOITE_GOLDEN_FILTER=testdata/io/l40 cargo test -p benitoite --test golden`
  - `BENITOITE_GOLDEN_FILTER=testdata/stdlib/l40 cargo test -p benitoite --test golden`
  - `BENITOITE_GOLDEN_FILTER=testdata/acceptance cargo test -p benitoite --test golden`
  - `python3 tools/spec-coverage/spec_coverage.py` と `python3 tools/spec-coverage/spec_coverage.py --self-test`
- 小さいので、W2 か W5 と一つにまとめてもよい。

#### 作業の順と注意

- 推す順は W3 → W4（`tests/golden.rs` を続けて変える）→ W1 → W2 → W5 → W6。W1 は設計者の決定（節 1 の (B)/(C)、節 2）を待つので、決まるまで W3 から進めてよい。
- `src/refinterp/` を変える W1・W2 は、07-03 の「長いテスト」の決まりにより、選んだ検査で `--include-ignored` の長いテストが走る。`scripts/check.sh --dry-run` で選ばれる検査を確かめてから、時間の見込みを設計者に知らせる。
- 形式化の範囲（構文・型の規則・脱糖）は変えないので、`scripts/check-formal.sh` は要らない。
- 各作業で、テストを加える・変えるときは test-audit の作成時の関門を通し、退行テストは直す前のコード（または一時的に壊したコード）で落ちることを確かめる。

## TODO-185 の調査（コレクションとテキスト・データのモジュールの細部）

調べた時点: 2026-10-12、ブランチ san_benito（eb8dac11）。リポジトリのファイルは変えていない。cargo のビルドとテストは走らせていない。行番号は今のコードで確かめた（項目に書かれた行番号と違うものは、その旨を書く）。

文献の PDF と Coq の証明は、調査のときに一時的に取得して読んだ（リポジトリには置かない。出典は各節の URL）。

### 0. 全体の結論

| 点 | 分類 | 要点 |
|---|---|---|
| 1. 文献の確認 | 文書だけ（コメントと 02-08・03-06） | 3 件とも一次資料で確かめた。(3,2) の挿入・削除の平衡と、E_MAX = 2 の条件は、実装と一致する。集合演算の計算量は、論文の手順と実装の手順に二つの違いがあり、定理がそのまま当てはまるわけではない |
| 2. 平衡のテストの補強 | テストの直し | 昇順・降順の挿入、順の削除、大きさの偏った split・difference・intersection を、確保の数の上限で確かめるテストを足す |
| 3. 永続マップの小さな点 | 実装の直し（2 点）／扱わない（1 点）／コメントの直し（1 点） | `make` の `vec!` を配列に、`build_sorted` に並びの `debug_assert!`。空の木の鍵の確かめは扱わない |
| 4. `Map.toList`・`keys`・`values` の上限 | 実装の直し | `Set.toList` も同じ。先に `CheckedLen::elements` で確かめる |
| 5. 集合の演算と Decimal の表現 | 文書だけ（03-06 と `Set.bnt` の説明） | 実装は第一の集合の表現を保つ。設計書に書いて固定する |
| 6. `Bytes.slice` | 既に直っている（設計書）／扱わない（共有の表現）／実装の直し（軽微な 2 点） | 03-06 は今の実装（写す、O(n)）に合っている。項目を閉じるときに 03-06 の TODO の参照を付け替える |
| 7. `Csv.formatWith` の区切り | 実装の直し（互換性のない変更） | 設計者の決定どおり ASCII に限る。CHANGELOG に書く |
| 8. `Csv` の解析の寛容さとテストの穴 | 文書（03-08）とテストの直し | csv-core の振る舞いをソースで確かめた。`parseWith` の行の番号のテストは、実在の退行を捕まえる |
| 9. `Json` の誤りの報告 | 実装の直し（推奨）またはテストと文書／既に直っている（順序） | 入力の終わりの誤りの位置が揃わない仕組みを特定した。`1e-400` は文書とテストを足す |
| 10. `Decimal.fromFloat` の例 | 文書だけ（01-04）とテストの行 1 つ | 例を一行足す |

### 1. 永続コレクションの手順の根拠にした文献

#### 1.1 今のコードの箇所

- `crates/benitoite/src/runtime/map/tree.rs:8-9`（`DELTA = 3`、`GAMMA = 2`）、`:106-107`（コメント「重み size + 1 の原型の条件で回転する。一重の判定は厳密な < とする（Hirai・Yamamoto 2011 の 3.4 節）」）、`:108-141`（`balance`）、`:143-174`（`join`）、`:176-202`（`join2`）、`:429-430`（コメント「SPAA 2016 の join に基づく集合演算」）、`:431-510`（`combine`）。項目の `tree.rs:105-107` はほぼ今の位置である。
- `crates/benitoite/src/runtime/map.rs:3`（モジュールのコメントに Δ = 3、Γ = 2）。
- `crates/benitoite/src/runtime/list/rrb.rs:14`（`E_MAX = 2`）、`:361-362`（コメント「r > ceil(s / 32) + 2 のときだけ詰め直す」）、`:377-432`（`rebalance`）。
- 設計書: 02-08「値の表現」（`docs/design/02-impl/02-08-vm.md:47`）は「重みで平衡させる二分木」とし、「平衡の条件の定数は、処理系の実装で定める」と書く。03-06「Map と Set（初回リリース版）」の表は集合演算の計算量を O(m log(n/m + 1)) とする。03-06「List の内部の表現」は、連結の詰め直しの条件を書いていない。どの章も文献を引いていない。

指摘（文献を確かめた記録がない）は今も当てはまる。

#### 1.2 Hirai・Yamamoto 2011（(3,2) の重み平衡）

出典: Yoichi Hirai, Kazuhiko Yamamoto. "Balancing weight-balanced trees". Journal of Functional Programming 21(3): 287–307, 2011. doi:10.1017/S0956796811000104（Crossref で書誌を確かめた: <https://api.crossref.org/works/10.1017/S0956796811000104>）。本文は著者の版 <http://yoichihirai.com/bst.pdf>（ページの頭に「JFP 21 (3): 287–307, 2011」とある出版の体裁の版）、Coq の証明は <http://yoichihirai.com/Balance.v>（どちらも <https://www.mew.org/~kazu/proj/weight-balanced-tree/> からリンクされている）。

確かめたこと:

- 1 節（Introduction）の貢献の一覧: 挿入と削除が平衡を保つパラメータの範囲を厳密に定め、「⟨Δ, Γ⟩ = ⟨3, 2⟩ is the only integer solution in the range」。範囲の内側で挿入と削除が平衡を保つことを Coq で証明した（soundness）。
- 3.4 節（Original balancing method）: 重みは「size plus one」。`isBalanced a b = delta * (size a + 1) >= (size b + 1)`、`isSingle a b = (size a + 1) < gamma * (size b + 1)`（一重の回転の判定は厳密な `<`）。
- 7 節（Soundness）、図 7: `Lemma insert_balanced` と `Lemma delete_balanced`（`good_params` のもとで、平衡で大きさの情報が正しい木への挿入・削除の結果は平衡）。
- 7 節の「Set operations」の段落: union・difference・intersection が ⟨3, 2⟩ と ⟨5/2, 3/2⟩ で平衡を保つことも証明したが、その手順は Data.Set の hedge-union であり、join に基づく分割統治ではない。
- Coq のスクリプト（Balance.v、15,774 行、`Admitted` は 0 個。Coq 8.2pl1 で確かめたと冒頭に書かれている。私はコンパイルしていない）には、論文の本文が触れていない次の補題がある。
  - `Fixpoint join`（7304 行）: 左右の重みが釣り合わない間、重い側の内側の枝を下り、帰りに `balanceL`・`balanceR`（Γ による一重・二重の回転）をかける。
  - `Lemma join_balanced`（8201 行）: パラメータ `p32`（Δ = 3/1、Γ = 2/1。8137 行）のもとで、平衡な二つの木の `join` は平衡。
  - `Lemma splitLookupBalanced`（11234 行）、`Lemma intersectionWithKey_balanced`（11517 行。`p32`）、`deleteFindMin` の結果の平衡（5946 行付近）。

実装との対応:

- `balance`（tree.rs:108-141）は、3.4 節の条件と一致する。重みは `len + 1`（`weight`、:59-61）、回転するのは `rw > DELTA * lw`（つまり `isBalanced` の否定）、一重の回転は `weight(r.left) < GAMMA * weight(r.right)`（厳密な `<`）。コメントの「3.4 節」は正しい。
- `insert`（:219-269）は、論文の `insert`（3.3 節）と同じく、道筋を下って帰りに一段ずつ `balance` をかける。したがって (3,2) で挿入の後に平衡を保つことは、`insert_balanced` が当てはまる。
- `remove`（:271-303）は、論文の `delete` と、見つけたノードを消す手順が違う。論文（Balance.v の `delete`、6962 行）は `glue`（小さくない側から最小か最大を取り出し `balanceR`・`balanceL`）を使い、実装は `join2`（右の木から最小を取り出し、`join(最小, 左, 残り)`）を使う。`join2` の平衡は、Coq の `deleteFindMin` の平衡と `join_balanced` の合成で言えるが、`delete_balanced` そのものの対象ではない。祖先への一段ずつの `balance` は同じである。
- `join`（:143-174）は、Coq の `join` と同じ形（重い側の内側の枝を下り、帰りに Γ の判定付きの回転）である。一方が空の場合、Coq は `insert` を呼び、実装は空の木の重み 1 で比べ続けて最も外側まで下る。結果の形は同じ手順に当たるが、文字どおりの同一ではない。

結論: (3,2) が挿入と削除の後に平衡を保つことは、一次資料で確かめた。join の平衡の回復は、項目は「一次資料の証明の範囲外」としているが、論文に付いた Coq のスクリプトに `join_balanced`（`p32`）があり、範囲の内側と言える（論文の本文には書かれていない）。実装の `remove` と `join` の細部は Coq の定義と文字どおりには一致しないので、テスト（2 節）で補う方針は保つ。

#### 1.3 Blelloch・Ferizovic・Sun 2016（join に基づく集合演算の計算量）

出典: Guy E. Blelloch, Daniel Ferizovic, Yihan Sun. "Just Join for Parallel Ordered Sets". Proceedings of the 28th ACM Symposium on Parallelism in Algorithms and Architectures (SPAA 2016), pp. 253–264. doi:10.1145/2935764.2935768（Crossref で書誌を確かめた: <https://api.crossref.org/works/10.1145/2935764.2935768>。ACM の頁は 403 で読めなかった）。本文は arXiv の版 "Parallel Ordered Sets Using Join"（arXiv:1602.02120v4、2016-11-12。<https://arxiv.org/abs/1602.02120>）で読んだ。以下の節と定理の番号は arXiv v4 のものであり、SPAA の版の番号は確かめていない。

確かめたこと:

- 2 節（Preliminaries）: WB 木（BB[α]）は、各ノードで α ≤ w(T_L)/w(T) ≤ 1 − α（w は大きさ + 1）。2/11 < α ≤ 1 − 1/√2 で、挿入と削除を一重と二重の回転で行える。join にも同じ条件を求め、実験では α = 0.29。
- 3 節、図 4（`joinRightWB`）と Lemma 3: α ≤ 1 − 1/√2 ≈ 0.29 の WB 木の JOIN は正しく、O(|log(w(T_L)/w(T_R))|) の手間で、ランクが 1 + max(r(T_L), r(T_R)) 以下の木を返す。図 4 の回転の選び方は「一重の回転の結果が釣り合うなら一重、そうでなければ二重」（`like` による判定）であり、Hirai・Yamamoto の Γ の判定ではない。
- 4 節、図 1: UNION(T1, T2) は T2 の根の鍵で T1 を分割し、左右を再帰して JOIN する。INTERSECT は根が見つからないとき JOIN2、DIFFERENCE は常に JOIN2。
- Theorem 4（Main Theorem）と Theorem 7: 四つの平衡の方式（AVL・赤黒・WB・treap）で、大きさ m と n（n ≥ m）の二つの木の UNION・INTERSECT・DIFFERENCE の手間は O(m log(n/m + 1))。5 節の冒頭に「Since our proof works for either tree being larger」とあり、どちらの木が大きくても成り立つ。ただし証明は、分割の軸の木（pivot tree）を最初から最後まで T2 に固定した手順についてである。

実装との対応:

- Δ = 3 は α = 1/(1 + Δ) = 1/4 に当たり（私の換算。重み w_l·3 ≥ w_r は w_l/(w_l + w_r) ≥ 1/4 と同値）、2 節の範囲 2/11 < α ≤ 1 − 1/√2 に入る。
- 違い 1: 実装の `join` は Γ = 2 の判定で回転を選ぶ（1.2 節の Coq の `join`）。Lemma 3 は図 4 の `like` による選び方についての補題なので、実装の `join` の手間とランクの上界は、Lemma 3 からは直接は出ない。平衡は Coq の `join_balanced` で言えるが、手間とランクの上界（Theorem 4 の証明が使う性質）は、どちらの資料も実装の `join` について示していない。
- 違い 2: 実装の `combine`（tree.rs:475）は、再帰の各段で小さいほうの木の根を軸にする（`if an <= bn`）。図 1 の手順は軸を T2 に固定する。各段で軸を入れ替える手順は、Theorem 4 の証明の文字どおりの対象ではない。
- 和・共通部分で、両方にある要素は第一の集合（a）のノードを使う（:475-492。5 節を参照）。図 1 の UNION は T2 の根の鍵を使うので、この点も手順が違う（計算量には関わらない）。

結論: 03-06 の O(m log(n/m + 1)) は、文献の Theorem 4 と同じ形であり、目標として妥当である。ただし実装は論文の手順と二点で違うので、「文献の定理から言える」とは書けない。設計書は今の【決定】の計算量の表を保ち、テスト（2 節の確保の数の上限）で観察する。コメントには違いを書く。

#### 1.4 Bagwell・Rompf（RRB 木の E_MAX = 2）

出典: Phil Bagwell, Tiark Rompf. "RRB-Trees: Efficient Immutable Vectors". EPFL Technical Report, 2011（Infoscience の記録: <https://infoscience.epfl.ch/record/169879>、<https://infoscience.epfl.ch/items/c11dbc7a-2601-4228-b42b-466aa313f589>。PDF は RMTrees.pdf、<https://infoscience.epfl.ch/server/api/core/bitstreams/e5d662ea-1e8d-4dda-b917-8cbb8bb40bf9/content>。各ページの足に「2012/3/11」とある版）。

確かめたこと:

- 2.5 節（Summing Over Two Levels）: 一つの高さで a 個のノードに合わせて p 個の子があるとき、余分な線形探索の歩数は e = a − (⌊(p − 1)/m⌋ + 1)。⌊(p − 1)/m⌋ + 1 は p ≥ 1 で ⌈p/m⌉ に等しい。e が許す値を超えるときだけ詰め直す。
- 同じ節（4 ページ）: 「With m = 32 empirical testing shows that setting e = 2 gives a good compromise」。e = 2 は実験で選んだ値であり、証明した値ではない。
- 同じ節: 詰め直しは、左から m − e/2 以上の子を持つノードを飛ばし、最初の小さいノードから右へ、数が一つ減るまで写す手順（発見的な手順。「Alternative algorithms ... could be used as well」とある）。
- 4 節（Splits and Insert At）: 分割で作った木は、ある高さで e を一つ超えることがあり、後の連結で戻すとする。

実装との対応:

- 詰め直すかの条件（rrb.rs:388-392）は `nodes.len() > ceil(slots / 32) + E_MAX`、`E_MAX = 2`。2.5 節の a > ⌈p/m⌉ + e（m = 32、e = 2）と一致する。
- 詰め直しの手順は違う。実装は、先頭から続く満ちたノードだけを共有し、最初の満ちていないノードから後をすべて 32 個ずつ詰める（:394-430。結果のノードの数はちょうど ⌈p/32⌉ になり、`debug_assert_eq!(result.len(), ideal)` で確かめている）。論文の手順より詰める量が多いが、各高さで写す量は O(m²) で抑えられ、論文も別の手順を許している。
- 分割（`List.take` など）が e を超える木を作りうる点は、論文の 4 節と同じ性質である。03-06「List の内部の表現」は高さを O(log n) とし、性能の測定で観察するとしているので、食い違いはない。

結論: E_MAX = 2 の条件は、論文の 2.5 節と一致する。e = 2 の根拠は論文の実験であり、証明ではない。

#### 1.5 直し方の具体案

- コメント（AGENTS.md「コメントと名前」に従い、設計書の節を根拠に示す）:
  - tree.rs:106-107 を「（設計書 02-08「値の表現」。条件は Hirai・Yamamoto 2011（JFP 21(3)）の 3.4 節の原型の WBT と同じ）」の形にする。
  - tree.rs の `join` の前に「平衡は、同論文の Coq の証明の `join_balanced`（Δ = 3、Γ = 2）と同じ手順で保つ」と一行。
  - tree.rs:429-430 を「（設計書 03-06「Map と Set（初回リリース版）」の計算量。手順は Blelloch・Ferizovic・Sun 2016 の図 1 の分割と join。各段で小さいほうの木を軸にし、Γ の判定で回転する join を使う点が論文と違う）」の形にする。
  - rrb.rs:361-362 に「（設計書 03-06「List の内部の表現」。条件は Bagwell・Rompf 2011 の 2.5 節の e = 2。詰め方は論文より強く、⌈s/32⌉ 個に詰める）」を足す。
- 設計書（設計者が決める。4 節の推奨を見る）:
  - 02-08「値の表現」の「平衡の条件の定数は、処理系の実装で定める」を、「平衡の条件は、重みを要素の数 + 1 とする原型の条件で、Δ = 3、Γ = 2 とする。理由: 挿入と削除の後に平衡を保つ整数の組はこれだけであることが、Coq で証明されている（Hirai・Yamamoto 2011、JFP 21(3)、1 節・7 節）。」に替える。
  - 03-06「List の内部の表現」の箇条に、「連結は、各高さでノードの数が ⌈子の数 / 32⌉ + 2 を超えるときだけ、その高さのノードを詰め直す。理由: 添字の探索の余分な歩数を 2 までに抑え、連結で写す量を減らす（Bagwell・Rompf 2011 の 2.5 節が、分岐の数 32 で実験から選んだ値）。」を足す。
  - 03-06 の集合演算の計算量は今の表を保つ（1.3 節の違いがあるので、文献の定理として書かない）。
- CHANGELOG: 不要（振る舞いを変えない）。

#### 1.6 設計者に決めてもらう点

- 02-08 に (3,2) と出典を書くか。推奨: 書く。理由: 定数は木の振る舞いの根拠であり、一次資料で確かめた事実なので、AGENTS.md の「事実と出典」の条件を満たす。今の「実装で定める」のままだと、実装のコメントだけが根拠になる。
- 03-06 に E_MAX = 2 の条件を書くか。推奨: 書く。理由は同じ。ただし e = 2 は実験で選んだ値と書く。
- 集合演算の手順を論文に揃える（軸を第二の集合に固定する）か。推奨: 揃えない。理由: 計算量の定理がそのまま当てはまるのは図 1 の手順だが、実装の `join` も論文の `join` と違うので、軸だけを揃えても定理の対象にはならない。確保の数の上限のテストで観察するほうが、退行を捕まえられる。

### 2. 永続マップの平衡のテストの補強

#### 2.1 今のコードの箇所

`crates/benitoite/src/runtime/map/tests.rs`（451 行）のテストは四つ。

- `randomized_operations_match_models_and_preserve_inputs_across_collection`（:62）: 鍵 0〜256 の小さな範囲で 2,400 歩。
- `equal_decimal_keys_keep_the_first_representation_in_updates_and_set_operations`（:157）。
- `key_order_is_lexicographic_for_all_key_kinds_and_rejects_invalid_values`（:202）。
- `million_element_trees_support_updates_and_union_shares_the_large_input`（:354、長いテスト）: 整列した 100 万要素の構築、大きい集合と 7 要素の集合の union の確保の数（`64 * 7 * log` 以下）、512 個の削除。

昇順・降順の挿入、順の削除、大きさの偏った split・difference・intersection のテストはない。指摘は今も当てはまる。なお、平衡の条件そのものは `make`（tree.rs:93）の `debug_assert!` が、作るノードごとにデバッグビルドで確かめている（03-06 が定める確かめ方）。したがって、昇順の挿入などの操作の列をデバッグビルドで流すだけで、平衡の崩れは panic として現れる。

#### 2.2 分類

テストの直し。

#### 2.3 直し方の具体案

`runtime/map/tests.rs` に、表の形のテストを一つ足す（test-audit の作成時の関門の答え: 1. 03-06 の O(log n) の更新と、道筋の外のノードを共有する契約を守る。2. 回転の条件の取り違え（`<` と `<=`、Δ と Γ の入れ替え）、`join`・`join2` の平衡の回復の漏れで、木が偏り道筋が長くなる退行を捕まえる。3. 既存のテストは鍵が 257 種類で木が浅く、昇順の挿入のような偏った列を含まない。4. 差し込み口は要らない。`heap.stats().allocations` は既存の長いテストが使っている）。

- 名前の案: `skewed_workloads_keep_update_paths_logarithmic`。
- 大きさ: n = 2^15（32,768）程度。HeapConfig は `stress: false`（既定）にして時間を抑える。10 秒を超えそうなら n を下げる（AGENTS.md「テストの運用」）。100 万要素は既存の長いテストに任せる。
- 筋書き（各操作の前後の `heap.stats().allocations` の差を測る。一つの `epoch` で一つの操作を行う）:
  1. 空の木へ 0..n を昇順に `map_insert`、別の木へ降順に `set_insert`。各挿入の確保の数が `C_insert * (log2(n) + 1)` 以下。
  2. できた木から 0..n/2 を昇順に `map_remove`・`set_remove`。各削除の確保の数が `C_remove * (log2(n) + 1)` 以下。
  3. 大きさ n の集合（`set_from_sorted`）と 7 要素の集合で、`set_difference`・`set_intersection` を両方の順に（大・小、小・大）。確保の数が既存の union の上限と同じ形（`64 * 7 * log`）以下。
  4. 各段の後に、モデル（`BTreeSet`・`BTreeMap`）と内容を突き合わせる（既存の `contents`・`elements` を使う）。
- 定数の根拠（コメントに書く。私の導出であり文献の値ではない）: Δ = 3 の木では子の重みが親の重みの 3/4 以下なので、高さは log_{4/3}(n + 1) ≈ 2.41·log2(n + 1) 以下。挿入は道筋の各段で高々 3 個のノードを作るので、`C_insert = 8` で足りる。削除は、道筋に加えて `join2` の最小の取り出しと `join` の下りがあるので `C_remove = 24` 程度。Codex には、上限を導出から決め、実測の最大値も一度確かめてから余裕を持たせるよう指示する。
- 鍵は `Value::Int` だけでよい（鍵の種類による違いは既存の無作為のテストが確かめている）。

#### 2.4 設計者に決めてもらう点

- 大きさを 10^4〜10^5 のどこに置くか。推奨: 2^15 で普通のテスト、超えるなら長いテスト（`#[ignore = "long: ..."]`）。理由: 道筋の長さの退行は 2^15 で十分に現れ、全体の検査を待たずに捕まえられる。

### 3. 永続マップの小さな点

#### 3.1 空の木で鍵の型でない値を拒まない（`find`・`remove`・`split`）

- 箇所: tree.rs:203-218（`find`）、:271-303（`remove`）、:305-338（`split`）。木が空なら `compare_keys` を呼ばずに返す。`insert`（:230）だけが、空の場所で `compare_keys(ctx, key, key)` を呼んで、鍵の型でない値を `Stop::Internal` にする。指摘は今も当てはまる。
- 分類: 扱わない。理由: 型検査を通ったプログラムでは届かない（鍵は鍵の型）。`insert` の確かめは、不正な値を木に入れて後の比較を壊さないためのものであり、`find`・`remove`・`split` は鍵を木に入れないので、不正な値で木が壊れることはない。加えると、空の木への問い合わせでも、複合の鍵の全体を辿る比較が一回増える。
- 直すなら（任意）: `find` の前に、`insert` の確かめが何のためにあるかを一行のコメントで書く。

#### 3.2 `build_sorted` に並びの `debug_assert!` がない

- 箇所: tree.rs:339-381。呼び出し元は `map_from_sorted`・`set_from_sorted`（map.rs:22-29、:75-83）で、定数の記述（02-07「定数表」）と Csv の見出し（csv.rs:248。整列済み）から呼ばれる。指摘は今も当てはまる。
- 分類: 実装の直し（デバッグビルドだけの確かめ）。
- 直し方: `build_sorted` の先頭に `debug_assert!(pairs.windows(2).all(|w| matches!(w, [a, b] if matches!(compare_keys(ctx, a.0, b.0), Ok(Ordering::Less)))));` の形を置く（`compare_keys` は `super` から使える。添字を使わない形にする）。テストは足さない（既存の無作為のテストと Csv の見出しのテストが、デバッグビルドでこの確かめを通る）。

#### 3.3 `tree.rs` のコメントが根拠を設計書の節で示していない

- 箇所: tree.rs:106-107、:429-430。文献だけを引き、設計書の節を引いていない。
- 分類: コメントの直し。内容は 1.5 節。

#### 3.4 `make` の `vec![]` の確保

- 箇所: tree.rs:94-97。ノードを作るたびに、欄の並びを `Vec` に確保してから `alloc_fields` に渡す。
- 分類: 実装の直し（振る舞いを変えない）。
- 直し方: 分岐ごとに配列のまま渡す。
  ```rust
  let result = match self {
      Self::Map => ctx.alloc_fields(self.kind(), count, &[n.key, n.value, left, right])?,
      Self::Set => ctx.alloc_fields(self.kind(), count, &[n.key, left, right])?,
  };
  ```
  テストは足さない（既存のテストが同じ結果を確かめる）。

#### 3.5 軽微な点（項目にないが見つけたもの）

- map.rs の `map_from_sorted`・`map_insert`・`set_from_sorted`・`set_insert`・`set_union` が `function` を受け取って `let _ = function;` で捨てている（:27、:50、:80、:99、:113）。扱わない（公開の口の変更になり、この項目の範囲を超える）。

### 4. `Map.toList`・`keys`・`values` の上限の確かめ

#### 4.1 今のコードの箇所

- `crates/benitoite/src/builtins/funcs/map.rs:39-43`（`Map.toList`）: `map_to_vec` で全部の組を集め、組ごとに `Pair` の対象をヒープに確保し、最後に `list::from_values` が長さを確かめる。
- 同 `:420-423`（`Map.keys`）、`:429-432`（`Map.values`）: 全部を集めた後に `list::from_values` で確かめる。
- 項目にないが同じ形: `crates/benitoite/src/builtins/funcs/set.rs:32-34`（`Set.toList`）。

指摘は今も当てはまる。`Map.set` を繰り返せば 2^24 を超えるマップを作れるので、上限を超えるマップの `Map.toList` は、2^24 個を超える `Pair` を確保した後で `ValueTooLarge` になる。02-09「一つの操作で作る値の大きさの上限」の「値を作り始める前に、引数から計算する」に反する。

#### 4.2 分類

実装の直し。CHANGELOG は不要（止まり方は同じ `ValueTooLarge` で、違いは途中の確保の量だけ）。

#### 4.3 直し方の具体案

- 四つの関数の先頭で、`CheckedLen::elements(u64::from(map::map_len(&ctx, xs)?), "Map.toList")?;` の形で確かめてから集める（`Set` は `map::set_len`）。`list::from_values` の確かめは残る（二重になるが、共通の関数の中なので害はない）。
- 共通の補助（例: `fn checked_len(len: u32, function) -> Result<(), Stop>`）を `builtins/funcs/map.rs` に置くかは実装者に任せる。
- 設計書: 変更なし（規約どおりにする直し）。

#### 4.4 テスト

上限を超えるマップを作るには 2^24 + 1 個のノードが要り、メモリと時間が大きい（ノード一つが欄 3〜4 個なので、1 GB 前後と見込む。測っていない）。

推奨: テストを足さない。理由: 確かめる順の入れ替えだけで、上限の判定そのものは `CheckedLen` の共通のテスト（`builtins/funcs/mod.rs` の `growing_values_are_rejected_before_heap_allocation` など）が守る。足すなら、`set_from_sorted` で 2^24 + 1 要素の集合を作り、`Set.toList` が `ValueTooLarge` を返し、その間の `heap.stats().allocations` が増えないことを確かめる長いテスト（`#[ignore = "long: ..."]`）にする。直す前のコードでは確保が増えるので、退行テストとして意味を持つ。設計者に決めてもらう。

### 5. 集合の演算と Decimal の表現

#### 5.1 今のコードの箇所

- `crates/benitoite/src/runtime/map.rs:106-115`（`set_union`、説明「同じ要素では第一の集合の表現を保つ」）、`:116-123`（`set_intersection`、同じ説明）。項目の `map.rs:107`・`117` はこの位置である。
- 実際に表現を選ぶのは tree.rs:475-492。a が小さければ a の根のノードを軸にし、b が小さければ b の根で a を分割して、見つかった a のノード（`found.unwrap_or(n)`）を使う。`Set.difference` は a の要素だけを残す。
- テスト: `runtime/map/tests.rs:157-200`（`1.0m` と `1.00m`、a が小さい場合と大きい場合の両方）。
- 設計書: 03-06「Map と Set（初回リリース版）」の鍵の順序の段落の最後（`docs/design/03-interop/03-06-stdlib.md:333`）は、`Map.set`・`Set.add`・`Map.fromList` などで元の鍵を保つと書くが、集合どうしの演算は書いていない。
- 標準ライブラリのソース `crates/benitoite/src/prelude/stdlib/Set.bnt` の `union`・`intersection` の説明にも書いていない（`Set.add` には「An existing element keeps its original form.」とある）。

指摘は今も当てはまる。

#### 5.2 分類

文書だけ（実装とテストは既にある）。

#### 5.3 直し方の具体案

- 03-06 の同じ段落に一文を足す: 「`Set.union` と `Set.intersection` は、両方の集合にある要素について、第一の集合の要素を保つ。`Set.difference` の結果の要素は、どれも第一の集合の要素である。」
- `Set.bnt` の説明: `union` に「An element in both sets keeps its form from `a`.」、`intersection` に「Each element keeps its form from `a`.」を足し、`cargo run -p benitoite --example gen_skill` で `skill/references/stdlib/Set.md` を作り直す（`tests/skill_docs.rs` が古さを検出する）。
- CHANGELOG: 不要（振る舞いを変えない）。

軽微な点（モデルとの比較に表現の違う Decimal の鍵を混ぜる、長い `match` の分岐、テストの鍵の補助を共有のモジュールに分ける）は、扱わない。理由: 表現の保存は 5.1 の専用のテストが a の大小の両方で確かめており、無作為のテストに混ぜても新しい退行は捕まえない。残りの二つは見た目の整理で、守る契約がない。

#### 5.4 設計者に決めてもらう点

- 集合の演算で第一の集合の表現を保つことを明記するか。推奨: 明記する（今の振る舞いを固定する）。理由: 実装とテストは既にこの振る舞いを守っており、`Set.add` などの「元の鍵を保つ」と揃う。書かないと、`Decimal` の桁数が表記（`Decimal.toString`）に現れるので、利用者に見える振る舞いが未定のまま残る。

### 6. `Bytes.slice`

#### 6.1 今のコードの箇所

- `crates/benitoite/src/builtins/funcs/bytes.rs:121-131`（`Bytes.slice`）。コメントは「正しい範囲なら部分のバイト列を写して作る（設計書 03-06「Bytes と ByteOrder（初回リリース版）」）」で、項目が書く「実装プランの 10-15 の表現の例外」という文言は既にない。
- 設計書: 03-06 の表（`03-06-stdlib.md:353`）は計算量を O(n) とし、`:368` は「元の値と領域を共有せず、範囲のバイトを新しい値に写して作る」「元の領域を共有して開始位置と長さだけを変える表現は、初回リリース版に含めない（docs/todo の TODO-185）」と書く。項目の「設計書を今の実装に合わせる直し」は済んでいる。
- 軽微な点 1: `bytes.rs:322` の `out.copy_from_slice(bytes);`（`write_integer` の大きい端の順の分岐）。`out` と `bytes` の長さはどちらも `count` なので今は panic しないが、長さが違えば panic する関数であり、隣の小さい端の分岐（:324-326）は zip の形で書いている。
- 軽微な点 2: `bytes.rs` のテストの `as`（:415、:421、:522、:554、:635、:648、:650、:682、:683、:695、:697）。

#### 6.2 分類

- 共有の表現: 扱わない（測定の後に決める）。
- 設計書を合わせる直し: 既に直っている。
- 軽微な 2 点: 実装の直し（テストのコードを含む）。

#### 6.3 直し方の具体案

- `:322` を `for (dst, src) in out.iter_mut().zip(bytes) { *dst = *src; }` にする（AGENTS.md「失敗を panic で表さない」の趣旨に揃える）。
- テストの `as` を `u8::try_from(i % 256).unwrap()`・`i64::try_from(bytes.len()).unwrap()`・`usize::try_from(count).unwrap()` の形にする。テストの中は `unwrap` を許している。`(1i128 << bits) - 1` の `as i64` は `i64::try_from(...).unwrap()` にする。
- 項目を閉じるとき（オーケストレータの作業）: 共有の表現の検討を docs/todo に新しい項目として移し、03-06:368 の「（docs/todo の TODO-185）」を新しい番号に付け替える。付け替えを忘れると、閉じた項目を指す参照が設計書に残る。
- CHANGELOG: 不要。

### 7. `Csv.formatWith` の区切り

#### 7.1 今のコードの箇所

- `crates/benitoite/src/builtins/funcs/csv.rs:58-64`（`format_with`。説明「ASCII でない区切りも書く」、`delimiter(arg1, false, ...)`）、`:66-77`（`delimiter`。`ascii` が偽なら ASCII を確かめない）。項目の行番号（62、66-70）とほぼ同じ。
- テスト: `csv.rs:590-634`（`delimiters_enforce_argument_domain_and_support_ascii_and_unicode_output`）は、`:628-632` で `'、'` と `'é'` の区切りの出力を固定している。
- 設計書: 03-08「Csv」の最後の箇条（`03-08-text-and-data.md`）は「`Csv.parseWith` の `delimiter` は ASCII の文字に限る」だけ。
- 標準ライブラリのソース: `crates/benitoite/src/prelude/stdlib/Csv.bnt:13-15`・`:25-27` の説明は区切りの制限を書いていない。生成物 `crates/benitoite/skill/references/stdlib/Csv.md` も同じ。
- ゴールデンテスト: `testdata/stdlib/l40-csv.bnt:14` は `formatWith(tabbed, ';')`（ASCII）なので影響しない。`testdata/stdlib/l40-csv-invalid-delimiter.bnt` は `parseWith(..., 'é')` の停止を確かめる。

#### 7.2 分類

実装の直し（互換性のない変更）。設計者が決めたとおり、ASCII でない区切りを実行時エラー（引数が定義域の外）にする。

#### 7.3 直し方の具体案

- `csv.rs:62` を `delimiter(arg1, true, "Csv.formatWith")` にする。すると `delimiter` の引数 `ascii` が常に真になるので、引数を消して ASCII の確かめを常に行う形に簡素化する（`parse_with`・`format_with` の両方が同じ規則になる）。`:59` の説明を「区切りは ASCII に限る」に直す。
- 戻り値を `char` のままにするか `u8` にするかは実装者に任せる（`parse_with` は `u8` に変えている。:35-36）。
- テスト（`csv.rs:590-634`）: 名前を `delimiters_must_be_ascii_and_not_quote_or_line_breaks` などに改め、`'、'`・`'é'` で `format_with` も `ArgumentOutOfDomain { function: "Csv.formatWith", argument: 1 }` を返すことを、`parse_with` と同じ表で確かめる。`:628-632` の Unicode の出力の確かめは消す。`rows` の `"a、b"`・`"é"` は、ASCII の区切りでの往復の確かめに残してよい。
- ゴールデンテストは足さない（CLI からの停止は `l40-csv-invalid-delimiter` が `parseWith` で確かめており、`formatWith` の配線は単体テストで届く）。
- 03-08 の最後の箇条を「`Csv.parseWith` と `Csv.formatWith` の `delimiter` は ASCII の文字に限る。ASCII でない文字を指定すると、実行時エラー（引数が定義域の外）とする。理由: `Csv.formatWith` で書いたものを、同じ区切りの `Csv.parseWith` で読み戻せるようにするため。」にする。
- `Csv.bnt` の `parseWith`・`formatWith` の説明に「`delimiter` must be an ASCII character other than `"`, CR, and LF.」を足し、`gen_skill` で作り直す。
- CHANGELOG（`CHANGELOG.md` の Unreleased、「Some functions and commands also behave differently.」の表）に一行足す。案: 「`Csv.formatWith` stops with a runtime error (argument out of domain) when `delimiter` is not an ASCII character, as `Csv.parseWith` already did. Before, it wrote such a delimiter, and the output could not be read back with `Csv.parseWith`.」／移行: 「Use an ASCII delimiter, or join the fields yourself with `String.join`.」

### 8. `Csv` の解析の寛容さとテストの穴

#### 8.1 今のコードの箇所と、確かめた振る舞い

- 解析は csv-core 0.1.13（`crates/benitoite/Cargo.toml:25`、`=0.1.13`）の `Reader`（`csv.rs:173`）。csv-core のソース（`~/.cargo/registry/src/*/csv-core-0.1.13/src/reader.rs:980-1060`、`transition_nfa`）で確かめた。
  - 閉じた引用符の後の文字（`InDoubleEscapedQuote` で区切り・行末・引用符のどれでもない文字）は、`InField` に移って出力に写す。したがって `"abc"x` は `abcx` になり、誤りにならない。続く `"` も `InField` でそのまま写す。
  - 引用符で始まらないフィールドの中の `"`（`InField`）は、そのまま写す。`a"b` は `a"b`。
  - 先頭の BOM は、最初の `read_field` の呼び出しで、入力が BOM で始まるときだけ読み飛ばす（`strip_utf8_bom`、:610-619。`has_read` で一度だけ）。
- 処理系の位置の追跡（`csv.rs:106-154`、`Position`）は、閉じた引用符の後の文字を `Plain` とし（:137-139）、csv-core と同じ状態を辿る。
- テスト: `csv.rs:424` の `("a\"b,\"c\"\"d\"", ...)` が `a"b` を受け付ける振る舞いを固定している（項目の行番号のとおり）。`"abc"x` の場合はない。
- 03-08 は「RFC 4180 の CSV を読み書きする」とし、寛容さを書いていない。

テストの穴の確認:

- `""` の組や引用符の中の CR LF が、出力の 4 KiB の境界をまたぐ場合: `long_fields_preserve_utf8_and_quotes_across_reader_output_chunks`（:636-652）は、`"x" × 4095` の後に `é😀"\r\n` を置き、境界は `é` の途中に来る。`""` と CR LF は境界から数バイト後ろで、境界をまたがない。なお境界は csv-core の出力（`written`）の区切りであり、入力の消費（`consumed`）もそこで切れる。`Position` は状態（`AfterQuote`、`previous_cr`）を呼び出しをまたいで持つので、正しく扱えるはずだが、確かめるテストはない。
- `parseWith` の `ParseError.line`: 誤りのテスト（:434-483）は `parse` と `parseWithHeader` だけ。`Position::consume` は区切りを引数で受け取り（:127、:138）、`read_csv` は `parseWith` の区切りを渡している（:195）。もし `,` を渡す退行が起きると、`a;"x` の `"` を `Plain` の途中とみなし、csv-core が引用符の中にいるのに `UNCLOSED_QUOTE` を返さず（:199）、閉じていない引用符を誤りにしなくなる。このテストは現実的な退行を捕まえる。
- `[]` の行の後の BOM のフィールド: `Csv.format([[], ["\u{feff}x"]])` は、最初の行で出力が空でなくなるので（:312 の `leading_bom` は出力が空のときだけ）、BOM のフィールドを引用符で囲まず `"\n\u{feff}x\n"` と書く。読み直すと、入力は BOM で始まらないので csv-core は BOM を飛ばさず、`[["\u{feff}x"]]` になる（`[]` の行が消えるのは 03-08 の既定の振る舞い）。BOM は保たれるので不具合ではないが、テストはない。

#### 8.2 分類

文書（03-08）とテストの直し。

#### 8.3 直し方の具体案

- 03-08「Csv」の箇条に足す: 「解析は、RFC 4180 に合わない次の入力も誤りにせず受け付ける。引用符で始まらないフィールドの中の引用符は、そのまま文字として読む（`a"b` は `a"b`）。閉じた引用符の後に区切りか行の終わりが来ないときは、続く文字をフィールドに加える（`"abc"x` は `abcx`）。誤りにするのは、閉じていない引用符だけである。理由: 実装に使う `csv-core`（0.1.13）の解析がこれらを受け付け、スクリプトが扱う手で書いた CSV を読めるほうが利用者に役立つ。」（理由の後半は設計者の判断に委ねる。少なくとも事実は書く）
- テスト（すべて `csv.rs` の既存のテストに行を足す形）:
  1. `parse_records_with_newlines_quotes_empty_fields_and_unequal_widths` の表に `("\"abc\"x,y", vec![vec!["abcx", "y"]])` と `("\"a\"b\"c", vec![vec!["ab\"c"]])` を足す（03-08 に書く振る舞いを固定する）。
  2. `parse_errors_point_to_record_start_across_blank_lines_and_multiline_fields` に、`parseWith` の場合を足す。表に区切りの列を加え、`("a;b\n1;\"x", ';', 2, UNCLOSED_QUOTE)`、`("a;b\r\n\r\n\"first\nsecond", ';', 3, UNCLOSED_QUOTE)` などを `parse_with` で確かめる。
  3. 4 KiB の境界: 境界の前後の位置（`k = 4093..=4097` など）を回す表の形のテストにする。各 `k` で、フィールド `"x" × k + "\"" + "\r\n" + "y"` の行と、次の行に閉じていない引用符を置いた入力を作り、(a) `format` → `parse` の往復で値が等しいこと、(b) 閉じていない引用符の `ParseError.line` が 3（引用符の中の CR LF を 1 行と数える）であることを確かめる。既存の長いフィールドのテストに入れるか、別のテストにするかは実装者に任せる（作成時の関門の 3 の答え: 既存のテストは境界の位置を一つしか試さず、`""` と CR LF が境界をまたがない）。
  4. BOM: `format_quotes_special_fields_and_round_trips_comma_and_tab` の BOM の確かめに、`[[], ["\u{feff}x"]]` を `format` すると `"\n\u{feff}x\n"` になり、`parse` で `[["\u{feff}x"]]` になることを足す。
- CHANGELOG: 不要（振る舞いを変えない）。

### 9. `Json` の誤りの報告の細部

#### 9.1 入力の終わりの誤りの位置

今のコードの箇所:

- `crates/benitoite/src/builtins/funcs/json.rs:48-68`（誤りの位置の決め方）、`:75-83`（`character_column`）。
- テスト: `json.rs:752-753` の `("\"é", 1, 2, ...)` と `("[1,\n", 2, 1, ...)`。項目の `json.rs:534` は今は :753。統合テスト `tests/l21_json.rs:146-148` も `"[1,\n"` を 2 行 1 列で確かめる。

仕組み（serde_json 1.0.151 の `read.rs:421-430`、`position_of_index` で確かめた）: serde_json の誤りの位置は、最後に読んだ文字の位置（列は 1 から数えたバイト数）である。入力の終わりでは、最後の文字の位置になる。ただし最後の文字が LF なら、次の行の列 0 になり、処理系の `character_column` が `.max(1)` で列 1 にする。このため次のように揃わない。

| 入力 | 今の行・列 | 指す位置 |
|---|---|---|
| `[1,` | 1・3 | 最後の文字 `,` |
| `"é` | 1・2 | 最後の文字 `é` |
| `[1,\n` | 2・1 | 最後の文字の直後 |
| （空の入力） | 1・1 | 直後（列 0 を 1 にした） |

指摘は今も当てはまる。03-08 は数え方（1 から、文字位置 + 1）だけを定め、入力の終わりの誤りの位置を定めていない。

分類: 実装の直し（推奨）。または文書とテストだけ（代替案）。

直し方の具体案（推奨案 a）:

- `error.classify() == serde_json::error::Category::Eof`（serde_json の `error.rs:53-61` で、`EofWhileParsingList`・`Object`・`String`・`Value` がこの分類）のときは、位置を入力の終わりの直後にする。行は入力の LF の数 + 1、列は最後の LF の後の文字の数 + 1。serde_json と同じく LF だけで行を数える。
- 結果: `[1,` は 1・4、`"é` は 1・3、`[1,\n` は 2・1（今と同じ）、空の入力は 1・1、`   ` は 1・4。
- 03-08「Json」の `line`・`column` の箇条に足す: 「誤りの位置は、誤りを見つけた文字の位置である。入力が途中で終わった誤り（閉じていない配列・オブジェクト・文字列、値のない入力）は、入力の最後の文字の直後の位置とする。」
- テスト: `json.rs:752` の `"é` の期待を 1・3 に直し、`("[1,", 1, 4, "EOF while parsing a value")`、`("", 1, 1, "EOF while parsing a value")`、`("[1,\r\n", 2, 1, ...)` を足す。`tests/l21_json.rs` は変えなくてよい（`[1,\n` は同じ）。
- CHANGELOG: 要る（誤りの列が変わる。互換性のない変更の表の「behave differently」に一行。案: 「`Json.ParseError.column` of an error at the end of the input, such as an unclosed array or string, points just after the last character. Before, it pointed at the last character unless the input ended with a line feed.」）。

代替案 b: 今の振る舞いを 03-08 に書いて固定する（「入力が途中で終わった誤りは、最後の文字の位置とする。ただし入力が LF で終わるときは、その次の行の 1 列目とする。」）。テストに `("[1,", 1, 3, ...)` を足す。CHANGELOG は不要。

#### 9.2 `1e400` と構文の誤りが両方あるときの報告の順

- 分類: 既に直っている。03-08「Json」は「入力に誤りが複数あるときは、入力の先頭から読んで最初の誤りを `Json.ParseError` として返す」と定めている。実装は serde_json の逐次の読みの中で数を `Visitor` から分類するので（`json.rs:225-240`）、先に現れた誤りを返す。テストは `json.rs:762-763` の `("[1e400,}", 1, 2, NUMBER_OUT_OF_RANGE)` と `("[},1e400]", 1, 2, "expected value")` で両方の順を固定している。
- 項目の「定めがない」は、この定めとテストが入る前の所見と思われる。直すことはない。

#### 9.3 `1e-400` が `0.0` になる

- 箇所: `json.rs:108-118`（`number_value`）。`"1e-400".parse::<f64>()` は `0.0`（有限）なので `Json.Value.Float(0.0)`、`-1e-400` は `-0.0`。serde_json（`float_roundtrip`）も誤りにしない。テストの表（`json.rs:592-606`）に行がない。03-08 は「`Float` の範囲も超える数は、解析の誤りとする」とだけ書き、小さすぎる数を書いていない。指摘は今も当てはまる。
- 分類: 文書とテストの直し。
- 直し方: 03-08「Json」の数の箇条に「絶対値が小さすぎて 0 に丸められる数は誤りにせず、符号を保った 0 の `Json.Value.Float` にする（`1e-400` は `Json.Value.Float(0.0)`、`-1e-400` は `Json.Value.Float(-0.0)`）。`Float.parse` と同じである（[基本型の意味論](../01-spec/01-04-types-basic.md)）。」を足す。テストの表に `("1e-400", 0.0, "0.0")` と `("-1e-400", -0.0, "-0.0")` を足す（`to_bits` で比べるので符号も確かめられる）。
- CHANGELOG: 不要。

#### 9.4 設計者に決めてもらう点

- 入力の終わりの誤りの位置を、案 a（最後の文字の直後に揃える）と案 b（今の振る舞いを書く）のどちらにするか。推奨: 案 a。理由: 規則が一文で書け、LLM と利用者が位置から誤りを見つけやすい。案 b の規則は serde_json の内部の数え方を写したもので、LF で終わるかどうかで指す位置が変わる。変更は列だけで、行は変わらず、統合テストの `[1,\n` の期待も変わらない。基本の方針（今の振る舞いを固定する）を選ぶなら案 b でもよい。

### 10. `Decimal.fromFloat` の例

#### 10.1 今のコードの箇所

- 設計書: 01-04「型の変換」の表（`docs/design/01-spec/01-04-types-basic.md:266`）。「`Float.toString(x)` の表記が表す数を、`Decimal` の値として読んだもの」とだけ書き、指数の表記（`1.0e+21`、`1.5e-7`。同じ章の `Float.toString` の規則、:276）のときの小数の桁数が読み取れない。
- 実装: `crates/benitoite/src/builtins/funcs/decimal.rs:108-150`（`float_decimal`）。指数を展開してから小数の桁数を決める（`1.0e+21` は桁数 0 で `1000000000000000000000`、`1.5e-7` は 8 で `0.00000015`、`0.1` は 1、`0.0` は 1 で `0.0`）。
- テスト: `decimal.rs:340-356` の表に `1e21` の行（:345）はあり、`1.25e-27` などの負の指数の丸めの行もある。`1.5e-7`（丸めのない負の指数）の行はない。

指摘は今も当てはまる（文書）。

#### 10.2 分類

文書だけ（01-04）と、テストの行を一つ。

#### 10.3 直し方の具体案

- 01-04 の表の `Decimal.fromFloat` の欄の後ろ（または表の後の段落）に一文を足す: 「小数の桁数は、表記の指数を展開した後の小数点の後の桁数である（`Decimal.fromFloat(1.0e21)` は小数の桁数 0 の `1000000000000000000000`、`Decimal.fromFloat(1.5e-7)` は 8 の `0.00000015`、`Decimal.fromFloat(0.1)` は 1 の `0.1`）。」
- 01-04 は `01-spec/` なので、` ```text ` のブロックに入れたときは `cargo test --test spec_examples` の対象になる。表の中か本文に書くなら対象にならない。
- テスト: `decimal.rs:340` の表に `(1.5e-7, "0.00000015")` を足す（設計書の例と同じ値を確かめる）。
- CHANGELOG: 不要。

#### 10.4 設計者に決めてもらう点

- 例を足すか。推奨: 足す。理由: 小数の桁数は `Decimal.toString` に現れる利用者に見える値で、今の文からは指数の表記のときの値を導けない。

### 11. 作業の分け方の案

Codex（GPT-6.1-Sol）に一つずつ渡す。各作業は直列に行う（メモリの「改造は直列で行う」）。重い検査（`scripts/check.sh` の選んだ検査）は最後に一度にまとめる。各作業の完了の条件は、関係するテストに絞ったコマンドとする。どの作業も、終わりに `cargo clippy -p benitoite --all-targets` と `cargo fmt --check` を通す（`scripts/check.sh --dry-run` で選ばれる検査を最後に確かめる）。

#### 作業 A: 永続マップの木（30〜45 分）

内容: 3.2（`build_sorted` の `debug_assert!`）、3.4（`make` の配列）、1.5 と 3.3 のコメント（tree.rs・map.rs:3・rrb.rs）、2.3 の平衡のテスト。

完了の条件:

```
cargo test -p benitoite --lib -- runtime::map runtime::list
```

（足したテストが 10 秒を超えないことを `--nocapture` の時間で確かめる。超えたら大きさを下げるか長いテストにする。長いテストの `million_element_trees_...` は最後の全体の検査に任せる。）

#### 作業 B: Map と Set の組み込みの関数と文書（30〜45 分）

内容: 4.3（`Map.toList`・`keys`・`values`・`Set.toList` の先の確かめ）、5.3（03-06 の一文、`Set.bnt` の説明）、`gen_skill` の作り直し。設計者が決めたら 1.5 の 02-08・03-06 の文。4.4 で長いテストを足すと決めたら、その長いテストも。

完了の条件:

```
cargo test -p benitoite --lib -- builtins::funcs::map builtins::funcs::set
cargo run -p benitoite --example gen_skill
cargo test -p benitoite --test skill_docs
```

#### 作業 C: Csv（45〜60 分）

内容: 7.3（`formatWith` を ASCII に限る、テストの書き換え、03-08、`Csv.bnt`、`gen_skill`、CHANGELOG）、8.3（03-08 の寛容さ、テストの行と表）。

完了の条件:

```
cargo test -p benitoite --lib -- builtins::funcs::csv
cargo test -p benitoite --test l23_csv
cargo run -p benitoite --example gen_skill
cargo test -p benitoite --test skill_docs
```

（`testdata/` は変えないので、ゴールデンテストは最後の全体の検査に任せる。`testdata/stdlib/l40-csv.bnt` は ASCII の区切りだけを使う。）

#### 作業 D: Json と Decimal と Bytes の軽微な点（30〜45 分）

内容: 9.1（設計者が選んだ案。案 a なら実装、03-08、テスト、CHANGELOG）、9.3（03-08、テストの行）、10.3（01-04、テストの行）、6.3（`bytes.rs:322` の zip、テストの `as`）。

完了の条件:

```
cargo test -p benitoite --lib -- builtins::funcs::json builtins::funcs::decimal builtins::funcs::bytes
cargo test -p benitoite --test l21_json
cargo test --test spec_examples
```

（`spec_examples` は 01-04 を変えるので走らせる。01-04 の ` ```text ` のブロックを変えないなら省いてよい。）

#### オーケストレータが行うこと（Codex に渡さない）

- 6.3 の後始末: 共有の表現の検討を docs/todo に新しい項目として加え、03-06:368 の「（docs/todo の TODO-185）」を新しい番号に直す（作業 B か D に文言の差し替えだけを頼んでもよいが、番号は先に決めて作業の文書に書く。docs/todo は worktree に現れない）。
- 3.1・3.5・5.3 の軽微な点を扱わない理由を、改造のディレクトリの判断の記録に書く。
- 最後に `scripts/check.sh --dry-run` で検査を選び、設計者に知らせてから走らせる。

## TODO-186 CLI の道具（fmt・test・skill install）の細部 — 調査の結果

調べた時点: 2026-10-12、ブランチ `san_benito`（`eb8dac11`）。リポジトリのファイルは変えず、ビルドとテストも走らせていない。行番号は今のコードで確かめ直したものである（項目に書かれた行番号は古いものがある）。

### 0. まとめ

| 点 | 分類 | 要点 |
|---|---|---|
| 1. test を並行に動かすか | 扱わない・項目に残す | 設計者の決定どおり順に動かすまま。新しい項目へ移す |
| 2. `<constructor #タグ>` の表示 | 扱わない・項目に残す | 設計者の決定どおり今のまま。1 と同じ新しい項目へ移す |
| 3a. Assert の値の書き出しの上限 | 実装の直し＋テスト＋文書 | 4,096 バイトで切って `…`。リスト・マップ・集合・`Bytes`・文字列を一度に全部読み出す箇所も、上限まで読んだら止める形に改める必要がある |
| 3b. 表記のテスト（`Byte`・`Bytes`・制御文字） | テストの直し | 表の形のテストに行を足す。中身を見せない型は `Assert.equal` に渡せない（等値の型でない）ので、テストを足さない |
| 4. `Returned` で `run.reports` を捨てる | 実装の直し（小） | 捕らえる出力先の書き込みが失敗するのはミューテックスが毒されたときだけで、実際には起きない。起きたら処理系の不具合として報告する。`MainError` も同じく捨てている |
| 5. fmt の `BlankBefore` の近似 | 実装の直し＋ゴールデンテスト | 06-03 から外れる入力が二つある（読んで確かめた）。設計書は変えない。凍結した型（10-17）を変えるので、設計者の了承が要る |
| 6a. `fmt_file` の `text.clone()` | 実装の直し（小） | 写しを `SourceTable` に移し、そこから借りる |
| 6b. `read_source` が普通のファイルを確かめない | 既に直っている | TODO-177 の改造（`b5f2da50`）で直り、テストもある |
| 6c. リンクのテストが一時ファイルの残りを確かめない | テストの直し（小） | 二つのディレクトリの中身の確認を足す |
| 6d. `args.rs` の `symlink_metadata`、`print.rs` の `Some(_line)` | 実装の直し（整理） | どちらも今も残っている |
| 7a. `ToolCommand::Skill` の通らない分岐 | 実装の直し（型で除く） | `parse_path_args` に `Test`・`Fmt` だけの型を渡す |
| 7b. HOME が無い・相対のときにディレクトリを作る | 実装の直し＋テスト＋文書 | 設計者の決定どおり、HOME が絶対パスで、存在するディレクトリのときだけ導入する |
| 7c. 別の pid の一時ディレクトリを消さない | 文書だけ（消さない） | 並行に動く別の実行の一時ディレクトリを消す危険があるので、消さないことを 06-06 に書く |

調査の中で、項目の外の点を一つ見つけた。値の構造の等しさ（`runtime/equal.rs` の `values_equal`）は、共有した構造を持つ値どうしを比べると指数時間がかかる。`Assert.equal(grow(64), grow(64))` のように等しい二つの値を比べると、書き出しより前に比較が終わらない。言語の `=` と同じ処理であり、この改造の範囲の外なので、docs/todo の新しい項目にすることを勧める（§9）。

---

### 1. `benitoite test` のテストを並行に動かすか

- 今のコード: `crates/benitoite/src/cli/tools/test_runner/mod.rs` の、ファイルごとのテストのループ（380〜450 行あたり。`run::run_test` を一つずつ呼ぶ）。06-04「テストの実行」は「処理系は、テストを並行に動かしてよい」とし、「結果の報告」は並行にしたときの報告の順序を定めている。指摘は今も当てはまる。
- 分類: **扱わない・項目に残す**（設計者の決定）。
- 直し方: なし。TODO-186 を閉じるときに、この点を 2 とあわせて新しい項目（例: 「`benitoite test` の並行の実行と、型の分からない構成子の表示」）へ移す。docs/todo の README の決まりに従って、閉じた項目の表の行に「残りは TODO-nnn に移した」と書く。
- 設計者に決めてもらう点: なし。

### 2. `Assert` の報告の `<constructor #タグ>`

- 今のコード: `crates/benitoite/src/runtime/assert.rs:209`（`text::UNKNOWN_CONSTRUCTOR`）。型が分からない値の形だけから書く `render_shape`（`Value::Tag`）と `render_object`（`FieldsKind::Ctor`）で使う。テストは `runtime/assert/tests.rs` の `unknown_types_render_by_shape_and_pipes_use_the_static_type`。指摘は今も当てはまる。
- 分類: **扱わない・項目に残す**（設計者の決定）。1 と同じ新しい項目へ移す。
- 補足: 3 の上限は、この表示にもそのまま当てはまる。

### 3. `Assert` の報告の値の書き出しの上限と、表記のテスト

#### 3.1 今のコードと、指摘が当てはまるか

- `render_value`（`assert.rs:162-187`）は、`Work` の積み重ねで値を辿って `String` を伸ばす。大きさの上限はない。共有した構造を持つ値（`t1 = Node(t0, t0)`、`t2 = Node(t1, t1)`…）は、書き出しが 2^n に伸びる。指摘は今も当てはまる。
- 上限を足すだけでは時間を抑えきれない箇所がある。どれも、上限に達したかを見る前に、中身を全部読み出す。
  - リスト: `render_typed`・`render_object` が `crate::runtime::list::to_vec` で全要素を `Vec` に写し、`sequence`（717 行）が要素ごとに `Work` を積む。
  - マップと集合: `map::map_to_vec`・`map::set_to_vec` で全体を写す（`map_pairs` は 734 行）。
  - `Bytes`: `render_object`（629 行あたり）が全バイトの `Work` を積む。
  - 文字列: `render_object`（617 行）が `quoted(s.chars(), '"')` で全体を逃がした文字列を作る（256 MiB の文字列なら、それ以上の大きさの文字列を作る）。
- 時間がかかる具体例: 長さ 100 万のリスト `xs` を作り、`ys = [xs, xs, …]` のように同じリストを要素に持つ値を書き出す。要素一つを書き出すたびに `to_vec` が 100 万の要素を写すので、4 KiB に達するまでに 100 万×数千の仕事をする。上限を足すだけでは、この例を抑えられない。

#### 3.2 分類

**実装の直し＋テスト＋文書**。

#### 3.3 直し方

上限と切り方（設計者の決定を具体化したもの）:

- 定数 `MAX_RENDERED_BYTES: usize = 4096` を `assert.rs` に置く。
- 書き出した文字列が 4,096 バイト以下なら、そのまま返す。超えるときは、4,096 − 3（`…` の UTF-8 の 3 バイト）= 4,093 バイト以下の最後の文字の境目で切り、`…`（U+2026）を一つ足す。結果は `…` を含めて 4,096 バイト以下になる。理由: `Regex.compile` の誤りの文面（03-08）と同じく「全体を 4 KiB 以下」に揃えるためである。
  - 切る位置は `str::floor_char_boundary` で求める（Rust 1.98 で安定している。使う前に `rustc` の文書で確かめる）。使えなければ、`is_char_boundary` で後ろへ戻るループで書く。
  - 末尾の `…` は、切ったことを一意に示す。切らずに書き出した値は `"`・`'`・`]`・`)`・`>`・数字・名前のどれかで終わり、`…` では終わらないからである。文字列の値の中の `…` は引用符の内側に現れるので、末尾の `…` とは区別できる。
  - 逃がしの途中で切れることがある（`"a\u{20…` など）。`…` が切ったことを示すので、それで足りる。逃がしの記号は ASCII なので、切っても端末の制御文字が現れることはない。
- 「数える」場所: `render_value` の中の出力の `String`。上限を判定するために、4,096 バイトを 1 バイトでも超えたら辿るのをやめる（4,097 バイト目まで書けば「超えた」と分かる）。

辿るのをやめる仕組み（時間も上限で抑えるため）:

- `render_value` のループの先頭で `out.len() > MAX_RENDERED_BYTES` なら抜ける。残りの `Work` は捨てる。
- 中身を全部読み出す箇所を、少しずつ読む形に改める。`values_equal`（`runtime/equal.rs`）がすでに同じ形で書いているので、それに倣う。
  - `Work` に `List { cursor: list::Cursor<'e>, ty: Option<Rc<Ty>>, first: bool }` と、マップ・集合用の `Tree { cursor: map::Cursor<'e>, key/value の型, is_map, first }` を足す。積み重ねから取り出すたびに一つだけ読み、区切り（`, `）と要素の `Work::Value` と、続きの走査を積む。`list::cursor` は `pub(crate)`、`map::Cursor::map`・`set` は `pub(in crate::runtime)` なので、`runtime::assert` から使える。
  - `Bytes` は `Work::Bytes { value, index }` のように、一度に一つずつか、残りの予算の分だけ書く。
  - 文字列と文字は、予算付きの逃がしの関数（例: `quoted_within(chars, quote, budget) -> String`）で、出力が予算を超えたところで止める。`quoted` は `test_runner/report.rs:13` が `@test` の説明に使うので、名前と振る舞いを変えずに残す。
- 時間の上限の論証（コメントに書く）: どの値の書き出しも、最初の仕事で 1 バイト以上を書く（`[`・`Map.fromList([`・名前・引用符など）。したがって、取り出す `Work::Value` の数は出力のバイト数（約 4,096）で抑えられる。一つの値に要る仕事は、走査を一つ進めることと、構成子の引数を取り出すことである。構成子の引数の数は宣言で決まるので、全体の仕事も上限で抑えられる。
- `render_value` は今 `pub` で、`assert.rs` の中からしか呼ばれていない。公開の範囲を変える必要はない。

テスト（`runtime/assert/tests.rs`。VM を通して `prepare` → `failure` で確かめる今の持ち主の境界に置く）:

1. 境目の表（新しいテスト `long_values_are_cut_at_4_kib_with_an_ellipsis`、表の形）:
   - `String.repeat("a", 4094)` → 書き出しは 4,096 バイトで、切らない（`…` がない）。
   - `String.repeat("a", 4095)` → `"` と `a` 4,092 個と `…`（4,096 バイト）。
   - `"a" + String.repeat("あ", 1400)` → 4,093 バイト以下の文字の境目は 2 + 3×1363 = 4,091 バイト。`"a` と `あ` 1,363 個と `…`。文字の途中で切らないことを確かめる。
   - 長いリスト `List.range(0, 100000)` → 期待値は、全体の書き出しの先頭 4,093 バイト以下の文字の境目までに `…` を足したもの。テストの中で Rust の `format!` と `join` で組み立てる（今の長いテストと同じやり方）。
2. 共有した構造（新しいテスト、または 1 の表の行）: `Tree.Node(t, t)` を 64 段重ねた値と `Tree.Leaf` を `Assert.equal` で比べる。比較は最初のタグの違いですぐ終わり、書き出しが上限で止まることを確かめる。直す前は終わらないので、直す前に失敗することは `timeout 60 cargo test ...` などで確かめる（段の数を 30 程度に下げて確かめてもよい）。
3. 今の `deep_and_long_values_render_without_internal_failure`（323 行。`#[ignore = "long: ..."]`）は、全体の書き出しを期待しているので、上限を入れると壊れる。上限のもとでは書き出しが約 4 KiB で止まり、深さ 10 万の入れ子を辿らないので、このテストの目的（書き出しを再帰で書く退行を、スタックの溢れで捕まえる）は果たせなくなる。次のように書き換えることを勧める。
   - 深い入れ子と長いリストの期待値を、1 と同じく「先頭＋`…`」にする。大きさは、書き出しが 4 KiB を超える最小に近いもの（深さ 5,000 程度、長さ 2 万程度）に下げ、`#[ignore]` を外して普通のテストにする。値を作る時間が短くなるので、gc-stress の分岐も要らなくなる見込みである。
   - 再帰の深さの退行は、上限があるので起きようがない（辿る段の数が約 4,096 で抑えられる）。テストの名前とコメントの関門を、上限の契約（どれだけ大きく深い値でも、4 KiB と `…` で終わる）に改める。
   - 1 の表の長いリストの行と重なるなら、どちらか一つにまとめる（test-audit の「同じ契約を繰り返すテスト」）。
4. 表記のテスト（3b）: `failed_equality_renders_both_values_in_show_form`（160 行）の表に行を足す。
   - `Option[Byte]`: `Byte.fromInteger(7)` と `Byte.fromInteger(255)` → `Option.Some(7)`・`Option.Some(255)`。
   - `Option[Bytes]`: `Bytes.fromIntegers([0, 255])` と `Bytes.fromIntegers([])` → `Option.Some(Bytes.fromList([0, 255]))`・`Option.Some(Bytes.fromList([]))`。
   - `String`: 制御文字と双方向制御文字を含む `"\u{1b}\u{7f}\u{202e}\u{2066}\u{feff}"` → 同じ `\u{…}` の形（16 進は小文字）。`Character`: `'\u{7}'` → `'\u{7}'`。
   - Rust のテストのソースでは `r#"..."#` で書く。Write や Bash で `\u` の並びが実際の文字に化けることがあるので、書いた後にファイルの中身を確かめる。
   - 中身を見せない型（`Reference`・`Regex.Pattern`・リソースなど）は等値の型でなく、`Assert.equal` の型の検査を通らない（01-06「等値の型」、言語リファレンスの等値の型の説明）。利用者のコードからは届かないので、テストを足さない。`render_typed` の `BuiltinTypeClass::Opaque | Resource` の分岐（513 行）と `text::OPAQUE` も届かない。消して `Ok(false)` を返す（形だけから書く経路に任せる）か、残すかは実装者に任せてよいが、消すなら同じ作業で行う。消す前に、その種類の値が等値の型に入らないこと（型の検査が `E04nn` で拒むこと）を一つの入力で確かめる。

文書:

- **06-04「結果の報告」**: 「値は、処理系が人間の読める形に書き出す。…」の箇条の後に、次の趣旨の箇条を足す。「【決定】一つの値の書き出しは 4 KiB（4,096 バイト）以下とする。超えるときは、文字の境目で切り、末尾に `…`（U+2026）を置いて省いたことを示す。`…` を含めて 4,096 バイト以下とする。書き出しが上限に達したら、値の残りを辿らない。理由: 共有した構造を持つ値は、書き出すと値の大きさに対して指数的に長くなりうるので、報告の大きさと書き出しの時間を値によらず抑えるためである。」あわせて、JSON Lines の `left`・`right` も同じ文字列であることを、`failure` の箇条に一言足す。
- **02-10**: 値の書き出しの規則を持っていない。「実行の外への受け渡し」の【方針】の段落が、テストの結果の形を 06-04 に委ねている。本文は変えなくてよい。変えるなら、その段落の最後に「`Assert` の報告の値の書き出しの上限も、06-04 で定める」と一文を足す程度にする。
- **言語リファレンス**（`docs/reference/benitoite.md` の §16 Tests、737 行あたりの JSON の説明の前後）: 「`left` and `right` show each value in at most 4 KiB; a longer value is cut and ends with `…`.」の趣旨の一文を足す。`docs/ja/` の訳はリリースのときに直す（AGENTS.md）。
- **CHANGELOG**: Unreleased の「### Changed」に一行足す（例: 「In the report of a failed `Assert.equal` or `Assert.notEqual`, each value is cut at 4 KiB (4,096 bytes) and ends with `…`. Before, a value could make the report arbitrarily long and could take exponential time for values that share structure.」）。

#### 3.4 設計者に決めてもらう点

- 4,096 バイトに `…` を含めるか。**推奨: 含める**（全体を 4,096 バイト以下にする）。理由: 03-08 の `Regex.compile` の誤りの文面と同じ数え方にでき、「上限」の意味が一つになる。
- 深い値と長い値の長いテストを、上限の契約のテストに書き換えて普通のテストにすること（3.3 の 3）。**推奨: 書き換える**。再帰の深さの退行は、上限のもとでは起きようがない。

### 4. テストが `Returned` で終わったときに、書き出しの失敗の報告を捨てる

#### 4.1 今のコード

- `crates/benitoite/src/cli/tools/test_runner/mod.rs:592` の `failure_of` の `EndKind::Returned => return Ok(None)`。`MainError`（593〜598 行）も `run.reports` を読まずに捨てている（項目は `Returned` だけを挙げている）。
- `run.reports` に何が入るか: `runtime/run.rs` の `step_end`（444 行〜）では、`Returned`・`MainError` のときは空である。後から足すのは `flush_failure`（509 行）だけで、最後の転送（`port.finish()`、389 行あたり）が `WriteFailure::Io` を返したときに `report::write_failed` を一つ足す。
- 捕らえる出力先の書き込みは `OutputTarget::write_bytes`（`run.rs:114-134`）の `Capture` の分岐で、失敗するのは `Mutex` が毒されたとき（ロックを持ったスレッドが panic したとき）だけである。書き出し用のスレッドの panic は `WriteFailure::Panicked` として処理系の不具合になる。テストの実行器の `take_bytes` は実行の後でしかロックを取らない。したがって、テストの実行では `Returned`・`MainError` の `run.reports` は空になる。「捕らえる出力先では起きない」という見立ては正しい。

#### 4.2 分類

**実装の直し（小）**。起きないはずの状態なので、捨てずに処理系の不具合として報告する（AGENTS.md「失敗を panic で表さない」の、起きないはずの状態の扱いに揃える）。

#### 4.3 直し方

- `failure_of` で、`Returned` と `MainError` のときに `run.reports` が空でなければ `Err("output capture failed")` のような説明を返す。呼び出し側（`mod.rs:436-439`）がすでに `Err` を `self.internal(...)` で処理系の不具合（終了状態 3）にしているので、呼び出し側は変えなくてよい。説明の文字列は処理系の不具合の説明なので、`text` にも診断の表にも載せない（AGENTS.md「文言」）。
- 起きない理由を、`failure_of` のコメントに 1〜2 行で書く（捕らえる出力先が失敗するのはミューテックスが毒されたときだけで、それは書き出し用のスレッドの panic として先に処理系の不具合になる、と）。
- テストは足さない。毒されたミューテックスを外の境界から作るには、本番が要らない差し込み口が要る（test-audit の作成時の関門の 4）。
- 設計書と CHANGELOG: 変えない（利用者に見える振る舞いは変わらない）。

#### 4.4 設計者に決めてもらう点

- 起きたときに処理系の不具合にするか、`flush_failure` の報告をそのまま失敗として示すか。**推奨: 処理系の不具合にする**。起きないはずの状態であり、テストを成功として数えたうえで報告を捨てるよりも、不具合として表に出す方が見落としがない。

### 5. フォーマッタの空の行の規則の `BlankBefore` による近似

#### 5.1 今のコード

- `crates/benitoite/src/cli/tools/formatter/roles.rs:7-14` の `BlankBefore { KeepOne, Remove }`。`Remove` は、理由の違う二つの規則を一つにまとめている。
  - (L) 構文の中身の最初の行（`roles/walk.rs:1067` の `contents` のループ）、`///` の行と属性の間・属性の行と宣言の間（`walk.rs` の `top_decl`）。06-03 では「その前の空の行を除く」で、コメントだけの行があれば、コメントの行の前の空の行を除く（「コメントだけの行を含めて数える」）。
  - (D) 閉じの字句（`closer`、230 行）、`else` と節の並びを始める `with`（`separator`、237 行）。06-03 では「その行の直前の空の行を除く」。
- `print.rs:325-349` の `blank_rule` は、`Remove` の行の前にコメントだけの行があるとき、理由の代わりに字句の種類（`role.inner_level.is_some()` か、`KwElse`・`KwWith` か、336 行）で振る舞いを分ける。(D) の字句とみなした行は、直前の空の行だけを除き（`index == code_index` なら `Zero`、そうでなければ `KeepOne`）、ほかは (L) とみなす（前の行がコードなら `Zero`、コメントなら `KeepOne`）。

#### 5.2 06-03 から外れる入力（読んで確かめたもの）

外れるのは、一つの行が (L) と (D) の両方に当たる場合と、(L) の行が `with` で始まる場合である。どちらも、中身の最初の行がコメントだけの行のとき、開きの行とコメントの行の間の空の行を除かず、一つ残す。

1. **中身がコメントだけの構文**（閉じの字句の行が中身の最初のコードの行）:

   ```text
   const xs: List[Integer] = [

     // none yet
   ]
   ```

   06-03 では、`// none yet` が中身の最初の行なので、その前の空の行を除く。実装では、コメントの行の後の最初のコードの行が `]`（`inner_level` を持つ）なので (D) とみなし、`index != code_index` のため `KeepOne` を返す。空の行が一つ残る。引数のない呼び出しの括弧（`f(` 改行 コメント 改行 `)`）も同じである。

2. **中身の最初の文が `with` の文で、その前にコメントだけの行がある**:

   ```text
   function main() -> Unit uses IO.All

     // open the input
     with r = File.openReader("in.txt") do
       ...
     end with
   end function
   ```

   06-03 では、コメントの行の前の空の行を除く。実装では、`with` の行の役割は (L) の `Remove` だが、字句が `KwWith` なので (D) とみなし、コメントの行に `KeepOne` を返す。空の行が一つ残る。コメントがなければ（`with` の行の直前が空の行だけなら）、`index == code_index` で `Zero` になり、06-03 のとおりになる。

- 同じ理由で、中身が空のまま `else` が続く場合（`if c then` 改行 空行 コメント 改行 `else`）も外れる。ただし、`then` の中身を空にできる構文かは確かめていない。実装者は、空の本体を書ける構文が他にないかを `walk.rs` の `content` の呼び出し元で確かめ、あればゴールデンテストに加える。
- 外れない場合（確かめたもの）: 中身のある括弧の中で閉じの字句の前にコメントがある場合（`1,` 空行 コメント `]`）、`else` の前にコメントがある場合、`handle` の節を始める `with` の前にコメントがある場合、ブロックの途中の `with` の文（役割が `KeepOne` なので 326 行で返る）、属性と宣言の間にコメントがある場合。どれも今の振る舞いが 06-03 と一致する。
- どちらの外れも冪等性は保つ（二度目の整形で変わらない）。整形後の検証（06-03「整形後の検証」）は空の行を比べないので、検証では見つからない。

#### 5.3 分類

**実装の直し＋ゴールデンテスト**。設計書（06-03）は変えない。実装を 06-03 に合わせる。

#### 5.4 直し方

- `BlankBefore` を、理由を区別できる形にする。一つの字句が両方に当たる（中身が空の構文の閉じの字句）ので、列挙ではなく二つの真偽値にする。例:

  ```rust
  /// 行の最初の字句のときの、その前の空の行の扱い（06-03「空の行」）。
  pub struct BlankBefore {
      /// 構文の中身の最初の行・属性と宣言の間・`///` と属性の間。前のコードの行との間の空の行を、
      /// コメントだけの行の前でも除く
      pub leading: bool,
      /// 閉じの字句・`else`・節の並びを始める `with`。その行の直前の空の行だけを除く
      pub direct: bool,
  }
  ```

  `TokenRole::blank_before` の型が変わる。`roles.rs` は `pub` だが、使うのは `formatter` の中だけである（`BlankBefore` と `TokenRole::blank_before` は、初回リリース版の実装プランの `docs/archive/2026-10-09-implement-first-release/10-interfaces/10-17-formatter.md`（184・201 行）で凍結した型である。AGENTS.md「型とシグネチャを変えない」に当たるので、作業に渡す前に設計者の了承を得る（5.5）。）
- `walk.rs`: `closer`・`separator` は `direct` を立て、`contents` のループと `top_decl` の印は `leading` を立てる。今の `remove_blank: Vec<bool>` を二つに分ける。
- `print.rs` の `blank_rule`（325〜349 行）を、字句の種類を見ずに書き直す。

  ```text
  if !leading && !direct            → KeepOne
  if direct && index == code_index  → Zero      （閉じの字句などの直前）
  if leading && prev.kind != Comment → Zero     （開きの行との間。コメントの行の前でも除く）
  otherwise                          → KeepOne
  ```

  `leading` の行の前の最後の空でない行がコメントでなければ、その行は開きの行である（中身の最初のコードの行より前に、中身のコードの行はない。シェバン・`//!`・トップレベルの宣言の後は 300〜318 行で先に返る）。これで 336 行の `KwElse`・`KwWith` の判定と、「`BlankBefore` は除く理由を持たないので、字句の種類も調べる」のコメントを消せる。上の四行は、5.2 の二つの外れの場合だけで今の振る舞いと違い、ほかの場合では今と同じ値を返す（実装者は、5.2 の「外れない場合」の各場合で同じ値になることを確かめる）。
- `print.rs:296` の `Some(_line)` も同じ作業で `Some(_)` にする（6d）。
- テスト: `crates/benitoite/testdata/fmt/blank_lines.bnt` と `.formatted` に、5.2 の 1 と 2 の入力を加える（または `blank_lines_comments.bnt` を新しく作る）。直す前に `.formatted` との違いで失敗し、直した後に通ることを確かめる。`BENITOITE_BLESS=1` で期待値を作り直さず、`.formatted` は 06-03 から手で書く（期待値を対象の処理で作らない。test-audit）。`formatter/tests.rs`・`roles/tests.rs` に `BlankBefore` の値を直接確かめるテストがあれば、型の変更に合わせて直す。新しい単体テストは足さない（持ち主の境界はゴールデンテストの `fmt` の方式。06-03「テスト」）。
- 設計書: 06-03 は変えない。`roles.rs` の `BlankBefore` の `///` のコメントを、二つの理由の説明に改める。
- CHANGELOG: 「### Fixed」に一行足す（例: 「`benitoite fmt` now removes a blank line before a comment that is the first line inside a construct, also when the construct contains only comments or its first statement is `with`, as the layout rules say.」）。整形の結果が変わる利用者がいるため。

#### 5.5 設計者に決めてもらう点

- 凍結した型 `BlankBefore`（10-17）を、二つの真偽値の形に変えてよいか。**推奨: 変える**。型を変えずに直すには、`print.rs` で字句の種類を調べる今の近似をさらに広げることになり、近似が残る。`formatter` の外から使われていない型なので、変える範囲は `roles.rs`・`walk.rs`・`print.rs` と、そのテストに限られる。

### 6. `fmt` の細かい点

#### 6a. `fmt_file` がソースを複製する

- 今のコード: `crates/benitoite/src/cli/tools/formatter/mod.rs:184-188`（`sources.add(Source::new(display.to_owned(), SourceKind::User, text.clone()))`）。指摘は今も当てはまる。
- 分類: **実装の直し（小）**。
- 直し方: `text` を `Source::new` に移し、整形には `sources.get(file).map(Source::text)` で借りたものを渡す（`Source::text` は `&[u8]` を返す。`base/source.rs:70`）。`get` が `None` なら処理系の不具合として報告する（`internal_diagnostic`）。`on_large_stack` の閉包は今も `&text` を借りているので、`&sources` を借りる形に変えても同じように書ける。テストは足さない（メモリの量は観察しにくく、振る舞いは変わらない）。設計書と CHANGELOG は変えない。
- 参考: `format_source`（`mod.rs:69-80` あたり）は `lexed.tokens.clone()` と `lexed.comments.clone()` で字句の列を写している。字句の列はソースより大きいので、メモリを減らす効果はこちらの方が大きい。ただし、項目の範囲の外であり、整形後の検証が元の字句の列を使うかを読んでからでないと直せないので、この改造では扱わないことを勧める。

#### 6b. `read_source` が普通のファイルかを確かめない

- 今のコード: `formatter/mod.rs:247-253` の `read_source` は `crate::base::file_read::read_regular_file(path, limit, false)` を呼ぶ。`base/file_read.rs:17-32` は `O_NONBLOCK` で開いた記述子が普通のファイルかを確かめ、FIFO・デバイス・ディレクトリを `not a regular file` で拒む。
- 分類: **既に直っている**（TODO-177 の改造、コミット `b5f2da50`）。テストは `tests/fmt_command.rs:289` の `fmt_rejects_a_fifo_without_blocking` と、`tests/cli_process.rs:493` の `/dev/stdin` の場合。設計書は 06-01 の 124 行に「`fmt` が読むファイルも、普通のファイルに限り…FIFO などはファイルを読めない誤り（E0101）とする」とある。CHANGELOG の Unreleased にも行がある。
- 直し方: なし。項目を閉じるときに「既に直っていた」と書く。

#### 6c. リンクのテストが一時ファイルの残りを確かめない

- 今のコード: `tests/fmt_command.rs:252-269` の `a_link_given_directly_rewrites_its_target_and_keeps_the_link`。リンクが残ることとリンクの先が整形されたことは確かめているが、`real/` と `dir` の根に一時ファイル（`.a.bnt.fmt-<pid>`）が残らないことは確かめていない。指摘は今も当てはまる。
- 分類: **テストの直し（小）**。
- 直し方: テストの最後に、`real/` の中身が `a.bnt` だけであることと、根の中身が `link.bnt` と `real` だけであることを `fs::read_dir` で確かめる（近くの `unwritable_directory_keeps_the_original_and_leaves_no_temp_file` が `read_dir(..).count()` で同じことをしている）。捕まえる退行: 一時ファイルをリンクの側のディレクトリに作って名前の変更に失敗する、成功の後に一時ファイルを消し忘れる、など。

#### 6d. 軽微な点

- `cli/tools/args.rs:120` の `std::fs::symlink_metadata(&path)` は今も残っている。`entry.file_type()` で足りる（Unix の `DirEntry::file_type` はリンクを辿らない）。`map_err` の誤りのパスも今と同じく `path` にする。**実装の直し（整理）**。振る舞いは変わらないので、テストは足さない（既存の `directory_expands_to_sorted_bnt_files_only` などが守る）。
- `formatter/print.rs:296` の `Some(_line)` は今も残っている。`Some(_)` にする。5 の作業で行う。

### 7. `skill install` の細部

#### 7a. `ToolCommand::Skill` の通らない分岐

- 今のコード: `crates/benitoite/src/cli/tools/args.rs:43`（`ToolCommand::Skill => "skill"`）と `65`（`ToolCommand::Test | ToolCommand::Skill => ...`）。呼び出し元は `cli/tools.rs:13`・`22` の二か所で、どちらも `Test` か `Fmt` を渡す。`Skill` で呼べば、`test` のオプションを受け付けて成功を返す。指摘は今も当てはまる。
- 分類: **実装の直し（型で除く）**。
- 直し方: `args.rs` に `pub enum PathTool { Test, Fmt }` を置き、`parse_path_args(tool: PathTool, args)` にする。`tools.rs` の二か所と `args/tests.rs`（21・26・40・92 行あたり）を合わせて直す。`ToolCommand` は `cli/mod.rs:44` のまま残す（サブコマンドの振り分けに使う）。テストは足さない（型で除くので、通らない経路がなくなる）。設計書と CHANGELOG は変えない。

#### 7b. HOME が存在しないパスや相対パスのときに、ディレクトリを作ってしまう

- 今のコード: `cli/tools.rs:28-34` が環境変数 `HOME`（空なら `None`）を `run_skill` に渡す。`skill/mod.rs:341-358` の `run_skill` は、`None` のときだけ `NO_HOME` を報告する。`install_dir`（97 行）の `create_dir_all(parent)`（101 行）が、HOME が存在しなくても、相対パスでも（作業ディレクトリからの相対で）`.claude/skills` などを作る。指摘は今も当てはまる。
- 分類: **実装の直し＋テスト＋文書**（設計者の決定: HOME が絶対パスで存在するディレクトリのときだけ導入する。そうでなければ誤りを報告し、ディレクトリを作らない）。
- 直し方:
  - `run_skill` の `Scope::User` の分岐で、`home.is_absolute()` と `std::fs::metadata(&home).is_ok_and(|m| m.is_dir())` を確かめる。`metadata` はリンクを辿る（HOME がディレクトリへのシンボリックリンクであるのは普通なので、辿ってよい）。満たさなければ、新しい文 `text::HOME_NOT_DIRECTORY`（例: ``"error: the home directory `{path}` is not an absolute path to an existing directory; set `HOME` or use `--project`"``）を標準エラー出力に書き、終了状態 1 で終える。`{path}` は `escape_terminal_controls` で逃がす（06-06 の、誤りの報告のパスの逃がし）。
  - `uninstall` にも同じ確かめを当てる（7b の設計者に決めてもらう点）。
  - `--project` の作業ディレクトリは `CliEnv::working_directory` で、CLI が絶対パスで作るので、確かめない。
- テスト（`skill/tests.rs`。`run(&temp, args, home)` で `home` を差し込める今の境界に置く）: `user_scope_without_home_reports_no_home`（263 行）の近くに、表の形のテストを一つ足す。
  - 存在しない絶対パス（`temp.path().join("missing")`）: 終了状態 1、`HOME_NOT_DIRECTORY` の文、`missing` が作られていないこと。
  - 普通のファイルを HOME にした場合: 同じ。
  - 相対パス（`PathBuf::from("relative-home-<一意の名前>")`）: 同じ文で、相対パスが作業ディレクトリ（テストのプロセスの作業ディレクトリ）の下に作られていないこと。直す前に走らせると、クレートの根の下にディレクトリを作るので、テストの最後に消す後始末を置くか、直す前の失敗は絶対パスの行だけで確かめる。
  - `install` と `uninstall` の両方で確かめる（`uninstall` に当てると決めたとき）。
- 文書:
  - 06-06「Skill の導入（初回リリース版）」の箇条に足す。「`--user` の置き場所の基準は、環境変数 `HOME` の値とする。`HOME` がないか空のとき、絶対パスでないとき、存在するディレクトリでないときは、何も書き出さず（ディレクトリも作らず）に誤りを報告し、終了状態 1 で終える。理由: 誤った `HOME` のもとで、作業ディレクトリの下や意図しない場所に置き場所のディレクトリを作らないためである。」終了状態の箇条にも、この場合を 1 に加える。
  - 06-01「`skill` のコマンドライン（初回リリース版）」は 06-06 に委ねているので、変えなくてよい。
  - `docs/reference/install.md` の §3（Agent Skill の導入）に、HOME の条件を一文足すかは任意（`--project` を使う代わりの手順があることを示すなら足す）。
  - CHANGELOG: 「### Changed」に一行（例: 「`benitoite skill install` and `uninstall` without `--project` report an error and write nothing when `HOME` is not an absolute path to an existing directory. Before, they created the skill directories relative to the working directory or at a missing path.」）。

#### 7c. 導入の途中で残った別の pid の `.benitoite.install-*`・`.benitoite.old-*` を消さない

- 今のコード: `skill/mod.rs:111-113`（`.benitoite.install-<pid>`。同じ pid の名残だけを消す）、`126-127`（`.benitoite.old-<pid>`）。指摘は今も当てはまる。
- 分類: **文書だけ（消さない）**。
- 理由: 別の pid の一時ディレクトリは、同じ置き場所へ並行に `install` している別のプロセスのものかもしれない。消すと、その実行の書き出しの途中のディレクトリを壊す。pid が生きているかで判定する案は、pid の再利用と判定の後の競合があり、確実ではない。名残が残るのは、プロセスが書き出しの途中で強制終了された場合に限られ、Skill の置き場所の中身（`benitoite/`）には影響しない（`.` で始まる別の名前のディレクトリなので、エージェントは Skill として読まない）。
- 直し方: 06-06 の「置き換えは、同じ親のディレクトリの一時ディレクトリに書き出してから名前を変えて行う。…」の箇条に足す。「途中で強制終了されると、親のディレクトリに `.benitoite.install-<pid>` か `.benitoite.old-<pid>` が残ることがある。`install` と `uninstall` は、自分の pid のもの以外を消さない。並行に動く別の実行の一時ディレクトリを壊さないためである。」コードとテストは変えない。CHANGELOG は要らない。
- 補足: エージェントが `.` で始まるディレクトリを Skill として読まないことは、各エージェントの文書で確かめていない。確かめないなら、06-06 の理由にこの点を書かず、「Skill の置き場所の `benitoite/` は変えない」までにとどめる（AGENTS.md「事実と出典」）。

#### 7d. 設計者に決めてもらう点

- HOME の確かめを `uninstall` にも当てるか。**推奨: 当てる**。相対の HOME のもとで `uninstall` は作業ディレクトリの下の `.claude/skills/benitoite` を消しうる（`install` が書き出したものだけを消すとはいえ、意図した場所ではない）。導入と同じ条件にしておけば、規則が一つで済む。
- 別の pid の名残を消さないこと（7c）。**推奨: 消さず、06-06 に書く**。

### 8. 項目の閉じ方

- TODO-186 を閉じ、1（並行の実行）と 2（`<constructor #タグ>`）を新しい項目へ移す。閉じた項目の表の行に、6b が既に直っていたことと、移した先の番号を書く。
- §9 の等しさの比較の指数時間を、新しい項目として加える（設計者が認めれば）。

### 9. 範囲の外で見つけた点（新しい項目の候補）

- `runtime/equal.rs` の `values_equal` は、同じ対象への参照でも成分を調べる（`[NaN]` を取りこぼさないため。同ファイル 49 行のコメント）。そのため、共有した構造を持つ等しい二つの値（`grow(64, Tree.Leaf)` どうしなど）の比較は指数時間になる。`Assert.equal` の比較も、言語の `=`・`<>` も同じである。書き出しの上限（§3）はこの比較の時間を抑えない。対策の候補（同じ対象で `Float` を含まない型なら成分を調べずに等しいとする、比べた組を覚える、など）と、型の情報が実行時に要るかを検討する項目にする。

---

### 作業の分け方の案

Codex（GPT-6.1-Sol）に一つずつ、順に渡す。どの作業も、終えたら `scripts/check.sh --dry-run` で選ばれる検査を示してから、オーケストレータが改造の最後にまとめて `scripts/check.sh` を通す（改造は直列、重い検査は最後に一度）。下の完了の条件は、関係するテストに絞ったものである。

#### 作業 A: Assert の値の書き出しの上限と表記のテスト（§3）— 約 60 分

内容: 3.3 の上限・切り方・少しずつ読む走査、テストの 1〜4、06-04「結果の報告」、言語リファレンスの §16、CHANGELOG の Changed。中身を見せない型の分岐を消すかは実装者の判断（消すなら理由を報告に書く）。

完了の条件:

```sh
cargo test -p benitoite --lib runtime::assert
cargo test -p benitoite --lib runtime::assert -- --ignored   # 長いテストを残した場合だけ
cargo test -p benitoite --test test_command
BENITOITE_GOLDEN_FILTER=testdata/test/ cargo test -p benitoite --test golden
cargo test -p benitoite --test reference_examples
cargo clippy -p benitoite --all-targets -- -D warnings
```

あわせて、共有した構造のテストが直す前に終わらないこと（`timeout` で止まること）と、境目の表のテストが直す前に失敗することを確かめ、報告に書く。

#### 作業 B: フォーマッタの空の行の規則（§5、6d の `Some(_)`）— 約 45〜60 分

内容: `BlankBefore` を二つの理由の真偽値にし、`walk.rs` と `print.rs` の `blank_rule` を直す。ゴールデンテストに 5.2 の二つの入力を加える（`.formatted` は 06-03 から手で書く）。CHANGELOG の Fixed。

完了の条件:

```sh
cargo test -p benitoite --lib cli::tools::formatter
BENITOITE_GOLDEN_FILTER=testdata/fmt/ cargo test -p benitoite --test golden
cargo test -p benitoite --test fmt_command
cargo clippy -p benitoite --all-targets -- -D warnings
```

加えたゴールデンテストが直す前に失敗することを確かめ、報告に書く。標準ライブラリのソースが正規形であることのテスト（`formatter/tests.rs`）も、上の `--lib cli::tools::formatter` に含まれる。

#### 作業 C: CLI の小さな直し（§4、§6a、§6c、§6d の `args.rs`、§7a）— 約 45 分

内容: `failure_of` の `Returned`・`MainError` で `run.reports` が空でなければ処理系の不具合にする。`fmt_file` の複製をやめる。リンクのテストに一時ファイルの残りの確認を足す。`bnt_files` を `entry.file_type()` にする。`parse_path_args` に `PathTool` を渡す。設計書と CHANGELOG は変えない。

完了の条件:

```sh
cargo test -p benitoite --lib cli::tools
cargo test -p benitoite --test fmt_command
cargo test -p benitoite --test test_command
cargo clippy -p benitoite --all-targets -- -D warnings
```

#### 作業 D: `skill install` の HOME の確かめと名残の文書（§7b、§7c）— 約 30〜45 分

内容: `run_skill` で HOME が絶対パスで存在するディレクトリかを確かめる（`uninstall` にも当てるかは、設計者の答えに従う）。表の形のテストを足す。06-06「Skill の導入（初回リリース版）」に HOME の規則と名残の扱いを書く。CHANGELOG の Changed。

完了の条件:

```sh
cargo test -p benitoite --lib cli::tools::skill
cargo test -p benitoite --test skill_docs
cargo clippy -p benitoite --all-targets -- -D warnings
```

足したテストのうち絶対パスの行が、直す前に失敗する（ディレクトリが作られる）ことを確かめ、報告に書く。

#### 作業の後（オーケストレータ）

- `scripts/check.sh --dry-run` で選ばれる検査を設計者に示してから `scripts/check.sh` を通す。
- docs/todo で TODO-186 を閉じ、1・2 を新しい項目へ移す。§9 を新しい項目にするかを設計者に尋ねる。
- `docs/ja/reference/` の訳は、リリースのときに直す。
