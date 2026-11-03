import Benitoite.Release.Refinement.ValueFacts
import Benitoite.Release.Refinement.TypedMeaningExamples

/-! # 値の芯と値に固有の篩の事実の逆転 -/
namespace Benitoite.Release.Refinement

private theorem core_le {P Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) :
    Ty.LeQ P Γ Φ a.norm.core b.norm.core := by
  match h with
  | .refl => exact .refl
  | .convert he => exact .convert (congrArg (fun a : Ty => a.core.norm) he)
  | .trans h g => exact .trans (core_le h) (core_le g)
  | .forget | .introduce .. => simpa only [Ty.refined_norm_core] using (Ty.LeQ.refl (P := P) (Γ := Γ) (Φ := Φ))
  | .refine h .. => simpa only [Ty.refined_norm_core] using core_le h
  | h@(.fn_effect _) | h@(.list _) | h@(.lazy _) | h@(.map_value _ _) | h@(.dependentFn _) |
      h@(.scoped _) | h@(.scoped_forget) | h@(.data _) =>
    simpa only [Ty.norm, Ty.core, Ty.core_foldFn] using h.norm

/-- 変数の元の型との関係は芯までとし、最外の篩はfactsから別に読む。 -/
theorem HasTypeVQ.inv_var {P B Ψ Q C Γ Φ v T i}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .var i) :
    ∃ a b, Γ[i]? = some (some a) ∧ a.Ordinary ∧
      T.norm.core = b ∧ Ty.LeQ P Γ Φ a.norm.core b := by
  match h with
  | .V_Var hi ho => cases hv; exact ⟨_,_,hi,ho,rfl,.refl⟩
  | .V_Normal h =>
    obtain ⟨a,b,hi,ho,ht,le⟩ := h.inv_var hv
    exact ⟨a,b,hi,ho,by simpa only [Ty.norm_idem] using ht,le⟩
  | .V_Sub h hl .. =>
    obtain ⟨a,b,hi,ho,ht,le⟩ := h.inv_var hv
    refine ⟨a,T.norm.core,hi,ho,rfl,.trans le ?_⟩
    rw [←ht]
    exact core_le hl
  | .V_Refine h .. =>
    obtain ⟨a,b,hi,ho,ht,le⟩ := h.inv_var hv
    exact ⟨a,b,hi,ho,by simpa only [Ty.refined_norm_core] using ht,le⟩
  | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
      .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
      .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
      .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. |
      .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. |
      .V_Super .. | .V_List .. => cases hv

private theorem list_core {a b : Ty} (h : a.listCore = some b) : a.core = .list b := by
  match a with
  | .refined a p => exact list_core (a := a) h
  | .list a => cases h; rfl
  | .base .. | .opaque .. | .data .. | .fn .. | .tvar .. | .reference .. | .lazy .. |
      .cont .. | .map .. | .set .. | .bytes | .dict .. | .tapp .. | .ctor .. |
      .dependentFn .. | .external .. | .scoped .. | .pathBases | .scopePattern .. => cases h

/-- 要素の部分型関係を芯のListまで返し、列全体の篩と区別する。 -/
theorem HasTypeVQ.inv_list_core {P B Ψ Q C Γ Φ v T vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .list vs) :
    ∃ a b, HasTypeEachQ P B Ψ Q C Γ Φ vs a ∧ Ty.Annotation P C Γ a ∧
      T.norm.core = .list b ∧ Ty.LeQ P Γ Φ a b := by
  match h with
  | .V_List hs hw hsort hd =>
    cases hv
    exact ⟨_,_,hs,⟨hw,hsort,hd⟩,rfl,.convert (Ty.norm_idem _).symm⟩
  | .V_Normal h =>
    obtain ⟨a,b,hs,ha,ht,le⟩ := h.inv_list_core hv
    exact ⟨a,b,hs,ha,by simpa only [Ty.norm_idem] using ht,le⟩
  | .V_Sub h hl .. =>
    obtain ⟨a,b,hs,ha,ht,le⟩ := h.inv_list_core hv
    have hc : _ := congrArg Ty.listCore ht
    simp only [Ty.listCore_core,Ty.listCore] at hc
    obtain ⟨c,hc,hbc⟩ := hl.norm.listCore hc
    exact ⟨a,c,hs,ha,list_core hc,.trans le hbc⟩
  | .V_Refine h .. =>
    obtain ⟨a,b,hs,ha,ht,le⟩ := h.inv_list_core hv
    exact ⟨a,b,hs,ha,by simpa only [Ty.refined_norm_core] using ht,le⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
      .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
      .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
      .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. |
      .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. |
      .V_Super .. => cases hv

/-- 篩付き定数でも、芯とその同じ値の事実を同時に読む。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ConstOK B (.integer ⟨5,by decide⟩) ∧
    monthType.norm.core = .base .integer ∧
    ∀ p ∈ monthType.assume, Entails [] (p.open (.integer 5)) := by
  have h := TypedMeaningExamples.month_typed P B Ψ
  exact ⟨(h.inv_const rfl).1,(h.inv_const rfl).2,h.facts rfl⟩

namespace ValueInversionExamples

/-- 値5の篩から、Integer全体が同じ篩に入るとは結論できない。 -/
private theorem whole_type_rejected (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ¬ (∀ {Q C Γ Φ T c}, HasTypeVQ P B Ψ Q C Γ Φ (.const c) T →
        ConstOK B c ∧ Ty.LeQ P Γ Φ (Const.type c) T) := by
  intro h
  have le := (h (TypedMeaningExamples.month_typed P B Ψ)).2
  have z : HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer ⟨0,by decide⟩))
      (Const.type (.integer ⟨5,by decide⟩)) := .V_Const trivial
  have mem : Pred.le (.integer 1) (.var 0) ∈ monthType.assume := by
    simp [monthType,monthPredicate,Ty.assume,Ty.core,Ty.carrierFacts,
      Ty.refinementPredicates,Pred.conjuncts]
  have unsound := Entails.sound (z.subtype_facts le rfl _ mem) (fun _ => none) (by simp [Ctx.facts])
  revert unsound
  decide

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ConstOK B (.integer ⟨5,by decide⟩) ∧ monthType.norm.core = .base .integer ∧
    ¬ (∀ {Q C Γ Φ T c}, HasTypeVQ P B Ψ Q C Γ Φ (.const c) T →
        ConstOK B c ∧ Ty.LeQ P Γ Φ (Const.type c) T) :=
  ⟨((TypedMeaningExamples.month_typed P B Ψ).inv_const rfl).1,
    ((TypedMeaningExamples.month_typed P B Ψ).inv_const rfl).2,whole_type_rejected P B Ψ⟩

/-- V_Refineを経た変数でも、芯と同じ変数の事実を別々に返す。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ∃ a b, [some (Ty.base .integer)][0]? = some (some a) ∧ a.Ordinary ∧
      (Ty.refined (.base .integer) .truth).norm.core = b ∧
      Ty.LeQ P [some (.base .integer)] [] a.norm.core b := by
  have raw : HasTypeVQ P B Ψ Qempty [] [some (.base .integer)] [] (.var 0) (.base .integer) :=
    .V_Var rfl (by intro b t e h; cases h)
  have typed := HasTypeVQ.V_Refine (p := Pred.truth) raw rfl rfl trivial trivial
    Entails.truth trivial trivial
  exact typed.inv_var rfl

/-- 観測不能な子を含む非空列でも、要素と列全体の篩を混同しない。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ∃ a b, HasTypeEachQ P B Ψ Qempty [] [] []
      (List.replicate 1 unobservableFunction) a ∧ Ty.Annotation P [] [] a ∧
      (nonemptyType unobservableFunctionType).norm.core = .list b ∧ Ty.LeQ P [] [] a b := by
  obtain ⟨typed,_⟩ := unobservable_length_coverage P B Ψ 1 (by decide)
  exact typed.inv_list_core rfl

end ValueInversionExamples

end Benitoite.Release.Refinement
