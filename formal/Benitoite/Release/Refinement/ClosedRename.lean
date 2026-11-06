import Benitoite.Release.Refinement.LocalInvariant

/-! # 閉じた値を束縛の下へ置くときの構文の一致と閉性 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem upRen_fixed {nv ξ} (h : ∀ i, i<nv → ξ i = i) (n : Nat) :
    ∀ i, i<nv+n → upRen n ξ i = i := by
  intro i hi
  by_cases hn : i<n
  · simp [upRen,hn]
  · simp only [upRen,hn,↓reduceIte]
    rw [h (i-n) (by omega)]; omega
private theorem type_rename_fixed {nt nv : Nat} {a : Ty} {ξ : Nat → Nat} (h : a.WF 0 nt nv) (hf : ∀ i, i<nv → ξ i = i) : renameTy ξ a = a := by
  rw [renameTy_eq_rawSubstV]
  exact Ty.rawSubstV_fixed h _ (fun i hi => by simp [hf i hi])
private theorem types_rename_fixed {nt nv : Nat} {ts : List Ty} {ξ : Nat → Nat} (h : ∀ a∈ts,a.WF 0 nt nv) (hf : ∀ i, i<nv → ξ i = i) :
    ts.map (renameTy ξ) = ts := by
  calc
    _ = ts.map id := List.map_congr_left (fun a ha => type_rename_fixed (h a ha) hf)
    _ = _ := List.map_id _
private theorem rows_rename_fixed {nt nv : Nat} {es : List Eff} {ξ : Nat → Nat} (h : ∀ e∈es,Eff.WF 0 nt nv e ∧ e.Canonical) (hf : ∀ i, i<nv → ξ i = i) :
    es.map (renameEff ξ) = es := by
  calc
    _ = es.map id := List.map_congr_left (fun e he => by
      rw [renameEff_eq_rawSubstV]
      exact Eff.rawSubstV_fixed (h e he).1 _ (fun i hi => by simp [hf i hi]))
    _ = _ := List.map_id _
private theorem tel_rename_fixed {nt nv : Nat} {t : Tel} {ξ : Nat → Nat} (h : Tel.WF 0 nt nv t) (hf : ∀ i, i<nv → ξ i = i) :
    Tel.rawBind (renEnv ξ) t = t := by
  change Tel.rawBind (SubstEnv.mk Ty.tvar [] [] (fun i => some (.var (ξ i)))) t = t
  rw [←Tel.rawSubstV_eq_rawBind]
  exact Tel.rawSubstV_fixed h _ (fun i hi => by simp [hf i hi])

mutual
  theorem Val.ClosedAt.rename_closed_scope {nt nv nv' : Nat} {v : Val} {ξ : Nat → Nat} (h : v.ClosedAt nt nv)
      (hle : nv ≤ nv') (hf : ∀ i, i<nv → ξ i = i) : v.rename ξ = v ∧ v.ClosedAt nt nv' := by
    cases v
    case var i => exact ⟨congrArg Val.var (hf i h),Nat.lt_of_lt_of_le h hle⟩
    case const | loc | bytesV | pathBases | scopePattern | checked | checkedRequest | atError | closure => exact ⟨rfl,h⟩
    case checkedAt r σ t req => cases req <;> exact ⟨rfl,h⟩
    case fnRef => exact ⟨by simp only [Val.rename,types_rename_fixed h.1 hf,rows_rename_fixed h.2.1 hf],
      (fun a ha => (h.1 a ha).weaken (Nat.le_refl _) hle),(fun e he => ⟨(h.2.1 e he).1.weaken (Nat.le_refl _) hle,(h.2.1 e he).2⟩),h.2.2⟩
    case prim => exact ⟨by simp only [Val.rename,types_rename_fixed h.1 hf,rows_rename_fixed h.2.1 hf],
      (fun a ha => (h.1 a ha).weaken (Nat.le_refl _) hle),(fun e he => ⟨(h.2.1 e he).1.weaken (Nat.le_refl _) hle,(h.2.1 e he).2⟩),h.2.2⟩
    case externalRef | externalHandle | op => exact ⟨by simp only [Val.rename,types_rename_fixed h hf],fun a ha => (h a ha).weaken (Nat.le_refl _) hle⟩
    case raise a e => exact ⟨by simp only [Val.rename,type_rename_fixed h.1 hf,type_rename_fixed h.2 hf],h.1.weaken (Nat.le_refl _) hle,h.2.weaken (Nat.le_refl _) hle⟩
    case con n ts vs =>
      have hh := Val.ClosedList.rename_closed_scope h.2 hle hf
      exact ⟨by simp only [Val.rename,types_rename_fixed h.1 hf,hh.1],(fun a ha => (h.1 a ha).weaken (Nat.le_refl _) hle),hh.2⟩
    case dict n ts vs =>
      have hh := Val.ClosedList.rename_closed_scope h.2 hle hf
      exact ⟨by simp only [Val.rename,types_rename_fixed h.1 hf,hh.1],(fun a ha => (h.1 a ha).weaken (Nat.le_refl _) hle),hh.2⟩
    case list vs | setV vs =>
      have hh := Val.ClosedList.rename_closed_scope h hle hf
      exact ⟨by simp only [Val.rename,hh.1],hh.2⟩
    case mapV ks vs =>
      have hk := Val.ClosedList.rename_closed_scope h.1 hle hf
      have hv := Val.ClosedList.rename_closed_scope h.2 hle hf
      exact ⟨by simp only [Val.rename,hk.1,hv.1],hk.2,hv.2⟩
    case super v cl =>
      have hh := Val.ClosedAt.rename_closed_scope (v := v) h hle hf
      exact ⟨by simp only [Val.rename,hh.1],hh.2⟩
    case lam ns ps body =>
      have hb := Comp.ClosedAt.rename_closed_scope h.2.2 (Nat.add_le_add_right hle _) (upRen_fixed hf ps.length)
      exact ⟨by simp only [Val.rename,types_rename_fixed h.2.1 hf,hb.1],h.1,(fun a ha => (h.2.1 a ha).weaken (Nat.le_refl _) hle),hb.2⟩
    case dependentLam t body =>
      have hb := Comp.ClosedAt.rename_closed_scope h.2 (Nat.add_le_add_right hle _) (upRen_fixed hf (telBinders t))
      exact ⟨by simp only [Val.rename,tel_rename_fixed h.1 hf,hb.1],h.1.weaken (Nat.le_refl _) hle,hb.2⟩
  termination_by structural v
  theorem Val.ClosedList.rename_closed_scope {nt nv nv' : Nat} {vs : List Val} {ξ : Nat → Nat} (h : Val.ClosedList nt nv vs)
      (hle : nv ≤ nv') (hf : ∀ i, i<nv → ξ i = i) : Val.renameList ξ vs = vs ∧ Val.ClosedList nt nv' vs := by
    cases vs with
    | nil => exact ⟨rfl,trivial⟩
    | cons v vs =>
      have hv := Val.ClosedAt.rename_closed_scope h.1 hle hf
      have hs := Val.ClosedList.rename_closed_scope h.2 hle hf
      exact ⟨by simp only [Val.renameList,hv.1,hs.1],hv.2,hs.2⟩
  termination_by structural vs
  theorem Comp.ClosedAt.rename_closed_scope {nt nv nv' : Nat} {m : Comp} {ξ : Nat → Nat} (h : m.ClosedAt nt nv)
      (hle : nv ≤ nv') (hf : ∀ i, i<nv → ξ i = i) : m.rename ξ = m ∧ m.ClosedAt nt nv' := by
    cases m
    case builderLet kind body =>
      have hb := Comp.ClosedAt.rename_closed_scope h.2 (Nat.add_le_add_right hle _) (upRen_fixed hf 1)
      cases kind <;> simp only [Comp.rename,renameKind,Comp.ClosedAt] at *
      · exact ⟨by rw [hb.1],trivial,hb.2⟩
      · exact ⟨by rw [type_rename_fixed h.1 hf,hb.1],h.1.weaken (Nat.le_refl _) hle,hb.2⟩
      · exact ⟨by rw [hb.1],trivial,hb.2⟩
    case builderOp kind op r vs =>
      have hs := Val.ClosedList.rename_closed_scope h.2.2 hle hf
      have hr : r.rename ξ = r := by cases r with | loc => rfl | bound i => exact congrArg LocalRef.bound (hf i h.2.1)
      cases kind <;> simp only [Comp.rename,renameKind,Comp.ClosedAt] at *
      · exact ⟨by rw [hr,hs.1],trivial,(by cases r with | loc => trivial | bound i => exact Nat.lt_of_lt_of_le h.2.1 hle),hs.2⟩
      · exact ⟨by rw [type_rename_fixed h.1 hf,hr,hs.1],h.1.weaken (Nat.le_refl _) hle,(by cases r with | loc => trivial | bound i => exact Nat.lt_of_lt_of_le h.2.1 hle),hs.2⟩
      · exact ⟨by rw [hr,hs.1],trivial,(by cases r with | loc => trivial | bound i => exact Nat.lt_of_lt_of_le h.2.1 hle),hs.2⟩
    case ret v | escape v =>
      have hh := Val.ClosedAt.rename_closed_scope h hle hf
      exact ⟨by simp only [Comp.rename,hh.1],hh.2⟩
    case letIn m n =>
      have hm := Comp.ClosedAt.rename_closed_scope h.1 hle hf
      have hn := Comp.ClosedAt.rename_closed_scope h.2 (Nat.add_le_add_right hle _) (upRen_fixed hf 1)
      exact ⟨by simp only [Comp.rename,hm.1,hn.1],hm.2,hn.2⟩
    case app f vs =>
      have hv := Val.ClosedAt.rename_closed_scope h.1 hle hf
      have hs := Val.ClosedList.rename_closed_scope h.2 hle hf
      exact ⟨by simp only [Comp.rename,hv.1,hs.1],hv.2,hs.2⟩
    case ite v m n =>
      have hv := Val.ClosedAt.rename_closed_scope h.1 hle hf
      have hm := Comp.ClosedAt.rename_closed_scope h.2.1 hle hf
      have hn := Comp.ClosedAt.rename_closed_scope h.2.2 hle hf
      exact ⟨by simp only [Comp.rename,hv.1,hm.1,hn.1],hv.2,hm.2,hn.2⟩
    case «match» v arms =>
      have hv := Val.ClosedAt.rename_closed_scope h.1 hle hf
      have ha := Arm.ClosedList.rename_closed_scope h.2 hle hf
      exact ⟨by simp only [Comp.rename,hv.1,ha.1],hv.2,ha.2⟩
    case lazyC m =>
      have hm := Comp.ClosedAt.rename_closed_scope (m := m) h hle hf
      exact ⟨by simp only [Comp.rename,hm.1],hm.2⟩
    case use v m | resume v m =>
      first
      | (have hv := Val.ClosedAt.rename_closed_scope h.1 hle hf
         have hm := Comp.ClosedAt.rename_closed_scope h.2 hle hf
         exact ⟨by simp only [Comp.rename,hv.1,hm.1],hv.2,hm.2⟩)
      | (have hv := Val.ClosedAt.rename_closed_scope h.1 hle hf
         have hm := Val.ClosedAt.rename_closed_scope h.2 hle hf
         exact ⟨by simp only [Comp.rename,hv.1,hm.1],hv.2,hm.2⟩)
    case handle m cs =>
      have hm := Comp.ClosedAt.rename_closed_scope h.1 hle hf
      have hs := Clause.ClosedList.rename_closed_scope h.2 hle hf
      exact ⟨by simp only [Comp.rename,hm.1,hs.1],hm.2,hs.2⟩
    case meth v m ts es vs =>
      have hv := Val.ClosedAt.rename_closed_scope h.1 hle hf
      have hs := Val.ClosedList.rename_closed_scope h.2.2.2 hle hf
      exact ⟨by simp only [Comp.rename,hv.1,types_rename_fixed h.2.1 hf,rows_rename_fixed h.2.2.1 hf,hs.1],hv.2,
        (fun a ha => (h.2.1 a ha).weaken (Nat.le_refl _) hle),
        (fun e he => ⟨(h.2.2.1 e he).1.weaken (Nat.le_refl _) hle,(h.2.2.1 e he).2⟩),hs.2⟩
    case externalCall f ts vs =>
      have hs := Val.ClosedList.rename_closed_scope h.2 hle hf
      exact ⟨by simp only [Comp.rename,types_rename_fixed h.1 hf,hs.1],(fun a ha => (h.1 a ha).weaken (Nat.le_refl _) hle),hs.2⟩
    case issuePathBases => exact ⟨rfl,trivial⟩
    case checkAt k o sh bs p v ix =>
      cases bs with
      | none =>
        have hp := Val.ClosedAt.rename_closed_scope h.2.2.2.1 hle hf
        have hv := Val.ClosedAt.rename_closed_scope h.2.2.2.2 hle hf
        exact ⟨by simp only [Comp.rename,type_rename_fixed h.1 hf,hp.1,hv.1],h.1.weaken (Nat.le_refl _) hle,h.2.1,trivial,hp.2,hv.2⟩
      | some b =>
        have hp := Val.ClosedAt.rename_closed_scope h.2.2.2.1 hle hf
        have hv := Val.ClosedAt.rename_closed_scope h.2.2.2.2 hle hf
        have hb := Val.ClosedAt.rename_closed_scope h.2.2.1 hle hf
        exact ⟨by simp only [Comp.rename,type_rename_fixed h.1 hf,hb.1,hp.1,hv.1],h.1.weaken (Nat.le_refl _) hle,h.2.1,hb.2,hp.2,hv.2⟩

  termination_by structural m
  theorem Arm.ClosedList.rename_closed_scope {nt nv nv' : Nat} {arms : List Arm} {ξ : Nat → Nat} (h : Arm.ClosedList nt nv arms)
      (hle : nv ≤ nv') (hf : ∀ i, i<nv → ξ i = i) : Arm.renameList ξ arms = arms ∧ Arm.ClosedList nt nv' arms := by
    cases arms with
    | nil => exact ⟨rfl,trivial⟩
    | cons arm arms => cases arm with
      | mk alts guard body =>
        cases guard with
        | none =>
          have hb := Comp.ClosedAt.rename_closed_scope h.2.1 (Nat.add_le_add_right hle _) (upRen_fixed hf _)
          have hs := Arm.ClosedList.rename_closed_scope h.2.2 hle hf
          exact ⟨by simp only [Arm.renameList,hb.1,hs.1],trivial,hb.2,hs.2⟩
        | some g =>
          have hb := Comp.ClosedAt.rename_closed_scope h.2.1 (Nat.add_le_add_right hle _) (upRen_fixed hf _)
          have hs := Arm.ClosedList.rename_closed_scope h.2.2 hle hf
          have hg := Comp.ClosedAt.rename_closed_scope h.1 (Nat.add_le_add_right hle _) (upRen_fixed hf _)
          exact ⟨by simp only [Arm.renameList,hg.1,hb.1,hs.1],hg.2,hb.2,hs.2⟩

  termination_by structural arms
  theorem Clause.ClosedList.rename_closed_scope {nt nv nv' : Nat} {cs : List Clause} {ξ : Nat → Nat} (h : Clause.ClosedList nt nv cs)
      (hle : nv ≤ nv') (hf : ∀ i, i<nv → ξ i = i) : Clause.renameList ξ cs = cs ∧ Clause.ClosedList nt nv' cs := by
    cases cs with
    | nil => exact ⟨rfl,trivial⟩
    | cons c cs =>
      cases c with
      | mk o n k m =>
        have hs := Clause.ClosedList.rename_closed_scope h.2 hle hf
        have hb := Comp.ClosedAt.rename_closed_scope (nv' := nv'+n+1) h.1 (by omega)
          (by simpa only [Nat.add_assoc] using upRen_fixed hf (n+1))
        exact ⟨by simp only [Clause.renameList,hb.1,hs.1],hb.2,hs.2⟩
      | fail e m =>
        have hs := Clause.ClosedList.rename_closed_scope h.2.2 hle hf
        have hb := Comp.ClosedAt.rename_closed_scope (nv' := nv'+2) h.2.1 (by omega) (upRen_fixed hf 2)
        exact ⟨by simp only [Clause.renameList,type_rename_fixed h.1 hf,hb.1,hs.1],h.1.weaken (Nat.le_refl _) hle,hb.2,hs.2⟩
  termination_by structural cs
end
end
end Benitoite.Release.Refinement
