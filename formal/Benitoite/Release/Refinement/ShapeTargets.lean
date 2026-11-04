import Benitoite.Release.Refinement.MembershipTargets
import Benitoite.Release.Refinement.BuiltinResponse
import Benitoite.Release.Refinement.PrimitiveScoped

/-! # 依存する実引数列の任意位置と単一の保持対象 -/
namespace Benitoite.Release.Refinement

private inductive OpaqueAt : Tel → Nat → OpaqueName → RangeIx → Prop where
  | head : OpaqueAt (.param n (.opaque o ix) rest) 0 o ix
  | tail : OpaqueAt rest p o ix → OpaqueAt (.param n a rest) (p+1) o ix

private theorem OpaqueAt.norm {tel p o ix} (h : OpaqueAt tel p o ix) :
    OpaqueAt tel.norm p o ix := by
  match h with
  | .head => exact .head
  | .tail h => exact .tail h.norm

private theorem OpaqueAt.bind {tel p o ix} (h : OpaqueAt tel p o ix) (θ : SubstEnv) :
    OpaqueAt (Tel.bind θ tel) p o (ix.inst θ.ranges) := by
  unfold Tel.bind
  apply OpaqueAt.norm
  induction h generalizing θ with
  | head => exact .head
  | tail h ih => exact .tail (ih θ.up)

private theorem OpaqueAt.signature {ns ps ret eff p o ix}
    (hn : NamesWF ns ps) (hp : ps[p]? = some (.opaque o ix)) :
    OpaqueAt (signatureTel ns ps ret eff) p o ix := by
  induction ns generalizing ps p with
  | nil => cases ps <;> simp_all [NamesWF]
  | cons n ns ih =>
    cases ps with
    | nil => simp at hp
    | cons a ps =>
      cases p with
      | zero => simp at hp; subst a; exact .head
      | succ p =>
        exact .tail (ih ⟨by simpa using hn.1, hn.2.of_cons⟩ hp)

private theorem OpaqueAt.argument {P B Ψ Q C Γ Φ ws tel a e p o r}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws tel a e)
    (hp : OpaqueAt tel p o (.fixed r)) :
    ∃ w, ws[p]? = some w ∧ HasTypeVQ P B Ψ Q C Γ Φ w (.opaque o (.fixed r)) := by
  induction ws generalizing tel p with
  | nil => cases h; cases hp
  | cons v vs ih =>
    cases h with
    | param ha hv hs =>
      cases hp with
      | head => exact ⟨_, rfl, hv⟩
      | tail hp =>
        obtain ⟨w,hw,ht⟩ := ih hs (hp.bind (Tel.argumentsEnv _))
        exact ⟨w, hw, ht⟩

/-- 宣言の形成から名前と引数型の同数・非重複を取り出す。 -/
theorem PrimSig.Scoped.namesWF {P sg} (h : PrimSig.Scoped P sg) : NamesWF sg.names sg.params :=
  h.names

theorem Builtins.ShapeOk.single_target {P B Ψ b sg ts es rs ws a e k p σ}
    (sh : B.ShapeOk b sg) (single : sg.shape = .single k p)
    (names : NamesWF sg.names sg.params)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ) :
    ∃ r t, rs = [r] ∧ (ws[p]?).bind Val.target? = some t ∧
      r.Mem σ k t ∧ sg.shapeAt ws = .single k p := by
  obtain ⟨l,bs,ho,hn,he,hb,hs⟩ := sh
  rw [single] at hs
  obtain ⟨hk,hr,hef,o,hp,hv⟩ := hs
  have count := args.ranges.1
  rw [hr] at count
  obtain ⟨r,rfl⟩ : ∃ r, rs = [r] := by
    cases rs with
    | nil => simp at count
    | cons r rest =>
      cases rest with
      | nil => exact ⟨r,rfl⟩
      | cons _ _ => simp at count
  have atSig : OpaqueAt sg.tel p o (.rvar 0) := OpaqueAt.signature names hp
  have atRange : OpaqueAt (Tel.instR [r] sg.tel) p o (.fixed r) := by
    rw [Tel.instR_eq_bind]
    exact atSig.bind (.rangesOnly [r])
  have atType : OpaqueAt (instantiatedTel (Tel.instR [r] sg.tel) ts es) p o (.fixed r) :=
    atRange.bind (typeEnvAt 0 ts es)
  obtain ⟨w,hw,ht⟩ := OpaqueAt.argument args.arguments atType
  obtain ⟨t,ht,hm⟩ := ht.target_member (Or.inr rfl) hv
    (had w (List.mem_of_getElem? hw))
  refine ⟨r,t,rfl,?_,hm,?_⟩
  · simp [hw,ht]
  · simp [PrimSig.shapeAt, single, hw, ht]

/-- 整形式の表の names 欄を、同じ型付き呼出しへ供給する。 -/
example {P B Ψ b sg ts es rs ws a e k p σ}
    (hsc : PrimSig.Scoped P sg) (sh : B.ShapeOk b sg)
    (single : sg.shape = .single k p)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ) :
    ∃ r t, rs = [r] ∧ (ws[p]?).bind Val.target? = some t ∧
      r.Mem σ k t ∧ sg.shapeAt ws = .single k p :=
  sh.single_target single hsc.namesWF args had

end Benitoite.Release.Refinement
