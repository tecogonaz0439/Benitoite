import Benitoite.Release.Refinement.ProgramWellFormed
import Benitoite.Release.Refinement.ValueBinding

/-! # 外部ABIの型形と依存する実引数の具体化 -/
namespace Benitoite.Release.Refinement.Surface.PredicateOverlayExternalShape
noncomputable section

private theorem key_core {a : Ty} (h : ExternalMapKey a) : ExternalMapKey a.core := by
  cases a with
  | refined a _ => exact key_core (a := a) h
  | _ => exact h

private theorem key_refine {a : Ty} (h : ExternalMapKey a) (p : Pred) :
    ExternalMapKey (a.refineNorm p) := by
  unfold Ty.refineNorm
  have base := key_core h
  generalize a.refinementPredicates ++ p.conjuncts = ps
  cases ps <;> exact base

private theorem key_norm {a : Ty} (h : ExternalMapKey a) : ExternalMapKey a.norm := by
  cases a with
  | base _ => exact h
  | refined a p => exact key_refine (key_norm (a := a) h) p
  | _ => cases h

private theorem value_core {P component unit a} (h : ExternalValueType P component unit a) :
    ExternalValueType P component unit a.core := by
  cases a with
  | refined a _ => cases h with | refined original => exact value_core (a := a) original
  | _ => exact h

private theorem value_refine {P component unit a} (h : ExternalValueType P component unit a)
    (p : Pred) : ExternalValueType P component unit (a.refineNorm p) := by
  unfold Ty.refineNorm
  have base := value_core h
  generalize a.refinementPredicates ++ p.conjuncts = ps
  cases ps with
  | nil => exact base
  | cons _ _ => exact .refined base

/-- 外部ABIの有限な型の展開は、型の正規化でも成り立つ。 -/
theorem value_norm {P component unit a} (h : ExternalValueType P component unit a) :
    ExternalValueType P component unit a.norm := by
  induction h with
  | scalar valid => exact .scalar valid
  | unit => exact .unit
  | bytes => exact .bytes
  | handle found component same arity empty =>
    subst empty
    exact .handle found component same arity rfl
  | list _ ih => exact .list ih
  | map key _ ih => exact .map (key_norm key) ih
  | flags cs unique lower upper complete arity fields =>
    exact .flags cs unique lower upper complete
      (by simpa only [Ty.normTys_eq_map, List.length_map] using arity) fields
  | data cs unique nonempty complete arity fields _ =>
    apply ExternalValueType.data cs unique nonempty complete
      (by simpa only [Ty.normTys_eq_map, List.length_map] using arity)
    intro c cd found owner field member
    simpa only [Ty.subst_norm_images] using fields c cd found owner field member
  | refined _ ih => exact value_refine ih _

private theorem key_substV {a : Ty} (h : ExternalMapKey a) (ν : ObservationEnv) :
    ExternalMapKey (a.substV ν) := by
  cases a with
  | base _ => exact h
  | refined a p => exact key_refine (key_substV (a := a) h ν) _
  | _ => cases h

private theorem substV_data (d : DataName) (ts : List Ty) (ν : ObservationEnv) :
    (Ty.data d ts).substV ν = .data d (bindDataArgs ν ts) := by
  exact Ty.bind_data d ts (SubstEnv.valuesOnly ν)

/-- 適格な宣言表の外部ABIの型形は、外側の値参照の具体化でも成り立つ。 -/
theorem value_substV {P : Program} {component unit a} (wf : P.WellFormed)
    (h : ExternalValueType P component unit a) (ν : ObservationEnv) :
    ExternalValueType P component unit (a.substV ν) := by
  induction h with
  | scalar valid => exact .scalar valid
  | unit => exact .unit
  | bytes => exact .bytes
  | handle found component same arity empty =>
    subst empty
    exact .handle found component same arity rfl
  | list _ ih => exact .list ih
  | map key _ ih => exact .map (key_substV key ν) ih
  | @flags unit d ts cs unique lower upper complete arity fields =>
    change ExternalValueType _ _ _ (.set ((Ty.data d ts).substV ν))
    rw [substV_data]
    exact .flags cs unique lower upper complete
      (by simpa only [bindDataArgs_length] using arity) fields
  | @data unit d ts cs unique nonempty complete arity fields ih =>
    rw [substV_data]
    apply ExternalValueType.data cs unique nonempty complete
      (by simpa only [bindDataArgs_length] using arity)
    intro c cd found owner field member
    have closed : field.WF 0 cd.ntys 0 := by
      have annotation := ((wf.cons c cd found).2 field member).2.1.wf
      simpa only [List.length_replicate, List.length_nil] using annotation
    rw [← Ty.substV_subst_closed closed]
    exact ih c cd found owner field member
  | refined _ ih => exact value_refine ih _

/-- 依存列の各引数と結果のABI型形は正規化でも成り立つ。 -/
theorem tel_norm {P component effect t} (h : ExternalTelWF P component effect t) :
    ExternalTelWF P component effect.norm (Tel.norm t) := by
  induction h with
  | done value same => exact .done (value_norm value) (congrArg Eff.norm same)
  | param value _ ih => exact .param (value_norm value) ih

/-- 値束縛後の依存列にも、各引数と結果のABI型形を持つ効果の証人がある。 -/
theorem tel_bind_values {P : Program} {component effect t} (wf : P.WellFormed)
    (h : ExternalTelWF P component effect t) (ν : ObservationEnv) :
    ∃ effect', ExternalTelWF P component effect' (Tel.bind (SubstEnv.valuesOnly ν) t) := by
  induction h generalizing ν with
  | done value _ => exact ⟨_, .done (value_substV wf value ν) rfl⟩
  | param value rest ih =>
    obtain ⟨effect', shape⟩ := ih (upValues ν)
    refine ⟨effect', .param (value_substV wf value ν) ?_⟩
    exact shape

end
end Benitoite.Release.Refinement.Surface.PredicateOverlayExternalShape
