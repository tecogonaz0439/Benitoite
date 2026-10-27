import Benitoite.Interval.Budget
import Benitoite.Interval.Identity

/-!
# 予算を逐次引き継ぐ局所の走査

環境の参照・更新・合流と分類を、事前の大きさの走査なしに行う。
作業枠は復帰時に返す。新しい環境の項目は呼び出し側の作業領域に保持し、
`region` がその領域を閉じるときに一括で返す。共有した入力の接尾辞は再計上しない。
（設計書 01-12「区間解析の予算付きの局所走査」）。
-/
namespace Benitoite.Interval.BudgetScan
open Benitoite.Surface
open Benitoite.Release (Ty selectSlots)
open Budget

/-- 停止時にも途中までの実消費を保ち、後続の計算を呼ばない。 -/
inductive Outcome (α : Type) where
  | ok (value : α) (state : State)
  | stopped (reason : StopReason) (state : State)

/-- 停止を成功と取り違えず、成否に共通の実消費だけを読む。 -/
def Outcome.state : Outcome α → State
  | .ok _ s | .stopped _ s => s

/-- 呼び出し前から保持した一時項目を勝手に返却しない計算。 -/
structure Scan (α : Type) where
  run : Limits → State → Outcome α
  keepsTemporary : ∀ limits s, s.body.temporary ≤ (run limits s).state.body.temporary
  keepsValid : ∀ limits s, s.Valid → (run limits s).state.Valid
  keepsWithin : ∀ limits s, s.Within limits → (run limits s).state.Within limits

private def ret (value : α) : Scan α :=
  ⟨fun _ s => .ok value s, by intros; exact Nat.le_refl _,
    by intros; assumption, by intros; assumption⟩

private def seq (first : Scan α) (next : α → Scan β) : Scan β where
  run limits s := match first.run limits s with
    | .ok value state => (next value).run limits state
    | .stopped reason state => .stopped reason state
  keepsTemporary limits s := by
    have h := first.keepsTemporary limits s
    cases eq : first.run limits s with
    | ok value state =>
      rw [eq] at h
      exact Nat.le_trans h ((next value).keepsTemporary limits state)
    | stopped reason state => rw [eq] at h; exact h

  keepsValid limits s valid := by
    have h := first.keepsValid limits s valid
    cases eq : first.run limits s with
    | ok value state =>
      rw [eq] at h
      exact (next value).keepsValid limits state h
    | stopped reason state => rw [eq] at h; exact h
  keepsWithin limits s within := by
    have h := first.keepsWithin limits s within
    cases eq : first.run limits s with
    | ok value state =>
      rw [eq] at h
      exact (next value).keepsWithin limits state h
    | stopped reason state => rw [eq] at h; exact h

instance : Monad Scan where
  pure := ret
  bind := seq

/-- 操作を拒否した場合は、実操作へ進まない。 -/
def tick (operation : Operation) : Scan Unit where
  run limits s := match charge limits s operation with
    | .ok state => .ok () state
    | .stopped reason state => .stopped reason state
  keepsTemporary limits s := by
    cases eq : charge limits s operation with
    | ok state =>
      have h := charge_temporary limits s operation
      rw [eq] at h
      exact Nat.le_of_eq h.symm
    | stopped reason state => rw [charge_rejected eq]; exact Nat.le_refl _

  keepsValid limits s valid := by
    have h := charge_valid limits s operation valid
    cases eq : charge limits s operation <;> simpa only [eq, Step.state, Outcome.state] using h
  keepsWithin limits s within := by
    have h := charge_within limits s operation within
    cases eq : charge limits s operation <;> simpa only [eq, Step.state, Outcome.state] using h

/-- 実際に追加する一項を、追加前に計上する。 -/
def allocate (item : Item) (lifetime : Lifetime := .temporary) : Scan Unit where
  run limits s := match reserve limits s item lifetime with
    | .ok state => .ok () state
    | .stopped reason state => .stopped reason state
  keepsTemporary limits s := by
    cases eq : reserve limits s item lifetime with
    | ok state =>
      have h := reserve_accepted_temporary eq
      cases lifetime <;> simp_all [Outcome.state] <;> omega
    | stopped reason state => rw [reserve_rejected eq]; exact Nat.le_refl _

  keepsValid limits s valid := by
    have h := reserve_valid limits s item lifetime valid
    cases eq : reserve limits s item lifetime <;> simpa only [eq, Step.state, Outcome.state] using h
  keepsWithin limits s within := by
    have h := reserve_within limits s item lifetime within
    cases eq : reserve limits s item lifetime <;> simpa only [eq, Step.state, Outcome.state] using h

/-- 状態だけを変更し、成功値・停止理由は保つ。 -/
def Outcome.mapState (f : State → State) : Outcome α → Outcome α
  | .ok value s => .ok value (f s)
  | .stopped reason s => .stopped reason (f s)

/-- 返却後の状態を成否によらず同じ定義で読む。 -/
@[simp] theorem Outcome.mapState_state (result : Outcome α) (f : State → State) :
    (result.mapState f).state = f result.state := by cases result <;> rfl

private theorem Outcome.mapState_ok {result : Outcome α} {f : State → State} {value state}
    (h : result.mapState f = .ok value state) : ∃ final, result = .ok value final := by
  cases result with
  | stopped => contradiction
  | ok v final => cases h; exact ⟨final, rfl⟩

/-- 一枠を実際の再帰呼び出しの前に確保し、成功・停止のどちらでも返す。 -/
def frame (body : Unit → Scan α) : Scan α where
  run limits s := match h : reserve limits s .stackFrame .temporary with
    | .stopped reason state => .stopped reason state
    | .ok entered =>
      let result := (body ()).run limits entered
      have available : 1 ≤ result.state.body.temporary := by
        have he := reserve_accepted_temporary h
        have hr := (body ()).keepsTemporary limits entered
        change entered.body.temporary = s.body.temporary + 1 at he
        dsimp only [result]
        omega
      result.mapState (fun _ => release result.state .temporary 1 available)
  keepsTemporary limits s := by
    dsimp
    split
    next reason state h => rw [reserve_rejected h]; exact Nat.le_refl _
    next entered h =>
      have he := reserve_accepted_temporary h
      change entered.body.temporary = s.body.temporary + 1 at he
      have hr := (body ()).keepsTemporary limits entered
      simp only [Outcome.mapState_state, release]
      omega

  keepsValid limits s valid := by
    dsimp
    split
    next reason state h => rw [reserve_rejected h]; exact valid
    next entered h =>
      have he := reserve_valid limits s .stackFrame .temporary valid
      rw [h] at he
      simp only [Outcome.mapState_state]
      apply release_valid
      exact (body ()).keepsValid limits entered he
  keepsWithin limits s within := by
    dsimp
    split
    next reason state h => rw [reserve_rejected h]; exact within
    next entered h =>
      have he := reserve_within limits s .stackFrame .temporary within
      rw [h] at he
      simp only [Outcome.mapState_state]
      apply release_within
      exact (body ()).keepsWithin limits entered he

/-- 作業領域を閉じる。領域内で作った環境は外へ返さず、利用を終えてから呼ぶ。 -/
def region (body : Unit → Scan α) : Scan α where
  run limits s :=
    let result := (body ()).run limits s
    let count := result.state.body.temporary - s.body.temporary
    result.mapState (fun _ => release result.state .temporary count (Nat.sub_le _ _))
  keepsTemporary limits s := by
    have h := (body ()).keepsTemporary limits s
    simp only [Outcome.mapState_state, release]
    omega

  keepsValid limits s valid := by
    simp only [Outcome.mapState_state]
    apply release_valid
    exact (body ()).keepsValid limits s valid
  keepsWithin limits s within := by
    simp only [Outcome.mapState_state]
    apply release_within
    exact (body ()).keepsWithin limits s within

/-- 番号付け全体を囲い、途中の枠・対応表の確保の失敗も番号未取得にする。 -/
def forNumbering (body : Unit → Scan α) : Scan α where
  run limits s := match (body ()).run limits s with
    | .stopped (.exceeded failure) state => .stopped (.unidentified failure) state
    | result => result
  keepsTemporary limits s := by
    have h := (body ()).keepsTemporary limits s
    cases eq : (body ()).run limits s with
    | ok => simpa only [eq] using h
    | stopped reason => cases reason <;> simpa only [eq, Outcome.state] using h

  keepsValid limits s valid := by
    have h := (body ()).keepsValid limits s valid
    cases eq : (body ()).run limits s with
    | ok => simpa only [eq] using h
    | stopped reason => cases reason <;> simpa only [eq, Outcome.state] using h
  keepsWithin limits s within := by
    have h := (body ()).keepsWithin limits s within
    cases eq : (body ()).run limits s with
    | ok => simpa only [eq] using h
    | stopped reason => cases reason <;> simpa only [eq, Outcome.state] using h

/-- 番号付けの有界の先行順走査が、一出現の対応を保存する直前に呼ぶ。
キーの計算に部分木の大きさを求めず、渡された次番号を一つ進める。 -/
def identify (next : OperationKey) : Scan (OperationKey × OperationKey) := forNumbering fun _ => do
  tick .numbering
  allocate .identity .saved
  pure (next, { next with surfacePreorder := next.surfacePreorder + 1 })

/-- 完走した結果だけを、既存の局所規則の値と比較する。 -/
def Agrees (scan : Scan α) (expected : α) : Prop :=
  ∀ limits s value state, scan.run limits s = .ok value state → value = expected

/-- 予算を消費しない値は、初期状態によらずその値自身を返す。 -/
theorem agrees_pure (value : α) : Agrees (pure value) value := by
  intro limits s result state h
  cases h
  rfl

/-- 後続の値を作らない操作の計上は、逐次合成で正常値を変えない。 -/
theorem agrees_unit (scan : Scan Unit) : Agrees scan () := by
  intro limits s result state h
  cases result
  rfl

/-- 先行・後続の完走時の一致から、状態を共有する逐次合成の一致を得る。 -/
theorem agrees_bind {first : Scan α} {next : α → Scan β} {value : α} {expected : β}
    (hfirst : Agrees first value) (hnext : Agrees (next value) expected) :
    Agrees (first >>= next) expected := by
  intro limits s result state h
  change (match first.run limits s with
    | .ok value state => (next value).run limits state
    | .stopped reason state => .stopped reason state) = _ at h
  cases eq : first.run limits s with
  | stopped => simp [eq] at h
  | ok value state =>
    have same := hfirst limits s value state eq
    subst value
    exact hnext limits state result _ (by simpa only [eq] using h)

/-- 枠の確保と返却を加えても、完走時の値の契約を保つ。 -/
theorem agrees_frame {body : Unit → Scan α} {expected : α}
    (hbody : Agrees (body ()) expected) : Agrees (frame body) expected := by
  intro limits s value state h
  dsimp only [frame] at h
  split at h
  · contradiction
  · next entered he =>
    obtain ⟨final, eq⟩ := Outcome.mapState_ok h
    exact hbody limits entered value final eq

/-- 作業領域の返却を加えても、完走時の値の契約を保つ。 -/
theorem agrees_region {body : Unit → Scan α} {expected : α}
    (hbody : Agrees (body ()) expected) : Agrees (region body) expected := by
  intro limits s value state h
  obtain ⟨final, eq⟩ := Outcome.mapState_ok h
  exact hbody limits s value final eq

/-- 先行する計算が停止したら、次の計算を評価せず同じ停止を返す。 -/
theorem bind_stopped {first : Scan α} {next : α → Scan β} {limits s reason state}
    (h : first.run limits s = .stopped reason state) :
    (first >>= next).run limits s = .stopped reason state := by
  change (match first.run limits s with
    | .ok value state => (next value).run limits state
    | .stopped reason state => .stopped reason state) = _
  rw [h]

/-- 領域を閉じると新しい一時項目だけを返し、呼び出し前の保持を保つ。 -/
theorem region_temporary (body : Unit → Scan α) (limits : Limits) (s : State) :
    ((region body).run limits s).state.body.temporary = s.body.temporary := by
  have h := (body ()).keepsTemporary limits s
  simp only [region, Outcome.mapState_state, release]
  omega

/-- 領域の返却で実消費・最大値・保存項目を消さない。 -/
theorem region_counters (body : Unit → Scan α) (limits : Limits) (s : State) :
    let before := ((body ()).run limits s).state
    let after := ((region body).run limits s).state
    after.body.operations = before.body.operations ∧
    after.whole = before.whole ∧ after.body.peak = before.body.peak ∧
    after.body.saved = before.body.saved := by
  simp only [region, Outcome.mapState_state, release]
  trivial

/-- 失敗の分類の変更によって、完走時の値の契約を変えない。 -/
theorem agrees_forNumbering {body : Unit → Scan α} {expected : α}
    (hbody : Agrees (body ()) expected) : Agrees (forNumbering body) expected := by
  intro limits s value state h
  dsimp only [forNumbering] at h
  cases eq : (body ()).run limits s with
  | ok result final =>
    simp only [eq, Outcome.ok.injEq] at h
    exact h.1 ▸ hbody limits s result final eq
  | stopped reason final => cases reason <;> simp [eq] at h

/-- 完走した一出現の番号付けは、渡されたキーを使って次番号を一つ進める。 -/
theorem identify_agrees (next : OperationKey) :
    Agrees (identify next) (next, { next with surfacePreorder := next.surfacePreorder + 1 }) := by
  apply agrees_forNumbering
  apply agrees_bind (agrees_unit _)
  apply agrees_bind (agrees_unit _)
  exact agrees_pure _

end Benitoite.Interval.BudgetScan
