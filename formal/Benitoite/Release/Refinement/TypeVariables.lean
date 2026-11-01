import Benitoite.Release.Refinement.TypeBounds
import Benitoite.Release.Refinement.TypeRows
import Benitoite.Release.Refinement.ProgramWellFormed

/-! WF、行、範囲原子を束ねた変数の条件。型・行・範囲・値の上限を区別する。
設計書01-12「コア計算と脱糖」に対応する。 -/
namespace Benitoite.Release.Refinement

def rangeCondition (nr : Nat) : Atom → Prop
  | .name _ ix => ix.WF nr
  | .rho _ => True

mutual
  theorem Ty.rangesScoped_iff_support {nr nt nv : Nat} (a : Ty) (hw : a.WF nr nt nv) :
      a.RangesScoped nr ↔ a.Support (rangeCondition nr) := by
    cases a <;> simp only [Ty.WF] at hw <;> simp only [Ty.RangesScoped, Ty.Support]
    all_goals first | exact Iff.rfl | exact iff_of_true hw True.intro |
      exact Ty.rangesScoped_iff_support _ hw | exact rangesScopedTypes_iff_support _ hw |
      exact Tel.rangesScoped_iff_support _ hw | skip
    case fn ns ps r e => rw [rangesScopedTypes_iff_support ps hw.2.1,
      Ty.rangesScoped_iff_support r hw.2.2.1, Eff.rangesScoped_iff_support e hw.2.2.2.1]
    case cont a b e => rw [Ty.rangesScoped_iff_support a hw.1,
      Ty.rangesScoped_iff_support b hw.2.1, Eff.rangesScoped_iff_support e hw.2.2.1]
    case map a b => rw [Ty.rangesScoped_iff_support a hw.1, Ty.rangesScoped_iff_support b hw.2]
    case tapp i as => exact rangesScopedTypes_iff_support as hw.2
    case refined a p => exact Ty.rangesScoped_iff_support a hw.1
  theorem rangesScopedTypes_iff_support {nr nt nv : Nat} (as : List Ty)
      (hw : Ty.WFList nr nt nv as) :
      rangesScopedTypes nr as ↔ Ty.SupportList (rangeCondition nr) as := by
    cases as with
    | nil => rfl
    | cons a as => exact and_congr (Ty.rangesScoped_iff_support a hw.1) (rangesScopedTypes_iff_support as hw.2)
  theorem Eff.rangesScoped_iff_support {nr nt nv : Nat} (e : Eff) (hw : e.WF nr nt nv) :
      e.RangesScoped nr ↔ e.Support (rangeCondition nr) := by
    cases e with
    | mk atoms fs =>
      simp only [Eff.RangesScoped, Eff.Support, rangesScopedTypes_iff_support fs hw]
      apply and_congr_left
      intro _
      constructor
      · intro h a ha
        cases a with
        | name l ix => exact h l ix ha
        | rho => trivial
      · intro h l ix hi; exact h (.name l ix) hi
  theorem Tel.rangesScoped_iff_support {nr nt nv : Nat} (t : Tel) (hw : t.WF nr nt nv) :
      t.RangesScoped nr ↔ t.Support (rangeCondition nr) := by
    cases t with
    | done r e => exact and_congr (Ty.rangesScoped_iff_support r hw.1) (Eff.rangesScoped_iff_support e hw.2.1)
    | param n a t => exact and_congr (Ty.rangesScoped_iff_support a hw.1) (Tel.rangesScoped_iff_support t hw.2)
end

def Ty.VarsIn (nr nt nv : Nat) (pe : Nat → Prop) (a : Ty) : Prop :=
  a.WF nr nt nv ∧ a.RowsIn pe ∧ a.RangesScoped nr

def Eff.VarsIn (nr nt nv : Nat) (pe : Nat → Prop) (e : Eff) : Prop :=
  e.WF nr nt nv ∧ e.RowsIn pe ∧ e.RangesScoped nr

def Tel.VarsIn (nr nt nv : Nat) (pe : Nat → Prop) (t : Tel) : Prop :=
  t.WF nr nt nv ∧ t.RowsIn pe ∧ t.RangesScoped nr

def Ty.VarsInList (nr nt nv : Nat) (pe : Nat → Prop) (as : List Ty) : Prop :=
  ∀ a ∈ as, a.VarsIn nr nt nv pe

theorem Ty.VarsInList.iff {nr nt nv : Nat} {pe : Nat → Prop} {as : List Ty} :
    Ty.VarsInList nr nt nv pe as ↔ ∀ a ∈ as, a.VarsIn nr nt nv pe := Iff.rfl

theorem Ty.VarsIn.wf {nr nt nv : Nat} {pe : Nat → Prop} (a : Ty)
    (h : a.VarsIn nr nt nv pe) : a.WF nr nt nv := h.1

theorem Ty.VarsIn.rows {nr nt nv : Nat} {pe : Nat → Prop} (a : Ty)
    (h : a.VarsIn nr nt nv pe) : a.RowsIn pe := h.2.1

theorem Ty.VarsIn.mono {nr nt nv mt mv : Nat} {pe pf : Nat → Prop}
    (ht : nt ≤ mt) (hv : nv ≤ mv) (hp : ∀ i, pe i → pf i) (a : Ty)
    (h : a.VarsIn nr nt nv pe) : a.VarsIn nr mt mv pf :=
  ⟨Ty.WF.weaken h.1 ht hv, Ty.RowsIn.mono hp a h.2.1, h.2.2⟩

theorem Ty.norm_VarsIn {nr nt nv : Nat} {pe : Nat → Prop} (a : Ty)
    (h : a.VarsIn nr nt nv pe) : (Ty.norm a).VarsIn nr nt nv pe :=
  ⟨Ty.wf_norm h.1, Ty.norm_rowsIn a h.2.1,
    (Ty.rangesScoped_iff_support _ (Ty.wf_norm h.1)).mpr
      (Ty.norm_support a ((Ty.rangesScoped_iff_support a h.1).mp h.2.2))⟩

theorem Eff.VarsIn.wf {nr nt nv : Nat} {pe : Nat → Prop} (e : Eff)
    (h : e.VarsIn nr nt nv pe) : e.WF nr nt nv := h.1

theorem Eff.VarsIn.rows {nr nt nv : Nat} {pe : Nat → Prop} (e : Eff)
    (h : e.VarsIn nr nt nv pe) : e.RowsIn pe := h.2.1

theorem Eff.VarsIn.mono {nr nt nv mt mv : Nat} {pe pf : Nat → Prop}
    (ht : nt ≤ mt) (hv : nv ≤ mv) (hp : ∀ i, pe i → pf i) (e : Eff)
    (h : e.VarsIn nr nt nv pe) : e.VarsIn nr mt mv pf :=
  ⟨Eff.WF.weaken h.1 ht hv, Eff.RowsIn.mono hp e h.2.1, h.2.2⟩

theorem Eff.norm_VarsIn {nr nt nv : Nat} {pe : Nat → Prop} (e : Eff)
    (h : e.VarsIn nr nt nv pe) : (Eff.norm e).VarsIn nr nt nv pe :=
  ⟨Eff.wf_norm h.1, Eff.norm_rowsIn e h.2.1,
    (Eff.rangesScoped_iff_support _ (Eff.wf_norm h.1)).mpr
      (Eff.norm_support e ((Eff.rangesScoped_iff_support e h.1).mp h.2.2))⟩

theorem Tel.VarsIn.wf {nr nt nv : Nat} {pe : Nat → Prop} (t : Tel)
    (h : t.VarsIn nr nt nv pe) : t.WF nr nt nv := h.1

theorem Tel.VarsIn.rows {nr nt nv : Nat} {pe : Nat → Prop} (t : Tel)
    (h : t.VarsIn nr nt nv pe) : t.RowsIn pe := h.2.1

theorem Tel.VarsIn.mono {nr nt nv mt mv : Nat} {pe pf : Nat → Prop}
    (ht : nt ≤ mt) (hv : nv ≤ mv) (hp : ∀ i, pe i → pf i) (t : Tel)
    (h : t.VarsIn nr nt nv pe) : t.VarsIn nr mt mv pf :=
  ⟨Tel.WF.weaken h.1 ht hv, Tel.RowsIn.mono hp t h.2.1, h.2.2⟩

theorem Tel.norm_VarsIn {nr nt nv : Nat} {pe : Nat → Prop} (t : Tel)
    (h : t.VarsIn nr nt nv pe) : (Tel.norm t).VarsIn nr nt nv pe :=
  ⟨Tel.wf_norm h.1, Tel.norm_rowsIn t h.2.1,
    (Tel.rangesScoped_iff_support _ (Tel.wf_norm h.1)).mpr
      (Tel.norm_support t ((Tel.rangesScoped_iff_support t h.1).mp h.2.2))⟩

theorem Ty.VarsInList.wf {nr nt nv : Nat} {pe : Nat → Prop} (as : List Ty)
    (h : Ty.VarsInList nr nt nv pe as) : Ty.WFList nr nt nv as :=
  Ty.wfList_iff.mpr (fun a ha => (h a ha).1)

theorem Ty.VarsInList.rows {nr nt nv : Nat} {pe : Nat → Prop} (as : List Ty)
    (h : Ty.VarsInList nr nt nv pe as) : Ty.RowsInList pe as :=
  Ty.RowsInList.iff.mpr (fun a ha => (h a ha).2.1)

theorem Ty.VarsInList.mono {nr nt nv mt mv : Nat} {pe pf : Nat → Prop}
    (ht : nt ≤ mt) (hv : nv ≤ mv) (hp : ∀ i, pe i → pf i) (as : List Ty)
    (h : Ty.VarsInList nr nt nv pe as) : Ty.VarsInList nr mt mv pf as :=
  fun a ha => Ty.VarsIn.mono ht hv hp a (h a ha)

/-- 既存の有限上限の入口と同じ条件である。 -/
theorem Ty.varsIn_iff_sourceScoped (nr nt ne nv : Nat) (a : Ty) :
    a.VarsIn nr nt nv (· < ne) ↔ a.SourceScoped nr nt ne nv := Iff.rfl

theorem Eff.varsIn_iff_sourceScoped (nr nt ne nv : Nat) (e : Eff) :
    e.VarsIn nr nt nv (· < ne) ↔ e.SourceScoped nr nt ne nv := Iff.rfl

end Benitoite.Release.Refinement
