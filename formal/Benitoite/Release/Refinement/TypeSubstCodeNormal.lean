import Benitoite.Release.Refinement.ContextNormEq
import Benitoite.Release.Refinement.TypeSubstBindings

/-! # 型置換後のコードと恒等の値置換（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement

set_option maxRecDepth 4096
set_option maxHeartbeats 2000000

theorem upSubst_var (k : Nat) : upSubst k Val.var = Val.var := by
  funext i
  unfold upSubst
  split
  · rfl
  · simp only [Val.rename]
    congr 1
    omega

theorem Tel.bind_var (t : Tel) : Tel.bind (valEnv Val.var) t = t.norm := by
  change (Tel.rawBind (valEnv Val.var) t).norm = t.norm
  have he : valEnv Val.var = renEnv id := rfl
  rw [he,Tel.rawBind_id]

@[simp] theorem norm_substTypeAt (a : Ty) (c : Nat) (ts : List Ty) (es : List Eff) :
    (substTypeAt c ts es a).norm = substTypeAt c ts es a := Ty.norm_idem _

@[simp] theorem norm_substRowAt (e : Eff) (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.norm (substRowAt c ts es e) = substRowAt c ts es e := Eff.norm_idem _

@[simp] theorem Tel.bind_normal (t : Tel) (θ : SubstEnv) :
    (Tel.bind θ t).norm = Tel.bind θ t := Tel.norm_idem _

mutual
  theorem Val.subst_var_typeSubst (v : Val) (c : Nat) (ts : List Ty) (es : List Eff) :
      (v.substTyAt c ts es).subst Val.var LocalRef.bound = v.substTyAt c ts es := by
    cases v <;> simp only [Val.substTyAt,Val.subst,
      show substTyValues Val.var = Ty.norm from funext substTyValues_var,
      show substEffValues Val.var = Eff.norm from funext substEffValues_var,
      upSubst_var,upLocalSubst_bound,List.map_map,Function.comp_def,
      norm_substTypeAt,norm_substRowAt,Val.substList_var_typeSubst,
      Comp.subst_var_typeSubst,Val.subst_var_typeSubst,Tel.bind_var,Tel.bind_normal]
  theorem Val.substList_var_typeSubst (vs : List Val) (c : Nat) (ts : List Ty) (es : List Eff) :
      Val.substList Val.var (Val.substTyAtList c ts es vs) LocalRef.bound =
        Val.substTyAtList c ts es vs := by
    cases vs <;> simp only [Val.substTyAtList,Val.substList,Val.subst_var_typeSubst,
      Val.substList_var_typeSubst]
  theorem Comp.subst_var_typeSubst (m : Comp) (c : Nat) (ts : List Ty) (es : List Eff) :
      (m.substTyAt c ts es).subst Val.var LocalRef.bound = m.substTyAt c ts es := by
    cases m
    case builderLet kind body =>
      cases kind
      all_goals
        dsimp only [Comp.substTyAt,Comp.subst]
        simp only [upSubst_var,upLocalSubst_bound,Comp.subst_var_typeSubst]
        congr 1
      all_goals first
        | rfl
        | (change BuilderKind.list (substTyValues Val.var (substTypeAt c ts es _)) =
            BuilderKind.list (substTypeAt c ts es _)
           rw [substTyValues_var,norm_substTypeAt])
    case builderOp kind op ref args =>
      cases kind <;> cases ref
      all_goals
        dsimp only [Comp.substTyAt,Comp.subst]
        simp only [LocalRef.subst,Val.substList_var_typeSubst]
        congr 1
      all_goals first
        | rfl
        | (change BuilderKind.list (substTyValues Val.var (substTypeAt c ts es _)) =
            BuilderKind.list (substTypeAt c ts es _)
           rw [substTyValues_var,norm_substTypeAt])
    case checkAt kind name sh bases p v ix =>
      cases bases <;> dsimp only [Comp.substTyAt,Comp.subst]
      all_goals simp only [substTyValues_var,norm_substTypeAt,Val.subst_var_typeSubst]
    all_goals simp only [Comp.substTyAt,Comp.subst,
      show substTyValues Val.var = Ty.norm from funext substTyValues_var,
      show substEffValues Val.var = Eff.norm from funext substEffValues_var,
      upSubst_var,upLocalSubst_bound,List.map_map,Function.comp_def,
      norm_substTypeAt,norm_substRowAt,Val.substList_var_typeSubst,
      Comp.subst_var_typeSubst,Val.subst_var_typeSubst,Arm.substList_var_typeSubst,
      Clause.substList_var_typeSubst]
  theorem Arm.substList_var_typeSubst (arms : List Arm) (c : Nat) (ts : List Ty) (es : List Eff) :
      Arm.substList Val.var (Arm.substTyAtList c ts es arms) LocalRef.bound =
        Arm.substTyAtList c ts es arms := by
    cases arms with
    | nil => rfl
    | cons arm arms =>
      cases arm with
      | mk alts guard body =>
        cases guard <;> simp only [Arm.substTyAtList,Arm.substList,upSubst_var,upLocalSubst_bound,
          Comp.subst_var_typeSubst,Arm.substList_var_typeSubst]
  theorem Clause.substList_var_typeSubst (cs : List Clause) (c : Nat) (ts : List Ty) (es : List Eff) :
      Clause.substList Val.var (Clause.substTyAtList c ts es cs) LocalRef.bound =
        Clause.substTyAtList c ts es cs := by
    cases cs with
    | nil => rfl
    | cons clause cs =>
      cases clause <;> simp only [Clause.substTyAtList,Clause.substList,Val.shiftEAt,
        upSubst_var,upLocalSubst_bound,Comp.subst_var_typeSubst,Clause.substList_var_typeSubst,
        substTyValues_var,norm_substTypeAt]
end

theorem Ctx.NormEq.typeSubst_comp {P B Ψ Q C Γ Δ Φ e c ts es}
    {R : Option Ty} {m : Comp} {a : Ty} {L : LocalCtx}
    (h : Γ.NormEq Δ)
    (hc : ∀ (i : Nat) (b t : Ty) (e : Eff), Γ[i]? = some (some (.cont b t e)) →
      ∃ (b' t' : Ty) (e' : Eff), Δ[i]? = some (some (.cont b' t' e')))
    (ha : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF)
    (ht : HasTypeCQ P B Ψ Q C Γ Φ (R.map (Ty.substAt c ts es))
      (m.substTyAt c ts es) (a.substAt c ts es) (Eff.substAt c ts es e)
      (L.map (Option.map (BuilderKind.substAt c ts es)))) :
    HasTypeCQ P B Ψ Q C Δ Φ (R.map (Ty.substAt c ts es))
      (m.substTyAt c ts es) (a.substAt c ts es) (Eff.substAt c ts es e)
      (L.map (Option.map (BuilderKind.substAt c ts es))) := by
  have hh := h.comp hc ha hw ht
  have hR : (R.map (Ty.substAt c ts es)).map Ty.norm = R.map (Ty.substAt c ts es) := by
    cases R <;> simp only [Option.map_none,Option.map_some,Ty.substAt, norm_substTypeAt]
  have hL : (L.map (Option.map (BuilderKind.substAt c ts es))).map
      (Option.map BuilderKind.norm) = L.map (Option.map (BuilderKind.substAt c ts es)) := by
    simp only [List.map_map,Option.map_map,Function.comp_def]
    apply List.map_congr_left
    intro ob _
    cases ob with
    | none => rfl
    | some b =>
      cases b <;> simp only [Option.map_some,BuilderKind.norm,BuilderKind.substAt,
        Ty.substAt,norm_substTypeAt]
  simpa only [hR,hL,Comp.subst_var_typeSubst,Ty.substAt,norm_substTypeAt,
    Eff.substAt,norm_substRowAt] using hh

theorem BuilderKind.substAt_eq (c : Nat) (ts : List Ty) (es : List Eff) :
    (fun b : BuilderKind => match b with
      | .list a => .list (a.substAt c ts es) | .string => .string | .bytes => .bytes) =
      BuilderKind.substAt c ts es := by
  funext b
  cases b <;> rfl

end Benitoite.Release.Refinement
