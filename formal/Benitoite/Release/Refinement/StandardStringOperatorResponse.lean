import Benitoite.Release.Refinement.StandardOperatorArguments

/-! # Stringの連結と順序の演算子 -/
namespace Benitoite.Release.Refinement.StandardStringOperatorResponse
noncomputable section

inductive API where
  | add | less | lessOrEqual | greater | greaterOrEqual
  deriving DecidableEq
def API.suffix : API → String
  | .add => ".add" | .less => ".less" | .lessOrEqual => ".lessOrEqual"
  | .greater => ".greater" | .greaterOrEqual => ".greaterOrEqual"
def name (api : API) : String := "%String" ++ api.suffix
def result (api : API) : BaseTy := if api=.add then .string else .boolean
def signature (api : API) : PrimSig := StandardOperatorArguments.signature .string (result api) false

/-- crates/benitoite/src/builtins/funcs/operators.rs のstring_add/less/less_or_equal/
    greater/greater_or_equalとruntime/heap/ctx.rsのalloc_str_parts/checked_parts_len。
    UTF-8のバイト列を辞書順で比べ、連結の前に合計バイト長の上限1 GiBを検査する。 -/
def reply (api : API) (a b : String) : Outcome :=
  let order := compare a.toUTF8.data.toList b.toUTF8.data.toList
  match api with
  | .add => if a.toUTF8.size+b.toUTF8.size ≤ 1073741824 then
      .val (.const (.string (a++b))) else .err "ValueTooLarge"
  | .less => .val (.const (.boolean (order=.lt)))
  | .lessOrEqual => .val (.const (.boolean (order≠.gt)))
  | .greater => .val (.const (.boolean (order=.gt)))
  | .greaterOrEqual => .val (.const (.boolean (order≠.lt)))

def delta (api : API) (b : PrimName) (ts : List Ty) (es : List Eff)
    (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  if b=name api ∧ ts=[] ∧ es=[] ∧ rs=[] then
    match ws with
    | [.const (.string a),.const (.string b)] => some (reply api a b)
    | _ => none
  else none

private theorem shape {P B Ψ v} (h : HasTypeVQ P B Ψ Qempty [] [] [] v (.base .string)) :
    ∃ s, v=.const (.string s) := by
  obtain ⟨c,rfl,_,tag⟩ := h.canonical_scalar rfl
  cases c <;> cases tag
  exact ⟨_,rfl⟩

private theorem safe {P B Ψ} (api : API) (a b : String) (ws : List Val) :
    Outcome.Typed P B Ψ (reply api a b) (.base (result api)) ∧
      AdequateResult ws (reply api a b) ∧ (∀ i, reply api a b≠.exit i) := by
  cases api <;> dsimp [reply,result]
  case add =>
    split
    · exact ⟨⟨.V_Const trivial,trivial⟩,by intro σ _ _; trivial,by intro i; simp⟩
    · exact ⟨trivial,by intro σ _ _; trivial,by intro i; simp⟩
  all_goals exact ⟨⟨.V_Const trivial,trivial⟩,by intro σ _ _; trivial,by intro i; simp⟩

theorem response {P B Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs P B Ψ (name api) (signature api) ts es rs ws a e) :
    ∃ out, delta api (name api) ts es rs ws=some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ :=
    StandardOperatorArguments.arguments .string (result api) false args
  cases values with | cons left rest => cases rest with | cons right rest =>
    cases rest
    obtain ⟨a,rfl⟩ := shape left
    obtain ⟨b,rfl⟩ := shape right
    exact ⟨reply api a b,by simp [delta],safe api a b _⟩

end
end Benitoite.Release.Refinement.StandardStringOperatorResponse
