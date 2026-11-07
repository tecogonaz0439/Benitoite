import Benitoite.Release.Refinement.Surface.PredicateRows
import Benitoite.Release.Refinement.MatchFacts

/-! # 欄の有限列をたどる判定の内部署名 -/
namespace Benitoite.Release.Refinement.Surface.PredicateProjection
open PredicateRows MatchFacts
noncomputable section

/-- 受け手の型パラメータと、判定する不変欄への経路。 -/
structure Projection where
  ntys : Nat
  owner : DataName
  route : List FieldRef
  entry : Entry
  deriving DecidableEq

def Projection.input (projection : Projection) : Ty :=
  .data projection.owner ((List.range projection.ntys).map Ty.tvar)

def Projection.result (projection : Projection) (receiver : Term) : Ty :=
  projection.entry.result (routeTerm receiver projection.route)

def Projection.signature (projection : Projection) : PrimSig :=
  ⟨List.replicate projection.ntys TypeCtx.valueParam, 0, ["receiver"], [projection.input],
    projection.result (.var 1), Eff.empty, (fun _ ts => ts.length = projection.ntys),
    .pure, none, [], .untargeted⟩

def Projection.run (projection : Projection) : List Val → Bool
  | [receiver] => (readPath receiver projection.route).elim false (fun value => projection.entry.run [value])
  | _ => false

def Projection.delta (projection : Projection) (types : List Ty) (rows : List Eff)
    (ranges : List RangeExpr) (values : List Val) : Option Outcome :=
  if types.length = projection.ntys ∧ rows = [] ∧ ranges = [] then
    some (.val (.const (.boolean (projection.run values)))) else none

theorem result_normal (projection : Projection) (receiver : Term) :
    (projection.result receiver).norm = projection.result receiver :=
  PredicateRows.result_normal _ _

theorem result_bind (projection : Projection) (θ : SubstEnv) (receiver : Term) :
    Ty.bind θ (projection.result receiver) =
      projection.result (termBind (upValues θ.values) receiver) := by
  simp only [Projection.result, PredicateRows.result_bind, routeTerm_bind]

/-- scalar の判定と欄の判定を同じ有限表へ登録する。 -/
inductive Row where
  | scalar (entry : Entry)
  | projected (projection : Projection)
  deriving DecidableEq

def Row.signature : Row → PrimSig
  | .scalar entry => entry.signature
  | .projected projection => projection.signature

def Row.delta : Row → List Ty → List Eff → List RangeExpr → List Val → Option Outcome
  | .scalar entry => entry.delta
  | .projected projection => projection.delta

end
end Benitoite.Release.Refinement.Surface.PredicateProjection
