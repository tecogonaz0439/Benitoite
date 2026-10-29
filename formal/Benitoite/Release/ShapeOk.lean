import Benitoite.Release.Assumptions
import Benitoite.Release.RangeInst

/-!
# IO の項目の形の検査と旧の `io_op`（L20.7）

信頼条件の欄 `io_op` の内容を形の検査 `Builtins.ShapeOk` に変えた（問 18 の行 1）。本モジュールは、形の検査から
証明が使う事実（`opEff`・`neffs = 0`・操作の一覧への所属、具体化した効果の名前の原子）を取り出す補題と、旧の
`io_op` の内容との対応（L00.03 のモデルの `shapeOk_old` の本番版）を置く（設計書 07-04「形式化で仮定するもの」）。

- 対象なしの形と旧 Top の形は、旧 `io_op` の内容をそのまま満たす（`Builtins.ShapeOk.old`）。
- 単一の対象の形は、Top の列で具体化した署名が旧 `io_op` の内容を満たす（`Builtins.ShapeOk.inst_top_old`）。
- 旧の像の表（項目の形が対象なし、範囲の変数がない、エフェクトの名前が対象の種類を持たない）では、新旧の欄が
  同値である（`Builtins.shapeOk_iff_old`・`Builtins.ioOp_iff_old`）。
-/

namespace Benitoite.Release

open Scope.Signature (IOShape Ix)

variable {B : Builtins} {b : PrimName} {s : PrimSig}

@[simp] theorem PrimSig.inst_shape (rs : List Scope.Domain.Range) (s : PrimSig) : (s.inst rs).shape = s.shape := rfl

/-- L20.7 の前の `io_op` の欄の内容。 -/
def Builtins.IoOpOld (B : Builtins) (b : PrimName) (s : PrimSig) : Prop :=
  ∃ l bs, s.opEff = some l ∧ s.eff = Eff.single l ∧ s.neffs = 0 ∧ B.effects l = some bs ∧ b ∈ bs

/-- 範囲の位置 ix の名前一つの効果を具体化すると、範囲の位置を具体化した名前一つの効果になる。 -/
@[simp] theorem Eff.instR_singleAt (rs : List Scope.Domain.Range) (l : EffName) (ix : Ix) :
    Eff.instR rs (Eff.singleAt l ix) = Eff.singleAt l (ix.inst rs) := by
  simp only [Eff.singleAt, Eff.ofAtoms, Eff.instR, List.map_nil, EffR.mk.injEq, and_true]
  funext x
  apply Bool.eq_iff_iff.mpr
  rw [Eff.instAtoms_spec]
  simp only [beq_iff_eq]
  constructor
  · rintro ⟨y, rfl, rfl⟩; rfl
  · rintro rfl; exact ⟨_, rfl, rfl⟩

/-- 形の検査から、全ての形に共通する事実を取り出す。 -/
theorem Builtins.ShapeOk.common (h : B.ShapeOk b s) :
    ∃ l bs, s.opEff = some l ∧ s.neffs = 0 ∧ B.effects l = some bs ∧ b ∈ bs := by
  obtain ⟨l, bs, h1, h2, h3, h4, -⟩ := h
  exact ⟨l, bs, h1, h2, h3, h4⟩

/-- 形の検査を通る項目の効果は、名前 l の原子一つ（範囲の位置は Top か範囲の変数 0）である。 -/
theorem Builtins.ShapeOk.eff_eq (h : B.ShapeOk b s) :
    ∃ l bs ix, s.opEff = some l ∧ B.effects l = some bs ∧ b ∈ bs ∧ s.eff = Eff.singleAt l ix := by
  obtain ⟨l, bs, h1, -, h3, h4, h5⟩ := h
  refine ⟨l, bs, ?_, h1, h3, h4, ?_⟩
  · exact match s.shape with
    | .untargeted => Ix.top
    | .topTargeted _ => Ix.top
    | .single _ _ => .rvar 0
  · split at h5
    · next hs => simp only [hs]; exact h5.2.2
    · next hs => simp only [hs]; exact h5.2.2
    · next hs => simp only [hs]; exact h5.2.2.1

/-- 形の検査を通る項目の効果は、範囲の変数を持たない名前の原子一つか、範囲の変数 0 を範囲の位置に持つ名前の
原子一つ（範囲の変数は一つ）である。節の添字の証明（`pres_op_common` の E-OpPrim の場合。L30.1）が、呼び出しの
範囲の列を節の添字の列に一致させるのに使う。 -/
theorem Builtins.ShapeOk.eff_cases (h : B.ShapeOk b s) :
    ∃ l bs, s.opEff = some l ∧ B.effects l = some bs ∧ b ∈ bs ∧
      ((s.eff = Eff.singleAt l Ix.top ∧ s.nranges = 0) ∨ (s.eff = Eff.singleAt l (.rvar 0) ∧ s.nranges = 1)) := by
  obtain ⟨l, bs, h1, -, h3, h4, h5⟩ := h
  refine ⟨l, bs, h1, h3, h4, ?_⟩
  split at h5
  · exact Or.inl ⟨h5.2.2, by simp [PrimSig.nranges, h5.2.1]⟩
  · exact Or.inl ⟨h5.2.2, by simp [PrimSig.nranges, h5.2.1]⟩
  · exact Or.inr ⟨h5.2.2.1, by simp [PrimSig.nranges, h5.2.1]⟩

/-- 形の検査を通る項目を範囲の列 rs で具体化した効果は、名前 l の原子を含む（範囲の位置は具体化による）。
エフェクトの健全性の証明（`no_event`）が、処理されない IO の名前を継続の末尾へ運ぶのに使う。 -/
theorem Builtins.ShapeOk.inst_eff_mem (h : B.ShapeOk b s) (rs : List Scope.Domain.Range) :
    ∃ l bs ix, s.opEff = some l ∧ B.effects l = some bs ∧ b ∈ bs ∧ Eff.mem (s.inst rs).eff (.name l ix) := by
  obtain ⟨l, bs, ix, h1, h2, h3, he⟩ := h.eff_eq
  refine ⟨l, bs, ix.inst rs, h1, h2, h3, ?_⟩
  rw [PrimSig.inst_eff, he, Eff.instR_singleAt]
  exact (Eff.mem_singleAt _ _ _).mpr rfl

/-- 旧の形（対象なし・旧 Top）の項目は、旧 `io_op` の内容を満たし、範囲の変数を持たない（L00.03 の `shapeOk_old`
の本番版）。 -/
theorem Builtins.ShapeOk.old (h : B.ShapeOk b s) (hs : ∀ k p, s.shape ≠ .single k p) :
    B.IoOpOld b s ∧ s.rkinds = [] := by
  obtain ⟨l, bs, h1, h2, h3, h4, h5⟩ := h
  cases hsh : s.shape with
  | untargeted =>
      simp only [hsh] at h5
      exact ⟨⟨l, bs, h1, h5.2.2, h2, h3, h4⟩, h5.2.1⟩
  | topTargeted k =>
      simp only [hsh] at h5
      exact ⟨⟨l, bs, h1, h5.2.2, h2, h3, h4⟩, h5.2.1⟩
  | single k p => exact absurd hsh (hs k p)

/-- 単一の対象の形の項目を Top の列で具体化した署名は、旧 `io_op` の内容を満たす（具体化した効果は名前だけの
効果 `Eff.single l` である。L00.03 の `single_inst_top_eff` の本番版）。 -/
theorem Builtins.ShapeOk.inst_top_old (h : B.ShapeOk b s) {k : Scope.Domain.Kind} {p : Nat}
    (hs : s.shape = .single k p) : B.IoOpOld b (s.inst s.topRanges) ∧ s.topRanges = [.top] := by
  obtain ⟨l, bs, h1, h2, h3, h4, h5⟩ := h
  simp only [hs] at h5
  obtain ⟨-, hr, he, -⟩ := h5
  have htop : s.topRanges = [.top] := by simp [PrimSig.topRanges, PrimSig.nranges, hr]
  refine ⟨⟨l, bs, by simpa using h1, ?_, by simpa [PrimSig.inst] using h2, h3, h4⟩, htop⟩
  rw [PrimSig.inst_eff, he, Eff.instR_singleAt, htop]
  rfl

/-- 旧の像の項目（形が対象なしで、範囲の変数を持たず、エフェクトの名前が対象の種類を持たない）では、形の検査は
旧 `io_op` の内容と同値である。 -/
theorem Builtins.shapeOk_iff_old (hs : s.shape = .untargeted) (hr : s.rkinds = [])
    (hk : ∀ l, s.opEff = some l → B.effKind l = none) : B.ShapeOk b s ↔ B.IoOpOld b s := by
  constructor
  · intro h; exact (h.old (fun k p h' => by rw [hs] at h'; cases h')).1
  · rintro ⟨l, bs, h1, h2, h3, h4, h5⟩
    refine ⟨l, bs, h1, h3, h4, h5, ?_⟩
    simp only [hs]
    exact ⟨hk l h1, hr, h2⟩

/-- 旧の像の表（全ての項目の形が対象なしで範囲の変数を持たず、エフェクトの名前が対象の種類を持たない）では、
新しい `io_op` の欄は旧の欄と同値である。 -/
theorem Builtins.ioOp_iff_old (hs : ∀ b s, B.sig b = some s → s.shape = .untargeted ∧ s.rkinds = [])
    (hk : ∀ l, B.effKind l = none) :
    (∀ b s, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → B.ShapeOk b s) ↔
      (∀ b s, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → B.IoOpOld b s) := by
  constructor
  · intro h b s hb hio
    exact (Builtins.shapeOk_iff_old (hs b s hb).1 (hs b s hb).2 (fun l _ => hk l)).mp (h b s hb hio)
  · intro h b s hb hio
    exact (Builtins.shapeOk_iff_old (hs b s hb).1 (hs b s hb).2 (fun l _ => hk l)).mpr (h b s hb hio)

/-- 単一の対象の形の項目から得る事実。範囲の変数は種類 k の一つだけで、効果は `L[rvar 0]`、対象の位置の引数は
種類 k の範囲付きの値型 `O[rvar 0]` である（入力の添字と効果の一致）。 -/
theorem Builtins.ShapeOk.single (h : B.ShapeOk b s) {k : Scope.Domain.Kind} {p : Nat}
    (hs : s.shape = .single k p) :
    ∃ l o, s.opEff = some l ∧ B.effKind l = some k ∧ s.rkinds = [k] ∧ s.eff = Eff.singleAt l (.rvar 0) ∧
      s.params[p]? = some (.opaque o (.rvar 0)) ∧ B.valKind o = some k := by
  obtain ⟨l, bs, h1, -, -, -, h5⟩ := h
  simp only [hs] at h5
  obtain ⟨h6, h7, h8, o, h9, h10⟩ := h5
  exact ⟨l, o, h1, h6, h7, h8, h9, h10⟩

/-- 単一の対象の形の項目を一つの範囲 R で具体化すると、対象の位置の引数の添字と効果の原子が同じ R を指す
（L00.03 の `single_inst_same_range` の本番版）。 -/
theorem Builtins.ShapeOk.single_inst (h : B.ShapeOk b s) {k : Scope.Domain.Kind} {p : Nat}
    (hs : s.shape = .single k p) (R : Scope.Domain.Range) :
    ∃ l o, s.opEff = some l ∧ B.effKind l = some k ∧ (s.inst [R]).eff = Eff.singleAt l (.fixed R) ∧
      (s.inst [R]).params[p]? = some (.opaque o (.fixed R)) ∧ B.valKind o = some k := by
  obtain ⟨l, o, h1, h2, -, he, hp, hk⟩ := h.single hs
  refine ⟨l, o, h1, h2, ?_, ?_, hk⟩
  · rw [PrimSig.inst_eff, he, Eff.instR_singleAt]; rfl
  · rw [PrimSig.inst_params, List.getElem?_map, hp]; rfl

end Benitoite.Release
