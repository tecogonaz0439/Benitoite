import Benitoite.Release.Refinement.Kinds
import Benitoite.Release.Refinement.EffectCover

/-!
# 篩と推移を通る構文の逆転

最外の篩だけを除き、要素の導出と依存列の推移閉包を保つ。
参照内容と Fail は正規化後の構造の等号で読む。
-/
namespace Benitoite.Release.Refinement

variable {P : Program}

def Ty.listCore : Ty → Option Ty
  | .list a => some a
  | .refined a _ => a.listCore
  | _ => none

def Ty.fnCore : Ty → Option Tel
  | .fn ns ps r e => some (Ty.toTel ns ps r e)
  | .dependentFn t => some t
  | .refined a _ => a.fnCore
  | _ => none

def Ty.refCore : Ty → Option Ty
  | .reference a => some a
  | .refined a _ => a.refCore
  | _ => none

theorem TelLe.of_norm_eq {Γ Φ t u} (h : Tel.norm t = Tel.norm u) : TelLe P Γ Φ t u := by
  cases t <;> cases u <;> simp only [Tel.norm, Tel.done.injEq, Tel.param.injEq] at h
  case done.done r e s f =>
    exact .done (.convert h.1) ((Eff.covers_norm_left.mp
      (Eff.covers_norm_right.mp (by rw [h.2]; exact Eff.Covers.refl Γ Φ _))))
  case param.param n a t m b u =>
    obtain ⟨rfl, ha, ht⟩ := h
    exact .param (.convert ha.symm) (TelLe.of_norm_eq ht)
  all_goals cases h

@[simp] theorem Ty.listCore_core (a : Ty) : a.core.listCore = a.listCore := by
  cases a with
  | refined a p => exact Ty.listCore_core a
  | _ => rfl
@[simp] theorem Ty.fnCore_core (a : Ty) : a.core.fnCore = a.fnCore := by
  cases a with
  | refined a p => exact Ty.fnCore_core a
  | _ => rfl
@[simp] theorem Ty.refCore_core (a : Ty) : a.core.refCore = a.refCore := by
  cases a with
  | refined a p => exact Ty.refCore_core a
  | _ => rfl

theorem Ty.listCore_refineNorm (a : Ty) (p : Pred) : (a.refineNorm p).listCore = a.listCore := by
  unfold Ty.refineNorm Ty.packRefinements
  split <;> simp only [Ty.listCore, Ty.listCore_core]
theorem Ty.fnCore_refineNorm (a : Ty) (p : Pred) : (a.refineNorm p).fnCore = a.fnCore := by
  unfold Ty.refineNorm Ty.packRefinements
  split <;> simp only [Ty.fnCore, Ty.fnCore_core]
theorem Ty.refCore_refineNorm (a : Ty) (p : Pred) : (a.refineNorm p).refCore = a.refCore := by
  unfold Ty.refineNorm Ty.packRefinements
  split <;> simp only [Ty.refCore, Ty.refCore_core]

theorem Ty.listCore_foldFn (t : Tel) : (Ty.foldFn t).listCore = none := by
  unfold Ty.foldFn
  split <;> rfl
theorem Ty.refCore_foldFn (t : Tel) : (Ty.foldFn t).refCore = none := by
  unfold Ty.foldFn
  split <;> rfl
theorem Ty.fnCore_foldFn (t : Tel) : (Ty.foldFn t).fnCore = some t := by
  unfold Ty.foldFn
  split
  · rename_i f hf
    exact congrArg some ((Tel.fnView?_eq_some_iff _ _).mp hf)
  · rfl

theorem Ty.foldFn_injective : Function.Injective Ty.foldFn := by
  intro t u he
  have hh := congrArg Ty.fnCore he
  simpa only [Ty.fnCore_foldFn, Option.some.injEq] using hh

theorem Ty.listCore_norm (a : Ty) : a.norm.listCore = a.listCore.map Ty.norm := by
  cases a <;> try rfl
  case refined a p => simp only [Ty.norm, Ty.listCore_refineNorm, Ty.listCore, Ty.listCore_norm]
  case dependentFn t => exact Ty.listCore_foldFn _
theorem Ty.refCore_norm (a : Ty) : a.norm.refCore = a.refCore.map Ty.norm := by
  cases a <;> try rfl
  case refined a p => simp only [Ty.norm, Ty.refCore_refineNorm, Ty.refCore, Ty.refCore_norm]
  case dependentFn t => exact Ty.refCore_foldFn _
theorem Ty.fnCore_norm (a : Ty) : a.norm.fnCore = a.fnCore.map Tel.norm := by
  cases a <;> try rfl
  case refined a p => simp only [Ty.norm, Ty.fnCore_refineNorm, Ty.fnCore, Ty.fnCore_norm]
  case dependentFn t => exact Ty.fnCore_foldFn _
  case fn ns ps r e => exact congrArg some (Tel.norm_toTel ns ps r e).symm

@[simp] theorem Ty.refined_norm_core (a : Ty) (p : Pred) :
    (Ty.refined a p).norm.core = a.norm.core := by
  exact Ty.core_refineNorm _ _

@[simp] theorem Ty.notDataCore_dependentFn {t : Tel} {d : DataName} {ts : List Ty} :
    (Ty.dependentFn t).norm.core ≠ .data d ts := by
  simp only [Ty.norm, Ty.core_foldFn]
  unfold Ty.foldFn
  split <;> intro he <;> cases he

theorem TelClosure.trans {Γ Φ t u v}
    (h : TelClosure P Γ Φ t u) (g : TelClosure P Γ Φ u v) : TelClosure P Γ Φ t v := by
  match g with
  | .refl => exact h
  | .tail g s => exact .tail (h.trans g) s

theorem TelLe.toTel_effect {Γ Φ ns ps r e f}
    (h : Eff.Covers Γ Φ f e) :
    TelLe P Γ Φ (Ty.toTel ns ps r e) (Ty.toTel ns ps r f) := by
  induction ns generalizing Γ Φ ps r e f with
  | nil => exact .done .refl h
  | cons n ns ih =>
    cases ps with
    | nil => exact .done .refl h
    | cons a ps =>
      exact .param .refl (ih (h.shiftV 1 0))

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

private theorem list_relation {Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) :
    OptionRel (Ty.LeQ P Γ Φ) a.listCore b.listCore := by
  match h with
  | .refl => exact OptionRel.refl (fun _ => .refl) _
  | .convert he =>
    apply OptionRel.of_map_eq (f := Ty.norm) (fun _ _ he => Ty.LeQ.convert he)
    rw [←Ty.listCore_norm, ←Ty.listCore_norm, he]
  | .trans h g => exact OptionRel.trans (R := Ty.LeQ P Γ Φ) (fun h g => Ty.LeQ.trans h g) (list_relation h) (list_relation g)
  | .list h => exact h
  | .forget | .introduce .. => exact OptionRel.refl (fun _ => .refl) _
  | .refine h .. => simpa only [Ty.listCore] using list_relation h
  | .data _ | .fn_effect _ | .lazy _ | .map_value _ _ | .dependentFn _ | .scoped _ | .scoped_forget => trivial

private theorem fn_relation {Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) :
    OptionRel (TelClosure P Γ Φ) a.fnCore b.fnCore := by
  match h with
  | .refl => exact OptionRel.refl (fun _ => .refl) _
  | .convert he =>
    apply OptionRel.of_map_eq (f := Tel.norm) (fun _ _ he => TelClosure.tail .refl (TelLe.of_norm_eq he))
    rw [←Ty.fnCore_norm, ←Ty.fnCore_norm, he]
  | .trans h g => exact OptionRel.trans (R := TelClosure P Γ Φ) (fun h g => TelClosure.trans h g) (fn_relation h) (fn_relation g)
  | .fn_effect h => exact .tail .refl (TelLe.toTel_effect h)
  | .dependentFn h => exact h
  | .forget | .introduce .. => exact OptionRel.refl (fun _ => .refl) _
  | .refine h .. => simpa only [Ty.fnCore] using fn_relation h
  | .data _ | .list _ | .lazy _ | .map_value _ _ | .scoped _ | .scoped_forget => trivial

private theorem ref_relation {Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) :
    OptionRel (fun x y : Ty => x.norm = y.norm) a.refCore b.refCore := by
  match h with
  | .refl => exact OptionRel.refl (R := fun x y : Ty => x.norm = y.norm) (fun _ => rfl) _
  | .convert he =>
    apply OptionRel.of_map_eq (f := Ty.norm) (fun _ _ he => he)
    rw [←Ty.refCore_norm, ←Ty.refCore_norm, he]
  | .trans h g => exact OptionRel.trans (R := fun x y : Ty => x.norm = y.norm) (fun h g => h.trans g) (ref_relation h) (ref_relation g)
  | .forget | .introduce .. => exact OptionRel.refl (R := fun x y : Ty => x.norm = y.norm) (fun _ => rfl) _
  | .refine h .. => simpa only [Ty.refCore] using ref_relation h
  | .data _ | .fn_effect _ | .dependentFn _ | .list _ | .lazy _ | .map_value _ _ | .scoped _ | .scoped_forget => trivial

theorem Ty.LeQ.listCore {Γ Φ a b x}
    (h : Ty.LeQ P Γ Φ a b) (ha : a.listCore = some x) :
    ∃ y, b.listCore = some y ∧ Ty.LeQ P Γ Φ x y := (list_relation h).left ha

theorem Ty.LeQ.listCore_right {Γ Φ a b y}
    (h : Ty.LeQ P Γ Φ a b) (hb : b.listCore = some y) :
    ∃ x, a.listCore = some x ∧ Ty.LeQ P Γ Φ x y := (list_relation h).right hb

theorem Ty.LeQ.fnCore {Γ Φ a b t}
    (h : Ty.LeQ P Γ Φ a b) (ha : a.fnCore = some t) :
    ∃ u, b.fnCore = some u ∧ TelClosure P Γ Φ t u := (fn_relation h).left ha

theorem Ty.LeQ.fnCore_right {Γ Φ a b u}
    (h : Ty.LeQ P Γ Φ a b) (hb : b.fnCore = some u) :
    ∃ t, a.fnCore = some t ∧ TelClosure P Γ Φ t u := (fn_relation h).right hb

theorem Ty.LeQ.names_eq {Γ Φ a b t u}
    (h : Ty.LeQ P Γ Φ a b) (ha : a.fnCore = some t) (hb : b.fnCore = some u) :
    t.names = u.names := by
  obtain ⟨v, hv, ht⟩ := h.fnCore ha
  have he := Option.some.inj (hv.symm.trans hb)
  exact ht.names.trans (congrArg Tel.names he)

theorem Ty.LeQ.refCore {Γ Φ a b x}
    (h : Ty.LeQ P Γ Φ a b) (ha : a.refCore = some x) :
    ∃ y, b.refCore = some y ∧ x.norm = y.norm := (ref_relation h).left ha

theorem Ty.LeQ.refCore_right {Γ Φ a b y}
    (h : Ty.LeQ P Γ Φ a b) (hb : b.refCore = some y) :
    ∃ x, a.refCore = some x ∧ x.norm = y.norm := (ref_relation h).right hb

theorem Eff.memFail_single_iff (a b : Ty) :
    (Eff.singleFail a).memFail b ↔ a.norm = b.norm := by
  simp only [Eff.singleFail, Eff.memFail, Eff.fails, List.mem_singleton]
  constructor
  · rintro ⟨x, rfl, h⟩
    exact (Ty.norm_idem a).symm.trans h
  · intro h
    exact ⟨a.norm, rfl, (Ty.norm_idem a).trans h⟩

theorem ProperApply.list_inv {a as x}
    (h : ProperApply a as (.list x)) : a = .ctor .list ∧ as = [x] := by
  cases h
  exact ⟨rfl, rfl⟩

theorem ProperApply.fn_impossible {a as ns ps r e} :
    ¬ ProperApply a as (.fn ns ps r e) := by
  intro h
  cases h

theorem Ty.HasKind.not_refined_constructor {P K a p n} :
    ¬ Ty.HasKind P K (.refined a p) (.constructor n) := by
  exact id

theorem rawApply_list_inv {P K a n as x}
    (hk : a.HasKind P K (.constructor n)) (hn : as.length = n)
    (he : rawApply a as = .list x) : a = .ctor .list ∧ as = [x] := by
  have hp := rawApply_proper hk hn
  rw [he] at hp
  exact hp.list_inv

theorem TypeImagesKinded.list_inv {P K L θ i n as x}
    (h : TypeImagesKinded P K L θ) (hi : K[i]? = some (.constructor n))
    (hn : as.length = n) (he : rawApply (θ i) as = .list x) :
    θ i = .ctor .list ∧ as = [x] :=
  rawApply_list_inv (h i _ hi).1 hn he

end Benitoite.Release.Refinement
