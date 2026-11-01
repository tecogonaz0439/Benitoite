import Lean
import Benitoite.Release.Refinement.ReferencePreservation

namespace Benitoite.Release.Refinement.RV15
noncomputable section

def P : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
abbrev U : Ty := .base .unit
/-- kind は io だが opEff なし・効果は空の項目。旧 io_op が拒む形。 -/
def evil : PrimSig := ⟨[],0,[],[],U,Eff.empty,fun _ _ => True,.io,none,[],.untargeted⟩
def getS : PrimSig := ⟨[{}],0,["reference"],[.reference (.tvar 0)],.tvar 0,Eff.single stateEff,fun _ _ => True,.refGet,none,[],.untargeted⟩
def setS : PrimSig := ⟨[{}],0,["reference","value"],[.reference (.tvar 0),.tvar 0],U,Eff.single stateEff,fun _ _ => True,.refSet,none,[],.untargeted⟩
def B : Builtins :=
  { sig := fun b => if b = "evil" then some evil else if b = "get" then some getS else if b = "set" then some setS else none,
    delta := fun _ _ _ _ _ => none,
    ioResponse := fun b _ _ _ o obs => b = "evil" ∧ o = .val (.const .unit) ∧ obs = [],
    releaseResponse := fun _ _ => True, isResource := fun _ => false,
    effects := fun l => if l = stateEff then some [] else none,
    sat := fun _ _ _ => True, refGet := "get", refSet := "set" }

theorem sig_cases {b s} (hs : B.sig b = some s) : (b = "evil" ∧ s = evil) ∨ s = getS ∨ s = setS := by
  change (if b = "evil" then _ else if b = "get" then _ else if b = "set" then _ else none) = some s at hs
  split at hs
  · exact Or.inl ⟨by assumption,(Option.some.inj hs).symm⟩
  · split at hs
    · exact Or.inr (Or.inl (Option.some.inj hs).symm)
    · split at hs
      · exact Or.inr (Or.inr (Option.some.inj hs).symm)
      · cases hs

theorem sig_evil : B.sig "evil" = some evil := rfl

theorem evil_tel : evil.tel = .done U Eff.empty := by
  simp [PrimSig.tel, signatureTel, evil]


theorem inst_tel (rs : List RangeExpr) : ∃ e0, instantiatedTel (Tel.instR rs evil.tel) [] [] = .done U e0 := by
  rw [evil_tel]; exact ⟨_, rfl⟩

theorem unit_typed {Ψ} : HasTypeV P B Ψ [] [] [] (.const .unit) U := .V_Const trivial

theorem args_shape {Ψ ts es rs ws a e} (h : BuiltinArgs P B Ψ "evil" evil ts es rs ws a e) :
    ts = [] ∧ es = [] ∧ ws = [] ∧ a = U := by
  have ht : ts = [] := List.length_eq_zero_iff.mp h.admissible.typeCount
  have he : es = [] := List.length_eq_zero_iff.mp h.admissible.rowCount
  subst ht he
  obtain ⟨e0, h0⟩ := inst_tel rs
  have ha := h.arguments
  rw [h0] at ha
  cases ha
  exact ⟨rfl, rfl, rfl, rfl⟩

theorem assumptions : Builtins.CoreAssumptions P B where
  sat_rename := by intros; trivial
  sat_values := by intros; trivial
  sat_renameTypes := by intros; trivial
  sat_subst := by intros; trivial
  admits_rename := by
    intro b s C Γ Δ ts ξ hs _ _ _ _
    rcases sig_cases hs with ⟨_,rfl⟩ | rfl | rfl <;> trivial
  admits_values := by
    intro b s Ψ Q C Γ Δ Ξ ν ts hs _ _ _
    rcases sig_cases hs with ⟨_,rfl⟩ | rfl | rfl <;> trivial
  admits_renameTypes := by
    intro b s C C' Γ Δ ts ρ hs _ _ _ _
    rcases sig_cases hs with ⟨_,rfl⟩ | rfl | rfl <;> trivial
  admits_subst := by
    intro b s C0 C1 ts ts' es' hs _ _ _ _
    rcases sig_cases hs with ⟨_,rfl⟩ | rfl | rfl <;> trivial
  external_typed := by intro Ψ f d ts vs a e out obs hw hs; cases hs
  external_exists := by intro Ψ f d ts vs a e hw hs; cases hs
  external_no_targets := by intro Ψ f d ts vs a e out obs hw hs; cases hs
  delta_typed := by
    intro Ψ b s ts es rs ws a e hs hk
    rcases sig_cases hs with ⟨_,rfl⟩ | rfl | rfl <;> cases hk
  io_typed := by
    intro Ψ b s ts es rs ws a e out obs hs hk ha hi
    obtain ⟨rfl, rfl, rfl⟩ := hi
    have hs' : s = evil := by simpa [sig_evil] using hs.symm
    subst hs'
    obtain ⟨rfl,rfl,rfl,rfl⟩ := args_shape ha
    exact ⟨⟨unit_typed, trivial⟩, fun _ _ _ => trivial⟩
  io_kind := by
    intro Ψ b s ts es rs ws a e out obs hs ha hi
    obtain ⟨rfl, rfl, rfl⟩ := hi
    have hs' : s = evil := by simpa [sig_evil] using hs.symm
    subst hs'
    exact Or.inl ⟨rfl, by intro n h; cases h⟩
  io_exists := by
    intro Ψ b s ts es rs ws a e hs hk ha
    rcases sig_cases hs with ⟨rfl,rfl⟩ | rfl | rfl
    · exact ⟨.val (.const .unit), [], rfl, rfl, rfl⟩
    · rcases hk with hk | hk <;> cases hk
    · rcases hk with hk | hk <;> cases hk
  pathBases_shape := by
    intro b s hs hk
    rcases sig_cases hs with ⟨_,rfl⟩ | rfl | rfl <;> cases hk
  opEff_io := by
    intro b s l hs ho
    rcases sig_cases hs with ⟨_,rfl⟩ | rfl | rfl <;> cases ho
  effect_ops := by
    intro l bs b hs hb
    change (if l = stateEff then some [] else none) = some bs at hs
    split at hs
    · cases Option.some.inj hs; cases hb
    · cases hs
  state_effect := by simp [B]
  ref_get := ⟨_, rfl, rfl⟩
  ref_set := ⟨_, rfl, rfl⟩
  store_shape := by
    intro b s hs _
    rcases sig_cases hs with ⟨_,rfl⟩ | rfl | rfl <;> simp [getS,setS,evil,PrimSig.StoreShape]
  store_admits := by
    intro b s C ts hs
    rcases sig_cases hs with ⟨_,rfl⟩ | rfl | rfl <;> intros <;> trivial

def code : Comp := .app (.prim "evil" [] [] []) []
def σ : PathEnv := ⟨[],[],[],none,none,none⟩

/-- 実行の一歩は IO の事象を出す。 -/
theorem step_io : Step P B σ (.run (Closure.pure code) [] Store.empty)
    (some (.io "evil" [] (.val (.const .unit)) []))
    (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) :=
  .E_IO rfl sig_evil rfl (by intro cap h hm; cases hm) ⟨rfl,rfl,rfl⟩

/-- 事象の被覆は opEff を要求するので、この項目ではどの効果でも成り立たない。 -/
theorem not_covered (Γ Φ ε) : ¬ Event.Covered B Γ Φ ε (.io "evil" [] (.val (.const .unit)) []) := by
  rintro ⟨s,l,r,hs,ho,_⟩
  rw [sig_evil] at hs
  cases Option.some.inj hs
  cases ho




theorem ann {Γ : Ctx} : Ty.Annotation P [] Γ (.dependentFn (.done U Eff.empty)) :=
  ⟨by simp [Ty.WF,Tel.WF,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Ty.WFList,U],by
    simp [Ty.Sorted,Tel.Sorted,U,Eff.empty,sortedEff,sortedTys],by simp [Ty.Declared,Tel.Declared,U,Eff.empty,declaredEff,declaredTys]⟩

theorem tel_eq : instantiatedTel (Tel.instR [] evil.tel) [] [] = .done U Eff.empty := by
  rw [evil_tel]
  simp [instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,
    Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Eff.norm,
    Eff.empty,mapRangesTys,mapRangeAtoms_rangeAt,instAtoms_nil,U,rawBindTys,rowFails]
  constructor
  · funext a
    cases a <;> simp [substAtoms,instAtoms,typeEnvAt]
    rename_i ix; cases ix <;> rfl
  · simp [typeEnvAt,Order.sortUnique]

theorem sigInst : SignatureInstance P [] [] (Tel.instR [] evil.tel) [] [] [] := by
  rw [evil_tel]
  refine ⟨?_,by simp [TypeAnnotations],?_,by simp [RowAnnotations],?_⟩
  · simp [Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
      Tel.norm,Ty.norm,Ty.normTys,Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,
      mapRangesTys,Order.sortUnique,mapRangeAtoms_rangeAt,instAtoms_nil,U]
  · exact ⟨rfl,[],rfl,by intro i t kind ht; cases ht⟩
  · have := tel_eq; rw [evil_tel] at this; rw [this]; exact ann

theorem prim_typed : HasTypeV P B StoreTy.empty [] [] [] (.prim "evil" [] [] [])
    (.dependentFn (.done U Eff.empty)) := by
  have h : HasTypeV P B StoreTy.empty [] [] [] (.prim "evil" [] [] [])
      (.dependentFn (instantiatedTel (Tel.instR [] evil.tel) [] [])) := by
    apply HasTypeVQ.V_Prim sig_evil
    · exact ⟨rfl,by simp,by simp,Or.inl (by simp)⟩
    · simp [NamesWF,evil]
    · refine ⟨rfl,trivial,by simp,rfl,by simp,?_,?_,?_⟩
      · simp [evil,Eff.RowsIn,Eff.empty,Ty.RowsInList]
      · intro i hi; simp [evil,Qsig,QTys,QTy,QEff,Eff.empty,Qempty] at hi
      · intro i hi; simp [evil,Qsig,QTys,QTy,QEff,Eff.empty,Qempty] at hi
    · exact sigInst
  rwa [tel_eq] at h

theorem typed : HasTypeC P B StoreTy.empty [] [] [] none code U Eff.empty :=
  .C_DependentApp prim_typed (.done ann)

#print axioms assumptions
#print axioms typed
#print axioms step_io
#print axioms not_covered
end
end Benitoite.Release.Refinement.RV15
