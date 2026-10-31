import Benitoite.Release.Refinement.TypeRenaming
import Benitoite.Release.Refinement.Subst

namespace Benitoite.Release.Refinement

def Ctx.shiftEAt (Γ : Ctx) (k c : Nat) : Ctx := Γ.map (Option.map (Refinement.shiftTypes k c))
def Ctx.shiftE (Γ : Ctx) (k : Nat) : Ctx := Γ.shiftEAt k 0

def Ctx.extendMany : Ctx → List Ty → Ctx
  | Γ, [] => Γ
  | Γ, a::as => (Γ.extend a).extendMany as

noncomputable def binderImages (ν : Nat → Val) : List Ty → List Ty
  | [] => []
  | a::as => substTyValues ν a :: binderImages (upSubst 1 ν) as

def BinderTypes.WF (nt : Nat) : Ctx → List Ty → Prop
  | _, [] => True
  | Γ, a::as => a.WF 0 nt Γ.length ∧ BinderTypes.WF nt (Γ.extend a) as

def BinderTypes.Sorted : Ctx → List Ty → Prop
  | _, [] => True
  | Γ, a::as => a.Sorted Γ ∧ BinderTypes.Sorted (Γ.extend a) as

@[simp] theorem binderImages_length (ν : Nat → Val) (ps : List Ty) :
    (binderImages ν ps).length = ps.length := by
  induction ps generalizing ν <;> simp_all [binderImages]

@[simp] theorem Ctx.extendMany_length (Γ : Ctx) (ps : List Ty) :
    (Γ.extendMany ps).length = Γ.length + ps.length := by
  induction ps generalizing Γ <;> simp_all [Ctx.extendMany, Ctx.extend] <;> omega



@[simp] theorem Val.shiftEListAt_length (vs : List Val) (k c : Nat) :
    (Val.shiftEListAt k c vs).length=vs.length := by
  induction vs <;> simp_all [Val.shiftEListAt]

def Val.shiftE (k : Nat) (v : Val) : Val := v.shiftEAt k 0

end Benitoite.Release.Refinement
