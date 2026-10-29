import Benitoite
/-! L00.06b の試行 A の非空の例。試行 A の状態（`trial-A.diff` を当てた formal）でだけ通る記録であり、本線では
`PrimSig.inst` がないので通らない。検査は formal で `lake env lean -M 12288 <このファイル>` として行った。 -/
namespace L006bExample
open Benitoite.Release

/-- 対象の位置 0 が `Scope.PathIn` の不透明型（Top）である、範囲付きの読み取りの署名。 -/
def readSig : PrimSig :=
  { tparams := [], neffs := 0, names := ["path"], params := [.opaqueTop "Scope.PathIn"],
    ret := .base .string, eff := Eff.single "File.Read", admits := fun _ _ => True, kind := .io,
    opEff := some "File.Read", target := some 0 }

def dataA : ScopeRange := .pathExact ["data", "a"]

/-- 範囲 `dataA` で具体化した署名は、対象の位置の型と効果の原子が同じ範囲を指す。 -/
theorem readSig_inst :
    readSig.inst dataA =
      { readSig with params := [.opaque "Scope.PathIn" dataA],
                     eff := Eff.ofAtoms (fun a => a == .name "File.Read" dataA) } := by
  unfold PrimSig.inst
  simp [readSig, dataA]

theorem readSig_scoped : readSig.Scoped := by
  simp [readSig, PrimSig.Scoped, NamesWF, Ty.VarsInList, Ty.VarsIn, Eff.VarsIn, Eff.single, Eff.ofAtoms,
    PrimSig.ntys]

/-- 開いた項では、範囲 `dataA` の引数を持つ変数に範囲付きの署名を当てられる（静的な型付けは空でない）。 -/
example (P : Program) (B : Builtins) (b : PrimName) (hs : B.sig b = some readSig) :
    HasTypeV P B StoreTy.empty [] [] (.prim b [] [])
      (fnTy ["path"] [.opaque "Scope.PathIn" dataA] (.base .string)
        (Eff.ofAtoms (fun a => a == .name "File.Read" dataA)) [] []) := by
  have h := HasTypeVQ.V_Prim (P := P) (Ψ := StoreTy.empty) (Q := Qempty) (C := []) (Γ := []) (ts := []) (es := [])
    (R := dataA) hs
    (by rw [readSig_inst]; simp [readSig, NamesWF])
    (PrimitiveAdmissible.of_noRows (PrimSig.inst_scoped _ readSig_scoped) (by simp [readSig])
      (by simp [readSig, PrimSig.ntys]) (by simp [readSig]) (by simp))
  rw [readSig_inst] at h
  simpa [readSig] using h

/-- 一方、閉じた値はその型の引数にならない（案 (i) の試行の Const は Top の型だけを持つ）。 -/
example (P : Program) (B : Builtins) (v : Val) :
    ¬ HasTypeV P B StoreTy.empty [] [] v (.opaque "Scope.PathIn" dataA) := by
  intro h
  have := h.closed_opaque_top
  simp [dataA] at this

end L006bExample
