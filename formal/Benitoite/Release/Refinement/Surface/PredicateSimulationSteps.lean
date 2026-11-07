import Benitoite.Release.Refinement.Surface.PredicateSimulationInvariants
import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionInputs

/-! # 判定の名前解決と構造的な実行の対応

同じ宣言と本体の対応を持つ任意の核を対象とする。元の核の型付けは要求しない。
公開判定の管理用の途中状態には下降する段階を付け、無観測の省略を有限にする。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateRows PredicateResponse
noncomputable section

structure DefinitionRel (source : Program) (rows : PredicateProjection.Table.Rows)
    (left right : Refinement.Def) : Prop where
  tparams : left.tparams = right.tparams
  neffs : left.neffs = right.neffs
  names : left.names = right.names
  params : left.params = right.params
  ret : left.ret = right.ret
  eff : left.eff = right.eff
  ranges : left.rkinds = right.rkinds
  body : Code source rows left.body right.body

structure ImplementationRel (source : Program) (rows : PredicateProjection.Table.Rows)
    (left right : Refinement.ImplDecl) : Prop where
  tparams : left.tparams = right.tparams
  dictionaries : left.dictParams = right.dictParams
  className : left.cls = right.cls
  target : left.target = right.target
  supers : ∀ superclass, Option.Rel (Value source rows) (left.supers superclass) (right.supers superclass)
  methods : ∀ method, Option.Rel (Code source rows) (left.methods method) (right.methods method)

/-- 通常の脱糖と同じbaseを補った核のどちらにも使える、本体と宣言の対応。 -/
structure ProgramRel (source : Program) (rows : PredicateProjection.Table.Rows)
    (P Q : Refinement.Program) : Prop where
  types : P.SameTypes Q
  definitions : ∀ name, Option.Rel (DefinitionRel source rows) (P.defs name) (Q.defs name)
  implementations : ∀ name, Option.Rel (ImplementationRel source rows) (P.impls name) (Q.impls name)
  getters : GetterEnvironment source P

/-- 少なくとも一段を持つ無観測の有限実行。 -/
inductive SilentPlus (P : Refinement.Program) (B : Builtins) (σ : PathEnv) : State → State → Prop
  | one {s t} : Step P B σ s none t → SilentPlus P B σ s t
  | cons {s t u} : Step P B σ s none t → SilentPlus P B σ t u → SilentPlus P B σ s u

theorem SilentPlus.steps {P B σ s t} (h : SilentPlus P B σ s t) : Steps P B σ s [] t := by
  induction h with
  | one h => exact .cons h .nil
  | cons h tail ih => exact .cons h ih

theorem ContRel.append {source rows k l xs ys} (h : ContRel source rows k l) (g : ContRel source rows xs ys) :
    ContRel source rows (k ++ xs) (l ++ ys) := by
  induction h with
  | nil => exact g
  | cons hf hk ih => exact .cons hf ih

theorem StoreRel.fresh {source rows μ ν location} (h : StoreRel source rows μ ν)
    (free : μ location = none) : ν location = none := by
  have related := h location
  rw [free] at related
  cases target : ν location with
  | none => rfl
  | some cell => rw [target] at related; cases related

theorem StoreRel.value {source rows μ ν location v} (h : StoreRel source rows μ ν)
    (found : μ location = some (.val v)) : ∃ w, ν location = some (.val w) ∧ Value source rows v w := by
  have related := h location
  rw [found] at related
  cases target : ν location with
  | none => rw [target] at related; cases related
  | some cell =>
    rw [target] at related
    cases related with
    | some related =>
      cases related with
      | value hv => exact ⟨_,rfl,hv⟩

theorem let_step_unique {P B σ q k μ m n label destination}
    (view : q.view = .letIn m n) (step : Step P B σ (.run q k μ) label destination) :
    label = none ∧ destination = .run (.mk q.capture m) (.letF (.mk q.capture n) :: k) μ := by
  cases step <;> simp_all
  all_goals subst_vars
  all_goals simp_all [Closure.view]

theorem return_let_step_unique {P B σ q n k μ v label destination}
    (view : q.view = .ret v) (step : Step P B σ (.run q (.letF n :: k) μ) label destination) :
    label = none ∧ destination = .run (n.apply [v]) k μ := by
  cases step <;> simp_all
  all_goals subst_vars
  all_goals simp_all [Closure.view]

theorem pure_step_unique {P B σ q k μ name signature ws output label destination}
    (view : q.view = .app (.prim name [] [] []) ws) (lookup : B.sig name = some signature)
    (pure : signature.kind = .pure) (reply : B.delta name [] [] [] ws = some (.val output))
    (step : Step P B σ (.run q k μ) label destination) :
    label = none ∧ destination = .run (.pure (.ret output)) k μ := by
  cases step <;> simp_all [closeVal]
  all_goals subst_vars
  all_goals simp_all [Closure.view]

theorem pure_step_unique_with_types {P B σ q k μ name signature ts es rs ws output label destination}
    (view : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) ws)
    (lookup : B.sig name = some signature) (pure : signature.kind = .pure)
    (reply : B.delta name (Ty.normTys ts) (es.map Eff.norm) rs ws = some (.val output))
    (step : Step P B σ (.run q k μ) label destination) :
    label = none ∧ destination = .run (.pure (.ret output)) k μ := by
  have rangesInjective : Function.Injective (List.map RangeIx.fixed) :=
    fun _ _ same => (List.map_inj_right (fun _ _ equal => RangeIx.fixed.inj equal)).mp same
  cases step <;> simp_all [closeVal,rangesInjective.eq_iff]
  all_goals subst_vars
  all_goals simp_all [Closure.view]

theorem ScalarPhase.related {source rows api entry positions values key cap cap' value target k l μ ν state rank}
    (phase : ScalarPhase api positions values cap k μ state rank)
    (lookup : rows.lookup key = some (.scalar entry)) (count : values.length = api.inputs.length)
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value)
    (simple : SimpleValues values) (hc : Captures source rows cap cap') (hv : Value source rows value target)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    StateRel source rows state (.run (.mk cap' (.app (.prim key [] [] []) [target])) l ν) :=
  .scalarPhase lookup count inputs simple hc hv hk hμ phase

/-- 公開appへ到達するまでの全ての実一段は、任意の継続・ストアの下で段階を一つ下げる。 -/
theorem ScalarPhase.forward_admin {P B σ api positions values cap k μ state rank label destination}
    (phase : ScalarPhase api positions values cap k μ state rank) (simple : SimpleValues values)
    (positive : 0 < rank) (step : Step P B σ state label destination) :
    label = none ∧ ∃ nextRank, ScalarPhase api positions values cap k μ destination nextRank ∧ nextRank < rank := by
  cases phase with
  | chain before remaining split =>
    cases remaining with
    | nil => cases positive
    | cons value remaining =>
      obtain ⟨rfl,rfl⟩ := let_step_unique (by rfl) step
      exact ⟨rfl,⟨_,.argument before value remaining split,by simp only [List.length_cons]; omega⟩⟩
  | argument before value remaining split =>
    obtain ⟨rfl,rfl⟩ := return_let_step_unique (by rfl) step
    have closed : closeVal (cap.extendMany (closeVals cap before)) (value.rename (· + before.length)) = closeVal cap value := by
      have valueSimple := simple value (by rw [split]; simp)
      simpa only [closeVals_length] using valueSimple.close_shiftMany cap (closeVals cap before)
    have capture : (cap.extendMany (closeVals cap before)).extend (closeVal cap value) =
        cap.extendMany (closeVals cap (before ++ [value])) := by
      rw [closeVals_append,Capture.extendMany_append]
      rfl
    have next : ScalarPhase api positions values cap k μ
        (.run (.mk (cap.extendMany (closeVals cap (before ++ [value])))
          (letChain (before.length+1) (remaining.map Comp.ret) (scalarBody api positions values))) k μ)
        (2 * remaining.length) := by
      simpa only [List.length_append,List.length_singleton] using
        ScalarPhase.chain (api := api) (positions := positions) (values := values) (cap := cap)
          (continuation := k) (store := μ) (before ++ [value]) remaining
          (by simpa only [List.append_assoc,List.singleton_append] using split)
    refine ⟨rfl,⟨2 * remaining.length,?_,by omega⟩⟩
    change ScalarPhase api positions values cap k μ
      (.run (.mk ((cap.extendMany (closeVals cap before)).extend
        (closeVal (cap.extendMany (closeVals cap before)) (value.rename (· + before.length))))
        (letChain (before.length+1) (remaining.map Comp.ret) (scalarBody api positions values))) k μ) _
    rw [closed,capture]
    exact next

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
