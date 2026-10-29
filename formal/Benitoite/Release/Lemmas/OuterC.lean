import Benitoite.Release.Lemmas.Regularity

/-!
# 外側の型パラメータの並びを加える弱化（契約名を持つコア）

型パラメータの並び `C1` の型の変数だけを使う項は、`C1` の外側に型パラメータの並び `C0` を加えても、
同じ型が付く。閉じた値（`C1 = []`）が、どの型パラメータの並びのもとでも型が付くことに使う。

型パラメータの範囲の弱化は契約名を変更せず、型付けの名前の整形式を保持する
（設計書 01-12「型付け規則」）。
-/

namespace Benitoite.Release

variable {Q : NoFailCtx}


variable {P : Program} {B : Builtins}

theorem SatAll.local (hb : B.CoreAssumptions P) {C1 C0 : List TParam} {ts tps}
    (hts : ∀ t ∈ ts, Ty.WF 0 C1.length t) (h : SatAll B C1 ts tps) : SatAll B (C1 ++ C0) ts tps :=
  ⟨h.1, fun i t p hi hp => hb.sat_local _ _ _ _ (hts _ (List.mem_of_getElem? hi)) (h.2 i t p hi hp)⟩


theorem Admissible.outer (hb : B.CoreAssumptions P) {C1 C0 tps ne Qs Qt ts es e}
    (h : Admissible B C1 tps ne Qs Qt ts es e) :
    Admissible B (C1 ++ C0) tps ne Qs Qt ts es e :=
  { h with
    types := h.types.local hb (fun t ht => (h.typeScope t ht).1)
    typeScope := fun t ht => ⟨Ty.WF.mono (by simp) t (h.typeScope t ht).1, (h.typeScope t ht).2⟩
    rowScope := fun f hf => Eff.WF.mono (by simp) f (h.rowScope f hf) }

theorem PrimitiveAdmissible.outer (hb : B.CoreAssumptions P) {C1 C0 b s rs Q ts es}
    (hs : B.sig b = some s) (h : PrimitiveAdmissible C1 (s.inst rs) Q ts es) :
    PrimitiveAdmissible (C1 ++ C0) (s.inst rs) Q ts es :=
  { h with
    admits := hb.admits_local _ s _ _ _ hs (fun t ht => (h.typeScope t ht).1) h.admits
    typeScope := fun t ht => ⟨Ty.WF.mono (by simp) t (h.typeScope t ht).1, (h.typeScope t ht).2⟩
    rowScope := fun f hf => Eff.WF.mono (by simp) f (h.rowScope f hf) }

theorem MethodRowsAdmissible.outer {C1 C0 Q ms es}
    (h : MethodRowsAdmissible C1 Q ms es) : MethodRowsAdmissible (C1 ++ C0) Q ms es :=
  ⟨h.1, fun f hf => Eff.WF.mono (by simp) f (h.2.1 f hf), h.2.2⟩

mutual
  theorem HasTypeVQ.outer {depth : Nat} (hb : B.CoreAssumptions P) {Ψ C1 C0 Γ v a} (h : HasTypeVQ P B Ψ Q C1 Γ v a)
      (hv : Val.VarsIn C1.length (fun _ => True) v depth) : HasTypeVQ P B Ψ Q (C1 ++ C0) Γ v a := by
    match h with
    | .V_Var hi hc => exact .V_Var hi hc
    | .V_Const => exact .V_Const
    | .V_Fun hd hnames had => exact .V_Fun hd hnames (had.outer hb)
    | .V_Prim hs hrs hnames had => exact .V_Prim hs hrs hnames (had.outer hb hs)
    | .V_Op hod hnames hts =>
        simp only [Val.VarsIn] at hv
        exact .V_Op hod hnames (hts.local hb (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv)))
    | .V_Raise ht he => exact .V_Raise (Ty.WF.mono (by simp) _ ht) (Ty.WF.mono (by simp) _ he)
    | .V_Lam hnames hw hbody =>
        simp only [Val.VarsIn] at hv
        exact .V_Lam hnames (Ty.WF.mono (by simp) _ hw) (HasTypeCQ.outer (depth := _) hb hbody hv.2.2)
    | .V_Con hc hts hargs =>
        simp only [Val.VarsIn] at hv
        exact .V_Con hc hts (HasTypeVsQ.outer (depth := _) hb hargs hv.2)
    | .V_List he hw =>
        simp only [Val.VarsIn] at hv
        exact .V_List (HasTypeEachQ.outer (depth := _) hb he hv) (Ty.WF.mono (by simp) _ hw)
    | .V_LocRef hl => exact .V_LocRef hl
    | .V_LocLazy hl => exact .V_LocLazy hl
    | .V_Map hk hvs hl hkey hwa hwb =>
        simp only [Val.VarsIn] at hv
        exact .V_Map (HasTypeEachQ.outer (depth := _) hb hk hv.1) (HasTypeEachQ.outer (depth := _) hb hvs hv.2) hl
          (hb.sat_local _ _ _ _ hwa hkey) (Ty.WF.mono (by simp) _ hwa) (Ty.WF.mono (by simp) _ hwb)
    | .V_Set he hkey hw =>
        simp only [Val.VarsIn] at hv
        exact .V_Set (HasTypeEachQ.outer (depth := _) hb he hv) (hb.sat_local _ _ _ _ hw hkey) (Ty.WF.mono (by simp) _ hw)
    | .V_Bytes => exact .V_Bytes
    | .V_Dict hi hts hvs =>
        simp only [Val.VarsIn] at hv
        exact .V_Dict hi (hts.local hb (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv.1))) (HasTypeVsQ.outer (depth := _) hb hvs hv.2)
    | .V_Super hv' hc hs =>
        simp only [Val.VarsIn] at hv
        exact .V_Super (HasTypeVQ.outer (depth := _) hb hv' hv) hc hs
    | .V_Sub h hle hw => exact .V_Sub (HasTypeVQ.outer (depth := _) hb h hv) hle (Ty.WF.mono (by simp) _ hw)
    | .V_Checked hk hm => exact .V_Checked hk hm
    | .V_CheckedRequest hk hm hc ht => exact .V_CheckedRequest hk hm hc ht

  theorem HasTypeVsQ.outer {depth : Nat} (hb : B.CoreAssumptions P) {Ψ C1 C0 Γ vs as} (h : HasTypeVsQ P B Ψ Q C1 Γ vs as)
      (hv : Val.VarsInList C1.length (fun _ => True) vs depth) : HasTypeVsQ P B Ψ Q (C1 ++ C0) Γ vs as := by
    match h with
    | .nil => exact .nil
    | .cons hx hxs =>
        simp only [Val.VarsInList] at hv
        exact .cons (HasTypeVQ.outer (depth := _) hb hx hv.1) (HasTypeVsQ.outer (depth := _) hb hxs hv.2)

  theorem HasTypeEachQ.outer {depth : Nat} (hb : B.CoreAssumptions P) {Ψ C1 C0 Γ vs a} (h : HasTypeEachQ P B Ψ Q C1 Γ vs a)
      (hv : Val.VarsInList C1.length (fun _ => True) vs depth) : HasTypeEachQ P B Ψ Q (C1 ++ C0) Γ vs a := by
    match h with
    | .nil => exact .nil
    | .cons hx hxs =>
        simp only [Val.VarsInList] at hv
        exact .cons (HasTypeVQ.outer (depth := _) hb hx hv.1) (HasTypeEachQ.outer (depth := _) hb hxs hv.2)

  theorem HasTypeCQ.outer {Δl : LocalCtx} {depth : Nat} (hb : B.CoreAssumptions P) {Ψ C1 C0 Γ R m a ε} (h : HasTypeCQ P B Ψ Q C1 Γ R m a ε Δl)
      (hm : Comp.VarsIn C1.length (fun _ => True) m depth) : HasTypeCQ P B Ψ Q (C1 ++ C0) Γ R m a ε Δl := by
    match h with
    | .C_BuilderLet hw hbody =>
        exact .C_BuilderLet (Ty.WF.mono (by simp) _ hw)
          (HasTypeCQ.outer (depth := depth + 1) hb hbody hm.2)
    | .C_BuilderOp hw hr ha =>
        exact .C_BuilderOp (Ty.WF.mono (by simp) _ hw) hr
          (HasTypeVsQ.outer (depth := depth) hb ha hm.2.2)
    | .C_Return hv => simp only [Comp.VarsIn] at hm; exact .C_Return (HasTypeVQ.outer (depth := _) hb hv hm)
    | .C_Sub h hle hs hw => exact .C_Sub (HasTypeCQ.outer (depth := _) hb h hm) hle hs (Ty.WF.mono (by simp) _ hw)
    | .C_Eff h hs => exact .C_Eff (HasTypeCQ.outer (depth := _) hb h hm) hs
    | .C_Let hm' hn =>
        simp only [Comp.VarsIn] at hm
        exact .C_Let (HasTypeCQ.outer (depth := _) hb hm' hm.1) (HasTypeCQ.outer (depth := _) hb hn hm.2)
    | .C_App hf hargs =>
        simp only [Comp.VarsIn] at hm
        exact .C_App (HasTypeVQ.outer (depth := _) hb hf hm.1) (HasTypeVsQ.outer (depth := _) hb hargs hm.2)
    | .C_If hv h1 h2 =>
        simp only [Comp.VarsIn] at hm
        exact .C_If (HasTypeVQ.outer (depth := _) hb hv hm.1) (HasTypeCQ.outer (depth := _) hb h1 hm.2.1) (HasTypeCQ.outer (depth := _) hb h2 hm.2.2)
    | .C_Match hv harms hex =>
        simp only [Comp.VarsIn] at hm
        exact .C_Match (HasTypeVQ.outer (depth := _) hb hv hm.1) (HasTypeArmsQ.outer (depth := _) hb harms hm.2) hex
    | .C_Lazy hm' => simp only [Comp.VarsIn] at hm; exact .C_Lazy (HasTypeCQ.outer (depth := _) hb hm' hm)
    | .C_Escape hv hw =>
        simp only [Comp.VarsIn] at hm
        exact .C_Escape (HasTypeVQ.outer (depth := _) hb hv hm) (Ty.WF.mono (by simp) _ hw)
    | .C_Use hv hr hm' hs =>
        simp only [Comp.VarsIn] at hm
        exact .C_Use (HasTypeVQ.outer (depth := _) hb hv hm.1) hr (HasTypeCQ.outer (depth := _) hb hm' hm.2) hs
    | .C_Handle hm' hs hc =>
        simp only [Comp.VarsIn] at hm
        exact .C_Handle (HasTypeCQ.outer (depth := _) hb hm' hm.1) hs (HasTypeClausesQ.outer (depth := _) hb hc hm.2)
    | .C_Handle_Fail hm' hs hn hc =>
        exact .C_Handle_Fail (HasTypeCQ.outer (depth := _) hb hm' hm.1) hs hn (HasFailureClause.outer (depth := _) hb hc hm.2)
    | .C_Resume hi hv =>
        simp only [Comp.VarsIn] at hm
        exact .C_Resume hi (HasTypeVQ.outer (depth := _) hb hv hm.2)
    | .C_ResumeL hl hv =>
        simp only [Comp.VarsIn] at hm
        exact .C_ResumeL hl (HasTypeVQ.outer (depth := _) hb hv hm.2)
    | .C_Meth hv hc hmeth hnames hts hscope hes hws =>
        simp only [Comp.VarsIn] at hm
        exact .C_Meth (HasTypeVQ.outer (depth := _) hb hv hm.1) hc hmeth hnames
          (hts.local hb (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hm.2.1)))
          (fun t ht => ⟨Ty.WF.mono (by simp) t (hscope t ht).1, (hscope t ht).2⟩) hes.outer (HasTypeVsQ.outer (depth := _) hb hws hm.2.2.2)

  theorem HasTypeArmsQ.outer {Δl : LocalCtx} {depth : Nat} (hb : B.CoreAssumptions P) {Ψ C1 C0 Γ R arms a b ε}
      (h : HasTypeArmsQ P B Ψ Q C1 Γ R arms a b ε Δl) (hm : Arm.VarsInList C1.length (fun _ => True) arms depth) :
      HasTypeArmsQ P B Ψ Q (C1 ++ C0) Γ R arms a b ε Δl := by
    match h with
    | .nil hw => exact .nil (Ty.WF.mono (by simp) _ hw)
    | .plain hp hbody hrest =>
        simp only [Arm.VarsInList] at hm
        exact .plain hp (HasTypeCQ.outer (depth := _) hb hbody hm.1) (HasTypeArmsQ.outer (depth := _) hb hrest hm.2)
    | .guarded hp hg hbody hrest =>
        simp only [Arm.VarsInList] at hm
        exact .guarded hp (HasTypeCQ.outer (depth := _) hb hg hm.1) (HasTypeCQ.outer (depth := _) hb hbody hm.2.1)
          (HasTypeArmsQ.outer (depth := _) hb hrest hm.2.2)

  theorem HasTypeClausesQ.outer {Δl : LocalCtx} {depth : Nat} (hb : B.CoreAssumptions P) {Ψ C1 C0 Γ R εb h t ε}
      (hc : HasTypeClausesQ P B Ψ Q C1 Γ R εb h t ε Δl) (hm : Clause.VarsInList C1.length (fun _ => True) h depth) :
      HasTypeClausesQ P B Ψ Q (C1 ++ C0) Γ R εb h t ε Δl := by
    match hc with
    | .cons (sg := sg) hsg hnames hn hk hew hbody hrest =>
        simp only [Clause.VarsInList] at hm
        refine .cons hsg hnames hn hk (Eff.WF.mono (by simp) _ hew) ?_ (HasTypeClausesQ.outer (depth := _) hb hrest hm.2)
        have := HasTypeCQ.outer (C0 := C0) hb hbody (by
          simp only [List.length_append]; rw [hk] at hm; simpa [Nat.add_comm] using hm.1)
        simpa [List.append_assoc] using this
    | .nil => exact .nil
  theorem HasFailureClause.outer {Δl : LocalCtx} {depth : Nat} (hb : B.CoreAssumptions P) {Ψ C1 C0 Γ E R h t ε}
      (hc : HasFailureClause P B Ψ Q C1 Γ E R h t ε Δl)
      (hm : Clause.VarsInList C1.length (fun _ => True) h depth) :
      HasFailureClause P B Ψ Q (C1 ++ C0) Γ E R h t ε Δl := by
    match hc with
    | .one he ht hew hbody =>
        refine .one (Ty.WF.mono (by simp) _ he) (Ty.WF.mono (by simp) _ ht)
          (Eff.WF.mono (by simp) _ hew) ?_
        have hv := HasTypeCQ.outer (C0 := C0) hb hbody (by
          simpa only [List.length_cons, Nat.add_comm] using hm.2.1)
        exact hv

end

end Benitoite.Release
