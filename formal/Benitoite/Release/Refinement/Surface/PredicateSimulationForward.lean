import Benitoite.Release.Refinement.Surface.PredicateSimulationObservationBridge
import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectedSteps
import Benitoite.Release.Refinement.Surface.PredicateSimulationResponseSteps
import Benitoite.Release.Refinement.Surface.PredicateSimulationBuilders
import Benitoite.Release.Refinement.Surface.PredicateSimulationAt
import Benitoite.Release.Refinement.Surface.PredicateSimulationStateOperations
import Benitoite.Release.Refinement.Surface.PredicateSimulationPatternAvoid
import Benitoite.Release.Refinement.ExternalLeafSelection

/-! # 元の実行の一段に対応する、準備後の実行

元の状態の全ての実一段について、準備後の対応する有限実行を構成する。
対応する側が段を進めないのは、管理用の束縛と取り出しの段に限る。
準備後の状態の型付けは、型付きの実行の保存から各段で得る。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateGeneratedNames
noncomputable section

/-- 名前解決の模倣に使う、準備後の核と表の条件と元の核の対応。 -/
structure Setting (source : Program) (rows : PredicateProjection.Table.Rows) (config : Check.BuiltinSource)
    (P Q : Refinement.Program) (σ : PathEnv) : Prop where
  active : CheckPreparation.enabled (.resolved config rows) = true
  program : ProgramRel source rows P Q
  programAvoid : ProgramAvoid (rows.map Prod.fst) P
  wellFormed : Q.WellFormed
  wellTyped : Q.WellTyped (responseTable config rows)
  effects : Q.EffectsOk (responseTable config rows)
  core : (responseTable config rows).CoreAssumptions Q
  pathEnvironment : σ.Valid
  variance : Q.VarianceValid
  valid : ∀ key projection, rows.lookup key = some (.projected projection) → PredicateProjection.Valid Q projection
  included : ∃ externals, StandardModel.Includes externals Q

variable {source : Program} {rows : PredicateProjection.Table.Rows} {config : Check.BuiltinSource}
variable {P Q : Refinement.Program} {σ : PathEnv} {effect : Eff}

/-- 準備後の一段が同期した対応を、型付けと元の禁止名不在とともに持ち上げる。 -/
theorem Setting.sync {first second destination next}
    (setting : Setting source rows config P Q σ)
    (typed : StateTyE Q (responseTable config rows) σ effect second)
    (sync : Step Q (responseTable config rows) σ second none next ∧ StateRel source rows destination next)
    (avoid : NoGeneratedKeys rows destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect first second none destination :=
  ForwardResult.of_step setting.wellFormed setting.wellTyped setting.effects setting.core setting.pathEnvironment
    typed sync.1 sync.2 avoid

theorem Setting.synchronized {first second destination}
    (setting : Setting source rows config P Q σ)
    (typed : StateTyE Q (responseTable config rows) σ effect second)
    (sync : ∃ next, Step Q (responseTable config rows) σ second none next ∧ StateRel source rows destination next)
    (avoid : NoGeneratedKeys rows destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect first second none destination := by
  obtain ⟨next,step,related⟩ := sync
  exact setting.sync typed ⟨step,related⟩ avoid

theorem Setting.synchronizedAt {first second destination} {step : Step P config.builtins σ first none destination}
    (setting : Setting source rows config P Q σ)
    (typed : StateTyE Q (responseTable config rows) σ effect second)
    (sync : SynchronizedAt source rows P Q config.builtins (responseTable config rows) σ first second step)
    (avoid : NoGeneratedKeys rows destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect first second none destination :=
  setting.synchronized typed sync avoid

theorem Setting.responseAt {first second label destination} {step : Step P config.builtins σ first label destination}
    (setting : Setting source rows config P Q σ)
    (typed : StateTyE Q (responseTable config rows) σ effect second)
    (sync : ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      first second step) :
    ForwardResult source rows Q (responseTable config rows) σ effect first second label destination := by
  obtain ⟨next,targetStep,related,avoid⟩ := sync
  exact ForwardResult.of_step setting.wellFormed setting.wellTyped setting.effects setting.core setting.pathEnvironment
    typed targetStep related avoid

theorem Setting.response {first second label destination}
    (setting : Setting source rows config P Q σ)
    (typed : StateTyE Q (responseTable config rows) σ effect second)
    (sync : ∃ next, Step Q (responseTable config rows) σ second label next ∧ StateRel source rows destination next ∧
      StateAvoid (rows.map Prod.fst) destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect first second label destination := by
  obtain ⟨next,step,related,avoid⟩ := sync
  exact ForwardResult.of_step setting.wellFormed setting.wellTyped setting.effects setting.core setting.pathEnvironment
    typed step related avoid

theorem pure_ret_avoid {keys value} (avoid : ValueAvoid keys value) : ClosureAvoid keys (Closure.pure (.ret value)) :=
  ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,avoid⟩

theorem StateAvoid.returned {keys cap value k μ} (avoid : StateAvoid keys (.run (.mk cap (.ret value)) k μ)) :
    ValueAvoid keys (closeVal cap value) := avoid.1.view

/-- 返却の値を読む全ての実一段。 -/
theorem forward_ret (setting : Setting source rows config P Q σ) {cap cap' v w k l μ ν label destination}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.ret v)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.ret w)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.ret v)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.ret v)) k μ) (.run (.mk cap' (.ret w)) l ν) label destination := by
  have valueAvoid := StateAvoid.returned avoid
  have closed := hv.close hc
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Return =>
    rename_i view
    injection view with same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | letF hq =>
        have frames := ContAvoid.cons.mp avoid.2.1
        exact setting.synchronizedAt typed (structural_return hc hv hq hk hμ)
          ⟨ClosureAvoid.apply frames.1 (ValuesAvoid.cons.mpr ⟨valueAvoid,ValuesAvoid.nil _⟩),frames.2,avoid.2.2⟩
  case E_Update =>
    rename_i view
    injection view with same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | update location =>
        exact setting.synchronizedAt typed (structural_update hc hv hk hμ)
          ⟨pure_ret_avoid valueAvoid,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2.set valueAvoid⟩
  case E_Mark =>
    rename_i view
    injection view with same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | mark =>
        exact setting.synchronizedAt typed (structural_mark hc hv hk hμ)
          ⟨pure_ret_avoid valueAvoid,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_HRet =>
    rename_i view
    injection view with same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | handleF hcap clauses =>
        exact setting.synchronizedAt typed (structural_handle_return hc hv hk hμ)
          ⟨pure_ret_avoid valueAvoid,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_Drop =>
    rename_i view found
    injection view with same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | drop location =>
        exact setting.synchronizedAt typed (structural_drop_used hc hv found hk hμ)
          ⟨pure_ret_avoid valueAvoid,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_DropRel =>
    rename_i view found
    injection view with same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | drop location =>
        have saved : ContAvoid (rows.map Prod.fst) _ := avoid.2.2.lookup found
        exact setting.synchronizedAt typed (structural_drop_continuation hc hv found hk hμ)
          ⟨pure_ret_avoid valueAvoid,ContAvoid.append saved.releases (ContAvoid.cons.mp avoid.2.1).2,
            avoid.2.2.set (cell := .used) trivial⟩
  case E_GuardT =>
    rename_i view
    injection view with same
    change closeVal cap v = _ at same
    cases hk with
    | cons hf hk => cases hf with
      | guardF hguard hcap harms hbody =>
        rw [same] at closed
        have target := Value.constant_left closed
        have frames := ContAvoid.cons.mp avoid.2.1
        exact setting.synchronizedAt typed
          (structural_guard_true (q := .mk cap (.ret v)) (r := .mk cap' (.ret w))
            (by change Comp.ret (closeVal cap v) = _; rw [same])
            (by change Comp.ret (closeVal cap' w) = _; rw [target]) hbody hk hμ)
          ⟨frames.1.2.2.2,frames.2,avoid.2.2⟩
  case E_GuardF =>
    rename_i view
    injection view with same
    change closeVal cap v = _ at same
    cases hk with
    | cons hf hk => cases hf with
      | guardF hguard hcap harms hbody =>
        rw [same] at closed
        have target := Value.constant_left closed
        have frames := ContAvoid.cons.mp avoid.2.1
        exact setting.synchronizedAt typed
          (structural_guard_false (q := .mk cap (.ret v)) (r := .mk cap' (.ret w))
            (by change Comp.ret (closeVal cap v) = _; rw [same])
            (by change Comp.ret (closeVal cap' w) = _; rw [target]) hguard hcap harms hk hμ)
          ⟨frames.1.1,frames.1.2.1,frames.1.2.2.1,frames.2,avoid.2.2⟩
  case E_Release =>
    rename_i response view
    injection view with same; change closeVal cap v = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | release hresource =>
        exact setting.responseAt typed (response_release (q := .mk cap (.ret v)) (r := .mk cap' (.ret w))
          setting.active rfl rfl closed hresource response hk hμ avoid)
  case E_RelErr =>
    rename_i response view
    cases hk with
    | cons hf hk => cases hf with
      | release hresource =>
        exact setting.responseAt typed (response_release_error (r := .mk cap' (.ret w))
          setting.active view rfl hresource response hk hμ avoid)

/-- 元の状態の捕捉と本体の名前の不在。 -/
theorem StateAvoid.parts {keys cap body k μ} (avoid : StateAvoid keys (.run (.mk cap body) k μ)) :
    CaptureAvoid keys cap ∧ CodeAvoid keys body ∧ ContAvoid keys k ∧ StoreAvoid keys μ :=
  ⟨avoid.1.capture,avoid.1.code,avoid.2.1,avoid.2.2⟩

theorem forward_let (setting : Setting source rows config P Q σ) {cap cap' m m' n n' k l μ ν label destination}
    (hc : Captures source rows cap cap') (hm : Code source rows m m') (hn : Code source rows n n')
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.letIn m n)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.letIn m' n')) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.letIn m n)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.letIn m n)) k μ) (.run (.mk cap' (.letIn m' n')) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  obtain ⟨first,rest⟩ := CodeAvoid.letIn.mp code
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Let =>
    rename_i view
    injection view with same same'; subst same; subst same'
    exact setting.synchronizedAt typed (structural_let hc hm hn hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨capture,first⟩,ContAvoid.cons.mpr ⟨ClosureAvoid.mk.mpr ⟨capture,rest⟩,stack⟩,store⟩

theorem BuilderAvoid.empty (keys : List PrimName) (kind : BuilderKind) : BuilderAvoid keys kind.empty := by
  cases kind <;> first | trivial | exact ValuesAvoid.nil _

theorem forward_builder (setting : Setting source rows config P Q σ) {cap cap' kind m n k l μ ν label destination}
    (hc : Captures source rows cap cap') (hm : Code source rows m n)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.builderLet kind m)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.builderLet kind n)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.builderLet kind m)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.builderLet kind m)) k μ) (.run (.mk cap' (.builderLet kind n)) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_BuilderNew =>
    rename_i view fresh
    injection view with same same'; subst same; subst same'
    exact setting.synchronizedAt typed (structural_builder hc hm hk hμ fresh)
      ⟨ClosureAvoid.mk.mpr ⟨capture,CodeAvoid.subst (show CodeAvoid _ m from code) _ _ (fun i => by
          cases i <;> first | exact ValueAvoid.constant _ _ | exact ValueAvoid.variable _ _)⟩,
        stack,store.set (BuilderAvoid.empty _ _)⟩

theorem Captures.substKind {cap cap'} (hc : Captures source rows cap cap') (kind : BuilderKind) :
    Refinement.substKind cap.env kind = Refinement.substKind cap'.env kind := by
  cases kind <;> simp only [Refinement.substKind, substTyValues_eq hc.env]

theorem forward_builder_operation (setting : Setting source rows config P Q σ)
    {cap cap' kind op reference vs ws k l μ ν label destination}
    (hc : Captures source rows cap cap') (ha : Values source rows vs ws)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.builderOp kind op reference vs)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.builderOp kind op reference ws)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.builderOp kind op reference vs)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.builderOp kind op reference vs)) k μ) (.run (.mk cap' (.builderOp kind op reference ws)) l ν)
      label destination := by
  have arguments : ValuesAvoid (rows.map Prod.fst) (closeVals cap vs) := valuesNames_avoid.mp avoid.1.view
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_BuilderOp =>
    rename_i reply view found
    have closedArgs := ha.close hc
    simp only [Closure.view, Closure.code, Closure.capture] at view reply ⊢
    injection view with sameKind sameOp sameRef sameArgs; subst sameKind; subst sameOp; subst sameRef; subst sameArgs
    have cellAvoid : BuilderAvoid _ _ := avoid.2.2.lookup found
    have replyAvoid := cellAvoid.apply arguments op
    rw [reply] at replyAvoid
    exact setting.synchronizedAt typed
      (structural_builder_operation rfl
        (by change Comp.builderOp (Refinement.substKind cap'.env kind) _ _ _ = _; rw [← hc.substKind]; rfl)
        closedArgs hk hμ found reply)
      ⟨pure_ret_avoid replyAvoid.2,avoid.2.1,avoid.2.2.set replyAvoid.1⟩
  case E_BuilderErr =>
    rename_i reply view found
    have closedArgs := ha.close hc
    simp only [Closure.view, Closure.code, Closure.capture] at view reply ⊢
    injection view with sameKind sameOp sameRef sameArgs; subst sameKind; subst sameOp; subst sameRef; subst sameArgs
    exact setting.synchronizedAt typed
      (structural_builder_error rfl
        (by change Comp.builderOp (Refinement.substKind cap'.env kind) _ _ _ = _; rw [← hc.substKind]; rfl)
        closedArgs hk hμ found reply)
      ⟨avoid.2.1,avoid.2.2⟩

/-- 生成した鍵でない名前は、生成した行の表に現れない。 -/
theorem rows_lookup_none {name : PrimName} (absent : name ∉ rows.map Prod.fst) : rows.lookup name = none := by
  cases selected : rows.lookup name with
  | none => rfl
  | some entry => exact False.elim (absent (List.mem_map_of_mem (f := Prod.fst) (ScopeSignatures.lookup_mem selected)))

theorem forward_ite (setting : Setting source rows config P Q σ) {cap cap' v w m m' n n' k l μ ν label destination}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (hm : Code source rows m m') (hn : Code source rows n n')
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.ite v m n)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.ite w m' n')) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.ite v m n)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.ite v m n)) k μ) (.run (.mk cap' (.ite w m' n')) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  have parts := NamesAvoid.append.mp (show NamesAvoid _ (valueNames v ++ compNames m ++ compNames n) from code)
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_IfT =>
    rename_i view
    injection view with condition same same'; subst same; subst same'
    exact setting.synchronizedAt typed (structural_if_true hc hv condition hm hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨capture,(NamesAvoid.append.mp parts.1).2⟩,stack,store⟩
  case E_IfF =>
    rename_i view
    injection view with condition same same'; subst same; subst same'
    exact setting.synchronizedAt typed (structural_if_false hc hv condition hn hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨capture,parts.2⟩,stack,store⟩

theorem forward_match (setting : Setting source rows config P Q σ) {cap cap' v w arms targets k l μ ν label destination}
    (hc : Captures source rows cap cap') (hv : Value source rows v w) (ha : Arms source rows arms targets)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.match v arms)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.match w targets)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.match v arms)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.match v arms)) k μ) (.run (.mk cap' (.match w targets)) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  have parts := NamesAvoid.append.mp (show NamesAvoid _ (valueNames v ++ armsNames arms) from code)
  have viewParts := NamesAvoid.append.mp (show NamesAvoid _ (valueNames (closeVal cap v) ++ armsNames arms) from avoid.1.view)
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Match =>
    rename_i view
    injection view with same same'; subst same; subst same'
    exact setting.synchronizedAt typed (structural_match hc hv ha hk hμ)
      ⟨viewParts.1,capture,parts.2,stack,store⟩

theorem forward_lazy (setting : Setting source rows config P Q σ) {cap cap' m n k l μ ν label destination}
    (hc : Captures source rows cap cap') (hm : Code source rows m n)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.lazyC m)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.lazyC n)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.lazyC m)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.lazyC m)) k μ) (.run (.mk cap' (.lazyC n)) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Lazy =>
    rename_i view fresh
    injection view with same; subst same
    exact setting.synchronizedAt typed (structural_lazy hc hm hk hμ fresh)
      ⟨pure_ret_avoid (ValueAvoid.location _ _),stack,
        store.set (cell := .thunk (.mk cap m)) (ClosureAvoid.mk.mpr ⟨capture,code⟩)⟩

theorem forward_use (setting : Setting source rows config P Q σ) {cap cap' v w m n k l μ ν label destination}
    (hc : Captures source rows cap cap') (hv : Value source rows v w) (hm : Code source rows m n)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.use v m)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.use w n)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.use v m)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.use v m)) k μ) (.run (.mk cap' (.use w n)) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  have parts := NamesAvoid.append.mp (show NamesAvoid _ (valueNames v ++ compNames m) from code)
  have viewParts := NamesAvoid.append.mp (show NamesAvoid _ (valueNames (closeVal cap v) ++ compNames m) from avoid.1.view)
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Use =>
    rename_i view
    injection view with same same'; subst same; subst same'
    exact setting.synchronizedAt typed (structural_use hc hv hm hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨capture,parts.2⟩,ContAvoid.cons.mpr ⟨viewParts.1,stack⟩,store⟩

theorem forward_handle (setting : Setting source rows config P Q σ) {cap cap' m n clauses targets k l μ ν label destination}
    (hc : Captures source rows cap cap') (hm : Code source rows m n) (hh : Clauses source rows clauses targets)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.handle m clauses)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.handle n targets)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.handle m clauses)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.handle m clauses)) k μ) (.run (.mk cap' (.handle n targets)) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  have parts := NamesAvoid.append.mp (show NamesAvoid _ (compNames m ++ clausesNames clauses) from code)
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Handle =>
    rename_i view
    injection view with same same'; subst same; subst same'
    exact setting.synchronizedAt typed (structural_handle hc hm hh hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨capture,parts.1⟩,ContAvoid.cons.mpr ⟨⟨capture,parts.2⟩,stack⟩,store⟩

theorem forward_escape (setting : Setting source rows config P Q σ) {cap cap' v w k l μ ν label destination}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.escape v)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.escape w)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.escape v)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.escape v)) k μ) (.run (.mk cap' (.escape w)) l ν) label destination := by
  have valueAvoid : ValueAvoid (rows.map Prod.fst) (closeVal cap v) := avoid.1.view
  have closed := hv.close hc
  have escaped : ClosureAvoid (rows.map Prod.fst) (Closure.pure (.escape (closeVal cap v))) :=
    ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,valueAvoid⟩
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_EscLet =>
    rename_i view
    injection view with same; change closeVal cap v = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | letF hq =>
        exact setting.synchronizedAt typed (structural_escape_let (q := .mk cap (.escape v)) (r := .mk cap' (.escape w))
          rfl rfl closed hk hμ) ⟨escaped,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_EscHandle =>
    rename_i view
    injection view with same; change closeVal cap v = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | handleF hcap clauses =>
        exact setting.synchronizedAt typed (structural_escape_handle (q := .mk cap (.escape v)) (r := .mk cap' (.escape w))
          rfl rfl closed hk hμ) ⟨escaped,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_EscMark =>
    rename_i view
    injection view with same; change closeVal cap v = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | mark =>
        exact setting.synchronizedAt typed (structural_escape_mark (q := .mk cap (.escape v)) (r := .mk cap' (.escape w))
          rfl rfl closed hk hμ) ⟨pure_ret_avoid valueAvoid,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_EscDrop =>
    rename_i view found
    injection view with same; change closeVal cap v = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | drop location =>
        exact setting.synchronizedAt typed (structural_escape_drop_used (q := .mk cap (.escape v)) (r := .mk cap' (.escape w))
          rfl rfl found closed hk hμ) ⟨escaped,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_EscDropRel =>
    rename_i view found
    injection view with same; change closeVal cap v = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | drop location =>
        have saved : ContAvoid (rows.map Prod.fst) _ := avoid.2.2.lookup found
        exact setting.synchronizedAt typed (structural_escape_drop_continuation (q := .mk cap (.escape v)) (r := .mk cap' (.escape w))
          rfl rfl found closed hk hμ)
          ⟨escaped,ContAvoid.append saved.releases (ContAvoid.cons.mp avoid.2.1).2,avoid.2.2.set (cell := .used) trivial⟩
  case E_EscRel =>
    rename_i response view
    injection view with same; change closeVal cap v = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | release hresource =>
        exact setting.responseAt typed (response_escape_release (q := .mk cap (.escape v)) (r := .mk cap' (.escape w))
          setting.active rfl rfl closed hresource response hk hμ avoid)
  case E_EscRelErr =>
    rename_i response view
    injection view with same; change closeVal cap v = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | release hresource =>
        exact setting.responseAt typed (response_escape_release_error (q := .mk cap (.escape v)) (r := .mk cap' (.escape w))
          setting.active rfl rfl hresource response hk hμ avoid)

theorem forward_issue_path_bases (setting : Setting source rows config P Q σ) {cap cap' name k l μ ν label destination}
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.issuePathBases name)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.issuePathBases name)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.issuePathBases name)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.issuePathBases name)) k μ) (.run (.mk cap' (.issuePathBases name)) l ν) label destination := by
  have absent : name ∉ rows.map Prod.fst := (show NamesAvoid _ [name] from avoid.1.code) name (List.mem_singleton_self _)
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_IssuePathBases =>
    rename_i found kind effectName valid view
    injection view with same; subst same
    obtain ⟨next,targetStep,related⟩ := structural_issue_path_bases (source := source) (rows := rows) (cap' := cap')
      (overlay_signature (rows_lookup_none absent) found) kind effectName valid hk hμ
    exact ForwardResult.of_step setting.wellFormed setting.wellTyped setting.effects setting.core setting.pathEnvironment
      typed targetStep related ⟨pure_ret_avoid (NamesAvoid.nil _),avoid.2.1,avoid.2.2⟩

theorem Value.location_left {l : Nat} {w : Val} (h : Value source rows (.loc l) w) : w = .loc l := by
  cases h; rfl

theorem forward_resume (setting : Setting source rows config P Q σ) {cap cap' kv kw v w k l μ ν label destination}
    (hc : Captures source rows cap cap') (hkv : Value source rows kv kw) (hv : Value source rows v w)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.resume kv v)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.resume kw w)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.resume kv v)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.resume kv v)) k μ) (.run (.mk cap' (.resume kw w)) l ν) label destination := by
  have parts := NamesAvoid.append.mp
    (show NamesAvoid _ (valueNames (closeVal cap kv) ++ valueNames (closeVal cap v)) from avoid.1.view)
  have closedK := hkv.close hc
  have closedV := hv.close hc
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Resume =>
    rename_i view found
    injection view with sameK sameV
    change closeVal cap kv = _ at sameK
    change closeVal cap v = _ at sameV
    subst sameV
    rw [sameK] at closedK
    have targetK := Value.location_left closedK
    obtain ⟨cell,targetFound,related⟩ := hμ.lookup found
    cases related with
    | cont saved =>
      have savedAvoid : ContAvoid (rows.map Prod.fst) _ := avoid.2.2.lookup found
      exact setting.sync typed
        ⟨.E_Resume (q := .mk cap' (.resume kw w))
            (by change Comp.resume (closeVal cap' kw) (closeVal cap' w) = _; rw [targetK]) targetFound,
          .run (.pure (.ret closedV)) (saved.append hk) (hμ.set .used)⟩
        ⟨pure_ret_avoid parts.2,ContAvoid.append savedAvoid avoid.2.1,avoid.2.2.set (cell := .used) trivial⟩
  case E_ResumeErr =>
    rename_i view found
    injection view with sameK sameV
    change closeVal cap kv = _ at sameK
    rw [sameK] at closedK
    have targetK := Value.location_left closedK
    obtain ⟨cell,targetFound,related⟩ := hμ.lookup found
    cases related with
    | used =>
      exact setting.sync typed
        ⟨.E_ResumeErr (q := .mk cap' (.resume kw w))
            (by change Comp.resume (closeVal cap' kw) (closeVal cap' w) = _; rw [targetK]) targetFound,
          .error hk hμ⟩
        ⟨avoid.2.1,avoid.2.2⟩

theorem StateTyE.builtin_args {P B σ Eb q k μ b ts es rs ws s}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hsig : B.sig b = some s) :
    ∃ Ψ r ef, BuiltinArgs P B Ψ b s (Ty.normTys ts) (es.map Eff.norm) rs ws r ef := by
  obtain ⟨Ψ,R,a,c,e,e1,hs,hq,_,hk,had,hcl,hkc,hμ⟩ := state
  obtain ⟨r,ef,hargs,_,_⟩ := hq.primitive_view_inputs hP hPB hB hs.wf hs.sorted hs.declared hcl view hsig
  exact ⟨Ψ,r,ef,hargs⟩

theorem Value.primitive_left {b ts es rs} {w : Val} (h : Value source rows (.prim b ts es rs) w) :
    w = .prim b ts es rs := by cases h; rfl
theorem Value.function_left {f ts es rs} {w : Val} (h : Value source rows (.fnRef f ts es rs) w) :
    w = .fnRef f ts es rs := by cases h; rfl
theorem Value.operation_left {o ts} {w : Val} (h : Value source rows (.op o ts) w) : w = .op o ts := by cases h; rfl
theorem Value.raise_left {t e} {w : Val} (h : Value source rows (.raise t e) w) : w = .raise t e := by cases h; rfl
theorem Value.external_left {f ts} {w : Val} (h : Value source rows (.externalRef f ts) w) :
    w = .externalRef f ts := by cases h; rfl

theorem Values.nil_left {ys : List Val} (h : Values source rows [] ys) : ys = [] := by cases h; rfl
theorem Values.single_left {x : Val} {ys : List Val} (h : Values source rows [x] ys) :
    ∃ y, ys = [y] ∧ Value source rows x y := by
  cases h with
  | cons hx rest => cases rest; exact ⟨_,rfl,hx⟩
theorem Values.pair_left {x z : Val} {ys : List Val} (h : Values source rows [x,z] ys) :
    ∃ y u, ys = [y,u] ∧ Value source rows x y ∧ Value source rows z u := by
  cases h with
  | cons hx rest => cases rest with
    | cons hz rest => cases rest; exact ⟨_,_,rfl,hx,hz⟩

/-- 分割した継続の各部分の禁止名不在。 -/
theorem ContAvoid.split {keys k beforeFrames hcap clauses rest}
    (avoid : ContAvoid keys k) (same : k = beforeFrames ++ .handleF hcap clauses :: rest) :
    ContAvoid keys beforeFrames ∧ (CaptureAvoid keys hcap ∧ ClausesAvoid keys clauses) ∧ ContAvoid keys rest := by
  subst same
  refine ⟨fun f member => avoid f (List.mem_append_left _ member),avoid (.handleF hcap clauses) (by simp),
    fun f member => avoid f (List.mem_append_right _ (List.mem_cons_of_mem _ member))⟩

theorem prim_avoid {keys name ts es rs} (absent : name ∉ keys) : ValueAvoid keys (.prim name ts es rs) := by
  intro other member
  simp only [valueNames,List.mem_singleton] at member
  subst other
  exact absent

theorem app_avoid {keys function values} (head : ValueAvoid keys function) (arguments : ValuesAvoid keys values) :
    CodeAvoid keys (.app function values) := NamesAvoid.append.mpr ⟨head,valuesNames_avoid.mpr arguments⟩

theorem forward_app [StandardModel.RowEnv Q (responseTable config rows)]
    (setting : Setting source rows config P Q σ) {cap cap' f g vs ws k l μ ν label destination}
    (hc : Captures source rows cap cap') (hf : Value source rows f g) (ha : Values source rows vs ws)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.app f vs)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.app g ws)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.app f vs)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.app f vs)) k μ) (.run (.mk cap' (.app g ws)) l ν) label destination := by
  have closedF := hf.close hc
  have closedA := ha.close hc
  have viewParts := NamesAvoid.append.mp
    (show NamesAvoid _ (valueNames (closeVal cap f) ++ valuesNames (closeVals cap vs)) from avoid.1.view)
  have argsAvoid : ValuesAvoid (rows.map Prod.fst) (closeVals cap vs) := valuesNames_avoid.mp viewParts.2
  have headAvoid : ValueAvoid (rows.map Prod.fst) (closeVal cap f) := viewParts.1
  have primAbsent : ∀ {b ts es rs}, closeVal cap f = .prim b ts es rs → rows.lookup b = none := by
    intro b ts es rs same
    rw [same] at headAvoid
    exact rows_lookup_none (headAvoid b (List.mem_singleton_self _))
  have primTarget : ∀ {b ts es rs}, closeVal cap f = .prim b ts es rs →
      (Closure.mk cap' (.app g ws)).view = .app (.prim b ts es rs) (closeVals cap' ws) := by
    intro b ts es rs same
    rw [same] at closedF
    change Comp.app (closeVal cap' g) (closeVals cap' ws) = _
    rw [Value.primitive_left closedF]
  have stack := avoid.2.1
  have store := avoid.2.2
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Lam =>
    rename_i function arity view
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    subst sameF; subst sameA
    have bodyAvoid : ValueAvoid (rows.map Prod.fst) (closeVal Capture.empty (closeVal cap f)) :=
      headAvoid.close (CaptureAvoid.empty _)
    rw [function] at bodyAvoid
    exact setting.synchronizedAt typed (structural_lambda hc hf ha function arity hk hμ)
      ⟨ClosureAvoid.apply bodyAvoid argsAvoid,stack.markPush,store⟩
  case E_ExternalApply =>
    rename_i view
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    subst sameA
    rw [sameF] at closedF
    have targetF := Value.external_left closedF
    exact setting.sync typed
      ⟨.E_ExternalApply (q := .mk cap' (.app g ws)) (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [targetF]; try rfl),
        .run (ClosedCode.pure (.externalCall closedA)) hk hμ⟩
      ⟨ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,valuesNames_avoid.mpr argsAvoid⟩,stack,store⟩
  case E_PathBasesApply =>
    rename_i found kind view
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    rw [sameA] at closedA
    have targetA := Values.nil_left closedA
    have absent := primAbsent sameF
    have second := primTarget sameF
    rw [targetA] at second
    rw [sameF] at headAvoid
    exact setting.sync typed
      ⟨.E_PathBasesApply second (overlay_signature absent found) kind,.run (.mk hc (.pathBases _)) hk hμ⟩
      ⟨ClosureAvoid.mk.mpr ⟨avoid.1.capture,headAvoid⟩,stack,store⟩
  case E_Fun =>
    rename_i found arity types effects view
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    subst sameA
    rw [sameF] at closedF
    have targetF := Value.function_left closedF
    have bodyAvoid := setting.programAvoid.1 _ _ found
    exact setting.synchronizedAt typed
      (structural_function (q := .mk cap (.app f vs)) (r := .mk cap' (.app g ws)) setting.program
        (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF]; try rfl)
        (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [targetF]; try rfl) found closedA arity types effects hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨(CaptureAvoid.empty _).extendMany argsAvoid,(bodyAvoid.instR _).substTy 0 _ _⟩,
        stack.markPush,store⟩
  case E_Prim =>
    rename_i found kind response view
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    subst sameA
    have targetSig := overlay_signature (primAbsent sameF) found
    obtain ⟨Ψ,r,ef,args⟩ := StateTyE.builtin_args setting.wellFormed setting.wellTyped setting.core typed (primTarget sameF) targetSig
    exact setting.responseAt typed (response_primitive setting.active setting.core
      (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF]; try rfl) (primTarget sameF) found kind response args closedA hk hμ avoid)
  case E_Err =>
    rename_i found kind response view
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    subst sameA
    have targetSig := overlay_signature (primAbsent sameF) found
    obtain ⟨Ψ,r,ef,args⟩ := StateTyE.builtin_args setting.wellFormed setting.wellTyped setting.core typed (primTarget sameF) targetSig
    exact setting.responseAt typed (response_primitive_error setting.active setting.core
      (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF]; try rfl) (primTarget sameF) found kind response args closedA hk hμ avoid)
  case E_IO =>
    rename_i found kind response view unhandled
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    subst sameA
    have targetSig := overlay_signature (primAbsent sameF) found
    obtain ⟨Ψ,r,ef,args⟩ := StateTyE.builtin_args setting.wellFormed setting.wellTyped setting.core typed (primTarget sameF) targetSig
    exact setting.responseAt typed (response_io setting.active
      (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF]; try rfl) (primTarget sameF) found kind unhandled response args closedA hk hμ avoid)
  case E_IOErr =>
    rename_i found kind response view unhandled
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    subst sameA
    have targetSig := overlay_signature (primAbsent sameF) found
    obtain ⟨Ψ,r,ef,args⟩ := StateTyE.builtin_args setting.wellFormed setting.wellTyped setting.core typed (primTarget sameF) targetSig
    exact setting.responseAt typed (response_io_error setting.active
      (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF]; try rfl) (primTarget sameF) found kind unhandled response args closedA hk hμ avoid)
  case E_Exit =>
    rename_i found kind response view unhandled
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    subst sameA
    have targetSig := overlay_signature (primAbsent sameF) found
    obtain ⟨Ψ,r,ef,args⟩ := StateTyE.builtin_args setting.wellFormed setting.wellTyped setting.core typed (primTarget sameF) targetSig
    exact setting.responseAt typed (response_exit setting.active
      (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF]; try rfl) (primTarget sameF) found kind unhandled response args closedA hk hμ avoid)
  case E_RefNew =>
    rename_i found kind view fresh
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    rw [sameA] at closedA argsAvoid
    obtain ⟨target,targetA,related⟩ := Values.single_left closedA
    have second := primTarget sameF
    rw [targetA] at second
    exact setting.synchronizedAt typed
      (structural_reference_new (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF,sameA]; try rfl) second
        found (overlay_signature (primAbsent sameF) found) kind related hk hμ fresh)
      ⟨pure_ret_avoid (ValueAvoid.location _ _),stack,store.set (cell := .val _) (ValuesAvoid.cons.mp argsAvoid).1⟩
  case E_RefGet =>
    rename_i found kind view cell
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    rw [sameA] at closedA
    obtain ⟨target,targetA,related⟩ := Values.single_left closedA
    rw [Value.location_left related] at targetA
    have second := primTarget sameF
    rw [targetA] at second
    exact setting.synchronizedAt typed
      (structural_reference_get (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF,sameA]; try rfl) second
        found (overlay_signature (primAbsent sameF) found) kind hk hμ cell)
      ⟨pure_ret_avoid (store.lookup cell),stack,store⟩
  case E_RefSet =>
    rename_i found kind view
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    rw [sameA] at closedA argsAvoid
    obtain ⟨location,target,targetA,relatedLocation,related⟩ := Values.pair_left closedA
    rw [Value.location_left relatedLocation] at targetA
    have second := primTarget sameF
    rw [targetA] at second
    exact setting.synchronizedAt typed
      (structural_reference_set (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF,sameA]; try rfl) second
        found (overlay_signature (primAbsent sameF) found) kind related hk hμ)
      ⟨pure_ret_avoid (ValueAvoid.constant _ _),stack,
        store.set (cell := .val _) (ValuesAvoid.cons.mp (ValuesAvoid.cons.mp argsAvoid).2).1⟩
  case E_RefUpdate =>
    rename_i found kind view
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    rw [sameA] at closedA argsAvoid
    obtain ⟨location,target,targetA,relatedLocation,related⟩ := Values.pair_left closedA
    rw [Value.location_left relatedLocation] at targetA
    have second := primTarget sameF
    rw [targetA] at second
    have prefixed : ∀ key ∈ rows.map Prod.fst, key.startsWith "%Predicate." = true := by
      intro key member
      obtain ⟨row,rowMember,rfl⟩ := List.mem_map.mp member
      exact List.all_eq_true.mp (Bool.and_eq_true_iff.mp setting.active).2 row rowMember
    have references := enabled_references_avoid (CheckPreparation.enabled_resolved_base setting.active) prefixed
    have functionAvoid := (ValuesAvoid.cons.mp (ValuesAvoid.cons.mp argsAvoid).2).1
    exact setting.synchronizedAt typed
      (structural_reference_update (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF,sameA]; try rfl) second
        found (overlay_signature (primAbsent sameF) found) kind rfl rfl related hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,CodeAvoid.letIn.mpr ⟨app_avoid (prim_avoid references.1)
          (ValuesAvoid.cons.mpr ⟨ValueAvoid.location _ _,ValuesAvoid.nil _⟩),
          CodeAvoid.letIn.mpr ⟨app_avoid (functionAvoid.rename _) (ValuesAvoid.cons.mpr ⟨ValueAvoid.variable _ _,ValuesAvoid.nil _⟩),
            app_avoid (prim_avoid references.2)
              (ValuesAvoid.cons.mpr ⟨ValueAvoid.location _ _,ValuesAvoid.cons.mpr ⟨ValueAvoid.variable _ _,ValuesAvoid.nil _⟩⟩)⟩⟩⟩,
        stack,store⟩
  case E_ForceDone =>
    rename_i found kind view cell
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    rw [sameA] at closedA
    obtain ⟨target,targetA,related⟩ := Values.single_left closedA
    rw [Value.location_left related] at targetA
    have second := primTarget sameF
    rw [targetA] at second
    exact setting.synchronizedAt typed
      (structural_force_done (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF,sameA]; try rfl) second
        found (overlay_signature (primAbsent sameF) found) kind hk hμ cell)
      ⟨pure_ret_avoid (store.lookup cell),stack,store⟩
  case E_Force =>
    rename_i found kind view cell
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    rw [sameA] at closedA
    obtain ⟨target,targetA,related⟩ := Values.single_left closedA
    rw [Value.location_left related] at targetA
    have second := primTarget sameF
    rw [targetA] at second
    exact setting.synchronizedAt typed
      (structural_force_thunk (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF,sameA]; try rfl) second
        found (overlay_signature (primAbsent sameF) found) kind hk hμ cell)
      ⟨store.lookup cell,ContAvoid.cons.mpr ⟨trivial,stack⟩,store⟩
  case E_Op =>
    rename_i found view split fresh
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    subst sameA
    rw [sameF] at closedF
    have targetF := Value.operation_left closedF
    obtain ⟨before,⟨handlerCapture,clauses⟩,after⟩ := stack.split split.1
    exact setting.synchronizedAt typed
      (structural_operation (q := .mk cap (.app f vs)) (r := .mk cap' (.app g ws))
        (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF]; try rfl)
        (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [targetF]; try rfl) closedA hk hμ split found fresh)
      ⟨ClosureAvoid.mk.mpr ⟨handlerCapture.extendMany (ValuesAvoid.append.mpr ⟨argsAvoid,
          ValuesAvoid.cons.mpr ⟨ValueAvoid.location _ _,ValuesAvoid.nil _⟩⟩),
          (clauses.find_body found).substTy 0 _ _⟩,
        ContAvoid.cons.mpr ⟨trivial,after⟩,
        store.set (cell := .cont _) (ContAvoid.append before (ContAvoid.cons.mpr ⟨⟨handlerCapture,clauses⟩,ContAvoid.nil _⟩))⟩
  case E_OpFail =>
    rename_i view split fresh
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    rw [sameF] at closedF
    rw [sameA] at closedA argsAvoid
    have targetF := Value.raise_left closedF
    obtain ⟨target,targetA,related⟩ := Values.single_left closedA
    obtain ⟨before,⟨handlerCapture,clauses⟩,after⟩ := stack.split split.1
    have bodyAvoid : CodeAvoid (rows.map Prod.fst) _ := (NamesAvoid.append.mp clauses).1
    exact setting.synchronizedAt typed
      (structural_fail_operation (q := .mk cap (.app f vs)) (r := .mk cap' (.app g ws))
        (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF,sameA]; try rfl)
        (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [targetF,targetA]; try rfl) related hk hμ split fresh)
      ⟨ClosureAvoid.mk.mpr ⟨handlerCapture.extendMany (ValuesAvoid.cons.mpr ⟨(ValuesAvoid.cons.mp argsAvoid).1,
          ValuesAvoid.cons.mpr ⟨ValueAvoid.location _ _,ValuesAvoid.nil _⟩⟩),
          bodyAvoid.substTy 0 _ _⟩,
        ContAvoid.cons.mpr ⟨trivial,after⟩,
        store.set (cell := .cont _) (ContAvoid.append before (ContAvoid.cons.mpr ⟨⟨handlerCapture,clauses⟩,ContAvoid.nil _⟩))⟩
  case E_OpPrim =>
    rename_i found kind clause view split fresh
    injection view with sameF sameA
    change closeVal cap f = _ at sameF
    change closeVals cap vs = _ at sameA
    subst sameA
    obtain ⟨before,⟨handlerCapture,clauses⟩,after⟩ := stack.split split.1
    exact setting.synchronizedAt typed
      (structural_primitive_operation (q := .mk cap (.app f vs))
        (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sameF]; try rfl) (primTarget sameF)
        found (overlay_signature (primAbsent sameF) found) kind closedA hk hμ split clause fresh)
      ⟨ClosureAvoid.mk.mpr ⟨handlerCapture.extendMany (ValuesAvoid.append.mpr ⟨argsAvoid,
          ValuesAvoid.cons.mpr ⟨ValueAvoid.location _ _,ValuesAvoid.nil _⟩⟩),
          (clauses.find_body clause).substTy 0 _ _⟩,
        ContAvoid.cons.mpr ⟨trivial,after⟩,
        store.set (cell := .cont _) (ContAvoid.append before (ContAvoid.cons.mpr ⟨⟨handlerCapture,clauses⟩,ContAvoid.nil _⟩))⟩

theorem forward_external_call (setting : Setting source rows config P Q σ) {cap cap' function ts vs ws k l μ ν label destination}
    (hc : Captures source rows cap cap') (ha : Values source rows vs ws)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.externalCall function ts vs)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.externalCall function ts ws)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.externalCall function ts vs)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.externalCall function ts vs)) k μ) (.run (.mk cap' (.externalCall function ts ws)) l ν)
      label destination := by
  have closedA := ha.close hc
  have second : (Closure.mk cap' (.externalCall function ts ws)).view =
      .externalCall function (ts.map cap.closeTy) (closeVals cap' ws) := by
    change Comp.externalCall function (ts.map cap'.closeTy) (closeVals cap' ws) = _
    rw [hc.closeTy]
  obtain ⟨Ψ,declaration,a,e,targetFound,args⟩ := StateTyE.external_args setting.wellFormed setting.wellTyped setting.core
    typed second
  have sameExternal : P.externalFunction function = Q.externalFunction function := by
    simp only [Program.externalFunction,setting.program.types.externals]
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_External =>
    rename_i found response receive view
    injection view with sameF sameT sameA
    subst sameF; subst sameT; subst sameA
    rw [sameExternal,targetFound] at found
    cases found
    obtain ⟨formed,variance⟩ := And.intro setting.wellFormed setting.variance
    exact setting.responseAt typed (response_external setting.program.types formed variance setting.core rfl second
      (by rw [sameExternal]; exact targetFound) response receive args closedA hk hμ avoid)
  case E_ExternalErr =>
    rename_i found response receive view
    injection view with sameF sameT sameA
    subst sameF; subst sameT; subst sameA
    rw [sameExternal,targetFound] at found
    cases found
    exact setting.responseAt typed (response_external_error setting.program.types setting.wellFormed setting.variance rfl second
      (by rw [sameExternal]; exact targetFound) response receive args closedA hk hμ avoid)

theorem Value.dictionary_left {i ts vs} {w : Val} (h : Value source rows (.dict i ts vs) w) :
    ∃ ws, w = .dict i ts ws ∧ Values source rows vs ws := by
  cases h with
  | dictionary related => exact ⟨_,rfl,related⟩

theorem forward_method (setting : Setting source rows config P Q σ)
    {cap cap' d d' method types effects vs ws k l μ ν label destination}
    (hc : Captures source rows cap cap') (hd : Value source rows d d') (ha : Values source rows vs ws)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.meth d method types effects vs)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.meth d' method types effects ws)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.meth d method types effects vs)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.meth d method types effects vs)) k μ) (.run (.mk cap' (.meth d' method types effects ws)) l ν)
      label destination := by
  have closedD := hd.close hc
  have closedA := ha.close hc
  have viewParts := NamesAvoid.append.mp
    (show NamesAvoid _ (valueNames (closeVal cap d) ++ valuesNames (closeVals cap vs)) from avoid.1.view)
  have argsAvoid : ValuesAvoid (rows.map Prod.fst) (closeVals cap vs) := valuesNames_avoid.mp viewParts.2
  have second : (Closure.mk cap' (.meth d' method types effects ws)).view =
      .meth (closeVal cap' d') method (types.map cap.closeTy) (effects.map cap.closeEff) (closeVals cap' ws) := by
    change Comp.meth (closeVal cap' d') method (types.map cap'.closeTy) (effects.map cap'.closeEff) (closeVals cap' ws) = _
    rw [hc.closeTy,hc.closeEff]
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Meth =>
    rename_i found methodFound classFound methodSignature argumentsCount dictionariesCount typesCount methodTypesCount
      effectsCount view
    injection view with sameD sameM sameT sameE sameA
    change closeVal cap d = _ at sameD
    subst sameM; subst sameT; subst sameE; subst sameA
    rw [sameD] at closedD viewParts
    obtain ⟨targetDictionaries,targetD,dictionariesRel⟩ := Value.dictionary_left closedD
    rw [targetD] at second
    have dictionariesAvoid : ValuesAvoid (rows.map Prod.fst) _ := valuesNames_avoid.mp viewParts.1
    have bodyAvoid := (setting.programAvoid.2 _ _ found).1 _ _ methodFound
    exact setting.synchronizedAt typed
      (structural_method (q := .mk cap (.meth d method types effects vs)) setting.program
        (by change Comp.meth (closeVal cap d) method (types.map cap.closeTy) (effects.map cap.closeEff) (closeVals cap vs) = _; rw [sameD]; rfl) second found methodFound classFound methodSignature
        argumentsCount dictionariesCount typesCount methodTypesCount effectsCount dictionariesRel closedA hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨(CaptureAvoid.empty _).extendMany (ValuesAvoid.append.mpr ⟨dictionariesAvoid,argsAvoid⟩),
          bodyAvoid.substTy 0 _ _⟩,avoid.2.1.markPush,avoid.2.2⟩
  case E_Super =>
    rename_i found view
    injection view with sameD sameM sameT sameE sameA
    change closeVal cap d = _ at sameD
    subst sameD; subst sameM; subst sameT; subst sameE; subst sameA
    have resultAvoid := ValueAvoid.superStep setting.programAvoid viewParts.1 found
    exact setting.synchronizedAt typed
      (structural_super (q := .mk cap (.meth d method types effects vs)) setting.program rfl second closedD closedA found hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,NamesAvoid.append.mpr ⟨resultAvoid,valuesNames_avoid.mpr argsAvoid⟩⟩,
        avoid.2.1,avoid.2.2⟩

theorem forward_match_run (setting : Setting source rows config P Q σ)
    {v w cap cap' arms targets next k l μ ν label destination}
    (hv : Value source rows v w) (hc : Captures source rows cap cap') (ha : Arms source rows arms targets)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.matchRun v cap arms next k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.matchRun w cap' targets next l ν))
    (step : Step P config.builtins σ (.matchRun v cap arms next k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.matchRun v cap arms next k μ) (.matchRun w cap' targets next l ν) label destination := by
  obtain ⟨valueAvoid,captureAvoid,armsAvoid,stack,store⟩ := avoid
  cases step with
  | E_MatchSkip found missed =>
    exact setting.synchronizedAt typed (structural_match_skip hc hv ha found missed hk hμ)
      ⟨valueAvoid,captureAvoid,armsAvoid,stack,store⟩
  | E_MatchBody found matched =>
    exact setting.synchronizedAt typed (structural_match_body hc hv ha found matched hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨captureAvoid.extendMany (valueAvoid.firstAlt matched),(armsAvoid.get found).1⟩,stack,store⟩
  | E_MatchGuard found matched =>
    have bound := captureAvoid.extendMany (valueAvoid.firstAlt matched)
    exact setting.synchronizedAt typed (structural_match_guard hc hv ha found matched hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨bound,(armsAvoid.get found).2 _ rfl⟩,
        ContAvoid.cons.mpr ⟨⟨valueAvoid,captureAvoid,armsAvoid,ClosureAvoid.mk.mpr ⟨bound,(armsAvoid.get found).1⟩⟩,stack⟩,
        store⟩

theorem forward_error (setting : Setting source rows config P Q σ) {errors k l μ ν label destination}
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.error errors k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.error errors l ν))
    (step : Step P config.builtins σ (.error errors k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect (.error errors k μ) (.error errors l ν) label destination := by
  obtain ⟨stack,store⟩ := avoid
  cases hk with
  | nil => cases step
  | cons hf hk =>
    have rest := (ContAvoid.cons.mp stack).2
    cases step with
    | E_ErrPopLet => exact setting.synchronizedAt typed (structural_error_pop (.letF _) hf hk hμ) ⟨rest,store⟩
    | E_ErrPopMark => exact setting.synchronizedAt typed (structural_error_pop .mark hf hk hμ) ⟨rest,store⟩
    | E_ErrPopUpdate => exact setting.synchronizedAt typed (structural_error_pop (.update _) hf hk hμ) ⟨rest,store⟩
    | E_ErrPopHandle => exact setting.synchronizedAt typed (structural_error_pop (.handleF _ _) hf hk hμ) ⟨rest,store⟩
    | E_ErrPopGuard => exact setting.synchronizedAt typed (structural_error_pop (.guardF _ _ _ _ _) hf hk hμ) ⟨rest,store⟩
    | E_ErrRel response =>
      cases hf with
      | release hresource => exact setting.responseAt typed (response_error_release setting.active hresource response hk hμ ⟨stack,store⟩)
    | E_ErrRelErr response =>
      cases hf with
      | release hresource =>
        exact setting.responseAt typed (response_error_release_error setting.active hresource response hk hμ ⟨stack,store⟩)
    | E_ErrDrop found =>
      cases hf with
      | drop location => exact setting.synchronizedAt typed (structural_error_drop_used found hk hμ) ⟨rest,store⟩
    | E_ErrDropRel found =>
      cases hf with
      | drop location =>
        have saved : ContAvoid (rows.map Prod.fst) _ := store.lookup found
        exact setting.synchronizedAt typed (structural_error_drop_continuation found hk hμ)
          ⟨ContAvoid.append saved.releases rest,store.set (cell := .used) trivial⟩

theorem forward_exit (setting : Setting source rows config P Q σ) {code errors k l μ ν label destination}
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.exit code errors k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.exit code errors l ν))
    (step : Step P config.builtins σ (.exit code errors k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.exit code errors k μ) (.exit code errors l ν) label destination := by
  obtain ⟨stack,store⟩ := avoid
  cases hk with
  | nil => cases step
  | cons hf hk =>
    have rest := (ContAvoid.cons.mp stack).2
    cases step with
    | E_ExitPopLet => exact setting.synchronizedAt typed (structural_exit_pop (.letF _) hf hk hμ) ⟨rest,store⟩
    | E_ExitPopMark => exact setting.synchronizedAt typed (structural_exit_pop .mark hf hk hμ) ⟨rest,store⟩
    | E_ExitPopUpdate => exact setting.synchronizedAt typed (structural_exit_pop (.update _) hf hk hμ) ⟨rest,store⟩
    | E_ExitPopHandle => exact setting.synchronizedAt typed (structural_exit_pop (.handleF _ _) hf hk hμ) ⟨rest,store⟩
    | E_ExitPopGuard => exact setting.synchronizedAt typed (structural_exit_pop (.guardF _ _ _ _ _) hf hk hμ) ⟨rest,store⟩
    | E_ExitRel response =>
      cases hf with
      | release hresource => exact setting.responseAt typed (response_exit_release setting.active hresource response hk hμ ⟨stack,store⟩)
    | E_ExitRelErr response =>
      cases hf with
      | release hresource =>
        exact setting.responseAt typed (response_exit_release_error setting.active hresource response hk hμ ⟨stack,store⟩)
    | E_ExitDrop found =>
      cases hf with
      | drop location => exact setting.synchronizedAt typed (structural_exit_drop_used found hk hμ) ⟨rest,store⟩
    | E_ExitDropRel found =>
      cases hf with
      | drop location =>
        have saved : ContAvoid (rows.map Prod.fst) _ := store.lookup found
        exact setting.synchronizedAt typed (structural_exit_drop_continuation found hk hμ)
          ⟨ContAvoid.append saved.releases rest,store.set (cell := .used) trivial⟩

theorem at_request_avoid {keys : List PrimName} {B : Builtins} {name input} (avoid : ValueAvoid keys input)
    (constructor : ConName) (types : List Ty) (bound : RangeExpr) (snapshot : Option PathEnv) (target : Scope.Domain.Target) :
    ValueAvoid keys (.con constructor types [.checkedAt bound snapshot target (AtRequest B name input)]) := by
  unfold AtRequest
  split
  · exact NamesAvoid.append.mpr ⟨NamesAvoid.nil _,NamesAvoid.nil _⟩
  · exact NamesAvoid.append.mpr ⟨avoid,NamesAvoid.nil _⟩

theorem forward_check_at [StandardModel.RowEnv Q (responseTable config rows)]
    (setting : Setting source rows config P Q σ)
    {cap cap' kind name shape bases bases' pattern pattern' input input' index k l μ ν label destination}
    (hc : Captures source rows cap cap') (hb : OptionalValue source rows bases bases')
    (hp : Value source rows pattern pattern') (hi : Value source rows input input')
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.checkAt kind name shape bases pattern input index)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect
      (.run (.mk cap' (.checkAt kind name shape bases' pattern' input' index)) l ν))
    (step : Step P config.builtins σ (.run (.mk cap (.checkAt kind name shape bases pattern input index)) k μ) label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect
      (.run (.mk cap (.checkAt kind name shape bases pattern input index)) k μ)
      (.run (.mk cap' (.checkAt kind name shape bases' pattern' input' index)) l ν) label destination := by
  have viewParts := NamesAvoid.append.mp
    (show NamesAvoid _ (optionalNames (bases.map (closeVal cap)) ++ valueNames (closeVal cap pattern) ++
      valueNames (closeVal cap input)) from avoid.1.view)
  have patternAvoid : ValueAvoid (rows.map Prod.fst) (closeVal cap pattern) := (NamesAvoid.append.mp viewParts.1).2
  have inputAvoid : ValueAvoid (rows.map Prod.fst) (closeVal cap input) := viewParts.2
  obtain ⟨externals,included⟩ := setting.included
  have equal : bases.map (closeVal cap) = bases'.map (closeVal cap') ∧
      closeVal cap pattern = closeVal cap' pattern' ∧ closeVal cap input = closeVal cap' input' := by
    obtain ⟨Ψ,R,a,c,e,e1,hs,hq,_⟩ := typed
    obtain ⟨Γ,Φ,capture,admissible,_⟩ := ClosureTy.at_inputs hq rfl
    exact at_inputs_equal included setting.wellFormed setting.variance setting.wellTyped setting.core
      hs.wf hs.sorted hs.declared capture admissible hc hb hp hi
  obtain ⟨baseEq,patternEq,inputEq⟩ := equal
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_AtOk =>
    rename_i current accepted code prepared
    injection code with sameK sameN sameS sameB sameP sameI sameX
    subst sameK; subst sameN; subst sameS; subst sameB; subst sameP; subst sameI; subst sameX
    obtain ⟨targetStep,related⟩ := at_ok_forward (Q := Q) (D := responseTable config rows) (shape := shape) hc hk hμ rfl rfl
      baseEq patternEq inputEq prepared current accepted
    exact setting.sync typed ⟨targetStep,related⟩
      ⟨pure_ret_avoid (at_request_avoid inputAvoid _ _ _ _ _),avoid.2.1,avoid.2.2⟩
  case E_AtError =>
    rename_i current failed code prepared
    injection code with sameK sameN sameS sameB sameP sameI sameX
    subst sameK; subst sameN; subst sameS; subst sameB; subst sameP; subst sameI; subst sameX
    obtain ⟨targetStep,related⟩ := at_error_forward (Q := Q) (D := responseTable config rows) (shape := shape) hc hk hμ rfl rfl
      baseEq patternEq inputEq prepared current failed
    exact setting.sync typed ⟨targetStep,related⟩
      ⟨pure_ret_avoid (NamesAvoid.append.mpr ⟨at_check_noMint patternAvoid inputAvoid,NamesAvoid.nil _⟩),
        avoid.2.1,avoid.2.2⟩
  case E_AtPrepareError =>
    rename_i code failed
    injection code with sameK sameN sameS sameB sameP sameI sameX
    subst sameK; subst sameN; subst sameS; subst sameB; subst sameP; subst sameI; subst sameX
    obtain ⟨targetStep,related⟩ := at_prepare_error_forward (Q := Q) (D := responseTable config rows) (shape := shape)
      hc hk hμ rfl rfl baseEq patternEq inputEq failed
    exact setting.sync typed ⟨targetStep,related⟩
      ⟨pure_ret_avoid (NamesAvoid.append.mpr ⟨at_prepare_noMint patternAvoid inputAvoid failed,NamesAvoid.nil _⟩),
        avoid.2.1,avoid.2.2⟩

/-- 元の状態の全ての実一段は、準備後の対応する有限実行を持つ。 -/
theorem StateRel.forward [StandardModel.RowLookup config.builtins] [StandardModel.RowEnv Q (responseTable config rows)]
    (setting : Setting source rows config P Q σ) {s t label destination}
    (related : StateRel source rows s t) (avoid : NoGeneratedKeys rows s)
    (typed : StateTyE Q (responseTable config rows) σ effect t)
    (step : Step P config.builtins σ s label destination) :
    ForwardResult source rows Q (responseTable config rows) σ effect s t label destination := by
  induction related generalizing label destination with
  | run closure stack store =>
    cases closure with
    | mk hc code =>
      cases code with
      | builder hm => exact forward_builder setting hc hm stack store avoid typed step
      | builderOp ha => exact forward_builder_operation setting hc ha stack store avoid typed step
      | ret hv => exact forward_ret setting hc hv stack store avoid typed step
      | letIn hm hn => exact forward_let setting hc hm hn stack store avoid typed step
      | app hf ha => exact forward_app setting hc hf ha stack store avoid typed step
      | ite hv hm hn => exact forward_ite setting hc hv hm hn stack store avoid typed step
      | matchC hv ha => exact forward_match setting hc hv ha stack store avoid typed step
      | lazyC hm => exact forward_lazy setting hc hm stack store avoid typed step
      | escape hv => exact forward_escape setting hc hv stack store avoid typed step
      | use hv hm => exact forward_use setting hc hv hm stack store avoid typed step
      | handle hm hh => exact forward_handle setting hc hm hh stack store avoid typed step
      | resume hv hkv => exact forward_resume setting hc hkv hv stack store avoid typed step
      | externalCall ha => exact forward_external_call setting hc ha stack store avoid typed step
      | pathBases b => exact forward_issue_path_bases setting stack store avoid typed step
      | checkAt hb hp hi => exact forward_check_at setting hc hb hp hi stack store avoid typed step
      | method hd ha => exact forward_method setting hc hd ha stack store avoid typed step
      | scalar lookup count inputs simple value =>
        exact ScalarPhase.forward_invariant P Q config.builtins σ setting.wellFormed setting.wellTyped setting.effects
          setting.core setting.pathEnvironment (ScalarPhase.initial _ _ _ _ _ _) lookup count inputs simple hc value
          stack store typed avoid step
      | projected lookup route arguments inputs count types simple value =>
        exact projected_root_forward setting.program setting.wellFormed setting.wellTyped setting.effects setting.core
          setting.pathEnvironment setting.variance (setting.valid _ _ lookup) lookup route arguments inputs types simple hc
          value stack store typed avoid step
  | matchRun hv hc ha hk hμ => exact forward_match_run setting hv hc ha hk hμ avoid typed step
  | error hk hμ => exact forward_error setting hk hμ avoid typed step
  | exit hk hμ => exact forward_exit setting hk hμ avoid typed step
  | scalarPhase lookup count inputs simple hc hv hk hμ phase =>
    exact ScalarPhase.forward_invariant P Q config.builtins σ setting.wellFormed setting.wellTyped setting.effects
      setting.core setting.pathEnvironment phase lookup count inputs simple hc hv hk hμ typed avoid step
  | projectedApplication lookup view inputs count read hk hμ =>
    exact projected_application_forward P Q config.builtins σ setting.wellFormed setting.wellTyped setting.effects
      setting.core setting.pathEnvironment setting.variance (setting.valid _ _ lookup) lookup view inputs count read
      hk hμ typed avoid step
  | administrative path related ih =>
    cases path with
    | nil => exact ih avoid typed step
    | cons first rest =>
      exact ForwardResult.administrative setting.program.getters first (.administrative rest related) avoid typed step

/-- 元の実行の一段の模倣。対応する実行が段を進めないときは、管理用の順位が減る。 -/
theorem Setting.forward [StandardModel.RowLookup config.builtins] [StandardModel.RowEnv Q (responseTable config rows)]
    (setting : Setting source rows config P Q σ) :
    Trace.Forward P config.builtins Q (responseTable config rows) σ
      (InvariantRel source rows Q (responseTable config rows) σ effect) (administrativeRank source) := by
  intro s t label destination related step
  exact StateRel.forward setting related.1 related.2.1 related.2.2 step

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
