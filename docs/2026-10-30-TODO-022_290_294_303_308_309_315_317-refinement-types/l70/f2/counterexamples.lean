import Benitoite

/-! 固定した String の公開署名から所属述語へ写すときの、sort の不一致の再現。
本番の定義・規則を変更せず、既定環境を読む。 -/
namespace Benitoite.Release.Refinement.F2StopEvidence

def pathRange : RangeExpr := .absolute (.path (.exact []))
def hostRange : RangeExpr := .absolute (.host (.name (.exact ["example", "com"])))

theorem path_mapping :
    PublicNames.memberPredicate "Scope.pathMatches" (some pathRange) (.var 0) =
      some (.member .path (.var 0) pathRange) := rfl

theorem host_mapping :
    PublicNames.memberPredicate "Scope.hostMatches" (some hostRange) (.var 0) =
      some (.member .host (.var 0) hostRange) := rfl

/-- 正常な文字列は、任意のプログラム・表・ストアで String の値として型付く。 -/
theorem string_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (s : String) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.string s)) (.base .string) :=
  .V_Const trivial

theorem strings_observe_as_strings (s : String) :
    Val.toTerm? (.const (.string s)) = some (.string s) := rfl

/-- 絶対形の正常な入力であり、相対形の選択は反例に関係しない。 -/
theorem path_input_parses :
    ScopeDelta.parsePattern "/" = some (.exact []) ∧
    parseAtInput .path (.const (.string "/")) = some (.absolute (.path [])) := by decide

theorem host_target_well_formed :
    (Scope.Domain.Target.host (.name ["example", "com"])).WF := by decide

/-- String の変数は、所属の要求する対象の sort を持たない。 -/
theorem string_path_not_sorted :
    ¬ (Pred.member .path (.var 0) pathRange).Sorted [some (.base .string)] none := by decide

theorem string_host_not_sorted :
    ¬ (Pred.member .host (.var 0) hostRange).Sorted [some (.base .string)] none := by decide

/-- 篩の self を String として束縛しても同じ不一致がある。 -/
theorem string_self_not_sorted :
    ¬ (Pred.member .path (.var 0) pathRange).Sorted [] (some (.base .string)) := by decide

/-- 既存の対象値は同じ所属述語の整形式を満たす。 -/
theorem scoped_path_sorted :
    (Pred.member .path (.var 0) pathRange).Sorted
      [some (.scoped "Scope.PathIn" .path (.fixed pathRange))] none := by decide

theorem scoped_host_sorted :
    (Pred.member .host (.var 0) hostRange).Sorted
      [some (.scoped "Scope.HostIn" .host (.fixed hostRange))] none := by decide

/-- D19 は文字列を暗黙に対象へ変換しない。 -/
theorem closed_strings_not_evaluable :
    (Pred.member .path (.string "/") pathRange).evalClosed = none ∧
    (Pred.member .host (.string "example.com") hostRange).evalClosed = none := by decide

/-- 同じ範囲と解析済みの対象では、所属と不所属の両側を評価できる。 -/
theorem closed_targets_accept_reject :
    (Pred.member .path (.targetValue none (.path [])) pathRange).evalClosed = some true ∧
    (Pred.member .path (.targetValue none (.path ["x"])) pathRange).evalClosed = some false ∧
    (Pred.member .host (.targetValue none (.host (.name ["example", "com"]))) hostRange).evalClosed = some true ∧
    (Pred.member .host (.targetValue none (.host (.name ["other", "com"]))) hostRange).evalClosed = some false := by decide

/-- 真偽と所属の一致を返す篩にも、同じ String の引数に対する不一致が残る。 -/
def booleanAgreement (p : Pred) : Pred :=
  .or (.and (.compare .boolean .eq (.var 0) (.boolean true)) p)
      (.and (.not (.compare .boolean .eq (.var 0) (.boolean true))) (.not p))

theorem result_agreement_not_sorted :
    ¬ (booleanAgreement (.member .path (.var 1) pathRange)).Sorted
      [some (.base .string), some (.base .string)] (some (.base .boolean)) ∧
    ¬ (booleanAgreement (.member .host (.var 1) hostRange)).Sorted
      [some (.base .string), some (.base .string)] (some (.base .boolean)) := by decide

end Benitoite.Release.Refinement.F2StopEvidence
