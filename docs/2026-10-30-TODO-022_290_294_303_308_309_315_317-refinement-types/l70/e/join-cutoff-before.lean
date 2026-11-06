import Benitoite.Release.Refinement.Surface.CheckEntrypointsSound

namespace Benitoite.Release.Refinement.Surface.JoinStoppedTrial
open Check CheckSubtyping

def declarations : Declarations where
  funs := fun _ => none
  cons := fun _ => none

def builtins : Builtins where
  sig := fun _ => none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => False
  refGet := "get"
  refSet := "set"

def p : Pred := .eq (.integer 1) (.integer 1)
def closedOne : ExchangeCertificate :=
  {certificate := .leaf ⟨p, .closed, [], []⟩
   actions := [.work .checkCertificate .node, .work .checkCertificate .node]}
def atom : Atom := .name "State" (.fixed .top)
def effect : Eff := .mk (fun a => decide (a = atom)) []
def a : Ty := .fn ["x"] [.refined (.base .integer) p] (.base .unit) Eff.empty
def b : Ty := .fn ["x"] [.base .integer] (.base .unit) effect

def input (limit : Nat) : Check.Input where
  D := declarations
  B := builtins
  opPrim := fun _ _ => none
  formation := {atoms := [atom], ctors := fun _ => []}
  proofSteps := limit
  logicCertificates := fun _ _ => some closedOne

def context : Ctx := [some a, some b]
def source : Expr := .ite (.literal (.boolean true)) (.last (.local 0)) (.last (.local 1))
def le (limit : Nat) (src dst : Ty) : Bool :=
  LeCertificate.checkAs [atom] declarations.core context [] limit src dst
    (CheckInfer.inferLe (input limit) ⟨(input limit).logicCertificates⟩ context [] [] 0 src dst)

-- 最初の候補は十分な予算なら成功し、少ない予算では失敗する。逆の候補は効果で失敗する。
example : le 10 a b = true ∧ le 1 a b = false ∧ le 10 b a = false := by
  with_unfolding_all exact ⟨rfl, rfl, rfl⟩

-- 最初の候補の論理の検査は、実際の予算切れである。
example : CheckDiagnostics.guideDecision 1
    (.node .E_Sub {subtypes := [CheckInfer.inferLe (input 1) ⟨(input 1).logicCertificates⟩
      context [] [] 0 a b]} []) = .unknown (some .stepsExhausted) := by
  with_unfolding_all rfl

-- 同じソースの実入口は、十分な予算では成功する。
example : (Check.checkExpr (input 10) [] context [] none .other [] source).toBool = true := by
  with_unfolding_all rfl

-- 少ない予算では、最初の候補での打ち切りが入口の拒否へ変わる。
example : (match Check.checkExpr (input 1) [] context [] none .other [] source with
    | .error err => err.kind = .rejected
    | _ => False) := by
  with_unfolding_all rfl

end Benitoite.Release.Refinement.Surface.JoinStoppedTrial
