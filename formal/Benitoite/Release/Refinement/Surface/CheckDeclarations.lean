import Benitoite.Release.Refinement.Surface.Check
import Benitoite.Release.Refinement.Surface.CheckDeclarationBase

/-! 関数と型クラスの実装を、宣言の署名と本体の表層の規則で検査する。 -/
namespace Benitoite.Release.Refinement.Surface.CheckDeclarations

/-- 依存列の末尾における、表層のブロックの実際の検査。 -/
def bodyChecker : BlockChecker := fun q rows C Γ Φ path body a e =>
  Check.checkBlockAt q rows [] C Γ Φ (some a) .tail path body a e (q.guide path)

/-- 関数の指定は、呼出し側の既定の証明の上限より優先する。 -/
def definitionInput (q : Check.Input) (d : Def) : Check.Input :=
  {q with proofSteps := d.proofSteps.getD q.proofSteps}

/-- 関数の署名の依存列で、本体の型と効果を照合する。証明の上限の明示指定は正である。 -/
def checkDef (q : Check.Input) (path : List Nat) (d : Def) : Check.Result Unit :=
  do
    Check.require path "proof step limit must be positive"
      (match d.proofSteps with | none => true | some n => decide (0 < n))
    checkDefWith bodyChecker (definitionInput q d) path d

/-- 実装の全メソッド・上位の辞書と、メソッドの実名を照合する。 -/
def checkImpl (q : Check.Input) (i : ImplName) (path : List Nat) (id : ImplDecl)
    (views : MethName → CoverageView := fun _ => q.D.view) : Check.Result Unit :=
  checkImplWith bodyChecker q i path id views

end Benitoite.Release.Refinement.Surface.CheckDeclarations
