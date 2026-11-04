import Benitoite.Release.Refinement.StandardCollectionPrecision

/-! # 同じ鍵を保ち、同長の値を入れ替える非公開の補助 -/
namespace Benitoite.Release.Refinement.StandardMapReplaceValues
open StandardCollections
noncomputable section
set_option maxRecDepth 5000
set_option maxHeartbeats 4000000
set_option linter.unusedSimpArgs false

def size (v : Term) : Term := .measure .mapSize v
def length (v : Term) : Term := .measure .listLength v
/-- Map.mapの同じ鍵の保持を、通常の本体の型付けへ渡すための非公開署名。 -/
def signature (sat : List TParam → Ty → TParam → Prop) : PrimSig :=
  ⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam,TypeCtx.valueParam],0,["m","values"],
    [.map (.tvar 0) (.tvar 1),.refined (.list (.tvar 2)) (.eq (length (.var 0)) (size (.var 1)))],
    .refined (.map (.tvar 0) (.tvar 2)) (.eq (size (.var 0)) (size (.var 2))),Eff.empty,
    (fun C ts => ts.length=3 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]?=some t → [TParam.keyC,{},{}][i]?=some p → sat C t p),
    .pure,none,[],.untargeted⟩

def replace : List MapEntry → List Val → Option (List MapEntry)
  | [],[] => some []
  | e::es,v::vs => do return {e with value := v} :: (← replace es vs)
  | _,_ => none

def pairs (a b : Ty) (es : List MapEntry) : List Val :=
  es.map (fun e => .con "Pair.Pair" [a,b] [e.key,e.value])

/-- 鍵の順と表現は元の正規化から読み、結果の構築は既存fromListの実δへ渡す。 -/
def delta (cs : List ConName) (name : PrimName) (ts : List Ty) (es : List Eff)
    (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  match name,ts,es,rs,ws with
  | "%Map.replaceValues",[a,_,b],[],[],[.mapV ks vs,.list ys] => do
    let source ← normalizedMap cs ks vs
    let output ← replace source ys
    mapDelta cs "Map.fromList" [a,b] [] [] [.list (pairs a b output)]
  | _,_,_,_,_ => none

private theorem replace_full (es : List MapEntry) (ys : List Val)
    (same : ys.length = es.length) (coherent : Coherent es) :
    ∃ output, replace es ys = some output ∧ output.map MapEntry.key = es.map MapEntry.key ∧
      output.map MapEntry.code = es.map MapEntry.code ∧ output.map MapEntry.value = ys ∧ Coherent output := by
  induction es generalizing ys with
  | nil =>
    have nil : ys=[] := List.length_eq_zero_iff.mp same
    subst ys
    exact ⟨[],rfl,rfl,rfl,rfl,by intro e h; cases h⟩
  | cons e es ih =>
    cases ys with
    | nil => simp at same
    | cons y ys =>
      have tail : ys.length = es.length := by simpa using same
      obtain ⟨out,reply,keys,codes,values,hco⟩ := ih ys tail
        (by intro x hx; exact coherent x (List.mem_cons_of_mem _ hx))
      refine ⟨{e with value := y}::out,by simp [replace,reply],by simp [keys],by simp [codes],by simp [values],?_⟩
      intro x hx
      rcases List.mem_cons.mp hx with rfl | hx
      · exact coherent e List.mem_cons_self
      · exact hco x hx


private theorem replace_pairs (a b : Ty) {source values output}
    (reply : replace source values = some output) :
    pairs a b output = List.zipWith (fun e v => .con "Pair.Pair" [a,b] [e.key,v]) source values := by
  induction source generalizing values output with
  | nil =>
    cases values with
    | nil => cases Option.some.inj reply; rfl
    | cons v vs => cases reply
  | cons e es ih =>
    cases values with
    | nil => cases reply
    | cons v vs =>
      cases hr : replace es vs with
      | none => simp [replace,hr] at reply
      | some rest =>
        have eq : output = {e with value := v}::rest := by simpa [replace,hr] using reply.symm
        subst output
        simpa only [pairs,List.map_cons,List.zipWith_cons_cons] using
          congrArg (List.cons (.con "Pair.Pair" [a,b] [e.key,v])) (ih hr)

/-- 元のキーと同じ位置のcallback結果をPairにした列へ、既存fromListを適用する同じδ。 -/
theorem delta_aligned {cs a b c ks vs ys entries}
    (normal : normalizedMap cs ks vs = some entries) (same : ys.length=entries.length) :
    delta cs "%Map.replaceValues" [a,b,c] [] [] [.mapV ks vs,.list ys] =
      mapDelta cs "Map.fromList" [a,c] [] []
        [.list (List.zipWith (fun e v => .con "Pair.Pair" [a,c] [e.key,v]) entries ys)] := by
  obtain ⟨output,replaced,_,_,_,_⟩ := replace_full entries ys same (normalized_map_coherent normal)
  simp only [delta,normal,Bind.bind,Option.bind,replaced]
  rw [replace_pairs a c replaced]

private theorem each_map {P B Ψ a} (es : List MapEntry) (f : MapEntry → Val)
    (has : ∀ e ∈ es, HasTypeVQ P B Ψ Qempty [] [] [] (f e) a) :
    HasTypeEachQ P B Ψ Qempty [] [] [] (es.map f) a := by
  induction es with
  | nil => exact .nil
  | cons e es ih =>
    exact .cons (has e List.mem_cons_self)
      (ih (fun x hx => has x (List.mem_cons_of_mem _ hx)))

private theorem adequate_member {σ xs v} (h : adequateVals σ xs) (mem : v ∈ xs) : v.Adequate σ := by
  induction xs with
  | nil => cases mem
  | cons x xs ih =>
    rcases List.mem_cons.mp mem with rfl | mem
    · exact h.1
    · exact ih h.2 mem
private theorem adequate_intro {σ xs} (h : ∀ v ∈ xs, Val.Adequate σ v) : adequateVals σ xs := by
  induction xs with
  | nil => trivial
  | cons x xs ih => exact ⟨h x List.mem_cons_self,ih (fun v hv => h v (List.mem_cons_of_mem _ hv))⟩
private theorem ground_intro {xs} (h : ∀ v ∈ xs, Val.Ground v) : Val.ClosedList 0 0 xs := by
  induction xs with
  | nil => trivial
  | cons x xs ih => exact ⟨h x List.mem_cons_self,ih (fun v hv => h v (List.mem_cons_of_mem _ hv))⟩

private theorem eq_eval {t u : Term} {n : Int}
    (ht : t.observe (fun _ => none) = some (.integer n))
    (hu : u.observe (fun _ => none) = some (.integer n)) :
    (Pred.eq t u).evalWith (fun _ => none) = some true := by
  simp [Pred.evalWith,Pred.atomReady,termReady,ht,hu,Term.observe_sound ht,Term.observe_sound hu,
    Pred.atomValue,integerAs,observeAs,Observation.sort,Observation.integerD]

private theorem response_value {P B Ψ a b c ks vs ys es}
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid) (decls : MapSetDeclarations P)
    (ha : Ty.Annotation P [] [] a) (hc : Ty.Annotation P [] [] c)
    (ordinary : Ordinary a ∧ Ordinary c) (an : a.Normal) (cn : c.Normal)
    (kinded : TypeArgsKinded P [] [a,c] [.value,.value]) (sat : B.sat [] a.norm TParam.keyC)
    (keysTyped : HasTypeEachQ P B Ψ Qempty [] [] [] ks a)
    (valuesTyped : HasTypeEachQ P B Ψ Qempty [] [] [] ys c)
    (gm : (Val.mapV ks vs).Ground) (gy : (Val.list ys).Ground)
    (normal : normalizedMap ((table.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst) ks vs = some es)
    (same : ys.length=es.length)
    (ret : Ty.Annotation P [] [] (.refined (.map a c)
      (.eq (size (.var 0)) (size (.mapValue (Val.toTermSlots ks) (Val.toTermSlots vs)))))) :
    ∃ out, delta ((table.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst)
        "%Map.replaceValues" [a,b,c] [] [] [.mapV ks vs,.list ys] = some out ∧
      Outcome.Typed P B Ψ out (.refined (.map a c)
        (.eq (size (.var 0)) (size (.mapValue (Val.toTermSlots ks) (Val.toTermSlots vs))))) ∧
      AdequateResult [.mapV ks vs,.list ys] out ∧ (∀ n,out ≠ .exit n) := by
  obtain ⟨output,replaced,keys,codes,values,coherent⟩ := replace_full es ys same (normalized_map_coherent normal)
  have distinct : (output.map MapEntry.code).Nodup := by rw [codes]; exact normalized_map_distinct normal
  have keyOrigin : ∀ e ∈ output, e.key ∈ ks := by
    intro e he
    have mem : e.key ∈ es.map MapEntry.key := keys ▸ List.mem_map_of_mem (f := MapEntry.key) he
    obtain ⟨entry,he,eq⟩ := List.mem_map.mp mem
    rw [←eq]
    exact (normalized_map_members normal entry he).1
  have valueOrigin : ∀ e ∈ output, e.value ∈ ys := by
    intro e he
    rw [←values]
    exact List.mem_map_of_mem (f := MapEntry.value) he
  have keyEach : HasTypeEachQ P B Ψ Qempty [] [] [] (output.map MapEntry.key) a :=
    each_map _ _ (fun e he => keysTyped.member (keyOrigin e he))
  have keyClosed := StandardKeyTyping.key_closed_slots table valid keyEach sat
  have typedPairs : HasTypeEachQ P B Ψ Qempty [] [] [] (pairs a c output) (.data "Pair" [a,c]) := by
    exact each_map _ _ (fun e he => pair_typed decls ha hc kinded
      (keysTyped.member (keyOrigin e he)) (valuesTyped.member (valueOrigin e he)))
  have pairGround : (Val.list (pairs a c output)).Ground := by
    apply ground_intro
    intro v hv
    obtain ⟨e,he,rfl⟩ := List.mem_map.mp hv
    refine ⟨?_,(show Val.ClosedList 0 0 ks from gm.1).member (keyOrigin e he),
      (show Val.ClosedList 0 0 ys from gy).member (valueOrigin e he),trivial⟩
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht
    · exact ha.wf
    · cases List.mem_singleton.mp ht; exact hc.wf
  obtain ⟨out,reply,base,adequate⟩ := map_fromList_full table valid decls ha hc ordinary an cn sat typedPairs pairGround
    ((table.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst)
  obtain ⟨t,ht,measure⟩ := map_fromList_unique_measure (fun _ => none) coherent distinct keyClosed reply
  have len : output.length=es.length := by simpa only [List.length_map] using congrArg List.length keys
  have sourceMeasure := normalized_map_measure (fun _ => none)
    (StandardKeyTyping.key_closed_slots table valid keysTyped sat) normal
  have inputClosed (ν : ObservationEnv) : termBind ν (.mapValue (Val.toTermSlots ks) (Val.toTermSlots vs)) =
      .mapValue (Val.toTermSlots ks) (Val.toTermSlots vs) := by
    unfold termBind
    rw [Term.bind_closed (Val.observation_wf gm rfl) ν]
    rfl
  refine ⟨.val out,by rw [delta_aligned normal same,←replace_pairs a c replaced]; exact reply,
    ⟨StandardHeadTail.refine_value base.1 ht rfl ret ?_,base.2⟩,?_,by intro n h; cases h⟩
  · have eq := eq_eval (len ▸ measure) sourceMeasure
    simpa only [size,Pred.open,predBind,termBind_measure,termBind_var,Option.getD_some,inputClosed] using eq
  · intro σ validPath inputs
    apply adequate σ validPath
    intro p hp
    cases List.mem_singleton.mp hp
    apply adequate_intro
    intro v hv
    obtain ⟨e,he,rfl⟩ := List.mem_map.mp hv
    exact ⟨adequate_member (inputs (.mapV ks vs) List.mem_cons_self).1 (keyOrigin e he),
      adequate_member (inputs (.list ys) (List.mem_cons_of_mem _ List.mem_cons_self)) (valueOrigin e he),trivial⟩

private theorem empty_range : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
  funext a; cases a <;> simp [mapRangeAtoms]
local macro "replace_simp" : tactic => `(tactic|
 simp [signature,size,length,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,
  Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,Tel.bind,Tel.rawBind,
  Ty.bind,Ty.rawBind,Ty.norm,Ty.normTys,Tel.norm,rawBindTys,typeEnvAt,SubstEnv.up,Eff.rawBind,
  Eff.norm,Eff.empty,rowFails,substAtoms_nil,instAtoms_nil,predBind,termBind,termBind?,upValues,
  Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,Ty.core,
  Ty.shiftV,Term.bind_closed,Tel.argumentsEnv,valEnv])
private theorem signature_tel (sat) {a b c : Ty}
    (wa : a.WF 0 0 0) (wc : c.WF 0 0 0) :
    instantiatedTel (Tel.instR [] (signature sat).tel) [a,b,c] [] =
      .param "m" (.map a.norm b.norm)
        (.param "values" (.refined (.list c.norm) (.eq (length (.var 0)) (size (.var 1))))
          (.done (.refined (.map a.norm c.norm) (.eq (size (.var 0)) (size (.var 2)))) Eff.empty)) := by
  replace_simp
  simp [empty_range,Ty.shiftV_of_wf_zero wa,Ty.shiftV_of_wf_zero wc]

/-- 非公開署名の全型・行・範囲・値引数から、同長性も同じ入力の型だけで導く。 -/
theorem response {P B Ψ ts es rs ws r e}
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid) (decls : MapSetDeclarations P)
    (args : BuiltinArgs P B Ψ "%Map.replaceValues" (signature B.sat) ts es rs ws r e) :
    ∃ out, delta ((table.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst)
        "%Map.replaceValues" ts es rs ws = some out ∧ Outcome.Typed P B Ψ out r ∧
      AdequateResult ws out ∧ (∀ n,out ≠ .exit n) := by
  have count : ts.length=3 := args.admissible.typeCount
  rcases ts with _ | ⟨a,ts⟩
  · cases count
  rcases ts with _ | ⟨b,ts⟩
  · cases count
  rcases ts with _ | ⟨c,ts⟩
  · cases count
  have nil : ts=[] := List.length_eq_zero_iff.mp (by simpa using count)
  subst ts
  have rows : es=[] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have ranges : rs=[] := List.length_eq_zero_iff.mp args.ranges.1
  subst es; subst rs
  have ha := args.signature.types a (by simp)
  have hb := args.signature.types b (by simp)
  have hc := args.signature.types c (by simp)
  have na : a.norm=a := (args.types a (by simp)).2
  have nb : b.norm=b := (args.types b (by simp)).2
  have nc : c.norm=c := (args.types c (by simp)).2
  have sat : B.sat [] a.norm TParam.keyC := args.admissible.admits.2 0 _ _ rfl rfl
  have kinds : TypeArgsKinded P [] [a,c] [.value,.value] := by
    refine ⟨rfl,?_⟩
    rintro (_|(_|i)) t k ht hk
    · cases Option.some.inj ht; cases Option.some.inj hk
      exact args.signature.kinds.2 0 a .value rfl rfl
    · cases Option.some.inj ht; cases Option.some.inj hk
      exact args.signature.kinds.2 2 c .value rfl rfl
    · simp at ht
  have values := args.arguments
  rw [signature_tel B.sat ha.wf hc.wf,na,nb,nc] at values
  cases values with
  | param _ source rest =>
    obtain ⟨ks,vs,rfl,hk,hv,len⟩ := typed_map_components source ha hb
    have gm := args.ground (.mapV ks vs) List.mem_cons_self
    obtain ⟨entries,normal⟩ := normalized_map_exists table valid hk sat
      ((table.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst) vs len
    have closedA (ν : ObservationEnv) : Ty.rawBind ⟨Ty.tvar,[],[],ν⟩ a = a := by
      rw [←Ty.rawSubstV_eq_rawBind,Ty.rawSubstV_of_wf_zero ha.wf]
    have closedB (ν : ObservationEnv) : Ty.rawBind ⟨Ty.tvar,[],[],ν⟩ b = b := by
      rw [←Ty.rawSubstV_eq_rawBind,Ty.rawSubstV_of_wf_zero hb.wf]
    have closedC (ν : ObservationEnv) : Ty.rawBind ⟨Ty.tvar,[],[],ν⟩ c = c := by
      rw [←Ty.rawSubstV_eq_rawBind,Ty.rawSubstV_of_wf_zero hc.wf]
    have closedInput (ν : ObservationEnv) : termBind? ν (.mapValue (Val.toTermSlots ks) (Val.toTermSlots vs)) =
        some (.mapValue (Val.toTermSlots ks) (Val.toTermSlots vs)) := Term.bind_closed (Val.observation_wf gm rfl) ν
    have closedKeys (ν : ObservationEnv) : bindSlots ν (Val.toTermSlots ks) = Val.toTermSlots ks := by
      exact Term.listValue.inj (Option.some.inj (Term.bind_closed
        (Val.observation_wf (v := .list ks) (show Val.Ground (.list ks) from gm.1) rfl) ν))
    have closedValues (ν : ObservationEnv) : bindSlots ν (Val.toTermSlots vs) = Val.toTermSlots vs := by
      exact Term.listValue.inj (Option.some.inj (Term.bind_closed
        (Val.observation_wf (v := .list vs) (show Val.Ground (.list vs) from gm.2) rfl) ν))
    simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Tel.argumentsEnv,valEnv,
      SubstEnv.up,rawBindTys,Ty.normTys,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,Ty.core,Eff.norm,Eff.empty,rowFails,substAtoms_nil,instAtoms_nil,
      size,length,predBind,termBind,termBind?,upValues,Ty.shiftV,Val.toTerm?,closedA,closedB,closedC,
      closedInput,closedKeys,closedValues,na,nb,nc,←Val.toTermSlots_eq_map] at rest
    cases rest with
    | param ann typed done =>
      have listTyped := HasTypeVQ.V_Sub typed Ty.LeQ.forget hc.wf hc.sorted hc.declared
      obtain ⟨ys,rfl,each⟩ := StandardHeadTail.list_elements listTyped hc
      have gy := args.ground (.list ys) (List.mem_cons_of_mem _ List.mem_cons_self)
      have same : ys.length = entries.length := by
        have eq : Entails [] (.eq (length (.listValue (Val.toTermSlots ys)))
            (size (.mapValue (Val.toTermSlots ks) (Val.toTermSlots vs)))) := by
          have h := typed.facts rfl
            (.eq (length (.var 0)) (size (.mapValue (Val.toTermSlots ks) (Val.toTermSlots vs))))
            (by simp [Ty.assume,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts,size,length])
          simpa [size,length,Pred.open,predBind,termBind,termBind?,upValues,closedInput,closedKeys,closedValues,Ctx.facts,←Val.toTermSlots_eq_map] using h
        have truth := Entails.sound eq (fun _ => none) (by intro p hp; cases hp)
        have hm := normalized_map_measure (fun _ => none)
          (StandardKeyTyping.key_closed_slots table valid hk sat) normal
        have hm' : (size (.mapValue (Val.toTermSlots ks) (Val.toTermSlots vs))).interpret (fun _ => none) =
            some (.integer entries.length) := Term.observe_sound hm
        have hl : (length (.listValue (Val.toTermSlots ys))).observe (fun _ => none) = some (.integer ys.length) := by
          simp [length,Term.observe,Observation.measure,Val.toTermSlots_eq_map,MatchFacts.observeSlots_length]
        simpa only [Pred.interpret,Pred.atomValue,integerAs,observeAs,hm',
          Term.observe_sound hl,Observation.sort,Observation.integerD,Option.bind_some,ite_true,decide_eq_true_eq,Int.ofNat_inj] using truth
      simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Tel.argumentsEnv,valEnv,
        SubstEnv.up,rawBindTys,Ty.normTys,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
        Pred.conjuncts,Pred.ofConjuncts,Ty.core,Eff.norm,Eff.empty,rowFails,substAtoms_nil,instAtoms_nil,
        size,length,predBind,termBind,termBind?,upValues,Ty.shiftV,Val.toTerm?,closedA,closedB,closedC,
        closedInput,closedKeys,closedValues,na,nb,nc,←Val.toTermSlots_eq_map] at done
      cases done with
      | done ret =>
        exact response_value table valid decls ha hc
          ⟨(args.admissible.typeScope a (by simp)).2,(args.admissible.typeScope c (by simp)).2⟩
          na nc kinds sat hk each gm gy normal same ⟨ret.wf.1,ret.sorted.1,ret.declared.1⟩

end
end Benitoite.Release.Refinement.StandardMapReplaceValues
