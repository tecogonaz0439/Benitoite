import Benitoite.Release.Refinement.Typing
import Benitoite.Release.BuilderExec

namespace Benitoite.Release.Refinement

inductive BuilderContents where
  | string (value : String)
  | list (values : List Val)
  | bytes (values : List Nat)

def BuilderKind.empty : BuilderKind → BuilderContents
  | .string => .string ""
  | .list _ => .list []
  | .bytes => .bytes []

def BuilderContents.size : BuilderContents → Nat
  | .string s => s.utf8ByteSize
  | .list vs => vs.length
  | .bytes bs => bs.length

def BuilderContents.limit : BuilderContents → Nat
  | .list _ => maxBuilderListLen
  | _ => maxBuilderBytes

def BuilderContents.snapshot : BuilderContents → Val
  | .string s => .const (.string s)
  | .list vs => .list vs
  | .bytes bs => .bytesV bs

def BuilderContents.lengthValue (c : BuilderContents) (h : c.size ≤ c.limit) : Integer64Value :=
  ⟨(c.size : Int), by
    have hn : (c.size : Int) ≤ (c.limit : Int) := Int.ofNat_le.mpr h
    have hu : (c.limit : Int) ≤ max64 := by
      cases c with
      | list _ => exact maxBuilderListLen_le_max64
      | string _ | bytes _ => exact maxBuilderBytes_le_max64
    constructor
    · have : (0 : Int) ≤ (c.size : Int) := Int.natCast_nonneg _
      simp only [min64]; omega
    · omega⟩

inductive BuilderReply where
  | value (contents : BuilderContents) (result : Val)
  | error (reason : ErrKind)

def builderJoin : List Val → Option String
  | [] => some ""
  | .const (.string s) :: vs => (builderJoin vs).map (s ++ ·)
  | _ => none

def builderCheckUpdate (c : BuilderContents) : BuilderReply :=
  if c.size ≤ c.limit then
    match c with
    | .bytes bs => if bs.all (· < 256) then .value c (.const .unit) else .error rBuilderInvalidByte
    | _ => .value c (.const .unit)
  else .error rValueTooLarge

def builderApply (op : BuilderOp) (c : BuilderContents) (args : List Val) : Option BuilderReply :=
  match op, c, args with
  | .copy, c, [] => some (.value c c.snapshot)
  | .length, c, [] => if h : c.size ≤ c.limit then some (.value c (.const (.integer (c.lengthValue h)))) else none
  | .append, .string s, [.const (.string t)] => some (builderCheckUpdate (.string (s ++ t)))
  | .appendAll, .string s, [.list vs] => (builderJoin vs).map fun t => builderCheckUpdate (.string (s ++ t))
  | .append, .list vs, [v] => some (builderCheckUpdate (.list (vs ++ [v])))
  | .appendAll, .list vs, [.list ws] => some (builderCheckUpdate (.list (vs ++ ws)))
  | .append, .bytes bs, [.const (.byte b)] => some (builderCheckUpdate (.bytes (bs ++ [b])))
  | .appendAll, .bytes bs, [.bytesV cs] => some (builderCheckUpdate (.bytes (bs ++ cs)))
  | _, _, _ => none

end Benitoite.Release.Refinement
