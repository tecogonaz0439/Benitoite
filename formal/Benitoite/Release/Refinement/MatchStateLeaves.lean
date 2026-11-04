import Benitoite.Release.Refinement.PatternBindingsAdequate
import Benitoite.Release.Refinement.PatternMatchAnnotations
import Benitoite.Release.Refinement.PatternBindingsGround
import Benitoite.Release.Refinement.ClosureStateLeaves
import Benitoite.Release.Refinement.PatternTransport
import Benitoite.Release.Refinement.MatchFacts

/-! # 照合の束縛と実行状態（設計書 01-12「篩を含む状態の型付け」） -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem CaptureOk.match_extend {P B Ψ R Γ Φ cap alts a δ v ws}
    (valid : P.VarianceValid) (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : AltsTy P alts a δ) (hδ : TypeAnnotations P [] Γ δ)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
    (hg : v.Ground) (hm : firstAlt v alts = some ws) :
    CaptureOk P B Ψ R (Refinement.bindParams Γ δ) (liftMany δ.length Φ) (cap.extendMany ws) := by
  have hp' := hp.subst_values cap.env
  have hv' : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a).norm := hv.V_Normal
  have hws := alternatives_bindings_typed valid hp' hv' hm
  change HasTypeVsQ P B Ψ Qempty [] [] [] ws ((δ.map cap.closeTy).map Ty.norm) at hws
  have hwst : HasTypeVsQ P B Ψ Qempty [] [] [] ws (δ.map cap.closeTy) := by
    have hn : ∀ t : Ty, (cap.closeTy t).norm = cap.closeTy t := fun t => Ty.norm_idem _
    simpa only [List.map_map,Function.comp_def,hn] using hws
  exact hc.bindParams hδ hwst (alternatives_bindings_ground hg hm)

theorem CaptureOk.paths_wellFormed {P B Ψ R Γ Φ cap vs t tests v}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (ho : vs.toTerm? = some t)
    (hs : ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs) (hw : FactsWF P [] Γ (pathFacts (some t) tests)) :
    FactsWF P [] [] (pathFacts v.toTerm? tests) := by
  obtain ⟨sort,hs⟩ := hs
  obtain ⟨u,hu,_⟩ := Term.hasSort_bind hs (valEnv cap.env).values
    hc.substOk.observations hc.substOk.references
  have hv' : v.toTerm? = some (termBind (valEnv cap.env).values t) := by
    rw [hv,closeVal_observation,Val.toTerm_subst_optional,ho,Option.bind_some,hu]
    simp only [termBind,hu,Option.getD_some]
  intro p hp
  simp only [pathFacts,hv'] at hp
  obtain ⟨test,htest,rfl⟩ := List.mem_map.mp hp
  have hs := hw _ (List.mem_map.mpr ⟨test,htest,rfl⟩)
  simpa only [PathTest.bind] using hs.map hc.substOk.observations hc.substOk.references hc.substOk.declaration

theorem CaptureOk.matched_facts {P B Ψ R Γ Φ cap vs obs alts v ws}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ho : ∀ t, obs = some t → vs.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs)
    (hw : FactsWF P [] Γ (pathFacts obs (matchedTests alts)))
    (hm : firstAlt v alts = some ws) :
    CaptureOk P B Ψ R Γ (pathFacts obs (matchedTests alts) ++ Φ) cap := by
  apply hc.addEvaluatedFacts hw
  cases obs with
  | none => intro p hp; cases hp
  | some t =>
    obtain ⟨ht,hs⟩ := ho t rfl
    have hw' := hc.paths_wellFormed ht hs hv hw
    exact hc.paths_evaluate ho hv (MatchFacts.matched_paths_true hm
      (fun p hp => ⟨(hw' p hp).wf,(hw' p hp).sorted⟩))

theorem CaptureOk.excluded_facts {P B Ψ R Γ Φ cap vs obs alts a δ v}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ho : ∀ t, obs = some t → vs.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs) (hp : AltsTy P alts a δ)
    (ht : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
    (hw : FactsWF P [] Γ (pathFacts obs (excludedTests alts)))
    (hm : firstAlt v alts = none) :
    CaptureOk P B Ψ R Γ (pathFacts obs (excludedTests alts) ++ Φ) cap := by
  apply hc.addEvaluatedFacts hw
  cases obs with
  | none => intro p hp; cases hp
  | some t =>
    obtain ⟨htm,hs⟩ := ho t rfl
    have hw' := hc.paths_wellFormed htm hs hv hw
    have heval := MatchFacts.excluded_paths_true_of_typing (hp.subst_values cap.env) ht hm
      (fun p hp => ⟨(hw' p hp).wf,(hw' p hp).sorted⟩)
    exact hc.paths_evaluate ho hv heval


private theorem capture_slot (cap : Capture) {ws : List Val} {i : Nat} {w : Val}
    (hw : ws[i]? = some w) : (cap.extendMany ws).env (ws.length-1-i) = w := by
  induction ws generalizing cap i with
  | nil => cases hw
  | cons x xs ih =>
    cases i with
    | zero =>
      cases Option.some.inj hw
      change ((cap.extend w).extendMany xs).env (xs.length+1-1-0) = w
      rw [show xs.length+1-1-0 = xs.length by omega,
        Capture.extendMany_env_outer _ _ _ (by omega)]
      simp only [Nat.sub_self,Capture.extend_env_zero]
    | succ i =>
      have hi := (List.getElem?_eq_some_iff.mp hw).1
      simpa only [Capture.extendMany,List.foldl_cons,List.length_cons,
        show xs.length+1-1-(i+1) = xs.length-1-i by omega] using ih (cap.extend x) hw

private theorem capture_lift_term (cap : Capture) (ws : List Val) (t : Term) :
    termBind (valEnv (cap.extendMany ws).env).values
      (termBind (fun i => some (.var (ws.length+i))) t) =
      termBind (valEnv cap.env).values t := by
  rw [termBind_comp]
  congr 1
  funext i
  simp only [Option.bind_some,termBind?,valEnv]
  rw [Capture.extendMany_env_outer _ _ _ (by omega)]
  simp only [Nat.add_sub_cancel_left]

/-- 実際の束縛で捕捉を延長した後、欄の事実を評価して文脈に追加する。 -/
theorem CaptureOk.field_facts {P B Ψ R Γ Φ cap alts δ obs vs v ws links}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hb : CaptureOk P B Ψ R (Refinement.bindParams Γ δ) (liftMany δ.length Φ) (cap.extendMany ws))
    (ho : ∀ t, obs = some t → vs.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs) (hm : firstAlt v alts = some ws)
    (hlen : ws.length = δ.length) (valid : LinksValid alts δ.length links)
    (hw : FactsWF P [] (Refinement.bindParams Γ δ) (fieldFacts δ.length obs links)) :
    CaptureOk P B Ψ R (Refinement.bindParams Γ δ)
      (fieldFacts δ.length obs links ++ liftMany δ.length Φ) (cap.extendMany ws) := by
  apply hb.addEvaluatedFacts hw
  cases obs with
  | none => intro p hp; cases hp
  | some t =>
    obtain ⟨ht,sort,hs⟩ := ho t rfl
    obtain ⟨u,hu,_⟩ := Term.hasSort_bind hs (valEnv cap.env).values
      hc.substOk.observations hc.substOk.references
    have root : v.toTerm? = some (termBind (valEnv cap.env).values t) := by
      rw [hv,closeVal_observation,Val.toTerm_subst_optional,ht,Option.bind_some,hu]
      simp only [termBind,hu,Option.getD_some]
    intro p hp
    obtain ⟨link,hl,rfl⟩ := List.mem_map.mp hp
    obtain ⟨w,hslot,hread⟩ := MatchFacts.FieldLink.matched (valid link hl) hm
    have envslot : (cap.extendMany ws).env (δ.length-1-link.slot) = w := by
      rw [←hlen]
      exact capture_slot cap hslot
    have hfield := hw _ (List.mem_map.mpr ⟨link,hl,rfl⟩)
    have hvar : ∃ s, (Term.var (δ.length-1-link.slot)).HasSort (Refinement.bindParams Γ δ) s := by
      have hleft := hfield.sorted.1
      cases hm : link.measure with
      | none => rw [hm] at hleft; exact ⟨.integer,hleft⟩
      | some m => rw [hm] at hleft; exact ⟨m.input,hleft.1,hleft.2.1⟩
    obtain ⟨s,hvar⟩ := hvar
    obtain ⟨a,ha,has⟩ := hvar.2
    obtain ⟨tw,htw,_⟩ := hb.substOk.observations _ a s ha has
    change ((cap.extendMany ws).env (δ.length-1-link.slot)).toTerm? = some tw at htw
    rw [envslot] at htw
    have heq : predBind (valEnv (cap.extendMany ws).env).values (link.predicate δ.length t) =
        .eq (viewTerm link.measure tw)
          (viewTerm link.measure (routeTerm (termBind (valEnv cap.env).values t) link.route)) := by
      simp only [FieldLink.predicate,predBind,viewTerm_bind,routeTerm_bind]
      rw [←hlen,capture_lift_term]
      simp only [termBind_var,valEnv,hlen,envslot,htw,Option.getD_some]
    have hwc := hfield.map hb.substOk.observations hb.substOk.references hb.substOk.declaration
    rw [heq] at hwc ⊢
    unfold Pred.evalClosed
    rw [if_pos ⟨hwc.wf,hwc.sorted⟩]
    obtain ⟨_,_,_,_,_,_,_,allowed⟩ := valid link hl
    exact MatchFacts.field_equality_true hread (by rw [root]; rfl) htw
      allowed hwc.sorted.1.2 hwc.sorted.2.2


private theorem prefix_tail {v arms n arm} (h : MatchPrefix v (arm :: arms) (n+1)) :
    MatchPrefix v arms n := by
  intro a ha hg
  exact h a (List.mem_cons_of_mem _ ha) hg

theorem HasTypeArmsQ.capture_plain_success {P B Ψ Γ Φ R Rs obs arms a b e L cap vs v n alts body ws}
    (h : HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs obs arms a b e L)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ho : ∀ t, obs = some t → vs.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs)
    (ht : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
    (hi : arms[n]? = some (.mk alts none body))
    (hpref : MatchPrefix v arms n) (hm : firstAlt v alts = some ws) :
    ∃ δ Ξ links, AltsTy P alts a δ ∧ CaptureOk P B Ψ R Γ Ξ cap ∧
      LinksValid alts δ.length links ∧ FactsWF P [] (bindParams Γ δ) (fieldFacts δ.length obs links) ∧
      HasTypeCQ P B Ψ Qempty [] (Refinement.bindParams Γ δ) (fieldFacts δ.length obs links ++ liftMany δ.length Ξ)
        (Rs.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (e.shiftV δ.length 0)
        (localExtend δ.length L) := by
  match h with
  | .nil _ => simp at hi
  | .plain hp hvf hfw hw hb hs =>
    cases n with
    | zero =>
      cases Option.some.inj hi
      exact ⟨_,_,_,hp,hc.matched_facts ho hv
        (FactsWF.left (by simpa only [pathFacts_append] using hw)) hm,hvf,hfw,hb⟩
    | succ n =>
      have hfail := hpref _ (List.mem_cons_self) rfl
      have hc' := hc.excluded_facts ho hv hp ht
        (FactsWF.right (by simpa only [pathFacts_append] using hw)) hfail
      exact hs.capture_plain_success hc' ho hv ht hi (prefix_tail hpref) hm
  | .guarded _ _ _ _ _ _ _ hs =>
    cases n with
    | zero => cases Option.some.inj hi
    | succ n => exact hs.capture_plain_success hc ho hv ht hi (prefix_tail hpref) hm
termination_by n


theorem Capture.closeTy_shift_many (cap : Capture) (vs : List Val) (a : Ty) :
    (cap.extendMany vs).closeTy (a.shiftV vs.length 0) = cap.closeTy a := by
  induction vs generalizing cap a with
  | nil => simp only [Capture.extendMany,List.foldl_nil,List.length_nil,Ty.shiftV_zero]
  | cons v vs ih =>
    change ((cap.extend v).extendMany vs).closeTy (a.shiftV (vs.length+1) 0) = _
    rw [show a.shiftV (vs.length+1) 0 = (a.shiftV 1 0).shiftV vs.length 0 by
      rw [Ty.shiftV_add,Nat.add_comm 1],ih,Capture.closeTy_shift]

theorem Capture.closeEff_shift_many (cap : Capture) (vs : List Val) (e : Eff) :
    (cap.extendMany vs).closeEff (e.shiftV vs.length 0) = cap.closeEff e := by
  exact (Ty.cont.inj (cap.closeTy_shift_many vs (.cont (.base .unit) (.base .unit) e))).2.2

theorem MatchPrefix.unresolve {v arms n ρ}
    (h : MatchPrefix v (Arm.resolveLocalsList ρ arms) n) : MatchPrefix v arms n := by
  induction n generalizing arms with
  | zero => intro arm ha; cases ha
  | succ n ih =>
    cases arms with
    | nil => intro arm ha; cases ha
    | cons arm arms =>
      cases arm with
      | mk alts guard body =>
        have ht : MatchPrefix v arms n := by
          apply ih
          cases guard <;> exact prefix_tail h
        intro arm hm hg
        rcases List.mem_cons.mp hm with rfl | hm
        · cases guard with
          | some g => cases hg
          | none => exact h (.mk alts none (body.resolveLocals (upLocalSubst (Arm.bindersOf alts) ρ))) List.mem_cons_self rfl
        · exact ht arm hm hg


theorem StateTyE.match_body {P B σ Eb v cap arms n alts body ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.matchRun v cap arms n k μ))
    (hi : arms[n]? = some (.mk alts none body)) (hm : firstAlt v alts = some ws) :
    StateTyE P B σ Eb (.run (.mk (cap.extendMany ws) body) k μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,⟨vs,hv,hq⟩,he,hk,hva,hca,hprefix,hvg,har,hcl,hkc,hμc⟩ := h
  obtain ⟨Γ,Φ,Rs,root,obs,arms0,input,as,es,L,ρ,hcap,ht,ho,hars,hL,hea,hroot,hR,ha,hee,hr,hx⟩ := hq.match_source
  rw [hroot] at hv
  have hi' := hi
  rw [hea] at hi'
  obtain ⟨alts0,g0,body0,hi0,harmeq⟩ := Arm.resolveLocalsList_at hi'
  obtain ⟨healts,heguard,hebody⟩ := Arm.mk.inj harmeq
  have hg0 : g0 = none := by cases g0 <;> first | rfl | cases heguard
  subst g0
  cases healts
  have hvt : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy input) := by
    rw [hv]
    exact close_value_typed hP hPB hB hs.wf hs.sorted hs.declared hcap ht
  obtain ⟨δ,Ξ,links,hpat,hcap',hlinks,hfields,hb⟩ := hars.capture_plain_success hcap ho hv hvt hi0
    ((hea ▸ hprefix).unresolve) hm
  have hinput := open_value_annotation hs.wf hs.sorted hs.declared hcap.contextRegular ht
  have hδ := hpat.bindings_annotation hPB.variance hcap hinput hvt hm
  have hbound := hcap'.match_extend hPB.variance hpat hδ hvt hvg hm
  have hws := alternatives_bindings_typed hPB.variance (hpat.subst_values cap.env) hvt.V_Normal hm
  have hlen : ws.length = δ.length := by simpa only [List.length_map] using hws.length
  have hbound := hcap'.field_facts hbound ho hv hm hlen hlinks hfields
  have hlocal := CaptureLocals.extendMany hs.wf ws hL
  rw [hlen] at hlocal
  have hbEq : body = body0.resolveLocals (upLocalSubst δ.length ρ) := by
    simpa only [hpat.2.1] using hebody
  have hty : (cap.extendMany ws).closeTy (as.shiftV δ.length 0) = a := by
    rw [←hlen,Capture.closeTy_shift_many,ha]
  have hef : (cap.extendMany ws).closeEff (es.shiftV δ.length 0) = e1 := by
    rw [←hlen,Capture.closeEff_shift_many,hee]
  have hret : (cap.extendMany ws).closeR (Rs.map (Ty.shiftV δ.length 0)) = R := by
    cases Rs with
    | none => exact hR
    | some r =>
      change some ((cap.extendMany ws).closeTy (r.shiftV δ.length 0)) = _
      rw [←hlen,Capture.closeTy_shift_many]
      exact hR
  have hrd : ∀ r, Rs.map (Ty.shiftV δ.length 0) = some r → r.Declared P [] (Refinement.bindParams Γ δ) := by
    intro r hh
    obtain ⟨r0,hr0,rfl⟩ := Option.map_eq_some_iff.mp hh
    exact (ShiftMap.outer Γ δ).declared (hr r0 hr0)
  have hdst := ClosureTy.capture_resolved_closed hbound hb hlocal
    (by rw [hty,hef]; exact hq.annotation) hret hrd
  rw [hty,hef,←hbEq] at hdst
  have hclosed : body.ClosedAt 0 (cap.extendMany ws).values.length := by
    have hh := Arm.ClosedList_body hcl.2 hi
    simpa only [Capture.extendMany_values,List.length_append,List.length_map,List.length_reverse,
      hlen,hpat.2.1,Nat.add_comm] using hh
  have hba := alternatives_bindings_adequate hva hm
  have hbal : adequateVals σ ws := by
    suffices hg : ∀ xs : List Val, (∀ w ∈ xs, w.Adequate σ) → adequateVals σ xs from hg ws hba
    intro xs
    induction xs with
    | nil => intro _; trivial
    | cons w xs ih =>
      intro hxs
      exact ⟨hxs w List.mem_cons_self,ih (fun w hw => hxs w (List.mem_cons_of_mem _ hw))⟩
  exact ⟨Ψ,R,a,b,e,e1,hs,hdst,he,hk,
    ⟨hca.extendMany hbal,adequateArms_body har hi⟩,
    ⟨hcl.1.extendMany (alternatives_bindings_ground hvg hm),hclosed⟩,hkc,hμc⟩


theorem HasTypeArmsQ.capture_guard_success {P B Ψ Γ Φ R Rs obs arms a b e L cap vs v n alts guard body ws}
    (h : HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs obs arms a b e L)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ho : ∀ t, obs = some t → vs.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs)
    (ht : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
    (hi : arms[n]? = some (.mk alts (some guard) body))
    (hpref : MatchPrefix v arms n) (hm : firstAlt v alts = some ws) :
    ∃ δ Ξ p links, AltsTy P alts a δ ∧ CaptureOk P B Ψ R Γ Ξ cap ∧
      LinksValid alts δ.length links ∧ FactsWF P [] (bindParams Γ δ) (fieldFacts δ.length obs links) ∧
      Ty.Annotation P [] (hideConts (Refinement.bindParams Γ δ)) (.refined (.base .boolean) p) ∧
      HasTypeCQ P B Ψ Qempty [] (hideConts (Refinement.bindParams Γ δ)) (fieldFacts δ.length obs links ++ liftMany δ.length Ξ)
        none guard (.refined (.base .boolean) p) Eff.empty (localExtend δ.length L) ∧
      HasTypeCQ P B Ψ Qempty [] (Refinement.bindParams Γ δ)
        (p.open (.boolean true) :: (fieldFacts δ.length obs links ++ liftMany δ.length Ξ))
        (Rs.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (e.shiftV δ.length 0)
        (localExtend δ.length L) := by
  match h with
  | .nil _ => simp at hi
  | .plain hp hvf hfw hw _ hs =>
    cases n with
    | zero => cases Option.some.inj hi
    | succ n =>
      have hfail := hpref _ List.mem_cons_self rfl
      have hc' := hc.excluded_facts ho hv hp ht
        (FactsWF.right (by simpa only [pathFacts_append] using hw)) hfail
      exact hs.capture_guard_success hc' ho hv ht hi (prefix_tail hpref) hm
  | .guarded hp hvf hfw hw hgp hg hb hs =>
    cases n with
    | zero =>
      cases Option.some.inj hi
      exact ⟨_,_,_,_,hp,hc.matched_facts ho hv
        (FactsWF.left (by simpa only [pathFacts_append] using hw)) hm,hvf,hfw,hgp,hg,hb⟩
    | succ n => exact hs.capture_guard_success hc ho hv ht hi (prefix_tail hpref) hm
termination_by n

theorem MatchPrefix.guard_advance {v arms n alts guard body}
    (hp : MatchPrefix v arms n) (hi : arms[n]? = some (.mk alts (some guard) body)) :
    MatchPrefix v arms (n+1) := by
  induction n generalizing arms with
  | zero =>
    cases arms with
    | nil => cases hi
    | cons arm arms =>
      cases Option.some.inj hi
      intro a ha hg
      rcases List.mem_cons.mp ha with rfl | ha
      · cases hg
      · cases ha
  | succ n ih =>
    cases arms with
    | nil => cases hi
    | cons arm arms =>
      have hh := ih (prefix_tail hp) hi
      intro a ha hg
      rcases List.mem_cons.mp ha with rfl | ha
      · exact hp _ List.mem_cons_self hg
      · exact hh a ha hg

theorem adequateArms_guard {σ : PathEnv} {arms : List Arm} {n : Nat} {alts : List Alt} {guard body : Comp}
    (h : adequateArms σ arms) (hi : arms[n]? = some (.mk alts (some guard) body)) : guard.Adequate σ := by
  induction arms generalizing n with
  | nil => cases hi
  | cons arm arms ih =>
    cases arm with
    | mk alts0 g m =>
      cases n with
      | zero => cases Option.some.inj hi; exact h.1
      | succ n => cases g <;> exact ih h.2.2 hi

theorem Arm.ClosedList_guard {nt nv : Nat} {arms : List Arm} {n : Nat} {alts : List Alt} {guard body : Comp}
    (h : Arm.ClosedList nt nv arms) (hi : arms[n]? = some (.mk alts (some guard) body)) :
    guard.ClosedAt nt (nv + Arm.bindersOf alts) := by
  induction arms generalizing n with
  | nil => cases hi
  | cons arm arms ih =>
    cases arm with
    | mk alts0 g m =>
      cases n with
      | zero => cases Option.some.inj hi; exact h.1
      | succ n => cases g <;> exact ih h.2.2 hi

theorem StateTyE.err_pop_guard {P B σ Eb rs v cap arms n body k μ}
    (h : StateTyE P B σ Eb (.error rs (.guardF v cap arms n body :: k) μ)) :
    StateTyE P B σ Eb (.error rs k μ) := by
  obtain ⟨Ψ,R,a,b,e,hs,hk,hkc,hμc⟩ := h
  obtain ⟨R',ε',t,e',_,_,ht,_⟩ := hk.guard_false
  exact ⟨Ψ,R',t,b,ε',hs,ht,(fun f hf => hkc f (List.mem_cons_of_mem _ hf)),hμc⟩

theorem StateTyE.exit_pop_guard {P B σ Eb code rs v cap arms n body k μ}
    (h : StateTyE P B σ Eb (.exit code rs (.guardF v cap arms n body :: k) μ)) :
    StateTyE P B σ Eb (.exit code rs k μ) := by
  obtain ⟨Ψ,R,a,b,e,hs,hk,hkc,hμc⟩ := h
  obtain ⟨R',ε',t,e',_,_,ht,_⟩ := hk.guard_false
  exact ⟨Ψ,R',t,b,ε',hs,ht,(fun f hf => hkc f (List.mem_cons_of_mem _ hf)),hμc⟩


theorem Ty.Annotation.done_empty {P C Γ a} (ha : Ty.Annotation P C Γ a) :
    Ty.Annotation P C Γ (.dependentFn (.done a Eff.empty)) :=
  ⟨⟨ha.wf,by simp [Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Ty.WFList]⟩,
    ⟨ha.sorted,by simp [sortedEff,Eff.empty,sortedTys]⟩,⟨ha.declared,by simp [declaredEff,Eff.empty,declaredTys]⟩⟩

theorem Capture.closeEff_empty (cap : Capture) : cap.closeEff Eff.empty = Eff.empty := by
  simp [Capture.closeEff,substEffValues,Eff.bind,Eff.rawBind,Eff.empty,Eff.norm,
    valEnv,instAtoms_nil,substAtoms_nil,rowFails,Ty.normTys]

theorem StateTyE.match_guard {P B σ Eb v cap arms n alts guard body ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.matchRun v cap arms n k μ))
    (hi : arms[n]? = some (.mk alts (some guard) body)) (hm : firstAlt v alts = some ws) :
    StateTyE P B σ Eb (.run (.mk (cap.extendMany ws) guard)
      (.guardF v cap arms (n+1) (.mk (cap.extendMany ws) body) :: k) μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,⟨vs,hv,hq⟩,he,hk,hva,hca,hprefix,hvg,har,hcl,hkc,hμc⟩ := h
  obtain ⟨Γ,Φ,Rs,root,obs,arms0,input,as,es,L,ρ,hcap,ht,ho,hars,hL,hea,hroot,hR,ha,hee,hr,hx⟩ := hq.match_source
  rw [hroot] at hv
  have hi' := hi
  rw [hea] at hi'
  obtain ⟨alts0,g0,body0,hi0,harmeq⟩ := Arm.resolveLocalsList_at hi'
  obtain ⟨healts,heguard,hebody⟩ := Arm.mk.inj harmeq
  cases healts
  cases g0 with
  | none => cases heguard
  | some guard0 =>
    have hgEq := Option.some.inj heguard
    have hvt : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy input) := by
      rw [hv]
      exact close_value_typed hP hPB hB hs.wf hs.sorted hs.declared hcap ht
    obtain ⟨δ,Ξ,p,links,hpat,hcap',hlinks,hfields,hgp,hg,hb⟩ := hars.capture_guard_success hcap ho hv hvt hi0
      ((hea ▸ hprefix).unresolve) hm
    have hinput := open_value_annotation hs.wf hs.sorted hs.declared hcap.contextRegular ht
    have hδ := hpat.bindings_annotation hPB.variance hcap hinput hvt hm
    have hbound := hcap'.match_extend hPB.variance hpat hδ hvt hvg hm
    have hws := alternatives_bindings_typed hPB.variance (hpat.subst_values cap.env) hvt.V_Normal hm
    have hlen : ws.length = δ.length := by simpa only [List.length_map] using hws.length
    have hbound := hcap'.field_facts hbound ho hv hm hlen hlinks hfields
    have hlocal := CaptureLocals.extendMany hs.wf ws hL
    rw [hlen] at hlocal
    have hbEq : body = body0.resolveLocals (upLocalSubst δ.length ρ) := by
      simpa only [hpat.2.1] using hebody
    have hgEq' : guard = guard0.resolveLocals (upLocalSubst δ.length ρ) := by
      simpa only [hpat.2.1] using hgEq
    have hty : (cap.extendMany ws).closeTy (as.shiftV δ.length 0) = a := by
      rw [←hlen,Capture.closeTy_shift_many,ha]
    have hef : (cap.extendMany ws).closeEff (es.shiftV δ.length 0) = e1 := by
      rw [←hlen,Capture.closeEff_shift_many,hee]
    have hret : (cap.extendMany ws).closeR (Rs.map (Ty.shiftV δ.length 0)) = R := by
      cases Rs with
      | none => exact hR
      | some r =>
        change some ((cap.extendMany ws).closeTy (r.shiftV δ.length 0)) = _
        rw [←hlen,Capture.closeTy_shift_many]
        exact hR
    have hrd : ∀ r, Rs.map (Ty.shiftV δ.length 0) = some r → r.Declared P [] (Refinement.bindParams Γ δ) := by
      intro r hh
      obtain ⟨r0,hr0,rfl⟩ := Option.map_eq_some_iff.mp hh
      exact (ShiftMap.outer Γ δ).declared (hr r0 hr0)
    have hmap : ShiftMap 0 0 (hideConts (Refinement.bindParams Γ δ)) (Refinement.bindParams Γ δ) := by
      refine ⟨by simp [hideConts],?_⟩
      intro i a hi ho
      simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using (hideConts_lookup.mp hi).1
    have hgp0 : Ty.Annotation P [] (Refinement.bindParams Γ δ) (.refined (.base .boolean) p) := by
      simpa only [Ty.shiftV_zero] using hmap.annotation hgp
    have hGB := GuardBodyTy.mk hbound hgp0 hb hlocal hbEq
      (by rw [hty,hef]; exact hq.annotation) hret hrd
    rw [hty,hef] at hGB
    have hguardcap := hbound.hideConts_any (R' := none)
    have hguard := ClosureTy.capture_resolved_closed hguardcap hg hlocal
      (by rw [Capture.closeEff_empty]; exact (hguardcap.substOk.annotation hgp).done_empty)
      rfl (by intro r hr; cases hr)
    rw [←hgEq',Capture.closeEff_empty] at hguard
    have hclosed : body.ClosedAt 0 (cap.extendMany ws).values.length := by
      have hh := Arm.ClosedList_body hcl.2 hi
      simpa only [Capture.extendMany_values,List.length_append,List.length_map,List.length_reverse,
        hlen,hpat.2.1,Nat.add_comm] using hh
    have hgclosed : guard.ClosedAt 0 (cap.extendMany ws).values.length := by
      have hh := Arm.ClosedList_guard hcl.2 hi
      simpa only [Capture.extendMany_values,List.length_append,List.length_map,List.length_reverse,
        hlen,hpat.2.1,Nat.add_comm] using hh
    have hbal : adequateVals σ ws := by
      have hba := alternatives_bindings_adequate hva hm
      suffices hg : ∀ xs : List Val, (∀ w ∈ xs, w.Adequate σ) → adequateVals σ xs from hg ws hba
      intro xs
      induction xs with
      | nil => intro _; trivial
      | cons w xs ih => intro hxs; exact ⟨hxs w List.mem_cons_self,ih (fun w hw => hxs w (List.mem_cons_of_mem _ hw))⟩
    have hbc := hcl.1.extendMany (alternatives_bindings_ground hvg hm)
    have hba := hca.extendMany hbal
    have hframe : Frame.Adequate σ (.guardF v cap arms (n+1) (.mk (cap.extendMany ws) body)) :=
      ⟨hva,hca,har,⟨hba,adequateArms_body har hi⟩⟩
    have hcont := ContTy.K_Guard hcap ht ho hars hL hea hr hx hv hR ha hee hGB he
      (hprefix.guard_advance hi) hk hframe
    exact ⟨Ψ,none,_,b,Eff.empty,Eff.empty,hs,hguard,⟨fun _ h => h,fun _ h => h⟩,hcont,
      ⟨hba,adequateArms_guard har hi⟩,⟨hbc,hgclosed⟩,
      (by intro f hf; rcases List.mem_cons.mp hf with rfl | hf
          · exact ⟨hvg,hcl.1,hcl.2,⟨hbc,hclosed⟩⟩
          · exact hkc f hf),hμc⟩

end
end Benitoite.Release.Refinement
