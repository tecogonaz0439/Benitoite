import Benitoite.Release.Refinement.TypeShiftSyntax
import Benitoite.Release.Refinement.TypeShiftAlgebra
import Benitoite.Release.Refinement.Admissible

namespace Benitoite.Release.Refinement

structure TypeCtxMap (k c : Nat) (Γ Δ : Ctx) : Prop where
  length : Δ.length = Γ.length
  lookup : ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → Δ[i]? = some (some (Refinement.shiftTypes k c a))

theorem TypeCtxMap.shiftEAt (Γ : Ctx) (k c : Nat) : TypeCtxMap k c Γ (Γ.shiftEAt k c) :=
  ⟨by simp [Ctx.shiftEAt], fun i a h => by simp [Ctx.shiftEAt, List.getElem?_map, h]⟩

theorem TypeCtxMap.cons {k c Γ Δ} (h : TypeCtxMap k c Γ Δ) (a : Option Ty) :
    TypeCtxMap k c (a :: Γ) (a.map (Refinement.shiftTypes k c) :: Δ) := by
  constructor
  · simp [h.length]
  · intro i t ht
    cases i with
    | zero => simp only [List.getElem?_cons_zero, Option.some.injEq] at ht; cases ht; rfl
    | succ i => exact h.lookup i t ht

theorem TypeCtxMap.extend {k c Γ Δ} (h : TypeCtxMap k c Γ Δ) (a : Ty) :
    TypeCtxMap k c (Γ.extend a) (Δ.extend (Refinement.shiftTypes k c a)) := by
  constructor
  · simp [Ctx.extend, h.length]
  · intro i t ht
    cases i with
    | zero =>
      simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at ht
      cases ht
      simp only [Ctx.extend, List.getElem?_cons_zero, shiftTypes_shiftV]
    | succ i =>
      simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at ht ⊢
      cases hi : Γ[i]? with
      | none => simp [hi] at ht
      | some a => cases a with
        | none => simp [hi] at ht
        | some a =>
          simp only [hi, Option.map_some, Option.some.injEq] at ht
          cases ht
          rw [h.lookup _ _ hi]
          simp only [Option.map_some, shiftTypes_shiftV]

theorem Ty.hasSort_shiftTypes (a : Ty) (k c : Nat) (s : «Sort») :
    (Refinement.shiftTypes k c a).HasSort s ↔ a.HasSort s := by
  cases a <;> simp [Refinement.shiftTypes, Ty.HasSort, Ty.sort?]
  case refined a p => exact Ty.hasSort_shiftTypes a k c s

theorem Ty.ordinary_shiftTypes (a : Ty) (k c : Nat) :
    Ordinary (Refinement.shiftTypes k c a) ↔ Ordinary a := by
  cases a <;> simp [Refinement.shiftTypes, Ordinary]
  case refined a p => simpa only [Ty.Ordinary, Benitoite.Release.Refinement.Ordinary, Ty.core_shiftTypes] using Ty.ordinary_shiftTypes a k c

theorem TypeCtxMap.images {k c Γ Δ} (h : TypeCtxMap k c Γ Δ) :
    Term.ImagesSorted Γ Δ (fun i => some (.var i)) := by
  intro i a s hi hs
  exact ⟨.var i,rfl,⟨Refinement.shiftTypes k c a,h.lookup i a hi,(Ty.ordinary_shiftTypes _ _ _).mpr hs.ordinary⟩,Refinement.shiftTypes k c a,h.lookup i a hi,(Ty.hasSort_shiftTypes _ _ _ _).mpr hs⟩

theorem TypeCtxMap.references {k c Γ Δ} (h : TypeCtxMap k c Γ Δ) :
    Term.ImageReferences Γ Δ (fun i => some (.var i)) := by
  intro i a hi ho t ht
  cases ht
  exact ⟨Refinement.shiftTypes k c a,h.lookup i a hi,(Ty.ordinary_shiftTypes _ _ _).mpr ho⟩

theorem Pred.sorted_shiftTypes {Γ Δ a p k c} (hp : Pred.Sorted Γ (some a) p)
    (h : TypeCtxMap k c Γ Δ) : Pred.Sorted Δ (some (Refinement.shiftTypes k c a)) p := by
  simpa only [upValues_id, predBind_id] using Pred.sorted_bind hp (fun i => some (.var i))
    (fun s hs => (Ty.hasSort_shiftTypes _ _ _ _).mpr hs)
    (fun ho => (Ty.ordinary_shiftTypes _ _ _).mpr ho) h.images h.references

mutual
  theorem Ty.sorted_shiftTypes {Γ Δ a k c} (ha : Ty.Sorted Γ a) (h : TypeCtxMap k c Γ Δ) :
      Ty.Sorted Δ (Refinement.shiftTypes k c a) := by
    cases a <;> simp only [Ty.Sorted] at ha <;> simp only [Refinement.shiftTypes, Ty.Sorted]
    all_goals first | trivial | exact Ty.sorted_shiftTypes ha h | exact sortedTys_shiftTypes ha h | exact Tel.sorted_shiftTypes ha h | skip
    case fn ns ps r e => exact ⟨sortedTys_shiftTypes ha.1 h, Ty.sorted_shiftTypes ha.2.1 h, sortedEff_shiftTypes ha.2.2 h⟩
    case cont b t e => exact ⟨Ty.sorted_shiftTypes ha.1 h, Ty.sorted_shiftTypes ha.2.1 h, sortedEff_shiftTypes ha.2.2 h⟩
    case map a b => exact ⟨Ty.sorted_shiftTypes ha.1 h, Ty.sorted_shiftTypes ha.2 h⟩
    case refined a p => exact ⟨Ty.sorted_shiftTypes ha.1 h, Pred.sorted_shiftTypes ha.2 h⟩
  theorem Tel.sorted_shiftTypes {Γ Δ t k c} (ha : Tel.Sorted Γ t) (h : TypeCtxMap k c Γ Δ) :
      Tel.Sorted Δ (shiftTelTypes k c t) := by
    cases t with
    | done r e => exact ⟨Ty.sorted_shiftTypes ha.1 h, sortedEff_shiftTypes ha.2 h⟩
    | param n a t => exact ⟨Ty.sorted_shiftTypes ha.1 h, Tel.sorted_shiftTypes ha.2 (h.extend a)⟩
  theorem sortedTys_shiftTypes {Γ Δ as k c} (ha : sortedTys Γ as) (h : TypeCtxMap k c Γ Δ) :
      sortedTys Δ (shiftTypesList k c as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.sorted_shiftTypes ha.1 h, sortedTys_shiftTypes ha.2 h⟩
  theorem sortedEff_shiftTypes {Γ Δ e k c} (ha : sortedEff Γ e) (h : TypeCtxMap k c Γ Δ) :
      sortedEff Δ (shiftRowsTypes k c e) := by
    cases e; exact sortedTys_shiftTypes ha h
end

theorem Term.HasData.shiftTypes {P Γ Δ t d ts k c} (ht : Term.HasData P Γ t d ts)
    (h : TypeCtxMap k c Γ Δ) : Term.HasData P Δ t d (ts.map (Refinement.shiftTypes k c)) := by
  match ht with
  | .widen hr hs => exact .widen (hr.shiftTypes h) (hs.shiftTypes k c)
  | .var (a := a) hi he =>
    refine Term.HasData.var (h.lookup _ _ hi) ?_
    rw [Ty.norm_shiftTypes, Ty.core_shiftTypes, he]
    simp only [Refinement.shiftTypes, shiftTypesList_eq_map]
  | .value hc hd hn hl => exact .value hc hd (by simpa using hn) hl
  | .field (a := a) (ts := xs) (cd := cd) ht hc hd hn hi hw hs he =>
    have hh := Ty.subst_shiftTypes hw xs [] (by omega) k c
    simp only [List.map_nil] at hh
    have hh' : (a.subst (xs.map (Refinement.shiftTypes k c)) []).norm.core = .data d (ts.map (Refinement.shiftTypes k c)) := by
      rw [←hh, Ty.norm_shiftTypes, Ty.core_shiftTypes, he]
      simp only [Refinement.shiftTypes, shiftTypesList_eq_map]
    exact .field (ht.shiftTypes h) hc hd (by simpa using hn) hi hw
      (by rw [←hh]; exact (Ty.hasSort_shiftTypes _ _ _ _).mpr hs) hh'

theorem FieldRef.Declared.shiftTypes {P C C' Γ Δ t ref k c} (ht : FieldRef.Declared P C Γ t ref)
    (h : TypeCtxMap k c Γ Δ) : FieldRef.Declared P C' Δ t ref := by
  obtain ⟨ts,cd,a,hr,hc,hd,hn,hi,hw,hs⟩ := ht
  refine ⟨ts.map (Refinement.shiftTypes k c),cd,a,hr.shiftTypes h,hc,hd,by simpa using hn,hi,hw,?_⟩
  have he := Ty.subst_shiftTypes hw ts [] (by omega) k c
  simp only [List.map_nil] at he
  rw [←he]
  exact (Ty.hasSort_shiftTypes _ _ _ _).mpr hs

mutual
  theorem Term.Declared.shiftTypes {P C C' Γ Δ t k c} (ht : Term.Declared P C Γ t)
      (h : TypeCtxMap k c Γ Δ) : Term.Declared P C' Δ t := by
    cases t <;> simp only [Term.Declared] at ht ⊢
    all_goals first | trivial | exact Term.Declared.shiftTypes ht h | exact declaredSlots_shiftTypes ht h | skip
    case var i => obtain ⟨a,hi,ho⟩ := ht; exact ⟨Refinement.shiftTypes k c a,h.lookup _ _ hi,(Ty.ordinary_shiftTypes _ _ _).mpr ho⟩
    case field ref t => exact ⟨ht.1.shiftTypes h,FieldRef.Declared.shiftTypes ht.2 h⟩
    case add a b => exact ⟨ht.1.shiftTypes h,ht.2.shiftTypes h⟩
    case mapValue ks vs => exact ⟨declaredSlots_shiftTypes ht.1 h,declaredSlots_shiftTypes ht.2 h⟩
    case dataValue con xs => exact ⟨declaredSlots_shiftTypes ht.1 h,ht.2⟩
  theorem declaredSlot_shiftTypes {P C C' Γ Δ x k c} (ht : declaredSlot P C Γ x)
      (h : TypeCtxMap k c Γ Δ) : declaredSlot P C' Δ x := by
    cases x with
    | none => trivial
    | some t => exact ht.shiftTypes h
  theorem declaredSlots_shiftTypes {P C C' Γ Δ xs k c} (ht : declaredSlots P C Γ xs)
      (h : TypeCtxMap k c Γ Δ) : declaredSlots P C' Δ xs := by
    cases xs with
    | nil => trivial
    | cons x xs => exact ⟨declaredSlot_shiftTypes ht.1 h,declaredSlots_shiftTypes ht.2 h⟩
end

theorem Pred.Declared.shiftTypes {P C C' Γ Δ self p k c} (ht : Pred.Declared P C Γ self p)
    (h : TypeCtxMap k c Γ Δ) : Pred.Declared P C' Δ (self.map (Refinement.shiftTypes k c)) p := by
  have hm : TypeCtxMap k c (Γ.declarationSelf self)
      (Δ.declarationSelf (self.map (Refinement.shiftTypes k c))) := by
    cases self with
    | none => exact h
    | some a => exact h.extend a
  induction p <;> simp only [Pred.Declared] at ht ⊢
  all_goals first
    | trivial
    | exact Term.Declared.shiftTypes ht hm
    | exact ⟨Term.Declared.shiftTypes ht.1 hm, Term.Declared.shiftTypes ht.2 hm⟩
    | exact ⟨by assumption,by assumption⟩
    | assumption
    | skip
  case constructorIs t con =>
    obtain ⟨hd,d,ts,cd,hx,hc,he⟩ := ht
    exact ⟨hd.shiftTypes hm,d,ts.map (Refinement.shiftTypes k c),cd,hx.shiftTypes hm,hc,he⟩
  case and p q hp hq => exact ⟨hp ht.1,hq ht.2⟩
  case or p q hp hq => exact ⟨hp ht.1,hq ht.2⟩
  case not p hp => exact hp ht

mutual
  theorem Ty.Declared.shiftTypes {P C C' Γ Δ a k c} (ht : Ty.Declared P C Γ a)
      (h : TypeCtxMap k c Γ Δ) (hC : TypeParamRenaming C C' (shiftIndex k c)) : Ty.Declared P C' Δ (Refinement.shiftTypes k c a) := by
    cases a with
    | base _ | bytes | «opaque» _ _ | «scoped» _ _ _ | pathBases | scopePattern _ | tvar _ => trivial
    | ctor con => cases con <;> exact ht
    | list a | reference a | lazy a | set a | dict _ a => exact Ty.Declared.shiftTypes (a := a) ht h hC
    | data d as => exact ⟨by simpa only [shiftTypesList_eq_map, List.length_map] using ht.1,
        declaredTys_shiftTypes ht.2 h hC⟩
    | external _ as => exact ⟨by simpa only [shiftTypesList_eq_map, List.length_map] using ht.1,
        declaredTys_shiftTypes ht.2 h hC⟩
    | tapp i as => exact ⟨by simpa only [shiftTypesList_eq_map, List.length_map, shiftIndex] using hC.kindRenaming _ _ ht.1, declaredTys_shiftTypes ht.2 h hC⟩
    | dependentFn t => exact Tel.Declared.shiftTypes ht h hC
    | fn ns ps r e => exact ⟨declaredTys_shiftTypes ht.1 h hC,
        Ty.Declared.shiftTypes ht.2.1 h hC,declaredEff_shiftTypes ht.2.2 h hC⟩
    | cont b t e => exact ⟨Ty.Declared.shiftTypes ht.1 h hC,
        Ty.Declared.shiftTypes ht.2.1 h hC,declaredEff_shiftTypes ht.2.2 h hC⟩
    | map a b => exact ⟨Ty.Declared.shiftTypes ht.1 h hC,Ty.Declared.shiftTypes ht.2 h hC⟩
    | refined a p => exact ⟨Ty.Declared.shiftTypes ht.1 h hC,Pred.Declared.shiftTypes ht.2 h⟩
  theorem Tel.Declared.shiftTypes {P C C' Γ Δ t k c} (ht : Tel.Declared P C Γ t)
      (h : TypeCtxMap k c Γ Δ) (hC : TypeParamRenaming C C' (shiftIndex k c)) : Tel.Declared P C' Δ (shiftTelTypes k c t) := by
    cases t with
    | done r e => exact ⟨Ty.Declared.shiftTypes ht.1 h hC,declaredEff_shiftTypes ht.2 h hC⟩
    | param n a t => exact ⟨Ty.Declared.shiftTypes ht.1 h hC,Tel.Declared.shiftTypes ht.2 (h.extend a) hC⟩
  theorem declaredTys_shiftTypes {P C C' Γ Δ as k c} (ht : declaredTys P C Γ as)
      (h : TypeCtxMap k c Γ Δ) (hC : TypeParamRenaming C C' (shiftIndex k c)) : declaredTys P C' Δ (shiftTypesList k c as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.Declared.shiftTypes ht.1 h hC,declaredTys_shiftTypes ht.2 h hC⟩
  theorem declaredEff_shiftTypes {P C C' Γ Δ e k c} (ht : declaredEff P C Γ e)
      (h : TypeCtxMap k c Γ Δ) (hC : TypeParamRenaming C C' (shiftIndex k c)) : declaredEff P C' Δ (shiftRowsTypes k c e) := by
    cases e; exact declaredTys_shiftTypes ht h hC
end

mutual
  theorem Ty.wf_shiftTypes {nr nt nv a} (hw : Ty.WF nr nt nv a) (k c : Nat) :
      Ty.WF nr (nt+k) nv (Refinement.shiftTypes k c a) := by
    cases a <;> simp only [Ty.WF] at hw <;> simp only [shiftTypes, Ty.WF]
    all_goals first | exact hw | exact Ty.wf_shiftTypes hw k c | exact wfList_shiftTypes hw k c | skip
    case tvar i => split <;> omega
    case fn ns ps r e => exact ⟨⟨by simpa [shiftTypesList_eq_map] using hw.1.1, hw.1.2⟩,
      wfList_shiftTypes hw.2.1 k c, Ty.wf_shiftTypes hw.2.2.1 k c,
      Eff.wf_shiftTypes hw.2.2.2.1 k c, by change (shiftRowsTypes k c e).norm = _; rw [Eff.norm_shiftTypes, hw.2.2.2.2]⟩
    case cont b t e => exact ⟨Ty.wf_shiftTypes hw.1 k c, Ty.wf_shiftTypes hw.2.1 k c,
      Eff.wf_shiftTypes hw.2.2.1 k c, by change (shiftRowsTypes k c e).norm = _; rw [Eff.norm_shiftTypes, hw.2.2.2]⟩
    case map a b => exact ⟨Ty.wf_shiftTypes hw.1 k c, Ty.wf_shiftTypes hw.2 k c⟩
    case tapp i as => exact ⟨by split <;> omega, wfList_shiftTypes hw.2 k c⟩
    case refined a p => exact ⟨Ty.wf_shiftTypes hw.1 k c, hw.2.1, (Ty.ordinary_shiftTypes _ _ _).mpr hw.2.2⟩
    case dependentFn t => exact Tel.wf_shiftTypes hw k c
  theorem Tel.wf_shiftTypes {nr nt nv t} (hw : Tel.WF nr nt nv t) (k c : Nat) :
      Tel.WF nr (nt+k) nv (shiftTelTypes k c t) := by
    cases t with
    | done r e => exact ⟨Ty.wf_shiftTypes hw.1 k c, Eff.wf_shiftTypes hw.2.1 k c,
        by change (shiftRowsTypes k c e).norm = _; rw [Eff.norm_shiftTypes, hw.2.2]⟩
    | param n a t => exact ⟨Ty.wf_shiftTypes hw.1 k c, Tel.wf_shiftTypes hw.2 k c⟩
  theorem wfList_shiftTypes {nr nt nv as} (hw : Ty.WFList nr nt nv as) (k c : Nat) :
      Ty.WFList nr (nt+k) nv (shiftTypesList k c as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.wf_shiftTypes hw.1 k c, wfList_shiftTypes hw.2 k c⟩
  theorem Eff.wf_shiftTypes {nr nt nv e} (hw : Eff.WF nr nt nv e) (k c : Nat) :
      Eff.WF nr (nt+k) nv (shiftRowsTypes k c e) := by
    cases e; exact wfList_shiftTypes hw k c
end

theorem TypeCtxMap.annotation {P C C' Γ Δ a k c} (h : TypeCtxMap k c Γ Δ)
    (hn : C'.length = C.length+k) (ha : Ty.Annotation P C Γ a)
    (hC : TypeParamRenaming C C' (shiftIndex k c)) :
    Ty.Annotation P C' Δ (Refinement.shiftTypes k c a) :=
  ⟨by simpa only [hn,h.length] using Ty.wf_shiftTypes ha.wf k c,
    Ty.sorted_shiftTypes ha.sorted h,ha.declared.shiftTypes h hC⟩

end Benitoite.Release.Refinement
