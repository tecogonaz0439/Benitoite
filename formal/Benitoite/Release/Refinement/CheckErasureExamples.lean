import Benitoite.Release.Refinement.CheckErasure
import Benitoite.Release.Refinement.StandardModelCheckInputs

/-! # 明示的な検査の消去と保持の正常な入力 -/
namespace Benitoite.Release.Refinement.CheckErasure
open RefinementCheck StandardModel
noncomputable section

/-- 合成表の実際の署名と応答は、消去が使う同じ行である。外部宣言は任意でよい。 -/
theorem standard_agreement (P : Program) (t u : Ty) (v : Val) :
    (builtins P).sig PublicNames.checkName = some RefinementCheck.signature ∧
    (builtins P).delta PublicNames.checkName [t,u] [] [] [v] =
      RefinementCheck.delta checkExpectedText PublicNames.checkName [t,u] [] [] [v] := by
  constructor
  · exact row_lookup P .p392
  · change (builtins P).delta Primitive.p392.name [t,u] [] [] [v] = _
    rw [RowLookup.delta .p392 rfl]
    rfl

/-- 1 と -1 は同じ全入力条件を満たす。真だけを消去し、偽は payload を持つ誤りを保つ。 -/
theorem integer_witnesses (externals : List (ExternalKey × ExternalDecl)) :
    let P := program externals
    let B := builtins P
    let yes := Val.const (.integer ⟨1,by decide⟩)
    let no := Val.const (.integer ⟨-1,by decide⟩)
    BuiltinArgs P B StoreTy.empty PublicNames.checkName RefinementCheck.signature
      [.base .integer,nonnegative] [] [] [yes] (result nonnegative) Eff.empty ∧
    BuiltinArgs P B StoreTy.empty PublicNames.checkName RefinementCheck.signature
      [.base .integer,nonnegative] [] [] [no] (result nonnegative) Eff.empty ∧
    erase (call (.base .integer) nonnegative yes) = .ret (ok nonnegative yes) ∧
    erase (call (.base .integer) nonnegative no) = call (.base .integer) nonnegative no ∧
    HasTypeCQ P B StoreTy.empty Qempty [] [] [] none
      (erase (call (.base .integer) nonnegative yes)) (result nonnegative) Eff.empty [] ∧
    HasTypeCQ P B StoreTy.empty Qempty [] [] [] none
      (erase (call (.base .integer) nonnegative no)) (result nonnegative) Eff.empty [] ∧
    RefinementCheck.delta checkExpectedText PublicNames.checkName [.base .integer,nonnegative] [] [] [no] =
      some (.val (rejected nonnegative (checkExpectedText nonnegative))) := by
  dsimp only
  have yp := integer_inputs externals ⟨1,by decide⟩
  have np := integer_inputs externals ⟨-1,by decide⟩
  have ys := standard_agreement (program externals) (.base .integer) nonnegative (.const (.integer ⟨1,by decide⟩))
  have ns := standard_agreement (program externals) (.base .integer) nonnegative (.const (.integer ⟨-1,by decide⟩))
  exact ⟨yp,np,erase_check rfl rfl rfl rfl (by decide),erase_rejected (by decide),
    (erase_typed (check_declarations externals) checkExpectedText ys.1 yp).2,
    (erase_typed (check_declarations externals) checkExpectedText ns.1 np).2,
    (integer_accept_reject checkExpectedText).2⟩

/-- 型付きの None の欄の評価が不能なときも、呼出しと同じ CheckError の payload を保つ。 -/
theorem undecided_witness (externals : List (ExternalKey × ExternalDecl)) :
    let P := program externals
    let B := builtins P
    BuiltinArgs P B StoreTy.empty PublicNames.checkName RefinementCheck.signature
      [OptionField.carrier,OptionField.expected] [] [] [OptionField.absent]
      (result OptionField.expected) Eff.empty ∧
    (OptionField.predicate.open (.dataValue "Option.None" [])).evalClosed = none ∧
    erase (call OptionField.carrier OptionField.expected OptionField.absent) =
      call OptionField.carrier OptionField.expected OptionField.absent ∧
    HasTypeCQ P B StoreTy.empty Qempty [] [] [] none
      (erase (call OptionField.carrier OptionField.expected OptionField.absent))
      (result OptionField.expected) Eff.empty [] ∧
    RefinementCheck.delta checkExpectedText PublicNames.checkName [OptionField.carrier,OptionField.expected]
      [] [] [OptionField.absent] =
      some (.val (rejected OptionField.expected (checkExpectedText OptionField.expected))) := by
  have witness := OptionField.undecided externals checkExpectedText
  refine ⟨witness.1,witness.2.1,?_,?_,witness.2.2⟩
  · exact erase_refined_rejected (sort := .data) rfl rfl (Or.inr witness.2.1)
  · exact (erase_typed (check_declarations externals) checkExpectedText
      (standard_agreement (program externals) OptionField.carrier OptionField.expected OptionField.absent).1 witness.1).2

/-- 正常な成功値に、任意の継続・ストアの観測保存を実際に適用する。 -/
theorem integer_observations (P : Program) (σ : PathEnv) (k : Cont) (μ : Store) :
    let v := Val.const (.integer ⟨1,by decide⟩)
    let source := State.run (Closure.pure (call (.base .integer) nonnegative v)) k μ
    let target := State.run (Closure.pure (.ret (ok nonnegative v))) k μ
    (∀ events z, z.Final → (Steps P (builtins P) σ source events z ↔
      Steps P (builtins P) σ target events z)) ∧
    Steps P (builtins P) σ source [] target := by
  dsimp only
  have agree := standard_agreement P (.base .integer) nonnegative (.const (.integer ⟨1,by decide⟩))
  have obs := observations_preserved (P := P) (σ := σ) (k := k) (μ := μ) (q := Closure.pure
    (call (.base .integer) nonnegative (.const (.integer ⟨1,by decide⟩))))
    (show (Closure.pure (call (.base .integer) nonnegative (.const (.integer ⟨1,by decide⟩)))).view =
      call (.base .integer) nonnegative (.const (.integer ⟨1,by decide⟩)) from rfl)
    agree.1 agree.2 rfl rfl rfl rfl (by decide)
  rw [erase_check (t := .base .integer) (u := nonnegative) rfl rfl rfl rfl (by decide)] at obs
  refine ⟨obs.2.1,?_⟩
  have path := (obs.1 [] _).mpr (show Execution P (builtins P) σ _ [] _ from rfl)
  exact path.steps

end
end Benitoite.Release.Refinement.CheckErasure
