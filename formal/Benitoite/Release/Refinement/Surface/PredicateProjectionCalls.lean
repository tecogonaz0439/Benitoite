import Benitoite.Release.Refinement.Surface.PredicateAccessorTargets
import Benitoite.Release.Refinement.Surface.PredicateProjectionObservation
import Benitoite.Release.Refinement.Surface.PredicateProjectSource

/-! # レコードの欄を対象とする判定の呼出しの解決

元の取り出しの式を検査用に保持し、受け手の元の値と、宣言から得た欄の列を内部の行へ渡す。
内部の行の署名は受け手の型パラメータだけを持ち、呼出し元の値や範囲を署名へ埋め込まない。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateProjectionCalls
open PredicateRows PredicateAccessorTargets PredicateProjection

abbrev Rows := List (PrimName × Row)

/-- 中間の欄のdataと、末尾の欄の判定対象のsortを照合する。 -/
def routeSorts : List PredicateAccessorTargets.Step → «Sort» → Bool
  | [], _ => true
  | [step], sort => decide (step.sort = sort)
  | step :: next :: rest, sort => decide (step.sort = .data) && routeSorts (next :: rest) sort

theorem routeSorts_sound {steps sort} (h : routeSorts steps sort = true) :
    RouteSorted (steps.map PredicateAccessorTargets.Step.reference) sort := by
  induction steps with
  | nil => trivial
  | cons step rest ih =>
      cases rest with
      | nil =>
          change decide (step.sort = sort) = true at h
          change step.sort = sort
          exact of_decide_eq_true h
      | cons next rest =>
          obtain ⟨head, tail⟩ := Bool.and_eq_true_iff.mp h
          exact ⟨of_decide_eq_true head, ih tail⟩

/-- 根の宣言と欄の列を、型パラメータを持つ内部行の仕様にする。 -/
def candidate {p source} (target : Parsed p source) (entry : Entry) : Option (Projection × List Ty) :=
  match target.steps with
  | [] => none
  | first :: _ => if routeSorts target.steps entry.sort then
      some (⟨first.declaration.ntys, first.declaration.data,
        target.steps.map Step.reference, entry⟩, first.types)
    else none

/-- 解決の候補にした経路は、中間と末尾のsortの検査を満たす。 -/
theorem candidate_sorted {p source} {target : Parsed p source} {entry projection types}
    (h : candidate target entry = some (projection, types)) : RouteSorted projection.route entry.sort := by
  unfold candidate at h
  split at h
  · cases h
  · split at h
    · rename_i hs
      cases h
      exact routeSorts_sound hs
    · cases h

/-- 名前によるlookupと同じ行を選ぶ。重複した名前の後ろの行を誤って参照しない。 -/
def internalName (rows : Rows) (projection : Projection) : Option PrimName :=
  (rows.find? (fun row => decide (row.2 = .projected projection ∧ rows.lookup row.1 = some (.projected projection)))).map Prod.fst

private theorem internalName_lookup {rows projection name} (h : internalName rows projection = some name) :
    rows.lookup name = some (.projected projection) := by
  unfold internalName at h
  obtain ⟨row, hf, he⟩ := Option.map_eq_some_iff.mp h
  have hrow : row.2 = .projected projection ∧ rows.lookup row.1 = some (.projected projection) :=
    of_decide_eq_true (List.find?_some
      (p := fun (row : PrimName × Row) => decide (row.2 = .projected projection ∧ rows.lookup row.1 = some (.projected projection))) hf)
  cases he
  exact hrow.2

/-- 元の欄の式を保持した内部形。元の式は型を再検査し、実行時の引数は受け手の値一つだけである。 -/
def encodedCall (name : PrimName) (types : List Ty) (projection : Projection)
    (root source : Expr) (term : Term) : Expr :=
  .partialCall (.primName name types [] []) [] (.expr none 0 root (.expr none 1 source .nil))
    (projection.result (termBind (fun i => some (.var (i + 1))) term)) Eff.empty

/-- 登録済みの取り出しの列を、同じ欄を判定する内部行へ解決する。 -/
def resolve (rows : Rows) (p : Program) (entry : Entry) (source : Expr) : Option Expr := do
  let target ← PredicateAccessorTargets.parse p source
  let (projection, types) ← candidate target entry
  let name ← internalName rows projection
  let rootTerm ← target.value.toTerm?
  pure (encodedCall name types projection target.root source rootTerm)

/-- 同じ合成表に登録した、対象の値を直接判定する行を選ぶ。 -/
def scalarName (rows : Rows) (entry : Entry) : Option PrimName :=
  (rows.find? (fun row => decide (row.2 = .scalar entry ∧ rows.lookup row.1 = some (.scalar entry)))).map Prod.fst

/-- 欄の内部行がある呼出しを先に解決し、それ以外は同じ表の値の判定を使う。 -/
def resolveCall (rows : Rows) (p : Program) (name : PrimName)
    (labels : List (Option String)) (positions : List Nat) (args : Exprs) : Expr :=
  let fallback := Expr.call (.primName name [] [] []) labels positions args
  match PredicateCalls.apiOfName name with
  | none => fallback
  | some api =>
      if CallOk api.names api.inputs.length false labels positions ∧ args.length = api.inputs.length then
        match PredicateCalls.identify api
            (recordFields api.inputs.length positions (PredicateCalls.expressions args) .unit) with
        | none => fallback
        | some (entry, target) =>
            ((resolve rows p entry target).orElse (fun _ =>
              (scalarName rows entry).bind (fun key => PredicateCalls.resolvedCall key entry target))).getD fallback
      else fallback

/-- 入れ子の呼出しも、同じプログラムと合成表で解決する。 -/
def resolveExpr (rows : Rows) (p : Program) : Expr → Expr :=
  PredicateCalls.resolveExprWith (resolveCall rows p)

/-- 関数と節の本体へ同じ解決を適用する。 -/
def resolveBlock (rows : Rows) (p : Program) : Block → Block :=
  PredicateCalls.resolveBlockWith (resolveCall rows p)

private theorem resolve_shape {rows p entry source output} (h : resolve rows p entry source = some output) :
    ∃ name types projection root value term,
      rows.lookup name = some (.projected projection) ∧ root.valueOf? = some value ∧ value.toTerm? = some term ∧
      output = encodedCall name types projection root source term := by
  unfold resolve at h
  obtain ⟨target, hp, h⟩ := Option.bind_eq_some_iff.mp h
  obtain ⟨pair, hc, h⟩ := Option.bind_eq_some_iff.mp h
  rcases pair with ⟨projection, types⟩
  obtain ⟨name, hn, h⟩ := Option.bind_eq_some_iff.mp h
  obtain ⟨term, ht, h⟩ := Option.bind_eq_some_iff.mp h
  cases h
  exact ⟨name, types, projection, target.root, target.value, term,
    internalName_lookup hn, target.root_value, ht, rfl⟩

/-- 解決に成功した欄の判定は、元の値を一度だけ内部の行へ渡す。 -/
theorem resolve_desugar {rows p entry source output} (h : resolve rows p entry source = some output)
    (op : OpPrim) (position : Position) :
    ∃ name types projection value,
      rows.lookup name = some (.projected projection) ∧
      desugarExpr op position output = .app (.prim name types [] []) [value] := by
  obtain ⟨name, types, projection, root, value, term, hn, hv, ht, rfl⟩ := resolve_shape h
  exact ⟨name, types, projection, value, hn, desugar_predicateProject hv⟩

/-- 欄の判定の受理は、元の取り出しの式を同じ文脈で純粋に型付けた証拠を保つ。 -/
theorem resolve_source_checked {rows program entry source output}
    (h : resolve rows program entry source = some output) {D B op Q Δ C Γ Φ R position a ε}
    (typed : HasTypeQ D B op Q Δ C Γ Φ R position output a ε) :
    ∃ input, HasTypeQ D B op Q Δ C Γ Φ R .other source input Eff.empty := by
  obtain ⟨name, types, projection, root, value, term, hn, hv, ht, rfl⟩ := resolve_shape h
  exact typed.predicateProject_source

/-- 開いた範囲の文脈でも、元の取り出しの再検査を省かない。 -/
theorem resolve_source_checked_open {rows program entry source output}
    (h : resolve rows program entry source = some output) {D B ks op Q Δ C Γ Φ R position a ε}
    (typed : OpenSurface.HasTypeQ D B ks op Q Δ C Γ Φ R position output a ε) :
    ∃ input, OpenSurface.HasTypeQ D B ks op Q Δ C Γ Φ R .other source input Eff.empty := by
  obtain ⟨name, types, projection, root, value, term, hn, hv, ht, rfl⟩ := resolve_shape h
  exact typed.predicateProject_source

end Benitoite.Release.Refinement.Surface.PredicateProjectionCalls
