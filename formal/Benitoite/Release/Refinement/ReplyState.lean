import Benitoite.Release.Refinement.StateLeaves

/-! # 応答の契約から同じストアと継続へ戻す葉 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e :=
  ⟨(by intro x hx; cases hx),(by intro a ha; obtain ⟨b,hb,_⟩ := ha; cases hb)⟩

private theorem adequate_member {σ vs} (h : adequateVals σ vs) :
    ∀ v∈vs,v.Adequate σ := by
  induction vs with
  | nil => intro v hv; cases hv
  | cons v vs ih =>
    intro w hw
    rcases List.mem_cons.mp hw with rfl | hw
    · exact h.1
    · exact ih h.2 w hw

theorem reply_value_state {P B σ Eb Ψ R a b e k μ r v}
    (hs : StoreOk P B σ Ψ μ)
    (hk : ContTy P B σ Ψ R e k a b Eb none)
    (hr : Ty.Annotation P [] [] r) (hn : r.Normal) (hle : Ty.LeQ P [] [] r a)
    (hv : HasTypeV P B Ψ [] [] [] v r) (hg : v.Ground) (ha : v.Adequate σ)
    (hkc : k.Closed) (hμ : μ.Closed) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) := by
  obtain ⟨R',hRn,hk'⟩ := hk.normal_return_tail rfl r hr hn hle
  have hret := hk'.return_annotation rfl
  have hq' := ClosureTy.pure (.C_Return (R := R') hv) hr.done_empty
    (fun t ht => ⟨(hret t ht).wf,(hret t ht).declared⟩) hn hRn
  exact ⟨Ψ,R',r,b,e,Eff.empty,hs,hq',empty_sub e,hk',⟨trivial,ha⟩,⟨trivial,hg⟩,hkc,hμ⟩

theorem StateTyE.error_from_run {P B σ Eb q k μ rs}
    (h : StateTyE P B σ Eb (.run q k μ)) : StateTyE P B σ Eb (.error rs k μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,_,_,hk,_,_,hkc,hμ⟩ := h
  exact ⟨Ψ,R,a,b,e,hs,hk,hkc,hμ⟩

theorem StateTyE.exit_from_run {P B σ Eb q k μ n rs}
    (h : StateTyE P B σ Eb (.run q k μ)) : StateTyE P B σ Eb (.exit n rs k μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,_,_,hk,_,_,hkc,hμ⟩ := h
  exact ⟨Ψ,R,a,b,e,hs,hk,hkc,hμ⟩

theorem ClosureTy.primitive_view_inputs {P B Ψ R q a e b ts es rs ws s}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hc : q.ClosedAt 0)
    (hv : q.view = .app (.prim b ts es rs) ws) (hb : B.sig b = some s) :
    ∃ r ef, BuiltinArgs P B Ψ b s (Ty.normTys ts) (es.map Eff.norm) rs ws r ef ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e ef := by
  have ht := hq.app_view_typed hP hPB hB hw hs hd hv
  exact ht.primitive_call (fun w hh => hq.view_read_ground hc
    (by rw [hv]; exact List.mem_cons_of_mem _ hh)) rfl hb

theorem StateTyE.primitive_value_all {P B σ Eb q b ts es rs ws k μ s v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .pure)
    (hδ : B.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws = some (.val v)) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) := by
  refine ⟨.E_Prim hv hsig hkind hδ,?_⟩
  obtain ⟨Ψ,R,a,c,e,e1,hs,hq,_,hk,had,hcl,hkc,hμ⟩ := h
  obtain ⟨r,ef,hargs,hle,_⟩ := hq.primitive_view_inputs hP hPB hB hs.wf hs.sorted hs.declared hcl hv hsig
  obtain ⟨out,heq,_,ht,ha⟩ := hB.responses.delta_typed _ _ _ _ _ _ _ _ _ hsig hkind hargs
  rw [hδ] at heq
  cases heq
  have had' := Closure.view_adequate had
  rw [hv] at had'
  have hadv := ha σ hσ (fun w hw => adequate_member had'.2 w hw)
  exact reply_value_state hs hk hargs.arguments.resultAnnotation hargs.result.2 hle ht.1 ht.2 hadv hkc hμ

theorem StateTyE.primitive_error_all {P B σ Eb q b ts es rs ws k μ s r}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .pure)
    (hδ : B.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws = some (.err r)) :
    Step P B σ (.run q k μ) none (.error [r] k μ) ∧ StateTyE P B σ Eb (.error [r] k μ) :=
  ⟨.E_Err hv hsig hkind hδ,h.error_from_run⟩

theorem StateTyE.io_value_all {P B σ Eb q b ts es rs ws k μ s v obs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .io) (hnh : NoHandler k (.prim b))
    (hio : B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.val v) obs) :
    Step P B σ (.run q k μ) (some (.io b ws (.val v) obs)) (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) := by
  refine ⟨.E_IO hv hsig hkind hnh hio,?_⟩
  obtain ⟨Ψ,R,a,c,e,e1,hs,hq,_,hk,had,hcl,hkc,hμ⟩ := h
  obtain ⟨r,ef,hargs,hle,_⟩ := hq.primitive_view_inputs hP hPB hB hs.wf hs.sorted hs.declared hcl hv hsig
  obtain ⟨ht,ha⟩ := hB.responses.io_typed _ _ _ _ _ _ _ _ _ _ _ hsig (Or.inl hkind) hargs hio
  have had' := Closure.view_adequate had
  rw [hv] at had'
  have hadv := ha σ hσ (fun w hw => adequate_member had'.2 w hw)
  exact reply_value_state hs hk hargs.arguments.resultAnnotation hargs.result.2 hle ht.1 ht.2 hadv hkc hμ

theorem StateTyE.io_error_all {P B σ Eb q b ts es rs ws k μ s r obs}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .io ∨ s.kind = .exit) (hnh : NoHandler k (.prim b))
    (hio : B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.err r) obs) :
    Step P B σ (.run q k μ) (some (.io b ws (.err r) obs)) (.error [r] k μ) ∧
    StateTyE P B σ Eb (.error [r] k μ) :=
  ⟨.E_IOErr hv hsig hkind hnh hio,h.error_from_run⟩

theorem StateTyE.io_exit_all {P B σ Eb q b ts es rs ws k μ s n obs}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .exit) (hnh : NoHandler k (.prim b))
    (hio : B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.exit n) obs) :
    Step P B σ (.run q k μ) (some (.io b ws (.exit n) obs)) (.exit n [] k μ) ∧
    StateTyE P B σ Eb (.exit n [] k μ) :=
  ⟨.E_Exit hv hsig hkind hnh hio,h.exit_from_run⟩

end
end Benitoite.Release.Refinement
