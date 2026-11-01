import Benitoite.Release.Refinement.LegacyInput

/-! # 旧七判断の全中間判断と局所規則 -/
namespace Benitoite.Release.Refinement
noncomputable section

inductive LegacyJudgment where
  | value : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → Benitoite.Release.Val → Benitoite.Release.Ty → LegacyJudgment
  | values : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → List Benitoite.Release.Val → List Benitoite.Release.Ty → LegacyJudgment
  | each : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → List Benitoite.Release.Val → Benitoite.Release.Ty → LegacyJudgment
  | comp : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → Option Benitoite.Release.Ty → Benitoite.Release.Comp → Benitoite.Release.Ty → Benitoite.Release.Eff → Benitoite.Release.LocalCtx → LegacyJudgment
  | arms : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → Option Benitoite.Release.Ty → List Benitoite.Release.Arm → Benitoite.Release.Ty → Benitoite.Release.Ty → Benitoite.Release.Eff → Benitoite.Release.LocalCtx → LegacyJudgment
  | clauses : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → Option Benitoite.Release.Ty → Benitoite.Release.Eff → List Benitoite.Release.Clause → Benitoite.Release.Ty → Benitoite.Release.Eff → Benitoite.Release.LocalCtx → LegacyJudgment
  | failure : KindCtx → Benitoite.Release.StoreTy → Benitoite.Release.NoFailCtx → List Benitoite.Release.TParam → List (Option Benitoite.Release.Ty) → Benitoite.Release.Ty → Option Benitoite.Release.Ty → List Benitoite.Release.Clause → Benitoite.Release.Ty → Benitoite.Release.Eff → Benitoite.Release.LocalCtx → LegacyJudgment

def LegacyJudgment.OldHolds (P0 : Benitoite.Release.Program) (B0 : Benitoite.Release.Builtins) : LegacyJudgment → Prop
  | .value _ Ψ Q C Γ v a => Benitoite.Release.HasTypeVQ P0 B0 Ψ Q C Γ v a
  | .values _ Ψ Q C Γ vs ts => Benitoite.Release.HasTypeVsQ P0 B0 Ψ Q C Γ vs ts
  | .each _ Ψ Q C Γ vs a => Benitoite.Release.HasTypeEachQ P0 B0 Ψ Q C Γ vs a
  | .comp _ Ψ Q C Γ R m a e L => Benitoite.Release.HasTypeCQ P0 B0 Ψ Q C Γ R m a e L
  | .arms _ Ψ Q C Γ R xs a b e L => Benitoite.Release.HasTypeArmsQ P0 B0 Ψ Q C Γ R xs a b e L
  | .clauses _ Ψ Q C Γ R eb cs a e L => Benitoite.Release.HasTypeClausesQ P0 B0 Ψ Q C Γ R eb cs a e L
  | .failure _ Ψ Q C Γ E R cs a e L => Benitoite.Release.HasFailureClause P0 B0 Ψ Q C Γ E R cs a e L

/-- 型文脈・値文脈と閉じたストアを同時に検査する。 -/
def LegacyNodeContext (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (κ : KindCtx) (Ψ : Benitoite.Release.StoreTy) (C : List Benitoite.Release.TParam)
    (Γ : List (Option Benitoite.Release.Ty)) : Prop :=
  LegacyContextInput K P0 Ψ C Γ ⟨κ, C, 0, Γ.length⟩

def LegacyNodeTypes (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (κ : KindCtx) (C : List Benitoite.Release.TParam) (nv : Nat)
    (as : List Benitoite.Release.Ty) : Prop :=
  ∀ a ∈ as, LegacyTypeInput K P0 ⟨κ, C, 0, nv⟩ a .value

def LegacyNodeLocal (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (κ : KindCtx) (C : List Benitoite.Release.TParam) (nv : Nat)
    (L : Benitoite.Release.LocalCtx) : Prop :=
  ∀ item ∈ L, ∀ k ∈ item.toList, LegacyBuilderInput K P0 ⟨κ, C, 0, nv⟩ k

def LegacyNodeRegular (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : LegacyJudgment → Prop
  | .value κ Ψ _Q C Γ v a =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyValueInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ v ∧ LegacyHeldTypeInput B0 B v a ∧
      LegacyNodeTypes K P0 κ C Γ.length [a]
  | .values κ Ψ _Q C Γ vs ts =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyValuesInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ vs ∧
      LegacyNodeTypes K P0 κ C Γ.length ts
  | .each κ Ψ _Q C Γ vs a =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyValuesInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ vs ∧
      LegacyNodeTypes K P0 κ C Γ.length [a]
  | .comp κ Ψ _Q C Γ R m a e L =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyCompInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ m ∧
      LegacyNodeTypes K P0 κ C Γ.length (a :: R.toList) ∧
      LegacyRowsInput K P0 ⟨κ, C, 0, Γ.length⟩ [e] ∧ LegacyNodeLocal K P0 κ C Γ.length L
  | .arms κ Ψ _Q C Γ R arms a b e L =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyArmsInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ arms ∧
      LegacyNodeTypes K P0 κ C Γ.length (a :: b :: R.toList) ∧
      LegacyRowsInput K P0 ⟨κ, C, 0, Γ.length⟩ [e] ∧ LegacyNodeLocal K P0 κ C Γ.length L
  | .clauses κ Ψ _Q C Γ R eb cs a e L =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyClausesInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ cs ∧
      LegacyNodeTypes K P0 κ C Γ.length (a :: R.toList) ∧
      LegacyRowsInput K P0 ⟨κ, C, 0, Γ.length⟩ [eb, e] ∧ LegacyNodeLocal K P0 κ C Γ.length L
  | .failure κ Ψ _Q C Γ E R cs a e L =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyClausesInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ cs ∧
      LegacyNodeTypes K P0 κ C Γ.length (E :: a :: R.toList) ∧
      LegacyRowsInput K P0 ⟨κ, C, 0, Γ.length⟩ [e] ∧ LegacyNodeLocal K P0 κ C Γ.length L

inductive LegacyRule (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) : LegacyJudgment → List LegacyJudgment → Prop where
  | V_Var {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ i a} :
      Γ[i]? = some (some a) →
      (∀ b t ε, a ≠ .cont b t ε) →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.var i) a) []
  | V_Const {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ c} :
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.const c) c.type) []
  | V_Fun {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ f d ts es} :
      P0.defs f = some d →
      Benitoite.Release.NamesWF d.names d.params →
      Benitoite.Release.Admissible B0 C d.tparams d.neffs (Benitoite.Release.Qsig d.params d.ret d.eff) Q ts es d.eff →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.fnRef f ts es) (Benitoite.Release.fnTy d.names d.params d.ret d.eff ts es)) []
  | V_Prim {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ b s rs ts es} :
      B0.sig b = some s →
      B0.RangeAdmissible b s rs →
      Benitoite.Release.NamesWF (s.inst rs).names (s.inst rs).params →
      Benitoite.Release.PrimitiveAdmissible C (s.inst rs) Q ts es →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.prim b ts es rs) (Benitoite.Release.fnTy (s.inst rs).names (s.inst rs).params (s.inst rs).ret (s.inst rs).eff ts es)) []
  | V_Op {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ o od ts} :
      P0.ops o = some od →
      Benitoite.Release.NamesWF od.names od.params →
      Benitoite.Release.SatAll B0 C ts od.tparams →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.op o ts) (Benitoite.Release.fnTy od.names od.params od.ret (Benitoite.Release.Eff.single od.eff) ts [])) []
  | V_Raise {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ T E} :
      Benitoite.Release.Ty.WF 0 C.length T →
      Benitoite.Release.Ty.WF 0 C.length E →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.raise T E) (.fn ["error"] [E] T (Benitoite.Release.Eff.singleFail E))) []
  | V_Lam {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ names ps body r ε} :
      Benitoite.Release.NamesWF names ps →
      Benitoite.Release.Ty.WF 0 C.length (.fn names ps r ε) →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.lam names ps body) (.fn names ps r ε)) [(.comp κ Ψ.hideBuilders Q C (Benitoite.Release.binds ps ++ Benitoite.Release.hideConts Γ) (some r) body r ε [])]
  | V_Con {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ c ts args cd} :
      P0.cons c = some cd →
      ts.length = cd.ntys →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.con c ts args) (.data cd.data ts)) [(.values κ Ψ Q C Γ args (cd.args.map (Benitoite.Release.Ty.subst ts [])))]
  | V_List {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ elems a} :
      Benitoite.Release.Ty.WF 0 C.length a →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.list elems) (.list a)) [(.each κ Ψ Q C Γ elems a)]
  | V_LocRef {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ l a} :
      Ψ l = some (.ref a) →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.loc l) (.reference a)) []
  | V_LocLazy {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ l a} :
      Ψ l = some (.lazy a) →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.loc l) (.lazy a)) []
  | V_Map {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ ks vs a b} :
      ks.length = vs.length →
      B0.sat C a Benitoite.Release.TParam.keyC →
      Benitoite.Release.Ty.WF 0 C.length a →
      Benitoite.Release.Ty.WF 0 C.length b →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.mapV ks vs) (.map a b)) [(.each κ Ψ Q C Γ ks a), (.each κ Ψ Q C Γ vs b)]
  | V_Set {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ elems a} :
      B0.sat C a Benitoite.Release.TParam.keyC →
      Benitoite.Release.Ty.WF 0 C.length a →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.setV elems) (.set a)) [(.each κ Ψ Q C Γ elems a)]
  | V_Bytes {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ bs} :
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.bytesV bs) .bytes) []
  | V_Dict {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ i ts vs id} :
      P0.impls i = some id →
      Benitoite.Release.SatAll B0 C ts id.tparams →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.dict i ts vs) (.dict id.cls (id.target.subst ts []))) [(.values κ Ψ Q C Γ vs (id.dictTys.map (Benitoite.Release.Ty.subst ts [])))]
  | V_Super {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ v cl τ cd s} :
      P0.classes cl = some cd →
      s ∈ cd.supers →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.super v s) (.dict s τ)) [(.value κ Ψ Q C Γ v (.dict cl τ))]
  | V_Sub {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ v a a'} :
      Benitoite.Release.Ty.Le a a' →
      Benitoite.Release.Ty.WF 0 C.length a' →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ v a') [(.value κ Ψ Q C Γ v a)]
  | V_Checked {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ o R t} :
      B0.valKind o = some t.kind →
      R.Mem t →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.checked t) (.opaque o (.fixed R))) []
  | V_CheckedRequest {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ o R t req T} :
      B0.valKind o = some t.kind →
      R.Mem t →
      B0.valContent o = some T →
      LegacyRule K P0 B0 (.value κ Ψ Q C Γ (.checkedRequest t req) (.opaque o (.fixed R))) [(.value [] Ψ Benitoite.Release.Qempty [] [] req T)]
  | Vs_nil {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ} :
      LegacyRule K P0 B0 (.values κ Ψ Q C Γ [] []) []
  | Vs_cons {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ v vs a as} :
      LegacyRule K P0 B0 (.values κ Ψ Q C Γ (v :: vs) (a :: as)) [(.value κ Ψ Q C Γ v a), (.values κ Ψ Q C Γ vs as)]
  | Each_nil {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ a} :
      LegacyRule K P0 B0 (.each κ Ψ Q C Γ [] a) []
  | Each_cons {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ v vs a} :
      LegacyRule K P0 B0 (.each κ Ψ Q C Γ (v :: vs) a) [(.value κ Ψ Q C Γ v a), (.each κ Ψ Q C Γ vs a)]
  | C_BuilderLet {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R kind body a ε} :
      Benitoite.Release.Ty.WF 0 C.length kind.contents →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.builderLet kind body) a ε Δ) [(.comp κ Ψ Q C (none :: Γ) R body a ε (some kind :: Δ))]
  | C_BuilderOp {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R kind op ref args} :
      Benitoite.Release.Ty.WF 0 C.length kind.contents →
      Benitoite.Release.LocalRef.HasKind Ψ Δ ref kind →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.builderOp kind op ref args) (op.result kind) Benitoite.Release.Eff.empty Δ) [(.values κ Ψ Q C Γ args (op.params kind))]
  | C_Return {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R v a} :
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.ret v) a Benitoite.Release.Eff.empty Δ) [(.value κ Ψ Q C Γ v a)]
  | C_Sub {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R m a a' ε ε'} :
      Benitoite.Release.Ty.Le a a' →
      Benitoite.Release.Eff.Covers ε' ε →
      Benitoite.Release.Ty.WF 0 C.length a' →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R m a' ε' Δ) [(.comp κ Ψ Q C Γ R m a ε Δ)]
  | C_Eff {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R m a ε ε'} :
      Benitoite.Release.Eff.Covers ε' ε →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R m a ε' Δ) [(.comp κ Ψ Q C Γ R m a ε Δ)]
  | C_Let {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R m n a b ε} :
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.letIn m n) b ε Δ) [(.comp κ Ψ Q C Γ R m a ε Δ), (.comp κ Ψ Q C (some a :: Γ) R n b ε (Benitoite.Release.LocalCtx.extend 1 Δ))]
  | C_App {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R f args names as b ε} :
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.app f args) b ε Δ) [(.value κ Ψ Q C Γ f (.fn names as b ε)), (.values κ Ψ Q C Γ args as)]
  | C_If {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R v m n a ε} :
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.ite v m n) a ε Δ) [(.value κ Ψ Q C Γ v (.base .boolean)), (.comp κ Ψ Q C Γ R m a ε Δ), (.comp κ Ψ Q C Γ R n a ε Δ)]
  | C_Match {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R v arms a b ε} :
      Benitoite.Release.Exhaustive P0 a (Benitoite.Release.unguardedPats arms) →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.match v arms) b ε Δ) [(.value κ Ψ Q C Γ v a), (.arms κ Ψ Q C Γ R arms a b ε Δ)]
  | C_Lazy {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R m a} :
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.lazyC m) (.lazy a) Benitoite.Release.Eff.empty Δ) [(.comp κ Ψ.hideBuilders Q C (Benitoite.Release.hideConts Γ) none m a Benitoite.Release.Eff.empty [])]
  | C_Escape {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ r v a ε} :
      Benitoite.Release.Ty.WF 0 C.length a →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ (some r) (.escape v) a ε Δ) [(.value κ Ψ Q C Γ v r)]
  | C_Use {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R v o m b ε} :
      B0.isResource o = true →
      Benitoite.Release.Eff.mem ε (.nameTop Benitoite.Release.stateEff) →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.use v m) b ε Δ) [(.value κ Ψ Q C Γ v (.opaqueTop o)), (.comp κ Ψ Q C Γ R m b ε Δ)]
  | C_Handle {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R m h t εm ε} :
      Benitoite.Release.Eff.Sub εm (Benitoite.Release.Eff.union ε (Benitoite.Release.handled P0 B0 h)) →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.handle m h) t ε Δ) [(.comp κ Ψ Q C Γ R m t εm Δ), (.clauses κ Ψ Q C Γ R εm h t ε Δ)]
  | C_Handle_Fail {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R m h t E eb Rest ec} :
      Benitoite.Release.Eff.Sub eb (Benitoite.Release.Eff.union (Benitoite.Release.Eff.singleFail E) Rest) →
      Benitoite.Release.NoFail Q Rest →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.handle m h) t (Benitoite.Release.Eff.union Rest ec) Δ) [(.comp κ Ψ Q C Γ R m t eb Δ), (.failure κ Ψ Q C Γ E R h t ec Δ)]
  | C_Resume {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R i v b t ε} :
      Γ[i]? = some (some (.cont b t ε)) →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.resume (.var i) v) t ε Δ) [(.value κ Ψ Q C Γ v b)]
  | C_ResumeL {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R l v b t ε} :
      Ψ l = some (.cont b t ε R) →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.resume (.loc l) v) t ε Δ) [(.value κ Ψ Q C Γ v b)]
  | C_Meth {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R v cl τ cd m ms ss es ws} :
      P0.classes cl = some cd →
      cd.methods m = some ms →
      Benitoite.Release.NamesWF ms.names ms.params →
      Benitoite.Release.SatAll B0 C ss ms.tparams →
      (∀ t ∈ ss ++ [τ], Benitoite.Release.Ty.WF 0 C.length t ∧ ∀ b r e, t ≠ .cont b r e) →
      Benitoite.Release.MethodRowsAdmissible C Q ms es →
      LegacyTypeInput K P0 ⟨K.methodParams cl m ++ [K.classArgument cl],
        ms.tparams ++ [({} : Benitoite.Release.TParam)], 0, 0⟩
        (.fn ms.names ms.params ms.ret ms.eff) .value →
      LegacyTypesInput K P0 ⟨κ, C, 0, Γ.length⟩ ss (K.methodParams cl m) →
      LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R (.meth v m ss es ws) (ms.ret.subst (ss ++ [τ]) es) (Benitoite.Release.Eff.substAt 0 (ss ++ [τ]) es ms.eff) Δ) [(.value κ Ψ Q C Γ v (.dict cl τ)), (.values κ Ψ Q C Γ ws (ms.params.map (Benitoite.Release.Ty.subst (ss ++ [τ]) es)))]
  | Arms_nil {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R a b ε} :
      Benitoite.Release.Ty.WF 0 C.length b →
      LegacyRule K P0 B0 (.arms κ Ψ Q C Γ R [] a b ε Δ) []
  | Arms_plain {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R alts body arms a b ε δ} :
      Benitoite.Release.AltsTy P0 alts a δ →
      LegacyRule K P0 B0 (.arms κ Ψ Q C Γ R (.mk alts none body :: arms) a b ε Δ) [(.comp κ Ψ Q C (Benitoite.Release.binds δ ++ Γ) R body b ε (Benitoite.Release.LocalCtx.extend δ.length Δ)), (.arms κ Ψ Q C Γ R arms a b ε Δ)]
  | Arms_guarded {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R alts guard body arms a b ε δ} :
      Benitoite.Release.AltsTy P0 alts a δ →
      LegacyRule K P0 B0 (.arms κ Ψ Q C Γ R (.mk alts (some guard) body :: arms) a b ε Δ) [(.comp κ Ψ Q C (Benitoite.Release.hideConts (Benitoite.Release.binds δ ++ Γ)) none guard (.base .boolean) Benitoite.Release.Eff.empty (Benitoite.Release.LocalCtx.extend δ.length Δ)), (.comp κ Ψ Q C (Benitoite.Release.binds δ ++ Γ) R body b ε (Benitoite.Release.LocalCtx.extend δ.length Δ)), (.arms κ Ψ Q C Γ R arms a b ε Δ)]
  | Clauses_nil {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R εb t ε} :
      LegacyRule K P0 B0 (.clauses κ Ψ Q C Γ R εb [] t ε Δ) []
  | Clauses_cons {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ R εb o n k body cs t ε sg} :
      Benitoite.Release.ClauseSig P0 B0 εb o sg →
      Benitoite.Release.NamesWF sg.names sg.params →
      n = sg.params.length →
      k = sg.tparams.length →
      Benitoite.Release.Eff.WF 0 C.length ε →
      LegacyRule K P0 B0 (.clauses κ Ψ Q C Γ R εb (.mk o n k body :: cs) t ε Δ) [(.comp (List.replicate sg.tparams.length .value ++ κ) Ψ.hideBuilders Q (sg.tparams ++ C) (some (.cont sg.ret (t.shift k 0) (Benitoite.Release.Eff.shift k 0 ε)) :: (Benitoite.Release.binds sg.params ++ Benitoite.Release.shiftEnv k Γ)) (R.map (Benitoite.Release.Ty.shift k 0)) body (t.shift k 0) (Benitoite.Release.Eff.shift k 0 ε) []), (.clauses κ Ψ Q C Γ R εb cs t ε Δ)]
  | Failure_one {κ : KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Δ Γ E R body t ec} :
      Benitoite.Release.Ty.WF 0 C.length E →
      Benitoite.Release.Ty.WF 0 C.length t →
      Benitoite.Release.Eff.WF 0 C.length ec →
      LegacyRule K P0 B0 (.failure κ Ψ Q C Γ E R [.fail E body] t ec Δ) [(.comp (.value :: κ) Ψ.hideBuilders Q (({} : Benitoite.Release.TParam) :: C) (none :: some (E.shift 1 0) :: Benitoite.Release.shiftEnv 1 Γ) (R.map (Benitoite.Release.Ty.shift 1 0)) body (t.shift 1 0) (Benitoite.Release.Eff.shift 1 0 ec) [])]

inductive LegacyOutputInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : LegacyJudgment → Prop where
  | node {j children} : LegacyRule K P0 B0 j children →
      LegacyNodeRegular K P0 B0 B j →
      (∀ child ∈ children, LegacyOutputInput K P0 B0 B child) →
      LegacyOutputInput K P0 B0 B j

theorem LegacyRule.old (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (j : LegacyJudgment) (children : List LegacyJudgment)
    (h : LegacyRule K P0 B0 j children)
    (hc : ∀ child ∈ children, child.OldHolds P0 B0) : j.OldHolds P0 B0 := by
  cases h with
  | @V_Var κ Ψ Q C Γ i a p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Var p0 p1
  | @V_Const κ Ψ Q C Γ c => exact Benitoite.Release.HasTypeVQ.V_Const
  | @V_Fun κ Ψ Q C Γ f d ts es p0 p1 p2 => exact Benitoite.Release.HasTypeVQ.V_Fun p0 p1 p2
  | @V_Prim κ Ψ Q C Γ b s rs ts es p0 p1 p2 p3 => exact Benitoite.Release.HasTypeVQ.V_Prim p0 p1 p2 p3
  | @V_Op κ Ψ Q C Γ o od ts p0 p1 p2 => exact Benitoite.Release.HasTypeVQ.V_Op p0 p1 p2
  | @V_Raise κ Ψ Q C Γ T E p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Raise p0 p1
  | @V_Lam κ Ψ Q C Γ names ps body r ε p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Lam p0 p1 (hc (.comp κ Ψ.hideBuilders Q C (Benitoite.Release.binds ps ++ Benitoite.Release.hideConts Γ) (some r) body r ε []) (by simp))
  | @V_Con κ Ψ Q C Γ c ts args cd p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Con p0 p1 (hc (.values κ Ψ Q C Γ args (cd.args.map (Benitoite.Release.Ty.subst ts []))) (by simp))
  | @V_List κ Ψ Q C Γ elems a p0 => exact Benitoite.Release.HasTypeVQ.V_List (hc (.each κ Ψ Q C Γ elems a) (by simp)) p0
  | @V_LocRef κ Ψ Q C Γ l a p0 => exact Benitoite.Release.HasTypeVQ.V_LocRef p0
  | @V_LocLazy κ Ψ Q C Γ l a p0 => exact Benitoite.Release.HasTypeVQ.V_LocLazy p0
  | @V_Map κ Ψ Q C Γ ks vs a b p0 p1 p2 p3 => exact Benitoite.Release.HasTypeVQ.V_Map (hc (.each κ Ψ Q C Γ ks a) (by simp)) (hc (.each κ Ψ Q C Γ vs b) (by simp)) p0 p1 p2 p3
  | @V_Set κ Ψ Q C Γ elems a p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Set (hc (.each κ Ψ Q C Γ elems a) (by simp)) p0 p1
  | @V_Bytes κ Ψ Q C Γ bs => exact Benitoite.Release.HasTypeVQ.V_Bytes
  | @V_Dict κ Ψ Q C Γ i ts vs id p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Dict p0 p1 (hc (.values κ Ψ Q C Γ vs (id.dictTys.map (Benitoite.Release.Ty.subst ts []))) (by simp))
  | @V_Super κ Ψ Q C Γ v cl τ cd s p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Super (hc (.value κ Ψ Q C Γ v (.dict cl τ)) (by simp)) p0 p1
  | @V_Sub κ Ψ Q C Γ v a a' p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Sub (hc (.value κ Ψ Q C Γ v a) (by simp)) p0 p1
  | @V_Checked κ Ψ Q C Γ o R t p0 p1 => exact Benitoite.Release.HasTypeVQ.V_Checked p0 p1
  | @V_CheckedRequest κ Ψ Q C Γ o R t req T p0 p1 p2 => exact Benitoite.Release.HasTypeVQ.V_CheckedRequest p0 p1 p2 (hc (.value [] Ψ Benitoite.Release.Qempty [] [] req T) (by simp))
  | @Vs_nil κ Ψ Q C Γ => exact Benitoite.Release.HasTypeVsQ.nil
  | @Vs_cons κ Ψ Q C Γ v vs a as => exact Benitoite.Release.HasTypeVsQ.cons (hc (.value κ Ψ Q C Γ v a) (by simp)) (hc (.values κ Ψ Q C Γ vs as) (by simp))
  | @Each_nil κ Ψ Q C Γ a => exact Benitoite.Release.HasTypeEachQ.nil
  | @Each_cons κ Ψ Q C Γ v vs a => exact Benitoite.Release.HasTypeEachQ.cons (hc (.value κ Ψ Q C Γ v a) (by simp)) (hc (.each κ Ψ Q C Γ vs a) (by simp))
  | @C_BuilderLet κ Ψ Q C Δ Γ R kind body a ε p0 => exact Benitoite.Release.HasTypeCQ.C_BuilderLet p0 (hc (.comp κ Ψ Q C (none :: Γ) R body a ε (some kind :: Δ)) (by simp))
  | @C_BuilderOp κ Ψ Q C Δ Γ R kind op ref args p0 p1 => exact Benitoite.Release.HasTypeCQ.C_BuilderOp p0 p1 (hc (.values κ Ψ Q C Γ args (op.params kind)) (by simp))
  | @C_Return κ Ψ Q C Δ Γ R v a => exact Benitoite.Release.HasTypeCQ.C_Return (hc (.value κ Ψ Q C Γ v a) (by simp))
  | @C_Sub κ Ψ Q C Δ Γ R m a a' ε ε' p0 p1 p2 => exact Benitoite.Release.HasTypeCQ.C_Sub (hc (.comp κ Ψ Q C Γ R m a ε Δ) (by simp)) p0 p1 p2
  | @C_Eff κ Ψ Q C Δ Γ R m a ε ε' p0 => exact Benitoite.Release.HasTypeCQ.C_Eff (hc (.comp κ Ψ Q C Γ R m a ε Δ) (by simp)) p0
  | @C_Let κ Ψ Q C Δ Γ R m n a b ε => exact Benitoite.Release.HasTypeCQ.C_Let (hc (.comp κ Ψ Q C Γ R m a ε Δ) (by simp)) (hc (.comp κ Ψ Q C (some a :: Γ) R n b ε (Benitoite.Release.LocalCtx.extend 1 Δ)) (by simp))
  | @C_App κ Ψ Q C Δ Γ R f args names as b ε => exact Benitoite.Release.HasTypeCQ.C_App (hc (.value κ Ψ Q C Γ f (.fn names as b ε)) (by simp)) (hc (.values κ Ψ Q C Γ args as) (by simp))
  | @C_If κ Ψ Q C Δ Γ R v m n a ε => exact Benitoite.Release.HasTypeCQ.C_If (hc (.value κ Ψ Q C Γ v (.base .boolean)) (by simp)) (hc (.comp κ Ψ Q C Γ R m a ε Δ) (by simp)) (hc (.comp κ Ψ Q C Γ R n a ε Δ) (by simp))
  | @C_Match κ Ψ Q C Δ Γ R v arms a b ε p0 => exact Benitoite.Release.HasTypeCQ.C_Match (hc (.value κ Ψ Q C Γ v a) (by simp)) (hc (.arms κ Ψ Q C Γ R arms a b ε Δ) (by simp)) p0
  | @C_Lazy κ Ψ Q C Δ Γ R m a => exact Benitoite.Release.HasTypeCQ.C_Lazy (hc (.comp κ Ψ.hideBuilders Q C (Benitoite.Release.hideConts Γ) none m a Benitoite.Release.Eff.empty []) (by simp))
  | @C_Escape κ Ψ Q C Δ Γ r v a ε p0 => exact Benitoite.Release.HasTypeCQ.C_Escape (hc (.value κ Ψ Q C Γ v r) (by simp)) p0
  | @C_Use κ Ψ Q C Δ Γ R v o m b ε p0 p1 => exact Benitoite.Release.HasTypeCQ.C_Use (hc (.value κ Ψ Q C Γ v (.opaqueTop o)) (by simp)) p0 (hc (.comp κ Ψ Q C Γ R m b ε Δ) (by simp)) p1
  | @C_Handle κ Ψ Q C Δ Γ R m h t εm ε p0 => exact Benitoite.Release.HasTypeCQ.C_Handle (hc (.comp κ Ψ Q C Γ R m t εm Δ) (by simp)) p0 (hc (.clauses κ Ψ Q C Γ R εm h t ε Δ) (by simp))
  | @C_Handle_Fail κ Ψ Q C Δ Γ R m h t E eb Rest ec p0 p1 => exact Benitoite.Release.HasTypeCQ.C_Handle_Fail (hc (.comp κ Ψ Q C Γ R m t eb Δ) (by simp)) p0 p1 (hc (.failure κ Ψ Q C Γ E R h t ec Δ) (by simp))
  | @C_Resume κ Ψ Q C Δ Γ R i v b t ε p0 => exact Benitoite.Release.HasTypeCQ.C_Resume p0 (hc (.value κ Ψ Q C Γ v b) (by simp))
  | @C_ResumeL κ Ψ Q C Δ Γ R l v b t ε p0 => exact Benitoite.Release.HasTypeCQ.C_ResumeL p0 (hc (.value κ Ψ Q C Γ v b) (by simp))
  | @C_Meth κ Ψ Q C Δ Γ R v cl τ cd m ms ss es ws p0 p1 p2 p3 p4 p5 _p6 _p7 => exact Benitoite.Release.HasTypeCQ.C_Meth (hc (.value κ Ψ Q C Γ v (.dict cl τ)) (by simp)) p0 p1 p2 p3 p4 p5 (hc (.values κ Ψ Q C Γ ws (ms.params.map (Benitoite.Release.Ty.subst (ss ++ [τ]) es))) (by simp))
  | @Arms_nil κ Ψ Q C Δ Γ R a b ε p0 => exact Benitoite.Release.HasTypeArmsQ.nil p0
  | @Arms_plain κ Ψ Q C Δ Γ R alts body arms a b ε δ p0 => exact Benitoite.Release.HasTypeArmsQ.plain p0 (hc (.comp κ Ψ Q C (Benitoite.Release.binds δ ++ Γ) R body b ε (Benitoite.Release.LocalCtx.extend δ.length Δ)) (by simp)) (hc (.arms κ Ψ Q C Γ R arms a b ε Δ) (by simp))
  | @Arms_guarded κ Ψ Q C Δ Γ R alts guard body arms a b ε δ p0 => exact Benitoite.Release.HasTypeArmsQ.guarded p0 (hc (.comp κ Ψ Q C (Benitoite.Release.hideConts (Benitoite.Release.binds δ ++ Γ)) none guard (.base .boolean) Benitoite.Release.Eff.empty (Benitoite.Release.LocalCtx.extend δ.length Δ)) (by simp)) (hc (.comp κ Ψ Q C (Benitoite.Release.binds δ ++ Γ) R body b ε (Benitoite.Release.LocalCtx.extend δ.length Δ)) (by simp)) (hc (.arms κ Ψ Q C Γ R arms a b ε Δ) (by simp))
  | @Clauses_nil κ Ψ Q C Δ Γ R εb t ε => exact Benitoite.Release.HasTypeClausesQ.nil
  | @Clauses_cons κ Ψ Q C Δ Γ R εb o n k body cs t ε sg p0 p1 p2 p3 p4 => exact Benitoite.Release.HasTypeClausesQ.cons p0 p1 p2 p3 p4 (hc (.comp (List.replicate sg.tparams.length .value ++ κ) Ψ.hideBuilders Q (sg.tparams ++ C) (some (.cont sg.ret (t.shift k 0) (Benitoite.Release.Eff.shift k 0 ε)) :: (Benitoite.Release.binds sg.params ++ Benitoite.Release.shiftEnv k Γ)) (R.map (Benitoite.Release.Ty.shift k 0)) body (t.shift k 0) (Benitoite.Release.Eff.shift k 0 ε) []) (by simp)) (hc (.clauses κ Ψ Q C Γ R εb cs t ε Δ) (by simp))
  | @Failure_one κ Ψ Q C Δ Γ E R body t ec p0 p1 p2 => exact Benitoite.Release.HasFailureClause.one p0 p1 p2 (hc (.comp (.value :: κ) Ψ.hideBuilders Q (({} : Benitoite.Release.TParam) :: C) (none :: some (E.shift 1 0) :: Benitoite.Release.shiftEnv 1 Γ) (R.map (Benitoite.Release.Ty.shift 1 0)) body (t.shift 1 0) (Benitoite.Release.Eff.shift 1 0 ec) []) (by simp))

theorem LegacyOutputInput.old {K P0 B0 B j}
    (h : LegacyOutputInput K P0 B0 B j) : j.OldHolds P0 B0 := by
  induction h with
  | node rule _ _ ih => exact rule.old K P0 B0 _ _ ih

theorem LegacyOutputInput.regular {K P0 B0 B j}
    (h : LegacyOutputInput K P0 B0 B j) : LegacyNodeRegular K P0 B0 B j := by
  cases h with
  | node _ regular _ => exact regular

end
end Benitoite.Release.Refinement
