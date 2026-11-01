import Benitoite.Release.Refinement.TypeSubstContracts

namespace Benitoite.Release.Refinement.A3aContracts

-- S02_V
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ v a ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowTransport Q Q' es →
  HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ v a →
  HasTypeVQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Val.substTyAt C1.length ts es) v) ((Ty.substAt C1.length ts es) a))

-- S02_Vs
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ vs as ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowTransport Q Q' es →
  HasTypeVsQ P B Ψ Q (C1 ++ C0) Γ Φ vs as →
  HasTypeVsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) (as.map (Ty.substAt C1.length ts es)))

-- S02_Each
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ vs a ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowTransport Q Q' es →
  HasTypeEachQ P B Ψ Q (C1 ++ C0) Γ Φ vs a →
  HasTypeEachQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) ((Ty.substAt C1.length ts es) a))

-- S02_C
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ R m a e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowTransport Q Q' es →
  HasTypeCQ P B Ψ Q (C1 ++ C0) Γ Φ R m a e L →
  HasTypeCQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) (m.substTyAt C1.length ts es) ((Ty.substAt C1.length ts es) a) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L))

-- S02_Args
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ vs t a e ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowTransport Q Q' es →
  HasTypeTelArgsQ P B Ψ Q (C1 ++ C0) Γ Φ vs t a e →
  HasTypeTelArgsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((List.map (Val.substTyAt C1.length ts es)) vs) ((Tel.substAt C1.length ts es) t) ((Ty.substAt C1.length ts es) a) ((Eff.substAt C1.length ts es) e))

-- S02_Body
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ t m ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowTransport Q Q' es →
  TelBodyTy P B Ψ Q (C1 ++ C0) Γ Φ t m →
  TelBodyTy P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Tel.substAt C1.length ts es) t) (m.substTyAt C1.length ts es))

-- S02_Capture
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {R Γ Φ cap},
  CaptureOk P B Ψ R Γ Φ cap → CaptureOk P B Ψ R Γ Φ cap)

-- S02_Closure
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {q t},
  DependentClosureTy P B Ψ q t → DependentClosureTy P B Ψ q t)

-- S02_Witness
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {o k r snapshot target req},
  CheckedWitness P B Ψ o k r snapshot target req →
  CheckedWitness P B Ψ o k r snapshot target req)

-- S02_At
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ k o shape bases pattern input ix ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowTransport Q Q' es →
  AtCallAdmissible P B Ψ Q (C1 ++ C0) Γ Φ k o shape bases pattern input ix →
  AtCallAdmissible P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ k o shape (bases.map (Val.substTyAt C1.length ts es)) ((Val.substTyAt C1.length ts es) pattern) ((Val.substTyAt C1.length ts es) input) ix)

-- S02_Arms
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ R obs arms a b e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowTransport Q Q' es →
  HasTypeArmsQ P B Ψ Q (C1 ++ C0) Γ Φ R obs arms a b e L →
  HasTypeArmsQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) obs ((Arm.substTyAtList C1.length ts es) arms) ((Ty.substAt C1.length ts es) a) ((Ty.substAt C1.length ts es) b) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L))

-- S02_Clauses
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ R eb clauses t e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowTransport Q Q' es →
  HasTypeClausesQ P B Ψ Q (C1 ++ C0) Γ Φ R eb clauses t e L →
  HasTypeClausesQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Option.map (Ty.substAt C1.length ts es)) R) ((Eff.substAt C1.length ts es) eb) ((Clause.substTyAtList C1.length ts es) clauses) ((Ty.substAt C1.length ts es) t) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L))

-- S02_Failure
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ err R clauses t e L ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowTransport Q Q' es →
  HasFailureClause P B Ψ Q (C1 ++ C0) Γ Φ err R clauses t e L →
  HasFailureClause P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Ty.substAt C1.length ts es) err) ((Option.map (Ty.substAt C1.length ts es)) R) ((Clause.substTyAtList C1.length ts es) clauses) ((Ty.substAt C1.length ts es) t) ((Eff.substAt C1.length ts es) e) ((fun (L : LocalCtx) => L.map (Option.map (fun (b : BuilderKind) => match b with | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) L))

-- S02_Image
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q C Γ Φ R ν i a},
  ImageOk P B Ψ Q C Γ Φ R ν i a → True)

-- Ty.HasKind.closed_context
#check (∀ {P : Program} {K K' : KindCtx} {a : Ty} {k : TyKind} {nr nv : Nat},
  a.WF nr 0 nv → a.HasKind P K k → a.HasKind P K' k)

-- kindsEff.closed_context
#check (∀ {P : Program} {K K' : KindCtx} {e : Eff} {nr nv : Nat},
  e.WF nr 0 nv → kindsEff P K e → kindsEff P K' e)

-- Ty.HasKind.substAt
#check (∀ {P : Program} {C0 C1 : TypeCtx} {a : Ty} {k : TyKind} {ts : List Ty} {es : List Eff},
  a.HasKind P (TypeCtx.kinds (C1 ++ C0)) k →
  TypeArgsKinded P [] ts (TypeCtx.kinds C0) →
  (∀ e ∈ es, kindsEff P [] e) →
  (a.substAt C1.length ts es).HasKind P (TypeCtx.kinds C1) k)

-- Tel.kinded_substAt
#check (∀ {P C0 C1 t ts es},
  kindsTel P (TypeCtx.kinds (C1 ++ C0)) t → TypeArgsKinded P [] ts (TypeCtx.kinds C0) →
  (∀ e ∈ es, kindsEff P [] e) → kindsTel P (TypeCtx.kinds C1) (t.substAt C1.length ts es))

-- TypeArgsKinded.substAt
#check (∀ {P C0 C1 as ks ts es},
  TypeArgsKinded P (C1 ++ C0) as ks →
  TypeArgsKinded P [] ts (TypeCtx.kinds C0) → (∀ e ∈ es, kindsEff P [] e) →
  TypeArgsKinded P C1 (as.map (Ty.substAt C1.length ts es)) ks)

-- Ty.Declared.substAt
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {C0 C1 Γ a ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → Ty.Annotation P (C1 ++ C0) Γ a →
  Ty.Declared P C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) ((Ty.substAt C1.length ts es) a))

-- Tel.Declared.substAt
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {C0 C1 Γ t ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → Ty.Annotation P (C1 ++ C0) Γ (.dependentFn t) →
  Tel.Declared P C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) ((Tel.substAt C1.length ts es) t))

-- declaredTys_substAt
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {C0 C1 Γ as ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → TypeAnnotations P (C1 ++ C0) Γ as →
  declaredTys P C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) (as.map (Ty.substAt C1.length ts es)))

-- declaredEff_substAt
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {C0 C1 Γ e ts es},
  (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowAnnotations P (C1 ++ C0) Γ [e] →
  declaredEff P C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) ((Eff.substAt C1.length ts es) e))


end Benitoite.Release.Refinement.A3aContracts
