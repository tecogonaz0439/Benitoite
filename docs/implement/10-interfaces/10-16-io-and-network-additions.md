# IO とネットワークの追加

本章は、U3 の IO とネットワークの組み込みの関数が使うランタイムの口と、U3 が使う Rust のクレートを定める。組み込みの関数の表と標準ライブラリのソースは[標準ライブラリの追加](10-15-stdlib-additions.md)で定める。本章は、[値とヒープ](10-08-values-and-heap.md)・[スケジューラと IO 実行器](10-10-scheduler-and-io.md)・[組み込みの関数の型付きの形](10-11-builtin-interface.md)・[パイプラインと CLI](10-13-pipeline-and-cli.md) の型を広げる。設計書の対応する章は、[ランタイム](../../design/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」「IO 実行器」「リソースの追跡」、[IO のモジュール](../../design/03-interop/03-07-io-modules.md)、[ネットワークのモジュール](../../design/03-interop/03-09-network.md)、[処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「HTTP のテスト（初回リリース版）」である。

- 置く作業: L00

コードブロックの見出しの読み方は [README](../README.md) の「インターフェースの読み方」に従う。`append=` の見出しは、10-10・10-11 が C01・C02 で置いたファイルの項目に、本章のコードを書き足す。パスは処理系のクレート `crates/benitoite/` からの相対パスである。

## 広げるものの一覧

U2 の型は、U3 の関数を持たない段階で凍結した。U3 の関数のうち、次のものは U2 の口だけでは書けないので、本章で口を加える。

| 足りないもの | 使う関数 | 本章で加えるもの |
|---|---|---|
| 組み込みの関数から、リソースの表の OS の資源と、実行ごとの状態を VM のスレッドで読む口。`IoServices` は、リソースを表に加える `register_resource` だけを持つ | `Http.listenerPort`・`accept`・`respond`（VM のスレッドとイベントループで行う。02-09「組み込みの操作とハンドラ表」の表）、ネットワークの失敗の注入、`Process.runAttached` | `IoServices::runtime_view`（既定は `None`） |
| `Pure`・`State` の文脈からリソースの表を読む口 | `Http.requestOf`（10-15「項目の種類と権限」） | `StateServices::resource_table`（既定は `None`）と、リソースの表の添え物 `ResourceTable::attachments` |
| テスト用のハンドラ表のネットワークの失敗（ADR 0287 の決定 3） | `Http.send`・`Http.get`・`Http.listen`・`Http.serve` | `RuntimeParts::network_faults` と `NetworkFaults` |
| `Process.runAttached` の標準入出力のつなぎ先 | `Process.runAttached` | `IoRuntime::process_stdio` と `ProcessStdio` |
| `mio` の型を持つ HTTP のサーバの接続の層の置き場所 | HTTP のサーバ | モジュール `runtime::io::http` |
| F17 が呼ぶ正規表現の組み立ての関数（README の「U3・U4 で決めたこと」の 9） | F17 | `builtins::regex_check::check_regex_source` |

隠れた乱数の生成器の状態の型は、10-10 の `IoRuntime::random_state` を `[u64; 4]` に改めた（本章の「隠れた乱数の生成器」）。リソースの種類（`ResourceKind::FileWriter`・`HttpListener`・`HttpExchange`）と、その解放がブロックするかの分岐（R24）、`NetworkError` の対象（10-08 の `FieldsKind::NetworkError`）、`Random.Generator`・`Regex.Pattern`・`Regex.Match` の値（`ObjKind::Opaque`）、`Clock.now`・`Clock.localOffsetMinutes`・`Random.Generate` の口（`IoServices` の `now_millis`・`local_offset_minutes`・`random_u64`）は、U2 の章に既にある。

加えるのはどれも、既定の実装を持つトレイトの関数、既定の値を持つ構造体の欄、新しい型と関数である。既存の関数のシグネチャは変えない。構造体の欄を加えると、その構造体をすべての欄を書いて作っている箇所がコンパイルできなくなるので、L00 がその箇所に既定の値を加える（後述の「置き方と既存の構築の箇所」）。

## 使うクレート

U3 が加えるクレートは、[ADR 0138](../../design/decisions/0138-crates-and-licenses-for-stdlib.md) と [ADR 0143](../../design/decisions/0143-http-and-tls-crates.md) が名指ししたものに限る（00-02「依存するクレート」）。次の版・ライセンス・`rust-version`・機能は、2026-09-30 に `cargo info` と、crates.io から取得した配布物の `Cargo.toml` で確かめた。`rust-version` はどれも Rust 1.98.1 以下である。

| クレート | 版 | ライセンス | `rust-version` | 使い方（`Cargo.toml` の指定） | 加える作業 |
|---|---|---|---|---|---|
| `regex` | 1.13.1 | MIT OR Apache-2.0 | 1.65 | 既定の機能（`std`・`perf`・`unicode`）のまま | L22 |
| `serde_json` | 1.0.151 | MIT OR Apache-2.0 | 1.71 | 既定の機能（`std`）のまま。`serde_json::Value` で読み書きし、`serde` の derive は使わない | L21 |
| `csv-core` | 0.1.13 | Unlicense/MIT（`cargo info` の表示。`Unlicense OR MIT` の古い書き方） | 記載なし | 既定の機能のまま | L23 |
| `jiff` | 0.2.37 | Unlicense OR MIT | 1.70 | `default-features = false`、`features = ["std", "tz-system", "tzdb-zoneinfo"]`。タイムゾーンのデータを同梱する機能（`tzdb-bundle-platform`・`tzdb-bundle-always`）を入れない（03-01「使う Rust のクレート」） | L24（`Clock.localOffsetMinutes` のために L10 が先に加えるなら L10） |
| `base64` | 0.23.1 | MIT OR Apache-2.0 | 1.71 | `default-features = false`、`features = ["std"]` | L25 |
| `sha2` | 0.11.0 | MIT OR Apache-2.0 | 1.85 | `default-features = false`（既定の `oid` を使わない）、`features = ["alloc"]` | L25 |
| `getrandom` | 0.4.3 | MIT OR Apache-2.0 | 1.85 | 既定の機能のまま。`getrandom::u64()` で種を得る | L14 |
| `httparse` | 1.10.1 | MIT OR Apache-2.0 | 記載なし | 既定の機能（`std`）のまま | L30 |
| `mio` | 1.2.3 | MIT | 1.71 | R26 が加えた指定に、機能 `net` を加える（00-02「依存するクレート」） | L30 |
| `ureq` | 3.4.2 | MIT OR Apache-2.0 | 1.85 | `default-features = false`、`features = ["rustls-no-provider", "platform-verifier"]`（ADR 0143 の決定 2）。既定の `gzip` と、`ring`・`webpki-roots` を入れない | L32 |
| `rustls` | 0.23.45 | Apache-2.0 OR ISC OR MIT | 1.71 | `default-features = false`、`features = ["std", "tls12"]`。`aws_lc_rs`・`ring` の機能を入れない。crates.io の最新は 0.24.0-dev.1 だが、開発中の版であり、`ureq` 3.4.2・`rustls-graviola` 0.4.0・`rustls-platform-verifier` 0.7.1 はどれも 0.23 の系列を要求する | L32 |
| `rustls-graviola` | 0.4.0 | Apache-2.0 OR ISC OR MIT-0 | 1.85 | 既定の機能のまま。`rustls` 0.23.18 以上を要求する | L32 |
| `graviola` | 0.4.1 | Apache-2.0 OR ISC OR MIT-0 | 1.89 | `rustls-graviola` を通して入る。直接は書かない | L32 |
| `rustls-platform-verifier` | 0.7.1 | MIT OR Apache-2.0 | 1.85 | `ureq` の機能 `platform-verifier` を通して入る（`ureq` は 0.7.0 以上を要求する）。直接は書かない | L32 |

- クレートを加える作業は、加えるときに `cargo deny check licenses` で確かめ、ADR 0138 の決定 3 の許可の一覧のうち実際に要るものだけを `deny.toml` に加える（00-02「依存するクレート」）。推移的な依存のライセンスは、上の表では確かめていない。許可の一覧にないライセンスの依存が入ったら、作業を止めて報告する。
- `graviola` と `rustls-graviola` の MIT-0 は許可の一覧にないので、Apache-2.0 か ISC を選ぶ（ADR 0143 の決定 5）。`csv-core` の `Unlicense/MIT` を `cargo deny` が `Unlicense OR MIT` として読むかは【要検証】であり、L23 が確かめる。読めなければ、`deny.toml` の `clarify` で `Unlicense OR MIT` と明示する。
- 作業の時点で、上の版より新しい同じ系列（`regex` 1.x、`rustls` 0.23.x など）の版があれば、その版の文書で機能の名前が変わっていないことを確かめて使い、版を完了の報告に書く（00-02 の `mio` と同じ扱い）。系列が変わる版（`rustls` 0.24、`sha2` 0.12 など）は使わない。
- `ureq` 3.4.2 の `TlsConfig` は、暗号の provider を `rustls` の `CryptoProvider` で与える口（`unversioned_rustls_crypto_provider`）と、OS のルート証明書を使う指定（`RootCerts::PlatformVerifier`。機能 `platform-verifier`）を持つことを、配布物の `src/tls/mod.rs`・`src/tls/rustls.rs` で確かめた。ただし、次の三つは確かめていない。

| 【要検証】の点 | 確かめる作業 | 確かめられないとき |
|---|---|---|
| `ureq` に `rustls-graviola` の provider と `rustls-platform-verifier` の検証を一緒に渡し、`https` の URL に接続できるか | L32（ビルドと、公開の `https` の URL への手動の接続。処理系のテストには入れない。ADR 0287 の決定 4） | 作業を始める前に設計者に報告する（README の「U3・U4 で決めたこと」の 3）。ADR 0143 の決定 3 は、`aws-lc-rs` に替える道を残している |
| `graviola` が三つのビルド先（特に `x86_64-unknown-linux-musl`）でビルドでき、`https` の接続に使えるか。配布物の `src/low/` は `x86_64` と `aarch64` の実装だけを持つ | L32（`cargo build --target` で確かめる。リリースのビルドは D31） | 同上 |
| タイムゾーンのデータを同梱しない `jiff`（`tz-system`・`tzdb-zoneinfo`）で、OS の時差（`/etc/localtime` と `TZ`）を得られるか | L10 | 同上。得られない環境では 0 を返す（ADR 0287 の決定 1）ので、得られないこと自体は誤りではない。確かめるのは、得られる環境（macOS と、タイムゾーンのデータを持つ Linux）で得られることである |

## ランタイムの内部への口

`IoServices` に、実行ごとの状態のうちランタイムが持つもの（10-10 の `IoRuntime`）と、リソースの表（`ResourceTable`）を借りる関数を加える。第 2 段の `IoServices` の実装である `IoView`（10-10）は、この二つを既に持つので、同じ形の値を借り直して返す。

```rust append=src/builtins/iface.rs::IoServices
    /// 実行ごとの状態のうちランタイムが持つものと、リソースの表を借りる（実装プラン 10-16「ランタイムの内部への口」）。
    /// 第 2 段の `IoView` だけが `Some` を返す。第 1 段の一時的な実装、参照インタプリタ、テスト用の実装は既定の
    /// `None` のままとし、これを要る組み込みの関数は `None` のとき `Stop::Internal` を返す。
    fn runtime_view(&mut self) -> Option<crate::runtime::io::services::IoView<'_>> {
        None
    }
```

- `IoView` の実装（10-10 の `impl IoServices for IoView<'_>`）に、`Some(IoView { rt: &mut *self.rt, resources: &mut *self.resources })` を返す関数を加えるのは L00 である。
- この口を使ってよいのは、本章の表の関数（HTTP のサーバ、ネットワークの失敗の注入、`Process.runAttached`）と、本章が名指しするもの（`Clock` と乱数の生成器）だけである。ファイルの関数は、リソースを作業用のスレッドへ貸す既存の形（`Lend::Resource`。10-11）で書き、この口でリソースの表に触れない。貸し出しと返却の規則（ADR 0266）を個々の関数が崩さないためである。
- 口を通してリソースの表の OS の資源を借りるときは、項目の状態が `Open` のときだけ使い、`Lent`・`Releasing`・`Released` のときは使わない。`Released` の資源を使おうとしたときは、解放したリソースの使用（`RuntimeError::ReleasedResourceUsed`）とする。HTTP のサーバのリソースは作業用のスレッドへ貸さない（ブロックする解放のときだけ、R24・R26 の手順で貸す）ので、`Lent` の状態で呼ばれることは、ブロックする解放の途中の使用に限られる。この場合も解放したリソースの使用とする（02-09「リソースの追跡」の、解放を始めた後の使用）。

## 受け付けた要求の保存

`Http.requestOf` は、受け付けた要求を返す。解放した後（解放を始めた後を含む）の `Http.Exchange` に使うと、実行時エラー（解放したリソースの使用）とする（03-09「サーバ」、ADR 0289）。`Http.requestOf` は `State` の項目であり、OS の資源（接続）を借りずに要求を読むので、要求の内容は OS の資源と別に持つ。そこで、リソースの表に、リソースの番号から Rust の値を引く添え物の表を加える。`Http.accept` が要求を読み終えたときに、要求の内容（方法、パス、クエリ、ヘッダ、本体の Rust の値）を `Exchange` の番号で加え、`Http.requestOf` がそれを読んで `Http.Request` のレコードを作る。

```rust append=src/runtime/io/resources.rs::ResourceTable
    /// リソースに添えた、言語の値を含まない Rust の値（受け付けた HTTP の要求など。実装プラン 10-16
    /// 「受け付けた要求の保存」）。リソースを解放するときに除く
    pub attachments: BTreeMap<ResourceId, Box<dyn std::any::Any + Send>>,
```

```rust append=src/builtins/iface.rs::StateServices
    /// リソースの表を借りる（実装プラン 10-16「受け付けた要求の保存」）。第 2 段の VM の側の実装だけが `Some` を返す。
    fn resource_table(&mut self) -> Option<&mut crate::runtime::io::resources::ResourceTable> {
        None
    }
```

- VM の側の `StateServices` の実装（R25 が置いたもの）に、`Some(リソースの表)` を返す関数を加えるのは L00 である。
- `Http.requestOf` は、リソースの表の項目の状態が `Open` のときだけ添え物を読む。`Lent`・`Releasing`・`Released` のときは、要求を返さずに解放したリソースの使用（`RuntimeError::ReleasedResourceUsed`）とする（本章「ランタイムの内部への口」の規則と同じ）。
- 添え物は、`Http.Exchange` の解放（`with` を抜けるときの解放、`Http.closeExchange`、止める手順と中断の要求での解放）で項目が `Released` になるときに除く。受け付けた要求の数に比例してメモリが増えることはない（ADR 0289）。実行の終わりに残った添え物は、実行ごとの状態とともに捨てる。
- 添え物を加え、読むのは HTTP のサーバの層（L30）だけである。ほかの作業は添え物を使わない。

## HTTP のサーバの接続の層

HTTP のサーバは、`httparse` と `mio` の上に自作する接続の層で行い、VM のスレッドのイベントループで動かす（ADR 0143 の決定 1、02-09「IO 実行器」）。層は新しいモジュール `runtime::io::http` に置く。10-10 は「`mio` の型は `runtime::io::event` の外に出さない」としたが、本章でこれを「`runtime::io::event` と `runtime::io::http` の外に出さない」と改める。組み込みの関数（`builtins::funcs::http_server`）は、`mio` の型に触れず、`runtime::io::http` の関数を呼ぶ。

```rust sig=src/runtime/io/mod.rs
pub mod http;
```

```rust file=src/runtime/io/http.rs
//! HTTP/1.1 のサーバの接続の層（設計書 02-09「IO 実行器」、03-09、ADR 0143・0149・0170）。
//! `mio` の型は、このモジュールと `runtime::io::event` の外に出さない。中身は L30 が書く（実装プラン 10-16）。

/// 受け付ける要求の本体の大きさの上限（16 MiB。03-09「要求と応答の型」、ADR 0287）。
/// 超えた要求には、処理系が状態コード 413 の応答を返す。
pub const MAX_REQUEST_BODY_BYTES: u64 = 16_777_216;

/// 資源の不足で受け付けをやり直すまで待つ時間の最初の値（ミリ秒。03-09「失敗の種類」、ADR 0170）。
pub const ACCEPT_RETRY_INITIAL_MILLIS: u64 = 5;

/// 資源の不足で受け付けをやり直すまで待つ時間の上限（ミリ秒）。
pub const ACCEPT_RETRY_MAX_MILLIS: u64 = 1_000;
```

層の中の型と関数（待ち受けと接続の OS の資源、読みかけの要求、書きかけの応答、イベントループへの登録）は L30 が決める。凍結しないのは、使うのが L30 の組み込みの関数だけだからである。L30 は、`runtime::io::event`（R26）に、この層から使う `pub(crate)` の登録の関数を加えてよい。

### 準備の待ちの規則

`IoWait::Readiness { resource, interest }`（10-11）は、U2 では使う関数がなく、R26 は `Stop::Internal` を返す形で置いた（R26「手順の要点」）。L30 は、次の規則で、準備の待ちを VM とイベントループに組み込む。

1. HTTP のサーバの操作（`Http.accept`・`Http.respond`）は、非同期の読み書き（`WouldBlock` で止まる）を VM のスレッドで行う。進めなくなったら、そのリソースと向き（読むか書くか）で `IoWait::Readiness` を返す。
2. VM は、`Readiness` の待ちを、種類 `OpKind::Readiness` の外部の操作の記録（10-10）にし、タスクを `WaitReason::Readiness(番号)` で待たせる。`runtime::io::http` は、そのリソースの OS の資源をイベントループに登録する。
3. イベントループが準備を知らせたら、完了（`Outcome::Ready`）を送る。VM は、`Deliver` でタスクがまだその番号を待っていれば、結果の値を作らずに、同じ呼び出しの命令（`site`）の操作をもう一度送り出しの列に置く（要求をやり直す）。操作の関数は、もう一度呼ばれたときに、リソースに残した途中の状態（読みかけの要求、書きかけの応答）から続ける。
4. 資源の不足で受け付けをやり直すまで待つとき（ADR 0170）も、`Http.accept` は `Readiness` を返す。`runtime::io::http` は、待ち受けがやり直しの時刻を持つ間は、イベントループの登録の代わりにタイマーの期限（単調な時計）で準備を知らせる。こうすると、待つ間もほかのタスクが進み、中断の要求を受け付ける（03-09「失敗の種類」）。
5. 準備の待ちは外部の待ちであり、行き詰まりの判定に数える（10-10「完了の処理と行き詰まりの判定の順序」の手順 5）。取り消したタスクの `Readiness` の記録は、10-10 の規則のとおり配送先を外して残し、準備が来たら捨てる（やり直さない）。

`Http.listenerPort` は、口（`runtime_view`）でリソースを読み、待たずに完了する（02-09「組み込みの操作とハンドラ表」の「VM のスレッドで、すぐに完了する」）。`Http.listen` は、名前の解決と待ち受けの開始を作業用のスレッドで行い（同 表の「`Http.listen` の名前の解決」）、完了の処理で `register_resource(ResourceKind::HttpListener, …)` で表に加える。

### 実装プランで決める値

HTTP のサーバの細部を、次のとおり決める。理由の句を除く行は、設計者が確かめて 03-09「サーバの接続と要求の読み方」に【方針】として書いた（ADR 0291）。表と 03-09 が食い違うときは、03-09 を正とする。

| 値 | 決めたこと | 理由 |
|---|---|---|
| 一つの接続で受け付ける要求の数 | 一つ。応答に `connection: close` を付け、応答を送った後か解放のときに接続を閉じる | 03-09 は `Http.closeExchange` を「接続を閉じる」と定め、`Http.Exchange` を接続と一対一に扱う。持続的な接続を扱うと、一つの `Exchange` の解放で接続を閉じるかを別に決める必要が生じる |
| 要求の本体の読み方 | `content-length` と `transfer-encoding: chunked` の両方を読む。どちらもなければ本体は空とする。両方あるか、形が正しくなければ状態コード 400 | HTTP/1.1 のサーバは chunked の本体を読めることが求められる（RFC 9112）。両方あるときの扱いを決めないと、要求の境目の解釈が食い違う |
| 本体の上限の判定 | `content-length` の値か、chunked を読んだ累計が `MAX_REQUEST_BODY_BYTES` を超えた時点で、本体の残りを読まずに状態コード 413 を返し、接続を閉じる | 上限を超える本体をメモリに読まない |
| 要求の頭（要求の行とヘッダ）の上限 | 64 KiB とし、超えたら状態コード 431 を返す。ヘッダの数は 100 までとし、超えたら 431 | `httparse` はヘッダの数の上限を呼び出し側が与える。頭が終わらない接続でメモリを使い続けない |
| 文字列にできない要求 | 要求の対象（パスとクエリ）とヘッダの値が、`Http.Request` の `String` にできない（UTF-8 でない）ときは、HTTP として読めない要求として状態コード 400 を返す | 03-09 は、HTTP として正しくない要求に 400 を返すと定めるだけで、UTF-8 でない場合を定めていない（[OPEN-062](../../design/open-issues.md#open-062) の R14）。新しい規則を作らず、既にある規則に寄せた。R14 の再現テストは L33 が書く |
| 応答に処理系が付けるヘッダ | `content-length`（本体の大きさ）と `connection: close`。利用者の `headers` に同じ名前（大文字と小文字を区別しない）があれば、処理系の値で置き換える | 03-09 は `Content-Length` を処理系が付けると定める。食い違う二つの値を送らない |
| 状態コードの理由の句 | RFC 9110 の句。知らないコードは空の句 | 利用者が句を指定する欄はない |

## 外部コマンドの標準入出力

`Process.runAttached` は、コマンドの標準入出力を、実行ごとの状態の出力先と標準入力につなぐ（02-09「組み込みの操作とハンドラ表」）。CLI の `run` ではプロセスのものを子に継がせ、テストの実行器とゴールデンテストの実行器では、空の入力と、その実行の出力先につなぐ（ADR 0165）。どちらかを組み込みの関数が知るために、`IoRuntime` に欄を加える。

```rust sig=src/runtime/io/services.rs
/// `Process.runAttached` が子プロセスの標準入出力をつなぐ先（実装プラン 10-16「外部コマンドの標準入出力」）。
/// 真ならプロセスのものを子に継がせる。偽なら、標準入力は空の入力、標準出力と標準エラー出力は、子の出力を
/// 集めて、コマンドが終わった後に実行の出力先へ書く。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
pub struct ProcessStdio {
    pub inherit_stdin: bool,
    pub inherit_stdout: bool,
    pub inherit_stderr: bool,
}
```

```rust append=src/runtime/io/services.rs::IoRuntime
    /// `Process.runAttached` の標準入出力のつなぎ先（実装プラン 10-16）。`IoRuntime::new` は既定の値（継がせない）で作り、
    /// `runtime::run` が `RunEnv` の標準入出力から決める（L13）
    pub process_stdio: ProcessStdio,
```

- `runtime::run` は、`RunEnv::stdin` が `StdinSource::Process` なら `inherit_stdin` を、`RunEnv::stdout` が `OutputTarget::Stdout` なら `inherit_stdout` を、`RunEnv::stderr` が `OutputTarget::Stderr` なら `inherit_stderr` を真にする（10-13「実行の流れ」）。これを書くのは L13 である。
- 継がせないときの出力は、子が終わった後に、標準出力、標準エラー出力の順に `IoServices::write_output` で書く。子の標準出力と標準エラー出力の間の書いた順は保たない。完了の処理は待てないので、`write_output` が容量の待ちを返しても待たずに進む。書き込みは預けられ、後の書き込みに追い越されない（ADR 0265 の決定 4）ので、出力の順は崩れない。
- 継がせるときも、子を起動する前に出力の転送の完了を待つ（`WorkerWait::after_output_flush`。02-09「出力のバッファ」）。処理系が標準入力を読んで持っている読みかけの内容（読み手のバッファ）は、子に渡らない。

## テスト用のハンドラ表のネットワークの失敗

ループバックの通信では起こしにくいネットワークの失敗（名前の解決の失敗、接続の拒否、接続のリセット、時間切れ）は、Rust のテストが、実行に差し替えの部品として渡すテスト用のハンドラ表で与える（02-09「組み込みの操作とハンドラ表」、07-03「HTTP のテスト（初回リリース版）」、ADR 0222・0287）。差し替えの部品は 10-10 の `RuntimeParts` であり、`CliEnv::parts` と `RunEnv::parts`（10-13）で実行に渡る。そこで、`RuntimeParts` に失敗の表を加える。

```rust sig=src/runtime/sched/parts.rs
/// テスト用のハンドラ表が返すネットワークの失敗（実装プラン 10-16、ADR 0222・0287）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum NetworkFault {
    HostNotFound,
    ConnectionRefused,
    ConnectionReset,
    TimedOut,
}

/// テスト用のハンドラ表のネットワークの失敗の表。空なら、本番のハンドラ表と同じく実際に行う。
#[derive(Clone, Debug, Default)]
pub struct NetworkFaults {
    /// 名前（`Http.send`・`Http.get` の URL の host と、`Http.listen` の `host`）ごとに返す失敗
    pub by_host: Vec<(String, NetworkFault)>,
}

impl NetworkFaults {
    /// `host` に当てる失敗。名前は ASCII の大文字と小文字を区別せずに比べる。なければ `None`。
    pub fn lookup(&self, host: &str) -> Option<NetworkFault>;
}
```

```rust append=src/runtime/sched/parts.rs::RuntimeParts
    /// テスト用のハンドラ表のネットワークの失敗（実装プラン 10-16）。実際の実装の組（`RuntimeParts::real`）は空である
    pub network_faults: NetworkFaults,
```

- `NetworkFaults::lookup` の中身は L00 が書く。
- 失敗を当てるのは、`Http.send`（`Http.get` はこれを呼ぶ）と `Http.listen`（`Http.serve` はこれを呼ぶ）である。関数は、`runtime_view` で `RuntimeParts` を読み、名前に失敗があれば、実際の操作を行わずに、その種類（`HostNotFound`・`ConnectionRefused`・`ConnectionReset`・`TimedOut`）の `NetworkError` の `Result.Error` を完了として返す。作業用のスレッドへ仕事を出さないので、テスト用の `WorkerExec`（R26）の筋書きなしに決まった結果が得られる。
- `Http.listen` に `ConnectionRefused`・`ConnectionReset`・`TimedOut` を当てたときも、その種類の失敗を返す。03-09 の「返しうる種類」の表にない組み合わせだが、テストが指定したときだけ起きるので、利用者のスクリプトの振る舞いは変わらない。
- 失敗の表は処理系のテストだけが使い、CLI と `benitoite test` からは与えられない（`RuntimeParts::real` が空の表を作る。ADR 0274 の決定 2 と同じ扱い）。

## 隠れた乱数の生成器

`Random.Generate` の操作は、実行の始めに OS の乱数で種を決めた隠れた生成器を使う（03-07「Random」）。生成器は `Random.fromSeed` と同じ xoshiro256** であり、状態は 256 ビットなので、10-10 の `IoRuntime::random_state` を `[u64; 4]` にした。

- R26 は、`IoRuntime::new` で `random_state` を 0 で埋め、`IoView::random_u64` を xoshiro256** の一歩（状態を進めて 64 ビットを返す）として書く。
- L14 は、`runtime::run` が `IoRuntime` を作った直後に、`getrandom::u64()` の値を種とし、SplitMix64 で広げた 4 個の値を `random_state` に入れる（03-07「Random」の手順）。`getrandom` が失敗したときは、処理系の不具合（`Stop::Internal`）として実行を止める。OS の乱数が得られない環境で、予測できる種で黙って続けないためである。
- 種を広げる手順と xoshiro256** の一歩は、`Random.fromSeed` などの純粋な関数（L14）と同じ関数を使う。

## 時計

`Clock.now` と `Clock.localOffsetMinutes` は、10-10 の `Clock`（差し替えられる時計）の `now_millis`・`local_offset_minutes` を `IoServices` 越しに読む。R25 が書く実際の時計の `local_offset_minutes` は、R25 の作業の文書が中身を定めておらず、OS の時差を求める `jiff` は U3 のクレートなので、R25 の時点では OS の時差を返せない。L10 が、`jiff` の `TimeZone::try_system()` で OS の時差を求める形に書き換える。求められないときは 0 を返す（ADR 0287 の決定 1）。テスト用の時計（R25）は、テストが与えた値を返す。

## 正規表現の組み立ての関数

F17 は、`Regex.compile` の引数が文字列リテラルか定数式のとき、正規表現を検査の時点で組み立てる（03-08「Regex」、OPEN-062 の R08）。検査の時点と実行の時点で結果が食い違わないように、組み立ての設定を一か所に置き、`Regex.compile` の本体とこの関数の両方がそれを使う。

```rust sig=src/builtins/mod.rs
pub mod regex_check;
```

```rust sig=src/builtins/regex_check.rs
//! 正規表現の源の検査（設計書 03-08「Regex」、OPEN-062 の R08）。L22 が書き、F17 が呼ぶ（実装プラン 10-16）。

/// 正規表現の源 `source` を、実行時の `Regex.compile` と同じ設定で組み立て、成否を返す。
/// 失敗なら、`Regex.compile` が `Result.Error` に入れるものと同じ理由の文字列（改行を含みうる）を返す。
/// 純粋な関数であり、組み立てた正規表現は捨てる。
pub fn check_regex_source(source: &str) -> Result<(), String>;
```

- L22 は、組み立ての設定（`regex::RegexBuilder` に与える大きさの上限など）を、`builtins::funcs::regex` と共有する非公開の関数に置き、`Regex.compile` の本体と `check_regex_source` の両方から呼ぶ。
- シグネチャに `regex` クレートの型を含めないのは、クレートを加える L22 より前の作業（F17 の文書を書く時点、`check` の道具）で、この宣言をコンパイルできるようにするためである。

## 作業用のスレッドで行う操作

作業用のスレッドで行う U3 の操作（02-09「組み込みの操作とハンドラ表」の表の「作業用のスレッドで行う」）は、R29 と同じく `WorkerWait::new` で書き、新しい口を要しない。

| 操作 | 仕事 | 完了の処理 |
|---|---|---|
| `Console.readAllLines`・`readAllBytes` | `Lend::Stdin`、`after_output_flush`。残りを上限より 1 バイト多い分まで読む | 行に分ける、`Bytes` にする。UTF-8 でなければ `InvalidUTF8` |
| `File` のパスを受け取る操作 | パスを基準のディレクトリから解決し、`std::fs` で行う | `IOError` への対応（R29 の表と 03-07「IOErrorKind と関数の対応」） |
| `File.readChunk`・`File.Writer` の操作 | `Lend::Resource` で借りる | 同上 |
| `File.openWriter` | 開く | `register_resource(ResourceKind::FileWriter, …)` |
| `Process.run`・`shell`・`runAttached` | 子を起動して待つ。`runAttached` は `after_output_flush` | 終了状態、集めた出力（UTF-8 の確かめ、上限） |
| `Http.send` | `ureq` で送り、応答の本体を上限より 1 バイト多い分まで読む | `Http.Response` のレコード、`NetworkError` |
| `Http.listen` | 名前を解決し、待ち受けを始める | `register_resource(ResourceKind::HttpListener, …)` |

- 取り消したタスクの操作は止めない。起動した外部コマンドも終わらせない（02-09「タスクの待ちと取り消し」）。中断の要求で止めるときも、処理系は子プロセスに何も送らない。端末からの `SIGINT` は、端末が同じプロセスグループの子にも送る。
- 大きさの上限を超えた入力は資源の不足（`ResourceError::InputTooLarge`）とする（02-09「一つの操作で作る値の大きさの上限」）。

## 置き方と既存の構築の箇所

L00 は、本章のブロックを 10-15 と同じく `place --task L00` で置く。構造体に欄を加えるブロック（`ResourceTable`・`IoRuntime`・`RuntimeParts`）を置くと、その構造体をすべての欄を書いて作る箇所がコンパイルできなくなる。L00 は、次の箇所に既定の値（`NetworkFaults::default()`・`ProcessStdio::default()`・`BTreeMap::new()`）を加える。

| 構造体 | 作る箇所（L00 の時点のクレートで `grep` して確かめる） |
|---|---|
| `IoRuntime` | `IoRuntime::new`（R26） |
| `RuntimeParts` | `RuntimeParts::real`（R26）、`sched::testing` の部品を作る関数（R25）、それを使うテスト |
| `ResourceTable` | `Default` で作る。すべての欄を書いて作る箇所があれば、同じく加える |

トレイトに加えた関数の既定の実装を上書きする箇所（`IoView` の `runtime_view`、VM の側の `StateServices::resource_table`）も L00 が書く。本体は一行であり、以後の作業（L10・L13・L30・L32）がどれも使うからである。

## 作業の割り当て

| 作業 | 本章で受け持つもの |
|---|---|
| L00 | 本章のブロックを置く。上の既存の構築の箇所に既定の値を加える。`runtime_view`・`resource_table` の上書き、`NetworkFaults::lookup` |
| L10 | 実際の時計の `local_offset_minutes`（`jiff`） |
| L13 | `runtime::run` で `process_stdio` を決める。`Process.run`・`runAttached`・`shell` |
| L14 | 隠れた生成器の種（`getrandom`）と `IoView::random_u64` の確かめ |
| L22 | `check_regex_source` と、組み立ての設定の共有 |
| L30 | `runtime::io::http` の層、準備の待ちの規則（R26 の `Deliver` の処理と `event.rs` を広げる）、受け付けた要求の保存、実装プランで決める値 |
| L32 | `ureq` と TLS の組み立て、ネットワークの失敗の注入（`Http.send`）、上の【要検証】の二つ |
| L33 | ネットワークの失敗の注入のテスト（`network_faults` を入れた `RuntimeParts` を `RunEnv::parts` で渡す Rust のテスト） |
