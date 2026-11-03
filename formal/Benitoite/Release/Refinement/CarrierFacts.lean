import Benitoite.Release.Refinement.Context

/-! # 型域の有限な事実

設計書 01-12「篩の正規形と制約の読み方」に対応する。
明示した篩の列と、芯の数値型が与える事実を分ける。
-/
namespace Benitoite.Release.Refinement

theorem Ty.carrierFacts_subset_assume (a : Ty) :
    ∀ p ∈ a.carrierFacts, p ∈ a.assume := by
  unfold Ty.assume
  cases hc : a.core <;> intro p hp
  all_goals first
    | exact List.mem_append_left _ hp
    | (simp only [Ty.carrierFacts, hc] at hp; cases hp)

theorem Ty.carrierFacts_hasSort {a : Ty} {p : Pred} (hp : p ∈ a.carrierFacts) :
    ∃ s, a.HasSort s := by
  cases a <;> try (cases hp)
  case refined a q => exact Ty.carrierFacts_hasSort (a := a) hp
  case base b =>
    cases b <;> simp only [Ty.carrierFacts, Ty.core] at hp <;> try cases hp
    all_goals first | exact ⟨.integer, rfl⟩ | exact ⟨.decimal, rfl⟩

end Benitoite.Release.Refinement
