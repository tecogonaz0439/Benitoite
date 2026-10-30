import Benitoite.Release.Refinement.Transport
import Benitoite.Release.Refinement.ShiftOrder

/-!
# 開いた文脈の移動

None の位置を残し、cutoff に利用不能な変数を挿入する。
-/
namespace Benitoite.Release.Refinement

/-- 型の全体の番号を移し、cutoff に k 個の None を挿入する。 -/
def Ctx.shiftV (Γ : Ctx) (k c : Nat) : Ctx :=
  (Γ.take c).map (Option.map (Ty.shiftV k c)) ++ List.replicate k none ++
    (Γ.drop c).map (Option.map (Ty.shiftV k c))

theorem Ctx.lookup_shiftV {Γ : Ctx} {i : Nat} {a : Option Ty} (h : Γ[i]? = some a) (k c : Nat) :
    (Γ.shiftV k c)[shiftIndex k c i]? = some (a.map (Ty.shiftV k c)) := by
  have hi := (List.getElem?_eq_some_iff.mp h).1
  have ha := (List.getElem?_eq_some_iff.mp h).2
  by_cases hc : i < c
  · have hmin : i < min c Γ.length := by omega
    simp [Ctx.shiftV, shiftIndex, hc, List.getElem?_append, hmin, ha]
  · have hmin : min c Γ.length = c := by omega
    have hge : ¬ i+k < c := by omega
    have hdrop : c + (i+k-c-k) = i := by omega
    have hrep : ¬ i+k-c < k := by omega
    simp [Ctx.shiftV, shiftIndex, hc, List.getElem?_append, List.getElem?_map,
      List.getElem?_drop, hmin, hge, hrep, hdrop, h]

@[simp] theorem Ty.integerCarrier_shiftV (a : Ty) (k c : Nat) :
    (a.shiftV k c).IntegerCarrier ↔ a.IntegerCarrier := by
  cases a <;> simp only [Ty.shiftV, Ty.IntegerCarrier, Ty.integerCarrier_shiftV]

theorem Ty.assume_shiftV (a : Ty) (k c : Nat) :
    (a.shiftV k c).assume = a.assume.map (Pred.shiftV k (c+1)) := by
  cases a <;> simp only [Ty.shiftV, Ty.assume, List.map_nil, List.map_cons,
    Ty.assume_shiftV, Pred.shiftV, shiftIndex]

/-- 文脈の事実の所属を、lookup と self の開きに分ける。 -/
theorem Ctx.mem_facts {Γ : Ctx} {q : Pred} : q ∈ Γ.facts ↔
    ∃ (i : Nat) (a : Ty) (p : Pred), Γ[i]? = some (some a) ∧ p ∈ a.assume ∧ p.open (.var i) = q := by
  simp only [Ctx.facts, List.mem_flatMap]
  constructor
  · rintro ⟨⟨a, i⟩, hi, hq⟩
    cases a with
    | none => cases hq
    | some a =>
      obtain ⟨p, hp, he⟩ := List.mem_map.mp hq
      exact ⟨i, a, p, List.mk_mem_zipIdx_iff_getElem?.mp hi, hp, he⟩
  · rintro ⟨i, a, p, hi, hp, rfl⟩
    exact ⟨(some a, i), List.mk_mem_zipIdx_iff_getElem?.mpr hi, List.mem_map.mpr ⟨p, hp, rfl⟩⟩

/-- 開いた事実は、同じ cutoff と self の規約で移動する。 -/
theorem Ctx.facts_shiftV {Γ : Ctx} {p : Pred} (h : p ∈ Γ.facts) (k c : Nat) :
    p.shiftV k c ∈ (Γ.shiftV k c).facts := by
  obtain ⟨i, a, q, hi, hq, rfl⟩ := Ctx.mem_facts.mp h
  apply Ctx.mem_facts.mpr
  refine ⟨shiftIndex k c i, a.shiftV k c, q.shiftV k (c+1), Γ.lookup_shiftV hi k c, ?_, ?_⟩
  · rw [Ty.assume_shiftV]; exact List.mem_map.mpr ⟨q, hq, rfl⟩
  · change (predBind (fun i => .var (shiftIndex k (c+1) i)) q).open _ = _
    rw [← upValues_shiftIndex]
    exact (predBind_open (fun i => .var (shiftIndex k c i)) q (.var i)).symm

/-- 移動の置換条件は facts の仮定を足さずに導かれる。 -/
theorem Transport.shiftV (Γ : Ctx) (Φ : List Pred) (k c : Nat) :
    Transport (renEnv (shiftIndex k c)) Γ Φ (Γ.shiftV k c) (Φ.map (Pred.shiftV k c)) := by
  constructor
  · intro i a hi ha
    exact ⟨a.shiftV k c, Γ.lookup_shiftV hi k c, (Ty.integerCarrier_shiftV a k c).mpr ha⟩
  · intro p hp
    apply Entails.hyp
    rcases List.mem_append.mp hp with hp | hp
    · exact List.mem_append_left _ (Ctx.facts_shiftV hp k c)
    · exact List.mem_append_right _ (List.mem_map.mpr ⟨p, hp, rfl⟩)

/-- 部分型の導出は開いた Γ/Φ と任意の Nat/cutoff について移動する。 -/
theorem Ty.LeQ.shiftV {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (k c : Nat) :
    Ty.LeQ (Γ.shiftV k c) (Φ.map (Pred.shiftV k c)) (a.shiftV k c) (b.shiftV k c) := by
  rw [Ty.shiftV_eq_renameTy, Ty.shiftV_eq_renameTy]
  exact h.rawBind _ (Transport.shiftV Γ Φ k c)

/-- Fail の正規形の等号も同じ移動で保たれる。 -/
theorem Eff.Covers.shiftV {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f) (k c : Nat) :
    Eff.Covers Δ Ψ (Eff.shiftV k c e) (Eff.shiftV k c f) := by
  rw [Eff.shiftV_eq_renameEff, Eff.shiftV_eq_renameEff]
  exact Eff.covers_norm_right.mp (Eff.covers_norm_left.mp (h.bind (renEnv (shiftIndex k c))))

theorem Pred.sorted_shiftV {Γ : Ctx} {a : Ty} {p : Pred} (h : p.Sorted Γ (some a)) (k c : Nat) :
    (p.shiftV k (c+1)).Sorted (Γ.shiftV k c) (some (a.shiftV k c)) := by
  unfold Pred.shiftV
  rw [← upValues_shiftIndex]
  exact Pred.sorted_bind h _ (fun hi => (Ty.integerCarrier_shiftV a k c).mpr hi)
    (fun i t hi ht => ⟨t.shiftV k c, Γ.lookup_shiftV hi k c, (Ty.integerCarrier_shiftV t k c).mpr ht⟩)

mutual
  theorem Ty.sorted_shiftV {Γ : Ctx} {a : Ty} (h : a.Sorted Γ) (k c : Nat) :
      (a.shiftV k c).Sorted (Γ.shiftV k c) := by
    cases a <;> simp only [Ty.Sorted] at h <;> simp only [Ty.shiftV, Ty.Sorted]
    all_goals first | trivial | exact Ty.sorted_shiftV h k c | exact sortedTys_shiftV h k c | skip
    case fn ns ps r e => exact ⟨sortedTys_shiftV h.1 k c, Ty.sorted_shiftV h.2.1 k c, sortedEff_shiftV h.2.2 k c⟩
    case cont b t e => exact ⟨Ty.sorted_shiftV h.1 k c, Ty.sorted_shiftV h.2.1 k c, sortedEff_shiftV h.2.2 k c⟩
    case map a b => exact ⟨Ty.sorted_shiftV h.1 k c, Ty.sorted_shiftV h.2 k c⟩
    case refined a p => exact ⟨Ty.sorted_shiftV h.1 k c, Pred.sorted_shiftV h.2 k c⟩
  theorem sortedTys_shiftV {Γ : Ctx} {as : List Ty} (h : sortedTys Γ as) (k c : Nat) :
      sortedTys (Γ.shiftV k c) (shiftVTys k c as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.sorted_shiftV h.1 k c, sortedTys_shiftV h.2 k c⟩
  theorem sortedEff_shiftV {Γ : Ctx} {e : Eff} (h : sortedEff Γ e) (k c : Nat) :
      sortedEff (Γ.shiftV k c) (Eff.shiftV k c e) := by
    cases e
    exact sortedTys_shiftV h k c
end

theorem Pred.open_shiftV_self (p : Pred) : (p.shiftV 1 1).open (.var 0) = p := by
  simp only [Pred.shiftV, Pred.open, predBind_comp]
  have hi : (fun i => termBind (fun i => match i with | 0 => Term.var 0 | j+1 => .var j)
      (.var (shiftIndex 1 1 i))) = Term.var := by
    funext i
    cases i <;> simp [termBind, shiftIndex]
  exact (congrArg (fun σ => predBind σ p) hi).trans (predBind_id p)

theorem Pred.open_shiftV_outer (p : Pred) (i : Nat) :
    (p.shiftV 1 1).open (.var (i+1)) = (p.open (.var i)).lift := by
  change (predBind (fun i => .var (shiftIndex 1 1 i)) p).open _ = _
  rw [← upValues_shiftIndex]
  exact (predBind_open (fun i => .var (shiftIndex 1 0 i)) p (.var i)).symm

/-- 束縛した値の事実と、外側から移動した事実を区別する。 -/
theorem Ctx.mem_facts_extend {Γ : Ctx} {a : Ty} {q : Pred} :
    q ∈ (Γ.extend a).facts ↔ q ∈ a.assume ∨ ∃ p ∈ Γ.facts, p.lift = q := by
  constructor
  · intro hq
    obtain ⟨i, t, p, hi, hp, he⟩ := Ctx.mem_facts.mp hq
    cases i with
    | zero =>
      simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      rw [Ty.assume_shiftV] at hp
      obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hp
      rw [Pred.open_shiftV_self] at he
      exact Or.inl (he ▸ hr)
    | succ i =>
      simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
      cases hg : Γ[i]? with
      | none => simp [hg] at hi
      | some u =>
        cases u with
        | none => simp [hg] at hi
        | some u =>
          simp only [hg, Option.map_some, Option.map_some, Option.some.injEq] at hi
          cases hi
          rw [Ty.assume_shiftV] at hp
          obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hp
          exact Or.inr ⟨r.open (.var i), Ctx.mem_facts.mpr ⟨i, u, r, hg, hr, rfl⟩,
            (Pred.open_shiftV_outer r i).symm.trans he⟩
  · rintro (hq | ⟨p, hp, rfl⟩)
    · exact Ctx.mem_facts.mpr ⟨0, a.shiftV 1 0, q.shiftV 1 1, rfl,
        by rw [Ty.assume_shiftV]; exact List.mem_map.mpr ⟨q, hq, rfl⟩, Pred.open_shiftV_self q⟩
    · obtain ⟨i, t, r, hi, hr, rfl⟩ := Ctx.mem_facts.mp hp
      exact Ctx.mem_facts.mpr ⟨i+1, t.shiftV 1 0, r.shiftV 1 1,
        by simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map, hi, Option.map_some],
        by rw [Ty.assume_shiftV]; exact List.mem_map.mpr ⟨r, hr, rfl⟩,
        Pred.open_shiftV_outer r i⟩

end Benitoite.Release.Refinement
