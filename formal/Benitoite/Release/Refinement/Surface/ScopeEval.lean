import Benitoite.Release.Refinement.Surface.ScopeRules

/-!
# Scope の局所解析の一段の具体の評価と健全性

局所解析の一段（`ScopeState.Step`）に、篩付きの型の核の値 `Refinement.Val` の上の具体の評価（`StepEval`）を置き、
規則の表が健全なら、局所の状態の事実が一段の後も具体の局所の値に対応することを示す（`absStep_sound`）。予算付きの
一段（`Run.step`）は、上限の値によらず、超過して由来を忘れる場合も含めて対応を保つ（`Run.step_models`）。
必須の判定が Top でない添字を付けた位置の値は、その範囲に属する対象を保持する（`requiredIndex_checked`）
（設計書 01-12「Scope の局所解析の状態と規則の表」「Scope の局所解析の予算と忘却」）。
-/

namespace Benitoite.Release.Refinement.Surface.ScopeState

open Benitoite.Scope.Inference
open Benitoite.Scope.Domain (Range Target)

/-- 局所の具体の値。束縛の位置ごとに、値を持たない（専用位置や読まない束縛）か値を持つ。 -/
abbrev Locals := List (Option Refinement.Val)

/-! ## リテラルの綴り -/

theorem litInt?_intLitText (n : Integer64Value) : litInt? (intLitText n) = some n.toInt := by
  simp [litInt?, intLitText, String.ofList_toList, Int.toInt?_repr]

theorem litModels_intLitText (n : Integer64Value) : LitModels (intLitText n) (.const (.integer n)) := by
  simp only [LitModels, litInt?_intLitText]
  exact ⟨n, rfl, rfl⟩

/-! ## 必須の判定の添字 -/

/-- 局所の読み取りに付ける添字は、その位置の必須の判定の添字と同じである。 -/
theorem argIndex_readLocal (st : ScopeState) (i : Nat) : argIndex (st.readLocal i) = st.requiredIndex i := by
  unfold ScopeState.readLocal ScopeState.requiredIndex
  cases hid : st.scope.idAt i with
  | none =>
    cases hf : st.facts[i]? with
    | none => rfl
    | some fo =>
      cases fo with
      | none => rfl
      | some f => cases f <;> simp [argIndex]
  | some id =>
    cases hf : st.facts[i]? with
    | none => rfl
    | some fo =>
      cases fo with
      | none => rfl
      | some f => cases f <;> simp [argIndex]

/-- 必須の判定が Top でない添字を付けた位置の値は、その添字の範囲に属する対象を保持する値である。 -/
theorem requiredIndex_checked {ok : ConName} {pattern : String → Option Range} {st : ScopeState} {env : Locals}
    (hm : st.Models (models ok pattern) env) {i : Nat} {v : Refinement.Val} (found : env[i]? = some (some v))
    (hne : st.requiredIndex i ≠ .top) :
    ∃ (o : Origin) (t : Target), v.target? = some t ∧ t.kind = o.kind ∧ st.requiredIndex i = o.bound.index ∧
      (st.requiredIndex i).Mem t := by
  obtain ⟨o, id, hidx, hmod⟩ := st.requiredIndex_fact hm found hne
  change factModel ok pattern (.checked o id) id v at hmod
  obtain ⟨-, hc⟩ := hmod
  obtain ⟨t, ht, hk, hmt⟩ := checkedModels_iff.mp hc
  exact ⟨o, t, ht, hk, hidx, hidx ▸ hmt⟩

/-! ## 一段の具体の評価 -/

/-- 引数の具体の評価。同定されない射影の出現とそれ以外の式は任意の値を返してよい。 -/
inductive EvalArg (T : ScopeTable Refinement.Val) (env : Locals) : Arg → Refinement.Val → Prop where
  | lit (s : String) : EvalArg T env (.lit s) (.const (.string s))
  | int (n : Integer64Value) : EvalArg T env (.int n) (.const (.integer n))
  | loc (i : Nat) (v : Refinement.Val) (found : env[i]? = some (some v)) : EvalArg T env (.loc i) v
  | proj (key : Key) (i : Nat) (rs : List Range) (w v : Refinement.Val) (found : env[i]? = some (some w))
      (eval : EvalScope T key rs [w] v) : EvalArg T env (.proj key i) v
  | projOther (key : Key) (i : Nat) (v : Refinement.Val) (missing : T.ruleAt key = none) :
      EvalArg T env (.proj key i) v
  | other (v : Refinement.Val) : EvalArg T env .other v

inductive EvalArgs (T : ScopeTable Refinement.Val) (env : Locals) : List Arg → List Refinement.Val → Prop where
  | nil : EvalArgs T env [] []
  | cons {a as v vs} : EvalArg T env a v → EvalArgs T env as vs → EvalArgs T env (a :: as) (v :: vs)

/-- 具体の一段。同定されない呼び出しと未知の値は任意の値を返してよい。 -/
inductive StepEval (ok : ConName) (T : ScopeTable Refinement.Val) : Locals → Step → Locals → Prop where
  | callStd {env key args vs rs v} : EvalArgs T env args vs → EvalScope T key rs vs v →
      StepEval ok T env (.call key args) (some v :: env)
  | callOther {env key args v} : T.ruleAt key = none → StepEval ok T env (.call key args) (some v :: env)
  | okArm {env i v w} : env[i]? = some (some v) → okPayload ok v = some w →
      StepEval ok T env (.okArm i) (some w :: env)
  | alias {env i w} : env[i]? = some (some w) → StepEval ok T env (.alias i) (some w :: env)
  | unknown {env v} : StepEval ok T env .unknown (v :: env)
  | join {env} : StepEval ok T env .join env

inductive StepsEval (ok : ConName) (T : ScopeTable Refinement.Val) : Locals → List Step → Locals → Prop where
  | nil {env} : StepsEval ok T env [] env
  | cons {env env' env'' s ss} : StepEval ok T env s env' → StepsEval ok T env' ss env'' →
      StepsEval ok T env (s :: ss) env''

theorem absArgs_models {ok : ConName} {pattern : String → Option Range} {T : ScopeTable Refinement.Val}
    (hT : TableSound (models ok pattern) T) {st : ScopeState} {env : Locals}
    (hm : st.Models (models ok pattern) env)
    {args : List Arg} {vs : List Refinement.Val} (hev : EvalArgs T env args vs) :
    ArgsModel (models ok pattern) (args.map (absArg T st)) vs := by
  induction hev with
  | nil => exact .nil
  | cons ha _ ih =>
    refine .cons ?_ ih
    cases ha with
    | lit s =>
      simp only [absArg]
      cases hs : litInt? s with
      | some _ => exact trivial
      | none =>
        simp only [Option.isSome_none, Bool.false_eq_true, ite_false]
        exact (litModels_of_none hs).mpr rfl
    | int n => exact litModels_intLitText n
    | loc i v found => exact ScopeState.readLocal_models hm found
    | proj key i rs w v found eval =>
      simp only [absArg]
      cases hf : absApply T key [st.readLocal i] with
      | none => exact trivial
      | some f => exact apply_sound hT (.cons (ScopeState.readLocal_models hm found) .nil) eval hf
    | projOther key i v missing =>
      simp only [absArg, absApply, missing]
      exact trivial
    | other v => exact trivial

/-- 一段の健全性。表が健全で、状態が具体の局所に対応すれば、一段の後も対応する。 -/
theorem absStep_sound {ok : ConName} {pattern : String → Option Range} {T : ScopeTable Refinement.Val}
    (hT : TableSound (models ok pattern) T) {st : ScopeState} {env env' : Locals} {s : Step}
    (hm : st.Models (models ok pattern) env) (hev : StepEval ok T env s env') :
    (absStep T st s).Models (models ok pattern) env' := by
  cases hev with
  | callStd hargs heval =>
    refine ScopeState.extend_models hm (fun f hf => ⟨_, rfl, ?_⟩)
    exact apply_sound hT (absArgs_models hT hm hargs) heval hf _
  | callOther hmissing =>
    refine ScopeState.extend_models hm (fun f hf => ?_)
    simp [absApply, hmissing] at hf
  | okArm found hok =>
    rename_i i v w
    refine ScopeState.extend_models hm (fun f hf => ?_)
    cases hfi : st.facts[i]? with
    | none => simp [hfi] at hf
    | some fo =>
      cases fo with
      | none => simp [hfi] at hf
      | some g =>
        cases g with
        | result o =>
          simp only [hfi, Option.some.injEq] at hf
          subst hf
          obtain ⟨id, value, -, hval, hmod⟩ := hm i (.result o) hfi
          rw [found] at hval
          cases hval
          exact ⟨w, rfl, rfl, hmod w hok⟩
        | _ => simp [hfi] at hf
  | alias _ => exact ScopeState.extend_models hm (fun f hf => by cases hf)
  | unknown => exact ScopeState.extend_models hm (fun f hf => by cases hf)
  | join => exact ScopeState.forgetAll_models _ st _

/-! ## 予算付きの一段の健全性 -/

/-- 由来を作らない一段は、具体の一段に対応を保つ。 -/
theorem blindStep_models {ok : ConName} {pattern : String → Option Range} {T : ScopeTable Refinement.Val}
    {st : ScopeState} {env env' : Locals} {s : Step} (hm : st.Models (models ok pattern) env)
    (hev : StepEval ok T env s env') : (blindStep st s).Models (models ok pattern) env' := by
  cases hev with
  | join => exact ScopeState.forgetAll_models _ st _
  | callStd => exact ScopeState.extend_models hm (fun f hf => by cases hf)
  | callOther => exact ScopeState.extend_models hm (fun f hf => by cases hf)
  | okArm => exact ScopeState.extend_models hm (fun f hf => by cases hf)
  | alias => exact ScopeState.extend_models hm (fun f hf => by cases hf)
  | unknown => exact ScopeState.extend_models hm (fun f hf => by cases hf)

/-- 予算付きの一段の健全性。上限の値によらず、超過して由来を忘れる場合も含めて対応を保つ。 -/
theorem Run.step_models {ok : ConName} {pattern : String → Option Range} {T : ScopeTable Refinement.Val}
    (hT : TableSound (models ok pattern) T) (L : Limits) {r : Run} {env env' : Locals} {s : Step}
    (hm : r.state.Models (models ok pattern) env) (hev : StepEval ok T env s env') :
    (r.step T L s).state.Models (models ok pattern) env' := by
  cases r with
  | running st b =>
    simp only [Run.step]
    split
    · exact absStep_sound hT hm hev
    · exact blindStep_models (ScopeState.forgetAll_models _ st env) hev
  | stopped f st b => exact blindStep_models hm hev

theorem Run.steps_models {ok : ConName} {pattern : String → Option Range} {T : ScopeTable Refinement.Val}
    (hT : TableSound (models ok pattern) T) (L : Limits) {ss : List Step} :
    ∀ {r : Run} {env env' : Locals}, r.state.Models (models ok pattern) env → StepsEval ok T env ss env' →
      (r.steps T L ss).state.Models (models ok pattern) env' := by
  induction ss with
  | nil => intro r env env' hm hev; cases hev; exact hm
  | cons s ss ih =>
    intro r env env' hm hev
    cases hev with
    | cons h1 h2 => exact ih (Run.step_models hT L hm h1) h2

/-- 本体の入口の状態は任意の具体の局所に対応する（由来を仮定しない）。 -/
theorem Run.enter_models (M : FactModels Refinement.Val) (scope : Interval.BindingScope) (r : Run)
    (env : Locals) : (r.enter scope).state.Models M env := by
  cases r with
  | running => exact ScopeState.empty_models M scope env
  | stopped f st b =>
    simp only [Run.enter]
    split <;> exact ScopeState.empty_models M scope env

/-- 本体の出口は外側の状態（またはその忘却）に戻るので、外側の対応を保つ。 -/
theorem Run.leave_models {M : FactModels Refinement.Val} {outer : Run} {env : Locals}
    (hm : outer.state.Models M env) (inner : Run) : (outer.leave inner).state.Models M env := by
  cases inner with
  | stopped f _ ib =>
    simp only [Run.leave]
    split
    · exact ScopeState.forgetAll_models M _ env
    · cases outer <;> exact hm
  | running _ ib => cases outer <;> exact hm

end Benitoite.Release.Refinement.Surface.ScopeState
