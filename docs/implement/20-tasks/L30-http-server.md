# L30 HTTP のサーバの接続の層

- 依存する作業: [L03](L03-bytes.md)、[L12](L12-file-resources.md)、[R24](R24-resources.md)、[R40](R40-event-loop-and-worker-threads.md)、[R27](R27-output-writers.md)、[R28](R28-interrupt-and-stop-procedure.md)
- 難易度: 5（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超。テストを含む）
- ブランチ: impl/L30-http-server

## 目的

HTTP/1.1 のサーバを、`httparse` と `mio` の上に自作する接続の層として作り、IO 実行器のタスクの切り替えに組み込む（[ADR 0143](../../design/decisions/0143-http-and-tls-crates.md) の決定 1）。層は VM のスレッドのイベントループで動き、接続を待つタスクがある間もほかのタスクを進める。10-15 の部分 43（`http_server::DECLS`）と部分 28（`network_error::DECLS`）の本体を書く。

| 部分 | 項目 | 権限 |
|---|---|---|
| 43 | `Http.listen`・`listenerPort`・`accept`・`respond` | `Io` |
| 43 | `Http.requestOf`・`closeListener`・`closeExchange` | `State` |
| 28 | `NetworkError.kind`・`NetworkError.message` | `Pure` |

本作業は、U2 が使わずに残した準備の待ち（`IoWait::Readiness`。R26 は `Stop::Internal` を返す形で置いた）を、VM とイベントループに組み込む最初の作業である。10-16「準備の待ちの規則」に従う。

依存の理由: 要求と応答の本体は `Bytes`（L03）。リソースの表と解放の枠（R24）、送り出しの列・外部の操作の記録（R26）、イベントループ（R40）、出力（R27。資源の不足の一行を標準エラー出力に書く）、止める手順と中断の要求（R28）の上に作る。`closeListener`・`closeExchange` は、L12 が `src/builtins/iface.rs` に書き足し VM の側で上書きした `StateServices::begin_close`（10-16「close の関数が解放の失敗を受け取る口」、ADR 0321）を使う（L12）。

## 読む設計書の節

- [ネットワークのモジュール](../../design/03-interop/03-09-network.md)の「モジュールとエフェクト」「範囲」「要求と応答の型」「サーバ」「サーバの接続と要求の読み方」「失敗の種類」「実装に使うクレート」
- [リソース管理](../../design/01-spec/01-10-resources.md)の「解放の失敗」「解放したリソースの使用」
- [並行処理](../../design/01-spec/01-11-concurrency.md)の、待つ間にほかのタスクを進めること、「失敗と停止」
- [エラー処理](../../design/01-spec/01-09-errors.md)の「ネットワークの失敗の種類（初回リリース版）」
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」（操作を行う場所の表と、`Http.accept` の失敗の分類の箇条）、「IO 実行器」、「リソースの追跡」（`Http.Listener`・`Http.Exchange` の解放）、「中断の要求」、「panic 境界」（イベントループと HTTP のサーバの層が境界の中にあること）
- [仮想機械](../../design/02-impl/02-08-vm.md)の「組み込みの関数の呼び出し」の待つ理由の表（イベントループの準備）、「タスクの切り替え」（行き詰まりの判定）
- [未決・要検証事項](../../design/open-issues.md#open-062)の OPEN-062 の R04・R14
- ADR: [0143](../../design/decisions/0143-http-and-tls-crates.md)、[0149](../../design/decisions/0149-http-exchange-release-failure.md)、[0170](../../design/decisions/0170-http-accept-failure-classification.md)、[0162](../../design/decisions/0162-event-loop-and-worker-threads-for-io.md)、[0145](../../design/decisions/0145-network-error.md)、[0150](../../design/decisions/0150-resource-release-as-state.md)、[0266](../../design/decisions/0266-task-and-resource-state-machines.md)、[0283](../../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)、[0287](../../design/decisions/0287-stdlib-details-decided-in-u3-plan.md) の決定 2、[0321](../../design/decisions/0321-close-functions-return-release-failure.md)、[0322](../../design/decisions/0322-stdlib-details-from-u3-preflight.md) の決定 4、[0289](../../design/decisions/0289-request-of-after-release-is-runtime-error.md)、[0330](../../design/decisions/0330-http-details-from-u3-preflight.md) の決定 1

インターフェース:

- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「ランタイムの内部への口」「受け付けた要求の保存」「HTTP のサーバの接続の層」（準備の待ちの規則、実装プランで決める値）、「使うクレート」の `httparse`・`mio`、「テスト用のハンドラ表のネットワークの失敗」（`Http.listen` に当てる分）
- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「ネットワーク」「ネットワークの失敗」の表、「項目の種類と権限」、`Network/Http.bnt`・`NetworkError.bnt`・`NetworkErrorKind.bnt`、「構成子のタグ」の `NETWORK_ERROR_KIND_*`、「レコードの値の作り方」
- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の「外部の操作の記録と完了」「リソースの表と状態」「イベントループ」「完了の処理と行き詰まりの判定の順序」
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `IoWait::Readiness`・`Interest`・`OsResource`・`StateServices::begin_release`
- R24 の作業の文書（`HttpListener` はブロックしない解放、`HttpExchange` はブロックする解放で失敗を捨てる）、R26 の作業の文書（`Deliver` の処理）、R40 の作業の文書（イベントループ）

## 作るもの

- `src/runtime/io/http.rs`: 接続の層（待ち受けと接続の OS の資源、読みかけの要求と書きかけの応答、`httparse` による解析、本体の読み方、応答の組み立て、イベントループへの登録、受け付けのやり直しの時刻）。`mio` の型はこのモジュールと `event.rs` の中に閉じる（10-16）
- `src/runtime/io/event.rs`（R40）に、10-16「準備の知らせを届ける経路」の欄と関数（`WakeBackend::WithPoll` の `Registry` と準備のトークンの列、`pub(crate)` の `register`・`reregister`・`deregister`・`take_ready`）を加えたもの
- `src/vm/dispatch/tasks/io.rs` の `boundary`（R26）に、`take_ready` で取り出したトークンから `Outcome::Ready` の完了を作って `ops::accept_completion` に渡す処理と、`Accepted::Deliver` で準備の待ちの完了の要求をやり直す分岐を加えたもの（10-16「準備の待ちの規則」の手順 3）。この二つのファイルを受け持つ作業はほかにない
- 【止まる】`src/runtime/io/resources.rs`: 項目が `Released` になるすべての経路で、その番号の添え物（`ResourceTable::attachments`）を除く（10-16「受け付けた要求の保存」、ADR 0289 の決定 2）。U3 の今のコードでは、経路は次の四つである。`request_release` の `Open` の分岐で、ブロックしない解放の OS の資源を `Released` にする箇所（`ReleaseStart::Done(handle.release())` を返す分岐）と、`TaskGroup` を `Released` にする箇所（添え物はないが、除いても害はない）、`finish_release`（ブロックする解放の完了。`HttpExchange` はこの経路）では `attachments.remove(&id)`、`close_all_silently` では `entries.clear()` とあわせて `attachments.clear()`。解放の経路ごとに添え物が除かれることを確かめる単体テスト（このファイルのテストのモジュール）を加える。添え物を除かずに作業を終えると、受け付けた要求の数に比例してメモリが残る（ADR 0289 が避けた振る舞い）ので、除けない事情が生じたら作業を止めて報告する
- `src/runtime/io/services.rs`: 準備の待ちの状態（イベントループのトークンと操作の番号の対応、やり直す要求、受け付けのやり直しの期限とタイマーの番号）を置く `pub(crate)` の欄を `IoRuntime` に加えてよい（R27 の `output_sites` と同じ形）。取り消しの反映（`io.rs` の `reflect_cancellation`）で、取り消したタスクの分を外す
- `src/runtime/sched/parts.rs` の `ThreadWorkers` の `WorkerExec::wakeup` の上書き（`Some(self.wakeup.clone())`）と、公開の構築の関数 `RuntimeParts::real_with_poll`（10-16「本物の部品とイベントループを使うテストの口」。L33 が使う）
- `src/builtins/funcs/http_server.rs`・`network_error.rs` の 9 項目の本体と単体テスト
- `mio` の機能 `net` と `httparse` の依存（10-16 の表の指定）
- 統合テスト（`tests/` の下。HTTP の要求はテストの中の Rust の `TcpStream` で送る。スクリプトからのクライアントは L32、`network` のゴールデンテストは L33）

## 手順の要点

### 準備の待ちと VM

10-16「準備の待ちの規則」の 1〜5 のとおりに組み込む。要点は次のとおりである。

- `IoWait::Readiness { resource, interest }` を受けた VM は、`OpKind::Readiness` の記録を加え、タスクを `WaitReason::Readiness(番号)` で待たせ、`runtime::io::http` にそのリソースの登録を頼む。準備の知らせ（`Outcome::Ready`）を受けたら、タスクがまだ待っていれば、同じ `site` の操作を送り出しの列にもう一度置く。結果の値は作らない。やり直しでは、次の三点を守る。
  - (a) `Accepted::Deliver` は `BuiltinDecl` を持たない（`task`・`op`・`site`・`outcome` だけ）。送り出しの列に置く `&'static BuiltinDecl` は、`site` の命令から引き直す。`program.builtin_call_operands(命令)` の `builtin`（`BuiltinRefIdx`）で `program.builtin(..)` を引き、その `id`（`BuiltinId`）を `builtins::table::builtin_decl` に渡す。テスト用の `IoRuntime::builtin_overrides` は `io.rs` の `publish` が `#[cfg(test)]` で当てるだけなので、やり直しには引き継がれない。上書きした項目で準備の待ちを試すテストは、この点を踏まえて組む。
  - (b) 要求を列に置き直すのは、`boundary` が `rt.dispatcher.on_wait_point` を呼んだ後（完了を受け取るループの中）である。そのままでは、直接呼び出しの方式では同じ `boundary` の中で次の `ServeNow` が来ず、進められるタスクがないので `idle` で待ち続けうる。置き直した後に部品にもう一度尋ねる（直接呼び出しなら `serve` を呼び、要求と応答なら `state.step = Some(VmStep::Requests(..))` にする）。
  - (c) `ops::check_completion`（`runtime/io/ops.rs`）は、記録のない操作の完了を `Stop::Internal`（"completion has no operation record"）にする。同じ操作に複数のトークンが来る場合（読みと書きの準備が続けて来るなど）や、配送して記録を外した後に古いトークンが来る場合に備え、`take_ready` のトークンから `Completion` を作る前に、操作の番号の重複を除き、記録のない番号を捨てる。
- 操作の関数は、もう一度呼ばれたときにリソースに残した途中の状態から続ける。呼ばれるたびに非同期の読み書きを `WouldBlock` まで進め、終われば完了、進めなければもう一度 `Readiness` を返す。
- 取り消したタスクの `Readiness` の記録は配送先を外して残し、準備が来たら捨てる。登録は、記録を捨てるときかリソースを解放するときに外す。
- 準備の待ちは外部の待ちであり、行き詰まりの判定に数える。接続を待つだけのサーバのタスクは行き詰まりにならない。
- 両方の IO の方式（直接呼び出しと要求と応答）で動くようにする（ADR 0264 の決定 7）。
- 準備の知らせは、10-10 のトレイトを変えずに `event.rs` の中で届ける（10-16「準備の知らせを届ける経路」）。`EventLoop::wait` が予約外のトークンを共有の列に積み、VM の `boundary` が `take_ready` で取り出して `Completion { op, outcome: Outcome::Ready, returned: LentOwned::Nothing }` を作り、`accept_completion` から `Accepted::Deliver` に流す（`Completion::returned` の型は `LentOwned` であり、`Option` ではない）。
- テスト用の部品（起こし口が `WithPoll` でなく `mio::Registry` がない）で登録を頼まれたら、`Stop::Internal` を返す。
- `mio` の登録は edge-triggered なので、`WouldBlock` まで読み書きを進めずに待つと、次の準備が知らされない。`WouldBlock` の後に向きを変えるときは `reregister` する。
- 受け付けのやり直しの期限（10-16「準備の待ちの規則」の手順 4）は、`Scheduler::add_timer`（`runtime/sched/mod.rs`）で `state.scheduler.timers` に入れ、`idle` に渡す次の期限（`next_deadline`）に含める。期限と、それを待つ操作の番号は `IoRuntime` の欄に持つ。既存の満了の処理（`vm/dispatch/tasks.rs` の `boundary` の `expire_timers` のループ）は、このタイマーに何もしない。待っているタスクは `spawn_wait` を持たないので `cancel::expire` が `false` を返し、`rt.sleeps` に該当がなく、タスクは `WaitReason::Readiness` で待っているので `wake_if(task, WaitReason::Timer(..))` は何もしない。ただし、`tasks.rs` の `boundary` は `io::boundary` の後に時計を読み直して `expire_timers` を呼ぶ。期限の判定を `io::boundary` で時計を比べるだけにすると、二つの読みの間に期限が来たときに、タイマーが何もせずに外れ、続く `idle` に期限が渡らず、ほかの知らせがなければ待ち続ける。これを避けるため、`tasks.rs` の満了のループの `rt.sleeps` の分岐の後に、外れたタイマーが受け付けのやり直しのものなら `io.rs` のやり直しの関数（`Deliver` のやり直しと同じ関数。上の (b) のとおり部品にもう一度尋ねる）を呼ぶ分岐を一つ加える（このとき `tasks.rs` を作るものに加え、完了の報告に書く）。`io::boundary` の側にも時計の比較を置く必要はない。

### 操作ごと

- `Http.listen(host, port)`: `port` が 0 以上 65535 以下でなければ実行時エラー（`ArgumentOutOfDomain`、引数の位置 1）。テスト用のハンドラ表に `host` の失敗があれば、その `NetworkError` を返す（10-16）。名前の解決と待ち受けの開始（`std::net::TcpListener::bind` の後に非同期にして `mio::net::TcpListener` にする）を作業用のスレッドで行い、完了の処理で `register_resource(ResourceKind::HttpListener, …)`。解決の失敗は `HostNotFound`、使われているアドレスは `AddressInUse`、アドレスの形の誤りは `InvalidInput`、OS の拒否は `PermissionDenied`（03-09 の表）。
- `Http.listenerPort(listener)`: `runtime_view` でリソースを読み、`local_addr` のポートを返す。
- `Http.accept(listener)`: 受け付けて、要求を読み終えたら、接続を `ResourceKind::HttpExchange` のリソースとして表に加え、要求の内容をリソースの表の添え物（`ResourceTable::attachments`）に加え（10-16「受け付けた要求の保存」）、`Result.Ok(Exchange)` を返す。要求が HTTP として正しくなければ、処理系が 400 を返して接続を閉じ、次の要求を待つ（03-09）。本体が上限（`MAX_REQUEST_BODY_BYTES`）を超えたら 413。受け付けの失敗は ADR 0170 の三つに分け、接続ごとの失敗は捨てて次を待ち、資源の不足（`EMFILE`・`ENFILE`・`ENOBUFS`・`ENOMEM`）は 5 ミリ秒から倍にして 1 秒までの間をおいてやり直し（10-16 の手順 4。やり直しの時刻は VM のタイマーの期限に入れて `idle` に渡す次の期限に含め、期限が来たら VM が `Outcome::Ready` の完了を作る）、続けて失敗し始めたときに一度だけ標準エラー出力に一行書く（文は `text` に置く）。この一行の `write_output` が出力の待ち（容量の待ち）を返しても、受け付けの処理は待たずに進む。書き込みは預けられ、後の書き込みに追い越されない（ADR 0265 の決定 4）ので、一行は失われず順も崩れない。ほかの失敗だけを `Result.Error` にする。複数の接続を並べて読む（一つの遅い接続が、ほかの接続の受け付けを止めない）。
- `Http.requestOf(exchange)`（`State`）: `StateServices::resource_table` で添え物を読み、`Http.Request` のレコード（`method`・`path`・`query`・`headers`・`body`）を作る。項目の状態が `Open` でない（解放した後か、解放を始めた後の）`Exchange` では、解放したリソースの使用（ADR 0289、10-16「受け付けた要求の保存」）。ヘッダの名前は小文字にそろえ、受け取った順に並べる。クエリは `?` より後を `&` と `=` で区切り、パーセント符号化を戻し、`+` を空白に戻す（03-09）。符号化を戻せないもの（`%` の後が 16 進の 2 桁でないもの。`?q=%G0`・末尾の `%`）は受け取った字面のまま残し（`Http.pathSegments` と同じ扱い）、`=` のない項目（`?a`）は値が空の文字列の組とし、空の項目（`?a&&b` の間）は飛ばし、`=` が二つ以上ある項目（`?a=b=c`）は最初の `=` で名前と値に分ける。`?` だけか `?` のない要求の対象では `query` を空のリストとする。戻した結果が正しい UTF-8 でないクエリは 400（03-09「要求と応答の型」、ADR 0330 の決定 1、10-16「実装プランで決める値」の「クエリの細部」）。
- `Http.respond(exchange, response)`: `status` が 100 以上 599 以下（03-09「サーバ」）でなければ実行時エラー（`ArgumentOutOfDomain { argument: 1 }`。引数の位置は 0 から数え、応答は二つ目の引数）。二度目の呼び出しは実行時エラー（`ResponseSentTwice`）。解放した後の `Exchange` は解放したリソースの使用。応答を組み立て（10-16「実装プランで決める値」の、処理系が付けるヘッダと理由の句）、書き終えるまで非同期に書く。クライアントが接続を切っていれば `ConnectionReset` などの `Result.Error`。
- `Http.closeListener`（`State`）: L12 が加えた `StateServices::begin_close` で解放を始める（ブロックしない解放。イベントループの登録を外して閉じる）。`CloseStep::Done(Some(理由))` なら、`NetworkErrorKind.Other` と理由の文字列の `NetworkError` の `Result.Error` を返す（ADR 0321 の決定 3）。`with` を抜けるときの解放の失敗は、ほかのリソースの型と同じく実行時エラーになる（`Http.Listener` は例外でない。R24 の解放の枠のまま）。ヒント: `HttpListener` のブロックしない解放は、VM のスレッドで `OsResource::release` として行われ（`resources.rs` の `request_release` が `handle.release()` を呼ぶ）、`runtime::io::http` の関数を経由しない。イベントループの登録を外すには、待ち受けの `OsResource` が `mio::Registry` の写し（`try_clone`）を持ち、`release` の中で `deregister` する。
  - 別のタスクが `Listener` を閉じたときに、その `Listener` の `accept` で準備を待っているタスクの扱いは、03-09 に定めがない。登録を外すと準備の知らせが来ず、`Readiness` の記録が残ったまま待ち続けうる（準備の待ちは行き詰まりの判定で外部の待ちに数えるので、行き詰まりとしても止まらない）。待っているタスクは、閉じた後の `accept` と同じ誤りで起こす。03-09 は閉じた後の `accept` を個別に定めないので、01-10「解放したリソースの使用」のとおり実行時エラー（`RuntimeError::ReleasedResourceUsed`）とする。たとえば、解放のときに、そのリソースを待つ準備の待ちの要求をやり直し、操作の関数が `Released` を見て誤りを返す形にする。この形で書けなければ、完了の報告に書く。
- `Http.closeExchange`（`State`）: 同じく `begin_close` で解放を始める（ブロックする解放。作業用のスレッドで、応答を送っていなければ 500 を送ってから閉じる）。`CloseStep::Wait` なら待ち、解放の完了の後の呼び出しで返る理由を `Result.Error` にする。誤りの種類は `closeListener` と同じく `NetworkErrorKind.Other` とし、理由の文字列を添える（解放の失敗は理由の文字列でしか返らないため。ADR 0321 の決定 3）。`with` を抜けるときの解放の失敗は捨てる（ADR 0149。R24 の分岐。L12 の `begin_close` の上書きは型による分岐を置かないので、`closeExchange` の失敗は返る）。どの経路の解放でも、項目が `Released` になるときに添え物を除く（10-16「受け付けた要求の保存」）。
- `NetworkError.kind`・`message`: `FieldsKind::NetworkError` の対象の `tag` と理由の文字列を読む（10-15「ネットワークの失敗」）。
- スクリプトのテストでは、非公式のモジュールを取り込みの名前で取り込む（`import Benitoite.Unofficial.Network.Http`。[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md) の決定 3）。03-09 の例の `import Benitoite.Network.Http` の形をそのまま写すと、E0321 になる。

### OPEN-062 の R14 について

UTF-8 でない要求の対象とヘッダは、03-09「サーバの接続と要求の読み方」の【方針】（ADR 0291）と 10-16「実装プランで決める値」の「文字列にできない要求」のとおり、HTTP として正しくない要求として 400 を返す。これ以上の規則を作らない。パーセント符号化を戻すと正しい UTF-8 にならないクエリも 400 とし、OPEN-062 の R14 のクエリの項目はこの規則で決着した（ADR 0322 の決定 4）。L33 の R14 の再現テストは 400 を期待する形で書くので、この規則で通る。

## 受け入れテスト

- 項目ごとの単体テスト: `NetworkError.kind`・`message`（9 の種類）。`Http.listen` の `port` の範囲。`requestOf` のクエリとヘッダの組み立て（`+` と `%20`、同じ名前のヘッダ、大文字のヘッダの名前、戻せない符号化 `%G0` と末尾の `%` が字面のまま残ること、`?a` が値の空の組になること、`?` だけと `?` なしで空のリスト）。`resources.rs` の、解放の経路ごとに添え物が除かれること。
- 統合テスト（`Http.listen("127.0.0.1", 0)` で待ち受け、テストの中の `TcpStream` で要求を送る。スクリプトはパイプラインの公開の関数で実行する）:
  - OS が選んだポートの知り方: スクリプトは、待ち受けを始めたら `Http.listenerPort` の値を標準出力に一行で書いてから `accept` に進む。テストは、`RunEnv` の `stdout` に `OutputTarget::Capture` を渡し、その `Arc<Mutex<Vec<u8>>>` を別のスレッドから短い間隔でのぞいて、その行が現れるのを待ってから接続する（実行は別のスレッドで動かす）。VM は、進められるタスクがなくイベントループで待つ前に出力の転送を依頼する（10-10「出力のバッファと書き出し用のスレッド」の表の「進められるタスクがなくなりイベントループで待つ前」、`vm/dispatch/tasks.rs` の `switch_inner` の `idle` の前の `request_transfer`）ので、`accept` で待つ間にその行が現れる。のぞく待ちには十分に長い上限（たとえば 30 秒）を設け、超えたらテストを失敗にする。この待ちは準備ができるまで待つだけで、確かめる結果は時機によらないので、実時間の待ちに頼らないという方針には当たらない（オーケストレータの判断）。
  - `listenerPort` が OS の選んだポートを返す。
  - `accept`・`requestOf`・`respond` の往復。応答の `content-length` と `connection: close`。`respond` の二度目で実行時エラー。解放した後の `respond` と `requestOf` で解放したリソースの使用。多くの要求を受け付けて解放した後に、添え物の表が空に戻る（要求の数に比例して残らない）。
  - 本体の読み方: `content-length`、chunked、両方あるとき 400、本体の上限を 1 バイト超えたとき 413（本体を最後まで読まずに応答する）、頭の上限と 431。
  - 正しくない要求で 400 が返り、同じ `accept` が次の要求を待ち続ける。要求を読み終える前に切れた接続が捨てられ、次の要求を受け付ける。
  - 遅い接続（頭を少しずつ送る）がある間に、別の接続の要求を受け付けて応答できる。
  - `with` の `Exchange` を応答せずに抜けると 500 が返る。クライアントが先に切っても、`with` を抜けるときに実行時エラーにならない（ADR 0149）。`closeExchange` を呼べば失敗を `Result.Error` で読める。
  - `closeListener` の解放の失敗が `Result.Error`（`NetworkErrorKind.Other`）で返り、その後の `with` の解放が失敗なしで終わる。失敗は、`release` が失敗を返す偽の `OsResource` を `ResourceKind::HttpListener` として登録する形で起こす。`tests/` からは動いている実行のリソースの表に項目を入れられないので、このテストは統合テストでなく、`src/` の下のテストのモジュールに置く（L12 の `src/builtins/funcs/file/resource_tests.rs` が前例）。
  - パーセント符号化を戻すと正しい UTF-8 にならないクエリ（`?q=%FF`）の要求に 400 が返り、同じ `accept` が次の要求を待ち続ける。
  - 接続を待つタスクがある間、ほかのタスク（計算を続けるタスク、`Clock.sleep` で待つタスク）が進む。
  - 資源の不足のやり直し（`tests/` の統合テストでなく、`src/runtime/io/http.rs` の単体テストに置く）: 資源の不足の誤りを起こす偽の待ち受け（層の中の非公開の関数で誤りを注入する形。OS の上限を実際に使い切らない）で、やり直しの間隔が 5・10・20… と倍になり 1 秒で止まること、その間もほかのタスクが進むこと、標準エラー出力の一行が一度だけ出ることを、仮想の時間（R25 のテスト用の部品）で確かめる。
  - 準備の知らせ: 準備の待ちのタスクが、`take_ready` から作った `Outcome::Ready` の完了で要求をやり直して進む。テスト用の部品で登録を頼むと `Stop::Internal` になる（テスト用の部品は `tests/` から実行に差し込めないので、この場合は `src/` の下のテストのモジュールに置く。前例は上と同じ）。同じ操作に二つのトークンが来ても、配送の後に古いトークンが来ても、`Stop::Internal` にならない（上の (c)）。別のタスクが `Listener` を閉じると、`accept` で待っているタスクが起き、実行時エラー（解放したリソースの使用）になる。
  - 中断の要求: `accept` で待っている間に中断の要求の印が立つと、止める手順に移り、`with` の `Listener` が解放される（R28 の経路）。`runtime/run.rs` の `run_entry` は、`env.parts` が `Some` のときシグナルを登録せず（`env.interrupt.attach` を呼ばない）、`None` のときも、テストの `InterruptSource` の `attach` は既定の本体（何もせず `Ok(None)`）なので、印を立てるだけでは `idle` の待ちは起きない。テストは、`RuntimeParts::real_with_poll` で作った部品の `workers.wakeup()`（本作業が加える上書きの後は `Some`）で `Wakeup` の写しを取ってから部品を `RunEnv::parts` に渡し、印を立てた後に別のスレッドから `Wakeup::wake` を呼んで起こす。または、印を立てた後に接続して `accept` の準備で起こす。
  - 両方の IO の方式で、上のテストが同じ結果になる。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置、10-16 の型と定数を変えていない
- `mio` の型が `runtime::io::event` と `runtime::io::http` の外に出ていない
- R26 の `Deliver` の処理とイベントループに加えた変更、`httparse` と `mio` の版を完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」「スケジューラと IO」の行。とくに、タスクを待たせてから要求を公開しているか、完了の処理の順序（返却 → 不具合 → 配送）を崩していないか。
- 準備の待ちのやり直しで、取り消したタスクの操作をやり直していないか。記録と登録が漏れなく外れるか。
- edge-triggered の登録で、`WouldBlock` まで進めてから待っているか、向きを変えるときに `reregister` しているか（取りこぼした準備で接続が止まらないか）。
- 一つの接続の失敗や遅さが、待ち受け全体を止めないか。
- 本体の上限を、本体を読む前に判定しているか。
- 03-09 が定めていない振る舞いを、10-16「実装プランで決める値」の外で新しく決めていないか。

## 難易度の理由

非同期の読み書きの途中の状態を持つ接続の層を自作し、VM の待ちとやり直し、イベントループの登録、リソースの状態の機械、取り消し、中断の要求、行き詰まりの判定と正しく組み合わせる必要がある。U2 が使わなかった待つ理由を初めて通すので、R26 のコードに手を入れる。
