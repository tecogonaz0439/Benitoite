import Benitoite.Surface.Lemmas.CallHead

/-! リストの展開と文字列補間の型保存（設計書 01-12「リストの展開」「文字列補間」）。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {Q : NoFailCtx}

variable {view : CoverageView}

variable {P : Release.Program} {B : Builtins} {C : List TParam} {Γ : List (Option Ty)}

theorem CompTypesQ.append {R ε ms ns as bs} (h : CompTypesQ P B Q C Γ R ε ms as)
    (hn : CompTypesQ P B Q C Γ R ε ns bs) : CompTypesQ P B Q C Γ R ε (ms ++ ns) (as ++ bs) := by
  induction h with
  | nil => exact hn
  | cons hm _ ih => exact .cons hm ih

theorem replicate_clean {n a} (ha : TyOK n a) (k : Nat) :
    Ty.VarsInList n (fun _ => True) (List.replicate k a) := by
  induction k with
  | zero => trivial
  | succ k ih => exact ⟨ha, ih⟩

theorem HasTypeVsQ.takeDrop {vs as} (h : HasTypeVsQ P B StoreTy.empty Q C Γ vs as) (n : Nat) :
    HasTypeVsQ P B StoreTy.empty Q C Γ (vs.take n) (as.take n) ∧
      HasTypeVsQ P B StoreTy.empty Q C Γ (vs.drop n) (as.drop n) := by
  induction n generalizing vs as with
  | zero => exact ⟨.nil, h⟩
  | succ n ih =>
      cases h with
      | nil => exact ⟨.nil, .nil⟩
      | cons hv ht => exact ⟨.cons hv (ih ht).1, (ih ht).2⟩

theorem spreadFinish_typed {R h before s after a}
    (hh : CallHead.HasTypeQ P B Q C Γ h ["xs", "ys"] [.list a, .list a] (.list a) Eff.empty)
    (hb : HasTypeEachQ P B StoreTy.empty Q C Γ before a)
    (hs : HasTypeVQ P B StoreTy.empty Q C Γ s (.list a))
    (ha : HasTypeEachQ P B StoreTy.empty Q C Γ after a) (hw : Ty.WF C.length a) :
    HasTypeCQ P B StoreTy.empty Q C Γ R (spreadFinish h before s after) (.list a) Eff.empty := by
  cases before <;> cases after <;> simp only [spreadFinish]
  · exact .C_Return hs
  · exact hh.apply (.cons hs (.cons (.V_List ha hw) .nil))
  · exact hh.apply (.cons (.V_List hb hw) (.cons hs .nil))
  · apply HasTypeCQ.C_Let (hh.apply (.cons (.V_List hb hw) (.cons hs .nil)))
    exact (hh.rename (RenOk.shift [some (.list a)] Γ)).apply
      (.cons (.V_Var rfl (by intro _ _ _ he; cases he))
        (.cons (.V_List (ha.rename (RenOk.shift [some (.list a)] Γ)) hw) .nil))

theorem spreadValues_typed {R h vs a n k}
    (hh : CallHead.HasTypeQ P B Q C Γ h ["xs", "ys"] [.list a, .list a] (.list a) Eff.empty)
    (hv : HasTypeVsQ P B StoreTy.empty Q C Γ vs
      (List.replicate n a ++ .list a :: List.replicate k a)) (hw : Ty.WF C.length a) :
    HasTypeCQ P B StoreTy.empty Q C Γ R (spreadValues h n vs) (.list a) Eff.empty := by
  obtain ⟨hb, hs⟩ := HasTypeVsQ.takeDrop hv n
  simp only [List.take_append, List.drop_append, List.length_replicate,
    List.take_replicate, Nat.min_self, Nat.sub_self, List.take_zero, List.append_nil,
    List.drop_replicate, List.replicate_zero, List.nil_append, List.drop_zero] at hb hs
  unfold spreadValues
  generalize he : vs.drop n = ss at hs ⊢
  cases hs with
  | cons hv hs =>
      exact spreadFinish_typed hh (HasTypeVsQ.each hb (fun _ hm => List.eq_of_mem_replicate hm)) hv
        (HasTypeVsQ.each hs (fun _ hm => List.eq_of_mem_replicate hm)) hw

/-- converterTypes で指定した直接の頭の列。 -/
inductive StrHeadsTyped (P : Release.Program) (B : Builtins) (Q : NoFailCtx) (C : List TParam)
    (Γ : List (Option Ty)) : List CallHead → List Ty → Prop
  | nil : StrHeadsTyped P B Q C Γ [] []
  | cons {h hs name t ts} : CallHead.HasTypeQ P B Q C Γ h [name] [t] (.base .string) Eff.empty →
      StrHeadsTyped P B Q C Γ hs ts →
      StrHeadsTyped P B Q C Γ (h :: hs) (.fn [name] [t] (.base .string) Eff.empty :: ts)

theorem StrHeadsTyped.rename {hs ts Δ ξ} (h : StrHeadsTyped P B Q C Γ hs ts)
    (hr : RenOk Γ Δ ξ) : StrHeadsTyped P B Q C Δ (hs.map (CallHead.rename ξ)) ts := by
  induction h with
  | nil => exact .nil
  | cons hh _ ih => exact .cons (hh.rename hr) ih

theorem directHeads_typed {p : Program} {op C Γ R fs ts ε δ}
    (h : HasTypesQ (p.declarationsFor view) B op Q C Γ R fs ts ε)
    (hm : CompTypesQ (desugarProgram op p) B Q C Γ R δ (desugarExprs op fs) ts)
    (hd : fs.AllDirect)
    (ht : ∀ t ∈ ts, ∃ a, t = .fn [InterpPart.converterName a] [a] (.base .string) Eff.empty) :
    StrHeadsTyped (desugarProgram op p) B Q C Γ (directHeads fs) ts := by
  match h with
  | .nil => exact .nil
  | .cons (a := t) hf hfs =>
      cases hm with
      | cons hm hms =>
          obtain ⟨a, rfl⟩ := ht t (by simp)
          obtain ⟨head, hh⟩ := hd.1
          simp only [directHeads, hh, Option.getD_some]
          exact .cons (directCallee_typed hh hf hm)
            (directHeads_typed hfs hms hd.2 (fun t hm => ht t (by simp [hm])))

theorem converterTypes_fn (parts : List InterpPart) :
    ∀ t ∈ InterpPart.converterTypes parts, ∃ a, t = .fn [InterpPart.converterName a] [a] (.base .string) Eff.empty := by
  induction parts with
  | nil => simp [InterpPart.converterTypes]
  | cons p ps ih =>
      cases p <;> simp only [InterpPart.converterTypes]
      · exact ih
      · exact ih
      · intro t ht; rcases List.mem_cons.mp ht with rfl | ht
        · exact ⟨_, rfl⟩
        · exact ih t ht

theorem stringAdd_typed {op R v w} (hsig : ∀ b s, B.sig b = some s → s.Scoped) (h : StringAddOk B op C)
    (hv : HasTypeVQ P B StoreTy.empty Q C Γ v (.base .string))
    (hw : HasTypeVQ P B StoreTy.empty Q C Γ w (.base .string)) :
    ∃ b ts, op (.binary .add) (.base .string) = some (b, ts) ∧
      HasTypeCQ P B StoreTy.empty Q C Γ R (.app (.prim b ts []) [v,w]) (.base .string) Eff.empty := by
  obtain ⟨b, ts, s, hop, hts, hs, ht, he, ha, hfn⟩ := h
  refine ⟨b, ts, hop, HasTypeCQ.C_App (names := ["left", "right"]) ?_ (.cons hv (.cons hw .nil))⟩
  have hn : NamesWF s.names s.params := by
    have hf := hfn
    rw [fnTy_eq] at hf
    have heq := Ty.fn.inj hf
    refine ⟨?_, ?_⟩
    · have hp := congrArg List.length heq.2.1
      rw [List.length_map] at hp
      rw [heq.1]
      exact hp.symm
    · rw [heq.1]
      decide
  rw [← hfn]
  apply HasTypeVQ.V_Prim hs hn
  subst ts
  exact PrimitiveAdmissible.of_noRows (hsig _ _ hs) he ht ha (by simp)

theorem joinStringFrom_typed {op R left rest depth} (hsig : ∀ b s, B.sig b = some s → s.Scoped) (xs : List (Option Ty))
    (hd : xs.length = depth)
    (hv : HasTypeVQ P B StoreTy.empty Q C (xs ++ Γ) left (.base .string))
    (hr : HasTypeEachQ P B StoreTy.empty Q C Γ rest (.base .string))
    (ha : rest ≠ [] → StringAddOk B op C) :
    HasTypeCQ P B StoreTy.empty Q C (xs ++ Γ) R (joinStringFrom op depth left rest)
      (.base .string) Eff.empty := by
  match hr with
  | .nil => exact .C_Return hv
  | .cons (vs := rest) hw hrs =>
      obtain ⟨b, ts, hop, happ⟩ := stringAdd_typed (R := R) hsig (ha (by simp)) hv
        (by simpa only [hd] using hw.rename (RenOk.shift xs Γ))
      cases rest with
      | nil => simpa only [joinStringFrom, hop] using happ
      | cons w rest =>
          simp only [joinStringFrom, hop]
          apply HasTypeCQ.C_Let happ
          simpa only [joinStringFrom, hop, List.cons_append] using joinStringFrom_typed (R := R) (depth := depth + 1) hsig (some (.base .string) :: xs) (by simp [hd])
            (.V_Var (i := 0) rfl (by intro _ _ _ he; cases he)) hrs (fun _ => ha (by simp))

theorem joinStringParts_typed {op R vs} (hsig : ∀ b s, B.sig b = some s → s.Scoped)
    (hv : HasTypeEachQ P B StoreTy.empty Q C Γ vs (.base .string))
    (ha : 2 ≤ vs.length → StringAddOk B op C) :
    HasTypeCQ P B StoreTy.empty Q C Γ R (joinStringParts op vs) (.base .string) Eff.empty := by
  cases hv with
  | nil => exact .C_Return .V_Const
  | cons hv hrs =>
      apply joinStringFrom_typed hsig [] rfl hv hrs
      intro hn; apply ha
      have : 0 < List.length _ := List.length_pos_iff.mpr hn
      simp only [List.length_cons]; omega

theorem HasTypeEachQ.append {vs ws a}
    (hv : HasTypeEachQ P B StoreTy.empty Q C Γ vs a)
    (hw : HasTypeEachQ P B StoreTy.empty Q C Γ ws a) :
    HasTypeEachQ P B StoreTy.empty Q C Γ (vs ++ ws) a := by
  match hv with
  | .nil => exact hw
  | .cons h hs => exact .cons h (HasTypeEachQ.append hs hw)

theorem interpolate_typed {op R parts vs hs acc} (hsig : ∀ b s, B.sig b = some s → s.Scoped)
    (hv : HasTypeVsQ P B StoreTy.empty Q C Γ vs (InterpPart.exprTypes parts))
    (hh : StrHeadsTyped P B Q C Γ hs (InterpPart.converterTypes parts))
    (hc : HasTypeEachQ P B StoreTy.empty Q C Γ acc (.base .string))
    (ha : 2 ≤ acc.length + InterpPart.count parts → StringAddOk B op C) :
    HasTypeCQ P B StoreTy.empty Q C Γ R (interpolate op parts vs hs acc) (.base .string) Eff.empty := by
  induction parts generalizing Γ vs hs acc with
  | nil => exact joinStringParts_typed hsig hc (by simpa [InterpPart.count] using ha)
  | cons p ps ih =>
      cases p with
      | text s =>
          simp only [interpolate]
          split
          · rename_i he; exact ih hv hh hc (by simpa [InterpPart.count, he] using ha)
          · rename_i he
            apply ih hv hh (HasTypeEachQ.append hc (.cons .V_Const .nil))
            simpa [InterpPart.count, he, List.length_append, Nat.add_assoc] using ha
      | stringExpr =>
          cases hv with
          | cons hv hvs =>
              exact ih hvs hh (HasTypeEachQ.append hc (.cons hv .nil))
                (by simpa [InterpPart.count, List.length_append, Nat.add_assoc] using ha)
      | converted t =>
          cases hv with
          | cons hv hvs =>
              cases hh with
              | cons hh hhs =>
                  apply HasTypeCQ.C_Let (hh.apply (.cons hv .nil))
                  apply ih (hvs.rename (RenOk.shift [some (.base .string)] Γ))
                    (hhs.rename (RenOk.shift [some (.base .string)] Γ))
                    (HasTypeEachQ.append (hc.rename (RenOk.shift [some (.base .string)] Γ))
                      (.cons (.V_Var rfl (by intro _ _ _ he; cases he)) .nil))
                  simpa [InterpPart.count, List.length_append, Val.renameList_length,
                    Nat.add_assoc] using ha

end Benitoite.Surface
