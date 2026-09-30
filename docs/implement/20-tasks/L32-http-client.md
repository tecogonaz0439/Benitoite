# L32 HTTP のクライアント

- 依存する作業: [L30](L30-http-server.md)、[R26](R26-dispatch-queue-and-io-executor.md)
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行。テストを含む）
- ブランチ: impl/L32-http-client

## 目的

HTTP のクライアントの操作 `Http.send` の本体を、`ureq` を作業用のスレッドで呼んで書く（ADR 0143 の決定 2）。10-15 の部分 45（`http_client::DECLS`）である。L00 が置いたソースの関数 `Http.get`・`Http.clientRequest` を確かめる。`https` の URL のために、TLS に `rustls`、暗号の provider に `rustls-graviola`、証明書の検証に `rustls-platform-verifier` を組み立てる。テスト用のハンドラ表のネットワークの失敗（10-16）を `Http.send` に当てる。

| 項目 | 権限 |
|---|---|
| `Http.send` | `Io` |
| `Http.get`・`Http.clientRequest`（ソース） | — |

依存の理由: `NetworkError` の値と、ループバックの通信で相手にするサーバは L30 が作る。作業用のスレッドの仕事は R26 の上で動く。

## 読む設計書の節

- [ネットワークのモジュール](../../design/03-interop/03-09-network.md)の「クライアント」（既定の値、4xx・5xx の扱い、`timeoutMilliseconds`、URL の形、証明書の検証、リダイレクト）、「要求と応答の型」（受け取った応答のヘッダの名前）、「失敗の種類」、「実装に使うクレート」
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」、「一つの操作で作る値の大きさの上限」（応答の本体）
- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「HTTP のテスト（初回リリース版）」
- [未決・要検証事項](../../design/open-issues.md#open-062)の OPEN-062 の R14
- ADR: [0143](../../design/decisions/0143-http-and-tls-crates.md)、[0142](../../design/decisions/0142-http-api-shape.md)、[0222](../../design/decisions/0222-http-tests-over-loopback.md)、[0287](../../design/decisions/0287-stdlib-details-decided-in-u3-plan.md) の決定 3・4

インターフェース:

- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「使うクレート」（`ureq`・`rustls`・`rustls-graviola`・`graviola`・`rustls-platform-verifier` と【要検証】の二つ）、「テスト用のハンドラ表のネットワークの失敗」、「ランタイムの内部への口」、「作業用のスレッドで行う操作」
- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「ネットワーク」の表と `Network/Http.bnt`、「レコードの値の作り方」

## 作るもの

- `src/builtins/funcs/http_client.rs` の `Http.send` の本体と単体テスト
- `ureq` の `Agent` の組み立て（TLS の設定を含む）の非公開の関数
- 10-16 の表のクレートの依存と、`deny.toml` の要るライセンスの追加
- スクリプトの統合テスト

## 手順の要点

- 始める前に、10-16 の【要検証】の二つ（`ureq` に `rustls-graviola` の provider と `rustls-platform-verifier` を渡せるか、`graviola` が三つのビルド先でビルドできるか）を確かめる。ビルド先は、`aarch64-apple-darwin`・`x86_64-unknown-linux-musl`・`aarch64-unknown-linux-musl`（[配布形態](../../design/05-platform/05-01-distribution.md)と ADR 0176 で確かめる）とし、`cargo build --target` で確かめる。ツールチェーンの部品がなくて確かめられないビルド先は、確かめられなかったことを書く。どちらかが成り立たなければ、作業を止めて報告する（README の「U3・U4 で決めたこと」の 3）。
- `Http.send(request)`: `ClientRequest` の欄を宣言の順で読み、Rust の値に変える（10-15「レコードの値の作り方」）。`timeoutMilliseconds` が 1 未満なら実行時エラー（`ArgumentOutOfDomain`）。URL の形が正しくないか、`http`・`https` 以外の形式なら `InvalidInput` の `Result.Error`（作業用のスレッドへ仕事を出さない）。
- 失敗の注入: URL の host に `NetworkFaults::lookup` の失敗があれば、仕事を出さずにその種類の `Result.Error` を返す（10-16）。
- 仕事: `ureq` の `Agent` を、リダイレクトを最大 10 回、4xx・5xx を誤りにしない設定（`http_status_as_error(false)`）、時間の上限を `timeoutMilliseconds`（送り始めてから本体を読み終えるまで）で作って送る。応答の本体を上限（2^30 バイト）より 1 バイト多い分まで読み、超えたら資源の不足（`InputTooLarge`）。
- 応答: `Http.Response` のレコード（`status`、名前を小文字にそろえ受け取った順に並べた `headers`、`body`）。ヘッダの値が UTF-8 でない応答は、設計書が扱いを定めていない（OPEN-062 の R14）ので、10-16「実装プランで決める値」の考え方（新しい規則を作らず既存の規則に寄せる）に従い、HTTP として正しくない応答として `InvalidHTTPData` を返す。再現テストは L33 が書く。
- 誤りの種類: `ureq` の誤りを 03-09「失敗の種類」の表の種類に分ける（名前の解決 → `HostNotFound`、接続の拒否 → `ConnectionRefused`、接続のリセット → `ConnectionReset`、時間切れ → `TimedOut`、応答の形の誤り → `InvalidHTTPData`、証明書の検証の失敗とそのほか → `Other`）。分け方は `ureq::Error` の選択肢と、その中の `std::io::ErrorKind` で決め、表を `///` のコメントに書く。
- TLS: `rustls` の `CryptoProvider` を `rustls-graviola` から作り、`ureq` の `TlsConfig` に provider と `RootCerts::PlatformVerifier` を与える。`webpki-roots` を依存に入れない（`cargo tree` で確かめる）。
- `Http.get` と `Http.clientRequest` はソースの関数であり、変えずに確かめる。

## 受け入れテスト

- 単体テスト: URL の形の誤り（`"not a url"`・`"ftp://x"`）で `InvalidInput`。`timeoutMilliseconds` が 0 で実行時エラー。失敗の注入の四つの種類。
- ループバックの統合テスト（L30 のサーバをスクリプトの中で動かし、同じスクリプトから `Http.get`・`Http.send` で接続する。ADR 0222）: 200 と 404 と 500 の応答を `Result.Ok` で受け取る。ヘッダの名前が小文字になる。`POST` の本体が届く。リダイレクト（サーバが 302 を返す）を 10 回まで辿る。11 回目のリダイレクトの扱い（`Result.Error` にするか、3xx の応答を返すか）は 03-09 が定めていないので、`ureq` の設定（`max_redirects_will_error`）の既定のままにし、テストで振る舞いを確かめて完了の報告に書く。サーバが応答を遅らせたときの時間切れ（`TimedOut`）。閉じたポートへの接続で `ConnectionRefused`。
- 応答の本体の上限: 上限を超える本体の応答で資源の不足になることを、上限を小さくできないので、読み取りの上限の判定を通る経路（本体を読む関数の単体テスト）で確かめる。
- `https`: 処理系のテストでは確かめない（07-03、ADR 0287 の決定 4）。上の【要検証】の確かめで、公開の `https` の URL へ手動で一度接続した結果を完了の報告に書く。
- `webpki-roots` と `ring`・`aws-lc-rs` が依存に入っていない（`cargo tree -i` の結果を完了の報告に書く）。

## 完了条件

- `scripts/check.sh`（`cargo deny check licenses` を含む）が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置、L00 が置いたソースを変えていない
- クレートの版と機能、【要検証】の二つの結果、`ureq` の誤りの分け方、UTF-8 でないヘッダの扱いを完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。とくに、作業用のスレッドに言語の値を渡していないか、本体の大きさを値を作る前に確かめているか。
- TLS の組み立てが ADR 0143 のとおりか（provider、OS のルート証明書、`webpki-roots` を使わない）。
- テストがループバックのアドレスにだけ接続しているか（07-03「HTTP のテスト（初回リリース版）」）。

## 難易度の理由

`ureq` と TLS のクレートの組み合わせに【要検証】の点があり、誤りの種類の分け方、時間の上限、リダイレクト、本体の上限をクレートの振る舞いに合わせて確かめる必要がある。
