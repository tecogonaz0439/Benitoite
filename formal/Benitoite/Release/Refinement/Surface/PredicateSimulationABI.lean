import Benitoite.Release.Refinement.Surface.PredicateOverlayExternal
import Benitoite.Release.Refinement.Surface.PredicateSimulationAlgebra

/-! # 型付きのABI入力と、対応する元の値の等号 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateOverlayExternal
noncomputable section

private theorem values_equal {source rows xs ys} (related : Values source rows xs ys)
    (equal : ∀ y ∈ ys, ∀ x, Value source rows x y → x = y) : xs = ys := by
  cases related with
  | nil => rfl
  | cons head tail =>
    have headEq := equal _ List.mem_cons_self _ head
    have tailEq := values_equal tail (fun y member => equal y (List.mem_cons_of_mem _ member))
    rw [headEq, tailEq]

/-- ABIの構文を持つ対応先の値には、対応元と異なる関数の本体がない。
診断値は同じdetailで対応するため、原入力に何が含まれるかによらず同じ値となる。 -/
theorem abi_shape_equal {source rows x y} (shape : ABIValueShape y)
    (related : Value source rows x y) : x = y := by
  induction shape generalizing x with
  | const c => exact related.constant_right
  | bytes values => cases related; rfl
  | handle handle types => cases related; rfl
  | atError detail => cases related; rfl
  | con values ih =>
    cases related with
    | con children => exact congrArg (Val.con _ _) (values_equal children ih)
  | list values ih =>
    cases related with
    | list children => exact congrArg Val.list (values_equal children ih)
  | map keys values ihKeys ihValues =>
    cases related with
    | map left right => rw [values_equal left ihKeys, values_equal right ihValues]
  | set values ih =>
    cases related with
    | set children => exact congrArg Val.setV (values_equal children ih)

/-- 対応先だけのABI型付けから、対応元が同じ実引数であることを得る。 -/
theorem abi_argument_equal {P B Ψ Q source rows component unit a x y} (valid : P.VarianceValid)
    (shape : ExternalValueType P component unit a) (typed : HasTypeVQ P B Ψ Q [] [] [] y a)
    (related : Value source rows x y) : x = y :=
  abi_shape_equal (abi_value_shape valid shape typed.V_Normal) related

private theorem tel_arguments_equal {P B Ψ source rows component effect t xs ys a e}
    (wf : P.WellFormed) (valid : P.VarianceValid)
    (typed : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ys t a e)
    (shape : ExternalTelWF P component effect t) (related : Values source rows xs ys) : xs = ys := by
  match typed with
  | .done annotation => cases related; rfl
  | .param annotation value rest =>
    cases shape with
    | param valueShape restShape =>
      cases related with
      | cons head tail =>
        have equal := abi_argument_equal valid valueShape value head
        obtain ⟨effect', bound⟩ := PredicateOverlayExternalShape.tel_bind_values wf restShape (openingEnv _)
        rw [← argumentsEnv_eq] at bound
        rw [equal, tel_arguments_equal wf valid rest bound tail]

private theorem typeEnv_nil : typeEnv [] = renEnv id := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1 <;> funext i <;> simp [typeEnv, typeEnvAt, renEnv]

/-- 外部宣言の対応先の型付き実引数だけから、両実引数列の等号を得る。 -/
theorem external_arguments_equal {P B Ψ source rows d ts xs ys a e}
    (wf : P.WellFormed) (valid : P.VarianceValid) (declared : d.WF P)
    (typed : ExternalArgs P B Ψ d ts ys a e) (related : Values source rows xs ys) : xs = ys := by
  have empty := typed.admissible.types_nil declared
  subst ts
  have shape := PredicateOverlayExternalShape.tel_norm declared.shape
  have binding : Tel.bind (typeEnv []) d.parameters = d.parameters.norm := by
    rw [typeEnv_nil, Tel.bind, Tel.rawBind_id]
  rw [← binding] at shape
  exact tel_arguments_equal wf valid typed.arguments shape related

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
