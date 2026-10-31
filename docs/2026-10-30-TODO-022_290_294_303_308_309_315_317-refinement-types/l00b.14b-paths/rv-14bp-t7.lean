import Benitoite.Release.Refinement.MatchPaths
/-! 束縛あり（δ≠[]）と観測ありの組み合わせ。境界の記録にない形。
    `match x { Box(y) => x }` の本体が lift された構成子の事実を読む。 -/
namespace Benitoite.Release.Refinement.RV7
noncomputable section
def B : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => True,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => True,
    refGet := "get", refSet := "set" }
abbrev IntTy : Ty := .base .integer
def cd : ConDecl := ⟨"T",0,[IntTy]⟩
def P0 : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def Pm : Program := { P0 with cons := fun c => if c = "Box" then some cd else none }
abbrev Input : Ty := .data "T" []
def Γm : Ctx := Ctx.extend [] Input
def fact : Pred := .constructorIs (.var 0) "Box"
def Out : Ty := .refined Input fact
def alts : List Alt := [⟨.con "Box" [.var],[0]⟩]

theorem input_ann {Γ : Ctx} : Ty.Annotation Pm [] Γ Input := by
  refine ⟨trivial,trivial,⟨⟨0,?_,rfl⟩,trivial⟩⟩
  refine ⟨⟨"Box",cd,rfl,rfl⟩,?_⟩
  intro c d hd _
  change (if c = "Box" then some cd else none) = some d at hd
  split at hd
  · cases Option.some.inj hd; rfl
  · cases hd

theorem box_cons : Pm.cons "Box" = some cd := rfl

theorem fact_wf : Pred.WellFormed Pm [] Γm fact := by
  refine ⟨?_,?_,?_⟩
  · simp [fact,Pred.WF,Pred.VarsIn,Term.VarsIn,Γm,Ctx.extend]
  · exact ⟨⟨Input,rfl,by trivial⟩,Input,rfl,rfl⟩
  · exact ⟨⟨Input,rfl,by trivial⟩,"T",[],cd,.var rfl rfl,rfl,rfl⟩

theorem paths_wf : FactsWF Pm [] Γm (pathFacts (some (.var 0)) (matchedTests alts ++ excludedTests alts)) := by
  intro p hp
  change p ∈ [fact] at hp
  rcases List.mem_cons.mp hp with rfl | hp
  · exact fact_wf
  · cases hp

theorem alts_typed : AltsTy Pm alts Input [IntTy] := by
  refine ⟨by decide,rfl,(by intro a h; cases Option.some.inj h; rfl),?_⟩
  intro a h
  rcases List.mem_cons.mp h with rfl | h
  · refine ⟨[IntTy],.P_Con (cd := cd) (ts := []) rfl rfl (by intro t ht; simp [cd] at ht; subst ht; trivial) ?_,.refl _,rfl⟩
    exact .cons .P_Var .nil
  · cases h

def Γb : Ctx := bindParams Γm [IntTy]
def Outs : Ty := Out.shiftV 1 0

theorem out_ann : Ty.Annotation Pm [] Γm Out := by
  exact ⟨⟨input_ann.wf,by simp [fact,Pred.WF,Pred.VarsIn,Term.VarsIn],by simp [Input,Ty.NotContCore,Ty.core]⟩,
      ⟨input_ann.sorted,⟨⟨Input,rfl,by trivial⟩,Input,rfl,rfl⟩⟩,
      ⟨input_ann.declared,⟨⟨Input,rfl,by trivial⟩,"T",[],cd,.var rfl rfl,rfl,rfl⟩⟩⟩

theorem out_shift_ann : Ty.Annotation Pm [] Γb Outs := (ShiftMap.outer Γm [IntTy]).annotation out_ann

theorem body : HasTypeCQ Pm B StoreTy.empty Qempty [] Γb
    (liftMany 1 (pathFacts (some (.var 0)) (matchedTests alts)))
    none (.ret (.var 1)) Outs (Eff.shiftV 1 0 Eff.empty) (localExtend 1 []) := by
  have ha := out_shift_ann
  apply HasTypeCQ.C_Return
  have hx : Entails (Γb.facts ++ liftMany 1 (pathFacts (some (.var 0)) (matchedTests alts)))
      (.constructorIs (.var 1) "Box") := .hyp (by
        apply List.mem_append_right
        change _ ∈ [Pred.lift fact]
        simp [fact,Pred.lift,predBind,termBind,termBind?])
  refine .V_Refine (.V_Var rfl (by trivial)) rfl rfl ha.sorted.2 ha.wf.2.1 ?_ ha.declared.1 ha.declared.2
  simpa [Outs,Out,fact,Ty.shiftV,Pred.shiftV,Pred.open,predBind,termBind,termBind?,openingEnv,upValues,shiftIndex,Input] using hx

theorem arms_typed : HasTypeArmsQ Pm B StoreTy.empty Qempty [] Γm [] none (some (.var 0))
    [.mk alts none (.ret (.var 1))] Input Out Eff.empty := by
  refine .plain alts_typed paths_wf ?_ (.nil out_ann)
  rw [List.append_nil]
  exact body
end
end Benitoite.Release.Refinement.RV7
#print axioms Benitoite.Release.Refinement.RV7.arms_typed
