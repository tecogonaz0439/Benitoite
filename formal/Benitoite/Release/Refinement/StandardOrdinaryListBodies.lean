import Benitoite.Release.Refinement.StandardOrdinaryCoreBodies

/-! # Listの通常のfoldと走査の実本体 -/
namespace Benitoite.Release.Refinement.StandardOrdinaryListBodies
noncomputable section
set_option maxHeartbeats 4000000
set_option linter.unusedSimpArgs false
open StandardOrdinaryCoreBodies

inductive Op where
 | fold | forEach | any | all | find
 deriving DecidableEq

def Op.name : Op → String
 | .fold => "List.fold" | .forEach => "List.forEach" | .any => "List.any" | .all => "List.all" | .find => "List.find"
def Op.helperName (o : Op) : String := o.name ++ "From"
def Op.count : Op → Nat | .fold => 2 | _ => 1
def Op.context (o : Op) : TypeCtx := List.replicate o.count TypeCtx.valueParam
def Op.args (o : Op) : List Ty := if o=.fold then [.tvar 0,.tvar 1] else [.tvar 0]
def Op.result : Op → Ty
 | .fold => .tvar 1 | .forEach => .base .unit | .any | .all => .base .boolean | .find => .data "Option" [.tvar 0]
def Op.callback : Op → Ty
 | .fold => .fn ["acc","value"] [.tvar 1,.tvar 0] (.tvar 1) (Eff.row 0)
 | .forEach => .fn ["value"] [.tvar 0] (.base .unit) (Eff.row 0)
 | _ => .fn ["value"] [.tvar 0] (.base .boolean) (Eff.row 0)
def Op.label : Op → String | .fold | .forEach => "f" | _ => "p"
def Op.names (o : Op) : List String := if o=.fold then ["xs","acc","f","i"] else ["xs",o.label,"i"]
def Op.inputs (o : Op) : List Ty := if o=.fold then [.list (.tvar 0),.tvar 1,o.callback,.base .integer] else [.list (.tvar 0),o.callback,.base .integer]
def Op.publicNames (o : Op) : List String := if o=.fold then ["xs","initial","f"] else ["xs",o.label]
def Op.publicInputs (o : Op) : List Ty := if o=.fold then [.list (.tvar 0),.tvar 1,o.callback] else [.list (.tvar 0),o.callback]
def Op.tel (o : Op) : Tel := signatureTel o.names o.inputs o.result (Eff.row 0)
def Op.publicTel (o : Op) : Tel := signatureTel o.publicNames o.publicInputs o.result (Eff.row 0)
private def zero : Val := .const (.integer ⟨0,by decide⟩)
private def one : Val := .const (.integer ⟨1,by decide⟩)
private def increment (i : Nat) : Comp := .app (.prim "%Integer.add" [] [] []) [.var i,one]
private def recurse (o : Op) (xs f i : Nat) : Comp := .app (.fnRef o.helperName o.args [Eff.row 0]) [.var xs,.var f,.var i]
def Op.next (o : Op) : Comp := .letIn (increment 3) (recurse o 6 5 0)
def Op.afterCall : Op → Comp
 | .fold => .letIn (increment 3) (.app (.fnRef "List.foldFrom" [.tvar 0,.tvar 1] [Eff.row 0]) [.var 7,.var 1,.var 5,.var 0])
 | .forEach => Op.next .forEach
 | .any => .ite (.var 0) (.ret (.const (.boolean true))) (Op.next .any)
 | .all => .ite (.var 0) (Op.next .all) (.ret (.const (.boolean false)))
 | .find => .ite (.var 0) (.ret (.con "Option.Some" [.tvar 0] [.var 1])) (Op.next .find)
def Op.noneBody : Op → Comp
 | .fold => .ret (.var 3) | .forEach => .ret (.const .unit)
 | .any => .ret (.const (.boolean false)) | .all => .ret (.const (.boolean true))
 | .find => .ret (.con "Option.None" [.tvar 0] [])
def Op.arms (o : Op) : List Arm := [
 .mk [⟨.con "Option.None" [],[]⟩] none o.noneBody,
 .mk [⟨.con "Option.Some" [.var],[0]⟩] none
  (.letIn (.app (.var 3) (if o=.fold then [.var 4,.var 0] else [.var 0])) o.afterCall)]
def Op.body (o : Op) : Comp :=
 .letIn (.app (.prim "List.get" [.tvar 0] [] []) [.var (if o=.fold then 3 else 2),.var 0])
  (.match (.var 0) o.arms)
def Op.publicBody (o : Op) : Comp :=
 .app (.fnRef o.helperName o.args [Eff.row 0]) (if o=.fold then [.var 2,.var 1,.var 0,zero] else [.var 1,.var 0,zero])
def Op.definition (o : Op) : Def := ⟨o.context,1,o.names,o.inputs,o.result,Eff.row 0,o.body, []⟩
def Op.publicDefinition (o : Op) : Def := ⟨o.context,1,o.publicNames,o.publicInputs,o.result,Eff.row 0,o.publicBody, []⟩
def Op.every : List Op := [.fold,.forEach,.any,.all,.find]
def definitions : List (FunName × Def) := Op.every.flatMap fun o => [(o.name,o.publicDefinition),(o.helperName,o.definition)]
def program : Program := { StandardOrdinaryCoreBodies.program with defs := fun n => (definitions ++ StandardOrdinaryCoreBodies.definitions).lookup n }
def getSignature : PrimSig :=
 ⟨[TypeCtx.valueParam],0,["xs","i"],[.list (.tvar 0),.base .integer],.data "Option" [.tvar 0],Eff.empty,(fun _ ts => ts.length=1),.pure,none,[],.untargeted⟩
def builtins : Builtins := { StandardOrdinaryCoreBodies.builtins with
 sig := fun n => if n = "List.get" then some getSignature
   else if n = "%Integer.add" then some StandardActualListBodies.additionSignature
   else StandardOrdinaryCoreBodies.builtins.sig n }

/-- 元の構成子・組込み・helperのlookupと制約判定だけを共有する。 -/
structure Inputs (P : Program) (B : Builtins) : Prop where
 /-- 本体が読むOptionの二構成子とarity。 -/
 options : StandardActualListBodies.ListOptionDeclarations P
 get : B.sig "List.get"=some getSignature
 addition : B.sig "%Integer.add"=some StandardActualListBodies.additionSignature
 helpers : ∀ o : Op, P.defs o.helperName=some o.definition
 sat : ∀ C a, B.sat C a {}

local macro "list_simp" : tactic => `(tactic|
 simp_all [Op.name,Op.helperName,Op.count,Op.context,Op.args,Op.result,Op.callback,Op.label,Op.names,Op.inputs,Op.publicNames,Op.publicInputs,Op.tel,Op.publicTel,Op.definition,Op.publicDefinition,getSignature,StandardActualListBodies.additionSignature,Getter.record,Getter.position,Getter.result,Getter.field,Getter.name,Getter.pattern,Getter.alts,
  Getter.body,Getter.definition,Getter.publicBody,Getter.publicDefinition,
  Record.params,Record.arity,Record.type,Record.fields,Record.owner,StandardSafe.names,
  Def.tel,PrimSig.tel,signatureTel,Tel.names,Tel.inputs,Tel.result,Tel.effect,
  TypeCtx.valueParam,TypeCtx.kinds,TypeCtx.constraints,TParamDecl.constraints,
  TypeAnnotations,RowAnnotations,Ty.Annotation,Ty.WF,Tel.WF,Ty.WFList,Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,
  Ty.Declared,Tel.Declared,declaredTys,declaredEff,Ty.HasKind,kindsTel,kindsList,kindsEff,
  NamesWF,Eff.WF,Eff.Canonical,Eff.empty,Eff.row,Eff.norm,Ordinary,Ty.core,
  Builtins.RangeAdmissible,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
  Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,Tel.bind,Tel.rawBind,Ty.bind,Ty.rawBind,rawBindTys,
  Ty.norm,Tel.norm,Ty.normTys,typeEnvAt,SubstEnv.up,SubstEnv.rangesOnly,Eff.rawBind,rowFails,
  substAtoms_nil,instAtoms_nil,Qsig,QTel,QTy,QTys,QEff,Qempty,Eff.RowsIn,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,
  RowTransport,NoFail,SatAll,Eff.test,Eff.atoms,Eff.fails,Eff.shiftV,Ty.shiftV,shiftVTys,Tel.shiftV,Ctx.extend,
  bindParams,localExtend,Pred.lift,liftMany])

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

private theorem option_alternatives {P} (decls : StandardActualListBodies.ListOptionDeclarations P) :
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

private theorem option_exhaustive {P} (decls : StandardActualListBodies.ListOptionDeclarations P) (a : Ty) :
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

private theorem subst_row_self : substAtoms [Eff.row 0] (Eff.row 0).atoms = (Eff.row 0).atoms := by
 funext a
 cases a with
 | name l r => simp [substAtoms,Eff.row,Eff.atoms,Eff.test]
 | rho i => cases i <;> simp [substAtoms,Eff.row,Eff.atoms,Eff.test]
private theorem empty_range : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
 funext a; cases a <;> simp [mapRangeAtoms]

theorem option_declarations {P : Program} (same : P.cons = fun n => constructorTable.lookup n) : StandardActualListBodies.ListOptionDeclarations P := by
 have only : ∀ c cd, P.cons c=some cd → cd.data="Option" → c="Option.None" ∨ c="Option.Some" := by
  intro c cd lookup owner
  rw [same] at lookup
  obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp lookup
  have mem : (c,cd) ∈ constructorTable := by rw [eq]; exact List.mem_append_right _ (List.mem_cons_self ..)
  simp [constructorTable,declarations,StandardKeyTyping.DataDecl.entries,List.mem_cons,List.not_mem_nil,Prod.mk.injEq] at mem
  rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals simp_all [Record.owner,StandardSafe.names]
 refine ⟨by rw [same]; rfl,by rw [same]; rfl,⟨⟨"Option.None",_,by rw [same]; rfl,rfl⟩,?_⟩,only⟩
 intro c cd lookup owner
 rcases only c cd lookup owner with rfl | rfl
 all_goals rw [same] at lookup; cases Option.some.inj lookup; rfl

private theorem get_function {P B Γ Φ Q} (inputs : Inputs P B) (o : Op) :
 HasTypeVQ P B StoreTy.empty Q o.context Γ Φ
  (.prim "List.get" [.tvar 0] [] [])
  (.fn ["xs","i"] [.list (.tvar 0),.base .integer] (.data "Option" [.tvar 0]) Eff.empty) := by
 have ar : ∃ n, P.DataArity "Option" n ∧ 1=n := ⟨1,inputs.options.arity,rfl⟩
 have kind : Ty.HasKind P (TypeCtx.kinds o.context) (.tvar 0) .value := by cases o <;> list_simp
 apply primitive_typed inputs.get
 · cases o <;> list_simp
 · cases o <;> list_simp
 · cases o <;> constructor <;> list_simp
 · constructor
   · cases o <;> list_simp
   · intro a ha; cases List.mem_singleton.mp ha; cases o <;> constructor <;> list_simp
   · exact singleton_kind kind (by intro b t e h; cases h)
   · intro e he; cases he
   · intro e he; cases he
   · cases o <;> constructor <;> list_simp
 · have fold := Ty.foldFn_toTel ⟨["xs","i"],[.list (.tvar 0),.base .integer],.data "Option" [.tvar 0],Eff.empty,by simp [NamesWF]⟩
   cases o <;> list_simp
   all_goals simpa [empty_range,FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty] using fold
 · cases o <;> constructor <;> list_simp

private theorem add_function {P B Γ Φ Q} (inputs : Inputs P B) (o : Op) :
 HasTypeVQ P B StoreTy.empty Q o.context Γ Φ
  (.prim "%Integer.add" [] [] [])
  (.fn ["left","right"] [.base .integer,.base .integer] (.base .integer) Eff.empty) := by
 apply primitive_typed inputs.addition
 · cases o <;> list_simp
 · cases o <;> list_simp
 · cases o <;> constructor <;> list_simp
 · constructor
   · cases o <;> list_simp
   · intro a ha; cases ha
   · exact ⟨rfl,by intro i a k ha; cases ha⟩
   · intro e he; cases he
   · intro e he; cases he
   · cases o <;> constructor <;> list_simp
 · have fold := Ty.foldFn_toTel ⟨["left","right"],[.base .integer,.base .integer],.base .integer,Eff.empty,by simp [NamesWF]⟩
   cases o <;> list_simp
   all_goals simpa [empty_range,FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty] using fold
 · cases o <;> constructor <;> list_simp

private theorem helper_lookup (o : Op) : program.defs o.helperName=some o.definition := by
 cases o <;> simp [program,definitions,Op.every,Op.name,Op.helperName,StandardOrdinaryCoreBodies.definitions,Getter.all,Getter.name,Getter.publicName,List.lookup]

private theorem args_kind {P : Program} (o : Op) : TypeArgsKinded P o.context o.args (TypeCtx.kinds o.definition.tparams) := by
 cases o <;> refine ⟨rfl,?_⟩
 all_goals rintro (_|(_|i)) a k ha hk <;> list_simp <;> subst_vars <;> list_simp

private theorem helper_function {P B Γ Φ Q} (inputs : Inputs P B) (o : Op) :
 HasTypeVQ P B StoreTy.empty Q o.context Γ Φ
  (.fnRef o.helperName o.args [Eff.row 0]) (.fn o.names o.inputs o.result (Eff.row 0)) := by
 have ar : ∃ n, P.DataArity "Option" n ∧ 1=n := ⟨1,inputs.options.arity,rfl⟩
 have selfrow := subst_row_self
 simp only [Eff.row,Eff.atoms] at selfrow
 have sat : ∀ C a, B.sat C a {} := inputs.sat
 have hn : NamesWF o.definition.names o.definition.params := by cases o <;> list_simp
 have ad : Admissible B o.context Γ.length (TypeCtx.constraints o.definition.tparams) 1
  (Qsig o.definition.params o.definition.ret o.definition.eff) Q o.args [Eff.row 0] o.definition.eff := by
  cases o <;> constructor
  all_goals first
   | (solve | constructor <;> list_simp)
   | (solve | list_simp)
   | (solve | list_simp; rintro (_|(_|i)) a p ha hp <;> list_simp)
 have kinds := args_kind (P := P) o
 have inst : SignatureInstance P o.context Γ o.definition.tel (TypeCtx.kinds o.definition.tparams) o.args [Eff.row 0] := by
  cases o <;> constructor
  all_goals first
   | (solve | constructor <;> list_simp)
   | (solve | list_simp)
   | (solve | intro a ha; simp [Op.args] at ha; rcases ha with rfl | rfl <;> constructor <;> list_simp)
   | (solve | intro a ha; cases List.mem_singleton.mp ha; constructor <;> list_simp)
   | (solve | exact kinds)
   | (solve | intro e he; cases List.mem_singleton.mp he; constructor <;> list_simp)
 apply (HasTypeVQ.fun_empty (Ψ := StoreTy.empty) (Φ := Φ) (inputs.helpers o) hn (by rfl) ad inst).convert
 · have fold := Ty.foldFn_toTel ⟨o.names,o.inputs,o.result,Eff.row 0,by cases o <;> list_simp⟩
   cases o <;> list_simp
   all_goals simpa [Op.names,Op.inputs,Op.result,Op.callback,Op.label,FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.row] using fold
 · cases o <;> constructor <;> list_simp

private theorem option_none {P B Γ Φ Q} (inputs : Inputs P B) (o : Op) :
 HasTypeVQ P B StoreTy.empty Q o.context Γ Φ (.con "Option.None" [.tvar 0] []) (.data "Option" [.tvar 0]) := by
 have ar : ∃ n, P.DataArity "Option" n ∧ 1=n := ⟨1,inputs.options.arity,rfl⟩
 have kind : Ty.HasKind P (TypeCtx.kinds o.context) (.tvar 0) .value := by cases o <;> list_simp
 apply HasTypeVQ.V_Con inputs.options.none_decl rfl
 · exact singleton_kind kind (by intro b t e h; cases h)
 · intro a ha; cases ha
 · exact .nil
 · cases o <;> constructor <;> list_simp
private theorem option_some {P B Γ Φ Q v} (inputs : Inputs P B) (o : Op)
 (hv : HasTypeVQ P B StoreTy.empty Q o.context Γ Φ v (.tvar 0)) :
 HasTypeVQ P B StoreTy.empty Q o.context Γ Φ (.con "Option.Some" [.tvar 0] [v]) (.data "Option" [.tvar 0]) := by
 have ar : ∃ n, P.DataArity "Option" n ∧ 1=n := ⟨1,inputs.options.arity,rfl⟩
 have kind : Ty.HasKind P (TypeCtx.kinds o.context) (.tvar 0) .value := by cases o <;> list_simp
 apply HasTypeVQ.V_Con inputs.options.some_decl rfl
 · exact singleton_kind kind (by intro b t e h; cases h)
 · intro a ha; cases List.mem_singleton.mp ha; simp [Ty.WF]
 · exact .cons hv .nil
 · cases o <;> constructor <;> list_simp

local macro "list_var" : tactic => `(tactic| (refine HasTypeVQ.V_Var rfl ?_; intro b t e; list_simp))
local macro "list_pure" : tactic => `(tactic| apply pure_effect (by constructor <;> list_simp))
local macro "list_add" f:term : tactic => `(tactic|
 (list_pure; apply HasTypeCQ.C_App ($f _ _); exact .cons (by list_var) (.cons (.V_Const trivial) .nil)))
local macro "list_rec" f:term : tactic => `(tactic|
 (apply HasTypeCQ.C_App ($f _ _)
  first
   | exact .cons (by list_var) (.cons (by list_var) (.cons (by list_var) .nil))
   | exact .cons (by list_var) (.cons (by list_var) (.cons (by list_var) (.cons (by list_var) .nil)))))

/-- 五つのhelperは、get・callback・加算・再帰を元の順序で一度ずつ評価する。 -/
theorem helper_typed {P B} (inputs : Inputs P B) (o : Op) : o.definition.WellTyped P B := by
 have ar : ∃ n, P.DataArity "Option" n ∧ 1=n := ⟨1,inputs.options.arity,rfl⟩
 have ak := TyCon.arity_data inputs.options.arity
 have getFn := fun Γ Φ => get_function (Γ := Γ) (Φ := Φ) (Q := QTel o.definition.tel) inputs o
 have addFn := fun Γ Φ => add_function (Γ := Γ) (Φ := Φ) (Q := QTel o.definition.tel) inputs o
 have recFn := fun Γ Φ => helper_function (Γ := Γ) (Φ := Φ) (Q := QTel o.definition.tel) inputs o
 have noFn := fun Γ Φ => option_none (Γ := Γ) (Φ := Φ) (Q := QTel o.definition.tel) inputs o
 have someFn := fun Γ Φ v => option_some (Γ := Γ) (Φ := Φ) (Q := QTel o.definition.tel) (v := v) inputs o
 have alts := option_alternatives inputs.options
 cases o
 case fold =>
  refine ⟨by list_simp,by list_simp,?_,?_⟩
  · constructor <;> list_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [Op.definition,Op.body,Op.arms,Op.afterCall,Op.noneBody,Op.next,increment,recurse]
    apply HasTypeCQ.C_Let (a := .data "Option" [.tvar 0])
    · list_pure
      apply HasTypeCQ.C_App (getFn _ _)
      exact .cons (by list_var) (.cons (by list_var) .nil)
    · apply HasTypeCQ.C_Match (obs := none)
      · list_var
      · intro t h; cases h
      · apply HasTypeArmsQ.plainEmpty alts.1 (by simp [pathFacts,FactsWF])
        · list_pure
          exact .C_Return (by list_var)
        · apply HasTypeArmsQ.plainEmpty alts.2 (by simp [pathFacts,FactsWF])
          · apply HasTypeCQ.C_Let
            · apply HasTypeCQ.C_App
              · list_var
              · exact .cons (by list_var) (.cons (by list_var) .nil)
            · apply HasTypeCQ.C_Let (a := .base .integer)
              · list_add addFn
              · list_rec recFn
              · list_simp
            · list_simp
          · apply HasTypeArmsQ.nil; constructor <;> list_simp
      · list_simp
      · exact option_exhaustive inputs.options (.tvar 0)
    · list_simp
 case forEach =>
  refine ⟨by list_simp,by list_simp,?_,?_⟩
  · constructor <;> list_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [Op.definition,Op.body,Op.arms,Op.afterCall,Op.noneBody,Op.next,increment,recurse]
    apply HasTypeCQ.C_Let (a := .data "Option" [.tvar 0])
    · list_pure
      apply HasTypeCQ.C_App (getFn _ _)
      exact .cons (by list_var) (.cons (by list_var) .nil)
    · apply HasTypeCQ.C_Match (obs := none)
      · list_var
      · intro t h; cases h
      · apply HasTypeArmsQ.plainEmpty alts.1 (by simp [pathFacts,FactsWF])
        · list_pure
          exact .C_Return (.V_Const trivial)
        · apply HasTypeArmsQ.plainEmpty alts.2 (by simp [pathFacts,FactsWF])
          · apply HasTypeCQ.C_Let
            · apply HasTypeCQ.C_App
              · list_var
              · exact .cons (by list_var) .nil
            · apply HasTypeCQ.C_Let (a := .base .integer)
              · list_add addFn
              · list_rec recFn
              · list_simp
            · list_simp
          · apply HasTypeArmsQ.nil; constructor <;> list_simp
      · list_simp
      · exact option_exhaustive inputs.options (.tvar 0)
    · list_simp
 case any =>
  refine ⟨by list_simp,by list_simp,?_,?_⟩
  · constructor <;> list_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [Op.definition,Op.body,Op.arms,Op.afterCall,Op.noneBody,Op.next,increment,recurse]
    apply HasTypeCQ.C_Let (a := .data "Option" [.tvar 0])
    · list_pure
      apply HasTypeCQ.C_App (getFn _ _)
      exact .cons (by list_var) (.cons (by list_var) .nil)
    · apply HasTypeCQ.C_Match (obs := none)
      · list_var
      · intro t h; cases h
      · apply HasTypeArmsQ.plainEmpty alts.1 (by simp [pathFacts,FactsWF])
        · list_pure
          exact .C_Return (.V_Const trivial)
        · apply HasTypeArmsQ.plainEmpty alts.2 (by simp [pathFacts,FactsWF])
          · apply HasTypeCQ.C_Let
            · apply HasTypeCQ.C_App
              · list_var
              · exact .cons (by list_var) .nil
            · apply HasTypeCQ.C_If
              · list_var
              · rfl
              · list_pure
                exact .C_Return (.V_Const trivial)
              · apply HasTypeCQ.C_Let (a := .base .integer)
                · list_add addFn
                · list_rec recFn
                · list_simp
            · list_simp
          · apply HasTypeArmsQ.nil; constructor <;> list_simp
      · list_simp
      · exact option_exhaustive inputs.options (.tvar 0)
    · list_simp
 case all =>
  refine ⟨by list_simp,by list_simp,?_,?_⟩
  · constructor <;> list_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [Op.definition,Op.body,Op.arms,Op.afterCall,Op.noneBody,Op.next,increment,recurse]
    apply HasTypeCQ.C_Let (a := .data "Option" [.tvar 0])
    · list_pure
      apply HasTypeCQ.C_App (getFn _ _)
      exact .cons (by list_var) (.cons (by list_var) .nil)
    · apply HasTypeCQ.C_Match (obs := none)
      · list_var
      · intro t h; cases h
      · apply HasTypeArmsQ.plainEmpty alts.1 (by simp [pathFacts,FactsWF])
        · list_pure
          exact .C_Return (.V_Const trivial)
        · apply HasTypeArmsQ.plainEmpty alts.2 (by simp [pathFacts,FactsWF])
          · apply HasTypeCQ.C_Let
            · apply HasTypeCQ.C_App
              · list_var
              · exact .cons (by list_var) .nil
            · apply HasTypeCQ.C_If
              · list_var
              · rfl
              · apply HasTypeCQ.C_Let (a := .base .integer)
                · list_add addFn
                · list_rec recFn
                · list_simp
              · list_pure
                exact .C_Return (.V_Const trivial)
            · list_simp
          · apply HasTypeArmsQ.nil; constructor <;> list_simp
      · list_simp
      · exact option_exhaustive inputs.options (.tvar 0)
    · list_simp
 case find =>
  refine ⟨by list_simp,by list_simp,?_,?_⟩
  · constructor <;> list_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    dsimp only [Op.definition,Op.body,Op.arms,Op.afterCall,Op.noneBody,Op.next,increment,recurse]
    apply HasTypeCQ.C_Let (a := .data "Option" [.tvar 0])
    · list_pure
      apply HasTypeCQ.C_App (getFn _ _)
      exact .cons (by list_var) (.cons (by list_var) .nil)
    · apply HasTypeCQ.C_Match (obs := none)
      · list_var
      · intro t h; cases h
      · apply HasTypeArmsQ.plainEmpty alts.1 (by simp [pathFacts,FactsWF])
        · list_pure
          exact .C_Return (noFn _ _)
        · apply HasTypeArmsQ.plainEmpty alts.2 (by simp [pathFacts,FactsWF])
          · apply HasTypeCQ.C_Let
            · apply HasTypeCQ.C_App
              · list_var
              · exact .cons (by list_var) .nil
            · apply HasTypeCQ.C_If
              · list_var
              · rfl
              · list_pure
                exact .C_Return (someFn _ _ _ (by list_var))
              · apply HasTypeCQ.C_Let (a := .base .integer)
                · list_add addFn
                · list_rec recFn
                · list_simp
            · list_simp
          · apply HasTypeArmsQ.nil; constructor <;> list_simp
      · list_simp
      · exact option_exhaustive inputs.options (.tvar 0)
    · list_simp

/-- 公開五本は元のhelperを添字0で呼び、初期accを保持する。 -/
theorem public_typed {P B} (inputs : Inputs P B) (o : Op) : o.publicDefinition.WellTyped P B := by
 have ar : ∃ n, P.DataArity "Option" n ∧ 1=n := ⟨1,inputs.options.arity,rfl⟩
 have ak := TyCon.arity_data inputs.options.arity
 have fn := fun Γ Φ => helper_function (Γ := Γ) (Φ := Φ) (Q := QTel o.publicDefinition.tel) inputs o
 cases o
 case fold =>
  refine ⟨by list_simp,by list_simp,?_,?_⟩
  · constructor <;> list_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    apply HasTypeCQ.C_App (fn _ _)
    exact .cons (by list_var) (.cons (by list_var) (.cons (by list_var) (.cons (.V_Const trivial) .nil)))
 case forEach =>
  refine ⟨by list_simp,by list_simp,?_,?_⟩
  · constructor <;> list_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    apply HasTypeCQ.C_App (fn _ _)
    exact .cons (by list_var) (.cons (by list_var) (.cons (.V_Const trivial) .nil))
 case any =>
  refine ⟨by list_simp,by list_simp,?_,?_⟩
  · constructor <;> list_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    apply HasTypeCQ.C_App (fn _ _)
    exact .cons (by list_var) (.cons (by list_var) (.cons (.V_Const trivial) .nil))
 case all =>
  refine ⟨by list_simp,by list_simp,?_,?_⟩
  · constructor <;> list_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    apply HasTypeCQ.C_App (fn _ _)
    exact .cons (by list_var) (.cons (by list_var) (.cons (.V_Const trivial) .nil))
 case find =>
  refine ⟨by list_simp,by list_simp,?_,?_⟩
  · constructor <;> list_simp
  · apply TelBodyTy.param; apply TelBodyTy.param; apply TelBodyTy.done
    apply HasTypeCQ.C_App (fn _ _)
    exact .cons (by list_var) (.cons (by list_var) (.cons (.V_Const trivial) .nil))

theorem model_inputs : Inputs program builtins :=
 ⟨option_declarations rfl,rfl,rfl,helper_lookup,fun _ _ => rfl⟩

theorem declarations_typed (o : Op) :
 program.defs o.name=some o.publicDefinition ∧ program.defs o.helperName=some o.definition ∧
 o.publicDefinition.WellTyped program builtins ∧ o.definition.WellTyped program builtins := by
 refine ⟨?_,helper_lookup o,public_typed model_inputs o,helper_typed model_inputs o⟩
 cases o <;> simp [program,definitions,Op.every,Op.name,Op.helperName,List.lookup]

example (o : Op) : o.publicDefinition.WellTyped program builtins := (declarations_typed o).2.2.1
example (o : Op) : o.definition.WellTyped program builtins := (declarations_typed o).2.2.2

end
end Benitoite.Release.Refinement.StandardOrdinaryListBodies
