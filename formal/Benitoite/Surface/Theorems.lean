import Benitoite.Surface.Lemmas.Program
import Benitoite.Release.Theorems

/-!
# 脱糖の型の保存と表層からのエフェクトの健全性（C1・C2・C4・C5b-1）

性質 1 は、表層の型付けと番号の範囲条件、組み込みのシグネチャの範囲条件を前提にする。
組み込みの関数の動作の仮定は、型の保存には不要である。
辞書・値として使う形・実装の定義を含む。言明と前提は C4 のままである。
-/

namespace Benitoite.Surface

open Benitoite.Release

/-- 01-12「確かめる性質」の性質 1。対象は C1・C2・C4・C5b-1 の構文であり、型の範囲を別の述語で狭めない。 -/
theorem desugar_typed {p : Program} {B : Builtins} {opPrim : OpPrim}
    (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped) :
    (desugarProgram opPrim p).WellFormed ∧
      (desugarProgram opPrim p).WellTyped B ∧
      (desugarProgram opPrim p).EffectsOk B := by
  exact ⟨desugar_wellFormed hwf hwt, desugar_wellTyped hwf hwt hsig, desugar_effectsOk hwf hwt⟩

/-- 性質 1 と Release.effect_soundness の組み合わせ。
HasMain Eff.empty は main の形と純粋性を表層の宣言で検査する。
開始状態は 01-12「エフェクトの名前と開始状態」の main[;]() である。
IO と解放の事象を伴う遷移と、処理されない操作の呼び出しがない。 -/
theorem surface_effect_soundness {p : Program} {B : Builtins} {opPrim : OpPrim}
    (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim)
    (hb : B.Assumptions (desugarProgram opPrim p))
    (hmain : p.HasMain Eff.empty) :
    ∀ s, Steps (desugarProgram opPrim p) B
      (.run (.app (.fnRef "main" [] []) []) [] Store.empty) s →
      (∀ ev s', ¬ Step (desugarProgram opPrim p) B s (some ev) s') ∧ ¬ UnhandledOp s := by
  obtain ⟨hwf', hwt', heffects⟩ := desugar_typed hwf hwt hb.sig_scoped
  obtain ⟨a, hm⟩ := main_typed (B := B) (op := opPrim) hwf hmain
  exact Release.effect_soundness hwf' hwt' heffects hb hm ⟨⟨trivial, trivial⟩, trivial⟩

end Benitoite.Surface
