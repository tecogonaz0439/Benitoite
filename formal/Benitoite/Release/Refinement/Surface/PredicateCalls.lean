import Benitoite.Release.Refinement.Surface.PredicateRows
import Benitoite.Release.Refinement.Surface.CheckSupport
import Benitoite.Release.Refinement.Surface.OpenSurfaceProperty1

/-! # リテラルの条件を持つ判定の呼出しの解決

篩の述語に写せる呼出しを、同じ述語と真偽が一致する結果型を持つ内部の行へ解決する。
対象の値は元の値の文脈から直接渡す。動的な条件や観測できる値を持たない対象は通常の呼出しを保つ。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateCalls
open PredicateRows PredicateResponse

/-- 括弧は判定の対象とリテラルの条件の写しで区別しない。 -/
def stripParens : Expr → Expr
  | .paren e => stripParens e
  | e => e

/-- 括弧を除いた対象は、同じ位置で同じ核の計算へ脱糖する。 -/
theorem stripParens_desugar (op : OpPrim) (position : Position) (source : Expr) :
    desugarExpr op position (stripParens source) = desugarExpr op position source := by
  cases source <;> try rfl
  case paren e =>
    simpa only [stripParens, desugarExpr] using stripParens_desugar op position e
termination_by source

def expressions : Exprs → List Expr
  | .nil => []
  | .cons e es => e :: expressions es

/-- 公開名が指す純粋な判定の種類。 -/
def apiOfName : PrimName → Option API
  | "Scope.pathMatches" => some .path
  | "Scope.hostMatches" => some .host
  | "String.charactersIn" => some .characters
  | "Float.isFinite" => some (.floating .binary64 .finite)
  | "Float.isInfinite" => some (.floating .binary64 .infinite)
  | "Float.isPositiveInfinity" => some (.floating .binary64 .positiveInfinity)
  | "Float.isNegativeInfinity" => some (.floating .binary64 .negativeInfinity)
  | "Float.isPositiveZero" => some (.floating .binary64 .positiveZero)
  | "Float.isNegativeZero" => some (.floating .binary64 .negativeZero)
  | "Float32.isFinite" => some (.floating .binary32 .finite)
  | "Float32.isInfinite" => some (.floating .binary32 .infinite)
  | "Float32.isPositiveInfinity" => some (.floating .binary32 .positiveInfinity)
  | "Float32.isNegativeInfinity" => some (.floating .binary32 .negativeInfinity)
  | "Float32.isPositiveZero" => some (.floating .binary32 .positiveZero)
  | "Float32.isNegativeZero" => some (.floating .binary32 .negativeZero)
  | _ => none

/-- 宣言順の引数から、リテラルの条件と対象を取り出す。 -/
private def identifyCore : API → List Expr → Option (Entry × Expr)
  | .path, [.literal (.string pattern), target] =>
      match parseAtPattern .path (.const (.string pattern)) with
      | some (.path p) => some (.path p, target)
      | _ => none
  | .host, [.literal (.string pattern), target] =>
      match parseAtPattern .host (.const (.string pattern)) with
      | some (.host p) => some (.host p, target)
      | _ => none
  | .characters, [target, .literal (.character lo), .literal (.character hi)] =>
      some (.characters lo hi, target)
  | .floating width test, [target] => some (.floating width test, target)
  | _, _ => none

/-- 括弧を除いたリテラルと対象を、公開名が選ぶ判定へ写す。 -/
def identify (api : API) (args : List Expr) : Option (Entry × Expr) :=
  identifyCore api (args.map stripParens)

/-- 解析したリテラルの絶対範囲は、内部の行に必要な整形式を満たす。 -/
theorem identify_valid {api args entry target} (h : identify api args = some (entry, target)) : entry.Valid := by
  unfold identify identifyCore at h
  split at h
  · split at h
    · cases h
      exact (parseAtPattern_formed (by assumption)).2.1
    · cases h
  · split at h
    · cases h
      exact (parseAtPattern_formed (by assumption)).2.1
    · cases h
  · cases h; trivial
  · cases h; trivial
  · cases h

/-- 公開名から取り出したパスの文字列の条件と、同じ内部行の全入力の応答は一致する。 -/
theorem path_delta {pattern p}
    (hp : parseAtPattern .path (.const (.string pattern)) = some (.path p)) (s : String) :
    (Entry.path p).delta [] [] [] [.const (.string s)] =
      API.path.delta API.path.name [] [] [] [.const (.string pattern), .const (.string s)] := by
  simp only [Entry.delta, API.delta, API.name, and_self, ite_true]
  rw [path_run hp]

/-- ホストについても、公開の判定と内部の行は同じ対象の文字列で一致する。 -/
theorem host_delta {pattern p}
    (hp : parseAtPattern .host (.const (.string pattern)) = some (.host p)) (s : String) :
    (Entry.host p).delta [] [] [] [.const (.string s)] =
      API.host.delta API.host.name [] [] [] [.const (.string pattern), .const (.string s)] := by
  simp only [Entry.delta, API.delta, API.name, and_self, ite_true]
  rw [host_run hp]

/-- 文字集合の両端を行に固定しても、対象の全ての文字列で同じ応答を返す。 -/
theorem characters_delta (lo hi : Char) (s : String) :
    (Entry.characters lo hi).delta [] [] [] [.const (.string s)] =
      API.characters.delta API.characters.name [] [] []
        [.const (.string s), .const (.character lo), .const (.character hi)] := by
  rfl

/-- 浮動小数点の分類の内部行は、同じビット列を公開の判定へ渡す。 -/
theorem floating_delta (width : FloatWidth) (test : FloatTest) (values : List Val) :
    (Entry.floating width test).delta [] [] [] values =
      (API.floating width test).delta (API.floating width test).name [] [] [] values := by
  simp [Entry.delta, API.delta, Entry.run]

/-- 特殊化した行の有限表から、同じ判定を行う内部名を選ぶ。 -/
def internalName (rows : List (PrimName × Entry)) (entry : Entry) : Option PrimName :=
  (rows.find? (fun (row : PrimName × Entry) => decide (row.2 = entry ∧ rows.lookup row.1 = some entry))).map Prod.fst

/-- 選んだ内部名の実際のlookupは、解決に使った行と一致する。 -/
theorem internalName_lookup {rows entry name} (h : internalName rows entry = some name) :
    rows.lookup name = some entry := by
  unfold internalName at h
  obtain ⟨row, hf, he⟩ := Option.map_eq_some_iff.mp h
  have hrow : row.2 = entry ∧ rows.lookup row.1 = some entry :=
    of_decide_eq_true (List.find?_some (p := fun (row : PrimName × Entry) => decide (row.2 = entry ∧ rows.lookup row.1 = some entry)) hf)
  cases he
  exact hrow.2

/-- 元の文脈の値を直接渡す内部の呼出し。穴のない部分適用の形を内部の符号化として使う。 -/
def resolvedCall (name : PrimName) (entry : Entry) (target : Expr) : Option Expr := do
  let root := stripParens target
  let value ← root.valueOf?
  let term ← value.toTerm?
  pure (.partialCall (.primName name [] [] []) [] (.expr none 0 root .nil)
    (entry.result (termBind (fun i => some (.var (i + 1))) term)) Eff.empty)

/-- 公開呼出し一つを解決する。ラベルと位置を先に検査し、リテラルを除いた対象の値だけを内部名へ渡す。
対象又は条件を述語へ写せない場合と、内部の行がない場合は、元の呼出しを保つ。 -/
def resolveCall (rows : List (PrimName × Entry)) (name : PrimName)
    (labels : List (Option String)) (positions : List Nat) (args : Exprs) : Expr :=
  let source := Expr.call (.primName name [] [] []) labels positions args
  match apiOfName name with
  | none => source
  | some api =>
      if CallOk api.names api.inputs.length false labels positions ∧ args.length = api.inputs.length then
        match identify api (recordFields api.inputs.length positions (expressions args) .unit) with
        | none => source
        | some (entry, target) =>
            ((internalName rows entry).bind (fun key => resolvedCall key entry target)).getD source
      else source

/-- 解決した公開呼出しは、整形式な同じ行を実際の内部名のlookupで参照する。 -/
theorem resolveCall_selected {rows name labels positions args api entry target key output}
    (ha : apiOfName name = some api)
    (hc : CallOk api.names api.inputs.length false labels positions ∧ args.length = api.inputs.length)
    (hi : identify api (recordFields api.inputs.length positions (expressions args) .unit) = some (entry, target))
    (hk : internalName rows entry = some key) (hr : resolvedCall key entry target = some output) :
    resolveCall rows name labels positions args = output ∧ rows.lookup key = some entry ∧ entry.Valid := by
  refine ⟨?_, internalName_lookup hk, identify_valid hi⟩
  simp only [resolveCall, ha, ite_eq_left hc, hi, hk, Option.bind_some, hr, Option.getD_some]

mutual
  /-- 入れ子の式・本体も含め、公開の判定の呼出しを名前解決済みの内部の形に写す。 -/
  def resolveExprWith (resolver : PrimName → List (Option String) → List Nat → Exprs → Expr) : Expr → Expr
    | .builderOp op i args kind => .builderOp op i (resolveExprsWith resolver args) kind
    | .constE ty body => .constE ty (resolveExprWith resolver body)
    | .handleFail error result body clause => .handleFail error result (resolveBlockWith resolver body) (resolveBlockWith resolver clause)
    | .paren e => .paren (resolveExprWith resolver e)
    | .block body => .block (resolveBlockWith resolver body)
    | .conCall c ts args => .conCall c ts (resolveExprsWith resolver args)
    | .record c ts positions args => .record c ts positions (resolveExprsWith resolver args)
    | .recordUpdate c ts n positions base args => .recordUpdate c ts n positions (resolveExprWith resolver base) (resolveExprsWith resolver args)
    | .call (.primName name [] [] []) labels positions args =>
        resolver name labels positions (resolveExprsWith resolver args)
    | .call f labels positions args => .call (resolveExprWith resolver f) labels positions (resolveExprsWith resolver args)
    | .pipe lhs rhs => .pipe (resolveExprWith resolver lhs) (resolveExprWith resolver rhs)
    | .partialCall f names args ret eff => .partialCall (resolveExprWith resolver f) names (resolveHolesWith resolver args) ret eff
    | .partialCon c ts args => .partialCon c ts (resolveHolesWith resolver args)
    | .binary op ty lhs rhs => .binary op ty (resolveExprWith resolver lhs) (resolveExprWith resolver rhs)
    | .neg ty e => .neg ty (resolveExprWith resolver e)
    | .not e => .not (resolveExprWith resolver e)
    | .and lhs rhs => .and (resolveExprWith resolver lhs) (resolveExprWith resolver rhs)
    | .or lhs rhs => .or (resolveExprWith resolver lhs) (resolveExprWith resolver rhs)
    | .list ty args => .list ty (resolveExprsWith resolver args)
    | .listSpread ty concat before spread after =>
        .listSpread ty (resolveExprWith resolver concat) (resolveExprsWith resolver before) (resolveExprWith resolver spread) (resolveExprsWith resolver after)
    | .interpolation parts args fs => .interpolation parts (resolveExprsWith resolver args) (resolveExprsWith resolver fs)
    | .lam names params ret eff body => .lam names params ret eff (resolveBlockWith resolver body)
    | .ite cond yes no => .ite (resolveExprWith resolver cond) (resolveBlockWith resolver yes) (resolveBlockWith resolver no)
    | .elseIf cond yes no => .elseIf (resolveExprWith resolver cond) (resolveBlockWith resolver yes) (resolveExprWith resolver no)
    | .ifOnly cond yes => .ifOnly (resolveExprWith resolver cond) (resolveBlockWith resolver yes)
    | .matchE ty e arms => .matchE ty (resolveExprWith resolver e) (resolveArmsWith resolver arms)
    | .returnE ty e => .returnE ty (resolveExprWith resolver e)
    | .tryResult ts ok err e => .tryResult ts ok err (resolveExprWith resolver e)
    | .tryOption ts someCon noneCon e => .tryOption ts someCon noneCon (resolveExprWith resolver e)
    | .tryResultDie ty ok err dict showMethod exit e msg =>
        .tryResultDie ty ok err dict showMethod exit (resolveExprWith resolver e) (match msg with | none => none | some message => some (resolveExprWith resolver message))
    | .tryOptionDie ty someCon noneCon exit e msg =>
        .tryOptionDie ty someCon noneCon exit (resolveExprWith resolver e) (match msg with | none => none | some message => some (resolveExprWith resolver message))
    | .withE o e body => .withE o (resolveExprWith resolver e) (resolveBlockWith resolver body)
    | .lazyE body => .lazyE (resolveBlockWith resolver body)
    | .handleE body clauses => .handleE (resolveBlockWith resolver body) (resolveClausesWith resolver clauses)
    | .resume k e => .resume k (resolveExprWith resolver e)
    | e => e

  def resolveExprsWith (resolver : PrimName → List (Option String) → List Nat → Exprs → Expr) : Exprs → Exprs
    | .nil => .nil
    | .cons e es => .cons (resolveExprWith resolver e) (resolveExprsWith resolver es)

  def resolveHolesWith (resolver : PrimName → List (Option String) → List Nat → Exprs → Expr) : HoleArgs → HoleArgs
    | .nil => .nil
    | .expr label position e rest => .expr label position (resolveExprWith resolver e) (resolveHolesWith resolver rest)
    | .hole label position ty rest => .hole label position ty (resolveHolesWith resolver rest)

  def resolveArmsWith (resolver : PrimName → List (Option String) → List Nat → Exprs → Expr) : Arms → Arms
    | .nil => .nil
    | .cons alts guard body rest =>
        .cons alts (match guard with | none => none | some condition => some (resolveExprWith resolver condition)) (resolveBlockWith resolver body) (resolveArmsWith resolver rest)

  def resolveClausesWith (resolver : PrimName → List (Option String) → List Nat → Exprs → Expr) : Clauses → Clauses
    | .nil => .nil
    | .cons op n nt body rest nd => .cons op n nt (resolveBlockWith resolver body) (resolveClausesWith resolver rest) nd

  /-- 関数又は節の本体を同じ値の束縛の下で解決する。 -/
  def resolveBlockWith (resolver : PrimName → List (Option String) → List Nat → Exprs → Expr) : Block → Block
    | .builderBind kind rest => .builderBind kind (resolveBlockWith resolver rest)
    | .empty => .empty
    | .last e => .last (resolveExprWith resolver e)
    | .lastBind kind ty e => .lastBind kind ty (resolveExprWith resolver e)
    | .lastDiscard e => .lastDiscard (resolveExprWith resolver e)
    | .bind kind ty e rest => .bind kind ty (resolveExprWith resolver e) (resolveBlockWith resolver rest)
    | .discard e rest => .discard (resolveExprWith resolver e) (resolveBlockWith resolver rest)
    | .seq e rest => .seq (resolveExprWith resolver e) (resolveBlockWith resolver rest)
    | .lastPat kind pat ty e => .lastPat kind pat ty (resolveExprWith resolver e)
    | .bindPat kind pat ty e rest => .bindPat kind pat ty (resolveExprWith resolver e) (resolveBlockWith resolver rest)
end

/-- 同じ構文の走査に、有限の判定の内部行の解決を渡す。 -/
def resolveExpr (rows : List (PrimName × Entry)) : Expr → Expr :=
  resolveExprWith (resolveCall rows)

/-- 関数又は節の本体へ、同じ有限表の解決を渡す。 -/
def resolveBlock (rows : List (PrimName × Entry)) : Block → Block :=
  resolveBlockWith (resolveCall rows)


/-- 内部の行への解決に成功した値は、同じ文脈のまま一度だけ核の呼出しへ渡る。 -/
theorem resolvedCall_desugar {name entry target output} (h : resolvedCall name entry target = some output)
    (op : OpPrim) (position : Position) :
    ∃ value term, (stripParens target).valueOf? = some value ∧ value.toTerm? = some term ∧
      output = .partialCall (.primName name [] [] []) [] (.expr none 0 (stripParens target) .nil)
        (entry.result (termBind (fun i => some (.var (i + 1))) term)) Eff.empty ∧
      desugarExpr op position output = .app (.prim name [] [] []) [value] ∧
      desugarExpr op position (stripParens target) = desugarExpr op position target := by
  unfold resolvedCall at h
  obtain ⟨value, hv, h⟩ := Option.bind_eq_some_iff.mp h
  obtain ⟨term, ht, h⟩ := Option.bind_eq_some_iff.mp h
  cases h
  exact ⟨value, term, hv, ht, rfl, desugar_predicateCall hv, stripParens_desugar op position target⟩

end Benitoite.Release.Refinement.Surface.PredicateCalls
