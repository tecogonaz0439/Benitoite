import Benitoite.Scope.Inference
import Benitoite.Scope.RangeCover
import Benitoite.Interval.Budget
import Benitoite.Release.Lemmas.Membership

/-!
# Scope の局所解析の状態・規則の表・予算と忘却

採用定義 `Scope.Inference`（規則の表と一つの評価関係、抽象値、局所状態）を、本番の値 `Release.Val`、
`Scope.Domain` の範囲と対象、範囲の被覆（`Scope/RangeCover.lean`）で具体化する
（設計書 01-12「Scope の局所解析の状態と規則の表」「Scope の局所解析の予算と忘却」）。

- 事実と値の対応: 成功値は対象を保持する値（検査済みの対象の値 `Val.checked t` か検査済みの要求の値
  `Val.checkedRequest t req`。`Val.target?` が対象を返す値）であり、対象の種類が由来の種類に合い、対象が由来の
  添字の範囲に属する（`CheckedModels`）。`Result.Ok` の値は構成子の名前で読む（`okPayload`）。
- 規則の表: 検査（`Scope.checkPathIn`・`Http.checkRequestIn`）、射影（`Scope.pathInValue`・
  `Http.requestInValue`）、拡大（`Scope.widenPathIn`・`Http.widenRequestIn`）の項目と、それぞれの `RuleSound`。
  出現の同定 `apiAt` は標準の所有元に解決した宣言だけを返す（`standardTable`）。
- 一段: 標準の直接呼び出しの一度の保存（`call`）、`Ok` の腕（`okArm`）、別名（`alias`）、未知（`unknown`）、
  合流と本体の境界（`join`）。表層の構文からの対応は `Surface.ScopeLower` で定める。
- リテラル: 文字列はそのまま、整数は先頭に U+0000 を置いた綴り（`intLitText`）で抽象の引数 `AbsArg.lit` に載せ、
  `Http.checkRequestIn` のポートをリテラルから読む（`requestLitBound`）。
- 予算: 必須の判定の予算は区間解析の警告の予算と別の状態に持つ。上限の値は引数であり、既定値を持たない。
  超過したら全ての由来を忘れて Top を返し、超過の理由に本体か全体か、操作数か保持数かを残す。

文字列のパターン・対象の解析、要求から実効の host・port を得る処理、範囲付きの値から文字列・要求を戻す処理は
形式化の外側であり、任意の関数として引数に取る。`Interval.RangeState` は変えず、import もしない。
-/

namespace Benitoite.Surface.ScopeState

open Benitoite.Scope.Inference
open Benitoite.Scope.Domain (Range Target Kind)

/-! ## 本番の値と事実の対応 -/

/-- 局所の具体の値（区間解析の `ConcreteEnv.locals` と同じ形）。 -/
abbrev Locals := List (Option Release.Val)

/-- `Result.Ok` の値から成功値を取り出す。`ok` は Ok の構成子の名前（標準の Result の宣言が与える）。 -/
def okPayload (ok : Release.ConName) : Release.Val → Option Release.Val
  | .con c _ [w] => if c = ok then some w else none
  | _ => none

/-- 由来と成功値の対応。成功値は対象を保持する値（`Val.target?` が対象を返す値。検査済みの対象の値と、
`Http.checkRequestIn` が返す検査済みの要求の値）で、対象の種類が由来の種類に合い、対象が由来の添字の範囲に属する。
未知の由来の添字は Top なので、所属は種類だけの条件になる。 -/
def CheckedModels (o : Origin) (v : Release.Val) : Prop :=
  match v.target? with
  | some t => t.kind = o.kind ∧ o.bound.index.Mem t
  | none => False

theorem checkedModels_iff {o : Origin} {v : Release.Val} :
    CheckedModels o v ↔ ∃ t, v.target? = some t ∧ t.kind = o.kind ∧ o.bound.index.Mem t := by
  unfold CheckedModels
  cases v.target? with
  | none => simp
  | some t => simp

/-- 一度保存した検査の Result の対応。`Ok` の値なら、その成功値が同じ由来の成功値に対応する。`Err` は任意。 -/
def ResultModels (ok : Release.ConName) (o : Origin) (v : Release.Val) : Prop :=
  ∀ w, okPayload ok v = some w → CheckedModels o w

/-- パスのパターンと対象の文字列の解析（形式化の外側）。型検査器がリテラルを解析する関数と、実行時の検査が
使う関数は同じものとする。 -/
structure Parsers where
  pattern : String → Option Range
  target : String → Option Target

/-- 事実と、束縛番号 id の位置にある具体の値の対応。成功値の事実はその番号にだけ有効である。 -/
def factModel (ok : Release.ConName) (P : Parsers) : ScopeFact → Nat → Release.Val → Prop
  | .pattern r, _, v => ∃ s, v = .const (.string s) ∧ P.pattern s = some r
  | .result o, _, v => ResultModels ok o v
  | .checked o sid, id, v => sid = id ∧ CheckedModels o v

/-! ## リテラルの抽象の綴り

採用定義の抽象の引数 `AbsArg.lit` は文字列だけを持つ。整数のリテラル（`Http.checkRequestIn` のポートの両端）は、
先頭に文字 U+0000 を置いた十進の綴り `intLitText n` で表し、`litInt?` で読み戻す。先頭が U+0000 の綴りは整数の
リテラルだけに使い、同じ形の文字列のリテラルは抽象の引数で未知にする（`absArg`）。 -/

/-- 整数のリテラルの抽象の綴り。 -/
def intLitText (n : Release.Integer64Value) : String := String.ofList ('\u0000' :: n.toInt.repr.toList)

/-- 抽象の綴りが整数のリテラルなら、その整数。 -/
def litInt? (s : String) : Option Int :=
  match s.toList with
  | '\u0000' :: rest => (String.ofList rest).toInt?
  | _ => none

theorem litInt?_intLitText (n : Release.Integer64Value) : litInt? (intLitText n) = some n.toInt := by
  simp [litInt?, intLitText, String.ofList_toList, Int.toInt?_repr]

/-- リテラルの抽象の綴りと値の対応。整数の綴りは同じ整数の定数、それ以外は同じ文字列の定数である。 -/
def LitModels (s : String) (v : Release.Val) : Prop :=
  match litInt? s with
  | some i => ∃ n : Release.Integer64Value, v = .const (.integer n) ∧ n.toInt = i
  | none => v = .const (.string s)

theorem litModels_of_none {s : String} {v : Release.Val} (h : litInt? s = none) :
    LitModels s v ↔ v = .const (.string s) := by
  simp only [LitModels, h]

theorem litModels_intLitText (n : Release.Integer64Value) : LitModels (intLitText n) (.const (.integer n)) := by
  simp only [LitModels, litInt?_intLitText]
  exact ⟨n, rfl, rfl⟩

/-- 本番の値の対応。リテラルは同じ文字列または同じ整数の定数である（`LitModels`）。 -/
def models (ok : Release.ConName) (P : Parsers) : FactModels Release.Val :=
  ⟨LitModels, factModel ok P⟩

@[simp] theorem models_fact (ok : Release.ConName) (P : Parsers) : (models ok P).fact = factModel ok P := rfl

@[simp] theorem models_lit (ok : Release.ConName) (P : Parsers) (s : String) (v : Release.Val) :
    (models ok P).lit s v ↔ LitModels s v := Iff.rfl

/-- 対象を保持する値は、名前 name の種類と保持する要求の型（検査済みの要求の値のときだけ）が合えば、対象の属する
範囲付きの値型を持つ（規則 V-Checked・V-CheckedRequest）。 -/
theorem target_hasTypeV {P : Release.Program} {B : Release.Builtins} {Ψ : Release.StoreTy}
    {Q : Release.NoFailCtx} {C : List Release.TParam} {Γ : List (Option Release.Ty)} {v : Release.Val}
    {t : Target} {R : Range} {name : Release.OpaqueName} (ht : v.target? = some t)
    (hk : B.valKind name = some t.kind) (hm : R.Mem t)
    (hc : ∀ c, v = .checkedRequest t c → ∃ A, B.valContent name = some A ∧ Release.HasTypeVQ P B Ψ Release.Qempty [] [] c A) :
    Release.HasTypeVQ P B Ψ Q C Γ v (.opaque name (.fixed R)) := by
  cases v with
  | checked t' =>
    simp only [Release.Val.target?, Option.some.injEq] at ht
    subst ht
    exact .V_Checked hk hm
  | checkedRequest t' c =>
    simp only [Release.Val.target?, Option.some.injEq] at ht
    subst ht
    obtain ⟨n, hn, hct⟩ := hc c rfl
    exact .V_CheckedRequest hk hm hn hct
  | _ => simp [Release.Val.target?] at ht

/-- 成功値の事実に対応する値は、本番の値の型付けの規則 V-Checked（検査済みの要求の値なら V-CheckedRequest）で、
由来の添字の範囲付きの値型を持つ。 -/
theorem checkedModels_hasTypeV {P : Release.Program} {B : Release.Builtins} {Ψ : Release.StoreTy}
    {Q : Release.NoFailCtx} {C : List Release.TParam} {Γ : List (Option Release.Ty)} {o : Origin}
    {v : Release.Val} {name : Release.OpaqueName} (hk : B.valKind name = some o.kind) (h : CheckedModels o v)
    (hc : ∀ t c, v = .checkedRequest t c → ∃ A, B.valContent name = some A ∧ Release.HasTypeVQ P B Ψ Release.Qempty [] [] c A) :
    Release.HasTypeVQ P B Ψ Q C Γ v (.opaque name (.fixed o.bound.index)) := by
  obtain ⟨t, ht, hk', hm⟩ := checkedModels_iff.mp h
  exact target_hasTypeV ht (by rw [hk, hk']) hm (hc t)

/-! ## 必須の判定の添字 -/

/-- 抽象の引数に付ける添字。同じ成功値の事実で、読んだ位置の束縛番号と成功値番号が一致するとき（再照合）だけ
既知の範囲、それ以外は Top。 -/
def argIndex : AbsArg → Range
  | .loc id (some (.checked o sid)) => if sid = id then o.bound.index else .top
  | _ => .top

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

/-- Top でない添字を付けた引数の値は、その範囲に属する対象を保持する値である。 -/
theorem argIndex_sound {ok : Release.ConName} {P : Parsers} {a : AbsArg} {v : Release.Val}
    (h : a.Models (models ok P) v) (hne : argIndex a ≠ .top) :
    ∃ t, v.target? = some t ∧ (argIndex a).Mem t := by
  match a, h, hne with
  | .loc id (some (.checked o sid)), h, hne =>
    simp only [AbsArg.Models, models_fact, factModel] at h
    obtain ⟨rfl, hc⟩ := h
    obtain ⟨t, ht, -, hm⟩ := checkedModels_iff.mp hc
    exact ⟨t, ht, by simpa [argIndex] using hm⟩
  | .loc _ (some (.pattern _)), _, hne => simp [argIndex] at hne
  | .loc _ (some (.result _)), _, hne => simp [argIndex] at hne
  | .loc _ none, _, hne => simp [argIndex] at hne
  | .lit _, _, hne => simp [argIndex] at hne
  | .value _, _, hne => simp [argIndex] at hne
  | .unknown, _, hne => simp [argIndex] at hne

/-- 必須の判定が Top でない添字を付けた位置の値は、その添字の範囲に属する対象を保持する値である
（採用定義の `requiredIndex_fact` と本番の対応から）。 -/
theorem requiredIndex_checked {ok : Release.ConName} {P : Parsers} {st : ScopeState} {env : Locals}
    (hm : st.Models (models ok P) env) {i : Nat} {v : Release.Val} (found : env[i]? = some (some v))
    (hne : st.requiredIndex i ≠ .top) :
    ∃ (o : Origin) (t : Target), v.target? = some t ∧ t.kind = o.kind ∧ st.requiredIndex i = o.bound.index ∧
      (st.requiredIndex i).Mem t := by
  obtain ⟨o, id, hidx, hmod⟩ := st.requiredIndex_fact hm found hne
  simp only [models_fact, factModel] at hmod
  obtain ⟨-, hc⟩ := hmod
  obtain ⟨t, ht, hk, hm⟩ := checkedModels_iff.mp hc
  exact ⟨o, t, ht, hk, hidx, hidx ▸ hm⟩

/-- 必須の判定の添字は、本番の値の型付けでその位置の値に付く。 -/
theorem requiredIndex_hasTypeV {ok : Release.ConName} {P : Parsers} {st : ScopeState} {env : Locals}
    (hm : st.Models (models ok P) env) {i : Nat} {v : Release.Val} (found : env[i]? = some (some v))
    (hne : st.requiredIndex i ≠ .top) {Pr : Release.Program} {B : Release.Builtins} {Ψ : Release.StoreTy}
    {Q : Release.NoFailCtx} {C : List Release.TParam} {Γ : List (Option Release.Ty)} {name : Release.OpaqueName}
    (hk : ∀ t, v.target? = some t → B.valKind name = some t.kind)
    (hc : ∀ t c, v = .checkedRequest t c → ∃ A, B.valContent name = some A ∧ Release.HasTypeVQ Pr B Ψ Release.Qempty [] [] c A) :
    Release.HasTypeVQ Pr B Ψ Q C Γ v (.opaque name (.fixed (st.requiredIndex i))) := by
  obtain ⟨_, t, ht, -, -, hmem⟩ := requiredIndex_checked hm found hne
  exact target_hasTypeV ht (hk t ht) hmem (hc t)

/-! ## 検査の規則 -/

/-- 検査の項目の形。`pattern`・`target` は実行時の引数が表す動的なパターンの範囲と検査する対象（解析は
形式化の外側）、`bound` は型検査器が抽象の引数から得る既知の範囲または未知である。 -/
structure CheckSpec where
  kind : Kind
  pattern : List Release.Val → Option Range
  target : List Release.Val → Option Target
  bound : List AbsArg → Bound

/-- 型検査器の既知の範囲は、実行時の動的なパターンが同じ範囲に解析されることを意味する。 -/
def CheckSpec.BoundSound (M : FactModels Release.Val) (C : CheckSpec) : Prop :=
  ∀ aargs vs r, ArgsModel M aargs vs → C.bound aargs = .known r → C.pattern vs = some r

/-- 検査の δ の契約（案 A）。δ が `Ok` の値を返すなら、具体化はちょうど一つの範囲 r であり、成功値は検査した
対象を保持する値（`Val.target?` がその対象を返す。`Scope.checkPathIn` は検査済みの対象の値、`Http.checkRequestIn` は
渡された要求を保持する検査済みの要求の値）で、対象は種類を持ち、動的なパターンと r の両方に属する。 -/
def CheckSpec.Contract (ok : Release.ConName) (C : CheckSpec)
    (run : List Range → List Release.Val → Option Release.Val) : Prop :=
  ∀ rs vs v w, run rs vs = some v → okPayload ok v = some w →
    ∃ r q t, rs = [r] ∧ C.pattern vs = some q ∧ C.target vs = some t ∧ w.target? = some t ∧
      t.kind = C.kind ∧ q.Mem t ∧ r.Mem t

/-- 検査の規則。具体化の範囲は型検査器が得た範囲の添字（未知は Top）、抽象の結果は同じ由来の Result の事実。 -/
def checkRule (C : CheckSpec) (run : List Range → List Release.Val → Option Release.Val) :
    ScopeRule Release.Val where
  index aargs := [(C.bound aargs).index]
  run := run
  transfer key aargs := some (.result ⟨key, C.kind, C.bound aargs⟩)

/-- 検査の規則の健全性。どの具体化の範囲で実行しても、`Ok` の成功値は同じ由来の成功値に対応する。 -/
theorem checkRule_sound {ok : Release.ConName} {P : Parsers} {C : CheckSpec}
    {run : List Range → List Release.Val → Option Release.Val}
    (hb : C.BoundSound (models ok P)) (hc : C.Contract ok run) : RuleSound (models ok P) (checkRule C run) := by
  intro key aargs rs vs v f hargs hrun htr _
  simp only [checkRule, Option.some.injEq] at htr
  subst htr
  intro w hw
  obtain ⟨r, q, t, -, hq, -, ht, hk, hqm, -⟩ := hc rs vs v w hrun hw
  refine checkedModels_iff.mpr ⟨t, ht, hk, ?_⟩
  cases hbd : C.bound aargs with
  | known r' =>
    have hp := hb aargs vs r' hargs hbd
    rw [hq] at hp
    cases hp
    exact hqm
  | unknown => trivial

/-- 型検査器がコアへ渡す具体化の範囲は、抽象の結果の由来が持つ添字と同じである（同じ R を渡す）。 -/
theorem checkRule_index_agrees {C : CheckSpec} {run : List Range → List Release.Val → Option Release.Val}
    {key : Key} {aargs : List AbsArg} {o : Origin}
    (h : (checkRule C run).transfer key aargs = some (.result o)) :
    (checkRule C run).index aargs = [o.bound.index] := by
  simp only [checkRule, Option.some.injEq, ScopeFact.result.injEq] at h
  subst h
  rfl

/-- パスの検査の成功値。検査した対象 t を持つ検査済みの対象の値である。 -/
def checkedOk : List Release.Val → Target → Release.Val := fun _ t => .checked t

/-- 要求の検査の成功値。渡された要求（四番目の引数。`Http.ClientRequest` のレコードの値）をそのまま保持し、実効の
endpoint t を持つ検査済みの要求の値であり、Release の実例の表の δ（`Release.ModelHttp.checkRun`）の成功値と同じ形で
ある（`ScopeSound.modelHttp_checkRun_requestOk`、L40.3c）。引数が四つでないときは検査済みの対象の値を返すが、検査の
項目 `requestCheck` は四つの引数の要求だけを読むので、この腕は成功値にならない。 -/
def requestOk : List Release.Val → Target → Release.Val
  | [_, _, _, req], t => .checkedRequest t req
  | _, t => .checked t

theorem checkedOk_target (vs : List Release.Val) (t : Target) : (checkedOk vs t).target? = some t := rfl

theorem requestOk_target (vs : List Release.Val) (t : Target) : (requestOk vs t).target? = some t := by
  unfold requestOk
  split <;> rfl

/-- 検査の δ の具体の形（案 A）。動的なパターンと具体化した範囲 r の両方への所属を確かめる。`tys r` は具体化した
範囲での Result の型引数、`failure` は失敗の値、`okVal vs t` は対象 t の成功値（パスは `checkedOk`、要求は
`requestOk`）である。 -/
def checkDelta (ok err : Release.ConName) (tys : Range → List Release.Ty) (failure : Release.Val)
    (okVal : List Release.Val → Target → Release.Val)
    (C : CheckSpec) : List Range → List Release.Val → Option Release.Val
  | [r], vs => some <|
      match C.pattern vs, C.target vs with
      | some q, some t =>
          if t.kind = C.kind ∧ q.Mem t ∧ r.Mem t then .con ok (tys r) [okVal vs t]
          else .con err (tys r) [failure]
      | _, _ => .con err (tys r) [failure]
  | _, _ => none

private theorem okPayload_err {ok err : Release.ConName} (hne : ok ≠ err) (ts : List Release.Ty)
    (x : Release.Val) : okPayload ok (.con err ts [x]) = none := by
  simp only [okPayload]
  exact ite_eq_right (fun h => hne h.symm)

/-- 具体の δ は契約を満たす（Ok と Err の構成子の名前が違い、成功値が対象を保持するとき）。 -/
theorem checkDelta_contract {ok err : Release.ConName} (hne : ok ≠ err) (tys : Range → List Release.Ty)
    (failure : Release.Val) {okVal : List Release.Val → Target → Release.Val}
    (hok : ∀ vs t, (okVal vs t).target? = some t) (C : CheckSpec) :
    C.Contract ok (checkDelta ok err tys failure okVal C) := by
  intro rs vs v w hrun hw
  match rs, hrun with
  | [r], hrun =>
    simp only [checkDelta, Option.some.injEq] at hrun
    subst hrun
    cases hq : C.pattern vs with
    | none => simp only [hq, okPayload_err hne] at hw; cases hw
    | some q =>
      cases ht : C.target vs with
      | none => simp only [hq, ht, okPayload_err hne] at hw; cases hw
      | some t =>
        simp only [hq, ht] at hw
        by_cases hcond : t.kind = C.kind ∧ q.Mem t ∧ r.Mem t
        · rw [ite_eq_left hcond] at hw
          simp only [okPayload, ite_true, Option.some.injEq] at hw
          subst hw
          exact ⟨r, q, t, rfl, rfl, rfl, hok vs t, hcond.1, hcond.2.1, hcond.2.2⟩
        · rw [ite_eq_right hcond, okPayload_err hne] at hw
          cases hw

/-- 型の添字への所属は δ の確かめだけから従い、局所解析の正しさを使わない（案 A）。 -/
theorem checkDelta_ok_mem {ok err : Release.ConName} (hne : ok ≠ err) {tys : Range → List Release.Ty}
    {failure : Release.Val} {okVal : List Release.Val → Target → Release.Val} {C : CheckSpec} {R : Range}
    {vs : List Release.Val} {v w : Release.Val}
    (hrun : checkDelta ok err tys failure okVal C [R] vs = some v) (hw : okPayload ok v = some w) :
    ∃ t, w = okVal vs t ∧ t.kind = C.kind ∧ R.Mem t := by
  simp only [checkDelta, Option.some.injEq] at hrun
  subst hrun
  cases hq : C.pattern vs with
  | none => simp only [hq, okPayload_err hne] at hw; cases hw
  | some q =>
    cases ht : C.target vs with
    | none => simp only [hq, ht, okPayload_err hne] at hw; cases hw
    | some t =>
      simp only [hq, ht] at hw
      by_cases hcond : t.kind = C.kind ∧ q.Mem t ∧ R.Mem t
      · rw [ite_eq_left hcond] at hw
        simp only [okPayload, ite_true, Option.some.injEq] at hw
        exact ⟨t, hw.symm, hcond.1, hcond.2.2⟩
      · rw [ite_eq_right hcond, okPayload_err hne] at hw
        cases hw

/-- 動的なパターンが既知の範囲 r に解析されるなら、r での確かめは Top での確かめと同じ成否と成功値を与える
（局所解析が正しいとき、R の確かめは冗長で振る舞いを変えない）。 -/
theorem checkDelta_known_redundant (ok err : Release.ConName) (tys : Range → List Release.Ty)
    (failure : Release.Val) (okVal : List Release.Val → Target → Release.Val) (C : CheckSpec)
    {vs : List Release.Val} {r : Range} (hp : C.pattern vs = some r) :
    (checkDelta ok err tys failure okVal C [r] vs).map (okPayload ok) =
      (checkDelta ok err tys failure okVal C [.top] vs).map (okPayload ok) := by
  simp only [checkDelta, hp, Option.map_some, Option.some.injEq]
  cases ht : C.target vs with
  | none => simp [okPayload]
  | some t =>
    simp only []
    by_cases hc : t.kind = C.kind ∧ r.Mem t
    · have h1 : t.kind = C.kind ∧ r.Mem t ∧ r.Mem t := ⟨hc.1, hc.2, hc.2⟩
      have h2 : t.kind = C.kind ∧ r.Mem t ∧ Range.top.Mem t := ⟨hc.1, hc.2, trivial⟩
      rw [ite_eq_left h1, ite_eq_left h2]
      simp [okPayload]
    · have h1 : ¬ (t.kind = C.kind ∧ r.Mem t ∧ r.Mem t) := fun h => hc ⟨h.1, h.2.1⟩
      have h2 : ¬ (t.kind = C.kind ∧ r.Mem t ∧ Range.top.Mem t) := fun h => hc ⟨h.1, h.2.1⟩
      rw [ite_eq_right h1, ite_eq_right h2]
      simp [okPayload]

/-- `Scope.checkPathIn(pattern, path)` の検査。型検査器は文字列のリテラルのパターンだけを既知にする（`const` の直接
参照は表層からの対応がリテラルへ写す。`Surface.ScopeLower`）。局所の束縛を経た値は、射影の事実を持っていても既知に
しない（判断 7）。 -/
def pathCheck (P : Parsers) : CheckSpec where
  kind := .path
  pattern
    | .const (.string ps) :: _ => P.pattern ps
    | _ => none
  target
    | [_, .const (.string raw)] => P.target raw
    | _ => none
  bound
    | .lit s :: _ =>
      match litInt? s with
      | some _ => .unknown
      | none =>
        match P.pattern s with
        | some r => .known r
        | none => .unknown
    | _ => .unknown

theorem pathCheck_boundSound (ok : Release.ConName) (P : Parsers) : (pathCheck P).BoundSound (models ok P) := by
  intro aargs vs r hargs hb
  match aargs, hargs, hb with
  | .lit s :: _, .cons h1 _, hb =>
    simp only [AbsArg.Models, models_lit] at h1
    cases hs : litInt? s with
    | some _ => simp [pathCheck, hs] at hb
    | none =>
      rw [litModels_of_none hs] at h1
      subst h1
      simp only [pathCheck, hs] at hb ⊢
      split at hb
      · next r' hr => cases hb; exact hr
      · cases hb
  | .loc _ _ :: _, _, hb => simp [pathCheck] at hb
  | .value _ :: _, _, hb => simp [pathCheck] at hb
  | .unknown :: _, _, hb => simp [pathCheck] at hb
  | [], _, hb => simp [pathCheck] at hb

/-- `Http.checkRequestIn(hostPattern, minimumPort, maximumPort, request)` の検査。ホストのパターンの文字列の解析と、
要求から実効の endpoint を得る処理は形式化の外側である。ポートは `Port.ofInt?` が内側の境界である。型検査器が
抽象の引数から得る範囲 `bound` は引数に取り、その健全性（`BoundSound`）を項目の条件にする。 -/
def requestCheck (hostPattern : String → Option Scope.Domain.HostPattern)
    (endpointOf : Release.Val → Option Scope.Domain.Endpoint) (bound : List AbsArg → Bound) : CheckSpec where
  kind := .endpoint
  pattern
    | [.const (.string hp), .const (.integer lo), .const (.integer hi), _] => do
      let h ← hostPattern hp
      let l ← Scope.Domain.Port.ofInt? lo.toInt
      let u ← Scope.Domain.Port.ofInt? hi.toInt
      some (.endpoint ⟨h, ⟨l, u⟩⟩)
    | _ => none
  target
    | [_, _, _, request] => (endpointOf request).map .endpoint
    | _ => none
  bound := bound

/-- 常に未知（Top）を返す範囲の読み取りは健全である。 -/
theorem requestCheck_unknown_boundSound (ok : Release.ConName) (P : Parsers)
    (hostPattern : String → Option Scope.Domain.HostPattern)
    (endpointOf : Release.Val → Option Scope.Domain.Endpoint) :
    (requestCheck hostPattern endpointOf (fun _ => .unknown)).BoundSound (models ok P) := by
  intro _ _ _ _ hb
  cases hb

/-- `Http.checkRequestIn` の範囲の型検査器による読み取り。ホストのパターンが文字列のリテラルで、二つのポートが整数の
リテラル（`const` の直接参照を含む）であり、実行時の検査と同じ解析と変換で得たポートの区間が整形式
（`PortRange.WF`。最小 ≤ 最大）のときだけ、既知のエンドポイントの範囲にする。それ以外は未知（Top）。要求の値は
読まない。最小が最大より大きい組を未知にするのは、整形式でない範囲を静的な範囲にしないためである（設計書 01-12
「Scope の局所解析の状態と規則の表」）。その範囲は所属する対象を持たないので、既知にすると、届かない成功の側への
任意の非 Top の注釈を被覆で受理してしまう。 -/
def requestLitBound (hostPattern : String → Option Scope.Domain.HostPattern) : List AbsArg → Bound
  | [.lit hs, .lit ls, .lit us, _] =>
    match litInt? hs, litInt? ls, litInt? us with
    | none, some lo, some hi =>
      match hostPattern hs, Scope.Domain.Port.ofInt? lo, Scope.Domain.Port.ofInt? hi with
      | some h, some l, some u =>
        if (⟨l, u⟩ : Scope.Domain.PortRange).WF then .known (.endpoint ⟨h, ⟨l, u⟩⟩) else .unknown
      | _, _, _ => .unknown
    | _, _, _ => .unknown
  | _ => .unknown

/-- リテラルによる読み取りは健全である。既知の範囲は、実行時の引数が表す動的なパターンと同じである。 -/
theorem requestLitBound_boundSound (ok : Release.ConName) (P : Parsers)
    (hostPattern : String → Option Scope.Domain.HostPattern)
    (endpointOf : Release.Val → Option Scope.Domain.Endpoint) :
    (requestCheck hostPattern endpointOf (requestLitBound hostPattern)).BoundSound (models ok P) := by
  intro aargs vs r hargs hb
  match aargs, hargs, hb with
  | [.lit hs, .lit ls, .lit us, _], .cons h0 (.cons h1 (.cons h2 (.cons _ .nil))), hb =>
    simp only [AbsArg.Models, models_lit] at h0 h1 h2
    simp only [requestCheck, requestLitBound] at hb ⊢
    cases e0 : litInt? hs with
    | some _ => simp [e0] at hb
    | none =>
      cases e1 : litInt? ls with
      | none => simp [e0, e1] at hb
      | some lo =>
        cases e2 : litInt? us with
        | none => simp [e0, e1, e2] at hb
        | some hi =>
          rw [litModels_of_none e0] at h0
          simp only [LitModels, e1, e2] at h1 h2
          obtain ⟨n1, rfl, hn1⟩ := h1
          obtain ⟨n2, rfl, hn2⟩ := h2
          subst h0 hn1 hn2
          simp only [e0, e1, e2] at hb
          cases eh : hostPattern hs <;> cases el : Scope.Domain.Port.ofInt? n1.toInt <;>
            cases eu : Scope.Domain.Port.ofInt? n2.toInt <;> simp only [eh, el, eu, reduceCtorEq] at hb ⊢
          -- 整形式の区間だけが既知になる。未知の場合は `hb` が偽である。
          split at hb
          · cases hb; rfl
          · cases hb
  | [], _, hb => simp [requestCheck, requestLitBound] at hb

/-- リテラルによる読み取りが既知にする範囲は、ポートの区間が整形式（`PortRange.WF`）のエンドポイントの範囲である。 -/
theorem requestLitBound_known_ports_wf {hostPattern : String → Option Scope.Domain.HostPattern}
    {aargs : List AbsArg} {r : Range} (hb : requestLitBound hostPattern aargs = .known r) :
    ∃ e : Scope.Domain.EndpointPattern, r = .endpoint e ∧ e.ports.WF := by
  unfold requestLitBound at hb
  split at hb
  · split at hb
    · split at hb
      · split at hb
        · next h => cases hb; exact ⟨_, rfl, h⟩
        · cases hb
      · cases hb
    · cases hb
  · cases hb

/-- ホストのパターンの解析が整形式のパターンだけを返すなら、リテラルによる読み取りが既知にする範囲は整形式
（`Range.WF`）である。交換の入力のホストのパターンの表は整形式であることを確かめてある（`Exchange.checkRangeInput`）。 -/
theorem requestLitBound_known_wf {hostPattern : String → Option Scope.Domain.HostPattern}
    (hhost : ∀ s h, hostPattern s = some h → h.WF) {aargs : List AbsArg} {r : Range}
    (hb : requestLitBound hostPattern aargs = .known r) : r.WF := by
  unfold requestLitBound at hb
  split at hb
  · split at hb
    · split at hb
      · next hs _ _ _ _ eh _ _ =>
        split at hb
        · next h => cases hb; exact ⟨hhost _ _ eh, h⟩
        · cases hb
      · cases hb
    · cases hb
  · cases hb

/-! ## 射影と拡大の規則 -/

/-- 対象の射影（`Scope.pathInValue`・`Http.requestInValue`）。普通の値を返し、事実を作らない。具体化の範囲は引数の
添字（必須の判定と同じ再照合）。 -/
def projectRule (run : List Range → List Release.Val → Option Release.Val) : ScopeRule Release.Val where
  index
    | [a] => [argIndex a]
    | _ => [.top]
  run := run
  transfer _ _ := none

theorem projectRule_sound (M : FactModels Release.Val) (run : List Range → List Release.Val → Option Release.Val) :
    RuleSound M (projectRule run) := by
  intro _ _ _ _ _ _ _ _ htr
  cases htr

/-- `Scope.pathInValue` の δ。検査済みの対象を文字列へ戻す（形式化の外側の関数 `text`）。 -/
def pathValueRun (text : Target → String) : List Range → List Release.Val → Option Release.Val
  | [_], [.checked t] => some (.const (.string (text t)))
  | _, _ => none

/-- 明示拡大（`Scope.widenPathIn`・`Http.widenRequestIn`）の δ。具体化は元の範囲 r と行き先 s の二つであり、s が r を
一原子で覆うときだけ同じ値を返す。 -/
def widenRun : List Range → List Release.Val → Option Release.Val
  | [r, s], [v] => if s.Covers r then some v else none
  | _, _ => none

/-- 明示拡大の規則。事実を作らない（結果の型は戻り値の注釈が決める）。型検査器が抽象の引数から選ぶのは元の範囲 R
だけであり、行き先 S は戻り値の注釈から決める（表層の型付け）。 -/
def widenRule : ScopeRule Release.Val where
  index
    | [a] => [argIndex a]
    | _ => [.top]
  run := widenRun
  transfer _ _ := none

theorem widenRule_sound (M : FactModels Release.Val) : RuleSound M widenRule := by
  intro _ _ _ _ _ _ _ _ htr
  cases htr

/-- 拡大の δ は同じ値を返し、そのとき行き先は元の範囲を覆う。 -/
theorem widenRun_same {r s : Range} {v w : Release.Val} (h : widenRun [r, s] [v] = some w) :
    w = v ∧ s.Covers r := by
  simp only [widenRun] at h
  split at h
  · next hc => cases h; exact ⟨rfl, hc⟩
  · cases h

/-- 拡大の δ は、種類に相対的な所属を行き先へ保つ（被覆の健全性 `Range.Covers.sound_memK`）。 -/
theorem widenRun_memK {r s : Range} {k : Kind} {t : Target} {w : Release.Val}
    (h : widenRun [r, s] [.checked t] = some w) (ht : r.MemK k t) : w = .checked t ∧ s.MemK k t := by
  obtain ⟨rfl, hc⟩ := widenRun_same h
  exact ⟨rfl, hc.sound_memK ht⟩

/-- 拡大の δ の結果は、本番の値の型付けで行き先の範囲付きの値型を持つ（`HasTypeVQ.checked_widen_covers`）。 -/
theorem widenRun_hasTypeV {Pr : Release.Program} {B : Release.Builtins} {Ψ : Release.StoreTy}
    {Q : Release.NoFailCtx} {C : List Release.TParam} {Γ : List (Option Release.Ty)} {o : Release.OpaqueName}
    {r s : Range} {t : Target} {w : Release.Val}
    (hv : Release.HasTypeVQ Pr B Ψ Q C Γ (.checked t) (.opaque o (.fixed r)))
    (h : widenRun [r, s] [.checked t] = some w) : Release.HasTypeVQ Pr B Ψ Q C Γ w (.opaque o (.fixed s)) := by
  obtain ⟨rfl, hc⟩ := widenRun_same h
  exact Release.HasTypeVQ.checked_widen_covers hv hc

/-! ## 解決済みの宣言と規則の表 -/

/-- 解決済みの宣言の所有元。標準の所有元か、利用者のモジュールか。 -/
inductive Owner where
  | standard
  | user (module : String)
  deriving DecidableEq, Repr

/-- 出現を解決した宣言（所有元と宣言の名前）。 -/
structure Resolved where
  owner : Owner
  declaration : String
  deriving DecidableEq, Repr

/-- 出現の解決の結果から作る表。`apiAt` は標準の所有元に解決した宣言だけを返し、同じ綴りの利用者の関数は
入らない。 -/
def standardTable (resolve : Key → Option Resolved) (rules : String → Option (ScopeRule Release.Val)) :
    ScopeTable Release.Val where
  apiAt key :=
    match resolve key with
    | some ⟨.standard, d⟩ => some d
    | _ => none
  rules := rules

/-- `apiAt` が返す宣言は、標準の所有元に解決した宣言である。 -/
theorem standardTable_apiAt {resolve : Key → Option Resolved} {rules : String → Option (ScopeRule Release.Val)}
    {key : Key} {d : String} : (standardTable resolve rules).apiAt key = some d ↔ resolve key = some ⟨.standard, d⟩ := by
  simp only [standardTable]
  constructor
  · intro h
    split at h
    · next d' hres => cases h; exact hres
    · cases h
  · intro h
    simp [h]

/-- 利用者のモジュールに解決した出現（標準の宣言と同じ綴りでも）には規則を付けない。 -/
theorem standardTable_user_ruleAt {resolve : Key → Option Resolved}
    {rules : String → Option (ScopeRule Release.Val)} {key : Key} {m d : String}
    (h : resolve key = some ⟨.user m, d⟩) : (standardTable resolve rules).ruleAt key = none := by
  simp [ScopeTable.ruleAt, standardTable, h]

/-- 利用者の関数の出現からは抽象の結果を作らず、標準の規則を適用する導出もない。 -/
theorem standardTable_user {resolve : Key → Option Resolved} {rules : String → Option (ScopeRule Release.Val)}
    {key : Key} {m d : String} (h : resolve key = some ⟨.user m, d⟩) :
    (∀ aargs, absApply (standardTable resolve rules) key aargs = none) ∧
      ∀ rs vs v, ¬ EvalScope (standardTable resolve rules) key rs vs v := by
  have hr := standardTable_user_ruleAt (rules := rules) h
  exact ⟨fun aargs => by simp [absApply, hr], fun _ _ _ => evalScope_unidentified hr⟩

/-- 標準の宣言の名前（L00.08 の一括の問い、問 22）。 -/
def checkPathName : String := "Scope.checkPathIn"
def checkRequestName : String := "Http.checkRequestIn"
def pathValueName : String := "Scope.pathInValue"
def requestValueName : String := "Http.requestInValue"
def widenPathName : String := "Scope.widenPathIn"
def widenRequestName : String := "Http.widenRequestIn"

/-- 規則を持つ標準の宣言の一覧。 -/
def ruleDeclarations : List String :=
  [checkPathName, checkRequestName, pathValueName, requestValueName, widenPathName, widenRequestName]

/-- 検査・射影・拡大の六つの項目。 -/
structure Rules where
  checkPath : ScopeRule Release.Val
  checkRequest : ScopeRule Release.Val
  pathValue : ScopeRule Release.Val
  requestValue : ScopeRule Release.Val
  widenPath : ScopeRule Release.Val
  widenRequest : ScopeRule Release.Val

/-- 宣言の名前から項目を引く。一覧にない宣言には規則がない。 -/
def Rules.lookup (R : Rules) (d : String) : Option (ScopeRule Release.Val) :=
  if d = checkPathName then some R.checkPath
  else if d = checkRequestName then some R.checkRequest
  else if d = pathValueName then some R.pathValue
  else if d = requestValueName then some R.requestValue
  else if d = widenPathName then some R.widenPath
  else if d = widenRequestName then some R.widenRequest
  else none

/-- 六つの項目がどれも健全であること。 -/
def Rules.Sound (M : FactModels Release.Val) (R : Rules) : Prop :=
  RuleSound M R.checkPath ∧ RuleSound M R.checkRequest ∧ RuleSound M R.pathValue ∧
    RuleSound M R.requestValue ∧ RuleSound M R.widenPath ∧ RuleSound M R.widenRequest

/-- 規則を持つのは一覧の宣言だけである。 -/
theorem Rules.lookup_mem {R : Rules} {d : String} {rule : ScopeRule Release.Val} (h : R.lookup d = some rule) :
    d ∈ ruleDeclarations := by
  unfold Rules.lookup at h
  by_cases h1 : d = checkPathName
  · subst h1; simp [ruleDeclarations]
  by_cases h2 : d = checkRequestName
  · subst h2; simp [ruleDeclarations]
  by_cases h3 : d = pathValueName
  · subst h3; simp [ruleDeclarations]
  by_cases h4 : d = requestValueName
  · subst h4; simp [ruleDeclarations]
  by_cases h5 : d = widenPathName
  · subst h5; simp [ruleDeclarations]
  by_cases h6 : d = widenRequestName
  · subst h6; simp [ruleDeclarations]
  rw [ite_eq_right h1, ite_eq_right h2, ite_eq_right h3, ite_eq_right h4, ite_eq_right h5,
    ite_eq_right h6] at h
  cases h

/-- 項目ごとの健全性から表の健全性が従う。 -/
theorem Rules.lookup_sound {M : FactModels Release.Val} {R : Rules} (hR : R.Sound M)
    (resolve : Key → Option Resolved) : TableSound M (standardTable resolve R.lookup) := by
  intro d rule h
  obtain ⟨h1, h2, h3, h4, h5, h6⟩ := hR
  change R.lookup d = some rule at h
  unfold Rules.lookup at h
  by_cases e1 : d = checkPathName
  · rw [ite_eq_left e1] at h; cases h; exact h1
  by_cases e2 : d = checkRequestName
  · rw [ite_eq_right e1, ite_eq_left e2] at h; cases h; exact h2
  by_cases e3 : d = pathValueName
  · rw [ite_eq_right e1, ite_eq_right e2, ite_eq_left e3] at h; cases h; exact h3
  by_cases e4 : d = requestValueName
  · rw [ite_eq_right e1, ite_eq_right e2, ite_eq_right e3, ite_eq_left e4] at h; cases h; exact h4
  by_cases e5 : d = widenPathName
  · rw [ite_eq_right e1, ite_eq_right e2, ite_eq_right e3, ite_eq_right e4, ite_eq_left e5] at h
    cases h; exact h5
  by_cases e6 : d = widenRequestName
  · rw [ite_eq_right e1, ite_eq_right e2, ite_eq_right e3, ite_eq_right e4, ite_eq_right e5,
      ite_eq_left e6] at h
    cases h; exact h6
  rw [ite_eq_right e1, ite_eq_right e2, ite_eq_right e3, ite_eq_right e4, ite_eq_right e5,
    ite_eq_right e6] at h
  cases h

/-- 適用の健全性（採用定義の `apply_sound` の本番の表への具体化）。 -/
theorem standardTable_apply_sound {M : FactModels Release.Val} {R : Rules} (hR : R.Sound M)
    (resolve : Key → Option Resolved) {key : Key} {rs : List Range} {vs : List Release.Val} {v : Release.Val}
    {aargs : List AbsArg} {f : ScopeFact} (hargs : ArgsModel M aargs vs)
    (hev : EvalScope (standardTable resolve R.lookup) key rs vs v)
    (hf : absApply (standardTable resolve R.lookup) key aargs = some f) : ∀ id, M.fact f id v :=
  apply_sound (Rules.lookup_sound hR resolve) hargs hev hf

/-- 本番の表を作るための、形式化の外側の関数と Result の表し方。 -/
structure Boundary where
  /-- `Result.Ok`・`Result.Err` の構成子の名前と、具体化した範囲での Result の型引数。 -/
  ok : Release.ConName
  err : Release.ConName
  pathTys : Range → List Release.Ty
  requestTys : Range → List Release.Ty
  /-- 失敗の値（`Scope.ScopeError`・`Http.RequestCheckError` の値）。中身は局所解析に現れない。 -/
  pathFailure : Release.Val
  requestFailure : Release.Val
  /-- パスのパターンと対象の文字列の解析。 -/
  parsers : Parsers
  /-- ホストのパターンの文字列の解析と、要求から実効の endpoint を得る処理。 -/
  hostPattern : String → Option Scope.Domain.HostPattern
  endpointOf : Release.Val → Option Scope.Domain.Endpoint
  /-- 型検査器が `Http.checkRequestIn` の抽象の引数から得る範囲（本番はリテラルによる読み取り `requestLitBound`）。 -/
  requestBound : List AbsArg → Bound
  /-- 検査済みの対象をパスの文字列へ戻す処理と、`Http.requestInValue` の δ。 -/
  pathText : Target → String
  requestValueRun : List Range → List Release.Val → Option Release.Val

/-- 本番の六つの項目。 -/
def Boundary.rules (B : Boundary) : Rules where
  checkPath := checkRule (pathCheck B.parsers)
    (checkDelta B.ok B.err B.pathTys B.pathFailure checkedOk (pathCheck B.parsers))
  checkRequest :=
    let C := requestCheck B.hostPattern B.endpointOf B.requestBound
    checkRule C (checkDelta B.ok B.err B.requestTys B.requestFailure requestOk C)
  pathValue := projectRule (pathValueRun B.pathText)
  requestValue := projectRule B.requestValueRun
  widenPath := widenRule
  widenRequest := widenRule

/-- 本番の対応。 -/
abbrev Boundary.models (B : Boundary) : FactModels Release.Val := ScopeState.models B.ok B.parsers

/-- 本番の六つの項目の健全性。条件は、Ok と Err の構成子の名前が違うことと、`Http.checkRequestIn` の範囲の
読み取りの健全性だけである。 -/
theorem Boundary.rules_sound (B : Boundary) (hne : B.ok ≠ B.err)
    (hreq : (requestCheck B.hostPattern B.endpointOf B.requestBound).BoundSound B.models) :
    B.rules.Sound B.models :=
  ⟨checkRule_sound (pathCheck_boundSound B.ok B.parsers) (checkDelta_contract hne _ _ checkedOk_target _),
   checkRule_sound hreq (checkDelta_contract hne _ _ requestOk_target _),
   projectRule_sound _ _, projectRule_sound _ _, widenRule_sound _, widenRule_sound _⟩

/-- `Http.checkRequestIn` の範囲をリテラルで読む本番の表の健全性。条件は Ok と Err の構成子の名前が違うことだけである。 -/
theorem Boundary.rules_sound_lit (B : Boundary) (hne : B.ok ≠ B.err)
    (hlit : B.requestBound = requestLitBound B.hostPattern) : B.rules.Sound B.models :=
  B.rules_sound hne (hlit ▸ requestLitBound_boundSound B.ok B.parsers B.hostPattern B.endpointOf)

/-! ## 一段の評価（本番の値） -/

/-- 呼び出しの引数の式。文字列と整数のリテラル（`const` の直接参照を含む）、局所の読み取り、局所に対する直接の
一引数の標準の呼び出し（射影）、それ以外の式（`other`。値を読まない）。 -/
inductive Arg where
  | lit (s : String)
  | int (n : Release.Integer64Value)
  | loc (index : Nat)
  | proj (key : Key) (index : Nat)
  | other
  deriving DecidableEq, Repr

/-- 抽象の引数。整数のリテラルは `intLitText` の綴りにする。先頭が U+0000 で整数の綴りと読める文字列のリテラルは、
整数のリテラルと取り違えないよう未知にする。 -/
def absArg (T : ScopeTable Release.Val) (st : ScopeState) : Arg → AbsArg
  | .lit s => if (litInt? s).isSome then .unknown else .lit s
  | .int n => .lit (intLitText n)
  | .loc i => st.readLocal i
  | .proj key i =>
    match absApply T key [st.readLocal i] with
    | some f => .value f
    | none => .unknown
  | .other => .unknown

/-- 引数の具体の評価。同定されない射影の出現とそれ以外の式は任意の値を返してよい。 -/
inductive EvalArg (T : ScopeTable Release.Val) (env : Locals) : Arg → Release.Val → Prop where
  | lit (s : String) : EvalArg T env (.lit s) (.const (.string s))
  | int (n : Release.Integer64Value) : EvalArg T env (.int n) (.const (.integer n))
  | loc (i : Nat) (v : Release.Val) (found : env[i]? = some (some v)) : EvalArg T env (.loc i) v
  | proj (key : Key) (i : Nat) (rs : List Range) (w v : Release.Val) (found : env[i]? = some (some w))
      (eval : EvalScope T key rs [w] v) : EvalArg T env (.proj key i) v
  | projOther (key : Key) (i : Nat) (v : Release.Val) (missing : T.ruleAt key = none) :
      EvalArg T env (.proj key i) v
  | other (v : Release.Val) : EvalArg T env .other v

inductive EvalArgs (T : ScopeTable Release.Val) (env : Locals) : List Arg → List Release.Val → Prop where
  | nil : EvalArgs T env [] []
  | cons {a as v vs} : EvalArg T env a v → EvalArgs T env as vs → EvalArgs T env (a :: as) (v :: vs)

/-- 文の一段。`call` は標準の直接呼び出しの結果を新しい位置へ一度だけ保存する。`okArm i` は位置 i の Result の
`Ok` の腕で成功値を新しい位置へ束縛する。`alias i` は別名、`unknown` は未知の呼び出し・再包装・リテラルの束縛、
`join` は合流と本体の境界。 -/
inductive Step where
  | call (key : Key) (args : List Arg)
  | okArm (index : Nat)
  | alias (index : Nat)
  | unknown
  | join
  deriving DecidableEq, Repr

/-- 具体の一段。同定されない呼び出しと未知の値は任意の値を返してよい。 -/
inductive StepEval (ok : Release.ConName) (T : ScopeTable Release.Val) : Locals → Step → Locals → Prop where
  | callStd {env key args vs rs v} : EvalArgs T env args vs → EvalScope T key rs vs v →
      StepEval ok T env (.call key args) (some v :: env)
  | callOther {env key args v} : T.ruleAt key = none → StepEval ok T env (.call key args) (some v :: env)
  | okArm {env i v w} : env[i]? = some (some v) → okPayload ok v = some w →
      StepEval ok T env (.okArm i) (some w :: env)
  | alias {env i w} : env[i]? = some (some w) → StepEval ok T env (.alias i) (some w :: env)
  | unknown {env v} : StepEval ok T env .unknown (v :: env)
  | join {env} : StepEval ok T env .join env

/-- 抽象の一段。成功値の事実を作るのは `okArm` だけで、読む Result の事実の由来を写し、新しい位置の束縛番号を
成功値番号にする。 -/
def absStep (T : ScopeTable Release.Val) (st : ScopeState) : Step → ScopeState
  | .call key args => st.extend (absApply T key (args.map (absArg T st)))
  | .okArm i =>
    st.extend <|
      match st.facts[i]? with
      | some (some (.result o)) => some (.checked o st.scope.nextId)
      | _ => none
  | .alias _ => st.extend none
  | .unknown => st.extend none
  | .join => st.forgetAll

def absSteps (T : ScopeTable Release.Val) : ScopeState → List Step → ScopeState
  | st, [] => st
  | st, s :: ss => absSteps T (absStep T st s) ss

inductive StepsEval (ok : Release.ConName) (T : ScopeTable Release.Val) : Locals → List Step → Locals → Prop where
  | nil {env} : StepsEval ok T env [] env
  | cons {env env' env'' s ss} : StepEval ok T env s env' → StepsEval ok T env' ss env'' →
      StepsEval ok T env (s :: ss) env''

theorem absArgs_models {ok : Release.ConName} {P : Parsers} {T : ScopeTable Release.Val}
    (hT : TableSound (models ok P) T) {st : ScopeState} {env : Locals} (hm : st.Models (models ok P) env)
    {args : List Arg} {vs : List Release.Val} (hev : EvalArgs T env args vs) :
    ArgsModel (models ok P) (args.map (absArg T st)) vs := by
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
theorem absStep_sound {ok : Release.ConName} {P : Parsers} {T : ScopeTable Release.Val}
    (hT : TableSound (models ok P) T) {st : ScopeState} {env env' : Locals} {s : Step}
    (hm : st.Models (models ok P) env) (hev : StepEval ok T env s env') :
    (absStep T st s).Models (models ok P) env' := by
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

theorem absSteps_sound {ok : Release.ConName} {P : Parsers} {T : ScopeTable Release.Val}
    (hT : TableSound (models ok P) T) {ss : List Step} :
    ∀ {st : ScopeState} {env env' : Locals}, st.Models (models ok P) env → StepsEval ok T env ss env' →
      (absSteps T st ss).Models (models ok P) env' := by
  induction ss with
  | nil => intro st env env' hm hev; cases hev; exact hm
  | cons s ss ih =>
    intro st env env' hm hev
    cases hev with
    | cons h1 h2 => exact ih (absStep_sound hT hm h1) h2

/-! ## 予算と忘却 -/

/-- 超過の補足の欄。区間解析の予算と同じ区別（本体か全体か、操作数か保持数か）を同じ型で持つ。予算の状態と
上限は区間解析と共有しない。 -/
abbrev LimitFailure := Benitoite.Interval.Budget.LimitFailure

/-- 一つの範囲に許す累積の操作数と同時の保持項目数。 -/
structure Cap where
  operations : Nat
  items : Nat
  deriving DecidableEq, Repr

/-- 本体と全体の上限。既定値を持たない（値は処理系の測定で決める）。 -/
structure Limits where
  body : Cap
  whole : Cap
  deriving DecidableEq, Repr

/-- 必須の判定の予算の状態。現在の本体の累積の操作数、全体の累積の操作数、外側の本体が保持する項目の数。
現在の本体の保持項目の数は局所状態から数える（`heldItems`）。 -/
structure Budget where
  bodyOperations : Nat
  wholeOperations : Nat
  outerItems : Nat
  deriving DecidableEq, Repr

def Budget.initial : Budget := ⟨0, 0, 0⟩

/-- 保持の数え方。事実を持つ位置ごとに一項であり、由来は事実に含める。事実を持たない位置は数えない。 -/
def heldItems (st : ScopeState) : Nat := st.facts.countP Option.isSome

/-- 局所の読み取りの操作数。位置の読み取りに一回、同じ成功値の事実なら再照合に一回。 -/
def readCost (st : ScopeState) (i : Nat) : Nat :=
  1 + match st.facts[i]? with
    | some (some (.checked _ _)) => 1
    | _ => 0

/-- 引数の操作数。リテラルとそれ以外の式は数えず、局所の読み取りと、射影ならその適用に一回。 -/
def argCost (st : ScopeState) : Arg → Nat
  | .lit _ | .int _ | .other => 0
  | .loc i => readCost st i
  | .proj _ i => readCost st i + 1

/-- 一段の操作数（計上点）。呼び出しは出現の同定と表の参照に一回、引数ごとの操作数、事実を書き込めば一回。
`Ok` の腕は Result の位置の読み取りに一回、由来を写せば一回。別名は読み取りに一回。忘却は事実を持つ位置の数。 -/
def stepCost (T : ScopeTable Release.Val) (st : ScopeState) : Step → Nat
  | .call key args =>
    1 + (args.map (argCost st)).sum + (if (absApply T key (args.map (absArg T st))).isSome then 1 else 0)
  | .okArm i =>
    1 + match st.facts[i]? with
      | some (some (.result _)) => 1
      | _ => 0
  | .alias _ => 1
  | .unknown => 0
  | .join => heldItems st

/-- 計上。操作数を加え、計上の後の保持数を確かめる。操作数を保持数より先に、本体を全体より先に報告する。
拒否では候補の状態を採用しない。 -/
def Budget.admit (L : Limits) (b : Budget) (ops held : Nat) : Except LimitFailure Budget :=
  let next : Budget := { b with bodyOperations := b.bodyOperations + ops,
                                wholeOperations := b.wholeOperations + ops }
  if next.bodyOperations > L.body.operations then .error ⟨.body, .operations⟩
  else if next.wholeOperations > L.whole.operations then .error ⟨.whole, .operations⟩
  else if held > L.body.items then .error ⟨.body, .items⟩
  else if b.outerItems + held > L.whole.items then .error ⟨.whole, .items⟩
  else .ok next

/-- 上限内にある予算の状態（保持数は局所状態の数え方による）。 -/
def Budget.Within (L : Limits) (b : Budget) (held : Nat) : Prop :=
  b.bodyOperations ≤ L.body.operations ∧ b.wholeOperations ≤ L.whole.operations ∧
    held ≤ L.body.items ∧ b.outerItems + held ≤ L.whole.items

/-- 成功した計上は、本体と全体の操作数に同じ数を加え、上限内にある。 -/
theorem Budget.admit_ok {L : Limits} {b b' : Budget} {ops held : Nat} (h : b.admit L ops held = .ok b') :
    b'.bodyOperations = b.bodyOperations + ops ∧ b'.wholeOperations = b.wholeOperations + ops ∧
      b'.outerItems = b.outerItems ∧ b'.Within L held := by
  simp only [Budget.admit] at h
  split at h
  · cases h
  · split at h
    · cases h
    · split at h
      · cases h
      · split at h
        · cases h
        · cases h
          refine ⟨rfl, rfl, rfl, ?_, ?_, ?_, ?_⟩ <;> simp_all <;> omega

/-- 拒否の理由は、候補の状態がどの上限を超えたかを表す。 -/
theorem Budget.admit_error {L : Limits} {b : Budget} {ops held : Nat} {f : LimitFailure}
    (h : b.admit L ops held = .error f) :
    (f = ⟨.body, .operations⟩ ∧ L.body.operations < b.bodyOperations + ops) ∨
      (f = ⟨.whole, .operations⟩ ∧ L.whole.operations < b.wholeOperations + ops) ∨
      (f = ⟨.body, .items⟩ ∧ L.body.items < held) ∨
      (f = ⟨.whole, .items⟩ ∧ L.whole.items < b.outerItems + held) := by
  simp only [Budget.admit] at h
  split at h
  · next h1 => cases h; exact .inl ⟨rfl, h1⟩
  · split at h
    · next h2 => cases h; exact .inr (.inl ⟨rfl, h2⟩)
    · split at h
      · next h3 => cases h; exact .inr (.inr (.inl ⟨rfl, h3⟩))
      · split at h
        · next h4 => cases h; exact .inr (.inr (.inr ⟨rfl, h4⟩))
        · cases h

/-- 本体の入口（ラムダ、handle の保護本体と節、Task の入口）。現在の本体の保持を外側の保持へ移し、本体の操作数を
0 から数える。全体の操作数は引き継ぐ。 -/
def Budget.enter (b : Budget) (held : Nat) : Budget :=
  { b with bodyOperations := 0, outerItems := b.outerItems + held }

/-- 本体の出口。外側の本体の操作数と保持へ戻し、全体の操作数は内側の値を引き継ぐ。 -/
def Budget.leave (outer inner : Budget) : Budget :=
  { outer with wholeOperations := inner.wholeOperations }

theorem Budget.enter_whole (b : Budget) (held : Nat) : (b.enter held).wholeOperations = b.wholeOperations := rfl

theorem Budget.leave_whole (outer inner : Budget) : (outer.leave inner).wholeOperations = inner.wholeOperations :=
  rfl

theorem Budget.leave_body (outer inner : Budget) :
    (outer.leave inner).bodyOperations = outer.bodyOperations ∧ (outer.leave inner).outerItems = outer.outerItems :=
  ⟨rfl, rfl⟩

/-- 由来を作らない一段。位置と番号は通常の一段と同じに保つ（予算の超過の後に使う）。 -/
def blindStep (st : ScopeState) : Step → ScopeState
  | .join => st.forgetAll
  | _ => st.extend none

/-- 予算付きの局所解析の状態。上限内で進む状態か、超過の補足と、全ての由来を忘れた状態。 -/
inductive Run where
  | running (st : ScopeState) (budget : Budget)
  | stopped (failure : LimitFailure) (st : ScopeState) (budget : Budget)

def Run.state : Run → ScopeState
  | .running st _ | .stopped _ st _ => st

def Run.budget : Run → Budget
  | .running _ b | .stopped _ _ b => b

/-- 超過の理由。診断の理由の `budgetExceeded` に当たり、補足の欄に本体か全体か、操作数か保持数かを持つ。 -/
inductive ExceedReason where
  | budgetExceeded (detail : LimitFailure)
  deriving DecidableEq, Repr

def Run.exceeded : Run → Option ExceedReason
  | .running _ _ => none
  | .stopped f _ _ => some (.budgetExceeded f)

/-- 予算付きの一段。計上が上限内なら通常の一段、超えたら予算の状態を変えずに全ての由来を忘れて止まる。止まった後は
由来を作らず、計上もしない。 -/
def Run.step (T : ScopeTable Release.Val) (L : Limits) : Run → Step → Run
  | .running st b, s =>
    let next := absStep T st s
    match b.admit L (stepCost T st s) (heldItems next) with
    | .ok b' => .running next b'
    | .error f => .stopped f (blindStep st.forgetAll s) b
  | .stopped f st b, s => .stopped f (blindStep st s) b

def Run.steps (T : ScopeTable Release.Val) (L : Limits) : Run → List Step → Run
  | r, [] => r
  | r, s :: ss => Run.steps T L (r.step T L s) ss

/-- 本体の入口の予算付きの状態。由来を仮定しない。全体の上限の超過は内側にも及ぶ。 -/
def Run.enter (scope : Interval.BindingScope) : Run → Run
  | .running st b => .running (ScopeState.empty scope) (b.enter (heldItems st))
  | .stopped f st b =>
    if f.scope = .whole then .stopped f (ScopeState.empty scope) b
    else .running (ScopeState.empty scope) (b.enter (heldItems st))

/-- 本体の出口。外側の状態に戻り、全体の操作数を引き継ぐ。内側が全体の上限を超えていたら外側も止まる。 -/
def Run.leave (outer inner : Run) : Run :=
  match inner with
  | .stopped f _ ib =>
    if f.scope = .whole then .stopped f outer.state.forgetAll (outer.budget.leave ib)
    else
      match outer with
      | .running st b => .running st (b.leave ib)
      | .stopped g st b => .stopped g st (b.leave ib)
  | .running _ ib =>
    match outer with
    | .running st b => .running st (b.leave ib)
    | .stopped g st b => .stopped g st (b.leave ib)

/-- 由来を持たない局所状態。 -/
def NoFacts (st : ScopeState) : Prop := ∀ (i : Nat) (f : ScopeFact), st.facts[i]? ≠ some (some f)

theorem noFacts_forgetAll (st : ScopeState) : NoFacts st.forgetAll := by
  intro i f h
  simp [ScopeState.forgetAll] at h

theorem noFacts_empty (scope : Interval.BindingScope) : NoFacts (ScopeState.empty scope) := by
  intro i f h
  simp only [ScopeState.empty, List.getElem?_replicate] at h
  split at h <;> simp_all

theorem noFacts_blindStep {st : ScopeState} (h : NoFacts st) (s : Step) : NoFacts (blindStep st s) := by
  cases s with
  | join => exact noFacts_forgetAll st
  | _ =>
    intro i f hf
    cases i with
    | zero => simp [blindStep, ScopeState.extend] at hf
    | succ i => exact h i f (by simpa [blindStep, ScopeState.extend] using hf)

/-- 由来を持たない位置には、必須の判定は Top を付ける。 -/
theorem noFacts_requiredIndex {st : ScopeState} (h : NoFacts st) (i : Nat) : st.requiredIndex i = .top := by
  unfold ScopeState.requiredIndex
  cases hf : st.facts[i]? with
  | none => rfl
  | some fo =>
    cases fo with
    | none => rfl
    | some f => exact absurd hf (h i f)

/-- 止まった状態は由来を持たない（不変条件）。 -/
def Run.Good : Run → Prop
  | .running _ _ => True
  | .stopped _ st _ => NoFacts st

theorem Run.step_good (T : ScopeTable Release.Val) (L : Limits) {r : Run} (h : r.Good) (s : Step) :
    (r.step T L s).Good := by
  cases r with
  | running st b =>
    simp only [Run.step]
    split
    · trivial
    · exact noFacts_blindStep (noFacts_forgetAll st) s
  | stopped f st b => exact noFacts_blindStep h s

theorem Run.steps_good (T : ScopeTable Release.Val) (L : Limits) {ss : List Step} :
    ∀ {r : Run}, r.Good → (r.steps T L ss).Good := by
  induction ss with
  | nil => intro r h; exact h
  | cons s ss ih => intro r h; exact ih (r.step_good T L h s)

theorem Run.enter_good (scope : Interval.BindingScope) (r : Run) : (r.enter scope).Good := by
  cases r with
  | running => trivial
  | stopped f st b =>
    simp only [Run.enter]
    split
    · exact noFacts_empty scope
    · trivial

theorem Run.leave_good {outer : Run} (h : outer.Good) (inner : Run) : (outer.leave inner).Good := by
  cases inner with
  | stopped f _ ib =>
    simp only [Run.leave]
    split
    · exact noFacts_forgetAll _
    · cases outer with
      | running => trivial
      | stopped => exact h
  | running _ ib =>
    cases outer with
    | running => trivial
    | stopped => exact h

/-- 超過で止まった状態の必須の判定は、全ての位置で Top である。 -/
theorem Run.exceeded_requiredIndex {r : Run} (h : r.Good) {e : ExceedReason} (he : r.exceeded = some e)
    (i : Nat) : r.state.requiredIndex i = .top := by
  cases r with
  | running => cases he
  | stopped f st b => exact noFacts_requiredIndex h i

/-- 一度止まった状態は、続く一段でも止まったままであり、理由を変えない。 -/
theorem Run.steps_stopped (T : ScopeTable Release.Val) (L : Limits) {ss : List Step} :
    ∀ {f : LimitFailure} {st : ScopeState} {b : Budget},
      ∃ st', (Run.stopped f st b).steps T L ss = .stopped f st' b := by
  induction ss with
  | nil => intro f st b; exact ⟨st, rfl⟩
  | cons s ss ih => intro f st b; exact ih

/-- 予算の内で終わった解析は、予算のない解析と同じ局所状態を返す（予算は精度を変えない）。 -/
theorem Run.steps_running (T : ScopeTable Release.Val) (L : Limits) {ss : List Step} :
    ∀ {st : ScopeState} {b : Budget} {st' : ScopeState} {b' : Budget},
      (Run.running st b).steps T L ss = .running st' b' → st' = absSteps T st ss := by
  induction ss with
  | nil => intro st b st' b' h; cases h; rfl
  | cons s ss ih =>
    intro st b st' b' h
    simp only [Run.steps, Run.step] at h
    split at h
    · exact ih h
    · next f _ =>
      obtain ⟨_, hs⟩ := Run.steps_stopped T L (ss := ss) (f := f) (st := blindStep st.forgetAll s) (b := b)
      rw [hs] at h
      cases h

/-- 由来を作らない一段は、具体の一段に対応を保つ。 -/
theorem blindStep_models {ok : Release.ConName} {P : Parsers} {T : ScopeTable Release.Val} {st : ScopeState}
    {env env' : Locals} {s : Step} (hm : st.Models (models ok P) env) (hev : StepEval ok T env s env') :
    (blindStep st s).Models (models ok P) env' := by
  cases hev with
  | join => exact ScopeState.forgetAll_models _ st _
  | callStd => exact ScopeState.extend_models hm (fun f hf => by cases hf)
  | callOther => exact ScopeState.extend_models hm (fun f hf => by cases hf)
  | okArm => exact ScopeState.extend_models hm (fun f hf => by cases hf)
  | alias => exact ScopeState.extend_models hm (fun f hf => by cases hf)
  | unknown => exact ScopeState.extend_models hm (fun f hf => by cases hf)

/-- 予算付きの一段の健全性。上限の値によらず、超過して Top を返す場合も含めて対応を保つ。 -/
theorem Run.step_models {ok : Release.ConName} {P : Parsers} {T : ScopeTable Release.Val}
    (hT : TableSound (models ok P) T) (L : Limits) {r : Run} {env env' : Locals} {s : Step}
    (hm : r.state.Models (models ok P) env) (hev : StepEval ok T env s env') :
    (r.step T L s).state.Models (models ok P) env' := by
  cases r with
  | running st b =>
    simp only [Run.step]
    split
    · exact absStep_sound hT hm hev
    · exact blindStep_models (ScopeState.forgetAll_models _ st env) hev
  | stopped f st b => exact blindStep_models hm hev

theorem Run.steps_models {ok : Release.ConName} {P : Parsers} {T : ScopeTable Release.Val}
    (hT : TableSound (models ok P) T) (L : Limits) {ss : List Step} :
    ∀ {r : Run} {env env' : Locals}, r.state.Models (models ok P) env → StepsEval ok T env ss env' →
      (r.steps T L ss).state.Models (models ok P) env' := by
  induction ss with
  | nil => intro r env env' hm hev; cases hev; exact hm
  | cons s ss ih =>
    intro r env env' hm hev
    cases hev with
    | cons h1 h2 => exact ih (Run.step_models hT L hm h1) h2

/-- 本体の入口の状態は任意の具体の局所に対応する（由来を仮定しない）。 -/
theorem Run.enter_models (M : FactModels Release.Val) (scope : Interval.BindingScope) (r : Run)
    (env : Locals) : (r.enter scope).state.Models M env := by
  cases r with
  | running => exact ScopeState.empty_models M scope env
  | stopped f st b =>
    simp only [Run.enter]
    split <;> exact ScopeState.empty_models M scope env

/-- 本体の出口は外側の状態（またはその忘却）に戻るので、外側の対応を保つ。 -/
theorem Run.leave_models {M : FactModels Release.Val} {outer : Run} {env : Locals}
    (hm : outer.state.Models M env) (inner : Run) : (outer.leave inner).state.Models M env := by
  cases inner with
  | stopped f _ ib =>
    simp only [Run.leave]
    split
    · exact ScopeState.forgetAll_models M _ env
    · cases outer <;> exact hm
  | running _ ib => cases outer <;> exact hm

/-- 内側の本体が全体の上限を超えたら、外側も同じ理由で止まる。本体の上限の超過は外側に及ばない。 -/
theorem Run.leave_exceeded (outer : Run) {f : LimitFailure} {st : ScopeState} {ib : Budget} :
    (f.scope = .whole → (outer.leave (.stopped f st ib)).exceeded = some (.budgetExceeded f)) ∧
      (f.scope ≠ .whole → (outer.leave (.stopped f st ib)).exceeded = outer.exceeded) := by
  constructor
  · intro h; simp [Run.leave, h, Run.exceeded]
  · intro h; cases outer <;> simp [Run.leave, h, Run.exceeded]

/-! ## Range の警告の解析との分離 -/

/-- 区間解析の局所の事実と予算、Scope の局所解析の状態と予算を並べた検査の状態。束縛番号は Scope の局所状態が
持つ一つを共有する（`toLocalState`）。 -/
structure Analyses (RF : Type) where
  range : List (Option RF)
  rangeBudget : Benitoite.Interval.Budget.State
  scope : Run

/-- 採用定義の `LocalState`（同じ束縛番号の上の二つの成分）へ写す。 -/
def Analyses.toLocalState {RF : Type} (a : Analyses RF) : LocalState RF :=
  ⟨a.scope.state.scope, a.range, a.scope.state.facts⟩

theorem Analyses.toLocalState_toScope {RF : Type} (a : Analyses RF) : a.toLocalState.toScope = a.scope.state := rfl

/-- Scope の局所解析の一段。区間解析の成分と予算を読まず、変えない。 -/
def Analyses.stepScope {RF : Type} (T : ScopeTable Release.Val) (L : Limits) (a : Analyses RF) (s : Step) :
    Analyses RF :=
  { a with scope := a.scope.step T L s }

/-- 区間解析の予算の計上（`Interval.Budget.charge`）は、Scope の局所解析の状態と予算を変えない。 -/
def Analyses.chargeRange {RF : Type} (L : Benitoite.Interval.Budget.Limits) (a : Analyses RF)
    (op : Benitoite.Interval.Budget.Operation) : Analyses RF :=
  { a with rangeBudget := (Benitoite.Interval.Budget.charge L a.rangeBudget op).state }

/-- 必須の判定とその予算の超過は、区間解析の成分と予算を読まない。 -/
theorem Analyses.required_range_independent {RF : Type} (a : Analyses RF) (r : List (Option RF))
    (b : Benitoite.Interval.Budget.State) (i : Nat) :
    ({ a with range := r, rangeBudget := b }).scope.state.requiredIndex i = a.scope.state.requiredIndex i ∧
      ({ a with range := r, rangeBudget := b }).scope.exceeded = a.scope.exceeded := ⟨rfl, rfl⟩

/-- Scope の一段の結果は区間解析の成分と予算によらず、Scope の一段は区間解析の成分と予算を変えない。 -/
theorem Analyses.stepScope_separate {RF : Type} (T : ScopeTable Release.Val) (L : Limits) (a : Analyses RF)
    (r : List (Option RF)) (b : Benitoite.Interval.Budget.State) (s : Step) :
    (({ a with range := r, rangeBudget := b }).stepScope T L s).scope = (a.stepScope T L s).scope ∧
      (a.stepScope T L s).range = a.range ∧ (a.stepScope T L s).rangeBudget = a.rangeBudget := ⟨rfl, rfl, rfl⟩

/-- 区間解析の予算の計上は、Scope の局所解析の状態・予算・超過の理由を変えない。 -/
theorem Analyses.chargeRange_scope {RF : Type} (L : Benitoite.Interval.Budget.Limits) (a : Analyses RF)
    (op : Benitoite.Interval.Budget.Operation) : (a.chargeRange L op).scope = a.scope := rfl

/-- 区間解析の局所の事実を置き換えても、Scope の成分の必須の判定は変わらない（採用定義の補題の具体化）。 -/
theorem Analyses.localState_range_independent {RF : Type} (a : Analyses RF) (r : List (Option RF)) (i : Nat) :
    ({ a.toLocalState with range := r }).toScope.requiredIndex i = a.scope.state.requiredIndex i :=
  LocalState.requiredIndex_range_independent a.toLocalState r i

end Benitoite.Surface.ScopeState
