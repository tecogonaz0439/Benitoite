import Lean
import Benitoite.Release.Refinement.BuiltinEffects
import Benitoite.Release.Refinement.ReferencePreservation
set_option linter.unusedSimpArgs false
namespace Benitoite.Release.Refinement.RV15b
noncomputable section
def P : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
abbrev U : Ty := .base .unit
def ioE : Eff := Eff.single "IO"
def plainS : PrimSig := ⟨[],0,[],[],U,ioE,fun _ _ => True,.io,some "IO",[],.untargeted⟩
def singleE : Eff := .mk (fun a => decide (a = .name "File.Read" (.rvar 0))) []
/-- 単一の対象の形。引数は旧と同じ opaque o (rvar 0)。 -/
def singleS : PrimSig := ⟨[],0,["path"],[.opaque "PathIn" (.rvar 0)],U,singleE,fun _ _ => True,.io,some "File.Read",[.path],.single .path 0⟩
def basesS : PrimSig := ⟨[],0,[],[],.pathBases,Eff.single processEnvironmentEff,fun _ _ => True,.pathBases,some processEnvironmentEff,[],.untargeted⟩
def getS : PrimSig := ⟨[{}],0,["reference"],[.reference (.tvar 0)],.tvar 0,Eff.single stateEff,fun _ _ => True,.refGet,none,[],.untargeted⟩
def setS : PrimSig := ⟨[{}],0,["reference","value"],[.reference (.tvar 0),.tvar 0],U,Eff.single stateEff,fun _ _ => True,.refSet,none,[],.untargeted⟩
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
  sat_rename := by intros; trivial
  sat_values := by intros; trivial
  sat_renameTypes := by intros; trivial
  sat_subst := by intros; trivial
  admits_rename := by
    intro b s C Γ Δ ts ξ hs _ _ _ _
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl <;> trivial
  admits_values := by
    intro b s Ψ Q C Γ Δ Ξ ν ts hs _ _ _
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl <;> trivial
  admits_renameTypes := by
    intro b s C C' Γ Δ ts ρ hs _ _ _ _
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl <;> trivial
  admits_subst := by
    intro b s C0 C1 ts ts' es' hs _ _ _ _
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl <;> trivial
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
    rcases sig_cases hs with ⟨_,rfl⟩|⟨_,rfl⟩|⟨_,rfl⟩|rfl|rfl <;> intros <;> trivial
#print axioms assumptions
end
end Benitoite.Release.Refinement.RV15b
