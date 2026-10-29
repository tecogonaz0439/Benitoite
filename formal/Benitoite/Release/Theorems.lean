import Benitoite.Release.Lemmas.StepSound
import Benitoite.Release.Lemmas.EffectSound
import Benitoite.Release.Lemmas.TargetStep

/-!
# コアの最終定理（契約名を持つコア）

設計書 01-12「確かめる性質」の性質 2（進行と保存）と性質 3（エフェクトの健全性）の、初回リリース版の
読み替えの形を、段階 B の範囲で言明し、証明する（段階 B2 で、型クラスとコレクションの構成を加えた）。証明の補題は `Lemmas/` に置く。
初回リリース版の拡張として、到達先の対象健全性（`reachable_target_sound`）を置く（一段の対象健全性は
`Lemmas/TargetStep.lean` の `step_target_sound`）。

共有型と型付けは契約名を含むコアの定義を使う。宣言・値の名前の整形式は、型付けと整形式の判断から導く。

段階 A と違い、遷移を計算する関数 `step` と遷移の関係の一致は、`step` が返す遷移が関係の遷移であること
（`step_sound`）だけを言明する。`step` は例の実行を調べる道具であり、新しい場所と応答の選び方を固定するので、
関係のすべての遷移を返すわけではない。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-- 型が付いた状態について、`step` が返す遷移は `Step` の遷移である。`oracle` と `rel` は、起こりうる応答が
あるときは、その一つを選ぶ（`oracle` は応答と観測の組を選ぶ）。`fresh` は、有限なストアに中身のない場所を選ぶ。 -/
theorem step_sound (hb : B.CoreAssumptions P) (oracle : Oracle) (rel : Val → Option ErrKind) (fresh : Store → Nat)
    (horacle : ∀ b ts es ws o obs, B.ioResponse b ts es ws o obs →
      B.ioResponse b ts es ws (oracle b ts es ws).1 (oracle b ts es ws).2)
    (hrel : ∀ v r, B.releaseResponse v r → B.releaseResponse v (rel v))
    (hfresh : ∀ σ : Store, (∃ n, ∀ l, n ≤ l → σ l = none) → σ (fresh σ) = none)
    {s : State} {l : Option Event} {s' : State} :
    StateTy P B s → step P B oracle rel fresh s = some (l, s') → Step P B s l s' := by
  intro hs h
  obtain ⟨Eb, _, hs⟩ := stateTy_iff.mp hs
  exact step_soundE hb oracle rel fresh horacle hrel hfresh hs h

/-- 進行。型が付いた状態は、`⟨return V, [], σ⟩`、`error(r̄, [], σ)`、`exit(n, r̄, [], σ)` のいずれかであるか、
遷移できる。 -/
theorem progress (hwt : P.WellTyped B) (hdecl : P.EffectsOk B) (hb : B.CoreAssumptions P) {s : State} :
    StateTy P B s → s.Final ∨ ∃ l s', Step P B s l s' := by
  intro hs
  obtain ⟨Eb, hEb, hs⟩ := stateTy_iff.mp hs
  exact progressE hwt hdecl hb hs hEb

/-- 保存。型が付いた状態から遷移した先の状態も型が付く。 -/
theorem preservation (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hb : B.CoreAssumptions P) {s : State} {l : Option Event} {s' : State} :
    StateTy P B s → Step P B s l s' → StateTy P B s' := by
  intro hs hst
  obtain ⟨Eb, hEb, hs⟩ := stateTy_iff.mp hs
  exact stateTy_iff.mpr ⟨Eb, hEb, preservationE hwf hwt hdecl hb hs hst⟩

/-- エフェクトの健全性。`· ⊢c M : A ! { }` が成り立ち、M がエフェクト変数を含まないとき、`⟨M, [], ∅⟩` からの
実行は、事象を伴う遷移（IO の事象と解放の事象）をせず、どの `handle` の枠も処理しない操作を呼ばない。
`· ⊢c M` の R は `none` とする（実行を始める計算は関数の本体の外にあるので `escape` を許さない。01-12「確かめる性質」）。 -/
theorem effect_soundness (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hb : B.CoreAssumptions P) {m : Comp} {a : Ty} :
    HasTypeC P B StoreTy.empty [] [] none m a Eff.empty → m.ClosedNoEffVars →
    ∀ s, Steps P B (.run m [] Store.empty) s →
      (∀ ev s', ¬ Step P B s (some ev) s') ∧ ¬ UnhandledOp s := by
  intro hm hc s hsteps
  have hs := steps_preserve hwf hwt hdecl hb hsteps (stateTyE_init hwf hb hm hc)
  exact ⟨no_event hdecl hb hs, no_unhandledOp hdecl hs builtinOnly_empty⟩

/-- ラムダ名の整形式を外部の前提から除いた、同じエフェクト健全性の保証。 -/
theorem effect_soundness_noLamNames (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hb : B.CoreAssumptions P) {m : Comp} {a : Ty} :
    HasTypeC P B StoreTy.empty [] [] none m a Eff.empty →
    Comp.VarsInNoLamNames 0 (fun _ => False) m →
    ∀ s, Steps P B (.run m [] Store.empty) s →
      (∀ ev s', ¬ Step P B s (some ev) s') ∧ ¬ UnhandledOp s := by
  intro hm hc s hsteps
  have hs := steps_preserve hwf hwt hdecl hb hsteps (stateTyE_init_noLamNames hwf hb hm hc)
  exact ⟨no_event hdecl hb hs, no_unhandledOp hdecl hs builtinOnly_empty⟩

/-! ## 到達先の対象健全性 -/

open Scope.Domain (Target) in
/-- 到達先の対象健全性。`· ⊢c M : A ! ε` が成り立ち、M がエフェクト変数を含まないとき、`⟨M, [], ∅⟩` から到達した
状態の IO の事象 `b(ws) ↦ o` について、b は署名 e と操作の名前 l（`e.opEff = some l`）を持ち、事象の観測の対象は
どれも初期の ε の名前 l の原子が許す（`Builtins.Allows`。Top の原子は名前の種類の全対象を許す）。

信頼条件は `CoreAssumptions` と `TargetAgreement` だけである。言明は初期の ε を継続の末尾に固定した `StateTyE` を
通して示す（`stateTyE_init_eff`・`steps_preserve`・`step_target_sound`）。公開の `StateTy` は末尾の効果を
存在量化するので使わない。 -/
theorem reachable_target_sound (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hc : B.CoreAssumptions P) (ht : B.TargetAgreement P) {m : Comp} {a : Ty} {ε : Eff}
    (hm : HasTypeC P B StoreTy.empty [] [] none m a ε) (hcl : m.ClosedNoEffVars)
    {s s' : State} {b : PrimName} {ws : List Val} {o : Outcome} {obs : List Target}
    (hsteps : Steps P B (.run m [] Store.empty) s) (hst : Step P B s (some (.io b ws o obs)) s') :
    ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, B.Allows ε l t :=
  step_target_sound hdecl hc ht (steps_preserve hwf hwt hdecl hc hsteps (stateTyE_init_eff hwf hc hm hcl)) hst

open Scope.Domain (Target) in
/-- 到達先の対象健全性の、事象の種類によらない形。到達した状態のどの事象の観測の対象も、IO の事象の操作の名前の
初期の ε の原子が許す。解放の事象は観測を持たない。 -/
theorem reachable_target_sound_event (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hc : B.CoreAssumptions P) (ht : B.TargetAgreement P) {m : Comp} {a : Ty} {ε : Eff}
    (hm : HasTypeC P B StoreTy.empty [] [] none m a ε) (hcl : m.ClosedNoEffVars)
    {s s' : State} {ev : Event} (hsteps : Steps P B (.run m [] Store.empty) s) (hst : Step P B s (some ev) s') :
    ∀ t ∈ ev.obs, ∃ b ws o obs e l, ev = .io b ws o obs ∧ B.sig b = some e ∧ e.opEff = some l ∧
      B.Allows ε l t :=
  step_target_sound_event hdecl hc ht (steps_preserve hwf hwt hdecl hc hsteps (stateTyE_init_eff hwf hc hm hcl)) hst

open Scope.Domain (Target) in
/-- 全体の信頼条件のもとでの到達先の対象健全性。 -/
theorem reachable_target_sound_of_assumptions (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hA : B.Assumptions P) {m : Comp} {a : Ty} {ε : Eff}
    (hm : HasTypeC P B StoreTy.empty [] [] none m a ε) (hcl : m.ClosedNoEffVars)
    {s s' : State} {b : PrimName} {ws : List Val} {o : Outcome} {obs : List Target}
    (hsteps : Steps P B (.run m [] Store.empty) s) (hst : Step P B s (some (.io b ws o obs)) s') :
    ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, B.Allows ε l t :=
  reachable_target_sound hwf hwt hdecl hA.core hA.target hm hcl hsteps hst

end Benitoite.Release
