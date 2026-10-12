# 扱う項目の本文の写し

docs/todo は非公開のリポジトリなので、扱う項目の本文を 2026-10-11 に写した。TODO-185 は、この改造で扱う `Regex` の点だけを写した（ほかの点は項目に残る）。

### TODO-201 繰り返す照合を一致ごとに区切り、取り消しと中断を効かせる

- 状態: 未着手
- 出どころ: 改造 `docs/archive/2026-10-11-TODO-042_177_195_196_197_198-runtime-and-check-hardening/` の `study-runtime.md` の TODO-196（案 5）と付随の所見、`decisions.md` の Q12・Q14
- 関連: TODO-185（`Regex` の確保の上限）

`Regex.findAll`・`replaceAll`・`replaceAllWith`・`split` は、繰り返す照合が最悪で入力の長さの 2 乗の時間になる（regex 1.13.1 の文書。03-08「Regex」）。照合は純粋な組み込みの関数として VM の中で同期的に走るので、途中では `Task.withTimeout` の取り消しも中断の要求（SIGINT）も効かない。128 KiB の入力の照合の途中に SIGINT を送ると、照合の後に `main` がそのまま終わり、終了状態 0 になった（02-09「中断の要求」の決まりの範囲内の振る舞い）。案は、「位置から一回だけ探す」内部の組み込みの関数を設け、繰り返す照合を標準ライブラリのソースのループで書くことである。一致の間で呼び出しの予算を使うので、切り替え・取り消し・中断が効く。空の一致の扱いを regex の反復と同じにすることと、一致の多い普通の入力での遅れを測ることが要る。あわせて、最後の切り替えの後に中断の印を調べるかを決める。

### TODO-202 HTTP サーバの細部の残り（接続ごとのヘッダ、`OPTIONS` の絶対形、要求の対象の `#`）

- 状態: 未着手
- 出どころ: 改造 `docs/archive/2026-10-11-TODO-042_177_195_196_197_198-runtime-and-check-hardening/` の `decisions.md` の Q18、`reviews/2026-10-11-H2/report.md` の所見 3・6・7
- 関連: TODO-069

改造 `docs/archive/2026-10-11-TODO-042_177_195_196_197_198-runtime-and-check-hardening/` で TODO-198 を直した後に残した細部である。

- 応答から除くヘッダは `content-length`・`connection`・`transfer-encoding`・`trailer` だけである。中継で上流から写りうるほかの接続ごとのヘッダ（`keep-alive`・`upgrade`・`proxy-connection`・`te`、`connection` に挙げた名前）を除くか（RFC 9110 §7.6.1 を確かめてから決める）。
- パスが空の `OPTIONS` の絶対形（`OPTIONS http://example.org:8001 HTTP/1.1`）を、RFC 9112 §3.2.4 の例のように `*` として扱うか。今は `/` にする。
- 要求の対象の `#`（断片）の扱いが一定しない（`http://h/p#f` は `/p#f`、`http://h#f` は `/`、起点形の `/p#f` はそのまま）。400 にするか取り除くかを決める。
- `100-continue` の 100 を一度で書き切れず、書き込みの準備を待つ経路を通るテストがない。OS のバッファの大きさに依存しない確かめ方を考える。

### TODO-185 コレクションとテキスト・データのモジュールの細部

（この改造で扱う点だけを写した）

- `Regex` の確保の上限。`findAll`（`crates/benitoite/src/builtins/funcs/regex.rs:132` 以降）は一致の数だけを `CheckedLen` で確かめ、一致の数×グループの数の確保（`Match` の `groups`）は確かめない。グループの多い正規表現と巨大な入力では、上限の内で止まらず大量に確保しうる。`compile`（同 97 行以降）は誤りの文面 `error.to_string()` をそのまま値にするので、正規表現の全文を含んで巨大になりうる（切り詰めるか、正規表現の長さの上限を決める）。`replaceAllWith`（`crates/benitoite/src/prelude/stdlib/Regex.bnt:52-66`）は `List.append` を重ねる形であり、計算量が 2 乗になるかは確かめていない（要確認）。Opaque の別の領域の容量を確保の量に数える論点は TODO-042 で、繰り返す照合の時間と `find` の入力の写しは TODO-196 で扱う。出どころ: [later-issues の 87](sources/later-issues.md)。
