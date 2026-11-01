import Benitoite.Release.Refinement.TypeSupport
import Benitoite.Release.Refinement.Admissible

/-! Fail・篩・依存列内部の行変数の条件。範囲添字のWFとは区別する。
設計書01-12「コア計算と脱糖」の支持を使う。 -/
namespace Benitoite.Release.Refinement

/-- 行変数だけに条件を課し、名前の原子は制限しない。 -/
def rowCondition (pe : Nat → Prop) : Atom → Prop
  | .rho i => pe i
  | .name _ _ => True

mutual
  theorem Ty.rowsIn_iff_support (pe : Nat → Prop) (a : Ty) :
      a.RowsIn pe ↔ a.Support (rowCondition pe) := by
    cases a <;> simp only [Ty.RowsIn, Ty.Support, Ty.rowsIn_iff_support,
      Ty.rowsInList_iff_support, Eff.rowsIn_iff_support, Tel.rowsIn_iff_support]
  theorem Ty.rowsInList_iff_support (pe : Nat → Prop) (as : List Ty) :
      Ty.RowsInList pe as ↔ Ty.SupportList (rowCondition pe) as := by
    cases as <;> simp only [Ty.RowsInList, Ty.SupportList, Ty.rowsIn_iff_support, Ty.rowsInList_iff_support]
  theorem Eff.rowsIn_iff_support (pe : Nat → Prop) (e : Eff) :
      e.RowsIn pe ↔ e.Support (rowCondition pe) := by
    cases e with
    | mk atoms fs =>
      simp only [Eff.RowsIn, Eff.Support, Ty.rowsInList_iff_support]
      apply and_congr_left
      intro _
      constructor
      · intro h a ha
        cases a with
        | name => trivial
        | rho i => exact h i ha
      · intro h i hi; exact h (.rho i) hi
  theorem Tel.rowsIn_iff_support (pe : Nat → Prop) (t : Tel) :
      t.RowsIn pe ↔ t.Support (rowCondition pe) := by
    cases t <;> simp only [Tel.RowsIn, Tel.Support, Ty.rowsIn_iff_support,
      Eff.rowsIn_iff_support, Tel.rowsIn_iff_support]
end

theorem Ty.RowsInList.iff {pe : Nat → Prop} {as : List Ty} :
    Ty.RowsInList pe as ↔ ∀ a ∈ as, a.RowsIn pe := by
  simp only [Ty.rowsInList_iff_support, Ty.SupportList.iff, Ty.rowsIn_iff_support]

theorem Ty.RowsIn.mono {pe pf : Nat → Prop} (hp : ∀ i, pe i → pf i)
    (a : Ty) (h : a.RowsIn pe) : a.RowsIn pf := by
  rw [Ty.rowsIn_iff_support] at h ⊢
  exact Ty.support_mono a h (fun a ha => by cases a with | name => trivial | rho i => exact hp i ha)

theorem Ty.norm_rowsIn {pe : Nat → Prop} (a : Ty) (h : a.RowsIn pe) :
    (Ty.norm a).RowsIn pe := by
  rw [Ty.rowsIn_iff_support] at h ⊢
  exact Ty.norm_support a h

theorem Eff.RowsIn.mono {pe pf : Nat → Prop} (hp : ∀ i, pe i → pf i)
    (e : Eff) (h : e.RowsIn pe) : e.RowsIn pf := by
  rw [Eff.rowsIn_iff_support] at h ⊢
  exact Eff.support_mono e h (fun a ha => by cases a with | name => trivial | rho i => exact hp i ha)

theorem Eff.norm_rowsIn {pe : Nat → Prop} (e : Eff) (h : e.RowsIn pe) :
    (Eff.norm e).RowsIn pe := by
  rw [Eff.rowsIn_iff_support] at h ⊢
  exact Eff.norm_support e h

theorem Tel.RowsIn.mono {pe pf : Nat → Prop} (hp : ∀ i, pe i → pf i)
    (t : Tel) (h : t.RowsIn pe) : t.RowsIn pf := by
  rw [Tel.rowsIn_iff_support] at h ⊢
  exact Tel.support_mono t h (fun a ha => by cases a with | name => trivial | rho i => exact hp i ha)

theorem Tel.norm_rowsIn {pe : Nat → Prop} (t : Tel) (h : t.RowsIn pe) :
    (Tel.norm t).RowsIn pe := by
  rw [Tel.rowsIn_iff_support] at h ⊢
  exact Tel.norm_support t h

theorem Ty.RowsInList.mono {pe pf : Nat → Prop} (hp : ∀ i, pe i → pf i)
    (as : List Ty) (h : Ty.RowsInList pe as) : Ty.RowsInList pf as := by
  rw [Ty.RowsInList.iff] at h ⊢
  exact fun a ha => Ty.RowsIn.mono hp a (h a ha)

theorem Ty.normTys_rowsIn {pe : Nat → Prop} (as : List Ty) (h : Ty.RowsInList pe as) :
    Ty.RowsInList pe (Ty.normTys as) := by
  rw [Ty.rowsInList_iff_support] at h ⊢
  exact Ty.normTys_support as h

mutual
  theorem Ty.rowsIn_true (a : Ty) : a.RowsIn (fun _ => True) := by
    cases a <;> simp only [Ty.RowsIn]
    all_goals first | trivial | exact Ty.rowsIn_true _ | exact Ty.rowsInList_true _ |
      exact Tel.rowsIn_true _ | skip
    case fn ns ps r e => exact ⟨Ty.rowsInList_true ps, Ty.rowsIn_true r, Eff.rowsIn_true e⟩
    case cont a b e => exact ⟨Ty.rowsIn_true a, Ty.rowsIn_true b, Eff.rowsIn_true e⟩
    case map a b => exact ⟨Ty.rowsIn_true a, Ty.rowsIn_true b⟩
  theorem Ty.rowsInList_true (as : List Ty) : Ty.RowsInList (fun _ => True) as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.rowsIn_true a, Ty.rowsInList_true as⟩
  theorem Eff.rowsIn_true (e : Eff) : e.RowsIn (fun _ => True) := by
    cases e; exact ⟨fun _ _ => trivial, Ty.rowsInList_true _⟩
  theorem Tel.rowsIn_true (t : Tel) : t.RowsIn (fun _ => True) := by
    cases t with
    | done r e => exact ⟨Ty.rowsIn_true r, Eff.rowsIn_true e⟩
    | param n a t => exact ⟨Ty.rowsIn_true a, Tel.rowsIn_true t⟩
end

end Benitoite.Release.Refinement
