import Benitoite.Release.Refinement.Finite
import Benitoite.Release.Refinement.ClosedDecidable
import Benitoite.Release.Refinement.Le

/-! 有限支持の下で型・効果を比較する検査（設計書 01-12「部分型と被覆」）。 -/
namespace Benitoite.Release.Refinement.Surface.CheckCompare

instance rangeExprCoversDecidable (r s : RangeExpr) : Decidable (r.Covers s) := by
  unfold RangeExpr.Covers
  cases r <;> cases s <;> infer_instance

instance rangeIxCoversDecidable (r s : RangeIx) : Decidable (r.Covers s) := by
  cases r <;> cases s <;> unfold RangeIx.Covers <;> infer_instance

instance atomCoversDecidable (a b : Atom) : Decidable (a.Covers b) := by
  cases a with
  | rho i => cases b <;> unfold Atom.Covers <;> infer_instance
  | name l ix => cases b with
    | rho i => cases ix <;> unfold Atom.Covers <;> infer_instance
    | name m jx => cases ix <;> cases jx <;> unfold Atom.Covers <;> infer_instance

/-- 正規化しない構造等号。 -/
def rawTyEq (s : List Atom) (a b : Ty) : Bool := decide (tyCompareWith s a b = .eq)

theorem rawTyEq_spec {s a b} (ha : a.Support (· ∈ s)) (hb : b.Support (· ∈ s)) :
    rawTyEq s a b = true ↔ a = b := by
  simp only [rawTyEq, decide_eq_true_eq, compareWith_eq_compare s a b ha hb, tyCompare_eq_iff]

def rawEffEq (s : List Atom) (e f : Eff) : Bool :=
  rawTyEq s (.fn [] [] (.base .unit) e) (.fn [] [] (.base .unit) f)

theorem rawEffEq_spec {s e f} (he : e.Support (· ∈ s)) (hf : f.Support (· ∈ s)) :
    rawEffEq s e f = true ↔ e = f := by
  rw [rawEffEq, rawTyEq_spec (by exact ⟨trivial, trivial, he⟩) (by exact ⟨trivial, trivial, hf⟩)]
  simp only [Ty.fn.injEq, true_and]

def normTyEq (s : List Atom) (a b : Ty) : Bool := rawTyEq s (a.normWith s) (b.normWith s)

theorem normTyEq_spec {s a b} (ha : a.Support (· ∈ s)) (hb : b.Support (· ∈ s)) :
    normTyEq s a b = true ↔ a.norm = b.norm := by
  unfold normTyEq
  rw [rawTyEq_spec (Ty.normWith_support s a ha) (Ty.normWith_support s b hb),
    Ty.normWith_eq_norm s a ha, Ty.normWith_eq_norm s b hb]

def rawTelEq (s : List Atom) (t u : Tel) : Bool := decide (telCompareWith s t u = .eq)

theorem rawTelEq_spec {s t u} (ht : t.Support (· ∈ s)) (hu : u.Support (· ∈ s)) :
    rawTelEq s t u = true ↔ t = u := by
  simp only [rawTelEq, decide_eq_true_eq, telCompareWith_eq_iff s t u ht hu]

/-- Fail の型は、正規化した同じ型の存在で比較する。 -/
def failSub (s : List Atom) (inner outer : Eff) : Bool :=
  inner.fails.all fun a => outer.fails.any fun b => normTyEq s a b

theorem failSub_sound {s inner outer} (hi : inner.Support (· ∈ s)) (ho : Ty.SupportList (· ∈ s) outer.fails)
    (h : failSub s inner outer = true) : ∀ t, inner.memFail t → outer.memFail t := by
  intro t ht
  obtain ⟨a, ha, hat⟩ := ht
  have hab := (List.all_eq_true.mp h) a ha
  obtain ⟨b, hb, he⟩ := List.any_eq_true.mp hab
  have hai := Ty.SupportList.iff.mp ((Eff.support_iff inner).mp hi).2 a ha
  have hbo := Ty.SupportList.iff.mp ho b hb
  exact ⟨b, hb, ((normTyEq_spec hai hbo).mp he).symm.trans hat⟩

/-- 構造上の包含。候補列は内側の原子の全てを含む必要がある。 -/
def effSub (s : List Atom) (inner outer : Eff) : Bool :=
  (s.all fun a => !inner.test a || outer.test a) && failSub s inner outer

theorem effSub_sound {s inner outer} (hi : inner.Support (· ∈ s)) (ho : Ty.SupportList (· ∈ s) outer.fails)
    (h : effSub s inner outer = true) : Eff.Sub inner outer := by
  obtain ⟨hat, hfail⟩ := Bool.and_eq_true_iff.mp h
  refine ⟨?_, failSub_sound hi ho hfail⟩
  intro a ha
  have hs := (Eff.support_iff inner).mp hi
  have hh := List.all_eq_true.mp hat a (hs.1 a ha)
  simpa only [ha, Bool.not_true, Bool.false_or] using hh

/-- 内側の一原子ごとに、一つの外側の原子を選ぶ。 -/
def effCovers (s : List Atom) (outer inner : Eff) : Bool :=
  (s.all fun a => !inner.test a || s.any (fun b => outer.test b && decide (b.Covers a))) &&
    failSub s inner outer

theorem effCovers_sound {s outer inner Γ Φ} (hi : inner.Support (· ∈ s)) (ho : Ty.SupportList (· ∈ s) outer.fails)
    (h : effCovers s outer inner = true) : Eff.Covers Γ Φ outer inner := by
  obtain ⟨hat, hfail⟩ := Bool.and_eq_true_iff.mp h
  refine ⟨?_, failSub_sound hi ho hfail⟩
  intro a ha
  have hs := (Eff.support_iff inner).mp hi
  have hh := List.all_eq_true.mp hat a (hs.1 a ha)
  have hex : (s.any fun b => outer.test b && decide (b.Covers a)) = true := by
    simpa only [ha, Bool.not_true, Bool.false_or] using hh
  obtain ⟨b, _, hb⟩ := List.any_eq_true.mp hex
  exact ⟨b, (Bool.and_eq_true_iff.mp hb).1, of_decide_eq_true (Bool.and_eq_true_iff.mp hb).2⟩

end Benitoite.Release.Refinement.Surface.CheckCompare
