import Benitoite.Release.Refinement.BuiltinTypingTransport

/-! # 外部宣言を読む表層・脱糖の型付き入力 -/
namespace Benitoite.Release.Refinement.ExternalSurface

/-- 同じ宣言の適格な型引数を、外部関数の参照へ渡す。 -/
theorem ref_typed {P B Ψ Q C Γ Φ f d ts}
    (lookup : P.externalFunction f = some d) (wf : d.WF P)
    (admissible : ExternalCallAdmissible P B C d ts)
    (inst : SignatureInstance P C Γ d.parameters d.kinds ts []) :
    HasTypeVQ P B Ψ Q C Γ Φ (.externalRef f ts)
      (.dependentFn (instantiatedTel d.parameters ts [])) :=
  .V_ExternalRef lookup wf admissible inst

/-- 並べ替え・捕捉を終えた実引数を、同じ宣言の依存列へ渡す。 -/
theorem call_typed {P B Ψ Q C Γ Φ R Δ f d ts ws a e}
    (lookup : P.externalFunction f = some d) (wf : d.WF P)
    (admissible : ExternalCallAdmissible P B C d ts)
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws
      (Tel.bind (typeEnv ts) d.parameters) a e) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.externalCall f ts ws) a e Δ :=
  .C_External lookup wf admissible args

/-- 応答関係を差し替えた表でも、参照と呼出しの全添字を保つ。 -/
example {P B B' Ψ Q C Γ Φ R Δ f d ts ws a e}
    (fields : Builtins.TypingFieldsEq B B')
    (lookup : P.externalFunction f = some d) (wf : d.WF P)
    (admissible : ExternalCallAdmissible P B C d ts)
    (inst : SignatureInstance P C Γ d.parameters d.kinds ts [])
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws (Tel.bind (typeEnv ts) d.parameters) a e) :
    HasTypeVQ P B' Ψ Q C Γ Φ (.externalRef f ts)
      (.dependentFn (instantiatedTel d.parameters ts [])) ∧
    HasTypeCQ P B' Ψ Q C Γ Φ R (.externalCall f ts ws) a e Δ :=
  ⟨(ref_typed lookup wf admissible inst).of_fields fields,
    (call_typed lookup wf admissible args).of_fields fields⟩

end Benitoite.Release.Refinement.ExternalSurface
