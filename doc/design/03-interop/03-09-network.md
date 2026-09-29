# ネットワークのモジュール

- 状態: 確定
- 関連ADR: [0056](../decisions/0056-record-fields-via-accessor-functions.md), [0067](../decisions/0067-with-resource-scope.md), [0115](../decisions/0115-structured-io-concurrency.md), [0121](../decisions/0121-pattern-extensions.md), [0129](../decisions/0129-effects-declared-in-modules.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0141](../decisions/0141-http-scope-in-stdlib.md), [0142](../decisions/0142-http-api-shape.md), [0143](../decisions/0143-http-and-tls-crates.md), [0145](../decisions/0145-network-error.md), [0147](../decisions/0147-remove-permission-declaration-syntax.md), [0149](../decisions/0149-http-exchange-release-failure.md), [0150](../decisions/0150-resource-release-as-state.md), [0151](../decisions/0151-inherited-handlers-tail-resume-only.md), [0153](../decisions/0153-taskgroup-open-only-in-with.md), [0170](../decisions/0170-http-accept-failure-classification.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0184](../decisions/0184-permissions-granted-per-builtin-effect.md)
- 未決事項: [OPEN-052](../open-issues.md#open-052), [OPEN-055](../open-issues.md#open-055), [OPEN-062](../open-issues.md#open-062)
- 移行元: なし

## 目的と範囲

`Benitoite.Network` の下のネットワークの操作を行うモジュールの範囲、型、関数、エフェクトを定める。初回リリース版のモジュールは `Benitoite.Network.Http` だけである。

現在の版は、モジュールとエフェクト（[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）、範囲（[ADR 0141](../decisions/0141-http-scope-in-stdlib.md)）、API の形（[ADR 0142](../decisions/0142-http-api-shape.md)）、実装に使うクレート（[ADR 0143](../decisions/0143-http-and-tls-crates.md)）を定め、型と関数の草稿を示す。型と関数の一覧は、どれも【方針】（草稿）である。ネットワークの操作の実行時の権限制御は [OPEN-052](../open-issues.md#open-052) で決める。実行時の権限制御は初回リリース版の後にサーバモードとあわせて加えるものであり、初回リリース版の処理系はネットワークの操作の許可を調べない（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)、[OPEN-055](../open-issues.md#open-055)）。

## 前提

エフェクト、ハンドラ、実行時の権限制御は[エフェクト](../01-spec/01-07-effects.md)で、リソースの型と `with` は[リソース管理](../01-spec/01-10-resources.md)で、タスクと `TaskGroup` は[並行処理](../01-spec/01-11-concurrency.md)で定める。IO を行うモジュールは[IO のモジュール](03-07-io-modules.md)で、JSON の値の型 `Json.Value` は[テキストとデータの処理](03-08-text-and-data.md)で定める。

## 仕様

### モジュールとエフェクト

【決定】ネットワークの操作を行うモジュールは、`Benitoite.IO` ではなく `Benitoite.Network` の下に置き、import しなければ使えない（[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）。`Benitoite.Network.Http` は、次の二つの組み込みのエフェクトを宣言する。

| エフェクト | 表す操作 | 要する権限 |
|---|---|---|
| `Http.Listen` | 接続の待ち受け、要求の受け付けと応答 | `Http.Listen`（対象: 待ち受けるアドレス。書き方は [OPEN-052](../open-issues.md#open-052) で定める） |
| `Http.Connect` | HTTP のサーバへの接続と、要求の送信 | `Http.Connect`（対象: 接続先。書き方は [OPEN-052](../open-issues.md#open-052) で定める） |

- エフェクトの名前は、`import Benitoite.Network.Http` で取り込んだときの書き方である。
- ネットワークのエフェクトは `IO.All` に含まれない。IO とネットワークの両方を使う関数は `uses IO.All, Http.Connect` のように書く。
- ネットワークの操作も IO 実行器を通し、ハンドラで処理でき、どのハンドラも処理しなければ処理系が実際に行う（[エフェクト](../01-spec/01-07-effects.md)）。

### 範囲

【決定】`Benitoite.Network.Http` に、HTTP/1.1 のサーバとクライアントを入れる（[ADR 0141](../decisions/0141-http-scope-in-stdlib.md)）。

- サーバは TLS を扱わない。手元の機械の中や、TLS を終端するリバースプロキシの後ろで動かす使い方を対象とする。
- クライアントは、`http` と `https` の URL を扱う。
- TCP と UDP の待ち受けと接続、WebSocket、HTTP/2 は、初回リリース版に入れない。

### 要求と応答の型

【方針】要求と応答を、次のレコードで表す。どれも `Benitoite.Network.Http` の型であり、フィールドは `Http.Request.path(request)` のように取り出す（[ADR 0056](../decisions/0056-record-fields-via-accessor-functions.md)）。

```text
record Request
  method: String
  path: String
  query: List[Pair[String, String]]
  headers: List[Pair[String, String]]
  body: Bytes
end record

record Response
  status: Integer
  headers: List[Pair[String, String]]
  body: Bytes
end record

record ClientRequest
  method: String
  url: String
  headers: List[Pair[String, String]]
  body: Bytes
  timeoutMilliseconds: Integer
end record
```

- `Request` はサーバが受け付けた要求、`Response` はサーバが返す応答とクライアントが受け取った応答、`ClientRequest` はクライアントが送る要求である。
- `Request` の `method` は、受け付けた要求の方法の名前（`"GET"` など）をそのまま入れる。`path` は、要求の対象のうち `?` より前の部分であり、パーセント符号化を戻さない。`query` は、`?` より後の部分を `&` と `=` で区切り、パーセント符号化を戻した組の並びである。`+` は空白に戻す。
- 受け付けた要求と受け取った応答の `headers` は、名前を小文字にそろえ、受け取った順に並べる。同じ名前の組が複数あれば、すべて残す。
- 本体は `Bytes` で表す。文字列との変換は `String.fromUTF8`・`String.toUTF8` で行う（[標準ライブラリ](03-06-stdlib.md)）。
- 受け付ける要求の本体の大きさには上限を設け、上限を超える要求には、処理系が状態コード 413 の応答を返す。上限の値は実装プランで定める。

### サーバ

【方針】サーバは、待ち受けのリソースの層と、要求から応答への関数を渡す `Http.serve` の二層で提供する（[ADR 0142](../decisions/0142-http-api-shape.md)）。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Http.serve(host, port, handler)` | `function[effect E](String, Integer, function(Http.Request) -> Http.Response uses E) -> Result[Unit, NetworkError] uses Http.Listen, State, E` | `host` の `port` で待ち受け、受け付けた要求ごとにタスクを起動して `handler` を呼び、その値を応答として返す。待ち受けを始められないとき、または `Http.accept` が失敗を返したとき（待ち受けを続けられないとき）に `Result.Error` を返して終わる |
| `Http.listen(host, port)` | `function(String, Integer) -> Result[Http.Listener, NetworkError] uses Http.Listen` | `host` の `port` で待ち受けを始める |
| `Http.listenerPort(listener)` | `function(Http.Listener) -> Integer uses Http.Listen` | 待ち受けているポートの番号 |
| `Http.accept(listener)` | `function(Http.Listener) -> Result[Http.Exchange, NetworkError] uses Http.Listen` | 次の要求を待ち、受け付ける。待つ間は、ほかのタスクを進める（[並行処理](../01-spec/01-11-concurrency.md)）。一つの接続だけの失敗と資源の不足では失敗を返さない（後述の「失敗の種類」） |
| `Http.requestOf(exchange)` | `function(Http.Exchange) -> Http.Request` | 受け付けた要求。純粋な関数である |
| `Http.respond(exchange, response)` | `function(Http.Exchange, Http.Response) -> Result[Unit, NetworkError] uses Http.Listen` | 応答を送る |
| `Http.closeListener(listener)` | `function(Http.Listener) -> Result[Unit, NetworkError] uses State` | 待ち受けをやめる |
| `Http.closeExchange(exchange)` | `function(Http.Exchange) -> Result[Unit, NetworkError] uses State` | 応答を送っていなければ、状態コード 500 の応答を送ってから接続を閉じる。クライアントが接続を切っていれば、`Result.Error` を返しうる |

- `Http.Listener` と `Http.Exchange` はリソースの型である（[リソース管理](../01-spec/01-10-resources.md)）。`with` で束縛したときの解放は、それぞれ `Http.closeListener` と `Http.closeExchange` と同じ処理である。この二つの関数は、`Http.Listen` の操作ではなく、`State` を型に持つ組み込みの関数であり、ハンドラで処理できない。解放のエフェクトは `State` である（[ADR 0150](../decisions/0150-resource-release-as-state.md)）。
- 【決定】`Http.Exchange` の解放の失敗は、実行時エラーにせず、報告もしない（[リソース管理](../01-spec/01-10-resources.md)の「解放の失敗」の例外。[ADR 0149](../decisions/0149-http-exchange-release-failure.md)）。クライアントが接続を切っても、`with` を抜けるときの解放でサーバが止まることはない。解放の失敗を調べるときは、`Http.closeExchange` を呼んで `Result` を調べる。`Http.Listener` の解放の失敗は、ほかのリソースの型と同じく実行時エラーとする。
- `Http.requestOf` は、解放した後の `Http.Exchange` にも使え、受け付けた要求を返す。要求は受け付けた時点で読み終えているので、この関数は外部に作用する操作を行わない。解放した後の `Http.Exchange` に対する `Http.respond` は、実行時エラー（解放したリソースの使用）とする。
- `host` は、待ち受けるアドレスか名前（`"127.0.0.1"`、`"localhost"`、`"0.0.0.0"` など）である。`port` が 0 なら、OS が空いているポートを選ぶ。選ばれたポートは `Http.listenerPort` で調べる。`port` が 0 以上 65535 以下でなければ、実行時エラーとする。
- 一つの `Http.Exchange` に `Http.respond` を二度呼ぶと、実行時エラーとする。
- `Http.respond` は、応答の `status` が 100 以上 599 以下でなければ実行時エラーとする。応答の `Content-Length` は、処理系が本体の大きさから付ける。
- `handler` の中で実行時エラーが起きたときは、ほかのタスクと同じく、プログラム全体を止める（[並行処理](../01-spec/01-11-concurrency.md)の「失敗と停止」）。要求の処理の失敗を応答で表すときは、`handler` が状態コード 500 などの応答を返す。
- `handler` は、`Http.serve` が起動したタスクの中で呼ぶ。そのため、`Http.serve` の呼び出しを囲む `handle` で `handler` のエフェクトを処理するときは、その操作の節を末尾で再開する節にしなければならない。そうでない節は、実行せずに実行時エラー（引き継いだハンドラの節の誤り）とする（[並行処理](../01-spec/01-11-concurrency.md)、[ADR 0151](../decisions/0151-inherited-handlers-tail-resume-only.md)）。

【方針】`Http.serve` は、標準ライブラリのソースで、次のように書く。受け付けを繰り返し、要求ごとに `TaskGroup.spawn` でタスクを起動する。`TaskGroup.open()` は `with` の束縛の式としてだけ書ける（[ADR 0153](../decisions/0153-taskgroup-open-only-in-with.md)）。受け付けに失敗すると `try` で `serveLoop` を終え、`with` を抜けるときに、起動したタスクがすべて終わるのを待つ。

```text
public function serve[effect E](host: String, port: Integer, handler: function(Request) -> Response uses E): Result[Unit, NetworkError] uses Listen, State, E
  with listener = try listen(host, port),
       group = TaskGroup.open() do
    return serveLoop(listener, group, handler)
  end with
end function

function serveLoop[effect E](listener: Listener, group: TaskGroup, handler: function(Request) -> Response uses E): Result[Unit, NetworkError] uses Listen, State, E
  let exchange = try accept(listener)
  let _ = TaskGroup.spawn(group, lambda()
    with current = exchange do
      return respond(current, handler(requestOf(current)))
    end with
  end lambda)
  return serveLoop(listener, group, handler)
end function
```

### 応答を作る関数と、要求を調べる関数

【方針】次の関数は、どれも純粋な関数である。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Http.text(status, s)` | `function(Integer, String) -> Http.Response` | 本体を `s` の UTF-8、`content-type` を `text/plain; charset=utf-8` とした応答 |
| `Http.html(status, s)` | `function(Integer, String) -> Http.Response` | 本体を `s` の UTF-8、`content-type` を `text/html; charset=utf-8` とした応答 |
| `Http.json(status, value)` | `function(Integer, Json.Value) -> Http.Response` | 本体を `Json.stringify(value)` の UTF-8、`content-type` を `application/json` とした応答 |
| `Http.pathSegments(path)` | `function(String) -> List[String]` | `path` を `/` で区切り、空の要素を除き、各要素のパーセント符号化を戻した並び。戻した結果が正しい UTF-8 でない要素は、戻さずに残す |
| `Http.header(headers, name)` | `function(List[Pair[String, String]], String) -> Option[String]` | 名前が `name` と大文字と小文字を区別せずに一致する、最初の組の値 |

経路の振り分けは組み込まず、`Http.pathSegments` の値をリストのパターンで照合して振り分ける（[ADR 0142](../decisions/0142-http-api-shape.md)、[代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)の「パターンの拡張（初回リリース版）」）。

```text
import Benitoite.Network.Http
import Benitoite.Json

function route(request: Http.Request): Http.Response
  let segments = Http.pathSegments(Http.Request.path(request))
  return case Pair(Http.Request.method(request), segments) of
    when Pair("GET", []): Http.html(200, "<h1>Hello</h1>")
    when Pair("GET", ["items", id]): Http.json(200, Json.Value.Object(Map.fromList([Pair("id", Json.Value.String(id))])))
    when _: Http.text(404, "not found")
  end case
end function

function main(): Result[Unit, String] uses Http.Listen, State
  return Http.serve("127.0.0.1", 8080, route) |> Result.mapError(_, NetworkError.message)
end function
```

### クライアント

【方針】クライアントの関数は次のとおりとする。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Http.get(url)` | `function(String) -> Result[Http.Response, NetworkError] uses Http.Connect` | `url` に `GET` の要求を送り、応答を返す。`Http.send(Http.clientRequest("GET", url))` と同じ |
| `Http.clientRequest(method, url)` | `function(String, String) -> Http.ClientRequest` | 後述の既定の値を入れた `Http.ClientRequest` を作る。純粋な関数である |
| `Http.send(request)` | `function(Http.ClientRequest) -> Result[Http.Response, NetworkError] uses Http.Connect` | 要求を送り、応答を返す |

- `Http.clientRequest(method, url)` は、`headers` を空のリスト、`body` を空のバイト列、`timeoutMilliseconds` を 30000 にする。ほかの値にするときは、レコードの更新で変える。
- 状態コードが 4xx や 5xx の応答でも `Result.Ok` を返す。`Result.Error` は、名前を解決できない、接続できない、時間切れになるなど、応答を得られなかったときに返す（[ADR 0142](../decisions/0142-http-api-shape.md)）。
- `timeoutMilliseconds` は、要求を送り始めてから応答の本体を読み終えるまでの時間の上限である。1 未満なら実行時エラーとする。
- `url` の形式が正しくないとき、または `http` と `https` 以外の形式のときは、`NetworkErrorKind.InvalidInput` を返す。
- `https` の URL では、OS のルート証明書でサーバの証明書を検証する（[ADR 0143](../decisions/0143-http-and-tls-crates.md)）。検証に失敗したら `Result.Error` を返す。
- リダイレクトの応答（3xx）は、最大 10 回まで辿る。辿った先の接続の権限の判定は、実行時の権限制御の方式とあわせて [OPEN-052](../open-issues.md#open-052) で決める。

### 失敗の種類

【決定】失敗しうる関数は `Result[T, NetworkError]` を返す（[エラー処理](../01-spec/01-09-errors.md)の「ネットワークの失敗の種類（初回リリース版）」、[ADR 0145](../decisions/0145-network-error.md)）。各関数が返しうる `NetworkErrorKind` は、主に次のとおりである。`NetworkErrorKind.Other` は、どの関数も返しうる。

| `NetworkErrorKind` | 返す主な関数 |
|---|---|
| `HostNotFound` | `Http.get`・`Http.send`、`Http.listen`・`Http.serve`（待ち受ける名前を解決できない） |
| `ConnectionRefused` | `Http.get`・`Http.send` |
| `ConnectionReset` | `Http.get`・`Http.send`・`Http.respond` |
| `TimedOut` | `Http.get`・`Http.send` |
| `AddressInUse` | `Http.listen`・`Http.serve` |
| `InvalidHTTPData` | `Http.get`・`Http.send`（応答が HTTP として正しくない） |
| `InvalidInput` | `Http.get`・`Http.send`（URL の形式）、`Http.listen`・`Http.serve`（アドレスの形式） |
| `PermissionDenied` | `Http.listen`・`Http.serve`（OS が待ち受けを拒んだ） |

- `https` の URL で、サーバの証明書の検証に失敗したときは `NetworkErrorKind.Other` を返し、理由を `NetworkError.message` で示す。
- 受け付けた要求が HTTP として正しくないときは、`Http.accept` は失敗を返さず、処理系が状態コード 400 の応答を返して、次の要求を待つ。

【決定】`Http.accept` は、受け付けの失敗を次のように分けて扱う（[ADR 0170](../decisions/0170-http-accept-failure-classification.md)）。

| 失敗 | 当たる場合 | `Http.accept` の扱い |
|---|---|---|
| 接続ごとの失敗 | 受け付けた接続が、要求を読み終える前に切れた、または読み取りに失敗した | その接続を捨て、失敗を返さずに次の要求を待つ |
| 資源の不足 | OS が、開けるファイル記述子の数の上限（プロセスまたはシステム）、メモリやバッファの不足で、接続の受け付けを拒んだ | 失敗を返さず、時間をおいて受け付けをやり直す |
| 待ち受けの失敗 | 上の二つに当たらない失敗 | `Result.Error` を返す |

- 資源の不足でやり直すまで待つ時間は、続けて失敗した最初の回を 5 ミリ秒とし、失敗するたびに 2 倍にして、1 秒を上限とする。受け付けに成功したら、最初の値に戻す。
- 資源の不足で続けて失敗し始めたときに一度だけ、処理系は失敗の理由を標準エラー出力に一行書く。
- やり直すまで待つ間も、ほかのタスクを進め、中断の要求を受け付ける（[並行処理](../01-spec/01-11-concurrency.md)）。

### 実装に使うクレート

【決定】サーバは `httparse` と `mio` の上に HTTP/1.1 の層を自作し、IO 実行器のタスクの切り替えに組み込む。クライアントは `ureq` を IO 実行器の作業用のスレッドで呼び、TLS に `rustls`、暗号の provider に `rustls-graviola`（第一候補）、証明書の検証に `rustls-platform-verifier` を使う（[ADR 0143](../decisions/0143-http-and-tls-crates.md)、[ライブラリの構成](03-01-library-structure.md)）。`graviola` が対象としない CPU では、`https` の URL を扱えない。

## 未決事項

- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式（ネットワークの操作の権限と、リダイレクトの判定を含む）
- [OPEN-055](../open-issues.md#open-055): サーバモードの設計
- [OPEN-062](../open-issues.md#open-062): 設計書の 2 回目のレビューで指摘された実行時の振る舞いの再現（R14）
