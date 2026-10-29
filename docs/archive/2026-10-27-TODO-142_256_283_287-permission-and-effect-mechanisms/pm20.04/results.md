# PM20.04 の結果: 空対象と誤った和の反例（PM20 の終わり）

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | PM20.04（docs/todo の TODO-256 の第三項のうち、空対象と種類判定の分離、誤った和の反例。判断 18） |
| 基準 B_WORK | `3ce3736e1640cddda06187affb3f76a6f3c4c583` |
| 作業用のディレクトリの HEAD | `3ce3736e1640cddda06187affb3f76a6f3c4c583`（ブランチ m013/pm10。`git rev-parse HEAD`） |
| 閉じた範囲 | 空対象の定義と補題、第一項の判定と第三項の判定の分離の定理、誤った和の定義と狭小化を崩す補題、空対象の例と誤った和の反例（点ごと・列）、写した定義と第一項の定義の同一性の機械的な確かめ、PM30 へ渡す一覧 |
| 未完の範囲 | なし。この枝で PM20 の四枝を終えた。独立のレビューと本番との対応の記録は PM30 の担当である |

## 変更と接続

- 変更: `<wt>/docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/Policy.lean`。冒頭の説明を直し、名前空間 `Policy` に「空対象と種類判定の分離、誤った和（PM20.04）」の節を、`Examples` に「空対象の例」「誤った和の反例」の小節を加え、`#print axioms` の行を加えた。PM20.01〜.03 の定義と定理は変えていない。
- 新規: 本ディレクトリ `pm20.04/`（本書、`lean-run-01.log`、`lean-run-01.exit`、`checks-01.txt`、`same-defs-tail.lean`、`same-defs-run.log`）。
- `formal/` の本番の定義は変えておらず、import もしていない。`PermissionKinds.lean` も変えていない。本番へは接続していない。

## 追加した定義と定理

名前空間の前置き `Benitoite.Models.Policy.` を省く。

### 一般の補題（`Policy`）

| 名前 | 種別 | 言明・意味 |
|---|---|---|
| `Policy.EmptyTargets p k` | def | `p.kinds k ∧ ∀ t, ¬ p.allow k t`（種類の記載はあるが対象の許可が空） |
| `Policy.not_permits_of_emptyTargets` | theorem | `EmptyTargets p k → ∀ t, ¬ p.permits k t` |
| `Policy.not_traceAllowed_of_emptyTargets` | theorem | `EmptyTargets p (kindOf e) → e ∈ tr → ¬ TraceAllowed kindOf targetOf p tr` |
| `Policy.kindCheck_passes_but_target_fails` | theorem | `KindCheck declared p.kinds → Subset (traceKinds kindOf tr) declared → EmptyTargets p (kindOf e) → e ∈ tr → p.kinds (kindOf e) ∧ ¬ TraceAllowed kindOf targetOf p tr`（第一項の判定は通り、第三項の判定は通らない） |
| `Policy.wrongUnion p q` | def | 誤った和。`kinds`・`allow`・`deny` をいずれも点ごとの論理和にする。拒否は `inter` と同じ論理和なので、`inter` との違いは種類の記載と許可の扱いだけである。反例のためだけに置く |
| `Policy.wrongUnion_permits_of_left` | theorem | `p.permits k t → ¬ q.deny k t → (wrongUnion p q).permits k t` |
| `Policy.wrongUnion_breaks_narrowing` | theorem | `p.permits k t → ¬ q.deny k t → ¬ q.permits k t → (wrongUnion p q).permits k t ∧ ¬ q.permits k t ∧ ¬ (inter p q).permits k t` |

### 例（`Examples`。PM20.02・.03 の `Kind`・`Target`・`Event`・`policy`・`extra` を使う）

| 名前 | 種別 | 内容 |
|---|---|---|
| `emptyPolicy` | def | `kinds`: `fileRead` だけ。`allow`: なし。`deny`: なし |
| `emptyPolicy_wf`・`emptyPolicy_fileRead_empty` | theorem | `emptyPolicy.WF`、`EmptyTargets emptyPolicy .fileRead` |
| `declaredRead` | def | 宣言上限。`fileRead` だけ |
| `emptyPolicy_kindCheck` | theorem | `KindCheck declaredRead emptyPolicy.kinds`（第一項の種類の判定は通る） |
| `readTrace_within` | theorem | `Subset (traceKinds kindOf [read publicFile]) declaredRead`（第一項の `WithinDeclared` に当たる包含） |
| `emptyTargets_example` | theorem | `KindCheck declaredRead emptyPolicy.kinds ∧ Subset (traceKinds kindOf [read publicFile]) emptyPolicy.kinds ∧ ¬ TraceAllowed … emptyPolicy [read publicFile] ∧ TraceAllowed … emptyPolicy []` |
| `wrongUnion_admits_host` | theorem | 反例（点ごと）。`(wrongUnion policy extra).permits .fileRead .host ∧ ¬ extra.permits .fileRead .host ∧ ¬ (inter policy extra).permits .fileRead .host` |
| `wrongUnion_allows_hostTrace` | theorem | 誤った和の下で `[read publicFile, read host]` が通る |
| `wrongUnion_not_narrowing` | theorem | 反例（列）。`¬ ∀ p q tr, TraceAllowed … (wrongUnion p q) tr → TraceAllowed … q tr`（例の型について。共通部分の `traceAllowed_inter_right` に当たる性質が誤った和では成り立たない） |

### 第一項との関係

`emptyTargets_example` は、写した第一項の定義（`KindCheck`・`Subset`・`traceKinds`）を使い、同じ列について次の三つを並べる。第一項の実行前の判定が通る。第一項の系（`Subset.trans` による事象 ⊆ 方針の種類）も成り立つ。それでも第三項の対象の判定は通らない。同じ方針の下で事象のない列は通る（`traceAllowed_nil`）ので、対象が空の種類の記載は、対象を持たない純粋な計算と区別される。これは判断 18 の「種類を許す記載があり対象が空の場合、種類だけの実行前判定は通り、実行時の対象判定はどれも通らない」に当たる。ただし「実行時の対象判定」はこのモデルでは述語 `TraceAllowed` であり、本番の実行時の拒否による停止ではない。

### 量化と仮定の説明

- 一般の補題は `Kind`・`Target`・`Ev`・`kindOf`・`targetOf`・方針 `p`・`q`・`k`・`t`・宣言上限・列について全称で量化している。仮定は言明に現れるものだけで、整形式は仮定しない。
- `kindCheck_passes_but_target_fails` の仮定の `KindCheck` と宣言上限への収まりは、例で同時に満たされる（`emptyPolicy_kindCheck`・`readTrace_within`）。結論の否定の部分は、仮定が矛盾するので成り立つのではない。
- `wrongUnion_breaks_narrowing` の三つの仮定（元の方針が許す、追加方針が拒否しない、追加方針が許さない）は、例の `policy`・`extra`・`host` で同時に満たされる（`wrongUnion_admits_host`）。
- `wrongUnion_not_narrowing` は例の型 `Examples.Kind`・`Examples.Target`・`Examples.Event` についての否定であり、任意の型についての否定ではない（性質の一般の言明に反例が一つあることを示す形である）。

## 写した定義と `PermissionKinds.lean` の同一性

二つのモデルの `#print axioms` の行を除いた本文を一つの一時ファイルへ連結し、末尾に `same-defs-tail.lean` を置いて検査した。末尾は、写した六つの宣言について `@Benitoite.Models.Policy.X = @Benitoite.Models.PermissionKinds.X` を `rfl` で確かめる `example` と、型の `#check` である。

| 項目 | 内容 |
|---|---|
| 対象 | `KindSet`・`KindSet.Subset`・`KindSet.Subset.trans`・`traceKinds`・`mem_traceKinds`・`KindCheck` |
| コマンド | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <scratch>/samedefs/SameDefs.lean`。一時ファイルは `{ grep -v '^#print axioms' models/PermissionKinds.lean; grep -v '^#print axioms' models/Policy.lean; cat pm20.04/same-defs-tail.lean; }` で作った |
| 入力の SHA-256 | `models/PermissionKinds.lean` `151962f4cf0addb70e0db88f7e7309a0bd525233caa3804bac8ce20845252299`、`models/Policy.lean` `9e67ce2be17727b04f9939211b9fb5d0833285fdea7cdd46f454de4bcf5bf71c`、`pm20.04/same-defs-tail.lean` `c39833a4b3f511b038484805d29dc378d1d24415e89424866ef5df1430ac135e` |
| 結果 | 終了 0、`error`・`sorry`・`warning` の一致なし（`same-defs-run.log`）。六つの等式はいずれも `rfl` で通った。`#check` の型は、引数の並び・暗黙の引数・名前（`kindOf`・`tr`・`e`）が一致し、違いは `KindSet` の名前空間だけである |
| 最大常駐量 | 447807488 バイト = 427.06 MiB（real 0.54 秒） |
| 本文の違い | `KindCheck` の第二引数の名前が、第一項では `policy`、写しでは `allowed` である（`Policy` の構造体の名前と混同しないため）。`traceKinds`・`mem_traceKinds` は、第一項では `variable` の宣言、写しでは明示の引数で書いた。いずれも展開した定義は一致する |

## 検査

計画の「work PM10/PM20」の行と「全実検査の計時」の行に従った。`scripts/check.sh` はこの枝では走らせない（依頼の指定）。

| 項目 | 内容 |
|---|---|
| コマンド | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/Policy.lean > ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/pm20.04/lean-run-01.log 2>&1` |
| Lean | 4.34.1（`formal/lean-toolchain`）、arm64-apple-darwin |
| 終了 | 0（`lean-run-01.exit`） |
| 時間 | `time` の real 0.29 秒（user 0.25 秒、sys 0.11 秒）。外側の経過は 18:10:20 の 1 秒未満 |
| 最大常駐量 | `/usr/bin/time -l`（macOS）の maximum resident set size の原値 438452224 バイト = 418.14 MiB = 0.408 GiB。lake とその子の lean の一回の実行の全体であり、同一性の確かめとは並行させず続けて実行した |
| sorry の検索 | 出力に `sorry` の一致なし（grep の終了 1）。`sorryAx`・`error`・`warning` も一致なし。ソースの `sorry`・`axiom`・`admit`・`decide` の語の検索（`#print axioms` の行を除く）も一致なし（`checks-01.txt`） |
| 公理の一覧 | 宣言 80 件（theorem 56 件、def・inductive・structure 21 件、`Policy` の欄の射影 3 件。この枝で加えた 17 件を含む）の全てに `#print axioms` を置き、宣言の名前との対応の欠けがないことを `checks-01.txt` で確かめた。80 件とも `does not depend on any axioms`。使った公理はない |
| 量化・仮定のレビュー | 担当の自己確認を上の節に書いた。独立のレビューは PM30 の担当である |

## 失敗と修正

なし（本検査も同一性の確かめも初回で終了 0、sorry と公理の一致なし）。

## ずれと申し送り

- 計画からのずれはない。写した定義の同一性の確かめは、依頼の「写した定義と PermissionKinds.lean の同一性」を一覧に付けるために加えた。一時ファイルは手元の一時の場所に置き、記録には末尾の断片と入力のハッシュだけを残した。
- 取りまとめが転記すべき条件: `models/` の二つのモデルは同じ定義を別の名前空間に持つ。片方を変えたら、もう片方を同じ変更で直し、上の同一性の確かめをやり直す。

## 時間

| 項目 | 内容 |
|---|---|
| 開始・終了 | 18:08 〜 18:12（2026-10-27、JST） |
| 外側の所要 | 約 4 分 |
| 能動時間 | 約 4 分（定義と例・同一性の確かめ・PM30 への一覧の作成）。Lean の検査は二回で計 1 秒未満 |
| 上端 2 倍の超過 | なし（見込み 0.75〜1.5時間） |

## PM30 へ渡す一覧

独立レビューと本番との対応の記録のための一覧である。いずれも基準 `3ce3736e1640cddda06187affb3f76a6f3c4c583` に本枝の変更を加えた状態のものである。二つのモデルとも Lean の core だけを使い、本番を import せず、全ての宣言が公理に依存しない（`PermissionKinds.lean` の 38 件は `pm10.02/`、`Policy.lean` の 80 件は本書の検査）。

### `models/PermissionKinds.lean`（第一項。名前空間 `Benitoite.Models.PermissionKinds`）

| 名前 | 言明の要約 | 仮定 |
|---|---|---|
| `KindSet Kind` | `Kind → Prop` | — |
| `KindSet.Subset A B` | `∀ k, A k → B k` | — |
| `KindSet.Subset.refl`・`.trans` | 反射・推移 | `.trans` は二つの包含 |
| `traceKinds kindOf tr` | `fun k => ∃ e, e ∈ tr ∧ kindOf e = k` | — |
| `mem_traceKinds` | `e ∈ tr → traceKinds kindOf tr (kindOf e)` | 所属 |
| `traceKinds_subset_iff` | 包含 ↔ 各事象の種類の所属 | なし |
| `KindCheck declared policy` | `Subset declared policy` | — |
| `WithinDeclared kindOf declared tr` | `Subset (traceKinds kindOf tr) declared`（本番の健全性が与えるべき性質を仮定で受ける） | — |
| `events_subset_policy` | 事象 ⊆ 宣言上限 と 宣言上限 ⊆ 方針 から 事象 ⊆ 方針 | 二つの包含 |
| `event_kind_in_policy` | 上の二つと `e ∈ tr` から `policy (kindOf e)` | 二つの包含と所属 |
| `all_runs_within_policy` | 任意の実行の集合 `runs` の全ての列について同じ結論 | 各列の `WithinDeclared` と `KindCheck` |
| `KindSet.ofList`・`KindSet.ofList_subset_iff` | 有限の列から述語への写しと、その包含の特徴付け | なし |
| `not_kindCheck_of_missing` | 宣言上限に方針にない種類があれば `¬ KindCheck` | 所属と非所属 |
| `not_events_subset_of_missing` | `S` にない種類の事象を含む列は `S` に収まらない | 所属と非所属 |
| `traceKinds_singleton` | 事象一つの列の種類はその事象の種類だけ | なし |
| `kindCheck_iff_all_traces` | 宣言上限の各種類に事象がある場合、「宣言上限に収まる全ての列で事象 ⊆ 方針」↔ `KindCheck` | 各種類の事象の存在 |
| `Examples.*`（20 件） | 種類 `console`・`fileRead`・`http`、事象 `print`・`readFile`・`get`。非空の例 `readFile_in_policy`・`trace_within_policy`・`trace_has_fileRead`。反例 `declaredWithHttp_rejected`（実行前）、`traceWithHttp_outside_policy`（`KindCheck` を外すと落ちる）、`traceWithHttp_needs_within`（`WithinDeclared` を外すと落ちる） | — |

### `models/Policy.lean`（第三項。名前空間 `Benitoite.Models.Policy`）

| 枝 | 名前 | 言明の要約 | 仮定 |
|---|---|---|---|
| 写し | `KindSet`・`KindSet.Subset`・`KindSet.Subset.trans`・`traceKinds`・`mem_traceKinds`・`KindCheck` | 第一項と同じ（上の「同一性」） | 第一項と同じ |
| .01 | `Policy`（欄 `kinds`・`allow`・`deny`） | 種類の記載と、対象の許可・拒否の述語 | — |
| .01 | `Policy.WF` | `∀ k t, allow k t → kinds k` | — |
| .01 | `Policy.permits` | `allow k t ∧ ¬ deny k t` | — |
| .01 | `permits_iff`・`permits_allow`・`permits_not_deny`・`permits_of_allow_of_not_deny` | 定義の分解と合成 | 言明のとおり |
| .01 | `permits_kind` | `WF → permits k t → kinds k` | 整形式 |
| .01 | `Policy.TraceAllowed` | `∀ e ∈ tr, permits (kindOf e) (targetOf e)` | — |
| .01 | `traceAllowed_nil`・`traceAllowed_cons_iff` | 空の列は通る、先頭への分解 | なし |
| .01 | `traceAllowed_kinds` | `WF → TraceAllowed → Subset (traceKinds) kinds` | 整形式 |
| .01 | `kindCheck_event_kind` | `KindCheck` と宣言上限への収まりから、各事象の種類の記載（対象の判定は得ない） | 二つの包含と所属 |
| .02 | `deny_overrides` | `deny k t → ¬ permits k t` | 拒否だけ |
| .02 | `deny_overrides_of_allow_all` | 許可が全ての対象を含んでも同じ（許可の仮定は証明で使わない） | 許可の全称と拒否 |
| .02 | `permits_iff_not_deny_of_allow` | 許可のある対象では `permits ↔ ¬ deny` | 許可 |
| .02 | `not_traceAllowed_of_denied` | 拒否された事象を含む列は通らない | 所属と拒否 |
| .02 | `permitsAllowWins`・`allowWins_admits_denied` | 拒否を見ない誤った判定（反例専用）と、許可と拒否の両方に属する対象が通る食い違い | 許可と拒否 |
| .03 | `inter` | `kinds`・`allow` は論理積、`deny` は論理和 | — |
| .03 | `permits_inter_iff`・`traceAllowed_inter_iff` | 共通部分の判定 ↔ 両方の判定（点ごと・列、両向き） | なし |
| .03 | `permits_inter_left`・`_right`、`traceAllowed_inter_left`・`_right` | 狭小化 | 共通部分の判定 |
| .03 | `not_permits_inter_of_not_right` | 追加方針が許さなければ共通部分も許さない | 非許可 |
| .03 | `inter_wf` | 整形式の保存 | 両方の整形式 |
| .03 | `inter_kinds_subset_left`・`_right`、`kindCheck_inter_iff` | 記載の包含、種類の判定の論理積 | なし |
| .04 | `EmptyTargets`・`not_permits_of_emptyTargets`・`not_traceAllowed_of_emptyTargets` | 記載はあるが対象が空の種類は、どの対象・どの列でも通らない | 空対象（と所属） |
| .04 | `kindCheck_passes_but_target_fails` | 第一項の判定と記載は得られるが、対象の判定は通らない | `KindCheck`・包含・空対象・所属 |
| .04 | `wrongUnion`・`wrongUnion_permits_of_left`・`wrongUnion_breaks_narrowing` | 許可の論理和の誤った結合（反例専用）と、狭小化を崩す補題 | 言明のとおり |

### 例と反例の対応

| 性質 | 非空の例（性質が働く） | 反例（仮定を外す・誤った定義） |
|---|---|---|
| 第一項の系 | `PermissionKinds.Examples.readFile_in_policy`・`trace_within_policy`・`trace_has_fileRead` | `declaredWithHttp_rejected`・`traceWithHttp_outside_policy`（`KindCheck` を外す）、`traceWithHttp_needs_within`（`WithinDeclared` を外す） |
| 対象の判定と deny 優先（.01・.02） | `Policy.Examples.permits_publicFile`・`publicTrace_allowed` | `not_permits_secretFile`・`mixedTrace_rejected`（拒否が勝つ）、`allowWins_admits_secretFile`（拒否の成分を外した誤った判定では通る） |
| 共通部分による狭小化（.03） | `inter_permits_publicFile`・`inter_allows_publicTrace`（両方が許す対象は落ちない） | `inter_not_permits_host`・`inter_rejects_hostTrace`（片方だけが許す対象は落ちる。`policy_allows_hostTrace` と対） |
| 誤った和（.04） | — | `wrongUnion_admits_host`・`wrongUnion_allows_hostTrace`・`wrongUnion_not_narrowing`（許可の論理和では片方だけが許す対象が通り、狭小化が崩れる） |
| 空対象と種類判定の分離（.04） | `emptyTargets_example` の第四成分（事象のない列は通る） | `emptyTargets_example` の第一〜三成分（第一項の判定と系は通るが、対象の判定は通らない） |

### PM30 で確かめるとよい点

- このモデルの「方針」「実行時の対象の判定」は抽象の述語であり、本番の方針の書式・parser・実行時の拒否による停止・サーバ・OS・非干渉性を表さない。本番の formal に方針の定義はない（`pm10.02/results.md` の「本番への対応」）。
- 第一項の `WithinDeclared` は仮定で受けている。本番の `effect_soundness` は宣言上限が空の場合だけを与える。空でない場合の本番の成立は未確認である（同上の「確かめていないこと」）。
- `wrongUnion_not_narrowing` は例の型についての否定である。
- `Target` を種類に依存しない一つの型にしたこと、種類の記載を独立の欄にしたことの理由は `pm20.01/results.md` にある。
