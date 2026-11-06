import Benitoite.Surface.Check
import Benitoite.Release.Refinement.Surface.CheckEntrypoints

namespace NumericPreservationTrial

def oldBuiltins : Benitoite.Release.Builtins where
  sig := fun _ => none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => False
  refGet := "get"
  refSet := "set"

def oldInput : Benitoite.Surface.Check.Input where
  D := { funs := fun _ => none, cons := fun _ => none }
  B := oldBuiltins
  satDec := fun _ _ _ => false
  admitsDec := fun _ _ _ => false
  opPrim := fun _ _ => none
  ctors := fun _ => []
  atoms := []

theorem old_accepts_invalid : Benitoite.Surface.Check.checkExpr oldInput .strict [] [] none .other []
    (.literal (.integer8 128)) = .ok (.base .integer8, Benitoite.Release.Eff.empty) := rfl

open Benitoite.Release.Refinement Benitoite.Release.Refinement.Surface

def newBuiltins : Builtins where
  sig := fun _ => none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => False
  refGet := "get"
  refSet := "set"

def newInput : Check.Input where
  D := { funs := fun _ => none, cons := fun _ => none }
  B := newBuiltins
  opPrim := fun _ _ => none
  formation := { atoms := [], ctors := fun _ => [] }
  proofSteps := 1

theorem new_literal_rejects_invalid : Check.checkExprAt newInput [] [] [] [] [] none .other []
    (.literal (.integer8 128)) (.base .integer8) Eff.empty (.node .E_Literal {} []) = false := rfl

theorem new_literal_accepts_valid : Check.checkExprAt newInput [] [] [] [] [] none .other []
    (.literal (.integer8 127)) (.base .integer8) Eff.empty (.node .E_Literal {} []) = true := rfl

theorem new_entry_boundary :
    (Check.checkExpr newInput [] [] [] none .other [] (.literal (.integer8 127))).toBool = true ∧
    (Check.checkExpr newInput [] [] [] none .other [] (.literal (.integer8 128))).toBool = false := by
  cbv

end NumericPreservationTrial
