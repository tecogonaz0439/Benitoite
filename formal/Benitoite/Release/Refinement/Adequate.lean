import Benitoite.Release.Refinement.RuntimeSyntax
import Benitoite.Release.Refinement.Ground

/-! # 固定したσに由来する保持値

場所からストアを再帰して読まず、有限の値・捕捉環境・コードにあるsnapshotを検査する。
-/
namespace Benitoite.Release.Refinement

def SnapshotAdequate (σ : PathEnv) (snapshot : Option PathEnv) (r : RangeExpr) : Prop :=
  match snapshot with | some ρ => ρ = σ | none => ∃ q, r = .absolute q

mutual
  def Val.Adequate (σ : PathEnv) : Val → Prop
    | .pathBases ρ => ρ = σ
    | .checkedAt r snapshot _ req => SnapshotAdequate σ snapshot r ∧
        (match req with | none => True | some v => v.Adequate σ)
    | .checkedRequest _ v => v.Adequate σ
    | .lam _ _ m | .dependentLam _ m => m.Adequate σ
    | .closure _ q => q.Adequate σ
    | .con _ _ vs | .dict _ _ vs | .list vs | .setV vs => adequateVals σ vs
    | .mapV ks vs => adequateVals σ ks ∧ adequateVals σ vs
    | .super v _ => v.Adequate σ
    | _ => True
  def adequateVals (σ : PathEnv) : List Val → Prop
    | [] => True
    | v :: vs => v.Adequate σ ∧ adequateVals σ vs
  def Comp.Adequate (σ : PathEnv) : Comp → Prop
    | .builderLet _ m | .lazyC m => m.Adequate σ
    | .builderOp _ _ _ vs | .externalCall _ _ vs => adequateVals σ vs
    | .ret v | .escape v => v.Adequate σ
    | .letIn m n => m.Adequate σ ∧ n.Adequate σ
    | .app f vs | .meth f _ _ _ vs => f.Adequate σ ∧ adequateVals σ vs
    | .ite v m n => v.Adequate σ ∧ m.Adequate σ ∧ n.Adequate σ
    | .match v arms => v.Adequate σ ∧ adequateArms σ arms
    | .use v m => v.Adequate σ ∧ m.Adequate σ
    | .handle m cs => m.Adequate σ ∧ adequateClauses σ cs
    | .resume k v => k.Adequate σ ∧ v.Adequate σ
    | .issuePathBases _ => True
    | .checkAt _ _ _ bs p v _ =>
        (match bs with | none => True | some b => b.Adequate σ) ∧ p.Adequate σ ∧ v.Adequate σ
  def adequateArms (σ : PathEnv) : List Arm → Prop
    | [] => True
    | .mk _ guard body :: arms =>
        (match guard with | none => True | some g => g.Adequate σ) ∧
        body.Adequate σ ∧ adequateArms σ arms
  def adequateClauses (σ : PathEnv) : List Clause → Prop
    | [] => True
    | .mk _ _ _ body :: cs | .fail _ body :: cs => body.Adequate σ ∧ adequateClauses σ cs
  def Capture.Adequate (σ : PathEnv) : Capture → Prop
    | .mk vs => adequateCaptureSlots σ vs
  def adequateCaptureSlots (σ : PathEnv) : List (Option Val) → Prop
    | [] => True
    | none :: vs => adequateCaptureSlots σ vs
    | some v :: vs => v.Adequate σ ∧ adequateCaptureSlots σ vs
  def Closure.Adequate (σ : PathEnv) : Closure → Prop
    | .mk cap m => cap.Adequate σ ∧ m.Adequate σ
end

mutual
  def Frame.Adequate (σ : PathEnv) : Frame → Prop
    | .letF q => q.Adequate σ
    | .release v => v.Adequate σ
    | .handleF cap cs => cap.Adequate σ ∧ adequateClauses σ cs
    | .guardF v cap arms _ body => v.Adequate σ ∧ cap.Adequate σ ∧
        adequateArms σ arms ∧ body.Adequate σ
    | .mark | .update _ | .drop _ => True
end

def Cont.Adequate (σ : PathEnv) (k : Cont) : Prop := ∀ f ∈ k, f.Adequate σ

def Cell.Adequate (σ : PathEnv) : Cell → Prop
  | .builder (.list vs) => adequateVals σ vs
  | .val v | .done v => v.Adequate σ
  | .thunk q => q.Adequate σ
  | .cont k => Cont.Adequate σ k
  | .builder _ | .used => True

def Store.Adequate (σ : PathEnv) (μ : Store) : Prop := ∀ l c, μ l = some c → c.Adequate σ

def Outcome.Adequate (σ : PathEnv) : Outcome → Prop
  | .val v => v.Adequate σ
  | .err _ | .exit _ => True

def AdequateResult (ws : List Val) (out : Outcome) : Prop :=
  ∀ σ, σ.Valid → (∀ w ∈ ws, w.Adequate σ) → out.Adequate σ

theorem SnapshotMem.kind {snapshot k r t} (h : SnapshotMem snapshot k r t) : t.kind = k := by
  cases snapshot with
  | none => cases r <;> first | exact h.1 | cases h
  | some σ => exact h.2.1

theorem SnapshotMem.current {σ snapshot k r t} (h : SnapshotMem snapshot k r t)
    (ha : SnapshotAdequate σ snapshot r) : r.Mem σ k t := by
  cases snapshot with
  | none =>
    cases r with
    | absolute q => exact ⟨h.1, by simpa [RangeExpr.resolve] using h.2⟩
    | based _ _ | secrets => cases h
  | some ρ => cases ha; exact h.2

theorem Val.adequate_pathBases {σ ρ} : (Val.pathBases ρ).Adequate σ ↔ ρ = σ := Iff.rfl

theorem Val.adequate_checkedAt_current {σ r snapshot target req}
    (h : (Val.checkedAt r snapshot target req).Adequate σ) :
    ∀ ρ, snapshot = some ρ → ρ = σ := by
  intro ρ he; cases he
  cases req <;> exact h.1

end Benitoite.Release.Refinement
