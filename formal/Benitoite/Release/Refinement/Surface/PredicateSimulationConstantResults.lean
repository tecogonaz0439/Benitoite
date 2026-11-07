import Benitoite.Release.Refinement.Surface.PredicateSimulationConstantInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationReplyAvoid

/-! # 標準の有限な純粋結果の型と内部名不生成 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

/-- 純粋な固定行が返す定数・bytes・有限リスト・標準Optionの型。 -/
inductive ConstantResultType : Ty → Prop where
  | base (tag) : ConstantResultType (.base tag)
  | bytes : ConstantResultType .bytes
  | list {a} : ConstantResultType a → ConstantResultType (.list a)
  | option {a} : ConstantResultType a → ConstantResultType (.data "Option" [a])

theorem ConstantResultType.normal {a} (shape : ConstantResultType a) : a.norm = a := by
  induction shape with
  | base _ | bytes => rfl
  | list _ ih => simp only [Ty.norm,ih]
  | option _ ih => simp only [Ty.norm,Ty.normTys,ih]

/-- 標準Optionの二構成子以外がないことと対応先の型付けから、結果の内部名不生成を得る。 -/
theorem constant_result_noMint {P B Ψ Q keys value a}
    (options : StandardActualListBodies.ListOptionDeclarations P) (valid : P.VarianceValid)
    (shape : ConstantResultType a) (typed : HasTypeVQ P B Ψ Q [] [] [] value a) : ValueAvoid keys value := by
  induction shape generalizing value with
  | base tag => exact constant_input_noMint (.base tag) typed
  | bytes => exact constant_input_noMint .bytes typed
  | @list a shape ih =>
    obtain ⟨values,_,rfl,_,_⟩ := typed.canonical_list (a := a) rfl
    have normal : (.list a : Ty).norm = .list a := by simp only [Ty.norm,shape.normal]
    obtain ⟨elements,_⟩ := PatternBindings.list_elements (normal ▸ typed) rfl
    exact ValueAvoid.list (fun value member => ih (shape.normal ▸ elements.member member))
  | @option a shape ih =>
    rcases typed.canonical_data (d := "Option") (ts := [a])
      (by simp only [Ty.norm,Ty.normTys,shape.normal,Ty.core]) with ⟨c,types,values,rfl⟩ | ⟨detail,rfl⟩
    · obtain ⟨cd,found,_,_,_,_,us,tag,_⟩ := typed.inv_con rfl
      have owner : cd.data = "Option" := (Ty.data.inj tag).1.symm
      rcases options.only c cd found owner with none | some
      · subst c
        have same := Option.some.inj (found.symm.trans options.none_decl)
        subst cd
        have fields := PatternBindings.constructor_values valid rfl typed options.none_decl
        cases fields
        exact ValueAvoid.con (ValuesAvoid.nil _) _ _
      · subst c
        have same := Option.some.inj (found.symm.trans options.some_decl)
        subst cd
        have fields := PatternBindings.constructor_values valid rfl typed options.some_decl
        have simplified : HasTypeVsQ P B Ψ Q [] [] [] values [a] := by
          simpa [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,SubstEnv.up,shape.normal] using fields
        cases simplified with | cons field rest =>
          cases rest
          exact ValueAvoid.con (ValuesAvoid.cons.mpr ⟨ih field,ValuesAvoid.nil _⟩) _ _
    · obtain ⟨result,declared,tag⟩ := typed.inv_atError rfl
      rw [declared.errorType_eq] at tag
      exact False.elim ((by decide : ("Option" : String) ≠ "Scope.ScopeError") (Ty.data.inj tag).1)

/-- 対応先の純粋結果の型付けは、同じ失敗・終了を含む応答の内部名不生成を与える。 -/
theorem constant_result_outcome_noMint {P B Ψ keys out a}
    (options : StandardActualListBodies.ListOptionDeclarations P) (valid : P.VarianceValid)
    (shape : ConstantResultType a) (typed : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  cases out with
  | val value => exact constant_result_noMint options valid shape typed.1
  | err _ | exit _ => trivial

/-- 固定した単相の署名の型付き応答は、標準の有限結果の形から内部名不生成を得る。 -/
theorem constant_arguments_result_noMint {P B Ψ keys name signature ts es rs values out a e names inputs result}
    (options : StandardActualListBodies.ListOptionDeclarations P) (valid : P.VarianceValid)
    (typed : BuiltinArgs P B Ψ name signature ts es rs values a e)
    (types : signature.tparams = []) (effects : signature.neffs = 0) (ranges : signature.rkinds = [])
    (instantiated : instantiatedTel (Tel.instR [] signature.tel) [] [] = Ty.toTel names inputs result Eff.empty)
    (named : NamesWF names inputs) (shape : ConstantResultType result)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  have resultEq := monomorphic_result_eq typed types effects ranges instantiated named shape.normal
  subst a
  exact constant_result_outcome_noMint options valid shape reply

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
