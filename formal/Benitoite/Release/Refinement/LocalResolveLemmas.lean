import Benitoite.Release.Refinement.LocalResolve
import Benitoite.Release.Refinement.Typing
import Benitoite.Release.Refinement.ValueRenameAlgebra

namespace Benitoite.Release.Refinement
noncomputable section

theorem upLocalSubst_bound (n : Nat) : upLocalSubst n LocalRef.bound = LocalRef.bound := by
  funext i; by_cases hi : i < n
  · simp [upLocalSubst,hi]
  · simp [upLocalSubst,hi,LocalRef.rename,Nat.sub_add_cancel (Nat.le_of_not_gt hi)]


mutual
  theorem Val.resolveLocals_id (v : Val) : v.resolveLocals LocalRef.bound = v := by
    cases v <;> simp only [Val.resolveLocals,Val.resolveLocals_id,Val.resolveLocalsList_id,Comp.resolveLocals_id,upLocalSubst_bound]
  theorem Val.resolveLocalsList_id (vs : List Val) : Val.resolveLocalsList LocalRef.bound vs = vs := by
    cases vs <;> simp only [Val.resolveLocalsList,Val.resolveLocals_id,Val.resolveLocalsList_id]
  theorem Comp.resolveLocals_id (m : Comp) : m.resolveLocals LocalRef.bound = m := by
    cases m
    case checkAt _ _ _ bs _ _ _ => cases bs <;> simp only [Comp.resolveLocals,Val.resolveLocals_id]
    all_goals simp only [Comp.resolveLocals,Val.resolveLocals_id,Val.resolveLocalsList_id,Comp.resolveLocals_id,
      Arm.resolveLocalsList_id,Clause.resolveLocalsList_id,upLocalSubst_bound,LocalRef.subst]
    case builderOp k op r vs => cases r <;> rfl
  theorem Arm.resolveLocalsList_id (arms : List Arm) : Arm.resolveLocalsList LocalRef.bound arms = arms := by
    cases arms with
    | nil => rfl
    | cons arm arms => cases arm with
      | mk alts guard body => cases guard <;> simp only [Arm.resolveLocalsList,Comp.resolveLocals_id,Arm.resolveLocalsList_id,upLocalSubst_bound]
  theorem Clause.resolveLocalsList_id (cs : List Clause) : Clause.resolveLocalsList LocalRef.bound cs = cs := by
    cases cs with
    | nil => rfl
    | cons cl cs => cases cl <;> simp only [Clause.resolveLocalsList,Comp.resolveLocals_id,Clause.resolveLocalsList_id,upLocalSubst_bound]
end

def localCompose (τ ρ : Nat → LocalRef) (i : Nat) : LocalRef := (ρ i).subst τ

theorem upLocalSubst_compose (n : Nat) (τ ρ : Nat → LocalRef) :
    localCompose (upLocalSubst n τ) (upLocalSubst n ρ) = upLocalSubst n (localCompose τ ρ) := by
  funext i
  by_cases hi : i < n
  · simp [localCompose,upLocalSubst,hi,LocalRef.subst]
  · cases hr : ρ (i-n) with
    | bound j => simp [localCompose,upLocalSubst,hi,hr,LocalRef.subst,LocalRef.rename,show ¬j+n<n by omega]
    | loc l => simp [localCompose,upLocalSubst,hi,hr,LocalRef.subst,LocalRef.rename]

theorem LocalRef.subst_comp (r : LocalRef) (τ ρ : Nat → LocalRef) :
    (r.subst ρ).subst τ = r.subst (localCompose τ ρ) := by cases r <;> rfl

/- 局所参照の置換を先に行っても、値の置換は同じ注釈を正規化する。 -/
mutual
  theorem Val.subst_resolveLocals (v : Val) (ν : Nat → Val) (ρ τ : Nat → LocalRef) :
      (v.resolveLocals ρ).subst ν τ = v.subst ν (localCompose τ ρ) := by
    cases v <;> simp only [Val.resolveLocals,Val.subst,Val.subst_resolveLocals,Val.substList_resolveLocals,
      Comp.subst_resolveLocals,upLocalSubst_compose]
  theorem Val.substList_resolveLocals (vs : List Val) (ν : Nat → Val) (ρ τ : Nat → LocalRef) :
      Val.substList ν (Val.resolveLocalsList ρ vs) τ = Val.substList ν vs (localCompose τ ρ) := by
    cases vs <;> simp only [Val.resolveLocalsList,Val.substList,Val.subst_resolveLocals,Val.substList_resolveLocals]
  theorem Comp.subst_resolveLocals (m : Comp) (ν : Nat → Val) (ρ τ : Nat → LocalRef) :
      (m.resolveLocals ρ).subst ν τ = m.subst ν (localCompose τ ρ) := by
    cases m
    case checkAt _ _ _ bs _ _ _ => cases bs <;> simp only [Comp.resolveLocals,Comp.subst,Val.subst_resolveLocals]
    all_goals simp only [Comp.resolveLocals,Comp.subst,Val.subst_resolveLocals,Val.substList_resolveLocals,
      Comp.subst_resolveLocals,Arm.substList_resolveLocals,Clause.substList_resolveLocals,upLocalSubst_compose,LocalRef.subst_comp]
  theorem Arm.substList_resolveLocals (arms : List Arm) (ν : Nat → Val) (ρ τ : Nat → LocalRef) :
      Arm.substList ν (Arm.resolveLocalsList ρ arms) τ = Arm.substList ν arms (localCompose τ ρ) := by
    cases arms with
    | nil => rfl
    | cons arm arms => cases arm with
      | mk alts guard body => cases guard <;> simp only [Arm.resolveLocalsList,Arm.substList,
          Comp.subst_resolveLocals,Arm.substList_resolveLocals,upLocalSubst_compose]
  theorem Clause.substList_resolveLocals (cs : List Clause) (ν : Nat → Val) (ρ τ : Nat → LocalRef) :
      Clause.substList ν (Clause.resolveLocalsList ρ cs) τ = Clause.substList ν cs (localCompose τ ρ) := by
    cases cs with
    | nil => rfl
    | cons cl cs => cases cl <;> simp only [Clause.resolveLocalsList,Clause.substList,
        Comp.subst_resolveLocals,Clause.substList_resolveLocals,upLocalSubst_compose]
end

theorem telBinders_arity (t : Tel) : telBinders t = t.arity := by
  cases t with
  | done => rfl
  | param n a t =>
    change telBinders t + 1 = t.names.length + 1
    exact congrArg (·+1) (telBinders_arity t)

theorem telBinders_bind (t : Tel) (θ : SubstEnv) : telBinders (Tel.bind θ t) = telBinders t := by
  rw [telBinders_arity,telBinders_arity,Tel.arity,Tel.arity,Tel.names_bind]

theorem builderImages_resolve (n : Nat) (ρ : Nat → LocalRef) (i : Nat) :
    ((upSubst n builderValueSubst) i).resolveLocals ρ = (upSubst n builderValueSubst) i := by
  unfold upSubst
  split
  · rfl
  · cases h : i-n <;> simp [builderValueSubst,Val.rename,Val.resolveLocals]

theorem builderImages_shiftE (n k : Nat) :
    (fun i => ((upSubst n builderValueSubst) i).shiftEAt k 0) = upSubst n builderValueSubst := by
  funext i; unfold upSubst
  split
  · rfl
  · cases h : i-n <;> simp [builderValueSubst,Val.rename,Val.shiftEAt]

mutual
  theorem Val.resolveLocals_builderSubst (v : Val) (n : Nat) (ρ : Nat → LocalRef) :
      (v.subst (upSubst n builderValueSubst) LocalRef.bound).resolveLocals ρ =
        v.subst (upSubst n builderValueSubst) ρ := by
    cases v <;> simp only [Val.subst,Val.resolveLocals,Val.resolveLocals_builderSubst,Val.resolveLocalsList_builderSubst,
      Comp.resolveLocals_builderSubst,upLocalSubst_bound,upSubst_add,List.length_map,telBinders_bind,builderImages_resolve]
  theorem Val.resolveLocalsList_builderSubst (vs : List Val) (n : Nat) (ρ : Nat → LocalRef) :
      Val.resolveLocalsList ρ (Val.substList (upSubst n builderValueSubst) vs LocalRef.bound) =
        Val.substList (upSubst n builderValueSubst) vs ρ := by
    cases vs <;> simp only [Val.substList,Val.resolveLocalsList,Val.resolveLocals_builderSubst,Val.resolveLocalsList_builderSubst]
  theorem Comp.resolveLocals_builderSubst (m : Comp) (n : Nat) (ρ : Nat → LocalRef) :
      (m.subst (upSubst n builderValueSubst) LocalRef.bound).resolveLocals ρ =
        m.subst (upSubst n builderValueSubst) ρ := by
    cases m
    case checkAt _ _ _ bs _ _ _ => cases bs <;> simp only [Comp.subst,Comp.resolveLocals,Val.resolveLocals_builderSubst]
    all_goals simp only [Comp.subst,Comp.resolveLocals,Val.resolveLocals_builderSubst,Val.resolveLocalsList_builderSubst,
      Comp.resolveLocals_builderSubst,Arm.resolveLocalsList_builderSubst,Clause.resolveLocalsList_builderSubst,
      upSubst_add,upLocalSubst_bound]
    case builderOp k op r vs => cases r <;> rfl
  theorem Arm.resolveLocalsList_builderSubst (arms : List Arm) (n : Nat) (ρ : Nat → LocalRef) :
      Arm.resolveLocalsList ρ (Arm.substList (upSubst n builderValueSubst) arms LocalRef.bound) =
        Arm.substList (upSubst n builderValueSubst) arms ρ := by
    cases arms with
    | nil => rfl
    | cons arm arms => cases arm with
      | mk alts guard body => cases guard <;> simp only [Arm.substList,Arm.resolveLocalsList,
          Comp.resolveLocals_builderSubst,Arm.resolveLocalsList_builderSubst,upSubst_add,upLocalSubst_bound]
  theorem Clause.resolveLocalsList_builderSubst (cs : List Clause) (n : Nat) (ρ : Nat → LocalRef) :
      Clause.resolveLocalsList ρ (Clause.substList (upSubst n builderValueSubst) cs LocalRef.bound) =
        Clause.substList (upSubst n builderValueSubst) cs ρ := by
    cases cs with
    | nil => rfl
    | cons cl cs => cases cl <;> simp only [Clause.substList,Clause.resolveLocalsList,
        Comp.resolveLocals_builderSubst,Clause.resolveLocalsList_builderSubst,upSubst_add,upLocalSubst_bound,builderImages_shiftE]
end

def pushLocal (r : LocalRef) (ρ : Nat → LocalRef) : Nat → LocalRef
  | 0 => r
  | i+1 => ρ i

theorem localCompose_builder (l : Nat) (ρ : Nat → LocalRef) :
    localCompose (builderLocalSubst l) (upLocalSubst 1 ρ) = pushLocal (.loc l) ρ := by
  funext i
  cases i with
  | zero => rfl
  | succ i => cases h : ρ i <;> simp [localCompose,upLocalSubst,builderLocalSubst,pushLocal,LocalRef.rename,LocalRef.subst,h]

theorem Comp.builderBody_resolve (m : Comp) (l : Nat) (ρ : Nat → LocalRef) :
    (m.resolveLocals (upLocalSubst 1 ρ)).subst builderValueSubst (builderLocalSubst l) =
      (m.subst builderValueSubst LocalRef.bound).resolveLocals (pushLocal (.loc l) ρ) := by
  rw [Comp.subst_resolveLocals,localCompose_builder]
  simpa only [upSubst_zero] using (Comp.resolveLocals_builderSubst m 0 (pushLocal (.loc l) ρ)).symm

def LocalsFixed (Δ : LocalCtx) (ρ : Nat → LocalRef) : Prop :=
  ∀ i b, Δ[i]? = some (some b) → ρ i = .bound i

theorem LocalRef.HasKind.resolve_fixed {Ψ L r b ρ} (h : LocalRef.HasKind Ψ L r b)
    (hf : LocalsFixed L ρ) : r.subst ρ = r := by
  induction h with
  | bound hi => exact hf _ _ hi
  | loc _ => rfl
  | normal _ ih => exact ih

theorem LocalsFixed.empty (ρ) : LocalsFixed [] ρ := by intro i b h; cases h

theorem LocalsFixed.ext {Δ ρ} (h : LocalsFixed Δ ρ) (x) :
    LocalsFixed (LocalCtx.extend x Δ) (upLocalSubst 1 ρ) := by
  intro i b hi
  cases i with
  | zero => simp [upLocalSubst]
  | succ i =>
    simp only [LocalCtx.extend,List.getElem?_cons_succ,List.getElem?_map] at hi
    obtain ⟨y,hy,he⟩ := Option.map_eq_some_iff.mp hi
    cases y with
    | none => cases he
    | some c => simp [upLocalSubst,h i c hy,LocalRef.rename]

theorem LocalsFixed.many {Δ ρ} (h : LocalsFixed Δ ρ) (n : Nat) :
    LocalsFixed (localExtend n Δ) (upLocalSubst n ρ) := by
  induction n with
  | zero => simpa only [localExtend,upLocalSubst_zero] using h
  | succ n ih => simpa only [localExtend,upLocalSubst_add] using ih.ext none

mutual
  theorem HasTypeVQ.resolve_id {P B Ψ Q C Γ Φ v a} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (ρ) :
      v.resolveLocals ρ = v := by
    match h with
    | .V_Var .. | .V_Const .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef ..
    | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest ..
    | .V_CheckedAt .. | .V_AtError .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. =>
      simp only [Val.resolveLocals]
    | .V_Lam _ _ _ hb _ =>
      simp only [Val.resolveLocals,HasTypeCQ.resolve_id hb _ (LocalsFixed.empty _)]
    | .V_DependentLam _ hb =>
      simp only [Val.resolveLocals,TelBodyTy.resolve_id hb _]
    | .V_Map hk hv _ _ _ _ =>
      simp only [Val.resolveLocals,HasTypeEachQ.resolve_id hk,HasTypeEachQ.resolve_id hv]
    | .V_Set he _ _ => simp only [Val.resolveLocals,HasTypeEachQ.resolve_id he]
    | .V_Dict _ _ _ _ _ _ hv _ => simp only [Val.resolveLocals,HasTypeVsQ.resolve_id hv]
    | .V_Con _ _ _ _ hv _ => simp only [Val.resolveLocals,HasTypeVsQ.resolve_id hv]
    | .V_Super hv _ _ _ => simp only [Val.resolveLocals,HasTypeVQ.resolve_id hv]
    | .V_List he _ _ _ => simp only [Val.resolveLocals,HasTypeEachQ.resolve_id he]
    | .V_Normal hv => exact HasTypeVQ.resolve_id hv ρ
    | .V_Sub hv _ _ _ _ => exact HasTypeVQ.resolve_id hv ρ
    | .V_Refine hv _ _ _ _ _ _ _ => exact HasTypeVQ.resolve_id hv ρ
  termination_by structural h

  theorem HasTypeVsQ.resolve_id {P B Ψ Q C Γ Φ vs as} (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) (ρ) :
      Val.resolveLocalsList ρ vs = vs := by
    match h with
    | .nil => rfl
    | .cons hv hs => simp only [Val.resolveLocalsList,HasTypeVQ.resolve_id hv,HasTypeVsQ.resolve_id hs]
  termination_by structural h

  theorem HasTypeEachQ.resolve_id {P B Ψ Q C Γ Φ vs a} (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (ρ) :
      Val.resolveLocalsList ρ vs = vs := by
    match h with
    | .nil => rfl
    | .cons hv hs => simp only [Val.resolveLocalsList,HasTypeVQ.resolve_id hv,HasTypeEachQ.resolve_id hs]
  termination_by structural h

  theorem HasTypeCQ.resolve_id {P B Ψ Q C Γ Φ R m a e Δ} (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e Δ)
      (ρ) (hf : LocalsFixed Δ ρ) : m.resolveLocals ρ = m := by
    match h with
    | .C_BuilderLet _ _ hb _ =>
      simp only [Comp.resolveLocals,HasTypeCQ.resolve_id hb _ (hf.ext _)]
    | .C_BuilderOp _ _ hr hs =>
      simp only [Comp.resolveLocals,HasTypeVsQ.resolve_id hs]
      rw [hr.resolve_fixed hf]
    | .C_Return hv => simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv]
    | .C_Let hm hn _ =>
      simp only [Comp.resolveLocals,HasTypeCQ.resolve_id hm _ hf,HasTypeCQ.resolve_id hn _ (hf.many 1)]
    | .C_App hv hs => simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv,HasTypeVsQ.resolve_id hs]
    | .C_DependentApp hv hs =>
      simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv,HasTypeTelArgsQ.resolve_id hs]
    | .C_If hv ht hm hn =>
      simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv,HasTypeCQ.resolve_id hm _ hf,HasTypeCQ.resolve_id hn _ hf]
    | .C_Match hv _ ha _ =>
      simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv,HasTypeArmsQ.resolve_id ha _ hf]
    | .C_Lazy hm _ => simp only [Comp.resolveLocals,HasTypeCQ.resolve_id hm _ (LocalsFixed.empty _)]
    | .C_Escape hv _ => simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv]
    | .C_Use hv _ hm _ => simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv,HasTypeCQ.resolve_id hm _ hf]
    | .C_Handle hm _ hc =>
      simp only [Comp.resolveLocals,HasTypeCQ.resolve_id hm _ hf,HasTypeClausesQ.resolve_id hc]
    | .C_Handle_Fail hm _ _ hc =>
      simp only [Comp.resolveLocals,HasTypeCQ.resolve_id hm _ hf,HasFailureClause.resolve_id hc]
    | .C_Resume _ hv _ | .C_ResumeNorm _ hv _ => simp only [Comp.resolveLocals,Val.resolveLocals,HasTypeVQ.resolve_id hv]
    | .C_ResumeLNorm _ _ hv _ => simp only [Comp.resolveLocals,Val.resolveLocals,HasTypeVQ.resolve_id hv]
    | .C_ResumeL _ hv _ => simp only [Comp.resolveLocals,Val.resolveLocals,HasTypeVQ.resolve_id hv]
    | .C_Meth hv _ _ _ _ _ _ _ hs _ =>
      simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv,HasTypeVsQ.resolve_id hs]
    | .C_External _ _ _ hs => simp only [Comp.resolveLocals,HasTypeTelArgsQ.resolve_id hs]
    | .C_IssuePathBases .. => simp only [Comp.resolveLocals]
    | .C_CheckAt ha =>
      obtain ⟨h1,h2,h3⟩ := AtCallAdmissible.resolve_id (ρ := ρ) ha
      rename_i bs _ _ _
      cases bs with
      | none => simp only [Comp.resolveLocals,h2,h3]
      | some v => simp only [Comp.resolveLocals,h1 v rfl,h2,h3]
    | .C_Sub hm _ _ _ _ _ => exact HasTypeCQ.resolve_id hm ρ hf
    | .C_Normal hm => exact HasTypeCQ.resolve_id hm ρ hf
    | .C_Eff hm _ => exact HasTypeCQ.resolve_id hm ρ hf
  termination_by structural h

  theorem HasTypeTelArgsQ.resolve_id {P B Ψ Q C Γ Φ vs t a e}
      (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) (ρ) : Val.resolveLocalsList ρ vs = vs := by
    match h with
    | .done _ => rfl
    | .param _ hv hs => simp only [Val.resolveLocalsList,HasTypeVQ.resolve_id hv,HasTypeTelArgsQ.resolve_id hs]
  termination_by structural h

  theorem TelBodyTy.resolve_id {P B Ψ Q C Γ Φ t body} (h : TelBodyTy P B Ψ Q C Γ Φ t body) (ρ) :
      body.resolveLocals ρ = body := by
    match h with
    | .done hb => exact HasTypeCQ.resolve_id hb ρ (LocalsFixed.empty _)
    | .param hb => exact TelBodyTy.resolve_id hb ρ
  termination_by structural h

  theorem AtCallAdmissible.resolve_id {P B Ψ Q C Γ Φ kind name shape bases pattern input index ρ}
      (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
      (∀ v, bases = some v → v.resolveLocals ρ = v) ∧
      pattern.resolveLocals ρ = pattern ∧ input.resolveLocals ρ = input := by
    match h with
    | .mk (bases := bases) _ _ hb hp _ hi _ _ =>
      exact ⟨fun v hv => HasTypeVQ.resolve_id (hb v hv) ρ,HasTypeVQ.resolve_id hp ρ,HasTypeVQ.resolve_id hi ρ⟩

  theorem HasTypeArmsQ.resolve_id {P B Ψ Q C Γ Φ R obs arms a b e Δ}
      (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e Δ) (ρ) (hf : LocalsFixed Δ ρ) :
      Arm.resolveLocalsList ρ arms = arms := by
    match h with
    | .nil _ => rfl
    | .plain hp _ _ _ hb hs =>
      have hl := hp.2.1
      simp only [Arm.resolveLocalsList,←hl,HasTypeCQ.resolve_id hb _ (hf.many _),HasTypeArmsQ.resolve_id hs _ hf]
    | .guarded hp _ _ _ _ hg hb hs =>
      have hl := hp.2.1
      simp only [Arm.resolveLocalsList,←hl,HasTypeCQ.resolve_id hg _ (hf.many _),
        HasTypeCQ.resolve_id hb _ (hf.many _),HasTypeArmsQ.resolve_id hs _ hf]
  termination_by structural h

  theorem HasTypeClausesQ.resolve_id {P B Ψ Q C Γ Φ R eb cs t e Δ}
      (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e Δ) (ρ) : Clause.resolveLocalsList ρ cs = cs := by
    match h with
    | .nil => rfl
    | .cons _ _ _ _ _ hb hs =>
      simp only [Clause.resolveLocalsList,HasTypeCQ.resolve_id hb _ (LocalsFixed.empty _),HasTypeClausesQ.resolve_id hs]
  termination_by structural h

  theorem HasFailureClause.resolve_id {P B Ψ Q C Γ Φ E R cs t ec Δ}
      (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t ec Δ) (ρ) : Clause.resolveLocalsList ρ cs = cs := by
    match h with
    | .one _ _ _ hb =>
      simp only [Clause.resolveLocalsList,HasTypeCQ.resolve_id hb _ (LocalsFixed.empty _)]
end

/-- 値の型付けの閉包の本体も解決で変わらない。closeValの型付けと枠のhに使う形。 -/
theorem closeVal_resolved {P B Ψ Q C Γ Φ v a} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (cap ρ) :
    closeVal cap (v.resolveLocals ρ) = closeVal cap v := by rw [HasTypeVQ.resolve_id h ρ]


end
end Benitoite.Release.Refinement
