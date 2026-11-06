import Benitoite.Release.Refinement.StandardDecodeComparison
import Benitoite.Release.Refinement.LocalTyping

/-! # decode 済みの Result に対する宣言順の検査本体 -/
namespace Benitoite.Release.Refinement.StandardDecode
noncomputable section
open StandardKeyTyping

private def errorType : Ty := .data "ConversionError" []
private def rawType : Ty := .data "Raw" []
private def inputType : Ty := .data "Result" [rawType,errorType]
private def outputType : Ty := .data "Result" [wholeType,errorType]

/-- 内部代表の制約違反。四欄と宣言位置を固定する。 -/
def constraintError (which : Nat) : Val :=
  .con "ConversionError.Make" [] [.list (if which = 0 then [.con "PathPart.Field" [] [.const (.string "lo")]]
    else if which = 1 then [.con "PathPart.Field" [] [.const (.string "hi")]] else []),
    .const (.string (if which < 2 then "nonnegative Integer" else "lo <= hi")),
    .const (.string "constraint violation"),.const (.string "record constraint failed")]

private def errorReturn (which : Nat) : Comp := .ret (.con "Result.Error" [wholeType,errorType] [constraintError which])
private def compareCode (left right : Val) : Comp := .app (.prim "%Integer.lessOrEqual" [] [] []) [left,right]
private def successful : Comp := .ret (.con "Result.Ok" [wholeType,errorType]
  [.con "Envelope.Make" [] [.con "Checked.Make" [] [.var 4,.var 3]]])

/-- Raw の lo/hi を束縛した後、欄0、欄1、全体の順にだけ検査する。 -/
def checksBody : Comp :=
  .letIn (compareCode (.const (.integer ⟨0,by decide⟩)) (.var 1))
    (.ite (.var 0)
      (.letIn (compareCode (.const (.integer ⟨0,by decide⟩)) (.var 1))
        (.ite (.var 0)
          (.letIn (compareCode (.var 3) (.var 2)) (.ite (.var 0) successful (errorReturn 2)))
          (errorReturn 1)))
      (errorReturn 0))

private def rawArm : Arm := .mk [⟨.con "Raw.Make" [.var,.var],[0,1]⟩] none checksBody
private def errorArm : Arm := .mk [⟨.con "Result.Error" [.var],[0]⟩] none
  (.ret (.con "Result.Error" [wholeType,errorType] [.var 0]))
private def okArm : Arm := .mk [⟨.con "Result.Ok" [.var],[0]⟩] none (.match (.var 0) [rawArm])

/-- 既に値となった通常decode結果から始める。任意decodeのRunsは前提にしない。 -/
def postprocessBody : Comp := .match (.var 0) [errorArm,okArm]

def postprocessRow : StandardContracts.Row :=
  ⟨"Internal.postprocessRecord",[],0,.param "decoded" inputType (.done outputType Eff.empty),
    some postprocessBody,.core,[.record,.decode]⟩

private theorem error_annotation (Γ : Ctx) : Ty.Annotation recordProgram [] Γ errorType :=
  record_annotation Γ (c := "ConversionError.Make") rfl rfl
private theorem raw_annotation (Γ : Ctx) : Ty.Annotation recordProgram [] Γ rawType :=
  record_annotation Γ (c := "Raw.Make") rfl rfl
private theorem output_annotation (Γ : Ctx) : Ty.Annotation recordProgram [] Γ outputType :=
  result_annotation Γ wholeType errorType (whole_annotation Γ) (error_annotation Γ)
private theorem input_annotation (Γ : Ctx) : Ty.Annotation recordProgram [] Γ inputType :=
  result_annotation Γ rawType errorType (raw_annotation Γ) (error_annotation Γ)

local macro "decode_simp" : tactic => `(tactic|
  simp_all [errorType,rawType,inputType,outputType,wholeType,wholePredicate,pairField,loField,hiField,
    nonnegative,comparisonType,comparisonPredicate,constructedComparison,envelopeTerm,boolCond,
    PrimSig.tel,Def.tel,signatureTel,Tel.names,Tel.inputs,Tel.result,Tel.effect,
    instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.bind,Ty.rawMapRanges,mapRangesTys,
    Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    predBind,termBind,termBind?,upValues,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
    Pred.conjuncts,Pred.ofConjuncts,Ty.core,Ty.shiftV,shiftVTys,bindSlots,slotBind,
    Ty.WF,Tel.WF,Ty.WFList,Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,
    Pred.WF,Pred.VarsIn,Pred.Sorted,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,
    varsInSlot,varsInSlots,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ty.NotContCore,
    Ctx.declarationSelf,Ctx.extend,Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,
    Qsig,QTy,QTys,QEff,QTel,Qempty,RowTransport,NoFail,Eff.test,Eff.atoms,Eff.fails,
    Eff.WF,Eff.Canonical,sortedEff,declaredEff,Comparison.Allowed,bindParams,
    localExtend,LocalCtx.extend,liftMany,Pred.lift,Ty.subst,Ty.substAt,substTypeAt,
    Tel.argumentsEnv,valEnv,Val.toTerm?,Val.toTermSlots])

private theorem comparison_result_annotation (Γ : Ctx) (left right : Term)
    (ls : left.HasSort (some (.base .boolean) :: Γ) .integer)
    (rs : right.HasSort (some (.base .boolean) :: Γ) .integer)
    (ld : left.Declared recordProgram [] (Γ.extend (.base .boolean)))
    (rd : right.Declared recordProgram [] (Γ.extend (.base .boolean))) :
    Ty.Annotation recordProgram [] Γ (comparisonType left right) := by
  have declared := constructed_declared (Γ.extend (.base .boolean)) left right ld rd
  have lw : termWF (Γ.length+1) left := Term.varsIn_mono ls.references
    (fun _ ⟨_,h,_⟩ => by have := (List.getElem?_eq_some_iff.mp h).1; simpa using this)
  have rw : termWF (Γ.length+1) right := Term.varsIn_mono rs.references
    (fun _ ⟨_,h,_⟩ => by have := (List.getElem?_eq_some_iff.mp h).1; simpa using this)
  refine ⟨?_,?_,?_⟩
  all_goals simp_all [comparisonType,comparisonPredicate,constructedComparison,envelopeTerm,
    pairField,loField,hiField,boolCond,Ty.WF,Ty.Sorted,Ty.Declared,Ty.NotContCore,
    Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,
    Term.References,Term.VarsIn,varsInSlot,varsInSlots,termWF,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,
    Ty.core,Ctx.declarationSelf,Ctx.extend,Ty.shiftV,Comparison.Allowed]

private theorem comparison_zero_typed {Ψ Γ Φ R Δ} (j : Nat)
    (hj : Γ[j]? = some (some (.base .integer))) :
    HasTypeCQ recordProgram recordBuiltins Ψ Qempty [] Γ Φ R
      (compareCode (.const (.integer ⟨0,by decide⟩)) (.var j))
      (comparisonType (.integer 0) (.var (j+1))) Eff.empty Δ := by
  have hs : (Term.var (j+1)).HasSort (some (.base .boolean) :: Γ) .integer := by
    simp [Term.HasSort,Term.References,Term.Shape,Term.VarsIn,Ctx.Readable,hj,Ty.HasSort,Ty.sort?,Ordinary,Ty.core]
  have hd : (Term.var (j+1)).Declared recordProgram [] (Γ.extend (.base .boolean)) := by
    exact ⟨.base .integer,by simp [Ctx.extend,List.getElem?_map,hj,Ty.shiftV],by intro b t e h; cases h⟩
  have ann := comparison_result_annotation Γ (.integer 0) (.var (j+1)) ⟨trivial,rfl⟩ hs trivial hd
  apply HasTypeCQ.C_DependentApp comparison_function
  refine .param ⟨trivial,trivial,trivial⟩ (.V_Const trivial) ?_
  decode_simp
  refine .param ⟨trivial,trivial,trivial⟩ (.V_Var hj (by intro b t e h; cases h)) ?_
  decode_simp
  exact .done ⟨⟨ann.wf,trivial,rfl⟩,⟨ann.sorted,trivial⟩,⟨ann.declared,trivial⟩⟩

private theorem comparison_vars_typed {Ψ Γ Φ R Δ} (i j : Nat)
    (hi : Γ[i]? = some (some (.base .integer))) (hj : Γ[j]? = some (some (.base .integer))) :
    HasTypeCQ recordProgram recordBuiltins Ψ Qempty [] Γ Φ R
      (compareCode (.var i) (.var j))
      (comparisonType (.var (i+1)) (.var (j+1))) Eff.empty Δ := by
  have hs (k : Nat) (hk : Γ[k]? = some (some (.base .integer))) :
      (Term.var (k+1)).HasSort (some (.base .boolean) :: Γ) .integer := by
    simp [Term.HasSort,Term.References,Term.Shape,Term.VarsIn,Ctx.Readable,hk,Ty.HasSort,Ty.sort?,Ordinary,Ty.core]
  have hd (k : Nat) (hk : Γ[k]? = some (some (.base .integer))) :
      (Term.var (k+1)).Declared recordProgram [] (Γ.extend (.base .boolean)) :=
    ⟨.base .integer,by simp [Ctx.extend,List.getElem?_map,hk,Ty.shiftV],by intro b t e h; cases h⟩
  have ann := comparison_result_annotation Γ (.var (i+1)) (.var (j+1)) (hs i hi) (hs j hj) (hd i hi) (hd j hj)
  apply HasTypeCQ.C_DependentApp comparison_function
  refine .param ⟨trivial,trivial,trivial⟩ (.V_Var hi (by intro b t e h; cases h)) ?_
  decode_simp
  refine .param ⟨trivial,trivial,trivial⟩ (.V_Var hj (by intro b t e h; cases h)) ?_
  decode_simp
  exact .done ⟨⟨ann.wf,trivial,rfl⟩,⟨ann.sorted,trivial⟩,⟨ann.declared,trivial⟩⟩

private theorem result_kinds : TypeArgsKinded recordProgram [] [wholeType,errorType] [.value,.value] := by
  refine ⟨rfl,?_⟩
  rintro (_|(_|i)) t k ht hk
  · cases Option.some.inj ht; cases Option.some.inj hk
    exact ⟨⟨record_kind (c := "Envelope.Make") rfl rfl,by intro b t e h; cases h⟩,by intro _ b t e h; cases h⟩
  · cases Option.some.inj ht; cases Option.some.inj hk
    exact ⟨record_kind (c := "ConversionError.Make") rfl rfl,by intro _ b t e h; cases h⟩
  · simp at ht

private theorem result_ok {Ψ Γ Φ value}
    (typed : HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] Γ Φ value wholeType) :
    HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] Γ Φ
      (.con "Result.Ok" [wholeType,errorType] [value]) outputType := by
  refine .V_Con (cd := ⟨"Result",2,[.tvar 0]⟩) rfl rfl result_kinds (by intro a ha; cases List.mem_singleton.mp ha; simp [Ty.WF]) ?_ (output_annotation Γ)
  have values := HasTypeVsQ.cons typed HasTypeVsQ.nil
  decode_simp

private theorem result_error {Ψ Γ Φ value}
    (typed : HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] Γ Φ value errorType) :
    HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] Γ Φ
      (.con "Result.Error" [wholeType,errorType] [value]) outputType := by
  refine .V_Con (cd := ⟨"Result",2,[.tvar 1]⟩) rfl rfl result_kinds (by intro a ha; cases List.mem_singleton.mp ha; simp [Ty.WF]) ?_ (output_annotation Γ)
  have values := HasTypeVsQ.cons typed HasTypeVsQ.nil
  decode_simp

private theorem constraint_error_typed {Ψ Γ Φ} (which : Nat) :
    HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] Γ Φ (constraintError which) errorType := by
  have pathAnn := record_annotation Γ (c := "PathPart.Field") rfl rfl
  have field (key : String) : HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] Γ Φ
      (.con "PathPart.Field" [] [.const (.string key)]) (.data "PathPart" []) := by
    refine .V_Con (cd := ⟨"PathPart",0,[.base .string]⟩) rfl rfl ⟨rfl,by intro i t k h; cases h⟩
      (by intro a h; cases List.mem_singleton.mp h; trivial) ?_ pathAnn
    exact .cons (.V_Const trivial) .nil
  apply HasTypeVQ.V_Con (cd := ⟨"ConversionError",0,[.list (.data "PathPart" []),.base .string,.base .string,.base .string]⟩)
    rfl rfl ⟨rfl,by intro i t k h; cases h⟩
    (by intro a h; simp only [List.mem_cons,List.not_mem_nil,or_false] at h; rcases h with rfl | rfl | rfl | rfl <;> trivial)
    _ (error_annotation Γ)
  have hp : HasTypeEachQ recordProgram recordBuiltins Ψ Qempty [] Γ Φ
      (if which = 0 then [.con "PathPart.Field" [] [.const (.string "lo")]]
        else if which = 1 then [.con "PathPart.Field" [] [.const (.string "hi")]] else []) (.data "PathPart" []) := by
    split
    · exact .cons (field _) .nil
    · split
      · exact .cons (field _) .nil
      · exact .nil
  have values := HasTypeVsQ.cons (HasTypeVQ.V_List hp pathAnn.wf pathAnn.sorted pathAnn.declared)
    (.cons (.V_Const (c := .string (if which < 2 then "nonnegative Integer" else "lo <= hi")) trivial)
      (.cons (.V_Const (c := .string "constraint violation") trivial)
        (.cons (.V_Const (c := .string "record constraint failed") trivial) .nil)))
  change HasTypeVsQ _ _ _ _ _ _ _ _ _
  simpa only [List.map_cons,List.map_nil,Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,
    Ty.norm,Ty.normTys,rawBindTys,typeEnvAt,Const.type] using values

private theorem error_return_typed {Ψ Γ Φ R Δ} (which : Nat) :
    HasTypeCQ recordProgram recordBuiltins Ψ Qempty [] Γ Φ R (errorReturn which) outputType Eff.empty Δ :=
  .C_Return (result_error (constraint_error_typed which))

private def rawContext : Ctx := [some (.base .integer),some (.base .integer),some rawType,some inputType]
private def loContext : Ctx := rawContext.extend (comparisonType (.integer 0) (.var 2))
private def hiContext : Ctx := loContext.extend (comparisonType (.integer 0) (.var 2))
private def wholeContext : Ctx := hiContext.extend (comparisonType (.var 4) (.var 3))
private def wholeFacts : List Pred := [boolCond (.var 0) true,boolCond (.var 1) true,boolCond (.var 2) true]

private theorem successful_typed {Ψ R Δ} :
    HasTypeCQ recordProgram recordBuiltins Ψ Qempty [] wholeContext wholeFacts R successful outputType Eff.empty Δ := by
  apply HasTypeCQ.C_Return
  apply result_ok
  have loTyped : HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] wholeContext wholeFacts
      (.var 4) (.base .integer) := .V_Var rfl (by intro b t e h; cases h)
  have hiTyped : HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] wholeContext wholeFacts
      (.var 3) (.base .integer) := .V_Var rfl (by intro b t e h; cases h)
  have checkLo : HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] wholeContext wholeFacts
      (.var 2) (comparisonType (.integer 0) (.var 5)) := .V_Var rfl (by intro b t e h; cases h)
  have checkHi : HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] wholeContext wholeFacts
      (.var 1) (comparisonType (.integer 0) (.var 4)) := .V_Var rfl (by intro b t e h; cases h)
  have checkWhole : HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] wholeContext wholeFacts
      (.var 0) (comparisonType (.var 5) (.var 4)) := .V_Var rfl (by intro b t e h; cases h)
  have factLo := comparison_true (comparison_known checkLo rfl)
    (Entails.hyp (List.mem_append_right _ (by simp [wholeFacts])))
  have factHi := comparison_true (comparison_known checkHi rfl)
    (Entails.hyp (List.mem_append_right _ (by simp [wholeFacts])))
  have factWhole := comparison_whole_true (comparison_known checkWhole rfl)
    (Entails.hyp (List.mem_append_right _ (by simp [wholeFacts])))
  exact whole_construct loTyped hiTyped rfl rfl factLo factHi (by
    simpa [constructedComparison,envelopeTerm,Pred.open,predBind,termBind,termBind?,bindSlots,slotBind] using factWhole)

private theorem boolean_check {Ψ Γ Φ i left right}
    (h : Γ[i]? = some (some (comparisonType left right))) :
    HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] Γ Φ (.var i) (.base .boolean) :=
  .V_Sub (.V_Var h (by intro b t e h; cases h)) .forget trivial trivial trivial

private theorem checks_locals_typed (Ψ : StoreTy) (Δ : LocalCtx) :
    HasTypeCQ recordProgram recordBuiltins Ψ Qempty [] rawContext [] (some outputType)
      checksBody outputType Eff.empty Δ := by
  refine .C_Let (comparison_zero_typed 1 rfl) ?_ (output_annotation rawContext).declared
  change HasTypeCQ _ _ _ _ _ loContext [] (some outputType) _ outputType Eff.empty (localExtend 1 Δ)
  refine .C_If (boolean_check (left := .integer 0) (right := .var 3) rfl) rfl ?_ (error_return_typed 0)
  refine .C_Let (comparison_zero_typed 1 rfl) ?_ (output_annotation loContext).declared
  change HasTypeCQ _ _ _ _ _ hiContext [boolCond (.var 1) true] (some outputType) _ outputType Eff.empty (localExtend 2 Δ)
  refine .C_If (boolean_check (left := .integer 0) (right := .var 3) rfl) rfl ?_ (error_return_typed 1)
  refine .C_Let (comparison_vars_typed 3 2 rfl rfl) ?_ (output_annotation hiContext).declared
  change HasTypeCQ _ _ _ _ _ wholeContext [boolCond (.var 1) true,boolCond (.var 2) true]
    (some outputType) _ outputType Eff.empty (localExtend 3 Δ)
  exact .C_If (boolean_check (left := .var 5) (right := .var 4) rfl) rfl successful_typed (error_return_typed 2)


/-- 実際の C_Let/C_If 三組が、同じ欄値と全体条件を成功型へ渡す。 -/
theorem checks_typed (Ψ : StoreTy) :
    HasTypeCQ recordProgram recordBuiltins Ψ Qempty [] rawContext [] (some outputType)
      checksBody outputType Eff.empty [] := checks_locals_typed Ψ []

private theorem single_alternative {c cd ts ps δ}
    (hc : recordProgram.cons c = some cd) (hn : ts.length = cd.ntys)
    (hw : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0)
    (hp : PatTys recordProgram ps (cd.args.map (Ty.subst ts [])) δ)
    (hb : Pat.bindersList ps = δ.length)
    (hs : selectSlots δ (List.range δ.length) = some δ) :
    AltsTy recordProgram [⟨.con c ps,List.range δ.length⟩] (.data cd.data ts) δ := by
  refine ⟨by simp,by simp [Arm.bindersOf,Pat.binders,hb],?_,?_⟩
  · intro alt h; cases Option.some.inj h
    simpa [Pat.binders] using congrArg List.range hb.symm
  · intro alt h; cases List.mem_singleton.mp h
    exact ⟨δ,.P_Con hc hn hw hp,List.Perm.refl _,hs⟩

private theorem result_error_alt :
    AltsTy recordProgram [⟨.con "Result.Error" [.var],[0]⟩] inputType [errorType] := by
  have h := single_alternative (c := "Result.Error") (cd := ⟨"Result",2,[.tvar 1]⟩)
    (ts := [rawType,errorType]) rfl rfl
    (by intro a ha; cases List.mem_singleton.mp ha; simp [Ty.WF])
    (by decode_simp; exact .cons .P_Var .nil) rfl rfl
  exact h

private theorem result_ok_alt :
    AltsTy recordProgram [⟨.con "Result.Ok" [.var],[0]⟩] inputType [rawType] := by
  have h := single_alternative (c := "Result.Ok") (cd := ⟨"Result",2,[.tvar 0]⟩)
    (ts := [rawType,errorType]) rfl rfl
    (by intro a ha; cases List.mem_singleton.mp ha; simp [Ty.WF])
    (by decode_simp; exact .cons .P_Var .nil) rfl rfl
  exact h

private theorem raw_alt : AltsTy recordProgram [⟨.con "Raw.Make" [.var,.var],[0,1]⟩]
    rawType [.base .integer,.base .integer] := by
  have h := single_alternative (c := "Raw.Make") (cd := ⟨"Raw",0,[.base .integer,.base .integer]⟩)
    (ts := []) rfl rfl
    (by intro a ha; simp only [List.mem_cons,List.not_mem_nil,or_false] at ha
        rcases ha with rfl | rfl <;> trivial)
    (by decode_simp; exact .cons .P_Var (.cons .P_Var .nil)) rfl rfl
  exact h

private theorem record_cons_members {c cd} (hc : recordProgram.cons c = some cd) :
    (c,cd) ∈ recordDeclarations.flatMap DataDecl.entries := by
  obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp hc
  rw [eq]
  exact List.mem_append_right _ (List.mem_cons_self ..)

private theorem result_only {c cd} (hc : recordProgram.cons c = some cd) (ho : cd.data = "Result") :
    c = "Result.Error" ∨ c = "Result.Ok" := by
  have hm := record_cons_members hc
  simp only [recordDeclarations,List.flatMap_cons,List.flatMap_nil,DataDecl.entries,
    List.map_cons,List.map_nil,List.nil_append,List.cons_append,
    List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at hm
  rcases hm with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals simp_all

private theorem raw_only {c cd} (hc : recordProgram.cons c = some cd) (ho : cd.data = "Raw") :
    c = "Raw.Make" := by
  have hm := record_cons_members hc
  simp only [recordDeclarations,List.flatMap_cons,List.flatMap_nil,DataDecl.entries,
    List.map_cons,List.map_nil,List.nil_append,List.cons_append,
    List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at hm
  rcases hm with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals simp_all

private theorem result_exhaustive : Exhaustive recordProgram inputType
    [.con "Result.Error" [.var],.con "Result.Ok" [.var]] := by
  intro v inhabitant
  have aux : ∀ t v, Inhabits recordProgram t v → t = inputType.norm →
      ∃ p ∈ [Pat.con "Result.Error" [.var],.con "Result.Ok" [.var]], (matchVal p v).isSome := by
    intro t v h eq
    cases h <;> try (solve | cases eq)
    case const c => cases c <;> cases eq
    case atError => simp [inputType,rawType,errorType,atErrorType,Ty.norm,Ty.normTys] at eq
    case con c ts tys args cd lookup ntys wf fields =>
      have owner : cd.data = "Result" := (Ty.data.inj eq).1
      rcases result_only lookup owner with hc | hc
      · subst c
        have hd := Option.some.inj (lookup.symm.trans (show recordProgram.cons "Result.Error" = some ⟨"Result",2,[.tvar 1]⟩ from rfl))
        subst cd
        cases fields with
        | cons value rest =>
          cases rest
          exact ⟨.con "Result.Error" [.var],by simp,by simp [matchVal,matchList]⟩
      · subst c
        have hd := Option.some.inj (lookup.symm.trans (show recordProgram.cons "Result.Ok" = some ⟨"Result",2,[.tvar 0]⟩ from rfl))
        subst cd
        cases fields with
        | cons value rest =>
          cases rest
          exact ⟨.con "Result.Ok" [.var],by simp,by simp [matchVal,matchList]⟩
  exact aux _ _ inhabitant rfl

private theorem raw_exhaustive : Exhaustive recordProgram rawType [.con "Raw.Make" [.var,.var]] := by
  intro v inhabitant
  have aux : ∀ t v, Inhabits recordProgram t v → t = rawType.norm →
      ∃ p ∈ [Pat.con "Raw.Make" [.var,.var]], (matchVal p v).isSome := by
    intro t v h eq
    cases h <;> try (solve | cases eq)
    case const c => cases c <;> cases eq
    case atError => simp [rawType,atErrorType,Ty.norm] at eq
    case con c ts tys args cd lookup ntys wf fields =>
      have owner : cd.data = "Raw" := (Ty.data.inj eq).1
      have hc := raw_only lookup owner
      subst c
      have hd := Option.some.inj (lookup.symm.trans (show recordProgram.cons "Raw.Make" = some ⟨"Raw",0,[.base .integer,.base .integer]⟩ from rfl))
      subst cd
      cases fields with
      | cons lo rest =>
        cases rest with
        | cons hi rest =>
          cases rest
          exact ⟨.con "Raw.Make" [.var,.var],by simp,by simp [matchVal,matchList]⟩
  exact aux _ _ inhabitant rfl

/-- 通常decode済みのResultを分解し、失敗の同じpayload又は三つの追加検査へ進む。 -/
theorem postprocess_typed (Ψ : StoreTy) :
    HasTypeCQ recordProgram recordBuiltins Ψ Qempty [] [some inputType] [] (some outputType)
      postprocessBody outputType Eff.empty [] := by
  dsimp only [postprocessBody,errorArm,okArm,rawArm]
  apply HasTypeCQ.C_Match (obs := none) (a := inputType)
  · exact .V_Var rfl (by intro b t e h; cases h)
  · intro t h; cases h
  · apply HasTypeArmsQ.plainEmpty result_error_alt (by simp [pathFacts,FactsWF])
    · apply HasTypeCQ.C_Return
      apply result_error
      exact .V_Var (by decode_simp) (by intro b t e h; cases h)
    · apply HasTypeArmsQ.plainEmpty result_ok_alt (by simp [pathFacts,FactsWF])
      · apply HasTypeCQ.C_Match (obs := none) (a := rawType)
        · exact .V_Var (by decode_simp) (by intro b t e h; cases h)
        · intro t h; cases h
        · apply HasTypeArmsQ.plainEmpty raw_alt (by simp [pathFacts,FactsWF])
          · change HasTypeCQ recordProgram recordBuiltins Ψ Qempty [] rawContext []
              (some outputType) checksBody outputType Eff.empty (localExtend 3 [])
            exact checks_locals_typed Ψ _
          · apply HasTypeArmsQ.nil; exact output_annotation _
        · exact (raw_annotation _).declared
        · simpa [unguardedPats,rawArm,Ty.shiftV,shiftVTys,rawType] using raw_exhaustive
      · apply HasTypeArmsQ.nil; exact output_annotation _
  · exact (input_annotation _).declared
  · simpa [postprocessBody,unguardedPats,errorArm,okArm] using result_exhaustive


/-- 後処理の同じRowから得る一引数の宣言。通常decoderの登録は含めない。 -/
def postprocessDefinition : Def :=
  ⟨[],0,["decoded"],[inputType],outputType,Eff.empty,postprocessBody, []⟩

private theorem postprocess_annotation :
    Ty.Annotation recordProgram [] [] (.dependentFn postprocessDefinition.tel) := by
  have ai := input_annotation []
  have ao := output_annotation (Ctx.extend [] inputType)
  refine ⟨⟨ai.wf,ao.wf,?_⟩,⟨ai.sorted,ao.sorted,?_⟩,⟨ai.declared,ao.declared,?_⟩⟩
  all_goals simp [postprocessDefinition,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,sortedEff,declaredEff,declaredTys,Ty.WFList,sortedTys]

/-- 任意decodeの実行証拠を使わず、実CompのTelBodyTyから同じDefを検査する。 -/
theorem postprocess_wellTyped : postprocessDefinition.WellTyped recordProgram recordBuiltins := by
  refine ⟨?_,?_,⟨postprocess_annotation.wf,postprocess_annotation.sorted,postprocess_annotation.declared⟩,?_⟩
  · exact ⟨rfl,by decide⟩
  · have hi := result_kind rawType errorType (record_kind (c := "Raw.Make") rfl rfl)
      (record_kind (c := "ConversionError.Make") rfl rfl)
    have ho := result_kind wholeType errorType
      ⟨record_kind (c := "Envelope.Make") rfl rfl,by intro b t e h; cases h⟩
      (record_kind (c := "ConversionError.Make") rfl rfl)
    simpa [postprocessDefinition,Def.tel,signatureTel,Ty.HasKind,kindsTel,kindsEff,TypeCtx.kinds,Eff.empty,inputType,outputType,kindsList] using And.intro hi (And.intro ho trivial)
  · change TelBodyTy _ _ _ _ _ _ _ _ _
    apply TelBodyTy.param
    apply TelBodyTy.done
    have h := postprocess_typed StoreTy.empty
    change HasTypeCQ recordProgram recordBuiltins StoreTy.empty (QTel postprocessDefinition.tel) []
      (Ctx.extend [] inputType) [] (some outputType) postprocessBody outputType Eff.empty []
    have hq : QTel postprocessDefinition.tel = Qempty := by
      funext i; apply propext
      simp [postprocessDefinition,Def.tel,signatureTel,QTel,QTy,QTys,QEff,Qempty,
        inputType,outputType,rawType,errorType,wholeType,Eff.empty]
    rw [hq]
    simpa [Qempty,
      inputType,outputType,rawType,errorType,wholeType,wholePredicate,Eff.empty,
      Ctx.extend,Ty.shiftV,shiftVTys] using h

/-- 同じ署名・本体を持つRowのBodyTyped。通常decodeとの接続は別の義務である。 -/
theorem postprocess_row_typed : postprocessRow.BodyTyped recordProgram recordBuiltins :=
  ⟨postprocessDefinition,rfl,postprocess_wellTyped⟩

example : postprocessDefinition.tel = postprocessRow.tel :=
  StandardContracts.Row.definition_tel (show postprocessRow.definition = some postprocessDefinition from rfl)
example : postprocessRow.BodyTyped recordProgram recordBuiltins := postprocess_row_typed


/-- 通常decodeのErrorは追加比較へ進まず、同じpayloadをそのまま返す。 -/
theorem postprocess_error_steps {σ} (payload : Val) (k : Cont) (μ : Store) :
    ∃ q, Steps recordProgram recordBuiltins σ
      (.run (.mk (Capture.empty.extend (.con "Result.Error" [rawType,errorType] [payload])) postprocessBody) k μ) []
      (.run q k μ) ∧ q.view = .ret (.con "Result.Error" [wholeType,errorType] [payload]) := by
  refine ⟨_,.cons (.E_Match rfl) (.cons (.E_MatchBody rfl rfl) .nil),rfl⟩

private def rawCapture (lo hi : Integer64Value) : Capture :=
  let raw := Val.con "Raw.Make" [] [.const (.integer lo),.const (.integer hi)]
  ((Capture.empty.extend (.con "Result.Ok" [rawType,errorType] [raw])).extend raw).extendMany
    [.const (.integer lo),.const (.integer hi)]

/-- Okの同じRaw二欄だけを捕捉し、欄0の最初の比較へ進む。 -/
theorem postprocess_raw_steps {σ} (lo hi : Integer64Value) (k : Cont) (μ : Store) :
    Steps recordProgram recordBuiltins σ
      (.run (.mk (Capture.empty.extend (.con "Result.Ok" [rawType,errorType]
        [.con "Raw.Make" [] [.const (.integer lo),.const (.integer hi)]])) postprocessBody) k μ) []
      (.run (.mk (rawCapture lo hi) checksBody) k μ) := by
  exact .cons (.E_Match rfl) (.cons (.E_MatchSkip rfl rfl)
    (.cons (.E_MatchBody rfl rfl) (.cons (.E_Match rfl) (.cons (.E_MatchBody rfl rfl) .nil))))

/-- Sourceのprependと同じ四欄の構成。先頭のpath要素以外を保持する。 -/
def prependError (part : Val) (path : List Val) (expected found reason : String) : Val :=
  .con "ConversionError.Make" [] [.list (part :: path),.const (.string expected),
    .const (.string found),.const (.string reason)]

example (key : String) (path : List Val) (expected found reason : String) :
    prependError (.con "PathPart.Field" [] [.const (.string key)]) path expected found reason =
      .con "ConversionError.Make" []
        [.list (.con "PathPart.Field" [] [.const (.string key)] :: path),
          .const (.string expected),.const (.string found),.const (.string reason)] := rfl
example (key : String) (path : List Val) (expected found reason : String) :
    prependError (.con "PathPart.Key" [] [.const (.string key)]) path expected found reason =
      .con "ConversionError.Make" []
        [.list (.con "PathPart.Key" [] [.const (.string key)] :: path),
          .const (.string expected),.const (.string found),.const (.string reason)] := rfl

example : constraintError 0 = .con "ConversionError.Make" []
    [.list [.con "PathPart.Field" [] [.const (.string "lo")]],
      .const (.string "nonnegative Integer"),.const (.string "constraint violation"),
      .const (.string "record constraint failed")] := rfl
example : constraintError 1 = .con "ConversionError.Make" []
    [.list [.con "PathPart.Field" [] [.const (.string "hi")]],
      .const (.string "nonnegative Integer"),.const (.string "constraint violation"),
      .const (.string "record constraint failed")] := rfl
example : constraintError 2 = .con "ConversionError.Make" []
    [.list [],.const (.string "lo <= hi"),.const (.string "constraint violation"),
      .const (.string "record constraint failed")] := rfl

example {σ} (key : String) (path : List Val) (expected found reason : String) (k : Cont) (μ : Store) :
    ∃ q, Steps recordProgram recordBuiltins σ
      (.run (.mk (Capture.empty.extend (.con "Result.Error" [rawType,errorType]
        [prependError (.con "PathPart.Field" [] [.const (.string key)]) path expected found reason])) postprocessBody) k μ) []
      (.run q k μ) ∧ q.view = .ret (.con "Result.Error" [wholeType,errorType]
        [prependError (.con "PathPart.Field" [] [.const (.string key)]) path expected found reason]) :=
  postprocess_error_steps _ k μ


private theorem first_failure_steps {σ} (k : Cont) (μ : Store) :
    ∃ q, Steps recordProgram recordBuiltins σ
      (.run (.mk (rawCapture ⟨-1,by decide⟩ ⟨-2,by decide⟩) checksBody) k μ) [] (.run q k μ) ∧
      q.view = .ret (.con "Result.Error" [wholeType,errorType] [constraintError 0]) := by
  refine ⟨_,.cons (.E_Let rfl) (.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl rfl)
    (.cons (.E_Return rfl) (.cons (.E_IfF rfl) .nil))),rfl⟩

private theorem second_failure_steps {σ} (k : Cont) (μ : Store) :
    ∃ q, Steps recordProgram recordBuiltins σ
      (.run (.mk (rawCapture ⟨2,by decide⟩ ⟨-1,by decide⟩) checksBody) k μ) [] (.run q k μ) ∧
      q.view = .ret (.con "Result.Error" [wholeType,errorType] [constraintError 1]) := by
  refine ⟨_,.cons (.E_Let rfl) (.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl rfl)
    (.cons (.E_Return rfl) (.cons (.E_IfT rfl)
      (.cons (.E_Let rfl) (.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl rfl)
        (.cons (.E_Return rfl) (.cons (.E_IfF rfl) .nil))))))),rfl⟩

private theorem whole_failure_steps {σ} (k : Cont) (μ : Store) :
    ∃ q, Steps recordProgram recordBuiltins σ
      (.run (.mk (rawCapture ⟨5,by decide⟩ ⟨2,by decide⟩) checksBody) k μ) [] (.run q k μ) ∧
      q.view = .ret (.con "Result.Error" [wholeType,errorType] [constraintError 2]) := by
  refine ⟨_,.cons (.E_Let rfl) (.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl rfl)
    (.cons (.E_Return rfl) (.cons (.E_IfT rfl)
      (.cons (.E_Let rfl) (.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl rfl)
        (.cons (.E_Return rfl) (.cons (.E_IfT rfl)
          (.cons (.E_Let rfl) (.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl rfl)
            (.cons (.E_Return rfl) (.cons (.E_IfF rfl) .nil))))))))))),rfl⟩

private theorem successful_steps {σ} (k : Cont) (μ : Store) :
    ∃ q, Steps recordProgram recordBuiltins σ
      (.run (.mk (rawCapture ⟨2,by decide⟩ ⟨5,by decide⟩) checksBody) k μ) [] (.run q k μ) ∧
      q.view = .ret (.con "Result.Ok" [wholeType,errorType]
        [.con "Envelope.Make" [] [.con "Checked.Make" [] [.const (.integer ⟨2,by decide⟩),.const (.integer ⟨5,by decide⟩)]]]) := by
  refine ⟨_,.cons (.E_Let rfl) (.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl rfl)
    (.cons (.E_Return rfl) (.cons (.E_IfT rfl)
      (.cons (.E_Let rfl) (.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl rfl)
        (.cons (.E_Return rfl) (.cons (.E_IfT rfl)
          (.cons (.E_Let rfl) (.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl rfl)
            (.cons (.E_Return rfl) (.cons (.E_IfT rfl) .nil))))))))))),rfl⟩


private theorem steps_follow {P B σ s t u es fs}
    (first : Steps P B σ s es t) (next : Steps P B σ t fs u) :
    Steps P B σ s (es ++ fs) u := by
  induction first with
  | nil => exact next
  | cons step rest ih => simpa [List.append_assoc] using Steps.cons step (ih next)

private theorem postprocess_concrete {σ} (lo hi : Integer64Value) (result : Val) (k : Cont) (μ : Store)
    (body : ∃ q, Steps recordProgram recordBuiltins σ
      (.run (.mk (rawCapture lo hi) checksBody) k μ) [] (.run q k μ) ∧ q.view = .ret result) :
    ∃ q, Steps recordProgram recordBuiltins σ
      (.run (.mk (Capture.empty.extend (.con "Result.Ok" [rawType,errorType]
        [.con "Raw.Make" [] [.const (.integer lo),.const (.integer hi)]])) postprocessBody) k μ) []
      (.run q k μ) ∧ q.view = .ret result := by
  obtain ⟨q,hq,hv⟩ := body
  exact ⟨q,steps_follow (postprocess_raw_steps lo hi k μ) hq,hv⟩

/-- 二欄とも違反するとき、同じ本体は最初のloのErrorを返す。 -/
example {σ} (k : Cont) (μ : Store) :
    ∃ q, Steps recordProgram recordBuiltins σ
      (.run (.mk (Capture.empty.extend (.con "Result.Ok" [rawType,errorType]
        [.con "Raw.Make" [] [.const (.integer ⟨-1,by decide⟩),.const (.integer ⟨-2,by decide⟩)]])) postprocessBody) k μ) []
      (.run q k μ) ∧ q.view = .ret (.con "Result.Error" [wholeType,errorType] [constraintError 0]) :=
  postprocess_concrete _ _ _ k μ (first_failure_steps k μ)

/-- loを通過した同じ本体のhi失敗。 -/
example {σ} (k : Cont) (μ : Store) :
    ∃ q, Steps recordProgram recordBuiltins σ
      (.run (.mk (Capture.empty.extend (.con "Result.Ok" [rawType,errorType]
        [.con "Raw.Make" [] [.const (.integer ⟨2,by decide⟩),.const (.integer ⟨-1,by decide⟩)]])) postprocessBody) k μ) []
      (.run q k μ) ∧ q.view = .ret (.con "Result.Error" [wholeType,errorType] [constraintError 1]) :=
  postprocess_concrete _ _ _ k μ (second_failure_steps k μ)

/-- 両欄を通過してからだけ全体条件のErrorへ進む。 -/
example {σ} (k : Cont) (μ : Store) :
    ∃ q, Steps recordProgram recordBuiltins σ
      (.run (.mk (Capture.empty.extend (.con "Result.Ok" [rawType,errorType]
        [.con "Raw.Make" [] [.const (.integer ⟨5,by decide⟩),.const (.integer ⟨2,by decide⟩)]])) postprocessBody) k μ) []
      (.run q k μ) ∧ q.view = .ret (.con "Result.Error" [wholeType,errorType] [constraintError 2]) :=
  postprocess_concrete _ _ _ k μ (whole_failure_steps k μ)

/-- 成功した同じ二欄をChecked/Envelopeへ格納する。 -/
example {σ} (k : Cont) (μ : Store) :
    ∃ q, Steps recordProgram recordBuiltins σ
      (.run (.mk (Capture.empty.extend (.con "Result.Ok" [rawType,errorType]
        [.con "Raw.Make" [] [.const (.integer ⟨2,by decide⟩),.const (.integer ⟨5,by decide⟩)]])) postprocessBody) k μ) []
      (.run q k μ) ∧ q.view = .ret (.con "Result.Ok" [wholeType,errorType]
        [.con "Envelope.Make" [] [.con "Checked.Make" [] [.const (.integer ⟨2,by decide⟩),.const (.integer ⟨5,by decide⟩)]]]) :=
  postprocess_concrete _ _ _ k μ (successful_steps k μ)

example (Ψ : StoreTy) :
    HasTypeCQ recordProgram recordBuiltins Ψ Qempty [] rawContext [] (some outputType)
      checksBody outputType Eff.empty [] := checks_typed Ψ

/-- 通常decodeの同じ二整数から、宣言順の最初の違反又は構築値を選ぶ。 -/
def checkedRawResult (lo hi : Integer64Value) : Val :=
  if 0≤lo.toInt then
    if 0≤hi.toInt then
      if lo.toInt≤hi.toInt then .con "Result.Ok" [wholeType,errorType]
        [.con "Envelope.Make" [] [.con "Checked.Make" [] [.const (.integer lo),.const (.integer hi)]]]
      else .con "Result.Error" [wholeType,errorType] [constraintError 2]
    else .con "Result.Error" [wholeType,errorType] [constraintError 1]
  else .con "Result.Error" [wholeType,errorType] [constraintError 0]

/-- 入力Resultのpayloadと二欄の同一性。型注釈の表現には依存しない。 -/
inductive DecodeResult : Val → Val → Prop where
  | error (ts : List Ty) (payload : Val) :
      DecodeResult (.con "Result.Error" ts [payload]) (.con "Result.Error" [wholeType,errorType] [payload])
  | raw (ts us : List Ty) (lo hi : Integer64Value) :
      DecodeResult (.con "Result.Ok" ts [.con "Raw.Make" us [.const (.integer lo),.const (.integer hi)]])
        (checkedRawResult lo hi)

private theorem comparison_boolean (left right : Integer64Value) :
    recordBuiltins.delta "%Integer.lessOrEqual" [] [] [] [.const (.integer left),.const (.integer right)]=
      some (.val (.const (.boolean (decide (left.toInt≤right.toInt))))) := by
  have h := StandardScalar.integerDelta_order .integer64 .le left right (.inr (.inl rfl))
  have booleans : Comparison.le.fromEqLt (left.toInt == right.toInt)
      (decide (left.toInt<right.toInt)) (decide (right.toInt<left.toInt)) =
      decide (left.toInt<=right.toInt) := by
    apply Bool.eq_iff_iff.mpr
    simp only [Comparison.fromEqLt,Bool.or_eq_true,decide_eq_true_eq,beq_iff_eq]
    omega
  exact h.trans (congrArg some (congrArg (fun b => Outcome.val (.const (.boolean b))) booleans))

private theorem checkedRawResult_typed (Ψ : StoreTy) (lo hi : Integer64Value) :
    HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] [] [] (checkedRawResult lo hi) outputType := by
  unfold checkedRawResult
  split
  · rename_i hlo
    split
    · rename_i hhi
      split
      · rename_i whole
        apply result_ok
        apply whole_construct (lo := .const (.integer lo)) (hi := .const (.integer hi))
          (.V_Const trivial) (.V_Const trivial) rfl rfl
          (Entails.integer_le hlo) (Entails.integer_le hhi)
        apply Entails.closed
        all_goals simp [constructedComparison,envelopeTerm,pairField,loField,hiField,
          Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.evalClosed,Pred.evalWith,Pred.atomReady,Pred.atomValue,
          Term.HasSort,Term.Shape,Term.References,Term.VarsIn,varsInSlot,varsInSlots,
          termReady,Term.observe,observeSlots,integerAs,observeAs,
          Term.interpret,Observation.sort,whole]
      · exact result_error (constraint_error_typed 2)
    · exact result_error (constraint_error_typed 1)
  · exact result_error (constraint_error_typed 0)

/-- 任意の型注釈を持つ同じRawの二欄で、既存の四具体例の実行を一般化する。 -/
theorem postprocess_raw_general_steps {σ} (ts us : List Ty) (lo hi : Integer64Value) (k : Cont) (μ : Store) :
    ∃ q, Steps recordProgram recordBuiltins σ
      (.run (.mk (Capture.empty.extend (.con "Result.Ok" ts
        [.con "Raw.Make" us [.const (.integer lo),.const (.integer hi)]])) postprocessBody) k μ) []
      (.run q k μ) ∧ q.view=.ret (checkedRawResult lo hi) := by
  have enter : Steps recordProgram recordBuiltins σ
      (.run (.mk (Capture.empty.extend (.con "Result.Ok" ts
        [.con "Raw.Make" us [.const (.integer lo),.const (.integer hi)]])) postprocessBody) k μ) []
      (.run (.mk (((Capture.empty.extend (.con "Result.Ok" ts
        [.con "Raw.Make" us [.const (.integer lo),.const (.integer hi)]])).extend
          (.con "Raw.Make" us [.const (.integer lo),.const (.integer hi)])).extendMany
            [.const (.integer lo),.const (.integer hi)]) checksBody) k μ) :=
    .cons (.E_Match rfl) (.cons (.E_MatchSkip rfl rfl)
      (.cons (.E_MatchBody rfl rfl) (.cons (.E_Match rfl) (.cons (.E_MatchBody rfl rfl) .nil))))
  have loReply : recordBuiltins.delta "%Integer.lessOrEqual" [] [] []
      [.const (.integer ⟨0,by decide⟩),.const (.integer lo)] =
      some (.val (.const (.boolean (decide (0<=lo.toInt))))) := comparison_boolean ⟨0,by decide⟩ lo
  have hiReply : recordBuiltins.delta "%Integer.lessOrEqual" [] [] []
      [.const (.integer ⟨0,by decide⟩),.const (.integer hi)] =
      some (.val (.const (.boolean (decide (0<=hi.toInt))))) := comparison_boolean ⟨0,by decide⟩ hi
  have wholeReply := comparison_boolean lo hi
  by_cases hlo : 0<=lo.toInt
  · simp only [hlo,decide_true] at loReply
    by_cases hhi : 0<=hi.toInt
    · simp only [hhi,decide_true] at hiReply
      by_cases whole : lo.toInt<=hi.toInt
      · simp [whole] at wholeReply
        refine ⟨_,steps_follow enter (by
          apply Steps.cons (.E_Let rfl)
          apply Steps.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl loReply)
          apply Steps.cons (.E_Return rfl)
          apply Steps.cons (.E_IfT rfl)
          apply Steps.cons (.E_Let rfl)
          apply Steps.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl hiReply)
          apply Steps.cons (.E_Return rfl)
          apply Steps.cons (.E_IfT rfl)
          apply Steps.cons (.E_Let rfl)
          apply Steps.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl wholeReply)
          apply Steps.cons (.E_Return rfl)
          apply Steps.cons (.E_IfT rfl)
          exact .nil),?_⟩
        simp only [checkedRawResult,ite_eq_left hlo,ite_eq_left hhi,ite_eq_left whole]; rfl
      · simp [whole] at wholeReply
        refine ⟨_,steps_follow enter (by
          apply Steps.cons (.E_Let rfl)
          apply Steps.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl loReply)
          apply Steps.cons (.E_Return rfl)
          apply Steps.cons (.E_IfT rfl)
          apply Steps.cons (.E_Let rfl)
          apply Steps.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl hiReply)
          apply Steps.cons (.E_Return rfl)
          apply Steps.cons (.E_IfT rfl)
          apply Steps.cons (.E_Let rfl)
          apply Steps.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl wholeReply)
          apply Steps.cons (.E_Return rfl)
          apply Steps.cons (.E_IfF rfl)
          exact .nil),?_⟩
        simp only [checkedRawResult,ite_eq_left hlo,ite_eq_left hhi,ite_eq_right whole]; rfl
    · simp only [hhi,decide_false] at hiReply
      refine ⟨_,steps_follow enter (by
          apply Steps.cons (.E_Let rfl)
          apply Steps.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl loReply)
          apply Steps.cons (.E_Return rfl)
          apply Steps.cons (.E_IfT rfl)
          apply Steps.cons (.E_Let rfl)
          apply Steps.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl hiReply)
          apply Steps.cons (.E_Return rfl)
          apply Steps.cons (.E_IfF rfl)
          exact .nil),?_⟩
      simp only [checkedRawResult,ite_eq_left hlo,ite_eq_right hhi]; rfl
  · simp only [hlo,decide_false] at loReply
    refine ⟨_,steps_follow enter (by
          apply Steps.cons (.E_Let rfl)
          apply Steps.cons (.E_Prim (ts := []) (es := []) (rs := []) rfl rfl rfl loReply)
          apply Steps.cons (.E_Return rfl)
          apply Steps.cons (.E_IfF rfl)
          exact .nil),?_⟩
    simp only [checkedRawResult,ite_eq_right hlo]; rfl

/-- 全型付きResultの同じ実値から、同じError又は検査した構築値への実行を得る。 -/
theorem postprocess_all {σ Ψ decoded}
    (typed : HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] [] [] decoded
      (.data "Result" [.data "Raw" [],.data "ConversionError" []])) (k : Cont) (μ : Store) :
    ∃ result q, Steps recordProgram recordBuiltins σ
      (.run (.mk (Capture.empty.extend decoded) postprocessBody) k μ) [] (.run q k μ) ∧
      q.view=.ret result ∧ DecodeResult decoded result ∧
      HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] [] [] result
        (.data "Result" [wholeType,.data "ConversionError" []]) := by
  have inhabitant := inhabits_of_typed_raw record_valid typed
  rcases inhabitant.data_inv "Result" [rawType,errorType] rfl with
    ⟨c,ts,vs,cd,rfl,lookup,owner,_,_,fields⟩ | bad
  · rcases result_only lookup owner with rfl | rfl
    · have same := Option.some.inj (lookup.symm.trans
        (show recordProgram.cons "Result.Error"=some ⟨"Result",2,[.tvar 1]⟩ from rfl))
      subst cd
      cases fields with | cons payload rest =>
        cases rest
        obtain ⟨v,hv,vt⟩ := typed.con_field_by_type
          (cd := ⟨"Result",2,[.tvar 1]⟩) rfl rfl (i := 0) rfl record_valid
          (input_annotation []).data_args (by intro a h; change a ∈ [rawType,errorType] at h; simp only [List.mem_cons,List.not_mem_nil,or_false] at h; rcases h with rfl | rfl <;> trivial)
        cases Option.some.inj hv
        rename_i payloadValue
        have payloadTyped : HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] [] [] payloadValue errorType := by
          simpa [errorType,Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,Ty.norm,Ty.normTys,rawBindTys] using vt
        exact ⟨.con "Result.Error" [wholeType,errorType] [payloadValue],_,
          .cons (.E_Match rfl) (.cons (.E_MatchBody rfl rfl) .nil),rfl,.error ts payloadValue,result_error payloadTyped⟩
    · have same := Option.some.inj (lookup.symm.trans
        (show recordProgram.cons "Result.Ok"=some ⟨"Result",2,[.tvar 0]⟩ from rfl))
      subst cd
      cases fields with | cons raw rest =>
        cases rest
        rcases raw.data_inv "Raw" [] rfl with ⟨c,us,vs,cd,rfl,lookup,owner,_,_,fields⟩ | bad
        · have hc := raw_only lookup owner
          subst c
          have same := Option.some.inj (lookup.symm.trans
            (show recordProgram.cons "Raw.Make"=some ⟨"Raw",0,[.base .integer,.base .integer]⟩ from rfl))
          subst cd
          cases fields with | cons lo rest => cases rest with | cons hi rest =>
            cases rest
            obtain ⟨c,rfl,tag⟩ := lo.base_inv .integer rfl
            clear lo
            cases c <;> cases tag
            rename_i lo
            obtain ⟨c,rfl,tag⟩ := hi.base_inv .integer rfl
            clear hi
            cases c <;> cases tag
            rename_i hi
            obtain ⟨q,steps,normal⟩ := postprocess_raw_general_steps ts us lo hi k μ
            exact ⟨checkedRawResult lo hi,q,steps,normal,.raw ts us lo hi,checkedRawResult_typed Ψ lo hi⟩
        · simp at bad
  · simp at bad

/-- 通常decoderの型付けから、同じpostprocessBodyとのletの型付けを構成する。 -/
theorem decode_let_typed {Ψ decoder}
    (typed : HasTypeCQ recordProgram recordBuiltins Ψ Qempty [] [] [] (some outputType)
      decoder inputType Eff.empty []) :
    HasTypeCQ recordProgram recordBuiltins Ψ Qempty [] [] [] (some outputType)
      (.letIn decoder postprocessBody) outputType Eff.empty [] := by
  apply HasTypeCQ.C_Let typed
  · have body := (postprocess_typed Ψ).local_zero (L' := [none]) (by
      intro i b h; simp at h)
    simpa [Ctx.extend,localExtend,LocalCtx.extend,Ty.shiftV,shiftVTys,predBind,termBind,termBind?,outputType,inputType,
      rawType,errorType,wholeType,wholePredicate,pairField,loField,hiField,Eff.shiftV,
      Eff.empty] using body
  · exact (output_annotation []).declared

end
end Benitoite.Release.Refinement.StandardDecode
