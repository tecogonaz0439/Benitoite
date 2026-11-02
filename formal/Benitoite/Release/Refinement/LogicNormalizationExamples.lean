import Benitoite.Release.Refinement.LogicNormalization

/-! # 否定標準形の全構成子と置換像の具体の読者 -/
namespace Benitoite.Release.Refinement.LogicNormalizationExamples

private def scalar : Pred := .compare .float64 .lt (.float64 0x7ff8000000000000) (.float64 0)
private def category : Pred := .floatClass .binary64 .negativeZero (.float64 0x8000000000000000)
private def decimal : Pred := .decimalRepresented (.decimal 123 2)
private def characters : Pred := .charactersIn (.string "abc") 'a' 'z'
private def membership : Pred := .member .path (.var 0) .top
private def constructor : Pred := .constructorIs (.dataValue "C" []) "C"
private def belowOne : Pred := .lt (.var 0) (.integer 1)
private def differentThree : Pred := .not (.eq (.var 0) (.integer 3))

-- 出力を実装から作らず、整数の境界と原子の符号を表に明記する。
private def cases28 : List (Pred × Bool × NNF) :=
  [(.truth, false, .truth), (.truth, true, .falsity),
   (.falsity, false, .falsity), (.falsity, true, .truth),
   (.eq (.var 0) (.integer 2), false, .and (.linear ⟨[1],2⟩) (.linear ⟨[-1],-2⟩)),
   (.eq (.var 0) (.integer 2), true, .or (.linear ⟨[1],1⟩) (.linear ⟨[-1],-3⟩)),
   (.le (.var 0) (.integer 2), false, .linear ⟨[1],2⟩),
   (.le (.var 0) (.integer 2), true, .linear ⟨[-1],-3⟩),
   (.lt (.var 0) (.integer 2), false, .linear ⟨[1],1⟩),
   (.lt (.var 0) (.integer 2), true, .linear ⟨[-1],-2⟩),
   (scalar, false, .literal scalar false), (scalar, true, .literal scalar true),
   (category, false, .literal category false), (category, true, .literal category true),
   (decimal, false, .literal decimal false), (decimal, true, .literal decimal true),
   (characters, false, .literal characters false), (characters, true, .literal characters true),
   (membership, false, .literal membership false), (membership, true, .literal membership true),
   (constructor, false, .literal constructor false), (constructor, true, .literal constructor true),
   (.and belowOne differentThree, false,
      .and (.linear ⟨[1],0⟩) (.or (.linear ⟨[1],2⟩) (.linear ⟨[-1],-4⟩))),
   (.and belowOne differentThree, true,
      .or (.linear ⟨[-1],-1⟩) (.and (.linear ⟨[1],3⟩) (.linear ⟨[-1],-3⟩))),
   (.or belowOne differentThree, false,
      .or (.linear ⟨[1],0⟩) (.or (.linear ⟨[1],2⟩) (.linear ⟨[-1],-4⟩))),
   (.or belowOne differentThree, true,
      .and (.linear ⟨[-1],-1⟩) (.and (.linear ⟨[1],3⟩) (.linear ⟨[-1],-3⟩))),
   (.not membership, false, .literal membership true),
   (.not membership, true, .literal membership false)]

private theorem cases28_checked : cases28.length = 28 ∧ cases28.all (fun (p,negative,expected) =>
    (normalize [.var 0] p negative).any (fun actual =>
      predEq (actual.toPred [.var 0]) (expected.toPred [.var 0]))) = true := by decide

-- 実際の正規化の成功と構造比較から、期待した28出力の意味へ接続する。
example (ν : ObservationEnv) (η : ObservationEnvModel) :
    ∀ entry ∈ cases28,
      (predBind ν (entry.2.2.toPred [.var 0])).interpret η =
        (if entry.2.1 then !((predBind ν entry.1).interpret η)
          else (predBind ν entry.1).interpret η) := by
  intro entry he
  have checked := List.all_eq_true.mp cases28_checked.2 entry he
  cases hn : normalize [.var 0] entry.1 entry.2.1 with
  | none => simp [hn] at checked
  | some q =>
    have heq : q.toPred [.var 0] = entry.2.2.toPred [.var 0] :=
      (predEq_spec _ _).mp (by simpa [hn] using checked)
    rw [← heq]
    exact normalize_sound_at hn ν η

-- 整数の厳密境界と二重否定をDe Morganと同時に読む。
example : normalize [.var 0] (.not (.and belowOne differentThree)) false =
    some (.or (.linear ⟨[-1],-1⟩) (.and (.linear ⟨[1],3⟩) (.linear ⟨[-1],-3⟩))) := rfl

-- 正規化した線形の葉の真から、列長の証拠なしにHoldsを取り出す。
example (ν : ObservationEnv) (η : ObservationEnvModel)
    (h : (predBind ν belowOne).interpret η = true) :
    (Linear.mk [1] 0).Holds (keyEnv η ([.var 0].map (termBind ν))) := by
  have hn : normalize [.var 0] belowOne false = some (.linear ⟨[1],0⟩) := rfl
  have hp := normalize_sound_at hn ν η
  have encoded : (predBind ν ((Linear.mk [1] 0).toPred [.var 0])).interpret η = true := hp.trans h
  exact (Linear.toPred_sound_at η ν _ _).mp encoded

-- Andから取り出した二つの葉を、同じ鍵の整数環境で非負結合する。
private def bounds : Pred := .and (.le (.var 0) (.integer 2)) (.le (.integer 1) (.var 0))
example (ν : ObservationEnv) (η : ObservationEnvModel)
    (h : (predBind ν bounds).interpret η = true) :
    (Linear.mk [1] 3).Holds (keyEnv η ([.var 0].map (termBind ν))) := by
  have hn : normalize [.var 0] bounds false =
      some (.and (.linear ⟨[1],2⟩) (.linear ⟨[-1],-1⟩)) := rfl
  have hp := normalize_sound_at hn ν η
  have encoded : (predBind ν ((NNF.and (.linear ⟨[1],2⟩)
      (.linear ⟨[-1],-1⟩)).toPred [.var 0])).interpret η = true := hp.trans h
  simp only [NNF.toPred, predBind, Pred.interpret, Bool.and_eq_true] at encoded
  have left := (Linear.toPred_sound_at η ν [.var 0] (Linear.mk [1] 2)).mp encoded.1
  have right := (Linear.toPred_sound_at η ν [.var 0] (Linear.mk [-1] (-1))).mp encoded.2
  have combined := integer_combination (k := 2) (l := 1) (by decide) (by decide) left right
  simp only [Linear.Holds, Linear.eval, linearDot] at combined ⊢
  omega

-- 不等号の負側を逆向きの非厳密比較へ変えるとNaNで意味が変わる。
example : scalar.interpret (fun _ => none) = false ∧
    (.not scalar : Pred).interpret (fun _ => none) = true ∧
    (.compare .float64 .ge (.float64 0x7ff8000000000000) (.float64 0) : Pred).interpret
      (fun _ => none) = false := by decide

-- 未観測の対象の原子を、正規化の際に定数へ変えない。
example : (normalize [] membership false).any (fun q =>
    predEq (q.toPred []) membership) = true ∧
    (Term.var 0).observe (fun _ => none) = none := by decide

-- 既知の変数なら成功し、同じ比較の未知鍵なら拒否する。
example : (normalize [.var 0] (.lt (.var 0) (.integer 2)) false).isSome = true ∧
    (normalize [] (.lt (.var 0) (.integer 2)) false).isNone = true := by decide

private def affinePredicate : Pred := .eq (.add (.var 0) (.integer 1)) (.var 1)
private def affineNNF : NNF :=
  .and (.linear ⟨[1,-1],-1⟩) (.linear ⟨[-1,1],1⟩)
private theorem affine_normalizes : normalize [.var 0,.var 1] affinePredicate false = some affineNNF := rfl

-- 元の鍵二つが衝突する像、定数と新しく一致する像、加算の像、snapshot内への像。
private def collision : ObservationEnv := fun _ => some (.var 2)
private def freshMatch : ObservationEnv := fun i =>
  if i = 0 then some (.integer 1) else some (.var 0)
private def addition : ObservationEnv := fun i =>
  if i = 0 then some (.add (.var 1) (.var 2)) else some (.var i)
private def intoSnapshot : ObservationEnv := fun i =>
  if i = 0 then some (.measure .setSize (.setValue [some (.var 1)])) else some (.var i)
example (η : ObservationEnvModel) :
    ((predBind collision (affineNNF.toPred [.var 0,.var 1])).interpret η =
      (predBind collision affinePredicate).interpret η) ∧
    ((predBind freshMatch (affineNNF.toPred [.var 0,.var 1])).interpret η =
      (predBind freshMatch affinePredicate).interpret η) ∧
    ((predBind addition (affineNNF.toPred [.var 0,.var 1])).interpret η =
      (predBind addition affinePredicate).interpret η) ∧
    ((predBind intoSnapshot (affineNNF.toPred [.var 0,.var 1])).interpret η =
      (predBind intoSnapshot affinePredicate).interpret η) :=
  ⟨normalize_sound_at affine_normalizes collision η,
   normalize_sound_at affine_normalizes freshMatch η,
   normalize_sound_at affine_normalizes addition η,
   normalize_sound_at affine_normalizes intoSnapshot η⟩
example (η : ObservationEnvModel) :
    (affineNNF.toPred [.var 0,.var 1]).interpret η = affinePredicate.interpret η :=
  normalize_sound affine_normalizes η

end Benitoite.Release.Refinement.LogicNormalizationExamples
