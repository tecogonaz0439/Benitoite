import Benitoite.Release.Effect
import Benitoite.Release.Order.Atoms

/-!
# 範囲の格納方式の比較: 案 (i) の独立したモデル

案 (i) は、範囲を既存の構成子の引数に置く（`Atom.name l r`、`Ty.opaque o r`）。本ファイルは比較のための
独立のモデルであり、`Release` の定義を変えない。旧の原子・効果・不透明型を Top の範囲へ写す対応と、
非 Top のパスの完全一致の例を置く。範囲の領域は比較に要る最小限（Top とパスの完全一致）に限り、
最終の対象分類は別に定める。採用は決めていない（L00.01 の比較。設計書には未反映）。
-/

namespace Benitoite.Scope.RepresentationExamples.CandidateI

open Benitoite.Release

/-! ## 範囲 -/

/-- 閉じた範囲。`top` は同じ種類の全対象、`pathExact` は解析済みのパスの要素列の完全一致。 -/
inductive ScopeRange where
  | top
  | pathExact (stem : List String)
  deriving DecidableEq, Repr

namespace ScopeRange

/-- 対象（解析済みのパスの要素列）の所属。 -/
def Mem : ScopeRange → List String → Prop
  | .top, _ => True
  | .pathExact s, p => p = s

/-- 一原子による被覆。`within r s` は、s が r の全対象を丸ごと覆うことを構造で判定する。 -/
def within : ScopeRange → ScopeRange → Bool
  | _, .top => true
  | .pathExact s, .pathExact t => s == t
  | .top, .pathExact _ => false

theorem within_sound {r s : ScopeRange} (h : within r s = true) {p : List String} (hp : Mem r p) :
    Mem s p := by
  cases r <;> cases s <;> simp_all [within, Mem]

theorem within_refl (r : ScopeRange) : within r r = true := by
  cases r <;> simp [within]

theorem within_trans {r s t : ScopeRange} (h₁ : within r s = true) (h₂ : within s t = true) :
    within r t = true := by
  cases r <;> cases s <;> cases t <;> simp_all [within]

/-- 範囲の符号。原子の固定順序（`Release.Order.Atoms`）の単射性に範囲の分を加える費用を示す。 -/
def code : ScopeRange → Nat
  | .top => 0
  | .pathExact stem => wordsCode stem + 1
where
  wordsCode : List String → Nat
    | [] => 0
    | x :: xs => pair (Atom.charsCode x.toList) (wordsCode xs) + 1
  pair (a b : Nat) : Nat := (a + b) * (a + b + 1) / 2 + a

end ScopeRange

/-! ## 対の符号の単射性（案 (i) が原子の順序に加える証明） -/

private theorem digit_lt (c : Char) : c.toNat + 1 < Release.Atom.codeBase := by
  have h := c.valid
  simp only [UInt32.isValidChar, Nat.isValidChar] at h
  change c.val.toNat + 1 < 1114113
  omega

/-- `Release.Order.Atoms` の非公開の補題と同じ内容。モデルを独立に保つために写した。 -/
private theorem charsCode_injective {cs ds : List Char}
    (h : Release.Atom.charsCode cs = Release.Atom.charsCode ds) : cs = ds := by
  induction cs generalizing ds with
  | nil => cases ds <;> simp_all [Release.Atom.charsCode] <;> omega
  | cons c cs ih =>
    cases ds with
    | nil => simp [Release.Atom.charsCode] at h
    | cons d ds =>
      have hc := digit_lt c
      have hd := digit_lt d
      have hr := congrArg (· % Release.Atom.codeBase) h
      simp only [Release.Atom.charsCode, Nat.add_mod, Nat.mul_mod_right, Nat.add_zero,
        Nat.mod_eq_of_lt hc, Nat.mod_eq_of_lt hd] at hr
      have he : c = d := Char.toNat_inj.mp (by omega)
      subst d
      have ht : Release.Atom.charsCode cs = Release.Atom.charsCode ds := by
        simp only [Release.Atom.charsCode, Release.Atom.codeBase] at h
        omega
      exact congrArg (c :: ·) (ih ht)

private def tri : Nat → Nat
  | 0 => 0
  | n + 1 => tri n + n + 1

private theorem tri_lt {n m : Nat} (h : n < m) : tri n + n < tri m := by
  induction m with
  | zero => omega
  | succ m ih =>
    simp only [tri]
    by_cases hm : n = m
    · subst hm; omega
    · have := ih (by omega); omega

private theorem tri_eq_div (n : Nat) : tri n = n * (n + 1) / 2 := by
  induction n with
  | zero => rfl
  | succ n ih =>
    simp only [tri, ih]
    have : (n + 1) * (n + 1 + 1) = n * (n + 1) + 2 * (n + 1) := by
      simp only [Nat.mul_add, Nat.add_mul, Nat.mul_one, Nat.one_mul]; omega
    rw [this, Nat.add_mul_div_left _ _ (by decide)]
    omega

theorem pair_injective {a b c d : Nat} (h : ScopeRange.code.pair a b = ScopeRange.code.pair c d) :
    a = c ∧ b = d := by
  simp only [ScopeRange.code.pair, ← tri_eq_div] at h
  have hs : a + b = c + d := by
    by_cases h1 : a + b < c + d
    · have := tri_lt h1; omega
    · by_cases h2 : c + d < a + b
      · have := tri_lt h2; omega
      · omega
  rw [hs] at h
  omega

private theorem wordsCode_injective {xs ys : List String}
    (h : ScopeRange.code.wordsCode xs = ScopeRange.code.wordsCode ys) : xs = ys := by
  induction xs generalizing ys with
  | nil => cases ys <;> simp_all [ScopeRange.code.wordsCode]
  | cons x xs ih =>
    cases ys with
    | nil => simp [ScopeRange.code.wordsCode] at h
    | cons y ys =>
      have hp := pair_injective (show ScopeRange.code.pair (Atom.charsCode x.toList)
          (ScopeRange.code.wordsCode xs) =
        ScopeRange.code.pair (Atom.charsCode y.toList) (ScopeRange.code.wordsCode ys) by
          simp only [ScopeRange.code.wordsCode] at h; omega)
      rw [String.toList_inj.mp (charsCode_injective hp.1), ih hp.2]

theorem ScopeRange.code_injective {r s : ScopeRange} (h : r.code = s.code) : r = s := by
  cases r <;> cases s <;> simp_all [ScopeRange.code]
  exact wordsCode_injective h

/-! ## 原子と旧の原子との対応 -/

/-- 案 (i) の原子。旧 `Release.Atom.name l` に範囲の引数を加える。行変数は範囲を持たない。
`other a` は、本番の原子が範囲の位置 `Ix` を持つようになった後（L10.2）の、本番の非 Top の名前の原子を
そのまま運ぶ。本モデルの範囲 `ScopeRange` は本番の範囲を表さないので、埋め込みを単射に保つための構成子であり、
被覆と所属には使わない。 -/
inductive Atom where
  | name (l : EffName) (r : ScopeRange)
  | rho (i : Nat)
  | other (a : Release.Atom)
  deriving DecidableEq, Repr

namespace Atom

/-- 本番の原子を写す。本番の Top の名前の原子はモデルの Top の原子へ、非 Top の名前の原子は `other` へ写す。 -/
def ofRelease : Release.Atom → Atom
  | .name l ix => if ix = .fixed .top then .name l .top else .other (.name l ix)
  | .rho i => .rho i

/-- Top の原子と、`other` が運ぶ本番の非 Top の名前の原子だけが本番の原子へ戻る。モデルの非 Top の原子は
本番の表現を持たない。 -/
def toRelease? : Atom → Option Release.Atom
  | .name l .top => some (.nameTop l)
  | .name _ (.pathExact _) => none
  | .rho i => some (.rho i)
  | .other (.name l ix) => if ix = .fixed .top then none else some (.name l ix)
  | .other (.rho _) => none

theorem toRelease_ofRelease (a : Release.Atom) : (ofRelease a).toRelease? = some a := by
  cases a with
  | name l ix => by_cases h : ix = .fixed .top <;> simp [ofRelease, toRelease?, h]
  | rho i => rfl

theorem ofRelease_injective {a b : Release.Atom} (h : ofRelease a = ofRelease b) : a = b := by
  have := congrArg toRelease? h
  simpa [toRelease_ofRelease] using this

theorem toRelease_eq_some {a : Atom} {b : Release.Atom} (h : a.toRelease? = some b) :
    a = ofRelease b := by
  cases a with
  | name l r => cases r <;> simp_all [toRelease?, ofRelease]; subst h; rfl
  | rho i => simp_all [toRelease?]; subst h; rfl
  | other x =>
    cases x with
    | name l ix =>
      by_cases hix : ix = .fixed .top
      · simp [toRelease?, hix] at h
      · simp only [toRelease?, hix, ↓reduceIte, Option.some.injEq] at h
        subst h; simp [ofRelease, hix]
    | rho i => simp [toRelease?] at h

/-- 範囲の被覆を原子へ持ち上げる。`within x b` は、名前が同じで b の範囲が x の範囲を覆うときだけ真。 -/
def within : Atom → Atom → Bool
  | .name l r, .name m s => l == m && ScopeRange.within r s
  | .rho i, .rho j => i == j
  | _, _ => false

/-- 名前は 3 の倍数、行変数は 3 で割って 1 余る数、`other` は 3 で割って 2 余る数。名前と範囲を対の符号で一つにする。 -/
def code : Atom → Nat
  | .name l r => 3 * ScopeRange.code.pair (Release.Atom.charsCode l.toList) r.code
  | .rho i => 3 * i + 1
  | .other a => 3 * Release.Atom.code a + 2

theorem code_injective {a b : Atom} (h : code a = code b) : a = b := by
  cases a with
  | name l r =>
    cases b with
    | name m s =>
      have hp := pair_injective (show ScopeRange.code.pair (Release.Atom.charsCode l.toList) r.code =
        ScopeRange.code.pair (Release.Atom.charsCode m.toList) s.code by simp only [code] at h; omega)
      rw [String.toList_inj.mp (charsCode_injective hp.1), ScopeRange.code_injective hp.2]
    | rho j => simp only [code] at h; omega
    | other y => simp only [code] at h; omega
  | rho i =>
    cases b with
    | name m s => simp only [code] at h; omega
    | rho j => have : i = j := by simp only [code] at h; omega
               subst this; rfl
    | other y => simp only [code] at h; omega
  | other x =>
    cases b with
    | name m s => simp only [code] at h; omega
    | rho j => simp only [code] at h; omega
    | other y =>
      have : Release.Atom.code x = Release.Atom.code y := by simp only [code] at h; omega
      rw [Release.Atom.code_injective this]

end Atom

/-! ## 効果と旧の効果との対応 -/

/-- 本番の名前と行の所属関数を写す。本番の Top の原子はモデルの Top の原子へ、非 Top の名前の原子は `other` へ写す。 -/
def liftAtoms (a : Release.Atom → Bool) : Atom → Bool
  | .name l .top => a (.nameTop l)
  | .name _ (.pathExact _) => false
  | .rho i => a (.rho i)
  | .other (.name l ix) => if ix = .fixed .top then false else a (.name l ix)
  | .other (.rho _) => false

theorem liftAtoms_ofRelease (a : Release.Atom → Bool) (x : Release.Atom) :
    liftAtoms a (Atom.ofRelease x) = a x := by
  cases x with
  | name l ix =>
    by_cases h : ix = .fixed .top
    · subst h; rfl
    · simp [Atom.ofRelease, liftAtoms, h]
  | rho i => rfl

theorem liftAtoms_injective {a b : Release.Atom → Bool} (h : liftAtoms a = liftAtoms b) : a = b := by
  funext x
  rw [← liftAtoms_ofRelease a x, ← liftAtoms_ofRelease b x, h]

/-- 旧の効果から写した所属は、非 Top の原子を含まない。 -/
theorem liftAtoms_nonTop (a : Release.Atom → Bool) (l : EffName) (s : List String) :
    liftAtoms a (.name l (.pathExact s)) = false := rfl

/-- 旧 `Eff.single l` は、Top の一原子の効果へ写る。 -/
theorem liftAtoms_single (l : EffName) (x : Atom) :
    liftAtoms (Release.Eff.single l).atoms x = (x == .name l .top) := by
  cases x with
  | name m r =>
    cases r with
    | top =>
      simp only [liftAtoms, Release.Eff.single, Release.Eff.ofAtoms, Release.Eff.atoms]
      by_cases h : m = l
      · subst h; simp
      · rw [beq_false_of_ne (fun e => h (by cases e; rfl)),
          beq_false_of_ne (fun e => h (by cases e; rfl))]
    | pathExact s => simp [liftAtoms]
  | rho i => rfl
  | other y =>
    cases y with
    | name m ix =>
      by_cases h : ix = .fixed .top
      · simp [liftAtoms, h]
      · simp only [liftAtoms, h, ↓reduceIte, Release.Eff.single, Release.Eff.ofAtoms,
          Release.Eff.atoms]
        rw [beq_false_of_ne (fun e => h (by cases e; rfl)), beq_false_of_ne (fun e => by cases e)]
    | rho i => simp [liftAtoms]

/-- 有限の原子列で表した上限が原子を許す。上限のいずれか一原子が丸ごと覆う（保守的な被覆）。 -/
def allows (ε : List Atom) (x : Atom) : Bool := ε.any (fun b => Atom.within x b)

/-! ## 標準値型と旧の不透明型との対応 -/

/-- 案 (i) の不透明型の部分。旧 `Ty.opaque o` に範囲の引数を加える。比較に要る構成子だけを置く。 -/
inductive ValTy where
  | opaque (o : OpaqueName) (r : ScopeRange)
  deriving DecidableEq, Repr

/-- 旧の不透明型を Top の範囲で写す。 -/
def ValTy.ofReleaseOpaque (o : OpaqueName) : ValTy := .opaque o .top

/-- 標準の所有元が認定する範囲付きの値型の名前。所有元は今の不透明型と同じく名前の文字列に置く。 -/
def pathInName : OpaqueName := "Scope.PathIn"

/-- `Scope.PathIn[R]` に当たる型。旧の裸の型は Top。 -/
def pathIn (r : ScopeRange) : ValTy := .opaque pathInName r

/-- 値型の添字への所属。範囲付きの名前を持つ型だけに意味を与え、他の不透明型には所属を与えない。 -/
def ValTy.Holds : ValTy → List String → Prop
  | .opaque o r, p => o = pathInName ∧ r.Mem p

/-- 型の等号は構造の一致であり、範囲の包含から型の等号を導かない（判断 5・6）。 -/
theorem pathIn_ne_of_ne {r s : ScopeRange} (h : r ≠ s) : pathIn r ≠ pathIn s := by
  intro he
  simp [pathIn] at he
  exact h he

/-- 範囲の被覆から、同じ値の広い型への所属を得る（明示拡大の所属補題の形）。 -/
theorem holds_widen {r s : ScopeRange} (hc : ScopeRange.within r s = true) {p : List String}
    (h : (pathIn r).Holds p) : (pathIn s).Holds p :=
  ⟨h.1, ScopeRange.within_sound hc h.2⟩

/-! ## 署名の具体化（範囲の数だけ操作 ID を発行しない） -/

/-- 操作の識別子。範囲の具体化の前後で同じ識別子を使う。 -/
abbrev OpId := String

/-- 具体化した単一対象の IO の署名。入力の型と効果の原子が同じ範囲を指す。 -/
structure Sig where
  op : OpId
  input : ValTy
  effect : Atom
  deriving DecidableEq, Repr

/-- `File.readTextIn` に当たる操作の具体化。識別子は範囲に依存しない。 -/
def readTextIn (r : ScopeRange) : Sig := ⟨"File.readTextIn", pathIn r, .name "File.Read" r⟩

theorem readTextIn_op (r s : ScopeRange) : (readTextIn r).op = (readTextIn s).op := rfl

/-- 具体化した署名では、入力の添字と効果の原子が同じ範囲を指す。 -/
theorem readTextIn_same_range (r : ScopeRange) :
    ∃ o l, (readTextIn r).input = .opaque o r ∧ (readTextIn r).effect = .name l r :=
  ⟨_, _, rfl, rfl⟩

/-- 入力の所属と効果の被覆から、事象の対象が上限に入る（対象の健全性の一段の形の小さい例）。 -/
theorem readTextIn_target_allowed {r s : ScopeRange} {p : List String}
    (hin : (readTextIn r).input.Holds p) (hc : ScopeRange.within r s = true) : s.Mem p :=
  ScopeRange.within_sound hc hin.2

/-! ## 非空の例 -/

def dataA : ScopeRange := .pathExact ["data", "a"]

example : (pathIn dataA).Holds ["data", "a"] := ⟨rfl, rfl⟩
example : ¬ (pathIn dataA).Holds ["data", "b"] := by simp [ValTy.Holds, pathIn, dataA, ScopeRange.Mem]
example : (pathIn .top).Holds ["data", "b"] := ⟨rfl, trivial⟩
example : pathIn dataA ≠ pathIn .top := pathIn_ne_of_ne (by decide)
example : (pathIn .top) = ValTy.ofReleaseOpaque pathInName := rfl

#guard allows [.name "File.Read" .top] (.name "File.Read" dataA)
#guard allows [.name "File.Read" dataA] (.name "File.Read" dataA)
#guard !allows [.name "File.Read" dataA] (.name "File.Read" (.pathExact ["data", "b"]))
#guard !allows [.name "File.Read" dataA] (.name "File.Read" .top)
#guard !allows [.name "File.Write" .top] (.name "File.Read" dataA)
#guard (readTextIn dataA).effect == .name "File.Read" dataA
#guard Atom.toRelease? (.name "File.Read" dataA) == none
#guard Atom.toRelease? (Atom.ofRelease (.nameTop "File.Read")) == some (.nameTop "File.Read")
#guard liftAtoms (Release.Eff.single "File.Read").atoms (.name "File.Read" .top)
#guard !liftAtoms (Release.Eff.single "File.Read").atoms (.name "File.Read" dataA)

end Benitoite.Scope.RepresentationExamples.CandidateI
