import Benitoite.Release.Refinement.StandardModelResponse
import Benitoite.Release.Refinement.StandardModelGeneral

/-! # 合成表の名前で参照するListのmapとfilterの本体

合成プログラムは、同じ公開名に通常側と精密側の二つの元の定義を持つListのmap・filterとその
補助を、内部の名前（`FunctionNames.rename`）で持つ。元の本体と関数参照の名前だけが異なる
合成用の定義を、元の証明の構成（StandardActualListBodies・StandardHeadTailBodies）で検査する。
通常側の補助は、合成表のList.getと精密なList.appendの署名から結果の篩を忘れて読む。 -/
namespace Benitoite.Release.Refinement.StandardModelOrdinaryList
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
    (fromTel filter).result,(fromTel filter).effect,listFromBody filter, []⟩

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
      simpa [FnView.toTel,Ty.toTel,shiftVTys,Ty.shiftV,Eff.shiftV,Eff.empty] using Ty.foldFn_toTel ⟨["xs","i"],[.list (.tvar i),.base .integer],.data "Option" [.tvar i],Eff.empty,by simp [NamesWF]⟩
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
        simpa [FnView.toTel,Ty.toTel,shiftVTys,Ty.shiftV,Eff.shiftV,Eff.empty] using Ty.foldFn_toTel ⟨["left","right"],[.base .integer,.base .integer],.base .integer,Eff.empty,by simp [NamesWF]⟩
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
  have typed := HasTypeVQ.fun_empty (Ψ := Ψ) (Φ := Φ) lookup names (by rfl) admissible (from_instance filter)
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
      · list_simp
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
  · exact (from_annotation (P := P) (Γ := []) filter).range_empty
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
end Benitoite.Release.Refinement.StandardModelOrdinaryList

/-! # 残りの列と累積の長さを検査するmap・filter -/
namespace Benitoite.Release.Refinement.StandardModelPreciseList
open StandardHeadTail
noncomputable section
set_option linter.unusedSimpArgs false

private def params (filter : Bool) : TypeCtx := List.replicate (if filter then 1 else 2) TypeCtx.valueParam
private def output (filter : Bool) : Ty := if filter then .tvar 0 else .tvar 1
private def arguments (filter : Bool) : List Ty := if filter then [.tvar 0] else [.tvar 0,.tvar 1]
private def callback (filter : Bool) : Ty :=
  .fn ["value"] [.tvar 0] (if filter then .base .boolean else .tvar 1) (Eff.row 0)
private def relation (filter : Bool) (a b : Term) : Pred := if filter then .le a b else .eq a b

def fromName (filter : Bool) : String := if filter then "%List.filterFrom.refined" else "%List.mapFrom.refined"
def invariant (filter : Bool) (acc rest total : Term) : Pred :=
  relation filter (.add (length acc) (length rest)) (length total)
def fromTel (filter : Bool) : Tel :=
  .param "xs" (.list (.tvar 0)) (.param (if filter then "p" else "f") (callback filter)
    (.param "rest" (.list (.tvar 0))
      (.param "acc" (.refined (.list (output filter)) (invariant filter (.var 0) (.var 1) (.var 3)))
        (.done (.refined (.list (output filter)) (relation filter (length (.var 0)) (length (.var 4)))) (Eff.row 0)))))
def publicTel (filter : Bool) : Tel :=
  .param "xs" (.list (.tvar 0)) (.param (if filter then "p" else "f") (callback filter)
    (.done (.refined (.list (output filter)) (relation filter (length (.var 0)) (length (.var 2)))) (Eff.row 0)))

private def recurse (filter : Bool) (xs f rest acc : Nat) : Comp :=
  .app (.fnRef (fromName filter) (arguments filter) [Eff.row 0]) [.var xs,.var f,.var rest,.var acc]
private def appended (filter : Bool) : Comp :=
  .letIn (.app (.prim "List.append" [output filter] [] []) [.var 5,.var (if filter then 3 else 2)])
    (recurse filter 9 8 1 0)
private def afterTail (filter : Bool) : Comp :=
  if filter then .ite (.var 2) (appended true) (recurse true 8 7 0 5) else appended false
private def tailArms (filter : Bool) : List Arm :=
  [.mk [⟨.con "Option.None" [],[]⟩] none (.ret (.var 4)),
   .mk [⟨.con "Option.Some" [.var],[0]⟩] none (afterTail filter)]
private def afterCallback (filter : Bool) : Comp :=
  .letIn (.app (.prim "List.tail" [.tvar 0] [] []) [.var 4]) (.match (.var 0) (tailArms filter))
private def headArms (filter : Bool) : List Arm :=
  [.mk [⟨.con "Option.None" [],[]⟩] none (.ret (.var 1)),
   .mk [⟨.con "Option.Some" [.var],[0]⟩] none
    (.letIn (.app (.var 4) [.var 0]) (afterCallback filter))]

/-- callbackの結果を一度束縛してからtailを呼ぶ。helperは公開引数を増やさない。 -/
def fromBody (filter : Bool) : Comp :=
  .letIn (.app (.prim "List.head" [.tvar 0] [] []) [.var 1]) (.match (.var 0) (headArms filter))
def publicBody (filter : Bool) : Comp :=
  .app (.fnRef (fromName filter) (arguments filter) [Eff.row 0]) [.var 1,.var 0,.var 1,.list []]
def fromRow (filter : Bool) : StandardContracts.Row :=
  ⟨fromName filter,params filter,1,fromTel filter,some (fromBody filter),.core,[if filter then .listFilter else .listMap]⟩
def publicRow (filter : Bool) : StandardContracts.Row :=
  ⟨if filter then "List.filter" else "List.map",params filter,1,publicTel filter,some (publicBody filter),.core,
    [if filter then .listFilter else .listMap]⟩
def fromDefinition (filter : Bool) : Def :=
  ⟨params filter,1,(fromTel filter).names,(fromTel filter).inputs,(fromTel filter).result,(fromTel filter).effect,fromBody filter, []⟩
def publicDefinition (filter : Bool) : Def :=
  ⟨params filter,1,(publicTel filter).names,(publicTel filter).inputs,(publicTel filter).result,(publicTel filter).effect,publicBody filter, []⟩

private theorem row_self : substAtoms [Eff.row 0] (Eff.row 0).atoms = (Eff.row 0).atoms := by
  funext a
  cases a with
  | name l r => simp [substAtoms,Eff.row,Eff.atoms,Eff.test]
  | rho i => cases i <;> simp [substAtoms,Eff.row,Eff.atoms,Eff.test]

private inductive Primitive where | head | tail | append
private def Primitive.name : Primitive → String
  | .head => "List.head" | .tail => "List.tail" | .append => "List.append"
private def Primitive.signature : Primitive → PrimSig
  | .head => headSignature | .tail => tailSignature | .append => appendSignature
private def Primitive.tel (p : Primitive) (a : Ty) : Tel :=
  match p with
  | .head => .param "xs" (.list a) (.done (.refined (.data "Option" [a]) (headPredicate (.var 0) (.var 1))) Eff.empty)
  | .tail => .param "xs" (.list a) (.done (.refined (.data "Option" [.list a]) (tailPredicate (.var 0) (.var 1))) Eff.empty)
  | .append => .param "xs" (.list a) (.param "x" a (.done (.refined (.list a) (appendPredicate (.var 0) (.var 2))) Eff.empty))

private def headType (xs : Term) : Ty := .refined (.data "Option" [.tvar 0])
  (headPredicate (.var 0) (termBind (fun i => some (.var (i+1))) xs))
private def tailType (xs : Term) : Ty := .refined (.data "Option" [.list (.tvar 0)])
  (tailPredicate (.var 0) (termBind (fun i => some (.var (i+1))) xs))
private def appendType (filter : Bool) (xs : Term) : Ty := .refined (.list (output filter))
  (appendPredicate (.var 0) (termBind (fun i => some (.var (i+1))) xs))

private theorem empty_range : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
  funext a; cases a <;> simp [mapRangeAtoms]

local macro "walk_simp" : tactic => `(tactic|
 try simp_all [InternalContracts.length,InternalContracts.nonemptyMap,InternalContracts.nonempty,nonemptyType,nonemptyPredicate,headType,tailType,appendType,empty_range,Tel.argumentsEnv,valEnv,Val.toTerm?,Primitive.name,Primitive.signature,Primitive.tel,params,output,arguments,callback,relation,invariant,fromName,fromTel,publicTel,fromRow,
   publicRow,fromDefinition,publicDefinition,headSignature,tailSignature,appendSignature,
   headPredicate,tailPredicate,appendPredicate,length,someField,
   Def.tel,PrimSig.tel,signatureTel,Tel.names,Tel.inputs,Tel.result,Tel.effect,
   TypeCtx.valueParam,TypeCtx.kinds,TypeCtx.constraints,TParamDecl.constraints,
   TypeAnnotations,RowAnnotations,Ty.Annotation,Ty.WF,Tel.WF,Ty.WFList,Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,
   Ty.Declared,Tel.Declared,declaredTys,declaredEff,Ty.HasKind,kindsTel,kindsList,kindsEff,
   NamesWF,Eff.WF,Eff.Canonical,Eff.empty,Eff.row,Eff.norm,Ordinary,Ty.core,Ty.NotContCore,
   Builtins.RangeAdmissible,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
   Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,Tel.bind,Tel.rawBind,Ty.bind,Ty.rawBind,rawBindTys,
   Ty.norm,Tel.norm,Ty.normTys,typeEnvAt,SubstEnv.up,SubstEnv.rangesOnly,Eff.rawBind,rowFails,
   substAtoms_nil,instAtoms_nil,row_self,Qsig,QTel,QTy,QTys,QEff,Qempty,Eff.RowsIn,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,
   RowTransport,NoFail,SatAll,Eff.test,Eff.atoms,Eff.fails,Eff.shiftV,Ty.shiftV,shiftVTys,Tel.shiftV,Ctx.extend,
   bindParams,localExtend,Pred.lift,liftMany,predBind,termBind,termBind?,upValues,
   Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,
   Pred.Sorted,Pred.WF,Pred.Declared,Pred.VarsIn,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,
   Term.Declared,Ctx.Readable,Ctx.declarationSelf,Ty.HasSort,Ty.sort?,Measure.input,Measure.output])

structure Inputs (P : Program) (B : Builtins) : Prop where
  declarations : StandardActualListBodies.ListOptionDeclarations P
  head : B.sig "List.head" = some headSignature
  tail : B.sig "List.tail" = some tailSignature
  append : B.sig "List.append" = some appendSignature
  helpers : ∀ filter, P.defs (fromName filter) = some (fromDefinition filter)
  sat : ∀ C a, B.sat C a {}

private theorem from_instance {P Γ} (filter : Bool) :
    SignatureInstance P (params filter) Γ (fromDefinition filter).tel
      (TypeCtx.kinds (fromDefinition filter).tparams) (arguments filter) [Eff.row 0] := by
  have selfrow := row_self
  simp only [Eff.row,Eff.atoms] at selfrow
  cases filter <;> constructor
  all_goals
    solve
    | walk_simp
    | (constructor <;> walk_simp)
    | (walk_simp; constructor <;> constructor <;> walk_simp)
    | (intro e he; cases List.mem_singleton.mp he; constructor <;> walk_simp)
    | (intro e he; cases List.mem_singleton.mp he; walk_simp)
    | (constructor; walk_simp; rintro (_|(_|j)) a k ha hk <;> walk_simp <;> (subst_vars; walk_simp))

private theorem from_reference {P B Ψ Q Γ Φ} (inp : Inputs P B) (filter : Bool) :
    HasTypeVQ P B Ψ Q (params filter) Γ Φ (.fnRef (fromName filter) (arguments filter) [Eff.row 0])
      (.dependentFn (fromTel filter)) := by
  have selfrow := row_self
  simp only [Eff.row,Eff.atoms] at selfrow
  have names : NamesWF (fromDefinition filter).names (fromDefinition filter).params := by cases filter <;> walk_simp
  have ad : Admissible B (params filter) Γ.length
      (TypeCtx.constraints (fromDefinition filter).tparams) 1
      (Qsig (fromDefinition filter).params (fromDefinition filter).ret (fromDefinition filter).eff) Q
      (arguments filter) [Eff.row 0] (fromDefinition filter).eff := by
    cases filter <;> constructor
    all_goals first | (constructor <;> walk_simp) | walk_simp
    all_goals rintro (_|(_|j)) a p ha hp <;> walk_simp <;> subst_vars
    all_goals exact inp.sat _ _
  have typed := HasTypeVQ.fun_empty (Ψ := Ψ) (Φ := Φ) (inp.helpers filter) names (by rfl) ad (from_instance filter)
  have same : instantiatedTel (fromDefinition filter).tel (arguments filter) [Eff.row 0] = fromTel filter := by
    cases filter <;> walk_simp
  rw [same] at typed
  exact typed

local macro "declarations_solve" ident:ident : tactic => `(tactic|
 first
 | (exact ⟨_,_,_,Term.HasData.var rfl rfl,($ident).declarations.none_decl,rfl⟩)
 | (exact ⟨_,_,_,Term.HasData.var rfl rfl,($ident).declarations.some_decl,rfl⟩)
 | (exact ⟨_,⟨_,Term.HasData.var rfl rfl⟩,_,($ident).declarations.none_decl,rfl⟩)
 | (exact ⟨_,⟨_,Term.HasData.var rfl rfl⟩,_,($ident).declarations.some_decl,rfl⟩)
 | (refine ⟨_,_,_,Term.HasData.var rfl rfl,($ident).declarations.some_decl,rfl,rfl,rfl,?_,rfl⟩
    simp [Ty.WF]))

private theorem primitive_annotation {P B Γ} (inp : Inputs P B) (filter : Bool)
    (i : Nat) (inside : i < (if filter then 1 else 2)) (p : Primitive) :
    Ty.Annotation P (params filter) Γ (.dependentFn (p.tel (.tvar i))) := by
  have ar := TyCon.arity_data inp.declarations.arity
  cases filter <;> cases p <;> constructor
  all_goals simp only [Primitive.tel]
  all_goals walk_simp
  all_goals refine ⟨inp.declarations.arity,?_⟩
  all_goals first
    | declarations_solve inp
    | (refine ⟨?_,?_,?_⟩ <;> declarations_solve inp)

private theorem primitive_reference {P B Ψ Q Γ Φ} (inp : Inputs P B) (filter : Bool)
    (i : Nat) (inside : i < (if filter then 1 else 2)) (p : Primitive) :
    HasTypeVQ P B Ψ Q (params filter) Γ Φ (.prim p.name [.tvar i] [] []) (.dependentFn (p.tel (.tvar i))) := by
  have lookup : B.sig p.name = some p.signature := by cases p; exact inp.head; exact inp.tail; exact inp.append
  have ar := TyCon.arity_data inp.declarations.arity
  have range : B.RangeAdmissible p.name p.signature [] := by cases p <;> simp only [Primitive.name,Primitive.signature] <;> walk_simp
  have names : NamesWF p.signature.names p.signature.params := by cases p <;> simp only [Primitive.signature] <;> walk_simp
  have admissible : PrimitiveAdmissible (params filter) Γ.length p.signature Q [.tvar i] [] := by
    cases p <;> simp only [Primitive.signature] <;> constructor <;> walk_simp
  have normal : instantiatedTel (Tel.instR [] p.signature.tel) [.tvar i] [] = p.tel (.tvar i) := by
    clear lookup range names admissible ar
    cases p <;> simp only [Primitive.signature,Primitive.tel] <;> walk_simp
    all_goals funext a; cases a <;> simp [mapRangeAtoms]
  have inst : SignatureInstance P (params filter) Γ (Tel.instR [] p.signature.tel)
      (TypeCtx.kinds p.signature.tparams) [.tvar i] [] := by
    constructor
    · cases p <;> simp only [Primitive.signature] <;> walk_simp
    · intro t ht; cases List.mem_singleton.mp ht
      clear normal lookup range names admissible ar
      constructor <;> walk_simp
    · refine ⟨by cases p <;> rfl,?_⟩
      rintro (_|j) t k ht hk
      · cases Option.some.inj ht
        cases p <;> cases Option.some.inj hk <;> constructor <;> walk_simp
      · simp at ht
    · intro e he; cases he
    · intro e he; cases he
    · rw [normal]; exact primitive_annotation inp filter i inside p
  have typed := HasTypeVQ.V_Prim (Ψ := Ψ) (Φ := Φ) lookup range names admissible inst
  rw [normal] at typed
  exact typed

private def map_none_premise : Pred := (.and (.eq (.add (.var 0) (.var 1)) (.var 2)) (.eq (.var 1) (.integer 0)))
private def map_none_goal : Pred := (.eq (.var 0) (.var 2))
private def map_none_certificate : Certificate := (.refute (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.cases (.consume (.derive (.combine [(1,1),(2,1),(4,1)] ⟨List.replicate 6 0,-1⟩) (.closeLinear 5))) (.consume (.derive (.combine [(0,1),(3,1),(4,1)] ⟨List.replicate 6 0,-1⟩) (.closeLinear 5)))))))))))))
private theorem map_none_checked : CertificateKernel.check map_none_premise map_none_goal map_none_certificate = true := by decide

private def map_append_premise : Pred := (.and (.eq (.add (.var 0) (.var 1)) (.var 2)) (.and (.eq (.var 3) (.add (.var 1) (.integer (-1)))) (.and (.eq (.var 4) (.var 3)) (.eq (.var 5) (.add (.var 0) (.integer 1))))))
private def map_append_goal : Pred := (.eq (.add (.var 5) (.var 4)) (.var 2))
private def map_append_certificate : Certificate := (.refute (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.cases (.consume (.derive (.combine [(1,1),(3,1),(5,1),(7,1),(8,1)] ⟨List.replicate 12 0,-1⟩) (.closeLinear 9))) (.consume (.derive (.combine [(0,1),(2,1),(4,1),(6,1),(8,1)] ⟨List.replicate 12 0,-1⟩) (.closeLinear 9)))))))))))))))))))))
private theorem map_append_checked : CertificateKernel.check map_append_premise map_append_goal map_append_certificate = true := by decide

private def map_initial_premise : Pred := .truth
private def map_initial_goal : Pred := (.eq (.add (.integer 0) (.var 0)) (.var 0))
private def map_initial_certificate : Certificate := (.refute (.consume (.consume (.cases (.consume (.derive (.combine [(0,1)] ⟨List.replicate 2 0,-1⟩) (.closeLinear 1))) (.consume (.derive (.combine [(0,1)] ⟨List.replicate 2 0,-1⟩) (.closeLinear 1)))))))
private theorem map_initial_checked : CertificateKernel.check map_initial_premise map_initial_goal map_initial_certificate = true := by decide

private def filter_none_premise : Pred := (.and (.le (.add (.var 0) (.var 1)) (.var 2)) (.eq (.var 1) (.integer 0)))
private def filter_none_goal : Pred := (.le (.var 0) (.var 2))
private def filter_none_certificate : Certificate := (.refute (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.derive (.combine [(0,1),(2,1),(3,1)] ⟨List.replicate 6 0,-1⟩) (.closeLinear 4))))))))))
private theorem filter_none_checked : CertificateKernel.check filter_none_premise filter_none_goal filter_none_certificate = true := by decide

private def filter_append_premise : Pred := (.and (.le (.add (.var 0) (.var 1)) (.var 2)) (.and (.eq (.var 3) (.add (.var 1) (.integer (-1)))) (.and (.eq (.var 4) (.var 3)) (.eq (.var 5) (.add (.var 0) (.integer 1))))))
private def filter_append_goal : Pred := (.le (.add (.var 5) (.var 4)) (.var 2))
private def filter_append_certificate : Certificate := (.refute (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.derive (.combine [(0,1),(1,1),(3,1),(5,1),(7,1)] ⟨List.replicate 12 0,-1⟩) (.closeLinear 8))))))))))))))))))
private theorem filter_append_checked : CertificateKernel.check filter_append_premise filter_append_goal filter_append_certificate = true := by decide

private def filter_initial_premise : Pred := .truth
private def filter_initial_goal : Pred := (.le (.add (.integer 0) (.var 0)) (.var 0))
private def filter_initial_certificate : Certificate := (.refute (.consume (.consume (.consume (.derive (.combine [(0,1)] ⟨List.replicate 2 0,-1⟩) (.closeLinear 1))))))
private theorem filter_initial_checked : CertificateKernel.check filter_initial_premise filter_initial_goal filter_initial_certificate = true := by decide

private def filter_skip_premise : Pred := (.and (.le (.add (.var 0) (.var 1)) (.var 2)) (.and (.eq (.var 3) (.add (.var 1) (.integer (-1)))) (.eq (.var 4) (.var 3))))
private def filter_skip_goal : Pred := (.le (.add (.var 0) (.var 4)) (.var 2))
private def filter_skip_certificate : Certificate := (.refute (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.derive (.combine [(0,1),(1,1),(3,1),(5,1)] ⟨List.replicate 10 0,-2⟩) (.closeLinear 6))))))))))))))
private theorem filter_skip_checked : CertificateKernel.check filter_skip_premise filter_skip_goal filter_skip_certificate = true := by decide


private theorem implication {Ξ : List Pred} {p q : Pred}
    (h : Entails Ξ (.or (.not p) q)) (hp : Entails Ξ p) : Entails Ξ q := by
  apply Entails.or_elim h
  · apply Entails.false_elim
    exact .not_elim (hp.weaken (fun _ h => List.mem_cons_of_mem _ h)) (.hyp List.mem_cons_self)
  · exact .hyp List.mem_cons_self

private theorem none_entails {Ξ : List Pred} (filter : Bool) (result rest acc total : Term)
    (ct : Entails Ξ (headPredicate result rest))
    (path : Entails Ξ (.constructorIs result "Option.None"))
    (inv : Entails Ξ (invariant filter acc rest total)) :
    Entails Ξ (relation filter (length acc) (length total)) := by
  have empty := implication ct path
  let ν : ObservationEnv := fun i => if i=0 then some (length acc) else if i=1 then some (length rest) else some (length total)
  cases filter
  · exact Entails.checkedAt ν map_none_checked (.and_intro inv empty)
  · exact Entails.checkedAt ν filter_none_checked (.and_intro inv empty)

private theorem append_entails {Ξ : List Pred} (filter : Bool) (result rest acc total ys acc' : Term)
    (ct : Entails Ξ (tailPredicate result rest))
    (path : Entails Ξ (.constructorIs result "Option.Some"))
    (inv : Entails Ξ (invariant filter acc rest total))
    (field : Entails Ξ (.eq (length ys) (length (.field someField result))))
    (append : Entails Ξ (appendPredicate acc' acc)) :
    Entails Ξ (invariant filter acc' ys total) := by
  have shorter := implication (.and_right ct) path
  let ν : ObservationEnv := fun i =>
    if i=0 then some (length acc) else if i=1 then some (length rest)
    else if i=2 then some (length total) else if i=3 then some (length (.field someField result))
    else if i=4 then some (length ys) else some (length acc')
  cases filter
  · exact Entails.checkedAt ν map_append_checked (.and_intro inv (.and_intro shorter (.and_intro field append)))
  · exact Entails.checkedAt ν filter_append_checked (.and_intro inv (.and_intro shorter (.and_intro field append)))

private theorem skip_entails {Ξ : List Pred} (result rest acc total ys : Term)
    (ct : Entails Ξ (tailPredicate result rest))
    (path : Entails Ξ (.constructorIs result "Option.Some"))
    (inv : Entails Ξ (invariant true acc rest total))
    (field : Entails Ξ (.eq (length ys) (length (.field someField result)))) :
    Entails Ξ (invariant true acc ys total) := by
  have shorter := implication (.and_right ct) path
  let ν : ObservationEnv := fun i =>
    if i=0 then some (length acc) else if i=1 then some (length rest)
    else if i=2 then some (length total) else if i=3 then some (length (.field someField result))
    else some (length ys)
  exact Entails.checkedAt ν filter_skip_checked (.and_intro inv (.and_intro shorter field))

private theorem initial_entails {Ξ : List Pred} (filter : Bool) (xs : Term) :
    Entails Ξ (invariant filter (.listValue []) xs xs) := by
  have base : Entails Ξ (relation filter (.add (.integer 0) (length xs)) (length xs)) := by
    cases filter
    · exact Entails.checkedAt (fun _ => some (length xs)) map_initial_checked .truth
    · exact Entails.checkedAt (fun _ => some (length xs)) filter_initial_checked .truth
  have zero : Entails Ξ (.eq (length (.listValue [])) (.integer 0)) := by
    apply Entails.closed (p := .eq (length (.listValue [])) (.integer 0)) (by decide) ⟨⟨trivial,rfl,rfl⟩,trivial,rfl⟩
    rfl
  have checked : CertificateKernel.check
      (.and (.eq (.var 0) (.integer 0)) (relation filter (.add (.integer 0) (.var 1)) (.var 1)))
      (relation filter (.add (.var 0) (.var 1)) (.var 1))
      (.substitute (relation filter (.add (.var 0) (.var 2)) (.var 2)) (.integer 0) (.var 0)
        (.symm (.hyp 0)) (.use 1) .integer) = true := by cases filter <;> decide
  cases filter <;> exact Entails.checkedAt (fun i => if i=0 then some (length (.listValue [])) else some (length xs))
    checked (.and_intro zero base)


private def optionAlts (someCase : Bool) : List Alt :=
  if someCase then [⟨.con "Option.Some" [.var],[0]⟩] else [⟨.con "Option.None" [],[]⟩]
private theorem option_alts {P B} (inp : Inputs P B) (tailCase : Bool) (p : Pred) (someCase : Bool) :
    AltsTy P (optionAlts someCase) (.refined (.data "Option" [if tailCase then .list (.tvar 0) else .tvar 0]) p)
      (if someCase then [if tailCase then .list (.tvar 0) else .tvar 0] else []) := by
  let a : Ty := if tailCase then .list (.tvar 0) else .tvar 0
  cases someCase <;> refine ⟨by decide,rfl,?_,?_⟩
  all_goals first | (solve | intro alt h; cases Option.some.inj h; rfl) | skip
  · intro alt h; cases List.mem_singleton.mp h
    exact ⟨[],.P_Refined (.P_Con inp.declarations.none_decl rfl (by simp) .nil),by simp,rfl⟩
  · intro alt h; cases List.mem_singleton.mp h
    refine ⟨[a],.P_Refined (.P_Con inp.declarations.some_decl rfl ?_ (by cases tailCase <;> exact .cons .P_Var .nil)),by simp,rfl⟩
    intro t ht; cases List.mem_singleton.mp ht; simp [Ty.WF]

private theorem option_exhaustive {P B} (inp : Inputs P B) (a : Ty) (p : Pred) :
    Exhaustive P (.refined (.data "Option" [a]) p) [.con "Option.None" [],.con "Option.Some" [.var]] := by
  intro v inhabitant
  have hc : Inhabits P (.data "Option" [a.norm]) v := by
    simpa [Ty.refined_norm_core,Ty.norm,Ty.normTys,Ty.core] using inhabitant.core
  rcases hc.data_inv _ _ rfl with ⟨c,ts,args,cd,rfl,lookup,owner,ntys,wf,fields⟩ | impossible
  · rcases inp.declarations.only c cd lookup owner with rfl | rfl
    · cases Option.some.inj (lookup.symm.trans inp.declarations.none_decl)
      cases fields
      exact ⟨.con "Option.None" [],by simp,by rfl⟩
    · cases Option.some.inj (lookup.symm.trans inp.declarations.some_decl)
      cases fields with | cons x rest =>
        cases rest
        exact ⟨.con "Option.Some" [.var],by simp,by rfl⟩
  · simp [atErrorType] at impossible


private theorem option_paths {P B C Γ a p} (inp : Inputs P B)
    (lookup : Γ[0]? = some (some (.refined (.data "Option" [a]) p))) (which : Bool) :
    FactsWF P C Γ (pathFacts (some (.var 0)) (matchedTests (optionAlts which) ++ excludedTests (optionAlts which))) := by
  have len : 0 < Γ.length := (List.getElem?_eq_some_iff.mp lookup).1
  have read : Γ.Readable 0 := ⟨_,lookup,by intro b t e h; cases h⟩
  have core : (.refined (.data "Option" [a]) p : Ty).norm.core = .data "Option" [a.norm] := by
    simp [Ty.refined_norm_core,Ty.norm,Ty.normTys,Ty.core]
  have hw (ctor : ConName) (cd : ConDecl) (hc : P.cons ctor = some cd) (hd : cd.data = "Option") :
      Pred.WellFormed P C Γ (.constructorIs (.var 0) ctor) :=
    ⟨len,⟨read,_,lookup,rfl⟩,read,"Option",[a.norm],cd,.var lookup core,hc,hd⟩
  have facts : pathFacts (some (.var 0)) (matchedTests (optionAlts which) ++ excludedTests (optionAlts which)) =
      [.constructorIs (.var 0) (if which then "Option.Some" else "Option.None"),
       .not (.constructorIs (.var 0) (if which then "Option.Some" else "Option.None"))] := by cases which <;> rfl
  intro q hq
  rw [facts] at hq
  have base : Pred.WellFormed P C Γ (.constructorIs (.var 0) (if which then "Option.Some" else "Option.None")) := by
    cases which
    · exact hw _ _ inp.declarations.none_decl rfl
    · exact hw _ _ inp.declarations.some_decl rfl
  rcases List.mem_cons.mp hq with rfl | hq
  · exact base
  · cases List.mem_singleton.mp hq
    exact ⟨base.wf,base.sorted,base.declared⟩

private def tailLinks : List FieldLink := [⟨0,0,[someField],some .listLength⟩]
private theorem tail_links : LinksValid (optionAlts true) 1 tailLinks := by
  intro l hl
  cases List.mem_singleton.mp hl
  exact ⟨_,rfl,⟨_,_,rfl⟩,by decide,rfl,BinderPath.con (j := 0) (i := 0) rfl rfl rfl .var,by decide⟩

local macro "walk_var" : tactic => `(tactic|
 (apply HasTypeVQ.V_Var (by rfl); intro b t e h; cases h))

local macro "walk_fields" inp:ident : tactic => `(tactic|
 (intro p hp
  cases List.mem_singleton.mp hp
  constructor <;> simp only [tailLinks,fieldFacts,FieldLink.predicate,routeTerm,viewTerm]
  all_goals walk_simp
  all_goals first | (solve | omega) | declarations_solve $inp))

private theorem pure_effect {P B Ψ Q C Γ Φ R m a L}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R m a Eff.empty L) :
    HasTypeCQ P B Ψ Q C Γ Φ R m a (Eff.row 0) L := by
  refine HasTypeCQ.C_Eff (ε' := Eff.row 0) typed ⟨?_,?_⟩
  · intro a h; simp [Eff.mem,Eff.empty,Eff.test,Eff.atoms] at h
  · intro t h; simp [Eff.memFail,Eff.empty,Eff.fails] at h


theorem variable_refinement {Γ : Ctx} {Φ : List Pred} {i : Nat} {a : Ty} {p : Pred}
    (hi : Γ[i]? = some (some (.refined a p))) (ordinary : Ordinary a) :
    Entails (Γ.facts ++ Φ) (p.open (.var i)) := by
  apply Entails.of_conjuncts
  intro q hq
  rw [Pred.open,Pred.conjuncts_bind] at hq
  obtain ⟨r,hr,rfl⟩ := List.mem_map.mp hq
  apply Entails.hyp
  apply List.mem_append_left
  apply Ctx.mem_facts.mpr
  refine ⟨i,.refined a p,r,hi,?_,rfl⟩
  rw [Ty.assume_refined ordinary]
  exact List.mem_append_right _ hr

open Lean Elab Tactic in
elab "walk_assumption" i:num a:term : tactic => do
  let target ← instantiateMVars (← (← getMainGoal).getType)
  let condition := target.getAppArgs[0]!
  let args := condition.getAppArgs
  let ctx := args[args.size - 2]!.getAppArgs[0]!
  let facts := args[args.size - 1]!
  let ctxSyntax ← PrettyPrinter.delab ctx
  let factsSyntax ← PrettyPrinter.delab facts
  evalTactic (← `(tactic|
    have h := variable_refinement (Γ := $ctxSyntax) (Φ := $factsSyntax) (i := $i) (a := $a)
      (by rfl) (by intro b t e h; cases h);
    walk_simp; all_goals exact h))

private theorem variable_carrier {P B Ψ Q C Γ Φ i a p}
    (hi : Γ[i]? = some (some (.refined a p))) (ordinary : Ordinary a)
    (ann : Ty.Annotation P C Γ a) : HasTypeVQ P B Ψ Q C Γ Φ (.var i) a :=
  .V_Sub (.V_Var hi ordinary) .forget ann.wf ann.sorted ann.declared

local macro "walk_listvar" : tactic => `(tactic|
 first
 | walk_var
 | (apply variable_carrier rfl (by intro b t e h; cases h); constructor <;> walk_simp))

local macro "walk_result" : tactic => `(tactic|
 (walk_simp
  first
  | apply HasTypeVQ.V_Refine (a := .list (.tvar 0)) (sort := .list) (by walk_listvar) rfl rfl
  | apply HasTypeVQ.V_Refine (a := .list (.tvar 1)) (sort := .list) (by walk_listvar) rfl rfl
  all_goals first | (solve | walk_simp) | skip))

private theorem from_annotation {P Γ} (filter : Bool) :
    Ty.Annotation P (params filter) Γ (.dependentFn (fromTel filter)) := by
  cases filter <;> constructor <;> walk_simp

local macro "walk_annotation" inp:ident : tactic => `(tactic|
 (constructor <;> walk_simp
  all_goals first | omega | rfl | declarations_solve $inp | (refine ⟨?_,?_,?_⟩ <;> declarations_solve $inp)))

local macro "walk_recur" recFn:ident inp:ident : tactic => `(tactic|
 (apply HasTypeCQ.C_DependentApp ($recFn _ _)
  refine .param (by walk_annotation $inp) (by walk_listvar) ?_
  walk_simp
  refine .param (by walk_annotation $inp) (by walk_var) ?_
  walk_simp
  refine .param (by walk_annotation $inp) (by walk_listvar) ?_
  walk_simp
  refine .param (by walk_annotation $inp) ?_ (by
    walk_simp
    apply HasTypeTelArgsQ.done
    walk_annotation $inp)
  walk_result))

local macro "walk_hyp" : tactic => `(tactic|
 (apply Entails.hyp
  apply List.mem_append_right
  first
  | exact List.mem_of_getElem? (i := 0) rfl
  | exact List.mem_of_getElem? (i := 1) rfl
  | exact List.mem_of_getElem? (i := 2) rfl
  | exact List.mem_of_getElem? (i := 3) rfl))

local macro "walk_append" filter:term:max appendFn:ident recFn:ident inp:ident : tactic => `(tactic|
 (apply HasTypeCQ.C_Let (a := appendType $filter (.var 5))
  · apply pure_effect
    apply HasTypeCQ.C_DependentApp ($appendFn _ _)
    refine .param (by walk_annotation $inp) (by walk_listvar) ?_
    walk_simp
    refine .param (by walk_annotation $inp) (by walk_var) ?_
    walk_simp
    apply HasTypeTelArgsQ.done
    walk_annotation $inp
  · walk_recur $recFn $inp
    first
    | apply append_entails false (.var 2) (.var 7) (.var 6) (.var 9) (.var 1) (.var 0)
    | apply append_entails true (.var 2) (.var 7) (.var 6) (.var 9) (.var 1) (.var 0)
    · walk_assumption 2 (.data "Option" [.list (.tvar 0)])
    · walk_hyp
    · first | walk_assumption 6 (.list (.tvar 0)) | walk_assumption 6 (.list (.tvar 1))
    · walk_hyp
    · first | walk_assumption 0 (.list (.tvar 0)) | walk_assumption 0 (.list (.tvar 1))
  · walk_simp))

set_option maxHeartbeats 800000 in
private theorem from_body {P B} (inp : Inputs P B) (filter : Bool) :
    TelBodyTy P B StoreTy.empty (QTel (fromTel filter)) (params filter) [] [] (fromTel filter) (fromBody filter) := by
  have dar := inp.declarations.arity
  have headFn := fun Γ Φ => primitive_reference (Ψ := StoreTy.empty) (Q := QTel (fromTel filter))
    (Γ := Γ) (Φ := Φ) inp filter 0 (by cases filter <;> decide) .head
  have tailFn := fun Γ Φ => primitive_reference (Ψ := StoreTy.empty) (Q := QTel (fromTel filter))
    (Γ := Γ) (Φ := Φ) inp filter 0 (by cases filter <;> decide) .tail
  have appendFn := fun Γ Φ => primitive_reference (Ψ := StoreTy.empty) (Q := QTel (fromTel filter))
    (Γ := Γ) (Φ := Φ) inp filter (if filter then 0 else 1) (by cases filter <;> decide) .append
  have recFn := fun Γ Φ => from_reference (Ψ := StoreTy.empty) (Q := QTel (fromTel filter))
    (Γ := Γ) (Φ := Φ) inp filter
  cases filter
  all_goals
    apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param
    apply TelBodyTy.done
    dsimp only [fromBody,headArms]
    apply HasTypeCQ.C_Let (a := headType (.var 1))
    · apply pure_effect
      apply HasTypeCQ.C_DependentApp (headFn _ _)
      refine .param ⟨by walk_simp,by walk_simp,by walk_simp⟩ (by walk_listvar) ?_
      walk_simp
      apply HasTypeTelArgsQ.done
      constructor <;> walk_simp
      all_goals first | declarations_solve inp | (refine ⟨?_,?_,?_⟩ <;> declarations_solve inp)
    · apply HasTypeCQ.C_Match (obs := some (.var 0))
      · walk_var
      · intro t ht; cases Option.some.inj ht
        refine ⟨rfl,.data,?_⟩
        simp only [headType]
        walk_simp
      · apply HasTypeArmsQ.plainEmpty (option_alts inp false _ false)
        · simp only [headType]
          exact option_paths inp rfl false
        · apply pure_effect
          apply HasTypeCQ.C_Return
          walk_result
          first
          | apply none_entails false (.var 0) (.var 2) (.var 1) (.var 4)
          | apply none_entails true (.var 0) (.var 2) (.var 1) (.var 4)
          · walk_assumption 0 (.data "Option" [.tvar 0])
          · exact .hyp (List.mem_append_right _ List.mem_cons_self)
          · first
            | walk_assumption 1 (.list (.tvar 0))
            | walk_assumption 1 (.list (.tvar 1))
        · apply HasTypeArmsQ.plainEmpty (option_alts inp false _ true)
          · simp only [headType]
            exact option_paths inp rfl true
          · apply HasTypeCQ.C_Let
            · apply HasTypeCQ.C_App
              · walk_var
              · exact .cons (by walk_var) .nil
            · dsimp only [afterCallback]
              apply HasTypeCQ.C_Let (a := tailType (.var 4))
              · apply pure_effect
                apply HasTypeCQ.C_DependentApp (tailFn _ _)
                refine .param ⟨by walk_simp,by walk_simp,by walk_simp⟩ (by walk_listvar) ?_
                walk_simp
                apply HasTypeTelArgsQ.done
                constructor <;> walk_simp
                all_goals first | declarations_solve inp | (refine ⟨?_,?_,?_⟩ <;> declarations_solve inp)
              · dsimp only [tailArms]
                apply HasTypeCQ.C_Match (obs := some (.var 0))
                · walk_var
                · intro t ht; cases Option.some.inj ht
                  refine ⟨rfl,.data,?_⟩
                  simp only [tailType]
                  walk_simp
                · apply HasTypeArmsQ.plainEmpty (option_alts inp true _ false)
                  · simp only [tailType]
                    exact option_paths inp rfl false
                  · apply pure_effect
                    apply HasTypeCQ.C_Return
                    walk_result
                    first
                    | apply none_entails false (.var 0) (.var 5) (.var 4) (.var 7)
                    | apply none_entails true (.var 0) (.var 5) (.var 4) (.var 7)
                    · apply Entails.and_left; walk_assumption 0 (.data "Option" [.list (.tvar 0)])
                    · exact .hyp (List.mem_append_right _ List.mem_cons_self)
                    · first
                      | walk_assumption 4 (.list (.tvar 0))
                      | walk_assumption 4 (.list (.tvar 1))
                  · apply HasTypeArmsQ.plain (links := tailLinks) (option_alts inp true _ true) tail_links
                    · simp only [tailType]
                      walk_fields inp
                    · simp only [tailType]
                      exact option_paths inp rfl true
                    · dsimp only [afterTail,appended,recurse]
                      first
                      | walk_append false appendFn recFn inp
                      | (apply HasTypeCQ.C_If
                         · walk_var
                         · rfl
                         · walk_append true appendFn recFn inp
                         · walk_recur recFn inp
                           apply skip_entails (.var 1) (.var 6) (.var 5) (.var 8) (.var 0)
                           · walk_assumption 1 (.data "Option" [.list (.tvar 0)])
                           · walk_hyp
                           · walk_assumption 5 (.list (.tvar 0))
                           · walk_hyp)
                    · apply HasTypeArmsQ.nil
                      constructor <;> walk_simp
                · walk_simp
                  all_goals first | declarations_solve inp | (refine ⟨?_,?_,?_⟩ <;> declarations_solve inp)
                · simpa only [unguardedPats,List.map_cons,List.map_nil,List.append_nil,List.cons_append,List.nil_append,headType,tailType,Ty.shiftV,shiftVTys] using option_exhaustive inp (.list (.tvar 0)) _
              · walk_simp
            · walk_simp
          · apply HasTypeArmsQ.nil
            constructor <;> walk_simp
      · walk_simp
        all_goals first | declarations_solve inp | (refine ⟨?_,?_,?_⟩ <;> declarations_solve inp)
      · simpa only [unguardedPats,List.map_cons,List.map_nil,List.append_nil,List.cons_append,List.nil_append,headType,tailType,Ty.shiftV,shiftVTys] using option_exhaustive inp (.tvar 0) _
    · walk_simp


/-- 同じ四引数の依存列を、通常のDef.WellTypedで検査する。 -/
theorem from_typed {P B} (inp : Inputs P B) (filter : Bool) :
    (fromRow filter).BodyTyped P B := by
  refine ⟨fromDefinition filter,rfl,?_,?_,?_,?_⟩
  · cases filter <;> walk_simp
  · cases filter <;> walk_simp
  · exact (from_annotation (P := P) (Γ := []) filter).range_empty
  · simpa only [Def.tel,fromDefinition,StandardContracts.signatureTel_rebuild,telBodyTyR_nil] using from_body inp filter

/-- 公開の二引数を保ち、元の列と空の累積でhelperの不変条件を開始する。 -/
theorem public_typed {P B} (inp : Inputs P B) (filter : Bool) :
    (publicRow filter).BodyTyped P B := by
  have recFn := fun Γ Φ => from_reference (Ψ := StoreTy.empty) (Q := QTel (publicTel filter))
    (Γ := Γ) (Φ := Φ) inp filter
  cases filter
  all_goals
    refine ⟨publicDefinition _,rfl,?_,?_,?_,?_⟩
    · walk_simp
    · walk_simp
    · walk_annotation inp
    · rw [show (publicDefinition _).tel = publicTel _ from StandardContracts.signatureTel_rebuild _]
      apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
      dsimp only [publicDefinition,publicBody]
      apply HasTypeCQ.C_DependentApp (recFn _ _)
      refine .param (by walk_annotation inp) (by walk_var) ?_
      walk_simp
      refine .param (by walk_annotation inp) (by walk_var) ?_
      walk_simp
      refine .param (by walk_annotation inp) (by walk_var) ?_
      walk_simp
      refine .param (by walk_annotation inp) ?_ (by
        walk_simp
        apply HasTypeTelArgsQ.done
        walk_annotation inp)
      first
      | apply HasTypeVQ.V_Refine (a := .list (.tvar 1)) (sort := .list)
          (by exact .V_List .nil (by walk_simp) (by walk_simp) (by walk_simp)) rfl rfl
      | apply HasTypeVQ.V_Refine (a := .list (.tvar 0)) (sort := .list)
          (by exact .V_List .nil (by walk_simp) (by walk_simp) (by walk_simp)) rfl rfl
      all_goals first | (solve | walk_simp) | skip
      first | exact initial_entails false (.var 1) | exact initial_entails true (.var 1)



theorem append_ordinary {P B Ψ Q Γ Φ} (inp : Inputs P B) (filter : Bool)
    (i : Nat) (inside : i < (if filter then 1 else 2)) :
    HasTypeVQ P B Ψ Q (params filter) Γ Φ (.prim "List.append" [.tvar i] [] [])
      (.fn ["xs","x"] [.list (.tvar i),.tvar i] (.list (.tvar i)) Eff.empty) := by
  have typed := primitive_reference (Ψ := Ψ) (Q := Q) (Γ := Γ) (Φ := Φ) inp filter i inside .append
  let tel : Tel := .param "xs" (.list (.tvar i)) (.param "x" (.tvar i) (.done (.list (.tvar i)) Eff.empty))
  have ann : Ty.Annotation P (params filter) Γ (.dependentFn tel) := by
    constructor <;> simp only [tel] <;> walk_simp
  have ordinary : HasTypeVQ P B Ψ Q (params filter) Γ Φ (.prim "List.append" [.tvar i] [] []) (.dependentFn tel) :=
    .V_Sub typed (.dependentFn (.tail .refl (.param .refl (.param .refl (.done .forget (Eff.Covers.refl _ _ _))))))
      ann.wf ann.sorted ann.declared
  apply ordinary.convert
  · exact Ty.norm_toTel (ns := ["xs","x"]) (ps := [.list (.tvar i),.tvar i]) (r := .list (.tvar i)) (e := Eff.empty) (by simp [NamesWF])
  · constructor <;> walk_simp

private theorem public_instance {P Γ} (filter : Bool) :
    SignatureInstance P (params filter) Γ (publicDefinition filter).tel
      (TypeCtx.kinds (publicDefinition filter).tparams) (arguments filter) [Eff.row 0] := by
  have selfrow := row_self
  simp only [Eff.row,Eff.atoms] at selfrow
  cases filter <;> constructor
  all_goals
    solve
    | walk_simp
    | (constructor <;> walk_simp)
    | (walk_simp; constructor <;> constructor <;> walk_simp)
    | (intro e he; cases List.mem_singleton.mp he; constructor <;> walk_simp)
    | (intro e he; cases List.mem_singleton.mp he; walk_simp)
    | (constructor; walk_simp; rintro (_|(_|j)) a k ha hk <;> walk_simp <;> (subst_vars; walk_simp))

private theorem public_reference {P B Ψ Q Γ Φ} (inp : Inputs P B) (filter : Bool)
    (lookup : P.defs (if filter then "%List.filter.refined" else "%List.map.refined") = some (publicDefinition filter)) :
    HasTypeVQ P B Ψ Q (params filter) Γ Φ (.fnRef ((if filter then "%List.filter.refined" else "%List.map.refined")) (arguments filter) [Eff.row 0])
      (.dependentFn (publicTel filter)) := by
  have selfrow := row_self
  simp only [Eff.row,Eff.atoms] at selfrow
  have names : NamesWF (publicDefinition filter).names (publicDefinition filter).params := by cases filter <;> walk_simp
  have ad : Admissible B (params filter) Γ.length
      (TypeCtx.constraints (publicDefinition filter).tparams) 1
      (Qsig (publicDefinition filter).params (publicDefinition filter).ret (publicDefinition filter).eff) Q
      (arguments filter) [Eff.row 0] (publicDefinition filter).eff := by
    cases filter <;> constructor
    all_goals first | (constructor <;> walk_simp) | walk_simp
    all_goals rintro (_|(_|j)) a p ha hp <;> walk_simp <;> subst_vars
    all_goals exact inp.sat _ _
  have typed := HasTypeVQ.fun_empty (Ψ := Ψ) (Φ := Φ) lookup names (by rfl) ad (public_instance filter)
  have same : instantiatedTel (publicDefinition filter).tel (arguments filter) [Eff.row 0] = publicTel filter := by
    cases filter <;> walk_simp
  rw [same] at typed
  exact typed


private def nonemptyTel : Tel := InternalContracts.nonemptyMap (.tvar 0) (.tvar 1) (Eff.row 0)
private def nonemptyBody : Comp := .letIn
  (.app (.fnRef "%List.map.refined" [.tvar 0,.tvar 1] [Eff.row 0]) [.var 1,.var 0]) (.ret (.var 0))
private def nonemptyRow : StandardContracts.Row :=
  ⟨"Internal.NonEmptyList.map",params false,1,nonemptyTel,some nonemptyBody,.core,[.nonempty,.listMap]⟩
private def nonemptyDefinition : Def :=
  ⟨params false,1,nonemptyTel.names,nonemptyTel.inputs,nonemptyTel.result,nonemptyTel.effect,nonemptyBody, []⟩

private theorem positive_eq {Ξ : List Pred} (xs ys : Term)
    (eq : Entails Ξ (.eq (length ys) (length xs)))
    (pos : Entails Ξ (.lt (.integer 0) (length xs))) :
    Entails Ξ (.lt (.integer 0) (length ys)) := by
  have checked : CertificateKernel.check
      (.and (.eq (.var 0) (.var 1)) (.lt (.integer 0) (.var 1)))
      (.lt (.integer 0) (.var 0))
      (.substitute (.lt (.integer 0) (.var 0)) (.var 1) (.var 0)
        (.symm (.hyp 0)) (.use 1) .integer) = true := by decide
  exact Entails.checkedAt (fun i => if i=0 then some (length ys) else some (length xs)) checked (.and_intro eq pos)

/-- 内部の非空map契約を、合成表の精密なList.mapの長さの等式から検査する。 -/
private theorem nonempty_typed {P B} (inp : Inputs P B)
    (lookup : P.defs "%List.map.refined" = some (publicDefinition false)) :
    nonemptyRow.BodyTyped P B := by
  have mapFn := fun Γ Φ => public_reference (Ψ := StoreTy.empty) (Q := QTel nonemptyTel)
    (Γ := Γ) (Φ := Φ) inp false lookup
  refine ⟨nonemptyDefinition,rfl,?_,?_,?_,?_⟩
  · simp only [nonemptyDefinition,nonemptyTel]; walk_simp
  · simp only [nonemptyDefinition,nonemptyTel]; walk_simp
  · simp only [nonemptyDefinition,nonemptyTel]; walk_annotation inp
  · rw [show nonemptyDefinition.tel = nonemptyTel from StandardContracts.signatureTel_rebuild _]
    apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [nonemptyDefinition,nonemptyBody]
    apply HasTypeCQ.C_Let (a := .refined (.list (.tvar 1)) (.eq (length (.var 0)) (length (.var 2))))
    · apply HasTypeCQ.C_DependentApp (mapFn _ _)
      refine .param (by walk_annotation inp) (by walk_listvar) ?_
      walk_simp
      refine .param (by walk_annotation inp) (by walk_var) ?_
      walk_simp
      apply HasTypeTelArgsQ.done
      walk_annotation inp
    · apply pure_effect
      apply HasTypeCQ.C_Return
      walk_result
      apply Entails.and_intro
      · apply positive_eq (.var 2) (.var 0)
        · walk_assumption 0 (.list (.tvar 1))
        · walk_assumption 2 (.list (.tvar 0))
      · walk_assumption 0 (.list (.tvar 1))
    · try simp only [nonemptyTel]
      walk_simp


/-- 公開の引数名valueを保ち、内部契約のxsと区別する。 -/
private def nonemptyPublicTel : Tel := .param "value" (InternalContracts.nonempty (.tvar 0))
  (.param "f" (callback false) (.done (.refined (.list (.tvar 1))
    (.and (.lt (.integer 0) (length (.var 0))) (.eq (length (.var 0)) (length (.var 2))))) (Eff.row 0)))
private def nonemptyPublicRow : StandardContracts.Row :=
  ⟨"NonEmptyList.map",params false,1,nonemptyPublicTel,some nonemptyBody,.core,[.nonempty,.listMap]⟩
private def nonemptyPublicDefinition : Def :=
  ⟨params false,1,nonemptyPublicTel.names,nonemptyPublicTel.inputs,nonemptyPublicTel.result,nonemptyPublicTel.effect,nonemptyBody, []⟩

/-- 公開名valueの非空mapの本体は、合成表の精密なList.mapを参照して型付く。 -/
theorem nonempty_public_typed {P B} (inp : Inputs P B)
    (lookup : P.defs "%List.map.refined"=some (publicDefinition false)) : nonemptyPublicRow.BodyTyped P B := by
  obtain ⟨d,hd,typed⟩ := nonempty_typed inp lookup
  have eq : d=nonemptyDefinition := Option.some.inj (hd.symm.trans rfl)
  subst d
  have body := typed.2.2.2
  rw [show nonemptyDefinition.tel=nonemptyTel from StandardContracts.signatureTel_rebuild _] at body
  refine ⟨nonemptyPublicDefinition,rfl,?_,?_,?_,?_⟩
  · simp only [nonemptyPublicDefinition,nonemptyPublicTel]; walk_simp
  · simp only [nonemptyPublicDefinition,nonemptyPublicTel]; walk_simp
  · simp only [nonemptyPublicDefinition,nonemptyPublicTel]; walk_annotation inp
  · rw [show nonemptyPublicDefinition.tel=nonemptyPublicTel from StandardContracts.signatureTel_rebuild _]
    cases body with
    | param tail => exact .param tail


end
end Benitoite.Release.Refinement.StandardModelPreciseList

/-! ## 合成表の上の八つの本体 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section

private theorem ordinary_from (filter : Bool) :
    (if filter then Body.b130 else Body.b129).definition = StandardModelOrdinaryList.listFromDefinition filter := by
  cases filter <;> rfl
private theorem ordinary_public (filter : Bool) :
    (if filter then Body.b002 else Body.b001).definition =
      ((StandardModelOrdinaryList.listHigherRow filter).definition).getD
        (StandardModelOrdinaryList.listFromDefinition filter) := by
  cases filter <;> rfl
private theorem precise_from (filter : Bool) :
    (if filter then Body.b102 else Body.b101).definition = StandardModelPreciseList.fromDefinition filter := by
  cases filter <;> rfl
private theorem precise_public (filter : Bool) :
    (if filter then Body.b104 else Body.b103).definition = StandardModelPreciseList.publicDefinition filter := by
  cases filter <;> rfl

section
variable {externals : List (ExternalKey × ExternalDecl)} {P : Program} {B : Builtins}

/-- 行の環境の表の List.get は、通常の helper が読む署名である。 -/
theorem get_signature_of [RowEnv P B] : B.sig "List.get" = some StandardBodies.listGetSig := by
  have h : B.sig Primitive.p259.name = some (Primitive.p259.signatureWith B.sat) := RowLookup.sig _
  rw [RowEnv.sat_eq (P := P)] at h
  refine h.trans ?_
  change some (StandardListRemainingResponse.API.signature _ .get) = some StandardBodies.listGetSig
  simp [StandardListRemainingResponse.API.signature,StandardListRemainingResponse.API.constraint,
    StandardListRemainingResponse.API.names,StandardListRemainingResponse.API.inputs,
    StandardListRemainingResponse.API.result,StandardBodies.listGetSig]
  rfl

private theorem precise_inputs [env : BodyEnv externals P B] : StandardModelPreciseList.Inputs P B :=
  ⟨env.options, RowLookup.sig_eq rfl rfl, RowLookup.sig_eq rfl rfl, RowLookup.sig_eq rfl rfl,
    fun filter => env.extends_.defs _ _ (by cases filter <;> rfl), RowEnv.sat_empty (P := P)⟩

/-- 通常側・精密側のListのmapとfilterと補助の八本は、本体の型付けの環境で型付く。 -/
theorem list_bodies_typed_of [env : BodyEnv externals P B] (filter : Bool) :
    (if filter then Body.b130 else Body.b129).definition.WellTyped P B ∧
    (if filter then Body.b002 else Body.b001).definition.WellTyped P B ∧
    (if filter then Body.b102 else Body.b101).definition.WellTyped P B ∧
    (if filter then Body.b104 else Body.b103).definition.WellTyped P B := by
  have inputs := precise_inputs (externals := externals) (P := P) (B := B)
  have get := get_signature_of (P := P) (B := B)
  refine ⟨?_, ?_, ?_, ?_⟩
  · rw [ordinary_from]
    apply StandardModelOrdinaryList.from_typed filter env.options get
    · intro Ψ Q Γ Φ i hi
      exact StandardModelPreciseList.append_ordinary inputs filter i hi
    · exact RowLookup.sig_eq rfl rfl
    · exact env.extends_.defs _ _ (by cases filter <;> rfl)
    · intro i hi; exact RowEnv.sat_empty (P := P) _ _
  · rw [ordinary_public]
    obtain ⟨d, hd, ht⟩ := StandardModelOrdinaryList.higher_typed (P := P) (B := B) filter
      (env.extends_.defs _ _ (by cases filter <;> rfl)) (by intro i hi; exact RowEnv.sat_empty (P := P) _ _)
    cases filter <;> cases Option.some.inj (hd.symm.trans rfl) <;> exact ht
  · rw [precise_from]
    obtain ⟨d, hd, ht⟩ := StandardModelPreciseList.from_typed inputs filter
    cases Option.some.inj (hd.symm.trans rfl)
    exact ht
  · rw [precise_public]
    obtain ⟨d, hd, ht⟩ := StandardModelPreciseList.public_typed inputs filter
    cases Option.some.inj (hd.symm.trans rfl)
    exact ht

/-- 非空の列の精密なmapは、表の精密なList.mapを参照して型付く。 -/
theorem nonempty_map_typed_of [env : BodyEnv externals P B] : Body.b105.definition.WellTyped P B := by
  obtain ⟨d, hd, ht⟩ := StandardModelPreciseList.nonempty_public_typed (precise_inputs (externals := externals))
    (env.extends_.defs _ _ rfl)
  cases Option.some.inj (hd.symm.trans rfl)
  exact ht

end

/-- 通常側・精密側のListのmapとfilterと補助の八本は、任意の外部宣言の合成表で型付く。 -/
theorem list_bodies_typed (externals : List (ExternalKey × ExternalDecl)) (filter : Bool) :
    (if filter then Body.b130 else Body.b129).definition.WellTyped (program externals) (builtins (program externals)) ∧
    (if filter then Body.b002 else Body.b001).definition.WellTyped (program externals) (builtins (program externals)) ∧
    (if filter then Body.b102 else Body.b101).definition.WellTyped (program externals) (builtins (program externals)) ∧
    (if filter then Body.b104 else Body.b103).definition.WellTyped (program externals) (builtins (program externals)) :=
  list_bodies_typed_of (externals := externals) filter

/-- 非空の列の精密なmapは、合成表の精密なList.mapを参照して型付く。 -/
theorem nonempty_map_typed (externals : List (ExternalKey × ExternalDecl)) :
    Body.b105.definition.WellTyped (program externals) (builtins (program externals)) :=
  nonempty_map_typed_of (externals := externals)

end
end Benitoite.Release.Refinement.StandardModel
