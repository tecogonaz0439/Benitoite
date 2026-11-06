import Benitoite.Release.Refinement.DependentBeta

/-!
# 捕捉した経路条件の閉じた評価と閉包の呼出し

閉じた導出を捕捉へ追加し、評価に成功する条件はその系として扱う。
状態の代表は開始と到達の同時構成であり、開始の逆転ではない。
-/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 閉じた条件の事実は、型付き像の仮定ではなく評価の成功から得る。 -/
theorem CaptureOk.evaluated_fact {p : Pred}
    (he : p.evalClosed = some true) : Entails [] p := by
  unfold Pred.evalClosed at he
  split at he
  · rename_i h
    exact .closed h.1 h.2 (by simp [Pred.evalClosed,h,he])
  · cases he

/-- 値の型の事実などから得た閉じた導出も、評価の成功に限らず追加できる。 -/
theorem CaptureOk.addEntailed {P B Ψ R Γ Φ cap p}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : Pred.WellFormed P [] Γ p)
    (hf : Entails [] (predBind (valEnv cap.env).values p)) :
    CaptureOk P B Ψ R Γ (p :: Φ) cap := by
  cases hc with
  | mk hw hn hh hs hΦ hg hi hfact =>
    refine .mk hw hn hh hs ?_ hg hi ?_
    · intro q hq
      rcases List.mem_cons.mp hq with rfl | hq
      · exact ⟨hp.wf,hp.sorted,hp.declared⟩
      · exact hΦ q hq
    · intro q hq
      rcases List.mem_append.mp hq with hq | hq
      · exact hfact q (List.mem_append_left _ hq)
      · rcases List.mem_cons.mp hq with rfl | hq
        · exact hf
        · exact hfact q (List.mem_append_right _ hq)

theorem CaptureOk.addEvaluated {P B Ψ R Γ Φ cap p}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : Pred.WellFormed P [] Γ p)
    (he : (predBind (valEnv cap.env).values p).evalClosed = some true) :
    CaptureOk P B Ψ R Γ (p :: Φ) cap :=
  hc.addEntailed hp (CaptureOk.evaluated_fact he)

/-- 閉じた導出の有限列を捕捉の事実へ追加する。 -/
theorem CaptureOk.addEntailedFacts {P B Ψ R Γ Φ cap added}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hw : FactsWF P [] Γ added)
    (he : ∀ p ∈ added, Entails [] (predBind (valEnv cap.env).values p)) :
    CaptureOk P B Ψ R Γ (added ++ Φ) cap := by
  induction added with
  | nil => exact hc
  | cons p ps ih =>
    exact (ih (fun q hq => hw q (List.mem_cons_of_mem _ hq))
      (fun q hq => he q (List.mem_cons_of_mem _ hq))).addEntailed
        (hw p List.mem_cons_self) (he p List.mem_cons_self)

/-- 局所名で書かれた導出を、捕捉した値で閉じて仮定なしで再構成する。 -/
theorem CaptureOk.close_entails {P B Ψ R Γ Φ cap p}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : Entails (Γ.facts ++ Φ) p) :
    Entails [] (predBind (valEnv cap.env).values p) := by
  apply (hp.bind (valEnv cap.env).values).cut
  intro q hq
  obtain ⟨r,hr,rfl⟩ := List.mem_map.mp hq
  exact hc.conditions r hr

/-- 一引数の逐次具体化を、捕捉環境の実際の延長と一致させる。 -/
theorem HasTypeTelArgsQ.captured_one {P B Ψ Γ Φ cap n x a e v}
    (hc : CaptureOk P B (hideBuilders Ψ) none Γ Φ cap)
    (ha : Ty.Annotation P [] (hideConts Γ) (.dependentFn (.param n x (.done a e))))
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy x)) :
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (cap.closeTel (.param n x (.done a e)))
      ((cap.extend v).closeTy a) ((cap.extend v).closeEff e) := by
  have ht := (hc.hideConts_any (R' := none)).substOk.telAnnotation ha
  change Ty.Annotation P [] []
    (.dependentFn (.param n (cap.closeTy x)
      (.done (Ty.bind (valEnv cap.env).up a) (Eff.bind (valEnv cap.env).up e)))) at ht
  have hs := HasTypeTelArgsQ.one ht (by simp [Ctx.WF]) hv
  have hn : (cap.closeTel (.param n x (.done a e))).Normal := Tel.norm_idem _
  have hi := hs.instantiate hn
  have he := Capture.instantiate cap (.param n x (.done a e)) [v] rfl
  have hh := Option.some.inj (hi.symm.trans he)
  obtain ⟨hae,hee⟩ := Prod.mk.inj hh
  simp only [Capture.extendMany,List.foldl_cons,List.foldl_nil,Tel.result,Tel.effect] at hae hee
  rw [←hae,←hee]
  exact hs

/-- 捕捉を持つ .closure の E_Lam。開始と到達の同じ契約を同時に構成する。 -/
theorem StateTyE.captured_beta_one
    {P B σ Ψ μ R Γ Φ cap name x a e body v k b ε Eb}
    (hA : Builtins.ValueAssumptions P B)
    (hc : CaptureOk P B (hideBuilders Ψ) none Γ Φ cap)
    (hb : TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ
      (.param name x (.done a e)) body)
    (ha : Ty.Annotation P [] (hideConts Γ) (.dependentFn (.param name x (.done a e))))
    (hv : HasTypeV P B Ψ [] [] [] v (cap.closeTy x)) (hg : v.Ground)
    (hcv : closeVal Capture.empty v = v)
    (hs : StoreOk P B σ Ψ μ)
    (hR : ∀ r, R = some r → r.WF 0 0 0 ∧ r.Declared P [] [] ∧ r.Normal)
    (hk : ContTy P B σ Ψ R ε k ((cap.extend v).closeTy a) b Eb none)
    (he : Eff.Sub ((cap.extend v).closeEff e) ε)
    (hcap : cap.Adequate σ) (hbody : body.Adequate σ) (hval : v.Adequate σ)
    (hccap : cap.Closed) (hcbody : body.ClosedAt 0 (cap.values.length + 1))
    (hck : k.Closed) (hcμ : μ.Closed) :
    StateTyE P B σ Eb
      (.run (Closure.pure (.app
        (.closure (cap.closeTel (.param name x (.done a e))) (.mk cap body)) [v])) k μ) ∧
    Step P B σ
      (.run (Closure.pure (.app
        (.closure (cap.closeTel (.param name x (.done a e))) (.mk cap body)) [v])) k μ) none
      (.run (.mk (cap.extend v) body) (markPush k) μ) ∧
    StateTyE P B σ Eb (.run (.mk (cap.extend v) body) (markPush k) μ) := by
  have ht := (hc.hideConts_any (R' := none)).substOk.telAnnotation ha
  change Ty.Annotation P [] [] (.dependentFn (cap.closeTel (.param name x (.done a e)))) at ht
  have hfun : HasTypeV P B Ψ [] [] []
      (.closure (cap.closeTel (.param name x (.done a e))) (.mk cap body))
      (.dependentFn (cap.closeTel (.param name x (.done a e)))) :=
    .V_Closure ht ⟨ht.wf,ht.wf,Tel.SameInputs.refl _⟩ (.mk hc hb ha ht)
  have hargs := HasTypeTelArgsQ.captured_one hc ha hv
  have hc1 : CaptureOk P B Ψ (some ((cap.extend v).closeTy a)) (hideConts Γ) Φ cap :=
    CaptureOk.store hc.hideConts_any hA hs.wf.hide (StoreTy.hide_extends Ψ).preservesNormals
  have hx : Ty.Annotation P [] (hideConts Γ) x := ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩
  have hr : Ty.Annotation P [] ((hideConts Γ).extend x) (.dependentFn (.done a e)) :=
    ⟨by simpa only [Ty.WF,Ctx.extend,List.length_cons,List.length_map] using ha.wf.2,
      ha.sorted.2,ha.declared.2⟩
  have hclosed := (hc1.extend hx hv hg).substOk.telAnnotation hr
  change Ty.Annotation P [] []
    (.dependentFn (.done ((cap.extend v).closeTy a) ((cap.extend v).closeEff e))) at hclosed
  have hca : Ty.Annotation P [] [] ((cap.extend v).closeTy a) :=
    ⟨hclosed.wf.1,hclosed.sorted.1,hclosed.declared.1⟩
  have hsrc := ClosureTy.pure (HasTypeCQ.C_DependentApp (R := R) (Δ := []) hfun hargs)
    hclosed (fun r hr => ⟨(hR r hr).1,(hR r hr).2.1⟩) (substTyValues_normal _ _)
    (fun r hr => (hR r hr).2.2)
  have hdst := ClosureTy.closure_one hA hs.wf hc hb ha hv hg
  have hstep : Step P B σ
      (.run (Closure.pure (.app
        (.closure (cap.closeTel (.param name x (.done a e))) (.mk cap body)) [v])) k μ) none
      (.run (.mk (cap.extend v) body) (markPush k) μ) := by
    apply Step.E_Lam (signature := cap.closeTel (.param name x (.done a e))) (body := .mk cap body) (ws := [v])
    · change Comp.app _ [closeVal Capture.empty v] = _
      rw [hcv]
    · rfl
    · simp [Capture.closeTel,Tel.arity,Tel.names_bind,Tel.names]
  refine ⟨⟨Ψ,R,_,b,ε,_,hs,hsrc,he,hk,?_,?_,hck,hcμ⟩,hstep,
    ⟨Ψ,some ((cap.extend v).closeTy a),_,b,ε,_,hs,hdst,he,hk.markPush hca,?_,?_,hck.markPush,hcμ⟩⟩
  · exact ⟨trivial,⟨hcap,hbody⟩,hval,trivial⟩
  · exact ⟨trivial,⟨ht.wf,hccap,hcbody⟩,hg,trivial⟩
  · exact ⟨⟨hval,(by cases cap; exact hcap)⟩,hbody⟩
  · exact ⟨⟨hg,(by cases cap; exact hccap)⟩,hcbody⟩

theorem StateTy.captured_beta_one
    {P B σ Ψ μ R Γ Φ cap name x a e body v k b ε Eb}
    (hA : Builtins.ValueAssumptions P B)
    (hc : CaptureOk P B (hideBuilders Ψ) none Γ Φ cap)
    (hb : TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ
      (.param name x (.done a e)) body)
    (ha : Ty.Annotation P [] (hideConts Γ) (.dependentFn (.param name x (.done a e))))
    (hv : HasTypeV P B Ψ [] [] [] v (cap.closeTy x)) (hg : v.Ground)
    (hcv : closeVal Capture.empty v = v)
    (hs : StoreOk P B σ Ψ μ)
    (hR : ∀ r, R = some r → r.WF 0 0 0 ∧ r.Declared P [] [] ∧ r.Normal)
    (hk : ContTy P B σ Ψ R ε k ((cap.extend v).closeTy a) b Eb none)
    (he : Eff.Sub ((cap.extend v).closeEff e) ε)
    (hcap : cap.Adequate σ) (hbody : body.Adequate σ) (hval : v.Adequate σ)
    (hccap : cap.Closed) (hcbody : body.ClosedAt 0 (cap.values.length + 1))
    (hck : k.Closed) (hcμ : μ.Closed)
    (hσ : σ.Valid) (hEb : BuiltinOnly P B Eb) :
    StateTy P B σ
      (.run (Closure.pure (.app
        (.closure (cap.closeTel (.param name x (.done a e))) (.mk cap body)) [v])) k μ) ∧
    Step P B σ
      (.run (Closure.pure (.app
        (.closure (cap.closeTel (.param name x (.done a e))) (.mk cap body)) [v])) k μ) none
      (.run (.mk (cap.extend v) body) (markPush k) μ) ∧
    StateTy P B σ (.run (.mk (cap.extend v) body) (markPush k) μ) := by
  obtain ⟨hsrc,hstep,hdst⟩ := StateTyE.captured_beta_one hA hc hb ha hv hg hcv hs hR hk he
    hcap hbody hval hccap hcbody hck hcμ
  exact ⟨⟨hσ,Eb,hEb,hsrc⟩,hstep,⟨hσ,Eb,hEb,hdst⟩⟩

end
end Benitoite.Release.Refinement
