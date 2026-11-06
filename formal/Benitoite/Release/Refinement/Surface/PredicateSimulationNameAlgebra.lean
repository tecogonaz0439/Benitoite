import Benitoite.Release.Refinement.Surface.PredicateSimulationInvariants

/-! # 実行時の具体化と生成名の不在

閉包のコードと失敗値の元入力も含む全inventoryを保つ。型付けを条件へ加えない。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateGeneratedNames
noncomputable section

mutual
  theorem valueNames_rename (v : Val) (ρ : Nat → Nat) : valueNames (v.rename ρ) = valueNames v := by
    cases v <;> simp only [Val.rename, valueNames, valueNames_rename, valuesNames_rename, compNames_rename]
  theorem valuesNames_rename (vs : List Val) (ρ : Nat → Nat) : valuesNames (Val.renameList ρ vs) = valuesNames vs := by
    cases vs <;> simp only [Val.renameList, valuesNames, valueNames_rename, valuesNames_rename]
  theorem compNames_rename (m : Comp) (ρ : Nat → Nat) : compNames (m.rename ρ) = compNames m := by
    cases m with
    | checkAt kind name shape bases pattern input index =>
      cases bases <;> simp only [Comp.rename, compNames, valueNames_rename, optionalNames]
    | _ => simp only [Comp.rename, compNames, valueNames_rename, valuesNames_rename, compNames_rename, armsNames_rename, clausesNames_rename]
  theorem armsNames_rename (arms : List Arm) (ρ : Nat → Nat) : armsNames (Arm.renameList ρ arms) = armsNames arms := by
    cases arms with
    | nil => rfl
    | cons arm rest => cases arm with
      | mk alternatives guard body => cases guard <;> simp only [Arm.renameList, armsNames, compNames_rename, armsNames_rename]
  theorem clausesNames_rename (clauses : List Clause) (ρ : Nat → Nat) : clausesNames (Clause.renameList ρ clauses) = clausesNames clauses := by
    cases clauses with
    | nil => rfl
    | cons clause rest => cases clause <;> simp only [Clause.renameList, clausesNames, compNames_rename, clausesNames_rename]
end

mutual
  theorem valueNames_substTy (v : Val) (c : Nat) (ts : List Ty) (es : List Eff) : valueNames (v.substTyAt c ts es) = valueNames v := by
    cases v <;> simp only [Val.substTyAt, valueNames, valueNames_substTy, valuesNames_substTy, compNames_substTy]
  theorem valuesNames_substTy (vs : List Val) (c : Nat) (ts : List Ty) (es : List Eff) : valuesNames (Val.substTyAtList c ts es vs) = valuesNames vs := by
    cases vs <;> simp only [Val.substTyAtList, valuesNames, valueNames_substTy, valuesNames_substTy]
  theorem compNames_substTy (m : Comp) (c : Nat) (ts : List Ty) (es : List Eff) : compNames (m.substTyAt c ts es) = compNames m := by
    cases m with
    | checkAt kind name shape bases pattern input index =>
      cases bases <;> simp only [Comp.substTyAt, compNames, valueNames_substTy, optionalNames]
    | _ => simp only [Comp.substTyAt, compNames, valueNames_substTy, valuesNames_substTy, compNames_substTy, armsNames_substTy, clausesNames_substTy]
  theorem armsNames_substTy (arms : List Arm) (c : Nat) (ts : List Ty) (es : List Eff) : armsNames (Arm.substTyAtList c ts es arms) = armsNames arms := by
    cases arms with
    | nil => rfl
    | cons arm rest => cases arm with
      | mk alternatives guard body => cases guard <;> simp only [Arm.substTyAtList, armsNames, compNames_substTy, armsNames_substTy]
  theorem clausesNames_substTy (clauses : List Clause) (c : Nat) (ts : List Ty) (es : List Eff) : clausesNames (Clause.substTyAtList c ts es clauses) = clausesNames clauses := by
    cases clauses with
    | nil => rfl
    | cons clause rest => cases clause <;> simp only [Clause.substTyAtList, clausesNames, compNames_substTy, clausesNames_substTy]
end

mutual
  theorem valueNames_shiftE (v : Val) (k c : Nat) : valueNames (v.shiftEAt k c) = valueNames v := by
    cases v <;> simp only [Val.shiftEAt, valueNames, valueNames_shiftE, valuesNames_shiftE, compNames_shiftE]
  theorem valuesNames_shiftE (vs : List Val) (k c : Nat) : valuesNames (Val.shiftEListAt k c vs) = valuesNames vs := by
    cases vs <;> simp only [Val.shiftEListAt, valuesNames, valueNames_shiftE, valuesNames_shiftE]
  theorem compNames_shiftE (m : Comp) (k c : Nat) : compNames (m.shiftEAt k c) = compNames m := by
    cases m with
    | checkAt kind name shape bases pattern input index =>
      cases bases <;> simp only [Comp.shiftEAt, compNames, valueNames_shiftE, optionalNames]
    | _ => simp only [Comp.shiftEAt, compNames, valueNames_shiftE, valuesNames_shiftE, compNames_shiftE, armsNames_shiftE, clausesNames_shiftE]
  theorem armsNames_shiftE (arms : List Arm) (k c : Nat) : armsNames (Arm.shiftEListAt k c arms) = armsNames arms := by
    cases arms with
    | nil => rfl
    | cons arm rest => cases arm with
      | mk alternatives guard body => cases guard <;> simp only [Arm.shiftEListAt, armsNames, compNames_shiftE, armsNames_shiftE]
  theorem clausesNames_shiftE (clauses : List Clause) (k c : Nat) : clausesNames (Clause.shiftEListAt k c clauses) = clausesNames clauses := by
    cases clauses with
    | nil => rfl
    | cons clause rest => cases clause <;> simp only [Clause.shiftEListAt, clausesNames, compNames_shiftE, clausesNames_shiftE]
end

mutual
  theorem valueNames_mapRanges (v : Val) (ρ : Nat → RangeIx) : valueNames (v.mapRangesN ρ) = valueNames v := by
    cases v <;> simp only [Val.mapRangesN, valueNames, valueNames_mapRanges, valuesNames_mapRanges, compNames_mapRanges]
  theorem valuesNames_mapRanges (vs : List Val) (ρ : Nat → RangeIx) : valuesNames (Val.mapRangesListN ρ vs) = valuesNames vs := by
    cases vs <;> simp only [Val.mapRangesListN, valuesNames, valueNames_mapRanges, valuesNames_mapRanges]
  theorem compNames_mapRanges (m : Comp) (ρ : Nat → RangeIx) : compNames (m.mapRangesN ρ) = compNames m := by
    cases m with
    | checkAt kind name shape bases pattern input index =>
      cases bases <;> simp only [Comp.mapRangesN, compNames, valueNames_mapRanges, optionalNames]
    | _ => simp only [Comp.mapRangesN, compNames, valueNames_mapRanges, valuesNames_mapRanges, compNames_mapRanges, armsNames_mapRanges, clausesNames_mapRanges]
  theorem armsNames_mapRanges (arms : List Arm) (ρ : Nat → RangeIx) : armsNames (Arm.mapRangesListN ρ arms) = armsNames arms := by
    cases arms with
    | nil => rfl
    | cons arm rest => cases arm with
      | mk alternatives guard body => cases guard <;> simp only [Arm.mapRangesListN, armsNames, compNames_mapRanges, armsNames_mapRanges]
  theorem clausesNames_mapRanges (clauses : List Clause) (ρ : Nat → RangeIx) : clausesNames (Clause.mapRangesListN ρ clauses) = clausesNames clauses := by
    cases clauses with
    | nil => rfl
    | cons clause rest => cases clause <;> simp only [Clause.mapRangesListN, clausesNames, compNames_mapRanges, clausesNames_mapRanges]
end

theorem valuesNames_avoid {keys values} : NamesAvoid keys (valuesNames values) ↔ ValuesAvoid keys values := by
  induction values with
  | nil => exact ⟨fun _ => ValuesAvoid.nil _,fun _ => NamesAvoid.nil _⟩
  | cons value rest ih =>
    change NamesAvoid keys (valueNames value ++ valuesNames rest) ↔ _
    rw [NamesAvoid.append,ValuesAvoid.cons,← ih]
    rfl

theorem ValueAvoid.rename {keys value} (h : ValueAvoid keys value) (ρ : Nat → Nat) :
    ValueAvoid keys (value.rename ρ) := by simpa only [ValueAvoid,valueNames_rename] using h

theorem CodeAvoid.rename {keys body} (h : CodeAvoid keys body) (ρ : Nat → Nat) :
    CodeAvoid keys (body.rename ρ) := by simpa only [CodeAvoid,compNames_rename] using h

theorem ValueAvoid.substTy {keys value} (h : ValueAvoid keys value) (c : Nat) (ts : List Ty) (es : List Eff) :
    ValueAvoid keys (value.substTyAt c ts es) := by simpa only [ValueAvoid,valueNames_substTy] using h

theorem CodeAvoid.substTy {keys body} (h : CodeAvoid keys body) (c : Nat) (ts : List Ty) (es : List Eff) :
    CodeAvoid keys (body.substTyAt c ts es) := by simpa only [CodeAvoid,compNames_substTy] using h

theorem ValueAvoid.shiftE {keys value} (h : ValueAvoid keys value) (k c : Nat) :
    ValueAvoid keys (value.shiftEAt k c) := by simpa only [ValueAvoid,valueNames_shiftE] using h

theorem CodeAvoid.shiftE {keys body} (h : CodeAvoid keys body) (k c : Nat) :
    CodeAvoid keys (body.shiftEAt k c) := by simpa only [CodeAvoid,compNames_shiftE] using h

theorem ValueAvoid.instR {keys value} (h : ValueAvoid keys value) (rs : List RangeExpr) :
    ValueAvoid keys (value.instR rs) := by
  cases rs with
  | nil => exact h
  | cons r rs => simpa only [Val.instR,Val.substR,ValueAvoid,valueNames_mapRanges] using h

theorem CodeAvoid.instR {keys body} (h : CodeAvoid keys body) (rs : List RangeExpr) :
    CodeAvoid keys (body.instR rs) := by
  cases rs with
  | nil => exact h
  | cons r rs => simpa only [Comp.instR,Comp.substR,CodeAvoid,compNames_mapRanges] using h

theorem valuesAvoid_upSubst {keys ν} (avoid : ∀ i, ValueAvoid keys (ν i)) (n i : Nat) :
    ValueAvoid keys (upSubst n ν i) := by
  by_cases bound : i < n
  · simpa only [upSubst,ite_eq_left bound] using ValueAvoid.variable keys i
  · simpa only [upSubst,ite_eq_right bound] using (avoid (i - n)).rename (· + n)

mutual
  theorem ValueAvoid.subst {keys value} (h : ValueAvoid keys value) (ν : Nat → Val) (ρ : Nat → LocalRef)
      (avoid : ∀ i, ValueAvoid keys (ν i)) : ValueAvoid keys (value.subst ν ρ) := by
    cases value with
    | var i => exact avoid i
    | lam names params body => exact CodeAvoid.subst (body := body) h (upSubst params.length ν) (upLocalSubst params.length ρ) (valuesAvoid_upSubst avoid params.length)
    | dependentLam signature body => exact CodeAvoid.subst (body := body) h (upSubst (telBinders signature) ν) (upLocalSubst (telBinders signature) ρ) (valuesAvoid_upSubst avoid (telBinders signature))
    | con c ts values => exact valuesNames_avoid.mpr ((valuesNames_avoid.mp h).subst ν ρ avoid)
    | list values => exact valuesNames_avoid.mpr ((valuesNames_avoid.mp h).subst ν ρ avoid)
    | setV values => exact valuesNames_avoid.mpr ((valuesNames_avoid.mp h).subst ν ρ avoid)
    | dict name ts values => exact valuesNames_avoid.mpr ((valuesNames_avoid.mp h).subst ν ρ avoid)
    | mapV keys values =>
      obtain ⟨left,right⟩ := NamesAvoid.append.mp h
      exact NamesAvoid.append.mpr ⟨valuesNames_avoid.mpr ((valuesNames_avoid.mp left).subst ν ρ avoid),
        valuesNames_avoid.mpr ((valuesNames_avoid.mp right).subst ν ρ avoid)⟩
    | super value superclass => exact ValueAvoid.subst (value := value) h ν ρ avoid
    | _ => exact h

  theorem ValuesAvoid.subst {keys values} (h : ValuesAvoid keys values) (ν : Nat → Val) (ρ : Nat → LocalRef)
      (avoid : ∀ i, ValueAvoid keys (ν i)) : ValuesAvoid keys (Val.substList ν values ρ) := by
    cases values with
    | nil => exact ValuesAvoid.nil _
    | cons value values =>
      obtain ⟨head,tail⟩ := ValuesAvoid.cons.mp h
      exact ValuesAvoid.cons.mpr ⟨head.subst ν ρ avoid,ValuesAvoid.subst tail ν ρ avoid⟩

  theorem CodeAvoid.subst {keys body} (h : CodeAvoid keys body) (ν : Nat → Val) (ρ : Nat → LocalRef)
      (avoid : ∀ i, ValueAvoid keys (ν i)) : CodeAvoid keys (body.subst ν ρ) := by
    cases body with
    | builderLet kind body => exact CodeAvoid.subst (body := body) h (upSubst 1 ν) (upLocalSubst 1 ρ) (valuesAvoid_upSubst avoid 1)
    | builderOp kind op localRef values => exact valuesNames_avoid.mpr ((valuesNames_avoid.mp h).subst ν ρ avoid)
    | ret value => exact ValueAvoid.subst (value := value) h ν ρ avoid
    | escape value => exact ValueAvoid.subst (value := value) h ν ρ avoid
    | letIn left right =>
      obtain ⟨hl,hr⟩ := NamesAvoid.append.mp h
      exact NamesAvoid.append.mpr ⟨CodeAvoid.subst (body := left) hl ν ρ avoid,CodeAvoid.subst (body := right) hr (upSubst 1 ν) (upLocalSubst 1 ρ) (valuesAvoid_upSubst avoid 1)⟩
    | app function values =>
      obtain ⟨hf,hargs⟩ := NamesAvoid.append.mp h
      exact NamesAvoid.append.mpr ⟨ValueAvoid.subst (value := function) hf ν ρ avoid,
        valuesNames_avoid.mpr ((valuesNames_avoid.mp hargs).subst ν ρ avoid)⟩
    | ite value yes no =>
      obtain ⟨heads,hn⟩ := NamesAvoid.append.mp h
      obtain ⟨hv,hy⟩ := NamesAvoid.append.mp heads
      exact NamesAvoid.append.mpr ⟨NamesAvoid.append.mpr ⟨ValueAvoid.subst (value := value) hv ν ρ avoid,
        CodeAvoid.subst (body := yes) hy ν ρ avoid⟩,CodeAvoid.subst (body := no) hn ν ρ avoid⟩
    | «match» value arms =>
      obtain ⟨hv,ha⟩ := NamesAvoid.append.mp h
      exact NamesAvoid.append.mpr ⟨ValueAvoid.subst (value := value) hv ν ρ avoid,ArmsAvoid.subst (arms := arms) ha ν ρ avoid⟩
    | lazyC body => exact CodeAvoid.subst (body := body) h ν ρ avoid
    | use value body =>
      obtain ⟨hv,hm⟩ := NamesAvoid.append.mp h
      exact NamesAvoid.append.mpr ⟨ValueAvoid.subst (value := value) hv ν ρ avoid,CodeAvoid.subst (body := body) hm ν ρ avoid⟩
    | handle body clauses =>
      obtain ⟨hm,hh⟩ := NamesAvoid.append.mp h
      exact NamesAvoid.append.mpr ⟨CodeAvoid.subst (body := body) hm ν ρ avoid,ClausesAvoid.subst (clauses := clauses) hh ν ρ avoid⟩
    | resume continuation value =>
      obtain ⟨hk,hv⟩ := NamesAvoid.append.mp h
      exact NamesAvoid.append.mpr ⟨ValueAvoid.subst (value := continuation) hk ν ρ avoid,ValueAvoid.subst (value := value) hv ν ρ avoid⟩
    | externalCall f ts values => exact valuesNames_avoid.mpr ((valuesNames_avoid.mp h).subst ν ρ avoid)
    | issuePathBases name => exact h
    | checkAt kind name shape bases pattern input index =>
      cases bases with
      | none =>
        obtain ⟨hp,hi⟩ := NamesAvoid.append.mp h
        exact NamesAvoid.append.mpr ⟨ValueAvoid.subst (value := pattern) hp ν ρ avoid,
          ValueAvoid.subst (value := input) hi ν ρ avoid⟩
      | some value =>
        obtain ⟨heads,hi⟩ := NamesAvoid.append.mp h
        obtain ⟨hb,hp⟩ := NamesAvoid.append.mp heads
        exact NamesAvoid.append.mpr ⟨NamesAvoid.append.mpr ⟨ValueAvoid.subst (value := value) hb ν ρ avoid,
          ValueAvoid.subst (value := pattern) hp ν ρ avoid⟩,ValueAvoid.subst (value := input) hi ν ρ avoid⟩
    | meth dictionary name ts es values =>
      obtain ⟨hd,ha⟩ := NamesAvoid.append.mp h
      exact NamesAvoid.append.mpr ⟨ValueAvoid.subst (value := dictionary) hd ν ρ avoid,
        valuesNames_avoid.mpr ((valuesNames_avoid.mp ha).subst ν ρ avoid)⟩

  theorem ArmsAvoid.subst {keys arms} (h : ArmsAvoid keys arms) (ν : Nat → Val) (ρ : Nat → LocalRef)
      (avoid : ∀ i, ValueAvoid keys (ν i)) : ArmsAvoid keys (Arm.substList ν arms ρ) := by
    cases arms with
    | nil => exact NamesAvoid.nil _
    | cons arm rest => cases arm with
      | mk alternatives guard body => cases guard with
        | none =>
          obtain ⟨hm,tail⟩ := NamesAvoid.append.mp h
          exact NamesAvoid.append.mpr ⟨CodeAvoid.subst (body := body) hm _ _ (valuesAvoid_upSubst avoid _),
            ArmsAvoid.subst (arms := rest) tail ν ρ avoid⟩
        | some guard =>
          obtain ⟨heads,tail⟩ := NamesAvoid.append.mp h
          obtain ⟨hg,hm⟩ := NamesAvoid.append.mp heads
          exact NamesAvoid.append.mpr ⟨NamesAvoid.append.mpr
            ⟨CodeAvoid.subst (body := guard) hg _ _ (valuesAvoid_upSubst avoid _),
             CodeAvoid.subst (body := body) hm _ _ (valuesAvoid_upSubst avoid _)⟩,
            ArmsAvoid.subst (arms := rest) tail ν ρ avoid⟩

  theorem ClausesAvoid.subst {keys clauses} (h : ClausesAvoid keys clauses) (ν : Nat → Val) (ρ : Nat → LocalRef)
      (avoid : ∀ i, ValueAvoid keys (ν i)) : ClausesAvoid keys (Clause.substList ν clauses ρ) := by
    cases clauses with
    | nil => exact NamesAvoid.nil _
    | cons clause rest => cases clause with
      | mk op arity ntypes body =>
        obtain ⟨heads,tail⟩ := NamesAvoid.append.mp h
        obtain ⟨hop,hm⟩ := NamesAvoid.append.mp heads
        exact NamesAvoid.append.mpr ⟨NamesAvoid.append.mpr ⟨hop,
          CodeAvoid.subst (body := body) hm _ _ (valuesAvoid_upSubst (fun i => (avoid i).shiftE ntypes 0) _)⟩,
          ClausesAvoid.subst (clauses := rest) tail ν ρ avoid⟩
      | fail error body =>
        obtain ⟨hm,tail⟩ := NamesAvoid.append.mp h
        exact NamesAvoid.append.mpr ⟨CodeAvoid.subst (body := body) hm _ _ (valuesAvoid_upSubst (fun i => (avoid i).shiftE 1 0) _),
          ClausesAvoid.subst (clauses := rest) tail ν ρ avoid⟩
end

theorem CaptureAvoid.empty (keys) : CaptureAvoid keys Capture.empty := NamesAvoid.nil _

theorem CaptureAvoid.extend {keys cap value} (h : CaptureAvoid keys cap) (hv : ValueAvoid keys value) :
    CaptureAvoid keys (cap.extend value) := by
  cases cap
  exact NamesAvoid.append.mpr ⟨hv,h⟩

theorem CaptureAvoid.extendNone {keys cap} (h : CaptureAvoid keys cap) : CaptureAvoid keys cap.extendNone := by
  cases cap
  exact h

private theorem slots_env_avoid {keys values} (h : NamesAvoid keys (slotsNames values)) (index : Nat) :
    ValueAvoid keys (((values[index]?).join).getD (.const .unit)) := by
  cases values with
  | nil => exact ValueAvoid.constant _ _
  | cons value values =>
    have parts := NamesAvoid.append.mp h
    cases index with
    | zero => cases value with
      | none => exact ValueAvoid.constant _ _
      | some value => exact parts.1
    | succ index => exact slots_env_avoid parts.2 index

theorem CaptureAvoid.env {keys cap} (h : CaptureAvoid keys cap) (index : Nat) : ValueAvoid keys (cap.env index) := by
  cases cap
  exact slots_env_avoid h index

theorem CaptureAvoid.extendMany {keys cap values} (h : CaptureAvoid keys cap) (hv : ValuesAvoid keys values) :
    CaptureAvoid keys (cap.extendMany values) := by
  induction values generalizing cap with
  | nil => exact h
  | cons value values ih =>
    obtain ⟨head,tail⟩ := ValuesAvoid.cons.mp hv
    exact ih (h.extend head) tail

mutual
  theorem ValueAvoid.close {keys value cap} (h : ValueAvoid keys value) (hc : CaptureAvoid keys cap) :
      ValueAvoid keys (closeVal cap value) := by
    cases value with
    | var i => exact hc.env i
    | lam names params body => exact NamesAvoid.append.mpr ⟨hc,h⟩
    | dependentLam signature body => exact NamesAvoid.append.mpr ⟨hc,h⟩
    | con c ts values => exact valuesNames_avoid.mpr ((valuesNames_avoid.mp h).close hc)
    | list values => exact valuesNames_avoid.mpr ((valuesNames_avoid.mp h).close hc)
    | setV values => exact valuesNames_avoid.mpr ((valuesNames_avoid.mp h).close hc)
    | dict name ts values => exact valuesNames_avoid.mpr ((valuesNames_avoid.mp h).close hc)
    | mapV keys values =>
      obtain ⟨left,right⟩ := NamesAvoid.append.mp h
      exact NamesAvoid.append.mpr ⟨valuesNames_avoid.mpr ((valuesNames_avoid.mp left).close hc),
        valuesNames_avoid.mpr ((valuesNames_avoid.mp right).close hc)⟩
    | super value superclass => exact ValueAvoid.close (value := value) h hc
    | _ => exact h
  theorem ValuesAvoid.close {keys values cap} (h : ValuesAvoid keys values) (hc : CaptureAvoid keys cap) :
      ValuesAvoid keys (closeVals cap values) := by
    cases values with
    | nil => exact ValuesAvoid.nil _
    | cons value values =>
      obtain ⟨head,tail⟩ := ValuesAvoid.cons.mp h
      exact ValuesAvoid.cons.mpr ⟨head.close hc,ValuesAvoid.close tail hc⟩
end

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation

