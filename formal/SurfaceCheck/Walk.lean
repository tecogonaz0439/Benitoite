import Benitoite.Exchange.CheckInput

/-! 末尾の照合の結果型を検査と同じ位置で補正し、分類に使う構文を保存する。
設計書 01-12「型の情報を付けた表層の構文と型付け」に対応する。 -/
namespace SurfaceCheck
open Benitoite.Release Benitoite.Surface Benitoite.Surface.Check Benitoite.Surface.CheckTools
structure Node where
  path : List Nat
  expr : Expr
  expected : Option Ty := none
structure WalkState where
  nodes : Array Node := #[]
  changes : Array (List Nat) := #[]
  nonUnit : Nat := 0
  tailMatches : Nat := 0
  prims : List String := []
abbrev Walk := StateM WalkState
mutual
  def walkExpr (q : Input) (R : Option Ty) (p : Position) (path : List Nat)
      (expected : Option Ty) (e : Expr) : Walk Expr := do
    modify fun s => { s with nodes := s.nodes.push ⟨path,e,expected⟩ }
    match e with
    | .constE t a => return .constE t (← walkExpr q R .other (child path 0) (some t) a)
    | .primName n _ _ _ =>
      modify fun s => { s with prims := n :: s.prims }; return e
    | .paren a => return .paren (← walkExpr q R p (child path 0) expected a)
    | .block b => return .block (← walkBlock q R p (child path 0) expected b)
    | .conCall c ts args => return .conCall c ts (← walkExprs q R (child path 0) 0 args)
    | .record c ts pos args => return .record c ts pos (← walkExprs q R (child path 0) 0 args)
    | .recordUpdate c ts n pos base args =>
      return .recordUpdate c ts n pos (← walkExpr q R .other (child path 0) none base) (← walkExprs q R (child path 1) 0 args)
    | .call f labels positions args => return .call (← walkExpr q R .other (child path 0) none f) labels positions (← walkExprs q R (child path 1) 0 args)
    | .pipe a b => return .pipe (← walkExpr q R .other (child path 0) none a) (← walkExpr q R .other (child path 1) none b)
    | .partialCall f names args r eff =>
      return .partialCall (← walkExpr q (some r) .other (child path 0) none f) names (← walkHoles q (some r) (child path 1) 0 args) r eff
    | .builderOp op i args kind =>
      return .builderOp op i (← walkExprs q R (child path 0) 0 args) kind
    | .partialCon c ts args =>
      let r := (q.D.cons c).map fun d => Ty.data d.data ts
      return .partialCon c ts (← walkHoles q r (child path 0) 0 args)
    | .binary op t a b =>
      match q.opPrim (.binary op) t with
      | some (n,_) => modify fun s => { s with prims := n :: s.prims }
      | none => pure ()
      return .binary op t (← walkExpr q R .other (child path 0) (some t) a) (← walkExpr q R .other (child path 1) (some t) b)
    | .neg t a =>
      match q.opPrim .neg t with
      | some (n,_) => modify fun s => { s with prims := n :: s.prims }
      | none => pure ()
      return .neg t (← walkExpr q R .other (child path 0) (some t) a)
    | .not a => return .not (← walkExpr q R .other (child path 0) none a)
    | .and a b => return .and (← walkExpr q R .other (child path 0) none a) (← walkExpr q R p (child path 1) none b)
    | .or a b => return .or (← walkExpr q R .other (child path 0) none a) (← walkExpr q R p (child path 1) none b)
    | .list t args => return .list t (← walkExprs q R (child path 0) 0 args)
    | .listSpread t f before spread after =>
      return .listSpread t (← walkExpr q R .other (child path 0) none f) (← walkExprs q R (child path 1) 0 before) (← walkExpr q R .other (child path 2) none spread) (← walkExprs q R (child path 3) 0 after)
    | .interpolation parts es fs => return .interpolation parts (← walkExprs q R (child path 0) 0 es) (← walkExprs q R (child path 1) 0 fs)
    | .lam names ps r eff body => return .lam names ps r eff (← walkBlock q (some r) .tail (child path 0) (some r) body)
    | .ite c y n => return .ite (← walkExpr q R .other (child path 0) none c) (← walkBlock q R p (child path 1) expected y) (← walkBlock q R p (child path 2) expected n)
    | .elseIf c y n => return .elseIf (← walkExpr q R .other (child path 0) none c) (← walkBlock q R p (child path 1) expected y) (← walkExpr q R p (child path 2) expected n)
    | .ifOnly c y => return .ifOnly (← walkExpr q R .other (child path 0) none c) (← walkBlock q R p (child path 1) (some (.base .unit)) y)
    | .matchE t a arms =>
      if p == .tail then modify fun s => { s with tailMatches := s.tailMatches + 1 }
      let mut t' := t
      if p == .tail && armsExits arms then
        if let some r := R then
          if !tyEq q.atoms t r then
            t' := r
            modify fun s => { s with changes := s.changes.push path, nonUnit := s.nonUnit + if tyEq q.atoms t (.base .unit) then 0 else 1 }
      return .matchE t' (← walkExpr q R .other (child path 0) none a) (← walkArms q R p (child path 1) t' arms)
    | .returnE t a =>
      return .returnE t (← walkExpr q R p (child path 0) R a)
    | .tryResult ts ok err a => return .tryResult ts ok err (← walkExpr q R .other (child path 0) none a)
    | .tryOption ts yes no a => return .tryOption ts yes no (← walkExpr q R .other (child path 0) none a)
    | .tryResultDie t ok err dict showMethod exit a message =>
      let a' ← walkExpr q R .other (child path 0) none a
      let message' : Option Expr ← match message with
        | none => pure none
        | some m => Option.some <$> walkExpr q none .other (child path 1) (some (.base .string)) m
      return .tryResultDie t ok err dict showMethod exit a' message'
    | .tryOptionDie t yes no exit a message =>
      let a' ← walkExpr q R .other (child path 0) none a
      let message' : Option Expr ← match message with
        | none => pure none
        | some m => Option.some <$> walkExpr q none .other (child path 1) (some (.base .string)) m
      return .tryOptionDie t yes no exit a' message'
    | .withE o a body => return .withE o (← walkExpr q R .other (child path 0) none a) (← walkBlock q R .other (child path 1) expected body)
    | .lazyE body => return .lazyE (← walkBlock q none .other (child path 0) none body)
    | .handleFail e t body clause => return .handleFail e t (← walkBlock q R .other (child path 0) none body) (← walkBlock q R .other (child path 1) (some t) clause)
    | .handleE body cs => return .handleE (← walkBlock q R .other (child path 0) none body) (← walkClauses q R (child path 1) cs)
    | .resume k a => return .resume k (← walkExpr q R .other (child path 0) none a)
    | _ => return e
  def walkBlock (q : Input) (R : Option Ty) (p : Position) (path : List Nat)
      (expected : Option Ty) : Block → Walk Block
    | .empty => pure .empty
    | .last e => return .last (← walkExpr q R p (child path 0) expected e)
    | .lastBind k t e => return .lastBind k t (← walkExpr q R .other (child path 0) (some t) e)
    | .lastDiscard e => return .lastDiscard (← walkExpr q R .other (child path 0) none e)
    | .builderBind k rest => do
      return .builderBind k (← walkBlock q R p (child path 0) expected rest)
    | .bind k t e rest => return .bind k t (← walkExpr q R .other (child path 0) (some t) e) (← walkBlock q R p (child path 1) expected rest)
    | .discard e rest => return .discard (← walkExpr q R .other (child path 0) none e) (← walkBlock q R p (child path 1) expected rest)
    | .seq e rest => return .seq (← walkExpr q R .other (child path 0) (some (.base .unit)) e) (← walkBlock q R p (child path 1) expected rest)
    | .lastPat k pat t e => return .lastPat k pat t (← walkExpr q R .other (child path 0) (some t) e)
    | .bindPat k pat t e rest => return .bindPat k pat t (← walkExpr q R .other (child path 0) (some t) e) (← walkBlock q R p (child path 1) expected rest)
  def walkExprs (q : Input) (R : Option Ty) (path : List Nat) (i : Nat) : Exprs → Walk Exprs
    | .nil => pure .nil
    | .cons e es => return .cons (← walkExpr q R .other (child path i) none e) (← walkExprs q R path (i+1) es)
  def walkHoles (q : Input) (R : Option Ty) (path : List Nat) (i : Nat) : HoleArgs → Walk HoleArgs
    | .nil => pure .nil
    | .hole label position t rest => return .hole label position t (← walkHoles q R path (i+1) rest)
    | .expr label position e rest => return .expr label position (← walkExpr q R .other (child path i) none e) (← walkHoles q R path (i+1) rest)
  def walkArms (q : Input) (R : Option Ty) (p : Position) (path : List Nat)
      (t : Ty) : Arms → Walk Arms
    | .nil => pure .nil
    | .cons alts guard body rest => do
      let g ← match guard with
        | none => pure none
        | some e => do
          pure (some (← walkExpr q none .other (child path 0) none e))
      return .cons alts g (← walkBlock q R p (child path 1) (some t) body) (← walkArms q R p (child path 2) t rest)
  def walkClauses (q : Input) (R : Option Ty) (path : List Nat) : Clauses → Walk Clauses
    | .nil => pure .nil
    | .cons o n nt body rest ndicts => do
      if let .prim name := o then modify fun s => { s with prims := name :: s.prims }
      return .cons o n nt (← walkBlock q (R.map (shiftTy q.atoms nt 0)) .other (child path 0) none body) (← walkClauses q R (child path 1) rest) ndicts
end

-- 分類に使う全ノードの列を独立に期待する。説明を落とす場合と、説明に外側の
-- 戻り値を渡す場合の両方を、二つの構文に対して検出する。
example (q : Input) :
    let t := Ty.base .integer
    let s := Ty.base .string
    let input := Expr.returnE t (.local 0)
    let message := some (Expr.returnE s (.local 1))
    [Expr.tryResultDie t "Ok" "Error" (.local 2) "show" "Process.exit" input message,
     Expr.tryOptionDie t "Some" "None" "Process.exit" input message].map (fun e =>
       ((walkExpr q (some t) .tail [] none e).run {}).2.nodes.toList.map
         (fun n => (n.path, n.expected))) =
    [[([], none), ([0], none), ([0, 0], some t), ([1], some s), ([1, 0], none)],
     [([], none), ([0], none), ([0, 0], some t), ([1], some s), ([1, 0], none)]] := by rfl

end SurfaceCheck
