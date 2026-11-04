import Benitoite.Release.Refinement.MembershipTargets
import Benitoite.Release.Refinement.PrimitiveScoped

/-! # 同じ保持値の不透明型への互換拡大と節の引数列 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem holds_indices {T : Ty} {o k ix o' k' ix'}
    (h : T.Holds o k ix) (g : T.Holds o' k' ix') : o = o' ∧ ix = ix' := by
  rcases h with h | h <;> rcases g with g | g
  all_goals have he := h.symm.trans g
  all_goals cases he
  all_goals exact ⟨rfl,rfl⟩

private theorem fixed_cover_wf {ix : RangeIx} {r : RangeExpr}
    (h : ix.Covers (.fixed r)) : ix.WF 0 := by
  cases ix <;> simp_all [RangeIx.Covers,RangeIx.WF]

/-- 通常の定数と、同じ値に対する scoped の導出を区別する。 -/
theorem HasTypeVQ.canonical_opaque {P B Ψ Q C Φ v o ix}
    (h : HasTypeVQ P B Ψ Q C [] Φ v (.opaque o ix)) :
    (∃ n, v = .const (.opaque o n) ∧ ix = .fixed .top) ∨
      ∃ k, B.valKind o = some k ∧ HasTypeVQ P B Ψ Q C [] Φ v (.scoped o k ix) := by
  have ht : (Ty.opaque o ix).Holds o .path ix := Or.inr rfl
  rcases h.canonical_held ht with ⟨o',payload,rfl⟩ | ⟨t,rfl⟩ |
    ⟨t,req,rfl⟩ | ⟨r,snapshot,t,req,rfl⟩
  · obtain ⟨_,he⟩ := h.inv_const rfl
    change Ty.opaque o ix = Ty.opaque o' (.fixed .top) at he
    cases he
    exact Or.inl ⟨payload,rfl,rfl⟩
  · obtain ⟨o',k,r,jx,hk,hc,hm,ht',hi⟩ := h.inv_checked rfl
    obtain ⟨rfl,rfl⟩ := holds_indices ht ht'
    exact Or.inr ⟨k,hk,.V_Sub (.V_Checked hk hc hm) (.scoped hi) (fixed_cover_wf hi) trivial trivial⟩
  · obtain ⟨o',r,A,jx,hk,hc,hh,hg,he,hm,ht',hi⟩ := h.inv_checkedRequest rfl
    obtain ⟨rfl,rfl⟩ := holds_indices ht ht'
    exact Or.inr ⟨.endpoint,hk,
      .V_Sub (.V_CheckedRequest hk hc hh hg he hm) (.scoped hi) (fixed_cover_wf hi) trivial trivial⟩
  · obtain ⟨o',k,jx,hw,ht',hi⟩ := h.inv_checkedAt rfl
    obtain ⟨rfl,rfl⟩ := holds_indices ht ht'
    have hk : B.valKind o = some k := by cases hw <;> assumption
    exact Or.inr ⟨k,hk,.V_Sub (.V_CheckedAt hw) (.scoped hi) (fixed_cover_wf hi) trivial trivial⟩

/-- 不透明型の拡大は、scoped の共変と同じ値の忘却を合成する。 -/
theorem HasTypeVQ.widen_opaque {P B Ψ Q C Φ v o r s}
    (h : HasTypeVQ P B Ψ Q C [] Φ v (.opaque o (.fixed r))) (hc : s.Covers r) :
    HasTypeVQ P B Ψ Q C [] Φ v (.opaque o (.fixed s)) := by
  rcases h.canonical_opaque with ⟨n,rfl,hi⟩ | ⟨k,_,hs⟩
  · cases hi
    have he : s = .top := by
      cases s <;> simp_all [RangeExpr.Covers,Scope.Domain.Range.covers_top_iff]
    subst s
    exact h
  · have widened : HasTypeVQ P B Ψ Q C [] Φ v (.scoped o k (.fixed s)) :=
      hs.V_Sub (.scoped hc) (by trivial) (by trivial) (by trivial)
    exact widened.V_Sub .scoped_forget trivial trivial trivial

private theorem subst_opaque (o : OpaqueName) (ix : RangeIx) (ts : List Ty) (es : List Eff) :
    (Ty.opaque o ix).subst ts es = .opaque o ix := by
  simp [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,Ty.norm]
private theorem subst_scoped (o : OpaqueName) (k : Scope.Domain.Kind) (ix : RangeIx)
    (ts : List Ty) (es : List Eff) :
    (Ty.scoped o k ix).subst ts es = .scoped o k ix := by
  simp [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,Ty.norm]

/-- 具体化済みの対象位置だけを、節の一つの上限で広げる。 -/
theorem HasTypeVQ.widen_instTarget_covers {P B Ψ Q C Φ v ts es}
    {p : Ty} {rs : List RangeExpr} {n nv : Nat} {S : RangeExpr}
    (hn : rs.length = n) (hp : p.TargetWF n C.length nv)
    (hc : ∀ r ∈ rs, S.Covers r)
    (h : HasTypeVQ P B Ψ Q C [] Φ v ((p.instTarget rs).subst ts es)) :
    HasTypeVQ P B Ψ Q C [] Φ v
      ((p.instTarget (List.replicate n S)).subst ts es) := by
  cases p with
  | «opaque» o ix =>
    cases ix with
    | fixed r => exact h
    | rvar i =>
      have hi : i < n := hp
      have hir : i < rs.length := hn ▸ hi
      simp only [Ty.instTarget,RangeIx.inst,List.getElem?_eq_getElem hir,subst_opaque] at h
      simp only [Ty.instTarget,RangeIx.inst,List.getElem?_replicate,hi,ite_true,subst_opaque]
      exact h.widen_opaque (hc _ (List.getElem_mem hir))
  | «scoped» o k ix =>
    cases ix with
    | fixed r => exact h
    | rvar i =>
      have hi : i < n := hp
      have hir : i < rs.length := hn ▸ hi
      simp only [Ty.instTarget,RangeIx.inst,List.getElem?_eq_getElem hir,subst_scoped] at h
      simp only [Ty.instTarget,RangeIx.inst,List.getElem?_replicate,hi,ite_true,subst_scoped]
      exact h.V_Sub (.scoped (hc _ (List.getElem_mem hir))) trivial trivial trivial
  | _ => exact h

/-- 引数列の全位置を、同じ順序・値・型と行の像のまま節へ渡す。 -/
theorem HasTypeVsQ.widen_covers {P B Ψ Q C Φ ws ps ts es rs n S nv}
    (hn : rs.length = n) (hp : BinderTypes.TargetWF n C.length nv ps)
    (hc : ∀ r ∈ rs, S.Covers r)
    (h : HasTypeVsQ P B Ψ Q C [] Φ ws ((ps.map (Ty.instTarget rs)).map (Ty.subst ts es))) :
    HasTypeVsQ P B Ψ Q C [] Φ ws
      ((ps.map (Ty.instTarget (List.replicate n S))).map (Ty.subst ts es)) := by
  induction ps generalizing ws nv with
  | nil => cases h; exact .nil
  | cons p ps ih =>
    cases h with
    | cons hv hs => exact .cons (hv.widen_instTarget_covers hn hp.1 hc) (ih hp.2 hs)

/-- 操作の元の形成と実引数から、捕捉した節の添字への全列の移送を供給する。 -/
example {P B Ψ Q C Φ ws sg ts es rs S b l}
    (hsc : PrimSig.Scoped P sg) (hsig : B.sig b = some sg) (hop : sg.opEff = some l)
    (hn : rs.length = sg.rkinds.length) (hc : ∀ r ∈ rs, S.Covers r)
    (h : HasTypeVsQ P B Ψ Q C [] Φ ws
      ((sg.params.map (Ty.instTarget rs)).map (Ty.subst ts es)))
    (hcTypes : C.length = sg.tparams.length) :
    ∃ clause, opSigAt P B S (.prim b) = some clause ∧
      HasTypeVsQ P B Ψ Q C [] Φ ws (clause.params.map (Ty.subst ts es)) := by
  have hw := (hsc.operation (by rw [hop]; simp)).1.1
  rw [← hcTypes] at hw
  exact ⟨⟨sg.tparams,sg.names,sg.params.map (Ty.instTarget (List.replicate sg.rkinds.length S)),sg.ret,l⟩,
    by simp [opSigAt,hsig,hop], h.widen_covers hn hw hc⟩

/-- 拡大後も同じ req と endpoint を射影し、同じ環境で新しい上限に属する。 -/
example {P B Ψ Q v o r S σ A}
    (h : HasTypeVQ P B Ψ Q [] [] [] v (.opaque o (.fixed r)))
    (hk : B.valKind o = some .endpoint) (content : B.valContent o = some A)
    (ha : v.Adequate σ) (hc : S.Covers r) :
    HasTypeVQ P B Ψ Q [] [] [] v (.opaque o (.fixed S)) ∧
    ∃ target req, (v = .checkedRequest target req ∨
      ∃ s snapshot, v = .checkedAt s snapshot target (some req)) ∧
      ModelHttp.valueRun [v] = .val req ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
      groundVal req = true ∧ req.reqTarget = some target ∧ S.Mem σ .endpoint target := by
  have widened := h.widen_opaque hc
  exact ⟨widened,widened.request_target (Or.inr rfl) hk content ha⟩

/-- /data/** のパスはTopの不透明型へ広がり、同じ値を覆わない /other/** では拒否される。 -/
example {P B Ψ Q} (σ : PathEnv)
    (hk : B.valKind "Scope.PathIn" = some .path)
    (hc : B.valContent "Scope.PathIn" = none) :
    HasTypeVQ P B Ψ Q [] [] [] (.checked (.path ["data"]))
      (.opaque "Scope.PathIn" (.fixed .top)) ∧
    ¬ HasTypeVQ P B Ψ Q [] [] [] (.checked (.path ["data"]))
      (.opaque "Scope.PathIn" (.fixed (.absolute (.path (.tree ["other"]))))) := by
  have path : HasTypeVQ P B Ψ Q [] [] [] (.checked (.path ["data"]))
      (.opaque "Scope.PathIn" (.fixed (.absolute (.path (.tree ["data"]))))) :=
    HasTypeVQ.checked_opaque hk hc ⟨rfl,⟨[],rfl⟩⟩
  refine ⟨path.widen_opaque (Or.inl rfl),?_⟩
  intro h
  obtain ⟨t,he,hm⟩ := h.target_member (σ := σ) (Or.inr rfl) hk (by simp [Val.Adequate])
  simp [Val.target?] at he
  subst he
  revert hm
  simp [RangeExpr.Mem, RangeExpr.resolve]
  decide

end
end Benitoite.Release.Refinement
