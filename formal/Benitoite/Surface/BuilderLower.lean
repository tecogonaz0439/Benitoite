import Benitoite.Surface.BuilderSyntax
import Benitoite.Release.Subst

/-!
# 専用操作のコアへの展開

引数の評価後に、専用番号と操作をコアへ直接渡す。
対応する規則は設計書 01-12「構築器の専用操作と脱糖」である。
-/
namespace Benitoite.Surface
open Benitoite.Release

/-- 通常引数の let の個数だけ移動した専用番号を、そのままコアへ渡す。 -/
def builderFinish (op : BuilderOp) (i : Nat) (k : BuilderKind) (args : List Val) : Comp :=
  .builderOp k op (.bound i) args


end Benitoite.Surface
