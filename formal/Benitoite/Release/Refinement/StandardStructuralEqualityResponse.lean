import Benitoite.Release.Refinement.StandardEqualityResponse
import Benitoite.Release.Refinement.StandardListRemainingResponse

/-! # Full Equalityの構造走査と実名の応答契約 -/
namespace Benitoite.Release.Refinement.StandardStructuralEqualityResponse
noncomputable section
open StandardListRemainingResponse (structuralEqual)

/-- crates/benitoite/src/runtime/equal.rsのvalues_equalと
    builtins/funcs/operators.rsのeq/ne。List・data・Bytes・Map・Setも既存の構造走査で比べる。
    不適格な構造の失敗はInternalComparisonのStopにし、正常な比較だけをBooleanとして返す。 -/
def reply (equal : Bool) (left right : Val) : Outcome :=
  match structuralEqual left right with
  | some result => .val (.const (.boolean (if equal then result else !result)))
  | none => .err "InternalComparison"

def delta (b : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  if (b="%eq" ∨ b="%ne") ∧ es=[] ∧ rs=[] then
    match ts,ws with
    | [_],[left,right] => some (reply (b="%eq") left right)
    | _,_ => none
  else none

/-- 正常な構造比較は必ずBooleanを返す。失敗を真偽の既定値へ読み替えない。 -/
theorem reply_normal (equal : Bool) (left right value : Val)
    (normal : reply equal left right=.val value) :
    ∃ b : Bool, value=.const (.boolean b) := by
  unfold reply at normal
  split at normal
  · cases Outcome.val.inj normal
    exact ⟨_,rfl⟩
  · cases normal

private theorem safe {P B Ψ} (equal : Bool) (left right : Val) (ws : List Val) :
    Outcome.Typed P B Ψ (reply equal left right) (.base .boolean) ∧
      AdequateResult ws (reply equal left right) ∧ (∀ i, reply equal left right≠.exit i) := by
  unfold reply
  split
  · exact ⟨⟨.V_Const trivial,trivial⟩,by intro σ _ _; trivial,by intro i; simp⟩
  · exact ⟨trivial,by intro σ _ _; trivial,by intro i; simp⟩

/-- scalar-domainの前提を付けず、元のT・Equality sat・注釈を保持して同じ構造δを読む。 -/
theorem response {P B Ψ ts es rs ws a e} (equal : Bool)
    (args : BuiltinArgs P B Ψ (if equal then "%eq" else "%ne")
      (StandardEqualityResponse.fullSignature B.sat) ts es rs ws a e) :
    ∃ T, ts=[T] ∧ Ty.Annotation P [] [] T ∧ Ordinary T ∧ B.sat [] T.norm {equality := true} ∧
      ∃ out, delta (if equal then "%eq" else "%ne") ts es rs ws=some out ∧
        Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
  obtain ⟨T,rfl,rfl,rfl,ann,_,ordinary,sat,values,rfl,rfl⟩ := StandardEqualityResponse.full_arguments equal args
  cases values with | cons left rest => cases rest with | cons right rest =>
    cases rest
    rename_i l r
    exact ⟨T,rfl,ann,ordinary,sat,reply equal l r,by cases equal <;> simp [delta],safe equal l r _⟩

def table (base : Builtins) : Builtins :=
  {base with sig := fun b => if b="%eq" ∨ b="%ne" then some (StandardEqualityResponse.fullSignature base.sat) else none,delta := delta}

theorem table_response {P base Ψ ts es rs ws a e} (equal : Bool)
    (args : BuiltinArgs P (table base) Ψ (if equal then "%eq" else "%ne")
      (StandardEqualityResponse.fullSignature (table base).sat) ts es rs ws a e) :
    (table base).sig (if equal then "%eq" else "%ne")=some (StandardEqualityResponse.fullSignature (table base).sat) ∧
    ∃ T, ts=[T] ∧ Ty.Annotation P [] [] T ∧ Ordinary T ∧ (table base).sat [] T.norm {equality := true} ∧
      ∃ out, (table base).delta (if equal then "%eq" else "%ne") ts es rs ws=some out ∧
        Outcome.Typed P (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) :=
  ⟨by cases equal <;> rfl,response equal args⟩

end
end Benitoite.Release.Refinement.StandardStructuralEqualityResponse
