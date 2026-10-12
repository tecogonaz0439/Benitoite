# 作業 H2 のコードレビュー

Opus のサブエージェントが行ったレビューである。サブエージェントがファイルを書けなかったので、オーケストレータが返答から写した（一部を縮めた）。

## 対象と方法

- 対象: ブランチ `impl/hardening-H2` の、基準 150ecc9 からコミット 9d0c57b までの差分（`src/runtime/io/http.rs` +116/−28、`src/runtime/io/http/tests.rs` +298、`tests/l30_http_server.rs` +44/−13）。
- 方法: 差分と周りのコード（`Connection::advance`、`accept`、`RequestReader::advance`、`arm`、`Registration::arm`、`WriteBuffer::advance`、`error_response`）を読み、依頼文、事前点検の補足、`decisions.md` の Q17・Q18、設計書 03-09 と照らした。rustix 1.1.5 の `Errno` の定数と cfg・`from_io_error`・`raw_os_error`、httparse 1.10.1 の `parse_headers` をソースで確かめた。
- 走らせた検査（このときは TCP を開けた）: `cargo test -p benitoite --test l30_http_server`（11 件）、`cargo test -p benitoite --lib runtime::io::http`（13 件）、`cargo test -p benitoite --test golden`（`testdata/network/` を含む）、`l31_http_serve_and_helpers`・`open_062_http`・`http_exchange_release`・`http_descriptor_exhaustion`、clippy、fmt。すべて通った。
- 直す前に落ちることは、コードから確かめた（Host の誤りと NUL 入りのトレーラは 200、絶対形の `path` は元のまま、100 を待つ `read_exact` は期限で失敗する）。
- Linux だけの部分はコンパイルしていない。8 つの定数は linux_raw と libc のどちらの裏側でも Linux で定義され、`Errno` は `Copy`・`PartialEq` を導出し、`ConnectionAborted`・`ConnectionReset` や資源の不足の値と重ならないので、読んだ限りでは型の誤りはない。

## 所見

要修正の所見はない。

### 1. 絶対形の対象で、空の authority と userinfo を受け付ける（望ましい）

- 場所: `src/runtime/io/http.rs` 986 行付近の `origin_target`。
- 問題: `http://`・`http:///p`・`http://?x=1` はそれぞれ `/`・`/p`・`/?x=1` に、`http://user:pass@h/p` は `/p` になる。RFC 9110 §4.2.1 は空の host を持つ `http` URI を不正として拒むことを求め（MUST）、§4.2.4 は信頼できない送り手の URI の userinfo を誤りとして扱うことを勧める（SHOULD）。
- 直し方の案: authority（scheme の後から最初の `/` か `?` の前まで）が空か、`@` を含めば 400 にする。Host と同じ文字の集合で確かめてもよい。単体テストに `http://` と `http://u@h/p` を足す。

### 2. `100-continue` の単体テストの期待が、表の外の式から導かれている（望ましい）

- 場所: `src/runtime/io/http/tests.rs` 104 行。
- 問題: `advance()` が `NeedMore` と `Complete` のどちらを返すべきかを、`framing` と `body` の文字列を調べる式で決めている。test-audit の「期待値を実装と同じ規則で計算しない」に当たる。
- 直し方の案: 期待する段階を表の欄（小さな列挙など）にする。

### 3. 「100 を書き切れなかった」経路を確かめるテストがない（参考）

- 場所: `Connection::advance` の `interim` の `Ok(false) => return ConnectionStep::Waiting`、`arm` の 1212 行付近。
- 問題: 状態機械は読んだ限り正しい（100 を書き切るまで読み込みを進めず、二度送らず、413 では送らず、相手が待たずに本体を送っても 100 の後に読む）。ただし `WouldBlock` で待って `WRITABLE` で戻る経路は、どのテストも通らない。
- 直し方の案: OS のバッファの大きさに依存するので、今はテストを足さず、未検査であることを記録に残す。

### 4. 新しい規則のコメントが理由と根拠を示していない（参考）

- 場所: `http.rs` 848 行付近の Host の検査、886 行付近の `send_continue` の条件、986 行付近の `origin_target`。
- 直し方の案: 理由（HTTP/1.0 の Host、RFC 9110 §10.1.1、RFC 9112 §3.2.2）と `（設計書 03-09「サーバの接続と要求の読み方」）` の参照を足す。設計書の反映で、03-09 と 02-09 にこれらの規則と Linux の errno を書く。

### 5. `Content-Length` の桁あふれの扱いを変えたことで、拒否の理由の順が変わった（参考）

- 場所: `length = Some(value.parse::<u64>().unwrap_or(u64::MAX));`。
- 問題: 桁あふれした `Content-Length` と `Transfer-Encoding: chunked` を両方持つ要求などが、413 でなく 400 になる。RFC 9112 §6.3 に照らすと 400 が自然で、退行ではない。
- 直し方の案: コードは変えない。拒否の理由の順（431、400、413）を 03-09 に書くかを判断する。

### 6. `OPTIONS` の絶対形でパスが空のときに `/` になる（参考）

- 場所: `origin_target`。
- 問題: RFC 9112 §3.2.4 は、パスが空の `OPTIONS` の絶対形を `*` の要求として扱う例を挙げる。
- 直し方の案: 今は変えず、必要になったら docs/todo の項目にする。

### 7. 要求の対象の `#` の扱いが一定しない（参考）

- 場所: `origin_target`。
- 問題: httparse は要求の対象に `#` を許すので、`http://h/p#f` は `/p#f`、`http://h#f` は `/` になる。起点形の `/p#f` を残すのは直す前からの振る舞いである。
- 直し方の案: 断片を含む対象を 400 にするか取り除くかを、後で決める（docs/todo の項目）。

### 8. トレーラの解析は、読むたびに入力の全体を解析し直す（参考）

- 問題: 1 バイトずつ送る相手には最悪で 64 KiB の二乗に比例する手間がかかるが、頭の解析も同じ形で、退行ではない。
- 直し方の案: 変えなくてよい。

## 総評

依頼の五つ（Host の数と値、トレーラ、絶対形、`100-continue`、受け付けの errno）は事前点検の補足のとおりに実装され、統合テストはこの環境ですべて通った。直すなら、空の authority と userinfo を拒むこと（所見 1）と、単体テストの期待を表の欄にすること（所見 2）を勧める。
