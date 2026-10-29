# URL と固定した依存の境界（LR-U5）

2026-10-29 に一次資料と固定したソースを照合した。依存は変更していない。`Cargo.lock` は `ureq 3.4.2`・`http 1.5.0` を固定する。調べたソースの大きさと SHA-256 は [url-dependency-sources.json](url-dependency-sources.json) に置く。

## 規範として確認した点

- [RFC 9110 4.2.1・4.2.2](https://www.rfc-editor.org/rfc/rfc9110.html#section-4.2.1) は http/https の空の host を無効とし、省略または空の port をそれぞれ80/443とする。4.2.4はメッセージ内のtarget URIや欄の値として生成するhttp/httpsのURI参照にuserinfoを入れないよう求める。4.2.5はfragmentを含む参照と含まないHTTP URIの文法を区別する。
- [RFC 3986 2.1・3.2.2・3.2.3](https://www.rfc-editor.org/rfc/rfc3986.html#section-3.2.2) はパーセント符号化を `%` と二桁の十六進数字で書き、IPv4を四つの十進要素で書き、IPv6のIP literalを角括弧で囲む。7.4はOSの変換が短い数値・八進・十六進を受ける場合の食い違いを説明する。

これは処理系がRFC全体への適合を保証するという意味ではない。受理集合はR10の代数と固定したHTTP依存が扱える範囲へ絞る。schemeは型のendpoint範囲に加えない。

## 固定した実装から確認した点

`http 1.5.0` の [Uriのソース](https://docs.rs/http/1.5.0/src/http/uri/mod.rs.html)、`uri/authority.rs` の `Authority::host`・`port`・`parse`、`uri/path.rs` の `PathAndQuery::from_shared` と `scan_path_and_query` を読んだ。authorityのhostはuserinfoの後を取り出し、IPv6の角括弧を保つ。`port()` は不正な明示portでも `None` を返すので、省略と同一視してはならない。path/queryには不正な `%` の並びを受ける場合があり、fragmentは解析した値から落とす。生のURLを保持するレコードを解析結果で作り直さない。

`ureq 3.4.2` の `src/util.rs` の `UriExt::ensure_valid_url` と `src/unversioned/resolver.rs` の `DefaultResolver::host_and_port`・`resolve` を読んだ。HTTPのUriを使い、既定portを補い、OSの `ToSocketAddrs` へ接続する。依存側の公開説明は [DefaultResolver](https://docs.rs/ureq/3.4.2/ureq/unversioned/resolver/struct.DefaultResolver.html) にある。これらの挙動は固定したソースの読解であり、この枝で実通信・DNSの正しさを検証したものではない。

## この枝と後続

この枝は同じレコードの `url` を読み、URL解析不能・非対応schemeを `InvalidUrl`、得たhostと条件の形式・整数portの条件・所属の失敗を `Scope` とする。明示portは生のauthorityから数字と幅を検査する。IPv6は数値で読みR10の正規形へ直し、名前はR10で小文字化する。非正規の数値風hostを名前として成功させない。旧Scopeの直接入力と既存sendの受理集合は変えない。

R30.3/.4は保持した五欄とendpointが実送信の同じhost/portへ渡ること、リダイレクト・proxy・追加対象の扱いを照合する。K10の静的交換の成功を実通信の証拠としない。具体的な受理・拒否の実行例と最終境界は results と runtime のテストに記す。

## R20.0b2: macOS の数値ホストの解釈

2026-10-29（JST）、この機械の macOS 27.0.1（build 26A434、Darwin 27.0.0）で Python の `socket.getaddrinfo` を実行した。`family=AF_INET`・`type=SOCK_STREAM`・`proto=IPPROTO_TCP`・`flags=AI_NUMERICHOST`・port=80 を指定し、DNS の名前解決を伴わない数値の解釈だけを確かめた。小さい台本は `target/` の下で実行し、作業末に削除した。実行日・OS の版・結果・終了は [ログ](r20.0b2-numeric-host.log) と [計時](r20.0b2-numeric-host.json) に残す。

| 入力 host | OS が返した IPv4 アドレス |
|---|---|
| `127.0x.0.1` | `127.0.0.1` |
| `127.0x.1` | `127.0.0.1` |
| `0x7f.0x0.0x.1` | `127.0.0.1` |
| `0x.1.2.3` | `0.1.2.3` |
| `127.0X.0.1` | `127.0.0.1` |

再現する呼び出しは `socket.getaddrinfo(host, 80, socket.AF_INET, socket.SOCK_STREAM, socket.IPPROTO_TCP, socket.AI_NUMERICHOST)` である。この結果は `0x`・`0X` の後に十六進数字を持たない要素も、OS が数値として読むことを示す。Linux の挙動は未確認であり、この結果を他の OS へ一般化しない。

Rust の判定は保守的に広げ、名前として読める host の全要素が ASCII の数字で始まり `[0-9a-fA-FxX]` だけからなる場合を数値風として拒否する。正規の IPv4 は、この名前の判定へ入る前に IP として受ける。英字で始まるラベルを含む `a0x.example`・`dead.beef` と、通常の数字ラベルを含む `123.example` の受理は、OS の名前解決を使わない処理系の通常入口のテストで確かめる。
