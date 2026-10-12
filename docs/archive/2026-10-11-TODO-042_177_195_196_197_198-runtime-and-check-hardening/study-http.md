# 調査: HTTP サーバの応答の組み立てと、要求の検査（TODO-198）

本書は、`todo-items.md` の TODO-198 の全項目（HTTP-01〜04、Host とトレーラの検査、`accept` の警告の書き出し、接続と要求の細部）について、今のコードで成り立つかを確かめ、直し方の案と影響を示す。

- 調べた版: `san_benito` の `1f951aa`。
- 方法: コードを読み、`cargo build -p benitoite`（debug）で作った `target/debug/benitoite` に、再現用の `.bnt`（応答を道ごとに変えるサーバ）と Python の `socket`・`http.client` で生の要求を送って確かめた。再現のファイルはリポジトリの外（`/private/tmp/claude-501/http-study/` の `server.bnt`・`probe.py`・`probe2.py`）に置いた。`cargo test` と `scripts/check.sh` は走らせていない。
- 行番号の起点: `src/` は `crates/benitoite/src/`、`tests/`・`testdata/`・`skill/` は `crates/benitoite/` を起点とする。行番号は `1f951aa` のものである。
- 「（推測）」は、読んだだけで実行していない箇所に付ける。「（未確認）」は、一次資料で確かめていない外部の事実に付ける。
- 外部のレビューの資料は `docs/todo/sources/2026-10-10-security-review/evidence/`（`REVIEW_JA.txt` の「HTTP の詳細所見」と `http/`）である。

## 要点

- HTTP-01・HTTP-02・Host とトレーラの検査は、すべて実際の通信で再現した。応答は `transfer-encoding: chunked` と `content-length` を両方持ち（利用者が直接書いた場合と、`Http.get` の結果をそのまま返す中継の場合の両方）、Python の `http.client` は `IncompleteRead` で読めなかった。HEAD・204・205・304・100・101 の応答と、CONNECT への 2xx に本体と `content-length` を付けて送る。Host のない HTTP/1.1 の要求、Host が二つの要求、Host の値に空白と `/` を含む要求に 200 を返す。トレーラの行は NUL・制御文字・`content-length` の名前を含んでも受け付ける（頭のヘッダは `httparse` が厳しく検査し、空白付きの名前や NUL を 400 で拒む）。
- HTTP-03・HTTP-04 は、コードを読んで成り立つことを確かめた（実行はしていない。レビューは確保の回数と記録の件数を観測器で測った）。HTTP-04 は、02-09「タスクの待ちと取り消し」が「イベントループの待ち受けの登録を外す」と定めているのに、実装が外していない食い違いでもある。
- 接続と要求の細部: 431 の応答は理由句が空（`HTTP/1.1 431 \r\n`）で、RFC 9112 の文法には合うが、処理系自身が出す状態コードなので RFC 6585 の句を表に足すのがよい。`Expect: 100-continue` の要求には 100 を送らず本体を待つ（再現した）。RFC 9110 §10.1.1 は、本体を待たずに 100 か最終の応答を送ることを求める。Linux の `accept` が返す接続ごとの errno（`ENETDOWN` など）は、待ち受けの失敗として `Http.accept` の `Result.Error` になり、`Http.serve` を終える（読んだだけ。Linux では試していない）。
- `accept` の警告は、標準エラーが詰まると出力の口の預かりの列に積まれ、捨てる手段がない（読んだだけ）。資源の不足の連続ごとに一行なので速くは増えないが、上限はない。
- 直し方はどれも `src/runtime/io/http.rs` と `src/builtins/funcs/http_server.rs` が中心で、HTTP-04 だけが `src/vm/dispatch/tasks/io.rs` と `src/runtime/io/ops.rs` に触れる。`Task.withTimeout` の担当とはコードのファイルは重ならない見込みだが、02-09「タスクの待ちと取り消し」の節を両方が直す。

## 所見ごとの調査

### HTTP-01 応答の `Transfer-Encoding`

#### 所見の確かめ

成り立つ。`src/runtime/io/http.rs` の `response_bytes`（917 行〜）は、利用者のヘッダのうち `content-length` と `connection` だけを除き（933 行、946 行）、本体の長さの `content-length` と `connection: close` を末尾に付け、本体をそのまま後ろに付ける。`transfer-encoding` と `trailer` は残る。`src/builtins/funcs/http_server.rs` の `respond`（94〜102 行）の文字の検査は、名前が token か、値に制御文字がないかだけを見るので、`Transfer-Encoding: chunked` は通る。

再現（debug、直接呼び出しの方式）:

- `Http.Response(status: 200, headers: [Pair("Transfer-Encoding", "chunked"), Pair("Trailer", "x-a")], body: ...)` を返すと、`Transfer-Encoding: chunked`・`Trailer: x-a`・`content-length: 5` の応答に `hello` が続いた。`http.client` は `IncompleteRead(0 bytes read)`。
- 上流（Python の `http.server`）が `Transfer-Encoding: chunked` で `hello` を返し、`.bnt` が `Http.get` の結果をそのまま `Http.respond` に渡す中継では、`transfer-encoding: chunked` と `content-length: 5` の応答になり、同じく `IncompleteRead`。

RFC 9112 §6.2 は「A sender MUST NOT send a Content-Length header field in any message that contains a Transfer-Encoding header field.」と定める（確かめた）。

#### 直し方

本体を固定長で送る今の形では、`transfer-encoding` と `trailer` も処理系が決めるヘッダとして除く（`response_bytes` の除く名前の判定を一つの補助の関数にまとめ、長さの計算と書き出しの二か所で同じものを使う）。TE の値を検査して残す案は、chunked の符号化を実装しない限り直らないので採らない。

ほかの接続ごとのヘッダ（`Connection` に挙げた名前、`Keep-Alive`、`Upgrade`、`Proxy-Connection`、`TE`）は、中継で上流から写りうる。RFC 9110 §7.6.1 は中継が接続ごとのヘッダを転送しないことを求める（未確認）。本体の区切りを壊すのは TE と CL の組だけなので、今回の範囲は `transfer-encoding` と `trailer` に限ることを推奨し、ほかの名前は問いの候補に挙げる。

#### 影響

- 設計書: 03-09「サーバの接続と要求の読み方」の「応答の `content-length`（本体の大きさ）と `connection: close` は、処理系が付ける。」の箇条に、`transfer-encoding` と `trailer` を除くことを加える。理由の一文（本体を固定長で送るため）を添える。
- テスト: `src/runtime/io/http/tests.rs` の `response_replaces_framing_headers_and_uses_known_reason_phrases` に TE と Trailer を加える。中継の境界（chunked の上流 → `Http.get` → `Http.respond` → 独立の解析器）は、`tests/l30_http_server.rs` か `tests/l32_http_client.rs` に、Rust の側で chunked を返す上流を立てる統合テストを一つ加える（レビューの「回帰テストは境界を一つ守ればよい」に合う）。
- 言語リファレンス・Skill: 振る舞いの記述がないので、変えなくてよい（後述の HTTP-02 で `Http.respond` の説明を足すなら、そこに含める）。
- CHANGELOG: 「Fixed」に一行。
- 大きさ: 小。

### HTTP-02 本体を持たない応答

#### 所見の確かめ

成り立つ。`respond` の組み込みの関数は状態コードが 100〜599 かだけを確かめ（`http_server.rs` 94 行）、`response_bytes` は要求の方法を受け取らず、常に本体と `content-length` を送る。要求の写し（`RequestData`。方法を含む）は、`Http.accept` が交換のリソースの添え物（`resources.attachments`）に入れており（`http_server.rs` 64〜66 行）、`respond` の時点で引ける。

再現した応答（どれも `Http.text(<状態>, "unexpected body")` か `Http.text(200, "hello")`）:

| 要求と応答 | 送ったもの | `http.client` の読み |
|---|---|---|
| GET に 204 | `content-length: 15` と本体 15 バイト | 状態 204、本体は空（余分なバイトが残る） |
| GET に 205 | 同上 | 状態 205、本体 `unexpected body` |
| GET に 304 | 同上 | 状態 304、本体は空（余分なバイト） |
| GET に 100 | 100 の頭、本体、接続を閉じる | `BadStatusLine: unexpected body` |
| GET に 101 | 101 の頭と本体 | 状態 101、本体は空 |
| HEAD に 200 | `content-length: 5` と `hello` | 状態 200、本体は空（余分なバイト） |
| CONNECT に 200 | `content-length: 5` と `hello` | 状態 200、本体 `hello` |

RFC で確かめた条文:

- RFC 9112 §6.3 の 1: HEAD への応答と、1xx・204・304 の応答は、ヘッダの後の最初の空行で終わる。2: CONNECT への 2xx の応答は、直ちにトンネルになり、クライアントは `Content-Length` と `Transfer-Encoding` を無視しなければならない。
- RFC 9110 §8.6: HEAD への応答に `Content-Length` を送ってよいが、その値が GET で送るはずの本体の長さと等しくなければ送ってはならない。1xx（と 204）の応答と、CONNECT への 2xx に `Content-Length` を送ってはならない。304 についての文は今回の取得で文面を読めなかった（未確認）。
- RFC 9110 §9.3.2: HEAD への応答に本体を送ってはならない。GET と同じヘッダを送るべきだが、本体を作って初めて決まるヘッダは省いてよい。
- RFC 9110 §9.3.6: CONNECT への 2xx に `Transfer-Encoding` と `Content-Length` を送ってはならない。
- RFC 9110 §15.2: 1xx はヘッダの終わりで終わり、本体を持たない。HTTP/1.0 のクライアントに 1xx を送ってはならない。§15.3.5: 204 も同じ。§15.3.6: 205 に本体を作ってはならない（205 の本体の長さの示し方は §15.3.6 に書かれていない。205 は §6.3 の 1 に含まれないので、受け手は `content-length` などで長さを知る）。

#### 直し方

`response_bytes` に「要求の方法から決まる性質」（HEAD か、CONNECT か）を渡し、状態コードと合わせて、本体と `content-length` の扱いを一つの表で決める。`respond` の組み込みの関数が添え物の `RequestData` から方法を読み、`response_bytes` に渡す。方法の文字列をそのまま渡すより、`enum ResponseFraming` のような小さな型を `http.rs` に置き、表を `http.rs` の一か所に閉じ込めるのがよい（テストもこの関数で表を確かめられる）。

推奨の表（問いの候補 Q1〜Q4 の推奨に従う場合）:

| 場合 | 本体 | `content-length` |
|---|---|---|
| 1xx | 送らない（`Http.respond` が実行時エラーにする） | — |
| 204 | 送らない | 送らない |
| 205 | 送らない | `0` |
| 304 | 送らない | 送らない |
| HEAD への応答（上の三つ以外） | 送らない | 渡された本体が空でなければその長さ、空なら送らない |
| CONNECT への 2xx | 送らない | 送らない（送った後に接続を閉じる） |
| そのほか | 送る | 本体の長さ |

1xx は、`Http.respond` が一度しか応答できないので、最終の応答として送れない。範囲の検査を 200〜599 に改め、100〜199 を今の 99 や 600 と同じ実行時エラー（`R0701` 引数の定義域の外）にする。1xx を返すのは要求ではなくスクリプトの書き手が決めることなので、止めて誤りを知らせてよい。一方、HEAD と CONNECT は相手が選べるので、実行時エラーにすると、一つの要求でサーバ全体を止められる（03-09「サーバ」: handler の中の実行時エラーはプログラム全体を止める）。この二つは黙って本体を落とす。

204・205・304 に空でない本体を渡したときも、黙って落とすことを推奨する（Q2）。

#### 影響

- 設計書: 03-09「サーバ」の「`Http.respond` は、応答の `status` が 100 以上 599 以下でなければ実行時エラーとする。応答の `Content-Length` は、処理系が本体の大きさから付ける。」を、200〜599 と上の表に書き換える。表は「サーバの接続と要求の読み方」に置き、「サーバ」から参照するのがよい。01-08・01-09 に状態コードの範囲の記述はない（`grep` で確かめた範囲）。
- テスト:
  - ゴールデンテスト: `testdata/network/status-below-range.bnt`（99）と `status-above-range.bnt`（600）は残る。100〜199 の誤りを守る `testdata/network/status-informational.bnt`（`.diag.json`・`.exit`・`.mode`）を加える。
  - 統合テスト: `tests/l30_http_server.rs` に、生の TCP で HEAD・204・205・304・CONNECT の表を、送ったバイトの長さで確かめるテストを一つ加える（レビューの「方法と状態の表を独立の解析器と通信の長さで確かめる」）。
  - 単体テスト: `src/runtime/io/http/tests.rs` の `response_bytes` の呼び出しを新しい引数に合わせ、表を確かめる。
- 言語リファレンス: `docs/reference/benitoite.md` の「A few behaviors worth knowing」（799 行の表の後）にサーバの振る舞いの箇条がない。`Http.respond` の状態コードの範囲と、HEAD・204・304 で本体を送らないことを一つ足す。
- 標準ライブラリのソース: `src/prelude/stdlib/Network/Http.bnt` の `respond` の説明（16 行）に、状態コードの範囲と本体を送らない場合を足す。`skill/references/stdlib/Network.Http.md` は生成物なので `cargo run -p benitoite --example gen_skill` で作り直す。
- CHANGELOG: 1xx を実行時エラーにするのは互換でない変更なので、「Incompatible changes」の二つ目の表（関数の振る舞いの変更）に一行。本体を落とす点は「Fixed」に一行。
- 大きさ: 中。

### Host とトレーラの検査

#### 所見の確かめ

成り立つ。`RequestReader::advance` の頭の処理（`http.rs` 701〜788 行）は、`httparse` で頭を読んだ後、`content-length` と `transfer-encoding` だけを特別に扱い（752〜772 行）、`host` の数も形も確かめない。要求の版（`request.version`）も見ていない。トレーラ（846〜869 行）は、行の長さの合計と、行に `:` を含むかだけを確かめる（863 行）。

再現:

| 要求 | 応答 |
|---|---|
| HTTP/1.1 で Host なし | 200 |
| Host が二つ（`a` と `b`） | 200（`Http.Request.headers` に `host=a` と `host=b` の二つ） |
| Host の値が `a b/c` | 200 |
| Host の値が空 | 200 |
| HTTP/1.0 で Host なし | 200（これは正しい） |
| トレーラの行が `\x00:x` | 200 |
| トレーラの行が `X: \x01` | 200 |
| トレーラの行が `x :y`（名前の後に空白） | 200 |
| トレーラの行が `Content-Length: 99` | 200（トレーラは捨てるので本体は変わらない） |
| 頭のヘッダの値に NUL | 400（`httparse` が拒む） |
| 頭のヘッダの名前の後に空白、obs-fold | 400（`httparse` が拒む） |

RFC 9112 §3.2 は、Host のない HTTP/1.1 の要求、Host が二つ以上の要求、Host の値が正しくない要求に 400 で応えなければならないと定める（確かめた）。RFC 9110 §5.5 は、CR・LF・NUL を含む欄の値は正しくなく、受け手は要求を拒むか空白に置き換えなければならないとする（確かめた）。RFC 9112 §7.1.2 のトレーラの文法は `trailer-section = *( field-line CRLF )` で、頭のヘッダと同じ `field-line` である（確かめた）。名前と `:` の間の空白を 400 で拒む規則は RFC 9112 §5.1 にある（未確認）。

付随して見つけた点: 対象が絶対形（`GET http://evil/echo HTTP/1.1`）の要求は、`Http.Request.path` が `http://evil/echo` のまま handler に渡る（再現した）。RFC 9112 §3.2.2 は、サーバが絶対形を受け付けなければならず、そのとき受け取った Host を無視して対象の authority を使うと定める（確かめた）。今の実装は受け付けているが、パスに scheme と authority が混じるので、`Http.pathSegments` は `["http:", "evil", "echo"]` を返す（推測）。

#### 直し方

- Host: 頭のヘッダを読む繰り返しで `host` の数を数える。`request.version == Some(1)`（HTTP/1.1）で数が 1 でなければ 400。HTTP/1.0 で Host がないものは受け付け、二つ以上なら 400 とする（§3.2 の「more than one Host」は版を問わない文なので）。値の形は、RFC 3986 の `uri-host [ ":" port ]` を厳密に解析するより、使える文字の集合（英数字、`-._~`、sub-delims、`:`、`[`、`]`、`%`）だけを確かめる軽い検査を推奨する（Q9）。空の値は受け付ける（RFC 9112 §3.2 は、対象に authority がないとき空の Host を送るとする。未確認）。
- トレーラ: 空行までのトレーラの部分を集め、`httparse::parse_headers`（`httparse` 1.10.1 にある。確かめた）で、頭のヘッダと同じ規則とヘッダの数の上限（100）で検査する。行ごとに `:` を探す今の処理を置き換える。トレーラは今までどおり捨てる。
- 絶対形: 問いの候補 Q10 とする。推奨は、`scheme://authority` を外して起点からのパス（origin-form）にすることである（小さい）。

#### 影響

- 設計書: 03-09「サーバの接続と要求の読み方」に、Host の数と形の規則（400）、トレーラを頭のヘッダと同じ規則で検査して捨てること、（Q10 を採るなら）絶対形の扱いを足す。「失敗の種類」の「HTTP として正しくない要求」は 400 のままで足りる。
- テスト: `tests/l30_http_server.rs` の `invalid_and_slow_connections_do_not_stop_the_same_accept`（214 行〜）が不正な要求を並べて同じ `accept` が続くことを確かめているので、ここに Host なし・Host 二つ・NUL 入りのトレーラを足すのが安い。`RequestReader` の単体テストを `src/runtime/io/http/tests.rs` に足してもよい（test-audit の関門で、どちらか一方にする）。
- 言語リファレンス・Skill: 変えなくてよい。
- CHANGELOG: 「Fixed」に一行（Host のない HTTP/1.1 の要求などに 400 を返す）。
- 大きさ: 小〜中。

### HTTP-03 再開のたびの応答の作り直し

#### 所見の確かめ

コードを読んで成り立つことを確かめた（実行していない。レビューは 4 MiB の応答で、応答の全体の領域の確保が 1 回から 3 回になったことを測った）。

- 書き込みの待ち（`IoWait::Readiness { interest: Writable }`、`http_server.rs` 105 行）から戻ると、`src/vm/dispatch/tasks/io.rs` の `retry_request`（738 行〜）が同じ組み込みの関数をもう一度呼ぶ。
- `respond`（`http_server.rs` 91〜110 行）は、呼ばれるたびにヘッダを `read_pairs` で `String` に写し、文字を検査し、`http::response_bytes` で応答の全体のバイト列を作る（102 行）。
- `http::respond`（`http.rs` 621 行〜）は、`exchange.response.is_none()` のときだけ受け取ったバイト列を保存し（638 行）、二回目からは捨てる。

#### 直し方

`http.rs` に、既に書きかけの応答があるかを先に調べて続きを書く関数（たとえば `http::resume(table, id, owner) -> Result<Resume, Stop>`。`Resume` は「まだ始めていない」か「続きを書いた結果」）を置き、組み込みの関数は、まだ始めていないときだけ検査と組み立てをして、今の `http::respond` に渡す。二回目の呼び出しの引数は一回目と同じ値（枠のレジスタに残っている）なので、検査を省いても結果は変わらない。`response_owner` による二度の応答の検査は、`resume` の入口にも置く。

閉包で組み立てを遅らせる案（`http::respond` に `FnOnce() -> Result<Vec<u8>, Stop>` を渡す）は、組み立てに `ctx`（ヒープの値の読み出し）が要り、`ctx.services()` の借用と重なるので採りにくい。

#### 影響

- 設計書: 03-09 と 02-09 に、この内部の手順の記述はない。直しても設計書は変えなくてよい（02-09「一つの操作で作る値の大きさの上限」の検査を最初の呼び出しだけで行うことは、今の記述と食い違わない）。
- テスト: 確保の回数を数える観測器（レビューの `alloc_observer.rs`）はリポジトリにない。単体テストとして、`src/runtime/io/http/tests.rs` に、送り手の領域を小さくした接続の組で `respond` が待ちを返した後、`resume` がバイト列なしで続きを書き終えることを確かめるものを一つ置く案がある。公開の振る舞いが変わらない直しなので、テストを足すかは test-audit の関門で決める（足さない場合も、既存の部分送信のテストが続きの正しさを守る）。
- CHANGELOG: 利用者に見える変化は大きな応答の確保の量だけなので、「Fixed」に一行か、書かない。
- 大きさ: 小〜中。

### HTTP-04 取り消した待ちの記録の残り

#### 所見の確かめ

コードを読んで成り立つことを確かめた（実行していない。レビューは観測器で、同じ listener に `Task.withTimeout(1, ...Http.accept...)` を 10,000 回繰り返して、配送先を外した準備の記録が最大 9,960 件残ったことを測った）。

- 取り消しを反映する `reflect_cancellation`（`src/vm/dispatch/tasks/io.rs` 41 行〜）は、タスクの操作の再試行のタイマーを外し（57〜62 行）、`rt.ops.detach_task(task)`（64 行）で配送先だけを外す。`src/runtime/io/ops.rs` の `detach_task`（131 行〜）は `deliver_to` を `None` にするだけで、記録を消さない。
- 準備のトークンと操作の対応（`rt.readiness.tokens`・`op_tokens`・`resources`・`resource_ops`）を外し、最後の待ちならリソースの登録を外す `clear_ready`（765 行〜）は、その操作の準備のイベントが来たとき（638 行）か、再試行のタイマーが満了したとき（`expire_retry`、844 行）にしか呼ばれない。
- `resource_ops` に取り消した操作が残るので、listener の `mio` の登録も外れない。次の `Http.accept` は同じトークンに新しい操作を足す（`Registration::arm` は登録があれば同じトークンで登録し直す。`http.rs` 151〜152 行）。
- テスト `src/vm/dispatch/tasks/io/tests.rs` の `readiness_deduplicates_live_operations_and_discards_stale_tokens`（1349 行〜）は、取り消しの後に記録が残ること（1386〜1387 行）を期待している。

02-09「タスクの待ちと取り消し」は、取り消しで「登録していたタイマーと、イベントループの待ち受けの登録を外す」と定め、記録を残すのは「作業用のスレッドで続いている操作」としている。実装は準備の待ちにも作業用のスレッドの規則を当てており、設計書と食い違う。

#### 直し方

`reflect_cancellation` の、取り消したタスクごとの繰り返しで、`rt.ops.task_operations(task)` の操作のうち種類が `OpKind::Readiness` のものに `clear_ready` を呼び、記録を消す。`clear_ready` は、同じリソースにほかの生きた待ちが残っていれば登録を残し、最後の待ちならリソースの `unwatch_readiness` と `http::disarm` を行うので、レビューの「同じ listener にほかの生きた待ちがあれば登録は残す」をそのまま満たす。そのうえで `detach_task` を呼び、作業用のスレッドの操作だけに配送先を外す印を残す。

必要な変更:

- `src/runtime/io/ops.rs` に、準備の待ちの記録を消す公開の関数（`remove` は非公開。`pub(crate) fn remove_readiness(op)` など）を足す。消す前に種類が `Readiness` で `lent` がないことを確かめ、違えば `Stop::Internal` にする。
- `reflect_cancellation` は今 `()` を返す。`clear_ready` が `Result` を返すので、`Result<(), Stop>` に変え、呼び出し元（`boundary` の 3 か所）で `?` を付ける。
- 遅れて届いた古いイベントは、`ready_for_tokens` の `ready.retain(|op| rt.ops.records.contains_key(op))`（825 行）が捨てるので、`check_completion` が記録のない操作を処理系の不具合にする経路には入らない。`expire_retry` も記録の有無を先に調べている（840 行）。
- 止める手順の枝（`expire_io`、44〜55 行）は、すべての記録の配送先を外すだけで実行の終わりまで残る。実行がすぐ終わるので今回は変えなくてよいが、同じ規則にそろえるなら、ここでも準備の記録を消す（推奨は変えないこと。止める手順の振る舞いに触れる範囲を広げないため）。

#### 影響

- 設計書: 02-09「タスクの待ちと取り消し」の三つ目の箇条（作業用のスレッドの操作の記録を残す）に、準備の待ちの記録は取り消しのときに消し、同じリソースの最後の待ちならイベントループの登録も外すことを一文で足す。`http.rs` の `ReadinessState` のコメント（967 行、「取り消しでは配送先だけを外し、準備の後に登録を手放す」）も直す。
- テスト: `src/vm/dispatch/tasks/io/tests.rs` の上記のテストの取り消しの側を、記録とトークンの対応が消えることを期待する形に改める。同じ listener への取り消しの繰り返しで、記録の数が生きた待ちの数を超えないことを確かめる回帰テストを一つ足す（`src/vm/dispatch/tasks/tests/cancellation.rs` の仮の IO の仕組みで書けるかは、実装のときに確かめる）。
- 言語リファレンス・Skill: 変えなくてよい。
- CHANGELOG: 「Fixed」に一行（`Task.withTimeout` で `Http.accept` を繰り返し取り消しても、内部の記録が溜まらない）。
- 大きさ: 中。

### `accept` の警告の書き出し（要確認）

#### 所見の確かめ

コードを読んで成り立つことを確かめた（再現していない）。

- `Http.accept` の組み込みの関数は、`http::accept` が返した警告を `view.write_output(Stream::Stderr, ...)` で書き、返った値（容量の待ち `IoWait::Output`）を `drop` で捨てる（`http_server.rs` 71 行）。
- `src/runtime/io/output.rs` の `OutputPort::write`（110〜121 行）は、容量が足りないか預かりの列が空でないとき、書く内容を写して預かりの列 `deferred` に積み（116 行）、`Deferred` を返す。積んだものは、書き手のタスクが待たなくても列に残る。列の長さに上限はない。
- 警告は資源の不足の連続の最初の一回だけ出る（`Listener::retry`、`http.rs` 466〜467 行。`retry_millis` が最初の値のときだけ）。連続は受け付けか登録が成功すると終わる（378 行、1067 行）。したがって、標準エラーが詰まったまま「不足 → 回復 → 不足」が繰り返されると、一回に一行ずつ積まれる。再試行の最短の間隔は 5 ミリ秒なので、増え方は最大でも毎秒 200 行程度である（推測）。
- 受け付けのタスクを取り消すと `stderr.cancel_pending(task)`（`tasks/io.rs` 69 行）が、そのタスクの預かりを捨てる（推測。`cancel_pending` の中身は読んでいない）。`Http.serve` の受け付けのタスクは取り消されないので、この経路では捨てられない。

#### 直し方

警告は、利用者に資源の不足を知らせるための補助であり、届かなくても処理は正しい。推奨は、出力の口に「容量があるときだけ書き、なければ捨てる」関数（`OutputPort::write_if_room` など）を足し、`accept` の警告はそれで書くことである。`IoView` の `write_output` と並ぶ関数を `src/runtime/io/services.rs` に足す。

代わりの案は二つある。(a) 預かりの列に警告の行を一つまでしか置かない（listener ごとの印）。(b) 警告を書いたら容量の待ちを返し、`accept` を待たせる。(b) は受け付けを止めるので採らない。(a) は捨てる案より状態が増える。

#### 影響

- 設計書: 03-09「失敗の種類」の「資源の不足で続けて失敗し始めたときに一度だけ、処理系は失敗の理由を標準エラー出力に一行書く。」に、標準エラーに書けないときは捨てることを足す。02-09「出力のバッファ」に、処理系が書く警告の例外を一文足すかは、実装のときに決める。
- テスト: `src/runtime/io/http/tests.rs` の `shortage_retries_use_vm_timers_and_one_warning_in_both_modes`（187 行〜）の近くに、詰まった出力で警告が積まれないことを確かめるテストを足す案がある。出力の口の単体テストは `src/vm/dispatch/tasks/io/output_tests.rs` にある。
- CHANGELOG: 書かなくてよい（再現していない内部の強化）。書くなら「Fixed」に一行。
- 大きさ: 小。

### 接続と要求の細部（要確認）

#### 所見の確かめ

1. 接続ごとの errno: `http::accept` の受け付けの繰り返し（`http.rs` 383〜403 行）は、`Interrupted` と `WouldBlock`、`ConnectionAborted`・`ConnectionReset`（392〜396 行）、資源の不足（`resource_shortage`、481 行〜。`EMFILE`・`ENFILE`・`ENOBUFS`・`ENOMEM`）だけを分け、ほかはすべて待ち受けの失敗（401 行）として `Http.accept` の `Result.Error` にする。`Http.serve` はそこで終わる。Linux の `accept(2)` の man ページは、「Linux accept() (and accept4()) passes already-pending network errors on the new socket as an error code from accept().」とし、TCP/IP では `ENETDOWN`・`EPROTO`・`ENOPROTOOPT`・`EHOSTDOWN`・`ENONET`・`EHOSTUNREACH`・`EOPNOTSUPP`・`ENETUNREACH` を `EAGAIN` と同じくやり直すよう求める（man.archlinux.org の写しで確かめた）。macOS の `accept(2)` の man ページには、この記述がない（手元の `man 2 accept` で確かめた）。Linux では試していない。
2. 431 の理由句: `text::reason`（`http.rs` 37〜84 行）に 431 がなく、処理系が返す 431 の応答は `HTTP/1.1 431 \r\n` になる（再現した）。RFC 9112 §4 の文法は `status-line = HTTP-version SP status-code SP [ reason-phrase ]` で、理由句は省いてよく、省いても空白は送らなければならない（確かめた）ので、規格には合う。RFC 6585 §5 の句は「Request Header Fields Too Large」である（確かめた）。表のコメントは「RFC 9110 の表に揃える」としているが、431 は RFC 9110 ではなく RFC 6585 が定める。
3. `100-continue`: `Expect: 100-continue` と `Content-Length: 5` の頭だけを送ると、2 秒待っても 100 は届かず、本体を送った後に 200 が返った（再現した）。RFC 9110 §10.1.1 は、HTTP/1.1 の要求で 100-continue を受けた origin server は、直ちに最終の状態コードか 100 を送らなければならず、「The origin server MUST NOT wait for the content before sending the 100 (Continue) response.」とする。本体の一部か全部を既に受け取っていれば 100 を省いてよい。HTTP/1.0 の要求の 100-continue は無視しなければならない（確かめた）。今の実装では、curl などのクライアントは自分の待ち時間（curl は既定で 1 秒。未確認）だけ遅れてから本体を送るので、壊れはしないが遅れる。上限を超える `Content-Length` には本体を読む前に 413 を返すので、その場合は既に規格に合う。

#### 直し方

1. 接続ごとの errno: Linux では上の 8 つを、`ConnectionAborted` と同じく接続ごとの失敗として次の受け付けに進む。errno の値は OS で異なるので、`resource_shortage` と同じく OS ごとの表にする。依存に既にある `rustix` の `rustix::io::Errno` の定数で書けば、数を直接書かずに済む（`ENONET` などの定数が `rustix` 1.1.5 にあるかは未確認。なければ `libc` の定数か、設計書に出典を添えた数の表にする）。macOS では今の扱いのまま。
2. 431: `text::reason` に `431 => "Request Header Fields Too Large"` を足す。表のコメントを「RFC 9110 と RFC 6585 の表」に直す。428・429 も同じ RFC にあるので一緒に足すかは Q6。
3. `100-continue`: 推奨は、HTTP/1.1 の要求の頭に `expect: 100-continue`（大文字と小文字を区別しない）があり、本体を読む必要があり、まだ本体のバイトを受け取っていないとき、本体を読む前に `HTTP/1.1 100 Continue\r\n\r\n` を送ることである。`Connection` に送りかけの 100 を持つ欄を足し、`advance` で書き込みを試み、書き切れなければ書き込みの準備を待つ（`arm` の `interest` の決め方に、送りかけの 100 があるときは `WRITABLE` を加える）。最終の応答は `Http.respond` が後で送るので、100 は高々一度で、二度の応答の検査とはぶつからない。

#### 影響

- 設計書:
  - 03-09「失敗の種類」の表の「接続ごとの失敗」の「当たる場合」に、受け付けのときに OS が接続ごとの誤りを返した場合を足す。02-09「組み込みの操作とハンドラ表」の 94 行（資源の不足の errno を挙げる箇条）に、Linux の接続ごとの errno の一覧と出典（`accept(2)`）を足す。
  - 03-09「サーバの接続と要求の読み方」に、100-continue の扱いを足す。431 の句は設計書に書かなくてよい（実装プランの値）。
- テスト: 接続ごとの errno は、`src/runtime/io/http/tests.rs` の注入の仕組み（`Listener.injected`、テストのときだけある）で `io::Error::from_raw_os_error` を入れて確かめられる（Linux の値は `cfg` で分ける）。431 は `tests/l30_http_server.rs` の不正な要求の並びで状態の行を確かめる。100-continue は同じファイルに、頭だけを送って 100 を受け取るテストを足す。
- CHANGELOG: 100-continue と接続ごとの errno は「Fixed」に一行ずつ。431 は書かなくてよい。
- 大きさ: errno は小、431 はごく小、100-continue は中。

## 問いの候補

設計者に決めてもらう点を挙げる。RFC の根拠は、上の各節で確かめた範囲である。

- **Q1 1xx の応答**: (A) `Http.respond` は 1xx を実行時エラーにする（範囲を 200〜599 に改める）。(B) 今のまま送り、閉じる。(C) 1xx を処理系の 500 に置き換える。推奨は (A)。理由: `Http.respond` は一度しか応答できず、1xx を最終の応答として送るのは RFC 9112 §6.3・RFC 9110 §15.2 に合わない。1xx を返すのは書き手の誤りで、相手が引き起こせないので、止めて知らせてよい（設計原則 1）。(C) は誤りを隠す。互換でない変更なので CHANGELOG の「Incompatible changes」に載せる。
- **Q2 204・205・304 に空でない本体を渡したとき**: (A) 黙って本体を落とす。(B) 実行時エラーにする。推奨は (A)。理由: handler の実行時エラーはサーバ全体を止める。`Http.text(204, "...")` のような書き方は LLM が書きやすく、止めると影響が大きい。HEAD では同じ本体を必ず落とすので、規則が一つになる。設計書と `Http.respond` の説明に、落とすことを書く。
- **Q3 HEAD・304 の `content-length`**: HEAD は (A) 本体が空でなければその長さ、空なら送らない、(B) 常に本体の長さ、(C) 常に送らない。304 は (A) 送らない、(B) 本体の長さ。推奨は HEAD が (A)、304 が (A)。理由: RFC 9110 §8.6 は、HEAD の `Content-Length` が GET の本体の長さと等しくなければ送ってはならないとする。方法で分けない handler は GET と同じ本体を返すので (A) で正しい値になり、HEAD のときに空の本体を返す handler に `content-length: 0` を誤って付けずに済む。RFC 9110 §9.3.2 は本体を作って決まるヘッダを省いてよいとする。304 は表現の長さを処理系が知らないので省く。
- **Q4 CONNECT への 2xx**: (A) 本体・`content-length`・`transfer-encoding` なしで送り、接続を閉じる。(B) 要求を読む段階で 501 を返し、handler に渡さない。(C) `Http.respond` の実行時エラーにする。推奨は (A)。理由: (C) は相手が CONNECT を送るだけでサーバを止められる。(B) は handler が CONNECT に自分で 405 などを返す余地をなくす。(A) は RFC 9110 §9.3.6 に合い、クライアントはトンネルが開いてすぐ閉じたと見る。なお、CONNECT の対象（`example.com:443` の authority 形）は今も `path` にそのまま入る（再現した）。
- **Q5 `100-continue`**: (A) 本体を読む前に 100 を送る。(B) 今のまま（本体を待つ）にし、設計書に書く。(C) 417 で拒む。推奨は (A)。理由: RFC 9110 §10.1.1 は本体を待たずに 100 か最終の応答を送ることを求める。(C) は正しい要求を拒む。`100-continue` 以外の `Expect` の値は今のまま無視することを推奨する（417 で拒んでよいかの条文は未確認）。
- **Q6 431 の理由句と表の範囲**: (A) 431 だけを足す。(B) RFC 6585 の 428・429・431 を足す。(C) 足さない（理由句は省いてよいので）。推奨は (B)。理由: 431 は処理系自身が出すので句を付けるべきで、同じ RFC の 428・429 は handler がよく使う。511 も RFC 6585 にあるが、origin server が返すものではないので含めない（511 の位置づけは未確認）。
- **Q7 Linux の接続ごとの errno**: (A) `accept(2)` が挙げる 8 つを接続ごとの失敗に含め、次の受け付けに進む。(B) 今のまま待ち受けの失敗にする。(C) 資源の不足と同じく時間をおいてやり直す。推奨は (A)。理由: man ページは `EAGAIN` と同じくやり直すよう求めており、これらは受け付けた一つの接続の誤りである。(B) は Linux で一つの接続の誤りが `Http.serve` を終える。(C) は待つ理由がない。`EPERM`（Linux でファイアウォールが接続を拒んだとき、と man ページにある。未確認）を含めるかも合わせて決める。
- **Q8 `accept` の警告が書けないとき**: (A) 捨てる。(B) 預かりの列に一つまで置く。(C) 書けるまで `accept` を待たせる。推奨は (A)。理由: 警告は補助で、届かなくても処理は正しい。(C) は受け付けを止める。
- **Q9 Host の値の検査の厳しさ**: (A) 使える文字の集合だけを確かめる。(B) RFC 3986 の `uri-host [ ":" port ]` を解析する。(C) 数だけを確かめる。推奨は (A)。理由: RFC 9112 §3.2 は正しくない値を 400 で拒むことを求めるので (C) では足りない。処理系は Host を使わず、handler に渡すだけなので、区切りの文字や空白を入れさせないことが要点で、(B) の手間に見合う効果が小さい。
- **Q10 絶対形の対象**: (A) `scheme://authority` を外して `path` を起点からのパスにする。(B) 今のまま渡し、設計書に書く。(C) 今回は含めず docs/todo の項目にする。推奨は (A)。理由: RFC 9112 §3.2.2 は絶対形を受け付けることを求め、今の `path` は `Http.pathSegments` で正しく分けられない。直しは要求の読み方の数行で済む。
- **Q11 ほかの接続ごとのヘッダ**: 応答から `transfer-encoding`・`trailer` のほかに `keep-alive`・`upgrade`・`proxy-connection`・`te` と、`Connection` に挙げた名前も除くか。推奨は、今回は除かない（docs/todo の項目にする）。理由: 本体の区切りを壊すのは TE と CL の組だけで、ほかは今の「一つの接続で一つの要求」と `connection: close` の下では区切りを壊さない（推測）。条文（RFC 9110 §7.6.1）を確かめてから決める。

## 作業の大きさと重なり

| 項目 | 大きさ | 主に触れるファイル |
|---|---|---|
| HTTP-01 | 小 | `src/runtime/io/http.rs`（`response_bytes`）、`src/runtime/io/http/tests.rs`、`tests/l30_http_server.rs` か `tests/l32_http_client.rs` |
| HTTP-02 | 中 | `src/runtime/io/http.rs`、`src/builtins/funcs/http_server.rs`、`src/prelude/stdlib/Network/Http.bnt`、`testdata/network/`、`tests/l30_http_server.rs`、`skill/references/stdlib/Network.Http.md`（生成） |
| Host とトレーラ（と Q10） | 小〜中 | `src/runtime/io/http.rs`（`RequestReader`）、`tests/l30_http_server.rs` |
| HTTP-03 | 小〜中 | `src/runtime/io/http.rs`、`src/builtins/funcs/http_server.rs` |
| HTTP-04 | 中 | `src/vm/dispatch/tasks/io.rs`（`reflect_cancellation` と `boundary` の呼び出し）、`src/runtime/io/ops.rs`、`src/vm/dispatch/tasks/io/tests.rs`、`src/runtime/io/http.rs`（コメント） |
| `accept` の警告 | 小 | `src/runtime/io/output.rs`、`src/runtime/io/services.rs`、`src/builtins/funcs/http_server.rs` |
| 接続ごとの errno・431 | 小 | `src/runtime/io/http.rs` |
| 100-continue | 中 | `src/runtime/io/http.rs`（`Connection`・`arm`）、`tests/l30_http_server.rs` |

全体では中〜大である。HTTP-01・02・03 と Host・トレーラ・431・errno・100-continue は `http.rs` と `http_server.rs` に集まるので、一つの作業にまとめるか、`http.rs` の応答の側（01・02・03）と要求の側（Host・トレーラ・100-continue・errno）の二つに分けて順に行うのがよい。HTTP-04 は VM の取り消しの側で、ほかの HTTP の直しと独立に並べられる。

ほかの担当との重なり:

- `Task.withTimeout`（TODO-197）: 同じ `src/vm/dispatch/tasks/` の下だが、触れるファイルは違う見込みである。TODO-197 の直しは、子が終えた時刻と期限の比べ方で、`src/vm/dispatch/tasks/cancel.rs`（`deliver` の 295・327・348 行の `timed_out` の判定、`expire` の 199 行〜）、`src/vm/dispatch/tasks.rs`（`finish` と `boundary` の 141〜160 行のタイマーの満了）、テストの `src/vm/dispatch/tasks/tests/cancellation.rs` に触れる（推測）。HTTP-04 は `src/vm/dispatch/tasks/io.rs` の `reflect_cancellation`（41〜72 行）と、その呼び出し元の `io::boundary`（594 行〜）だけを変える。`tasks.rs` の `boundary`（141 行〜）は `io::boundary` を呼ぶだけなので、`reflect_cancellation` の戻り値を `Result` にしても `tasks.rs` は変わらない。重なりうるのは次の二つである。(1) TODO-197 が完了の判定に時計を渡すために `RunState` や `vm/state.rs` の `scheduling`（`cancelled_io`・`timed_out` がある、199 行付近）を変えると、HTTP-04 が読む `cancelled_io` と同じ構造体に触れる。(2) 設計書の 02-09「タスクの待ちと取り消し」を両方が直す（TODO-197 は `Task.withTimeout` の箇条、HTTP-04 は取り消しの三つ目の箇条）。同じ節の別の箇条なので、後に取り込む側が合わせればよい。
- `Regex` と `Opaque` の容量（TODO-196・042）: コードは重ならない。02-09 の「メモリの管理」か「一つの操作で作る値の大きさの上限」を直すなら、HTTP-03 は同じ節を変えないので重ならない。
- check の資源消費（TODO-195）: 重ならない。
- `uses` の別名（TODO-177 F-2）: `skill/SKILL.md`（手で書く）と、名前解決の診断を足すなら `skill/references/diagnostics.md`（生成物）を変える。HTTP-02 は `skill/references/stdlib/Network.Http.md`（生成物）を作り直す。`gen_skill` は references をまとめて作り直すので、取り込みの順に合わせて、後の側がもう一度 `gen_skill` を走らせる。
- 全員: `CHANGELOG.md` の「Unreleased」節（HTTP-02 は「Incompatible changes」の二つ目の表、ほかは「Fixed」）。
