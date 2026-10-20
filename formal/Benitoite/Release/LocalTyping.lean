import Benitoite.Release.Typing
import Benitoite.Release.LocalRef

/-!
# 局所参照の種類と共有番号の対応

通常の型と分け、bound は局所環境、loc はストアの専用セルから分類する。
設計書 01-12「構築器の分類と環境の対応」に対応する。
-/
namespace Benitoite.Release

/-- 分類された専用番号が、構文上の局所深さに収まる。 -/
def LocalCtx.Scoped (Δ : LocalCtx) (depth : Nat) : Prop :=
  ∀ i k, Δ.kindAt i = some k → i < depth

theorem LocalCtx.Scoped.nil (depth : Nat) : Scoped [] depth := by
  intro i k hi; simp [kindAt] at hi

theorem LocalCtx.Scoped.extend {Δ depth} (h : Scoped Δ depth) (n : Nat) :
    Scoped (Δ.extend n) (depth + n) := by
  intro i k hi
  rw [kindAt_extend] at hi
  split at hi
  · cases hi
  · have := h (i - n) k hi; omega

theorem LocalCtx.Scoped.builder {Δ depth} (h : Scoped Δ depth) (kind : BuilderKind) :
    Scoped (some kind :: Δ) (depth + 1) := by
  intro i k hi
  cases i with
  | zero => omega
  | succ i => have := h i k (by simpa [kindAt] using hi); omega

/-- 現れる専用場所を許す範囲。通常の ref/lazy/cont には条件を課さない。 -/
def StoreTy.BuilderPlaces (Ψ : StoreTy) (places : Nat → Prop) : Prop :=
  ∀ l k, Ψ l = some (.builder k) → places l

theorem StoreTy.BuilderPlaces.hidden (Ψ : StoreTy) (places : Nat → Prop) :
    Ψ.hideBuilders.BuilderPlaces places := by
  intro l k hl
  cases hp : Ψ l with
  | none => simp [StoreTy.hideBuilders, hp] at hl
  | some x => cases x <;> simp [StoreTy.hideBuilders, hp] at hl

theorem LocalRef.HasKind.rename {Ψ Δ Δ' r k ξ} (h : HasKind Ψ Δ r k)
    (hξ : LocalRenOk Δ Δ' ξ) : HasKind Ψ Δ' (r.rename ξ) k := by
  cases h with
  | bound hi => exact .bound (hξ _ _ hi)
  | loc hl => exact .loc hl

theorem LocalRef.HasKind.subst {Ψ Δ Δ' r k ρ} (h : HasKind Ψ Δ r k)
    (hρ : LocalSubstOk Ψ Δ Δ' ρ) : HasKind Ψ Δ' (r.subst ρ) k := by
  cases h with
  | bound hi => exact hρ _ _ hi
  | loc hl => exact .loc hl

theorem LocalRef.HasKind.store {Ψ Ψ' Δ r k} (h : HasKind Ψ Δ r k)
    (hΨ : StoreTy.Sub Ψ Ψ') : HasKind Ψ' Δ r k := by
  cases h with
  | bound hi => exact .bound hi
  | loc hl => exact .loc (hΨ _ _ hl)

/-- 空の局所環境の型付き参照は、ストアに実在する専用の場所である。 -/
theorem LocalRef.HasKind.closed {Ψ r k} (h : HasKind Ψ [] r k) :
    ∃ l, r = .loc l ∧ Ψ l = some (.builder k) := by
  cases h with
  | bound hi => simp [LocalCtx.kindAt] at hi
  | loc hl => exact ⟨_, rfl, hl⟩

/-- 隠した専用場所はどの分類としても読めない。 -/
theorem hideBuilders_no_builder (Ψ : StoreTy) (l : Nat) (k : BuilderKind) :
    Ψ.hideBuilders l ≠ some (.builder k) := by
  cases hl : Ψ l with
  | none => simp [StoreTy.hideBuilders, hl]
  | some x => cases x <;> simp [StoreTy.hideBuilders, hl]

theorem LocalRenOk.empty (Δ' : LocalCtx) (ξ : Nat → Nat) : LocalRenOk [] Δ' ξ := by
  intro i k hi; simp [LocalCtx.kindAt] at hi

theorem LocalSubstOk.empty (Ψ : StoreTy) (Δ' : LocalCtx) (ρ : Nat → LocalRef) :
    LocalSubstOk Ψ [] Δ' ρ := by
  intro i k hi; simp [LocalCtx.kindAt] at hi

/-- 通常束縛を n 個加え、共有番号を同じ数だけずらす。 -/
theorem LocalRenOk.extend {Δ Δ' ξ} (h : LocalRenOk Δ Δ' ξ) (n : Nat) :
    LocalRenOk (Δ.extend n) (Δ'.extend n) (upRen n ξ) := by
  intro i k hi
  rw [LocalCtx.kindAt_extend] at hi ⊢
  by_cases hn : i < n
  · simp [hn] at hi
  · simp only [hn, ↓reduceIte] at hi
    have he := h (i - n) k hi
    simpa [upRen, hn, show ¬ ξ (i - n) + n < n by omega] using he

/-- 専用束縛も通常番号と同じ先頭に追加する。 -/
theorem LocalRenOk.builder {Δ Δ' ξ} (h : LocalRenOk Δ Δ' ξ) (kind : BuilderKind) :
    LocalRenOk (some kind :: Δ) (some kind :: Δ') (upRen 1 ξ) := by
  intro i k hi
  cases i with
  | zero => simpa [LocalCtx.kindAt, upRen] using hi
  | succ i =>
      have he := h i k (by simpa [LocalCtx.kindAt] using hi)
      simpa [LocalCtx.kindAt, upRen, Nat.add_comm] using he

theorem LocalRenOk.shift (Δ : LocalCtx) (n : Nat) : LocalRenOk Δ (Δ.extend n) (· + n) := by
  intro i k hi
  simpa [LocalCtx.kindAt_extend, show ¬ i + n < n by omega] using hi

theorem LocalSubstOk.extend {Ψ Δ Δ' ρ} (h : LocalSubstOk Ψ Δ Δ' ρ) (n : Nat) :
    LocalSubstOk Ψ (Δ.extend n) (Δ'.extend n) (upLocalSubst n ρ) := by
  intro i k hi
  rw [LocalCtx.kindAt_extend] at hi
  by_cases hn : i < n
  · simp [hn] at hi
  · simp only [hn, ↓reduceIte] at hi
    simpa [upLocalSubst, hn] using (h (i - n) k hi).rename (LocalRenOk.shift Δ' n)

theorem LocalRenOk.builder_shift (Δ : LocalCtx) (kind : BuilderKind) :
    LocalRenOk Δ (some kind :: Δ) (· + 1) := by
  intro i k hi
  simpa [LocalCtx.kindAt] using hi

theorem LocalSubstOk.builder {Ψ Δ Δ' ρ} (h : LocalSubstOk Ψ Δ Δ' ρ) (kind : BuilderKind) :
    LocalSubstOk Ψ (some kind :: Δ) (some kind :: Δ') (upLocalSubst 1 ρ) := by
  intro i k hi
  cases i with
  | zero => exact .bound (by simpa [upLocalSubst, LocalCtx.kindAt] using hi)
  | succ i =>
      have he := (h i k (by simpa [LocalCtx.kindAt] using hi)).rename (LocalRenOk.builder_shift Δ' kind)
      simpa [upLocalSubst, Nat.add_comm] using he

/-- 専用 new の置換は先頭だけを場所にし、残る分類表を一つ詰める。 -/
theorem LocalSubstOk.new {Ψ Δ l kind} (hl : Ψ l = some (.builder kind)) :
    LocalSubstOk Ψ (some kind :: Δ) Δ (builderLocalSubst l) := by
  intro i k hi
  cases i with
  | zero =>
      have hk : kind = k := by simpa [LocalCtx.kindAt] using hi
      subst hk
      exact .loc hl
  | succ i => exact .bound (by simpa [LocalCtx.kindAt] using hi)

/-- 通常束縛を除く置換は、残る局所分類も同じ数だけ詰める。 -/
theorem LocalSubstOk.instantiate (Ψ : StoreTy) (Δ : LocalCtx) (n : Nat) :
    LocalSubstOk Ψ (Δ.extend n) Δ (instLocalSubst n) := by
  intro i k hi
  rw [LocalCtx.kindAt_extend] at hi
  by_cases hn : i < n
  · simp [hn] at hi
  · simp only [hn, ↓reduceIte] at hi
    simpa [instLocalSubst, hn] using LocalRef.HasKind.bound (Ψ := Ψ) hi

end Benitoite.Release
