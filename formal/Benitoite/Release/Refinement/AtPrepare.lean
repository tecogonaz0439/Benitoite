import Benitoite.Release.Refinement.AtInput
import Benitoite.Release.Refinement.Capture
import Benitoite.Release.Refinement.Ground

/-! # Atの準備

準備は渡されたtokenだけを使う。実行のσを参照せず、未具体化の範囲変数をErrorにする。
-/
namespace Benitoite.Release.Refinement
open Scope.Domain

mutual
  def groundTy : Ty → Bool
    | .base _ | .bytes => true
    | .data _ ts => groundTys ts
    | .list a => groundTy a
    | _ => false
  def groundTys : List Ty → Bool
    | [] => true
    | a :: ts => groundTy a && groundTys ts
end
mutual
  def groundVal : Val → Bool
    | .const _ | .bytesV _ => true
    | .list vs => groundVals vs
    | .con _ ts vs => groundTys ts && groundVals vs
    | _ => false
  def groundVals : List Val → Bool
    | [] => true
    | v :: vs => groundVal v && groundVals vs
end

mutual
  theorem groundTy_wf {a : Ty} (h : groundTy a = true) : a.WF 0 nt nv := by
    cases a <;> simp only [groundTy, Bool.false_eq_true] at h <;> try contradiction
    all_goals try trivial
    case data d ts => exact groundTys_wf h
    case list a => exact groundTy_wf (a := a) h
  theorem groundTys_wf {ts : List Ty} (h : groundTys ts = true) : Ty.WFList 0 nt nv ts := by
    cases ts with
    | nil => trivial
    | cons a ts =>
      simp only [groundTys, Bool.and_eq_true] at h
      exact ⟨groundTy_wf h.1, groundTys_wf h.2⟩
end
mutual
  theorem groundVal_ground {v : Val} (h : groundVal v = true) : v.Ground := by
    cases v <;> simp only [groundVal, Bool.false_eq_true] at h <;> try contradiction
    all_goals try trivial
    case list vs => exact groundVals_closed h
    case con c ts vs =>
      simp only [Bool.and_eq_true] at h
      exact ⟨by
        intro a ha
        exact (Ty.wfList_iff.mp (groundTys_wf h.1)) a ha,
        groundVals_closed h.2⟩
  theorem groundVals_closed {vs : List Val} (h : groundVals vs = true) : Val.ClosedList 0 0 vs := by
    cases vs with
    | nil => trivial
    | cons v vs =>
      simp only [groundVals, Bool.and_eq_true] at h
      exact ⟨groundVal_ground h.1, groundVals_closed h.2⟩
end

def AtRequest (B : Builtins) (name : OpaqueName) (v : Val) : Option Val :=
  match B.valContent name with | none => none | some _ => some v

private structure PreparationError where
  detail : AtError
  notStatic : detail.failure ≠ .staticIndex

private def prepareError (σ : Option PathEnv) (p : RangeExpr) (t : TargetInput)
    (f : AtFailure) (hf : f ≠ .staticIndex) : PreparationError :=
  ⟨atDetail σ p t f, hf⟩

noncomputable section
private def prepareCore (B : Builtins) (cap : Capture) (kind : Kind) (name : OpaqueName)
    (bases : Option Val) (pattern input : Val) (bound : RangeExpr) :
    Except PreparationError (Option PathEnv × RangeExpr × TargetInput) := do
  let pval := closeVal cap pattern
  let ival := closeVal cap input
  let pat ← match parseAtPattern kind pval with
    | none => .error (prepareError none .top (.absolute (.path [])) .invalidPattern (by decide))
    | some r => .ok r
  let target ← match B.valContent name with
    | none => match parseAtInput kind ival with
      | none => .error (prepareError none pat (.absolute (.path [])) .invalidTarget (by decide))
      | some t => .ok t
    | some _ => (if groundVal ival then
        match ival.reqTarget with
        | none => .error (prepareError none pat (.absolute (.path [])) .invalidTarget (by decide))
        | some t => .ok (.absolute t)
      else .error (prepareError none pat (.absolute (.path [])) .invalidTarget (by decide)))
  let snapshot ← match bases with
    | none => .ok none
    | some b => match closeVal cap b with
      | .pathBases σ => (if σ.Valid then .ok (some σ)
          else .error (prepareError none pat target .invalidTarget (by decide)))
      | _ => .error (prepareError none pat target .invalidTarget (by decide))
  if B.valKind name ≠ some kind then
    .error (prepareError snapshot pat target .invalidTarget (by decide))
  else if ¬ (bound.FitsKind kind ∧ bound.WF ∧ bound.Canonical) then
    .error (prepareError snapshot pat target .invalidPattern (by decide))
  else match snapshot, pat, target, bound with
    | none, .based b _, _, _ => .error (prepareError snapshot pat target (.unbound b) (by intro h; cases h))
    | none, .secrets, _, _ => .error (prepareError snapshot pat target .secretsUnbound (by decide))
    | none, _, .homePath _, _ => .error (prepareError snapshot pat target (.unbound .home) (by decide))
    | none, _, .relativePath _, _ => .error (prepareError snapshot pat target (.unbound .cwd) (by decide))
    | none, _, _, .based b _ => .error (prepareError snapshot pat target (.unbound b) (by intro h; cases h))
    | none, _, _, .secrets => .error (prepareError snapshot pat target .secretsUnbound (by decide))
    | _, _, _, _ => .ok (snapshot, pat, target)

def AtPrepare (B : Builtins) (cap : Capture) (kind : Kind) (name : OpaqueName)
    (bases : Option Val) (pattern input : Val) (index : RangeIx) :
    Except AtError (Option PathEnv × RangeExpr × TargetInput × RangeExpr) :=
  match index with
  | .rvar _ => .error (atDetail none .top (.absolute (.path [])) .staticIndex)
  | .fixed bound => match prepareCore B cap kind name bases pattern input bound with
    | .error e => .error e.detail
    | .ok (snapshot, pat, target) => .ok (snapshot, pat, target, bound)

def AtPrepared (B : Builtins) (cap : Capture) (kind : Kind) (name : OpaqueName)
    (bases : Option Val) (pattern input : Val) (index : RangeIx)
    (snapshot : Option PathEnv) (pat : RangeExpr) (target : TargetInput) (bound : RangeExpr) : Prop :=
  AtPrepare B cap kind name bases pattern input index = .ok (snapshot, pat, target, bound)

theorem AtPrepared.fixed_index {B cap kind name bases pattern input index snapshot pat target bound}
    (h : AtPrepared B cap kind name bases pattern input index snapshot pat target bound) :
    index = .fixed bound := by
  cases index with
  | rvar i => cases h
  | fixed r =>
    unfold AtPrepared AtPrepare at h
    cases he : prepareCore B cap kind name bases pattern input r with
    | error e => simp [he] at h
    | ok value => rcases value with ⟨σ,p,t⟩; simp only [he, Except.ok.injEq, Prod.mk.injEq] at h; exact congrArg RangeIx.fixed h.2.2.2

theorem AtPrepare.fixed_index {index : RangeIx} (h : index.WF 0) : ∃ bound, index = .fixed bound := by
  cases index with
  | fixed r => exact ⟨r, rfl⟩
  | rvar i => exact False.elim (Nat.not_lt_zero i h)

theorem AtPrepare.no_staticIndex {B cap kind name bases pattern input index detail}
    (hw : index.WF 0) (h : AtPrepare B cap kind name bases pattern input index = .error detail) :
    detail.failure ≠ .staticIndex := by
  obtain ⟨r, rfl⟩ := AtPrepare.fixed_index hw
  unfold AtPrepare at h
  cases he : prepareCore B cap kind name bases pattern input r with
  | error e => simp only [he, Except.error.injEq] at h; cases h; exact e.notStatic
  | ok value => rcases value with ⟨σ,p,t⟩; simp [he] at h

end
end Benitoite.Release.Refinement
