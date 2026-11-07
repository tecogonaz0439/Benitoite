import Benitoite.Release.Refinement.Surface.PredicateSimulationForward

/-! # 準備後の実行の一段に対応する、元の実行

準備後の状態の全ての実一段について、元の状態から同じ事象を出す空でない有限実行を構成する。
元の状態が公開判定の管理用の途中にあるときは、管理用の段を先に実行する。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateGeneratedNames
noncomputable section

variable {source : Program} {rows : PredicateProjection.Table.Rows} {config : Check.BuiltinSource}
variable {P Q : Refinement.Program} {σ : PathEnv} {effect : Eff}

theorem Setting.back {first second label destination next}
    (setting : Setting source rows config P Q σ)
    (typed : StateTyE Q (responseTable config rows) σ effect second)
    (targetStep : Step Q (responseTable config rows) σ second label destination)
    (sourceStep : Step P config.builtins σ first label next)
    (related : StateRel source rows next destination) (avoid : NoGeneratedKeys rows next) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect first second label destination :=
  BackwardResult.of_step setting.wellFormed setting.wellTyped setting.effects setting.core setting.pathEnvironment
    typed targetStep sourceStep related avoid

theorem Setting.backAt {first second label destination}
    {targetStep : Step Q (responseTable config rows) σ second label destination}
    (setting : Setting source rows config P Q σ)
    (typed : StateTyE Q (responseTable config rows) σ effect second)
    (sync : ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      first second targetStep) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect first second label destination := by
  obtain ⟨next,sourceStep,related,avoid⟩ := sync
  exact setting.back typed targetStep sourceStep related avoid

theorem overlay_signature_eq {name : PrimName} (absent : rows.lookup name = none) :
    (responseTable config rows).sig name = config.builtins.sig name := by
  change (match rows.lookup name with | some row => some row.signature | none => config.builtins.sig name) = _
  rw [absent]

theorem Value.primitive_right {b ts es rs} {v : Val} (h : Value source rows v (.prim b ts es rs)) :
    v = .prim b ts es rs := by cases h; rfl
theorem Value.function_right {f ts es rs} {v : Val} (h : Value source rows v (.fnRef f ts es rs)) :
    v = .fnRef f ts es rs := by cases h; rfl
theorem Value.operation_right {o ts} {v : Val} (h : Value source rows v (.op o ts)) : v = .op o ts := by cases h; rfl
theorem Value.raise_right {t e} {v : Val} (h : Value source rows v (.raise t e)) : v = .raise t e := by cases h; rfl
theorem Value.external_right {f ts} {v : Val} (h : Value source rows v (.externalRef f ts)) :
    v = .externalRef f ts := by cases h; rfl
theorem Value.location_right {l : Nat} {v : Val} (h : Value source rows v (.loc l)) : v = .loc l := by cases h; rfl
theorem Value.closure_right {signature body} {v : Val} (h : Value source rows v (.closure signature body)) :
    ∃ original, v = .closure signature original ∧ ClosedCode source rows original body := by
  cases h with
  | closure related => exact ⟨_,rfl,related⟩
theorem Value.dictionary_right {i ts ws} {v : Val} (h : Value source rows v (.dict i ts ws)) :
    ∃ vs, v = .dict i ts vs ∧ Values source rows vs ws := by
  cases h with
  | dictionary related => exact ⟨_,rfl,related⟩

theorem Values.nil_right {xs : List Val} (h : Values source rows xs []) : xs = [] := by cases h; rfl
theorem Values.single_right {y : Val} {xs : List Val} (h : Values source rows xs [y]) :
    ∃ x, xs = [x] ∧ Value source rows x y := by
  cases h with
  | cons hx rest => cases rest; exact ⟨_,rfl,hx⟩
theorem Values.pair_right {y u : Val} {xs : List Val} (h : Values source rows xs [y,u]) :
    ∃ x z, xs = [x,z] ∧ Value source rows x y ∧ Value source rows z u := by
  cases h with
  | cons hx rest => cases rest with
    | cons hz rest => cases rest; exact ⟨_,_,rfl,hx,hz⟩

theorem optionRel_right_some {α β : Type} {R : α → β → Prop} {a : Option α} {b : β} (h : Option.Rel R a (some b)) :
    ∃ x, a = some x ∧ R x b := by
  cases h with
  | some related => exact ⟨_,rfl,related⟩
theorem optionRel_right_none {α β : Type} {R : α → β → Prop} {a : Option α} (h : Option.Rel R a none) : a = none := by
  cases h; rfl

theorem ProgramRel.def_right {name definition} (program : ProgramRel source rows P Q)
    (found : Q.defs name = some definition) :
    ∃ original, P.defs name = some original ∧ DefinitionRel source rows original definition := by
  have related := program.definitions name
  rw [found] at related
  exact optionRel_right_some related

theorem optionRel_right_of {α β γ : Type} {R : α → β → Prop} {f : γ → Option α} {g : γ → Option β} {x : γ} {b : β}
    (h : ∀ x, Option.Rel R (f x) (g x)) (found : g x = some b) : ∃ a, f x = some a ∧ R a b := by
  have related := h x
  rw [found] at related
  exact optionRel_right_some related

theorem optionRel_right_of_none {α β γ : Type} {R : α → β → Prop} {f : γ → Option α} {g : γ → Option β} {x : γ}
    (h : ∀ x, Option.Rel R (f x) (g x)) (found : g x = none) : f x = none := by
  have related := h x
  rw [found] at related
  exact optionRel_right_none related

theorem ContRel.split_frame_right {before after : Cont} {k : Cont} {target : Frame}
    (h : ContRel source rows k (before ++ target :: after)) :
    ∃ original next rest, k = original ++ next :: rest ∧
      ContRel source rows original before ∧ FrameRel source rows next target ∧ ContRel source rows rest after := by
  induction before generalizing k with
  | nil => cases h with
    | cons head tail => exact ⟨[],_,_,rfl,.nil,head,tail⟩
  | cons first before ih => cases h with
    | cons head tail =>
      obtain ⟨original,next,rest,rfl,hbefore,hframe,hafter⟩ := ih tail
      exact ⟨_ :: original,next,rest,rfl,.cons head hbefore,hframe,hafter⟩

theorem ContRel.splitAt_right {k l op before cap clauses after}
    (h : ContRel source rows k l) (split : SplitAt op l before cap clauses after) :
    ∃ original originalCap originalClauses rest, SplitAt op k original originalCap originalClauses rest ∧
      ContRel source rows original before ∧ Captures source rows originalCap cap ∧
      Clauses source rows originalClauses clauses ∧ ContRel source rows rest after := by
  obtain ⟨rfl,handled,absent⟩ := split
  obtain ⟨original,next,rest,equal,hbefore,hframe,hafter⟩ := h.split_frame_right
  cases hframe with
  | handleF hc hh =>
    exact ⟨original,_,_,rest,⟨equal,(hh.handles op).symm ▸ handled,(hbefore.noHandler op).mpr absent⟩,
      hbefore,hc,hh,hafter⟩

theorem ClauseRel.find_left {clauses targets op target} (h : Clauses source rows clauses targets)
    (found : findClause targets op = some target) :
    ∃ original, findClause clauses op = some original ∧ ClauseRel source rows original target := by
  have related := h.findClause op
  rw [found] at related
  exact optionRel_right_some related

theorem backward_ret (setting : Setting source rows config P Q σ) {cap cap' v w k l μ ν label destination}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.ret v)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.ret w)) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.ret w)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
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
        exact setting.back typed (.E_Return rfl) (.E_Return rfl) (.run (hq.apply (.cons closed .nil)) hk hμ)
          ⟨ClosureAvoid.apply frames.1 (ValuesAvoid.cons.mpr ⟨valueAvoid,ValuesAvoid.nil _⟩),frames.2,avoid.2.2⟩
  case E_Update =>
    rename_i view
    injection view with same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | update location =>
        exact setting.back typed (.E_Update rfl) (.E_Update rfl) (.run (.pure (.ret closed)) hk (hμ.set (.done closed)))
          ⟨pure_ret_avoid valueAvoid,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2.set valueAvoid⟩
  case E_Mark =>
    rename_i view
    injection view with same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | mark =>
        exact setting.back typed (.E_Mark rfl) (.E_Mark rfl) (.run (.pure (.ret closed)) hk hμ)
          ⟨pure_ret_avoid valueAvoid,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_HRet =>
    rename_i view
    injection view with same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | handleF hcap clauses =>
        exact setting.back typed (.E_HRet rfl) (.E_HRet rfl) (.run (.pure (.ret closed)) hk hμ)
          ⟨pure_ret_avoid valueAvoid,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_Drop =>
    rename_i view found
    injection view with same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | drop location =>
        obtain ⟨cell,original,related⟩ := hμ.lookup_right found
        cases related
        exact setting.back typed (.E_Drop rfl found) (.E_Drop rfl original) (.run (.pure (.ret closed)) hk hμ)
          ⟨pure_ret_avoid valueAvoid,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_DropRel =>
    rename_i view found
    injection view with same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | drop location =>
        obtain ⟨cell,original,related⟩ := hμ.lookup_right found
        cases related with
        | cont saved =>
          have savedAvoid : ContAvoid (rows.map Prod.fst) _ := avoid.2.2.lookup original
          exact setting.back typed (.E_DropRel rfl found) (.E_DropRel rfl original)
            (.run (.pure (.ret closed)) (saved.releases.append hk) (hμ.set .used))
            ⟨pure_ret_avoid valueAvoid,ContAvoid.append savedAvoid.releases (ContAvoid.cons.mp avoid.2.1).2,
              avoid.2.2.set (cell := .used) trivial⟩
  case E_GuardT =>
    rename_i view
    injection view with same
    change closeVal cap' w = _ at same
    rw [same] at closed
    have original := Value.constant_right closed
    cases hk with
    | cons hf hk => cases hf with
      | guardF hguard hcap harms hbody =>
        have frames := ContAvoid.cons.mp avoid.2.1
        exact setting.back typed (.E_GuardT (q := .mk cap' (.ret w)) (by change Comp.ret (closeVal cap' w) = _; rw [same]))
          (.E_GuardT (q := .mk cap (.ret v)) (by change Comp.ret (closeVal cap v) = _; rw [original]))
          (.run hbody hk hμ) ⟨frames.1.2.2.2,frames.2,avoid.2.2⟩
  case E_GuardF =>
    rename_i view
    injection view with same
    change closeVal cap' w = _ at same
    rw [same] at closed
    have original := Value.constant_right closed
    cases hk with
    | cons hf hk => cases hf with
      | guardF hguard hcap harms hbody =>
        have frames := ContAvoid.cons.mp avoid.2.1
        exact setting.back typed (.E_GuardF (q := .mk cap' (.ret w)) (by change Comp.ret (closeVal cap' w) = _; rw [same]))
          (.E_GuardF (q := .mk cap (.ret v)) (by change Comp.ret (closeVal cap v) = _; rw [original]))
          (.matchRun hguard hcap harms hk hμ) ⟨frames.1.1,frames.1.2.1,frames.1.2.2.1,frames.2,avoid.2.2⟩
  case E_Release =>
    rename_i response view
    injection view with same; change closeVal cap' w = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | release hresource =>
        exact setting.backAt typed (response_release_backward (q := .mk cap (.ret v)) (r := .mk cap' (.ret w))
          setting.active rfl rfl closed hresource response hk hμ avoid)
  case E_RelErr =>
    rename_i response view
    cases hk with
    | cons hf hk => cases hf with
      | release hresource =>
        exact setting.backAt typed (response_release_error_backward (q := .mk cap (.ret v))
          setting.active rfl view hresource response hk hμ avoid)

theorem backward_let (setting : Setting source rows config P Q σ) {cap cap' m m' n n' k l μ ν label destination}
    (hc : Captures source rows cap cap') (hm : Code source rows m m') (hn : Code source rows n n')
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.letIn m n)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.letIn m' n')) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.letIn m' n')) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.run (.mk cap (.letIn m n)) k μ) (.run (.mk cap' (.letIn m' n')) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  obtain ⟨first,rest⟩ := CodeAvoid.letIn.mp code
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Let =>
    rename_i view
    injection view with same same'; subst same; subst same'
    exact setting.back typed (.E_Let rfl) (.E_Let rfl) (.run (.mk hc hm) (.cons (.letF (.mk hc hn)) hk) hμ)
      ⟨ClosureAvoid.mk.mpr ⟨capture,first⟩,ContAvoid.cons.mpr ⟨ClosureAvoid.mk.mpr ⟨capture,rest⟩,stack⟩,store⟩

theorem backward_builder (setting : Setting source rows config P Q σ) {cap cap' kind m n k l μ ν label destination}
    (hc : Captures source rows cap cap') (hm : Code source rows m n)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.builderLet kind m)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.builderLet kind n)) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.builderLet kind n)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.run (.mk cap (.builderLet kind m)) k μ) (.run (.mk cap' (.builderLet kind n)) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_BuilderNew =>
    rename_i view fresh
    injection view with same same'; subst same; subst same'
    rename_i location
    have body : Code source rows (m.subst builderValueSubst (builderLocalSubst location))
        (n.subst builderValueSubst (builderLocalSubst location)) :=
      hm.subst _ _ _ (fun i => Value.refl _) simple_builder_substitution
    have empty : BuilderRel source rows (Refinement.substKind cap.env kind).empty
        (Refinement.substKind cap'.env kind).empty := by
      rw [hc.substKind]
      cases Refinement.substKind cap'.env kind <;> first | exact .string _ | exact .bytes _ | exact .list .nil
    exact setting.back typed (.E_BuilderNew rfl fresh) (.E_BuilderNew rfl (hμ.fresh_right fresh))
      (.run (.mk hc body) hk (hμ.set (.builder empty)))
      ⟨ClosureAvoid.mk.mpr ⟨capture,CodeAvoid.subst (show CodeAvoid _ m from code) _ _ (fun i => by
          cases i <;> first | exact ValueAvoid.constant _ _ | exact ValueAvoid.variable _ _)⟩,
        stack,store.set (BuilderAvoid.empty _ _)⟩

theorem backward_builder_operation (setting : Setting source rows config P Q σ)
    {cap cap' kind op reference vs ws k l μ ν label destination}
    (hc : Captures source rows cap cap') (ha : Values source rows vs ws)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.builderOp kind op reference vs)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.builderOp kind op reference ws)) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.builderOp kind op reference ws)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.run (.mk cap (.builderOp kind op reference vs)) k μ) (.run (.mk cap' (.builderOp kind op reference ws)) l ν)
      label destination := by
  have arguments : ValuesAvoid (rows.map Prod.fst) (closeVals cap vs) := valuesNames_avoid.mp avoid.1.view
  have closedArgs := ha.close hc
  have first : (Closure.mk cap (.builderOp kind op reference vs)).view =
      .builderOp (Refinement.substKind cap'.env kind) op reference (closeVals cap vs) := by
    change Comp.builderOp (Refinement.substKind cap.env kind) op reference (closeVals cap vs) = _
    rw [hc.substKind]
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_BuilderOp =>
    rename_i reply view found
    simp only [Closure.view, Closure.code, Closure.capture] at view reply ⊢
    injection view with sameKind sameOp sameRef sameArgs; subst sameKind; subst sameOp; subst sameRef; subst sameArgs
    obtain ⟨cell,original,related⟩ := hμ.lookup_right found
    cases related with
    | builder contents =>
      have output := contents.apply closedArgs op
      rw [reply] at output
      obtain ⟨sourceReply,sourceFound,replyRel⟩ := optionRel_right_some output
      cases replyRel with
      | value next result =>
        have cellAvoid : BuilderAvoid _ _ := avoid.2.2.lookup original
        have replyAvoid := cellAvoid.apply arguments op
        rw [sourceFound] at replyAvoid
        exact setting.back typed (.E_BuilderOp rfl found reply) (.E_BuilderOp first original sourceFound)
          (.run (.pure (.ret result)) hk (hμ.set (.builder next)))
          ⟨pure_ret_avoid replyAvoid.2,avoid.2.1,avoid.2.2.set replyAvoid.1⟩
  case E_BuilderErr =>
    rename_i reply view found
    simp only [Closure.view, Closure.code, Closure.capture] at view reply ⊢
    injection view with sameKind sameOp sameRef sameArgs; subst sameKind; subst sameOp; subst sameRef; subst sameArgs
    obtain ⟨cell,original,related⟩ := hμ.lookup_right found
    cases related with
    | builder contents =>
      have output := contents.apply closedArgs op
      rw [reply] at output
      obtain ⟨sourceReply,sourceFound,replyRel⟩ := optionRel_right_some output
      cases replyRel with
      | error reason =>
        exact setting.back typed (.E_BuilderErr rfl found reply) (.E_BuilderErr first original sourceFound)
          (.error hk hμ) ⟨avoid.2.1,avoid.2.2⟩

theorem backward_ite (setting : Setting source rows config P Q σ) {cap cap' v w m m' n n' k l μ ν label destination}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (hm : Code source rows m m') (hn : Code source rows n n')
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.ite v m n)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.ite w m' n')) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.ite w m' n')) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.run (.mk cap (.ite v m n)) k μ) (.run (.mk cap' (.ite w m' n')) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  have parts := NamesAvoid.append.mp (show NamesAvoid _ (valueNames v ++ compNames m ++ compNames n) from code)
  have closed := hv.close hc
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_IfT =>
    rename_i view
    injection view with condition same same'; subst same; subst same'
    change closeVal cap' w = _ at condition
    rw [condition] at closed
    have original := Value.constant_right closed
    exact setting.back typed (.E_IfT (q := .mk cap' (.ite w m' n')) (by change Comp.ite (closeVal cap' w) m' n' = _; rw [condition]))
      (.E_IfT (q := .mk cap (.ite v m n)) (by change Comp.ite (closeVal cap v) m n = _; rw [original]))
      (.run (.mk hc hm) hk hμ) ⟨ClosureAvoid.mk.mpr ⟨capture,(NamesAvoid.append.mp parts.1).2⟩,stack,store⟩
  case E_IfF =>
    rename_i view
    injection view with condition same same'; subst same; subst same'
    change closeVal cap' w = _ at condition
    rw [condition] at closed
    have original := Value.constant_right closed
    exact setting.back typed (.E_IfF (q := .mk cap' (.ite w m' n')) (by change Comp.ite (closeVal cap' w) m' n' = _; rw [condition]))
      (.E_IfF (q := .mk cap (.ite v m n)) (by change Comp.ite (closeVal cap v) m n = _; rw [original]))
      (.run (.mk hc hn) hk hμ) ⟨ClosureAvoid.mk.mpr ⟨capture,parts.2⟩,stack,store⟩

theorem backward_match (setting : Setting source rows config P Q σ) {cap cap' v w arms targets k l μ ν label destination}
    (hc : Captures source rows cap cap') (hv : Value source rows v w) (ha : Arms source rows arms targets)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.match v arms)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.match w targets)) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.match w targets)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.run (.mk cap (.match v arms)) k μ) (.run (.mk cap' (.match w targets)) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  have parts := NamesAvoid.append.mp (show NamesAvoid _ (valueNames v ++ armsNames arms) from code)
  have viewParts := NamesAvoid.append.mp (show NamesAvoid _ (valueNames (closeVal cap v) ++ armsNames arms) from avoid.1.view)
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Match =>
    rename_i view
    injection view with same same'; subst same; subst same'
    exact setting.back typed (.E_Match rfl) (.E_Match rfl) (.matchRun (hv.close hc) hc ha hk hμ)
      ⟨viewParts.1,capture,parts.2,stack,store⟩

theorem backward_lazy (setting : Setting source rows config P Q σ) {cap cap' m n k l μ ν label destination}
    (hc : Captures source rows cap cap') (hm : Code source rows m n)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.lazyC m)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.lazyC n)) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.lazyC n)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.run (.mk cap (.lazyC m)) k μ) (.run (.mk cap' (.lazyC n)) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Lazy =>
    rename_i view fresh
    injection view with same; subst same
    exact setting.back typed (.E_Lazy rfl fresh) (.E_Lazy rfl (hμ.fresh_right fresh))
      (.run (.pure (.ret (.location _))) hk (hμ.set (.thunk (.mk hc hm))))
      ⟨pure_ret_avoid (ValueAvoid.location _ _),stack,
        store.set (cell := .thunk (.mk cap m)) (ClosureAvoid.mk.mpr ⟨capture,code⟩)⟩

theorem backward_use (setting : Setting source rows config P Q σ) {cap cap' v w m n k l μ ν label destination}
    (hc : Captures source rows cap cap') (hv : Value source rows v w) (hm : Code source rows m n)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.use v m)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.use w n)) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.use w n)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.run (.mk cap (.use v m)) k μ) (.run (.mk cap' (.use w n)) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  have parts := NamesAvoid.append.mp (show NamesAvoid _ (valueNames v ++ compNames m) from code)
  have viewParts := NamesAvoid.append.mp (show NamesAvoid _ (valueNames (closeVal cap v) ++ compNames m) from avoid.1.view)
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Use =>
    rename_i view
    injection view with same same'; subst same; subst same'
    exact setting.back typed (.E_Use rfl) (.E_Use rfl) (.run (.mk hc hm) (.cons (.release (hv.close hc)) hk) hμ)
      ⟨ClosureAvoid.mk.mpr ⟨capture,parts.2⟩,ContAvoid.cons.mpr ⟨viewParts.1,stack⟩,store⟩

theorem backward_handle (setting : Setting source rows config P Q σ) {cap cap' m n clauses targets k l μ ν label destination}
    (hc : Captures source rows cap cap') (hm : Code source rows m n) (hh : Clauses source rows clauses targets)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.handle m clauses)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.handle n targets)) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.handle n targets)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.run (.mk cap (.handle m clauses)) k μ) (.run (.mk cap' (.handle n targets)) l ν) label destination := by
  obtain ⟨capture,code,stack,store⟩ := StateAvoid.parts avoid
  have parts := NamesAvoid.append.mp (show NamesAvoid _ (compNames m ++ clausesNames clauses) from code)
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Handle =>
    rename_i view
    injection view with same same'; subst same; subst same'
    exact setting.back typed (.E_Handle rfl) (.E_Handle rfl) (.run (.mk hc hm) (.cons (.handleF hc hh) hk) hμ)
      ⟨ClosureAvoid.mk.mpr ⟨capture,parts.1⟩,ContAvoid.cons.mpr ⟨⟨capture,parts.2⟩,stack⟩,store⟩

theorem backward_escape (setting : Setting source rows config P Q σ) {cap cap' v w k l μ ν label destination}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.escape v)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.escape w)) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.escape w)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.run (.mk cap (.escape v)) k μ) (.run (.mk cap' (.escape w)) l ν) label destination := by
  have valueAvoid : ValueAvoid (rows.map Prod.fst) (closeVal cap v) := avoid.1.view
  have closed := hv.close hc
  have escaped : ClosureAvoid (rows.map Prod.fst) (Closure.pure (.escape (closeVal cap v))) :=
    ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,valueAvoid⟩
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_EscLet =>
    rename_i view
    injection view with same; change closeVal cap' w = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | letF hq =>
        exact setting.back typed (.E_EscLet rfl) (.E_EscLet rfl) (.run (.pure (.escape closed)) hk hμ)
          ⟨escaped,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_EscHandle =>
    rename_i view
    injection view with same; change closeVal cap' w = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | handleF hcap clauses =>
        exact setting.back typed (.E_EscHandle rfl) (.E_EscHandle rfl) (.run (.pure (.escape closed)) hk hμ)
          ⟨escaped,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_EscMark =>
    rename_i view
    injection view with same; change closeVal cap' w = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | mark =>
        exact setting.back typed (.E_EscMark rfl) (.E_EscMark rfl) (.run (.pure (.ret closed)) hk hμ)
          ⟨pure_ret_avoid valueAvoid,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_EscDrop =>
    rename_i view found
    injection view with same; change closeVal cap' w = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | drop location =>
        obtain ⟨cell,original,related⟩ := hμ.lookup_right found
        cases related
        exact setting.back typed (.E_EscDrop rfl found) (.E_EscDrop rfl original) (.run (.pure (.escape closed)) hk hμ)
          ⟨escaped,(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩
  case E_EscDropRel =>
    rename_i view found
    injection view with same; change closeVal cap' w = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | drop location =>
        obtain ⟨cell,original,related⟩ := hμ.lookup_right found
        cases related with
        | cont saved =>
          have savedAvoid : ContAvoid (rows.map Prod.fst) _ := avoid.2.2.lookup original
          exact setting.back typed (.E_EscDropRel rfl found) (.E_EscDropRel rfl original)
            (.run (.pure (.escape closed)) (saved.releases.append hk) (hμ.set .used))
            ⟨escaped,ContAvoid.append savedAvoid.releases (ContAvoid.cons.mp avoid.2.1).2,
              avoid.2.2.set (cell := .used) trivial⟩
  case E_EscRel =>
    rename_i response view
    injection view with same; change closeVal cap' w = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | release hresource =>
        exact setting.backAt typed (response_escape_release_backward (q := .mk cap (.escape v)) (r := .mk cap' (.escape w))
          setting.active rfl rfl closed hresource response hk hμ avoid)
  case E_EscRelErr =>
    rename_i response view
    injection view with same; change closeVal cap' w = _ at same; subst same
    cases hk with
    | cons hf hk => cases hf with
      | release hresource =>
        exact setting.backAt typed (response_escape_release_error_backward (q := .mk cap (.escape v)) (r := .mk cap' (.escape w))
          setting.active rfl rfl hresource response hk hμ avoid)

theorem backward_issue_path_bases (setting : Setting source rows config P Q σ) {cap cap' name k l μ ν label destination}
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.issuePathBases name)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.issuePathBases name)) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.issuePathBases name)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.run (.mk cap (.issuePathBases name)) k μ) (.run (.mk cap' (.issuePathBases name)) l ν) label destination := by
  have absent : name ∉ rows.map Prod.fst := (show NamesAvoid _ [name] from avoid.1.code) name (List.mem_singleton_self _)
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_IssuePathBases =>
    rename_i found kind effectName valid view
    injection view with same; subst same
    have original := (overlay_signature_eq (config := config) (rows_lookup_none absent)).symm.trans found
    exact setting.back typed (.E_IssuePathBases rfl found kind effectName valid)
      (.E_IssuePathBases rfl original kind effectName valid) (.run (.pure (.ret (.pathBases _))) hk hμ)
      ⟨pure_ret_avoid (NamesAvoid.nil _),avoid.2.1,avoid.2.2⟩

theorem backward_app [StandardModel.RowEnv Q (responseTable config rows)]
    (setting : Setting source rows config P Q σ) {cap cap' f g vs ws k l μ ν label destination}
    (hc : Captures source rows cap cap') (hf : Value source rows f g) (ha : Values source rows vs ws)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.app f vs)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.app g ws)) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.app g ws)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.run (.mk cap (.app f vs)) k μ) (.run (.mk cap' (.app g ws)) l ν) label destination := by
  have closedF := hf.close hc
  have closedA := ha.close hc
  have viewParts := NamesAvoid.append.mp
    (show NamesAvoid _ (valueNames (closeVal cap f) ++ valuesNames (closeVals cap vs)) from avoid.1.view)
  have argsAvoid : ValuesAvoid (rows.map Prod.fst) (closeVals cap vs) := valuesNames_avoid.mp viewParts.2
  have headAvoid : ValueAvoid (rows.map Prod.fst) (closeVal cap f) := viewParts.1
  have primSource : ∀ {b ts es rs}, closeVal cap' g = .prim b ts es rs →
      closeVal cap f = .prim b ts es rs ∧ rows.lookup b = none := by
    intro b ts es rs same
    rw [same] at closedF
    have original := Value.primitive_right closedF
    refine ⟨original,?_⟩
    rw [original] at headAvoid
    exact rows_lookup_none (headAvoid b (List.mem_singleton_self _))
  have stack := avoid.2.1
  have store := avoid.2.2
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Lam =>
    rename_i function arity view
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    subst sameF; subst sameA
    have closed := closedF.close (Captures.mk Slots.nil)
    change Value source rows (closeVal Capture.empty (closeVal cap f)) (closeVal Capture.empty (closeVal cap' g)) at closed
    rw [function] at closed
    obtain ⟨original,sourceFunction,hbody⟩ := Value.closure_right closed
    have bodyAvoid : ValueAvoid (rows.map Prod.fst) (closeVal Capture.empty (closeVal cap f)) :=
      headAvoid.close (CaptureAvoid.empty _)
    rw [sourceFunction] at bodyAvoid
    exact setting.back typed (.E_Lam rfl function arity) (.E_Lam rfl sourceFunction (closedA.length ▸ arity))
      (.run (hbody.apply closedA) hk.markPush hμ) ⟨ClosureAvoid.apply bodyAvoid argsAvoid,stack.markPush,store⟩
  case E_ExternalApply =>
    rename_i view
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    subst sameA
    rw [sameF] at closedF
    have sourceF := Value.external_right closedF
    exact setting.back typed (.E_ExternalApply (q := .mk cap' (.app g ws))
        (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [sameF]))
      (.E_ExternalApply (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF]))
      (.run (ClosedCode.pure (.externalCall closedA)) hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,valuesNames_avoid.mpr argsAvoid⟩,stack,store⟩
  case E_PathBasesApply =>
    rename_i found kind view
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    rw [sameA] at closedA
    have sourceA := Values.nil_right closedA
    obtain ⟨sourceF,absent⟩ := primSource sameF
    rw [sourceF] at headAvoid
    exact setting.back typed (.E_PathBasesApply (q := .mk cap' (.app g ws))
        (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [sameF,sameA]) found kind)
      (.E_PathBasesApply (q := .mk cap (.app f vs))
        (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF,sourceA])
        ((overlay_signature_eq absent).symm.trans found) kind)
      (.run (.mk hc (.pathBases _)) hk hμ) ⟨ClosureAvoid.mk.mpr ⟨avoid.1.capture,headAvoid⟩,stack,store⟩
  case E_Fun =>
    rename_i found arity types effects view
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    subst sameA
    rw [sameF] at closedF
    have sourceF := Value.function_right closedF
    obtain ⟨original,sourceFound,hd⟩ := setting.program.def_right found
    have bodyAvoid := setting.programAvoid.1 _ _ sourceFound
    exact setting.back typed (.E_Fun (q := .mk cap' (.app g ws))
        (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [sameF]) found arity types effects)
      (.E_Fun (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF]) sourceFound
        (closedA.length ▸ hd.params ▸ arity) (by simpa only [Refinement.Def.ntys,hd.tparams] using types) (hd.neffs ▸ effects))
      (.run (.mk ((Captures.mk Slots.nil).extendMany closedA) ((hd.body.instR _).substTy 0 _ _)) hk.markPush hμ)
      ⟨ClosureAvoid.mk.mpr ⟨(CaptureAvoid.empty _).extendMany argsAvoid,(bodyAvoid.instR _).substTy 0 _ _⟩,
        stack.markPush,store⟩
  case E_Prim =>
    rename_i found kind response view
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    subst sameA
    obtain ⟨sourceF,absent⟩ := primSource sameF
    have second : (Closure.mk cap' (.app g ws)).view = Comp.app (closeVal cap' g) (closeVals cap' ws) := rfl
    rw [sameF] at second
    obtain ⟨Ψ,r,ef,args⟩ := StateTyE.builtin_args setting.wellFormed setting.wellTyped setting.core typed second found
    exact setting.backAt typed (response_primitive_backward setting.active setting.core
      (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF]) second found kind response args
      closedA hk hμ avoid)
  case E_Err =>
    rename_i found kind response view
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    subst sameA
    obtain ⟨sourceF,absent⟩ := primSource sameF
    have second : (Closure.mk cap' (.app g ws)).view = Comp.app (closeVal cap' g) (closeVals cap' ws) := rfl
    rw [sameF] at second
    obtain ⟨Ψ,r,ef,args⟩ := StateTyE.builtin_args setting.wellFormed setting.wellTyped setting.core typed second found
    exact setting.backAt typed (response_primitive_error_backward setting.active setting.core
      (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF]) second found kind response args
      closedA hk hμ avoid)
  case E_IO =>
    rename_i found kind response view unhandled
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    subst sameA
    obtain ⟨sourceF,absent⟩ := primSource sameF
    have second : (Closure.mk cap' (.app g ws)).view = Comp.app (closeVal cap' g) (closeVals cap' ws) := rfl
    rw [sameF] at second
    obtain ⟨Ψ,r,ef,args⟩ := StateTyE.builtin_args setting.wellFormed setting.wellTyped setting.core typed second found
    exact setting.backAt typed (response_io_backward setting.active
      (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF]) second found kind unhandled response args
      closedA hk hμ avoid)
  case E_IOErr =>
    rename_i found kind response view unhandled
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    subst sameA
    obtain ⟨sourceF,absent⟩ := primSource sameF
    have second : (Closure.mk cap' (.app g ws)).view = Comp.app (closeVal cap' g) (closeVals cap' ws) := rfl
    rw [sameF] at second
    obtain ⟨Ψ,r,ef,args⟩ := StateTyE.builtin_args setting.wellFormed setting.wellTyped setting.core typed second found
    exact setting.backAt typed (response_io_error_backward setting.active
      (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF]) second found kind unhandled response args
      closedA hk hμ avoid)
  case E_Exit =>
    rename_i found kind response view unhandled
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    subst sameA
    obtain ⟨sourceF,absent⟩ := primSource sameF
    have second : (Closure.mk cap' (.app g ws)).view = Comp.app (closeVal cap' g) (closeVals cap' ws) := rfl
    rw [sameF] at second
    obtain ⟨Ψ,r,ef,args⟩ := StateTyE.builtin_args setting.wellFormed setting.wellTyped setting.core typed second found
    exact setting.backAt typed (response_exit_backward setting.active
      (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF]) second found kind unhandled response args
      closedA hk hμ avoid)
  case E_RefNew =>
    rename_i found kind view fresh
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    rw [sameA] at closedA
    obtain ⟨original,sourceA,related⟩ := Values.single_right closedA
    obtain ⟨sourceF,absent⟩ := primSource sameF
    rw [sourceA] at argsAvoid
    exact setting.back typed (.E_RefNew (q := .mk cap' (.app g ws))
        (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [sameF,sameA]) found kind fresh)
      (.E_RefNew (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF,sourceA])
        ((overlay_signature_eq absent).symm.trans found) kind (hμ.fresh_right fresh))
      (.run (.pure (.ret (.location _))) hk (hμ.set (.value related)))
      ⟨pure_ret_avoid (ValueAvoid.location _ _),stack,store.set (cell := .val _) (ValuesAvoid.cons.mp argsAvoid).1⟩
  case E_RefGet =>
    rename_i found kind view cell
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    rw [sameA] at closedA
    obtain ⟨original,sourceA,related⟩ := Values.single_right closedA
    rw [Value.location_right related] at sourceA
    obtain ⟨sourceF,absent⟩ := primSource sameF
    obtain ⟨sourceCell,sourceFound,cellRel⟩ := hμ.lookup_right cell
    cases cellRel with
    | value hv =>
      exact setting.back typed (.E_RefGet (q := .mk cap' (.app g ws))
          (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [sameF,sameA]) found kind cell)
        (.E_RefGet (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF,sourceA])
          ((overlay_signature_eq absent).symm.trans found) kind sourceFound)
        (.run (.pure (.ret hv)) hk hμ) ⟨pure_ret_avoid (store.lookup sourceFound),stack,store⟩
  case E_RefSet =>
    rename_i found kind view
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    rw [sameA] at closedA
    obtain ⟨location,original,sourceA,relatedLocation,related⟩ := Values.pair_right closedA
    rw [Value.location_right relatedLocation] at sourceA
    obtain ⟨sourceF,absent⟩ := primSource sameF
    rw [sourceA] at argsAvoid
    exact setting.back typed (.E_RefSet (q := .mk cap' (.app g ws))
        (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [sameF,sameA]) found kind)
      (.E_RefSet (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF,sourceA])
        ((overlay_signature_eq absent).symm.trans found) kind)
      (.run (.pure (.ret (.constant _))) hk (hμ.set (.value related)))
      ⟨pure_ret_avoid (ValueAvoid.constant _ _),stack,
        store.set (cell := .val _) (ValuesAvoid.cons.mp (ValuesAvoid.cons.mp argsAvoid).2).1⟩
  case E_RefUpdate =>
    rename_i found kind view
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    rw [sameA] at closedA
    obtain ⟨location,original,sourceA,relatedLocation,related⟩ := Values.pair_right closedA
    rw [Value.location_right relatedLocation] at sourceA
    obtain ⟨sourceF,absent⟩ := primSource sameF
    rw [sourceA] at argsAvoid
    have prefixed : ∀ key ∈ rows.map Prod.fst, key.startsWith "%Predicate." = true := by
      intro key member
      obtain ⟨row,rowMember,rfl⟩ := List.mem_map.mp member
      exact List.all_eq_true.mp (Bool.and_eq_true_iff.mp setting.active).2 row rowMember
    have references := enabled_references_avoid (CheckPreparation.enabled_resolved_base setting.active) prefixed
    have functionAvoid := (ValuesAvoid.cons.mp (ValuesAvoid.cons.mp argsAvoid).2).1
    exact setting.back typed (.E_RefUpdate (q := .mk cap' (.app g ws))
        (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [sameF,sameA]) found kind)
      (.E_RefUpdate (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF,sourceA])
        ((overlay_signature_eq absent).symm.trans found) kind)
      (.run (.pure (.letIn (.app (.primitive _ _ _ _) (.cons (.location _) .nil))
        (.letIn (.app (related.rename (· + 1)) (.cons (.var 0) .nil))
          (.app (.primitive _ _ _ _) (.cons (.location _) (.cons (.var 0) .nil)))))) hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,CodeAvoid.letIn.mpr ⟨app_avoid (prim_avoid references.1)
          (ValuesAvoid.cons.mpr ⟨ValueAvoid.location _ _,ValuesAvoid.nil _⟩),
          CodeAvoid.letIn.mpr ⟨app_avoid (functionAvoid.rename _) (ValuesAvoid.cons.mpr ⟨ValueAvoid.variable _ _,ValuesAvoid.nil _⟩),
            app_avoid (prim_avoid references.2)
              (ValuesAvoid.cons.mpr ⟨ValueAvoid.location _ _,ValuesAvoid.cons.mpr ⟨ValueAvoid.variable _ _,ValuesAvoid.nil _⟩⟩)⟩⟩⟩,
        stack,store⟩
  case E_ForceDone =>
    rename_i found kind view cell
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    rw [sameA] at closedA
    obtain ⟨original,sourceA,related⟩ := Values.single_right closedA
    rw [Value.location_right related] at sourceA
    obtain ⟨sourceF,absent⟩ := primSource sameF
    obtain ⟨sourceCell,sourceFound,cellRel⟩ := hμ.lookup_right cell
    cases cellRel with
    | done hv =>
      exact setting.back typed (.E_ForceDone (q := .mk cap' (.app g ws))
          (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [sameF,sameA]) found kind cell)
        (.E_ForceDone (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF,sourceA])
          ((overlay_signature_eq absent).symm.trans found) kind sourceFound)
        (.run (.pure (.ret hv)) hk hμ) ⟨pure_ret_avoid (store.lookup sourceFound),stack,store⟩
  case E_Force =>
    rename_i found kind view cell
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    rw [sameA] at closedA
    obtain ⟨original,sourceA,related⟩ := Values.single_right closedA
    rw [Value.location_right related] at sourceA
    obtain ⟨sourceF,absent⟩ := primSource sameF
    obtain ⟨sourceCell,sourceFound,cellRel⟩ := hμ.lookup_right cell
    cases cellRel with
    | thunk hq =>
      exact setting.back typed (.E_Force (q := .mk cap' (.app g ws))
          (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [sameF,sameA]) found kind cell)
        (.E_Force (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF,sourceA])
          ((overlay_signature_eq absent).symm.trans found) kind sourceFound)
        (.run hq (.cons (.update _) hk) hμ) ⟨store.lookup sourceFound,ContAvoid.cons.mpr ⟨trivial,stack⟩,store⟩
  case E_Op =>
    rename_i found view split fresh
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    subst sameA
    rw [sameF] at closedF
    have sourceF := Value.operation_right closedF
    obtain ⟨before,sourceCap,sourceClauses,after,sourceSplit,hbefore,hcapRel,clausesRel,hafter⟩ := hk.splitAt_right split
    obtain ⟨sourceClause,sourceFound,clauseRel⟩ := ClauseRel.find_left clausesRel found
    obtain ⟨beforeAvoid,⟨handlerCapture,clausesAvoid⟩,afterAvoid⟩ := stack.split sourceSplit.1
    exact setting.back typed (.E_Op (q := .mk cap' (.app g ws))
        (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [sameF]) split found fresh)
      (.E_Op (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF])
        sourceSplit sourceFound (hμ.fresh_right fresh))
      (.run (.mk (hcapRel.extendMany (closedA.append (.cons (.location _) .nil))) (clauseRel.body.substTy 0 _ []))
        (.cons (.drop _) hafter) (hμ.set (.cont (hbefore.append (.cons (.handleF hcapRel clausesRel) .nil)))))
      ⟨ClosureAvoid.mk.mpr ⟨handlerCapture.extendMany (ValuesAvoid.append.mpr ⟨argsAvoid,
          ValuesAvoid.cons.mpr ⟨ValueAvoid.location _ _,ValuesAvoid.nil _⟩⟩),
          (clausesAvoid.find_body sourceFound).substTy 0 _ _⟩,
        ContAvoid.cons.mpr ⟨trivial,afterAvoid⟩,
        store.set (cell := .cont _) (ContAvoid.append beforeAvoid (ContAvoid.cons.mpr ⟨⟨handlerCapture,clausesAvoid⟩,ContAvoid.nil _⟩))⟩
  case E_OpFail =>
    rename_i view split fresh
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    rw [sameF] at closedF
    rw [sameA] at closedA
    have sourceF := Value.raise_right closedF
    obtain ⟨original,sourceA,related⟩ := Values.single_right closedA
    rw [sourceA] at argsAvoid
    obtain ⟨before,sourceCap,sourceClauses,after,sourceSplit,hbefore,hcapRel,clausesRel,hafter⟩ := hk.splitAt_right split
    cases clausesRel with
    | fail code tail =>
      cases tail
      obtain ⟨beforeAvoid,⟨handlerCapture,clausesAvoid⟩,afterAvoid⟩ := stack.split sourceSplit.1
      have bodyAvoid : CodeAvoid (rows.map Prod.fst) _ := (NamesAvoid.append.mp clausesAvoid).1
      exact setting.back typed (.E_OpFail (q := .mk cap' (.app g ws))
          (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [sameF,sameA]) split fresh)
        (.E_OpFail (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF,sourceA])
          sourceSplit (hμ.fresh_right fresh))
        (.run (.mk (hcapRel.extendMany (.cons related (.cons (.location _) .nil))) (code.substTy 0 _ []))
          (.cons (.drop _) hafter) (hμ.set (.cont (hbefore.append (.cons (.handleF hcapRel (.fail code .nil)) .nil)))))
        ⟨ClosureAvoid.mk.mpr ⟨handlerCapture.extendMany (ValuesAvoid.cons.mpr ⟨(ValuesAvoid.cons.mp argsAvoid).1,
            ValuesAvoid.cons.mpr ⟨ValueAvoid.location _ _,ValuesAvoid.nil _⟩⟩),bodyAvoid.substTy 0 _ _⟩,
          ContAvoid.cons.mpr ⟨trivial,afterAvoid⟩,
          store.set (cell := .cont _) (ContAvoid.append beforeAvoid (ContAvoid.cons.mpr ⟨⟨handlerCapture,clausesAvoid⟩,ContAvoid.nil _⟩))⟩
  case E_OpPrim =>
    rename_i found kind clause view split fresh
    injection view with sameF sameA
    change closeVal cap' g = _ at sameF
    change closeVals cap' ws = _ at sameA
    subst sameA
    obtain ⟨sourceF,absent⟩ := primSource sameF
    obtain ⟨before,sourceCap,sourceClauses,after,sourceSplit,hbefore,hcapRel,clausesRel,hafter⟩ := hk.splitAt_right split
    obtain ⟨sourceClause,sourceFound,clauseRel⟩ := ClauseRel.find_left clausesRel clause
    obtain ⟨beforeAvoid,⟨handlerCapture,clausesAvoid⟩,afterAvoid⟩ := stack.split sourceSplit.1
    exact setting.back typed (.E_OpPrim (q := .mk cap' (.app g ws))
        (by change Comp.app (closeVal cap' g) (closeVals cap' ws) = _; rw [sameF]) found kind split clause fresh)
      (.E_OpPrim (q := .mk cap (.app f vs)) (by change Comp.app (closeVal cap f) (closeVals cap vs) = _; rw [sourceF])
        ((overlay_signature_eq absent).symm.trans found) kind sourceSplit sourceFound (hμ.fresh_right fresh))
      (.run (.mk (hcapRel.extendMany (closedA.append (.cons (.location _) .nil))) (clauseRel.body.substTy 0 _ []))
        (.cons (.drop _) hafter) (hμ.set (.cont (hbefore.append (.cons (.handleF hcapRel clausesRel) .nil)))))
      ⟨ClosureAvoid.mk.mpr ⟨handlerCapture.extendMany (ValuesAvoid.append.mpr ⟨argsAvoid,
          ValuesAvoid.cons.mpr ⟨ValueAvoid.location _ _,ValuesAvoid.nil _⟩⟩),
          (clausesAvoid.find_body sourceFound).substTy 0 _ _⟩,
        ContAvoid.cons.mpr ⟨trivial,afterAvoid⟩,
        store.set (cell := .cont _) (ContAvoid.append beforeAvoid (ContAvoid.cons.mpr ⟨⟨handlerCapture,clausesAvoid⟩,ContAvoid.nil _⟩))⟩

theorem backward_resume (setting : Setting source rows config P Q σ) {cap cap' kv kw v w k l μ ν label destination}
    (hc : Captures source rows cap cap') (hkv : Value source rows kv kw) (hv : Value source rows v w)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.resume kv v)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.resume kw w)) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.resume kw w)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
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
    change closeVal cap' kw = _ at sameK
    change closeVal cap' w = _ at sameV
    subst sameV
    rw [sameK] at closedK
    have sourceK := Value.location_right closedK
    obtain ⟨cell,original,related⟩ := hμ.lookup_right found
    cases related with
    | cont saved =>
      have savedAvoid : ContAvoid (rows.map Prod.fst) _ := avoid.2.2.lookup original
      exact setting.back typed
        (.E_Resume (q := .mk cap' (.resume kw w))
          (by change Comp.resume (closeVal cap' kw) (closeVal cap' w) = _; rw [sameK]) found)
        (.E_Resume (q := .mk cap (.resume kv v))
          (by change Comp.resume (closeVal cap kv) (closeVal cap v) = _; rw [sourceK]) original)
        (.run (.pure (.ret closedV)) (saved.append hk) (hμ.set .used))
        ⟨pure_ret_avoid parts.2,ContAvoid.append savedAvoid avoid.2.1,avoid.2.2.set (cell := .used) trivial⟩
  case E_ResumeErr =>
    rename_i view found
    injection view with sameK sameV
    change closeVal cap' kw = _ at sameK
    rw [sameK] at closedK
    have sourceK := Value.location_right closedK
    obtain ⟨cell,original,related⟩ := hμ.lookup_right found
    cases related
    exact setting.back typed
      (.E_ResumeErr (q := .mk cap' (.resume kw w))
        (by change Comp.resume (closeVal cap' kw) (closeVal cap' w) = _; rw [sameK]) found)
      (.E_ResumeErr (q := .mk cap (.resume kv v))
        (by change Comp.resume (closeVal cap kv) (closeVal cap v) = _; rw [sourceK]) original)
      (.error hk hμ) ⟨avoid.2.1,avoid.2.2⟩

theorem backward_external_call (setting : Setting source rows config P Q σ) {cap cap' function ts vs ws k l μ ν label destination}
    (hc : Captures source rows cap cap') (ha : Values source rows vs ws)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.externalCall function ts vs)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.externalCall function ts ws)) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.externalCall function ts ws)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.run (.mk cap (.externalCall function ts vs)) k μ) (.run (.mk cap' (.externalCall function ts ws)) l ν)
      label destination := by
  have closedA := ha.close hc
  have first : (Closure.mk cap (.externalCall function ts vs)).view =
      .externalCall function (ts.map cap'.closeTy) (closeVals cap vs) := by
    change Comp.externalCall function (ts.map cap.closeTy) (closeVals cap vs) = _
    rw [hc.closeTy]
  have second : (Closure.mk cap' (.externalCall function ts ws)).view =
      .externalCall function (ts.map cap'.closeTy) (closeVals cap' ws) := rfl
  obtain ⟨Ψ,declaration,a,e,targetFound,args⟩ := StateTyE.external_args setting.wellFormed setting.wellTyped setting.core
    typed second
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_External =>
    rename_i found response receive view
    injection view with sameF sameT sameA
    subst sameF; subst sameT; subst sameA
    rw [targetFound] at found
    cases found
    exact setting.backAt typed (response_external_backward setting.program.types setting.wellFormed setting.variance
      setting.core first second targetFound response receive args closedA hk hμ avoid)
  case E_ExternalErr =>
    rename_i found response receive view
    injection view with sameF sameT sameA
    subst sameF; subst sameT; subst sameA
    rw [targetFound] at found
    cases found
    exact setting.backAt typed (response_external_error_backward setting.program.types setting.wellFormed setting.variance
      first second targetFound response receive args closedA hk hμ avoid)

theorem ProgramRel.impl_right {name implementation} (program : ProgramRel source rows P Q)
    (found : Q.impls name = some implementation) :
    ∃ original, P.impls name = some original ∧ ImplementationRel source rows original implementation := by
  have related := program.implementations name
  rw [found] at related
  exact optionRel_right_some related

theorem ImplementationRel.dictTys {left right} (h : ImplementationRel source rows left right) :
    left.dictTys = right.dictTys := by
  simp only [Refinement.ImplDecl.dictTys,h.dictionaries]

theorem backward_method (setting : Setting source rows config P Q σ)
    {cap cap' d d' method types effects vs ws k l μ ν label destination}
    (hc : Captures source rows cap cap') (hd : Value source rows d d') (ha : Values source rows vs ws)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.meth d method types effects vs)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.run (.mk cap' (.meth d' method types effects ws)) l ν))
    (step : Step Q (responseTable config rows) σ (.run (.mk cap' (.meth d' method types effects ws)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.run (.mk cap (.meth d method types effects vs)) k μ) (.run (.mk cap' (.meth d' method types effects ws)) l ν)
      label destination := by
  have closedD := hd.close hc
  have closedA := ha.close hc
  have viewParts := NamesAvoid.append.mp
    (show NamesAvoid _ (valueNames (closeVal cap d) ++ valuesNames (closeVals cap vs)) from avoid.1.view)
  have argsAvoid : ValuesAvoid (rows.map Prod.fst) (closeVals cap vs) := valuesNames_avoid.mp viewParts.2
  have first : (Closure.mk cap (.meth d method types effects vs)).view =
      .meth (closeVal cap d) method (types.map cap'.closeTy) (effects.map cap'.closeEff) (closeVals cap vs) := by
    change Comp.meth (closeVal cap d) method (types.map cap.closeTy) (effects.map cap.closeEff) (closeVals cap vs) = _
    rw [hc.closeTy,hc.closeEff]
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_Meth =>
    rename_i found methodFound classFound methodSignature argumentsCount dictionariesCount typesCount methodTypesCount
      effectsCount view
    injection view with sameD sameM sameT sameE sameA
    change closeVal cap' d' = _ at sameD
    subst sameM; subst sameT; subst sameE; subst sameA
    rw [sameD] at closedD
    obtain ⟨sourceDictionaries,sourceD,dictionariesRel⟩ := Value.dictionary_right closedD
    rw [sourceD] at first viewParts
    have dictionariesAvoid : ValuesAvoid (rows.map Prod.fst) _ := valuesNames_avoid.mp viewParts.1
    obtain ⟨original,sourceFound,implRel⟩ := setting.program.impl_right found
    obtain ⟨sourceBody,sourceMethod,methodRel⟩ := optionRel_right_of implRel.methods methodFound
    have sourceClass := (congrArg (fun c => P.classes c) implRel.className).trans
      ((congrFun setting.program.types.classes _).trans classFound)
    have dictionaryTypes := implRel.dictTys
    have bodyAvoid := (setting.programAvoid.2 _ _ sourceFound).1 _ _ sourceMethod
    exact setting.back typed
      (.E_Meth (q := .mk cap' (.meth d' _ _ _ ws))
        (by change Comp.meth (closeVal cap' d') _ _ _ (closeVals cap' ws) = _; rw [sameD]; rfl) found methodFound classFound
        methodSignature argumentsCount dictionariesCount typesCount methodTypesCount effectsCount)
      (.E_Meth first sourceFound sourceMethod sourceClass methodSignature (closedA.length ▸ argumentsCount)
        (dictionariesRel.length ▸ dictionaryTypes.symm ▸ dictionariesCount) (implRel.tparams ▸ typesCount)
        methodTypesCount effectsCount)
      (.run (.mk ((Captures.mk Slots.nil).extendMany (dictionariesRel.append closedA))
        (methodRel.substTy 0 _ _)) hk.markPush hμ)
      ⟨ClosureAvoid.mk.mpr ⟨(CaptureAvoid.empty _).extendMany (ValuesAvoid.append.mpr ⟨dictionariesAvoid,argsAvoid⟩),
          bodyAvoid.substTy 0 _ _⟩,avoid.2.1.markPush,avoid.2.2⟩
  case E_Super =>
    rename_i found view
    injection view with sameD sameM sameT sameE sameA
    change closeVal cap' d' = _ at sameD
    subst sameD; subst sameM; subst sameT; subst sameE; subst sameA
    have outputs := setting.program.superStep closedD
    rw [found] at outputs
    obtain ⟨result,sourceFound,value⟩ := optionRel_right_some outputs
    have resultAvoid := ValueAvoid.superStep setting.programAvoid viewParts.1 sourceFound
    exact setting.back typed (.E_Super rfl found) (.E_Super first sourceFound)
      (.run (.pure (.method value closedA)) hk hμ)
      ⟨ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,NamesAvoid.append.mpr ⟨resultAvoid,valuesNames_avoid.mpr argsAvoid⟩⟩,
        avoid.2.1,avoid.2.2⟩

theorem backward_check_at [StandardModel.RowEnv Q (responseTable config rows)]
    (setting : Setting source rows config P Q σ)
    {cap cap' kind name shape bases bases' pattern pattern' input input' index k l μ ν label destination}
    (hc : Captures source rows cap cap') (hb : OptionalValue source rows bases bases')
    (hp : Value source rows pattern pattern') (hi : Value source rows input input')
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run (.mk cap (.checkAt kind name shape bases pattern input index)) k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect
      (.run (.mk cap' (.checkAt kind name shape bases' pattern' input' index)) l ν))
    (step : Step Q (responseTable config rows) σ
      (.run (.mk cap' (.checkAt kind name shape bases' pattern' input' index)) l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
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
  have prepareEq := at_prepare_equal (B := config.builtins) (D := responseTable config rows) (kind := kind) (name := name)
    (index := index) rfl rfl baseEq patternEq inputEq
  cases step
  all_goals try (exfalso; simp only [Closure.view, Closure.code, reduceCtorEq] at *; done)
  case E_AtOk =>
    rename_i current accepted code prepared
    injection code with sameK sameN sameS sameB sameP sameI sameX
    subst sameK; subst sameN; subst sameS; subst sameB; subst sameP; subst sameI; subst sameX
    have sourcePrepared : AtPrepared config.builtins cap _ _ bases pattern input _ _ _ _ _ := prepareEq.trans prepared
    refine setting.back typed (.E_AtOk rfl prepared current accepted) (.E_AtOk rfl sourcePrepared current accepted)
      (.run (.pure (.ret ?_)) hk hμ) ⟨pure_ret_avoid (at_request_avoid inputAvoid _ _ _ _ _),avoid.2.1,avoid.2.2⟩
    simp only [Closure.capture]
    rw [hc.closeTy,at_request_equal (B := config.builtins) (D := responseTable config rows) rfl inputEq]
    exact .refl _
  case E_AtError =>
    rename_i current failed code prepared
    injection code with sameK sameN sameS sameB sameP sameI sameX
    subst sameK; subst sameN; subst sameS; subst sameB; subst sameP; subst sameI; subst sameX
    have sourcePrepared : AtPrepared config.builtins cap _ _ bases pattern input _ _ _ _ _ := prepareEq.trans prepared
    refine setting.back typed (.E_AtError rfl prepared current failed) (.E_AtError rfl sourcePrepared current failed)
      (.run (.pure (.ret ?_)) hk hμ)
      ⟨pure_ret_avoid (NamesAvoid.append.mpr ⟨at_check_noMint patternAvoid inputAvoid,NamesAvoid.nil _⟩),avoid.2.1,avoid.2.2⟩
    simp only [Closure.capture]
    rw [hc.closeTy,patternEq,inputEq]
    exact .refl _
  case E_AtPrepareError =>
    rename_i code failed
    injection code with sameK sameN sameS sameB sameP sameI sameX
    subst sameK; subst sameN; subst sameS; subst sameB; subst sameP; subst sameI; subst sameX
    have sourceFailed := prepareEq.trans failed
    refine setting.back typed (.E_AtPrepareError rfl failed) (.E_AtPrepareError rfl sourceFailed)
      (.run (.pure (.ret ?_)) hk hμ)
      ⟨pure_ret_avoid (NamesAvoid.append.mpr ⟨at_prepare_noMint patternAvoid inputAvoid sourceFailed,NamesAvoid.nil _⟩),
        avoid.2.1,avoid.2.2⟩
    simp only [Closure.capture]
    rw [hc.closeTy]
    exact .refl _
theorem backward_match_run (setting : Setting source rows config P Q σ)
    {v w cap cap' arms targets next k l μ ν label destination}
    (hv : Value source rows v w) (hc : Captures source rows cap cap') (ha : Arms source rows arms targets)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.matchRun v cap arms next k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.matchRun w cap' targets next l ν))
    (step : Step Q (responseTable config rows) σ (.matchRun w cap' targets next l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.matchRun v cap arms next k μ) (.matchRun w cap' targets next l ν) label destination := by
  obtain ⟨valueAvoid,captureAvoid,armsAvoid,stack,store⟩ := avoid
  cases step with
  | E_MatchSkip found missed =>
    have related := ha.getElem? next
    rw [found] at related
    obtain ⟨arm,sourceFound,armRel⟩ := optionRel_right_some related
    cases armRel with
    | plain body =>
      have matched := optionRel_right_of_none (fun alternatives => hv.firstAlt alternatives) missed
      exact setting.back typed (.E_MatchSkip found missed) (.E_MatchSkip sourceFound matched)
        (.matchRun hv hc ha hk hμ) ⟨valueAvoid,captureAvoid,armsAvoid,stack,store⟩
    | guarded guard body =>
      have matched := optionRel_right_of_none (fun alternatives => hv.firstAlt alternatives) missed
      exact setting.back typed (.E_MatchSkip found missed) (.E_MatchSkip sourceFound matched)
        (.matchRun hv hc ha hk hμ) ⟨valueAvoid,captureAvoid,armsAvoid,stack,store⟩
  | E_MatchBody found matched =>
    have related := ha.getElem? next
    rw [found] at related
    obtain ⟨arm,sourceFound,armRel⟩ := optionRel_right_some related
    cases armRel with
    | plain bodyRel =>
      obtain ⟨arguments,sourceMatched,argumentsRel⟩ :=
        optionRel_right_of (fun alternatives => hv.firstAlt alternatives) matched
      exact setting.back typed (.E_MatchBody found matched) (.E_MatchBody sourceFound sourceMatched)
        (.run (.mk (hc.extendMany argumentsRel) bodyRel) hk hμ)
        ⟨ClosureAvoid.mk.mpr ⟨captureAvoid.extendMany (valueAvoid.firstAlt sourceMatched),(armsAvoid.get sourceFound).1⟩,
          stack,store⟩
  | E_MatchGuard found matched =>
    have related := ha.getElem? next
    rw [found] at related
    obtain ⟨arm,sourceFound,armRel⟩ := optionRel_right_some related
    cases armRel with
    | guarded guardRel bodyRel =>
      obtain ⟨arguments,sourceMatched,argumentsRel⟩ :=
        optionRel_right_of (fun alternatives => hv.firstAlt alternatives) matched
      have bound := captureAvoid.extendMany (valueAvoid.firstAlt sourceMatched)
      exact setting.back typed (.E_MatchGuard found matched) (.E_MatchGuard sourceFound sourceMatched)
        (.run (.mk (hc.extendMany argumentsRel) guardRel)
          (.cons (.guardF hv hc ha (.mk (hc.extendMany argumentsRel) bodyRel)) hk) hμ)
        ⟨ClosureAvoid.mk.mpr ⟨bound,(armsAvoid.get sourceFound).2 _ rfl⟩,
          ContAvoid.cons.mpr ⟨⟨valueAvoid,captureAvoid,armsAvoid,ClosureAvoid.mk.mpr ⟨bound,(armsAvoid.get sourceFound).1⟩⟩,stack⟩,
          store⟩

theorem backward_error (setting : Setting source rows config P Q σ) {errors k l μ ν label destination}
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.error errors k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.error errors l ν))
    (step : Step Q (responseTable config rows) σ (.error errors l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.error errors k μ) (.error errors l ν) label destination := by
  obtain ⟨stack,store⟩ := avoid
  cases hk with
  | nil => cases step
  | cons hf hk =>
    have rest := (ContAvoid.cons.mp stack).2
    cases step with
    | E_ErrPopLet => cases hf; exact setting.back typed .E_ErrPopLet .E_ErrPopLet (.error hk hμ) ⟨rest,store⟩
    | E_ErrPopMark => cases hf; exact setting.back typed .E_ErrPopMark .E_ErrPopMark (.error hk hμ) ⟨rest,store⟩
    | E_ErrPopUpdate => cases hf; exact setting.back typed .E_ErrPopUpdate .E_ErrPopUpdate (.error hk hμ) ⟨rest,store⟩
    | E_ErrPopHandle => cases hf; exact setting.back typed .E_ErrPopHandle .E_ErrPopHandle (.error hk hμ) ⟨rest,store⟩
    | E_ErrPopGuard => cases hf; exact setting.back typed .E_ErrPopGuard .E_ErrPopGuard (.error hk hμ) ⟨rest,store⟩
    | E_ErrRel response =>
      cases hf with
      | release hresource =>
        exact setting.backAt typed (response_error_release_backward setting.active hresource response hk hμ ⟨stack,store⟩)
    | E_ErrRelErr response =>
      cases hf with
      | release hresource =>
        exact setting.backAt typed (response_error_release_error_backward setting.active hresource response hk hμ ⟨stack,store⟩)
    | E_ErrDrop found =>
      cases hf with
      | drop location =>
        obtain ⟨cell,original,related⟩ := hμ.lookup_right found
        cases related
        exact setting.back typed (.E_ErrDrop found) (.E_ErrDrop original) (.error hk hμ) ⟨rest,store⟩
    | E_ErrDropRel found =>
      cases hf with
      | drop location =>
        obtain ⟨cell,original,related⟩ := hμ.lookup_right found
        cases related with
        | cont saved =>
          have savedAvoid : ContAvoid (rows.map Prod.fst) _ := store.lookup original
          exact setting.back typed (.E_ErrDropRel found) (.E_ErrDropRel original)
            (.error (saved.releases.append hk) (hμ.set .used))
            ⟨ContAvoid.append savedAvoid.releases rest,store.set (cell := .used) trivial⟩

theorem backward_exit (setting : Setting source rows config P Q σ) {code errors k l μ ν label destination}
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.exit code errors k μ))
    (typed : StateTyE Q (responseTable config rows) σ effect (.exit code errors l ν))
    (step : Step Q (responseTable config rows) σ (.exit code errors l ν) label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect
      (.exit code errors k μ) (.exit code errors l ν) label destination := by
  obtain ⟨stack,store⟩ := avoid
  cases hk with
  | nil => cases step
  | cons hf hk =>
    have rest := (ContAvoid.cons.mp stack).2
    cases step with
    | E_ExitPopLet => cases hf; exact setting.back typed .E_ExitPopLet .E_ExitPopLet (.exit hk hμ) ⟨rest,store⟩
    | E_ExitPopMark => cases hf; exact setting.back typed .E_ExitPopMark .E_ExitPopMark (.exit hk hμ) ⟨rest,store⟩
    | E_ExitPopUpdate => cases hf; exact setting.back typed .E_ExitPopUpdate .E_ExitPopUpdate (.exit hk hμ) ⟨rest,store⟩
    | E_ExitPopHandle => cases hf; exact setting.back typed .E_ExitPopHandle .E_ExitPopHandle (.exit hk hμ) ⟨rest,store⟩
    | E_ExitPopGuard => cases hf; exact setting.back typed .E_ExitPopGuard .E_ExitPopGuard (.exit hk hμ) ⟨rest,store⟩
    | E_ExitRel response =>
      cases hf with
      | release hresource =>
        exact setting.backAt typed (response_exit_release_backward setting.active hresource response hk hμ ⟨stack,store⟩)
    | E_ExitRelErr response =>
      cases hf with
      | release hresource =>
        exact setting.backAt typed (response_exit_release_error_backward setting.active hresource response hk hμ ⟨stack,store⟩)
    | E_ExitDrop found =>
      cases hf with
      | drop location =>
        obtain ⟨cell,original,related⟩ := hμ.lookup_right found
        cases related
        exact setting.back typed (.E_ExitDrop found) (.E_ExitDrop original) (.exit hk hμ) ⟨rest,store⟩
    | E_ExitDropRel found =>
      cases hf with
      | drop location =>
        obtain ⟨cell,original,related⟩ := hμ.lookup_right found
        cases related with
        | cont saved =>
          have savedAvoid : ContAvoid (rows.map Prod.fst) _ := store.lookup original
          exact setting.back typed (.E_ExitDropRel found) (.E_ExitDropRel original)
            (.exit (saved.releases.append hk) (hμ.set .used))
            ⟨ContAvoid.append savedAvoid.releases rest,store.set (cell := .used) trivial⟩

/-- 準備後の状態の全ての実一段は、元の状態の空でない有限実行に対応する。 -/
theorem StateRel.backward [StandardModel.RowLookup config.builtins] [StandardModel.RowEnv Q (responseTable config rows)]
    (setting : Setting source rows config P Q σ) {s t label destination}
    (related : StateRel source rows s t) (avoid : NoGeneratedKeys rows s)
    (typed : StateTyE Q (responseTable config rows) σ effect t)
    (step : Step Q (responseTable config rows) σ t label destination) :
    BackwardResult source rows P Q config.builtins (responseTable config rows) σ effect s t label destination := by
  induction related generalizing label destination with
  | run closure stack store =>
    cases closure with
    | mk hc code =>
      cases code with
      | builder hm => exact backward_builder setting hc hm stack store avoid typed step
      | builderOp ha => exact backward_builder_operation setting hc ha stack store avoid typed step
      | ret hv => exact backward_ret setting hc hv stack store avoid typed step
      | letIn hm hn => exact backward_let setting hc hm hn stack store avoid typed step
      | app hf ha => exact backward_app setting hc hf ha stack store avoid typed step
      | ite hv hm hn => exact backward_ite setting hc hv hm hn stack store avoid typed step
      | matchC hv ha => exact backward_match setting hc hv ha stack store avoid typed step
      | lazyC hm => exact backward_lazy setting hc hm stack store avoid typed step
      | escape hv => exact backward_escape setting hc hv stack store avoid typed step
      | use hv hm => exact backward_use setting hc hv hm stack store avoid typed step
      | handle hm hh => exact backward_handle setting hc hm hh stack store avoid typed step
      | resume hv hkv => exact backward_resume setting hc hkv hv stack store avoid typed step
      | externalCall ha => exact backward_external_call setting hc ha stack store avoid typed step
      | pathBases b => exact backward_issue_path_bases setting stack store avoid typed step
      | checkAt hb hp hi => exact backward_check_at setting hc hb hp hi stack store avoid typed step
      | method hd ha => exact backward_method setting hc hd ha stack store avoid typed step
      | scalar lookup count inputs simple value =>
        exact ScalarPhase.backward_invariant P Q config.builtins σ setting.wellFormed setting.wellTyped setting.effects
          setting.core setting.pathEnvironment (ScalarPhase.initial _ _ _ _ _ _) lookup inputs simple hc value
          stack store typed avoid step
      | projected lookup route arguments inputs count types simple value =>
        exact projected_root_backward setting.program setting.wellFormed setting.wellTyped setting.effects setting.core
          setting.pathEnvironment setting.variance (setting.valid _ _ lookup) lookup route arguments inputs types simple hc
          value stack store typed avoid step
  | matchRun hv hc ha hk hμ => exact backward_match_run setting hv hc ha hk hμ avoid typed step
  | error hk hμ => exact backward_error setting hk hμ avoid typed step
  | exit hk hμ => exact backward_exit setting hk hμ avoid typed step
  | scalarPhase lookup count inputs simple hc hv hk hμ phase =>
    exact ScalarPhase.backward_invariant P Q config.builtins σ setting.wellFormed setting.wellTyped setting.effects
      setting.core setting.pathEnvironment phase lookup inputs simple hc hv hk hμ typed avoid step
  | projectedApplication lookup view inputs count read hk hμ =>
    exact projected_application_backward P Q config.builtins σ setting.wellFormed setting.wellTyped setting.effects
      setting.core setting.pathEnvironment setting.variance (setting.valid _ _ lookup) lookup view inputs count read
      hk hμ typed avoid step
  | administrative path related ih =>
    exact BackwardResult.prepend setting.program.getters path (ih (path.noMint avoid) typed step)

/-- 準備後の実行の一段の模倣。元の側は常に一段以上を進める。 -/
theorem Setting.backward [StandardModel.RowLookup config.builtins] [StandardModel.RowEnv Q (responseTable config rows)]
    (setting : Setting source rows config P Q σ) :
    Trace.Forward Q (responseTable config rows) P config.builtins σ
      (fun t s => InvariantRel source rows Q (responseTable config rows) σ effect s t) (fun _ => 0) := by
  intro t s label destination related step
  obtain ⟨next,steps,nextRelated,descends⟩ := StateRel.backward setting related.1 related.2.1 related.2.2 step
  exact ⟨next,steps,nextRelated,Or.inl descends⟩

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
