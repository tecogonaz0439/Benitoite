import Benitoite
open Benitoite.Release.Refinement
example : (Eff.normWith [] (.mk (fun _ => false) [])).fails = [] := by decide
example : (Ty.normWith [] .bytes) = .bytes := rfl
example : NamesWF ["x"] [.bytes] := by decide
