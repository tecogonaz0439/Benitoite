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

/-- 開いた事実は、同じ cutoff と self の規約で移動する。 -/
theorem Ctx.facts_shiftV {Γ : Ctx} {p : Pred} (h : p ∈ Γ.facts) (k c : Nat) :
    p.shiftV k c ∈ (Γ.shiftV k c).facts := by
  obtain ⟨i, a, q, hi, hq, rfl⟩ := Ctx.mem_facts.mp h
  apply Ctx.mem_facts.mpr
  refine ⟨shiftIndex k c i, a.shiftV k c, q.shiftV k (c+1), Γ.lookup_shiftV hi k c, ?_, ?_⟩
  · rw [Ty.assume_shiftV]; exact List.mem_map.mpr ⟨q, hq, rfl⟩
  · change (predBind (fun i => some (.var (shiftIndex k (c+1) i))) q).open _ = _
    rw [← upValues_shiftIndex]
    exact (predBind_open_renaming (shiftIndex k c) q (.var i)).symm

/-- 移動の置換条件は facts の仮定を足さずに導かれる。 -/
theorem Transport.shiftV (Γ : Ctx) (Φ : List Pred) (k c : Nat) :
    Transport (renEnv (shiftIndex k c)) Γ Φ (Γ.shiftV k c) (Φ.map (Pred.shiftV k c)) := by
  constructor
  · intro i a s hi ha
    exact ⟨.var (shiftIndex k c i), rfl,
      ⟨a.shiftV k c, Γ.lookup_shiftV hi k c, (Ty.ordinary_shiftV _ _ _).mpr ha.ordinary⟩,
      a.shiftV k c, Γ.lookup_shiftV hi k c, (Ty.hasSort_shiftV a k c s).mpr ha⟩
  · intro i a hi ho t ht
    cases ht
    exact ⟨a.shiftV k c, Γ.lookup_shiftV hi k c, (Ty.ordinary_shiftV _ _ _).mpr ho⟩
  · intro i; simp [renEnv, Ordinary]
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
  exact Pred.sorted_bind h _ (fun s hi => (Ty.hasSort_shiftV a k c s).mpr hi)
    (fun hi => (Ty.ordinary_shiftV _ _ _).mpr hi)
    (Transport.shiftV Γ [] k c).values (Transport.shiftV Γ [] k c).references

theorem Ctx.shiftV_extend (Γ : Ctx) (a : Ty) (k c : Nat) :
    (Γ.extend a).shiftV k (c+1) = (Γ.shiftV k c).extend (a.shiftV k c) := by
  simp only [Ctx.extend, Ctx.shiftV, List.take_succ_cons, List.drop_succ_cons,
    List.map_cons, List.map_append, ← List.map_take, ← List.map_drop, List.map_map,
    Option.map_some, List.cons_append, List.map_replicate, Option.map_none,
    Function.comp_def, Option.map_map, Ty.shiftV_comm]


mutual
  theorem Ty.sorted_shiftV {Γ : Ctx} {a : Ty} (h : a.Sorted Γ) (k c : Nat) :
      (a.shiftV k c).Sorted (Γ.shiftV k c) := by
    cases a <;> simp only [Ty.Sorted] at h <;> simp only [Ty.shiftV, Ty.Sorted]
    all_goals first | trivial | exact Ty.sorted_shiftV h k c | exact sortedTys_shiftV h k c | exact Tel.sorted_shiftV h k c | skip
    case fn ns ps r e => exact ⟨sortedTys_shiftV h.1 k c, Ty.sorted_shiftV h.2.1 k c, sortedEff_shiftV h.2.2 k c⟩
    case cont b t e => exact ⟨Ty.sorted_shiftV h.1 k c, Ty.sorted_shiftV h.2.1 k c, sortedEff_shiftV h.2.2 k c⟩
    case map a b => exact ⟨Ty.sorted_shiftV h.1 k c, Ty.sorted_shiftV h.2 k c⟩
    case refined a p => exact ⟨Ty.sorted_shiftV h.1 k c, Pred.sorted_shiftV h.2 k c⟩
  theorem Tel.sorted_shiftV {Γ : Ctx} {t : Tel} (h : Tel.Sorted Γ t) (k c : Nat) :
      Tel.Sorted (Γ.shiftV k c) (Tel.shiftV k c t) := by
    cases t with
    | done r e => exact ⟨Ty.sorted_shiftV h.1 k c, sortedEff_shiftV h.2 k c⟩
    | param n a t =>
      refine ⟨Ty.sorted_shiftV h.1 k c, ?_⟩
      have ht := Tel.sorted_shiftV h.2 k (c+1)
      rw [Ctx.shiftV_extend] at ht
      exact ht
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


end Benitoite.Release.Refinement
