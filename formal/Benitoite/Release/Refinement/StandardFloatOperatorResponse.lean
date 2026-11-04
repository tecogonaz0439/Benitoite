import Benitoite.Release.Refinement.StandardOperatorArguments

/-! # Float二幅の算術演算子の具体応答 -/
namespace Benitoite.Release.Refinement.StandardFloatOperatorResponse
noncomputable section
open StandardFloatMathResponse (constant)

inductive API where
  | add | subtract | multiply | divide | negate
  deriving DecidableEq

def API.suffix : API → String
  | .add => ".add" | .subtract => ".subtract" | .multiply => ".multiply"
  | .divide => ".divide" | .negate => ".negate"
def name (single : Bool) (api : API) : String :=
  "%" ++ (if single then "Float32" else "Float") ++ api.suffix
def base (single : Bool) : BaseTy := if single then .float32 else .float
def signature (single : Bool) (api : API) : PrimSig :=
  StandardOperatorArguments.signature (base single) (base single) (api=.negate)

/-- crates/benitoite/src/builtins/funcs/operators.rs のfloat_add/subtract/multiply/divide/negate、
    operators/float32.rs の同じ五関数の算術。NaNのpayload/quiet化はsquareRootと同じ模型に従う。
    nativeのFloat演算を使わず、Modelの演算後のビット列を保存する。 -/
def bits (single : Bool) (api : API) (left right : Nat) : Nat :=
  if single then
    let a := Float32.Model.ofBits (UInt32.ofNat left)
    let b := Float32.Model.ofBits (UInt32.ofNat right)
    (match api with
      | .add => Float32.Model.add a b | .subtract => Float32.Model.sub a b
      | .multiply => Float32.Model.mul a b | .divide => Float32.Model.div a b
      | .negate => Float32.Model.neg a).toBits.toNat
  else
    let a := Float.Model.ofBits (UInt64.ofNat left)
    let b := Float.Model.ofBits (UInt64.ofNat right)
    (match api with
      | .add => Float.Model.add a b | .subtract => Float.Model.sub a b
      | .multiply => Float.Model.mul a b | .divide => Float.Model.div a b
      | .negate => Float.Model.neg a).toBits.toNat

private def read (single : Bool) : Val → Option Nat
  | .const (.float32 n) => if single then some n.toNat else none
  | .const (.float64 n) => if single then none else some n.toNat
  | _ => none

def delta (single : Bool) (api : API) (b : PrimName) (ts : List Ty) (es : List Eff)
    (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  if b=name single api ∧ ts=[] ∧ es=[] ∧ rs=[] then
    if api=.negate then
      match ws with
      | [v] => (read single v).map (fun n => .val (constant single (bits single api n 0)))
      | _ => none
    else
      match ws with
      | [v,w] => do
        let a ← read single v
        let c ← read single w
        return .val (constant single (bits single api a c))
      | _ => none
  else none

private theorem shape {P B Ψ v} (single : Bool)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (.base (base single))) :
    ∃ n, v=constant single n ∧ read single (constant single n)=some n := by
  cases single <;> obtain ⟨c,rfl,hc,tag⟩ := typed.canonical_scalar rfl
  all_goals cases c <;> cases tag
  all_goals rename_i n
  all_goals exact ⟨n.toNat,by simp [constant],by simp [constant,read]⟩

private theorem safe {P B Ψ} (single : Bool) (n : Nat) (ws : List Val) :
    Outcome.Typed P B Ψ (.val (constant single n)) (.base (base single)) ∧
      AdequateResult ws (.val (constant single n)) := by
  cases single <;> exact ⟨⟨.V_Const trivial,trivial⟩,by intro σ _ _; trivial⟩

/-- 十実名の原署名の全入力から、同じModel演算のδの型・Ground・保持値・非exitを得る。 -/
theorem response {P B Ψ ts es rs ws a e} (single : Bool) (api : API)
    (args : BuiltinArgs P B Ψ (name single api) (signature single api) ts es rs ws a e) :
    ∃ out, delta single api (name single api) ts es rs ws=some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ :=
    StandardOperatorArguments.arguments (base single) (base single) (api=.negate) args
  by_cases unary : api=.negate
  · simp only [unary] at values
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨n,rfl,hr⟩ := shape single typed
      exact ⟨.val (constant single (bits single api n 0)),by simp [delta,unary,hr],(safe (P := P) (B := B) (Ψ := Ψ) single _ [constant single n]).1,(safe (P := P) (B := B) (Ψ := Ψ) single _ _).2,by intro i; simp⟩
  · simp only [unary] at values
    cases values with | cons left rest => cases rest with | cons right rest =>
      cases rest
      obtain ⟨n,rfl,hn⟩ := shape single left
      obtain ⟨m,rfl,hm⟩ := shape single right
      exact ⟨.val (constant single (bits single api n m)),by simp [delta,unary,hn,hm],(safe (P := P) (B := B) (Ψ := Ψ) single _ [constant single n,constant single m]).1,(safe (P := P) (B := B) (Ψ := Ψ) single _ _).2,by intro i; simp⟩

end
end Benitoite.Release.Refinement.StandardFloatOperatorResponse
