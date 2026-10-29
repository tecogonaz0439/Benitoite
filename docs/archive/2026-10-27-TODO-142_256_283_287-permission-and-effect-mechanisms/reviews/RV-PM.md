# RV-PM: 権限の判定の独立小モデル（PM10・PM20）のレビュー

2026-10-27。PM30.01〜.03 の独立レビューとして、Opus 5.5 のサブエージェント（effort medium）が、ブランチ `m013/pm10` の HEAD `58c7fbed46886619a7d746951e1567f7620ef2ab`（基準 `10099543`）の `models/PermissionKinds.lean`・`models/Policy.lean` と `pm10.01`〜`pm20.04` の results.md を読んだ。実装の担当とは別の担当である。ファイルと git の状態は変えていない。応答を取りまとめが保存した（作業用のディレクトリの絶対パスは `<wt>` に置き換えた）。

## 結論

重大な指摘はない。定義は判断 18 の意味をそのまま表し、量化・仮定の向き・反例の論理に、結論を誤らせる欠陥はない。直すべき点は、仮定を使っていない一般の補題が二つあることと、二つのモデルに写した定義を保守する手順が検査の行に入っていないことである。残りは記述と件数の小さな誤りである。

## A. 読めば確定する指摘

### 中1: 仮定を使わず、結論が仮定の言い換えになっている補題

- 場所: `Policy.lean` の `Policy.kindCheck_passes_but_target_fails`。
- 問題: 結論の第一成分 `p.kinds (kindOf e)` は、仮定 `hEmpty : EmptyTargets p (kindOf e)` の第一成分そのものである。仮定 `hCheck`（KindCheck）と `hWithin` は結論のどこにも要らず、第二成分も `not_traceAllowed_of_emptyTargets` だけで出る。「種類の判定は通る」は結論ではなく仮定なのに、pm20.04 の一覧は分離を示した言明のように読める。判断 18 の分離を実際に支えているのは、KindCheck を証明している例 `Examples.emptyTargets_example` である。
- 修正案: 補題を `not_traceAllowed_of_emptyTargets` に一本化し、分離は `emptyTargets_example` が示すと記録に明記する。または、`KindCheck declared p.kinds` が `allow`・`deny` に依らないことを言明に入れ、一覧の説明を「仮定した KindCheck の下で」に直す。

### 軽1: 使わない仮定が言明に残っている

- 場所: `Policy.lean` の `Policy.deny_overrides_of_allow_all`。
- 問題: 仮定 `_hAll` を証明で使っていない。中身は `deny_overrides` と同じである。
- 修正案: 残すなら一覧の要約を「`deny_overrides` の特殊化（新しい内容なし）」と書く。消して、例の `not_permits_secretFile` を `deny_overrides` から直接導いてもよい。

### 軽2: 誤った和の docstring が実際の定義と食い違う

- 場所: `Policy.lean` の `Policy.wrongUnion` の docstring。
- 問題: 「誤りを許可の扱いだけに限る」とあるが、`kinds` も論理和で `inter`（論理積）と違う。pm20.04/results.md の「違いは種類の記載と許可の扱いだけ」は正しい。反例の効き目は `permits` が `kinds` を見ないので変わらない。
- 修正案: docstring を results.md に合わせる。または `kinds` を `inter` と同じ論理積にして、誤りを本当に `allow` だけに限る。

### 軽3: 「KindCheck を外すと落ちる」反例が一つの定理になっていない

- 場所: `PermissionKinds.lean` の `Examples.traceWithHttp_outside_policy`。
- 問題: docstring は「KindCheck を外すと結論が成り立たない」と言うが、この定理が示すのは `¬ Subset …` だけである。反例には `traceWithHttp_within_declared` と `declaredWithHttp_rejected` の組み合わせが要る。対になる `traceWithHttp_needs_within` は三つを一つの連言にしてある。
- 修正案: `¬ KindCheck declaredWithHttp policy ∧ WithinDeclared … ∧ ¬ Subset …` の連言の定理を置き、PM30 の表はそれを指す。

### 軽4: 第一項の非空の例が退化している

- 場所: `PermissionKinds.lean` の `Examples.declared`・`policy`・`trace`。
- 問題: `declared` と `policy` は同じ列で、`kindCheck_example` は `exact hk` で閉じる。`trace` に現れる種類も宣言上限と一致し、推移の系が三つの集合が等しい場合でしか例示されていない。系は一般に証明済みなので、正しさの問題ではない。
- 修正案: 方針を真の上位集合にする。または列が宣言上限の一部の種類だけを含むようにする。

### 軽5: WF を外せないことの反例がない

- 場所: `Policy.lean` の `Policy.traceAllowed_kinds`・`permits_kind`。
- 確認: `WF`（allow → kinds）の向きは正しく、空対象を表せる。
- 問題: WF を外すと結論が落ちる例がない。外すと、記載のない種類の事象が対象の判定を通る。
- 修正案（任意）: 記載のない種類に allow を持つ方針の例を一つ置く。

### 軽6: 件数の誤り

- `pm10.01/results.md`: 「theorem 8 件と定義 4 件」は、実際は theorem 7 件・def 5 件である。
- `pm10.02/results.md`: 「theorem 25 件、def・inductive 13 件」は、実際は 24 件・14 件である。
- 合計（12 件・38 件）と網羅は正しく、内訳だけの誤りである。

### 軽7: 確かめていない主張と推測

- `pm10.02/results.md` の `kindCheck_iff_all_traces` の説明の「仮定を外すと…同値は一般には成り立たない」は Lean で示していない。示さないなら「（未証明）」と書く。
- `Policy.lean` の propext のコメントは、「match の compile が propext に依存した」と事実のように書く。pm20.02 の記録が確かめたのは、欄を書き換えたら依存が消えたことだけで、原因の特定は推測にとどまる。

### 軽8: 例の名前がまぎらわしい

- 場所: `Policy.lean` の `Examples.Target.host`。`fileRead` の対象に `host` という名前を使っている。
- 修正案（任意）: `otherFile` などにする。

## B. 実行して確かめた点

- `cd <wt>/formal && lake env lean -M 12288 ../docs/…/models/<ファイル>` を実行した。`PermissionKinds.lean` は終了 0、出力 38 行の全てが `does not depend on any axioms`、最大常駐量 434 MB、real 0.27 秒。`Policy.lean` は終了 0、出力 80 行の全てが公理なし、最大常駐量 440 MB、real 0.30 秒。両方とも出力に `sorry`・`error`・`warning` はない。記録の件数とソースの SHA-256 は pm20.04 の記録と一致した。
- `#print axioms` の網羅: 宣言の完全名と `#print axioms` の対象を突き合わせ、両ファイルとも欠けはない。`Policy.lean` で余分に見えた 3 件は構造体の欄の射影である。ソースに `sorry`・`axiom`・`native_decide`・`implemented_by` はなく、`admit` の一致は名前の一部だけである。
- 写した定義の同一性: pm20.04 の手順を再現して終了 0 だった。写しの `KindCheck` を向きの逆転に変えると、末尾の `rfl` の行で終了 1 となり、不一致を捕まえることを確かめた。

## C. 本番との対応の記述

pm10.02 が引く本番の名前と行番号（`Event`、`E_IO`、`Steps`、`BuiltinOnly`、`StateTy`、`no_event`、`steps_preserve`、`ContTy.end_of_noHandler`、`ContTy.state_end`、`preservationE`、`Assumptions.io_op`、`stateEff`）は、すべて `formal/Benitoite/Release/` の今の内容と一致した。

「本番の `effect_soundness` が与えるのは宣言上限が空の場合だけ」は正しい。`effect_soundness`・`_noLamNames` は `Eff.empty` の型付けを前提にし、全ての到達状態について「事象を伴う遷移なし ∧ `¬UnhandledOp`」を結論する。`stateTyE_init` も `Eff.empty` に限る。`steps_preserve` は任意の `Eb` で状態の型付けを保つが、それだけでは「事象の種類 ∈ Eb」を与えない。

モデルを本番へ接続済みとする記述や、実行時の拒否・サーバ・OS・非干渉性を証明したと読める記述はない。

## D. 二つのモデルに写した同じ定義

### 中2: 同一性の確かめが検査の手順に入っていない

- 場所: plan.md の「work PM10/PM20」の行。pm20.01・pm20.04 の申し送り。
- 問題: 同一性の確かめは pm20.04 が任意で加えた手作業で、検査の行にない。一時ファイルを作るコマンドも results.md の文中にしかない。片方だけを直しても、各モデルの単独の検査は通ってしまう。
- 修正案: (a) plan の検査の行に連結と `same-defs-tail.lean` の検査を加え、どちらかのモデルを変えたときに必須にする。(b) 連結のコマンドを固定の小さなスクリプトとして改造のディレクトリに置く。(c) 写しをやめて二つのモデルを一つのファイルにまとめる。確かめの方法そのもの（`@X = @Y := rfl` と `#check`）は妥当である。

## E. 問題がなかった点

- 第一項の系 `events_subset_policy` の量化と仮定。二つの仮定はどちらも外せない（反例 `traceWithHttp_needs_within` と軽3の組み合わせ）。
- `kindCheck_iff_all_traces` が実行前の判定の必要性を示している（仮定 `hRealized` は妥当）。
- 第三項の `permits = allow ∧ ¬deny` と、deny 優先が allow に条件を付けずに成り立つこと。
- `inter` の判定の両向きの特徴付けと、整形式の保存。
- `EmptyTargets` を独立の欄 `kinds` で表し、空の列（純粋な計算）と区別していること。
- 例と反例が非空で、許す例と拒否する例が同じ方針の下に両方あること。
- `wrongUnion_not_narrowing` は例の型について ¬∀ を示し、results.md の説明もその区別のとおりであること。
- 本番を import しない、`formal/` を変えない、公理を使わないこと。手元の絶対パスと docs/todo へのリンクがなく、用語が README の決定とぶつからないこと。

## PM30.04 へ渡す点

1. モデルは本番へ接続していない。`WithinDeclared` は仮定で受けている。本番が今与えるのは、型のエフェクトが `Eff.empty` の場合に事象が一つもないことだけである（`effect_soundness`）。
2. 空でない宣言上限について本番で `WithinDeclared` を言うには、印の列を持つ多段の遷移（本番の `Steps` は印を捨てる）、`no_event` を空でない `Eb` へ一般化した補題、`main` の型のエフェクト ε と `Eb` の関係の三つが足りない。どれも未証明・未定義であり、本番の主定理を変える作業なので別の計画に割り当てる必要がある。
3. `kindOf` に当たる本番の関数はない。候補の写し（`io b ↦ opEff`、`release ↦ stateEff`）と、行の原子・Fail を扱わないことの差を記録する。
4. 方針・`KindCheck`・対象の判定（`TraceAllowed`）は本番の formal に存在しない。本番の parser・実行時の拒否による停止・サーバ・OS・非干渉性・Rust の側の実行前の判定との対応は確かめていない。
5. 範囲付きのエフェクト（案4）の対象と、モデルの `Kind`・`Target` の写しの関係は扱っていない。判断 18 のとおり、第四項は中心の対象健全性へ計上する。
6. 中1の補題を、「分離」を一般に証明した根拠として記録に引かない。分離の根拠は例 `emptyTargets_example` である。
7. 写した定義の同一性の確かめは、検査の手順として固定するまで、保守上の未閉の危険として記録する（中2）。
