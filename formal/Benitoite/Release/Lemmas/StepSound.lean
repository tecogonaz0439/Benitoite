import Benitoite.Release.Lemmas.EffectSound

/-!
# 遷移を計算する関数の健全性（段階 B）

`step` が返す遷移は `Step` の遷移である。IO の応答と解放の応答は、起こりうる応答があるときに `oracle` と
`rel` が選ぶ応答であり、応答があることは状態の型付けから分かる。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

theorem splitHandler_some {o : OpRef} : ∀ {k k1 : Cont} {h : List Clause} {k2 : Cont},
    splitHandler o k = some (k1, h, k2) → SplitAt o k k1 h k2
  | [], _, _, _, e => by simp [splitHandler] at e
  | f :: k, k1, h, k2, e => by
      have rest : ∀ {k1'}, splitHandler o k = some (k1', h, k2) → (∀ h', f = .handleF h' → handles h' o = false) →
          k1 = f :: k1' → SplitAt o (f :: k) k1 h k2 := by
        intro k1' e' hf hk1
        obtain ⟨hk, hh', hn⟩ := splitHandler_some e'
        refine ⟨by rw [hk1, hk]; rfl, hh', fun h3 hin => ?_⟩
        rw [hk1] at hin
        rcases List.mem_cons.mp hin with e3 | hin
        · exact hf h3 e3.symm
        · exact hn h3 hin
      cases f with
      | handleF h' =>
          simp only [splitHandler] at e
          split at e
          · rename_i hh
            simp only [Option.some.injEq, Prod.mk.injEq] at e
            obtain ⟨rfl, rfl, rfl⟩ := e
            exact ⟨rfl, hh, fun _ hin => by simp at hin⟩
          · rename_i hh
            cases e' : splitHandler o k with
            | none => rw [e'] at e; simp at e
            | some p =>
                obtain ⟨k1', h'', k2'⟩ := p
                rw [e'] at e
                simp only [Option.map_some, Option.some.injEq, Prod.mk.injEq] at e
                obtain ⟨rfl, rfl, rfl⟩ := e
                exact rest e' (fun h3 e3 => by cases e3; simpa using hh) rfl
      | letF n | mark | update l | release v | drop κ | guardF v arms next body =>
          simp only [splitHandler] at e
          cases e' : splitHandler o k with
          | none => rw [e'] at e; simp at e
          | some p =>
              obtain ⟨k1', h'', k2'⟩ := p
              rw [e'] at e
              simp only [Option.map_some, Option.some.injEq, Prod.mk.injEq] at e
              obtain ⟨rfl, rfl, rfl⟩ := e
              exact rest e' (fun h3 e3 => by cases e3) rfl

theorem splitHandler_none {o : OpRef} : ∀ {k : Cont}, splitHandler o k = none → NoHandler k o
  | [], _ => fun _ hin => by simp at hin
  | f :: k, e => by
      cases f with
      | handleF h' =>
          simp only [splitHandler] at e
          split at e
          · simp at e
          · rename_i hh
            have hk := splitHandler_none (k := k) (by
              cases e' : splitHandler o k with
              | none => rfl
              | some p => rw [e'] at e; simp at e)
            intro h3 hin
            rcases List.mem_cons.mp hin with e3 | hin
            · cases e3; simpa using hh
            · exact hk h3 hin
      | letF n | mark | update l | release v | drop κ | guardF v arms next body =>
          simp only [splitHandler] at e
          have hk := splitHandler_none (k := k) (by
            cases e' : splitHandler o k with
            | none => rfl
            | some p => rw [e'] at e; simp at e)
          intro h3 hin
          rcases List.mem_cons.mp hin with e3 | hin
          · cases e3
          · exact hk h3 hin

theorem releaseStep_cases {rel : Val → Option ErrKind} {v ok err l s'}
    (h : releaseStep rel v ok err = some (l, s')) :
    (rel v = none ∧ l = some (.release v none) ∧ s' = ok) ∨
      (∃ r, rel v = some r ∧ l = some (.release v (some r)) ∧ s' = err r) := by
  unfold releaseStep at h
  split at h
  · rename_i e; simp only [Option.some.injEq, Prod.mk.injEq] at h
    exact Or.inl ⟨e, h.1.symm, h.2.symm⟩
  · rename_i r e; simp only [Option.some.injEq, Prod.mk.injEq] at h
    exact Or.inr ⟨r, e, h.1.symm, h.2.symm⟩

theorem rel_resp (hb : B.Assumptions P) {rel : Val → Option ErrKind}
    (hrel : ∀ v r, B.releaseResponse v r → B.releaseResponse v (rel v)) {Ψ R ε v k a b Eb Re}
    (hk : ContTy P B Ψ R ε (.release v :: k) a b Eb Re) : B.releaseResponse v (rel v) := by
  obtain ⟨o, hv, hres, _, _⟩ := hk.inv_release
  obtain ⟨r, hr⟩ := hb.release_exists Ψ v o hv hres
  exact hrel v r hr

theorem step_soundE (hb : B.Assumptions P) (oracle : Oracle) (rel : Val → Option ErrKind)
    (fresh : Store → Nat)
    (horacle : ∀ b ts es ws o, B.ioResponse b ts es ws o → B.ioResponse b ts es ws (oracle b ts es ws))
    (hrel : ∀ v r, B.releaseResponse v r → B.releaseResponse v (rel v))
    (hfresh : ∀ σ : Store, (∃ n, ∀ l, n ≤ l → σ l = none) → σ (fresh σ) = none)
    {Eb : Eff} {s : State} {l : Option Event} {s' : State}
    (hs : StateTyE P B Eb s) (h : step P B oracle rel fresh s = some (l, s')) : Step P B s l s' := by
  cases s with
  | run m k σ =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, _, _, _⟩ := hs
      have hfr : σ (fresh σ) = none := hfresh σ hσ.1
      cases m with
      | ret v =>
          cases k with
          | nil => simp [step] at h
          | cons f k =>
              cases f with
              | guardF w arms next body =>
                  cases v with
                  | const c =>
                      cases c with
                      | boolean b =>
                          cases b <;> simp only [step, Option.some.injEq, Prod.mk.injEq] at h <;>
                            obtain ⟨rfl, rfl⟩ := h
                          · exact .E_GuardF
                          · exact .E_GuardT
                      | _ => simp [step] at h
                  | _ => simp [step] at h
              | letF n =>
                  simp only [step, Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h; exact .E_Return
              | mark =>
                  simp only [step, Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h; exact .E_Mark
              | update l =>
                  simp only [step, Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h; exact .E_Update
              | release w =>
                  simp only [step] at h
                  have hr := rel_resp hb hrel hk
                  rcases releaseStep_cases h with ⟨e, rfl, rfl⟩ | ⟨r, e, rfl, rfl⟩
                  · rw [e] at hr; exact .E_Release hr
                  · rw [e] at hr; exact .E_RelErr hr
              | handleF hs =>
                  simp only [step, Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h; exact .E_HRet
              | drop κ =>
                  simp only [step] at h
                  split at h
                  · rename_i e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                    obtain ⟨rfl, rfl⟩ := h; exact .E_Drop e
                  · rename_i k' e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                    obtain ⟨rfl, rfl⟩ := h; exact .E_DropRel e
                  · simp at h
      | letIn m n =>
          simp only [step, Option.some.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, rfl⟩ := h; exact .E_Let
      | meth v m ss es ws =>
          cases v with
          | dict i ts vs =>
              simp only [step] at h
              split at h
              · rename_i id hi
                split at h
                · rename_i body cd hbody hcd
                  split at h
                  · rename_i ms hms
                    split at h
                    · rename_i e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                      obtain ⟨rfl, rfl⟩ := h
                      exact .E_Meth hi hbody hcd hms e.1 e.2.1 e.2.2.1 e.2.2.2.1 e.2.2.2.2
                    · simp at h
                  · simp at h
                · simp at h
              · simp at h
          | _ =>
              simp only [step, Option.map_eq_some_iff, Prod.mk.injEq] at h
              obtain ⟨v', hv', rfl, rfl⟩ := h
              exact .E_Super hv'
      | app f ws =>
          obtain ⟨_, _, _, hf, _⟩ := hm.inv_app rfl
          rcases hf.canonical_fn with ⟨ps, body, rfl⟩ | ⟨g, ts, es, rfl⟩ | ⟨b0, ts, es, rfl⟩ | ⟨o, ts, rfl⟩
          · simp only [step] at h
            split at h
            · rename_i e; simp only [Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h; exact .E_Lam e
            · simp at h
          · simp only [step] at h
            split at h
            · rename_i d hd
              split at h
              · rename_i e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                obtain ⟨rfl, rfl⟩ := h; exact .E_Fun hd e.1 e.2.1 e.2.2
              · simp at h
            · simp at h
          · simp only [step] at h
            split at h
            · simp at h
            · rename_i s0 hsig
              split at h
              case h_1 =>
                have hkd : s0.kind = .pure := by assumption
                split at h
                · rename_i v e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h; exact .E_Prim hsig hkd e
                · rename_i r e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h; exact .E_Err hsig hkd e
                · simp at h
              case h_2 | h_3 =>
                have hkd : s0.kind = .io ∨ s0.kind = .exit := by
                  first | exact Or.inl ‹_› | exact Or.inr ‹_›
                obtain ⟨s1, hs1, htl, hel, had, hargs, _, _⟩ := inv_prim_app hm
                have e0 := Option.some.inj (hsig.symm.trans hs1)
                subst e0
                obtain ⟨o, ho⟩ := hb.io_exists Ψ b0 s0 ts es _ hsig hkd htl hel had hargs
                have hro := horacle _ _ _ _ _ ho
                split at h
                · rename_i k1 h' k2 e1
                  split at h
                  · rename_i c e2; simp only [Option.some.injEq, Prod.mk.injEq] at h
                    obtain ⟨rfl, rfl⟩ := h; exact .E_OpPrim hsig hkd (splitHandler_some e1) e2 hfr
                  · simp at h
                · rename_i e1
                  have hno := splitHandler_none e1
                  split at h
                  · simp only [Option.some.injEq, Prod.mk.injEq] at h
                    obtain ⟨rfl, rfl⟩ := h
                    refine .E_IO hsig (by assumption) hno ?_
                    rwa [‹oracle b0 ts es _ = _›] at hro
                  · simp only [Option.some.injEq, Prod.mk.injEq] at h
                    obtain ⟨rfl, rfl⟩ := h
                    refine .E_IOErr hsig hkd hno ?_
                    rwa [‹oracle b0 ts es _ = _›] at hro
                  · simp only [Option.some.injEq, Prod.mk.injEq] at h
                    obtain ⟨rfl, rfl⟩ := h
                    refine .E_Exit hsig (by assumption) hno ?_
                    rwa [‹oracle b0 ts es _ = _›] at hro
                  · simp at h
              case h_4 =>
                simp only [Option.some.injEq, Prod.mk.injEq] at h
                obtain ⟨rfl, rfl⟩ := h; exact .E_RefNew hsig (by assumption) hfr
              case h_5 =>
                have hkd : s0.kind = .refGet := by assumption
                split at h
                · rename_i v e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h; exact .E_RefGet hsig hkd e
                · simp at h
              case h_6 =>
                simp only [Option.some.injEq, Prod.mk.injEq] at h
                obtain ⟨rfl, rfl⟩ := h; exact .E_RefSet hsig (by assumption)
              case h_7 =>
                simp only [Option.some.injEq, Prod.mk.injEq] at h
                obtain ⟨rfl, rfl⟩ := h; exact .E_RefUpdate hsig (by assumption)
              case h_8 =>
                have hkd : s0.kind = .force := by assumption
                split at h
                · rename_i v e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h; exact .E_ForceDone hsig hkd e
                · rename_i m e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h; exact .E_Force hsig hkd e
                · simp at h
              case h_9 => simp at h
          · simp only [step] at h
            split at h
            · rename_i k1 h' k2 e1
              split at h
              · rename_i c e2; simp only [Option.some.injEq, Prod.mk.injEq] at h
                obtain ⟨rfl, rfl⟩ := h; exact .E_Op (splitHandler_some e1) e2 hfr
              · simp at h
            · simp at h
      | ite v m n =>
          obtain ⟨_, _, hv, _⟩ := hm.inv_ite rfl
          obtain ⟨bb, rfl⟩ := hv.canonical_boolean
          cases bb <;> simp only [step, Option.some.injEq, Prod.mk.injEq] at h <;> obtain ⟨rfl, rfl⟩ := h
          · exact .E_IfF
          · exact .E_IfT
      | «match» v arms =>
          simp only [step, Option.some.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, rfl⟩ := h; exact .E_Match
      | lazyC m =>
          simp only [step, Option.some.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, rfl⟩ := h; exact .E_Lazy hfr
      | escape v =>
          cases k with
          | nil => simp [step] at h
          | cons f k =>
              cases f with
              | guardF v arms next body => simp [step] at h
              | letF n =>
                  simp only [step, Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h; exact .E_EscLet
              | mark =>
                  simp only [step, Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h; exact .E_EscMark
              | update l => simp [step] at h
              | release w =>
                  simp only [step] at h
                  have hr := rel_resp hb hrel hk
                  rcases releaseStep_cases h with ⟨e, rfl, rfl⟩ | ⟨r, e, rfl, rfl⟩
                  · rw [e] at hr; exact .E_EscRel hr
                  · rw [e] at hr; exact .E_EscRelErr hr
              | handleF hs =>
                  simp only [step, Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h; exact .E_EscHandle
              | drop κ =>
                  simp only [step] at h
                  split at h
                  · rename_i e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                    obtain ⟨rfl, rfl⟩ := h; exact .E_EscDrop e
                  · rename_i k' e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                    obtain ⟨rfl, rfl⟩ := h; exact .E_EscDropRel e
                  · simp at h
      | use v m =>
          simp only [step, Option.some.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, rfl⟩ := h; exact .E_Use
      | handle m hs =>
          simp only [step, Option.some.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, rfl⟩ := h; exact .E_Handle
      | resume w v =>
          rcases hm.resume_form rfl with ⟨i, rfl⟩ | ⟨κ, rfl⟩
          · simp [step] at h
          · simp only [step] at h
            split at h
            · rename_i k' e; simp only [Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h; exact .E_Resume e
            · rename_i e; simp only [Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h; exact .E_ResumeErr e
            · simp at h
  | matchRun v arms next k σ =>
      simp only [step] at h
      cases hi : arms[next]? with
      | none => simp [hi] at h
      | some arm =>
          cases arm with
          | mk alts guard body =>
              rw [hi] at h
              cases ha : firstAlt v alts with
              | none =>
                  simp only [ha, Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h
                  exact .E_MatchSkip hi ha
              | some ws =>
                  simp only [ha] at h
                  cases guard with
                  | none =>
                      simp only [Option.some.injEq, Prod.mk.injEq] at h
                      obtain ⟨rfl, rfl⟩ := h
                      exact .E_MatchBody hi ha
                  | some g =>
                      simp only [Option.some.injEq, Prod.mk.injEq] at h
                      obtain ⟨rfl, rfl⟩ := h
                      exact .E_MatchGuard hi ha
  | error rs k σ =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, _, _⟩ := hs
      cases k with
      | nil => simp [step] at h
      | cons f k =>
          cases f with
          | guardF v arms next body =>
              simp only [step, Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h; exact .E_ErrPopGuard
          | letF n =>
              simp only [step, Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h; exact .E_ErrPopLet
          | mark =>
              simp only [step, Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h; exact .E_ErrPopMark
          | update l =>
              simp only [step, Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h; exact .E_ErrPopUpdate
          | release w =>
              simp only [step] at h
              have hr := rel_resp hb hrel hk
              rcases releaseStep_cases h with ⟨e, rfl, rfl⟩ | ⟨r, e, rfl, rfl⟩
              · rw [e] at hr; exact .E_ErrRel hr
              · rw [e] at hr; exact .E_ErrRelErr hr
          | handleF hs =>
              simp only [step, Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h; exact .E_ErrPopHandle
          | drop κ =>
              simp only [step] at h
              split at h
              · rename_i e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                obtain ⟨rfl, rfl⟩ := h; exact .E_ErrDrop e
              · rename_i k' e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                obtain ⟨rfl, rfl⟩ := h; exact .E_ErrDropRel e
              · simp at h
  | exit n rs k σ =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, _, _⟩ := hs
      cases k with
      | nil => simp [step] at h
      | cons f k =>
          cases f with
          | guardF v arms next body =>
              simp only [step, Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h; exact .E_ExitPopGuard
          | letF n =>
              simp only [step, Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h; exact .E_ExitPopLet
          | mark =>
              simp only [step, Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h; exact .E_ExitPopMark
          | update l =>
              simp only [step, Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h; exact .E_ExitPopUpdate
          | release w =>
              simp only [step] at h
              have hr := rel_resp hb hrel hk
              rcases releaseStep_cases h with ⟨e, rfl, rfl⟩ | ⟨r, e, rfl, rfl⟩
              · rw [e] at hr; exact .E_ExitRel hr
              · rw [e] at hr; exact .E_ExitRelErr hr
          | handleF hs =>
              simp only [step, Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h; exact .E_ExitPopHandle
          | drop κ =>
              simp only [step] at h
              split at h
              · rename_i e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                obtain ⟨rfl, rfl⟩ := h; exact .E_ExitDrop e
              · rename_i k' e; simp only [Option.some.injEq, Prod.mk.injEq] at h
                obtain ⟨rfl, rfl⟩ := h; exact .E_ExitDropRel e
              · simp at h

end Benitoite.Release
