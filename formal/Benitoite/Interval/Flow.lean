import Benitoite.Interval.Environment

/-!
# 整数の束縛・比較と分岐・短絡の合成

同型の定数と局所参照の区間を保存し、比較した一位置だけを絞り込む。
端点の加減算は数学上の Int で行う
（設計書 01-12「区間解析の束縛保存と単一比較」）。
分岐では条件と到達可能な各枝を一回ずつ解析し、正常値だけを合流する
（設計書 01-12「区間解析の単一ifと正常値の合流」）。
否定と複合条件の真偽環境は、経路を列挙せず各位置の凸包へ合流する
（設計書 01-12「区間解析の短絡と複合条件」）。
整数パターンと正常区間を交差し、slots の選択と反転で腕入口を作る
（設計書 01-12「区間解析のIntegerパターンと腕入口」）。
guard の真の環境を腕の本体だけへ渡し、return の後の正常値を消す
（設計書 01-12「区間解析のguardとreturnの局所規則」）。
-/
namespace Benitoite.Interval
open Benitoite.Release Benitoite.Surface

/-- 型検査済みの Integer64 定数だけを読む。局所値を定数として逆算しない。 -/
def integerConstant : Expr → Option Int
  | .literal (.integer value) => some value.toValue.toInt
  | .negInt value => some value.negValue.toInt
  | .constE (.base .integer) value | .paren value => integerConstant value
  | _ => none

/-- 局所位置と定数の同型の正常値を読む。それ以外は全値域に退く。 -/
def atomRange (env : AbstractEnv) : Expr → Interval
  | .literal (.integer value) => normalize value.toValue.toInt value.toValue.toInt
  | .negInt value => normalize value.negValue.toInt value.negValue.toInt
  | .local index => integerAt env index
  | .constE (.base .integer) value => atomRange (clearLocals env) value
  | .paren value => atomRange env value
  | _ => top

/-- 読み取れた定数は、評価関係の任意の正常整数結果と一致する。 -/
theorem integerConstant_sound {env input value trace constant}
    (eval : EvalPartial env input (.normal (.integer value)) trace)
    (known : integerConstant input.source = some constant) : value.toInt = constant := by
  generalize outcomeEq : EvalOutcome.normal (.integer value) = outcome at eval
  cases eval <;> simp_all [integerConstant]
  case unknownNormal output unsupported typed =>
    cases input with
    | mk source type key =>
        cases source <;> simp_all [integerConstant, UnknownAt, Unsupported, Unmodeled, classify]
        all_goals rename_i literal; cases literal <;> simp_all [integerConstant]
  case paren key source type child =>
    cases outcomeEq
    exact integerConstant_sound (input := ⟨source, type, childKey key []⟩) child known
  case constE key source type child =>
    cases type <;> try simp_all [integerConstant]
    rename_i base
    cases base <;> simp_all [integerConstant]
    cases outcomeEq
    exact integerConstant_sound (env := { env with locals := [] })
      (input := ⟨source, .base .integer, childKey key []⟩) child known
termination_by surfaceSize input.source
decreasing_by all_goals simp_all

/-- 同じ型のリテラル・const・参照の区間は、正常な具体整数を失わない。 -/
theorem atomRange_sound {abstract concrete input value trace}
    (models : Models abstract concrete)
    (eval : EvalPartial concrete input (.normal (.integer value)) trace) :
    Mem value.toInt (atomRange abstract input.source) := by
  generalize outcomeEq : EvalOutcome.normal (.integer value) = outcome at eval
  cases eval <;> try cases outcomeEq
  all_goals first
    | exact (mem_top _).mpr value.toInt_bounds
    | skip
  case integer | negInt =>
    apply (mem_normalize _ _ _).mpr
    exact ⟨(Integer64Value.toInt_bounds _).1,
      (Integer64Value.toInt_bounds _).2, Int.le_refl _, Int.le_refl _⟩
  case «local» => exact integerAt_sound models (by assumption)
  case paren key source type child =>
    exact atomRange_sound (input := ⟨source, type, childKey key []⟩) models child
  case constE key source type child =>
    cases type <;> simp only [atomRange] <;>
      try exact (mem_top _).mpr value.toInt_bounds
    rename_i base
    cases base <;> simp only [atomRange] <;>
      try exact (mem_top _).mpr value.toInt_bounds
    exact atomRange_sound (abstract := clearLocals abstract) (concrete := { concrete with locals := [] })
      (input := ⟨source, .base .integer, childKey key []⟩) (models_clearLocals models) child
  case unknownNormal unsupported typed =>
    have unknown : atomRange abstract input.source = top := by
      cases input with
      | mk source type key =>
          cases source <;> simp_all [atomRange, UnknownAt, Unsupported, Unmodeled, classify]
          all_goals rename_i literal; cases literal <;> simp_all [atomRange]
    rw [unknown]
    exact (mem_top _).mpr value.toInt_bounds
termination_by surfaceSize input.source
decreasing_by all_goals simp_all

/-- 原子式を右辺に持つbind/shadowは、正常に得た整数を新しい位置へ保存する。 -/
theorem models_bindAtom {abstract concrete input value trace} (kind : BindKind)
    (models : Models abstract concrete)
    (eval : EvalPartial concrete input (.normal (.integer value)) trace) :
    Models (bindRange kind abstract (.base .integer) (atomRange abstract input.source))
      { concrete with locals := some (.integer value) :: concrete.locals } :=
  models_bindRange kind value models (atomRange_sound models eval)

/-- 左右を入れ替えて局所参照を左に揃える。 -/
def Comparison.reverse : Comparison → Comparison
  | .eq => .eq | .ne => .ne | .lt => .gt | .le => .ge | .gt => .lt | .ge => .le

/-- 偽枝は反対の比較の真枝として扱う。 -/
def Comparison.complement : Comparison → Comparison
  | .eq => .ne | .ne => .eq | .lt => .ge | .le => .gt | .gt => .le | .ge => .lt

/-- 左右反転しても比較結果は変わらない。 -/
theorem Comparison.reverse_holds (op : Comparison) (x k : Int) :
    op.reverse.Holds x k ↔ op.Holds k x := by
  cases op <;> simp [Comparison.reverse, Comparison.Holds, eq_comm]

/-- 偽枝の比較は元の比較の否定と一致する。 -/
theorem Comparison.complement_holds (op : Comparison) (x k : Int) :
    op.complement.Holds x k ↔ ¬ op.Holds x k := by
  cases op <;> simp [Comparison.complement, Comparison.Holds] <;> omega

/-- 不等値の穴は表せないので、端点の場合だけ一点を取り除く。 -/
def excludePoint : Interval → Int → Interval
  | .bottom, _ => .bottom
  | .closed lo hi valid, k =>
      if lo = k then normalize (lo + 1) hi
      else if hi = k then normalize lo (hi - 1)
      else .closed lo hi valid

/-- 除いた一点以外の具体値は、端点の縮小や穴の近似で失わない。 -/
theorem excludePoint_sound {range value k} (inside : Mem value range) (different : value ≠ k) :
    Mem value (excludePoint range k) := by
  have bounds := mem_bounds inside
  cases range with
  | bottom => contradiction
  | closed lo hi valid =>
      simp only [Mem] at inside
      simp only [excludePoint]
      split
      · rw [mem_normalize]; omega
      · split
        · rw [mem_normalize]; omega
        · exact inside

/-- 不等値による近似は、元の正常値の集合を広げない。 -/
theorem excludePoint_subset (range : Interval) (k : Int) :
    Subset (excludePoint range k) range := by
  apply (subset_iff _ _).mpr
  intro value inside
  cases range with
  | bottom => exact inside
  | closed lo hi valid =>
      simp only [excludePoint] at inside
      split at inside
      · rw [mem_normalize] at inside
        simp only [Mem]
        omega
      · split at inside
        · rw [mem_normalize] at inside
          simp only [Mem]
          omega
        · exact inside

/-- 真枝の区間。k±1を型域内へ交差させるので、端でのあふれは生じない。 -/
def refineTrue (op : Comparison) (range : Interval) (k : Int) : Interval :=
  match op with
  | .eq => meet range (normalize k k)
  | .ne => excludePoint range k
  | .lt => meet range (normalize min64 (k - 1))
  | .le => meet range (normalize min64 k)
  | .gt => meet range (normalize (k + 1) max64)
  | .ge => meet range (normalize k max64)

/-- 真となった比較で絞っても、その具体値は失われない。 -/
theorem refineTrue_sound {op range k value} (inside : Mem value range)
    (condition : op.Holds value k) : Mem value (refineTrue op range k) := by
  have bounds := mem_bounds inside
  cases op with
  | ne => exact excludePoint_sound inside condition
  | eq | lt | le | gt | ge =>
      apply (mem_meet _ _ _).mpr
      refine ⟨inside, ?_⟩
      rw [mem_normalize]
      simp only [Comparison.Holds] at condition
      simp only [IntKind.min, IntKind.max] at *
      omega

/-- 真偽の指定を一つの絞り込み規則へまとめる。 -/
def refineRange (op : Comparison) (range : Interval) (k : Int) (truth : Bool) : Interval :=
  refineTrue (if truth then op else op.complement) range k

/-- どちらの枝でも正常値の所属を保存する。 -/
theorem refineRange_sound {op range k value truth} (inside : Mem value range)
    (condition : op.Holds value k ↔ truth = true) :
    Mem value (refineRange op range k truth) := by
  cases truth with
  | true => exact refineTrue_sound inside (condition.mpr rfl)
  | false =>
      apply refineTrue_sound inside
      exact (Comparison.complement_holds _ _ _).mpr (by simpa using condition)

/-- 枝での絞り込みは、元の区間を包含する方向へ広げない。 -/
theorem refineRange_subset (op : Comparison) (range : Interval) (k : Int) (truth : Bool) :
    Subset (refineRange op range k truth) range := by
  unfold refineRange
  generalize (if truth then op else op.complement) = selected
  cases selected with
  | ne => exact excludePoint_subset range k
  | eq | lt | le | gt | ge =>
      apply (subset_iff _ _).mpr
      intro value inside
      exact ((mem_meet _ _ _).mp inside).1

/-- 一つの局所位置と同型の定数の比較。 -/
structure LocalComparison where
  index : Nat
  op : Comparison
  constant : Int
  deriving DecidableEq, Repr

/-- 括弧の中の直接参照だけを認め、式の逆算や二変数の関係を作らない。 -/
def localIndex : Expr → Option Nat
  | .local index => some index
  | .paren value => localIndex value
  | _ => none

/-- 比較の型はInteger64だけとし、右にある局所参照は演算を反転する。 -/
def comparisonAt : Expr → Option LocalComparison
  | .paren value => comparisonAt value
  | .binary op (.base .integer) left right => do
      let comparison ← Comparison.ofBinOp op
      match localIndex left, integerConstant right with
      | some index, some constant => some ⟨index, comparison, constant⟩
      | _, _ => do
          let index ← localIndex right
          let constant ← integerConstant left
          some ⟨index, comparison.reverse, constant⟩
  | _ => none

/-- 比較した一位置の区間だけを更新する。 -/
def refineEnv (env : AbstractEnv) (comparison : LocalComparison) (truth : Bool) : AbstractEnv :=
  narrowAt env comparison.index
    (refineRange comparison.op (integerAt env comparison.index) comparison.constant truth)

/-- 実際の比較結果を満たす具体環境は、絞り込み後も対応する。 -/
theorem models_refineEnv {abstract concrete comparison truth value}
    (models : Models abstract concrete)
    (atIndex : concrete.locals[comparison.index]? = some (some (.integer value)))
    (condition : comparison.op.Holds value.toInt comparison.constant ↔ truth = true) :
    Models (refineEnv abstract comparison truth) concrete :=
  models_narrowAt models atIndex (refineRange_sound (integerAt_sound models atIndex) condition)

/-- 別名も古いshadowも、比較した番号でなければ元の区間のままである。 -/
theorem lookup_refineEnv_other (env : AbstractEnv) (comparison : LocalComparison)
    (truth : Bool) (other : Nat) (different : other ≠ comparison.index) :
    lookup (refineEnv env comparison truth) other = lookup env other :=
  lookup_narrowAt_other _ _ _ _ different

/-- 表層が持つ任意のNatから、型域内の定数だけを認定する。 -/
def boundedKindConstant (kind : IntKind) (value : Int) : Option Int :=
  if kind.min ≤ value ∧ value ≤ kind.max then some value else none

/-- 同じ種類のリテラルと閉じた定数だけを読む。局所値の逆算は行わない。 -/
def integerKindConstant (kind : IntKind) : Expr → Option Int
  | .literal value => match kind, value with
    | .integer64, .integer value => some value.toValue.toInt
    | .integer8, .integer8 value | .integer16, .integer16 value
    | .integer32, .integer32 value | .unsignedInteger16, .unsignedInteger16 value
    | .unsignedInteger32, .unsignedInteger32 value
    | .unsignedInteger64, .unsignedInteger64 value => boundedKindConstant kind (value : Int)
    | _, _ => none
  | .negInt value => if kind = .integer64 then some value.negValue.toInt else none
  | .negInteger8 value => if kind = .integer8 then boundedKindConstant kind (-(value : Int)) else none
  | .negInteger16 value => if kind = .integer16 then boundedKindConstant kind (-(value : Int)) else none
  | .negInteger32 value => if kind = .integer32 then boundedKindConstant kind (-(value : Int)) else none
  | .constE type child => if IntKind.ofType type = some kind then integerKindConstant kind child else none
  | .paren child => integerKindConstant kind child
  | _ => none

/-- 認定した種類付き定数は、その式の任意の正常な具体整数と一致する。 -/
theorem integerKindConstant_sound {kind : IntKind} {env input trace constant}
    {value : IntegerValue kind}
    (eval : EvalPartial env input (.normal (.ofInteger kind value)) trace)
    (known : integerKindConstant kind input.source = some constant) : value.toInt = constant := by
  generalize outcomeEq : EvalOutcome.normal (.ofInteger kind value) = outcome at eval
  cases eval <;> try simp only [integerKindConstant] at known
  all_goals try contradiction
  case unknownNormal output unsupported typed =>
    cases input with
    | mk source type key =>
      cases source <;> simp_all [integerKindConstant, UnknownAt, Unsupported, Unmodeled, classify]
      case literal literal =>
        cases literal <;> cases kind <;> simp_all [boundedKindConstant]
        all_goals omega
      all_goals cases kind <;> simp_all [boundedKindConstant]
      all_goals omega
  case paren key source type child =>
    cases outcomeEq
    exact integerKindConstant_sound child known
  case constE key source type child =>
    split at known
    · cases outcomeEq
      exact integerKindConstant_sound child known
    · contradiction
  all_goals
    cases kind <;> simp_all [boundedKindConstant,
      ConcreteValue.ofInteger, IntegerValue.toInt, Integer64Value.toInt]
termination_by surfaceSize input.source
decreasing_by all_goals simp_all

/-- 一つの局所位置と同じ種類の定数の比較。 -/
structure KindLocalComparison where
  kind : IntKind
  index : Nat
  op : Comparison
  constant : Int
  deriving DecidableEq, Repr

/-- 六幅の比較だけを追加認定し、Integer64の既存の入口と分ける。 -/
def comparisonKindAt : Expr → Option KindLocalComparison
  | .paren child => comparisonKindAt child
  | .binary op type left right => do
      let kind ← IntKind.ofType type
      if kind = .integer64 then none else do
        let comparison ← Comparison.ofBinOp op
        match localIndex left, integerKindConstant kind right with
        | some index, some constant => some ⟨kind, index, comparison, constant⟩
        | _, _ => do
            let index ← localIndex right
            let constant ← integerKindConstant kind left
            some ⟨kind, index, comparison.reverse, constant⟩
  | _ => none

/-- 穴は端点の場合だけ除き、数学上の整数で境界を計算する。 -/
def excludeKindPoint {kind : IntKind} : Interval kind → Int → Interval kind
  | .bottom, _ => .bottom
  | .closed lo hi valid, value =>
      if lo = value then normalize (lo + 1) hi kind
      else if hi = value then normalize lo (hi - 1) kind
      else .closed lo hi valid

/-- 除いた一点以外の具体値を、種類付きの近似から失わない。 -/
theorem excludeKindPoint_sound {kind : IntKind} {range : Interval kind} {value constant}
    (inside : Mem value range) (different : value ≠ constant) :
    Mem value (excludeKindPoint range constant) := by
  have bounds := mem_bounds inside
  cases range with
  | bottom => contradiction
  | closed lo hi valid =>
      simp only [Mem] at inside
      simp only [excludeKindPoint]
      split
      · rw [mem_normalize _ _ _ kind]; omega
      · split
        · rw [mem_normalize _ _ _ kind]; omega
        · exact inside

/-- 指定した型の全値域と交差し、端の加減算をホスト幅へ丸めない。 -/
def refineKindTrue {kind : IntKind} (op : Comparison) (range : Interval kind)
    (constant : Int) : Interval kind :=
  match op with
  | .eq => meet range (normalize constant constant kind)
  | .ne => excludeKindPoint range constant
  | .lt => meet range (normalize kind.min (constant - 1) kind)
  | .le => meet range (normalize kind.min constant kind)
  | .gt => meet range (normalize (constant + 1) kind.max kind)
  | .ge => meet range (normalize constant kind.max kind)

/-- 同じ種類の比較が真なら、絞り込み後もその具体整数を含む。 -/
theorem refineKindTrue_sound {kind : IntKind} {op} {range : Interval kind} {constant value}
    (inside : Mem value range) (condition : op.Holds value constant) :
    Mem value (refineKindTrue op range constant) := by
  have bounds := mem_bounds inside
  cases op with
  | ne => exact excludeKindPoint_sound inside condition
  | eq | lt | le | gt | ge =>
      apply (mem_meet _ _ _).mpr
      refine ⟨inside, ?_⟩
      rw [mem_normalize _ _ _ kind]
      simp only [Comparison.Holds] at condition
      omega

/-- 種類付きの真偽の絞り込み。 -/
def refineKindRange {kind : IntKind} (op : Comparison) (range : Interval kind)
    (constant : Int) (truth : Bool) : Interval kind :=
  refineKindTrue (if truth then op else op.complement) range constant

/-- 真偽のどちらの経路でも具体整数を失わない。 -/
theorem refineKindRange_sound {kind : IntKind} {op} {range : Interval kind} {constant value truth}
    (inside : Mem value range) (condition : op.Holds value constant ↔ truth = true) :
    Mem value (refineKindRange op range constant truth) := by
  cases truth with
  | true => exact refineKindTrue_sound inside (condition.mpr rfl)
  | false =>
      apply refineKindTrue_sound inside
      exact (Comparison.complement_holds _ _ _).mpr (by simpa using condition)

/-- 認定した幅の一位置だけを絞り、同定表と別名の事実を保つ。 -/
def refineKindEnv (env : AbstractEnv) (comparison : KindLocalComparison) (truth : Bool) : AbstractEnv :=
  narrowKindAt env comparison.kind comparison.index
    (refineKindRange comparison.op (integerKindAt env comparison.kind comparison.index)
      comparison.constant truth)

/-- 比較の実際の結果に従う環境は、種類付き絞り込み後も対応する。 -/
theorem models_refineKindEnv {abstract concrete comparison truth}
    {value : IntegerValue comparison.kind} (models : Models abstract concrete)
    (atIndex : concrete.locals[comparison.index]? = some (some (.ofInteger comparison.kind value)))
    (condition : comparison.op.Holds value.toInt comparison.constant ↔ truth = true) :
    Models (refineKindEnv abstract comparison truth) concrete :=
  models_narrowKindAt models atIndex
    (refineKindRange_sound (integerKindAt_sound models atIndex) condition)

/-- 選択した番号以外への逆伝播は、整数の種類を増やしても行わない。 -/
theorem lookup_refineKindEnv_other (env : AbstractEnv) (comparison : KindLocalComparison)
    (truth : Bool) (other : Nat) (different : other ≠ comparison.index) :
    lookup (refineKindEnv env comparison truth) other = lookup env other :=
  lookup_narrowKindAt_other _ _ _ _ _ different

/-- Integer64 のリテラル・負号・整数の両端だけを区間にする。
他の幅の Const を持つ範囲や構造の内部から事実を作らない。 -/
def integerPatternRange : Pattern → Interval
  | .integer value => normalize value.toValue.toInt value.toValue.toInt
  | .negInt value => normalize value.negValue.toInt value.negValue.toInt
  | .range (.integer lo) (.integer hi) => normalize lo.toInt hi.toInt
  | _ => top

/-- コアの整数パターンの実際の照合成功から、区間への所属を得る。
照合の成功を区間から逆に導かず、網羅性判定には使わない。 -/
theorem integerPatternRange_sound {pattern value bindings}
    (matched : pattern.toCore.matchVal (.const (.integer value)) = some bindings) :
    Mem value.toInt (integerPatternRange pattern) := by
  have bounds := value.toInt_bounds
  cases pattern with
  | integer literal | negInt literal =>
    simp [Pattern.toCore, Pat.matchVal, Const.matches] at matched
    simp only [integerPatternRange, mem_normalize]
    exact ⟨bounds.1, bounds.2, by omega, by omega⟩
  | range lo hi =>
    cases lo <;> cases hi <;>
      simp_all [Pattern.toCore, Pat.matchVal, Const.inRange, integerPatternRange]
    rw [mem_normalize]
    exact ⟨bounds.1, bounds.2, matched.1.1, matched.1.2⟩
  | _ => exact (mem_top _).mpr bounds

/-- 整数の照合に成功したパターンの束縛は、照合した整数そのものだけを持つ。
構造の内部の値を整数と見なす仮定は加えない。 -/
theorem integerPatternLocals_values {pattern value bindings} {raw : List ConcreteValue}
    (matched : pattern.toCore.matchVal (.const (.integer value)) = some bindings)
    (locals : PatternLocals pattern (.integer value) raw.reverse) :
    ∀ bound ∈ raw, bound = .integer value := by
  have locals := patternLocals_reverse.mp locals
  cases pattern <;>
    simp_all [PatternLocals, Pattern.binders, Pattern.toCore, Pat.binders, Pat.matchVal]

/-- 同じ幅の整数だけをパターンの区間と交差する。その他の型は未知とする。 -/
def matchRange (type : Ty) (normal : Interval) (pattern : Pattern) : Interval :=
  match type with
  | .base .integer => meet normal (integerPatternRange pattern)
  | _ => top

/-- 照合対象が直接の局所参照ならその位置だけを絞る。束縛追加より先に行う。 -/
def matchScrutineeEnv (env : AbstractEnv) (source : Expr) (type : Ty)
    (range : Interval) : AbstractEnv :=
  match type with
  | .base .integer =>
    match localIndex source with
    | some index => narrowAt env index range
    | none => env
  | _ => env

/-- 同じ照合値を持つ具体環境との対応を、局所参照の絞り込み後も保つ。 -/
theorem models_matchScrutineeEnv {abstract concrete source range value}
    (models : Models abstract concrete) (inside : Mem value.toInt range)
    (atLocal : ∀ index, localIndex source = some index →
      concrete.locals[index]? = some (some (.integer value))) :
    Models (matchScrutineeEnv abstract source (.base .integer) range) concrete := by
  simp only [matchScrutineeEnv]
  cases recognized : localIndex source with
  | none => exact models
  | some index => exact models_narrowAt models (atLocal index recognized) inside

/-- 一つの選択肢の腕入口。Integer64 の空の交差では束縛も追加しない。 -/
def matchAlternativeEnv (env : AbstractEnv) (source : Expr) (type : Ty)
    (normal : Interval) (alt : Alternative) : Option AbstractEnv :=
  let range := matchRange type normal alt.pat
  let extended := extendMatchSlots (matchScrutineeEnv env source type range)
    (matchPatternSlots alt.pat type range) alt.slots
  match type with
  | .base .integer => if range = .bottom then none else extended
  | _ => extended

/-- 正常な整数の照合成功と束縛の対応から、同じ値を失わない腕入口を得る。 -/
theorem models_matchAlternativeEnv {abstract concrete source normal alt value selected bindings}
    {raw : List ConcreteValue}
    (models : Models abstract concrete) (inside : Mem value.toInt normal)
    (matched : alt.pat.toCore.matchVal (.const (.integer value)) = some bindings)
    (atLocal : ∀ index, localIndex source = some index →
      concrete.locals[index]? = some (some (.integer value)))
    (locals : PatternLocals alt.pat (.integer value) raw.reverse)
    (chosen : selectSlots raw alt.slots = some selected) :
    ∃ inner, matchAlternativeEnv abstract source (.base .integer) normal alt = some inner ∧
      Models inner { concrete with locals := selected.reverse.map some ++ concrete.locals } := by
  have member : Mem value.toInt (matchRange (.base .integer) normal alt.pat) :=
    (mem_meet _ _ _).mpr ⟨inside, integerPatternRange_sound matched⟩
  have live : matchRange (.base .integer) normal alt.pat ≠ .bottom := by
    intro empty; rw [empty] at member; exact member
  obtain ⟨inner, entry, related⟩ := models_extendMatchSlots
    (models_matchScrutineeEnv models member atLocal)
    (matchPatternSlots_models rfl (by intro integer equal; cases equal; exact member) locals) chosen
  exact ⟨inner, by simpa [matchAlternativeEnv, live, ConcreteValue.type] using entry, related⟩

/-- Integer64は区間、Booleanは偽・真の可能性、それ以外は正常値の有無を持つ。 -/
def NormalRange : Ty → Type
  | .base .integer => Interval
  | .base .boolean => Bool × Bool
  | _ => Bool

/-- 正常値のない結果。失敗やreturnの有無は、この値だけからは決めない。 -/
def emptyNormal (type : Ty) : NormalRange type := by
  cases type with
  | base base =>
    cases base with
    | integer => exact .bottom
    | boolean => exact (false, false)
    | _ => exact false
  | _ => exact false

/-- 正常な任意の型内の値を許す。未知と正常値なしを区別する。 -/
def topNormal (type : Ty) : NormalRange type := by
  cases type with
  | base base =>
    cases base with
    | integer => exact top
    | boolean => exact (true, true)
    | _ => exact true
  | _ => exact true

/-- 型に応じた正常値の範囲の条件。型の一致はNormalMemが別に要求する。 -/
def NormalContains (type : Ty) (range : NormalRange type) (value : ConcreteValue) : Prop := by
  cases type with
  | base base =>
    cases base with
    | integer => exact (match value with
        | .integer integer => Mem integer.toInt range
        | _ => False)
    | boolean => exact (match value with
        | .boolean false => range.1 = true
        | .boolean true => range.2 = true
        | _ => False)
    | _ => exact (range = true)
  | _ => exact (range = true)

/-- 正常値の所属。unitを整数のBottomと混同せず、型の一致を保つ。 -/
def NormalMem (type : Ty) (range : NormalRange type) (value : ConcreteValue) : Prop :=
  value.type = type ∧ NormalContains type range value

/-- 同じ型の正常値を合流する。整数の穴と枝ごとの相関は保持しない。 -/
def joinNormal (type : Ty) (left right : NormalRange type) : NormalRange type := by
  cases type with
  | base base =>
    cases base with
    | integer => exact join left right
    | boolean => exact (left.1 || right.1, left.2 || right.2)
    | _ => exact (left || right)
  | _ => exact (left || right)

/-- 合流はどちらかの枝の正常値を失わない。 -/
theorem joinNormal_sound {type left right value}
    (inside : NormalMem type left value ∨ NormalMem type right value) :
    NormalMem type (joinNormal type left right) value := by
  obtain ⟨typed, inside⟩ : value.type = type ∧
      (NormalContains type left value ∨ NormalContains type right value) := by
    rcases inside with ⟨typed, inside⟩ | ⟨typed, inside⟩
    · exact ⟨typed, Or.inl inside⟩
    · exact ⟨typed, Or.inr inside⟩
  refine ⟨typed, ?_⟩
  cases type with
  | base base =>
    cases base with
    | integer =>
      cases value <;> simp_all [NormalContains, joinNormal]
      exact mem_join inside
    | boolean =>
      change Bool × Bool at left right
      cases value with
      | boolean truth =>
        cases truth with
        | false =>
          change left.1 = true ∨ right.1 = true at inside
          exact Bool.or_eq_true_iff.mpr inside
        | true =>
          change left.2 = true ∨ right.2 = true at inside
          exact Bool.or_eq_true_iff.mpr inside
      | _ => simp_all [NormalContains]
    | _ =>
      change Bool at left right
      change left = true ∨ right = true at inside
      exact Bool.or_eq_true_iff.mpr inside
  | _ =>
    change Bool at left right
    change left = true ∨ right = true at inside
    exact Bool.or_eq_true_iff.mpr inside

/-- 枝の正常値、失敗可能性、警告。戻り値は正常値へ合流しない。 -/
structure FlowApprox (type : Ty) where
  normal : NormalRange type
  mayFail : Bool
  warnings : List IntervalWarning

/-- 未到達の枝は解析せず、この結果を合流の単位元として使う。 -/
def unreachableFlow (type : Ty) : FlowApprox type := ⟨emptyNormal type, false, []⟩

/-- 未対応の枝は型内の任意値・失敗可能・新警告なしとする。 -/
def unknownFlow (type : Ty) : FlowApprox type := ⟨topNormal type, true, []⟩

/-- 中心命題で使う既存の出力へ写す。 -/
def FlowApprox.toAnalysis {type : Ty} (result : FlowApprox type) : AnalysisResult :=
  ⟨NormalMem type result.normal, result.mayFail, result.warnings⟩

/-- 元の位置の種類を保ち、二つの枝の整数区間だけを凸包で合流する。 -/
def hullSlots : List AbstractSlot → List AbstractSlot → List AbstractSlot → List AbstractSlot
  | [], _, _ => []
  | slot :: rest, left, right =>
      (match slot with
        | .integer _ => .integer (join (integerAt (AbstractEnv.ofLocals left) 0)
            (integerAt (AbstractEnv.ofLocals right) 0))
        | .integerKind kind _ => .integerKind kind
            (join (integerKindAt (AbstractEnv.ofLocals left) kind 0)
              (integerKindAt (AbstractEnv.ofLocals right) kind 0))
        | _ => slot) :: hullSlots rest (left.drop 1) (right.drop 1)

/-- 合流は元の環境の同定表を保存する。 -/
def hullEnv (base left right : AbstractEnv) : AbstractEnv :=
  { base with locals := hullSlots base.locals left.locals right.locals, ranges := base.ranges.forget }

/-- 片方の枝を表す具体環境は、凸包による合流後も失わない。 -/
theorem models_hullEnv {base left right concrete} (models : Models base concrete)
    (branch : Models left concrete ∨ Models right concrete) :
    Models (hullEnv base left right) concrete := by
  have member : ∀ index value,
      concrete.locals[index]? = some (some (.integer value)) →
      Mem value.toInt (join (integerAt left index) (integerAt right index)) := by
    intro index value atIndex
    apply mem_join
    exact branch.elim (fun h => Or.inl (integerAt_sound h atIndex))
      (fun h => Or.inr (integerAt_sound h atIndex))
  have memberKind : ∀ (index : Nat) (kind : IntKind) (value : IntegerValue kind),
      concrete.locals[index]? = some (some (.ofInteger kind value)) →
      Mem value.toInt (join (integerKindAt left kind index) (integerKindAt right kind index)) := by
    intro index kind value atIndex
    apply mem_join
    exact branch.elim (fun h => Or.inl (integerKindAt_sound h atIndex))
      (fun h => Or.inr (integerKindAt_sound h atIndex))
  clear branch
  simp only [integerAt, lookup] at member
  simp only [integerKindAt, lookup] at memberKind
  refine ⟨?_, models.2⟩
  have models := models.1
  change LocalsModels (hullSlots base.locals left.locals right.locals) concrete.locals
  generalize base.locals = slots at models ⊢
  generalize left.locals = leftSlots at member memberKind ⊢
  generalize right.locals = rightSlots at member memberKind ⊢
  generalize concrete.locals = values at models member memberKind ⊢
  induction models generalizing leftSlots rightSlots with
  | nil => exact .nil
  | @cons slot value slots values related rest ih =>
    refine .cons ?_ (ih (leftSlots := leftSlots.drop 1) (rightSlots := rightSlots.drop 1) ?_ ?_)
    · cases slot with
      | integer range =>
        cases value with
        | none => contradiction
        | some value =>
          cases value <;> try contradiction
          exact member 0 _ rfl
      | integerKind kind range =>
        cases value with
        | none => contradiction
        | some value =>
          obtain ⟨integer, same, inside⟩ := related
          exact ⟨integer, same, memberKind 0 kind integer (by simpa only [List.getElem?_cons_zero, same])⟩
      | unknown | builder | unavailable => exact related
    · intro index value atIndex
      have h := member (index + 1) value atIndex
      simpa [integerAt, lookup, AbstractEnv.ofLocals, List.getElem?_drop, Nat.add_comm] using h
    · intro index kind value atIndex
      have h := memberKind (index + 1) kind value atIndex
      simpa [integerKindAt, lookup, AbstractEnv.ofLocals, List.getElem?_drop, Nat.add_comm] using h

/-- 到達不能は合流の単位元であり、到達経路の列を保持しない。 -/
def joinConditionEnvs (base : AbstractEnv) : Option AbstractEnv → Option AbstractEnv → Option AbstractEnv
  | none, right => right
  | left, none => left
  | some left, some right => some (hullEnv base left right)

/-- 合流で由来を捨て、単独の到達経路ではその対応を保つ。 -/
theorem ranges_joinConditionEnvs {base left right concrete}
    (branch : (∃ env, left = some env ∧ env.ranges.Models concrete) ∨
      (∃ env, right = some env ∧ env.ranges.Models concrete)) :
    ∃ env, joinConditionEnvs base left right = some env ∧ env.ranges.Models concrete := by
  cases left <;> cases right <;> simp only [joinConditionEnvs] at *
  · rcases branch with ⟨_, h, _⟩ | ⟨_, h, _⟩ <;> contradiction
  · rcases branch with ⟨_, h, _⟩ | ⟨env, h, related⟩
    · contradiction
    · cases h; exact ⟨_, rfl, related⟩
  · rcases branch with ⟨env, h, related⟩ | ⟨_, h, _⟩
    · cases h; exact ⟨_, rfl, related⟩
    · contradiction
  · exact ⟨_, rfl, range_forget_models _ _⟩

/-- 到達したどちらか一方の環境が対応すれば、合流の入口も存在し対応する。 -/
theorem joinConditionEnvs_models {base left right concrete} (models : Models base concrete)
    (branch : (∃ env, left = some env ∧ Models env concrete) ∨
      (∃ env, right = some env ∧ Models env concrete)) :
    ∃ env, joinConditionEnvs base left right = some env ∧ Models env concrete := by
  cases left <;> cases right <;> simp only [joinConditionEnvs] at *
  · rcases branch with ⟨_, h, _⟩ | ⟨_, h, _⟩ <;> contradiction
  · rcases branch with ⟨_, h, _⟩ | ⟨env, h, related⟩
    · contradiction
    · cases h; exact ⟨_, rfl, related⟩
  · rcases branch with ⟨env, h, related⟩ | ⟨_, h, _⟩
    · cases h; exact ⟨_, rfl, related⟩
    · contradiction
  · refine ⟨_, rfl, models_hullEnv models ?_⟩
    rcases branch with ⟨env, h, related⟩ | ⟨env, h, related⟩ <;> cases h
    · exact Or.inl related
    · exact Or.inr related

/-- 六幅でも、認定した一位置の矛盾だけを到達不能にする。 -/
def kindAtomicConditionEnv (env : AbstractEnv) (condition : Expr) (truth : Bool) : Option AbstractEnv :=
  match comparisonKindAt condition with
  | none => some env
  | some comparison =>
      if refineKindRange comparison.op (integerKindAt env comparison.kind comparison.index)
          comparison.constant truth = .bottom then none
      else some (refineKindEnv env comparison truth)

/-- 比較を認定できない式は環境を変えず、比較の矛盾だけを未到達にする。 -/
def atomicConditionEnv (env : AbstractEnv) (condition : Expr) (truth : Bool) : Option AbstractEnv :=
  match comparisonAt condition with
  | none => kindAtomicConditionEnv env condition truth
  | some comparison =>
      if refineRange comparison.op (integerAt env comparison.index)
          comparison.constant truth = .bottom then none
      else some (refineEnv env comparison truth)

/-- 短絡の順に真偽環境を求める。選択経路は各位置の凸包へ直ちに合流する。 -/
def conditionEnv (env : AbstractEnv) : Expr → Bool → Option AbstractEnv
  | .literal (.boolean value), truth => if value = truth then some env else none
  | .paren child, truth => conditionEnv env child truth
  | .not child, truth => conditionEnv env child (!truth)
  | .and left right, true =>
      (conditionEnv env left true).bind (fun inner => conditionEnv inner right true)
  | .and left right, false =>
      joinConditionEnvs env (conditionEnv env left false)
        ((conditionEnv env left true).bind (fun inner => conditionEnv inner right false))
  | .or left right, true =>
      joinConditionEnvs env (conditionEnv env left true)
        ((conditionEnv env left false).bind (fun inner => conditionEnv inner right true))
  | .or left right, false =>
      (conditionEnv env left false).bind (fun inner => conditionEnv inner right false)
  | source, truth => atomicConditionEnv env source truth

/-- 一位置の比較は Range の由来を変更しない。 -/
theorem ranges_atomicConditionEnv {env concrete source truth inner}
    (related : env.ranges.Models concrete)
    (found : atomicConditionEnv env source truth = some inner) : inner.ranges.Models concrete := by
  unfold atomicConditionEnv at found
  split at found
  · unfold kindAtomicConditionEnv at found
    split at found
    · cases found; exact related
    · split at found
      · contradiction
      · cases found; exact related
  · split at found
    · contradiction
    · cases found; exact related

/-- 複合条件の絞り込みと合流も、同じ具体環境への由来の対応を保つ。 -/
theorem ranges_conditionEnv {env : AbstractEnv} {concrete : ConcreteEnv}
    (related : env.ranges.Models concrete) (source : Expr) (truth : Bool)
    {inner : AbstractEnv} (found : conditionEnv env source truth = some inner) :
    inner.ranges.Models concrete := by
  cases source <;> try exact ranges_atomicConditionEnv related found
  case literal value =>
    cases value <;> try exact ranges_atomicConditionEnv related found
    simp only [conditionEnv] at found
    split at found
    · cases found; exact related
    · contradiction
  case paren child => exact ranges_conditionEnv related child truth found
  case not child => exact ranges_conditionEnv related child (!truth) found
  case and left right =>
    cases truth
    · simp only [conditionEnv] at found
      cases first : conditionEnv env left false with
      | some branch =>
        have h := ranges_joinConditionEnvs (base := env)
          (right := (conditionEnv env left true).bind (fun inner => conditionEnv inner right false))
          (Or.inl ⟨branch, first, ranges_conditionEnv related left false first⟩)
        obtain ⟨joined, entry, modeled⟩ := h
        have := Option.some.inj (entry.symm.trans found)
        subst joined; exact modeled
      | none =>
        simp only [first, joinConditionEnvs] at found
        obtain ⟨middle, atMiddle, atInner⟩ := Option.bind_eq_some_iff.mp found
        exact ranges_conditionEnv (ranges_conditionEnv related left true atMiddle) right false atInner
    · simp only [conditionEnv] at found
      obtain ⟨middle, atMiddle, atInner⟩ := Option.bind_eq_some_iff.mp found
      exact ranges_conditionEnv (ranges_conditionEnv related left true atMiddle) right true atInner
  case or left right =>
    cases truth
    · simp only [conditionEnv] at found
      obtain ⟨middle, atMiddle, atInner⟩ := Option.bind_eq_some_iff.mp found
      exact ranges_conditionEnv (ranges_conditionEnv related left false atMiddle) right false atInner
    · simp only [conditionEnv] at found
      cases first : conditionEnv env left true with
      | some branch =>
        have h := ranges_joinConditionEnvs (base := env)
          (right := (conditionEnv env left false).bind (fun inner => conditionEnv inner right true))
          (Or.inl ⟨branch, first, ranges_conditionEnv related left true first⟩)
        obtain ⟨joined, entry, modeled⟩ := h
        have := Option.some.inj (entry.symm.trans found)
        subst joined; exact modeled
      | none =>
        simp only [first, joinConditionEnvs] at found
        obtain ⟨middle, atMiddle, atInner⟩ := Option.bind_eq_some_iff.mp found
        exact ranges_conditionEnv (ranges_conditionEnv related left false atMiddle) right true atInner
termination_by surfaceSize source

/-- 条件から到達可能な一枝へ渡す環境。正常値なしなら条件の構文も読まない。 -/
def branchEnv (env : AbstractEnv) (condition : Expr)
    (normal : NormalRange (.base .boolean)) (truth : Bool) : Option AbstractEnv :=
  if (if truth then normal.2 else normal.1) then conditionEnv env condition truth else none

/-- 実際に選ばれた真偽の枝にも、同じ成功値の由来だけを渡す。 -/
theorem ranges_branchEnv {env concrete source normal truth inner}
    (related : env.ranges.Models concrete)
    (found : branchEnv env source normal truth = some inner) : inner.ranges.Models concrete := by
  cases truth with
  | false =>
    change (if normal.1 then conditionEnv env source false else none) = some inner at found
    split at found
    · exact ranges_conditionEnv related source false found
    · contradiction
  | true =>
    change (if normal.2 then conditionEnv env source true else none) = some inner at found
    split at found
    · exact ranges_conditionEnv related source true found
    · contradiction

/-- 認定済みの比較では、複合条件の規則を通しても従来の一位置の絞り込みと一致する。 -/
theorem conditionEnv_comparison {env source truth comparison}
    (recognized : comparisonAt source = some comparison) :
    conditionEnv env source truth = atomicConditionEnv env source truth := by
  cases source <;> try simp [comparisonAt] at recognized
  all_goals try rfl
  case paren child =>
    simpa [conditionEnv, atomicConditionEnv, comparisonAt, kindAtomicConditionEnv, comparisonKindAt] using
      conditionEnv_comparison (env := env) (truth := truth) recognized
termination_by surfaceSize source

/-- 腕の共通の位置数は最初の選択肢の slots で決まる。 -/
def matchArmBinders (alternatives : List Alternative) : Nat :=
  (alternatives.head?.map fun alt => alt.slots.length).getD 0

/-- 選択肢合流の基準。整数の腕の新位置は整数のTop、他は未知の通常位置とする。 -/
def matchArmTemplate (env : AbstractEnv) (type : Ty) (count : Nat) : AbstractEnv :=
  let slot := match type with
    | .base .integer => AbstractSlot.integer top
    | _ => .unknown none
  { env with locals := List.replicate count slot ++ env.locals, ranges := env.ranges.extendUnknown count }

/-- 共通の束縛数が一致し、新しい値が整数なら、合流の基準環境も具体値を表す。 -/
theorem models_matchArmTemplate {abstract concrete count} {values : List ConcreteValue}
    (models : Models abstract concrete) (length : values.length = count)
    (integers : ∀ value ∈ values, ∃ integer, value = ConcreteValue.integer integer) :
    Models (matchArmTemplate abstract (.base .integer) count)
      { concrete with locals := values.reverse.map some ++ concrete.locals } := by
  refine ⟨?_, models.2⟩
  have heads : LocalsModels (List.replicate values.length (.integer top)) (values.map some) := by
    clear length
    induction values with
    | nil => exact .nil
    | cons value rest ih =>
      obtain ⟨integer, rfl⟩ := integers value (by simp)
      exact .cons ((mem_top _).mpr integer.toInt_bounds)
        (ih (by intro value member; exact integers value (by simp [member])))
  have reversed := heads.reverse
  simpa [matchArmTemplate, length] using reversed.append models.1

/-- 各選択肢は同じ元環境から入り、その結果だけを凸に合流する。
前の選択肢や前の腕に照合しなかった理由を次へ持ち込まない。 -/
def matchAlternativesEnv (template env : AbstractEnv) (source : Expr) (type : Ty)
    (normal : Interval) : List Alternative → Option AbstractEnv
  | [] => none
  | alt :: rest => joinConditionEnvs template
      (matchAlternativeEnv env source type normal alt)
      (matchAlternativesEnv template env source type normal rest)

/-- 一つの腕の入口。guard と本体へ同じ束縛順の環境を渡すための局所規則。 -/
def matchArmEnv (env : AbstractEnv) (source : Expr) (type : Ty)
    (normal : Interval) (alternatives : List Alternative) : Option AbstractEnv :=
  matchAlternativesEnv (matchArmTemplate env type (matchArmBinders alternatives))
    env source type normal alternatives

/-- 具体的に選ばれた選択肢を表す入口は、選択肢全体の合流でも失われない。
template の対応は、型検査済みの腕の共通の束縛数・種類の契約で与える。 -/
theorem matchAlternativesEnv_models {template env source type normal alternatives concrete alt inner}
    (base : Models template concrete) (member : alt ∈ alternatives)
    (entry : matchAlternativeEnv env source type normal alt = some inner)
    (related : Models inner concrete) :
    ∃ joined, matchAlternativesEnv template env source type normal alternatives = some joined ∧
      Models joined concrete := by
  induction alternatives with
  | nil => contradiction
  | cons head rest ih =>
    apply joinConditionEnvs_models base
    simp only [List.mem_cons] at member
    rcases member with same | later
    · subst head; exact Or.inl ⟨inner, entry, related⟩
    · obtain ⟨joined, found, modeled⟩ := ih later
      exact Or.inr ⟨joined, found, modeled⟩

/-- Integer64 の腕は、照合した選択肢の具体値と束縛順を合流後も保存する。
slots の長さの一致は既存の型検査済み選択肢の契約である。 -/
theorem models_matchIntegerArmEnv
    {abstract concrete source normal alternatives alt value selected bindings}
    {raw : List ConcreteValue}
    (models : Models abstract concrete) (inside : Mem value.toInt normal)
    (member : alt ∈ alternatives)
    (count : alt.slots.length = matchArmBinders alternatives)
    (matched : alt.pat.toCore.matchVal (.const (.integer value)) = some bindings)
    (atLocal : ∀ index, localIndex source = some index →
      concrete.locals[index]? = some (some (.integer value)))
    (locals : PatternLocals alt.pat (.integer value) raw.reverse)
    (chosen : selectSlots raw alt.slots = some selected) :
    ∃ inner, matchArmEnv abstract source (.base .integer) normal alternatives = some inner ∧
      Models inner { concrete with locals := selected.reverse.map some ++ concrete.locals } := by
  obtain ⟨inner, entry, related⟩ := models_matchAlternativeEnv models inside matched atLocal locals chosen
  have base := models_matchArmTemplate models ((selectSlots_length chosen).trans count)
    (by
      intro bound member
      exact ⟨value, integerPatternLocals_values matched locals bound
        (selectSlots_mem chosen bound member)⟩)
  exact matchAlternativesEnv_models base member entry related

/-- 幅付き整数に許す束縛・ワイルドカードは、照合値の全正常区間を保存する。
定数と範囲のパターンはこの幅の型検査対象に含めない
（設計書 01-02「パターンマッチ」、01-04「Integer」）。 -/
def integerKindPatternRange (kind : IntKind) (_pattern : Pattern) : Interval kind := top kind

/-- 種類付きの照合の成功は、その種類の全値域に含まれる。 -/
theorem integerKindPatternRange_sound {kind : IntKind} {pattern bindings}
    {value : IntegerValue kind}
    (_matched : widthPatternMatch pattern kind value = some bindings) :
    Mem value.toInt (integerKindPatternRange kind pattern) :=
  (mem_top _ _).mpr value.toInt_bounds

/-- 幅付きの整数パターンは、照合値自身以外の内部の値を束縛しない。 -/
theorem integerKindPatternLocals_values {kind : IntKind} {pattern bindings}
    {value : IntegerValue kind} {raw : List ConcreteValue}
    (matched : widthPatternMatch pattern kind value = some bindings)
    (locals : PatternLocals pattern (.ofInteger kind value) raw.reverse) :
    ∀ bound ∈ raw, bound = .ofInteger kind value := by
  have locals := patternLocals_reverse.mp locals
  cases pattern <;>
    simp_all [widthPatternMatch, PatternLocals, Pattern.binders, Pattern.toCore, Pat.binders]

/-- 幅付きの照合対象でも、直接参照した一位置だけを束縛追加前に絞る。 -/
def matchKindScrutineeEnv (env : AbstractEnv) (source : Expr) (kind : IntKind)
    (range : Interval kind) : AbstractEnv :=
  match localIndex source with
  | some index => narrowKindAt env kind index range
  | none => env

/-- 元の局所参照を絞っても、同じ幅の具体的な照合値を失わない。 -/
theorem models_matchKindScrutineeEnv {kind : IntKind} {abstract concrete source range}
    {value : IntegerValue kind}
    (models : Models abstract concrete) (inside : Mem value.toInt range)
    (atLocal : ∀ index, localIndex source = some index →
      concrete.locals[index]? = some (some (.ofInteger kind value))) :
    Models (matchKindScrutineeEnv abstract source kind range) concrete := by
  simp only [matchKindScrutineeEnv]
  cases recognized : localIndex source with
  | none => exact models
  | some index => exact models_narrowKindAt models (atLocal index recognized) inside

/-- 幅付きの一選択肢の入口。空の交差では slots の位置も増やさない。 -/
def matchKindAlternativeEnv (env : AbstractEnv) (source : Expr) (kind : IntKind)
    (normal : Interval kind) (alt : Alternative) : Option AbstractEnv :=
  let range := meet normal (integerKindPatternRange kind alt.pat)
  if range = .bottom then none else
    extendMatchSlots (matchKindScrutineeEnv env source kind range)
      (matchKindPatternSlots alt.pat kind range) alt.slots

/-- 照合成功と slots の具体的な選択から、幅を保つ選択肢入口を得る。 -/
theorem models_matchKindAlternativeEnv {kind : IntKind}
    {abstract concrete source normal alt selected bindings}
    {value : IntegerValue kind} {raw : List ConcreteValue}
    (models : Models abstract concrete) (inside : Mem value.toInt normal)
    (matched : widthPatternMatch alt.pat kind value = some bindings)
    (atLocal : ∀ index, localIndex source = some index →
      concrete.locals[index]? = some (some (.ofInteger kind value)))
    (locals : PatternLocals alt.pat (.ofInteger kind value) raw.reverse)
    (chosen : selectSlots raw alt.slots = some selected) :
    ∃ inner, matchKindAlternativeEnv abstract source kind normal alt = some inner ∧
      Models inner { concrete with locals := selected.reverse.map some ++ concrete.locals } := by
  have member : Mem value.toInt (meet normal (integerKindPatternRange kind alt.pat)) :=
    (mem_meet _ _ _).mpr ⟨inside, integerKindPatternRange_sound matched⟩
  have live : meet normal (integerKindPatternRange kind alt.pat) ≠ .bottom := by
    intro empty; rw [empty] at member; exact member
  obtain ⟨inner, entry, related⟩ := models_extendMatchSlots
    (models_matchKindScrutineeEnv models member atLocal)
    (matchKindPatternSlots_models member locals) chosen
  exact ⟨inner, by simpa only [matchKindAlternativeEnv, live, ite_false] using entry, related⟩

/-- 共通の新位置は照合値と同じ整数幅を持ち、外の位置は元の形を保つ。 -/
def matchKindArmTemplate (env : AbstractEnv) (kind : IntKind) (count : Nat) : AbstractEnv :=
  { env with locals := List.replicate count (topKindSlot kind) ++ env.locals, ranges := env.ranges.extendUnknown count }

/-- 共通の幅と位置数が一致すれば、選択肢の合流の基準環境も対応する。 -/
theorem models_matchKindArmTemplate {kind : IntKind} {abstract concrete count}
    {values : List ConcreteValue}
    (models : Models abstract concrete) (length : values.length = count)
    (integers : ∀ value ∈ values, ∃ integer, value = ConcreteValue.ofInteger kind integer) :
    Models (matchKindArmTemplate abstract kind count)
      { concrete with locals := values.reverse.map some ++ concrete.locals } := by
  refine ⟨?_, models.2⟩
  have heads : LocalsModels (List.replicate values.length (topKindSlot kind))
      (values.map some) := by
    clear length
    induction values with
    | nil => exact .nil
    | cons value rest ih =>
      obtain ⟨integer, rfl⟩ := integers value (by simp)
      exact .cons (integerKindSlot_models ((mem_top _ _).mpr integer.toInt_bounds))
        (ih (by intro value member; exact integers value (by simp [member])))
  have reversed := heads.reverse
  simpa [matchKindArmTemplate, length] using reversed.append models.1

/-- 各選択肢は同じ元環境から解析し、同じ種類の位置だけを凸包へ合流する。 -/
def matchKindAlternativesEnv (template env : AbstractEnv) (source : Expr) (kind : IntKind)
    (normal : Interval kind) : List Alternative → Option AbstractEnv
  | [] => none
  | alt :: rest => joinConditionEnvs template
      (matchKindAlternativeEnv env source kind normal alt)
      (matchKindAlternativesEnv template env source kind normal rest)

/-- 幅付きの照合の腕入口を作り、guard と本体へ同じ束縛順を渡す。 -/
def matchKindArmEnvCore (env : AbstractEnv) (source : Expr) (kind : IntKind)
    (normal : Interval kind) (alternatives : List Alternative) : Option AbstractEnv :=
  matchKindAlternativesEnv (matchKindArmTemplate env kind (matchArmBinders alternatives))
    env source kind normal alternatives

/-- 実際に選ばれた幅付きの選択肢の具体環境は、腕全体の合流でも失われない。 -/
theorem matchKindAlternativesEnv_models
    {kind : IntKind} {template env source normal alternatives concrete alt inner}
    (base : Models template concrete) (member : alt ∈ alternatives)
    (entry : matchKindAlternativeEnv env source kind normal alt = some inner)
    (related : Models inner concrete) :
    ∃ joined, matchKindAlternativesEnv template env source kind normal alternatives = some joined ∧
      Models joined concrete := by
  induction alternatives with
  | nil => contradiction
  | cons head rest ih =>
    apply joinConditionEnvs_models base
    simp only [List.mem_cons] at member
    rcases member with same | later
    · subst head; exact Or.inl ⟨inner, entry, related⟩
    · obtain ⟨joined, found, modeled⟩ := ih later
      exact Or.inr ⟨joined, found, modeled⟩

/-- 幅付きの腕でも、選択した値・位置順と元の局所環境の対応を保存する。 -/
theorem models_matchKindArmEnvCore {kind : IntKind}
    {abstract concrete source normal alternatives alt selected bindings}
    {value : IntegerValue kind} {raw : List ConcreteValue}
    (models : Models abstract concrete) (inside : Mem value.toInt normal)
    (member : alt ∈ alternatives)
    (count : alt.slots.length = matchArmBinders alternatives)
    (matched : widthPatternMatch alt.pat kind value = some bindings)
    (atLocal : ∀ index, localIndex source = some index →
      concrete.locals[index]? = some (some (.ofInteger kind value)))
    (locals : PatternLocals alt.pat (.ofInteger kind value) raw.reverse)
    (chosen : selectSlots raw alt.slots = some selected) :
    ∃ inner, matchKindArmEnvCore abstract source kind normal alternatives = some inner ∧
      Models inner { concrete with locals := selected.reverse.map some ++ concrete.locals } := by
  obtain ⟨inner, entry, related⟩ := models_matchKindAlternativeEnv models inside matched
    atLocal locals chosen
  have base := models_matchKindArmTemplate models ((selectSlots_length chosen).trans count)
    (by
      intro bound member
      exact ⟨value, integerKindPatternLocals_values matched locals bound
        (selectSlots_mem chosen bound member)⟩)
  exact matchKindAlternativesEnv_models base member entry related

/-- 具体的に選ばれた整数の選択肢で、新しい未知位置と元の成功由来を対応させる。 -/
theorem ranges_matchAlternativeEnv {env concrete source type normal alt inner}
    (related : env.ranges.Models concrete)
    (found : matchAlternativeEnv env source type normal alt = some inner)
    (values : List (Option ConcreteValue)) (length : values.length = alt.slots.length) :
    inner.ranges.Models { concrete with locals := values ++ concrete.locals } := by
  unfold matchAlternativeEnv at found
  dsimp only at found
  have unchanged : (matchScrutineeEnv env source type (matchRange type normal alt.pat)).ranges = env.ranges := by
    unfold matchScrutineeEnv
    split
    · split <;> rfl
    · rfl
  cases type <;> (try dsimp only at found) <;> try exact ranges_extendMatchSlots (by simpa only [unchanged] using related) found values length
  rename_i base
  cases base <;> (try dsimp only at found) <;> try exact ranges_extendMatchSlots (by simpa only [unchanged] using related) found values length
  split at found
  · contradiction
  · exact ranges_extendMatchSlots (by simpa only [unchanged] using related) found values length

/-- 幅付きの整数照合も、新しい位置に成功由来を作らない。 -/
theorem ranges_matchKindAlternativeEnv {kind env concrete source normal alt inner}
    (related : env.ranges.Models concrete)
    (found : matchKindAlternativeEnv env source kind normal alt = some inner)
    (values : List (Option ConcreteValue)) (length : values.length = alt.slots.length) :
    inner.ranges.Models { concrete with locals := values ++ concrete.locals } := by
  unfold matchKindAlternativeEnv at found
  dsimp only at found
  split at found
  · contradiction
  · apply ranges_extendMatchSlots (env := matchKindScrutineeEnv env source kind _) _ found values length
    unfold matchKindScrutineeEnv
    split <;> exact related

/-- 実際の選択肢の成功由来の対応を、選択肢全体の合流へ移す。 -/
theorem ranges_matchAlternativesEnv {template env source type normal alternatives concrete alt inner}
    (member : alt ∈ alternatives)
    (entry : matchAlternativeEnv env source type normal alt = some inner)
    (related : inner.ranges.Models concrete) :
    ∃ joined, matchAlternativesEnv template env source type normal alternatives = some joined ∧
      joined.ranges.Models concrete := by
  induction alternatives with
  | nil => contradiction
  | cons head rest ih =>
    apply ranges_joinConditionEnvs
    simp only [List.mem_cons] at member
    rcases member with same | later
    · subst head; exact Or.inl ⟨inner, entry, related⟩
    · obtain ⟨joined, found, modeled⟩ := ih later
      exact Or.inr ⟨joined, found, modeled⟩

/-- 六幅の選択肢の合流も、到達した選択肢の対応だけを用いる。 -/
theorem ranges_matchKindAlternativesEnv {kind template env source normal alternatives concrete alt inner}
    (member : alt ∈ alternatives)
    (entry : matchKindAlternativeEnv env source kind normal alt = some inner)
    (related : inner.ranges.Models concrete) :
    ∃ joined, matchKindAlternativesEnv template env source kind normal alternatives = some joined ∧
      joined.ranges.Models concrete := by
  induction alternatives with
  | nil => contradiction
  | cons head rest ih =>
    apply ranges_joinConditionEnvs
    simp only [List.mem_cons] at member
    rcases member with same | later
    · subst head; exact Or.inl ⟨inner, entry, related⟩
    · obtain ⟨joined, found, modeled⟩ := ih later
      exact Or.inr ⟨joined, found, modeled⟩

/-- Integer64 は既存の定数・範囲の精度を保ち、他の六幅は束縛と guard を扱う。 -/
def matchKindArmEnv (env : AbstractEnv) (source : Expr) (kind : IntKind)
    (normal : Interval kind) (alternatives : List Alternative) : Option AbstractEnv :=
  match kind with
  | .integer64 => matchArmEnv env source (.base .integer) normal alternatives
  | kind => matchKindArmEnvCore env source kind normal alternatives

/-- 種類を選ぶ入口でも、具体的な照合値と束縛順の対応を保存する。 -/
theorem models_matchKindArmEnv {kind : IntKind}
    {abstract concrete source normal alternatives alt selected bindings}
    {value : IntegerValue kind} {raw : List ConcreteValue}
    (models : Models abstract concrete) (inside : Mem value.toInt normal)
    (member : alt ∈ alternatives)
    (count : alt.slots.length = matchArmBinders alternatives)
    (matched : widthPatternMatch alt.pat kind value = some bindings)
    (atLocal : ∀ index, localIndex source = some index →
      concrete.locals[index]? = some (some (.ofInteger kind value)))
    (locals : PatternLocals alt.pat (.ofInteger kind value) raw.reverse)
    (chosen : selectSlots raw alt.slots = some selected) :
    ∃ inner, matchKindArmEnv abstract source kind normal alternatives = some inner ∧
      Models inner { concrete with locals := selected.reverse.map some ++ concrete.locals } := by
  cases kind with
  | integer64 =>
    apply models_matchIntegerArmEnv models inside member count (bindings := bindings)
      (value := value) ?_ atLocal locals chosen
    cases pattern : alt.pat <;> simp_all [widthPatternMatch, Pattern.toCore, Pat.matchVal,
      integerPatternValue, IntegerValue.toConst]
  | integer8 | integer16 | integer32 | unsignedInteger16 | unsignedInteger32 | unsignedInteger64 =>
    exact models_matchKindArmEnvCore models inside member count matched atLocal locals chosen

/-- 未到達ならコールバックを呼ばない。枝内の束縛は枝外の環境へ持ち出さない。 -/
def analyzeBranch {type : Ty} (env : Option AbstractEnv)
    (analyze : AbstractEnv → FlowApprox type) : FlowApprox type :=
  match env with
  | none => unreachableFlow type
  | some refined => analyze refined

/-- 型ごとの正常値の有無。return と失敗の区別や、成功の保証には使わない。 -/
def normalPossible (type : Ty) (normal : NormalRange type) : Bool := by
  cases type with
  | base base =>
    cases base with
    | integer => exact (match normal with | .bottom => false | .closed .. => true)
    | boolean => exact (normal.1 || normal.2)
    | _ => exact normal
  | _ => exact normal

/-- 正常な具体値を含む範囲には、後続へ進む可能性がある。 -/
theorem normalPossible_sound {type normal value} (inside : NormalMem type normal value) :
    normalPossible type normal = true := by
  obtain ⟨typed, inside⟩ := inside
  cases type with
  | base base =>
    cases base with
    | integer =>
      cases value <;> simp_all [ConcreteValue.type, NormalContains]
      cases normal <;> simp_all [normalPossible, Mem]
    | boolean =>
      cases value <;> simp_all [ConcreteValue.type, NormalContains]
      rename_i truth
      cases truth <;> simp_all [normalPossible]
    | _ => exact inside
  | _ => exact inside

/-- 正常値なしは、どの型でも後続へ進めない。 -/
theorem normalPossible_empty (type : Ty) : normalPossible type (emptyNormal type) = false := by
  cases type <;> try rfl
  rename_i base
  cases base <;> rfl

/-- return のオペランドの失敗・警告を残し、式の正常値だけを消す。 -/
def returnFlow {operandType : Ty} (resultType : Ty)
    (operand : FlowApprox operandType) : FlowApprox resultType :=
  ⟨emptyNormal resultType, operand.mayFail, operand.warnings⟩

/-- return の値を式の正常値として後続へ戻さない。 -/
theorem returnFlow_no_normal {operandType resultType value} (operand : FlowApprox operandType) :
    ¬ NormalMem resultType (returnFlow resultType operand).normal value := by
  intro inside
  have possible := normalPossible_sound inside
  simpa [returnFlow, normalPossible_empty] using possible

/-- オペランドを一度解析してから、return の後続への伝播を切る。 -/
def analyzeReturn {operandType : Ty} (resultType : Ty) (env : AbstractEnv) (operand : Expr)
    (analyze : AbstractEnv → Expr → FlowApprox operandType) : FlowApprox resultType :=
  returnFlow resultType (analyze env operand)

/-- 正常な値がなければ後続を解析しない。続きの環境は呼び出し側が元環境から作る。 -/
def thenFlow {firstType resultType : Ty} (first : FlowApprox firstType)
    (next : Unit → FlowApprox resultType) : FlowApprox resultType :=
  if normalPossible firstType first.normal then
    let rest := next ()
    ⟨rest.normal, first.mayFail || rest.mayFail, first.warnings ++ rest.warnings⟩
  else returnFlow resultType first

/-- return 後の式は解析されず、オペランドで既に得た失敗可能性と警告だけを残す。 -/
theorem thenFlow_return {operandType firstType resultType : Ty}
    (operand : FlowApprox operandType) (next : Unit → FlowApprox resultType) :
    thenFlow (returnFlow firstType operand) next = returnFlow resultType operand := by
  simp [thenFlow, returnFlow, normalPossible_empty]

/-- 正常な第一式に続く正常値は、順序付きの合成でも失わない。 -/
theorem thenFlow_normal_sound {firstType resultType first next firstValue value}
    (firstInside : NormalMem firstType first.normal firstValue)
    (nextInside : NormalMem resultType (next ()).normal value) :
    NormalMem resultType (thenFlow first next).normal value := by
  simpa [thenFlow, normalPossible_sound firstInside] using nextInside

/-- guard を先に読み、真の正常値が可能な環境だけで腕の本体を解析する。
偽の事実や腕内の束縛を、次の腕や match の外へ返さない。 -/
def analyzeGuardedBody {type : Ty} (env : AbstractEnv) (guard : Option Expr) (body : Block)
    (analyzeGuard : AbstractEnv → Expr → FlowApprox (.base .boolean))
    (analyzeBlock : AbstractEnv → Block → FlowApprox type) : FlowApprox type :=
  match guard with
  | none => analyzeBlock env body
  | some condition =>
    let tested := analyzeGuard env condition
    let result := analyzeBranch (branchEnv env condition tested.normal true)
      (fun refined => analyzeBlock refined body)
    ⟨result.normal, tested.mayFail || result.mayFail, tested.warnings ++ result.warnings⟩

/-- パターン照合の入口、guard、腕の本体の順に局所規則を接続する。
後続の腕には、この結果でなく同じ元環境と照合値を渡す。 -/
def analyzeMatchArm {type : Ty} (env : AbstractEnv) (source : Expr) (scrutineeType : Ty)
    (normal : Interval) (alternatives : List Alternative) (guard : Option Expr) (body : Block)
    (analyzeGuard : AbstractEnv → Expr → FlowApprox (.base .boolean))
    (analyzeBlock : AbstractEnv → Block → FlowApprox type) : FlowApprox type :=
  analyzeBranch (matchArmEnv env source scrutineeType normal alternatives)
    (fun inner => analyzeGuardedBody inner guard body analyzeGuard analyzeBlock)

/-- guard の真の入口がなければ、本体の警告・失敗可能性は合成しない。 -/
theorem analyzeGuardedBody_unreachable {type env condition body analyzeGuard analyzeBlock}
    (unreachable : branchEnv env condition (analyzeGuard env condition).normal true = none) :
    analyzeGuardedBody (type := type) env (some condition) body analyzeGuard analyzeBlock =
      returnFlow type (analyzeGuard env condition) := by
  simp [analyzeGuardedBody, unreachable, analyzeBranch, unreachableFlow, returnFlow]

/-- 条件の失敗と警告を先に保存し、選んだ枝の正常値と失敗・警告を合成する。 -/
def mergeBranches {type : Ty} (condition : FlowApprox (.base .boolean))
    (yes no : FlowApprox type) : FlowApprox type :=
  ⟨joinNormal type yes.normal no.normal,
    condition.mayFail || yes.mayFail || no.mayFail,
    condition.warnings ++ yes.warnings ++ no.warnings⟩

/-- iteの局所規則。条件を一度読み、到達可能な各Blockを一度ずつ読む。 -/
def analyzeIte {type : Ty} (env : AbstractEnv) (condition : Expr) (yes no : Block)
    (analyzeCondition : AbstractEnv → Expr → FlowApprox (.base .boolean))
    (analyzeBlock : AbstractEnv → Block → FlowApprox type) : FlowApprox type :=
  let tested := analyzeCondition env condition
  let yesResult := analyzeBranch (branchEnv env condition tested.normal true)
    (fun refined => analyzeBlock refined yes)
  let noResult := analyzeBranch (branchEnv env condition tested.normal false)
    (fun refined => analyzeBlock refined no)
  mergeBranches tested yesResult noResult

/-- elseIfの偽枝は式であり、その式へ偽枝の絞り込みを渡す。 -/
def analyzeElseIf {type : Ty} (env : AbstractEnv) (condition : Expr) (yes : Block) (no : Expr)
    (analyzeCondition : AbstractEnv → Expr → FlowApprox (.base .boolean))
    (analyzeBlock : AbstractEnv → Block → FlowApprox type)
    (analyzeExpr : AbstractEnv → Expr → FlowApprox type) : FlowApprox type :=
  let tested := analyzeCondition env condition
  let yesResult := analyzeBranch (branchEnv env condition tested.normal true)
    (fun refined => analyzeBlock refined yes)
  let noResult := analyzeBranch (branchEnv env condition tested.normal false)
    (fun refined => analyzeExpr refined no)
  mergeBranches tested yesResult noResult

/-- ifOnlyの偽枝はunitで正常終了し、真枝の失敗やreturnを正常値に戻さない。 -/
def analyzeIfOnly (env : AbstractEnv) (condition : Expr) (yes : Block)
    (analyzeCondition : AbstractEnv → Expr → FlowApprox (.base .boolean))
    (analyzeBlock : AbstractEnv → Block → FlowApprox (.base .unit)) :
    FlowApprox (.base .unit) :=
  let tested := analyzeCondition env condition
  let yesResult := analyzeBranch (branchEnv env condition tested.normal true)
    (fun refined => analyzeBlock refined yes)
  let noResult := analyzeBranch (branchEnv env condition tested.normal false)
    (fun _ => (⟨true, false, []⟩ : FlowApprox (.base .unit)))
  mergeBranches tested yesResult noResult

/-- 条件の成否にかかわらず、到達した枝の正常値は合成結果へ入る。 -/
theorem mergeBranches_normal_sound {type condition yes no value}
    (inside : NormalMem type yes.normal value ∨ NormalMem type no.normal value) :
    NormalMem type (mergeBranches condition yes no).normal value :=
  joinNormal_sound inside

/-- 条件で正常値を得なければ、いずれの枝の失敗も警告も追加しない。 -/
theorem branchEnv_no_normal (env : AbstractEnv) (condition : Expr) (truth : Bool) :
    branchEnv env condition (false, false) truth = none := by
  cases truth <;> rfl

/-- 実際に選ばれた比較の枝は、Bottomによる枝の除外で失われない。 -/
theorem branchEnv_comparison_sound {abstract concrete condition normal truth comparison value}
    (models : Models abstract concrete)
    (recognized : comparisonAt condition = some comparison)
    (possible : (if truth then normal.2 else normal.1) = true)
    (atIndex : concrete.locals[comparison.index]? = some (some (.integer value)))
    (holds : comparison.op.Holds value.toInt comparison.constant ↔ truth = true) :
    ∃ refined, branchEnv abstract condition normal truth = some refined ∧ Models refined concrete := by
  have inside := refineRange_sound (integerAt_sound models atIndex) holds
  have nonempty : refineRange comparison.op (integerAt abstract comparison.index)
      comparison.constant truth ≠ .bottom := by
    intro empty
    rw [empty] at inside
    exact inside
  exact ⟨refineEnv abstract comparison truth,
    by simp [branchEnv, possible, conditionEnv_comparison recognized,
      atomicConditionEnv, recognized, nonempty], models_refineEnv models atIndex holds⟩

-- 分岐の正常値の合流は穴を失い、失敗の有無と正常値なしを独立に保つ。
example :
    joinNormal (.base .integer) (normalize (-2) (-1)) (normalize 1 2) = normalize (-2) 2 ∧
    joinNormal (.base .integer) .bottom (normalize 7 7) = normalize 7 7 ∧
    joinNormal (.base .boolean) (true, false) (false, true) = (true, true) ∧
    joinNormal (.base .unit) false true = true ∧
    (unknownFlow (.base .integer)).normal = top ∧
    (unreachableFlow (.base .integer)).normal = .bottom := by
  repeat' constructor

-- 条件に正常値がなければ両枝を除外し、到達した条件自身の警告だけを残す。
-- ここで検査するのは局所の合成規則であり、コールバックの健全性ではない。
example (key : OperationKey) (source : Expr) (yes no : Block) :
    let warning : IntervalWarning := ⟨key, .binary .intDiv (.base .integer), .zeroDivisor⟩
    let condition : FlowApprox (.base .boolean) := ⟨(false, false), true, [warning]⟩
    let result := analyzeIte (type := .base .integer) (AbstractEnv.ofLocals []) source yes no
      (fun _ _ => condition)
      (fun _ _ => ⟨normalize 99 99, true, [warning, warning]⟩)
    result.normal = .bottom ∧ result.mayFail = true ∧
    result.warnings.map (fun w => w.cause) = [.zeroDivisor] := by
  exact ⟨rfl, rfl, rfl⟩

-- 真だけが可能なら偽枝の失敗・警告は混ぜず、選ばれた正常値だけを残す。
example (key : OperationKey) :
    let warning : IntervalWarning := ⟨key, .binary .add (.base .integer), .overflow⟩
    let result := analyzeElseIf (type := .base .integer) (AbstractEnv.ofLocals []) (.literal (.boolean true))
      (.last (.literal (.integer ⟨4, by decide⟩)))
      (.binary .add (.base .integer)
        (.literal (.integer ⟨9223372036854775807, by decide⟩))
        (.literal (.integer ⟨1, by decide⟩)))
      (fun _ _ => ⟨(false, true), false, []⟩)
      (fun _ _ => ⟨normalize 4 4, false, []⟩)
      (fun _ _ => ⟨.bottom, true, [warning]⟩)
    result.normal = normalize 4 4 ∧ result.mayFail = false ∧ result.warnings = [] := by
  exact ⟨rfl, rfl, rfl⟩

-- 既知の比較の偽枝をelseIfの式へ渡す。別名は逆方向に絞らない。
example :
    let env : AbstractEnv := (AbstractEnv.ofLocals [.integer (normalize (-5) 5), .integer (normalize (-5) 5)])
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let condition : Expr := .binary .lt (.base .integer) (.local 0) zero
    let branch := branchEnv env condition (true, true) false
    branch.map (fun refined => (integerAt refined 0, integerAt refined 1)) =
      some (normalize 0 5, normalize (-5) 5) ∧
    (analyzeElseIf (type := .base .integer) env condition
      (.last (.literal (.integer ⟨8, by decide⟩))) (.local 0)
      (fun _ _ => ⟨(true, true), false, []⟩)
      (fun _ _ => ⟨normalize 8 8, false, []⟩)
      (fun refined source => ⟨atomRange refined source, false, []⟩)).normal = normalize 0 8 := by
  repeat' constructor

-- iteの異なる二つのBlockを読む。真枝の絞り込みを落とすと上端5が混入する。
example :
    let env : AbstractEnv := (AbstractEnv.ofLocals [.integer (normalize (-5) 5)])
    let condition : Expr := .binary .lt (.base .integer) (.local 0)
      (.literal (.integer ⟨0, by decide⟩))
    let result := analyzeIte (type := .base .integer) env condition
      (.last (.local 0)) (.last (.literal (.integer ⟨2, by decide⟩)))
      (fun _ _ => ⟨(true, true), false, []⟩)
      (fun refined body => match body with
        | .last source => ⟨atomRange refined source, false, []⟩
        | _ => unknownFlow (.base .integer))
    result.normal = normalize (-5) 2 ∧ result.mayFail = false ∧ result.warnings = [] := by
  repeat' constructor

-- 比較の矛盾で枝を除外する。両枝が可能でも正常値のない失敗枝は値に混ぜない。
example (key : OperationKey) :
    let warning : IntervalWarning := ⟨key, .binary .add (.base .integer), .overflow⟩
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let condition : Expr := .binary .lt (.base .integer) (.local 0) zero
    let env : AbstractEnv := (AbstractEnv.ofLocals [.integer (normalize 0 5)])
    let tested : FlowApprox (.base .boolean) := ⟨(true, true), false, []⟩
    let failed : FlowApprox (.base .integer) := ⟨.bottom, true, [warning]⟩
    let yes := analyzeBranch (branchEnv env condition tested.normal true) (fun _ => failed)
    let no : FlowApprox (.base .integer) := ⟨normalize 6 8, false, []⟩
    let pruned := mergeBranches tested yes no
    let reached := mergeBranches tested failed no
    pruned.normal = normalize 6 8 ∧ pruned.mayFail = false ∧ pruned.warnings = [] ∧
    reached.normal = normalize 6 8 ∧ reached.mayFail = true ∧
    reached.warnings.map (fun w => w.cause) = [.overflow] := by
  repeat' constructor

-- ifOnlyは偽ならunit、真の正常値がなければ正常値なしとする。
-- 正常値なしの条件はreturn相当でも失敗相当でも両枝を実行しない。
example :
    let failed : FlowApprox (.base .unit) := ⟨false, true, []⟩
    let returned : FlowApprox (.base .unit) := ⟨false, false, []⟩
    let run := fun normal branch => analyzeIfOnly (AbstractEnv.ofLocals [.unknown (some (.base .boolean))])
      (.local 0) (.last .unit)
      (fun _ _ => ⟨normal, false, []⟩) (fun _ _ => branch)
    (run (true, false) failed).normal = true ∧
    (run (true, false) failed).mayFail = false ∧
    (run (false, true) failed).normal = false ∧
    (run (false, true) failed).mayFail = true ∧
    (run (true, true) failed).normal = true ∧
    (run (true, true) failed).mayFail = true ∧
    (run (false, true) returned).normal = false ∧
    (run (false, true) returned).mayFail = false ∧
    (run (false, false) failed).normal = false ∧
    (run (false, false) failed).mayFail = false := by
  repeat' constructor

-- 独立期待値で六比較の両枝を確かめる。期待区間は絞り込みから生成しない。
example :
    let range := normalize (-5) 5
    ([Comparison.eq, .ne, .lt, .le, .gt, .ge].map fun op =>
      (refineRange op range 0 true, refineRange op range 0 false)) =
    [(normalize 0 0, normalize (-5) 5), (normalize (-5) 5, normalize 0 0),
     (normalize (-5) (-1), normalize 0 5), (normalize (-5) 0, normalize 1 5),
     (normalize 1 5, normalize (-5) 0), (normalize 0 5, normalize (-5) (-1))] := by decide

-- 値域の外のk±1を数学上で求め、到達不能をBottomにする。
example :
    refineRange .lt top min64 true = .bottom ∧
    refineRange .ge top min64 false = .bottom ∧
    refineRange .gt top max64 true = .bottom ∧
    refineRange .le top max64 false = .bottom ∧
    refineRange .eq top min64 true = normalize min64 min64 ∧
    refineRange .ne top max64 false = normalize max64 max64 ∧
    refineRange .lt top max64 true = normalize min64 (max64 - 1) ∧
    refineRange .gt top min64 true = normalize (min64 + 1) max64 := by decide

-- 等値の偽枝の穴を捏造せず、端点と一点の場合だけ狭める。
example :
    refineRange .eq (normalize (-2) 2) 0 false = normalize (-2) 2 ∧
    Mem 0 (refineRange .eq (normalize (-2) 2) 0 false) ∧
    refineRange .eq (normalize 0 2) 0 false = normalize 1 2 ∧
    refineRange .eq (normalize (-2) 0) 0 false = normalize (-2) (-1) ∧
    refineRange .eq (normalize 0 0) 0 false = .bottom ∧
    refineRange .ne .bottom 0 true = .bottom := by decide

-- 同型のconstと負号付きリテラルを、独立した具体の一点へ保存する。
example :
    let seven : Expr := .literal (.integer ⟨7, by decide⟩)
    atomRange (AbstractEnv.ofLocals []) (.constE (.base .integer) (.paren seven)) = normalize 7 7 ∧
    integerConstant (.constE (.base .integer) (.paren seven)) = some 7 ∧
    atomRange (AbstractEnv.ofLocals []) (.negInt ⟨9223372036854775808, by decide⟩) = normalize min64 min64 ∧
    integerConstant (.negInt ⟨9223372036854775808, by decide⟩) = some min64 := by decide

-- 定数の幅と比較の型を照合し、左右反転と括弧を同じ位置へ対応させる。
example :
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let constant : Expr := .constE (.base .integer) (.paren zero)
    comparisonAt (.binary .lt (.base .integer) (.local 2) constant) =
      some ⟨2, .lt, 0⟩ ∧
    comparisonAt (.paren (.binary .gt (.base .integer) constant (.paren (.local 2)))) =
      some ⟨2, .lt, 0⟩ ∧
    comparisonAt (.binary .lt (.base .integer8) (.local 2) (.literal (.integer8 0))) = none ∧
    comparisonAt (.binary .lt (.base .integer) (.local 2) (.literal (.integer8 0))) = none ∧
    comparisonAt (.binary .lt (.base .integer) (.local 0) (.local 1)) = none ∧
    comparisonAt (.binary .lt (.base .integer)
      (.binary .add (.base .integer) (.local 0) zero) zero) = none := by decide

-- 別名は束縛時の区間をコピーし、比較では片方だけを狭める。
-- 続くshadowの新しい番号0を絞っても、古い番号と元の区間は保存する。
example :
    let original : AbstractEnv := (AbstractEnv.ofLocals [.integer (normalize (-5) 5)])
    let alias := bindRange .bind original (.base .integer) (atomRange original (.local 0))
    let narrowed := refineEnv alias ⟨0, .gt, 0⟩ true
    let shadow := bindRange .shadow narrowed (.base .integer) (normalize 9 9)
    let finalEnv := refineEnv shadow ⟨0, .eq, 9⟩ true
    (integerAt narrowed 0, integerAt narrowed 1) = (normalize 1 5, normalize (-5) 5) ∧
    (integerAt finalEnv 0, integerAt finalEnv 1, integerAt finalEnv 2) =
      (normalize 9 9, normalize 1 5, normalize (-5) 5) ∧
    (BindingScope.fresh (BindingScope.fresh ⟨[0], 1⟩)).positions = [2, 1, 0] := by decide

-- 宣言型が整数でもない位置と専用位置を、整数の事実に置き換えない。
example :
    let env : AbstractEnv := (AbstractEnv.ofLocals [.builder .string, .unknown (some (.reference (.base .integer)))])
    lookup (refineEnv env ⟨0, .eq, 0⟩ true) 0 = some (.builder .string) ∧
    lookup (refineEnv env ⟨1, .eq, 0⟩ true) 1 =
      some (.unknown (some (.reference (.base .integer)))) ∧
    atomRange env (.constE (.base .integer8) (.literal (.integer8 7))) = top ∧
    integerConstant (.constE (.base .integer8) (.literal (.integer8 7))) = none := by
  exact ⟨rfl, rfl, rfl, rfl⟩

-- 複合条件の真偽を独立した端点で固定し、凸包で失う穴も残す。
-- 未知の論理式から整数の事実を捏造せず、元の別名・専用位置を保つ。
example :
    let env : AbstractEnv := (AbstractEnv.ofLocals [.integer (normalize (-5) 5),
      .integer (normalize (-5) 5), .builder .string])
    let constant := fun (n : Integer64Literal) => Expr.literal (.integer n)
    let low : Expr := .binary .ge (.base .integer) (.local 0) (constant ⟨0, by decide⟩)
    let high : Expr := .binary .le (.base .integer) (.local 0) (constant ⟨2, by decide⟩)
    let unknown : Expr := .funName "Example.unknownCondition" [] []
    let read := fun source truth => (conditionEnv env source truth).map fun inner =>
      (integerAt inner 0, integerAt inner 1, lookup inner 2)
    read (.and low high) true =
      some (normalize 0 2, normalize (-5) 5, some (.builder .string)) ∧
    read (.and low high) false =
      some (normalize (-5) 5, normalize (-5) 5, some (.builder .string)) ∧
    read (.or (.not low) (.not high)) false =
      some (normalize 0 2, normalize (-5) 5, some (.builder .string)) ∧
    read (.or (.not low) (.not high)) true =
      some (normalize (-5) 5, normalize (-5) 5, some (.builder .string)) ∧
    conditionEnv env (.and low (.not low)) true = none ∧
    conditionEnv env (.or low (.not low)) false = none ∧
    conditionEnv env unknown true = some env ∧
    conditionEnv env (.not unknown) false = some env ∧
    conditionEnv env (.and low unknown) false = some env := by
  repeat' constructor

-- リテラル・負号・両端を独立した端点で確かめる。幅付きの範囲を新たに認定しない。
example :
    integerPatternRange (.integer ⟨7, by decide⟩) = normalize 7 7 ∧
    integerPatternRange (.negInt ⟨9223372036854775808, by decide⟩) = normalize min64 min64 ∧
    integerPatternRange (.integer ⟨9223372036854775807, by decide⟩) = normalize max64 max64 ∧
    integerPatternRange (.range (.integer ⟨-2, by decide⟩) (.integer ⟨3, by decide⟩)) =
      normalize (-2) 3 ∧
    integerPatternRange (.range (.integer ⟨3, by decide⟩) (.integer ⟨-2, by decide⟩)) = .bottom ∧
    integerPatternRange (.range (.integer8 1) (.integer8 2)) = top ∧
    matchRange (.base .integer8) (normalize 1 2) (.integer ⟨1, by decide⟩) = top ∧
    ((Pattern.range (.integer8 1) (.integer8 2)).toCore.matchVal
      (.const (.integer ⟨1, by decide⟩))) = none := by
  repeat' constructor

-- 各選択肢との交差を先に取り、未到達の選択肢から凸包を作らない。
-- 到達する二つの範囲の間の穴は保持しない。
example :
    let alts : List Alternative :=
      [⟨.integer ⟨0, by decide⟩, []⟩, ⟨.integer ⟨10, by decide⟩, []⟩]
    let env := AbstractEnv.ofLocals [.integer top]
    let read := fun normal alternatives =>
      (matchArmEnv env (.local 0) (.base .integer) normal alternatives).map
        (fun inner => integerAt inner 0)
    read (normalize 4 6) alts = none ∧
    read (normalize 0 10) alts = some (normalize 0 10) ∧
    read top [] = none := by
  repeat' constructor

-- 腕ごとに同じ元環境から入る。先の腕で0に照合しても、後のwildcardから0を除かない。
-- 選択肢合流では元の別名・専用位置を保存し、対象の一位置だけを絞る。
example :
    let env := AbstractEnv.ofLocals [.integer (normalize (-5) 5),
      .integer (normalize (-5) 5), .builder .string]
    let zero : List Alternative := [⟨.integer ⟨0, by decide⟩, []⟩]
    let other : List Alternative := [⟨.wild, []⟩]
    let ends : List Alternative :=
      [⟨.range (.integer ⟨-5, by decide⟩) (.integer ⟨-3, by decide⟩), []⟩,
       ⟨.range (.integer ⟨3, by decide⟩) (.integer ⟨5, by decide⟩), []⟩]
    let read := fun alts => (matchArmEnv env (.paren (.local 0)) (.base .integer)
      (normalize (-5) 5) alts).map fun inner =>
        (integerAt inner 0, integerAt inner 1, inner.locals.length)
    [zero, other, ends].map read =
      [some (normalize 0 0, normalize (-5) 5, 3),
       some (normalize (-5) 5, normalize (-5) 5, 3),
       some (normalize (-5) 5, normalize (-5) 5, 3)] ∧
    (matchArmEnv env (.local 0) (.base .integer) (normalize 1 2) zero).isNone = true := by
  repeat' constructor

-- 単独のパターン変数は照合時の区間をコピーし、元の参照は追加した位置だけずれる。
-- 幅付き整数の変数は型だけを持ち、Integer64の区間を流用しない。
example :
    let env := AbstractEnv.ofLocals [.integer (normalize (-5) 5), .builder .string]
    let widthEnv := AbstractEnv.ofLocals [.unknown (some (.base .integer8)), .builder .string]
    let singleVar : List Alternative := [⟨.var, [0]⟩]
    (matchArmEnv env (.local 0) (.base .integer) (normalize 1 3) singleVar).map
      (fun inner => (integerAt inner 0, integerAt inner 1, inner.locals.length)) =
      some (normalize 1 3, normalize 1 3, 3) ∧
    (matchArmEnv widthEnv (.local 0) (.base .integer8) (normalize 1 3) singleVar).map
      (fun inner => (integerAt inner 0, integerAt inner 1, inner.locals.length)) =
      some (top, top, 3) ∧
    (matchArmEnv env (.local 0) (.base .integer) .bottom singleVar).isNone = true := by
  repeat' constructor

-- slotsは左からの位置を選んだ後に反転する。恒等と交換で独立した二値の順が変わる。
-- 範囲外のslotを成功にせず、構造パターンの内部の型や整数を推測しない。
example :
    let env := AbstractEnv.ofLocals [.integer (normalize 99 99), .builder .string]
    let slots := [AbstractSlot.integer (normalize 11 11), .integer (normalize 22 22)]
    let read := fun positions => (extendMatchSlots env slots positions).map fun inner =>
      (integerAt inner 0, integerAt inner 1, integerAt inner 2, inner.locals.length)
    read [0, 1] = some (normalize 22 22, normalize 11 11, normalize 99 99, 4) ∧
    read [1, 0] = some (normalize 11 11, normalize 22 22, normalize 99 99, 4) ∧
    (extendMatchSlots env slots [2]).isNone = true ∧
    (matchPatternSlots (.record "Example.Pair" 2 [1, 0] [.var, .var])
      (.data "Example.Pair" []) (normalize 1 3)).length = 2 ∧
    (matchPatternSlots .wild (.base .integer) (normalize 1 3)).length = 0 := by
  repeat' constructor

end Benitoite.Interval
