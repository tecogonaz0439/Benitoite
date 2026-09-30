# L30 HTTP のサーバの接続の層

- 依存する作業: [L03](L03-bytes.md)、[R24](R24-resources.md)、[R26](R26-dispatch-queue-and-io-executor.md)、[R27](R27-output-writers.md)、[R28](R28-interrupt-and-stop-procedure.md)
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

依存の理由: 要求と応答の本体は `Bytes`（L03）。リソースの表と解放の枠（R24）、送り出しの列・外部の操作の記録・イベントループ（R26）、出力（R27。資源の不足の一行を標準エラー出力に書く）、止める手順と中断の要求（R28）の上に作る。

## 読む設計書の節

- [ネットワークのモジュール](../../design/03-interop/03-09-network.md)の「モジュールとエフェクト」「範囲」「要求と応答の型」「サーバ」「サーバの接続と要求の読み方」「失敗の種類」「実装に使うクレート」
- [リソース管理](../../design/01-spec/01-10-resources.md)の「解放の失敗」「解放したリソースの使用」
- [並行処理](../../design/01-spec/01-11-concurrency.md)の、待つ間にほかのタスクを進めること、「失敗と停止」
- [エラー処理](../../design/01-spec/01-09-errors.md)の「ネットワークの失敗の種類（初回リリース版）」
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」（操作を行う場所の表と、`Http.accept` の失敗の分類の箇条）、「IO 実行器」、「リソースの追跡」（`Http.Listener`・`Http.Exchange` の解放）、「中断の要求」、「panic 境界」（イベントループと HTTP のサーバの層が境界の中にあること）
- [仮想機械](../../design/02-impl/02-08-vm.md)の「組み込みの関数の呼び出し」の待つ理由の表（イベントループの準備）、「タスクの切り替え」（行き詰まりの判定）
- [未決・要検証事項](../../design/open-issues.md#open-062)の OPEN-062 の R04・R14
- ADR: [0143](../../design/decisions/0143-http-and-tls-crates.md)、[0149](../../design/decisions/0149-http-exchange-release-failure.md)、[0170](../../design/decisions/0170-http-accept-failure-classification.md)、[0162](../../design/decisions/0162-event-loop-and-worker-threads-for-io.md)、[0145](../../design/decisions/0145-network-error.md)、[0150](../../design/decisions/0150-resource-release-as-state.md)、[0266](../../design/decisions/0266-task-and-resource-state-machines.md)、[0283](../../design/decisions/0283-deadlock-counts-only-waits-that-can-wake-tasks.md)、[0287](../../design/decisions/0287-stdlib-details-decided-in-u3-plan.md) の決定 2

インターフェース:

- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「ランタイムの内部への口」「受け付けた要求の保存」「HTTP のサーバの接続の層」（準備の待ちの規則、実装プランで決める値）、「使うクレート」の `httparse`・`mio`、「テスト用のハンドラ表のネットワークの失敗」（`Http.listen` に当てる分）
- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「ネットワーク」「ネットワークの失敗」の表、「項目の種類と権限」、`Network/Http.bnt`・`NetworkError.bnt`・`NetworkErrorKind.bnt`、「構成子のタグ」の `NETWORK_ERROR_KIND_*`、「レコードの値の作り方」
- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の「外部の操作の記録と完了」「リソースの表と状態」「イベントループ」「完了の処理と行き詰まりの判定の順序」
- [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `IoWait::Readiness`・`Interest`・`OsResource`・`StateServices::begin_release`
- R24 の作業の文書（`HttpListener` はブロックしない解放、`HttpExchange` はブロックする解放で失敗を捨てる）、R26 の作業の文書（`Deliver` の処理、イベントループ）

## 作るもの

- `src/runtime/io/http.rs`: 接続の層（待ち受けと接続の OS の資源、読みかけの要求と書きかけの応答、`httparse` による解析、本体の読み方、応答の組み立て、イベントループへの登録、受け付けのやり直しの時刻）。`mio` の型はこのモジュールと `event.rs` の中に閉じる（10-16）
- `src/runtime/io/event.rs`（R26）に、この層から使う `pub(crate)` の登録の関数を加えたもの
- VM の `Deliver` の処理（R26）に、準備の待ちの完了で要求をやり直す分岐を加えたもの（10-16「準備の待ちの規則」の手順 3）
- `src/builtins/funcs/http_server.rs`・`network_error.rs` の 9 項目の本体と単体テスト
- `mio` の機能 `net` と `httparse` の依存（10-16 の表の指定）
- 統合テスト（`tests/` の下。HTTP の要求はテストの中の Rust の `TcpStream` で送る。スクリプトからのクライアントは L32、`network` のゴールデンテストは L33）

## 手順の要点

### 準備の待ちと VM

10-16「準備の待ちの規則」の 1〜5 のとおりに組み込む。要点は次のとおりである。

- `IoWait::Readiness { resource, interest }` を受けた VM は、`OpKind::Readiness` の記録を加え、タスクを `WaitReason::Readiness(番号)` で待たせ、`runtime::io::http` にそのリソースの登録を頼む。準備の知らせ（`Outcome::Ready`）を受けたら、タスクがまだ待っていれば、同じ `site` の操作を送り出しの列にもう一度置く。結果の値は作らない。
- 操作の関数は、もう一度呼ばれたときにリソースに残した途中の状態から続ける。呼ばれるたびに非同期の読み書きを `WouldBlock` まで進め、終われば完了、進めなければもう一度 `Readiness` を返す。
- 取り消したタスクの `Readiness` の記録は配送先を外して残し、準備が来たら捨てる。登録は、記録を捨てるときかリソースを解放するときに外す。
- 準備の待ちは外部の待ちであり、行き詰まりの判定に数える。接続を待つだけのサーバのタスクは行き詰まりにならない。
- 両方の IO の方式（直接呼び出しと要求と応答）で動くようにする（ADR 0264 の決定 7）。

### 操作ごと

- `Http.listen(host, port)`: `port` が 0 以上 65535 以下でなければ実行時エラー（`ArgumentOutOfDomain`、引数の位置 1）。テスト用のハンドラ表に `host` の失敗があれば、その `NetworkError` を返す（10-16）。名前の解決と待ち受けの開始（`std::net::TcpListener::bind` の後に非同期にして `mio::net::TcpListener` にする）を作業用のスレッドで行い、完了の処理で `register_resource(ResourceKind::HttpListener, …)`。解決の失敗は `HostNotFound`、使われているアドレスは `AddressInUse`、アドレスの形の誤りは `InvalidInput`、OS の拒否は `PermissionDenied`（03-09 の表）。
- `Http.listenerPort(listener)`: `runtime_view` でリソースを読み、`local_addr` のポートを返す。
- `Http.accept(listener)`: 受け付けて、要求を読み終えたら、接続を `ResourceKind::HttpExchange` のリソースとして表に加え、要求の内容をリソースの表の添え物（`ResourceTable::attachments`）に加え（10-16「受け付けた要求の保存」）、`Result.Ok(Exchange)` を返す。要求が HTTP として正しくなければ、処理系が 400 を返して接続を閉じ、次の要求を待つ（03-09）。本体が上限（`MAX_REQUEST_BODY_BYTES`）を超えたら 413。受け付けの失敗は ADR 0170 の三つに分け、接続ごとの失敗は捨てて次を待ち、資源の不足（`EMFILE`・`ENFILE`・`ENOBUFS`・`ENOMEM`）は 5 ミリ秒から倍にして 1 秒までの間をおいてやり直し（10-16 の手順 4）、続けて失敗し始めたときに一度だけ標準エラー出力に一行書く（文は `text` に置く）。ほかの失敗だけを `Result.Error` にする。複数の接続を並べて読む（一つの遅い接続が、ほかの接続の受け付けを止めない）。
- `Http.requestOf(exchange)`（`State`）: `StateServices::resource_table` で添え物を読み、`Http.Request` のレコード（`method`・`path`・`query`・`headers`・`body`）を作る。項目の状態が `Open` でない（解放した後か、解放を始めた後の）`Exchange` では、解放したリソースの使用（ADR 0289、10-16「受け付けた要求の保存」）。ヘッダの名前は小文字にそろえ、受け取った順に並べる。クエリは `?` より後を `&` と `=` で区切り、パーセント符号化を戻し、`+` を空白に戻す（03-09）。
- `Http.respond(exchange, response)`: `status` が 100 以上 599 以下でなければ実行時エラー。二度目の呼び出しは実行時エラー（`ResponseSentTwice`）。解放した後の `Exchange` は解放したリソースの使用。応答を組み立て（10-16「実装プランで決める値」の、処理系が付けるヘッダと理由の句）、書き終えるまで非同期に書く。クライアントが接続を切っていれば `ConnectionReset` などの `Result.Error`。
- `Http.closeListener`（`State`）: `begin_release` で解放を始める（ブロックしない解放。イベントループの登録を外して閉じる）。解放の失敗は実行時エラーの規則に従う（`Http.Listener` は例外でない）。
- `Http.closeExchange`（`State`）: `begin_release` で解放を始める（ブロックする解放。作業用のスレッドで、応答を送っていなければ 500 を送ってから閉じる）。`closeExchange` を呼んだときは失敗を `Result.Error` で返す。`with` を抜けるときの解放の失敗は捨てる（ADR 0149。R24 の分岐）。どの経路の解放でも、項目が `Released` になるときに添え物を除く（10-16「受け付けた要求の保存」）。
- `NetworkError.kind`・`message`: `FieldsKind::NetworkError` の対象の `tag` と理由の文字列を読む（10-15「ネットワークの失敗」）。

### OPEN-062 の R14 について

UTF-8 でない要求の対象とヘッダは、03-09「サーバの接続と要求の読み方」の【方針】（ADR 0291）と 10-16「実装プランで決める値」の「文字列にできない要求」のとおり、HTTP として正しくない要求として 400 を返す。これ以上の規則を作らない。クエリの扱いは OPEN-062 の R14 の修正の候補と異なる。R14 の再現テストは L33 が書き、結果を設計者に示す。

## 受け入れテスト

- 項目ごとの単体テスト: `NetworkError.kind`・`message`（9 の種類）。`Http.listen` の `port` の範囲。`requestOf` のクエリとヘッダの組み立て（`+` と `%20`、同じ名前のヘッダ、大文字のヘッダの名前）。
- 統合テスト（`Http.listen("127.0.0.1", 0)` で待ち受け、テストの中の `TcpStream` で要求を送る。スクリプトはパイプラインの公開の関数で実行する）:
  - `listenerPort` が OS の選んだポートを返す。
  - `accept`・`requestOf`・`respond` の往復。応答の `content-length` と `connection: close`。`respond` の二度目で実行時エラー。解放した後の `respond` と `requestOf` で解放したリソースの使用。多くの要求を受け付けて解放した後に、添え物の表が空に戻る（要求の数に比例して残らない）。
  - 本体の読み方: `content-length`、chunked、両方あるとき 400、本体の上限を 1 バイト超えたとき 413（本体を最後まで読まずに応答する）、頭の上限と 431。
  - 正しくない要求で 400 が返り、同じ `accept` が次の要求を待ち続ける。要求を読み終える前に切れた接続が捨てられ、次の要求を受け付ける。
  - 遅い接続（頭を少しずつ送る）がある間に、別の接続の要求を受け付けて応答できる。
  - `with` の `Exchange` を応答せずに抜けると 500 が返る。クライアントが先に切っても、`with` を抜けるときに実行時エラーにならない（ADR 0149）。`closeExchange` を呼べば失敗を `Result.Error` で読める。
  - 接続を待つタスクがある間、ほかのタスク（計算を続けるタスク、`Clock.sleep` で待つタスク）が進む。
  - 資源の不足のやり直し: 資源の不足の誤りを起こす偽の待ち受け（層の中の非公開の関数で誤りを注入する形。OS の上限を実際に使い切らない）で、やり直しの間隔が 5・10・20… と倍になり 1 秒で止まること、その間もほかのタスクが進むこと、標準エラー出力の一行が一度だけ出ることを、仮想の時間（R25 のテスト用の部品）で確かめる。
  - 中断の要求: `accept` で待っている間に中断の要求の印が立つと、止める手順に移り、`with` の `Listener` が解放される（R28 の経路）。
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
- 一つの接続の失敗や遅さが、待ち受け全体を止めないか。
- 本体の上限を、本体を読む前に判定しているか。
- 03-09 が定めていない振る舞いを、10-16「実装プランで決める値」の外で新しく決めていないか。

## 難易度の理由

非同期の読み書きの途中の状態を持つ接続の層を自作し、VM の待ちとやり直し、イベントループの登録、リソースの状態の機械、取り消し、中断の要求、行き詰まりの判定と正しく組み合わせる必要がある。U2 が使わなかった待つ理由を初めて通すので、R26 のコードに手を入れる。
