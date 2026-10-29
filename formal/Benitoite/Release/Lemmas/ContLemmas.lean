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
  | K_Handle _ hs hb hc hw ih => exact .K_Handle ih hs hb (hc.store (hideBuilders_mono hΨ)) hw
  | K_Handle_Fail _ hr hn hc he hw ih => exact .K_Handle_Fail ih hr hn (hc.store (hideBuilders_mono hΨ)) he hw
  | K_Drop hl hs _ ih => exact .K_Drop (hΨ _ _ hl) hs ih
  | K_Guard hm hs hp hb _ ih => exact .K_Guard (hm.store hΨ) hs hp (hb.store hΨ) ih
  | K_Sub _ hle ih => exact .K_Sub ih hle

/-! ## エフェクトの名前が継続の末尾まで届くこと -/

/-- 継続の先頭で許すエフェクトの名前 l は、l を処理する `handle` の枠がなければ、継続の末尾でも許される。 -/
theorem ContTy.name_end {Ψ R ε k a b ε0 Re l} (h : ContTy P B Ψ R ε k a b ε0 Re)
    (hl : Eff.mem ε (.nameTop l)) (hno : ∀ hs, Frame.handleF hs ∈ k → Eff.test (handled P B hs) (.nameTop l) = false) :
    Eff.mem ε0 (.nameTop l) := by
  induction h with
  | K_Empty hs _ => exact hs.1 _ hl
  | K_Let _ _ _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | K_Mark _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | K_Update _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | K_Release _ _ _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | @K_Handle R ε εc εb hs k t b ε0 Re _ hsub hbh _ _ ih =>
      have hh := hno hs (by simp)
      have hl := hbh.1 _ hl
      rw [Eff.mem_union] at hl
      have hl' := hl.resolve_right (fun hm => by
        change Eff.test (handled P B hs) (.nameTop l) = true at hm
        rw [hh] at hm
        cases hm)
      exact ih (hsub.nameTop hl') (fun hs' hm => hno hs' (by simp [hm]))
  | K_Handle_Fail _ hr _ _ _ _ ih =>
      have ha : Eff.mem _ (.nameTop l) := (Eff.mem_union _ _ _).mp hl |>.resolve_left (by
        simp [Eff.mem, Eff.test, Eff.singleFail, Eff.atoms])
      exact ih (hr.nameTop ha) (fun hs hm => hno hs (by simp [hm]))
  | K_Drop _ _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | K_Guard => simp [Eff.mem, Eff.test, Eff.atoms, Eff.empty] at hl
  | K_Sub _ _ ih => exact ih hl hno

/-- `ContTy.name_end` の範囲付きの版。範囲の位置 r を持つ名前の原子 l は、l を処理する `handle` の枠が継続になければ、
継続の末尾に、それを覆う同じ名前の原子として届く（`handled` は範囲の位置を見ない。`handled_name`）。`handle` の枠の
節の効果は枠の下の継続の効果に被覆で含まれるので（K-Handle）、範囲の位置は枠を越えるたびに広がりうる（L40.6c）。 -/
theorem ContTy.name_end_ix {Ψ R ε k a b ε0 Re l r} (h : ContTy P B Ψ R ε k a b ε0 Re)
    (hl : Eff.mem ε (.name l r))
    (hno : ∀ hs, Frame.handleF hs ∈ k → Eff.test (handled P B hs) (.nameTop l) = false) :
    ∃ r', Eff.mem ε0 (.name l r') ∧ (Atom.name l r').Covers (.name l r) := by
  induction h generalizing r with
  | K_Empty hs _ => exact ⟨r, hs.1 _ hl, Atom.Covers.refl _⟩
  | K_Let _ _ _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | K_Mark _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | K_Update _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | K_Release _ _ _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | @K_Handle R ε εc εb hs k t b ε0 Re _ hsub hbh _ _ ih =>
      have hh := hno hs (by simp)
      have hl := hbh.1 _ hl
      rw [Eff.mem_union] at hl
      have hl' := hl.resolve_right (fun hm => by
        change Eff.test (handled P B hs) (.name l r) = true at hm
        rw [handled_name, hh] at hm
        cases hm)
      obtain ⟨c, hc, hcc⟩ := hsub.1 _ hl'
      obtain ⟨jx, rfl⟩ := hcc.name_right
      obtain ⟨r', h1, h2⟩ := ih hc (fun hs' hm => hno hs' (by simp [hm]))
      exact ⟨r', h1, h2.trans hcc⟩
  | K_Handle_Fail _ hr _ _ _ _ ih =>
      have ha : Eff.mem _ (.name l r) := (Eff.mem_union _ _ _).mp hl |>.resolve_left (by
        simp [Eff.mem, Eff.test, Eff.singleFail, Eff.atoms])
      obtain ⟨c, hc, hcc⟩ := hr.1 _ ha
      obtain ⟨jx, rfl⟩ := hcc.name_right
      obtain ⟨r', h1, h2⟩ := ih hc (fun hs hm => hno hs (by simp [hm]))
      exact ⟨r', h1, h2.trans hcc⟩
  | K_Drop _ _ _ ih => exact ih hl (fun hs hm => hno hs (by simp [hm]))
  | K_Guard => simp [Eff.mem, Eff.test, Eff.atoms, Eff.empty] at hl
  | K_Sub _ _ ih => exact ih hl hno

/-- 継続の型付けは、末尾の添字 ε0 を包含で大きくしても成り立つ。ε0 を読むのは `K_Empty` の `Eff.Sub ε ε0`
だけである（L20.1 の試行の補題）。 -/
theorem ContTy.mono_end {Ψ R ε k a b ε0 ε0' Re} (h : ContTy P B Ψ R ε k a b ε0 Re)
    (hs : Eff.Sub ε0 ε0') : ContTy P B Ψ R ε k a b ε0' Re := by
  induction h with
  | K_Empty h1 hw => exact .K_Empty (h1.trans hs) hw
  | K_Let hn hw h1 _ ih => exact .K_Let hn hw h1 (ih hs)
  | K_Mark _ hw ih => exact .K_Mark (ih hs) hw
  | K_Update hl _ ih => exact .K_Update hl (ih hs)
  | K_Release hv hr h1 _ ih => exact .K_Release hv hr h1 (ih hs)
  | K_Handle _ h1 hb hc hw ih => exact .K_Handle (ih hs) h1 hb hc hw
  | K_Handle_Fail _ hr hn hc he hw ih => exact .K_Handle_Fail (ih hs) hr hn hc he hw
  | K_Drop hl h1 _ ih => exact .K_Drop hl h1 (ih hs)
  | K_Guard hm h1 hp hb _ ih => exact .K_Guard hm h1 hp hb (ih hs)
  | K_Sub _ hle ih => exact .K_Sub (ih hs) hle

/-- `State` はどの `handled(H)` にも含まれない。 -/
theorem handled_state (hdecl : P.EffectsOk B) (hb : B.CoreAssumptions P) (hs : List Clause) :
    Eff.test (handled P B hs) (.nameTop stateEff) = false := by
  simp only [Eff.test, Eff.atoms, Eff.ofAtoms, handled, effOps]
  have hp : P.effects stateEff = none := by
    cases h : P.effects stateEff with
    | none => rfl
    | some os =>
        have := hdecl.2.2 _ _ h
        rw [hb.state_effect] at this; cases this
  rw [hp, hb.state_effect]
  rfl

theorem ContTy.state_end (hdecl : P.EffectsOk B) (hb : B.CoreAssumptions P) {Ψ R ε k a b ε0 Re}
    (h : ContTy P B Ψ R ε k a b ε0 Re) (hs : Eff.mem ε (.nameTop stateEff)) : Eff.mem ε0 (.nameTop stateEff) :=
  h.name_end hs (fun hs _ => handled_state hdecl hb hs)

/-! ## 逆転 -/

theorem ContTy.inv_nil {Ψ R ε a b ε0 Re} (h : ContTy P B Ψ R ε [] a b ε0 Re) :
    Ty.Le a b ∧ Eff.Sub ε ε0 ∧ R = Re ∧ Ty.WF 0 0 b := by
  generalize hk : ([] : Cont) = k at h
  induction h with
  | K_Empty hs hw => exact ⟨Ty.Le.refl _, hs, rfl, hw⟩
  | K_Sub _ hle ih => obtain ⟨h1, h2, h3, h4⟩ := ih hk; exact ⟨hle.trans h1, h2, h3, h4⟩
  | _ => cases hk

theorem ContTy.inv_let {Ψ R ε n k a b ε0 Re} (h : ContTy P B Ψ R ε (.letF n :: k) a b ε0 Re) :
    ∃ a' c ε1, Ty.Le a a' ∧ HasTypeC P B Ψ [] [some a'] R n c ε1 ∧ Eff.Sub ε1 ε ∧
      ContTy P B Ψ R ε k c b ε0 Re ∧ Ty.WF 0 0 a' := by
  generalize hk : (Frame.letF n :: k) = k0 at h
  induction h with
  | K_Let hn hw hs hrest _ => cases hk; exact ⟨_, _, _, Ty.Le.refl _, hn, hs, hrest, hw⟩
  | K_Sub _ hle ih =>
      obtain ⟨a', c, ε1, h1, h2, h3, h4, hw⟩ := ih hk
      exact ⟨a', c, ε1, hle.trans h1, h2, h3, h4, hw⟩
  | _ => cases hk

theorem ContTy.inv_mark {Ψ R ε k a b ε0 Re} (h : ContTy P B Ψ R ε (.mark :: k) a b ε0 Re) :
    ∃ a' R', Ty.Le a a' ∧ R = some a' ∧ ContTy P B Ψ R' ε k a' b ε0 Re ∧ Ty.WF 0 0 a' := by
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
    ∃ o, HasTypeV P B Ψ [] [] v (.opaqueTop o) ∧ B.isResource o = true ∧ Eff.mem ε (.nameTop stateEff) ∧
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
    ∃ t εb εc, Ty.Le a t ∧ Eff.Sub ε (Eff.union εc (handled P B hs)) ∧ ContTy P B Ψ R εb k t b ε0 Re ∧
      Eff.Covers εb εc ∧ HasTypeClauses P B Ψ [] [] R ε hs t εc ∧ Ty.WF 0 0 t := by
  generalize hk : (Frame.handleF hs :: k) = k0 at h
  induction h with
  | K_Handle hrest hsub hbh hc hw _ =>
      cases hk; exact ⟨_, _, _, Ty.Le.refl _, hbh, hrest, hsub, hc.store (hideBuilders_sub _), hw⟩
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
    ∃ t εb, Ty.Le a t ∧ ContTy P B Ψ R εb k t b ε0 Re ∧ Ty.WF 0 0 t := by
  generalize hk : (Frame.handleF hs :: k) = k0 at h
  induction h with
  | K_Handle ht _ _ _ hw _ | K_Handle_Fail ht _ _ _ _ hw _ =>
      cases hk
      exact ⟨_, _, Ty.Le.refl _, ht, hw⟩
  | K_Sub _ hl ih =>
      obtain ⟨t, e, hl', ht, hw⟩ := ih hk
      exact ⟨t, e, hl.trans hl', ht, hw⟩
  | _ => cases hk

theorem ContTy.inv_drop {Ψ R ε κ k a b ε0 Re} (h : ContTy P B Ψ R ε (.drop κ :: k) a b ε0 Re) :
    ∃ b' t' ε' R', Ψ κ = some (.cont b' t' ε' R') ∧
      (Eff.mem ε' (.nameTop stateEff) → Eff.mem ε (.nameTop stateEff)) ∧ ContTy P B Ψ R ε k a b ε0 Re := by
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
    (hk : ContTy P B Ψ Rκ ε2 k t' c E Re) (hsub : Eff.Covers ε2 εκ) :
    ContTy P B Ψ R ε (k' ++ k) b c E Re := by
  induction hcell generalizing t' with
  | K_Empty _ _ => obtain ⟨k1, hs, e⟩ := hend; simp at e
  | K_Let hn hw hs hrest ih => exact .K_Let hn hw hs (ih (hend.tail' (by intro _ h; cases h)) hle hk hsub)
  | K_Mark hrest hw ih => exact .K_Mark (ih (hend.tail' (by intro _ h; cases h)) hle hk hsub) hw
  | K_Update hl hrest ih => exact .K_Update hl (ih (hend.tail' (by intro _ h; cases h)) hle hk hsub)
  | K_Release hv hr hs hrest ih => exact .K_Release hv hr hs (ih (hend.tail' (by intro _ h; cases h)) hle hk hsub)
  | @K_Handle R' ε' εc εb hs k0 t0 b0 ε0' Re' hrest hsc hbh hc hw ih =>
      by_cases hn' : k0 = []
      · subst hn'
        obtain ⟨hle0, hs0, hR, _⟩ := hrest.inv_nil
        subst hR
        simp only [List.cons_append, List.nil_append]
        exact .K_Handle (.K_Sub hk (hle0.trans hle)) ((hsub.trans hs0.covers).trans hsc) hbh hc hw
      · exact .K_Handle (ih (hend.tail hn') hle hk hsub) hsc hbh hc hw
  | @K_Handle_Fail R' ε' ec Rest E hs k0 t0 b0 ε0' Re' hrest hr hn hc he hw ih =>
      by_cases hn' : k0 = []
      · subst hn'
        obtain ⟨hle0, hs0, hR, _⟩ := hrest.inv_nil
        subst hR
        simp only [List.cons_append, List.nil_append]
        exact .K_Handle_Fail (.K_Sub hk (hle0.trans hle)) ((hsub.trans hs0.covers).trans hr) hn hc
          ((hsub.trans hs0.covers).trans he) hw
      · exact .K_Handle_Fail (ih (hend.tail hn') hle hk hsub) hr hn hc he hw
  | K_Drop hl hs hrest ih => exact .K_Drop hl hs (ih (hend.tail' (by intro _ h; cases h)) hle hk hsub)
  | K_Guard hm hs hp hb _ ih =>
      exact .K_Guard hm hs hp hb (ih (hend.tail' (by intro _ h; cases h)) hle hk hsub)
  | K_Sub _ hle' ih => exact .K_Sub (ih hend hle hk hsub) hle'

/-! ## E-Op：継続を `handle` の枠で分ける -/

/-- 継続を、操作を処理する `handle` の枠で分ける。枠の穴の効果 εh（保護本体の効果。節の添字はここから選ぶ）は、
枠より内側の継続が処理しない名前の原子を、継続の先頭の効果 ε から、それを覆う同じ名前の原子として受け取る
（L30.1。内側の `handle` の枠を越えると範囲の位置は被覆で広がりうる。L40.6c）。 -/
theorem ContTy.split {Ψ R ε a b E Re hs k2 k1}
    (h : ContTy P B Ψ R ε (k1 ++ .handleF hs :: k2) a b E Re)
    (ho : handles hs .fail = false) :
    ∃ t εh εb εc Rh, ContTy P B Ψ R ε (k1 ++ [.handleF hs]) a t εc Rh ∧ ContTy P B Ψ Rh εb k2 t b E Re ∧
      Eff.Covers εb εc ∧ HasTypeClauses P B Ψ [] [] Rh εh hs t εc ∧ Ty.WF 0 0 t ∧
      ∀ l r, Eff.mem ε (.name l r) →
        (∀ hs', Frame.handleF hs' ∈ k1 → Eff.test (handled P B hs') (.nameTop l) = false) →
        ∃ r', Eff.mem εh (.name l r') ∧ (Atom.name l r').Covers (.name l r) := by
  generalize heq : (k1 ++ Frame.handleF hs :: k2) = k0 at h
  induction h generalizing k1 with
  | K_Empty _ _ => cases k1 <;> simp at heq
  | K_Sub _ hle ih =>
      obtain ⟨t, εh, εb, εc, Rh, h1, h2, h3, h4, h5, h6⟩ := ih heq
      exact ⟨t, εh, εb, εc, Rh, .K_Sub h1 hle, h2, h3, h4, h5, h6⟩
  | K_Let hn hw hsub _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εh, εb, εc, Rh, h1, h2, h3, h4, h5, h6⟩ := ih heq
          exact ⟨t, εh, εb, εc, Rh, .K_Let hn hw hsub h1, h2, h3, h4, h5,
            fun l r hm hno => h6 l r hm (fun hs' hin => hno hs' (by simp [hin]))⟩
  | K_Mark _ hw ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εh, εb, εc, Rh, h1, h2, h3, h4, h5, h6⟩ := ih heq
          exact ⟨t, εh, εb, εc, Rh, .K_Mark h1 hw, h2, h3, h4, h5,
            fun l r hm hno => h6 l r hm (fun hs' hin => hno hs' (by simp [hin]))⟩
  | K_Update hl _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εh, εb, εc, Rh, h1, h2, h3, h4, h5, h6⟩ := ih heq
          exact ⟨t, εh, εb, εc, Rh, .K_Update hl h1, h2, h3, h4, h5,
            fun l r hm hno => h6 l r hm (fun hs' hin => hno hs' (by simp [hin]))⟩
  | K_Release hv hr hst _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εh, εb, εc, Rh, h1, h2, h3, h4, h5, h6⟩ := ih heq
          exact ⟨t, εh, εb, εc, Rh, .K_Release hv hr hst h1, h2, h3, h4, h5,
            fun l r hm hno => h6 l r hm (fun hs' hin => hno hs' (by simp [hin]))⟩
  | K_Drop hl hsub _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εh, εb, εc, Rh, h1, h2, h3, h4, h5, h6⟩ := ih heq
          exact ⟨t, εh, εb, εc, Rh, .K_Drop hl hsub h1, h2, h3, h4, h5,
            fun l r hm hno => h6 l r hm (fun hs' hin => hno hs' (by simp [hin]))⟩
  | K_Guard hm hsub hp hb _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εh, εb, εc, Rh, h1, h2, h3, h4, h5, -⟩ := ih heq
          exact ⟨t, εh, εb, εc, Rh, .K_Guard hm hsub hp hb h1, h2, h3, h4, h5,
            fun l r hm _ => by simp [Eff.mem, Eff.test, Eff.atoms, Eff.empty] at hm⟩
  | @K_Handle R0 ε0 εc0 εb0 hs0 k0 t0 b0 E0 Re0 ht hsub hbh hc hw ih =>
      cases k1 with
      | nil =>
          simp only [List.nil_append, List.cons.injEq, Frame.handleF.injEq] at heq
          obtain ⟨rfl, rfl⟩ := heq
          exact ⟨_, _, _, _, _, .K_Handle (.K_Empty (Eff.Sub.refl _) hw) (Eff.Covers.refl _) hbh hc hw,
            ht, hsub, hc.store (hideBuilders_sub _), hw, fun l r hm _ => ⟨r, hm, Atom.Covers.refl _⟩⟩
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, εh, εb, εc, Rh, h1, h2, h3, h4, h5, h6⟩ := ih heq
          refine ⟨t, εh, εb, εc, Rh, .K_Handle h1 hsub hbh hc hw, h2, h3, h4, h5, fun l r hm hno => ?_⟩
          have hh := hno hs0 (by simp)
          have hm' := hbh.1 _ hm
          rw [Eff.mem_union] at hm'
          have hm'' := hm'.resolve_right (fun hx => by
            change Eff.test (handled P B hs0) (.name l r) = true at hx
            rw [handled_name, hh] at hx
            cases hx)
          obtain ⟨c, hc', hcc⟩ := hsub.1 _ hm''
          obtain ⟨jx, rfl⟩ := hcc.name_right
          obtain ⟨r', h1', h2'⟩ := h6 l jx hc' (fun hs' hin => hno hs' (by simp [hin]))
          exact ⟨r', h1', h2'.trans hcc⟩
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
          obtain ⟨t, εh, εb, εc, Rh, h1, h2, h3, h4, h5, h6⟩ := ih heq
          refine ⟨t, εh, εb, εc, Rh, .K_Handle_Fail h1 hr hn hc he hw, h2, h3, h4, h5, fun l r hm hno => ?_⟩
          have ha : Eff.mem _ (.name l r) := (Eff.mem_union _ _ _).mp hm |>.resolve_left (by
            simp [Eff.mem, Eff.test, Eff.singleFail, Eff.atoms])
          obtain ⟨c, hc', hcc⟩ := hr.1 _ ha
          obtain ⟨jx, rfl⟩ := hcc.name_right
          obtain ⟨r', h1', h2'⟩ := h6 l jx hc' (fun hs' hin => hno hs' (by simp [hin]))
          exact ⟨r', h1', h2'.trans hcc⟩

/-! ## `releases(K')` の型付け -/

/-- 継続の中の解放の枠と `drop` の枠が、末尾のエフェクト ε0 のもとで満たす性質。 -/
def FramesOk (P : Program) (B : Builtins) (Ψ : StoreTy) (ε0 : Eff) (k : Cont) : Prop :=
  ∀ f ∈ k, match f with
    | .release v => (∃ o, HasTypeV P B Ψ [] [] v (.opaqueTop o) ∧ B.isResource o = true) ∧
        Eff.mem ε0 (.nameTop stateEff)
    | .drop κ => ∃ b t e r, Ψ κ = some (.cont b t e r) ∧
        (Eff.mem e (.nameTop stateEff) → Eff.mem ε0 (.nameTop stateEff))
    | _ => True

theorem ContTy.framesOk (hdecl : P.EffectsOk B) (hb : B.CoreAssumptions P) {Ψ R ε k a b ε0 Re}
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
  | K_Handle _ _ _ _ _ ih | K_Handle_Fail _ _ _ _ _ _ ih =>
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
      | .release v => (∃ o, HasTypeV P B Ψ [] [] v (.opaqueTop o) ∧ B.isResource o = true) ∧
          Eff.mem ε (.nameTop stateEff)
      | .drop κ => ∃ b t e r, Ψ κ = some (.cont b t e r) ∧
          (Eff.mem e (.nameTop stateEff) → Eff.mem ε (.nameTop stateEff))
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
theorem ContTy.drop_releases (hdecl : P.EffectsOk B) (hb : B.CoreAssumptions P)
    {Ψ R ε k a b ε0 Re b' t' e' r' R'' ε'' k'}
    (hk : ContTy P B Ψ R ε k a b ε0 Re) (hcond : Eff.mem e' (.nameTop stateEff) → Eff.mem ε (.nameTop stateEff))
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
