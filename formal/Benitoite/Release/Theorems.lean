import Benitoite.Release.Lemmas.StepSound

/-!
# 段階 B の定理

設計書 01-12「確かめる性質」の性質 2（進行と保存）と性質 3（エフェクトの健全性）の、初回リリース版の
読み替えの形を、段階 B の範囲で言明し、証明する（段階 B2 で、型クラスとコレクションの構成を加えた）。証明の補題は `Lemmas/` に置く。

段階 A と違い、遷移を計算する関数 `step` と遷移の関係の一致は、`step` が返す遷移が関係の遷移であること
（`step_sound`）だけを言明する。`step` は例の実行を調べる道具であり、新しい場所と応答の選び方を固定するので、
関係のすべての遷移を返すわけではない。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-- 型が付いた状態について、`step` が返す遷移は `Step` の遷移である。`oracle` と `rel` は、起こりうる応答が
あるときは、その一つを選ぶ。`fresh` は、有限なストアに中身のない場所を選ぶ。 -/
theorem step_sound (hb : B.Assumptions P) (oracle : Oracle) (rel : Val → Option ErrKind) (fresh : Store → Nat)
    (horacle : ∀ b ts es ws o, B.ioResponse b ts es ws o → B.ioResponse b ts es ws (oracle b ts es ws))
    (hrel : ∀ v r, B.releaseResponse v r → B.releaseResponse v (rel v))
    (hfresh : ∀ σ : Store, (∃ n, ∀ l, n ≤ l → σ l = none) → σ (fresh σ) = none)
    {s : State} {l : Option Event} {s' : State} :
    StateTy P B s → step P B oracle rel fresh s = some (l, s') → Step P B s l s' := by
  intro hs h
  obtain ⟨Eb, _, hs⟩ := stateTy_iff.mp hs
  exact step_soundE hb oracle rel fresh horacle hrel hfresh hs h

/-- 進行。型が付いた状態は、`⟨return V, [], σ⟩`、`error(r̄, [], σ)`、`exit(n, r̄, [], σ)` のいずれかであるか、
遷移できる。 -/
theorem progress (hwt : P.WellTyped B) (hdecl : P.EffectsOk B) (hb : B.Assumptions P) {s : State} :
    StateTy P B s → s.Final ∨ ∃ l s', Step P B s l s' := by
  intro hs
  obtain ⟨Eb, hEb, hs⟩ := stateTy_iff.mp hs
  exact progressE hwt hdecl hb hs hEb

/-- 保存。型が付いた状態から遷移した先の状態も型が付く。 -/
theorem preservation (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hb : B.Assumptions P) {s : State} {l : Option Event} {s' : State} :
    StateTy P B s → Step P B s l s' → StateTy P B s' := by
  intro hs hst
  obtain ⟨Eb, hEb, hs⟩ := stateTy_iff.mp hs
  exact stateTy_iff.mpr ⟨Eb, hEb, preservationE hwf hwt hdecl hb hs hst⟩

/-- エフェクトの健全性。`· ⊢c M : A ! { }` が成り立ち、M がエフェクト変数を含まないとき、`⟨M, [], ∅⟩` からの
実行は、事象を伴う遷移（IO の事象と解放の事象）をせず、どの `handle` の枠も処理しない操作を呼ばない。
`· ⊢c M` の R は `none` とする（実行を始める計算は関数の本体の外にあるので `escape` を許さない。01-12「確かめる性質」）。 -/
theorem effect_soundness (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hb : B.Assumptions P) {m : Comp} {a : Ty} :
    HasTypeC P B StoreTy.empty [] [] none m a Eff.empty → m.ClosedNoEffVars →
    ∀ s, Steps P B (.run m [] Store.empty) s →
      (∀ ev s', ¬ Step P B s (some ev) s') ∧ ¬ UnhandledOp s := by
  intro hm hc s hsteps
  have hs := steps_preserve hwf hwt hdecl hb hsteps (stateTyE_init hwf hb hm hc)
  exact ⟨no_event hdecl hb hs, no_unhandledOp hdecl hs builtinOnly_empty⟩

end Benitoite.Release
