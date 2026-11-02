import Benitoite.Release.Refinement.CloseTyping
import Benitoite.Release.Refinement.ClosedCapture

/-! # 全実引数と捕捉の置換の交換（設計書 01-12「篩を含む状態の型付け」） -/
namespace Benitoite.Release.Refinement
noncomputable section

mutual
  theorem Val.observation_wf {v : Val} {t : Term} {nt nv : Nat}
      (hv : v.ClosedAt nt nv) (ht : v.toTerm? = some t) : termWF nv t := by
    cases v
    case const c => cases c <;> simp only [Val.toTerm?] at ht <;> cases ht <;> trivial
    all_goals simp only [Val.toTerm?] at ht
    all_goals try contradiction
    case var i => cases ht; exact hv
    case con c ts vs => cases ht; exact Val.observation_slots_wf hv.2
    case list vs => cases ht; exact Val.observation_slots_wf hv
    case mapV ks vs => cases ht; exact ⟨Val.observation_slots_wf hv.1,Val.observation_slots_wf hv.2⟩
    case setV vs => cases ht; exact Val.observation_slots_wf hv
    case atError d =>
      cases ht
      induction d.textFields with
      | nil => trivial
      | cons x xs ih => exact ⟨trivial,ih⟩
    all_goals cases ht; trivial
  theorem Val.observation_slots_wf {vs : List Val} {nt nv : Nat}
      (hv : Val.ClosedList nt nv vs) : varsInSlots (· < nv) (Val.toTermSlots vs) := by
    cases vs with
    | nil => trivial
    | cons v vs =>
      refine ⟨?_,Val.observation_slots_wf hv.2⟩
      cases ht : v.toTerm? with
      | none => trivial
      | some t => exact Val.observation_wf hv.1 ht
end

theorem Term.bind_closed {t : Term} (ht : t.Closed) (ν : ObservationEnv) :
    termBind? ν t = some t := by
  have hh := Term.bind_congr (σ := ν) (τ := fun i => some (.var i))
    (Term.varsIn_mono ht (fun i hi => by omega))
  exact hh.trans (termBind?_id t)

theorem CaptureOk.closed {P B Ψ R Γ Φ cap}
    (hc : CaptureOk P B Ψ R Γ Φ cap) : cap.Closed := by
  have hg : ∀ ov ∈ cap.values, ∀ v, ov = some v → v.Ground := by
    cases hc with
    | mk _ _ _ _ _ hg _ _ => exact hg
  have go : ∀ values : List (Option Val),
      (∀ ov ∈ values, ∀ v, ov = some v → v.Ground) → captureSlotsClosed values := by
    intro values
    induction values with
    | nil => intro _; trivial
    | cons ov rest ih =>
      intro hg
      have hr := ih (fun ov hm v he => hg ov (List.mem_cons_of_mem _ hm) v he)
      cases ov with
      | none => exact hr
      | some v => exact ⟨hg _ List.mem_cons_self v rfl,hr⟩
  cases cap
  exact go _ hg

theorem Capture.extendMany_values (cap : Capture) (vs : List Val) :
    (cap.extendMany vs).values = vs.reverse.map some ++ cap.values := by
  induction vs generalizing cap with
  | nil => rfl
  | cons v vs ih =>
    simpa only [Capture.extendMany,List.foldl_cons,List.reverse_cons,List.map_append,
      List.map_cons,List.map_nil,List.append_assoc,List.singleton_append,Capture.extend_values] using ih (cap.extend v)

theorem Capture.extendMany_env_outer (cap : Capture) (vs : List Val) (i : Nat)
    (hi : vs.length ≤ i) : (cap.extendMany vs).env i = cap.env (i-vs.length) := by
  simp only [Capture.env, Capture.extendMany_values]
  rw [List.getElem?_append_right (by simpa using hi)]
  simp only [List.length_map,List.length_reverse]

theorem Capture.extendMany_env_inner (cap : Capture) (vs : List Val) (i : Nat)
    (hi : i < vs.length) : (cap.extendMany vs).env i = (Capture.empty.extendMany vs).env i := by
  simp only [Capture.env,Capture.extendMany_values]
  rw [List.getElem?_append_left (by simpa using hi),List.getElem?_append_left (by simpa using hi)]

theorem Capture.apply_observations {cap : Capture} (hc : cap.Closed) (vs : List Val) :
    (fun i => ((upSubst vs.length cap.env) i).toTerm?.bind
      (termBind? (valEnv (Capture.empty.extendMany vs).env).values)) =
      (valEnv (cap.extendMany vs).env).values := by
  funext i
  change _ = ((cap.extendMany vs).env i).toTerm?
  by_cases hi : i < vs.length
  · simp only [upSubst,hi,↓reduceIte,Val.toTerm?,Option.bind_some,termBind?]
    exact congrArg Val.toTerm? (cap.extendMany_env_inner vs i hi).symm
  · simp only [upSubst,hi,↓reduceIte,Val.toTerm_rename]
    rw [cap.extendMany_env_outer vs i (Nat.le_of_not_gt hi)]
    cases ht : (cap.env (i-vs.length)).toTerm? with
    | none => rfl
    | some t =>
      have htclosed : t.Closed := Val.observation_wf (hc.env _) ht
      have hr : termBind (fun i => some (.var (i + vs.length))) t = t := by
        simp only [termBind,Term.bind_closed htclosed,Option.getD_some]
      simp only [Option.map_some,hr,Option.bind_some,Term.bind_closed htclosed]

theorem Capture.closeTyAt_apply_all {cap : Capture} (hc : cap.Closed) (vs : List Val) (a : Ty) :
    substTyValues (Capture.empty.extendMany vs).env (cap.closeTyAt vs.length a) =
      (cap.extendMany vs).closeTy a := by
  simp only [Capture.closeTyAt,Capture.closeTy,substTyValues,Ty.bind,
    valEnv,←Ty.rawSubstV_eq_rawBind]
  rw [Ty.norm_rawSubstV,Ty.rawSubstV_comp]
  have he := cap.apply_observations hc vs
  simpa only [valEnv] using congrArg (fun ν => (Ty.rawSubstV ν a).norm) he

theorem Eff.norm_rawSubstV (e : Eff) (ν : ObservationEnv) :
    (Eff.rawSubstV ν e.norm).norm = (Eff.rawSubstV ν e).norm := by
  simpa only [SubstEnv.valuesOnly, ←Eff.rawSubstV_eq_rawBind] using
    Eff.norm_rawBind (SubstEnv.valuesOnly ν) e

theorem Capture.closeEffAt_apply_all {cap : Capture} (hc : cap.Closed) (vs : List Val) (e : Eff) :
    substEffValues (Capture.empty.extendMany vs).env (cap.closeEffAt vs.length e) =
      (cap.extendMany vs).closeEff e := by
  simp only [Capture.closeEffAt,Capture.closeEff,substEffValues,Eff.bind,
    valEnv,←Eff.rawSubstV_eq_rawBind]
  rw [Eff.norm_rawSubstV,Eff.rawSubstV_comp]
  have he := cap.apply_observations hc vs
  simpa only [valEnv] using congrArg (fun ν => (Eff.rawSubstV ν e).norm) he

theorem CaptureOk.bindParams {P B Ψ R Γ Φ cap ss vs}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (ht : TypeAnnotations P [] Γ ss)
    (hv : HasTypeVsQ P B Ψ Qempty [] [] [] vs (ss.map cap.closeTy))
    (hg : ∀ v ∈ vs, v.Ground) :
    CaptureOk P B Ψ R (bindParams Γ ss) (liftMany ss.length Φ) (cap.extendMany vs) := by
  cases ss with
  | nil =>
    cases hv
    simpa only [Refinement.bindParams,List.reverse_nil,List.map_nil,List.nil_append,Capture.extendMany,
      List.foldl_nil,liftMany_eq,List.length_nil,show Pred.shiftV 0 0 = id from funext (fun p => p.shiftV_zero 0),show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hc
  | cons x xs =>
    cases hv with
    | cons hv hvs =>
      rename_i v vs
      have hx := ht x List.mem_cons_self
      have hm : ShiftMap 1 0 Γ (Γ.extend x) := by
        simpa [bindParams,Ctx.extend] using ShiftMap.outer Γ [x]
      have ht' : TypeAnnotations P [] (Γ.extend x) (xs.map (Ty.shiftV 1 0)) := by
        intro a ha
        obtain ⟨b,hb,rfl⟩ := List.mem_map.mp ha
        exact hm.annotation (ht b (List.mem_cons_of_mem _ hb))
      have hvs' : HasTypeVsQ P B Ψ Qempty [] [] [] vs
          ((xs.map (Ty.shiftV 1 0)).map (cap.extend v).closeTy) := by
        simpa only [List.map_map,Function.comp_def,Capture.closeTy_shift] using hvs
      have hh := CaptureOk.bindParams (hc.extend hx hv (hg _ List.mem_cons_self)) ht' hvs'
        (fun v hv => hg v (List.mem_cons_of_mem _ hv))
      simpa only [bindParams_cons,List.length_map,List.length_cons,Capture.extendMany,
        List.foldl_cons,←liftMany_one,liftMany_add,Nat.add_comm 1] using hh
termination_by ss.length

theorem Capture.Closed.extendMany {cap : Capture} {vs : List Val}
    (hc : cap.Closed) (hv : ∀ v ∈ vs, v.Ground) : (cap.extendMany vs).Closed := by
  induction vs generalizing cap with
  | nil => exact hc
  | cons v vs ih =>
    exact ih (show (cap.extend v).Closed from by cases cap; exact ⟨hv _ List.mem_cons_self,hc⟩)
      (fun v h => hv v (List.mem_cons_of_mem _ h))

theorem Capture.Adequate.extendMany {σ : PathEnv} {cap : Capture} {vs : List Val}
    (hc : cap.Adequate σ) (hv : adequateVals σ vs) : (cap.extendMany vs).Adequate σ := by
  induction vs generalizing cap with
  | nil => exact hc
  | cons v vs ih => exact ih (show (cap.extend v).Adequate σ from by cases cap; exact ⟨hv.1,hc⟩) hv.2


theorem Capture.close_pred_apply_all {cap : Capture} (hc : cap.Closed) (vs : List Val) (p : Pred) :
    predBind (valEnv (Capture.empty.extendMany vs).env).values
      (predBind (valEnv (upSubst vs.length cap.env)).values p) =
        predBind (valEnv (cap.extendMany vs).env).values p := by
  rw [predBind_comp]
  exact congrArg (fun ν => predBind ν p) (cap.apply_observations hc vs)

theorem Capture.close_facts_apply_all {cap : Capture} (hc : cap.Closed) (vs : List Val) (Φ : List Pred) :
    (Φ.map (predBind (valEnv (upSubst vs.length cap.env)).values)).map
      (predBind (valEnv (Capture.empty.extendMany vs).env).values) =
        Φ.map (predBind (valEnv (cap.extendMany vs).env).values)
 := by
  simp only [List.map_map,Function.comp_def,Capture.close_pred_apply_all hc]

end
end Benitoite.Release.Refinement
