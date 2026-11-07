import Benitoite.Release.Refinement.Surface.PredicateSimulationABI
import Benitoite.Release.Refinement.Surface.PredicateSimulationInvariants

/-! # 定数・bytes・有限リストを受ける固定行の入力 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateOverlayExternal
noncomputable section

/-- 値の型付けから、関数の本体を含まない構文を取り出せる入力型。 -/
inductive ConstantInputType : Ty → Prop where
  | base (tag) : ConstantInputType (.base tag)
  | bytes : ConstantInputType .bytes
  | list {a} : ConstantInputType a → ConstantInputType (.list a)

theorem ConstantInputType.normal {a} (shape : ConstantInputType a) : a.norm = a := by
  induction shape with
  | base _ | bytes => rfl
  | list _ ih => simp only [Ty.norm, ih]

private theorem constant_input_shape {P B Ψ Q y a} (shape : ConstantInputType a)
    (typed : HasTypeVQ P B Ψ Q [] [] [] y a) : ABIValueShape y := by
  induction shape generalizing y with
  | base tag =>
    obtain ⟨c,rfl,_,_⟩ := typed.canonical_scalar rfl
    exact .const c
  | bytes =>
    obtain ⟨values,rfl⟩ := typed.canonical_bytes rfl
    exact .bytes values
  | @list a shape ih =>
    obtain ⟨values,_,rfl,_,_⟩ := typed.canonical_list (a := a) rfl
    have normalized : (.list a : Ty).norm = .list a := by simp only [Ty.norm, shape.normal]
    obtain ⟨elements,_⟩ := PatternBindings.list_elements (normalized ▸ typed) rfl
    exact .list (fun v member => ih (shape.normal ▸ elements.member member))

/-- 対応先の定数・bytes・有限リストの型付けから、対応元との等号を得る。 -/
theorem constant_input_equal {P B Ψ Q source rows x y a} (shape : ConstantInputType a)
    (typed : HasTypeVQ P B Ψ Q [] [] [] y a) (related : Value source rows x y) : x = y :=
  abi_shape_equal (constant_input_shape shape typed) related

private theorem values_names_avoid {keys values} (each : ValuesAvoid keys values) :
    NamesAvoid keys (PredicateGeneratedNames.valuesNames values) := by
  induction values with
  | nil => intro name member; cases member
  | cons head tail ih =>
    intro name member
    rcases List.mem_append.mp member with member | member
    · exact each _ List.mem_cons_self name member
    · exact ih (fun v present => each v (List.mem_cons_of_mem _ present)) name member

/-- 定数・bytes・有限リストの型付き値は、禁止した組込み名を含まない。 -/
theorem constant_input_noMint {P B Ψ Q keys value a} (shape : ConstantInputType a)
    (typed : HasTypeVQ P B Ψ Q [] [] [] value a) : ValueAvoid keys value := by
  induction shape generalizing value with
  | base tag =>
    obtain ⟨c,rfl,_,_⟩ := typed.canonical_scalar rfl
    exact ValueAvoid.constant _ _
  | bytes =>
    obtain ⟨values,rfl⟩ := typed.canonical_bytes rfl
    intro name member
    cases member
  | @list a shape ih =>
    obtain ⟨values,_,rfl,_,_⟩ := typed.canonical_list (a := a) rfl
    have normalized : (.list a : Ty).norm = .list a := by simp only [Ty.norm, shape.normal]
    obtain ⟨elements,_⟩ := PatternBindings.list_elements (normalized ▸ typed) rfl
    exact values_names_avoid (fun v member => ih (shape.normal ▸ elements.member member))

/-- 対応先の正常値の型を使い、失敗・終了を含む応答の内部名不生成を得る。 -/
theorem constant_outcome_noMint {P B Ψ keys out a} (shape : ConstantInputType a)
    (typed : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  cases out with
  | val value => exact constant_input_noMint shape typed.1
  | err _ | exit _ => trivial

private theorem constant_inputs_normal {inputs : List Ty}
    (shapes : ∀ input ∈ inputs, ConstantInputType input) : Ty.normTys inputs = inputs := by
  induction inputs with
  | nil => rfl
  | cons input rest ih =>
    simp only [Ty.normTys, (shapes _ List.mem_cons_self).normal,
      ih (fun type member => shapes type (List.mem_cons_of_mem _ member))]

/-- 各入力の定数・bytes・有限リストの型付けを、両列の等号へまとめる。 -/
theorem constant_values_equal {P B Ψ source rows xs ys types}
    (typed : HasTypeVsQ P B Ψ Qempty [] [] [] ys types)
    (shapes : ∀ type ∈ types, ConstantInputType type) (related : Values source rows xs ys) : xs = ys := by
  match typed with
  | .nil => cases related; rfl
  | .cons value rest =>
    cases related with
    | cons head tail =>
      rw [constant_input_equal (shapes _ List.mem_cons_self) value head,
        constant_values_equal rest (fun type member => shapes type (List.mem_cons_of_mem _ member)) tail]

/-- パラメータを持たない固定行の実署名から、対応先の各実引数の型付けを得る。 -/
theorem monomorphic_arguments_values {P B Ψ name signature ts es rs ys a e names inputs result}
    (typed : BuiltinArgs P B Ψ name signature ts es rs ys a e)
    (types : signature.tparams = []) (effects : signature.neffs = 0) (ranges : signature.rkinds = [])
    (instantiated : instantiatedTel (Tel.instR [] signature.tel) [] [] = Ty.toTel names inputs result Eff.empty)
    (named : NamesWF names inputs) (normal : Ty.normTys inputs = inputs) :
    HasTypeVsQ P B Ψ Qempty [] [] [] ys inputs := by
  have typesNil : ts = [] := List.length_eq_zero_iff.mp (by simpa only [types,List.length_nil] using typed.admissible.typeCount)
  have effectsNil : es = [] := List.length_eq_zero_iff.mp (effects ▸ typed.admissible.rowCount)
  have rangesNil : rs = [] := List.length_eq_zero_iff.mp (by simpa only [ranges,List.length_nil] using typed.ranges.1)
  subst ts; subst es; subst rs
  have arguments := typed.arguments
  rw [instantiated] at arguments
  obtain ⟨values,_,_⟩ := arguments.toTelValues named
  exact normal ▸ values

/-- 単相の実署名が返す結果型を、対応先の実引数の導出から回収する。 -/
theorem monomorphic_result_eq {P B Ψ name signature ts es rs ys a e names inputs result}
    (typed : BuiltinArgs P B Ψ name signature ts es rs ys a e)
    (types : signature.tparams = []) (effects : signature.neffs = 0) (ranges : signature.rkinds = [])
    (instantiated : instantiatedTel (Tel.instR [] signature.tel) [] [] = Ty.toTel names inputs result Eff.empty)
    (named : NamesWF names inputs) (normal : result.norm = result) : a = result := by
  have typesNil : ts = [] := List.length_eq_zero_iff.mp (by simpa only [types,List.length_nil] using typed.admissible.typeCount)
  have effectsNil : es = [] := List.length_eq_zero_iff.mp (effects ▸ typed.admissible.rowCount)
  have rangesNil : rs = [] := List.length_eq_zero_iff.mp (by simpa only [ranges,List.length_nil] using typed.ranges.1)
  subst ts; subst es; subst rs
  have arguments := typed.arguments
  rw [instantiated] at arguments
  exact typed.result.2.symm.trans ((arguments.toTelValues named).2.1.trans normal)

/-- パラメータを持たない固定行の実署名と入力型から、対応する両実引数列の等号を得る。 -/
theorem constant_arguments_equal {P B Ψ source rows name signature ts es rs xs ys a e names inputs result}
    (typed : BuiltinArgs P B Ψ name signature ts es rs ys a e)
    (types : signature.tparams = []) (effects : signature.neffs = 0) (ranges : signature.rkinds = [])
    (instantiated : instantiatedTel (Tel.instR [] signature.tel) [] [] = Ty.toTel names inputs result Eff.empty)
    (named : NamesWF names inputs) (shapes : ∀ input ∈ inputs, ConstantInputType input)
    (related : Values source rows xs ys) : xs = ys :=
  constant_values_equal
    (monomorphic_arguments_values typed types effects ranges instantiated named (constant_inputs_normal shapes))
    shapes related

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
