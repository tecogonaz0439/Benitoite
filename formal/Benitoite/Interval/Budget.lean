import Benitoite.Interval.Domain

/-!
# 区間解析の操作数と保持項目数の予算

計上を拒否した操作は実行せず、本体の一時項目と終了後も保存する項目を区別する。
保持数はホストのバイト数によらない（設計書 01-12「区間解析の予算の状態と計上」）。
このモジュールは予算の状態遷移だけを定義し、式や環境の走査は行わない。
-/
namespace Benitoite.Interval.Budget

/-- 超過を判定する二つの資源。 -/
inductive Resource where
  | operations | items
  deriving DecidableEq, Repr

/-- 本体の上限と検査全体の上限を区別する。 -/
inductive Scope where
  | body | whole
  deriving DecidableEq, Repr

/-- 番号未取得の場合にも、原因となった上限と資源を残す。 -/
structure LimitFailure where
  scope : Scope
  resource : Resource
  deriving DecidableEq, Repr

/-- 通常の超過と、番号付けを完走できなかった場合の区別。 -/
inductive StopReason where
  | exceeded (failure : LimitFailure)
  | unidentified (failure : LimitFailure)
  deriving DecidableEq, Repr

/-- 各訪問・参照・更新・走査を一回ずつ計上する操作。 -/
inductive Operation where
  | expression | environmentRead | environmentWrite | joinItem | origin
  | numbering | classification
  deriving DecidableEq, Repr

/-- 同じ内容を二か所へ置けば二項となる、保持の単位。 -/
inductive Item where
  | environment | rangeOrigin | recordField | identity | warning | auxiliary | stackFrame
  deriving DecidableEq, Repr

/-- 本体終了で返却する項目と、終了後にも保存する項目。 -/
inductive Lifetime where
  | temporary | saved
  deriving DecidableEq, Repr

/-- 一つの範囲に許す累積操作数と最大同時保持項目数。 -/
structure Cap where
  operations : Nat
  items : Nat
  deriving DecidableEq, Repr

/-- 任意の上限を渡せる。既定値は本体10万、全体100万。 -/
structure Limits where
  body : Cap := ⟨100000, 100000⟩
  whole : Cap := ⟨1000000, 1000000⟩
  deriving DecidableEq, Repr

/-- 現在の本体に属する実消費。保存項目も本体の最大同時保持に含める。 -/
structure BodyState where
  operations : Nat := 0
  temporary : Nat := 0
  saved : Nat := 0
  peak : Nat := 0
  deriving DecidableEq, Repr

/-- 完了済み本体の保存項目、累積操作数、全体の最大同時保持。 -/
structure WholeState where
  operations : Nat := 0
  saved : Nat := 0
  peak : Nat := 0
  deriving DecidableEq, Repr

/-- 全体状態は本体を切り替えても引き継ぐ。 -/
structure State where
  body : BodyState := {}
  whole : WholeState := {}
  deriving DecidableEq, Repr

/-- 現本体の同時保持項目数。 -/
def State.bodyHeld (s : State) : Nat := s.body.temporary + s.body.saved

/-- 完了済み本体と現本体を合わせた同時保持項目数。 -/
def State.wholeHeld (s : State) : Nat := s.whole.saved + s.bodyHeld

/-- 現本体を終えても保存する項目の総数。 -/
def State.savedHeld (s : State) : Nat := s.whole.saved + s.body.saved

/-- 最大同時保持と累積操作数の整合性。 -/
def State.Valid (s : State) : Prop :=
  s.bodyHeld ≤ s.body.peak ∧ s.wholeHeld ≤ s.whole.peak ∧
  s.body.operations ≤ s.whole.operations

/-- 上限内にある状態。過去の最大同時保持も含む。 -/
def State.Within (limits : Limits) (s : State) : Prop :=
  s.body.operations ≤ limits.body.operations ∧ s.body.peak ≤ limits.body.items ∧
  s.whole.operations ≤ limits.whole.operations ∧ s.whole.peak ≤ limits.whole.items

/-- 停止時にも、最後に成功した状態を返す。 -/
inductive Step where
  | ok (state : State)
  | stopped (reason : StopReason) (state : State)
  deriving DecidableEq, Repr

/-- 成否に共通の、実消費を記録した状態。 -/
def Step.state : Step → State
  | .ok s | .stopped _ s => s

/-- 番号付けの呼び出し側は超過を番号未取得として報告する。 -/
def Step.forNumbering : Step → Step
  | .stopped (.exceeded failure) s => .stopped (.unidentified failure) s
  | result => result

/-- 同時超過時は本体を先に報告する。拒否では候補状態を採用しない。 -/
private def admit (limits : Limits) (resource : Resource) (before after : State) : Step :=
  let bodyUse := match resource with
    | .operations => after.body.operations
    | .items => after.bodyHeld
  let wholeUse := match resource with
    | .operations => after.whole.operations
    | .items => after.wholeHeld
  let bodyCap := match resource with
    | .operations => limits.body.operations
    | .items => limits.body.items
  let wholeCap := match resource with
    | .operations => limits.whole.operations
    | .items => limits.whole.items
  if bodyUse > bodyCap then .stopped (.exceeded ⟨.body, resource⟩) before
  else if wholeUse > wholeCap then .stopped (.exceeded ⟨.whole, resource⟩) before
  else .ok after

/-- 実際の操作の直前に一回を計上する。拒否時には操作を行わない。 -/
def charge (limits : Limits) (s : State) (_operation : Operation) : Step :=
  admit limits .operations s
    { s with body.operations := s.body.operations + 1,
             whole.operations := s.whole.operations + 1 }

/-- 一項の追加直前に両上限を検査する。内容の事前走査は必要としない。 -/
def reserve (limits : Limits) (s : State) (_item : Item) (lifetime : Lifetime) : Step :=
  let body := match lifetime with
    | .temporary => { s.body with temporary := s.body.temporary + 1 }
    | .saved => { s.body with saved := s.body.saved + 1 }
  admit limits .items s
    { body := { body with peak := max s.body.peak (s.bodyHeld + 1) },
      whole := { s.whole with peak := max s.whole.peak (s.wholeHeld + 1) } }

/-- 一時項目を保存項目へ移す。複製せず、保持数と最大同時保持は変えない。 -/
def save (s : State) (count : Nat) (_available : count ≤ s.body.temporary) : State :=
  { s with body.temporary := s.body.temporary - count,
           body.saved := s.body.saved + count }

/-- 現本体の指定した種類の項目を削除し、その数だけ返却する。 -/
def release (s : State) (lifetime : Lifetime) (count : Nat)
    (_available : count ≤ match lifetime with
      | .temporary => s.body.temporary | .saved => s.body.saved) : State :=
  match lifetime with
  | .temporary => { s with body.temporary := s.body.temporary - count }
  | .saved => { s with body.saved := s.body.saved - count }

/-- 完了済み本体の保存項目を削除した場合も全体の保持数へ返却する。 -/
def releaseSaved (s : State) (count : Nat) (_available : count ≤ s.whole.saved) : State :=
  { s with whole.saved := s.whole.saved - count }

/-- 本体の終了。一時項目だけを返し、保存項目・累積操作数・全体の最大値を保つ。 -/
def finishBody (s : State) : State :=
  { body := {}, whole := { s.whole with saved := s.savedHeld } }

/-- 初期状態は整合する。 -/
theorem initial_valid : State.Valid {} := by
  simp [State.Valid, State.bodyHeld, State.wholeHeld]

/-- 初期状態は0を含む任意の上限内にある。 -/
theorem initial_within (limits : Limits) : State.Within limits {} := by
  simp [State.Within]

/-- 拒否された計上は、操作数・保持数・最大値のすべてを変えない。 -/
private theorem admit_rejected {limits resource before after reason state}
    (h : admit limits resource before after = .stopped reason state) : state = before := by
  cases resource <;> simp only [admit] at h <;>
    split at h <;> simp_all <;> split at h <;> simp_all

/-- 成功した計上は候補状態をそのまま採用する。 -/
private theorem admit_accepted {limits resource before after state}
    (h : admit limits resource before after = .ok state) : state = after := by
  cases resource <;> simp only [admit] at h <;>
    split at h <;> simp_all <;> split at h <;> simp_all

/-- 成功した操作は、本体と全体の累積に正確に一回を加える。 -/
theorem charge_accepted {limits s operation state}
    (h : charge limits s operation = .ok state) :
    state.body.operations = s.body.operations + 1 ∧
    state.whole.operations = s.whole.operations + 1 ∧
    state.bodyHeld = s.bodyHeld ∧ state.wholeHeld = s.wholeHeld := by
  have eq := admit_accepted h
  subst state
  simp [State.bodyHeld, State.wholeHeld]

/-- 成功した確保だけが両範囲の保持数を一項増やし、最大値を更新する。 -/
theorem reserve_accepted {limits s item lifetime state}
    (h : reserve limits s item lifetime = .ok state) :
    state.bodyHeld = s.bodyHeld + 1 ∧ state.wholeHeld = s.wholeHeld + 1 ∧
    state.body.peak = max s.body.peak (s.bodyHeld + 1) ∧
    state.whole.peak = max s.whole.peak (s.wholeHeld + 1) := by
  unfold reserve at h
  have eq := admit_accepted h
  subst state
  cases lifetime <;> simp [State.bodyHeld, State.wholeHeld] <;> omega

/-- 特に拒否された確保で保持数は増えない。 -/
theorem reserve_rejected {limits s item lifetime reason state}
    (h : reserve limits s item lifetime = .stopped reason state) : state = s := by
  unfold reserve at h
  exact admit_rejected h

/-- 番号未取得への分類は、消費した状態を変えない。 -/
theorem numbering_state (result : Step) : result.forNumbering.state = result.state := by
  cases result with
  | ok => rfl
  | stopped reason => cases reason <;> rfl

/-- 本体を終了しても検査全体の累積操作数は減らない。 -/
theorem finish_operations (s : State) :
    (finishBody s).whole.operations = s.whole.operations := rfl

/-- 保存済み項目は本体の終了で失われない。 -/
theorem finish_saved (s : State) : (finishBody s).savedHeld = s.savedHeld := by
  simp [finishBody, State.savedHeld]

/-- 本体終了時に返す項目は、一時項目にちょうど一致する。 -/
theorem finish_held (s : State) :
    (finishBody s).wholeHeld + s.body.temporary = s.wholeHeld := by
  simp [finishBody, State.wholeHeld, State.bodyHeld, State.savedHeld]
  omega

/-- 全体の最大同時保持は、本体終了時にも保存する。 -/
theorem finish_peak (s : State) : (finishBody s).whole.peak = s.whole.peak := rfl

/-- 本体終了で整合性を保つ。 -/
theorem finish_valid {s : State} (h : s.Valid) : (finishBody s).Valid := by
  simp [State.Valid, finishBody, State.bodyHeld, State.wholeHeld, State.savedHeld] at *
  omega

/-- 本体終了で上限内の状態を保つ。 -/
theorem finish_within {limits : Limits} {s : State} (h : s.Within limits) :
    (finishBody s).Within limits := by
  simp [State.Within, finishBody] at *
  omega

/-- 操作を拒否した場合にも、状態全体を保つ。 -/
theorem charge_rejected {limits s operation reason state}
    (h : charge limits s operation = .stopped reason state) : state = s := by
  exact admit_rejected h

/-- 操作の計上は状態の整合性を保つ。 -/
theorem charge_valid (limits : Limits) (s : State) (operation : Operation) (h : s.Valid) :
    (charge limits s operation).state.Valid := by
  dsimp [charge, admit]
  split
  · exact h
  · split
    · exact h
    · simp [Step.state, State.Valid, State.bodyHeld, State.wholeHeld] at *
      omega

/-- 成功した操作の実消費と、拒否後の実消費は、いずれも上限内である。 -/
theorem charge_within (limits : Limits) (s : State) (operation : Operation)
    (h : s.Within limits) : (charge limits s operation).state.Within limits := by
  dsimp [charge, admit]
  split
  · exact h
  · split
    · exact h
    · simp [Step.state, State.Within] at *
      omega

/-- 確保は両範囲の最大同時保持を更新し、整合性を保つ。 -/
theorem reserve_valid (limits : Limits) (s : State) (item : Item) (lifetime : Lifetime)
    (h : s.Valid) : (reserve limits s item lifetime).state.Valid := by
  cases lifetime <;> dsimp [reserve, admit] <;> split
  · exact h
  · split
    · exact h
    · simp [Step.state, State.Valid, State.bodyHeld, State.wholeHeld] at *
      omega
  · exact h
  · split
    · exact h
    · simp [Step.state, State.Valid, State.bodyHeld, State.wholeHeld] at *
      omega

/-- 拒否前に最大値を更新せず、成功した確保だけが両上限へ収まる。 -/
theorem reserve_within (limits : Limits) (s : State) (item : Item) (lifetime : Lifetime)
    (h : s.Within limits) : (reserve limits s item lifetime).state.Within limits := by
  cases lifetime <;> dsimp [reserve, admit] <;> split
  · exact h
  · split
    · exact h
    · simp [Step.state, State.Within, State.bodyHeld, State.wholeHeld] at *
      omega
  · exact h
  · split
    · exact h
    · simp [Step.state, State.Within, State.bodyHeld, State.wholeHeld] at *
      omega

/-- 保存への移動で保持数と最大同時保持を重複計上しない。 -/
theorem save_held (s : State) (count : Nat) (h : count ≤ s.body.temporary) :
    (save s count h).bodyHeld = s.bodyHeld ∧
    (save s count h).wholeHeld = s.wholeHeld ∧
    (save s count h).body.peak = s.body.peak ∧
    (save s count h).whole.peak = s.whole.peak := by
  simp [save, State.bodyHeld, State.wholeHeld]
  omega

/-- 保存への移動は整合性と上限を保つ。 -/
theorem save_valid (s : State) (count : Nat) (available : count ≤ s.body.temporary)
    (h : s.Valid) : (save s count available).Valid := by
  simp [State.Valid, save, State.bodyHeld, State.wholeHeld] at *
  omega

/-- 保存への移動は操作数と最大値を変えない。 -/
theorem save_within (limits : Limits) (s : State) (count : Nat)
    (available : count ≤ s.body.temporary) (h : s.Within limits) :
    (save s count available).Within limits := h

/-- 削除した現本体の項目数だけ、両範囲の同時保持数が減る。 -/
theorem release_held (s : State) (lifetime : Lifetime) (count : Nat)
    (h : count ≤ match lifetime with
      | .temporary => s.body.temporary | .saved => s.body.saved) :
    (release s lifetime count h).bodyHeld + count = s.bodyHeld ∧
    (release s lifetime count h).wholeHeld + count = s.wholeHeld := by
  cases lifetime <;> dsimp at h ⊢ <;>
    simp [release, State.bodyHeld, State.wholeHeld] <;> omega

/-- 削除で整合性を保ち、過去の最大値を減らさない。 -/
theorem release_valid (s : State) (lifetime : Lifetime) (count : Nat)
    (available : count ≤ match lifetime with
      | .temporary => s.body.temporary | .saved => s.body.saved)
    (h : s.Valid) : (release s lifetime count available).Valid := by
  cases lifetime <;>
    simp [release, State.Valid, State.bodyHeld, State.wholeHeld] at * <;> omega

/-- 削除は上限内の状態を保つ。 -/
theorem release_within (limits : Limits) (s : State) (lifetime : Lifetime) (count : Nat)
    (available : count ≤ match lifetime with
      | .temporary => s.body.temporary | .saved => s.body.saved)
    (h : s.Within limits) : (release s lifetime count available).Within limits := by
  cases lifetime <;> exact h

/-- 完了済み本体の項目の削除も、実際に減った数を返却する。 -/
theorem releaseSaved_held (s : State) (count : Nat) (h : count ≤ s.whole.saved) :
    (releaseSaved s count h).wholeHeld + count = s.wholeHeld := by
  simp [releaseSaved, State.wholeHeld, State.bodyHeld]
  omega

/-- 完了済み本体の保存項目の削除は整合性を保つ。 -/
theorem releaseSaved_valid (s : State) (count : Nat) (available : count ≤ s.whole.saved)
    (h : s.Valid) : (releaseSaved s count available).Valid := by
  simp [releaseSaved, State.Valid, State.wholeHeld, State.bodyHeld] at *
  omega

/-- 完了済み本体の保存項目の削除は上限内の状態を保つ。 -/
theorem releaseSaved_within (limits : Limits) (s : State) (count : Nat)
    (available : count ≤ s.whole.saved) (h : s.Within limits) :
    (releaseSaved s count available).Within limits := h

/-- 作業枠を返す呼び出し側のため、操作の成否によらず一時保持数を保つ。 -/
theorem charge_temporary (limits : Limits) (s : State) (operation : Operation) :
    (charge limits s operation).state.body.temporary = s.body.temporary := by
  cases h : charge limits s operation with
  | ok state =>
    have eq := admit_accepted h
    subst state
    rfl
  | stopped reason state => rw [charge_rejected h]; rfl

/-- 成功した確保が増やした一時保持数を、寿命から直接読める。 -/
theorem reserve_accepted_temporary {limits s item lifetime state}
    (h : reserve limits s item lifetime = .ok state) :
    state.body.temporary = s.body.temporary +
      (match lifetime with | .temporary => 1 | .saved => 0) := by
  unfold reserve at h
  have eq := admit_accepted h
  subst state
  cases lifetime <;> simp

end Benitoite.Interval.Budget

