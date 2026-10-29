import Benitoite.Surface.Lemmas.Program
import Benitoite.Release.Theorems

/-!
# 脱糖の型の保存と表層からのエフェクトの健全性

性質 1 は、表層の型付けと番号の範囲条件、組み込みのシグネチャの範囲条件を前提にする。
組み込みの関数の動作の仮定は、型の保存には不要である。
操作・ハンドラ・型クラス・コレクション・レコードを含む全表層を扱う。
契約名と位置対応は入力の型付けと範囲条件から得て、別の外部仮定を加えない。
関数・実装メソッドごとの任意の view を表層の型付けに使い、コアの結論へは渡さない。
-/

namespace Benitoite.Surface

open Benitoite.Release

/-- 01-12「確かめる性質」の性質 1。型付けと範囲条件が扱う全構文を対象とする。 -/
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
IO と解放の事象を伴う遷移と、処理されない操作の呼び出しがない。
組み込みの関数の仮定は旧の条件 CoreAssumptions だけを求め、対象一致の条件を求めない。 -/
theorem surface_effect_soundness {p : Program} {B : Builtins} {opPrim : OpPrim}
    (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim)
    (hb : B.CoreAssumptions (desugarProgram opPrim p))
    (hmain : p.HasMain Eff.empty) :
    ∀ s, Steps (desugarProgram opPrim p) B
      (.run (.app (.fnRef "main" [] []) []) [] Store.empty) s →
      (∀ ev s', ¬ Step (desugarProgram opPrim p) B s (some ev) s') ∧ ¬ UnhandledOp s := by
  obtain ⟨hwf', hwt', heffects⟩ := desugar_typed hwf hwt hb.sig_scoped
  obtain ⟨a, hm⟩ := main_typed (B := B) (op := opPrim) hwf hmain
  exact Release.effect_soundness hwf' hwt' heffects hb hm ⟨⟨trivial, trivial⟩, trivial⟩

open Scope.Domain (Target) in
/-- 表層の対象健全性。到達先の対象健全性（`Release.reachable_target_sound`）を性質 1（`desugar_typed`）の結論に当てる。
表層のプログラムの main が許す上限 ε を宣言し（`HasMain ε`）、表層の整形式性と型付けを満たすなら、脱糖したプログラムの
開始状態 `main[;]()` から到達した状態の IO の事象の観測の対象は、事象の操作の名前の ε の原子が許す（`Builtins.Allows`。
表の `effKind` で種類を読む）。組み込みの関数の仮定は旧の条件 `CoreAssumptions` と対象一致の条件 `TargetAgreement` だけを
求める。 -/
theorem surface_target_sound {p : Program} {B : Builtins} {opPrim : OpPrim} {ε : Eff}
    (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim)
    (hc : B.CoreAssumptions (desugarProgram opPrim p)) (ht : B.TargetAgreement (desugarProgram opPrim p))
    (hmain : p.HasMain ε) {s s' : State} {b : PrimName} {ws : List Val} {o : Outcome} {obs : List Target}
    (hsteps : Steps (desugarProgram opPrim p) B (.run (.app (.fnRef "main" [] []) []) [] Store.empty) s)
    (hst : Step (desugarProgram opPrim p) B s (some (.io b ws o obs)) s') :
    ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, B.Allows ε l t := by
  obtain ⟨hwf', hwt', heffects⟩ := desugar_typed hwf hwt hc.sig_scoped
  obtain ⟨d, a, -, hsub, hm⟩ := main_typed_eff (B := B) (op := opPrim) hwf hmain
  obtain ⟨e, l, he, hl, hallow⟩ :=
    Release.reachable_target_sound hwf' hwt' heffects hc ht hm ⟨⟨trivial, trivial⟩, trivial⟩ hsteps hst
  exact ⟨e, l, he, hl, fun t htm => ((Eff.allows_substAt_nil 0 [] d.eff).mp (hallow t htm)).mono hsub⟩

end Benitoite.Surface
