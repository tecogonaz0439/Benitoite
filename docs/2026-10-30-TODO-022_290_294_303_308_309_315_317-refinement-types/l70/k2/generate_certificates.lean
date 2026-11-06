import Benitoite.Release.Refinement.Surface.CheckAccept

namespace Benitoite.Release.Refinement.Surface.FieldCheckerExamples
open CheckTables CheckSubtyping
private def field (s : «Sort») (t : Term) : Term := .field ⟨"Box", "Box", 0, s⟩ t
private def box (a : Ty) : ConDecl := ⟨"Box", 0, [a]⟩

private def closeLinear (size : Nat) (facts : List NNF) :
    List (NNF × Nat) → Linear → List (Nat × Int) → Option Refutation
  | [], _, _ => none
  | (.linear x, i) :: rest, sum, weights =>
      let next : Linear := ⟨List.zipWith (· + ·) sum.coefficients x.coefficients, sum.bound + x.bound⟩
      let weights := weights ++ [(i,1)]
      let step := LinearStep.combine weights next
      if step.check size facts && CertificateKernel.closeLinear (facts ++ [.linear next]) facts.length then
        some (.derive step (.closeLinear facts.length))
      else (closeLinear size facts rest next weights).or (closeLinear size facts rest sum (weights.dropLast))
  | _ :: rest, sum, weights => closeLinear size facts rest sum weights

/-- 有限の例の反証候補を作る。成功の根拠は既存の証明書検査だけである。 -/
private def solve (keys : KeyTable) : Nat → List NNF → List NNF → Option Refutation
  | 0, _, _ => none
  | n+1, todo, facts =>
    let atom := (facts.zipIdx).findSome? fun (_,i) => (facts.zipIdx).findSome? fun (_,j) =>
      if CertificateKernel.closeAtom facts i j then some (.closeAtom i j) else none
    match atom with
    | some proof => some proof
    | none => match todo with
      | [] => closeLinear keys.length facts facts.zipIdx ⟨List.replicate keys.length 0, 0⟩ []
      | .falsity :: _ => some (.consume (.closeAtom 0 0))
      | .truth :: rest => (solve keys n rest facts).map .consume
      | .linear l :: rest => (solve keys n rest (facts ++ [.linear l])).map .consume
      | .literal p b :: rest => (solve keys n rest (facts ++ [.literal p b])).map .consume
      | .and p q :: rest => (solve keys n (p::q::rest) facts).map .consume
      | .or p q :: rest => match solve keys n rest facts with
        | some proof => some (.discardTodo proof)
        | none => do return .cases (← solve keys n (p::rest) facts) (← solve keys n (q::rest) facts)

private def certificate (premises : List Pred) (goal : Pred) (leaf : PreparedLeaf) : ExchangeCertificate :=
  let premise := Pred.ofConjuncts (premises.flatMap Pred.conjuncts)
  let keys := premise.linearKeys ++ goal.linearKeys ++ leaf.predicate.linearKeys
  let proof := do
    let root ← normalize keys (.and premise (.not goal)) false
    let extra ← normalize keys leaf.predicate false
    return Refutation.builtin leaf (← solve keys 80 [extra,root] [])
  ⟨.refute (proof.getD (.closeAtom 0 0)), []⟩

private inductive Payload where
  | decimal | float64 | float32 | string | map | set | bytes

private def payloadType : Payload → Ty
  | .decimal => .base .decimal | .float64 => .base .float | .float32 => .base .float32
  | .string => .base .string | .map => .map (.base .unit) (.base .unit)
  | .set => .set (.base .unit) | .bytes => .bytes

private def payloadSort : Payload → «Sort»
  | .decimal => .decimal | .float64 => .float64 | .float32 => .float32
  | .string => .string | .map => .map | .set => .set | .bytes => .bytes

private def payloadAtom : Payload → Term → Pred
  | .decimal, t => .compare .decimal .ge t (.decimal 0 0)
  | .float64, t => .compare .float64 .ge t (.float64 0)
  | .float32, t => .compare .float32 .ge t (.float32 0)
  | .string, t => .charactersIn t 'a' 'z'
  | .map, t => .eq (.measure .mapSize t) (.integer 0)
  | .set, t => .eq (.measure .setSize t) (.integer 0)
  | .bytes, t => .eq (.measure .bytesLength t) (.integer 0)

private def payloadArguments : Payload → List Term
  | .decimal => [.decimal 0 0] | .float64 => [.float64 0] | .float32 => [.float32 0]
  | .string => [.character 'a', .character 'z'] | _ => []

private def payloadProof (x : Payload) : ExchangeCertificate :=
  let a := Term.var 0
  let b := field (payloadSort x) (.var 1)
  let relation := accessorPred "Box" (box (payloadType x)) 0
  let premises := relation :: (payloadType x).carrierFacts ++ [payloadAtom x b, payloadAtom x (field (payloadSort x) (.var 2))]
  let clause := BuiltinSchema.implies (.and (fieldRelation (payloadSort x) [] none a b) (payloadAtom x b)) (payloadAtom x a)
  certificate premises (payloadAtom x a)
    (match x with
     | .map | .set | .bytes => ⟨.truth, .closed, [], []⟩
     | _ => ⟨clause, .fieldAtom (payloadSort x) [], a :: b :: payloadArguments x, []⟩)

private def showLinear (l : Linear) : String := "⟨[" ++ String.intercalate "," (l.coefficients.map toString) ++ "]," ++ toString l.bound ++ "⟩"
private def showStep : LinearStep → String
  | .combine ts l => ".combine [" ++ String.intercalate "," (ts.map fun (i,k) => "(" ++ toString i ++ "," ++ toString k ++ ")") ++ "] " ++ showLinear l
  | .round i d l => ".round " ++ toString i ++ " " ++ toString d ++ " " ++ showLinear l
private def showProof : Refutation → String
  | .consume c => ".consume (" ++ showProof c ++ ")"
  | .cases l r => ".cases (" ++ showProof l ++ ") (" ++ showProof r ++ ")"
  | .derive s c => ".derive (" ++ showStep s ++ ") (" ++ showProof c ++ ")"
  | .closeLinear i => ".closeLinear " ++ toString i
  | .closeAtom i j => ".closeAtom " ++ toString i ++ " " ++ toString j
  | .discardTodo c => ".discardTodo (" ++ showProof c ++ ")"
  | _ => "UNEXPECTED"
private def bodyProof (x : Payload) : Refutation := match (payloadProof x).certificate with
  | .refute (.builtin _ next) => next | _ => .closeAtom 0 0
#eval IO.println ("decimal: " ++ showProof (bodyProof .decimal))
#eval IO.println ("float64: " ++ showProof (bodyProof .float64))
#eval IO.println ("float32: " ++ showProof (bodyProof .float32))
#eval IO.println ("string: " ++ showProof (bodyProof .string))
#eval IO.println ("map: " ++ showProof (bodyProof .map))
#eval IO.println ("set: " ++ showProof (bodyProof .set))
#eval IO.println ("bytes: " ++ showProof (bodyProof .bytes))
end Benitoite.Release.Refinement.Surface.FieldCheckerExamples
