import Benitoite.Release.Refinement.SurfaceCheckedMainExamples
import Benitoite.Release.Refinement.ExternalModelTransport

/-!
# 表層の対象健全性の前提を満たし IO の事象へ到達する main

`function main() -> Unit with {Console.Write} = { print("hi"); }` を、標準の型の宣言を収集した表層のプログラムとして
置き、範囲付きのパス操作と対象なしの IO を持つ実例の表（`ExternalModels.targets`）の下で、表層の整形式・型付け・
組込みの表の仮定・main の宣言・環境の束縛を満たすことを示す。同じ開始状態から `print` の IO の事象を伴う遷移へ到達
するので、表層の対象健全性（`surface_target_sound`）の前提は空疎でない（設計書 01-12「確かめる性質」、
07-04「証明する性質」）。
-/

namespace Benitoite.Release.Refinement.Surface.TargetReachExamples
noncomputable section
open StandardModel

/-- `print(text: "hi")`。 -/
def printCall : Expr :=
  .call (.primName "print" [] [] []) [none] [0] (.cons (.literal (.string "hi")) .nil)

/-- main の宣言した効果 `{Console.Write}`。 -/
def writeEff : Eff := Eff.single "Console.Write"

def mainDef : Def := { Examples.mainDef with eff := writeEff, body := .lastDiscard printCall }

/-- 標準の型の宣言と外部宣言を収集し、利用者は print を呼ぶ main を書く。 -/
def source : Program :=
  { MainExamples.source positiveExternals with defs := fun f => if f = "main" then some mainDef else none }

/-- 演算子の表。 -/
abbrev op : OpPrim := fun _ _ => none
/-- 脱糖したプログラム。 -/
abbrev core : Refinement.Program := desugarProgram op source
/-- 範囲付きのパス操作と対象なしの IO を持つ実例の表。 -/
abbrev table : Builtins := ExternalModels.targets core

private theorem table_print : table.sig "print" = some ModelTargets.printSig := rfl

private theorem printSig_tel : ModelTargets.printSig.tel = .param "text" (.base .string) (.done (.base .unit) writeEff) := rfl

private theorem mainDef_tel : mainDef.toFunDecl.tel = .done (.base .unit) writeEff := rfl

private theorem main_annotation (P : Refinement.Program) (Γ : Ctx := []) :
    Ty.Annotation P [] Γ (.dependentFn (.done (.base .unit) writeEff)) :=
  ⟨by simp [writeEff,Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.single,Eff.Canonical,Eff.norm,Ty.normTys],by trivial,by trivial⟩

/-- 表層の整形式。型の宣言は標準の宣言の整形式を引き継ぐ。 -/
theorem wellFormed : source.WellFormed where
  types := (MainExamples.wellFormed positiveExternals positive_wf).types
  defs := by
    intro f d hd
    change (if f = "main" then some mainDef else none) = some d at hd
    split at hd
    · cases hd
      refine ⟨by simp [mainDef,Examples.mainDef,FunDecl.coreNames,FunDecl.coreParams,FunDecl.dictTys,internalNames,NamesWF],?_,
        by simp [mainDef,Examples.mainDef,printCall,Block.Scoped,Expr.Scoped,Exprs.Scoped,scopedTypes,scopedRows]⟩
      change SignatureScopedR _ [] [] 0 (.done (.base .unit) writeEff)
      refine ⟨⟨(main_annotation source.declarations.core).wf,?_,?_⟩,?_,?_,(main_annotation source.declarations.core).range_empty⟩
      all_goals simp [writeEff,Eff.single,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,Ty.RowsInList,Ty.RangesScoped,
        Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,Ty.HasKind,kindsTel,kindsEff,kindsList,RangeIx.WF]
    · cases hd
  impls := by intro i id hi; cases hi
  accessors := by intro f c k h; cases h
  testers := by intro f c h; cases h

private abbrev printTel : Tel := .param "text" (.base .string) (.done (.base .unit) writeEff)

private theorem print_instR : Tel.instR [] ModelTargets.printSig.tel = printTel := by
  simp [printSig_tel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.norm, Ty.norm, Eff.norm, writeEff, Eff.single]

private theorem print_instantiated : instantiatedTel printTel [] [] = printTel := by
  simp [instantiatedTel, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, typeEnvAt, substAtoms_nil, instAtoms_nil,
    rowFails, Tel.norm, Ty.norm, Ty.normTys, Eff.norm, writeEff, Eff.single]

private theorem print_admissible (Q : NoFailCtx) : PrimitiveAdmissible [] 0 ModelTargets.printSig Q [] [] := by
  constructor
  · rfl
  · simp [ModelTargets.printSig, ScopeSignatures.unscopedIO]
  · simp
  · rfl
  · simp
  · simp [ModelTargets.printSig, ScopeSignatures.unscopedIO, Eff.single, Eff.RowsIn, Ty.RowsInList]
  · simp [ModelTargets.printSig, ScopeSignatures.unscopedIO, Qsig, QTys, QTy, QEff, Eff.single,
      Benitoite.Release.Qempty]
  · simp [ModelTargets.printSig, ScopeSignatures.unscopedIO, Qsig, QTys, QTy, QEff, Eff.single,
      Benitoite.Release.Qempty, RowTransport]
  · simp [printSig_tel, Tel.RowsIn, Ty.RowsIn, Ty.RowsInList, Eff.RowsIn, writeEff, Eff.single]

private theorem print_instance (P : Refinement.Program) :
    SignatureInstance P [] [] (Tel.instR [] ModelTargets.printSig.tel) [] [] [] := by
  rw [print_instR]
  constructor
  · simp [writeEff, Ty.WF, Tel.WF, Ty.WFList, Eff.WF, Eff.single, Eff.Canonical, Eff.norm, Ty.normTys]
  · simp [TypeAnnotations]
  · exact ⟨rfl, by intro i a k ha; cases i <;> cases ha⟩
  · simp [RowAnnotations]
  · simp
  · rw [print_instantiated]
    exact ⟨by simp [writeEff, Ty.WF, Tel.WF, Ty.WFList, Eff.WF, Eff.single, Eff.Canonical, Eff.norm,
      Ty.normTys], by trivial, by trivial⟩

private theorem print_head (D : Declarations) (Q : NoFailCtx) :
    CallHeadTy D table Q [] [] (.primName "print" [] [] []) printTel [] := by
  have h := CallHeadTy.prim (D := D) (B := table) (Q := Q) (C := []) (Γ := []) (b := "print")
    (s := ModelTargets.printSig) (ts := []) (es := []) (rs := []) rfl
    ⟨rfl, by simp, by simp, Or.inl (by simp)⟩
    (by simp [ModelTargets.printSig, ScopeSignatures.unscopedIO, NamesWF]) (print_admissible Q) (print_instance _)
  simpa only [List.map_nil, print_instR, print_instantiated] using h

private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e :=
  ⟨by intro a ha; simp [Eff.empty,Eff.mem,Eff.test,Eff.atoms] at ha,
    by intro t ht; obtain ⟨u,hu,_⟩ := ht; simp [Eff.empty,Eff.fails] at hu⟩

private theorem print_typed (D : Declarations) (Q : NoFailCtx) :
    HasTypeQ D table op Q [] [] [] [] (some (.base .unit)) .other printCall (.base .unit) writeEff := by
  apply HasTypeQ.E_CallDirect (r := .base .unit) (e := writeEff) (print_head D Q)
  · simp [CallOk, Tel.names, telBinders]
  · exact .cons (.E_Sub (.E_Literal trivial) .refl (empty_sub _).covers ⟨trivial, trivial, trivial⟩) .nil
  · simp [Tel.shiftV, bindParams, liftMany_one, boundVars, recordFields, fieldAt, Ty.shiftV,
      Eff.shiftV, writeEff, Eff.single]
    apply ValsTel.param
    · exact ⟨by simp [Ty.WF], trivial, trivial⟩
    · exact .var rfl (by simp [Ordinary, Literal.toConst, Const.type, Ty.shiftV, Ty.core])
    · exact .refl
    · simpa [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind, Eff.rawBind, valEnv, typeEnvAt,
        substAtoms_nil, instAtoms_nil, rowFails, Tel.norm, Ty.norm, Ty.normTys, Eff.norm, Tel.shiftV, Ty.shiftV,
        Eff.shiftV, Ctx.extend, liftMany_one, writeEff, Eff.single, Literal.toConst, Const.type] using
        (ValsTel.done (D := D) (B := table) (C := []) (Γ0 := []) (k := 1)
          (Γ := [some (.base .string)]) (Φ := []) (a := .base .unit) (e := writeEff)
          (main_annotation D.core [some (.base .string)]))
  · exact .refl
  · simp [Eff.shiftV, writeEff, Eff.single]
    exact Eff.Covers.refl _ _ _
  · exact ⟨trivial, trivial, trivial⟩

/-- 表層の型付け。print の直接の呼出しは引数を束縛してから宣言の位置順に渡し、効果は main の宣言の効果に等しい。 -/
theorem wellTyped : source.WellTyped table op where
  variance := (variance_valid positiveExternals).sameTypes ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩
  defs := by
    intro f d hd
    change (if f = "main" then some mainDef else none) = some d at hd
    split at hd
    · cases hd
      refine ⟨by simp [mainDef, Examples.mainDef, FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys,
          internalNames, NamesWF], ?_, by rw [mainDef_tel]; exact (main_annotation _).range_empty, ?_⟩
      · rw [mainDef_tel]; simp [Ty.HasKind, kindsTel, kindsEff, kindsList, writeEff, Eff.single]
      · rw [mainDef_tel]; exact .done (.B_LastDiscard (print_typed _ _))
    · cases hd
  impls := by intro i id hi; cases hi
  effects := ⟨fun _ _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, source,
      MainExamples.source, Examples.mainProgram] at h,
    fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, source,
      MainExamples.source, Examples.mainProgram] at h,
    fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, source,
      MainExamples.source, Examples.mainProgram] at h⟩

/-- 範囲付きのモデルが読む Result と Scope.ScopeError の宣言。 -/
theorem hasFile : ScopeDeclarations.HasFile core := (http_declarations positiveExternals).file

/-- main の宣言の形。 -/
theorem hasMain : source.HasMain writeEff := ⟨mainDef, rfl, rfl, rfl, rfl, rfl, rfl, Or.inl rfl, rfl⟩

/-- 全ての起点を束縛した具体の環境。 -/
def environment : PathEnv := ⟨[],[],[],some [],some [],some []⟩

/-- 環境の束縛。 -/
theorem ready : environment.Ready core table (.run mainClosure [] Store.empty) := by
  refine ⟨by simp [PathEnv.Valid,environment,Scope.Domain.PathWordWF], ?_⟩
  intro r _
  cases r with
  | base b => cases b <;> exact ⟨[],rfl⟩
  | secrets => rfl

private def hiValue : Refinement.Val := .const (.string "hi")
private def printComp : Comp := .app (.prim "print" [] [] []) [.var 0]
private def restComp : Comp := .ret (.const .unit)
private def headComp : Comp := .letIn (.ret hiValue) printComp

/-- 開始状態から、main の呼出し・二つの let・値の返却で print の呼出しへ進む。 -/
theorem reach : Benitoite.Release.Refinement.Steps core table environment (.run mainClosure [] Store.empty) []
    (.run ((Closure.mk Capture.empty printComp).apply [hiValue])
      [.letF (Closure.mk Capture.empty restComp), .mark] Store.empty) :=
  .cons (.E_Fun (rs := []) rfl rfl rfl rfl rfl)
    (.cons (.E_Let rfl) (.cons (.E_Let rfl) (.cons (.E_Return rfl) .nil)))

/-- その状態は print の IO の事象を伴って遷移する。 -/
theorem print_step : Benitoite.Release.Refinement.Step core table environment
    (.run ((Closure.mk Capture.empty printComp).apply [hiValue])
      [.letF (Closure.mk Capture.empty restComp), .mark] Store.empty)
    (some (.io "print" [hiValue] (.val (.const .unit)) []))
    (.run (Closure.pure (.ret (.const .unit))) [.letF (Closure.mk Capture.empty restComp), .mark] Store.empty) :=
  .E_IO (rs := []) rfl rfl rfl (by simp [NoHandler]) (Or.inr (Or.inl ⟨rfl, rfl, rfl⟩))

/-- 表層の対象健全性の全前提を満たす main の開始状態から、IO の事象を伴う遷移へ到達する。到達した事象の観測は、
main の宣言した効果が許す（`surface_target_sound` の適用）。 -/
theorem main_reach :
    (∃ s s', Benitoite.Release.Refinement.Steps core table environment (.run mainClosure [] Store.empty) [] s ∧
      Benitoite.Release.Refinement.Step core table environment s
        (some (.io "print" [.const (.string "hi")] (.val (.const .unit)) [])) s') ∧
    ∃ e l, table.sig "print" = some e ∧ e.opEff = some l ∧
      ∀ t ∈ ([] : List Scope.Domain.Target), Eff.Allows environment table.effKind writeEff l t :=
  ⟨⟨_, _, reach, print_step⟩,
    surface_target_sound wellFormed wellTyped (ExternalModels.targets_core core hasFile)
      (ExternalModels.targets_scope core hasFile).toTargetAgreement hasMain ready _ _ _ _ _ _ _ reach print_step⟩

end
end Benitoite.Release.Refinement.Surface.TargetReachExamples
