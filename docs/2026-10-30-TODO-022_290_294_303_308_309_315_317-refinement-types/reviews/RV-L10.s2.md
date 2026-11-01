# RV-L10.s2 独立レビュー（群 S 後半 L10.44〜L10.51）

**判定: 条件付き可。** 所見は重1・中0・軽4 である。

本番の Lean の定理に誤りは見つからなかった。ただし補助契約 5 の根拠は偽であり、旧の継続型の禁止を読む旧読者が対応表から漏れている。その結果、G03 の入力の Ordinary が E_Op・E_OpFail・E_Meth の経路で得られない（重1）。五つの境界は s2 の差分では変わっていない。重1 の修正は境界に触れ得るので、L20 の G03 に入る前に設計者の判断を要する。

対象はブランチ `m014/l10.s2` の未コミットの作業ツリー、基準は `42a09116fd2442fca93b38a7e18b8138356a8dcc` である。補助入力は `<tmp>/rvl10s2/` に置いた。全件、`cd <repo>/formal && lake env lean -M 12288 <入力>` で終了0、`sorry` なし、公理は `propext`・`Quot.sound`・`Classical.choice` だけである。

## 所見

### 重1: 型引数の Ordinary が V_Op・V_Raise・C_Meth・V_Dict から得られず、G03 の入力が欠ける（五つの境界に触れ得る）

- **場所**: `<repo>/formal/Benitoite/Release/Refinement/TypeVariables.lean` の `Ty.VarsIn`。`l10/s2/signatures.md` の補助契約 5、`l10/s2/results.md` の「補助契約で決めたこと」6、`l10/detail.md`「不要とした旧言明の読者の代替」。
- **問題 1（旧読者の漏れ）**: 旧の `Ty.VarsIn` の `.cont _ _ _ => False` は使われていた。`Release/Lemmas/Preservation.lean` の `closedArgs_of` は `Ty.VarsInList 0 0 _ tys` から `ClosedArgs tys`（WF と非継続）を導く。これを E_Fun・E_Meth・E_Op・E_OpFail と `Ty.subst_wf0` が使う。旧の `HasTypeVQ.substTy` は `hts : ClosedArgs ts'` を要求し、V_Var の場合で `Ty.substAt_notCont` を使う。detail の 12 件の表にはこの読者がない。FND147〜158 は同名の移植として「本群で完了」とされたが、新 VarsIn はこの条件を失っている。
- **問題 2（契約の根拠が偽）**: 契約 5 は、利用者の注釈の適格性を「既存の Annotation/HasKind/Ordinary で検査する」と書く。実際には、Annotation（WF・Sorted・Declared）も `HasKind … .value` も継続型を許す。Ordinary を要求するのは `Admissible` と `PrimitiveAdmissible` の `typeScope` だけである。V_Op は `SatAll` と `SignatureInstance` だけ、V_Con・V_Dict・builder は `TypeArgsKinded` だけ、V_Raise は Annotation だけを持つ。C_Meth は旧規則の `∀ t ∈ ss ++ [τ], WF ∧ ¬cont` に当たる前提を持たない。`SourceScoped` も継続型を拒まない。`sat_unconstrained` はむしろ閉じた WF の継続型を制約なしの型引数として認める。
- **問題 3（G03 への影響）**: `WFImages.ordinary`、`Ty.substAt_wf` の `ho`、既存の `Ty.LeQ.substAt` の前提は正しい要求である。V_Var の型置換の結論は Ordinary なしでは偽である。一方、E_Op の `c.body.substTy ts []`、E_OpFail の `body.substTy [t] []`、E_Meth の `ss ++ ts` にはその入力の供給元がない。`HandlerOperation` の代表は `.op o []` だけなので、この問題が表に出ていなかった。l10/v で V_Con について「Ordinary は補助の入力」と記録された判断も、同じ供給元の問題を残している（`sourceOrd`）。
- **再現**: あり。`rv-s2-t1.lean` は次を証明する。
  - `op_source_scoped`: `.op "o" [k0]`（k0 は継続型）は `SourceScoped`。
  - `op_typed`: `B.CoreAssumptions` だけから閉じた文脈で `.op "o" [k0]` が型付く。
  - `k0_not_ordinary`、`varsIn_accepts_cont`、`annotation_accepts_nested_cont`。
  - `body_typed` と `subst_conclusion_false`: 本体の `.var 0` は `tvar 0` で型付くが、`[k0]` で具体化した結論は、どの型でも成り立たない。
- **未再現の範囲**: 全状態の preservation の反例までは組んでいない。節の本体が `tvar` 型の束縛を読む閉じた状態を作れば届くと読むが、機械では確かめていない。利用者向けの構文の章と言語リファレンスに継続型の記法は見当たらず、利用者が直接書ける形ではない。
- **修正案**:
  1. 既定の案: `TypeArgsKinded` に `k = .value → Ordinary a` を加える（`TypeImagesKinded` と同じ形）。`SignatureInstance` を持つ全規則と V_Con・V_Dict・builder を一箇所で閉じられる。V_Raise の `t`・`e` は別に要る。旧導出の埋め込みでは LegacyInput が Ordinary を供給する必要がある。
  2. 別案: 旧の方式に戻し、`SourceScoped` と `VarsIn` に継続型の禁止を入れ、実行中の型引数の閉性を不変量として保つ。`Ty.varsIn_iff_sourceScoped` も変わる。
  3. どちらの案でも、契約 5・results の 6 を「継続の禁止の担当は未確定で、Ordinary の供給が必要」と直し、detail の旧読者の表に `closedArgs_of`・`ClosedArgs.single` を加える。
- **境界**: 主な定理の前提・結論は s2 では変わっていない。修正は型付けの規則（既存の定義の意味）を変えるので、計画の停止条件に当たる。利用者の書ける形は、案 1 では面が変わらない見込みであるが、取りまとめが確かめる必要がある。

### 軽1: 境界の負例の一部に対の正例がなく、語も食い違う

- **場所**: `l10/s2/boundary.lean` の `kind_none_denies`・`row_variable_denies`。01-12 の `Eff.Allows` の段落。
- **問題**: `kind_none_denies` の `topOnly` には κ があるときの許可の正例がない。`row_variable_denies` が扱うのは行変数 `Eff.row 0` であり、01-12 と契約 6 が述べる範囲変数（`rvar`）の負例ではない。`TopAtoms` の正負例も boundary にない。
- **再現**: 主張自体は正しい。`rv-s2-t3.lean` の `top_allows`・`rvar_denies`・`secrets_denies`・`sigma_matters`・`top_atoms_ignores_fail`・`top_atoms_rejects_based` が通る。
- **修正案**: これらを boundary へ加える。

### 軽2: 弱めた言明の一覧が結果にない

- **場所**: `l10/s2/results.md` の foundation の表。
- **問題**: 同名の行が「完了」と並び、弱めた点が読み取れない。`foundation.lean` の 115 件の照合は `#check` による存在の確認であり、言明の型の照合は `signatures.lean` の 106 件に限られる。
- **再現**: 読めば確定。
- **修正案**: 下の「弱めた言明と利用先の判定」を結果へ写す。「照合」の語を対応先の存在の確認と書き分ける。

### 軽3: 07-04 の工程に寄った書き方

- **場所**: `docs/design/07-quality/07-04-formal-semantics.md` の追加段落。
- **問題**: 「RawWFの層を追加しない」は、設計書のほかの箇所で定義していない語を否定している。「SourceScopedとの一致を定義し」は実際には証明（`Iff.rfl`）である。
- **再現**: 読めば確定。
- **修正案**: 前者を削り、後者を「一致を示し」にする。

### 軽4: L20 へ渡す小さな包装がない

- **場所**: `TypeBounds.lean`。
- **問題**: `Tel.bind_wf`・`Tel.substAt_wf` がなく、`instantiatedTel` の主な利用では `Tel.rawBind_norm_wf` を直接呼ぶ。旧 `Ty.substAt_nil_of_wf` の新形（閉じた型は `a.norm` へ移る）もない。
- **再現**: 足りないのは包装だけである。`rv-s2-t2.lean` の `admissible_instantiated_wf`・`substAt_of_closed` が数行で通る。
- **修正案**: 本群で足すか G03 の入口へ送る。

## 弱めた言明と利用先の判定

| 旧 → 新 | 変化 | 利用先の判定 |
|---|---|---|
| `Ty.shift_of_wf` | 結論を `a` から `a.norm` へ | 足りる。節の型は生の `shiftTypes` なので `Ty.rawShift_of_wf` を使える |
| `Eff.shift_of_wf` | Canonical の前提を外し、結論を `e.norm` へ | 同値 |
| `*.rawBind_rawWF` 三件 | 入力が RawWF から WF へ、結論が正規化後へ、Ordinary・範囲・値の像を追加 | 足りる。二重の生の置換は `rv-s2-t3.lean` の `raw_twice_wf` で閉じる |
| `Ty.bind_wf`・`Eff.bind_wf` | 像の条件が WFImages へ | Ordinary を除き足りる |
| `*.substAt_wf`・`*.subst_wf`・`substList_wf` | `ho` を追加。一方で像の深さは n へ一般化し、値深さを追加 | **Ordinary の供給が重1 で未解決**。ほかは足りる |
| `Eff.allows_norm` | σ を追加 | 足りる。`rv-s2-t4.lean` の `allows_of_covers` で固定した σ の下の被覆の健全性も確認 |
| `Ty.VarsIn` 系 12 件 | 継続の禁止を失う | **重1**。範囲と行の移送は `rv-s2-t3.lean` の `substAt_varsIn` で足りる（行変数なしの場合） |
| `Ty.shift_compareList` | `tysCompare` から木の比較へ | 足りる。新体系に `tysCompare` がない |

## G03・G04 の見通し

- **G03**: WF の基盤は足りる。`rv-s2-t2.lean` で次が通った。
  - `ctx_wf_bindTypes`: `Ctx.WF` の移送。
  - `admissible_instantiated_wf`: Admissible から instantiatedTel の WF（値深さの弱化を含む）。
  - `typeEnvAt_up_agrees`: 項の置換が行う `shiftV` と `WFImages.up` の一致。
  - `tapp_annotation_case`・`apply_formed`: 構成子の像を持つ `Ty.Annotation` の tapp の場合。WF は基盤から、Sorted と Declared は kind と引数から得る。
  足りないのは Ordinary の供給元（重1）である。既存の `Ty.Sorted.typesOnly` と `Ty.Declared.typesOnly` は noTapp を要するので、tapp へ一般化する作業は G03 に残る。LeQ は既存の `Ty.LeQ.substAt` が Ordinary 付きで閉じている。
- **G04**: `rv-s2-t2.lean` の `close_wf`・`ground_term`・`close_wf_ground` により、Ground な捕捉の下で、WF の束縛の型は閉じた WF へ移る。`WFImages` は使える形である。継続の束縛は `Ty.CaptureWF` が潜在効果の WF を持たないので `Ty.bind_wf` を適用できず、`ImageOk` の証拠に頼る。緩い三条件からの全正則性は今回の試行の範囲外で、未確認である。

## 確かめて問題がなかった点

- **件数**: 158 行を機械照合した。16＋43＋31＋68、名前・状態・単位は detail と全行一致。単位の内訳 5+7+7+10+12+8+13+6=68、新規 656 行も一致。
- **対応の内容**: 本群 68 件は旧の言明と読み比べた。名前だけの対応は VarsIn 系の意味の欠落を除いてない。`Eff.memFail_singleFail`・`Eff.eq_of_sub_of_sub`・比較と整列の前提は旧と同じで、Canonical を外していない。
- **補助契約**: RawWF を複製しない判断、WF から Canonical を導かない判断は妥当である。`bad_refined_cont` などの負例で確認した。契約 1〜4・6〜9 に問題はない。契約 5 は重1。
- **旧の整形式**: 旧 `Eff.WF` も原子の範囲を読まない。新 WF への移植で範囲の条件は落ちていない。
- **効果**: `.top` は `.fixed .top` であり、`Allows` は Top の原子も読む。`Sub` と `Covers` の区別は保たれ、σ は `Allows` だけに渡る。
- **移動と深さ**: `substAt` の n+c、cutoff、nv の分離、param と self の up、行像の再置換なし、篩・依存列・外部型の正例は実際に通る。負例は空虚でない。
- **設計書**: 01-12・07-04・用語集は Lean と一致する（軽3 を除く）。
- **境界・証拠**: 主な 10 言明と既存の定義は不変。新しい公理なし。`signatures`・`foundation`・`boundary`・`axioms` を再実行して全件成功、公理依存 473 件。`verification.json` の 25 入力のハッシュが一致。記録に絶対パスなし。既定 `lake build` は 771 ジョブで成功（増分）。
- **作業ツリーの補足**: `effort-ledger.md` に依頼文の 4 ファイル以外の 1 行の追記があるが、これは検証の後に加わった工数の記録であり、定義・言明に関係しない。

## 補助入力

`<tmp>/rvl10s2/rv-s2-t1.lean`（重1 の反例）、`rv-s2-t2.lean`（G03・G04 の正例）、`rv-s2-t3.lean`（効果の正負例と VarsIn・二重置換）、`rv-s2-t4.lean`（固定した σ での被覆の健全性）。

## 取りまとめの追記

2026-11-01。補助の入力は `l10/s2/rv-s2-t1.lean`〜`t4.lean` へ写した。重1は `plan.md` の先頭の判断のとおり案1を採る。軽1〜4 は同じ再開で処置する。

## 再レビュー

2026-11-01。重1 と軽1〜4 の処置を、規則の変更に絞って再確認した。全体の再実行はしていない。

**判定: 条件付き可。** 所見は重0・中1・軽2 である。重1 が示した経路（型引数が最上位で継続型である場合）は閉じた。軽1〜4 も処置を確認した。規則の変更は妥当である。ただし E_OpFail の補題が実際の入力と異なる（再中1）。

補助入力 `<tmp>/rvl10s2/rv-s2-t5.lean` は終了0、`sorry` なし、公理は三つだけである。既定 `lake build` は772ジョブで成功した。`rv-s2-t1.lean` は意図どおり `op_instance`・`op_typed` だけが失敗するようになり、前回の反例が消えたことを示す。

### 再中1: `raise_subst_wf/le` の型引数が E_OpFail と異なる

- **場所**: `formal/Benitoite/Release/Refinement/TypeArgumentRegularity.lean` の `HasTypeVQ.raise_subst_wf`・`raise_subst_le` とその注釈「E_OpFailで使う単一のエラー型の像」。`l10/s2/signatures.md` の同じ署名。
- **問題**: 実際の E_OpFail は `.raise T E'` から `body.substTy [T] []` を作る（Semantics.lean、Step.lean）。T は `raise` の結果型である。補題は `a.subst [e] []`、つまりエラー型 E' で置換しており、言明は真だが E_OpFail の入力の形ではない。`HasFailureClause` の本体の `tvar 0` の像は T である。補題の報告どおりの用途には使えない。
- **再現**: あり。`rv-s2-t5.lean` の `raise_subst_T_wf` は `raise_typeScope` の T 側から `[t]` の形を証明する。`raise_images_differ` は二つの像が別の型になり得ることを示す。
- **修正案**: 二補題を `[t]` へ直し、注釈と署名の照合を更新する。`raise_typeScope` は両方を供給しているので、規則の変更は不要である。

### 再軽1: `iff_of_closedArgs` は閉じた型引数に限られる

- **場所**: 同ファイルの `LegacyTypesInput.iff_of_closedArgs`、`of_closedArgs`。results の同じ主張。
- **問題**: 言明は正しいが、旧 `ClosedArgs` は `Ty.WF 0 0` を含む。多相の本体の中の `.op o [tvar 0]` にはこの補題を使えない。open な旧導出の埋め込みでは、適格な旧導出の範囲を変えないことの根拠として足りない。
- **再現**: あり。`rv-s2-t5.lean` の `closedArgs_rejects_open`。必要なのは NotCont だけで、`iff_of_notCont` が同じ証明で通る。
- **修正案**: 前提を `∀ t ∈ ts, Ty.NotCont t` へ弱める。`Ty.VarsIn` から型列の NotCont を得る補題も添える。

### 再軽2: Ordinary は入れ子の継続を拒まないことを明記していない

- **場所**: 01-12 の `TypeArgsKinded` の段落、results の契約の記述。
- **問題**: `Ordinary` は篩を外した芯だけを読むので、`.list k0` は通る。旧の `VarsIn` は入れ子も拒んでいたが、旧 `ClosedArgs` の `NotCont` は最上位だけだった。したがって不足ではないが、「継続型の型引数が閉じた」という書き方は入れ子まで含むように読める。
- **再現**: あり。`rv-s2-t5.lean` の `nested_op_typed` は `.op "o" [.list k0]` が今も型付くことを示す。`nested_body` は、その像でも tvar を読む本体の置換の結論が成り立つことを示す。`rv-s2-t1.lean` の `annotation_accepts_nested_cont`・`ordinary_accepts_nested_cont` も不変である。
- **害の判定**: 置換の保存には害がない。像が Ordinary なら `Ty.ordinary_bind` で本体の Ordinary が保たれ、`cont` の閉じた値を作る規則もない。全状態の証明では未確認である。
- **修正案**: 最上位の条件であることと、入れ子を拒まない理由を一文で書く。

### 確かめて問題がなかった点

1. **閉じたか**: V_Con・V_Dict・builder は `TypeArgsKinded`、V_Fun・V_Prim・V_Op・V_ExternalRef・C_Meth は `SignatureInstance.kinds` を通る。`Admissible`・`PrimitiveAdmissible` の `typeScope` は別に残る。C_External も `kinds` を持つ。V_ExternalHandle の型引数は Ordinary を持たないが、本体への置換に使われない。`.lam` の注釈の継続は像にならない。
2. **kind と継続**: constructor kind は `constructor_ordinary` で閉じ、`.ctor .list` は `constructor_arg_accepted` で受理される。`resume`・`K_Handle`・`ClauseSig`・`failureContext` は `TypeArgsKinded` を読まず、文脈の継続の扱いは変わっていない。
3. **保存**: `shiftV`・`shiftTypes`・値置換・`norm` の Ordinary は同値の補題で前提なしに閉じる。`ordinary_bind_values` の移動も内容の変更はない。型置換は像が Ordinary であることだけを要する。像に継続を持ち込む経路は `TypeArgsKinded`・`V_Raise`・`typeScope` で塞がれた。
4. **主な10言明**: 差分の宣言行を自分で比べた。値移動・型移動・値置換・narrowing の本体の変更は `V_Raise` の場合の追随だけで、宣言の行に変更はない。旧の主定理は不変である。判断そのものは狭まったが、これは計画の先頭の決定の範囲である。
5. **E_Op・E_Meth**: `op_subst_*` の `ts`、`method_subst_*` の `ss ++ ts` と `es` は Semantics の遷移と一致する。`dict_typeScope` は `V_Sub` の下でも `ts` を返す。
6. **五つの境界**: 定義の変更は `TypeArgsKinded`・`TypeArgsKindedAt`・`V_Raise`・Legacy の入力三つだけである。新しい公理はない。提供範囲と精密な外部状態に変更はない。利用者の文書と構文の章に継続型の記法はなく、書ける形は変わらない見込みである。Rust 側の照合は取りまとめに残る。

### G03 の見通し

重1 の入力不足は E_Op・E_Meth で解消した。E_OpFail は再中1 の修正だけで揃う。残りは本体全体の型置換の族と、tapp の Sorted/Declared の一般化である。`typeScope` の入口は `Closure.pure` の一引数に限られる（`StateTyE.operation_typeScope`）ので、捕捉のある閉包と複数引数は `op_typeScope` と ImageOk から組み立てる必要がある。方式の障害は見つかっていない。

## 取りまとめの追記（再レビューの処置）

2026-11-01。補助の入力は `l10/s2/rv-s2-t5.lean` へ写した。再中1は `raise_subst_wf/le` を結果型 `T` の置換へ直す。再軽1は `iff_of_notCont` へ弱める。再軽2は、`Ordinary` が最上位だけを見ることを判断として明示する。旧 `ClosedArgs` の `NotCont` も最上位だけであり、入れ子の継続は値として作れないので、規則を強めない。全状態で害がないことの確認は G03 の入力とする。再レビューはこれで閉じる。
