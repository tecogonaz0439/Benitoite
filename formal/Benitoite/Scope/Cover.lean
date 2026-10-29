import Benitoite.Scope.Domain

/-!
# 一原子の被覆の判定: パスとホスト名

範囲付きのエフェクトの包含は、左の各原子を右のいずれか一原子が丸ごと覆うことで判定する（判断 5）。
本ファイルは、その一原子の被覆のうち、パスのパターン（`PathPattern`）とホスト名のパターン（`NamePattern`）の
判定を定める（L00.02 の義務 3 のうちパスとホスト名）。IP・ポート・エンドポイント・`Range` 全体の被覆は
後の枝で同じ形に足す。

`p.Covers q` は「外側のパターン p が内側のパターン q を丸ごと覆う」の意味であり、引数の順は外側が先である
（意味の包含 `Range.Sub r s` は内側が先なので、向きが逆になる）。判定 `covers?` は Bool の関数であり、
`covers?_spec` で `Covers` と同値である。健全性は「覆うなら所属が包含される」、反射と推移は判定の性質である。
パスとホスト名では、任意の要素の列を対象とする所属について、判定は完全でもある（所属の包含なら覆う。
`covers_iff`）。完全性は整形式性を前提にしない所属についての言明であり、整形式の対象だけに限った所属の
包含については述べない。

名前の扱いは `Domain.lean` の先頭のコメントに従い、名前空間 `Benitoite.Scope.Domain` の中に置く。
-/

namespace Benitoite.Scope.Domain

/-! ## パス -/

namespace PathPattern

/-- 外側 p が内側 q を覆う。exact は同じ幹の exact だけを覆い、tree は幹が前方の部分列になる exact と tree を
覆う。exact は tree を覆わない（tree は幹の子を含むため）。 -/
def Covers : PathPattern → PathPattern → Prop
  | .exact s, .exact t => t = s
  | .tree s, .exact t => ∃ rest, t = s ++ rest
  | .tree s, .tree t => ∃ rest, t = s ++ rest
  | .exact _, .tree _ => False

/-- 被覆の判定。 -/
def covers? : PathPattern → PathPattern → Bool
  | .exact s, .exact t => decide (t = s)
  | .tree s, .exact t => s.isPrefixOf t
  | .tree s, .tree t => s.isPrefixOf t
  | .exact _, .tree _ => false

theorem covers?_spec (p q : PathPattern) : p.covers? q = true ↔ p.Covers q := by
  cases p <;> cases q <;>
    simp only [covers?, Covers, decide_eq_true_eq, List.isPrefixOf_iff_prefix, List.IsPrefix,
      Bool.false_eq_true] <;>
    exact exists_congr fun _ => eq_comm

instance (p q : PathPattern) : Decidable (p.Covers q) := decidable_of_iff _ (covers?_spec p q)

/-- 内側が exact のときの被覆は、外側への所属と同じである。 -/
theorem covers_exact_iff (p : PathPattern) (t : Word) : p.Covers (.exact t) ↔ p.Matches t := by
  cases p <;> simp only [Covers, Matches]

/-- 健全性: 覆うなら、内側に所属する対象は外側に所属する。 -/
theorem Covers.sound {p q : PathPattern} (h : p.Covers q) {w : Word} (hw : q.Matches w) : p.Matches w := by
  match p, q, h, hw with
  | .exact _, .exact _, h, hw => exact hw.trans h
  | .tree _, .exact _, ⟨r, h⟩, hw => exact ⟨r, hw.trans h⟩
  | .tree _, .tree _, ⟨r, h⟩, ⟨r', hw⟩ => exact ⟨r ++ r', by rw [hw, h]; simp⟩

theorem Covers.refl (p : PathPattern) : p.Covers p := by
  cases p with
  | exact s => rfl
  | tree s => exact ⟨[], by simp⟩

theorem Covers.trans {p q r : PathPattern} (h₁ : p.Covers q) (h₂ : q.Covers r) : p.Covers r := by
  cases p <;> cases q <;> cases r <;> simp only [Covers] at h₁ h₂ ⊢
  · exact h₂.trans h₁
  · obtain ⟨x, rfl⟩ := h₁; subst h₂; exact ⟨x, rfl⟩
  · obtain ⟨x, rfl⟩ := h₁; obtain ⟨y, rfl⟩ := h₂; exact ⟨x ++ y, by simp⟩
  · obtain ⟨x, rfl⟩ := h₁; obtain ⟨y, rfl⟩ := h₂; exact ⟨x ++ y, by simp⟩

/-- 完全性: 任意の要素の列についての所属の包含は被覆を与える。exact が tree を含まないことは、
tree の幹とその子（`t ++ [""]`）の二つが exact の一点に入らないことから従う。 -/
theorem covers_of_sub {p q : PathPattern} (h : ∀ w, q.Matches w → p.Matches w) : p.Covers q := by
  cases q with
  | exact t => exact (covers_exact_iff p t).mpr (h t rfl)
  | tree t =>
    have h0 := h t ⟨[], by simp⟩
    cases p with
    | exact s =>
      have h1 := h (t ++ [""]) ⟨[""], rfl⟩
      simp only [Matches] at h0 h1
      rw [h0] at h1
      simp at h1
    | tree s => exact h0

theorem covers_iff (p q : PathPattern) : p.Covers q ↔ ∀ w, q.Matches w → p.Matches w :=
  ⟨fun h _ hw => h.sound hw, covers_of_sub⟩

/-- exact は tree を覆わない（幹が同じでも）。 -/
theorem exact_not_covers_tree (s t : Word) : ¬ (PathPattern.exact s).Covers (.tree t) := id

/-- tree は同じ幹の exact を覆う（木は幹自身を含む）。 -/
theorem tree_covers_exact_stem (s : Word) : (PathPattern.tree s).Covers (.exact s) := ⟨[], by simp⟩

/-- 要素の一部だけが一致する対象を覆わない: `/data/**` は `/database` も `/database/**` も覆わない。 -/
theorem data_tree_not_covers_database :
    ¬ (PathPattern.tree ["data"]).Covers (.exact ["database"]) ∧
      ¬ (PathPattern.tree ["data"]).Covers (.tree ["database"]) := by
  refine ⟨?_, ?_⟩ <;> rintro ⟨rest, h⟩ <;> simp at h

end PathPattern

/-! ## ホスト名 -/

namespace NamePattern

/-- 外側 p が内側 q を覆う（ラベル列は通常の順で、幹は末尾）。

- 内側が exact `t` のときは、外側への所属と同じ条件である。
- one `s` は one `s` だけを覆う。
- many `s` は、幹 `t` の末尾が `s` である one `t`（`t = ys ++ s`、`ys` は空でもよい）と many `t` を覆う。
- exact は one・many を覆わず、one は many を覆わない。 -/
def Covers : NamePattern → NamePattern → Prop
  | .exact s, .exact t => t = s
  | .one s, .exact t => ∃ x, t = x :: s
  | .many s, .exact t => ∃ xs, xs ≠ [] ∧ t = xs ++ s
  | .one s, .one t => t = s
  | .many s, .one t => ∃ ys, t = ys ++ s
  | .many s, .many t => ∃ ys, t = ys ++ s
  | .exact _, .one _ => False
  | .exact _, .many _ => False
  | .one _, .many _ => False

/-- 被覆の判定。内側が exact のときは所属の判定 `matches?` を使う。 -/
def covers? : NamePattern → NamePattern → Bool
  | p, .exact t => p.matches? t
  | .one s, .one t => decide (t = s)
  | .many s, .one t => s.isSuffixOf t
  | .many s, .many t => s.isSuffixOf t
  | .exact _, .one _ => false
  | .exact _, .many _ => false
  | .one _, .many _ => false

/-- 内側が exact のときの被覆は、外側への所属と同じである。 -/
theorem covers_exact_iff (p : NamePattern) (t : Word) : p.Covers (.exact t) ↔ p.Matches t := by
  cases p <;> simp only [Covers, Matches]

theorem covers?_spec (p q : NamePattern) : p.covers? q = true ↔ p.Covers q := by
  cases q with
  | exact t => simp only [covers?]; rw [matches?_spec, covers_exact_iff]
  | one t =>
    cases p <;>
      simp only [covers?, Covers, decide_eq_true_eq, List.isSuffixOf_iff_suffix, List.IsSuffix,
        Bool.false_eq_true]
    exact exists_congr fun _ => eq_comm
  | many t =>
    cases p <;>
      simp only [covers?, Covers, List.isSuffixOf_iff_suffix, List.IsSuffix, Bool.false_eq_true]
    exact exists_congr fun _ => eq_comm

instance (p q : NamePattern) : Decidable (p.Covers q) := decidable_of_iff _ (covers?_spec p q)

/-- 健全性: 覆うなら、内側に所属する対象は外側に所属する。 -/
theorem Covers.sound {p q : NamePattern} (h : p.Covers q) {w : Word} (hw : q.Matches w) : p.Matches w := by
  cases q with
  | exact t => simp only [Matches] at hw; subst hw; exact (covers_exact_iff p w).mp h
  | one t =>
    obtain ⟨x, rfl⟩ := hw
    cases p <;> simp only [Covers, Matches] at h ⊢
    · subst h; exact ⟨x, rfl⟩
    · obtain ⟨ys, rfl⟩ := h; exact ⟨x :: ys, List.cons_ne_nil _ _, rfl⟩
  | many t =>
    obtain ⟨xs, hxs, rfl⟩ := hw
    cases p <;> simp only [Covers, Matches] at h ⊢
    obtain ⟨ys, rfl⟩ := h
    exact ⟨xs ++ ys, by simp [hxs], by simp⟩

theorem Covers.refl (p : NamePattern) : p.Covers p := by
  cases p with
  | exact s => rfl
  | one s => rfl
  | many s => exact ⟨[], by simp⟩

theorem Covers.trans {p q r : NamePattern} (h₁ : p.Covers q) (h₂ : q.Covers r) : p.Covers r := by
  cases r with
  | exact t => exact (covers_exact_iff p t).mpr (h₁.sound ((covers_exact_iff q t).mp h₂))
  | one t =>
    cases q <;> cases p <;> simp only [Covers] at h₁ h₂ ⊢
    · exact h₂.trans h₁
    · subst h₂; exact h₁
    · obtain ⟨ys, rfl⟩ := h₂; obtain ⟨zs, rfl⟩ := h₁; exact ⟨ys ++ zs, by simp⟩
  | many t =>
    cases q <;> cases p <;> simp only [Covers] at h₁ h₂ ⊢
    obtain ⟨ys, rfl⟩ := h₂; obtain ⟨zs, rfl⟩ := h₁; exact ⟨ys ++ zs, by simp⟩

/-- 完全性: 任意のラベル列についての所属の包含は被覆を与える。one と many はどちらも幹の前に任意の
ラベルを置けるので一点に入らず、many は二段の対象を持つので one に入らない。 -/
theorem covers_of_sub {p q : NamePattern} (h : ∀ w, q.Matches w → p.Matches w) : p.Covers q := by
  cases q with
  | exact t => exact (covers_exact_iff p t).mpr (h t rfl)
  | one t =>
    have ha := h ("a" :: t) ⟨"a", rfl⟩
    have hb := h ("b" :: t) ⟨"b", rfl⟩
    cases p with
    | exact s =>
      simp only [Matches] at ha hb
      rw [← hb] at ha; simp at ha
    | one s =>
      simp only [Matches] at ha
      obtain ⟨x, hx⟩ := ha
      exact (List.cons.inj hx).2
    | many s =>
      simp only [Matches] at ha
      obtain ⟨xs, hxs, hx⟩ := ha
      cases xs with
      | nil => exact absurd rfl hxs
      | cons y ys => exact ⟨ys, (List.cons.inj hx).2⟩
  | many t =>
    have h1 := h (["a"] ++ t) ⟨["a"], by simp, rfl⟩
    have h2 := h (["a", "a"] ++ t) ⟨["a", "a"], by simp, rfl⟩
    cases p with
    | exact s =>
      simp only [Matches] at h1 h2
      rw [← h2] at h1; simp at h1
    | one s =>
      simp only [Matches] at h1 h2
      obtain ⟨x, hx⟩ := h1
      obtain ⟨y, hy⟩ := h2
      have l1 := congrArg List.length hx
      have l2 := congrArg List.length hy
      simp at l1 l2; omega
    | many s =>
      simp only [Matches] at h1
      obtain ⟨xs, hxs, hx⟩ := h1
      cases xs with
      | nil => exact absurd rfl hxs
      | cons y ys => exact ⟨ys, by simpa using (List.cons.inj hx).2⟩

theorem covers_iff (p q : NamePattern) : p.Covers q ↔ ∀ w, q.Matches w → p.Matches w :=
  ⟨fun h _ hw => h.sound hw, covers_of_sub⟩

/-- one と many の差: many は同じ幹の one を覆い、one は同じ幹の many を覆わない。 -/
theorem many_covers_one (s : Word) : (NamePattern.many s).Covers (.one s) := ⟨[], by simp⟩

theorem one_not_covers_many (s t : Word) : ¬ (NamePattern.one s).Covers (.many t) := id

/-- one と many は幹自身を覆わない（両ワイルドカードは幹を含まない）。 -/
theorem one_not_covers_stem (s : Word) : ¬ (NamePattern.one s).Covers (.exact s) := by
  rintro ⟨x, h⟩
  have := congrArg List.length h
  simp at this

theorem many_not_covers_stem (s : Word) : ¬ (NamePattern.many s).Covers (.exact s) := by
  rintro ⟨xs, hxs, h⟩
  have hl := congrArg List.length h
  have : 0 < xs.length := List.length_pos_iff.mpr hxs
  simp only [List.length_append] at hl; omega

/-- one は二段下の one を覆わず、many は覆う。 -/
theorem one_not_covers_deeper_one (x : String) (s : Word) :
    ¬ (NamePattern.one s).Covers (.one (x :: s)) := by
  intro h
  have := congrArg List.length h
  simp at this

theorem many_covers_deeper_one (x : String) (s : Word) :
    (NamePattern.many s).Covers (.one (x :: s)) := ⟨[x], rfl⟩

/-- exact は one・many を覆わない。 -/
theorem exact_not_covers_one (s t : Word) : ¬ (NamePattern.exact s).Covers (.one t) := id

theorem exact_not_covers_many (s t : Word) : ¬ (NamePattern.exact s).Covers (.many t) := id

end NamePattern

/-! ## 小さい具体例

`#guard` はコンパイルした判定を評価し、カーネルの展開に頼らない。
-/

-- パス: tree と exact の向き。
#guard (PathPattern.tree ["data"]).covers? (.exact ["data", "a"])
#guard (PathPattern.tree ["data"]).covers? (.exact ["data"])
#guard !(PathPattern.exact ["data"]).covers? (.tree ["data"])
#guard (PathPattern.tree ["data"]).covers? (.tree ["data", "a"])
#guard !(PathPattern.tree ["data", "a"]).covers? (.tree ["data"])
#guard (PathPattern.tree []).covers? (.tree ["etc"])
-- `/data/**` は `/database` と `/database/**` を覆わない。
#guard !(PathPattern.tree ["data"]).covers? (.exact ["database"])
#guard !(PathPattern.tree ["data"]).covers? (.tree ["database"])
-- ホスト名: one と many の差。
#guard (NamePattern.many ["example", "com"]).covers? (.one ["example", "com"])
#guard !(NamePattern.one ["example", "com"]).covers? (.many ["example", "com"])
#guard (NamePattern.many ["com"]).covers? (.many ["example", "com"])
#guard (NamePattern.many ["com"]).covers? (.one ["example", "com"])
#guard !(NamePattern.one ["com"]).covers? (.one ["example", "com"])
#guard (NamePattern.one ["example", "com"]).covers? (.exact ["api", "example", "com"])
#guard !(NamePattern.one ["example", "com"]).covers? (.exact ["a", "b", "example", "com"])
#guard (NamePattern.many ["example", "com"]).covers? (.exact ["a", "b", "example", "com"])
-- ワイルドカードは幹自身を覆わない。exact はワイルドカードを覆わない。
#guard !(NamePattern.one ["example", "com"]).covers? (.exact ["example", "com"])
#guard !(NamePattern.many ["example", "com"]).covers? (.exact ["example", "com"])
#guard !(NamePattern.exact ["example", "com"]).covers? (.one ["example", "com"])
-- ラベルの一部だけが一致する幹は覆わない（`**.example.com` は `badexample.com` を覆わない）。
#guard !(NamePattern.many ["example", "com"]).covers? (.exact ["badexample", "com"])

end Benitoite.Scope.Domain
