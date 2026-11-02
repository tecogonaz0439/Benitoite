import Benitoite.Release.Refinement.TypeSubstBindings
import Benitoite.Release.Refinement.PatternTypeSubst

namespace Benitoite.Release.Refinement.S02Internal

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

end Benitoite.Release.Refinement.S02Internal
