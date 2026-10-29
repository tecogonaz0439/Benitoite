import Benitoite.Release.TypeScopedSubst
import Benitoite.Release.Semantics

/-!
# 原子と不透明型の範囲の位置の小さい例

名前の原子 `Atom.name l ix` と不透明型 `Ty.opaque o ix` が範囲の位置 `Scope.Signature.Ix` を持つことの、
具体の小さい例である（設計書 01-12「構文」「表記」）。旧の綴りは明示の Top の構築関数 `Atom.nameTop`・
`Ty.opaqueTop` で書く。範囲の位置の違う原子と型は構造の等号で等しくなく（判断 5）、`Eff.single` は Top の原子だけを
作り、型代入は範囲の位置を変えず、Fail の列の不透明型も範囲の位置を持つ。大きな具体の計算は置かず、`#guard` と
小さい証明に限る。
-/

namespace Benitoite.Release.RangeIxExamples

open Benitoite.Release

/-- `/data/**` の閉じた範囲の位置。 -/
def dataTree : Scope.Signature.Ix := .fixed (.path (.tree ["data"]))

/-- 範囲の位置の違う名前の原子は等しくない。 -/
example : Atom.name "File.Read" dataTree ≠ Atom.nameTop "File.Read" := by
  simp [Atom.nameTop, dataTree]

/-- 範囲の変数の位置も Top と区別する。 -/
example : Atom.name "File.Read" (.rvar 0) ≠ Atom.nameTop "File.Read" := by
  simp [Atom.nameTop]

/-- 範囲の位置の違う不透明型は等しくない。 -/
example : Ty.opaque "Scope.PathIn" dataTree ≠ Ty.opaqueTop "Scope.PathIn" := by
  simp [Ty.opaqueTop, dataTree]

/-- `Eff.single` は Top の原子を作り、同じ名前の範囲付きの原子を含まない。 -/
example : Eff.mem (Eff.single "File.Read") (.nameTop "File.Read") := (Eff.mem_single _ _).mpr rfl
example : ¬ Eff.mem (Eff.single "File.Read") (.name "File.Read" dataTree) := by
  rw [Eff.mem_single_name]
  simp [dataTree]

/-- 型代入は不透明型の範囲の位置を変えない。 -/
example (ts : List Ty) (es : List Eff) :
    (Ty.opaque "Scope.PathIn" dataTree).substAt 0 ts es = .opaque "Scope.PathIn" dataTree :=
  Ty.substAt_opaque _ _ _ _ _

/-- 代入は範囲付きの名前の原子を同じ範囲の位置のまま残す。 -/
example (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.mem (Eff.substAt c ts es (Eff.ofAtoms (fun a => a == .name "File.Read" dataTree)))
      (.name "File.Read" dataTree) :=
  Eff.substAt_name (by simp [Eff.mem, Eff.test, Eff.atoms])

/-- Fail の列の不透明型も範囲の位置を持ち、範囲の位置の違う Fail の型を区別する。 -/
example : Eff.memFail (Eff.singleFail (.opaque "E" dataTree)) (.opaque "E" dataTree) := by
  rw [Eff.memFail_singleFail]
example : ¬ Eff.memFail (Eff.singleFail (.opaque "E" dataTree)) (Ty.opaqueTop "E") := by
  rw [Eff.memFail_singleFail]
  simp [Ty.norm, dataTree]

-- 範囲の位置は原子の符号に入る（構造の等号を固定順序で区別する）。
#guard Atom.code (.nameTop "File.Read") != Atom.code (.name "File.Read" dataTree)
#guard Atom.code (.nameTop "File.Read") != Atom.code (.name "File.Read" (.rvar 0))
#guard Atom.code (.name "File.Read" dataTree) == Atom.code (.name "File.Read" (.fixed (.path (.tree ["data"]))))

/-- `handled(H)` は範囲の位置を見ない（`handled_name`）。 -/
example (P : Program) (B : Builtins) (h : List Clause) :
    Eff.mem (handled P B h) (.name "File.Write" dataTree) ↔ Eff.mem (handled P B h) (.nameTop "File.Write") :=
  mem_handled_name_iff P B h _ _ _

end Benitoite.Release.RangeIxExamples
