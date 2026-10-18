import Benitoite.Surface.FiniteTools
open Benitoite.Release Benitoite.Surface.CheckTools.Finite
private def inner : Ty := .fn [] [] (.base .unit) (Eff.single "outside")
private def leftTy : Ty := .fn [] [] (.base .unit) Eff.empty
private def rightTy : Ty := .fn [] [] (.base .unit) (.mk (fun _ => false) [inner])
private def joined : Ty := .fn [] [] (.base .unit) (.mk (fun _ => false) [inner])
example : tyJoin [] leftTy rightTy = some joined := rfl
example : ¬ Ty.Support (· ∈ ([] : List Atom)) joined := by
  intro h
  have hi := h.2.2.2.1.2.2.1 (.name "outside") (by rfl)
  cases hi
