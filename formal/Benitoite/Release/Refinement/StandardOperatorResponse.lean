import Benitoite.Release.Refinement.StandardFloatOperatorResponse
import Benitoite.Release.Refinement.StandardDecimalOperatorResponse
import Benitoite.Release.Refinement.StandardStringOperatorResponse
import Benitoite.Release.Refinement.StandardIntegerOperatorResponse

/-! # 算術・文字列の演算子の全実名と応答契約 -/
namespace Benitoite.Release.Refinement.StandardOperatorResponse
noncomputable section
open Benitoite.Interval

inductive Entry where
  | integer (kind : IntKind) (modulo : Bool)
  | floating (single : Bool) (api : StandardFloatOperatorResponse.API)
  | decimal (api : StandardDecimalOperatorResponse.API)
  | string (api : StandardStringOperatorResponse.API)

def Entry.name : Entry → String
  | .integer k m => StandardIntegerOperatorResponse.name k m
  | .floating s a => StandardFloatOperatorResponse.name s a
  | .decimal a => StandardDecimalOperatorResponse.name a
  | .string a => StandardStringOperatorResponse.name a
def Entry.signature : Entry → PrimSig
  | .integer k _ => StandardIntegerOperatorResponse.signature k
  | .floating s a => StandardFloatOperatorResponse.signature s a
  | .decimal a => StandardDecimalOperatorResponse.signature a
  | .string a => StandardStringOperatorResponse.signature a
def Entry.delta : Entry → PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome
  | .integer k m => StandardIntegerOperatorResponse.delta k m
  | .floating s a => StandardFloatOperatorResponse.delta s a
  | .decimal a => StandardDecimalOperatorResponse.delta a
  | .string a => StandardStringOperatorResponse.delta a

/-- 七整数型×div/mod、二Float幅×五算術、Decimal五算術、String五演算。 -/
def entries : List Entry :=
  ([.integer8,.integer16,.integer32,.integer64,.unsignedInteger16,.unsignedInteger32,.unsignedInteger64].flatMap
    (fun k => [Entry.integer k false,.integer k true])) ++
  ([false,true].flatMap (fun s => [.floating s .add,.floating s .subtract,.floating s .multiply,
    .floating s .divide,.floating s .negate])) ++
  [.decimal .add,.decimal .subtract,.decimal .multiply,.decimal .divide,.decimal .negate,
    .string .add,.string .less,.string .lessOrEqual,.string .greater,.string .greaterOrEqual]

def dispatch (name : String) : Option Entry := entries.find? (fun row => row.name=name)

theorem entries_count : entries.length=34 := rfl
theorem entries_unique : (entries.map Entry.name).Pairwise (·≠·) := by decide

theorem dispatch_name (entry : Entry) : dispatch entry.name=some entry := by
  cases entry with
  | integer k m => cases k <;> cases m <;> rfl
  | floating s a => cases s <;> cases a <;> rfl
  | decimal a => cases a <;> rfl
  | string a => cases a <;> rfl

def lookup (b : PrimName) : Option PrimSig := (dispatch b).map Entry.signature
def table (base : Builtins) : Builtins :=
  {base with sig := lookup,delta := fun b ts es rs ws =>
    (dispatch b).bind (fun row => row.delta b ts es rs ws)}

/-- 原署名の全BuiltinArgsから、同じ表の名前付きδの応答を得る。 -/
theorem response {P B Ψ ts es rs ws a e} (entry : Entry)
    (args : BuiltinArgs P B Ψ entry.name entry.signature ts es rs ws a e) :
    ∃ out, entry.delta entry.name ts es rs ws=some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
  cases entry with
  | integer k m => exact StandardIntegerOperatorResponse.response k m args
  | floating s api => exact StandardFloatOperatorResponse.response s api args
  | decimal api => exact StandardDecimalOperatorResponse.response api args
  | string api => exact StandardStringOperatorResponse.response api args

theorem table_response {P base Ψ ts es rs ws a e} (entry : Entry)
    (args : BuiltinArgs P (table base) Ψ entry.name entry.signature ts es rs ws a e) :
    (table base).sig entry.name=some entry.signature ∧
    ∃ out, (table base).delta entry.name ts es rs ws=some out ∧
      Outcome.Typed P (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
  refine ⟨by simp only [table,lookup,dispatch_name,Option.map_some],?_⟩
  obtain ⟨out,hd,ht,ha,hn⟩ := response entry args
  exact ⟨out,by simpa only [table,dispatch_name,Option.bind_some] using hd,ht,ha,hn⟩

end
end Benitoite.Release.Refinement.StandardOperatorResponse
