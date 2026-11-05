import Benitoite.Release.Refinement.StandardActualListBodies

/-! # 実演算子の引数名で検査する同じList本体 -/
namespace Benitoite.Release.Refinement.ComposedOrdinaryList
noncomputable section
open StandardBodies

private def valueParams (n : Nat) : List TParamDecl := List.replicate n TypeCtx.valueParam
private def resultType (filter : Bool) : Ty := if filter then .tvar 0 else .tvar 1
private def callbackType (filter : Bool) : Ty :=
  .fn ["value"] [.tvar 0] (if filter then .base .boolean else .tvar 1) (Eff.row 0)
private def fromTel (filter : Bool) : Tel :=
  .param "xs" (.list (.tvar 0)) (.param (if filter then "p" else "f") (callbackType filter)
    (.param "i" (.base .integer) (.param "acc" (.list (resultType filter))
      (.done (.list (resultType filter)) (Eff.row 0)))))
private def fromName (filter : Bool) : String := if filter then "%List.filterFrom.ordinary" else "%List.mapFrom.ordinary"
private def typeArgs (filter : Bool) : List Ty := if filter then [.tvar 0] else [.tvar 0,.tvar 1]
private def one : Val := .const (.integer ⟨1,by decide⟩)
private def zero : Val := .const (.integer ⟨0,by decide⟩)
private def increment (i : Nat) : Comp := .app (.prim "%Integer.add" [] [] []) [.var i,one]
private def appendValue (acc x : Nat) (a : Ty) : Comp :=
  .app (.prim "List.append" [a] [] []) [.var acc,.var x]
private def recurse (filter : Bool) (xs f i acc : Nat) : Comp :=
  .app (.fnRef (fromName filter) (typeArgs filter) [Eff.row 0]) [.var xs,.var f,.var i,.var acc]

private def listFromAfterCall (filter : Bool) : Comp :=
  if filter then
    .ite (.var 0)
      (.letIn (increment 4)
        (.letIn (appendValue 4 2 (.tvar 0)) (recurse true 8 7 1 0)))
      (.letIn (increment 4) (recurse true 7 6 0 4))
  else
    .letIn (increment 4)
      (.letIn (appendValue 4 1 (.tvar 1)) (recurse false 8 7 1 0))

private def listFromArms (filter : Bool) : List Arm :=
  [.mk [⟨.con "Option.None" [],[]⟩] none (.ret (.var 1)),
   .mk [⟨.con "Option.Some" [.var],[0]⟩] none
    (.letIn (.app (.var 4) [.var 0]) (listFromAfterCall filter))]

/-- get の Some の値、callback の値、加算、append をそれぞれ一度だけ束縛する。 -/
private def listFromBody (filter : Bool) : Comp :=
  .letIn (.app (.prim "List.get" [.tvar 0] [] []) [.var 3,.var 1])
    (.match (.var 0) (listFromArms filter))

/-- 実ソースの mapFrom/filterFrom と同じ引数と通常の再帰呼出し。 -/
private def listFromRow (filter : Bool) : StandardContracts.Row :=
  ⟨fromName filter,valueParams (if filter then 1 else 2),1,fromTel filter,
    some (listFromBody filter),.core,[if filter then .listFilter else .listMap]⟩

private def listHigherRow (filter : Bool) : StandardContracts.Row :=
  ⟨if filter then "List.filter" else "List.map",valueParams (if filter then 1 else 2),1,
    .param "xs" (.list (.tvar 0)) (.param (if filter then "p" else "f") (callbackType filter)
      (.done (.list (resultType filter)) (Eff.row 0))),
    some (.app (.fnRef (fromName filter) (typeArgs filter) [Eff.row 0])
      [.var 1,.var 0,zero,.list []]),.core,[if filter then .listFilter else .listMap]⟩

/-- 参照する三つの組込み署名。許容は型引数の個数だけを検査する。 -/
private def listGetSig : PrimSig :=
  ⟨valueParams 1,0,["xs","i"],[.list (.tvar 0),.base .integer],.data "Option" [.tvar 0],
    Eff.empty,(fun _ ts => ts.length = 1),.pure,none,[],.untargeted⟩
private def listAppendSig : PrimSig :=
  ⟨valueParams 1,0,["xs","x"],[.list (.tvar 0),.tvar 0],.list (.tvar 0),
    Eff.empty,(fun _ ts => ts.length = 1),.pure,none,[],.untargeted⟩
def additionSignature : PrimSig :=
  ⟨[],0,["left","right"],[.base .integer,.base .integer],.base .integer,
    Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

private theorem subst_row_self :
    substAtoms [Eff.row 0] (Eff.row 0).atoms = (Eff.row 0).atoms := by
  funext a
  cases a with
  | name l r => simp [substAtoms,Eff.row,Eff.atoms,Eff.test]
  | rho i => cases i <;> simp [substAtoms,Eff.row,Eff.atoms,Eff.test]


private def listFromDefinition (filter : Bool) : Def :=
  ⟨valueParams (if filter then 1 else 2),1,(fromTel filter).names,(fromTel filter).inputs,
    (fromTel filter).result,(fromTel filter).effect,listFromBody filter⟩

local macro "list_simp" : tactic => `(tactic|
  simp_all [valueParams,resultType,callbackType,fromTel,fromName,typeArgs,
    listFromRow,listHigherRow,listGetSig,listAppendSig,additionSignature,
    listFromDefinition,Def.tel,PrimSig.tel,signatureTel,Tel.names,Tel.inputs,Tel.result,Tel.effect,
    TypeCtx.valueParam,TypeCtx.kinds,TypeCtx.constraints,TParamDecl.constraints,
    TypeAnnotations,Ty.Annotation,Ty.WF,Tel.WF,Ty.WFList,Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,
    Ty.Declared,Tel.Declared,declaredTys,declaredEff,Ty.HasKind,kindsTel,kindsList,kindsEff,
    NamesWF,Eff.WF,Eff.Canonical,Eff.empty,Eff.row,Eff.norm,Ordinary,Ty.core,
    Builtins.RangeAdmissible,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,Tel.bind,Tel.rawBind,Ty.bind,Ty.rawBind,rawBindTys,
    Ty.norm,Tel.norm,Ty.normTys,typeEnvAt,SubstEnv.up,SubstEnv.rangesOnly,
    Eff.rawBind,rowFails,subst_row_self,substAtoms_nil,instAtoms_nil,
    Qsig,QTel,QTy,QTys,QEff,Qempty,Eff.RowsIn,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,
    RowTransport,NoFail,Eff.test,Eff.atoms,Eff.fails,shiftVTys,Eff.shiftV,Ty.shiftV,Tel.shiftV,Ctx.extend,
    bindParams,localExtend,Pred.lift,liftMany])

private theorem variable_annotation {P Γ} (filter : Bool) (i : Nat)
    (inside : i < (if filter then 1 else 2)) :
    Ty.Annotation P (valueParams (if filter then 1 else 2)) Γ (.tvar i) := by
  cases filter <;> constructor <;> list_simp

private theorem primitive_typed {P B Ψ Q C Γ Φ b s ts ns as r}
    (lookup : B.sig b = some s)
    (range : B.RangeAdmissible b s []) (names : NamesWF s.names s.params)
    (admissible : PrimitiveAdmissible C Γ.length s Q ts [])
    (inst : SignatureInstance P C Γ (Tel.instR [] s.tel) (TypeCtx.kinds s.tparams) ts [])
    (normal : (.dependentFn (instantiatedTel (Tel.instR [] s.tel) ts []) : Ty).norm =
      (Ty.fn ns as r Eff.empty).norm)
    (annotation : Ty.Annotation P C Γ (.fn ns as r Eff.empty)) :
    HasTypeVQ P B Ψ Q C Γ Φ (.prim b ts [] []) (.fn ns as r Eff.empty) :=
  (HasTypeVQ.V_Prim lookup range names admissible inst).convert normal annotation

private theorem singleton_kind {P C a}
    (kind : Ty.HasKind P (TypeCtx.kinds C) a .value) (ordinary : Ordinary a) :
    TypeArgsKinded P C [a] [.value] := by
  refine ⟨rfl,?_⟩
  rintro (_|j) b k hb hk
  · cases Option.some.inj hb
    cases Option.some.inj hk
    exact ⟨kind,fun _ => ordinary⟩
  · simp at hb

private theorem list_primitive {P B Ψ Q Γ Φ} (filter : Bool) (i : Nat)
    (inside : i < (if filter then 1 else 2))
    (arity : P.DataArity "Option" 1)
    (get : B.sig "List.get" = some listGetSig)
    (append : ∀ Ψ Q Γ Φ i, i < (if filter then 1 else 2) →
      HasTypeVQ P B Ψ Q (valueParams (if filter then 1 else 2)) Γ Φ
        (.prim "List.append" [.tvar i] [] [])
        (.fn ["xs","x"] [.list (.tvar i),.tvar i] (.list (.tvar i)) Eff.empty))
    (addition : B.sig "%Integer.add" = some additionSignature) :
    HasTypeVQ P B Ψ Q (valueParams (if filter then 1 else 2)) Γ Φ
      (.prim "List.get" [.tvar i] [] [])
      (.fn ["xs","i"] [.list (.tvar i),.base .integer] (.data "Option" [.tvar i]) Eff.empty) ∧
    HasTypeVQ P B Ψ Q (valueParams (if filter then 1 else 2)) Γ Φ
      (.prim "List.append" [.tvar i] [] [])
      (.fn ["xs","x"] [.list (.tvar i),.tvar i] (.list (.tvar i)) Eff.empty) ∧
    HasTypeVQ P B Ψ Q (valueParams (if filter then 1 else 2)) Γ Φ
      (.prim "%Integer.add" [] [] [])
      (.fn ["left","right"] [.base .integer,.base .integer] (.base .integer) Eff.empty) := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext a; simp [mapRangeAtoms]
  have ann := variable_annotation (P := P) (Γ := Γ) filter i inside
  have ar : ∃ n, P.DataArity "Option" n ∧ 1 = n := ⟨1,arity,rfl⟩
  have kind : Ty.HasKind P (TypeCtx.kinds (valueParams (if filter then 1 else 2))) (.tvar i) .value := by
    simp [valueParams,TypeCtx.kinds,TypeCtx.valueParam,inside,Ty.HasKind]
  constructor
  · apply primitive_typed get
    · list_simp
    · list_simp
    · constructor <;> list_simp
    · constructor
      · list_simp
      · intro a ha; cases List.mem_singleton.mp ha; exact ann
      · exact singleton_kind kind (by intro b t e; simp [Ty.core])
      · intro e he; cases he
      · intro e he; cases he
      · constructor <;> list_simp
    · list_simp
      simpa [emptyRange,FnView.toTel,Ty.toTel,shiftVTys,Ty.shiftV,Eff.shiftV,Eff.empty] using Ty.foldFn_toTel ⟨["xs","i"],[.list (.tvar i),.base .integer],.data "Option" [.tvar i],Eff.empty,by simp [NamesWF]⟩
    · constructor <;> list_simp
  · constructor
    · exact append _ _ _ _ i inside
    · apply primitive_typed addition
      · list_simp
      · list_simp
      · constructor <;> list_simp
      · constructor
        · list_simp
        · intro a ha; cases ha
        · exact ⟨rfl,by intro j a k ha; cases ha⟩
        · intro e he; cases he
        · intro e he; cases he
        · constructor <;> list_simp
      · list_simp
        simpa [emptyRange,FnView.toTel,Ty.toTel,shiftVTys,Ty.shiftV,Eff.shiftV,Eff.empty] using Ty.foldFn_toTel ⟨["left","right"],[.base .integer,.base .integer],.base .integer,Eff.empty,by simp [NamesWF]⟩
      · constructor <;> list_simp

private theorem from_annotation {P Γ} (filter : Bool) :
    Ty.Annotation P (valueParams (if filter then 1 else 2)) Γ (.dependentFn (fromTel filter)) := by
  cases filter <;> constructor <;> list_simp

private theorem from_instance {P Γ} (filter : Bool) :
    SignatureInstance P (valueParams (if filter then 1 else 2)) Γ
      (listFromDefinition filter).tel (TypeCtx.kinds (listFromDefinition filter).tparams) (typeArgs filter) [Eff.row 0] := by
  have selfrow := subst_row_self
  simp only [Eff.row,Eff.atoms] at selfrow
  cases filter <;> constructor
  all_goals
    solve
    | list_simp
    | (constructor <;> list_simp)
    | (list_simp; constructor <;> constructor <;> list_simp)
    | (intro e he; cases List.mem_singleton.mp he; constructor <;> list_simp)
    | (intro e he; cases List.mem_singleton.mp he; list_simp)
    | (constructor; list_simp; rintro (_|(_|j)) a k ha hk <;> list_simp <;> (subst_vars; list_simp))

private theorem fold_from (filter : Bool) : Ty.foldFn (fromTel filter) =
    .fn (fromTel filter).names (fromTel filter).inputs (.list (resultType filter)) (Eff.row 0) := by
  cases filter
  · simpa [FnView.toTel,Ty.toTel,fromTel,callbackType,resultType,Tel.names,Tel.inputs,
      shiftVTys,Ty.shiftV,Eff.shiftV,Eff.row] using
      Ty.foldFn_toTel ⟨(fromTel false).names,(fromTel false).inputs,.list (.tvar 1),Eff.row 0,
        by simp [fromTel,Tel.names,Tel.inputs,NamesWF]⟩
  · simpa [FnView.toTel,Ty.toTel,fromTel,callbackType,resultType,Tel.names,Tel.inputs,
      shiftVTys,Ty.shiftV,Eff.shiftV,Eff.row] using
      Ty.foldFn_toTel ⟨(fromTel true).names,(fromTel true).inputs,.list (.tvar 0),Eff.row 0,
        by simp [fromTel,Tel.names,Tel.inputs,NamesWF]⟩

private theorem from_function {P B Ψ Q Γ Φ} (filter : Bool)
    (lookup : P.defs (fromName filter) = some (listFromDefinition filter))
    (sat : ∀ i, i < (if filter then 1 else 2) →
      B.sat (TypeCtx.constraints (valueParams (if filter then 1 else 2))) (.tvar i) {}) :
    HasTypeVQ P B Ψ Q (valueParams (if filter then 1 else 2)) Γ Φ
      (.fnRef (fromName filter) (typeArgs filter) [Eff.row 0])
      (.fn (fromTel filter).names (fromTel filter).inputs (.list (resultType filter)) (Eff.row 0)) := by
  have selfrow := subst_row_self
  simp only [Eff.row,Eff.atoms] at selfrow
  have names : NamesWF (listFromDefinition filter).names (listFromDefinition filter).params := by
    cases filter <;> simp [listFromDefinition,fromTel,NamesWF,Tel.names,Tel.inputs]
  have admissible : Admissible B (valueParams (if filter then 1 else 2)) Γ.length
      (TypeCtx.constraints (listFromDefinition filter).tparams) 1
      (Qsig (listFromDefinition filter).params (listFromDefinition filter).ret (listFromDefinition filter).eff) Q
      (typeArgs filter) [Eff.row 0] (listFromDefinition filter).eff := by
    cases filter <;> constructor
    all_goals first | (constructor <;> list_simp) | list_simp
    all_goals rintro (_|(_|j)) a p ha hp <;> list_simp
    all_goals subst_vars; list_simp
    all_goals first | exact sat 0 (by decide) | exact sat 1 (by decide)
  have typed := HasTypeVQ.V_Fun (Ψ := Ψ) (Φ := Φ) lookup names admissible (from_instance filter)
  apply typed.convert
  · have fold := fold_from filter
    cases filter <;> list_simp
  · cases filter <;> constructor <;> list_simp

/-- Option の同じ二つの宣言と、他の Option 構成子がないことを照合する。 -/
abbrev ListOptionDeclarations := StandardActualListBodies.ListOptionDeclarations

private theorem option_alternatives {P} (decls : ListOptionDeclarations P) :
    AltsTy P [⟨.con "Option.None" [],[]⟩] (.data "Option" [.tvar 0]) [] ∧
    AltsTy P [⟨.con "Option.Some" [.var],[0]⟩] (.data "Option" [.tvar 0]) [.tvar 0] := by
  constructor
  · refine ⟨by simp,rfl,?_,?_⟩
    · intro alt h; cases Option.some.inj h; rfl
    · intro alt h; cases List.mem_singleton.mp h
      exact ⟨[],.P_Con decls.none_decl rfl (by simp) .nil,by simp,rfl⟩
  · refine ⟨by simp,rfl,?_,?_⟩
    · intro alt h; cases Option.some.inj h; rfl
    · intro alt h; cases List.mem_singleton.mp h
      refine ⟨[.tvar 0],.P_Con decls.some_decl rfl ?_ (.cons .P_Var .nil),by simp,rfl⟩
      intro a ha; cases List.mem_singleton.mp ha; simp [Ty.WF]

private theorem option_exhaustive {P} (decls : ListOptionDeclarations P) (a : Ty) :
    Exhaustive P (.data "Option" [a]) [.con "Option.None" [],.con "Option.Some" [.var]] := by
  intro v inhabitant
  change Inhabits P (.data "Option" [a.norm]) v at inhabitant
  have aux : ∀ t v, Inhabits P t v → t = .data "Option" [a.norm] →
      ∃ p ∈ [Pat.con "Option.None" [],.con "Option.Some" [.var]], (matchVal p v).isSome := by
    intro t v h eq
    cases h <;> try (solve | cases eq)
    case const c => cases c <;> cases eq
    case atError => simp [atErrorType] at eq
    case con c ts tys args cd lookup ntys wf fields =>
      have owner := (Ty.data.inj eq).1
      rcases decls.only c cd lookup owner with hc | hc
      · subst c
        have hd := Option.some.inj (lookup.symm.trans decls.none_decl)
        subst cd
        cases fields
        exact ⟨.con "Option.None" [],by simp,by simp [matchVal,matchList]⟩
      · subst c
        have hd := Option.some.inj (lookup.symm.trans decls.some_decl)
        subst cd
        cases fields with
        | cons value rest =>
          cases rest
          exact ⟨.con "Option.Some" [.var],by simp,by simp [matchVal,matchList]⟩
  exact aux _ _ inhabitant rfl

private theorem pure_effect {P B Ψ Q C Γ Φ R m a Δ} (ann : Ty.Annotation P C Γ a)
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R m a Eff.empty Δ) :
    HasTypeCQ P B Ψ Q C Γ Φ R m a (Eff.row 0) Δ := by
  apply HasTypeCQ.C_Sub typed .refl _ ann.wf ann.sorted ann.declared
  constructor
  · intro a h; simp [Eff.mem,Eff.empty,Eff.test,Eff.atoms] at h
  · intro t h; simp [Eff.memFail,Eff.empty,Eff.fails] at h

local macro "list_var" : tactic => `(tactic| (refine HasTypeVQ.V_Var rfl ?_; intro b t e; list_simp))

local macro "list_index_step" f:term : tactic => `(tactic|
  (apply pure_effect (by constructor <;> list_simp)
   apply HasTypeCQ.C_App ($f _ _)
   exact .cons (by list_var) (.cons (.V_Const trivial) .nil)))
local macro "list_append_step" f:term : tactic => `(tactic|
  (apply pure_effect (by constructor <;> list_simp)
   apply HasTypeCQ.C_App ($f _ _)
   exact .cons (by list_var) (.cons (by list_var) .nil)))
local macro "list_recurse_step" f:term : tactic => `(tactic|
  (apply HasTypeCQ.C_App ($f _ _)
   exact .cons (by list_var) (.cons (by list_var) (.cons (by list_var) (.cons (by list_var) .nil)))))

private theorem from_body {P B} (filter : Bool) (decls : ListOptionDeclarations P)
    (get : B.sig "List.get" = some listGetSig)
    (append : ∀ Ψ Q Γ Φ i, i < (if filter then 1 else 2) →
      HasTypeVQ P B Ψ Q (valueParams (if filter then 1 else 2)) Γ Φ
        (.prim "List.append" [.tvar i] [] [])
        (.fn ["xs","x"] [.list (.tvar i),.tvar i] (.list (.tvar i)) Eff.empty))
    (addition : B.sig "%Integer.add" = some additionSignature)
    (lookup : P.defs (fromName filter) = some (listFromDefinition filter))
    (sat : ∀ i, i < (if filter then 1 else 2) →
      B.sat (TypeCtx.constraints (valueParams (if filter then 1 else 2))) (.tvar i) {}) :
    TelBodyTy P B StoreTy.empty (QTel (fromTel filter))
      (valueParams (if filter then 1 else 2)) [] [] (fromTel filter) (listFromBody filter) := by
  have ar : ∃ n, P.DataArity "Option" n ∧ 1 = n := ⟨1,decls.arity,rfl⟩
  have getFn := fun Γ Φ => (list_primitive (P := P) (B := B) (Ψ := StoreTy.empty)
    (Q := QTel (fromTel filter)) (Γ := Γ) (Φ := Φ) filter 0 (by cases filter <;> decide)
      decls.arity get append addition).1
  have appendFn := fun Γ Φ => (list_primitive (P := P) (B := B) (Ψ := StoreTy.empty)
    (Q := QTel (fromTel filter)) (Γ := Γ) (Φ := Φ) filter (if filter then 0 else 1)
      (by cases filter <;> decide) decls.arity get append addition).2.1
  have addFn := fun Γ Φ => (list_primitive (P := P) (B := B) (Ψ := StoreTy.empty)
    (Q := QTel (fromTel filter)) (Γ := Γ) (Φ := Φ) filter 0 (by cases filter <;> decide)
      decls.arity get append addition).2.2
  have recFn := fun Γ Φ => from_function (P := P) (B := B) (Ψ := StoreTy.empty)
    (Q := QTel (fromTel filter)) (Γ := Γ) (Φ := Φ) filter lookup sat
  have alts := option_alternatives decls
  cases filter
  all_goals
    apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param
    apply TelBodyTy.done
    dsimp only [listFromBody,listFromArms,listFromAfterCall]
    apply HasTypeCQ.C_Let (a := .data "Option" [.tvar 0])
    · apply pure_effect (by constructor <;> list_simp)
      apply HasTypeCQ.C_App (getFn _ _)
      exact .cons (by list_var) (.cons (by list_var) .nil)
    · apply HasTypeCQ.C_Match (obs := none)
      · list_var
      · intro t h; cases h
      · apply HasTypeArmsQ.plainEmpty alts.1 (by simp [pathFacts,FactsWF])
        · apply pure_effect (by constructor <;> list_simp)
          exact .C_Return (by list_var)
        · apply HasTypeArmsQ.plainEmpty alts.2 (by simp [pathFacts,FactsWF])
          · apply HasTypeCQ.C_Let
            · apply HasTypeCQ.C_App
              · list_var
              · exact .cons (by list_var) .nil
            · first
              | (apply HasTypeCQ.C_Let (a := .base .integer)
                 · list_index_step addFn
                 · apply HasTypeCQ.C_Let (a := .list (.tvar 1))
                   · list_append_step appendFn
                   · list_recurse_step recFn
                   · list_simp
                 · list_simp)
              | (apply HasTypeCQ.C_If
                 · list_var
                 · rfl
                 · apply HasTypeCQ.C_Let (a := .base .integer)
                   · list_index_step addFn
                   · apply HasTypeCQ.C_Let (a := .list (.tvar 0))
                     · list_append_step appendFn
                     · list_recurse_step recFn
                     · list_simp
                   · list_simp
                 · apply HasTypeCQ.C_Let (a := .base .integer)
                   · list_index_step addFn
                   · list_recurse_step recFn
                   · list_simp)
            · list_simp
          · apply HasTypeArmsQ.nil; constructor <;> list_simp
      · simpa [unguardedPats,Ty.shiftV,shiftVTys] using option_exhaustive decls (.tvar 0)
    · list_simp

/-- 同じ再帰定義と組込みの宣言から、通常本体の静的な結果型と効果を構成する。 -/
private theorem listFrom_body_typed {P B} (filter : Bool) (decls : ListOptionDeclarations P)
    (get : B.sig "List.get" = some listGetSig)
    (append : ∀ Ψ Q Γ Φ i, i < (if filter then 1 else 2) →
      HasTypeVQ P B Ψ Q (valueParams (if filter then 1 else 2)) Γ Φ
        (.prim "List.append" [.tvar i] [] [])
        (.fn ["xs","x"] [.list (.tvar i),.tvar i] (.list (.tvar i)) Eff.empty))
    (addition : B.sig "%Integer.add" = some additionSignature)
    (lookup : P.defs (listFromRow filter).name = some (listFromDefinition filter))
    (sat : ∀ i, i < (listFromRow filter).tparams.length →
      B.sat (TypeCtx.constraints (listFromRow filter).tparams) (.tvar i) {}) :
    (listFromRow filter).BodyTyped P B := by
  refine ⟨listFromDefinition filter,rfl,?_,?_,?_,?_⟩
  · cases filter <;> list_simp
  · cases filter <;> list_simp
  · exact from_annotation filter
  · cases filter <;> exact from_body _ decls get append addition lookup sat

/-- 公開 map/filter は同じ helper を、添字0と空のaccで一度呼ぶ。 -/
private theorem listHigher_body_typed {P B} (filter : Bool)
    (lookup : P.defs (listFromRow filter).name = some (listFromDefinition filter))
    (sat : ∀ i, i < (listHigherRow filter).tparams.length →
      B.sat (TypeCtx.constraints (listHigherRow filter).tparams) (.tvar i) {}) :
    (listHigherRow filter).BodyTyped P B := by
  have recFn := fun Γ Φ => from_function (P := P) (B := B) (Ψ := StoreTy.empty)
    (Q := QTel (listHigherRow filter).tel) (Γ := Γ) (Φ := Φ) filter lookup (by simpa [listHigherRow,valueParams] using sat)
  cases filter
  all_goals
    refine ⟨_,rfl,?_,?_,?_,TelBodyTy.param (TelBodyTy.param (TelBodyTy.done ?_))⟩
    · list_simp
    · list_simp
    · constructor <;> list_simp
    · apply HasTypeCQ.C_App (recFn _ _)
      refine .cons (by list_var) (.cons (by list_var) (.cons (.V_Const trivial) (.cons ?_ .nil)))
      exact .V_List .nil (by list_simp) (by list_simp) (by list_simp)



-- 合成用のDefの型付け。元の本体は関数参照名だけが異なる。
theorem from_typed {P B} (filter : Bool) (decls : ListOptionDeclarations P)
    (get : B.sig "List.get" = some listGetSig)
    (append : ∀ Ψ Q Γ Φ i, i < (if filter then 1 else 2) →
      HasTypeVQ P B Ψ Q (valueParams (if filter then 1 else 2)) Γ Φ
        (.prim "List.append" [.tvar i] [] [])
        (.fn ["xs","x"] [.list (.tvar i),.tvar i] (.list (.tvar i)) Eff.empty))
    (addition : B.sig "%Integer.add" = some additionSignature)
    (lookup : P.defs (fromName filter) = some (listFromDefinition filter))
    (sat : ∀ i, i < (listFromRow filter).tparams.length →
      B.sat (TypeCtx.constraints (listFromRow filter).tparams) (.tvar i) {}) :
    (listFromDefinition filter).WellTyped P B :=
  by
    obtain ⟨d, hd, ht⟩ := listFrom_body_typed filter decls get append addition lookup sat
    cases Option.some.inj (hd.symm.trans rfl)
    exact ht

theorem higher_typed {P B} (filter : Bool)
    (lookup : P.defs (fromName filter) = some (listFromDefinition filter))
    (sat : ∀ i, i < (listHigherRow filter).tparams.length →
      B.sat (TypeCtx.constraints (listHigherRow filter).tparams) (.tvar i) {}) :
    (listHigherRow filter).BodyTyped P B := listHigher_body_typed filter lookup sat

end
end Benitoite.Release.Refinement.ComposedOrdinaryList
