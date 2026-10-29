import Benitoite.Release.Lemmas.Rename
import Benitoite.Release.Admissible

/-! NoFail の文脈を広げる弱化。Q は型付け判断のパラメータである。 -/
namespace Benitoite.Release
variable {P : Program} {B : Builtins} {Q : NoFailCtx}

mutual
  theorem HasTypeVQ.q_mono {Ψ Q' C Γ v a} (h : HasTypeVQ P B Ψ Q C Γ v a) (hq : QLe Q Q') :
      HasTypeVQ P B Ψ Q' C Γ v a := by
    match h with
    | .V_Var hi hc => exact .V_Var hi hc
    | .V_Const => exact .V_Const
    | .V_Fun hd hn had => exact .V_Fun hd hn (had.mono hq)
    | .V_Prim hs hrs hn had => exact .V_Prim hs hrs hn (had.mono hq)
    | .V_Op hod hn hts => exact .V_Op hod hn hts
    | .V_Raise ht he => exact .V_Raise ht he
    | .V_Lam hn hw hb => exact .V_Lam hn hw (HasTypeCQ.q_mono hb hq)
    | .V_Con hc hts hargs => exact .V_Con hc hts (HasTypeVsQ.q_mono hargs hq)
    | .V_List he hw => exact .V_List (HasTypeEachQ.q_mono he hq) hw
    | .V_LocRef hl => exact .V_LocRef hl
    | .V_LocLazy hl => exact .V_LocLazy hl
    | .V_Map hk hv hl hkey hwa hwb =>
        exact .V_Map (HasTypeEachQ.q_mono hk hq) (HasTypeEachQ.q_mono hv hq) hl hkey hwa hwb
    | .V_Set he hkey hw => exact .V_Set (HasTypeEachQ.q_mono he hq) hkey hw
    | .V_Bytes => exact .V_Bytes
    | .V_Dict hi hts hvs => exact .V_Dict hi hts (HasTypeVsQ.q_mono hvs hq)
    | .V_Super hv hc hs => exact .V_Super (HasTypeVQ.q_mono hv hq) hc hs
    | .V_Sub h hle hw => exact .V_Sub (HasTypeVQ.q_mono h hq) hle hw
    | .V_Checked hk hm => exact .V_Checked hk hm
    | .V_CheckedRequest hk hm hc ht => exact .V_CheckedRequest hk hm hc ht

  theorem HasTypeVsQ.q_mono {Ψ Q' C Γ vs as} (h : HasTypeVsQ P B Ψ Q C Γ vs as) (hq : QLe Q Q') :
      HasTypeVsQ P B Ψ Q' C Γ vs as := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeVQ.q_mono hv hq) (HasTypeVsQ.q_mono hvs hq)

  theorem HasTypeEachQ.q_mono {Ψ Q' C Γ vs a} (h : HasTypeEachQ P B Ψ Q C Γ vs a)
      (hq : QLe Q Q') : HasTypeEachQ P B Ψ Q' C Γ vs a := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeVQ.q_mono hv hq) (HasTypeEachQ.q_mono hvs hq)

  theorem HasTypeCQ.q_mono {Δl : LocalCtx} {Ψ Q' C Γ R m a ε} (h : HasTypeCQ P B Ψ Q C Γ R m a ε Δl)
      (hq : QLe Q Q') : HasTypeCQ P B Ψ Q' C Γ R m a ε Δl := by
    match h with
    | .C_BuilderLet hw hb => exact .C_BuilderLet hw (HasTypeCQ.q_mono hb hq)
    | .C_BuilderOp hw hr ha => exact .C_BuilderOp hw hr (HasTypeVsQ.q_mono ha hq)
    | .C_Return hv => exact .C_Return (HasTypeVQ.q_mono hv hq)
    | .C_Sub h hle hs hw => exact .C_Sub (HasTypeCQ.q_mono h hq) hle hs hw
    | .C_Eff h hs => exact .C_Eff (HasTypeCQ.q_mono h hq) hs
    | .C_Let hm hn => exact .C_Let (HasTypeCQ.q_mono hm hq) (HasTypeCQ.q_mono hn hq)
    | .C_App hf hargs => exact .C_App (HasTypeVQ.q_mono hf hq) (HasTypeVsQ.q_mono hargs hq)
    | .C_If hv hm hn =>
        exact .C_If (HasTypeVQ.q_mono hv hq) (HasTypeCQ.q_mono hm hq) (HasTypeCQ.q_mono hn hq)
    | .C_Match hv harms hex => exact .C_Match (HasTypeVQ.q_mono hv hq) (HasTypeArmsQ.q_mono harms hq) hex
    | .C_Lazy hm => exact .C_Lazy (HasTypeCQ.q_mono hm hq)
    | .C_Escape hv hw => exact .C_Escape (HasTypeVQ.q_mono hv hq) hw
    | .C_Use hv hr hm hs => exact .C_Use (HasTypeVQ.q_mono hv hq) hr (HasTypeCQ.q_mono hm hq) hs
    | .C_Handle hm hs hc => exact .C_Handle (HasTypeCQ.q_mono hm hq) hs (HasTypeClausesQ.q_mono hc hq)
    | .C_Handle_Fail hm hs hn hc =>
        exact .C_Handle_Fail (HasTypeCQ.q_mono hm hq) hs (hn.mono hq) (HasFailureClause.q_mono hc hq)
    | .C_Resume hi hv => exact .C_Resume hi (HasTypeVQ.q_mono hv hq)
    | .C_ResumeL hl hv => exact .C_ResumeL hl (HasTypeVQ.q_mono hv hq)
    | .C_Meth hv hc hm hnames hts hscope hes hws =>
        exact .C_Meth (HasTypeVQ.q_mono hv hq) hc hm hnames hts hscope (hes.mono hq) (HasTypeVsQ.q_mono hws hq)

  theorem HasTypeArmsQ.q_mono {Δl : LocalCtx} {Ψ Q' C Γ R arms a b ε} (h : HasTypeArmsQ P B Ψ Q C Γ R arms a b ε Δl)
      (hq : QLe Q Q') : HasTypeArmsQ P B Ψ Q' C Γ R arms a b ε Δl := by
    match h with
    | .nil hw => exact .nil hw
    | .plain hp hm ht => exact .plain hp (HasTypeCQ.q_mono hm hq) (HasTypeArmsQ.q_mono ht hq)
    | .guarded hp hg hm ht =>
        exact .guarded hp (HasTypeCQ.q_mono hg hq) (HasTypeCQ.q_mono hm hq) (HasTypeArmsQ.q_mono ht hq)

  theorem HasTypeClausesQ.q_mono {Δl : LocalCtx} {Ψ Q' C Γ R εb h t ε} (hc : HasTypeClausesQ P B Ψ Q C Γ R εb h t ε Δl)
      (hq : QLe Q Q') : HasTypeClausesQ P B Ψ Q' C Γ R εb h t ε Δl := by
    match hc with
    | .nil => exact .nil
    | .cons hsg hnames hn hk hew hbody hrest =>
        exact .cons hsg hnames hn hk hew (HasTypeCQ.q_mono hbody hq) (HasTypeClausesQ.q_mono hrest hq)
  theorem HasFailureClause.q_mono {Δl : LocalCtx} {Ψ Q' C Γ E R h t ε}
      (hc : HasFailureClause P B Ψ Q C Γ E R h t ε Δl) (hq : QLe Q Q') :
      HasFailureClause P B Ψ Q' C Γ E R h t ε Δl := by
    match hc with
    | .one he ht hew hb => exact .one he ht hew (HasTypeCQ.q_mono hb hq)

end

end Benitoite.Release
