import Benitoite.Release.Refinement.Types

namespace Benitoite.Release.Refinement

/-- data の型引数の変性。非出現の引数も不変である。 -/
inductive Variance where
  | covariant | contravariant | invariant
  deriving DecidableEq

inductive Polarity where
  | positive | negative | both
  deriving DecidableEq

def Polarity.flip : Polarity → Polarity
  | .positive => .negative
  | .negative => .positive
  | .both => .both

def Polarity.compose (p : Polarity) : Variance → Polarity
  | .covariant => p
  | .contravariant => p.flip
  | .invariant => .both

def Variance.accepts : Variance → Polarity → Prop
  | .invariant, _ => True
  | .covariant, .positive | .contravariant, .negative => True
  | _, _ => False

/-- 原ソースから収集した制約と公開境界。収集の完全性は別に照合する。 -/
structure DataVarianceDecl where
  arity : Nat
  variances : List Variance
  requirements : List Ty
  publicBoundary : List (Polarity × Ty)

mutual
  /-- 型変数の出現。型構成子適用の head も含む。 -/
  def Ty.ParamOccurs (i : Nat) : Ty → Prop
    | .tvar j => i = j
    | .tapp j as => i = j ∨ paramsOccur i as
    | .data _ as | .external _ as => paramsOccur i as
    | .list a | .reference a | .lazy a | .set a | .dict _ a | .refined a _ => a.ParamOccurs i
    | .fn _ ps r e => paramsOccur i ps ∨ r.ParamOccurs i ∨ Eff.ParamOccurs i e
    | .cont a b e => a.ParamOccurs i ∨ b.ParamOccurs i ∨ Eff.ParamOccurs i e
    | .map a b => a.ParamOccurs i ∨ b.ParamOccurs i
    | .dependentFn t => Tel.ParamOccurs i t
    | _ => False
  def paramsOccur (i : Nat) : List Ty → Prop
    | [] => False
    | a :: as => a.ParamOccurs i ∨ paramsOccur i as
  def Eff.ParamOccurs (i : Nat) : Eff → Prop
    | .mk _ fs => paramsOccur i fs
  def Tel.ParamOccurs (i : Nat) : Tel → Prop
    | .done r e => r.ParamOccurs i ∨ Eff.ParamOccurs i e
    | .param _ a t => a.ParamOccurs i ∨ Tel.ParamOccurs i t
end

end Benitoite.Release.Refinement
