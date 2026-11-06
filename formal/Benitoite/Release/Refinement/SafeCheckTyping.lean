import Benitoite.Release.Refinement.SafeCheckErasure
import Benitoite.Release.Refinement.Surface.Transport

/-! # 定義の本体を替えたプログラムへの型付けの移送 -/
namespace Benitoite.Release.Refinement
noncomputable section
open SafeCheckErasure

theorem erased_types (P : Program) : P.SameTypes (eraseProgram P) := ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩

theorem handled_program (P : Program) (B : Builtins) (cs : List Clause) :
    handledSelected (eraseProgram P) B cs = handledSelected P B cs := by
  rfl

theorem ExternalCallAdmissible.sameTypes {P P' B C d ts} (ha : ExternalCallAdmissible P B C d ts)
    (hs : P.SameTypes P') : ExternalCallAdmissible P' B C d ts :=
  ⟨ha.count,ha.kinds.sameTypes hs,ha.constraints,ha.types.sameTypes hs⟩

theorem ResultShape.Declared.sameTypes {P P' shape} (h : ResultShape.Declared P shape)
    (hs : P.SameTypes P') : ResultShape.Declared P' shape := by
  obtain ⟨standard,arity,distinct,⟨cd,hc,ok⟩,⟨cd',hc',err⟩⟩ := h
  exact ⟨standard.sameTypes hs,(hs.dataArity _ _).mp arity,distinct,
    ⟨cd,hs.cons ▸ hc,ok⟩,⟨cd',hs.cons ▸ hc',err⟩⟩

theorem Ty.CaptureDeclared.sameTypes {P P' C Γ a} (hd : Ty.CaptureDeclared P C Γ a)
    (hs : P.SameTypes P') : Ty.CaptureDeclared P' C Γ a := by
  cases a <;> simp only [Ty.CaptureDeclared] at hd ⊢
  all_goals first | exact hd.sameTypes hs | exact ⟨hd.1.sameTypes hs,hd.2.sameTypes hs⟩

theorem ClauseSig.sameTypes {P P' B e o sg} (hc : ClauseSig P B e o sg) (hs : P.SameTypes P') :
    ClauseSig P' B e o sg := by
  obtain ⟨S,hix,hsg,hr⟩ := hc
  refine ⟨S,hix,?_,hr⟩
  cases o <;> simpa only [opSigAt,hs.ops] using hsg

mutual
  theorem HasTypeVQ.in_erased_program {P : Program} {B : Builtins} {Ψ Q C Γ Φ v a} (typed : HasTypeVQ P B Ψ Q C Γ Φ v a) :
      HasTypeVQ (eraseProgram P) B Ψ Q C Γ Φ v a := by
    match typed with
    | .V_Var h0 h1 => exact .V_Var h0 h1
    | .V_Const h0 => exact .V_Const h0
    | .V_Lam h0 h1 h2 h3 h4 => exact .V_Lam h0 h1 h2 (h3.in_erased_program) (h4.sameTypes (erased_types P))
    | .V_DependentLam h0 h1 => exact .V_DependentLam (h0.sameTypes (erased_types P)) (h1.in_erased_program)
    | .V_Closure h0 h1 h2 => exact .V_Closure (h0.sameTypes (erased_types P)) h1 (h2.in_erased_program)
    | .V_Fun (d := d) h0 h1 hr h2 h3 =>
      exact .V_Fun (d := { d with body := erase d.body }) (by simp only [eraseProgram,h0,Option.map_some])
        h1 hr h2 (h3.sameTypes (erased_types P))
    | .V_Prim h0 h1 h2 h3 h4 => exact .V_Prim h0 h1 h2 h3 (h4.sameTypes (erased_types P))
    | .V_Op h0 h1 h2 h3 => exact .V_Op h0 h1 h2 (h3.sameTypes (erased_types P))
    | .V_ExternalRef h0 h1 h2 h3 =>
      exact .V_ExternalRef h0 (h1.sameTypes (erased_types P)) (h2.sameTypes (erased_types P)) (h3.sameTypes (erased_types P))
    | .V_ExternalHandle hd td h0 h1 h2 h3 h4 =>
      exact .V_ExternalHandle hd td h0 h1 h2 h3 (h4.sameTypes (erased_types P))
    | .V_PathBases h0 => exact .V_PathBases h0
    | .V_ScopePattern h0 h1 h2 => exact .V_ScopePattern h0 h1 h2
    | .V_Checked h0 h1 h2 => exact .V_Checked h0 h1 h2
    | .V_CheckedRequest h0 h1 h2 h3 h4 h5 => exact .V_CheckedRequest h0 h1 (h2.in_erased_program) h3 h4 h5
    | .V_CheckedAt h0 => exact .V_CheckedAt (h0.in_erased_program)
    | .V_AtError h0 => exact .V_AtError (h0.sameTypes (erased_types P))
    | .V_Map h0 h1 h2 h3 h4 h5 =>
      exact .V_Map (h0.in_erased_program) (h1.in_erased_program) h2 h3 (h4.sameTypes (erased_types P)) (h5.sameTypes (erased_types P))
    | .V_Set h0 h1 h2 => exact .V_Set (h0.in_erased_program) h1 (h2.sameTypes (erased_types P))
    | .V_Dict h0 h1 h2 h3 h4 h5 h6 h7 =>
      exact .V_Dict h0 h1 (h2.sameTypes (erased_types P)) (h3.sameTypes (erased_types P)) h4 h5 (h6.in_erased_program) (h7.sameTypes (erased_types P))
    | .V_Raise h0 h1 h2 h3 => exact .V_Raise (h0.sameTypes (erased_types P)) h1 h2 (h3.sameTypes (erased_types P))
    | .V_LocRef h0 h1 => exact .V_LocRef h0 (h1.sameTypes (erased_types P))
    | .V_LocLazy h0 h1 => exact .V_LocLazy h0 (h1.sameTypes (erased_types P))
    | .V_Bytes h0 => exact .V_Bytes h0
    | .V_Con h0 h1 h2 h3 h4 h5 => exact .V_Con h0 h1 (h2.sameTypes (erased_types P)) h3 (h4.in_erased_program) (h5.sameTypes (erased_types P))
    | .V_Super h0 h1 h2 h3 => exact .V_Super (h0.in_erased_program) h1 h2 (h3.sameTypes (erased_types P))
    | .V_List h0 h1 h2 h3 => exact .V_List (h0.in_erased_program) h1 h2 (h3.sameTypes (erased_types P))
    | .V_Sub h0 h1 h2 h3 h4 => exact .V_Sub (h0.in_erased_program) (h1.sameTypes (erased_types P)) h2 h3 (h4.sameTypes (erased_types P))
    | .V_Normal h0 => exact .V_Normal (h0.in_erased_program)
    | .V_Refine h0 h1 h2 h3 h4 h5 h6 h7 =>
      exact .V_Refine (h0.in_erased_program) h1 h2 h3 h4 h5 (h6.sameTypes (erased_types P)) (h7.sameTypes (erased_types P))
  theorem HasTypeVsQ.in_erased_program {P : Program} {B : Builtins} {Ψ Q C Γ Φ vs as} (typed : HasTypeVsQ P B Ψ Q C Γ Φ vs as) :
      HasTypeVsQ (eraseProgram P) B Ψ Q C Γ Φ vs as := by
    match typed with
    | .nil => exact .nil
    | .cons h0 h1 => exact .cons (h0.in_erased_program) (h1.in_erased_program)
  theorem HasTypeEachQ.in_erased_program {P : Program} {B : Builtins} {Ψ Q C Γ Φ vs a} (typed : HasTypeEachQ P B Ψ Q C Γ Φ vs a) :
      HasTypeEachQ (eraseProgram P) B Ψ Q C Γ Φ vs a := by
    match typed with
    | .nil => exact .nil
    | .cons h0 h1 => exact .cons (h0.in_erased_program) (h1.in_erased_program)
  theorem HasTypeCQ.in_erased_program {P : Program} {B : Builtins} {Ψ Q C Γ Φ R m a ε Δ} (typed : HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ) :
      HasTypeCQ (eraseProgram P) B Ψ Q C Γ Φ R m a ε Δ := by
    match typed with
    | .C_BuilderLet h0 h1 h2 h3 => exact .C_BuilderLet (h0.sameTypes (erased_types P)) (h1.sameTypes (erased_types P)) (h2.in_erased_program) (h3.sameTypes (erased_types P))
    | .C_BuilderOp h0 h1 h2 h3 => exact .C_BuilderOp (h0.sameTypes (erased_types P)) (h1.sameTypes (erased_types P)) h2 (h3.in_erased_program)
    | .C_Return h0 => exact .C_Return (h0.in_erased_program)
    | .C_Let h0 h1 h2 => exact .C_Let (h0.in_erased_program) (h1.in_erased_program) (h2.sameTypes (erased_types P))
    | .C_App h0 h1 => exact .C_App (h0.in_erased_program) (h1.in_erased_program)
    | .C_DependentApp h0 h1 => exact .C_DependentApp (h0.in_erased_program) (h1.in_erased_program)
    | .C_If h0 h1 h2 h3 => exact .C_If (h0.in_erased_program) h1 (h2.in_erased_program) (h3.in_erased_program)
    | .C_Match h0 h1 h2 hdecl h3 => exact .C_Match (h0.in_erased_program) h1 (h2.in_erased_program) (hdecl.sameTypes (erased_types P)) (h3.sameTypes (erased_types P))
    | .C_Lazy h0 h1 => exact .C_Lazy (h0.in_erased_program) (h1.sameTypes (erased_types P))
    | .C_Escape h0 h1 => exact .C_Escape (h0.in_erased_program) (h1.sameTypes (erased_types P))
    | .C_Use h0 h1 h2 h3 => exact .C_Use (h0.in_erased_program) h1 (h2.in_erased_program) h3
    | .C_Handle (h := cs) h0 h1 h2 =>
      exact .C_Handle (h0.in_erased_program) (by simpa only [handled_program] using h1) (h2.in_erased_program)
    | .C_Handle_Fail h0 h1 h2 h3 => exact .C_Handle_Fail (h0.in_erased_program) h1 h2 (h3.in_erased_program)
    | .C_Resume h0 h1 h2 => exact .C_Resume h0 (h1.in_erased_program) (h2.sameTypes (erased_types P))
    | .C_ResumeL h0 h1 h2 => exact .C_ResumeL h0 (h1.in_erased_program) (h2.sameTypes (erased_types P))
    | .C_ResumeNorm h0 h1 h2 => exact .C_ResumeNorm h0 (h1.in_erased_program) (h2.sameTypes (erased_types P))
    | .C_ResumeLNorm h0 h1 h2 h3 => exact .C_ResumeLNorm h0 h1 (h2.in_erased_program) (h3.sameTypes (erased_types P))
    | .C_Normal h0 => exact .C_Normal (h0.in_erased_program)
    | .C_Meth h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 =>
      exact .C_Meth (h0.in_erased_program) h1 h2 h3 h4 (h5.sameTypes (erased_types P)) h6 h7 (h8.in_erased_program) (h9.sameTypes (erased_types P))
    | .C_External h0 h1 h2 h3 =>
      exact .C_External h0 (h1.sameTypes (erased_types P)) (h2.sameTypes (erased_types P)) (h3.in_erased_program)
    | .C_IssuePathBases b sg h0 h1 h2 h3 h4 h5 => exact .C_IssuePathBases b sg h0 h1 h2 h3 h4 h5
    | .C_CheckAt h0 => exact .C_CheckAt (h0.in_erased_program)
    | .C_Sub h0 h1 h2 h3 h4 h5 => exact .C_Sub (h0.in_erased_program) (h1.sameTypes (erased_types P)) h2 h3 h4 (h5.sameTypes (erased_types P))
    | .C_Eff h0 h1 => exact .C_Eff (h0.in_erased_program) h1
  theorem HasTypeTelArgsQ.in_erased_program {P : Program} {B : Builtins} {Ψ Q C Γ Φ ws t a e} (typed : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t a e) :
      HasTypeTelArgsQ (eraseProgram P) B Ψ Q C Γ Φ ws t a e := by
    match typed with
    | .done h0 => exact .done (h0.sameTypes (erased_types P))
    | .param h0 h1 h2 => exact .param (h0.sameTypes (erased_types P)) (h1.in_erased_program) (h2.in_erased_program)
  theorem TelBodyTy.in_erased_program {P : Program} {B : Builtins} {Ψ Q C Γ Φ t body} (typed : TelBodyTy P B Ψ Q C Γ Φ t body) :
      TelBodyTy (eraseProgram P) B Ψ Q C Γ Φ t body := by
    match typed with
    | .done h0 => exact .done (h0.in_erased_program)
    | .param h0 => exact .param (h0.in_erased_program)
  theorem CaptureOk.in_erased_program {P : Program} {B : Builtins} {Ψ R Γ Φ cap} (typed : CaptureOk P B Ψ R Γ Φ cap) : CaptureOk (eraseProgram P) B Ψ R Γ Φ cap := by
    match typed with
    | .mk h0 h1 h2 h3 h4 h5 h6 h7 =>
      exact .mk h0 h1 h2 (fun i a hi => ⟨(h3 i a hi).1, Ty.CaptureDeclared.sameTypes (h3 i a hi).2 (erased_types P)⟩)
        (fun p hp => ⟨(h4 p hp).1, (h4 p hp).2.1, (h4 p hp).2.2.sameTypes (erased_types P)⟩) h5
        (fun i a hi => (h6 i a hi).in_erased_program) h7
  theorem DependentClosureTy.in_erased_program {P : Program} {B : Builtins} {Ψ body t} (typed : DependentClosureTy P B Ψ body t) :
      DependentClosureTy (eraseProgram P) B Ψ body t := by
    match typed with
    | .mk h0 h1 h2 h3 => exact .mk (h0.in_erased_program) (h1.in_erased_program) (h2.sameTypes (erased_types P)) (h3.sameTypes (erased_types P))
  theorem CheckedWitness.in_erased_program {P : Program} {B : Builtins} {Ψ o k range snapshot target request}
      (typed : CheckedWitness P B Ψ o k range snapshot target request) :
      CheckedWitness (eraseProgram P) B Ψ o k range snapshot target request := by
    match typed with
    | .plain h0 h1 h2 h3 => exact .plain h0 h1 h2 h3
    | .request h0 h1 h2 h3 h4 h5 => exact .request h0 h1 (h2.in_erased_program) h3 h4 h5
  theorem AtCallAdmissible.in_erased_program {P : Program} {B : Builtins} {Ψ Q C Γ Φ kind name shape bases pattern input index}
      (typed : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
      AtCallAdmissible (eraseProgram P) B Ψ Q C Γ Φ kind name shape bases pattern input index := by
    match typed with
    | .mk h0 h1 h2 h3 h4 h5 h6 h7 =>
      exact .mk (h0.sameTypes (erased_types P)) h1 (fun v hv => (h2 v hv).in_erased_program) (h3.in_erased_program) h4
        (h5.in_erased_program) h6 h7
    | .text h0 h1 h2 h3 h4 h5 h6 h7 =>
      exact .text (h0.sameTypes (erased_types P)) h1 (fun v hv => (h2 v hv).in_erased_program) (h3.in_erased_program) h4
        (h5.in_erased_program) h6 h7
  theorem HasTypeArmsQ.in_erased_program {P : Program} {B : Builtins} {Ψ Q C Γ Φ R obs arms a b e Δ}
      (typed : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e Δ) : HasTypeArmsQ (eraseProgram P) B Ψ Q C Γ Φ R obs arms a b e Δ := by
    match typed with
    | .nil h0 => exact .nil (h0.sameTypes (erased_types P))
    | .plain h0 h1 h2 h3 h4 h5 =>
      exact .plain (h0.sameTypes (erased_types P)) h1 (h2.sameTypes (erased_types P)) (h3.sameTypes (erased_types P)) (h4.in_erased_program) (h5.in_erased_program)
    | .guarded h0 h1 h2 h3 h4 h5 h6 h7 =>
      exact .guarded (h0.sameTypes (erased_types P)) h1 (h2.sameTypes (erased_types P)) (h3.sameTypes (erased_types P)) (h4.sameTypes (erased_types P))
        (h5.in_erased_program) (h6.in_erased_program) (h7.in_erased_program)
  theorem HasTypeClausesQ.in_erased_program {P : Program} {B : Builtins} {Ψ Q C Γ Φ R eb cs t e Δ}
      (typed : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e Δ) : HasTypeClausesQ (eraseProgram P) B Ψ Q C Γ Φ R eb cs t e Δ := by
    match typed with
    | .nil => exact .nil
    | .cons h0 h1 h2 h3 h4 h5 h6 => exact .cons (ClauseSig.sameTypes h0 (erased_types P)) h1 h2 h3 h4 (h5.in_erased_program) (h6.in_erased_program)
  theorem HasFailureClause.in_erased_program {P : Program} {B : Builtins} {Ψ Q C Γ Φ E R cs t e Δ}
      (typed : HasFailureClause P B Ψ Q C Γ Φ E R cs t e Δ) : HasFailureClause (eraseProgram P) B Ψ Q C Γ Φ E R cs t e Δ := by
    match typed with
    | .one h0 h1 h2 h3 => exact .one (h0.sameTypes (erased_types P)) (h1.sameTypes (erased_types P)) (h2.sameTypes (erased_types P)) (h3.in_erased_program)
  theorem ImageOk.in_erased_program {P : Program} {B : Builtins} {Ψ Q C Γ Φ R env i a} (typed : ImageOk P B Ψ Q C Γ Φ R env i a) :
      ImageOk (eraseProgram P) B Ψ Q C Γ Φ R env i a := by
    match typed with
    | .ordinary h0 h1 => exact .ordinary h0 (h1.in_erased_program)
    | .hidden h0 h1 => exact .hidden h0 h1
    | .contLoc h0 h1 h2 h3 h4 h5 => exact .contLoc h0 h1 h2 h3 h4 h5
    | .contVar h0 h1 h2 => exact .contVar h0 h1 h2
end


end
end Benitoite.Release.Refinement
