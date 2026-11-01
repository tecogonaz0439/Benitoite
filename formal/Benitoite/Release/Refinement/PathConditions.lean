import Benitoite.Release.Refinement.CapturedFacts
import Benitoite.Release.Refinement.Narrowing

/-! # 条件値の観測から分岐の閉包を型付ける -/
namespace Benitoite.Release.Refinement

variable {P : Program}
noncomputable section

theorem Ty.LeQ.weaken_conditions {Γ Φ Ξ a b} (h : Ty.LeQ P Γ Φ a b)
    (hf : ∀ p ∈ Φ, Entails (Γ.facts ++ Ξ) p) : Ty.LeQ P Γ Ξ a b := by
  have ht := Transport.id Γ Φ
  have hh := h.rawBind (renEnv id) (Δ := Γ) (Ψ := Ξ)
    ⟨ht.values,ht.references,ht.typeImages,by
      intro p hp
      simp only [renEnv_values,id_eq,predBind_id]
      rcases List.mem_append.mp hp with hp | hp
      · exact .hyp (List.mem_append_left _ hp)
      · exact hf p hp⟩
  simpa only [Ty.rawBind_id] using hh

theorem HasTypeCQ.if_legacy {P B Ψ Q C Γ Φ R v m n a e L}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v (.base .boolean))
    (hm : HasTypeCQ P B Ψ Q C Γ Φ R m a e L)
    (hn : HasTypeCQ P B Ψ Q C Γ Φ R n a e L) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.ite v m n) a e L := by
  obtain ⟨t,ht,_⟩ := hv.observation rfl
  exact .C_If hv ht
    (hm.weaken_conditions hA hw (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_cons_of_mem _ hp))))
    (hn.weaken_conditions hA hw (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_cons_of_mem _ hp))))

theorem HasTypeVQ.boolCond_wellFormed {P B Ψ Q C Γ Φ v t b}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v (.base .boolean)) (ht : v.toTerm? = some t) :
    Pred.WellFormed P C Γ (boolCond t b) := by
  obtain ⟨u,hu,hs⟩ := hv.observation rfl
  cases hu.symm.trans ht
  have hp : (boolCond t b).Sorted Γ none := ⟨trivial,hs,by trivial⟩
  exact ⟨hp.wf_none,hp,hv.observation_declared ht,trivial⟩

/-- 枝の前提の事実だけを選び、外側の型・行の拡大をそのまま再構成する。 -/
theorem HasTypeCQ.ite_branch {P B Ψ Q C Γ Φ R code a e L v m n}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hc : code = .ite v m n) (b : Bool) :
    ∃ t, HasTypeVQ P B Ψ Q C Γ Φ v (.base .boolean) ∧ v.toTerm? = some t ∧
      HasTypeCQ P B Ψ Q C Γ (boolCond t b :: Φ) R (if b then m else n) a e L := by
  match h with
  | .C_If hv ht hm hn =>
    cases hc
    exact ⟨_,hv,ht,by cases b; exact hn; exact hm⟩
  | .C_Sub hb hl he hw hs hd =>
    obtain ⟨t,hv,ht,hb⟩ := hb.ite_branch hc b
    refine ⟨t,hv,ht,.C_Sub hb ?_ ?_ hw hs hd⟩
    · exact hl.weaken_conditions (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_cons_of_mem _ hp)))
    · exact he
  | .C_Eff hb he =>
    obtain ⟨t,hv,ht,hb⟩ := hb.ite_branch hc b
    exact ⟨t,hv,ht,.C_Eff hb (he)⟩
  | .C_Normal hb =>
    obtain ⟨t,hv,ht,hb⟩ := hb.ite_branch hc b
    exact ⟨t,hv,ht,.C_Normal hb⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. |
    .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc

theorem CaptureOk.boolCond_evaluates {P B Ψ R Γ Φ cap v t b}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hv : HasTypeV P B Ψ [] Γ Φ v (.base .boolean))
    (ht : v.toTerm? = some t) (he : closeVal cap v = .const (.boolean b)) :
    (predBind (valEnv cap.env).values (boolCond t b)).evalClosed = some true := by
  have ho := hc.substOk.observation hv rfl ht LocalRef.bound
  rw [←closeVal_observation] at ho
  rw [he] at ho
  have heq : termBind (valEnv cap.env).values t = .boolean b := (Option.some.inj ho).symm
  change (Pred.compare .boolean .eq (termBind (valEnv cap.env).values t) (.boolean b)).evalClosed = some true
  rw [heq]
  cases b <;> decide

theorem ClosureTy.branch {P B Ψ R Rs Γ Φ cap t b body a e}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : Pred.WellFormed P [] Γ (boolCond t b))
    (he : (predBind (valEnv cap.env).values (boolCond t b)).evalClosed = some true)
    (hb : HasTypeC P B Ψ [] Γ (boolCond t b :: Φ) Rs body a e)
    (ha : Ty.Annotation P [] Γ (.dependentFn (.done a e)))
    (hR : cap.closeR Rs = R) (hr : ∀ r, Rs = some r → r.Declared P [] Γ) :
    ClosureTy P B Ψ [] R (.mk cap body) (cap.closeTy a) (cap.closeEff e) :=
  ClosureTy.capture (hc.addEvaluated hp he) hb ha hR hr

private def Comp.isIte : Comp → Bool
  | .ite .. => true
  | _ => false

private theorem Closure.isIte_view (q : Closure) : q.view.isIte = q.code.isIte := by
  cases q with
  | mk cap code => cases code <;> rfl

private theorem Comp.isIte_resolve (m : Comp) (ρ : Nat → LocalRef) :
    (m.resolveLocals ρ).isIte = m.isIte := by
  cases m <;> rfl

/-- 実際の閉包の見方を逆転する。閉じた条件は CaptureOk の導出にだけ使う。 -/
theorem ClosureTy.ite_selected {P B Ψ R q a e m n} (b : Bool)
    (hq : ClosureTy P B Ψ [] R q a e)
    (hv : q.view = .ite (.const (.boolean b)) m n) :
    ClosureTy P B Ψ [] R (.mk q.capture (if b then m else n)) a e := by
  generalize hps : ([] : List Ty) = ps at hq
  cases hq with
  | mk hc hb hl hcode hss hcs hR ha hae hrs hrd =>
    rename_i ss cap code0 code Γ Φ Rs as es L ρ
    have hs : ss = [] := List.map_eq_nil_iff.mp hps.symm
    subst ss
    simp only [List.length_nil,bindParams,List.reverse_nil,List.map_nil,List.nil_append,
      liftMany_eq,Ty.shiftV_zero,Capture.closeTyAt,Capture.closeEffAt,
      Capture.closeRAt,upSubst_zero,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),
      show Pred.shiftV 0 0 = id from funext (fun p => p.shiftV_zero 0),
      Option.map_id,List.map_id] at hb hl hR ha hae hrs hrd ⊢
    change HasTypeCQ P B Ψ Qempty [] Γ Φ Rs code0 as es L at hb
    subst code
    have htag : code0.isIte = true := by
      have hh := congrArg Comp.isIte hv
      rw [Closure.isIte_view,Closure.code,Comp.isIte_resolve] at hh
      exact hh
    cases code0 <;> try cases htag
    simp only [Comp.resolveLocals,Closure.view,Closure.code,Closure.capture] at hv
    rename_i v mt nt
    obtain ⟨hv,hm,hn⟩ := Comp.ite.inj hv
    obtain ⟨t,htv,ht,hbranch⟩ := hb.ite_branch rfl b
    have hobs : closeVal cap v = .const (.boolean b) := by
      rw [HasTypeVQ.resolve_id htv] at hv
      exact hv
    have hcap := hc.addEvaluated (htv.boolCond_wellFormed ht) (hc.boolCond_evaluates htv ht hobs)
    have hbody : (if b then m else n) = (if b then mt else nt).resolveLocals ρ := by
      cases b
      · exact hn.symm
      · exact hm.symm
    have hh := ClosureTy.mk (ss := []) (code0 := if b then mt else nt) (code := if b then m else n)
      (a := as) (e := es) (L := L) (ρ := ρ) (Rs := Rs) hcap (by
        simpa only [List.length_nil,bindParams,List.reverse_nil,List.map_nil,List.nil_append,
          show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),
          Option.map_id,List.map_id,liftMany_eq,
          show Pred.shiftV 0 0 = id from funext (fun p => p.shiftV_zero 0)] using hbranch)
      (by simpa only [List.length_nil,upSubst_zero] using hl) hbody hss hcs
      (by simpa only [Capture.closeRAt,Capture.closeTyAt,List.length_nil,upSubst_zero] using hR)
      (by simpa only [List.map_nil,List.length_nil,bindParams,List.reverse_nil,List.nil_append,
        Capture.closeTyAt,upSubst_zero] using ha)
      (by simpa only [List.map_nil,List.length_nil,bindParams,List.reverse_nil,List.nil_append,
        Capture.closeTyAt,Capture.closeEffAt,upSubst_zero] using hae)
      (by simpa only [List.length_nil,bindParams,List.reverse_nil,List.map_nil,List.nil_append,
        show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hrs)
      (by simpa only [List.map_nil,bindParams,List.reverse_nil,List.nil_append] using hrd)
    simpa only [List.map_nil,List.length_nil,Capture.closeTyAt,Capture.closeEffAt,upSubst_zero,Closure.capture] using hh

theorem Closure.ite_selected_adequate {σ : PathEnv} {q : Closure} {m n : Comp} (b : Bool)
    (hv : q.view = .ite (.const (.boolean b)) m n) (ha : q.Adequate σ) :
    (Closure.mk q.capture (if b then m else n)).Adequate σ := by
  cases q with
  | mk cap code =>
    have htag : code.isIte = true := (Closure.isIte_view _).symm.trans (congrArg Comp.isIte hv)
    cases code <;> try cases htag
    simp only [Closure.view,Closure.code,Closure.capture] at hv
    obtain ⟨_,rfl,rfl⟩ := Comp.ite.inj hv
    cases b
    · exact ⟨ha.1,ha.2.2.2⟩
    · exact ⟨ha.1,ha.2.2.1⟩

theorem Closure.ite_selected_closed {q : Closure} {m n : Comp} (b : Bool)
    (hv : q.view = .ite (.const (.boolean b)) m n) (ha : q.ClosedAt 0) :
    (Closure.mk q.capture (if b then m else n)).ClosedAt 0 := by
  cases q with
  | mk cap code =>
    have htag : code.isIte = true := (Closure.isIte_view _).symm.trans (congrArg Comp.isIte hv)
    cases code <;> try cases htag
    simp only [Closure.view,Closure.code,Closure.capture] at hv
    obtain ⟨_,rfl,rfl⟩ := Comp.ite.inj hv
    cases b
    · exact ⟨ha.1,ha.2.2.2⟩
    · exact ⟨ha.1,ha.2.2.1⟩

/-- 開始の状態の型付けから、実際に選ばれた枝の状態を導く。 -/
theorem StateTyE.if_selected {P B σ Eb q k μ m n} (b : Bool)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .ite (.const (.boolean b)) m n) :
    StateTyE P B σ Eb (.run (.mk q.capture (if b then m else n)) k μ) := by
  obtain ⟨Ψ,R,a,c,e,e1,hs,hq,he,hk,ha,hclosed,hkc,hμc⟩ := h
  exact ⟨Ψ,R,a,c,e,e1,hs,hq.ite_selected b hv,he,hk,
    Closure.ite_selected_adequate b hv ha,Closure.ite_selected_closed b hv hclosed,hkc,hμc⟩

theorem StateTyE.if_true {P B σ Eb q k μ m n}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .ite (.const (.boolean true)) m n) :
    StateTyE P B σ Eb (.run (.mk q.capture m) k μ) := h.if_selected true hv

theorem StateTyE.if_false {P B σ Eb q k μ m n}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .ite (.const (.boolean false)) m n) :
    StateTyE P B σ Eb (.run (.mk q.capture n) k μ) := h.if_selected false hv


theorem StateTy.if_true {P B σ q k μ m n}
    (h : StateTy P B σ (.run q k μ))
    (hv : q.view = .ite (.const (.boolean true)) m n) :
    StateTy P B σ (.run (.mk q.capture m) k μ) := by
  obtain ⟨hσ,Eb,hEb,hs⟩ := h
  exact ⟨hσ,Eb,hEb,hs.if_true hv⟩

theorem StateTy.if_false {P B σ q k μ m n}
    (h : StateTy P B σ (.run q k μ))
    (hv : q.view = .ite (.const (.boolean false)) m n) :
    StateTy P B σ (.run (.mk q.capture n) k μ) := by
  obtain ⟨hσ,Eb,hEb,hs⟩ := h
  exact ⟨hσ,Eb,hEb,hs.if_false hv⟩

end
end Benitoite.Release.Refinement
