import Benitoite.Release.Refinement.BuiltinTypingTransport

/-! # 宣言のcarrierを満たす生の外部応答 -/
namespace Benitoite.Release.Refinement
namespace ExternalModel

/-- 外部宣言の結果carrierと非exitを満たし、IO対象を生じない抽象応答。 -/
def response (P : Program) (base : Builtins)
    (f : ExternalFunctionId) (ts : List Ty) (vs : List Val)
    (out : Outcome) (obs : List Benitoite.Scope.Domain.Target) : Prop :=
  obs = [] ∧ ∀ Ψ d a e,
    P.externalFunction f = some d → ExternalArgs P base Ψ d ts vs a e →
    Outcome.Carrier P base Ψ out a ∧ (∀ n : Int, out ≠ .exit n)

/-- 型付けの七射影とδ・IOを保ち、外部応答と解放を選ぶ。 -/
def builtins (P : Program) (base : Builtins)
    (release : Val → Option Benitoite.Release.ErrKind → Prop) : Builtins :=
  { base with externalResponse := response P base, releaseResponse := release }

theorem typing_fields (P : Program) (base : Builtins)
    (release : Val → Option Benitoite.Release.ErrKind → Prop) :
    Builtins.TypingFieldsEq base (builtins P base release) :=
  ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

/-- 実行時エラーは、宣言や引数の有無によらず生の応答に属する。 -/
theorem response_err (P : Program) (base : Builtins) (f : ExternalFunctionId)
    (ts : List Ty) (vs : List Val) (r : Benitoite.Release.ErrKind) :
    response P base f ts vs (.err r) [] := by
  refine ⟨rfl, ?_⟩
  intro Ψ d a e _ _
  exact ⟨trivial, by intro n; simp⟩

/-- 正常応答の存在を要求せず、全入力に応答を一つ供給する。 -/
theorem response_exists (P : Program) (base : Builtins) (f : ExternalFunctionId)
    (ts : List Ty) (vs : List Val) : ∃ out obs, response P base f ts vs out obs :=
  ⟨.err "ExternalFailure", [], response_err P base f ts vs _⟩

/-- 拡張表の応答も、同じ表の型付けで読み取れる。 -/
example {P base Ψ Q C Γ Φ v a}
    (release : Val → Option Benitoite.Release.ErrKind → Prop)
    (typed : HasTypeVQ P base Ψ Q C Γ Φ v a) (f : ExternalFunctionId)
    (ts : List Ty) (vs : List Val) :
    HasTypeVQ P (builtins P base release) Ψ Q C Γ Φ v a ∧
    ∃ out obs, (builtins P base release).externalResponse f ts vs out obs :=
  ⟨typed.of_fields (typing_fields P base release), response_exists P base f ts vs⟩

end ExternalModel
end Benitoite.Release.Refinement
