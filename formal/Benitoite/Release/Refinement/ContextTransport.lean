import Benitoite.Release.Refinement.CaptureRegularity
import Benitoite.Release.Refinement.ContextNormEq

/-! # Q と文脈の移送（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem NoFail.q_mono {Q Q' e} (h : NoFail Q e) (hq : ∀ i, Q i → Q' i) : NoFail Q' e :=
  ⟨h.1, fun i hi => hq i (h.2 i hi)⟩

theorem RowTransport.q_mono {Qs Q Q' es} (h : RowTransport Qs Q es)
    (hq : ∀ i, Q i → Q' i) : RowTransport Qs Q' es :=
  fun i hi => (h i hi).q_mono hq

theorem Admissible.q_mono {B C nv tps ne Qs Q Q' ts es e}
    (h : Admissible B C nv tps ne Qs Q ts es e) (hq : ∀ i, Q i → Q' i) :
    Admissible B C nv tps ne Qs Q' ts es e :=
  { h with noFailRows := h.noFailRows.q_mono hq }

theorem PrimitiveAdmissible.q_mono {C nv s Q Q' ts es}
    (h : PrimitiveAdmissible C nv s Q ts es) (hq : ∀ i, Q i → Q' i) :
    PrimitiveAdmissible C nv s Q' ts es :=
  { h with noFailRows := h.noFailRows.q_mono hq }

theorem MethodRowsAdmissible.q_mono {C nv Q Q' ms es}
    (h : MethodRowsAdmissible C nv Q ms es) (hq : ∀ i, Q i → Q' i) :
    MethodRowsAdmissible C nv Q' ms es :=
  ⟨h.1,h.2.1,h.2.2.1,h.2.2.2.1,h.2.2.2.2.q_mono hq⟩

mutual
  theorem HasTypeVQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {v : Val} {a : Ty} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeVQ P B Ψ Q' C Γ Φ v a := by
    match h with
    | @HasTypeVQ.V_Var _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 =>
      exact .V_Var x7 x8
    | @HasTypeVQ.V_Const _ _ x0 x1 x2 x3 x4 x5 x6 =>
      exact .V_Const x6
    | @HasTypeVQ.V_Lam _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .V_Lam x10 x11 x12 (HasTypeCQ.q_mono x13 hq) x14
    | @HasTypeVQ.V_DependentLam _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 =>
      exact .V_DependentLam x7 (TelBodyTy.q_mono x8 hq)
    | @HasTypeVQ.V_Closure _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact .V_Closure x8 x9 x10
    | @HasTypeVQ.V_Fun _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 =>
      exact .V_Fun x9 x10 (x11.q_mono hq) x12
    | @HasTypeVQ.V_Prim _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .V_Prim x10 x11 x12 (x13.q_mono hq) x14
    | @HasTypeVQ.V_Op _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact .V_Op x8 x9 x10 x11
    | @HasTypeVQ.V_ExternalRef _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact .V_ExternalRef x8 x9 x10 x11
    | @HasTypeVQ.V_ExternalHandle _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 =>
      exact .V_ExternalHandle x6 x7 x8 x9 x10 x11 x12
    | @HasTypeVQ.V_PathBases _ _ x0 x1 x2 x3 x4 x5 x6 =>
      exact .V_PathBases x6
    | @HasTypeVQ.V_ScopePattern _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact .V_ScopePattern x7 x8 x9
    | @HasTypeVQ.V_Checked _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact .V_Checked x9 x10 x11
    | @HasTypeVQ.V_CheckedRequest _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 =>
      exact .V_CheckedRequest x10 x11 x12 x13 x14 x15
    | @HasTypeVQ.V_CheckedAt _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact .V_CheckedAt x11
    | @HasTypeVQ.V_AtError _ _ x0 x1 x2 x3 x4 x5 x6 x7 =>
      exact .V_AtError x7
    | @HasTypeVQ.V_Map _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .V_Map (HasTypeEachQ.q_mono x9 hq) (HasTypeEachQ.q_mono x10 hq) x11 x12 x13 x14
    | @HasTypeVQ.V_Set _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact .V_Set (HasTypeEachQ.q_mono x7 hq) x8 x9
    | @HasTypeVQ.V_Dict _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact .V_Dict x9 x10 x11 x12 x13 x14 (HasTypeVsQ.q_mono x15 hq) x16
    | @HasTypeVQ.V_Raise _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact .V_Raise x7 x8 x9 x10
    | @HasTypeVQ.V_LocRef _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 =>
      exact .V_LocRef x7 x8
    | @HasTypeVQ.V_LocLazy _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 =>
      exact .V_LocLazy x7 x8
    | @HasTypeVQ.V_Bytes _ _ x0 x1 x2 x3 x4 x5 x6 =>
      exact .V_Bytes x6
    | @HasTypeVQ.V_Con _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .V_Con x9 x10 x11 x12 (HasTypeVsQ.q_mono x13 hq) x14
    | @HasTypeVQ.V_Super _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 =>
      exact .V_Super (HasTypeVQ.q_mono x10 hq) x11 x12 x13
    | @HasTypeVQ.V_List _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact .V_List (HasTypeEachQ.q_mono x7 hq) x8 x9 x10
    | @HasTypeVQ.V_Sub _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 =>
      exact .V_Sub (HasTypeVQ.q_mono x8 hq) x9 x10 x11 x12
    | @HasTypeVQ.V_Normal _ _ x0 x1 x2 x3 x4 x5 x6 x7 =>
      exact .V_Normal (HasTypeVQ.q_mono x7 hq)
    | @HasTypeVQ.V_Refine _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 =>
      exact .V_Refine (HasTypeVQ.q_mono x10 hq) x11 x12 x13 x14 x15 x16 x17
  termination_by structural h

  theorem HasTypeVsQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {vs : List Val} {as : List Ty} (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeVsQ P B Ψ Q' C Γ Φ vs as := by
    match h with
    | @HasTypeVsQ.nil _ _ x0 x1 x2 x3 x4 =>
      exact .nil 
    | @HasTypeVsQ.cons _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact .cons (HasTypeVQ.q_mono x9 hq) (HasTypeVsQ.q_mono x10 hq)
  termination_by structural h

  theorem HasTypeEachQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {vs : List Val} {a : Ty} (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeEachQ P B Ψ Q' C Γ Φ vs a := by
    match h with
    | @HasTypeEachQ.nil _ _ x0 x1 x2 x3 x4 x5 =>
      exact .nil 
    | @HasTypeEachQ.cons _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact .cons (HasTypeVQ.q_mono x8 hq) (HasTypeEachQ.q_mono x9 hq)
  termination_by structural h

  theorem HasTypeCQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {m : Comp} {a : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeCQ P B Ψ Q' C Γ Φ R m a e L := by
    match h with
    | @HasTypeCQ.C_BuilderLet _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_BuilderLet x11 x12 (HasTypeCQ.q_mono x13 hq) x14
    | @HasTypeCQ.C_BuilderOp _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_BuilderOp x11 x12 x13 (HasTypeVsQ.q_mono x14 hq)
    | @HasTypeCQ.C_Return _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact .C_Return (HasTypeVQ.q_mono x9 hq)
    | @HasTypeCQ.C_Let _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_Let (HasTypeCQ.q_mono x12 hq) (HasTypeCQ.q_mono x13 hq) x14
    | @HasTypeCQ.C_App _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_App (HasTypeVQ.q_mono x13 hq) (HasTypeVsQ.q_mono x14 hq)
    | @HasTypeCQ.C_DependentApp _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 =>
      exact .C_DependentApp (HasTypeVQ.q_mono x12 hq) (HasTypeTelArgsQ.q_mono x13 hq)
    | @HasTypeCQ.C_If _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact .C_If (HasTypeVQ.q_mono x13 hq) x14 (HasTypeCQ.q_mono x15 hq) (HasTypeCQ.q_mono x16 hq)
    | @HasTypeCQ.C_Match _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact .C_Match (HasTypeVQ.q_mono x13 hq) x14 (HasTypeArmsQ.q_mono x15 hq) x16
    | @HasTypeCQ.C_Lazy _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact .C_Lazy (HasTypeCQ.q_mono x9 hq) x10
    | @HasTypeCQ.C_Escape _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact .C_Escape (HasTypeVQ.q_mono x10 hq) x11
    | @HasTypeCQ.C_Use _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 =>
      exact .C_Use (HasTypeVQ.q_mono x12 hq) x13 (HasTypeCQ.q_mono x14 hq) x15
    | @HasTypeCQ.C_Handle _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_Handle (HasTypeCQ.q_mono x12 hq) x13 (HasTypeClausesQ.q_mono x14 hq)
    | @HasTypeCQ.C_Handle_Fail _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 =>
      exact .C_Handle_Fail (HasTypeCQ.q_mono x14 hq) x15 (x16.q_mono hq) (HasFailureClause.q_mono x17 hq)
    | @HasTypeCQ.C_Resume _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_Resume x12 (HasTypeVQ.q_mono x13 hq) x14
    | @HasTypeCQ.C_ResumeL _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_ResumeL x12 (HasTypeVQ.q_mono x13 hq) x14
    | @HasTypeCQ.C_ResumeNorm _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_ResumeNorm x12 (HasTypeVQ.q_mono x13 hq) x14
    | @HasTypeCQ.C_ResumeLNorm _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact .C_ResumeLNorm x13 x14 (HasTypeVQ.q_mono x15 hq) x16
    | @HasTypeCQ.C_Normal _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact .C_Normal (HasTypeCQ.q_mono x10 hq)
    | @HasTypeCQ.C_Meth _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 =>
      exact .C_Meth (HasTypeVQ.q_mono x19 hq) x20 x21 x22 x23 x24 (x25.q_mono hq) x26 (HasTypeVsQ.q_mono x27 hq) x28
    | @HasTypeCQ.C_External _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact .C_External x13 x14 x15 (HasTypeTelArgsQ.q_mono x16 hq)
    | @HasTypeCQ.C_IssuePathBases _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_IssuePathBases x7 x8 x9 x10 x11 x12 x13 x14
    | @HasTypeCQ.C_CheckAt _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .C_CheckAt (AtCallAdmissible.q_mono x14 hq)
    | @HasTypeCQ.C_Sub _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 =>
      exact .C_Sub (HasTypeCQ.q_mono x12 hq) x13 x14 x15 x16 x17
    | @HasTypeCQ.C_Eff _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 =>
      exact .C_Eff (HasTypeCQ.q_mono x11 hq) x12
  termination_by structural h

  theorem HasTypeTelArgsQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {vs : List Val} {t : Tel} {a : Ty} {e : Eff} (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeTelArgsQ P B Ψ Q' C Γ Φ vs t a e := by
    match h with
    | @HasTypeTelArgsQ.done _ _ x0 x1 x2 x3 x4 x5 x6 x7 =>
      exact .done x7
    | @HasTypeTelArgsQ.param _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .param x12 (HasTypeVQ.q_mono x13 hq) (HasTypeTelArgsQ.q_mono x14 hq)
  termination_by structural h

  theorem TelBodyTy.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {t : Tel} {body : Comp} (h : TelBodyTy P B Ψ Q C Γ Φ t body) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    TelBodyTy P B Ψ Q' C Γ Φ t body := by
    match h with
    | @TelBodyTy.done _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 =>
      exact .done (HasTypeCQ.q_mono x8 hq)
    | @TelBodyTy.param _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact .param (TelBodyTy.q_mono x9 hq)
  termination_by structural h

  theorem CaptureOk.q_fixed {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty} {Γ : Ctx} {Φ : List Pred} {cap : Capture} (h : CaptureOk P B Ψ R Γ Φ cap) :
    CaptureOk P B Ψ R Γ Φ cap := by
    match h with
    | @CaptureOk.mk _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 =>
      exact .mk x5 x6 x7 x8 x9 x10 x11 x12

  theorem DependentClosureTy.q_fixed {P : Program} {B : Builtins} {Ψ : StoreTy} {q : Closure} {t : Tel} (h : DependentClosureTy P B Ψ q t) :
    DependentClosureTy P B Ψ q t := by
    match h with
    | @DependentClosureTy.mk _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact .mk x6 x7 x8 x9

  theorem CheckedWitness.q_fixed {P : Program} {B : Builtins} {Ψ : StoreTy} {o : Benitoite.Release.OpaqueName} {kind : Benitoite.Scope.Domain.Kind} {range : RangeExpr} {snapshot : Option PathEnv} {target : Benitoite.Scope.Domain.Target} {request : Option Val} (h : CheckedWitness P B Ψ o kind range snapshot target request) :
    CheckedWitness P B Ψ o kind range snapshot target request := by
    match h with
    | @CheckedWitness.plain _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact .plain x6 x7 x8 x9
    | @CheckedWitness.request _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 =>
      exact .request x7 x8 x9 x10 x11 x12

  theorem AtCallAdmissible.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName} {shape : ResultShape} {bases : Option Val} {pattern : Val} {input : Val} {index : RangeIx} (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    AtCallAdmissible P B Ψ Q' C Γ Φ kind name shape bases pattern input index := by
    match h with
    | @AtCallAdmissible.mk _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 =>
      exact .mk x13 x14 (fun v hv => HasTypeVQ.q_mono (x15 v hv) hq) (HasTypeVQ.q_mono x16 hq) x17 (HasTypeVQ.q_mono x18 hq) x19 x20
  termination_by structural h

  theorem HasTypeArmsQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {obs : Option Benitoite.Release.Refinement.Term} {arms : List Arm} {a : Ty} {b : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeArmsQ P B Ψ Q' C Γ Φ R obs arms a b e L := by
    match h with
    | @HasTypeArmsQ.nil _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact .nil x11
    | @HasTypeArmsQ.plain _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 =>
      exact .plain x15 x16 (HasTypeCQ.q_mono x17 hq) (HasTypeArmsQ.q_mono x18 hq)
    | @HasTypeArmsQ.guarded _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 =>
      exact .guarded x17 x18 x19 (HasTypeCQ.q_mono x20 hq) (HasTypeCQ.q_mono x21 hq) (HasTypeArmsQ.q_mono x22 hq)
  termination_by structural h

  theorem HasTypeClausesQ.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {eb : Eff} {cs : List Clause} {t : Ty} {e : Eff} {L : LocalCtx} (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasTypeClausesQ P B Ψ Q' C Γ Φ R eb cs t e L := by
    match h with
    | @HasTypeClausesQ.nil _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact .nil 
    | @HasTypeClausesQ.cons _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 =>
      exact .cons x16 x17 x18 x19 x20 (HasTypeCQ.q_mono x21 hq) (HasTypeClausesQ.q_mono x22 hq)
  termination_by structural h

  theorem HasFailureClause.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {E : Ty} {R : Option Ty} {cs : List Clause} {t : Ty} {e : Eff} {L : LocalCtx} (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t e L) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    HasFailureClause P B Ψ Q' C Γ Φ E R cs t e L := by
    match h with
    | @HasFailureClause.one _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact .one x11 x12 x13 (HasTypeCQ.q_mono x14 hq)
  termination_by structural h

  theorem ImageOk.q_mono {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {ν : Nat → Val} {i : Nat} {a : Ty} (h : ImageOk P B Ψ Q C Γ Φ R ν i a) {Q' : NoFailCtx} (hq : ∀ i, Q i → Q' i) :
    ImageOk P B Ψ Q' C Γ Φ R ν i a := by
    match h with
    | @ImageOk.ordinary _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact .ordinary x9 (HasTypeVQ.q_mono x10 hq)
    | @ImageOk.hidden _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact .hidden x9 x10
    | @ImageOk.contLoc _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 =>
      exact .contLoc x16 x17 x18 x19 x20 x21
    | @ImageOk.contVar _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 =>
      exact .contVar x13 x14 x15

end
end
end Benitoite.Release.Refinement
