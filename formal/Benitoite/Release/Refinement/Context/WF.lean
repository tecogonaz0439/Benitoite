import Benitoite.Release.Refinement.TypingDeclared
import Benitoite.Release.Refinement.ClosureTyping
import Benitoite.Release.Refinement.ValueReferences

/-!
# ソース文脈の参照順序と整形式

注釈は lookup する文脈の番号で格納する。outer は自分と内側を隠し、
既存の References により self と依存列の内部束縛を区別する。
捕捉用の CaptureWF は継続の行を読まないため、この判断とは区別する。
-/
namespace Benitoite.Release.Refinement

def Ctx.outer : Ctx → Nat → Ctx
  | [], _ => []
  | _ :: Γ, 0 => none :: Γ
  | _ :: Γ, i+1 => none :: Ctx.outer Γ i

@[simp] theorem Ctx.outer_length (Γ : Ctx) (i : Nat) :
    (Γ.outer i).length = Γ.length := by
  induction Γ generalizing i with
  | nil => rfl
  | cons a Γ ih => cases i <;> simp [Ctx.outer, ih]

theorem Ctx.lookup_outer {Γ : Ctx} {i j : Nat} {a : Ty} :
    (Γ.outer i)[j]? = some (some a) ↔ i < j ∧ Γ[j]? = some (some a) := by
  induction Γ generalizing i j with
  | nil => simp [Ctx.outer]
  | cons x Γ ih =>
    cases i <;> cases j <;> simp [Ctx.outer, ih, Nat.succ_lt_succ_iff]

private theorem outer_map (Γ : Ctx) (i : Nat) (f : Ty → Ty) :
    Ctx.outer (Γ.map (Option.map f)) i = (Γ.outer i).map (Option.map f) := by
  induction Γ generalizing i with
  | nil => rfl
  | cons x Γ ih => cases i <;> simp [Ctx.outer, ih]

@[simp] theorem Ctx.outer_extend_zero (Γ : Ctx) (a : Ty) :
    (Γ.extend a).outer 0 = Γ.extendNone := rfl

@[simp] theorem Ctx.outer_extend_succ (Γ : Ctx) (a : Ty) (i : Nat) :
    (Γ.extend a).outer (i+1) = (Γ.outer i).extendNone := by
  simp [Ctx.extend, Ctx.extendNone, Ctx.outer, outer_map]

@[simp] theorem Ctx.outer_extendNone_succ (Γ : Ctx) (i : Nat) :
    Γ.extendNone.outer (i+1) = (Γ.outer i).extendNone := by
  simp [Ctx.extendNone, Ctx.outer, outer_map]

@[simp] theorem Ctx.lookup_extend (Γ : Ctx) (a : Ty) (i : Nat) :
    (Γ.extend a)[i+1]? = (Γ[i]?).map (Option.map (Ty.shiftV 1 0)) := by
  simp [Ctx.extend]

@[simp] theorem Ctx.lookup_extendNone (Γ : Ctx) (i : Nat) :
    Γ.extendNone[i+1]? = (Γ[i]?).map (Option.map (Ty.shiftV 1 0)) := by
  simp [Ctx.extendNone]

theorem Ctx.not_readable_none {Γ : Ctx} {i : Nat} (h : Γ[i]? = some none) :
    ¬ Γ.Readable i := by
  rintro ⟨a, ha, _⟩
  simp [h] at ha

theorem Ctx.outer_readable {Γ : Ctx} {i j : Nat} (h : (Γ.outer i).Readable j) :
    i < j ∧ Γ.Readable j := by
  obtain ⟨a, ha, ho⟩ := h
  obtain ⟨hj, ha⟩ := Ctx.lookup_outer.mp ha
  exact ⟨hj, a, ha, ho⟩

/-- 各注釈は宣言済みの外側の通常値だけを参照する。 -/
def Ctx.Ordered (Γ : Ctx) : Prop :=
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.References (Γ.outer i)

theorem Ctx.Ordered.lookup {Γ : Ctx} (h : Γ.Ordered) {i : Nat} {a : Ty}
    (hi : Γ[i]? = some (some a)) : a.References (Γ.outer i) := h i a hi

/-- self は0に残り、注釈の外側の自由変数は宣言済みの位置だけを指す。 -/
theorem Ctx.Ordered.refined_outer {Γ : Ctx} (h : Γ.Ordered) {i : Nat} {a : Ty} {p : Pred}
    (hi : Γ[i]? = some (some (.refined a p))) :
    p.VarsIn (fun j => match j with | 0 => a.Ordinary | j+1 => i < j ∧ Γ.Readable j) := by
  have hp := (h i (.refined a p) hi).2
  apply Pred.varsIn_mono hp
  intro j hj
  cases j with
  | zero =>
    obtain ⟨b, hb, ho⟩ := hj
    simp only [List.getElem?_cons_zero, Option.some.injEq] at hb
    cases hb
    exact ho
  | succ j =>
    obtain ⟨b, hb, ho⟩ := hj
    exact Ctx.outer_readable ⟨b, hb, ho⟩

theorem Ctx.Ordered.nil : Ctx.Ordered [] := by simp [Ctx.Ordered]

theorem ShiftMap.outerValue (Γ : Ctx) (a : Option Ty) :
    ShiftMap 1 0 Γ (a :: Γ.map (Option.map (Ty.shiftV 1 0))) := by
  constructor
  · simp
  · intro i b hi _
    simp [shiftIndex, hi]

theorem Ty.References.shift_none {Γ : Ctx} {a : Ty} (h : a.References Γ) :
    (a.shiftV 1 0).References Γ.extendNone := by
  have hh := h.rawSubstV (ShiftMap.outerValue Γ none).references
  rw [Ty.rawSubstV_eq_rawBind] at hh
  change Ty.References Γ.extendNone (renameTy (shiftIndex 1 0) a) at hh
  simpa only [← Ty.shiftV_eq_renameTy] using hh

theorem Ctx.Ordered.extend {Γ : Ctx} {a : Ty} (h : Γ.Ordered) (ha : a.References Γ) :
    (Γ.extend a).Ordered := by
  intro i b hi
  cases i with
  | zero =>
    simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
    cases hi
    simpa only [Ctx.outer_extend_zero] using ha.shift_none
  | succ i =>
    rw [Ctx.lookup_extend] at hi
    obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
    cases x with
    | none => cases hb
    | some x =>
      cases hb
      simpa only [Ctx.outer_extend_succ] using (h i x hx).shift_none

theorem Ctx.Ordered.extendNone {Γ : Ctx} (h : Γ.Ordered) : Γ.extendNone.Ordered := by
  intro i b hi
  cases i with
  | zero => cases hi
  | succ i =>
    rw [Ctx.lookup_extendNone] at hi
    obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
    cases x with
    | none => cases hb
    | some x =>
      cases hb
      simpa only [Ctx.outer_extendNone_succ] using (h i x hx).shift_none

/-- 指定した位置だけを隠す。内部の self と Tel の束縛は References が扱う。 -/
def Ctx.without : Ctx → Nat → Ctx
  | [], _ => []
  | _ :: Γ, 0 => none :: Γ
  | a :: Γ, j+1 => a :: Ctx.without Γ j

private theorem lookup_without_of_ne {Γ : Ctx} {i j : Nat} (h : i ≠ j) :
    (Γ.without j)[i]? = Γ[i]? := by
  induction Γ generalizing i j with
  | nil => rfl
  | cons a Γ ih => cases i <;> cases j <;> simp_all [Ctx.without]

/-- 注釈iが必要とする外側の参照j。jを隠すと注釈の参照整合が失われる。 -/
def Ctx.Depends (Γ : Ctx) (i j : Nat) : Prop :=
  ∃ a : Ty, Γ[i]? = some (some a) ∧ ¬ a.References (Γ.without j)

/-- Orderedの下では、注釈の依存先は必ず外側にある。 -/
theorem Ctx.Ordered.depends_lt {Γ : Ctx} (h : Γ.Ordered) {i j : Nat}
    (hd : Γ.Depends i j) : i < j := by
  obtain ⟨a, hi, hd⟩ := hd
  by_cases hn : i < j
  · exact hn
  apply False.elim
  have hm : Ctx.TypeMap (Γ.outer i) (Γ.without j) := by
    constructor
    intro k b hk
    obtain ⟨hik, hkb⟩ := Ctx.lookup_outer.mp hk
    refine ⟨b, ?_, fun _ h => h, fun h => h, fun _ h => h⟩
    rw [lookup_without_of_ne (by omega)]
    exact hkb
  exact hd ((h.lookup hi).context hm)

theorem Ctx.no_dependency_cycle {Γ : Ctx} (hΓ : Γ.Ordered) (i : Nat)
    (h : Relation.TransGen Γ.Depends i i) : False := by
  have lt : ∀ {a b}, Relation.TransGen Γ.Depends a b → a < b := by
    intro a b hab
    induction hab with
    | single h => exact hΓ.depends_lt h
    | tail _ h ih => exact Nat.lt_trans ih (hΓ.depends_lt h)
  exact Nat.lt_irrefl i (lt h)

theorem Ctx.WF.extend {nr nt : Nat} {Γ : Ctx} {a : Ty}
    (h : Ctx.WF nr nt Γ) (ha : a.WF nr nt Γ.length) : Ctx.WF nr nt (Γ.extend a) := by
  intro i b hi
  cases i with
  | zero =>
    simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
    cases hi
    simpa [Ctx.extend] using Ty.wf_shiftV ha 1 0
  | succ i =>
    rw [Ctx.lookup_extend] at hi
    obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
    cases x with
    | none => cases hb
    | some x => cases hb; simpa [Ctx.extend] using Ty.wf_shiftV (h i x hx) 1 0

theorem Ctx.WF.extendNone {nr nt : Nat} {Γ : Ctx} (h : Ctx.WF nr nt Γ) :
    Ctx.WF nr nt Γ.extendNone := by
  intro i b hi
  cases i with
  | zero => cases hi
  | succ i =>
    rw [Ctx.lookup_extendNone] at hi
    obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
    cases x with
    | none => cases hb
    | some x => cases hb; simpa [Ctx.extendNone] using Ty.wf_shiftV (h i x hx) 1 0

def Ctx.Sorted (Γ : Ctx) : Prop := ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.Sorted Γ

structure Ctx.Regular (P : Program) (C : List TParam) (Γ : Ctx) : Prop where
  wf : Ctx.WF 0 C.length Γ
  sorted : Γ.Sorted
  declared : Ctx.Declared P C Γ
  ordered : Γ.Ordered

theorem Ctx.Regular.empty (P : Program) (C : List TParam) : Ctx.Regular P C [] := by
  constructor <;> simp [Ctx.WF, Ctx.Sorted, Ctx.Declared, Ctx.Ordered]

theorem Ctx.Regular.extend {P C Γ a} (h : Ctx.Regular P C Γ)
    (ha : Ty.Annotation P C Γ a) : Ctx.Regular P C (Γ.extend a) := by
  refine ⟨h.wf.extend ha.wf, ?_, ?_, h.ordered.extend ha.sorted.references⟩
  all_goals
    intro i b hi
    have hx : Ty.Annotation P C (Γ.extend a) b := by
      cases i with
      | zero =>
        simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
        cases hi
        exact (ShiftMap.outerValue Γ (some (a.shiftV 1 0))).annotation ha
      | succ i =>
        rw [Ctx.lookup_extend] at hi
        obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
        cases x with
        | none => cases hb
        | some x =>
          cases hb
          exact (ShiftMap.outerValue Γ (some (a.shiftV 1 0))).annotation
            ⟨h.wf i x hx, h.sorted i x hx, h.declared i x hx⟩
    first | exact hx.sorted | exact hx.declared

theorem Ctx.Regular.extendNone {P C Γ} (h : Ctx.Regular P C Γ) :
    Ctx.Regular P C Γ.extendNone := by
  refine ⟨h.wf.extendNone, ?_, ?_, h.ordered.extendNone⟩
  all_goals
    intro i b hi
    cases i with
    | zero => cases hi
    | succ i =>
      rw [Ctx.lookup_extendNone] at hi
      obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
      cases x with
      | none => cases hb
      | some x =>
        cases hb
        have ha : Ty.Annotation P C Γ x := ⟨h.wf i x hx, h.sorted i x hx, h.declared i x hx⟩
        have hd := (ShiftMap.outerValue Γ none).annotation ha
        first | exact hd.sorted | exact hd.declared

end Benitoite.Release.Refinement
