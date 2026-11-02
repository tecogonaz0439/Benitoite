# L20 群 D の署名

2026-11-02。B_WORK は `6bef569230cf169bd1d8f6f7116a1a19dcdc4688`。各追加・変更の署名を実装前に記し、最終の型を Lean の環境と照合した。明示した本番宣言は222件（定義17・定理205、うち非公開3）である。定義の本体と case・相互帰納の合成以外の完全署名をここに残す。完全な222件の一覧は `<tmp>/signatures-full.md` に置き、大きさと SHA-256 を [results.md](results.md) に記す。公開の S02 の14定義はそのままである。

## 定義の本体

### TypeSubstTypingMotives.lean

```lean
def VGoal (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (v : Val) (a : Ty) : Prop :=
  ∀ {C0 C1 ts es Q'}, C = C1 ++ C0 →
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => v.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  HasTypeVQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Val.substTyAt C1.length ts es) v) ((Ty.substAt C1.length ts es) a)

def VsGoal (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (as : List Ty) : Prop :=
  ∀ {C0 C1 ts es Q'}, C = C1 ++ C0 →
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => scopedValues nr nt ne nv vs) → RowTransport Q Q' es →
  HasTypeVsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) (as.map (Ty.substAt C1.length ts es))

def EachGoal (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (a : Ty) : Prop :=
  ∀ {C0 C1 ts es Q'}, C = C1 ++ C0 →
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => scopedValues nr nt ne nv vs) → RowTransport Q Q' es →
  HasTypeEachQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) ((Ty.substAt C1.length ts es) a)

def CGoal (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (m : Comp) (a : Ty) (e : Eff) (L : LocalCtx) : Prop :=
  ∀ {C0 C1 ts es Q'}, C = C1 ++ C0 →
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => m.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  HasTypeCQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) (m.substTyAt C1.length ts es) ((Ty.substAt C1.length ts es) a) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (BuilderKind.substAt C1.length ts es))) L)

def ArgsGoal (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (t : Tel) (a : Ty) (e : Eff) : Prop :=
  ∀ {C0 C1 ts es Q'}, C = C1 ++ C0 →
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => scopedValues nr nt ne nv vs) → RowTransport Q Q' es →
  HasTypeTelArgsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) ((Tel.substAt C1.length ts es) t) ((Ty.substAt C1.length ts es) a) ((Eff.substAt C1.length ts es) e)

def BodyGoal (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (t : Tel) (m : Comp) : Prop :=
  ∀ {C0 C1 ts es Q'}, C = C1 ++ C0 →
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => m.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  TelBodyTy P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Tel.substAt C1.length ts es) t) (m.substTyAt C1.length ts es)

def AtGoal (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (k : Scope.Domain.Kind) (o : OpaqueName) (shape : ResultShape) (bases : Option Val) (pattern input : Val) (ix : RangeIx) : Prop :=
  ∀ {C0 C1 ts es Q'}, C = C1 ++ C0 →
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => (match bases with | none => True | some b => b.SourceScoped nr nt ne nv) ∧ pattern.SourceScoped nr nt ne nv ∧ input.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  AtCallAdmissible P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ k o shape (bases.map (Val.substTyAt C1.length ts es)) ((Val.substTyAt C1.length ts es) pattern) ((Val.substTyAt C1.length ts es) input) ix

def ArmsGoal (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (obs : Option Term) (arms : List Arm) (a b : Ty) (e : Eff) (L : LocalCtx) : Prop :=
  ∀ {C0 C1 ts es Q'}, C = C1 ++ C0 →
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => scopedArms nr nt ne nv arms) → RowTransport Q Q' es →
  HasTypeArmsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) obs ((Arm.substTyAtList C1.length ts es) arms) ((Ty.substAt C1.length ts es) a) ((Ty.substAt C1.length ts es) b) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (BuilderKind.substAt C1.length ts es))) L)

def ClausesGoal (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (eb : Eff) (clauses : List Clause) (t : Ty) (e : Eff) (L : LocalCtx) : Prop :=
  ∀ {C0 C1 ts es Q'}, C = C1 ++ C0 →
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => scopedClauses nr nt ne nv clauses) → RowTransport Q Q' es →
  HasTypeClausesQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) ((Eff.substAt C1.length ts es) eb) ((Clause.substTyAtList C1.length ts es) clauses) ((Ty.substAt C1.length ts es) t) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (BuilderKind.substAt C1.length ts es))) L)

def FailureGoal (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (err : Ty) (R : Option Ty) (clauses : List Clause) (t : Ty) (e : Eff) (L : LocalCtx) : Prop :=
  ∀ {C0 C1 ts es Q'}, C = C1 ++ C0 →
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => scopedClauses nr nt ne nv clauses) → RowTransport Q Q' es →
  HasFailureClause P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Ty.substAt C1.length ts es) err) ((Option.map (Ty.substAt C1.length ts es)) R) ((Clause.substTyAtList C1.length ts es) clauses) ((Ty.substAt C1.length ts es) t) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (BuilderKind.substAt C1.length ts es))) L)
```

### ContextNormEq.lean

```lean
def Ctx.NormEq (Γ Δ : Ctx) : Prop :=
  Γ.map (Option.map Ty.norm) = Δ.map (Option.map Ty.norm)
```

### TypeSubstMain.lean

```lean
def V : Prop :=
∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ v a ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => v.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ v a →
  HasTypeVQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Val.substTyAt C1.length ts es) v) ((Ty.substAt C1.length ts es) a)

def Vs : Prop :=
∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ vs as ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => scopedValues nr nt ne nv vs) → RowTransport Q Q' es →
  HasTypeVsQ P B Ψ Q (C1 ++ C0) Γ Φ vs as →
  HasTypeVsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) (as.map (Ty.substAt C1.length ts es))

def Each : Prop :=
∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ vs a ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => scopedValues nr nt ne nv vs) → RowTransport Q Q' es →
  HasTypeEachQ P B Ψ Q (C1 ++ C0) Γ Φ vs a →
  HasTypeEachQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) ((Ty.substAt C1.length ts es) a)

def Args : Prop :=
∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ vs t a e ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => scopedValues nr nt ne nv vs) → RowTransport Q Q' es →
  HasTypeTelArgsQ P B Ψ Q (C1 ++ C0) Γ Φ vs t a e →
  HasTypeTelArgsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) ((Tel.substAt C1.length ts es) t) ((Ty.substAt C1.length ts es) a) ((Eff.substAt C1.length ts es) e)

def At : Prop :=
∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ k o shape bases pattern input ix ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => (match bases with | none => True | some b => b.SourceScoped nr nt ne nv) ∧ pattern.SourceScoped nr nt ne nv ∧ input.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  AtCallAdmissible P B Ψ Q (C1 ++ C0) Γ Φ k o shape bases pattern input ix →
  AtCallAdmissible P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ k o shape (bases.map (Val.substTyAt C1.length ts es)) ((Val.substTyAt C1.length ts es) pattern) ((Val.substTyAt C1.length ts es) input) ix

def Failure : Prop :=
∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ err R clauses t e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (TypeSubstInput P B C0 C1 ts es) → TypeSubstCode es (fun nr nt ne nv => scopedClauses nr nt ne nv clauses) → RowTransport Q Q' es →
  HasFailureClause P B Ψ Q (C1 ++ C0) Γ Φ err R clauses t e L →
  HasFailureClause P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Ty.substAt C1.length ts es) err) ((Option.map (Ty.substAt C1.length ts es)) R) ((Clause.substTyAtList C1.length ts es) clauses) ((Ty.substAt C1.length ts es) t) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L)
```

## 76 case と14成分

完全署名の正は TypeSubstTyping.lean の各宣言である。76 case の補題を14成分の一つの相互帰納へ合成する。

ソース: 92,113バイト、SHA-256 `7f0a1d4502b0840d00ce82f7dc9e0c171904bfc0caf0cf7043bd9fe082d838d9`。

```text
case_V_Var
case_V_Const
case_V_Lam
case_V_DependentLam
case_V_Closure
case_V_Fun
case_V_Prim
case_V_Op
case_V_ExternalRef
case_V_ExternalHandle
case_V_PathBases
case_V_ScopePattern
case_V_Checked
case_V_CheckedRequest
case_V_CheckedAt
case_V_AtError
case_V_Map
case_V_Set
case_V_Dict
case_V_Raise
case_V_LocRef
case_V_LocLazy
case_V_Bytes
case_V_Con
case_V_Super
case_V_List
case_V_Sub
case_V_Normal
case_V_Refine
case_Vs_nil
case_Vs_cons
case_Each_nil
case_Each_cons
case_C_BuilderLet
case_C_BuilderOp
case_C_Return
case_C_Let
case_C_App
case_C_DependentApp
case_C_If
case_C_Match
case_C_Lazy
case_C_Escape
case_C_Use
case_C_Handle
case_C_Handle_Fail
case_C_Resume
case_C_ResumeL
case_C_ResumeNorm
case_C_ResumeLNorm
case_C_Normal
case_C_Meth
case_C_External
case_C_IssuePathBases
case_C_CheckAt
case_C_Sub
case_C_Eff
case_Args_done
case_Args_param
case_Body_done
case_Body_param
case_Capture_mk
case_Closure_mk
case_Witness_plain
case_Witness_request
case_At_mk
case_Arms_nil
case_Arms_plain
case_Arms_guarded
case_Clauses_nil
case_Clauses_cons
case_Failure_one
case_Image_ordinary
case_Image_hidden
case_Image_contLoc
case_Image_contVar
```

```text
deriveV
deriveVs
deriveEach
deriveC
deriveArgs
deriveBody
deriveCapture
deriveClosure
deriveWitness
deriveAt
deriveArms
deriveClauses
deriveFailure
deriveImage
```

## その他の完全署名

```lean
def Benitoite.Release.Refinement.S02Internal.VGoal :
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Ty → Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.VsGoal :
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              List Benitoite.Release.Refinement.Val → List Benitoite.Release.Refinement.Ty → Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.EachGoal :
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Ty → Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.CGoal :
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              Option Benitoite.Release.Refinement.Ty →
                Benitoite.Release.Refinement.Comp →
                  Benitoite.Release.Refinement.Ty →
                    Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.LocalCtx → Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.ArgsGoal :
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              List Benitoite.Release.Refinement.Val →
                Benitoite.Release.Refinement.Tel →
                  Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Eff → Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.BodyGoal :
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              Benitoite.Release.Refinement.Tel → Benitoite.Release.Refinement.Comp → Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.AtGoal :
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              Benitoite.Scope.Domain.Kind →
                Benitoite.Release.OpaqueName →
                  Benitoite.Release.Refinement.ResultShape →
                    Option Benitoite.Release.Refinement.Val →
                      Benitoite.Release.Refinement.Val →
                        Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.RangeIx → Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.ArmsGoal :
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              Option Benitoite.Release.Refinement.Ty →
                Option Benitoite.Release.Refinement.Term →
                  List Benitoite.Release.Refinement.Arm →
                    Benitoite.Release.Refinement.Ty →
                      Benitoite.Release.Refinement.Ty →
                        Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.LocalCtx → Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.ClausesGoal :
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              Option Benitoite.Release.Refinement.Ty →
                Benitoite.Release.Refinement.Eff →
                  List Benitoite.Release.Refinement.Clause →
                    Benitoite.Release.Refinement.Ty →
                      Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.LocalCtx → Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.FailureGoal :
Benitoite.Release.Refinement.Program →
  Benitoite.Release.Refinement.Builtins →
    Benitoite.Release.Refinement.StoreTy →
      Benitoite.Release.NoFailCtx →
        Benitoite.Release.Refinement.TypeCtx →
          Benitoite.Release.Refinement.Ctx →
            List Benitoite.Release.Refinement.Pred →
              Benitoite.Release.Refinement.Ty →
                Option Benitoite.Release.Refinement.Ty →
                  List Benitoite.Release.Refinement.Clause →
                    Benitoite.Release.Refinement.Ty →
                      Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.LocalCtx → Prop
```

```lean
def Benitoite.Release.Refinement.Ctx.NormEq :
Benitoite.Release.Refinement.Ctx → Benitoite.Release.Refinement.Ctx → Prop
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.refl :
∀ (Γ : Benitoite.Release.Refinement.Ctx), Γ.NormEq Γ
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.symm :
∀ {Γ Δ : Benitoite.Release.Refinement.Ctx}, Γ.NormEq Δ → Δ.NormEq Γ
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.length :
∀ {Γ Δ : Benitoite.Release.Refinement.Ctx}, Γ.NormEq Δ → List.length Γ = List.length Δ
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.lookup :
∀ {Γ Δ : Benitoite.Release.Refinement.Ctx},
  Γ.NormEq Δ →
    ∀ {i : Nat} {a : Benitoite.Release.Refinement.Ty},
      Γ[i]? = some (some a) → ∃ b, Δ[i]? = some (some b) ∧ a.norm = b.norm
```

```lean
theorem Benitoite.Release.Refinement.substTyValues_var :
∀ (a : Benitoite.Release.Refinement.Ty),
  Benitoite.Release.Refinement.substTyValues Benitoite.Release.Refinement.Val.var a = a.norm
```

```lean
theorem Benitoite.Release.Refinement.substEffValues_var :
∀ (e : Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.substEffValues Benitoite.Release.Refinement.Val.var e = e.norm
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.valueImages :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ Δ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred},
  Γ.NormEq Δ → Benitoite.Release.Refinement.TypedValueImages P B Ψ Q C Γ Δ Φ Benitoite.Release.Refinement.Val.var
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.substOk :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ Δ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty},
  Γ.NormEq Δ →
    (∀ (i : Nat) (b t : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
        Γ[i]? = some (some (b.cont t e)) → ∃ b' t' e', Δ[i]? = some (some (b'.cont t' e'))) →
      Benitoite.Release.Refinement.SubstOk P B Ψ Q C Γ Φ Δ Φ R Benitoite.Release.Refinement.Val.var
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.sortMap :
∀ {Γ Δ : Benitoite.Release.Refinement.Ctx}, Γ.NormEq Δ → Benitoite.Release.Refinement.SortMap Γ Δ
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.declaration :
∀ {P : Benitoite.Release.Refinement.Program} {C : Benitoite.Release.Refinement.TypeCtx}
  {Γ Δ : Benitoite.Release.Refinement.Ctx} {B : Benitoite.Release.Refinement.Builtins},
  Γ.NormEq Δ →
    Benitoite.Release.Refinement.DeclarationImages P C Γ Δ fun i => some (Benitoite.Release.Refinement.Term.var i)
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.annotation :
∀ {P : Benitoite.Release.Refinement.Program} {C : Benitoite.Release.Refinement.TypeCtx}
  {Γ Δ : Benitoite.Release.Refinement.Ctx} {a : Benitoite.Release.Refinement.Ty}
  {B : Benitoite.Release.Refinement.Builtins},
  Γ.NormEq Δ → Benitoite.Release.Refinement.Ty.Annotation P C Γ a → Benitoite.Release.Refinement.Ty.Annotation P C Δ a
```

```lean
theorem Benitoite.Release.Refinement.Ctx.facts_map_norm :
∀ (Γ : Benitoite.Release.Refinement.Ctx),
  Benitoite.Release.Refinement.Ctx.facts (List.map (Option.map Benitoite.Release.Refinement.Ty.norm) Γ) = Γ.facts
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.facts :
∀ {Γ Δ : Benitoite.Release.Refinement.Ctx}, Γ.NormEq Δ → Γ.facts = Δ.facts
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.shiftV :
∀ {Γ Δ : Benitoite.Release.Refinement.Ctx},
  Γ.NormEq Δ →
    ∀ (k c : Nat),
      Benitoite.Release.Refinement.Ctx.NormEq (List.map (Option.map (Benitoite.Release.Refinement.Ty.shiftV k c)) Γ)
        (List.map (Option.map (Benitoite.Release.Refinement.Ty.shiftV k c)) Δ)
```

```lean
theorem Benitoite.Release.Refinement.Ctx.norm_bindParams :
∀ (Γ : Benitoite.Release.Refinement.Ctx) (ps : List Benitoite.Release.Refinement.Ty),
  List.map (Option.map Benitoite.Release.Refinement.Ty.norm) (Benitoite.Release.Refinement.bindParams Γ ps) =
    Benitoite.Release.Refinement.bindParams (List.map (Option.map Benitoite.Release.Refinement.Ty.norm) Γ)
      (List.map Benitoite.Release.Refinement.Ty.norm ps)
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.params :
∀ {Γ Δ : Benitoite.Release.Refinement.Ctx},
  Γ.NormEq Δ →
    ∀ (ps : List Benitoite.Release.Refinement.Ty),
      (Benitoite.Release.Refinement.bindParams Γ ps).NormEq
        (Benitoite.Release.Refinement.bindParams Δ (List.map Benitoite.Release.Refinement.Ty.norm ps))
```

```lean
theorem Benitoite.Release.Refinement.Ctx.norm_hideConts :
∀ (Γ : Benitoite.Release.Refinement.Ctx),
  List.map (Option.map Benitoite.Release.Refinement.Ty.norm) (Benitoite.Release.Refinement.hideConts Γ) =
    Benitoite.Release.Refinement.hideConts (List.map (Option.map Benitoite.Release.Refinement.Ty.norm) Γ)
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.hide :
∀ {Γ Δ : Benitoite.Release.Refinement.Ctx},
  Γ.NormEq Δ → (Benitoite.Release.Refinement.hideConts Γ).NormEq (Benitoite.Release.Refinement.hideConts Δ)
```

```lean
theorem Benitoite.Release.Refinement.substKind_var :
∀ (b : Benitoite.Release.Refinement.BuilderKind),
  Benitoite.Release.Refinement.substKind Benitoite.Release.Refinement.Val.var b = b.norm
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.comp :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ Δ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {m : Benitoite.Release.Refinement.Comp} {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {L : Benitoite.Release.Refinement.LocalCtx},
  Γ.NormEq Δ →
    (∀ (i : Nat) (b t : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
        Γ[i]? = some (some (b.cont t e)) → ∃ b' t' e', Δ[i]? = some (some (b'.cont t' e'))) →
      Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P B →
        Ψ.WF →
          Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R m a e L →
            Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Δ Φ (Option.map Benitoite.Release.Refinement.Ty.norm R)
              (Benitoite.Release.Refinement.Comp.subst Benitoite.Release.Refinement.Val.var m) a.norm e.norm
              (List.map (Option.map Benitoite.Release.Refinement.BuilderKind.norm) L)
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.variable :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred} {i : Nat}
  {a : Benitoite.Release.Refinement.Ty} {Γ Δ : Benitoite.Release.Refinement.Ctx},
  Γ.NormEq Δ →
    Γ[i]? = some (some a) →
      Benitoite.Release.Refinement.Ordinary a →
        Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Δ Φ (Benitoite.Release.Refinement.Val.var i) a.norm
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.resume :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ Δ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {i : Nat} {v : Benitoite.Release.Refinement.Val}
  {b t : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {R : Option Benitoite.Release.Refinement.Ty} {L : Benitoite.Release.Refinement.LocalCtx},
  Γ.NormEq Δ →
    (∀ (i : Nat) (b t : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
        Γ[i]? = some (some (b.cont t e)) → ∃ b' t' e', Δ[i]? = some (some (b'.cont t' e'))) →
      Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P B →
        Ψ.WF →
          Γ[i]? = some (some (b.cont t e)) →
            Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v b →
              Benitoite.Release.Refinement.Ty.Declared P C Γ t →
                Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Δ Φ (Option.map Benitoite.Release.Refinement.Ty.norm R)
                  (Benitoite.Release.Refinement.Comp.resume (Benitoite.Release.Refinement.Val.var i)
                    (Benitoite.Release.Refinement.Val.subst Benitoite.Release.Refinement.Val.var v))
                  t.norm e.norm (List.map (Option.map Benitoite.Release.Refinement.BuilderKind.norm) L)
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.lambda :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ Δ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {ns : List String} {ps : List Benitoite.Release.Refinement.Ty}
  {body : Benitoite.Release.Refinement.Comp} {r : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.EffR},
  Γ.NormEq Δ →
    (∀ (i : Nat) (b t : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
        Γ[i]? = some (some (b.cont t e)) → ∃ b' t' e', Δ[i]? = some (some (b'.cont t' e'))) →
      Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P B →
        Ψ.WF →
          Benitoite.Release.Refinement.NamesWF ns ps →
            Benitoite.Release.Refinement.Ty.Annotation P C Γ (Benitoite.Release.Refinement.Ty.fn ns ps r e) →
              Benitoite.Release.Refinement.HasTypeCQ P B (Benitoite.Release.Refinement.hideBuilders Ψ) Q C
                  (Benitoite.Release.Refinement.bindParams (Benitoite.Release.Refinement.hideConts Γ) ps)
                  (Benitoite.Release.Refinement.liftMany ps.length Φ)
                  (some (Benitoite.Release.Refinement.Ty.shiftV ps.length 0 r)) body
                  (Benitoite.Release.Refinement.Ty.shiftV ps.length 0 r)
                  (Benitoite.Release.Refinement.Eff.shiftV ps.length 0 e) →
                Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Δ Φ
                  (Benitoite.Release.Refinement.Val.subst Benitoite.Release.Refinement.Val.var
                    (Benitoite.Release.Refinement.Val.lam ns ps body))
                  (Benitoite.Release.Refinement.Ty.fn ns ps r e).norm
```

```lean
theorem Benitoite.Release.Refinement.upSubst_var :
∀ (k : Nat),
  Benitoite.Release.Refinement.upSubst k Benitoite.Release.Refinement.Val.var = Benitoite.Release.Refinement.Val.var
```

```lean
theorem Benitoite.Release.Refinement.Tel.bind_var :
∀ (t : Benitoite.Release.Refinement.Tel),
  Benitoite.Release.Refinement.Tel.bind (Benitoite.Release.Refinement.valEnv Benitoite.Release.Refinement.Val.var) t =
    t.norm
```

```lean
theorem Benitoite.Release.Refinement.norm_substTypeAt :
∀ (a : Benitoite.Release.Refinement.Ty) (c : Nat) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff),
  (Benitoite.Release.Refinement.substTypeAt c ts es a).norm = Benitoite.Release.Refinement.substTypeAt c ts es a
```

```lean
theorem Benitoite.Release.Refinement.norm_substRowAt :
∀ (e : Benitoite.Release.Refinement.Eff) (c : Nat) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff),
  (Benitoite.Release.Refinement.substRowAt c ts es e).norm = Benitoite.Release.Refinement.substRowAt c ts es e
```

```lean
theorem Benitoite.Release.Refinement.Tel.bind_normal :
∀ (t : Benitoite.Release.Refinement.Tel) (θ : Benitoite.Release.Refinement.SubstEnv),
  (Benitoite.Release.Refinement.Tel.bind θ t).norm = Benitoite.Release.Refinement.Tel.bind θ t
```

```lean
theorem Benitoite.Release.Refinement.Val.subst_var_typeSubst :
∀ (v : Benitoite.Release.Refinement.Val) (c : Nat) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.Val.subst Benitoite.Release.Refinement.Val.var
      (Benitoite.Release.Refinement.Val.substTyAt c ts es v) =
    Benitoite.Release.Refinement.Val.substTyAt c ts es v
```

```lean
theorem Benitoite.Release.Refinement.Val.substList_var_typeSubst :
∀ (vs : List Benitoite.Release.Refinement.Val) (c : Nat) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.Val.substList Benitoite.Release.Refinement.Val.var
      (Benitoite.Release.Refinement.Val.substTyAtList c ts es vs) =
    Benitoite.Release.Refinement.Val.substTyAtList c ts es vs
```

```lean
theorem Benitoite.Release.Refinement.Comp.subst_var_typeSubst :
∀ (m : Benitoite.Release.Refinement.Comp) (c : Nat) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.Comp.subst Benitoite.Release.Refinement.Val.var
      (Benitoite.Release.Refinement.Comp.substTyAt c ts es m) =
    Benitoite.Release.Refinement.Comp.substTyAt c ts es m
```

```lean
theorem Benitoite.Release.Refinement.Arm.substList_var_typeSubst :
∀ (arms : List Benitoite.Release.Refinement.Arm) (c : Nat) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.Arm.substList Benitoite.Release.Refinement.Val.var
      (Benitoite.Release.Refinement.Arm.substTyAtList c ts es arms) =
    Benitoite.Release.Refinement.Arm.substTyAtList c ts es arms
```

```lean
theorem Benitoite.Release.Refinement.Clause.substList_var_typeSubst :
∀ (cs : List Benitoite.Release.Refinement.Clause) (c : Nat) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.Clause.substList Benitoite.Release.Refinement.Val.var
      (Benitoite.Release.Refinement.Clause.substTyAtList c ts es cs) =
    Benitoite.Release.Refinement.Clause.substTyAtList c ts es cs
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.typeSubst_comp :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ Δ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {e : Benitoite.Release.Refinement.Eff} {c : Nat}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {R : Option Benitoite.Release.Refinement.Ty} {m : Benitoite.Release.Refinement.Comp}
  {a : Benitoite.Release.Refinement.Ty} {L : Benitoite.Release.Refinement.LocalCtx},
  Γ.NormEq Δ →
    (∀ (i : Nat) (b t : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
        Γ[i]? = some (some (b.cont t e)) → ∃ b' t' e', Δ[i]? = some (some (b'.cont t' e'))) →
      Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P B →
        Ψ.WF →
          Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ
              (Option.map (Benitoite.Release.Refinement.Ty.substAt c ts es) R)
              (Benitoite.Release.Refinement.Comp.substTyAt c ts es m)
              (Benitoite.Release.Refinement.Ty.substAt c ts es a) (Benitoite.Release.Refinement.Eff.substAt c ts es e)
              (List.map (Option.map (Benitoite.Release.Refinement.BuilderKind.substAt c ts es)) L) →
            Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Δ Φ
              (Option.map (Benitoite.Release.Refinement.Ty.substAt c ts es) R)
              (Benitoite.Release.Refinement.Comp.substTyAt c ts es m)
              (Benitoite.Release.Refinement.Ty.substAt c ts es a) (Benitoite.Release.Refinement.Eff.substAt c ts es e)
              (List.map (Option.map (Benitoite.Release.Refinement.BuilderKind.substAt c ts es)) L)
```

```lean
theorem Benitoite.Release.Refinement.BuilderKind.substAt_eq :
∀ (c : Nat) (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff),
  (fun b =>
      match b with
      | Benitoite.Release.Refinement.BuilderKind.list a =>
        Benitoite.Release.Refinement.BuilderKind.list (Benitoite.Release.Refinement.Ty.substAt c ts es a)
      | Benitoite.Release.Refinement.BuilderKind.string => Benitoite.Release.Refinement.BuilderKind.string
      | Benitoite.Release.Refinement.BuilderKind.bytes => Benitoite.Release.Refinement.BuilderKind.bytes) =
    Benitoite.Release.Refinement.BuilderKind.substAt c ts es
```

```lean
private theorem Benitoite.Release.Refinement.substAtoms_rowfree :
∀ (es : List Benitoite.Release.Refinement.Eff) (a : Benitoite.Release.Refinement.Atom → Bool),
  (∀ (i : Nat), a (Benitoite.Release.Refinement.Atom.rho i) = false) → Benitoite.Release.Refinement.substAtoms es a = a
```

```lean
private theorem Benitoite.Release.Refinement.rowFails_rowfree :
∀ (es : List Benitoite.Release.Refinement.Eff) (a : Benitoite.Release.Refinement.Atom → Bool),
  (∀ (i : Nat), a (Benitoite.Release.Refinement.Atom.rho i) = false) → Benitoite.Release.Refinement.rowFails es a = []
```

```lean
theorem Benitoite.Release.Refinement.Ty.rawBind_rows_rowfree :
∀ (a : Benitoite.Release.Refinement.Ty),
  Benitoite.Release.Refinement.Ty.RowsIn (fun x => x < 0) a →
    ∀ (θ : Benitoite.Release.Refinement.SubstEnv) (rs ss : List Benitoite.Release.Refinement.Eff),
      Benitoite.Release.Refinement.Ty.rawBind { types := θ.types, rows := rs, ranges := θ.ranges, values := θ.values }
          a =
        Benitoite.Release.Refinement.Ty.rawBind { types := θ.types, rows := ss, ranges := θ.ranges, values := θ.values }
          a
```

```lean
theorem Benitoite.Release.Refinement.Ty.rawBindTys_rows_rowfree :
∀ (as : List Benitoite.Release.Refinement.Ty),
  Benitoite.Release.Refinement.Ty.RowsInList (fun x => x < 0) as →
    ∀ (θ : Benitoite.Release.Refinement.SubstEnv) (rs ss : List Benitoite.Release.Refinement.Eff),
      Benitoite.Release.Refinement.rawBindTys { types := θ.types, rows := rs, ranges := θ.ranges, values := θ.values }
          as =
        Benitoite.Release.Refinement.rawBindTys { types := θ.types, rows := ss, ranges := θ.ranges, values := θ.values }
          as
```

```lean
theorem Benitoite.Release.Refinement.Eff.rawBind_rows_rowfree :
∀ (e : Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.Eff.RowsIn (fun x => x < 0) e →
    ∀ (θ : Benitoite.Release.Refinement.SubstEnv) (rs ss : List Benitoite.Release.Refinement.Eff),
      Benitoite.Release.Refinement.Eff.rawBind { types := θ.types, rows := rs, ranges := θ.ranges, values := θ.values }
          e =
        Benitoite.Release.Refinement.Eff.rawBind
          { types := θ.types, rows := ss, ranges := θ.ranges, values := θ.values } e
```

```lean
theorem Benitoite.Release.Refinement.Tel.rawBind_rows_rowfree :
∀ (t : Benitoite.Release.Refinement.Tel),
  Benitoite.Release.Refinement.Tel.RowsIn (fun x => x < 0) t →
    ∀ (θ : Benitoite.Release.Refinement.SubstEnv) (rs ss : List Benitoite.Release.Refinement.Eff),
      Benitoite.Release.Refinement.Tel.rawBind { types := θ.types, rows := rs, ranges := θ.ranges, values := θ.values }
          t =
        Benitoite.Release.Refinement.Tel.rawBind
          { types := θ.types, rows := ss, ranges := θ.ranges, values := θ.values } t
```

```lean
theorem Benitoite.Release.Refinement.Ty.substAt_local_rowfree :
∀ {nr nv k c : Nat} (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
  (a : Benitoite.Release.Refinement.Ty),
  Benitoite.Release.Refinement.Ty.WF nr k nv a →
    Benitoite.Release.Refinement.Ty.RowsIn (fun x => x < 0) a →
      k ≤ c → Benitoite.Release.Refinement.Ty.substAt c ts es a = a.norm
```

```lean
theorem Benitoite.Release.Refinement.signatureTel.rows :
∀ {ns : List String} {ps : List Benitoite.Release.Refinement.Ty} {r : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {pe : Nat → Prop},
  Benitoite.Release.Refinement.NamesWF ns ps →
    Benitoite.Release.Refinement.Tel.RowsIn pe (Benitoite.Release.Refinement.signatureTel ns ps r e) →
      Benitoite.Release.Refinement.Ty.RowsInList pe ps ∧
        Benitoite.Release.Refinement.Ty.RowsIn pe r ∧ Benitoite.Release.Refinement.Eff.RowsIn pe e
```

```lean
theorem Benitoite.Release.Refinement.ClauseSig.localRows :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {e : Benitoite.Release.Refinement.Eff} {o : Benitoite.Release.OpRef} {sg : Benitoite.Release.Refinement.OpSig},
  P.WellFormed →
    Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
      Benitoite.Release.Refinement.ClauseSig P B e o sg →
        Benitoite.Release.Refinement.NamesWF sg.names sg.params →
          Benitoite.Release.Refinement.Ty.RowsInList (fun x => x < 0) sg.params ∧
            Benitoite.Release.Refinement.Ty.RowsIn (fun x => x < 0) sg.ret
```

```lean
theorem Benitoite.Release.Refinement.BinderTypes.LocalWF.substAt_local :
∀ {nt n c : Nat} {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {ps : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.BinderTypes.LocalWF nt n ps →
    Benitoite.Release.Refinement.Ty.RowsInList (fun x => x < 0) ps →
      nt ≤ c →
        List.map (Benitoite.Release.Refinement.Ty.substAt c ts es) ps = List.map Benitoite.Release.Refinement.Ty.norm ps
```

```lean
theorem Benitoite.Release.Refinement.OpSig.substAt_local :
∀ {sg : Benitoite.Release.Refinement.OpSig} {c : Nat} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff},
  sg.WF →
    Benitoite.Release.Refinement.Ty.RowsInList (fun x => x < 0) sg.params ∧
        Benitoite.Release.Refinement.Ty.RowsIn (fun x => x < 0) sg.ret →
      List.length sg.tparams ≤ c →
        Benitoite.Release.Refinement.OpSig.substAt c ts es sg =
          { tparams := sg.tparams, names := sg.names, params := List.map Benitoite.Release.Refinement.Ty.norm sg.params,
            ret := sg.ret.norm, eff := sg.eff }
```

```lean
theorem Benitoite.Release.Refinement.Ty.cont_of_norm_wf :
∀ {a b t : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff} {nr nt nv : Nat},
  Benitoite.Release.Refinement.Ty.WF nr nt nv a → a.norm = b.cont t e → ∃ b' t' e', a = b'.cont t' e'
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.extend :
∀ {Γ Δ : Benitoite.Release.Refinement.Ctx} {a b : Benitoite.Release.Refinement.Ty},
  Γ.NormEq Δ → a.norm = b.norm → (Γ.extend a).NormEq (Δ.extend b)
```

```lean
private theorem Benitoite.Release.Refinement.Ty.cont_of_shiftV :
∀ {a x y : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff} {n c : Nat},
  Benitoite.Release.Refinement.Ty.shiftV n c a = x.cont y e → ∃ x' y' e', a = x'.cont y' e'
```

```lean
theorem Benitoite.Release.Refinement.Ctx.continuations_extend :
∀ {Γ Δ : Benitoite.Release.Refinement.Ctx} {a b : Benitoite.Release.Refinement.Ty},
  (∀ (i : Nat) (x y : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
      Γ[i]? = some (some (x.cont y e)) → ∃ x' y' e', Δ[i]? = some (some (x'.cont y' e'))) →
    (∀ (x y : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.EffR),
        a = x.cont y e → ∃ x' y' e', b = x'.cont y' e') →
      ∀ (i : Nat) (x y : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
        (Γ.extend a)[i]? = some (some (x.cont y e)) → ∃ x' y' e', (Δ.extend b)[i]? = some (some (x'.cont y' e'))
```

```lean
theorem Benitoite.Release.Refinement.Ctx.NormEq.extendMany_local :
∀ {Γ Δ : Benitoite.Release.Refinement.Ctx} {ps : List Benitoite.Release.Refinement.Ty} {nt n : Nat},
  Γ.NormEq Δ →
    Benitoite.Release.Refinement.BinderTypes.LocalWF nt n ps →
      (Γ.extendMany (List.map Benitoite.Release.Refinement.Ty.norm ps)).NormEq (Δ.extendMany ps)
```

```lean
theorem Benitoite.Release.Refinement.Ctx.continuations_extendMany_local :
∀ {Γ Δ : Benitoite.Release.Refinement.Ctx} {ps : List Benitoite.Release.Refinement.Ty} {nt n : Nat},
  (∀ (i : Nat) (x y : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
      Γ[i]? = some (some (x.cont y e)) → ∃ x' y' e', Δ[i]? = some (some (x'.cont y' e'))) →
    Benitoite.Release.Refinement.BinderTypes.LocalWF nt n ps →
      ∀ (i : Nat) (x y : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
        (Γ.extendMany (List.map Benitoite.Release.Refinement.Ty.norm ps))[i]? = some (some (x.cont y e)) →
          ∃ x' y' e', (Δ.extendMany ps)[i]? = some (some (x'.cont y' e'))
```

```lean
theorem Benitoite.Release.Refinement.OpSig.context_normEq :
∀ (sg : Benitoite.Release.Refinement.OpSig),
  sg.WF →
    ∀ (Γ : Benitoite.Release.Refinement.Ctx) (t : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff),
      ({ tparams := sg.tparams, names := sg.names, params := List.map Benitoite.Release.Refinement.Ty.norm sg.params,
                ret := sg.ret.norm, eff := sg.eff }.context
            Γ t e).NormEq
        (sg.context Γ t e)
```

```lean
theorem Benitoite.Release.Refinement.OpSig.context_continuations :
∀ (sg : Benitoite.Release.Refinement.OpSig),
  sg.WF →
    ∀ (Γ : Benitoite.Release.Refinement.Ctx) (t : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (i : Nat) (b u : Benitoite.Release.Refinement.Ty)
      (f : Benitoite.Release.Refinement.Eff),
      ({ tparams := sg.tparams, names := sg.names, params := List.map Benitoite.Release.Refinement.Ty.norm sg.params,
                  ret := sg.ret.norm, eff := sg.eff }.context
              Γ t e)[i]? =
          some (some (b.cont u f)) →
        ∃ b' u' f', (sg.context Γ t e)[i]? = some (some (b'.cont u' f'))
```

```lean
theorem Benitoite.Release.Refinement.OpSig.typeSubst_body :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {C0 C1 : Benitoite.Release.Refinement.TypeCtx} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {c : Nat} {f : Benitoite.Release.Refinement.Eff}
  {R : Option Benitoite.Release.Refinement.Ty} {m : Benitoite.Release.Refinement.Comp}
  {a : Benitoite.Release.Refinement.Ty} {L : Benitoite.Release.Refinement.LocalCtx},
  Benitoite.Release.Refinement.TypeSubstInput P B C0 C1 ts es →
    ∀ (sg : Benitoite.Release.Refinement.OpSig),
      sg.WF →
        Benitoite.Release.Refinement.Ty.RowsInList (fun x => x < 0) sg.params ∧
            Benitoite.Release.Refinement.Ty.RowsIn (fun x => x < 0) sg.ret →
          Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P B →
            Ψ.WF →
              ∀ (t : Benitoite.Release.Refinement.Ty) (e : Benitoite.Release.Refinement.Eff),
                Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C
                    ((sg.context Γ t e).bindTypes
                      (Benitoite.Release.Refinement.typeEnvAt (c + List.length sg.tparams) ts es))
                    Φ (Option.map (Benitoite.Release.Refinement.Ty.substAt (c + List.length sg.tparams) ts es) R)
                    (Benitoite.Release.Refinement.Comp.substTyAt (c + List.length sg.tparams) ts es m)
                    (Benitoite.Release.Refinement.Ty.substAt (c + List.length sg.tparams) ts es a)
                    (Benitoite.Release.Refinement.Eff.substAt (c + List.length sg.tparams) ts es f)
                    (List.map
                      (Option.map (Benitoite.Release.Refinement.BuilderKind.substAt (c + List.length sg.tparams) ts es))
                      L) →
                  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C
                    (sg.context (Γ.bindTypes (Benitoite.Release.Refinement.typeEnvAt c ts es))
                      (Benitoite.Release.Refinement.Ty.substAt c ts es t)
                      (Benitoite.Release.Refinement.Eff.substAt c ts es e))
                    Φ (Option.map (Benitoite.Release.Refinement.Ty.substAt (c + List.length sg.tparams) ts es) R)
                    (Benitoite.Release.Refinement.Comp.substTyAt (c + List.length sg.tparams) ts es m)
                    (Benitoite.Release.Refinement.Ty.substAt (c + List.length sg.tparams) ts es a)
                    (Benitoite.Release.Refinement.Eff.substAt (c + List.length sg.tparams) ts es f)
                    (List.map
                      (Option.map (Benitoite.Release.Refinement.BuilderKind.substAt (c + List.length sg.tparams) ts es))
                      L)
```

```lean
theorem Benitoite.Release.Refinement.ClauseSig.substAt :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {e : Benitoite.Release.Refinement.Eff} {o : Benitoite.Release.OpRef} {sg : Benitoite.Release.Refinement.OpSig},
  Benitoite.Release.Refinement.ClauseSig P B e o sg →
    ∀ (c : Nat) (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff),
      Benitoite.Release.Refinement.ClauseSig P B (Benitoite.Release.Refinement.Eff.substAt c ts es e) o sg
```

```lean
theorem Benitoite.Release.Refinement.BuilderKind.contents_substAt :
∀ (b : Benitoite.Release.Refinement.BuilderKind) (c : Nat) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff),
  (Benitoite.Release.Refinement.BuilderKind.substAt c ts es b).contents =
    Benitoite.Release.Refinement.Ty.substAt c ts es b.contents
```

```lean
theorem Benitoite.Release.Refinement.BuilderOp.parameters_substAt :
∀ (op : Benitoite.Release.Refinement.BuilderOp) (b : Benitoite.Release.Refinement.BuilderKind) (c : Nat)
  (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff),
  op.parameters (Benitoite.Release.Refinement.BuilderKind.substAt c ts es b) =
    List.map (Benitoite.Release.Refinement.Ty.substAt c ts es) (op.parameters b)
```

```lean
theorem Benitoite.Release.Refinement.BuilderOp.resultType_substAt :
∀ (op : Benitoite.Release.Refinement.BuilderOp) (b : Benitoite.Release.Refinement.BuilderKind) (c : Nat)
  (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff),
  op.resultType (Benitoite.Release.Refinement.BuilderKind.substAt c ts es b) =
    Benitoite.Release.Refinement.Ty.substAt c ts es (op.resultType b)
```

```lean
theorem Benitoite.Release.Refinement.BuilderKind.substAt_norm_source :
∀ (b : Benitoite.Release.Refinement.BuilderKind) (c : Nat) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.BuilderKind.substAt c ts es b.norm =
    Benitoite.Release.Refinement.BuilderKind.substAt c ts es b
```

```lean
theorem Benitoite.Release.Refinement.LocalRef.HasKind.typeSubst :
∀ {Ψ : Benitoite.Release.Refinement.StoreTy} {L : Benitoite.Release.Refinement.LocalCtx}
  {r : Benitoite.Release.LocalRef} {b : Benitoite.Release.Refinement.BuilderKind} {c : Nat}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.LocalRef.HasKind Ψ L r b →
    Ψ.WF →
      (es = [] ∨ ∃ i, r = Benitoite.Release.LocalRef.bound i) →
        Benitoite.Release.Refinement.LocalRef.HasKind Ψ
          (List.map (Option.map (Benitoite.Release.Refinement.BuilderKind.substAt c ts es)) L) r
          (Benitoite.Release.Refinement.BuilderKind.substAt c ts es b)
```

```lean
theorem Benitoite.Release.Refinement.Eff.mem_union_iff :
∀ (e f : Benitoite.Release.Refinement.Eff) (a : Benitoite.Release.Refinement.Atom),
  (e.union f).mem a ↔ e.mem a ∨ f.mem a
```

```lean
theorem Benitoite.Release.Refinement.Eff.memFail_union_iff :
∀ (e f : Benitoite.Release.Refinement.Eff) (t : Benitoite.Release.Refinement.Ty),
  (e.union f).memFail t ↔ e.memFail t ∨ f.memFail t
```

```lean
theorem Benitoite.Release.Refinement.Eff.bind_union :
∀ (e f : Benitoite.Release.Refinement.Eff) (θ : Benitoite.Release.Refinement.SubstEnv),
  Benitoite.Release.Refinement.Eff.bind θ (e.union f) =
    (Benitoite.Release.Refinement.Eff.bind θ e).union (Benitoite.Release.Refinement.Eff.bind θ f)
```

```lean
theorem Benitoite.Release.Refinement.handled_typeSubst :
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (cs : List Benitoite.Release.Refinement.Clause) (c : Nat) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.handled P B (Benitoite.Release.Refinement.Clause.substTyAtList c ts es cs) =
    Benitoite.Release.Refinement.handled P B cs
```

```lean
theorem Benitoite.Release.Refinement.handled_substAt :
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (cs : List Benitoite.Release.Refinement.Clause) (c : Nat) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.Eff.substAt c ts es (Benitoite.Release.Refinement.handled P B cs) =
    Benitoite.Release.Refinement.handled P B cs
```

```lean
theorem Benitoite.Release.Refinement.Ty.Annotation.typeSubst_boolean :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {C0 C1 : Benitoite.Release.Refinement.TypeCtx}
  {Γ : Benitoite.Release.Refinement.Ctx} {p : Benitoite.Release.Refinement.Pred}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff},
  P.WellFormed ∧ P.WellTyped B ∧ Benitoite.Release.Refinement.Builtins.CoreAssumptions P B ∧ Ψ.WF →
    Benitoite.Release.Refinement.TypeSubstInput P B C0 C1 ts es →
      Benitoite.Release.Refinement.Ty.Annotation P (C1 ++ C0) Γ
          ((Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.boolean).refined p) →
        Benitoite.Release.Refinement.Ty.Annotation P C1
          (Γ.bindTypes (Benitoite.Release.Refinement.typeEnvAt (List.length C1) ts es))
          ((Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.boolean).refined p)
```

```lean
theorem Benitoite.Release.Refinement.Eff.substAt_union :
∀ (e f : Benitoite.Release.Refinement.Eff) (c : Nat) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.Eff.substAt c ts es (e.union f) =
    (Benitoite.Release.Refinement.Eff.substAt c ts es e).union (Benitoite.Release.Refinement.Eff.substAt c ts es f)
```

```lean
def Benitoite.Release.Refinement.S02Internal.V :
Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.Vs :
Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.Each :
Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.Args :
Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.At :
Prop
```

```lean
def Benitoite.Release.Refinement.S02Internal.Failure :
Prop
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.V.toPublic :
Benitoite.Release.Refinement.S02Internal.V → Benitoite.Release.Refinement.S02_V
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.Vs.toPublic :
Benitoite.Release.Refinement.S02Internal.Vs → Benitoite.Release.Refinement.S02_Vs
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.Each.toPublic :
Benitoite.Release.Refinement.S02Internal.Each → Benitoite.Release.Refinement.S02_Each
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.Args.toPublic :
Benitoite.Release.Refinement.S02Internal.Args → Benitoite.Release.Refinement.S02_Args
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.At.toPublic :
Benitoite.Release.Refinement.S02Internal.At → Benitoite.Release.Refinement.S02_At
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.Failure.toPublic :
Benitoite.Release.Refinement.S02Internal.Failure → Benitoite.Release.Refinement.S02_Failure
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.substV :
Benitoite.Release.Refinement.S02Internal.V
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.substVs :
Benitoite.Release.Refinement.S02Internal.Vs
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.substEach :
Benitoite.Release.Refinement.S02Internal.Each
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.substC :
Benitoite.Release.Refinement.S02Internal.C
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.substArgs :
Benitoite.Release.Refinement.S02Internal.Args
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.substBody :
Benitoite.Release.Refinement.S02Internal.Body
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.substAt :
Benitoite.Release.Refinement.S02Internal.At
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.substArms :
Benitoite.Release.Refinement.S02Internal.Arms
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.substClauses :
Benitoite.Release.Refinement.S02Internal.Clauses
```

```lean
theorem Benitoite.Release.Refinement.S02Internal.substFailure :
Benitoite.Release.Refinement.S02Internal.Failure
```

```lean
theorem Benitoite.Release.Refinement.type_subst_value :
Benitoite.Release.Refinement.S02_V
```

```lean
theorem Benitoite.Release.Refinement.type_subst_values :
Benitoite.Release.Refinement.S02_Vs
```

```lean
theorem Benitoite.Release.Refinement.type_subst_each :
Benitoite.Release.Refinement.S02_Each
```

```lean
theorem Benitoite.Release.Refinement.type_subst_comp :
Benitoite.Release.Refinement.S02_C
```

```lean
theorem Benitoite.Release.Refinement.type_subst_args :
Benitoite.Release.Refinement.S02_Args
```

```lean
theorem Benitoite.Release.Refinement.type_subst_body :
Benitoite.Release.Refinement.S02_Body
```

```lean
theorem Benitoite.Release.Refinement.type_subst_capture :
Benitoite.Release.Refinement.S02_Capture
```

```lean
theorem Benitoite.Release.Refinement.type_subst_closure :
Benitoite.Release.Refinement.S02_Closure
```

```lean
theorem Benitoite.Release.Refinement.type_subst_witness :
Benitoite.Release.Refinement.S02_Witness
```

```lean
theorem Benitoite.Release.Refinement.type_subst_at :
Benitoite.Release.Refinement.S02_At
```

```lean
theorem Benitoite.Release.Refinement.type_subst_arms :
Benitoite.Release.Refinement.S02_Arms
```

```lean
theorem Benitoite.Release.Refinement.type_subst_clauses :
Benitoite.Release.Refinement.S02_Clauses
```

```lean
theorem Benitoite.Release.Refinement.type_subst_failure :
Benitoite.Release.Refinement.S02_Failure
```

```lean
theorem Benitoite.Release.Refinement.type_subst_image :
Benitoite.Release.Refinement.S02_Image
```

```lean
theorem Benitoite.Release.Refinement.type_subst_all :
Benitoite.Release.Refinement.S02_V ∧
  Benitoite.Release.Refinement.S02_Vs ∧
    Benitoite.Release.Refinement.S02_Each ∧
      Benitoite.Release.Refinement.S02_C ∧
        Benitoite.Release.Refinement.S02_Args ∧
          Benitoite.Release.Refinement.S02_Body ∧
            Benitoite.Release.Refinement.S02_Capture ∧
              Benitoite.Release.Refinement.S02_Closure ∧
                Benitoite.Release.Refinement.S02_Witness ∧
                  Benitoite.Release.Refinement.S02_At ∧
                    Benitoite.Release.Refinement.S02_Arms ∧
                      Benitoite.Release.Refinement.S02_Clauses ∧
                        Benitoite.Release.Refinement.S02_Failure ∧ Benitoite.Release.Refinement.S02_Image
```

```lean
theorem Benitoite.Release.Refinement.CaptureContextRegular.empty :
∀ (P : Benitoite.Release.Refinement.Program) (C : Benitoite.Release.Refinement.TypeCtx),
  Benitoite.Release.Refinement.CaptureContextRegular P C []
```

```lean
theorem Benitoite.Release.Refinement.CaptureContextRegular.bindParams_empty :
∀ {P : Benitoite.Release.Refinement.Program} {C : Benitoite.Release.Refinement.TypeCtx}
  {ps : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.TypeAnnotations P C [] ps →
    Benitoite.Release.Refinement.CaptureContextRegular P C (Benitoite.Release.Refinement.bindParams [] ps)
```

```lean
theorem Benitoite.Release.Refinement.type_subst_fun_body :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Φ0 : List Benitoite.Release.Refinement.Pred}
  {callerTy : Benitoite.Release.Refinement.Ty} {f : Benitoite.Release.FunName} {d : Benitoite.Release.Refinement.Def}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff},
  P.WellFormed ∧ P.WellTyped B ∧ Benitoite.Release.Refinement.Builtins.CoreAssumptions P B →
    P.defs f = some d →
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] Φ0
          (Benitoite.Release.Refinement.Val.fnRef f ts es) callerTy →
        Benitoite.Release.Refinement.TelBodyTy P B Benitoite.Release.Refinement.StoreTy.empty Benitoite.Release.Qempty
          [] [] [] (Benitoite.Release.Refinement.Tel.substAt 0 ts es d.tel)
          (Benitoite.Release.Refinement.Comp.substTy ts es d.body)
```

```lean
theorem Benitoite.Release.Refinement.type_subst_method_body :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {L : Benitoite.Release.Refinement.LocalCtx} {i : Benitoite.Release.ImplName}
  {us : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val}
  {name : Benitoite.Release.MethName} {ss : List Benitoite.Release.Refinement.Ty}
  {fs : List Benitoite.Release.Refinement.Eff} {ws : List Benitoite.Release.Refinement.Val},
  P.WellFormed ∧ P.WellTyped B ∧ Benitoite.Release.Refinement.Builtins.CoreAssumptions P B ∧ Ψ.WF →
    Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q [] [] Φ R
        (Benitoite.Release.Refinement.Comp.meth (Benitoite.Release.Refinement.Val.dict i us vs) name ss fs ws) a e L →
      ∃ id cl cd ms body,
        P.impls i = some id ∧
          P.classes cl = some cd ∧
            cd.methods name = some ms ∧
              id.cls = cl ∧
                id.methods name = some body ∧
                  Benitoite.Release.Refinement.TelBodyTy P B Benitoite.Release.Refinement.StoreTy.empty Q []
                    ((Benitoite.Release.Refinement.bindParams []
                          (List.map (Benitoite.Release.Refinement.Ty.shift ms.tparams.length 0) id.dictTys)).bindTypes
                      (Benitoite.Release.Refinement.typeEnvAt 0 (ss ++ us) fs))
                    []
                    (Benitoite.Release.Refinement.Tel.substAt 0 (ss ++ us) fs
                      (Benitoite.Release.Refinement.Tel.shiftV id.dictTys.length 0
                        (Benitoite.Release.Refinement.Tel.bind
                          (Benitoite.Release.Refinement.typeEnvAt ms.tparams.length [id.target] []) ms.tel)))
                    (Benitoite.Release.Refinement.Comp.substTy (ss ++ us) fs body)
```

```lean
theorem Benitoite.Release.Refinement.HasTypeVQ.op_body_input :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpName} {ts : List Benitoite.Release.Refinement.Ty}
  {od : Benitoite.Release.Refinement.OpDecl},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a →
    C = [] →
      Γ = [] →
        v = Benitoite.Release.Refinement.Val.op o ts →
          P.ops o = some od →
            Benitoite.Release.Refinement.TypeSubstInput P B (Benitoite.Release.Refinement.TypeCtx.values od.tparams) []
              ts []
```

```lean
theorem Benitoite.Release.Refinement.type_subst_op_body :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {Φ0 : List Benitoite.Release.Refinement.Pred} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {body : Benitoite.Release.Refinement.Comp}
  {t : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {ts : List Benitoite.Release.Refinement.Ty} {callerTy : Benitoite.Release.Refinement.Ty}
  {o : Benitoite.Release.OpName} {eb : Benitoite.Release.Refinement.Eff} {R : Option Benitoite.Release.Refinement.Ty}
  {sg : Benitoite.Release.Refinement.OpSig},
  P.WellFormed ∧ P.WellTyped B ∧ Benitoite.Release.Refinement.Builtins.CoreAssumptions P B ∧ Ψ.WF →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] Φ0 (Benitoite.Release.Refinement.Val.op o ts) callerTy →
      Benitoite.Release.Refinement.ClauseSig P B eb (Benitoite.Release.OpRef.user o) sg →
        Benitoite.Release.Refinement.HasTypeCQ P B (Benitoite.Release.Refinement.hideBuilders Ψ) Q sg.tparams
            (sg.context Γ t e) (Benitoite.Release.Refinement.liftMany (sg.params.length + 1) Φ)
            (Option.map
              (fun r =>
                Benitoite.Release.Refinement.Ty.shiftV (sg.params.length + 1) 0
                  (Benitoite.Release.Refinement.shiftTypes (List.length sg.tparams) 0 r))
              R)
            body
            (Benitoite.Release.Refinement.Ty.shiftV (sg.params.length + 1) 0
              (Benitoite.Release.Refinement.shiftTypes (List.length sg.tparams) 0 t))
            (Benitoite.Release.Refinement.Eff.shiftV (sg.params.length + 1) 0
              (Benitoite.Release.Refinement.shiftRowsTypes (List.length sg.tparams) 0 e)) →
          Benitoite.Release.Refinement.HasTypeCQ P B (Benitoite.Release.Refinement.hideBuilders Ψ) Q []
            ((sg.context Γ t e).bindTypes (Benitoite.Release.Refinement.typeEnvAt 0 ts []))
            (Benitoite.Release.Refinement.liftMany (sg.params.length + 1) Φ)
            (Option.map (Benitoite.Release.Refinement.Ty.substAt 0 ts [])
              (Option.map
                (fun r =>
                  Benitoite.Release.Refinement.Ty.shiftV (sg.params.length + 1) 0
                    (Benitoite.Release.Refinement.shiftTypes (List.length sg.tparams) 0 r))
                R))
            (Benitoite.Release.Refinement.Comp.substTy ts [] body)
            (Benitoite.Release.Refinement.Ty.substAt 0 ts []
              (Benitoite.Release.Refinement.Ty.shiftV (sg.params.length + 1) 0
                (Benitoite.Release.Refinement.shiftTypes (List.length sg.tparams) 0 t)))
            (Benitoite.Release.Refinement.Eff.substAt 0 ts []
              (Benitoite.Release.Refinement.Eff.shiftV (sg.params.length + 1) 0
                (Benitoite.Release.Refinement.shiftRowsTypes (List.length sg.tparams) 0 e)))
```

```lean
theorem Benitoite.Release.Refinement.type_subst_opfail_body :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {Φ0 : List Benitoite.Release.Refinement.Pred} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T E0 Es callerTy : Benitoite.Release.Refinement.Ty}
  {body : Benitoite.Release.Refinement.Comp} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {R : Option Benitoite.Release.Refinement.Ty},
  P.WellFormed ∧ P.WellTyped B ∧ Benitoite.Release.Refinement.Builtins.CoreAssumptions P B ∧ Ψ.WF →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q [] [] Φ0 (Benitoite.Release.Refinement.Val.raise T E0) callerTy →
      Benitoite.Release.Refinement.HasTypeCQ P B (Benitoite.Release.Refinement.hideBuilders Ψ) Q
          [Benitoite.Release.Refinement.TypeCtx.valueParam] (Benitoite.Release.Refinement.failureContext Γ Es)
          (Benitoite.Release.Refinement.liftMany 2 Φ)
          (Option.map
            (fun r => Benitoite.Release.Refinement.Ty.shiftV 2 0 (Benitoite.Release.Refinement.shiftTypes 1 0 r)) R)
          body (Benitoite.Release.Refinement.Ty.shiftV 2 0 (Benitoite.Release.Refinement.shiftTypes 1 0 a))
          (Benitoite.Release.Refinement.Eff.shiftV 2 0 (Benitoite.Release.Refinement.shiftRowsTypes 1 0 e)) →
        Benitoite.Release.Refinement.HasTypeCQ P B (Benitoite.Release.Refinement.hideBuilders Ψ) Q []
          ((Benitoite.Release.Refinement.failureContext Γ Es).bindTypes
            (Benitoite.Release.Refinement.typeEnvAt 0 [T] []))
          (Benitoite.Release.Refinement.liftMany 2 Φ)
          (Option.map (Benitoite.Release.Refinement.Ty.substAt 0 [T] [])
            (Option.map
              (fun r => Benitoite.Release.Refinement.Ty.shiftV 2 0 (Benitoite.Release.Refinement.shiftTypes 1 0 r)) R))
          (Benitoite.Release.Refinement.Comp.substTy [T] [] body)
          (Benitoite.Release.Refinement.Ty.substAt 0 [T] []
            (Benitoite.Release.Refinement.Ty.shiftV 2 0 (Benitoite.Release.Refinement.shiftTypes 1 0 a)))
          (Benitoite.Release.Refinement.Eff.substAt 0 [T] []
            (Benitoite.Release.Refinement.Eff.shiftV 2 0 (Benitoite.Release.Refinement.shiftRowsTypes 1 0 e)))
```

```lean
theorem Benitoite.Release.Refinement.hideBuilders_idem :
∀ (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.hideBuilders (Benitoite.Release.Refinement.hideBuilders Ψ) =
    Benitoite.Release.Refinement.hideBuilders Ψ
```

```lean
theorem Benitoite.Release.Refinement.HasTypeVQ.fun_body_input :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {f : Benitoite.Release.FunName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {d : Benitoite.Release.Refinement.Def},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a →
    C = [] →
      Γ = [] →
        v = Benitoite.Release.Refinement.Val.fnRef f ts es →
          P.defs f = some d →
            Benitoite.Release.Refinement.SignatureInstance P [] [] d.tel
                (Benitoite.Release.Refinement.TypeCtx.kinds d.tparams) ts es ∧
              Benitoite.Release.Refinement.Admissible B [] 0
                (Benitoite.Release.Refinement.TypeCtx.constraints d.tparams) d.neffs
                (Benitoite.Release.Refinement.Qsig d.params d.ret d.eff) Q ts es d.eff
```

```lean
theorem Benitoite.Release.Refinement.HasTypeClausesQ.findClause_body :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {Rs : Option Benitoite.Release.Refinement.Ty}
  {eb : Benitoite.Release.Refinement.Eff} {cs : List Benitoite.Release.Refinement.Clause}
  {t : Benitoite.Release.Refinement.Ty} {ecs : Benitoite.Release.Refinement.Eff} {o : Benitoite.Release.OpRef}
  {c : Benitoite.Release.Refinement.Clause},
  Benitoite.Release.Refinement.HasTypeClausesQ P B Ψ Q [] Γ Φ Rs eb cs t ecs →
    Benitoite.Release.Refinement.findClause cs o = some c →
      ∃ sg n k body,
        c = Benitoite.Release.Refinement.Clause.mk o n k body ∧
          Benitoite.Release.Refinement.ClauseSig P B eb o sg ∧
            Benitoite.Release.Refinement.HasTypeCQ P B (Benitoite.Release.Refinement.hideBuilders Ψ) Q sg.tparams
              (sg.context Γ t ecs) (Benitoite.Release.Refinement.liftMany (sg.params.length + 1) Φ)
              (Option.map
                (fun r =>
                  Benitoite.Release.Refinement.Ty.shiftV (sg.params.length + 1) 0
                    (Benitoite.Release.Refinement.shiftTypes (List.length sg.tparams) 0 r))
                Rs)
              body
              (Benitoite.Release.Refinement.Ty.shiftV (sg.params.length + 1) 0
                (Benitoite.Release.Refinement.shiftTypes (List.length sg.tparams) 0 t))
              (Benitoite.Release.Refinement.Eff.shiftV (sg.params.length + 1) 0
                (Benitoite.Release.Refinement.shiftRowsTypes (List.length sg.tparams) 0 ecs))
```

```lean
theorem Benitoite.Release.Refinement.type_subst_e_op_site :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Φ0 : List Benitoite.Release.Refinement.Pred}
  {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {Rs : Option Benitoite.Release.Refinement.Ty} {ebs : Benitoite.Release.Refinement.Eff}
  {h : List Benitoite.Release.Refinement.Clause} {t : Benitoite.Release.Refinement.Ty}
  {ecs : Benitoite.Release.Refinement.Eff} {o : Benitoite.Release.OpName} {ts : List Benitoite.Release.Refinement.Ty}
  {c : Benitoite.Release.Refinement.Clause} {callerTy : Benitoite.Release.Refinement.Ty},
  P.WellFormed ∧ P.WellTyped B ∧ Benitoite.Release.Refinement.Builtins.CoreAssumptions P B ∧ Ψ.WF →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] Φ0
        (Benitoite.Release.Refinement.Val.op o ts) callerTy →
      Benitoite.Release.Refinement.HasTypeClausesQ P B (Benitoite.Release.Refinement.hideBuilders Ψ)
          Benitoite.Release.Qempty [] Γ Φ Rs ebs h t ecs →
        Benitoite.Release.Refinement.findClause h (Benitoite.Release.OpRef.user o) = some c →
          ∃ sg,
            Benitoite.Release.Refinement.HasTypeCQ P B (Benitoite.Release.Refinement.hideBuilders Ψ)
              Benitoite.Release.Qempty []
              ((sg.context Γ t ecs).bindTypes (Benitoite.Release.Refinement.typeEnvAt 0 ts []))
              (Benitoite.Release.Refinement.liftMany (sg.params.length + 1) Φ)
              (Option.map (Benitoite.Release.Refinement.Ty.substAt 0 ts [])
                (Option.map
                  (fun r =>
                    Benitoite.Release.Refinement.Ty.shiftV (sg.params.length + 1) 0
                      (Benitoite.Release.Refinement.shiftTypes (List.length sg.tparams) 0 r))
                  Rs))
              (Benitoite.Release.Refinement.Comp.substTy ts [] c.body)
              (Benitoite.Release.Refinement.Ty.substAt 0 ts []
                (Benitoite.Release.Refinement.Ty.shiftV (sg.params.length + 1) 0
                  (Benitoite.Release.Refinement.shiftTypes (List.length sg.tparams) 0 t)))
              (Benitoite.Release.Refinement.Eff.substAt 0 ts []
                (Benitoite.Release.Refinement.Eff.shiftV (sg.params.length + 1) 0
                  (Benitoite.Release.Refinement.shiftRowsTypes (List.length sg.tparams) 0 ecs)))
```

```lean
theorem Benitoite.Release.Refinement.type_subst_e_opfail_site :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Φ0 : List Benitoite.Release.Refinement.Pred}
  {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {Rs : Option Benitoite.Release.Refinement.Ty} {Es : Benitoite.Release.Refinement.Ty}
  {h : List Benitoite.Release.Refinement.Clause} {t : Benitoite.Release.Refinement.Ty}
  {ecs : Benitoite.Release.Refinement.Eff} {T E0 E : Benitoite.Release.Refinement.Ty}
  {body : Benitoite.Release.Refinement.Comp} {callerTy : Benitoite.Release.Refinement.Ty},
  P.WellFormed ∧ P.WellTyped B ∧ Benitoite.Release.Refinement.Builtins.CoreAssumptions P B ∧ Ψ.WF →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] Φ0
        (Benitoite.Release.Refinement.Val.raise T E0) callerTy →
      Benitoite.Release.Refinement.HasFailureClause P B (Benitoite.Release.Refinement.hideBuilders Ψ)
          Benitoite.Release.Qempty [] Γ Φ Es Rs h t ecs →
        h = [Benitoite.Release.Refinement.Clause.fail E body] →
          Benitoite.Release.Refinement.HasTypeCQ P B (Benitoite.Release.Refinement.hideBuilders Ψ)
            Benitoite.Release.Qempty []
            ((Benitoite.Release.Refinement.failureContext Γ Es).bindTypes
              (Benitoite.Release.Refinement.typeEnvAt 0 [T] []))
            (Benitoite.Release.Refinement.liftMany 2 Φ)
            (Option.map (Benitoite.Release.Refinement.Ty.substAt 0 [T] [])
              (Option.map
                (fun r => Benitoite.Release.Refinement.Ty.shiftV 2 0 (Benitoite.Release.Refinement.shiftTypes 1 0 r))
                Rs))
            (Benitoite.Release.Refinement.Comp.substTy [T] [] body)
            (Benitoite.Release.Refinement.Ty.substAt 0 [T] []
              (Benitoite.Release.Refinement.Ty.shiftV 2 0 (Benitoite.Release.Refinement.shiftTypes 1 0 t)))
            (Benitoite.Release.Refinement.Eff.substAt 0 [T] []
              (Benitoite.Release.Refinement.Eff.shiftV 2 0 (Benitoite.Release.Refinement.shiftRowsTypes 1 0 ecs)))
```

```lean
theorem Benitoite.Release.Refinement.Pred.Declared.typeSubst :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {C0 C1 : Benitoite.Release.Refinement.TypeCtx}
  {Γ : Benitoite.Release.Refinement.Ctx} {a : Benitoite.Release.Refinement.Ty} {p : Benitoite.Release.Refinement.Pred}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff},
  P.WellFormed ∧ P.WellTyped B ∧ Benitoite.Release.Refinement.Builtins.CoreAssumptions P B ∧ Ψ.WF →
    Benitoite.Release.Refinement.TypeSubstInput P B C0 C1 ts es →
      Benitoite.Release.Refinement.Pred.Declared P (C1 ++ C0) Γ (some a) p →
        Benitoite.Release.Refinement.Pred.Declared P C1
          (Γ.bindTypes (Benitoite.Release.Refinement.typeEnvAt (List.length C1) ts es))
          (some (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts es a)) p
```

```lean
theorem Benitoite.Release.Refinement.Pred.Sorted.typeSubst :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {C0 C1 : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {a : Benitoite.Release.Refinement.Ty} {p : Benitoite.Release.Refinement.Pred}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.TypeSubstInput P B C0 C1 ts es →
    Benitoite.Release.Refinement.Pred.Sorted Γ (some a) p →
      Benitoite.Release.Refinement.Pred.Sorted
        (Γ.bindTypes (Benitoite.Release.Refinement.typeEnvAt (List.length C1) ts es))
        (some (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts es a)) p
```

```lean
theorem Benitoite.Release.Refinement.Ctx.typeSubst_sortMap :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {C0 C1 : Benitoite.Release.Refinement.TypeCtx} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} (Γ : Benitoite.Release.Refinement.Ctx),
  Benitoite.Release.Refinement.TypeSubstInput P B C0 C1 ts es →
    Benitoite.Release.Refinement.SortMap Γ (Γ.bindTypes (Benitoite.Release.Refinement.typeEnvAt (List.length C1) ts es))
```

```lean
theorem Benitoite.Release.Refinement.FactsWF.typeSubst :
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {C0 C1 : Benitoite.Release.Refinement.TypeCtx}
  {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff},
  P.WellFormed ∧ P.WellTyped B ∧ Benitoite.Release.Refinement.Builtins.CoreAssumptions P B ∧ Ψ.WF →
    Benitoite.Release.Refinement.TypeSubstInput P B C0 C1 ts es →
      Benitoite.Release.Refinement.FactsWF P (C1 ++ C0) Γ Φ →
        Benitoite.Release.Refinement.FactsWF P C1
          (Γ.bindTypes (Benitoite.Release.Refinement.typeEnvAt (List.length C1) ts es)) Φ
```

## 節の結果型が `tvar 0` の検査

`normeq-check.lean` の具体例である。

```lean
theorem clauses_tvar0 {P B Ψ Q eb o}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hs : ClauseSig P B eb o signature) :
    HasTypeClausesQ P B Ψ Q [] [] [] none (Eff.substAt 0 [] [] eb)
      (Clause.substTyAtList 0 [] [] [.mk o 0 0 body]) (result.substAt 0 [] [])
      (Eff.substAt 0 [] [] Eff.empty) []
```
