import Benitoite
namespace Benitoite.Release.Refinement
/-! L70 の主定理の言明の形の試行（本番に入れない）。sorry を使わず、言明を Prop の定義として型検査するだけ。 -/

/-- 新しい状態の終端。旧 `State.Final` に当たる定義は Refinement にない。 -/
def State.FinalL70 : State → Prop
  | .run q [] _ => ∃ v, q.view = .ret v
  | .error _ [] _ => True
  | .exit _ _ [] _ => True
  | _ => False

def ProgressStmt (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P → ∀ s, StateTy P B σ s →
    s.FinalL70 ∨ ∃ l s', Step P B σ s l s'

def PreservationStmt (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P →
    ∀ s l s', StateTy P B σ s → Step P B σ s l s' → StateTy P B σ s'

def StepSoundStmt (P : Program) (B : Builtins) (σ : PathEnv) (oracle : Oracle) (ext : ExternalOracle)
    (rel : Val → Option ErrKind) (fresh : Store → Nat) : Prop :=
  B.CoreAssumptions P → ∀ s l s', StateTy P B σ s →
    step P B σ oracle ext rel fresh s = some (l, s') → Step P B σ s l s'

/-- 開始状態は空の捕捉の閉包。型は ClosureTy で読む。 -/
def EffectSoundStmt (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P → σ.Valid →
    ∀ (q : Closure) (a : Ty), ClosureTy P B StoreTy.empty [] none q a Eff.empty →
    ∀ evs s, Steps P B σ (.run q [] Store.empty) evs s →
      (∀ ev s', ¬ Step P B σ s (some ev) s') ∧ ¬ UnhandledOp s

def TargetStmt (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P → B.TargetAgreement P → σ.Valid →
    ∀ (q : Closure) (a : Ty) (ε : Eff), ClosureTy P B StoreTy.empty [] none q a ε →
    ∀ evs s s' b ws o obs, Steps P B σ (.run q [] Store.empty) evs s →
      Step P B σ s (some (.io b ws o obs)) s' →
      ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind ε l t

/-- 合成表の言明をそのまま主定理の前提へ当てられることの型の確認（固定の合成プログラム）。 -/
def StandardInstance (externals : List (ExternalKey × ExternalDecl)) (σ : PathEnv) : Prop :=
  (StandardModel.program externals).ExternalWF →
  ProgressStmt (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) σ

example (externals : List (ExternalKey × ExternalDecl)) (hw : (StandardModel.program externals).ExternalWF) :
    (StandardModel.program externals).WellTyped (StandardModel.builtins (StandardModel.program externals)) ∧
    (StandardModel.program externals).WellFormed ∧
    Builtins.CoreAssumptions (StandardModel.program externals) (StandardModel.builtins (StandardModel.program externals)) :=
  ⟨StandardModel.program_typed externals hw, StandardModel.program_wellFormed externals hw, StandardModel.core externals⟩

/-- R10 の欄どうしの依存を record 全体の篩へ写す形（Term.field が既にある）。 -/
def spanRef (pos : Nat) : FieldRef := ⟨"Span", "Span", pos, .integer⟩
def spanRefined : Ty := .refined (.data "Span" []) (.le (.field (spanRef 0) (.var 0)) (.field (spanRef 1) (.var 0)))

/-- R9(a) の構成子の判定の関数の結果の篩（核の Pred.constructorIs を使う）。 -/
def isCircleResult : Ty :=
  .refined (.base .boolean)
    (.or (.and (.eq (.var 0) (.boolean true)) (.constructorIs (.var 1) "Shape.Circle"))
         (.and (.eq (.var 0) (.boolean false)) (.not (.constructorIs (.var 1) "Shape.Circle"))))

end Benitoite.Release.Refinement
