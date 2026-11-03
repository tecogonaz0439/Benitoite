import Benitoite
open Benitoite.Release.Refinement
namespace Benitoite.Release.Refinement.Signatures

-- F03: 閉じた scalar と Boolean
#check (∀ {P B Ψ Q C Φ v T tag},
  HasTypeVQ P B Ψ Q C [] Φ v T → T.norm.core = .base tag →
  ∃ c, v = .const c ∧ ConstOK B c ∧ c.type.norm.core = .base tag : Prop)
#check (∀ {P B Ψ Q C Φ v T},
  HasTypeVQ P B Ψ Q C [] Φ v T → T.norm.core = .base .boolean →
  ∃ b, v = .const (.boolean b) : Prop)

-- F03: 同じストアと固定したσの四つの入口
#check (∀ {P B σ Ψ μ l a}, StoreOk P B σ Ψ μ → Ψ l = some (.ref a) →
  ∃ v, μ l = some (.val v) ∧ HasTypeV P B Ψ [] [] [] v a.norm ∧ v.Adequate σ : Prop)
#check (∀ {P B σ Ψ μ l a}, StoreOk P B σ Ψ μ → Ψ l = some (.lazy a) →
  (∃ q, μ l = some (.thunk q) ∧
    ClosureTy P B (hideBuilders Ψ) [] none q a Eff.empty ∧ q.Adequate σ) ∨
  (∃ v, μ l = some (.done v) ∧ HasTypeV P B Ψ [] [] [] v a ∧ v.Adequate σ) : Prop)
#check (∀ {P B σ Ψ μ l b t e r}, StoreOk P B σ Ψ μ → Ψ l = some (.cont b t e r) →
  (∃ k, μ l = some (.cont k) ∧ EndsWithHandle k ∧
    ∃ R' e', ContTy P B σ Ψ R' e' k b t e r) ∨ μ l = some .used : Prop)
#check (∀ {P B σ Ψ μ l kind}, StoreOk P B σ Ψ μ → Ψ l = some (.builder kind) →
  ∃ c, μ l = some (.builder c) ∧ BuilderCellOk P B Ψ kind c ∧
    Cell.Adequate σ (.builder c) : Prop)

-- F02: 文脈の形成を明示した全列の入口。
#check (∀ {P B Ψ Q C Γ Φ t u ws a e},
    P.WellFormed → B.CoreAssumptions P → Ψ.WF → Ctx.WF 0 C.length Γ →
    Ty.Annotation P C Γ (.dependentFn t) → Ty.Annotation P C Γ (.dependentFn u) →
    TelClosure P Γ Φ t u → HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e →
    ∃ b f, HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t b f ∧
      Ty.LeQ P Γ Φ b a ∧ Eff.Covers Γ Φ e f : Prop)

-- F07: 五つの定義を固定し、その定義について局所規則の型を検査する。
def joinV : Shared.ValueApprox → Shared.ValueApprox → Shared.ValueApprox
  | .bottom, b => b
  | a, .bottom => a
  | .integer k a, .integer l b =>
      if same : l = k then .integer k (Benitoite.Interval.join a (same ▸ b)) else .unknown
  | .boolean f t, .boolean g u => .boolean (f || g) (t || u)
  | _, _ => .unknown

def normalF (a : Shared.ValueApprox) : Shared.FlowApprox := ⟨a,.bottom,false⟩
def returnF (f : Shared.FlowApprox) : Shared.FlowApprox :=
  ⟨.bottom,joinV f.normal f.returned,f.mayFail⟩
def joinF (f g : Shared.FlowApprox) : Shared.FlowApprox :=
  ⟨joinV f.normal g.normal,joinV f.returned g.returned,f.mayFail || g.mayFail⟩
def seqF (f g : Shared.FlowApprox) : Shared.FlowApprox :=
  ⟨g.normal,joinV f.returned g.returned,f.mayFail || g.mayFail⟩

#check (∀ a b v, a.Mem v → (joinV a b).Mem v : Prop)
#check (∀ a b v, b.Mem v → (joinV a b).Mem v : Prop)
#check (∀ a v, a.Mem v → (normalF a).NormalMem v : Prop)
#check (∀ f (outcome : Benitoite.Interval.EvalOutcome),
  f.ResultMem outcome.toApprox →
    (returnF f).ResultMem (Benitoite.Interval.returnOutcome outcome).toApprox : Prop)
#check (∀ f g (outcome : Benitoite.Interval.EvalOutcome),
  f.ResultMem outcome.toApprox → (joinF f g).ResultMem outcome.toApprox : Prop)
#check (∀ f g (outcome : Benitoite.Interval.EvalOutcome),
  g.ResultMem outcome.toApprox → (joinF f g).ResultMem outcome.toApprox : Prop)
#check (∀ f g (outcome : Benitoite.Interval.EvalOutcome),
  g.ResultMem outcome.toApprox → (seqF f g).ResultMem outcome.toApprox : Prop)
#check (∀ f g (outcome : Benitoite.Interval.EvalOutcome),
  outcome.Abrupt → f.ResultMem outcome.toApprox →
    (seqF f g).ResultMem outcome.toApprox : Prop)

end Benitoite.Release.Refinement.Signatures
