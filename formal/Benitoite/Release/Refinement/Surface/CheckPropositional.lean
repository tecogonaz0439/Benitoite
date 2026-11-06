import Benitoite.Release.Refinement.Surface.CheckInput

/-! # 判定の結果と条件分岐のための命題論理の証明書の候補

否定標準形を分解し、同じ原子の肯定と否定、又は閉じた評価との矛盾だけを探す。
候補は既存の証明書の検査器が再検査する。整数の不等式の探索は行わない。
-/
namespace Benitoite.Release.Refinement.Surface.CheckPropositional

private def weight : NNF → Nat
  | .and a b | .or a b => 1 + weight a + weight b
  | _ => 1

private def contradiction (facts : List NNF) : Option Refutation :=
  ((facts.zipIdx).findSome? fun (_, i) =>
    (facts.zipIdx).findSome? fun (_, j) =>
      if CertificateKernel.closeAtom facts i j then some (.closeAtom i j)
      else if CertificateKernel.closeLinear facts i then some (.closeLinear i)
      else none)

private def booleanConflict (facts : List NNF) : Option Refutation :=
  facts.zipIdx.findSome? fun (p, i) =>
    facts.zipIdx.findSome? fun (q, j) =>
      match p, q with
      | .literal (.compare .boolean .eq t (.boolean b)) false,
        .literal (.compare .boolean .eq u (.boolean c)) false =>
          if termEq t u && decide (b ≠ c) then
            let predicate := .not (.and (.compare .boolean .eq t (.boolean b))
              (.compare .boolean .eq u (.boolean c)))
            some (.builtin ⟨predicate, .booleanApart, [t], []⟩
              (.cases (.consume (.closeAtom i facts.length)) (.consume (.closeAtom j facts.length))))
          else none
      | _, _ => none

private def closedConflict (facts : List NNF) : Option Refutation :=
  facts.zipIdx.findSome? fun (p, i) =>
    match p with
    | .literal atom negative =>
      let goal := if negative then atom else .not atom
      if goal.closedTrue then
        let leaf : PreparedLeaf := ⟨goal, .closed, [], []⟩
        some (.builtin leaf (.consume (if negative then .closeAtom facts.length i else .closeAtom i facts.length)))
      else none
    | _ => none

private def search : Nat → List NNF → List NNF → Option Refutation
  | 0, _, _ => none
  | fuel + 1, todo, facts =>
    match (contradiction facts).orElse (fun _ => booleanConflict facts) with
    | some proof => some proof
    | none => match todo with
      | [] => closedConflict facts
      | .falsity :: _ => some (.consume (.closeAtom 0 0))
      | .truth :: rest => (search fuel rest facts).map Refutation.consume
      | .and a b :: rest => (search fuel (a :: b :: rest) facts).map Refutation.consume
      | .or a b :: rest => do
          return .cases (← search fuel (a :: rest) facts) (← search fuel (b :: rest) facts)
      | atom :: rest => (search fuel rest (facts ++ [atom])).map Refutation.consume

/-- 同じ命題の分解又は閉じた原子で閉じる反証だけを生成し、rawの再検査が通る候補を返す。 -/
def candidate (premises : List Pred) (goal : Pred) : Option CheckSubtyping.ExchangeCertificate := do
  let premise := Pred.ofConjuncts (premises.flatMap Pred.conjuncts)
  let keys := premise.linearKeys ++ goal.linearKeys
  let nnf ← normalize keys (.and premise (.not goal)) false
  let proof ← search (weight nnf + 1) [nnf] []
  let certificate := Certificate.refute proof
  if certificate.check premises goal then
    return { certificate := certificate, actions := [] }
  else none

end Benitoite.Release.Refinement.Surface.CheckPropositional
