import Benitoite.Release.Normalize

/-!
# 署名の範囲の変数の具体化の定義

組み込みの署名の範囲の変数を閉じた範囲の列で具体化する関数の定義だけを置く（設計書 01-12「構文」の「署名の範囲の
変数と具体化」）。型付けの規則 V-Prim が具体化した署名を使うので、`Release/Typing.lean` より前に置く。性質は
`Release/RangeInst.lean` にある。
-/

namespace Benitoite.Release

open Order

/-- 原子の範囲の位置の具体化。行の原子は変えない。 -/
def Atom.instR (rs : List Scope.Domain.Range) : Atom → Atom
  | .name l ix => .name l (ix.inst rs)
  | .rho i => .rho i

/-- 所属関数の具体化（原子ごとの具体化の像）。閉じた範囲の名前の原子は、同じ原子か、その範囲を与える範囲の変数の
原子があれば所属する。範囲の変数の原子は、具体化の列が短いときだけ残る。 -/
def Eff.instAtoms (rs : List Scope.Domain.Range) (a : Atom → Bool) : Atom → Bool
  | .name l (.fixed r) => a (.name l (.fixed r)) ||
      (List.range rs.length).any (fun i => a (.name l (.rvar i)) && decide (rs[i]? = some r))
  | .name l (.rvar i) => a (.name l (.rvar i)) && rs[i]?.isNone
  | .rho i => a (.rho i)

mutual
  /-- 正規化前の型の全ての範囲の位置（不透明型と効果の名前の原子）の具体化。 -/
  def Ty.rawInstR (rs : List Scope.Domain.Range) : Ty → Ty
    | .base b => .base b
    | .opaque o ix => .opaque o (ix.inst rs)
    | .data d as => .data d (Ty.rawInstRTys rs as)
    | .list a => .list (a.rawInstR rs)
    | .fn ns ps r e => .fn ns (Ty.rawInstRTys rs ps) (r.rawInstR rs) (Eff.rawInstR rs e)
    | .tvar i => .tvar i
    | .reference a => .reference (a.rawInstR rs)
    | .lazy a => .lazy (a.rawInstR rs)
    | .cont b t e => .cont (b.rawInstR rs) (t.rawInstR rs) (Eff.rawInstR rs e)
    | .map a b => .map (a.rawInstR rs) (b.rawInstR rs)
    | .set a => .set (a.rawInstR rs)
    | .bytes => .bytes
    | .dict cl a => .dict cl (a.rawInstR rs)
    | .tapp i as => .tapp i (Ty.rawInstRTys rs as)
    | .ctor c => .ctor c
  termination_by structural t => t

  def Ty.rawInstRTys (rs : List Scope.Domain.Range) : List Ty → List Ty
    | [] => []
    | a :: as => a.rawInstR rs :: Ty.rawInstRTys rs as
  termination_by structural as => as

  /-- 所属関数と Fail の型の具体化。 -/
  def Eff.rawInstR (rs : List Scope.Domain.Range) : Eff → Eff
    | .mk a fs => .mk (Eff.instAtoms rs a) (Ty.rawInstRTys rs fs)
  termination_by structural e => e
end

/-- 公開する型の具体化は、生の具体化の後に正規化する（効果の Fail の列の並びと重複が変わりうるため）。 -/
noncomputable def Ty.instR (rs : List Scope.Domain.Range) (t : Ty) : Ty := (t.rawInstR rs).norm

/-- 計算の最上位の効果の具体化。内側の型は正規化し、最上位の Fail の列の並びは保つ（計算の最上位の効果には
正規形を求めない。`Eff.WF`）。 -/
noncomputable def Eff.instR (rs : List Scope.Domain.Range) : Eff → Eff
  | .mk a fs => .mk (Eff.instAtoms rs a) (fs.map (Ty.instR rs))

/-- 引数の型の具体化。最上位の対象の位置（不透明型）の範囲の位置だけを具体化する。 -/
def Ty.instTarget (rs : List Scope.Domain.Range) : Ty → Ty
  | .opaque o ix => .opaque o (ix.inst rs)
  | t => t

end Benitoite.Release
