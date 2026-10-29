import Benitoite.Scope.Inference
import Benitoite.Scope.SignatureExamples
import Benitoite.Interval.RangeState

/-!
# Scope の成功の局所解析のモデル（L00.05 のモデル）

0.0.13 の L00.05 のモデルである。L00.08 で、評価関係・抽象値・局所状態の骨格を採用定義 `Scope.Inference` へ
移し、本モデルはそれを具体の値 `CVal` と対応 `models` で具体化して直接使う。具体の値・解析器・検査と射影の規則・
文の小さな言語（`Step`・`StepEval`・`absStep`）・小例はモデルだけの定義であり、本番の値と表層の構文への接続は
L40 で行う（`l00.08/placement.md`）。

Range の事実と Scope の事実を同じ束縛番号の上の別の成分に置く形は、採用定義の `LocalState` を区間解析の
`Interval.RangeLocalFact` で具体化して示す（そのためだけに本モデルは `Interval.RangeState` を import する。
採用定義は import しない）。

公開名（DET-03）は L00.08 の一括の問い（問 22）の表のとおりである。条件の射影（`Scope.pathPattern`）は初段の公開名に
加えない例であり、名前はモデルの中だけのものである。
-/

namespace Benitoite.Scope.InferenceExamples

open Benitoite.Scope.Domain
open Benitoite.Scope.Inference

/-! ## 具体の値と文字列の境界 -/

/-- 比較に要る具体の値。`checked pattern raw t` は検査に渡した同じパターンの文字列と対象の文字列、
解析した対象を保持する範囲付きの値（判断 7 の「同じ要求を保持する」と同じ形）。 -/
inductive CVal where
  | str (s : String)
  | checked (pattern raw : String) (t : Target)
  | ok (v : CVal)
  | err (v : CVal)
  | unit
  deriving DecidableEq, Repr

/-- パターンと対象の文字列の解析。形式化の外側（plan「形式化の内外」）であり、任意の関数として量化する。
型検査器がリテラルを解析する関数と、実行時の検査が使う関数は同じものとする。 -/
structure Parsers where
  pat : String → Option Range
  target : String → Option Target

/-- 由来と成功値の対応。対象の解析・種類・動的なパターンへの所属・型の添字への所属、既知の範囲なら
保持したパターンがその範囲に解析されること。 -/
def checkedModels (P : Parsers) (o : Origin) : CVal → Prop
  | .checked ps raw t =>
      P.target raw = some t ∧ t.kind = o.kind ∧ (∃ q, P.pat ps = some q ∧ q.Mem t) ∧
        o.bound.index.Mem t ∧ ∀ r, o.bound = .known r → P.pat ps = some r
  | _ => False

/-- 検査の Result の対応。`Ok` なら同じ由来の成功値、`Err` は任意。 -/
def resultModels (P : Parsers) (o : Origin) : CVal → Prop
  | .ok w => checkedModels P o w
  | .err _ => True
  | _ => False

/-- 事実と、束縛番号 id の位置にある具体の値の対応。成功値の事実はその番号にだけ有効である。 -/
def factModel (P : Parsers) : ScopeFact → Nat → CVal → Prop
  | .pattern r, _, v => ∃ s, v = .str s ∧ P.pat s = some r
  | .result o, _, v => resultModels P o v
  | .checked o sid, id, v => sid = id ∧ checkedModels P o v

/-- モデルの対応。リテラルは同じ文字列の値である。 -/
def models (P : Parsers) : FactModels CVal := ⟨fun s v => v = .str s, factModel P⟩

@[simp] theorem models_fact (P : Parsers) : (models P).fact = factModel P := rfl
@[simp] theorem models_lit (P : Parsers) (s : String) (v : CVal) : (models P).lit s v ↔ v = .str s := Iff.rfl

/-! ## 検査と射影の規則 -/

/-- 検査の δ。動的なパターンと、型検査器が具体化した範囲 r の両方への所属を確かめる
（L00.03 の `checkPathDelta` を種類 k へ一般化し、保持する文字列を加えた形）。 -/
def checkRun (P : Parsers) (k : Kind) : List Range → List CVal → Option CVal
  | [r], [.str ps, .str raw] =>
      some <| match P.pat ps, P.target raw with
        | some q, some t => if t.kind = k ∧ q.Mem t ∧ r.Mem t then .ok (.checked ps raw t) else .err .unit
        | _, _ => .err .unit
  | _, _ => none

/-- 型検査器がパターンの引数から得る範囲。リテラル（と `const` の直接参照。モデルではリテラルに含める）と、
同じ成功値の直接の射影だけを既知にする。局所の束縛を経た値は、射影の事実を持っていても既知にしない
（判断 7 の「局所 bind の一般的な定数伝播を加えない」）。 -/
def patternBound (P : Parsers) : AbsArg → Bound
  | .lit s => match P.pat s with
    | some r => .known r
    | none => .unknown
  | .value (.pattern r) => .known r
  | _ => .unknown

/-- 既知の範囲は、パターンの引数の値がその範囲に解析されることを意味する。 -/
theorem patternBound_sound {P : Parsers} {pa : AbsArg} {ps : String} (h : pa.Models (models P) (.str ps)) :
    ∀ r, patternBound P pa = .known r → P.pat ps = some r := by
  intro r hb
  cases pa with
  | lit s =>
    simp only [AbsArg.Models, models_lit, CVal.str.injEq] at h
    subst h
    simp only [patternBound] at hb
    split at hb
    · next r' hr => cases hb; exact hr
    · cases hb
  | value f =>
    cases f with
    | pattern r' =>
      simp only [patternBound] at hb
      cases hb
      obtain ⟨s, hs, hp⟩ := h 0
      cases hs
      exact hp
    | _ => simp [patternBound] at hb
  | _ => simp [patternBound] at hb

def checkIndex (P : Parsers) : List AbsArg → List Range
  | [pa, _] => [(patternBound P pa).index]
  | _ => [.top]

def checkTransfer (P : Parsers) (k : Kind) (key : Key) : List AbsArg → Option ScopeFact
  | [pa, _] => some (.result ⟨key, k, patternBound P pa⟩)
  | _ => none

def checkRule (P : Parsers) (k : Kind) : ScopeRule CVal where
  index := checkIndex P
  run := checkRun P k
  transfer := checkTransfer P k

/-- 検査の δ が値を返すのは、具体化が一つの範囲で、引数が二つの文字列のときだけである。 -/
theorem checkRun_some {P : Parsers} {k : Kind} {rs : List Range} {vs : List CVal} {v : CVal}
    (h : checkRun P k rs vs = some v) :
    ∃ r ps raw, rs = [r] ∧ vs = [.str ps, .str raw] ∧
      v = (match P.pat ps, P.target raw with
        | some q, some t => if t.kind = k ∧ q.Mem t ∧ r.Mem t then .ok (.checked ps raw t) else .err .unit
        | _, _ => .err .unit) := by
  unfold checkRun at h
  split at h
  · exact ⟨_, _, _, rfl, rfl, (Option.some.inj h).symm⟩
  · cases h

theorem checkRule_sound (P : Parsers) (k : Kind) : RuleSound (models P) (checkRule P k) := by
  intro key aargs rs vs v f hargs hrun htr id
  match aargs, htr with
  | [pa, ta], htr =>
    simp only [checkRule, checkTransfer, Option.some.injEq] at htr
    subst htr
    obtain ⟨r, ps, raw, rfl, rfl, rfl⟩ := checkRun_some (P := P) (k := k) hrun
    cases hargs with
    | cons h1 _ =>
      cases hq : P.pat ps with
      | none => exact trivial
      | some q =>
        cases ht : P.target raw with
        | none => exact trivial
        | some t =>
          try simp only []
          by_cases hc : t.kind = k ∧ q.Mem t ∧ r.Mem t
          · rw [ite_eq_left hc]
            refine ⟨ht, hc.1, ⟨q, hq, hc.2.1⟩, ?_, patternBound_sound h1⟩
            cases hb : patternBound P pa with
            | known r' =>
              have := patternBound_sound h1 r' hb
              rw [hq] at this
              cases this
              exact hc.2.1
            | unknown => exact trivial
          · rw [ite_eq_right hc]; exact trivial

/-- 型検査器がコアへ渡す具体化の範囲は、抽象の結果の由来が持つ添字と同じである（同じ R を渡す）。 -/
theorem checkRule_index_agrees {P : Parsers} {k : Kind} {key : Key} {aargs : List AbsArg} {o : Origin}
    (h : checkTransfer P k key aargs = some (.result o)) : checkIndex P aargs = [o.bound.index] := by
  match aargs, h with
  | [pa, _], h =>
    simp only [checkTransfer, Option.some.injEq, ScopeFact.result.injEq] at h
    subst h
    rfl

/-- 条件の射影の δ（`Scope.pathPattern(old)` に当たる例。名前は未決）。保持した同じパターンの文字列を返す。 -/
def patternRun : List Range → List CVal → Option CVal
  | _, [.checked ps _ _] => some (.str ps)
  | _, _ => none

/-- 同じ成功値の直接の射影だけを認定する。読んだ位置の束縛番号と事実の成功値番号を再照合する。 -/
def patternTransfer (_key : Key) : List AbsArg → Option ScopeFact
  | [.loc id (some (.checked o sid))] =>
      if sid = id then
        match o.bound with
        | .known r => some (.pattern r)
        | .unknown => none
      else none
  | _ => none

def patternRule : ScopeRule CVal where
  index _ := []
  run := patternRun
  transfer := patternTransfer

theorem patternRule_sound (P : Parsers) : RuleSound (models P) patternRule := by
  intro key aargs rs vs v f hargs hrun htr id
  match aargs, htr with
  | [.loc i (some (.checked o sid))], htr =>
    simp only [patternRule, patternTransfer] at htr
    split at htr
    · next hsid =>
      cases hb : o.bound with
      | unknown => simp [hb] at htr
      | known r =>
        simp only [hb, Option.some.injEq] at htr
        subst htr
        cases hargs with
        | cons h1 hargs =>
          cases hargs
          rename_i w
          obtain ⟨-, hw⟩ := h1
          match w, hw, hrun with
          | .checked ps raw t, hw, hrun =>
            simp only [patternRule, patternRun, Option.some.injEq] at hrun
            subst hrun
            exact ⟨ps, rfl, hw.2.2.2.2 r hb⟩
    · simp at htr

/-- 対象の射影の δ（`Scope.pathInValue` の候補）。普通の文字列を返し、事実を作らない。 -/
def valueRule : ScopeRule CVal where
  index _ := []
  run
    | _, [.checked _ raw _] => some (.str raw)
    | _, _ => none
  transfer _ _ := none

theorem valueRule_sound (P : Parsers) : RuleSound (models P) valueRule := by
  intro key aargs rs vs v f _ _ htr
  simp [valueRule] at htr

/-! ## 局所の状態と一段の評価 -/

/-- 具体の局所の値（`Interval.ConcreteEnv.locals` と同じ形）。 -/
abbrev Locals := List (Option CVal)

/-- 呼び出しの引数の式。リテラル、局所の読み取り、局所に対する直接の一引数の標準の呼び出し（射影）。 -/
inductive Arg where
  | lit (s : String)
  | loc (index : Nat)
  | proj (key : Key) (index : Nat)
  deriving DecidableEq, Repr

def absArg (T : ScopeTable CVal) (st : ScopeState) : Arg → AbsArg
  | .lit s => .lit s
  | .loc i => st.readLocal i
  | .proj key i =>
      match absApply T key [st.readLocal i] with
      | some f => .value f
      | none => .unknown

inductive EvalArg (T : ScopeTable CVal) (env : Locals) : Arg → CVal → Prop where
  | lit (s : String) : EvalArg T env (.lit s) (.str s)
  | loc (i : Nat) (v : CVal) (found : env[i]? = some (some v)) : EvalArg T env (.loc i) v
  | proj (key : Key) (i : Nat) (rs : List Range) (w v : CVal) (found : env[i]? = some (some w))
      (eval : EvalScope T key rs [w] v) : EvalArg T env (.proj key i) v

inductive EvalArgs (T : ScopeTable CVal) (env : Locals) : List Arg → List CVal → Prop where
  | nil : EvalArgs T env [] []
  | cons {a as v vs} : EvalArg T env a v → EvalArgs T env as vs → EvalArgs T env (a :: as) (v :: vs)

/-- 文の一段。`call` は標準の直接呼び出しの結果を新しい位置へ一度だけ保存する。`okArm i` は位置 i の
Result の `Ok` の腕で成功値を新しい位置へ束縛する。`alias i` は別名、`unknown` は未知の呼び出し・再包装・
リテラルの束縛、`join` は合流と本体の境界。 -/
inductive Step where
  | call (key : Key) (args : List Arg)
  | okArm (index : Nat)
  | alias (index : Nat)
  | unknown
  | join
  deriving DecidableEq, Repr

/-- 具体の一段。同定されない呼び出しと未知の値は任意の値を返してよい。 -/
inductive StepEval (T : ScopeTable CVal) : Locals → Step → Locals → Prop where
  | callStd {env key args vs rs v} : EvalArgs T env args vs → EvalScope T key rs vs v →
      StepEval T env (.call key args) (some v :: env)
  | callOther {env key args v} : T.ruleAt key = none → StepEval T env (.call key args) (some v :: env)
  | okArm {env i w} : env[i]? = some (some (.ok w)) → StepEval T env (.okArm i) (some w :: env)
  | alias {env i w} : env[i]? = some (some w) → StepEval T env (.alias i) (some w :: env)
  | unknown {env v} : StepEval T env .unknown (v :: env)
  | join {env} : StepEval T env .join env

/-- 抽象の一段。成功値の事実を作るのは `okArm` だけで、読む Result の事実の由来を写し、新しい位置の
束縛番号を成功値番号にする。 -/
def absStep (T : ScopeTable CVal) (st : ScopeState) : Step → ScopeState
  | .call key args => st.extend (absApply T key (args.map (absArg T st)))
  | .okArm i =>
      st.extend <| match st.facts[i]? with
        | some (some (.result o)) => some (.checked o st.scope.nextId)
        | _ => none
  | .alias _ => st.extend none
  | .unknown => st.extend none
  | .join => st.forgetAll

theorem absArgs_models {P : Parsers} {T : ScopeTable CVal} (hT : TableSound (models P) T) {st : ScopeState}
    {env : Locals} (hm : st.Models (models P) env) {args : List Arg} {vs : List CVal} (hev : EvalArgs T env args vs) :
    ArgsModel (models P) (args.map (absArg T st)) vs := by
  induction hev with
  | nil => exact .nil
  | cons ha _ ih =>
    refine .cons ?_ ih
    cases ha with
    | lit s => rfl
    | loc i v found => exact ScopeState.readLocal_models hm found
    | proj key i rs w v found eval =>
      simp only [absArg]
      cases hf : absApply T key [st.readLocal i] with
      | none => exact trivial
      | some f =>
        exact apply_sound hT (.cons (ScopeState.readLocal_models hm found) .nil) eval hf

/-- 一段の健全性（モデル）。表が健全で、状態が具体の局所に対応すれば、一段の後も対応する。 -/
theorem step_sound {P : Parsers} {T : ScopeTable CVal} (hT : TableSound (models P) T) {st : ScopeState}
    {env env' : Locals} {s : Step} (hm : st.Models (models P) env) (hev : StepEval T env s env') :
    (absStep T st s).Models (models P) env' := by
  cases hev with
  | callStd hargs heval =>
    refine ScopeState.extend_models hm (fun f hf => ⟨_, rfl, ?_⟩)
    exact apply_sound hT (absArgs_models hT hm hargs) heval hf _
  | callOther hmissing =>
    refine ScopeState.extend_models hm (fun f hf => ?_)
    simp [absApply, hmissing] at hf
  | okArm found =>
    rename_i i w
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
          rw [found] at hval; cases hval
          exact ⟨w, rfl, rfl, hmod⟩
        | _ => simp [hfi] at hf
  | alias _ => exact ScopeState.extend_models hm (fun f hf => by cases hf)
  | unknown => exact ScopeState.extend_models hm (fun f hf => by cases hf)
  | join => exact ScopeState.forgetAll_models (models P) st _

inductive StepsEval (T : ScopeTable CVal) : Locals → List Step → Locals → Prop where
  | nil {env} : StepsEval T env [] env
  | cons {env env' env'' s ss} : StepEval T env s env' → StepsEval T env' ss env'' →
      StepsEval T env (s :: ss) env''

def absSteps (T : ScopeTable CVal) (st : ScopeState) : List Step → ScopeState
  | [] => st
  | s :: ss => absSteps T (absStep T st s) ss

theorem steps_sound {P : Parsers} {T : ScopeTable CVal} (hT : TableSound (models P) T) {ss : List Step} :
    ∀ {st : ScopeState} {env env' : Locals}, st.Models (models P) env → StepsEval T env ss env' →
      (absSteps T st ss).Models (models P) env' := by
  induction ss with
  | nil => intro st env env' hm hev; cases hev; exact hm
  | cons s ss ih =>
    intro st env env' hm hev
    cases hev with
    | cons h1 h2 => exact ih (step_sound hT hm h1) h2

/-! ## 必須の判定と同じ値の対応 -/

/-- 必須の判定が Top でない添字を付けた位置の値は、その添字の範囲に属する対象を保持する（採用定義の
`requiredIndex_fact` とモデルの対応から）。 -/
theorem requiredIndex_sound {P : Parsers} {st : ScopeState} {env : Locals} (hm : st.Models (models P) env)
    {index : Nat} {v : CVal} (found : env[index]? = some (some v)) (hne : st.requiredIndex index ≠ .top) :
    ∃ ps raw t, v = .checked ps raw t ∧ (st.requiredIndex index).Mem t := by
  obtain ⟨o, id, hidx, hmod⟩ := st.requiredIndex_fact hm found hne
  rw [hidx]
  obtain ⟨-, hc⟩ := hmod
  match v, hc with
  | .checked ps raw t, hc => exact ⟨ps, raw, t, rfl, hc.2.2.2.1⟩

/-- L00.03 のモデルの値への写し。範囲付きの値は保持した対象を持つ。 -/
def CVal.toSig : CVal → SignatureExamples.Val
  | .str s => .str s
  | .checked _ _ t => .checked t
  | .ok v => .ok v.toSig
  | .err v => .err v.toSig
  | .unit => .unit

/-- 同じ値の対応: 成功値の事実が持つ添字は、L00.03 の値の型付け（所属の不変条件）でその値に付く。 -/
theorem checked_hasTypeV {P : Parsers} {o : Origin} {v : CVal} {K : String → Option Kind} {name : String}
    (hk : K name = some o.kind) (h : checkedModels P o v) :
    SignatureExamples.HasTypeV K v.toSig (.opaque name (.fixed o.bound.index)) := by
  match v, h with
  | .checked ps raw t, h =>
    simp only [CVal.toSig, SignatureExamples.HasTypeV]
    exact ⟨by rw [hk, h.2.1], h.2.2.2.1⟩

/-- Range の事実と Scope の事実を同じ束縛番号の上の別の成分に置く採用定義の局所の状態を、区間解析の局所の
事実で具体化する。 -/
abbrev RangedLocalState := LocalState Interval.RangeLocalFact

def RangedLocalState.toRange (s : RangedLocalState) : Interval.RangeState := ⟨s.scope, s.range⟩

/-- 必須の判定は Range の成分を読まない（採用定義の補題の具体化）。 -/
theorem requiredIndex_range_independent (s : RangedLocalState) (r : List (Option Interval.RangeLocalFact))
    (index : Nat) :
    ({ s with range := r }).toScope.requiredIndex index = s.toScope.requiredIndex index :=
  LocalState.requiredIndex_range_independent s r index

/-- 二つの成分は同じ束縛番号を読む（別の番号付けを作らない）。 -/
theorem localState_same_scope (s : RangedLocalState) : s.toScope.scope = s.toRange.scope := rfl

/-! ## L00.03 の申し送り: 検査の δ の二重の確かめ -/

/-- 既知のリテラルのパターンでは、具体化した範囲の確かめは結果を変えない（冗長）。 -/
theorem checkRun_known_redundant (P : Parsers) (k : Kind) {ps raw : String} {r : Range}
    (hp : P.pat ps = some r) :
    checkRun P k [r] [.str ps, .str raw] = checkRun P k [.top] [.str ps, .str raw] := by
  simp only [checkRun, hp]
  cases ht : P.target raw with
  | none => rfl
  | some t =>
    by_cases hc : t.kind = k ∧ r.Mem t
    · simp [hc]
    · have hc' : ¬ (t.kind = k ∧ r.Mem t ∧ r.Mem t) := fun h => hc ⟨h.1, h.2.1⟩
      have hc'' : ¬ (t.kind = k ∧ r.Mem t ∧ Range.top.Mem t) := fun h => hc ⟨h.1, h.2.1⟩
      simp only [ite_eq_right hc', ite_eq_right hc'']

/-- 型の添字への所属は δ の確かめから従い、局所解析の正しさを使わない。 -/
theorem checkRun_ok_mem (P : Parsers) (k : Kind) {R : Range} {vs : List CVal} {w : CVal}
    (h : checkRun P k [R] vs = some (.ok w)) : ∃ ps raw t, w = .checked ps raw t ∧ R.Mem t ∧ t.kind = k := by
  match vs, h with
  | [.str ps, .str raw], h =>
    simp only [checkRun, Option.some.injEq] at h
    split at h
    · next q t _ _ =>
      split at h
      · next hc => cases h; exact ⟨ps, raw, t, rfl, hc.2.2, hc.1⟩
      · cases h
    · cases h

/-- L00.03 の `checkPathDelta` でも、既知のパターンでは具体化した範囲の確かめが冗長である。 -/
theorem checkPathDelta_known_redundant (parsePat : String → Option Range)
    (parseTarget : String → Option Target) {pat raw : String} {r : Range} (hp : parsePat pat = some r) :
    SignatureExamples.checkPathDelta parsePat parseTarget [r] [.str pat, .str raw] =
      SignatureExamples.checkPathDelta parsePat parseTarget [.top] [.str pat, .str raw] := by
  simp only [SignatureExamples.checkPathDelta, hp]
  cases ht : parseTarget raw with
  | none => rfl
  | some t =>
    by_cases hc : t.kind = .path ∧ r.Mem t
    · simp [hc]
    · have hc' : ¬ (t.kind = .path ∧ r.Mem t ∧ r.Mem t) := fun h => hc ⟨h.1, h.2.1⟩
      have hc'' : ¬ (t.kind = .path ∧ r.Mem t ∧ Range.top.Mem t) := fun h => hc ⟨h.1, h.2.1⟩
      simp only [ite_eq_right hc', ite_eq_right hc'']

/-! ## 小例 -/

def dataTree : Range := .path (.tree ["data"])

/-- 例の解析器。`/data/**` だけを解析し、`/data/a.txt` と `/etc/x` を対象として解析する。 -/
def toyParsers : Parsers where
  pat
    | "/data/**" => some dataTree
    | _ => none
  target
    | "/data/a.txt" => some (.path ["data", "a.txt"])
    | "/etc/x" => some (.path ["etc", "x"])
    | _ => none

def keyCheck : Key := ⟨"main.store", 3⟩
def keyCheck2 : Key := ⟨"main.store", 9⟩
def keyPattern : Key := ⟨"main.store", 7⟩
def keyValue : Key := ⟨"main.store", 8⟩
def keyUser : Key := ⟨"main.store", 11⟩

/-- 出現の同定。`keyUser` は同じ綴りの利用者の関数の出現であり、標準の宣言に解決しない。 -/
def toyTable : ScopeTable CVal where
  apiAt key :=
    if key = keyCheck ∨ key = keyCheck2 then some "Scope.checkPathIn"
    else if key = keyPattern then some "Scope.pathPattern"
    else if key = keyValue then some "Scope.pathInValue"
    else none
  rules
    | "Scope.checkPathIn" => some (checkRule toyParsers .path)
    | "Scope.pathPattern" => some patternRule
    | "Scope.pathInValue" => some valueRule
    | _ => none

theorem toyTable_sound : TableSound (models toyParsers) toyTable := by
  intro d rule h
  simp only [toyTable] at h
  split at h
  · cases h; exact checkRule_sound _ _
  · cases h; exact patternRule_sound _
  · cases h; exact valueRule_sound _
  · cases h

/-- 関数の入口。引数 `raw` の一つの位置（番号 0）だけを持ち、由来はない。 -/
def entry : ScopeState := ScopeState.empty ⟨[0], 1⟩

/-- 最小例: 直接の検査 → 一度の保存 → 同じ `Ok` 値 → 射影。
`let r = Scope.checkPathIn(pattern: "/data/**", path: raw)`（位置 0 が raw）、
`case Result.Ok(p)`、`Scope.checkPathIn(pattern: Scope.pathPattern(p), path: Scope.pathInValue(p))` を
保存し、その `Ok` の腕を読む。 -/
def minimalSteps : List Step :=
  [ .call keyCheck [.lit "/data/**", .loc 0],
    .okArm 0,
    .call keyCheck2 [.proj keyPattern 0, .proj keyValue 0],
    .okArm 0 ]

-- 直接の検査の結果は既知の範囲の由来を持つ。
#guard (absSteps toyTable entry (minimalSteps.take 1)).facts[0]? ==
  some (some (.result ⟨keyCheck, .path, .known dataTree⟩))
-- 同じ Ok 値（番号 2）は同じ由来を持ち、必須の判定は `/data/**` の添字を付ける。
#guard (absSteps toyTable entry (minimalSteps.take 2)).facts[0]? ==
  some (some (.checked ⟨keyCheck, .path, .known dataTree⟩ 2))
#guard (absSteps toyTable entry (minimalSteps.take 2)).requiredIndex 0 == dataTree
-- 直接の射影で得た条件を渡した再検査も既知の範囲になる（新しい検査は残る）。
#guard (absSteps toyTable entry minimalSteps).requiredIndex 0 == dataTree
#guard (absSteps toyTable entry minimalSteps).facts[0]? ==
  some (some (.checked ⟨keyCheck2, .path, .known dataTree⟩ 4))
-- 元の引数 raw（番号 0）は Top のまま。
#guard (absSteps toyTable entry minimalSteps).requiredIndex 4 == .top

/-- 最小例の健全性: 入口から最小例の具体の評価で得た局所は、抽象の結果に対応する。 -/
theorem minimal_sound {env env' : Locals} (hev : StepsEval toyTable env minimalSteps env') :
    (absSteps toyTable entry minimalSteps).Models (models toyParsers) env' :=
  steps_sound toyTable_sound (ScopeState.empty_models _ _ _) hev

/-- 最小例の位置 0 の値は `/data/**` の対象を保持する（同じ値と条件の対応）。 -/
theorem minimal_checked {env env' : Locals} {v : CVal} (hev : StepsEval toyTable env minimalSteps env')
    (found : env'[0]? = some (some v)) : ∃ ps raw t, v = .checked ps raw t ∧ dataTree.Mem t := by
  have h := requiredIndex_sound (minimal_sound hev) found (by decide)
  have hidx : (absSteps toyTable entry minimalSteps).requiredIndex 0 = dataTree := by decide
  rw [hidx] at h
  exact h

/-! ## 精度を失う境界の小例 -/

-- 未知のパターン（局所の文字列）では Top。検査の δ は動的なパターンだけを実質に確かめる。
#guard (absSteps toyTable entry [.call keyCheck [.loc 0, .loc 0], .okArm 0]).requiredIndex 0 == .top
-- 射影の結果を局所に保存してから渡すと既知にしない（局所の束縛の定数伝播をしない）。
#guard (absSteps toyTable entry
  [.call keyCheck [.lit "/data/**", .loc 0], .okArm 0, .call keyPattern [.loc 0],
   .call keyCheck2 [.loc 0, .loc 3], .okArm 0]).requiredIndex 0 == .top
-- 別名は由来を写さない。
#guard (absSteps toyTable entry [.call keyCheck [.lit "/data/**", .loc 0], .okArm 0, .alias 0]).requiredIndex 0
  == .top
-- 再包装（未知の値）の Ok 腕は別個体であり、由来を持たない。
#guard (absSteps toyTable entry [.call keyCheck [.lit "/data/**", .loc 0], .okArm 0, .unknown, .okArm 0]).requiredIndex 0
  == .top
-- 合流と本体の境界で忘れる。
#guard (absSteps toyTable entry [.call keyCheck [.lit "/data/**", .loc 0], .okArm 0, .join]).requiredIndex 0
  == .top
-- 同じ綴りの利用者の関数（同定されない出現）は由来を作らない。
#guard (absSteps toyTable entry [.call keyUser [.lit "/data/**", .loc 0], .okArm 0]).requiredIndex 0 == .top
-- 成功値番号と読んだ位置の番号が食い違う事実は使わない（再照合）。
#guard ScopeState.requiredIndex ⟨⟨[5], 6⟩, [some (.checked ⟨keyCheck, .path, .known dataTree⟩ 4)]⟩ 0 == .top
-- Result そのもの（Ok の腕の前）には添字を付けない。
#guard (absSteps toyTable entry [.call keyCheck [.lit "/data/**", .loc 0]]).requiredIndex 0 == .top

end Benitoite.Scope.InferenceExamples
