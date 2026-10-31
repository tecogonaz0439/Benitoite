import Lean
import Benitoite.Release.Refinement.MatchFacts
import Benitoite.Release.Refinement.LogicSound

namespace Benitoite.Release.Refinement.MatchPathsBoundary
noncomputable section

def B : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => True,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => True,
    refGet := "get", refSet := "set" }
def cd : ConDecl := ⟨"Boxed",0,[.base .integer]⟩
def P : Program :=
  { defs := fun _ => none, cons := fun _ => some cd, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }

inductive Case where
  | trueLit | falseLit | integerLit | characterLit | stringLit
  | integerRange | characterRange | emptyList | box
  deriving DecidableEq

def input : Case → Ty
  | .trueLit | .falseLit => .base .boolean
  | .integerLit | .integerRange => .base .integer
  | .characterLit | .characterRange => .base .character
  | .stringLit => .base .string
  | .emptyList => .list (.base .unit)
  | .box => .data "Boxed" []
def pat : Case → Pat
  | .trueLit => .const (.boolean true)
  | .falseLit => .const (.boolean false)
  | .integerLit => .const (.integer ⟨3,by decide⟩)
  | .characterLit => .const (.character 'a')
  | .stringLit => .const (.string "ok")
  | .integerRange => .range (.integer ⟨1,by decide⟩) (.integer ⟨5,by decide⟩)
  | .characterRange => .range (.character 'a') (.character 'z')
  | .emptyList => .list [] none []
  | .box => .con "Box" [.wild]
def alts (c : Case) : List Alt := [⟨pat c,[]⟩]
def yesTest : Case → PathTest
  | .trueLit => .literal (.boolean true)
  | .falseLit => .literal (.boolean false)
  | .integerLit => .literal (.integer 3)
  | .characterLit => .literal (.character 'a')
  | .stringLit => .literal (.string "ok")
  | .integerRange => .integerRange 1 5
  | .characterRange => .characterRange 'a' 'z'
  | .emptyList => .empty
  | .box => .constructor "Box"
def noTest : Case → PathTest
  | .emptyList => .nonempty
  | .box => .excluded "Box"
  | c => .negated (yesTest c)
def chosen (c : Case) (yes : Bool) : PathTest := if yes then yesTest c else noTest c

def ctx (c : Case) : Ctx := Ctx.extend [] (input c)
def fact (c : Case) (yes : Bool) : Pred := (chosen c yes).predicate (.var 0)
def out (c : Case) (yes : Bool) : Ty := .refined (.base .boolean) ((fact c yes).shiftV 1 0)

macro "metadata" : tactic => `(tactic|
  simp [ctx,Ctx.extend,input,chosen,yesTest,noTest,fact,out,PathTest.predicate,PathLiteral.predicate,
    Ty.WF,Ty.WFList,Ty.Sorted,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Ty.shiftV,
    Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ty.HasSort,Ty.sort?,Ordinary,Ty.Declared,
    Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Comparison.Allowed,
    sortedTys,declaredTys,Pred.shiftV,predBind,termBind,termBind?,shiftIndex,Measure.input,Measure.output])

theorem input_annotation (c : Case) : Ty.Annotation P [] (ctx c) (input c) := by
  cases c <;> refine ⟨?_,?_,?_⟩ <;> try metadata
  refine ⟨⟨"Box",cd,rfl,rfl⟩,?_⟩
  intro c d hc _; cases Option.some.inj hc; rfl

theorem out_annotation (c : Case) (yes : Bool) : Ty.Annotation P [] (ctx c) (out c yes) := by
  cases c <;> cases yes <;> refine ⟨?_,?_,?_⟩ <;> try metadata
  all_goals exact ⟨"Boxed",⟨[],.var rfl rfl⟩,cd,rfl,rfl⟩

theorem test_wf (c : Case) (yes : Bool) : Pred.WellFormed P [] (ctx c) (fact c yes) := by
  cases c <;> cases yes <;> refine ⟨?_,?_,?_⟩ <;> try metadata
  all_goals exact ⟨"Boxed",⟨[],.var rfl rfl⟩,cd,rfl,rfl⟩

theorem matched_tests (c : Case) : matchedTests (alts c) = [yesTest c] := by cases c <;> rfl
theorem excluded_tests (c : Case) : excludedTests (alts c) = [noTest c] := by cases c <;> rfl

theorem facts_wf (c : Case) : FactsWF P [] (ctx c)
    (pathFacts (some (.var 0)) (matchedTests (alts c) ++ excludedTests (alts c))) := by
  rw [matched_tests,excluded_tests]
  intro p hp
  change p ∈ [fact c true,fact c false] at hp
  rcases List.mem_cons.mp hp with rfl | hp
  · exact test_wf c true
  · rcases List.mem_cons.mp hp with rfl | hp
    · exact test_wf c false
    · cases hp

theorem pat_typed (c : Case) : PatTy P (pat c) (input c) [] := by
  cases c
  all_goals first | exact .P_Const rfl | exact .P_RangeInt | exact .P_RangeChar | skip
  · exact .P_List .nil .nil (by intro h; rfl)
  · exact .P_Con (cd := cd) (ts := []) rfl rfl
      (by intro t ht; simp [cd] at ht; subst ht; trivial) (.cons .P_Wild .nil)

theorem alts_typed (c : Case) : AltsTy P (alts c) (input c) [] := by
  refine ⟨by simp [alts],?_,?_,?_⟩
  · cases c <;> rfl
  · intro alt h; cases Option.some.inj h; cases c <;> rfl
  · intro alt h
    rcases List.mem_cons.mp h with rfl | h
    · exact ⟨[],pat_typed c,.refl _,rfl⟩
    · cases h

theorem open_fact (c : Case) (yes : Bool) : ((fact c yes).shiftV 1 0).open (.boolean true) = fact c yes := by
  cases c <;> cases yes <;>
    simp [fact,chosen,yesTest,noTest,PathTest.predicate,PathLiteral.predicate,Pred.shiftV,Pred.open,
      predBind,termBind,termBind?,shiftIndex,openingEnv]

theorem body (c : Case) (yes : Bool) {Φ : List Pred} {R : Option Ty} {L : LocalCtx}
    (hf : fact c yes ∈ Φ) : HasTypeCQ P B StoreTy.empty Qempty [] (ctx c) Φ R
      (.ret (.const (.boolean true))) (out c yes) Eff.empty L := by
  have ha := out_annotation c yes
  refine .C_Return (.V_Refine (.V_Const trivial) rfl rfl ha.sorted.2 ha.wf.2.1 ?_ ha.declared.1 ha.declared.2)
  rw [open_fact]
  exact .hyp (List.mem_append_right _ hf)

def counter : Case → Bool → Observation
  | .trueLit, true => .boolean false | .trueLit, false => .boolean true
  | .falseLit, true => .boolean true | .falseLit, false => .boolean false
  | .integerLit, true => .integer 4 | .integerLit, false => .integer 3
  | .characterLit, true => .character 'b' | .characterLit, false => .character 'a'
  | .stringLit, true => .string "no" | .stringLit, false => .string "ok"
  | .integerRange, true => .integer 9 | .integerRange, false => .integer 3
  | .characterRange, true => .character '0' | .characterRange, false => .character 'm'
  | .emptyList, true => .listValue [some .unitValue] | .emptyList, false => .listValue []
  | .box, true => .dataValue "Other" [none] | .box, false => .dataValue "Box" [none]

theorem body_requires_fact (c : Case) (yes : Bool) : ¬ HasTypeC P B StoreTy.empty [] (ctx c) [] none
    (.ret (.const (.boolean true))) (out c yes) Eff.empty := by
  intro h
  have hv := h.ret_value rfl
  have he : Entails ((ctx c).facts ++ []) (((fact c yes).shiftV 1 0).open (.boolean true)) := by
    apply Entails.of_conjuncts
    intro q hq
    rw [Pred.open,Pred.conjuncts_bind] at hq
    obtain ⟨r,hr,rfl⟩ := List.mem_map.mp hq
    exact hv.facts rfl r (by
      rw [out,Ty.assume_refined (by simp [Ty.Ordinary,Ordinary,Ty.core])]
      exact List.mem_append_right _ hr)
  rw [open_fact] at he
  have hh := he.sound (fun _ => some (counter c yes)) (by
    intro q hq
    have hempty : (ctx c).facts = [] := by cases c <;> rfl
    simp only [hempty,List.nil_append,List.not_mem_nil] at hq)
  have hfalse : (fact c yes).interpret (fun _ => some (counter c yes)) = false := by
    cases c <;> cases yes <;> decide
  rw [hfalse] at hh
  cases hh

theorem wild_typed (c : Case) : AltsTy P [⟨.wild,[]⟩] (input c) [] :=
  ⟨by decide,rfl,(by intro alt h; cases Option.some.inj h; rfl),
    (by intro alt h; rcases List.mem_cons.mp h with rfl | h; exact ⟨[],.P_Wild,.refl _,rfl⟩; cases h)⟩

def arms (c : Case) (yes : Bool) : List Arm := if yes then
  [.mk (alts c) none (.ret (.const (.boolean true))), .mk [⟨.wild,[]⟩] none (.escape (.const .unit))]
  else [.mk (alts c) none (.escape (.const .unit)), .mk [⟨.wild,[]⟩] none (.ret (.const (.boolean true)))]

theorem arms_typed (c : Case) (yes : Bool) :
    HasTypeArmsQ P B StoreTy.empty Qempty [] (ctx c) [] (some (.base .unit)) (some (.var 0))
      (arms c yes) (input c) (out c yes) Eff.empty := by
  have ha := out_annotation c yes
  have hzero : ∀ (b : HasTypeCQ P B StoreTy.empty Qempty [] (ctx c)
      (pathFacts (some (.var 0)) (matchedTests (alts c))) (some (.base .unit))
      (if yes then .ret (.const (.boolean true)) else .escape (.const .unit)) (out c yes) Eff.empty []),
      HasTypeCQ P B StoreTy.empty Qempty [] (bindParams (ctx c) [])
        (liftMany 0 (pathFacts (some (.var 0)) (matchedTests (alts c)) ++ []))
        ((some (.base .unit)).map (Ty.shiftV 0 0))
        (if yes then .ret (.const (.boolean true)) else .escape (.const .unit))
        ((out c yes).shiftV 0 0) (Eff.empty.shiftV 0 0) (localExtend 0 []) := by
    intro hb
    simpa only [List.length_nil,List.append_nil,bindParams,List.reverse_nil,List.map_nil,List.nil_append,liftMany_eq,
      Ty.shiftV_zero,Eff.shiftV_zero,localExtend,id_eq,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),
      show Pred.shiftV 0 0 = id from funext (fun p => p.shiftV_zero 0),Option.map_id,List.map_id] using hb
  cases yes
  · refine .plain (alts_typed c) (facts_wf c) ?_ ?_
    · apply hzero
      exact .C_Escape (.V_Const trivial) ha
    · refine .plain (wild_typed c) (by intro p hp; cases hp) ?_ (.nil ha)
      have hb := body c false (Φ := [fact c false]) (R := some (.base .unit)) (L := []) List.mem_cons_self
      simpa [bindParams,liftMany_eq,localExtend,matchedTests,patternTest?,pathFacts,excluded_tests,fact,chosen,
        Ty.shiftV_zero,Eff.shiftV_zero,Pred.shiftV_zero,
        show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0)] using hb
  · refine .plain (alts_typed c) (facts_wf c) ?_ ?_
    · apply hzero
      exact body c true (by rw [matched_tests]; exact List.mem_cons_self)
    · refine .plain (wild_typed c) (by intro p hp; cases hp) ?_ (.nil ha)
      have hb : HasTypeC P B StoreTy.empty [] (ctx c)
          (pathFacts (some (.var 0)) (excludedTests (alts c))) (some (.base .unit))
          (.escape (.const .unit)) (out c true) Eff.empty := .C_Escape (.V_Const trivial) ha
      simpa [bindParams,liftMany_eq,localExtend,matchedTests,patternTest?,pathFacts,excluded_tests,
        Ty.shiftV_zero,Eff.shiftV_zero,Pred.shiftV_zero,
        show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0)] using hb


theorem source_typed (c : Case) (yes : Bool) : HasTypeC P B StoreTy.empty [] (ctx c) [] (some (.base .unit))
    (.match (.var 0) (arms c yes)) (out c yes) Eff.empty := by
  have hv : HasTypeV P B StoreTy.empty [] (ctx c) [] (.var 0) (input c) :=
    .V_Var (by cases c <;> rfl) (by cases c <;> trivial)
  have hsort : ∃ sort, (input c).HasSort sort := by
    cases c
    all_goals first | exact ⟨.boolean,rfl⟩ | exact ⟨.integer,rfl⟩ | exact ⟨.character,rfl⟩ |
      exact ⟨.string,rfl⟩ | exact ⟨.list,rfl⟩ | exact ⟨.data,rfl⟩
  obtain ⟨sort,hs⟩ := hsort
  obtain ⟨t,ht,hst⟩ := hv.observation hs
  have ht' : t = .var 0 := (Option.some.inj ht).symm
  subst t
  exact .C_Match hv (obs := some (.var 0)) (by intro t ht; cases ht; exact ⟨rfl,sort,hst⟩)
    (arms_typed c yes) (by
      intro v hv
      cases yes <;> exact ⟨.wild,by simp [arms,unguardedPats],by simp [matchVal]⟩)

def actual (c : Case) (yes : Bool) : Val := match c with
  | .trueLit => .const (.boolean yes)
  | .falseLit => .const (.boolean (!yes))
  | .integerLit => .const (.integer (if yes then ⟨3,by decide⟩ else ⟨4,by decide⟩))
  | .characterLit => .const (.character (if yes then 'a' else 'b'))
  | .stringLit => .const (.string (if yes then "ok" else "no"))
  | .integerRange => .const (.integer (if yes then ⟨3,by decide⟩ else ⟨9,by decide⟩))
  | .characterRange => .const (.character (if yes then 'm' else '0'))
  | .emptyList => .list (if yes then [] else [.const .unit])
  | .box => .con (if yes then "Box" else "Other") [] [.const (.integer ⟨3,by decide⟩)]

def observed (c : Case) (yes : Bool) : Term := ((actual c yes).toTerm?).getD (.integer 0)

theorem actual_observed (c : Case) (yes : Bool) : (actual c yes).toTerm? = some (observed c yes) := by
  cases c <;> cases yes <;> rfl

theorem actual_root (c : Case) (yes : Bool) : MatchFacts.RootShape P (input c) (actual c yes) := by
  cases c <;> cases yes <;> simp only [input,actual,MatchFacts.RootShape,Bool.not_true,Bool.not_false,ite_true,ite_false]
  all_goals first | exact ⟨_,rfl,rfl⟩ | exact ⟨_,rfl⟩ | exact .inl ⟨_,_,_,cd,rfl,rfl,rfl⟩

theorem actual_match (c : Case) : firstAlt (actual c true) (alts c) = some [] := by cases c <;> rfl

theorem actual_failure (c : Case) : firstAlt (actual c false) (alts c) = none := by cases c <;> rfl

theorem observed_wf (c : Case) (yes : Bool) : ((chosen c yes).predicate (observed c yes)).WF 0 ∧
    ((chosen c yes).predicate (observed c yes)).Sorted [] none := by
  cases c <;> cases yes <;> constructor <;>
    simp [chosen,yesTest,noTest,observed,actual,Val.toTerm?,Val.toTermSlots,PathTest.predicate,PathLiteral.predicate,
      Pred.WF,Pred.VarsIn,Term.VarsIn,varsInSlots,varsInSlot,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,
      Comparison.Allowed,Measure.input,Measure.output]

/-- 成功・失敗の事実は計算で結論を与えず、本番の健全性の補題を通す。 -/
theorem actual_matched_fact (c : Case) :
    ((yesTest c).predicate (observed c true)).evalClosed = some true := by
  exact MatchFacts.matched_evalClosed_true (actual_match c)
    (by rw [matched_tests]; exact List.mem_cons_self) (actual_observed c true)
    (observed_wf c true).1 (observed_wf c true).2

theorem actual_excluded_fact (c : Case) :
    ((noTest c).predicate (observed c false)).evalClosed = some true := by
  exact MatchFacts.excluded_evalClosed_true (alts_typed c) (actual_root c false) (actual_failure c)
    (by rw [excluded_tests]; exact List.mem_cons_self) (actual_observed c false)
    (observed_wf c false).1 (observed_wf c false).2

/-- 欄のリテラルの失敗から根を除くと偽になる。 -/
theorem constrained_field_counterexample :
    firstAlt (.con "Box" [] [.const (.integer ⟨4,by decide⟩)])
      [⟨.con "Box" [.const (.integer ⟨3,by decide⟩)],[]⟩] = none ∧
    excludedTests [⟨.con "Box" [.const (.integer ⟨3,by decide⟩)],[]⟩] = [] ∧
    (Pred.not (.constructorIs (.dataValue "Box" [some (.integer 4)]) "Box")).evalClosed = some false :=
  ⟨rfl,rfl,by decide⟩

theorem constrained_field_not_entailed :
    ¬ Entails [] (.not (.constructorIs (.dataValue "Box" [some (.integer 4)]) "Box")) := by
  intro h
  have hh := h.sound (fun _ => none) (by intro p hp; cases hp)
  change false = true at hh
  cases hh

-- パターンとして許されない種類から、暗黙に事実を増やさない。
example : pathLiteral? (.decimal 1 0) = none := rfl
example : pathLiteral? (.byte 1) = none := rfl
example : patternTest? (.const (.integer8 3)) = none := rfl
example : excludedTests [⟨.con "Box" [.con "Nested" []],[]⟩] = [] := rfl


namespace OrPattern
def alts : List Alt := [⟨.const (.integer ⟨1,by decide⟩),[]⟩,⟨.const (.integer ⟨3,by decide⟩),[]⟩]
def test : PathTest := .either (.literal (.integer 1)) (.literal (.integer 3))
def predicate : Pred := test.predicate (.var 0)
def Out : Ty := .refined (.base .boolean) (predicate.shiftV 1 0)
abbrev Γ : Ctx := ctx .integerLit

theorem tests : matchedTests alts = [test] ∧ excludedTests alts =
    [.negated (.literal (.integer 1)),.negated (.literal (.integer 3))] := ⟨rfl,rfl⟩

theorem annotation : Ty.Annotation P [] Γ Out := by
  refine ⟨?_,?_,?_⟩ <;>
    simp [Out,predicate,test,ctx,Ctx.extend,input,PathTest.predicate,PathLiteral.predicate,
      Ty.WF,Ty.Sorted,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Ty.shiftV,
      Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ty.HasSort,Ty.sort?,Ordinary,
      Ty.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,
      Pred.shiftV,predBind,termBind,termBind?,shiftIndex]

theorem alts_typed : AltsTy P alts (.base .integer) [] := by
  refine ⟨by decide,rfl,(by intro a h; cases Option.some.inj h; rfl),?_⟩
  intro a ha
  rcases List.mem_cons.mp ha with rfl | ha
  · exact ⟨[],.P_Const rfl,.refl _,rfl⟩
  · rcases List.mem_cons.mp ha with rfl | ha
    · exact ⟨[],.P_Const rfl,.refl _,rfl⟩
    · cases ha

theorem facts_wf : FactsWF P [] Γ (pathFacts (some (.var 0)) (matchedTests alts ++ excludedTests alts)) := by
  intro p hp
  change p ∈ [predicate,.not (.eq (.var 0) (.integer 1)),.not (.eq (.var 0) (.integer 3))] at hp
  simp only [List.mem_cons,List.not_mem_nil,or_false] at hp
  rcases hp with rfl | rfl | rfl
  all_goals refine ⟨?_,?_,?_⟩ <;>
    simp [predicate,test,ctx,Ctx.extend,input,PathTest.predicate,PathLiteral.predicate,
      Pred.WF,Pred.VarsIn,Term.VarsIn,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,
      Ty.HasSort,Ty.sort?,Ordinary,Ty.core,Ty.shiftV,Pred.Declared,Term.Declared,Ctx.Readable,Ctx.declarationSelf]

theorem body : HasTypeC P B StoreTy.empty [] Γ [predicate] none
    (.ret (.const (.boolean true))) Out Eff.empty := by
  refine .C_Return (.V_Refine (.V_Const trivial) rfl rfl annotation.sorted.2 annotation.wf.2.1 ?_
    annotation.declared.1 annotation.declared.2)
  have hp : Entails (Γ.facts ++ [predicate]) predicate := .hyp (List.mem_append_right _ List.mem_cons_self)
  simpa [predicate,test,PathTest.predicate,PathLiteral.predicate,Pred.shiftV,Pred.open,predBind,termBind,termBind?,shiftIndex,openingEnv] using hp

theorem arm : HasTypeArmsQ P B StoreTy.empty Qempty [] Γ [] none (some (.var 0))
    [.mk alts none (.ret (.const (.boolean true)))] (.base .integer) Out Eff.empty := by
  refine .plain alts_typed facts_wf ?_ (.nil annotation)
  simpa [tests.1,bindParams,liftMany_eq,localExtend,Ty.shiftV_zero,Pred.shiftV_zero,Eff.shiftV_zero,
    show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),pathFacts,predicate] using body

theorem body_requires_or : ¬ HasTypeC P B StoreTy.empty [] Γ [] none
    (.ret (.const (.boolean true))) Out Eff.empty := by
  intro h
  have hf := (h.ret_value rfl).facts rfl (predicate.shiftV 1 0)
    (by change _ ∈ [predicate.shiftV 1 0]; exact List.mem_cons_self)
  have hh := hf.sound (fun _ => some (.integer 2)) (by intro p hp; change p ∈ [] at hp; cases hp)
  change false = true at hh
  cases hh

theorem success_first : firstAlt (.const (.integer ⟨1,by decide⟩)) alts = some [] := rfl
theorem success_second : firstAlt (.const (.integer ⟨3,by decide⟩)) alts = some [] := rfl

theorem second_fact_true : (test.predicate (.integer 3)).evalClosed = some true :=
  MatchFacts.matched_evalClosed_true success_second (by rw [tests.1]; exact List.mem_cons_self) rfl
    (by trivial) (by trivial)

theorem failure : firstAlt (.const (.integer ⟨2,by decide⟩)) alts = none := rfl

theorem excluded_fact_true (test' : PathTest) (ht : test' ∈ excludedTests alts) :
    (test'.predicate (.integer 2)).evalClosed = some true := by
  have hw : (test'.predicate (.integer 2)).WF 0 ∧ (test'.predicate (.integer 2)).Sorted [] none := by
    rw [tests.2] at ht
    rcases List.mem_cons.mp ht with rfl | ht
    · trivial
    · rcases List.mem_cons.mp ht with rfl | ht
      · trivial
      · cases ht
  exact MatchFacts.excluded_evalClosed_true alts_typed (show MatchFacts.RootShape P (.base .integer) (.const (.integer ⟨2,by decide⟩)) from ⟨_,rfl,rfl⟩) failure ht rfl hw.1 hw.2
end OrPattern

-- Unit は型付きの失敗を生じず、成功側の等号は実際に閉じた評価で真になる。
example : matchedTests [⟨.const .unit,[]⟩] = [.literal .unit] := rfl
example : ((PathTest.literal .unit).predicate .unitValue).evalClosed = some true := by decide

namespace CheckedAt

/-- 保持の証拠と注釈から scoped_forget を通す。除外の結論は仮定しない。 -/
theorem opaque_typed {P B Ψ o k range snap target req}
    (hw : CheckedWitness P B Ψ o k range snap target req)
    (ha : Ty.Annotation P [] [] (.opaque o (.fixed range))) :
    HasTypeV P B Ψ [] [] [] (.checkedAt range snap target req) (.opaque o (.fixed range)) :=
  .V_Sub (.V_CheckedAt hw) .scoped_forget ha.wf ha.sorted ha.declared

theorem list_typed {P B Ψ o k range snap target req}
    (hw : CheckedWitness P B Ψ o k range snap target req)
    (ha : Ty.Annotation P [] [] (.opaque o (.fixed range))) :
    HasTypeV P B Ψ [] [] [] (.list [.checkedAt range snap target req]) (.list (.opaque o (.fixed range))) :=
  .V_List (.cons (opaque_typed hw ha) .nil) ha.wf ha.sorted ha.declared

def emptyAlts : List Alt := [⟨.list [] none [],[]⟩]
def boxAlts : List Alt := [⟨.con "Box" [.wild],[]⟩]

theorem empty_alts_typed {P a} : AltsTy P emptyAlts (.list a) [] := by
  refine ⟨by simp [emptyAlts],rfl,?_,?_⟩
  · intro alt h; cases Option.some.inj h; rfl
  · intro alt h
    rcases List.mem_cons.mp h with rfl | h
    · exact ⟨[],.P_List .nil .nil (by intro _; rfl),.refl _,rfl⟩
    · cases h

theorem list_failure {range snap target req} :
    firstAlt (.list [.checkedAt range snap target req]) emptyAlts = none := rfl

/-- [] の腕を飛ばした後の非空を、閉じた値の型付けと実際の失敗から読む。 -/
theorem list_excluded_from_typing {P B Ψ a range snap target req}
    (hv : HasTypeV P B Ψ [] [] [] (.list [.checkedAt range snap target req]) (.list a)) :
    PathsEvaluated (.list [.checkedAt range snap target req]) (excludedTests emptyAlts) := by
  apply MatchFacts.excluded_paths_true_of_typing empty_alts_typed hv list_failure
  intro p hp
  simp only [emptyAlts,excludedTests,excludedTest?,List.filterMap_cons,List.filterMap_nil,
    pathFacts,Val.toTerm?,Val.toTermSlots,List.map_cons,List.map_nil,List.mem_singleton] at hp
  subst p
  constructor <;> simp [PathTest.predicate,Pred.WF,Pred.VarsIn,Term.VarsIn,varsInSlots,varsInSlot,
    Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Measure.input,Measure.output]

theorem list_example {P B Ψ o k range snap target req}
    (hw : CheckedWitness P B Ψ o k range snap target req)
    (ha : Ty.Annotation P [] [] (.opaque o (.fixed range))) :
    PathsEvaluated (.list [.checkedAt range snap target req]) (excludedTests emptyAlts) :=
  list_excluded_from_typing (list_typed hw ha)

-- List の正規化を通る導出も同じ入力を作る。
theorem list_normal_root {P B Ψ o k range snap target req}
    (hw : CheckedWitness P B Ψ o k range snap target req)
    (ha : Ty.Annotation P [] [] (.opaque o (.fixed range))) :
    MatchFacts.RootShape P (Ty.list (.opaque o (.fixed range))).norm (.list [.checkedAt range snap target req]) :=
  MatchFacts.rootShape_of_typing (list_typed hw ha).V_Normal

def decl (o : OpaqueName) (range : RangeExpr) : ConDecl := ⟨"WithOpaque",0,[.opaque o (.fixed range)]⟩
def program (o : OpaqueName) (range : RangeExpr) : Program :=
  { P with cons := fun _ => some (decl o range) }

theorem data_annotation (o : OpaqueName) (range : RangeExpr) :
    Ty.Annotation (program o range) [] [] (.data "WithOpaque" []) := by
  refine ⟨by trivial,by trivial,?_⟩
  refine ⟨⟨0,?_,rfl⟩,by trivial⟩
  refine ⟨⟨"Box",decl o range,rfl,rfl⟩,?_⟩
  intro c cd hc _; cases Option.some.inj hc; rfl

theorem box_alts_typed {o range}
    (ha : Ty.Annotation (program o range) [] [] (.opaque o (.fixed range))) :
    AltsTy (program o range) boxAlts (.data "WithOpaque" []) [] := by
  refine ⟨by simp [boxAlts],rfl,?_,?_⟩
  · intro alt h; cases Option.some.inj h; rfl
  · intro alt h
    rcases List.mem_cons.mp h with rfl | h
    · refine ⟨[],.P_Con (cd := decl o range) (ts := []) rfl rfl ?_ (.cons .P_Wild .nil),.refl _,rfl⟩
      intro a hm
      have he : a = .opaque o (.fixed range) := by simpa [decl] using hm
      subst a; exact ha.wf
    · cases h

theorem con_typed {B Ψ o k range snap target req} (name : ConName)
    (hw : CheckedWitness (program o range) B Ψ o k range snap target req)
    (ha : Ty.Annotation (program o range) [] [] (.opaque o (.fixed range))) :
    HasTypeV (program o range) B Ψ [] [] [] (.con name [] [.checkedAt range snap target req]) (.data "WithOpaque" []) := by
  refine .V_Con (cd := decl o range) rfl rfl (by refine ⟨rfl,[],rfl,?_⟩; intro i a k h; simp at h) ?_ ?_ (data_annotation o range)
  · intro a hm
    have he : a = .opaque o (.fixed range) := by simpa [decl] using hm
    subst a; exact ha.wf
  · simpa [decl,Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,Ty.norm] using (HasTypeVsQ.cons (opaque_typed hw ha) .nil)

theorem box_failure {range snap target req} :
    firstAlt (.con "Other" [] [.checkedAt range snap target req]) boxAlts = none := rfl

/-- Box(_) の失敗から根の否定を得る。欄には checkedAt があってよい。 -/
theorem box_excluded_from_typing {P B Ψ a range snap target req}
    (hp : AltsTy P boxAlts a [])
    (hv : HasTypeV P B Ψ [] [] [] (.con "Other" [] [.checkedAt range snap target req]) a) :
    PathsEvaluated (.con "Other" [] [.checkedAt range snap target req]) (excludedTests boxAlts) := by
  apply MatchFacts.excluded_paths_true_of_typing hp hv box_failure
  intro p hm
  simp only [boxAlts,excludedTests,excludedTest?,irrefutableField,List.all_cons,List.all_nil,
    Bool.and_self,ite_true,List.filterMap_cons,List.filterMap_nil,pathFacts,Val.toTerm?,Val.toTermSlots,
    List.map_cons,List.map_nil,List.mem_singleton] at hm
  subst p
  constructor <;> simp [PathTest.predicate,Pred.WF,Pred.VarsIn,Term.VarsIn,varsInSlots,varsInSlot,
    Pred.Sorted,Term.HasSort,Term.References,Term.Shape]

theorem box_example {B Ψ o k range snap target req}
    (hw : CheckedWitness (program o range) B Ψ o k range snap target req)
    (ha : Ty.Annotation (program o range) [] [] (.opaque o (.fixed range))) :
    PathsEvaluated (.con "Other" [] [.checkedAt range snap target req]) (excludedTests boxAlts) :=
  box_excluded_from_typing (box_alts_typed ha) (con_typed "Other" hw ha)

-- 進行の側で読む Inhabits は変更しない。この不足は L20 の入力である。
theorem checkedAt_not_inhabits {P : Program} {o r range snap target req} :
    ¬ Inhabits P (.opaque o (.fixed r)) (.checkedAt range snap target req) := by
  intro h
  generalize ha : Ty.opaque o (.fixed r) = a at h
  generalize hv : Val.checkedAt range snap target req = w at h
  cases h <;> first | (cases ha; done) | (cases hv; done)

theorem list_checkedAt_not_inhabits {P : Program} {o r range snap target req} :
    ¬ Inhabits P (.list (.opaque o (.fixed r))) (.list [.checkedAt range snap target req]) := by
  intro h
  generalize ha : Ty.list (.opaque o (.fixed r)) = x at h
  generalize hv : Val.list [.checkedAt range snap target req] = w at h
  cases h with
  | list he =>
    cases ha; cases hv
    cases he with
    | cons hh _ => exact checkedAt_not_inhabits hh
  | _ => first | (cases ha; done) | (cases hv; done)

end CheckedAt

end
end Benitoite.Release.Refinement.MatchPathsBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if name.toString.startsWith "Benitoite.Release.Refinement.MatchPathsBoundary."
      then some name else none).mergeSort (fun a b => a.toString < b.toString)
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
  logInfo m!"MATCH_BOUNDARY_DECLARATIONS {names.length}"
