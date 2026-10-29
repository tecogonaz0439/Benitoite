# PM20.01 の結果: allow/deny と種類の許可

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | PM20.01（docs/todo の TODO-256 の第三項の最初の枝。allow/deny と種類の許可。判断 18） |
| 基準 B_WORK | `8900f6476ad573657a2a41846ef2aa4c778de7ad` |
| 作業用のディレクトリの HEAD | `8900f6476ad573657a2a41846ef2aa4c778de7ad`（ブランチ m013/pm10。`git rev-parse HEAD`） |
| 閉じた範囲 | 方針の定義、対象の判定 `permits`、整形式、列に対する判定 `TraceAllowed`、種類の判定（第一項の `KindCheck`）との関係と、基本の補題 |
| 未完の範囲 | なし（この枝の範囲で）。deny 優先（PM20.02）、共通部分による狭小化（PM20.03）、空対象と誤った和の反例（PM20.04）は証明していない |

## 変更と接続

- 新規: `<wt>/docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/Policy.lean`（名前空間 `Benitoite.Models.Policy`）。
- 新規: 本ディレクトリ `pm20.01/`（本書、`lean-run-01.log`、`lean-run-01.exit`、`checks-01.txt`、`import-probe.log`）。
- `formal/` の本番の定義は変えておらず、import もしていない。モデルは import 文を持たず、Lean の core だけを使う。本番へは接続していない。

## `KindSet` を写した理由

`KindSet`・`Subset`・`Subset.trans`・`traceKinds`・`mem_traceKinds`・`KindCheck` を、`PermissionKinds.lean` と同じ本体のまま写した。理由: 検査のコマンド `lake env lean` の探索パス（`LEAN_PATH`）は `formal/.lake/build/lib/lean` と Lean の toolchain の `lib/lean` だけであり、`models/` の `.olean` を含まない。一時の場所に置いた `import PermissionKinds` の一行のファイルは `unknown module prefix 'PermissionKinds'` で失敗した（`import-probe.log`。手元のパスはプレースホルダへ置き換えた）。import するには `formal/` の lakefile に lib を足すか `.olean` を作る必要があり、`formal/` の変更か計画にない生成物になるので採らなかった。写した定義の名前は `Benitoite.Models.Policy.` の下にあり、第一項の名前と衝突しない。

## 定義と定理の一覧

`Kind`・`Target`・`Ev` は任意の型の引数であり、具体の種類・対象の列挙は使っていない。`kindOf : Ev → Kind` と `targetOf : Ev → Target` は、各事象の種類と対象を返す任意の関数である。名前空間の前置き `Benitoite.Models.Policy.` を省く。

| 名前 | 種別 | 言明・意味 |
|---|---|---|
| `KindSet`・`KindSet.Subset`・`KindSet.Subset.trans`・`traceKinds`・`mem_traceKinds`・`KindCheck` | def・theorem | 第一項からの写し（上の節） |
| `Policy Kind Target` | structure | 欄 `kinds : KindSet Kind`（種類の記載）、`allow : Kind → Target → Prop`（`Allow(k,t)`）、`deny : Kind → Target → Prop`（`Deny(k,t)`） |
| `Policy.WF p` | def | `∀ k t, p.allow k t → p.kinds k`（許可する対象は記載のある種類のものに限る） |
| `Policy.permits p k t` | def | `p.allow k t ∧ ¬ p.deny k t` |
| `Policy.permits_iff` | theorem | `p.permits k t ↔ p.allow k t ∧ ¬ p.deny k t` |
| `Policy.permits_allow`・`Policy.permits_not_deny` | theorem | `p.permits k t → p.allow k t`、`p.permits k t → ¬ p.deny k t` |
| `Policy.permits_of_allow_of_not_deny` | theorem | `p.allow k t → ¬ p.deny k t → p.permits k t` |
| `Policy.permits_kind` | theorem | `p.WF → p.permits k t → p.kinds k` |
| `Policy.TraceAllowed kindOf targetOf p tr` | def | `∀ e, e ∈ tr → p.permits (kindOf e) (targetOf e)`（実行時の対象の判定を列の全ての事象に適用したもの） |
| `Policy.traceAllowed_nil` | theorem | 任意の `p` で `TraceAllowed kindOf targetOf p []` |
| `Policy.traceAllowed_cons_iff` | theorem | `TraceAllowed … p (e :: tr) ↔ p.permits (kindOf e) (targetOf e) ∧ TraceAllowed … p tr` |
| `Policy.traceAllowed_kinds` | theorem | `p.WF → TraceAllowed kindOf targetOf p tr → Subset (traceKinds kindOf tr) p.kinds`（対象の判定は種類の判定を細かくしたもの） |
| `Policy.kindCheck_event_kind` | theorem | `KindCheck declared p.kinds → Subset (traceKinds kindOf tr) declared → e ∈ tr → p.kinds (kindOf e)`（実行前の種類の判定から、各事象の種類の記載を得る。対象の判定は得ない） |

### 量化と仮定の説明

- 全ての定理は `Kind`・`Target`・`Ev`・`kindOf`・`targetOf`・方針 `p`・宣言上限 `declared`・列 `tr` について全称で量化している。述語が空であることや列が空であることは仮定していない。
- 仮定は、各定理の言明に現れる `p.permits k t`・`p.allow k t`・`¬ p.deny k t`・`p.WF`・`KindCheck`・宣言上限への収まりだけである。どれも述語の値に制約を置くだけで、`False` を導く形をしていない（具体の非空の例は PM20.04 の担当）。
- `WF` は種類の記載と許可の述語の関係だけを課し、拒否の述語には何も課さない。拒否は記載のない種類について書いてもよく、`permits` の値には影響しない（`permits` は `allow` を要する）。
- `traceAllowed_nil` が示すとおり、事象のない列（対象を持たない純粋な計算）はどの方針の下でも判定を通る。判断 18 が区別を求める「種類の記載はあるが対象が空の方針」は、`kinds k` が真で `∀ t, ¬ allow k t` となる方針であり、`kindCheck_event_kind` は種類の記載だけを結論し、対象の判定（`permits`）を結論しない。この方針の下で `k` の事象を含む列が判定を通らない例は PM20.04 が示す。

## 定義の形を選んだ理由

- 方針を三つの欄（`kinds`・`allow`・`deny`）の構造体にした。理由: 種類の記載を対象の許可から独立した欄にしないと、判断 18 の「種類を許す記載があり対象が空」が「記載がない」と区別できなくなる（記載を `∃ t, allow k t` で定めると、対象が空のとき記載も偽になる）。`WF` で一方向（許可 → 記載）だけを課し、逆は課さないので、対象が空の記載を表せる。
- `allow`・`deny` を `Kind → Target → Prop` の述語にした。理由: PM20.03 の共通部分は、欄ごとの点ごとの論理積（`kinds`・`allow`）と論理和（`deny`）で構造体を作るだけで定義でき、PM20.04 の誤った和も `allow` の点ごとの論理和で書ける。点ごとの演算は定義の展開だけで所属の補題になり、`simp` と `propext` を要しにくい。
- 対象の判定を `allow ∧ ¬ deny` の定義そのものにした。理由: PM20.02 の deny 優先（`deny k t → ¬ permits k t`）が定義の第二の成分から直ちに出る形であり、許可の述語がどれほど広くても拒否が勝つことを、allow に条件を付けずに言明できる。
- 対象の型 `Target` を種類に依存させない一つの型にした。理由: 依存型（`Target : Kind → Type`）にすると、PM20.03・.04 で二つの方針を組み合わせるときに型の書き換えが要る。種類ごとの対象の領域の違いは、`allow` の述語で表せる。
- 列に対する判定 `TraceAllowed` を、第一項の `traceKinds` と同じ事象の列（`List Ev`）の上に置いた。理由: 第一項の種類の判定と第三項の対象の判定を、同じ列について並べて比べられる（`traceAllowed_kinds`・`kindCheck_event_kind`）。

## 検査

計画の「work PM10/PM20」の行と「全実検査の計時」の行に従った。`scripts/check.sh` はこの枝では走らせない（依頼の指定）。

| 項目 | 内容 |
|---|---|
| コマンド | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/Policy.lean > ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/pm20.01/lean-run-01.log 2>&1` |
| Lean | 4.34.1（`formal/lean-toolchain`）、arm64-apple-darwin |
| 終了 | 0（`lean-run-01.exit`） |
| 時間 | `time` の real 0.22 秒（user 0.14 秒、sys 0.08 秒）。外側の経過は 18:00:21 の 1 秒未満 |
| 最大常駐量 | `/usr/bin/time -l`（macOS）の maximum resident set size の原値 423428096 バイト = 403.81 MiB = 0.394 GiB。lake とその子の lean の一回の実行の全体であり、並行する別のプロセスを含まない |
| sorry の検索 | 出力に `sorry` の一致なし（grep の終了 1）。`sorryAx`・`error`・`warning` も一致なし。ソースにも `sorry`・`axiom`・`admit`・`decide` の類はない（`checks-01.txt`） |
| 公理の一覧 | 宣言 22 件（theorem 11 件、def 7 件、structure 1 件とその欄の射影 3 件）の全てに `#print axioms` を置き、宣言の名前との対応の欠けがないことを `checks-01.txt` で確かめた。22 件とも `does not depend on any axioms`。使った公理はない。構造体から自動で作られる `Policy.mk`・`Policy.rec` などは列挙していない（証明が直接使っていない） |
| 量化・仮定のレビュー | 担当の自己確認を上の節に書いた。独立のレビューは PM30 の担当である |

`import-probe.log` は検査ではなく、import の可否を調べた記録である（`lake env printenv LEAN_PATH` と、一時の場所の一行のファイルの `lake env lean -M 12288`。終了 1）。

## 失敗と修正

なし（初回の実行で終了 0、sorry と公理の一致なし）。

## ずれと申し送り

- 計画からのずれはない。`KindSet` などを写したことは依頼が認めた選択である。
- PM20.02（deny 優先）への申し送り:
  - deny 優先の中心は `p.deny k t → ¬ p.permits k t` であり、`permits_not_deny` の対偶として `allow` に条件を付けずに言明できる。許可の述語が全ての対象を含む方針（`allow k = fun _ => True`）でも拒否が勝つことを、量化の説明で示すとよい。
  - 列の形は `traceAllowed_cons_iff` を使い、「拒否された対象の事象を一つでも含む列は `TraceAllowed` を満たさない」とすると、PM20.04 の例でも使える。
  - 拒否を記載のない種類に書いた場合も `permits` は偽のまま（`allow` を要する）なので、`WF` を拒否に広げる必要はない。
  - 第一項の定義を写した事情は PM20.02〜.04 でも同じである。`Policy.lean` の中で続けて書けば import は要らない。
- 取りまとめが転記すべき条件: `models/` の二つのモデルは同じ定義を別の名前空間に写して持つ。片方の定義を変える場合は、もう片方も同じ変更で直す。

## 時間

| 項目 | 内容 |
|---|---|
| 開始・終了 | 17:59 〜 18:01（2026-10-27、JST） |
| 外側の所要 | 約 2 分 |
| 能動時間 | 約 2 分（定義の設計・証明・記録）。Lean の検査は 1 秒未満 |
| 上端 2 倍の超過 | なし（見込み 0.75〜1.5時間） |
