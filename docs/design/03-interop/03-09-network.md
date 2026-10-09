# ネットワークのモジュール

- 状態: 確定
- 関連ADR: [0056](../decisions/0056-record-fields-via-accessor-functions.md), [0067](../decisions/0067-with-resource-scope.md), [0115](../decisions/0115-structured-io-concurrency.md), [0121](../decisions/0121-pattern-extensions.md), [0129](../decisions/0129-effects-declared-in-modules.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0141](../decisions/0141-http-scope-in-stdlib.md), [0142](../decisions/0142-http-api-shape.md), [0143](../decisions/0143-http-and-tls-crates.md), [0145](../decisions/0145-network-error.md), [0147](../decisions/0147-remove-permission-declaration-syntax.md), [0149](../decisions/0149-http-exchange-release-failure.md), [0150](../decisions/0150-resource-release-as-state.md), [0151](../decisions/0151-inherited-handlers-tail-resume-only.md), [0153](../decisions/0153-taskgroup-open-only-in-with.md), [0170](../decisions/0170-http-accept-failure-classification.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0184](../decisions/0184-permissions-granted-per-builtin-effect.md), [0254](../decisions/0254-return-type-after-arrow.md), [0255](../decisions/0255-bind-and-shadow.md), [0257](../decisions/0257-match-with-case-arms.md), [0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md), [0287](../decisions/0287-stdlib-details-decided-in-u3-plan.md), [0289](../decisions/0289-request-of-after-release-is-runtime-error.md), [0291](../decisions/0291-file-copy-limit-and-http-server-details.md), [0322](../decisions/0322-stdlib-details-from-u3-preflight.md), [0330](../decisions/0330-http-details-from-u3-preflight.md), [0331](../decisions/0331-invalid-http-header-characters-stop.md), [0333](../decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md), [0337](../decisions/0337-file-transfer-for-large-copies.md), [0339](../decisions/0339-web-authentication-human-approval-and-browser-first.md), [0354](../decisions/0354-http-exchange-release-deadline.md)
- 未決事項: [OPEN-052](../open-issues.md#open-052), [OPEN-055](../open-issues.md#open-055), [OPEN-062](../open-issues.md#open-062), [OPEN-086](../open-issues.md#open-086), [OPEN-089](../open-issues.md#open-089), [OPEN-091](../open-issues.md#open-091), [OPEN-092](../open-issues.md#open-092), [OPEN-104](../open-issues.md#open-104), [OPEN-105](../open-issues.md#open-105), [OPEN-107](../open-issues.md#open-107), [OPEN-109](../open-issues.md#open-109)
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
- 初回リリース版では、`Benitoite.Network.Http` は非公式のモジュールであり、`import Benitoite.Unofficial.Network.Http` と書いて取り込む（[標準ライブラリ](03-06-stdlib.md)の「標準のモジュールと非公式のモジュール（初回リリース版）」、[ADR 0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md)）。取り込んだ後の書き方（`Http.get`、`uses Http.Connect`）は変わらない。本章は、標準に加えた後の名前で書く。
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
- 【方針】`query` の細部は次のとおりとする（[ADR 0330](../decisions/0330-http-details-from-u3-preflight.md) の決定 1）。パーセント符号化を戻せないもの（`%` の後が 16 進の 2 桁でないもの。`?q=%G0` や末尾の `%`）は、戻さずに受け取った字面のまま残す（`Http.pathSegments` と同じ扱い）。`=` のない項目（`?a`）は、値が空の文字列の組とする。空の項目（`?a&&b` の間）は飛ばし、`=` が二つ以上ある項目（`?a=b=c`）は最初の `=` で名前と値に分ける。`?` だけの要求の対象と、`?` のない要求の対象では、`query` を空のリストとする。戻した結果が正しい UTF-8 でないクエリは、後述の「サーバの接続と要求の読み方」のとおり、HTTP として正しくない要求として扱う。
- 受け付けた要求と受け取った応答の `headers` は、名前を小文字にそろえ、受け取った順に並べる。同じ名前の組が複数あれば、すべて残す。ただし、クライアントが受け取った応答の `headers` は、名前ごとにまとめた順（同じ名前の値どうしは受け取った順）でもよい（[ADR 0322](../decisions/0322-stdlib-details-from-u3-preflight.md) の決定 3）。
- 本体は `Bytes` で表す。文字列との変換は `String.fromUTF8`・`String.toUTF8` で行う（[標準ライブラリ](03-06-stdlib.md)）。
- 受け付ける要求の本体の大きさには上限を設け、上限を超える要求には、処理系が状態コード 413 の応答を返す。【方針】上限は 16 MiB（16,777,216 バイト）とする（[ADR 0287](../decisions/0287-stdlib-details-decided-in-u3-plan.md)）。

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
| `Http.closeExchange(exchange)` | `function(Http.Exchange) -> Result[Unit, NetworkError] uses State` | 応答を一バイトも送っていなければ、総時間 3 秒を上限として状態コード 500 の応答を送ってから接続を閉じる。応答を書きかけていれば、続きを送らずに接続を閉じる。書き込みや接続を閉じる処理が失敗すれば、`Result.Error` を返しうる |

- `Http.Listener` と `Http.Exchange` はリソースの型である（[リソース管理](../01-spec/01-10-resources.md)）。`with` で束縛したときの解放は、それぞれ `Http.closeListener` と `Http.closeExchange` と同じ処理である。この二つの関数は、`Http.Listen` の操作ではなく、`State` を型に持つ組み込みの関数であり、ハンドラで処理できない。解放のエフェクトは `State` である（[ADR 0150](../decisions/0150-resource-release-as-state.md)）。
- 【方針】`Http.Exchange` の解放では、応答を一バイトも送っていないときだけ状態コード 500 を送る。書き込みの総時間の上限は 3 秒とし、部分書き込みや中断された書き込みをやり直しても期限を延ばさない。期限を超えるか書き込みに失敗したときは、接続を閉じる。応答を書きかけているときは、続きを送らずに接続を shutdown して閉じる。実行時エラーや中断の要求などの止める手順では、500 の送信も、既に始めた解放の完了の待ちも行わず、接続を shutdown して閉じる（[ランタイム](../02-impl/02-09-runtime.md)の「リソースの追跡」、[ADR 0354](../decisions/0354-http-exchange-release-deadline.md)）。
- 【決定】`Http.Exchange` の解放の失敗は、実行時エラーにせず、報告もしない（[リソース管理](../01-spec/01-10-resources.md)の「解放の失敗」の例外。[ADR 0149](../decisions/0149-http-exchange-release-failure.md)）。クライアントが接続を切っても、`with` を抜けるときの解放でサーバが止まることはない。解放の失敗を調べるときは、`Http.closeExchange` を呼んで `Result` を調べる。`Http.Listener` の解放の失敗は、ほかのリソースの型と同じく実行時エラーとする。
- `Http.requestOf` は、受け付けた要求を返す。要求は受け付けた時点で読み終えているので、この関数は外部に作用する操作を行わない。【方針】解放した後（解放を始めた後を含む）の `Http.Exchange` に対する `Http.requestOf` と `Http.respond` は、実行時エラー（解放したリソースの使用）とする。処理系は、受け付けた要求の内容を `Http.Exchange` の解放のときに手放す。解放の後にも要求を使うときは、解放の前に `Http.requestOf` で値を得ておく（[ADR 0289](../decisions/0289-request-of-after-release-is-runtime-error.md)）。
- `host` は、待ち受けるアドレスか名前（`"127.0.0.1"`、`"localhost"`、`"0.0.0.0"` など）である。`port` が 0 なら、OS が空いているポートを選ぶ。選ばれたポートは `Http.listenerPort` で調べる。`port` が 0 以上 65535 以下でなければ、実行時エラーとする。
- 一つの `Http.Exchange` に `Http.respond` を二度呼ぶと、実行時エラーとする。
- `Http.respond` は、応答の `status` が 100 以上 599 以下でなければ実行時エラーとする。応答の `Content-Length` は、処理系が本体の大きさから付ける。
- `handler` の中で実行時エラーが起きたときは、ほかのタスクと同じく、プログラム全体を止める（[並行処理](../01-spec/01-11-concurrency.md)の「失敗と停止」）。要求の処理の失敗を応答で表すときは、`handler` が状態コード 500 などの応答を返す。
- `handler` は、`Http.serve` が起動したタスクの中で呼ぶ。そのため、`Http.serve` の呼び出しを囲む `handle` で `handler` のエフェクトを処理するときは、その操作の節を末尾で再開する節にしなければならない。そうでない節は、実行せずに実行時エラー（引き継いだハンドラの節の誤り）とする（[並行処理](../01-spec/01-11-concurrency.md)、[ADR 0151](../decisions/0151-inherited-handlers-tail-resume-only.md)）。

【方針】`Http.serve` は、標準ライブラリのソースで、次のように書く。受け付けを繰り返し、要求ごとに `TaskGroup.spawn` でタスクを起動する。`TaskGroup.open()` は `with` の束縛の式としてだけ書ける（[ADR 0153](../decisions/0153-taskgroup-open-only-in-with.md)）。受け付けに失敗すると `try` で `serveLoop` を終え、`with` を抜けるときに、起動したタスクがすべて終わるのを待つ。

```text
public function serve[effect E](host: String, port: Integer, handler: function(Request) -> Response uses E) -> Result[Unit, NetworkError] uses Listen, State, E
  with listener = try listen(host, port),
    group = TaskGroup.open() do
    return serveLoop(listener, group, handler)
  end with
end function

function serveLoop[effect E](listener: Listener, group: TaskGroup, handler: function(Request) -> Response uses E) -> Result[Unit, NetworkError] uses Listen, State, E
  bind exchange <- try accept(listener)
  bind _ <- TaskGroup.spawn(group, lambda()
    with current = exchange do
      return respond(current, handler(requestOf(current)))
    end with
  end lambda)
  return serveLoop(listener, group, handler)
end function
```

### サーバの接続と要求の読み方

【方針】HTTP のサーバの接続と、要求の読み方は次のとおりとする（[ADR 0291](../decisions/0291-file-copy-limit-and-http-server-details.md)）。

- 一つの接続では、一つの要求だけを受け付ける。応答を送った後か、`Http.Exchange` を解放するときに、接続を閉じる。
- 要求の本体は、`content-length` と `transfer-encoding: chunked` のどちらでも読む。どちらもなければ、本体を空とする。両方があるとき、または形が正しくないときは、HTTP として正しくない要求として扱う（後述の「失敗の種類」の、状態コード 400 の応答）。
- 要求の頭（要求の行とヘッダ）の大きさの上限を 64 KiB（65,536 バイト）、ヘッダの数の上限を 100 とする。どちらかを超えた要求には、処理系が状態コード 431 の応答を返し、`Http.accept` は失敗を返さずに次の要求を待つ。
- 要求の対象（パスとクエリ）かヘッダの値を `Http.Request` の `String` の値にできない（正しい UTF-8 でない）要求は、HTTP として正しくない要求として扱う。クエリでは、パーセント符号化を戻した結果が正しい UTF-8 でない場合を含む。クエリのこの扱いは、[OPEN-062](../open-issues.md#open-062) の R14 が挙げた修正の候補（戻せないものを受け取ったままにする）と異なるが、この規則で R14 のクエリの項目を決着とする（[ADR 0322](../decisions/0322-stdlib-details-from-u3-preflight.md) の決定 4）。
- 【決定】`Http.respond` の応答の `headers` で、名前が RFC 9110 の token の文字以外を含むか、値が制御文字（水平タブを除く 0x00〜0x1F と 0x7F。CR・LF・NUL を含む）を含むときは、送る前に実行時エラー（引数の定義域の外）とする。値に許すのは、水平タブ、見える文字（0x21〜0x7E）、空白、0x80 以上のバイトである（[ADR 0331](../decisions/0331-invalid-http-header-characters-stop.md)、[ADR 0333](../decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md) の決定 3）。
- 応答の `content-length`（本体の大きさ）と `connection: close` は、処理系が付ける。応答の `headers` に同じ名前（大文字と小文字を区別しない）の組があれば、処理系の値で置き換える。

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

function route(request: Http.Request) -> Http.Response
  bind segments <- Http.pathSegments(Http.Request.path(request))
  return match Pair(Http.Request.method(request), segments) with
    case Pair("GET", []) -> Http.html(200, "<h1>Hello</h1>")
    case Pair("GET", ["items", id]) -> Http.json(200, Json.Value.Object(Map.fromList([Pair("id", Json.Value.String(id))])))
    case _ -> Http.text(404, "not found")
  end match
end function

function main() -> Result[Unit, String] uses Http.Listen, State
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

- 【決定】`Http.send` の要求の `headers` も、`Http.respond` と同じく、名前が token の文字以外を含むか値が制御文字（水平タブを除く 0x00〜0x1F と 0x7F）を含むときは、送る前に実行時エラーとする（[ADR 0331](../decisions/0331-invalid-http-header-characters-stop.md)、[ADR 0333](../decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md) の決定 3）。
- `Http.clientRequest(method, url)` は、`headers` を空のリスト、`body` を空のバイト列、`timeoutMilliseconds` を 30000 にする。ほかの値にするときは、レコードの更新で変える。
- 状態コードが 4xx や 5xx の応答でも `Result.Ok` を返す。`Result.Error` は、名前を解決できない、接続できない、時間切れになるなど、応答を得られなかったときに返す（[ADR 0142](../decisions/0142-http-api-shape.md)）。
- `timeoutMilliseconds` は、要求を送り始めてから応答の本体を読み終えるまでの時間の上限である。1 未満なら実行時エラーとする。
- `url` の形式が正しくないとき、または `http` と `https` 以外の形式のときは、`NetworkErrorKind.InvalidInput` を返す。
- 【決定】要求の方法は、標準の方法（`GET`・`HEAD`・`POST`・`PUT`・`DELETE`・`CONNECT`・`OPTIONS`・`TRACE`・`PATCH`。大文字と小文字を区別する）に限る。それ以外の方法（`PURGE`、小文字の `get` など）のとき、または方法と本体の組み合わせが正しくないとき（`GET`・`HEAD`・`CONNECT` に空でない本体）は、要求を送らずに `NetworkErrorKind.InvalidInput` を返す（[ADR 0333](../decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md) の決定 3）。
- 【決定】名前を解決できないときは、解決器が返す誤りの形によらず `NetworkErrorKind.HostNotFound` を返す（[ADR 0333](../decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md) の決定 3）。
- `https` の URL では、OS のルート証明書でサーバの証明書を検証する（[ADR 0143](../decisions/0143-http-and-tls-crates.md)）。検証に失敗したら `Result.Error` を返す。
- 【方針】初回リリース版のクライアントは、環境変数のプロキシ（`HTTPS_PROXY`・`HTTP_PROXY`・`ALL_PROXY`・`NO_PROXY`）に従わず、接続先に直接つなぐ（[ADR 0330](../decisions/0330-http-details-from-u3-preflight.md) の決定 2）。
- 【方針】`https` の URL への接続（リダイレクトで `https` に移る場合を含む）では、TLS を組み立てる前に、`graviola` が要する CPU の機能があるかを確かめる。足りなければ、`NetworkErrorKind.Other` と理由の文字列の `Result.Error` を返す。確かめる機能は、`x86_64` では `aes`・`pclmulqdq`・`bmi1`・`adx`・`avx`・`avx2`、`aarch64` では `neon`・`aes`・`pmull`・`sha2` である。`http` の URL は、機能が足りない計算機でも使える（[ADR 0330](../decisions/0330-http-details-from-u3-preflight.md) の決定 3）。
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
| `InvalidInput` | `Http.get`・`Http.send`（URL の形式、標準でない方法、方法と本体の組み合わせ）、`Http.listen`・`Http.serve`（アドレスの形式） |
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

【決定】サーバは `httparse` と `mio` の上に HTTP/1.1 の層を自作し、IO 実行器のタスクの切り替えに組み込む。クライアントは `ureq` を IO 実行器の作業用のスレッドで呼び、TLS に `rustls`、暗号の provider に `rustls-graviola`（第一候補）、証明書の検証に `rustls-platform-verifier` を使う（[ADR 0143](../decisions/0143-http-and-tls-crates.md)、[ライブラリの構成](03-01-library-structure.md)）。`graviola` が対象としない CPU では、`https` の URL を扱えない（前述の「クライアント」の、CPU の機能の確かめ）。

### 応答の本体を流す操作（初回リリース版の後）

`Http.get`・`Http.send` は応答の本体を `Bytes` で返すので、1 GiB を超える本体（導入のパッケージなど）を受け取れない（[ランタイム](../02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」）。

【未決】初回リリース版の後に、応答の本体を開いた `File.Writer` に流す操作（`Http.sendTo(request, writer)` など。`Http.Connect` の操作）を加えるかは、[OPEN-086](../open-issues.md#open-086) で決める。ファイルのリソースどうしを流す `File.transfer`（[IO のモジュール](03-07-io-modules.md)の「大きなファイルを流す操作（初回リリース版の後）」、[ADR 0337](../decisions/0337-file-transfer-for-large-copies.md)）と同じ形である。

### ウェブの認証（初回リリース版の後）

初回リリース版のクライアントは、スクリプトが組み立てたヘッダを送れるので、Basic や Bearer のトークンは `headers` に書いて送れる。認証のための仕組み（秘密を渡す受け取り口、OAuth の手順、パスキーなど）は持たない。

【決定】初回リリース版の後に、標準ライブラリや公式のライブラリでウェブの認証を支える機能を加えるときは、次の方針に従う（[ADR 0339](../decisions/0339-web-authentication-human-approval-and-browser-first.md)）。初回リリース版のクライアントは変えない。

1. 認証のときには、人間による承認の操作を必ず挟む。ブラウザに任せる形ではブラウザでの承認、物理キーと OS の認証器ではキーや OS が求める操作、パスワードやトークンを渡す方式では処理系が用意する秘密の入力の経路での入力や承認で挟む。
2. ウェブの認証は、ブラウザに任せる形を本命とする。サイトが対応していれば、OAuth のデバイス認可（RFC 8628）や、認可コードと PKCE をループバックの宛先で受ける形（RFC 8252）などで、利用者がブラウザで承認し、スクリプトはトークンだけを受け取る形を第一に支える。処理系が WebAuthn のクライアントになる形は、本命としない。

【未決】次の点は未決である。

- 加える機能の範囲と順。HTTP の要求のヘッダに秘密の型の値を渡す受け取り口、秘密を渡したヘッダをホストが変わるリダイレクトで送らない規則、TOTP のための HMAC、OAuth の手順の例、ログインのフォームの自動化（[OPEN-091](../open-issues.md#open-091)）。
- パスワードやトークンを渡す方式で、承認を求めるたびに挟むか、サーバモードの登録のときの承認で済ませるかを選べるようにするか（[OPEN-089](../open-issues.md#open-089)）。
- 物理キーなどに限って、処理系が WebAuthn のクライアントになる形を設けるか。設けるなら、署名に入れるオリジンを処理系が接続している宛先から決める規則（[OPEN-092](../open-issues.md#open-092)）。

## 未決事項

- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式（ネットワークの操作の権限と、リダイレクトの判定を含む）
- [OPEN-055](../open-issues.md#open-055): サーバモードの設計
- [OPEN-062](../open-issues.md#open-062): 設計書の 2 回目のレビューで指摘された実行時の振る舞いの再現（R14）
- [OPEN-086](../open-issues.md#open-086): 開いたリソースへ流す操作の広げ方（応答の本体を `File.Writer` に流す操作）
- [OPEN-089](../open-issues.md#open-089): 人間から秘密を受け取る経路（パスワードやトークンを渡す方式で承認を挟む位置）
- [OPEN-091](../open-issues.md#open-091): HTTP の認証を支える機能の範囲
- [OPEN-092](../open-issues.md#open-092): 処理系が WebAuthn のクライアントになる形
- [OPEN-104](../open-issues.md#open-104): HTTP のサーバの要求ごとの失敗の隔離（初回リリース版の後に、`handler` の中の実行時エラーで要求のタスクだけを止める形を設けるか）
- [OPEN-105](../open-issues.md#open-105): DB へ到達する手段（初回リリース版の後に、SQLite を組み込むか、TCP と TLS のクライアントを加えるか）
- [OPEN-107](../open-issues.md#open-107): 流しながら読み書きする HTTP の本体と、接続の再利用（初回リリース版の後）
- [OPEN-109](../open-issues.md#open-109): Web システムに要る標準ライブラリの部品の範囲（初回リリース版の後。暗号、Cookie、セッション、CORS、テンプレートなど）
