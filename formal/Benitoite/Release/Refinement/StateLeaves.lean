import Benitoite.Release.Refinement.ClosedRename

/-! # 捕捉された任意の値からストアと実行の葉への接続 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem ground_list {vs : List Val} (h : ∀ v∈vs,v.Ground) : Val.ClosedList 0 0 vs := by
  induction vs with
  | nil => trivial
  | cons v vs ih => exact ⟨h v List.mem_cons_self,ih (fun v hv => h v (List.mem_cons_of_mem _ hv))⟩
private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e :=
  ⟨(by intro x hx; cases hx),(by intro a ha; obtain ⟨b,hb,_⟩ := ha; cases hb)⟩

/-- 行先の型付けを受けず、元の導出と捕捉から実際の app の型付けを作る。 -/
theorem StateTyE.app_view_pure {P B σ Eb q f ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app f ws) :
    StateTyE P B σ Eb (.run (Closure.pure (.app f ws)) k μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hclosed,hkc,hμ⟩ := h
  have hb := hq.app_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  have hr := hk.return_annotation rfl
  have hq' := ClosureTy.pure hb hq.annotation
    (fun r hh => ⟨(hr r hh).wf,(hr r hh).declared⟩) hq.result_normal hq.return_normal
  have hfg : f.Ground := hq.view_read_ground hclosed (by rw [hv]; exact List.mem_cons_self)
  have hwg : ∀ w∈ws,w.Ground := fun w hw => hq.view_read_ground hclosed
    (by rw [hv]; exact List.mem_cons_of_mem _ hw)
  have hva := Closure.view_adequate had
  rw [hv] at hva
  exact ⟨Ψ,R,a,b,e,e1,hs,hq',he,hk,⟨trivial,hva⟩,⟨trivial,hfg,ground_list hwg⟩,hkc,hμ⟩

theorem StateTyE.reference_new_all {P B σ Eb q b ts es rs v k μ s l}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [v])
    (hs : B.sig b = some s) (hk : s.kind = .refNew) (hl : μ l = none) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v))) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v))) :=
  ⟨.E_RefNew hv hs hk hl,(h.app_view_pure hP hPB hB hv).reference_new hB hs hk hl⟩

theorem StateTyE.reference_get_all {P B σ Eb q b ts es rs l k μ s v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l])
    (hs : B.sig b = some s) (hk : s.kind = .refGet) (hl : μ l = some (.val v)) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) :=
  ⟨.E_RefGet hv hs hk hl,(h.app_view_pure hP hPB hB hv).reference_get hB hs hk hl⟩

theorem StateTyE.reference_set_all {P B σ Eb q b ts es rs l v k μ s}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l,v])
    (hs : B.sig b = some s) (hk : s.kind = .refSet) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v))) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v))) :=
  ⟨.E_RefSet hv hs hk,(h.app_view_pure hP hPB hB hv).reference_set hB hs hk⟩

private theorem primitive_raw {P B Ψ Q C Γ Φ v b s ts T}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .prim b (Ty.normTys ts) [] [])
    (hs : B.sig b = some s) (ha : TypeAnnotations P C Γ ts)
    (hk : TypeArgsKinded P C ts (s.tparams.map TParamDecl.kind))
    (hscope : ∀ a∈ts,a.WF 0 C.length Γ.length ∧ a.Ordinary) :
    HasTypeVQ P B Ψ Q C Γ Φ (.prim b ts [] []) T := by
  match h with
  | .V_Prim hs' hr hn had hi =>
    cases hv
    cases Option.some.inj (hs'.symm.trans hs)
    have had' : PrimitiveAdmissible C Γ.length s Q ts [] :=
      { had with typeCount := by simpa only [Ty.normTys_eq_map,List.length_map] using had.typeCount
                 admits := by simpa only [Ty.normTys_eq_map,List.map_map,Function.comp_def,Ty.norm_idem] using had.admits
                 typeScope := hscope }
    have hi' : SignatureInstance P C Γ (Tel.instR [] s.tel) (s.tparams.map TParamDecl.kind) ts [] :=
      ⟨hi.source,ha,hk,hi.rows,hi.rowKinds,by
        rw [←instantiatedTel_norm_images (Tel.instR [] s.tel) ts []]
        exact hi.result⟩
    have hh := HasTypeVQ.V_Prim (P := P) (B := B) (Ψ := Ψ) (Q := Q) (C := C) (Γ := Γ) (Φ := Φ) hs hr hn had' hi'
    have heq := instantiatedTel_norm_images (Tel.instR [] s.tel) ts ([] : List Eff)
    simp only [List.map_nil] at heq
    rw [heq]
    exact hh
  | .V_Normal hh => exact (primitive_raw hh hv hs ha hk hscope).V_Normal
  | .V_Sub hh hl hw hsort hd => exact .V_Sub (primitive_raw hh hv hs ha hk hscope) hl hw hsort hd
  | .V_Refine hh hi ht hsort hw he hd hp => cases hv; cases ht
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. |
    .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
    .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
    .V_List .. => cases hv
termination_by structural h

/-- 元の生の型引数を、get/set の型付きの組み込み値に戻す。 -/
private theorem raw_reference_heads {P B Ψ b s ts es rs T}
    (hB : B.CoreAssumptions P) (hv : HasTypeV P B Ψ [] [] [] (.prim b ts es rs) T)
    (hs : B.sig b = some s) (hkind : s.kind = .refUpdate) {a : Ty}
    (hts : Ty.normTys ts = [a]) (ha : Ty.Annotation P [] [] a) (hn : a.Normal)
    (ho : a.Ordinary) (hk : a.HasKind P [] .value) :
    HasTypeV P B Ψ [] [] [] (.prim B.refGet ts [] [])
      (.fn ["reference"] [.reference a] a (Eff.single stateEff)) ∧
    HasTypeV P B Ψ [] [] [] (.prim B.refSet ts [] [])
      (.fn ["reference","value"] [.reference a,a] (.base .unit) (Eff.single stateEff)) := by
  obtain ⟨hr,had,hi⟩ := hv.primitive_inputs hs
  have sh := hB.store_shape b s hs (by rw [hkind]; decide)
  simp only [PrimSig.StoreShape,hkind] at sh
  have hks := sh.2.2.2.2.2.2.2
  obtain ⟨_,hts',hg,hset⟩ := hB.reference_primitives hts ha hn ho hk
  cases (List.cons.inj (hts'.symm.trans hts)).1
  obtain ⟨sg,hsg,hkg⟩ := hB.ref_get
  obtain ⟨ss,hss,hks'⟩ := hB.ref_set
  have hgks := hB.store_shape B.refGet sg hsg (by rw [hkg]; decide)
  have hsks := hB.store_shape B.refSet ss hss (by rw [hks']; decide)
  simp only [PrimSig.StoreShape,hkg] at hgks
  simp only [PrimSig.StoreShape,hks'] at hsks
  have gk : TypeArgsKinded P [] ts (sg.tparams.map TParamDecl.kind) := by
    rw [hgks.2.2.2.2.2.2.2,←hks]; exact hi.kinds
  have sk : TypeArgsKinded P [] ts (ss.tparams.map TParamDecl.kind) := by
    rw [hsks.2.2.2.2.2.2.2,←hks]; exact hi.kinds
  exact ⟨primitive_raw (hg.weaken_empty (store := Ψ) hB.values) rfl hsg hi.types gk had.typeScope,
    primitive_raw (hset.weaken_empty (store := Ψ) hB.values) rfl hss hi.types sk had.typeScope⟩

theorem StateTyE.reference_update_all {P B σ Eb q b ts es rs l f k μ s}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l,f])
    (hsig : B.sig b = some s) (hkind : s.kind = .refUpdate) :
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.letIn (.app (.prim B.refGet ts [] []) [.loc l])
        (.letIn (.app (f.rename (·+1)) [.var 0]) (.app (.prim B.refSet ts [] []) [.loc l,.var 0])))) k μ) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.letIn (.app (.prim B.refGet ts [] []) [.loc l])
        (.letIn (.app (f.rename (·+1)) [.var 0]) (.app (.prim B.refSet ts [] []) [.loc l,.var 0])))) k μ) := by
  refine ⟨.E_RefUpdate hv hsig hkind,?_⟩
  obtain ⟨Ψ,R,a,c,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  have hcall := hq.app_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  have hg : ∀ w∈[Val.loc l,f],w.Ground := fun w hw => hq.view_read_ground hcl
    (by rw [hv]; exact List.mem_cons_of_mem _ hw)
  obtain ⟨r,ef,hargs,hle,hcov⟩ := hcall.primitive_call hg rfl hsig
  have hshape := hB.store_shape b s hsig (by rw [hkind]; decide)
  obtain ⟨x,hts,hx,hn,ho,hl,hf,hr,hef⟩ := hargs.reference_update hshape hkind
  subst r ef
  have hshape' := hshape
  simp only [PrimSig.StoreShape,hkind] at hshape'
  have hxkind := (hargs.signature.kinds.2 0 x .value (by rw [hts]; rfl)
    (by rw [hshape'.2.2.2.2.2.2.2]; rfl)).1
  obtain ⟨T,hprim⟩ := hcall.read_values _ List.mem_cons_self
  obtain ⟨hget,hset⟩ := raw_reference_heads hB hprim hsig hkind hts hx hn ho hxkind
  obtain ⟨_,_,rawsig⟩ := hprim.primitive_inputs hsig
  have htsw : ∀ t∈ts,t.WF 0 0 0 := fun t ht => (rawsig.types t ht).wf
  have hunit : Ty.Annotation P [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  obtain ⟨R',hRn,hk'⟩ := hk.normal_return_tail rfl (.base .unit) hunit rfl hle
  have hret := hk'.return_annotation rfl
  have hann := hq.annotation
  have hbody := HasTypeCQ.C_Eff (reference_update_body (R := R') hB.values hs.wf hx ho hl hf hget hset htsw) hcov
  have hq' := ClosureTy.pure hbody
    (Ty.Annotation.mk ⟨trivial,hann.wf.2⟩ ⟨trivial,hann.sorted.2⟩ ⟨trivial,hann.declared.2⟩)
    (fun r hr => ⟨(hret r hr).wf,(hret r hr).declared⟩) rfl hRn
  have hfg := hg f (by simp)
  have hrename : f.rename (·+1) = f := (hfg.rename_closed_scope (nv' := 0) (Nat.le_refl 0) (by intro i hi; omega)).1
  have hfAt (n : Nat) : f.ClosedAt 0 n := (hfg.rename_closed_scope (ξ := id) (Nat.zero_le n) (by intro i hi; omega)).2
  have htsAt (n : Nat) : ∀ t∈ts,t.WF 0 0 n := fun t ht => (htsw t ht).weaken (Nat.le_refl 0) (Nat.zero_le n)
  have hva := Closure.view_adequate had
  rw [hv] at hva
  refine ⟨Ψ,R',.base .unit,c,e,e1,hs,hq',he,hk',?_,?_,hkc,hμ⟩
  · simpa [Closure.pure,Closure.Adequate,Comp.Adequate,Val.Adequate,adequateVals,hrename] using (show Capture.empty.Adequate σ ∧ f.Adequate σ from ⟨trivial,hva.2.2.1⟩)
  · change Capture.empty.Closed ∧ _
    constructor
    · trivial
    · simpa [Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,hrename,Capture.empty,Capture.values,
        List.length_nil,Nat.zero_add,List.not_mem_nil,forall_const,not_false_eq_true,and_true,true_and] using
        (show (∀ t∈ts,t.WF 0 0 0) ∧ f.ClosedAt 0 1 ∧ (∀ t∈ts,t.WF 0 0 2) from ⟨htsw,hfAt 1,htsAt 2⟩)

theorem StateTyE.force_done_all {P B σ Eb q b ts es rs l k μ s v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l])
    (hs : B.sig b = some s) (hk : s.kind = .force) (hl : μ l = some (.done v)) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) :=
  ⟨.E_ForceDone hv hs hk hl,((h.app_view_pure hP hPB hB hv).force_done_transition hB hs hk hl).2⟩

theorem StateTyE.force_thunk_all {P B σ Eb q b ts es rs l k μ s m}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l])
    (hs : B.sig b = some s) (hk : s.kind = .force) (hl : μ l = some (.thunk m)) :
    Step P B σ (.run q k μ) none (.run m (.update l::k) μ) ∧
    StateTyE P B σ Eb (.run m (.update l::k) μ) :=
  ⟨.E_Force hv hs hk hl,((h.app_view_pure hP hPB hB hv).force_thunk_transition hB hs hk hl).2⟩

theorem StateTyE.lazy_update_all {P B σ Eb q v l k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.update l::k) μ)) (hv : q.view = .ret v) :
    Step P B σ (.run q (.update l::k) μ) none (.run (Closure.pure (.ret v)) k (μ.set l (.done v))) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k (μ.set l (.done v))) := by
  refine ⟨.E_Update hv,?_⟩
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  obtain ⟨rfl,x,R0,hl,hle,hx,hk'⟩ := hk.update_inv
  have hval := hq.ret_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  have ha : Ty.Annotation P [] [] a := ⟨hq.annotation.wf.1,hq.annotation.sorted.1,hq.annotation.declared.1⟩
  have hg := hq.view_read_ground hcl (by rw [hv]; exact List.mem_cons_self)
  have hva := Closure.view_adequate had
  rw [hv] at hva
  have htyped : HasTypeV P B Ψ [] [] [] v x := .V_Sub hval hle hx.wf hx.sorted hx.declared
  have hs' := hs.write_done hl htyped hva
  obtain ⟨R',hRn,hk''⟩ := hk'.normal_return_tail rfl a ha hq.result_normal hle
  have hret := hk''.return_annotation rfl
  have hq' := ClosureTy.pure (.C_Return (R := R') hval) ha.done_empty
    (fun r hr => ⟨(hret r hr).wf,(hret r hr).declared⟩) hq.result_normal hRn
  exact ⟨Ψ,R',a,b,e,Eff.empty,hs',hq',empty_sub e,hk'',⟨trivial,hva⟩,⟨trivial,hg⟩,
    (fun f hf => hkc f (List.mem_cons_of_mem _ hf)),hμ.set_cell hg⟩

end
end Benitoite.Release.Refinement
