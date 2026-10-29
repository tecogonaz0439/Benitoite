import Benitoite.Scope.Signature

/-!
# 型に依存しないエフェクトの原子

型と効果の相互再帰から原子の順序を使えるよう、名前と行の定義を分離する。
原子は型を含まない（設計書 01-12「エフェクトの名前と開始状態」）。

名前の原子は、名前と範囲の位置 `Scope.Signature.Ix` の組である（設計書 01-12「構文」「表記」）。範囲の位置は
閉じた範囲 `fixed R` か、組み込みの署名の中だけに現れる範囲の変数 `rvar i` である。旧の名前だけの原子は
明示の Top の構築関数 `Atom.nameTop` で書き、既定引数と暗黙の変換を置かない。既定引数を置くと、パターンや
言明の `.name l` が黙って Top だけの意味になるので、範囲を見るべき箇所を型の誤りとして列挙させるためである。
-/

namespace Benitoite.Release

/-- エフェクトの名前。01-12「エフェクトの名前と開始状態」の `L`。宣言したモジュールと名前の組を、
一つの文字列で表す。 -/
abbrev EffName := String

/-- 状態を扱う組み込みの関数と解放のエフェクト `State`（01-07「可変のセル（初回リリース版）」）。 -/
def stateEff : EffName := "State"

/-- エフェクトの原子。01-12 の `e ::= L[ix] | ρ`。名前の原子は範囲の位置 `ix` を持つ。 -/
inductive Atom where
  | name (l : EffName) (ix : Scope.Signature.Ix)
  | rho (i : Nat)
  deriving DecidableEq, Repr

/-- 旧の名前だけの原子（範囲の位置が Top）を作る明示の構築関数。`.name l Ix.top` と同じ項である。 -/
abbrev Atom.nameTop (l : EffName) : Atom := .name l (.fixed .top)

/-- `Atom.nameTop` は `Ix.top` を範囲の位置に持つ。 -/
theorem Atom.nameTop_eq (l : EffName) : Atom.nameTop l = .name l Scope.Signature.Ix.top := rfl

/-- 範囲の位置が違えば原子は等しくない（判断 5。構造の等号）。 -/
theorem Atom.name_inj {l m : EffName} {a b : Scope.Signature.Ix} :
    Atom.name l a = Atom.name m b ↔ l = m ∧ a = b := by
  constructor
  · intro h; cases h; exact ⟨rfl, rfl⟩
  · rintro ⟨rfl, rfl⟩; rfl

/-- 原子の範囲の位置の範囲の変数の番号が `nr` より小さい（`Scope.Signature.Ix.WF nr`）。行の原子には条件がない。
宣言と項の変数の範囲（`Ty.VarsIn`・`Eff.VarsIn`）が効果の名前の原子に求める条件である（問 3 の P1）。 -/
def Atom.WF (nr : Nat) : Atom → Prop
  | .name _ ix => ix.WF nr
  | .rho _ => True

instance (nr : Nat) (a : Atom) : Decidable (a.WF nr) := by
  cases a <;> unfold Atom.WF <;> infer_instance

@[simp] theorem Atom.wf_name (nr : Nat) (l : EffName) (ix : Scope.Signature.Ix) :
    (Atom.name l ix).WF nr ↔ ix.WF nr := Iff.rfl

@[simp] theorem Atom.wf_rho (nr i : Nat) : (Atom.rho i).WF nr := trivial

/-- 閉じた範囲の位置は、どの文脈でも範囲の条件を満たす（`simp` で閉じるための補題）。 -/
@[simp] theorem Atom.ix_wf_fixed (nr : Nat) (r : Scope.Domain.Range) : (Scope.Signature.Ix.fixed r).WF nr :=
  trivial

/-- 旧の原子の像。範囲の位置が Top の名前の原子と、行の原子である（範囲の変数のない Top だけの項目）。
旧の像での同値（`Eff.TopAtoms`・`BuiltinOnly.iff_old`・`Eff.covers_iff_sub_old` など）の、原子の側の条件に使う。 -/
def Atom.TopImage : Atom → Prop
  | .name _ ix => ix = .fixed .top
  | .rho _ => True

@[simp] theorem Atom.topImage_nameTop (l : EffName) : (Atom.nameTop l).TopImage := rfl

@[simp] theorem Atom.topImage_rho (i : Nat) : (Atom.rho i).TopImage := trivial

end Benitoite.Release
