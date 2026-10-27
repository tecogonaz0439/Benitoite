import Benitoite.Interval.SyntacticReach

/-!
# 標準 call の認定を伴う警告の範囲

構文だけの候補範囲に、元のキーによる認定を加え、未認定 call の内側を除く。
固定域の契約を持つ純粋なシフトの call 自身と、その引数を追加する。
列と述語はいずれも証明用であり、解析器の出力・走査・予算には加えない。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

namespace CallReach

/-- 番号を占める元の列と、その根から親へ返せる警告の述語。 -/
structure Scope where
  sources : List Expr
  allows : OperationKey → IntervalWarning → Prop

def empty : Scope := ⟨[], fun _ _ => False⟩
def outside (sources : List Expr) : Scope := ⟨sources, fun _ _ => False⟩
def root (source : Expr) : Scope := ⟨[source], fun key warning => RootWarning key source warning⟩
/-- 固定域 call 自身の候補は、同じキーで認定した標準束縛に限る。 -/
def callRoot (env : ConcreteEnv) (source : Expr) : Scope :=
  ⟨[source], fun key warning => RootWarning key source warning ∧
    match warning.operation with
    | .standard binding => rangeCallBinding env ⟨source, .base .unit, key⟩ = some binding
    | _ => True⟩

def append (xs ys : Scope) : Scope :=
  ⟨xs.sources ++ ys.sources, fun key warning =>
    xs.allows key warning ∨ ys.allows (advanceKey key xs.sources.length) warning⟩
def gate (known : OperationKey → Prop) (body : Scope) : Scope :=
  ⟨body.sources, fun key warning => known key ∧ body.allows key warning⟩

instance : Append Scope := ⟨append⟩

@[simp] theorem append_sources (xs ys : Scope) : (xs ++ ys).sources = xs.sources ++ ys.sources := rfl
@[simp] theorem append_allows (xs ys : Scope) (key warning) :
    (xs ++ ys).allows key warning ↔ xs.allows key warning ∨
      ys.allows (advanceKey key xs.sources.length) warning := Iff.rfl

@[ext] theorem Scope.ext {xs ys : Scope} (sources : xs.sources = ys.sources)
    (allows : ∀ key warning, xs.allows key warning ↔ ys.allows key warning) : xs = ys := by
  cases xs; cases ys
  cases sources
  congr
  funext key warning
  exact propext (allows key warning)

@[simp] theorem empty_append (xs : Scope) : empty ++ xs = xs := by
  apply Scope.ext
  · simp [empty]
  · intro key warning; simp [empty]

@[simp] theorem append_empty (xs : Scope) : xs ++ empty = xs := by
  apply Scope.ext
  · simp [empty]
  · intro key warning; simp [empty]

theorem append_assoc (xs ys zs : Scope) : (xs ++ ys) ++ zs = xs ++ (ys ++ zs) := by
  apply Scope.ext
  · simp [List.append_assoc]
  · intro key warning; simp [advanceKey_add, or_assoc]

mutual
/-- call は元のキーで認定できる場合だけ引数へ進む。callee は親へ候補を返さない。 -/
def exprTables (env : ConcreteEnv) (source : Expr) : Scope :=
  match source with
  | .call callee _ _ args =>
      gate (fun key => rangeCallBinding env ⟨source, .base .unit, key⟩ ≠ none)
        (callRoot env source ++ outside (surfacePreorder callee) ++ exprsTables env args)
  | source => root source ++ childrenTables env source

def childrenTables (env : ConcreteEnv) : Expr → Scope
  | .paren child | .constE _ child | .returnE _ child | .not child => exprTables env child
  | .neg type child =>
      if negModeled type then exprTables env child else outside (surfacePreorder child)
  | .binary op type left right =>
      if binarySupported op type then exprTables env left ++ exprTables env right
      else outside (surfacePreorder left ++ surfacePreorder right)
  | .and left right | .or left right => exprTables env left ++ exprTables env right
  | .matchE _ source arms => exprTables env source ++ armListTables env arms
  | .block body => blockTables env body
  | .ite condition yes no => exprTables env condition ++ blockTables env yes ++ blockTables env no
  | .elseIf condition yes no => exprTables env condition ++ blockTables env yes ++ exprTables env no
  | .ifOnly condition yes => exprTables env condition ++ blockTables env yes
  | source => outside (surfacePreorder source).tail

def exprsTables (env : ConcreteEnv) : Exprs → Scope
  | .nil => empty
  | .cons source rest => exprTables env source ++ exprsTables env rest

def blockTables (env : ConcreteEnv) : Block → Scope
  | .empty => empty
  | .builderBind _ rest => blockTables env rest
  | .last source | .lastBind _ _ source | .lastDiscard source | .lastPat _ _ _ source => exprTables env source
  | .bind _ _ source rest | .discard source rest | .seq source rest | .bindPat _ _ _ source rest =>
      exprTables env source ++ blockTables env rest

def armListTables (env : ConcreteEnv) : Arms → Scope
  | .nil => empty
  | .cons _ guard body rest =>
      (match guard with | none => empty | some source => exprTables env source) ++
        blockTables env body ++ armListTables env rest
end

mutual
@[simp] theorem exprTables_sources (env : ConcreteEnv) (source : Expr) :
    (exprTables env source).sources = surfacePreorder source := by
  cases source <;> simp only [exprTables, childrenTables, root, callRoot, append_sources, gate, outside,
    exprTables_sources, blockTables_sources, armListTables_sources, exprsTables_sources, surfacePreorder,
    List.singleton_append, List.tail_cons]
  case neg type child => split <;> simp only [exprTables_sources]
  case binary op type left right => split <;> simp only [append_sources, exprTables_sources]
  all_goals rename_i message; cases message <;> rfl

@[simp] theorem exprsTables_sources (env : ConcreteEnv) (sources : Exprs) :
    (exprsTables env sources).sources = preorderExprs sources := by
  cases sources <;> simp only [exprsTables, empty, append_sources, preorderExprs, exprTables_sources, exprsTables_sources]

@[simp] theorem blockTables_sources (env : ConcreteEnv) (body : Block) :
    (blockTables env body).sources = preorderBlock body := by
  cases body <;> simp only [blockTables, empty, append_sources, preorderBlock, exprTables_sources, blockTables_sources]

@[simp] theorem armListTables_sources (env : ConcreteEnv) (arms : Arms) :
    (armListTables env arms).sources = preorderArms arms := by
  cases arms with
  | nil => simp only [armListTables, empty, preorderArms]
  | cons alts guard body rest =>
    cases guard <;> simp only [armListTables, empty, append_sources, preorderArms,
      exprTables_sources, blockTables_sources, armListTables_sources, List.nil_append]
end

abbrev expr (env : AbstractEnv) (source : Expr) : Scope := exprTables (rangeTables env) source
abbrev children (env : AbstractEnv) (source : Expr) : Scope := childrenTables (rangeTables env) source
abbrev exprs (env : AbstractEnv) (source : Exprs) : Scope := exprsTables (rangeTables env) source
abbrev block (env : AbstractEnv) (source : Block) : Scope := blockTables (rangeTables env) source
abbrev armList (env : AbstractEnv) (source : Arms) : Scope := armListTables (rangeTables env) source

@[simp] theorem expr_sources (env : AbstractEnv) (source : Expr) :
    (expr env source).sources = surfacePreorder source := exprTables_sources _ _

@[simp] theorem exprs_sources (env : AbstractEnv) (source : Exprs) :
    (exprs env source).sources = preorderExprs source := exprsTables_sources _ _

@[simp] theorem block_sources (env : AbstractEnv) (source : Block) :
    (block env source).sources = preorderBlock source := blockTables_sources _ _

@[simp] theorem armList_sources (env : AbstractEnv) (source : Arms) :
    (armList env source).sources = preorderArms source := armListTables_sources _ _

/-- 表層の位置と、同じ二表で認定した対象演算との対応。 -/
def ScopeLocated (env : AbstractEnv) (scope : Scope) : Prop :=
  ∀ key warning, scope.allows key warning →
    ∃ source, (warning.key, source) ∈ numberFrom key scope.sources ∧
      targetOperationAt env warning.key source = some warning.operation

private theorem outside_located (env sources) : ScopeLocated env (outside sources) := by
  intro key warning absent
  exact absent.elim

private theorem empty_located (env) : ScopeLocated env empty := outside_located env []

private theorem append_located {env xs ys} (left : ScopeLocated env xs) (right : ScopeLocated env ys) :
    ScopeLocated env (xs ++ ys) := by
  intro key warning member
  rcases member with member | member
  · obtain ⟨source, atSource, target⟩ := left key warning member
    exact ⟨source, by rw [append_sources, numberFrom_append]; exact List.mem_append_left _ atSource, target⟩
  · obtain ⟨source, atSource, target⟩ := right _ warning member
    exact ⟨source, by rw [append_sources, numberFrom_append]; exact List.mem_append_right _ atSource, target⟩

private theorem gate_located {env known scope} (valid : ScopeLocated env scope) :
    ScopeLocated env (gate known scope) := fun key warning member => valid key warning member.2

private theorem root_located (env source)
    (noCall : match source with | .call .. => False | _ => True) : ScopeLocated env (root source) := by
  intro key warning member
  obtain ⟨same, operation⟩ := member
  refine ⟨source, by simp [root, numberFrom, same], ?_⟩
  cases kind : warning.operation with
  | binary op type | neg type =>
    apply arithmetic_target_at (env := env) (key := warning.key)
    simpa only [kind, WarningOperationSyntax] using operation
  | standard binding =>
    simp only [kind, WarningOperationSyntax] at operation
    cases source <;> simp_all

private theorem callRoot_located (env source) : ScopeLocated env (callRoot (rangeTables env) source) := by
  intro key warning member
  obtain ⟨⟨same, operation⟩, known⟩ := member
  refine ⟨source, by simp [callRoot, numberFrom, same], ?_⟩
  cases kind : warning.operation with
  | binary op type | neg type =>
    apply arithmetic_target_at (env := env) (key := warning.key)
    simpa only [kind, WarningOperationSyntax] using operation
  | standard binding =>
    simp only [kind] at known
    rw [same]
    exact call_binding_target known

mutual
/-- 認定された call の束縛は、警告が持つ束縛そのものと一致する。 -/
theorem expr_located (env : AbstractEnv) (source : Expr) : ScopeLocated env (expr env source) := by
  unfold expr
  cases source <;> rw [exprTables] <;> try simp
  case call callee labels positions sources =>
    exact gate_located (append_located (append_located (callRoot_located env _)
      (outside_located env _)) (exprs_located env sources))
  all_goals
    apply append_located
    · apply root_located
      trivial
    · exact children_located env _

theorem children_located (env : AbstractEnv) (source : Expr) : ScopeLocated env (children env source) := by
  cases source <;> simp only [children, childrenTables]
  all_goals first
    | exact expr_located env _
    | exact block_located env _
    | exact exprs_located env _
    | exact outside_located env _
    | exact append_located (expr_located env _) (expr_located env _)
    | exact append_located (expr_located env _) (exprs_located env _)
    | exact append_located (expr_located env _) (arms_located env _)
    | exact append_located (expr_located env _) (block_located env _)
    | exact append_located (append_located (expr_located env _) (block_located env _)) (block_located env _)
    | exact append_located (append_located (expr_located env _) (block_located env _)) (expr_located env _)
    | (split <;> first
        | exact expr_located env _
        | exact append_located (expr_located env _) (expr_located env _)
        | exact outside_located env _)

theorem exprs_located (env : AbstractEnv) (sources : Exprs) : ScopeLocated env (exprs env sources) := by
  unfold exprs
  cases sources with
  | nil => rw [exprsTables]; exact empty_located env
  | cons source rest => rw [exprsTables]; exact append_located (expr_located env source) (exprs_located env rest)

theorem block_located (env : AbstractEnv) (body : Block) : ScopeLocated env (block env body) := by
  unfold block
  cases body <;> rw [blockTables]
  all_goals first
    | exact empty_located env
    | exact block_located env _
    | exact expr_located env _
    | exact append_located (expr_located env _) (block_located env _)

theorem arms_located (env : AbstractEnv) (arms : Arms) : ScopeLocated env (armList env arms) := by
  unfold armList
  cases arms with
  | nil => rw [armListTables]; exact empty_located env
  | cons alts guard body rest =>
    rw [armListTables.eq_def]
    cases guard with
    | none => exact append_located (append_located (empty_located env) (block_located env body)) (arms_located env rest)
    | some source => exact append_located (append_located (expr_located env source) (block_located env body)) (arms_located env rest)
end

/-- 認定した範囲は、構文だけの候補範囲に含まれる。 -/
def Compatible (scope : Scope) (slots : List (Bool × Expr)) : Prop :=
  scope.sources = slots.map Prod.snd ∧
    ∀ key warning, scope.allows key warning → InSyntacticReach key slots warning

private theorem compatible_empty : Compatible empty [] := ⟨rfl, by intros; contradiction⟩
private theorem compatible_outside (sources : List Expr) : Compatible (outside sources) (outsideSyntacticReach sources) :=
  ⟨(outsideSyntacticReach_sources sources).symm, by intros; contradiction⟩

private theorem compatible_root (source : Expr) : Compatible (root source) [(concreteRule source, source)] := by
  refine ⟨rfl, ?_⟩
  intro key warning own
  exact ⟨source, by simp [numberSyntacticReach, own.1, warning_target_concrete own.2], own.2⟩

private theorem compatible_callRoot (env source) : Compatible (callRoot env source) [(concreteRule source, source)] :=
  ⟨rfl, fun key warning own => (compatible_root source).2 key warning own.1⟩

theorem compatible_append {xs ys left right}
    (hx : Compatible xs left) (hy : Compatible ys right) : Compatible (xs ++ ys) (left ++ right) := by
  refine ⟨by simp only [append_sources, List.map_append, hx.1, hy.1], ?_⟩
  intro key warning member
  rcases member with member | member
  · obtain ⟨source, atSource, target⟩ := hx.2 key warning member
    refine ⟨source, ?_, target⟩
    rw [numberSyntacticReach_append]
    exact List.mem_append_left _ atSource
  · have size : xs.sources.length = left.length := by rw [hx.1, List.length_map]
    obtain ⟨source, atSource, target⟩ := hy.2 _ warning member
    refine ⟨source, ?_, target⟩
    rw [numberSyntacticReach_append]
    apply List.mem_append_right
    simpa only [size] using atSource

private theorem compatible_gate {known scope slots} (valid : Compatible scope slots) :
    Compatible (gate known scope) slots := ⟨valid.1, fun key warning own => valid.2 key warning own.2⟩

mutual
theorem expr_compatible (env : AbstractEnv) (source : Expr) : Compatible (expr env source) (syntacticReachExpr source) := by
  unfold expr
  cases source <;> rw [exprTables] <;> try simp
  case call callee labels positions sources =>
    simpa only [syntacticReachExpr, syntacticReachChildren, List.singleton_append, List.append_assoc, List.cons_append, List.nil_append] using
      compatible_gate (compatible_append (compatible_append (compatible_callRoot (rangeTables env) _)
        (compatible_outside (surfacePreorder callee))) (exprs_compatible env sources))
  all_goals
    simpa only [syntacticReachExpr, List.singleton_append] using
      compatible_append (compatible_root _) (children_compatible env _)

theorem children_compatible (env : AbstractEnv) (source : Expr) :
    Compatible (children env source) (syntacticReachChildren source) := by
  cases source <;> simp only [children, childrenTables, syntacticReachChildren]
  case call callee labels positions sources =>
    refine ⟨?_, by intros; contradiction⟩
    simpa only [outside, syntacticReachChildren] using
      (syntacticReachChildren_sources (.call callee labels positions sources)).symm
  all_goals first
    | exact expr_compatible env _
    | exact block_compatible env _
    | exact exprs_compatible env _
    | exact compatible_outside _
    | exact compatible_append (expr_compatible env _) (expr_compatible env _)
    | exact compatible_append (expr_compatible env _) (exprs_compatible env _)
    | exact compatible_append (expr_compatible env _) (arms_compatible env _)
    | exact compatible_append (expr_compatible env _) (block_compatible env _)
    | exact compatible_append (compatible_append (expr_compatible env _) (block_compatible env _)) (block_compatible env _)
    | exact compatible_append (compatible_append (expr_compatible env _) (block_compatible env _)) (expr_compatible env _)
    | (split <;> first
        | exact expr_compatible env _
        | exact compatible_append (expr_compatible env _) (expr_compatible env _)
        | exact compatible_outside _)

 theorem exprs_compatible (env : AbstractEnv) (sources : Exprs) :
    Compatible (exprs env sources) (syntacticReachExprs sources) := by
  unfold exprs
  cases sources with
  | nil => rw [exprsTables, syntacticReachExprs]; exact compatible_empty
  | cons source rest =>
    rw [exprsTables, syntacticReachExprs]
    exact compatible_append (expr_compatible env source) (exprs_compatible env rest)

theorem block_compatible (env : AbstractEnv) (body : Block) :
    Compatible (block env body) (syntacticReachBlock body) := by
  unfold block
  cases body <;> rw [blockTables, syntacticReachBlock]
  all_goals first
    | exact compatible_empty
    | exact block_compatible env _
    | exact expr_compatible env _
    | exact compatible_append (expr_compatible env _) (block_compatible env _)

theorem arms_compatible (env : AbstractEnv) (arms : Arms) :
    Compatible (armList env arms) (syntacticReachArms arms) := by
  unfold armList
  cases arms with
  | nil => rw [armListTables, syntacticReachArms]; exact compatible_empty
  | cons alts guard body rest =>
    rw [armListTables.eq_def, syntacticReachArms.eq_def]
    cases guard <;> dsimp only
    case none => exact compatible_append (compatible_append compatible_empty (block_compatible env body)) (arms_compatible env rest)
    case some source => exact compatible_append (compatible_append (expr_compatible env source) (block_compatible env body)) (arms_compatible env rest)
end

end CallReach
end Benitoite.Interval.BudgetAnalysis
