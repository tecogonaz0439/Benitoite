# L32 HTTP のクライアント

- 依存する作業: [L30](L30-http-server.md)、[R40](R40-event-loop-and-worker-threads.md)
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行。テストを含む）
- ブランチ: impl/L32-http-client

## 目的

HTTP のクライアントの操作 `Http.send` の本体を、`ureq` を作業用のスレッドで呼んで書く（ADR 0143 の決定 2）。10-15 の部分 45（`http_client::DECLS`）である。L00 が置いたソースの関数 `Http.get`・`Http.clientRequest` を確かめる。`https` の URL のために、TLS に `rustls`、暗号の provider に `rustls-graviola`、証明書の検証に `rustls-platform-verifier` を組み立てる。テスト用のハンドラ表のネットワークの失敗（10-16）を `Http.send` に当てる。

| 項目 | 権限 |
|---|---|
| `Http.send` | `Io` |
| `Http.get`・`Http.clientRequest`（ソース） | — |

依存の理由: `NetworkError` の値と、ループバックの通信で相手にするサーバは L30 が作る。作業用のスレッドの仕事は R26 の送り出しの列と R40 の作業用のスレッドの上で動く。

## 読む設計書の節

- [ネットワークのモジュール](../../2026-10-09-design-first-release/03-interop/03-09-network.md)の「クライアント」（既定の値、4xx・5xx の扱い、`timeoutMilliseconds`、URL の形、証明書の検証、リダイレクト）、「要求と応答の型」（受け取った応答のヘッダの名前）、「失敗の種類」、「実装に使うクレート」
- [ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」、「一つの操作で作る値の大きさの上限」（応答の本体）
- [処理系のテスト戦略](../../2026-10-09-design-first-release/07-quality/07-03-compiler-testing.md)の「HTTP のテスト（初回リリース版）」
- [未決・要検証事項](../../2026-10-09-design-first-release/open-issues.md#open-062)の OPEN-062 の R14
- ADR: [0143](../../2026-10-09-design-first-release/decisions/0143-http-and-tls-crates.md)、[0142](../../2026-10-09-design-first-release/decisions/0142-http-api-shape.md)、[0222](../../2026-10-09-design-first-release/decisions/0222-http-tests-over-loopback.md)、[0287](../../2026-10-09-design-first-release/decisions/0287-stdlib-details-decided-in-u3-plan.md) の決定 3・4、[0322](../../2026-10-09-design-first-release/decisions/0322-stdlib-details-from-u3-preflight.md) の決定 3、[0330](../../2026-10-09-design-first-release/decisions/0330-http-details-from-u3-preflight.md) の決定 2〜4

インターフェース:

- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「使うクレート」（`ureq`・`rustls`・`rustls-graviola`・`graviola`・`rustls-platform-verifier` と【要検証】の二つ）、「テスト用のハンドラ表のネットワークの失敗」、「ランタイムの内部への口」、「作業用のスレッドで行う操作」（プロキシを使わない設定と CPU の機能の確かめの箇条を含む）、「本物の部品とイベントループを使うテストの口」（`RuntimeParts::real_with_poll`。L30 が加える）
- ループバックの統合テストは、L30 のサーバの準備の待ちにイベントループが要るので、`RunEnv::parts` に `RuntimeParts::real_with_poll(NetworkFaults::default())` で作った部品を渡して実行する（失敗を当てるときは `NetworkFaults { … }` に欄を入れる）。
- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「ネットワーク」の表と `Network/Http.bnt`、「レコードの値の作り方」

## 作るもの

- `src/builtins/funcs/http_client.rs` の `Http.send` の本体と単体テスト
- `ureq` の `Agent` の組み立て（TLS の設定を含む）の非公開の関数
- 10-16 の表のクレートの依存と、`deny.toml` の要るライセンスの追加
- スクリプトの統合テスト

## 手順の要点

- 始める前に、10-16 の【要検証】の二つ（`ureq` に `rustls-graviola` の provider と `rustls-platform-verifier` を渡せるか、`graviola` が三つのビルド先でビルドできるか）を確かめる。ビルド先は、`aarch64-apple-darwin`・`x86_64-unknown-linux-musl`・`aarch64-unknown-linux-musl`（[配布形態](../../2026-10-09-design-first-release/05-platform/05-01-distribution.md)と ADR 0176 で確かめた初回リリース版の対応環境）とし、`cargo build --target` で確かめる。作業の環境には musl のビルド先の部品がなく、作業の中では加えられない。musl の二つは「確かめられなかった」と完了の報告に書けばよく、そのために作業を止めない。ビルドできたビルド先で成り立たなければ、作業を止めて報告する（README の「U3・U4 で決めたこと」の 3）。
- 依存のクレート（`ureq` 3.4.2、`graviola` が要する `getrandom` 0.3.4 など、推移的な依存を含む 108 個）は、オーケストレータが `cargo fetch` で取得済みである。取得されていないクレートが要ると分かったら、作業を止めて報告する。
- `deny.toml` に、ADR 0138 の決定 3 の許可の一覧のうち、`ISC`（`rustls-webpki`・`untrusted`）と `BSD-3-Clause`（`subtle`）を加える。`Unicode-3.0`（`unicode-ident`）は、下の `[graph]` の節を加えた後の `cargo deny check licenses` で要ると出たときだけ加える。加えたら、`cargo deny check licenses` でほかに足りないものがないことを確かめる。
- `rustls-platform-verifier` は、ビルド先が `wasm32` のときだけ `webpki-root-certs`（`CDLA-Permissive-2.0`。ADR 0138 の許可の一覧にない）に依存する。`cargo deny` が対応環境でないビルド先の依存まで調べないように、`deny.toml` に次の `[graph]` の節を加え、調べるビルド先を対応環境の三つに絞る。`CDLA-Permissive-2.0` を許可の一覧に加えない。

  ```toml
  [graph]
  targets = ["aarch64-apple-darwin", "x86_64-unknown-linux-musl", "aarch64-unknown-linux-musl"]
  ```
- `Http.send(request)`: `ClientRequest` の欄を宣言の順で読み、Rust の値に変える（10-15「レコードの値の作り方」）。`timeoutMilliseconds` が 1 未満なら実行時エラー（`ArgumentOutOfDomain`）。URL の形が正しくないか、`http`・`https` 以外の形式なら `InvalidInput` の `Result.Error`（作業用のスレッドへ仕事を出さない）。
- 失敗の注入: URL の host に `NetworkFaults::lookup` の失敗があれば、仕事を出さずにその種類の `Result.Error` を返す（10-16）。
- 仕事: `ureq` の `Agent` を、プロキシを使わない設定（`ConfigBuilder::proxy(None)`。`ureq` 3.4.2 の `Config` の既定の値は `Proxy::try_from_env()` で `ALL_PROXY`・`HTTPS_PROXY`・`HTTP_PROXY`・`NO_PROXY`（小文字の名前を含む）を読むので、明示して外す。03-09「クライアント」、ADR 0330 の決定 2）、リダイレクトを最大 10 回、4xx・5xx を誤りにしない設定（`http_status_as_error(false)`）、時間の上限を `timeoutMilliseconds`（送り始めてから本体を読み終えるまで）で作って送る。応答の本体を上限（2^30 バイト）より 1 バイト多い分まで読み、超えたら資源の不足（`InputTooLarge`）。`ureq` 3 の本体の読み出しは既定で 10 MB を上限とする（超えると誤りになる）ので、reader で読んで自前で数える。上限の判定は、任意の `std::io::Read` と上限を受け取り、上限 + 1 バイトまで読んで、超えたら資源の不足、超えなければ読んだバイト列を返す非公開の関数に分け、`Http.send` はこの関数で本体を読む（下の受け入れテストの「応答の本体の上限」で、この関数を単体テストする）。
- 要求の `headers`: 名前が RFC 9110 の token の文字以外を含むか、値が制御文字（水平タブを除く 0x00〜0x1F と 0x7F。CR・LF・NUL を含む）を含むときは、送る前に実行時エラー（`ArgumentOutOfDomain`。function は DECL の name、argument は要求の引数の位置）とする（ADR 0331、[ADR 0333](../../2026-10-09-design-first-release/decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md) の決定 3、03-09「クライアント」）。値の水平タブ、見える文字、空白、0x80 以上のバイトは許す。
- 要求の方法: 標準の方法（`GET`・`HEAD`・`POST`・`PUT`・`DELETE`・`CONNECT`・`OPTIONS`・`TRACE`・`PATCH`。大文字と小文字を区別する）でないとき、または `GET`・`HEAD`・`CONNECT` に空でない本体を付けたときは、送らずに `InvalidInput` の `Result.Error` とする（[ADR 0333](../../2026-10-09-design-first-release/decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md) の決定 3）。単体テストを置く。
- 応答: `Http.Response` のレコード（`status`、名前を小文字にそろえた `headers`、`body`）。`headers` は、`ureq` 3 の応答の `http::HeaderMap` を反復した順（名前ごとにまとめた順。同じ名前の値どうしは受け取った順）に並べてよい（03-09「要求と応答の型」、ADR 0322 の決定 3）。名前が交互に来た順を取り戻す処理は書かない。ヘッダの値が UTF-8 かは、`std::str::from_utf8(value.as_bytes())` で確かめる（`http::HeaderValue::to_str()` は見える ASCII 以外のバイトを誤りにするので、UTF-8 の非 ASCII の値まで拒んでしまう）。ヘッダの値が UTF-8 でない応答は、設計書が扱いを定めていない（OPEN-062 の R14）ので、10-16「実装プランで決める値」の考え方（新しい規則を作らず既存の規則に寄せる）に従い、HTTP として正しくない応答として `InvalidHTTPData` を返す。再現テストは L33 が書く。
- 誤りの種類: `ureq` の誤りを 03-09「失敗の種類」の表の種類に分ける（名前の解決 → `HostNotFound`（`ureq` の既定の解決器が `Io` で返す失敗も包んで寄せる。[ADR 0333](../../2026-10-09-design-first-release/decisions/0333-fmt-refusal-test-json-notes-http-method-and-process-input.md) の決定 3）、接続の拒否 → `ConnectionRefused`、接続のリセット → `ConnectionReset`、時間切れ → `TimedOut`、応答の形の誤り → `InvalidHTTPData`、証明書の検証の失敗とそのほか → `Other`）。分け方は `ureq::Error` の選択肢と、その中の `std::io::ErrorKind` で決め、表を `///` のコメントに書く。
- TLS: `rustls` の `CryptoProvider` を `rustls-graviola` から作り、`ureq` の `TlsConfig` に provider と `RootCerts::PlatformVerifier` を与える。`webpki-roots` を依存に入れない（`cargo tree` で確かめる）。
- CPU の機能の確かめ（03-09「クライアント」、ADR 0330 の決定 3）: `graviola` 0.4.1 は、公開の関数の入口ごとに `verify_cpu_features` を呼び、要する機能が足りなければ `assert!` で panic する（`src/low/entry.rs`）。要する機能は、`x86_64` では `aes`・`pclmulqdq`・`bmi1`・`adx`・`avx`・`avx2`（`src/low/x86_64/cpu.rs`）、`aarch64` では `neon`・`aes`・`pmull`・`sha2`（`src/low/aarch64/cpu.rs`）である。`graviola` は確かめる関数を公開していない（`pub(crate)`）ので、処理系が `std::arch::is_x86_feature_detected!`・`std::arch::is_aarch64_feature_detected!` で同じ機能を確かめる。`https` の URL では、TLS を組み立てる前（作業用のスレッドへ仕事を出す前）に確かめ、足りなければ `NetworkErrorKind.Other` と理由の文字列（足りない機能の名前を含める。文は `text` に置く）の `Result.Error` を返す。`http` の URL からリダイレクトで `https` に移る場合に備え、機能が足りない計算機では、TLS の接続器を含まない接続器の連なり（`Agent::with_parts` に `ureq::unversioned::transport::TcpConnector` だけを渡し、解決器は `DefaultResolver`）で `Agent` を作る。このとき `ureq` は `https` への接続で `Error::TlsRequired` を返すので、同じ種類と理由に分ける。機能があるかの判定は、足りない機能の一覧を返す関数（CPU を調べる部分）と、その一覧から誤りを作るか TLS を組み立てるかを決める関数に分け、後者に「足りない」一覧を与えて、`Result.Error`（`Other`）になる分岐を単体テストで確かめる。
- `Http.get` と `Http.clientRequest` はソースの関数であり、変えずに確かめる。
- スクリプトのテストでは、非公式のモジュールを取り込みの名前で取り込む（`import Benitoite.Unofficial.Network.Http`。[ADR 0286](../../2026-10-09-design-first-release/decisions/0286-unofficial-modules-imported-under-unofficial.md) の決定 3）。03-09 の例の `import Benitoite.Network.Http` の形をそのまま写すと、E0321 になる。

## 受け入れテスト

- 単体テスト: URL の形の誤り（`"not a url"`・`"ftp://x"`）で `InvalidInput`。`timeoutMilliseconds` が 0 で実行時エラー。失敗の注入の四つの種類。CPU の機能が足りないときの分岐（上の「CPU の機能の確かめ」）で `NetworkErrorKind.Other` の `Result.Error` になる。
- ループバックの統合テスト（L30 のサーバをスクリプトの中で動かし、同じスクリプトから `Http.get`・`Http.send` で接続する。ADR 0222）: 200 と 404 と 500 の応答を `Result.Ok` で受け取る。ヘッダの名前が小文字になる。サーバが `x-a: 1`、`x-b: 2`、`x-a: 3` の順で返した応答の `headers` で、`x-a` の二つの値が `1`・`3` の順に隣り合って並び、`x-b: 2` もある（名前どうしの順は `HeaderMap` の反復の順に任せ、期待に固定しない。観測した順を完了の報告に書く）。`POST` の本体が届く。リダイレクト（サーバが 302 を返す）を 10 回まで辿る。11 回目のリダイレクトは、03-09 が「最大 10 回まで辿る」とだけ定めるので、`ureq` の既定（`max_redirects` が 10、`max_redirects_will_error` が `true`。`src/config.rs` の `Default`）のままにする。この既定では、11 回目の 3xx で `ureq` が `Error::TooManyRedirects` を返し（`src/run.rs`）、上の誤りの分け方では `NetworkErrorKind.Other` の `Result.Error` になる。テストでこの振る舞いを確かめる。時間切れ（`TimedOut`）: `timeoutMilliseconds` を 100 程度にする。`ureq` の時間の上限（`timeout_global`）は実時間で数えるので、このテストに限り、実時間の短い待ちを許す（ADR 0330 の決定 4。実時間の待ちに頼らない方針の例外）。サーバの側は `Clock.sleep` で応答を遅らせず、待ち受けを開くだけで要求を受け付けず（`Http.accept` を呼ばず）、クライアントのタスクの結果を待ってから（たとえば、`TaskGroup.spawn` で起動したクライアントのタスクを `Task.await` で待ってから）待ち受けを閉じる。時間切れが要求を送り終える前に起きても止まらないようにするためである（[ADR 0335](../../2026-10-09-design-first-release/decisions/0335-http-timeout-test-server-does-not-accept.md)）。閉じたポートへの接続で `ConnectionRefused`。
- 応答の本体の上限: 上限を超える本体の応答で資源の不足になることを、上限を小さくできないので、読み取りの上限の判定を通る経路（上の「仕事」の、任意の `Read` と上限を受け取る非公開の関数の単体テスト。小さな上限を与え、上限ちょうどの入力は読めて、上限 + 1 バイトの入力は資源の不足になる）で確かめる。
- `https`: 処理系のテストでは確かめない（07-03、ADR 0287 の決定 4）。公開の `https` の URL への手動の接続は、取り込みの前にオーケストレータが行う。本作業は、ビルドが通ることと、手動の接続に使える形（`https` の URL を `Http.get` で読むスクリプト）を完了の報告に書く。
- `webpki-roots` と `ring`・`aws-lc-rs` が依存に入っていない（`cargo tree -i` の結果を完了の報告に書く）。

## 完了条件

- `scripts/check.sh`（`cargo deny check licenses` を含む）が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置、L00 が置いたソースを変えていない
- クレートの版と機能、【要検証】の二つの結果（確かめられなかったビルド先を含む）、`deny.toml` に加えたライセンスと `[graph]` の節、`ureq` の誤りの分け方、UTF-8 でないヘッダの扱い、11 回目のリダイレクトの振る舞い、プロキシを外した設定と CPU の機能の確かめの書き方を完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。とくに、作業用のスレッドに言語の値を渡していないか、本体の大きさを値を作る前に確かめているか。
- TLS の組み立てが ADR 0143 のとおりか（provider、OS のルート証明書、`webpki-roots` を使わない）。
- テストがループバックのアドレスにだけ接続しているか（07-03「HTTP のテスト（初回リリース版）」）。

## 難易度の理由

`ureq` と TLS のクレートの組み合わせに【要検証】の点があり、誤りの種類の分け方、時間の上限、リダイレクト、本体の上限をクレートの振る舞いに合わせて確かめる必要がある。
