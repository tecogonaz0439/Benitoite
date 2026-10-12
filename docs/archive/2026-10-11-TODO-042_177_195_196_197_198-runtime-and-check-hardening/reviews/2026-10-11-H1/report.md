# 作業 H1 のコードレビュー

Opus のサブエージェントが行ったレビューである。サブエージェントがファイルを書けなかったので、返答の全文をオーケストレータが写した。

## 対象と方法

- 対象: ブランチ `impl/hardening-H1` の、基準 375304c からコミット 2315a4b までの差分（14 ファイル、+629/−22）。
- 照らし合わせたもの: 依頼文（事前点検の補足 1〜11 を含む）、実装担当の報告、`decisions.md`（Q15・Q16・Q18）と `plan.md`（H1 の行と完了の条件）、AGENTS.md の実装の規約、スキル test-audit、RFC 9110 §8.6・§9.3.6・§15.3.6、RFC 9112 §6.3。
- 走らせたもの（このときは TCP を開けた）:
  - `cargo test -p benitoite --lib -- response_ write_if_room resume_peeks respond_status respond_headers shortage_retries`: 9 件とも通った。TCP を使う `resume_finishes_pending_response_without_replacement_bytes` も通った。
  - `cargo test -p benitoite --test l30_http_server`: 10 件とも通った。新しい `response_framing_uses_request_method_and_status_in_both_modes` と `relay_of_chunked_response_uses_content_length_in_both_modes` を含む。
  - `BENITOITE_GOLDEN_FILTER=network cargo test --test golden`: 通った。手書きの `status-informational.diag.json` は実際の出力と一致した。
  - `cargo run -p benitoite --example gen_skill`: 実行の後に差は残らない。
- 手書きのゴールデンは、隣の `status-below-range.*` と比べた。差はファイル名と、1 文字ずれた offset・column の 3 か所だけで、各 offset がソースの位置と合う。

## 所見

### 1. CONNECT への 205 に `content-length: 0` を送る（要修正）

- 場所: `crates/benitoite/src/runtime/io/http.rs` 971〜979 行（`ResponseFraming::body_and_length`）。`src/runtime/io/http/tests.rs` の `response_body_and_content_length_follow_status_and_method` の `("CONNECT", 205, ...)` の行が期待値として固定している。
- 問題: 表は状態の規則を方法の規則より先に当てるので、`(205, _)` が `(200..=299, Self::Connect)` より先に当たり、CONNECT への 205 に `content-length: 0` が付く。RFC 9110 §8.6 は CONNECT への 2xx の応答に Content-Length を送ってはならない（MUST NOT）とし、`decisions.md` の Q16 も CONNECT への 2xx は本体・`content-length`・`transfer-encoding` なしで送るとする。RFC 9110 §15.3.6 の 205 の要件は本体を生成しないことだけで、CONNECT を先に当てても満たせる。受け手は CONNECT の 2xx の Content-Length を無視する（RFC 9112 §6.3）ので実害は小さいが、送り手の MUST NOT に反し、テストがそれを固定している。
- 直し方の案: `(200..=299, Self::Connect) => (&[], None)` を `(205, _)` より前に移し、単体テストの期待値を `"HTTP/1.1 205 Reset Content\r\nconnection: close\r\n\r\n"` に直す。表の直前のコメントを「CONNECT への 2xx を先に当て、次に状態の規則、最後に HEAD を当てる」趣旨に直す。設計書 03-09 へ反映するときに、この優先順位も書く。

### 2. `write_if_room` が使わない引数 `_task` を受け取る（望ましい）

- 場所: `crates/benitoite/src/runtime/io/output.rs` 123〜126 行。
- 問題: `write` が `task` を使うのは預かりの列に積むときだけで、`write_if_room` は列に積まないので使わない。呼び出し側（`services.rs` 106 行）は意味のない `self.rt.output_task` を渡している。
- 直し方の案: 引数を消し、テスト（`output/testing.rs`）の呼び出しも合わせる。

### 3. 失敗の変換を `write_output` と二重に書いている（望ましい）

- 場所: `crates/benitoite/src/runtime/io/services.rs` 101〜125 行（`write_output_if_room`）と 135〜164 行（`write_output`）。
- 問題: `WriteFailure` の変換と、書いたときの `output_trace` と `dev_panic` の後始末が、二つの関数で同じ文の写しになっている。片方だけを後で直すと、警告と通常の出力で失敗の扱いが食い違う。
- 直し方の案: 失敗の変換と書いた後の後始末を非公開の補助の関数に切り出し、両方から呼ぶ。

### 4. 新しい関数のコメントに設計書の参照がない（望ましい）

- 場所: `http.rs` 641〜651 行（`Resume` と `resume`。`resume` には `///` がない）、同 955〜979 行（`ResponseFraming`、`from_method`、`body_and_length`、`replaced_response_header`）、`output.rs` 122 行（`write_if_room`）、`services.rs` 100 行（`write_output_if_room`）。
- 問題: AGENTS.md の「コメントと名前」は、公開の関数と型に `///` を書き、根拠になる設計書の章と節を示すことを求める。`body_and_length` の表は RFC の MUST NOT に基づくので、出典がないと所見 1 のような優先順位の誤りを見つけにくい。
- 直し方の案: `resume` に `///` を足し、各コメントに `（設計書 03-09「サーバ」）`・`（設計書 02-09「出力のバッファ」）` と RFC の節を添える。

### 5. 待ちの途中で別のタスクが不正な応答を渡すと、誤りの種類が変わる（参考）

- 場所: `crates/benitoite/src/builtins/funcs/http_server.rs` 93〜102 行。
- 問題: タスク A の応答が書き込みの待ちにある間に、タスク B が同じ交換に状態 99 などの応答を渡すと、直す前は R0701、直した後は `ResponseSentTwice` になる。どちらも実行時エラーで止まり、順序は補足 1 が指定したものだが、「外から見える振る舞いは変えない」とは厳密には食い違う。
- 直し方の案: 直さなくてよい（二度の応答のほうが誤りの実態に近い）。

### 6. HTTP-03 の確かめが組み込みの関数の経路を通らない（参考）

- 場所: `src/runtime/io/http/tests.rs` の `resume_finishes_pending_response_without_replacement_bytes`。
- 問題: `http::resume` がバイト列なしで続きを書き終えることは確かめるが、組み込みの関数 `respond` が待ちから戻ったときに組み立てを飛ばすことは確かめていない。分岐が短く読めば分かるので、今の範囲で足りる。16 MiB の応答が一度で書き終わらない前提も、壊れやすさは小さい。
- 直し方の案: 直さなくてよい。

### 7. 統合テストの表が単体テストの表と重なる（参考）

- 場所: `tests/l30_http_server.rs` の `RESPONSE_CASES` と、単体テストの表。
- 問題: 統合テストの 8 件のうち GET の 204・205・304 は単体テストと同じことを確かめるが、plan の完了の条件が生の TCP での確かめを求めているので、今の形でよい。
- 直し方の案: 直さなくてよい。所見 1 を直すときは単体テストだけを直せばよい。

### 8. 設計書と CHANGELOG の反映が残る（参考）

- 場所: `docs/design/03-interop/03-09-network.md` 93 行（「`status` が 100 以上 599 以下でなければ実行時エラー」）、CHANGELOG.md。
- 直し方の案: オーケストレータが、改造の反映のときに直す。

## 総評

依頼文の 6 項目と補足 1〜11 は漏れなく実装されている。除くヘッダの判定の一本化、落とした本体を全長の検査から外したこと、`resume` が覗くだけで誤りの順序を守ること、`advance_response` の共有、`write_if_room` が預かりの列を追い越さず記録済みの失敗を返すことは、いずれも正しい。本番のコードに `unwrap`・添字・`as`・`panic` はなく、テストは「関門」のコメントを付けて既存の表に足す形をとっている。直すべきなのは所見 1 だけで、所見 2〜4 は取り込みの前に直すのが望ましい。
