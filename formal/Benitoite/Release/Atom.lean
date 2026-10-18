/-!
# 型に依存しないエフェクトの原子

型と効果の相互再帰から原子の順序を使えるよう、名前と行の定義を分離する。
原子は型を含まない（設計書 01-12「エフェクトの名前と開始状態」）。
-/

namespace Benitoite.Release

/-- エフェクトの名前。01-12「エフェクトの名前と開始状態」の `L`。宣言したモジュールと名前の組を、
一つの文字列で表す。 -/
abbrev EffName := String

/-- 状態を扱う組み込みの関数と解放のエフェクト `State`（01-07「可変のセル（初回リリース版）」）。 -/
def stateEff : EffName := "State"

/-- エフェクトの原子。01-12 の `e ::= L | ρ`。 -/
inductive Atom where
  | name (l : EffName)
  | rho (i : Nat)
  deriving DecidableEq, Repr

end Benitoite.Release
