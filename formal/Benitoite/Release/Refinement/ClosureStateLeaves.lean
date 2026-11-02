import Benitoite.Release.Refinement.ClosureCallInputs
import Benitoite.Release.Refinement.HandlerOperation
import Benitoite.Release.Refinement.CallBodyScope
import Benitoite.Release.Refinement.MethodClosure
import Benitoite.Release.Refinement.SuperClosure

/-! # 全引数の呼出しと状態の葉（設計書 01-12「篩を含む状態の型付け」） -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem Closure.Adequate.apply {σ : PathEnv} {q : Closure} {vs : List Val}
    (hq : q.Adequate σ) (hv : adequateVals σ vs) : (q.apply vs).Adequate σ := by
  cases q with
  | mk cap body => exact ⟨hq.1.extendMany hv,hq.2⟩

theorem Closure.ClosedAt.apply {q : Closure} {vs : List Val}
    (hq : q.ClosedAt vs.length) (hv : ∀ v ∈ vs, v.Ground) : (q.apply vs).ClosedAt 0 := by
  cases q with
  | mk cap body =>
    refine ⟨hq.1.extendMany hv,?_⟩
    simpa only [Closure.apply,Closure.capture,Closure.code,Capture.extendMany_values,
      List.length_append,List.length_map,List.length_reverse,Nat.add_zero,Nat.zero_add,Nat.add_comm] using hq.2

theorem StateTyE.dependent_beta_all {P B σ Eb q k μ runtime body vs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .app (.closure runtime body) vs)
    (hlen : vs.length = runtime.arity) :
    Step P B σ (.run q k μ) none (.run (body.apply vs) (markPush k) μ) ∧
      StateTyE P B σ Eb (.run (body.apply vs) (markPush k) μ) := by
  obtain ⟨Ψ,R,a,b,ε,e,hs,hq,he,hk,had,hclosed,hkc,hμc⟩ := h
  have hread : ∀ v ∈ q.view.readValues, v.Ground := fun v hv => hq.view_read_ground hclosed hv
  have hg : ∀ v ∈ vs, v.Ground := by
    intro v hm
    apply hread
    rw [hv]
    exact List.mem_cons_of_mem _ hm
  have hfg : (Val.closure runtime body).Ground := by
    apply hread
    rw [hv]
    exact List.mem_cons_self
  have hcode := hq.app_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  obtain ⟨t,r,g,hr,hbody,hargs,hle,hcov⟩ := hcode.closure_inputs hs.wf hs.sorted hs.declared rfl
  have hdst := hbody.apply_all hP hPB hB hs hargs hg
  obtain ⟨hdst,hsub⟩ := hdst.widen_atoms (he.covers.trans hcov)
  have hcont := (ContTy.K_Sub hk hle).markPush hargs.resultAnnotation
  have had' := Closure.view_adequate had
  rw [hv] at had'
  have hcl : body.ClosedAt vs.length := by
    simpa only [telBinders_arity,←hlen] using hfg.2
  refine ⟨.E_Lam hv hlen,⟨Ψ,some r,r,b,ε,_,hs,hdst,hsub,hcont,?_,?_,hkc.markPush,hμc⟩⟩
  · exact Closure.Adequate.apply had'.1 had'.2
  · exact Closure.ClosedAt.apply hcl hg

theorem StateTy.dependent_beta_all {P B σ q k μ runtime body vs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTy P B σ (.run q k μ))
    (hv : q.view = .app (.closure runtime body) vs)
    (hlen : vs.length = runtime.arity) :
    Step P B σ (.run q k μ) none (.run (body.apply vs) (markPush k) μ) ∧
      StateTy P B σ (.run (body.apply vs) (markPush k) μ) := by
  obtain ⟨hσ,Eb,hEb,h⟩ := h
  obtain ⟨hstep,hdst⟩ := h.dependent_beta_all hP hPB hB hv hlen
  exact ⟨hstep,hσ,Eb,hEb,hdst⟩

theorem ContTy.let_inv {P B σ Ψ R ε frames a b Eb Re}
    (h : ContTy P B σ Ψ R ε frames a b Eb Re) :
    ∀ n k, frames = .letF n :: k →
      ∃ x c e1, ClosureTy P B Ψ [x] (R.map (Ty.shiftV 1 0)) n
        (c.shiftV 1 0) (Eff.shiftV 1 0 e1) ∧ n.Adequate σ ∧
        Ty.Annotation P [] [] x ∧ Ty.LeQ P [] [] a x ∧ Eff.Sub e1 ε ∧
        ContTy P B σ Ψ R ε k c b Eb Re := by
  match h with
  | .K_Let hq had ha he hk => intro n k hh; cases hh; exact ⟨_,_,_,hq,had,ha,.refl,he,hk⟩
  | .K_Sub hk hl =>
    intro n k hh
    obtain ⟨x,c,e1,hq,had,ha,hax,he,hk⟩ := hk.let_inv n k hh
    exact ⟨x,c,e1,hq,had,ha,.trans hl hax,he,hk⟩
  | .K_Empty .. | .K_Mark .. | .K_Update .. | .K_Release .. | .K_Handle .. |
    .K_Handle_Fail .. | .K_Drop .. | .K_Guard .. => intro n k hh; cases hh
termination_by structural h

theorem StateTyE.let_step {P B σ Eb q k μ m n}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .letIn m n) :
    Step P B σ (.run q k μ) none
      (.run (.mk q.capture m) (.letF (.mk q.capture n) :: k) μ) ∧
    StateTyE P B σ Eb (.run (.mk q.capture m) (.letF (.mk q.capture n) :: k) μ) := by
  obtain ⟨Ψ,R,a,b,ε,e,hs,hq,he,hk,had,hclosed,hkc,hμc⟩ := h
  cases q with
  | mk cap code =>
    cases code
    case letIn m0 n0 =>
      cases hv
      have hback : (Closure.mk cap n).Adequate σ := ⟨had.1,had.2.2⟩
      obtain ⟨a',e',hfront,he',hcont⟩ := e_let_post hs.wf hs.sorted hs.declared hq he hk rfl hback
      refine ⟨.E_Let rfl,⟨Ψ,R,a',b,ε,e',hs,hfront,he',hcont,?_,?_,?_,hμc⟩⟩
      · exact ⟨had.1,had.2.1⟩
      · exact ⟨hclosed.1,hclosed.2.1⟩
      · intro f hf
        rcases List.mem_cons.mp hf with rfl | hf
        · exact ⟨hclosed.1,hclosed.2.2⟩
        · exact hkc f hf
    case checkAt k o sh bs p v ix =>
      cases bs <;> (simp only [Closure.view,Closure.code] at hv; injection hv)
    all_goals (simp only [Closure.view,Closure.code] at hv; injection hv)

theorem ContTy.apply_let {P B σ Ψ μ R ε k a b Eb q v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ)
    (hk : ContTy P B σ Ψ R ε (.letF q :: k) a b Eb none)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v a) (hg : v.Ground) :
    ∃ c e1, ClosureTy P B Ψ [] R (q.apply [v]) c e1 ∧ Eff.Sub e1 ε ∧
      ContTy P B σ Ψ R ε k c b Eb none ∧ q.Adequate σ := by
  obtain ⟨x,c,e1,hq,had,hx,hax,he,hkt⟩ := hk.let_inv q k rfl
  have hvx := HasTypeVQ.V_Sub hv hax hx.wf hx.sorted hx.declared
  have hdst := hq.apply_all hP hPB hB hs (.cons hvx .nil)
    (by intro w hw; cases List.mem_singleton.mp hw; exact hg)
  have hRwf := hk.return_wf rfl
  have hRshift : R.map (Ty.shiftV 1 0) = R := by
    cases hr : R with
    | none => rfl
    | some r => exact congrArg some (Ty.shiftV_of_wf_zero (hRwf r hr) 1 0)
  have hRn := hq.return_normal
  rw [hRshift] at hRn
  let ν := (Capture.empty.extendMany [v]).env
  have hRsubst : R.map (substTyValues ν) = R := by
    cases hr : R with
    | none => rfl
    | some r => exact congrArg some ((Ty.subst_values_of_wf_zero (hRwf r hr) ν).trans (hRn r hr))
  have hann := hq.annotation
  have hcwf : c.WF 0 0 0 := Ty.wf_shiftV_rev (nv := 0) (k := 1) (c := 0) (by omega)
    (by simpa only [Refinement.bindParams,List.reverse_cons,List.reverse_nil,List.nil_append,
      List.map_cons,List.map_nil,List.length_cons,List.length_nil,Nat.reduceAdd,List.length_map,
      List.length_append,List.length_nil] using hann.wf.1)
  have hewf : e1.WF 0 0 0 := Eff.wf_shiftV_rev (nv := 0) (k := 1) (c := 0) (by omega)
    (by simpa only [Refinement.bindParams,List.reverse_cons,List.reverse_nil,List.nil_append,
      List.map_cons,List.map_nil,List.length_cons,List.length_nil,Nat.reduceAdd,List.length_map,
      List.length_append,List.length_nil] using hann.wf.2.1)
  have hecan : e1.Canonical := Eff.canonical_shiftV_rev hann.wf.2.2
  change ClosureTy P B Ψ [] ((R.map (Ty.shiftV 1 0)).map (substTyValues ν)) (q.apply [v])
    (substTyValues ν (c.shiftV 1 0)) (substEffValues ν (Eff.shiftV 1 0 e1)) at hdst
  rw [hRshift,hRsubst,Ty.shiftV_of_wf_zero hcwf,Ty.subst_values_of_wf_zero hcwf,
    Eff.shiftV_of_wf_zero hewf,Eff.subst_values_of_wf_zero hewf hecan] at hdst
  exact ⟨c.norm,e1,hdst,he,.K_Sub hkt (.convert (Ty.norm_idem _)),had⟩

theorem StateTyE.return_step {P B σ Eb q k μ n v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.letF n :: k) μ)) (hview : q.view = .ret v) :
    Step P B σ (.run q (.letF n :: k) μ) none (.run (n.apply [v]) k μ) ∧
      StateTyE P B σ Eb (.run (n.apply [v]) k μ) := by
  obtain ⟨Ψ,R,a,b,ε,e,hs,hq,he,hk,had,hclosed,hkc,hμc⟩ := h
  have hv := hq.ret_view_typed hP hPB hB hs.wf hs.sorted hs.declared hview
  have hg : v.Ground := hq.view_read_ground hclosed (by rw [hview]; exact List.mem_cons_self)
  obtain ⟨c,e1,hdst,he1,hkt,hnad⟩ := hk.apply_let hP hPB hB hs hv hg
  have hva := Closure.view_adequate had
  rw [hview] at hva
  have hnc : n.ClosedAt 1 := hkc _ List.mem_cons_self
  refine ⟨.E_Return hview,⟨Ψ,R,c,b,ε,e1,hs,hdst,he1,hkt,?_,?_,?_,hμc⟩⟩
  · exact Closure.Adequate.apply hnad ⟨hva,trivial⟩
  · exact Closure.ClosedAt.apply hnc (by intro w hw; cases List.mem_singleton.mp hw; exact hg)
  · exact fun f hf => hkc f (List.mem_cons_of_mem _ hf)

theorem StateTyE.mark_step {P B σ Eb q k μ v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.mark :: k) μ)) (hview : q.view = .ret v) :
    Step P B σ (.run q (.mark :: k) μ) none (.run (Closure.pure (.ret v)) k μ) ∧
      StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) := by
  obtain ⟨Ψ,R,a,b,ε,e,hs,hq,he,hk,had,hclosed,hkc,hμc⟩ := h
  have hv := hq.ret_view_typed hP hPB hB hs.wf hs.sorted hs.declared hview
  have ha := open_value_annotation hs.wf hs.sorted hs.declared (CaptureContextRegular.empty P []) hv
  obtain ⟨r,R',hR,hle,hkt⟩ := hk.mark_inv k rfl
  obtain ⟨R'',hn,hkt⟩ := hkt.normal_return_tail rfl a ha hq.result_normal hle
  have hr := hkt.return_annotation rfl
  have hempty : Ty.Annotation P [] [] (.dependentFn (.done a Eff.empty)) :=
    ⟨⟨ha.wf,trivial,rfl⟩,⟨ha.sorted,trivial⟩,⟨ha.declared,trivial⟩⟩
  have hdst := ClosureTy.pure (HasTypeCQ.C_Return (R := R'') hv) hempty
    (fun r hr' => ⟨(hr r hr').wf,(hr r hr').declared⟩) hq.result_normal hn
  have hva := Closure.view_adequate had
  rw [hview] at hva
  have hvg : v.Ground := hq.view_read_ground hclosed (by rw [hview]; exact List.mem_cons_self)
  refine ⟨.E_Mark hview,⟨Ψ,R'',a,b,ε,Eff.empty,hs,hdst,?_,hkt,⟨trivial,hva⟩,
    ⟨trivial,hvg⟩,fun f hf => hkc f (List.mem_cons_of_mem _ hf),hμc⟩⟩
  constructor
  · intro a ha; cases ha
  · intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu

theorem StateTyE.fun_step {P B σ Eb q k μ f d ts es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .app (.fnRef f ts es) ws) (hd : P.defs f = some d)
    (hws : ws.length = d.params.length) (hts : ts.length = d.ntys) (hes : es.length = d.neffs) :
    Step P B σ (.run q k μ) none
      (.run (.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)) (markPush k) μ) ∧
    StateTyE P B σ Eb
      (.run (.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)) (markPush k) μ)
 := by
  obtain ⟨Ψ,R,a,b,ε,e,hs,hq,he,hk,had,hclosed,hkc,hμc⟩ := h
  have hread : (Val.fnRef f ts es) ∈ q.view.readValues := by rw [hv]; exact List.mem_cons_self
  obtain ⟨T,hfn⟩ := hq.view_read_typed hP hPB hB hs.wf hs.sorted hs.declared hread
  have hi := (hfn.fun_body_input rfl rfl rfl hd).1
  have hcode := hq.app_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  have hg : ∀ v ∈ ws, v.Ground := by
    intro v hm; apply hq.view_read_ground hclosed; rw [hv]; exact List.mem_cons_of_mem _ hm
  obtain ⟨r,g,hdst,hle,hcov⟩ := hcode.fun_apply_all hP hPB hB hs rfl hd hg
  have hann := hdst.annotation
  have hr : Ty.Annotation P [] [] r := ⟨hann.wf.1,hann.sorted.1,hann.declared.1⟩
  obtain ⟨hdst,hsub⟩ := hdst.widen_atoms (he.covers.trans hcov)
  have hbody := (hP.defs f d hd).2.2
  rw [←hts] at hbody
  have hbody' := Comp.SourceScoped.runtime_inst (ts := ts) (es := es) (c := 0)
    (by simpa only [Nat.zero_add] using hbody) (fun t ht => (hi.types t ht).wf)
    (fun e he => (hi.rows e he).wf.2.2.2.1) hi.ordinary σ
  have hva := Closure.view_adequate had
  rw [hv] at hva
  refine ⟨.E_Fun hv hd hws hts hes,
    ⟨Ψ,some r,r,b,ε,_,hs,hdst,hsub,(ContTy.K_Sub hk hle).markPush hr,?_,?_,hkc.markPush,hμc⟩⟩
  · exact ⟨(show Capture.Adequate σ Capture.empty from trivial).extendMany hva.2,hbody'.2⟩
  · refine ⟨(show Capture.Closed Capture.empty from trivial).extendMany hg,?_⟩
    change (d.body.substTy ts es).ClosedAt 0 ((Capture.empty.extendMany ws).values.length+0)
    rw [Capture.extendMany_values]
    simpa only [Comp.substTy,Capture.empty,Capture.values,List.length_append,List.length_map,
      List.length_reverse,List.length_nil,Nat.add_zero,←hws] using hbody'.1

theorem StateTyE.method_step {P B σ Eb q k μ i us vs name ss es ws id cd ms body}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .meth (.dict i us vs) name ss es ws)
    (hid : P.impls i = some id) (hbody : id.methods name = some body)
    (hcl : P.classes id.cls = some cd) (hm : cd.methods name = some ms)
    (hws : ws.length = ms.params.length) (hvs : vs.length = id.dictTys.length)
    (hus : us.length = id.tparams.length) (hss : ss.length = ms.tparams.length)
    (hes : es.length = ms.neffs) :
    Step P B σ (.run q k μ) none
      (.run (.mk (Capture.empty.extendMany (vs++ws)) (body.substTy (ss++us) es)) (markPush k) μ) ∧
    StateTyE P B σ Eb
      (.run (.mk (Capture.empty.extendMany (vs++ws)) (body.substTy (ss++us) es)) (markPush k) μ)
 := by
  obtain ⟨Ψ,R,a,b,ε,e,hs,hq,he,hk,had,hclosed,hkc,hμc⟩ := h
  have hcode := hq.method_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  have hvg : (Val.dict i us vs).Ground := hq.view_read_ground hclosed (by rw [hv]; exact List.mem_cons_self)
  have hgv : ∀ v ∈ vs, v.Ground := fun v hv => hvg.2.member hv
  have hgw : ∀ v ∈ ws, v.Ground := by
    intro v hm; apply hq.view_read_ground hclosed; rw [hv]; exact List.mem_cons_of_mem _ hm
  obtain ⟨id',cd',ms',body',r,g,hi',hc',hm',hb',hdst,hle,hcov⟩ :=
    hcode.method_apply_all hP hPB hB hs rfl rfl rfl rfl rfl hgv hgw
  cases Option.some.inj (hi'.symm.trans hid)
  cases Option.some.inj (hc'.symm.trans hcl)
  cases Option.some.inj (hm'.symm.trans hm)
  cases Option.some.inj (hb'.symm.trans hbody)
  obtain ⟨id0,cl0,cd0,ms0,τ,hi0,hc0,hm0,hcls0,_,_,inp,_,_⟩ := hcode.method_body_input rfl
  cases Option.some.inj (hi0.symm.trans hid)
  subst cl0
  cases Option.some.inj (hc0.symm.trans hcl)
  cases Option.some.inj (hm0.symm.trans hm)
  have hsrc := (hP.impls i id hid).2.2.2.2.2.2 cd name ms body hcl hm hbody
  have hsrc' : body.SourceScoped 0 (0+(ss++us).length) ms.neffs (id.dictTys.length+ms.params.length) := by
    simpa only [List.length_append,hss,hus,Nat.zero_add] using hsrc
  have hscope := hsrc'.runtime_inst inp.typeWF inp.rowWF inp.typeKinds.ordinary σ
  have hann := hdst.annotation
  have hr : Ty.Annotation P [] [] r := ⟨hann.wf.1,hann.sorted.1,hann.declared.1⟩
  obtain ⟨hdst,hsub⟩ := hdst.widen_atoms (he.covers.trans hcov)
  have hva := Closure.view_adequate had
  rw [hv] at hva
  have hg : ∀ v ∈ vs++ws, v.Ground := by
    intro v hv; rcases List.mem_append.mp hv with hv | hv
    · exact hgv v hv
    · exact hgw v hv
  refine ⟨.E_Meth hv hid hbody hcl hm hws hvs hus hss hes,
    ⟨Ψ,some r,r,b,ε,_,hs,hdst,hsub,(ContTy.K_Sub hk hle).markPush hr,?_,?_,hkc.markPush,hμc⟩⟩
  · have hvaw : adequateVals σ (vs++ws) := by
      have hav : adequateVals σ vs := hva.1
      have haw : adequateVals σ ws := hva.2
      have happ : ∀ (xs : List Val), adequateVals σ xs → adequateVals σ (xs++ws) := by
        intro xs
        induction xs with
        | nil => intro _; exact haw
        | cons v xs ih => intro hx; exact ⟨hx.1,ih hx.2⟩
      exact happ vs hav
    exact ⟨(show Capture.Adequate σ Capture.empty from trivial).extendMany hvaw,hscope.2⟩
  · refine ⟨(show Capture.Closed Capture.empty from trivial).extendMany hg,?_⟩
    change (body.substTy (ss++us) es).ClosedAt 0 ((Capture.empty.extendMany (vs++ws)).values.length+0)
    rw [Capture.extendMany_values]
    simpa only [Comp.substTy,Capture.empty,Capture.values,List.length_append,List.length_map,
      List.length_reverse,List.length_nil,Nat.add_zero,hvs,hws] using hscope.1

theorem StateTyE.super_step {P B σ Eb q k μ v w name ss es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .meth v name ss es ws) (hstep : v.superStep P = some w) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.meth w name ss es ws)) k μ) ∧
      StateTyE P B σ Eb (.run (Closure.pure (.meth w name ss es ws)) k μ)
 := by
  obtain ⟨Ψ,R,a,b,ε,e,hs,hq,he,hk,had,hclosed,hkc,hμc⟩ := h
  have hcode := hq.method_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  have hg : v.Ground := hq.view_read_ground hclosed (by rw [hv]; exact List.mem_cons_self)
  have hva := Closure.view_adequate had
  rw [hv] at hva
  obtain ⟨hdst,hwg,hwa,hts,hes⟩ :=
    hcode.method_super_aux hP hPB hB hs rfl rfl rfl rfl rfl hstep hg hva.1
  have hR := hk.return_annotation rfl
  have hdst' := ClosureTy.pure hdst hq.annotation
    (fun r hr => ⟨(hR r hr).wf,(hR r hr).declared⟩) hq.result_normal hq.return_normal
  have hwsc : Val.ClosedList 0 0 ws := by
    have hall : ∀ v ∈ ws, v.Ground := by
      intro v hv'; apply hq.view_read_ground hclosed; rw [hv]; exact List.mem_cons_of_mem _ hv'
    have hf : ∀ xs : List Val, (∀ v ∈ xs, v.Ground) → Val.ClosedList 0 0 xs := by
      intro xs; induction xs with
      | nil => intro _; trivial
      | cons v xs ih => intro hh; exact ⟨hh v List.mem_cons_self,ih (fun v hv => hh v (List.mem_cons_of_mem _ hv))⟩
    exact hf ws hall
  refine ⟨.E_Super hv hstep,⟨Ψ,R,a,b,ε,e,hs,hdst',he,hk,?_,?_,hkc,hμc⟩⟩
  · exact ⟨trivial,hwa,hva.2⟩
  · exact ⟨trivial,hwg,hts,hes,hwsc⟩

theorem StateTy.let_step {P B σ q k μ m n}
    (h : StateTy P B σ (.run q k μ)) (hv : q.view = .letIn m n) :
    Step P B σ (.run q k μ) none
      (.run (.mk q.capture m) (.letF (.mk q.capture n) :: k) μ) ∧
    StateTy P B σ (.run (.mk q.capture m) (.letF (.mk q.capture n) :: k) μ) := by
  obtain ⟨hσ,Eb,hEb,hs⟩ := h
  obtain ⟨hst,hdst⟩ := StateTyE.let_step hs hv
  exact ⟨hst,hσ,Eb,hEb,hdst⟩

theorem StateTy.return_step {P B σ q k μ n v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTy P B σ (.run q (.letF n :: k) μ)) (hview : q.view = .ret v) :
    Step P B σ (.run q (.letF n :: k) μ) none (.run (n.apply [v]) k μ) ∧
      StateTy P B σ (.run (n.apply [v]) k μ) := by
  obtain ⟨hσ,Eb,hEb,hs⟩ := h
  obtain ⟨hst,hdst⟩ := StateTyE.return_step hP hPB hB hs hview
  exact ⟨hst,hσ,Eb,hEb,hdst⟩

theorem StateTy.mark_step {P B σ q k μ v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTy P B σ (.run q (.mark :: k) μ)) (hview : q.view = .ret v) :
    Step P B σ (.run q (.mark :: k) μ) none (.run (Closure.pure (.ret v)) k μ) ∧
      StateTy P B σ (.run (Closure.pure (.ret v)) k μ) := by
  obtain ⟨hσ,Eb,hEb,hs⟩ := h
  obtain ⟨hst,hdst⟩ := StateTyE.mark_step hP hPB hB hs hview
  exact ⟨hst,hσ,Eb,hEb,hdst⟩

theorem StateTy.fun_step {P B σ q k μ f d ts es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTy P B σ (.run q k μ))
    (hv : q.view = .app (.fnRef f ts es) ws) (hd : P.defs f = some d)
    (hws : ws.length = d.params.length) (hts : ts.length = d.ntys) (hes : es.length = d.neffs) :
    Step P B σ (.run q k μ) none
      (.run (.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)) (markPush k) μ) ∧
    StateTy P B σ
      (.run (.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)) (markPush k) μ)
 := by
  obtain ⟨hσ,Eb,hEb,hs⟩ := h
  obtain ⟨hst,hdst⟩ := StateTyE.fun_step hP hPB hB hs hv hd hws hts hes
  exact ⟨hst,hσ,Eb,hEb,hdst⟩

theorem StateTy.method_step {P B σ q k μ i us vs name ss es ws id cd ms body}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTy P B σ (.run q k μ))
    (hv : q.view = .meth (.dict i us vs) name ss es ws)
    (hid : P.impls i = some id) (hbody : id.methods name = some body)
    (hcl : P.classes id.cls = some cd) (hm : cd.methods name = some ms)
    (hws : ws.length = ms.params.length) (hvs : vs.length = id.dictTys.length)
    (hus : us.length = id.tparams.length) (hss : ss.length = ms.tparams.length)
    (hes : es.length = ms.neffs) :
    Step P B σ (.run q k μ) none
      (.run (.mk (Capture.empty.extendMany (vs++ws)) (body.substTy (ss++us) es)) (markPush k) μ) ∧
    StateTy P B σ
      (.run (.mk (Capture.empty.extendMany (vs++ws)) (body.substTy (ss++us) es)) (markPush k) μ)
 := by
  obtain ⟨hσ,Eb,hEb,hs⟩ := h
  obtain ⟨hst,hdst⟩ := StateTyE.method_step hP hPB hB hs hv hid hbody hcl hm hws hvs hus hss hes
  exact ⟨hst,hσ,Eb,hEb,hdst⟩

theorem StateTy.super_step {P B σ q k μ v w name ss es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTy P B σ (.run q k μ))
    (hv : q.view = .meth v name ss es ws) (hstep : v.superStep P = some w) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.meth w name ss es ws)) k μ) ∧
      StateTy P B σ (.run (Closure.pure (.meth w name ss es ws)) k μ)
 := by
  obtain ⟨hσ,Eb,hEb,hs⟩ := h
  obtain ⟨hst,hdst⟩ := StateTyE.super_step hP hPB hB hs hv hstep
  exact ⟨hst,hσ,Eb,hEb,hdst⟩

end
end Benitoite.Release.Refinement
