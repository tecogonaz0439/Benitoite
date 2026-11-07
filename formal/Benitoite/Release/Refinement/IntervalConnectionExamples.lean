import Benitoite.Release.Refinement.IntervalConnection

/-! # 捕捉の束縛・return・guard と独立評価の具体の接続 -/
namespace Benitoite.Release.Refinement.IntervalConnection
noncomputable section
open Benitoite.Interval (ConcreteValue EvalPartial EvalBlock EvalArms EvalWidthArms EvalResultArms)
namespace Examples
private def env : Benitoite.Interval.ConcreteEnv := ⟨[],[],fun _ => none⟩
private def key : Benitoite.Interval.OperationKey := ⟨"control",0⟩
private def op : Benitoite.Surface.OpPrim := fun _ _ => none
private def failures : Benitoite.Interval.Failure → List ErrKind → Prop := fun reason rs =>
  reason = .unknown ∧ rs = [rResume]
private def body : Comp := .letIn (.ret (.var 0)) (.escape (.var 0))
private def source : Benitoite.Surface.Block := .bind .bind (.base .unit) .unit
  (.last (.returnE (.base .unit) (.local 0)))
private def code : Comp := .letIn (.ret (.const .unit)) body
private theorem unitRel : ValueRel .unit (.const .unit) := .unit
private theorem atom {P B σ q k μ c v}
    (hv : q.view = .ret v) (hrel : ValueRel c v) : Runs P B σ failures q k μ (.normal c) :=
  ⟨[],.run q k μ,.nil,q,μ,v,rfl,hv,hrel⟩

/-- 二つの let の間で同じ値の番号を前置し、途中の return を mark で戻す。 -/
theorem binding_and_return (P : Program) (B : Builtins) (σ : PathEnv) :
    BlockCode op .other source code ∧
    EvalBlock env key source (.base .unit) (.returned .unit) [] ∧
    Runs P B σ failures (.mk Capture.empty code) [.mark] Store.empty (.returned .unit) ∧
    Runs P B σ failures (.mk Capture.empty code) [.mark] Store.empty (.normal .unit) [] := by
  have henv : EnvRel env Capture.empty := .nil
  have heval : EvalPartial env ⟨.unit,.base .unit,key⟩ (.normal .unit) [] := .unit _ _
  have teval : EvalBlock {env with locals := [some .unit]} (Benitoite.Interval.advanceKey key 1)
      (.last (.returnE (.base .unit) (.local 0))) (.base .unit) (.returned .unit) [] :=
    .last _ _ _ _ _ _ (.returnE _ _ _ _ _ _ _ (.local _ _ 0 .unit rfl))
  have head : Runs P B σ failures (.mk Capture.empty (.ret (.const .unit)))
      (.letF (.mk Capture.empty body) :: [.mark]) Store.empty (.normal .unit) := atom rfl unitRel
  have tail : ∀ v μ', ValueRel .unit v → EnvRel {env with locals := [some .unit]} (Capture.empty.extend v) →
      Runs P B σ failures (.mk (Capture.empty.extend v) body) [.mark] μ' (.returned .unit) := by
    intro v μ' hv henv'
    have hl : Runs P B σ failures (.mk (Capture.empty.extend v) (.ret (.var 0)))
        (.letF (.mk (Capture.empty.extend v) (.escape (.var 0))) :: [.mark]) μ' (.normal .unit) := atom rfl hv
    have hc := connect_return (op := op) (resultType := Benitoite.Release.Ty.base .unit)
      (key := Benitoite.Interval.advanceKey key 1) (source := .local 0) henv' (by simp only [ExprCode, Benitoite.Interval.SurfaceCode.expr, Benitoite.Interval.SurfaceSyntax.liftExpr, Benitoite.Interval.SurfaceSyntax.liftPosition, Surface.desugarExpr] <;> rfl)
      (EvalPartial.local _ _ 0 .unit rfl) hl
    exact hc.2.2.2
  have result := connect_bind (op := op) (position := .other) (kind := Benitoite.Surface.BindKind.bind)
    (k := [.mark]) henv (by simp only [ExprCode, Benitoite.Interval.SurfaceCode.expr, Benitoite.Interval.SurfaceSyntax.liftExpr, Benitoite.Interval.SurfaceSyntax.liftPosition, Surface.desugarExpr] <;> rfl) (show BlockCode op .other (.last (.returnE (.base .unit) (.local 0))) body from by
          simp only [BlockCode, Benitoite.Interval.SurfaceCode.block,
            Benitoite.Interval.SurfaceSyntax.liftExpr, Benitoite.Interval.SurfaceSyntax.liftBlock,
            Benitoite.Interval.SurfaceSyntax.liftPosition, Surface.desugarExpr,
            Surface.desugarBlock, body] <;> rfl)
    heval teval head tail
  exact ⟨result.1,result.2.1,result.2.2,result.2.2.returned_mark⟩

/-- 七幅の正しい定数は、同じ値へ一意に戻り、同じ近似に所属する。 -/
theorem integer_values (B : Builtins) (kind : Benitoite.Interval.IntKind) (n : Benitoite.Interval.IntegerValue kind) :
    let c := embedConst (Benitoite.Interval.IntegerValue.toConst kind n)
    c = embedConst (Benitoite.Interval.IntegerValue.toConst kind n) ∧
    (Benitoite.Interval.normalToShared kind.type (Benitoite.Interval.topNormal kind.type)).Mem c.toApprox := by
  dsimp only
  have hc : ConstOK B (embedConst (Benitoite.Interval.IntegerValue.toConst kind n)) := by
    cases kind <;> first | trivial | exact n.property
  have hk : Benitoite.Interval.IntKind.ofRefinementType (embedConst (Benitoite.Interval.IntegerValue.toConst kind n)).type = some kind := by
    cases kind <;> rfl
  have ha : (embedConst (Benitoite.Interval.IntegerValue.toConst kind n)).toApprox = .integer kind n := by
    cases kind <;> first | rfl | exact Shared.ApproxValue.ofInt_bounded _ n
  have he := const_integer_same_value hc hk n ha
  have hrel : ValueRel (.ofInteger kind n) (.const (embedConst (Benitoite.Interval.IntegerValue.toConst kind n))) :=
    .integer kind n
  exact ⟨he,(normal_shared_iff hrel (Benitoite.Interval.ConcreteValue.ofInteger_type kind n)).mpr
    ⟨Benitoite.Interval.ConcreteValue.ofInteger_type kind n,by cases kind <;> first | trivial | exact n.property⟩⟩

private def alternative : Benitoite.Surface.Alternative := ⟨.var,[0]⟩
private def alts : List Alt := [alternative.toCore]
private def integer : Benitoite.Release.Integer64Value := ⟨7,by decide⟩
private def integerVal : Val := .const (.integer integer)
private def integerCore : Benitoite.Release.Val := .const (.integer integer)
private theorem integerRel : ValueRel (.integer integer) integerVal := .integer .integer64 integer

/-- 最初の変数パターンを選び、実際の一束縛を両方の環境へ加える。 -/
theorem integer_arm (P : Program) (B : Builtins) (σ : PathEnv) :
    EvalArms env key integer (.cons [alternative] none (.last (.local 0)) .nil) (.base .integer)
      (.normal (.integer integer)) [] ∧
    ValueRel (.integer integer) integerVal ∧
    ArmBodyConnection env Capture.empty id op .other (.last (.local 0)) (.ret (.var 0)) [.integer integer] [integerVal] ∧
    ∃ events state, Steps P B σ (.matchRun integerVal Capture.empty [.mk alts none (.ret (.var 0))] 0 [] Store.empty)
      events state ∧ EndState failures (.normal (.integer integer)) [] state := by
  have sel : Benitoite.Interval.IntegerSelection [alternative] integer [.integer integer] :=
    ⟨[],alternative,[],[.integer integer],[integerCore],rfl,(by simp),rfl,rfl,rfl,rfl⟩
  have ev : EvalBlock {env with locals := [some (.integer integer)]} key (.last (.local 0)) (.base .integer)
      (.normal (.integer integer)) [] := .last _ _ _ _ _ _ (.local _ _ 0 (.integer integer) rfl)
  exact connect_integer_arm (env := env) (cap := Capture.empty) (ξ := id) (op := op) (position := .other) (EnvRel.at (.nil : EnvRel env Capture.empty)) (.cons integerRel .nil) sel ev integerRel (by
          simp only [Benitoite.Interval.SurfaceCode.block, Benitoite.Interval.SurfaceSyntax.liftExpr,
            Benitoite.Interval.SurfaceSyntax.liftBlock,
            Benitoite.Interval.SurfaceSyntax.liftPosition, Surface.desugarExpr,
            Surface.desugarBlock, Comp.rename, Val.rename, upRen] <;> rfl) rfl rfl (atom rfl integerRel)

/-- 幅付き整数も同じ slots と変数番号で束縛する。 -/
theorem width_arm (P : Program) (B : Builtins) (σ : PathEnv) (kind : Benitoite.Interval.IntKind)
    (n : Benitoite.Interval.IntegerValue kind) :
    let v := Val.const (embedConst (Benitoite.Interval.IntegerValue.toConst kind n))
    EvalWidthArms env key kind n (.cons [alternative] none (.last (.local 0)) .nil) kind.type
      (.normal (.ofInteger kind n)) [] ∧
    ValueRel (.ofInteger kind n) v ∧
    ArmBodyConnection env Capture.empty id op .other (.last (.local 0)) (.ret (.var 0)) [.ofInteger kind n] [v] ∧
    ∃ events state, Steps P B σ (.matchRun v Capture.empty [.mk alts none (.ret (.var 0))] 0 [] Store.empty)
      events state ∧ EndState failures (.normal (.ofInteger kind n)) [] state := by
  dsimp only
  have sel : Benitoite.Interval.WidthSelection [alternative] kind n [.ofInteger kind n] :=
    ⟨[],alternative,[],[.ofInteger kind n],[Benitoite.Interval.integerPatternValue kind n],rfl,(by simp),rfl,rfl,rfl,rfl⟩
  have ev : EvalBlock {env with locals := [some (.ofInteger kind n)]} key (.last (.local 0)) kind.type
      (.normal (.ofInteger kind n)) [] := by
    simpa only [Benitoite.Interval.ConcreteValue.ofInteger_type] using
      (EvalBlock.last _ _ _ _ _ _ (EvalPartial.local _ _ 0 (.ofInteger kind n) rfl))
  have hr : ValueRel (.ofInteger kind n) (.const (embedConst (Benitoite.Interval.IntegerValue.toConst kind n))) :=
    .integer kind n
  exact connect_width_arm (env := env) (cap := Capture.empty) (ξ := id) (op := op) (position := .other) (EnvRel.at (.nil : EnvRel env Capture.empty)) (.cons hr .nil) sel ev hr (by
          simp only [Benitoite.Interval.SurfaceCode.block, Benitoite.Interval.SurfaceSyntax.liftExpr,
            Benitoite.Interval.SurfaceSyntax.liftBlock,
            Benitoite.Interval.SurfaceSyntax.liftPosition, Surface.desugarExpr,
            Surface.desugarBlock, Comp.rename, Val.rename, upRen] <;> rfl) rfl rfl (atom rfl hr)

private def names : Benitoite.Interval.RangeNames := ⟨"Range","Range.Checked","Result","RangeError","Result.Ok","Result.Error","InvalidBounds","OutOfRange"⟩
private def result : ConcreteValue := .con names.result [.base .unit,.data names.error []] names.ok [.unit]

/-- Result の腕はtag と payload を同じ選択へ渡す。 -/
theorem result_arm (P : Program) (B : Builtins) (σ : PathEnv) :
    EvalResultArms env key names result names.ok .unit (.cons [alternative] none (.last .unit) .nil) (.base .unit)
      (.normal .unit) [] ∧
    ValueRel result (.con names.ok [.base .unit,.data names.error []] [.const .unit]) ∧
    (∃ code ws, ArmBodyConnection env Capture.empty id op .other (.last .unit) code [result] ws) ∧
    ∃ events state, Steps P B σ (.matchRun (.con names.ok [.base .unit,.data names.error []] [.const .unit]) Capture.empty
      [.mk alts none (.ret (.const .unit))] 0 [] Store.empty) events state ∧ EndState failures (.normal .unit) [] state := by
  have hr : ValueRel result (.con names.ok [.base .unit,.data names.error []] [.const .unit]) := .con (.cons unitRel .nil)
  apply connect_result_arm (env := env) (cap := Capture.empty) (ξ := id) (op := op) (position := .other)
    (EnvRel.at (.nil : EnvRel env Capture.empty))
    (by intro a ha; cases List.mem_singleton.mp ha; rfl)
    ⟨[],alternative,[],[result],rfl,(by simp),rfl,rfl,rfl⟩ (.last _ _ _ _ _ _ (.unit _ _)) hr
  intro ws hm hws
  have he : ws = [.con names.ok [.base .unit,.data names.error []] [.const .unit]] := by
    simpa [firstAlt,matchVal,selectSlots,Benitoite.Surface.Alternative.toCoreList,
      Benitoite.Surface.Alternative.toCore,alternative,Benitoite.Surface.Pattern.toCore] using hm.symm
  subst ws
  refine ⟨.ret (.const .unit),?_,rfl,atom rfl unitRel⟩
  simp only [Benitoite.Interval.SurfaceCode.block, Benitoite.Interval.SurfaceSyntax.liftBlock,
    Benitoite.Interval.SurfaceSyntax.liftExpr, Benitoite.Interval.SurfaceSyntax.liftPosition,
    Surface.desugarBlock, Surface.desugarExpr, Comp.rename, Val.rename] <;> rfl

/-- Ok/Error の逆の tag と Unit/構造値は関係せず、同じ Ok の腕だけが成功する。 -/
theorem result_tag_contrast :
    ¬ ValueRel result (.con names.err [] [.const .unit]) ∧
    ¬ ValueRel .unit (.con names.ok [] []) ∧
    ¬ ValueRel (.con names.result [] names.ok [.unit]) (.con names.ok [] [.con names.err [] []]) ∧
    (∃ ws, firstAlt (.con names.ok [] [.const .unit])
      (Benitoite.Surface.Alternative.toCoreList
        [⟨.con none names.err [.var],[0]⟩,⟨.con none names.ok [.var],[0]⟩]) = some ws ∧
      ValuesRel [.unit] ws) := by
  refine ⟨?_,?_,?_,?_⟩
  · intro h; obtain ⟨ts,vs,he,_⟩ := h.con_inv
    exact (by decide : names.err ≠ names.ok) (Val.con.inj he).1
  · intro h; cases h
  · intro h; obtain ⟨ts,vs,he,hs⟩ := h.con_inv; cases he
    cases hs with
    | cons hu _ => cases hu
  · apply result_selection_related (names := names) (types := [])
      (ValueRel.con (.cons ValueRel.unit .nil))
      (by intro a ha; simp only [List.mem_cons,List.not_mem_nil,or_false] at ha
          rcases ha with rfl | rfl <;> rfl)
    exact ⟨[⟨.con none names.err [.var],[0]⟩],⟨.con none names.ok [.var],[0]⟩,[],[.unit],rfl,
      (by intro a ha; cases List.mem_singleton.mp ha; rfl),rfl,rfl,rfl⟩

private def guardArms (truth : Bool) : List Arm :=
  [.mk [.mk .wild []] (some (.ret (.const (.boolean truth)))) (.ret (.const .unit)),
   .mk [.mk .wild []] none (.ret (.const .unit))]
private def guardFrame (truth : Bool) : Frame :=
  .guardF (.const .unit) Capture.empty (guardArms truth) 1 (.mk Capture.empty (.ret (.const .unit)))

/-- 真では本体へ戻り、偽では元の捕捉で次の腕へ進む。 -/
theorem guards (P : Program) (B : Builtins) (σ : PathEnv) :
    ∀ truth, ∃ events state, Steps P B σ (.matchRun (.const .unit) Capture.empty (guardArms truth) 0 [] Store.empty)
      events state ∧ EndState failures (.normal .unit) [] state := by
  intro truth
  apply runs_match_guard (ws := []) rfl rfl
  cases truth
  · have hg : Runs P B σ failures (.mk Capture.empty (.ret (.const (.boolean false)))) [guardFrame false] Store.empty
        (.normal (.boolean false)) := atom rfl (.boolean _)
    obtain ⟨events,μ,hs⟩ := runs_guard_false hg
    have tail : ∃ events state, Steps P B σ (.matchRun (.const .unit) Capture.empty (guardArms false) 1 [] μ)
        events state ∧ EndState failures (.normal .unit) [] state :=
      (runs_match_body (env := env) (cap := Capture.empty) (.nil : EnvRel env Capture.empty) (.nil : ValuesRel [] []) rfl rfl (atom rfl unitRel)).2
    obtain ⟨rest,state,ht,he⟩ := tail
    exact ⟨events ++ rest,state,steps_trans hs ht,he⟩
  · have hg : Runs P B σ failures (.mk Capture.empty (.ret (.const (.boolean true)))) [guardFrame true] Store.empty
        (.normal (.boolean true)) := atom rfl (.boolean _)
    exact runs_guard_true hg (fun μ => atom rfl unitRel)

private def sampleInput : Nat → ArmInput
  | 0 => .integer integer
  | 1 => .width .integer8 ⟨7,by decide⟩
  | _ => .result names result names.ok .unit
private def sampleValue : Nat → ConcreteValue
  | 0 => .integer integer
  | 1 => .integer8 ⟨7,by decide⟩
  | _ => result
private def sampleRuntime : Nat → Val
  | 0 => integerVal
  | 1 => .const (.integer8 7)
  | _ => .con names.ok [] [.const .unit]
private def fallback : Benitoite.Surface.Arms := .cons [⟨.wild,[]⟩] none (.last .unit) .nil
private def guardedRuntime (truth : Bool) : List Arm :=
  [.mk alts (some (.ret (.const (.boolean truth)))) (.ret (.const .unit)),
   .mk [.mk .wild []] none (.ret (.const .unit))]

private theorem sample_selection (i : Nat) : (sampleInput i).Selection [alternative] [sampleValue i] := by
  cases i with
  | zero => exact ⟨[],alternative,[],[.integer integer],[integerCore],rfl,(by simp),rfl,rfl,rfl,rfl⟩
  | succ i => cases i with
    | zero => exact ⟨[],alternative,[],[.integer8 ⟨7,by decide⟩],[.const (.integer8 7)],rfl,(by simp),rfl,rfl,rfl,rfl⟩
    | succ i => exact ⟨[],alternative,[],[result],rfl,(by simp),rfl,rfl,rfl⟩

private theorem sample_relation (i : Nat) : ValueRel (sampleValue i) (sampleRuntime i) := by
  cases i with
  | zero => exact integerRel
  | succ i => cases i with
    | zero => exact .integer .integer8 ⟨7,by decide⟩
    | succ i => exact .con (.cons unitRel .nil)

private theorem fallback_eval (i : Nat) (key : Benitoite.Interval.OperationKey) :
    (sampleInput i).Eval env key fallback (.base .unit) (.normal .unit) [] := by
  cases i with
  | zero => exact (.body _ _ _ _ _ _ _ _ _ _
      ⟨[],⟨.wild,[]⟩,[],[],[],rfl,(by simp),rfl,rfl,rfl,rfl⟩ (.last _ _ _ _ _ _ (.unit _ _)))
  | succ i => cases i with
    | zero => exact (.body _ _ _ _ _ _ _ _ _ _ _
        ⟨[],⟨.wild,[]⟩,[],[],[],rfl,(by simp),rfl,rfl,rfl,rfl⟩ (.last _ _ _ _ _ _ (.unit _ _)))
    | succ i => exact (.body _ _ _ _ _ _ _ _ _ _ _ _ _
        ⟨[],⟨.wild,[]⟩,[],[],rfl,(by simp),rfl,rfl,rfl⟩ (.last _ _ _ _ _ _ (.unit _ _)))

/-- Integer・幅付き整数・Result の全てで、真の本体と偽の次の腕を両評価で構成する。 -/
theorem independent_arm_guards (P : Program) (B : Builtins) (σ : PathEnv) (i : Nat) (truth : Bool) :
    (sampleInput i).Eval env key (.cons [alternative] (some (.literal (.boolean truth))) (.last .unit) fallback)
      (.base .unit) (.normal .unit) [] ∧
    ∃ events state, Steps P B σ (.matchRun (sampleRuntime i) Capture.empty (guardedRuntime truth) 0 [] Store.empty)
      events state ∧ EndState failures (.normal .unit) [] state := by
  have hr := sample_relation i
  have hm : firstAlt (sampleRuntime i) alts = some [sampleRuntime i] := rfl
  have henv := EnvRel.at (env := env) (cap := Capture.empty) (.nil : EnvRel env Capture.empty)
  have hvs : ValuesRel [sampleValue i] [sampleRuntime i] := .cons hr .nil
  cases truth
  · have result := connect_arm_guard_false (P := P) (B := B) (σ := σ) (k := []) (μ := Store.empty) (body := .last .unit)
      (input := sampleInput i) henv hvs (sample_selection i)
      (EvalPartial.boolean _ _ false)
      (fallback_eval i (Benitoite.Interval.advanceKey key (Benitoite.Interval.surfaceSize (.literal (.boolean false)) + Benitoite.Interval.blockSize (.last .unit))))
      (hi := show (guardedRuntime false)[0]? = some (.mk alts (some (.ret (.const (.boolean false)))) (.ret (.const .unit))) from rfl)
      hm (atom rfl (.boolean false))
      (fun μ' => (runs_match_body (env := env) (cap := Capture.empty) (.nil : EnvRel env Capture.empty) (.nil : ValuesRel [] []) rfl rfl (atom rfl unitRel)).2)
    exact ⟨result.1,result.2.2⟩
  · have result := connect_arm_guard_true (key := key) (rest := fallback) (P := P) (B := B) (σ := σ) (k := []) (μ := Store.empty)
      (input := sampleInput i) henv hvs (sample_selection i)
      (EvalPartial.boolean _ _ true) (EvalBlock.last _ _ _ _ _ _ (EvalPartial.unit _ _))
      (hi := show (guardedRuntime true)[0]? = some (.mk alts (some (.ret (.const (.boolean true)))) (.ret (.const .unit))) from rfl)
      hm (atom rfl (.boolean true)) (fun μ' => atom rfl unitRel)
    exact ⟨result.1,result.2.2⟩

private def missed : Benitoite.Surface.Alternative := ⟨.con none "Missing" [.var],[0]⟩
/-- 三種類の腕で、実際に失敗するパターンを飛ばし、元の環境の次の腕へ進む。 -/
theorem independent_arm_skip (P : Program) (B : Builtins) (σ : PathEnv) (i : Nat) :
    (sampleInput i).Eval env key (.cons [missed] none (.last .unit) fallback) (.base .unit) (.normal .unit) [] ∧
    ∃ events state, Steps P B σ (.matchRun (sampleRuntime i) Capture.empty
      [.mk (Benitoite.Surface.Alternative.toCoreList [missed]) none (.ret (.const .unit)),
       .mk [.mk .wild []] none (.ret (.const .unit))] 0 [] Store.empty)
      events state ∧ EndState failures (.normal .unit) [] state := by
  have miss : (sampleInput i).Miss [missed] := by
    cases i with
    | zero => intro a ha; cases List.mem_singleton.mp ha; rfl
    | succ i => cases i with
      | zero => intro a ha; cases List.mem_singleton.mp ha; rfl
      | succ i => intro a ha; cases List.mem_singleton.mp ha; rfl
  have hm : firstAlt (sampleRuntime i) (Benitoite.Surface.Alternative.toCoreList [missed]) = none := by
    cases i with
    | zero => rfl
    | succ i => cases i <;> rfl
  exact connect_arm_skip (sampleInput i) miss
    (fallback_eval i (Benitoite.Interval.advanceKey key (Benitoite.Interval.guardSize none + Benitoite.Interval.blockSize (.last .unit))))
    rfl hm ((runs_match_body (env := env) (cap := Capture.empty) (.nil : EnvRel env Capture.empty) (.nil : ValuesRel [] []) rfl rfl (atom rfl unitRel)).2)

private def minimum : Benitoite.Release.Integer64Value := ⟨Benitoite.Release.min64,by decide⟩
private def overflowEnv : Benitoite.Interval.ConcreteEnv := {env with locals := [some (.integer minimum)]}
private def overflowTrace : Benitoite.Interval.EvalTrace :=
  [⟨key,.neg (.base .integer),[.integer minimum],.rejected .overflow⟩]

/-- 実際の算術の拒否は tracked に属し、unknown の失敗は候補の対象から区別する。 -/
theorem tracked_failure_contrast :
    EvalPartial overflowEnv ⟨.neg (.base .integer) (.local 0),.base .integer,key⟩ (.failed .overflow) overflowTrace ∧
    TrackedFailure .overflow overflowTrace ∧ ¬ TrackedFailure .unknown [] := by
  have hx : Benitoite.Interval.checkedNeg minimum = .rejected .overflow := by rfl
  have he := EvalPartial.neg overflowEnv key (.local 0) minimum [] (EvalPartial.local _ _ 0 (.integer minimum) rfl)
  rw [hx] at he
  exact ⟨he,⟨by decide,⟨_,List.mem_cons_self,rfl⟩⟩,fun h => h.1 rfl⟩

private def failedSource : Benitoite.Surface.Expr := .resume 0 .unit
private def failedCode : Comp := .resume (.loc 0) (.const .unit)
private def used : Store := Store.empty.set 0 .used
private theorem failed_eval : EvalPartial env ⟨failedSource,.base .unit,key⟩ (.failed .unknown) [] :=
  .unknownFailed _ _ (by simp [Benitoite.Interval.UnknownAt,Benitoite.Interval.Unsupported,Benitoite.Interval.classify,failedSource])
private theorem failed_run (P : Program) (B : Builtins) (σ : PathEnv) (k : Cont) :
    Runs P B σ failures (.mk Capture.empty failedCode) k used (.failed .unknown) :=
  ⟨[],.error [rResume] k used,.cons (.E_ResumeErr rfl (by simp [used,Store.set])) .nil,used,[rResume],rfl,rfl,rfl⟩

/-- 子の失敗を let と guard の双方から、同じ理由列で外へ出す。 -/
theorem failure_propagation (P : Program) (B : Builtins) (σ : PathEnv) :
    EvalBlock env key (.bind .bind (.base .unit) failedSource (.last .unit)) (.base .unit) (.failed .unknown) [] ∧
    Runs P B σ failures (.mk Capture.empty (.letIn failedCode (.ret (.const .unit)))) [] used (.failed .unknown) ∧
    Runs P B σ failures (.mk Capture.empty failedCode) [guardFrame true] used (.failed .unknown) [] := by
  have hb := connect_bind_failed (kind := Benitoite.Surface.BindKind.bind) (rest := .last .unit)
    (type := Benitoite.Release.Ty.base .unit) failed_eval
    (failed_run P B σ [.letF (.mk Capture.empty (.ret (.const .unit)))])
  exact ⟨hb.1,hb.2,runs_guard_failed (failed_run P B σ [guardFrame true])⟩

/-- 最初のパターンが失敗した場合も、次の成功の束縛を使う。 -/
theorem skipped_arm (P : Program) (B : Builtins) (σ : PathEnv) :
    let arms : List Arm := [.mk [.mk (.const (.boolean false)) []] none (.ret (.const .unit)),
      .mk [.mk .wild []] none (.ret (.const .unit))]
    ∃ events state, Steps P B σ (.matchRun (.const (.boolean true)) Capture.empty arms 0 [] Store.empty)
      events state ∧ EndState failures (.normal .unit) [] state := by
  dsimp only
  apply runs_match_skip (alts := [.mk (.const (.boolean false)) []]) (guard := none) (body := .ret (.const .unit)) rfl rfl
  exact (runs_match_body (env := env) (cap := Capture.empty) (.nil : EnvRel env Capture.empty)
    (.nil : ValuesRel [] []) rfl rfl (atom rfl unitRel)).2

/-- 脱糖の腕は、パターンの束縛を保護して元の変数の前へ照合対象を挿入する。 -/
theorem arm_code_and_environment :
    let arms := Benitoite.Interval.SurfaceCode.arms op .other
      (.cons [alternative] none (.last (.local 0)) .nil)
    arms = [.mk alts none (.ret (.var 0))] ∧
    (env.locals.length = Capture.empty.values.length) := by
  refine ⟨?_,EnvRel.length (.nil : EnvRel env Capture.empty)⟩
  simp only [Benitoite.Interval.SurfaceCode.arms, Benitoite.Interval.SurfaceSyntax.liftArms,
    Benitoite.Interval.SurfaceSyntax.liftMaybe, Benitoite.Interval.SurfaceSyntax.liftBlock,
    Benitoite.Interval.SurfaceSyntax.liftExpr, Benitoite.Interval.SurfaceSyntax.liftPosition,
    Surface.SourceRename.block_last, Surface.SourceRename.expr_local] <;> rfl

/-- 腕の変数0と、照合値の追加位置を越える外側の変数1を同時に読む。 -/
theorem inserted_scrutinee :
    EnvRelAt {env with locals := [some .unit,some (.integer integer)]}
      ((Capture.empty.extend integerVal).extend (.const (.boolean true)) |>.extendMany [.const .unit])
      (Benitoite.Release.upRen 1 (fun i => i+1)) ∧
    (((Capture.empty.extend integerVal).extend (.const (.boolean true))).extendMany [.const .unit]).env 0 = .const .unit ∧
    (((Capture.empty.extend integerVal).extend (.const (.boolean true))).extendMany [.const .unit]).env 2 = integerVal := by
  have he : EnvRel {env with locals := [some (.integer integer)]} (Capture.empty.extend integerVal) :=
    EnvRel.extend (env := env) (cap := Capture.empty) (.nil : EnvRel env Capture.empty) integerRel
  have hi := (he.at.insert (.const (.boolean true))).extendMany (.cons unitRel .nil)
  exact ⟨hi,rfl,rfl⟩

/-- normal と returned は値が同じでも混同しない。 -/
theorem result_constructors (P : Program) (B : Builtins) (σ : PathEnv) :
    (∃ result, ResultRel failures (.normal .unit) result) ∧
    ¬ ResultRel failures (.normal .unit) (.returned (.const .unit)) := by
  obtain ⟨_,state,_,he⟩ := (binding_and_return P B σ).2.2.2
  exact ⟨he.result,fun h => h⟩

private theorem unit_escape {P B σ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ Eff.empty (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
    EndState (fun _ _ => False) (.normal .unit) [] (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) := by
  have ha : Ty.Annotation P [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have hq := ClosureTy.pure (B := B) (Ψ := StoreTy.empty)
    (.C_Escape (ε := Eff.empty) (.V_Const (c := .unit) (by trivial)) ha) ha.done_empty
    (by intro r hr; cases hr; exact ⟨trivial,trivial⟩) rfl (by intro r hr; cases hr; rfl)
  have hk := ContTy.K_Mark (ContTy.K_Empty (R := none) (P := P) (B := B) (σ := σ)
    (Ψ := StoreTy.empty) (show Eff.Sub Eff.empty Eff.empty from ⟨fun _ h => h,fun _ h => h⟩) ha) ha
  have hs : StateTyE P B σ Eff.empty (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty) :=
    ⟨StoreTy.empty,some (.base .unit),.base .unit,.base .unit,Eff.empty,Eff.empty,
      StoreOk.empty _ _ σ,hq,⟨fun _ h => h,fun _ h => h⟩,hk,by trivial,by trivial,
      (by intro f hf; cases List.mem_singleton.mp hf; trivial),(by intro l c h; cases h)⟩
  exact typed_returned_mark hP hPB hB hs rfl unitRel

/-- 途中 return の実際の終状態を、同じ値の関係と型付けで結ぶ。 -/
theorem concrete_interval_control :
    ∃ (P : Program) (B : Builtins) (σ : PathEnv), P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ σ.Valid ∧
      ∃ events state, Steps P B σ (.run (.mk Capture.empty code) [.mark] Store.empty) events state ∧
        EndState (fun _ _ => False) (.normal .unit) [] state ∧ StateTyE P B σ Eff.empty state := by
  obtain ⟨σ,hσ,hP,hPB,hB,_⟩ := NormalReplyExamples.concrete_normal_replies
  obtain ⟨ht,he⟩ := unit_escape hP hPB hB
  refine ⟨_,_,σ,hP,hPB,hB,hσ,[],.run (Closure.pure (.ret (.const .unit))) [] Store.empty,?_,he,ht⟩
  exact .cons (.E_Let rfl) (.cons (.E_Return rfl) (.cons (.E_Let rfl)
    (.cons (.E_Return rfl) (.cons (.E_EscMark rfl) .nil))))

private theorem view_observation_model {P B}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    (∃ f : FnView, f.names = ["value"] ∧ f.names.Nodup ∧
      f.toTel.fnViewWith? [] = some f ∧ Ty.foldFnWith [] f.toTel = .fn f.names f.params f.result f.effect) ∧
    (∃ u, (closeVal Capture.empty integerVal).toTerm? = some u ∧
      termBind (valEnv Capture.empty.env).values (.integer 7) = u ∧ u.HasSort [] .integer ∧
      HasTypeV P B StoreTy.empty [] [] [] (closeVal Capture.empty integerVal) (Capture.empty.closeTy (.base .integer))) := by
  let f : FnView := ⟨["value"],[.base .unit],.base .unit,Eff.empty,⟨rfl,by simp⟩⟩
  have hs : f.toTel.Support (·∈([] : List Atom)) :=
    (Ty.support_toTel_iff _ _ _ _ _ f.names_wf).mpr ⟨⟨trivial,trivial⟩,trivial,⟨(by intro a h; cases h),trivial⟩⟩
  have hv := (Tel.fnViewWith?_eq_some_iff [] f.toTel f hs).mpr rfl
  have hcontract := Tel.function_view_contract hs hv
  have ht : HasTypeV P B StoreTy.empty [] [] [] integerVal (.base .integer) := .V_Const trivial
  exact ⟨⟨f,rfl,hcontract.2.2.2.1,hv,hcontract.2.2.2.2⟩,
    ht.captured_observation hP hPB hB (by intro l x hx; cases hx) (by intro l x hx; cases hx)
      (by intro l x hx; cases hx) (CaptureOk.empty P B StoreTy.empty none) rfl (by trivial)⟩

/-- 名前のある関数 view と数値の観測に、同じ具体の表の契約を適用する。 -/
theorem concrete_view_observation :
    ∃ (P : Program) (B : Builtins) (σ : PathEnv), P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ σ.Valid ∧
      (∃ f : FnView, f.names = ["value"] ∧ f.names.Nodup ∧
        f.toTel.fnViewWith? [] = some f ∧ Ty.foldFnWith [] f.toTel = .fn f.names f.params f.result f.effect) ∧
      (∃ u, (closeVal Capture.empty integerVal).toTerm? = some u ∧
        termBind (valEnv Capture.empty.env).values (.integer 7) = u ∧ u.HasSort [] .integer ∧
        HasTypeV P B StoreTy.empty [] [] [] (closeVal Capture.empty integerVal) (Capture.empty.closeTy (.base .integer))) := by
  obtain ⟨σ,hσ,hP,hPB,hB,_⟩ := NormalReplyExamples.concrete_normal_replies
  exact ⟨_,_,σ,hP,hPB,hB,hσ,view_observation_model hP hPB hB⟩

end Examples
end
end Benitoite.Release.Refinement.IntervalConnection
