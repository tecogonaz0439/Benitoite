import Benitoite.Release.Refinement.Surface.CheckFormationData

/-!
# 欄の観測から計算する名目型の案内

宣言の欄型に、必要な sort と受け手の名目型の条件を当てる。
消去された構成子の型引数は条件を満たす代表型から構成し、変数の実際の型引数は文脈から読む。
生成した候補を宣言の検査へ戻すため、案内を外部の入力から受け取らない。
-/
namespace Benitoite.Release.Refinement.Surface.CheckDataHint
open CheckFormation CheckCompare

private inductive Shape where
  | any
  | sort (value : «Sort»)
  | data (owner : DataName) (arguments : Option (List Shape))

mutual
  private def merge : Shape → Shape → Option Shape
    | .any, b => some b
    | a, .any => some a
    | .sort a, .sort b => if a = b then some (.sort a) else none
    | .sort .data, b@(.data _ _) | b@(.data _ _), .sort .data => some b
    | .data d xs, .data e ys => if d = e then do
        let zs ← match xs, ys with
          | none, ys => some ys
          | xs, none => some xs
          | some xs, some ys => (mergeList xs ys).map some
        pure (.data d zs)
      else none
    | _, _ => none
  termination_by structural a _ => a

  private def mergeList : List Shape → List Shape → Option (List Shape)
    | [], [] => some []
    | x :: xs, y :: ys => do
        let z ← merge x y
        let zs ← mergeList xs ys
        pure (z :: zs)
    | _, _ => none
  termination_by structural xs _ => xs
end

private def assign (state : List Shape) (i : Nat) (wanted : Shape) : Option (List Shape) := do
  let previous ← state[i]?
  let updated ← merge previous wanted
  pure (state.set i updated)

mutual
  private def constrain (a : Ty) (wanted : Shape) (state : List Shape) : Option (List Shape) :=
    match wanted, a with
    | .any, _ => some state
    | _, .refined a _ => constrain a wanted state
    | _, .tvar i | _, .tapp i _ => assign state i wanted
    | .sort sort, a => if a.HasSort sort then some state else none
    | .data d wants, .data e args =>
        if d = e then match wants with
          | none => some state
          | some wants => constrainList args wants state
        else none
    | _, _ => none
  termination_by structural a

  private def constrainList : List Ty → List Shape → List Shape → Option (List Shape)
    | [], [], state => some state
    | a :: as, wanted :: wants, state => do
        let state ← constrain a wanted state
        constrainList as wants state
    | _, _, _ => none
  termination_by structural as _ _ => as
end

private def sortType : «Sort» → Ty
  | .integer => .base .integer
  | .character => .base .character
  | .float64 => .base .float
  | .float32 => .base .float32
  | .decimal => .base .decimal
  | .boolean => .base .boolean
  | .unit => .base .unit
  | .string => .base .string
  | .list => .list (.base .unit)
  | .bytes => .bytes
  | .map => .map (.base .unit) (.base .unit)
  | .set => .set (.base .unit)
  | .data => .data "" []
  | .target kind => .scoped "" kind .top

private theorem sortType_support (s : List Atom) (sort : «Sort») : (sortType sort).Support (· ∈ s) := by
  cases sort <;> trivial

mutual
  private def fill (wanted : Shape) (fallback : Ty) : Ty :=
    match wanted with
    | .any => fallback.observationType
    | .sort sort =>
        if fallback.HasSort sort then fallback.observationType else
        match sort, fallback.observationType.core with
        | .target kind, .opaque name _ | .target kind, .scoped name _ _ => .scoped name kind .top
        | _, _ => sortType sort
    | .data d none => match fallback.observationType.core with
      | .data e _ => if d = e then fallback.observationType else .data d []
      | _ => .data d []
    | .data d (some wants) => match fallback.observationType.core with
      | .data e args => if d = e then .data d (fillList wants args) else .data d (fillList wants [])
      | _ => .data d (fillList wants [])
  termination_by structural wanted

  private def fillList : List Shape → List Ty → List Ty
    | [], _ => []
    | wanted :: wants, [] => fill wanted (.base .unit) :: fillList wants []
    | wanted :: wants, a :: as => fill wanted a :: fillList wants as
  termination_by structural wants _ => wants
end

mutual
  private theorem fill_support (s : List Atom) (wanted : Shape) (fallback : Ty) :
      (fill wanted fallback).Support (· ∈ s) := by
    rw [fill.eq_def]
    cases wanted with
    | any => exact observationType_support s fallback
    | sort sort =>
        dsimp only
        split
        · exact observationType_support s fallback
        · split <;> first | trivial | exact sortType_support s _
    | data d wants =>
        cases wants with
        | none =>
            dsimp only
            split
            · split
              · exact observationType_support s fallback
              · trivial
            · trivial
        | some wants =>
            dsimp only
            split
            · split <;> exact fillList_support s wants _
            · exact fillList_support s wants _

  termination_by sizeOf wanted
  decreasing_by all_goals (simp_wf <;> omega)

  private theorem fillList_support (s : List Atom) (wants : List Shape) (fallback : List Ty) :
      Ty.SupportList (· ∈ s) (fillList wants fallback) := by
    rw [fillList.eq_def]
    cases wants with
    | nil => trivial
    | cons wanted wants => cases fallback with
      | nil => exact ⟨fill_support s wanted _, fillList_support s wants []⟩
      | cons a as => exact ⟨fill_support s wanted a, fillList_support s wants as⟩
  termination_by sizeOf wants
  decreasing_by all_goals (simp_wf <;> omega)
end

abbrev SupportedHint (s : List Atom) := {hint : DataHint // hint.Support s}

private def finish (q : Input) (P : Refinement.Program) (Γ : Ctx) (t : Term)
    (owner : DataName) (wants : Option (List Shape)) (accept : SupportedHint q.atoms → Bool)
    (hint : SupportedHint q.atoms) : Option (SupportedHint q.atoms) := do
  let (d, args) ← dataCheck q P Γ t hint.val
  if d ≠ owner then none else
  if accept hint then some hint else
  match wants with
  | none => none
  | some wants =>
      let proposed := fillList wants args
      if rawTyEq q.atoms (.data d (observationTypes args)) (.data d (observationTypes proposed)) then none else
      let widened : SupportedHint q.atoms := ⟨.widen hint.val proposed, hint.property, fillList_support q.atoms wants _⟩
      match dataCheck q P Γ t widened.val with
      | none => none
      | some _ => if accept widened then some widened else none

private def inferData (q : Input) (P : Refinement.Program) (Γ : Ctx) (t : Term)
    (owner : DataName) (wants : Option (List Shape)) (accept : SupportedHint q.atoms → Bool) : Option (SupportedHint q.atoms) :=
  match t with
  | .var _ => finish q P Γ t owner wants accept ⟨.var, trivial⟩
  | .dataValue c slots => do
      let cd ← P.cons c
      if cd.data ≠ owner ∨ slots.length ≠ cd.args.length then none else
      let wants := wants.getD (List.replicate cd.ntys .any)
      let args := fillList wants []
      finish q P Γ t owner (some wants) accept ⟨.value args, fillList_support q.atoms wants []⟩
  | .field ref receiver => do
      let cd ← P.cons ref.constructor
      let a ← cd.args[ref.position]?
      let requirements := constrain a (.data owner wants) (List.replicate cd.ntys .any)
      let needs := requirements.getD (List.replicate cd.ntys .any)
      let acceptReceiver := fun (hint : SupportedHint q.atoms) =>
        let h : SupportedHint q.atoms := ⟨.field hint.val, hint.property⟩
        (finish q P Γ t owner wants accept h).isSome
      let receiverHint ← inferData q P Γ receiver ref.owner (some needs) acceptReceiver
      finish q P Γ t owner wants accept ⟨.field receiverHint.val, receiverHint.property⟩
  | _ => none
termination_by structural t

/-- 案内を独立に検査し、受け手と宣言した欄型から結果の sort を得る。 -/
def fieldValid (q : Input) (P : Refinement.Program) (Γ : Ctx) (receiver : Term)
    (ref : FieldRef) (hint : DataHint) : Bool :=
  match dataCheck q P Γ receiver hint, P.cons ref.constructor with
  | some (d, ts), some cd => match cd.args[ref.position]? with
    | some a => decide (d = ref.owner ∧ cd.data = ref.owner ∧ cd.ntys = ts.length) &&
        (wfTy q 0 cd.ntys 0 a && decide ((substTy q ts [] a).HasSort ref.result))
    | none => false
  | _, _ => false

/-- 宣言と受け手の項から、欄に必要な名目型の候補を生成する。 -/
def inferFieldHint (q : Input) (P : Refinement.Program) (Γ : Ctx) (receiver : Term)
    (ref : FieldRef) : Option (SupportedHint q.atoms) := do
  let cd ← P.cons ref.constructor
  let a ← cd.args[ref.position]?
  let wants ← constrain a (.sort ref.result) (List.replicate cd.ntys .any)
  inferData q P Γ receiver ref.owner (some wants) (fun hint => fieldValid q P Γ receiver ref hint.val)

/-- 構成子の判定は、同じ名目の受け手を構成する候補を計算する。 -/
def inferConstructorHint (q : Input) (P : Refinement.Program) (Γ : Ctx) (receiver : Term)
    (constructor : ConName) : Option (SupportedHint q.atoms) := do
  let cd ← P.cons constructor
  inferData q P Γ receiver cd.data none (fun hint =>
    match dataCheck q P Γ receiver hint.val with
    | some (d, _) => decide (d = cd.data)
    | none => false)

end Benitoite.Release.Refinement.Surface.CheckDataHint
