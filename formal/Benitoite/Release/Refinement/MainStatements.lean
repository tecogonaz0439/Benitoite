import Benitoite.Release.Refinement.StepLeafSelection
import Benitoite.Release.Refinement.ExternalModelTransport
import Benitoite.Release.Refinement.Preparation
import Benitoite.Release.Refinement.EffectFacts
import Benitoite.Release.Refinement.StandardModelCore
import Benitoite.Release.Refinement.StandardModelProgram
import Benitoite.Release.Refinement.StandardModelWellFormed

/-! # 主な定理の言明

設計書 01-12「確かめる性質」の性質 2（進行と保存）と性質 3（エフェクトの健全性・対象健全性）を、篩付きの型の判断の
上の命題として定める。証明は別のモジュールが `theorem progress : ProgressStatement P B σ` の形で閉じる。

- 終端の状態は `⟨return V, [], μ⟩`、`error(r̄, [], μ)`、`exit(n, r̄, [], μ)` である（`State.Final`）。照合の途中の状態
  `matchRun` は終端でない。
- 実行を始める状態は、閉じた閉包を空の継続と空のストアで始めたものである。開始の条件は閉じ方・σ に由来する保持値の
  適格性・開始の状態が要る起点の束縛（`InitialPrepared`）であり、起点の束縛を全状態の不変条件には加えない。
- 抽象の外部呼出しの応答の存在は、外部宣言の表の構造検証と、型付きの実引数を前提に取る（`ExternalAssumptions`）。
  そのため、外部呼出しの状態の進行と、実行関数の外部の分岐の健全性は、プログラムの整形式と型付けを前提に読む。
- 実行関数 `step` が返す遷移が関係の遷移であること（計算から関係への向き）だけを述べる。関係のすべての遷移を返す
  完全性、error・exit を消す保証、正常応答の存在は述べない。
-/
namespace Benitoite.Release.Refinement
noncomputable section

open Scope.Domain (Target)

/-- 終端の状態。値を返して継続が空の実行、継続が空の失敗と終了である。 -/
def State.Final : State → Prop
  | .run q [] _ => ∃ v, q.view = .ret v
  | .error _ [] _ => True
  | .exit _ _ [] _ => True
  | _ => False

/-- 事象が観測した対象。IO の事象だけが観測を持つ。 -/
def Event.targets : Event → List Target
  | .io _ _ _ obs => obs
  | .release _ _ | .pathBases _ _ => []

/-- 実行を始める閉包の条件。閉包は閉じており、保持値は σ に由来し、開始の状態が要る起点の束縛を σ が持つ
（`InitialPrepared` は `σ.Valid` を含む）。 -/
structure StartCondition (P : Program) (B : Builtins) (σ : PathEnv) (q : Closure) : Prop where
  adequate : q.Adequate σ
  closed : q.ClosedAt 0
  prepared : InitialPrepared P B σ (.run q [] Store.empty)

/-- 実行関数が選ぶ応答・新しい場所の条件。IO・外部呼出し・解放の応答は、関係に応答があるときはその一つを選ぶ。
新しい場所は、有限なストアの中身のない場所を選ぶ。 -/
structure StepSelection (B : Builtins) (oracle : Oracle) (externalOracle : ExternalOracle)
    (rel : Val → Option ErrKind) (fresh : Store → Nat) : Prop where
  io : ∀ b ts es ws o obs, B.ioResponse b ts es ws o obs →
    B.ioResponse b ts es ws (oracle b ts es ws).1 (oracle b ts es ws).2
  external : ∀ f ts ws o obs, B.externalResponse f ts ws o obs →
    B.externalResponse f ts ws (externalOracle f ts ws).1 (externalOracle f ts ws).2
  release : ∀ v r, B.releaseResponse v r → B.releaseResponse v (rel v)
  fresh : ∀ μ : Store, (∃ n, ∀ l, n ≤ l → μ l = none) → μ (fresh μ) = none

/-- 進行。型が付いた状態は終端であるか、遷移を持つ。 -/
def ProgressStatement (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P →
    ∀ s, StateTy P B σ s → s.Final ∨ ∃ l s', Step P B σ s l s'

/-- 保存。型が付いた状態から遷移した先の状態も型が付く。 -/
def PreservationStatement (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P →
    ∀ s l s', StateTy P B σ s → Step P B σ s l s' → StateTy P B σ s'

/-- 実行の列の保存。 -/
def StepsPreservationStatement (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P →
    ∀ s evs s', StateTy P B σ s → Steps P B σ s evs s' → StateTy P B σ s'

/-- 実行関数の健全性。型が付いた状態について、選択の条件を満たす実行関数が返す遷移は関係の遷移である。 -/
def StepSoundStatement (P : Program) (B : Builtins) (σ : PathEnv) (oracle : Oracle)
    (externalOracle : ExternalOracle) (rel : Val → Option ErrKind) (fresh : Store → Nat) : Prop :=
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P → StepSelection B oracle externalOracle rel fresh →
    ∀ s l s', StateTy P B σ s → step P B σ oracle externalOracle rel fresh s = some (l, s') → Step P B σ s l s'

/-- 開始の状態の型付け。開始の閉包の型付けと開始の条件から、閉包の効果を継続の末尾に固定した状態の型付けを得る。 -/
def InitialTypingStatement (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
    ∀ q a ε, ClosureTy P B StoreTy.empty [] none q a ε → StartCondition P B σ q →
      StateTyE P B σ ε (.run q [] Store.empty)

/-- エフェクトの健全性。空の効果で型が付いた閉包から始めた実行は、事象を伴う遷移をせず、どの `handle` の枠も
処理しない操作を呼ばない。旧体系の二つの形（ラムダ名の整形式を前提に持つ形と持たない形）は、この一つの言明に
当たる。名前の条件は開始の条件の閉じ方（`Closure.ClosedAt` は lam に `NamesWF` を要求する）に含まれ、型付けから
名前の整形式を供給して同じ開始の条件へ接続する。名前の条件を独立の信頼条件にしない。 -/
def EffectSoundnessStatement (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P →
    ∀ q a, ClosureTy P B StoreTy.empty [] none q a Eff.empty → StartCondition P B σ q →
      ∀ evs s, Steps P B σ (.run q [] Store.empty) evs s →
        (∀ ev s', ¬ Step P B σ s (some ev) s') ∧ ¬ UnhandledOp s

/-- 一段の対象健全性。継続の末尾に効果 Eb を固定した状態の IO の事象の観測の対象は、その操作の名前の Eb の原子が
σ の下で許す。 -/
def StepTargetStatement (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.EffectsOk B → B.CoreAssumptions P → B.TargetAgreement P → σ.Valid →
    ∀ Eb s s' b ws o obs, StateTyE P B σ Eb s → Step P B σ s (some (.io b ws o obs)) s' →
      ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind Eb l t

/-- 到達先の対象健全性。型が付いた閉包から始めた実行が到達した状態の IO の事象の観測の対象は、初期の効果 ε の
操作の名前の原子が σ の下で許す。 -/
def ReachableTargetStatement (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P → B.TargetAgreement P →
    ∀ q a ε, ClosureTy P B StoreTy.empty [] none q a ε → StartCondition P B σ q →
      ∀ evs s s' b ws o obs, Steps P B σ (.run q [] Store.empty) evs s →
        Step P B σ s (some (.io b ws o obs)) s' →
        ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind ε l t

/-- 到達先の対象健全性の、事象の種類によらない形。解放と起点の発行の事象は観測を持たない。 -/
def ReachableTargetEventStatement (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P → B.TargetAgreement P →
    ∀ q a ε, ClosureTy P B StoreTy.empty [] none q a ε → StartCondition P B σ q →
      ∀ evs s s' ev, Steps P B σ (.run q [] Store.empty) evs s → Step P B σ s (some ev) s' →
        ∀ t ∈ ev.targets, ∃ b ws o obs e l, ev = .io b ws o obs ∧ B.sig b = some e ∧ e.opEff = some l ∧
          Eff.Allows σ B.effKind ε l t

/-- 合成表から選んだ応答と、空の場所の選択は、実行関数の選択の条件を満たす。 -/
theorem Builtins.selected_stepSelection (B : Builtins) :
    StepSelection B B.selectOracle B.selectExternal B.selectRelease Store.selectFresh where
  io b ts es ws o obs h := Builtins.selectOracle_response ⟨o, obs, h⟩
  external f ts ws o obs h := Builtins.selectExternal_response ⟨o, obs, h⟩
  release v r h := Builtins.selectRelease_response ⟨r, h⟩
  fresh μ h := by
    obtain ⟨n, hn⟩ := h
    have he : ∃ l, μ l = none := ⟨n, hn n (Nat.le_refl n)⟩
    simp only [Store.selectFresh, dite_eq_left he]
    exact Classical.choose_spec he

/-- 合成プログラムと合成表は、外部宣言の表の構造検証の下で、主な定理の言明の前提のうち整形式・型付け・信頼条件・
対象の条件を満たす（効果の検査の前提は利用者のプログラムへの収集で供給する）。 -/
theorem StandardModel.statement_premises (externals : List (ExternalKey × ExternalDecl))
    (hw : (StandardModel.program externals).ExternalWF) :
    (StandardModel.program externals).WellFormed ∧
      (StandardModel.program externals).WellTyped (StandardModel.builtins (StandardModel.program externals)) ∧
      Builtins.CoreAssumptions (StandardModel.program externals)
        (StandardModel.builtins (StandardModel.program externals)) ∧
      Builtins.TargetAgreement (StandardModel.program externals)
        (StandardModel.builtins (StandardModel.program externals)) :=
  ⟨StandardModel.program_wellFormed externals hw, StandardModel.program_typed externals hw,
    StandardModel.core externals, StandardModel.targets externals⟩

/-- 継続が空の失敗は終端であり、照合の途中の状態は終端でない。 -/
example (rs : List ErrKind) (μ : Store) : (State.error rs [] μ).Final := trivial
example (v : Val) (cap : Capture) (μ : Store) : ¬ (State.matchRun v cap [] 0 [] μ).Final := id

/-- 解放の事象は観測を持たず、IO の事象は自身の観測を持つ。 -/
example (v : Val) : (Event.release v none).targets = [] := rfl
example (b : PrimName) (ws : List Val) (o : Outcome) (obs : List Target) :
    (Event.io b ws o obs).targets = obs := rfl

end
end Benitoite.Release.Refinement
