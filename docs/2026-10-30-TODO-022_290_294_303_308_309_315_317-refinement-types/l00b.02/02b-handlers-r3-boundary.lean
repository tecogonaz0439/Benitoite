import Lean
import Benitoite

namespace Benitoite.Release.Refinement.HandlerReviewBoundary

def variableAlt : Alt := ⟨.var,[0]⟩
def guardCode : Comp := .letIn (.builderOp .string .length (.bound 1) []) (.ret (.const (.boolean true)))
def arms : List Arm := [.mk [variableAlt] (some guardCode) (.ret (.const .unit))]
def facts : List Pred := [.eq (.integer 7) (.integer 7)]

theorem string_kinded (P : Program) : TypeArgsKinded P [] [.base .string] [.value] := by
  refine ⟨rfl,[],rfl,?_⟩
  intro i a k ha hk
  cases i with
  | zero => simp only [List.getElem?_cons_zero,Option.some.injEq] at ha hk; cases ha; cases hk; trivial
  | succ i => simp at ha

theorem variable_alt_typed (P : Program) : AltsTy P [variableAlt] (.base .integer) [.base .integer] := by
  refine ⟨by simp, rfl, ?_, ?_⟩
  · intro alt h; cases h; rfl
  · intro alt h
    have he : alt=variableAlt := List.mem_singleton.mp h
    subst alt
    exact ⟨[.base .integer],.P_Var,List.Perm.refl _,rfl⟩

/-- guard内から、パターン束縛の外側の構築器を専用操作で読む。 -/
theorem guard_builder {P B Ψ Q Γ} {L : LocalCtx} :
    HasTypeCQ P B Ψ Q [] (hideConts (bindParams Γ [.base .integer])) (liftMany 1 facts)
      none guardCode (.base .boolean) Eff.empty (localExtend 1 (some .string::L)) := by
  refine .C_Let (.C_BuilderOp ⟨trivial,trivial,trivial⟩ (string_kinded P) (.bound rfl) .nil) ?_ trivial
  exact .C_Return (.V_Const trivial)

theorem guarded_arm {P B Ψ Q R Γ} {L : LocalCtx} :
    HasTypeArmsQ P B Ψ Q [] Γ facts R arms (.base .integer) (.base .unit) Eff.empty (some .string::L) := by
  exact .guarded (variable_alt_typed P) guard_builder (.C_Return (.V_Const trivial))
    (.nil ⟨trivial,trivial,trivial⟩)

def builderStore : StoreTy := fun _ => some (.builder .string)

theorem guard_builder_loc {P B Q Γ} :
    HasTypeCQ P B builderStore Q [] (hideConts (bindParams Γ [.base .integer])) (liftMany 1 facts)
      none (.letIn (.builderOp .string .length (.loc 0) []) (.ret (.const (.boolean true))))
      (.base .boolean) Eff.empty (localExtend 1 []) := by
  refine .C_Let (.C_BuilderOp ⟨trivial,trivial,trivial⟩ (string_kinded P) (.loc rfl) .nil) ?_ trivial
  exact .C_Return (.V_Const trivial)

/-- 移動後にも局所参照を同じ構築器へ対応させる。 -/
theorem guarded_arm_shift {P B Ψ Q} {R : Option Ty} (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) :
    HasTypeArmsQ P B Ψ Q [] [none,none] (facts.map (Pred.shiftV 1 0)) (R.map (Ty.shiftV 1 0))
      (Arm.renameList (shiftIndex 1 0) arms) (.base .integer) (.base .unit) Eff.empty
      [none,some .string] := by
  have hm : FullShiftMap 1 0 [none] [none,none] := by
    constructor
    · rfl
    · intro i a hi; cases i <;> simp at hi
  have hl : LocalCtx.Shift 1 0 [some .string] [none,some .string] := by
    intro i b hi
    cases i with
    | zero => simp only [List.getElem?_cons_zero,Option.some.injEq] at hi; cases hi; rfl
    | succ i => simp at hi
  exact guarded_arm.shift_values hA hw (.refl _) hm hl (fun p hp => .hyp (List.mem_append_right _ (List.mem_map.mpr ⟨p,hp,rfl⟩)))

/-- 空の値スロットの置換でも、外側の構築器の局所参照は残る。 -/
theorem guarded_arm_subst {P B Ψ Q} {R : Option Ty} (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF) :
    HasTypeArmsQ P B Ψ Q [] [none] facts (R.map (substTyValues Val.var))
      (Arm.substList Val.var arms LocalRef.bound) (.base .integer) (.base .unit) Eff.empty [some .string] := by
  have ht : SubstOk P B Ψ Q [] [none] facts [none] facts (R.map (substTyValues Val.var)) Val.var := by
    intro i a hi; cases i <;> simp at hi
  have hl : LocalSubstOk Ψ [some .string] Val.var LocalRef.bound [some .string] := by
    intro i b hi
    cases i with
    | zero => simp only [List.getElem?_cons_zero,Option.some.injEq] at hi; cases hi; exact .bound rfl
    | succ i => simp at hi
  have hh := (guarded_arm (P := P) (B := B) (Ψ := Ψ) (Q := Q) (R := R)).subst hA hw ht
    (fun p hp => by simpa only [valEnv,Val.toTerm?,predBind_id] using Entails.hyp (List.mem_append_right _ hp)) LocalRef.bound hl
  simpa only [substTyValues,Ty.bind,Ty.rawBind,Ty.norm,substEffValues_empty] using hh

def refinedInteger : Ty := .refined (.base .integer) (.eq (.var 0) (.integer 7))

/-- narrowingのNoneの下でも同じguardを検査できる。 -/
theorem guarded_arm_narrow {P B Ψ Q R} (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) :
    HasTypeArmsQ P B Ψ Q [] [none,some refinedInteger] facts R arms
      (.base .integer) (.base .unit) Eff.empty [some .string,none] := by
  have hn : Ctx.Narrows P [] [none,some (.base .integer)] facts [none,some refinedInteger] facts := by
    have hh : Ctx.Narrows P [] (Ctx.extend [] (.base .integer)) (facts.map Pred.lift)
        (Ctx.extend [] refinedInteger) (facts.map Pred.lift) :=
      .here .forget (by simp [refinedInteger,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]) trivial trivial trivial
    exact hh.underNone
  exact guarded_arm.narrow hA hw hn

def atDecl : ConDecl := ⟨"Scope.ScopeError",0,atErrorFields⟩
def outsideDecl : ConDecl := ⟨"Scope.ScopeError",0,[.base .string,.base .string]⟩
def errorConstructors : List (ConName × ConDecl) :=
  [("Scope.ScopeError.At",atDecl),("Scope.ScopeError.OutsideScope",outsideDecl)]
def P : Program :=
  { defs := fun _ => none,
    cons := fun c => if c="Scope.ScopeError.At" then some atDecl else
      if c="Scope.ScopeError.OutsideScope" then some outsideDecl else none,
    ops := fun _ => none, effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def shape : ResultShape := ⟨"Result","Ok","Error",atErrorType⟩

theorem table_complete : P.StandardErrorComplete errorConstructors := by
  constructor
  · intro c cd h
    simp only [errorConstructors,List.mem_cons,Prod.mk.injEq] at h
    rcases h with ⟨rfl,rfl⟩ | h
    · exact ⟨rfl,rfl,rfl⟩
    · simp only [List.not_mem_nil,or_false] at h
      rcases h with ⟨rfl,rfl⟩
      exact ⟨rfl,rfl,rfl⟩
  · intro c cd hc _
    by_cases ha : c="Scope.ScopeError.At"
    · subst c
      have he : cd=atDecl := Option.some.inj hc.symm
      subst cd; simp [errorConstructors]
    · by_cases ho : c="Scope.ScopeError.OutsideScope"
      · subst c
        have he : cd=outsideDecl := Option.some.inj hc.symm
        subst cd; simp [errorConstructors]
      · simp [P,ha,ho] at hc

theorem standard : ResultShape.StandardError P shape := by
  refine ⟨rfl,⟨⟨"Scope.ScopeError.At",atDecl,rfl,rfl⟩,?_⟩,atDecl,rfl,rfl,rfl,rfl⟩
  intro c cd hc _
  by_cases ha : c="Scope.ScopeError.At"
  · subst c; have he : cd=atDecl := Option.some.inj hc.symm; subst cd; rfl
  · by_cases ho : c="Scope.ScopeError.OutsideScope"
    · subst c; have he : cd=outsideDecl := Option.some.inj hc.symm; subst cd; rfl
    · simp [P,ha,ho] at hc

theorem error_exhaustive : Exhaustive P atErrorType (atErrorPatterns errorConstructors) :=
  .atError standard table_complete

def outsideValue : Val := .con "Scope.ScopeError.OutsideScope" []
  [.const (.string "pattern"),.const (.string "target")]

theorem outside_inhabits : Inhabits P atErrorType outsideValue := by
  exact .con (cd := outsideDecl) (ts := []) rfl rfl (by intros a h; simp_all [outsideDecl,Ty.WF])
    (by change InhabitsAll P [.base .string,.base .string] _; exact .cons (.const (c := .string "pattern")) (.cons (.const (c := .string "target")) .nil))

theorem outside_covered : ∃ p∈atErrorPatterns errorConstructors,(matchVal p outsideValue).isSome :=
  error_exhaustive outsideValue outside_inhabits

theorem at_only_incomplete : ¬Exhaustive P atErrorType [atErrorPattern] := by
  intro h
  obtain ⟨p,hp,hm⟩ := h outsideValue outside_inhabits
  have he := List.mem_singleton.mp hp
  subst p
  simp [atErrorPattern,outsideValue,matchVal] at hm

theorem detail_covered (detail : AtError) :
    ∃ p∈atErrorPatterns errorConstructors,(matchVal p (.atError detail)).isSome :=
  error_exhaustive _ (.atError standard)

end Benitoite.Release.Refinement.HandlerReviewBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := env.constants.toList.filterMap fun (name, _) =>
    if (`Benitoite.Release.Refinement.HandlerReviewBoundary).isPrefixOf name then some name else none
  let names := names.mergeSort (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
