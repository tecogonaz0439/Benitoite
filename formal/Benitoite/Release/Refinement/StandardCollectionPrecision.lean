import Benitoite.Release.Refinement.StandardCollectionExamples
import Benitoite.Release.Refinement.StandardHeadTailResponse

/-! # Map・Setの構築と射影の大きさの契約 -/
namespace Benitoite.Release.Refinement.StandardCollectionPrecision
open StandardCollections
noncomputable section
set_option maxRecDepth 5000
set_option maxHeartbeats 4000000
set_option linter.unusedSimpArgs false

def size (map : Bool) (v : Term) : Term := .measure (if map then .mapSize else .setSize) v
def length (v : Term) : Term := .measure .listLength v
def predicate (map build : Bool) (result input : Term) : Pred :=
  if build then .le (size map result) (length input) else .eq (length result) (size map input)
def collection (map : Bool) (a b : Ty) : Ty := if map then .map a b else .set a
def element (map : Bool) (a b : Ty) : Ty := if map then .data "Pair" [a,b] else a
def input (map build : Bool) (a b : Ty) : Ty := if build then .list (element map a b) else collection map a b
def result (map build : Bool) (a b : Ty) : Ty := if build then collection map a b else .list (element map a b)
def name (map build : Bool) : String :=
  (if map then "Map." else "Set.") ++ (if build then "fromList" else "toList")
/-- 構築の縮約と射影の長さを、高階本体の同じ入力・出力へ渡すために記す。 -/
def signature (sat : List TParam → Ty → TParam → Prop) (map build : Bool) : PrimSig :=
  { StandardBodies.collectionPrimitiveSig sat map build with
    tparams := if map then [⟨TParam.keyC,.value⟩,TypeCtx.valueParam] else [⟨TParam.keyC,.value⟩]
    params := [input map build (.tvar 0) (.tvar 1)]
    ret := .refined (result map build (.tvar 0) (.tvar 1)) (predicate map build (.var 0) (.var 1)) }

private theorem closed_term {v : Val} {t : Term} (ground : v.Ground) (ht : v.toTerm? = some t) (ν : ObservationEnv) :
    termBind ν t = t := by
  unfold termBind
  rw [Term.bind_closed (Val.observation_wf ground ht) ν]
  rfl

private theorem list_length (xs : List Val) :
    (length (.listValue (Val.toTermSlots xs))).observe (fun _ => none) = some (.integer xs.length) := by
  simp [length,Term.observe,Observation.measure,Val.toTermSlots_eq_map,MatchFacts.observeSlots_length]

private theorem eq_eval {t u : Term} {n : Int}
    (ht : t.observe (fun _ => none) = some (.integer n))
    (hu : u.observe (fun _ => none) = some (.integer n)) :
    (Pred.eq t u).evalWith (fun _ => none) = some true := by
  simp [Pred.evalWith,Pred.atomReady,termReady,ht,hu,Term.observe_sound ht,Term.observe_sound hu,Pred.atomValue,
    integerAs,observeAs,Term.interpret,Observation.sort,Observation.integerD]

private theorem le_eval {t u : Term} {n m : Int}
    (ht : t.observe (fun _ => none) = some (.integer n))
    (hu : u.observe (fun _ => none) = some (.integer m)) (bound : n ≤ m) :
    (Pred.le t u).evalWith (fun _ => none) = some true := by
  simp [Pred.evalWith,Pred.atomReady,termReady,ht,hu,Term.observe_sound ht,Term.observe_sound hu,Pred.atomValue,
    integerAs,observeAs,Term.interpret,Observation.sort,Observation.integerD,bound]

/-- Mapの実toList/fromListの全入力。値の観測可能性は要求しない。 -/
theorem map_fact {cs a b v out} (build : Bool) (ground : v.Ground)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (input true build a b))
    (ha : Ty.Annotation P [] [] a) (hb : Ty.Annotation P [] [] b)
    (reply : mapDelta cs (name true build) [a,b] [] [] [v] = some (.val out)) :
    ∃ t u, out.toTerm? = some t ∧ v.toTerm? = some u ∧
      (predicate true build t u).evalWith (fun _ => none) = some true := by
  cases build
  · obtain ⟨ks,vs,rfl,_,_,_⟩ := typed_map_components typed ha hb
    obtain ⟨ys,rfl,measure⟩ := map_toList_layout (fun _ => none) ground reply
    exact ⟨_,_,rfl,rfl,eq_eval (list_length ys) measure⟩
  · obtain ⟨xs,e,rfl,_,_⟩ := typed.canonical_list rfl
    obtain ⟨entries,rfl,coherent,distinct,closed,bound⟩ := map_fromList_layout ground reply
    exact ⟨_,_,rfl,rfl,le_eval (map_value_measure (fun _ => none) closed coherent distinct)
      (list_length xs) (by omega)⟩

/-- Setの実toList/fromListの全入力。重複の縮約を等式へ強めない。 -/
theorem set_fact {cs a v out} (build : Bool) (ground : v.Ground)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (input false build a (.base .unit)))
    (ha : Ty.Annotation P [] [] a)
    (reply : setDelta cs (name false build) [a] [] [] [v] = some (.val out)) :
    ∃ t u, out.toTerm? = some t ∧ v.toTerm? = some u ∧
      (predicate false build t u).evalWith (fun _ => none) = some true := by
  cases build
  · obtain ⟨xs,rfl,_⟩ := typed_set_components typed ha
    obtain ⟨ys,rfl,measure⟩ := set_toList_layout (fun _ => none) ground reply
    exact ⟨_,_,rfl,rfl,eq_eval (list_length ys) measure⟩
  · obtain ⟨xs,e,rfl,_,_⟩ := typed.canonical_list rfl
    obtain ⟨entries,rfl,coherent,distinct,closed,bound⟩ := set_fromList_layout ground reply
    exact ⟨_,_,rfl,rfl,le_eval (set_value_measure (fun _ => none) closed coherent distinct)
      (list_length xs) (by omega)⟩

private theorem open_predicate (map build : Bool) {v t u}
    (ground : Val.Ground v) (observed : v.toTerm? = some u) :
    (predicate map build (.var 0) u).open t = predicate map build t u := by
  cases map <;> cases build <;>
    simp [predicate,size,length,Pred.open,predBind,termBind_measure,termBind_var,
      closed_term ground observed,Option.getD_some]

/-- Mapの型付き実入力を、その同じ実応答の精密な結果へ接続する。 -/
theorem map_response_value {P B Ψ a b v u} (build : Bool)
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid) (decls : MapSetDeclarations P)
    (ha : Ty.Annotation P [] [] a) (hb : Ty.Annotation P [] [] b)
    (ordinary : Ordinary a ∧ Ordinary b) (an : a.Normal) (bn : b.Normal)
    (kinded : TypeArgsKinded P [] [a,b] [.value,.value]) (sat : B.sat [] a.norm TParam.keyC)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (input true build a b))
    (ground : v.Ground) (observed : v.toTerm? = some u)
    (ret : Ty.Annotation P [] [] (.refined (result true build a b) (predicate true build (.var 0) u)))
    (cs : List ConName) :
    ∃ out, mapDelta cs (name true build) [a,b] [] [] [v] = some out ∧
      Outcome.Typed P B Ψ out (.refined (result true build a b) (predicate true build (.var 0) u)) ∧
      AdequateResult [v] out ∧ (∀ n,out ≠ .exit n) := by
  obtain ⟨out,delta,base,adequate,noexit⟩ := map_selected build table valid decls ha hb ordinary an bn kinded sat typed ground cs
  obtain ⟨t,u',ht,hu,eval⟩ := map_fact build ground typed ha hb (by cases build <;> exact delta)
  cases Option.some.inj (observed.symm.trans hu)
  refine ⟨.val out,(by cases build <;> exact delta),⟨?_,base.2⟩,adequate,noexit⟩
  apply StandardHeadTail.refine_value (sort := if build then .map else .list) base.1 ht (by cases build <;> rfl) ret
  rw [open_predicate true build ground observed]
  exact eval

/-- Setの型付き実入力。構築の結果は入力長以下であり、等式は要求しない。 -/
theorem set_response_value {P B Ψ a v u} (build : Bool)
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid)
    (ha : Ty.Annotation P [] [] a) (sat : B.sat [] a.norm TParam.keyC)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (input false build a (.base .unit)))
    (ground : v.Ground) (observed : v.toTerm? = some u)
    (ret : Ty.Annotation P [] [] (.refined (result false build a (.base .unit)) (predicate false build (.var 0) u)))
    (cs : List ConName) :
    ∃ out, setDelta cs (name false build) [a] [] [] [v] = some out ∧
      Outcome.Typed P B Ψ out (.refined (result false build a (.base .unit)) (predicate false build (.var 0) u)) ∧
      AdequateResult [v] out ∧ (∀ n,out ≠ .exit n) := by
  obtain ⟨out,delta,base,adequate,noexit⟩ := set_selected build table valid ha sat typed ground cs
  obtain ⟨t,u',ht,hu,eval⟩ := set_fact build ground typed ha (by cases build <;> exact delta)
  cases Option.some.inj (observed.symm.trans hu)
  refine ⟨.val out,(by cases build <;> exact delta),⟨?_,base.2⟩,adequate,noexit⟩
  apply StandardHeadTail.refine_value (sort := if build then .set else .list) base.1 ht (by cases build <;> rfl) ret
  rw [open_predicate false build ground observed]
  exact eval

local macro "instantiation_simp" : tactic => `(tactic|
 simp [signature,StandardBodies.collectionPrimitiveSig,input,result,collection,element,predicate,size,length,
  PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
  Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,Tel.bind,Tel.rawBind,Ty.bind,Ty.rawBind,Ty.norm,
  Ty.normTys,Tel.norm,rawBindTys,typeEnvAt,SubstEnv.up,Eff.rawBind,Eff.norm,Eff.empty,rowFails,
  substAtoms_nil,instAtoms_nil,predBind,termBind,termBind?,upValues,Ty.refineNorm,Ty.packRefinements,
  Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,Ty.core,Ty.shiftV,Term.bind_closed,
  Tel.argumentsEnv,valEnv])

private theorem empty_range : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
 funext a; cases a <;> simp [mapRangeAtoms]

private theorem map_tel (sat) (build : Bool) {a b : Ty} (wa : a.WF 0 0 0) (wb : b.WF 0 0 0) :
    instantiatedTel (Tel.instR [] (signature sat true build).tel) [a,b] [] =
      .param (if build then "pairs" else "m") (input true build a.norm b.norm)
        (.done (.refined (result true build a.norm b.norm) (predicate true build (.var 0) (.var 1))) Eff.empty) := by
  cases build <;> instantiation_simp <;> simp [empty_range,Ty.shiftV_of_wf_zero wa,Ty.shiftV_of_wf_zero wb]

private theorem set_tel (sat) (build : Bool) {a : Ty} (wa : a.WF 0 0 0) :
    instantiatedTel (Tel.instR [] (signature sat false build).tel) [a] [] =
      .param (if build then "xs" else "s") (input false build a.norm (.base .unit))
        (.done (.refined (result false build a.norm (.base .unit)) (predicate false build (.var 0) (.var 1))) Eff.empty) := by
  cases build <;> instantiation_simp <;> simp [empty_range,Ty.shiftV_of_wf_zero wa]

local macro "substituted_simp" rest:ident : tactic => `(tactic|
 simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Tel.argumentsEnv,valEnv,
  SubstEnv.up,rawBindTys,Ty.normTys,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
  Pred.conjuncts,Pred.ofConjuncts,Ty.core,Eff.norm,Eff.empty,rowFails,substAtoms_nil,instAtoms_nil,
  input,result,collection,element,predicate,size,length,predBind,termBind,termBind?,upValues,
  Ty.shiftV] at $rest:ident)

/-- Mapの二つの精密署名に対する全型・行・範囲・実引数。 -/
theorem map_response {P B Ψ ts es rs ws r e} (build : Bool)
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid) (decls : MapSetDeclarations P)
    (args : BuiltinArgs P B Ψ (name true build) (signature B.sat true build) ts es rs ws r e) :
    ∃ out, mapDelta ((table.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst)
        (name true build) ts es rs ws = some out ∧ Outcome.Typed P B Ψ out r ∧
      AdequateResult ws out ∧ (∀ n,out ≠ .exit n) := by
  have count : ts.length = 2 := by cases build <;> exact args.admissible.typeCount
  rcases ts with _ | ⟨a,ts⟩
  · cases count
  rcases ts with _ | ⟨b,ts⟩
  · cases count
  have nil : ts=[] := List.length_eq_zero_iff.mp (by simpa using count)
  subst ts
  have rows : es=[] := by apply List.length_eq_zero_iff.mp; cases build <;> exact args.admissible.rowCount
  have ranges : rs=[] := by apply List.length_eq_zero_iff.mp; cases build <;> exact args.ranges.1
  subst es; subst rs
  have ha := args.signature.types a (by simp)
  have hb := args.signature.types b (by simp)
  have na : a.norm=a := (args.types a (by simp)).2
  have nb : b.norm=b := (args.types b (by simp)).2
  have ordinary := And.intro (args.admissible.typeScope a (by simp)).2 (args.admissible.typeScope b (by simp)).2
  have kinded : TypeArgsKinded P [] [a,b] [.value,.value] := by
    exact args.signature.kinds
  have sat : B.sat [] a.norm TParam.keyC := by
    have h := args.admissible.admits
    cases build <;> exact h.2 0 _ _ rfl rfl
  have values := args.arguments
  rw [map_tel B.sat build ha.wf hb.wf,na,nb] at values
  cases values with
  | param _ typed rest =>
    have ground := args.ground _ List.mem_cons_self
    obtain ⟨u,hu,_⟩ := typed.observation (sort := if build then .list else .map) (by cases build <;> rfl)
    have closedA (ν : ObservationEnv) : Ty.rawBind ⟨Ty.tvar,[],[],ν⟩ a = a := by
      rw [←Ty.rawSubstV_eq_rawBind,Ty.rawSubstV_of_wf_zero ha.wf]
    have closedB (ν : ObservationEnv) : Ty.rawBind ⟨Ty.tvar,[],[],ν⟩ b = b := by
      rw [←Ty.rawSubstV_eq_rawBind,Ty.rawSubstV_of_wf_zero hb.wf]
    have closedU (ν : ObservationEnv) : termBind ν u = u := closed_term ground hu ν
    have rawClosedU (ν : ObservationEnv) : termBind? ν u = some u := Term.bind_closed (Val.observation_wf ground hu) ν
    cases build
    all_goals
      substituted_simp rest
      simp [closedA,closedB,closedU,rawClosedU,na,nb,hu,termBind,termBind?,upValues] at rest
      cases rest with
      | done ret =>
        apply map_response_value _ table valid decls ha hb ordinary na nb kinded sat typed ground hu
          ⟨ret.wf.1,ret.sorted.1,ret.declared.1⟩ _

/-- Setの二つの精密署名に対する全型・行・範囲・実引数。 -/
theorem set_response {P B Ψ ts es rs ws r e} (build : Bool)
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid)
    (args : BuiltinArgs P B Ψ (name false build) (signature B.sat false build) ts es rs ws r e) :
    ∃ out, setDelta ((table.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst)
        (name false build) ts es rs ws = some out ∧ Outcome.Typed P B Ψ out r ∧
      AdequateResult ws out ∧ (∀ n,out ≠ .exit n) := by
  have count : ts.length = 1 := by cases build <;> exact args.admissible.typeCount
  obtain ⟨a,rfl⟩ := List.length_eq_one_iff.mp count
  have rows : es=[] := by apply List.length_eq_zero_iff.mp; cases build <;> exact args.admissible.rowCount
  have ranges : rs=[] := by apply List.length_eq_zero_iff.mp; cases build <;> exact args.ranges.1
  subst es; subst rs
  have ha := args.signature.types a (by simp)
  have na : a.norm=a := (args.types a (by simp)).2
  have sat : B.sat [] a.norm TParam.keyC := by
    have h := args.admissible.admits
    cases build <;> exact h.2 0 _ _ rfl rfl
  have values := args.arguments
  rw [set_tel B.sat build ha.wf,na] at values
  cases values with
  | param _ typed rest =>
    have ground := args.ground _ List.mem_cons_self
    obtain ⟨u,hu,_⟩ := typed.observation (sort := if build then .list else .set) (by cases build <;> rfl)
    have closedA (ν : ObservationEnv) : Ty.rawBind ⟨Ty.tvar,[],[],ν⟩ a = a := by
      rw [←Ty.rawSubstV_eq_rawBind,Ty.rawSubstV_of_wf_zero ha.wf]
    have closedU (ν : ObservationEnv) : termBind ν u = u := closed_term ground hu ν
    have rawClosedU (ν : ObservationEnv) : termBind? ν u = some u := Term.bind_closed (Val.observation_wf ground hu) ν
    cases build
    all_goals
      substituted_simp rest
      simp [closedA,closedU,rawClosedU,na,hu,termBind,termBind?,upValues] at rest
      cases rest with
      | done ret =>
        apply set_response_value _ table valid ha sat typed ground hu ⟨ret.wf.1,ret.sorted.1,ret.declared.1⟩ _

end
end Benitoite.Release.Refinement.StandardCollectionPrecision
