# PM30 の結果: レビュー RV-PM への対応と本番との対応の記録

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | PM30.01〜.03（[RV-PM](../reviews/RV-PM.md) への対応）と PM30.04（本番との対応と未接続の範囲の記録）。docs/todo の TODO-256 の第一項・第三項、判断 18 |
| 基準 B_WORK | `709f57037b19fb0105aaaadd36100182b4c2b872` |
| 作業用のディレクトリの HEAD | `709f57037b19fb0105aaaadd36100182b4c2b872`（ブランチ m013/pm10。`git rev-parse HEAD`） |
| 閉じた範囲 | 中1・中2・軽1〜8 の全ての対応（[RV-PM-handling](../reviews/RV-PM-handling.md)）、PM30.04 へ渡す点 1〜7 の記録（[correspondence.md](correspondence.md)） |
| 未完の範囲 | なし（この枝の範囲で）。`models/check-same-defs.sh` を plan の検査の行へ加えるのは取りまとめの担当であり、それまでは保守上の未閉の危険として残る（correspondence の 7） |

## 変更と接続

- 変更: `models/PermissionKinds.lean`、`models/Policy.lean`（宣言ごとの変更は RV-PM-handling の表）。
- 新規: `models/check-same-defs.sh`、`models/same-defs-tail.lean`（`pm20.04/same-defs-tail.lean` と同じ内容）、`reviews/RV-PM-handling.md`、本ディレクトリ `pm30/`（本書、`correspondence.md`、`lean-PermissionKinds.log`・`.exit`、`lean-Policy.log`・`.exit`、`check-same-defs.log`・`.exit`、`checks.txt`、`mutation.diff`、`mutation-check.log`）。
- `formal/` の本番の定義は変えておらず、import もしていない（基準とブランチの開始版 `10099543` の間で `formal/` に差分がないことも確かめた）。モデルは本番へ接続していない。

## 検査

計画の「work PM10/PM20、Leanを直すPM30枝」の行と「全実検査の計時」の行に従った。三つの実行は続けて行い、並行させていない。`scripts/check.sh` はこの枝では走らせない（PM10.01 の依頼文と同じ指定）。

| 項目 | `PermissionKinds.lean` | `Policy.lean` | `check-same-defs.sh` |
|---|---|---|---|
| コマンド | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/PermissionKinds.lean > …/pm30/lean-PermissionKinds.log 2>&1` | 同じ形で末尾を `Policy.lean`、出力を `pm30/lean-Policy.log` | `/usr/bin/time -l sh <wt>/docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/check-same-defs.sh > …/pm30/check-same-defs.log 2>&1`（スクリプトの中で `lake env lean -M 12288`） |
| 終了 | 0 | 0 | 0（最終行 `check-same-defs: ok`） |
| 時間（real） | 0.42 秒 | 0.34 秒 | 0.45 秒 |
| 最大常駐量（`time -l` の maximum resident set size） | 438796288 バイト = 418.47 MiB = 0.409 GiB | 440303616 バイト = 419.91 MiB = 0.410 GiB | 453181440 バイト = 432.19 MiB = 0.422 GiB（sh・lake・lean の全体） |
| sorry の検索 | 出力に `sorry`・`sorryAx`・`error`・`warning` の一致なし | 同じく一致なし | 出力に `error`・`sorry` なし（スクリプトが検索する） |
| 公理 | 41 件とも `does not depend on any axioms` | 81 件とも `does not depend on any axioms` | — |
| 宣言と `#print axioms` の対応 | theorem 26 件、def 13 件、inductive 2 件の計 41 件。宣言に対する `#print axioms` の欠けも、宣言のない `#print axioms` もない | theorem 56 件、def 18 件、inductive 3 件、structure 1 件、構造体の欄の射影 3 件の計 81 件。欠けも余りもない | — |
| ソースの検索 | `sorry`・`axiom`・`admit`・`native_decide`・`decide`・`implemented_by` の語の一致なし（`#print axioms` の行を除く） | 同じく一致なし | — |

生の検索の結果と入力の SHA-256 は `checks.txt` にある（`PermissionKinds.lean` `82f4bc45…e199e6`、`Policy.lean` `e130f656…65a4f2`、`check-same-defs.sh` `92723e0d…7659f`、`same-defs-tail.lean` `c39833a4…ac135e`。完全な値は同ファイル）。

使った公理は、二つのモデルともない（`propext`・`Classical.choice`・`Quot.sound` も使っていない）。

### スクリプトが不一致を捕まえることの確かめ

一時の場所に、`PermissionKinds.lean`・`check-same-defs.sh`・`same-defs-tail.lean` の写しと、写しの `KindCheck` を `Subset allowed declared`（逆向き）に変えた `Policy.lean` を、改造のディレクトリと同じ深さに置き、`formal/` を記号リンクで指して、スクリプトを走らせた（差分は `mutation.diff`）。終了 1 で、`same-defs-tail.lean` の `rfl` の行を含む型の不一致が報告された（`mutation-check.log`。手元のパスは置き換えた）。一時の場所は消した。

## 件数の訂正（RV-PM の軽6）

元の記録は直さず、正しい内訳をここに記す。合計と網羅は元の記録のとおりである。

| 記録 | 元の記録の内訳 | 正しい内訳 |
|---|---|---|
| `pm10.01/results.md`（計 12 件） | theorem 8 件、定義 4 件 | theorem 7 件（`Subset.refl`・`Subset.trans`・`mem_traceKinds`・`traceKinds_subset_iff`・`events_subset_policy`・`event_kind_in_policy`・`all_runs_within_policy`）、def 5 件（`KindSet`・`KindSet.Subset`・`traceKinds`・`KindCheck`・`WithinDeclared`） |
| `pm10.02/results.md`（計 38 件） | theorem 25 件、def・inductive 13 件 | theorem 24 件、def 12 件、inductive 2 件 |

PM20.01〜.04 の記録の内訳（theorem 11・23・43・56 件など）は検索で数えたものであり、正しいことを確かめた。手で数えた PM10 の二つの記録だけが誤っていた。

この枝の後の件数は上の検査の表のとおりである（`PermissionKinds.lean` 41 件、`Policy.lean` 81 件）。PM20.04 の時点からの増減は、`PermissionKinds.lean` が `http_not_in_list` を消して `example_sets_strict`・`kindCheck_needed`・`declaredClock`・`realized_needed_example` を加えた（38 → 41 件）。`Policy.lean` は `deny_overrides_of_allow_all`・`kindCheck_passes_but_target_fails` を消して `secretFile_denied_although_allow_all`・`unlistedPolicy`・`wf_needed_example` を加え、例の名前の `host` を `otherFile` に改めた（80 → 81 件）。

## 失敗と修正

- 試しの実行（記録の検査の前）で、`Policy.lean` が二度、終了 1 になった。一度目は `wf_needed_example` の匿名の構成子の中の `fun e he` で `he` の型が決まらず（`cases` の場合の名前が合わない）、第三成分の `.fileRead` の型も決まらなかった。二度目は匿名の構成子の中に置いた `by` の塊の後の `,` が構文の誤りになった。証明を `refine` で始める戦術の形に書き直し、`Kind.fileRead`・`Target.publicFile` と型を明示して直した。試しの実行の出力は記録に残していない（記録の検査は直した後の一回である）。
- 例の対象の改名で、macOS の `sed` が `\b` を扱わず一部が残った。`perl` で残りを改名し、`host` が残っていないことを検索で確かめた。

## ずれと申し送り

- 計画からのずれはない。依頼の書いてよい範囲の中で作業した。
- 取りまとめが転記すべき条件:
  - plan の「work PM10/PM20」の行に、`models/check-same-defs.sh` を、どちらかのモデルを変えたときに必須の検査として加える（RV-PM の中2、correspondence の 7）。
  - 本番との対応の要点（correspondence の 1・2）: 本番が今与えるのは宣言上限が空の場合だけである。空でない場合の `WithinDeclared` には、印の列を持つ多段の遷移、`no_event` の一般化、`main` の型のエフェクトと `Eb` の関係の三つが要る。いずれも計画の外の別の作業である。
- 例の方針を書くときは、引き続き重なる型の match を避ける（PM20.02 の記録）。

## 時間

| 項目 | 内容 |
|---|---|
| 開始・終了 | 18:19 〜 18:26（2026-10-27、JST） |
| 外側の所要 | 約 7 分 |
| 能動時間 | 約 7 分（レビューの読解・モデルの修正・スクリプト・二つの記録の作成）。Lean の検査は計 2 秒未満 |
| 上端 2 倍の超過 | なし（見込み PM30 の 4 枝の計 2〜5時間） |
