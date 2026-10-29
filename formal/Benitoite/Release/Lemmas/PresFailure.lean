import Benitoite.Release.Lemmas.PresBase

/-!
# Fail 捕捉の一歩の保存

継続の規則からエラー型を一致させ、結果型だけを具体化する。
予約した継続の位置は利用不能のまま値置換する（設計書 01-12「型付け規則」）。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-- 閉じた Fail 節へ、結果型とエラー値を代入する。0番の値には型を要求しない。 -/
theorem HasFailureClause.instantiate {Δl : LocalCtx} (hwf : P.WellFormed) (hb : B.CoreAssumptions P)
    {Ψ E R body t ec T v κ}
    (hc : HasFailureClause P B Ψ Qempty [] [] E R [.fail E body] t ec Δl)
    (hΨ : StoreTy.WF Ψ) (hts : ClosedArgs [T])
    (hR : ∀ x, R = some x → Ty.WF 0 0 x)
    (hv : HasTypeV P B Ψ [] [] v E) (hvc : Val.VarsIn 0 (fun _ => True) v) :
    HasTypeC P B Ψ [] [] R ((body.substTy [T] []).instantiate [v, .loc κ]) t (Eff.norm ec) := by
  cases hc with
  | one he ht hew hbody =>
      have hsat : SatAll B [] [T] [({} : TParam)] := by
        refine ⟨rfl, ?_⟩
        intro i x p hx hp
        cases i with
        | zero => simp only [List.getElem?_cons_zero, Option.some.injEq] at hx hp
                  subst x; subst p; exact hb.sat_unconstrained T (hts T (by simp)).1
        | succ i => simp at hx
      have hshR : R.map (Ty.shift 1 0) = R := by
        cases hr : R with
        | none => rfl
        | some x => simp only [Option.map_some]; rw [Ty.shift_of_wf _ _ (hR x hr)]
      rw [Ty.shift_of_wf (c := 0) 1 E he, Ty.shift_of_wf (c := 0) 1 t ht, hshR,
        Eff.shift, Eff.rawShift_of_wf (c := 0) _ _ hew] at hbody
      have hθ := HasTypeCQ.substTy (c := 0) hwf hb hbody (Nat.zero_le _) hts (by simp)
        (by simpa using hsat) (StoreFix.of_wf hΨ.hideBuilders [T]) (RowTransport.refl Qempty)
      have hRθ : R.map (Ty.substAt 0 [T] []) = R := by
        cases hr : R with
        | none => rfl
        | some x => simp only [Option.map_some]; rw [Ty.substAt_nil_of_wf [T] x (hR x hr)]
      simp only [List.take_zero, envSubst, shiftEnv, List.map_nil, List.map_cons,
        Option.map_none, Option.map_some] at hθ
      rw [Ty.substAt_nil_of_wf (c := 0) [T] E he, Ty.substAt_nil_of_wf (c := 0) [T] t ht, hRθ,
        Eff.substAt_nil_of_wf (c := 0) [T] (Eff.norm ec) (Eff.norm_WF ec hew) (Eff.norm_idem ec)] at hθ
      apply (hideBuilders_weaken hθ).subst
      intro i x hi
      cases i with
      | zero => simp at hi
      | succ i =>
          cases i with
          | zero =>
              simp only [List.getElem?_cons_succ, List.getElem?_cons_zero, Option.some.injEq] at hi
              subst x
              exact Or.inr (Or.inl ⟨hv.notCont, he, by simpa [instSubst] using ClosedTy.of hb hv hvc⟩)
          | succ i => simp at hi

/-- E-OpFail の保存。保存継続の効果には Rest と節の効果の双方を残す。 -/
theorem pres_failure (hwf : P.WellFormed) (hb : B.CoreAssumptions P)
    {Ψ σ R a b ε em Eb T E' v k k1 E body k2 κ}
    (hσ : StoreOk P B Ψ σ)
    (hm : HasTypeC P B Ψ [] [] R (.app (.raise T E') [v]) a em)
    (hem : Eff.Sub em ε) (hk : ContTy P B Ψ R ε k a b Eb none)
    (hmc : Comp.VarsIn 0 (fun _ => True) (.app (.raise T E') [v]))
    (hck : Cont.Closed k) (hcσ : Store.Closed σ)
    (hsplit : SplitAt .fail k k1 [.fail E body] k2) (hκ : σ κ = none) :
    StateTyE P B Eb (.run ((body.substTy [T] []).instantiate [v, .loc κ]) (.drop κ :: k2)
      (σ.set κ (.cont (k1 ++ [.handleF [.fail E body]])))) := by
  obtain ⟨heq, hv⟩ := failure_clause_selected_typed hm hem hk hsplit
  subst E'
  obtain ⟨ht, he, hle, _, _⟩ := hm.inv_raise_app
  rw [hsplit.1] at hk hck
  obtain ⟨t, Rh, eout, Rest, ec, hc, hn, hr, hec, htw, hk2, hsave⟩ := hk.split_failure
  have hRh : ∀ x, Rh = some x → Ty.WF 0 0 x := hk2.R_wf (by intro x hx; cases hx)
  have hck' := Cont.Closed.append.mp hck
  have hck2 := Cont.Closed.cons.mp hck'.2
  have hbc : Comp.VarsIn 1 (fun _ => True) body 2 := hck2.1.2.1
  have hts : ClosedArgs [T] := closedArgs_of ⟨hmc.1.1, trivial⟩
  have hvc : Val.VarsIn 0 (fun _ => True) v := hmc.2.1
  have hew : Eff.WF 0 0 ec := by cases hc with | one _ _ hew _ => exact hew
  let x : LocTy := .cont T t (captureEff Rest ec) Rh
  have hcapw : Eff.WF 0 0 (captureEff Rest ec) := by
    apply Eff.norm_WF
    unfold Eff.union
    apply Eff.norm_WF
    change Ty.WFList 0 0 (Rest.fails ++ ec.fails)
    rw [hn.1, List.nil_append]
    cases ec; exact hew
  have hxwf : x.WF := ⟨ht, htw, hRh, hcapw, Eff.norm_idem _⟩
  have hΨκ := hσ.none_of hκ
  have hsub : StoreTy.Sub Ψ (Ψ.set κ x) := StoreTy.set_sub (Or.inl hΨκ)
  have hl : (Ψ.set κ x) κ = some x := by simp [StoreTy.set]
  have hσnew : StoreOk P B (Ψ.set κ x) (σ.set κ (.cont (k1 ++ [.handleF [.fail E body]]))) := hσ.set hxwf (Or.inl hΨκ)
      ⟨T, t, captureEff Rest ec, Rh, hl, ⟨k1, [.fail E body], rfl⟩, R, ε,
        (ContTy.K_Sub hsave hle).store hsub⟩
  -- 節の本体は節の効果 ec で型付き、枠の下の継続の効果 eout は ec を覆う（K-Handle-Fail）。本体の効果を C-Eff で
  -- eout へ広げる（L40.6c）。
  refine ⟨Ψ.set κ x, Rh, t, b, eout, eout, hσnew, ?_, Eff.Sub.refl _, ?_, ?_, ?_, ?_⟩
  · exact .C_Eff ((hc.store hsub).instantiate hwf hb hσnew.wf hts hRh (hv.store hsub) hvc)
      (Eff.covers_norm_right.mpr hec)
  · exact failure_drop hl hr hec (hk2.store hsub)
  · exact Comp.VarsIn.instantiate (depth := 2) (hd := by simp) ⟨hvc, trivial, trivial⟩
      (Comp.VarsIn.substTyAt (c := 0) [] (fun u hu => varsInList_mem (as := [T]) ⟨hmc.1.1, trivial⟩ hu)
        (by simp) body (by simpa using hbc))
  · exact Cont.Closed.cons.mpr ⟨trivial, hck2.2⟩
  · exact hcσ.set (Cont.Closed.append.mpr ⟨hck'.1,
      Cont.Closed.cons.mpr ⟨hck2.1, by intro f hf; simp at hf⟩⟩)

end Benitoite.Release
