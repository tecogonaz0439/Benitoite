# V5「要求の対象の文法」のレビュー（コミット 9c0fbfad）

読んだもの: `git show 9c0fbfad` の全差分、コミット時点の `runtime/io/http.rs`（`advance`・`acceptable_target`・`origin_target`・`parse_query`）、`http/tests.rs` の該当テスト、03-09、リファレンス、CHANGELOG、decisions.md の Q1・R10・R11、plan.md の V5、V4V6-preflight.md の「V5 への補足」、実装担当の報告。httparse 1.10.1 の `URI_MAP`（`b'!'..=0x7e | 0x80..=0xFF`）も確かめた。ビルドとテストは走らせていない。

## 総評

重さ「高」の指摘はない。Q1・R10・R11 の範囲は、事前点検の判定の順序のとおりに実装されている。拒みすぎも見つからなかった。文書の書き方の直しを中心に、中 2 件、低 6 件を挙げる。

### 観点 1: Q1 の範囲（抜けと拒みすぎ）

確かめた結果は次のとおりで、どれも Q1 のとおりである。

| 要求 | 結果 | 経路 |
|---|---|---|
| `GET http://host:8080/path?x=1` | 受け付ける | 接頭辞の判定 → `origin_target` が authority `host:8080` を `valid_host_characters` で確かめる（`:` は許す） |
| `GET HTTP://Example.COM/path?x=1`、`hTtPs://` | 受け付ける | `eq_ignore_ascii_case`（既存の受理の表にもある） |
| `GET http://[::1]:80/p` | 受け付ける | `[`・`]`・`:` は `valid_host_characters` の集まりに入る |
| `CONNECT [::1]:443` | 受け付ける | `rsplit_once(':')` で host `[::1]`、port `443`（表にある） |
| `OPTIONS http://h:8001`・`OPTIONS *` | 受け付ける | 表にある |
| `%` 符号化、`/%G0`、`/?q=%` | 受け付ける | 文字の判定は `%` を見ない（表にある） |
| `CONNECT h:0`・`h:65535`・`h:0443` | 受け付ける（R11） | 数字だけを確かめた後に `parse::<u16>()` |
| `CONNECT h:`・`h:x`・`h:+443`・`h:65536`・`:443`・`h`・`/x`・`http://h/`・`*` | 400 | 表にある。`+443` は数字の判定で拒む |
| `GET *`・`options *`・`*x`・`foo`・`?x`・`%2Fa`・`GET h:443`・`ftp://`・`urn:x`・`http:/x` | 400（R10） | 表にある |
| `"`・`<`・`>`・0x80 以上 | 400 | httparse が通すので新しい判定が要る。テストは実際に新しいコードを守っている |
| `[ ] \ ^ ` { | }` | 受け付ける | 表にある |

制御文字・空白・0x7F は httparse の `URI_MAP` が先に拒む。

### 観点 2〜4

RFC の引用は大筋で正しい（低-3 に一点）。文言の規約: 新しい文言はなく、panic も添字も算術もない（`get(..7)` を使う）。テストは既存の表に行を足す形で、test-audit の関門に合う。l30 の TCP の表に 1 行を足し、実際の接続の経路も確かめている。

---

## 指摘

### 中-1 リファレンスが、どこにも書かれていない「既存の扱い」と「`Host` の文字」を指している

- ファイル: `docs/reference/benitoite.md` 813 行
- 問題: (a) "keeps the existing handling of incomplete or invalid percent escapes" は、変更の前後で比べる書き方である。リファレンスのほかの箇所に `%` の扱い（`?q=%G0` は `%` を字面のまま残す、など。03-09 の 67 行）が書かれていないので、利用者は「既存の扱い」が何かを知る手段がない。"still accepts" も同じく変更の前後で比べる書き方である。(b) "the same characters allowed in `Host`" も、リファレンスに `Host` で許す文字の記述がない（grep で確かめた）。
- 直し方: (a) 今の振る舞いを書く。例: "Literal `[`, `]`, `\`, `^`, `` ` ``, `{`, `|`, and `}` are accepted in paths and queries. A `%` that is not followed by two hexadecimal digits is accepted and kept as is." (b) 文字を列挙する。例: "a non-empty host made of ASCII letters, digits, and `-._~!$&'()*+,;=:[]%`"。または `Host` の検査（03-09 の 124 行）を、別の項目としてリファレンスに足す。

### 中-2 03-09 の本文に、変更の前後で比べる語が残っている

- ファイル: `docs/design/03-interop/03-09-network.md` 128 行
- 問題: 「引き続き受け付ける」「その文字はパスでも従来どおり受け付け」は、変更の前後で比べる書き方である。設計書には、処理系が今実装している内容だけを書く（AGENTS.md「設計書の規約」）。改造を保管した後では、「従来」が何を指すのか読み手には分からない。
- 直し方: 「`[`・…・`}` と、`%` の後が 16 進の 2 桁でない場合は、起点形と絶対形のパスとクエリで受け付ける。」「後者では `[` などがクエリに生で残りうるため、その文字はパスでも受け付け、`%` は後述のクエリの読み方に従う。」のように直す。テストのコメント（`http/tests.rs` の受理の表の「パスでも従来どおり受け付ける」）も「パスでも受け付ける」にする（低）。

### 低-1 03-09 の UTF-8 の文が二通りに読める

- ファイル: 03-09 133 行
- 問題: 「パーセント符号化を戻したクエリかヘッダの値が正しい UTF-8 でない」は、「パーセント符号化を戻した」がヘッダの値にもかかるように読める。ヘッダの値は、符号化を戻さずに UTF-8 を確かめている（`std::str::from_utf8(header.value)`）。
- 直し方: 「ヘッダの値か、パーセント符号化を戻したクエリが、正しい UTF-8 でない要求は、…」と語の順序を入れ替える。

### 低-2 CHANGELOG の行で、`CONNECT` の起点形が拒まれることが読み取りにくい

- ファイル: `CHANGELOG.md` 30 行
- 問題: 一文目（"targets that do not begin with `/` … except …"）だけを読むと、`CONNECT /x` を受け付けるように読める。二文目の "`CONNECT` accepts only …" で補っているが、`CONNECT` の起点形と絶対形も新たに 400 になることは明示されていない。`host:port` がコードの書式になっていない。この表のほかの行（Csv・File.Writer）にある "Before, …" の文もない。
- 直し方: 例: "… except `*` for uppercase `OPTIONS`. Uppercase `CONNECT` accepts only `host:port`, with a non-empty host and a port of ASCII digits from 0 to 65535; `CONNECT /path` and absolute targets are rejected. … Before, these targets were passed to the handler." 移行の欄は今のままでよい。

### 低-3 RFC 9110 §7.1 に「限る」を帰すのは少し強い

- ファイル: 03-09 127 行
- 問題: RFC 9110 §7.1 は、CONNECT と OPTIONS の対象が方法ごとの形になることを説明している。authority 形を CONNECT だけに、`*` を OPTIONS だけに「限る」と明記するのは、RFC 9112 §3.2.3（"only used for CONNECT requests"）と §3.2.4（"only used for a server-wide OPTIONS request"）である。どちらも同じ文の中で既に引いているので、誤りではない。
- 直し方: 「[RFC 9112 §3.2.3・§3.2.4] が authority 形を `CONNECT`、`*` の形を `OPTIONS` に限り（RFC 9110 §7.1 も同じ）」のように、限定の出典を 9112 に寄せる。任意。

### 低-4 authority 形の検査は RFC の uri-host より緩いが、03-09 にそう書いていない

- ファイル: 03-09 127 行、`http.rs` の `acceptable_target`
- 問題: `CONNECT a:b:443`、括弧のない `CONNECT ::1:443`、`CONNECT [::1:443` は受け付ける（host を `valid_host_characters` だけで確かめるため）。RFC 9112 §3.2.3 の `uri-host` では、どれも正しくない。事前点検は「書く必要はない」と判断したが、同じ文が「RFC 9112 … が対象の形を定め」を理由に挙げているので、厳密に検査していると読まれうる。`Host` の項目（124 行）は「RFC 3986 の厳密な解析はしない」と明記している。
- 直し方: 理由の末尾に「host は `Host` と同じく文字の集まりだけを確かめ、RFC 3986 の厳密な解析はしない。」と一文を足す。処理系は直さなくてよい。

### 低-5 受理の表に、絶対形の authority が port と IPv6 を含む行がない

- ファイル: `http/tests.rs` の `request_absolute_target_becomes_origin_path_and_query` の受理の表
- 問題: 今回、`:` で port を分ける判定を加えたが、絶対形に port（`http://h:8080/p?x=1`）や IPv6（`http://[::1]:80/p`）が付く場合の受理を守る行がない（`OPTIONS http://h:8001` の 1 行だけ）。後で port の判定を絶対形にも広げる直しが入ったときの退行を捕まえにくい。
- 直し方: `("GET", "http://[::1]:8080/p?x=1", "/p", vec![("x", "1")])` を 1 行足す。

### 低-6 小文字の `connect` の扱いを守る行がない

- ファイル: 同じテスト
- 問題: 方法は大文字と小文字を区別するので、`connect h:443` は `CONNECT` の分岐を通らず 400 になり、`connect /x` は起点形として受け付ける。03-09 とリファレンスは「uppercase `CONNECT`」と書くが、`options *` の行に当たる `connect` の行がない。
- 直し方: 拒否の表に `("connect", "h:443")` を足す。任意。

---

## 要点

- 高はない。Q1・R10・R11 の範囲は守られ、拒みすぎもない（大文字の scheme、port と IPv6 の絶対形、IPv6 の CONNECT、OPTIONS の絶対形、`%` を確かめた）。
- 中-1: リファレンス 813 行の "existing handling" と "same characters allowed in `Host`" は、リファレンスのどこにも書かれていない事柄を指している。今の振る舞いを具体的に書く。
- 中-2: 03-09 128 行の「引き続き」「従来どおり」は、設計書の規約（今の実装だけを書く）に反する。
- 低: 03-09 133 行の語の順序、CHANGELOG での `CONNECT` の起点形の明示、RFC 9110 §7.1 の引き方、host の検査が緩いことの一文、テストに 2 行を足すこと。
