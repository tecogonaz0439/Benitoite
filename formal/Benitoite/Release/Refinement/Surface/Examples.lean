import Benitoite.Release.Refinement.Surface.Theorems
import Benitoite.Release.Refinement.StandardModelSubstitution
import Benitoite.Release.Refinement.LogicSound

/-!
# 性質1の適用例

前提を満たす最小の表層のプログラム（Unit を返す main だけ）に性質1を当て、整形式・型付けの前提と組み込みの表の
仮定が満たせることを示す。組み込みの表は合成表（`StandardModel.builtins`）である。
-/

namespace Benitoite.Release.Refinement.Surface.Examples

/-- `function main() -> Unit = { }`。 -/
def mainDef : Def where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.empty
  body := .empty

def mainProgram : Program where
  defs := fun f => if f = "main" then some mainDef else none
  cons := fun _ => none

theorem mainDef_tel : mainDef.toFunDecl.tel = .done (.base .unit) Eff.empty := rfl

theorem mainTel_annotation (P : Refinement.Program) :
    Ty.Annotation P [] [] (.dependentFn (.done (.base .unit) Eff.empty)) :=
  (Ty.Annotation.done_empty ⟨trivial, trivial, trivial⟩)

theorem mainProgram_wellFormed : mainProgram.WellFormed where
  types := {
    defs := fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core] at h
    cons := fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, mainProgram] at h
    ops := fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, mainProgram] at h
    classes := fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, mainProgram] at h
    impls := fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core] at h
    metadata := fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, mainProgram] at h
    external := ⟨by simp [Program.declarationsFor, Program.declarations, Declarations.core, mainProgram],
      fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, mainProgram] at h⟩ }
  defs := by
    intro f d hd
    simp only [mainProgram] at hd
    split at hd
    · cases hd
      refine ⟨by simp [FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys, internalNames, NamesWF, mainDef], ?_, trivial⟩
      rw [mainDef_tel]
      refine ⟨⟨(mainTel_annotation (P := (mainProgram.declarations).core)).wf, ?_, ?_⟩, ?_, ?_, mainTel_annotation _⟩
      · simp [Ty.RowsIn, Tel.RowsIn, Eff.RowsIn, Eff.empty, Ty.RowsInList]
      · simp [Ty.RangesScoped, Tel.RangesScoped, Eff.RangesScoped, Eff.empty, rangesScopedTypes]
      · simp [Tel.RowsIn, Ty.RowsIn, Eff.RowsIn, Eff.empty, Ty.RowsInList]
      · simp [Ty.HasKind, kindsTel, kindsEff, kindsList, Eff.empty]
    · cases hd
  impls := fun _ _ h => by simp [mainProgram] at h
  accessors := fun _ _ _ h => by simp [mainProgram] at h
  testers := fun _ _ h => by simp [mainProgram] at h

theorem mainProgram_wellTyped (B : Builtins) (op : OpPrim) : mainProgram.WellTyped B op where
  variance := ⟨fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, mainProgram] at h,
    fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, mainProgram] at h⟩
  defs := by
    intro f d hd
    simp only [mainProgram] at hd
    split at hd
    · cases hd
      refine ⟨by simp [FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys, internalNames, NamesWF, mainDef], ?_,
        by rw [mainDef_tel]; exact mainTel_annotation _, ?_⟩
      · rw [mainDef_tel]; simp [Ty.HasKind, kindsTel, kindsEff, kindsList, Eff.empty]
      · rw [mainDef_tel]; exact .done .B_Empty
    · cases hd
  impls := fun _ _ h => by simp [mainProgram] at h
  effects := ⟨fun _ _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, mainProgram] at h,
    fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, mainProgram] at h,
    fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, mainProgram] at h⟩

/-- 性質1の適用例。合成表の組み込みの関数の表で、脱糖したプログラムが整形式で型付く。 -/
theorem mainProgram_desugar_typed (op : OpPrim) :
    (desugarProgram op mainProgram).WellFormed ∧
      (desugarProgram op mainProgram).WellTyped (StandardModel.builtins (desugarProgram op mainProgram)) ∧
      (desugarProgram op mainProgram).EffectsOk (StandardModel.builtins (desugarProgram op mainProgram)) :=
  desugar_typed mainProgram_wellFormed (mainProgram_wellTyped _ op)
    (StandardModel.substitution_assumptions _).toValueAssumptions

/-! ## 値の観測による篩の導入 -/

/-- 結果が true でないという篩。 -/
def notTrue : Pred := .not (boolCond (.var 0) true)

/-- リテラル `false` は `Boolean{r | not(r = true)}` を持つ（任意の宣言表・組み込みの表・演算子の表）。 -/
theorem false_notTrue (D : Declarations) (B : Builtins) (op : OpPrim) (Q : NoFailCtx) :
    HasTypeQ D B op Q [] [] [] [] none .other (.literal (.boolean false)) (.refined (.base .boolean) notTrue)
      Eff.empty :=
  .E_Refine (s := .boolean) (.E_Literal trivial) rfl rfl rfl
    (by simp [notTrue, boolCond, Pred.Sorted, Comparison.Allowed, Term.HasSort, Term.References, Term.Shape,
      Term.VarsIn, Ctx.Readable, Ty.HasSort, Ty.sort?])
    (by simp [notTrue, boolCond, Pred.WF, Pred.VarsIn, Term.VarsIn])
    (by simpa [notTrue, boolCond, Pred.open, predBind, termBind, termBind?, Ctx.facts] using
      (entails_closed closed_not_false_true : Entails [] _))
    ⟨trivial, trivial, trivial⟩
    (by simp [notTrue, boolCond, Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.Readable, Ctx.extend,
      Ty.shiftV, Ty.core])

/-- 誤った値 `true` には、篩の導入の前提（値の項について篩が導けること）が成り立たない（含意の健全性）。 -/
theorem true_not_notTrue : ¬ Entails [] (notTrue.open (.boolean true)) := by
  intro h
  have := h.sound (fun _ => none) (by simp)
  simp [notTrue, boolCond, Pred.open, predBind, termBind, termBind?, Pred.interpret, Pred.atomValue, observeAs,
    Observation.compare, Term.interpret, Observation.sort, Comparison.fromEqLt] at this

/-- 負の Decimal の専用の構文に、その値との等号の篩を導入する。 -/
theorem negDecimal_singleton (D : Declarations) (B : Builtins) (op : OpPrim) (Q : NoFailCtx) :
    HasTypeQ D B op Q [] [] [] [] none .other (.negDecimal 1 0)
      (.refined (.base .decimal) (.compare .decimal .eq (.var 0) (.decimal (-1) 0))) Eff.empty := by
  refine .E_Refine (s := .decimal) (.E_NegDecimal (by simp [ConstOK])) rfl rfl rfl ?_ ?_ ?_
    ⟨trivial, trivial, trivial⟩ ?_
  · simp [Pred.Sorted, Comparison.Allowed, Term.HasSort, Term.References, Term.Shape, Term.VarsIn,
      Ctx.Readable, Ty.HasSort, Ty.sort?]
  · simp [Pred.WF, Pred.VarsIn, Term.VarsIn]
  · apply entails_closed
    simp [Pred.open, predBind, termBind, termBind?, Pred.evalClosed, Pred.WF, Pred.VarsIn, Pred.Sorted,
      Comparison.Allowed, Term.HasSort, Term.References, Term.Shape, Term.VarsIn, Pred.evalWith,
      Pred.atomReady, Pred.atomValue, termReady, observeAs, Observation.compare, Term.observe,
      Term.interpret, Observation.sort, Comparison.fromEqLt]
    exact decide_eq_true trivial
  · simp [Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.Readable, Ctx.extend, Ty.shiftV, Ty.core]

/-- 符号付きの三つの固定幅整数の専用の構文に、整数 -1 との等号の篩を導入する。 -/
theorem negIntegers_singleton (D : Declarations) (B : Builtins) (op : OpPrim) (Q : NoFailCtx) :
    HasTypeQ D B op Q [] [] [] [] none .other (.negInteger8 1)
      (.refined (.base .integer8) (.eq (.var 0) (.integer (-1)))) Eff.empty ∧
    HasTypeQ D B op Q [] [] [] [] none .other (.negInteger16 1)
      (.refined (.base .integer16) (.eq (.var 0) (.integer (-1)))) Eff.empty ∧
    HasTypeQ D B op Q [] [] [] [] none .other (.negInteger32 1)
      (.refined (.base .integer32) (.eq (.var 0) (.integer (-1)))) Eff.empty := by
  refine ⟨?_, ?_, ?_⟩
  all_goals
    refine .E_Refine (s := .integer) ?_ rfl rfl rfl ?_ ?_ ?_ ⟨trivial, trivial, trivial⟩ ?_
    · first | exact .E_NegInteger8 (n := 1) (by simp [ConstOK]) | exact .E_NegInteger16 (n := 1) (by simp [ConstOK]) | exact .E_NegInteger32 (n := 1) (by simp [ConstOK])
    · simp [Pred.Sorted, Term.HasSort, Term.References, Term.Shape, Term.VarsIn, Ctx.Readable,
        Ty.HasSort, Ty.sort?]
    · simp [Pred.WF, Pred.VarsIn, Term.VarsIn]
    · simpa [Pred.open, predBind, termBind, termBind?, Ctx.facts] using (Entails.eq_refl (Ξ := []) (t := .integer (-1)))
    · simp [Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.Readable, Ctx.extend, Ty.shiftV, Ty.core]

/-- Float32 の負号は符号ビットを反転し、専用の構文のまま -1.0f32 との等号の篩を導入できる。 -/
theorem negFloat32_singleton (D : Declarations) (B : Builtins) (op : OpPrim) (Q : NoFailCtx) :
    HasTypeQ D B op Q [] [] [] [] none .other (.negFloat32 0x3f800000)
      (.refined (.base .float32) (.compare .float32 .eq (.var 0) (.float32 0xbf800000))) Eff.empty := by
  refine .E_Refine (s := .float32) .E_NegFloat32 rfl rfl rfl ?_ ?_ ?_ ⟨trivial, trivial, trivial⟩ ?_
  · simp [Pred.Sorted, Comparison.Allowed, Term.HasSort, Term.References, Term.Shape, Term.VarsIn,
      Ctx.Readable, Ty.HasSort, Ty.sort?]
  · simp [Pred.WF, Pred.VarsIn, Term.VarsIn]
  · apply entails_closed
    decide
  · simp [Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.Readable, Ctx.extend, Ty.shiftV, Ty.core]

/-! ## 照合の事実を使う腕 -/

theorem scrutObs_some {Γ : Ctx} {s} (h : (Term.var 0).HasSort Γ s) : scrutObs Γ = some (.var 0) := by
  have h' : ∃ s, (Term.var 0).HasSort Γ s := ⟨s, h⟩
  unfold scrutObs
  simp only [h', ite_true]

/-- 照合する値 x を受け、`true` の腕では `false` を、残りの腕では x 自身を返す。残りの腕の本体 x は、前の腕の除外の
事実 `not(x = true)` があるときだけ `Boolean{r | not(r = true)}` を持つ。 -/
def notTrueArms : Arms :=
  .cons [⟨.boolean true, []⟩] none (.last (.literal (.boolean false)))
    (.cons [⟨.wild, []⟩] none (.last (.local 0)) .nil)

theorem notTrueArms_typed (D : Declarations) (B : Builtins) (op : OpPrim) (Q : NoFailCtx) :
    HasArmsQ D B op Q [none] [] (Ctx.extend [some (.base .boolean)] (.base .boolean)) [] none .other notTrueArms
      (.base .boolean) (.refined (.base .boolean) (liftRef 1 notTrue)) Eff.empty := by
  have hs : (Term.var 0).HasSort (Ctx.extend [some (.base .boolean)] (.base .boolean)) .boolean := by
    simp [Term.HasSort, Term.References, Term.Shape, Term.VarsIn, Ctx.Readable, Ctx.extend, Ty.HasSort, Ty.sort?,
      Ty.shiftV]
  have ho := scrutObs_some hs
  have hff : ∀ n (o : Option Term), fieldFacts n o [] = [] := by intro n o; cases o <;> rfl
  have hann : Ty.Annotation D.core [] (Ctx.extend [some (.base .boolean)] (.base .boolean)) (.base .boolean) :=
    ⟨trivial, trivial, trivial⟩
  have hsorted : Pred.Sorted (Ctx.extend [some (.base .boolean)] (.base .boolean)) (some (.base .boolean))
      (liftRef 1 notTrue) := by
    simp [liftRef, notTrue, boolCond, predBind, termBind, termBind?, Pred.Sorted, Comparison.Allowed, Term.HasSort,
      Term.References, Term.Shape, Term.VarsIn, Ctx.Readable, Ty.HasSort, Ty.sort?]
  have hwf : Pred.WF ((Ctx.extend [some (.base .boolean)] (.base .boolean)).length + 1) (liftRef 1 notTrue) := by
    simp [liftRef, notTrue, boolCond, predBind, termBind, termBind?, Pred.WF, Pred.VarsIn, Term.VarsIn, Ctx.extend]
  have hpd : Pred.Declared D.core [] (Ctx.extend [some (.base .boolean)] (.base .boolean)) (some (.base .boolean))
      (liftRef 1 notTrue) := by
    simp [liftRef, notTrue, boolCond, predBind, termBind, termBind?, Pred.Declared, Term.Declared, Ctx.declarationSelf,
      Ctx.Readable, Ctx.extend, Ty.shiftV, Ty.core]
  have hfact : Pred.WellFormed D.core [] (Ctx.extend [some (.base .boolean)] (.base .boolean))
      (.compare .boolean .eq (.var 0) (.boolean true)) := by
    refine ⟨?_, ?_, ?_⟩ <;> simp [Pred.WF, Pred.VarsIn, Term.VarsIn, Pred.Sorted, Comparison.Allowed, Term.HasSort,
      Term.References, Term.Shape, Ctx.Readable, Ty.HasSort, Ty.sort?, Pred.Declared, Term.Declared,
      Ctx.declarationSelf, Ctx.extend, Ty.shiftV, Ty.core]
  refine .plain (δ := []) (links := []) (by simp [Alternative.Valid, Pattern.Valid])
    (AltsTy.single (.P_Const rfl)) (by intro l hl; cases hl)
    (by intro q hq; rw [hff] at hq; cases hq) ?_ ?_ ?_
  · rw [ho]
    intro q hq
    simp [Alternative.toCoreList, Alternative.toCore, Pattern.toCore, matchedTests, excludedTests, patternTest?,
      excludedTest?, pathLiteral?, pathFacts, PathTest.predicate, PathLiteral.predicate] at hq
    rcases hq with rfl | rfl
    · exact hfact
    · exact ⟨hfact.wf, hfact.sorted, hfact.declared⟩
  · simp only [Ty.shiftV_zero, Eff.shiftV_zero, bindParams_nil, List.length_nil, Option.map_none]
    refine .B_Last (.E_Refine (s := .boolean) (.E_Literal trivial) rfl rfl rfl hsorted hwf ?_ hann hpd)
    refine entails_closed ?_
    simpa [liftRef, notTrue, boolCond, predBind, termBind, termBind?, Pred.open] using closed_not_false_true
  · rw [ho]
    refine .plain (δ := []) (links := []) (by simp [Alternative.Valid, Pattern.Valid])
      (AltsTy.single .P_Wild) (by intro l hl; cases hl) (by intro q hq; rw [hff] at hq; cases hq)
      (by intro q hq; simp [Alternative.toCoreList, Alternative.toCore, Pattern.toCore, matchedTests,
        excludedTests, patternTest?, excludedTest?, pathFacts, ho] at hq) ?_ .nil
    simp only [Ty.shiftV_zero, Eff.shiftV_zero, bindParams_nil, List.length_nil, Option.map_none]
    refine .B_Last (.E_Refine (s := .boolean) (.E_Local (by simp [Ctx.extend, Ty.shiftV]) (by intro b t e; simp [Ty.core]))
      rfl rfl rfl hsorted hwf ?_ hann hpd)
    refine .hyp (List.mem_append_right _ ?_)
    simp [Alternative.toCoreList, Alternative.toCore, Pattern.toCore, matchedTests, excludedTests, patternTest?,
      excludedTest?, pathLiteral?, pathFacts, PathTest.predicate, PathLiteral.predicate, liftRef, notTrue, boolCond,
      predBind, termBind, termBind?, Pred.open, hff, ho]
    exact List.mem_singleton_self _

/-- 結果が true であるという篩。 -/
def isTrue : Pred := boolCond (.var 0) true

/-- ガードの結果の篩: 結果が true でないか、照合する値（番号 1）が true である。 -/
def guardPred : Pred := .or (.not (boolCond (.var 0) true)) (boolCond (.var 1) true)

theorem excluded_middle {Ξ : List Pred} (p : Pred) : Entails Ξ (.or (.not p) p) := by
  have hH : Pred.not (.or (.not p) p) ∈ Pred.not (.or (.not p) p) :: Ξ := List.mem_cons_self
  have hp : p ∈ p :: Pred.not (.or (.not p) p) :: Ξ := List.mem_cons_self
  have hH' : Pred.not (.or (.not p) p) ∈ p :: Pred.not (.or (.not p) p) :: Ξ := List.mem_cons_of_mem _ hH
  have hc : Entails (p :: Pred.not (.or (.not p) p) :: Ξ) .falsity :=
    .not_elim (p := .or (.not p) p) (.or_right (.hyp hp)) (.hyp hH')
  exact .not_not_elim (.not_intro (.not_elim (p := .or (.not p) p) (.or_left (.not_intro hc)) (.hyp hH)))

theorem boolean_shiftV (k c : Nat) : Ty.shiftV k c (.base .boolean) = .base .boolean := by simp [Ty.shiftV]

/-- 照合する値をガードにし、ガードが真の腕では照合する値を返し、残りの腕では true を返す。ガードの腕の本体は、ガードの
結果の篩から得る事実（照合する値が true）があるときだけ `Boolean{r | r = true}` を持つ。 -/
def guardArms : Arms :=
  .cons [⟨.wild, []⟩] (some (.local 0)) (.last (.local 0))
    (.cons [⟨.wild, []⟩] none (.last (.literal (.boolean true))) .nil)

theorem guardArms_typed (D : Declarations) (B : Builtins) (op : OpPrim) (Q : NoFailCtx) :
    HasArmsQ D B op Q [none] [] (Ctx.extend [] (.base .boolean)) [] none .other guardArms
      (.base .boolean) (.refined (.base .boolean) isTrue) Eff.empty := by
  have hff : ∀ n (o : Option Term), fieldFacts n o [] = [] := by intro n o; cases o <;> rfl
  have hann : ∀ Γ : Ctx, Ty.Annotation D.core [] Γ (.base .boolean) := fun _ => ⟨trivial, trivial, trivial⟩
  have hwild : ∀ Γ : Ctx, pathFacts (scrutObs Γ) (matchedTests [Alternative.toCore ⟨.wild, []⟩] ++
      excludedTests [Alternative.toCore ⟨.wild, []⟩]) = [] := by
    intro Γ; cases scrutObs Γ <;> simp [Alternative.toCore, Pattern.toCore, matchedTests, excludedTests,
      patternTest?, excludedTest?, pathFacts]
  have hm : ∀ Γ : Ctx, pathFacts (scrutObs Γ) (matchedTests [Alternative.toCore ⟨.wild, []⟩]) = [] := by
    intro Γ; cases scrutObs Γ <;> simp [Alternative.toCore, Pattern.toCore, matchedTests, patternTest?, pathFacts]
  have hsortedT : ∀ Γ : Ctx, Pred.Sorted Γ (some (.base .boolean)) isTrue := by
    intro Γ; simp [isTrue, boolCond, Pred.Sorted, Comparison.Allowed, Term.HasSort, Term.References, Term.Shape,
      Term.VarsIn, Ctx.Readable, Ty.HasSort, Ty.sort?]
  have hwfT : ∀ n, Pred.WF (n + 1) isTrue := by intro n; simp [isTrue, boolCond, Pred.WF, Pred.VarsIn, Term.VarsIn]
  have hpdT : ∀ Γ : Ctx, Pred.Declared D.core [] Γ (some (.base .boolean)) isTrue := by
    intro Γ; simp [isTrue, boolCond, Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.Readable, Ctx.extend,
      boolean_shiftV, Ty.core]
  have hG : (Ctx.extend [] (.base .boolean))[0]? = some (some (.base .boolean)) := by simp [Ctx.extend, Ty.shiftV]
  refine .guarded (δ := []) (links := []) (q := guardPred) (by simp [Alternative.Valid, Pattern.Valid])
    (AltsTy.single .P_Wild) (by intro l hl; cases hl) (by intro q hq; rw [hff] at hq; cases hq)
    (by intro q hq; simp only [Alternative.toCoreList, List.map_cons, List.map_nil, hwild] at hq; cases hq)
    ?_ ?_ ?_ ?_
  · refine ⟨⟨trivial, ?_, ?_⟩, ⟨trivial, ?_⟩, ⟨trivial, ?_⟩⟩ <;>
      simp [guardPred, boolCond, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core, Pred.Sorted,
        Comparison.Allowed, Term.HasSort, Term.References, Term.Shape, Ctx.Readable, Ty.HasSort, Ty.sort?,
        Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.extend, hideConts, bindParams, boolean_shiftV]
  · refine .E_Refine (s := .boolean) (.E_Local (by simp [hideConts, bindParams, Ctx.extend, boolean_shiftV])
      (by intro b t e; simp [Ty.core])) rfl rfl rfl ?_ ?_ ?_ (hann _) ?_
    · simp [guardPred, boolCond, Pred.Sorted, Comparison.Allowed, Term.HasSort, Term.References, Term.Shape,
        Term.VarsIn, Ctx.Readable, Ty.HasSort, Ty.sort?, hideConts, bindParams, Ctx.extend, Ty.shiftV]
    · simp [guardPred, boolCond, Pred.WF, Pred.VarsIn, Term.VarsIn, hideConts, bindParams, Ctx.extend]
    · simpa [guardPred, boolCond, Pred.open, predBind, termBind, termBind?] using
        excluded_middle (Ξ := _) (boolCond (.var 0) true)
    · simp [guardPred, boolCond, Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.Readable, Ctx.extend,
        hideConts, bindParams, Ty.shiftV, Ty.core]
  · simp only [Ty.shiftV_zero, Eff.shiftV_zero, bindParams_nil, List.length_nil, Option.map_none]
    refine .B_Last (.E_Refine (s := .boolean) (.E_Local hG (by intro b t e; simp [Ty.core])) rfl rfl rfl
      (hsortedT _) (hwfT _) ?_ (hann _) (hpdT _))
    have hfact : Entails (((Ctx.extend [] (.base .boolean))).facts ++
        (guardPred.open (.boolean true) :: (fieldFacts 0 (scrutObs (Ctx.extend [] (.base .boolean))) [] ++
          liftMany 0 (pathFacts (scrutObs (Ctx.extend [] (.base .boolean)))
            (matchedTests (Alternative.toCoreList [⟨.wild, []⟩])) ++ []))))
        (guardPred.open (.boolean true)) := .hyp (List.mem_append_right _ (by simp))
    simp only [guardPred, boolCond, Pred.open, predBind, termBind, termBind?] at hfact
    refine .or_elim hfact ?_ (.hyp (by simp [isTrue, boolCond, Pred.open, predBind, termBind, termBind?]))
    exact .false_elim (.not_elim (entails_closed closed_true_true) (.hyp (by simp)))
  · refine .plain (δ := []) (links := []) (by simp [Alternative.Valid, Pattern.Valid])
      (AltsTy.single .P_Wild) (by intro l hl; cases hl) (by intro q hq; rw [hff] at hq; cases hq)
      (by intro q hq; simp only [Alternative.toCoreList, List.map_cons, List.map_nil, hwild] at hq; cases hq) ?_ .nil
    simp only [Ty.shiftV_zero, Eff.shiftV_zero, bindParams_nil, List.length_nil, Option.map_none]
    refine .B_Last (.E_Refine (s := .boolean) (.E_Literal trivial) rfl rfl rfl (hsortedT _) (hwfT _) ?_ (hann _)
      (hpdT _))
    exact entails_closed (by simpa [isTrue, boolCond, Pred.open, predBind, termBind, termBind?] using closed_true_true)

end Benitoite.Release.Refinement.Surface.Examples
