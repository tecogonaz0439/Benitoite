import Benitoite.Release.Subst

/-!
# 型の置き換えのカーネル簡約

型変数の移動と置換を rfl で確かめ、入れ子の型列を辿る際にも
カーネルの簡約が止まらないことを検査する（設計書 07-04「01-12 との対応」）。
-/

namespace Benitoite.Release

-- cutoff の内外を区別し、型列と継続の型を同時に移動する。効果内部のFail型も移動する。
example (e : Eff) :
    Ty.shift 2 1 (.fn ["x", "y"] [.tvar 0, .list (.tvar 1)] (.cont (.tvar 2) .bytes e) e) =
      .fn ["x", "y"] [.tvar 0, .list (.tvar 3)] (.cont (.tvar 4) .bytes (Eff.shift 2 1 e)) (Eff.shift 2 1 e) := rfl

-- 旧表現の任意の名前・行の関数では、従来どおり潜在効果が変わらない。
example (atoms : Atom → Bool) :
    Ty.shift 2 1 (.fn ["x", "y"] [.tvar 0, .list (.tvar 1)]
      (.cont (.tvar 2) .bytes (Eff.ofAtoms atoms)) (Eff.ofAtoms atoms)) =
      .fn ["x", "y"] [.tvar 0, .list (.tvar 3)]
        (.cont (.tvar 4) .bytes (Eff.ofAtoms atoms)) (Eff.ofAtoms atoms) := rfl

-- 挿入する像を cutoff だけ移動し、型構成子の適用と、置換範囲より外側の番号の詰め直しを確かめる。
example :
    Ty.substAt 1 [.ctor .list, .tvar 0] []
      (.data "Box" [.tapp 1 [.dict "C" (.tvar 2)], .tvar 0, .tvar 4]) =
        .data "Box" [.list (.dict "C" (.tvar 1)), .tvar 0, .tvar 2] := rfl

end Benitoite.Release
