import Benitoite.Release.Refinement.PredicateResponse
import Benitoite.Release.Refinement.ScopeSignatureFormation

/-! # リテラルを固定した判定の内部の行

パターンと文字集合の端を行に固定し、動的な対象だけを引数にする。結果の真偽と対象の述語の一致を依存する結果型に置く。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateRows
open Scope.Domain PredicateResponse
noncomputable section

/-- 述語に写せる判定の、固定した引数。 -/
inductive Entry where
  | path (pattern : PathPattern)
  | host (pattern : HostPattern)
  | characters (minimum maximum : Char)
  | floating (width : FloatWidth) (test : FloatTest)
  deriving DecidableEq

/-- 内部行へ固定する絶対パターンの整形式。 -/
def Entry.Valid : Entry → Prop
  | .path p => p.WF
  | .host p => p.WF
  | .characters _ _ | .floating _ _ => True

instance (entry : Entry) : Decidable entry.Valid := by
  cases entry <;> unfold Entry.Valid <;> infer_instance

def Entry.input : Entry → BaseTy
  | .path _ | .host _ | .characters _ _ => .string
  | .floating .binary64 _ => .float
  | .floating .binary32 _ => .float32

def Entry.sort : Entry → «Sort»
  | .path _ | .host _ | .characters _ _ => .string
  | .floating .binary64 _ => .float64
  | .floating .binary32 _ => .float32

/-- 結果が真であることと述語が成り立つことの一致。 -/
def agreementAt (result : Term) (p : Pred) : Pred :=
  .or (.and (.compare .boolean .eq result (.boolean true)) p)
    (.and (.not (.compare .boolean .eq result (.boolean true))) (.not p))

def agreement (p : Pred) : Pred := agreementAt (.var 0) p

def Entry.predicate : Entry → Term → Pred
  | .path p, value => .member .path value (.absolute (.path p))
  | .host p, value => .member .host value (.absolute (.host p))
  | .characters lo hi, value => .charactersIn value lo hi
  | .floating w test, value => test.predicate w value

def Entry.result (entry : Entry) (value : Term) : Ty :=
  .refined (.base .boolean) (agreement (entry.predicate value))

def Entry.signature (entry : Entry) : PrimSig :=
  ⟨[], 0, ["value"], [.base entry.input], entry.result (.var 1), Eff.empty,
    (fun _ ts => ts = []), .pure, none, [], .untargeted⟩

def Entry.run : Entry → List Val → Bool
  | .path p, [.const (.string s)] => stringMember .path (.absolute (.path p)) s
  | .host p, [.const (.string s)] => stringMember .host (.absolute (.host p)) s
  | .characters lo hi, [.const (.string s)] =>
      API.characters.run [.const (.string s), .const (.character lo), .const (.character hi)]
  | .floating w test, values => (API.floating w test).run values
  | _, _ => false

def Entry.delta (entry : Entry) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (values : List Val) : Option Outcome :=
  if ts = [] ∧ es = [] ∧ rs = [] then some (.val (.const (.boolean (entry.run values)))) else none

/-- 結果の依存列は、対象を束縛した位置を保つ。 -/
theorem instantiated (entry : Entry) :
    instantiatedTel (Tel.instR [] entry.signature.tel) [] [] =
      .param "value" (.base entry.input) (.done (entry.result (.var 1)) Eff.empty) := by
  cases entry <;> try (rename_i w t; cases w using FloatWidth.casesOn <;> cases t)
  all_goals simp [Entry.signature, Entry.input, Entry.result, Entry.predicate,
    agreement, agreementAt, FloatTest.predicate, PrimSig.tel, signatureTel, instantiatedTel,
    Tel.instR, Tel.substRAt, Tel.mapRanges,
    Tel.bind, Tel.rawBind, Ty.rawBind, rawBindTys, Eff.rawBind, Tel.norm, Ty.norm,
    Ty.normTys, Ty.refineNorm, Ty.packRefinements, Ty.refinementPredicates, Pred.conjuncts, Pred.ofConjuncts, Ty.shiftV, Eff.norm, Eff.empty, typeEnvAt, SubstEnv.up, substAtoms_nil,
    instAtoms_nil, rowFails, predBind, termBind, termBind?,
    upValues]

/-- 判定の述語への値の置換は、対象の項への置換だけである。 -/
theorem predicate_bind (entry : Entry) (ν : ObservationEnv) (t : Term) :
    predBind ν (entry.predicate t) = entry.predicate (termBind ν t) := by
  cases entry <;> try (rename_i w test; cases test using FloatTest.casesOn)
  all_goals rfl

private theorem agreement_closed {p : Pred} {b : Bool}
    (he : p.evalClosed = some b) :
    (agreementAt (.boolean b) p).evalClosed = some true := by
  have hw : p.WF 0 ∧ p.Sorted [] none := by
    unfold Pred.evalClosed at he
    split at he
    · assumption
    · cases he
  have hv : p.evalWith (fun _ => none) = some b := by
    simpa [Pred.evalClosed, hw] using he
  have hW : p.VarsIn (fun _ => False) := by simpa [Pred.WF] using hw.1
  cases b <;>
    simp +decide [agreementAt, Pred.evalClosed, Pred.WF, Pred.VarsIn, Pred.Sorted,
      hW, hw.2, Pred.evalWith, Pred.atomValue, observeAs, Term.interpret,
      Observation.compare, Comparison.fromEqLt, hv]

/-- 一致の篩は、外側の結合が選言であるため一つの篩として正規形になる。 -/
theorem result_normal (entry : Entry) (t : Term) :
    (entry.result t).norm = entry.result t := by
  simp [Entry.result, agreement, agreementAt, Ty.norm, Ty.refineNorm,
    Ty.packRefinements, Ty.refinementPredicates, Pred.conjuncts, Pred.ofConjuncts]

theorem result_bind (entry : Entry) (θ : SubstEnv) (t : Term) :
    Ty.bind θ (entry.result t) = entry.result (termBind (upValues θ.values) t) := by
  simp [Ty.bind, Ty.rawBind, Entry.result, agreement, agreementAt, predBind,
    upValues, predicate_bind, Ty.norm, Ty.refineNorm, Ty.packRefinements,
    Ty.refinementPredicates, Pred.conjuncts, Pred.ofConjuncts]

theorem result_accepts (entry : Entry) {t : Term} {b : Bool}
    (he : (entry.predicate t).evalClosed = some b) :
    BooleanResult.accepts b (entry.result t) = true := by
  have hw : (entry.predicate t).WF 0 := by
    unfold Pred.evalClosed at he
    split at he
    · exact (show (entry.predicate t).WF 0 ∧ _ from by assumption).1
    · cases he
  have heq : (agreement (entry.predicate t)).open (.boolean b) =
      agreementAt (.boolean b) (entry.predicate t) := by
    change agreementAt (.boolean b) (predBind _ (entry.predicate t)) = _
    rw [Pred.bind_closed hw]
  simp only [Entry.result, BooleanResult.accepts, heq, Bool.true_and]
  simp [Pred.closedTrue, agreement_closed he]

/-- 内部行の署名は、宣言した深さと引数のsortで形成される。 -/
theorem signature_scoped (P : Refinement.Program) (entry : Entry) :
    PrimSig.Scoped P entry.signature := by
  cases entry <;> try (rename_i w test; cases w using FloatWidth.casesOn <;> cases test)
  all_goals constructor
  all_goals simp [Entry.signature, Entry.input, Entry.result, Entry.predicate, agreement, agreementAt,
    FloatTest.predicate, PrimSig.tel, signatureTel, NamesWF, Ty.SourceScoped,
    Ty.WF, Tel.WF, Ty.WFList, RangeIx.WF, Pred.WF, Pred.VarsIn, Term.VarsIn,
    Ty.RowsIn, Tel.RowsIn, Ty.RowsInList, Eff.RowsIn, Ty.RangesScoped,
    Tel.RangesScoped, rangesScopedTypes, Eff.RangesScoped, Eff.WF,
    Eff.empty, Eff.Canonical, Eff.norm, Ty.normTys, Ty.HasKind, kindsTel,
    kindsList, kindsEff, TypeCtx.kinds, Tel.Sorted, Ty.Sorted, sortedTys, sortedEff,
    Term.HasSort, Term.References, Term.Shape, Ctx.Readable, Ty.HasSort, Ty.sort?,
    Pred.Sorted, Comparison.Allowed, Tel.Declared, Ty.Declared, declaredEff,
    declaredTys, Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.extend,
    Ty.shiftV, Ordinary, Ty.core, Ty.NotContCore]

/-- パターンを解釈した内部行は、公開の文字列の判定と同じ値を返す。 -/
theorem path_run {pattern : String} {p : PathPattern}
    (hp : parseAtPattern .path (.const (.string pattern)) = some (.absolute (.path p))) (s : String) :
    (Entry.path p).run [.const (.string s)] = API.path.run [.const (.string pattern), .const (.string s)] := by
  simp [Entry.run, API.run, matchString, hp]

theorem host_run {pattern : String} {p : HostPattern}
    (hp : parseAtPattern .host (.const (.string pattern)) = some (.absolute (.host p))) (s : String) :
    (Entry.host p).run [.const (.string s)] = API.host.run [.const (.string pattern), .const (.string s)] := by
  simp [Entry.run, API.run, matchString, hp]

end
end Benitoite.Release.Refinement.Surface.PredicateRows
