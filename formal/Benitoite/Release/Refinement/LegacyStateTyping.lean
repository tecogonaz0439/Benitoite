import Benitoite.Release.Refinement.LegacyHeldTyping
import Benitoite.Release.Refinement.ClosureTyping
import Benitoite.Release.Refinement.MatchPaths
import Benitoite.Release.Refinement.ClosureViewTyping

/-! # 旧継続と状態の片方向の埋め込み（設計書 01-12「旧判断の適格な入力」） -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem legacy_closed_annotation {K P0 B0 B Ψ Γ R m a e}
    (input : LegacyClosedCompInput K P0 B0 B Ψ Γ R m a e) :
    Ty.Annotation (embedProgramWithKinds K P0) [] [] (.dependentFn (.done (embedTy a) (embedEff e))) := by
  have ha := input.1.regular.2.2.1.annotation (a := a) (by simp) rfl []
  have he := (input.1.regular.2.2.2.1 e (by simp)).annotation_at rfl rfl []
  exact ⟨⟨ha.wf,he.wf.2.2.2⟩,⟨ha.sorted,he.sorted.2.2⟩,⟨ha.declared,he.declared.2.2⟩⟩

private theorem legacy_closed_return {K P0 B0 B Ψ Γ R m a e}
    (input : LegacyClosedCompInput K P0 B0 B Ψ Γ R m a e) :
    ∀ r, R.map embedTy = some r → Ty.Annotation (embedProgramWithKinds K P0) [] [] r ∧ r.Normal := by
  intro r hr
  obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp hr
  have ha := input.1.regular.2.2.1.annotation (a := old) (by simp [ho]) rfl []
  exact ⟨ha,legacy_normal ha.wf⟩

private theorem legacy_cont_annotation {K P0 Ψ R e a b out Re}
    (input : LegacyContRegular K P0 Ψ R e a b out Re) :
    Ty.Annotation (embedProgramWithKinds K P0) [] [] (embedTy a) :=
  input.2.1.annotation (by simp) rfl []

private theorem legacy_close_type {a : Benitoite.Release.Ty} {nr nt nv : Nat}
    (h : (embedTy a).WF nr nt nv) (cap : Capture) (n : Nat) :
    cap.closeTyAt n (embedTy a) = embedTy a := by
  unfold Capture.closeTyAt
  rw [substTyValues_embed,embedTy_norm,legacy_normal h]

private theorem legacy_pure_let {K P0 B0 B Ψ R m a c e}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (ha : Ty.Annotation (embedProgramWithKinds K P0) [] [] (embedTy a))
    (input : LegacyClosedCompInput K P0 B0 B Ψ [some a] R m c e) :
    ClosureTy (embedProgramWithKinds K P0) B (embedStoreTy Ψ) [embedTy a]
      (R.map embedTy) (Closure.pure (embedComp m)) (embedTy c) (embedEff e) := by
  have hc := legacy_closed_annotation input
  have hr := legacy_closed_return input
  have hca : Capture.empty.closeTy (embedTy a) = embedTy a := by
    simpa only [Capture.closeTyAt,Capture.closeTy,upSubst_zero] using legacy_close_type ha.wf Capture.empty 0
  have hcc := legacy_close_type hc.wf.1 Capture.empty 1
  have hce : Capture.empty.closeEffAt 1 (embedEff e) = embedEff e :=
    Eff.subst_values_of_wf_zero hc.wf.2.1 hc.wf.2.2 _
  have hR : Capture.empty.closeRAt 1 (R.map embedTy) = R.map embedTy := by
    cases h : R with
    | none => rfl
    | some r => exact congrArg some (legacy_close_type (hr (embedTy r) (by simp [h])).1.wf _ 1)
  have hb := embedHasTypeCQ K [] wf tables input.1 []
  have hh := ClosureTy.mk (ss := [embedTy a]) (Rs := R.map embedTy)
    (a := embedTy c) (e := embedEff e) (CaptureOk.empty _ _ _ _) (by
      change HasTypeCQ _ _ _ _ [] [some ((embedTy a).shiftV 1 0)] [] _ _ _ _ []
      simpa only [legacy_shiftV,legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,
        List.map_nil,List.map_cons,Option.map_some] using hb)
    (CaptureLocals.empty _ _ _) (Comp.resolveLocals_id _).symm
    (by intro t ht; obtain rfl := List.mem_singleton.mp ht; exact ha)
    (by simpa only [List.map_cons,List.map_nil,hca] using
      (show TypeAnnotations (embedProgramWithKinds K P0) [] [] [embedTy a] from by
        intro t ht; obtain rfl := List.mem_singleton.mp ht; exact ha))
    hR
    (by simpa only [List.length_cons,List.length_nil,hcc] using
      (show Ty.Annotation (embedProgramWithKinds K P0) [] _ (embedTy c) from
        (input.1.regular.2.2.1.annotation (by simp) rfl _)))
    (by simpa only [List.length_cons,List.length_nil,hcc,hce] using hc.closed_context)
    (fun r he => (hr r he).1.declared.closed_context (hr r he).1.wf)
    (fun r he => (hr r he).1.declared.closed_context (hr r he).1.wf)
  simpa only [List.map_cons,List.map_nil,hca,List.length_cons,List.length_nil,hcc,hce,Closure.pure] using hh

private theorem legacy_close_return {P : Program} {R : Option Benitoite.Release.Ty}
    (hr : ∀ a ∈ R.toList, Ty.Annotation P [] [] (embedTy a)) :
    Capture.empty.closeR (R.map embedTy) = R.map embedTy := by
  cases h : R with
  | none => rfl
  | some a =>
    have ha := hr a (by simp [h])
    change some (Capture.empty.closeTy (embedTy a)) = some (embedTy a)
    apply congrArg some
    simpa only [Capture.closeTyAt,Capture.closeTy,upSubst_zero] using legacy_close_type ha.wf Capture.empty 0

private theorem legacy_values_map (vs : List Benitoite.Release.Val) : embedVals vs = vs.map embedVal := by
  induction vs <;> simp_all [embedVals]
private theorem legacy_arms_map (arms : List Benitoite.Release.Arm) : embedArms arms = arms.map embedArm := by
  induction arms with
  | nil => rfl
  | cons a arms ih => cases a with
    | mk alts guard body => cases guard <;> simp [embedArms,embedArm,ih]

private theorem legacy_const_matches (p c : Benitoite.Release.Const) :
    patternMatches p (embedConst c) = p.matches c := by cases p <;> cases c <;> rfl

private theorem legacy_const_range (lo hi c : Benitoite.Release.Const) :
    patternRange lo hi (embedConst c) = Benitoite.Release.Const.inRange lo hi c := by
  cases lo <;> cases hi <;> cases c <;> rfl

private theorem closed_take {vs : List Val} (h : Val.ClosedList 0 0 vs) (n : Nat) : Val.ClosedList 0 0 (vs.take n) := by
  induction n generalizing vs with
  | zero => trivial
  | succ n ih => cases vs with
    | nil => trivial
    | cons v vs => exact ⟨h.1,ih h.2⟩
private theorem closed_drop {vs : List Val} (h : Val.ClosedList 0 0 vs) (n : Nat) : Val.ClosedList 0 0 (vs.drop n) := by
  induction n generalizing vs with
  | zero => exact h
  | succ n ih => cases vs with
    | nil => trivial
    | cons v vs => exact ih h.2

mutual
  private theorem legacy_match_embed (p : Pat) (v : Benitoite.Release.Val)
      (hg : (embedVal v).Ground) :
      matchVal p (embedHeldVal v) = (Benitoite.Release.Pat.matchVal p v).map (fun vs => closeVals Capture.empty (embedVals vs)) := by
    cases p <;> cases v <;>
      simp only [embedVal,Val.Ground,Val.ClosedAt] at hg <;>
      simp only [embedHeldVal,embedVal,closeVal,matchVal,Benitoite.Release.Pat.matchVal,
        legacy_const_matches,legacy_const_range,Option.map_none,Option.map_some,embedVals,closeVals]
    all_goals try omega
    all_goals try (split <;> rfl)
    case con.con c ps c' ts args =>
      split <;> simp_all only [legacy_match_list_embed ps args hg.2,Option.map_none]
    case list.list before rest after elems =>
      simp only [legacy_values_map,closeVals_eq_map,List.length_map,←List.map_take,←List.map_drop]
      simp only [←closeVals_eq_map,←legacy_values_map]
      rw [legacy_match_list_embed before _ (by simpa only [legacy_values_map,←List.map_take] using closed_take hg _),
        legacy_match_list_embed after _ (by simpa only [legacy_values_map,←List.map_drop] using closed_drop hg _)]
      by_cases hc : (if rest.isSome then before.length + after.length ≤ elems.length
        else before.length + after.length = elems.length)
      · simp only [hc,ite_true]
        cases Benitoite.Release.Pat.matchList before (elems.take before.length) <;>
          cases Benitoite.Release.Pat.matchList after (elems.drop (elems.length-after.length)) <;>
          cases rest with
          | none => simp [legacy_values_map,closeVals_eq_map,List.map_append]
          | some r => cases r <;> simp [legacy_values_map,closeVals_eq_map,List.map_append,
              embedVal,closeVal,List.map_take,List.map_drop]
      · simp only [hc,ite_false,Option.map_none]
  private theorem legacy_match_list_embed (ps : List Pat) (vs : List Benitoite.Release.Val)
      (hg : Val.ClosedList 0 0 (embedVals vs)) :
      matchList ps (closeVals Capture.empty (embedVals vs)) =
        (Benitoite.Release.Pat.matchList ps vs).map (fun vs => closeVals Capture.empty (embedVals vs)) := by
    cases ps <;> cases vs <;>
      simp only [embedVals,Val.ClosedList] at hg <;>
      simp only [embedVals,closeVals,Benitoite.Release.Pat.matchList,matchList,Option.map_none,Option.map_some]
    case cons.cons p ps v vs =>
      rw [show closeVal Capture.empty (embedVal v) = embedHeldVal v from rfl,
        legacy_match_embed p v hg.1,legacy_match_list_embed ps vs hg.2]
      cases Benitoite.Release.Pat.matchVal p v <;> cases Benitoite.Release.Pat.matchList ps vs <;>
        simp [legacy_values_map,closeVals_eq_map,List.map_append]
end

private theorem legacy_firstAlt_embed (v : Benitoite.Release.Val) (alts : List Alt)
    (hg : (embedVal v).Ground) :
    firstAlt (embedHeldVal v) alts =
      (Benitoite.Release.firstAlt v alts).map (fun vs => closeVals Capture.empty (embedVals vs)) := by
  induction alts with
  | nil => rfl
  | cons alt alts ih =>
    simp only [firstAlt,Benitoite.Release.firstAlt,legacy_match_embed _ _ hg]
    cases hm : Benitoite.Release.Pat.matchVal alt.pat v with
    | none => exact ih
    | some ws =>
      simp only [Option.map_some,legacy_values_map,closeVals_eq_map,List.map_map]
      exact (selectSlots_map _ _ _).trans (congrArg _ (legacy_selectSlots ws alt.slots))

private theorem legacy_prefix {v : Benitoite.Release.Val} {arms : List Benitoite.Release.Arm} {next : Nat}
    (h : Benitoite.Release.MatchPrefix v arms next) (hg : (embedVal v).Ground) :
    MatchPrefix (embedHeldVal v) (embedArms arms) next := by
  intro arm hm hguard
  rw [legacy_arms_map,←List.map_take] at hm
  obtain ⟨old,ho,rfl⟩ := List.mem_map.mp hm
  cases old with
  | mk alts guard body =>
    have hn : guard = none := by cases guard <;> simp_all [embedArm,Arm.guard]
    subst guard
    change firstAlt (embedHeldVal v) alts = none
    have hh : Benitoite.Release.firstAlt v alts = none := h (.mk alts none body) ho rfl
    rw [legacy_firstAlt_embed v alts hg,hh]
    rfl

theorem embedContTy {K : DeclarationKinds} {P0 : Benitoite.Release.Program}
    {B0 : Benitoite.Release.Builtins} {B : Builtins} {σ : PathEnv}
    {Ψ : Benitoite.Release.StoreTy} {R : Option Benitoite.Release.Ty}
    {e : Benitoite.Release.Eff} {k : Benitoite.Release.Cont}
    {a b : Benitoite.Release.Ty} {out : Benitoite.Release.Eff}
    {Re : Option Benitoite.Release.Ty}
    {h : Benitoite.Release.ContTy P0 B0 Ψ R e k a b out Re}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyContInput K P0 B0 B Ψ h) :
    ContTy (embedProgramWithKinds K P0) B σ (embedStoreTy Ψ)
      (R.map embedTy) (embedEff e) (embedCont k) (embedTy a) (embedTy b)
      (embedEff out) (Re.map embedTy) := by
  induction input with
  | @empty R e a out hs hw reg => exact .K_Empty (legacy_eff_sub hs) (legacy_cont_annotation reg)
  | @letFrame R e n k a c b out e1 Re ht hw hs hk reg code tail ih =>
    simpa only [embedCont,List.map_cons,embedFrame,legacy_shiftV,legacy_shiftVEff,legacy_shiftVR] using
      ContTy.K_Let (by simpa only [legacy_shiftV,legacy_shiftVEff,legacy_shiftVR] using
        legacy_pure_let wf tables (legacy_cont_annotation reg) code)
        (legacy_frame_adequate (.letF n) σ) (legacy_cont_annotation reg) (legacy_eff_sub hs) ih
  | mark reg tail ih => exact .K_Mark ih (legacy_cont_annotation reg)
  | @update R e l k a b out Re hl hk reg tail ih =>
    exact .K_Update (by simp only [embedStoreTy,hl,Option.map_some,embedLocTy])
      (legacy_cont_annotation reg) ih
  | @release R e v o k a b out Re hv hr hs hk reg value ground tail ih =>
    exact .K_Release (embedHasTypeVQ K [] wf tables value [])
      (legacy_value_adequate v σ) (by simpa only [tables.resources] using hr)
      (by simpa only [Eff.mem,legacy_eff_test,embedAtoms,Atom.toOld?,Option.map_some,Option.getD_some] using hs) ih
  | @drop R e i k a b out Re b' t' e' R' hl hs hk reg tail ih =>
    exact .K_Drop (b' := embedTy b') (t' := embedTy t') (e' := embedEff e') (R' := R'.map embedTy) (by simp only [embedStoreTy,hl,Option.map_some,embedLocTy])
      (by simpa only [Eff.mem,legacy_eff_test,embedAtoms,Atom.toOld?,Option.map_some,Option.getD_some] using hs) ih
  | @sub R e k a a' b out Re hk hs reg tail ih => exact .K_Sub ih (embedLe hs)

  | @handle R e ec eb cs k t b out Re hk hc hs ht hw reg code closed tail ih =>
    have ha := legacy_cont_annotation reg
    have hr (a : Benitoite.Release.Ty) (hm : a ∈ R.toList) :
        Ty.Annotation (embedProgramWithKinds K P0) [] [] (embedTy a) :=
      reg.2.1.annotation (by simp [hm]) rfl []
    have he := (code.regular.2.2.2.1 ec (by simp)).annotation_at rfl rfl []
    have htype : Capture.empty.closeTy (embedTy t) = embedTy t := by
      simpa only [Capture.closeTyAt,Capture.closeTy,upSubst_zero] using legacy_close_type ha.wf Capture.empty 0
    apply ContTy.K_Handle (Γ := []) (Φ := []) (Rs := R.map embedTy)
      (ts := embedTy t) (ecs := embedEff ec) (ebs := embedEff eb) ih (embedCovers hc) _
      (CaptureOk.empty _ _ _ _) _ (legacy_close_return hr) htype _ _ _ ha _ _
    · have hsub := legacy_eff_sub hs
      rw [legacy_union] at hsub
      have hh := legacy_handled_sub tables cs code.regular.2.1
      refine ⟨?_,?_⟩
      · intro a ha
        rcases (Eff.mem_union_iff _ _ _).mp (hsub.1 a ha) with ha | ha
        · exact (Eff.mem_union_iff _ _ _).mpr (Or.inl ha)
        · exact (Eff.mem_union_iff _ _ _).mpr (Or.inr (hh.1 a ha))
      · intro a ha
        rcases (Eff.memFail_union_iff _ _ _).mp (hsub.2 a ha) with ha | ha
        · exact (Eff.memFail_union_iff _ _ _).mpr (Or.inl ha)
        · exact (Eff.memFail_union_iff _ _ _).mpr (Or.inr (hh.2 a ha))
    · simpa only [legacy_hideBuilders,legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil]
        using embedHasTypeClausesQ K [] wf tables code []
    · exact Eff.subst_values_of_wf_zero he.wf.2.2.2.1 he.wf.2.2.2.2 _
    · have heb := (reg.2.2 eb (by simp)).annotation_at rfl rfl []
      exact Eff.subst_values_of_wf_zero heb.wf.2.2.2.1 heb.wf.2.2.2.2 _
    · exact ⟨⟨ha.wf,he.wf.2.2.2⟩,⟨ha.sorted,he.sorted.2.2⟩,⟨ha.declared,he.declared.2.2⟩⟩
    · intro a hm
      obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp hm
      exact (hr old (by simp [ho])).declared
    · exact legacy_frame_adequate (.handleF cs) σ
  | @handleFail R e ec rest E cs k t b out Re hk hc hn ht hc' hw reg code closed tail ih =>
    have ha := legacy_cont_annotation reg
    have hr (a : Benitoite.Release.Ty) (hm : a ∈ R.toList) :
        Ty.Annotation (embedProgramWithKinds K P0) [] [] (embedTy a) :=
      reg.2.1.annotation (by simp [hm]) rfl []
    have hE := code.regular.2.2.1.annotation (a := E) (by simp) rfl []
    have he := (code.regular.2.2.2.1 ec (by simp)).annotation_at rfl rfl []
    have htype : Capture.empty.closeTy (embedTy t) = embedTy t := by
      simpa only [Capture.closeTyAt,Capture.closeTy,upSubst_zero] using legacy_close_type ha.wf Capture.empty 0
    rw [show embedCont (.handleF cs :: k) = .handleF Capture.empty (embedClauses cs) :: embedCont k from rfl,
      legacy_union,legacy_singleFail]
    exact ContTy.K_Handle_Fail ih (embedCovers hc) (legacy_NoFail hn) (CaptureOk.empty _ _ _ _)
      (by simpa only [legacy_hideBuilders,legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil]
        using embedHasFailureClause K [] wf tables code [])
      (legacy_close_return hr) htype
      (Eff.subst_values_of_wf_zero he.wf.2.2.2.1 he.wf.2.2.2.2 _)
      (by simpa only [Capture.closeTyAt,Capture.closeTy,upSubst_zero] using legacy_close_type hE.wf Capture.empty 0)
      (by intro a hm; obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp hm; exact (hr old (by simp [ho])).declared)
      (embedCovers hc') ha (legacy_frame_adequate (.handleF cs) σ)

  | @guard R e v arms next m k a b out Re e1 ht hs hp hm hk reg code body tail ih =>
    have ha := legacy_closed_annotation body
    have hr := legacy_closed_return body
    have hb := embedHasTypeCQ K [] wf tables body.1 [.truth]
    have hR := legacy_close_return (P := embedProgramWithKinds K P0) (R := R) (by
      intro r he
      have hh : R = some r := by simpa using he
      exact (hr (embedTy r) (by rw [hh]; rfl)).1)
    have htype : Capture.empty.closeTy (embedTy a) = embedTy a := by
      simpa only [Capture.closeTyAt,Capture.closeTy,upSubst_zero] using legacy_close_type ha.wf.1 Capture.empty 0
    have heff : Capture.empty.closeEff (embedEff e1) = embedEff e1 :=
      Eff.subst_values_of_wf_zero ha.wf.2.1 ha.wf.2.2 _
    have hbool : Ty.Annotation (embedProgramWithKinds K P0) [] [] (.refined (.base .boolean) .truth) :=
      ⟨⟨trivial,trivial,by simp [Ty.NotContCore,Ty.core]⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩
    have hgb := GuardBodyTy.mk (CaptureOk.empty (embedProgramWithKinds K P0) B (embedStoreTy Ψ) (R.map embedTy))
      hbool (by simpa only [legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil,Pred.open,predBind] using hb)
      (CaptureLocals.empty _ _ _) (Comp.resolveLocals_id _).symm
      (by rw [htype,heff]; exact ha) hR (fun r he => (hr r he).1.declared)
    have hboolclose : Capture.empty.closeTy (.refined (.base .boolean) .truth) = .base .boolean := by
      simp [Capture.closeTy,substTyValues,Ty.bind,Ty.rawBind,Ty.norm,Ty.refineNorm,
        Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,predBind]
    rw [hboolclose,htype,heff] at hgb
    have hmatch := embedHasTypeCQ K [] wf tables code.1 []
    obtain ⟨t,obs,hv,ho,harm,hx⟩ := hmatch.match_arms rfl
    simpa only [embedCont,List.map_cons,embedFrame,embedHeldVal,Closure.pure,embedTy,legacy_empty,Option.map_none] using
      ContTy.K_Guard (CaptureOk.empty _ _ _ _) hv ho harm (CaptureLocals.empty _ _ _)
      (Arm.resolveLocalsList_id _).symm (fun r he => (hr r he).1.declared) hx rfl hR htype heff
      hgb (legacy_eff_sub hs) (legacy_prefix hp code.2.1) ih
      (legacy_frame_adequate (.guardF v arms next m) σ)

private theorem legacy_store_formation {K P0 Ψ}
    (ctx : LegacyNodeContext K P0 [] Ψ [] []) :
    (embedStoreTy Ψ).WF ∧ (embedStoreTy Ψ).Sorted ∧ StoreTy.Declared (embedProgramWithKinds K P0) (embedStoreTy Ψ) := by
  have formedLoc (lt : Benitoite.Release.LocTy) (hi : LegacyLocInput K P0 .closed lt) :
      (embedLocTy lt).WF ∧ (embedLocTy lt).Sorted ∧ (embedLocTy lt).Declared (embedProgramWithKinds K P0) := by
    cases lt with
    | builder kind => cases kind with
      | string | bytes => exact ⟨trivial,trivial,trivial⟩
      | list a => exact ⟨hi.1.2.1,embedTy_sorted a [],hi.1.2.2.2.1⟩
    | ref a | lazy a => exact ⟨hi.2.1,embedTy_sorted a [],hi.2.2.2.1⟩
    | cont a b e R =>
      have he := hi.2.2.1 e (by simp)
      refine ⟨⟨hi.1.2.1,hi.2.1.2.1,he.2.1.2.2.2.1,he.2.1.2.2.2.2,?_⟩,
        ⟨embedTy_sorted a [],embedTy_sorted b [],embedEff_sorted e []⟩,
        ⟨hi.1.2.2.2.1,hi.2.1.2.2.2.1,he.2.2.2.1.2.2,?_⟩⟩
      · intro r hr
        obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp hr
        exact (hi.2.2.2 old (by simp [ho])).2.1
      · intro r hr
        obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp hr
        exact (hi.2.2.2 old (by simp [ho])).2.2.2.1
  constructor
  · intro l lt hl
    obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp hl
    exact (formedLoc old (ctx.2.2.2.1 l old ho)).1
  constructor
  · intro l lt hl
    obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp hl
    exact (formedLoc old (ctx.2.2.2.1 l old ho)).2.1
  · intro l lt hl
    obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp hl
    exact (formedLoc old (ctx.2.2.2.1 l old ho)).2.2

private theorem legacy_cont_closed {K P0 B0 B Ψ R e k a b out Re}
    {h : Benitoite.Release.ContTy P0 B0 Ψ R e k a b out Re}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyContInput K P0 B0 B Ψ h) : (embedCont k).Closed := by
  induction input with
  | empty => simp [embedCont,Cont.Closed]
  | letFrame reg code tail ih =>
    intro f hf
    rcases List.mem_cons.mp hf with rfl | hf
    · exact ⟨trivial,code.2⟩
    · exact ih _ hf
  | mark reg tail ih | update reg tail ih | drop reg tail ih =>
    intro f hf; rcases List.mem_cons.mp hf with rfl | hf
    · trivial
    · exact ih _ hf
  | release reg value ground tail ih =>
    intro f hf; rcases List.mem_cons.mp hf with rfl | hf
    · exact ground
    · exact ih _ hf
  | handle reg code closed tail ih | handleFail reg code closed tail ih =>
    intro f hf; rcases List.mem_cons.mp hf with rfl | hf
    · exact ⟨trivial,closed⟩
    · exact ih _ hf
  | @guard R e v arms next m k a b out Re e1 ht hs hp hm hk reg code body tail ih =>
    have hmatch := embedHasTypeCQ K [] wf tables code.1 []
    obtain ⟨t,obs,hv,ho,harm,hx⟩ := hmatch.match_arms rfl
    intro f hf; rcases List.mem_cons.mp hf with rfl | hf
    · exact ⟨hv.close_ground (CaptureOk.empty _ _ _ none) rfl (by trivial) code.2.1,
        trivial,code.2.2,trivial,body.2⟩
    · exact ih _ hf
  | sub reg tail ih => exact ih

private theorem legacy_cell {K P0 B0 B Ψ l c} {σ : PathEnv}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyCellInput K P0 B0 B Ψ l c) :
    CellOk (embedProgramWithKinds K P0) B σ (embedStoreTy Ψ) l (embedCell c) ∧ (embedCell c).Closed := by
  cases c with
  | val v =>
    obtain ⟨a,hl,value,ground⟩ := input
    have ha := legacy_value_annotation value.regular
    exact ⟨⟨embedTy a,by simp [embedStoreTy,hl,embedLocTy],
      (embedHasTypeVQ K [] wf tables value []).convert (Ty.norm_idem _).symm ha.norm,
      legacy_value_adequate v σ⟩,ground⟩
  | done v =>
    obtain ⟨a,hl,value,ground⟩ := input
    exact ⟨⟨embedTy a,by simp [embedStoreTy,hl,embedLocTy],embedHasTypeVQ K [] wf tables value [],
      legacy_value_adequate v σ⟩,ground⟩
  | thunk m =>
    obtain ⟨a,hl,code⟩ := input
    have ha := legacy_closed_annotation code
    have ht := embedHasTypeCQ K [] wf tables code.1 []
    have hq := ClosureTy.pure (by simpa [legacy_hideBuilders,legacyTypeCtx,embedTParamsWithKinds] using ht)
      (by simpa only [legacy_empty] using ha) (by intro r hr; cases hr) (legacy_normal ha.wf.1) (by intro r hr; cases hr)
    exact ⟨⟨embedTy a,by simp [embedStoreTy,hl,embedLocTy],(by simpa only [legacy_hideBuilders,legacy_empty] using hq),legacy_frame_adequate (.letF m) σ⟩,trivial,code.2⟩
  | cont k =>
    obtain ⟨b,t,e,R,hl,he,R',e',h,hi⟩ := input
    have hend : EndsWithHandle (embedCont k) := by
      obtain ⟨k1,cs,rfl⟩ := he
      exact ⟨embedCont k1,Capture.empty,embedClauses cs,by simp [embedCont,embedFrame]⟩
    exact ⟨⟨embedTy b,embedTy t,embedEff e,R.map embedTy,by simp [embedStoreTy,hl,embedLocTy],hend,
      R'.map embedTy,embedEff e',embedContTy wf tables hi⟩,legacy_cont_closed wf tables hi⟩
  | used =>
    obtain ⟨b,t,e,R,hl⟩ := input
    exact ⟨⟨embedTy b,embedTy t,embedEff e,R.map embedTy,by simp [embedStoreTy,hl,embedLocTy]⟩,trivial⟩
  | builder c =>
    obtain ⟨kind,hl,hold,hkind,hcontents⟩ := input
    have had := legacy_cell_adequate (.builder c) σ
    cases c with
    | string text =>
      have hk : kind = .string := hold.1.symm
      subst kind
      exact ⟨⟨.string,by simp [embedStoreTy,hl,embedLocTy,embedBuilderKind],⟨hold.2.1,trivial⟩,had⟩,trivial⟩
    | bytes bs =>
      have hk : kind = .bytes := hold.1.symm
      subst kind
      exact ⟨⟨.bytes,by simp [embedStoreTy,hl,embedLocTy,embedBuilderKind],⟨hold.2.1,hcontents⟩,had⟩,trivial⟩
    | list a vs =>
      have hk : kind = .list a := hold.1.symm
      subst kind
      refine ⟨⟨.list (embedTy a),by simp [embedStoreTy,hl,embedLocTy,embedBuilderKind],?_,had⟩,hcontents.2⟩
      exact ⟨by simpa only [BuilderContents.size,embedBuilderContents,embedVals_length,Benitoite.Release.BuilderContents.size,Benitoite.Release.BuilderKind.limit] using hold.2.1,
        (by
          have hc := hkind.1.annotation_at rfl rfl ([] : Ctx)
          exact ⟨hc.wf,hc.sorted,hc.declared⟩),embedHasTypeEachQ K [] wf tables hcontents.1 []⟩

theorem embedStoreOk {K : DeclarationKinds} {P0 : Benitoite.Release.Program}
    {B0 : Benitoite.Release.Builtins} {B : Builtins} {σ : PathEnv}
    {Ψ : Benitoite.Release.StoreTy} {μ : Benitoite.Release.Store}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyStoreInput K P0 B0 B Ψ μ) :
    StoreOk (embedProgramWithKinds K P0) B σ (embedStoreTy Ψ) (embedStore μ) := by
  have formed := legacy_store_formation input.2.1
  obtain ⟨n,hn⟩ := input.1.1
  refine ⟨⟨n,by intro l hl; simp [embedStore,hn l hl]⟩,formed.1,formed.2.1,formed.2.2,?_,?_⟩
  · intro l lt hl hm
    obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp hl
    have hd := input.1.2.2.1 l old ho
    exact hd (by cases hμ : μ l <;> simp_all [embedStore])
  · intro l c hc
    obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp hc
    exact (legacy_cell wf tables (input.2.2 l old ho)).1

private theorem legacy_store_closed {K P0 B0 B Ψ μ}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyStoreInput K P0 B0 B Ψ μ) : (embedStore μ).Closed := by
  intro l c hc
  obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp hc
  exact (legacy_cell (σ := ⟨[],[],[],none,none,none⟩) wf tables (input.2.2 l old ho)).2

theorem embedStateTyE {K : DeclarationKinds} {P0 : Benitoite.Release.Program}
    {B0 : Benitoite.Release.Builtins} {B : Builtins} {σ : PathEnv}
    {Eb : Benitoite.Release.Eff} {s : Benitoite.Release.State}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyStateInput K P0 B0 B Eb s) :
    StateTyE (embedProgramWithKinds K P0) B σ (embedEff Eb) (embedState s) := by
  cases s with
  | run m k μ =>
    obtain ⟨Ψ,R,a,b,e,e1,hk,store,code,sub,cont,closed,kclosed,μclosed⟩ := input
    have ha := legacy_closed_annotation code
    have hr := legacy_closed_return code
    have ht := embedHasTypeCQ K [] wf tables code.1 []
    have hq := ClosureTy.pure (by simpa only [legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil] using ht)
      ha (fun r he => ⟨(hr r he).1.wf,(hr r he).1.declared⟩) (legacy_normal ha.wf.1) (fun r he => (hr r he).2)
    exact ⟨embedStoreTy Ψ,R.map embedTy,embedTy a,embedTy b,embedEff e,embedEff e1,
      embedStoreOk wf tables store,hq,legacy_eff_sub sub,embedContTy wf tables cont,
      legacy_frame_adequate (.letF m) σ,⟨trivial,code.2⟩,legacy_cont_closed wf tables cont,legacy_store_closed wf tables store⟩
  | matchRun v arms next k μ =>
    obtain ⟨Ψ,R,a,b,e,e1,hk,store,code,sub,cont,closed,kclosed,μclosed,hprefix⟩ := input
    have ha := legacy_closed_annotation code
    have hr := legacy_closed_return code
    have ht := embedHasTypeCQ K [] wf tables code.1 []
    have hq := ClosureTy.pure (by simpa only [legacyTypeCtx,embedTParamsWithKinds,List.zip_nil_left,List.map_nil] using ht)
      ha (fun r he => ⟨(hr r he).1.wf,(hr r he).1.declared⟩) (legacy_normal ha.wf.1) (fun r he => (hr r he).2)
    obtain ⟨t,obs,hv,ho,harm,hx⟩ := ht.match_arms rfl
    exact ⟨embedStoreTy Ψ,R.map embedTy,embedTy a,embedTy b,embedEff e,embedEff e1,
      embedStoreOk wf tables store,⟨embedVal v,rfl,hq⟩,legacy_eff_sub sub,embedContTy wf tables cont,
      legacy_held_value_adequate v σ,trivial,legacy_prefix hprefix code.2.1,
      hv.close_ground (CaptureOk.empty _ _ _ none) rfl (by trivial) code.2.1,
      legacy_arms_adequate arms σ,⟨trivial,code.2.2⟩,legacy_cont_closed wf tables cont,legacy_store_closed wf tables store⟩
  | error rs k μ | exit n rs k μ =>
    obtain ⟨Ψ,R,a,b,e,hk,store,cont,kclosed,μclosed⟩ := input
    exact ⟨embedStoreTy Ψ,R.map embedTy,embedTy a,embedTy b,embedEff e,
      embedStoreOk wf tables store,embedContTy wf tables cont,legacy_cont_closed wf tables cont,legacy_store_closed wf tables store⟩

end
end Benitoite.Release.Refinement
