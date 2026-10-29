import Benitoite.Scope.RangeCover
import Benitoite.Release.TypeComposition

/-!
# 原子と効果の被覆の定義

原子の被覆 `Atom.Covers` と効果の被覆 `Eff.Covers`（判断 5 の一原子の被覆）の定義と、型付けの規則が使う基本の
補題（反射・推移・構造上の包含からの被覆・正規化・和・空・代入）を置く。型付けの包含の規則（C-Sub・C-Eff と
関数の型の効果の包含 `Ty.Le`）がこの関係を使うので、型付けの規則（`Release/Typing.lean`）より前に置く。
許可の関係・健全性・旧の効果の系・例は `Release/EffectCover.lean` にある（設計書 01-12「エフェクトの名前と開始状態」）。
-/

namespace Benitoite.Release

/-! ## 原子の被覆 -/

/-- 原子の被覆（引数は外側が先）。同じ名前の閉じた範囲の原子どうしは範囲の被覆で覆う。範囲の変数の原子と行の
原子は同じ原子だけが覆う。名前の違う原子、閉じた範囲と範囲の変数の組、名前と行の組は覆わない（判断 5 の
「未確定の行変数を範囲原子で覆わない」。範囲の変数も具体化の前は覆わない）。 -/
def Atom.Covers : Atom → Atom → Prop
  | .name l (.fixed r), .name m (.fixed s) => l = m ∧ r.Covers s
  | .name l (.rvar i), .name m (.rvar j) => l = m ∧ i = j
  | .rho i, .rho j => i = j
  | _, _ => False

/-- 原子の被覆の判定。 -/
def Atom.covers? : Atom → Atom → Bool
  | .name l (.fixed r), .name m (.fixed s) => l == m && r.covers? s
  | .name l (.rvar i), .name m (.rvar j) => l == m && i == j
  | .rho i, .rho j => i == j
  | _, _ => false

theorem Atom.covers?_spec (a b : Atom) : a.covers? b = true ↔ a.Covers b := by
  rcases a with ⟨l, r | i⟩ | i <;> rcases b with ⟨m, s | j⟩ | j <;>
    simp [Atom.covers?, Atom.Covers, Scope.Domain.Range.covers?_spec]

instance (a b : Atom) : Decidable (a.Covers b) := decidable_of_iff _ (Atom.covers?_spec a b)

theorem Atom.Covers.refl (a : Atom) : a.Covers a := by
  rcases a with ⟨l, r | i⟩ | i <;> simp [Atom.Covers, Scope.Domain.Range.Covers.refl]

theorem Atom.Covers.trans {a b c : Atom} (h₁ : a.Covers b) (h₂ : b.Covers c) : a.Covers c := by
  rcases a with ⟨l, r | i⟩ | i <;> rcases b with ⟨m, s | j⟩ | j <;> rcases c with ⟨n, u | k⟩ | k <;>
    simp only [Atom.Covers] at h₁ h₂ ⊢
  · exact ⟨h₁.1.trans h₂.1, h₁.2.trans h₂.2⟩
  · exact ⟨h₁.1.trans h₂.1, h₁.2.trans h₂.2⟩
  · exact h₁.trans h₂

/-- 閉じた範囲の名前の原子を覆うのは、同じ名前の閉じた範囲の原子で、範囲が覆うものだけである。 -/
theorem Atom.covers_fixed_iff {a : Atom} {l : EffName} {s : Scope.Domain.Range} :
    a.Covers (.name l (.fixed s)) ↔ ∃ r, a = .name l (.fixed r) ∧ r.Covers s := by
  rcases a with ⟨m, r | i⟩ | i <;> simp only [Atom.Covers]
  · constructor
    · rintro ⟨rfl, h⟩; exact ⟨r, rfl, h⟩
    · rintro ⟨r', h, hc⟩; cases h; exact ⟨rfl, hc⟩
  · simp
  · simp

/-- 範囲の変数の原子を覆うのは、同じ原子だけである。 -/
theorem Atom.covers_rvar_iff {a : Atom} {l : EffName} {j : Nat} :
    a.Covers (.name l (.rvar j)) ↔ a = .name l (.rvar j) := by
  rcases a with ⟨m, r | i⟩ | i <;> simp only [Atom.Covers]
  · simp
  · constructor
    · rintro ⟨rfl, rfl⟩; rfl
    · intro h; cases h; exact ⟨rfl, rfl⟩
  · simp

/-- 行の原子を覆うのは、同じ行の原子だけである（判断 5）。 -/
theorem Atom.covers_rho_iff {a : Atom} {j : Nat} : a.Covers (.rho j) ↔ a = .rho j := by
  rcases a with ⟨m, r | i⟩ | i <;> simp [Atom.Covers]

/-- 名前の原子を覆うのは、同じ名前の原子だけである。 -/
theorem Atom.Covers.name_right {a : Atom} {l : EffName} {ix : Scope.Signature.Ix}
    (h : a.Covers (.name l ix)) : ∃ jx, a = .name l jx := by
  cases ix with
  | fixed s => obtain ⟨r, rfl, -⟩ := Atom.covers_fixed_iff.mp h; exact ⟨_, rfl⟩
  | rvar j => exact ⟨_, Atom.covers_rvar_iff.mp h⟩

/-- Top の名前の原子を覆うのは、同じ名前の Top の原子だけである（L10.4 の `Range.not_covers_top`）。 -/
theorem Atom.covers_nameTop_iff {a : Atom} {l : EffName} : a.Covers (.nameTop l) ↔ a = .nameTop l := by
  rw [Atom.covers_fixed_iff]
  constructor
  · rintro ⟨r, rfl, h⟩
    rw [(Scope.Domain.Range.covers_top_iff r).mp h]
  · intro h; exact ⟨.top, h, Scope.Domain.Range.top_covers _⟩

/-- 内側が Top の原子は、非 Top の閉じた範囲の原子に覆われない。 -/
theorem Atom.not_covers_nameTop {l m : EffName} {r : Scope.Domain.Range} (hr : r ≠ .top) :
    ¬ (Atom.name l (.fixed r)).Covers (.nameTop m) := by
  rw [Atom.covers_nameTop_iff]
  intro h; cases h; exact hr rfl

/-- Top の名前の原子は、同じ名前の閉じた範囲の原子をすべて覆う。 -/
theorem Atom.nameTop_covers_iff {l : EffName} {b : Atom} :
    (Atom.nameTop l).Covers b ↔ ∃ s, b = .name l (.fixed s) := by
  rcases b with ⟨m, s | j⟩ | j <;> simp only [Atom.Covers]
  · constructor
    · rintro ⟨rfl, -⟩; exact ⟨s, rfl⟩
    · rintro ⟨s', h⟩; cases h; exact ⟨rfl, Scope.Domain.Range.top_covers _⟩
  · simp
  · simp

/-- 旧の原子の像（Top の名前の原子と行）では、被覆は等号と同じである。 -/
theorem Atom.covers_iff_eq_of_topImage {a b : Atom} (hb : b.TopImage) : a.Covers b ↔ a = b := by
  rcases b with ⟨l, ix⟩ | j
  · cases hb; exact Atom.covers_nameTop_iff
  · exact Atom.covers_rho_iff

/-- 覆う原子の名前は、範囲の被覆の健全性を通して、内側の範囲の対象を種類に相対的に含む。 -/
theorem Atom.Covers.sound_fixed {r s : Scope.Domain.Range} {l m : EffName}
    (h : (Atom.name l (.fixed r)).Covers (.name m (.fixed s))) : l = m ∧ s.Sub r :=
  ⟨h.1, Scope.Domain.Range.Covers.sound h.2⟩

/-! ## 効果の被覆 -/

/-- 効果の被覆（引数は外側が先）。ε' の各原子を ε のいずれか一原子が覆い、ε' の Fail の型が ε に属する。
Fail の型は構造上の所属で比べる（判断 5 の「Fail の型と行変数の規則は保つ」）。一原子を複数の原子の和で覆う
判定はしない。構造上の包含 `Eff.Sub` とは別の関係である（問 13）。 -/
def Eff.Covers (ε ε' : Eff) : Prop :=
  (∀ a, Eff.mem ε' a → ∃ b, Eff.mem ε b ∧ b.Covers a) ∧ (∀ t, Eff.memFail ε' t → Eff.memFail ε t)

theorem Eff.Covers.refl (ε : Eff) : ε.Covers ε :=
  ⟨fun a ha => ⟨a, ha, Atom.Covers.refl a⟩, fun _ => id⟩

theorem Eff.Covers.trans {ε₁ ε₂ ε₃ : Eff} (h₁ : ε₁.Covers ε₂) (h₂ : ε₂.Covers ε₃) : ε₁.Covers ε₃ := by
  refine ⟨fun a ha => ?_, fun t ht => h₁.2 t (h₂.2 t ht)⟩
  obtain ⟨b, hb, hba⟩ := h₂.1 a ha
  obtain ⟨c, hc, hcb⟩ := h₁.1 b hb
  exact ⟨c, hc, hcb.trans hba⟩

/-- 構造上の包含は被覆を与える（向きに注意: `Eff.Sub ε' ε` は内側が先）。 -/
theorem Eff.Sub.covers {ε ε' : Eff} (h : Eff.Sub ε' ε) : ε.Covers ε' :=
  ⟨fun a ha => ⟨a, h.1 a ha, Atom.Covers.refl a⟩, h.2⟩

/-- 被覆の下で、内側の閉じた範囲の名前の原子には、同じ名前の閉じた範囲の原子で意味の上で含む原子がある。 -/
theorem Eff.Covers.name_fixed {ε ε' : Eff} (h : ε.Covers ε') {l : EffName} {s : Scope.Domain.Range}
    (hm : Eff.mem ε' (.name l (.fixed s))) : ∃ r, Eff.mem ε (.name l (.fixed r)) ∧ r.Covers s ∧ s.Sub r := by
  obtain ⟨b, hb, hbc⟩ := h.1 _ hm
  obtain ⟨r, rfl, hrs⟩ := Atom.covers_fixed_iff.mp hbc
  exact ⟨r, hb, hrs, hrs.sound⟩

/-- 内側の Top の原子は、外側の同じ名前の Top の原子だけが覆う。 -/
theorem Eff.Covers.nameTop {ε ε' : Eff} (h : ε.Covers ε') {l : EffName} (hm : Eff.mem ε' (.nameTop l)) :
    Eff.mem ε (.nameTop l) := by
  obtain ⟨b, hb, hbc⟩ := h.1 _ hm
  rwa [Atom.covers_nameTop_iff.mp hbc] at hb

/-- 内側の行の原子は、外側の同じ行の原子だけが覆う（判断 5）。 -/
theorem Eff.Covers.rho {ε ε' : Eff} (h : ε.Covers ε') {i : Nat} (hm : Eff.mem ε' (.rho i)) :
    Eff.mem ε (.rho i) := by
  obtain ⟨b, hb, hbc⟩ := h.1 _ hm
  rwa [Atom.covers_rho_iff.mp hbc] at hb

/-- 内側の範囲の変数の原子は、外側の同じ原子だけが覆う。 -/
theorem Eff.Covers.rvar {ε ε' : Eff} (h : ε.Covers ε') {l : EffName} {j : Nat}
    (hm : Eff.mem ε' (.name l (.rvar j))) : Eff.mem ε (.name l (.rvar j)) := by
  obtain ⟨b, hb, hbc⟩ := h.1 _ hm
  rwa [Atom.covers_rvar_iff.mp hbc] at hb

theorem Eff.covers_norm_left {ε ε' : Eff} : (Eff.norm ε).Covers ε' ↔ ε.Covers ε' := by
  simp only [Eff.Covers, Eff.mem_norm, Eff.norm_memFail]

theorem Eff.covers_norm_right {ε ε' : Eff} : ε.Covers (Eff.norm ε') ↔ ε.Covers ε' := by
  simp only [Eff.Covers, Eff.mem_norm, Eff.norm_memFail]

/-! ### 和と空の被覆 -/

/-- 和を覆うことは、両方を覆うことである。 -/
theorem Eff.covers_union_iff {ε e f : Eff} : ε.Covers (Eff.union e f) ↔ ε.Covers e ∧ ε.Covers f := by
  simp only [Eff.Covers, Eff.mem_union, Eff.memFail_union]
  constructor
  · rintro ⟨ha, ht⟩
    exact ⟨⟨fun a h => ha a (Or.inl h), fun t h => ht t (Or.inl h)⟩,
      ⟨fun a h => ha a (Or.inr h), fun t h => ht t (Or.inr h)⟩⟩
  · rintro ⟨⟨ha, ht⟩, ⟨hb, hu⟩⟩
    exact ⟨fun a h => h.elim (ha a) (hb a), fun t h => h.elim (ht t) (hu t)⟩

theorem Eff.Covers.union {ε e f : Eff} (he : ε.Covers e) (hf : ε.Covers f) : ε.Covers (Eff.union e f) :=
  Eff.covers_union_iff.mpr ⟨he, hf⟩

/-- 和は左右の各項を覆う。 -/
theorem Eff.union_covers_left (e f : Eff) : (Eff.union e f).Covers e :=
  Eff.Sub.covers ⟨fun a h => (Eff.mem_union e f a).mpr (Or.inl h),
    fun t h => (Eff.memFail_union e f t).mpr (Or.inl h)⟩

theorem Eff.union_covers_right (e f : Eff) : (Eff.union e f).Covers f :=
  Eff.Sub.covers ⟨fun a h => (Eff.mem_union e f a).mpr (Or.inr h),
    fun t h => (Eff.memFail_union e f t).mpr (Or.inr h)⟩

/-- 和は被覆について単調である。 -/
theorem Eff.Covers.union_mono {ε ε' e e' : Eff} (h : ε.Covers ε') (h' : e.Covers e') :
    (Eff.union ε e).Covers (Eff.union ε' e') :=
  ((Eff.union_covers_left ε e).trans h).union ((Eff.union_covers_right ε e).trans h')

/-- どの効果も空の効果を覆う。 -/
theorem Eff.covers_empty (ε : Eff) : ε.Covers Eff.empty :=
  ⟨fun a h => ((Eff.mem_empty a).mp h).elim, fun t h => ((Eff.memFail_empty t).mp h).elim⟩

/-- 空の効果が覆うのは、原子も Fail の型もない効果だけである。 -/
theorem Eff.empty_covers_iff {ε : Eff} :
    Eff.empty.Covers ε ↔ (∀ a, ¬ Eff.mem ε a) ∧ ∀ t, ¬ Eff.memFail ε t := by
  constructor
  · rintro ⟨ha, ht⟩
    refine ⟨fun a h => ?_, fun t h => (Eff.memFail_empty t).mp (ht t h)⟩
    obtain ⟨b, hb, -⟩ := ha a h
    exact (Eff.mem_empty b).mp hb
  · rintro ⟨ha, ht⟩
    exact ⟨fun a h => (ha a h).elim, fun t h => (ht t h).elim⟩

/-! ### 被覆は代入で保たれる -/

/-- 代入は被覆を保つ。名前の原子は同じ名前と範囲のまま残り、行の原子は同じ行の原子に覆われるので、内側の
行の像は外側の行の像に含まれる。 -/
theorem Eff.Covers.bind {ε ε' : Eff} (h : ε.Covers ε') (θ : SubstEnv) :
    (Eff.bind θ ε).Covers (Eff.bind θ ε') := by
  refine ⟨fun a ha => ?_, fun t ht => ?_⟩
  · rcases (Eff.mem_bind θ ε' a).mp ha with ⟨l, r, rfl, hm⟩ | ⟨i, hi, hia⟩
    · obtain ⟨b, hb, hbc⟩ := h.1 _ hm
      obtain ⟨jx, rfl⟩ := hbc.name_right
      exact ⟨_, (Eff.mem_bind_name θ ε l jx).mpr (Or.inl hb), hbc⟩
    · exact ⟨a, (Eff.mem_bind θ ε a).mpr (Or.inr ⟨i, h.rho hi, hia⟩), Atom.Covers.refl a⟩
  · rcases (Eff.memFail_bind θ ε' t).mp ht with ⟨x, hx, hxt⟩ | ⟨i, hi, hit⟩
    · exact (Eff.memFail_bind θ ε t).mpr (Or.inl ⟨x, h.2 x hx, hxt⟩)
    · exact (Eff.memFail_bind θ ε t).mpr (Or.inr ⟨i, h.rho hi, hit⟩)

theorem Eff.Covers.substAt {ε ε' : Eff} (h : ε.Covers ε') (c : Nat) (ts : List Ty) (es : List Eff) :
    (Eff.substAt c ts es ε).Covers (Eff.substAt c ts es ε') :=
  h.bind (SubstEnv.at c ts es)

/-- 型の変数の移動は被覆を保つ。移動は名前と行の原子を変えず、Fail の型だけを移す。 -/
theorem Eff.Covers.shift (k c : Nat) {ε ε' : Eff} (h : ε.Covers ε') :
    (Eff.shift k c ε).Covers (Eff.shift k c ε') := by
  cases ε with
  | mk a fs =>
    cases ε' with
    | mk b gs =>
      refine ⟨fun x hx => h.1 x hx, fun t ht => ?_⟩
      rw [Eff.shift, Eff.norm_memFail] at ht ⊢
      simp only [Eff.memFail, Eff.rawShift, Eff.fails, Ty.rawShiftTys_eq_map, List.mem_map] at ht ⊢
      obtain ⟨x, ⟨y, hy, rfl⟩, hyt⟩ := ht
      obtain ⟨z, hz, hzy⟩ := h.2 y ⟨y, hy, rfl⟩
      refine ⟨z.rawShift k c, ⟨z, hz, rfl⟩, ?_⟩
      rw [Ty.norm_rawShift] at hyt ⊢
      exact (congrArg (Ty.rawShift k c) hzy).trans hyt

/-- 原子を持たない効果（Fail の型だけの効果）を覆うことは、構造上の包含と同じである。被覆の Fail の部分は構造上の
所属の包含だからである。 -/
theorem Eff.Covers.sub_of_noAtoms {ε ε' : Eff} (h : ε.Covers ε') (ha : ∀ a, ¬ Eff.mem ε' a) : Eff.Sub ε' ε :=
  ⟨fun a h' => (ha a h').elim, h.2⟩

theorem Eff.Covers.sub_of_singleFail {ε : Eff} {E : Ty} (h : ε.Covers (Eff.singleFail E)) :
    Eff.Sub (Eff.singleFail E) ε :=
  h.sub_of_noAtoms (fun a ha => by simp [Eff.mem, Eff.test, Eff.singleFail, Eff.atoms] at ha)

/-- 閉じた範囲の名前の原子どうしの被覆は、名前の一致と範囲の被覆である。 -/
theorem Atom.covers_fixed_fixed {l m : EffName} {r s : Scope.Domain.Range} :
    (Atom.name l (.fixed r)).Covers (.name m (.fixed s)) ↔ l = m ∧ r.Covers s := Iff.rfl

end Benitoite.Release
