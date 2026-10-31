import Lean
import Benitoite.Release.Refinement.Canonical
import Benitoite.Release.Refinement.SubstitutionContracts
/-! rawApply の修正により、以前の反例の元の導出が拒否される。 -/
namespace Benitoite.Release.Refinement.SourceKindCounter
private def flavor : Ty → Option Bool
  | .tvar _ => some false
  | .tapp _ _ => some true
  | .refined a _ => flavor a
  | _ => none
private theorem flavor_core (a : Ty) : flavor a.core = flavor a := by
  cases a with
  | refined a p => exact flavor_core a
  | _ => rfl
private theorem flavor_refineNorm (a : Ty) (p : Pred) : flavor (a.refineNorm p) = flavor a := by
  unfold Ty.refineNorm Ty.packRefinements
  split <;> simp only [flavor, flavor_core]
private theorem flavor_norm (a : Ty) : flavor a.norm = flavor a := by
  cases a <;> try rfl
  case refined a p => simp only [Ty.norm, flavor_refineNorm, flavor, flavor_norm]
  case dependentFn t => unfold Ty.norm Ty.foldFn; split <;> rfl
private theorem flavor_le {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) : flavor a = flavor b := by
  match h with
  | .refl => rfl
  | .convert he => rw [←flavor_norm a, he, flavor_norm]
  | .trans h g => exact (flavor_le h).trans (flavor_le g)
  | .refine h .. => simpa only [flavor] using flavor_le h
  | .forget | .introduce .. | .fn_effect _ | .list _ | .lazy _ | .map_value _ _ |
    .dependentFn _ | .scoped _ | .scoped_forget => rfl
abbrev arg : Ty := .refined (.tvar 0) .truth
abbrev source : Ty := .tapp 0 [.base .unit]
def cd : ConDecl := ⟨"D", 1, [source]⟩
def prog : Program :=
  { defs := fun _ => none, cons := fun _ => some cd, ops := fun _ => none, effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def builtins : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => True,
    refGet := "get", refSet := "set" }
abbrev Γ : Ctx := [some (.tvar 0)]
abbrev C : List TParam := [{}]
abbrev value : Val := .con "C" [arg] [.var 0]
abbrev result : Ty := .data "D" [arg]

private theorem var_flavor {P B Ψ Q C1 Γ1 Φ1 T v} (h : HasTypeVQ P B Ψ Q C1 Γ1 Φ1 v T) (hg : Γ1 = Γ) (hv : v = .var 0) :
    flavor T = some false := by
  match h with
  | .V_Var hi _ => cases hv; subst Γ1; cases Option.some.inj hi; rfl
  | .V_Normal h => simpa only [flavor_norm] using var_flavor h hg hv
  | .V_Sub h hl .. => exact (flavor_le hl).symm.trans (var_flavor h hg hv)
  | .V_Refine h .. => simpa only [flavor] using var_flavor h hg hv
  | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. |
    .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
    .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. |
    .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. |
    .V_Con .. | .V_Super .. | .V_List .. => cases hv

private theorem changed_arguments_untypable {B Ψ Q C Γ Φ v T}
    (h : HasTypeVQ prog B Ψ Q C Γ Φ v T)
    (hc : C = SourceKindCounter.C) (hg : Γ = SourceKindCounter.Γ) (hp : Φ = [])
    (hv : v = .con "C" [arg] [.var 0]) : False := by
  match h with
  | .V_Con hl _ _ _ hvs _ =>
    cases hv
    have he : _ = cd := Option.some.inj hl.symm
    cases he
    subst C Γ Φ
    cases hvs with
    | cons hh ht => exact Bool.noConfusion (Option.some.inj (var_flavor hh rfl rfl))
  | .V_Normal h => exact changed_arguments_untypable h hc hg hp hv
  | .V_Sub h .. => exact changed_arguments_untypable h hc hg hp hv
  | .V_Refine h .. => exact changed_arguments_untypable h hc hg hp hv
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. |
    .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
    .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. |
    .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. |
    .V_Super .. | .V_List .. => cases hv

theorem original_derivation_rejected (Ψ : StoreTy) (a : Ty) :
    ¬ HasTypeVQ prog builtins Ψ Qempty C Γ [] value a := by
  intro h
  exact changed_arguments_untypable h rfl rfl rfl rfl

theorem value_kind_refined_image : arg.HasKind prog [.value] .value := by
  simp [Ty.HasKind, Ty.NotContCore]

theorem proper_constructor_unchanged :
    rawApply (.ctor .list) [arg] = .list arg := rfl

theorem identity_images (Ψ : StoreTy) :
    ∀ i a, Γ[i]? = some (some a) →
      ImageOk prog builtins Ψ Qempty C Γ [] none Val.var i a := by
  intro i a hi
  cases i with
  | zero =>
    cases Option.some.inj hi
    apply ImageOk.ordinary (by simp)
    change HasTypeVQ prog builtins Ψ Qempty C Γ [] (.var 0) (.tvar 0)
    exact .V_Var rfl (by simp [Ordinary])
  | succ i => simp [Γ] at hi

theorem identity_facts :
    ∀ p ∈ Γ.facts ++ ([] : List Pred), Entails (Γ.facts ++ [])
      (predBind (valEnv Val.var).values p) := by
  intro p hp
  simp [Γ, Ctx.facts, Ty.assume, Ty.refinementPredicates] at hp

-- Bの制約と署名は、値・型の移動と置換に対する信頼条件を満たす。
-- satの全ての保存則はこの定理を使い、admitsの保存則はsig_noneで前提を排除する。
theorem sat_any (C1 : List TParam) (a : Ty) (p : TParam) : builtins.sat C1 a p := trivial

theorem sig_none (b : PrimName) (s : PrimSig) : builtins.sig b ≠ some s := by
  intro he; cases he

theorem assumptions : Builtins.SubstitutionAssumptions prog builtins := by
  constructor
  · constructor
    · intros; trivial
    · intro b sg C1 Γ1 Δ1 ts ξ hl
      cases hl
    · intros; trivial
    · intro b sg Ψ Q1 C1 Γ1 Δ1 Ξ1 ν ts hl
      cases hl
  · constructor
    · intros; trivial
    · intro b sg C1 C2 Γ1 Δ1 ts ρ hl
      cases hl
    · intros; trivial
    · intro b sg C0 C1 ts ts' es' hl
      cases hl

theorem old_counterexample_input_rejected :
    Builtins.SubstitutionAssumptions prog builtins ∧
    StoreTy.WF StoreTy.empty ∧
    SubstOk prog builtins StoreTy.empty Qempty C Γ [] Γ [] none Val.var ∧
    ¬ HasTypeVQ prog builtins StoreTy.empty Qempty C Γ [] value result :=
  ⟨assumptions, StoreTy.WF.empty, identity_images _, original_derivation_rejected _ _⟩

end Benitoite.Release.Refinement.SourceKindCounter

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn ".SourceKindCounter.").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
