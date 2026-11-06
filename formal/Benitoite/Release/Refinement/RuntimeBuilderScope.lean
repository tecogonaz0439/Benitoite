import Benitoite.Release.Refinement.HandlerGeneral

/-! # 構築器の束縛を取り除く置換による閉性と保持値の適格性 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem builder_env_wf (nt nv c : Nat) (hc : c ≤ nv) :
    (valEnv (upSubst c builderValueSubst)).WFImages 0 nt (nv+1) 0 nt nv := by
  constructor
  · intro i hi; exact hi
  · intro e he; cases he
  · intro ix hi; cases ix <;> exact hi
  · intro i hi t ht
    change ((upSubst c builderValueSubst) i).toTerm? = some t at ht
    unfold upSubst at ht
    split at ht
    · cases ht; exact Nat.lt_of_lt_of_le ‹i < c› hc
    · rename_i hn
      cases hh : i-c with
      | zero => simp only [hh,builderValueSubst,Val.rename,Val.toTerm?,Option.some.injEq] at ht
                subst t; trivial
      | succ j =>
        simp only [hh,builderValueSubst,Val.rename,Val.toTerm?,Option.some.injEq] at ht
        subst t
        change j+c < nv
        omega
  · intro i; simp [valEnv,Ordinary,Ty.core]

private theorem builder_type_wf {nt nv c a} (hc : c ≤ nv) (h : a.WF 0 nt (nv+1)) :
    (substTyValues (upSubst c builderValueSubst) a).WF 0 nt nv :=
  Ty.bind_wf a h (builder_env_wf nt nv c hc)

private theorem builder_types_wf {nt nv c : Nat} {as : List Ty} (hc : c ≤ nv)
    (h : ∀ a ∈ as, a.WF 0 nt (nv+1)) :
    ∀ a ∈ as.map (substTyValues (upSubst c builderValueSubst)), a.WF 0 nt nv := by
  intro a ha; obtain ⟨t,ht,rfl⟩ := List.mem_map.mp ha
  exact builder_type_wf hc (h t ht)

private theorem builder_rows_wf {nt nv c : Nat} {es : List Eff} (hc : c ≤ nv)
    (h : ∀ e ∈ es, Eff.WF 0 nt (nv+1) e ∧ e.Canonical) :
    ∀ e ∈ es.map (substEffValues (upSubst c builderValueSubst)), Eff.WF 0 nt nv e ∧ e.Canonical := by
  intro e he; obtain ⟨f,hf,rfl⟩ := List.mem_map.mp he
  exact ⟨Eff.bind_wf f (h f hf).1 (builder_env_wf nt nv c hc),Eff.norm_idem _⟩

private theorem builder_var_scope {nt nv c i} {σ : PathEnv} (hc : c ≤ nv) (hi : i < nv+1) :
    ((upSubst c builderValueSubst) i).ClosedAt nt nv ∧ ((upSubst c builderValueSubst) i).Adequate σ := by
  unfold upSubst
  split
  · exact ⟨Nat.lt_of_lt_of_le ‹i < c› hc,trivial⟩
  · cases hh : i-c with
    | zero => exact ⟨trivial,trivial⟩
    | succ j =>
      simp only [builderValueSubst,Val.rename,Val.ClosedAt,Val.Adequate]
      exact ⟨by omega,trivial⟩
private theorem builder_local_scope {nv c l} (hc : c ≤ nv) {ref : LocalRef}
    (h : match ref with | .bound i => i < nv+1 | .loc _ => True) :
    (match ref.subst (upLocalSubst c (builderLocalSubst l)) with | .bound i => i < nv | .loc _ => True) := by
  cases ref with
  | loc => trivial
  | bound i =>
    change i < nv+1 at h
    by_cases hi : i < c
    · simpa only [LocalRef.subst,upLocalSubst,hi,↓reduceIte] using Nat.lt_of_lt_of_le hi hc
    · simp only [LocalRef.subst,upLocalSubst,hi,↓reduceIte]
      cases hh : i-c with
      | zero => trivial
      | succ j =>
        change j+c < nv
        omega

mutual
  theorem Val.ClosedAt.builder_subst_scope {nt nv c l : Nat} {v : Val}
      (h : v.ClosedAt nt (nv+1)) {σ : PathEnv} (had : v.Adequate σ)
      (hc : c ≤ nv) :
      (v.subst (upSubst c builderValueSubst) (upLocalSubst c (builderLocalSubst l))).ClosedAt nt nv ∧ (v.subst (upSubst c builderValueSubst) (upLocalSubst c (builderLocalSubst l))).Adequate σ := by
    cases v
    case var i => exact builder_var_scope hc h
    case const => exact ⟨h,had⟩
    case loc => exact ⟨h,had⟩
    case bytesV => exact ⟨h,had⟩
    case checked => exact ⟨h,had⟩
    case pathBases => exact ⟨h,had⟩
    case scopePattern => exact ⟨h,had⟩
    case atError => exact ⟨h,had⟩
    case checkedAt r snapshot target req => cases req <;> exact ⟨h,had⟩
    case checkedRequest => exact ⟨h,had⟩
    case closure => exact ⟨h,had⟩
    case fnRef => exact ⟨⟨builder_types_wf hc h.1,builder_rows_wf hc h.2.1,h.2.2⟩,trivial⟩
    case prim => exact ⟨⟨builder_types_wf hc h.1,builder_rows_wf hc h.2.1,h.2.2⟩,trivial⟩
    case externalRef => exact ⟨builder_types_wf hc h,trivial⟩
    case externalHandle => exact ⟨builder_types_wf hc h,trivial⟩
    case op => exact ⟨builder_types_wf hc h,trivial⟩
    case raise => exact ⟨⟨builder_type_wf hc h.1,builder_type_wf hc h.2⟩,trivial⟩
    case con n as vs =>
      have hh := builder_values_scope (l := l) h.2 had hc
      exact ⟨⟨builder_types_wf hc h.1,hh.1⟩,hh.2⟩
    case dict n as vs =>
      have hh := builder_values_scope (l := l) h.2 had hc
      exact ⟨⟨builder_types_wf hc h.1,hh.1⟩,hh.2⟩
    case list vs => exact builder_values_scope (l := l) h had hc
    case setV vs => exact builder_values_scope (l := l) h had hc
    case mapV ks vs =>
      have hk := builder_values_scope (l := l) h.1 had.1 hc
      have hv := builder_values_scope (l := l) h.2 had.2 hc
      exact ⟨⟨hk.1,hv.1⟩,hk.2,hv.2⟩
    case super v s => exact Val.ClosedAt.builder_subst_scope (l := l) (v := v) h had hc
    case lam ns ps body =>
      have hb := Comp.ClosedAt.builder_subst_scope (l := l) (c := c+ps.length) (nv := nv+ps.length)
        (by simpa only [Nat.add_right_comm] using h.2.2) had (by omega)
      simpa only [Val.subst,upSubst_add,upLocalSubst_add,
        List.length_map,Val.ClosedAt,Val.Adequate] using
        And.intro (And.intro (show NamesWF ns (ps.map (substTyValues (upSubst c builderValueSubst))) from
          ⟨by simpa only [List.length_map] using h.1.1,h.1.2⟩)
          (And.intro (builder_types_wf hc h.2.1) hb.1)) hb.2
    case dependentLam t body =>
      have hb := Comp.ClosedAt.builder_subst_scope (l := l) (c := c+telBinders t) (nv := nv+telBinders t)
        (by simpa only [Nat.add_right_comm] using h.2) had (by omega)
      have hw := Tel.bind_wf t h.1 (builder_env_wf nt nv c hc)
      simpa only [Val.subst,upSubst_add,upLocalSubst_add,
        Val.ClosedAt,Val.Adequate,telBinders_bind] using And.intro (And.intro hw hb.1) hb.2
  termination_by structural v
  theorem builder_values_scope {nt nv c l : Nat} {vs : List Val}
      (h : Val.ClosedList nt (nv+1) vs) {σ : PathEnv} (had : adequateVals σ vs)
      (hc : c ≤ nv) :
      Val.ClosedList nt nv (Val.substList (upSubst c builderValueSubst) vs (upLocalSubst c (builderLocalSubst l))) ∧ adequateVals σ (Val.substList (upSubst c builderValueSubst) vs (upLocalSubst c (builderLocalSubst l))) := by
    cases vs with
    | nil => exact ⟨trivial,trivial⟩
    | cons v vs =>
      have hv := Val.ClosedAt.builder_subst_scope (l := l) h.1 had.1 hc
      have hs := builder_values_scope (l := l) h.2 had.2 hc
      exact ⟨⟨hv.1,hs.1⟩,hv.2,hs.2⟩
  termination_by structural vs
  theorem Comp.ClosedAt.builder_subst_scope {nt nv c l : Nat} {m : Comp}
      (h : m.ClosedAt nt (nv+1)) {σ : PathEnv} (had : m.Adequate σ)
      (hc : c ≤ nv) :
      (m.subst (upSubst c builderValueSubst) (upLocalSubst c (builderLocalSubst l))).ClosedAt nt nv ∧ (m.subst (upSubst c builderValueSubst) (upLocalSubst c (builderLocalSubst l))).Adequate σ := by
    cases m
    case ret v => exact Val.ClosedAt.builder_subst_scope (l := l) h had hc
    case escape v => exact Val.ClosedAt.builder_subst_scope (l := l) h had hc
    case app f vs =>
      have hf := Val.ClosedAt.builder_subst_scope (l := l) h.1 had.1 hc
      have hvs := builder_values_scope (l := l) h.2 had.2 hc
      exact ⟨⟨hf.1,hvs.1⟩,hf.2,hvs.2⟩
    case letIn m n =>
      have hm := Comp.ClosedAt.builder_subst_scope (l := l) h.1 had.1 hc
      have hn := Comp.ClosedAt.builder_subst_scope (l := l) (c := c+1) (nv := nv+1) h.2 had.2 (by omega)
      simpa only [Comp.subst,upSubst_add,upLocalSubst_add,
        Comp.ClosedAt,Comp.Adequate] using And.intro (And.intro hm.1 hn.1) (And.intro hm.2 hn.2)
    case ite v m n =>
      have hv := Val.ClosedAt.builder_subst_scope (l := l) h.1 had.1 hc
      have hm := Comp.ClosedAt.builder_subst_scope (l := l) h.2.1 had.2.1 hc
      have hn := Comp.ClosedAt.builder_subst_scope (l := l) h.2.2 had.2.2 hc
      exact ⟨⟨hv.1,hm.1,hn.1⟩,hv.2,hm.2,hn.2⟩
    case «match» v arms =>
      have hv := Val.ClosedAt.builder_subst_scope (l := l) h.1 had.1 hc
      have ha := builder_arms_scope (l := l) h.2 had.2 hc
      exact ⟨⟨hv.1,ha.1⟩,hv.2,ha.2⟩
    case lazyC m => exact Comp.ClosedAt.builder_subst_scope (l := l) (m := m) h had hc
    case use v m =>
      have hv := Val.ClosedAt.builder_subst_scope (l := l) h.1 had.1 hc
      have hm := Comp.ClosedAt.builder_subst_scope (l := l) h.2 had.2 hc
      exact ⟨⟨hv.1,hm.1⟩,hv.2,hm.2⟩
    case handle m cs =>
      have hm := Comp.ClosedAt.builder_subst_scope (l := l) h.1 had.1 hc
      have hc := builder_clauses_scope (l := l) h.2 had.2 hc
      exact ⟨⟨hm.1,hc.1⟩,hm.2,hc.2⟩
    case resume k v =>
      have hk := Val.ClosedAt.builder_subst_scope (l := l) h.1 had.1 hc
      have hv := Val.ClosedAt.builder_subst_scope (l := l) h.2 had.2 hc
      exact ⟨⟨hk.1,hv.1⟩,hk.2,hv.2⟩
    case externalCall f as vs =>
      have hv := builder_values_scope (l := l) h.2 had hc
      exact ⟨⟨builder_types_wf hc h.1,hv.1⟩,hv.2⟩
    case issuePathBases => exact ⟨h,had⟩
    case meth v name as fs vs =>
      have hv := Val.ClosedAt.builder_subst_scope (l := l) h.1 had.1 hc
      have hvs := builder_values_scope (l := l) h.2.2.2 had.2 hc
      exact ⟨⟨hv.1,builder_types_wf hc h.2.1,builder_rows_wf hc h.2.2.1,hvs.1⟩,hv.2,hvs.2⟩
    case builderLet kind body =>
      have hb := Comp.ClosedAt.builder_subst_scope (l := l) (c := c+1) (nv := nv+1) h.2 had (by omega)
      cases kind <;> simp only [Comp.subst,upSubst_add,upLocalSubst_add,
        Comp.ClosedAt,Comp.Adequate,substKind] <;> exact ⟨⟨by first | trivial | exact builder_type_wf hc h.1,hb.1⟩,hb.2⟩
    case builderOp kind op ref vs =>
      have hv := builder_values_scope (l := l) h.2.2 had hc
      have href := builder_local_scope (l := l) hc (ref := ref) h.2.1
      cases kind <;> exact ⟨⟨by first | trivial | exact builder_type_wf hc h.1,href,hv.1⟩,hv.2⟩
    case checkAt k o sh bs p v ix =>
      cases bs
      all_goals
        have hp := Val.ClosedAt.builder_subst_scope (l := l) h.2.2.2.1 had.2.1 hc
        have hv := Val.ClosedAt.builder_subst_scope (l := l) h.2.2.2.2 had.2.2 hc
        first
        | exact ⟨⟨builder_type_wf hc h.1,h.2.1,trivial,hp.1,hv.1⟩,trivial,hp.2,hv.2⟩
        | skip
      case some b =>
          have hp := Val.ClosedAt.builder_subst_scope (l := l) h.2.2.2.1 had.2.1 hc
          have hv := Val.ClosedAt.builder_subst_scope (l := l) h.2.2.2.2 had.2.2 hc
          have hb := Val.ClosedAt.builder_subst_scope (l := l) h.2.2.1 had.1 hc
          exact ⟨⟨builder_type_wf hc h.1,h.2.1,hb.1,hp.1,hv.1⟩,hb.2,hp.2,hv.2⟩
  termination_by structural m
  theorem builder_arms_scope {nt nv c l : Nat} {arms : List Arm}
      (h : Arm.ClosedList nt (nv+1) arms) {σ : PathEnv} (had : adequateArms σ arms)
      (hc : c ≤ nv) :
      Arm.ClosedList nt nv (Arm.substList (upSubst c builderValueSubst) arms (upLocalSubst c (builderLocalSubst l))) ∧ adequateArms σ (Arm.substList (upSubst c builderValueSubst) arms (upLocalSubst c (builderLocalSubst l))) := by
    cases arms with
    | nil => exact ⟨trivial,trivial⟩
    | cons a arms =>
      cases a with
      | mk alts guard body =>
        cases guard with
        | none =>
          have hb := Comp.ClosedAt.builder_subst_scope (l := l) (c := c+Benitoite.Release.Arm.bindersOf alts) (nv := nv+Benitoite.Release.Arm.bindersOf alts)
            (by simpa only [Nat.add_right_comm] using h.2.1) had.2.1 (by omega)
          have hs := builder_arms_scope (l := l) h.2.2 had.2.2 hc
          simpa only [Arm.substList,upSubst_add,upLocalSubst_add,
            Arm.ClosedList,adequateArms] using And.intro (And.intro trivial (And.intro hb.1 hs.1))
              (And.intro trivial (And.intro hb.2 hs.2))
        | some g =>
          have hb := Comp.ClosedAt.builder_subst_scope (l := l) (c := c+Benitoite.Release.Arm.bindersOf alts) (nv := nv+Benitoite.Release.Arm.bindersOf alts)
            (by simpa only [Nat.add_right_comm] using h.2.1) had.2.1 (by omega)
          have hs := builder_arms_scope (l := l) h.2.2 had.2.2 hc
          have hg := Comp.ClosedAt.builder_subst_scope (l := l) (c := c+Benitoite.Release.Arm.bindersOf alts) (nv := nv+Benitoite.Release.Arm.bindersOf alts)
            (by simpa only [Nat.add_right_comm] using h.1) had.1 (by omega)
          simpa only [Arm.substList,upSubst_add,upLocalSubst_add,
            Arm.ClosedList,adequateArms] using And.intro (And.intro hg.1 (And.intro hb.1 hs.1))
              (And.intro hg.2 (And.intro hb.2 hs.2))
  termination_by structural arms
  theorem builder_clauses_scope {nt nv c l : Nat} {cs : List Clause}
      (h : Clause.ClosedList nt (nv+1) cs) {σ : PathEnv} (had : adequateClauses σ cs)
      (hc : c ≤ nv) :
      Clause.ClosedList nt nv (Clause.substList (upSubst c builderValueSubst) cs (upLocalSubst c (builderLocalSubst l))) ∧ adequateClauses σ (Clause.substList (upSubst c builderValueSubst) cs (upLocalSubst c (builderLocalSubst l))) := by
    cases cs with
    | nil => exact ⟨trivial,trivial⟩
    | cons cl cs =>
      cases cl with
      | mk o n k m =>
        have hm := Comp.ClosedAt.builder_subst_scope (l := l) (nt := nt+k) (c := c+(n+1)) (nv := nv+(n+1))
          (by
            have heq : nv + (n+1) + 1 = nv + 1 + n + 1 := by omega
            rw [heq]; exact h.1) had.1 (by omega)
        have hs := builder_clauses_scope (l := l) h.2 had.2 hc
        simpa only [Clause.substList,builderImages_shiftE,upSubst_add,upLocalSubst_add,
          Clause.ClosedList,adequateClauses,Nat.add_assoc] using And.intro (And.intro hm.1 hs.1) (And.intro hm.2 hs.2)
      | fail e m =>
        have hm := Comp.ClosedAt.builder_subst_scope (l := l) (nt := nt+1) (c := c+2) (nv := nv+2)
          (by simpa only [Nat.add_right_comm] using h.2.1) had.1 (by omega)
        have hs := builder_clauses_scope (l := l) h.2.2 had.2 hc
        simpa only [Clause.substList,builderImages_shiftE,upSubst_add,upLocalSubst_add,
          Clause.ClosedList,adequateClauses,substTyValues] using And.intro
            (And.intro (builder_type_wf hc h.1) (And.intro hm.1 hs.1)) (And.intro hm.2 hs.2)
  termination_by structural cs
end
end
end Benitoite.Release.Refinement
