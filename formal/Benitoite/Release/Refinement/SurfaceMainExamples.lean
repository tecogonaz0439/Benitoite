import Benitoite.Release.Refinement.SurfaceLibrary
import Benitoite.Release.Refinement.Surface.Examples
import Benitoite.Release.Refinement.StandardModelApplicationExamples

/-! # 標準本体と外部宣言を保持した表層の main -/
namespace Benitoite.Release.Refinement.Surface.MainExamples
noncomputable section
open StandardModel

/-- 標準の型の宣言と外部宣言を収集し、利用者は空の main の本体を書く。 -/
def source (externals : List (ExternalKey × ExternalDecl)) : Program :=
  { Examples.mainProgram with
    cons := (program externals).cons
    dataInfo := (program externals).dataInfo
    externals := externals }

def linked (externals : List (ExternalKey × ExternalDecl)) : Refinement.Program :=
  linkProgram (program externals) (fun _ _ => none) (source externals)

private theorem main_fresh (externals : List (ExternalKey × ExternalDecl)) :
    (program externals).defs "main" = none := rfl

/-- 核の標準本体を同じ値で保持する包含。 -/
theorem includes (externals : List (ExternalKey × ExternalDecl)) : Includes externals (linked externals) where
  extends_ := { Refinement.Program.Extends.refl (program externals) with
    defs := by
      intro f d hd
      have hn : f ≠ "main" := by intro h; subst f; rw [main_fresh] at hd; cases hd
      simpa [linked,linkProgram,desugarProgram,Program.lookupFun,source,Examples.mainProgram,hn] using hd }
  internal := by
    intro f d hn hd
    by_cases hm : f = "main"
    · subst f; simp only [String.startsWith_string_iff]; decide
    · simp [linked,linkProgram,desugarProgram,Program.lookupFun,source,Examples.mainProgram,hm,hn] at hd
  publicCollisions := by
    intro n hn
    have h0 := (Includes.refl externals).publicCollisions n hn
    have hm : n ≠ "main" := by
      intro h; subst n
      simp [FunctionNames.collisionNames] at hn
    simpa [linked,linkProgram,desugarProgram,Program.lookupFun,source,Examples.mainProgram,hm] using h0

/-- 関数の結合は data の宣言を変えない。 -/
def data (externals : List (ExternalKey × ExternalDecl)) : DataTable (linked externals) :=
  { dataTable externals with valid := (variance_valid externals).sameTypes ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩ }

/-- 全ての起点を束縛した具体の環境。 -/
def environment : PathEnv := ⟨[],[],[],some [],some [],some []⟩

private theorem ready (P : Refinement.Program) (B : Builtins) :
    environment.Ready P B (.run mainClosure [] Store.empty) := by
  refine ⟨by simp [PathEnv.Valid,environment,Scope.Domain.PathWordWF], ?_⟩
  intro r _
  cases r with
  | base b => cases b <;> exact ⟨[],rfl⟩
  | secrets => rfl

private theorem source_types (externals : List (ExternalKey × ExternalDecl))
    (hw : (program externals).ExternalWF) : (source externals).declarations.core.WellFormed := by
  have h := program_wellFormed externals hw
  have hs : (program externals).SameTypes (source externals).declarations.core := ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩
  refine ⟨?_,?_,?_,?_,?_,h.metadata.sameTypes hs,h.external.sameTypes hs⟩
  · intro f d hd; cases hd
  · intro c cd hc
    exact ⟨(hs.dataArity _ _).mp (h.cons c cd hc).1,(h.cons c cd hc).2.sameTypes hs⟩
  · intro o od ho; cases ho
  · intro c cd hc; cases hc
  · intro i id hi; cases hi

/-- 表層の整形式を、checker の結論から独立に供給する。 -/
theorem wellFormed (externals : List (ExternalKey × ExternalDecl)) (hw : (program externals).ExternalWF) :
    (source externals).WellFormed where
  types := source_types externals hw
  defs := by
    intro f d hd
    change (if f = "main" then some Examples.mainDef else none) = some d at hd
    split at hd
    · cases hd
      refine ⟨by simp [Examples.mainDef,FunDecl.coreNames,FunDecl.coreParams,FunDecl.dictTys,internalNames,NamesWF],?_,trivial⟩
      rw [Examples.mainDef_tel]
      refine ⟨⟨(Examples.mainTel_annotation (source externals).declarations.core).wf,?_,?_⟩,?_,?_,(Examples.mainTel_annotation _).range_empty⟩
      · simp [Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,Eff.empty,Ty.RowsInList]
      · simp [Ty.RangesScoped,Tel.RangesScoped,Eff.RangesScoped,Eff.empty,rangesScopedTypes]
      · simp [Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Eff.empty,Ty.RowsInList]
      · simp [Ty.HasKind,kindsTel,kindsEff,kindsList,Eff.empty]
    · cases hd
  impls := by intro i id hi; cases hi
  accessors := by intro f c k h; cases h
  testers := by intro f c h; cases h

/-- 仮定側の行を使わず、同じ完成した標準表を選ぶ。 -/
def input (externals : List (ExternalKey × ExternalDecl)) : Check.Input where
  D := (source externals).declarations
  builtinSource := .custom (complete nameLists (data externals) ApplicationExamples.noAssumptions)
  opPrim := fun _ _ => none
  formation := ⟨[],fun _ => [],[]⟩
  proofSteps := 1
  defs := ["main"]

/-- main の表層の有限な導出と、収集した変性・効果の検査。 -/
theorem checked (externals : List (ExternalKey × ExternalDecl)) : CheckTables.CheckedUnder (source externals) (input externals) where
  variance := (variance_valid externals).sameTypes ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩
  defs := by
    intro f d hd
    change (if f = "main" then some Examples.mainDef else none) = some d at hd
    split at hd
    · cases hd
      refine ⟨by simp [Examples.mainDef,FunDecl.coreNames,FunDecl.coreParams,FunDecl.dictTys,internalNames,NamesWF],?_,?_,?_⟩
      · simp [Examples.mainDef,FunDecl.tel,FunDecl.coreNames,FunDecl.coreParams,FunDecl.dictTys,internalNames,signatureTel,
          Ty.HasKind,kindsTel,kindsEff,kindsList,Eff.empty]
      · exact (Examples.mainTel_annotation _).range_empty
      · apply bodyTyR_nil.mpr
        exact .done .B_Empty
    · cases hd
  extension := CheckTables.Extends.refl _
  effects := by
    refine ⟨?_,?_,?_⟩ <;> intros <;> contradiction
  impls := by intro i id hi; cases hi

/-- 標準を含む表層の利用者のプログラムに、完成した同じ表の全主定理を適用できる。 -/
theorem guarantees (externals : List (ExternalKey × ExternalDecl)) (hw : (program externals).ExternalWF) (σ : PathEnv) :
    ProgramGuarantees (linked externals) (input externals).B σ :=
  surface_guarantees (p := source externals) (q := input externals) nameLists_wf (data externals) rfl (includes externals)
    (link_realizes _ (wellFormed externals hw) closedView)
    (ApplicationExamples.noAssumptions_completion nameLists_wf _) hw (wellFormed externals hw) (checked externals) σ

/-- 性質1の三検査から、同じ表で追加宣言の十一欄を取り出す具体の適用。 -/
example (op : OpPrim) :
    Refinement.Program.Additions (StandardModel.program []) (desugarProgram op Examples.mainProgram)
      (StandardModel.builtins (desugarProgram op Examples.mainProgram)) :=
  desugar_additions _ Examples.mainProgram_wellFormed (Examples.mainProgram_wellTyped _ op)
    (StandardModel.substitution_assumptions _).toValueAssumptions

/-- 外部宣言を一つ保持した main で、開始の型付け・効果・対象の全前提を同時に満たす。 -/
theorem main_guarantees : MainGuarantees (linked positiveExternals) (input positiveExternals).B environment Eff.empty := by
  apply linked_main (p := source positiveExternals) (q := input positiveExternals) nameLists_wf (data positiveExternals) rfl (includes positiveExternals)
    (link_realizes _ (wellFormed _ positive_wf) closedView)
    (ApplicationExamples.noAssumptions_completion nameLists_wf _) positive_wf
    (wellFormed _ positive_wf) (checked positiveExternals)
  · exact ⟨Examples.mainDef,rfl,rfl,rfl,rfl,rfl,rfl,Or.inl rfl,rfl⟩
  · exact ready _ _

/-- 外部宣言を保持する同じ証人へ、プログラム全体の主定理も適用する。 -/
example : ProgramGuarantees (linked positiveExternals) (input positiveExternals).B environment :=
  guarantees _ positive_wf environment

/-- 生の脱糖の入口も、同じ main の宣言から空の効果の性質を得る。 -/
example (op : OpPrim) :
    ∀ evs s, Steps (desugarProgram op Examples.mainProgram)
      (ExternalModels.model (desugarProgram op Examples.mainProgram)) environment
      (.run mainClosure [] Store.empty) evs s →
    (∀ ev s', ¬ Step (desugarProgram op Examples.mainProgram)
      (ExternalModels.model (desugarProgram op Examples.mainProgram)) environment s (some ev) s') ∧ ¬ UnhandledOp s :=
  surface_effect_soundness Examples.mainProgram_wellFormed (Examples.mainProgram_wellTyped _ op)
    (ExternalModels.model_core _) ⟨Examples.mainDef,rfl,rfl,rfl,rfl,rfl,rfl,Or.inl rfl,rfl⟩ (ready _ _)

/-- 同じ脱糖の入口の対象の結論を、到達した IO の事象に適用する。 -/
example (op : OpPrim) :
    ∀ evs s s' b ws o obs, Steps (desugarProgram op Examples.mainProgram)
      (ExternalModels.model (desugarProgram op Examples.mainProgram)) environment
      (.run mainClosure [] Store.empty) evs s →
    Step (desugarProgram op Examples.mainProgram)
      (ExternalModels.model (desugarProgram op Examples.mainProgram)) environment s (some (.io b ws o obs)) s' →
    ∃ e l, (ExternalModels.model (desugarProgram op Examples.mainProgram)).sig b = some e ∧ e.opEff = some l ∧
      ∀ t ∈ obs, Eff.Allows environment (ExternalModels.model (desugarProgram op Examples.mainProgram)).effKind Eff.empty l t :=
  surface_target_sound Examples.mainProgram_wellFormed (Examples.mainProgram_wellTyped _ op)
    (ExternalModels.model_core _) (ExternalModels.model_scope _).toTargetAgreement
    ⟨Examples.mainDef,rfl,rfl,rfl,rfl,rfl,rfl,Or.inl rfl,rfl⟩ (ready _ _)

private theorem prepare_source (q : Check.Input) (externals : List (ExternalKey × ExternalDecl)) :
    CheckPreparation.prepare q (source externals) = ⟨q, source externals⟩ := by
  have sources_empty : CheckPreparation.sources q (source externals) = [] := by
    have each : ∀ name : FunName,
        (match (source externals).defs name with
          | none => [] | some d => Identity.preorderBlock d.body) = [] := by
      intro name
      by_cases h : name = "main" <;> simp [source, Examples.mainProgram, h, Examples.mainDef, Identity.preorderBlock]
    have empty_flatMap : ∀ names : List String, names.flatMap (fun _ => ([] : List Expr)) = [] := by
      intro names
      induction names with
      | nil => rfl
      | cons name names ih => exact ih
    have hdefs := congrArg (fun f : FunName → List Expr => q.defs.flatMap f) (funext each)
    change _ ++ _ = []
    calc
      _ = q.defs.flatMap (fun _ => ([] : List Expr)) ++
          q.impls.flatMap (fun name => match (source externals).impls name with
            | none => [] | some id => q.methods.flatMap fun method => match id.methods method with
              | none => [] | some body => Identity.preorderBlock body) :=
        congrArg (fun expressions : List Expr => expressions ++ _) hdefs
      _ = [] := by
        change q.defs.flatMap (fun _ => ([] : List Expr)) ++ q.impls.flatMap (fun _ => []) = []
        rw [empty_flatMap, empty_flatMap]
        rfl
  have rows_empty : ∀ forbidden,
      PredicateRowCollection.collectAvoid (source externals) [] forbidden = [] := fun _ => rfl
  simp [CheckPreparation.prepare, sources_empty, rows_empty]

/-- 実入口の成功から、具体の利用者の main の開始までを接続する。 -/
example {q : Check.Input} {Ai : CheckAccept.AcceptInput}
    (hq : q.Sound) (hn : CheckTables.NamesComplete q (source positiveExternals))
    (hd : ∀ n d, (source positiveExternals).defs n = some d → CheckDeclarations.DefSupport q d)
    (hi : ∀ n id, (source positiveExternals).impls n = some id → CheckDeclarations.ImplSupport q id)
    (him : ∀ n id, (source positiveExternals).impls n = some id → CheckDeclarations.ImplNamesComplete q id)
    (hext : CheckTables.Extends q.D (source positiveExternals).declarations)
    (ha : CheckAccept.NamesComplete q (source positiveExternals))
    (haccept : CheckAccept.checkProgramAccepted q Ai (source positiveExternals) = .ok ())
    (T : DataTable (linkProgram (program positiveExternals) q.opPrim (source positiveExternals)))
    {A : AssumedTable} (hB : q.B = complete nameLists T A)
    (hI : Includes positiveExternals (linkProgram (program positiveExternals) q.opPrim (source positiveExternals)))
    (hR : q.D.Realizes (linkProgram (program positiveExternals) q.opPrim (source positiveExternals)))
    (hc : Completion nameLists T A) :
    CheckAccept.Accepted Ai q (source positiveExternals) ∧
      ProgramGuarantees (linkProgram (program positiveExternals) q.opPrim (source positiveExternals))
        (complete nameLists T A) environment ∧
      MainGuarantees (linkProgram (program positiveExternals) q.opPrim (source positiveExternals))
        (complete nameLists T A) environment Eff.empty := by
  have apply_main := checkProgramAccepted_main (q := q) (p := source positiveExternals)
    (Ai := Ai) (L := nameLists) (externals := positiveExternals)
  rw [prepare_source q positiveExternals] at apply_main
  exact apply_main hq hn hd hi him hext ha haccept nameLists_wf T hB hI hR hc
    positive_wf (wellFormed _ positive_wf)
    ⟨Examples.mainDef,rfl,rfl,rfl,rfl,rfl,rfl,Or.inl rfl,rfl⟩ (ready _ _)

/-- 証人の開始の状態は、空の効果のままで事象を出さず未処理の操作を呼ばない。 -/
example : ∀ evs s, Steps (linked positiveExternals) (input positiveExternals).B environment
    (.run mainClosure [] Store.empty) evs s →
    (∀ ev s', ¬ Step (linked positiveExternals) (input positiveExternals).B environment s (some ev) s') ∧ ¬ UnhandledOp s :=
  main_guarantees.effect rfl

end
end Benitoite.Release.Refinement.Surface.MainExamples
