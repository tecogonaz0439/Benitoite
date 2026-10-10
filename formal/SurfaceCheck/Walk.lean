import Benitoite.Exchange.CheckInput

/-! 検査と同じ位置と経路で Q11 を適用し、分類に使う構文を保存する。 -/
namespace SurfaceCheck
open Benitoite.Release Benitoite.Surface Benitoite.Surface.Check Benitoite.Surface.CheckTools
structure Node where
  path : List Nat
  expr : Expr
  expected : Option Ty := none
structure WalkState where
  nodes : Array Node := #[]
  guards : Array (List Nat) := #[]
  changes : Array (List Nat) := #[]
  nonUnit : Nat := 0
  tailMatches : Nat := 0
  prims : List String := []
  partialReturns : Array (List Nat) := #[]
abbrev Walk := StateM WalkState
mutual
  def walkExpr (q : Input) (R : Option Ty) (p : Position) (path : List Nat)
      (inPartial : Bool) (expected : Option Ty) (e : Expr) : Walk Expr := do
    modify fun s => { s with nodes := s.nodes.push ⟨path,e,expected⟩ }
    match e with
    | .constE t a => return .constE t (← walkExpr q R .other (child path 0) inPartial (some t) a)
    | .primName n _ _ =>
      modify fun s => { s with prims := n :: s.prims }; return e
    | .paren a => return .paren (← walkExpr q R p (child path 0) inPartial expected a)
    | .conCall c ts args => return .conCall c ts (← walkExprs q R (child path 0) 0 inPartial args)
    | .record c ts pos args => return .record c ts pos (← walkExprs q R (child path 0) 0 inPartial args)
    | .recordUpdate c ts n pos base args =>
      return .recordUpdate c ts n pos (← walkExpr q R .other (child path 0) inPartial none base) (← walkExprs q R (child path 1) 0 inPartial args)
    | .call f args => return .call (← walkExpr q R .other (child path 0) inPartial none f) (← walkExprs q R (child path 1) 0 inPartial args)
    | .pipe a b => return .pipe (← walkExpr q R .other (child path 0) inPartial none a) (← walkExpr q R .other (child path 1) inPartial none b)
    | .partialCall f args r eff =>
      return .partialCall (← walkExpr q (some r) .other (child path 0) true none f) (← walkHoles q (some r) (child path 1) 0 args) r eff
    | .partialCon c ts args =>
      let r := (q.D.cons c).map fun d => Ty.data d.data ts
      return .partialCon c ts (← walkHoles q r (child path 0) 0 args)
    | .binary op t a b =>
      match q.opPrim (.binary op) t with
      | some (n,_) => modify fun s => { s with prims := n :: s.prims }
      | none => pure ()
      return .binary op t (← walkExpr q R .other (child path 0) inPartial (some t) a) (← walkExpr q R .other (child path 1) inPartial (some t) b)
    | .neg t a =>
      match q.opPrim .neg t with
      | some (n,_) => modify fun s => { s with prims := n :: s.prims }
      | none => pure ()
      return .neg t (← walkExpr q R .other (child path 0) inPartial (some t) a)
    | .not a => return .not (← walkExpr q R .other (child path 0) inPartial none a)
    | .and a b => return .and (← walkExpr q R .other (child path 0) inPartial none a) (← walkExpr q R p (child path 1) inPartial none b)
    | .or a b => return .or (← walkExpr q R .other (child path 0) inPartial none a) (← walkExpr q R p (child path 1) inPartial none b)
    | .list t args => return .list t (← walkExprs q R (child path 0) 0 inPartial args)
    | .listSpread t f before spread after =>
      return .listSpread t (← walkExpr q R .other (child path 0) inPartial none f) (← walkExprs q R (child path 1) 0 inPartial before) (← walkExpr q R .other (child path 2) inPartial none spread) (← walkExprs q R (child path 3) 0 inPartial after)
    | .interpolation parts es fs => return .interpolation parts (← walkExprs q R (child path 0) 0 inPartial es) (← walkExprs q R (child path 1) 0 inPartial fs)
    | .lam ps r eff body => return .lam ps r eff (← walkBlock q (some r) .tail (child path 0) false (some r) body)
    | .ite c y n => return .ite (← walkExpr q R .other (child path 0) inPartial none c) (← walkBlock q R p (child path 1) inPartial expected y) (← walkBlock q R p (child path 2) inPartial expected n)
    | .elseIf c y n => return .elseIf (← walkExpr q R .other (child path 0) inPartial none c) (← walkBlock q R p (child path 1) inPartial expected y) (← walkExpr q R p (child path 2) inPartial expected n)
    | .ifOnly c y => return .ifOnly (← walkExpr q R .other (child path 0) inPartial none c) (← walkBlock q R p (child path 1) inPartial (some (.base .unit)) y)
    | .matchE t a arms =>
      if p == .tail then modify fun s => { s with tailMatches := s.tailMatches + 1 }
      let mut t' := t
      if p == .tail && armsExits arms then
        if let some r := R then
          if !tyEq q.atoms t r then
            t' := r
            modify fun s => { s with changes := s.changes.push path, nonUnit := s.nonUnit + if tyEq q.atoms t (.base .unit) then 0 else 1 }
      return .matchE t' (← walkExpr q R .other (child path 0) inPartial none a) (← walkArms q R p (child path 1) inPartial t' arms)
    | .returnE t a =>
      if inPartial then modify fun s => { s with partialReturns := s.partialReturns.push path }
      return .returnE t (← walkExpr q R p (child path 0) inPartial R a)
    | .tryResult ts ok err a => return .tryResult ts ok err (← walkExpr q R .other (child path 0) inPartial none a)
    | .tryOption ts yes no a => return .tryOption ts yes no (← walkExpr q R .other (child path 0) inPartial none a)
    | .withE o a body => return .withE o (← walkExpr q R .other (child path 0) inPartial none a) (← walkBlock q R .other (child path 1) inPartial expected body)
    | .lazyE body => return .lazyE (← walkBlock q none .other (child path 0) false none body)
    | .handleE body cs => return .handleE (← walkBlock q R .other (child path 0) inPartial none body) (← walkClauses q R (child path 1) inPartial cs)
    | .resume k a => return .resume k (← walkExpr q R .other (child path 0) inPartial none a)
    | _ => return e
  def walkBlock (q : Input) (R : Option Ty) (p : Position) (path : List Nat)
      (inPartial : Bool) (expected : Option Ty) : Block → Walk Block
    | .empty => pure .empty
    | .last e => return .last (← walkExpr q R p (child path 0) inPartial expected e)
    | .lastBind k t e => return .lastBind k t (← walkExpr q R .other (child path 0) inPartial (some t) e)
    | .lastDiscard e => return .lastDiscard (← walkExpr q R .other (child path 0) inPartial none e)
    | .bind k t e rest => return .bind k t (← walkExpr q R .other (child path 0) inPartial (some t) e) (← walkBlock q R p (child path 1) inPartial expected rest)
    | .discard e rest => return .discard (← walkExpr q R .other (child path 0) inPartial none e) (← walkBlock q R p (child path 1) inPartial expected rest)
    | .seq e rest => return .seq (← walkExpr q R .other (child path 0) inPartial (some (.base .unit)) e) (← walkBlock q R p (child path 1) inPartial expected rest)
    | .lastPat k pat t e => return .lastPat k pat t (← walkExpr q R .other (child path 0) inPartial (some t) e)
    | .bindPat k pat t e rest => return .bindPat k pat t (← walkExpr q R .other (child path 0) inPartial (some t) e) (← walkBlock q R p (child path 1) inPartial expected rest)
  def walkExprs (q : Input) (R : Option Ty) (path : List Nat) (i : Nat) (inPartial : Bool) : Exprs → Walk Exprs
    | .nil => pure .nil
    | .cons e es => return .cons (← walkExpr q R .other (child path i) inPartial none e) (← walkExprs q R path (i+1) inPartial es)
  def walkHoles (q : Input) (R : Option Ty) (path : List Nat) (i : Nat) : HoleArgs → Walk HoleArgs
    | .nil => pure .nil
    | .hole t rest => return .hole t (← walkHoles q R path (i+1) rest)
    | .expr e rest => return .expr (← walkExpr q R .other (child path i) true none e) (← walkHoles q R path (i+1) rest)
  def walkArms (q : Input) (R : Option Ty) (p : Position) (path : List Nat)
      (inPartial : Bool) (t : Ty) : Arms → Walk Arms
    | .nil => pure .nil
    | .cons alts guard body rest => do
      let g ← match guard with
        | none => pure none
        | some e => do
          modify fun s => { s with guards := s.guards.push (child path 0) }
          pure (some (← walkExpr q none .other (child path 0) inPartial none e))
      return .cons alts g (← walkBlock q R p (child path 1) inPartial (some t) body) (← walkArms q R p (child path 2) inPartial t rest)
  def walkClauses (q : Input) (R : Option Ty) (path : List Nat) (inPartial : Bool) : Clauses → Walk Clauses
    | .nil => pure .nil
    | .cons o n nt body rest => do
      if let .prim name := o then modify fun s => { s with prims := name :: s.prims }
      return .cons o n nt (← walkBlock q (R.map (shiftTy nt 0)) .other (child path 0) inPartial none body) (← walkClauses q R (child path 1) inPartial rest)
end
end SurfaceCheck
