import Benitoite.Release.EffectCoverDef
import Benitoite.Scope.RangeCover
import Benitoite.Release.TypeScopedSubst

/-!
# 効果の許可の関係と被覆

構造上の包含 `Eff.Sub`（原子ごとの所属の包含）を変えずに、名前と対象を受け取る許可の関係 `Eff.Allows` と、
効果どうしの被覆 `Eff.Covers` を別の関係として置く（設計書 01-12「エフェクトの名前と開始状態」、問 13）。被覆の
定義と型付けが使う基本の補題は `Release/EffectCoverDef.lean` にある。L40.6c から、型付けの C-Sub・C-Eff と関数の型の
効果の包含（`Ty.Le`）、継続の型付けの K-Handle・K-Handle-Fail の節の効果の包含は被覆で判定する（旧の像での同値は
`Release/CoverCompat.lean`）。

- 許可の関係 `Eff.Allows κ ε l t` は、効果の上限 ε が名前 l の操作の対象 t を許すことである。名前から対象の
  種類への関数 κ を引数に取り、同じ名前の閉じた範囲の原子に、種類 `κ l` に相対的に（`Range.MemK`）対象が
  属することとする。Top の原子は名前の種類の全対象を許し、他の種類の対象を許さない（RV-L00 中2）。範囲の変数の
  原子は対象を許さない。κ は署名の表の `effKind` に具体化する前の引数である。
- 被覆 `Eff.Covers ε ε'`（外側が先）は、ε' の各原子を ε のいずれか一原子が丸ごと覆い、ε' の Fail の型が ε に
  属することである。同じ名前の閉じた範囲の原子どうしは範囲の被覆 `Range.Covers` で覆い、範囲の変数の原子と
  行の原子は同じ原子だけが覆う（判断 5）。和による被覆は判定しない。
- 被覆は許可の包含を与える（`Eff.Covers.sound`）が、相互の被覆から構造の等号は従わない
  （`Eff.no_eq_of_semCovers`）。相互の被覆や許可の一致から効果の等号を導く補題は置かない（判断 5）。
- 代入は閉じた範囲を変えない。型だけの代入は名前の原子と許可を変えず、行の代入は行の像の原子を加えるだけで
  ある（`Eff.allows_bind`・`Eff.allows_bind_of_rows_nil`）。被覆は代入で保たれる（`Eff.Covers.bind`）。
- 旧の効果（原子がすべて `Atom.TopImage`）では、被覆は構造上の包含と同じであり
  （`Eff.covers_iff_sub_of_topAtoms`）、所属の一致と構造上の包含は旧の原子（Top の名前の原子と行）だけの所属で
  決まる（`Eff.mem_iff_of_topAtoms`・`Eff.sub_iff_of_topAtoms`）。構造の等号の補題（`Eff.eq_of_sub_of_sub`・
  `Eff.norm_ext`・`Eff.ext_canonical`）は範囲の位置を含む全ての原子について述べたものであり、旧の言明はこの二つの
  補題を合成して得る（L50.3 で、利用側のない旧の言明の系を除いた）。
-/

namespace Benitoite.Release

/-! ## 許可の関係 -/

/-- 効果の上限 ε が、名前 l の操作の対象 t を許す。κ は名前から対象の種類への関数（署名の表の `effKind` の位置）
であり、同じ名前の閉じた範囲の原子に、種類 `κ l` に相対的に対象が属することとする。Top の原子は種類 `κ l` の
全対象を許し、他の種類の対象を許さない（RV-L00 中2）。`κ l = none` の名前（対象を持たない名前）は何も許さない。
範囲の変数の原子は対象を許さない。 -/
def Eff.Allows (κ : EffName → Option Scope.Domain.Kind) (ε : Eff) (l : EffName)
    (t : Scope.Domain.Target) : Prop :=
  ∃ k r, κ l = some k ∧ Eff.mem ε (.name l (.fixed r)) ∧ r.MemK k t

section Allows

variable {κ : EffName → Option Scope.Domain.Kind}

theorem Eff.allows_of_mem {ε : Eff} {l : EffName} {t : Scope.Domain.Target} {k : Scope.Domain.Kind}
    {r : Scope.Domain.Range} (hk : κ l = some k) (hm : Eff.mem ε (.name l (.fixed r))) (ht : r.MemK k t) :
    Eff.Allows κ ε l t :=
  ⟨k, r, hk, hm, ht⟩

/-- 許される対象の種類は名前の種類である。 -/
theorem Eff.Allows.kind {ε : Eff} {l : EffName} {t : Scope.Domain.Target} (h : Eff.Allows κ ε l t) :
    κ l = some t.kind := by
  obtain ⟨k, r, hk, -, ht, -⟩ := h
  rw [hk, ht]

/-- 対象を持たない名前は何も許さない。 -/
theorem Eff.not_allows_of_kind_none {ε : Eff} {l : EffName} {t : Scope.Domain.Target} (h : κ l = none) :
    ¬ Eff.Allows κ ε l t := by
  intro ha
  rw [ha.kind] at h
  cases h

/-- Top の名前の原子は、名前の種類の全対象を許す。 -/
theorem Eff.allows_of_nameTop {ε : Eff} {l : EffName} {t : Scope.Domain.Target}
    (hm : Eff.mem ε (.nameTop l)) (hk : κ l = some t.kind) : Eff.Allows κ ε l t :=
  ⟨t.kind, .top, hk, hm, rfl, trivial⟩

/-- `Eff.single l`（Top の一原子）が許すのは、名前 l の種類の対象だけである。 -/
theorem Eff.allows_single_iff {l m : EffName} {t : Scope.Domain.Target} :
    Eff.Allows κ (Eff.single l) m t ↔ m = l ∧ κ l = some t.kind := by
  constructor
  · rintro ⟨k, r, hk, hm, ht⟩
    obtain ⟨rfl, hr⟩ := (Eff.mem_single_name l m _).mp hm
    refine ⟨rfl, ?_⟩
    rw [hk, ht.1]
  · rintro ⟨rfl, hk⟩
    exact Eff.allows_of_nameTop ((Eff.mem_single _ _).mpr rfl) hk

/-- 構造上の包含は許可を保つ。 -/
theorem Eff.Allows.mono {ε ε' : Eff} {l : EffName} {t : Scope.Domain.Target} (h : Eff.Allows κ ε l t)
    (hs : Eff.Sub ε ε') : Eff.Allows κ ε' l t := by
  obtain ⟨k, r, hk, hm, ht⟩ := h
  exact ⟨k, r, hk, hs.1 _ hm, ht⟩

theorem Eff.allows_norm {ε : Eff} {l : EffName} {t : Scope.Domain.Target} :
    Eff.Allows κ (Eff.norm ε) l t ↔ Eff.Allows κ ε l t := by
  simp only [Eff.Allows, Eff.mem_norm]

/-- 和の許可は、どちらかの許可である。 -/
theorem Eff.allows_union {e f : Eff} {l : EffName} {t : Scope.Domain.Target} :
    Eff.Allows κ (Eff.union e f) l t ↔ Eff.Allows κ e l t ∨ Eff.Allows κ f l t := by
  simp only [Eff.Allows, Eff.mem_union]
  constructor
  · rintro ⟨k, r, hk, hm | hm, ht⟩
    · exact Or.inl ⟨k, r, hk, hm, ht⟩
    · exact Or.inr ⟨k, r, hk, hm, ht⟩
  · rintro (⟨k, r, hk, hm, ht⟩ | ⟨k, r, hk, hm, ht⟩)
    · exact ⟨k, r, hk, Or.inl hm, ht⟩
    · exact ⟨k, r, hk, Or.inr hm, ht⟩

/-- 空の効果は何も許さない。 -/
theorem Eff.not_allows_empty {l : EffName} {t : Scope.Domain.Target} : ¬ Eff.Allows κ Eff.empty l t := by
  rintro ⟨k, r, -, hm, -⟩
  exact (Eff.mem_empty _).mp hm

/-- 行一つの効果は何も許さない。 -/
theorem Eff.not_allows_row {i : Nat} {l : EffName} {t : Scope.Domain.Target} :
    ¬ Eff.Allows κ (Eff.row i) l t := by
  rintro ⟨k, r, -, hm, -⟩
  cases (Eff.mem_row _ _).mp hm

/-! ### 代入は閉じた範囲を変えない -/

/-- 代入の後の許可は、元の効果の許可か、元の効果の行の像の許可である。閉じた範囲の原子は同じ名前と同じ範囲の
まま残り、範囲を広げも狭めもしない。 -/
theorem Eff.allows_bind (θ : SubstEnv) (e : Eff) {l : EffName} {t : Scope.Domain.Target} :
    Eff.Allows κ (Eff.bind θ e) l t ↔
      Eff.Allows κ e l t ∨ ∃ i, Eff.mem e (.rho i) ∧ Eff.Allows κ (Eff.rowImage θ.rows i) l t := by
  simp only [Eff.Allows, Eff.mem_bind_name]
  constructor
  · rintro ⟨k, r, hk, hm | ⟨i, hi, hm⟩, ht⟩
    · exact Or.inl ⟨k, r, hk, hm, ht⟩
    · exact Or.inr ⟨i, hi, k, r, hk, hm, ht⟩
  · rintro (⟨k, r, hk, hm, ht⟩ | ⟨i, hi, k, r, hk, hm, ht⟩)
    · exact ⟨k, r, hk, Or.inl hm, ht⟩
    · exact ⟨k, r, hk, Or.inr ⟨i, hi, hm⟩, ht⟩

/-- 行を置き換えない代入（型だけの代入）は、名前の原子の所属を変えない。 -/
theorem Eff.mem_bind_name_of_rows_nil {θ : SubstEnv} (h : θ.rows = []) (e : Eff) (l : EffName)
    (r : Scope.Signature.Ix) : Eff.mem (Eff.bind θ e) (.name l r) ↔ Eff.mem e (.name l r) := by
  rw [Eff.mem_bind_name]
  constructor
  · rintro (hm | ⟨i, -, hm⟩)
    · exact hm
    · simp only [Eff.rowImage, h, List.getElem?_nil, Option.getD_none, Eff.mem_row] at hm
      cases hm
  · exact Or.inl

/-- 行を置き換えない代入（型だけの代入）は、許可を変えない。 -/
theorem Eff.allows_bind_of_rows_nil {θ : SubstEnv} (h : θ.rows = []) (e : Eff) {l : EffName}
    {t : Scope.Domain.Target} : Eff.Allows κ (Eff.bind θ e) l t ↔ Eff.Allows κ e l t := by
  simp only [Eff.Allows, Eff.mem_bind_name_of_rows_nil h]

/-- 型の代入 `substAt c ts []` は名前の原子の所属を変えない。 -/
theorem Eff.mem_substAt_nil_name (c : Nat) (ts : List Ty) (e : Eff) (l : EffName) (r : Scope.Signature.Ix) :
    Eff.mem (Eff.substAt c ts [] e) (.name l r) ↔ Eff.mem e (.name l r) :=
  Eff.mem_bind_name_of_rows_nil (θ := SubstEnv.at c ts []) rfl e l r

/-- 型の代入 `substAt c ts []` は許可を変えない。 -/
theorem Eff.allows_substAt_nil (c : Nat) (ts : List Ty) (e : Eff) {l : EffName} {t : Scope.Domain.Target} :
    Eff.Allows κ (Eff.substAt c ts [] e) l t ↔ Eff.Allows κ e l t :=
  Eff.allows_bind_of_rows_nil (θ := SubstEnv.at c ts []) rfl e

/-- 行の代入の後の許可は、元の許可か、置き換えた行の許可である。 -/
theorem Eff.allows_substRho (es : List Eff) (e : Eff) {l : EffName} {t : Scope.Domain.Target} :
    Eff.Allows κ (Eff.substRho es e) l t ↔
      Eff.Allows κ e l t ∨ ∃ i, Eff.mem e (.rho i) ∧ Eff.Allows κ (Eff.rowImage es i) l t := by
  rw [Eff.substRho_eq_bind]
  exact Eff.allows_bind (SubstEnv.rowsOnly es) e

/-- 合成した代入の許可は、二段の代入の許可と同じである。`Eff.bind_comp_of_types` の範囲付きの版であり、許可は
Fail の型を見ないので、Fail の型の合成の前提を要しない（証明は `Eff.bind_comp` の等号による）。 -/
theorem Eff.allows_bind_comp (θ φ : SubstEnv) (e : Eff) {l : EffName} {t : Scope.Domain.Target} :
    Eff.Allows κ (Eff.bind φ (Eff.bind θ e)) l t ↔ Eff.Allows κ (Eff.bind (θ.compose φ) e) l t := by
  rw [Eff.bind_comp]

end Allows

/-! ## 効果の被覆 -/

/-- 健全性: 被覆は、どの名前の種類の関数 κ についても許可の包含を与える。 -/
theorem Eff.Covers.sound {ε ε' : Eff} (h : ε.Covers ε') {κ : EffName → Option Scope.Domain.Kind}
    {l : EffName} {t : Scope.Domain.Target} (ha : Eff.Allows κ ε' l t) : Eff.Allows κ ε l t := by
  obtain ⟨k, s, hk, hm, ht⟩ := ha
  obtain ⟨b, hb, hbc⟩ := h.1 _ hm
  obtain ⟨r, rfl, hrs⟩ := Atom.covers_fixed_iff.mp hbc
  exact ⟨k, r, hk, hb, hrs.sound_memK ht⟩

/-- 閉じた範囲 r の名前の原子を覆う原子が効果に属するとき、効果は r に属する対象を許す（被覆の健全性）。 -/
theorem Eff.allows_of_mem_covers {κ : EffName → Option Scope.Domain.Kind} {ε : Eff} {l : EffName}
    {ix : Scope.Signature.Ix} {r : Scope.Domain.Range} {k : Scope.Domain.Kind} {t : Scope.Domain.Target}
    (hk : κ l = some k) (hm : Eff.mem ε (.name l ix)) (hc : (Atom.name l ix).Covers (.name l (.fixed r)))
    (ht : r.MemK k t) : Eff.Allows κ ε l t := by
  obtain ⟨r', he, hrc⟩ := Atom.covers_fixed_iff.mp hc
  cases he
  exact ⟨k, r', hk, hm, hrc.sound_memK ht⟩

theorem Eff.Covers.substRho {ε ε' : Eff} (h : ε.Covers ε') (es : List Eff) :
    (Eff.substRho es ε).Covers (Eff.substRho es ε') := by
  rw [Eff.substRho_eq_bind, Eff.substRho_eq_bind]
  exact h.bind (SubstEnv.rowsOnly es)

/-! ## 旧の効果（原子がすべて Top の像） -/

/-- 原子がすべて旧の原子の像（範囲の位置が Top の名前の原子と行）である効果。Fail の列の型は見ない。 -/
def Eff.TopAtoms (e : Eff) : Prop := ∀ a, Eff.mem e a → a.TopImage

theorem Eff.topAtoms_empty : Eff.empty.TopAtoms := fun a h => ((Eff.mem_empty a).mp h).elim

theorem Eff.topAtoms_single (l : EffName) : (Eff.single l).TopAtoms := by
  intro a h
  rw [(Eff.mem_single l a).mp h]
  exact Atom.topImage_nameTop l

theorem Eff.topAtoms_row (i : Nat) : (Eff.row i).TopAtoms := by
  intro a h
  rw [(Eff.mem_row i a).mp h]
  exact Atom.topImage_rho i

theorem Eff.TopAtoms.norm {e : Eff} (h : e.TopAtoms) : (Eff.norm e).TopAtoms :=
  fun a ha => h a ((Eff.mem_norm e a).mp ha)

theorem Eff.TopAtoms.union {e f : Eff} (he : e.TopAtoms) (hf : f.TopAtoms) : (Eff.union e f).TopAtoms :=
  fun a ha => ((Eff.mem_union e f a).mp ha).elim (he a) (hf a)

theorem Eff.TopAtoms.of_sub {e f : Eff} (hf : f.TopAtoms) (h : Eff.Sub e f) : e.TopAtoms :=
  fun a ha => hf a (h.1 a ha)

/-- 旧の効果に、行の像も旧の効果である代入を施した結果は旧の効果である。 -/
theorem Eff.TopAtoms.bind {e : Eff} (he : e.TopAtoms) {θ : SubstEnv}
    (hθ : ∀ i, (Eff.rowImage θ.rows i).TopAtoms) : (Eff.bind θ e).TopAtoms := by
  intro a ha
  rcases (Eff.mem_bind θ e a).mp ha with ⟨l, r, rfl, hm⟩ | ⟨i, -, hia⟩
  · exact he _ hm
  · exact hθ i a hia

/-- 旧の効果の原子は、範囲の位置が Top でない名前の原子を含まない。 -/
theorem Eff.TopAtoms.not_mem_fixed {e : Eff} (h : e.TopAtoms) {l : EffName} {r : Scope.Domain.Range}
    (hr : r ≠ .top) : ¬ Eff.mem e (.name l (.fixed r)) := fun hm => by
  have := h _ hm
  simp only [Atom.TopImage, Scope.Signature.Ix.fixed.injEq] at this
  exact hr this

/-- 旧の効果では、被覆は構造上の包含と同じである（旧の像で旧の内容と同値）。 -/
theorem Eff.covers_iff_sub_of_topAtoms {ε ε' : Eff} (h : ε'.TopAtoms) : ε.Covers ε' ↔ Eff.Sub ε' ε := by
  refine ⟨fun hc => ⟨fun a ha => ?_, hc.2⟩, Eff.Sub.covers⟩
  obtain ⟨b, hb, hba⟩ := hc.1 a ha
  rwa [(Atom.covers_iff_eq_of_topImage (h a ha)).mp hba] at hb

/-- 旧の原子の所属: 旧の効果どうしの所属の一致は、旧の原子（Top の名前の原子と行）の所属の一致から従う。 -/
theorem Eff.mem_iff_of_topAtoms {e f : Eff} (he : e.TopAtoms) (hf : f.TopAtoms)
    (hn : ∀ l, Eff.mem e (.nameTop l) ↔ Eff.mem f (.nameTop l))
    (hr : ∀ i, Eff.mem e (.rho i) ↔ Eff.mem f (.rho i)) (a : Atom) : Eff.mem e a ↔ Eff.mem f a := by
  rcases a with ⟨l, ix⟩ | i
  · by_cases hix : ix = Scope.Signature.Ix.top
    · subst hix; exact hn l
    · constructor
      · intro h; exact absurd (he _ h) hix
      · intro h; exact absurd (hf _ h) hix
  · exact hr i

/-- 旧の効果の構造上の包含は、旧の原子の所属の包含である。 -/
theorem Eff.sub_iff_of_topAtoms {e f : Eff} (he : e.TopAtoms) :
    Eff.Sub e f ↔ (∀ l, Eff.mem e (.nameTop l) → Eff.mem f (.nameTop l)) ∧
      (∀ i, Eff.mem e (.rho i) → Eff.mem f (.rho i)) ∧ ∀ t, Eff.memFail e t → Eff.memFail f t := by
  constructor
  · rintro ⟨ha, ht⟩
    exact ⟨fun l => ha _, fun i => ha _, ht⟩
  · rintro ⟨hn, hr, ht⟩
    refine ⟨fun a ha => ?_, ht⟩
    rcases a with ⟨l, ix⟩ | i
    · have hix : ix = Scope.Signature.Ix.top := he _ ha
      subst hix; exact hn l ha
    · exact hr i ha

/-! ## 例と反例 -/

namespace EffectCoverExamples

/-- `/data/a` の完全一致の範囲。 -/
def dataA : Scope.Domain.Range := .path (.exact ["data", "a"])

/-- `/**`（根の木）の範囲。種類 path の全対象を含む。 -/
def treeRoot : Scope.Domain.Range := .path (.tree [])

/-- `{File.Read[Top], File.Read[/data/a]}`。 -/
def wide : Eff := Eff.ofAtoms (fun a => a == .nameTop "File.Read" || a == .name "File.Read" (.fixed dataA))

/-- `{File.Read[Top]}`。 -/
def top : Eff := Eff.single "File.Read"

/-- `{File.Read[/**]}`。 -/
def treeEff : Eff := Eff.ofAtoms (fun a => a == .name "File.Read" (.fixed treeRoot))

theorem wide_canonical : wide.Canonical := Eff.canonical_ofAtoms _

theorem top_canonical : top.Canonical := Eff.canonical_ofAtoms _

theorem wide_covers_top : wide.Covers top := by
  refine Eff.Sub.covers ⟨fun a ha => ?_, fun t ht => ?_⟩
  · rw [show a = .nameTop "File.Read" from (Eff.mem_single _ _).mp ha]
    simp [wide, Eff.mem, Eff.test, Eff.atoms]
  · exact ((Eff.memFail_single _ t).mp ht).elim

theorem top_covers_wide : top.Covers wide := by
  refine ⟨fun a ha => ⟨.nameTop "File.Read", (Eff.mem_single _ _).mpr rfl, ?_⟩, fun t ht => ?_⟩
  · simp only [wide, Eff.mem, Eff.test, Eff.atoms, Bool.or_eq_true, beq_iff_eq] at ha
    rcases ha with rfl | rfl
    · exact Atom.Covers.refl _
    · exact Atom.nameTop_covers_iff.mpr ⟨_, rfl⟩
  · simp [Eff.memFail, wide, Eff.fails] at ht

theorem wide_ne_top : wide ≠ top := by
  intro h
  have := congrArg (fun e : Eff => e.atoms (.name "File.Read" (.fixed dataA))) h
  simp [wide, top, Eff.single, Eff.atoms, dataA] at this

theorem not_sub_wide_top : ¬ Eff.Sub wide top := by
  intro h
  have hm := h.1 (.name "File.Read" (.fixed dataA)) (by simp [wide, Eff.mem, Eff.test, Eff.atoms])
  rw [show top = Eff.single "File.Read" from rfl, Eff.mem_single_name] at hm
  simp [dataA] at hm

end EffectCoverExamples

open EffectCoverExamples in
/-- 反例: 正規形の効果どうしで相互に覆っても、構造の等号は成り立たない。`{File.Read[Top], File.Read[/data/a]}` と
`{File.Read[Top]}` は互いに覆うが、等しくなく、構造上の包含も成り立たない（L00.06 のモデルの反例の本番の型の版）。 -/
theorem Eff.semCovers_not_eq :
    wide.Covers top ∧ top.Covers wide ∧ wide ≠ top ∧ ¬ Eff.Sub wide top :=
  ⟨wide_covers_top, top_covers_wide, wide_ne_top, not_sub_wide_top⟩

open EffectCoverExamples in
/-- したがって、被覆の相互包含から等号を導く規則は、正規形に限っても偽である（判断 5）。 -/
theorem Eff.no_eq_of_semCovers :
    ¬ (∀ e f : Eff, e.Canonical → f.Canonical → e.Covers f → f.Covers e → e = f) := fun h =>
  wide_ne_top (h _ _ wide_canonical top_canonical wide_covers_top top_covers_wide)

open EffectCoverExamples in
/-- 許可の一致からも等号は従わない: 上の二つの効果は、どの κ についても同じ対象を許す。 -/
theorem Eff.no_eq_of_allows_iff :
    ¬ (∀ (κ : EffName → Option Scope.Domain.Kind) (e f : Eff), e.Canonical → f.Canonical →
        (∀ l t, Eff.Allows κ e l t ↔ Eff.Allows κ f l t) → e = f) := fun h =>
  wide_ne_top (h (fun _ => none) _ _ wide_canonical top_canonical
    (fun _ _ => ⟨top_covers_wide.sound, wide_covers_top.sound⟩))

open EffectCoverExamples in
/-- 内側が Top の原子は非 Top の原子に覆われない（L10.4 の `Range.not_covers_top`）。種類 path の名前では、
`{File.Read[/**]}` は `{File.Read[Top]}` の許す対象をすべて許すが、覆わない。被覆は許可の包含より狭い。 -/
theorem Eff.tree_allows_not_covers_top {κ : EffName → Option Scope.Domain.Kind}
    (hk : κ "File.Read" = some .path) :
    (∀ l t, Eff.Allows κ top l t → Eff.Allows κ treeEff l t) ∧ ¬ treeEff.Covers top := by
  refine ⟨fun l t ha => ?_, fun hc => ?_⟩
  · obtain ⟨rfl, hkt⟩ := Eff.allows_single_iff.mp ha
    rw [hk] at hkt
    have htk : t.kind = .path := (Option.some.inj hkt).symm
    refine ⟨.path, treeRoot, hk, by simp [treeEff, Eff.mem, Eff.test, Eff.atoms], htk, ?_⟩
    cases t with
    | path w => exact ⟨w, by simp⟩
    | host _ => cases htk
    | endpoint _ => cases htk
  · have hm := hc.nameTop ((Eff.mem_single "File.Read" _).mpr rfl)
    simp [treeEff, Eff.mem, Eff.test, Eff.atoms, treeRoot] at hm

/-- 和による被覆を判定しない（判断 5）: 同じホストのパターンでポート `0..4` と `5..9` の二原子の効果は、種類
endpoint の名前について `0..9` の原子の効果の許す対象をすべて許すが、覆わない。 -/
theorem Eff.union_allows_not_covers {κ : EffName → Option Scope.Domain.Kind} {l : EffName}
    (hk : κ l = some .endpoint) (h : Scope.Domain.HostPattern) :
    let r09 : Scope.Domain.Range := .endpoint ⟨h, ⟨0, 9⟩⟩
    let r04 : Scope.Domain.Range := .endpoint ⟨h, ⟨0, 4⟩⟩
    let r59 : Scope.Domain.Range := .endpoint ⟨h, ⟨5, 9⟩⟩
    let e09 : Eff := Eff.ofAtoms (fun a => a == .name l (.fixed r09))
    let e0459 : Eff := Eff.ofAtoms (fun a => a == .name l (.fixed r04) || a == .name l (.fixed r59))
    (∀ m t, Eff.Allows κ e09 m t → Eff.Allows κ e0459 m t) ∧ ¬ e0459.Covers e09 := by
  intro r09 r04 r59 e09 e0459
  obtain ⟨hu, h04, h59⟩ := Scope.Domain.Range.endpoint_union_not_covers h
  refine ⟨fun m t ha => ?_, fun hc => ?_⟩
  · obtain ⟨k, r, hkm, hm, ht⟩ := ha
    simp only [e09, Eff.mem, Eff.test, Eff.atoms, beq_iff_eq, Atom.name.injEq,
      Scope.Signature.Ix.fixed.injEq] at hm
    obtain ⟨rfl, rfl⟩ := hm
    rcases hu t ht.2 with h1 | h1
    · exact ⟨k, r04, hkm, by simp [e0459, Eff.mem, Eff.test, Eff.atoms], ht.1, h1⟩
    · exact ⟨k, r59, hkm, by simp [e0459, Eff.mem, Eff.test, Eff.atoms], ht.1, h1⟩
  · obtain ⟨r, hm, hrs, -⟩ := hc.name_fixed (l := l) (s := r09)
      (by simp [e09, Eff.mem, Eff.test, Eff.atoms])
    simp only [e0459, Eff.mem, Eff.test, Eff.atoms, Bool.or_eq_true, beq_iff_eq, Atom.name.injEq,
      Scope.Signature.Ix.fixed.injEq, true_and] at hm
    rcases hm with rfl | rfl
    · exact h04 hrs
    · exact h59 hrs

/-- RV-L00 中2 の確かめ: 種類 path の名前 `File.Write` の Top の原子は、パスの対象を許すが、エンドポイントの対象を
許さない（Top の許可は名前の種類に相対的である）。 -/
theorem Eff.single_allows_kind {κ : EffName → Option Scope.Domain.Kind}
    (hk : κ "File.Write" = some .path) (w : Scope.Domain.Word) (e : Scope.Domain.Endpoint) :
    Eff.Allows κ (Eff.single "File.Write") "File.Write" (.path w) ∧
      ¬ Eff.Allows κ (Eff.single "File.Write") "File.Write" (.endpoint e) := by
  refine ⟨Eff.allows_single_iff.mpr ⟨rfl, hk⟩, fun ha => ?_⟩
  have := (Eff.allows_single_iff.mp ha).2
  rw [hk] at this
  cases this

namespace EffectCoverExamples

/-- `/data/**` の範囲。 -/
def dataTree : Scope.Domain.Range := .path (.tree ["data"])

#guard (Atom.nameTop "File.Read").covers? (.name "File.Read" (.fixed dataA))
#guard !(Atom.name "File.Read" (.fixed treeRoot)).covers? (.nameTop "File.Read")
#guard (Atom.name "File.Read" (.fixed dataTree)).covers? (.name "File.Read" (.fixed dataA))
#guard !(Atom.name "File.Read" (.fixed dataA)).covers? (.name "File.Read" (.fixed dataTree))
#guard !(Atom.name "File.Write" (.fixed dataTree)).covers? (.name "File.Read" (.fixed dataA))
#guard !(Atom.nameTop "File.Read").covers? (.name "File.Read" (.rvar 0))
#guard (Atom.name "File.Read" (.rvar 0)).covers? (.name "File.Read" (.rvar 0))
#guard !(Atom.nameTop "File.Read").covers? (.rho 0)
#guard (Atom.rho 0).covers? (.rho 0)
#guard !(Atom.name "File.Read" (.fixed dataTree)).covers? (.rho 0)

end EffectCoverExamples

end Benitoite.Release
