import Benitoite.Surface.ScopeLower
import Benitoite.Release.EffectCover
import Benitoite.Release.TargetTable

/-!
# 型検査器の必須の判定の受理と拒否の理由（L40.4）

表層の組み込みの名前 `primName b ts es rs` の範囲の列 `rs` は型検査器が選ぶ。本ファイルは、その選び方の条件を
Scope の局所解析（`Surface.ScopeLower.analyzeBody`）の結果から定め、狭い契約（Top でない範囲）を、必須の判定の結果を
被覆で確かめたときだけ受理する判定と、拒否の理由（DET-05 の列挙）を置く（設計書 01-12「Scope の必須の判定の受理と拒否の理由」）。

- 範囲の受理 `acceptRange`: 必須の判定が既知の範囲 r を返した位置では、契約の範囲 S が r を覆うときだけ受理する。
  未知・予算の超過の位置では Top の契約だけを受理する。Top を覆うのは Top だけである（`/**` も Top を覆わない）。
- 原子の受理 `acceptAtom`: 効果の原子 a を、上限の原子の並びのどれか一原子が覆うときだけ受理する。和による被覆は
  判定しない。構造上の包含（Release の `Eff.Sub`）が成り立つ原子は必ず受理する（`acceptAtom_of_mem`）。受理は
  型付けの規則の包含を置き換えない（Release の C-Sub と `Eff.Sub` は構造上の包含のまま）。
- 呼び出しの受理 `acceptCall`・`acceptBody`: Scope の規則を持つ呼び出し（検査・射影・拡大）の範囲の列を、その
  出現の番号の文の始まりの記録の**全て**の状態で規則の `index` が選ぶ範囲と照らす（記録の番号の重複を仮定しない）。
  記録のない出現（解析が辿らない式の中の呼び出し）は外側の文の記録を使わず、事実を持たない状態で選ぶ（リテラルと
  `const` の直接参照だけが既知になる）。
- 明示拡大の行き先 S は、戻り値の注釈（期待される型）の範囲から一意に決まる（`widenRanges`）。

受理の判定は Scope の局所解析の記録だけを読み、後段の区間解析（`Interval.Eval`・`RangeState`）の結果を読まない。
本モジュールは区間解析の評価と警告のモジュールを import しない。
-/

namespace Benitoite.Surface.ScopeAccept

open Benitoite.Release
open Benitoite.Scope.Inference
open Benitoite.Surface.ScopeState
open Benitoite.Surface.ScopeLower
open Scope.Domain (Range)

/-! ## 拒否の理由と必須の判定の結果 -/

/-- 範囲の被覆を確認できなかった理由（DET-05。診断 E0519 の `reason`）。`notCovered` は既知の範囲を契約が覆わない、
`atomicCoverOnly` は一原子ずつの被覆では確認できない（複数の原子の和なら覆いうる）、`unknownSource` は由来を
認定できず Top になった、`budgetExceeded` は必須の判定の予算を超えて Top になった。 -/
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

/-- 型の添字。未知と予算の超過は Top（判断 9）。 -/
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

/-- 未知・予算の超過の位置で受理する契約は Top だけである。 -/
theorem acceptRange_top_of_not_known {q : Required} {S : Range} (h : acceptRange q S = .ok ())
    (hq : ∀ r, q ≠ .known r) : S = .top := by
  by_cases hs : S = .top
  · exact hs
  · cases q with
    | known r => exact absurd rfl (hq r)
    | unknown | exceeded => simp [acceptRange, hs] at h

/-- Top を覆うのは Top だけである。必須の判定の添字が Top なら、受理する契約も Top である。 -/
theorem acceptRange_top_only {q : Required} {S : Range} (h : acceptRange q S = .ok ()) (hq : q.index = .top) :
    S = .top :=
  (Range.covers_top_iff S).mp (hq ▸ acceptRange_sound h)

/-- 既知の範囲を覆う契約は受理する（判定は一つの範囲どうしについて完全）。 -/
theorem acceptRange_of_covers {r S : Range} (h : S.Covers r) : acceptRange (.known r) S = .ok () := by
  unfold acceptRange
  split
  · rfl
  · simp [h]

/-- Top の契約はいつも受理する（旧の Top の範囲）。 -/
@[simp] theorem acceptRange_top (q : Required) : acceptRange q .top = .ok () := by simp [acceptRange]

/-- 拒否の理由の対応。 -/
theorem acceptRange_unknown {S : Range} (hs : S ≠ .top) : acceptRange .unknown S = .error .unknownSource := by
  simp [acceptRange, hs]

theorem acceptRange_exceeded {S : Range} (hs : S ≠ .top) : acceptRange .exceeded S = .error .budgetExceeded := by
  simp [acceptRange, hs]

theorem acceptRange_notCovered {r S : Range} (hs : S ≠ .top) (hc : ¬ S.Covers r) :
    acceptRange (.known r) S = .error .notCovered := by
  simp [acceptRange, hs, hc]

/-- 列の先頭の位置の受理。必須の判定の結果が `some q` なら `acceptRange q`、`none`（規則がその位置を選ばない。明示拡大の
行き先など）なら制約を置かない。 -/
def acceptHead (qs : List (Option Required)) (S : Range) : Except CoverFailure Unit :=
  match qs.head? with
  | some (some q) => acceptRange q S
  | _ => .ok ()

/-- 範囲の列の受理。各位置を `acceptHead` で確かめる。規則が範囲を選ぶ位置（`some q`）に契約の範囲がない（範囲の列が
短い）なら、推論した範囲を覆う契約がないので `notCovered` で拒否する（RV-L40 軽4。型付けの `RangeAdmissible` が
列の長さを署名の範囲の変数の数に合わせるので、型付く呼び出しでは起きない）。 -/
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

/-- 受理した範囲の列は、規則が範囲を選ぶ全ての位置に契約の範囲を持つ（RV-L40 軽4）。 -/
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

/-- 範囲の列の受理の特徴付け。第一の連言は、各位置の契約が規則の選ぶ範囲を `acceptRange` で受理すること（L40.6 の後の
判定が確かめた条件と同じ形）であり、第二の連言は RV-L40 軽4 で加えた長さの条件（規則が範囲を選ぶ位置は列の中にある）で
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

/-! ## 原子の受理（効果の上限） -/

/-- 一原子ずつの被覆で確認できなかった原子の理由。Top の原子（範囲の位置が Top の名前の原子）は、由来が未知か予算の
超過なら `unknownSource`・`budgetExceeded`、既知なら `notCovered`（Top を覆うのは Top だけ）。閉じた範囲の原子は、上限に
同じ名前の閉じた範囲の原子が二つ以上あれば `atomicCoverOnly`（和なら覆いうるが判定しない）、そうでなければ
`notCovered`。 -/
def atomFailure (upper : List Atom) (src : Required) : Atom → CoverFailure
  | .name l (.fixed r) =>
    if r = .top then
      match src with
      | .unknown => .unknownSource
      | .exceeded => .budgetExceeded
      | .known _ => .notCovered
    else if 2 ≤ (upper.filter (fun b => match b with
        | .name m (.fixed s) => decide (m = l) && decide (s ≠ .top)
        | _ => false)).length then .atomicCoverOnly
    else .notCovered
  | _ => .notCovered

/-- 効果の原子 a を上限の原子の並びのもとで受理するか。src は a の範囲の位置の由来。 -/
def acceptAtom (upper : List Atom) (src : Required) (a : Atom) : Except CoverFailure Unit :=
  if upper.any (fun b => b.covers? a) then .ok () else .error (atomFailure upper src a)

/-- 受理した原子は、上限のどれか一原子に覆われる。 -/
theorem acceptAtom_sound {upper : List Atom} {src : Required} {a : Atom} (h : acceptAtom upper src a = .ok ()) :
    ∃ b ∈ upper, b.Covers a := by
  unfold acceptAtom at h
  split at h
  · next hany =>
    obtain ⟨b, hb, hc⟩ := List.any_eq_true.mp hany
    exact ⟨b, hb, (Atom.covers?_spec b a).mp hc⟩
  · cases h

/-- 一原子に覆われる原子は受理する。 -/
theorem acceptAtom_of_covers {upper : List Atom} {src : Required} {a b : Atom} (hb : b ∈ upper) (hc : b.Covers a) :
    acceptAtom upper src a = .ok () := by
  unfold acceptAtom
  have hany : upper.any (fun b => b.covers? a) = true :=
    List.any_eq_true.mpr ⟨b, hb, (Atom.covers?_spec b a).mpr hc⟩
  simp only [hany, ↓reduceIte]

/-- 構造上の包含（同じ原子が上限にある）なら受理する。受理は Release の `Eff.Sub` より弱い必要条件である。 -/
theorem acceptAtom_of_mem {upper : List Atom} {src : Required} {a : Atom} (ha : a ∈ upper) :
    acceptAtom upper src a = .ok () :=
  acceptAtom_of_covers ha (Atom.Covers.refl a)

/-- Top の原子を受理するのは、上限に同じ名前の Top の原子があるときだけである（`/**` の原子も Top を覆わない）。 -/
theorem acceptAtom_nameTop {upper : List Atom} {src : Required} {l : EffName}
    (h : acceptAtom upper src (.nameTop l) = .ok ()) : Atom.nameTop l ∈ upper := by
  obtain ⟨b, hb, hc⟩ := acceptAtom_sound h
  rwa [(Atom.covers_nameTop_iff).mp hc] at hb

/-- 原子の並びの受理。最初に受理しなかった原子と理由を返す。 -/
def acceptAtoms (upper : List Atom) : List (Atom × Required) → Except (Atom × CoverFailure) Unit
  | [] => .ok ()
  | (a, src) :: rest =>
    match acceptAtom upper src a with
    | .ok () => acceptAtoms upper rest
    | .error f => .error (a, f)

theorem acceptAtoms_sound {upper : List Atom} :
    ∀ {needs : List (Atom × Required)}, acceptAtoms upper needs = .ok () → ∀ p ∈ needs, ∃ b ∈ upper, b.Covers p.1
  | [], _, _, hp => by simp at hp
  | (a, src) :: rest, h, p, hp => by
    simp only [acceptAtoms] at h
    split at h
    · next ha =>
      rcases List.mem_cons.mp hp with rfl | hp
      · exact acceptAtom_sound ha
      · exact acceptAtoms_sound h p hp
    · cases h

/-! ## 呼び出しの受理（必須の判定の結果を型の制約へ渡す） -/

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
def requiredAt (T : ScopeTable Release.Val) (exceeded : Bool) (rule : ScopeRule Release.Val) (xs : List Arg)
    (st : ScopeState) : List (Option Required) :=
  (rule.index (xs.map (absArg T st))).map (fun r => some (Required.ofIndex exceeded r))

/-- Scope の規則を持つ出現 k の呼び出しの範囲の列 rs の受理。記録があれば全ての記録の状態で、なければ事実を持たない
状態で、規則が選ぶ範囲を各位置の契約が覆うことを確かめる。規則を持たない出現には制約を置かない（範囲は引数の型と
戻り値の注釈で決まる）。 -/
def acceptCall (T : ScopeTable Release.Val) (records : Records) (exceeded : Bool) (k : Key) (xs : List Arg)
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
theorem acceptCall_sound {T : ScopeTable Release.Val} {records : Records} {exceeded : Bool} {k : Key}
    {xs : List Arg} {rs : List Range} {rule : ScopeRule Release.Val}
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

/-- 記録のない出現（解析が辿らない式の中の呼び出しなど）は、事実を持たない状態で選んだ範囲を覆う契約だけを受理する。 -/
theorem acceptCall_sound_unrecorded {T : ScopeTable Release.Val} {records : Records} {exceeded : Bool} {k : Key}
    {xs : List Arg} {rs : List Range} {rule : ScopeRule Release.Val}
    (h : acceptCall T records exceeded k xs rs = .ok ()) (hrule : T.ruleAt k = some rule)
    (hnone : ∀ st, (k, st) ∉ records) :
    ∀ (i : Nat) (S r : Range), rs[i]? = some S → (rule.index (xs.map (absArg T factFree)))[i]? = some r →
      S.Covers r := by
  intro i S r hS hr
  unfold acceptCall at h
  rw [hrule] at h
  have hs : statesAt records k = [] := by
    apply List.eq_nil_iff_forall_not_mem.mpr
    intro st hst
    exact hnone st (mem_statesAt.mp hst)
  rw [hs] at h
  have hq : (requiredAt T exceeded rule xs factFree)[i]? = some (some (Required.ofIndex exceeded r)) := by
    simp [requiredAt, hr]
  simpa using acceptRange_sound (acceptRanges_sound h i S _ hS hq)

/-- 受理した呼び出しの範囲の列は、記録のどの状態でも規則が範囲を選ぶ全ての位置に契約の範囲を持つ（RV-L40 軽4）。 -/
theorem acceptCall_some {T : ScopeTable Release.Val} {records : Records} {exceeded : Bool} {k : Key}
    {xs : List Arg} {rs : List Range} {rule : ScopeRule Release.Val}
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

/-- 受理の健全性（Top の由来）。由来が認定できず規則が Top を選んだ位置では、受理する契約は Top だけである。 -/
theorem acceptCall_top_of_top {T : ScopeTable Release.Val} {records : Records} {exceeded : Bool} {k : Key}
    {xs : List Arg} {rs : List Range} {rule : ScopeRule Release.Val}
    (h : acceptCall T records exceeded k xs rs = .ok ()) (hrule : T.ruleAt k = some rule)
    {st : ScopeState} (hst : (k, st) ∈ records) {i : Nat} {S : Range}
    (hS : rs[i]? = some S) (hr : (rule.index (xs.map (absArg T st)))[i]? = some .top) : S = .top :=
  (Range.covers_top_iff S).mp (acceptCall_sound h hrule st hst i S .top hS hr)

/-! ## 本体の受理 -/

/-- 本体の出現と番号の組（区間解析と同じ先行順。`Surface.ScopeLower.analyzeBody` の記録の番号と同じ数え方）。 -/
def occurrences (key : Key) (body : Block) : List (Key × Expr) :=
  (Interval.preorderBlock body).zipIdx key.surfacePreorder |>.map fun (e, i) => (⟨key.definition, i⟩, e)

/-- 一つの出現の受理。組み込みの名前を頭に持つ直接の呼び出しだけが範囲の列を持つ。 -/
def acceptOccurrence (T : ScopeTable Release.Val) (records : Records) (exceeded : Bool) (k : Key) :
    Expr → Except CoverFailure Unit
  | .call (.primName b ts es rs) _ positions args =>
    match contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) with
    | some xs => acceptCall T records exceeded k xs rs
    | none => acceptCall T records exceeded k [] rs
  | _ => .ok ()

/-- 定義の本体の受理。Scope の局所解析を一度走らせ、全ての出現の呼び出しを記録と照らす。最初に拒否した出現の番号と
理由を返す。 -/
def acceptBody (ok : Release.ConName) (T : ScopeTable Release.Val) (L : Limits) (key : Key)
    (scope : Interval.BindingScope) (body : Block) : Except (Key × CoverFailure) Unit :=
  let result := analyzeBody ok T L key scope body
  let exceeded := result.1.exceeded.isSome
  allOk (occurrences key body) fun p =>
    match acceptOccurrence T result.2 exceeded p.1 p.2 with
    | .ok () => .ok ()
    | .error f => .error (p.1, f)

theorem acceptBody_occurrence {ok : Release.ConName} {T : ScopeTable Release.Val} {L : Limits} {key : Key}
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
theorem acceptBody_sound {ok : Release.ConName} {T : ScopeTable Release.Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (h : acceptBody ok T L key scope body = .ok ())
    {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions args xs}
    (hocc : (k, .call (.primName b ts es rs) labels positions args) ∈ occurrences key body)
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some xs)
    {rule : ScopeRule Release.Val} (hrule : T.ruleAt k = some rule) :
    ∀ st, (k, st) ∈ (analyzeBody ok T L key scope body).2 → ∀ (i : Nat) (S r : Range), rs[i]? = some S →
      (rule.index (xs.map (absArg T st)))[i]? = some r → S.Covers r := by
  have := acceptBody_occurrence h _ _ hocc
  simp only [acceptOccurrence, hxs] at this
  exact acceptCall_sound this hrule

/-- 受理した本体の規則付きの呼び出しの範囲の列は、記録のどの状態でも規則が範囲を選ぶ全ての位置に契約の範囲を持つ
（RV-L40 軽4。接続定理の範囲の位置の結論が、空の列で空に成り立たないことの根拠）。 -/
theorem acceptBody_some {ok : Release.ConName} {T : ScopeTable Release.Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (h : acceptBody ok T L key scope body = .ok ())
    {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions args xs}
    (hocc : (k, .call (.primName b ts es rs) labels positions args) ∈ occurrences key body)
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some xs)
    {rule : ScopeRule Release.Val} (hrule : T.ruleAt k = some rule) :
    ∀ st, (k, st) ∈ (analyzeBody ok T L key scope body).2 → ∀ (i : Nat) (r : Range),
      (rule.index (xs.map (absArg T st)))[i]? = some r → ∃ S, rs[i]? = some S := by
  have := acceptBody_occurrence h _ _ hocc
  simp only [acceptOccurrence, hxs] at this
  exact acceptCall_some this hrule

/-! ## 明示拡大の行き先 -/

/-- 明示拡大の範囲の列を、引数の型（元の範囲 R）と戻り値の注釈（期待される型。行き先 S）から決める。どちらかが
範囲付きの値型でなければ決まらない。 -/
def widenRanges : Ty → Ty → Option (List Range)
  | .opaque o (.fixed r), .opaque o' (.fixed s) => if o = o' then some [r, s] else none
  | _, _ => none

/-- 明示拡大の項目を具体化した戻りの型は、行き先の範囲そのものを持つ。 -/
theorem widenPathIn_inst_ret (r s : Range) :
    (TargetTable.widenPathIn.inst [r, s]).ret = .opaque "Scope.PathIn" (.fixed s) := by
  simp [PrimSig.inst, TargetTable.widenPathIn, TargetTable.pureIn, TargetTable.pathIn, Ty.instR, Ty.rawInstR,
    Scope.Signature.Ix.inst, Ty.norm]

theorem widenRequestIn_inst_ret (r s : Range) :
    (TargetTable.widenRequestIn.inst [r, s]).ret = .opaque "Http.RequestIn" (.fixed s) := by
  simp [PrimSig.inst, TargetTable.widenRequestIn, TargetTable.pureIn, TargetTable.requestIn, Ty.instR, Ty.rawInstR,
    Scope.Signature.Ix.inst, Ty.norm]

theorem widenPathIn_inst_params (r s : Range) :
    (TargetTable.widenPathIn.inst [r, s]).params = [.opaque "Scope.PathIn" (.fixed r)] := by
  simp [PrimSig.inst, TargetTable.widenPathIn, TargetTable.pureIn, TargetTable.pathIn, Ty.instTarget,
    Scope.Signature.Ix.inst]

/-- 明示拡大の行き先は戻り値の注釈から一意に決まる。許容される列（長さ 2）で具体化した戻りの型が同じなら、行き先の
範囲は同じである。 -/
theorem widenPathIn_target_unique {rs rs' : List Range} (hl : rs.length = 2) (hl' : rs'.length = 2)
    (h : (TargetTable.widenPathIn.inst rs).ret = (TargetTable.widenPathIn.inst rs').ret) : rs[1]? = rs'[1]? := by
  match rs, rs', hl, hl' with
  | [r, s], [r', s'], _, _ =>
    rw [widenPathIn_inst_ret, widenPathIn_inst_ret] at h
    simp only [Ty.opaque.injEq, Scope.Signature.Ix.fixed.injEq, true_and] at h
    simp [h]

/-- 引数の型と戻り値の注釈から決めた列は、具体化した署名の引数と戻りの型をそれぞれ与える列である。 -/
theorem widenRanges_pathIn {r s : Range} :
    widenRanges (.opaque "Scope.PathIn" (.fixed r)) (.opaque "Scope.PathIn" (.fixed s)) = some [r, s] ∧
      (TargetTable.widenPathIn.inst [r, s]).params = [.opaque "Scope.PathIn" (.fixed r)] ∧
      (TargetTable.widenPathIn.inst [r, s]).ret = .opaque "Scope.PathIn" (.fixed s) :=
  ⟨by simp [widenRanges], widenPathIn_inst_params r s, widenPathIn_inst_ret r s⟩

end Benitoite.Surface.ScopeAccept
