import Benitoite
open Benitoite Benitoite.Release.Refinement
namespace RVL10
-- Byte の sort と Top 関連
#eval (Ty.base .byte).sort?.isSome
#print Ty.sort?
#print Ty.refineNorm
noncomputable example := @Ty.foldFn
-- 計算可能か: 次はコンパイラが拒否するなら計算不能
def tryNorm (t : Tel) : Ty := Ty.foldFn t
end RVL10
