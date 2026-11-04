import Benitoite.Release.Refinement.StandardFactExamples
import Benitoite.Release.Refinement.TelApplication
import Benitoite.Release.Refinement.StandardVariance
import Benitoite.Release.Refinement.CanonicalValues
import Benitoite.Release.Refinement.OpenSubstitution

/-! 設計書01-12「篩を含む型判断」の高階の型位置の内部模型。
標準ソースの解決済みABI又は全APIの充足とは別の、構文による受理・拒否を扱う。 -/
namespace Benitoite.Release.Refinement.StandardHigherPositions
noncomputable section
/-- 整数型。 -/
def I : Ty := .base .integer
/-- 自己値が7である整数型。 -/
def R : Ty := .refined I (.eq (.var 0) (.integer 7))
/-- 単位型。 -/
def U : Ty := .base .unit
/-- 同じvalueラベルを持つ一引数の関数型。 -/
def F (a b : Ty) (e : Eff := Eff.empty) : Ty := .fn ["value"] [a] b e

private theorem reverse_rejected {P : Program} {Γ : Ctx} (facts : Γ.facts = []) :
 ¬ Ty.LeQ P Γ [] I R := by
 intro h
 have he := h.assume (.eq (.var 0) (.integer 7)) (by simp [R,I,Ty.assume,Ty.core,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts])
 have bad := he.sound (fun _ => some (.integer 8)) (by
   intro p hp
   simp [I,Ty.assume,Ty.core,Ty.carrierFacts,integerBounds,Ty.refinementPredicates,facts] at hp
   rcases hp with rfl | rfl <;> decide)
 have no : (Pred.eq (.var 0) (.integer 7)).interpret (fun _ => some (.integer 8)) = false := by decide
 rw [no] at bad; cases bad

private theorem var_core {P B Ψ source target}
 (h : HasTypeVQ P B Ψ Qempty [] [some source] [] (.var 0) target) :
 Ty.LeQ P [some source] [] source.norm.core target.norm.core := by
 obtain ⟨a,b,hi,ho,ht,le⟩ := h.inv_var rfl
 have eq : a = source := Option.some.inj (Option.some.inj hi).symm
 subst a
 simpa only [ht] using le

private theorem callback_accept (P : Program) (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ P B Ψ Qempty [] [some (F I U)] [] (.var 0) (F R U) := by
 apply HasTypeVQ.V_Sub (a := F I U)
 · exact .V_Var rfl (by intro b t e h; cases h)
 · exact .fn (by simp [NamesWF]) (by simp [NamesWF]) (.cons .forget .nil) .refl (Eff.Covers.refl _ _ _)
 all_goals simp [F,I,R,U,Ty.WF,Ty.WFList,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,Term.VarsIn,
  Ty.Sorted,sortedTys,sortedEff,Pred.Sorted,Term.HasSort,Term.Shape,Term.References,Ty.HasSort,Ty.sort?,
  Ctx.Readable,Ctx.extend,Ty.Declared,declaredTys,declaredEff,Pred.Declared,Term.Declared,Ctx.declarationSelf,
  Ty.shiftV,NamesWF,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm]

private theorem callback_reject (P : Program) (B : Builtins) (Ψ : StoreTy) :
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F R U)] [] (.var 0) (F I U) := by
 intro h
 have l := var_core h
 obtain ⟨u,hu,rel⟩ := l.fnCore rfl
 cases Option.some.inj hu
 obtain ⟨b,t,ht,le,tail⟩ := rel.param_inputs
 cases ht
 have le' : Ty.LeQ P [some (F R U)] [] I R.norm := le
 apply reverse_rejected (P := P) (Γ := [some (F R U)]) (by rfl)
 exact .trans le' (.convert (Ty.norm_idem R))

-- 受理と拒否には、同じ変数とその元型を持つ文脈を使う。
private theorem accept_var {P B Ψ source target}
 (ordinary : source.Ordinary) (le : Ty.LeQ P [some source] [] source target)
 (ann : Ty.Annotation P [] [some source] target) :
 HasTypeVQ P B Ψ Qempty [] [some source] [] (.var 0) target :=
 .V_Sub (.V_Var rfl ordinary) le ann.wf ann.sorted ann.declared

private theorem basic_ann (P : Program) (source : Ty) :
 (Ty.Annotation P [] [some source] (F U I)) ∧
 (Ty.Annotation P [] [some source] (F R I)) ∧
 (Ty.Annotation P [] [some source] (.list (F R I))) ∧
 (Ty.Annotation P [] [some source] (F U U (Eff.singleFail I))) := by
 all_goals repeat' constructor
 all_goals simp [I,Ty.NotContCore,Ty.core,Ty.shiftV]

private theorem result_accept (P : Program) (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ P B Ψ Qempty [] [some (F U R)] [] (.var 0) (F U I) :=
 accept_var (by intro b t e h; cases h)
 (.fn (by simp [NamesWF]) (by simp [NamesWF]) (.cons .refl .nil) .forget (Eff.Covers.refl _ _ _))
 (basic_ann P _).1

private theorem result_reject (P : Program) (B : Builtins) (Ψ : StoreTy) :
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F U I)] [] (.var 0) (F U R) := by
 intro h
 obtain ⟨u,hu,rel⟩ := (var_core h).fnCore rfl
 cases Option.some.inj hu
 obtain ⟨b,t,ht,le,tail⟩ := rel.param_inputs
 cases ht
 obtain ⟨r,e,he,out,cov⟩ := tail.done_outputs
 cases he
 have out' : Ty.LeQ P (Ctx.extend [some (F U I)] U) [] I R.norm := out
 exact reverse_rejected (P := P) (Γ := Ctx.extend [some (F U I)] U) (by rfl)
   (.trans out' (.convert (Ty.norm_idem R)))

private theorem widen_eff (Γ : Ctx) : Eff.Covers Γ [] (Eff.singleFail I) Eff.empty := by
 constructor
 · intro a ha; cases ha
 · intro t ht; simp [Eff.memFail,Eff.empty,Eff.fails] at ht

private theorem effect_accept (P : Program) (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ P B Ψ Qempty [] [some (F U U)] [] (.var 0) (F U U (Eff.singleFail I)) :=
 accept_var (by intro b t e h; cases h) (.fn_effect (widen_eff _)) (basic_ann P _).2.2.2

private theorem effect_reject (P : Program) (B : Builtins) (Ψ : StoreTy) :
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F U U (Eff.singleFail I))] [] (.var 0) (F U U) := by
 intro h
 obtain ⟨u,hu,rel⟩ := (var_core h).fnCore rfl
 cases Option.some.inj hu
 obtain ⟨b,t,ht,le,tail⟩ := rel.param_inputs
 cases ht
 obtain ⟨r,e,he,out,cov⟩ := tail.done_outputs
 cases he
 have fail : (Eff.singleFail I).memFail I := (Eff.memFail_single_iff _ _).mpr rfl
 have bad := cov.2 I fail
 change Eff.empty.memFail I at bad
 simp [Eff.memFail,Eff.empty,Eff.fails] at bad

private theorem list_accept (P : Program) (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ P B Ψ Qempty [] [some (.list (F I R))] [] (.var 0) (.list (F R I)) :=
 accept_var (by intro b t e h; cases h)
 (.list (.fn (by simp [NamesWF]) (by simp [NamesWF]) (.cons .forget .nil) .forget (Eff.Covers.refl _ _ _)))
 (basic_ann P _).2.2.1

private theorem list_reject (P : Program) (B : Builtins) (Ψ : StoreTy) :
 ¬ HasTypeVQ P B Ψ Qempty [] [some (.list (F R I))] [] (.var 0) (.list (F I R)) := by
 intro h
 obtain ⟨b,hb,le⟩ := (var_core h).listCore rfl
 cases Option.some.inj hb
 obtain ⟨u,hu,rel⟩ := le.fnCore rfl
 cases Option.some.inj hu
 obtain ⟨b,t,ht,le,tail⟩ := rel.param_inputs
 cases ht
 have le' : Ty.LeQ P [some (.list (F R I))] [] I R.norm := le
 exact reverse_rejected (P := P) (Γ := [some (.list (F R I))]) (by rfl)
   (.trans le' (.convert (Ty.norm_idem R)))
/-- 負位置の型引数を持つConsumerの具体的な構成子表。 -/
def consumerProgram : Program where
 defs := fun _ => none
 cons := fun c => if c = "Consumer.Make" then
   some ⟨"Consumer",1,[.fn ["value"] [.tvar 0] (.base .unit) Eff.empty]⟩ else none
 ops := fun _ => none
 effects := fun _ => none
 classes := fun _ => none
 impls := fun _ => none
 dataInfo := fun d => if d = "Consumer" then some ⟨1,[.contravariant],[],[]⟩ else none

private theorem consumer_valid : consumerProgram.VarianceValid := by
 constructor
 · intro d info hi
   simp only [consumerProgram] at hi
   split at hi
   · rename_i eq; subst d; cases hi
     refine ⟨rfl,?_,by simp,by simp⟩
     intro i variance hv unused
     cases i with
     | zero =>
       cases Option.some.inj hv
       exact False.elim (unused ⟨"Consumer.Make",⟨"Consumer",1,[.fn ["value"] [.tvar 0] (.base .unit) Eff.empty]⟩,
         .fn ["value"] [.tvar 0] (.base .unit) Eff.empty,by simp [consumerProgram],rfl,by simp,by simp [Ty.ParamOccurs,paramsOccur]⟩)
     | succ i => simp at hv
   · cases hi
 · intro c cd hc
   simp only [consumerProgram] at hc
   split at hc
   · cases hc
     constructor
     · intro info hi; simp [consumerProgram] at hi; cases hi; rfl
     · intro a ha; cases List.mem_singleton.mp ha
       refine ⟨⟨?_,?_,?_⟩,?_,?_⟩
       all_goals simp [Ty.WF,Ty.WFList,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,declaredEff,
         Ty.HasKind,kindsList,kindsEff,Ty.VarianceOK,varianceTysOK,Eff.VarianceOK,
         Program.varianceFor,consumerProgram,TypeCtx.valueParam,NamesWF,
         Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Ty.normTys,Polarity.flip,Variance.accepts]
   · cases hc


private theorem option_arity : StandardVariance.program.DataArity "Option" 1 := by
 constructor
 · exact ⟨"Option.Some",⟨"Option",1,[.tvar 0]⟩,rfl,rfl⟩
 · intro c cd hc same
   have hi : StandardVariance.program.dataInfo cd.data = some ⟨1,[.covariant],[],[]⟩ := by rw [same]; rfl
   exact ((StandardVariance.valid.2 c cd hc).1 _ hi).symm
private theorem consumer_arity : consumerProgram.DataArity "Consumer" 1 := by
 constructor
 · exact ⟨"Consumer.Make",⟨"Consumer",1,[.fn ["value"] [.tvar 0] (.base .unit) Eff.empty]⟩,by simp [consumerProgram],rfl⟩
 · intro c cd hc same
   have hi : consumerProgram.dataInfo cd.data = some ⟨1,[.contravariant],[],[]⟩ := by rw [same]; simp [consumerProgram]
   exact ((consumer_valid.2 c cd hc).1 _ hi).symm

private theorem option_accept (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ StandardVariance.program B Ψ Qempty [] [some (.data "Option" [R])] [] (.var 0) (.data "Option" [I]) := by
 apply accept_var (by intro b t e h; cases h)
 · exact (StandardVariance.covariant_positions (Ty.LeQ.forget (P := StandardVariance.program))).2.1
 · constructor <;> simp [I,Ty.WF,Ty.WFList,Ty.Sorted,sortedTys,Ty.Declared,declaredTys,option_arity]

private theorem option_reject (B : Builtins) (Ψ : StoreTy) :
 ¬ HasTypeVQ StandardVariance.program B Ψ Qempty [] [some (.data "Option" [I])] [] (.var 0) (.data "Option" [R]) := by
 intro h
 obtain ⟨bs,hb,ha⟩ := (var_core h).dataCore rfl
 have eq : bs = [R.norm] := (Ty.data.inj hb).2.symm
 subst bs
 change TypeArgsLe StandardVariance.program [some (.data "Option" [I])] [] [.covariant] [I] [R.norm] at ha
 cases ha with
 | covariant_cons le rest =>
   exact reverse_rejected (P := StandardVariance.program) (Γ := [some (.data "Option" [I])]) (by rfl)
     (.trans le (.convert (Ty.norm_idem R)))

private theorem consumer_accept (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ consumerProgram B Ψ Qempty [] [some (.data "Consumer" [I])] [] (.var 0) (.data "Consumer" [R]) := by
 apply accept_var (by intro b t e h; cases h)
 · apply Ty.LeQ.data
   change TypeArgsLe consumerProgram _ _ [.contravariant] [I] [R]
   exact .contravariant_cons .forget .nil
 · constructor <;> simp [I,R,Ty.WF,Ty.WFList,Ty.Sorted,sortedTys,Ty.Declared,declaredTys,
    Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,Term.VarsIn,Pred.Sorted,Term.HasSort,Term.Shape,
    Term.References,Ty.HasSort,Ty.sort?,Ctx.Readable,Ctx.extend,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ty.shiftV,consumer_arity]

private theorem consumer_reject (B : Builtins) (Ψ : StoreTy) :
 ¬ HasTypeVQ consumerProgram B Ψ Qempty [] [some (.data "Consumer" [R])] [] (.var 0) (.data "Consumer" [I]) := by
 intro h
 obtain ⟨bs,hb,ha⟩ := (var_core h).dataCore rfl
 have eq : bs = [I] := (Ty.data.inj hb).2.symm
 subst bs
 change TypeArgsLe consumerProgram [some (.data "Consumer" [R])] [] [.contravariant] [R.norm] [I] at ha
 cases ha with
 | contravariant_cons le rest =>
   exact reverse_rejected (P := consumerProgram) (Γ := [some (.data "Consumer" [R])]) (by rfl)
     (.trans le (.convert (Ty.norm_idem R)))

/-- 通常の一引数関数と同じ正規形を持つ依存列の表示。 -/
def FunctionView : Ty := .dependentFn (Ty.toTel ["value"] [I] U Eff.empty)
private theorem view_norm : (F I U).norm = FunctionView.norm :=
 (Ty.norm_toTel (ns := ["value"]) (ps := [I]) (r := U) (e := Eff.empty) (by simp [NamesWF])).symm

private theorem view_annotation (P : Program) (source : Ty) :
 Ty.Annotation P [] [some source] FunctionView ∧
 Ty.Annotation P [] [some source] (.reference FunctionView) ∧
 Ty.Annotation P [] [some source] (F U U (Eff.singleFail FunctionView)) := by
 have same : Eff.singleFail FunctionView = Eff.singleFail (F I U) := by simp only [Eff.singleFail,←view_norm]
 refine ⟨?_,?_,?_⟩
 all_goals try rw [same]
 all_goals constructor
 all_goals simp [FunctionView,Ty.toTel,F,I,U,Ty.WF,Ty.WFList,Tel.WF,
    Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,Ty.Declared,Tel.Declared,declaredTys,declaredEff,
    Ty.shiftV,shiftVTys,Eff.shiftV,NamesWF,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.singleFail,
    Ty.norm,Ty.normTys]

private theorem reference_accept (P : Program) (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ P B Ψ Qempty [] [some (.reference (F I U))] [] (.var 0) (.reference FunctionView) := by
 apply accept_var (by intro b t e h; cases h)
 · exact .convert (congrArg Ty.reference view_norm)
 · exact (view_annotation P _).2.1

private theorem reference_reject (P : Program) (B : Builtins) (Ψ : StoreTy) :
 ¬ HasTypeVQ P B Ψ Qempty [] [some (.reference R)] [] (.var 0) (.reference I) := by
 intro h
 obtain ⟨b,hb,eq⟩ := (var_core h).refCore rfl
 cases Option.some.inj hb
 cases eq

private theorem fail_accept (Γ : Ctx) : Eff.Covers Γ [] (Eff.singleFail FunctionView) (Eff.singleFail (F I U)) := by
 constructor
 · intro a ha; cases ha
 · intro t ht
   have eq := (Eff.memFail_single_iff _ _).mp ht
   exact (Eff.memFail_single_iff _ _).mpr (view_norm.symm.trans eq)

private theorem fail_reject (Γ : Ctx) : ¬ Eff.Covers Γ [] (Eff.singleFail I) (Eff.singleFail R) := by
 intro h
 have bad := (Eff.memFail_single_iff _ _).mp (h.2 R ((Eff.memFail_single_iff _ _).mpr rfl))
 cases bad

private theorem fail_value_accept (P : Program) (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ P B Ψ Qempty [] [some (F U U (Eff.singleFail (F I U)))] [] (.var 0) (F U U (Eff.singleFail FunctionView)) :=
 accept_var (by intro b t e h; cases h) (.fn_effect (fail_accept _)) (view_annotation P _).2.2

private theorem fail_value_reject (P : Program) (B : Builtins) (Ψ : StoreTy) :
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F U U (Eff.singleFail R))] [] (.var 0) (F U U (Eff.singleFail I)) := by
 intro h
 obtain ⟨u,hu,rel⟩ := (var_core h).fnCore rfl
 cases Option.some.inj hu
 obtain ⟨b,t,ht,le,tail⟩ := rel.param_inputs
 cases ht
 obtain ⟨r,e,he,out,cov⟩ := tail.done_outputs
 cases he
 have cov' : Eff.Covers (Ctx.extend [some (F U U (Eff.singleFail R))] U) [] (Eff.singleFail I) (Eff.singleFail R.norm) := cov
 apply fail_reject (Ctx.extend [some (F U U (Eff.singleFail R))] U)
 simpa only [Eff.singleFail,Ty.norm_idem] using cov'

private theorem names_accept (P : Program) (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ P B Ψ Qempty [] [some (F I U)] [] (.var 0) FunctionView :=
 accept_var (by intro b t e h; cases h) (.convert view_norm) (view_annotation P _).1

private theorem names_wellformed : NamesWF ["value"] [I] ∧ NamesWF ["other"] [I] ∧ NamesWF ["value","extra"] [I,U] := by
 simp [NamesWF]

private theorem names_reject (P : Program) (B : Builtins) (Ψ : StoreTy) :
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F I U)] [] (.var 0) (.fn ["other"] [I] U Eff.empty) := by
 intro h
 have same := (var_core h).names_eq rfl rfl
 change ["value"] = ["other"] at same
 exact (by decide : ("value" : String) ≠ "other") (List.cons.inj same).1

private theorem arity_reject (P : Program) (B : Builtins) (Ψ : StoreTy) :
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F I U)] [] (.var 0) (.fn ["value","extra"] [I,U] U Eff.empty) := by
 intro h
 have same := congrArg List.length ((var_core h).names_eq rfl rfl)
 change 1 = 2 at same
 cases same

-- 依存結果と非空の潜在Failを、同じ二つの実値で具体化する。
/-- 依存する二引数の比較で用いる入力型。 -/
def inTy (strong : Bool) : Ty := if strong then .refined I (.eq (.var 0) (.integer 2)) else I
/-- 二つの値引数から10x+yを表す結果の篩。 -/
def dep : Ty := .refined I (.eq (.var 0) (.add (.scale 10 (.var 2)) (.var 1)))
/-- 同じ篩を依存結果と潜在Failの両方に持つ二引数列。 -/
def depTel (strong : Bool) : Tel :=
 .param "x" (inTy strong) (.param "y" I (.done dep (Eff.singleFail dep)))
/-- 一番目の実引数2。 -/
def v2 : Val := .const (.integer ⟨2,by decide⟩)
/-- 二番目の実引数5。 -/
def v5 : Val := .const (.integer ⟨5,by decide⟩)
/-- 10*2+5の算術構文を保持する結果型。 -/
def r25 : Ty := .refined I (.eq (.var 0) (.add (.scale 10 (.integer 2)) (.integer 5)))
/-- 引数の位置を交換した10*5+2の結果型。 -/
def r52 : Ty := .refined I (.eq (.var 0) (.add (.scale 10 (.integer 5)) (.integer 2)))

private theorem dep_annotation (P : Program) (strong : Bool) : Ty.Annotation P [] [] (.dependentFn (depTel strong)) := by
 constructor
 · cases strong <;> simp [depTel,inTy,dep,I,Ty.WF,Tel.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,
    Ty.NotContCore,Ty.core,Eff.WF,Ty.WFList,Eff.Canonical,Eff.singleFail,Eff.norm,Ty.normTys,Ty.norm,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts]
 · cases strong <;> simp [depTel,inTy,dep,I,Ty.Sorted,Tel.Sorted,Pred.Sorted,Term.HasSort,Term.References,
    Term.VarsIn,Term.Shape,Ctx.Readable,Ctx.extend,Ty.HasSort,Ty.sort?,Ty.core,sortedEff,sortedTys,
    Ty.shiftV,Eff.singleFail,Ty.norm,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts]
 · cases strong <;> simp [depTel,inTy,dep,I,Ty.Declared,Tel.Declared,Pred.Declared,Term.Declared,
    declaredEff,declaredTys,Eff.singleFail,Ctx.declarationSelf,Ctx.extend,Ctx.Readable,Ty.core,Ty.shiftV,
    predBind,Ty.norm,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts]

private theorem dep_relation (P : Program) : TelClosure P [] [] (depTel false) (depTel true) :=
 .tail .refl (.param .forget (.param .refl (.done .refl (Eff.Covers.refl _ _ _))))

private theorem dep_instantiate : Tel.instantiate (depTel true) [v2,v5] = some (r25,Eff.singleFail r25) := by
 simp [Tel.instantiate,depTel,inTy,v2,v5,Tel.bind,Tel.rawBind,Tel.norm,Ty.rawBind,Ty.norm,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,Eff.singleFail,Eff.rawBind,Eff.norm,Tel.argumentsEnv,valEnv,SubstEnv.up,upValues,predBind,termBind,termBind?,r25,dep,I,Val.toTerm?,substAtoms,instAtoms,rowFails,Benitoite.Release.Integer64Value.toInt]
 all_goals first | rfl | skip
 all_goals try (funext a; rcases a with ⟨l,r|i⟩|i <;> simp [substAtoms,instAtoms])

private theorem dep_args (P : Program) (B : Builtins) (Ψ : StoreTy) :
 HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v2,v5] (depTel true) r25 (Eff.singleFail r25) := by
 have hv2 : HasTypeVQ P B Ψ Qempty [] [] [] v2 I := .V_Const trivial
 have hv5 : HasTypeVQ P B Ψ Qempty [] [] [] v5 I := .V_Const trivial
 have narrow2 : HasTypeVQ P B Ψ Qempty [] [] [] v2 (inTy true) := by
   apply HasTypeVQ.V_Refine (a := I) (t := .integer 2) (sort := .integer) hv2 rfl rfl
   all_goals first | exact Entails.eq_refl | (simp [I,Pred.WF,Pred.VarsIn,Term.VarsIn,
    Pred.Sorted,Term.HasSort,Term.Shape,Term.References,Ty.HasSort,Ty.sort?,Ctx.Readable,
    Ctx.declarationSelf,Ctx.extend,Ty.Declared,Pred.Declared,Term.Declared,Ordinary,Ty.core,Ty.shiftV] <;> trivial)

 have first := dep_annotation P true
 have opened := Tel.annotation_open (by intro i a h; cases h) first narrow2
 have last := Tel.annotation_open (by intro i a h; cases h) opened hv5
 have finished := HasTypeTelArgsQ.done (B := B) (Ψ := Ψ) (Q := Qempty) (Φ := []) last
 have second := HasTypeTelArgsQ.param (name := "y") (a := I)
   (rest := Tel.bind (Tel.argumentsEnv v2).up (.done dep (Eff.singleFail dep)))
   ⟨opened.wf.1,opened.sorted.1,opened.declared.1⟩ hv5 finished
 have all := HasTypeTelArgsQ.param (name := "x") (a := inTy true)
   (rest := .param "y" I (.done dep (Eff.singleFail dep)))
   ⟨first.wf.1,first.sorted.1,first.declared.1⟩ narrow2 second
 have normal : (depTel true).Normal := by
   simp [Tel.Normal,depTel,inTy,dep,I,Tel.norm,Ty.norm,Ty.refineNorm,Ty.packRefinements,
     Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,Eff.singleFail,Eff.norm]
 have eq := all.instantiate normal
 have same := Option.some.inj (dep_instantiate.symm.trans eq)
 obtain ⟨hr,he⟩ := Prod.mk.inj same
 simpa only [←he,←hr,depTel] using all

/-- 元列の注釈と反変関係へ同じ二実引数を適用し、依存結果と潜在Failを同時に得る。 -/
theorem dep_apply (P : Program) (B : Builtins) (Ψ : StoreTy) :
 ∃ r e, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v2,v5] (depTel false) r e ∧
   Ty.LeQ P [] [] r r25 ∧ Eff.Covers [] [] (Eff.singleFail r25) e :=
 (dep_relation P).apply (by intro i a h; cases h) (dep_annotation P false) (dep_args P B Ψ)

private theorem swapped_fail_rejected : ¬ Eff.Covers [] [] (Eff.singleFail r52) (Eff.singleFail r25) := by
 intro h
 have hi : (Eff.singleFail r25).memFail r25 := (Eff.memFail_single_iff _ _).mpr rfl
 have bad := (Eff.memFail_single_iff _ _).mp (h.2 r25 hi)
 cases bad

private theorem swapped_result_rejected (P : Program) (B : Builtins) (Ψ : StoreTy) :
 ¬ HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer ⟨25,by decide⟩)) r52 := by
 intro h
 have he := h.facts (t := .integer 25) rfl
   (.eq (.var 0) (.add (.scale 10 (.integer 5)) (.integer 2))) (by
    simp [r52,I,Ty.assume,Ty.core,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts])
 have bad := he.sound (fun _ => none) (by simp [Ctx.facts])
 have no : (Pred.eq (.integer 25) (.add (.scale 10 (.integer 5)) (.integer 2))).interpret (fun _ => none) = false := by decide
 change (Pred.eq (.integer 25) (.add (.scale 10 (.integer 5)) (.integer 2))).interpret (fun _ => none) = true at bad
 rw [no] at bad; cases bad

-- 長さの前提を読む既存の導出へ、四種の置換像を実際に適用する。
/-- 長さを表す整数を一つ持つ元文脈。 -/
def nContext : Ctx := [some I]
/-- 元の長さの正数条件。 -/
def nPositive : Pred := .lt (.integer 0) (.var 0)
/-- 元文脈の整数と長さが等しいList型。 -/
def nSource : Ty := .refined (.list U) (.eq (.measure .listLength (.var 0)) (.var 1))

private theorem length_transport : Transport OpenSubstitution.θ nContext [nPositive]
    OpenSubstitution.Δ OpenSubstitution.Ψ := by
 constructor
 · intro i a sort hi hs
   cases i with
   | zero =>
     cases Option.some.inj hi
     exact OpenSubstitution.transport.values 0
       (.refined I (.eq (.var 0) (.integer 7))) sort rfl hs
   | succ i => simp [nContext] at hi
 · intro i a hi ho t ht
   cases i with
   | zero =>
     cases Option.some.inj hi
     exact OpenSubstitution.transport.references 0
       (.refined I (.eq (.var 0) (.integer 7))) rfl ho t ht
   | succ i => simp [nContext] at hi
 · exact OpenSubstitution.transport.typeImages
 · intro p hp
   have nf : nContext.facts = integerBounds (-9223372036854775808) 9223372036854775807 := rfl
   rw [nf] at hp
   rcases List.mem_append.mp hp with hp | hp
   · apply OpenSubstitution.transport.facts
     apply List.mem_append_left
     rw [OpenSubstitution.context_facts.1]
     exact List.mem_append_left _ hp
   · cases List.mem_singleton.mp hp
     change Entails (OpenSubstitution.Δ.facts ++ OpenSubstitution.Ψ)
       (.lt (.integer 0) (.add (.var 2) (.integer 1)))
     have checked : EqProof.checkRaw [.eq (.add (.var 2) (.integer 1)) (.integer 7)]
       .integer (.integer 7) (.add (.var 2) (.integer 1)) (.symm (.hyp 0)) = true := by decide
     have pos := EqProof.substitute_entails (p := .lt (.integer 0) (.var 0)) checked (by decide)
       (Entails.integer_lt (by decide : (0 : Int) < 7))
     apply pos.cut
     intro q hq
     cases List.mem_singleton.mp hq
     exact OpenSubstitution.target_path_from_facts.weaken (fun _ h => List.mem_append_left _ h)

/-- 正数の経路条件を読む既存の長さ導出を、四種の像を持つ既存の置換で移送する。 -/
theorem length_all_images (P : Program) : Ty.LeQ P OpenSubstitution.Δ OpenSubstitution.Ψ
  (nSource.bind OpenSubstitution.θ) ((nonemptyType U).bind OpenSubstitution.θ) :=
 (show Ty.LeQ P nContext [nPositive] nSource (nonemptyType U) from
    StandardFactExamples.length_le P).bind OpenSubstitution.θ length_transport

private theorem length_without_positive (P : Program) : ¬ Ty.LeQ P nContext [] nSource (nonemptyType U) :=
 StandardFactExamples.length_without_positive_rejected P

example (P : Program) : Ty.LeQ P OpenSubstitution.Δ OpenSubstitution.Ψ
   ((OpenSubstitution.source OpenSubstitution.inner).bind OpenSubstitution.θ)
   ((OpenSubstitution.source OpenSubstitution.outer).bind OpenSubstitution.θ) :=
 OpenSubstitution.all_open_derivation

example : Eff.Covers OpenSubstitution.Δ OpenSubstitution.Ψ
   (Eff.bind OpenSubstitution.θ OpenSubstitution.outer) (Eff.bind OpenSubstitution.θ OpenSubstitution.inner) :=
 OpenSubstitution.all_open_covers


private def localTypes : List Ty := [I, R, U, F I U, F R U, F U I, F U R, F U U, F U U (Eff.singleFail I), F I R, F R I, .list (F I R), .list (F R I), .reference (F I U), .reference FunctionView, .reference R, .reference I, F U U (Eff.singleFail (F I U)), F U U (Eff.singleFail FunctionView), F U U (Eff.singleFail R), FunctionView, .fn ["other"] [I] U Eff.empty, .fn ["value","extra"] [I,U] U Eff.empty]

private theorem local_annotations (P : Program) (source t : Ty)
    (ht : t ∈ localTypes) : Ty.Annotation P [] [some source] t := by
 simp only [localTypes,List.mem_cons,List.not_mem_nil,or_false] at ht
 rcases ht with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
 all_goals try exact (view_annotation P source).2.2
 all_goals try exact (view_annotation P source).2.1
 all_goals try exact (view_annotation P source).1
 all_goals constructor
 all_goals simp [F,I,R,U,Ty.WF,Ty.WFList,Ty.NotContCore,Ty.core,
  Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.Sorted,sortedTys,sortedEff,Pred.Sorted,
  Term.HasSort,Term.Shape,Term.References,Ty.HasSort,Ty.sort?,Ctx.Readable,Ctx.extend,
  Ty.Declared,declaredTys,declaredEff,Pred.Declared,Term.Declared,Ctx.declarationSelf,
  Ty.shiftV,NamesWF,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.singleFail,
  Ty.norm,Ty.normTys,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
  Pred.conjuncts,Pred.ofConjuncts]

/-- 同じ元型・変数の変換の受理と、逆向きの拒否。両型の注釈を元文脈で検査する。 -/
def PositionChecked (P : Program) (B : Builtins) (Ψ : StoreTy) (source target : Ty) : Prop :=
 Ty.Annotation P [] [some source] source ∧ Ty.Annotation P [] [some source] target ∧
 HasTypeVQ P B Ψ Qempty [] [some source] [] (.var 0) target ∧
 ¬ HasTypeVQ P B Ψ Qempty [] [some target] [] (.var 0) source

private theorem data_annotations :
 (Ty.Annotation StandardVariance.program [] [some (.data "Option" [R])] (.data "Option" [R]) ∧
  Ty.Annotation StandardVariance.program [] [some (.data "Option" [R])] (.data "Option" [I])) ∧
 (Ty.Annotation consumerProgram [] [some (.data "Consumer" [I])] (.data "Consumer" [I]) ∧
  Ty.Annotation consumerProgram [] [some (.data "Consumer" [I])] (.data "Consumer" [R])) := by
 refine ⟨⟨?_,?_⟩,⟨?_,?_⟩⟩
 all_goals constructor
 all_goals simp [I,R,Ty.WF,Ty.WFList,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,Term.VarsIn,
  Ty.Sorted,sortedTys,Pred.Sorted,Term.HasSort,Term.Shape,Term.References,Ty.HasSort,Ty.sort?,
  Ctx.Readable,Ctx.extend,Ty.Declared,declaredTys,Pred.Declared,Term.Declared,Ctx.declarationSelf,
  Ty.shiftV,option_arity,consumer_arity]

/-- 関数入力の反変を、整形式な両型と同じ変数で検査する。 -/
theorem callback_checked (P : Program) (B : Builtins) (Ψ : StoreTy) :
 PositionChecked P B Ψ (F I U) (F R U) :=
 ⟨local_annotations P _ _ (by simp [localTypes]),local_annotations P _ _ (by simp [localTypes]),
  callback_accept P B Ψ,callback_reject P B Ψ⟩

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ P B Ψ Qempty [] [some (F I U)] [] (.var 0) (F R U) ∧
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F R U)] [] (.var 0) (F I U) :=
 ⟨(callback_checked P B Ψ).2.2.1,(callback_checked P B Ψ).2.2.2⟩

/-- 関数結果の共変を、整形式な両型と同じ変数で検査する。 -/
theorem result_checked (P : Program) (B : Builtins) (Ψ : StoreTy) :
 PositionChecked P B Ψ (F U R) (F U I) :=
 ⟨local_annotations P _ _ (by simp [localTypes]),local_annotations P _ _ (by simp [localTypes]),
  result_accept P B Ψ,result_reject P B Ψ⟩

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ P B Ψ Qempty [] [some (F U R)] [] (.var 0) (F U I) ∧
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F U I)] [] (.var 0) (F U R) :=
 ⟨(result_checked P B Ψ).2.2.1,(result_checked P B Ψ).2.2.2⟩

/-- 潜在効果の集合の拡大を、整形式な両型と同じ変数で検査する。 -/
theorem effect_checked (P : Program) (B : Builtins) (Ψ : StoreTy) :
 PositionChecked P B Ψ (F U U) (F U U (Eff.singleFail I)) :=
 ⟨local_annotations P _ _ (by simp [localTypes]),local_annotations P _ _ (by simp [localTypes]),
  effect_accept P B Ψ,effect_reject P B Ψ⟩

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ P B Ψ Qempty [] [some (F U U)] [] (.var 0) (F U U (Eff.singleFail I)) ∧
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F U U (Eff.singleFail I))] [] (.var 0) (F U U) :=
 ⟨(effect_checked P B Ψ).2.2.1,(effect_checked P B Ψ).2.2.2⟩

/-- List内の関数の入力反変・結果共変を、整形式な両型と同じ変数で検査する。 -/
theorem list_checked (P : Program) (B : Builtins) (Ψ : StoreTy) :
 PositionChecked P B Ψ (.list (F I R)) (.list (F R I)) :=
 ⟨local_annotations P _ _ (by simp [localTypes]),local_annotations P _ _ (by simp [localTypes]),
  list_accept P B Ψ,list_reject P B Ψ⟩

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ P B Ψ Qempty [] [some (.list (F I R))] [] (.var 0) (.list (F R I)) ∧
 ¬ HasTypeVQ P B Ψ Qempty [] [some (.list (F R I))] [] (.var 0) (.list (F I R)) :=
 ⟨(list_checked P B Ψ).2.2.1,(list_checked P B Ψ).2.2.2⟩

/-- 同じ実構成子表の検証済み変性と実DataArityの下で、dataの引数を検査する。 -/
theorem option_checked (B : Builtins) (Ψ : StoreTy) :
 PositionChecked StandardVariance.program B Ψ (.data "Option" [R]) (.data "Option" [I]) :=
 ⟨data_annotations.1.1,data_annotations.1.2,option_accept B Ψ,option_reject B Ψ⟩

example (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ StandardVariance.program B Ψ Qempty [] [some (.data "Option" [R])] [] (.var 0) (.data "Option" [I]) ∧
 ¬ HasTypeVQ StandardVariance.program B Ψ Qempty [] [some (.data "Option" [I])] [] (.var 0) (.data "Option" [R]) :=
 ⟨(option_checked B Ψ).2.2.1,(option_checked B Ψ).2.2.2⟩

/-- 同じ実構成子表の検証済み変性と実DataArityの下で、dataの引数を検査する。 -/
theorem consumer_checked (B : Builtins) (Ψ : StoreTy) :
 PositionChecked consumerProgram B Ψ (.data "Consumer" [I]) (.data "Consumer" [R]) :=
 ⟨data_annotations.2.1,data_annotations.2.2,consumer_accept B Ψ,consumer_reject B Ψ⟩

example (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ consumerProgram B Ψ Qempty [] [some (.data "Consumer" [I])] [] (.var 0) (.data "Consumer" [R]) ∧
 ¬ HasTypeVQ consumerProgram B Ψ Qempty [] [some (.data "Consumer" [R])] [] (.var 0) (.data "Consumer" [I]) :=
 ⟨(consumer_checked B Ψ).2.2.1,(consumer_checked B Ψ).2.2.2⟩

/-- Referenceは同じ正規形の関数viewを受理し、篩を忘れる変換を拒否する。 -/
theorem reference_checked (P : Program) (B : Builtins) (Ψ : StoreTy) :
 (Ty.Annotation P [] [some (.reference (F I U))] (.reference (F I U)) ∧
  Ty.Annotation P [] [some (.reference (F I U))] (.reference FunctionView)) ∧
 (Ty.Annotation P [] [some (.reference R)] (.reference R) ∧
  Ty.Annotation P [] [some (.reference R)] (.reference I)) ∧
 HasTypeVQ P B Ψ Qempty [] [some (.reference (F I U))] [] (.var 0) (.reference FunctionView) ∧
 ¬ HasTypeVQ P B Ψ Qempty [] [some (.reference R)] [] (.var 0) (.reference I) :=
 ⟨⟨local_annotations P _ _ (by simp [localTypes]),local_annotations P _ _ (by simp [localTypes])⟩,
  ⟨local_annotations P _ _ (by simp [localTypes]),local_annotations P _ _ (by simp [localTypes])⟩,
  reference_accept P B Ψ,reference_reject P B Ψ⟩

/-- Failのエラー型の正規形等号と、潜在Failを持つ同じ関数変数での対照。 -/
theorem fail_checked (P : Program) (B : Builtins) (Ψ : StoreTy) :
 Eff.Covers [] [] (Eff.singleFail FunctionView) (Eff.singleFail (F I U)) ∧
 ¬ Eff.Covers [] [] (Eff.singleFail I) (Eff.singleFail R) ∧
 HasTypeVQ P B Ψ Qempty [] [some (F U U (Eff.singleFail (F I U)))] [] (.var 0) (F U U (Eff.singleFail FunctionView)) ∧
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F U U (Eff.singleFail R))] [] (.var 0) (F U U (Eff.singleFail I)) :=
 ⟨fail_accept [],fail_reject [],fail_value_accept P B Ψ,fail_value_reject P B Ψ⟩

/-- 名前と個数の異なる注釈も整形式であるが、同じ変数の関数型の変換では拒否する。 -/
theorem names_arity_checked (P : Program) (B : Builtins) (Ψ : StoreTy) :
 (NamesWF ["value"] [I] ∧ NamesWF ["other"] [I] ∧ NamesWF ["value","extra"] [I,U]) ∧
 Ty.Annotation P [] [some (F I U)] (.fn ["other"] [I] U Eff.empty) ∧
 Ty.Annotation P [] [some (F I U)] (.fn ["value","extra"] [I,U] U Eff.empty) ∧
 HasTypeVQ P B Ψ Qempty [] [some (F I U)] [] (.var 0) FunctionView ∧
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F I U)] [] (.var 0) (.fn ["other"] [I] U Eff.empty) ∧
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F I U)] [] (.var 0) (.fn ["value","extra"] [I,U] U Eff.empty) :=
 ⟨names_wellformed,local_annotations P _ _ (by simp [localTypes]),
 local_annotations P _ _ (by simp [localTypes]),names_accept P B Ψ,names_reject P B Ψ,arity_reject P B Ψ⟩

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ P B Ψ Qempty [] [some (.reference (F I U))] [] (.var 0) (.reference FunctionView) :=
 (reference_checked P B Ψ).2.2.1
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
 ¬ Eff.Covers [] [] (Eff.singleFail I) (Eff.singleFail R) := (fail_checked P B Ψ).2.1
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F I U)] [] (.var 0) (.fn ["other"] [I] U Eff.empty) :=
 (names_arity_checked P B Ψ).2.2.2.2.1

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
 (∃ r e, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v2,v5] (depTel false) r e ∧
   Ty.LeQ P [] [] r r25 ∧ Eff.Covers [] [] (Eff.singleFail r25) e) ∧
 (¬ HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer ⟨25,by decide⟩)) r52) ∧
 (¬ Eff.Covers [] [] (Eff.singleFail r52) (Eff.singleFail r25)) :=
 ⟨dep_apply P B Ψ,swapped_result_rejected P B Ψ,swapped_fail_rejected⟩

example (P : Program) :
 Ty.LeQ P OpenSubstitution.Δ OpenSubstitution.Ψ
  (nSource.bind OpenSubstitution.θ) ((nonemptyType U).bind OpenSubstitution.θ) ∧
 ¬ Ty.LeQ P nContext [] nSource (nonemptyType U) :=
 ⟨length_all_images P,length_without_positive P⟩

-- 逆向きの拒否でも、両型を同じ実文脈で注釈として形成できる。
example (P : Program) (source t : Ty) (ht : t ∈ localTypes) :
 Ty.Annotation P [] [some source] t := local_annotations P source t ht

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
 (Ty.Annotation P [] [some (F U U (Eff.singleFail (F I U)))] (F U U (Eff.singleFail (F I U))) ∧
  Ty.Annotation P [] [some (F U U (Eff.singleFail (F I U)))] (F U U (Eff.singleFail FunctionView))) ∧
 (Ty.Annotation P [] [some (F U U (Eff.singleFail R))] (F U U (Eff.singleFail R)) ∧
  Ty.Annotation P [] [some (F U U (Eff.singleFail R))] (F U U (Eff.singleFail I))) ∧
 HasTypeVQ P B Ψ Qempty [] [some (F U U (Eff.singleFail (F I U)))] [] (.var 0) (F U U (Eff.singleFail FunctionView)) ∧
 ¬ HasTypeVQ P B Ψ Qempty [] [some (F U U (Eff.singleFail R))] [] (.var 0) (F U U (Eff.singleFail I)) :=
 ⟨⟨local_annotations P _ _ (by simp [localTypes]),local_annotations P _ _ (by simp [localTypes])⟩,
  ⟨local_annotations P _ _ (by simp [localTypes]),local_annotations P _ _ (by simp [localTypes])⟩,
  (fail_checked P B Ψ).2.2⟩


end
end Benitoite.Release.Refinement.StandardHigherPositions
