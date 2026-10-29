import Benitoite.Scope.SignatureExamples
import Benitoite.Scope.InferenceExamples
import Benitoite.Release.Assumptions

/-!
UB10 の点検の一時ファイル（リポジトリの外。本番を変えない）。
L00 の模型と本番の Release の定義が、利用者のエフェクトの名前を範囲付きの標準の認定に入れないことと、
節の添字・節の引数の型付けが名前に依存しない（後の (a) で再利用できる）ことを確かめる。
-/

open Benitoite.Scope.Domain
open Benitoite.Scope.SignatureExamples

namespace UB10

/-! ## 1. 本番の Release: 利用者の操作と組み込みの操作は構成子で分かれ、節の照合で混ざらない -/

example : (Benitoite.Release.OpRef.user "File.writeTextIn" == .prim "File.writeTextIn") = false := by decide

/-- 本番の `Program.EffectsOk` の第三の連言: 利用者のエフェクトの名前は組み込みのエフェクトの名前と重ならない。 -/
example (P : Benitoite.Release.Program) (B : Benitoite.Release.Builtins) (h : P.EffectsOk B)
    (l : Benitoite.Release.EffName) (os : List Benitoite.Release.OpName) (hl : P.effects l = some os) :
    B.effects l = none := h.2.2 l os hl

/-- 本番の V_Op の効果は名前だけの一原子（旧の Top）である。 -/
example (P : Benitoite.Release.Program) (B : Benitoite.Release.Builtins) Ψ Q C Γ o od ts
    (ho : P.ops o = some od) (hn : Benitoite.Release.NamesWF od.names od.params)
    (hs : Benitoite.Release.SatAll B C ts od.tparams) :
    Benitoite.Release.HasTypeVQ P B Ψ Q C Γ (.op o ts)
      (Benitoite.Release.fnTy od.names od.params od.ret (Benitoite.Release.Eff.single od.eff) ts []) :=
  .V_Op ho hn hs

/-! ## 2. L00.03 の署名表: 認定元は組み込みの表だけ -/

-- 利用者のエフェクトの名前（表の `effects` にない名前）を効果に持つ項目は形の検査を通らない。
#guard !shapeOk exampleTable "main.write"
  { writeTextIn with opEff := some "main.Report", eff := [.name "main.Report" (.rvar 0)] }
-- 表の鍵にない利用者の操作の名前で、組み込みの項目を登録したことにはならない（一覧にない）。
#guard !shapeOk exampleTable "main.write" writeTextIn
#guard exampleTable.effKind "main.Report" == none
#guard exampleTable.valKind "main.Store" == none

/-- 範囲付きの値の所属は、表が認定した標準値型の名前でだけ成り立つ。利用者の不透明型の名前では成り立たない。 -/
theorem user_opaque_not_scoped (t : Target) (r : Range) :
    ¬ HasTypeV exampleTable.valKind (.checked t) (.opaque "main.Store" (.fixed r)) := by
  simp [HasTypeV, exampleTable]

/-! ## 3. 節の添字と節の引数の型付けは名前の文字列だけで決まる（後の (a) で利用者の名前にも使える形） -/

#guard clauseIndex "main.Report" [.name "main.Report" (.fixed dataTree)] == dataTree
#guard clauseIndex "main.Report" [.name "main.Report" (.fixed dataTree), .name "File.Write" (.fixed dataA)] == dataTree
#guard clauseIndex "main.Report" [.name "main.Report" (.fixed .top)] == .top

/-- `clause_arg_typed` は名前 l と値型の名前 o を全称で量化している。利用者のエフェクトの名前へ当てても、
値型が標準の `Scope.PathIn` なら同じ補題が使える。 -/
example (v : Val) (R : Range) (hv : HasTypeV exampleTable.valKind v (pathIn (.fixed R)))
    (hsub : Range.Sub R dataTree) :
    HasTypeV exampleTable.valKind v
      (pathIn (.fixed (clauseIndex "main.Report" [.name "main.Report" (.fixed dataTree)]))) :=
  clause_arg_typed (k := .path) rfl hv ⟨dataTree, by simp, hsub⟩

/-! ## 4. L00.05 の局所解析: 同定されない出現には規則を適用できない -/

example : Benitoite.Scope.InferenceExamples.toyTable.ruleAt Benitoite.Scope.InferenceExamples.keyUser = none := by
  decide

#print axioms user_opaque_not_scoped

end UB10
