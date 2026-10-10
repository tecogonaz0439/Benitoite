# ネットワークのモジュール

## 目的と範囲

`Benitoite.Network` の下のネットワークの操作を行うモジュールの範囲、型、関数、エフェクトを定める。初回リリース版のモジュールは `Benitoite.Network.Http` だけである。

初回リリース版は実行時の権限制御を持たず、ネットワークの操作の許可を調べない（[エフェクト](../01-spec/01-07-effects.md)の「エフェクトの型と権限制御の区別」）。

## 前提

エフェクトとハンドラは[エフェクト](../01-spec/01-07-effects.md)で、リソースの型と `with` は[リソース管理](../01-spec/01-10-resources.md)で、タスクと `TaskGroup` は[並行処理](../01-spec/01-11-concurrency.md)で定める。IO を行うモジュールは[IO のモジュール](03-07-io-modules.md)で、JSON の値の型 `Json.Value` は[テキストとデータの処理](03-08-text-and-data.md)で定める。

## 仕様

### モジュールとエフェクト

【決定】ネットワークの操作を行うモジュールは、`Benitoite.IO` ではなく `Benitoite.Network` の下に置き、import しなければ使えない。`Benitoite.Network.Http` は、次の二つの組み込みのエフェクトを宣言する。

| エフェクト | 表す操作 |
|---|---|
| `Http.Listen` | 接続の待ち受け、要求の受け付けと応答 |
| `Http.Connect` | HTTP のサーバへの接続と、要求の送信 |

- エフェクトの名前は、`import Benitoite.Unofficial.Network.Http` で取り込んだときの書き方である。
- 初回リリース版では、`Benitoite.Network.Http` は非公式のモジュールであり、`import Benitoite.Unofficial.Network.Http` と書いて取り込む（[標準ライブラリ](03-06-stdlib.md)の「標準のモジュールと非公式のモジュール（初回リリース版）」）。取り込んだ後の書き方（`Http.get`、`uses Http.Connect`）は変わらない。本章は、`Unofficial` を挟まない名前で書く。
- ネットワークのエフェクトは `IO.All` に含まれない。理由: ネットワークの操作は、スクリプトを動かす機械の外の資源に触れ、機械の中の操作とは影響の及ぶ範囲が異なる。IO とネットワークの両方を使う関数は `uses IO.All, Http.Connect` のように書く。
- ネットワークの操作も IO 実行器を通し、ハンドラで処理でき、どのハンドラも処理しなければ処理系が実際に行う（[エフェクト](../01-spec/01-07-effects.md)）。

### 範囲

【決定】`Benitoite.Network.Http` に、HTTP/1.1 のサーバとクライアントを入れる。

- サーバは TLS を扱わない。手元の機械の中や、TLS を終端するリバースプロキシの後ろで動かす使い方を対象とする。
- クライアントは、`http` と `https` の URL を扱う。
- TCP と UDP の待ち受けと接続、WebSocket、HTTP/2 は、初回リリース版に入れない。

### 要求と応答の型

【方針】要求と応答を、次のレコードで表す。どれも `Benitoite.Network.Http` の型であり、フィールドは `Http.Request.path(request)` のように取り出す。

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
- 【方針】`query` の細部は次のとおりとする。パーセント符号化を戻せないもの（`%` の後が 16 進の 2 桁でないもの。`?q=%G0` や末尾の `%`）は、その `%` だけを受け取った字面のまま残し、同じ項目のほかの `%XX` と `+` は戻す（`b%20%G0` は `b %G0`）。`=` のない項目（`?a`）は、値が空の文字列の組とする。空の項目（`?a&&b` の間）は飛ばし、`=` が二つ以上ある項目（`?a=b=c`）は最初の `=` で名前と値に分ける。`?` だけの要求の対象と、`?` のない要求の対象では、`query` を空のリストとする。戻した結果が正しい UTF-8 でないクエリは、後述の「サーバの接続と要求の読み方」のとおり、HTTP として正しくない要求として扱う。
- 受け付けた要求と受け取った応答の `headers` は、名前を小文字にそろえ、受け取った順に並べる。同じ名前の組が複数あれば、すべて残す。ただし、クライアントが受け取った応答の `headers` は、名前ごとにまとめた順（同じ名前の値どうしは受け取った順）でもよい。
- 本体は `Bytes` で表す。文字列との変換は `String.fromUTF8`・`String.toUTF8` で行う（[標準ライブラリ](03-06-stdlib.md)）。
- 受け付ける要求の本体の大きさには上限を設け、上限を超える要求には、処理系が状態コード 413 の応答を返す。【方針】上限は 16 MiB（16,777,216 バイト）とする。

### サーバ

【方針】サーバは、待ち受けのリソースの層と、要求から応答への関数を渡す `Http.serve` の二層で提供する。

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

- `Http.Listener` と `Http.Exchange` はリソースの型である（[リソース管理](../01-spec/01-10-resources.md)）。`with` で束縛したときの解放は、それぞれ `Http.closeListener` と `Http.closeExchange` と同じ処理である。この二つの関数は、`Http.Listen` の操作ではなく、`State` を型に持つ組み込みの関数であり、ハンドラで処理できない。解放のエフェクトは `State` である。
- 【方針】`Http.Exchange` の解放では、応答を一バイトも送っていないときだけ状態コード 500 を送る。書き込みの総時間の上限は 3 秒とし、部分書き込みや中断された書き込みをやり直しても期限を延ばさない。期限を超えるか書き込みに失敗したときは、接続を閉じる。応答を書きかけているときは、続きを送らずに接続を shutdown して閉じる。実行時エラーや中断の要求などの止める手順では、500 の送信も、既に始めた解放の完了の待ちも行わず、接続を shutdown して閉じる（[ランタイム](../02-impl/02-09-runtime.md)の「リソースの追跡」）。
- 【決定】`Http.Exchange` の解放の失敗は、実行時エラーにせず、報告もしない（[リソース管理](../01-spec/01-10-resources.md)の「解放の失敗」の例外）。クライアントが接続を切っても、`with` を抜けるときの解放でサーバが止まることはない。解放の失敗を調べるときは、`Http.closeExchange` を呼んで `Result` を調べる。`Http.Listener` の解放の失敗は、ほかのリソースの型と同じく実行時エラーとする。
- `Http.requestOf` は、受け付けた要求を返す。要求は受け付けた時点で読み終えているので、この関数は外部に作用する操作を行わない。【方針】解放した後（解放を始めた後を含む）の `Http.Exchange` に対する `Http.requestOf` と `Http.respond` は、実行時エラー（解放したリソースの使用）とする。処理系は、受け付けた要求の内容を `Http.Exchange` の解放のときに手放す。解放の後にも要求を使うときは、解放の前に `Http.requestOf` で値を得ておく。
- `host` は、待ち受けるアドレスか名前（`"127.0.0.1"`、`"localhost"`、`"0.0.0.0"` など）である。`port` が 0 なら、OS が空いているポートを選ぶ。選ばれたポートは `Http.listenerPort` で調べる。`port` が 0 以上 65535 以下でなければ、実行時エラーとする。
- 一つの `Http.Exchange` に `Http.respond` を二度呼ぶと、実行時エラーとする。
- `Http.respond` は、応答の `status` が 100 以上 599 以下でなければ実行時エラーとする。応答の `Content-Length` は、処理系が本体の大きさから付ける。
- `handler` の中で実行時エラーが起きたときは、ほかのタスクと同じく、プログラム全体を止める（[並行処理](../01-spec/01-11-concurrency.md)の「失敗と停止」）。要求の処理の失敗を応答で表すときは、`handler` が状態コード 500 などの応答を返す。
- `handler` は、`Http.serve` が起動したタスクの中で呼ぶ。そのため、`Http.serve` の呼び出しを囲む `handle` で `handler` のエフェクトを処理するときは、その操作の節を末尾で再開する節にしなければならない。そうでない節は、実行せずに実行時エラー（引き継いだハンドラの節の誤り）とする（[並行処理](../01-spec/01-11-concurrency.md)）。

【方針】`Http.serve` は、標準ライブラリのソースで、次のように書く。受け付けを繰り返し、要求ごとに `TaskGroup.spawn` でタスクを起動する。`TaskGroup.open()` は `with` の束縛の式としてだけ書ける。受け付けに失敗すると `try` で `serveLoop` を終え、`with` を抜けるときに、起動したタスクがすべて終わるのを待つ。

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

【方針】HTTP のサーバの接続と、要求の読み方は次のとおりとする。

- 一つの接続では、一つの要求だけを受け付ける。応答を送った後か、`Http.Exchange` を解放するときに、接続を閉じる。
- 要求の本体は、`content-length` と `transfer-encoding: chunked` のどちらでも読む。どちらもなければ、本体を空とする。両方があるとき、または形が正しくないときは、HTTP として正しくない要求として扱う（後述の「失敗の種類」の、状態コード 400 の応答）。
- 要求の頭（要求の行とヘッダ）の大きさの上限を 64 KiB（65,536 バイト）、ヘッダの数の上限を 100 とする。どちらかを超えた要求には、処理系が状態コード 431 の応答を返し、`Http.accept` は失敗を返さずに次の要求を待つ。
- 要求の対象（パスとクエリ）かヘッダの値を `Http.Request` の `String` の値にできない（正しい UTF-8 でない）要求は、HTTP として正しくない要求として扱う。クエリでは、パーセント符号化を戻した結果が正しい UTF-8 でない場合を含む。
- 【決定】`Http.respond` の応答の `headers` で、名前が RFC 9110 の token の文字以外を含むか、値が制御文字（水平タブを除く 0x00〜0x1F と 0x7F。CR・LF・NUL を含む）を含むときは、送る前に実行時エラー（引数の定義域の外）とする。値に許すのは、水平タブ、見える文字（0x21〜0x7E）、空白、0x80 以上のバイトである。
- 応答の `content-length`（本体の大きさ）と `connection: close` は、処理系が付ける。応答の `headers` に同じ名前（大文字と小文字を区別しない）の組があれば、処理系の値で置き換える。
- 同時に保持する接続の数と、クライアントが要求を送り終えるまでの時間には、上限を設けない。このため、サーバをインターネットに直接さらさず、127.0.0.1 で待ち受けるか、リバースプロキシの後ろで動かす。モジュールの説明も、利用者にこの使い方を示す。

### 応答を作る関数と、要求を調べる関数

【方針】次の関数は、どれも純粋な関数である。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Http.text(status, s)` | `function(Integer, String) -> Http.Response` | 本体を `s` の UTF-8、`content-type` を `text/plain; charset=utf-8` とした応答 |
| `Http.html(status, s)` | `function(Integer, String) -> Http.Response` | 本体を `s` の UTF-8、`content-type` を `text/html; charset=utf-8` とした応答 |
| `Http.json(status, value)` | `function(Integer, Json.Value) -> Http.Response` | 本体を `Json.stringify(value)` の UTF-8、`content-type` を `application/json` とした応答 |
| `Http.pathSegments(path)` | `function(String) -> List[String]` | `path` を `/` で区切り、空の要素を除き、各要素のパーセント符号化を戻した並び。戻した結果が正しい UTF-8 でない要素と、`%` の後が 16 進の 2 桁でない箇所を含む要素は、要素全体を戻さずに残す |
| `Http.header(headers, name)` | `function(List[Pair[String, String]], String) -> Option[String]` | 名前が `name` と大文字と小文字を区別せずに一致する、最初の組の値 |

経路の振り分けは組み込まず、`Http.pathSegments` の値をリストのパターンで照合して振り分ける（[代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)の「パターンの拡張（初回リリース版）」）。

```text
import Benitoite.Unofficial.Network.Http
import Benitoite.Unofficial.Json

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

- 【決定】`Http.send` の要求の `headers` も、`Http.respond` と同じく、名前が token の文字以外を含むか値が制御文字（水平タブを除く 0x00〜0x1F と 0x7F）を含むときは、送る前に実行時エラーとする。
- `Http.clientRequest(method, url)` は、`headers` を空のリスト、`body` を空のバイト列、`timeoutMilliseconds` を 30000 にする。ほかの値にするときは、レコードの更新で変える。
- 状態コードが 4xx や 5xx の応答でも `Result.Ok` を返す。`Result.Error` は、名前を解決できない、接続できない、時間切れになるなど、応答を得られなかったときに返す。
- `timeoutMilliseconds` は、要求を送り始めてから応答の本体を読み終えるまでの時間の上限である。1 未満なら実行時エラーとする。
- `url` の形式が正しくないとき、または `http` と `https` 以外の形式のときは、`NetworkErrorKind.InvalidInput` を返す。
- 【決定】要求の方法は、標準の方法（`GET`・`HEAD`・`POST`・`PUT`・`DELETE`・`CONNECT`・`OPTIONS`・`TRACE`・`PATCH`。大文字と小文字を区別する）に限る。それ以外の方法（`PURGE`、小文字の `get` など）のとき、または方法と本体の組み合わせが正しくないとき（`GET`・`HEAD`・`CONNECT` に空でない本体）は、要求を送らずに `NetworkErrorKind.InvalidInput` を返す。
- 【決定】名前を解決できないときは、OS の解決器が返す誤りの種類によらず `NetworkErrorKind.HostNotFound` を返す。解決が時間切れになったときは `NetworkErrorKind.TimedOut` を返す。
- `https` の URL では、OS のルート証明書でサーバの証明書を検証する。検証に失敗したら `Result.Error` を返す。
- 【方針】初回リリース版のクライアントは、環境変数のプロキシ（`HTTPS_PROXY`・`HTTP_PROXY`・`ALL_PROXY`・`NO_PROXY`）に従わず、接続先に直接つなぐ。
- 【方針】`https` の URL への接続（リダイレクトで `https` に移る場合を含む）では、TLS を組み立てる前に、`graviola` が要する CPU の機能があるかを確かめる。足りなければ、`NetworkErrorKind.Other` と理由の文字列の `Result.Error` を返す。確かめる機能は、`x86_64` では `aes`・`pclmulqdq`・`bmi1`・`adx`・`avx`・`avx2`、`aarch64` では `neon`・`aes`・`pmull`・`sha2` である。`http` の URL は、機能が足りない計算機でも使える。
- リダイレクトの応答（3xx）は、最大 10 回まで辿る。
- 応答の本体は `Bytes` で返すので、1 GiB を超える本体は受け取れない（[ランタイム](../02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」）。
- スクリプトが組み立てたヘッダを送れるので、Basic や Bearer の認証のトークンは `headers` に書いて送れる。初回リリース版は、認証のための仕組み（秘密を渡す受け取り口、OAuth の手順、パスキーなど）を持たない。

### 失敗の種類

【決定】失敗しうる関数は `Result[T, NetworkError]` を返す（[エラー処理](../01-spec/01-09-errors.md)の「ネットワークの失敗の種類（初回リリース版）」）。各関数が返しうる `NetworkErrorKind` は、主に次のとおりである。`NetworkErrorKind.Other` は、どの関数も返しうる。

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

【決定】`Http.accept` は、受け付けの失敗を次のように分けて扱う。

| 失敗 | 当たる場合 | `Http.accept` の扱い |
|---|---|---|
| 接続ごとの失敗 | 受け付けた接続が、要求を読み終える前に切れた、または読み取りに失敗した | その接続を捨て、失敗を返さずに次の要求を待つ |
| 資源の不足 | OS が、開けるファイル記述子の数の上限（プロセスまたはシステム）、メモリやバッファの不足で、接続の受け付けを拒んだ | 失敗を返さず、時間をおいて受け付けをやり直す |
| 待ち受けの失敗 | 上の二つに当たらない失敗 | `Result.Error` を返す |

- 資源の不足でやり直すまで待つ時間は、続けて失敗した最初の回を 5 ミリ秒とし、失敗するたびに 2 倍にして、1 秒を上限とする。受け付けに成功したら、最初の値に戻す。
- 資源の不足で続けて失敗し始めたときに一度だけ、処理系は失敗の理由を標準エラー出力に一行書く。
- やり直すまで待つ間も、ほかのタスクを進め、中断の要求を受け付ける（[並行処理](../01-spec/01-11-concurrency.md)）。

### 実装に使うクレート

【決定】サーバは `httparse` と `mio` の上に HTTP/1.1 の層を自作し、IO 実行器のタスクの切り替えに組み込む。クライアントは `ureq` を IO 実行器の作業用のスレッドで呼び、TLS に `rustls`、暗号の provider に `rustls-graviola`、証明書の検証に `rustls-platform-verifier` を使う（[ライブラリの構成](03-01-library-structure.md)）。`graviola` が対象としない CPU では、`https` の URL を扱えない（前述の「クライアント」の、CPU の機能の確かめ）。
