import Benitoite.Release.Refinement.ShapeTargets
import Benitoite.Release.Refinement.EffectFacts

/-! # 同じ実行環境での効果の許容と応答の観測 -/
namespace Benitoite.Release.Refinement
private inductive EffectAtom (l : EffName) (ix : RangeIx) : Tel → Prop where
  | done {e : Eff} : e.mem (.name l ix) → EffectAtom l ix (.done a e)
  | param : EffectAtom l ix t → EffectAtom l ix (.param n a t)
private theorem EffectAtom.norm {l ix t} (h : EffectAtom l ix t) : EffectAtom l ix t.norm := by
  induction h with
  | done hm => exact .done (by simpa using hm)
  | param h ih => exact .param ih
private theorem EffectAtom.bind {l ix t} (h : EffectAtom l ix t) (θ : SubstEnv) :
    EffectAtom l (ix.inst θ.ranges) (Tel.bind θ t) := by
  unfold Tel.bind
  apply EffectAtom.norm
  induction h generalizing θ with
  | done hm => exact .done ((Eff.mem_rawBind θ _ _).mpr (.inl ⟨_,hm,rfl,trivial⟩))
  | param h ih => exact .param (ih θ.up)
private theorem EffectAtom.signature {ns ps a l ix} {e : Eff} (h : e.mem (.name l ix)) :
    EffectAtom l ix (signatureTel ns ps a e) := by
  induction ns generalizing ps with
  | nil => exact .done h
  | cons n ns ih => cases ps with
    | nil => exact .done h
    | cons p ps => exact .param ih
private theorem EffectAtom.arguments {P B Ψ Q C Γ Φ ws t a e l r}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t a e)
    (hm : EffectAtom l (.fixed r) t) : e.mem (.name l (.fixed r)) := by
  induction ws generalizing t with
  | nil => cases h; cases hm with | done hm => exact hm
  | cons v vs ih => cases h with
    | param ha hv hs => cases hm with
      | param hm => exact ih hs (hm.bind (Tel.argumentsEnv v))
private theorem effect_atom {P B Ψ b sg ts es rs ws a e l ix}
    (h : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (hm : sg.eff.mem (.name l ix)) (r : RangeExpr)
    (hr : ix.inst rs = .fixed r) : e.mem (.name l (.fixed r)) := by
  have sig : EffectAtom l ix sg.tel := EffectAtom.signature hm
  have ran : EffectAtom l (ix.inst rs) (Tel.instR rs sg.tel) := by
    rw [Tel.instR_eq_bind]; exact sig.bind (.rangesOnly rs)
  rw [hr] at ran
  exact EffectAtom.arguments h.arguments (ran.bind (typeEnvAt 0 ts es))

theorem Builtins.TargetAgreement.obs_allowed {P B Ψ b sg ts es rs ws a e out obs σ}
    (hsh : B.ShapeOk b sg) (ht : B.TargetAgreement P)
    (hs : B.sig b = some sg) (hkind : sg.kind = .io ∨ sg.kind = .exit)
    (names : NamesWF sg.names sg.params)
    (ha : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ)
    (hr : B.ioResponse b ts es ws out obs) :
    ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind e l t := by
  have agree := ht.io_target _ _ _ _ _ _ _ _ _ _ _ hs hkind ha hr
  obtain ⟨l,bs,ho,hn,he,hb,sh⟩ := hsh
  refine ⟨l,ho,?_⟩
  cases shape : sg.shape with
  | untargeted =>
    have empty : obs = [] := by simpa [PrimSig.shapeAt,shape,Scope.Signature.ShapeTargets] using agree
    simp [empty]
  | topTargeted k =>
    rw [shape] at sh
    intro t hm
    have kind : t.kind = k := by
      exact (show Scope.Signature.ShapeTargets Val.target? (.topTargeted k) ws obs from
        by simpa [PrimSig.shapeAt,shape] using agree) t hm
    refine ⟨k,.top,sh.1,?_,?_⟩
    · apply effect_atom ha (ix := .top) _ .top rfl
      simp [sh.2.2,Eff.single,Eff.mem,Eff.test,Eff.atoms]
    · exact ⟨kind, .top, by simp, trivial⟩
  | single k p =>
    have shapeok : B.ShapeOk b sg := ⟨l,bs,ho,hn,he,hb,sh⟩
    obtain ⟨r,t,hrs,hw,hm,hshape⟩ := shapeok.single_target shape names ha had
    rw [shape] at sh
    rw [hshape] at agree
    obtain ⟨t',hw',rfl⟩ := agree
    have tt : t' = t := Option.some.inj (hw'.symm.trans hw)
    subst t'
    intro u hu
    have ut : u = t := List.mem_singleton.mp hu
    subst u
    refine ⟨k,r,sh.1,?_,hm⟩
    apply effect_atom ha (ix := .rvar 0) _ r (by simp [hrs,RangeIx.inst])
    simp [sh.2.2.1,Eff.mem,Eff.test,Eff.atoms]
/-- 実表の名前の形成を、観測の許容へ渡す。 -/
example {P B Ψ b sg ts es rs ws a e out obs σ}
    (sc : PrimSig.Scoped P sg) (sh : B.ShapeOk b sg) (ht : B.TargetAgreement P)
    (hs : B.sig b = some sg) (hk : sg.kind = .io ∨ sg.kind = .exit)
    (ha : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ) (hr : B.ioResponse b ts es ws out obs) :
    ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind e l t :=
  Builtins.TargetAgreement.obs_allowed sh ht hs hk sc.namesWF ha had hr

end Benitoite.Release.Refinement
