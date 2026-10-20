import Benitoite.Surface.CheckSupport
import Benitoite.Surface.AdmissibleCheck
import Benitoite.Surface.SingleFailCheck

/-!
# 専用操作の種類と支持の補題

内容の型から種類の一致と操作の支持を導き、有限検査の健全性へ接続する。
対応する規則は設計書 01-12「構築器の専用操作と脱糖」である。
-/
namespace Benitoite.Surface
open Benitoite.Release CheckTools

/-- 内容の型は三種類を区別し、分類の比較にも使える。 -/
theorem BuilderKind.contents_injective {k l : BuilderKind} (h : k.contents = l.contents) : k = l := by
  cases k <;> cases l <;> simp_all [BuilderKind.contents]

end Benitoite.Surface

namespace Benitoite.Release
open Benitoite.Surface

/-- 操作の契約内にある支持は、内容の型から得られる。 -/
theorem BuilderOp.params_atoms {k : BuilderKind} {atoms} (o : BuilderOp)
    (h : Ty.AtomsIn atoms k.contents) : Tys.AtomsIn atoms (o.params k) := by
  cases o <;> cases k <;> simp_all [BuilderOp.params, BuilderKind.item, BuilderKind.contents, Ty.SupportList, Ty.Support]

theorem BuilderOp.result_atoms {k : BuilderKind} {atoms} (o : BuilderOp)
    (h : Ty.AtomsIn atoms k.contents) : Ty.AtomsIn atoms (o.result k) := by
  cases o <;> first | exact h | trivial

end Benitoite.Release
