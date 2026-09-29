# 0143. HTTP のサーバは httparse と mio の上に自作し、クライアントは ureq と rustls を使い、暗号は graviola を第一候補とする

- 状態: 採択
- 日付: 2026-09-28
- 関連章: [ライブラリの構成](../03-interop/03-01-library-structure.md), [ネットワークのモジュール](../03-interop/03-09-network.md), [ランタイム](../02-impl/02-09-runtime.md), [配布形態](../05-platform/05-01-distribution.md), [他の言語の調査記録](../08-appendix/08-03-language-surveys.md)
- 関連する未決事項: [OPEN-045](../open-issues.md#open-045)

## 背景

標準ライブラリに、TLS のない HTTP/1.1 のサーバと、HTTPS を含む HTTP/1.1 のクライアントを入れる（[ADR 0141](0141-http-scope-in-stdlib.md)）。HTTP と TLS のクレートは、HTTP の範囲とあわせて決めることにしていた（[ADR 0138](0138-crates-and-licenses-for-stdlib.md) の決定 5）。

処理系は、一つの実行を一つのスレッドで進め、IO の完了を待つタスクがあればほかのタスクを進める（[ADR 0015](0015-shared-program-per-execution-state.md)、[ADR 0115](0115-structured-io-concurrency.md)）。言語の値はスレッドの間で受け渡せない（[ADR 0078](0078-reference-counting-in-minimal.md)）。

crates.io の登録情報と各リポジトリ（2026-09-28）を調べた結果は、[他の言語の調査記録](../08-appendix/08-03-language-surveys.md)の「HTTP と TLS のクレート」に記録した。要点は次のとおりである。

- `hyper`（1.11.1）は `tokio` に必ず依存する。`tiny_http`（0.12.0）は 2022 年から版を出していない。`httparse`（1.10.1）は依存のない HTTP の解析器であり、入出力を持たない。
- `ureq`（3.4.2）は同期の API のクライアントで、非同期の実行環境を要しない。既定の機能は、暗号に `ring`、ルート証明書に `webpki-roots`（CDLA-Permissive-2.0）を使う。
- 本番に使える TLS の暗号の実装のうち、`ring` と `aws-lc-rs` はビルドに C コンパイラを要する。`aws-lc-rs` が依存する `aws-lc-sys` は AWS-LC の C のソースを同梱し、ライセンスの表示に ISC・Apache-2.0・MIT・BSD-3-Clause を要する。rustls の README は、`aws-lc-rs` を推奨し、`ring` は耐量子の鍵交換を持たないと書く。
- `graviola`（0.4.1）は、README に「no C compiler, assembler or other tooling needed: just the Rust compiler」と書き、形式検証済みの s2n-bignum のアセンブリを Rust の中に取り込む。x86_64 と aarch64 の、特定の CPU の機能を持つものだけを対象とし、「This project is very new, so exercise due caution.」と書く。rustls の README は、第三者の provider として `rustls-graviola` を挙げる。
- `rustls-platform-verifier`（0.7.1）は、OS の証明書の検証を使う。`webpki-root-certs` に依存するのは wasm32 を対象とするときだけである。

## 決定

1. HTTP/1.1 のサーバは、`httparse` で要求を解析し、`mio` で接続の待ち受けと読み書きを行う層を自作する。この層は IO 実行器のタスクの切り替えに組み込む。
2. HTTP のクライアントには `ureq` を使い、IO 実行器が作業用のスレッドで呼ぶ。既定の機能を切り、`rustls-no-provider` と `platform-verifier` の機能を使う。
3. TLS には `rustls` を使う。暗号の provider は `rustls-graviola` を第一候補とする。対象の環境で使えないことや、不具合が分かったときは、`aws-lc-rs` に替える。
4. ルート証明書は `rustls-platform-verifier` で OS のものを使い、`webpki-roots` と `webpki-root-certs` は使わない。

   | 用途 | クレート | リポジトリ | ライセンス |
   |---|---|---|---|
   | HTTP の解析 | `httparse` | https://github.com/seanmonstar/httparse | MIT OR Apache-2.0 |
   | 接続の待ち受けと読み書き | `mio` | https://github.com/tokio-rs/mio | MIT |
   | HTTP のクライアント | `ureq` | https://github.com/algesten/ureq | MIT OR Apache-2.0 |
   | TLS | `rustls` | https://github.com/rustls/rustls | Apache-2.0 OR ISC OR MIT |
   | TLS の暗号 | `rustls-graviola`・`graviola` | https://github.com/ctz/graviola | Apache-2.0 OR ISC OR MIT-0 |
   | ルート証明書の検証 | `rustls-platform-verifier` | https://github.com/rustls/rustls-platform-verifier | MIT OR Apache-2.0 |

5. 許可するライセンスの一覧（ADR 0138 の決定 3）は変えない。MIT-0 は OR の選択肢の一つなので、Apache-2.0 か ISC を選ぶ。

## 検討した代替案

- **サーバに `hyper` を使う**: 広く使われている。しかし、`tokio` が依存に入り、処理系のタスクの切り替えと別の実行環境を抱えることになる。
- **サーバに `tiny_http` を使う**: 同期の API で組み込みやすい。しかし、2022 年から版を出しておらず、TLS の機能は古い rustls に依存する。
- **暗号に `aws-lc-rs` を使う（rustls の既定で、推奨）**: 機能と性能は最もそろっている。しかし、ビルドに C コンパイラ（Windows では NASM か同梱のオブジェクトも）を要し、開発と CI の環境の整備が増える。代わりの案として残す。
- **暗号に `ring` を使う**: ライセンスの表示は 2 種類で済む。しかし、ビルドに C コンパイラを要し、耐量子の鍵交換を持たない。
- **`native-tls` を使う**: macOS と Windows では OS の TLS を使い、C コンパイラを要しない。しかし、Linux ではシステムの OpenSSL を要し、一つのバイナリで配れなくなる。
- **`rustls-rustcrypto` を使う**: Rust だけで書かれている。しかし、alpha 版で、README に「DO NOT USE IN PRODUCTION」と書かれている。
- **クライアントを自作する**: 依存が減る。しかし、HTTP のクライアントは言語の中核でも処理系の主要部でもないので、既存の OSS を使う区分に当たる。サーバの層を自作するのは、既存のクレートが処理系のタスクの切り替えに合わないためであり、解析は `httparse` に任せる。

## 帰結

- 使うクレートは、どれも C のコードを含まず、ビルドに Rust のツールチェーンだけを要する（ADR 0138 の帰結が保たれる）。
- `graviola` が対象としない CPU（x86_64 の一部の古いもの、Raspberry Pi 4 以前などの aarch64、ほかのアーキテクチャ）では、HTTPS のクライアントを使えない。HTTP のサーバと、`http` の URL のクライアントは使える。対象の環境で HTTPS を使えないときの振る舞いは、実装プランで定める。
- `ureq` に `rustls-graviola` の provider を与える API（`unversioned_rustls_crypto_provider`）は、名前のとおり版をまたいだ安定を約束していない。組み合わせて動くかは【要検証】である。
- `aws-lc-rs` に替えるときは、ビルドに C コンパイラが要るようになり、配布物のライセンスの表示に MIT と BSD-3-Clause が加わる。
