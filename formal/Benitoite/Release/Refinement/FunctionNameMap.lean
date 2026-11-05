import Benitoite.Release.Refinement.Syntax
namespace Benitoite.Release.Refinement.FunctionNames

def swap (a b n : String) : String := if n = a then b else if n = b then a else n

theorem swap_injective (a b : String) : Function.Injective (swap a b) := by
  intro x y eq
  by_cases xa : x = a <;> by_cases xb : x = b <;>
    by_cases ya : y = a <;> by_cases yb : y = b <;>
    simp_all [swap]

def collisionNames : List String :=
  ["List.filter", "List.filterFrom", "List.map", "List.mapFrom", "Map.filter", "Map.map",
   "NonEmptyList.map", "Range.checkedLength", "Range.indexValue", "Range.indexValues",
   "Range.lengthMaximum", "Range.lengthMinimum", "Range.lengthValues", "Range.maximum",
   "Range.minimum", "Range.value", "Set.filter", "Set.map"]

def rename (refined : Bool) (name : String) : String :=
  collisionNames.foldl (fun n old => swap old ("%" ++ old ++ if refined then ".refined" else ".ordinary") n) name

private theorem fold_injective (refined : Bool) (names : List String) :
    Function.Injective (fun name => names.foldl (fun n old =>
      swap old ("%" ++ old ++ if refined then ".refined" else ".ordinary") n) name) := by
  induction names with
  | nil => exact fun _ _ h => h
  | cons name rest ih =>
    intro x y h
    exact swap_injective _ _ (ih h)

theorem rename_injective (refined : Bool) : Function.Injective (rename refined) :=
  fold_injective refined collisionNames

example : rename false "List.map" ≠ rename false "List.filter" := by
  intro h
  have same := rename_injective false h
  exact (by decide : ("List.map" : String) ≠ "List.filter") same

mutual
  def value (ρ : String → String) : Val → Val
    | .var i => .var i
    | .const c => .const c
    | .fnRef f ts es => .fnRef (ρ f) ts es
    | .prim b ts es rs => .prim b ts es rs
    | .lam ns ps m => .lam ns ps (computation ρ m)
    | .dependentLam t m => .dependentLam t (computation ρ m)
    | .closure t (.mk (.mk vs) m) => .closure t (.mk (.mk (slots ρ vs)) (computation ρ m))
    | .con c ts vs => .con c ts (values ρ vs)
    | .list vs => .list (values ρ vs)
    | .op o ts => .op o ts
    | .raise t e => .raise t e
    | .loc l => .loc l
    | .mapV ks vs => .mapV (values ρ ks) (values ρ vs)
    | .setV vs => .setV (values ρ vs)
    | .bytesV bs => .bytesV bs
    | .dict i ts vs => .dict i ts (values ρ vs)
    | .super v s => .super (value ρ v) s
    | .externalRef f ts => .externalRef f ts
    | .externalHandle h ts => .externalHandle h ts
    | .pathBases bs => .pathBases bs
    | .scopePattern r => .scopePattern r
    | .checkedAt r s t none => .checkedAt r s t none
    | .checkedAt r s t (some req) => .checkedAt r s t (some (value ρ req))
    | .atError d => .atError {d with originalPattern := value ρ d.originalPattern, originalTarget := value ρ d.originalTarget}
    | .checked t => .checked t
    | .checkedRequest t req => .checkedRequest t (value ρ req)
  def values (ρ : String → String) : List Val → List Val
    | [] => []
    | v :: vs => value ρ v :: values ρ vs
  def slots (ρ : String → String) : List (Option Val) → List (Option Val)
    | [] => []
    | none :: vs => none :: slots ρ vs
    | some v :: vs => some (value ρ v) :: slots ρ vs
  def computation (ρ : String → String) : Comp → Comp
    | .builderLet k m => .builderLet k (computation ρ m)
    | .builderOp k op r vs => .builderOp k op r (values ρ vs)
    | .ret v => .ret (value ρ v)
    | .letIn m n => .letIn (computation ρ m) (computation ρ n)
    | .app f vs => .app (value ρ f) (values ρ vs)
    | .ite v m n => .ite (value ρ v) (computation ρ m) (computation ρ n)
    | .match v as => .match (value ρ v) (arms ρ as)
    | .lazyC m => .lazyC (computation ρ m)
    | .escape v => .escape (value ρ v)
    | .use v m => .use (value ρ v) (computation ρ m)
    | .handle m cs => .handle (computation ρ m) (clauses ρ cs)
    | .resume k v => .resume (value ρ k) (value ρ v)
    | .externalCall f ts vs => .externalCall f ts (values ρ vs)
    | .issuePathBases b => .issuePathBases b
    | .checkAt k o sh none p v ix => .checkAt k o sh none (value ρ p) (value ρ v) ix
    | .checkAt k o sh (some bs) p v ix => .checkAt k o sh (some (value ρ bs)) (value ρ p) (value ρ v) ix
    | .meth d m ts es vs => .meth (value ρ d) m ts es (values ρ vs)
  def arms (ρ : String → String) : List Arm → List Arm
    | [] => []
    | .mk alts none m :: rest => .mk alts none (computation ρ m) :: arms ρ rest
    | .mk alts (some g) m :: rest => .mk alts (some (computation ρ g)) (computation ρ m) :: arms ρ rest
  def clauses (ρ : String → String) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: rest => .mk o n k (computation ρ m) :: clauses ρ rest
    | .fail e m :: rest => .fail e (computation ρ m) :: clauses ρ rest
end

def definition (ρ : String → String) (d : Def) : Def := {d with body := computation ρ d.body}

theorem definition_tel (ρ : String → String) (d : Def) : (definition ρ d).tel = d.tel := rfl
end Benitoite.Release.Refinement.FunctionNames
