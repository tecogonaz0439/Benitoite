import Benitoite.Release.Refinement.BooleanResult
import Benitoite.Release.Refinement.StandardOperatorArguments
import Benitoite.Release.Refinement.PublicNames

/-! # 純粋な所属・文字集合・浮動小数点の判定 -/
namespace Benitoite.Release.Refinement.PredicateResponse
open Scope.Domain
noncomputable section

inductive FloatTest where
  | finite | infinite | positiveInfinity | negativeInfinity | positiveZero | negativeZero
  deriving DecidableEq

def FloatTest.name : FloatTest → String
  | .finite => "isFinite" | .infinite => "isInfinite"
  | .positiveInfinity => "isPositiveInfinity" | .negativeInfinity => "isNegativeInfinity"
  | .positiveZero => "isPositiveZero" | .negativeZero => "isNegativeZero"

def FloatTest.test (t : FloatTest) (fraction exponent bits : Nat) : Bool :=
  match t with
  | .finite => ieeeClass fraction exponent bits .finite
  | .infinite => ieeeClass fraction exponent bits .positiveInfinity || ieeeClass fraction exponent bits .negativeInfinity
  | .positiveInfinity => ieeeClass fraction exponent bits .positiveInfinity
  | .negativeInfinity => ieeeClass fraction exponent bits .negativeInfinity
  | .positiveZero => ieeeClass fraction exponent bits .positiveZero
  | .negativeZero => ieeeClass fraction exponent bits .negativeZero

inductive API where
  | path | host | characters | floating (width : FloatWidth) (test : FloatTest)
  deriving DecidableEq

def API.name : API → PrimName
  | .path => "Scope.pathMatches" | .host => "Scope.hostMatches"
  | .characters => "String.charactersIn"
  | .floating w t => (match w with | .binary64 => "Float." | .binary32 => "Float32.") ++ t.name

def API.names : API → List String
  | .path => ["pattern","path"] | .host => ["pattern","host"]
  | .characters => ["text","minimum","maximum"]
  | .floating .binary64 _ => ["x"] | .floating .binary32 _ => ["n"]

def API.inputs : API → List Ty
  | .path | .host => [.base .string,.base .string]
  | .characters => [.base .string,.base .character,.base .character]
  | .floating .binary64 _ => [.base .float] | .floating .binary32 _ => [.base .float32]

/-- 実行時の判定は Boolean を返す。リテラルに依存する期待型は BooleanResult.typed が読む。 -/
def API.signature (api : API) : PrimSig :=
  ⟨[],0,api.names,api.inputs,.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

/-- 絶対形の pattern だけを解釈し、相対形・解析失敗を偽とする。 -/
def matchString (k : Kind) (pattern target : String) : Bool :=
  match parseAtPattern k (.const (.string pattern)) with
  | some r@(.absolute _) => stringMember k r target
  | _ => false

def API.run : API → List Val → Bool
  | .path, [.const (.string p),.const (.string s)] => matchString .path p s
  | .host, [.const (.string p),.const (.string s)] => matchString .host p s
  | .characters, [.const (.string s),.const (.character lo),.const (.character hi)] =>
    s.toList.all (fun c => decide (lo.toNat ≤ c.toNat ∧ c.toNat ≤ hi.toNat))
  | .floating .binary64 t, [.const (.float64 b)] => t.test 52 11 b.toNat
  | .floating .binary32 t, [.const (.float32 b)] => t.test 23 8 b.toNat
  | _, _ => false

def API.delta (api : API) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome :=
  if name = api.name ∧ ts = [] ∧ es = [] ∧ rs = [] then some (.val (.const (.boolean (api.run ws)))) else none

theorem instantiated (api : API) :
    instantiatedTel (Tel.instR [] api.signature.tel) [] [] =
      Ty.toTel api.names api.inputs (.base .boolean) Eff.empty := by
  cases api <;> try (rename_i w t; cases w)
  all_goals simp [API.signature,API.names,API.inputs,PrimSig.tel,signatureTel,instantiatedTel,
    Tel.instR,Tel.substRAt,Tel.mapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    Ty.toTel,Ty.shiftV,Eff.shiftV,shiftVTys]

/-- 全ての型付き入力は、純粋な Boolean の非終了応答を持つ。 -/
theorem response {P B Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e) :
    ∃ out, api.delta api.name ts es rs ws = some out ∧ Outcome.Typed P B Ψ out a ∧
      AdequateResult ws out ∧ ∀ n, out ≠ .exit n := by
  have ht : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have he : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have hr : rs = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst ts; subst es; subst rs
  have values := args.arguments
  rw [instantiated] at values
  have names : NamesWF api.names api.inputs := by
    cases api <;> try (rename_i w t; cases w)
    all_goals simp [API.names,API.inputs,NamesWF]
  obtain ⟨_, ar, _⟩ := values.toTelValues names
  have ha : a = .base .boolean := args.result.2.symm.trans ar
  subst a
  exact ⟨.val (.const (.boolean (api.run ws))),by simp [API.delta],
    ⟨.V_Const trivial,trivial⟩,by intro σ _ _; trivial,by intro n; simp⟩

/-- リテラルの絶対範囲を解析した同じ δ と、任意の String の閉じた所属評価は一致する。 -/
theorem matches_evalClosed {k : Kind} {pattern : String} {r : Range}
    (hk : k = .path ∨ k = .host)
    (hp : parseAtPattern k (.const (.string pattern)) = some (.absolute r))
    (s : String) :
    (Pred.member k (.string s) (.absolute r)).evalClosed = some (matchString k pattern s) := by
  rw [matchString, hp]
  have formed := parseAtPattern_formed hp
  exact Pred.evalClosed_stringMember (r := .absolute r) hk formed.2.1 formed.1 rfl s

/-- パスの公開名から写した篩は、任意の String の対象で同じ δ と一致する。 -/
example {pattern : String} {p : PathPattern}
    (hp : parseAtPattern .path (.const (.string pattern)) = some (.path p)) (s : String) :
    (PublicNames.memberPredicate "Scope.pathMatches" (some (.path p)) (.string s)).bind Pred.evalClosed =
      some (API.path.run [.const (.string pattern),.const (.string s)]) :=
  matches_evalClosed (Or.inl rfl) hp s

/-- ホストについても、リテラルの条件と任意の String の対象を用いる。 -/
example {pattern : String} {p : HostPattern}
    (hp : parseAtPattern .host (.const (.string pattern)) = some (.host p)) (s : String) :
    (PublicNames.memberPredicate "Scope.hostMatches" (some (.host p)) (.string s)).bind Pred.evalClosed =
      some (API.host.run [.const (.string pattern),.const (.string s)]) :=
  matches_evalClosed (Or.inr rfl) hp s

/-- 分類関数の同じ名前を読む閉じた述語。 -/
def FloatTest.predicate (w : FloatWidth) (t : FloatTest) (value : Term) : Pred :=
  match t with
  | .finite => .floatClass w .finite value
  | .infinite => .or (.floatClass w .positiveInfinity value) (.floatClass w .negativeInfinity value)
  | .positiveInfinity => .floatClass w .positiveInfinity value
  | .negativeInfinity => .floatClass w .negativeInfinity value
  | .positiveZero => .floatClass w .positiveZero value
  | .negativeZero => .floatClass w .negativeZero value

/-- 篩の公開名の写しと、実行する分類は同じ類を指す。 -/
theorem float_mapping (w : FloatWidth) (t : FloatTest) (value : Term) :
    PublicNames.floatPredicate w t.name value = some (t.predicate w value) := by
  cases t <;> rfl

/-- Float のビット列を保持して、通常の判定と篩の真偽を一致させる。 -/
theorem float64_eval (t : FloatTest) (bits : UInt64) :
    (t.predicate .binary64 (.float64 bits)).evalClosed =
      some ((API.floating .binary64 t).run [.const (.float64 bits)]) := by
  cases t <;> simp [FloatTest.predicate,FloatTest.test,API.run,Pred.evalClosed,Pred.WF,Pred.VarsIn,
    Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Term.VarsIn,Pred.evalWith,Pred.atomReady,
    termReady,Term.observe,Observation.sort,Pred.atomValue,observeAs,Term.interpret]
  cases ieeeClass 52 11 bits.toNat .positiveInfinity <;>
    cases ieeeClass 52 11 bits.toNat .negativeInfinity <;> rfl

/-- Float32 も同じ有限述語と分類の関数を読む。 -/
theorem float32_eval (t : FloatTest) (bits : UInt32) :
    (t.predicate .binary32 (.float32 bits)).evalClosed =
      some ((API.floating .binary32 t).run [.const (.float32 bits)]) := by
  cases t <;> simp [FloatTest.predicate,FloatTest.test,API.run,Pred.evalClosed,Pred.WF,Pred.VarsIn,
    Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Term.VarsIn,Pred.evalWith,Pred.atomReady,
    termReady,Term.observe,Observation.sort,Pred.atomValue,observeAs,Term.interpret]
  cases ieeeClass 23 8 bits.toNat .positiveInfinity <;>
    cases ieeeClass 23 8 bits.toNat .negativeInfinity <;> rfl

/-- 文字集合の両端のリテラルと、任意の文字列で同じ判定を行う。 -/
theorem characters_eval (s : String) (lo hi : Char) :
    (Pred.charactersIn (.string s) lo hi).evalClosed =
      some (API.characters.run [.const (.string s),.const (.character lo),.const (.character hi)]) := by
  simp [API.run,Pred.evalClosed,Pred.WF,Pred.VarsIn,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,
    Term.VarsIn,Pred.evalWith,Pred.atomReady,termReady,Term.observe,Observation.sort,Pred.atomValue,
    observeAs,Term.interpret]

/-- 公開名から得る篩も、Float の通常の呼出しと同じ結果を返す。 -/
example (t : FloatTest) (bits : UInt64) :
    (PublicNames.floatPredicate .binary64 t.name (.float64 bits)).bind Pred.evalClosed =
      some ((API.floating .binary64 t).run [.const (.float64 bits)]) := by
  rw [float_mapping]
  exact float64_eval t bits

/-- Float32 の公開名についても、篩の内外の結果は一致する。 -/
example (t : FloatTest) (bits : UInt32) :
    (PublicNames.floatPredicate .binary32 t.name (.float32 bits)).bind Pred.evalClosed =
      some ((API.floating .binary32 t).run [.const (.float32 bits)]) := by
  rw [float_mapping]
  exact float32_eval t bits

/-- 両端がリテラルの文字集合の公開名は、同じ篩を評価する。 -/
example (s : String) (lo hi : Char) :
    (PublicNames.charactersInPredicate (.string s) (some lo) (some hi)).bind Pred.evalClosed =
      some (API.characters.run [.const (.string s),.const (.character lo),.const (.character hi)]) :=
  characters_eval s lo hi

end
end Benitoite.Release.Refinement.PredicateResponse
