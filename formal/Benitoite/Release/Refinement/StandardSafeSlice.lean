import Benitoite.Release.Refinement.StandardSafeBodies

/-! # 内部List.sliceの停止枝と有限列の長さ -/
namespace Benitoite.Release.Refinement.StandardSafeSlice
open InternalContracts StandardSafe
noncomputable section
set_option maxRecDepth 5000
set_option maxHeartbeats 1000000
set_option linter.unusedSimpArgs false

/-- 実組込みと同じfront/backの検査。列の全長に機械整数の上限を仮定しない。 -/
def sliceReply (xs : List Val) (front back : Integer64Value) : Outcome :=
 if front.toInt < 0 ∨ 4294967295 < front.toInt ∨ back.toInt < 0 ∨ 4294967295 < back.toInt
 then .err "invalid list pattern slice bounds"
 else if xs.length < back.toInt.toNat ∨ xs.length-back.toInt.toNat < front.toInt.toNat
 then .err "list pattern slice out of bounds"
 else .val (.list ((xs.drop front.toInt.toNat).take (xs.length-back.toInt.toNat-front.toInt.toNat)))

def slicePredicate (xs front back : Term) : Pred :=
 .eq (length (.var 0)) (.add (.add (length xs) (.neg front)) (.neg back))
def sliceType (a : Ty) (xs front back : Term) : Ty := .refined (.list a) (slicePredicate xs front back)

/-- 通常の3引数を保ち、正常結果だけに正確な長さを与える内部契約。 -/
def sliceSignature : PrimSig :=
 ⟨C,0,["xs","front","back"],[.list (.tvar 0),.base .integer,.base .integer],
  sliceType (.tvar 0) (.var 3) (.var 2) (.var 1),Eff.empty,(fun _ ts => ts.length=1),
  .pure,none,[],.untargeted⟩

def sliceDelta (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
 (ws : List Val) : Option Outcome :=
 match name,ts,es,rs,ws with
 | "%List.slice",[_],[],[],[.list xs,.const (.integer front),.const (.integer back)] => some (sliceReply xs front back)
 | _,_,_,_,_ => none

private theorem each_subset {P B Ψ a xs ys}
 (typed : HasTypeEachQ P B Ψ Qempty [] [] [] xs a) (sub : ∀ x ∈ ys, x ∈ xs) :
 HasTypeEachQ P B Ψ Qempty [] [] [] ys a := by
 induction ys with
 | nil => exact .nil
 | cons x ys ih => exact .cons (typed.member (sub x (by simp))) (ih (fun y hy => sub y (by simp [hy])))

private theorem closed_subset {xs ys} (ground : (Val.list xs).Ground) (sub : ∀ x ∈ ys, x ∈ xs) :
 (Val.list ys).Ground := by
 change Val.ClosedList 0 0 ys
 induction ys with
 | nil => trivial
 | cons x ys ih => exact ⟨(show Val.ClosedList 0 0 xs from ground).member (sub x (by simp)),ih (fun y hy => sub y (by simp [hy]))⟩

private theorem adequate_member {σ xs v} (h : adequateVals σ xs) (mem : v ∈ xs) : v.Adequate σ := by
 induction xs with
 | nil => cases mem
 | cons x xs ih =>
  rcases List.mem_cons.mp mem with rfl | mem
  · exact h.1
  · exact ih h.2 mem
private theorem adequate_subset {σ xs ys} (adequate : adequateVals σ xs) (sub : ∀ x ∈ ys, x ∈ xs) :
 adequateVals σ ys := by
 induction ys with
 | nil => trivial
 | cons x ys ih => exact ⟨adequate_member adequate (sub x (by simp)),ih (fun y hy => sub y (by simp [hy]))⟩

/-- 正常な切出しは同じdrop/take列であり、長さの算術と元要素の型を保つ。 -/
theorem slice_selected {P B Ψ a xs} (front back : Integer64Value)
 (typed : HasTypeEachQ P B Ψ Qempty [] [] [] xs a)
 (nonnegative : 0≤front.toInt ∧ 0≤back.toInt)
 (fits : front.toInt≤4294967295 ∧ back.toInt≤4294967295)
 (inside : front.toInt.toNat+back.toInt.toNat≤xs.length) :
 let ys := (xs.drop front.toInt.toNat).take (xs.length-back.toInt.toNat-front.toInt.toNat)
 sliceReply xs front back = .val (.list ys) ∧
 (ys.length : Int) = (xs.length : Int)-front.toInt-back.toInt ∧
 HasTypeEachQ P B Ψ Qempty [] [] [] ys a := by
 have sub : ∀ x ∈ (xs.drop front.toInt.toNat).take (xs.length-back.toInt.toNat-front.toInt.toNat), x ∈ xs := by
  intro x hx
  exact List.mem_of_mem_drop (List.mem_of_mem_take hx)
 have len : ((xs.drop front.toInt.toNat).take (xs.length-back.toInt.toNat-front.toInt.toNat)).length =
  xs.length-back.toInt.toNat-front.toInt.toNat := by
  simp only [List.length_take,List.length_drop]
  omega
 refine ⟨?_,?_,each_subset typed sub⟩
 · simp [sliceReply,show ¬front.toInt<0 from by omega,show ¬back.toInt<0 from by omega,
    show ¬4294967295<front.toInt from by omega,show ¬4294967295<back.toInt from by omega,
    show ¬xs.length<back.toInt.toNat from by omega,
    show ¬xs.length-back.toInt.toNat<front.toInt.toNat from by omega]
 · rw [len]
   have f : (front.toInt.toNat : Int)=front.toInt := Int.toNat_of_nonneg nonnegative.1
   have b : (back.toInt.toNat : Int)=back.toInt := Int.toNat_of_nonneg nonnegative.2
   omega

private theorem slice_fact (xs ys : List Val) (front back : Int)
 (gx : (Val.list xs).Ground) (gy : (Val.list ys).Ground)
 (len : (ys.length : Int) = (xs.length : Int)-front-back) :
 ((slicePredicate (.listValue (Val.toTermSlots xs)) (.integer front) (.integer back)).open
  (.listValue (Val.toTermSlots ys))).evalClosed = some true := by
 have wx : termWF 0 (.listValue (Val.toTermSlots xs)) := Val.observation_wf gx rfl
 have wy : termWF 0 (.listValue (Val.toTermSlots ys)) := Val.observation_wf gy rfl
 have bx (ν : ObservationEnv) : termBind ν (.listValue (Val.toTermSlots xs)) = .listValue (Val.toTermSlots xs) := by
  unfold termBind
  rw [Term.bind_closed wx ν]
  rfl
 have rx : Term.References [] (.listValue (Val.toTermSlots xs)) := Term.varsIn_mono wx (by intro i hi; omega)
 have ry : Term.References [] (.listValue (Val.toTermSlots ys)) := Term.varsIn_mono wy (by intro i hi; omega)
 simp only [slicePredicate,length,Pred.open,predBind,termBind_measure,termBind_add,termBind_neg,
  termBind_integer,termBind_var,bx]
 simp only [termWF,Term.VarsIn,Val.toTermSlots_eq_map,Nat.not_lt_zero] at wx wy
 simp only [Term.References,Term.VarsIn,Val.toTermSlots_eq_map] at rx ry
 simp [Pred.evalClosed,Pred.evalWith,Pred.atomReady,Pred.atomValue,termReady,integerAs,observeAs,
  Pred.WF,Pred.VarsIn,Term.VarsIn,Pred.Sorted,Term.HasSort,Term.Shape,Term.References,rx,ry,Measure.input,Measure.output,
  Term.observe,Term.interpret,Observation.sort,Observation.measure,Observation.integerD,
  MatchFacts.observeSlots_length,Val.toTermSlots_eq_map,len,Int.sub_eq_add_neg,wx,wy,termWF]

/-- 追加した精密結果の注釈の下で、同じ実slice応答を型付ける。 -/
theorem slice_reply {P B Ψ a xs} (front back : Integer64Value)
 (ann : Ty.Annotation P [] [] a)
 (ret : Ty.Annotation P [] [] (sliceType a (.listValue (Val.toTermSlots xs)) (.integer front.toInt) (.integer back.toInt)))
 (typed : HasTypeEachQ P B Ψ Qempty [] [] [] xs a) (ground : (Val.list xs).Ground) :
 Outcome.Typed P B Ψ (sliceReply xs front back)
  (sliceType a (.listValue (Val.toTermSlots xs)) (.integer front.toInt) (.integer back.toInt)) ∧
 AdequateResult [.list xs,.const (.integer front),.const (.integer back)] (sliceReply xs front back) ∧
 (∀ n, sliceReply xs front back ≠ .exit n) := by
 unfold sliceReply
 split
 · exact ⟨trivial,(fun _ _ _ => True.intro),by intros; intro h; cases h⟩
 · rename_i valid
   split
   · exact ⟨trivial,(fun _ _ _ => True.intro),by intros; intro h; cases h⟩
   · rename_i inside
     have nonnegative : 0≤front.toInt ∧ 0≤back.toInt := by omega
     have fits : front.toInt≤4294967295 ∧ back.toInt≤4294967295 := by omega
     have bounds : front.toInt.toNat+back.toInt.toNat≤xs.length := by omega
     have selected := slice_selected front back typed nonnegative fits bounds
     let ys := (xs.drop front.toInt.toNat).take (xs.length-back.toInt.toNat-front.toInt.toNat)
     have sub : ∀ x ∈ ys, x ∈ xs := by intro x hx; exact List.mem_of_mem_drop (List.mem_of_mem_take hx)
     refine ⟨⟨?_,closed_subset ground sub⟩,?_,by intro n h; cases h⟩
     · exact .V_Refine (.V_List selected.2.2 ann.wf ann.sorted ann.declared) rfl rfl
        ret.sorted.2 ret.wf.2.1 (CaptureOk.evaluated_fact (slice_fact xs ys _ _ ground (closed_subset ground sub) selected.2.1))
        ret.declared.1 ret.declared.2
     · intro σ _ input
       exact adequate_subset (input (.list xs) (by simp)) sub

local macro "slice_simp" : tactic => `(tactic|
 simp [sliceSignature,sliceType,slicePredicate,length,C,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
  Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,
  Tel.bind,Tel.rawBind,Ty.bind,Ty.rawBind,Ty.norm,Ty.normTys,Tel.norm,rawBindTys,
  typeEnvAt,SubstEnv.up,Eff.rawBind,Eff.norm,Eff.empty,rowFails,substAtoms_nil,instAtoms_nil,
  predBind,termBind,termBind?,upValues,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
  Pred.conjuncts,Pred.ofConjuncts,Ty.core,Ty.shiftV,Term.bind_closed,Tel.argumentsEnv,valEnv,
  Ty.WF,Ty.WFList,Tel.WF,Ty.NotContCore,Pred.WF,Pred.VarsIn])

private theorem slice_tel {U : Ty} (wf : U.WF 0 0 0) :
 instantiatedTel (Tel.instR [] sliceSignature.tel) [U] [] =
 .param "xs" (.list U.norm) (.param "front" (.base .integer) (.param "back" (.base .integer)
  (.done (sliceType U.norm (.var 3) (.var 2) (.var 1)) Eff.empty))) := by
 have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
  funext a; cases a <;> simp [mapRangeAtoms]
 slice_simp
 simp [emptyRange,Ty.shiftV_of_wf_zero wf]

private theorem list_elements {P B Ψ v a}
 (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (.list a))
 (ann : Ty.Annotation P [] [] a) :
 ∃ xs, v = .list xs ∧ HasTypeEachQ P B Ψ Qempty [] [] [] xs a := by
 obtain ⟨xs,b,rfl,hs,le⟩ := typed.canonical_list rfl
 have all : ∀ ys : List Val, (∀ x ∈ ys, x ∈ xs) → HasTypeEachQ P B Ψ Qempty [] [] [] ys a := by
  intro ys sub
  induction ys with
  | nil => exact .nil
  | cons x ys ih => exact .cons (.V_Sub (hs.member (sub x (by simp))) le ann.wf ann.sorted ann.declared) (ih (fun y hy => sub y (by simp [hy])))
 exact ⟨xs,rfl,all xs (by intro x h; exact h)⟩
private theorem integer_shape {P B Ψ v}
 (h : HasTypeVQ P B Ψ Qempty [] [] [] v (.base .integer)) :
 ∃ n : Integer64Value, v = .const (.integer n) := by
 obtain ⟨c,rfl,_,hc⟩ := h.canonical_scalar rfl
 cases c <;> cases hc
 exact ⟨_,rfl⟩

/-- 全ての型・行・範囲・実引数を、同じsliceδと精密な結果へ接続する。 -/
theorem slice_response {P B Ψ ts es rs ws a e}
 (args : BuiltinArgs P B Ψ "%List.slice" sliceSignature ts es rs ws a e) :
 ∃ out, sliceDelta "%List.slice" ts es rs ws = some out ∧
 Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) := by
 have ts1 : ts.length=1 := args.admissible.typeCount
 obtain ⟨U,rfl⟩ := List.length_eq_one_iff.mp ts1
 have es0 : es=[] := List.length_eq_zero_iff.mp args.admissible.rowCount
 have rs0 : rs=[] := List.length_eq_zero_iff.mp args.ranges.1
 subst es; subst rs
 have ann := args.signature.types U (by simp)
 have values := args.arguments
 rw [slice_tel ann.wf] at values
 cases values with
 | param _ hx rest =>
  obtain ⟨xs,rfl,each⟩ := list_elements hx ann.norm
  have ground := args.ground (.list xs) (by simp)
  have wx : termWF 0 (.listValue (Val.toTermSlots xs)) := Val.observation_wf ground rfl
  have bx (ν : ObservationEnv) : bindSlots ν (Val.toTermSlots xs) = Val.toTermSlots xs := by
   have h := Term.bind_closed wx ν
   exact Term.listValue.inj (Option.some.inj h)
  have closed (ν : ObservationEnv) : Ty.rawBind ⟨Ty.tvar,[],[],ν⟩ U.norm = U.norm := by
   rw [←Ty.rawSubstV_eq_rawBind,Ty.rawSubstV_of_wf_zero ann.norm.wf]
  simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Tel.argumentsEnv,valEnv,
   SubstEnv.up,rawBindTys,Ty.normTys,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
   Pred.conjuncts,Pred.ofConjuncts,Ty.core,Eff.norm,Eff.empty,rowFails,substAtoms_nil,instAtoms_nil,
   sliceType,slicePredicate,length,predBind,termBind,termBind?,upValues,Val.toTerm?,closed,bx,←Val.toTermSlots_eq_map] at rest
  try simp only [Ty.shiftV,closed,Ty.norm_idem] at rest
  cases rest with
  | param _ hf tail =>
   obtain ⟨front,rfl⟩ := integer_shape hf
   simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Tel.argumentsEnv,valEnv,
    SubstEnv.up,rawBindTys,Ty.normTys,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
    Pred.conjuncts,Pred.ofConjuncts,Ty.core,Eff.norm,Eff.empty,rowFails,substAtoms_nil,instAtoms_nil,
    sliceType,slicePredicate,length,predBind,termBind,termBind?,upValues,Val.toTerm?,closed,bx,←Val.toTermSlots_eq_map] at tail
   try simp only [Ty.shiftV,closed,Ty.norm_idem] at tail
   cases tail with
   | param _ hb done =>
    obtain ⟨back,rfl⟩ := integer_shape hb
    simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Tel.argumentsEnv,valEnv,
     SubstEnv.up,rawBindTys,Ty.normTys,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
     Pred.conjuncts,Pred.ofConjuncts,Ty.core,Eff.norm,Eff.empty,rowFails,substAtoms_nil,instAtoms_nil,
     sliceType,slicePredicate,length,predBind,termBind,termBind?,upValues,Val.toTerm?,closed,bx,←Val.toTermSlots_eq_map] at done
    try simp only [Ty.shiftV,closed,Ty.norm_idem] at done
    cases done with
    | done ret =>
     exact ⟨_,rfl,slice_reply front back ann.norm ⟨ret.wf.1,ret.sorted.1,ret.declared.1⟩ each ground⟩

def builtins : Builtins where
 sat := fun C a p => Benitoite.Release.satB [] C (StandardKeyTyping.carrier a) p = true
 sig := fun name => if name="%List.slice" then some sliceSignature else none
 delta := sliceDelta
 ioResponse := fun _ _ _ _ _ _ => False
 releaseResponse := fun _ _ => False
 isResource := fun _ => false
 effects := fun _ => none
 refGet := "Reference.get"
 refSet := "Reference.set"

def tailBody : Comp := .app (.prim "%List.slice" [.tvar 0] [] [])
 [.var 0,.const (.integer ⟨1,by decide⟩),.const (.integer ⟨0,by decide⟩)]
def tailRow : StandardContracts.Row :=
 ⟨"Internal.safeTail",C,0,safeTail (.tvar 0),some tailBody,.core,[.listAccess]⟩
def nonemptyTailRow : StandardContracts.Row := {tailRow with name := "Internal.NonEmptyList.tail"}
def definitions : List (FunName × Def) := [tailRow,nonemptyTailRow].filterMap fun r => r.definition.map (r.name,·)
def program : Program := StandardSafe.program (fun name => definitions.lookup name)

private theorem empty_map_range : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
 funext a; cases a <;> simp [mapRangeAtoms]

local macro "slice_formation" : tactic => `(tactic|
 simp_all [sliceSignature,sliceType,slicePredicate,length,C,a,PrimSig.tel,Def.tel,signatureTel,TypeCtx.valueParam,
  TypeCtx.kinds,TypeCtx.constraints,TParamDecl.constraints,TypeAnnotations,Ty.Annotation,
  Ty.WF,Tel.WF,Ty.WFList,Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,Ty.Declared,Tel.Declared,
  declaredTys,declaredEff,Ty.HasKind,kindsTel,kindsList,kindsEff,NamesWF,Eff.WF,Eff.Canonical,
  Eff.empty,Eff.row,Eff.norm,Ordinary,Ty.core,Ty.NotContCore,Builtins.RangeAdmissible,
  instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,
  Eff.rawMapRanges,mapRangeAtoms,empty_map_range,Tel.bind,Tel.rawBind,Ty.bind,Ty.rawBind,
  rawBindTys,Ty.norm,Tel.norm,Ty.normTys,typeEnvAt,SubstEnv.up,SubstEnv.rangesOnly,Eff.rawBind,
  rowFails,substAtoms_nil,instAtoms_nil,Qsig,QTel,QTy,QTys,QEff,Qempty,Eff.RowsIn,Tel.RowsIn,
  Ty.RowsIn,Ty.RowsInList,RowTransport,NoFail,Eff.test,Eff.atoms,Eff.fails,shiftVTys,Eff.shiftV,
  Ty.shiftV,Tel.shiftV,Ctx.extend,bindParams,localExtend,Pred.lift,liftMany,predBind,termBind,
  termBind?,upValues,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,
  Pred.ofConjuncts,Pred.Sorted,Pred.Declared,Pred.WellFormed,Pred.WF,Pred.VarsIn,Term.HasSort,
  Term.Declared,Term.References,Term.VarsIn,Term.Shape,Ty.HasSort,Ty.sort?,Measure.input,
  Measure.output,Ctx.Readable,Ctx.declarationSelf,nonempty,nonemptyType,nonemptyPredicate,
  Integer64Value.toInt,Tel.argumentsEnv,valEnv,Val.toTerm?,Tel.names,Tel.inputs,Tel.result,Tel.effect])

private theorem slice_function {Γ Φ Q} :
 HasTypeVQ program builtins StoreTy.empty Q C Γ Φ (.prim "%List.slice" [.tvar 0] [] [])
 (.dependentFn (.param "xs" (.list (.tvar 0)) (.param "front" (.base .integer)
  (.param "back" (.base .integer) (.done (sliceType (.tvar 0) (.var 3) (.var 2) (.var 1)) Eff.empty))))) := by
 have lookup : builtins.sig "%List.slice" = some sliceSignature := rfl
 have range : builtins.RangeAdmissible "%List.slice" sliceSignature [] := by slice_formation
 have names : NamesWF sliceSignature.names sliceSignature.params := by slice_formation
 have admissible : PrimitiveAdmissible C Γ.length sliceSignature Q [.tvar 0] [] := by
  constructor
  all_goals first | (solve | slice_formation) | (solve | constructor <;> slice_formation)
 have inst : SignatureInstance program C Γ (Tel.instR [] sliceSignature.tel)
  (TypeCtx.kinds sliceSignature.tparams) [.tvar 0] [] := by
  refine ⟨?_,?_,?_,?_,?_,?_⟩
  all_goals first
   | (solve | slice_formation)
   | (solve | constructor <;> slice_formation)
   | (solve | intro t ht; simp only [List.mem_singleton] at ht; subst t; constructor <;> slice_formation)
   | (solve | refine ⟨rfl,?_⟩; rintro (_|i) t k ht hk <;> slice_formation <;> subst_vars <;> slice_formation)
   | (solve | intro e he; cases he)
 have typed := HasTypeVQ.V_Prim (Ψ := StoreTy.empty) (Φ := Φ) lookup range names admissible inst
 simpa [sliceSignature,sliceType,slicePredicate,length,C,PrimSig.tel,signatureTel,instantiatedTel,
  Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
  mapRangeAtoms,empty_map_range,Tel.bind,Tel.rawBind,Ty.bind,Ty.rawBind,rawBindTys,Ty.norm,
  Tel.norm,Ty.normTys,typeEnvAt,SubstEnv.up,Eff.rawBind,rowFails,substAtoms_nil,instAtoms_nil,
  Eff.norm,Eff.empty,Ty.shiftV,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
  Pred.conjuncts,Pred.ofConjuncts,Ty.core,predBind,termBind,termBind?,upValues] using typed

private def arithmeticPremise : Pred := .eq (.var 0)
 (.add (.add (.var 1) (.neg (.integer 1))) (.neg (.integer 0)))
private def arithmeticGoal : Pred := .eq (.var 0) (.add (.var 1) (.integer (-1)))
private def arithmeticCertificate : Certificate := .refute (.consume (.consume (.consume (.consume
 (.cases
  (.consume (.derive (.combine [(1,1),(2,1)] ⟨[0,0,0,0],-1⟩) (.closeLinear 3)))
  (.consume (.derive (.combine [(0,1),(2,1)] ⟨[0,0,0,0],-1⟩) (.closeLinear 3))))))))
private theorem tail_arithmetic (x y : Term) : Entails
 [.eq x (.add (.add y (.neg (.integer 1))) (.neg (.integer 0)))]
 (.eq x (.add y (.integer (-1)))) := by
 have h : Entails [arithmeticPremise] arithmeticGoal :=
  Entails.checked (c:=arithmeticCertificate) (by decide) (.hyp List.mem_cons_self)
 simpa [arithmeticPremise,arithmeticGoal,predBind,termBind,termBind?] using
  h.bind (fun i => if i=0 then some x else some y)

private theorem tail_body : TelBodyTy program builtins StoreTy.empty (QTel (safeTail a)) C [] []
 (safeTail a) tailBody := by
 apply TelBodyTy.param
 apply TelBodyTy.done
 apply HasTypeCQ.C_Sub (a:=sliceType a (.var 1) (.integer 1) (.integer 0)) (ε:=Eff.empty)
  (HasTypeCQ.C_DependentApp slice_function ?_) ?_ (Eff.Covers.refl _ _ _) ?_ ?_ ?_
 · refine .param ⟨by slice_formation,trivial,trivial⟩ ?_ ?_
   · exact .V_Sub (.V_Var rfl (by intro b t e h; cases h)) .forget (by slice_formation) trivial trivial
   · slice_formation
     refine .param ⟨trivial,trivial,trivial⟩ (.V_Const trivial) ?_
     slice_formation
     refine .param ⟨trivial,trivial,trivial⟩ (.V_Const trivial) ?_
     slice_formation
     apply HasTypeTelArgsQ.done
     constructor <;> slice_formation
 · apply Ty.LeQ.refine .refl
   · slice_formation
   · slice_formation
   · apply (tail_arithmetic (.measure .listLength (.var 0)) (.measure .listLength (.var 1))).weaken
     intro p hp
     cases List.mem_singleton.mp hp
     exact List.mem_cons_self
 · slice_formation
 · slice_formation
 · slice_formation

private theorem tail_annotation : Ty.Annotation program C [] (.dependentFn (safeTail a)) :=
 declarations_annotation ⟨"safeTail",C,0,safeTail a,none,.core,[]⟩
 (by simp [declarationRows,InternalContracts.all,List.zipIdx,a])

/-- 既存sliceの精密応答を読む本体。固定された長さn−1を保持する。 -/
theorem tail_row_typed : tailRow.BodyTyped program builtins := by
 refine ⟨_,rfl,?_,?_,tail_annotation,tail_body⟩
 · simp [tailRow,safeTail,Tel.names,Tel.inputs,NamesWF]
 · simp [tailRow,safeTail,Tel.names,Tel.inputs,Tel.result,Tel.effect,Def.tel,signatureTel,
   Ty.HasKind,kindsTel,kindsList,kindsEff,nonempty,nonemptyType,C,a,TypeCtx.kinds,
   TypeCtx.valueParam,Ty.NotContCore,Ty.core,Ty.shiftV,Eff.empty]

example {Ψ ts es rs ws a e}
 (args : BuiltinArgs program builtins Ψ "%List.slice" sliceSignature ts es rs ws a e) :
 ∃ out, builtins.delta "%List.slice" ts es rs ws = some out ∧
 Outcome.Typed program builtins Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) := slice_response args

example {P B Ψ a xs} (typed : HasTypeEachQ P B Ψ Qempty [] [] [] xs a) (nonempty : xs≠[]) :
 sliceReply xs ⟨1,by decide⟩ ⟨0,by decide⟩ = .val (.list (xs.drop 1)) := by
 have h := slice_selected ⟨1,by decide⟩ ⟨0,by decide⟩ typed (by decide) (by decide) (by cases xs <;> simp_all [Integer64Value.toInt])
 simpa [Integer64Value.toInt,show xs.tail.take (xs.length-1)=xs.tail from List.take_of_length_le (by simp)] using h.1

/-- 二つの内部名が同じ固定Tel・本体を同じP.defsから読む。 -/
theorem registered_tails : ∀ row ∈ [tailRow,nonemptyTailRow],
 ∃ d, program.defs row.name = some d ∧ row.definition = some d ∧
 d.tel=safeTail a ∧ d.WellTyped program builtins := by
 intro row mem
 rcases List.mem_cons.mp mem with rfl | mem
 · obtain ⟨d,eq,typed⟩ := tail_row_typed
   cases Option.some.inj eq
   exact ⟨_,rfl,rfl,rfl,typed⟩
 · cases List.mem_singleton.mp mem
   obtain ⟨d,eq,typed⟩ := tail_row_typed
   cases Option.some.inj eq
   exact ⟨_,rfl,rfl,rfl,typed⟩

example : ∃ d, program.defs nonemptyTailRow.name = some d ∧ d.tel=safeTail a ∧ d.WellTyped program builtins := by
 obtain ⟨d,h,_,tel,typed⟩ := registered_tails nonemptyTailRow (by simp)
 exact ⟨d,h,tel,typed⟩
example : tailRow.tel=nonemptyTailRow.tel ∧ tailRow.tel=safeTail a := ⟨rfl,rfl⟩
example : builtins.sig "%List.slice" = some sliceSignature := rfl
example (front back : Integer64Value) (xs : List Val) :
 sliceDelta "%List.slice" [.base .unit] [] [] [.list xs,.const (.integer front),.const (.integer back)] =
 some (sliceReply xs front back) := rfl

end
end Benitoite.Release.Refinement.StandardSafeSlice
