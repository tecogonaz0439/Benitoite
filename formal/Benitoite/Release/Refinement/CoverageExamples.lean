import Benitoite.Release.Refinement.CoverageInitial

/-!
# 網羅性の入口の適用例

初期領域ごとに同じ型の受理と拒否を対照させる。空型以外には正常な所属の証人を置く。
-/
namespace Benitoite.Release.Refinement.CoverageExamples
open Coverage

/-- 利用者の宣言を持たないプログラム。 -/
def program : Program where
  defs := fun _ => none
  cons := fun _ => none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

def ctors : DataName → List ConName := fun _ => []

theorem complete : CtorsComplete program ctors := by
  intro c cd h
  cases h

private def yes : Pat := .const (.boolean true)
private def no : Pat := .const (.boolean false)

/-- 省いた Boolean の値は、同じ初期領域に実在する。 -/
theorem boolean_inputs : Inhabits program (.base .boolean) (.const (.boolean true)) ∧
    Inhabits program (.base .boolean) (.const (.boolean false)) := ⟨Inhabits.const (c := .boolean true), Inhabits.const (c := .boolean false)⟩

theorem boolean_accept_reject :
    coverage program ctors closedView (.base .boolean) [yes, no] = .exhaustive ∧
    coverage program ctors closedView (.base .boolean) [yes] = .nonExhaustive [.boolean false] := by constructor <;> rfl

theorem boolean_exhaustive : Exhaustive program (.base .boolean) [yes, no] :=
  coverage_sound _ _ _ _ _ complete boolean_accept_reject.1

/-- 空の篩は、基の型と宣言の表によらず空の腕を受理する。 -/
theorem empty_accept (P : Program) (ctors : DataName → List ConName) (view : CoverageView) (a : Ty) :
    coverage P ctors view (.refined a .falsity) [] = .exhaustive := rfl

theorem month_input : Inhabits program monthType (.const (.integer ⟨12, by decide⟩)) := by
  refine .refined (Inhabits.const (c := .integer ⟨12, by decide⟩)) ?_
  simp [RefinementPossible, monthPredicate, Pred.evalWith, Pred.atomReady, Pred.atomValue,
    termReady, observeAs, integerAs, selfModel, selfObservation, Val.toTerm?, Term.observe,
    Term.interpret, Observation.sort, Integer64Value.toInt]

private def shortMonth : Pat := .range (.integer ⟨1, by decide⟩) (.integer ⟨11, by decide⟩)

theorem month_accept_reject :
    coverage program ctors closedView monthType [monthPattern] = .exhaustive ∧
    (match coverage program ctors closedView monthType [shortMonth] with
      | .nonExhaustive _ => True | _ => False) := by constructor; rfl; trivial

theorem month_coverage : Exhaustive program monthType [monthPattern] :=
  coverage_sound _ _ _ _ _ complete month_accept_reject.1

theorem nonempty_input : Inhabits program (nonemptyType (.base .unit)) (.list [.const .unit]) := by
  refine .refined (.list (.cons (Inhabits.const (c := .unit)) .nil)) ?_
  simp [RefinementPossible, nonemptyPredicate, Pred.evalWith, Pred.atomReady, Pred.atomValue,
    termReady, observeAs, integerAs, selfModel, selfObservation, Val.toTerm?, Term.observe,
    Term.interpret, Observation.sort, Observation.measure, MatchFacts.observeSlots_length,
    Val.toTermSlots_eq_map]

theorem nonempty_accept_reject :
    coverage program ctors closedView (nonemptyType (.base .unit)) [headRestPattern] = .exhaustive ∧
    (match coverage program ctors closedView (nonemptyType (.base .unit)) [.list [] none []] with
      | .nonExhaustive _ => True | _ => False) := by constructor; rfl; trivial

theorem nonempty_coverage : Exhaustive program (nonemptyType (.base .unit)) [headRestPattern] :=
  coverage_sound _ _ _ _ _ complete nonempty_accept_reject.1

theorem length_input : Inhabits program (lengthType (.base .unit) 2) (.list [.const .unit, .const .unit]) := by
  refine .refined (.list (.cons (Inhabits.const (c := .unit)) (.cons (Inhabits.const (c := .unit)) .nil))) ?_
  simp [RefinementPossible, Pred.evalWith, Pred.atomReady, Pred.atomValue,
    termReady, observeAs, integerAs, selfModel, selfObservation, Val.toTerm?, Term.observe,
    Term.interpret, Observation.sort, Observation.measure, MatchFacts.observeSlots_length,
    Val.toTermSlots_eq_map]

theorem length_accept_reject :
    coverage program ctors closedView (lengthType (.base .unit) 2) [exactLengthPattern 2] = .exhaustive ∧
    (match coverage program ctors closedView (lengthType (.base .unit) 2) [exactLengthPattern 1] with
      | .nonExhaustive _ => True | _ => False) := by constructor; rfl; trivial

theorem length_coverage : Exhaustive program (lengthType (.base .unit) 2) [exactLengthPattern 2] :=
  coverage_sound _ _ _ _ _ complete length_accept_reject.1

/-- 値の型付けから篩の導入と網羅性の判定までを、同じ非空の List で合成する。 -/
theorem typed_nonempty_reader (B : Builtins) :
    HasTypeVQ program B StoreTy.empty Qempty [] [] [] (.list [.const .unit]) (nonemptyType (.base .unit)) ∧
      Exhaustive program (nonemptyType (.base .unit)) [headRestPattern] := by
  have ha : Ty.Annotation program [] [] (.list (.base .unit)) := ⟨trivial, trivial, trivial⟩
  have hv : HasTypeVQ program B StoreTy.empty Qempty [] [] [] (.list [.const .unit]) (.list (.base .unit)) :=
    .V_List (.cons (.V_Const trivial) .nil) ha.wf ha.sorted ha.declared
  apply typed_nonempty_coverage hv rfl ha
  · simp [nonemptyPredicate, Pred.Sorted, Term.HasSort, Term.References, Term.Shape, Term.VarsIn,
      Ctx.Readable, Ty.HasSort, Ty.sort?, Measure.input, Measure.output]
  · simp [nonemptyPredicate, Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.Readable,
      Ctx.extend, Ty.shiftV, Ty.core]
  · exact Entails.closed (by decide) (by decide) (by decide)
  · exact complete
  · exact nonempty_accept_reject.1

/-- 構成子を実際に持つ宣言表。 -/
def dataProgram : Program := { program with
  cons := fun c => if c = "D.C" then some ⟨"D", 0, []⟩ else none }

def dataCtors : DataName → List ConName := fun d => if d = "D" then ["D.C"] else []

theorem data_complete : CtorsComplete dataProgram dataCtors := by
  intro c cd h
  simp only [dataProgram] at h
  split at h
  · next he => cases h; simp [dataCtors, he]
  · cases h

theorem data_input : Inhabits dataProgram (.data "D" []) (.con "D.C" [] []) :=
  .con (cd := ⟨"D", 0, []⟩) rfl rfl (by simp) .nil

def openData : CoverageView := fun d => d == "D"

/-- 現在の構成子の列が完全でも、指定した型の将来の形を見落とさない。 -/
theorem data_accept_future :
    coverage dataProgram dataCtors closedView (.data "D" []) [.con "D.C" []] = .exhaustive ∧
    coverage dataProgram dataCtors openData (.data "D" []) [.con "D.C" []] =
      .nonExhaustive [.future "D"] := by constructor <;> rfl

def futureProgram : Program := { dataProgram with
  cons := fun c => if c = "D.Future" then some ⟨"D", 0, []⟩ else dataProgram.cons c }

theorem extension : ConstructorExtension dataProgram futureProgram openData where
  preserve := by
    intro c cd h
    simp only [dataProgram] at h
    split at h
    · next he => cases h; simp [futureProgram, dataProgram, he]
    · cases h
  added := by
    intro c cd hq hp
    simp only [futureProgram] at hq
    split at hq
    · cases hq; rfl
    · rw [hp] at hq; cases hq

theorem future_input : Inhabits futureProgram (.data "D" []) (.con "D.Future" [] []) :=
  .con (cd := ⟨"D", 0, []⟩) rfl rfl (by simp) .nil

/-- 拡張先の値も含め、同じ判定の成功から網羅性を得る。 -/
theorem future_coverage : Exhaustive futureProgram (.data "D" []) [.wild] :=
  usefulWithView_extension_exhaustive dataProgram futureProgram dataCtors openData extension data_complete _ _ rfl

/-- 同じ問いを燃料切れで停止したとき、選択肢は除かれない。 -/
theorem stopped_keeps :
    classify (usefulFuelWithView program ctors closedView 0 [.base .boolean] [[yes]] [yes]) = .unknown ∧
    retainedAlternatives [((0, 0), classify
      (usefulFuelWithView program ctors closedView 0 [.base .boolean] [[yes]] [yes]))] = [(0, 0)] := by constructor <;> rfl

/-- 同じ型の未処置の選択肢を、非網羅とも不明とも言わずに除くことはしない。 -/
theorem kept_alternative_reader : (0, 0) ∈ retained program ctors closedView (.base .boolean)
    [⟨[⟨yes, []⟩], none, .ret (.const .unit)⟩] := by decide

private def booleanArms : List Arm :=
  [⟨[⟨yes, []⟩, ⟨no, []⟩], none, .ret (.const .unit)⟩,
   ⟨[⟨yes, []⟩], none, .ret (.const .unit)⟩]

/-- 閉じた入口は全域を覆い、重複した選択肢の位置と、その説明を返す。 -/
theorem closed_match_report :
    (checkMatch program ctors (.base .boolean) booleanArms).exhaustive = true ∧
    (1, 0) ∈ (checkMatch program ctors (.base .boolean) booleanArms).unreachable ∧
    coveringAlternatives program ctors (.base .boolean) booleanArms 1 0 = [(0, 0)] := by
  constructor; rfl
  constructor; decide
  rfl

/-- 網羅性と選ばれないことは、位置を持つ閉じた入口の同じ結果から得られる。 -/
theorem closed_match_reader :
    Exhaustive program (.base .boolean) (unguardedPats booleanArms) ∧
    (∀ v, Inhabits program (.base .boolean) v → ¬ AlternativeSelected booleanArms 1 0 v) :=
  ⟨checkMatch_exhaustive_sound _ _ _ _ complete closed_match_report.1,
   checkMatch_unreachable_sound _ _ _ _ _ _ complete closed_match_report.2.1⟩

/-- 選ばれない位置の報告は、そこに実在する選択肢と先行する行の判定へ戻せる。 -/
theorem closed_unreachable_lookup :
    ∃ arm alt, booleanArms[1]? = some arm ∧ arm.alts[0]? = some alt ∧
      useful program ctors [.base .boolean]
        ((precedingPats booleanArms 1 0).map (fun p => [p])) [alt.pat] = none :=
  checkMatch_unreachable_lookup closed_match_report.2.1

/-- 全ての長さを許す束縛の左辺は空の List も含めて網羅する。 -/
theorem closed_list_binding : Exhaustive program (.list (.base .unit)) [.list [] (some .skip) []] :=
  irrefutable_sound _ _ _ _ complete rfl

/-- 閉じた有用性の成功は、特定の問いに合致する値を覆う行を返す。 -/
theorem closed_query_reader : ∃ p ∈ [yes, no], (matchVal p (.const (.boolean true))).isSome = true :=
  useful_singleton_none_sound program ctors (.base .boolean) [yes, no] yes complete rfl _
    (Inhabits.const (c := .boolean true)) rfl

/-- 二列の行列にも、任意の値の列を量化した健全性を適用できる。 -/
theorem closed_matrix_reader (vs : List Val)
    (hv : InhabitsAll program [.base .unit, .base .boolean] vs)
    (hm : (matchList [.wild, .wild] vs).isSome = true) :
    ∃ row ∈ [[.const .unit, yes], [.const .unit, no]], (matchList row vs).isSome = true :=
  useful_none_sound program ctors _ _ _ complete rfl vs hv hm

/-- 有限の燃料を明示する入口は、Unit の定数の問いを変数の行で覆える。 -/
theorem finite_query_reader (v : Val) (hv : Inhabits program (.base .unit) v)
    (hm : (matchVal (.const .unit) v).isSome = true) :
    ∃ row ∈ [[Pat.var]], (matchList row [v]).isSome = true := by
  apply usefulFuel_none_sound program ctors complete 3 [.base .unit] [[.var]] [.const .unit] [v] rfl
  · exact .cons hv .nil
  · rw [Coverage.matchList_cons]
    simpa only [matchList, Option.isSome_some, Bool.and_true] using hm

/-- Boolean の別の値は重ならず、同じ値は明示した燃料でも重なる。 -/
theorem closed_overlap_report :
    overlaps program ctors (.base .boolean) yes no = false ∧
    overlapsFuel program ctors 2 (.base .boolean) yes yes = true ∧
    (usefulReport program ctors [.base .boolean] [[yes], [no]] [.wild]).witness = none := by
  constructor; rfl
  constructor <;> rfl

private def monthArm (p : Pat) : Arm := ⟨[⟨p, []⟩], none, .ret (.const .unit)⟩
private def outsideMonth : Pat := .const (.integer ⟨0, by decide⟩)
private def wideMonth : Pat := .range (.integer ⟨0, by decide⟩) (.integer ⟨12, by decide⟩)
private def monthArms : List Arm :=
  [monthArm shortMonth, monthArm monthPattern, monthArm outsideMonth, monthArm wideMonth]

/-- 初期領域全体とその不足を、位置付き報告と束縛の左辺の両方で区別する。 -/
theorem month_match_accept_reject :
    (checkMatchWithView program ctors closedView monthType monthArms).exhaustive = true ∧
    (checkMatchWithView program ctors closedView monthType [monthArm shortMonth]).uncovered.isSome = true ∧
    irrefutableWithView program ctors closedView monthType monthPattern = true ∧
    irrefutableWithView program ctors closedView monthType shortMonth = false ∧
    irrefutableWithView program ctors closedView (.base .integer) monthPattern = false := by
  exact ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- 領域外の候補には覆いの腕を付けず、領域内で覆われる候補には実際の先行腕を返す。 -/
theorem month_alternative_report :
    (checkMatchWithView program ctors closedView monthType monthArms).unreachable = [(2, 0), (3, 0)] ∧
    (checkMatchWithView program ctors closedView monthType monthArms).coveredBy =
      [((2, 0), []), ((3, 0), [1])] ∧
    retained program ctors closedView monthType monthArms = [(0, 0), (1, 0)] := by
  exact ⟨rfl, rfl, rfl⟩

/-- 元の篩付きの型で量化する健全性は、同じ網羅性と位置の報告を読む。 -/
theorem month_match_reader :
    Exhaustive program monthType (unguardedPats monthArms) ∧
    (∀ v, Inhabits program monthType v → ¬ AlternativeSelected monthArms 2 0 v) :=
  ⟨checkMatchWithView_exhaustive_sound _ _ _ _ _ complete month_match_accept_reject.1,
    checkMatchWithView_unreachable_sound _ _ _ _ _ _ _ complete (by rw [month_alternative_report.1]; simp)⟩

/-- 空のListの候補は非空の初期領域外であり、残りの候補だけを保持する。 -/
theorem nonempty_match_report :
    let a := nonemptyType (.base .unit)
    let arms := [monthArm (.list [] none []), monthArm headRestPattern]
    (checkMatchWithView program ctors closedView a arms).exhaustive = true ∧
    (checkMatchWithView program ctors closedView a arms).coveredBy = [((0, 0), [])] ∧
    retained program ctors closedView a arms = [(1, 0)] ∧
    irrefutableWithView program ctors closedView a headRestPattern = true ∧
    irrefutableWithView program ctors closedView a (exactLengthPattern 1) = false := by
  exact ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- 固定長の初期領域は、残りを持つ候補をその長さへ具体化する。 -/
theorem length_match_report :
    let a := lengthType (.base .unit) 2
    let p := Pat.list [.wild] (some .skip) []
    let arms := [monthArm (exactLengthPattern 1), monthArm p]
    (checkMatchWithView program ctors closedView a arms).exhaustive = true ∧
    (checkMatchWithView program ctors closedView a arms).coveredBy = [((0, 0), [])] ∧
    retained program ctors closedView a arms = [(1, 0)] ∧
    irrefutableWithView program ctors closedView a p = true ∧
    irrefutableWithView program ctors closedView a (exactLengthPattern 1) = false := by
  exact ⟨rfl, rfl, rfl, rfl, rfl⟩

end Benitoite.Release.Refinement.CoverageExamples
