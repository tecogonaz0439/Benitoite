import Benitoite.Release.Effect

/-!
# 旧 Top との互換の埋め込みと一般化した効果（採用定義）

0.0.13 の L00 の比較の後、設計者が採用した Top の互換の骨格である（L00.08 の一括の問い、問 1・13）。範囲を持つ
原子の型 `α` を引数に取り、旧の原子を Top の範囲の原子へ写す対応 `TopEmbedding` と、原子の型を一般化した効果
`GEff α`、旧の効果からの変換 `TopEmbedding.lift` とその構造補題を置く。L10 で本番の原子に範囲の引数（案 (i)）を
加えるとき、旧の効果の補題を Top の互換の系として取り戻すために使う。

包含は構造上の包含（原子ごとの所属）のままであり、範囲の意味の被覆は別の関係として L10.3 で定める（問 13。
判断 5 の「相互包含から型の等号を導かない」）。Fail の列は旧の型 `Release.Ty` のままである。具体化の例と
意味の被覆の反例は `Scope.CompatExamples` に置く。

本番での扱い（L50.3 の整理）: L10.2 は本番の原子 `Release.Atom` そのものに範囲の位置を加えたので、本ファイルの
`Release.Atom` は範囲を持つ本番の原子を指し、本番の原子で `TopEmbedding` を具体化すると恒等になる。そのため L10.5
は具体化せず、旧の像は本番の側で `Release.Atom.TopImage`・`Release.Eff.TopAtoms`（`Release/EffectCover.lean`）として
述べた。旧の像での同値は、その述語を前提に持つ本番の補題（`Eff.covers_iff_sub_of_topAtoms`・
`Eff.mem_iff_of_topAtoms`・`Eff.sub_iff_of_topAtoms`、`Release/CoverCompat.lean`・`Release/Semantics.lean` の
`*_iff_old`）が受け持ち、本ファイルの `old_*` と重なっていた本番の旧の言明の系は L50.3 で除いた。本ファイルの
定義と `old_*` は L00 のモデル（`Scope.CompatExamples`・`Scope.SwitchExamples`）だけが使い、本番の定理は使わない。
-/

namespace Benitoite.Scope.TopCompat

open Benitoite.Release

/-! ## 旧の原子から範囲を持つ原子への埋め込み -/

/-- 旧の原子を Top の範囲の原子へ写す対応。Top の原子だけが旧の原子へ戻る。 -/
structure TopEmbedding (α : Type) where
  ofRelease : Release.Atom → α
  toRelease? : α → Option Release.Atom
  to_of : ∀ a, toRelease? (ofRelease a) = some a
  of_to : ∀ {x a}, toRelease? x = some a → x = ofRelease a

namespace TopEmbedding

variable {α : Type} (emb : TopEmbedding α)

theorem ofRelease_injective {a b : Release.Atom} (h : emb.ofRelease a = emb.ofRelease b) : a = b := by
  have := congrArg emb.toRelease? h
  rwa [emb.to_of, emb.to_of, Option.some.injEq] at this

/-- 旧の原子の所属関数を、Top の原子だけの所属関数として読む。 -/
def liftAtoms (f : Release.Atom → Bool) (x : α) : Bool :=
  match emb.toRelease? x with
  | some a => f a
  | none => false

theorem liftAtoms_ofRelease (f : Release.Atom → Bool) (a : Release.Atom) :
    emb.liftAtoms f (emb.ofRelease a) = f a := by
  simp [liftAtoms, emb.to_of]

/-- 旧の所属関数を読んだものは、旧の表現を持たない原子（非 Top の原子）を含まない。 -/
theorem liftAtoms_none (f : Release.Atom → Bool) {x : α} (h : emb.toRelease? x = none) :
    emb.liftAtoms f x = false := by
  simp [liftAtoms, h]

theorem liftAtoms_true {f : Release.Atom → Bool} {x : α} (h : emb.liftAtoms f x = true) :
    ∃ a, x = emb.ofRelease a ∧ f a = true := by
  unfold liftAtoms at h
  split at h
  · next a ha => exact ⟨a, emb.of_to ha, h⟩
  · cases h

end TopEmbedding

/-! ## 一般化した効果 -/

/-- 原子の型を `α` に一般化した効果。名前と行の所属関数と、Fail の型の生の列（旧の型）を持つ。 -/
structure GEff (α : Type) where
  atoms : α → Bool
  fails : List Ty

namespace GEff

variable {α : Type}

def mem (e : GEff α) (a : α) : Prop := e.atoms a = true

/-- Fail の所属は、旧と同じく要素の正規形で定める。 -/
def memFail (e : GEff α) (t : Ty) : Prop := ∃ x ∈ e.fails, x.norm = t.norm

/-- Fail の列だけを持つ旧の効果。Fail の正規化と順序の補題を旧の効果から流用するために使う。 -/
def failPart (e : GEff α) : Eff := .mk (fun _ => false) e.fails

/-- 正規化。原子の所属を変えず、Fail の列を旧と同じ固定順で整列し重複を除く。 -/
noncomputable def norm (e : GEff α) : GEff α := ⟨e.atoms, (Eff.norm e.failPart).fails⟩

def Canonical (e : GEff α) : Prop := e.norm = e

/-- 構造上の包含。原子ごとの所属と Fail の所属を要求する。範囲の意味の被覆は使わない。 -/
def Sub (e f : GEff α) : Prop := (∀ a, mem e a → mem f a) ∧ (∀ t, memFail e t → memFail f t)

def empty : GEff α := ⟨fun _ => false, []⟩

noncomputable def union (e f : GEff α) : GEff α := norm ⟨fun a => e.atoms a || f.atoms a, e.fails ++ f.fails⟩

theorem ext {e f : GEff α} (ha : ∀ a, mem e a ↔ mem f a) (hf : e.fails = f.fails) : e = f := by
  cases e with
  | mk a fs =>
    cases f with
    | mk b gs =>
      have hab : a = b := funext (fun x => Bool.eq_iff_iff.mpr (ha x))
      cases hab; cases hf; rfl

theorem memFail_failPart (e : GEff α) (t : Ty) : Eff.memFail e.failPart t ↔ memFail e t := Iff.rfl

theorem norm_failPart (e : GEff α) : (norm e).failPart = Eff.norm e.failPart := by
  simp [norm, failPart, Eff.norm, Eff.fails]

@[simp] theorem mem_norm (e : GEff α) (a : α) : mem (norm e) a ↔ mem e a := Iff.rfl

theorem norm_memFail (e : GEff α) (t : Ty) : memFail (norm e) t ↔ memFail e t := by
  rw [← memFail_failPart, norm_failPart, Eff.norm_memFail, memFail_failPart]

theorem norm_idem (e : GEff α) : norm (norm e) = norm e := by
  have h := Eff.norm_idem e.failPart
  rw [← norm_failPart, ← norm_failPart] at h
  exact ext (fun _ => Iff.rfl) (congrArg Eff.fails h)

theorem canonical_failPart {e : GEff α} (h : Canonical e) : Eff.Canonical e.failPart := by
  unfold Eff.Canonical; rw [← norm_failPart]; unfold Canonical at h; rw [h]

theorem sub_norm (e f : GEff α) : Sub e f ↔ Sub (norm e) (norm f) := by
  simp only [Sub, mem_norm, norm_memFail]

/-- 一般化した `Eff.eq_of_sub_of_sub`。正規形どうしの構造上の相互包含から、生の等号を導く。
証明は Fail の部分を旧の補題へ帰着させる。 -/
theorem eq_of_sub_of_sub {e f : GEff α} (he : Canonical e) (hf : Canonical f)
    (hef : Sub e f) (hfe : Sub f e) : e = f := by
  have hp : e.failPart = f.failPart :=
    Eff.eq_of_sub_of_sub (canonical_failPart he) (canonical_failPart hf)
      ⟨fun a h => by simp [failPart, Eff.mem, Eff.test, Eff.atoms] at h, hef.2⟩
      ⟨fun a h => by simp [failPart, Eff.mem, Eff.test, Eff.atoms] at h, hfe.2⟩
  exact ext (fun a => ⟨hef.1 a, hfe.1 a⟩) (congrArg Eff.fails hp)

theorem mem_union (e f : GEff α) (a : α) : mem (union e f) a ↔ mem e a ∨ mem f a := by
  simp [union, mem, norm]

theorem memFail_union (e f : GEff α) (t : Ty) : memFail (union e f) t ↔ memFail e t ∨ memFail f t := by
  unfold union
  rw [norm_memFail]
  simp only [memFail, List.mem_append, or_and_right, exists_or]

theorem mem_empty (a : α) : mem (empty : GEff α) a ↔ False := by simp [mem, empty]

theorem memFail_empty (t : Ty) : memFail (empty : GEff α) t ↔ False := by simp [memFail, empty]

theorem union_canonical (e f : GEff α) : Canonical (union e f) := norm_idem _

/-! ### 構造の等号の利用側（旧の 4 件の一般化） -/

/-- 一般化した `Eff.norm_ext`。 -/
theorem norm_ext {e f : GEff α} (ha : ∀ a, mem e a ↔ mem f a) (ht : ∀ t, memFail e t ↔ memFail f t) :
    norm e = norm f := by
  apply eq_of_sub_of_sub (norm_idem e) (norm_idem f)
  · exact (sub_norm e f).mp ⟨fun a => (ha a).mp, fun t => (ht t).mp⟩
  · exact (sub_norm f e).mp ⟨fun a => (ha a).mpr, fun t => (ht t).mpr⟩

/-- 一般化した `Eff.ext_canonical`。 -/
theorem ext_canonical {e f : GEff α} (he : Canonical e) (hf : Canonical f)
    (ha : ∀ a, mem e a ↔ mem f a) (ht : ∀ t, memFail e t ↔ memFail f t) : e = f :=
  eq_of_sub_of_sub he hf ⟨fun a => (ha a).mp, fun t => (ht t).mp⟩
    ⟨fun a => (ha a).mpr, fun t => (ht t).mpr⟩

/-- 一般化した `Surface.union_empty_right_nested`。 -/
theorem union_empty_right_nested (a b : GEff α) : union a (union b empty) = union a b := by
  apply eq_of_sub_of_sub (union_canonical _ _) (union_canonical _ _)
  all_goals
    simp only [Sub, mem_union, memFail_union, mem_empty, memFail_empty, or_false]
    exact ⟨fun _ => id, fun _ => id⟩

/-- 一般化した `Surface.union_empty_left_nested`。 -/
theorem union_empty_left_nested (a b : GEff α) : union a (union empty b) = union a b := by
  apply eq_of_sub_of_sub (union_canonical _ _) (union_canonical _ _)
  all_goals
    simp only [Sub, mem_union, memFail_union, mem_empty, memFail_empty, false_or]
    exact ⟨fun _ => id, fun _ => id⟩

end GEff

/-! ## 旧の効果からの変換と構造補題 -/

namespace TopEmbedding

variable {α : Type} (emb : TopEmbedding α)

/-- 旧の効果を、Top の範囲の原子だけを持つ一般化した効果へ写す。Fail の列は変えない。 -/
def lift (e : Eff) : GEff α := ⟨emb.liftAtoms e.atoms, e.fails⟩

theorem lift_mem_ofRelease (e : Eff) (a : Release.Atom) :
    (emb.lift e).mem (emb.ofRelease a) ↔ Eff.mem e a := by
  simp [lift, GEff.mem, Eff.mem, Eff.test, emb.liftAtoms_ofRelease]

/-- 写した効果の原子は、旧の原子の像だけである。 -/
theorem lift_mem {e : Eff} {x : α} (h : (emb.lift e).mem x) : ∃ a, x = emb.ofRelease a ∧ Eff.mem e a :=
  emb.liftAtoms_true h

theorem lift_memFail (e : Eff) (t : Ty) : (emb.lift e).memFail t ↔ Eff.memFail e t := Iff.rfl

theorem lift_injective {e f : Eff} (h : emb.lift e = emb.lift f) : e = f := by
  apply Eff.ext (fun a => ?_) (congrArg GEff.fails h)
  rw [← emb.lift_mem_ofRelease e a, ← emb.lift_mem_ofRelease f a, h]

/-- 変換は構造上の包含を両向きに保つ。 -/
theorem lift_sub_iff (e f : Eff) : GEff.Sub (emb.lift e) (emb.lift f) ↔ Eff.Sub e f := by
  constructor
  · rintro ⟨ha, hf⟩
    exact ⟨fun a h => (emb.lift_mem_ofRelease f a).mp (ha _ ((emb.lift_mem_ofRelease e a).mpr h)), hf⟩
  · rintro ⟨ha, hf⟩
    refine ⟨fun x hx => ?_, hf⟩
    obtain ⟨a, rfl, h⟩ := emb.lift_mem hx
    exact (emb.lift_mem_ofRelease f a).mpr (ha a h)

theorem lift_norm (e : Eff) : emb.lift (Eff.norm e) = GEff.norm (emb.lift e) := by
  cases e with
  | mk a fs => simp [lift, GEff.norm, GEff.failPart, Eff.norm, Eff.atoms, Eff.fails]

theorem lift_canonical_iff (e : Eff) : GEff.Canonical (emb.lift e) ↔ Eff.Canonical e := by
  unfold GEff.Canonical Eff.Canonical
  rw [← lift_norm]
  exact ⟨emb.lift_injective, fun h => by rw [h]⟩

theorem lift_union (e f : Eff) : emb.lift (Eff.union e f) = GEff.union (emb.lift e) (emb.lift f) := by
  unfold Eff.union GEff.union
  rw [lift_norm]
  congr 1
  simp only [lift, GEff.mk.injEq]
  constructor
  · funext x
    unfold liftAtoms
    split <;> simp [Eff.test, Eff.atoms]
  · simp [Eff.fails]

theorem lift_empty : emb.lift Eff.empty = (GEff.empty : GEff α) := by
  simp only [lift, GEff.empty, GEff.mk.injEq]
  constructor
  · funext x; unfold liftAtoms; split <;> rfl
  · rfl

/-- 旧 `Eff.single l` は、Top の名前の一原子の効果へ写る。 -/
theorem lift_single [DecidableEq α] (l : EffName) :
    emb.lift (Eff.single l) = ⟨fun x => decide (x = emb.ofRelease (.nameTop l)), []⟩ := by
  simp only [lift, GEff.mk.injEq]
  constructor
  · funext x
    unfold liftAtoms
    split
    · next a ha =>
      have hx := emb.of_to ha
      subst hx
      simp only [Eff.single, Eff.ofAtoms, Eff.atoms]
      by_cases h : a = .nameTop l
      · subst h; simp
      · have : emb.ofRelease a ≠ emb.ofRelease (.nameTop l) := fun e => h (emb.ofRelease_injective e)
        simp [h, this]
    · next ha =>
      have : x ≠ emb.ofRelease (.nameTop l) := by
        rintro rfl; rw [emb.to_of] at ha; cases ha
      simp [this]
  · rfl

/-! ### 旧の言明を Top の互換の系として取り戻す -/

/-- 旧 `union_empty_right_nested` の言明を、一般化した補題と変換から得る。 -/
theorem old_union_empty_right_nested (emb : TopEmbedding α) (a b : Eff) :
    Eff.union a (Eff.union b Eff.empty) = Eff.union a b := by
  apply emb.lift_injective
  rw [lift_union, lift_union, lift_empty, lift_union]
  exact GEff.union_empty_right_nested _ _

/-- 旧 `union_empty_left_nested` の言明を、一般化した補題と変換から得る。 -/
theorem old_union_empty_left_nested (emb : TopEmbedding α) (a b : Eff) :
    Eff.union a (Eff.union Eff.empty b) = Eff.union a b := by
  apply emb.lift_injective
  rw [lift_union, lift_union, lift_empty, lift_union]
  exact GEff.union_empty_left_nested _ _

/-- 旧 `Eff.ext_canonical` の言明を、一般化した補題と変換から得る。 -/
theorem old_ext_canonical (emb : TopEmbedding α) {e f : Eff} (he : Eff.Canonical e) (hf : Eff.Canonical f)
    (ha : ∀ a, Eff.mem e a ↔ Eff.mem f a) (ht : ∀ t, Eff.memFail e t ↔ Eff.memFail f t) : e = f := by
  apply emb.lift_injective
  apply GEff.ext_canonical ((emb.lift_canonical_iff e).mpr he) ((emb.lift_canonical_iff f).mpr hf)
  · intro x
    constructor
    · intro hx
      obtain ⟨a, rfl, h⟩ := emb.lift_mem hx
      exact (emb.lift_mem_ofRelease f a).mpr ((ha a).mp h)
    · intro hx
      obtain ⟨a, rfl, h⟩ := emb.lift_mem hx
      exact (emb.lift_mem_ofRelease e a).mpr ((ha a).mpr h)
  · exact ht

/-- 旧 `Eff.norm_ext` の言明を、一般化した補題と変換から得る。 -/
theorem old_norm_ext (emb : TopEmbedding α) {e f : Eff} (ha : ∀ a, Eff.mem e a ↔ Eff.mem f a)
    (ht : ∀ t, Eff.memFail e t ↔ Eff.memFail f t) : Eff.norm e = Eff.norm f := by
  apply emb.lift_injective
  rw [lift_norm, lift_norm]
  apply GEff.norm_ext
  · intro x
    constructor
    · intro hx
      obtain ⟨a, rfl, h⟩ := emb.lift_mem hx
      exact (emb.lift_mem_ofRelease f a).mpr ((ha a).mp h)
    · intro hx
      obtain ⟨a, rfl, h⟩ := emb.lift_mem hx
      exact (emb.lift_mem_ofRelease e a).mpr ((ha a).mpr h)
  · exact ht

end TopEmbedding

end Benitoite.Scope.TopCompat
