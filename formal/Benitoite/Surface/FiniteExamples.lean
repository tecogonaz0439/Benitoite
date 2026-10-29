import Benitoite.Surface.FinitePredicates
import Benitoite.Release.FiniteSupport

/-! 一般のFail列・潜在効果・代入像を、計算用APIの境界で確認する。 -/
namespace Benitoite.Surface.CheckTools.Finite.Examples
open Benitoite.Release

private def unitTy : Ty := .base .unit
private def stringTy : Ty := .base .string
private def aTy : Ty := .fn [] [] unitTy (Eff.single "a")
private def bTy : Ty := .fn [] [] unitTy (Eff.single "b")
private def atoms : List Atom := [.nameTop "b", .nameTop "a"]
private def raw : Eff := .mk (fun _ => false) [aTy, stringTy, bTy, aTy]
private def rawOther : Eff := .mk (fun a => (a == .nameTop "irrelevant") && false) [aTy, stringTy, bTy, aTy]
private def sorted : Eff := .mk (fun _ => false) [stringTy, bTy, aTy]

-- 符号の最小の相違点を使い、候補の並びや重複を比較順にしない。
example : effEq atoms (Eff.normWith atoms raw) sorted = true := rfl
example : effEq [.nameTop "a", .nameTop "b", .nameTop "b", .nameTop "unused"]
    (Eff.normWith [.nameTop "a", .nameTop "b", .nameTop "b", .nameTop "unused"] raw) sorted = true := rfl

-- 生の比較には正規形を求めず、順序と重複を変えた列とは区別する。
example : effEq atoms raw rawOther = true := rfl
example : effEq atoms raw sorted = false := rfl
example : canonicalEff atoms raw = false ∧ canonicalEff atoms sorted = true := ⟨rfl, rfl⟩
example : effSub atoms raw sorted = true ∧ effSub atoms sorted raw = true := ⟨rfl, rfl⟩

private def template : Ty := .fn [] [] unitTy (.mk (fun a => a == .rho 0) [.tvar 0])
private def row : Eff := .mk (fun a => a == .nameTop "state") [stringTy]
private def substituted : Ty := .fn [] [] unitTy
  (.mk (fun a => a == .nameTop "state") [stringTy, aTy])
private def substAtoms : List Atom := [.nameTop "state", .rho 0, .nameTop "a"]

-- Fail型の置換像に含まれる潜在効果と、行の像からのFailを両方保持する。
example : tyEq substAtoms (substTyAt substAtoms 0 [aTy] [row] template) substituted = true := rfl
example : (Eff.collectAtoms substAtoms
    (.mk (fun _ => false) [substituted])).contains (.nameTop "a") = true := rfl

-- 型内部の移動後にも、一般の列を固定順で整列する。
example : tyEq []
    (shiftTy [] 2 1 (.fn [] [] unitTy (.mk (fun _ => false) [.tvar 0, .list (.tvar 1)])))
    (.fn [] [] unitTy (.mk (fun _ => false) [.list (.tvar 3), .tvar 0])) = true := rfl

-- 注釈の判定では正規化しない。Fail内部の型の範囲と継続も検査する。
private def scopedTy (i : Nat) : Ty := .fn [] [] unitTy (.mk (fun _ => false) [.tvar i])
example : cleanTy [] 1 (scopedTy 0) = true ∧ cleanTy [] 0 (scopedTy 0) = false := ⟨rfl, rfl⟩
example : wfTy [] 0 (.fn [] [] unitTy (.mk (fun _ => false) [.cont unitTy unitTy Eff.empty])) = true ∧
    cleanTy [] 0 (.fn [] [] unitTy (.mk (fun _ => false) [.cont unitTy unitTy Eff.empty])) = false :=
  ⟨rfl, rfl⟩

-- 型の比較に使う支持を空にしても、和から原子を切り捨てない。
example : Eff.test (unionEff [] (Eff.single "outside") Eff.empty) (.nameTop "outside") = true := rfl

-- Failのない旧効果の正規化は、任意の原子関数で簡約できる。
example (f : Atom → Bool) : Eff.normWith [] (.mk f []) = .mk f [] := rfl

end Benitoite.Surface.CheckTools.Finite.Examples
