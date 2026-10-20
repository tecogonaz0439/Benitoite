import Benitoite.Release.Lemmas.ContLemmas
import Benitoite.Release.Lemmas.Regularity

/-!
# Fail の伝播と捕捉するエラー型の一致

最も内側の節まで Fail の所属を伝播し、上限と NoFail から型の一致を導く。
実行の選択には型を比較する条件を加えない。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-- 型付き継続中のハンドラは、通常節だけか一つの Fail 節である。 -/
theorem ContTy.handler_kind {Ψ R ε k a b ε0 Re hs}
    (hk : ContTy P B Ψ R ε k a b ε0 Re) (hm : Frame.handleF hs ∈ k) :
    handles hs .fail = false ∨ ∃ E body, hs = [.fail E body] := by
  induction hk with
  | K_Empty => simp at hm
  | K_Sub _ _ ih => exact ih hm
  | K_Handle _ _ hc _ ih =>
      rcases List.mem_cons.mp hm with heq | hm
      · cases heq; exact Or.inl hc.no_failure
      · exact ih hm
  | K_Handle_Fail _ _ _ hc _ _ ih =>
      rcases List.mem_cons.mp hm with heq | hm
      · cases heq; obtain ⟨body, heq⟩ := hc.shape; exact Or.inr ⟨_, body, heq⟩
      · exact ih hm
  | K_Let _ _ _ _ ih | K_Mark _ _ ih | K_Update _ _ ih | K_Release _ _ _ _ ih
  | K_Drop _ _ _ ih | K_Guard _ _ _ _ _ ih =>
      rcases List.mem_cons.mp hm with heq | hm
      · cases heq
      · exact ih hm

/-- 通常の操作が選ぶ型付きハンドラには Fail 節がない。 -/
theorem ContTy.selected_ordinary {Ψ R ε k a b ε0 Re o k1 hs k2}
    (hk : ContTy P B Ψ R ε k a b ε0 Re) (ho : o ≠ .fail)
    (hsplit : SplitAt o k k1 hs k2) : handles hs .fail = false := by
  rcases hk.handler_kind (hs := hs) (by rw [hsplit.1]; simp) with hn | ⟨E, body, rfl⟩
  · exact hn
  · have hh := hsplit.2.1
    simp [handles, Clause.op] at hh
    exact (ho hh.symm).elim

/-- Fail を捕捉しない継続を通って、Fail の所属は末尾へ届く。 -/
theorem ContTy.fail_end {Ψ R ε k a b ε0 Re E}
    (h : ContTy P B Ψ R ε k a b ε0 Re) (hno : NoHandler k .fail)
    (he : Eff.memFail ε E) : Eff.memFail ε0 E := by
  induction h with
  | K_Empty hs _ => exact hs.2 _ he
  | K_Let _ _ _ _ ih | K_Mark _ _ ih | K_Update _ _ ih | K_Release _ _ _ _ ih
  | K_Drop _ _ _ ih => exact ih (fun hs hm => hno hs (by simp [hm])) he
  | K_Handle _ hs _ _ ih =>
      have hh := (Eff.memFail_union _ _ _).mp he
      have hh' := hh.resolve_right ((handled_noFail P B _).not_memFail E)
      exact ih (fun hs hm => hno hs (by simp [hm])) (hs.2 _ hh')
  | K_Handle_Fail _ _ _ hc _ _ _ =>
      have hf := hno _ List.mem_cons_self
      rw [hc.handles] at hf
      cases hf
  | K_Guard => exact ((Eff.memFail_empty E).mp he).elim
  | K_Sub _ _ ih => exact ih hno he

/-- 分割した手前 K1 だけを辿り、選ばれた Fail 枠の入力の上限へ所属を返す。 -/
theorem ContTy.failure_prefix {Ψ R ein k1 E body k2 a b Eb Re E'}
    (h : ContTy P B Ψ R ein (k1 ++ .handleF [.fail E body] :: k2) a b Eb Re)
    (hno : NoHandler k1 .fail) (he : Eff.memFail ein E') :
    ∃ Rh eout Rest ec t,
      HasFailureClause P B Ψ Qempty [] [] E Rh [.fail E body] t ec ∧
      NoFail Qempty Rest ∧ Eff.Sub Rest eout ∧ Eff.Sub ec eout ∧ Ty.WF 0 t ∧
      ContTy P B Ψ Rh eout k2 t b Eb Re ∧
      Eff.memFail (Eff.union (Eff.singleFail E) Rest) E' := by
  generalize heq : (k1 ++ Frame.handleF [.fail E body] :: k2) = k0 at h
  induction h generalizing k1 with
  | K_Empty _ _ => cases k1 <;> simp at heq
  | K_Sub _ _ ih => exact ih hno he heq
  | K_Let _ _ _ _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          exact ih (fun hs hm => hno hs (by simp [hm])) he heq
  | K_Mark _ _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          exact ih (fun hs hm => hno hs (by simp [hm])) he heq
  | K_Update _ _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          exact ih (fun hs hm => hno hs (by simp [hm])) he heq
  | K_Release _ _ _ _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          exact ih (fun hs hm => hno hs (by simp [hm])) he heq
  | K_Drop _ _ _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          exact ih (fun hs hm => hno hs (by simp [hm])) he heq
  | K_Guard => exact ((Eff.memFail_empty E').mp he).elim
  | K_Handle _ hs hc _ ih =>
      cases k1 with
      | nil =>
          simp only [List.nil_append, List.cons.injEq, Frame.handleF.injEq] at heq
          obtain ⟨rfl, rfl⟩ := heq
          have hf := hc.no_failure
          simp [handles, Clause.op] at hf
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          have he' := ((Eff.memFail_union _ _ _).mp he).resolve_right ((handled_noFail P B _).not_memFail E')
          exact ih (fun hs hm => hno hs (by simp [hm])) (hs.2 _ he') heq
  | K_Handle_Fail ht hr hn hc hec hw ih =>
      cases k1 with
      | nil =>
          simp only [List.nil_append, List.cons.injEq, Frame.handleF.injEq] at heq
          obtain ⟨rfl, rfl⟩ := heq
          cases hc with
          | one hew htw hecw hb =>
              exact ⟨_, _, _, _, _, .one hew htw hecw (by simpa only [hideBuilders_idem] using hb), hn, hr, hec, hw, ht, he⟩
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          have hf := hno _ List.mem_cons_self
          rw [hc.handles] at hf
          cases hf

/-- Fail 枠で分割した保存継続の上限は Rest と節の効果の和である。 -/
theorem ContTy.split_failure {Ψ R ein k1 E body k2 a b Eb Re}
    (h : ContTy P B Ψ R ein (k1 ++ .handleF [.fail E body] :: k2) a b Eb Re) :
    ∃ t Rh eout Rest ec,
      HasFailureClause P B Ψ Qempty [] [] E Rh [.fail E body] t ec ∧
      NoFail Qempty Rest ∧ Eff.Sub Rest eout ∧ Eff.Sub ec eout ∧ Ty.WF 0 t ∧
      ContTy P B Ψ Rh eout k2 t b Eb Re ∧
      ContTy P B Ψ R ein (k1 ++ [.handleF [.fail E body]]) a t (captureEff Rest ec) Rh := by
  generalize heq : (k1 ++ Frame.handleF [.fail E body] :: k2) = k0 at h
  induction h generalizing k1 with
  | K_Empty _ _ => cases k1 <;> simp at heq
  | K_Sub _ hle ih =>
      obtain ⟨t, Rh, eout, Rest, ec, hc, hn, hr, he, hw, ht, hsave⟩ := ih heq
      exact ⟨t, Rh, eout, Rest, ec, hc, hn, hr, he, hw, ht, .K_Sub hsave hle⟩
  | K_Let hn hw hsub _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, Rh, eout, Rest, ec, hc, hnf, hre, he, htw, ht, hsave⟩ := ih heq
          exact ⟨t, Rh, eout, Rest, ec, hc, hnf, hre, he, htw, ht, .K_Let hn hw hsub hsave⟩
  | K_Mark _ hw ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, Rh, eout, Rest, ec, hc, hnf, hre, he, htw, ht, hsave⟩ := ih heq
          exact ⟨t, Rh, eout, Rest, ec, hc, hnf, hre, he, htw, ht, .K_Mark hsave hw⟩
  | K_Update hl _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, Rh, eout, Rest, ec, hc, hnf, hre, he, htw, ht, hsave⟩ := ih heq
          exact ⟨t, Rh, eout, Rest, ec, hc, hnf, hre, he, htw, ht, .K_Update hl hsave⟩
  | K_Release hv hr hst _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, Rh, eout, Rest, ec, hc, hnf, hre, he, htw, ht, hsave⟩ := ih heq
          exact ⟨t, Rh, eout, Rest, ec, hc, hnf, hre, he, htw, ht, .K_Release hv hr hst hsave⟩
  | K_Drop hl hsub _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, Rh, eout, Rest, ec, hc, hnf, hre, he, htw, ht, hsave⟩ := ih heq
          exact ⟨t, Rh, eout, Rest, ec, hc, hnf, hre, he, htw, ht, .K_Drop hl hsub hsave⟩
  | K_Guard hm hsub hp hb _ ih =>
      cases k1 with
      | nil => cases heq
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, Rh, eout, Rest, ec, hc, hnf, hre, he, htw, ht, hsave⟩ := ih heq
          exact ⟨t, Rh, eout, Rest, ec, hc, hnf, hre, he, htw, ht, .K_Guard hm hsub hp hb hsave⟩
  | K_Handle ht hs hc hw ih =>
      cases k1 with
      | nil =>
          simp only [List.nil_append, List.cons.injEq, Frame.handleF.injEq] at heq
          obtain ⟨rfl, rfl⟩ := heq
          have hf := hc.no_failure
          simp [handles, Clause.op] at hf
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, Rh, eout, Rest, ec, hcl, hn, hr, he, htw, ht, hsave⟩ := ih heq
          exact ⟨t, Rh, eout, Rest, ec, hcl, hn, hr, he, htw, ht, .K_Handle hsave hs hc hw⟩
  | K_Handle_Fail ht hr hn hc he hw ih =>
      cases k1 with
      | nil =>
          simp only [List.nil_append, List.cons.injEq, Frame.handleF.injEq] at heq
          obtain ⟨rfl, rfl⟩ := heq
          cases hc with
          | one hew htw hecw hb =>
              have hcl := HasFailureClause.one (Δ := []) hew htw hecw (by simpa only [hideBuilders_idem] using hb)
              exact ⟨_, _, _, _, _, hcl, hn, hr, he, hw, ht, failure_capture_base hcl hn hw⟩
      | cons f k1 =>
          simp only [List.cons_append, List.cons.injEq] at heq
          obtain ⟨rfl, heq⟩ := heq
          obtain ⟨t, Rh, eout, Rest, ec, hcl, hnf, hre, hec, htw, ht, hsave⟩ := ih heq
          exact ⟨t, Rh, eout, Rest, ec, hcl, hnf, hre, hec, htw, ht, .K_Handle_Fail hsave hr hn hc he hw⟩

/-- SplitAt の手前には Fail を処理する枠がない。 -/
theorem splitAt_failure_prefix {k k1 E body k2}
    (hs : SplitAt .fail k k1 [.fail E body] k2) :
    NoHandler k1 .fail ∧ ∀ E' body', .handleF [.fail E' body'] ∉ k1 := by
  refine ⟨hs.2.2, ?_⟩
  intro E' body' hm
  have hf := hs.2.2 _ hm
  simp [handles, Clause.op] at hf

/-- 包含で広がった raise の型から元の二型と潜在効果を取り出す。 -/
theorem HasTypeVQ.inv_raise {Ψ Q C Γ v a T E}
    (hv : HasTypeVQ P B Ψ Q C Γ v a) (heq : v = .raise T E) :
    Ty.WF C.length T ∧ Ty.WF C.length E ∧ Ty.Le (.fn ["error"] [E] T (Eff.singleFail E)) a := by
  match hv with
  | .V_Const => cases heq
  | .V_Raise ht he => cases heq; exact ⟨ht, he, Ty.Le.refl _⟩
  | .V_Sub hv hl _ =>
      obtain ⟨ht, he, hl'⟩ := hv.inv_raise heq
      exact ⟨ht, he, hl'.trans hl⟩

/-- Fail 専用の handle の入力上限と、外へ残す効果を取り出す。 -/
theorem HasTypeCQ.inv_handle_failure {Δl : LocalCtx} {Ψ Q C Γ R m' a ε m h}
    (hh : HasTypeCQ P B Ψ Q C Γ R m' a ε Δl) (hm : m' = .handle m h)
    (ho : handles h .fail = true) :
    ∃ t eb E Rest ec, HasTypeCQ P B Ψ Q C Γ R m t eb Δl ∧
      Eff.Sub eb (Eff.union (Eff.singleFail E) Rest) ∧ NoFail Q Rest ∧
      HasFailureClause P B Ψ Q C Γ E R h t ec Δl ∧ Ty.Le t a ∧ Eff.Sub (Eff.union Rest ec) ε := by
  match hh with
  | .C_Handle _ _ hc => cases hm; rw [hc.no_failure] at ho; cases ho
  | .C_Handle_Fail ht hs hn hc =>
      cases hm; exact ⟨_, _, _, _, _, ht, hs, hn, hc, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub ht hl hs _ =>
      obtain ⟨t, eb, E, Rest, ec, ht, hb, hn, hc, hl', hs'⟩ := ht.inv_handle_failure hm ho
      exact ⟨t, eb, E, Rest, ec, ht, hb, hn, hc, hl'.trans hl, hs'.trans hs⟩
  | .C_Eff ht hs =>
      obtain ⟨t, eb, E, Rest, ec, ht, hb, hn, hc, hl, hs'⟩ := ht.inv_handle_failure hm ho
      exact ⟨t, eb, E, Rest, ec, ht, hb, hn, hc, hl, hs'.trans hs⟩
  | .C_BuilderLet .. | .C_BuilderOp .. => cases hm

/-- raise の適用で必要な Fail は C_Sub/C_Eff/V_Sub を通っても残る。 -/
theorem HasTypeCQ.inv_raise_app {Δl : LocalCtx} {Ψ Q C Γ R T E v a em}
    (hm : HasTypeCQ P B Ψ Q C Γ R (.app (.raise T E) [v]) a em Δl) :
    Ty.WF C.length T ∧ Ty.WF C.length E ∧ Ty.Le T a ∧
      Eff.Sub (Eff.singleFail E) em ∧ HasTypeVQ P B Ψ Q C Γ v E := by
  obtain ⟨names, as, b, e, hf, ha, hl, hs⟩ := hm.inv_app rfl
  obtain ⟨ht, he, hfn⟩ := hf.inv_raise rfl
  obtain ⟨e', hfn', hsub⟩ := hfn.fn_left
  cases hfn'
  cases ha with
  | cons hv ht' => exact ⟨ht, he, hl, hsub.trans hs, hv⟩

/-- 継続の上限から捕捉先の生のエラー型の一致と引数の型を導く。 -/
theorem failure_clause_selected_typed {Ψ R T E' v a b ein em Eb k k1 E body k2}
    (hm : HasTypeC P B Ψ [] [] R (.app (.raise T E') [v]) a em)
    (hs : Eff.Sub em ein) (hk : ContTy P B Ψ R ein k a b Eb none)
    (hsplit : SplitAt .fail k k1 [.fail E body] k2) :
    E' = E ∧ HasTypeV P B Ψ [] [] v E := by
  obtain ⟨ht, he', _, hfail, hv⟩ := hm.inv_raise_app
  rw [hsplit.1] at hk
  have hem : Eff.memFail ein E' := (hfail.trans hs).2 _ ((Eff.memFail_singleFail _ _).mpr rfl)
  obtain ⟨Rh, eout, Rest, ec, t, hc, hn, _, _, _, _, he⟩ := hk.failure_prefix hsplit.2.2 hem
  have hwE : Ty.WF 0 E := by cases hc with | one he _ _ _ => exact he
  have heq := failure_upper_bound hwE.canonical he'.canonical hn he
  exact ⟨heq, heq ▸ hv⟩

end Benitoite.Release
