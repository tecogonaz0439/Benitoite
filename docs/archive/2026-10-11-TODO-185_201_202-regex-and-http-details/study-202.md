# TODO-202 の調査（HTTP サーバの細部の残り）

TODO-202 の四つの点（応答から除く接続ごとのヘッダ、パスが空の `OPTIONS` の絶対形、要求の対象の `#`、`100-continue` の書き込みの準備を待つ経路のテスト）について、今の実装、確かめた外部の事実、直し方の案をまとめる。経緯は、前の改造（`docs/archive/2026-10-11-TODO-042_177_195_196_197_198-runtime-and-check-hardening/`）の `decisions.md` の Q18 と、`reviews/2026-10-11-H2/report.md` の所見 3・6・7 にある。

この調査では、処理系のソース・テストを変えず、ビルドとテストも走らせていない。行番号は、ブランチ `san_benito`（0485561）の作業ディレクトリで読んだものである。

## 1. 今の実装

### 1.1 担当の分け方とクレート

- サーバは `crates/benitoite/src/runtime/io/http.rs`（1326 行）にあり、単体テストは `crates/benitoite/src/runtime/io/http/tests.rs` にある。組み込みの関数 `Http.respond` は `crates/benitoite/src/builtins/funcs/http_server.rs:116` で `http::response_bytes` を呼ぶ。
- 使うクレートは `Cargo.lock` で `httparse` 1.10.1、`mio` 1.2.4、`rustix` 1.1.5 である。`hyper` は使っていない（設計書 03-09「実装に使うクレート」）。
- `httparse` が行うのは、要求の行とヘッダの字句の解析だけである。要求の対象の文字は、`httparse` 1.10.1 の `URI_MAP`（`src/lib.rs` 69 行）で `b'!'..=0x7e | 0x80..=0xFF` を許す。`#`（0x23）も、RFC の文法で要求の対象に許さない `"`・`<`・`>`・`\`・`^`・`` ` ``・`{`・`|`・`}` も通す。ソースのコメントは `TODO: Make a stricter checking for URI string?` である。
- 要求の対象の解釈、本体の区切り、`100-continue`、応答の組み立てと除くヘッダ、読み書きの準備の待ちは、すべて処理系が `http.rs` で行う。

### 1.2 要求の対象の扱い

- `RequestReader::advance`（`http.rs` 800 行付近）は、`httparse` が返した対象を `origin_target`（995 行）に渡し（826 行）、結果を最初の `?` で `path` と `query` に分ける。
- `origin_target` は、先頭が `http://` か `https://`（大文字と小文字を区別しない）のときだけ絶対形として扱う。
  - authority の終わりを `/`・`?`・`#` のどれかで探し、空か `Host` と同じ文字の集まりの外の文字（`@` を含む）なら 400 にする。
  - パスの始まりは `/` か `?` で探す（`#` を探さない）。見つからなければ空とし、`/` で始まらなければ `/` を前に付ける。
  - 絶対形でなければ、対象をそのまま返す。起点形・`*`・`CONNECT` の `h:443` のほか、`GET *` や `/` で始まらない対象も、そのまま `path` になる。
- このため、TODO-202 の挙動になる。

  | 要求の対象 | 今の `path` |
  |---|---|
  | `http://h/p#f` | `/p#f`（断片が残る） |
  | `http://h#f` | `/`（断片が消える） |
  | `http://#f` | 400（authority が空） |
  | `/p#f`（起点形） | `/p#f` |
  | `/p?x=1#f` | `/p`、`query` の値が `1#f` |
  | `OPTIONS http://h:8001` | `/` |
  | `OPTIONS *` | `*` |

- 単体テスト `request_absolute_target_becomes_origin_path_and_query`（tests.rs 282 行）が、`http://h` → `/` と `OPTIONS *` → `*` と、`http://#f` などの 400 を確かめている。

### 1.3 応答の組み立てと除くヘッダ

- `replaced_response_header`（`http.rs` 1097 行）は、`content-length`・`connection`・`transfer-encoding`・`trailer` を大文字と小文字を区別せずに除く。
- `response_bytes`（1109 行）は、除いた後の利用者のヘッダを並べ、最後に処理系の `content-length`（表による）と `connection: close` を付ける。処理系の `error_response`（1151 行）も同じ形である。
- 単体テスト `response_replaces_framing_headers_and_uses_known_reason_phrases`（tests.rs 343 行）は、`Keep-Alive: timeout=5` と `Upgrade: example` が**そのまま送られる**ことを期待のバイト列で確かめている。直すとこの期待が変わる。
- `Http.send` の応答のヘッダは、`crates/benitoite/src/builtins/funcs/http_client.rs:242` で `ureq` の `response.headers()` をすべて写す。上流の応答の `Connection`・`Keep-Alive` などが `Http.Response` に入るかは、`ureq` が受け取ったヘッダを除かずに返すかによる。これは確かめていない。利用者がその `headers` を `Http.respond` に渡せば、今は `Keep-Alive`・`Upgrade`・`Connection` に挙げた名前のヘッダがそのまま送られる。

### 1.4 `100-continue` と書き込みの準備の待ち

- `RequestReader::advance` は、HTTP/1.1・`Expect: 100-continue`・本体あり・本体のバイトをまだ受け取っていない、のすべてを満たすときに `send_continue` を立てる（889 行）。
- `Connection::advance`（330 行）は、`take_continue` が真なら 100 の行を `interim` の `WriteBuffer` に置き、書き切るまで読み込みを進めない。`WriteBuffer::advance`（760 行）が `WouldBlock` を返すと `Ok(false)` になり、`Connection::advance` は `ConnectionStep::Waiting` を返す（341 行）。
- `arm`（1228 行付近）は、`interim` か `rejection` があれば `WRITABLE` を、なければ `READABLE` を登録する。
- 統合テスト `expect_continue_arrives_before_body_and_final_response_in_both_modes`（`crates/benitoite/tests/l30_http_server.rs` 215 行）は、100 が本体と最終の応答より前に届くことを確かめる。ただし、100 の 25 バイトは一度で書けるので、`Ok(false)` → `Waiting` → `WRITABLE` の登録 → 再開、の経路はどのテストも通らない（H2 の所見 3）。

### 1.5 テストの部品の前例

- `Listener` には `#[cfg(test)] injected: VecDeque<io::Error>`（201 行）があり、`next_connection` がその誤りを先に返す。テストのために本番の型へ `#[cfg(test)]` の欄を足した前例である（tests.rs 145 行の `per_connection_accept_errnos_continue_until_listener_failure`）。
- 起こし口は、`event::wakeup_with_poll()`（`runtime/io/event.rs` 152 行）で実際の `mio::Poll` 付きのものを作れる。
- 部分書き込みのテストの前例は `resume_finishes_pending_response_without_replacement_bytes`（tests.rs 931 行）である。16 MiB の応答を送り、OS の送りのバッファがそれより小さいことを当てにして `WouldBlock` を起こす。
- `rustix` は機能 `std`・`fs` だけで使っており（`crates/benitoite/Cargo.toml` 31 行）、`SO_SNDBUF` を設定する `net` の機能はない。`mio` 1.2.4 の `TcpStream` が送りのバッファの大きさを設定する関数を持つかは確かめていない。

## 2. 確かめた外部の事実

RFC の本文は、rfc-editor.org のテキスト版（https://www.rfc-editor.org/rfc/rfc9110.txt 、https://www.rfc-editor.org/rfc/rfc9112.txt 、https://www.rfc-editor.org/rfc/rfc3986.txt ）を 2026-10-11 に取得して読んだ。

### 2.1 接続ごとのヘッダ（RFC 9110 §7.6.1・§7.8・§10.1.4・§15.5.22）

- 中継は、`Connection` に挙げた名前のヘッダと `Connection` 自体を、転送の前に除かなければならない（MUST）。

  > Intermediaries MUST parse a received Connection header field before a message is forwarded and, for each connection-option in this field, remove any header or trailer field(s) from the message with the same name as the connection-option, and then remove the Connection header field itself (or replace it with the intermediary's own control options for the forwarded message).（RFC 9110 §7.6.1）

- `Connection` に挙げていなくても除くべき名前は、強さが SHOULD である。

  > Furthermore, intermediaries SHOULD remove or replace fields that are known to require removal before forwarding, whether or not they appear as a connection-option, after applying those fields' semantics. This includes but is not limited to: Proxy-Connection (...), Keep-Alive (...), TE (Section 10.1.4), Transfer-Encoding (...), Upgrade (Section 7.8)（RFC 9110 §7.6.1）

- 接続のための情報を運ぶヘッダを送る側は、その名前を `Connection` に挙げなければならない（MUST）。`Connection` を伴わずに届いた接続ごとのヘッダは、受け手が無視するべきものとされる。

  > When a field aside from Connection is used to supply control information for or about the current connection, the sender MUST list the corresponding field name within the Connection header field.（§7.6.1）
  > a connection-specific field received without a corresponding connection option usually indicates that the field has been improperly forwarded by an intermediary and ought to be ignored by the recipient.（§7.6.1）

- `TE` は要求のヘッダである（クライアントの能力を表す）。`TE` を送る側は `Connection` に `TE` を挙げなければならない（§10.1.4 の "A sender of TE MUST also send a "TE" connection option"）。応答で `TE` を送る意味は RFC にない。
- `Upgrade` を送る側は `Connection` に `Upgrade` を挙げなければならない（MUST）。

  > A sender of Upgrade MUST also send an "Upgrade" connection option in the Connection header field (Section 7.6.1) to inform intermediaries not to forward this field.（§7.8）

- `Upgrade` を応答で送るのは、101（必須）、426（必須）、その他の応答で将来の要求のために切り替えの能力を知らせる場合（MAY）である。

  > A server that sends a 426 (Upgrade Required) response MUST send an Upgrade header field to indicate the acceptable protocols（§7.8。§15.5.22 も同じ）
  > A server MAY send an Upgrade header field in any other response to advertise that it implements support for upgrading to the listed protocols, in order of descending preference, when appropriate for a future request.（§7.8）

- Benitoite との関係: Benitoite のサーバは中継ではなく、§7.6.1 の中継の規則は直接には掛からない。ただし、処理系は `connection: close` で `Connection` を置き換えるので、利用者の `Upgrade`・`Keep-Alive` を残すと「送る側は名前を `Connection` に挙げる」（MUST）を満たさない応答になる。また処理系は 1xx の応答を送れず（`Http.respond` の 100〜199 は実行時エラー `R0701`）、プロトコルの切り替えを行わない。

### 2.2 `OPTIONS` の絶対形でパスが空のとき（RFC 9112 §3.2.4・§3.2.2・§3.3、RFC 9110 §9.3.7）

- `*` に変えると定めているのは、最後の中継（プロキシ）が転送するときである（MUST）。パスが空で、**クエリもない**ことが条件である。

  > If a proxy receives an OPTIONS request with an absolute-form of request-target in which the URI has an empty path and no query component, then the last proxy on the request chain MUST send a request-target of "*" when it forwards the request to the indicated origin server.（RFC 9112 §3.2.4）
  > For example, the request `OPTIONS http://www.example.org:8001 HTTP/1.1` would be forwarded by the final proxy as `OPTIONS * HTTP/1.1` / `Host: www.example.org:8001`（同）

- 起点のサーバが絶対形を直接受け取ったときの扱いを、`*` と同じにせよとは書いていない。§3.2.2 は、起点のサーバが絶対形を受け付けること（MUST）と、対象の host の情報を使うことだけを定める。
- 一方、§3.3 の対象の URI の組み立てでは、`*` の形の対象 URI のパスとクエリは空になる。`OPTIONS * HTTP/1.1` / `Host: www.example.org:8080` の対象 URI は `http://www.example.org:8080` である（§3.3 の Example 2）。したがって、`OPTIONS http://www.example.org:8080` と `OPTIONS *` は同じ対象 URI を表す。

  > If the request-target is in authority-form or asterisk-form, the target URI's combined path and query component is empty.（RFC 9112 §3.3）

- `*` の `OPTIONS` は、特定のリソースでなくサーバ全体に向けた要求である（RFC 9110 §9.3.7）。`*` の形と `CONNECT` の形は、ほかの方法で使ってはならない（RFC 9110 §7.1 の "These forms MUST NOT be used with other methods."）。

### 2.3 要求の対象の `#`（RFC 9110 §7.1、RFC 9112 §3.2、RFC 3986 §3.5・§4.3）

- 対象の URI は断片を含まない。断片はクライアントの側で扱うものとされる。

  > The target URI excludes the reference's fragment component, if any, since fragment identifiers are reserved for client-side processing ([URI], Section 3.5).（RFC 9110 §7.1）
  > the fragment identifier is separated from the rest of the URI prior to a dereference（RFC 3986 §3.5）

- 要求の対象の文法は、断片を許さない。起点形は `origin-form = absolute-path [ "?" query ]`（RFC 9112 §3.2.1）、絶対形は `absolute-form = absolute-URI`（§3.2.2）で、`absolute-URI = scheme ":" hier-part [ "?" query ]`（RFC 3986 §4.3。"Some protocol elements allow only the absolute form of a URI without a fragment identifier."）である。`query = *( pchar / "/" / "?" )` で、`pchar` も `#` を含まない（RFC 3986 付録 A）。したがって、`#` を含む要求の行は文法に合わない。
- 文法に合わない要求の行の受け手には、400 か、正しく符号化した対象への 301 を勧め、直して処理することを勧めない（SHOULD・SHOULD NOT）。

  > Recipients of an invalid request-line SHOULD respond with either a 400 (Bad Request) error or a 301 (Moved Permanently) redirect with the request-target properly encoded. A recipient SHOULD NOT attempt to autocorrect and then process the request without a redirect, since the invalid request-line might be deliberately crafted to bypass security filters along the request chain.（RFC 9112 §3.2）

  §3.2 の例は空白だが、文は「invalid request-line」一般について述べている。`#` を含む行がこれに当たるという読みは、上の文法からの推論であり、RFC が `#` を名指しして定めた文はない（見つけていない）。
- ほかの実装の挙動（ソースを読んで確かめた範囲だけ）:
  - `http` クレート 1.5.0（`hyper` 1.11.1 の HTTP/1 のサーバが要求の対象を `http::Uri::from_maybe_shared` で解析する。`hyper` の `src/proto/h1/role.rs` 224 行）は、`src/uri/path.rs` の `scan_path_and_query` で `#` を断片の始まりとし、`PathAndQuery::from_shared` で `#` 以降を切り捨てる。400 にはしない。手元の cargo のレジストリにあるソースで読んだ。
  - nginx（GitHub の `nginx/nginx` の master、コミット 2b5c2b6、`src/http/ngx_http_parse.c`）は、要求の行の解析で `#` を見ると `complex_uri` を立て、`ngx_http_parse_complex_uri` でパスを `#` で終える（`case '#': goto done;`）。引数（クエリ）も `#` の前で終える。400 にはしない。
  - 両者とも「取り除く」側である。curl などのクライアントが断片を送らないかどうかは確かめていない。

## 3. 点ごとの直し方の案

### 3.1 接続ごとのヘッダ

選択肢:

- **H-a（今のまま）**: `content-length`・`connection`・`transfer-encoding`・`trailer` だけを除く。`Upgrade`・`Keep-Alive` を残すと、`Connection` に名前のない接続ごとのヘッダを送ることになり、§7.6.1・§7.8 の送り手の MUST に合わない。
- **H-b（推奨）**: 次を除く。
  1. 今の四つ（`content-length`・`connection`・`transfer-encoding`・`trailer`）。
  2. `keep-alive`・`proxy-connection`・`te`・`upgrade`。
  3. 利用者の `connection` の値に挙げた名前（`,` で区切り、前後の空白を除き、大文字と小文字を区別せずに比べる）。
  理由: 処理系は接続を必ず閉じ、プロトコルを切り替えず、応答を chunked で送らない。これらのヘッダは、どれも処理系の接続の実際と食い違う内容を相手に伝える。上流の応答を写して返す使い方（`Http.send` の `headers` をそのまま渡す）では、RFC が中継に求める除去と同じ結果になる。
- **H-c**: H-b のうち `upgrade` だけは残し、`upgrade` があれば `connection: upgrade, close` を送る。426 の応答の MUST（`Upgrade` を送る）を満たせる。ただし、処理系は切り替えを一度も行えないので、`Upgrade` で切り替えの能力を知らせても、相手が次の要求で切り替えを求めたときに応じられない。`connection` に挙げた名前を除く規則と `upgrade` の例外の組み合わせも複雑になる。

`te` と `upgrade` を除いてよいか:

- `te` は要求のヘッダで、応答に置く意味がない。除いて失うものはない。
- `upgrade` は、101 を送れず（`R0701`）切り替えもしない処理系では、426 と「能力の知らせ」にしか使い道がない。どちらも処理系が実際には応じられない切り替えを相手に約束することになる。H-b では、426 の応答に `Upgrade` を付けられなくなる（426 の MUST を満たせない）。426 を送る利用者がいるかは確かめていないが、HTTP/1.1 の層だけを持つ処理系が 426 を使う場面は少ないと見込む。この点は問い Q1 として設計者に尋ねる。

影響:

- 利用者から見える振る舞い: 上の名前のヘッダが送られなくなる。`Connection: x-foo` と書いた利用者の `X-Foo` も送られなくなる。互換性のない変更として CHANGELOG の Unreleased の表に載せるか、Fixed に載せるかを決める（前の改造は `transfer-encoding`・`trailer` の除去を Fixed に書いた）。
- コード: `replaced_response_header` を、利用者のヘッダから除く名前の集まりを先に作る形に変える。長さの計算（`response_bytes` の 1 回目の走査）と書き出し（2 回目の走査）の両方で同じ判定を使う。`connection` の値の分解で確保を増やさないよう、比べるときに値を走査する形にできる（大きさの上限の検査より前に大きな確保をしないため。02-09「一つの操作で作る値の大きさの上限」）。
- テスト: tests.rs 343 行のテストの期待（`Keep-Alive` と `Upgrade` が残る）を変え、`Connection: x-foo` で `X-Foo` が消える場合と、`Connection` に空の要素や空白がある場合を足す。

### 3.2 パスが空の `OPTIONS` の絶対形

選択肢:

- **O-a（今のまま）**: `OPTIONS http://h:8001` は `path` が `/` になる。`OPTIONS /` と区別できない。
- **O-b（推奨）**: 方法が `OPTIONS`（大文字と小文字を区別する。03-09 の方法の照合に揃える）で、絶対形のパスが空で、クエリもないときだけ `path` を `*` とする。`OPTIONS http://h?x=1` は今のとおり `/` とクエリにする。
  理由: RFC 9112 §3.3 によれば `OPTIONS *` と `OPTIONS http://h:8001` は同じ対象 URI を表すので、handler に同じ `path` を渡すのが一貫する。§3.2.4 は中継の規則だが、起点のサーバに中継がいない場合（直接に絶対形を受けた場合）に、最後の中継が行うはずの変換をサーバが代わりに行う形になる。
- **O-c**: 方法を問わずパスが空なら `*` にする。RFC 9110 §7.1 は `*` を `OPTIONS` 以外で使ってはならないとするので採らない。

影響:

- `origin_target` が方法を受け取る必要がある（非公開の関数なので、シグネチャを変えてよい）。
- 03-09「サーバの接続と要求の読み方」の絶対形の項の「authority の後にパスがなければ `/` とする」に例外を書き足す。
- テスト: tests.rs 282 行の表に `("OPTIONS", "http://h:8001", "*", vec![])`、`("OPTIONS", "http://h?x=1", "/", vec![("x","1")])`、`("GET", "http://h", "/", ...)`（既存）を並べる。
- 関連の所見（この TODO の外）: 起点形で `/` で始まらない対象（`GET *`、`GET foo`）を、今は 400 にせず `path` にしている。RFC 9110 §7.1 は `*` を `OPTIONS` 以外で使ってはならないとし、RFC 9112 §3.2 は文法に合わない要求の行を 400 にすることを勧める。`#` と同じ「要求の対象の文法の検査」の問題なので、3.3 と一緒に扱うか、docs/todo の新しい項目にするかを問い Q4 で尋ねる。

### 3.3 要求の対象の `#`

選択肢:

- **F-a（推奨）**: 要求の対象（起点形・絶対形のどちらでも）が `#` を含めば 400 にする。`origin_target` に渡す前に確かめる。
  理由: `#` は要求の対象の文法に合わず（RFC 9112 §3.2.1・§3.2.2、RFC 3986 §4.3）、文法に合わない要求の行は 400 にし、直して処理しないことが勧められている（RFC 9112 §3.2）。設計原則 1（誤りを報告する）にも合う。`#` を断片と見て取り除くと、`/p?x=1#f` のクエリの値が利用者の意図と変わる場合でも気付けない。普通のクライアントは断片を送らない（RFC 9110 §7.1 は対象の URI が断片を含まないとする）ので、400 になるのは誤ったクライアントか、細工した要求だけと見込む。パーセント符号化した `%23` は今のとおり受け付ける。
- **F-b**: 最初の `#` から後ろを取り除く。`http` クレート（`hyper`）と nginx と同じ振る舞いで、寛容である。ただし RFC 9112 §3.2 の「直して処理しない」に反する。
- **F-c（今のまま）**: 絶対形と起点形で扱いが一定しない。採らない。

影響:

- 利用者から見える振る舞い: `#` を含む対象への要求は handler に届かず 400 になる。前の改造の `Host` と絶対形の 400 と同じく、CHANGELOG の Unreleased の「Incompatible changes」の表に足すのが揃う（前の改造は 33 行の項に書いた）。
- `origin_target` の authority の終わりの探索から `#` を外せる（先に 400 にするので）。
- 03-09 の絶対形の項に一文を足す（「要求の対象が `#` を含むときは 400 とする」と理由）。
- テスト: tests.rs 282 行のテストの 400 の並びに `http://h/p#f`・`http://h#f`・`/p#f`・`/p?x=1#f` を足す。l30 の統合テストの 400 の表（`invalid_and_slow_connections_do_not_stop_the_same_accept`）に一つ足すかは任意とする（単体テストで規則を確かめ、統合テストは拒否の後の受け付けの継続を受け持つ、という tests.rs 183 行の方針による）。

### 3.4 `100-continue` の書き込みの準備を待つ経路のテスト

確かめたい性質: 100 を一度で書き切れないとき、(1) `Connection::advance` が `Waiting` を返し、(2) 読み込みを進めず（本体のバイトが届いていても `reader.input` を増やさない）、(3) `arm` が `WRITABLE` を登録し、(4) 書けるようになった後に 100 の残りを書いてから本体を読んで要求を完成させ、(5) 100 を二度送らない。

選択肢:

- **T-a（推奨）: 送りのバッファを `WouldBlock` まで埋めてから進める。** 単体テストで、ループバックの接続を作り、サーバ側の `mio::net::TcpStream` に、相手が読まないまま `WouldBlock` が返るまで埋めのバイトを書く。その後、そのソケットで `Connection` を作り、`Expect: 100-continue` 付きの頭だけを相手から送って `advance` を呼ぶ。
  - 長所: 本物の OS の `WouldBlock` で経路を通る。本番のコードを変えない。バッファの大きさを当てにせず「`WouldBlock` が出るまで」書くので、OS や設定でバッファが大きくても小さくても成り立つ（前例の 16 MiB のテストより弱い仮定である）。`arm` を `event::wakeup_with_poll()` と `ResourceTable` の `Listener` で呼べば、(3) の登録の向きまで確かめられる。
  - 短所: 相手側は、埋めのバイトの後に 100 を受け取る。テストは、受け取った全体の末尾が 100 の行であること、埋めのバイトの数が書いた数と一致することで確かめる（埋めのバイトは実際の応答には現れないテスト用の前置きである）。Linux で送りのバッファの自動の拡大がある場合、埋める量が数 MiB になりうるが、`WouldBlock` まで書くだけなので時間は短いと見込む（測っていない）。本番の経路（`accept` から `Connection::advance` へ）の外で `Connection` を直接作るので、`Listener` の中の接続の並びに入れて `accept` を呼ぶ形にするかを、実装のときに決める。
- **T-b: 書き込みの部品を差し替える。** `WriteBuffer::advance` の引数を `&mut impl Write` にし、`Connection` に `#[cfg(test)]` の欄（例: 次の書き込みで受け付けるバイト数の並び、`Listener` の `injected` と同じ形）を足して、100 の書き込みを「数バイトだけ受け付け、次は `WouldBlock`」にする。
  - 長所: 決定的で、OS に依存しない。部分書き込み（途中まで書いた後の続き）の位置を細かく確かめられる。
  - 短所: 本番の型にテストのための欄と分岐が入る。差し替えた `WouldBlock` の後もソケット自体は書けるので、(3) の `WRITABLE` の待ちは実際には待たずにすぐ起きる。読み込みは `mio::net::TcpStream` のままなので、読みと書きを分けて差し替えるには `Connection` の作りの変更が大きくなる。
- **T-c: 送りのバッファを小さくする（`SO_SNDBUF`）。**
  - 長所: 本番のコードを変えない。
  - 短所: OS が下限を設けたり値を倍にしたりするので（OS ごとの規則は確かめていない）、100 の 25 バイトより小さくはできず、結局は T-a と同じ埋めが要る。`rustix` に `net` の機能を足すか、別のクレートが要る。T-a より得るものがない。
- **T-d: 単体テストを `WriteBuffer` の段に限る。** `WriteBuffer::advance` を `impl Write` にして、少しずつしか受け付けない書き手で部分書き込みを確かめる。
  - 長所: 小さい。
  - 短所: 経路の要点（(1)〜(3)、読み込みを止めること）を確かめないので、H2 の所見 3 の不足を埋めない。

推奨は T-a である。所見 3 が問題にしたのは、OS の `WouldBlock` で待って `WRITABLE` で戻る経路が通らないことであり、T-a はその経路を本番のコードのまま通す。バッファの大きさへの依存は「`WouldBlock` まで書く」ことで外せる。

## 4. 設計者に決めてもらう問いの候補

- **Q1 応答から除く接続ごとのヘッダ**
  - 選択肢: H-a 今のまま／H-b `keep-alive`・`proxy-connection`・`te`・`upgrade` と `connection` に挙げた名前も除く／H-c H-b のうち `upgrade` は残して `connection: upgrade, close` を送る。
  - 推奨: H-b。
  - 理由: 処理系は必ず接続を閉じ、切り替えをしないので、これらのヘッダは接続の実際と食い違う。`connection: close` で置き換える以上、`Upgrade`・`Keep-Alive` を残すと RFC 9110 §7.6.1・§7.8 の送り手の MUST に合わない。代わりに 426 の応答に `Upgrade` を付けられなくなる。
- **Q2 パスが空の `OPTIONS` の絶対形**
  - 選択肢: O-a 今のまま `/`／O-b 方法が `OPTIONS` でパスもクエリも空なら `*`／O-c 方法を問わず `*`。
  - 推奨: O-b。
  - 理由: RFC 9112 §3.3 で `OPTIONS *` と同じ対象 URI になり、§3.2.4 の中継の変換と同じ結果を handler に渡せる。`*` を `OPTIONS` 以外で使うことは RFC 9110 §7.1 が禁じる。
- **Q3 要求の対象の `#`**
  - 選択肢: F-a 400／F-b 取り除く（`hyper`・nginx と同じ）。
  - 推奨: F-a。
  - 理由: `#` は要求の対象の文法に合わず、RFC 9112 §3.2 は文法に合わない要求の行を 400 にし、直して処理しないことを勧める。設計原則 1 にも合う。
- **Q4 要求の対象の文法の検査を広げるか**（この TODO の外の関連）
  - 選択肢: (a) この改造では `#` だけを扱い、ほかは docs/todo の新しい項目にする／(b) この改造で、起点形が `/` で始まらない対象（`OPTIONS` 以外の `*`、`CONNECT` 以外の authority の形を含む）と、`httparse` が通す文法の外の文字（`"`・`<`・`>`・`\`・`^`・`` ` ``・`{`・`|`・`}`）も 400 にする。
  - 推奨: (a)。
  - 理由: 範囲が広がると、利用者から見える変更（400 になる要求）が増え、既存のテスト（`CONNECT h:443`、`OPTIONS *`）との関係も整理が要る。TODO-202 の範囲で `#` を決め、残りは項目にして別に検討する方が見落としが少ない。
- **Q5 `100-continue` の待ちの経路のテストの作り方**
  - 選択肢: T-a 送りのバッファを `WouldBlock` まで埋める／T-b 書き込みの部品を `#[cfg(test)]` で差し替える／T-d `WriteBuffer` の段だけ。
  - 推奨: T-a。
  - 理由: 本番のコードを変えずに、OS の `WouldBlock` と `WRITABLE` の登録の経路を通せる。バッファの大きさに依存しない。

## 5. 作業の分け方の案

どれも `crates/benitoite/src/runtime/io/http.rs` とその単体テストに閉じた小さな変更なので、Codex に渡す作業は一つにまとめ、内部で次の順に進めることを勧める（改造の作業を一つずつ直列に進め、重い検査を最後に一度だけ行う、これまでの運用に合わせる）。分けるなら、W1〜W3 と W4 の二つにする。

- **W1 除くヘッダ（Q1）**: `replaced_response_header` を、`connection` の値に挙げた名前を含めて判定する形に変える。完了の条件: tests.rs 343 行のテストの期待を新しい規則に変え、`Connection: x-foo` → `X-Foo` を除く、空の要素と空白、大文字と小文字の混在の場合を足して通る。
- **W2 `OPTIONS` の絶対形（Q2）**: `origin_target` に方法を渡し、パスもクエリも空の `OPTIONS` の絶対形を `*` にする。完了の条件: tests.rs 282 行の表に 3.2 の場合を足して通る。
- **W3 `#`（Q3）**: 要求の対象が `#` を含めば 400 にする。完了の条件: tests.rs 282 行のテストの 400 の並びに 3.3 の場合を足して通る。
- **W4 待ちの経路のテスト（Q5）**: T-a のテストを tests.rs に足す。完了の条件: 1 の (1)〜(5) を確かめ、テストを `cfg(unix)` にするかを決める（ループバックの TCP は Windows でも動くが、処理系の対象の OS に合わせる）。テストが 10 秒を超えないことを確かめる（AGENTS.md「テストの運用」）。test-audit の作成時の関門を通す。
- **共通**: コメントに根拠（RFC の節と `（設計書 03-09「サーバの接続と要求の読み方」）`）を書く。03-09・利用者向けリファレンス・CHANGELOG を同じ変更で直す（6 節）。
- 走らせる関係のテスト: `cargo test -p benitoite --lib runtime::io::http`、`cargo test -p benitoite --test l30_http_server`（統合テストの期待が変わらないことの確認。161 行の `CONNECTION: keep-alive` は、挙げた名前 `keep-alive` のヘッダがないので出力は変わらない見込み）、`--test l31_http_serve_and_helpers`、`--test golden`（`testdata/network/`）。最後に `scripts/check.sh`（走らせる前に `--dry-run` で選ばれる検査を設計者に知らせる）。`spec_examples` は 01-spec を変えないので要らない見込み。

## 6. 影響する設計書・テスト

- 設計書
  - `docs/design/03-interop/03-09-network.md`「サーバの接続と要求の読み方」: 絶対形の項（125 行。`OPTIONS` の例外と `#` の 400）、応答のヘッダの項（132 行。除く名前の一覧と理由）。
  - `docs/design/02-impl/02-09-runtime.md`: HTTP のサーバの規則は 03-09 を参照する形で、直す箇所は見つけていない。
- 利用者向けの文書
  - `docs/reference/benitoite.md` 808 行（`drops transfer-encoding and trailer from your headers`）。除く名前を足す。`#` と `OPTIONS` の扱いは、今のリファレンスが要求の対象の細部を書いていないので、書くかを決める。
  - `docs/ja/reference/` の訳は、リリースのときに訳し直す（AGENTS.md の決まり）。
  - 同梱の Skill の `references/` が `Http.respond` の説明を含むかは確かめていない。標準ライブラリのソースの文書のコメントを変えた場合は `gen_skill` で作り直す。
- CHANGELOG（`CHANGELOG.md` の Unreleased）
  - `#` の 400 と、`connection` に挙げた名前などを送らなくなることは、利用者から見える変更である。前の改造の書き方（400 は「Incompatible changes」の表の 33 行、除くヘッダは「Fixed」の 51 行）に揃える。
- テスト
  - `crates/benitoite/src/runtime/io/http/tests.rs`: 282 行（要求の対象）、343 行（除くヘッダ。期待が変わる）、新しい待ちの経路のテスト。
  - `crates/benitoite/tests/l30_http_server.rs`: 期待は変わらない見込み（161 行の `RESPOND` と 215 行の `100-continue`）。
  - `crates/benitoite/tests/l32_http_client.rs` はクライアントのテストで、影響しない。
- docs/todo
  - TODO-202 を閉じる。Q4 を (a) にするなら、要求の対象の文法の検査（`/` で始まらない対象、文法の外の文字）を新しい項目にする。
