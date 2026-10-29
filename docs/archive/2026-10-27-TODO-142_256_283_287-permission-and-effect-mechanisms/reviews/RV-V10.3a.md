# RV-V10.3a: 版・登録・訳・README・CHANGELOG の最終編集の独立レビュー

2026-10-30。対象は未コミットの差分（基準 `92f9ac80`。84ファイル）と `v10.3a/`。ファイルと git の状態は変えず、作業ディレクトリのソースからレビュー用の target で CLI を作り、公開版 0.0.12 の CLI（`--version=json` の build.commit が `v0.0.12^{commit}` と一致）と比べた。試した入力を `v10.3a/rv-probes/` に写した。

結論: 重大0・中3・軽1。中1 は J2 の前提の訂正に当たるので、取りまとめの判断を先に決めてから同じ枝で直す。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `modules/text.rs` の `SCOPED_HTTP_OPERATIONS_CHANGE`・`_HELP`、`CHANGELOG.md` の 0.0.13 の節、README の J2、`decisions.md` | 0.0.13 で受理が狭まるのは `Http.send` だけではない。旧11操作をすべて処理する `File.Read` のハンドラ（`file-old-complete.bnt`）と旧12操作をすべて処理する `File.Write` のハンドラ（`write-old-complete.bnt`）は、公開版 0.0.12 では `check` 終了0、0.0.13 では E0501（`File.Read`・`File.Write` を宣言していない）になる。新しい操作を足すと 0.0.13 でも終了0。E0908 の境界の登録はこの場合も効く（`language "0.0.12"` で E0908）が、注記・help・CHANGELOG・J2 の前提は Http の場合しか述べていない | J2 の前提を訂正し、summary・help・CHANGELOG を File.Read・File.Write・Http.Connect の三つの事実にする（例: summary「File.Read, File.Write, and Http.Connect gained scoped operations; handlers that cover only their earlier operations, such as a handler with only an Http.send clause, are partial and leave the effect unhandled」、help「File.Read declares 13 operations, File.Write 16, and Http.Connect send and sendIn; a handler without every operation leaves that effect in the effect contract」）。text.rs・package.rs と modules/tests.rs の表・older-language.diag.json が連動する |
| 中2 | 中 | 06-09「設定ファイルの検査」の表（0.0.12 まで）・直後の段落・【決定】「修正案は同じ順で変更ごとの移行方法を示す」、02-10 の31行、`diag/codes.rs` の E0908 の説明（「helps list the corresponding migration guidance」。生成する `skill/references/diagnostics.md` に入る） | 0.0.13 の help は移行方法を示さず CHANGELOG も参照しないので、06-09 の【決定】・02-10・E0908 の説明が今の実装と食い違う | 06-09 の表に 0.0.13 の行を加え、段落に「0.0.13 の案内は CHANGELOG を参照せず、宣言とハッシュの更新も促さない」を加え、【決定】を「修正案は同じ順で変更ごとの案内を示す。0.0.12 までの案内は移行の方法を示し、0.0.13 の案内は変更の事実だけを示す」と改め、理由（`0.1.0` の公開まで移行の案内を書かない）を添える。02-10 を「各変更の案内を修正案へ」に改める。codes.rs は「helps list the corresponding guidance」とする（直すなら生成物も作り直す） |
| 中3 | 中 | `CHANGELOG.md` の 0.0.13 の節 | 既存の `Scope.checkHost` が IP と CIDR を受け付けるようになり（`ip.bnt`。0.0.12 では `InvalidPattern(…, "expected a host, *.host, or **.host")`、0.0.13 では `ok`）、拒否の理由の文も変わった。IPv4 射影の対象の拒否も新しい規則である。前の公開版との差であり、変更記録に載せるべき | 事実だけの項目を一つ加える（例: 「Scope host checks and patterns accept canonical IPv4/IPv6 addresses and CIDR networks; IPv4-mapped IPv6 targets are rejected, and invalid-pattern reasons list the new forms.」）。診断の追加を一行で書くかは「短く」とのつり合いで決める |
| 軽1 | 軽 | `CHANGELOG.md` の冒頭 | 「Every incompatible change is listed with how to migrate.」を「Incompatible changes are listed in each release section.」に変えた。0.0.13 は移行方法を載せないので変えること自体は正しいが、文案にも計画にもなく、results.md にも挙がっていない | results.md に理由を一文足す。設計者の受け入れの表で確認を得る |

## 問題がなかった点

- 版は `crates/benitoite/Cargo.toml` だけが 0.0.13 になり、ルートと fuzz の Cargo.toml は不変。二つの lock の差分はそれぞれ benitoite の `version` の一行だけ。
- 登録・表のテスト・modules/tests.rs は V10.1b の差分案と一致し、summary と help は既存の形で Q2 に合う（範囲の不足は中1）。CLI で、`language "0.0.12"` は E0908（注記 `0.0.13: handlers with only…`）、`0.0.13` と宣言なしは E0501、`0.0.14` は E0907、`0.0.11` は注記と help が 0.0.12・0.0.13 の順に並ぶ。
- testdata の差分は `language` の 50 行と hash の 1 行で、一覧と過不足なく一致する。旧版・将来版・ゼロのハッシュを狙う5入力は不変。三組のハッシュを 06-09 の規則で計算し直し、すべて一致した。成功用の入力に `language "0.0.12"` は残っていない。
- 訳は英日7組でコードフェンス・見出し・固定 URL が一致し、V10.2b と V10.3a の英語の差分（と 0.0.12 以降の英語の差分）がすべて入っている。消した derive の旧手順の文は訳でも消えている。誤訳と造語は見つからなかった。
- README は現在版 0.0.13。CHANGELOG の 0.0.13 の節に性能の増減・移行の手順・移行の例・H21 はない。古い版の節は不変。
- 検査は dry-run が9単位を選び、check.sh 自身の終了0・real 257.00 秒・1,610 成功・失敗0・ignored 29 を数え直して一致した。advisories の初回の DB ロックの取得不能を「unverified」として終了0で記録し、別の保存先で再確認して両対象とも照合済み0件にした扱いは 07-03 と AGENTS.md の決まりに合う。
- V10.1d への引き渡しの62件（loader とビルド5、testdata 51、`.diag.json` 5、named.rs 1）は影響表の行に正しく対応し、抜けはない。
- 公開の差分に手元のパス・作業の ID・担当の名前はない。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1 | J2 の前提を訂正する。J2 (a)（0.0.13 を登録し、要約と help は事実だけ）の方向は変えず、事実を File.Read・File.Write・Http.Connect の三つに広げる（設計者の委任による取りまとめの判断、2026-10-30。README に記録する） | V10.3ab、README |
| 中2 | 採る。codes.rs の E0908 の説明も直し、G で生成物を作り直す。診断の説明の文字列だけの変更で、性能の測定の経路と入力を変えないので、V10.2b の後の short の判断を保つ | V10.3ab |
| 中3 | 採る。Scope の項目を一つ加える。新しい診断の列挙は加えない（H20 の「短く」に合わせる） | V10.3ab |
| 軽1 | 採る。push の前の報告で設計者の確認を得る | V10.3ab、取りまとめ |
