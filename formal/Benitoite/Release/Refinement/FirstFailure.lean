import Benitoite.Release.Refinement.StandardIntegerFailure
import Benitoite.Release.Refinement.IntervalFailure

/-! # 後続の独立した拒否と、実行の最初の失敗が違う反例 -/
namespace Benitoite.Release.Refinement.IntervalConnection.H04

/-- 選んだ同じ実行経路について、まだ error に入っていないことを示す。 -/
def BeforeError : State → Prop
  | .error .. => False
  | _ => True

inductive BeforeErrorSteps (P : Program) (B : Builtins) (σ : PathEnv) :
    State → List Event → State → Prop where
  | nil {s} : BeforeError s → BeforeErrorSteps P B σ s [] s
  | cons {s t u event events} : BeforeError s → Step P B σ s event t →
      BeforeErrorSteps P B σ t events u →
      BeforeErrorSteps P B σ s (event.toList ++ events) u

/-- 最初の失敗の位置と、その位置で実際に拒否した pure の δ だけを観測する。 -/
def FirstFailureHandoff : Prop :=
  ∀ (P : Program) (B : Builtins) (σ : PathEnv) (q : Closure) (k : Cont) (μ : Store)
    (events : List Event) (errors : List ErrKind) (lastK : Cont) (lastStore : Store),
    Steps P B σ (.run q k μ) events (.error errors lastK lastStore) →
    ∃ (preEvents : List Event) (before : State) (event : Option Event)
      (firstErrors : List ErrKind) (firstK : Cont) (firstStore : Store) (suffix : List Event),
      BeforeErrorSteps P B σ (.run q k μ) preEvents before ∧
      Step P B σ before event (.error firstErrors firstK firstStore) ∧
      Steps P B σ (.error firstErrors firstK firstStore) suffix (.error errors lastK lastStore) ∧
      events = preEvents ++ event.toList ++ suffix ∧
      ∀ (focus : Closure) (atK : Cont) (atStore : Store) (b : PrimName)
        (ts : List Ty) (es : List Eff) (ranges : List RangeExpr) (ws : List Val) (sg : PrimSig),
        before = .run focus atK atStore → focus.view = .app (.prim b ts es (List.map RangeIx.fixed ranges)) ws →
        B.sig b = some sg → sg.kind = .pure →
        event = none ∧ ∃ r, firstErrors = [r] ∧ B.delta b (Ty.normTys ts) (es.map Eff.norm) ranges ws = some (.err r)

noncomputable section

/-- 有限な実行を、error に入る最初の一歩と前後の列へ分ける。 -/
theorem first_error {P B σ s target events}
    (run : Steps P B σ s events target) :
    BeforeError s → ∀ errors lastK lastStore, target = .error errors lastK lastStore →
    ∃ preEvents before event firstErrors firstK firstStore suffix,
      BeforeErrorSteps P B σ s preEvents before ∧
      Step P B σ before event (.error firstErrors firstK firstStore) ∧
      Steps P B σ (.error firstErrors firstK firstStore) suffix (.error errors lastK lastStore) ∧
      events = preEvents ++ event.toList ++ suffix := by
  induction run with
  | nil => intro start errors lastK lastStore he; cases he; exact False.elim start
  | @cons s t u event events step tail ih =>
    intro start errors lastK lastStore finish
    cases ht : t with
    | error rs k μ =>
      exact ⟨[],s,event,rs,k,μ,events,.nil start,ht ▸ step,finish ▸ (ht ▸ tail),by simp⟩
    | run q k μ | matchRun v cap arms next k μ | exit n rs k μ =>
      obtain ⟨pre,before,ev,errs,k0,μ0,post,hpre,hs,htail,he⟩ :=
        ih (by rw [ht]; trivial) errors lastK lastStore finish
      exact ⟨event.toList ++ pre,before,ev,errs,k0,μ0,post,
        .cons start step hpre,hs,htail,by simp only [he,List.append_assoc]⟩

/-- pure の呼出しから error に入る一歩は、同じ実引数の δ の拒否である。 -/
theorem pure_failure {P B σ q k μ event errors firstK firstStore b ts es ranges ws sg}
    (step : Step P B σ (.run q k μ) event (.error errors firstK firstStore))
    (view : q.view = .app (.prim b ts es (List.map RangeIx.fixed ranges)) ws)
    (signature : B.sig b = some sg) (pure : sg.kind = .pure) :
    event = none ∧ ∃ r, errors = [r] ∧ B.delta b (Ty.normTys ts) (es.map Eff.norm) ranges ws = some (.err r) := by
  have map_inj : Function.Injective (List.map RangeIx.fixed) :=
    fun xs ys he => by
      have hc := congrArg closedRanges he
      simpa only [closedRanges_fixed, Option.some.injEq] using hc
  cases step <;> simp_all [map_inj.eq_iff]

/-- 最初の error の位置で pure の δ を観測する。算術との一致は前提に含めない。 -/
theorem first_failure_handoff : FirstFailureHandoff := by
  intro P B σ q k μ events errors lastK lastStore run
  obtain ⟨pre,before,ev,errs,k0,μ0,post,hpre,hs,ht,he⟩ := first_error run (by trivial) errors lastK lastStore rfl
  refine ⟨pre,before,ev,errs,k0,μ0,post,hpre,hs,ht,he,?_⟩
  intro focus atK atStore b ts es ranges ws sg eq view signature pure
  cases eq
  exact pure_failure hs view signature pure

example {P B σ q k μ events errors lastK lastStore}
    (run : Steps P B σ (.run q k μ) events (.error errors lastK lastStore)) :=
  first_failure_handoff P B σ q k μ events errors lastK lastStore run


end

end Benitoite.Release.Refinement.IntervalConnection.H04

namespace Benitoite.Release.Refinement.IntervalConnection.H04Counterexample
noncomputable section

def OldH04 : Prop := (∀ (P : Program) (B : Builtins) (σ : PathEnv)
    (concrete : Benitoite.Interval.ConcreteEnv) (input : Benitoite.Interval.EvalInput)
    (reason : Benitoite.Interval.Failure) (trace : Benitoite.Interval.EvalTrace)
    (op : Benitoite.Surface.OpPrim) (ξ : Nat → Nat) (cap : Capture) (code : Comp) (k : Cont) (μ : Store),
    EnvRelAt concrete cap ξ →
    code = ((Benitoite.Interval.SurfaceCode.expr op .other input.source).rename ξ) →
    Benitoite.Interval.EvalPartial concrete input (.failed reason) trace →
    TrackedFailure reason trace →
    Runs P B σ (fun _ _ => True) (.mk cap code) k μ (.failed reason) →
    let failures : Benitoite.Interval.Failure → List Benitoite.Release.ErrKind → Prop := fun rejected rs =>
      ∃ event ∈ trace, event.result = .rejected rejected ∧
        match event.operation with
        | .binary bin type => ∃ b ts ws r,
            op (.binary bin) type = some (b,ts) ∧ ValuesRel event.arguments ws ∧
            B.delta b (Ty.normTys (embedTys ts)) [] [] ws = some (.err r) ∧ r ∈ rs
        | .neg type => ∃ b ts ws r,
            op .neg type = some (b,ts) ∧ ValuesRel event.arguments ws ∧
            B.delta b (Ty.normTys (embedTys ts)) [] [] ws = some (.err r) ∧ r ∈ rs
        | .standard binding => ∃ ws events μ' rejectedErrors,
            ValuesRel event.arguments ws ∧ rejectedErrors ≠ [] ∧
            Steps P B σ (.run (Closure.pure (.app (.fnRef binding.declaration [] []) ws)) [] Store.empty)
              events (.error rejectedErrors [] μ') ∧ ∀ r ∈ rejectedErrors, r ∈ rs
    ∃ (events : List Event) (μ' : Store) (rs : List Benitoite.Release.ErrKind),
      Steps P B σ (.run (.mk cap code) k μ) events (.error rs k μ') ∧ failures reason rs : Prop)

private def one : Benitoite.Release.Integer64Value := ⟨1,by decide⟩
private def minusOne : Benitoite.Release.Integer64Value := ⟨-1,by decide⟩
private def minimum : Benitoite.Release.Integer64Value := ⟨Benitoite.Release.min64,by decide⟩
private def env : Benitoite.Interval.ConcreteEnv := ⟨[some (.integer one),some (.integer minimum)],[],fun _ => none⟩
private def cap : Capture := (Capture.empty.extend (.const (.integer minimum))).extend (.const (.integer one))
private def key : Benitoite.Interval.OperationKey := ⟨"counterexample",0⟩
private def left : Benitoite.Surface.Expr := .neg (.base .integer) (.local 0)
private def right : Benitoite.Surface.Expr := .neg (.base .integer) (.local 1)
private def input : Benitoite.Interval.EvalInput := ⟨.binary .add (.base .integer) left right,.base .integer,key⟩
private def op : Benitoite.Surface.OpPrim := fun operator _ => match operator with
  | .neg => some ("neg",[])
  | .binary .add => some ("add",[])
  | _ => none
private def sig : PrimSig := ⟨[],0,["value"],[.base .integer],.base .integer,Eff.empty,fun _ _ => True,.pure,none,[],.untargeted⟩
private def B : Builtins where
  sig := fun _ => some sig
  delta := fun _ _ _ _ args => match args with
    | [.const (.integer n)] => if n.toInt = 1 then some (.err "LeftError") else some (.val (.const (.integer n)))
    | _ => some (.val (.const .unit))
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"
private def P : Program := ⟨fun _ => none,fun _ => none,fun _ => none,fun _ => none,fun _ => none,fun _ => none,[],fun _ => none⟩
private def leftEvent : Benitoite.Interval.EvalEvent := ⟨Benitoite.Interval.childKey key [],.neg (.base .integer),[.integer one],.normal (.integer minusOne)⟩
private def rightEvent : Benitoite.Interval.EvalEvent := ⟨Benitoite.Interval.childKey key [left],.neg (.base .integer),[.integer minimum],.rejected .overflow⟩
private def trace : Benitoite.Interval.EvalTrace := [leftEvent,rightEvent]
private def code : Comp :=
  .letIn (.letIn (.ret (.var 0)) (.app (.prim "neg" [] [] []) [.var 0]))
    (.letIn (.letIn (.ret (.var 2)) (.app (.prim "neg" [] [] []) [.var 0]))
      (.app (.prim "add" [] [] []) [.var 1,.var 0]))

private theorem code_source :
    code = (Benitoite.Interval.SurfaceCode.expr op .other input.source).rename id := by
  simp [code, Benitoite.Interval.SurfaceCode.expr, input, left, right,
    Benitoite.Interval.SurfaceSyntax.liftExpr, Benitoite.Interval.SurfaceSyntax.liftPosition,
    Benitoite.Interval.SurfaceSyntax.liftOp, Benitoite.Interval.SurfaceSyntax.eraseOperator,
    Benitoite.Interval.SurfaceSyntax.eraseBinOp,
    Benitoite.Interval.SurfaceSyntax.liftBinOp, op, Surface.desugarExpr,
    Surface.sequence, Surface.letChain, Surface.boundVars, Comp.rename, Val.rename, Val.renameList, upRen,
    Surface.shiftTs, embedTy, List.range, List.range.loop]


private theorem independent : Benitoite.Interval.EvalPartial env input (.failed .overflow) trace := by
  have hl := Benitoite.Interval.EvalPartial.neg env (Benitoite.Interval.childKey key []) (.local 0) one [] (Benitoite.Interval.EvalPartial.local _ _ 0 (.integer one) rfl)
  have hr := Benitoite.Interval.EvalPartial.neg env (Benitoite.Interval.childKey key [left]) (.local 1) minimum [] (Benitoite.Interval.EvalPartial.local _ _ 1 (.integer minimum) rfl)
  have hleft : Benitoite.Interval.checkedNeg one = .normal (.integer minusOne) := by rfl
  have hright : Benitoite.Interval.checkedNeg minimum = .rejected .overflow := by rfl
  rw [hleft] at hl
  rw [hright] at hr
  exact Benitoite.Interval.EvalPartial.addRightAbrupt env key left right minusOne (.failed .overflow) [leftEvent] [rightEvent] hl hr trivial

private theorem environment : EnvRelAt env cap id := by
  apply EnvRel.at
  exact EnvRel.extend (EnvRel.extend (env := ⟨[],[],fun _ => none⟩) (cap := Capture.empty) .nil (.integer .integer64 minimum)) (.integer .integer64 one)

private theorem tracked : TrackedFailure .overflow trace :=
  ⟨by decide, rightEvent,by simp [trace],rfl⟩

private theorem runtime (σ : PathEnv) : Runs P B σ (fun _ _ => True) (.mk cap code) [] Store.empty (.failed .overflow) := by
  refine ⟨[],.error ["LeftError"] [] Store.empty,?_,Store.empty,["LeftError"],rfl,trivial⟩
  apply Steps.cons (Step.E_Let (by rfl))
  apply Steps.cons (Step.E_Let (by rfl))
  apply Steps.cons (Step.E_Return (by rfl))
  apply Steps.cons (Step.E_Err (r := "LeftError") (s := sig) (b := "neg") (ts := []) (es := []) (rs := [])
    (ws := [.const (.integer one)]) rfl rfl rfl (by simp [B,one,Benitoite.Release.Integer64Value.toInt]))
  exact .cons .E_ErrPopLet .nil

private theorem no_later_delta (ws : List Val) (h : ValuesRel [.integer minimum] ws) :
    ∀ ts r, B.delta "neg" (Ty.normTys (embedTys ts)) [] [] ws ≠ some (.err r) := by
  cases h with
  | cons hv hs =>
    cases hs; cases hv
    intro ts r
    simp [B,minimum,Benitoite.Interval.IntegerValue.toConst,embedConst,Benitoite.Release.Integer64Value.toInt,Benitoite.Release.min64]

/-- 同じ環境・脱糖の独立評価と実行でも、後続の拒否の δ は一致しない。 -/
theorem old_candidate_false : ¬ OldH04 := by
  intro claim
  obtain ⟨σ,_,_,_,_,_⟩ := NormalReplyExamples.concrete_normal_replies
  obtain ⟨events,μ,rs,_,h⟩ := claim P B σ env input .overflow trace op id cap code [] Store.empty environment code_source independent tracked (runtime σ)
  -- standard の枝は両事象で生じないため、σ の選び方は結論の否定に影響しない。
  obtain ⟨event,hm,he,hdelta⟩ := h
  simp only [trace,List.mem_cons,List.not_mem_nil,or_false] at hm
  rcases hm with rfl | rfl
  · cases he
  · obtain ⟨b,ts,ws,r,hop,hvs,hd,_⟩ := hdelta
    have hop' : ("neg",[]) = (b,ts) := Option.some.inj hop
    cases hop'
    exact no_later_delta ws hvs [] r hd

/-- 同じ反例で、最初に失敗する左の neg の位置の δ を観測できる。 -/
theorem revised_counterexample_accepted (σ : PathEnv) :
    ∃ preEvents before firstErrors firstK firstStore suffix,
      H04.BeforeErrorSteps P B σ (.run (.mk cap code) [] Store.empty) preEvents before ∧
      Step P B σ before none (.error firstErrors firstK firstStore) ∧
      Steps P B σ (.error firstErrors firstK firstStore) suffix (.error ["LeftError"] [] Store.empty) ∧
      (∃ q k μ, before = .run q k μ ∧ q.view = .app (.prim "neg" [] [] []) [.const (.integer one)]) ∧
      B.delta "neg" [] [] [] [.const (.integer one)] = some (.err "LeftError") := by
  let continuation : Cont := [.letF (.mk cap (match code with | .letIn _ n => n | _ => .ret (.const .unit)))]
  have preEvents : H04.BeforeErrorSteps P B σ (.run (.mk cap code) [] Store.empty) []
      (.run (.mk (cap.extend (.const (.integer one))) (.app (.prim "neg" [] [] []) [.var 0]))
        continuation Store.empty) := by
    apply H04.BeforeErrorSteps.cons (by trivial) (.E_Let rfl)
    apply H04.BeforeErrorSteps.cons (by trivial) (.E_Let rfl)
    apply H04.BeforeErrorSteps.cons (by trivial) (.E_Return rfl)
    exact .nil (by trivial)
  refine ⟨[],_,["LeftError"],continuation,Store.empty,[],preEvents,?_,.cons .E_ErrPopLet .nil,?_,?_⟩
  · exact .E_Err (s := sig) (b := "neg") (ts := []) (es := []) (rs := [])
      (ws := [.const (.integer one)]) rfl rfl rfl (by simp [B,one,Benitoite.Release.Integer64Value.toInt])
  · exact ⟨_,_,_,rfl,rfl⟩
  · simp [B,one,Benitoite.Release.Integer64Value.toInt]

example : ¬ OldH04 := old_candidate_false
example (σ : PathEnv) := revised_counterexample_accepted σ

end
end Benitoite.Release.Refinement.IntervalConnection.H04Counterexample
