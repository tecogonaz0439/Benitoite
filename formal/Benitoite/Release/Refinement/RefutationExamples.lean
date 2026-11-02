import Benitoite.Release.Refinement.RefutationSound

/-! # 整数の導出と枝内の参照の受理・拒否 -/
namespace Benitoite.Release.Refinement.RefutationExamples
open CertificateKernel

private def x : KeyTable := [.var 0]
private def f : List NNF := [.linear ⟨[1],0⟩, .linear ⟨[-1],-1⟩]
private def addBoth : LinearStep := .combine [(0,1),(1,1)] ⟨[0],-1⟩
private def close : Refutation := .derive addBoth (.closeLinear 2)

-- 順序は先行するfacts、零乗数、空和、長さ、負係数、期待式の照合を区別する。
example : ([
    (LinearStep.combine [] ⟨[0],0⟩).check 1 f,
    (LinearStep.combine [(0,1)] ⟨[1],0⟩).check 1 f,
    (LinearStep.combine [(0,0),(1,1)] ⟨[-1],-1⟩).check 1 f,
    addBoth.check 1 f,
    !(LinearStep.combine [(0,-1)] ⟨[-1],0⟩).check 1 f,
    !(LinearStep.combine [(2,1)] ⟨[0],-1⟩).check 1 f,
    !(LinearStep.combine [(0,1)] ⟨[],0⟩).check 1 f,
    !(LinearStep.combine [(0,1)] ⟨[1],1⟩).check 1 f,
    !(LinearStep.combine [(0,1)] ⟨[1],0⟩).check 2 f
  ].all id) = true := by decide

example : ([
    (LinearStep.round 0 2 ⟨[1],-2⟩).check 1 [.linear ⟨[2],-3⟩],
    !(LinearStep.round 0 2 ⟨[1],-1⟩).check 1 [.linear ⟨[2],-3⟩],
    !(LinearStep.round 0 2 ⟨[1],0⟩).check 1 [.linear ⟨[3],1⟩],
    !(LinearStep.round 0 0 ⟨[1],0⟩).check 1 [.linear ⟨[0],1⟩],
    !(LinearStep.round 0 (-2) ⟨[1],0⟩).check 1 [.linear ⟨[-2],1⟩],
    !(LinearStep.round 1 2 ⟨[1],0⟩).check 1 [.linear ⟨[2],1⟩]
  ].all id) = true := by decide

-- 2*x=1 の上下両側を丸め、0≤-1を作る。
private def odd : Refutation :=
  .derive (.round 0 2 ⟨[1],0⟩)
    (.derive (.round 1 2 ⟨[-1],-1⟩)
      (.derive (.combine [(2,1),(3,1)] ⟨[0],-1⟩) (.closeLinear 4)))
example : refute x [] [.linear ⟨[2],1⟩,.linear ⟨[-2],-1⟩] odd = true := by decide
example : refute x [] f close = true := by decide

-- 零と矛盾する上限だけを閉じる。原子は同じ構文の正負だけを閉じる。
example : ([closeLinear [.linear ⟨[], -1⟩] 0,
    !closeLinear [.linear ⟨[], 0⟩] 0,
    !closeLinear [.linear ⟨[1], -1⟩] 0,
    closeAtom [.literal (.member .path (.var 0) .top) false,
      .literal (.member .path (.var 0) .top) true] 0 1,
    !closeAtom [.literal (.member .path (.var 0) .top) false,
      .literal (.member .path (.var 0) .top) true] 1 0,
    !closeAtom [.literal .truth false,.literal .falsity true] 0 1,
    !closeAtom [.literal .truth false,.literal .truth false] 0 1].all id) = true := by decide

-- Orはconsumeで読めず、casesは両枝を要求する。兄弟の追記も参照できない。
example : refute x [.or .falsity .falsity] [] (.cases (.consume (.closeLinear 0)) (.consume (.closeLinear 0))) = true ∧
    refute x [.or .falsity .truth] [] (.cases (.consume (.closeLinear 0)) (.consume (.closeLinear 0))) = false ∧
    refute x [.or .falsity .falsity] [] (.consume (.closeLinear 0)) = false ∧
    refute x [.or (.linear ⟨[0],-1⟩) .truth] []
      (.cases (.consume (.closeLinear 0)) (.consume (.closeLinear 0))) = false := by decide

-- splitは同じ列から左右を検査し、未知の鍵や片枝の欠落を拒否する。
example : refute x [] [.linear ⟨[0],-1⟩] (.split 0 0 (.closeLinear 0) (.closeLinear 0)) = true ∧
    refute x [] [.linear ⟨[0],-1⟩] (.split 0 0 (.closeLinear 0) (.closeLinear 1)) = false ∧
    refute x [] [.linear ⟨[0],-1⟩] (.split 1 0 (.closeLinear 0) (.closeLinear 0)) = false := by decide

-- 左は2·(x≤0)+(−2x≤−1)、右は2·(−x≤−1)+(2x≤1)で閉じる。
-- 両枝ともsplitが末尾の位置2へ加えた事実を使い、丸めは使わない。
private def splitOddLeft : Refutation :=
  .derive (.combine [(2,2),(1,1)] ⟨[0],-1⟩) (.closeLinear 3)
private def splitOddRight : Refutation :=
  .derive (.combine [(2,2),(0,1)] ⟨[0],-1⟩) (.closeLinear 3)
example : refute x [] [.linear ⟨[2],1⟩,.linear ⟨[-2],-1⟩]
      (.split 0 0 splitOddLeft splitOddRight) = true ∧
    refute x [] [.linear ⟨[2],1⟩,.linear ⟨[-2],-1⟩]
      (.split 0 0 splitOddLeft splitOddLeft) = false := by decide

-- 削除後のindex 0だけが矛盾を指し、旧index 1と範囲外の削除を拒否する。
example : refute x [.or .truth .truth] [.truth,.linear ⟨[0],-1⟩]
      (.discardTodo (.discardFact 0 (.closeLinear 0))) = true ∧
    refute x [] [.truth,.linear ⟨[0],-1⟩] (.discardFact 0 (.closeLinear 1)) = false ∧
    refute x [] [.truth,.linear ⟨[0],-1⟩] (.discardFact 2 (.closeLinear 1)) = false := by decide

theorem combine_refutes_at (ν : ObservationEnv) (η : ObservationEnvModel) :
    BranchRefutedAt x [] f ν η := by
  apply derive_sound_at (step := addBoth) (next := fun _ fs => closeLinear fs 2) (by decide) ν η
  exact fun _ _ h => close_linear_sound_at h ν η

theorem odd_refutes_at (ν : ObservationEnv) (η : ObservationEnvModel) :
    BranchRefutedAt x [] [.linear ⟨[2],1⟩,.linear ⟨[-2],-1⟩] ν η := by
  apply derive_sound_at (step := .round 0 2 ⟨[1],0⟩)
    (next := fun ts fs => refute x ts fs
      (.derive (.round 1 2 ⟨[-1],-1⟩)
        (.derive (.combine [(2,1),(3,1)] ⟨[0],-1⟩) (.closeLinear 4)))) (by decide) ν η
  intro ts fs h
  apply derive_sound_at (step := .round 1 2 ⟨[-1],-1⟩)
    (next := fun ts fs => refute x ts fs
      (.derive (.combine [(2,1),(3,1)] ⟨[0],-1⟩) (.closeLinear 4))) h ν η
  intro ts fs h
  apply derive_sound_at (step := .combine [(2,1),(3,1)] ⟨[0],-1⟩)
    (next := fun _ fs => closeLinear fs 4) h ν η
  exact fun _ _ h => close_linear_sound_at h ν η

theorem consumed_refutes_at (ν : ObservationEnv) (η : ObservationEnvModel) :
    BranchRefutedAt x [.and (.linear ⟨[1],0⟩) (.linear ⟨[-1],-1⟩)] [] ν η := by
  let k := fun ts fs => refute x ts fs (.consume (.consume close))
  apply consume_sound_at (next := k) (by decide) ν η
  intro ts fs h
  apply consume_sound_at (next := fun ts fs => refute x ts fs (.consume close)) h ν η
  intro ts fs h
  apply consume_sound_at (next := fun ts fs => refute x ts fs close) h ν η
  intro ts fs h
  apply derive_sound_at (step := addBoth) (next := fun _ fs => closeLinear fs 2) h ν η
  exact fun _ _ h => close_linear_sound_at h ν η

theorem normalized_refutes_at (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.and (.le (.var 0) (.integer 0)) (.le (.integer 1) (.var 0)))).interpret η ≠ true := by
  intro hp
  have hn := (normalize_holds_at (keys := x) (p := .and (.le (.var 0) (.integer 0))
    (.le (.integer 1) (.var 0))) (negative := false) (q := .and (.linear ⟨[1],0⟩) (.linear ⟨[-1],-1⟩))
    (by rfl) ν η).mpr hp
  exact consumed_refutes_at ν η (by simpa [BranchHoldsAt] using hn)

example (ν : ObservationEnv) (η : ObservationEnvModel) :
    (Linear.mk [1] 3).Holds (keyEnv η (x.map (termBind ν))) ↔
      (predBind ν (.le (.var 0) (.integer 3))).interpret η = true :=
  normalize_linear_at (keys := x) (p := .le (.var 0) (.integer 3))
    (l := ⟨[1],3⟩) (negative := false) rfl ν η

example (ν : ObservationEnv) (η : ObservationEnvModel) :
    BranchRefutedAt x [.or .falsity .falsity] [] ν η := by
  apply cases_sound_at (left := fun ts fs => consume (fun _ _ => false) ts fs)
    (right := fun ts fs => consume (fun _ _ => false) ts fs) (by decide) ν η
  all_goals
    intro ts fs h
    exact consume_sound_at h ν η (by intro _ _ h; cases h)

example (ν : ObservationEnv) (η : ObservationEnvModel) :
    BranchRefutedAt x [] [.linear ⟨[2],1⟩,.linear ⟨[-2],-1⟩] ν η := by
  apply split_sound_at (key := 0) (cut := 0)
    (left := fun ts fs => refute x ts fs splitOddLeft)
    (right := fun ts fs => refute x ts fs splitOddRight) (by decide) ν η
  · intro ts fs h
    apply derive_sound_at (step := .combine [(2,2),(1,1)] ⟨[0],-1⟩)
      (next := fun _ fs => closeLinear fs 3) h ν η
    exact fun _ _ h => close_linear_sound_at h ν η
  · intro ts fs h
    apply derive_sound_at (step := .combine [(2,2),(0,1)] ⟨[0],-1⟩)
      (next := fun _ fs => closeLinear fs 3) h ν η
    exact fun _ _ h => close_linear_sound_at h ν η

example (ν : ObservationEnv) (η : ObservationEnvModel) :
    BranchRefutedAt x [.or .truth .truth] [.truth,.linear ⟨[0],-1⟩] ν η := by
  apply discard_todo_sound_at (next := fun ts fs => discardFact (fun _ fs => closeLinear fs 0) ts fs 0)
    (by decide) ν η
  intro ts fs h
  exact discard_fact_sound_at h ν η (fun _ _ h => close_linear_sound_at h ν η)

example (ν : ObservationEnv) (η : ObservationEnvModel) :
    BranchRefutedAt x [] [.literal (.floatClass .binary64 .nan (.var 0)) false,
      .literal (.floatClass .binary64 .nan (.var 0)) true] ν η :=
  close_atom_sound_at (p := 0) (n := 1) (by decide) ν η

end Benitoite.Release.Refinement.RefutationExamples
