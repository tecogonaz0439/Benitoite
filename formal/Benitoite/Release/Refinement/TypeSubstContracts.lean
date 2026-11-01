import Benitoite.Release.Refinement.ProgramWellFormed
import Benitoite.Release.Refinement.CaptureRegularity

/-! 型・行の閉じた像の入力。型付けの保存の結論を入力欄には含めない。 -/
namespace Benitoite.Release.Refinement

structure ClosedTypeSubstInput (P : Program) (B : Builtins)
    (C0 C1 : TypeCtx) (Γ : Ctx) (ts : List Ty) (es : List Eff) : Prop where
  typeCount : ts.length = C0.length
  typeWF : ∀ t ∈ ts, t.WF 0 0 0
  typeKinds : TypeArgsKinded P [] ts (TypeCtx.kinds C0)
  typeAnnotations : TypeAnnotations P [] [] ts
  constraints : SatAll B C1 ts (TypeCtx.constraints C0)
  rowWF : ∀ e ∈ es, e.WF 0 0 0
  rowAnnotations : RowAnnotations P [] [] es
  rowKinds : ∀ e ∈ es, kindsEff P [] e
  context : CaptureContextRegular P (C1 ++ C0) Γ

theorem ClosedTypeSubstInput.extend {P B C0 C1 Γ ts es a}
    (h : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ a) :
    ClosedTypeSubstInput P B C0 C1 (Γ.extend a) ts es :=
  { h with context := h.context.extend ha }

/-- 行像が空か、コードが実行時専用の構文を含まないソースである。 -/
def TypeSubstCode (es : List Eff) (source : Nat → Nat → Nat → Nat → Prop) : Prop :=
  es = [] ∨ ∃ nr nt ne nv, source nr nt ne nv

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_V : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ v a ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => v.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ v a →
  HasTypeVQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Val.substTyAt C1.length ts es) v) ((Ty.substAt C1.length ts es) a)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Vs : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ vs as ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => scopedValues nr nt ne nv vs) → RowTransport Q Q' es →
  HasTypeVsQ P B Ψ Q (C1 ++ C0) Γ Φ vs as →
  HasTypeVsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) (as.map (Ty.substAt C1.length ts es))

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Each : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ vs a ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => scopedValues nr nt ne nv vs) → RowTransport Q Q' es →
  HasTypeEachQ P B Ψ Q (C1 ++ C0) Γ Φ vs a →
  HasTypeEachQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) ((Ty.substAt C1.length ts es) a)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_C : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ R m a e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => m.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  HasTypeCQ P B Ψ Q (C1 ++ C0) Γ Φ R m a e L →
  HasTypeCQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) (m.substTyAt C1.length ts es) ((Ty.substAt C1.length ts es) a) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Args : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ vs t a e ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => scopedValues nr nt ne nv vs) → RowTransport Q Q' es →
  HasTypeTelArgsQ P B Ψ Q (C1 ++ C0) Γ Φ vs t a e →
  HasTypeTelArgsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) ((Tel.substAt C1.length ts es) t) ((Ty.substAt C1.length ts es) a) ((Eff.substAt C1.length ts es) e)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Body : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ t m ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => m.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  TelBodyTy P B Ψ Q (C1 ++ C0) Γ Φ t m →
  TelBodyTy P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Tel.substAt C1.length ts es) t) (m.substTyAt C1.length ts es)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Capture : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {R Γ Φ cap},
  CaptureOk P B Ψ R Γ Φ cap → CaptureOk P B Ψ R Γ Φ cap

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Closure : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {q t},
  DependentClosureTy P B Ψ q t → DependentClosureTy P B Ψ q t

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Witness : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {o k r snapshot target req},
  CheckedWitness P B Ψ o k r snapshot target req →
  CheckedWitness P B Ψ o k r snapshot target req

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_At : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ k o shape bases pattern input ix ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => (match bases with | none => True | some b => b.SourceScoped nr nt ne nv) ∧ pattern.SourceScoped nr nt ne nv ∧ input.SourceScoped nr nt ne nv) → RowTransport Q Q' es →
  AtCallAdmissible P B Ψ Q (C1 ++ C0) Γ Φ k o shape bases pattern input ix →
  AtCallAdmissible P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ k o shape (bases.map (Val.substTyAt C1.length ts es)) ((Val.substTyAt C1.length ts es) pattern) ((Val.substTyAt C1.length ts es) input) ix

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Arms : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ R obs arms a b e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => scopedArms nr nt ne nv arms) → RowTransport Q Q' es →
  HasTypeArmsQ P B Ψ Q (C1 ++ C0) Γ Φ R obs arms a b e L →
  HasTypeArmsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) obs ((Arm.substTyAtList C1.length ts es) arms) ((Ty.substAt C1.length ts es) a) ((Ty.substAt C1.length ts es) b) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Clauses : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ R eb clauses t e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => scopedClauses nr nt ne nv clauses) → RowTransport Q Q' es →
  HasTypeClausesQ P B Ψ Q (C1 ++ C0) Γ Φ R eb clauses t e L →
  HasTypeClausesQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) ((Eff.substAt C1.length ts es) eb) ((Clause.substTyAtList C1.length ts es) clauses) ((Ty.substAt C1.length ts es) t) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Failure : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ err R clauses t e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeSubstCode es (fun nr nt ne nv => scopedClauses nr nt ne nv clauses) → RowTransport Q Q' es →
  HasFailureClause P B Ψ Q (C1 ++ C0) Γ Φ err R clauses t e L →
  HasFailureClause P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Ty.substAt C1.length ts es) err) ((Option.map (Ty.substAt C1.length ts es)) R) ((Clause.substTyAtList C1.length ts es) clauses) ((Ty.substAt C1.length ts es) t) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L)

/-- 型置換の契約。全体の証明とは区別する。 -/
def S02_Image : Prop :=
  ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q C Γ Φ R ν i a},
  ImageOk P B Ψ Q C Γ Φ R ν i a → True

end Benitoite.Release.Refinement
