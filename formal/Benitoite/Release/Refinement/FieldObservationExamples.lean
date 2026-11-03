import Benitoite.Release.Refinement.PreparedLeaf
import Benitoite.Release.Refinement.ClosureTyping

/-! # 宣言した不変欄の連鎖、欠けたスロットと置換後の観測 -/
namespace Benitoite.Release.Refinement.FieldObservationExamples
noncomputable section

private def P : Program :=
  ⟨fun _ => none,
   fun c => if c = "Inner.Make" then some ⟨"Inner",0,[.base .unit,.base .string]⟩
     else if c = "Outer.Make" then some ⟨"Outer",0,[.data "Inner" []]⟩ else none,
   fun _ => none,fun _ => none,fun _ => none,fun _ => none,[],fun _ => none⟩
private def inner : FieldRef := ⟨"Outer","Outer.Make",0,.data⟩
private def text : FieldRef := ⟨"Inner","Inner.Make",1,.string⟩
private def snapshot : Term :=
  .dataValue "Outer.Make" [some (.dataValue "Inner.Make" [none,some (.string "é")])]
private def receiver : Term := .field inner snapshot
private def selected : Term := .field text receiver

private theorem innerArity : P.DataArity "Inner" 0 := by
  refine ⟨⟨"Inner.Make",⟨"Inner",0,[.base .unit,.base .string]⟩,rfl,rfl⟩, ?_⟩
  intro c cd hc hd
  simp only [P] at hc
  split at hc
  · cases hc; rfl
  · split at hc
    · cases hc; simp at hd
    · cases hc

private theorem valid : P.VarianceValid := by
  constructor
  · simp [P]
  · intro c cd hc
    simp only [P] at hc
    split at hc
    · cases hc
      constructor
      · simp [P]
      · intro a ha
        simp only [List.mem_cons, List.not_mem_nil, or_false] at ha
        rcases ha with rfl | rfl <;> exact ⟨⟨trivial,trivial,trivial⟩,trivial,trivial⟩
    · split at hc
      · cases hc
        constructor
        · simp [P]
        · intro a ha
          cases List.mem_singleton.mp ha
          refine ⟨⟨trivial,trivial,?_,trivial⟩, ?_, trivial⟩
          · exact ⟨0,innerArity,rfl⟩
          · exact ⟨TyCon.arity_data innerArity,trivial⟩
      · cases hc

private theorem outerData : Term.HasData P [] snapshot "Outer" [] :=
  .value rfl rfl rfl rfl
private theorem receiverData : Term.HasData P [] receiver "Inner" [] :=
  .field outerData rfl rfl rfl rfl trivial rfl rfl
private theorem selectedDeclared : selected.Declared P [] [] := by
  refine ⟨⟨?_,⟨[],_,.data "Inner" [],outerData,rfl,rfl,rfl,rfl,trivial,rfl⟩⟩,
    ⟨[],_,.base .string,receiverData,rfl,rfl,rfl,rfl,trivial,rfl⟩⟩
  simp only [snapshot, Term.Declared, declaredSlots, declaredSlot]
  exact ⟨⟨⟨⟨trivial,⟨trivial,trivial⟩⟩,_,rfl,rfl⟩,trivial⟩,_,rfl,rfl⟩

theorem field_chain_admissible : selected.AdmissibleIn P [] [] .string ∧ P.VarianceValid := by
  exact ⟨⟨⟨by trivial,⟨⟨rfl,rfl⟩,rfl⟩⟩,selectedDeclared⟩,valid⟩

private def leaf : PreparedLeaf :=
  ⟨.le (.integer 0) (.measure .stringBytes selected),.measureNonnegative,[selected],[]⟩

theorem field_leaf_checked : leaf.checkIn P [] [] [] = true := by
  classical
  have hs := field_chain_admissible.1.1
  have hd := field_chain_admissible.1.2
  have href : selected.VarsIn (Ctx.Readable []) := hs.1
  have hshape := hs.2
  have hex : ∃ s, selected.Shape [] s := ⟨.string,hshape⟩
  have hm : (Term.measure .stringBytes selected).AdmissibleIn P [] [] .integer :=
    ⟨⟨hs.1,hs.2,rfl⟩,hd⟩
  simp [PreparedLeaf.checkIn, Certificate.checkIn, Certificate.check, Certificate.AdmissibleIn,
    Certificate.keys, Certificate.extraKeys, Pred.linearKeys, Term.linearKeys,
    Ctx.facts, Pred.ofConjuncts, KeyTable.checkIn, valid, leaf, predEq_spec, PreparedLeaf.checkRaw,
    BuiltinSchema.candidates, BuiltinSchema.measures, Term.AdmissibleIn, href, hshape, hex, hd, Pred.Sorted, Pred.Declared, Term.HasSort, Term.Shape, Term.References,
    Term.VarsIn, Term.Declared, Ctx.declarationSelf, Measure.input, Measure.output]

example : Entails [] leaf.predicate := PreparedLeaf.entailsIn field_leaf_checked

/-- 同じ閉じた項のmeasureについて、構造合同の反射を照合する。 -/
example : EqProof.check (Term.measure .stringBytes selected) (Term.measure .stringBytes selected)
    (.measure (.field (.field .refl))) = true := by decide

/-- 内側のNoneは埋めず、選んだ文字列のバイト長だけを保つ。 -/
theorem field_chain_stable (ν : ObservationEnv) (η ξ : ObservationEnvModel)
    (hi : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ))) :
    Observation.OptionInfoLE (some (.string "é"))
      ((Term.field text (termBind ν receiver)).observe ξ) ∧
    (Term.measure .stringBytes (.field text (termBind ν receiver))).observe ξ = some (.integer 2) :=
  field_measure_stable ν η ξ hi (by rfl) (by rfl)

private def receiverImage : ObservationEnv := fun | 0 => some receiver | _ => none
private def receiverModel : ObservationEnvModel := fun
  | 0 => some (.dataValue "Inner.Make" [none,some (.string "é")])
  | _ => none

/-- 開いた受け手の変数を実際の欄の像に置き換え、同じ正常結果を読む。 -/
theorem open_field_stable :
    (Term.field text (.var 0)).observe receiverModel = some (.string "é") ∧
    termBind receiverImage (.field text (.var 0)) = selected ∧
    (Term.measure .stringBytes (termBind receiverImage (.field text (.var 0)))).observe
      (fun _ => none) = some (.integer 2) := by
  have info : ∀ i, Observation.OptionInfoLE (receiverModel i)
      ((receiverImage i).bind (Term.observe (fun _ => none))) := by
    intro i
    cases i with
    | zero => exact .some (.refl _)
    | succ i => exact .none _
  have stable := field_measure_stable (r := text) (t := .var 0) (m := .stringBytes) (n := 2)
    receiverImage receiverModel (fun _ => none) info (by rfl) (by rfl)
  exact ⟨rfl,rfl,stable.2⟩

-- closeValの観測交換も、Noneを残す実際のclosureのsnapshotへ適用する。
example (cap : Capture) :
    (closeVal cap (.list [.lam [] [] (.ret (.const .unit)),.const (.string "é")])).toTerm? =
      some (.listValue [none,some (.string "é")]) := by
  rw [closeVal_observation]
  rfl

end
end Benitoite.Release.Refinement.FieldObservationExamples
