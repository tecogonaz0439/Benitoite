# 0330. HTTP のクエリの壊れた符号化、クライアントのプロキシと CPU の機能、時間切れのテストを決める

- 状態: 採択（決定 4 のテストのサーバの形を 0335 で改めた）
- 日付: 2026-10-07
- 関連章: [ネットワークのモジュール](../03-interop/03-09-network.md)
- 関連 ADR: [0143](0143-http-and-tls-crates.md), [0222](0222-http-tests-over-loopback.md), [0287](0287-stdlib-details-decided-in-u3-plan.md), [0291](0291-file-copy-limit-and-http-server-details.md), [0322](0322-stdlib-details-from-u3-preflight.md)

## 背景

2026-10-07 に、実装プランの L30〜L32（HTTP のサーバとクライアント）の作業文書の事前点検で、03-09 が定めていないか、使うクレートの振る舞いと作業の進め方が合わない点が四つ見つかった。どれも設計者が判断した。

1. HTTP のサーバが受け取るクエリの細部。03-09 は、`?` より後を `&` と `=` で区切り、パーセント符号化を戻すと定め、戻した結果が正しい UTF-8 でないクエリには状態コード 400 を返すと定める（ADR 0291、ADR 0322 の決定 4）。しかし、`%` の後が 16 進の 2 桁でないもの（`?q=%G0`、末尾の `%`）のように符号化を戻せないもの、`=` のない項目（`?a`）、空のクエリ（`?` だけのものと、`?` のないもの）の扱いを定めていなかった。
2. HTTP のクライアントのプロキシ。ureq 3.4.2 の `Config` の既定の値は、プロキシを `Proxy::try_from_env()` で環境変数から読む（`src/config.rs` の `Default`、`src/proxy.rs`）。`try_from_env` は `ALL_PROXY`・`HTTPS_PROXY`・`HTTP_PROXY`（と小文字の名前）をこの順に読み、`NO_PROXY`（と `no_proxy`）を除外の一覧として読む。03-09 はプロキシを定めていない。
3. `x86_64` で、graviola が要する CPU の機能が足りない計算機。graviola 0.4.1 は、公開の関数の入口ごとに `verify_cpu_features` を呼び、機能が足りなければ `assert!` で panic する（`src/low/entry.rs`、`src/low/x86_64/cpu.rs`）。要する機能は `aes`・`pclmulqdq`・`bmi1`・`adx`・`avx`・`avx2` である。`aarch64` でも同じく `neon`・`aes`・`pmull`・`sha2` を要し、足りなければ panic する（`src/low/aarch64/cpu.rs`）。graviola は機能を確かめる関数を公開していない（`verify_cpu_features` は `pub(crate)`）。panic は処理系の不具合として報告される（02-09「panic 境界」）が、利用者の誤りでも処理系の誤りでもない。03-09 は「`graviola` が対象としない CPU では、`https` の URL を扱えない」とだけ定める。
4. L32 の HTTP のクライアントの時間切れ（`timeoutMilliseconds`）のテスト。ureq の時間の上限（`timeout_global`）は実時間で数えるので、仮想の時間では時間切れを起こせない。実装プランのテストの方針は実時間の待ちに頼らないことであり、例外は ADR 0322 の帰結の L13 の一件だけだった。

## 決定

1. HTTP のサーバが受け取るクエリは、次のとおり読む。
   - パーセント符号化を戻せないもの（`%` の後が 16 進の 2 桁でないもの。`?q=%G0` や末尾の `%`）は、戻さずに、受け取った字面のまま残す。`Http.pathSegments` が戻せない要素を残すのと同じ扱いである。
   - `=` のない項目（`?a`）は、名前がその字面で、値が空の文字列の項目とする。
   - 戻した結果が正しい UTF-8 にならないクエリは、ADR 0291 と ADR 0322 の決定 4 のとおり、HTTP として正しくない要求として状態コード 400 を返す。
   - 空のクエリ（`?` だけのもの、`?` のないもの）は、項目のない空のクエリ（`query` が空のリスト）とする。
2. HTTP のクライアント（`Http.send`・`Http.get`）は、初回リリース版では、環境変数のプロキシ（`HTTPS_PROXY`・`HTTP_PROXY`・`ALL_PROXY`・`NO_PROXY`）に従わず、接続先に直接つなぐ。
3. `https` の URL への要求では、TLS を組み立てる前に、graviola が要する CPU の機能があるかを確かめる。足りなければ、`NetworkErrorKind.Other` と理由の文字列の `Result.Error` を返す（graviola が panic する前に止める）。`http` の URL は、機能が足りない計算機でも使える。確かめる機能は、`x86_64` では `aes`・`pclmulqdq`・`bmi1`・`adx`・`avx`・`avx2`、`aarch64` では `neon`・`aes`・`pmull`・`sha2` とする。
4. L32 の、HTTP のクライアントの時間切れのテストに限り、実時間の短い待ち（100 ミリ秒程度）を許す。テストのサーバは `Clock.sleep` で応答を遅らせず、クライアントのタスクの結果を待ってから応答し、接続を解放する。

## 検討した代替案

- 1 で、戻せない符号化も状態コード 400 にする案。ADR 0322 の決定 4 の「壊れた入力は早く拒む」に揃う。しかし、`Http.pathSegments` は戻せない要素を残すので、パスとクエリで扱いが分かれる。多くの HTTP のサーバも、戻せない符号化を字面のまま渡す。UTF-8 にならない結果だけを 400 にするのは、`Http.Request` の `String` の値を作れないからであり、字面のまま残せる場合とは事情が違う。
- 2 で、ureq の既定のとおり環境変数のプロキシに従う案。プロキシのある環境ではそのまま使える。しかし、同じスクリプトの振る舞いが実行する環境の変数で変わり、ループバックの通信のテスト（ADR 0222）も、テストを動かす環境にプロキシの変数があると結果が変わりうる。必要になったら、後の版で、従うことを指定する手段を加える。
- 3 で、graviola の panic を処理系の不具合のまま報告する案。CPU が古いことは処理系の不具合ではなく、利用者が報告を読んでも原因が分からない。
- 4 で、時間切れのテストを書かない案と、時間切れを起こす偽の部品を作る案。前者は `timeoutMilliseconds` を ureq に渡す処理を確かめられない。後者は、ureq の中で数える時間を差し替えられないので作れない。

## 帰結

- 03-09「要求と応答の型」の `query` の箇条に決定 1 を、「クライアント」に決定 2・3 を書く。
- 決定 2 は、ureq の `ConfigBuilder::proxy(None)` で設定する。`Config::default()`・`Config::builder()`・`Agent::config_builder()` はどれも既定の値から始まり、既定の値が `Proxy::try_from_env()` を呼ぶので、明示して `None` を与える。
- 決定 3 は、graviola に機能を確かめる公開の関数がないので、処理系が `std::arch::is_x86_feature_detected!`（`x86_64`）と `std::arch::is_aarch64_feature_detected!`（`aarch64`）で同じ機能を確かめる。graviola の版を上げるときは、要する機能の一覧（`verify_cpu_features`）の変化を確かめる。
- 決定 3 の確かめは、最初の URL が `https` の要求だけでは足りない。`http` の URL からリダイレクトで `https` に移ると、ureq は TLS の接続器を呼ぶ。機能が足りない計算機では、TLS の接続器を含まない接続器の連なりで `Agent` を作り（ureq の `Agent::with_parts`）、ureq が返す `Error::TlsRequired` を同じく `NetworkErrorKind.Other` と理由の文字列にする。
- 実装プランのテストの方針（実時間の待ちに頼らない）の例外に、決定 4 の一件を加える。ADR 0322 の帰結の例外の箇条に追記する。
- 実装プランの 10-16 と、L30・L31・L32 の作業文書に反映する。凍結したコードとシグネチャは変えない。
