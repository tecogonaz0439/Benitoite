import Lean
import Benitoite.Release.Refinement.BuiltinEffects
import Benitoite.Release.Refinement.ReferencePreservation

namespace Benitoite.Release.Refinement.Boundary15
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

/-- レビューの表は新しい io_op の条件を満たさない。 -/
theorem rejects_evil : ¬ Builtins.CoreAssumptions P B := by
  intro h
  obtain ⟨l, bs, ho, _⟩ := h.io_op "evil" evil sig_evil (Or.inl rfl)
  cases ho

/-- top は固定範囲の全式を覆うが、範囲変数は覆わない。 -/
example : ¬ RangeIx.Covers (.fixed .top) (.rvar 0) := by
  intro h
  cases h

#print axioms rejects_evil

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

#print axioms typed
#print axioms step_io
#print axioms not_covered

/-- 旧の対象なしの形は、新しい表でも同じ条件で受理する。 -/
def ioSig : PrimSig := { evil with opEff := some "IO", eff := Eff.single "IO" }
def ioB : Builtins := { B with sig := fun _ => some ioSig, effects := fun _ => some ["io"] }
theorem accepts_io_shape : ioB.ShapeOk "io" ioSig :=
  ⟨"IO", ["io"], rfl, rfl, rfl, by simp, rfl, rfl, rfl⟩

/-- PathBases の署名の形だけでは、空の操作表への所属を作れない。 -/
def basesSig : PrimSig := { evil with kind := .pathBases, ret := .pathBases, opEff := some processEnvironmentEff, eff := Eff.single processEnvironmentEff }
def missingBases : Builtins := { B with sig := fun _ => some basesSig, effects := fun _ => some [] }
theorem rejects_missing_pathBases_member : ¬ Builtins.CoreAssumptions P missingBases := by
  intro h
  obtain ⟨bs, he, hm⟩ := (h.pathBases_shape "bases" basesSig rfl rfl).membership
  change some [] = some bs at he
  cases Option.some.inj he
  cases hm

def basesB : Builtins := { missingBases with effects := fun _ => some ["bases"] }
theorem accepts_pathBases_shape : basesSig.PathBasesShape basesB "bases" :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, ["bases"], rfl, by simp⟩

#print axioms accepts_io_shape
#print axioms rejects_missing_pathBases_member
#print axioms accepts_pathBases_shape

end
end Benitoite.Release.Refinement.Boundary15
