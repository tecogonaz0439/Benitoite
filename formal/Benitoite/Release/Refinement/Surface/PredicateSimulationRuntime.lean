import Benitoite.Release.Refinement.Surface.PredicateSimulationAlgebra
import Benitoite.Release.Refinement.Surface.PredicateProjectionCalls
import Benitoite.Release.Refinement.Surface.PredicatePublicDeltas
import Benitoite.Release.Refinement.Surface.PredicateSimulationScalarControl
import Benitoite.Release.Refinement.Surface.PredicateSimulationAdministrativePath
import Benitoite.Release.Refinement.Surface.CheckBuiltinSource
import Benitoite.Release.Refinement.Semantics

/-! # 判定の名前解決の実行状態の対応

値・閉包の対応をフレームとストアへ持ち上げ、公開呼出しの管理用の途中状態を対応させる。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateRows PredicateResponse
noncomputable section

inductive BuilderRel (source : Program) (rows : PredicateProjection.Table.Rows) : BuilderContents → BuilderContents → Prop
  | string (s) : BuilderRel source rows (.string s) (.string s)
  | bytes (bs) : BuilderRel source rows (.bytes bs) (.bytes bs)
  | list {vs ws} : Values source rows vs ws → BuilderRel source rows (.list vs) (.list ws)

inductive FrameRel (source : Program) (rows : PredicateProjection.Table.Rows) : Frame → Frame → Prop
  | letF {q r} : ClosedCode source rows q r → FrameRel source rows (.letF q) (.letF r)
  | mark : FrameRel source rows .mark .mark
  | update (l) : FrameRel source rows (.update l) (.update l)
  | release {v w} : Value source rows v w → FrameRel source rows (.release v) (.release w)
  | drop (l) : FrameRel source rows (.drop l) (.drop l)
  | handleF {cap cap' cs ds} : Captures source rows cap cap' → Clauses source rows cs ds →
      FrameRel source rows (.handleF cap cs) (.handleF cap' ds)
  | guardF {v w cap cap' as bs next q r} : Value source rows v w → Captures source rows cap cap' →
      Arms source rows as bs → ClosedCode source rows q r → FrameRel source rows (.guardF v cap as next q) (.guardF w cap' bs next r)

inductive ContRel (source : Program) (rows : PredicateProjection.Table.Rows) : Cont → Cont → Prop
  | nil : ContRel source rows [] []
  | cons {f g k l} : FrameRel source rows f g → ContRel source rows k l → ContRel source rows (f :: k) (g :: l)

inductive CellRel (source : Program) (rows : PredicateProjection.Table.Rows) : Cell → Cell → Prop
  | builder {a b} : BuilderRel source rows a b → CellRel source rows (.builder a) (.builder b)
  | value {v w} : Value source rows v w → CellRel source rows (.val v) (.val w)
  | done {v w} : Value source rows v w → CellRel source rows (.done v) (.done w)
  | used : CellRel source rows .used .used
  | thunk {q r} : ClosedCode source rows q r → CellRel source rows (.thunk q) (.thunk r)
  | cont {k l} : ContRel source rows k l → CellRel source rows (.cont k) (.cont l)

def StoreRel (source : Program) (rows : PredicateProjection.Table.Rows) (μ ν : Store) : Prop :=
  ∀ l, Option.Rel (CellRel source rows) (μ l) (ν l)

inductive StateRel (source : Program) (rows : PredicateProjection.Table.Rows) : State → State → Prop
  | run {q r k l μ ν} : ClosedCode source rows q r → ContRel source rows k l → StoreRel source rows μ ν →
      StateRel source rows (.run q k μ) (.run r l ν)
  | matchRun {v w cap cap' as bs next k l μ ν} : Value source rows v w → Captures source rows cap cap' →
      Arms source rows as bs → ContRel source rows k l → StoreRel source rows μ ν →
      StateRel source rows (.matchRun v cap as next k μ) (.matchRun w cap' bs next l ν)
  | error {rs k l μ ν} : ContRel source rows k l → StoreRel source rows μ ν → StateRel source rows (.error rs k μ) (.error rs l ν)
  | exit {n rs k l μ ν} : ContRel source rows k l → StoreRel source rows μ ν → StateRel source rows (.exit n rs k μ) (.exit n rs l ν)
  /-- ソース順の単純な値を束縛する途中は、同じ対象を読む内部appと対応する。 -/
  | scalarPhase {api entry positions values key cap cap' value target k l μ ν state rank} :
      rows.lookup key = some (.scalar entry) → values.length = api.inputs.length →
      ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value →
      SimpleValues values → Captures source rows cap cap' → Value source rows value target →
      ContRel source rows k l → StoreRel source rows μ ν → ScalarPhase api positions values cap k μ state rank →
      StateRel source rows state (.run (.mk cap' (.app (.prim key [] [] []) [target])) l ν)
  /-- getter列を実行した公開判定と、同じ欄を直接読む内部判定を対応させる。 -/
  | projectedApplication {api projection key q cap arguments types receiver constant k l μ ν} :
      rows.lookup key = some (.projected projection) →
      q.view = .app (.prim api.name [] [] []) arguments →
      ScalarInputs api projection.entry arguments (.const constant) →
      types.length = projection.ntys →
      MatchFacts.readPath (closeVal cap receiver) projection.route = some (.const constant) →
      ContRel source rows k l → StoreRel source rows μ ν →
      StateRel source rows (.run q k μ)
        (.run (.mk cap (.app (.prim key types [] []) [receiver])) l ν)
  /-- 実getterの六規則だけからなる一意な管理用経路を、対応する本体の前に置く。 -/
  | administrative {first ready target} : AdministrativePath source first ready → StateRel source rows ready target →
      StateRel source rows first target

theorem StoreRel.empty (source : Program) (rows) : StoreRel source rows Store.empty Store.empty := by intro l; exact .none

theorem StoreRel.set {source rows μ ν l c d} (h : StoreRel source rows μ ν) (hc : CellRel source rows c d) :
    StoreRel source rows (μ.set l c) (ν.set l d) := by
  intro k
  by_cases he : k = l
  · simp only [Store.set, he, ite_true]; exact .some hc
  · simp only [Store.set, he, ite_false]; exact h k

def floatingSource (width : FloatWidth) (test : FloatTest) (i : Nat) : Expr :=
  .call (.primName (API.floating width test).name [] [] []) [none] [0] (.cons (.local i) .nil)

def floatingResolved (width : FloatWidth) (test : FloatTest) (key : PrimName) (i : Nat) : Expr :=
  .partialCall (.primName key [] [] []) [] (.expr none 0 (.local i) .nil)
    ((Entry.floating width test).result (.var (i + 1))) Eff.empty

theorem scalarName_lookup {rows entry key}
    (h : PredicateProjectionCalls.scalarName rows entry = some key) : rows.lookup key = some (.scalar entry) := by
  unfold PredicateProjectionCalls.scalarName at h
  obtain ⟨row, found, same⟩ := Option.map_eq_some_iff.mp h
  have selected : row.2 = .scalar entry ∧ rows.lookup row.1 = some (.scalar entry) :=
    of_decide_eq_true (List.find?_some (p := fun (row : PrimName × PredicateProjection.Row) => decide (row.2 = .scalar entry ∧ rows.lookup row.1 = some (.scalar entry))) found)
  cases same
  exact selected.2

/-- 実際の公開呼出しの解決を、登録済みの同じscalar行へ接続する。 -/
theorem floating_resolution (rows) (p : Program) (width : FloatWidth) (test : FloatTest) (key : PrimName) (i : Nat)
    (hk : PredicateProjectionCalls.scalarName rows (.floating width test) = some key) :
    PredicateProjectionCalls.resolveExpr rows p (floatingSource width test i) = floatingResolved width test key i := by
  have api : PredicateCalls.apiOfName (API.floating width test).name = some (.floating width test) := by
    cases width <;> cases test <;> rfl
  have allowed : CallOk (API.floating width test).names (API.floating width test).inputs.length false [none] [0] ∧
      (Exprs.cons (.local i) .nil).length = (API.floating width test).inputs.length := by
    cases width <;> simp only [API.names, API.inputs, Exprs.length, List.length_cons, List.length_nil] <;> decide
  have selected : PredicateCalls.identify (.floating width test)
      (recordFields (API.floating width test).inputs.length [0]
        (PredicateCalls.expressions (.cons (.local i) .nil)) .unit) = some (.floating width test, .local i) := by
    cases width <;> rfl
  have projected : PredicateProjectionCalls.resolve rows p (.floating width test) (.local i) = none := by
    simp [PredicateProjectionCalls.resolve, PredicateAccessorTargets.parse, Expr.valueOf?, Val.toTerm?, PredicateProjectionCalls.candidate]
  change PredicateProjectionCalls.resolveCall rows p (API.floating width test).name [none] [0]
    (.cons (.local i) .nil) = _
  simp only [PredicateProjectionCalls.resolveCall, api, ite_eq_left allowed, selected, projected,
    Option.orElse_none, hk, Option.bind_some]
  rfl

/-- 公開判定の元の脱糖と、実際に解決した式の脱糖は根のコードの対応を満たす。 -/
theorem floating_code (rows) (p : Program) (op : OpPrim) (position : Position)
    (width : FloatWidth) (test : FloatTest) (key : PrimName) (i : Nat)
    (hk : PredicateProjectionCalls.scalarName rows (.floating width test) = some key) :
    Code p rows (desugarExpr op position (floatingSource width test i))
      (desugarExpr op position (PredicateProjectionCalls.resolveExpr rows p (floatingSource width test i))) := by
  rw [floating_resolution rows p width test key i hk]
  have simple : SimpleValues [.var i] := fun value member => by
    simp only [List.mem_singleton] at member; subst value; exact .var i
  cases width <;>
    exact Code.scalar (source := p) (api := .floating _ test) (positions := [0]) (values := [.var i])
      (scalarName_lookup hk) rfl (.floating _ test (.var i)) simple (.var i)

/-- ラムダ本体の実際のresolveBlockも、同じ値と本体の相互関係へ入る。 -/
theorem floating_lambda_code (rows) (p : Program) (op : OpPrim)
    (width : FloatWidth) (test : FloatTest) (key : PrimName)
    (hk : PredicateProjectionCalls.scalarName rows (.floating width test) = some key) :
    let source := Block.last (.lam ["x"] [.base (Entry.floating width test).input] (.base .unit) Eff.empty
      (.lastDiscard (floatingSource width test 0)))
    Code p rows (desugarBlock op .tail source)
      (desugarBlock op .tail (PredicateProjectionCalls.resolveBlock rows p source)) := by
  dsimp only
  apply Code.ret
  apply Value.lam
  exact .letIn (floating_code rows p op .other width test key 0 hk) (.ret (.constant .unit))

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
