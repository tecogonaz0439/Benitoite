import Benitoite.Release.Refinement.StandardActualListBodies
import Benitoite.Release.Refinement.StandardSafeAnnotations
import Benitoite.Release.Refinement.StandardCollectionExamples

/-! # 標準coreの通常署名と実本体の型付け -/
namespace Benitoite.Release.Refinement.StandardOrdinaryCoreBodies
noncomputable section
open StandardKeyTyping
set_option maxHeartbeats 4000000
set_option linter.unusedSimpArgs false

inductive Record where
 | checkedInteger | checkedLength | checkedIndex | nonempty
 deriving DecidableEq

def Record.owner : Record → String
 | .checkedInteger => StandardSafe.names.checkedInteger
 | .checkedLength => StandardSafe.names.checkedLength
 | .checkedIndex => StandardSafe.names.checkedIndex
 | .nonempty => "Benitoite.NonEmptyList.NonEmptyList"
def Record.arity : Record → Nat
 | .checkedInteger => 0 | _ => 1
def Record.fields : Record → List Ty
 | .checkedInteger => [.base .integer,.base .integer,.base .integer]
 | .checkedLength => [.base .integer,.base .integer,.base .integer,.list (.tvar 0)]
 | .checkedIndex => [.list (.tvar 0),.base .integer,.tvar 0]
 | .nonempty => [.tvar 0,.list (.tvar 0)]
def Record.type (r : Record) : Ty := .data r.owner (if r.arity=0 then [] else [.tvar 0])
def Record.params (r : Record) : TypeCtx := List.replicate r.arity TypeCtx.valueParam

def declarations : List DataDecl := [
 ⟨"Option",1,[("Option.None",[]),("Option.Some",[.tvar 0])]⟩,
 ⟨"Pair",2,[("Pair.Pair",[.tvar 0,.tvar 1])]⟩,
 ⟨StandardSafe.names.result,2,[("Benitoite.Result.Result.Ok",[.tvar 0]),("Benitoite.Result.Result.Error",[.tvar 1])]⟩,
 ⟨Record.owner .checkedInteger,0,[(Record.owner .checkedInteger,Record.fields .checkedInteger)]⟩,
 ⟨Record.owner .checkedLength,1,[(Record.owner .checkedLength,Record.fields .checkedLength)]⟩,
 ⟨Record.owner .checkedIndex,1,[(Record.owner .checkedIndex,Record.fields .checkedIndex)]⟩,
 ⟨Record.owner .nonempty,1,[(Record.owner .nonempty,Record.fields .nonempty)]⟩,
 ⟨"Benitoite.Range.RangeError",0,[("Benitoite.Range.RangeError.InvalidBounds",[.base .integer,.base .integer]),("Benitoite.Range.RangeError.OutOfRange",[.base .integer,.base .integer,.base .integer])]⟩,
 ⟨"Benitoite.Range.LengthError",0,[("Benitoite.Range.LengthError.InvalidBounds",[.base .integer,.base .integer]),("Benitoite.Range.LengthError.OutOfRange",[.base .integer,.base .integer,.base .integer])]⟩,
 ⟨"Benitoite.Range.IndexError",0,[("Benitoite.Range.IndexError.OutOfBounds",[.base .integer,.base .integer])]⟩,
 ⟨StandardSafe.names.emptyListError,0,[("Benitoite.NonEmptyList.EmptyListError.EmptyList",[])]⟩]
def constructorTable := declarations.flatMap DataDecl.entries

inductive Getter where
 | minimum | maximum | integerValue | lengthMinimum | lengthMaximum | length | lengthValues
 | indexValues | index | element | first | rest
 deriving DecidableEq

def Getter.record : Getter → Record
 | .minimum | .maximum | .integerValue => .checkedInteger
 | .lengthMinimum | .lengthMaximum | .length | .lengthValues => .checkedLength
 | .indexValues | .index | .element => .checkedIndex
 | .first | .rest => .nonempty

def Getter.position : Getter → Nat
 | .minimum | .lengthMinimum | .indexValues | .first => 0
 | .maximum | .lengthMaximum | .index | .rest => 1
 | .integerValue | .length | .element => 2
 | .lengthValues => 3

def Getter.field : Getter → String
 | .minimum | .lengthMinimum => "minimum"
 | .maximum | .lengthMaximum => "maximum"
 | .integerValue => "value" | .length => "length"
 | .lengthValues | .indexValues => "values" | .index => "index" | .element => "element"
 | .first => "first" | .rest => "rest"
def Getter.name (g : Getter) : String := g.record.owner ++ "." ++ g.field

def Getter.result (g : Getter) : Ty := g.record.fields.getD g.position (.base .unit)
def Getter.pattern (g : Getter) : Pat := .con g.record.owner
 (g.record.fields.zipIdx.map fun (_,i) => if i=g.position then .var else .wild)
def Getter.alts (g : Getter) : List Alt := [⟨g.pattern,[0]⟩]
def Getter.body (g : Getter) : Comp := .match (.var 0) [.mk g.alts none (.ret (.var 0))]
def Getter.definition (g : Getter) : Def :=
 ⟨g.record.params,0,["value"],[g.record.type],g.result,Eff.empty,g.body, []⟩
def Getter.publicName : Getter → String
 | .minimum => "Range.minimum" | .maximum => "Range.maximum" | .integerValue => "Range.value"
 | .lengthMinimum => "Range.lengthMinimum" | .lengthMaximum => "Range.lengthMaximum"
 | .length => "Range.checkedLength" | .lengthValues => "Range.lengthValues"
 | .indexValues => "Range.indexValues" | .index => "Range.indexValue" | .element => "Range.get"
 | .first => "NonEmptyList.head" | .rest => "NonEmptyList.tail"
def Getter.publicBody (g : Getter) : Comp :=
 .app (.fnRef g.name (if g.record.arity=0 then [] else [.tvar 0]) []) [.var 0]
def Getter.publicDefinition (g : Getter) : Def :=
 {g.definition with body := g.publicBody}
def Getter.all : List Getter := [.minimum,.maximum,.integerValue,.lengthMinimum,.lengthMaximum,.length,.lengthValues,.indexValues,.index,.element,.first,.rest]

def definitions : List (FunName × Def) := Getter.all.flatMap fun g =>
 [(g.name,g.definition),(g.publicName,g.publicDefinition)]
def program : Program where
 defs := fun n => definitions.lookup n
 cons := fun n => constructorTable.lookup n
 ops := fun _ => none
 effects := fun _ => none
 classes := fun _ => none
 impls := fun _ => none

def builtins : Builtins := StandardCollectionModel.builtins

private theorem cons_mem {P : Program} (same : P.cons = fun n => constructorTable.lookup n)
 {c cd} (lookup : P.cons c=some cd) : (c,cd) ∈ constructorTable := by
 rw [same] at lookup
 obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp lookup
 rw [eq]
 exact List.mem_append_right _ (List.mem_cons_self ..)

/-- 本体が読む四つの記録型の宣言。各記録型は同名の一つの構成子だけを持つ。 -/
structure Records (P : Program) : Prop where
 decl : ∀ r : Record, P.cons r.owner=some ⟨r.owner,r.arity,r.fields⟩
 only : ∀ (r : Record) {c cd}, P.cons c=some cd → cd.data=r.owner → c=r.owner

/-- 固定の構成子の表を持つPは、四つの記録型の宣言を持つ。 -/
theorem Records.of_table {P : Program} (same : P.cons = fun n => constructorTable.lookup n) : Records P := by
 refine ⟨fun r => by rw [same]; cases r <;> rfl,?_⟩
 intro r c cd h owner
 have mem := cons_mem same h
 cases r <;> simp [constructorTable,declarations,DataDecl.entries,List.mem_cons,List.not_mem_nil,Prod.mk.injEq] at mem
 all_goals rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
 all_goals simp_all [Record.owner,StandardSafe.names]

private theorem record_arity {P : Program} (records : Records P) (r : Record) :
 P.DataArity r.owner r.arity := by
 refine ⟨⟨r.owner,_,records.decl r,rfl⟩,?_⟩
 intro c cd h owner
 have eq := records.only r h owner
 subst c
 cases Option.some.inj (h.symm.trans (records.decl r))
 rfl

local macro "core_simp" : tactic => `(tactic|
 simp_all [Getter.record,Getter.position,Getter.result,Getter.field,Getter.name,Getter.pattern,Getter.alts,
  Getter.body,Getter.definition,Getter.publicBody,Getter.publicDefinition,
  Record.params,Record.arity,Record.type,Record.fields,Record.owner,StandardSafe.names,
  Def.tel,PrimSig.tel,signatureTel,Tel.names,Tel.inputs,Tel.result,Tel.effect,
  TypeCtx.valueParam,TypeCtx.kinds,TypeCtx.constraints,TParamDecl.constraints,
  TypeAnnotations,RowAnnotations,Ty.Annotation,Ty.WF,Tel.WF,Ty.WFList,Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,
  Ty.Declared,Tel.Declared,declaredTys,declaredEff,Ty.HasKind,kindsTel,kindsList,kindsEff,
  NamesWF,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Ordinary,Ty.core,
  Builtins.RangeAdmissible,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
  Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,Tel.bind,Tel.rawBind,Ty.bind,Ty.rawBind,rawBindTys,
  Ty.norm,Tel.norm,Ty.normTys,typeEnvAt,SubstEnv.up,SubstEnv.rangesOnly,Eff.rawBind,rowFails,
  substAtoms_nil,instAtoms_nil,Qsig,QTel,QTy,QTys,QEff,Qempty,Eff.RowsIn,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,
  RowTransport,NoFail,SatAll,Eff.test,Eff.atoms,Eff.fails,Eff.shiftV,Ty.shiftV,shiftVTys,Tel.shiftV,Ctx.extend,
  bindParams,localExtend,Pred.lift,liftMany])

private theorem getter_alts {P : Program} (records : Records P) (g : Getter) :
 AltsTy P g.alts g.record.type [g.result] := by
 have decl := records.decl g.record
 cases g <;> refine ⟨by simp [Getter.alts],rfl,?_,?_⟩
 all_goals first
  | (solve | intro alt h; cases Option.some.inj h; rfl)
  | skip
 case minimum.refine_2 =>
  intro alt h; cases List.mem_singleton.mp h
  refine ⟨[_],.P_Con decl rfl ?_ ?_,by simp,rfl⟩
  · intro a ha
    simp only [Getter.record,Record.fields,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl | rfl <;> simp [Getter.record,Record.arity,Ty.WF]
  · exact (.cons .P_Var (.cons .P_Wild (.cons .P_Wild .nil)))
 case maximum.refine_2 =>
  intro alt h; cases List.mem_singleton.mp h
  refine ⟨[_],.P_Con decl rfl ?_ ?_,by simp,rfl⟩
  · intro a ha
    simp only [Getter.record,Record.fields,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl | rfl <;> simp [Getter.record,Record.arity,Ty.WF]
  · exact (.cons .P_Wild (.cons .P_Var (.cons .P_Wild .nil)))
 case integerValue.refine_2 =>
  intro alt h; cases List.mem_singleton.mp h
  refine ⟨[_],.P_Con decl rfl ?_ ?_,by simp,rfl⟩
  · intro a ha
    simp only [Getter.record,Record.fields,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl | rfl <;> simp [Getter.record,Record.arity,Ty.WF]
  · exact (.cons .P_Wild (.cons .P_Wild (.cons .P_Var .nil)))
 case lengthMinimum.refine_2 =>
  intro alt h; cases List.mem_singleton.mp h
  refine ⟨[_],.P_Con decl rfl ?_ ?_,by simp,rfl⟩
  · intro a ha
    simp only [Getter.record,Record.fields,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl | rfl | rfl <;> simp [Getter.record,Record.arity,Ty.WF]
  · exact (.cons .P_Var (.cons .P_Wild (.cons .P_Wild (.cons .P_Wild .nil))))
 case lengthMaximum.refine_2 =>
  intro alt h; cases List.mem_singleton.mp h
  refine ⟨[_],.P_Con decl rfl ?_ ?_,by simp,rfl⟩
  · intro a ha
    simp only [Getter.record,Record.fields,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl | rfl | rfl <;> simp [Getter.record,Record.arity,Ty.WF]
  · exact (.cons .P_Wild (.cons .P_Var (.cons .P_Wild (.cons .P_Wild .nil))))
 case length.refine_2 =>
  intro alt h; cases List.mem_singleton.mp h
  refine ⟨[_],.P_Con decl rfl ?_ ?_,by simp,rfl⟩
  · intro a ha
    simp only [Getter.record,Record.fields,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl | rfl | rfl <;> simp [Getter.record,Record.arity,Ty.WF]
  · exact (.cons .P_Wild (.cons .P_Wild (.cons .P_Var (.cons .P_Wild .nil))))
 case lengthValues.refine_2 =>
  intro alt h; cases List.mem_singleton.mp h
  refine ⟨[_],.P_Con decl rfl ?_ ?_,by simp,rfl⟩
  · intro a ha
    simp only [Getter.record,Record.fields,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl | rfl | rfl <;> simp [Getter.record,Record.arity,Ty.WF]
  · exact (.cons .P_Wild (.cons .P_Wild (.cons .P_Wild (.cons .P_Var .nil))))
 case indexValues.refine_2 =>
  intro alt h; cases List.mem_singleton.mp h
  refine ⟨[_],.P_Con decl rfl ?_ ?_,by simp,rfl⟩
  · intro a ha
    simp only [Getter.record,Record.fields,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl | rfl <;> simp [Getter.record,Record.arity,Ty.WF]
  · exact (.cons .P_Var (.cons .P_Wild (.cons .P_Wild .nil)))
 case index.refine_2 =>
  intro alt h; cases List.mem_singleton.mp h
  refine ⟨[_],.P_Con decl rfl ?_ ?_,by simp,rfl⟩
  · intro a ha
    simp only [Getter.record,Record.fields,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl | rfl <;> simp [Getter.record,Record.arity,Ty.WF]
  · exact (.cons .P_Wild (.cons .P_Var (.cons .P_Wild .nil)))
 case element.refine_2 =>
  intro alt h; cases List.mem_singleton.mp h
  refine ⟨[_],.P_Con decl rfl ?_ ?_,by simp,rfl⟩
  · intro a ha
    simp only [Getter.record,Record.fields,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl | rfl <;> simp [Getter.record,Record.arity,Ty.WF]
  · exact (.cons .P_Wild (.cons .P_Wild (.cons .P_Var .nil)))
 case first.refine_2 =>
  intro alt h; cases List.mem_singleton.mp h
  refine ⟨[_],.P_Con decl rfl ?_ ?_,by simp,rfl⟩
  · intro a ha
    simp only [Getter.record,Record.fields,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl <;> simp [Getter.record,Record.arity,Ty.WF]
  · exact (.cons .P_Var (.cons .P_Wild .nil))
 case rest.refine_2 =>
  intro alt h; cases List.mem_singleton.mp h
  refine ⟨[_],.P_Con decl rfl ?_ ?_,by simp,rfl⟩
  · intro a ha
    simp only [Getter.record,Record.fields,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl <;> simp [Getter.record,Record.arity,Ty.WF]
  · exact (.cons .P_Wild (.cons .P_Var .nil))

private theorem getter_exhaustive {P : Program} (records : Records P) (g : Getter) :
 Exhaustive P g.record.type [g.pattern] := by
 intro v inhabitant
 have aux : ∀ t v, Inhabits P t v → t=g.record.type.norm →
  (matchVal g.pattern v).isSome := by
  intro t v h eq
  cases h <;> try (cases g <;> cases eq)
  case const c => cases c <;> cases g <;> cases eq
  case atError => cases g <;> simp [atErrorType,Getter.record,Record.type,Record.owner,Record.arity,StandardSafe.names,Ty.norm,Ty.normTys] at eq
  case con c ts tys args cd lookup ntys wf fields =>
   have owner : cd.data=g.record.owner := by cases g <;> exact (Ty.data.inj eq).1
   have hc := records.only g.record lookup owner
   subst c
   cases Option.some.inj (lookup.symm.trans (records.decl g.record))
   cases g
   case minimum =>
    cases fields with | cons a fields =>
     cases fields with | cons a fields =>
      cases fields with | cons a fields =>
       cases fields
       rfl
   case maximum =>
    cases fields with | cons a fields =>
     cases fields with | cons a fields =>
      cases fields with | cons a fields =>
       cases fields
       rfl
   case integerValue =>
    cases fields with | cons a fields =>
     cases fields with | cons a fields =>
      cases fields with | cons a fields =>
       cases fields
       rfl
   case lengthMinimum =>
    cases fields with | cons a fields =>
     cases fields with | cons a fields =>
      cases fields with | cons a fields =>
       cases fields with | cons a fields =>
        cases fields
        rfl
   case lengthMaximum =>
    cases fields with | cons a fields =>
     cases fields with | cons a fields =>
      cases fields with | cons a fields =>
       cases fields with | cons a fields =>
        cases fields
        rfl
   case length =>
    cases fields with | cons a fields =>
     cases fields with | cons a fields =>
      cases fields with | cons a fields =>
       cases fields with | cons a fields =>
        cases fields
        rfl
   case lengthValues =>
    cases fields with | cons a fields =>
     cases fields with | cons a fields =>
      cases fields with | cons a fields =>
       cases fields with | cons a fields =>
        cases fields
        rfl
   case indexValues =>
    cases fields with | cons a fields =>
     cases fields with | cons a fields =>
      cases fields with | cons a fields =>
       cases fields
       rfl
   case index =>
    cases fields with | cons a fields =>
     cases fields with | cons a fields =>
      cases fields with | cons a fields =>
       cases fields
       rfl
   case element =>
    cases fields with | cons a fields =>
     cases fields with | cons a fields =>
      cases fields with | cons a fields =>
       cases fields
       rfl
   case first =>
    cases fields with | cons a fields =>
     cases fields with | cons a fields =>
      cases fields
      rfl
   case rest =>
    cases fields with | cons a fields =>
     cases fields with | cons a fields =>
      cases fields
      rfl

 exact ⟨g.pattern,by simp,aux _ _ inhabitant rfl⟩

/-- 自動getterの通常契約は、四つの記録型の宣言を持つ任意のPで、nominalの一腕matchから検査する。 -/
theorem getter_typed_of {P : Program} (records : Records P) (B : Builtins) (g : Getter) :
 g.definition.WellTyped P B := by
 have ar := record_arity records g.record
 have ak := TyCon.arity_data ar
 cases g
 all_goals refine ⟨?_,?_,?_,TelBodyTy.param (TelBodyTy.done ?_)⟩
 all_goals first
  | (solve | core_simp)
  | (solve | constructor <;> core_simp)
  | (apply HasTypeCQ.C_Match (obs := none)
     · exact .V_Var rfl (by intro b t e; core_simp)
     · intro t h; cases h
     · apply HasTypeArmsQ.plainEmpty (getter_alts records _) (by simp [pathFacts,FactsWF])
       · exact .C_Return (.V_Var rfl (by intro b t e; core_simp))
       · apply HasTypeArmsQ.nil; constructor <;> core_simp
     · core_simp
     · exact getter_exhaustive records _)

/-- 自動getterの通常契約は、nominalの一腕matchから検査する。 -/
theorem getter_typed {P : Program} (same : P.cons = fun n => constructorTable.lookup n) (B : Builtins) (g : Getter) :
 g.definition.WellTyped P B :=
 getter_typed_of (Records.of_table same) B g


private theorem empty_range : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
 funext a; cases a <;> simp [mapRangeAtoms]

/-- 同じ通常getter定義を、四つの記録型の宣言を持つ任意のPで元のvalueラベルで参照する。 -/
theorem getter_reference_of {P B Ψ Q Γ Φ}
 (records : Records P)
 (sat : ∀ C a, B.sat C a {}) (g : Getter)
 (lookup : P.defs g.name=some g.definition) :
 HasTypeVQ P B Ψ Q g.record.params Γ Φ
  (.fnRef g.name (if g.record.arity=0 then [] else [.tvar 0]) [])
  (.fn ["value"] [g.record.type] g.result Eff.empty) := by
 have ar := record_arity records g.record
 have ak := TyCon.arity_data ar
 have names : NamesWF g.definition.names g.definition.params := by cases g <;> core_simp
 have ad : Admissible B g.record.params Γ.length (TypeCtx.constraints g.definition.tparams) 0
  (Qsig g.definition.params g.definition.ret g.definition.eff) Q
  (if g.record.arity=0 then [] else [.tvar 0]) [] g.definition.eff := by
  cases g <;> constructor
  all_goals first
   | (solve | constructor <;> core_simp)
   | (solve | core_simp)
   | (solve | core_simp; rintro (_|i) a p ha hp <;> core_simp)
 have inst : SignatureInstance P g.record.params Γ g.definition.tel
  (TypeCtx.kinds g.definition.tparams) (if g.record.arity=0 then [] else [.tvar 0]) [] := by
  cases g <;> constructor
  all_goals first
   | (solve | constructor <;> core_simp)
   | (solve | core_simp)
   | (solve | intro a ha; cases List.mem_singleton.mp ha; constructor <;> core_simp)
   | (solve | constructor; core_simp; rintro (_|i) a k ha hk <;> core_simp <;> subst_vars; constructor <;> core_simp)
 apply (HasTypeVQ.fun_empty (Ψ := Ψ) (Φ := Φ) lookup names (by rfl) ad inst).convert
 · have fold := Ty.foldFn_toTel ⟨["value"],[g.record.type],g.result,Eff.empty,by simp [NamesWF]⟩
   cases g <;> core_simp
   all_goals simpa [FnView.toTel,Ty.toTel,Getter.record,Getter.result,Getter.position,Record.type,Record.arity,Record.fields,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty] using fold
 · cases g <;> constructor <;> core_simp

/-- 各公開射影の本体は、四つの記録型の宣言を持つ任意のPで、自動getterを一度呼ぶ元の本体である。 -/
theorem projection_typed_of {P B} (records : Records P)
 (sat : ∀ C a, B.sat C a {}) (g : Getter)
 (lookup : P.defs g.name=some g.definition) : g.publicDefinition.WellTyped P B := by
 have ar := record_arity records g.record
 have ak := TyCon.arity_data ar
 have fn := fun Γ Φ => getter_reference_of (Γ := Γ) (Φ := Φ) (Q := QTel g.publicDefinition.tel) (Ψ := StoreTy.empty) records sat g lookup
 cases g <;> refine ⟨?_,?_,?_,TelBodyTy.param (TelBodyTy.done ?_)⟩
 all_goals first
  | (solve | core_simp)
  | (solve | constructor <;> core_simp)
  | (apply HasTypeCQ.C_App (fn _ _); exact .cons (.V_Var rfl (by intro b t e; core_simp)) .nil)

/-- 各公開射影の本体は、自動getterを一度呼ぶ元の本体である。 -/
theorem projection_typed {P B} (same : P.cons = fun n => constructorTable.lookup n)
 (sat : ∀ C a, B.sat C a {}) (g : Getter)
 (lookup : P.defs g.name=some g.definition) : g.publicDefinition.WellTyped P B :=
 projection_typed_of (Records.of_table same) sat g lookup

/-- 通常getterと公開射影の全lookupを、同じ有限表の型付けに接続する。 -/
theorem getter_declarations (g : Getter) :
 program.defs g.name=some g.definition ∧ program.defs g.publicName=some g.publicDefinition ∧
 g.definition.WellTyped program builtins ∧ g.publicDefinition.WellTyped program builtins := by
 have look : program.defs g.name=some g.definition := by
  cases g <;> simp [program,definitions,Getter.all,Getter.name,Getter.publicName,Getter.field,Getter.record,Record.owner,StandardSafe.names,List.lookup]
 have pub : program.defs g.publicName=some g.publicDefinition := by
  cases g <;> simp [program,definitions,Getter.all,Getter.name,Getter.publicName,Getter.field,Getter.record,Record.owner,StandardSafe.names,List.lookup]
 refine ⟨look,pub,getter_typed rfl _ g,projection_typed rfl ?_ g look⟩
 intro C a; rfl

example (g : Getter) : g.definition.WellTyped program builtins := (getter_declarations g).2.2.1
example (g : Getter) : g.publicDefinition.WellTyped program builtins := (getter_declarations g).2.2.2

end
end Benitoite.Release.Refinement.StandardOrdinaryCoreBodies
