import Benitoite.Release.Refinement.ClosureViewTyping
import Benitoite.Release.Refinement.CapturedFacts
import Benitoite.Release.Refinement.CaptureApplicationAlgebra

/-! # 捕捉を延長する全引数の適用（設計書 01-12「篩を含む状態の型付け」） -/
namespace Benitoite.Release.Refinement
noncomputable section
set_option maxRecDepth 2048

theorem TelBodyTy.capture_all {P B Ψ₀ Ψ Γ Φ cap t code vs a e}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ₀.WF) (hp : Ψ₀.Extends Ψ)
    (hc : CaptureOk P B Ψ (some a) Γ Φ cap)
    (hb : TelBodyTy P B Ψ₀ Qempty [] Γ Φ t code)
    (ht : Ty.Annotation P [] Γ (.dependentFn t))
    (hv : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (cap.closeTel t) a e)
    (hg : ∀ v ∈ vs, v.Ground) :
    ClosureTy P B Ψ [] (some a) (.mk (cap.extendMany vs) code) a e := by
  cases t with
  | done r f =>
    cases hv
    cases hb with
    | done hb =>
      have h := ClosureTy.capture hc (hb.store_extend hA hw hp) ht rfl
        (by intro r hr; cases hr; exact ht.declared.1)
      simpa only [Capture.extendMany,List.foldl_nil,Capture.closeTy,Capture.closeEff,substTyValues,substEffValues,Ty.bind,Eff.bind] using h
  | param n x rest =>
    change HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs
      (.param n (cap.closeTy x) (Tel.bind (valEnv cap.env).up rest)) a e at hv
    cases hv with
    | param _ hv hvs =>
      cases hb with
      | param hb =>
        have hx : Ty.Annotation P [] Γ x := ⟨ht.wf.1,ht.sorted.1,ht.declared.1⟩
        have ht' : Ty.Annotation P [] (Γ.extend x) (.dependentFn rest) :=
          ⟨by simpa [Ty.WF,Ctx.extend] using ht.wf.2,ht.sorted.2,ht.declared.2⟩
        rw [Capture.openTel] at hvs
        have h := TelBodyTy.capture_all hA hw hp
          (hc.extend hx hv (hg _ List.mem_cons_self)) hb ht' hvs
          (fun v hv => hg v (List.mem_cons_of_mem _ hv))
        simpa only [Capture.extendMany,List.foldl_cons] using h
termination_by t

theorem DependentClosureTy.apply_all
    {P : Program} {B : Builtins} {σ : PathEnv} {Ψ : StoreTy} {μ : Store}
    {q : Closure} {t : Tel} {vs : List Val} {a : Ty} {e : Eff}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ) (hq : DependentClosureTy P B Ψ q t)
    (hv : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs t a e)
    (hg : ∀ v ∈ vs, v.Ground) :
    ClosureTy P B Ψ [] (some a) (q.apply vs) a e := by
  cases hq with
  | mk hc hb ha _ =>
    have hc' := hc.hideConts_any (R' := some a)
    have hc'' := hc'.store hB.values hs.wf.hide (StoreTy.hide_extends Ψ).preservesNormals
    exact TelBodyTy.capture_all hB.values hs.wf.hide (StoreTy.hide_extends Ψ) hc'' hb ha hv hg

theorem CaptureOk.mapReturn {P B Ψ R Γ Φ cap}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hn : ∀ r, R = some r → r.Normal) (ν : Nat → Val) :
    CaptureOk P B Ψ (R.map (substTyValues ν)) Γ Φ cap := by
  cases hc with
  | mk hw hl hh hs hf hg hi he =>
    refine .mk hw hl hh hs hf hg ?_ he
    intro i a hlookup
    cases hi i a hlookup with
    | ordinary ho hv => exact .ordinary ho hv
    | hidden ho hh => exact .hidden ho hh
    | contLoc he ht hw hv hl hr =>
      have hR : R.map (substTyValues ν) = R := by
        cases h : R with
        | none => rfl
        | some r =>
          exact congrArg some ((Ty.subst_values_of_wf_zero (hr r h) ν).trans (hn r h))
      rw [hR]
      exact .contLoc he ht hw hv hl hr
    | contVar _ _ hl => obtain ⟨_,_,_,hl,_⟩ := hl; cases hl

theorem CaptureLocals.apply_all {Ψ : StoreTy} {cap : Capture} {L ρ}
    (hw : Ψ.WF) (hc : cap.Closed) (vs : List Val)
    (hl : CaptureLocals Ψ (upSubst vs.length cap.env) L ρ) :
    CaptureLocals Ψ (cap.extendMany vs).env L ρ := by
  intro i kind hi
  obtain ⟨l,hr,ht⟩ := hl i kind hi
  refine ⟨l,hr,?_⟩
  cases kind with
  | string | bytes => exact ht
  | list a =>
    have ha : (cap.closeTyAt vs.length a).WF 0 0 0 := hw l _ ht
    have he := cap.closeTyAt_apply_all hc vs a
    have hn : (cap.closeTyAt vs.length a).Normal := substTyValues_normal _ _
    rw [Ty.subst_values_of_wf_zero ha,hn] at he
    change Ψ l = some (.builder (.list ((cap.extendMany vs).closeTy a)))
    rw [←he]
    exact ht

theorem ClosureTy.apply_all
    {P : Program} {B : Builtins} {σ : PathEnv} {Ψ : StoreTy} {μ : Store}
    {R : Option Ty} {q : Closure} {ss : List Ty} {a : Ty} {e : Eff}
    {vs : List Val}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ) (hq : ClosureTy P B Ψ ss R q a e)
    (hv : HasTypeVsQ P B Ψ Qempty [] [] [] vs ss)
    (hg : ∀ v ∈ vs, v.Ground) :
    let ν := (Capture.empty.extendMany vs).env
    ClosureTy P B Ψ [] (R.map (substTyValues ν)) (q.apply vs)
      (substTyValues ν a) (substEffValues ν e) := by
  have hn := hq.return_normal
  cases hq with
  | mk hc hb hl hcode hss hcs hr ha hae hrs hrd =>
    rename_i ss cap code0 code Γ Φ Rs as es L ρ
    have hlen : vs.length = ss.length := by simpa only [List.length_map] using hv.length
    let ν := (Capture.empty.extendMany vs).env
    have hcc := hc.closed
    have hc' := (hc.mapReturn hn ν).bindParams hss hv hg
    have hargtypes : HasTypeVsQ P B Ψ Qempty [] [] [] vs
        ((ss.map cap.closeTy).map Capture.empty.closeTy) := by
      have he : (ss.map cap.closeTy).map Capture.empty.closeTy = ss.map cap.closeTy := by
        rw [List.map_map]
        apply List.map_congr_left
        intro a ha
        exact (Ty.subst_values_of_wf_zero (hcs _ (List.mem_map.mpr ⟨a,ha,rfl⟩)).wf _).trans (substTyValues_normal a cap.env)
      rw [he]
      exact hv
    have hargs := (CaptureOk.empty P B Ψ (R.map (substTyValues ν))).bindParams hcs hargtypes hg
    have hta := hargs.substOk.annotation ha
    have hte := hargs.substOk.telAnnotation hae
    have heA := cap.closeTyAt_apply_all hcc vs as
    have heE := cap.closeEffAt_apply_all hcc vs es
    rw [←hlen,heA] at hta
    change Ty.Annotation P [] [] (.dependentFn (.done
      (substTyValues (Capture.empty.extendMany vs).env (cap.closeTyAt ss.length as))
      (substEffValues (Capture.empty.extendMany vs).env (cap.closeEffAt ss.length es)))) at hte
    rw [←hlen,heA,heE] at hte
    have hl' : CaptureLocals Ψ (cap.extendMany vs).env L ρ :=
      CaptureLocals.apply_all hs.wf hcc vs (by simpa only [hlen] using hl)
    have heR : (cap.extendMany vs).closeR Rs = R.map (substTyValues ν) := by
      rw [←hr]
      cases Rs with
      | none => rfl
      | some r =>
        simp only [Capture.closeR,Capture.closeRAt,Option.map_some]
        exact congrArg some (by simpa only [hlen] using (cap.closeTyAt_apply_all hcc vs r).symm)
    have hrd' : ∀ r, R.map (substTyValues ν) = some r → r.Declared P [] [] := by
      intro r hr
      obtain ⟨r0,hr0,rfl⟩ := Option.map_eq_some_iff.mp hr
      exact (hrd r0 hr0).bind_values hargs.substOk.declaration
    have hh := ClosureTy.mk (ss := []) (Rs := Rs) (a := as) (e := es) hc'
      (by simpa only [Refinement.bindParams,List.reverse_nil,List.map_nil,List.nil_append,List.length_nil,
        liftMany_eq,show Pred.shiftV 0 0 = id from funext (fun p => p.shiftV_zero 0),
        show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hb)
      (by simpa only [List.length_nil,upSubst_zero] using hl')
      hcode (by simp [TypeAnnotations]) (by simp [TypeAnnotations])
      (by simpa only [Capture.closeRAt,Capture.closeR,Capture.closeTyAt,Capture.closeTy,List.length_nil,upSubst_zero] using heR)
      (by simpa only [Capture.closeTyAt,Capture.closeTy,List.length_nil,upSubst_zero,Refinement.bindParams,
        List.reverse_nil,List.map_nil,List.nil_append,show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hta)
      (by simpa only [Capture.closeTyAt,Capture.closeEffAt,Capture.closeTy,Capture.closeEff,
        List.length_nil,upSubst_zero,Refinement.bindParams,List.reverse_nil,List.map_nil,List.nil_append,
        show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hte)
      (by simpa only [Refinement.bindParams,List.reverse_nil,List.map_nil,List.nil_append,List.length_nil,
        show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hrs)
      (by simpa only [Refinement.bindParams,List.reverse_nil,List.map_nil,List.nil_append,List.length_nil,
        show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hrd')
    change ClosureTy P B Ψ [] (R.map (substTyValues ν)) (.mk (cap.extendMany vs) code)
      (substTyValues ν (cap.closeTyAt ss.length as)) (substEffValues ν (cap.closeEffAt ss.length es))
    dsimp only [ν]
    rw [←hlen,heA,heE]
    simpa only [List.map_nil,List.length_nil,Capture.closeTyAt,Capture.closeEffAt,Capture.closeTy,Capture.closeEff,upSubst_zero,ν] using hh

end
end Benitoite.Release.Refinement
