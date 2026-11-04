import Benitoite.Release.Refinement.ScopeSyntax

/-! # 固定した起点による有限の解決とAtの検査 -/
namespace Benitoite.Release.Refinement
open Scope.Domain

def RangeExpr.FitsKind (r : RangeExpr) (k : Scope.Domain.Kind) : Prop := match r with
  | .absolute r => r.FitsKind k
  | .based _ _ | .secrets => k = .path

def RangeExpr.WF : RangeExpr → Prop
  | .absolute r => r.WF
  | .based _ p => (Scope.Domain.Range.path p).WF
  | .secrets => True

def RangeExpr.Canonical : RangeExpr → Prop
  | .absolute r => r.Canonical
  | .based _ p => (Scope.Domain.Range.path p).Canonical
  | .secrets => True

instance (r : RangeExpr) (k : Kind) : Decidable (r.FitsKind k) := by
  cases r <;> unfold RangeExpr.FitsKind <;> infer_instance
instance (r : RangeExpr) : Decidable r.WF := by
  cases r <;> unfold RangeExpr.WF <;> infer_instance
instance (r : RangeExpr) : Decidable r.Canonical := by
  cases r <;> unfold RangeExpr.Canonical <;> infer_instance

def PathEnv.Valid (σ : PathEnv) : Prop :=
  PathWordWF σ.root ∧ PathWordWF σ.cwd ∧ PathWordWF σ.home ∧
  (∀ w ∈ σ.work, PathWordWF w) ∧ (∀ w ∈ σ.tmp, PathWordWF w) ∧
  (∀ ps ∈ σ.secrets, ∀ p ∈ ps, p.WF)
instance (σ : PathEnv) : Decidable σ.Valid := by unfold PathEnv.Valid; infer_instance

def PathEnv.lookup (σ : PathEnv) : PathBase → Option Word
  | .root => some σ.root | .cwd => some σ.cwd | .home => some σ.home
  | .work => σ.work | .tmp => σ.tmp

def PathEnv.Binds (σ : PathEnv) (b : PathBase) (w : Word) : Prop := σ.lookup b = some w

def PathPattern.atBase (base : Word) : PathPattern → PathPattern
  | .exact s => .exact (base ++ s)
  | .tree s => .tree (base ++ s)

def RangeExpr.resolve (σ : PathEnv) : RangeExpr → Option (List Range)
  | .absolute r => some [r]
  | .based b p => (σ.lookup b).map (fun w => [.path (PathPattern.atBase w p)])
  | .secrets => σ.secrets.map (List.map Range.path)

def TargetInput.resolve (σ : PathEnv) : TargetInput → Option Target
  | .absolute t => some t
  | .relativePath w => some (.path (σ.cwd ++ w))
  | .homePath w => some (.path (σ.home ++ w))

def RangeExpr.Mem (σ : PathEnv) (k : Kind) (r : RangeExpr) (t : Target) : Prop :=
  t.kind = k ∧ match r.resolve σ with
    | none => False
    | some rs => ∃ q ∈ rs, q.Mem t
instance (σ k r t) : Decidable (RangeExpr.Mem σ k r t) := by
  unfold RangeExpr.Mem
  cases r.resolve σ <;> infer_instance

def SnapshotMem (snapshot : Option PathEnv) (k : Kind) (r : RangeExpr) (t : Target) : Prop :=
  match snapshot with
  | none => match r with | .absolute q => q.MemK k t | _ => False
  | some σ => σ.Valid ∧ r.Mem σ k t
instance (snapshot k r t) : Decidable (SnapshotMem snapshot k r t) := by
  cases snapshot with
  | none => cases r <;> unfold SnapshotMem <;> infer_instance
  | some σ => unfold SnapshotMem; infer_instance

inductive AtResult where
  | ok (target : Target)
  | error (detail : AtCheckError)
  deriving DecidableEq

def RangeExpr.base? : RangeExpr → Option PathBase
  | .based b _ => some b | _ => none

def TargetInput.base? : TargetInput → Option PathBase
  | .relativePath _ => some .cwd | .homePath _ => some .home | _ => none

def resolveSnapshot (σ : Option PathEnv) (r : RangeExpr) : Option (List Range) :=
  match σ, r with
  | _, .absolute q => some [q]
  | some σ, r => r.resolve σ
  | none, _ => none

def resolveTargetSnapshot (σ : Option PathEnv) (t : TargetInput) : Option Target :=
  match σ, t with
  | _, .absolute t => some t
  | some σ, t => t.resolve σ
  | none, _ => none

def atDetail (σ : Option PathEnv) (p : RangeExpr) (t : TargetInput) (f : AtFailure) : AtCheckError :=
  ⟨f, p, t, resolveSnapshot σ p, resolveTargetSnapshot σ t, p.base?, t.base?⟩

private def missingRange (p : RangeExpr) : AtFailure := match p with
  | .based b _ => .unbound b | .secrets => .secretsUnbound | _ => .invalidPattern

def checkAt (σ : Option PathEnv) (k : Kind) (p : RangeExpr) (input : TargetInput)
    (bound : RangeExpr) : AtResult :=
  match resolveSnapshot σ p, resolveTargetSnapshot σ input, resolveSnapshot σ bound with
  | none, _, _ => .error (atDetail σ p input (missingRange p))
  | _, none, _ => .error (atDetail σ p input (.unbound (input.base?.getD .cwd)))
  | _, _, none => .error (atDetail σ p input (missingRange bound))
  | some ps, some t, some bs =>
    if ¬ t.WF ∨ t.kind ≠ k then .error (atDetail σ p input .invalidTarget)
    else if ¬ (p.WF ∧ bound.WF ∧ p.FitsKind k ∧ bound.FitsKind k) then
      .error (atDetail σ p input .invalidPattern)
    else if ¬ (∃ r ∈ ps, r.Mem t) then .error (atDetail σ p input .dynamicCondition)
    else if ¬ (∃ r ∈ bs, r.Mem t) then .error (atDetail σ p input .staticIndex)
    else .ok t

/-- 形成された条件と上限の検査は、形式不正を返さない。 -/
theorem checkAt.no_invalidPattern {σ k p input bound detail}
    (hp : p.WF ∧ p.FitsKind k) (hb : bound.WF ∧ bound.FitsKind k)
    (h : checkAt σ k p input bound = .error detail) :
    detail.failure ≠ .invalidPattern := by
  unfold checkAt at h
  split at h
  · cases p <;> simp_all [resolveSnapshot,RangeExpr.resolve,atDetail,missingRange] <;> cases h <;> simp
  · cases h; simp [atDetail]
  · cases bound <;> simp_all [resolveSnapshot,RangeExpr.resolve,atDetail,missingRange] <;> cases h <;> simp
  · split at h
    · cases h; simp [atDetail]
    · split at h
      · simp_all
      · split at h
        · cases h; simp [atDetail]
        · split at h
          · cases h; simp [atDetail]
          · cases h

end Benitoite.Release.Refinement
