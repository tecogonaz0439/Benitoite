import Benitoite.Release.Refinement.SafeCheckTyping
import Benitoite.Release.Refinement.ApplicationInputs
import Benitoite.Release.Refinement.SafeCheckSimulation

/-! # 安全な位置の消去による整形式と型付けの保存 -/
namespace Benitoite.Release.Refinement.SafeCheckErasure
noncomputable section
open CheckErasure RefinementCheck

mutual
  /-- 消去はソースの四名前空間の深さを保つ。 -/
  theorem Code.scoped {m n} (h : Code m n) {nr nt ne nv}
      (hs : m.SourceScoped nr nt ne nv) : n.SourceScoped nr nt ne nv := by
    cases h with
    | same _ => exact hs
    | check _ =>
      simp only [call,Comp.SourceScoped,Val.SourceScoped,scopedTypes,scopedRows,scopedValues] at hs ⊢
      change scopedTypes nr nt ne nv [_,errorType] ∧ scopedValues nr nt ne nv [_]
      exact ⟨⟨hs.1.1.2.1,⟨⟨trivial,trivial,trivial⟩,trivial⟩⟩,hs.2.1,trivial⟩
    | builder h => exact ⟨hs.1,h.scoped hs.2⟩
    | letIn h g => exact ⟨h.scoped hs.1,g.scoped hs.2⟩
    | ite h g => exact ⟨hs.1,h.scoped hs.2.1,g.scoped hs.2.2⟩
    | matchC h => exact ⟨hs.1,h.scoped hs.2⟩
    | lazyC h => exact h.scoped hs
    | use h => exact ⟨hs.1,h.scoped hs.2⟩
    | handle h g => exact ⟨h.scoped hs.1,g.scoped hs.2⟩
  theorem Arms.scoped {as bs} (h : Arms as bs) {nr nt ne nv}
      (hs : scopedArms nr nt ne nv as) : scopedArms nr nt ne nv bs := by
    cases h with
    | nil => trivial
    | plain h g => exact ⟨trivial,h.scoped hs.2.1,g.scoped hs.2.2⟩
    | guard h g k => exact ⟨h.scoped hs.1,g.scoped hs.2.1,k.scoped hs.2.2⟩
  theorem Clauses.scoped {cs ds} (h : Clauses cs ds) {nr nt ne nv}
      (hs : scopedClauses nr nt ne nv cs) : scopedClauses nr nt ne nv ds := by
    cases h with
    | nil => trivial
    | op h g => exact ⟨h.scoped hs.1,g.scoped hs.2⟩
    | fail h g => exact ⟨hs.1,h.scoped hs.2.1,g.scoped hs.2.2⟩
end

/-- 同じ署名と型の宣言を持つ消去後のプログラムも整形式である。 -/
theorem program_wellFormed {P : Program} (h : P.WellFormed) : (eraseProgram P).WellFormed := by
  have hs := erased_types P
  refine ⟨?_,?_,?_,?_,?_,h.metadata.sameTypes hs,h.external.sameTypes hs⟩
  · intro f d hd
    obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp hd
    obtain ⟨hn,hsg,hbody⟩ := h.defs f old ho
    exact ⟨hn,⟨hsg.1,hsg.2.1,hsg.2.2.1.sameTypes hs,
      ⟨hsg.2.2.2.wf,hsg.2.2.2.sorted,hsg.2.2.2.declared.sameTypes hs⟩⟩,(erase_code _).scoped hbody⟩
  · intro c cd hc
    exact ⟨(hs.dataArity _ _).mp (h.cons c cd hc).1,(h.cons c cd hc).2.sameTypes hs⟩
  · intro o od ho; exact (h.ops o od ho).sameTypes hs
  · intro c cd hc; exact (h.classes c cd hc).sameTypes hs
  · intro i id hi
    obtain ⟨h1,h2,h3,h4,h5,h6,h7⟩ := h.impls i id hi
    exact ⟨h1,h2,h3.sameTypes hs,h4.sameTypes hs,fun a ha => (h5 a ha).sameTypes hs,h6,h7⟩

/-- 基の型へ移す補題は任意の型・値文脈と事実で使える。 -/
theorem to_core_in_context {P B Ψ Q C Γ Φ v a} (ha : Ty.Annotation P C Γ a)
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v a) : HasTypeVQ P B Ψ Q C Γ Φ v a.core := by
  cases a with
  | refined a p =>
    have hb : Ty.Annotation P C Γ a := ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩
    exact to_core_in_context (a := a) hb (.V_Sub hv .forget hb.wf hb.sorted hb.declared)
  | _ => exact hv
termination_by structural a

/-- 閉じた評価の成功から、同じ任意の文脈で期待型を得る。 -/
theorem accepted_in_context {P B Ψ Q C Γ Φ v a} (ha : Ty.Annotation P C Γ a)
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v a.core) (hc : accepts v a = true) :
    HasTypeVQ P B Ψ Q C Γ Φ v a := by
  cases a with
  | refined a p =>
    have hh := hc
    simp only [accepts,Bool.and_eq_true] at hh
    have hb : Ty.Annotation P C Γ a := ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩
    have typed := accepted_in_context hb hv hh.1
    cases hsort : a.sort? with
    | none =>
      have he : p.closedTrue = true := by simpa only [hsort] using hh.2
      exact .V_Sub typed (.introduce ha.sorted.2 ((Pred.closedTrue_entails he).2.2.weaken (by simp)))
        ha.wf ha.sorted ha.declared
    | some s =>
      cases ht : v.toTerm? with
      | none => simp [hsort,ht] at hh
      | some t =>
        have he : (p.open t).closedTrue = true := by simpa only [hsort,ht] using hh.2
        exact .V_Refine typed hsort ht ha.sorted.2 ha.wf.2.1
          ((Pred.closedTrue_entails he).2.2.weaken (by simp)) ha.declared.1 ha.declared.2
  | _ => exact hv
termination_by structural a
/-- 任意の文脈で、期待型を持つ同じ値から Result.Ok を組み立てる。 -/
theorem ok_in_context {P B Ψ Q C Γ Φ u v} (hp : Declarations P)
    (hu : Ty.Annotation P C Γ u) (ku : Ty.HasKind P (TypeCtx.kinds C) u .value)
    (nu : u.norm = u) (ou : Ordinary u) (hv : HasTypeVQ P B Ψ Q C Γ Φ v u) :
    HasTypeVQ P B Ψ Q C Γ Φ (ok u v) (result u) := by
  have hr := hp.file ScopeDeclarations.result (by simp [ScopeDeclarations.file])
  have he : Ty.Annotation P C Γ errorType := ⟨trivial,trivial,⟨⟨0,hp.arity,rfl⟩,trivial⟩⟩
  have ke : Ty.HasKind P (TypeCtx.kinds C) errorType .value := ⟨TyCon.arity_data hp.arity,trivial⟩
  have oe : Ordinary errorType := by intro b t e h; cases h
  have kinds : TypeArgsKinded P C [u,errorType] [.value,.value] := by
    refine ⟨rfl,?_⟩
    rintro (_|(_|i)) t k ht hk
    · cases ht; cases hk; exact ⟨ku,fun _ => ou⟩
    · cases ht; cases hk; exact ⟨ke,fun _ => oe⟩
    · simp at ht
  have ann : Ty.Annotation P C Γ (result u) :=
    ⟨⟨hu.wf,he.wf,trivial⟩,⟨hu.sorted,he.sorted,trivial⟩,
      ⟨⟨2,hr.1,rfl⟩,hu.declared,he.declared,trivial⟩⟩
  refine .V_Con (hr.2 ("Result.Ok",⟨"Result",2,[.tvar 0]⟩)
    (by simp [ScopeDeclarations.result,StandardKeyTyping.DataDecl.entries])) rfl kinds ?_ ?_ ann
  · intro t ht; cases List.mem_singleton.mp ht; change 0 < 2; omega
  · simpa [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,nu]
      using (HasTypeVsQ.cons hv HasTypeVsQ.nil)

/-- 一束縛を開くとき、普通の型の像だけから論理の移送を得る。 -/
theorem open_transport {P B Ψ Q C Γ Φ v a}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    Transport (valEnv (openValue v)) (Γ.extend a) (Φ.map Pred.lift) Γ Φ := by
  have images : ∀ i b, (Γ.extend a)[i]? = some (some b) → b.Ordinary →
      HasTypeVQ P B Ψ Q C Γ Φ (openValue v i) (substTyValues (openValue v) b) := by
    intro i b hi ho
    cases i with
    | zero =>
      simp only [Ctx.extend,List.getElem?_cons_zero,Option.some.injEq] at hi
      cases hi
      rw [Ty.openValue_shift]
      exact hv.V_Normal
    | succ i =>
      simp only [Ctx.extend,List.getElem?_cons_succ,List.getElem?_map] at hi
      obtain ⟨x,hx,he⟩ := Option.map_eq_some_iff.mp hi
      cases x with
      | none => cases he
      | some t =>
        cases he
        rw [Ty.openValue_shift]
        exact (HasTypeVQ.V_Var hx ((Ty.ordinary_shiftV _ _ _).mp ho)).V_Normal
  refine ⟨?_,?_,(by intro i; simp [valEnv]),?_⟩
  · intro i b sort hi hb
    exact (images i b hi hb.ordinary).observation (Ty.hasSort_bind hb (valEnv (openValue v)))
  · intro i b hi ho t ht
    exact (images i b hi ho).observation_references ht
  · intro p hp
    rcases List.mem_append.mp hp with hp | hp
    · obtain ⟨i,b,q,hi,hq,rfl⟩ := Ctx.mem_facts.mp hp
      have ht := images i b hi (Ty.assume_ordinary hq)
      have he := ht.assume_optional (predBind (upValues (valEnv (openValue v)).values) q)
        (Ty.assume_bind b (valEnv (openValue v)) (by intro i; simp [valEnv,Ty.core]) q hq)
      change Entails _ (predBind (valEnv (openValue v)).values (q.openOptional (some (.var i))))
      rw [predBind_open_optional]
      exact he
    · obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
      simpa only [Pred.openValue_lift] using Entails.hyp (List.mem_append_right Γ.facts hq)

/-- primitive の値の型注釈は、周囲の文脈の形成を使わずに得られる。 -/
theorem primitive_annotation {P B Ψ Q C Γ Φ w a b ts es rs}
    (typed : HasTypeVQ P B Ψ Q C Γ Φ w a)
    (he : w = .prim b ts es rs) : Ty.Annotation P C Γ a := by
  match typed with
  | .V_Prim _ _ _ _ inst => exact inst.result
  | .V_Normal h => exact (primitive_annotation h he).norm
  | .V_Sub _ _ hw hs hd => exact ⟨hw,hs,hd⟩
  | .V_Refine h hsort _ hsp hwp _ hda hdp =>
    have ha := primitive_annotation h he
    exact ⟨⟨ha.wf,hwp,hsort.ordinary⟩,⟨ha.sorted,hsp⟩,⟨hda,hdp⟩⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. |
      .V_Closure .. | .V_Fun .. | .V_Op .. | .V_ExternalRef .. |
      .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
      .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
      .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. |
      .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases he

/-- 閉じた一引数の契約では、周囲の形成を使わず元の入力と結果の関係を得る。 -/
theorem check_contract_inputs {P B Ψ Q C Γ Φ t u v tel a e}
    (site : Site t u v)
    (ht : Ty.Annotation P C Γ t)
    (relation : TelClosure P Γ Φ (Ty.toTel ["value"] [t] (result u) Eff.empty) tel)
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ [v] tel a e) :
    HasTypeVQ P B Ψ Q C Γ Φ v t ∧ Ty.LeQ P Γ Φ (result u) a := by
  have wu : (result u).WF 0 0 0 := ⟨site.expectedWF,trivial,trivial⟩
  change TelClosure P Γ Φ (.param "value" t (.done ((result u).shiftV 1 0) (Eff.empty.shiftV 1 0))) tel at relation
  rw [Ty.shiftV_of_wf_zero wu] at relation
  obtain ⟨y,tail,rfl,hy,rest⟩ := relation.param_inputs
  cases args with
  | param ann hv args =>
    obtain ⟨z,f,rfl,le,cov⟩ := rest.done_outputs
    simp only [Tel.bind_done] at args
    cases args
    refine ⟨hv.V_Sub hy ht.wf ht.sorted ht.declared,?_⟩
    have h := le.bind (valEnv (openValue v)) (open_transport hv)
    rw [←valEnv_openValue]
    change Ty.LeQ P Γ Φ _ (substTyValues (openValue v) z)
    have closed : substTyValues (openValue v) (result u) = result u := by
      rw [Ty.subst_values_of_wf_zero wu]
      simp [result,Ty.norm,Ty.normTys,site.normalExpected,errorType]
    change Ty.LeQ P Γ Φ (substTyValues (openValue v) (result u)) (substTyValues (openValue v) z) at h
    simpa only [closed] using h

/-- primitive の適用結果の注釈は、周囲の形成を使わずに得られる。 -/
theorem primitive_call_annotation {P B Ψ Q C Γ Φ R m a e Δ b ts es rs vs}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R m a e Δ)
    (he : m = .app (.prim b ts es rs) vs) : Ty.Annotation P C Γ a := by
  match typed with
  | .C_App hf _ =>
    cases he
    have ann := primitive_annotation hf rfl
    exact ⟨ann.wf.2.2.1,ann.sorted.2.1,ann.declared.2.1⟩
  | .C_DependentApp _ args => cases he; exact args.resultAnnotation
  | .C_Normal h => exact (primitive_call_annotation h he).norm
  | .C_Sub _ _ _ hw hs hd => exact ⟨hw,hs,hd⟩
  | .C_Eff h _ => exact primitive_call_annotation h he
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
      .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. |
      .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. |
      .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases he

/-- 任意の文脈で、成功した安定な呼出しを同じ型・効果の return に替える。 -/
theorem check_typed_in_context {P B Ψ Q C Γ Φ R Δ t u v a ε}
    (hp : Declarations P) (hsig : B.sig PublicNames.checkName = some signature)
    (site : Site t u v)
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R (call t u v) a ε Δ) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.ret (ok u v)) a ε Δ := by
  have outAnn := primitive_call_annotation typed rfl
  have inputs : ∃ tel r e,
      HasTypeVQ P B Ψ Q C Γ Φ (.prim PublicNames.checkName [t,u] [] []) (.dependentFn tel) ∧
      HasTypeTelArgsQ P B Ψ Q C Γ Φ [v] tel r e ∧ Ty.LeQ P Γ Φ r a := by
    rcases typed.inv_app rfl with ⟨ns,ps,r,e,hf,args,le,_⟩ | ⟨tel,r,e,hf,args,le,_⟩
    · have ann := primitive_annotation hf rfl
      have tel := args.toTel_in_context ann
      have same := Ty.norm_toTel (r := r.norm) (e := Eff.norm e) ann.norm.wf.1
      have fann := ann.norm.toTel
      refine ⟨_,_,_,hf.V_Sub (.convert ?_) fann.wf fann.sorted fann.declared,tel,
        .trans (.convert (Ty.norm_idem _)) le⟩
      exact (Ty.norm_idem _).symm.trans same.symm
    · exact ⟨tel,r,e,hf,args,le⟩
  obtain ⟨tel,r,e,hfun,args,le⟩ := inputs
  obtain ⟨sg,orig,sglookup,_,_,_,inst,core,relation⟩ := hfun.inv_prim (rs := []) rfl
  have heq := Option.some.inj (sglookup.symm.trans hsig)
  subst sg
  cases Option.some.inj core
  have au := inst.types u (by simp)
  have annT := inst.types t (by simp)
  rw [RefinementCheck.instantiated t u site.expectedWF site.normalSource site.normalExpected] at relation
  obtain ⟨tv,step⟩ := check_contract_inputs site annT relation args
  have vt := to_core_in_context annT tv
  rw [site.core] at vt
  have vu := accepted_in_context au vt site.accepts
  have ku : Ty.HasKind P (TypeCtx.kinds C) u .value :=
    (inst.kinds.2 1 u .value rfl rfl).1
  have ou := inst.ordinary u (by simp)
  have vok := ok_in_context hp au ku site.normalExpected ou vu
  have hempty : Eff.Covers Γ Φ ε Eff.empty :=
    ⟨fun _ h => by simp [Eff.empty,Eff.mem,Eff.test,Eff.atoms] at h,
      fun _ h => by simp [Eff.empty,Eff.memFail,Eff.fails] at h⟩
  exact .C_Sub (.C_Return vok) (step.trans le) hempty outAnn.wf outAnn.sorted outAnn.declared

/-- 消去は網羅性が読むガードなしのパターン列を保つ。 -/
theorem Arms.unguarded {as bs} (h : Arms as bs) : unguardedPats as = unguardedPats bs := by
  cases h with
  | nil => rfl
  | plain _ rest => exact congrArg (_ ++ ·) rest.unguarded
  | guard _ _ rest => exact rest.unguarded

/-- 消去はハンドラが処理する効果を保つ。 -/
theorem Clauses.handled {as bs} (h : Clauses as bs) (P : Program) (B : Builtins) :
    handled P B as = handled P B bs := by
  have same : Refinement.handles as = Refinement.handles bs := funext h.handles
  simp only [Refinement.handled,same]

mutual
  /-- 値の中へ入らない計算の消去は、任意の文脈で同じ型と効果を保つ。 -/
  theorem Code.typed {P B Ψ Q C Γ Φ R m a e Δ}
      (typed : HasTypeCQ P B Ψ Q C Γ Φ R m a e Δ)
      (hp : Declarations P) (hs : B.sig PublicNames.checkName = some signature)
      {n} (code : Code m n) : HasTypeCQ P B Ψ Q C Γ Φ R n a e Δ := by
    match typed with
    | .C_BuilderLet h0 h1 body hd =>
      obtain ⟨n,rfl,hn⟩ := code.builder_inv
      exact .C_BuilderLet h0 h1 (hn.typed body hp hs) hd
    | .C_Let hm hn hd =>
      obtain ⟨m',n',rfl,hmm,hnn⟩ := code.let_inv
      exact .C_Let (hmm.typed hm hp hs) (hnn.typed hn hp hs) hd
    | .C_App hf args | .C_DependentApp hf args =>
      rcases code.app_inv with rfl | ⟨t,u,v,rfl,rfl,rfl,site⟩
      · first | exact .C_App hf args | exact .C_DependentApp hf args
      · exact check_typed_in_context hp hs site (by first | exact .C_App hf args | exact .C_DependentApp hf args)
    | .C_If hv ht hm hn =>
      obtain ⟨m',n',rfl,hmm,hnn⟩ := code.ite_inv
      exact .C_If hv ht (hmm.typed hm hp hs) (hnn.typed hn hp hs)
    | .C_Match hv ho ha hd hx =>
      obtain ⟨arms,rfl,harm⟩ := code.match_inv
      exact .C_Match hv ho (harm.typed ha hp hs) hd (by simpa only [←harm.unguarded] using hx)
    | .C_Lazy hm ha =>
      obtain ⟨m',rfl,hmm⟩ := code.lazy_inv
      exact .C_Lazy (hmm.typed hm hp hs) ha
    | .C_Use hv hr hm he =>
      obtain ⟨m',rfl,hmm⟩ := code.use_inv
      exact .C_Use hv hr (hmm.typed hm hp hs) he
    | .C_Handle hm he hc =>
      obtain ⟨m',cs,rfl,hmm,hcc⟩ := code.handle_inv
      exact .C_Handle (hmm.typed hm hp hs) (by simpa only [←hcc.handled P B] using he) (hcc.typed hc hp hs)
    | .C_Handle_Fail hm he hn hc =>
      obtain ⟨m',cs,rfl,hmm,hcc⟩ := code.handle_inv
      exact .C_Handle_Fail (hmm.typed hm hp hs) he hn (hcc.typed_failure hc hp hs)
    | .C_Normal hm => exact .C_Normal (code.typed hm hp hs)
    | .C_Sub hm hl he hw hsort hd => exact .C_Sub (code.typed hm hp hs) hl he hw hsort hd
    | .C_Eff hm he => exact .C_Eff (code.typed hm hp hs) he
    | .C_Return hv => cases code.ret_inv; exact .C_Return hv
    | .C_Escape hv ha => cases code.escape_inv; exact .C_Escape hv ha
    | .C_BuilderOp ha hk hr hv =>
      cases code.atomic_inv (by simp); exact .C_BuilderOp ha hk hr hv
    | .C_Resume hi hv hd => cases code.atomic_inv (by simp); exact .C_Resume hi hv hd
    | .C_ResumeL hi hv hd => cases code.atomic_inv (by simp); exact .C_ResumeL hi hv hd
    | .C_ResumeNorm hi hv hd => cases code.atomic_inv (by simp); exact .C_ResumeNorm hi hv hd
    | .C_ResumeLNorm hi hr hv hd => cases code.atomic_inv (by simp); exact .C_ResumeLNorm hi hr hv hd
    | .C_Meth hv hc hm hn hsat hi he hargs hvargs ha =>
      cases code.atomic_inv (by simp); exact .C_Meth hv hc hm hn hsat hi he hargs hvargs ha
    | .C_External hf hw had args =>
      cases code.atomic_inv (by simp); exact .C_External hf hw had args
    | .C_IssuePathBases b sg hs hk ho hp hr he =>
      cases code.atomic_inv (by simp); exact .C_IssuePathBases b sg hs hk ho hp hr he
    | .C_CheckAt h => cases code.atomic_inv (by simp); exact .C_CheckAt h

  /-- 腕のガードと本体は同じ束縛と事実のまま型付けられる。 -/
  theorem Arms.typed {P B Ψ Q C Γ Φ R obs as a b e Δ}
      (typed : HasTypeArmsQ P B Ψ Q C Γ Φ R obs as a b e Δ)
      (hp : Declarations P) (hs : B.sig PublicNames.checkName = some signature)
      {bs} (code : Arms as bs) : HasTypeArmsQ P B Ψ Q C Γ Φ R obs bs a b e Δ := by
    match typed with
    | .nil ha => cases code; exact .nil ha
    | .plain h0 h1 h2 h3 hm ha =>
      cases code with
      | plain hmm haa => exact .plain h0 h1 h2 h3 (hmm.typed hm hp hs) (haa.typed ha hp hs)
    | .guarded h0 h1 h2 h3 h4 hg hm ha =>
      cases code with
      | guard hgg hmm haa => exact .guarded h0 h1 h2 h3 h4 (hgg.typed hg hp hs) (hmm.typed hm hp hs) (haa.typed ha hp hs)

  /-- 操作の節の本体を、同じ操作の契約の下で消去できる。 -/
  theorem Clauses.typed {P B Ψ Q C Γ Φ R eb as t e Δ}
      (typed : HasTypeClausesQ P B Ψ Q C Γ Φ R eb as t e Δ)
      (hp : Declarations P) (hs : B.sig PublicNames.checkName = some signature)
      {bs} (code : Clauses as bs) : HasTypeClausesQ P B Ψ Q C Γ Φ R eb bs t e Δ := by
    match typed with
    | .nil => cases code; exact .nil
    | .cons h0 h1 h2 h3 h4 hm hc =>
      cases code with
      | op hmm hcc => exact .cons h0 h1 h2 h3 h4 (hmm.typed hm hp hs) (hcc.typed hc hp hs)

  /-- 失敗の節の本体を、同じ失敗の契約の下で消去できる。 -/
  theorem Clauses.typed_failure {P B Ψ Q C Γ Φ E R as t e Δ}
      (typed : HasFailureClause P B Ψ Q C Γ Φ E R as t e Δ)
      (hp : Declarations P) (hs : B.sig PublicNames.checkName = some signature)
      {bs} (code : Clauses as bs) : HasFailureClause P B Ψ Q C Γ Φ E R bs t e Δ := by
    match typed with
    | .one h0 h1 h2 hm =>
      cases code with
      | fail hmm hcc =>
        cases hcc
        exact .one h0 h1 h2 (hmm.typed hm hp hs)
end

/-- 引数を順に束縛した関数の本体にも、同じ消去を適用できる。 -/
theorem Code.telBodyTyped {P B Ψ Q C Γ Φ tel m}
    (typed : TelBodyTy P B Ψ Q C Γ Φ tel m)
    (hp : Declarations P) (hs : B.sig PublicNames.checkName = some signature)
    {n} (code : Code m n) : TelBodyTy P B Ψ Q C Γ Φ tel n := by
  match typed with
  | .done h => exact .done (code.typed h hp hs)
  | .param h => exact .param (code.telBodyTyped h hp hs)

/-- 範囲パラメータの全具体化でも、同じ本体の型付けを保つ。 -/
theorem Code.telBodyTypedR {P B Ψ Q ks C Γ Φ tel m}
    (typed : TelBodyTyR P B Ψ Q ks C Γ Φ tel m)
    (hp : Declarations P) (hs : B.sig PublicNames.checkName = some signature)
    {n} (code : Code m n) : TelBodyTyR P B Ψ Q ks C Γ Φ tel n := by
  by_cases hk : ks = []
  · subst ks
    exact code.telBodyTyped typed hp hs
  · simp only [TelBodyTyR,hk,↓reduceIte] at typed ⊢
    intro rs hr
    exact (code.instR rs).telBodyTyped (typed rs hr) hp hs

/-- 同じ署名のまま本体を消去した定義を、消去後のプログラムで型付ける。 -/
theorem definition_wellTyped {P B} {d : Def}
    (typed : d.WellTyped P B) (hp : Declarations P)
    (hs : B.sig PublicNames.checkName = some signature) :
    Def.WellTyped (eraseProgram P) B {d with body := erase d.body} := by
  obtain ⟨hn,hk,ha,hbody⟩ := typed
  refine ⟨hn,hk.sameTypes (erased_types P),
    ⟨ha.wf,ha.sorted,ha.declared.sameTypes (erased_types P)⟩,?_⟩
  have hb := (erase_code d.body).telBodyTypedR hbody hp hs
  by_cases hd : d.rkinds = []
  · simp only [TelBodyTyR,hd,↓reduceIte] at hb ⊢
    exact hb.in_erased_program
  · simp only [TelBodyTyR,hd,↓reduceIte] at hb ⊢
    intro rs hr
    exact (hb rs hr).in_erased_program

/-- メソッドの本体と辞書の値は、そのまま消去後のプログラムで型付けられる。 -/
theorem implementation_wellTyped {P B} {id : ImplDecl}
    (typed : id.WellTyped P B) : id.WellTyped (eraseProgram P) B := by
  obtain ⟨cd,hc,hm,hs,hk,ha,hbody,hsuper⟩ := typed
  refine ⟨cd,hc,hm,hs,hk.sameTypes (erased_types P),
    ha.sameTypes (erased_types P),?_,?_⟩
  · intro m ms hms
    obtain ⟨body,hlookup,hn,hb⟩ := hbody m ms hms
    exact ⟨body,hlookup,hn,hb.in_erased_program⟩
  · intro cl hcl
    obtain ⟨u,hu,ht⟩ := hsuper cl hcl
    exact ⟨u,hu,ht.in_erased_program⟩

/-- 定義の本体の消去は、外部宣言と実装を含むプログラムの型付けを保つ。 -/
theorem program_wellTyped {P B} (typed : P.WellTyped B) (hp : Declarations P)
    (hs : B.sig PublicNames.checkName = some signature) : (eraseProgram P).WellTyped B := by
  refine ⟨typed.variance.sameTypes (erased_types P),typed.external.sameTypes (erased_types P),?_,?_⟩
  · intro f d hd
    obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp hd
    exact definition_wellTyped (typed.defs f old ho) hp hs
  · intro i id hi
    exact implementation_wellTyped (typed.impls i id hi)

/-- プログラムと開始する計算を同時に消去し、元の型と効果を保つ。 -/
theorem computation_preservation {P B Ψ Q C Γ Φ R m a e Δ}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R m a e Δ)
    (hp : Declarations P) (hs : B.sig PublicNames.checkName = some signature) :
    HasTypeCQ (eraseProgram P) B Ψ Q C Γ Φ R (erase m) a e Δ :=
  ((erase_code m).typed typed hp hs).in_erased_program

/-- 安全な位置を消去した全プログラムの整形式と型付けを、同時に保存する。 -/
theorem program_preservation {P B} (hw : P.WellFormed) (typed : P.WellTyped B)
    (hp : Declarations P) (hs : B.sig PublicNames.checkName = some signature) :
    (eraseProgram P).WellFormed ∧ (eraseProgram P).WellTyped B :=
  ⟨program_wellFormed hw,program_wellTyped typed hp hs⟩

end
end Benitoite.Release.Refinement.SafeCheckErasure
