import Benitoite.Surface.Syntax
import Benitoite.Surface.SingleFail
import Benitoite.Release.Admissible
import Benitoite.Release.FiniteSupport
import Benitoite.Release.Lemmas.Closed
import Benitoite.Release.Lemmas.Rename

/-!
# 局所構築器の分類と共有番号

通常変数と専用名の番号を共有し、専用名を通常値の環境へ移さずコアの分類表に対応させる。
このモジュールは表層の型付けに依存しない（設計書 01-12「構築器の分類と環境の対応」）。
-/
namespace Benitoite.Surface
open Benitoite.Release

namespace BuilderCtx

@[simp] theorem kindAt_nil (i : Nat) : kindAt [] i = none := rfl
@[simp] theorem kindAt_zero (k : Option BuilderKind) (Δ : BuilderCtx) :
    kindAt (k :: Δ) 0 = k := rfl
@[simp] theorem kindAt_succ (k : Option BuilderKind) (Δ : BuilderCtx) (i : Nat) :
    kindAt (k :: Δ) (i + 1) = kindAt Δ i := rfl

/-- コアの空の表の表現にそろえる。番号は変えず、利用不能な末尾だけを省く。 -/
def toLocal : BuilderCtx → LocalCtx
  | [] => []
  | none :: Δ => LocalCtx.extend 1 (toLocal Δ)
  | some k :: Δ => some k :: toLocal Δ

@[simp] theorem toLocal_nil : toLocal [] = [] := rfl
@[simp] theorem toLocal_value (Δ : BuilderCtx) : toLocal (none :: Δ) = LocalCtx.extend 1 Δ.toLocal := rfl
@[simp] theorem toLocal_builder (k : BuilderKind) (Δ : BuilderCtx) :
    toLocal (some k :: Δ) = some k :: Δ.toLocal := rfl

/-- 両判断は同じ番号で同じ種類を読む。環境の射影は行わない。 -/
theorem toLocal_kindAt (Δ : BuilderCtx) (i : Nat) : Δ.toLocal.kindAt i = Δ.kindAt i := by
  induction Δ generalizing i with
  | nil => rfl
  | cons k Δ ih =>
      cases k with
      | none =>
          cases i <;> simp [toLocal, LocalCtx.kindAt_extend, ih, kindAt]
      | some k =>
          cases i with
          | zero => rfl
          | succ i => exact ih i

/-- 専用位置は Γ の通常値として読めず、Γ の範囲内にある。 -/
def Aligned (Γ : List (Option Ty)) (Δ : BuilderCtx) : Prop :=
  Δ.length ≤ Γ.length ∧ ∀ i k, Δ.kindAt i = some k → Γ[i]? = some none

/-- 種類の内部にある通常の型に課す条件を、一つの持ち上げでそろえる。 -/
def All (p : Ty → Prop) (Δ : BuilderCtx) : Prop :=
  ∀ i k, Δ.kindAt i = some k → p k.contents

/-- 内容の型が型変数の範囲内にあり、継続型を含まない。 -/
def Clean (n : Nat) (Δ : BuilderCtx) : Prop := All (TyOK n) Δ
/-- 内容の型内部のエフェクトの原子が候補集合に含まれる。 -/
def AtomsIn (atoms : List Atom) (Δ : BuilderCtx) : Prop := All (Ty.Support (· ∈ atoms)) Δ
/-- 内容の型内部でも表層の単一 Fail の条件を満たす。 -/
def Single (Q : NoFailCtx) (Δ : BuilderCtx) : Prop := All (SingleTy Q) Δ

theorem aligned_empty (Γ : List (Option Ty)) : Aligned Γ [] := by
  exact ⟨by simp, by simp⟩

theorem aligned_value {Γ Δ} (h : Aligned Γ Δ) (t : Option Ty) :
    Aligned (t :: Γ) (none :: Δ) := by
  refine ⟨by simpa using h.1, ?_⟩
  intro i k hi
  cases i with
  | zero => simp at hi
  | succ i => simpa using h.2 i k hi

theorem aligned_builder {Γ Δ} (h : Aligned Γ Δ) (k : BuilderKind) :
    Aligned (none :: Γ) (some k :: Δ) := by
  refine ⟨by simpa using h.1, ?_⟩
  intro i l hi
  cases i with
  | zero => rfl
  | succ i => simpa using h.2 i l hi

theorem aligned_values {Γ Δ} (h : Aligned Γ Δ) (xs : List (Option Ty)) :
    Aligned (xs ++ Γ) (List.replicate xs.length none ++ Δ) := by
  induction xs with
  | nil => exact h
  | cons x xs ih => simpa only [List.length_cons, List.replicate_succ, List.cons_append] using aligned_value ih x

theorem all_empty (p : Ty → Prop) : All p [] := by simp [All]

theorem all_value {p Δ} (h : All p Δ) : All p (none :: Δ) := by
  intro i k hi
  cases i with
  | zero => simp at hi
  | succ i => exact h i k hi

theorem all_builder {p Δ k} (h : All p Δ) (hk : p k.contents) :
    All p (some k :: Δ) := by
  intro i l hi
  cases i with
  | zero => simpa using (Option.some.inj hi ▸ hk)
  | succ i => exact h i l hi

theorem all_values {p Δ} (h : All p Δ) (n : Nat) :
    All p (List.replicate n none ++ Δ) := by
  induction n with
  | zero => exact h
  | succ n ih => exact all_value ih

theorem clean_empty (n : Nat) : Clean n [] := all_empty _
theorem atomsIn_empty (atoms : List Atom) : AtomsIn atoms [] := all_empty _
theorem single_empty (Q : NoFailCtx) : Single Q [] := all_empty _
theorem clean_value {n Δ} (h : Clean n Δ) : Clean n (none :: Δ) := all_value h
theorem atomsIn_value {atoms Δ} (h : AtomsIn atoms Δ) : AtomsIn atoms (none :: Δ) := all_value h
theorem single_value {Q Δ} (h : Single Q Δ) : Single Q (none :: Δ) := all_value h
theorem clean_builder {n Δ k} (h : Clean n Δ) (hk : TyOK n k.contents) :
    Clean n (some k :: Δ) := all_builder h hk
theorem atomsIn_builder {atoms Δ k} (h : AtomsIn atoms Δ) (hk : Ty.Support (· ∈ atoms) k.contents) :
    AtomsIn atoms (some k :: Δ) := all_builder h hk
theorem single_builder {Q Δ k} (h : Single Q Δ) (hk : SingleTy Q k.contents) :
    Single Q (some k :: Δ) := all_builder h hk

theorem aligned_hideConts {Γ Δ} (h : Aligned Γ Δ) : Aligned (hideConts Γ) Δ := by
  refine ⟨by simpa only [hideConts_length] using h.1, ?_⟩
  intro i k hi
  simp only [hideConts, List.getElem?_map, h.2 i k hi, Option.map_some]

end BuilderCtx

end Benitoite.Surface
