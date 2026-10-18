import Benitoite.Release.Lemmas.Closed
import Benitoite.Release.Lemmas.Rename
import Benitoite.Release.Assumptions
import Benitoite.Release.Semantics
import Benitoite.Release.Lemmas.FailureBase

/-!
# 継続の型付けの補題（契約名を持つコア）

契約名を含む型のまま補題を示す（設計書 01-12「型付け規則」）。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-! ## ストアの型付けの拡大 -/

theorem ContTy.store {Ψ Ψ' R ε k a b ε0 Re} (h : ContTy P B Ψ R ε k a b ε0 Re)
    (hΨ : StoreTy.Sub Ψ Ψ') : ContTy P B Ψ' R ε k a b ε0 Re := by
  induction h with
  | K_Empty hs hw => exact .K_Empty hs hw
  | K_Let hn hw hs _ ih => exact .K_Let (hn.store hΨ) hw hs ih
  | K_Mark _ hw ih => exact .K_Mark ih hw
  | K_Update hl _ ih => exact .K_Update (hΨ _ _ hl) ih
  | K_Release hv hr hs _ ih => exact .K_Release (hv.store hΨ) hr hs ih
  | K_Handle _ hs hc hw ih => exact .K_Handle ih hs (hc.store hΨ) hw
  | K_Handle_Fail _ hr hn hc he hw ih => exact .K_Handle_Fail ih hr hn (hc.store hΨ) he hw
  | K_Drop hl hs _ ih => exact .K_Drop (hΨ _ _ hl) hs ih
  | K_Guard hm hs hp hb _ ih => exact .K_Guard (hm.store hΨ) hs hp (hb.store hΨ) ih
  | K_Sub _ hle ih => exact .K_Sub ih hle

/-! ## エフェクトの名前が継続の末尾まで届くこと -/

/-- 継続の先頭で許すエフェクトの名前 l は、l を処理する `handle` の枠がなければ、継続の末尾でも許される。 -/
theorem ContTy.name_end {Ψ R ε k a b ε0 Re l} (h : ContTy P B Ψ R ε k a b ε0 Re)
    (hl : Eff.mem ε (.name l)) (hno : ∀ hs, Frame.handleF hs ∈ k → Eff.test (handled P B hs) (.name l) = false) :
    Eff.mem ε0 (.name l) := by
  induction h with
  | K_Empty hs _ => exact hs.1 _ hl
  | K_Let _ _ _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | K_Mark _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | K_Update _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | K_Release _ _ _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | @K_Handle R ε εc hs k t b ε0 Re _ hsub _ _ ih =>
      have hh := hno hs (by simp)
      rw [Eff.mem_union] at hl
      have hl' := hl.resolve_right (fun hm => by
        change Eff.test (handled P B hs) (.name l) = true at hm
        rw [hh] at hm
        cases hm)
      exact ih (hsub.1 _ hl') (fun hs' hm => hno hs' (by simp [hm]))
  | K_Handle_Fail _ hr _ _ _ _ ih =>
      have ha : Eff.mem _ (.name l) := (Eff.mem_union _ _ _).mp hl |>.resolve_left (by
        simp [Eff.mem, Eff.test, Eff.singleFail, Eff.atoms])
      exact ih (hr.1 _ ha) (fun hs hm => hno hs (by simp [hm]))
  | K_Drop _ _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | K_Guard => simp [Eff.mem, Eff.test, Eff.atoms, Eff.empty] at hl
  | K_Sub _ _ ih => exact ih hl hno

/-- `State` はどの `handled(H)` にも含まれない。 -/
theorem handled_state (hdecl : P.EffectsOk B) (hb : B.Assumptions P) (hs : List Clause) :
    Eff.test (handled P B hs) (.name stateEff) = false := by
  simp only [Eff.test, Eff.atoms, Eff.ofAtoms, handled, effOps]
  have hp : P.effects stateEff = none := by
    cases h : P.effects stateEff with
    | none => rfl
    | some os =>
        have := hdecl.2.2 _ _ h
        rw [hb.state_effect] at this; cases this
  rw [hp, hb.state_effect]
  rfl

theorem ContTy.state_end (hdecl : P.EffectsOk B) (hb : B.Assumptions P) {Ψ R ε k a b ε0 Re}
    (h : ContTy P B Ψ R ε k a b ε0 Re) (hs : Eff.mem ε (.name stateEff)) : Eff.mem ε0 (.name stateEff) :=
  h.name_end hs (fun hs _ => handled_state hdecl hb hs)

/-! ## 逆転 -/

theorem ContTy.inv_nil {Ψ R ε a b ε0 Re} (h : ContTy P B Ψ R ε [] a b ε0 Re) :
    Ty.Le a b ∧ Eff.Sub ε ε0 ∧ R = Re ∧ Ty.WF 0 b := by
  generalize hk : ([] : Cont) = k at h
  induction h with
  | K_Empty hs hw => exact ⟨Ty.Le.refl _, hs, rfl, hw⟩
  | K_Sub _ hle ih => obtain ⟨h1, h2, h3, h4⟩ := ih hk; exact ⟨hle.trans h1, h2, h3, h4⟩
  | _ => cases hk

theorem ContTy.inv_let {Ψ R ε n k a b ε0 Re} (h : ContTy P B Ψ R ε (.letF n :: k) a b ε0 Re) :
    ∃ a' c ε1, Ty.Le a a' ∧ HasTypeC P B Ψ [] [some a'] R n c ε1 ∧ Eff.Sub ε1 ε ∧
      ContTy P B Ψ R ε k c b ε0 Re ∧ Ty.WF 0 a' := by
  generalize hk : (Frame.letF n :: k) = k0 at h
  induction h with
  | K_Let hn hw hs hrest _ => cases hk; exact ⟨_, _, _, Ty.Le.refl _, hn, hs, hrest, hw⟩
  | K_Sub _ hle ih =>
      obtain ⟨a', c, ε1, h1, h2, h3, h4, hw⟩ := ih hk
      exact ⟨a', c, ε1, hle.trans h1, h2, h3, h4, hw⟩
  | _ => cases hk

theorem ContTy.inv_mark {Ψ R ε k a b ε0 Re} (h : ContTy P B Ψ R ε (.mark :: k) a b ε0 Re) :
    ∃ a' R', Ty.Le a a' ∧ R = some a' ∧ ContTy P B Ψ R' ε k a' b ε0 Re ∧ Ty.WF 0 a' := by
  generalize hk : (Frame.mark :: k) = k0 at h
  induction h with
  | K_Mark hrest hw _ => cases hk; exact ⟨_, _, Ty.Le.refl _, rfl, hrest, hw⟩
  | K_Sub _ hle ih =>
      obtain ⟨a', R', h1, h2, h3, h4⟩ := ih hk
      exact ⟨a', R', hle.trans h1, h2, h3, h4⟩
  | _ => cases hk

theorem ContTy.inv_update {Ψ R ε l k a b ε0 Re} (h : ContTy P B Ψ R ε (.update l :: k) a b ε0 Re) :
    ∃ a' R', Ty.Le a a' ∧ R = none ∧ Ψ l = some (.lazy a') ∧ ContTy P B Ψ R' ε k a' b ε0 Re := by
  generalize hk : (Frame.update l :: k) = k0 at h
  induction h with
  | K_Update hl hrest _ => cases hk; exact ⟨_, _, Ty.Le.refl _, rfl, hl, hrest⟩
  | K_Sub _ hle ih =>
      obtain ⟨a', R', h1, h2, h3, h4⟩ := ih hk
      exact ⟨a', R', hle.trans h1, h2, h3, h4⟩
  | _ => cases hk

theorem ContTy.inv_release {Ψ R ε v k a b ε0 Re}
    (h : ContTy P B Ψ R ε (.release v :: k) a b ε0 Re) :
    ∃ o, HasTypeV P B Ψ [] [] v (.opaque o) ∧ B.isResource o = true ∧ Eff.mem ε (.name stateEff) ∧
      ContTy P B Ψ R ε k a b ε0 Re := by
  generalize hk : (Frame.release v :: k) = k0 at h
  induction h with
  | K_Release hv hr hs hrest _ => cases hk; exact ⟨_, hv, hr, hs, hrest⟩
  | K_Sub _ hle ih =>
      obtain ⟨o, h1, h2, h3, h4⟩ := ih hk
      exact ⟨o, h1, h2, h3, .K_Sub h4 hle⟩
  | _ => cases hk

theorem ContTy.inv_handle {Ψ R ε hs k a b ε0 Re}
    (h : ContTy P B Ψ R ε (.handleF hs :: k) a b ε0 Re) (ho : handles hs .fail = false) :
    ∃ t εb εc, Ty.Le a t ∧ ε = Eff.union εc (handled P B hs) ∧ ContTy P B Ψ R εb k t b ε0 Re ∧
      Eff.Sub εc εb ∧ HasTypeClauses P B Ψ [] [] R hs t εc ∧ Ty.WF 0 t := by
  generalize hk : (Frame.handleF hs :: k) = k0 at h
  induction h with
  | K_Handle hrest hsub hc hw _ => cases hk; exact ⟨_, _, _, Ty.Le.refl _, rfl, hrest, hsub, hc, hw⟩
  | K_Handle_Fail _ _ _ hc _ _ _ =>
      cases hk
      rw [hc.handles] at ho
      cases ho
  | K_Sub _ hle ih =>
      obtain ⟨t, εb, εc, h1, h2, h3, h4, h5, h6⟩ := ih hk
      exact ⟨t, εb, εc, hle.trans h1, h2, h3, h4, h5, h6⟩
  | _ => cases hk

/-- handle の種類によらず、値・escape・停止を外側へ返すための反転。 -/
theorem ContTy.inv_handle_tail {Ψ R ε hs k a b ε0 Re}
    (h : ContTy P B Ψ R ε (.handleF hs :: k) a b ε0 Re) :
    ∃ t εb, Ty.Le a t ∧ ContTy P B Ψ R εb k t b ε0 Re ∧ Ty.WF 0 t := by
  generalize hk : (Frame.handleF hs :: k) = k0 at h
  induction h with
  | K_Handle ht _ _ hw _ | K_Handle_Fail ht _ _ _ _ hw _ =>
      cases hk
      exact ⟨_, _, Ty.Le.refl _, ht, hw⟩
  | K_Sub _ hl ih =>
      obtain ⟨t, e, hl', ht, hw⟩ := ih hk
      exact ⟨t, e, hl.trans hl', ht, hw⟩
  | _ => cases hk

theorem ContTy.inv_drop {Ψ R ε κ k a b ε0 Re} (h : ContTy P B Ψ R ε (.drop κ :: k) a b ε0 Re) :
    ∃ b' t' ε' R', Ψ κ = some (.cont b' t' ε' R') ∧
      (Eff.mem ε' (.name stateEff) → Eff.mem ε (.name stateEff)) ∧ ContTy P B Ψ R ε k a b ε0 Re := by
  generalize hk : (Frame.drop κ :: k) = k0 at h
  induction h with
  | K_Drop hl hs hrest _ => cases hk; exact ⟨_, _, _, _, hl, hs, hrest⟩
  | K_Sub _ hle ih =>
      obtain ⟨b', t', ε', R', h1, h2, h3⟩ := ih hk
      exact ⟨b', t', ε', R', h1, h2, .K_Sub h3 hle⟩
  | _ => cases hk

/-- ガードの枠の逆転。入力の R とエフェクトは、元の計算のものとは別である。 -/
theorem ContTy.inv_guard {Ψ R ε v arms next body k a b ε0 Re}
    (h : ContTy P B Ψ R ε (.guardF v arms next body :: k) a b ε0 Re) :
    ∃ R' ε' ε1 c, R = none ∧ ε = Eff.empty ∧ Ty.Le a (.base .boolean) ∧
      HasTypeC P B Ψ [] [] R' (.match v arms) c ε1 ∧ Eff.Sub ε1 ε' ∧
      MatchPrefix v arms next ∧ HasTypeC P B Ψ [] [] R' body c ε1 ∧
      ContTy P B Ψ R' ε' k c b ε0 Re := by
  generalize hk : (Frame.guardF v arms next body :: k) = k0 at h
  induction h with
  | K_Guard hm hs hp hb ht _ =>
      cases hk
      exact ⟨_, _, _, _, rfl, rfl, Ty.Le.refl _, hm, hs, hp, hb, ht⟩
  | K_Sub _ hle ih =>
      obtain ⟨R', ε', ε1, c, hr, he, hle', hm, hs, hp, hb, ht⟩ := ih hk
      exact ⟨R', ε', ε1, c, hr, he, hle.trans hle', hm, hs, hp, hb, ht⟩
  | _ => cases hk

/-! ## E-Resume：捕まえた継続を今の継続につなぐ -/

/-- 継続が `handle` の枠で終わる。 -/
theorem EndsWithHandle.tail {f : Frame} {k : Cont} (h : EndsWithHandle (f :: k)) (hk : k ≠ []) :
    EndsWithHandle k := by
  obtain ⟨k1, hs, e⟩ := h
  cases k1 with
  | nil => simp at e; exact absurd e.2 hk
  | cons g k1 => simp at e; exact ⟨k1, hs, e.2⟩

theorem EndsWithHandle.tail' {f : Frame} {k : Cont} (h : EndsWithHandle (f :: k))
    (hf : ∀ hs, f ≠ .handleF hs) : EndsWithHandle k := by
  obtain ⟨k1, hs, e⟩ := h
  cases k1 with
  | nil => simp at e; exact absurd e.1 (hf hs)
  | cons g k1 => simp at e; exact ⟨k1, hs, e.2⟩

theorem ContTy.resume_append {Ψ R ε k' b t εκ Rκ} (hcell : ContTy P B Ψ R ε k' b t εκ Rκ)
    (hend : EndsWithHandle k') {k t' c E Re ε2} (hle : Ty.Le t t')
    (hk : ContTy P B Ψ Rκ ε2 k t' c E Re) (hsub : Eff.Sub εκ ε2) :
    ContTy P B Ψ R ε (k' ++ k) b c E Re := by
  induction hcell generalizing t' with
  | K_Empty _ _ => obtain ⟨k1, hs, e⟩ := hend; simp at e
  | K_Let hn hw hs hrest ih => exact .K_Let hn hw hs (ih (hend.tail' (by intro _ h; cases h)) hle hk hsub)
  | K_Mark hrest hw ih => exact .K_Mark (ih (hend.tail' (by intro _ h; cases h)) hle hk hsub) hw
  | K_Update hl hrest ih => exact .K_Update hl (ih (hend.tail' (by intro _ h; cases h)) hle hk hsub)
  | K_Release hv hr hs hrest ih => exact .K_Release hv hr hs (ih (hend.tail' (by intro _ h; cases h)) hle hk hsub)
  | @K_Handle R' ε' εc hs k0 t0 b0 ε0' Re' hrest hsc hc hw ih =>
      by_cases hn' : k0 = []
      · subst hn'
        obtain ⟨hle0, hs0, hR, _⟩ := hrest.inv_nil
        subst hR
        simp only [List.cons_append, List.nil_append]
        exact .K_Handle (.K_Sub hk (hle0.trans hle)) (hsc.trans (hs0.trans hsub)) hc hw
      · exact .K_Handle (ih (hend.tail hn') hle hk hsub) hsc hc hw
  | @K_Handle_Fail R' ε' ec Rest E hs k0 t0 b0 ε0' Re' hrest hr hn hc he hw ih =>
      by_cases hn' : k0 = []
      · subst hn'
        obtain ⟨hle0, hs0, hR, _⟩ := hrest.inv_nil
        subst hR
        simp only [List.cons_append, List.nil_append]
        exact .K_Handle_Fail (.K_Sub hk (hle0.trans hle)) (hr.trans (hs0.trans hsub)) hn hc
          (he.trans (hs0.trans hsub)) hw
      · exact .K_Handle_Fail (ih (hend.tail hn') hle hk hsub) hr hn hc he hw
  | K_Drop hl hs hrest ih => exact .K_Drop hl hs (ih (hend.tail' (by intro _ h; cases h)) hle hk hsub)
  | K_Guard hm hs hp hb _ ih =>
      exact .K_Guard hm hs hp hb (ih (hend.tail' (by intro _ h; cases h)) hle hk hsub)
  | K_Sub _ hle' ih => exact .K_Sub (ih hend hle hk hsub) hle'

/-! ## E-Op：継続を `handle` の枠で分ける -/

theorem ContTy.split {Ψ R ε a b E Re hs k2 k1}
    (h : ContTy P B Ψ R ε (k1 ++ .handleF hs :: k2) a b E Re)
    (ho : handles hs .fail = false) :
    ∃ t εb εc Rh, ContTy P B Ψ R ε (k1 ++ [.handleF hs]) a t εc Rh ∧ ContTy P B Ψ Rh εb k2 t b E Re ∧
      Eff.Sub εc εb ∧ HasTypeClauses P B Ψ [] [] Rh hs t εc ∧ Ty.WF 0 t := by
  generalize heq : (k1 ++ Frame.handleF hs :: k2) = k0 at h
  induction h generalizing k1 with
  | K_Empty _ _ => cases k1 <;> simp at heq
  | K_Sub _ hle ih =>
      obtain ⟨t, εb, εc, Rh, h1, h2, h3, h4, h5⟩ := ih heq
      exact ⟨t, εb, εc, Rh, .K_Sub h1 hle, h2, h3, h4, h5⟩
  | K_Let hn hw hsub _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εb, εc, Rh, h1, h2, h3, h4, h5⟩ := ih heq
          exact ⟨t, εb, εc, Rh, .K_Let hn hw hsub h1, h2, h3, h4, h5⟩
  | K_Mark _ hw ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εb, εc, Rh, h1, h2, h3, h4, h5⟩ := ih heq
          exact ⟨t, εb, εc, Rh, .K_Mark h1 hw, h2, h3, h4, h5⟩
  | K_Update hl _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εb, εc, Rh, h1, h2, h3, h4, h5⟩ := ih heq
          exact ⟨t, εb, εc, Rh, .K_Update hl h1, h2, h3, h4, h5⟩
  | K_Release hv hr hst _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εb, εc, Rh, h1, h2, h3, h4, h5⟩ := ih heq
          exact ⟨t, εb, εc, Rh, .K_Release hv hr hst h1, h2, h3, h4, h5⟩
  | K_Drop hl hsub _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εb, εc, Rh, h1, h2, h3, h4, h5⟩ := ih heq
          exact ⟨t, εb, εc, Rh, .K_Drop hl hsub h1, h2, h3, h4, h5⟩
  | K_Guard hm hsub hp hb _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εb, εc, Rh, h1, h2, h3, h4, h5⟩ := ih heq
          exact ⟨t, εb, εc, Rh, .K_Guard hm hsub hp hb h1, h2, h3, h4, h5⟩
  | K_Handle ht hsub hc hw ih =>
      cases k1 with
      | nil =>
          simp only [List.nil_append, List.cons.injEq, Frame.handleF.injEq] at heq
          obtain ⟨rfl, rfl⟩ := heq
          exact ⟨_, _, _, _, .K_Handle (.K_Empty (Eff.Sub.refl _) hw) (Eff.Sub.refl _) hc hw,
            ht, hsub, hc, hw⟩
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εb, εc, Rh, h1, h2, h3, h4, h5⟩ := ih heq
          exact ⟨t, εb, εc, Rh, .K_Handle h1 hsub hc hw, h2, h3, h4, h5⟩
  | K_Handle_Fail ht hr hn hc he hw ih =>
      cases k1 with
      | nil =>
          simp only [List.nil_append, List.cons.injEq, Frame.handleF.injEq] at heq
          obtain ⟨rfl, rfl⟩ := heq
          rw [hc.handles] at ho
          cases ho
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εb, εc, Rh, h1, h2, h3, h4, h5⟩ := ih heq
          exact ⟨t, εb, εc, Rh, .K_Handle_Fail h1 hr hn hc he hw, h2, h3, h4, h5⟩

/-! ## `releases(K')` の型付け -/

/-- 継続の中の解放の枠と `drop` の枠が、末尾のエフェクト ε0 のもとで満たす性質。 -/
def FramesOk (P : Program) (B : Builtins) (Ψ : StoreTy) (ε0 : Eff) (k : Cont) : Prop :=
  ∀ f ∈ k, match f with
    | .release v => (∃ o, HasTypeV P B Ψ [] [] v (.opaque o) ∧ B.isResource o = true) ∧
        Eff.mem ε0 (.name stateEff)
    | .drop κ => ∃ b t e r, Ψ κ = some (.cont b t e r) ∧
        (Eff.mem e (.name stateEff) → Eff.mem ε0 (.name stateEff))
    | _ => True

theorem ContTy.framesOk (hdecl : P.EffectsOk B) (hb : B.Assumptions P) {Ψ R ε k a b ε0 Re}
    (h : ContTy P B Ψ R ε k a b ε0 Re) : FramesOk P B Ψ ε0 k := by
  induction h with
  | K_Empty _ _ => intro f hf; simp at hf
  | K_Let _ _ _ _ ih =>
      intro f hf; rcases List.mem_cons.mp hf with rfl | hf
      · trivial
      · exact ih f hf
  | K_Mark _ _ ih =>
      intro f hf; rcases List.mem_cons.mp hf with rfl | hf
      · trivial
      · exact ih f hf
  | K_Update _ _ ih =>
      intro f hf; rcases List.mem_cons.mp hf with rfl | hf
      · trivial
      · exact ih f hf
  | K_Release hv hr hs hrest ih =>
      intro f hf; rcases List.mem_cons.mp hf with rfl | hf
      · exact ⟨⟨_, hv, hr⟩, hrest.state_end hdecl hb hs⟩
      · exact ih f hf
  | K_Handle _ _ _ _ ih | K_Handle_Fail _ _ _ _ _ _ ih =>
      intro f hf; rcases List.mem_cons.mp hf with rfl | hf
      · trivial
      · exact ih f hf
  | K_Drop hl hs hrest ih =>
      intro f hf; rcases List.mem_cons.mp hf with rfl | hf
      · exact ⟨_, _, _, _, hl, fun h' => hrest.state_end hdecl hb (hs h')⟩
      · exact ih f hf
  | K_Guard _ _ _ _ _ ih =>
      intro f hf; rcases List.mem_cons.mp hf with rfl | hf
      · trivial
      · exact ih f hf
  | K_Sub _ _ ih => exact ih

theorem releases_sub (k : Cont) : ∀ f ∈ releases k, f ∈ k ∧ ((∃ v, f = .release v) ∨ ∃ κ, f = .drop κ) := by
  induction k with
  | nil => simp [releases]
  | cons g k ih =>
      intro f hf
      cases g with
      | release v =>
          simp only [releases, List.mem_cons] at hf
          rcases hf with rfl | hf
          · exact ⟨by simp, Or.inl ⟨v, rfl⟩⟩
          · obtain ⟨h1, h2⟩ := ih f hf; exact ⟨by simp [h1], h2⟩
      | drop κ =>
          simp only [releases, List.mem_cons] at hf
          rcases hf with rfl | hf
          · exact ⟨by simp, Or.inr ⟨κ, rfl⟩⟩
          · obtain ⟨h1, h2⟩ := ih f hf; exact ⟨by simp [h1], h2⟩
      | _ =>
          simp only [releases] at hf
          obtain ⟨h1, h2⟩ := ih f hf; exact ⟨by simp [h1], h2⟩

/-- 解放の枠と `drop` の枠だけからなる継続を、今の継続の上に積んでも型が付く。 -/
theorem ContTy.prepend_releases {Ψ R ε k a b ε0 Re} (hk : ContTy P B Ψ R ε k a b ε0 Re) :
    ∀ (l : Cont), (∀ f ∈ l, match f with
      | .release v => (∃ o, HasTypeV P B Ψ [] [] v (.opaque o) ∧ B.isResource o = true) ∧
          Eff.mem ε (.name stateEff)
      | .drop κ => ∃ b t e r, Ψ κ = some (.cont b t e r) ∧
          (Eff.mem e (.name stateEff) → Eff.mem ε (.name stateEff))
      | _ => False) →
    ContTy P B Ψ R ε (l ++ k) a b ε0 Re
  | [], _ => hk
  | f :: l, hl => by
      have hrest := ContTy.prepend_releases hk l (fun g hg => hl g (by simp [hg]))
      have hf := hl f (by simp)
      cases f with
      | release v =>
          obtain ⟨⟨o, hv, hr⟩, hs⟩ := hf
          exact .K_Release hv hr hs hrest
      | drop κ =>
          obtain ⟨b', t', e', r', hΨ, hs⟩ := hf
          exact .K_Drop hΨ hs hrest
      | _ => exact hf.elim

/-- E-DropRel などで、捨てる継続の `releases(K')` を `drop κ` の枠の位置に加えても型が付く。 -/
theorem ContTy.drop_releases (hdecl : P.EffectsOk B) (hb : B.Assumptions P)
    {Ψ R ε k a b ε0 Re b' t' e' r' R'' ε'' k'}
    (hk : ContTy P B Ψ R ε k a b ε0 Re) (hcond : Eff.mem e' (.name stateEff) → Eff.mem ε (.name stateEff))
    (hcell : ContTy P B Ψ R'' ε'' k' b' t' e' r') :
    ContTy P B Ψ R ε (releases k' ++ k) a b ε0 Re := by
  have hfr := hcell.framesOk hdecl hb
  refine hk.prepend_releases (releases k') ?_
  intro f hf
  obtain ⟨hmem, hkind⟩ := releases_sub k' f hf
  have := hfr f hmem
  rcases hkind with ⟨v, rfl⟩ | ⟨κ, rfl⟩
  · exact ⟨this.1, hcond this.2⟩
  · obtain ⟨b, t, e, r, hΨ, hs⟩ := this
    exact ⟨b, t, e, r, hΨ, fun h => hcond (hs h)⟩

end Benitoite.Release
