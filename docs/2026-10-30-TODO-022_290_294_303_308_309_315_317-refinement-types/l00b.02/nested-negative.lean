import Lean

/- 中7の再現入力。本番へ import しない。終了1を期待する。 -/
namespace SignatureProbeNegative
mutual
  inductive Typed : Nat → Prop where
    | capture : Captured → Typed 0
  inductive Captured : Prop where
    | mk : (∀ i : Nat, Typed i ∨ (∃ j : Nat, i = j)) → Captured
end
end SignatureProbeNegative
