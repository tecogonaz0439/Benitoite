import Benitoite.Release.Refinement.MatchFacts

/-! Float の欄から無条件の IEEE 等号を生成できないことの再現入力。 -/
namespace Benitoite.Release.Refinement.K2Obstruction

theorem float64_nan_self_eq_false (bits : UInt64)
    (hnan : ieeeNaN 52 11 bits.toNat = true) :
    (Pred.compare .float64 .eq (.float64 bits) (.float64 bits)).evalWith
      (fun _ => none) = some false := by
  simp [Pred.evalWith, Pred.atomReady, Comparison.Allowed, termReady,
    Term.observe, Observation.sort, Pred.atomValue, observeAs, Term.interpret,
    Observation.compare, ieeeCompare, hnan]
  rfl

theorem float32_nan_self_eq_false (bits : UInt32)
    (hnan : ieeeNaN 23 8 bits.toNat = true) :
    (Pred.compare .float32 .eq (.float32 bits) (.float32 bits)).evalWith
      (fun _ => none) = some false := by
  simp [Pred.evalWith, Pred.atomReady, Comparison.Allowed, termReady,
    Term.observe, Observation.sort, Pred.atomValue, observeAs, Term.interpret,
    Observation.compare, ieeeCompare, hnan]
  rfl

/-- 固定幅の NaN を一個ずつ置く。列や範囲の展開は行わない。 -/
theorem nan_witnesses :
    ieeeNaN 52 11 (0x7ff8000000000000 : UInt64).toNat = true ∧
    ieeeNaN 23 8 (0x7fc00000 : UInt32).toNat = true := by decide

/-- NaN のビット列も、追加の組込み契約なしに通常の Float 値として型付く。 -/
theorem float64_value_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (bits : UInt64) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.float64 bits)) (.base .float) :=
  .V_Const trivial

theorem float32_value_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (bits : UInt32) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.float32 bits)) (.base .float32) :=
  .V_Const trivial

theorem float64_field_nan (bits : UInt64)
    (hnan : ieeeNaN 52 11 bits.toNat = true) :
    let ref : FieldRef := ⟨"Box", "Box", 0, .float64⟩
    let w : Val := .const (.float64 bits)
    let root : Val := .con "Box" [] [w]
    matchVal (.con "Box" [.var]) root = some [w] ∧
    MatchFacts.readPath root [ref] = some w ∧
    (Pred.compare .float64 .eq (.float64 bits)
      (.field ref (.dataValue "Box" [some (.float64 bits)]))).evalWith
      (fun _ => none) = some false := by
  simp [matchVal, matchList, MatchFacts.readPath, MatchFacts.conFields?,
    Pred.evalWith, Pred.atomReady, Comparison.Allowed, termReady,
    Term.observe, observeSlots, Observation.sort, Pred.atomValue, observeAs,
    Term.interpret, Observation.compare, ieeeCompare, hnan]
  rfl

theorem float32_field_nan (bits : UInt32)
    (hnan : ieeeNaN 23 8 bits.toNat = true) :
    let ref : FieldRef := ⟨"Box", "Box", 0, .float32⟩
    let w : Val := .const (.float32 bits)
    let root : Val := .con "Box" [] [w]
    matchVal (.con "Box" [.var]) root = some [w] ∧
    MatchFacts.readPath root [ref] = some w ∧
    (Pred.compare .float32 .eq (.float32 bits)
      (.field ref (.dataValue "Box" [some (.float32 bits)]))).evalWith
      (fun _ => none) = some false := by
  simp [matchVal, matchList, MatchFacts.readPath, MatchFacts.conFields?,
    Pred.evalWith, Pred.atomReady, Comparison.Allowed, termReady,
    Term.observe, observeSlots, Observation.sort, Pred.atomValue, observeAs,
    Term.interpret, Observation.compare, ieeeCompare, hnan]
  rfl

/-- IEEE 等号だけでは、篩で観測できるゼロの符号の一致までは導けない。 -/
theorem float64_signed_zero_distinguished :
    (Pred.compare .float64 .eq (.float64 0) (.float64 0x8000000000000000)).evalWith
      (fun _ => none) = some true ∧
    (Pred.floatClass .binary64 .positiveZero (.float64 0)).evalWith
      (fun _ => none) = some true ∧
    (Pred.floatClass .binary64 .positiveZero (.float64 0x8000000000000000)).evalWith
      (fun _ => none) = some false := by decide

end Benitoite.Release.Refinement.K2Obstruction
