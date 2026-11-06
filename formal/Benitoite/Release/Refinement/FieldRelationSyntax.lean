import Benitoite.Release.Refinement.ClosedEvaluation

/-! # 欄の観測を結ぶ述語と移送できる原子 -/
namespace Benitoite.Release.Refinement

/-- 二つの二値の判定が一致することを、既存の論理結合で表す。 -/
def predicateIff (p q : Pred) : Pred :=
  .or (.and p q) (.and (.not p) (.not q))

/-- Float の等号は NaN 同士を含み、六つの分類はゼロの符号も区別する。 -/
def floatFieldRelation (w : FloatWidth) (a b : Term) : Pred :=
  .and (.or (.compare (match w with | .binary32 => .float32 | .binary64 => .float64) .eq a b)
    (.and (.floatClass w .nan a) (.floatClass w .nan b)))
    ([FloatClass.finite, .nan, .positiveInfinity, .negativeInfinity, .positiveZero, .negativeZero].foldr
      (fun c p => .and (predicateIff (.floatClass w c a) (.floatClass w c b)) p) .truth)

/-- 構成子の有限列の各判定を保存する。 -/
def constructorFieldRelation (cs : List ConName) (a b : Term) : Pred :=
  cs.foldr (fun c p => .and (predicateIff (.constructorIs a c) (.constructorIs b c)) p) .truth

/-- 値の比較と、その sort で観測できる測度を結ぶ。 -/
def fieldRelation (s : «Sort») (cs : List ConName) (m : Option Measure) (a b : Term) : Pred :=
  match m with
  | some m => .eq (.measure m a) (.measure m b)
  | none => match s with
    | .integer => .eq a b
    | .float64 => floatFieldRelation .binary64 a b
    | .float32 => floatFieldRelation .binary32 a b
    | .character => .and (.compare .character .eq a b) (.eq (.measure .characterCode a) (.measure .characterCode b))
    | .string => .and (.compare .string .eq a b)
        (.and (.eq (.measure .stringBytes a) (.measure .stringBytes b))
          (.eq (.measure .stringCharacters a) (.measure .stringCharacters b)))
    | .decimal | .boolean | .unit => .compare s .eq a b
    | .list => .eq (.measure .listLength a) (.measure .listLength b)
    | .bytes => .eq (.measure .bytesLength a) (.measure .bytesLength b)
    | .map => .eq (.measure .mapSize a) (.measure .mapSize b)
    | .set => .eq (.measure .setSize a) (.measure .setSize b)
    | .data => constructorFieldRelation cs a b
    | .target _ => .truth

/-- 測度の入力 sort と、data の空でない構成子列を照合する。対象の所属は列挙しない。 -/
def FieldRelation.Valid (s : «Sort») (cs : List ConName) : Option Measure → Prop
  | some m => s = m.input
  | none => match s with | .target _ => False | .data => cs ≠ [] | _ => True

instance (s : «Sort») (cs : List ConName) (m : Option Measure) :
    Decidable (FieldRelation.Valid s cs m) := by
  cases m with
  | some m => exact inferInstanceAs (Decidable (s = m.input))
  | none => cases s <;> simp only [FieldRelation.Valid] <;> infer_instance

/-- 関係の形成から、両辺の元の sort を取り出す。 -/
theorem fieldRelation_sorted {Γ : Ctx} {s : «Sort»} {cs : List ConName} {m : Option Measure}
    {a b : Term} (valid : FieldRelation.Valid s cs m)
    (h : (fieldRelation s cs m a b).Sorted Γ none) : a.HasSort Γ s ∧ b.HasSort Γ s := by
  cases m with
  | some m =>
      subst s
      exact ⟨⟨h.1.1,h.1.2.1⟩,⟨h.2.1,h.2.2.1⟩⟩
  | none =>
      cases s with
      | integer => exact h
      | character | string => exact h.1.2
      | decimal | boolean | unit => exact h.2
      | float64 | float32 => exact h.1.1.2
      | list | bytes | map | set => exact ⟨⟨h.1.1,h.1.2.1⟩,⟨h.2.1,h.2.2.1⟩⟩
      | data =>
          cases cs with
          | nil => exact False.elim (valid rfl)
          | cons c cs => exact h.1.1
      | target k => exact False.elim valid

@[simp] theorem predicateIff_bind (ν : ObservationEnv) (p q : Pred) :
    predBind ν (predicateIff p q) = predicateIff (predBind ν p) (predBind ν q) := rfl

@[simp] theorem floatFieldRelation_bind (ν : ObservationEnv) (w : FloatWidth) (a b : Term) :
    predBind ν (floatFieldRelation w a b) = floatFieldRelation w (termBind ν a) (termBind ν b) := rfl

@[simp] theorem constructorFieldRelation_bind (ν : ObservationEnv) (cs : List ConName) (a b : Term) :
    predBind ν (constructorFieldRelation cs a b) = constructorFieldRelation cs (termBind ν a) (termBind ν b) := by
  induction cs with
  | nil => rfl
  | cons c cs ih => simp only [constructorFieldRelation, List.foldr_cons, predBind, predicateIff_bind] at *; rw [ih]

@[simp] theorem fieldRelation_bind (ν : ObservationEnv) (s : «Sort») (cs : List ConName)
    (m : Option Measure) (a b : Term) :
    predBind ν (fieldRelation s cs m a b) = fieldRelation s cs m (termBind ν a) (termBind ν b) := by
  cases m with
  | some m => rfl
  | none => cases s <;> simp [fieldRelation, predBind, floatFieldRelation_bind, constructorFieldRelation_bind]

/-- 数値又は値の等号で比較の結果を保存する sort。 -/
def FieldRelation.Scalar (s : «Sort») : Prop :=
  s = .character ∨ s = .decimal ∨ s = .float64 ∨ s = .float32 ∨
    s = .boolean ∨ s = .string ∨ s = .unit

/-- 欄の関係の下で同じ二値を返す原子の組。比較のもう一方の項は固定する。 -/
inductive FieldAtom : «Sort» → List ConName → Term → Term → Pred → Pred → Prop where
  | compareLeft {s cs a b} (hs : FieldRelation.Scalar s) (o : Comparison) (t : Term) :
      FieldAtom s cs a b (.compare s o a t) (.compare s o b t)
  | compareRight {s cs a b} (hs : FieldRelation.Scalar s) (o : Comparison) (t : Term) :
      FieldAtom s cs a b (.compare s o t a) (.compare s o t b)
  | charactersIn {cs a b} (lo hi : Char) :
      FieldAtom .string cs a b (.charactersIn a lo hi) (.charactersIn b lo hi)
  | floatClass {cs a b} (w : FloatWidth) (c : FloatClass) :
      FieldAtom (match w with | .binary32 => .float32 | .binary64 => .float64) cs a b
        (.floatClass w c a) (.floatClass w c b)
  | constructorIs {cs a b} (c : ConName) (hc : c ∈ cs) :
      FieldAtom .data cs a b (.constructorIs a c) (.constructorIs b c)
  | reverse {s cs a b p q} : FieldAtom s cs a b p q → FieldAtom s cs a b q p

/-- 原子の組の構文上の条件は同時置換で保存される。 -/
theorem FieldAtom.bind {s cs a b p q} (h : FieldAtom s cs a b p q) (ν : ObservationEnv) :
    FieldAtom s cs (termBind ν a) (termBind ν b) (predBind ν p) (predBind ν q) := by
  induction h with
  | compareLeft hs o t => exact .compareLeft hs o (termBind ν t)
  | compareRight hs o t => exact .compareRight hs o (termBind ν t)
  | charactersIn lo hi => exact .charactersIn lo hi
  | floatClass w c => exact .floatClass w c
  | constructorIs c hc => exact .constructorIs c hc
  | reverse _ ih => exact .reverse ih

end Benitoite.Release.Refinement
