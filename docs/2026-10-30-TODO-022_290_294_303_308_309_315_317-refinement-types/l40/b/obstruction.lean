import Lean
import Benitoite

/-! # 開いた呼出しの直接規則と依存実引数の形成の差 -/
namespace Benitoite.Release.Refinement.ApplicationObstruction

private theorem tvar_source {P Γ Φ a b i} (h : Ty.LeQ P Γ Φ a b)
    (hb : b.norm.core = .tvar i) : a.norm.core = .tvar i := by
  match h with
  | .refl => exact hb
  | .convert he => rw [he]; exact hb
  | .trans h g => exact tvar_source h (tvar_source g hb)
  | .forget | .introduce .. => simpa only [Ty.refined_norm_core] using hb
  | .refine h .. =>
    simp only [Ty.refined_norm_core] at hb ⊢
    exact tvar_source h hb
  | .fn_effect .. | .dependentFn .. | .list .. | .lazy .. | .map_value .. |
      .scoped .. | .scoped_forget | .data .. =>
    simp only [Ty.norm,Ty.core,Ty.core_foldFn] at hb
    first | cases hb | (unfold Ty.foldFn at hb; split at hb <;> cases hb)

def context : Ctx := [some (.fn [] [] (.tvar 0) Eff.empty)]

/-- C_Appは型パラメータのない文脈でも、この直接導出を許す。 -/
theorem source (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ P B Ψ Qempty [] context [] none
      (.app (.var 0) []) (.tvar 0) Eff.empty [] := by
  apply HasTypeCQ.C_App (ns := []) (as := [])
  · exact .V_Var rfl (by intro b t e he; cases he)
  · exact .nil

/-- 同じ呼出しの結果への部分型を持つ依存実引数列は存在しない。 -/
theorem no_telescope (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ¬ ∃ t a e, HasTypeTelArgsQ P B Ψ Qempty [] context [] [] t a e ∧
      Ty.LeQ P context [] a (.tvar 0) := by
  rintro ⟨t,a,e,args,le⟩
  have wf := Ty.WF.core (Ty.wf_norm (open_telArgs_annotation args).wf.1)
  have eq := tvar_source le rfl
  rw [eq] at wf
  exact Nat.not_lt_zero 0 wf

/-- 関数値の型付けと効果の被覆を足した共通化も、この入力では偽である。 -/
theorem common_application_false (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ¬ (HasTypeCQ P B Ψ Qempty [] context [] none
        (.app (.var 0) []) (.tvar 0) Eff.empty [] →
      ∃ t a e, HasTypeVQ P B Ψ Qempty [] context [] (.var 0) (.dependentFn t) ∧
        HasTypeTelArgsQ P B Ψ Qempty [] context [] [] t a e ∧
        Ty.LeQ P context [] a (.tvar 0) ∧ Eff.Covers context [] Eff.empty e) := by
  intro common
  obtain ⟨t,a,e,_,args,le,_⟩ := common (source P B Ψ)
  exact no_telescope P B Ψ ⟨t,a,e,args,le⟩

/-- この文脈からCtx.WFを無条件に供給することもできない。 -/
theorem context_not_wf : ¬ Ctx.WF 0 0 context := by
  intro h
  have hw := h 0 (.fn [] [] (.tvar 0) Eff.empty) rfl
  exact Nat.not_lt_zero 0 hw.2.2.1

/-- 結果をUnitにした同じ零引数の形は、共通の依存列を持つ。 -/
theorem formed_contrast (P : Program) (B : Builtins) (Ψ : StoreTy) :
    let Γ : Ctx := [some (.fn [] [] (.base .unit) Eff.empty)]
    HasTypeCQ P B Ψ Qempty [] Γ [] none
      (.app (.var 0) []) (.base .unit) Eff.empty [] ∧
    ∃ t a e, HasTypeVQ P B Ψ Qempty [] Γ [] (.var 0) (.dependentFn t) ∧
      HasTypeTelArgsQ P B Ψ Qempty [] Γ [] [] t a e ∧
      Ty.LeQ P Γ [] a (.base .unit) ∧ Eff.Covers Γ [] Eff.empty e := by
  dsimp
  have raw : HasTypeVQ P B Ψ Qempty [] [some (.fn [] [] (.base .unit) Eff.empty)] []
      (.var 0) (.fn [] [] (.base .unit) Eff.empty) :=
    .V_Var rfl (by intro b t e he; cases he)
  have ann : Ty.Annotation P [] [some (.fn [] [] (.base .unit) Eff.empty)]
      (.dependentFn (.done (.base .unit) Eff.empty)) :=
    ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩
  refine ⟨.C_App raw .nil, .done (.base .unit) Eff.empty, .base .unit, Eff.empty, ?_,
    .done ann, .refl, Eff.Covers.refl _ _ _⟩
  have same : (Ty.dependentFn (.done (.base .unit) Eff.empty)).norm =
      (Ty.fn [] [] (.base .unit) Eff.empty).norm :=
    Ty.norm_toTel (ns := []) (ps := []) (r := .base .unit) (e := Eff.empty)
      ⟨rfl,by simp⟩
  exact raw.V_Sub (.convert same.symm) ann.wf ann.sorted ann.declared

end Benitoite.Release.Refinement.ApplicationObstruction

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (n, _) =>
    if (n.toString.splitOn "ApplicationObstruction").length > 1 then some n else none).mergeSort
    (fun a b => a.toString < b.toString)
  for n in names do
    logInfo m!"OBSTRUCTION_TARGET {n}"
    elabCommand (← `(#print axioms $(mkIdent n)))
