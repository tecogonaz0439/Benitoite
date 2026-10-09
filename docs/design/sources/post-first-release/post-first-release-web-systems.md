# 一般的な Web システムを動かすための言語機能の検討（初回リリース版の完成後に向けて）

- 作成: 2026-10-06
- 扱い: 検討用のメモ。初回リリース版の完成後に、設計書（01-08・01-09・01-10・01-11・03-09・02-09・ADR・OPEN）へ移す。
- 関係する検討: [パッケージ管理](post-first-release-package-management.md)、[秘密の情報の扱い](post-first-release-secrets.md)

## 目的と範囲

Node.js・Bun・Deno の上で Express・NestJS・Hono を使う構成のような、一般的な Web システム（DB を持つ REST API やサーバ側で HTML を作るアプリケーション）を Benitoite で動かすために、初回リリース版に加える必要がある言語機能とランタイムの機能を検討する。ライブラリを足せば済むものは、最後に一覧だけを示す。

他の関数型言語の Web の実装が同じ問題をどう扱っているかを調べ、案ごとに対応づけた。調べたのは、Haskell（WAI・Warp・Servant）、OCaml（Dream・Lwt・Eio）、Erlang（Cowboy）、Elixir（Plug・Bandit・Phoenix・Ecto）、Gleam（Mist・Wisp）、Scala（http4s・cats-effect・ZIO HTTP）、F#（Giraffe・ASP.NET Core）、Roc（basic-webserver）である。出典は末尾にまとめた。

## 初回リリース版の前提

- HTTP/1.1 のサーバとクライアントを標準ライブラリに持つ。サーバは TLS を扱わず、TCP・UDP・WebSocket・HTTP/2 はない（ADR 0141）。
- `Http.serve` は、受け付けた要求ごとに `TaskGroup.spawn` でタスクを起動して handler を呼ぶ。要求の本体は読み終えてから渡し（上限 16 MiB）、応答の本体は `Bytes` 一つである。一つの接続では一つの要求だけを受け付ける（03-09、ADR 0291）。
- 例外の仕組みはなく、実行時エラーは捕捉できない（ADR 0064）。どれかのタスクで実行時エラーが起きたら、すべてのタスクの `with` のリソースを解放してプログラム全体を止める（01-11「失敗と停止」）。handler の中の実行時エラーも同じである。
- 外部の関数は WASM のモジュールの関数だけとし、外に作用できるのはホストの関数（標準ライブラリの IO の操作）だけである。初回リリース版には実装しない（ADR 0139）。
- 並行処理は単一のコアで進め、ヒープは実行ごとに持つ（01-11、ADR 0015）。

## 1. 要求ごとの失敗の隔離

### 問題

一つの要求の処理で整数の溢れや 0 による除算が起きると、サーバ全体が止まり、処理中のほかの要求も失われる。同じ要求を繰り返し送るだけでサーバを止められるので、可用性の問題であると同時に、サービス妨害の入口にもなる。Node.js の構成では、Express などの枠組みが例外を受け止めて 500 を返し、サーバは動き続ける。

### 他の言語

| 言語・実装 | handler の中の想定外の失敗 | 隔離の単位 |
|---|---|---|
| Erlang（Cowboy） | 要求の処理のプロセスが異常終了すると、記録を残して 500 を返す | 要求ごとのプロセス（再利用しない）。メモリを共有しない |
| Elixir（Bandit・Plug） | 例外を受け止めて記録し、誤りの応答を返す。`Plug.ErrorHandler` は応答を作った後に例外を投げ直す | 同上 |
| Gleam（Wisp） | `rescue_crashes` の中間層が受け止め、記録して 500 を返す | 同上（Mist は接続ごとのプロセス） |
| Haskell（Warp） | 例外を受け止め、既定では 500（不正な要求には 400）を返す。`setOnException` などで変えられる | 接続ごとの軽量スレッド |
| OCaml（Dream） | 例外と拒否された promise を一つの誤りの処理に渡し、既定では記録して空の 500 を返す | 要求ごと |
| OCaml（Eio） | `accept_fork` の `on_error` が呼ばれる。記録して続けるのが典型で、止めたければ `raise` を渡す | 接続ごとの fiber |
| OCaml（Lwt 単独） | 扱われない例外は、既定ではプロセスを終える | なし |
| Scala（http4s） | `NonFatal` の例外を記録し、500 と `Connection: close` を返す | 要求ごと |
| Scala（ZIO HTTP） | サーバは誤りの型が `Response` の経路しか受け付けない。`sandbox` した誤り（defect を含む）は 500 にする | 要求ごと |
| F#（ASP.NET Core） | 応答の頭を送る前なら 500、送った後なら接続を閉じる | 要求ごと |
| Roc（basic-webserver） | `respond!` が返した `Err` は記録して 500 にする。`crash` はサーバのプロセス全体を終える | 型で表した失敗だけ要求ごと |

Roc の `crash` だけが、今の Benitoite と同じ振る舞いである。ほかの実装は、型で表さない失敗も要求の単位で受け止める。Erlang 系はプロセスがメモリを共有しないので、受け止めた後に共有の状態が壊れている心配がない。それ以外の実装は、共有の可変状態が途中まで書き換えられた状態で処理を続ける危険を、利用者に委ねている。

### ADR 0064 との関係

ADR 0064 は、実行時エラーを `Result` に変える関数（`Process.catch` の形）を設けない決定である。却下した理由は、失敗の経路が関数の型に現れないまま増え、検査で見落としやすくなることだった（原則 1）。同じ ADR の帰結は、MCP サーバで繰り返し実行するときに、一つの実行の実行時エラーがその実行だけを止めるとしている。つまり、「隔離の境界でだけ止まる範囲を限る」形は既に認めている。

要求ごとの隔離は、任意の位置で捕捉する関数ではなく、この境界をタスクの単位に広げるものとして設計できる。

### 案

- **(a) `Http.serve` だけが要求のタスクの実行時エラーを受け止める。** そのタスクとその子のタスクを止め、`with` のリソースを解放し、報告を標準エラー出力に書き、応答を送っていなければ 500 を返す。言語の表面は変わらない。
- **(b) 隔離するタスクを起動する汎用の関数を設ける。** 例えば `TaskGroup.spawnIsolated(group, f)` を設け、その `Task` を待つと `Result[T, Failure]` が得られる形にする。`Failure` は実行時エラーの種類と位置を持つ。キューの処理など HTTP 以外の常駐の処理にも使え、(a) はその上で書ける。
- **(c) 今のまま全体を止め、外部の監視（systemd の再起動など）に任せる。** 言語は変わらないが、処理中の要求を失い、上記のサービス妨害も残る。Roc の `crash` の扱いに当たる。

どの案でも、次の点を決める必要がある。

- 隔離の後に共有の状態が壊れている問題。Benitoite のタスクは `Reference` を共有できるので、Erlang のようには保証できない。対策の候補は、(i) 隔離されたタスクが書き換えうる `Reference` を型やエフェクトから推定して警告する、(ii) 「隔離は可用性のためで、共有の状態の整合は保証しない」と保証の範囲に書く、(iii) 共有の状態を DB などの外に置くことを推奨する形にとどめる（Roc の basic-webserver は「Durable mutable state belongs in SQLite or an external service」と書く）。
- 隔離してもプログラム全体を止める実行時エラーの種類。標準出力への書き込みの失敗、リソースの解放の失敗、待ち合いの行き詰まりは、要求に閉じない状態を表すので、全体を止めるままにするのが自然である。
- 隔離した失敗の報告の形（診断エンジンの報告と同じ形で、要求の方法とパスを添える）と、繰り返し起きたときに止める閾値を設けるか。
- タスクを止めるときは、取り消しと同じ手順（01-11「取り消し」）でよいか。

### 暫定の見立て

(b) を採り、`Http.serve` は (b) を使って (a) の振る舞いにする。汎用の関数は失敗の経路を型（`Result[T, Failure]`）に出すので、ADR 0064 が退けた「型に現れない失敗の経路」にはならない。共有の状態は (ii) と (iii) の組み合わせとし、保証の範囲として明記する。ADR 0064 を改める ADR が要る。

## 2. DB へ到達する手段

### 問題

典型的な Web システムは PostgreSQL・MySQL・Redis などにつなぐ。初回リリース版は TCP を持たず（ADR 0141）、外部の関数の層もない（ADR 0139）。そのため、DB のドライバを Benitoite で書くことも、既存の C や Rust のクライアントを呼ぶこともできない。ファイルの読み書きで済むのは、ファイルを DB の代わりにする小さな用途だけである。

### 他の言語

| 言語 | ソケット | PostgreSQL のドライバの作り |
|---|---|---|
| Erlang・Elixir | 標準の `gen_tcp`・`ssl` | Postgrex は `:gen_tcp.connect` の上で動き、`:ssl.connect` で同じソケットを TLS に切り替える（ソースで確認） |
| Gleam | Erlang のものを `@external` で使う | pog は Erlang の pgo の上に作る。SQLite の sqlight は C の SQLite を NIF で包む |
| Haskell | 別のパッケージ `network` | postgresql-simple は libpq（C）の束縛の上に作る。hasql は libpq の束縛の版と、純粋な Haskell の版（alpha）を持つ |
| OCaml | 標準の `Unix` | postgresql-ocaml は libpq の束縛。pgx は純粋な OCaml。Caqti は libpq の版を主とし、pgx の版を「experimental」とする |
| Scala | JVM のソケット | skunk は純粋な Scala（fs2 のソケット）。doobie は JDBC の上に作る |
| F# | .NET のソケット | Npgsql（.NET で書かれたドライバ）。接続の pool を内蔵する |
| Roc | プラットフォームが与えるものだけ | basic-webserver は SQLite の接続の pool と TCP をプラットフォームの機能として与える。PostgreSQL は README にない |

二つのことが分かる。第一に、言語自身で書いたドライバは成熟に時間がかかる（hasql の純粋な版は alpha、Caqti は pgx の版を experimental とする）。第二に、C の束縛には固有の危険がある。Erlang の文書は、NIF が落ちると処理系全体が落ちること、1 ミリ秒以内に戻るべきことを書いている。

### 案

- **(a) TCP と TLS のクライアントの接続を標準ライブラリに加える。** `Network.Tcp` に接続・読み・書き・TLS への切り替えを置き、エフェクトを `Tcp.Connect`（対象: 接続先のホストとポート）とする。ドライバは Benitoite のパッケージとして書く（Postgrex・skunk・pgx の形）。PostgreSQL の TLS は接続した後に切り替える手順なので、接続した後に TLS へ切り替える関数が要る。
- **(b) よく使う DB のクライアントを処理系に組み込む。** SQLite（Rust の `rusqlite` など）と PostgreSQL（Rust のクライアント）を、標準ライブラリか公式のモジュールとして与える。Roc の basic-webserver の形に当たる。
- **(c) WASM の外部の関数にソケットのホストの関数を与える。** 既存の Rust のドライバを WASM にビルドして使う。ADR 0139 の権限の枠組みに収まるが、ホストの関数の範囲（OPEN-051）と WASM の実行環境を先に決める必要がある。

### 暫定の見立て

SQLite を (b) で先に与える。単一のファイルで済み、スクリプトの用途と相性がよく、サーバを立てずに DB を持つ Web システムを作れる。PostgreSQL・MySQL・Redis は (a) を加えてパッケージで書く。組み込むドライバを DB ごとに増やすと、処理系が持つ依存と保守が増えるからである。(c) は OPEN-051 の検討の中で、(a) の代わりになるかを比べる。

(a) は Web システムに限らず、ADR 0141 が「初回リリース版の目標には要らない」とした TCP を加える変更なので、ADR 0141 の決定 4 を改める ADR が要る。

## 3. 接続の pool を多数の要求で共有する形

### 問題

DB の接続の pool は、サーバの起動のときに作り、すべての要求のタスクから借りて返す。Benitoite のリソースは `with` によるブロック単位の寿命を基本とする（01-10）。次の点が設計書で決まっていない。

- 外側のタスクが `with` で開いたリソースを、`Http.serve` が起動した子のタスクから使ってよいか。使うときに、同時に複数のタスクから操作することをどう扱うか。
- 借りた接続を返すことを、どの形で書くか。
- 借りたタスクが取り消されたり、1. の隔離で止まったりしたとき、接続を pool に戻すか。

### 他の言語

- **借りる操作は、関数を渡す形でブロックに閉じる。** Haskell の `withResource`、OCaml の Caqti と Lwt_pool の `use`、Dream の `Dream.sql` がこの形である。Haskell の resource-pool は `takeResource`・`putResource` という手で返す形も持つ。
- **pool 自身の寿命も、スコープかプロセスの木に結び付ける。** cats-effect の `Resource`、ZIO の `ZPool`（`Scope` の中で作る）と `ZLayer.scoped`、Eio の `Switch.run`、Elixir の Ecto（監視の木の下で起動する）がこの形である。skunk の `Session.pooled` は `Resource[F, Resource[F, Session[F]]]` を返し、外側が pool の寿命、内側が一回の借用である。
- **失敗したら、接続を pool に戻さずに捨てる。** resource-pool は、渡した処理が例外を投げたら接続を壊して戻さない。Lwt_pool は `check` で使えるかを確かめてから戻す。DBConnection は、接続を持ったまま利用者のプロセスが終わったことを pool が知り、接続の誤りとして扱う（ソースでは ETS の継承の仕組みで知る）。

### 案

pool をリソースの型とし、`with pool = Db.openPool(...)` で `Http.serve` の呼び出しを囲む。借りる操作は次のどちらかにする。

- **(a) 関数を渡す形。** `Db.use(pool, lambda(conn) ... end lambda)`。Haskell・OCaml の形である。
- **(b) 借りた接続を、リソースの型の値として `with` で束縛する形。** `with conn = Db.take(pool) do ... end with`。解放が pool への返却になる。

どちらの形でも、取り消しや隔離で止まったタスクが借りていた接続は、pool に戻さずに閉じる。プロトコルの途中で止まった接続は、状態が分からないからである。返した後の接続の使用は、既にある「解放したリソースの使用」の実行時エラーで捕まえられる。

子のタスクから外側のリソースを使う規則は、pool に限らない一般の規則として 01-10・01-11 に書く必要がある。単一のコアで進むので、データ競合は起きない。しかし、一つの接続の読み書きが二つのタスクで交互に進むと、プロトコルが壊れる。pool から借りた接続を、借りたタスクだけが使えるようにする方法（借りたタスクの外での使用を実行時エラーにする、など）を決める。

### 暫定の見立て

(b) を採る。Benitoite のリソースの書き方（`with`）に揃い、関数を渡す形を新たに覚えさせずに済む（原則 5）。必要な言語の変更は、子のタスクからのリソースの使用の規則と、借りたタスクの外での使用の検査である。【要検証】今の仕様で、外側の `with` のリソースを子のタスクが使えるか、使えるならどう振る舞うかを、01-10・01-11 と実装で確かめる。

## 4. 流しながら読み書きする本体

### 問題

今の API では、要求の本体を読み終えてから handler に渡し、応答の本体を `Bytes` 一つで返す。次のものが書けない。

- 大きなファイルの受け取りと配信
- Server-Sent Events と、LLM の応答のように少しずつ生まれる結果を流す API
- WebSocket

### 他の言語

| 実装 | 応答を流す形 | 要求を流す形 |
|---|---|---|
| Cowboy | `stream_reply` の後に `stream_body` を `nofin`・`fin` で繰り返す | `read_body` が大きいときは `more` を返し、続きを読む |
| Plug | `send_chunked` の後に `chunk` を繰り返す | `read_body` の `:length` で一回の量を限り、`{:more, ...}` を返す |
| Mist | 反復子を chunked で送る。SSE と WebSocket の専用の関数がある | 要求するまで本体をソケットから読まない |
| WAI | `responseStream` に、断片を送る関数と flush の関数を受け取るコールバックを渡す。資源の確保は `responseStream` の外で bracket を使うよう文書が勧める | `getRequestBodyChunk` が次の断片を返し、尽きたら空を返す |
| Dream | `Dream.stream` のコールバックに流れを渡し、コールバックが戻るか例外を投げたら自動で閉じる。`write` は相手が次を受け取れるまで待つ | `body_stream` で少しずつ読む |
| http4s | 本体は `fs2.Stream[F, Byte]` であり、流れを返すと chunked で送る | 同じく流れ |
| ZIO HTTP | `Body.fromStream`（長さが既知）と `Body.fromStreamChunked` | 流れ |
| Roc | 応答は全体を持つ値だけ。SSE は専用の型付きの形で与える | 上限付きの流れとして読める |

流れを言語の値（http4s の `fs2.Stream`、ZIO の `ZStream`）として持つ実装と、リソースに対する読み書きの関数とコールバックで表す実装（Cowboy・Plug・WAI・Dream）に分かれる。後者は、流れの型を持たない言語でも書ける。

### 案

- **(a) リソースに対する読み書きの関数を加える。** 要求の側は `Http.readBodyChunk(exchange) -> Result[Option[Bytes], NetworkError]` とする。応答の側は `Http.startResponse(exchange, status, headers)` で `Http.ResponseWriter`（リソースの型）を得て、`Http.write`・`Http.flush` を繰り返し、解放で終える。SSE・WebSocket は、この上の関数として加える。
- **(b) 遅延して生まれる値の列の型を、言語か標準ライブラリに加える。** http4s・ZIO の形である。合成しやすいが、取り消し・リソース・エフェクトとの関係を新たに定める必要があり、変更が大きい。

### 暫定の見立て

(a) を採る。新しい言語機能は要らず、`with` と取り消しの既存の規則でリソースを解放できる（Dream の「コールバックを抜けたら閉じる」と同じ性質を、`with` で得る）。初回の回答では「言語とランタイムに加える必要がある」としたが、調べた結果、HTTP の API とランタイムの変更で足りると判断した。ただし、次の変更があわせて要る。

- 要求の本体を読み終えてから handler を呼ぶ今の形を、読まずに渡す形に改める（ADR 0291）。上限 16 MiB の適用の場所も改める。
- 送る速さを相手に合わせる（Dream の `write` のように、相手が受け取れるまで待つ）。
- 接続が切れたときに、書き込みの失敗を `Result` で返し、handler が後始末できるようにする。

(b) は、流れを合成する用途（ファイルを読みながら変換して送る、など）が増えてから検討する。

## 5. JSON とレコードの間の変換を自動で作る仕組み

### 問題

今の `Json.Value` から自前のレコードへの変換は、手で書くしかない。REST API では、要求の本体を検証してレコードにし、レコードを JSON にして返す処理が、ほぼすべての経路に現れる。手書きの変換は量が多く、LLM が書くとフィールドの名前の綴りや、`Option` の扱いを誤りやすい。

### 他の言語

| 言語 | 仕組み | 言語機能の種類 |
|---|---|---|
| Haskell（aeson） | `Generic` を導出し、空のインスタンスを書くと既定の実装が生成される。Template Haskell の `deriveJSON` もある | 型の構造の汎用の表現（Generics）と、コンパイル時のメタプログラミング |
| OCaml | `[@@deriving yojson]`（ppx_deriving_yojson・ppx_yojson_conv） | 構文木を変換する前処理器（ppx） |
| Scala | Scala 3 の `derives JsonCodec`（zio-json）。circe の `deriveDecoder`・`deriveEncoder` | 型の構造の表現（Mirror）とマクロ |
| Elixir | `@derive {Jason.Encoder, only: [...]}`（protocol の導出。符号化だけ）。受け取る側は Ecto の changeset で、受け付けるフィールドを明示して変換・検証する | protocol の導出 |
| Roc | 型に `encoder_for : _` と `parser_for : _` を書くと既定の実装を使う | 処理系による導出 |
| F#（Thoth.Json） | `Decode.Auto.generateDecoder<User>()` | 実行時の型の情報（【要検証】反射によるかは一次資料で未確認） |
| Gleam | 導出はない。復号器は手で組み合わせて書く。言語サーバのコードアクションが、型から変換の関数のコードを生成する（v1.9.0 で JSON への変換を加えた） | 道具によるコードの生成 |
| Erlang | OTP 27 の `json` は値の変換だけで、レコードへの対応はない | なし |

### 案

- **(a) 処理系が、決まった型クラスのインスタンスを導出する。** `@derive(Json.Encode, Json.Decode)` のような属性を、レコードと代数的データ型に付ける。Haskell の stock deriving や Roc に近い。処理系が `Json` のモジュールを知る必要がある。
- **(b) 処理系は型の構造の汎用の表現だけを導出し、変換はライブラリが書く。** Haskell の `Generic`、Scala 3 の `Mirror` の形である。処理系は `Json` を知らずに済むが、型システムに型の構造を表す型（積と和の型レベルの表現）が要り、言語の中核の変更が大きい。
- **(c) 道具がコードを生成する。** `benitoite` のサブコマンドか言語サーバのコードアクションで、型から変換の関数のコードを生成し、ソースに置く。Gleam の形である。言語は変わらず、生成したコードを人と LLM が読んで直せる。

(c) には、型を変えた後に生成し直すのを忘れる危険がある。復号の関数はレコードを作るので、フィールドを加えると型の誤りになって気付ける（原則 2）。一方、符号化の関数は加えたフィールドを黙って落とす。生成したコードに印を付け、型と食い違ったら `check` が警告する形にすれば、この危険を減らせる。

### 暫定の見立て

標準ライブラリとの疎結合の方針（初回リリース版では、処理系が標準ライブラリの関数を特別扱いする密結合を最小限にする）から、(a) は避ける。先に (c) を道具として加え、型と生成したコードの食い違いを `check` で検出する。(b) は型システムの学習の題材としても価値があるので、型クラスの扱い（ADR 0059）とあわせて後で検討する。属性でフィールドの名前の対応（`snake_case` など）を指定する仕組みは、(b) か (c) のどちらを採るかで形が変わるので、その時点で決める。

## 6. 複数のコアの利用

### 他の言語

- BEAM（Erlang・Elixir・Gleam）は、既定で論理プロセッサの数だけスケジューラを持つ。プロセスはメモリを共有しない。
- GHC は `-threaded` と `+RTS -N` で軽量スレッドを複数の OS のスレッドで並列に進める。Warp はこの上で動く。
- cats-effect は、コアごとに作業の列を持つ work-stealing の pool で fiber を進める。
- OCaml 5 の domain は OS のスレッドと 1 対 1 に対応する重い単位である。Eio の `run_server` は、`additional_domains` を渡すと domain ごとに受け付けのループを動かし、handler が触れる値がスレッド安全であることを利用者に求める。Dream は Lwt の上で動き、Lwt は既定で単一のスレッドで進める。
- Roc の basic-webserver は Rust の Hyper と Tokio の上で動き、同時に動く handler の数の既定を 32 とする。【要検証】複数の OS のスレッドで並列に進むか。

### 案と暫定の見立て

ヒープは実行ごとに持つ（ADR 0015）ので、一つのプロセスの中で、コアの数だけ実行（ヒープ）を作り、各実行が同じ待ち受けで受け付ける形がとりやすい。実行の間ではメモリを共有しないので、BEAM のプロセスと同じく、実行をまたいで共有の状態が壊れる心配がない。共有の状態は 2. の DB に置く。それまでは、プロセスを複数起動してリバースプロキシで振り分ける運用で足りる。ランタイムの変更なので、初回リリース版の後の性能の段階で扱う。

## 7. ライブラリで足りるもの

- ルーティングと中間層。Express・Hono の形は、`function(Http.Request) -> Http.Response uses E` を包む高階関数で書ける。要求ごとの文脈（認証した利用者など）はレコードで渡す。中間層ごとにフィールドを足していく書き方が要るなら、拡張可能なレコード（行多相）が欲しくなるが、まず要望を待つ。
- 暗号。HMAC、JWT の署名と検証、パスワードのハッシュ（argon2 など）、暗号論的な乱数、定数時間の比較。今の `Hash` は SHA-256 だけである。
- Cookie、セッション、CORS、HTML のテンプレート、接続の再利用（keep-alive）、HTTP/2、WebSocket（4. の (a) が前提）。
- 正常な終了（ADR 0163 の SIGTERM による解放がある）、定期的な処理（タスクと `Clock.sleep`）、設定（`Process.environmentVariable`）、要求ごとの時間切れ（`Task.withTimeout`）は、今の機能で書ける。

NestJS のデコレータと DI コンテナ、クラス、async/await と Promise に当たるものは要らない。モジュールと高階関数、直接形式のエフェクトとタスクで同じことを書ける。足すと同じ役割の構文が増える（原則 5）。

## 優先の順序（暫定）

1. 要求ごとの失敗の隔離（1.）。ないとサーバとして運用できない。
2. SQLite の組み込み（2. の (b)）と、接続の pool の規則（3.）。
3. 流しながら読み書きする本体と keep-alive（4.）。
4. JSON の変換の生成（5. の (c)）。
5. TCP と TLS のクライアント（2. の (a)）と、PostgreSQL などのドライバのパッケージ。パッケージ管理（[パッケージ管理](post-first-release-package-management.md)）の後になる。
6. 複数のコア（6.）。

DB の接続の文字列やパスワードの受け取り方は、[秘密の情報の扱い](post-first-release-secrets.md)の検討に従う。

## 残っていること

- 1. の隔離の対象から外す実行時エラーの種類、`Failure` の型の中身、繰り返し起きたときに止める閾値。
- 1. の共有の状態の扱いを、保証の範囲（07-01）にどう書くか。
- 3. の、子のタスクから外側のリソースを使う規則と、借りたタスクの外での使用の検査の方法。【要検証】今の仕様と実装での振る舞い。
- 4. の、流しながら読む形に改めるときの、本体の上限と 413 の応答の扱い。
- 5. の (b) を採るかと、フィールドの名前の対応の指定の方法。
- 【要検証】次の点は、一次資料で確かめられなかった。
  - Warp が、要求の処理の途中で相手が接続を切ったときに handler のスレッドを止めるか。
  - Dream と Lwt が、流している途中で接続が切れたときにリソースをどう扱うか。
  - Thoth.Json の自動の変換が反射によるか。
  - BEAM の reduction による横取りの細部（erlang.org の文書で確かめられなかった）。
  - Roc の basic-webserver の handler が複数のスレッドで並列に進むか。
  - Roc で外部の関数を呼べるのがプラットフォームだけであること（現在の公式の文書の頁で確かめられなかった）。

## 設計書に移すときの候補

- ADR: 隔離するタスクを起動する関数を設け、`Http.serve` が要求ごとに使う（ADR 0064 と 01-11「失敗と停止」を改める）。
- ADR: SQLite を処理系に組み込み、TCP と TLS のクライアントを標準ライブラリに加える（ADR 0141 の決定 4 を改める）。
- ADR: 子のタスクからのリソースの使用の規則と、接続の pool の形。
- ADR: 流しながら読み書きする HTTP の API（ADR 0291 を改める）。
- ADR: JSON の変換のコードを生成する道具。
- OPEN: 型の構造の汎用の表現（5. の (b)）、複数のコア（6.）。

## 出典（2026-10-06 に確認）

取得の道具は頁の内容を要約して返すことがあるので、設計書に引用するときは原文の文言を改めて確かめる。

- Erlang・Elixir・Gleam
  - Cowboy の処理の流れ: https://raw.githubusercontent.com/ninenines/cowboy/master/doc/src/guide/flow_diagram.asciidoc
  - Cowboy の要求のプロセスの終了で 500 を返す処理: https://raw.githubusercontent.com/ninenines/cowboy/master/src/cowboy_stream_h.erl
  - Cowboy の応答と要求の本体: https://raw.githubusercontent.com/ninenines/cowboy/master/doc/src/guide/resp.asciidoc 、https://raw.githubusercontent.com/ninenines/cowboy/master/doc/src/guide/req_body.asciidoc
  - OTP の設計の原則: https://www.erlang.org/doc/system/design_principles.html
  - `gen_tcp`: https://www.erlang.org/doc/apps/kernel/gen_tcp.html
  - NIF: https://www.erlang.org/doc/system/nif.html 、https://www.erlang.org/doc/apps/erts/erl_nif.html
  - `json`（OTP 27）: https://www.erlang.org/doc/apps/stdlib/json.html
  - `erl` の `+S`: https://www.erlang.org/doc/apps/erts/erl_cmd.html
  - Plug.ErrorHandler: https://plug.hexdocs.pm/Plug.ErrorHandler.html
  - Plug.Conn（`send_chunked`・`chunk`・`read_body`）: https://plug.hexdocs.pm/Plug.Conn.html
  - Bandit の例外の処理: https://raw.githubusercontent.com/mtrudel/bandit/main/lib/bandit/pipeline.ex
  - Phoenix の誤りの頁: https://phoenix.hexdocs.pm/custom_error_pages.html
  - Elixir の監視と「let it crash」: https://elixir.hexdocs.pm/1.18/supervisor-and-application.html
  - Postgrex: https://postgrex.hexdocs.pm/readme.html 、https://github.com/elixir-ecto/postgrex/blob/master/lib/postgrex/protocol.ex
  - Ecto.Repo: https://ecto.hexdocs.pm/Ecto.Repo.html
  - Ecto.Changeset: https://ecto.hexdocs.pm/Ecto.Changeset.html
  - DBConnection: https://db-connection.hexdocs.pm/DBConnection.html 、https://db-connection.hexdocs.pm/DBConnection.Ownership.html
  - DBConnection の利用者の終了の検出: https://raw.githubusercontent.com/elixir-ecto/db_connection/master/lib/db_connection/holder.ex 、https://raw.githubusercontent.com/elixir-ecto/db_connection/master/lib/db_connection/connection_pool.ex
  - Jason.Encoder: https://jason.hexdocs.pm/Jason.Encoder.html
  - Wisp: https://raw.githubusercontent.com/gleam-wisp/wisp/main/src/wisp.gleam 、https://wisp.hexdocs.pm/wisp.html
  - glisten: https://glisten.hexdocs.pm/
  - Mist: https://mist.hexdocs.pm/mist.html
  - pog: https://pog.hexdocs.pm/
  - pgo: https://github.com/erleans/pgo
  - sqlight: https://sqlight.hexdocs.pm/
  - Gleam の外部の関数: https://tour.gleam.run/advanced-features/externals/
  - Gleam の復号器: https://gleam-stdlib.hexdocs.pm/gleam/dynamic/decode.html
  - Gleam v1.9.0 の告知: https://gleam.run/news/hello-echo-hello-git/
- Haskell・OCaml
  - Warp: https://hackage.haskell.org/package/warp-3.4.16/docs/Network-Wai-Handler-Warp.html
  - Warp の設計（作者による解説）: https://aosabook.org/en/posa/warp.html
  - WAI: https://hackage.haskell.org/package/wai-3.2.5/docs/Network-Wai.html
  - servant-server: https://hackage.haskell.org/package/servant-server/docs/Servant-Server.html
  - Servant の流す例: https://docs.servant.dev/en/latest/cookbook/basic-streaming/Streaming.html
  - postgresql-libpq: https://hackage.haskell.org/package/postgresql-libpq
  - postgresql-simple: https://hackage.haskell.org/package/postgresql-simple
  - hasql: https://hackage.haskell.org/package/hasql
  - network: https://hackage.haskell.org/package/network
  - resource-pool: https://hackage.haskell.org/package/resource-pool-0.5.1.0/docs/Data-Pool.html
  - Control.Exception（`bracket`）: https://hackage.haskell.org/package/base/docs/Control-Exception.html
  - aeson: https://hackage.haskell.org/package/aeson/docs/Data-Aeson.html 、https://hackage.haskell.org/package/aeson/docs/Data-Aeson-TH.html
  - GHC の並行と並列: https://downloads.haskell.org/ghc/latest/docs/users_guide/using-concurrent.html
  - Dream: https://github.com/camlworks/dream/blob/master/src/dream.mli
  - Dream の SSE の例: https://github.com/camlworks/dream/tree/master/example/w-server-sent-events
  - Lwt: https://github.com/ocsigen/lwt/blob/master/src/core/lwt.mli 、https://github.com/ocsigen/lwt/blob/master/src/core/lwt_pool.mli 、https://github.com/ocsigen/lwt
  - Eio: https://github.com/ocaml-multicore/eio 、https://github.com/ocaml-multicore/eio/blob/main/lib_eio/net.mli
  - postgresql-ocaml: https://github.com/mmottl/postgresql-ocaml
  - pgx: https://github.com/pgx-ocaml/pgx
  - Caqti: https://github.com/paurkedal/ocaml-caqti 、https://github.com/paurkedal/ocaml-caqti/blob/master/caqti/lib/pool.mli
  - OCaml の `Unix`: https://ocaml.org/manual/5.3/api/Unix.html
  - OCaml の並列: https://ocaml.org/manual/5.3/parallelism.html
  - ppx_deriving_yojson: https://github.com/ocaml-ppx/ppx_deriving_yojson
  - ppx_yojson_conv: https://github.com/janestreet/ppx_yojson_conv
- Scala・F#・Roc
  - http4s の既定の誤りの処理: https://github.com/http4s/http4s/blob/series/0.23/server/shared/src/main/scala/org/http4s/server/package.scala
  - http4s の流れ: https://http4s.org/v0.23/docs/streaming.html
  - ZIO HTTP: https://ziohttp.com/reference/routing/routes 、https://ziohttp.com/reference/handler 、https://ziohttp.com/reference/body
  - skunk: https://typelevel.org/skunk/ 、https://github.com/typelevel/skunk/blob/main/modules/core/shared/src/main/scala/Session.scala
  - doobie: https://typelevel.org/doobie/
  - cats-effect の Resource: https://typelevel.org/cats-effect/docs/std/resource
  - cats-effect のスレッドの模型: https://typelevel.org/cats-effect/docs/thread-model
  - ZIO: https://zio.dev/reference/resource/zpool/ 、https://zio.dev/reference/di/dependency-memoization 、https://zio.dev/reference/contextual/zlayer/ 、https://zio.dev/reference/fiber/
  - zio-json: https://zio.dev/zio-json/
  - circe の半自動の導出: https://circe.io/circe/codecs/semiauto-derivation.html
  - Giraffe: https://github.com/giraffe-fsharp/Giraffe/blob/master/DOCUMENTATION.md
  - ASP.NET Core の誤りの処理: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling
  - Kestrel: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel
  - Npgsql: https://www.npgsql.org/doc/basic-usage.html
  - Thoth.Json: https://thoth-org.github.io/Thoth.Json/
  - Roc の basic-webserver: https://github.com/roc-lang/basic-webserver
  - Roc の FAQ: https://www.roc-lang.org/faq
  - Roc の符号化と復号の例: https://roc-lang.org/examples/EncodeDecode/README.html
