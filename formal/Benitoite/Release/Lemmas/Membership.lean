import Benitoite.Release.Model
import Benitoite.Release.Lemmas.MembershipBase

/-!
# 値の所属の葉の規則（V-Checked）の補題

設計書 01-12「型付け規則」の V-Checked（検査済みの対象の値 `checked(t)` は、名前 `O` の対象の種類が対象の種類に
合い、対象が範囲 R に所属するとき、範囲付きの値型 `O[R]` を持つ）について、次を置く。

- 逆転・範囲の拡大・閉じた値の標準形は `Release/Lemmas/MembershipBase.lean` にある（保存の証明が使うので前に置く）。
- 旧の像での同値: 対象の種類を持たない表（`valKind` が全て `none`）では V-Checked が使えず、範囲付きの値型の
  閉じた値は旧の不透明型の定数だけである。網羅性の値の形（`Inhabits`）に加えた検査済みの対象の値の場合は、
  範囲が Top の不透明型では網羅性の判断を変えない（`Exhaustive.opaqueTop_iff`）。
- 閉じた非 Top の値の小例: `/data/a.txt` の値が `PathIn["/data/**"]` の型を持つ。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins} {Q : NoFailCtx}

/-! ## 旧の像での同値 -/

/-- 表のどの不透明型の名前も対象の種類を持たない（旧の像の表。既存の不透明型と資源の型は `valKind = none`）。 -/
def Builtins.NoValKind (B : Builtins) : Prop := ∀ o, B.valKind o = none

/-- 対象の種類を持たない表では、検査済みの対象の値はどの型も持たない（V-Checked が使えない）。 -/
theorem HasTypeVQ.not_checked_of_noValKind (hB : B.NoValKind) {Ψ C Γ t T} :
    ¬ HasTypeVQ P B Ψ Q C Γ (.checked t) T := by
  intro h
  obtain ⟨o, _, _, hk, _⟩ := h.inv_checked rfl
  rw [hB o] at hk
  cases hk

/-- 対象の種類を持たない表では、検査済みの要求の値はどの型も持たない（V-CheckedRequest が使えない）。 -/
theorem HasTypeVQ.not_checkedRequest_of_noValKind (hB : B.NoValKind) {Ψ C Γ t c T} :
    ¬ HasTypeVQ P B Ψ Q C Γ (.checkedRequest t c) T := by
  intro h
  obtain ⟨o, _, _, _, hk, _⟩ := h.inv_checkedRequest rfl
  rw [hB o] at hk
  cases hk

/-- 値が保持する要求の型を持たない表（`valContent` が全て `none`。L40.3b の前の表と、`ModelTargets` の表）では、
検査済みの要求の値はどの型も持たない。 -/
def Builtins.NoValContent (B : Builtins) : Prop := ∀ o, B.valContent o = none

theorem HasTypeVQ.not_checkedRequest_of_noValContent (hB : B.NoValContent) {Ψ C Γ t c T} :
    ¬ HasTypeVQ P B Ψ Q C Γ (.checkedRequest t c) T := by
  intro h
  obtain ⟨o, _, _, _, _, _, hc, _⟩ := h.inv_checkedRequest rfl
  rw [hB o] at hc
  cases hc

/-- 対象の種類を持たない表では、不透明型の閉じた値は旧の不透明型の定数だけであり、型の範囲は Top である。 -/
theorem HasTypeVQ.canonical_opaque_of_noValKind (hB : B.NoValKind) {Ψ C v o ix}
    (h : HasTypeVQ P B Ψ Q C [] v (.opaque o ix)) :
    ∃ n, v = .const (.opaque o n) ∧ ix = .fixed .top := by
  rcases h.canonical_opaque with hc | ⟨t, _, rfl, _, _, _⟩ | ⟨t, _, c, _, rfl, _⟩
  · exact hc
  · exact absurd h (HasTypeVQ.not_checked_of_noValKind hB)
  · exact absurd h (HasTypeVQ.not_checkedRequest_of_noValKind hB)

/-- 範囲が Top の不透明型の閉じた値の集合は、表によらず旧の不透明型の定数の全てを含む。 -/
theorem HasTypeVQ.const_opaqueTop {Ψ C o n} :
    HasTypeVQ P B Ψ Q C [] (.const (.opaque o n)) (.opaqueTop o) := .V_Const

/-- `release_exists` の旧の像での同値。対象の種類を持たない表では、欄が量化する値（範囲が Top の資源の型の
閉じた値）はちょうど旧の不透明型の定数であり、欄は定数についての解放の応答の存在と同値である。 -/
theorem release_exists_iff_old (hB : B.NoValKind) :
    (∀ Ψ v o, HasTypeV P B Ψ [] [] v (.opaqueTop o) → B.isResource o = true → ∃ r, B.releaseResponse v r) ↔
      (∀ o n, B.isResource o = true → ∃ r, B.releaseResponse (.const (.opaque o n)) r) := by
  constructor
  · intro h o n hr
    exact h StoreTy.empty _ o HasTypeVQ.const_opaqueTop hr
  · intro h Ψ v o hv hr
    obtain ⟨n, rfl, -⟩ := hv.canonical_opaque_of_noValKind hB
    exact h o n hr

/-- 唯一の仮定の実例の表は、対象の種類を持たない。 -/
theorem Model.builtins_noValKind : Model.builtins.NoValKind := Model.builtins_valKind

/-! ## 網羅性の値の形 -/

/-- 不透明型に属する値は、その型の不透明型の定数か、範囲付きの値型の検査済みの対象の値か検査済みの要求の値で
ある。 -/
theorem Inhabits.opaque_iff {o ix v} :
    Inhabits P (.opaque o ix) v ↔
      (∃ c, v = .const c ∧ c.type = .opaque o ix) ∨ (∃ R t, ix = .fixed R ∧ v = .checked t) ∨
        (∃ R t c, ix = .fixed R ∧ v = .checkedRequest t c) := by
  constructor
  · intro h
    generalize ha : Ty.opaque o ix = a at h
    revert ha
    cases h with
    | const => intro _; exact .inl ⟨_, rfl, rfl⟩
    | checked => intro ha; cases ha; exact .inr (.inl ⟨_, _, rfl, rfl⟩)
    | checkedRequest => intro ha; cases ha; exact .inr (.inr ⟨_, _, _, rfl, rfl⟩)
    | _ => intro ha; cases ha
  · rintro (⟨c, rfl, hc⟩ | ⟨R, t, rfl, rfl⟩ | ⟨R, t, c, rfl, rfl⟩)
    · rw [← hc]; exact .const
    · exact .checked
    · exact .checkedRequest

/-- 旧の不透明型の定数に当たるパターンは、変数か `_` だけである（定数・範囲・構成子・リストのパターンは
不透明型の定数に当たらない）。 -/
theorem Pat.catchAll_of_matches_opaque {p : Pat} {o n}
    (h : (p.matchVal (.const (.opaque o n))).isSome) : p = .wild ∨ p = .var := by
  cases p with
  | wild => exact .inl rfl
  | var => exact .inr rfl
  | const c => cases c <;> simp [Pat.matchVal, Const.matches] at h
  | range lo hi => cases lo <;> cases hi <;> simp [Pat.matchVal, Const.inRange] at h
  | con c ps => simp [Pat.matchVal] at h
  | list b r a => simp [Pat.matchVal] at h

/-- 範囲が Top の不透明型の網羅性は、旧の判断（旧の値の形が属する値、すなわち不透明型の定数の全てに当たる
パターンがあること）と同値である。検査済みの対象の値の場合を加えても、旧の像の網羅性は変わらない。 -/
theorem Exhaustive.opaqueTop_iff {o ps} :
    Exhaustive P (.opaqueTop o) ps ↔ ∀ n, ∃ p ∈ ps, (p.matchVal (.const (.opaque o n))).isSome := by
  constructor
  · intro h n
    exact h _ (Inhabits.const (c := .opaque o n))
  · intro h v hv
    rcases Inhabits.opaque_iff.mp hv with ⟨c, rfl, hc⟩ | ⟨R, t, -, rfl⟩ | ⟨R, t, c, -, rfl⟩
    · cases c <;> simp [Const.type] at hc
      obtain ⟨rfl, -⟩ := hc
      exact h _
    · obtain ⟨p, hp, hm⟩ := h 0
      refine ⟨p, hp, ?_⟩
      rcases Pat.catchAll_of_matches_opaque hm with rfl | rfl <;> simp [Pat.matchVal]
    · obtain ⟨p, hp, hm⟩ := h 0
      refine ⟨p, hp, ?_⟩
      rcases Pat.catchAll_of_matches_opaque hm with rfl | rfl <;> simp [Pat.matchVal]

/-- 検査済みの対象の値に当たるパターンは、変数か `_` だけである。 -/
theorem Pat.catchAll_of_matches_checked {p : Pat} {t}
    (h : (p.matchVal (.checked t)).isSome) : p = .wild ∨ p = .var := by
  cases p with
  | wild => exact .inl rfl
  | var => exact .inr rfl
  | const c => simp [Pat.matchVal] at h
  | range lo hi => simp [Pat.matchVal] at h
  | con c ps => simp [Pat.matchVal] at h
  | list b r a => simp [Pat.matchVal] at h

/-- 不透明型の網羅性は、検査済みの要求の値の場合（V-CheckedRequest に対応する値の形。L40.3b）を除いて判断しても
同じである。範囲が Top の型では不透明型の定数が、Top でない型では検査済みの対象の値が既に属し、どちらにも当たるのは
変数か `_` のパターンだけなので、検査済みの要求の値にも当たる。 -/
theorem Exhaustive.opaque_iff_noRequest {o ix ps} :
    Exhaustive P (.opaque o ix) ps ↔
      ∀ v, Inhabits P (.opaque o ix) v → (∀ t c, v ≠ .checkedRequest t c) → ∃ p ∈ ps, (p.matchVal v).isSome := by
  constructor
  · intro h v hv _
    exact h v hv
  · intro h v hv
    rcases Inhabits.opaque_iff.mp hv with ⟨c, rfl, hc⟩ | ⟨R, t, -, rfl⟩ | ⟨R, t, c, rfl, rfl⟩
    · exact h _ hv (by intros; simp)
    · exact h _ hv (by intros; simp)
    · obtain ⟨p, hp, hm⟩ := h (.checked t) .checked (by intros; simp)
      refine ⟨p, hp, ?_⟩
      rcases Pat.catchAll_of_matches_checked hm with rfl | rfl <;> simp [Pat.matchVal]

/-! ## 閉じた非 Top の値の小例 -/

namespace MembershipExample

/-- 範囲付きの値型の名前 `Scope.PathIn` に種類 path を与えた表（ほかの欄は唯一の仮定の実例と同じ）。 -/
def builtins : Builtins := { Model.builtins with valKind := fun o => if o = "Scope.PathIn" then some .path else none }

/-- `/data/a.txt` の対象。 -/
def target : Scope.Domain.Target := .path ["data", "a.txt"]

/-- `/data/**` の範囲。 -/
def range : Scope.Domain.Range := .path (.tree ["data"])

/-- `/data/a.txt` の検査済みの対象の値は、本番の型付けで `PathIn["/data/**"]` の型を持つ。 -/
theorem checked_typed {P : Program} {Ψ : StoreTy} :
    HasTypeV P builtins Ψ [] [] (.checked target) (.opaque "Scope.PathIn" (.fixed range)) :=
  .V_Checked rfl (by decide)

/-- 同じ値は `PathIn["/database/**"]` の型を持たない（範囲に所属しない）。 -/
theorem not_typed_database {P : Program} {Ψ : StoreTy} :
    ¬ HasTypeV P builtins Ψ [] [] (.checked target) (.opaque "Scope.PathIn" (.fixed (.path (.tree ["database"])))) := by
  intro h
  obtain ⟨_, _, hT, _, hm⟩ := h.inv_checked rfl
  cases hT
  revert hm; decide

/-- 対象の種類を持たない名前（旧の不透明型）の型は持たない。 -/
theorem not_typed_other {P : Program} {Ψ : StoreTy} :
    ¬ HasTypeV P builtins Ψ [] [] (.checked target) (.opaque "File.Handle" (.fixed range)) := by
  intro h
  obtain ⟨_, _, hT, hk, _⟩ := h.inv_checked rfl
  cases hT
  simp [builtins] at hk

/-- 被覆による拡大: `/**` の範囲へ広げられる。 -/
theorem widened {P : Program} {Ψ : StoreTy} :
    HasTypeV P builtins Ψ [] [] (.checked target) (.opaque "Scope.PathIn" (.fixed (.path (.tree [])))) :=
  checked_typed.checked_widen_covers (by decide)

/-- 同じ表で、範囲付きの値型の閉じた値は Top の型へも広げられる。 -/
theorem widened_top {P : Program} {Ψ : StoreTy} :
    HasTypeV P builtins Ψ [] [] (.checked target) (.opaqueTop "Scope.PathIn") :=
  checked_typed.widen_opaque_top

/-- 範囲付きの値型の分岐のない `match` は網羅的でない（検査済みの対象の値が属する）。 -/
theorem not_exhaustive_nil {P : Program} : ¬ Exhaustive P (.opaque "Scope.PathIn" (.fixed range)) [] := by
  intro h
  obtain ⟨_, hp, _⟩ := h (.checked target) .checked
  cases hp

/-- `_` の選択肢があれば網羅的である。 -/
theorem exhaustive_wild {P : Program} : Exhaustive P (.opaque "Scope.PathIn" (.fixed range)) [.wild] :=
  fun _ _ => ⟨.wild, List.mem_singleton_self _, rfl⟩

end MembershipExample

end Benitoite.Release
