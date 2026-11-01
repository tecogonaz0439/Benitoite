import Benitoite.Release.Refinement.TypeSubstCalls
import Benitoite.Release.Refinement.Capture

/-! # 開いた型・行の像と値置換の交換（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem normImages (c : Nat) (ts : List Ty) (es : List Eff) :
    SubstEnv.SameTypes (typeEnvAt c (ts.map Ty.norm) (es.map Eff.norm))
      (typeEnvAt c ts es).normRows := by
  constructor
  · intro i
    simp only [typeEnvAt,SubstEnv.normRows_types,List.length_map,List.getElem?_map]
    split
    · rfl
    · split
      · cases hi : ts[i-c]? <;> simp [Ty.norm_shiftTypes,Ty.norm_idem]
      · rfl
  · simp only [typeEnvAt,SubstEnv.normRows_rows,List.map_map,Function.comp_def]
    exact List.map_congr_left (fun e _ => (Eff.norm_shiftTypes e c 0).symm)
  · rfl
  · rfl

theorem Ty.substAt_norm_images_all (a : Ty) (c : Nat) (ts : List Ty) (es : List Eff) :
    a.substAt c (ts.map Ty.norm) (es.map Eff.norm) = a.substAt c ts es :=
  (Ty.bind_sameTypes a (normImages c ts es)).trans (Ty.bind_normRows a _)

theorem Eff.substAt_norm_images_all (e : Eff) (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.substAt c (ts.map Ty.norm) (es.map Eff.norm) e = Eff.substAt c ts es e :=
  (Eff.bind_sameTypes e (normImages c ts es)).trans (Eff.bind_normRows e _)

theorem Tel.substAt_norm_images_all (t : Tel) (c : Nat) (ts : List Ty) (es : List Eff) :
    Tel.substAt c (ts.map Ty.norm) (es.map Eff.norm) t = Tel.substAt c ts es t :=
  (Tel.bind_sameTypes t (normImages c ts es)).trans (Tel.bind_normRows t _)

theorem Ty.substAt_substV_images (a : Ty) (c : Nat) (ts : List Ty) (es : List Eff)
    (σ : ObservationEnv) :
    (a.substAt c ts es).substV σ =
      (a.substV σ).substAt c (ts.map (Ty.substV σ)) (es.map (Eff.substV σ)) := by
  rw [Ty.substAt_substV]
  have ht : Ty.substV σ = fun t => (t.rawSubstV σ).norm := by
    funext t; simp only [Ty.substV,Ty.bind,SubstEnv.valuesOnly,←Ty.rawSubstV_eq_rawBind]
  have he : Eff.substV σ = fun e => (Eff.rawSubstV σ e).norm := by
    funext e; simp only [Eff.substV,Eff.bind,SubstEnv.valuesOnly,←Eff.rawSubstV_eq_rawBind]
  rw [ht,he]
  simpa only [ht,he,List.map_map,Function.comp_def] using
    (Ty.substAt_norm_images_all (a.substV σ) c (ts.map (Ty.rawSubstV σ))
      (es.map (Eff.rawSubstV σ))).symm

theorem Eff.substAt_substV_images (e : Eff) (c : Nat) (ts : List Ty) (es : List Eff)
    (σ : ObservationEnv) :
    Eff.substV σ (Eff.substAt c ts es e) =
      Eff.substAt c (ts.map (Ty.substV σ)) (es.map (Eff.substV σ)) (Eff.substV σ e) := by
  rw [Eff.substAt_substV]
  have ht : Ty.substV σ = fun t => (t.rawSubstV σ).norm := by
    funext t; simp only [Ty.substV,Ty.bind,SubstEnv.valuesOnly,←Ty.rawSubstV_eq_rawBind]
  have he : Eff.substV σ = fun e => (Eff.rawSubstV σ e).norm := by
    funext e; simp only [Eff.substV,Eff.bind,SubstEnv.valuesOnly,←Eff.rawSubstV_eq_rawBind]
  rw [ht,he]
  simpa only [ht,he,List.map_map,Function.comp_def] using
    (Eff.substAt_norm_images_all (Eff.substV σ e) c (ts.map (Ty.rawSubstV σ))
      (es.map (Eff.rawSubstV σ))).symm

theorem Tel.substAt_substV_images (t : Tel) (c : Nat) (ts : List Ty) (es : List Eff)
    (σ : ObservationEnv) :
    Tel.substV σ (Tel.substAt c ts es t) =
      Tel.substAt c (ts.map (Ty.substV σ)) (es.map (Eff.substV σ)) (Tel.substV σ t) := by
  have raw : Tel.substV σ (Tel.substAt c ts es t) =
      Tel.substAt c (ts.map (Ty.rawSubstV σ)) (es.map (Eff.rawSubstV σ)) (Tel.substV σ t) := by
    simp only [Tel.substV,Tel.substAt,Tel.bind,Tel.norm_rawBind,SubstEnv.valuesOnly]
    rw [←Tel.rawSubstV_eq_rawBind,←Tel.rawSubstV_eq_rawBind,
      Tel.rawBind_substV t _ rfl σ,typeEnvAt_mapValues]
  rw [raw]
  have ht : Ty.substV σ = fun t => (t.rawSubstV σ).norm := by
    funext t; simp only [Ty.substV,Ty.bind,SubstEnv.valuesOnly,←Ty.rawSubstV_eq_rawBind]
  have he : Eff.substV σ = fun e => (Eff.rawSubstV σ e).norm := by
    funext e; simp only [Eff.substV,Eff.bind,SubstEnv.valuesOnly,←Eff.rawSubstV_eq_rawBind]
  rw [ht,he]
  simpa only [ht,he,List.map_map,Function.comp_def] using
    (Tel.substAt_norm_images_all (Tel.substV σ t) c (ts.map (Ty.rawSubstV σ))
      (es.map (Eff.rawSubstV σ))).symm

theorem Capture.closeTyAt_typeSubst (cap : Capture) (n c : Nat) (ts : List Ty) (es : List Eff)
    (a : Ty) :
    cap.closeTyAt n (a.substAt c ts es) =
      (cap.closeTyAt n a).substAt c (ts.map (cap.closeTyAt n)) (es.map (cap.closeEffAt n)) :=
  Ty.substAt_substV_images a c ts es (valEnv (upSubst n cap.env)).values

theorem Capture.closeEffAt_typeSubst (cap : Capture) (n c : Nat) (ts : List Ty) (es : List Eff)
    (e : Eff) :
    cap.closeEffAt n (Eff.substAt c ts es e) =
      Eff.substAt c (ts.map (cap.closeTyAt n)) (es.map (cap.closeEffAt n)) (cap.closeEffAt n e) :=
  Eff.substAt_substV_images e c ts es (valEnv (upSubst n cap.env)).values

theorem Capture.closeTel_typeSubst (cap : Capture) (c : Nat) (ts : List Ty) (es : List Eff)
    (t : Tel) :
    cap.closeTel (Tel.substAt c ts es t) =
      Tel.substAt c (ts.map cap.closeTy) (es.map cap.closeEff) (cap.closeTel t) :=
  Tel.substAt_substV_images t c ts es (valEnv cap.env).values

theorem Capture.closeRAt_typeSubst (cap : Capture) (n c : Nat) (ts : List Ty) (es : List Eff)
    (R : Option Ty) :
    cap.closeRAt n (R.map (Ty.substAt c ts es)) =
      (cap.closeRAt n R).map (Ty.substAt c (ts.map (cap.closeTyAt n)) (es.map (cap.closeEffAt n))) := by
  cases R with
  | none => rfl
  | some a => exact congrArg some (cap.closeTyAt_typeSubst n c ts es a)

mutual
  theorem Val.toTerm_substTyAt (v : Val) (c : Nat) (ts : List Ty) (es : List Eff) :
      (v.substTyAt c ts es).toTerm? = v.toTerm? := by
    cases v <;> try rfl
    all_goals simp only [Val.substTyAt,Val.toTerm?,Val.toTermSlots_substTyAt]
  theorem Val.toTermSlots_substTyAt (vs : List Val) (c : Nat) (ts : List Ty) (es : List Eff) :
      Val.toTermSlots (Val.substTyAtList c ts es vs) = Val.toTermSlots vs := by
    cases vs <;> simp only [Val.substTyAtList,Val.toTermSlots,Val.toTerm_substTyAt,Val.toTermSlots_substTyAt]
end

noncomputable def BuilderKind.substAt (c : Nat) (ts : List Ty) (es : List Eff) : BuilderKind → BuilderKind
  | .string => .string
  | .bytes => .bytes
  | .list a => .list (a.substAt c ts es)

theorem substKind_typeSubst (ν : Nat → Val) (b : BuilderKind) (c : Nat)
    (ts : List Ty) (es : List Eff) :
    substKind ν (BuilderKind.substAt c ts es b) =
      BuilderKind.substAt c (ts.map (substTyValues ν)) (es.map (substEffValues ν)) (substKind ν b) := by
  cases b with
  | string | bytes => rfl
  | list a =>
    exact congrArg BuilderKind.list
      (Ty.substAt_substV_images a c ts es (valEnv ν).values)

theorem LocalCtx.typeSubst_values (L : LocalCtx) (ν : Nat → Val) (c : Nat)
    (ts : List Ty) (es : List Eff) :
    (L.map (Option.map (BuilderKind.substAt c ts es))).map (Option.map (substKind ν)) =
      (L.map (Option.map (substKind ν))).map
        (Option.map (BuilderKind.substAt c (ts.map (substTyValues ν)) (es.map (substEffValues ν)))) := by
  simp only [List.map_map,Function.comp_def,Option.map_map]
  apply List.map_congr_left
  intro b _
  cases b with
  | none => rfl
  | some b => exact congrArg some (substKind_typeSubst ν b c ts es)

theorem lambdaShape_typeSubst (ns : List String) (ps : List Ty) (c : Nat)
    (ts : List Ty) (es : List Eff) :
    Tel.substAt c ts es (lambdaShape ns ps) =
      lambdaShape ns (ps.map (Ty.substAt c ts es)) := by
  change Tel.bind (typeEnvAt c ts es) (Ty.toTel ns ps (.base .unit) Eff.empty) = _
  rw [Tel.bind_toTel]
  change Ty.toTel ns (ps.map (Ty.substAt c ts es)) (.base .unit)
    (Eff.substAt c ts es Eff.empty) = _
  rw [Eff.substAt_empty]
  rfl


theorem closeVal_dependentLam_typeSubst (cap : Capture) (t : Tel) (body : Comp)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    closeVal cap ((Val.dependentLam t body).substTyAt c ts es) =
      .closure (Tel.substAt c (ts.map cap.closeTy) (es.map cap.closeEff) (cap.closeTel t))
        (.mk cap (body.substTyAt c (ts.map (Ty.shiftV (telBinders t) 0))
          (es.map (Eff.shiftV (telBinders t) 0)))) := by
  change Val.closure (cap.closeTel (Tel.substAt c ts es t)) _ = _
  rw [cap.closeTel_typeSubst]

theorem closeVal_lam_typeSubst (cap : Capture) (ns : List String) (ps : List Ty) (body : Comp)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    closeVal cap ((Val.lam ns ps body).substTyAt c ts es) =
      .closure (Tel.substAt c (ts.map cap.closeTy) (es.map cap.closeEff) (cap.closeTel (lambdaShape ns ps)))
        (.mk cap (body.substTyAt c (ts.map (Ty.shiftV ps.length 0))
          (es.map (Eff.shiftV ps.length 0)))) := by
  change Val.closure (cap.closeTel (lambdaShape ns (ps.map (Ty.substAt c ts es)))) _ = _
  rw [←lambdaShape_typeSubst,cap.closeTel_typeSubst]

end
end Benitoite.Release.Refinement
