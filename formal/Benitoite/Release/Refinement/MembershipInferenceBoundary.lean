import Benitoite.Release.Refinement.PredicateResponse
import Benitoite.Release.Refinement.LogicSound

/-! # 文字列の長さの事実と、解析による所属の区別 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 同じバイト長と文字数でも、文字列の対象が所属する範囲は異なる。 -/
def stringLengthPremise : Pred :=
  .and (.eq (.measure .stringBytes (.var 0)) (.integer 2))
       (.eq (.measure .stringCharacters (.var 0)) (.integer 2))

def stringMemberGoal : Pred := .member .path (.var 0) (.path (.exact ["a"]))

private theorem length_model :
    stringLengthPremise.interpret (fun _ => some (.string "/b")) = true ∧
    stringMemberGoal.interpret (fun _ => some (.string "/b")) = false := by
  simp +decide [stringLengthPremise,stringMemberGoal,Pred.interpret,Pred.atomValue,integerAs,
    observeAs,Term.interpret,Observation.sort,Observation.measure,stringMember,parseTargetInput,
    splitText,splitChars,Scope.Domain.PathWordWF]

/-- 長さの二つの事実から所属を導く論理の導出は存在しない。 -/
theorem string_length_not_member : ¬ Entails [stringLengthPremise] stringMemberGoal := by
  intro h
  have ht := h.sound (fun _ => some (.string "/b")) (by
    intro q hq; cases List.mem_singleton.mp hq; exact length_model.1)
  rw [length_model.2] at ht
  cases ht

/-- 篩の検査器も、同じ前提から所属を結論する証明書を受理しない。 -/
theorem string_length_certificate_rejected (c : Certificate) :
    CertificateKernel.check stringLengthPremise stringMemberGoal c ≠ true := by
  intro hc
  exact string_length_not_member (Entails.checked hc (.hyp List.mem_cons_self))

/-- 同じ長さの連結の結果でも、対象の所属は解析した内容で区別される。 -/
theorem concatenation_member_contrast :
    ("/" ++ "a").utf8ByteSize = ("/" ++ "b").utf8ByteSize ∧
    stringMember .path (.path (.exact ["a"])) ("/" ++ "a") = true ∧
    stringMember .path (.path (.exact ["a"])) ("/" ++ "b") = false := by
  simp +decide [stringMember,parseTargetInput,splitText,splitChars,Scope.Domain.PathWordWF]

/-- 純粋な判定は Boolean のみを返し、保持対象や要求を作らない。 -/
theorem predicate_no_targets (api : PredicateResponse.API) (ws : List Val) :
    (Val.const (.boolean (api.run ws))).target? = none ∧
    (Val.const (.boolean (api.run ws))).reqTarget = none := ⟨rfl,rfl⟩

/-- 仮定の再使用の証明書も、長さの事実を所属へ読み替えられない。 -/
example : CertificateKernel.check stringLengthPremise stringMemberGoal (.use 0) ≠ true :=
  string_length_certificate_rejected (.use 0)

/-- 絶対形の正常な二つの String を判定しても、保持対象と要求は生じない。 -/
example :
    (Val.const (.boolean (PredicateResponse.API.path.run
      [.const (.string "/"),.const (.string "/")]))).target? = none ∧
    (Val.const (.boolean (PredicateResponse.API.path.run
      [.const (.string "/"),.const (.string "/")]))).reqTarget = none :=
  predicate_no_targets .path [.const (.string "/"),.const (.string "/")]

end
end Benitoite.Release.Refinement
