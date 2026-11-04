import Benitoite.Release.Refinement.StandardHeadTailContracts

/-! # 精密head・tail・appendの全入力の応答 -/
namespace Benitoite.Release.Refinement.StandardHeadTail
noncomputable section
set_option maxRecDepth 5000
set_option maxHeartbeats 4000000
set_option linter.unusedSimpArgs false

private theorem open_annotation {P B Ψ a p v t}
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v a) (ht : v.toTerm? = some t)
    (ann : Ty.Annotation P [] [] (.refined a p)) : Pred.WellFormed P [] [] (p.open t) := by
  let ν : ObservationEnv := openingEnv (some t)
  have hs : Term.ImagesSorted (some a :: []) [] ν := by
    intro i b sort hi hb
    cases i with
    | zero =>
      cases Option.some.inj hi
      obtain ⟨u,hu,shape⟩ := typed.observation hb
      cases Option.some.inj (ht.symm.trans hu)
      exact ⟨t,rfl,shape⟩
    | succ i => simp at hi
  have hr : Term.ImageReferences (some a :: []) [] ν := by
    intro i b hi ho u hu
    cases i with
    | zero => cases hu; exact typed.observation_references ht
    | succ i => simp at hi
  have hp : (p.open t).Sorted [] none := ann.sorted.2.map (Δ := []) (other := none) hs hr
  have hd := DeclarationImages.drop (P := P) (C := []) (Γ := []) (a := a)
    (typed.observation_declared ht) (fun _ _ he => typed.data_observation he ht)
  exact ⟨hp.wf_none,hp,ann.declared.2.map (other := none) hd⟩

theorem refine_value {P B Ψ a p v t sort}
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v a) (ht : v.toTerm? = some t)
    (shape : a.HasSort sort) (ann : Ty.Annotation P [] [] (.refined a p))
    (eval : (p.open t).evalWith (fun _ => none) = some true) :
    HasTypeVQ P B Ψ Qempty [] [] [] v (.refined a p) := by
  have opened := open_annotation typed ht ann
  apply HasTypeVQ.V_Refine typed shape ht ann.sorted.2 ann.wf.2.1
    (Entails.closed opened.wf opened.sorted ?_) ann.declared.1 ann.declared.2
  unfold Pred.evalClosed
  rw [if_pos ⟨opened.wf,opened.sorted⟩]
  exact eval

private theorem closed_list (xs : List Val) (g : (Val.list xs).Ground) (ν : ObservationEnv) :
    termBind ν (.listValue (Val.toTermSlots xs)) = .listValue (Val.toTermSlots xs) := by
  unfold termBind
  rw [Term.bind_closed (Val.observation_wf g rfl) ν]
  rfl

/-- 型の付いた任意のhead入力。型・保持値は通常の実応答、篩は実観測から得る。 -/
theorem head_response_value {P B Ψ a xs}
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1) (ann : Ty.Annotation P [] [] a)
    (kinded : TypeArgsKinded P [] [a] [.value])
    (typed : HasTypeEachQ P B Ψ Qempty [] [] [] xs a) (ground : (Val.list xs).Ground)
    (ret : Ty.Annotation P [] [] (.refined (.data "Option" [a])
      (headPredicate (.var 0) (.listValue (Val.toTermSlots xs))))) :
    Outcome.Typed P B Ψ (.val (StandardCollections.optionValue a xs.head?))
      (.refined (.data "Option" [a]) (headPredicate (.var 0) (.listValue (Val.toTermSlots xs)))) ∧
    AdequateResult [.list xs] (.val (StandardCollections.optionValue a xs.head?)) ∧
    (∀ n, Outcome.val (StandardCollections.optionValue a xs.head?) ≠ .exit n) := by
  have ordinary := StandardListRemainingResponse.head_selected someDecl noneDecl arity ann kinded typed ground
  obtain ⟨t,ht,eval⟩ := head_reply a xs
  refine ⟨⟨refine_value ordinary.1.1 ht rfl ret ?_,ordinary.1.2⟩,ordinary.2⟩
  simpa only [headPredicate,length,Option.getD_some,Pred.open,predBind,termBind_var,termBind_measure,termBind_integer,
    closed_list xs ground] using eval

/-- 型の付いた任意のtail入力。Someの欄の長さも実tailから得る。 -/
theorem tail_response_value {P B Ψ a xs}
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1) (ann : Ty.Annotation P [] [] a)
    (kinded : TypeArgsKinded P [] [a] [.value])
    (typed : HasTypeEachQ P B Ψ Qempty [] [] [] xs a) (ground : (Val.list xs).Ground)
    (ret : Ty.Annotation P [] [] (.refined (.data "Option" [.list a])
      (tailPredicate (.var 0) (.listValue (Val.toTermSlots xs))))) :
    Outcome.Typed P B Ψ (.val (StandardCollections.optionValue (.list a) (StandardListRemainingResponse.tail? xs)))
      (.refined (.data "Option" [.list a]) (tailPredicate (.var 0) (.listValue (Val.toTermSlots xs)))) ∧
    AdequateResult [.list xs] (.val (StandardCollections.optionValue (.list a) (StandardListRemainingResponse.tail? xs))) ∧
    (∀ n, Outcome.val (StandardCollections.optionValue (.list a) (StandardListRemainingResponse.tail? xs)) ≠ .exit n) := by
  have ordinary := StandardListRemainingResponse.tail_selected someDecl noneDecl arity ann kinded typed ground
  obtain ⟨t,ht,eval⟩ := tail_reply a xs
  refine ⟨⟨refine_value ordinary.1.1 ht rfl ret ?_,ordinary.1.2⟩,ordinary.2⟩
  simpa only [tailPredicate,headPredicate,length,Option.getD_some,Pred.open,predBind,termBind_var,termBind_measure,termBind_integer,
    termBind_add,termBind_field,closed_list xs ground] using eval

private theorem ground_append {xs : List Val} {x : Val}
    (gx : (Val.list xs).Ground) (g : x.Ground) : (Val.list (xs++[x])).Ground := by
  induction xs with
  | nil => exact ⟨g,trivial⟩
  | cons y ys ih => exact ⟨gx.1,ih gx.2⟩

private theorem adequate_append {σ xs x} (gx : adequateVals σ xs) (g : Val.Adequate σ x) :
    adequateVals σ (xs++[x]) := by
  induction xs with
  | nil => exact ⟨g,trivial⟩
  | cons y ys ih => exact ⟨gx.1,ih gx.2⟩

/-- appendの入力列・要素・篩を同じ実応答へ渡す。 -/
theorem append_response_value {P B Ψ a xs x}
    (ann : Ty.Annotation P [] [] a) (typed : HasTypeEachQ P B Ψ Qempty [] [] [] xs a)
    (element : HasTypeVQ P B Ψ Qempty [] [] [] x a)
    (ground : (Val.list xs).Ground) (gx : x.Ground)
    (ret : Ty.Annotation P [] [] (.refined (.list a)
      (appendPredicate (.var 0) (.listValue (Val.toTermSlots xs))))) :
    Outcome.Typed P B Ψ (.val (.list (xs++[x])))
      (.refined (.list a) (appendPredicate (.var 0) (.listValue (Val.toTermSlots xs)))) ∧
    AdequateResult [.list xs,x] (.val (.list (xs++[x]))) ∧
    (∀ n, Outcome.val (.list (xs++[x])) ≠ .exit n) := by
  obtain ⟨ys,hd,hy,_⟩ := StandardCollections.insert_reply ann typed element true
  cases Option.some.inj hd
  refine ⟨⟨refine_value hy rfl rfl ret ?_,ground_append ground gx⟩,?_,by intro n h; cases h⟩
  · simpa only [appendPredicate,length,Pred.open,predBind,termBind_var,termBind_measure,
      termBind_integer,termBind_add,Option.getD_some,closed_list xs ground] using append_reply xs x
  · intro σ valid input
    exact adequate_append (input (.list xs) (by simp)) (input x (by simp))

private def optionSignature (tail : Bool) : PrimSig := if tail then tailSignature else headSignature
private def optionPredicate (tail : Bool) (v xs : Term) : Pred := if tail then tailPredicate v xs else headPredicate v xs
private def optionType (tail : Bool) (a : Ty) : Ty := .data "Option" [if tail then .list a else a]

local macro "response_simp" : tactic => `(tactic|
 simp [optionSignature,optionPredicate,optionType,headSignature,tailSignature,appendSignature,
  headPredicate,tailPredicate,appendPredicate,length,someField,PrimSig.tel,signatureTel,
  instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,
  Eff.rawMapRanges,mapRangeAtoms,Tel.bind,Tel.rawBind,Ty.bind,Ty.rawBind,Ty.norm,Ty.normTys,
  Tel.norm,rawBindTys,typeEnvAt,SubstEnv.up,Eff.rawBind,Eff.norm,Eff.empty,rowFails,
  substAtoms_nil,instAtoms_nil,predBind,termBind,termBind?,upValues,Ty.refineNorm,
  Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,Ty.core,
  Ty.shiftV,Term.bind_closed,Tel.argumentsEnv,valEnv,Ty.WF,Ty.WFList,Tel.WF,Ty.NotContCore,
  Pred.WF,Pred.VarsIn])

private theorem empty_range : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
 funext a; cases a <;> simp [mapRangeAtoms]

private theorem option_tel (tail : Bool) {a : Ty} (wf : a.WF 0 0 0) :
    instantiatedTel (Tel.instR [] (optionSignature tail).tel) [a] [] =
      .param "xs" (.list a.norm) (.done (.refined (optionType tail a.norm)
        (optionPredicate tail (.var 0) (.var 1))) Eff.empty) := by
 cases tail <;> response_simp <;> simp [empty_range,Ty.shiftV_of_wf_zero wf]

theorem list_elements {P B Ψ v a}
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (.list a)) (ann : Ty.Annotation P [] [] a) :
    ∃ xs, v = .list xs ∧ HasTypeEachQ P B Ψ Qempty [] [] [] xs a := by
 obtain ⟨xs,b,rfl,hs,le⟩ := typed.canonical_list rfl
 have build : ∀ ys : List Val, (∀ x ∈ ys, x ∈ xs) → HasTypeEachQ P B Ψ Qempty [] [] [] ys a := by
  intro ys sub
  induction ys with
  | nil => exact .nil
  | cons x ys ih =>
    exact .cons (.V_Sub (hs.member (sub x (by simp))) le ann.wf ann.sorted ann.declared)
      (ih (fun y hy => sub y (by simp [hy])))
 exact ⟨xs,rfl,build xs (fun _ h => h)⟩

/-- head・tailの新しい署名に従う全ts/es/rs/ws/Ψ。応答の事実を別入力にしない。 -/
theorem option_response {P B Ψ ts es rs ws r e} (tail : Bool)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1)
    (args : BuiltinArgs P B Ψ (if tail then "List.tail" else "List.head") (optionSignature tail) ts es rs ws r e) :
    ∃ out, StandardListRemainingResponse.delta (if tail then .tail else .head)
        (if tail then "List.tail" else "List.head") ts es rs ws = some out ∧
      Outcome.Typed P B Ψ out r ∧ AdequateResult ws out ∧ (∀ n,out ≠ .exit n) := by
 have count : ts.length = 1 := by cases tail <;> exact args.admissible.typeCount
 obtain ⟨a,rfl⟩ := List.length_eq_one_iff.mp count
 have rows : es=[] := by apply List.length_eq_zero_iff.mp; cases tail <;> exact args.admissible.rowCount
 have ranges : rs=[] := by apply List.length_eq_zero_iff.mp; cases tail <;> exact args.ranges.1
 subst es; subst rs
 have ann := args.signature.types a (by simp)
 have na : a.norm = a := (args.types a (by simp)).2
 have kinds : TypeArgsKinded P [] [a] [.value] := by
  have h := args.signature.kinds
  cases tail <;> simpa [optionSignature,headSignature,tailSignature,TypeCtx.kinds,TypeCtx.valueParam] using h
 have values := args.arguments
 rw [option_tel tail ann.wf,na] at values
 cases values with
 | param _ hx rest =>
  obtain ⟨xs,rfl,each⟩ := list_elements hx ann
  have ground := args.ground (.list xs) (by simp)
  have wx : termWF 0 (.listValue (Val.toTermSlots xs)) := Val.observation_wf ground rfl
  have bx (ν : ObservationEnv) : bindSlots ν (Val.toTermSlots xs) = Val.toTermSlots xs := by
   have h := Term.bind_closed wx ν
   exact Term.listValue.inj (Option.some.inj h)
  have closed (ν : ObservationEnv) : Ty.rawBind ⟨Ty.tvar,[],[],ν⟩ a = a := by
   rw [←Ty.rawSubstV_eq_rawBind,Ty.rawSubstV_of_wf_zero ann.wf]
  cases tail
  all_goals
   simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Tel.argumentsEnv,valEnv,
    SubstEnv.up,rawBindTys,Ty.normTys,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
    Pred.conjuncts,Pred.ofConjuncts,Ty.core,Eff.norm,Eff.empty,rowFails,substAtoms_nil,instAtoms_nil,
    optionType,optionPredicate,headPredicate,tailPredicate,length,someField,predBind,termBind,
    termBind?,upValues,Val.toTerm?,Ty.shiftV,closed,bx,na,←Val.toTermSlots_eq_map] at rest
   cases rest with
   | done ret =>
    first
    | exact ⟨_,real_head a xs,head_response_value someDecl noneDecl arity ann kinds each ground
        ⟨ret.wf.1,ret.sorted.1,ret.declared.1⟩⟩
    | exact ⟨_,real_tail a xs,tail_response_value someDecl noneDecl arity ann kinds each ground
        ⟨ret.wf.1,ret.sorted.1,ret.declared.1⟩⟩

private theorem append_tel {a : Ty} (wf : a.WF 0 0 0) :
    instantiatedTel (Tel.instR [] appendSignature.tel) [a] [] =
      .param "xs" (.list a.norm) (.param "x" a.norm
        (.done (.refined (.list a.norm) (appendPredicate (.var 0) (.var 2))) Eff.empty)) := by
 response_simp
 simp [empty_range,Ty.shiftV_of_wf_zero wf]

/-- appendの新しい署名に従う全ts/es/rs/ws/Ψ。加算の精密署名を使わない。 -/
theorem append_response {P B Ψ ts es rs ws r e}
    (args : BuiltinArgs P B Ψ "List.append" appendSignature ts es rs ws r e) :
    ∃ out, StandardCollections.insertDelta "List.append" ts es rs ws = some out ∧
      Outcome.Typed P B Ψ out r ∧ AdequateResult ws out ∧ (∀ n,out ≠ .exit n) := by
 have count : ts.length = 1 := args.admissible.typeCount
 obtain ⟨a,rfl⟩ := List.length_eq_one_iff.mp count
 have rows : es=[] := List.length_eq_zero_iff.mp args.admissible.rowCount
 have ranges : rs=[] := List.length_eq_zero_iff.mp args.ranges.1
 subst es; subst rs
 have ann := args.signature.types a (by simp)
 have na : a.norm = a := (args.types a (by simp)).2
 have values := args.arguments
 rw [append_tel ann.wf,na] at values
 cases values with
 | param _ hx rest =>
  obtain ⟨xs,rfl,each⟩ := list_elements hx ann
  have ground := args.ground (.list xs) (by simp)
  have wx : termWF 0 (.listValue (Val.toTermSlots xs)) := Val.observation_wf ground rfl
  have bx (ν : ObservationEnv) : bindSlots ν (Val.toTermSlots xs) = Val.toTermSlots xs := by
   have h := Term.bind_closed wx ν
   exact Term.listValue.inj (Option.some.inj h)
  have closed (ν : ObservationEnv) : Ty.rawBind ⟨Ty.tvar,[],[],ν⟩ a = a := by
   rw [←Ty.rawSubstV_eq_rawBind,Ty.rawSubstV_of_wf_zero ann.wf]
  simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Tel.argumentsEnv,valEnv,
    SubstEnv.up,rawBindTys,Ty.normTys,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
    Pred.conjuncts,Pred.ofConjuncts,Ty.core,Eff.norm,Eff.empty,rowFails,substAtoms_nil,instAtoms_nil,
    appendPredicate,length,predBind,termBind,termBind?,upValues,Val.toTerm?,Ty.shiftV,closed,bx,na,
    ←Val.toTermSlots_eq_map] at rest
  cases rest with
  | param _ element done =>
   have gx := args.ground _ (List.mem_cons_of_mem _ List.mem_cons_self)
   simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Tel.argumentsEnv,valEnv,
    SubstEnv.up,rawBindTys,Ty.normTys,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
    Pred.conjuncts,Pred.ofConjuncts,Ty.core,Eff.norm,Eff.empty,rowFails,substAtoms_nil,instAtoms_nil,
    appendPredicate,length,predBind,termBind,termBind?,upValues,Val.toTerm?,Ty.shiftV,closed,bx,na,
    ←Val.toTermSlots_eq_map] at done
   cases done with
   | done ret =>
    exact ⟨_,real_append a xs _,append_response_value ann each element ground gx
      ⟨ret.wf.1,ret.sorted.1,ret.declared.1⟩⟩

end
end Benitoite.Release.Refinement.StandardHeadTail
