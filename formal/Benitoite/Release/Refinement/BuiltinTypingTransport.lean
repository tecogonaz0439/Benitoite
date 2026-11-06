import Benitoite.Release.Refinement.BuiltinResponse
import Benitoite.Release.Refinement.TargetModelConditions

/-! # 同じ宣言表の組込み射影による型付けの移送 -/
namespace Benitoite.Release.Refinement

/-- 型付けが読む七射影。応答と解放の関係は含めない。 -/
structure Builtins.TypingFieldsEq (B B' : Builtins) : Prop where
  sig : B.sig = B'.sig
  sat : B.sat = B'.sat
  ranges : B.admitsR = B'.admitsR
  resources : B.isResource = B'.isResource
  kinds : B.valKind = B'.valKind
  content : B.valContent = B'.valContent
  effects : B.effects = B'.effects

theorem ConstOK.of_fields {B B' c} (h : Builtins.TypingFieldsEq B B') (hc : ConstOK B c) :
    ConstOK B' c := by
  cases c <;> try exact hc
  simpa only [ConstOK, ← h.kinds, ← h.content] using hc

theorem SatAll.of_fields {B B' C ts ps} (h : Builtins.TypingFieldsEq B B')
    (ht : SatAll B C ts ps) : SatAll B' C ts ps := by
  simpa only [SatAll, ← h.sat] using ht

theorem Admissible.of_fields {B B' C nv ps ne Qs Qt ts es e}
    (h : Builtins.TypingFieldsEq B B') (ha : Admissible B C nv ps ne Qs Qt ts es e) :
    Admissible B' C nv ps ne Qs Qt ts es e :=
  { ha with types := ha.types.of_fields h }

theorem Builtins.RangeAdmissible.of_fields {B B' b s rs}
    (h : Builtins.TypingFieldsEq B B') (ha : B.RangeAdmissible b s rs) :
    B'.RangeAdmissible b s rs := by
  simpa only [Builtins.RangeAdmissible, ← h.ranges] using ha

theorem ExternalCallAdmissible.of_fields {P B B' C d ts}
    (h : Builtins.TypingFieldsEq B B') (ha : ExternalCallAdmissible P B C d ts) :
    ExternalCallAdmissible P B' C d ts :=
  { ha with constraints := ha.constraints.of_fields h }

theorem handled_of_fields {P B B' cs} (h : Builtins.TypingFieldsEq B B') :
    handled P B cs = handled P B' cs := by
  simp only [handled, effOps, issuesSelected, Builtins.issuesIn, h.effects, h.sig]

theorem ClauseSig.of_fields {P B B' e o sg} (h : Builtins.TypingFieldsEq B B')
    (hc : ClauseSig P B e o sg) : ClauseSig P B' e o sg := by
  simpa only [ClauseSig, ClauseIxOk, opSigAt, ← h.sig] using hc

mutual
  theorem HasTypeVQ.of_fields {P B B' Ψ Q C Γ Φ v a}
      (fields : Builtins.TypingFieldsEq B B') (typed : HasTypeVQ P B Ψ Q C Γ Φ v a) :
      HasTypeVQ P B' Ψ Q C Γ Φ v a := by
    match typed with
    | .V_Var h0 h1 => exact .V_Var h0 h1
    | .V_Const h0 => exact .V_Const (h0.of_fields fields)
    | .V_Lam h0 h1 h2 h3 h4 => exact .V_Lam h0 h1 h2 (h3.of_fields fields) h4
    | .V_DependentLam h0 h1 => exact .V_DependentLam h0 (h1.of_fields fields)
    | .V_Closure h0 h1 h2 => exact .V_Closure h0 h1 (h2.of_fields fields)
    | .V_Fun h0 h1 hr h2 h3 => exact .V_Fun h0 h1 hr (h2.of_fields fields) h3
    | .V_Prim h0 h1 h2 h3 h4 => exact .V_Prim (fields.sig ▸ h0) (h1.of_fields fields) h2 h3 h4
    | .V_Op h0 h1 h2 h3 => exact .V_Op h0 h1 (h2.of_fields fields) h3
    | .V_ExternalRef h0 h1 h2 h3 => exact .V_ExternalRef h0 h1 (h2.of_fields fields) h3
    | .V_ExternalHandle h td h0 h1 h2 h3 h4 => exact .V_ExternalHandle h td h0 h1 h2 h3 h4
    | .V_PathBases h0 => exact .V_PathBases h0
    | .V_ScopePattern h0 h1 h2 => exact .V_ScopePattern h0 h1 h2
    | .V_Checked h0 h1 h2 => exact .V_Checked (fields.kinds ▸ h0) (fields.content ▸ h1) h2
    | .V_CheckedRequest h0 h1 h2 h3 h4 h5 => exact .V_CheckedRequest (fields.kinds ▸ h0) (fields.content ▸ h1) (h2.of_fields fields) h3 h4 h5
    | .V_CheckedAt h0 => exact .V_CheckedAt (h0.of_fields fields)
    | .V_AtError h0 => exact .V_AtError h0
    | .V_Map h0 h1 h2 h3 h4 h5 => exact .V_Map (h0.of_fields fields) (h1.of_fields fields) h2 (fields.sat ▸ h3) h4 h5
    | .V_Set h0 h1 h2 => exact .V_Set (h0.of_fields fields) (fields.sat ▸ h1) h2
    | .V_Dict h0 h1 h2 h3 h4 h5 h6 h7 => exact .V_Dict h0 (h1.of_fields fields) h2 h3 h4 h5 (h6.of_fields fields) h7
    | .V_Raise h0 h1 h2 h3 => exact .V_Raise h0 h1 h2 h3
    | .V_LocRef h0 h1 => exact .V_LocRef h0 h1
    | .V_LocLazy h0 h1 => exact .V_LocLazy h0 h1
    | .V_Bytes h0 => exact .V_Bytes h0
    | .V_Con h0 h1 h2 h3 h4 h5 => exact .V_Con h0 h1 h2 h3 (h4.of_fields fields) h5
    | .V_Super h0 h1 h2 h3 => exact .V_Super (h0.of_fields fields) h1 h2 h3
    | .V_List h0 h1 h2 h3 => exact .V_List (h0.of_fields fields) h1 h2 h3
    | .V_Sub h0 h1 h2 h3 h4 => exact .V_Sub (h0.of_fields fields) h1 h2 h3 h4
    | .V_Normal h0 => exact .V_Normal (h0.of_fields fields)
    | .V_Refine h0 h1 h2 h3 h4 h5 h6 h7 => exact .V_Refine (h0.of_fields fields) h1 h2 h3 h4 h5 h6 h7
  theorem HasTypeVsQ.of_fields {P B B' Ψ Q C Γ Φ vs as}
      (fields : Builtins.TypingFieldsEq B B') (typed : HasTypeVsQ P B Ψ Q C Γ Φ vs as) :
      HasTypeVsQ P B' Ψ Q C Γ Φ vs as := by
    match typed with
    | .nil => exact .nil
    | .cons h0 h1 => exact .cons (h0.of_fields fields) (h1.of_fields fields)
  theorem HasTypeEachQ.of_fields {P B B' Ψ Q C Γ Φ vs a}
      (fields : Builtins.TypingFieldsEq B B') (typed : HasTypeEachQ P B Ψ Q C Γ Φ vs a) :
      HasTypeEachQ P B' Ψ Q C Γ Φ vs a := by
    match typed with
    | .nil => exact .nil
    | .cons h0 h1 => exact .cons (h0.of_fields fields) (h1.of_fields fields)
  theorem HasTypeCQ.of_fields {P B B' Ψ Q C Γ Φ R m a ε Δ}
      (fields : Builtins.TypingFieldsEq B B') (typed : HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ) :
      HasTypeCQ P B' Ψ Q C Γ Φ R m a ε Δ := by
    match typed with
    | .C_BuilderLet h0 h1 h2 h3 => exact .C_BuilderLet h0 h1 (h2.of_fields fields) h3
    | .C_BuilderOp h0 h1 h2 h3 => exact .C_BuilderOp h0 h1 h2 (h3.of_fields fields)
    | .C_Return h0 => exact .C_Return (h0.of_fields fields)
    | .C_Let h0 h1 h2 => exact .C_Let (h0.of_fields fields) (h1.of_fields fields) h2
    | .C_App h0 h1 => exact .C_App (h0.of_fields fields) (h1.of_fields fields)
    | .C_DependentApp h0 h1 => exact .C_DependentApp (h0.of_fields fields) (h1.of_fields fields)
    | .C_If h0 h1 h2 h3 => exact .C_If (h0.of_fields fields) h1 (h2.of_fields fields) (h3.of_fields fields)
    | .C_Match h0 h1 h2 hdecl h3 => exact .C_Match (h0.of_fields fields) h1 (h2.of_fields fields) hdecl h3
    | .C_Lazy h0 h1 => exact .C_Lazy (h0.of_fields fields) h1
    | .C_Escape h0 h1 => exact .C_Escape (h0.of_fields fields) h1
    | .C_Use h0 h1 h2 h3 => exact .C_Use (h0.of_fields fields) (fields.resources ▸ h1) (h2.of_fields fields) h3
    | .C_Handle h0 h1 h2 => exact .C_Handle (h0.of_fields fields) ((handled_of_fields fields) ▸ h1) (h2.of_fields fields)
    | .C_Handle_Fail h0 h1 h2 h3 => exact .C_Handle_Fail (h0.of_fields fields) h1 h2 (h3.of_fields fields)
    | .C_Resume h0 h1 h2 => exact .C_Resume h0 (h1.of_fields fields) h2
    | .C_ResumeL h0 h1 h2 => exact .C_ResumeL h0 (h1.of_fields fields) h2
    | .C_ResumeNorm h0 h1 h2 => exact .C_ResumeNorm h0 (h1.of_fields fields) h2
    | .C_ResumeLNorm h0 h1 h2 h3 => exact .C_ResumeLNorm h0 h1 (h2.of_fields fields) h3
    | .C_Normal h0 => exact .C_Normal (h0.of_fields fields)
    | .C_Meth h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 => exact .C_Meth (h0.of_fields fields) h1 h2 h3 (h4.of_fields fields) h5 h6 h7 (h8.of_fields fields) h9
    | .C_External h0 h1 h2 h3 => exact .C_External h0 h1 (h2.of_fields fields) (h3.of_fields fields)
    | .C_IssuePathBases b sg h0 h1 h2 h3 h4 h5 => exact .C_IssuePathBases b sg (fields.sig ▸ h0) h1 h2 h3 h4 h5
    | .C_CheckAt h0 => exact .C_CheckAt (h0.of_fields fields)
    | .C_Sub h0 h1 h2 h3 h4 h5 => exact .C_Sub (h0.of_fields fields) h1 h2 h3 h4 h5
    | .C_Eff h0 h1 => exact .C_Eff (h0.of_fields fields) h1
  theorem HasTypeTelArgsQ.of_fields {P B B' Ψ Q C Γ Φ ws t a e}
      (fields : Builtins.TypingFieldsEq B B') (typed : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t a e) :
      HasTypeTelArgsQ P B' Ψ Q C Γ Φ ws t a e := by
    match typed with
    | .done h0 => exact .done h0
    | .param h0 h1 h2 => exact .param h0 (h1.of_fields fields) (h2.of_fields fields)
  theorem TelBodyTy.of_fields {P B B' Ψ Q C Γ Φ t body}
      (fields : Builtins.TypingFieldsEq B B') (typed : TelBodyTy P B Ψ Q C Γ Φ t body) :
      TelBodyTy P B' Ψ Q C Γ Φ t body := by
    match typed with
    | .done h0 => exact .done (h0.of_fields fields)
    | .param h0 => exact .param (h0.of_fields fields)
  theorem CaptureOk.of_fields {P B B' Ψ R Γ Φ cap}
      (fields : Builtins.TypingFieldsEq B B') (typed : CaptureOk P B Ψ R Γ Φ cap) :
      CaptureOk P B' Ψ R Γ Φ cap := by
    match typed with
    | .mk h0 h1 h2 h3 h4 h5 h6 h7 => exact .mk h0 h1 h2 h3 h4 h5 (fun i a hi => (h6 i a hi).of_fields fields) h7
  theorem DependentClosureTy.of_fields {P B B' Ψ body t}
      (fields : Builtins.TypingFieldsEq B B') (typed : DependentClosureTy P B Ψ body t) :
      DependentClosureTy P B' Ψ body t := by
    match typed with
    | .mk h0 h1 h2 h3 => exact .mk (h0.of_fields fields) (h1.of_fields fields) h2 h3
  theorem CheckedWitness.of_fields {P B B' Ψ o k range snapshot target request}
      (fields : Builtins.TypingFieldsEq B B') (typed : CheckedWitness P B Ψ o k range snapshot target request) :
      CheckedWitness P B' Ψ o k range snapshot target request := by
    match typed with
    | .plain h0 h1 h2 h3 => exact .plain (fields.kinds ▸ h0) (fields.content ▸ h1) h2 h3
    | .request h0 h1 h2 h3 h4 h5 => exact .request (fields.kinds ▸ h0) (fields.content ▸ h1) (h2.of_fields fields) h3 h4 h5
  theorem AtCallAdmissible.of_fields {P B B' Ψ Q C Γ Φ kind name shape bases pattern input index}
      (fields : Builtins.TypingFieldsEq B B') (typed : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
      AtCallAdmissible P B' Ψ Q C Γ Φ kind name shape bases pattern input index := by
    match typed with
    | .mk h0 h1 h2 h3 h4 h5 h6 h7 => exact .mk h0 (fields.kinds ▸ h1) (fun v hv => (h2 v hv).of_fields fields) (h3.of_fields fields) (fields.content ▸ h4) (h5.of_fields fields) h6 h7
    | .text h0 h1 h2 h3 h4 h5 h6 h7 => exact .text h0 (fields.kinds ▸ h1) (fun v hv => (h2 v hv).of_fields fields) (h3.of_fields fields) (fields.content ▸ h4) (h5.of_fields fields) h6 h7
  theorem HasTypeArmsQ.of_fields {P B B' Ψ Q C Γ Φ R obs arms a b e Δ}
      (fields : Builtins.TypingFieldsEq B B') (typed : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e Δ) :
      HasTypeArmsQ P B' Ψ Q C Γ Φ R obs arms a b e Δ := by
    match typed with
    | .nil h0 => exact .nil h0
    | .plain h0 h1 h2 h3 h4 h5 => exact .plain h0 h1 h2 h3 (h4.of_fields fields) (h5.of_fields fields)
    | .guarded h0 h1 h2 h3 h4 h5 h6 h7 => exact .guarded h0 h1 h2 h3 h4 (h5.of_fields fields) (h6.of_fields fields) (h7.of_fields fields)
  theorem HasTypeClausesQ.of_fields {P B B' Ψ Q C Γ Φ R eb cs t e Δ}
      (fields : Builtins.TypingFieldsEq B B') (typed : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e Δ) :
      HasTypeClausesQ P B' Ψ Q C Γ Φ R eb cs t e Δ := by
    match typed with
    | .nil => exact .nil
    | .cons h0 h1 h2 h3 h4 h5 h6 => exact .cons (h0.of_fields fields) h1 h2 h3 h4 (h5.of_fields fields) (h6.of_fields fields)
  theorem HasFailureClause.of_fields {P B B' Ψ Q C Γ Φ E R cs t e Δ}
      (fields : Builtins.TypingFieldsEq B B') (typed : HasFailureClause P B Ψ Q C Γ Φ E R cs t e Δ) :
      HasFailureClause P B' Ψ Q C Γ Φ E R cs t e Δ := by
    match typed with
    | .one h0 h1 h2 h3 => exact .one h0 h1 h2 (h3.of_fields fields)
  theorem ImageOk.of_fields {P B B' Ψ Q C Γ Φ R env i a}
      (fields : Builtins.TypingFieldsEq B B') (typed : ImageOk P B Ψ Q C Γ Φ R env i a) :
      ImageOk P B' Ψ Q C Γ Φ R env i a := by
    match typed with
    | .ordinary h0 h1 => exact .ordinary h0 (h1.of_fields fields)
    | .hidden h0 h1 => exact .hidden h0 h1
    | .contLoc h0 h1 h2 h3 h4 h5 => exact .contLoc h0 h1 h2 h3 h4 h5
    | .contVar h0 h1 h2 => exact .contVar h0 h1 h2
end

end Benitoite.Release.Refinement
