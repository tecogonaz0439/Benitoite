import Benitoite.Release.Refinement.ReferencePreservation

/-! # 明示遅延の共変な結果型とセルの逆転 -/
namespace Benitoite.Release.Refinement
noncomputable section

def Ty.lazyCore : Ty → Option Ty
  | .lazy a => some a
  | .refined a _ => a.lazyCore
  | _ => none

private theorem lazyCore_core (a : Ty) : a.core.lazyCore = a.lazyCore := by
  cases a with
  | refined a p => exact lazyCore_core a
  | _ => rfl

private theorem lazyCore_refineNorm (a : Ty) (p : Pred) :
    (a.refineNorm p).lazyCore = a.lazyCore := by
  unfold Ty.refineNorm Ty.packRefinements
  split <;> simp only [Ty.lazyCore,lazyCore_core]

private theorem lazyCore_foldFn (t : Tel) : (Ty.foldFn t).lazyCore = none := by
  unfold Ty.foldFn
  split <;> rfl

theorem Ty.lazyCore_norm (a : Ty) : a.norm.lazyCore = a.lazyCore.map Ty.norm := by
  cases a <;> try rfl
  case refined a p => simp only [Ty.norm,lazyCore_refineNorm,Ty.lazyCore,Ty.lazyCore_norm]
  case dependentFn t => exact lazyCore_foldFn _

private def OptionRel {α : Type} (R : α → α → Prop) : Option α → Option α → Prop
  | none, none => True
  | some a, some b => R a b
  | _, _ => False

private theorem OptionRel.refl {α : Type} {R : α → α → Prop}
    (h : ∀ x, R x x) (a : Option α) : OptionRel R a a := by
  cases a with
  | none => trivial
  | some a => exact h a

private theorem OptionRel.trans {α : Type} {R : α → α → Prop}
    (ht : ∀ {a b c}, R a b → R b c → R a c)
    {a b c : Option α} (h : OptionRel R a b) (g : OptionRel R b c) : OptionRel R a c := by
  cases a <;> cases b <;> cases c <;> simp only [OptionRel] at h g ⊢
  all_goals first | contradiction | trivial | exact ht h g

private theorem OptionRel.left {α : Type} {R : α → α → Prop}
    {a b : Option α} {x : α} (h : OptionRel R a b) (ha : a = some x) :
    ∃ y, b = some y ∧ R x y := by
  subst a
  cases b with
  | none => cases h
  | some y => exact ⟨y, rfl, h⟩

private theorem OptionRel.right {α : Type} {R : α → α → Prop}
    {a b : Option α} {y : α} (h : OptionRel R a b) (hb : b = some y) :
    ∃ x, a = some x ∧ R x y := by
  subst b
  cases a with
  | none => cases h
  | some x => exact ⟨x, rfl, h⟩

private theorem OptionRel.of_map_eq {α β : Type} {R : α → α → Prop} {f : α → β}
    (hf : ∀ a b, f a = f b → R a b) {a b : Option α} (h : a.map f = b.map f) :
    OptionRel R a b := by
  cases a <;> cases b <;> simp only [Option.map_none, Option.map_some, Option.some.injEq] at h
  all_goals first | exact True.intro | exact hf _ _ h | contradiction

private theorem lazy_relation {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) :
    OptionRel (Ty.LeQ Γ Φ) a.lazyCore b.lazyCore := by
  match h with
  | .refl => exact OptionRel.refl (fun _ => .refl) _
  | .convert he =>
    apply OptionRel.of_map_eq (f := Ty.norm) (fun _ _ he => Ty.LeQ.convert he)
    rw [←Ty.lazyCore_norm, ←Ty.lazyCore_norm, he]
  | .trans h g => exact OptionRel.trans (R := Ty.LeQ Γ Φ) (fun h g => Ty.LeQ.trans h g) (lazy_relation h) (lazy_relation g)
  | .lazy h => exact h
  | .forget | .introduce .. => exact OptionRel.refl (fun _ => .refl) _
  | .refine h .. => simpa only [Ty.lazyCore] using lazy_relation h
  | .fn_effect _ | .list _ | .map_value _ _ | .dependentFn _ | .scoped _ | .scoped_forget => trivial

theorem Ty.LeQ.lazyCore {Γ Φ a b x}
    (h : Ty.LeQ Γ Φ a b) (ha : a.lazyCore = some x) :
    ∃ y, b.lazyCore = some y ∧ Ty.LeQ Γ Φ x y := (lazy_relation h).left ha

theorem Ty.LeQ.lazyCore_right {Γ Φ a b y}
    (h : Ty.LeQ Γ Φ a b) (hb : b.lazyCore = some y) :
    ∃ x, a.lazyCore = some x ∧ Ty.LeQ Γ Φ x y := (lazy_relation h).right hb

private theorem canonical_lazy_aux {P B Ψ Q C Γ Φ v T a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hΓ : Γ = []) (ha : T.lazyCore = some a) :
    ∃ l b, v = .loc l ∧ Ψ l = some (.lazy b) ∧ Ty.LeQ Γ Φ b a := by
  match h with
  | .V_Var hi _ => subst Γ; simp at hi
  | .V_Const (c := c) _ => cases c <;> simp [Const.type, Ty.lazyCore] at ha
  | .V_LocLazy hi _ => cases ha; exact ⟨_, _, rfl, hi, .refl⟩
  | .V_Normal (a := T0) h =>
    have hl : Ty.LeQ Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨b, hb, he⟩ := hl.lazyCore_right ha
    obtain ⟨l, c, hv, hc, hcb⟩ := canonical_lazy_aux h hΓ hb
    exact ⟨l, c, hv, hc, .trans hcb he⟩
  | .V_Sub h hl _ _ _ =>
    obtain ⟨b, hb, he⟩ := hl.lazyCore_right ha
    obtain ⟨l, c, hv, hc, hcb⟩ := canonical_lazy_aux h hΓ hb
    exact ⟨l, c, hv, hc, .trans hcb he⟩
  | .V_Refine h .. => exact canonical_lazy_aux h hΓ ha
  | .V_AtError hs => rw [hs.errorType_eq] at ha; cases ha
  | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. |
    .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
    .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_Bytes .. | .V_Con .. |
    .V_Super .. | .V_List .. => cases ha

theorem HasTypeVQ.canonical_lazy {P B Ψ Q C Φ v T a}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ha : T.lazyCore = some a) :
    ∃ l b, v = .loc l ∧ Ψ l = some (.lazy b) ∧ Ty.LeQ [] Φ b a :=
  canonical_lazy_aux h rfl ha


end
end Benitoite.Release.Refinement
