import Benitoite.Release.Refinement.Surface.ScopeState

/-!
# Scope の必須の判定の規則の表と健全性

採用定義 `Scope.Inference` の規則の表を、篩付きの型の核の値 `Refinement.Val` で具体化する
（設計書 01-12「Scope の局所解析の状態と規則の表」）。

- 事実と値の対応: 成功値は対象を保持する値（`Val.target?` が対象を返す値）であり、対象の種類が由来の種類に合い、
  対象が由来の添字の範囲に属する（`CheckedModels`）。`Result.Ok` の値は構成子の名前で読む（`okPayload`）。
  リテラルは同じ文字列の定数、整数の綴り（`intLitText`）は同じ整数の定数に対応する（`LitModels`）。
- 規則: 検査（`checkRule`）は、型検査器がリテラルから得た既知の範囲または未知を由来に持つ Result の事実を作る。
  射影と明示拡大（`projectRule`）は事実を作らず、引数の必須の判定の添字を具体化の範囲に選ぶ。
- 健全性: 検査の規則は、型検査器の既知の範囲が実行時の動的なパターンと同じであること（`CheckSpec.BoundSound`）と、
  δ の `Ok` の成功値が動的なパターンに属する対象を保持すること（`CheckSpec.Contract`）から健全である
  （`checkRule_sound`）。六つの項目の健全性から表の健全性が従う（`Rules.lookup_sound`）。

文字列のパターン・対象の解析は引数に取る。本番の δ と解析器への具体化は `Surface.ScopeSound` で行う。
-/

namespace Benitoite.Release.Refinement.Surface.ScopeState

open Benitoite.Scope.Inference
open Benitoite.Scope.Domain (Range Target Kind)

/-! ## 本番の値と事実の対応 -/

/-- `Result.Ok` の値から成功値を取り出す。`ok` は Ok の構成子の名前である。 -/
def okPayload (ok : ConName) : Refinement.Val → Option Refinement.Val
  | .con c _ [w] => if c = ok then some w else none
  | _ => none

/-- 由来と成功値の対応。成功値は対象を保持する値で、対象の種類が由来の種類に合い、対象が由来の添字の範囲に
属する。未知の由来の添字は Top なので、所属は種類だけの条件になる。 -/
def CheckedModels (o : Origin) (v : Refinement.Val) : Prop :=
  match v.target? with
  | some t => t.kind = o.kind ∧ o.bound.index.Mem t
  | none => False

theorem checkedModels_iff {o : Origin} {v : Refinement.Val} :
    CheckedModels o v ↔ ∃ t, v.target? = some t ∧ t.kind = o.kind ∧ o.bound.index.Mem t := by
  unfold CheckedModels
  cases v.target? with
  | none => simp
  | some t => simp

/-- 一度保存した検査の Result の対応。`Ok` の値なら、その成功値が同じ由来の成功値に対応する。それ以外は任意。 -/
def ResultModels (ok : ConName) (o : Origin) (v : Refinement.Val) : Prop :=
  ∀ w, okPayload ok v = some w → CheckedModels o w

/-- 事実と、束縛番号 id の位置にある具体の値の対応。`pattern` は文字列のパターンの解析（引数）で読む。
成功値の事実はその番号にだけ有効である。 -/
def factModel (ok : ConName) (pattern : String → Option Range) :
    ScopeFact → Nat → Refinement.Val → Prop
  | .pattern r, _, v => ∃ s, v = .const (.string s) ∧ pattern s = some r
  | .result o, _, v => ResultModels ok o v
  | .checked o sid, id, v => sid = id ∧ CheckedModels o v

/-- リテラルの抽象の綴りと値の対応。整数の綴りは同じ整数の定数、それ以外は同じ文字列の定数である。 -/
def LitModels (s : String) (v : Refinement.Val) : Prop :=
  match litInt? s with
  | some i => ∃ n : Integer64Value, v = .const (.integer n) ∧ n.toInt = i
  | none => v = .const (.string s)

theorem litModels_of_none {s : String} {v : Refinement.Val} (h : litInt? s = none) :
    LitModels s v ↔ v = .const (.string s) := by
  simp only [LitModels, h]

/-- 本番の値の対応。 -/
def models (ok : ConName) (pattern : String → Option Range) : FactModels Refinement.Val :=
  ⟨LitModels, factModel ok pattern⟩

@[simp] theorem models_lit (ok : ConName) (pattern : String → Option Range) (s : String) (v : Refinement.Val) :
    (models ok pattern).lit s v ↔ LitModels s v := Iff.rfl

/-! ## 必須の判定の添字 -/

/-- 抽象の引数に付ける添字。同じ成功値の事実で、読んだ位置の束縛番号と成功値番号が一致するとき（再照合）だけ
既知の範囲、それ以外は Top。 -/
def argIndex : AbsArg → Range
  | .loc id (some (.checked o sid)) => if sid = id then o.bound.index else .top
  | _ => .top

/-! ## 検査の規則 -/

/-- 検査の項目の形。`pattern`・`target` は実行時の引数が表す動的なパターンの範囲と検査する対象、`bound` は
型検査器が抽象の引数から得る既知の範囲または未知である。 -/
structure CheckSpec where
  kind : Kind
  pattern : List Refinement.Val → Option Range
  target : List Refinement.Val → Option Target
  bound : List AbsArg → Bound

/-- 型検査器の既知の範囲は、実行時の動的なパターンが同じ範囲に解析されることを意味する。 -/
def CheckSpec.BoundSound (M : FactModels Refinement.Val) (C : CheckSpec) : Prop :=
  ∀ aargs vs r, ArgsModel M aargs vs → C.bound aargs = .known r → C.pattern vs = some r

/-- 検査の δ の契約。δ が `Ok` の値を返すなら、具体化はちょうど一つの範囲 r であり、成功値は検査した対象を
保持する値で、対象は種類を持ち、動的なパターンと r の両方に属する。 -/
def CheckSpec.Contract (ok : ConName) (C : CheckSpec)
    (run : List Range → List Refinement.Val → Option Refinement.Val) : Prop :=
  ∀ rs vs v w, run rs vs = some v → okPayload ok v = some w →
    ∃ r q t, rs = [r] ∧ C.pattern vs = some q ∧ C.target vs = some t ∧ w.target? = some t ∧
      t.kind = C.kind ∧ q.Mem t ∧ r.Mem t

/-- 検査の規則。具体化の範囲は型検査器が得た範囲の添字（未知は Top）、抽象の結果は同じ由来の Result の事実。 -/
def checkRule (C : CheckSpec) (run : List Range → List Refinement.Val → Option Refinement.Val) :
    ScopeRule Refinement.Val where
  index aargs := [(C.bound aargs).index]
  run := run
  transfer key aargs := some (.result ⟨key, C.kind, C.bound aargs⟩)

/-- 検査の規則の健全性。どの具体化の範囲で実行しても、`Ok` の成功値は同じ由来の成功値に対応する。 -/
theorem checkRule_sound {ok : ConName} {pattern : String → Option Range} {C : CheckSpec}
    {run : List Range → List Refinement.Val → Option Refinement.Val}
    (hb : C.BoundSound (models ok pattern)) (hc : C.Contract ok run) :
    RuleSound (models ok pattern) (checkRule C run) := by
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

/-- `Scope.checkPathIn(pattern, path)` の検査。`pattern`・`target` は実行時の検査が使う解析、`known` は型検査器が
文字列のリテラルのパターンから読む範囲である。局所の束縛を経た値は、射影の事実を持っていても既知にしない。 -/
def pathCheck (pattern : String → Option Range) (target : String → Option Target)
    (known : String → Option Range) : CheckSpec where
  kind := .path
  pattern
    | .const (.string ps) :: _ => pattern ps
    | _ => none
  target
    | [_, .const (.string raw)] => target raw
    | _ => none
  bound
    | .lit s :: _ =>
      match litInt? s with
      | some _ => .unknown
      | none =>
        match known s with
        | some r => .known r
        | none => .unknown
    | _ => .unknown

/-- 型検査器の読む範囲が実行時の解析の結果に含まれるなら、パスの検査の既知の範囲は健全である。 -/
theorem pathCheck_boundSound (ok : ConName) (facts : String → Option Range)
    {pattern : String → Option Range} {target : String → Option Target} {known : String → Option Range}
    (hk : ∀ s r, known s = some r → pattern s = some r) :
    (pathCheck pattern target known).BoundSound (models ok facts) := by
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
      · next r' hr => cases hb; exact hk _ _ hr
      · cases hb
  | .loc _ _ :: _, _, hb => simp [pathCheck] at hb
  | .value _ :: _, _, hb => simp [pathCheck] at hb
  | .unknown :: _, _, hb => simp [pathCheck] at hb
  | [], _, hb => simp [pathCheck] at hb

/-- `Http.checkRequestIn(hostPattern, minimumPort, maximumPort, request)` の検査。ホストのパターンの文字列の解析と、
要求から実効の endpoint を得る処理は引数に取る。ポートは `Port.ofInt?` が内側の境界である。型検査器が抽象の引数
から得る範囲 `bound` は引数に取り、その健全性（`BoundSound`）を項目の条件にする。 -/
def requestCheck (hostPattern : String → Option Scope.Domain.HostPattern)
    (endpointOf : Refinement.Val → Option Scope.Domain.Endpoint) (bound : List AbsArg → Bound) : CheckSpec where
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

/-- `Http.checkRequestIn` の範囲の型検査器による読み取り。ホストのパターンが文字列のリテラルで、二つのポートが整数の
リテラルであり、実行時の検査と同じ変換で得たポートの区間が整形式（`PortRange.WF`。最小 ≤ 最大）のときだけ、既知の
エンドポイントの範囲にする。それ以外は未知（Top）。要求の値は読まない。整形式でない範囲は所属する対象を持たない
ので、既知にすると、届かない成功の側への任意の非 Top の注釈を被覆で受理してしまう（設計書 01-12「Scope の局所解析の
状態と規則の表」）。 -/
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

/-- リテラルによる読み取りは、型検査器の読むホストのパターンが実行時の解析の結果に含まれるなら健全である。既知の
範囲は、実行時の引数が表す動的なパターンと同じである。 -/
theorem requestLitBound_boundSound (ok : ConName) (facts : String → Option Range)
    {hostPattern known : String → Option Scope.Domain.HostPattern}
    (endpointOf : Refinement.Val → Option Scope.Domain.Endpoint)
    (hk : ∀ s h, known s = some h → hostPattern s = some h) :
    (requestCheck hostPattern endpointOf (requestLitBound known)).BoundSound (models ok facts) := by
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
          cases eh : known hs with
          | none => simp only [eh, reduceCtorEq] at hb
          | some h =>
            simp only [hk _ _ eh]
            cases el : Scope.Domain.Port.ofInt? n1.toInt <;>
              cases eu : Scope.Domain.Port.ofInt? n2.toInt <;> simp only [eh, el, eu, reduceCtorEq] at hb ⊢
            -- 整形式の区間だけが既知になる。未知の場合は `hb` が偽である。
            split at hb
            · cases hb; rfl
            · cases hb
  | [], _, hb => simp [requestCheck, requestLitBound] at hb

/-! ## 射影と拡大の規則 -/

/-- 事実を作らない規則。対象の射影（`Scope.pathInValue`・`Http.requestInValue`）と明示拡大（`Scope.widenPathIn`・
`Http.widenRequestIn`）に使う。型検査器が抽象の引数から選ぶ具体化の範囲は引数の添字（必須の判定と同じ再照合）
であり、明示拡大の行き先は戻り値の注釈から決める（表層の型付け）。 -/
def projectRule (run : List Range → List Refinement.Val → Option Refinement.Val) : ScopeRule Refinement.Val where
  index
    | [a] => [argIndex a]
    | _ => [.top]
  run := run
  transfer _ _ := none

theorem projectRule_sound (M : FactModels Refinement.Val)
    (run : List Range → List Refinement.Val → Option Refinement.Val) : RuleSound M (projectRule run) := by
  intro _ _ _ _ _ _ _ _ htr
  cases htr

/-! ## 規則の表 -/

/-- 規則を持つ標準の宣言の名前。 -/
def checkPathName : String := "Scope.checkPathIn"
def checkRequestName : String := "Http.checkRequestIn"
def pathValueName : String := "Scope.pathInValue"
def requestValueName : String := "Http.requestInValue"
def widenPathName : String := "Scope.widenPathIn"
def widenRequestName : String := "Http.widenRequestIn"

/-- 検査・射影・拡大の六つの項目。 -/
structure Rules where
  checkPath : ScopeRule Refinement.Val
  checkRequest : ScopeRule Refinement.Val
  pathValue : ScopeRule Refinement.Val
  requestValue : ScopeRule Refinement.Val
  widenPath : ScopeRule Refinement.Val
  widenRequest : ScopeRule Refinement.Val

/-- 宣言の名前から項目を引く。六つの名前にない宣言には規則がない。 -/
def Rules.lookup (R : Rules) (d : String) : Option (ScopeRule Refinement.Val) :=
  if d = checkPathName then some R.checkPath
  else if d = checkRequestName then some R.checkRequest
  else if d = pathValueName then some R.pathValue
  else if d = requestValueName then some R.requestValue
  else if d = widenPathName then some R.widenPath
  else if d = widenRequestName then some R.widenRequest
  else none

/-- 六つの項目がどれも健全であること。 -/
def Rules.Sound (M : FactModels Refinement.Val) (R : Rules) : Prop :=
  RuleSound M R.checkPath ∧ RuleSound M R.checkRequest ∧ RuleSound M R.pathValue ∧
    RuleSound M R.requestValue ∧ RuleSound M R.widenPath ∧ RuleSound M R.widenRequest

/-- 項目ごとの健全性から、出現の解決によらず表の健全性が従う。 -/
theorem Rules.lookup_sound {M : FactModels Refinement.Val} {R : Rules} (hR : R.Sound M)
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
  · rw [ite_eq_right e1, ite_eq_right e2, ite_eq_right e3, ite_eq_right e4, ite_eq_left e5] at h; cases h; exact h5
  by_cases e6 : d = widenRequestName
  · rw [ite_eq_right e1, ite_eq_right e2, ite_eq_right e3, ite_eq_right e4, ite_eq_right e5, ite_eq_left e6] at h; cases h; exact h6
  rw [ite_eq_right e1, ite_eq_right e2, ite_eq_right e3, ite_eq_right e4, ite_eq_right e5, ite_eq_right e6] at h
  cases h

end Benitoite.Release.Refinement.Surface.ScopeState
