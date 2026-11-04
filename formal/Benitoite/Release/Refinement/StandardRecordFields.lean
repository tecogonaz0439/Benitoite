import Benitoite.Release.Refinement.StandardFactExamples
import Benitoite.Release.Refinement.CanonicalValues
import Benitoite.Release.Refinement.StandardKeyTyping
import Benitoite.Release.Refinement.FieldObservationExamples

/-! # 同じ宣言表の不変欄と型付きの二段連鎖 -/
namespace Benitoite.Release.Refinement.StandardDecode
noncomputable section
open StandardKeyTyping

def nonnegative : Ty := .refined (.base .integer) (.le (.integer 0) (.var 0))

/-- Raw/Checked/Envelope は Lean 内部の検査列の代表である。 -/
def recordDeclarations : List DataDecl := [
  ⟨"Raw",0,[("Raw.Make",[.base .integer,.base .integer])]⟩,
  ⟨"Checked",0,[("Checked.Make",[nonnegative,nonnegative])]⟩,
  ⟨"Envelope",0,[("Envelope.Make",[.data "Checked" []])]⟩,
  ⟨"Result",2,[("Result.Ok",[.tvar 0]),("Result.Error",[.tvar 1])]⟩,
  ⟨"ConversionError",0,[("ConversionError.Make",[.list (.data "PathPart" []),.base .string,.base .string,.base .string])]⟩,
  ⟨"PathPart",0,[("PathPart.Field",[.base .string]),("PathPart.Index",[.base .integer]),("PathPart.Key",[.base .string])]⟩,
  ⟨"People.Person",0,[("People.Person.Make",[.base .string,.data "Address.Address" [],
    .data "Option" [.base .string],.list (.map (.base .string) (.base .float)),.base .boolean,.base .integer])]⟩,
  ⟨"Address.Address",0,[("Address.Address.Make",[.base .string])]⟩,
  ⟨"Option",1,[("Option.Some",[.tvar 0]),("Option.None",[])]⟩]

def recordProgram : Program where
  defs := fun _ => none
  cons := fun c => (recordDeclarations.flatMap DataDecl.entries).lookup c
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

private theorem cons_mem {c cd} (h : recordProgram.cons c = some cd) :
    (c,cd) ∈ recordDeclarations.flatMap DataDecl.entries := by
  obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp h
  rw [eq]
  exact List.mem_append_right _ (List.mem_cons_self ..)

private def recordArity (name : String) : Nat :=
  if name = "Result" then 2 else if name = "Option" then 1 else 0

private theorem arity_agreement {c cd} (h : recordProgram.cons c = some cd) :
    cd.ntys = recordArity cd.data := by
  have mem := cons_mem h
  simp only [recordDeclarations,List.flatMap_cons,List.flatMap_nil,DataDecl.entries,
    List.map_cons,List.map_nil,List.nil_append,List.cons_append,
    List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
  rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals rfl

private theorem arity_of_constructor {c cd} (h : recordProgram.cons c = some cd) :
    recordProgram.DataArity cd.data cd.ntys := by
  refine ⟨⟨c,cd,h,rfl⟩,?_⟩
  intro c' cd' hc same
  rw [arity_agreement hc,arity_agreement h,same]

private theorem raw_arity : recordProgram.DataArity "Raw" 0 := arity_of_constructor (c := "Raw.Make") rfl
private theorem checked_arity : recordProgram.DataArity "Checked" 0 := arity_of_constructor (c := "Checked.Make") rfl
private theorem envelope_arity : recordProgram.DataArity "Envelope" 0 := arity_of_constructor (c := "Envelope.Make") rfl
private theorem result_arity : recordProgram.DataArity "Result" 2 := arity_of_constructor (c := "Result.Ok") rfl
private theorem error_arity : recordProgram.DataArity "ConversionError" 0 := arity_of_constructor (c := "ConversionError.Make") rfl
private theorem path_arity : recordProgram.DataArity "PathPart" 0 := arity_of_constructor (c := "PathPart.Field") rfl
private theorem person_arity : recordProgram.DataArity "People.Person" 0 := arity_of_constructor (c := "People.Person.Make") rfl
private theorem address_arity : recordProgram.DataArity "Address.Address" 0 := arity_of_constructor (c := "Address.Address.Make") rfl
private theorem option_arity : recordProgram.DataArity "Option" 1 := arity_of_constructor (c := "Option.Some") rfl

/-- 全欄の注釈と変性を同じ有限表から検査する。 -/
theorem record_valid : recordProgram.VarianceValid := by
  constructor
  · intro d info h; cases h
  · intro c cd h
    have mem := cons_mem h
    simp only [recordDeclarations,List.flatMap_cons,List.flatMap_nil,DataDecl.entries,
      List.map_cons,List.map_nil,List.nil_append,List.cons_append,
      List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals
      constructor
      · intro info h; cases h
      · intro a ha
        simp only [List.mem_cons,List.not_mem_nil,or_false] at ha
        all_goals first | subst a | rcases ha with rfl | rfl | rfl | rfl | rfl | rfl
        all_goals refine ⟨⟨?_,?_,?_⟩,?_,?_⟩
        all_goals simp [nonnegative,Ty.WF,Ty.Sorted,Ty.Declared,Ty.HasKind,
          TypeCtx.valueParam,Ty.VarianceOK,Program.varianceFor,Variance.accepts,
          Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,
          Term.References,Term.VarsIn,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ty.core,
          Ty.NotContCore,Ctx.declarationSelf,Ctx.extend,Ty.shiftV,declaredTys,checked_arity,path_arity,address_arity,option_arity,Ty.HasSort,kindsList,TyCon.arity_data checked_arity,
          TyCon.arity_data path_arity,TyCon.arity_data address_arity,TyCon.arity_data option_arity]

        all_goals simp [recordProgram,Ty.Sorted,Ty.WFList,sortedTys,varianceArgsOK,Ty.VarianceOK,Ty.WF]

local macro "record_type_simp" : tactic => `(tactic|
  simp [nonnegative,Ty.subst,Ty.substAt,substTypeAt,typeEnvAt,Ty.bind,Ty.rawBind,
    rawBindTys,Ty.norm,Ty.normTys,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
    Pred.conjuncts,Pred.ofConjuncts,Ty.core,SubstEnv.up,predBind,termBind,termBind?,upValues,
    Ty.shiftV,shiftVTys] at *)

/-- 同じ構成子の宣言を根拠に、型引数なしの名目型を形成する。 -/
theorem record_annotation (Γ : Ctx) {c cd} (hc : recordProgram.cons c = some cd)
    (hn : cd.ntys = 0) : Ty.Annotation recordProgram [] Γ (.data cd.data []) := by
  refine ⟨trivial,trivial,⟨⟨0,hn ▸ arity_of_constructor hc,rfl⟩,trivial⟩⟩

theorem record_kind {c cd} (hc : recordProgram.cons c = some cd) (hn : cd.ntys = 0) :
    Ty.HasKind recordProgram [] (.data cd.data []) .value :=
  ⟨by simpa only [hn,List.length_nil] using TyCon.arity_data (arity_of_constructor hc),trivial⟩

theorem result_kind (a b : Ty) (ha : a.HasKind recordProgram [] .value)
    (hb : b.HasKind recordProgram [] .value) :
    Ty.HasKind recordProgram [] (.data "Result" [a,b]) .value :=
  ⟨TyCon.arity_data result_arity,ha,hb,trivial⟩

private theorem nonnegative_annotation (Γ : Ctx) : Ty.Annotation recordProgram [] Γ nonnegative := by
  refine ⟨?_,?_,?_⟩
  all_goals simp [nonnegative,Ty.WF,Ty.Sorted,Ty.Declared,Ty.NotContCore,Ty.core,
    Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,
    Term.References,Term.VarsIn,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ctx.declarationSelf,Ctx.extend,Ty.shiftV]

private theorem nullary_kinds : TypeArgsKinded recordProgram [] [] [] := ⟨rfl,by intro i t k h; cases h⟩

/-- 二欄を検査した同じ値だけを、篩を持つ宣言の構成子へ格納する。 -/
theorem checked_construct {B Ψ Γ Φ lo hi tl th}
    (loTyped : HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ lo (.base .integer))
    (hiTyped : HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ hi (.base .integer))
    (loTerm : lo.toTerm? = some tl) (hiTerm : hi.toTerm? = some th)
    (loNonnegative : Entails (Γ.facts ++ Φ) (.le (.integer 0) tl))
    (hiNonnegative : Entails (Γ.facts ++ Φ) (.le (.integer 0) th)) :
    HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ (.con "Checked.Make" [] [lo,hi]) (.data "Checked" []) := by
  have refineLo : HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ lo nonnegative :=
    .V_Refine loTyped rfl loTerm (nonnegative_annotation Γ).sorted.2 (nonnegative_annotation Γ).wf.2.1
      loNonnegative trivial (nonnegative_annotation Γ).declared.2
  have refineHi : HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ hi nonnegative :=
    .V_Refine hiTyped rfl hiTerm (nonnegative_annotation Γ).sorted.2 (nonnegative_annotation Γ).wf.2.1
      hiNonnegative trivial (nonnegative_annotation Γ).declared.2
  refine .V_Con rfl rfl nullary_kinds (by intro a ha; simp only [List.mem_cons,List.not_mem_nil,or_false] at ha; rcases ha with rfl | rfl <;> exact (nonnegative_annotation []).wf) ?_
    (record_annotation Γ (c := "Checked.Make") rfl rfl)
  have values := HasTypeVsQ.cons refineLo (.cons refineHi .nil)
  record_type_simp
  exact values

/-- 型付きの同じ内側recordを、不変欄の外側recordに格納する。 -/
theorem envelope_construct {B Ψ Γ Φ pair}
    (typed : HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ pair (.data "Checked" [])) :
    HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ (.con "Envelope.Make" [] [pair]) (.data "Envelope" []) := by
  refine .V_Con rfl rfl nullary_kinds (by intro a ha; cases List.mem_singleton.mp ha; trivial) ?_
    (record_annotation Γ (c := "Envelope.Make") rfl rfl)
  have values := HasTypeVsQ.cons typed HasTypeVsQ.nil
  record_type_simp
  exact values

def pairField : FieldRef := ⟨"Envelope","Envelope.Make",0,.data⟩
def loField : FieldRef := ⟨"Checked","Checked.Make",0,.integer⟩
def hiField : FieldRef := ⟨"Checked","Checked.Make",1,.integer⟩

def envelopeTerm (left right : Term) : Term :=
  .dataValue "Envelope.Make" [some (.dataValue "Checked.Make" [some left,some right])]

def constructedComparison (left right : Term) : Pred :=
  .le (.field loField (.field pairField (envelopeTerm left right)))
    (.field hiField (.field pairField (envelopeTerm left right)))

/-- 構築する式自身の欄を観測するための名目宣言。 -/
theorem constructed_declared (Γ : Ctx) (left right : Term)
    (hl : left.Declared recordProgram [] Γ) (hr : right.Declared recordProgram [] Γ) :
    (constructedComparison left right).Declared recordProgram [] Γ none := by
  have outer : Term.HasData recordProgram Γ (envelopeTerm left right) "Envelope" [] :=
    .value rfl rfl rfl rfl
  have inner : Term.HasData recordProgram Γ (.field pairField (envelopeTerm left right)) "Checked" [] :=
    .field outer rfl rfl rfl rfl trivial rfl rfl
  have declared : (envelopeTerm left right).Declared recordProgram [] Γ :=
    ⟨⟨⟨⟨hl,hr,trivial⟩,_,rfl,rfl⟩,trivial⟩,_,rfl,rfl⟩
  have pair : FieldRef.Declared recordProgram [] Γ (envelopeTerm left right) pairField :=
    ⟨[],_,_,outer,rfl,rfl,rfl,rfl,trivial,rfl⟩
  exact ⟨⟨⟨declared,pair⟩,[],_,_,inner,rfl,rfl,rfl,rfl,(nonnegative_annotation []).wf,rfl⟩,
    ⟨⟨declared,pair⟩,[],_,_,inner,rfl,rfl,rfl,rfl,(nonnegative_annotation []).wf,rfl⟩⟩

def wholePredicate : Pred :=
  .le (.field loField (.field pairField (.var 0))) (.field hiField (.field pairField (.var 0)))

def wholeType : Ty := .refined (.data "Envelope" []) wholePredicate

/-- 自己の二段の欄を持つ全体条件を、同じ表の宣言で形成する。 -/
theorem whole_annotation (Γ : Ctx) : Ty.Annotation recordProgram [] Γ wholeType := by
  have outer : Term.HasData recordProgram (Γ.extend (.data "Envelope" [])) (.var 0) "Envelope" [] :=
    .var rfl rfl
  have inner : Term.HasData recordProgram (Γ.extend (.data "Envelope" []))
      (.field pairField (.var 0)) "Checked" [] := .field outer rfl rfl rfl rfl trivial rfl rfl
  have pdecl : wholePredicate.Declared recordProgram [] Γ (some (.data "Envelope" [])) := by
    have hd : (Term.var 0).Declared recordProgram [] (Γ.extend (.data "Envelope" [])) := ⟨_,rfl,by intro b t e h; cases h⟩
    have pair : FieldRef.Declared recordProgram [] (Γ.extend (.data "Envelope" [])) (.var 0) pairField :=
      ⟨[],_,_,outer,rfl,rfl,rfl,rfl,trivial,rfl⟩
    exact ⟨⟨⟨hd,pair⟩,[],_,_,inner,rfl,rfl,rfl,rfl,(nonnegative_annotation []).wf,rfl⟩,
      ⟨⟨hd,pair⟩,[],_,_,inner,rfl,rfl,rfl,rfl,(nonnegative_annotation []).wf,rfl⟩⟩
  refine ⟨⟨trivial,?_,by intro b t e h; cases h⟩,⟨trivial,?_⟩,
    ⟨(record_annotation Γ (c := "Envelope.Make") rfl rfl).declared,pdecl⟩⟩
  · simp [wholePredicate,pairField,loField,hiField,Pred.WF,Pred.VarsIn,Term.VarsIn]
  · simp [wholePredicate,pairField,loField,hiField,Pred.Sorted,Term.HasSort,Term.References,
      Term.Shape,Term.VarsIn,Ctx.Readable,Ty.HasSort,Ty.sort?,Ty.core,Ordinary]

/-- Result の通常二引数を、同じ宣言の arity で形成する。 -/
theorem result_annotation (Γ : Ctx) (a b : Ty)
    (ha : Ty.Annotation recordProgram [] Γ a) (hb : Ty.Annotation recordProgram [] Γ b) :
    Ty.Annotation recordProgram [] Γ (.data "Result" [a,b]) :=
  ⟨⟨ha.wf,hb.wf,trivial⟩,⟨ha.sorted,hb.sorted,trivial⟩,⟨⟨2,result_arity,rfl⟩,ha.declared,hb.declared,trivial⟩⟩

/-- 最後の比較の型の事実を、その場で構築する同じ外側recordの篩へ入れる。 -/
theorem whole_construct {B Ψ Γ Φ lo hi tl th}
    (loTyped : HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ lo (.base .integer))
    (hiTyped : HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ hi (.base .integer))
    (loTerm : lo.toTerm? = some tl) (hiTerm : hi.toTerm? = some th)
    (loNonnegative : Entails (Γ.facts ++ Φ) (.le (.integer 0) tl))
    (hiNonnegative : Entails (Γ.facts ++ Φ) (.le (.integer 0) th))
    (whole : Entails (Γ.facts ++ Φ) (constructedComparison tl th)) :
    HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ
      (.con "Envelope.Make" [] [.con "Checked.Make" [] [lo,hi]]) wholeType := by
  have typed := envelope_construct (checked_construct loTyped hiTyped loTerm hiTerm loNonnegative hiNonnegative)
  apply HasTypeVQ.V_Refine typed rfl
    (show (Val.con "Envelope.Make" [] [.con "Checked.Make" [] [lo,hi]]).toTerm? = some (envelopeTerm tl th) by
      simp [Val.toTerm?,Val.toTermSlots,loTerm,hiTerm,envelopeTerm])
    (whole_annotation Γ).sorted.2 (whole_annotation Γ).wf.2.1 _
    (whole_annotation Γ).declared.1 (whole_annotation Γ).declared.2
  simpa [wholePredicate,constructedComparison,envelopeTerm,Pred.open,predBind,termBind,termBind?,bindSlots,slotBind] using whole

/-- 宣言と型付けを二段とも読み、同じ二欄の篩を回収する。 -/
theorem record_chain {B Ψ Γ Φ lo hi}
    (typed : HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ
      (.con "Envelope.Make" [] [.con "Checked.Make" [] [lo,hi]]) (.data "Envelope" [])) :
    HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ lo nonnegative ∧
    HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ hi nonnegative := by
  obtain ⟨v,hv,inner⟩ := typed.con_field_by_type (cd := ⟨"Envelope",0,[.data "Checked" []]⟩)
    rfl rfl (i := 0) rfl record_valid (by intro a h; cases h) (by intro a h; cases h)
  cases Option.some.inj hv
  obtain ⟨l,hl,lt⟩ := inner.con_field_by_type (cd := ⟨"Checked",0,[nonnegative,nonnegative]⟩)
    rfl rfl (i := 0) rfl record_valid (by intro a h; cases h) (by intro a h; cases h)
  obtain ⟨h,hh,ht⟩ := inner.con_field_by_type (cd := ⟨"Checked",0,[nonnegative,nonnegative]⟩)
    rfl rfl (i := 1) rfl record_valid (by intro a h; cases h) (by intro a h; cases h)
  cases Option.some.inj hl; cases Option.some.inj hh
  record_type_simp
  exact ⟨lt,ht⟩

example (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ recordProgram B Ψ Qempty [] [] [] (.const (.integer ⟨2,by decide⟩)) nonnegative ∧
    HasTypeVQ recordProgram B Ψ Qempty [] [] [] (.const (.integer ⟨5,by decide⟩)) nonnegative := by
  apply record_chain
  apply envelope_construct
  exact checked_construct (.V_Const trivial) (.V_Const trivial) rfl rfl
    (.integer_le (by decide)) (.integer_le (by decide))


/-- 原SourceのPerson.address（位置1）からAddress.city（位置0）への有限表の照合。 -/
example :
    Term.Declared recordProgram [] [some (.data "People.Person" [])]
      (.field ⟨"Address.Address","Address.Address.Make",0,.string⟩
        (.field ⟨"People.Person","People.Person.Make",1,.data⟩ (.var 0))) := by
  have person : Term.HasData recordProgram [some (.data "People.Person" [])]
      (.var 0) "People.Person" [] := .var rfl rfl
  have address : Term.HasData recordProgram [some (.data "People.Person" [])]
      (.field ⟨"People.Person","People.Person.Make",1,.data⟩ (.var 0)) "Address.Address" [] :=
    .field person rfl rfl rfl rfl trivial rfl rfl
  have source : Term.Declared recordProgram [] [some (.data "People.Person" [])] (.var 0) :=
    ⟨_,rfl,by intro b t e h; cases h⟩
  have first : FieldRef.Declared recordProgram [] [some (.data "People.Person" [])]
      (.var 0) ⟨"People.Person","People.Person.Make",1,.data⟩ :=
    ⟨[],_,_,person,rfl,rfl,rfl,rfl,trivial,rfl⟩
  exact ⟨⟨source,first⟩,[],_,_,address,rfl,rfl,rfl,rfl,trivial,rfl⟩

end
end Benitoite.Release.Refinement.StandardDecode
