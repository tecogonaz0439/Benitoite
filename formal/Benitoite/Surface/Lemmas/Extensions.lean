import Benitoite.Surface.Lemmas.CallHead

/-! C6a-1 の追加の let と、並行した断片・式・呼ぶ値の型付け。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {P : Release.Program} {B : Builtins} {C : List TParam} {Γ : List (Option Ty)}

theorem CompTypes.append {R ε ms ns as bs} (h : CompTypes P B C Γ R ε ms as)
    (hn : CompTypes P B C Γ R ε ns bs) : CompTypes P B C Γ R ε (ms ++ ns) (as ++ bs) := by
  induction h with
  | nil => exact hn
  | cons hm _ ih => exact .cons hm ih

theorem replicate_clean {n a} (ha : TyOK n a) (k : Nat) :
    Ty.VarsInList n (fun _ => True) (List.replicate k a) := by
  induction k with
  | zero => trivial
  | succ k ih => exact ⟨ha, ih⟩

theorem HasTypeVs.takeDrop {vs as} (h : HasTypeVs P B StoreTy.empty C Γ vs as) (n : Nat) :
    HasTypeVs P B StoreTy.empty C Γ (vs.take n) (as.take n) ∧
      HasTypeVs P B StoreTy.empty C Γ (vs.drop n) (as.drop n) := by
  induction n generalizing vs as with
  | zero => exact ⟨.nil, h⟩
  | succ n ih =>
      cases h with
      | nil => exact ⟨.nil, .nil⟩
      | cons hv ht => exact ⟨.cons hv (ih ht).1, (ih ht).2⟩

theorem spreadFinish_typed {R h before s after a}
    (hh : CallHead.HasType P B C Γ h [.list a, .list a] (.list a) Eff.empty)
    (hb : HasTypeEach P B StoreTy.empty C Γ before a)
    (hs : HasTypeV P B StoreTy.empty C Γ s (.list a))
    (ha : HasTypeEach P B StoreTy.empty C Γ after a) (hw : Ty.WF C.length a) :
    HasTypeC P B StoreTy.empty C Γ R (spreadFinish h before s after) (.list a) Eff.empty := by
  cases before <;> cases after <;> simp only [spreadFinish]
  · exact .C_Return hs
  · exact hh.apply (.cons hs (.cons (.V_List ha hw) .nil))
  · exact hh.apply (.cons (.V_List hb hw) (.cons hs .nil))
  · apply HasTypeC.C_Let (hh.apply (.cons (.V_List hb hw) (.cons hs .nil)))
    exact (hh.rename (RenOk.shift [some (.list a)] Γ)).apply
      (.cons (.V_Var rfl (by intro _ _ _ he; cases he))
        (.cons (.V_List (ha.rename (RenOk.shift [some (.list a)] Γ)) hw) .nil))

theorem spreadValues_typed {R h vs a n k}
    (hh : CallHead.HasType P B C Γ h [.list a, .list a] (.list a) Eff.empty)
    (hv : HasTypeVs P B StoreTy.empty C Γ vs
      (List.replicate n a ++ .list a :: List.replicate k a)) (hw : Ty.WF C.length a) :
    HasTypeC P B StoreTy.empty C Γ R (spreadValues h n vs) (.list a) Eff.empty := by
  obtain ⟨hb, hs⟩ := HasTypeVs.takeDrop hv n
  simp only [List.take_append, List.drop_append, List.length_replicate,
    List.take_replicate, Nat.min_self, Nat.sub_self, List.take_zero, List.append_nil,
    List.drop_replicate, List.replicate_zero, List.nil_append, List.drop_zero] at hb hs
  unfold spreadValues
  generalize he : vs.drop n = ss at hs ⊢
  cases hs with
  | cons hv hs =>
      exact spreadFinish_typed hh (HasTypeVs.each hb (fun _ hm => List.eq_of_mem_replicate hm)) hv
        (HasTypeVs.each hs (fun _ hm => List.eq_of_mem_replicate hm)) hw

/-- converterTypes で指定した直接の頭の列。 -/
inductive StrHeadsTyped (P : Release.Program) (B : Builtins) (C : List TParam)
    (Γ : List (Option Ty)) : List CallHead → List Ty → Prop
  | nil : StrHeadsTyped P B C Γ [] []
  | cons {h hs t ts} : CallHead.HasType P B C Γ h [t] (.base .string) Eff.empty →
      StrHeadsTyped P B C Γ hs ts →
      StrHeadsTyped P B C Γ (h :: hs) (.fn [t] (.base .string) Eff.empty :: ts)

theorem StrHeadsTyped.rename {hs ts Δ ξ} (h : StrHeadsTyped P B C Γ hs ts)
    (hr : RenOk Γ Δ ξ) : StrHeadsTyped P B C Δ (hs.map (CallHead.rename ξ)) ts := by
  induction h with
  | nil => exact .nil
  | cons hh _ ih => exact .cons (hh.rename hr) ih

theorem directHeads_typed {p : Program} {op C Γ R fs ts ε δ}
    (h : HasTypes p.declarations B op C Γ R fs ts ε)
    (hm : CompTypes (desugarProgram op p) B C Γ R δ (desugarExprs op fs) ts)
    (hd : fs.AllDirect)
    (ht : ∀ t ∈ ts, ∃ a, t = .fn [a] (.base .string) Eff.empty) :
    StrHeadsTyped (desugarProgram op p) B C Γ (directHeads fs) ts := by
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
    ∀ t ∈ InterpPart.converterTypes parts, ∃ a, t = .fn [a] (.base .string) Eff.empty := by
  induction parts with
  | nil => simp [InterpPart.converterTypes]
  | cons p ps ih =>
      cases p <;> simp only [InterpPart.converterTypes]
      · exact ih
      · exact ih
      · intro t ht; rcases List.mem_cons.mp ht with rfl | ht
        · exact ⟨_, rfl⟩
        · exact ih t ht

theorem stringAdd_typed {op R v w} (h : StringAddOk B op C)
    (hv : HasTypeV P B StoreTy.empty C Γ v (.base .string))
    (hw : HasTypeV P B StoreTy.empty C Γ w (.base .string)) :
    ∃ b ts, op (.binary .add) (.base .string) = some (b, ts) ∧
      HasTypeC P B StoreTy.empty C Γ R (.app (.prim b ts []) [v,w]) (.base .string) Eff.empty := by
  obtain ⟨b, ts, s, hop, _, hs, ht, he, ha, hfn⟩ := h
  refine ⟨b, ts, hop, HasTypeC.C_App ?_ (.cons hv (.cons hw .nil))⟩
  rw [← hfn]; exact .V_Prim hs ht (by simpa using he.symm) ha

theorem joinStringFrom_typed {op R left rest depth} (xs : List (Option Ty))
    (hd : xs.length = depth)
    (hv : HasTypeV P B StoreTy.empty C (xs ++ Γ) left (.base .string))
    (hr : HasTypeEach P B StoreTy.empty C Γ rest (.base .string))
    (ha : rest ≠ [] → StringAddOk B op C) :
    HasTypeC P B StoreTy.empty C (xs ++ Γ) R (joinStringFrom op depth left rest)
      (.base .string) Eff.empty := by
  match hr with
  | .nil => exact .C_Return hv
  | .cons (vs := rest) hw hrs =>
      obtain ⟨b, ts, hop, happ⟩ := stringAdd_typed (R := R) (ha (by simp)) hv
        (by simpa only [hd] using hw.rename (RenOk.shift xs Γ))
      cases rest with
      | nil => simpa only [joinStringFrom, hop] using happ
      | cons w rest =>
          simp only [joinStringFrom, hop]
          apply HasTypeC.C_Let happ
          simpa only [joinStringFrom, hop, List.cons_append] using joinStringFrom_typed (R := R) (depth := depth + 1) (some (.base .string) :: xs) (by simp [hd])
            (.V_Var (i := 0) rfl (by intro _ _ _ he; cases he)) hrs (fun _ => ha (by simp))

theorem joinStringParts_typed {op R vs}
    (hv : HasTypeEach P B StoreTy.empty C Γ vs (.base .string))
    (ha : 2 ≤ vs.length → StringAddOk B op C) :
    HasTypeC P B StoreTy.empty C Γ R (joinStringParts op vs) (.base .string) Eff.empty := by
  cases hv with
  | nil => exact .C_Return .V_Const
  | cons hv hrs =>
      apply joinStringFrom_typed [] rfl hv hrs
      intro hn; apply ha
      have : 0 < List.length _ := List.length_pos_iff.mpr hn
      simp only [List.length_cons]; omega

theorem HasTypeEach.append {vs ws a}
    (hv : HasTypeEach P B StoreTy.empty C Γ vs a)
    (hw : HasTypeEach P B StoreTy.empty C Γ ws a) :
    HasTypeEach P B StoreTy.empty C Γ (vs ++ ws) a := by
  match hv with
  | .nil => exact hw
  | .cons h hs => exact .cons h (HasTypeEach.append hs hw)

theorem interpolate_typed {op R parts vs hs acc}
    (hv : HasTypeVs P B StoreTy.empty C Γ vs (InterpPart.exprTypes parts))
    (hh : StrHeadsTyped P B C Γ hs (InterpPart.converterTypes parts))
    (hc : HasTypeEach P B StoreTy.empty C Γ acc (.base .string))
    (ha : 2 ≤ acc.length + InterpPart.count parts → StringAddOk B op C) :
    HasTypeC P B StoreTy.empty C Γ R (interpolate op parts vs hs acc) (.base .string) Eff.empty := by
  induction parts generalizing Γ vs hs acc with
  | nil => exact joinStringParts_typed hc (by simpa [InterpPart.count] using ha)
  | cons p ps ih =>
      cases p with
      | text s =>
          simp only [interpolate]
          split
          · rename_i he; exact ih hv hh hc (by simpa [InterpPart.count, he] using ha)
          · rename_i he
            apply ih hv hh (HasTypeEach.append hc (.cons .V_Const .nil))
            simpa [InterpPart.count, he, List.length_append, Nat.add_assoc] using ha
      | stringExpr =>
          cases hv with
          | cons hv hvs =>
              exact ih hvs hh (HasTypeEach.append hc (.cons hv .nil))
                (by simpa [InterpPart.count, List.length_append, Nat.add_assoc] using ha)
      | converted t =>
          cases hv with
          | cons hv hvs =>
              cases hh with
              | cons hh hhs =>
                  apply HasTypeC.C_Let (hh.apply (.cons hv .nil))
                  apply ih (hvs.rename (RenOk.shift [some (.base .string)] Γ))
                    (hhs.rename (RenOk.shift [some (.base .string)] Γ))
                    (HasTypeEach.append (hc.rename (RenOk.shift [some (.base .string)] Γ))
                      (.cons (.V_Var rfl (by intro _ _ _ he; cases he)) .nil))
                  simpa [InterpPart.count, List.length_append, Val.renameList_length,
                    Nat.add_assoc] using ha

end Benitoite.Surface
