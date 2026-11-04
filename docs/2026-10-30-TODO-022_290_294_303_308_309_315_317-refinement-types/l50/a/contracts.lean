import Benitoite
import Benitoite.Release.Refinement.EffectTargets
import Benitoite.Release.Refinement.TargetModelConditions
import Benitoite.Release.Refinement.ScopeDeclarations
namespace L50Contracts
open Benitoite.Release.Refinement
/-- 適格な捕捉と元の bases 値から供給する。CaptureOk は不要。 -/
def F06Current : Prop := ∀ {B σ cap kind name bs p v ix snap pat t bound},
    cap.Adequate σ → (∀ b, bs = some b → b.Adequate σ) →
    AtPrepared B cap kind name bs p v ix snap pat t bound →
    ∀ ρ, snap = some ρ → ρ = σ
/-- 元の署名は型付けの証拠も渡す。未使用の shape は束縛しない。 -/
def F06CurrentOriginal : Prop := ∀ {P B σ Ψ R Γ Φ cap kind name bs p v ix snap pat t bound},
    CaptureOk P B Ψ R Γ Φ cap → cap.Adequate σ →
    (∀ b, bs = some b → b.Adequate σ) →
    AtPrepared B cap kind name bs p v ix snap pat t bound →
    ∀ ρ, snap = some ρ → ρ = σ
example (h : F06Current) : F06CurrentOriginal := by
  intro P B σ Ψ R Γ Φ cap kind name bs p v ix snap pat t bound _ had hb hp
  exact h had hb hp


def F01Path : Prop := ∀ (w : Benitoite.Scope.Domain.Word)
    {p q : Benitoite.Scope.Domain.PathPattern}, p.Covers q →
    (PathPattern.atBase w p).Covers (PathPattern.atBase w q)
def F01Range : Prop := ∀ {outer inner : RangeExpr}, outer.Covers inner →
    ∀ (σ : PathEnv) {k t}, inner.Mem σ k t → outer.Mem σ k t
def F01Snapshot : Prop := ∀ {snapshot k r s t},
    SnapshotMem snapshot k r t → s.Covers r → SnapshotMem snapshot k s t

def F02 : Prop := ∀ {Γ Φ e f σ κ l t}, Eff.Covers Γ Φ e f →
    Eff.Allows σ κ f l t → Eff.Allows σ κ e l t

def F03 : Prop := ∀ {P B Ψ Q v T o k r σ},
    HasTypeVQ P B Ψ Q [] [] [] v T → T.Holds o k (.fixed r) →
    B.valKind o = some k → v.Adequate σ → ∃ t, v.target? = some t ∧ r.Mem σ k t

def F04 : Prop := ∀ {P B Ψ b sg ts es rs ws a e k p σ},
    B.ShapeOk b sg → sg.shape = .single k p → NamesWF sg.names sg.params →
    BuiltinArgs P B Ψ b sg ts es rs ws a e → (∀ w ∈ ws, w.Adequate σ) →
    ∃ r t, rs = [r] ∧ (ws[p]?).bind Val.target? = some t ∧
      r.Mem σ k t ∧ sg.shapeAt ws = .single k p

def F05 : Prop := ∀ {P B Ψ b sg ts es rs ws a e out obs σ},
    B.ShapeOk b sg → B.TargetAgreement P → B.sig b = some sg →
    (sg.kind = .io ∨ sg.kind = .exit) → NamesWF sg.names sg.params →
    BuiltinArgs P B Ψ b sg ts es rs ws a e → (∀ w ∈ ws, w.Adequate σ) →
    B.ioResponse b ts es ws out obs →
    ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind e l t

def F06Resolve : Prop := ∀ {P B σ s r}, σ.Ready P B s →
    PreparationNode.Reachable P B (.state s) (.range r) → ∃ rs, r.resolve σ = some rs

/-- 具体の一つの純粋項目に対する全入力の受け口。 -/
def F07Pure (P : Program) (B : Builtins) (b : Benitoite.Release.PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e, B.sig b = some sg → sg.kind = .pure →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    ∃ out, B.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out

/-- 七つの IO 項目は同じ関係の全応答と応答存在を別々に供給する。 -/
def F07IO (P : Program) (B : Builtins) (b : Benitoite.Release.PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e, B.sig b = some sg → sg.kind = .io →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    (∀ out obs, B.ioResponse b ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧
      (∀ n, out ≠ .exit n) ∧
      Benitoite.Scope.Signature.ShapeTargets Val.target? (sg.shapeAt ws) ws obs) ∧
    ∃ out obs, B.ioResponse b ts es ws out obs

def F07Ground (P : Program) (B : Builtins) (b : Benitoite.Release.PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e out v, B.sig b = some sg → sg.kind = .pure →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    B.delta b ts es rs ws = some out → out = .val v → v.Ground

def F07ExternalRef : Prop := ∀ (id : ExternalFunctionId) (ts : List Ty) (ws : List Val),
    AdequateResult ws (.val (.externalRef id ts))
def F07ExternalHandle : Prop := ∀ (h : ExternalHandle) (ts : List Ty) (ws : List Val),
    AdequateResult ws (.val (.externalHandle h ts))
def F07ScopePattern : Prop := ∀ (r : RangeExpr) (ws : List Val),
    AdequateResult ws (.val (.scopePattern r))
def F07AtError : Prop := ∀ (d : AtError) (ws : List Val), AdequateResult ws (.val (.atError d))

def F08 : Prop := ∀ {P B Ψ Q C Γ Φ t u ws a e}, Ctx.WF 0 C.length Γ →
    Ty.Annotation P C Γ (.dependentFn t) → TelClosure P Γ Φ t u →
    HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e →
    ∃ b f, HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t b f ∧
      Ty.LeQ P Γ Φ b a ∧ Eff.Covers Γ Φ e f

-- B は各モデルの実装が定義する同じ表を表す。条件の入力は増やさない。
def F09Model (B : Builtins) : Prop := ∀ P, ModelScopeConditions P B
def F09File (B : Builtins) : Prop := ∀ P, ScopeDeclarations.HasFile P → ModelScopeConditions P B
def F09Http (B : Builtins) : Prop := ∀ P, ScopeDeclarations.HasHttp P → ModelScopeConditions P B

example : F01Path := @PathPattern.covers_atBase
example : F01Range := @RangeExpr.Covers.mem
example : F01Snapshot := @SnapshotMem.mono
example : F03 := @HasTypeVQ.target_member
example : F04 := @Builtins.ShapeOk.single_target
example : F05 := @Builtins.TargetAgreement.obs_allowed
example : F08 := @TelClosure.apply

-- 保持値四構文の適格性の署名は、任意の ws と全σを保つ。
example : F07ExternalRef := by intro id ts ws σ _ _; trivial
example : F07ExternalHandle := by intro h ts ws σ _ _; trivial
example : F07ScopePattern := by intro r ws σ _ _; trivial
example : F07AtError := by intro d ws σ _ _; trivial
end L50Contracts
