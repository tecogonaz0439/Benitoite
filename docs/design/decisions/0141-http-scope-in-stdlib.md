# 0141. 標準ライブラリに、TLS のない HTTP サーバと、HTTPS を含む HTTP クライアントを入れ、TCP は入れない

- 状態: 採択
- 日付: 2026-09-28
- 関連章: [ネットワークのモジュール](../03-interop/03-09-network.md), [ライブラリの構成](../03-interop/03-01-library-structure.md), [並行処理](../01-spec/01-11-concurrency.md), [ロードマップ](../00-overview/00-03-roadmap.md), [他の言語の調査記録](../08-appendix/08-03-language-surveys.md)
- 関連する未決事項: [OPEN-045](../open-issues.md#open-045)

## 背景

初回リリース版で、スクリプトから簡易な HTTP サーバ（HTML を返す、REST API を提供する）を動かせるようにする（[ADR 0115](0115-structured-io-concurrency.md)、[ロードマップ](../00-overview/00-03-roadmap.md)）。標準ライブラリの `Network` のモジュールの範囲は、HTTP のクライアントとサーバとし、細部を [OPEN-045](../open-issues.md#open-045) に残していた（[ADR 0137](0137-first-release-library-scope.md)）。

他の言語の調べた結果は[他の言語の調査記録](../08-appendix/08-03-language-surveys.md)の「標準ライブラリの HTTP」に記録した。要点は次のとおりである。

- Go・Python・Java・Dart・Erlang/OTP は、HTTP のサーバとクライアントを標準ライブラリに持ち、クライアントは HTTPS を扱える。Ruby は 3.0 で WEBrick（サーバ）を外し、クライアントの `Net::HTTP` を残した。
- Python の `http.server` は「not recommended for production」、Java の `SimpleFileServer` は「intended for testing, development and debugging purposes only」と、文書に書かれている。
- Gleam・Haskell・OCaml・Rust は、HTTP をパッケージに任せる。

## 決定

1. `Benitoite.Network.Http`（[ADR 0140](0140-network-separated-from-local-io.md)）に、HTTP/1.1 のサーバとクライアントを入れる。
2. サーバは TLS を扱わない。手元の機械の中や、TLS を終端するリバースプロキシの後ろで動かす使い方を対象とする。
3. クライアントは、`http` と `https` の URL を扱う。
4. TCP と UDP の待ち受けと接続、WebSocket、HTTP/2 は、初回リリース版に入れない。

## 検討した代替案

- **サーバだけを入れ、クライアントは外部コマンド（`curl` など）に任せる**: TLS の実装を処理系に持たずに済む。しかし、REST API を呼ぶことはスクリプトのよくある用途であり、外部コマンドに任せると、応答を文字列から解析する手間と、コマンドの有無への依存が生じる。コマンドの中の通信は、処理系の権限制御の外にもなる。
- **TCP の待ち受けと接続も入れる**: HTTP 以外のプロトコルも扱える。しかし、初回リリース版の目標（簡易な HTTP サーバ）には要らず、API と権限の範囲が広がる。
- **サーバも TLS を扱う**: 単独で公開できる。しかし、証明書の管理まで標準ライブラリで扱うことになる。対象とする使い方では、TLS の終端はリバースプロキシに任せられる。

## 帰結

- `Network` の範囲についての [OPEN-045](../open-issues.md#open-045) の論点のうち、標準ライブラリに入れる範囲が決まる。権限の宣言の書き方は OPEN-045 に残す。
- クライアントのために TLS の実装が要る。使うクレートは [ADR 0143](0143-http-and-tls-crates.md) で定める。
- API の形は [ADR 0142](0142-http-api-shape.md) で定める。
