import Benitoite.Release.Refinement.StateTyping

/-! 型付きのコードは、局所文脈の外の参照を持たないので、解決で変わらない。 -/
namespace Benitoite.Release.Refinement
noncomputable section

def LocalsFixed (Δ : LocalCtx) (ρ : Nat → LocalRef) : Prop :=
  ∀ i b, Δ[i]? = some (some b) → ρ i = .bound i

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
      cases hr with
      | bound hi => simp only [LocalRef.subst,hf _ _ hi]
      | loc _ => rfl
    | .C_Return hv => simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv]
    | .C_Let hm hn _ =>
      simp only [Comp.resolveLocals,HasTypeCQ.resolve_id hm _ hf,HasTypeCQ.resolve_id hn _ (hf.many 1)]
    | .C_App hv hs => simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv,HasTypeVsQ.resolve_id hs]
    | .C_DependentApp hv hs =>
      simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv,HasTypeTelArgsQ.resolve_id hs]
    | .C_If hv hm hn =>
      simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv,HasTypeCQ.resolve_id hm _ hf,HasTypeCQ.resolve_id hn _ hf]
    | .C_Match hv ha _ =>
      simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv,HasTypeArmsQ.resolve_id ha _ hf]
    | .C_Lazy hm _ => simp only [Comp.resolveLocals,HasTypeCQ.resolve_id hm _ (LocalsFixed.empty _)]
    | .C_Escape hv _ => simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv]
    | .C_Use hv _ hm _ => simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv,HasTypeCQ.resolve_id hm _ hf]
    | .C_Handle hm _ hc =>
      simp only [Comp.resolveLocals,HasTypeCQ.resolve_id hm _ hf,HasTypeClausesQ.resolve_id hc]
    | .C_Handle_Fail hm _ _ hc =>
      simp only [Comp.resolveLocals,HasTypeCQ.resolve_id hm _ hf,HasFailureClause.resolve_id hc]
    | .C_Resume _ hv _ => simp only [Comp.resolveLocals,Val.resolveLocals,HasTypeVQ.resolve_id hv]
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

  theorem HasTypeArmsQ.resolve_id {P B Ψ Q C Γ Φ R arms a b e Δ}
      (h : HasTypeArmsQ P B Ψ Q C Γ Φ R arms a b e Δ) (ρ) (hf : LocalsFixed Δ ρ) :
      Arm.resolveLocalsList ρ arms = arms := by
    match h with
    | .nil _ => rfl
    | .plain hp hb hs =>
      have hl := hp.2.1
      simp only [Arm.resolveLocalsList,←hl,HasTypeCQ.resolve_id hb _ (hf.many _),HasTypeArmsQ.resolve_id hs _ hf]
    | .guarded hp hg hb hs =>
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

#print axioms HasTypeVQ.resolve_id
#print axioms HasTypeCQ.resolve_id
#print axioms HasTypeClausesQ.resolve_id
end
end Benitoite.Release.Refinement
