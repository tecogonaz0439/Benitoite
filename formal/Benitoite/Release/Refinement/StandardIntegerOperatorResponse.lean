import Benitoite.Release.Refinement.StandardOperatorArguments

/-! # 七幅の整数のdiv/modの原署名と具体応答 -/
namespace Benitoite.Release.Refinement.StandardIntegerOperatorResponse
open Benitoite.Interval StandardScalar

def base : IntKind → BaseTy
  | .integer64 => .integer | .integer8 => .integer8 | .integer16 => .integer16
  | .integer32 => .integer32 | .unsignedInteger16 => .unsignedInteger16
  | .unsignedInteger32 => .unsignedInteger32 | .unsignedInteger64 => .unsignedInteger64
def name (kind : IntKind) (modulo : Bool) : String :=
  "%" ++ integerModule kind ++ if modulo then ".mod" else ".div"
def signature (kind : IntKind) : PrimSig := StandardOperatorArguments.signature (base kind) (base kind) false

/-- crates/benitoite/src/builtins/funcs/operators.rs のint_divide/int_modulo、
    operators/signed.rs・unsigned.rsの幅付きの対応。StandardIntegerFailureと同じ本体を使う。 -/
def delta (kind : IntKind) (modulo : Bool) (b : PrimName) (ts : List Ty) (es : List Eff)
    (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  if b=name kind modulo ∧ ts=[] ∧ es=[] ∧ rs=[] then
    match ws with
    | [left,right] => do
      let a ← integerRead kind left
      let c ← integerRead kind right
      return integerBinaryDelta kind (if modulo then .mod else .intDiv) a c
    | _ => none
  else none

private theorem shape {P B Ψ v} (kind : IntKind)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (.base (base kind))) :
    ∃ n : IntegerValue kind, v=.const (embedConst (IntegerValue.toConst kind n)) := by
  cases kind <;> obtain ⟨c,rfl,hc,ht⟩ := typed.canonical_scalar rfl
  all_goals cases c <;> cases ht
  all_goals first | exact ⟨_,rfl⟩ | exact ⟨⟨_,hc⟩,rfl⟩

private theorem read_self (kind : IntKind) (n : IntegerValue kind) :
    integerRead kind (.const (embedConst (IntegerValue.toConst kind n)))=some n := by
  exact integerRead_const kind n

private theorem normal_safe {P B Ψ} (kind : IntKind) (n : IntegerValue kind) (ws : List Val) :
    Outcome.Typed P B Ψ (.val (.const (embedConst (IntegerValue.toConst kind n)))) (.base (base kind)) ∧
      AdequateResult ws (.val (.const (embedConst (IntegerValue.toConst kind n)))) := by
  have bounds := n.toInt_bounds
  cases kind <;> refine ⟨⟨.V_Const ?_,trivial⟩,by intro σ _ _; trivial⟩
  all_goals first | trivial | exact bounds

/-- 正常値とStopの分離は群共通のStandardIntegerFailureの言明をそのまま使う。 -/
private theorem safe {P B Ψ} (kind : IntKind) (modulo : Bool) (a b : IntegerValue kind) (ws : List Val) :
    Outcome.Typed P B Ψ (integerBinaryDelta kind (if modulo then .mod else .intDiv) a b) (.base (base kind)) ∧
      AdequateResult ws (integerBinaryDelta kind (if modulo then .mod else .intDiv) a b) ∧
      (∀ i, integerBinaryDelta kind (if modulo then .mod else .intDiv) a b≠.exit i) := by
  have split := divMod_delta_split kind a b modulo
  cases modulo <;> simp only [Bool.false_eq_true,ite_false,ite_true] at split ⊢
  · rcases split with h | ⟨h,_⟩ | ⟨v,_,h,_⟩
    · rw [h]; exact ⟨trivial,by intro σ _ _; trivial,by intro i; simp⟩
    · rw [h]; exact ⟨trivial,by intro σ _ _; trivial,by intro i; simp⟩
    · rw [h]
      exact ⟨(normal_safe (P := P) (B := B) (Ψ := Ψ) kind v ws).1,
        (normal_safe (P := P) (B := B) (Ψ := Ψ) kind v ws).2,by intro i; simp⟩
  · rcases split with h | ⟨v,_,h,_⟩
    · rw [h]; exact ⟨trivial,by intro σ _ _; trivial,by intro i; simp⟩
    · rw [h]
      exact ⟨(normal_safe (P := P) (B := B) (Ψ := Ψ) kind v ws).1,
        (normal_safe (P := P) (B := B) (Ψ := Ψ) kind v ws).2,by intro i; simp⟩

theorem response {P B Ψ ts es rs ws a e} (kind : IntKind) (modulo : Bool)
    (args : BuiltinArgs P B Ψ (name kind modulo) (signature kind) ts es rs ws a e) :
    ∃ out, delta kind modulo (name kind modulo) ts es rs ws=some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ :=
    StandardOperatorArguments.arguments (base kind) (base kind) false args
  cases values with | cons left rest => cases rest with | cons right rest =>
    cases rest
    obtain ⟨a,rfl⟩ := shape kind left
    obtain ⟨b,rfl⟩ := shape kind right
    exact ⟨integerBinaryDelta kind (if modulo then .mod else .intDiv) a b,
      by simp [delta,read_self],safe kind modulo a b _⟩

end Benitoite.Release.Refinement.StandardIntegerOperatorResponse
