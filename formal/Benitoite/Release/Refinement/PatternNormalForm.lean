import Benitoite.Release.Refinement.ValueMeaning
import Benitoite.Release.Refinement.BindCongr

namespace Benitoite.Release.Refinement
noncomputable section

theorem RefinementPossible.conjuncts (p : Pred) (v : Val) :
    RefinementPossible p v ↔ ∀ q ∈ p.conjuncts, RefinementPossible q v := by
  induction p with
  | truth => simp [Pred.conjuncts,RefinementPossible,Pred.evalWith,Pred.atomReady,Pred.atomValue]
  | and p q ihp ihq =>
    simp only [Pred.conjuncts,List.mem_append,or_imp,forall_and,←ihp,←ihq]
    unfold RefinementPossible
    cases hp : p.evalWith (selfModel (fun _ => none) v) with
    | none => cases hq : q.evalWith (selfModel (fun _ => none) v) with
      | none => simp [Pred.evalWith,hp,hq]
      | some b => cases b <;> simp [Pred.evalWith,hp,hq]
    | some b => cases b <;> cases hq : q.evalWith (selfModel (fun _ => none) v) with
      | none => simp [Pred.evalWith,hp,hq]
      | some c => cases c <;> simp [Pred.evalWith,hp,hq]
  | _ => simp only [Pred.conjuncts,List.mem_singleton,forall_eq]

theorem Inhabits.core {P a v} (h : Inhabits P a v) : Inhabits P a.core v := by
  match h with
  | .refined hs _ => exact hs.core
  | .const (c := c) => cases c <;> exact .const
  | .con hc hn hw hs => exact .con hc hn hw hs
  | .atError hs => exact .atError hs
  | .list hs => exact .list hs
  | .fn => exact .fn
  | .dependentFn => exact .dependentFn
  | .tvar => exact .tvar
  | .reference => exact .reference
  | .lazy => exact .lazy
  | .cont => exact .cont
  | .map => exact .map
  | .set => exact .set
  | .bytes => exact .bytes
  | .dict => exact .dict
  | .tapp => exact .tapp
  | .ctor => exact .ctor
  | .external => exact .external
  | .scoped => exact .scoped
  | .pathBases => exact .pathBases
  | .scopePattern => exact .scopePattern
  | .checked => exact .checked
  | .checkedRequest => exact .checkedRequest
  | .checkedAtOpaque => exact .checkedAtOpaque

theorem Inhabits.predicates {P a v} (h : Inhabits P a v) :
    ∀ p ∈ a.refinementPredicates, RefinementPossible p v := by
  match h with
  | .refined hs hp =>
    intro q hq
    rcases List.mem_append.mp hq with hq | hq
    · exact hs.predicates q hq
    · exact (RefinementPossible.conjuncts _ _).mp hp q hq
  | .const (c := c) => cases c <;> intro p hp <;> cases hp
  | .con _ _ _ _ | .atError _ | .list _ | .fn | .dependentFn | .tvar | .reference | .lazy | .cont | .map | .set | .bytes | .dict | .tapp | .ctor | .external | .scoped | .pathBases | .scopePattern | .checked | .checkedRequest | .checkedAtOpaque => intro p hp; cases hp

theorem Inhabits.of_core_possible {P a v} (h : Inhabits P a.core v)
    (hp : ∀ p ∈ a.refinementPredicates, RefinementPossible p v) : Inhabits P a v := by
  cases a with
  | refined a p =>
    exact .refined (Inhabits.of_core_possible h (fun q hq => hp q (List.mem_append_left _ hq)))
      ((RefinementPossible.conjuncts p v).mpr (fun q hq => hp q (List.mem_append_right _ hq)))
  | _ => exact h

theorem Inhabits.refineNorm_iff {P a p v} :
    Inhabits P (a.refineNorm p) v ↔ Inhabits P a v ∧ RefinementPossible p v := by
  constructor
  · intro h
    have hp := h.predicates
    rw [Ty.predicates_refineNorm] at hp
    exact ⟨Inhabits.of_core_possible (by simpa only [Ty.core_refineNorm] using h.core)
      (fun q hq => hp q (List.mem_append_left _ hq)),
      (RefinementPossible.conjuncts p v).mpr (fun q hq => hp q (List.mem_append_right _ hq))⟩
  · rintro ⟨h,hp⟩
    apply Inhabits.of_core_possible
    · simpa only [Ty.core_refineNorm] using h.core
    · rw [Ty.predicates_refineNorm]
      intro q hq
      rcases List.mem_append.mp hq with hq | hq
      · exact h.predicates q hq
      · exact (RefinementPossible.conjuncts p v).mp hp q hq

theorem Inhabits.refined_inv {P a v} (h : Inhabits P a v) :
    ∀ b p, a = .refined b p → Inhabits P b v ∧ RefinementPossible p v := by
  match h with
  | .const (c := c) => intro b p he; cases c <;> cases he
  | .refined ha hp => intro b p he; cases he; exact ⟨ha,hp⟩
  | .con _ _ _ _ | .atError _ | .list _ | .fn | .dependentFn | .tvar | .reference | .lazy | .cont | .map | .set | .bytes | .dict | .tapp | .ctor | .external | .scoped | .pathBases | .scopePattern | .checked | .checkedRequest | .checkedAtOpaque => intro b p he; cases he

private theorem inhabits_refined_iff {P a p v} :
    Inhabits P (.refined a p) v ↔ Inhabits P a v ∧ RefinementPossible p v :=
  ⟨fun h => Inhabits.refined_inv h a p rfl,fun ⟨ha,hp⟩ => .refined ha hp⟩

theorem Inhabits.list_inv {P a v} (h : Inhabits P a v) :
    ∀ b, a = .list b → ∃ xs, v = .list xs ∧ InhabitsEach P b xs := by
  match h with
  | .const (c := c) => intro b he; cases c <;> cases he
  | .list hs => intro b he; cases he; exact ⟨_,rfl,hs⟩
  | .con _ _ _ _ | .atError _ | .fn | .dependentFn | .tvar | .reference | .lazy | .cont | .map | .set | .bytes | .dict | .tapp | .ctor | .external | .scoped | .pathBases | .scopePattern | .refined _ _ | .checked | .checkedRequest | .checkedAtOpaque => intro b he; cases he

theorem Inhabits.data_inv {P a v} (h : Inhabits P a v) :
    ∀ d ts, a = .data d ts →
      (∃ c tys args cd, v = .con c tys args ∧ P.cons c = some cd ∧ cd.data = d ∧
        cd.ntys = ts.length ∧ (∀ a ∈ cd.args, a.WF 0 cd.ntys 0) ∧
        InhabitsAll P (cd.args.map (Ty.subst ts [])) args) ∨
      (d = "Scope.ScopeError" ∧ ts = [] ∧ ∃ detail, v = .atError detail ∧
        ResultShape.StandardError P ⟨"Result","Ok","Error",atErrorType⟩) := by
  match h with
  | .const (c := c) => intro d ts he; cases c <;> cases he
  | .con hc hn hw hs => intro d ts he; cases he; exact .inl ⟨_,_,_,_,rfl,hc,rfl,hn,hw,hs⟩
  | .atError hs => intro d ts he; cases he; exact .inr ⟨rfl,rfl,_,rfl,hs⟩
  | .list _ | .fn | .dependentFn | .tvar | .reference | .lazy | .cont | .map | .set | .bytes | .dict | .tapp | .ctor | .external | .scoped | .pathBases | .scopePattern | .refined _ _ | .checked | .checkedRequest | .checkedAtOpaque => intro d ts he; cases he

theorem Inhabits.base_inv {P a v} (h : Inhabits P a v) :
    ∀ b, a = .base b → ∃ c, v = .const c ∧ c.type = .base b := by
  match h with
  | .const => intro b he; exact ⟨_,rfl,he⟩
  | .con .. | .atError .. | .list .. | .fn | .dependentFn | .tvar | .reference | .lazy | .cont |
    .map | .set | .bytes | .dict | .tapp | .ctor | .external | .scoped | .pathBases | .scopePattern |
    .refined .. | .checked | .checkedRequest | .checkedAtOpaque => intro b he; cases he

theorem Inhabits.norm_all_iff {P : Program} (a : Ty) (v : Val) :
    Inhabits P a.norm v ↔ Inhabits P a v := by
  cases a with
  | refined a p =>
    rw [Ty.norm,Inhabits.refineNorm_iff,inhabits_refined_iff,Inhabits.norm_all_iff a v]
  | list a =>
    have walk : ∀ (xs : List Val), InhabitsEach P a.norm xs ↔ InhabitsEach P a xs := by
      intro xs
      induction xs with
      | nil => exact ⟨fun _ => .nil,fun _ => .nil⟩
      | cons x xs ih =>
        constructor
        · intro h; cases h with
          | cons hx hs => exact .cons ((Inhabits.norm_all_iff a x).mp hx) (ih.mp hs)
        · intro h; cases h with
          | cons hx hs => exact .cons ((Inhabits.norm_all_iff a x).mpr hx) (ih.mpr hs)
    constructor
    · intro h
      obtain ⟨xs,rfl,hs⟩ := Inhabits.list_inv h _ rfl
      exact .list ((walk xs).mp hs)
    · intro h
      obtain ⟨xs,rfl,hs⟩ := Inhabits.list_inv h _ rfl
      exact .list ((walk xs).mpr hs)
  | data d ts =>
    have he : ∀ cd : ConDecl, cd.args.map (Ty.subst (Ty.normTys ts) []) = cd.args.map (Ty.subst ts []) := by
      intro cd; apply List.map_congr_left; intro a _; exact a.subst_norm_images ts
    constructor
    · intro h
      rcases Inhabits.data_inv h d (Ty.normTys ts) rfl with ⟨c,tys,args,cd,rfl,hc,rfl,hn,hw,hs⟩ | ⟨rfl,ht,detail,rfl,hs⟩
      · exact .con hc (by simpa only [Ty.normTys_eq_map,List.length_map] using hn) hw (he cd ▸ hs)
      · have : ts = [] := by simpa only [Ty.normTys_eq_map,List.map_eq_nil_iff] using ht
        subst ts; exact .atError hs
    · intro h
      rcases Inhabits.data_inv h d ts rfl with ⟨c,tys,args,cd,rfl,hc,rfl,hn,hw,hs⟩ | ⟨rfl,rfl,detail,rfl,hs⟩
      · exact .con hc (by simpa only [Ty.normTys_eq_map,List.length_map] using hn) hw ((he cd).symm ▸ hs)
      · exact .atError hs
  | dependentFn t =>
    constructor
    · intro _; exact .dependentFn
    · intro _; unfold Ty.norm Ty.foldFn; split <;> first | exact .fn | exact .dependentFn
  | fn ns ps r e => exact ⟨fun _ => .fn,fun _ => .fn⟩
  | reference a => exact ⟨fun _ => .reference,fun _ => .reference⟩
  | lazy a => exact ⟨fun _ => .lazy,fun _ => .lazy⟩
  | cont b t e => exact ⟨fun _ => .cont,fun _ => .cont⟩
  | map a b => exact ⟨fun _ => .map,fun _ => .map⟩
  | set a => exact ⟨fun _ => .set,fun _ => .set⟩
  | dict cl a => exact ⟨fun _ => .dict,fun _ => .dict⟩
  | tapp i ts => exact ⟨fun _ => .tapp,fun _ => .tapp⟩
  | external id ts => exact ⟨fun _ => .external,fun _ => .external⟩
  | _ => exact Iff.rfl
termination_by sizeOf a

theorem Inhabits.norm_iff {P : Program} {a : Ty} {v : Val} {nr nt nv : Nat}
    (_wf : a.WF nr nt nv) : Inhabits P a.norm v ↔ Inhabits P a v := Inhabits.norm_all_iff a v

end
end Benitoite.Release.Refinement
