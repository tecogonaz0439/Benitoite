import Benitoite.Release.Lemmas.SubstTyping

/-!
# 型とエフェクトの置き換えで型付けが保たれること（段階 B）

E-Fun は定義の本体に、E-Op は節の本体に、閉じた型引数の置き換えを施す。置き換える型パラメータの
並び `C0` は、置き換える位置の内側で束縛された型パラメータの並び `C1` の外側にある。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-! ## 型の置き換えの性質 -/

/-- 型が継続の型でないこと。 -/
def Ty.NotCont (x : Ty) : Prop := ∀ b t ε, x ≠ .cont b t ε

/-- 置き換える型の並びが、項の中に書ける閉じた型である。 -/
def ClosedArgs (ts : List Ty) : Prop := ∀ t ∈ ts, Ty.WF 0 t ∧ Ty.NotCont t

theorem Ty.applyTo_notCont {t : Ty} (ht : t.NotCont) (as : List Ty) : (t.applyTo as).NotCont := by
  cases t with
  | ctor φ => cases φ <;> (intro b t ε h; simp [Ty.applyTo, TyCon.apply] at h)
  | tvar j => intro b t ε h; simp [Ty.applyTo] at h
  | _ => simpa [Ty.applyTo] using ht

theorem Ty.shift_notCont {t : Ty} (ht : t.NotCont) (k c : Nat) : (t.shift k c).NotCont := by
  cases t with
  | cont b t ε => exact absurd rfl (ht b t ε)
  | tvar i => intro b t ε h; simp [Ty.shift] at h; split at h <;> cases h
  | tapp i as => intro b t ε h; simp [Ty.shift] at h
  | _ => intro b t ε h; simp [Ty.shift] at h

theorem Ty.substAt_notCont {c ts es} (hts : ClosedArgs ts) {x : Ty} (hx : x.NotCont) :
    (x.substAt c ts es).NotCont := by
  cases x with
  | cont b t ε => exact absurd rfl (hx b t ε)
  | tvar i =>
      simp only [Ty.substAt]
      split
      · intro b t ε h; cases h
      · split
        · rename_i _ h2
          have hmem := List.getElem_mem h2
          simp only [List.getElem?_eq_getElem h2, Option.getD_some]
          rw [Ty.shift_of_wf _ _ (Ty.WF.mono (Nat.zero_le _) _ (hts _ hmem).1)]
          exact (hts _ hmem).2
        · intro b t ε h; cases h
  | tapp i as =>
      simp only [Ty.substAt]
      split
      · intro b t ε h; cases h
      · split
        · rename_i _ h2
          have hmem := List.getElem_mem h2
          simp only [List.getElem?_eq_getElem h2, Option.getD_some]
          exact Ty.applyTo_notCont (Ty.shift_notCont (hts _ hmem).2 _ _) _
        · intro b t ε h; cases h
  | _ => intro b t ε h; simp [Ty.substAt] at h

/-- 環境の要素一つを隠す関数（`hideConts` の中身）。 -/
def hideOne : Option Ty → Option Ty
  | some (.cont _ _ _) => none
  | x => x

theorem hideConts_eq (Γ : List (Option Ty)) : hideConts Γ = Γ.map hideOne := by
  simp only [hideConts]
  congr 1

theorem hideOne_notCont {x : Ty} (hx : x.NotCont) : hideOne (some x) = some x := by
  cases x with
  | cont b t ε => exact absurd rfl (hx b t ε)
  | _ => rfl

theorem hideConts_map {c ts es} (hts : ClosedArgs ts) (Γ : List (Option Ty)) :
    hideConts (Γ.map (Option.map (Ty.substAt c ts es))) =
      (hideConts Γ).map (Option.map (Ty.substAt c ts es)) := by
  rw [hideConts_eq, hideConts_eq]
  simp only [List.map_map]
  congr 1
  funext o
  cases o with
  | none => rfl
  | some x =>
      simp only [Function.comp, Option.map_some]
      cases x with
      | cont b t ε => simp [Ty.substAt, hideOne]
      | tvar i =>
          have hnc : (Ty.tvar i).NotCont := by intro b t ε h; cases h
          rw [hideOne_notCont (Ty.substAt_notCont hts hnc), hideOne_notCont hnc]; rfl
      | tapp i as =>
          have hnc : (Ty.tapp i as).NotCont := by intro b t ε h; cases h
          rw [hideOne_notCont (Ty.substAt_notCont hts hnc), hideOne_notCont hnc]; rfl
      | _ => simp [Ty.substAt, hideOne]

theorem binds_map (f : Ty → Ty) (as : List Ty) :
    binds (as.map f) = (binds as).map (Option.map f) := by
  simp [binds, List.map_reverse, List.map_map]

theorem shiftEnv_substAt {c k ts es} (hts : ClosedArgs ts) (Γ : List (Option Ty)) :
    (shiftEnv k Γ).map (Option.map (Ty.substAt (c + k) ts es)) =
      shiftEnv k (Γ.map (Option.map (Ty.substAt c ts es))) := by
  simp only [shiftEnv, List.map_map]
  congr 1
  funext o
  cases o with
  | none => rfl
  | some x =>
      simp only [Function.comp, Option.map_some]
      rw [Ty.shift_substAt es (fun t ht => (hts t ht).1)]

theorem Eff.substRho_union (es : List Eff) (ε ε' : Eff) :
    Eff.substRho es (Eff.union ε ε') = Eff.union (Eff.substRho es ε) (Eff.substRho es ε') := by
  funext a
  apply Bool.eq_iff_iff.mpr
  have hu : ∀ (e1 e2 : Eff) x, Eff.union e1 e2 x = true ↔ e1 x = true ∨ e2 x = true := by
    intro e1 e2 x; simp [Eff.union]
  rw [hu, Eff.substRho_true, Eff.substRho_true, Eff.substRho_true]
  cases a with
  | name l =>
      simp only [hu]
      constructor
      · rintro ((h | h) | ⟨i, e, he, hi | hi, hea⟩)
        · exact Or.inl (Or.inl h)
        · exact Or.inr (Or.inl h)
        · exact Or.inl (Or.inr ⟨i, e, he, hi, hea⟩)
        · exact Or.inr (Or.inr ⟨i, e, he, hi, hea⟩)
      · rintro ((h | ⟨i, e, he, hi, hea⟩) | (h | ⟨i, e, he, hi, hea⟩))
        · exact Or.inl (Or.inl h)
        · exact Or.inr ⟨i, e, he, Or.inl hi, hea⟩
        · exact Or.inl (Or.inr h)
        · exact Or.inr ⟨i, e, he, Or.inr hi, hea⟩
  | rho k =>
      simp only [hu]
      constructor
      · rintro (⟨hk, h | h⟩ | ⟨i, e, he, hi | hi, hea⟩)
        · exact Or.inl (Or.inl ⟨hk, h⟩)
        · exact Or.inr (Or.inl ⟨hk, h⟩)
        · exact Or.inl (Or.inr ⟨i, e, he, hi, hea⟩)
        · exact Or.inr (Or.inr ⟨i, e, he, hi, hea⟩)
      · rintro ((⟨hk, h⟩ | ⟨i, e, he, hi, hea⟩) | (⟨hk, h⟩ | ⟨i, e, he, hi, hea⟩))
        · exact Or.inl ⟨hk, Or.inl h⟩
        · exact Or.inr ⟨i, e, he, Or.inl hi, hea⟩
        · exact Or.inl ⟨hk, Or.inr h⟩
        · exact Or.inr ⟨i, e, he, Or.inr hi, hea⟩

/-- `handled(H)` はエフェクト変数を含まないので、エフェクト変数の置き換えで変わらない。 -/
theorem handled_substRho (es : List Eff) (h : List Clause) :
    Eff.substRho es (handled P B h) = handled P B h := by
  funext a
  apply Bool.eq_iff_iff.mpr
  rw [Eff.substRho_true]
  cases a with
  | name l =>
      simp only
      constructor
      · rintro (h' | ⟨i, e, _, hi, _⟩)
        · exact h'
        · simp [handled] at hi
      · intro h'; exact Or.inl h'
  | rho k =>
      simp only [handled]
      simp

/-! ## 変数の範囲の単調性 -/

theorem Eff.RhosIn.mono {pe pe' : Nat → Prop} (hpe : ∀ i, pe i → pe' i) {ε : Eff}
    (h : Eff.RhosIn pe ε) : Eff.RhosIn pe' ε := fun i hi => hpe i (h i hi)

mutual
  theorem Ty.VarsIn.mono {n n' : Nat} {pe pe' : Nat → Prop} (hn : n ≤ n') (hpe : ∀ i, pe i → pe' i) :
      (a : Ty) → Ty.VarsIn n pe a → Ty.VarsIn n' pe' a
    | .base _, _ => trivial
    | .opaque _, _ => trivial
    | .data _ args, h => by simp only [Ty.VarsIn] at h ⊢; exact Ty.VarsInList.mono hn hpe args h
    | .list a, h => by simp only [Ty.VarsIn] at h ⊢; exact Ty.VarsIn.mono hn hpe a h
    | .fn ps r ε, h => by
        simp only [Ty.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono hn hpe ps h.1, Ty.VarsIn.mono hn hpe r h.2.1, Eff.RhosIn.mono hpe h.2.2⟩
    | .tvar i, h => by simp only [Ty.VarsIn] at h ⊢; omega
    | .reference a, h => by simp only [Ty.VarsIn] at h ⊢; exact Ty.VarsIn.mono hn hpe a h
    | .lazy a, h => by simp only [Ty.VarsIn] at h ⊢; exact Ty.VarsIn.mono hn hpe a h
    | .cont _ _ _, h => by simp only [Ty.VarsIn] at h
    | .map a b, h => by
        simp only [Ty.VarsIn] at h ⊢; exact ⟨Ty.VarsIn.mono hn hpe a h.1, Ty.VarsIn.mono hn hpe b h.2⟩
    | .set a, h => by simp only [Ty.VarsIn] at h ⊢; exact Ty.VarsIn.mono hn hpe a h
    | .bytes, _ => by simp [Ty.VarsIn]
    | .dict _ τ, h => by simp only [Ty.VarsIn] at h ⊢; exact Ty.VarsIn.mono hn hpe τ h
    | .tapp i args, h => by
        simp only [Ty.VarsIn] at h ⊢; exact ⟨by omega, Ty.VarsInList.mono hn hpe args h.2⟩
    | .ctor _, _ => by simp [Ty.VarsIn]

  theorem Ty.VarsInList.mono {n n' : Nat} {pe pe' : Nat → Prop} (hn : n ≤ n') (hpe : ∀ i, pe i → pe' i) :
      (as : List Ty) → Ty.VarsInList n pe as → Ty.VarsInList n' pe' as
    | [], _ => trivial
    | a :: as, h => by
        simp only [Ty.VarsInList] at h ⊢
        exact ⟨Ty.VarsIn.mono hn hpe a h.1, Ty.VarsInList.mono hn hpe as h.2⟩
end

/-! ## 閉じた型を保つストア -/

/-- ストアの型付けの型が、置き換えで変わらない。 -/
def StoreFix (Ψ : StoreTy) (ts : List Ty) (es : List Eff) : Prop :=
  ∀ (c l : Nat),
    (∀ a, Ψ l = some (.ref a) → a.substAt c ts es = a) ∧
    (∀ a, Ψ l = some (.lazy a) → a.substAt c ts es = a) ∧
    (∀ b t ε r, Ψ l = some (.cont b t ε r) →
      b.substAt c ts es = b ∧ t.substAt c ts es = t ∧ Eff.substRho es ε = ε ∧
      r.map (Ty.substAt c ts es) = r)

theorem StoreFix.empty (ts : List Ty) (es : List Eff) : StoreFix StoreTy.empty ts es := by
  intro c l; simp [StoreTy.empty]

theorem Eff.substRho_nil (ε : Eff) : Eff.substRho [] ε = ε := by
  funext a; cases a <;> simp [Eff.substRho]

mutual
  theorem Ty.substAt_nil_of_wf {c : Nat} (ts : List Ty) : (a : Ty) → Ty.WF c a → a.substAt c ts [] = a
    | .base _, _ => by simp [Ty.substAt]
    | .opaque _, _ => by simp [Ty.substAt]
    | .data d args, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt]; rw [Ty.substAtList_nil_of_wf ts args w]
    | .list a, w => by simp only [Ty.WF] at w; simp only [Ty.substAt]; rw [Ty.substAt_nil_of_wf ts a w]
    | .fn ps r e, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt]
        rw [Ty.substAtList_nil_of_wf ts ps w.1, Ty.substAt_nil_of_wf ts r w.2, Eff.substRho_nil]
    | .tvar i, w => by simp only [Ty.WF] at w; simp [Ty.substAt, w]
    | .reference a, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt]; rw [Ty.substAt_nil_of_wf ts a w]
    | .lazy a, w => by simp only [Ty.WF] at w; simp only [Ty.substAt]; rw [Ty.substAt_nil_of_wf ts a w]
    | .cont b t e, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt]
        rw [Ty.substAt_nil_of_wf ts b w.1, Ty.substAt_nil_of_wf ts t w.2, Eff.substRho_nil]
    | .map a b, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt]
        rw [Ty.substAt_nil_of_wf ts a w.1, Ty.substAt_nil_of_wf ts b w.2]
    | .set a, w => by simp only [Ty.WF] at w; simp only [Ty.substAt]; rw [Ty.substAt_nil_of_wf ts a w]
    | .bytes, _ => by simp [Ty.substAt]
    | .dict _ τ, w => by simp only [Ty.WF] at w; simp only [Ty.substAt]; rw [Ty.substAt_nil_of_wf ts τ w]
    | .tapp i args, w => by
        simp only [Ty.WF] at w; simp only [Ty.substAt, w.1, ↓reduceIte]
        rw [Ty.substAtList_nil_of_wf ts args w.2]
    | .ctor _, _ => by simp [Ty.substAt]

  theorem Ty.substAtList_nil_of_wf {c : Nat} (ts : List Ty) :
      (as : List Ty) → Ty.WFList c as → as.map (Ty.substAt c ts []) = as
    | [], _ => rfl
    | a :: as, w => by
        simp only [Ty.WFList] at w
        simp only [List.map_cons]; rw [Ty.substAt_nil_of_wf ts a w.1, Ty.substAtList_nil_of_wf ts as w.2]
end

theorem StoreFix.of_wf {Ψ : StoreTy} (hΨ : StoreTy.WF Ψ) (ts : List Ty) : StoreFix Ψ ts [] := by
  intro c l
  refine ⟨fun a h => ?_, fun a h => ?_, fun b t ε r h => ?_⟩
  · exact Ty.substAt_nil_of_wf ts a (Ty.WF.mono (Nat.zero_le _) _ (hΨ _ _ h))
  · exact Ty.substAt_nil_of_wf ts a (Ty.WF.mono (Nat.zero_le _) _ (hΨ _ _ h))
  · have w := hΨ _ _ h
    simp only [LocTy.WF] at w
    refine ⟨Ty.substAt_nil_of_wf ts b (Ty.WF.mono (Nat.zero_le _) _ w.1),
      Ty.substAt_nil_of_wf ts t (Ty.WF.mono (Nat.zero_le _) _ w.2.1), Eff.substRho_nil ε, ?_⟩
    cases r with
    | none => rfl
    | some x =>
        simp only [Option.map_some]
        rw [Ty.substAt_nil_of_wf ts x (Ty.WF.mono (Nat.zero_le _) _ (w.2.2 x rfl))]

end Benitoite.Release
