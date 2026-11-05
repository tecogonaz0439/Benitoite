import Benitoite.Release.Refinement.CloseTyping
import Benitoite.Release.Refinement.MatchPaths

/-! # 実行の view が読む値（設計書 01-12「篩を含む状態の型付け」） -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 一歩で読む通常値。resume の継続は別に場所の証拠を取り出す。 -/
def Comp.readValues : Comp → List Val
  | .ret v => [v]
  | .app f vs => f :: vs
  | .builderLet _ _ | .letIn _ _ | .lazyC _ | .handle _ _ | .issuePathBases _ => []
  | .builderOp _ _ _ vs | .externalCall _ _ vs => vs
  | .ite v _ _ | .match v _ | .escape v | .use v _ | .resume _ v => [v]
  | .checkAt _ _ _ bs p v _ => bs.toList ++ [p,v]
  | .meth v _ _ _ vs => v :: vs

theorem HasTypeVsQ.read_values {P B Ψ Q C Γ Φ vs as}
    (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) :
    ∀ v ∈ vs, ∃ a, HasTypeVQ P B Ψ Q C Γ Φ v a := by
  match h with
  | .nil => intro v hv; cases hv
  | .cons hv hs =>
    intro v hh
    rcases List.mem_cons.mp hh with rfl | hh
    · exact ⟨_,hv⟩
    · exact hs.read_values v hh

theorem HasTypeTelArgsQ.read_values {P B Ψ Q C Γ Φ vs t a e}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) :
    ∀ v ∈ vs, ∃ b, HasTypeVQ P B Ψ Q C Γ Φ v b := by
  match h with
  | .done _ => intro v hv; cases hv
  | .param _ hv hs =>
    intro v hh
    rcases List.mem_cons.mp hh with rfl | hh
    · exact ⟨_,hv⟩
    · exact hs.read_values v hh

theorem HasTypeCQ.read_values {P B Ψ Q C Γ Φ R m a e L}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) :
    ∀ v ∈ m.readValues, ∃ b, HasTypeVQ P B Ψ Q C Γ Φ v b := by
  match h with
  | .C_Return hv | .C_Escape hv _ | .C_If hv _ _ _ | .C_Match hv _ _ _ |
    .C_Use hv _ _ _ | .C_Resume _ hv _ | .C_ResumeL _ hv _ |
    .C_ResumeNorm _ hv _ | .C_ResumeLNorm _ _ hv _ =>
    intro v hh
    cases List.mem_singleton.mp hh
    exact ⟨_,hv⟩
  | .C_App hf hs | .C_Meth hf _ _ _ _ _ _ _ hs _ =>
    intro v hh
    rcases List.mem_cons.mp hh with rfl | hh
    · exact ⟨_,hf⟩
    · exact hs.read_values v hh
  | .C_DependentApp hf hs =>
    intro v hh
    rcases List.mem_cons.mp hh with rfl | hh
    · exact ⟨_,hf⟩
    · exact hs.read_values v hh
  | .C_BuilderOp _ _ _ hs => exact hs.read_values
  | .C_External _ _ _ hs => exact hs.read_values
  | .C_CheckAt (bases := bases) ha =>
    cases ha with
    | mk _ _ hb hp _ hv _ _ =>
      intro v hh
      rcases List.mem_append.mp hh with hh | hh
      · cases hbases : bases with
        | none => simp [Option.toList, hbases] at hh
        | some w =>
          have he : v = w := by simpa [Option.toList, hbases] using hh
          subst v
          exact ⟨_,hb w hbases⟩
      · rcases List.mem_cons.mp hh with rfl | hh
        · exact ⟨_,hp⟩
        · cases List.mem_singleton.mp hh; exact ⟨_,hv⟩
    | text _ _ hb hp _ hv _ _ =>
      intro v hh
      rcases List.mem_append.mp hh with hh | hh
      · cases hbases : bases with
        | none => simp [Option.toList, hbases] at hh
        | some w =>
          have he : v = w := by simpa [Option.toList, hbases] using hh
          subst v
          exact ⟨_,hb w hbases⟩
      · rcases List.mem_cons.mp hh with rfl | hh
        · exact ⟨_,hp⟩
        · cases List.mem_singleton.mp hh; exact ⟨_,hv⟩
  | .C_BuilderLet .. | .C_Let .. | .C_Lazy .. | .C_Handle .. |
    .C_Handle_Fail .. | .C_IssuePathBases .. => intro v hv; cases hv
  | .C_Sub h .. | .C_Eff h _ | .C_Normal h => exact h.read_values
termination_by structural h

theorem closeVals_eq_map (cap : Capture) (vs : List Val) :
    closeVals cap vs = vs.map (closeVal cap) := by
  induction vs <;> simp_all [closeVals]

theorem Val.resolveLocalsList_eq_map (vs : List Val) (ρ : Nat → LocalRef) :
    Val.resolveLocalsList ρ vs = vs.map (fun v => v.resolveLocals ρ) := by
  induction vs <;> simp_all [Val.resolveLocalsList]

theorem Comp.readValues_resolve (m : Comp) (ρ : Nat → LocalRef) :
    (m.resolveLocals ρ).readValues = m.readValues.map (fun v => v.resolveLocals ρ) := by
  cases m
  case checkAt k n s bs p v i => cases bs <;> rfl
  all_goals simp only [Comp.resolveLocals,Comp.readValues,Val.resolveLocalsList_eq_map,List.map_nil,List.map_cons]

theorem Closure.readValues_view (q : Closure) :
    q.view.readValues = closeVals q.capture q.code.readValues := by
  cases q with
  | mk cap code =>
    cases code <;> simp only [Closure.view,Closure.capture,Closure.code,Comp.readValues,closeVals_eq_map,List.map_nil,List.map_cons,List.map_append]
    case checkAt k n s bs p v i => cases bs <;> rfl

/-- 元の型・効果・戻り先、子コードと局所参照を同じ証人で保持する view。 -/
inductive ClosureViewTy (P : Program) (B : Builtins) (Ψ : StoreTy)
    (R : Option Ty) (q : Closure) (a : Ty) (e : Eff) : Prop where
  | mk {cap Γ Φ Rs source as es L ρ} :
      q = .mk cap (source.resolveLocals ρ) → CaptureOk P B Ψ R Γ Φ cap →
      HasTypeCQ P B Ψ Qempty [] Γ Φ Rs source as es L →
      CaptureLocals Ψ cap.env L ρ → cap.closeR Rs = R →
      cap.closeTy as = a → cap.closeEff es = e →
      (∀ v ∈ source.readValues, ∃ t,
        HasTypeVQ P B Ψ Qempty [] Γ Φ v t ∧
        HasTypeVQ P B Ψ Qempty [] [] [] (closeVal cap v) (cap.closeTy t)) →
      q.view.readValues = closeVals cap source.readValues →
      ClosureViewTy P B Ψ R q a e

theorem ClosureTy.view_typed {P B Ψ R q a e}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) : ClosureViewTy P B Ψ R q a e := by
  obtain ⟨cap,Γ,Φ,Rs,m,as,es,L,ρ,hq,hc,hb,hl,hr,ha,he,_⟩ := hq.open_zero
  refine .mk hq hc hb hl hr ha he ?_ ?_
  · intro v hv
    obtain ⟨t,ht⟩ := hb.read_values v hv
    exact ⟨t,ht,close_value_typed hP hPB hB hw hs hd hc ht⟩
  · rw [hq,Closure.readValues_view]
    change closeVals cap (m.resolveLocals ρ).readValues = _
    rw [Comp.readValues_resolve]
    congr 1
    have hmap : m.readValues.map (fun v => v.resolveLocals ρ) = m.readValues.map id := by
      apply List.map_congr_left
      intro v hv
      obtain ⟨t,ht⟩ := hb.read_values v hv
      exact ht.resolve_id ρ
    simpa only [List.map_id] using hmap

theorem Val.ClosedList.member {nt nv vs v}
    (h : Val.ClosedList nt nv vs) (hv : v ∈ vs) : v.ClosedAt nt nv := by
  induction vs with
  | nil => cases hv
  | cons w ws ih =>
    rcases List.mem_cons.mp hv with rfl | hv
    · exact h.1
    · exact ih h.2 hv

theorem Comp.ClosedAt.read_values {m : Comp} {nt nv : Nat}
    (h : m.ClosedAt nt nv) {v : Val} (hv : v ∈ m.readValues) : v.ClosedAt nt nv := by
  match m with
  | .ret _ | .escape _ => cases List.mem_singleton.mp hv; exact h
  | .app _ _ =>
    rcases List.mem_cons.mp hv with rfl | hv
    · exact h.1
    · exact h.2.member hv
  | .meth _ _ _ _ _ =>
    rcases List.mem_cons.mp hv with rfl | hv
    · exact h.1
    · exact h.2.2.2.member hv
  | .ite _ _ _ | .match _ _ | .use _ _ => cases List.mem_singleton.mp hv; exact h.1
  | .resume _ _ => cases List.mem_singleton.mp hv; exact h.2
  | .builderOp _ _ _ _ => exact h.2.2.member hv
  | .externalCall _ _ _ => exact h.2.member hv
  | .checkAt _ _ _ bs _ _ _ =>
    cases bs with
    | none =>
      rcases List.mem_cons.mp hv with hv | hv
      · exact hv.symm ▸ h.2.2.2.1
      · exact (List.mem_singleton.mp hv).symm ▸ h.2.2.2.2
    | some w =>
      rcases List.mem_cons.mp hv with hv | hv
      · exact hv.symm ▸ h.2.2.1
      · rcases List.mem_cons.mp hv with hv | hv
        · exact hv.symm ▸ h.2.2.2.1
        · exact (List.mem_singleton.mp hv).symm ▸ h.2.2.2.2
  | .builderLet .. | .letIn .. | .lazyC .. | .handle .. | .issuePathBases .. => cases hv

theorem Closure.view_adequate {q : Closure} {σ : PathEnv} (h : q.Adequate σ) : q.view.Adequate σ := by
  cases q with
  | mk cap m =>
    obtain ⟨hc,hm⟩ := h
    cases m <;> first | exact hm | skip
    case ret v => exact closeVal_adequate hc hm
    case app f vs => exact ⟨closeVal_adequate hc hm.1,closeVals_adequate hc hm.2⟩
    case builderOp => exact closeVals_adequate hc hm
    case ite => exact ⟨closeVal_adequate hc hm.1,hm.2⟩
    case «match» => exact ⟨closeVal_adequate hc hm.1,hm.2⟩
    case escape => exact closeVal_adequate hc hm
    case use => exact ⟨closeVal_adequate hc hm.1,hm.2⟩
    case resume => exact ⟨closeVal_adequate hc hm.1,closeVal_adequate hc hm.2⟩
    case externalCall => exact closeVals_adequate hc hm
    case meth => exact ⟨closeVal_adequate hc hm.1,closeVals_adequate hc hm.2⟩
    case checkAt k o sh bs p v ix =>
      cases bs with
      | none => exact ⟨trivial,closeVal_adequate hc hm.2.1,closeVal_adequate hc hm.2.2⟩
      | some b => exact ⟨closeVal_adequate hc hm.1,closeVal_adequate hc hm.2.1,closeVal_adequate hc hm.2.2⟩

theorem ClosureTy.view_read_ground {P B Ψ R q a e v}
    (hq : ClosureTy P B Ψ [] R q a e) (hclosed : q.ClosedAt 0)
    (hv : v ∈ q.view.readValues) : v.Ground := by
  obtain ⟨cap,Γ,Φ,Rs,m,as,es,L,ρ,rfl,hc,hb,_,_,_,_,_⟩ := hq.open_zero
  rw [Closure.readValues_view,closeVals_eq_map] at hv
  obtain ⟨w,hw,rfl⟩ := List.mem_map.mp hv
  change w ∈ (m.resolveLocals ρ).readValues at hw
  rw [Comp.readValues_resolve] at hw
  obtain ⟨u,hu,rfl⟩ := List.mem_map.mp hw
  obtain ⟨t,ht⟩ := hb.read_values u hu
  have hu' : u.resolveLocals ρ ∈ (m.resolveLocals ρ).readValues := by
    rw [Comp.readValues_resolve]
    exact List.mem_map.mpr ⟨u,hu,rfl⟩
  have hcval := Comp.ClosedAt.read_values hclosed.2 hu'
  change (closeVal cap (u.resolveLocals ρ)).Ground
  rw [ht.resolve_id ρ] at hcval ⊢
  exact ht.close_ground hc rfl hclosed.1 (by simpa only [Capture.values,Nat.add_zero] using hcval)

theorem ClosureTy.view_read_typed {P B Ψ R q a e v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : v ∈ q.view.readValues) :
    ∃ t, HasTypeVQ P B Ψ Qempty [] [] [] v t := by
  cases hq.view_typed hP hPB hB hw hs hd with
  | mk _ _ _ _ _ _ _ hread heq =>
    rw [heq,closeVals_eq_map] at hv
    obtain ⟨w,hw,rfl⟩ := List.mem_map.mp hv
    obtain ⟨t,_,ht⟩ := hread w hw
    exact ⟨_,ht⟩

end
end Benitoite.Release.Refinement
