import Benitoite.Release.Refinement.StateTyping
import Benitoite.Release.Refinement.ClosureTyping
import Benitoite.Release.Refinement.Context.Capture
import Benitoite.Release.Refinement.ExternalConnection
import Benitoite.Release.Refinement.ValueFacts

/-!
# 一引数の依存する契約と実行時のβ

型付きの値置換と、実行が捕捉環境に実引数を足す操作を結ぶ。
状態の代表では同じストア・継続の結果・固定した末尾の効果を使う。
-/
namespace Benitoite.Release.Refinement

variable {P : Program}
noncomputable section

theorem HasTypeCQ.open_one {P B Ψ Q C Γ Φ R body a e x v}
    (hb : HasTypeCQ P B Ψ Q C (Γ.extend x) (Φ.map Pred.lift) R body a e [])
    (hA : Builtins.SubstitutionAssumptions P B) (hΨ : Ψ.WF)
    (hx : Ty.Annotation P C Γ x) (hΓ : Ctx.WF 0 C.length Γ)
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v x) :
    HasTypeCQ P B Ψ Q C Γ Φ (R.map (substTyValues (openValue v)))
      (body.subst (openValue v) LocalRef.bound)
      (substTyValues (openValue v) a) (substEffValues (openValue v) e) [] := by
  apply hb.subst hA hΨ (SubstOk.openValue hv hx hΓ)
  · intro p hp
    obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
    rw [Pred.openValue_lift]
    exact .hyp (List.mem_append_right _ hq)
  · intro i kind hi; cases hi

theorem Capture.empty_closeTel {t : Tel} (hw : t.WF 0 0 0) (hn : t.Normal) :
    Capture.empty.closeTel t = t :=
  (Tel.bind_values_of_wf_zero hw _).trans hn

theorem Capture.instantiate_one {name : String} {x a : Ty} {e : Eff} (v : Val)
    (hw : (Tel.param name x (.done a e)).WF 0 0 0)
    (hn : (Tel.param name x (.done a e)).Normal) :
    (Capture.empty.extend v).closeTy a = substTyValues (openValue v) a ∧
    (Capture.empty.extend v).closeEff e = substEffValues (openValue v) e := by
  have h := Capture.instantiate Capture.empty (.param name x (.done a e)) [v] rfl
  rw [Capture.empty_closeTel hw hn] at h
  simp only [Tel.instantiate,Tel.bind_done,←valEnv_openValue] at h
  simpa only [Capture.extendMany,List.foldl_cons,List.foldl_nil,Tel.result,Tel.effect,
    substTyValues,substEffValues,Ty.bind,Eff.bind,Ty.norm_idem,Eff.norm_idem] using
    (show (Capture.empty.extendMany [v]).closeTy (Tel.param name x (.done a e)).result =
        (Ty.bind (valEnv (openValue v)) a).norm ∧
      (Capture.empty.extendMany [v]).closeEff (Tel.param name x (.done a e)).effect =
        (Eff.bind (valEnv (openValue v)) e).norm from
      ⟨(Prod.mk.inj (Option.some.inj h)).1.symm,(Prod.mk.inj (Option.some.inj h)).2.symm⟩)

theorem HasTypeTelArgsQ.one {P B Ψ Q C Γ Φ name x a e v}
    (ht : Ty.Annotation P C Γ (.dependentFn (.param name x (.done a e))))
    (hΓ : Ctx.WF 0 C.length Γ) (hv : HasTypeVQ P B Ψ Q C Γ Φ v x) :
    HasTypeTelArgsQ P B Ψ Q C Γ Φ [v] (.param name x (.done a e))
      (substTyValues (openValue v) a) (substEffValues (openValue v) e) := by
  have hx : Ty.Annotation P C Γ x := ⟨ht.wf.1,ht.sorted.1,ht.declared.1⟩
  have hr : Ty.Annotation P C (Γ.extend x) (.dependentFn (.done a e)) :=
    ⟨by simpa only [Ty.WF,Ctx.extend,List.length_cons,List.length_map] using ht.wf.2,
      ht.sorted.2,ht.declared.2⟩
  have h := (SubstOk.openValue (R := none) hv hx hΓ).telAnnotation hr
  rw [valEnv_openValue] at h
  exact .param hx hv (.done h)

theorem ClosureTy.dependent_one {P B Ψ name x a e body v}
    (ht : Ty.Annotation P [] [] (.dependentFn (.param name x (.done a e))))
    (hn : (Tel.param name x (.done a e)).Normal)
    (hb : HasTypeC P B Ψ [] (Ctx.extend [] x) [] (some a) body a e)
    (hv : HasTypeV P B Ψ [] [] [] v x) (hg : v.Ground) :
    ClosureTy P B Ψ [] (some (substTyValues (openValue v) a))
      ((Closure.pure body).apply [v])
      (substTyValues (openValue v) a) (substEffValues (openValue v) e) := by
  have hx : Ty.Annotation P [] [] x := ⟨ht.wf.1,ht.sorted.1,ht.declared.1⟩
  have hnX : x.norm = x := (Tel.param.inj hn).2.1
  have hc := (CaptureOk.empty P B Ψ (some (substTyValues (openValue v) a))).extend hx
    (by simpa only [Capture.closeTy,Ty.subst_values_of_wf_zero hx.wf _,hnX] using hv) hg
  have hr : Ty.Annotation P [] (Ctx.extend [] x) (.dependentFn (.done a e)) :=
    ⟨by simpa only [Ty.WF,Ctx.extend,List.length_cons,List.length_map] using ht.wf.2,
      ht.sorted.2,ht.declared.2⟩
  have he := Capture.instantiate_one v ht.wf hn
  have h := ClosureTy.capture hc hb hr (congrArg some he.1) (by
    intro r hh; cases hh; exact hr.declared.1)
  rw [he.1,he.2] at h
  exact h

/-- R が some のときも含め、先頭の mark を逆転する。 -/
theorem ContTy.mark_inv {P B σ Ψ R ε k0 a b Eb Re}
    (h : ContTy P B σ Ψ R ε k0 a b Eb Re) :
    ∀ k, k0 = .mark :: k → ∃ r R', R = some r ∧ Ty.LeQ P [] [] a r ∧ ContTy P B σ Ψ R' ε k r b Eb Re := by
  induction h with
  | K_Mark h ha => 
    intro k he; cases he
    exact ⟨_,_,rfl,.refl,h⟩
  | K_Sub _ hl ih =>
    intro k he
    obtain ⟨r,R',hR,hle,hk⟩ := ih k he
    exact ⟨r,R',hR,.trans hl hle,hk⟩
  | _ => intro k he; cases he

/-- mark の追加と、既存の mark への併合を一度だけ場合分けする。 -/
theorem markPush.eq_cons_or_merge (k : Cont) :
    markPush k = .mark :: k ∨ ∃ tail, k = .mark :: tail ∧ markPush k = k := by
  cases k with
  | nil => exact .inl rfl
  | cons f tail =>
    cases f with
    | mark => exact .inr ⟨tail,rfl,rfl⟩
    | _ => exact .inl rfl

/-- 呼出し元の R によらず、同じ結果契約で mark を追加または併合する。 -/
theorem ContTy.markPush {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (ha : Ty.Annotation P [] [] a) :
    ContTy P B σ Ψ (some a) ε (markPush k) a b Eb Re := by
  rcases Refinement.markPush.eq_cons_or_merge k with hm | ⟨tail,hk,hm⟩
  · rw [hm]; exact .K_Mark h ha
  · obtain ⟨r,R',_,hle,htail⟩ := h.mark_inv tail hk
    rw [hm,hk]
    exact .K_Mark (.K_Sub htail hle) ha

theorem Cont.Closed.markPush {k : Cont} (h : k.Closed) : (markPush k).Closed := by
  rcases Refinement.markPush.eq_cons_or_merge k with hm | ⟨_,_,hm⟩
  · rw [hm]
    intro f hf
    rcases List.mem_cons.mp hf with rfl | hf
    · trivial
    · exact h f hf
  · rw [hm]; exact h

private theorem hideMap (Γ : Ctx) : ShiftMap 0 0 Γ (Refinement.hideConts Γ) := by
  refine ⟨by simp [Refinement.hideConts], ?_⟩
  intro i a hi ho
  simpa [shiftIndex_zero, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi, ho⟩

/-- DependentClosureTy の捕捉（Γ・R=none）を、本体の hideConts Γ と任意の R へ移す。 -/
theorem CaptureOk.hideConts_any {P B Ψ R R' Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
    CaptureOk P B Ψ R' (Refinement.hideConts Γ) Φ cap := by
  have hm := hideMap Γ
  cases h with
  | mk hw hn hh hs hf hg himg he =>
    have hlen : (Refinement.hideConts Γ).length = Γ.length := by simp [Refinement.hideConts]
    refine .mk ?_ (hn.trans hlen.symm) ?_ ?_ ?_ hg ?_ ?_
    · intro i a hi
      obtain ⟨hl,_⟩ := hideConts_lookup.mp hi
      rw [hlen]; exact hw i a hl
    · intro i a hi
      exact hh i a (hideConts_lookup.mp hi).1
    · intro i a hi
      obtain ⟨hl,_⟩ := hideConts_lookup.mp hi
      have := hs i a hl
      have h1 := hm.captureSorted this.1
      have h2 := hm.captureDeclared this.2
      simpa only [Ty.shiftV_zero] using And.intro h1 h2
    · intro p hp
      have hq := hf p hp
      have hx := Pred.WellFormed.shift hm (Pred.WellFormed.mk hq.1 hq.2.1 hq.2.2)
      rw [Pred.shiftV_zero] at hx
      exact ⟨hx.wf,hx.sorted,hx.declared⟩
    · intro i a hi
      obtain ⟨hl,ho⟩ := hideConts_lookup.mp hi
      cases himg i a hl with
      | ordinary _ hv => exact .ordinary ho hv
      | hidden hno _ => exact absurd ho hno
      | contLoc h0 _ _ _ _ _ => subst h0; simp_all [Ty.Ordinary,Ordinary,Ty.core]
      | contVar h0 _ _ => subst h0; simp_all [Ty.Ordinary,Ordinary,Ty.core]
    · intro p hp
      apply he
      rcases List.mem_append.mp hp with hp | hp
      · exact List.mem_append_left _ (Ctx.mem_facts_hide.mp hp)
      · exact List.mem_append_right _ hp

theorem HasTypeCQ.store_extend {P B store Q C Γ Φ R m a e L} (hb : HasTypeCQ P B store Q C Γ Φ R m a e L) {store'}
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF) (hp : store.Extends store') :
    HasTypeCQ P B store' Q C Γ Φ R m a e L := by
  have hh := HasTypeCQ.shift_values hb (k := 0) (c := 0) hA hw hp
      ⟨rfl,by intro i a hi; simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using hi⟩
      (LocalCtx.Shift.refl _) (Ξ := _) (fun p hp => by rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [Ty.shiftV_zero,Eff.shiftV_zero,shiftIndex_zero,Comp.rename_identity,
    show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,id_eq] using hh

theorem StoreTy.hide_extends (Ψ : StoreTy) : (hideBuilders Ψ).Extends Ψ := by
  intro l t ht
  unfold hideBuilders at ht
  cases hl : Ψ l with
  | none => simp [hl] at ht
  | some x => cases x <;> simp only [hl] at ht <;> cases ht <;> rfl


/-- 評価済みの閉包（捕捉 cap・Γ/Φ を持つ）の一引数の適用を、DependentClosureTy の中身から型付ける。 -/
theorem ClosureTy.closure_one {P B Ψ Γ Φ cap n x a e code v}
    (hA : Builtins.ValueAssumptions P B) (hW : Ψ.WF)
    (hc : CaptureOk P B (hideBuilders Ψ) none Γ Φ cap)
    (hb : TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ (.param n x (.done a e)) code)
    (ha : Ty.Annotation P [] (hideConts Γ) (.dependentFn (.param n x (.done a e))))
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy x)) (hg : v.Ground) :
    ClosureTy P B Ψ [] (some ((cap.extend v).closeTy a)) (.mk (cap.extend v) code)
      ((cap.extend v).closeTy a) ((cap.extend v).closeEff e) := by
  have hc1 : CaptureOk P B (hideBuilders Ψ) (some ((cap.extend v).closeTy a)) (hideConts Γ) Φ cap :=
    hc.hideConts_any
  have hc2 := CaptureOk.store hc1 hA hW.hide (StoreTy.hide_extends Ψ).preservesNormals
  have hx : Ty.Annotation P [] (hideConts Γ) x := ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩
  have hc3 := hc2.extend hx hv hg
  have hr : Ty.Annotation P [] ((hideConts Γ).extend x) (.dependentFn (.done a e)) :=
    ⟨by simpa only [Ty.WF,Ctx.extend,List.length_cons,List.length_map] using ha.wf.2,
      ha.sorted.2,ha.declared.2⟩
  cases hb with
  | param hb =>
    cases hb with
    | done hb =>
      have hb' := hb.store_extend hA hW.hide (StoreTy.hide_extends Ψ)
      exact ClosureTy.capture hc3 hb' hr rfl (fun r h => by cases h; exact hr.declared.1)


theorem StateTyE.dependent_beta_one
    {P B σ Ψ μ R name x a e body v k b ε Eb}
    (hA : Builtins.ValueAssumptions P B)
    (ht : Ty.Annotation P [] [] (.dependentFn (.param name x (.done a e))))
    (hn : (Tel.param name x (.done a e)).Normal)
    (hb : HasTypeC P B (hideBuilders Ψ) [] (Ctx.extend [] x) [] (some a) body a e)
    (hv : HasTypeV P B Ψ [] [] [] v x) (hg : v.Ground)
    (hcv : closeVal Capture.empty v = v)
    (hs : StoreOk P B σ Ψ μ)
    (hR : ∀ r, R = some r → r.WF 0 0 0 ∧ r.Declared P [] [] ∧ r.Normal)
    (hk : ContTy P B σ Ψ R ε k (substTyValues (openValue v) a) b Eb none)
    (he : Eff.Sub (substEffValues (openValue v) e) ε)
    (hbody : body.Adequate σ) (hval : v.Adequate σ)
    (hcbody : body.ClosedAt 0 1) (hck : k.Closed) (hcμ : μ.Closed) :
    StateTyE P B σ Eb
      (.run (Closure.pure (.app (.dependentLam (.param name x (.done a e)) body) [v])) k μ) ∧
    Step P B σ
      (.run (Closure.pure (.app (.dependentLam (.param name x (.done a e)) body) [v])) k μ) none
      (.run ((Closure.pure body).apply [v]) (markPush k) μ) ∧
    StateTyE P B σ Eb (.run ((Closure.pure body).apply [v]) (markPush k) μ) := by
  let av := substTyValues (openValue v) a
  let ev := substEffValues (openValue v) e
  have hargs := HasTypeTelArgsQ.one ht (by simp [Ctx.WF]) hv
  have htav := (SubstOk.openValue (R := none) hv
    ⟨ht.wf.1,ht.sorted.1,ht.declared.1⟩ (by simp [Ctx.WF])).telAnnotation
    (show Ty.Annotation P [] (Ctx.extend [] x) (.dependentFn (.done a e)) from
      ⟨by simpa only [Ty.WF,Ctx.extend,List.length_cons,List.length_map] using ht.wf.2,
        ht.sorted.2,ht.declared.2⟩)
  have hca : Ty.Annotation P [] [] av := ⟨htav.wf.1,htav.sorted.1,htav.declared.1⟩
  have hfun : HasTypeV P B Ψ [] [] [] (.dependentLam (.param name x (.done a e)) body)
      (.dependentFn (.param name x (.done a e))) := by
    apply HasTypeVQ.V_DependentLam ht
    exact .param (.done hb)
  have hsrc := ClosureTy.pure (HasTypeCQ.C_DependentApp (R := R) (Δ := []) hfun hargs)
    htav (fun r hr => ⟨(hR r hr).1,(hR r hr).2.1⟩) (substTyValues_normal _ _)
    (fun r hr => (hR r hr).2.2)
  have hb' := hb.store_extend hA hs.wf.hide (StoreTy.hide_extends Ψ)
  have hdst := ClosureTy.dependent_one ht hn hb' hv hg
  have hstep : Step P B σ
      (.run (Closure.pure (.app (.dependentLam (.param name x (.done a e)) body) [v])) k μ) none
      (.run ((Closure.pure body).apply [v]) (markPush k) μ) := by
    apply Step.E_Lam (signature := .param name x (.done a e)) (body := Closure.pure body)
    · change Comp.app (.closure (Capture.empty.closeTel (.param name x (.done a e)))
        (Closure.pure body)) [closeVal Capture.empty v] = _
      rw [Capture.empty_closeTel ht.wf hn]
      rw [hcv]
    · rfl
    · rfl
  refine ⟨⟨Ψ,R,av,b,ε,ev,hs,hsrc,he,hk,?_,?_,hck,hcμ⟩,hstep,
    ⟨Ψ,some av,av,b,ε,ev,hs,hdst,he,hk.markPush hca,?_,?_,?_,hcμ⟩⟩
  · exact ⟨trivial,hbody,hval,trivial⟩
  · exact ⟨trivial,⟨ht.wf,hcbody⟩,hg,trivial⟩
  · exact ⟨⟨hval,trivial⟩,hbody⟩
  · exact ⟨⟨hg,trivial⟩,hcbody⟩
  · exact hck.markPush

/-- 同じ Eb の証人を使って StateTy へ戻す。 -/
theorem StateTy.dependent_beta_one
    {P B σ Ψ μ R name x a e body v k b ε Eb}
    (hA : Builtins.ValueAssumptions P B)
    (ht : Ty.Annotation P [] [] (.dependentFn (.param name x (.done a e))))
    (hn : (Tel.param name x (.done a e)).Normal)
    (hb : HasTypeC P B (hideBuilders Ψ) [] (Ctx.extend [] x) [] (some a) body a e)
    (hv : HasTypeV P B Ψ [] [] [] v x) (hg : v.Ground)
    (hcv : closeVal Capture.empty v = v)
    (hs : StoreOk P B σ Ψ μ)
    (hR : ∀ r, R = some r → r.WF 0 0 0 ∧ r.Declared P [] [] ∧ r.Normal)
    (hk : ContTy P B σ Ψ R ε k (substTyValues (openValue v) a) b Eb none)
    (he : Eff.Sub (substEffValues (openValue v) e) ε)
    (hbody : body.Adequate σ) (hval : v.Adequate σ)
    (hcbody : body.ClosedAt 0 1) (hck : k.Closed) (hcμ : μ.Closed)
    (hσ : σ.Valid) (hEb : BuiltinOnly P B Eb) :
    StateTy P B σ
      (.run (Closure.pure (.app (.dependentLam (.param name x (.done a e)) body) [v])) k μ) ∧
    Step P B σ
      (.run (Closure.pure (.app (.dependentLam (.param name x (.done a e)) body) [v])) k μ) none
      (.run ((Closure.pure body).apply [v]) (markPush k) μ) ∧
    StateTy P B σ (.run ((Closure.pure body).apply [v]) (markPush k) μ) := by
  obtain ⟨h0,hstep,h1⟩ := StateTyE.dependent_beta_one hA ht hn hb hv hg hcv hs hR hk he
    hbody hval hcbody hck hcμ
  exact ⟨⟨hσ,Eb,hEb,h0⟩,hstep,⟨hσ,Eb,hEb,h1⟩⟩

/-- return の実際の値に、計算側の拡大した結果契約を適用する。 -/
theorem HasTypeCQ.ret_value {P B Ψ Q C Γ Φ R m a e L v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (hm : m = .ret v) :
    HasTypeVQ P B Ψ Q C Γ Φ v a := by
  match h with
  | .C_Return hv => cases hm; exact hv
  | .C_Sub hb hl _ hw hs hd => exact .V_Sub (hb.ret_value hm) hl hw hs hd
  | .C_Eff hb _ => exact hb.ret_value hm
  | .C_Normal hb => exact (hb.ret_value hm).V_Normal
  | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. |
    .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. |
    .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. | .C_BuilderLet .. | .C_BuilderOp .. | .C_External .. |
    .C_IssuePathBases .. | .C_CheckAt .. => cases hm

/-- 受信検査の後の元の型付けからだけ篩の事実を取り出す。 -/
theorem Builtins.ExternalAssumptions.received_facts
    {P B Ψ f d ts vs a e out obs v t}
    (h : Builtins.ExternalAssumptions P B) (hw : P.ExternalWF)
    (hd : P.externalFunction f = some d) (ha : ExternalArgs P B Ψ d ts vs a e)
    (hr : B.externalResponse f ts vs out obs)
    (hrec : externalReceive P d ts vs out = some (.val v)) (σ : PathEnv)
    (ht : v.toTerm? = some t) :
    HasTypeV P B Ψ [] [] [] v a ∧ v.Ground ∧ v.Adequate σ ∧
      ∀ p ∈ a.assume, Entails [] (p.open t) := by
  obtain ⟨hv,hg,had⟩ := h.received_value hw hd ha hr hrec σ
  exact ⟨hv,hg,had,hv.facts ht⟩

end
end Benitoite.Release.Refinement
