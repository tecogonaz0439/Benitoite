import Benitoite.Interval.BudgetLocated

/-!
# 具体規則で辿れる構文的な到達可能性

先行順の各出現に、解析が親へ候補を返せる構文上の範囲を付ける。
呼び出しは標準束縛の認定前の候補として引数を含め、callee は含めない。
未知の部分木は番号の位置を保つが、親の構文的な到達可能性へは含めない。
この列は証明用であり、実行する解析には走査も予算消費も追加しない。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
-- syntactic reachability は実行で到達できることとは異なる。
-- 根から解析の候補を返し得る構文上の出現を表し、実行や標準束縛の同定を要求しない。
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 具体評価の候補となる形。呼び出しの認定と腕の到達は要求しない。 -/
def concreteRule : Expr → Bool
  | .literal (.integer _) | .literal (.boolean _) | .negInt _ | .unit | .local _
  | .paren _ | .constE _ _ | .returnE _ _ | .and _ _ | .or _ _ | .matchE _ _ _
  | .not _ | .block _ | .ite _ _ _ | .elseIf _ _ _ | .ifOnly _ _ => true
  | .literal (.integer8 value) => decide (IntKind.min .integer8 ≤ (value : Int) ∧
      (value : Int) ≤ IntKind.max .integer8)
  | .literal (.integer16 value) => decide (IntKind.min .integer16 ≤ (value : Int) ∧
      (value : Int) ≤ IntKind.max .integer16)
  | .literal (.integer32 value) => decide (IntKind.min .integer32 ≤ (value : Int) ∧
      (value : Int) ≤ IntKind.max .integer32)
  | .literal (.unsignedInteger16 value) => decide (IntKind.min .unsignedInteger16 ≤ (value : Int) ∧
      (value : Int) ≤ IntKind.max .unsignedInteger16)
  | .literal (.unsignedInteger32 value) => decide (IntKind.min .unsignedInteger32 ≤ (value : Int) ∧
      (value : Int) ≤ IntKind.max .unsignedInteger32)
  | .literal (.unsignedInteger64 value) => decide (IntKind.min .unsignedInteger64 ≤ (value : Int) ∧
      (value : Int) ≤ IntKind.max .unsignedInteger64)
  | .negInteger8 value => decide (IntKind.min .integer8 ≤ -(value : Int) ∧
      -(value : Int) ≤ IntKind.max .integer8)
  | .negInteger16 value => decide (IntKind.min .integer16 ≤ -(value : Int) ∧
      -(value : Int) ≤ IntKind.max .integer16)
  | .negInteger32 value => decide (IntKind.min .integer32 ≤ -(value : Int) ∧
      -(value : Int) ≤ IntKind.max .integer32)
  | .neg type _ => negModeled type
  | .binary op type _ _ => binarySupported op type
  | .call .. => true
  | _ => false

/-- 既知の対象演算は具体規則を持つ。未知の根で RootWarning は成立しない。 -/
theorem target_concrete {source : Expr} {operation : TargetOperation}
    (target : arithmeticOperationAt source = some operation) : concreteRule source = true := by
  cases source <;> simp only [arithmeticOperationAt] at target <;> try contradiction
  case neg type child =>
    simp only [concreteRule, negModeled]
    cases found : IntKind.ofType type with
    | none => simp [found] at target
    | some kind =>
      simp only [found] at target ⊢
      split at target <;> simp_all
  rename_i op type left right
  apply (binarySupported_iff op type).mpr
  split at target
  · assumption
  · contradiction

theorem warning_target_concrete {source : Expr} {operation : TargetOperation}
    (target : WarningOperationSyntax source operation) : concreteRule source = true := by
  cases operation with
  | binary op type => exact target_concrete target
  | neg type => exact target_concrete target
  | standard binding =>
    obtain ⟨_, call⟩ := target
    cases source <;> simp only at call <;> try contradiction
    rfl

/-- 呼び出しの標準束縛も認定できれば、候補の親には未知の評価規則を適用しない。 -/
theorem concreteRule_known {source : Expr} (concrete : concreteRule source = true)
    (env : ConcreteEnv) (type : Ty) (key : OperationKey)
    (callKnown : ∀ callee labels positions arguments,
      source = .call callee labels positions arguments →
      rangeCallBinding env ⟨source, type, key⟩ ≠ none) :
    ¬ UnknownAt env ⟨source, type, key⟩ := by
  cases source <;> simp only [concreteRule] at concrete <;> try contradiction
  case call =>
    have known := callKnown _ _ _ _ rfl
    simpa [UnknownAt, Unsupported, Unmodeled, classify] using known
  all_goals try { simp_all [concreteRule, UnknownAt, Unsupported, Unmodeled, classify] }
  case literal value =>
    cases value <;> simp_all [concreteRule, UnknownAt, Unsupported, Unmodeled, classify]
  case neg type child =>
    unfold negModeled at concrete
    cases found : IntKind.ofType type with
    | none => simp [found] at concrete
    | some kind =>
      simp only [found, decide_eq_true_eq] at concrete
      simp [UnknownAt, Unsupported, Unmodeled, classify, found, concrete]
  case binary op type left right =>
    have supported := (binarySupported_iff op type).mp concrete
    simp [UnknownAt, Unsupported, Unmodeled, classify, supported]

/-- 番号の占有は保ち、範囲からだけ除く。 -/
def outsideSyntacticReach (sources : List Expr) : List (Bool × Expr) :=
  sources.map fun source => (false, source)

mutual
/-- true の印が候補の範囲である。未対応の形の子は false、呼び出しの引数は認定前の候補とする。 -/
def syntacticReachExpr (source : Expr) : List (Bool × Expr) :=
  (concreteRule source, source) :: syntacticReachChildren source

/-- 対応する親と標準呼び出しの候補から、値を解析する子の範囲へ進む。 -/
def syntacticReachChildren : Expr → List (Bool × Expr)
  | .paren child | .constE _ child | .returnE _ child | .not child => syntacticReachExpr child
  | .neg type child =>
      if negModeled type then syntacticReachExpr child
      else outsideSyntacticReach (surfacePreorder child)
  | .binary op type left right =>
      if binarySupported op type then syntacticReachExpr left ++ syntacticReachExpr right
      else outsideSyntacticReach (surfacePreorder left ++ surfacePreorder right)
  | .and left right | .or left right => syntacticReachExpr left ++ syntacticReachExpr right
  | .matchE _ source arms => syntacticReachExpr source ++ syntacticReachArms arms
  | .call callee _ _ args => outsideSyntacticReach (surfacePreorder callee) ++ syntacticReachExprs args
  | .block body => syntacticReachBlock body
  | .ite condition yes no => syntacticReachExpr condition ++ syntacticReachBlock yes ++ syntacticReachBlock no
  | .elseIf condition yes no => syntacticReachExpr condition ++ syntacticReachBlock yes ++ syntacticReachExpr no
  | .ifOnly condition yes => syntacticReachExpr condition ++ syntacticReachBlock yes
  | source => outsideSyntacticReach (surfacePreorder source).tail

/-- 認定された標準呼び出しが使う、ソース順の引数の候補範囲。 -/
def syntacticReachExprs : Exprs → List (Bool × Expr)
  | .nil => []
  | .cons source rest => syntacticReachExpr source ++ syntacticReachExprs rest

/-- Block の容器は番号を持たず、右辺と続きを連ねる。 -/
def syntacticReachBlock : Block → List (Bool × Expr)
  | .empty => []
  | .builderBind _ rest => syntacticReachBlock rest
  | .last source | .lastBind _ _ source | .lastDiscard source | .lastPat _ _ _ source =>
      syntacticReachExpr source
  | .bind _ _ source rest | .discard source rest | .seq source rest | .bindPat _ _ _ source rest =>
      syntacticReachExpr source ++ syntacticReachBlock rest

/-- 腕の guard・本体・後続腕の範囲。到達の存在までは要求しない。 -/
def syntacticReachArms : Arms → List (Bool × Expr)
  | .nil => []
  | .cons _ guard body rest =>
      (match guard with | none => [] | some source => syntacticReachExpr source) ++
        syntacticReachBlock body ++ syntacticReachArms rest
end

@[simp] theorem outsideSyntacticReach_sources (sources : List Expr) :
    (outsideSyntacticReach sources).map Prod.snd = sources := by
  simp [outsideSyntacticReach, List.map_map, Function.comp_def]

mutual
/-- 印を忘れると、未知の内側を含む元の先行順に戻る。 -/
@[simp] theorem syntacticReachExpr_sources (source : Expr) :
    (syntacticReachExpr source).map Prod.snd = surfacePreorder source := by
  rw [syntacticReachExpr, List.map_cons]
  cases source <;> simp only [syntacticReachChildren, List.map_append, syntacticReachExpr_sources,
    syntacticReachBlock_sources, syntacticReachArms_sources, syntacticReachExprs_sources, outsideSyntacticReach_sources, surfacePreorder, List.tail_cons, List.append_eq]
  case neg type child =>
    split <;> simp only [syntacticReachExpr_sources, outsideSyntacticReach_sources]
  case binary op type left right =>
    split <;> simp only [List.map_append, syntacticReachExpr_sources, outsideSyntacticReach_sources]
  all_goals rename_i message; cases message <;> rfl

@[simp] theorem syntacticReachExprs_sources (sources : Exprs) :
    (syntacticReachExprs sources).map Prod.snd = preorderExprs sources := by
  cases sources <;> simp only [syntacticReachExprs, preorderExprs, List.map_append,
    syntacticReachExpr_sources, syntacticReachExprs_sources, List.map_nil]

@[simp] theorem syntacticReachBlock_sources (body : Block) :
    (syntacticReachBlock body).map Prod.snd = preorderBlock body := by
  cases body <;> simp only [syntacticReachBlock, preorderBlock, List.map_append,
    syntacticReachExpr_sources, syntacticReachBlock_sources, List.map_nil]

@[simp] theorem syntacticReachArms_sources (arms : Arms) :
    (syntacticReachArms arms).map Prod.snd = preorderArms arms := by
  cases arms with
  | nil => simp only [syntacticReachArms, preorderArms, List.map_nil]
  | cons alts guard body rest =>
    cases guard <;> simp only [syntacticReachArms, preorderArms, List.map_append,
      syntacticReachExpr_sources, syntacticReachBlock_sources, syntacticReachArms_sources, List.map_nil]
end

@[simp] theorem syntacticReachChildren_sources (source : Expr) :
    (syntacticReachChildren source).map Prod.snd = (surfacePreorder source).tail := by
  have h := congrArg List.tail (syntacticReachExpr_sources source)
  simpa only [syntacticReachExpr, List.map_cons, List.tail_cons] using h

/-- 未知の根では、内側の全出現を親の範囲から除く。 -/
theorem syntacticReachChildren_unknown {source : Expr} (unknown : concreteRule source = false) :
    syntacticReachChildren source = outsideSyntacticReach (surfacePreorder source).tail := by
  cases source <;> simp only [concreteRule] at unknown <;> try contradiction
  all_goals simp only [syntacticReachChildren]
  case neg type child =>
    simp only [unknown, Bool.false_eq_true, ↓reduceIte, surfacePreorder, List.tail_cons]
  case binary op type left right => simp only [unknown, Bool.false_eq_true, ite_false, surfacePreorder, List.tail_cons]

/-- 未知の式自身も、その内側も、親の構文的な到達可能性には入らない。 -/
theorem syntacticReachExpr_unknown {source : Expr} (unknown : concreteRule source = false) :
    syntacticReachExpr source = outsideSyntacticReach (surfacePreorder source) := by
  have shape : surfacePreorder source = source :: (surfacePreorder source).tail := by
    rw [surfacePreorder_children]; rfl
  calc
    syntacticReachExpr source = (false, source) :: outsideSyntacticReach (surfacePreorder source).tail := by
      rw [syntacticReachExpr, unknown, syntacticReachChildren_unknown unknown]
    _ = outsideSyntacticReach (source :: (surfacePreorder source).tail) := rfl
    _ = outsideSyntacticReach (surfacePreorder source) := congrArg outsideSyntacticReach shape.symm

/-- 印付きの列へ、元の先行順と同じ連続番号を付ける。 -/
def numberSyntacticReach (key : OperationKey) : List (Bool × Expr) → List (OperationKey × Bool × Expr)
  | [] => []
  | slot :: rest => (key, slot) :: numberSyntacticReach (advanceKey key 1) rest

theorem numberSyntacticReach_append (key : OperationKey) (xs ys : List (Bool × Expr)) :
    numberSyntacticReach key (xs ++ ys) =
      numberSyntacticReach key xs ++ numberSyntacticReach (advanceKey key xs.length) ys := by
  induction xs generalizing key with
  | nil => simp [numberSyntacticReach]
  | cons x xs ih => simp [numberSyntacticReach, ih, Nat.add_comm]

/-- 同じ元の出現にある対象演算で、根から具体規則だけで辿れること。 -/
def InSyntacticReach (key : OperationKey) (slots : List (Bool × Expr))
    (warning : IntervalWarning) : Prop :=
  ∃ source, (warning.key, true, source) ∈ numberSyntacticReach key slots ∧
    WarningOperationSyntax source warning.operation

/-- 範囲の印を忘れても、元の出現とキーを変えない。 -/
theorem numberSyntacticReach_sources (key : OperationKey) (slots : List (Bool × Expr)) :
    (numberSyntacticReach key slots).map (fun (key, _, source) => (key, source)) =
      numberFrom key (slots.map Prod.snd) := by
  induction slots generalizing key with
  | nil => rfl
  | cons slot rest ih => simp only [numberSyntacticReach, List.map_cons, numberFrom, ih]

/-- 範囲への所属は、元の番号列での位置と対象演算の一致も含む。 -/
theorem InSyntacticReach.located {key slots warning} (inside : InSyntacticReach key slots warning) :
    LocatedIn key (slots.map Prod.snd) warning := by
  obtain ⟨source, member, target⟩ := inside
  refine ⟨source, ?_, target⟩
  rw [← numberSyntacticReach_sources]
  exact List.mem_map.mpr ⟨(warning.key, true, source), member, rfl⟩

/-- 未知の内側を保持する false の列は、警告の位置として認めない。 -/
theorem outsideSyntacticReach_excluded (key : OperationKey) (sources : List Expr) (warning : IntervalWarning) :
    ¬ InSyntacticReach key (outsideSyntacticReach sources) warning := by
  suffices absent : ∀ source, (warning.key, true, source) ∉ numberSyntacticReach key (outsideSyntacticReach sources) by
    intro ⟨source, member, _⟩
    exact absent source member
  induction sources generalizing key with
  | nil => simp [outsideSyntacticReach, numberSyntacticReach]
  | cons source rest ih =>
    simpa only [outsideSyntacticReach, List.map_cons, numberSyntacticReach, List.mem_cons, Prod.mk.injEq,
      Bool.true_eq_false, false_and, and_false, false_or, not_false_eq_true] using ih (advanceKey key 1)

/-- 未知の根の入力では、内側の対象演算も警告の根拠にはしない。 -/
theorem unknown_warning_excluded {source : Expr} (unknown : concreteRule source = false)
    (key : OperationKey) (warning : IntervalWarning) :
    ¬ InSyntacticReach key (syntacticReachExpr source) warning := by
  rw [syntacticReachExpr_unknown unknown]
  exact outsideSyntacticReach_excluded key (surfacePreorder source) warning

/-- 式の入力に対する構文的な到達可能性の契約。評価導出も到達の存在も仮定しない。 -/
def WarningsInSyntacticReach {Parameters : Type}
    (analyze : AbstractEnv → EvalInput → Parameters → AnalysisResult) : Prop :=
  (∀ env input parameters warning, warning ∈ (analyze env input parameters).warnings →
    InSyntacticReach input.key (syntacticReachExpr input.source) warning) ∧ WarningLocated analyze

/-- 構文候補の範囲と、同じ入口の標準束縛による位置の認定を取り出す。 -/
theorem WarningsInSyntacticReach.located {Parameters : Type}
    {analyze : AbstractEnv → EvalInput → Parameters → AnalysisResult}
    (inside : WarningsInSyntacticReach analyze) : WarningLocated analyze := inside.2

/-- 算術の演算を持つ警告には、従来の演算の認定をそのまま保つ。 -/
theorem InSyntacticReach.arithmetic {key slots warning}
    (inside : InSyntacticReach key slots warning)
    (arithmetic : ∀ binding, warning.operation ≠ .standard binding) :
    ∃ source, (warning.key, true, source) ∈ numberSyntacticReach key slots ∧
      arithmeticOperationAt source = some warning.operation := by
  obtain ⟨source, member, operation⟩ := inside
  refine ⟨source, member, ?_⟩
  cases op : warning.operation with
  | binary op type | neg type => simpa only [op, WarningOperationSyntax] using operation
  | standard binding => exact False.elim (arithmetic binding op)

end Benitoite.Interval.BudgetAnalysis
