import Benitoite.Release.Refinement.Surface.ScopeLower
import Benitoite.Scope.RangeCover

/-!
# 必須の判定の受理と拒否の理由

全ての出現を検査し、記録のある出現は全ての記録の状態で、記録のない出現は事実を持たない状態で、
規則の選ぶ範囲を契約が覆うことを確かめる。未知の由来と予算の超過が選ぶ Top を、狭い契約で受理しない
（設計書 01-12「Scope の必須の判定の受理と拒否の理由」）。
-/
namespace Benitoite.Release.Refinement.Surface.ScopeAccept

open Benitoite.Scope.Inference
open Benitoite.Release.Refinement.Surface.ScopeState
open Benitoite.Release.Refinement.Surface.ScopeLower
open Benitoite.Scope.Domain (Range)

/-! ## 拒否の理由と必須の判定の結果 -/

/-- 範囲の被覆を確認できなかった理由（診断 E0519 の `reason`）。`notCovered` は既知の範囲を契約が覆わない、
`atomicCoverOnly` は一原子ずつの被覆では確認できない（複数の原子の和なら覆いうる）。`unknownSource` は由来を
認定できず Top になった場合、又は未具体化の契約の全具体化に対する被覆を確認できない場合である。
`budgetExceeded` は必須の判定の予算を超えて Top になった場合である。 -/
inductive CoverFailure where
  | notCovered
  | atomicCoverOnly
  | unknownSource
  | budgetExceeded
  deriving DecidableEq, Repr

/-- 必須の判定が一つの範囲の位置について返す結果。 -/
inductive Required where
  | known (r : Range)
  | unknown
  | exceeded
  deriving DecidableEq, Repr

/-- 型の添字。未知と予算の超過は Top。 -/
def Required.index : Required → Range
  | .known r => r
  | .unknown | .exceeded => .top

/-- 規則の `index` が返した範囲を必須の判定の結果に読む。Top は由来を認定できなかった位置であり、解析が予算を超えて
いれば超過、そうでなければ未知とする。 -/
def Required.ofIndex (exceeded : Bool) (r : Range) : Required :=
  if r = .top then (if exceeded then .exceeded else .unknown) else .known r

@[simp] theorem Required.ofIndex_index (exceeded : Bool) (r : Range) : (Required.ofIndex exceeded r).index = r := by
  unfold Required.ofIndex
  split
  · next h => subst h; split <;> rfl
  · rfl

/-! ## 範囲の受理 -/

/-- 契約の範囲 S を、必須の判定の結果 q のもとで受理するか。 -/
def acceptRange (q : Required) (S : Range) : Except CoverFailure Unit :=
  if S = .top then .ok ()
  else
    match q with
    | .known r => if S.Covers r then .ok () else .error .notCovered
    | .unknown => .error .unknownSource
    | .exceeded => .error .budgetExceeded

/-- 受理した契約の範囲は、必須の判定の添字を覆う。 -/
theorem acceptRange_sound {q : Required} {S : Range} (h : acceptRange q S = .ok ()) : S.Covers q.index := by
  by_cases hs : S = .top
  · subst hs; exact Range.top_covers _
  · cases q with
    | known r =>
      simp only [Required.index]
      by_cases hc : S.Covers r
      · exact hc
      · simp [acceptRange, hs, hc] at h
    | unknown | exceeded => simp [acceptRange, hs] at h

/-- Top の契約はいつも受理する。 -/
@[simp] theorem acceptRange_top (q : Required) : acceptRange q .top = .ok () := by simp [acceptRange]

theorem acceptRange_exceeded {S : Range} (hs : S ≠ .top) : acceptRange .exceeded S = .error .budgetExceeded := by
  simp [acceptRange, hs]

/-- 列の先頭の位置の受理。必須の判定の結果が `some q` なら `acceptRange q`、`none`（規則がその位置を選ばない。明示拡大の
行き先など）なら制約を置かない。 -/
def acceptHead (qs : List (Option Required)) (S : Range) : Except CoverFailure Unit :=
  match qs.head? with
  | some (some q) => acceptRange q S
  | _ => .ok ()

/-- 範囲の列の受理。各位置を `acceptHead` で確かめる。規則が範囲を選ぶ位置（`some q`）に契約の範囲がない（範囲の列が
短い）なら、推論した範囲を覆う契約がないので `notCovered` で拒否する。 -/
def acceptRanges : List (Option Required) → List Range → Except CoverFailure Unit
  | qs, [] => if qs.any Option.isSome then .error .notCovered else .ok ()
  | qs, S :: rest =>
    match acceptHead qs S with
    | .ok () => acceptRanges qs.tail rest
    | .error f => .error f

theorem acceptRanges_sound : ∀ {qs : List (Option Required)} {rs : List Range}, acceptRanges qs rs = .ok () →
    ∀ (i : Nat) (S : Range) (q : Required), rs[i]? = some S → qs[i]? = some (some q) → acceptRange q S = .ok ()
  | _, [], _, i, S, q, hS, _ => by simp at hS
  | qs, S0 :: rest, h, i, S, q, hS, hq => by
    simp only [acceptRanges] at h
    split at h
    · next hh =>
      cases qs with
      | nil => simp at hq
      | cons q0 qs' =>
        cases i with
        | zero =>
          simp only [List.getElem?_cons_zero, Option.some.injEq] at hS hq
          subst hS hq
          simpa [acceptHead] using hh
        | succ i =>
          simp only [List.getElem?_cons_succ] at hS hq
          exact acceptRanges_sound h i S q hS hq
    · cases h

/-- 受理した範囲の列は、規則が範囲を選ぶ全ての位置に契約の範囲を持つ。 -/
theorem acceptRanges_some : ∀ {qs : List (Option Required)} {rs : List Range}, acceptRanges qs rs = .ok () →
    ∀ (i : Nat) (q : Required), qs[i]? = some (some q) → ∃ S, rs[i]? = some S
  | qs, [], h, i, q, hq => by
    simp only [acceptRanges] at h
    split at h
    · cases h
    · next hn =>
      exfalso
      apply hn
      exact List.any_eq_true.mpr ⟨some q, List.mem_of_getElem? hq, rfl⟩
  | qs, S0 :: rest, h, i, q, hq => by
    cases i with
    | zero => exact ⟨S0, rfl⟩
    | succ i =>
      simp only [acceptRanges] at h
      split at h
      · cases qs with
        | nil => simp at hq
        | cons q0 qs' =>
          simp only [List.getElem?_cons_succ] at hq ⊢
          exact acceptRanges_some h i q hq
      · cases h

/-- 範囲の列の受理の特徴付け。第一の連言は、各位置の契約が規則の選ぶ範囲を `acceptRange` で受理することであり、第二の連言は 列の長さの条件（規則が範囲を選ぶ位置は列の中にある）で
ある。型付けの `RangeAdmissible` を満たす列のように、規則が選ぶ位置が全て列の長さより小さければ、受理は第一の連言と
同値である。 -/
theorem acceptRanges_iff : ∀ {qs : List (Option Required)} {rs : List Range},
    acceptRanges qs rs = .ok () ↔
      (∀ (i : Nat) (S : Range) (q : Required), rs[i]? = some S → qs[i]? = some (some q) → acceptRange q S = .ok ()) ∧
      (∀ (i : Nat) (q : Required), qs[i]? = some (some q) → i < rs.length)
  | qs, [] => by
    simp only [acceptRanges, List.length_nil, Nat.not_lt_zero, List.getElem?_nil, reduceCtorEq, false_implies,
      implies_true, true_and]
    constructor
    · intro h i q hq
      split at h
      · cases h
      · next hn => exact hn (List.any_eq_true.mpr ⟨some q, List.mem_of_getElem? hq, rfl⟩)
    · intro h
      split
      · next hy =>
        obtain ⟨x, hx, hs⟩ := List.any_eq_true.mp hy
        obtain ⟨i, hi⟩ := List.getElem?_of_mem hx
        cases x with
        | none => cases hs
        | some q => exact (h i q hi).elim
      · rfl
  | qs, S0 :: rest => by
    simp only [acceptRanges]
    have ih := @acceptRanges_iff qs.tail rest
    have hhead : acceptHead qs S0 = .ok () ↔ ∀ q, qs[0]? = some (some q) → acceptRange q S0 = .ok () := by
      unfold acceptHead
      cases qs with
      | nil => simp
      | cons q0 qs' =>
        cases q0 with
        | none => simp
        | some q => simp
    constructor
    · intro h
      split at h
      · next hh =>
        obtain ⟨h1, h2⟩ := ih.mp h
        refine ⟨fun i S q hS hq => ?_, fun i q hq => ?_⟩
        · cases i with
          | zero =>
            simp only [List.getElem?_cons_zero, Option.some.injEq] at hS
            subst hS
            exact (hhead.mp hh) q hq
          | succ i =>
            simp only [List.getElem?_cons_succ] at hS
            exact h1 i S q hS (by cases qs <;> simp_all)
        · cases i with
          | zero => simp
          | succ i =>
            have := h2 i q (by cases qs <;> simp_all)
            simp only [List.length_cons]; omega
      · cases h
    · rintro ⟨h1, h2⟩
      have hh : acceptHead qs S0 = .ok () := hhead.mpr fun q hq => h1 0 S0 q rfl hq
      rw [hh]
      refine ih.mpr ⟨fun i S q hS hq => h1 (i + 1) S q (by simpa using hS) (by cases qs <;> simp_all),
        fun i q hq => ?_⟩
      have := h2 (i + 1) q (by cases qs <;> simp_all)
      simp only [List.length_cons] at this; omega

/-- 事実を持たない状態。記録のない出現の選び方に使う（局所の事実を仮定しない）。 -/
def factFree : ScopeState := ⟨⟨[], 0⟩, []⟩

/-- 出現の番号 k の文の始まりの記録の状態を、全て集める（番号の重複を仮定しない）。 -/
def statesAt (records : Records) (k : Key) : List ScopeState :=
  (records.filter (fun p => decide (p.1 = k))).map (·.2)

theorem mem_statesAt {records : Records} {k : Key} {st : ScopeState} :
    st ∈ statesAt records k ↔ (k, st) ∈ records := by
  unfold statesAt
  rw [List.mem_map]
  constructor
  · rintro ⟨⟨k', st'⟩, hm, he⟩
    have hm' := List.mem_filter.mp hm
    have hk : k' = k := of_decide_eq_true hm'.2
    cases hk; cases he; exact hm'.1
  · intro h
    exact ⟨(k, st), List.mem_filter.mpr ⟨h, decide_eq_true rfl⟩, rfl⟩

/-- 列の全ての要素が通ることの判定。最初に通らなかった要素の誤りを返す。 -/
def allOk {α ε : Type} : List α → (α → Except ε Unit) → Except ε Unit
  | [], _ => .ok ()
  | x :: xs, f =>
    match f x with
    | .ok () => allOk xs f
    | .error e => .error e

/-- 状態 st で規則の `index` が選ぶ範囲を、位置ごとの必須の判定の結果に読む。 -/
def requiredAt (T : ScopeTable Refinement.Val) (exceeded : Bool) (rule : ScopeRule Refinement.Val) (xs : List Arg)
    (st : ScopeState) : List (Option Required) :=
  (rule.index (xs.map (absArg T st))).map (fun r => some (Required.ofIndex exceeded r))

/-- Scope の規則を持つ出現 k の呼び出しの範囲の列 rs の受理。記録があれば全ての記録の状態で、なければ事実を持たない
状態で、規則が選ぶ範囲を各位置の契約が覆うことを確かめる。規則を持たない出現には制約を置かない（範囲は引数の型と
戻り値の注釈で決まる）。 -/
def acceptCall (T : ScopeTable Refinement.Val) (records : Records) (exceeded : Bool) (k : Key) (xs : List Arg)
    (rs : List Range) : Except CoverFailure Unit :=
  match T.ruleAt k with
  | none => .ok ()
  | some rule =>
    match statesAt records k with
    | [] => acceptRanges (requiredAt T exceeded rule xs factFree) rs
    | sts => allOk sts (fun st => acceptRanges (requiredAt T exceeded rule xs st) rs)

theorem allOk_ok {α ε : Type} {xs : List α} {f : α → Except ε Unit}
    (h : allOk xs f = .ok ()) : ∀ x ∈ xs, f x = .ok () := by
  induction xs with
  | nil => intro x hx; simp at hx
  | cons y ys ih =>
    intro x hx
    simp only [allOk] at h
    split at h
    · next hy =>
      rcases List.mem_cons.mp hx with rfl | hx
      · exact hy
      · exact ih h x hx
    · cases h

/-- 受理の健全性（記録の全称の形）。受理した呼び出しの位置 i の契約 S は、その出現の番号の**どの**記録の状態でも、
規則が選ぶ範囲（必須の判定の添字）を覆い、選ぶ範囲が由来の未知か予算の超過による Top なら S も Top である。 -/
theorem acceptCall_sound {T : ScopeTable Refinement.Val} {records : Records} {exceeded : Bool} {k : Key}
    {xs : List Arg} {rs : List Range} {rule : ScopeRule Refinement.Val}
    (h : acceptCall T records exceeded k xs rs = .ok ()) (hrule : T.ruleAt k = some rule) :
    ∀ st, (k, st) ∈ records → ∀ (i : Nat) (S r : Range), rs[i]? = some S →
      (rule.index (xs.map (absArg T st)))[i]? = some r → S.Covers r := by
  intro st hst i S r hS hr
  unfold acceptCall at h
  rw [hrule] at h
  have hmem : st ∈ statesAt records k := mem_statesAt.mpr hst
  have hq : (requiredAt T exceeded rule xs st)[i]? = some (some (Required.ofIndex exceeded r)) := by
    simp [requiredAt, hr]
  have hacc : acceptRanges (requiredAt T exceeded rule xs st) rs = .ok () := by
    cases hs : statesAt records k with
    | nil => rw [hs] at hmem; simp at hmem
    | cons s ss =>
      rw [hs] at h hmem
      exact allOk_ok h st hmem
  have := acceptRange_sound (acceptRanges_sound hacc i S _ hS hq)
  simpa using this

private theorem acceptCall_unrecorded_ok {T : ScopeTable Refinement.Val} {records : Records} {exceeded : Bool} {k : Key}
    {xs : List Arg} {rs : List Range} {rule : ScopeRule Refinement.Val}
    (h : acceptCall T records exceeded k xs rs = .ok ()) (hrule : T.ruleAt k = some rule)
    (hnone : ∀ st, (k, st) ∉ records) :
    acceptRanges (requiredAt T exceeded rule xs factFree) rs = .ok () := by
  unfold acceptCall at h
  rw [hrule] at h
  have hs : statesAt records k = [] := by
    apply List.eq_nil_iff_forall_not_mem.mpr
    intro st hst
    exact hnone st (mem_statesAt.mp hst)
  simpa only [hs] using h

/-- 記録のない出現（解析が辿らない式の中の呼び出しなど）は、事実を持たない状態で選んだ範囲を覆う契約だけを受理する。 -/
theorem acceptCall_sound_unrecorded {T : ScopeTable Refinement.Val} {records : Records} {exceeded : Bool} {k : Key}
    {xs : List Arg} {rs : List Range} {rule : ScopeRule Refinement.Val}
    (h : acceptCall T records exceeded k xs rs = .ok ()) (hrule : T.ruleAt k = some rule)
    (hnone : ∀ st, (k, st) ∉ records) :
    ∀ (i : Nat) (S r : Range), rs[i]? = some S → (rule.index (xs.map (absArg T factFree)))[i]? = some r →
      S.Covers r := by
  intro i S r hS hr
  have hacc := acceptCall_unrecorded_ok h hrule hnone
  have hq : (requiredAt T exceeded rule xs factFree)[i]? = some (some (Required.ofIndex exceeded r)) := by
    simp [requiredAt, hr]
  simpa using acceptRange_sound (acceptRanges_sound hacc i S _ hS hq)

/-- 記録のない出現でも、事実を持たない状態で規則が選ぶ全ての位置に契約がある。 -/
theorem acceptCall_some_unrecorded {T : ScopeTable Refinement.Val} {records : Records} {exceeded : Bool} {k : Key}
    {xs : List Arg} {rs : List Range} {rule : ScopeRule Refinement.Val}
    (h : acceptCall T records exceeded k xs rs = .ok ()) (hrule : T.ruleAt k = some rule)
    (hnone : ∀ st, (k, st) ∉ records) :
    ∀ (i : Nat) (r : Range), (rule.index (xs.map (absArg T factFree)))[i]? = some r → ∃ S, rs[i]? = some S := by
  intro i r hr
  have hacc := acceptCall_unrecorded_ok h hrule hnone
  have hq : (requiredAt T exceeded rule xs factFree)[i]? = some (some (Required.ofIndex exceeded r)) := by
    simp [requiredAt, hr]
  exact acceptRanges_some hacc i _ hq

/-- 受理した呼び出しの範囲の列は、記録のどの状態でも規則が範囲を選ぶ全ての位置に契約の範囲を持つ。 -/
theorem acceptCall_some {T : ScopeTable Refinement.Val} {records : Records} {exceeded : Bool} {k : Key}
    {xs : List Arg} {rs : List Range} {rule : ScopeRule Refinement.Val}
    (h : acceptCall T records exceeded k xs rs = .ok ()) (hrule : T.ruleAt k = some rule) :
    ∀ st, (k, st) ∈ records → ∀ (i : Nat) (r : Range),
      (rule.index (xs.map (absArg T st)))[i]? = some r → ∃ S, rs[i]? = some S := by
  intro st hst i r hr
  unfold acceptCall at h
  rw [hrule] at h
  have hmem : st ∈ statesAt records k := mem_statesAt.mpr hst
  have hq : (requiredAt T exceeded rule xs st)[i]? = some (some (Required.ofIndex exceeded r)) := by
    simp [requiredAt, hr]
  have hacc : acceptRanges (requiredAt T exceeded rule xs st) rs = .ok () := by
    cases hs : statesAt records k with
    | nil => rw [hs] at hmem; simp at hmem
    | cons s ss =>
      rw [hs] at h hmem
      exact allOk_ok h st hmem
  exact acceptRanges_some hacc i _ hq

/-! ## 本体の受理 -/

/-- 本体の出現と番号の組（区間解析と同じ先行順。`Surface.ScopeLower.analyzeBody` の記録の番号と同じ数え方）。 -/
def occurrences (key : Key) (body : Block) : List (Key × Expr) :=
  (Identity.preorderBlock body).zipIdx key.surfacePreorder |>.map fun (e, i) => (⟨key.definition, i⟩, e)

/-- 局所解析が扱う、閉じた絶対範囲の列を取り出す。 -/
def absoluteRanges : List RangeIx → Option (List Range)
  | [] => some []
  | .fixed (.absolute r) :: xs => (absoluteRanges xs).map (r :: ·)
  | _ => none

@[simp] theorem absoluteRanges_fixed (rs : List Range) :
    absoluteRanges (rs.map (fun r => RangeIx.fixed (.absolute r))) = some rs := by
  induction rs <;> simp_all [absoluteRanges]

theorem absoluteRanges_some {xs : List RangeIx} {rs : List Range}
    (h : absoluteRanges xs = some rs) : xs = rs.map (fun r => RangeIx.fixed (.absolute r)) := by
  induction xs generalizing rs with
  | nil => cases h; rfl
  | cons x xs ih =>
    cases x with
    | rvar _ => cases h
    | fixed r =>
      cases r with
      | based _ _ | secrets => cases h
      | absolute r =>
        simp only [absoluteRanges, Option.map_eq_some_iff] at h
        obtain ⟨rest, hr, rfl⟩ := h
        simp only [List.map_cons]
        exact congrArg (List.cons _) (ih hr)

/-- 一つの出現の受理。閉じた絶対範囲を持つ直接の呼出しを、局所解析の記録で照合する。 -/
def acceptOccurrence (T : ScopeTable Refinement.Val) (records : Records) (exceeded : Bool) (k : Key) :
    Expr → Except CoverFailure Unit
  | .call (.primName b ts es ix) _ positions args =>
    match absoluteRanges ix with
    | none => match T.ruleAt k with | none => .ok () | some _ => .error .unknownSource
    | some rs =>
      match contractOrder positions (lowerArgs (argsKey k (.primName b ts es ix)) args) with
      | some xs => acceptCall T records exceeded k xs rs
      | none => acceptCall T records exceeded k [] rs
  | _ => .ok ()

/-- 定義の本体の受理。Scope の局所解析を一度走らせ、全ての出現の呼び出しを記録と照らす。最初に拒否した出現の番号と
理由を返す。 -/
def acceptBody (ok : ConName) (T : ScopeTable Refinement.Val) (L : Limits) (key : Key)
    (scope : Interval.BindingScope) (body : Block) : Except (Key × CoverFailure) Unit :=
  let result := analyzeBody ok T L key scope body
  let exceeded := result.1.exceeded.isSome
  allOk (occurrences key body) fun p =>
    match acceptOccurrence T result.2 exceeded p.1 p.2 with
    | .ok () => .ok ()
    | .error f => .error (p.1, f)

theorem acceptBody_occurrence {ok : ConName} {T : ScopeTable Refinement.Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (h : acceptBody ok T L key scope body = .ok ()) :
    ∀ k e, (k, e) ∈ occurrences key body →
      acceptOccurrence T (analyzeBody ok T L key scope body).2 (analyzeBody ok T L key scope body).1.exceeded.isSome
        k e = .ok () := by
  unfold acceptBody at h
  intro k e he
  have := allOk_ok h _ he
  simp only at this
  split at this
  · next hok => exact hok
  · cases this

/-- 本体の受理の健全性。受理した本体の、Scope の規則を持つ直接の呼び出しの範囲の列は、その出現の全ての記録の状態で
規則が選ぶ範囲を各位置で覆う。 -/
theorem acceptBody_sound {ok : ConName} {T : ScopeTable Refinement.Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (h : acceptBody ok T L key scope body = .ok ())
    {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions args xs}
    (hocc : (k, .call (.primName b ts es (rs.map (fun r => RangeIx.fixed (.absolute r)))) labels positions args) ∈ occurrences key body)
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es (rs.map (fun r => RangeIx.fixed (.absolute r))))) args) = some xs)
    {rule : ScopeRule Refinement.Val} (hrule : T.ruleAt k = some rule) :
    ∀ st, (k, st) ∈ (analyzeBody ok T L key scope body).2 → ∀ (i : Nat) (S r : Range), rs[i]? = some S →
      (rule.index (xs.map (absArg T st)))[i]? = some r → S.Covers r := by
  have := acceptBody_occurrence h _ _ hocc
  simp only [acceptOccurrence, absoluteRanges_fixed, hxs] at this
  exact acceptCall_sound this hrule

/-- 受理した本体の規則付きの呼び出しの範囲の列は、記録のどの状態でも規則が範囲を選ぶ全ての位置に契約の範囲を持つ
。 -/
theorem acceptBody_some {ok : ConName} {T : ScopeTable Refinement.Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (h : acceptBody ok T L key scope body = .ok ())
    {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions args xs}
    (hocc : (k, .call (.primName b ts es (rs.map (fun r => RangeIx.fixed (.absolute r)))) labels positions args) ∈ occurrences key body)
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es (rs.map (fun r => RangeIx.fixed (.absolute r))))) args) = some xs)
    {rule : ScopeRule Refinement.Val} (hrule : T.ruleAt k = some rule) :
    ∀ st, (k, st) ∈ (analyzeBody ok T L key scope body).2 → ∀ (i : Nat) (r : Range),
      (rule.index (xs.map (absArg T st)))[i]? = some r → ∃ S, rs[i]? = some S := by
  have := acceptBody_occurrence h _ _ hocc
  simp only [acceptOccurrence, absoluteRanges_fixed, hxs] at this
  exact acceptCall_some this hrule


/-- 記録のない本体の出現では、事実を持たない状態で選ぶ範囲を契約が覆う。 -/
theorem acceptBody_sound_unrecorded {ok : ConName} {T : ScopeTable Refinement.Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (h : acceptBody ok T L key scope body = .ok ())
    {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions args xs}
    (hocc : (k, .call (.primName b ts es (rs.map (fun r => RangeIx.fixed (.absolute r)))) labels positions args) ∈ occurrences key body)
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es (rs.map (fun r => RangeIx.fixed (.absolute r))))) args) = some xs)
    {rule : ScopeRule Refinement.Val} (hrule : T.ruleAt k = some rule)
    (hnone : ∀ st, (k, st) ∉ (analyzeBody ok T L key scope body).2) :
    ∀ (i : Nat) (S r : Range), rs[i]? = some S →
      (rule.index (xs.map (absArg T factFree)))[i]? = some r → S.Covers r := by
  have hc := acceptBody_occurrence h _ _ hocc
  simp only [acceptOccurrence, absoluteRanges_fixed, hxs] at hc
  exact acceptCall_sound_unrecorded hc hrule hnone

/-- 記録のない本体の出現でも、規則が選ぶ全ての位置に契約がある。 -/
theorem acceptBody_some_unrecorded {ok : ConName} {T : ScopeTable Refinement.Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (h : acceptBody ok T L key scope body = .ok ())
    {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions args xs}
    (hocc : (k, .call (.primName b ts es (rs.map (fun r => RangeIx.fixed (.absolute r)))) labels positions args) ∈ occurrences key body)
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es (rs.map (fun r => RangeIx.fixed (.absolute r))))) args) = some xs)
    {rule : ScopeRule Refinement.Val} (hrule : T.ruleAt k = some rule)
    (hnone : ∀ st, (k, st) ∉ (analyzeBody ok T L key scope body).2) :
    ∀ (i : Nat) (r : Range), (rule.index (xs.map (absArg T factFree)))[i]? = some r → ∃ S, rs[i]? = some S := by
  have hc := acceptBody_occurrence h _ _ hocc
  simp only [acceptOccurrence, absoluteRanges_fixed, hxs] at hc
  exact acceptCall_some_unrecorded hc hrule hnone

/-- 選んだ規則がある全ての出現について、未具体化の契約も検査から除外しない。
成功時には各位置の絶対範囲の証人を返すので、任意の範囲具体化でも同じ被覆が成り立つ。 -/
theorem acceptBody_ranges {ok : ConName} {T : ScopeTable Refinement.Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (h : acceptBody ok T L key scope body = .ok ())
    {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff} {ix : List RangeIx} {labels positions args xs}
    (hocc : (k, .call (.primName b ts es ix) labels positions args) ∈ occurrences key body)
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es ix)) args) = some xs)
    {rule : ScopeRule Refinement.Val} (hrule : T.ruleAt k = some rule) :
    (∀ st, (k, st) ∈ (analyzeBody ok T L key scope body).2 → ∀ (i : Nat) (r : Range),
      (rule.index (xs.map (absArg T st)))[i]? = some r →
      ∃ S, ix[i]? = some (.fixed (.absolute S)) ∧ S.Covers r) ∧
    ((∀ st, (k, st) ∉ (analyzeBody ok T L key scope body).2) → ∀ (i : Nat) (r : Range),
      (rule.index (xs.map (absArg T factFree)))[i]? = some r →
      ∃ S, ix[i]? = some (.fixed (.absolute S)) ∧ S.Covers r) := by
  have hc := acceptBody_occurrence h _ _ hocc
  cases habs : absoluteRanges ix with
  | none => simp only [acceptOccurrence, habs, hrule, reduceCtorEq] at hc
  | some rs =>
    have heq := absoluteRanges_some habs
    subst ix
    constructor
    · intro st hst i r hr
      obtain ⟨S, hS⟩ := acceptBody_some h hocc hxs hrule st hst i r hr
      exact ⟨S, by simp only [List.getElem?_map, hS, Option.map_some],
        acceptBody_sound h hocc hxs hrule st hst i S r hS hr⟩
    · intro hnone i r hr
      obtain ⟨S, hS⟩ := acceptBody_some_unrecorded h hocc hxs hrule hnone i r hr
      exact ⟨S, by simp only [List.getElem?_map, hS, Option.map_some],
        acceptBody_sound_unrecorded h hocc hxs hrule hnone i S r hS hr⟩

/-- 全出現で、閉じた規則が選ぶ範囲の契約と被覆がある。未記録の出現も事実を持たない状態で含める。 -/
def BodyRanges (ok : ConName) (T : ScopeTable Refinement.Val) (L : Limits) (key : Key)
    (scope : Interval.BindingScope) (body : Block) : Prop :=
  let records := (analyzeBody ok T L key scope body).2
  ∀ (k : Key) (b : PrimName) (ts : List Ty) (es : List Eff) (ix : List RangeIx)
      (labels : List (Option String)) (positions : List Nat) (args : Exprs) (xs : List Arg)
      (rule : ScopeRule Refinement.Val),
    (k, .call (.primName b ts es ix) labels positions args) ∈ occurrences key body →
    contractOrder positions (lowerArgs (argsKey k (.primName b ts es ix)) args) = some xs →
    T.ruleAt k = some rule →
    (∀ st, (k, st) ∈ records → ∀ (i : Nat) (r : Range),
      (rule.index (xs.map (absArg T st)))[i]? = some r →
      ∃ S, ix[i]? = some (.fixed (.absolute S)) ∧ S.Covers r) ∧
    ((∀ st, (k, st) ∉ records) → ∀ (i : Nat) (r : Range),
      (rule.index (xs.map (absArg T factFree)))[i]? = some r →
      ∃ S, ix[i]? = some (.fixed (.absolute S)) ∧ S.Covers r)

/-- 閉じた規則による受理から、全出現をまとめた範囲の契約を得る。 -/
theorem acceptBody_ranges_all {ok T L key scope body}
    (h : acceptBody ok T L key scope body = .ok ()) : BodyRanges ok T L key scope body := by
  intro k b ts es ix labels positions args xs rule hocc hxs hrule
  exact acceptBody_ranges h hocc hxs hrule

/-! ## 規則を持つ表による受理と拒否 -/

namespace Examples

/-- リテラルのパターンから範囲を一つ選び、それ以外は Top を選ぶ一引数の規則。
実行は渡された引数を返し、結果の由来は登録しない。 -/
private def rule : ScopeRule Refinement.Val where
  index := fun args => [match args with
    | [.lit "/data/**"] => .path (.tree ["data"])
    | _ => .top]
  run := fun _ values => values.head?
  transfer := fun _ _ => none

private def table : ScopeTable Refinement.Val :=
  standardTable (fun _ => some ⟨.standard, "Example.range"⟩)
    (fun name => if name = "Example.range" then some rule else none)

private def limits : Limits := ⟨⟨100, 100⟩, ⟨100, 100⟩⟩

private def body (contract : Range) (arg : Expr) : Block :=
  .last (.call (.primName "Example.range" [] [] [.fixed (.absolute contract)]) [none] [0] (.cons arg .nil))

/-- 非空の規則表が実際の値を返す入力を持つ。 -/
example : table.ruleAt ⟨"Example.body", 0⟩ = some rule ∧
    rule.run [.path (.tree ["data"])] [.const (.string "/data/**")] = some (.const (.string "/data/**")) :=
  ⟨by rfl, by rfl⟩

/-- 推論した範囲を覆う契約を受理する。 -/
example : acceptBody "Ok" table limits ⟨"Example.body", 0⟩ ⟨[], 0⟩
    (body (.path (.tree ["data"])) (.literal (.string "/data/**"))) = .ok () := by rfl

/-- 同じ入力と規則で、別の範囲の契約を拒否する。 -/
example : acceptBody "Ok" table limits ⟨"Example.body", 0⟩ ⟨[], 0⟩
    (body (.path (.tree ["other"])) (.literal (.string "/data/**"))) =
      .error (⟨"Example.body", 0⟩, .notCovered) := by rfl

/-- 由来のない局所に狭い契約を与えると、未知として拒否する。 -/
example : acceptBody "Ok" table limits ⟨"Example.body", 0⟩ ⟨[0], 1⟩
    (body (.path (.tree ["data"])) (.local 0)) =
      .error (⟨"Example.body", 0⟩, .unknownSource) := by rfl

/-- 同じ由来のない局所には Top の契約を受理する。 -/
example : acceptBody "Ok" table limits ⟨"Example.body", 0⟩ ⟨[0], 1⟩
    (body .top (.local 0)) = .ok () := by rfl

/-- 予算の超過ではTopを受理し、同じ状態の狭い契約は専用の理由で拒否する。 -/
example : acceptRange .exceeded .top = .ok () ∧
    acceptRange .exceeded (.path (.tree ["data"])) = .error .budgetExceeded :=
  ⟨acceptRange_top _, acceptRange_exceeded (by intro h; cases h)⟩

end Examples

end Benitoite.Release.Refinement.Surface.ScopeAccept
