import Benitoite.Release.Refinement.TypeSubstTyping

namespace Benitoite.Release.Refinement
namespace S02Internal

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

theorem V.toPublic (h : V) : S02_V :=
  fun hf hi hc hq ht => h hf hi.toTypeSubstInput hc hq ht

theorem Vs.toPublic (h : Vs) : S02_Vs :=
  fun hf hi hc hq ht => h hf hi.toTypeSubstInput hc hq ht

theorem Each.toPublic (h : Each) : S02_Each :=
  fun hf hi hc hq ht => h hf hi.toTypeSubstInput hc hq ht

theorem Args.toPublic (h : Args) : S02_Args :=
  fun hf hi hc hq ht => h hf hi.toTypeSubstInput hc hq ht

theorem At.toPublic (h : At) : S02_At :=
  fun hf hi hc hq ht => h hf hi.toTypeSubstInput hc hq ht

theorem Failure.toPublic (h : Failure) : S02_Failure :=
  fun hf hi hc hq ht => h hf hi.toTypeSubstInput hc hq ht

theorem substV : V := by
  intro P B Ψ Q Q' C0 C1 Γ Φ v a ts es hf hi hc hq ht
  exact deriveV P B Ψ Q (C1 ++ C0) Γ Φ v a ht rfl hf hi hc hq

theorem substVs : Vs := by
  intro P B Ψ Q Q' C0 C1 Γ Φ vs as ts es hf hi hc hq ht
  exact deriveVs P B Ψ Q (C1 ++ C0) Γ Φ vs as ht rfl hf hi hc hq

theorem substEach : Each := by
  intro P B Ψ Q Q' C0 C1 Γ Φ vs a ts es hf hi hc hq ht
  exact deriveEach P B Ψ Q (C1 ++ C0) Γ Φ vs a ht rfl hf hi hc hq

theorem substC : C := by
  intro P B Ψ Q Q' C0 C1 Γ Φ R m a e L ts es hf hi hc hq ht
  have out := deriveC P B Ψ Q (C1 ++ C0) Γ Φ R m a e L ht rfl hf hi hc hq
  apply Eq.mp ?_ out
  congr 1
  apply List.map_congr_left
  intro ob _
  cases ob with
  | none => rfl
  | some b => cases b <;> rfl

theorem substArgs : Args := by
  intro P B Ψ Q Q' C0 C1 Γ Φ vs t a e ts es hf hi hc hq ht
  exact deriveArgs P B Ψ Q (C1 ++ C0) Γ Φ vs t a e ht rfl hf hi hc hq

theorem substBody : Body := by
  intro P B Ψ Q Q' C0 C1 Γ Φ t m ts es hf hi hc hq ht
  exact deriveBody P B Ψ Q (C1 ++ C0) Γ Φ t m ht rfl hf hi hc hq

theorem substAt : At := by
  intro P B Ψ Q Q' C0 C1 Γ Φ k o shape bases pattern input ix ts es hf hi hc hq ht
  exact deriveAt P B Ψ Q (C1 ++ C0) Γ Φ k o shape bases pattern input ix ht rfl hf hi hc hq

theorem substArms : Arms := by
  intro P B Ψ Q Q' C0 C1 Γ Φ R obs arms a b e L ts es hf hi hc hq ht
  have out := deriveArms P B Ψ Q (C1 ++ C0) Γ Φ R obs arms a b e L ht rfl hf hi hc hq
  apply Eq.mp ?_ out
  congr 1
  apply List.map_congr_left
  intro ob _
  cases ob with
  | none => rfl
  | some b => cases b <;> rfl

theorem substClauses : Clauses := by
  intro P B Ψ Q Q' C0 C1 Γ Φ R eb clauses t e L ts es hf hi hc hq ht
  have out := deriveClauses P B Ψ Q (C1 ++ C0) Γ Φ R eb clauses t e L ht rfl hf hi hc hq
  apply Eq.mp ?_ out
  congr 1
  apply List.map_congr_left
  intro ob _
  cases ob with
  | none => rfl
  | some b => cases b <;> rfl

theorem substFailure : Failure := by
  intro P B Ψ Q Q' C0 C1 Γ Φ err R clauses t e L ts es hf hi hc hq ht
  have out := deriveFailure P B Ψ Q (C1 ++ C0) Γ Φ err R clauses t e L ht rfl hf hi hc hq
  apply Eq.mp ?_ out
  congr 1
  apply List.map_congr_left
  intro ob _
  cases ob with
  | none => rfl
  | some b => cases b <;> rfl

end S02Internal

theorem type_subst_value : S02_V := S02Internal.V.toPublic S02Internal.substV

theorem type_subst_values : S02_Vs := S02Internal.Vs.toPublic S02Internal.substVs

theorem type_subst_each : S02_Each := S02Internal.Each.toPublic S02Internal.substEach

theorem type_subst_comp : S02_C := S02Internal.C.toPublic S02Internal.substC

theorem type_subst_args : S02_Args := S02Internal.Args.toPublic S02Internal.substArgs

theorem type_subst_body : S02_Body := S02Internal.Body.toPublic S02Internal.substBody

theorem type_subst_capture : S02_Capture := by
  intro P B Ψ R Γ Φ cap h
  exact S02Internal.deriveCapture P B Ψ R Γ Φ cap h

theorem type_subst_closure : S02_Closure := by
  intro P B Ψ q t h
  exact S02Internal.deriveClosure P B Ψ q t h

theorem type_subst_witness : S02_Witness := by
  intro P B Ψ o k r snapshot target req h
  exact S02Internal.deriveWitness P B Ψ o k r snapshot target req h

theorem type_subst_at : S02_At := S02Internal.At.toPublic S02Internal.substAt

theorem type_subst_arms : S02_Arms := S02Internal.Arms.toPublic S02Internal.substArms

theorem type_subst_clauses : S02_Clauses := S02Internal.Clauses.toPublic S02Internal.substClauses

theorem type_subst_failure : S02_Failure := S02Internal.Failure.toPublic S02Internal.substFailure

theorem type_subst_image : S02_Image := by
  intro P B Ψ Q C Γ Φ R ν i a h
  exact S02Internal.deriveImage P B Ψ Q C Γ Φ R ν i a h

theorem type_subst_all : S02_V ∧ S02_Vs ∧ S02_Each ∧ S02_C ∧ S02_Args ∧ S02_Body ∧ S02_Capture ∧ S02_Closure ∧ S02_Witness ∧ S02_At ∧ S02_Arms ∧ S02_Clauses ∧ S02_Failure ∧ S02_Image :=
  ⟨type_subst_value, type_subst_values, type_subst_each, type_subst_comp, type_subst_args, type_subst_body, type_subst_capture, type_subst_closure, type_subst_witness, type_subst_at, type_subst_arms, type_subst_clauses, type_subst_failure, type_subst_image⟩

end Benitoite.Release.Refinement
