import Benitoite
open Benitoite Benitoite.Release.Refinement
namespace RVT
inductive Variance where | covariant | contravariant | invariant | unused deriving DecidableEq
structure Info where
  arity : Nat
  variances : List Variance
  requirements : List Ty
-- Program の欄の代わりに表を引数で受ける
def vf (P : Program) (T : Benitoite.Release.DataName → Option Info) (d : Benitoite.Release.DataName) (n : Nat) : List Variance :=
  match T d with
  | some i => if i.arity = n ∧ i.variances.length = n then i.variances else List.replicate n .invariant
  | none => List.replicate n .invariant

mutual
inductive LeQ (P : Program) (T : Benitoite.Release.DataName → Option Info) : Ctx → List Pred → Ty → Ty → Prop where
  | refl {Γ Φ a} : LeQ P T Γ Φ a a
  | convert {Γ Φ a b} : a.norm = b.norm → LeQ P T Γ Φ a b
  | trans {Γ Φ a b c} : LeQ P T Γ Φ a b → LeQ P T Γ Φ b c → LeQ P T Γ Φ a c
  | data {Γ Φ d as bs} : TArgs P T Γ Φ (vf P T d as.length) as bs → LeQ P T Γ Φ (.data d as) (.data d bs)
  | dependentFn {Γ Φ t u} : TC P T Γ Φ t u → LeQ P T Γ Φ (.dependentFn t) (.dependentFn u)
inductive TL (P : Program) (T : Benitoite.Release.DataName → Option Info) : Ctx → List Pred → Tel → Tel → Prop where
  | done {Γ Φ r s e f} : LeQ P T Γ Φ r s → Eff.Covers Γ Φ f e → TL P T Γ Φ (.done r e) (.done s f)
  | param {Γ Φ n a b t u} : LeQ P T Γ Φ b a → TL P T (Γ.extend b) (Φ.map Pred.lift) t u →
      TL P T Γ Φ (.param n a t) (.param n b u)
inductive TC (P : Program) (T : Benitoite.Release.DataName → Option Info) : Ctx → List Pred → Tel → Tel → Prop where
  | refl {Γ Φ t} : TC P T Γ Φ t t
  | tail {Γ Φ t u v} : TC P T Γ Φ t u → TL P T Γ Φ u v → TC P T Γ Φ t v
inductive TArgs (P : Program) (T : Benitoite.Release.DataName → Option Info) : Ctx → List Pred → List Variance → List Ty → List Ty → Prop where
  | nil {Γ Φ} : TArgs P T Γ Φ [] [] []
  | co {Γ Φ vs a b as bs} : LeQ P T Γ Φ a b → TArgs P T Γ Φ vs as bs → TArgs P T Γ Φ (.covariant :: vs) (a::as) (b::bs)
  | contra {Γ Φ vs a b as bs} : LeQ P T Γ Φ b a → TArgs P T Γ Φ vs as bs → TArgs P T Γ Φ (.contravariant :: vs) (a::as) (b::bs)
  | inv {Γ Φ vs a b as bs} : a.norm = b.norm → TArgs P T Γ Φ vs as bs → TArgs P T Γ Φ (.invariant :: vs) (a::as) (b::bs)
  | unused {Γ Φ vs a b as bs} : TArgs P T Γ Φ vs as bs → TArgs P T Γ Φ (.unused :: vs) (a::as) (b::bs)
end

theorem TArgs.trans_ok {P : Program} {T : Benitoite.Release.DataName → Option Info} {Γ Φ vs as bs cs} (h : TArgs P T Γ Φ vs as bs) (g : TArgs P T Γ Φ vs bs cs) :
    TArgs P T Γ Φ vs as cs := by
  match h, g with
  | .nil, .nil => exact .nil
  | .co h r, .co g s => exact .co (.trans h g) (TArgs.trans_ok r s)
  | .contra h r, .contra g s => exact .contra (.trans g h) (TArgs.trans_ok r s)
  | .inv h r, .inv g s => exact .inv (h.trans g) (TArgs.trans_ok r s)
  | .unused r, .unused s => exact .unused (TArgs.trans_ok r s)

-- 欄の Annotation の型が通るか
example (P : Program) (n : Nat) (a : Ty) : Prop :=
  Ty.Annotation P (List.replicate n ({} : Benitoite.Release.TParam)) [] a ∧
  Ty.HasKind P (List.replicate n .value) a .value


def selfObs (v : Val) : Option Observation := v.toTerm?.bind (Term.observe (fun _ => none))
def ev (p : Pred) (v : Val) : Option Bool := p.evalWith (fun | 0 => selfObs v | _+1 => none)
def month : Pred := .and (.le (.integer 1) (.var 0)) (.le (.var 0) (.integer 12))
def nonEmpty : Pred := .lt (.integer 0) (.measure .listLength (.var 0))
def fnv : Val := .fnRef "f" [] []
abbrev i (n : Int) : Val := .const (.integer8 n)
#eval (ev month (i 13), ev month (i 5), ev month (i 0))
#eval (ev .falsity (i 1), ev .falsity fnv)
#eval (ev nonEmpty (.list []), ev nonEmpty (.list [fnv]), ev nonEmpty (.list [i 1]))
-- 外側の変数と観測不能
def outer : Pred := .le (.var 0) (.var 1)
#eval ev outer (i 1)
#eval ev (.and outer .falsity) (i 1)
#eval ev (.or outer .truth) (i 1)
#eval ev (.not outer) (i 1)
#eval ev month fnv
#eval ev (.not month) fnv
#eval ev nonEmpty (.con "C" [] [])
#eval ev (.le (.var 0) (.integer 0)) (.const (.byte 300))
end RVT
