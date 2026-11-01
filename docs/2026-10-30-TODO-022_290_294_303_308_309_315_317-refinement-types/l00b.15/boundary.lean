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

set_option linter.unusedSimpArgs false
namespace Benitoite.Release.Refinement.Boundary15Full
noncomputable section
def P : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
abbrev U : Ty := .base .unit
def ioE : Eff := Eff.single "IO"
def plainS : PrimSig := ⟨[],0,[],[],U,ioE,fun _ ts => ts.length = 0,.io,some "IO",[],.untargeted⟩
def singleE : Eff := .mk (fun a => decide (a = .name "File.Read" (.rvar 0))) []
/-- 単一の対象の形。引数は旧と同じ opaque o (rvar 0)。 -/
def singleS : PrimSig := ⟨[],0,["path"],[.opaque "PathIn" (.rvar 0)],U,singleE,fun _ ts => ts.length = 0,.io,some "File.Read",[.path],.single .path 0⟩
def basesS : PrimSig := ⟨[],0,[],[],.pathBases,Eff.single processEnvironmentEff,fun _ ts => ts.length = 0,.pathBases,some processEnvironmentEff,[],.untargeted⟩
def getS : PrimSig := ⟨[{}],0,["reference"],[.reference (.tvar 0)],.tvar 0,Eff.single stateEff,fun _ ts => ts.length = 1,.refGet,none,[],.untargeted⟩
def setS : PrimSig := ⟨[{}],0,["reference","value"],[.reference (.tvar 0),.tvar 0],U,Eff.single stateEff,fun _ ts => ts.length = 1,.refSet,none,[],.untargeted⟩
def B : Builtins :=
  { sig := fun b => if b = "plain" then some plainS else if b = "single" then some singleS else
      if b = "bases" then some basesS else if b = "get" then some getS else if b = "set" then some setS else none,
    delta := fun _ _ _ _ _ => none,
    ioResponse := fun b _ _ _ o obs => (b = "plain" ∨ b = "single") ∧ o = .err "e" ∧ obs = [],
    releaseResponse := fun _ _ => True, isResource := fun _ => false,
    effects := fun l => if l = stateEff then some [] else if l = "IO" then some ["plain"] else
      if l = "File.Read" then some ["single"] else if l = processEnvironmentEff then some ["bases"] else none,
    sat := fun _ _ _ => True, refGet := "get", refSet := "set",
    effKind := fun l => if l = "File.Read" then some .path else none,
    valKind := fun o => if o = "PathIn" then some .path else none }
theorem sig_cases {b s} (hs : B.sig b = some s) :
    (b = "plain" ∧ s = plainS) ∨ (b = "single" ∧ s = singleS) ∨ (b = "bases" ∧ s = basesS) ∨ s = getS ∨ s = setS := by
  change (if b = "plain" then _ else if b = "single" then _ else if b = "bases" then _ else
    if b = "get" then _ else if b = "set" then _ else none) = some s at hs
  repeat' split at hs
  all_goals first
    | exact Or.inl ⟨by assumption,(Option.some.inj hs).symm⟩
    | exact Or.inr (Or.inl ⟨by assumption,(Option.some.inj hs).symm⟩)
    | exact Or.inr (Or.inr (Or.inl ⟨by assumption,(Option.some.inj hs).symm⟩))
    | exact Or.inr (Or.inr (Or.inr (Or.inl (Option.some.inj hs).symm)))
    | exact Or.inr (Or.inr (Or.inr (Or.inr (Option.some.inj hs).symm)))
    | cases hs
theorem eff_cases {l bs} (he : B.effects l = some bs) :
    (l = stateEff ∧ bs = []) ∨ (l = "IO" ∧ bs = ["plain"]) ∨ (l = "File.Read" ∧ bs = ["single"]) ∨ (l = processEnvironmentEff ∧ bs = ["bases"]) := by
  change (if l = stateEff then some [] else if l = "IO" then some ["plain"] else
      if l = "File.Read" then some ["single"] else if l = processEnvironmentEff then some ["bases"] else none) = some bs at he
  repeat' split at he
  all_goals first
    | exact Or.inl ⟨by assumption,(Option.some.inj he).symm⟩
    | exact Or.inr (Or.inl ⟨by assumption,(Option.some.inj he).symm⟩)
    | exact Or.inr (Or.inr (Or.inl ⟨by assumption,(Option.some.inj he).symm⟩))
    | exact Or.inr (Or.inr (Or.inr ⟨by assumption,(Option.some.inj he).symm⟩))
    | cases he

theorem assumptions : Builtins.CoreAssumptions P B where
  sat_unconstrained := by intros; trivial
  admits_sat := by
    intro b s C ts hs ha
    refine ⟨?_, by intros; trivial⟩
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl <;>
      simpa [plainS,singleS,basesS,getS,setS,Ty.normTys_eq_map] using ha
  release_exists := by intros; exact ⟨none, trivial⟩
  sat_rename := by intros; trivial
  sat_values := by intros; trivial
  sat_renameTypes := by intros; trivial
  sat_subst := by intros; trivial
  admits_rename := by
    intro b s C Γ Δ ts ξ hs _ _ _ _
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl <;> simp_all [plainS,singleS,basesS,getS,setS,Ty.normTys_eq_map]
  admits_values := by
    intro b s Ψ Q C Γ Δ Ξ ν ts hs _ _ _
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl <;> simp_all [plainS,singleS,basesS,getS,setS,Ty.normTys_eq_map]
  admits_renameTypes := by
    intro b s C C' Γ Δ ts ρ hs _ _ _ _
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl <;> simp_all [plainS,singleS,basesS,getS,setS,Ty.normTys_eq_map]
  admits_subst := by
    intro b s C0 C1 ts ts' es' hs _ _ _ _
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl <;> simp_all [plainS,singleS,basesS,getS,setS,Ty.normTys_eq_map]
  external_typed := by intro Ψ f d ts vs a e out obs hw hs; cases hs
  external_exists := by intro Ψ f d ts vs a e hw hs; cases hs
  external_no_targets := by intro Ψ f d ts vs a e out obs hw hs; cases hs
  delta_typed := by
    intro Ψ b s ts es rs ws a e hs hk
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl <;> cases hk
  io_typed := by
    intro Ψ b s ts es rs ws a e out obs hs hk ha hi
    obtain ⟨_, rfl, rfl⟩ := hi
    exact ⟨trivial, fun _ _ _ => trivial⟩
  io_kind := by
    intro Ψ b s ts es rs ws a e out obs hs ha hi
    obtain ⟨hb, rfl, rfl⟩ := hi
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨h,rfl⟩|rfl|rfl
    · exact Or.inl ⟨rfl, by intro n h; cases h⟩
    · exact Or.inl ⟨rfl, by intro n h; cases h⟩
    · rcases hb with rfl|rfl <;> exact absurd h (by decide)
    all_goals (rcases hb with rfl|rfl <;> cases (Option.some.inj hs))
  io_exists := by
    intro Ψ b s ts es rs ws a e hs hk ha
    rcases sig_cases hs with ⟨rfl,rfl⟩|⟨rfl,rfl⟩|⟨_,rfl⟩|rfl|rfl
    · exact ⟨.err "e", [], Or.inl rfl, rfl, rfl⟩
    · exact ⟨.err "e", [], Or.inr rfl, rfl, rfl⟩
    all_goals (rcases hk with hk|hk <;> cases hk)
  pathBases_shape := by
    intro b s hs hk
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨rfl,rfl⟩|rfl|rfl <;> try cases hk
    exact ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,["bases"],by simp [B,processEnvironmentEff,stateEff],by simp⟩
  io_op := by
    intro b s hs hk
    rcases sig_cases hs with ⟨rfl,rfl⟩|⟨rfl,rfl⟩|⟨_,rfl⟩|rfl|rfl
    · exact ⟨"IO",["plain"],rfl,rfl,by simp [B,stateEff],by simp,by simp [plainS,B,ioE]⟩
    · refine ⟨"File.Read",["single"],rfl,rfl,by simp [B,stateEff],by simp,?_⟩
      simp [singleS,singleE,B]
    all_goals (rcases hk with hk|hk <;> cases hk)
  opEff_io := by
    intro b s l hs ho
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl
    · exact Or.inl rfl
    · exact Or.inl rfl
    · exact Or.inr (Or.inr rfl)
    all_goals cases ho
  effect_ops := by
    intro l bs b he hb
    rcases eff_cases he with ⟨rfl,rfl⟩|⟨rfl,rfl⟩|⟨rfl,rfl⟩|⟨rfl,rfl⟩
    · cases hb
    · cases List.mem_singleton.mp hb; exact ⟨plainS,rfl,Or.inl rfl,rfl⟩
    · cases List.mem_singleton.mp hb; exact ⟨singleS,rfl,Or.inl rfl,rfl⟩
    · cases List.mem_singleton.mp hb; exact ⟨basesS,rfl,Or.inr (Or.inr rfl),rfl⟩
  state_effect := by simp [B]
  ref_get := ⟨_, rfl, rfl⟩
  ref_set := ⟨_, rfl, rfl⟩
  store_shape := by
    intro b s hs hk
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl
    · simp [plainS,PrimSig.StoreShape]
    · simp [singleS,PrimSig.StoreShape]
    · exact absurd rfl hk
    all_goals simp [getS,setS,PrimSig.StoreShape]
  store_admits := by
    intro b s C ts hs
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl <;> intros <;> simp_all [plainS,singleS,basesS,getS,setS]
theorem core_nonempty : ∃ P B, Builtins.CoreAssumptions P B := ⟨P, B, assumptions⟩

theorem single_shape : B.ShapeOk "single" singleS :=
  assumptions.io_op "single" singleS rfl (Or.inl rfl)

#print axioms assumptions
#print axioms single_shape
#print axioms core_nonempty
end
end Benitoite.Release.Refinement.Boundary15Full

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn "Benitoite.Release.Refinement.Boundary15").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
