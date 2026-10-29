# RV-R30.4: 非追従の sendIn と実対象の独立レビュー

2026-10-29。対象は R30.4・R30.4b の未コミットの差分と `r30.4/` の results.md・調査・ログ。作業用のディレクトリは書き換えず、scratchpad の target で debug のバイナリをビルドし、ループバックの受け手（ポート 18411 と 18412）で再現した。外部への通信はしていない。台本と出力は `r30.4/rv-probes/` に写した（絶対パスは `<probes>` などに伏せた）。R30.4 は HTTPS の証明書の検証で OS が別の宛先へ取得しうる件で一度止まり、設計者の決定（README の 2026-10-29 の項）で、保証の範囲に DNS と並べて書いて R30.4b で完了した。その説明と、W-R の引用も確かめた。

結論: 取り込んでよい。重大0・中1・軽4。中1 は取り込みの前に直す（設計書の1文の誤りで、Rust には触れない）。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | 02-08 の 220 行（sendIn の【決定】） | 「Direct と Request の両方式、および参照実行器は同じ登録と実処理を使う」とあるが、HTTP の実処理は `runtime_view()` を要し、参照実行器の `refinterp/resources.rs` の `Io` はそれを意図して公開しない（`reference_and_fixed_services_do_not_expose_vm_runtime_views` が None を検査）。参照の実通信の試行は `Internal("HTTP runtime unavailable")` で止まった。旧 `send` も同じ | 「参照実行器も同じ登録を持つが、HTTP の実通信の本体は VM のランタイムを要し、参照実行器では実行しない（処理系の不具合として止まる）」の形に直す |
| 軽1 | 軽 | `src/prelude/stdlib/Network/Http.bnt` 29 行の doc コメントと生成物 `skill/references/stdlib/Network.Http.md` | `NetworkError.InvalidInput` とあるが、構成子は `NetworkErrorKind.InvalidInput`（Process.bnt は `IOErrorKind.InvalidInput`、SKILL.md・idioms・03-09 も `NetworkErrorKind`）。LLM が読む参照に誤った名前が入る | doc コメントを `NetworkErrorKind.InvalidInput` に直し、`gen_skill` で作り直す |
| 軽2 | 軽 | 07-01 の 62 行の出典 | Apple の Web の文書へリンクしているが、照合した一次資料は SDK の `SecTrust.h` で、Web の頁は確認していない（`sectrust-aia-sources.json` は `network_access_for_sources: false`）。記述の中身は正しい（SDK の 260〜289 行と 405〜425 行、SHA-256 の一致を確かめた） | 出典を SDK の Security.framework の `SecTrust.h`（SDK の版を添える）に替える |
| 軽3 | 軽 | 07-04「形式化で仮定するもの」の 276〜277 行（単一対象の「ちょうど一つ報告する」と、旧 Top の「実装が作用した対象をすべて観測に含む」）、01-12 の 342 行の観測の定義（「作用した対象」） | 観測の単位（プログラムが接続する endpoint。DNS と TLS の OS の副次的な通信は含めない）を書いたのは 285 行と 07-01・03-09 だけで、観測を定義する箇所と完全性の文言は「作用した対象」のまま。旧 `send` の完全性を字面どおりに読むと AIA の宛先まで含む | 276〜277 行に、HTTP の観測の対象は「プログラムが接続する endpoint」と読み、OS の副次的な通信を含めないことを一文で加え、旧 Top の完全性も同じ単位で読む。01-12 は実装に依存しない章なので任意 |
| 軽4 | 軽 | `skill/SKILL.md`・`references/idioms.md` の sendIn の段落 | 「DNS と OS の変換の前」までは書いてあるが、TLS の証明書の検証で OS が別の宛先と通信しうることに触れていない（results は V10 の担当とするが、Skill はこの枝で書き換えている） | この枝で一文を足す |

参考: 棚卸しの検索の範囲の外にある `r10.6/inputs/http-full-handler.bnt` の `case Http.send(sent)` は今は部分ハンドラの扱いになる。過去の測定の入力なので直す必要はないが、R30.5 の棚卸しで範囲の外として名指しするとよい。

## 問題がなかった点

- 明示した Host（11入力）: 末尾のドット、userinfo 付き、同じ値の Host 二つ、port の省略、別の port、末尾の空白、空の値、path 付き、IPv4 射影の IPv6 は送信前に InvalidInput で止まり、受け手への接続は0件。名前が大文字の `HOST` と先頭0付きの port は受理し、URI と同じ相手にちょうど1件届いた。
- 型の上の経路（Top の要求を狭い上限の下で送る、狭い注釈の lambda や関数値に Top を渡す、パイプ、注釈のない関数値を狭い引数と Top の引数で呼ぶ、Top を受ける高階関数に `Http.sendIn` を渡す、節で捕えた狭い引数を裸の型へ転送する）はすべて E0519 か E0401 で拒否された。
- ハンドラ: 旧 `send` の節だけでは `Http.Connect[狭い範囲]` が残り、二節そろえば完全。旧 `send` の節で実際に転送すると Top が外側へ残り、節自身が別の endpoint へ送るとその Connect は外側へ残る。
- 健全性: ureq 3.4.2 の `config.rs` で `max_redirects(0)` は追わずに 3xx を返し、上限超過の誤りにもしない。`proxy(None)` で環境変数を無視する。URI の判定は検査と同じ `http::Uri` と `endpoint()` で行い userinfo を拒否する。resolver でも保持した endpoint と照合し直す。型で拒否する方向は Lean と合い、Rust の方が厳しい向きの差（完全性に二節を要する）だけがある。
- 契約: 欄の読み取りを射影と共有し、URL の規則を複製していない。共用の読み取りと完了は報告の関数名を受け取る。Host と URI を別々に照合する。widen の `[R, S]` と `Covers { outer: 1, inner: 0 }` は変えていない。旧 `send` は追従10回のまま。IO の失敗を RequestCheckError へ混ぜていない。
- worker と保持: worker が捕捉するのはホスト側のデータ（`Request<Vec<u8>>`・`Duration`・`Option<Endpoint>`・`&'static str` など）だけで、言語の値は VM の引数に残す。H を実行し H-full を要らないとした判断は妥当。
- 規約: 本番のコードに `unwrap`・添字・`as` はない。例・テスト・Skill の射影と拡大は `bind` の形。設計書に新しい作業の ID はない。
- TLS の説明: rustls-platform-verifier 0.7.1 の `apple.rs` は SSL policy の SecTrust を作りネットワークの取得を無効にせず評価する。ureq 3.4.2 の `RootCerts::PlatformVerifier` はこの検証器を設定する。SDK の `SecTrust.h` は取得が既定で有効で、評価が失効の検査の通信を含みうると書く。07-01・03-09・07-04 は「保証しない」と限定して書き、言い過ぎはなく、R30.3 の契約（観測の単位は保持した endpoint）を広げただけで矛盾しない。
- W-R の引用は 07-03「結果の保存と引用」の条件を満たす。初回の終了1、`cfg(test)` の期待配列だけの修正と1件の再実行、補完の `--only … --test '*'` の終了0、その後の network_faults の1件と fmt・clippy のやり直しが、ファイルの更新時刻と記録の時刻の順序と合う。差分の SHA-256 と未追跡の `http_io.rs` の SHA-256、22 入力のうち変更なしの19件が記録と一致し、残りの3件は再開で変えた 03-09・07-01・07-04（これらを読む検査はない）。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1・軽1〜軽4 | 採る | R30.4c |
| 参考 | R30.5 の棚卸しで範囲の外として名指しする | R30.5 |
