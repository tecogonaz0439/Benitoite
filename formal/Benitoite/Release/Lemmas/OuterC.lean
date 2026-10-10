import Benitoite.Release.Lemmas.Regularity

/-!
# 外側の型パラメータの並びを加える弱化（段階 B）

型パラメータの並び `C1` の型の変数だけを使う項は、`C1` の外側に型パラメータの並び `C0` を加えても、
同じ型が付く。閉じた値（`C1 = []`）が、どの型パラメータの並びのもとでも型が付くことに使う。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

theorem SatAll.local (hb : B.Assumptions P) {C1 C0 : List TParam} {ts tps}
    (hts : ∀ t ∈ ts, Ty.WF C1.length t) (h : SatAll B C1 ts tps) : SatAll B (C1 ++ C0) ts tps :=
  ⟨h.1, fun i t p hi hp => hb.sat_local _ _ _ _ (hts _ (List.mem_of_getElem? hi)) (h.2 i t p hi hp)⟩

mutual
  theorem HasTypeV.outer (hb : B.Assumptions P) {Ψ C1 C0 Γ v a} (h : HasTypeV P B Ψ C1 Γ v a)
      (hv : Val.VarsIn C1.length (fun _ => True) v) : HasTypeV P B Ψ (C1 ++ C0) Γ v a := by
    match h with
    | .V_Var hi hc => exact .V_Var hi hc
    | .V_Const => exact .V_Const
    | .V_Fun hd hts hes =>
        simp only [Val.VarsIn] at hv
        exact .V_Fun hd (hts.local hb (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv.1))) hes
    | .V_Prim hs hts hes had =>
        simp only [Val.VarsIn] at hv
        exact .V_Prim hs hts hes
          (hb.admits_local _ _ _ _ _ hs (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv.1)) had)
    | .V_Op hod hts =>
        simp only [Val.VarsIn] at hv
        exact .V_Op hod (hts.local hb (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv)))
    | .V_Lam hbody =>
        simp only [Val.VarsIn] at hv
        exact .V_Lam (HasTypeC.outer hb hbody hv.2)
    | .V_Con hc hts hargs =>
        simp only [Val.VarsIn] at hv
        exact .V_Con hc hts (HasTypeVs.outer hb hargs hv.2)
    | .V_List he hw =>
        simp only [Val.VarsIn] at hv
        exact .V_List (HasTypeEach.outer hb he hv) (Ty.WF.mono (by simp) _ hw)
    | .V_LocRef hl => exact .V_LocRef hl
    | .V_LocLazy hl => exact .V_LocLazy hl
    | .V_Map hk hvs hl hkey hwa hwb =>
        simp only [Val.VarsIn] at hv
        exact .V_Map (HasTypeEach.outer hb hk hv.1) (HasTypeEach.outer hb hvs hv.2) hl
          (hb.sat_local _ _ _ _ hwa hkey) (Ty.WF.mono (by simp) _ hwa) (Ty.WF.mono (by simp) _ hwb)
    | .V_Set he hkey hw =>
        simp only [Val.VarsIn] at hv
        exact .V_Set (HasTypeEach.outer hb he hv) (hb.sat_local _ _ _ _ hw hkey) (Ty.WF.mono (by simp) _ hw)
    | .V_Bytes => exact .V_Bytes
    | .V_Dict hi hts hvs =>
        simp only [Val.VarsIn] at hv
        exact .V_Dict hi (hts.local hb (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv.1))) (HasTypeVs.outer hb hvs hv.2)
    | .V_Super hv' hc hs =>
        simp only [Val.VarsIn] at hv
        exact .V_Super (HasTypeV.outer hb hv' hv) hc hs
    | .V_Sub h hle => exact .V_Sub (HasTypeV.outer hb h hv) hle

  theorem HasTypeVs.outer (hb : B.Assumptions P) {Ψ C1 C0 Γ vs as} (h : HasTypeVs P B Ψ C1 Γ vs as)
      (hv : Val.VarsInList C1.length (fun _ => True) vs) : HasTypeVs P B Ψ (C1 ++ C0) Γ vs as := by
    match h with
    | .nil => exact .nil
    | .cons hx hxs =>
        simp only [Val.VarsInList] at hv
        exact .cons (HasTypeV.outer hb hx hv.1) (HasTypeVs.outer hb hxs hv.2)

  theorem HasTypeEach.outer (hb : B.Assumptions P) {Ψ C1 C0 Γ vs a} (h : HasTypeEach P B Ψ C1 Γ vs a)
      (hv : Val.VarsInList C1.length (fun _ => True) vs) : HasTypeEach P B Ψ (C1 ++ C0) Γ vs a := by
    match h with
    | .nil => exact .nil
    | .cons hx hxs =>
        simp only [Val.VarsInList] at hv
        exact .cons (HasTypeV.outer hb hx hv.1) (HasTypeEach.outer hb hxs hv.2)

  theorem HasTypeC.outer (hb : B.Assumptions P) {Ψ C1 C0 Γ R m a ε} (h : HasTypeC P B Ψ C1 Γ R m a ε)
      (hm : Comp.VarsIn C1.length (fun _ => True) m) : HasTypeC P B Ψ (C1 ++ C0) Γ R m a ε := by
    match h with
    | .C_Return hv => simp only [Comp.VarsIn] at hm; exact .C_Return (HasTypeV.outer hb hv hm)
    | .C_Sub h hle hs => exact .C_Sub (HasTypeC.outer hb h hm) hle hs
    | .C_Let hm' hn =>
        simp only [Comp.VarsIn] at hm
        exact .C_Let (HasTypeC.outer hb hm' hm.1) (HasTypeC.outer hb hn hm.2)
    | .C_App hf hargs =>
        simp only [Comp.VarsIn] at hm
        exact .C_App (HasTypeV.outer hb hf hm.1) (HasTypeVs.outer hb hargs hm.2)
    | .C_If hv h1 h2 =>
        simp only [Comp.VarsIn] at hm
        exact .C_If (HasTypeV.outer hb hv hm.1) (HasTypeC.outer hb h1 hm.2.1) (HasTypeC.outer hb h2 hm.2.2)
    | .C_Match hv harms hex =>
        simp only [Comp.VarsIn] at hm
        exact .C_Match (HasTypeV.outer hb hv hm.1) (HasTypeArms.outer hb harms hm.2) hex
    | .C_Lazy hm' => simp only [Comp.VarsIn] at hm; exact .C_Lazy (HasTypeC.outer hb hm' hm)
    | .C_Escape hv hw =>
        simp only [Comp.VarsIn] at hm
        exact .C_Escape (HasTypeV.outer hb hv hm) (Ty.WF.mono (by simp) _ hw)
    | .C_Use hv hr hm' hs =>
        simp only [Comp.VarsIn] at hm
        exact .C_Use (HasTypeV.outer hb hv hm.1) hr (HasTypeC.outer hb hm' hm.2) hs
    | .C_Handle hm' hs hc =>
        simp only [Comp.VarsIn] at hm
        exact .C_Handle (HasTypeC.outer hb hm' hm.1) hs (HasTypeClauses.outer hb hc hm.2)
    | .C_Resume hi hv =>
        simp only [Comp.VarsIn] at hm
        exact .C_Resume hi (HasTypeV.outer hb hv hm.2)
    | .C_ResumeL hl hv =>
        simp only [Comp.VarsIn] at hm
        exact .C_ResumeL hl (HasTypeV.outer hb hv hm.2)
    | .C_Meth hv hc hmeth hts hes hws =>
        simp only [Comp.VarsIn] at hm
        exact .C_Meth (HasTypeV.outer hb hv hm.1) hc hmeth
          (hts.local hb (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hm.2.1))) hes (HasTypeVs.outer hb hws hm.2.2.2)

  theorem HasTypeArms.outer (hb : B.Assumptions P) {Ψ C1 C0 Γ R arms a b ε}
      (h : HasTypeArms P B Ψ C1 Γ R arms a b ε) (hm : Arm.VarsInList C1.length (fun _ => True) arms) :
      HasTypeArms P B Ψ (C1 ++ C0) Γ R arms a b ε := by
    match h with
    | .nil hw => exact .nil (Ty.WF.mono (by simp) _ hw)
    | .plain hp hbody hrest =>
        simp only [Arm.VarsInList] at hm
        exact .plain hp (HasTypeC.outer hb hbody hm.1) (HasTypeArms.outer hb hrest hm.2)
    | .guarded hp hg hbody hrest =>
        simp only [Arm.VarsInList] at hm
        exact .guarded hp (HasTypeC.outer hb hg hm.1) (HasTypeC.outer hb hbody hm.2.1)
          (HasTypeArms.outer hb hrest hm.2.2)

  theorem HasTypeClauses.outer (hb : B.Assumptions P) {Ψ C1 C0 Γ R h t ε}
      (hc : HasTypeClauses P B Ψ C1 Γ R h t ε) (hm : Clause.VarsInList C1.length (fun _ => True) h) :
      HasTypeClauses P B Ψ (C1 ++ C0) Γ R h t ε := by
    match hc with
    | .cons (sg := sg) hsg hn hk hbody hrest =>
        simp only [Clause.VarsInList] at hm
        refine .cons hsg hn hk ?_ (HasTypeClauses.outer hb hrest hm.2)
        have := HasTypeC.outer (C0 := C0) hb hbody (by
          simp only [List.length_append]; rw [hk] at hm; simpa [Nat.add_comm] using hm.1)
        simpa [List.append_assoc] using this
    | .nil => exact .nil
end

end Benitoite.Release
