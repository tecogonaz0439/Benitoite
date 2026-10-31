import Lean
import Benitoite.Release.Refinement.Canonical

namespace Benitoite.Release.Refinement.InversionBoundary

abbrev U : Ty := .base .unit
abbrev R : Ty := .refined U .truth

private theorem unit_annotation (P : Program) (C : List TParam) (Γ : Ctx) :
    Ty.Annotation P C Γ U := by
  exact ⟨trivial, trivial, trivial⟩

private theorem refined_annotation (P : Program) (C : List TParam) (Γ : Ctx) :
    Ty.Annotation P C Γ R := by
  exact ⟨⟨trivial, trivial, by simp [Ty.NotContCore, Ty.core]⟩, ⟨trivial, trivial⟩, ⟨trivial, trivial⟩⟩

private theorem true_intro (Γ : Ctx) (Φ : List Pred) (a : Ty) :
    Ty.LeQ Γ Φ a (.refined a .truth) := .introduce trivial .truth

theorem list_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.list [.const .unit])
      (.refined (.list U) .truth) := by
  have hv : HasTypeVQ P B Ψ Qempty [] [] [] (.const .unit) R :=
    .V_Sub (.V_Const trivial) (true_intro [] [] U)
      (refined_annotation P [] []).wf (refined_annotation P [] []).sorted
      (refined_annotation P [] []).declared
  have hlist : HasTypeVQ P B Ψ Qempty [] [] [] (.list [.const .unit]) (.list R) :=
    .V_List (.cons hv .nil) (refined_annotation P [] []).wf
      (refined_annotation P [] []).sorted (refined_annotation P [] []).declared
  have hwide : HasTypeVQ P B Ψ Qempty [] [] [] (.list [.const .unit]) (.list U) :=
    .V_Sub hlist (.trans (.list .forget) .refl) trivial trivial trivial
  exact .V_Sub hwide (true_intro [] [] (.list U))
    ⟨trivial, trivial, by simp [Ty.NotContCore, Ty.core]⟩ ⟨trivial, trivial⟩ ⟨trivial, trivial⟩

theorem list_extract (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ∃ a, HasTypeEachQ P B Ψ Qempty [] [] [] [.const .unit] a ∧ Ty.LeQ [] [] a U := by
  obtain ⟨a, hv, b, hb, hl⟩ := (list_typed P B Ψ).inv_list rfl
  have he : b = U := Option.some.inj hb.symm
  exact ⟨a, hv, he ▸ hl⟩

theorem function_chain :
    Ty.LeQ [] []
      (.refined (.dependentFn (.param "x" U (.done R Eff.empty))) .truth)
      (.refined (.dependentFn (.param "x" R (.done U Eff.empty))) .truth) :=
  .trans .forget (.trans (.dependentFn (.tail .refl
    (.param .forget (.done .forget (Eff.Covers.refl _ _ _)))))
    (true_intro [] [] _))

theorem function_extract :
    TelClosure [] [] (.param "x" U (.done R Eff.empty)) (.param "x" R (.done U Eff.empty)) := by
  obtain ⟨t, ht, hc⟩ := function_chain.fnCore rfl
  have he : t = .param "x" R (.done U Eff.empty) := Option.some.inj ht.symm
  exact he ▸ hc

theorem names_extract :
    (Tel.param "x" U (.done R Eff.empty)).names =
      (Tel.param "x" R (.done U Eff.empty)).names :=
  function_chain.names_eq rfl rfl

theorem names_change_rejected :
    ¬ Ty.LeQ [] [] (.dependentFn (.param "x" U (.done U Eff.empty)))
      (.dependentFn (.param "y" U (.done U Eff.empty))) := by
  intro h
  have he := h.names_eq rfl rfl
  simp [Tel.names] at he

theorem reference_typed (P : Program) (B : Builtins) (Ψ : StoreTy)
    (hl : Ψ 0 = some (.ref U)) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.loc 0) (.refined (.reference U) .truth) := by
  exact .V_Sub (.V_Sub (.V_LocRef hl trivial) .refl trivial trivial trivial)
    (true_intro [] [] (.reference U))
    ⟨trivial, trivial, by simp [Ty.NotContCore, Ty.core]⟩ ⟨trivial, trivial⟩ ⟨trivial, trivial⟩

theorem reference_extract (P : Program) (B : Builtins) (Ψ : StoreTy)
    (hl : Ψ 0 = some (.ref U)) :
    ∃ l b, (Val.loc 0) = .loc l ∧ Ψ l = some (.ref b) ∧ b.norm = U.norm :=
  (reference_typed P B Ψ hl).canonical_ref rfl

theorem reference_covariance_rejected : ¬ Ty.LeQ [] [] (.reference (.refined U .falsity)) (.reference U) := by
  intro h
  obtain ⟨b, hb, he⟩ := h.refCore rfl
  have hb' : b = U := Option.some.inj hb.symm
  rw [hb'] at he
  cases he

theorem fail_normal_equality :
    (Eff.singleFail (.fn [] [] U (.mk (fun _ => false) [U, U]))).memFail
      (.fn [] [] U (.mk (fun _ => false) [U])) := by
  apply (Eff.memFail_single_iff _ _).mpr
  simp [Ty.norm, Eff.norm, Ty.normTys, Order.sortUnique, Order.insertUnique, (tyCompare_eq_iff _ _).mpr rfl]

theorem fail_covariance_rejected : ¬ (Eff.singleFail (.refined U .falsity)).memFail U := by
  intro h
  have he := (Eff.memFail_single_iff (.refined U .falsity) U).mp h
  cases he

theorem kinded_list : rawApply (.ctor .list) [R] = .list R := rfl

theorem kinded_list_extract (P : Program) :
    (Ty.ctor .list) = .ctor .list ∧ ([R] : List Ty) = [R] :=
  rawApply_list_inv (P := P) (K := []) (n := 1) rfl rfl kinded_list

theorem refined_constructor_rejected (P : Program) :
    ¬ Ty.HasKind P [] (.refined (.ctor .list) .truth) (.constructor 1) :=
  Ty.HasKind.not_refined_constructor

theorem value_image_accepts_refinement (P : Program) : Ty.HasKind P [] R .value := by
  exact ⟨trivial, by simp [Ty.NotContCore, Ty.core]⟩

private def kindedImage : Nat → Ty
  | 0 => .ctor .list
  | _ => R

theorem substitution_images (P : Program) :
    TypeImagesKinded P [.constructor 1, .value] [] kindedImage := by
  intro i k hk
  cases i with
  | zero =>
    simp only [List.getElem?_cons_zero, Option.some.injEq] at hk
    cases hk
    exact ⟨rfl, by intro h; cases h⟩
  | succ i =>
    cases i with
    | zero =>
      simp only [List.getElem?_cons_succ, List.getElem?_cons_zero, Option.some.injEq] at hk
      cases hk
      exact ⟨value_image_accepts_refinement P, by intro _; simp [Ordinary, kindedImage]⟩
    | succ i => simp at hk

theorem substitution_leaf (P : Program) :
    rawApply (kindedImage 0) [kindedImage 1] = .list R ∧
      kindedImage 0 = .ctor .list ∧ ([kindedImage 1] : List Ty) = [R] := by
  have he : rawApply (kindedImage 0) [kindedImage 1] = .list R := rfl
  exact ⟨he, (substitution_images P).list_inv (i := 0) (n := 1) rfl rfl he⟩

theorem raw_unkinded_inversion_false :
    rawApply (.list U) [R] = .list U ∧ (Ty.list U) ≠ .ctor .list := ⟨rfl, by intro h; cases h⟩

private theorem lambda_annotation (P : Program) : Ty.Annotation P [] [] (.fn [] [] U Eff.empty) := by
  exact ⟨⟨⟨rfl, by simp⟩, trivial, trivial, trivial, rfl⟩, ⟨trivial, trivial, trivial⟩,
    ⟨trivial, trivial, trivial⟩⟩

theorem lambda_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.lam [] [] (.ret (.const .unit))) (.fn [] [] U Eff.empty) :=
  .V_Lam ⟨rfl, by simp⟩ (lambda_annotation P).wf (lambda_annotation P).sorted
    (.C_Return (.V_Const trivial)) (lambda_annotation P).declared

private theorem empty_done : Capture.empty.closeTel (.done U Eff.empty) = .done U Eff.empty :=
  by
    change Tel.norm (Tel.rawBind (SubstEnv.valuesOnly (valEnv Capture.empty.env).values) (.done U Eff.empty)) = _
    unfold SubstEnv.valuesOnly
    rw [←Tel.rawSubstV_eq_rawBind]
    rw [Tel.rawSubstV_of_wf_zero (show Tel.WF 0 0 0 (.done U Eff.empty) from ⟨trivial, trivial, rfl⟩)]
    rfl

theorem closed_lambda_dependent (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] []
      (closeVal Capture.empty (.lam [] [] (.ret (.const .unit))))
      (.dependentFn (.done U Eff.empty)) := by
  have ha : Ty.Annotation P [] [] (.dependentFn (.done U Eff.empty)) :=
    ⟨⟨trivial, trivial, rfl⟩, ⟨trivial, trivial⟩, ⟨trivial, trivial⟩⟩
  have hb : DependentClosureTy P B Ψ (.mk Capture.empty (.ret (.const .unit)))
      (Capture.empty.closeTel (.done U Eff.empty)) :=
    .mk (CaptureOk.empty P B _ _)
      (.done (.C_Return (.V_Const trivial))) ha (by rw [empty_done]; exact ha)
  rw [empty_done] at hb
  change HasTypeVQ P B Ψ Qempty [] [] []
    (.closure (Capture.empty.closeTel (.done U Eff.empty)) (.mk Capture.empty (.ret (.const .unit)))) _
  rw [empty_done]
  exact .V_Closure ha ⟨⟨trivial, trivial, rfl⟩, ⟨trivial, trivial, rfl⟩, trivial⟩ hb

theorem closed_lambda_extract (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ∃ t u, Ty.Annotation P [] [] (.dependentFn t) ∧
      Tel.RuntimeShape (.done U Eff.empty) t ∧
      DependentClosureTy P B Ψ (.mk Capture.empty (.ret (.const .unit))) t ∧
      (Ty.dependentFn (.done U Eff.empty)).fnCore = some u ∧ TelClosure [] [] t u :=
  (closed_lambda_dependent P B Ψ).inv_closure (by
    change Val.closure (Capture.empty.closeTel (.done U Eff.empty)) _ = _
    rw [empty_done])


theorem closed_lambda_fn (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] []
      (closeVal Capture.empty (.lam [] [] (.ret (.const .unit))))
      (.fn [] [] U Eff.empty) :=
  (closed_lambda_dependent P B Ψ).convert (Ty.norm_toTel (ns := []) (ps := []) (r := U) (e := Eff.empty) ⟨rfl, by simp⟩) (lambda_annotation P)

theorem closed_lambda_fn_extract (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ∃ t u, Ty.Annotation P [] [] (.dependentFn t) ∧
      Tel.RuntimeShape (.done U Eff.empty) t ∧
      DependentClosureTy P B Ψ (.mk Capture.empty (.ret (.const .unit))) t ∧
      (Ty.fn [] [] U Eff.empty).fnCore = some u ∧ TelClosure [] [] t u :=
  (closed_lambda_fn P B Ψ).inv_closure (by
    change Val.closure (Capture.empty.closeTel (.done U Eff.empty)) _ = _
    rw [empty_done])

end Benitoite.Release.Refinement.InversionBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn ".InversionBoundary.").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
