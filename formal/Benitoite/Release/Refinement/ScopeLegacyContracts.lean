import Benitoite.Release.Refinement.AtTargets
import Benitoite.Checked.Scope
import Benitoite.Release.TargetTable

/-! # 純粋な絶対パスの入口と明示した起点による At -/
namespace Benitoite.Release.Refinement
noncomputable section

namespace ScopeLegacyContracts
open Scope.Domain

/-- Scope.checkPath・Scope.checkPathIn に渡すパスは、解析後の絶対形だけを受け入れる。 -/
def pathInput (v : Val) : Option Word :=
  match parseAtInput .path v with
  | some (.absolute (.path w)) => some w
  | _ => none

def checkPath (p : PathPattern) (v : Val) : Option (Except Checked.Scope.ScopeError Checked.Scope.CheckedPath) :=
  (pathInput v).map (Checked.Scope.makePath p)

/-- 記号付き上限は、純粋な入口では解決せず拒否する。 -/
def checkPathIn (p : PathPattern) (v : Val) (bound : RangeExpr) : Option AtResult :=
  match bound with
  | .absolute r => (pathInput v).map (fun w => checkAt none .path (.path p) (.absolute (.path w)) (.absolute r))
  | .based _ _ | .secrets => none

theorem relative_rejected {v : Val} {w : Word}
    (hv : parseAtInput .path v = some (.relativePath w) ∨
      parseAtInput .path v = some (.homePath w)) (p : PathPattern) (bound : RangeExpr) :
    pathInput v = none ∧ checkPath p v = none ∧ checkPathIn p v bound = none := by
  have hi : pathInput v = none := by rcases hv with hv | hv <;> simp [pathInput,hv]
  refine ⟨hi,by simp [checkPath,hi],?_⟩
  cases bound <;> simp [checkPathIn,hi]

theorem absolute_input {v : Val} {w : Word}
    (hv : parseAtInput .path v = some (.absolute (.path w))) (p : PathPattern) (r : Range) :
    checkPath p v = some (Checked.Scope.makePath p w) ∧
    checkPathIn p v (.absolute r) = some (checkAt none .path (.path p) (.absolute (.path w)) (.absolute r)) := by
  simp [checkPath,checkPathIn,pathInput,hv]

example {v : Val} {w : Word}
    (hv : parseAtInput .path v = some (.relativePath w)) (p : PathPattern) (r : RangeExpr) :
    checkPath p v = none ∧ checkPathIn p v r = none := (relative_rejected (Or.inl hv) p r).2

example {v : Val} {w : Word}
    (hv : parseAtInput .path v = some (.absolute (.path w))) (p : PathPattern) (r : Range) :
    checkPath p v = some (Checked.Scope.makePath p w) ∧
    checkPathIn p v (.absolute r) = some (checkAt none .path (.path p) (.absolute (.path w)) (.absolute r)) :=
  absolute_input hv p r

/-- パターンの root と対象の cwd/home は、別々の解決を使う。 -/
example (σ : PathEnv) (p : PathPattern) (w : Word) :
    (RangeExpr.based .root p).resolve σ = some [.path (PathPattern.atBase σ.root p)] ∧
    (TargetInput.relativePath w).resolve σ = some (.path (σ.cwd ++ w)) ∧
    (TargetInput.homePath w).resolve σ = some (.path (σ.home ++ w)) := ⟨rfl,rfl,rfl⟩

/-- 成功値の絶対対象への射影は、起点を再解決しない。 -/
example {snapshot kind p target bound t}
    (h : checkAt snapshot kind p (.absolute target) bound = .ok t) :
    (Val.checkedAt bound snapshot t none).target? = (Val.checked target).target? := by
  rw [checkAt.absolute h]; rfl

/-- At の型付けは、起点を明示した呼出しでも純粋な効果を持つ。 -/
example {P B Ψ Q C Γ Φ R kind name shape bases pattern input index}
    (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.checkAt kind name shape bases pattern input index)
      (.data shape.owner [.scoped name kind index,shape.errorType]) Eff.empty [] := .C_CheckAt h

example : Benitoite.Release.TargetTable.checkPathIn.kind = .pure ∧
    Benitoite.Release.TargetTable.checkPathIn.eff = Benitoite.Release.Eff.empty := ⟨rfl,rfl⟩

example (p : PathPattern) (v : Val) (b : PathBase) (q : PathPattern) :
    checkPathIn p v (.based b q) = none ∧ checkPathIn p v .secrets = none := ⟨rfl,rfl⟩

example (p : PathPattern) :
    checkPath p (.const (.string "/")) = some (Checked.Scope.makePath p []) ∧
    checkPath p (.const (.string ".")) = none ∧ checkPath p (.const (.string "~")) = none := by
  simp [checkPath,pathInput,parseAtInput,parseTargetInput]

end ScopeLegacyContracts
end
end Benitoite.Release.Refinement
