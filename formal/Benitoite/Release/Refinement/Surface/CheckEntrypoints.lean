import Benitoite.Release.Refinement.Surface.Check

/-! ソース位置の案内と推論結果を使う式・ブロックの公開の検査入口。 -/
namespace Benitoite.Release.Refinement.Surface.Check

/-- 篩の証明の打ち切りは、不正な証明書の拒否と区別する。 -/
def expressionFailureKind (q : Input) (Γ : Ctx) (Φ : List Pred) (path : List Nat) (e : Expr) : ErrorKind :=
  match q.guide path with
  | .unknown => .unknown
  | .node .E_Refine h [_] => match e.valueOf?.bind Val.toTerm? with
    | some t => match (h.proof 0).result q.proofSteps (Γ.facts ++ Φ) ((h.pred 0).open t) with
      | .unknown _ => .unknown
      | .proved | .rejected => .rejected
    | none => .rejected
  | _ => .rejected

def blockFailureKind (g : Guide) : ErrorKind := match g with
  | .unknown => .unknown
  | .node _ _ _ => .rejected

/-- 書いた位置の型と効果を、同じ位置の案内で再検査して返す。 -/
def checkExpr (q : Input) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (p : Position)
    (path : List Nat) (e : Expr) : Result Inferred :=
  let (a, ε) := q.inferred path
  if checkExprAt q [] [] C Γ Φ R p path e a ε (q.guide path)
  then .ok (a, ε) else .error ⟨path, "expression check failed", expressionFailureKind q Γ Φ path e⟩

def checkBlock (q : Input) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (p : Position)
    (path : List Nat) (body : Block) : Result Inferred :=
  let (a, ε) := q.inferred path
  if checkBlockAt q [] [] C Γ Φ R p path body a ε (q.guide path)
  then .ok (a, ε) else .error ⟨path, "block check failed", blockFailureKind (q.guide path)⟩

theorem checkExpr_ok {q C Γ Φ R p path e a ε} (h : checkExpr q C Γ Φ R p path e = .ok (a, ε)) :
    checkExprAt q [] [] C Γ Φ R p path e a ε (q.guide path) = true := by
  cases hp : q.inferred path with
  | mk b ef =>
    simp only [checkExpr, hp] at h
    split at h
    · next hc =>
      obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj h)
      exact hc
    · cases h

theorem checkBlock_ok {q C Γ Φ R p path body a ε} (h : checkBlock q C Γ Φ R p path body = .ok (a, ε)) :
    checkBlockAt q [] [] C Γ Φ R p path body a ε (q.guide path) = true := by
  cases hp : q.inferred path with
  | mk b ef =>
    simp only [checkBlock, hp] at h
    split at h
    · next hc =>
      obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj h)
      exact hc
    · cases h

end Benitoite.Release.Refinement.Surface.Check
