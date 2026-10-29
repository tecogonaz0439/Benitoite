# PM10.02 の結果: 非空の例・許可不足の反例と本番への対応

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | PM10.02（docs/todo の TODO-256 の第一項のうち、非空の例・許可不足の反例と本番への対応。判断 18） |
| 基準 B_WORK | `ab02fec144e492ff392bc6f22368853bb71bb05d`（作業用のディレクトリのブランチ m013/pm10。`git rev-parse HEAD`） |
| 作業用のディレクトリの HEAD | `ab02fec144e492ff392bc6f22368853bb71bb05d` |
| 閉じた範囲 | 有限の列からの写し、許可不足の一般の補題、判定の必要十分性、具体の例（非空の例と許可不足の反例）、本番への対応の記録 |
| 未完の範囲 | なし（この枝の範囲で）。モデルは本番へ接続していない。独立のレビューは PM30 の担当である |

## 変更と接続

- 変更: `<wt>/docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/PermissionKinds.lean`。冒頭の説明を直し、PM10.02 の二つの節（一般の補題、名前空間 `Benitoite.Models.PermissionKinds.Examples` の例）と `#print axioms` の行を加えた。PM10.01 の定義と定理は変えていない。
- 新規: 本ディレクトリ `pm10.02/`（本書、`lean-run-01.log`、`lean-run-01.exit`、`checks-01.txt`）。
- `formal/` の本番の定義は変えておらず、import もしていない。本番は読むだけにした（下の「本番への対応」）。
- 具体の種類の列挙は `Examples` の中だけで使った。例の種類と事象の名前は説明のためのものであり、本番の組み込みのエフェクトや関数を表さない。

## 追加した定義と定理

名前空間の前置き `Benitoite.Models.PermissionKinds.` を省く。

### 一般の補題

| 名前 | 種別 | 言明・意味 |
|---|---|---|
| `KindSet.ofList l` | def | 有限の列 `l : List Kind` を、所属 `k ∈ l` を述語とする集合へ写す |
| `KindSet.ofList_subset_iff` | theorem | `Subset (ofList l) S ↔ ∀ k, k ∈ l → S k` |
| `not_kindCheck_of_missing` | theorem | `declared k → ¬ policy k → ¬ KindCheck declared policy`（許可不足は実行前の判定で落ちる） |
| `not_events_subset_of_missing` | theorem | `e ∈ tr → ¬ S (kindOf e) → ¬ Subset (traceKinds kindOf tr) S` |
| `traceKinds_singleton` | theorem | `traceKinds kindOf [e] k → kindOf e = k` |
| `kindCheck_iff_all_traces` | theorem | `(∀ k, declared k → ∃ e, kindOf e = k)` のとき、`(∀ tr, WithinDeclared kindOf declared tr → Subset (traceKinds kindOf tr) policy) ↔ KindCheck declared policy` |

`kindCheck_iff_all_traces` は、宣言上限の各種類にその種類の事象が存在するという仮定の下で、実行前の判定 `KindCheck` が系の結論に要る条件と一致し、それより強くないことを示す。仮定を外すと、事象を持たない種類が宣言上限にあっても結論は成り立つので、同値は一般には成り立たない。

### 例（`Examples`）

| 名前 | 種別 | 内容 |
|---|---|---|
| `Kind` | inductive | `console`・`fileRead`・`http` |
| `Event` | inductive | `print (msg : String)`・`readFile (path : String)`・`get (url : String)`。種類とは別の型にした |
| `kindOf` | def | `print ↦ console`、`readFile ↦ fileRead`、`get ↦ http` |
| `declared`・`policy` | def | どちらも `ofList [console, fileRead]` |
| `declaredWithHttp` | def | `ofList [console, http]` |
| `trace` | def | `[print "hello", readFile "a.txt"]` |
| `traceWithHttp` | def | `[print "hello", get "https://example.com/"]` |
| `http_not_in_list`・`http_not_in_policy`・`http_not_in_declared` | theorem | `http` は `[console, fileRead]` に属さない |
| `kindCheck_example` | theorem | `KindCheck declared policy` |
| `trace_within_declared` | theorem | `WithinDeclared kindOf declared trace` |
| `readFile_in_policy` | theorem | 非空の例。系 `event_kind_in_policy` により `policy (kindOf (readFile "a.txt"))` |
| `trace_within_policy` | theorem | 非空の例の集合の形。`Subset (traceKinds kindOf trace) policy` |
| `trace_has_fileRead` | theorem | 非空の例の結論が空でないこと。`traceKinds kindOf trace fileRead` |
| `declaredWithHttp_rejected` | theorem | 許可不足の反例（実行前）。`¬ KindCheck declaredWithHttp policy` |
| `traceWithHttp_within_declared` | theorem | `WithinDeclared kindOf declaredWithHttp traceWithHttp` |
| `traceWithHttp_outside_policy` | theorem | 許可不足の反例（実行）。宣言上限に収まるが `¬ Subset (traceKinds kindOf traceWithHttp) policy`。系の仮定 `KindCheck` を外すと結論が成り立たない |
| `traceWithHttp_needs_within` | theorem | `KindCheck declared policy ∧ ¬ WithinDeclared kindOf declared traceWithHttp ∧ ¬ Subset (traceKinds kindOf traceWithHttp) policy`。系の仮定 `WithinDeclared` も外せない |

二つの反例により、系 `events_subset_policy` の二つの仮定はどちらも結論に要る。非空の例により、二つの仮定は空でない列・空でない集合で同時に成り立ち、結論は実際の事象の種類について方針への所属を与える。

## 本番への対応

このモデルは本番へ接続していない。以下は本番の `formal/` を読んで確かめた名前と、確かめていないことを分けた記録である。行番号は基準の版のものである。

### 確かめた名前

| モデル | 本番の名前（`formal/Benitoite/Release/`） | 対応と差 |
|---|---|---|
| `Kind` | `EffName`（`Atom.lean`。`String` の別名）と原子 `Atom.name l` | 本番の効果 `Eff` は名前のほかに行の原子 `Atom.rho i` と Fail の型の列 `fails` を持つ。モデルの種類は名前だけに当たり、行と Fail は扱わない |
| `declared` | 継続の末尾で許すエフェクト `Eb`（`Lemmas/PresHelpers.lean` の `StateTyE P B Eb`）。`StateTy`（`Semantics.lean:647`）は `Eb` に `BuiltinOnly P B Eb`（`Semantics.lean:613`。Fail を含まず、所属する原子は全て組み込みのエフェクトの名前）を課す | 有限の名前の集合への写しは `KindSet.ofList` の形で取れる見込みである。本番の所属は `Eff.mem Eb (.name l)` |
| 包含 `Subset` | `Eff.Sub`（`Effect.lean`。名前と行の所属の含意と、Fail の型の所属の含意の組） | 名前の部分の含意がモデルの `Subset` に当たる |
| 事象 `Ev` | `Event`（`Semantics.lean:62`）の `io (b : PrimName) (ws : List Val) (o : Outcome)` と `release (v : Val) (r : Option ErrKind)` | 遷移 `Step P B s (some ev) s'` の印として現れる |
| `kindOf` | IO の事象: `Builtins.Assumptions` の欄 `io_op`（`Assumptions.lean`）が、IO と終了の組み込みの関数 `b` について `s.opEff = some l` と `s.eff = Eff.single l` を与える。解放の事象: 名前 `stateEff`（`"State"`。`Atom.lean`） | `io b _ _ ↦ l`（`B.sig b` の `opEff`）、`release _ _ ↦ stateEff` が写しの候補である。`kindOf` を関数として定義した本番の名前はない |
| `WithinDeclared` を与える性質 | `effect_soundness`・`effect_soundness_noLamNames`（`Theorems.lean`）は、型のエフェクトが空（`Eff.empty`）の計算について、到達する全ての状態が事象を伴う遷移をしないことを言明する。その証明は `no_event`（`Lemmas/EffectSound.lean:39`）と `steps_preserve`（同 133 行。`Steps` に沿って `StateTyE P B Eb` の `Eb` を保つ）を使う | 本番が今与えるのは、宣言上限が空の場合（事象が一つもない）だけである。これはモデルでは `declared` が空で `traceKinds` が空になる場合に当たる |
| 事象ごとの所属の材料 | `no_event` の証明の中で、IO の事象については `hb.io_op` と `ContTy.end_of_noHandler`（`Lemmas/EffectSound.lean:20`）から `Eff.mem Eb (.name l)` を、解放の事象については `ContTy.state_end`（`Lemmas/ContLemmas.lean:74`）から `Eff.mem Eb (.name stateEff)` を導き、`Eb` が空であることと矛盾させている。IO の遷移 `E_IO`・`E_IOErr`・`E_Exit`（`Semantics.lean:184`〜）は `NoHandler k (.prim b)` を前提にする | 空でない `Eb` について「事象を伴う遷移の種類は `Eb` に属する」を述べる補題の材料は、`no_event` の証明の途中に揃っている |
| 実行の列 | `Steps`（`Semantics.lean:325`）は遷移の印を捨てる。印の列を持つ多段の遷移の関係は、`Release`・`Core` の中に見つからなかった（`inductive Steps` は `Release/Semantics.lean:325` と `Core/Semantics.lean:73` だけ） | モデルの `List Ev` に当たる本番の定義はない |
| 方針と `KindCheck` | 本番の formal に方針の定義はない | モデルだけの概念である |

### 確かめていないこと

- 空でない `Eb` について、事象を伴う遷移の種類が `Eb` に属するという一般の補題（`no_event` の一般化）が、本番の今の前提（`Builtins.Assumptions`・`EffectsOk` など）だけで証明できるか。材料は揃っているように読めるが、書いて検査していない。
- 印の列を持つ多段の遷移を本番に加えたとき、上の補題と `preservationE`（`Lemmas/PresMain.lean:18`）・`steps_preserve` から `WithinDeclared` の本番の形（列の全ての事象の種類が `Eb` に属する）が導けるか。
- 空でない型のエフェクト ε を持つ `main` から始めたときの `Eb` と ε の関係。今の初期状態の補題 `stateTyE_init`・`stateTyE_init_noLamNames` は `Eff.empty` の場合だけを言明する。
- 処理系の Rust の側の実行前の判定がモデルの `KindCheck` に当たるか。処理系のソースは読んでいない。
- 0.0.13 の範囲付きのエフェクト（案4）の下で、種類と対象の組がモデルの `Kind` にどう写るか。対象は第三項（PM20）とその本番の対応で扱う。

これらは本番の主定理を変える作業ではない。本番への接続を行う場合は、別の作業として計画に割り当てる必要がある。この枝では、追加の公理も本番の定義の変更も要しなかった。

## 検査

計画の「work PM10/PM20」の行と「全実検査の計時」の行に従った。`scripts/check.sh` はこの枝では走らせない（依頼の指定）。

| 項目 | 内容 |
|---|---|
| コマンド | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/PermissionKinds.lean > ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/pm10.02/lean-run-01.log 2>&1` |
| Lean | 4.34.1（`formal/lean-toolchain`）、arm64-apple-darwin |
| 終了 | 0（`lean-run-01.exit`） |
| 時間 | `time` の real 0.24 秒（user 0.19 秒、sys 0.09 秒）。外側の経過は 17:56:38〜17:56:39 |
| 最大常駐量 | `/usr/bin/time -l`（macOS）の maximum resident set size の原値 433389568 バイト = 413.31 MiB = 0.404 GiB。lake とその子の lean の一回の実行の全体であり、並行する別のプロセスを含まない |
| sorry の検索 | 出力に `sorry` の一致なし（grep の終了 1）。`sorryAx`・`error`・`warning` も一致なし。ソースにも `sorry`・`axiom`・`admit`・`decide` の類はない（`checks-01.txt`） |
| 公理の一覧 | 宣言 38 件（PM10.01 の 12 件と、この枝で加えた 26 件。theorem 25 件と、それらが使う def・inductive 13 件）の全てに `#print axioms` を置いた。宣言の名前と `#print axioms` の対応の欠けがないことを `checks-01.txt` で確かめた。38 件とも `does not depend on any axioms`。使った公理はない |
| 量化・仮定のレビュー | 担当の自己確認を上の節に書いた。独立のレビューは PM30 の担当である |

## 失敗と修正

なし（初回の実行で終了 0、sorry と公理の一致なし）。編集の途中で、取りまとめのコミットの後にファイルを読み直さずに編集しようとして道具が断ったので、読み直してから同じ編集を行った。内容への影響はない。

## ずれと申し送り

- 計画からのずれはない。
- PM20（第三項）への申し送り:
  - 種類の集合はこのモデルの `KindSet`（述語）と `KindSet.ofList` を同じ形で使える。PM20 は独立の `models/Policy.lean` に置く計画なので、定義を写すか同じ形で定め直す。このファイルを import するかは PM20 の依頼で決める。
  - 判断 18 の「種類を許す記載があり対象が空」の例は、このモデルの `KindCheck` が通る（種類の記載はある）一方で、対象の述語が空のため実行時の対象の判定がどれも通らない形にすると、第一項の判定と第三項の判定の分離を示せる。対象を持たない純粋な計算（このモデルで列が空の場合）と区別する。
  - 許可不足の反例は、このモデルと同じく、仮定のそれぞれを外すと結論が落ちる具体例（deny 優先を外す、共通部分を和に置き換える）を一つずつ置くと、量化と仮定のレビューが容易になる。
  - 証明は `cases` による所属の分解だけで公理なしに閉じた。`simp` は `propext` を使うことがあるので、使う場合は `#print axioms` の結果を確かめる。
- 取りまとめが転記すべき条件: 本番の `effect_soundness` は宣言上限が空の場合だけを与えるので、このモデルの `WithinDeclared` の本番での成立は未確認である（上の「確かめていないこと」）。

## 時間

| 項目 | 内容 |
|---|---|
| 開始・終了 | 17:53 〜 17:58（2026-10-27、JST） |
| 外側の所要 | 約 5 分 |
| 能動時間 | 約 5 分（本番の読解・例と補題の証明・記録）。Lean の検査は 1 秒未満 |
| 上端 2 倍の超過 | なし（見込み 0.5〜1.5時間） |
