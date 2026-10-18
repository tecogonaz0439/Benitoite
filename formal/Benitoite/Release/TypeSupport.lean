import Benitoite.Release.TypeComposition

/-!
# 型と効果の再帰的な支持

Fail内部の型と潜在効果まで、現れる名前と行を同じ述語で制限する。
正規化・移動・同時代入で支持を保つ（設計書 07-04「01-12 との対応」）。
-/
namespace Benitoite.Release

mutual
  def Ty.Support (p : Atom → Prop) : Ty → Prop
    | .data _ ts | .tapp _ ts => Ty.SupportList p ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t => t.Support p
    | .fn _ ps r e => Ty.SupportList p ps ∧ r.Support p ∧ Eff.Support p e
    | .cont a b e => a.Support p ∧ b.Support p ∧ Eff.Support p e
    | .map a b => a.Support p ∧ b.Support p
    | _ => True
  def Ty.SupportList (p : Atom → Prop) : List Ty → Prop
    | [] => True
    | t :: ts => t.Support p ∧ Ty.SupportList p ts
  def Eff.Support (p : Atom → Prop) : Eff → Prop
    | .mk a fs => (∀ x, a x = true → p x) ∧ Ty.SupportList p fs
end

theorem Ty.SupportList.iff {p ts} : Ty.SupportList p ts ↔ ∀ t ∈ ts, t.Support p := by
  induction ts with
  | nil => simp [Ty.SupportList]
  | cons t ts ih => simp [Ty.SupportList, ih]

mutual
  theorem Ty.norm_support {p} (t : Ty) (h : t.Support p) : t.norm.Support p := by
    cases t <;> simp only [Ty.norm, Ty.Support] at h ⊢
    all_goals first
      | trivial
      | exact Ty.norm_support _ h
      | exact Ty.normTys_support _ h
      | skip
    case fn ns ps r e => exact ⟨Ty.normTys_support ps h.1, Ty.norm_support r h.2.1,
      Eff.norm_support e h.2.2⟩
    case cont a b e => exact ⟨Ty.norm_support a h.1, Ty.norm_support b h.2.1,
      Eff.norm_support e h.2.2⟩
    case map a b => exact ⟨Ty.norm_support a h.1, Ty.norm_support b h.2⟩
  theorem Ty.normTys_support {p} (ts : List Ty) (h : Ty.SupportList p ts) :
      Ty.SupportList p (Ty.normTys ts) := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.norm_support t h.1, Ty.normTys_support ts h.2⟩
  theorem Eff.norm_support {p} (e : Eff) (h : Eff.Support p e) : Eff.Support p (Eff.norm e) := by
    cases e with
    | mk a fs =>
      refine ⟨h.1, Ty.SupportList.iff.mpr ?_⟩
      intro t ht
      exact Ty.SupportList.iff.mp (Ty.normTys_support fs h.2) t (Order.mem_sortUnique.mp ht)
end

mutual
  theorem Ty.rawShift_support {p} (k c : Nat) (t : Ty) (h : t.Support p) :
      (t.rawShift k c).Support p := by
    cases t <;> simp only [Ty.Support] at h <;> simp only [Ty.rawShift, Ty.Support]
    all_goals first
      | trivial
      | exact Ty.rawShift_support k c _ h
      | exact Ty.rawShiftTys_support k c _ h
      | skip
    case fn ns ps r e => exact ⟨Ty.rawShiftTys_support k c ps h.1,
      Ty.rawShift_support k c r h.2.1, Eff.rawShift_support k c e h.2.2⟩
    case cont a b e => exact ⟨Ty.rawShift_support k c a h.1,
      Ty.rawShift_support k c b h.2.1, Eff.rawShift_support k c e h.2.2⟩
    case map a b => exact ⟨Ty.rawShift_support k c a h.1, Ty.rawShift_support k c b h.2⟩
  theorem Ty.rawShiftTys_support {p} (k c : Nat) (ts : List Ty) (h : Ty.SupportList p ts) :
      Ty.SupportList p (Ty.rawShiftTys k c ts) := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.rawShift_support k c t h.1, Ty.rawShiftTys_support k c ts h.2⟩
  theorem Eff.rawShift_support {p} (k c : Nat) (e : Eff) (h : Eff.Support p e) :
      Eff.Support p (Eff.rawShift k c e) := by
    cases e with
    | mk a fs => exact ⟨h.1, Ty.rawShiftTys_support k c fs h.2⟩
end

theorem Ty.shift_support {p} (k c : Nat) (t : Ty) (h : t.Support p) : (t.shift k c).Support p := by
  rw [Ty.shift_eq_norm_rawShift]
  exact Ty.norm_support _ (Ty.rawShift_support k c t h)

theorem Eff.shift_support {p} (k c : Nat) (e : Eff) (h : Eff.Support p e) :
    Eff.Support p (Eff.shift k c e) := Eff.norm_support _ (Eff.rawShift_support k c e h)

theorem TyCon.rawApply_support {p} (c : TyCon) (ts : List Ty) (h : Ty.SupportList p ts) :
    (c.rawApply ts).Support p := by
  cases c <;> cases ts <;> simp_all [TyCon.rawApply, Ty.Support, Ty.SupportList]
  all_goals (rename_i ts; cases ts <;> simp_all [Ty.Support, Ty.SupportList])

theorem Ty.rawApplyTo_support {p} (t : Ty) (ts : List Ty) (h : t.Support p)
    (hs : Ty.SupportList p ts) : (t.rawApplyTo ts).Support p := by
  cases t <;> try exact h
  · exact hs
  · exact TyCon.rawApply_support _ ts hs

mutual
  theorem Ty.rawBind_support {p} (θ : SubstEnv) (ht : ∀ i, (θ.types i).Support p)
      (he : ∀ e ∈ θ.rows, Eff.Support p e) (t : Ty) (h : t.Support p) :
      (t.rawBind θ).Support p := by
    cases t <;> simp only [Ty.Support] at h <;> simp only [Ty.rawBind, Ty.Support]
    all_goals first
      | trivial
      | exact Ty.rawBind_support θ ht he _ h
      | exact Ty.rawBindTys_support θ ht he _ h
      | skip
    case tvar i => exact ht i
    case fn ns ps r e => exact ⟨Ty.rawBindTys_support θ ht he ps h.1,
      Ty.rawBind_support θ ht he r h.2.1, Eff.rawBind_support θ ht he e h.2.2⟩
    case cont a b e => exact ⟨Ty.rawBind_support θ ht he a h.1,
      Ty.rawBind_support θ ht he b h.2.1, Eff.rawBind_support θ ht he e h.2.2⟩
    case map a b => exact ⟨Ty.rawBind_support θ ht he a h.1, Ty.rawBind_support θ ht he b h.2⟩
    case tapp i ts =>
      exact Ty.rawApplyTo_support (θ.types i) _ (ht i)
        (Ty.rawBindTys_support θ ht he ts h)
  theorem Ty.rawBindTys_support {p} (θ : SubstEnv) (ht : ∀ i, (θ.types i).Support p)
      (he : ∀ e ∈ θ.rows, Eff.Support p e) (ts : List Ty) (h : Ty.SupportList p ts) :
      Ty.SupportList p (Ty.rawBindTys θ ts) := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.rawBind_support θ ht he t h.1, Ty.rawBindTys_support θ ht he ts h.2⟩
  theorem Eff.rawBind_support {p} (θ : SubstEnv) (ht : ∀ i, (θ.types i).Support p)
      (he : ∀ e ∈ θ.rows, Eff.Support p e) (e : Eff) (h : Eff.Support p e) :
      Eff.Support p (Eff.rawBind θ e) := by
    cases e with
    | mk a fs =>
      constructor
      · intro x hx
        have hx' : Eff.substAtoms θ.rows (Eff.atoms (.mk a fs)) x = true := hx
        rw [Eff.mem_substAtoms] at hx'
        rcases hx' with hx | ⟨i, f, hi, _, hx⟩
        · cases x with
          | name _ => exact h.1 _ hx
          | rho _ => exact h.1 _ hx.2
        · cases f with
          | mk b gs => exact (he (.mk b gs) (List.mem_of_getElem? hi)).1 _ hx
      · apply Ty.SupportList.iff.mpr
        intro t hm
        rcases List.mem_append.mp hm with hm | hm
        · exact Ty.SupportList.iff.mp (Ty.rawBindTys_support θ ht he fs h.2) t hm
        · obtain ⟨i, f, hi, _, hm⟩ := Eff.mem_rowFails.mp hm
          cases f with
          | mk b gs => exact Ty.SupportList.iff.mp (he (.mk b gs) (List.mem_of_getElem? hi)).2 t hm
end

theorem SubstEnv.at_support {p c ts es} (ht : ∀ t ∈ ts, t.Support p)
    (he : ∀ e ∈ es, Eff.Support p e) :
    (∀ i, ((SubstEnv.at c ts es).types i).Support p) ∧
      (∀ e ∈ (SubstEnv.at c ts es).rows, Eff.Support p e) := by
  constructor
  · intro i
    simp only [SubstEnv.at]
    split
    · trivial
    · split
      · apply Ty.rawShift_support
        cases hi : ts[i - c]? with
        | none => trivial
        | some t => exact ht t (List.mem_of_getElem? hi)
      · trivial
  · intro e hm
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp hm
    exact Eff.rawShift_support c 0 f (he f hf)

theorem Ty.substAt_support {p} (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ t ∈ ts, t.Support p) (he : ∀ e ∈ es, Eff.Support p e) (t : Ty) (h : t.Support p) :
    (t.substAt c ts es).Support p := by
  rw [Ty.substAt_eq_rawBind]
  have hh := SubstEnv.at_support (c := c) ht he
  exact Ty.norm_support _ (Ty.rawBind_support _ hh.1 hh.2 t h)

theorem Eff.substAt_support {p} (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ t ∈ ts, t.Support p) (he : ∀ e ∈ es, Eff.Support p e) (e : Eff) (h : Eff.Support p e) :
    Eff.Support p (Eff.substAt c ts es e) := by
  have hh := SubstEnv.at_support (c := c) ht he
  exact Eff.norm_support _ (Eff.rawBind_support _ hh.1 hh.2 e h)

end Benitoite.Release
