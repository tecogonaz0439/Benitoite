# ネットワークのモジュール

## 目的と範囲

`Benitoite.Network` の下のネットワークの操作を行うモジュールの範囲、型、関数、エフェクトを定める。初回リリース版のモジュールは `Benitoite.Network.Http` だけである。

初回リリース版は実行時の権限制御を持たず、ネットワークの操作の許可を調べない（[エフェクト](../01-spec/01-07-effects.md)の「エフェクトの型と権限制御の区別」）。

## 前提

エフェクトとハンドラは[エフェクト](../01-spec/01-07-effects.md)で、リソースの型と `with` は[リソース管理](../01-spec/01-10-resources.md)で、タスクと `TaskGroup` は[並行処理](../01-spec/01-11-concurrency.md)で定める。IO を行うモジュールは[IO のモジュール](03-07-io-modules.md)で、JSON の値の型 `Json.Value` は[テキストとデータの処理](03-08-text-and-data.md)で定める。

## 仕様

【決定】ネットワークの失敗値 `NetworkError` は、`Benitoite.Trait` の `Show` 実装で `NetworkError.message` の文字列をそのまま表示する。`try Http.get(url) or die` の原因にもこの実装を使い、失敗値を String へ変換するだけの `Result.mapError` は必要としない。終了には Process.Exit が加わる（[標準ライブラリ](03-06-stdlib.md#標準の型クラス初回リリース版)、[エラー処理](../01-spec/01-09-errors.md#失敗時に終了する処置)）。

関数一覧の表の `f(a, b)` は、関数とパラメータを示す記法である。実際のコードでは、複数の引数を取る通常の関数は宣言のパラメータ名を付けて名前付きで呼ぶ。

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

【決定】`Http.RequestIn` は、端点の範囲を添字に持つ組み込みの不透明型であり、型注釈で利用できる。裸の `Http.RequestIn` は Top、`Http.RequestIn["api.example", 443]` はホストとポートを組にした一つの範囲を表す。型引数と複数の範囲は持たない。利用者による構築・更新・表現のパターン・自動アクセサは認めない。添字の不変性と照合の制限は[型システム](../01-spec/01-06-type-system.md#範囲付きの不透明標準型)に従う。

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
- `Request` の `method` は、受け付けた要求の方法の名前（`"GET"` など）をそのまま入れる。`path` は、要求の対象のうち `?` より前の部分であり、パーセント符号化を戻さない。絶対形は後述の規則で変換し、パスもクエリもない `OPTIONS` の絶対形では `path` を `*` とする。`query` は、`?` より後の部分を `&` と `=` で区切り、パーセント符号化を戻した組の並びである。`+` は空白に戻す。
- 【方針】`query` の細部は次のとおりとする。パーセント符号化を戻せないもの（`%` の後が 16 進の 2 桁でないもの。`?q=%G0` や末尾の `%`）は、その `%` だけを受け取った字面のまま残し、同じ項目のほかの `%XX` と `+` は戻す（`b%20%G0` は `b %G0`）。`=` のない項目（`?a`）は、値が空の文字列の組とする。空の項目（`?a&&b` の間）は飛ばし、`=` が二つ以上ある項目（`?a=b=c`）は最初の `=` で名前と値に分ける。`?` だけの要求の対象と、`?` のない要求の対象では、`query` を空のリストとする。戻した結果が正しい UTF-8 でないクエリは、後述の「サーバの接続と要求の読み方」のとおり、HTTP として正しくない要求として扱う。
- 受け付けた要求と受け取った応答の `headers` は、名前を小文字にそろえ、受け取った順に並べる。同じ名前の組が複数あれば、すべて残す。ただし、クライアントが受け取った応答の `headers` は、名前ごとにまとめた順（同じ名前の値どうしは受け取った順）でもよい。
- 本体は `Bytes` で表す。文字列との変換は `String.fromUTF8`・`String.toUTF8` で行う（[標準ライブラリ](03-06-stdlib.md)）。
- 受け付ける要求の本体の大きさには上限を設け、上限を超える要求には、処理系が状態コード 413 の応答を返す。【方針】上限は 16 MiB（16,777,216 バイト）とする。

### サーバ

【方針】サーバは、待ち受けのリソースの層と、要求から応答への関数を渡す `Http.serve` の二層で提供する。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Http.serve(host, port, handler)` | `function[effect E](host: String, port: Integer, handler: function(request: Http.Request) -> Http.Response uses E) -> Result[Unit, NetworkError] uses Http.Listen, State, E` | `host` の `port` で待ち受け、受け付けた要求ごとにタスクを起動して `handler` を呼び、その値を応答として返す。待ち受けを始められないとき、または `Http.accept` が失敗を返したとき（待ち受けを続けられないとき）に `Result.Error` を返して終わる |
| `Http.listen(host, port)` | `function(host: String, port: Integer) -> Result[Http.Listener, NetworkError] uses Http.Listen` | `host` の `port` で待ち受けを始める |
| `Http.listenerPort(listener)` | `function(listener: Http.Listener) -> Integer uses Http.Listen` | 待ち受けているポートの番号 |
| `Http.accept(listener)` | `function(listener: Http.Listener) -> Result[Http.Exchange, NetworkError] uses Http.Listen` | 次の要求を待ち、受け付ける。待つ間は、ほかのタスクを進める（[並行処理](../01-spec/01-11-concurrency.md)）。一つの接続だけの失敗と資源の不足では失敗を返さない（後述の「失敗の種類」） |
| `Http.requestOf(exchange)` | `function(exchange: Http.Exchange) -> Http.Request` | 受け付けた要求。純粋な関数である |
| `Http.respond(exchange, response)` | `function(exchange: Http.Exchange, response: Http.Response) -> Result[Unit, NetworkError] uses Http.Listen` | 応答を送る |
| `Http.closeListener(listener)` | `function(listener: Http.Listener) -> Result[Unit, NetworkError] uses State` | 待ち受けをやめる |
| `Http.closeExchange(exchange)` | `function(exchange: Http.Exchange) -> Result[Unit, NetworkError] uses State` | 応答を一バイトも送っていなければ、総時間 3 秒を上限として状態コード 500 の応答を送ってから接続を閉じる。応答を書きかけていれば、続きを送らずに接続を閉じる。書き込みや接続を閉じる処理が失敗すれば、`Result.Error` を返しうる |

- `Http.Listener` と `Http.Exchange` はリソースの型である（[リソース管理](../01-spec/01-10-resources.md)）。`with` で束縛したときの解放は、それぞれ `Http.closeListener` と `Http.closeExchange` と同じ処理である。この二つの関数は、`Http.Listen` の操作ではなく、`State` を型に持つ組み込みの関数であり、ハンドラで処理できない。解放のエフェクトは `State` である。
- 【方針】`Http.Exchange` の解放では、応答を一バイトも送っていないときだけ状態コード 500 を送る。書き込みの総時間の上限は 3 秒とし、部分書き込みや中断された書き込みをやり直しても期限を延ばさない。期限を超えるか書き込みに失敗したときは、接続を閉じる。応答を書きかけているときは、続きを送らずに接続を shutdown して閉じる。実行時エラーや中断の要求などの止める手順では、500 の送信も、既に始めた解放の完了の待ちも行わず、接続を shutdown して閉じる（[ランタイム](../02-impl/02-09-runtime.md)の「リソースの追跡」）。
- 【決定】`Http.Exchange` の解放の失敗は、実行時エラーにせず、報告もしない（[リソース管理](../01-spec/01-10-resources.md)の「解放の失敗」の例外）。クライアントが接続を切っても、`with` を抜けるときの解放でサーバが止まることはない。解放の失敗を調べるときは、`Http.closeExchange` を呼んで `Result` を調べる。`Http.Listener` の解放の失敗は、ほかのリソースの型と同じく実行時エラーとする。
- `Http.requestOf` は、受け付けた要求を返す。要求は受け付けた時点で読み終えているので、この関数は外部に作用する操作を行わない。【方針】解放した後（解放を始めた後を含む）の `Http.Exchange` に対する `Http.requestOf` と `Http.respond` は、実行時エラー（解放したリソースの使用）とする。処理系は、受け付けた要求の内容を `Http.Exchange` の解放のときに手放す。解放の後にも要求を使うときは、解放の前に `Http.requestOf` で値を得ておく。
- `host` は、待ち受けるアドレスか名前（`"127.0.0.1"`、`"localhost"`、`"0.0.0.0"` など）である。`port` が 0 なら、OS が空いているポートを選ぶ。選ばれたポートは `Http.listenerPort` で調べる。`port` が 0 以上 65535 以下でなければ、実行時エラーとする。
- 一つの `Http.Exchange` に `Http.respond` を二度呼ぶと、実行時エラーとする。
- 【決定】`Http.respond` は、応答の `status` が 200 以上 599 以下でなければ実行時エラー（引数の定義域の外）とする。1xx の状態コードも実行時エラーである。理由: `Http.respond` は一つの `Http.Exchange` に一度しか応答できず、1xx は最終の応答にならない（RFC 9110 §15.2、RFC 9112 §6.3）。状態コードはスクリプトが決めるもので、要求を送る相手には選べないので、止めて知らせてよい。応答の本体の有無と `content-length` は、処理系が後述の「サーバの接続と要求の読み方」の規則で決める。
- `Http.respond` は、応答を一度だけ検査して組み立てる。書き込みを待って再開したときは、組み立てた応答の続きを書き、検査と組み立てをやり直さない。
- `handler` の中で実行時エラーが起きたときは、ほかのタスクと同じく、プログラム全体を止める（[並行処理](../01-spec/01-11-concurrency.md)の「失敗と停止」）。要求の処理の失敗を応答で表すときは、`handler` が状態コード 500 などの応答を返す。
- `handler` は、`Http.serve` が起動したタスクの中で呼ぶ。そのため、`Http.serve` の呼び出しを囲む `handle` で `handler` のエフェクトを処理するときは、その操作の節を末尾で再開する節にしなければならない。そうでない節は、実行せずに実行時エラー（引き継いだハンドラの節の誤り）とする（[並行処理](../01-spec/01-11-concurrency.md)）。

【方針】`Http.serve` は、標準ライブラリのソースで、次のように書く。受け付けを繰り返し、要求ごとに `TaskGroup.spawn` でタスクを起動する。`TaskGroup.open()` は `with` の束縛の式としてだけ書ける。受け付けに失敗すると `try` で `serveLoop` を終え、`with` を抜けるときに、起動したタスクがすべて終わるのを待つ。

```text
public function serve[effect E](host: String, port: Integer, handler: function(request: Request) -> Response uses E) -> Result[Unit, NetworkError] uses Listen, State, E
  with listener = try listen(host: host, port: port) or return,
    group = TaskGroup.open() do
    return serveLoop(listener: listener, group: group, handler: handler)
  end with
end function

function serveLoop[effect E](listener: Listener, group: TaskGroup, handler: function(request: Request) -> Response uses E) -> Result[Unit, NetworkError] uses Listen, State, E
  bind exchange <- try accept(listener) or return
  bind _ <- TaskGroup.spawn(group: group, action: lambda()
    with current = exchange do
      return respond(exchange: current, response: handler(requestOf(current)))
    end with
  end lambda)
  return serveLoop(listener: listener, group: group, handler: handler)
end function
```

### サーバの接続と要求の読み方

【方針】HTTP のサーバの接続と、要求の読み方は次のとおりとする。

- 一つの接続では、一つの要求だけを受け付ける。応答を送った後か、`Http.Exchange` を解放するときに、接続を閉じる。
- 【決定】処理系が要求を拒んで返す 400・413・431 の応答は、書き終えたら送信の側だけを閉じ、要求の残りを読み捨てる。相手が送信の側を閉じるか、読み捨てた量が 1 MiB（1,048,576 バイト）を超えるか、応答を書き終えてから 2 秒に達したら、接続を閉じる。読み書きの失敗でも閉じる。この処理は `Http.accept` を呼んでいる間にだけ進み、呼ばない間は期限を過ぎても閉じない。応答を書き終えるまでの時間には上限を設けない。`Http.Exchange` の応答と解放には、この閉じ方を当てない。理由: [RFC 9112 §9.6](https://www.rfc-editor.org/rfc/rfc9112.html#section-9.6) の段階的な閉じ方に従い、拒否した要求の未読の残りによる TCP の RST で、相手が最後の応答を失う可能性を減らす。[RFC 1122 §4.2.2.13](https://www.rfc-editor.org/rfc/rfc1122.html#section-4.2.2.13) は、閉じた後に読み続けられない実装で、未読のデータを残して閉じるか、閉じた後にデータが届く場合に、RST を送ることを勧める。
- 【決定】HTTP/1.1 の要求は、`Host` のヘッダをちょうど一つ持たなければならない。`Host` がない HTTP/1.1 の要求と、版によらず `Host` が二つ以上ある要求は、HTTP として正しくない要求として扱う（状態コード 400）。`Host` の値は、英数字と `-._~!$&'()*+,;=:[]%` の文字だけからなるかを確かめ、ほかの文字を含めば同じく 400 とする。空の値は受け付ける。HTTP/1.0 の要求は `Host` を持たなくてよい。理由: RFC 9112 §3.2 は、`Host` のない HTTP/1.1 の要求と二つ以上ある要求を 400 で拒むことを求める。処理系は `Host` を使わず `handler` に渡すだけなので、区切りの文字や空白を入れさせないことに検査を絞り、RFC 3986 の厳密な解析はしない。
- 要求の対象が絶対形（`GET http://example.com/path?q=1`）のときは、scheme（`http://`・`https://`）と authority を外し、起点からのパス（`/path?q=1`）にして `path` と `query` を作る。authority の後にパスがなければ `/` とする。ただし、方法が `OPTIONS`（大文字と小文字を区別する）で、authority の後にパスもクエリの部分もなければ、`path` を `*`、`query` を空のリストとする（`OPTIONS http://example.org:8001`）。`OPTIONS http://h/`・`OPTIONS http://h?x=1`・`OPTIONS http://h?` の `path` は `/` のままである。authority が空のとき、`@`（userinfo）を含むとき、`Host` と同じ文字の集まりの外の文字を含むときは、400 とする。理由: [RFC 9112 §3.2.2](https://www.rfc-editor.org/rfc/rfc9112.html#section-3.2.2) はサーバが絶対形を受け付けることを求め、外さないと `Http.pathSegments` が対象を正しく分けられない。パスもクエリもない `OPTIONS` の絶対形は、同 §3.3 で `OPTIONS *` と同じ対象 URI を表すので、同 §3.2.4 の最後の中継による変換と同じ結果を `handler` に渡す。空の authority と userinfo は RFC 9110 §4.2.1・§4.2.4 が拒むよう求める。
- 【決定】要求の対象が `#` を含めば、形を問わず状態コード 400 の応答を返し、`handler` に渡さない。`%23` は受け付け、`path` の符号化は戻さない。理由: [RFC 9112 §3.2.1・§3.2.2](https://www.rfc-editor.org/rfc/rfc9112.html#section-3.2.1) の起点形・絶対形の文法は断片を許さず、authority 形（[§3.2.3](https://www.rfc-editor.org/rfc/rfc9112.html#section-3.2.3)）と `*` の形（[§3.2.4](https://www.rfc-editor.org/rfc/rfc9112.html#section-3.2.4)）の文法も `#` を含まない。同 §3.2 は文法に合わない要求の行を 400 か符号化した対象への 301 で拒み、黙って直して処理しないことを勧める。このため、処理系は変換前の対象を検査して 400 を返す。
- 【決定】要求の対象として、`/` で始まる起点形（`//a` を含む）、`http://`・`https://` で始まる絶対形（scheme は大文字と小文字を区別しない）、方法が `OPTIONS` のときの `*` だけの形、方法が `CONNECT` のときの authority 形を受け付ける。方法は大文字と小文字を区別し、`CONNECT` は authority 形だけを受け付ける。authority 形は最後の `:` で host と port に分け、host が空でなく `Host` と同じ文字の集まりに合い、port が 1 桁以上の ASCII の数字で、値が 0〜65535 のときに受け付ける。それ以外の形は状態コード 400 とし、`handler` に渡さない。理由: [RFC 9112 §3.2・§3.2.1〜§3.2.4](https://www.rfc-editor.org/rfc/rfc9112.html#section-3.2) が対象の形を定め、同 [§3.2.3](https://www.rfc-editor.org/rfc/rfc9112.html#section-3.2.3)・[§3.2.4](https://www.rfc-editor.org/rfc/rfc9112.html#section-3.2.4) が authority 形を `CONNECT`、`*` の形を `OPTIONS` に限り、[RFC 9110 §9.3.6](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.3.6) が `CONNECT` の対象を host と port だけに限り、空か正しくない port の拒否を求める。port 0 を受け付けるかは `handler` に委ねる。host は `Host` と同じく文字の集まりだけを確かめ、[RFC 3986 §3.2.2](https://www.rfc-editor.org/rfc/rfc3986.html#section-3.2.2) の uri-host より緩い検査とし、厳密な解析はしない。
- 【決定】変換前の要求の対象が `"`・`<`・`>` か 0x80 以上のバイトを含めば、形を問わず状態コード 400 とし、`handler` に渡さない。`[`・`]`・`\`・`^`・`` ` ``・`{`・`|`・`}` と、`%` の後が 16 進の 2 桁でない場合は、起点形と絶対形のパスとクエリで受け付ける。理由: [RFC 3986 §2〜§3.4](https://www.rfc-editor.org/rfc/rfc3986.html#section-2) の文法と [WHATWG URL Standard の符号化の集合](https://url.spec.whatwg.org/#percent-encoded-bytes) のどちらでも、拒む文字はパスとクエリに生で現れない。後者では `[` などは少なくともクエリに生で残りうるため、その文字はパスでも受け付け、`%` は後述のクエリの読み方に従う。
- 要求の本体は、`content-length` と `transfer-encoding: chunked` のどちらでも読む。どちらもなければ、本体を空とする。両方があるとき、または形が正しくないときは、HTTP として正しくない要求として扱う（後述の「失敗の種類」の、状態コード 400 の応答）。
- 要求の頭（要求の行とヘッダ）の大きさの上限を 64 KiB（65,536 バイト）、ヘッダの数の上限を 100 とする。どちらかを超えた要求には、処理系が状態コード 431 の応答を返し、`Http.accept` は失敗を返さずに次の要求を待つ。chunked の本体の後のトレーラも、頭のヘッダと同じ解析と同じ大きさと数の上限で確かめ（形が正しくなければ 400、上限を超えれば 431）、内容は捨てる。
- `Host` の誤りと形の正しくないヘッダ（二つの `content-length` など）は、本体の大きさの上限（状態コード 413）より先に判定する。
- 【決定】HTTP/1.1 の要求が `Expect: 100-continue` を持ち、本体を読む必要があり（`transfer-encoding: chunked` か、`content-length` が 0 より大きい）、頭を読んだ時点で本体のバイトをまだ受け取っていなければ、処理系は本体を読む前に `HTTP/1.1 100 Continue` を送る。100 を書き切るまで、続きを読まない。HTTP/1.0 の要求の `Expect` は無視する。理由: RFC 9110 §10.1.1 は、本体を待たずに 100 か最終の応答を送ることを求める。本体のバイトを既に受け取っていれば 100 を省いてよい。
- ヘッダの値か、パーセント符号化を戻したクエリが、正しい UTF-8 でない要求は、HTTP として正しくない要求として扱う（状態コード 400）。
- 【決定】`Http.respond` の応答の `headers` で、名前が RFC 9110 の token の文字以外を含むか、値が制御文字（水平タブを除く 0x00〜0x1F と 0x7F。CR・LF・NUL を含む）を含むときは、送る前に実行時エラー（引数の定義域の外）とする。値に許すのは、水平タブ、見える文字（0x21〜0x7E）、空白、0x80 以上のバイトである。
- 応答の区切りと接続のヘッダは処理系が決める。応答の `headers` の `content-length`・`connection`・`transfer-encoding`・`trailer`・`keep-alive`・`proxy-connection`・`te`・`upgrade` と、利用者の `connection` の値に挙げた名前のヘッダは送らず、処理系が `connection: close` と、次の表の `content-length` を付ける。名前は大文字と小文字を区別しない。`connection` が複数あればすべての値を読み、各値をカンマで区切り、各要素の前後の空白と水平タブ（OWS）を除く。空の要素は飛ばす。理由: 処理系は本体を chunked で送らないので、`transfer-encoding` を残すと `content-length` と両方を持つ応答になり、本体の区切りが壊れる（RFC 9112 §6.2・§6.3）。接続を必ず閉じ、プロトコルを切り替えないため、接続ごとのヘッダも実際と食い違うので除く（[RFC 9110 §7.6.1・§7.8](https://www.rfc-editor.org/rfc/rfc9110.html#section-7.6.1)）。
- 【決定】応答の本体と `content-length` は、要求の方法と状態コードから、次の表の上の行から順に当てて決める。本体を送らない場合に `Http.respond` に渡した空でない本体は、実行時エラーにせず捨てる。

  | 場合 | 本体 | `content-length` |
  |---|---|---|
  | `CONNECT` の要求への 2xx の応答 | 送らない | 送らない |
  | 状態コード 204・304 | 送らない | 送らない |
  | 状態コード 205 | 送らない | `0` |
  | `HEAD` の要求への応答 | 送らない | 渡した本体が空でなければその長さ、空なら送らない |
  | それ以外 | 送る | 本体の長さ |

  理由: `HEAD` への応答と 204・304 の応答は本体を持たず、`CONNECT` への 2xx の応答の後は接続がトンネルになる（RFC 9112 §6.3）。RFC 9110 は、204 と `CONNECT` への 2xx に `content-length` を送ることを禁じ（§8.6・§9.3.6）、205 に本体を送ることを禁じて長さ 0 を示す方法として `content-length: 0` を挙げる（§15.3.6）。304 の `content-length` は送ってもよいが、同じ要求への 200 の応答の本体の長さと等しくなければならず、処理系は渡された本体の長さがそれと等しいかを確かめられないので送らない（§8.6）。`CONNECT` への 2xx の規則を 205 より先に当てるのは、`CONNECT` への 2xx では `content-length` そのものを送れないからである。`HEAD` の `content-length` は、`GET` の応答の本体の長さと等しくなければ送ってはならない（§8.6）ので、本体を渡されたときだけ送る。`HEAD` と `CONNECT` は要求を送る相手が選べるので、実行時エラーにすると一つの要求でサーバを止められる。要求の方法は、大文字と小文字を区別して照合する（§9.1）。
- 処理系が返す応答の状態の行の理由の句は、RFC 9110 と RFC 6585 §3〜§5 の表に従う（431 は `Request Header Fields Too Large`）。
- 同時に保持する接続の数（閉じる途中の接続を含む）と、クライアントが要求を送り終えるまでの時間には、上限を設けない。このため、サーバをインターネットに直接さらさず、127.0.0.1 で待ち受けるか、リバースプロキシの後ろで動かす。モジュールの説明も、利用者にこの使い方を示す。

### 応答を作る関数と、要求を調べる関数

【方針】次の関数は、どれも純粋な関数である。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Http.text(status, s)` | `function(status: Integer, s: String) -> Http.Response` | 本体を `s` の UTF-8、`content-type` を `text/plain; charset=utf-8` とした応答 |
| `Http.html(status, s)` | `function(status: Integer, s: String) -> Http.Response` | 本体を `s` の UTF-8、`content-type` を `text/html; charset=utf-8` とした応答 |
| `Http.json(status, value)` | `function(status: Integer, value: Json.Value) -> Http.Response` | 本体を `Json.stringify(value)` の UTF-8、`content-type` を `application/json` とした応答 |
| `Http.pathSegments(path)` | `function(path: String) -> List[String]` | `path` を `/` で区切り、空の要素を除き、各要素のパーセント符号化を戻した並び。戻した結果が正しい UTF-8 でない要素と、`%` の後が 16 進の 2 桁でない箇所を含む要素は、要素全体を戻さずに残す |
| `Http.header(headers, name)` | `function(headers: List[Pair[String, String]], name: String) -> Option[String]` | 名前が `name` と大文字と小文字を区別せずに一致する、最初の組の値 |

経路の振り分けは組み込まず、`Http.pathSegments` の値をリストのパターンで照合して振り分ける（[代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)の「パターンの拡張（初回リリース版）」）。

```text
import Benitoite.Unofficial.Network.Http
import Benitoite.Unofficial.Json

function route(request: Http.Request) -> Http.Response
  bind segments <- Http.pathSegments(Http.Request.path(request))
  return match Pair(Http.Request.method(request), segments) with
    case Pair("GET", []) -> Http.html(status: 200, s: "<h1>Hello</h1>")
    case Pair("GET", ["items", id]) -> Http.json(status: 200, value: Json.Value.Object(Map.fromList([Pair("id", Json.Value.String(id))])))
    case otherPath -> Http.text(status: 404, s: "not found")
  end match
end function

function main() -> Result[Unit, String] uses Http.Listen, State
  return Http.serve(host: "127.0.0.1", port: 8080, handler: route) |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error))
end function
```

### クライアント

【方針】クライアントの関数は次のとおりとする。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Http.get(url)` | `function(url: String) -> Result[Http.Response, NetworkError] uses Http.Connect` | `url` に `GET` の要求を送り、応答を返す。`Http.send(Http.clientRequest(method: "GET", url: url))` と同じ |
| `Http.clientRequest(method: method, url: url)` | `function(method: String, url: String) -> Http.ClientRequest` | 後述の既定の値を入れた `Http.ClientRequest` を作る。純粋な関数である |
| `Http.send(request)` | `function(request: Http.ClientRequest) -> Result[Http.Response, NetworkError] uses Http.Connect` | 要求を送り、応答を返す |
| `Http.sendIn(request)` | `function(request: Http.RequestIn[H,P]) -> Result[Http.Response, NetworkError] uses Http.Connect[H,P]` | 保持した同じ要求を、保持した端点へ送り、3xx を含む応答を返す。リダイレクトを追わない |

【決定】`sendIn` の署名の H/P は説明のためのホストとポートの範囲であり、その組が一つの端点の範囲を表す。標準署名の内部では端点の範囲変数を一つ持ち、対象位置は第 1 引数である。対象入力の型から範囲を決め、同じ列で潜在効果を具体化する。関数値も期待する入力型や後の呼び出しから具体化し、入力型の制約が最後までなければ Top とする。戻り値から範囲を逆算しない。

【決定】要求の検査・射影・明示拡大には、次の純粋な入口を提供する。次の表の H/P と H'/P' は説明のためのホストとポートの範囲であり、それぞれの組が一つの端点の範囲を表す。利用者が宣言する型引数ではない。標準署名の内部では、検査と射影は端点の範囲変数を一つ、拡大は元と行き先の二つを持つ。

| 関数 | 型 | 振る舞い |
|---|---|---|
| `Http.checkRequestIn(hostPattern, minimumPort, maximumPort, request)` | `function(hostPattern: String, minimumPort: Integer, maximumPort: Integer, request: Http.ClientRequest) -> Result[Http.RequestIn[H,P], Http.RequestCheckError]` | `request.url` から得た実効の端点が、動的な条件と選んだ静的な範囲に属するか検査する |
| `Http.requestInValue(request)` | `function(request: Http.RequestIn[H,P]) -> Http.ClientRequest` | 検査で保持した同じ要求のレコードを返す |
| `Http.widenRequestIn(request)` | `function(request: Http.RequestIn[H,P]) -> Http.RequestIn[H',P']` | 戻りの注釈が元の範囲を覆う場合に、同じ検査済みの値を返す |

直接呼び出しの検査は、型の制約で範囲が決まらなければ、規則が選ぶ範囲へ具体化する。ホストのパターンとポートの両端がリテラルまたは const の直接参照から既知で、正しい範囲を作る場合は、その端点の範囲を選ぶ。未知の条件や逆転した閉区間では、範囲を選ぶ必須の判定は Top を選ぶ。既知の不良による本体の後の追加拒否は、下記のとおり別に行う。たとえば `checkRequestIn(hostPattern: "api.example", minimumPort: 443, maximumPort: 443, request: raw)` の成功型は、型の制約で決まらなければ `Http.RequestIn["api.example", 443]` となる。成功値を裸の `Http.RequestIn`（Top）の引数へ直接渡すなど、型の制約から Top と決まれば、検査も Top へ具体化する。未知の条件を渡した検査の成功型は裸の `Http.RequestIn`（Top）である。

射影と拡大の元の範囲は、同じ Result の保存と同じ `Result.Ok` の照合で得た局所解析の事実から選ぶ。期待する型の注釈だけで所属を得ることはなく、事実を忘れた位置には Top を要求する。明示拡大の行き先は戻りの注釈から一意に選び、元の端点の範囲を覆う場合だけ受理する。拡大は、保持した要求のレコードと実効の端点の両方を変更しない。直接呼び出し以外の扱いと忘却の境界は[型システム](../01-spec/01-06-type-system.md#範囲付きの不透明標準型)に従う。

`checkRequestIn` の直接呼び出しでは、リテラルまたは const の直接参照から既知のホストのパターンとポートの両端を、本体の後に追加検査する。パターンの形式不良は E0459、ポートの範囲外と両端の逆転は E0461 とする。未知の引数をどの値で埋めても実行時に Error となる不良だけを拒否する。要求内の URL はこの追加検査で解析せず、`requestInValue` には追加検査する条件の引数がない。型の制約の前の必須の判定が選ぶ範囲の列と理由は、この追加拒否によって変更しない。取得の範囲・予算・対象の呼び出し形は[型検査器](../02-impl/02-05-typechecker.md#本体の後の検査)に従う。

`Http.RequestCheckError` は、`InvalidUrl(message: String)` と `Scope(error: Scope.ScopeError)` の二つの構成子を持つ公開の data 型である。URL の形式不良・非対応の scheme などで host と port を取り出せない場合は `InvalidUrl`、host の形式と数値の正規形を含む端点の形式の不良は `Scope.InvalidTarget`、ホストのパターン・ポート・所属の失敗は `Scope` を通常の `Result.Error` で返す。通信は行わず、名前の解決もしない。

成功値は、渡された同じ `ClientRequest` のレコード（`method`・`url`・`headers`・`body`・`timeoutMilliseconds` の五欄）と、その `url` から得た実効の端点を保持する。クエリは `url` の一部として保つ。射影では欄を作り直さず、保持したレコードをそのまま返す。射影したレコードを更新しても元の成功値は変わらず、URL を変えた要求を検査済みとして扱うには再検査を要する。静的な範囲が Top でも、動的な条件と端点の所属を検査し、成功した場合だけ `Result.Ok` を作る。

【決定】要求の純粋な検査は、送信のための要求の妥当性検査とは分ける。検査済みの値を作る段では `url` と端点の所属を調べ、`method`・`headers`・`body`・`timeoutMilliseconds` は元の値のまま保持する。これらの欄が送信に使えるかは `Http.send`・`sendIn` の送信準備とプロトコルの検査で判断する。`sendIn` は保持した同じ五欄のレコードを読み、送信用 URI の実効 host/port と保持した端点を共通の代数で照合する。利用者指定の `Host` 欄も同じ実効 host/port を指す場合だけ受理し、不正・不一致なら送信前に `NetworkErrorKind.InvalidInput` を返す。省略時は URI から補完する。名前の大小、IPv6 の等価な表記、scheme に応じた既定ポートは、字面の等号でなく実効の端点で比べる。

【決定】`sendIn` は 3xx を追わず、環境変数の proxy に自動接続しない。対象の観測の単位は、プログラムが接続する endpoint（DNS と OS による変換前の、保持した endpoint）一つである。DNS の問い合わせと TLS の証明書の検証に伴う OS の副次的な通信は、この観測に含めない。OS は中間証明書や失効の情報を別の宛先から取得しうるため、これらの宛先は静的な端点の範囲の保証に含まれない（[セキュリティモデル](../07-quality/07-01-security-model.md#各機構が保証すること)）。名前を解決した複数のアドレスへの接続試行の回数やソケットの相手のアドレスの族も、この一対象の数え方とは別である。通信の失敗と送信準備の失敗は `NetworkError` または既存の実行時エラーであり、純粋な検査の `RequestCheckError` に混ぜない。`requestInValue` で取り出したレコードを旧 `Http.send` に渡すことはできるが、この旧入口は保持した端点を受け取らず、リダイレクトも追従する。理由: 要求の保持と、実際の通信が作用する対象の一致は、別々に確認する必要があるためである。

【決定】射影と拡大は、同じ成功値の由来を記録する `bind` の右辺の直接呼び出しとして書く。`sendIn` の節の引数は、狭い型を持っても入口でその由来を持たないため、狭い型のまま射影・拡大すると拒否する。同じ狭い型への転送、Top の引数の射影と Top への拡大は受理する（[型システム](../01-spec/01-06-type-system.md#範囲付きの不透明標準型)）。

ホストのパターンとポートの読取り・所属には、[エフェクト](../01-spec/01-07-effects.md#閉じた範囲引数)で定める範囲の共通の代数を使う。ホスト名の完全一致・一段・任意の正の段数のパターン、IP の完全一致と CIDR、ポートの閉区間を扱い、IP をホスト名へ変換しない。旧 `Scope.checkHost`・`checkEndpoint` も、同じ共通の代数で IP と CIDR を検査し、保存するパターンを正規化する。端点の範囲には scheme を含めず、ホストとポートの組だけを入れる。したがって、同じホストとポートの範囲は `http` と `https` の両方を覆い、固定した origin や通信内容の制限を表さない。

`checkRequestIn` の URL は、ASCII の絶対形式で scheme が `http` か `https`、ホストが空でないものに限る。字句には ASCII の英数字と `-._~:/?#[]@!$&'()*+,;=%` だけを許し、正しい二桁の16進数が続かない `%` と userinfo を拒否する。パスやクエリの非 ASCII の文字は、URL に渡す前にパーセント符号化する。ホスト名は範囲の代数と同じ ASCII のラベルに限る。断片（`#` 以後）は受理して元のレコードへ保持するが、端点には含めない。URL のポートを省略した場合と空にした場合は、`http` では80、`https` では443を実効のポートとする。ポートを明示した場合は ASCII の十進数字と0〜65535の範囲を検査し、不正な文字列や範囲外の値を既定のポートへ置き換えない。

URL の角括弧で囲んだ IPv6 は数値として読み、実効のホストを採択した正規形へそろえる。ただし、IPv4 射影の IPv6（`::ffff:0:0/96`）は数値で判定し、`Http.RequestCheckError.Scope` の中の `Scope.ScopeError.InvalidTarget` として拒否する。大文字、ゼロの省略、末尾の IPv4 の点の形と16進数の形のいずれでも同じ判定とする。URL から host と port を取り出せるこの場合は `InvalidUrl` にしない。IPv4 射影の範囲だけを指すパターンは受理するが、有効な対象には一致しない。IPv4 は正規形の四つの十進要素に限り、先頭0と不正な四要素を拒否する。名前として読めるホストでも、ドットで分けた全ての要素が ASCII の数字で始まり、`[0-9a-fA-FxX]` だけからなる場合は、数値風のホストとして拒否する。この判定は、省略形（`127.1` など）、整数（`2130706433` など）、十六進（`0x7f000001` など）、`0x`・`0X` だけの要素を含む形（`127.0x.0.1` など）を含む。英字で始まるラベルを含む正当なホスト名（`a0x.example` など）は、この判定では拒否しない。zone ID と IPvFuture も受理しない。URL から取り出したホストのこの不良は `Scope` の `InvalidTarget` とする。URL の元の字面は、要求のレコードの `url` にそのまま保持する。

- 【決定】`Http.send`・`sendIn` の要求の `headers` も、`Http.respond` と同じく、名前が token の文字以外を含むか値が制御文字（水平タブを除く 0x00〜0x1F と 0x7F）を含むときは、送る前に実行時エラーとする。
- `Http.clientRequest(method: method, url: url)` は、`headers` を空のリスト、`body` を空のバイト列、`timeoutMilliseconds` を 30000 にする。ほかの値にするときは、レコードの更新で変える。
- 状態コードが 4xx や 5xx の応答でも `Result.Ok` を返す。`Result.Error` は、名前を解決できない、接続できない、時間切れになるなど、応答を得られなかったときに返す。
- `timeoutMilliseconds` は、要求を送り始めてから応答の本体を読み終えるまでの時間の上限である。1 未満なら実行時エラーとする。【方針】2^40 ミリ秒を超える値は 2^40 ミリ秒（約 34.8 年）として扱う。理由: 期限は現在の時刻に上限を足して計算するので、足し算が溢れない大きさに収めるためである。約 34.8 年を超える上限は、実行の時間として区別できない。
- `url` の形式が正しくないとき、または `http` と `https` 以外の形式のときは、`NetworkErrorKind.InvalidInput` を返す。
- 【決定】要求の方法は、標準の方法（`GET`・`HEAD`・`POST`・`PUT`・`DELETE`・`CONNECT`・`OPTIONS`・`TRACE`・`PATCH`。大文字と小文字を区別する）に限る。それ以外の方法（`PURGE`、小文字の `get` など）のとき、または方法と本体の組み合わせが正しくないとき（`GET`・`HEAD`・`CONNECT` に空でない本体）は、要求を送らずに `NetworkErrorKind.InvalidInput` を返す。
- 【決定】名前を解決できないときは、OS の解決器が返す誤りの種類によらず `NetworkErrorKind.HostNotFound` を返す。解決が時間切れになったときは `NetworkErrorKind.TimedOut` を返す。
- `https` の URL では、OS のルート証明書でサーバの証明書を検証する。検証に失敗したら `Result.Error` を返す。
- 【方針】初回リリース版のクライアントは、環境変数のプロキシ（`HTTPS_PROXY`・`HTTP_PROXY`・`ALL_PROXY`・`NO_PROXY`）に従わず、接続先に直接つなぐ。
- 【方針】`https` の URL への接続（リダイレクトで `https` に移る場合を含む）では、TLS を組み立てる前に、`graviola` が要する CPU の機能があるかを確かめる。足りなければ、`NetworkErrorKind.Other` と理由の文字列の `Result.Error` を返す。確かめる機能は、`x86_64` では `aes`・`pclmulqdq`・`bmi1`・`adx`・`avx`・`avx2`、`aarch64` では `neon`・`aes`・`pmull`・`sha2` である。`http` の URL は、機能が足りない計算機でも使える。
- `Http.get`・`send` はリダイレクトの応答（3xx）を最大 10 回まで辿る。`sendIn` は追従せず、3xx の status・headers・body を返す。
- 応答の本体は `Bytes` で返すので、1 GiB を超える本体は受け取れない（[ランタイム](../02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」）。
- スクリプトが組み立てたヘッダを送れるので、Basic や Bearer の認証のトークンは `headers` に書いて送れる。初回リリース版は、認証のための仕組み（秘密を渡す受け取り口、OAuth の手順、パスキーなど）を持たない。

### 失敗の種類

`NetworkErrorKind` は `@extensible` を持ち、標準ライブラリの外の照合には[拡張可能な型](../01-spec/01-05-data-types.md#拡張可能な型)の規則を適用する。

【決定】通信で失敗しうる関数は `Result[T, NetworkError]` を返す（[エラー処理](../01-spec/01-09-errors.md)の「ネットワークの失敗の種類（初回リリース版）」）。各関数が返しうる `NetworkErrorKind` は、主に次のとおりである。`NetworkErrorKind.Other` は、どの関数も返しうる。

| `NetworkErrorKind` | 返す主な関数 |
|---|---|
| `HostNotFound` | `Http.get`・`Http.send`・`Http.sendIn`、`Http.listen`・`Http.serve`（待ち受ける名前を解決できない） |
| `ConnectionRefused` | `Http.get`・`Http.send`・`Http.sendIn` |
| `ConnectionReset` | `Http.get`・`Http.send`・`Http.sendIn`・`Http.respond` |
| `TimedOut` | `Http.get`・`Http.send`・`Http.sendIn` |
| `AddressInUse` | `Http.listen`・`Http.serve` |
| `InvalidHTTPData` | `Http.get`・`Http.send`・`Http.sendIn`（応答が HTTP として正しくない） |
| `InvalidInput` | `Http.get`・`Http.send`・`Http.sendIn`（URL の形式、標準でない方法、方法と本体の組み合わせ、`sendIn` の Host の不一致）、`Http.listen`・`Http.serve`（アドレスの形式） |
| `PermissionDenied` | `Http.listen`・`Http.serve`（OS が待ち受けを拒んだ） |

- `https` の URL で、サーバの証明書の検証に失敗したときは `NetworkErrorKind.Other` を返し、理由を `NetworkError.message` で示す。
- 受け付けた要求が HTTP として正しくないときは、`Http.accept` は失敗を返さず、処理系が状態コード 400 の応答を返して、次の要求を待つ。

【決定】`Http.accept` は、受け付けの失敗を次のように分けて扱う。

| 失敗 | 当たる場合 | `Http.accept` の扱い |
|---|---|---|
| 接続ごとの失敗 | 受け付けた接続が、要求を読み終える前に切れた、または読み取りに失敗した。受け付けのときに、OS が新しい接続に既に生じたネットワークの失敗を返した（Linux。[ランタイム](../02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」） | その接続を捨て、失敗を返さずに次の要求を待つ |
| 資源の不足 | OS が、開けるファイル記述子の数の上限（プロセスまたはシステム）、メモリやバッファの不足で、接続の受け付けを拒んだ | 失敗を返さず、時間をおいて受け付けをやり直す |
| 待ち受けの失敗 | 上の二つに当たらない失敗 | `Result.Error` を返す |

- 資源の不足でやり直すまで待つ時間は、続けて失敗した最初の回を 5 ミリ秒とし、失敗するたびに 2 倍にして、1 秒を上限とする。受け付けに成功したら、最初の値に戻す。
- 資源の不足で続けて失敗し始めたときに一度だけ、処理系は失敗の理由を標準エラー出力に一行書く。標準エラー出力のバッファに書く余地がなければ（[ランタイム](../02-impl/02-09-runtime.md)の「出力のバッファ」）、この行を捨て、受け付けを止めない。理由: この行は補助の情報であり、書けなくても受け付けの処理は正しい。
- やり直すまで待つ間も、ほかのタスクを進め、中断の要求を受け付ける（[並行処理](../01-spec/01-11-concurrency.md)）。

### 実装に使うクレート

【決定】サーバは `httparse` と `mio` の上に HTTP/1.1 の層を自作し、IO 実行器のタスクの切り替えに組み込む。クライアントは `ureq` を IO 実行器の作業用のスレッドで呼び、TLS に `rustls`、暗号の provider に `rustls-graviola`、証明書の検証に `rustls-platform-verifier` を使う（[ライブラリの構成](03-01-library-structure.md)）。`graviola` が対象としない CPU では、`https` の URL を扱えない（前述の「クライアント」の、CPU の機能の確かめ）。
