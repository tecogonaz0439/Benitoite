# L00.08b: 採用定義の最終の配置と、採らなかった候補の削除

2026-10-27、作業 L00.08b。plan「作業 L00.08」の手順のうち、採択後の配置と削除を行った。設計者の回答は README「設計者の決定（2026-10-27、L00 の骨格の一括の問い）」（[questions.md](questions.md) の27の問いをすべて推す案）である。本番の定義（`Release`・`Surface`・`Builtins.Assumptions` の既存の構成子と主定理）は切り替えていない（L10 以降の仕事）。L10 以降が拡張だけで進められるよう、格納方式によらない骨格を `*Examples` でない最終のモジュールと名前空間へ置き、模型はそれを直接使う形に直した。

## 採用定義の一覧

| モジュール | 名前空間 | 定義 | L10 以降での扱い |
|---|---|---|---|
| `Benitoite/Scope/Domain.lean`（`Std` だけを import） | `Benitoite.Scope.Domain` | `Word`、`PathPattern`・`NamePattern`（`Matches`・`matches?`・`MatchesRev`）、`Family`・`IPAddr`・`CIDR`（`WF`・`Mem`・`PrefixMem`・`hi`）、`IPPattern`（`normalize`・`Canonical`）、`HostTarget`・`HostPattern`、`Port`・`PortRange`・`Endpoint`・`EndpointPattern`、`Kind`・`Target`、`Range`（`kind?`・`FitsKind`・`Mem`・`normalize`）、整形式性の述語（`Range.WF`・`Range.Canonical` など）。本作業で `Range.Sub`（意味の包含。模型から移した）・`Range.MemK`（種類に相対的な所属）・`Range.FitsKinds`（範囲の列と種類の列）と補題を加えた | L10.2 は被覆の判定・健全性・反射・推移、prefix と区間の所属の一致を足す（L00.02 の義務）。L40 で `Checked.Scope` が本モジュールを import し、重複した整形式性の述語を置き換える（問 17） |
| `Benitoite/Scope/Signature.lean`（`Domain` だけを import） | `Benitoite.Scope.Signature` | 範囲の位置 `Ix`（`fixed`・`rvar`、明示の Top の構築関数 `Ix.top`、具体化 `Ix.inst`、範囲の変数の個数の整形式性 `Ix.WF`）、IO の形 `IOShape`、観測の条件 `ShapeTargets`（値の型によらない。`io_target` の内容）、範囲の具体化の許容 `RangeAdmissible`（種類・整形式性・項目の制約）と補題 | L10.1 は案 (i) で本番の `Atom.name` と `Ty.opaque` に `Ix` の引数を加え、旧の綴りを `Ix.top` で書く（問 1・2）。L20 は `Ty.WF` に範囲の変数の文脈を足して `Ix.WF` を使い（問 3）、`PrimSig` に範囲の変数の種類と `IOShape` を加え、具体化の許容に `RangeAdmissible` を使う（問 4・5）。L20.3 は `CoreAssumptions` と `TargetAgreement` を本番の型の上で定め、`io_target` の結論を `ShapeTargets` にする（問 7〜11） |
| `Benitoite/Scope/Inference.lean`（`Domain`・`Interval.BindingScope`・`Interval.Identity` を import） | `Benitoite.Scope.Inference` | 呼び出しの同定 `Key`、抽象値 `Bound`・`Origin`・`ScopeFact`・`AbsArg`、事実と値の対応 `FactModels`・`ArgsModel`、規則の表 `ScopeRule`・`ScopeTable`・`RuleSound`・`TableSound`、一つの評価関係 `EvalScope`・`absApply`・`apply_sound`、局所状態 `ScopeState`（`empty`・`extend`・`forgetAll`・`readLocal`）と対応の補題、必須の判定 `requiredIndex`・`requiredIndex_fact`、Range と別の成分を持つ `LocalState` | L40 は本番の具体の値で `FactModels` を具体化し、標準の宣言の規則（検査・射影・拡大）を表の項目と `RuleSound` の補題で足す（問 14）。予算の計上点・忘却の費用・上限の値は L40 と R20（問 24） |
| `Benitoite/Scope/TopCompat.lean`（`Release.Effect` だけを import） | `Benitoite.Scope.TopCompat` | 旧の原子を Top の範囲の原子へ写す対応 `TopEmbedding`、一般化した効果 `GEff`（構造上の包含 `Sub`・`norm`・`union`・`eq_of_sub_of_sub` など）、変換 `TopEmbedding.lift` と構造補題、旧の言明を系として取り戻す `old_*` の4件 | L10.1 は本番の新しい原子の型で `TopEmbedding` を具体化し、旧の効果の補題を Top の互換の系として取り戻す。意味の被覆は別の関係として L10.3 で定める（問 13） |
| `Benitoite/Interval/BindingScope.lean`（import なし） | `Benitoite.Interval` | `BindingScope`・`idAt`・`fresh` と補題3（定義を変えずに `Interval/RangeState.lean` から移した） | 区間解析と Scope の局所解析の共通の土台（問 15） |
| `Benitoite/Release/Lemmas/EffectSound.lean` | `Benitoite.Release` | `stateTyE_init_eff`（模型から移した。言明と証明は変えていない） | L30 の到達先の対象健全性が初期の同じ ε を固定するのに使う（問 16） |

一般化した点: 模型では観測の条件が模型の値 `Val` に、局所解析が模型の値 `CVal` と区間の事実 `Interval.RangeLocalFact` に固定されていた。採用定義では、値から対象を取り出す関数（`ShapeTargets` の `target?`）、具体の値の型と対応（`FactModels V`）、Range の事実の型（`LocalState RF`）を引数にした。模型はこれらを元の型で具体化しており、模型の定理の言明の意味は変わっていない。

## 模型だけの定義の扱い

模型のモジュールは既定の import に残し、採用定義を直接使う非 Top の例と Top の互換の例として保つ。次の定義は本番と同じ名前か本番の写しであり、採用定義にしない。L10 以降は本番の定義を変えて同じ役割を持たせ、模型の定義を本番から import しない。

| 模型のモジュール | 模型だけの定義 | L10 以降で置き換える本番の定義（段） |
|---|---|---|
| `Scope/SignatureExamples.lean` | `VTy`・`VTy.inst` | `Release.Ty`（`opaque` に `Ix`。L10.1）と型代入に並ぶ範囲の代入（L20） |
| 同 | `Atom`・`Atom.inst`・`Atom.ofOld` | `Release.Atom.name l ix`（L10.1）。`Atom.ofOld` は `Ix.top` を使う明示の構築関数 |
| 同 | `Val`・`HasTypeV`・`HasTypeVs`・`HasTypeV.widen` | `Release.Val` に検査済みの対象の値（NV）、`HasTypeVQ` に所属を前提に持つ葉の規則（NT、案 A。問 6。L20.1） |
| 同 | `Entry`（`rkinds`・`nranges`・`inst`）・`PKind` | `PrimSig` に範囲の変数の種類と `IOShape`、`PrimSig.inst`（L20.2） |
| 同 | `Table`（`effKind`・`valKind`・`admitsR`・`delta`・`ioResponse`）・`Table.isResourceTy` | `Builtins` の同じ役割の欄と、資源の判定を Top の添字に限る定義（問 19。L20） |
| 同 | `RangeAdmissible`（模型の版）・`opListed`・`shapeOk` | 本番の具体化の許容と、`io_op` の内容の形の検査（L20.3） |
| 同 | `CoreAssumptions`・`TargetAgreement`・`Assumptions` | 本番の型の上の S1 の構造体（L20.3） |
| 同 | `EffAllows`・`target_sound`・`io_response_typed` | 本番の `allows` と対象健全性（L30。[L00.08b-target-statements](../reviews/L00.08b-target-statements.md)） |
| 同 | `FieldNew`・`FieldOld`・`fieldNew_iff_old`・`fieldNew_extend` | 問 18 の仮定の行を受け入れた根拠の補題。本番の欄の量化の変更（L20.3）の点検に使う |
| 同 | `clauseIndex`・`clause_arg_typed` | 本番の節の添字 S の規則（L30） |
| 同 | 例の項目と表（`fileIn`・`readTextIn` など・`exampleTable`・`checkPathDelta`・`widenDelta`） | 本番の署名表の項目（L20）と組み込みの関数（R30）。公開名は問 22 の表 |
| `Scope/TargetExamples.lean`（L00.08b の追加の作業で消した） | 観測を持つ小さな機械と例の表の全て（下の「削除」） | 本番の `Event`・`Step`・`Oracle`（O1。L20.4）、四つの主定理（L20〜L30）、本番の対象健全性（L30）。例は [reviews/L00.08b-target-statements.md](../reviews/L00.08b-target-statements.md)「L30 の義務: 本番の定義の上に置き直す例」で L30 が置き直す |
| `Scope/InferenceExamples.lean` | `CVal`・`Parsers`・`checkedModels`・`resultModels`・`factModel`・`models`・`checkRun`・`checkRule`・`patternRule`・`valueRule`・文の小さな言語（`Arg`・`EvalArg`・`Step`・`StepEval`・`absStep`・`absSteps`）・`RangedLocalState` と小例 | 本番の具体の値・表層の構文から局所解析の段への対応・標準の宣言の規則（L40） |
| `Scope/CompatExamples.lean` | `embI`（案 (i) の L00.01 の模型の原子での具体化）・`SemanticExample` | 本番の原子での具体化（L10.1）。`semCovers_not_eq` は判断 5 の反例として残す |
| `Scope/SwitchExamples.lean` | `fileWrite`・`write_obs_of_shape`・`removeName`・`handledBound`・`UserOp`・`ixNoVar`・`vtyNoRVar`・`UserOp.NoRVar`・`ValueTyping`（案 A の `TyA`）・`embIx` と例 | `removeName`・`handledBound` は本番の `handled` と節の効果の計算（L30。L00.07 の申し送り 5）。`UserOp` は `Release.OpDecl`。`vtyNoRVar` は `Ix.WF 0` を使う `Ty.WF`（L20）。`TyA` は `HasTypeVQ` の葉の規則（L20.1） |
| `Scope/RepresentationExamplesI.lean` | 採用した案 (i) の L00.01 の模型（最小の範囲 `ScopeRange`、原子・効果・不透明型の対応、対の符号の単射性） | 採用定義ではない。範囲は `Scope.Domain.Range` に置き換わった。L10.1 で原子の符号の単射性を本番へ写すときの参考（`pair_injective`）。L00.07 の申し送り 4 のとおり、採らなかった側（案 (ii)）だけを消し、本ファイルは変えていない |

## 直した言明（RV-L00 中1・中2・軽7）

| 指摘 | 直した箇所 | 内容 |
|---|---|---|
| 中1: 対象健全性の言明が操作の名前を持たない | 本番の言明の案（[reviews/L00.08b-target-statements.md](../reviews/L00.08b-target-statements.md)）、模型の `TargetExamples.StepTargetSound`（後に模型ごと消した） | 結論を、事象の操作の署名の `opEff` の名前 l を通す形（`∃ sg l, B.sig b = some sg ∧ sg.opEff = some l ∧ …`）にした。模型の `StepTargetSound` も `step_target_sound` と同じ形（`∃ e l, T.sig ev.b = some e ∧ e.opEff = some l ∧ …`）にした。`name_matters` が、上限に `File.Read["/**"]` を足しても `File.Write` の名前では `/etc/passwd` を許さないことを示した（模型を消した後は L30 の置き直す例の表に残す）。L30 の義務の表に `obs`・`effKind`・`allows`・`TA` の意図した定義を固定した |
| 中2: Top の所属が種類を見ない | `Domain.Range.MemK`（新規）、模型の `SignatureExamples.EffAllows`・`target_sound`、本番の言明の案 | 種類に相対的な所属 `Range.MemK k r t := t.kind = k ∧ r.Mem t` を置いた。`EffAllows K eff l t` は名前 l の種類 k（`K l = some k`）について `R.MemK k t` を求める。`target_sound` の旧 Top の腕は、`ShapeTargets` の種類の条件と形の検査の `effKind l = some k` から `Range.top.MemK k t` を導く（自明な所属で閉じない）。単一の対象の腕は値の型付けの `valKind o = some t.kind` と形の検査の `valKind o = some k` から種類を導く。`top_kind_relative` が、`File.Write` の名前だけの上限はエンドポイントの対象を許さないことを示した（同上） |
| 軽7: `RangeAdmissible` が種類の一致を一般の条件に持たない | `Signature.RangeAdmissible`（新規）、模型の `Entry`・`shapeOk`・`RangeAdmissible` | 項目に範囲の変数ごとの種類 `rkinds` を持たせ（`nranges` は `rkinds` の長さ）、具体化の許容に `Range.FitsKinds rs rkinds` を入れた。形の検査は単一の対象の形で `rkinds = [k]`、旧の形で `rkinds = []` を求める。表の制約 `admitsR` の `FitsKind` の項は要らなくなったので消した。`writeTextIn_not_endpoint` が、`admitsR` を問わずエンドポイントの範囲で `File.writeTextIn` を具体化できないことを示す |

未証明の本番の言明は theorem として先置きしていない。本番の言明の案は問 16 の決定どおり reviews/ の文書に置き、Lean の写しを一時ファイルで型検査した（`reachable_of_step` は一段の言明を引数に取る定理として証明できた。[target-statements.lean](target-statements.lean)・[target-statements.log](target-statements.log)）。

## 移動

| 宣言 | 元 | 先 |
|---|---|---|
| `stateTyE_init_eff` | `Scope/TargetExamples.lean`（`Benitoite.Scope.TargetExamples`） | `Release/Lemmas/EffectSound.lean`（`Benitoite.Release`）。言明と証明は同じ |
| `BindingScope`・`BindingScope.idAt`・`BindingScope.fresh`・`fresh_idAt`・`fresh_distinct`・`fresh_valid` | `Interval/RangeState.lean` | `Interval/BindingScope.lean`。名前（`Benitoite.Interval.BindingScope`）と定義は同じ。`Interval/RangeState.lean` が新しいモジュールを import し、ほかの利用側（`Environment`・`Range`・`Flow`・`BudgetRange`）は推移的な import のまま変更なし |
| `Ix`・`Ix.inst`・`Ix.inst_nil`・`IOShape` | `Scope/SignatureExamples.lean` | `Scope/Signature.lean` |
| `ShapeTargets` | 同 | `Scope/Signature.lean`。値から対象を取り出す関数を引数にした |
| `Range.Sub` | 同（`Benitoite.Scope.SignatureExamples.Range.Sub`） | `Scope/Domain.lean`（`Benitoite.Scope.Domain.Range.Sub`） |
| `Key`・`Bound`・`Origin`・`ScopeFact`・`AbsArg`・`AbsArg.Models`・`ArgsModel`・`ScopeRule`・`RuleSound`・`ScopeTable`・`ruleAt`・`TableSound`・`EvalScope`・`absApply`・`evalScope_unidentified`・`apply_sound`・`ScopeState` と `Models`・`empty`・`extend`・`forgetAll`・`readLocal`・`empty_models`・`forgetAll_models`・`readLocal_models`・`extend_models`・`requiredIndex`・`LocalState`・`LocalState.toScope`・`requiredIndex_range_independent` | `Scope/InferenceExamples.lean` | `Scope/Inference.lean`。値の型と対応（`FactModels`）、Range の事実の型を引数にした。模型の `Origin.CheckedModels`・`Origin.ResultModels`・`ScopeFact.Models` は `checkedModels`・`resultModels`・`factModel` と改名して模型に残した（採用定義の名前空間に模型の定義を置かないため）。`requiredIndex_sound` は模型に残し、採用定義の `requiredIndex_fact` から導く |
| `TopEmbedding` と補題5・`GEff` と補題・`lift` と補題・`old_*` の4件 | `Scope/CompatExamples.lean` | `Scope/TopCompat.lean` |

## 削除

採用しなかった模型の記録（L00.01〜.07・L00.06b・L00.06c の results.md と差分）は消していない。

| ファイル | 消した宣言 | 理由 |
|---|---|---|
| `Scope/RepresentationExamplesII.lean`（ファイルごと） | 48: `Scope`・`Scope.WF`・`Scope.Admits`・`Scope.covers`・`Scope.covers_sound`・`EffDesc`・`OpaqueDesc`・`Atom`・`Ty`・`Atom.ofRelease`・`Atom.toRelease?`・`Atom.toRelease_ofRelease`・`Atom.ofRelease_injective`・`Atom.eq_ofRelease_of_toRelease`・`Atom.toRelease_scoped`・`liftAtoms`・`liftAtoms_ofRelease`・`liftAtoms_scoped`・`Ty.ofReleaseOpaque`・`Ty.ofReleaseOpaque_injective`・`Sig`・`Ty.withIndex`・`Sig.inst`・`Sig.inst_top`・`Sig.inst_names`・`Sig.inst_opEff`・`Sig.inst_params_length`・`Sig.inst_of_target_none`・`Table`・`Table.isResourceTy`・`Table.isResourceTy_index`・`Table.callSig`・`Table.handled`・`Table.handled_scope`・`pathIn`・`writeTextInSig`・`writeTextSig`・`table`・`dataTree`・`callSig_same_key`・`effects_independent_of_scope`・`dataTree_admits_file`・`dataTree_covers_exact`・`dataTree_not_database`・`dataTree_wf`・`handled_example`・`lift_old_effect_excludes_scoped`・`lift_old_effect_keeps_top`（名前空間 `Benitoite.Scope.RepresentationExamples.CandidateII`） | 採らなかった格納方式 (ii) の模型（問 1） |
| `Benitoite.lean` | `import Benitoite.Scope.RepresentationExamplesII` の一行 | 同上 |
| `Scope/CompatExamples.lean` | `embII`、`embII` を使う `example` 一つと `#guard` 二つ、`import Benitoite.Scope.RepresentationExamplesII` | 比較のためだけの案 (ii) の具体化。`example` は `embI` で同じ言明を確かめる形に直した |
| `Scope/SignatureExamples.lean` | `DescII`・`AtomII`・`Atom.toII`・`AtomII.toI`・`AtomII.inst`・`Atom.toII_toI`・`AtomII.toI_toII`・`Atom.toII_inst`（「案 (ii) の記述との対応」の節） | 比較のためだけの案 (ii) との対応 |
| `Scope/TargetExamples.lean` | `argObs_raw` | 採らなかった観測の置き方 O3 の反例（問 8） |
| 同 | `ShapeTargetsLoose`・`shapeTargets_loose`・`shapeTargetsLoose_nil`・`obs_mem_of_loose` | 採らなかった空の観測の案 E2（問 9） |
| 同 | `ReleaseStepTargetStatement`・`ReleaseReachableTargetStatement`・`reachable_of_step`、`import Benitoite.Release.Lemmas.EffectSound` | 本番の言明の案は直して reviews/ の文書へ移した（問 16）。模型から `Release` の import がなくなった |
| `Scope/SwitchExamples.lean` | `oldTop_union_empty_II` | 案 (ii) の埋め込みの例（L00.07 の申し送り 4）。`Ix` の原子の埋め込み `embIx` の `oldTop_union_empty_Ix` に置き換えた |
| 同 | `ValueTyping` の案 B・C: `ConstB`・`ConstB.type`・`ConstTy`・`ValB`・`TyB`・`exactOf`・`ConstB.typeExact`・`TyC`・`tyB_canonical`・`tyB_widen`・`tyB_old_conclusion`・`tyC_not_tree` | 採らなかった値の所属の置き方（問 6）の比較 |

### `TargetExamples` のモジュールの削除と `SwitchExamples` の 1〜4 節（L00.08b の追加の作業）

問 16 の推す案（「模型のモジュールは消す」）のとおり、`Scope/TargetExamples.lean` をファイルごと消し、既定の import（`Benitoite.lean`）から外した。消した宣言は 64（上の表で先に消した 9 を除く）: `argObs`・`argObs_mem`・`obs_mem_of_input_and_agreement`・`AtomCovered`・`EffCovered`・`atomCovered_nil`・`effAllows_of_covered`・`inst_eff_nonempty`・`Call`・`Ev`・`CallTy`・`StTy`・`Step`・`Steps`・`progress`・`preservation`・`steps_preserve`・`effect_soundness`・`effect_soundness_steps`・`step_target_sound`・`reachable_target_sound`・`Atom.widenTop`・`TopOnly`・`widenTop_topOnly`・`stTy_widenTop`・`widened_allows_any`・`sendOld`・`sigOf`・`sigOf_cases`・`tableBase`・`mkTable`・`shapeOk_writeTextIn`・`shapeOk_sendOld`・`shapeOk_printLine`・`core_mkTable`・`goodTable`・`target_goodTable`・`assumptions_goodTable`・`dataTreeA`・`writeCall`・`epsData`・`dataTree_wf`・`writeCall_ty`・`writeCall_ty_mk`・`good_write_obs_mem`・`endpointA`・`endpointB`・`sendCall`・`epsHttpTop`・`sendCall_ty`・`redirect_step`・`endpointA_ne_B`・`redirect_allowed`・`outsideTarget`・`badTable`・`outside_not_mem`・`bad_core_and_arg_mem`・`bad_step_escapes`・`bad_no_target_agreement`・`StepTargetSound`・`target_not_from_core`・`stepTargetSound_of_assumptions`・`name_matters`・`top_kind_relative`。L30 が本番の定義の上に置き直す例は [reviews/L00.08b-target-statements.md](../reviews/L00.08b-target-statements.md)「L30 の義務: 本番の定義の上に置き直す例」に名前と中身を書いた。

`SwitchExamples` の 1〜4 節の宣言ごとの扱い。「書き直した」は、`TargetExamples` の表 `goodTable`・機械（`Call`・`Step`・`CallTy`）を使わず、採用定義（`Scope.Domain`・`Scope.Signature` の `ShapeTargets`・`RangeAdmissible`）と、残る模型 `SignatureExamples` の値の型付け・表 `exampleTable`・具体化を使う形にしたことを指す。IO の観測についての言明は、事象の遷移ではなく、観測の条件 `ShapeTargets`（`io_target` の内容）を満たす観測について述べる形に弱めた。

| 節 | 宣言 | 扱い |
|---|---|---|
| 共通 | `mem_path_kind` | 残した（`Domain` だけ） |
| 共通 | `fileWrite`・`pathIn_typed_iff` | 書き直した（`goodTable.valKind` を `exampleTable.valKind` に） |
| 共通 | `goodTable_valKind_pathIn` | 消して、同じ内容の `exampleTable_valKind_pathIn` を足した |
| 共通 | `writeAt` | 消した（機械の呼び出し） |
| 共通 | `writeAt_ty` | 消した。具体化の許容の部分を `writeTextIn_admissible`、効果の部分を `writeTextIn_eff` として足した。上限での呼び出しの型付けは L30 の置き直す例 |
| 共通 | `writeAt_obs` | 消して、観測の条件と値の型付けだけから同じ結論（観測は引数の対象一つで R に種類に相対的に属する）を出す `write_obs_of_shape` を足した。事象の遷移からの導出は L30 の置き直す例 |
| 共通 | `dataTreeA`・`outsideTarget`・`dataTree_wf` | `TargetExamples` から写して足した（例の対象と整形式性） |
| 1 | `checkPathDelta_ok`・`pp0`・`pt0`・`#guard` 2 | 残した |
| 1 | `check_then_write`・`check_then_write_example` | 書き直した（引数の型付け・具体化した効果・観測の条件を満たす観測が検査した対象一つであること） |
| 1 | `minimal_then_write` | 書き直した（局所解析の最小例の値が `PathIn["/data/**"]` の型を持ち、具体化が許されること。上限での型付けは L30 の置き直す例） |
| 2 | `valA`・`widen_admissible`・`widen_same_value`・`widen_not_admissible` | 残した |
| 2 | `valA_narrow`・`widen_typed`・`widen_then_write_same_target` | 書き直した（`exampleTable.valKind`、観測の条件） |
| 3 | `removeName`・`handledBound`・`logsTree`・`logT`・`bodyWrite`・`outerLog`・`#guard` 2・`logsTree_wf`・`outerForward` | 残した |
| 3 | `captured_arg_typed`・`outerLog_excludes_data` | 書き直した（`exampleTable` の `valKind`・`effKind`） |
| 3 | `log_clause_obs` | 書き直した（具体化した効果が外側の上限と一致し、具体化が許され、観測の条件を満たす観測が `/logs/**` に属する） |
| 3 | `forward_clause_ty` | 消して、`forward_clause`（具体化した効果が外側の上限と一致し、引数が S の型を持つ）を足した |
| 3c | `UserOp`・`UserOp.atom`・`reportsTree`・`saveOp`・`bodyReport`・`outerSave`・`#guard` 2・`outerSave_no_user`・`reportsTree_wf` | 残した |
| 3c | `saveOp_not_builtin` | 書き直した（`goodTable` を `exampleTable` に） |
| 3c | `save_clause`・`save_example` | 書き直した（具体化した効果と観測の条件） |
| 3c | `ixNoVar`・`vtyNoRVar`・`UserOp.NoRVar`・`#guard` 3・`inst_of_noRVar`・`saveOp_params_inst`・`rvar_uninhabited` | 残した |
| 3c | `rvar_atom_uncovered` | 消した（`TargetExamples.AtomCovered` にだけ依る）。L30 の置き直す例の表に載せた |
| 4 | `printLine_inst` | 残した |
| 4 | `print_obs_nil` | 書き直した（観測の条件の対象なしの形から観測が空） |
| 4 | `printCall`・`epsMixed`・`printCall_ty`・`writeCall_ty_mixed`・`mixed_ty`・`mixed_progress`・`mixed_reachable`・`mixed_not_empty` | 消した（機械の状態・進行・到達先にだけ依る）。L30 の置き直す例 |

ほかの変更: `SignatureExamples` の `Entry.nranges` の欄を、範囲の変数ごとの種類 `rkinds` の欄と、その長さを返す関数 `Entry.nranges` に替えた（軽7）。`SignatureExamples` の `exampleTable.admitsR` から、`RangeAdmissible` が受け持つようになった `FitsKind` の項を消した。`SwitchExamples` に、範囲の位置 `Ix` を持つ原子の埋め込み `embIx` と非 Top の効果の例（`nonTopIx`・`nonTopIx_not_lifted`・`nonTopIx_union_empty`・`oldTop_union_empty_Ix`）を足した（plan「非 Top の例と Top 互換の補題は同じ採用定義を直接使う」）。

## 名前と配置を選んだ理由

1. 対象の領域は `Benitoite.Scope.Domain` のまま置き、名前空間を固定した（RV-L00 軽8）。`HostPattern`・`PathPattern` は `Benitoite.Checked.Scope` に、`Range` は `Benitoite.Checked.Range`（区間）に同じ短い名前があるが、名前空間が違うので、`open Benitoite.Scope.Domain` をしない限り短い名前は衝突しない。名前の解決は現在の名前空間から外側へ探すので、`Benitoite.Checked.Scope` の中の `HostPattern` は旧の定義を指し、`Scope.Domain.HostPattern` は新しい定義を指す。両方を `open` すると `HostPattern` が曖昧になる。この三点を一時ファイルで確かめた（[names-check.lean](names-check.lean)・[names-check.log](names-check.log)。最後の誤りは曖昧さを示すための意図したもの）。そこで `Checked` と `Interval` のモジュールでは `open Benitoite.Scope.Domain` をせず修飾して書くことを、`Domain.lean` の先頭のコメントに決まりとして書いた。改名しなかった理由: 定着した別の英語の名前が見つからず、新しい名前を作ると造語になる。問 26（DET-06）の JSON の形も `Range` の構成子への対応で決まっている。整形式性の述語の重複は、問 17 の決定どおり L40 で `Checked.Scope` が本モジュールを import して一つにまとめる。
2. 新しい三つのモジュールの名前は、模型の名前から `Examples` を除いた `Signature`・`Inference`・`TopCompat` とした。`Benitoite.Scope` の下には `Domain` と模型の名前空間しかなく、既存の名前空間と重ならない。`Range` を名前に含めず、区間解析の「Range の予算」と紛れないようにした。局所解析を `Local` と呼ばなかったのは、`Release.LocalScope`・`Release.LocalTyping` があるためである。
3. import の向き: `Domain` と `Signature` は `Release` を import しないので、L10.1 で `Release.Atom`・`Release.Types` が `Signature` を import して `Ix` を構成子の引数に使える（循環しない）。`TopCompat` は旧の効果を写すために `Release.Effect` を import するので、`Release.Effect` 自身からは import できない。L10.1 で本番の原子による具体化は `Release.Effect` より後のモジュールに置く。`Inference` は呼び出しの同定 `OperationKey` のために `Interval.Identity`（`Surface.Syntax` を import）を import するが、区間解析の評価関係（`Interval.Eval`）と警告の解析は import しない。
4. `BindingScope` は名前 `Benitoite.Interval.BindingScope` と定義を変えずに `Interval/BindingScope.lean` へ移した。名前空間を変えないので既存の利用側の名前は変わらず、`Interval.RangeState` に import を一行足すだけで済んだ。`Scope.Inference` は `Interval.RangeState`（と、その import する `Interval.Eval`）を import しない。
5. 問 16 の「模型のモジュールは消す」は、取りまとめの判断（設計者は推す案の文言どおりに選んだ）に従い、`TargetExamples` のモジュールごと消すことと読んだ。初めは `Release` を import する部分だけを除いたが、追加の作業でモジュールを消し、`SwitchExamples` の 1〜4 節を、採用定義の観測の条件 `ShapeTargets` と `SignatureExamples` の値の型付け・具体化の許容だけで書き直すか消した（上の「削除」の宣言ごとの表）。消した非 Top の例は、L30 が本番の定義の上に置き直す義務として reviews/ の文書に残した。
