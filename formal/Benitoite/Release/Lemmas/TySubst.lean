import Benitoite.Release.Lemmas.SubstTyping

/-!
# 型とエフェクトの置き換えで型付けが保たれること（契約名を持つコア）

E-Fun は定義の本体に、E-Op は節の本体に、閉じた型引数の置き換えを施す。置き換える型パラメータの
並び `C0` は、置き換える位置の内側で束縛された型パラメータの並び `C1` の外側にある。

型・エフェクトの置換は契約名を変更せず、閉じた型の性質を保持する
（設計書 01-12「型付け規則」）。
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
  | ctor φ => cases φ <;> (intro b t ε h; simp [Ty.applyTo, TyCon.apply, TyCon.rawApply] at h)
  | tvar j => intro b t ε h; simp [Ty.applyTo] at h
  | cont a b e => exact (ht a b e rfl).elim
  | _ => intro b t ε h; simp [Ty.applyTo, Ty.norm] at h

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
  | _ => intro b t ε h; simp [Ty.substAt, Eff.substAt] at h

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
      | cont b t ε => simp [Ty.substAt, Eff.substAt, hideOne]
      | tvar i =>
          have hnc : (Ty.tvar i).NotCont := by intro b t ε h; cases h
          rw [hideOne_notCont (Ty.substAt_notCont hts hnc), hideOne_notCont hnc]; rfl
      | tapp i as =>
          have hnc : (Ty.tapp i as).NotCont := by intro b t ε h; cases h
          rw [hideOne_notCont (Ty.substAt_notCont hts hnc), hideOne_notCont hnc]; rfl
      | _ => simp [Ty.substAt, Eff.substAt, hideOne]

theorem binds_map (f : Ty → Ty) (as : List Ty) :
    binds (as.map f) = (binds as).map (Option.map f) := by
  simp [binds, List.map_reverse, List.map_map]

theorem shiftEnv_substAt {c k ts es} (hts : ClosedArgs ts) (hes : ∀ e ∈ es, Eff.WF 0 e) (Γ : List (Option Ty)) :
    (shiftEnv k Γ).map (Option.map (Ty.substAt (c + k) ts es)) =
      shiftEnv k (Γ.map (Option.map (Ty.substAt c ts es))) := by
  simp only [shiftEnv, List.map_map]
  congr 1
  funext o
  cases o with
  | none => rfl
  | some x =>
      simp only [Function.comp, Option.map_some]
      rw [Ty.shift_substAt es (fun t ht => (hts t ht).1) hes]

/-- `handled(H)` はエフェクト変数を含まないので、エフェクト変数の置き換えで変わらない。 -/
theorem handled_substRho (es : List Eff) (h : List Clause) :
    Eff.substRho es (handled P B h) = handled P B h := by
  apply Eff.ext
  · intro a
    rw [Eff.substRho_true]
    cases a with
    | name l =>
      simp only
      constructor
      · rintro (h' | ⟨i, e, _, hi, _⟩)
        · exact h'
        · simp [Eff.mem, Eff.test, Eff.atoms, Eff.ofAtoms, handled] at hi
      · intro h'; exact Or.inl h'
    | rho k => simp [Eff.mem, Eff.test, Eff.atoms, Eff.ofAtoms, handled]
  · change (Eff.substAt 0 [] es (handled P B h)).fails = (handled P B h).fails
    rw [Eff.substAt_fails]
    have hempty : Eff.rowFails (es.map (Eff.rawShift 0 0)) (handled P B h).atoms = [] := by
      unfold Eff.rowFails
      have hf : List.filter (fun i => (handled P B h).atoms (.rho i))
          (List.range (es.map (Eff.rawShift 0 0)).length) = [] := by
        apply List.filter_eq_nil_iff.mpr
        simp [handled, Eff.atoms, Eff.ofAtoms]
      rw [hf]
      rfl
    rw [hempty]
    rfl

theorem handled_substAt (c : Nat) (ts : List Ty) (es : List Eff) (h : List Clause) :
    Eff.substAt c ts es (handled P B h) = handled P B h :=
  Eff.bind_ofAtoms_noRhos (SubstEnv.at c ts es) _ (fun _ => rfl)

/-! ## 閉じた型を保つストア -/

/-- ストアの型付けの型が、置き換えで変わらない。 -/
def StoreFix (Ψ : StoreTy) (ts : List Ty) (es : List Eff) : Prop :=
  ∀ (c l : Nat),
    (∀ a, Ψ l = some (.ref a) → a.substAt c ts es = a) ∧
    (∀ a, Ψ l = some (.lazy a) → a.substAt c ts es = a) ∧
    (∀ b t ε r, Ψ l = some (.cont b t ε r) →
      b.substAt c ts es = b ∧ t.substAt c ts es = t ∧ Eff.substAt c ts es ε = ε ∧
      r.map (Ty.substAt c ts es) = r)

theorem StoreFix.empty (ts : List Ty) (es : List Eff) : StoreFix StoreTy.empty ts es := by
  intro c l; simp [StoreTy.empty]

theorem StoreFix.of_wf {Ψ : StoreTy} (hΨ : StoreTy.WF Ψ) (ts : List Ty) : StoreFix Ψ ts [] := by
  intro c l
  refine ⟨fun a h => ?_, fun a h => ?_, fun b t ε r h => ?_⟩
  · exact Ty.substAt_nil_of_wf ts a (Ty.WF.mono (Nat.zero_le _) _ (hΨ _ _ h))
  · exact Ty.substAt_nil_of_wf ts a (Ty.WF.mono (Nat.zero_le _) _ (hΨ _ _ h))
  · have w := hΨ _ _ h
    simp only [LocTy.WF] at w
    refine ⟨Ty.substAt_nil_of_wf ts b (Ty.WF.mono (Nat.zero_le _) _ w.1),
      Ty.substAt_nil_of_wf ts t (Ty.WF.mono (Nat.zero_le _) _ w.2.1), Eff.substAt_nil_of_wf ts ε (Eff.WF.mono (Nat.zero_le _) ε w.2.2.2.1) w.2.2.2.2, ?_⟩
    cases r with
    | none => rfl
    | some x =>
        simp only [Option.map_some]
        rw [Ty.substAt_nil_of_wf ts x (Ty.WF.mono (Nat.zero_le _) _ (w.2.2.1 x rfl))]

end Benitoite.Release
