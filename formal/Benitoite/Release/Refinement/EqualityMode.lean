/-! # 等号の検査で区別する構造と整数の意味 -/
namespace Benitoite.Release.Refinement

inductive EqualityMode where
  | structural
  | integer
  deriving DecidableEq

end Benitoite.Release.Refinement
