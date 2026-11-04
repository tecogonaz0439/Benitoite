import Benitoite.Release.Refinement.StandardBodies
import Benitoite.Release.Refinement.StandardCollections
import Benitoite.Release.Refinement.CoverageRefinement
import Benitoite.Release.Refinement.StandardKeyTyping
import Benitoite.Release.Refinement.FirstReturn
import Benitoite.Release.Refinement.IntervalConnection
import Lean

/-! # List の通常の高階本体と有限な実行 -/
namespace Benitoite.Release.Refinement.StandardBodies
noncomputable section

private def valueParams (n : Nat) : List TParamDecl := List.replicate n TypeCtx.valueParam
private def resultType (filter : Bool) : Ty := if filter then .tvar 0 else .tvar 1
private def callbackType (filter : Bool) : Ty :=
  .fn ["value"] [.tvar 0] (if filter then .base .boolean else .tvar 1) (Eff.row 0)
private def fromTel (filter : Bool) : Tel :=
  .param "xs" (.list (.tvar 0)) (.param (if filter then "p" else "f") (callbackType filter)
    (.param "i" (.base .integer) (.param "acc" (.list (resultType filter))
      (.done (.list (resultType filter)) (Eff.row 0)))))
private def fromName (filter : Bool) : String := if filter then "List.filterFrom" else "List.mapFrom"
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
def listFromBody (filter : Bool) : Comp :=
  .letIn (.app (.prim "List.get" [.tvar 0] [] []) [.var 3,.var 1])
    (.match (.var 0) (listFromArms filter))

/-- 実ソースの mapFrom/filterFrom と同じ引数と通常の再帰呼出し。 -/
def listFromRow (filter : Bool) : StandardContracts.Row :=
  ⟨fromName filter,valueParams (if filter then 1 else 2),1,fromTel filter,
    some (listFromBody filter),.core,[if filter then .listFilter else .listMap]⟩

def listHigherRow (filter : Bool) : StandardContracts.Row :=
  ⟨if filter then "List.filter" else "List.map",valueParams (if filter then 1 else 2),1,
    .param "xs" (.list (.tvar 0)) (.param (if filter then "p" else "f") (callbackType filter)
      (.done (.list (resultType filter)) (Eff.row 0))),
    some (.app (.fnRef (fromName filter) (typeArgs filter) [Eff.row 0])
      [.var 1,.var 0,zero,.list []]),.core,[if filter then .listFilter else .listMap]⟩

/-- 参照する三つの組込み署名。許容は型引数の個数だけを検査する。 -/
def listGetSig : PrimSig :=
  ⟨valueParams 1,0,["xs","i"],[.list (.tvar 0),.base .integer],.data "Option" [.tvar 0],
    Eff.empty,(fun _ ts => ts.length = 1),.pure,none,[],.untargeted⟩
def listAppendSig : PrimSig :=
  ⟨valueParams 1,0,["xs","x"],[.list (.tvar 0),.tvar 0],.list (.tvar 0),
    Eff.empty,(fun _ ts => ts.length = 1),.pure,none,[],.untargeted⟩
def listIndexAddSig : PrimSig :=
  ⟨[],0,["a","b"],[.base .integer,.base .integer],.base .integer,
    Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

private theorem subst_row_self :
    substAtoms [Eff.row 0] (Eff.row 0).atoms = (Eff.row 0).atoms := by
  funext a
  cases a with
  | name l r => simp [substAtoms,Eff.row,Eff.atoms,Eff.test]
  | rho i => cases i <;> simp [substAtoms,Eff.row,Eff.atoms,Eff.test]


def listFromDefinition (filter : Bool) : Def :=
  ⟨valueParams (if filter then 1 else 2),1,(fromTel filter).names,(fromTel filter).inputs,
    (fromTel filter).result,(fromTel filter).effect,listFromBody filter⟩

local macro "list_simp" : tactic => `(tactic|
  simp_all [valueParams,resultType,callbackType,fromTel,fromName,typeArgs,
    listFromRow,listHigherRow,listGetSig,listAppendSig,listIndexAddSig,
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
    (append : B.sig "List.append" = some listAppendSig)
    (addition : B.sig "%Integer.add" = some listIndexAddSig) :
    HasTypeVQ P B Ψ Q (valueParams (if filter then 1 else 2)) Γ Φ
      (.prim "List.get" [.tvar i] [] [])
      (.fn ["xs","i"] [.list (.tvar i),.base .integer] (.data "Option" [.tvar i]) Eff.empty) ∧
    HasTypeVQ P B Ψ Q (valueParams (if filter then 1 else 2)) Γ Φ
      (.prim "List.append" [.tvar i] [] [])
      (.fn ["xs","x"] [.list (.tvar i),.tvar i] (.list (.tvar i)) Eff.empty) ∧
    HasTypeVQ P B Ψ Q (valueParams (if filter then 1 else 2)) Γ Φ
      (.prim "%Integer.add" [] [] [])
      (.fn ["a","b"] [.base .integer,.base .integer] (.base .integer) Eff.empty) := by
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
    · apply primitive_typed append
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
        simpa [emptyRange,FnView.toTel,Ty.toTel,shiftVTys,Ty.shiftV,Eff.shiftV,Eff.empty] using Ty.foldFn_toTel ⟨["xs","x"],[.list (.tvar i),.tvar i],.list (.tvar i),Eff.empty,by simp [NamesWF]⟩
      · constructor <;> list_simp
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
        simpa [emptyRange,FnView.toTel,Ty.toTel,shiftVTys,Ty.shiftV,Eff.shiftV,Eff.empty] using Ty.foldFn_toTel ⟨["a","b"],[.base .integer,.base .integer],.base .integer,Eff.empty,by simp [NamesWF]⟩
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
structure ListOptionDeclarations (P : Program) : Prop where
  none_decl : P.cons "Option.None" = some ⟨"Option",1,[]⟩
  some_decl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩
  arity : P.DataArity "Option" 1
  only : ∀ c cd, P.cons c = some cd → cd.data = "Option" →
    c = "Option.None" ∨ c = "Option.Some"

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
    (append : B.sig "List.append" = some listAppendSig)
    (addition : B.sig "%Integer.add" = some listIndexAddSig)
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
theorem listFrom_body_typed {P B} (filter : Bool) (decls : ListOptionDeclarations P)
    (get : B.sig "List.get" = some listGetSig)
    (append : B.sig "List.append" = some listAppendSig)
    (addition : B.sig "%Integer.add" = some listIndexAddSig)
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
theorem listHigher_body_typed {P B} (filter : Bool)
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

private def listCapture (xs : List Val) (f : Val) (i : Benitoite.Release.Integer64Value)
    (acc : List Val) : Capture := .mk [some (.list acc),some (.const (.integer i)),some f,some (.list xs)]

/-- None の実応答の後は callback に進まず、同じ acc を返す。 -/
theorem listFrom_none_steps {P B σ} (filter : Bool) (xs acc : List Val) (f : Val)
    (i : Benitoite.Release.Integer64Value) (k : Cont) (μ : Store)
    (get : B.sig "List.get" = some listGetSig)
    (none_reply : B.delta "List.get" [.tvar 0] [] [] [.list xs,.const (.integer i)] =
      some (.val (.con "Option.None" [.tvar 0] []))) :
    ∃ q, Steps P B σ (.run (.mk (listCapture xs f i acc) (listFromBody filter)) k μ) []
        (.run q k μ) ∧ q.view = .ret (.list acc) := by
  refine ⟨_,.cons (.E_Let rfl)
    (.cons (.E_Prim (ts := [.tvar 0]) (es := []) (rs := [])
      (ws := [.list xs,.const (.integer i)]) rfl get rfl none_reply)
    (.cons (.E_Return rfl) (.cons (.E_Match rfl) (.cons (.E_MatchBody rfl rfl) .nil)))),rfl⟩


private def callbackCapture (xs acc : List Val) (f x : Val) (i : Benitoite.Release.Integer64Value) : Capture :=
  ((listCapture xs f i acc).extend (.con "Option.Some" [.tvar 0] [closeVal Capture.empty x])).extend
    (closeVal Capture.empty x)
private def callbackStart (xs acc : List Val) (f x : Val) (i : Benitoite.Release.Integer64Value) : Closure :=
  .mk (callbackCapture xs acc f x i) (.app (.var 4) [.var 0])
private def callbackTail (filter : Bool) (xs acc : List Val) (f x : Val)
    (i : Benitoite.Release.Integer64Value) : Closure :=
  .mk (callbackCapture xs acc f x i) (listFromAfterCall filter)

/-- Some の実応答から、元の f と受信した要素を一度だけ評価する地点へ進む。 -/
theorem listFrom_some_steps {P B σ} (filter : Bool) (xs acc : List Val) (f x : Val)
    (i : Benitoite.Release.Integer64Value) (k : Cont) (μ : Store)
    (get : B.sig "List.get" = some listGetSig)
    (some_reply : B.delta "List.get" [.tvar 0] [] [] [.list xs,.const (.integer i)] =
      some (.val (.con "Option.Some" [.tvar 0] [x]))) :
    (callbackStart xs acc f x i).view = .app f [closeVal Capture.empty x] ∧
    Steps P B σ (.run (.mk (listCapture xs f i acc) (listFromBody filter)) k μ) []
      (.run (callbackStart xs acc f x i) (.letF (callbackTail filter xs acc f x i) :: k) μ) := by
  refine ⟨rfl,.cons (.E_Let rfl) (.cons (.E_Prim (ts := [.tvar 0]) (es := []) (rs := [])
      (ws := [.list xs,.const (.integer i)]) rfl get rfl some_reply)
    (.cons (.E_Return rfl) (.cons (.E_Match rfl) (.cons (.E_MatchSkip rfl rfl)
      (.cons (.E_MatchBody (ws := [closeVal Capture.empty x]) rfl rfl)
        (.cons (.E_Let rfl) .nil))))))⟩

/-- callback の失敗は同じ事象列・理由・更新後のストアのまま外へ進む。 -/
theorem listFrom_callback_failed {P B σ} (filter : Bool) (xs acc : List Val) (f x : Val)
    (i : Benitoite.Release.Integer64Value) (k : Cont) (μ μ' : Store) (events : List Event)
    (errors : List ErrKind) (get : B.sig "List.get" = some listGetSig)
    (some_reply : B.delta "List.get" [.tvar 0] [] [] [.list xs,.const (.integer i)] =
      some (.val (.con "Option.Some" [.tvar 0] [x])))
    (child : Steps P B σ (.run (callbackStart xs acc f x i)
      (.letF (callbackTail filter xs acc f x i) :: k) μ) events
      (.error errors (.letF (callbackTail filter xs acc f x i) :: k) μ')) :
    Steps P B σ (.run (.mk (listCapture xs f i acc) (listFromBody filter)) k μ)
      events (.error errors k μ') := by
  have headSteps := (listFrom_some_steps (P := P) (σ := σ) filter xs acc f x i k μ get some_reply).2
  have pop : Steps P B σ (.error errors (.letF (callbackTail filter xs acc f x i) :: k) μ') []
      (.error errors k μ') := .cons .E_ErrPopLet .nil
  simpa using IntervalConnection.steps_trans headSteps (IntervalConnection.steps_trans child pop)

/-- 正常な子の実値だけを後続へ束縛し、子と後続の同じ事象列を連結する。 -/
theorem listFrom_callback_normal {P B σ} (filter : Bool) (xs acc : List Val) (f x y : Val)
    (i : Benitoite.Release.Integer64Value) (k : Cont) (μ μ' : Store)
    (events rest : List Event) (q : Closure) (last : State)
    (get : B.sig "List.get" = some listGetSig)
    (some_reply : B.delta "List.get" [.tvar 0] [] [] [.list xs,.const (.integer i)] =
      some (.val (.con "Option.Some" [.tvar 0] [x])))
    (child : Steps P B σ (.run (callbackStart xs acc f x i)
      (.letF (callbackTail filter xs acc f x i) :: k) μ) events
      (.run q (.letF (callbackTail filter xs acc f x i) :: k) μ'))
    (normal : q.view = .ret y)
    (tail : Steps P B σ (.run ((callbackTail filter xs acc f x i).apply [y]) k μ') rest last) :
    Steps P B σ (.run (.mk (listCapture xs f i acc) (listFromBody filter)) k μ)
      (events ++ rest) last := by
  have headSteps := (listFrom_some_steps (P := P) (σ := σ) filter xs acc f x i k μ get some_reply).2
  have composed := IntervalConnection.steps_trans headSteps
    (IntervalConnection.steps_trans child (.cons (.E_Return normal) tail))
  simpa using composed

private theorem append_tel {U : Ty} (wf : U.WF 0 0 0) :
    instantiatedTel (Tel.instR [] listAppendSig.tel) [U] [] =
      .param "xs" (.list U.norm) (.param "x" U.norm (.done (.list U.norm) Eff.empty)) := by
  simp [listAppendSig,valueParams,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
    Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
    mapRangeAtoms,Tel.bind,Tel.rawBind,Tel.norm,Ty.rawBind,Ty.norm,Ty.normTys,rawBindTys,
    typeEnvAt,SubstEnv.up,Eff.rawBind,Eff.norm,Eff.empty,rowFails,substAtoms_nil,instAtoms_nil,
    Ty.shiftV_of_wf_zero wf]
  funext a; simp [mapRangeAtoms]

/-- 同じ実 Steps の append 直前で、callback の実値と acc の要素型を元の契約から読む。 -/
theorem list_append_reached_typed {P B σ Eb source events q k μ U acc y}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (initial : StateTyE P B σ Eb source)
    (trace : Steps P B σ source events (.run q k μ))
    (lookup : B.sig "List.append" = some listAppendSig)
    (view : q.view = .app (.prim "List.append" [U] [] []) [.list acc,y]) :
    ∃ Ψ, StoreOk P B σ Ψ μ ∧
      HasTypeVQ P B Ψ Qempty [] [] [] y U.norm ∧
      HasTypeEachQ P B Ψ Qempty [] [] [] acc U.norm := by
  have reached := initial.steps_preserved hP hPB hdecl hB hσ trace
  obtain ⟨Ψ,R,a,e,sg,r,ef,store,_,hs,_,_,inst,args,_,_⟩ :=
    reached.primitive_contract_inputs hP hPB hB view
  cases Option.some.inj (hs.symm.trans lookup)
  have ann := inst.types U (by simp)
  rw [append_tel ann.wf] at args
  cases args with
  | param _ listTyped tail =>
    have wf1 : U.norm.WF 0 0 1 := by
      simpa [Ty.shiftV_of_wf_zero ann.norm.wf] using Ty.wf_shiftV ann.norm.wf 1 0
    have restWF : Tel.WF 0 0 0 (.param "x" U.norm (.done (.list U.norm) Eff.empty)) :=
      ⟨ann.norm.wf,wf1,trivial,rfl⟩
    rw [show Tel.bind (Tel.argumentsEnv (.list acc))
        (.param "x" U.norm (.done (.list U.norm) Eff.empty)) =
        .param "x" U.norm (.done (.list U.norm) Eff.empty) from by
      rw [← valEnv_openValue]
      simpa [Tel.norm,Ty.norm,Ty.norm_idem,Eff.norm,Eff.empty] using
        Tel.bind_values_of_wf_zero restWF (openValue (.list acc))] at tail
    cases tail with
    | param _ valueTyped _ =>
      obtain ⟨a,b,each,_,core,le⟩ := listTyped.inv_list_core rfl
      have eq : b = U.norm := by simpa [Ty.norm,Ty.core,Ty.norm_idem] using core.symm
      subst b
      have convertEach : ∀ xs, HasTypeEachQ P B Ψ Qempty [] [] [] xs a →
          HasTypeEachQ P B Ψ Qempty [] [] [] xs U.norm := by
        intro xs
        induction xs with
        | nil => intro _; exact .nil
        | cons x xs ih =>
          intro elements
          cases elements with
          | cons hx hxs =>
            exact .cons (.V_Sub hx le ann.norm.wf ann.norm.sorted ann.norm.declared) (ih hxs)
      exact ⟨Ψ,store,valueTyped,convertEach acc each⟩

example {P B σ Eb source events q k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (initial : StateTyE P B σ Eb source)
    (trace : Steps P B σ source events (.run q k μ))
    (lookup : B.sig "List.append" = some listAppendSig)
    (view : q.view = .app (.prim "List.append" [.base .unit] [] [])
      [.list [.const .unit],.const .unit]) :
    ∃ Ψ, StoreOk P B σ Ψ μ ∧ HasTypeVQ P B Ψ Qempty [] [] [] (.const .unit) (.base .unit) ∧
      HasTypeEachQ P B Ψ Qempty [] [] [] [.const .unit] (.base .unit) :=
  list_append_reached_typed hP hPB hdecl hB hσ initial trace lookup view

namespace ListModel
private def constructors (c : ConName) : Option ConDecl :=
  if c = "Option.None" then some ⟨"Option",1,[]⟩
  else if c = "Option.Some" then some ⟨"Option",1,[.tvar 0]⟩ else none

def program : Program where
  defs := fun name =>
    if name = "List.mapFrom" then some (listFromDefinition false)
    else if name = "List.filterFrom" then some (listFromDefinition true) else none
  cons := constructors
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

private def getDelta (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome :=
  match name,ts,es,rs,ws with
  | "List.get",[a],[],[],[.list xs,.const (.integer i)] =>
    let found := if i.toInt < 0 then none else xs[i.toInt.toNat]?
    some (.val (match found with
      | none => .con "Option.None" [a] []
      | some x => .con "Option.Some" [a] [x]))
  | _,_,_,_,_ => none

def builtins : Builtins where
  sig := fun name =>
    if name = "List.get" then some listGetSig
    else if name = "List.append" then some listAppendSig
    else if name = "%Integer.add" then some listIndexAddSig else none
  delta := fun name ts es rs ws =>
    (getDelta name ts es rs ws).orElse (fun _ =>
      (StandardCollections.insertDelta name ts es rs ws).orElse (fun _ =>
        StandardScalar.integerDelta name ts es rs ws))
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun C a p => Benitoite.Release.satB [] C (StandardKeyTyping.carrier a) p = true
  refGet := "Reference.get"
  refSet := "Reference.set"

private theorem option_declarations : ListOptionDeclarations program := by
  have only : ∀ c cd, program.cons c = some cd →
      c = "Option.None" ∨ c = "Option.Some" := by
    intro c cd h
    simp only [program,constructors] at h
    split at h
    · exact Or.inl ‹_›
    · split at h
      · exact Or.inr ‹_›
      · cases h
  refine ⟨rfl,rfl,?_,fun c cd h _ => only c cd h⟩
  refine ⟨⟨"Option.None",_,rfl,rfl⟩,?_⟩
  intro c cd h _
  rcases only c cd h with rfl | rfl
  all_goals cases Option.some.inj h; rfl

/-- satB の空制約を使う実表で、四つの通常本体が型付けされる。 -/
theorem typed (filter : Bool) :
    (listFromRow filter).BodyTyped program builtins ∧
    (listHigherRow filter).BodyTyped program builtins := by
  have lookup : program.defs (listFromRow filter).name = some (listFromDefinition filter) := by
    cases filter <;> rfl
  constructor
  · exact listFrom_body_typed filter option_declarations rfl rfl rfl lookup (by
      intro i _; rfl)
  · exact listHigher_body_typed filter lookup (by intro i _; rfl)

example : (listFromRow false).BodyTyped program builtins := (typed false).1
example : (listHigherRow false).BodyTyped program builtins := (typed false).2
example : (listFromRow true).BodyTyped program builtins := (typed true).1
example : (listHigherRow true).BodyTyped program builtins := (typed true).2
private def unitIdentity : Val := .lam ["value"] [.base .unit] (.ret (.var 0))
private def receivedIdentity : Val := closeVal Capture.empty unitIdentity
private theorem received_identity_typed (P : Program) (B : Builtins) :
    HasTypeV P B StoreTy.empty [] [] [] receivedIdentity
      (.dependentFn (.param "value" (.base .unit) (.done (.base .unit) Eff.empty))) := by
  let t : Tel := .param "value" (.base .unit) (.done (.base .unit) Eff.empty)
  have ann : Ty.Annotation P [] [] (.dependentFn t) := by
    constructor <;> simp [t,Ty.WF,Tel.WF,Ty.Sorted,Tel.Sorted,Ty.Declared,Tel.Declared,
      Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Ty.normTys,sortedEff,declaredEff,Ty.WFList,sortedTys,declaredTys]
  have closed : Capture.empty.closeTel t = t := by
    simp [Capture.closeTel,t,Tel.bind,Tel.rawBind,Ty.rawBind,Tel.norm,Ty.norm,
      Eff.rawBind,Eff.empty,Eff.norm,Ty.normTys,rowFails,instAtoms_nil,substAtoms_nil,
      rawBindTys,valEnv,SubstEnv.up]
  have body : TelBodyTy P B (hideBuilders StoreTy.empty) Qempty [] (hideConts []) [] t (.ret (.var 0)) :=
    .param (.done (.C_Return (.V_Var rfl (by intro b r e; simp [Ty.core]))))
  have typed := DependentClosureTy.mk (CaptureOk.empty P B (hideBuilders StoreTy.empty) none)
    body ann (by rw [closed]; exact ann)
  rw [closed] at typed
  change HasTypeV P B StoreTy.empty [] [] []
    (.closure (Capture.empty.closeTel t) (.mk Capture.empty (.ret (.var 0)))) (.dependentFn t)
  rw [closed]
  exact .V_Closure ann ⟨ann.wf,ann.wf,by simp [t,Tel.SameInputs]⟩ typed

example (σ : PathEnv) (filter : Bool) :
    ∃ q, Steps program builtins σ
      (.run (.mk (listCapture [] receivedIdentity ⟨0,by decide⟩ []) (listFromBody filter)) [] Store.empty) []
      (.run q [] Store.empty) ∧ q.view = .ret (.list []) :=
  listFrom_none_steps filter [] [] receivedIdentity ⟨0,by decide⟩ [] Store.empty rfl rfl

example (σ : PathEnv) (filter : Bool) :
    Steps program builtins σ
      (.run (.mk (listCapture [.const .unit] receivedIdentity ⟨0,by decide⟩ []) (listFromBody filter)) [] Store.empty) []
      (.run ((callbackTail filter [.const .unit] [] receivedIdentity (.const .unit) ⟨0,by decide⟩).apply [.const .unit])
        [] Store.empty) := by
  refine listFrom_callback_normal filter [.const .unit] [] receivedIdentity (.const .unit)
    (.const .unit) ⟨0,by decide⟩ [] Store.empty Store.empty [] []
    (Closure.pure (.ret (.const .unit))) _ rfl rfl ?_ rfl .nil
  exact .cons (.E_Lam rfl rfl rfl) (.cons (.E_Mark rfl) .nil)

private def overflowCallback : Val :=
  .closure (.param "value" (.base .unit) (.done (.base .integer) Eff.empty))
    (.pure (.app (.prim "%Integer.add" [] [] [])
      [.const (.integer ⟨9223372036854775807,by decide⟩),one]))

example (σ : PathEnv) (filter : Bool) :
    Steps program builtins σ
      (.run (.mk (listCapture [.const .unit] overflowCallback ⟨0,by decide⟩ []) (listFromBody filter)) [] Store.empty) []
      (.error ["IntegerOverflow"] [] Store.empty) := by
  refine listFrom_callback_failed filter [.const .unit] [] overflowCallback (.const .unit)
    ⟨0,by decide⟩ [] Store.empty Store.empty [] ["IntegerOverflow"] rfl rfl ?_
  exact .cons (.E_Lam rfl rfl rfl)
    (.cons (.E_Err (ts := []) (es := []) (rs := [])
      (ws := [.const (.integer ⟨9223372036854775807,by decide⟩),one]) rfl rfl rfl rfl)
      (.cons .E_ErrPopMark .nil))

private def repeatTail : Comp := .app (.fnRef "Example.repeat" [] []) []
private def repeatDefinition : Def :=
  ⟨[],0,[],[],.list (.base .unit),Eff.empty,
    .letIn (.app (.fnRef "List.mapFrom" [.base .unit,.base .unit] [Eff.empty])
      [.list [.const .unit],unitIdentity,one,.list [.const .unit]]) repeatTail⟩
private def repeatProgram : Program :=
  { program with defs := fun name =>
    if name = "Example.repeat" then some repeatDefinition else program.defs name }
private def unitFromBody : Comp := (listFromBody false).substTy [.base .unit,.base .unit] [Eff.empty]
private def repeatCont : Cont := [.mark,.letF (Closure.pure repeatTail),.mark]

private theorem unit_none_steps {P σ} (xs acc : List Val) (f : Val)
    (i : Benitoite.Release.Integer64Value) (k : Cont) (μ : Store)
    (reply : builtins.delta "List.get" [.base .unit] [] [] [.list xs,.const (.integer i)] =
      some (.val (.con "Option.None" [.base .unit] []))) :
    ∃ q, Steps P builtins σ (.run (.mk (listCapture xs f i acc) unitFromBody) k μ) []
        (.run q k μ) ∧ q.view = .ret (.list acc) := by
  refine ⟨_,.cons (.E_Let rfl)
    (.cons (.E_Prim (ts := [.base .unit]) (es := []) (rs := [])
      (ws := [.list xs,.const (.integer i)]) rfl rfl rfl reply)
    (.cons (.E_Return rfl) (.cons (.E_Match rfl) (.cons (.E_MatchBody rfl rfl) .nil)))),rfl⟩

example : (listFromRow false).BodyTyped repeatProgram builtins :=
  listFrom_body_typed false ⟨option_declarations.none_decl,option_declarations.some_decl,
    option_declarations.arity,option_declarations.only⟩ rfl rfl rfl rfl (by intro i hi; rfl)

example : unitFromBody = (listFromBody false).substTy [.base .unit,.base .unit] [Eff.empty] := rfl
example :
    builtins.delta "List.get" [.base .unit] [] [] [.list [],zero] =
      some (.val (.con "Option.None" [.base .unit] [])) ∧
    builtins.delta "List.get" [.base .unit] [] [] [.list [.const .unit],one] =
      some (.val (.con "Option.None" [.base .unit] [])) := ⟨rfl,rfl⟩
example : repeatProgram.EffectsOk builtins := by
  refine ⟨?_,?_,?_⟩
  · intro l os o h ho; cases h
  · intro o od h; cases h
  · intro l os h; cases h

/-- 同じ継続の構文への再到達だけでは、最初の呼出しの正常返却を特定できない。 -/
theorem later_return_same_continuation (σ : PathEnv) :
    ∃ q, Steps repeatProgram builtins σ
      (.run (.mk (listCapture [] receivedIdentity ⟨0,by decide⟩ []) unitFromBody) repeatCont Store.empty) []
      (.run q repeatCont Store.empty) ∧ q.view = .ret (.list [.const .unit]) := by
  obtain ⟨first,headSteps,firstView⟩ := unit_none_steps (P := repeatProgram) (σ := σ)
    [] [] receivedIdentity ⟨0,by decide⟩ repeatCont Store.empty rfl
  obtain ⟨last,lastSteps,lastView⟩ := unit_none_steps (P := repeatProgram) (σ := σ)
    [.const .unit] [.const .unit] receivedIdentity ⟨1,by decide⟩ repeatCont Store.empty rfl
  have middle : Steps repeatProgram builtins σ (.run first repeatCont Store.empty) []
      (.run (.mk (listCapture [.const .unit] receivedIdentity ⟨1,by decide⟩ [.const .unit]) unitFromBody)
        repeatCont Store.empty) := by
    refine .cons (.E_Mark firstView) (.cons (.E_Return rfl)
      (.cons (.E_Fun (d := repeatDefinition) rfl rfl rfl rfl rfl)
        (.cons (.E_Let rfl)
          (.cons (.E_Fun (d := listFromDefinition false) rfl rfl rfl rfl rfl) ?_))))
    simp [unitFromBody,listCapture,receivedIdentity,unitIdentity,repeatDefinition,repeatTail,repeatCont,
        Comp.substTy,Comp.substTyAt,Val.substTyAt,Val.substTyAtList,substTypeAt,substRowAt,
        Ty.bind,Eff.bind,typeEnvAt,Ty.rawBind,Eff.rawBind,rawBindTys,
        Capture.closeTy,Capture.closeEff,substTyValues,substEffValues,Ty.norm,Eff.norm,Ty.normTys,
        Eff.empty,rowFails,instAtoms_nil,substAtoms_nil,closeVal,closeVals,Closure.apply,Closure.pure,
        Capture.empty,Capture.extendMany,Capture.extend,Capture.env,Capture.closeTel,lambdaShape,
        Tel.bind,Tel.rawBind,Tel.norm,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,markPush,valEnv,SubstEnv.up]
    exact .nil
  have whole := IntervalConnection.steps_trans headSteps (IntervalConnection.steps_trans middle lastSteps)
  exact ⟨last,by simpa using whole,lastView⟩

/-- 空の入力に対する長さ0の契約は、末端の同じ継続だけでは偽になる。 -/
theorem endpoint_length_not_contract (σ : PathEnv) :
    ¬ (∀ q, Steps repeatProgram builtins σ
      (.run (.mk (listCapture [] receivedIdentity ⟨0,by decide⟩ []) unitFromBody) repeatCont Store.empty) []
      (.run q repeatCont Store.empty) →
      ∀ ys, q.view = .ret (.list ys) → ys.length = ([] : List Val).length) := by
  intro contract
  obtain ⟨q,trace,normal⟩ := later_return_same_continuation σ
  have impossible := contract q trace [.const .unit] normal
  cases impossible

example (σ : PathEnv) :
    ¬ (∀ q, Steps repeatProgram builtins σ
      (.run (.mk (listCapture [] receivedIdentity ⟨0,by decide⟩ []) unitFromBody) repeatCont Store.empty) []
      (.run q repeatCont Store.empty) →
      ∀ ys, q.view = .ret (.list ys) → ys.length = ([] : List Val).length) :=
  endpoint_length_not_contract σ

example (σ : PathEnv) :
    HasTypeV repeatProgram builtins StoreTy.empty [] [] [] receivedIdentity
      (.dependentFn (.param "value" (.base .unit) (.done (.base .unit) Eff.empty))) ∧
    ∃ q, Steps repeatProgram builtins σ
      (.run (.mk (listCapture [] receivedIdentity ⟨0,by decide⟩ []) unitFromBody) repeatCont Store.empty) []
      (.run q repeatCont Store.empty) ∧ q.view = .ret (.list [.const .unit]) :=
  ⟨received_identity_typed _ _,later_return_same_continuation σ⟩

example (σ : PathEnv) :
    ∃ q, Steps repeatProgram builtins σ
      (.run (.mk (listCapture [] receivedIdentity ⟨0,by decide⟩ []) unitFromBody) repeatCont Store.empty) []
      (.run q repeatCont Store.empty) ∧ q.view = .ret (.list [.const .unit]) :=
  later_return_same_continuation σ

example : closeVal Capture.empty unitIdentity ≠ unitIdentity := by
  intro impossible
  cases impossible

private def unitFromBodyAt (E : Eff) : Comp :=
  (listFromBody false).substTy [.base .unit,.base .unit] [E]

private theorem unit_none_first {P σ} (E : Eff) (xs acc : List Val) (f : Val)
    (i : Benitoite.Release.Integer64Value) (k : Cont) (μ : Store)
    (reply : builtins.delta "List.get" [.base .unit] [] [] [.list xs,.const (.integer i)] =
      some (.val (.con "Option.None" [.base .unit] []))) :
    ∃ q, FirstReturn P builtins σ k (.run (.mk (listCapture xs f i acc) (unitFromBodyAt E)) k μ)
      [] q μ (.list acc) := by
  refine ⟨_,.step (ReturnAt.not_view (by intro v h; cases h)) (.E_Let rfl)
    (.step (ReturnAt.not_let k _ _ μ)
      (.E_Prim (ts := [.base .unit]) (es := []) (rs := [])
        (ws := [.list xs,.const (.integer i)]) rfl rfl rfl reply)
      (.step (ReturnAt.not_let k _ _ μ) (.E_Return rfl)
        (.step (ReturnAt.not_view (by intro v h; cases h)) (.E_Match rfl)
          (.step (ReturnAt.not_match k _ _ _ _ μ) (.E_MatchBody rfl rfl) (.done rfl)))))⟩

private def failEffect : Eff := Eff.singleFail (.base .unit)
private def failingCallback : Val :=
  .closure (.param "value" (.base .unit) (.done (.base .unit) failEffect))
    (.pure (.app (.raise (.base .unit) (.base .unit)) [.const .unit]))
private theorem failing_callback_typed (P : Program) (B : Builtins) :
    HasTypeV P B StoreTy.empty [] [] [] failingCallback
      (.dependentFn (.param "value" (.base .unit) (.done (.base .unit) failEffect))) := by
  let t : Tel := .param "value" (.base .unit) (.done (.base .unit) failEffect)
  have ann : Ty.Annotation P [] [] (.dependentFn t) := by
    constructor <;> simp [t,failEffect,Ty.WF,Tel.WF,Ty.WFList,Ty.Sorted,Tel.Sorted,sortedTys,
      Ty.Declared,Tel.Declared,declaredTys,Eff.WF,Eff.Canonical,Eff.singleFail,Eff.norm,
      Ty.normTys,Ty.norm,sortedEff,declaredEff]
  have raisedAnn : Ty.Annotation P [] [some (.base .unit)]
      (.fn ["error"] [.base .unit] (.base .unit) failEffect) := by
    constructor <;> simp [failEffect,Ty.WF,Ty.WFList,Ty.Sorted,sortedTys,Ty.Declared,declaredTys,
      NamesWF,Eff.WF,Eff.Canonical,Eff.singleFail,Eff.norm,Ty.normTys,Ty.norm,sortedEff,declaredEff]
  have body : TelBodyTy P B (hideBuilders StoreTy.empty) Qempty [] (hideConts []) [] t
      (.app (.raise (.base .unit) (.base .unit)) [.const .unit]) :=
    .param (.done (.C_App (.V_Raise raisedAnn (by intro b r e; simp [Ty.core])
      (by intro b r e; simp [Ty.core]) trivial) (.cons (.V_Const trivial) .nil)))
  have closed : Capture.empty.closeTel t = t := by
    simp [Capture.closeTel,t,failEffect,Tel.bind,Tel.rawBind,Ty.rawBind,Tel.norm,Ty.norm,
      Eff.rawBind,Eff.singleFail,Eff.norm,Ty.normTys,rowFails,instAtoms_nil,substAtoms_nil,
      rawBindTys,valEnv,SubstEnv.up]
  have typed := DependentClosureTy.mk (CaptureOk.empty P B (hideBuilders StoreTy.empty) none)
    body ann (by rw [closed]; exact ann)
  rw [closed] at typed
  exact .V_Closure ann ⟨ann.wf,ann.wf,by simp [Tel.SameInputs]⟩ typed

private def failHandler : List Clause := [.fail (.base .unit) (.ret (.list []))]
private def failTail : Comp := .app (.fnRef "Example.repeatFail" [] []) []
private def repeatFailDefinition : Def :=
  ⟨[],0,[],[],.list (.base .unit),Eff.empty,
    .letIn (.handle
      (.app (.fnRef "List.mapFrom" [.base .unit,.base .unit] [failEffect])
        [.list [],failingCallback,zero,.list []]) failHandler) failTail⟩
private def repeatFailProgram : Program :=
  { program with defs := fun name =>
    if name = "Example.repeatFail" then some repeatFailDefinition else program.defs name }
private def failCont : Cont := [.mark,.handleF Capture.empty failHandler,.letF (Closure.pure failTail),.mark]

private theorem set_overwrite (μ : Store) (l : Nat) (a b : Cell) :
    (μ.set l a).set l b = μ.set l b := by
  funext n
  by_cases h : n = l <;> simp [Store.set,h]

/-- 外側のhandlerによる中断と再呼出しは、最初の同じkでのretだけでも区別できない。 -/
theorem first_return_after_handler_abort (σ : PathEnv) :
    ∃ q μ, FirstReturn repeatFailProgram builtins σ failCont
      (.run (.mk (listCapture [.const .unit] failingCallback ⟨0,by decide⟩ []) (unitFromBodyAt failEffect))
        failCont Store.empty) [] q μ (.list []) := by
  let saved : Cont := [.mark,
    .letF (.mk (((listCapture [.const .unit] failingCallback ⟨0,by decide⟩ []).extend
        (.con "Option.Some" [.base .unit] [.const .unit])).extend (.const .unit))
      ((listFromAfterCall false).substTy [.base .unit,.base .unit] [failEffect])),
    .mark,.handleF Capture.empty failHandler]
  let usedStore : Store := Store.empty.set 0 .used
  obtain ⟨last,lastFirst⟩ := unit_none_first (P := repeatFailProgram) (σ := σ) failEffect
    [] [] failingCallback ⟨0,by decide⟩ failCont usedStore rfl
  refine ⟨last,usedStore,?_⟩
  refine .step (ReturnAt.not_view (by intro v h; cases h)) (.E_Let rfl)
    (.step (ReturnAt.not_let failCont _ _ Store.empty)
      (.E_Prim (ts := [.base .unit]) (es := []) (rs := [])
        (ws := [.list [.const .unit],zero]) rfl rfl rfl rfl)
      (.step (ReturnAt.not_let failCont _ _ Store.empty) (.E_Return rfl)
        (.step (ReturnAt.not_view (by intro v h; cases h)) (.E_Match rfl)
          (.step (ReturnAt.not_match failCont _ _ _ _ Store.empty) (.E_MatchSkip rfl rfl)
            (.step (ReturnAt.not_match failCont _ _ _ _ Store.empty)
              (.E_MatchBody (ws := [.const .unit]) rfl rfl)
              (.step (ReturnAt.not_view (by intro v h; cases h)) (.E_Let rfl) ?_))))))
  refine .step (ReturnAt.not_let failCont _ _ Store.empty) (.E_Lam rfl rfl rfl) ?_
  refine .step (ReturnAt.not_length (by simp [failCont,markPush]))
    (.E_OpFail (κ := 0) (E := .base .unit) (body := .ret (.list [])) (k1 := saved.take 3) (hcap := Capture.empty)
      (k2 := [.letF (Closure.pure failTail),.mark]) rfl ?_ rfl) ?_
  · refine ⟨rfl,rfl,?_⟩
    intro cap clauses member
    simp [saved] at member
  refine .step (ReturnAt.not_length (by simp [failCont])) (.E_DropRel rfl rfl) ?_
  refine .step (ReturnAt.not_length (by simp [failCont])) (.E_Return rfl) ?_
  refine .step (ReturnAt.not_length (by simp [failCont]))
    (.E_Fun (d := repeatFailDefinition) (ts := []) (es := []) (ws := []) rfl rfl rfl rfl rfl) ?_
  refine .step (ReturnAt.not_length (by simp [failCont,markPush])) (.E_Let rfl) ?_
  refine .step (ReturnAt.not_length (by simp [failCont,markPush])) (.E_Handle rfl) ?_
  refine .step (ReturnAt.not_length (by simp [failCont,markPush]))
    (.E_Fun (d := listFromDefinition false) rfl rfl rfl rfl rfl) ?_
  simpa [set_overwrite,Closure.capture,Closure.code,Capture.values,listFromDefinition,zero,Clause.substTyAtList,unitFromBodyAt,listCapture,repeatFailDefinition,failTail,failCont,usedStore,saved,
    Comp.substTy,Comp.substTyAt,Val.substTyAt,Val.substTyAtList,substTypeAt,substRowAt,
    Ty.bind,Eff.bind,typeEnvAt,Ty.rawBind,Eff.rawBind,rawBindTys,
    Capture.closeTy,Capture.closeEff,substTyValues,substEffValues,Ty.norm,Eff.norm,Ty.normTys,
    Eff.empty,rowFails,instAtoms_nil,substAtoms_nil,closeVal,closeVals,Closure.apply,Closure.pure,
    Capture.empty,Capture.extendMany,Capture.extend,Capture.env,markPush,valEnv,SubstEnv.up,
    releases,failHandler,failingCallback,failEffect,Eff.singleFail] using lastFirst

example : (listFromRow false).BodyTyped repeatFailProgram builtins :=
  listFrom_body_typed false ⟨option_declarations.none_decl,option_declarations.some_decl,
    option_declarations.arity,option_declarations.only⟩ rfl rfl rfl rfl (by intro i hi; rfl)
example : repeatFailProgram.EffectsOk builtins := by
  refine ⟨?_,?_,?_⟩
  · intro l os o h ho; cases h
  · intro o od h; cases h
  · intro l os h; cases h
example : unitFromBodyAt failEffect =
    (listFromBody false).substTy [.base .unit,.base .unit] [failEffect] := rfl
example :
    builtins.delta "List.get" [.base .unit] [] [] [.list [.const .unit],zero] =
      some (.val (.con "Option.Some" [.base .unit] [.const .unit])) ∧
    builtins.delta "List.get" [.base .unit] [] [] [.list [],zero] =
      some (.val (.con "Option.None" [.base .unit] [])) := ⟨rfl,rfl⟩

/-- 最初の同じkでのretも、外側handlerによる中断の後の別呼出しを含みうる。 -/
theorem first_return_length_not_contract (σ : PathEnv) :
    ¬ (∀ q μ ys, FirstReturn repeatFailProgram builtins σ failCont
      (.run (.mk (listCapture [.const .unit] failingCallback ⟨0,by decide⟩ []) (unitFromBodyAt failEffect))
        failCont Store.empty) [] q μ (.list ys) → ys.length = 1) := by
  intro contract
  obtain ⟨q,μ,trace⟩ := first_return_after_handler_abort σ
  have impossible := contract q μ [] trace
  cases impossible

example (σ : PathEnv) :
    HasTypeV repeatFailProgram builtins StoreTy.empty [] [] [] failingCallback
      (.dependentFn (.param "value" (.base .unit) (.done (.base .unit) failEffect))) ∧
    ∃ q μ, FirstReturn repeatFailProgram builtins σ failCont
      (.run (.mk (listCapture [.const .unit] failingCallback ⟨0,by decide⟩ []) (unitFromBodyAt failEffect))
        failCont Store.empty) [] q μ (.list []) :=
  ⟨failing_callback_typed _ _,first_return_after_handler_abort σ⟩
example (σ : PathEnv) :
    ¬ (∀ q μ ys, FirstReturn repeatFailProgram builtins σ failCont
      (.run (.mk (listCapture [.const .unit] failingCallback ⟨0,by decide⟩ []) (unitFromBodyAt failEffect))
        failCont Store.empty) [] q μ (.list ys) → ys.length = 1) :=
  first_return_length_not_contract σ

example {P B σ Eb cap k μ events q μ' ys}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (initial : StateTyE P B σ Eb (.run (.mk cap (listFromBody false)) k μ))
    (normal : FirstReturn P B σ k (.run (.mk cap (listFromBody false)) k μ) events q μ' (.list ys)) :
    StateTyE P B σ Eb (.run q k μ') :=
  normal.typed hP hPB hdecl hB hσ initial

end ListModel

end
end Benitoite.Release.Refinement.StandardBodies
