import Benitoite.Release.Refinement.Surface.CheckGuide

/-! 検査器が読む宣言・組み込みの表と、論理の証明書。 -/
namespace Benitoite.Release.Refinement.Surface.Check

structure Input where
  D : Declarations
  B : Builtins
  opPrim : OpPrim
  formation : CheckFormation.Input
  satDec : CheckArguments.SatDec := fun _ _ _ => false
  admitsDec : CheckArguments.AdmitsDec := fun _ _ _ => false
  admitsRDec : CheckArguments.RangeAdmitsDec := fun _ _ => false
  proofSteps : Nat
  /-- 各論理の検査位置の証明書。規則の案内と中間の型・効果は含めない。 -/
  logicCertificates : List Nat → Nat → Option CheckSubtyping.ExchangeCertificate := fun _ _ => none
  defs : List FunName := []
  impls : List ImplName := []
  effects : List EffName := []
  ops : List OpName := []
  methods : List MethName := []
  supers : List ClassName := []
  dataNames : List DataName := []
  ctorNames : List ConName := []
  methodParamNames : ImplName → MethName → List String := fun _ _ => []
  functionSteps : FunName → Nat := fun _ => proofSteps
  methodSteps : ImplName → MethName → Nat := fun _ _ => proofSteps

/-- 材料の有限支持と既存の型クラス・組み込みの許容判定との対応。型付けや証明書の健全性は仮定しない。 -/
structure Input.Sound (q : Input) : Prop where
  formation : q.formation.Sound q.D.core
  tables : CheckArguments.HeadTableSupport q.formation.atoms q.D q.B
  sat : CheckArguments.SatSound q.B q.satDec
  admits : CheckArguments.AdmitsSound q.B q.admitsDec
  ranges : CheckArguments.RangeAdmitsSound q.B q.admitsRDec
  operators : ∀ o t b ts, q.opPrim o t = some (b, ts) →
    t.Support (· ∈ q.formation.atoms) → Ty.SupportList (· ∈ q.formation.atoms) ts

abbrev ExprSupport (q : Input) := CheckSource.ExprSupport q.formation q.B
abbrev BlockSupport (q : Input) := CheckSource.BlockSupport q.formation q.B
abbrev ExprsSupport (q : Input) := CheckSource.ExprsSupport q.formation q.B
abbrev HolesSupport (q : Input) := CheckSource.HolesSupport q.formation q.B
abbrev ArmsSupport (q : Input) := CheckSource.ArmsSupport q.formation q.B
abbrev ClausesSupport (q : Input) := CheckSource.ClausesSupport q.formation q.B

def ReturnSupport (s : List Atom) : Option Ty → Prop
  | none => True
  | some a => a.Support (· ∈ s)

inductive ErrorKind where
  | rejected
  | unknown
  deriving Repr, DecidableEq

structure Error where
  path : List Nat
  reason : String
  kind : ErrorKind := .rejected
  deriving Repr, DecidableEq

abbrev Result (α : Type) := Except Error α
abbrev Inferred := Ty × Eff

def child (path : List Nat) (i : Nat) : List Nat := path ++ [i]

def require (path : List Nat) (reason : String) (ok : Bool) : Result Unit :=
  if ok then .ok () else .error ⟨path, reason, .rejected⟩

def allChecks : List Bool → Bool
  | [] => true
  | b :: bs => b && allChecks bs

end Benitoite.Release.Refinement.Surface.Check
