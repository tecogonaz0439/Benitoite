import Benitoite.Interval.Eval

/-!
# 閉じた対象入力の実行可能な評価

到達した未知の式は評価不能とし、任意の正常値や失敗へ決めない。
値・失敗・return と trace に評価導出を添え、実行比較の入力を限定する
（設計書 01-12「区間解析の閉じた対象入力の評価」）。
-/
namespace Benitoite.Interval

open Benitoite.Release Benitoite.Surface

/-- 計算で得た結果と、その結果に対応する対象構文の評価導出。 -/
structure ClosedRun (relation : EvalOutcome → EvalTrace → Prop) where
  outcome : EvalOutcome
  trace : EvalTrace
  sound : relation outcome trace

namespace ClosedRun

/-- 正常値だけ次へ渡す。失敗と return は元の順序で伝播する。 -/
def bind {P Q : EvalOutcome → EvalTrace → Prop} (run : ClosedRun P) (priorTrace : EvalTrace)
    (next : ∀ value trace, P (.normal value) trace → Option (ClosedRun Q))
    (abrupt : ∀ outcome trace, P outcome trace → outcome.Abrupt → Q outcome (priorTrace ++ trace)) :
    Option (ClosedRun Q) :=
  match run with
  | ⟨.normal value, trace, proof⟩ => next value trace proof
  | ⟨.failed reason, trace, proof⟩ =>
      some ⟨.failed reason, priorTrace ++ trace, abrupt _ _ proof trivial⟩
  | ⟨.returned value, trace, proof⟩ =>
      some ⟨.returned value, priorTrace ++ trace, abrupt _ _ proof trivial⟩

/-- 子の結果を変換し、前に評価した子の trace を順序どおり連結する。 -/
def map {P Q : EvalOutcome → EvalTrace → Prop} (run : ClosedRun P)
    (out : EvalOutcome → EvalOutcome) (events : EvalTrace → EvalTrace)
    (proof : ∀ outcome trace, P outcome trace → Q (out outcome) (events trace)) :
    ClosedRun Q := ⟨out run.outcome, events run.trace, proof _ _ run.sound⟩

end ClosedRun

namespace ClosedEval

mutual
/-- 基本型・不透明型・リスト型・データ型の一致を計算する。
関数型の効果の外延的等号を決定する手続きは要求しない。 -/
def sameType : (a b : Ty) → Option (PLift (a = b))
  | .base a, .base b => if same : a = b then some ⟨by subst b; rfl⟩ else none
  | .opaque a ra, .opaque b rb =>
      if same : a = b ∧ ra = rb then some ⟨by obtain ⟨rfl, rfl⟩ := same; rfl⟩ else none
  | .list a, .list b => do
      let ⟨element⟩ ← sameType a b
      some ⟨by subst b; rfl⟩
  | .data a xs, .data b ys => do
      if same : a = b then
        let ⟨types⟩ ← sameTypes xs ys
        some ⟨by subst b; subst ys; rfl⟩
      else none
  | _, _ => none
/-- 型引数も順序と個数を保って照合する。 -/
def sameTypes : (a b : List Ty) → Option (PLift (a = b))
  | [], [] => some ⟨rfl⟩
  | a :: xs, b :: ys => do
      let ⟨head⟩ ← sameType a b
      let ⟨tail⟩ ← sameTypes xs ys
      some ⟨by subst b; subst ys; rfl⟩
  | _, _ => none
end

-- 捨てる式と return のオペランドには期待型が書かれていない。
-- 構文から得た候補を使うが、実際の導出は expr が別に構築する。
mutual
/-- 閉じた対象の型候補。型検査器の代用にはしない。 -/
def typeOf (standards : List StandardBinding) : Nat → List (Option Ty) → Expr → Option Ty
  | 0, _, _ => none
  | n+1, locals, source =>
    match source with
    | .local i => (locals[i]?).join
    | .literal (.integer _) | .negInt _ => some (.base .integer)
    | .literal (.integer8 _) | .negInteger8 _ => some (.base .integer8)
    | .literal (.integer16 _) | .negInteger16 _ => some (.base .integer16)
    | .literal (.integer32 _) | .negInteger32 _ => some (.base .integer32)
    | .literal (.unsignedInteger16 _) => some (.base .unsignedInteger16)
    | .literal (.unsignedInteger32 _) => some (.base .unsignedInteger32)
    | .literal (.unsignedInteger64 _) => some (.base .unsignedInteger64)
    | .call callee _ _ _ => do
        let declaration ← standardCallHead callee
        (standards.find? (fun binding => binding.declaration == declaration)).map
          (fun binding => binding.rule.resultType)
    | .neg type _ => match IntKind.ofType type with
        | some kind => if kind.min < 0 then some type else none
        | none => none
    | .literal (.boolean _) | .not _ | .and _ _ | .or _ _ => some (.base .boolean)
    | .unit | .ifOnly _ _ => some (.base .unit)
    | .constE t _ | .returnE t _ | .matchE t _ _ => some t
    | .paren e => typeOf standards n locals e
    | .block b | .ite _ b _ | .elseIf _ b _ => blockType standards n locals b
    | .binary op t _ _ =>
        if (Comparison.ofBinOp op).isSome then some (.base .boolean) else some t
    | _ => none
/-- Block の型候補は束縛の型と専用位置を区別する。 -/
def blockType (standards : List StandardBinding) : Nat → List (Option Ty) → Block → Option Ty
  | 0, _, _ => none
  | n+1, locals, body =>
    match body with
    | .empty | .lastBind .. | .lastDiscard .. | .lastPat .. => some (.base .unit)
    | .last e => typeOf standards n locals e
    | .bind _ t _ rest => blockType standards n (some t :: locals) rest
    | .builderBind _ rest => blockType standards n (none :: locals) rest
    | .bindPat _ pat t _ rest => blockType standards n (List.replicate pat.binders (some t) ++ locals) rest
    | .discard _ rest | .seq _ rest => blockType standards n locals rest
end

/-- 実値から型候補の環境を作る。専用 builder 位置は値なしのまま残す。 -/
def localTypes (env : ConcreteEnv) : List (Option Ty) :=
  env.locals.map (Option.map ConcreteValue.type)

/-- 対象の原子的な具体値だけを、既存のパターン照合へ渡す。 -/
def patternValue : ConcreteValue → Option Val
  | .integer n => some (.const (.integer n))
  | .integer8 n => some (integerPatternValue .integer8 n)
  | .integer16 n => some (integerPatternValue .integer16 n)
  | .integer32 n => some (integerPatternValue .integer32 n)
  | .unsignedInteger16 n => some (integerPatternValue .unsignedInteger16 n)
  | .unsignedInteger32 n => some (integerPatternValue .unsignedInteger32 n)
  | .unsignedInteger64 n => some (integerPatternValue .unsignedInteger64 n)
  | .boolean b => some (.const (.boolean b))
  | .unit => some (.const .unit)
  | _ => none

/-- 束縛数0のパターンは局所位置を増やさない。 -/
theorem emptyLocals (pattern : Pattern) (value : ConcreteValue)
    (empty : pattern.binders = 0) : PatternLocals pattern value [] := by
  cases pattern <;> simp_all [PatternLocals, Pattern.binders, Pattern.toCore, Release.Pat.binders]

/-- 実際に照合した変数か、束縛のない成功パターンだけから値を得る。 -/
def bindings (pattern : Pattern) (value : ConcreteValue) :
    Option { values : List ConcreteValue // PatternLocals pattern value values } :=
  match pattern with
  | .var => some ⟨[value], rfl⟩
  | .wild => some ⟨[], rfl⟩
  | pattern => do
      let core ← patternValue value
      let _ ← pattern.toCore.matchVal core
      if empty : pattern.binders = 0 then some ⟨[], emptyLocals pattern value empty⟩ else none

/-- 整数の選択肢に共通の束縛数を与えた、最初の照合成功。 -/
def Selection (arity : Nat) (alts : List Alternative) (value : Integer64Value)
    (selected : List ConcreteValue) : Prop :=
  ∃ before alt after raw matched,
    alts = before ++ alt :: after ∧
    (∀ prior ∈ before, prior.pat.toCore.matchVal (.const (.integer value)) = none) ∧
    alt.pat.toCore.matchVal (.const (.integer value)) = some matched ∧
    PatternLocals alt.pat (.integer value) raw.reverse ∧
    selectSlots raw alt.slots = some selected ∧ alt.slots.length = arity

/-- 照合失敗は次の腕へ進めるが、未対応は照合失敗と区別する。 -/
inductive SelectionResult (arity : Nat) (alts : List Alternative) (value : Integer64Value) where
  | miss (proof : ∀ alt ∈ alts, alt.pat.toCore.matchVal (.const (.integer value)) = none)
  | hit (selected : List ConcreteValue) (proof : Selection arity alts value selected)

/-- 選択肢をソース順に調べ、最初の成功の slots と共通束縛数を検査する。 -/
def selectInteger (arity : Nat) (value : Integer64Value) :
    (alts : List Alternative) → Option (SelectionResult arity alts value)
  | [] => some (.miss (by simp))
  | alt :: rest => do
      match matched : alt.pat.toCore.matchVal (.const (.integer value)) with
      | none =>
          match ← selectInteger arity value rest with
          | .miss proof => some (.miss (by
              intro prior member
              rcases List.mem_cons.mp member with rfl | member
              · exact matched
              · exact proof prior member))
          | .hit selected proof =>
              some (.hit selected (by
                obtain ⟨before, chosen, after, raw, vals, eq, misses, hit, bindings, slots, count⟩ := proof
                refine ⟨alt :: before, chosen, after, raw, vals, ?_, ?_, hit, bindings, slots, count⟩
                · simp [eq]
                · intro prior member
                  rcases List.mem_cons.mp member with rfl | member
                  · exact matched
                  · exact misses prior member))
      | some vals =>
          let raw ← bindings alt.pat (.integer value)
          match slots : selectSlots raw.val.reverse alt.slots with
          | none => none
          | some selected =>
            if count : alt.slots.length = arity then
              some (.hit selected ⟨[], alt, rest, raw.val.reverse, vals,
                rfl, by simp, matched, by simpa using raw.property, slots, count⟩)
            else none

/-- 幅付き整数に認める変数とワイルドカードの位置を作る。 -/
def widthBindings (pattern : Pattern) (value : ConcreteValue) :
    Option { values : List ConcreteValue // PatternLocals pattern value values } :=
  match pattern with
  | .var => some ⟨[value], rfl⟩
  | .wild => some ⟨[], rfl⟩
  | _ => none

/-- 整数の選択肢に共通の束縛数を与えた、最初の照合成功。 -/
def WidthSelection (arity : Nat) (alts : List Alternative) (kind : IntKind) (value : IntegerValue kind)
    (selected : List ConcreteValue) : Prop :=
  ∃ before alt after raw matched,
    alts = before ++ alt :: after ∧
    (∀ prior ∈ before, widthPatternMatch prior.pat kind value = none) ∧
    widthPatternMatch alt.pat kind value = some matched ∧
    PatternLocals alt.pat (.ofInteger kind value) raw.reverse ∧
    selectSlots raw alt.slots = some selected ∧ alt.slots.length = arity

/-- 照合失敗は次の腕へ進めるが、未対応は照合失敗と区別する。 -/
inductive WidthSelectionResult (arity : Nat) (alts : List Alternative) (kind : IntKind) (value : IntegerValue kind) where
  | miss (proof : ∀ alt ∈ alts, widthPatternMatch alt.pat kind value = none)
  | hit (selected : List ConcreteValue) (proof : WidthSelection arity alts kind value selected)

/-- 選択肢をソース順に調べ、最初の成功の slots と共通束縛数を検査する。 -/
def selectWidth (arity : Nat) (kind : IntKind) (value : IntegerValue kind) :
    (alts : List Alternative) → Option (WidthSelectionResult arity alts kind value)
  | [] => some (.miss (by simp))
  | alt :: rest => do
      match matched : widthPatternMatch alt.pat kind value with
      | none =>
          match ← selectWidth arity kind value rest with
          | .miss proof => some (.miss (by
              intro prior member
              rcases List.mem_cons.mp member with rfl | member
              · exact matched
              · exact proof prior member))
          | .hit selected proof =>
              some (.hit selected (by
                obtain ⟨before, chosen, after, raw, vals, eq, misses, hit, bindings, slots, count⟩ := proof
                refine ⟨alt :: before, chosen, after, raw, vals, ?_, ?_, hit, bindings, slots, count⟩
                · simp [eq]
                · intro prior member
                  rcases List.mem_cons.mp member with rfl | member
                  · exact matched
                  · exact misses prior member))
      | some vals =>
          let raw ← widthBindings alt.pat (.ofInteger kind value)
          match slots : selectSlots raw.val.reverse alt.slots with
          | none => none
          | some selected =>
            if count : alt.slots.length = arity then
              some (.hit selected ⟨[], alt, rest, raw.val.reverse, vals,
                rfl, by simp, matched, by simpa using raw.property, slots, count⟩)
            else none

/-- 現 profile で決定的な具体規則を持つ整数二項演算。 -/
inductive Binary where
  | add | sub | mul | intDiv | mod | compare (op : Comparison)

/-- 二項演算の表層での名前。 -/
def Binary.op : Binary → BinOp
  | .add => .add | .sub => .sub | .mul => .mul
  | .intDiv => .intDiv | .mod => .mod | .compare op => op.binOp

/-- 比較だけ Boolean を返す。 -/
def Binary.type : Binary → Ty
  | .compare _ => .base .boolean | _ => .base .integer

/-- 算術の値と失敗を、既存の具体的な検査で求める。 -/
def Binary.apply : Binary → Integer64Value → Integer64Value → OperationResult
  | .add => checkedAdd | .sub => checkedSub | .mul => checkedMul
  | .intDiv => checkedDivMod .intDiv
  | .mod => checkedDivMod .mod | .compare op => checkedCompare op

/-- 正常な二引数から演算自身の事象を作る。 -/
theorem Binary.normal (op : Binary) {env key left right a b lt rt}
    (el : EvalPartial env ⟨left, .base .integer, childKey key []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩ (.normal (.integer b)) rt) :
    EvalPartial env ⟨.binary op.op (.base .integer) left right, op.type, key⟩
      (op.apply a b).outcome
      (lt ++ rt ++ [⟨key, .binary op.op (.base .integer), [.integer a, .integer b], op.apply a b⟩]) := by
  cases op with
  | add => exact .add _ _ _ _ _ _ _ _ el er
  | sub => exact .sub _ _ _ _ _ _ _ _ el er
  | mul => exact .mul _ _ _ _ _ _ _ _ el er
  | intDiv => exact .divMod _ _ _ _ _ _ _ _ _ (Or.inl rfl) el er
  | mod => exact .divMod _ _ _ _ _ _ _ _ _ (Or.inr rfl) el er
  | compare op => exact .compare _ _ op _ _ _ _ _ _ el er

/-- 左辺の異常終了では右辺も演算自身も実行しない。 -/
theorem Binary.leftAbrupt (op : Binary) {env key left right outcome trace}
    (el : EvalPartial env ⟨left, .base .integer, childKey key []⟩ outcome trace)
    (abrupt : outcome.Abrupt) :
    EvalPartial env ⟨.binary op.op (.base .integer) left right, op.type, key⟩ outcome trace := by
  cases op with
  | add => exact .addLeftAbrupt _ _ _ _ _ _ el abrupt
  | sub => exact .subLeftAbrupt _ _ _ _ _ _ el abrupt
  | mul => exact .mulLeftAbrupt _ _ _ _ _ _ el abrupt
  | intDiv => exact .divModLeftAbrupt _ _ _ _ _ _ _ (Or.inl rfl) el abrupt
  | mod => exact .divModLeftAbrupt _ _ _ _ _ _ _ (Or.inr rfl) el abrupt
  | compare op => exact .compareLeftAbrupt _ _ op _ _ _ _ el abrupt

/-- 右辺の異常終了では左辺、右辺の事象だけを順につなぐ。 -/
theorem Binary.rightAbrupt (op : Binary) {env key left right a outcome lt rt}
    (el : EvalPartial env ⟨left, .base .integer, childKey key []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial env ⟨right, .base .integer, childKey key [left]⟩ outcome rt)
    (abrupt : outcome.Abrupt) :
    EvalPartial env ⟨.binary op.op (.base .integer) left right, op.type, key⟩ outcome (lt ++ rt) := by
  cases op with
  | add => exact .addRightAbrupt _ _ _ _ _ _ _ _ el er abrupt
  | sub => exact .subRightAbrupt _ _ _ _ _ _ _ _ el er abrupt
  | mul => exact .mulRightAbrupt _ _ _ _ _ _ _ _ el er abrupt
  | intDiv => exact .divModRightAbrupt _ _ _ _ _ _ _ _ _ (Or.inl rfl) el er abrupt
  | mod => exact .divModRightAbrupt _ _ _ _ _ _ _ _ _ (Or.inr rfl) el er abrupt
  | compare op => exact .compareRightAbrupt _ _ op _ _ _ _ _ _ el er abrupt

/-- 右辺を遅延して受け取り、左辺が正常な整数のときだけ評価する。 -/
def binary (op : Binary) (env : ConcreteEnv) (key : OperationKey) (left right : Expr)
    (el : Option (ClosedRun (EvalPartial env ⟨left, .base .integer, childKey key []⟩)))
    (er : Unit → Option (ClosedRun (EvalPartial env ⟨right, .base .integer, childKey key [left]⟩))) :
    Option (ClosedRun (EvalPartial env ⟨.binary op.op (.base .integer) left right, op.type, key⟩)) := do
  let l ← el
  l.bind [] (fun value lt hl => do
    match value, hl with
    | .integer _a, hl =>
      let r ← er ()
      r.bind lt (fun value _rt hr =>
        match value, hr with
        | .integer _b, hr => some ⟨_, _, op.normal hl hr⟩
        | _, _ => none)
        (fun _outcome _rt hr abrupt => op.rightAbrupt hl hr abrupt)
    | _, _ => none)
    (fun _outcome _trace hl abrupt => op.leftAbrupt hl abrupt)

/-- 値の幅が要求した種類と一致した場合だけ、その有界整数を得る。 -/
def integerValue : (kind : IntKind) → (value : ConcreteValue) →
    Option { integer : IntegerValue kind // value = .ofInteger kind integer }
  | .integer64, .integer n => some ⟨n, rfl⟩
  | .integer8, .integer8 n => some ⟨n, rfl⟩
  | .integer16, .integer16 n => some ⟨n, rfl⟩
  | .integer32, .integer32 n => some ⟨n, rfl⟩
  | .unsignedInteger16, .unsignedInteger16 n => some ⟨n, rfl⟩
  | .unsignedInteger32, .unsignedInteger32 n => some ⟨n, rfl⟩
  | .unsignedInteger64, .unsignedInteger64 n => some ⟨n, rfl⟩
  | _, _ => none

/-- 左辺が正常な同幅整数のときだけ右辺を評価し、事象を一度作る。 -/
def widthBinary (kind : IntKind) (op : WidthBinary) (not64 : kind ≠ .integer64)
    (env : ConcreteEnv) (key : OperationKey) (left right : Expr)
    (el : Option (ClosedRun (EvalPartial env ⟨left, kind.type, childKey key []⟩)))
    (er : Unit → Option (ClosedRun (EvalPartial env ⟨right, kind.type, childKey key [left]⟩))) :
    Option (ClosedRun (EvalPartial env ⟨.binary op.op kind.type left right, op.type kind, key⟩)) := do
  let l ← el
  l.bind [] (fun value lt hl => do
    let ⟨a, ha⟩ ← integerValue kind value
    have hl' : EvalPartial env ⟨left, kind.type, childKey key []⟩
        (.normal (.ofInteger kind a)) lt := by simpa only [ha] using hl
    let r ← er ()
    r.bind lt (fun value rt hr => do
      let ⟨b, hb⟩ ← integerValue kind value
      have hr' : EvalPartial env ⟨right, kind.type, childKey key [left]⟩
          (.normal (.ofInteger kind b)) rt := by simpa only [hb] using hr
      some ⟨_, _, .widthBinary env key kind op left right a b lt rt not64 hl' hr'⟩)
      (fun outcome rt hr abrupt =>
        .widthBinaryRightAbrupt env key kind op left right a outcome lt rt not64 hl' hr abrupt))
    (fun outcome trace hl abrupt =>
      .widthBinaryLeftAbrupt env key kind op left right outcome trace not64 hl abrupt)

/-- 負号は子が正常な同幅整数のときだけ検査する。 -/
def widthNeg (kind : IntKind) (not64 : kind ≠ .integer64) (signed : kind.min < 0)
    (env : ConcreteEnv) (key : OperationKey) (source : Expr)
    (child : ClosedRun (EvalPartial env ⟨source, kind.type, childKey key []⟩)) :
    Option (ClosedRun (EvalPartial env ⟨.neg kind.type source, kind.type, key⟩)) :=
  child.bind [] (fun value trace proof => do
    let ⟨integer, same⟩ ← integerValue kind value
    have proof' : EvalPartial env ⟨source, kind.type, childKey key []⟩
        (.normal (.ofInteger kind integer)) trace := by simpa only [same] using proof
    some ⟨_, _, .widthNeg env key kind source integer trace not64 signed proof'⟩)
    (fun outcome trace proof abrupt =>
      .widthNegAbrupt env key kind source outcome trace not64 signed proof abrupt)

/-- 標準規則を計算した結果にも評価導出を付ける。 -/
structure StandardRun (rule : StandardRule) (key : OperationKey) (arguments : List ConcreteValue) where
  result : OperationResult
  sound : EvalStandard rule key arguments result

/-- 固定域の正常引数には、規則が許す他の失敗を選ぶ。
正常値を任意に作らず、実 VM の成功値の比較には使わない。 -/
def standard : (rule : StandardRule) → (key : OperationKey) → (arguments : List ConcreteValue) →
    Option (StandardRun rule key arguments)
  | .rangeCheck names, key, [.integer lo, .integer hi, .integer value] =>
      some ⟨rangeCheck names key lo hi value, .rangeCheck names key lo hi value⟩
  | .rangeValue record, key, [input] =>
      match stored : rangeStoredValue record input with
      | some value => some ⟨.normal (.integer value), .rangeValue record key input value stored⟩
      | none => none
  | .fixedDomain position lo hi result, key, args =>
      match found : args[position]? with
      | some (.integer value) =>
          if inside : lo ≤ value.toInt ∧ value.toInt ≤ hi then
            some ⟨.rejected .unknown,
              .domainOtherFailure position lo hi result key args value found inside⟩
          else some ⟨.rejected .outsideDomain,
              .domainRejected position lo hi result key args value found inside⟩
      | _ => none
  | _, _, _ => none

/-- 具体的な Result の同じ中身と、その見方の導出。 -/
structure ResultRun (names : RangeNames) (value : ConcreteValue) where
  tag : ConName
  payload : ConcreteValue
  sound : names.ResultView value tag payload

/-- other の見方は非決定的なので、閉じた評価器では選ばない。 -/
def resultView (names : RangeNames) : (value : ConcreteValue) → Option (ResultRun names value)
  | .con result [.data owner [], .data error []] tag [payload] => do
      if hr : result = names.result then
        if ho : owner = names.owner then
          if he : error = names.error then
            if hok : tag = names.ok then
              let ⟨typed⟩ ← sameType payload.type (.data names.owner [])
              some ⟨names.ok, payload, by
                subst result; subst owner; subst error; subst tag
                exact .ok payload typed⟩
            else if herr : tag = names.err then
              let ⟨typed⟩ ← sameType payload.type (.data names.error [])
              some ⟨names.err, payload, by
                subst result; subst owner; subst error; subst tag
                exact .error payload typed⟩
            else none
          else none
        else none
      else none
  | _ => none

/-- 選択肢が照合しなかったことと、未対応で評価できないことを区別する。 -/
inductive ResultSelectionRun (names : RangeNames) (value : ConcreteValue) (tag : ConName)
    (payload : ConcreteValue) (arity : Nat) (alts : List Alternative) where
  | miss (proof : ∀ alt ∈ alts, resultPatternMatch names value tag payload alt.pat = none)
  | hit (selected : List ConcreteValue)
      (proof : ∃ before alt after raw,
        alts = before ++ alt :: after ∧
        (∀ prior ∈ before, resultPatternMatch names value tag payload prior.pat = none) ∧
        resultPatternMatch names value tag payload alt.pat = some raw ∧
        selectSlots raw alt.slots = some selected ∧ alt.slots.length = arity)

/-- 最初に照合した選択肢を使い、slots が不正なら後の選択肢へ逃げない。 -/
def selectResult (names : RangeNames) (value : ConcreteValue) (tag : ConName)
    (payload : ConcreteValue) (arity : Nat) : (alts : List Alternative) →
    Option (ResultSelectionRun names value tag payload arity alts)
  | [] => some (.miss (by simp))
  | alt :: rest =>
      match matched : resultPatternMatch names value tag payload alt.pat with
      | some raw => do
          match selected : selectSlots raw alt.slots with
          | none => none
          | some slots =>
              if count : alt.slots.length = arity then
                some (.hit slots ⟨[], alt, rest, raw, rfl, by simp, matched, selected, count⟩)
              else none
      | none => do
          let tail ← selectResult names value tag payload arity rest
          match tail with
          | .miss miss => some (.miss (by
              intro prior member
              rcases List.mem_cons.mp member with same | member
              · subst prior; exact matched
              · exact miss prior member))
          | .hit selected proof =>
              some (.hit selected (by
                obtain ⟨before, picked, after, raw, equal, missed, hit, ordered, count⟩ := proof
                refine ⟨alt :: before, picked, after, raw, ?_, ?_, hit, ordered, count⟩
                · simp [equal]
                · intro prior member
                  rcases List.mem_cons.mp member with rfl | member
                  · exact matched
                  · exact missed prior member))

/-- 引数列の結果と導出。中断の場合は Abrupt の証拠も保持する。 -/
inductive ArgumentsRun (env : ConcreteEnv) (key : OperationKey) (sources : List Expr) (type : Ty) where
  | normal (values : List ConcreteValue) (trace : EvalTrace)
      (sound : EvalArguments env key sources type (.normal values) trace)
  | abrupt (outcome : EvalOutcome) (trace : EvalTrace)
      (sound : EvalArguments env key sources type (.abrupt outcome) trace)
      (abrupt : outcome.Abrupt)

/-- 契約の位置ごとに異なる型を持つ、標準 call の引数の結果と導出。 -/
inductive TypedArgumentsRun (env : ConcreteEnv) (key : OperationKey) (sources : List Expr) (types : List Ty) where
  | normal (values : List ConcreteValue) (trace : EvalTrace)
      (sound : EvalTypedArguments env key sources types (.normal values) trace)
  | abrupt (outcome : EvalOutcome) (trace : EvalTrace)
      (sound : EvalTypedArguments env key sources types (.abrupt outcome) trace)
      (abrupt : outcome.Abrupt)

mutual
/-- 深さを上限にし、到達した既知の式だけを評価する。 -/
def expr : (fuel : Nat) → (env : ConcreteEnv) → (key : OperationKey) →
    (source : Expr) → (type : Ty) → Option (ClosedRun (EvalPartial env ⟨source, type, key⟩))
  | 0, _, _, _, _ => none
  | n+1, env, key, .literal (.integer value), .base .integer =>
      some ⟨_, [], .integer env key value⟩
  | n+1, env, key, .literal (.integer8 value), .base .integer8 =>
      if bounded : IntKind.min .integer8 ≤ (value : Int) ∧ (value : Int) ≤ IntKind.max .integer8 then
        some ⟨_, [], .integer8 env key value bounded⟩
      else none
  | n+1, env, key, .literal (.integer16 value), .base .integer16 =>
      if bounded : IntKind.min .integer16 ≤ (value : Int) ∧ (value : Int) ≤ IntKind.max .integer16 then
        some ⟨_, [], .integer16 env key value bounded⟩
      else none
  | n+1, env, key, .literal (.integer32 value), .base .integer32 =>
      if bounded : IntKind.min .integer32 ≤ (value : Int) ∧ (value : Int) ≤ IntKind.max .integer32 then
        some ⟨_, [], .integer32 env key value bounded⟩
      else none
  | n+1, env, key, .literal (.unsignedInteger16 value), .base .unsignedInteger16 =>
      if bounded : IntKind.min .unsignedInteger16 ≤ (value : Int) ∧ (value : Int) ≤ IntKind.max .unsignedInteger16 then
        some ⟨_, [], .unsignedInteger16 env key value bounded⟩
      else none
  | n+1, env, key, .literal (.unsignedInteger32 value), .base .unsignedInteger32 =>
      if bounded : IntKind.min .unsignedInteger32 ≤ (value : Int) ∧ (value : Int) ≤ IntKind.max .unsignedInteger32 then
        some ⟨_, [], .unsignedInteger32 env key value bounded⟩
      else none
  | n+1, env, key, .literal (.unsignedInteger64 value), .base .unsignedInteger64 =>
      if bounded : IntKind.min .unsignedInteger64 ≤ (value : Int) ∧ (value : Int) ≤ IntKind.max .unsignedInteger64 then
        some ⟨_, [], .unsignedInteger64 env key value bounded⟩
      else none
  | n+1, env, key, .negInteger8 value, .base .integer8 =>
      if bounded : IntKind.min .integer8 ≤ -(value : Int) ∧ -(value : Int) ≤ IntKind.max .integer8 then
        some ⟨_, [], .negInteger8 env key value bounded⟩
      else none
  | n+1, env, key, .negInteger16 value, .base .integer16 =>
      if bounded : IntKind.min .integer16 ≤ -(value : Int) ∧ -(value : Int) ≤ IntKind.max .integer16 then
        some ⟨_, [], .negInteger16 env key value bounded⟩
      else none
  | n+1, env, key, .negInteger32 value, .base .integer32 =>
      if bounded : IntKind.min .integer32 ≤ -(value : Int) ∧ -(value : Int) ≤ IntKind.max .integer32 then
        some ⟨_, [], .negInteger32 env key value bounded⟩
      else none
  | n+1, env, key, .literal (.boolean value), .base .boolean =>
      some ⟨_, [], .boolean env key value⟩
  | n+1, env, key, .negInt value, .base .integer => some ⟨_, [], .negInt env key value⟩
  | n+1, env, key, .unit, .base .unit => some ⟨_, [], .unit env key⟩
  | n+1, env, key, .local index, type => do
      match atIndex : env.locals[index]? with
      | some (some value) =>
          let ⟨typed⟩ ← sameType value.type type
          some ⟨.normal value, [], by subst type; exact .local env key index value atIndex⟩
      | _ => none
  | n+1, env, key, .paren source, type => do
      let result ← expr n env (childKey key []) source type
      some (result.map id id (fun _ _ proof => .paren env key source type _ _ proof))
  | n+1, env, key, .constE annotation source, type => do
      let ⟨same⟩ ← sameType annotation type
      let result ← expr n { env with locals := [] } (childKey key []) source type
      some (result.map id id (fun _ _ proof => by
        subst annotation; exact .constE env key source type _ _ proof))
  | n+1, env, key, .returnE annotation source, type => do
      let ⟨same⟩ ← sameType annotation type
      let sourceType ← typeOf env.standards n (localTypes env) source
      let result ← expr n env (childKey key []) source sourceType
      some (result.map returnOutcome id (fun _ _ proof => by
        subst annotation; exact .returnE env key type source sourceType _ _ proof))
  | n+1, env, key, .neg (.base .integer) source, .base .integer => do
      let result ← expr n env (childKey key []) source (.base .integer)
      result.bind [] (fun value trace proof =>
        match value, proof with
        | .integer value, proof => some ⟨_, _, .neg env key source value trace proof⟩
        | _, _ => none)
        (fun _ _ proof abrupt => .negAbrupt env key source _ _ proof abrupt)
  | n+1, env, key, .neg operandType source, type => do
      let kind ← IntKind.ofType operandType
      let ⟨sameOperand⟩ ← sameType kind.type operandType
      let ⟨sameResult⟩ ← sameType kind.type type
      if not64 : kind ≠ .integer64 then
        if signed : kind.min < 0 then
          let child ← expr n env (childKey key []) source kind.type
          let result ← widthNeg kind not64 signed env key source child
          some (by cases sameOperand; cases sameResult; exact result)
        else none
      else none
  | n+1, env, key, .block body, type => do
      let result ← block n env (childKey key []) body type
      some (result.map id id (fun _ _ proof => .block env key body type _ _ proof))
  | n+1, env, key, .binary op (.base .integer) left right, type => do
      let selected ← match op with
        | .add => some Binary.add | .sub => some Binary.sub | .mul => some Binary.mul
        | .intDiv => some Binary.intDiv | .mod => some Binary.mod
        | _ => (Comparison.ofBinOp op).map Binary.compare
      if sameOp : selected.op = op then
        let ⟨sameResultType⟩ ← sameType selected.type type
        let result ← binary selected env key left right
          (expr n env (childKey key []) left (.base .integer))
          (fun _ => expr n env (childKey key [left]) right (.base .integer))
        some (by simpa only [sameOp, sameResultType] using result)
      else none
  | n+1, env, key, .binary op operandType left right, type => do
      let kind ← IntKind.ofType operandType
      let ⟨sameOperand⟩ ← sameType kind.type operandType
      if not64 : kind ≠ .integer64 then
        let selected ← match op with
          | .add => some WidthBinary.add | .sub => some WidthBinary.sub | .mul => some WidthBinary.mul
          | .intDiv => some WidthBinary.intDiv | .mod => some WidthBinary.mod
          | _ => (Comparison.ofBinOp op).map WidthBinary.compare
        if sameOp : selected.op = op then
          let ⟨sameResult⟩ ← sameType (selected.type kind) type
          let result ← widthBinary kind selected not64 env key left right
            (expr n env (childKey key []) left kind.type)
            (fun _ => expr n env (childKey key [left]) right kind.type)
          some (by cases sameOp; cases sameOperand; cases sameResult; exact result)
        else none
      else none
  | n+1, env, key, .not source, .base .boolean => do
      let result ← expr n env (childKey key []) source (.base .boolean)
      result.bind [] (fun value trace proof =>
        match value, proof with
        | .boolean b, proof => some ⟨_, trace, .not env key source b trace proof⟩
        | _, _ => none)
        (fun _ _ proof abrupt => .notAbrupt env key source _ _ proof abrupt)
  | n+1, env, key, .and left right, .base .boolean => do
      let result ← expr n env (childKey key []) left (.base .boolean)
      result.bind [] (fun value lt hl => do
        match value, hl with
        | .boolean false, hl => some ⟨_, lt, .andShort env key left right lt hl⟩
        | .boolean true, hl =>
            let result ← expr n env (childKey key [left]) right (.base .boolean)
            some (result.map id (lt ++ ·)
              (fun _ _ hr => .andRight env key left right _ lt _ hl hr))
        | _, _ => none)
        (fun _ _ hl abrupt => .andAbrupt env key left right _ _ hl abrupt)
  | n+1, env, key, .or left right, .base .boolean => do
      let result ← expr n env (childKey key []) left (.base .boolean)
      result.bind [] (fun value lt hl => do
        match value, hl with
        | .boolean true, hl => some ⟨_, lt, .orShort env key left right lt hl⟩
        | .boolean false, hl =>
            let result ← expr n env (childKey key [left]) right (.base .boolean)
            some (result.map id (lt ++ ·)
              (fun _ _ hr => .orRight env key left right _ lt _ hl hr))
        | _, _ => none)
        (fun _ _ hl abrupt => .orAbrupt env key left right _ _ hl abrupt)
  | n+1, env, key, .ite cond yes no, type => do
      let result ← expr n env (childKey key []) cond (.base .boolean)
      result.bind [] (fun value ct hc => do
        match value, hc with
        | .boolean true, hc =>
            let result ← block n env (childKey key [cond]) yes type
            some (result.map id (ct ++ ·)
              (fun _ _ hb => .iteTrue env key cond yes no type _ ct _ hc hb))
        | .boolean false, hc =>
            let result ← block n env (childKey key (cond :: blockChildren yes)) no type
            some (result.map id (ct ++ ·)
              (fun _ _ hb => .iteFalse env key cond yes no type _ ct _ hc hb))
        | _, _ => none)
        (fun _ _ hc abrupt => .iteAbrupt env key cond yes no type _ _ hc abrupt)
  | n+1, env, key, .elseIf cond yes no, type => do
      let result ← expr n env (childKey key []) cond (.base .boolean)
      result.bind [] (fun value ct hc => do
        match value, hc with
        | .boolean true, hc =>
            let result ← block n env (childKey key [cond]) yes type
            some (result.map id (ct ++ ·)
              (fun _ _ hb => .elseIfTrue env key cond yes no type _ ct _ hc hb))
        | .boolean false, hc =>
            let result ← expr n env (childKey key (cond :: blockChildren yes)) no type
            some (result.map id (ct ++ ·)
              (fun _ _ hb => .elseIfFalse env key cond yes no type _ ct _ hc hb))
        | _, _ => none)
        (fun _ _ hc abrupt => .elseIfAbrupt env key cond yes no type _ _ hc abrupt)
  | n+1, env, key, .ifOnly cond yes, .base .unit => do
      let result ← expr n env (childKey key []) cond (.base .boolean)
      result.bind [] (fun value ct hc => do
        match value, hc with
        | .boolean true, hc =>
            let result ← block n env (childKey key [cond]) yes (.base .unit)
            some (result.map id (ct ++ ·)
              (fun _ _ hb => .ifOnlyTrue env key cond yes _ ct _ hc hb))
        | .boolean false, hc => some ⟨.normal .unit, ct, .ifOnlyFalse env key cond yes ct hc⟩
        | _, _ => none)
        (fun _ _ hc abrupt => .ifOnlyAbrupt env key cond yes _ _ hc abrupt)
  | n+1, env, key, .call callee labels positions sources, type => do
      match recognized : rangeCallBinding env ⟨.call callee labels positions sources, type, key⟩ with
      | none => none
      | some binding =>
          let evaluated ← typedArguments n env (childKey key [callee]) (exprsChildren sources)
            (binding.sourceTypes positions)
          match evaluated with
          | .normal values trace children => do
              match ordered : orderArguments positions values with
              | none => none
              | some args =>
                  let run ← standard binding.rule key args
                  if fixed : binding.rule.isFixed = true then
                    match run with
                    | ⟨.rejected reason, sound⟩ => some ⟨.failed reason,
                        trace ++ [⟨key, .standard binding, args, .rejected reason⟩],
                        .fixedCallFailed env key callee labels positions sources binding values args
                          reason type trace recognized fixed children ordered sound⟩
                    | _ => none
                  else
                    let ⟨typed⟩ ← sameType binding.rule.resultType type
                    some ⟨binding.rule.finish run.result,
                      trace ++ [⟨key, .standard binding, args, run.result⟩], by
                        subst type
                        exact .standardCall env key callee labels positions sources binding values args
                          run.result trace recognized children ordered run.sound⟩
          | .abrupt outcome trace children abrupt => do
              if fixed : binding.rule.isFixed = true then
                some ⟨outcome, trace, .fixedCallAbrupt env key callee labels positions sources binding
                  type outcome trace recognized fixed children abrupt⟩
              else
                let ⟨typed⟩ ← sameType binding.rule.resultType type
                some ⟨outcome, trace, by
                  subst type
                  exact .standardCallAbrupt env key callee labels positions sources binding outcome
                    trace recognized children abrupt⟩
  | n+1, env, key, .matchE annotation source arms, type => do
      let ⟨same⟩ ← sameType annotation type
      let sourceType ← typeOf env.standards n (localTypes env) source
      let result ← expr n env (childKey key []) source sourceType
      result.bind [] (fun value st hs => do
        match value, hs with
        | .integer value, hs =>
            -- 正常値の型だけから子の導出の型は変えない。
            let ⟨integerType⟩ ← sameType sourceType (.base .integer)
            let result ← armList n env (childKey key [source]) value arms type
            some (result.map id (st ++ ·) (fun _ _ ha => by
              subst annotation; subst sourceType
              exact .matchInteger env key source arms type value _ st _ hs ha))
        | value, hs => do
            match IntKind.ofType sourceType with
            | some kind =>
                if not64 : kind ≠ .integer64 then
                  let ⟨sameType⟩ ← sameType sourceType kind.type
                  let ⟨integer, sameValue⟩ ← integerValue kind value
                  let result ← widthArmList n env (childKey key [source]) kind integer arms type
                  some (result.map id (st ++ ·) (fun _ _ ha => by
                    subst annotation
                    have hs' : EvalPartial env ⟨source, kind.type, childKey key []⟩
                        (.normal (.ofInteger kind integer)) st := by
                      simpa only [sameType, sameValue] using hs
                    exact .matchWidth env key kind source arms type integer _ st _ not64 hs' ha))
                else none
            | none =>
                match recognized : rangeResultMatch env value arms with
                | none => none
                | some names =>
                    let view ← resultView names value
                    let result ← resultArmList n env (childKey key [source]) names value
                      view.tag view.payload arms type
                    some (result.map id (st ++ ·) (fun _ _ ha => by
                      subst annotation
                      exact .matchResult env key source arms type sourceType value names
                        view.tag view.payload _ st _ recognized view.sound hs ha)))
        (fun _ _ hs abrupt => by
          subst annotation
          exact .matchAbrupt env key source arms type sourceType _ _ hs abrupt)
  | _, _, _, _, _ => none

/-- 引数はソース順に一度ずつ評価し、中断後は残りを評価しない。 -/
def arguments : (fuel : Nat) → (env : ConcreteEnv) → (key : OperationKey) →
    (sources : List Expr) → (type : Ty) → Option (ArgumentsRun env key sources type)
  | 0, _, _, _, _ => none
  | _n+1, env, key, [], type => some (.normal [] [] (.nil env key type))
  | n+1, env, key, source :: rest, type => do
      let head ← expr n env key source type
      match head with
      | ⟨.normal value, ht, proof⟩ =>
          let tail ← arguments n env (advanceKey key (surfaceSize source)) rest type
          match tail with
          | .normal values rt tail =>
              some (.normal (value :: values) (ht ++ rt)
                (.cons env key source rest type value values ht rt proof tail))
          | .abrupt outcome rt tail abrupt =>
              some (.abrupt outcome (ht ++ rt)
                (.tailAbrupt env key source rest type value outcome ht rt proof tail) abrupt)
      | ⟨.failed reason, trace, proof⟩ =>
          some (.abrupt (.failed reason) trace
            (.headAbrupt env key source rest type _ trace proof trivial) trivial)
      | ⟨.returned value, trace, proof⟩ =>
          some (.abrupt (.returned value) trace
            (.headAbrupt env key source rest type _ trace proof trivial) trivial)

/-- ソース順の型列を使い、型や引数が欠ける入力から導出を作らない。 -/
def typedArguments : (fuel : Nat) → (env : ConcreteEnv) → (key : OperationKey) →
    (sources : List Expr) → (types : List Ty) → Option (TypedArgumentsRun env key sources types)
  | 0, _, _, _, _ => none
  | _n+1, env, key, [], [] => some (.normal [] [] (.nil env key))
  | n+1, env, key, source :: rest, type :: types => do
      let head ← expr n env key source type
      match head with
      | ⟨.normal value, ht, proof⟩ =>
          let tail ← typedArguments n env (advanceKey key (surfaceSize source)) rest types
          match tail with
          | .normal values rt tail =>
              some (.normal (value :: values) (ht ++ rt)
                (.cons env key source rest type types value values ht rt proof tail))
          | .abrupt outcome rt tail abrupt =>
              some (.abrupt outcome (ht ++ rt)
                (.tailAbrupt env key source rest type types value outcome ht rt proof tail) abrupt)
      | ⟨.failed reason, trace, proof⟩ =>
          some (.abrupt (.failed reason) trace
            (.headAbrupt env key source rest type types _ trace proof trivial) trivial)
      | ⟨.returned value, trace, proof⟩ =>
          some (.abrupt (.returned value) trace
            (.headAbrupt env key source rest type types _ trace proof trivial) trivial)
  | _, _, _, _, _ => none

/-- 全 Block 形をソース順に評価し、専用位置と通常位置を混同しない。 -/
def block : (fuel : Nat) → (env : ConcreteEnv) → (key : OperationKey) →
    (body : Block) → (type : Ty) → Option (ClosedRun (EvalBlock env key body type))
  | 0, _, _, _, _ => none
  | _n+1, env, key, .empty, .base .unit => some ⟨.normal .unit, [], .empty env key⟩
  | n+1, env, key, .builderBind kind rest, type => do
      let result ← block n { env with locals := none :: env.locals } key rest type
      some (result.map id id (fun _ _ proof => .builderBind env key kind rest type _ _ proof))
  | n+1, env, key, .last source, type => do
      let result ← expr n env key source type
      some (result.map id id (fun _ _ proof => .last env key source type _ _ proof))
  | n+1, env, key, .lastBind kind boundType source, .base .unit => do
      let result ← expr n env key source boundType
      some (result.map discardOutcome id
        (fun _ _ proof => .lastBind env key kind boundType source _ _ proof))
  | n+1, env, key, .lastDiscard source, .base .unit => do
      let sourceType ← typeOf env.standards n (localTypes env) source
      let result ← expr n env key source sourceType
      some (result.map discardOutcome id
        (fun _ _ proof => .lastDiscard env key source sourceType _ _ proof))
  | n+1, env, key, .lastPat kind pattern boundType source, .base .unit => do
      let result ← expr n env key source boundType
      some (result.map discardOutcome id
        (fun _ _ proof => .lastPat env key kind pattern boundType source _ _ proof))
  | n+1, env, key, .bind kind boundType source rest, type => do
      let result ← expr n env key source (boundType)
      result.bind [] (fun value et head => do
        let result ← block n { env with locals := some value :: env.locals } (advanceKey key (surfaceSize source)) rest type
        some (result.map id (et ++ ·) (fun _ _ tail =>
          .bind env key kind boundType source rest type value _ et _ head tail)))
        (fun _ _ head abrupt => .bindAbrupt env key kind boundType source rest type _ _ head abrupt)
  | n+1, env, key, .discard source rest, type => do
      let sourceType ← typeOf env.standards n (localTypes env) source
      let result ← expr n env key source (sourceType)
      result.bind [] (fun value et head => do
        let result ← block n env (advanceKey key (surfaceSize source)) rest type
        some (result.map id (et ++ ·) (fun _ _ tail =>
          .discard env key source rest sourceType type value _ et _ head tail)))
        (fun _ _ head abrupt => .discardAbrupt env key source rest sourceType type _ _ head abrupt)
  | n+1, env, key, .seq source rest, type => do
      let result ← expr n env key source (.base .unit)
      result.bind [] (fun value et head => do
        let result ← block n env (advanceKey key (surfaceSize source)) rest type
        some (result.map id (et ++ ·) (fun _ _ tail =>
          .seq env key source rest type value _ et _ head tail)))
        (fun _ _ head abrupt => .seqAbrupt env key source rest type _ _ head abrupt)
  | n+1, env, key, .bindPat kind pattern boundType source rest, type => do
      let result ← expr n env key source (boundType)
      result.bind [] (fun value et head => do
        let values ← bindings pattern value
        let result ← block n { env with locals := values.val.map some ++ env.locals } (advanceKey key (surfaceSize source)) rest type
        some (result.map id (et ++ ·) (fun _ _ tail =>
          .bindPat env key kind pattern boundType source rest type value _ et _ values.val head values.property tail)))
        (fun _ _ head abrupt => .bindPatAbrupt env key kind pattern boundType source rest type _ _ head abrupt)
  | _, _, _, _, _ => none

/-- 整数の腕と guard を順に評価し、偽の guard の束縛を後続へ残さない。 -/
def armList : (fuel : Nat) → (env : ConcreteEnv) → (key : OperationKey) →
    (value : Integer64Value) → (arms : Arms) → (type : Ty) →
    Option (ClosedRun (EvalArms env key value arms type))
  | 0, _, _, _, _, _ => none
  | n+1, env, key, value, .nil, type => some ⟨.failed .unknown, [], .nil env key value type⟩
  | n+1, env, key, value, .cons alts guard body rest, type => do
      let selection ← selectInteger ((alts.head?.map fun first => first.slots.length).getD 0) value alts
      match selection with
      | .miss proof =>
          let result ← armList n env (advanceKey key (guardSize guard + blockSize body)) value rest type
          some (result.map id id
            (fun _ _ tail => .skip env key value alts guard body rest type _ _ proof tail))
      | .hit selected proof =>
          let inner := { env with locals := selected.reverse.map some ++ env.locals }
          match guardEq : guard with
          | none =>
              let result ← block n inner key body type
              some (result.map id id
                (fun outcome trace branch => by
                  simpa only [guardEq, id, List.nil_append] using (EvalArms.body env key value alts body rest type selected outcome trace proof branch)))
          | some guard =>
              let result ← expr n inner key guard (.base .boolean)
              result.bind [] (fun truth gt condition => do
                match truth, condition with
                | .boolean true, condition =>
                    let result ← block n inner (advanceKey key (surfaceSize guard)) body type
                    some (result.map id (gt ++ ·) (fun outcome trace branch => by
                      simpa only [guardEq, id, List.nil_append] using (EvalArms.guardTrue env key value alts guard body rest type selected outcome gt trace proof condition branch)))
                | .boolean false, condition =>
                    let result ← armList n env (advanceKey key (surfaceSize guard + blockSize body)) value rest type
                    some (result.map id (gt ++ ·) (fun outcome trace tail => by
                      simpa only [guardEq, id, List.nil_append] using (EvalArms.guardFalse env key value alts guard body rest type selected outcome gt trace proof condition tail)))
                | _, _ => none)
                (fun outcome trace condition abrupt => by
                  simpa only [guardEq, id, List.nil_append] using (EvalArms.guardAbrupt env key value alts guard body rest type selected outcome trace proof condition abrupt))

/-- 整数の腕と guard を順に評価し、偽の guard の束縛を後続へ残さない。 -/
def widthArmList : (fuel : Nat) → (env : ConcreteEnv) → (key : OperationKey) →
    (kind : IntKind) → (value : IntegerValue kind) → (arms : Arms) → (type : Ty) →
    Option (ClosedRun (EvalWidthArms env key kind value arms type))
  | 0, _, _, _, _, _, _ => none
  | n+1, env, key, kind, value, .nil, type => some ⟨.failed .unknown, [], .nil env key kind value type⟩
  | n+1, env, key, kind, value, .cons alts guard body rest, type => do
      let selection ← selectWidth ((alts.head?.map fun first => first.slots.length).getD 0) kind value alts
      match selection with
      | .miss proof =>
          let result ← widthArmList n env (advanceKey key (guardSize guard + blockSize body)) kind value rest type
          some (result.map id id
            (fun _ _ tail => .skip env key kind value alts guard body rest type _ _ proof tail))
      | .hit selected proof =>
          let inner := { env with locals := selected.reverse.map some ++ env.locals }
          match guardEq : guard with
          | none =>
              let result ← block n inner key body type
              some (result.map id id
                (fun outcome trace branch => by
                  simpa only [guardEq, id, List.nil_append] using (EvalWidthArms.body env key kind value alts body rest type selected outcome trace proof branch)))
          | some guard =>
              let result ← expr n inner key guard (.base .boolean)
              result.bind [] (fun truth gt condition => do
                match truth, condition with
                | .boolean true, condition =>
                    let result ← block n inner (advanceKey key (surfaceSize guard)) body type
                    some (result.map id (gt ++ ·) (fun outcome trace branch => by
                      simpa only [guardEq, id, List.nil_append] using (EvalWidthArms.guardTrue env key kind value alts guard body rest type selected outcome gt trace proof condition branch)))
                | .boolean false, condition =>
                    let result ← widthArmList n env (advanceKey key (surfaceSize guard + blockSize body)) kind value rest type
                    some (result.map id (gt ++ ·) (fun outcome trace tail => by
                      simpa only [guardEq, id, List.nil_append] using (EvalWidthArms.guardFalse env key kind value alts guard body rest type selected outcome gt trace proof condition tail)))
                | _, _ => none)
                (fun outcome trace condition abrupt => by
                  simpa only [guardEq, id, List.nil_append] using (EvalWidthArms.guardAbrupt env key kind value alts guard body rest type selected outcome trace proof condition abrupt))
/-- Result の選択・guard・本体を同じ成功値の環境で評価する。 -/
def resultArmList : (fuel : Nat) → (env : ConcreteEnv) → (key : OperationKey) →
    (names : RangeNames) → (value : ConcreteValue) → (tag : ConName) → (payload : ConcreteValue) → (arms : Arms) → (type : Ty) →
    Option (ClosedRun (EvalResultArms env key names value tag payload arms type))
  | 0, _, _, _, _, _, _, _, _ => none
  | n+1, env, key, names, value, tag, payload, .nil, type => some ⟨.failed .unknown, [], .nil env key names value tag payload type⟩
  | n+1, env, key, names, value, tag, payload, .cons alts guard body rest, type => do
      let selection ← selectResult names value tag payload ((alts.head?.map fun first => first.slots.length).getD 0) alts
      match selection with
      | .miss proof =>
          let result ← resultArmList n env (advanceKey key (guardSize guard + blockSize body)) names value tag payload rest type
          some (result.map id id
            (fun _ _ tail => .skip env key names value tag payload alts guard body rest type _ _ proof tail))
      | .hit selected proof =>
          let inner := { env with locals := selected.reverse.map some ++ env.locals }
          match guardEq : guard with
          | none =>
              let result ← block n inner key body type
              some (result.map id id
                (fun outcome trace branch => by
                  simpa only [guardEq, id, List.nil_append] using (EvalResultArms.body env key names value tag payload alts body rest type selected outcome trace proof branch)))
          | some guard =>
              let result ← expr n inner key guard (.base .boolean)
              result.bind [] (fun truth gt condition => do
                match truth, condition with
                | .boolean true, condition =>
                    let result ← block n inner (advanceKey key (surfaceSize guard)) body type
                    some (result.map id (gt ++ ·) (fun outcome trace branch => by
                      simpa only [guardEq, id, List.nil_append] using (EvalResultArms.guardTrue env key names value tag payload alts guard body rest type selected outcome gt trace proof condition branch)))
                | .boolean false, condition =>
                    let result ← resultArmList n env (advanceKey key (surfaceSize guard + blockSize body)) names value tag payload rest type
                    some (result.map id (gt ++ ·) (fun outcome trace tail => by
                      simpa only [guardEq, id, List.nil_append] using (EvalResultArms.guardFalse env key names value tag payload alts guard body rest type selected outcome gt trace proof condition tail)))
                | _, _ => none)
                (fun outcome trace condition abrupt => by
                  simpa only [guardEq, id, List.nil_append] using (EvalResultArms.guardAbrupt env key names value tag payload alts guard body rest type selected outcome trace proof condition abrupt))
end

end ClosedEval

/-- 閉じた対象入力の決定的な評価。none は評価不能であり、言語の失敗ではない。
深さは評価器の停止用であり、区間解析の操作数・保持項目数の予算とは別である。 -/
def evalClosed (env : ConcreteEnv) (input : EvalInput) (fuel : Nat) :
    Option (ClosedRun (EvalPartial env input)) :=
  ClosedEval.expr fuel env input.key input.source input.type

/-- 評価に成功した値・失敗・return と trace は、必ず EvalPartial の導出を持つ。 -/
theorem evalClosed_sound {env input fuel result}
    (_evaluated : evalClosed env input fuel = some result) :
    EvalPartial env input result.outcome result.trace := result.sound

/-- 認定されない一般呼び出しは、引数を評価せず評価不能にする。 -/
theorem evalClosed_call (env : ConcreteEnv) (key : OperationKey) (head : Expr)
    (labels : List (Option String)) (positions : List Nat) (args : Exprs) (type : Ty) (fuel : Nat)
    (unrecognized : rangeCallBinding env ⟨.call head labels positions args, type, key⟩ = none) :
    evalClosed env ⟨.call head labels positions args, type, key⟩ fuel = none := by
  cases fuel with
  | zero => rfl
  | succ n =>
      simp only [evalClosed, ClosedEval.expr]
      split
      · rfl
      · rename_i binding recognized
        rw [unrecognized] at recognized
        contradiction

/-- 未知の値と事実を切る境界は、正常値にも失敗にも固定しない。 -/
theorem evalClosed_unsupported {env input fuel} (unsupported : Unsupported input.source) :
    evalClosed env input fuel = none := by
  rcases input with ⟨source, type, key⟩
  cases fuel with
  | zero => rfl
  | succ n =>
      cases source <;> simp_all [Unsupported, classify] <;> rfl

/-- 成功した評価の事象のキーは、元の部分木の番号範囲に入り重複しない。 -/
theorem evalClosed_trace_keys {env input fuel result}
    (evaluated : evalClosed env input fuel = some result) :
    TraceKeys input.key (surfaceSize input.source) result.trace :=
  eval_trace_keys (evalClosed_sound evaluated)

-- 実行可能な入口で正常な左辺の事象を残し、右辺の失敗で親の演算を飛ばす。
-- 期待するキー列は解析器や評価関係から生成せず固定する。
#guard
    let env : ConcreteEnv := ⟨[], [], fun _ => none⟩
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let input : EvalInput := ⟨.binary .add (.base .integer)
      (.binary .add (.base .integer) one one)
      (.binary .intDiv (.base .integer) one zero), .base .integer, ⟨"Closed.order", 10⟩⟩
    match evalClosed env input 16 with
    | some ⟨.failed .zeroDivisor, trace, _⟩ =>
        trace.map (fun event => event.key.surfacePreorder) == [11, 14]
    | _ => false

-- 未到達の未知式には具体値を選ばず、短絡した式だけを正常に評価する。
#guard
    let env : ConcreteEnv := ⟨[], [], fun _ => none⟩
    let unknown : Expr := .funName "Closed.unknown" [] []
    let input : EvalInput := ⟨.and (.literal (.boolean false)) unknown,
      .base .boolean, ⟨"Closed.short", 0⟩⟩
    (match evalClosed env input 8 with
      | some ⟨.normal (.boolean false), [], _⟩ => true
      | _ => false) &&
    (evalClosed env ⟨unknown, .base .boolean, input.key⟩ 8).isNone &&
    (evalClosed env input 0).isNone

-- 最初の腕の guard が偽ならその束縛を捨て、次の腕の値を実際に計算する。
#guard
    let env : ConcreteEnv := ⟨[], [], fun _ => none⟩
    let source : Expr := .matchE (.base .integer) (.literal (.integer ⟨7, by decide⟩))
      (.cons [⟨.var, [0]⟩] (some (.literal (.boolean false))) (.last (.local 0))
        (.cons [⟨.wild, []⟩] none (.last (.literal (.integer ⟨9, by decide⟩))) .nil))
    match evalClosed env ⟨source, .base .integer, ⟨"Closed.guard", 0⟩⟩ 16 with
    | some ⟨.normal (.integer value), [], _⟩ => value.toInt == 9
    | _ => false

end Benitoite.Interval
