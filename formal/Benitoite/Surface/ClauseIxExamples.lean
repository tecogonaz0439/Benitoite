import Benitoite.Surface.DesugarRange

/-!
# 表層の節の添字の例（L40.5）

L00.07 の例 3a（`/data/**` へ書く保護本体の `File.writeTextIn` の節）の節の添字 `/data/**` を、表層の規則
（`clauseIx`）と検査器の計算（`clauseRangeIn`・`clauseOpSigIn`）から作る。表の項目は L20.7 の `TargetTable` の表、
保護本体の効果は `Release.ClauseIxExamples.bodyData`（`{File.Write["/data/**"]}`）である（設計書 01-12「型の情報を
付けた表層の構文と型付け」）。
-/

namespace Benitoite.Surface.ClauseIxExamples

open Benitoite.Release
open Benitoite.Release.TargetTable
open Benitoite.Release.ClauseIxExamples (dataR logsR bodyData bodyData_rule sig_writeTextIn)
open Scope.Domain (Range)

variable {delta : PrimName → List Ty → List Eff → List Range → List Val → Option Outcome}
  {ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → List Scope.Domain.Target → Prop}

/-- 検査器の候補の原子の一覧。 -/
def atoms : List Atom :=
  [.nameTop "File.Write", .name "File.Write" (.fixed dataR), .name "File.Write" (.fixed logsR),
    .name "File.Read" (.fixed dataR), .rho 0]

/-! ## 検査器の計算（`#guard`） -/

/-- 原子の有限の並びの効果（計算できる形。`Eff.union` は計算できないので例ではこの形で書く）。 -/
def effOf (as : List Atom) : Eff := Eff.ofAtoms (fun a => as.contains a)

-- 同名の閉じた原子が一つだけなら、その範囲（例 3a）。
#guard clauseRangeIn atoms bodyData "File.Write" == dataR
-- 二つの範囲の原子なら Top。
#guard clauseRangeIn atoms (effOf [.name "File.Write" (.fixed dataR), .name "File.Write" (.fixed logsR)]) "File.Write"
  == .top
-- 行の変数を持つなら Top。
#guard clauseRangeIn atoms (effOf [.name "File.Write" (.fixed dataR), .rho 0]) "File.Write" == .top
-- 同名の Top の原子（旧の `File.Write`）なら Top。
#guard clauseRangeIn atoms (effOf [.nameTop "File.Write"]) "File.Write" == .top
-- 同名の原子がなければ Top。
#guard clauseRangeIn atoms (Eff.singleAt "File.Read" (.fixed dataR)) "File.Write" == .top
-- 検査器が `File.writeTextIn`（範囲の変数一つ）の節に与える添字。
#guard clauseIxIn (builtins (fun _ _ _ _ _ => none) (fun _ _ _ _ _ _ => True)) atoms bodyData
  (.prim "File.writeTextIn") == dataR

/-! ## 表層の規則と検査器の一致 -/

theorem bodyData_atomsIn : bodyData.AtomsIn atoms := by
  refine (Eff.support_iff bodyData).mpr ⟨fun x hx => ?_, trivial⟩
  have := (Eff.mem_singleAt _ _ _).mp hx
  subst this
  simp [atoms]

/-- 例 3a: 表層の型付けの規則は、保護本体の効果 `{File.Write["/data/**"]}` から `File.writeTextIn` の節の添字
`/data/**` を選ぶ。 -/
theorem ex3a_clauseIx :
    clauseIx (builtins delta ioResponse) bodyData (.prim "File.writeTextIn") = dataR := by
  rw [clauseIx_prim sig_writeTextIn rfl]
  exact Eff.clauseRange_of bodyData_rule

/-- 例 3a: 表層の節の操作の型の引数は `[PathIn["/data/**"], String]` である。 -/
theorem ex3a_sig {P : Release.Program} :
    opSigAt P (builtins delta ioResponse) (clauseIx (builtins delta ioResponse) bodyData (.prim "File.writeTextIn"))
        (.prim "File.writeTextIn") =
      some ⟨[], ["path", "text"], [.opaque "Scope.PathIn" (.fixed dataR), .base .string],
        resultTy (.base .unit) ioErrorTy, "File.Write"⟩ := by
  rw [ex3a_clauseIx]
  simp [opSigAt, sig_writeTextIn, writeTextIn, ioIn, pathIn, PrimSig.nranges, Ty.instTarget,
    Scope.Signature.Ix.inst]

/-- 例 3a: 検査器が引く節の操作の型も同じである（`clauseOpSigIn_eq`）。 -/
theorem ex3a_checker {P : Release.Program} :
    clauseOpSigIn P (builtins delta ioResponse) atoms bodyData (.prim "File.writeTextIn") =
      some ⟨[], ["path", "text"], [.opaque "Scope.PathIn" (.fixed dataR), .base .string],
        resultTy (.base .unit) ioErrorTy, "File.Write"⟩ := by
  rw [clauseOpSigIn_eq bodyData_atomsIn]
  exact ex3a_sig

/-- 表層の規則は Top の添字の操作の型（引数 `PathIn[Top]`）を選ばない。コアの型付けは同じ節を Top でも型付けうる
（`Release.ClauseIxExamples.clauseSig_top`）が、表層の型付けの添字は一つに決まる。 -/
theorem ex3a_not_top {P : Release.Program} :
    opSigAt P (builtins delta ioResponse) (clauseIx (builtins delta ioResponse) bodyData (.prim "File.writeTextIn"))
        (.prim "File.writeTextIn") ≠
      some ⟨[], ["path", "text"], [.opaqueTop "Scope.PathIn", .base .string],
        resultTy (.base .unit) ioErrorTy, "File.Write"⟩ := by
  rw [ex3a_sig]
  simp [dataR]

/-- 行の変数を持つ保護本体の効果では、表層の規則の添字は Top である（未確定の行の変数）。 -/
theorem rho_clauseIx :
    clauseIx (builtins delta ioResponse) (Eff.union bodyData (Eff.row 0)) (.prim "File.writeTextIn") = .top := by
  rw [clauseIx_prim sig_writeTextIn rfl]
  exact Eff.clauseRange_of_rho (i := 0) ((Eff.mem_union _ _ _).mpr (Or.inr ((Eff.mem_row _ _).mpr rfl)))


/-! ## 本体の効果を `B_Sub` で広げると Top の添字に届く（RV-L40 中2）

表層の型付けの `E_Handle` の保護本体の効果 εbody は導出が選ぶ。純粋な本体を `B_Sub` で
`{File.Write["/data/**"], File.Write["/logs/**"]}` へ広げると、同名の閉じた原子が二つなので規則の値は Top になり、
`File.writeTextIn` の節を Top の操作の型（引数 `PathIn[Top]`）で型付ける導出ができる。規則の値を一つに選ぶのは
εbody を固定した型付け（`cons_sig_unique`）と、最小の効果を使う検査器（`clauseOpSigIn_eq`）であり、表層の型付けの
集合 `p.WellTyped` は節の添字の制限で狭まらない。 -/

/-- 二つの範囲の原子を持つ効果。 -/
noncomputable def wide : Eff := Eff.union bodyData (Eff.singleAt "File.Write" (.fixed logsR))

theorem wide_clauseIx : clauseIx (builtins delta ioResponse) wide (.prim "File.writeTextIn") = .top := by
  rw [clauseIx_prim sig_writeTextIn rfl]
  exact Eff.clauseRange_of_two (ix := .fixed dataR) (ix' := .fixed logsR)
    ((Eff.mem_union _ _ _).mpr (Or.inl ((Eff.mem_singleAt _ _ _).mpr rfl)))
    ((Eff.mem_union _ _ _).mpr (Or.inr ((Eff.mem_singleAt _ _ _).mpr rfl))) (by simp [dataR, logsR])

/-- 広げた本体の効果のもとでの節の操作の型は Top の添字で具体化した形（引数 `PathIn[Top]`）である。 -/
theorem wide_sig {P : Release.Program} :
    opSigAt P (builtins delta ioResponse) (clauseIx (builtins delta ioResponse) wide (.prim "File.writeTextIn"))
        (.prim "File.writeTextIn") =
      some ⟨[], ["path", "text"], [.opaque "Scope.PathIn" (.fixed .top), .base .string],
        resultTy (.base .unit) ioErrorTy, "File.Write"⟩ := by
  rw [wide_clauseIx]
  simp [opSigAt, sig_writeTextIn, writeTextIn, ioIn, pathIn, PrimSig.nranges, Ty.instTarget,
    Scope.Signature.Ix.inst]

private def one : Expr := .literal (.integer ⟨1, by decide⟩)

/-- 表層の型付けの導出: 純粋な保護本体 `{ 1 }` を `B_Sub` で `wide` へ広げ、`File.writeTextIn` の節（本体 `{ 1 }`）を
Top の操作の型で型付ける。`handle` の式の効果は `wide` である。 -/
theorem top_clause_typed {D : Declarations} {opPrim : OpPrim} {C : List TParam} {Γ : List (Option Ty)} {R : Option Ty} :
    HasType D (builtins delta ioResponse) opPrim C Γ R .other
      (.handleE (.last one) (.cons (.prim "File.writeTextIn") 2 0 (.last one) .nil))
      (.base .integer) wide := by
  have hvars : Ty.VarsIn 0 C.length (fun _ => True) (.base .integer) := by simp [Ty.VarsIn]
  have hbody : HasBlock D (builtins delta ioResponse) opPrim C Γ R .other (.last one) (.base .integer) wide :=
    HasBlock.B_Sub (HasBlock.B_Last (HasType.E_Literal (l := .integer ⟨1, by decide⟩)))
      (Ty.Le.refl _) (Eff.covers_empty _) hvars
  apply HasType.E_Handle hbody
  · refine ⟨fun a ha => (Eff.mem_union _ _ _).mpr (Or.inl ha), fun t ht => (Eff.memFail_union _ _ _).mpr (Or.inl ht)⟩
  · apply HasClauses.cons (sg := ⟨[], ["path", "text"], [.opaque "Scope.PathIn" (.fixed .top), .base .string],
        resultTy (.base .unit) ioErrorTy, "File.Write"⟩) wide_sig
      (by simp [NamesWF]) ⟨rfl, rfl⟩ rfl
    · simp [wide, bodyData, Eff.union, Eff.norm, Eff.singleAt, Eff.ofAtoms, Eff.fails, Eff.WF, Ty.WFList]
    · exact HasBlock.B_Sub (HasBlock.B_Last (HasType.E_Literal (l := .integer ⟨1, by decide⟩)))
        (Ty.Le.refl _) (Eff.covers_empty _) (by simp [Ty.VarsIn, Ty.shift])
    · exact .nil

end Benitoite.Surface.ClauseIxExamples
