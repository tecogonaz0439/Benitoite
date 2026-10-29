# PM20.03 の結果: 追加方針との共通部分による狭小化

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | PM20.03（docs/todo の TODO-256 の第三項のうち、追加方針との共通部分による狭小化。判断 18） |
| 基準 B_WORK | `43d2a35ab9483438ee525e4db5a5db9b3743b99b` |
| 作業用のディレクトリの HEAD | `43d2a35ab9483438ee525e4db5a5db9b3743b99b`（ブランチ m013/pm10。`git rev-parse HEAD`） |
| 閉じた範囲 | 共通部分の定義、判定の両向きの特徴付け（点ごと・列）、狭小化（左右、点ごと・列）、整形式の保存、種類の記載と実行前の種類の判定の共通部分、非空の例と狭小化の例 |
| 未完の範囲 | なし（この枝の範囲で）。空対象と誤った和（PM20.04）は扱っていない |

## 変更と接続

- 変更: `<wt>/docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/Policy.lean`。冒頭の説明を直し、名前空間 `Policy` の中に「追加方針との共通部分による狭小化（PM20.03）」の節を、`Examples` に「共通部分の例（PM20.03）」の小節を加え、`#print axioms` の行を加えた。PM20.01・PM20.02 の定義と定理は変えていない。
- 新規: 本ディレクトリ `pm20.03/`（本書、`lean-run-01.log`、`lean-run-01.exit`、`checks-01.txt`）。
- `formal/` の本番の定義は変えておらず、import もしていない。本番へは接続していない。

## 追加した定義と定理

名前空間の前置き `Benitoite.Models.Policy.` を省く。

### 一般の補題（`Policy`）

| 名前 | 種別 | 言明・意味 |
|---|---|---|
| `Policy.inter p q` | def | `kinds := p.kinds k ∧ q.kinds k`、`allow := p.allow k t ∧ q.allow k t`、`deny := p.deny k t ∨ q.deny k t` |
| `Policy.permits_inter_iff` | theorem | `(inter p q).permits k t ↔ p.permits k t ∧ q.permits k t`（両向き） |
| `Policy.permits_inter_left`・`Policy.permits_inter_right` | theorem | `(inter p q).permits k t → p.permits k t`、同じく `→ q.permits k t`（狭小化） |
| `Policy.not_permits_inter_of_not_right` | theorem | `¬ q.permits k t → ¬ (inter p q).permits k t`（追加方針が許さない対象は共通部分も許さない） |
| `Policy.inter_wf` | theorem | `p.WF → q.WF → (inter p q).WF` |
| `Policy.inter_kinds_subset_left`・`Policy.inter_kinds_subset_right` | theorem | `Subset (inter p q).kinds p.kinds`、`Subset (inter p q).kinds q.kinds` |
| `Policy.kindCheck_inter_iff` | theorem | `KindCheck declared (inter p q).kinds ↔ KindCheck declared p.kinds ∧ KindCheck declared q.kinds` |
| `Policy.traceAllowed_inter_iff` | theorem | `TraceAllowed kindOf targetOf (inter p q) tr ↔ TraceAllowed … p tr ∧ TraceAllowed … q tr`（列の形、両向き） |
| `Policy.traceAllowed_inter_left`・`Policy.traceAllowed_inter_right` | theorem | 共通部分の下で通る列は、`p`・`q` のそれぞれの下でも通る |

### 例（`Examples`。PM20.02 の `Kind`・`Target`・`Event`・`policy` を使う）

| 名前 | 種別 | 内容 |
|---|---|---|
| `extra` | def | 追加方針。`kinds`: `fileRead` だけ。`allow`: `fileRead` の `publicFile` だけ。`deny`: なし |
| `extra_wf`・`inter_example_wf` | theorem | `extra.WF`、`(inter policy extra).WF`（`inter_wf` による） |
| `policy_permits_host` | theorem | 元の方針は `host` を許す |
| `extra_not_permits_host` | theorem | 追加方針は `host` を許さない |
| `inter_not_permits_host` | theorem | 狭小化の例。片方（元の方針）だけが許す `host` は、共通部分では通らない |
| `inter_permits_publicFile` | theorem | 非空の例。両方が許す `publicFile` は、共通部分でも通る |
| `policy_allows_hostTrace` | theorem | 元の方針の下で `[read publicFile, read host]` が通る |
| `inter_rejects_hostTrace` | theorem | 狭小化の例（列）。同じ列は共通部分の下では通らない |
| `inter_allows_publicTrace` | theorem | 非空の例（列）。`[read publicFile]` は共通部分の下でも通る |

### 量化と仮定の説明

- 一般の補題は `Kind`・`Target`・`Ev`・`kindOf`・`targetOf`・方針 `p`・`q`・`k`・`t`・宣言上限 `declared`・列 `tr` について全称で量化している。`permits_inter_iff`・`kindCheck_inter_iff`・`traceAllowed_inter_iff` は仮定を持たない同値であり、整形式も仮定しない。`inter_wf` だけが両方の整形式を仮定する。
- 同値の両向きにより、共通部分は両方の方針より狭い（左右の狭小化）だけでなく、両方が許す対象を落とさない（必要以上に狭くならない）。
- 結論が空の場合だけで成り立つ形でないこと: 例の共通部分は整形式で、`publicFile` を許し（`inter_permits_publicFile`）、`host` を許さない（`inter_not_permits_host`）。許す列と許さない列の両方がある。元の方針の下で通る列が共通部分の下で通らない例（`policy_allows_hostTrace` と `inter_rejects_hostTrace`）は、狭小化が実際に判定を変えることを示す。
- 拒否の論理和は deny 優先（PM20.02）と組み合わさる。元の方針の拒否する `secretFile` は、追加方針が拒否しなくても共通部分では通らない（`permits_inter_left` と `not_permits_secretFile` から出る。この組み合わせを定理として別に置いてはいない）。

## 検査

計画の「work PM10/PM20」の行と「全実検査の計時」の行に従った。`scripts/check.sh` はこの枝では走らせない（依頼の指定）。

| 項目 | 内容 |
|---|---|
| コマンド | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/Policy.lean > ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/pm20.03/lean-run-01.log 2>&1` |
| Lean | 4.34.1（`formal/lean-toolchain`）、arm64-apple-darwin |
| 終了 | 0（`lean-run-01.exit`） |
| 時間 | `time` の real 0.28 秒（user 0.24 秒、sys 0.11 秒）。外側の経過は 18:07:17 の 1 秒未満 |
| 最大常駐量 | `/usr/bin/time -l`（macOS）の maximum resident set size の原値 436568064 バイト = 416.34 MiB = 0.407 GiB。lake とその子の lean の一回の実行の全体であり、並行する別のプロセスを含まない |
| sorry の検索 | 出力に `sorry` の一致なし（grep の終了 1）。`sorryAx`・`error`・`warning` も一致なし。ソースの `sorry`・`axiom`・`admit`・`decide` の語の検索（`#print axioms` の行を除く）も一致なし（`checks-01.txt`） |
| 公理の一覧 | 宣言 63 件（theorem 43 件、def・inductive・structure 17 件、`Policy` の欄の射影 3 件。この枝で加えた 22 件を含む）の全てに `#print axioms` を置き、宣言の名前との対応の欠けがないことを `checks-01.txt` で確かめた。63 件とも `does not depend on any axioms`。使った公理はない |
| 量化・仮定のレビュー | 担当の自己確認を上の節に書いた。独立のレビューは PM30 の担当である |

`checks-01.txt` では、PM20.02 の検索の偽の一致（宣言の名前 `allowWins_admits_…` の中の `admit`、例の欄の定義の行）を避けるため、語の単位の検索と、宣言の種類ごとの数え方に改めた。

## 失敗と修正

なし（初回の実行で終了 0、sorry と公理の一致なし）。

## ずれと申し送り

- 計画からのずれはない。
- PM20.04（空対象と誤った和）への申し送り:
  - 空対象の例は、`kinds k` が真で `∀ t, ¬ allow k t` の方針にすると、`KindCheck declared p.kinds` は通る（種類の記載はある）が、`k` の事象を含む列は `TraceAllowed` を満たさない形で、第一項の判定と第三項の判定の分離を示せる。事象のない列は `traceAllowed_nil` で通るので、対象を持たない純粋な計算と区別できる。
  - 誤った和は `allow` を点ごとの論理和にした方針（反例のためだけの名前の定義）にすると、`permits_inter_left` に当たる狭小化が成り立たず、片方だけが許す対象（例の `host`）が通ってしまうことを示せる。この枝の `policy`・`extra` をそのまま使える。
  - 例の方針を書くときは、引き続き重なる型の match を避け、構成子を全て並べる。
- 取りまとめが転記すべき条件: なし。

## 時間

| 項目 | 内容 |
|---|---|
| 開始・終了 | 18:06 〜 18:08（2026-10-27、JST） |
| 外側の所要 | 約 2 分 |
| 能動時間 | 約 2 分（定義と証明・例・記録）。Lean の検査は 1 秒未満 |
| 上端 2 倍の超過 | なし（見込み 0.75〜1.5時間） |
