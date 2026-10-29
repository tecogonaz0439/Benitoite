import Benitoite.Release.RangeWF
import Benitoite.Release.SubstEnv

/-!
# 署名の範囲の変数の具体化と範囲の具体化の許容

組み込みの署名の範囲の変数（`Scope.Signature.Ix.rvar i`）を、呼び出しが選ぶ閉じた範囲の列 `rs` で具体化する
（設計書 01-12「構文」の「署名の範囲の変数と具体化」、問 2・5）。具体化の形は次のとおりである（RV-PL10 重大1、
plan-l10-l50 の注「具体化の条件の置き場所」）。

- 結果の型と効果は、全ての範囲の位置を具体化する（`Ty.instR`・`Eff.instR`）。
- 引数の型は、最上位の対象の位置（`Ty.opaque o (rvar i)` の形の引数）だけを具体化し、ほかの位置の範囲の変数を
  残す（`Ty.instTarget`）。`inst rs` と `inst [Top, …]` の引数の型は最上位の対象の位置だけで違うので、捕捉した
  引数を Top の型へ拡大する補題は葉の値だけで済む（`PrimSig.inst_params_agree_off_target`）。
- 長さの足りない具体化は範囲の変数を残し、黙って Top に狭めない（`Ix.inst`）。

具体化の関数と `PrimSig.inst`・`Builtins.RangeAdmissible` の定義は、型付けの規則 V-Prim が使うので
`Release/RangeInstDef.lean` と `Release/Typing.lean` にある。本ファイルは、具体化と型代入・行代入・shift の交換、
空の具体化、個数の合う閉じた列での整形式性と変数の範囲（`Ty.instR_varsIn_zero`）、範囲の具体化の許容の性質、
`PrimSig.Scoped`（`sig_scoped`・`hsig` が読む形）と範囲の変数の番号の上限で読む `PrimSig.ScopedRanges` の関係、
範囲の変数のない項目の V-Prim（`HasTypeVQ.V_PrimNil`）を置く。
-/

namespace Benitoite.Release

open Order

/-! ## 範囲の位置の具体化の補助 -/

namespace RangeInst

/-- 具体化の結果が閉じた範囲になるのは、元が同じ閉じた範囲か、具体化の列がその範囲を与える範囲の変数のときである。 -/
theorem ix_inst_eq_fixed_iff {rs : List Scope.Domain.Range} {ix : Scope.Signature.Ix} {r : Scope.Domain.Range} :
    ix.inst rs = .fixed r ↔ ix = .fixed r ∨ ∃ i, ix = .rvar i ∧ rs[i]? = some r := by
  cases ix with
  | fixed r' => simp [Scope.Signature.Ix.inst]
  | rvar i =>
    constructor
    · intro h
      right
      refine ⟨i, rfl, ?_⟩
      cases hi : rs[i]? with
      | none => simp [Scope.Signature.Ix.inst, hi] at h
      | some r' => simp only [Scope.Signature.Ix.inst, hi, Scope.Signature.Ix.fixed.injEq] at h; rw [h]
    · rintro (h | ⟨j, hj, hr⟩)
      · cases h
      · cases hj; simp [Scope.Signature.Ix.inst, hr]

/-- 具体化の結果が範囲の変数として残るのは、元が同じ範囲の変数で、具体化の列が短いときだけである。 -/
theorem ix_inst_eq_rvar_iff {rs : List Scope.Domain.Range} {ix : Scope.Signature.Ix} {i : Nat} :
    ix.inst rs = .rvar i ↔ ix = .rvar i ∧ rs[i]? = none := by
  cases ix with
  | fixed r' => simp [Scope.Signature.Ix.inst]
  | rvar j =>
    constructor
    · intro h
      cases hj : rs[j]? with
      | none =>
        simp only [Scope.Signature.Ix.inst, hj, Scope.Signature.Ix.rvar.injEq] at h
        subst h; exact ⟨rfl, hj⟩
      | some r' => simp [Scope.Signature.Ix.inst, hj] at h
    · rintro ⟨hj, hr⟩
      cases hj; simp [Scope.Signature.Ix.inst, hr]

end RangeInst

/-! ## 原子と効果の具体化 -/

@[simp] theorem Atom.instR_rho (rs : List Scope.Domain.Range) (i : Nat) : (Atom.rho i).instR rs = .rho i := rfl

@[simp] theorem Atom.instR_nil (x : Atom) : x.instR [] = x := by
  cases x <;> simp [Atom.instR]

/-- 具体化した所属関数の所属は、元の所属関数の原子の具体化の像である。 -/
theorem Eff.instAtoms_spec (rs : List Scope.Domain.Range) (a : Atom → Bool) (x : Atom) :
    Eff.instAtoms rs a x = true ↔ ∃ y, a y = true ∧ y.instR rs = x := by
  cases x with
  | rho i =>
    simp only [Eff.instAtoms]
    constructor
    · intro h; exact ⟨.rho i, h, rfl⟩
    · rintro ⟨y, hy, he⟩
      cases y with
      | name l ix => simp [Atom.instR] at he
      | rho j => simp only [Atom.instR, Atom.rho.injEq] at he; subst he; exact hy
  | name l ix =>
    cases ix with
    | fixed r =>
      simp only [Eff.instAtoms, Bool.or_eq_true, List.any_eq_true, List.mem_range, Bool.and_eq_true,
        decide_eq_true_eq]
      constructor
      · rintro (h | ⟨i, _, h, hi⟩)
        · exact ⟨_, h, rfl⟩
        · exact ⟨.name l (.rvar i), h, by simp [Atom.instR, Scope.Signature.Ix.inst, hi]⟩
      · rintro ⟨y, hy, he⟩
        cases y with
        | rho j => simp [Atom.instR] at he
        | name l' ix' =>
          simp only [Atom.instR, Atom.name.injEq] at he
          obtain ⟨rfl, he⟩ := he
          rcases RangeInst.ix_inst_eq_fixed_iff.mp he with rfl | ⟨i, rfl, hi⟩
          · exact Or.inl hy
          · exact Or.inr ⟨i, (List.getElem?_eq_some_iff.mp hi).1, hy, hi⟩
    | rvar i =>
      simp only [Eff.instAtoms, Bool.and_eq_true, Option.isNone_iff_eq_none]
      constructor
      · rintro ⟨h, hi⟩
        exact ⟨_, h, by simp [Atom.instR, Scope.Signature.Ix.inst, hi]⟩
      · rintro ⟨y, hy, he⟩
        cases y with
        | rho j => simp [Atom.instR] at he
        | name l' ix' =>
          simp only [Atom.instR, Atom.name.injEq] at he
          obtain ⟨rfl, he⟩ := he
          obtain ⟨rfl, hi⟩ := RangeInst.ix_inst_eq_rvar_iff.mp he
          exact ⟨hy, hi⟩

/-- 空の具体化は所属関数を変えない。 -/
@[simp] theorem Eff.instAtoms_nil (a : Atom → Bool) : Eff.instAtoms [] a = a := by
  funext x
  apply Bool.eq_iff_iff.mpr
  rw [Eff.instAtoms_spec]
  simp

/-- 行の原子の所属は具体化で変わらない。 -/
@[simp] theorem Eff.instAtoms_rho (rs : List Scope.Domain.Range) (a : Atom → Bool) (i : Nat) :
    Eff.instAtoms rs a (.rho i) = a (.rho i) := rfl

/-- 範囲の変数の番号の上限を満たす原子は、個数の足りる具体化の後に範囲の変数を持たない。 -/
theorem Atom.instR_wf_zero {nr : Nat} {x : Atom} (h : x.WF nr) {rs : List Scope.Domain.Range}
    (hn : nr ≤ rs.length) : (x.instR rs).WF 0 := by
  cases x with
  | name l ix => exact Scope.Signature.Ix.inst_wf_zero h hn
  | rho i => trivial

/-- 範囲の変数のない原子は、どの具体化でも変わらない。 -/
theorem Atom.instR_of_wf_zero {x : Atom} (h : x.WF 0) (rs : List Scope.Domain.Range) : x.instR rs = x := by
  cases x with
  | name l ix => simp only [Atom.instR, Scope.Signature.Ix.inst_of_wf_zero h]
  | rho i => rfl

/-- 範囲の変数のない原子だけの所属関数は、どの具体化でも変わらない。 -/
theorem Eff.instAtoms_of_wf_zero {a : Atom → Bool} (h : ∀ x, a x = true → x.WF 0)
    (rs : List Scope.Domain.Range) : Eff.instAtoms rs a = a := by
  funext x
  apply Bool.eq_iff_iff.mpr
  rw [Eff.instAtoms_spec]
  constructor
  · rintro ⟨y, hy, rfl⟩; rwa [Atom.instR_of_wf_zero (h y hy)]
  · intro hx; exact ⟨x, hx, Atom.instR_of_wf_zero (h x hx) rs⟩

/-! ## 型と効果の具体化 -/

@[simp] theorem Ty.rawInstRTys_eq_map (rs : List Scope.Domain.Range) (as : List Ty) :
    Ty.rawInstRTys rs as = as.map (Ty.rawInstR rs) := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [Ty.rawInstRTys, List.map_cons, ih]

@[simp] theorem PrimSig.inst_names (rs : List Scope.Domain.Range) (s : PrimSig) : (s.inst rs).names = s.names := rfl
@[simp] theorem PrimSig.inst_params (rs : List Scope.Domain.Range) (s : PrimSig) :
    (s.inst rs).params = s.params.map (Ty.instTarget rs) := rfl
@[simp] theorem PrimSig.inst_ret (rs : List Scope.Domain.Range) (s : PrimSig) : (s.inst rs).ret = s.ret.instR rs := rfl
@[simp] theorem PrimSig.inst_eff (rs : List Scope.Domain.Range) (s : PrimSig) :
    (s.inst rs).eff = Eff.instR rs s.eff := rfl
@[simp] theorem PrimSig.inst_ntys (rs : List Scope.Domain.Range) (s : PrimSig) : (s.inst rs).ntys = s.ntys := rfl
@[simp] theorem PrimSig.inst_neffs (rs : List Scope.Domain.Range) (s : PrimSig) : (s.inst rs).neffs = s.neffs := rfl
@[simp] theorem PrimSig.inst_kind (rs : List Scope.Domain.Range) (s : PrimSig) : (s.inst rs).kind = s.kind := rfl
@[simp] theorem PrimSig.inst_opEff (rs : List Scope.Domain.Range) (s : PrimSig) : (s.inst rs).opEff = s.opEff := rfl
@[simp] theorem PrimSig.inst_admits (rs : List Scope.Domain.Range) (s : PrimSig) : (s.inst rs).admits = s.admits := rfl
@[simp] theorem PrimSig.inst_rkinds (rs : List Scope.Domain.Range) (s : PrimSig) : (s.inst rs).rkinds = s.rkinds := rfl

/-! ## 空の具体化と範囲の変数のない型 -/

mutual
  @[simp] theorem Ty.rawInstR_nil (t : Ty) : t.rawInstR [] = t := by
    cases t <;> simp only [Ty.rawInstR, Ty.rawInstR_nil, Ty.rawInstRTys_nil, Eff.rawInstR_nil,
      Scope.Signature.Ix.inst_nil]

  @[simp] theorem Ty.rawInstRTys_nil (as : List Ty) : Ty.rawInstRTys [] as = as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.rawInstRTys, Ty.rawInstR_nil, Ty.rawInstRTys_nil]

  @[simp] theorem Eff.rawInstR_nil (e : Eff) : Eff.rawInstR [] e = e := by
    cases e with
    | mk a fs => simp only [Eff.rawInstR, Eff.instAtoms_nil, Ty.rawInstRTys_nil]
end

/-- 空の具体化は、型を正規化するだけである。 -/
theorem Ty.instR_nil (t : Ty) : t.instR [] = t.norm := by simp [Ty.instR]

@[simp] theorem Ty.instTarget_nil (t : Ty) : t.instTarget [] = t := by
  cases t <;> simp [Ty.instTarget]

mutual
  /-- 範囲の変数のない型（`Ty.RangesIn 0`）は、どの具体化でも変わらない。 -/
  theorem Ty.rawInstR_of_rangesIn (rs : List Scope.Domain.Range) (t : Ty) (h : Ty.RangesIn 0 t) :
      t.rawInstR rs = t := by
    cases t <;> simp only [Ty.RangesIn] at h <;> simp only [Ty.rawInstR]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.rawInstR_of_rangesIn rs _ h)
      | exact congrArg _ (Ty.rawInstRTys_of_rangesIn rs _ h)
      | skip
    case «opaque» o ix => rw [Scope.Signature.Ix.inst_of_wf_zero h]
    case fn ns ps r e =>
      rw [Ty.rawInstRTys_of_rangesIn rs ps h.1, Ty.rawInstR_of_rangesIn rs r h.2.1,
        Eff.rawInstR_of_rangesIn rs e h.2.2]
    case cont b t e =>
      rw [Ty.rawInstR_of_rangesIn rs b h.1, Ty.rawInstR_of_rangesIn rs t h.2.1,
        Eff.rawInstR_of_rangesIn rs e h.2.2]
    case map a b => rw [Ty.rawInstR_of_rangesIn rs a h.1, Ty.rawInstR_of_rangesIn rs b h.2]

  theorem Ty.rawInstRTys_of_rangesIn (rs : List Scope.Domain.Range) (as : List Ty) (h : Ty.RangesInList 0 as) :
      Ty.rawInstRTys rs as = as := by
    cases as with
    | nil => rfl
    | cons a as =>
      simp only [Ty.rawInstRTys, Ty.rawInstR_of_rangesIn rs a h.1, Ty.rawInstRTys_of_rangesIn rs as h.2]

  theorem Eff.rawInstR_of_rangesIn (rs : List Scope.Domain.Range) (e : Eff) (h : Eff.RangesIn 0 e) :
      Eff.rawInstR rs e = e := by
    cases e with
    | mk a fs =>
      simp only [Eff.rawInstR, Eff.instAtoms_of_wf_zero h.1, Ty.rawInstRTys_of_rangesIn rs fs h.2]
end

/-- 範囲の変数のない正規形の型は、どの具体化でも変わらない。プログラムの型（`Ty.VarsIn 0`）はこの形である。 -/
theorem Ty.instR_of_rangesIn {t : Ty} (h : Ty.RangesIn 0 t) (hc : t.Canonical) (rs : List Scope.Domain.Range) :
    t.instR rs = t := by
  rw [Ty.instR, Ty.rawInstR_of_rangesIn rs t h]; exact hc

/-! ## 正規化と具体化の交換 -/

mutual
  /-- 正規化してから生の具体化を行っても、結果の正規形は同じである（Fail の列の並びと重複だけが違う）。 -/
  theorem Ty.norm_rawInstR (rs : List Scope.Domain.Range) (t : Ty) :
      (t.norm.rawInstR rs).norm = (t.rawInstR rs).norm := by
    cases t <;> simp only [Ty.norm, Ty.rawInstR, Ty.norm_rawInstR, Ty.normTys_rawInstR, Eff.norm_rawInstR]

  theorem Ty.normTys_rawInstR (rs : List Scope.Domain.Range) (as : List Ty) :
      Ty.normTys (Ty.rawInstRTys rs (Ty.normTys as)) = Ty.normTys (Ty.rawInstRTys rs as) := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.normTys, Ty.rawInstRTys, Ty.norm_rawInstR, Ty.normTys_rawInstR]

  theorem Eff.norm_rawInstR (rs : List Scope.Domain.Range) (e : Eff) :
      Eff.norm (Eff.rawInstR rs (Eff.norm e)) = Eff.norm (Eff.rawInstR rs e) := by
    cases e with
    | mk a fs =>
      simp only [Eff.norm, Eff.rawInstR]
      congr 1
      simp only [Ty.normTys_eq_map, Ty.rawInstRTys_eq_map, List.map_map]
      rw [sortUnique_map_sortUnique (cmp := tyCompare) (cmp' := tyCompare)]
      exact congrArg (sortUnique tyCompare) (by
        simpa only [Ty.normTys_eq_map, Ty.rawInstRTys_eq_map, List.map_map, Function.comp_def] using
          Ty.normTys_rawInstR rs fs)
end

/-- 計算の最上位の効果の具体化も、正規化すれば生の具体化の正規形と同じである。 -/
theorem Eff.norm_instR (rs : List Scope.Domain.Range) (e : Eff) :
    Eff.norm (Eff.instR rs e) = Eff.norm (Eff.rawInstR rs e) := by
  cases e with
  | mk a fs =>
    simp only [Eff.instR, Eff.rawInstR, Eff.norm, Ty.instR, Ty.normTys_eq_map, Ty.rawInstRTys_eq_map,
      List.map_map, Function.comp_def, Ty.norm_idem]

/-- 型の具体化は、正規化の前後どちらで行っても同じである。 -/
theorem Ty.instR_norm (rs : List Scope.Domain.Range) (t : Ty) : t.norm.instR rs = t.instR rs :=
  Ty.norm_rawInstR rs t

/-! ## 具体化と shift の交換 -/

mutual
  theorem Ty.rawInstR_rawShift (rs : List Scope.Domain.Range) (k c : Nat) (t : Ty) :
      (t.rawShift k c).rawInstR rs = (t.rawInstR rs).rawShift k c := by
    cases t <;> simp only [Ty.rawShift, Ty.rawInstR, Ty.rawInstR_rawShift, Ty.rawInstRTys_rawShift,
      Eff.rawInstR_rawShift]

  theorem Ty.rawInstRTys_rawShift (rs : List Scope.Domain.Range) (k c : Nat) (as : List Ty) :
      Ty.rawInstRTys rs (Ty.rawShiftTys k c as) = Ty.rawShiftTys k c (Ty.rawInstRTys rs as) := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.rawShiftTys, Ty.rawInstRTys, Ty.rawInstR_rawShift, Ty.rawInstRTys_rawShift]

  theorem Eff.rawInstR_rawShift (rs : List Scope.Domain.Range) (k c : Nat) (e : Eff) :
      Eff.rawInstR rs (Eff.rawShift k c e) = Eff.rawShift k c (Eff.rawInstR rs e) := by
    cases e with
    | mk a fs => simp only [Eff.rawShift, Eff.rawInstR, Ty.rawInstRTys_rawShift]
end

/-- 具体化は型の変数の移動と交換する。 -/
theorem Ty.instR_shift (rs : List Scope.Domain.Range) (k c : Nat) (t : Ty) :
    (t.shift k c).instR rs = (t.instR rs).shift k c := by
  rw [Ty.shift_eq_norm_rawShift, Ty.instR_norm, Ty.instR, Ty.rawInstR_rawShift, Ty.instR,
    Ty.shift_eq_norm_rawShift, Ty.norm_rawShift, Ty.norm_rawShift, Ty.norm_idem]

/-- 引数の具体化も型の変数の移動と交換する（移動は不透明型を変えず、不透明型でない型を不透明型にしない）。 -/
theorem Ty.instTarget_shift (rs : List Scope.Domain.Range) (k c : Nat) (t : Ty) :
    (t.shift k c).instTarget rs = (t.instTarget rs).shift k c := by
  cases t with
  | tvar i => by_cases h : i < c <;> simp [Ty.shift, Ty.instTarget, h]
  | _ => simp [Ty.shift, Ty.instTarget]


/-! ## 具体化と型代入・行代入の交換 -/

/-- 代入の像の生の具体化。 -/
def SubstEnv.rawInstR (rs : List Scope.Domain.Range) (θ : SubstEnv) : SubstEnv :=
  ⟨fun i => (θ.types i).rawInstR rs, θ.rows.map (Eff.rawInstR rs)⟩

theorem Ty.rawInstR_rawApplyTo (rs : List Scope.Domain.Range) (t : Ty) (as : List Ty) :
    (t.rawApplyTo as).rawInstR rs = (t.rawInstR rs).rawApplyTo (Ty.rawInstRTys rs as) := by
  cases t with
  | ctor c =>
    cases c <;> cases as <;> simp only [Ty.rawApplyTo, Ty.rawInstR, TyCon.rawApply, Ty.rawInstRTys,
      List.headD_nil, List.headD_cons, List.tail_nil, List.tail_cons]
    all_goals rename_i a as
    all_goals cases as <;> rfl
  | _ => simp [Ty.rawApplyTo, Ty.rawInstR]

/-- 生の効果の具体化の所属は、元の所属関数の具体化である。 -/
theorem Eff.test_rawInstR (rs : List Scope.Domain.Range) (f : Eff) (x : Atom) :
    Eff.test (Eff.rawInstR rs f) x = Eff.instAtoms rs f.atoms x := by
  cases f; rfl

theorem Eff.fails_rawInstR (rs : List Scope.Domain.Range) (f : Eff) :
    (Eff.rawInstR rs f).fails = f.fails.map (Ty.rawInstR rs) := by
  cases f; simp [Eff.rawInstR, Eff.fails]

private theorem substAtoms_spec (es : List Eff) (a : Atom → Bool) (x : Atom) :
    Eff.substAtoms es a x = true ↔
      (match x with
        | .name l r => a (.name l r) = true
        | .rho i => es.length ≤ i ∧ a (.rho i) = true) ∨
      ∃ i f, es[i]? = some f ∧ a (.rho i) = true ∧ Eff.test f x = true :=
  Eff.mem_substAtoms es (.mk a []) x

/-- 行の置換と範囲の具体化は交換する（範囲の位置と行の変数は互いに独立である）。 -/
theorem Eff.instAtoms_substAtoms (rs : List Scope.Domain.Range) (es : List Eff) (a : Atom → Bool) :
    Eff.instAtoms rs (Eff.substAtoms es a) =
      Eff.substAtoms (es.map (Eff.rawInstR rs)) (Eff.instAtoms rs a) := by
  funext x
  apply Bool.eq_iff_iff.mpr
  rw [Eff.instAtoms_spec, substAtoms_spec]
  constructor
  · rintro ⟨y, hy, rfl⟩
    rcases (substAtoms_spec es a y).mp hy with hk | ⟨i, f, hf, ha, hfy⟩
    · left
      cases y with
      | name l r => exact (Eff.instAtoms_spec rs a _).mpr ⟨_, hk, rfl⟩
      | rho j => simpa [Atom.instR] using hk
    · right
      refine ⟨i, Eff.rawInstR rs f, by simp [hf], ha, ?_⟩
      rw [Eff.test_rawInstR, Eff.instAtoms_spec]; exact ⟨y, hfy, rfl⟩
  · rintro (hk | ⟨i, f', hf', ha, hfx⟩)
    · cases x with
      | name l r =>
        obtain ⟨y, hy, he⟩ := (Eff.instAtoms_spec rs a _).mp hk
        cases y with
        | rho j => simp [Atom.instR] at he
        | name l' r' => exact ⟨_, (substAtoms_spec es a _).mpr (Or.inl hy), he⟩
      | rho j =>
        simp only [List.length_map, Eff.instAtoms_rho] at hk
        exact ⟨.rho j, (substAtoms_spec es a _).mpr (Or.inl hk), rfl⟩
    · rw [List.getElem?_map] at hf'
      obtain ⟨f, hf, rfl⟩ := Option.map_eq_some_iff.mp hf'
      rw [Eff.test_rawInstR, Eff.instAtoms_spec] at hfx
      obtain ⟨y, hy, rfl⟩ := hfx
      exact ⟨y, (substAtoms_spec es a y).mpr (Or.inr ⟨i, f, hf, ha, hy⟩), rfl⟩

/-- 選ばれる行の像の Fail の型も、具体化と交換する。 -/
theorem Eff.rowFails_rawInstR (rs : List Scope.Domain.Range) (es : List Eff) (a : Atom → Bool) :
    Eff.rowFails (es.map (Eff.rawInstR rs)) (Eff.instAtoms rs a) = Ty.rawInstRTys rs (Eff.rowFails es a) := by
  simp only [Eff.rowFails, List.length_map, Eff.instAtoms_rho, Ty.rawInstRTys_eq_map, List.map_flatMap]
  congr 1
  funext i
  rw [List.getElem?_map]
  cases es[i]? with
  | none => rfl
  | some e => simp [Eff.fails_rawInstR]

mutual
  /-- 生の代入と生の具体化は、代入の像も具体化すれば交換する。 -/
  theorem Ty.rawInstR_rawBind (rs : List Scope.Domain.Range) (θ : SubstEnv) (t : Ty) :
      (t.rawBind θ).rawInstR rs = (t.rawInstR rs).rawBind (θ.rawInstR rs) := by
    cases t <;> simp only [Ty.rawBind, Ty.rawInstR, Ty.rawInstR_rawBind, Ty.rawInstRTys_rawBind,
      Eff.rawInstR_rawBind]
    case tvar i => rfl
    case tapp i as => rw [Ty.rawInstR_rawApplyTo, Ty.rawInstRTys_rawBind]; rfl

  theorem Ty.rawInstRTys_rawBind (rs : List Scope.Domain.Range) (θ : SubstEnv) (as : List Ty) :
      Ty.rawInstRTys rs (Ty.rawBindTys θ as) = Ty.rawBindTys (θ.rawInstR rs) (Ty.rawInstRTys rs as) := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.rawBindTys, Ty.rawInstRTys, Ty.rawInstR_rawBind, Ty.rawInstRTys_rawBind]

  theorem Eff.rawInstR_rawBind (rs : List Scope.Domain.Range) (θ : SubstEnv) (e : Eff) :
      Eff.rawInstR rs (Eff.rawBind θ e) = Eff.rawBind (θ.rawInstR rs) (Eff.rawInstR rs e) := by
    cases e with
    | mk a fs =>
      simp only [Eff.rawBind, Eff.rawInstR]
      congr 1
      · exact Eff.instAtoms_substAtoms rs θ.rows a
      · rw [Ty.rawInstRTys_eq_map, List.map_append, ← Ty.rawInstRTys_eq_map, ← Ty.rawInstRTys_eq_map,
          Ty.rawInstRTys_rawBind]
        exact congrArg _ (Eff.rowFails_rawInstR rs θ.rows a).symm
end

/-- 公開する代入と具体化の交換。代入の像は具体化して正規化する。 -/
theorem Ty.instR_bind (rs : List Scope.Domain.Range) (θ : SubstEnv) (t : Ty) :
    (Ty.bind θ t).instR rs = Ty.bind (θ.rawInstR rs).norm (t.instR rs) := by
  unfold Ty.bind Ty.instR
  rw [Ty.norm_rawInstR, Ty.rawInstR_rawBind, Ty.norm_rawBind_normEnv, Ty.norm_rawBind]

theorem Eff.norm_rawInstR_bind (rs : List Scope.Domain.Range) (θ : SubstEnv) (e : Eff) :
    Eff.norm (Eff.rawInstR rs (Eff.bind θ e)) = Eff.bind (θ.rawInstR rs).norm (Eff.rawInstR rs e) := by
  unfold Eff.bind
  rw [Eff.norm_rawInstR, Eff.rawInstR_rawBind, Eff.norm_rawBind_normEnv]

/-- 有限列の代入の像の具体化は、像の列を具体化した代入である。 -/
theorem SubstEnv.at_rawInstR (rs : List Scope.Domain.Range) (c : Nat) (ts : List Ty) (es : List Eff) :
    (SubstEnv.at c ts es).rawInstR rs = SubstEnv.at c (Ty.rawInstRTys rs ts) (es.map (Eff.rawInstR rs)) := by
  unfold SubstEnv.at SubstEnv.rawInstR
  simp only [Ty.rawInstRTys_eq_map, List.length_map, List.map_map]
  congr 1
  · funext i
    by_cases hi : i < c
    · simp only [hi, ↓reduceIte, Ty.rawInstR]
    · simp only [hi, ↓reduceIte]
      by_cases hj : i - c < ts.length
      · simp only [hj, ↓reduceIte, List.getElem?_map, List.getElem?_eq_getElem hj, Option.map_some,
          Option.getD_some, Ty.rawInstR_rawShift]
      · simp only [hj, ↓reduceIte, Ty.rawInstR]
  · apply List.map_congr_left
    intro e _
    exact Eff.rawInstR_rawShift rs c 0 e

/-- 具体化と型代入・行代入の交換（RV-PL10 中5）。代入の型の像と行の像も具体化する。 -/
theorem Ty.instR_substAt (rs : List Scope.Domain.Range) (c : Nat) (ts : List Ty) (es : List Eff) (t : Ty) :
    (t.substAt c ts es).instR rs =
      (t.instR rs).substAt c (ts.map (Ty.instR rs)) (es.map fun e => Eff.norm (Eff.rawInstR rs e)) := by
  rw [Ty.substAt_eq_bind, Ty.instR_bind, SubstEnv.at_rawInstR, ← SubstEnv.at_norm, Ty.substAt_eq_bind]
  simp only [Ty.rawInstRTys_eq_map, List.map_map, Function.comp_def]
  rfl

/-- 効果の代入とも交換する（最上位の Fail の列は正規化して比べる）。 -/
theorem Eff.norm_rawInstR_substAt (rs : List Scope.Domain.Range) (c : Nat) (ts : List Ty) (es : List Eff)
    (e : Eff) :
    Eff.norm (Eff.rawInstR rs (Eff.substAt c ts es e)) =
      Eff.substAt c (ts.map (Ty.instR rs)) (es.map fun e => Eff.norm (Eff.rawInstR rs e)) (Eff.rawInstR rs e) := by
  have h := Eff.norm_rawInstR_bind rs (SubstEnv.at c ts es) e
  simp only [Eff.bind] at h
  rw [Eff.substAt, Eff.rawSubstAt, h, SubstEnv.at_rawInstR, ← SubstEnv.at_norm]
  simp only [Eff.substAt, Eff.rawSubstAt, Ty.rawInstRTys_eq_map, List.map_map, Function.comp_def]
  rfl

/-- 型の像を正規化しても、像が正規形なら代入は同じである。 -/
theorem Ty.substAt_rows_norm {c : Nat} {ts : List Ty} (hts : ∀ u ∈ ts, u.Canonical) (es : List Eff) (t : Ty) :
    t.substAt c ts (es.map Eff.norm) = t.substAt c ts es := by
  have hts' : ts.map Ty.norm = ts := by
    conv => rhs; rw [← List.map_id ts]
    exact List.map_congr_left hts
  rw [← hts', Ty.substAt_eq_bind, SubstEnv.at_norm, Ty.substAt_eq_bind]
  unfold Ty.bind
  rw [Ty.norm_rawBind_normEnv, hts']

/-- 範囲の変数のない正規形の型の像と範囲の変数のない行の像（プログラムの型と効果）では、具体化と代入は像を
変えずに交換する。 -/
theorem Ty.instR_substAt_of_rangeFree (rs : List Scope.Domain.Range) {c : Nat} {ts : List Ty} {es : List Eff}
    (hts : ∀ u ∈ ts, Ty.RangesIn 0 u ∧ u.Canonical) (hes : ∀ e ∈ es, Eff.RangesIn 0 e) (t : Ty) :
    (t.substAt c ts es).instR rs = (t.instR rs).substAt c ts es := by
  rw [Ty.instR_substAt]
  have h1 : ts.map (Ty.instR rs) = ts := by
    conv => rhs; rw [← List.map_id ts]
    exact List.map_congr_left (fun u hu => Ty.instR_of_rangesIn (hts u hu).1 (hts u hu).2 rs)
  have h2 : (es.map fun e => Eff.norm (Eff.rawInstR rs e)) = es.map Eff.norm :=
    List.map_congr_left (fun e he => by rw [Eff.rawInstR_of_rangesIn rs e (hes e he)])
  rw [h1, h2, Ty.substAt_rows_norm (fun u hu => (hts u hu).2)]

/-! ## 引数の具体化と代入 -/

/-- 最上位が範囲の変数を持つ不透明型でない。 -/
def Ty.TopRangeFree (t : Ty) : Prop := ∀ o j, t ≠ .opaque o (.rvar j)

theorem Ty.instTarget_of_topRangeFree {t : Ty} (h : t.TopRangeFree) (rs : List Scope.Domain.Range) :
    t.instTarget rs = t := by
  cases t with
  | «opaque» o ix =>
    cases ix with
    | fixed r => rfl
    | rvar j => exact absurd rfl (h o j)
  | _ => rfl

/-- 範囲の変数のない型の最上位は、範囲の変数を持たない。 -/
theorem Ty.TopRangeFree.of_opaqueRangesIn {t : Ty} (h : Ty.OpaqueRangesIn 0 t) : t.TopRangeFree := by
  intro o j he
  subst he
  exact Nat.not_lt_zero j h

theorem Ty.TopRangeFree.shift {t : Ty} (h : t.TopRangeFree) (k c : Nat) : (t.shift k c).TopRangeFree := by
  intro o j he
  cases t with
  | «opaque» o' ix =>
    simp only [Ty.shift, Ty.opaque.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    exact h _ _ rfl
  | tvar i => by_cases hi : i < c <;> simp [Ty.shift, hi] at he
  | _ => simp [Ty.shift] at he

theorem Ty.TopRangeFree.applyTo {t : Ty} (h : t.TopRangeFree) (as : List Ty) : (t.applyTo as).TopRangeFree := by
  intro o j he
  cases t with
  | ctor c => cases c <;> simp [Ty.applyTo, TyCon.apply, TyCon.rawApply] at he
  | tvar i => simp [Ty.applyTo] at he
  | «opaque» o' ix =>
    simp only [Ty.applyTo, Ty.norm, Ty.opaque.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    exact h _ _ rfl
  | _ => simp [Ty.applyTo, Ty.norm] at he

/-- 引数の具体化と型代入・行代入の交換。代入の型の像の最上位が範囲の変数を持たないとき（プログラムの型の引数）、
具体化と代入は像を変えずに交換する。 -/
theorem Ty.instTarget_substAt (rs : List Scope.Domain.Range) {c : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ u ∈ ts, u.TopRangeFree) (t : Ty) :
    (t.substAt c ts es).instTarget rs = (t.instTarget rs).substAt c ts es := by
  have himg : ∀ i, ¬ i < c → i - c < ts.length → ((ts[i - c]?).getD (.tvar i)).TopRangeFree := by
    intro i _ hj
    rw [List.getElem?_eq_getElem hj, Option.getD_some]
    exact hts _ (List.getElem_mem hj)
  cases t with
  | «opaque» o ix => rfl
  | tvar i =>
    simp only [Ty.instTarget, Ty.substAt]
    by_cases hi : i < c
    · simp [hi]
    · simp only [hi, ↓reduceIte]
      by_cases hj : i - c < ts.length
      · simp only [hj, ↓reduceIte]
        exact Ty.instTarget_of_topRangeFree ((himg i hi hj).shift c 0) rs
      · simp [hj]
  | tapp i args =>
    simp only [Ty.instTarget, Ty.substAt]
    by_cases hi : i < c
    · simp [hi]
    · simp only [hi, ↓reduceIte]
      by_cases hj : i - c < ts.length
      · simp only [hj, ↓reduceIte]
        exact Ty.instTarget_of_topRangeFree (((himg i hi hj).shift c 0).applyTo _) rs
      · simp [hj]
  | _ => simp [Ty.instTarget, Ty.substAt]


/-! ## 個数の合う閉じた列での整形式性 -/

mutual
  /-- 範囲の変数の番号が `nr` より小さい生の型は、`nr` 個以上の閉じた範囲で具体化すると範囲の変数を持たない。 -/
  theorem Ty.rawInstR_rawWF {nr n : Nat} {rs : List Scope.Domain.Range} (hn : nr ≤ rs.length) (t : Ty)
      (h : t.RawWF nr n) : (t.rawInstR rs).RawWF 0 n := by
    cases t <;> simp only [Ty.RawWF] at h <;> simp only [Ty.rawInstR, Ty.RawWF]
    all_goals first
      | trivial
      | exact h
      | exact Ty.rawInstR_rawWF hn _ h
      | exact Ty.rawInstRTys_rawWF hn _ h
      | skip
    case «opaque» o ix => exact Scope.Signature.Ix.inst_wf_zero h hn
    case fn ns ps r e =>
      exact ⟨by simpa only [NamesWF, Ty.rawInstRTys_eq_map, List.length_map] using h.1,
        Ty.rawInstRTys_rawWF hn ps h.2.1, Ty.rawInstR_rawWF hn r h.2.2.1, Eff.rawInstR_rawWF hn e h.2.2.2⟩
    case cont b t e =>
      exact ⟨Ty.rawInstR_rawWF hn b h.1, Ty.rawInstR_rawWF hn t h.2.1, Eff.rawInstR_rawWF hn e h.2.2⟩
    case map a b => exact ⟨Ty.rawInstR_rawWF hn a h.1, Ty.rawInstR_rawWF hn b h.2⟩
    case tapp i as => exact ⟨h.1, Ty.rawInstRTys_rawWF hn as h.2⟩

  theorem Ty.rawInstRTys_rawWF {nr n : Nat} {rs : List Scope.Domain.Range} (hn : nr ≤ rs.length) (as : List Ty)
      (h : Ty.RawWFList nr n as) : Ty.RawWFList 0 n (Ty.rawInstRTys rs as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.rawInstR_rawWF hn a h.1, Ty.rawInstRTys_rawWF hn as h.2⟩

  theorem Eff.rawInstR_rawWF {nr n : Nat} {rs : List Scope.Domain.Range} (hn : nr ≤ rs.length) (e : Eff)
      (h : Eff.RawWF nr n e) : Eff.RawWF 0 n (Eff.rawInstR rs e) := by
    cases e with
    | mk a fs => exact Ty.rawInstRTys_rawWF hn fs h
end

/-- `Ix.inst_wf_zero` の型への持ち上げ。範囲の変数の文脈 `nr` で整形式の型を `nr` 個以上の閉じた範囲で具体化
すると、範囲の変数の文脈 0 で整形式である。 -/
theorem Ty.instR_wf_zero {nr n : Nat} {rs : List Scope.Domain.Range} (hn : nr ≤ rs.length) {t : Ty}
    (h : Ty.WF nr n t) : Ty.WF 0 n (t.instR rs) :=
  Ty.norm_rawWF _ (Ty.rawInstR_rawWF hn t (Ty.WF.raw t h))

/-- 計算の最上位の効果でも同じである。 -/
theorem Eff.instR_wf_zero {nr n : Nat} {rs : List Scope.Domain.Range} (hn : nr ≤ rs.length) {e : Eff}
    (h : Eff.WF nr n e) : Eff.WF 0 n (Eff.instR rs e) := by
  cases e with
  | mk a fs =>
    simp only [Eff.instR, Eff.WF]
    apply Ty.WFList.iff.mpr
    intro t ht
    obtain ⟨u, hu, rfl⟩ := List.mem_map.mp ht
    exact Ty.instR_wf_zero hn (Ty.WFList.iff.mp h u hu)

/-- 引数の最上位の対象の位置の具体化。不透明型の範囲の位置だけを具体化する。 -/
theorem Ty.instTarget_wf_zero {nr n : Nat} {rs : List Scope.Domain.Range} (hn : nr ≤ rs.length) {t : Ty}
    (h : Ty.WF nr n t) (hin : (∃ o ix, t = .opaque o ix) ∨ Ty.OpaqueRangesIn 0 t) :
    Ty.WF 0 n (t.instTarget rs) := by
  rcases hin with ⟨o, ix, rfl⟩ | hin
  · exact Scope.Signature.Ix.inst_wf_zero h hn
  · rw [Ty.instTarget_of_topRangeFree (Ty.TopRangeFree.of_opaqueRangesIn hin)]
    exact (Ty.wf_iff_old 0 n t).mpr ⟨((Ty.wf_iff_old nr n t).mp h).1, hin⟩

/-! ## 個数の合う閉じた列での変数の範囲（`Ty.VarsIn` の持ち上げ） -/

mutual
  /-- `Ty.VarsIn` から関数の型の効果の正規形の条件を除いたもの。生の具体化は正規形を保たないので、正規化の前の
  型の変数・行の変数・範囲の変数の範囲をこの形で追う。 -/
  def Ty.RawVarsIn (nr n : Nat) (pe : Nat → Prop) : Ty → Prop
    | .base _ | .bytes | .ctor _ => True
    | .opaque _ ix => ix.WF nr
    | .data _ args => Ty.RawVarsInList nr n pe args
    | .list a | .reference a | .lazy a | .set a | .dict _ a => Ty.RawVarsIn nr n pe a
    | .fn names params ret eff =>
        NamesWF names params ∧ Ty.RawVarsInList nr n pe params ∧ Ty.RawVarsIn nr n pe ret ∧ Eff.RawVarsIn nr n pe eff
    | .tvar i => i < n
    | .cont _ _ _ => False
    | .map a b => Ty.RawVarsIn nr n pe a ∧ Ty.RawVarsIn nr n pe b
    | .tapp i args => i < n ∧ Ty.RawVarsInList nr n pe args

  def Ty.RawVarsInList (nr n : Nat) (pe : Nat → Prop) : List Ty → Prop
    | [] => True
    | a :: as => Ty.RawVarsIn nr n pe a ∧ Ty.RawVarsInList nr n pe as

  def Eff.RawVarsIn (nr n : Nat) (pe : Nat → Prop) : Eff → Prop
    | .mk a fs => (∀ i, a (.rho i) = true → pe i) ∧ Ty.RawVarsInList nr n pe fs ∧ ∀ x, a x = true → x.WF nr
end

theorem Ty.RawVarsInList.iff {nr n : Nat} {pe : Nat → Prop} {as : List Ty} :
    Ty.RawVarsInList nr n pe as ↔ ∀ a ∈ as, a.RawVarsIn nr n pe := by
  induction as with
  | nil => simp [Ty.RawVarsInList]
  | cons a as ih => simp [Ty.RawVarsInList, ih]

mutual
  theorem Ty.VarsIn.raw {nr n : Nat} {pe : Nat → Prop} (t : Ty) (h : t.VarsIn nr n pe) : t.RawVarsIn nr n pe := by
    cases t <;> simp only [Ty.VarsIn] at h <;> simp only [Ty.RawVarsIn]
    all_goals first
      | trivial
      | exact h
      | exact Ty.VarsIn.raw _ h
      | exact Ty.VarsInList.raw _ h
      | skip
    case fn ns ps r e => exact ⟨h.1, Ty.VarsInList.raw ps h.2.1, Ty.VarsIn.raw r h.2.2.1, Eff.VarsIn.raw e h.2.2.2.1⟩
    case map a b => exact ⟨Ty.VarsIn.raw a h.1, Ty.VarsIn.raw b h.2⟩
    case tapp i as => exact ⟨h.1, Ty.VarsInList.raw as h.2⟩

  theorem Ty.VarsInList.raw {nr n : Nat} {pe : Nat → Prop} (as : List Ty) (h : Ty.VarsInList nr n pe as) :
      Ty.RawVarsInList nr n pe as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.VarsIn.raw a h.1, Ty.VarsInList.raw as h.2⟩

  theorem Eff.VarsIn.raw {nr n : Nat} {pe : Nat → Prop} (e : Eff) (h : Eff.VarsIn nr n pe e) :
      Eff.RawVarsIn nr n pe e := by
    cases e with
    | mk a fs => exact ⟨h.1, Ty.VarsInList.raw fs h.2.1, h.2.2⟩
end

mutual
  /-- 生の具体化は、範囲の変数の番号が `nr` より小さい型を、`nr` 個以上の閉じた範囲で範囲の変数のない型に移す。 -/
  theorem Ty.rawInstR_rawVarsIn {nr n : Nat} {pe : Nat → Prop} {rs : List Scope.Domain.Range} (hn : nr ≤ rs.length)
      (t : Ty) (h : t.RawVarsIn nr n pe) : (t.rawInstR rs).RawVarsIn 0 n pe := by
    cases t <;> simp only [Ty.RawVarsIn] at h <;> simp only [Ty.rawInstR, Ty.RawVarsIn]
    all_goals first
      | trivial
      | exact h
      | exact Ty.rawInstR_rawVarsIn hn _ h
      | exact Ty.rawInstRTys_rawVarsIn hn _ h
      | skip
    case «opaque» o ix => exact Scope.Signature.Ix.inst_wf_zero h hn
    case fn ns ps r e =>
      exact ⟨by simpa only [NamesWF, Ty.rawInstRTys_eq_map, List.length_map] using h.1,
        Ty.rawInstRTys_rawVarsIn hn ps h.2.1, Ty.rawInstR_rawVarsIn hn r h.2.2.1, Eff.rawInstR_rawVarsIn hn e h.2.2.2⟩
    case map a b => exact ⟨Ty.rawInstR_rawVarsIn hn a h.1, Ty.rawInstR_rawVarsIn hn b h.2⟩
    case tapp i as => exact ⟨h.1, Ty.rawInstRTys_rawVarsIn hn as h.2⟩

  theorem Ty.rawInstRTys_rawVarsIn {nr n : Nat} {pe : Nat → Prop} {rs : List Scope.Domain.Range} (hn : nr ≤ rs.length)
      (as : List Ty) (h : Ty.RawVarsInList nr n pe as) : Ty.RawVarsInList 0 n pe (Ty.rawInstRTys rs as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.rawInstR_rawVarsIn hn a h.1, Ty.rawInstRTys_rawVarsIn hn as h.2⟩

  theorem Eff.rawInstR_rawVarsIn {nr n : Nat} {pe : Nat → Prop} {rs : List Scope.Domain.Range} (hn : nr ≤ rs.length)
      (e : Eff) (h : Eff.RawVarsIn nr n pe e) : Eff.RawVarsIn 0 n pe (Eff.rawInstR rs e) := by
    cases e with
    | mk a fs =>
      refine ⟨fun i hi => h.1 i (by simpa using hi), Ty.rawInstRTys_rawVarsIn hn fs h.2.1, ?_⟩
      intro x hx
      obtain ⟨y, hy, rfl⟩ := (Eff.instAtoms_spec rs a x).mp hx
      exact Atom.instR_wf_zero (h.2.2 y hy) hn
end

mutual
  /-- 正規化は、生の変数の範囲を `Ty.VarsIn` へ移す（関数の型の効果は正規形になる）。 -/
  theorem Ty.norm_rawVarsIn {nr n : Nat} {pe : Nat → Prop} (t : Ty) (h : t.RawVarsIn nr n pe) :
      t.norm.VarsIn nr n pe := by
    cases t <;> simp only [Ty.RawVarsIn] at h <;> simp only [Ty.norm, Ty.VarsIn]
    all_goals first
      | trivial
      | exact h
      | exact Ty.norm_rawVarsIn _ h
      | exact Ty.normTys_rawVarsIn _ h
      | skip
    case fn ns ps r e =>
      exact ⟨by simpa only [NamesWF, Ty.normTys_eq_map, List.length_map] using h.1,
        Ty.normTys_rawVarsIn ps h.2.1, Ty.norm_rawVarsIn r h.2.2.1, Eff.norm_rawVarsIn e h.2.2.2, Eff.norm_idem e⟩
    case map a b => exact ⟨Ty.norm_rawVarsIn a h.1, Ty.norm_rawVarsIn b h.2⟩
    case tapp i as => exact ⟨h.1, Ty.normTys_rawVarsIn as h.2⟩

  theorem Ty.normTys_rawVarsIn {nr n : Nat} {pe : Nat → Prop} (as : List Ty) (h : Ty.RawVarsInList nr n pe as) :
      Ty.VarsInList nr n pe (Ty.normTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.norm_rawVarsIn a h.1, Ty.normTys_rawVarsIn as h.2⟩

  theorem Eff.norm_rawVarsIn {nr n : Nat} {pe : Nat → Prop} (e : Eff) (h : Eff.RawVarsIn nr n pe e) :
      Eff.VarsIn nr n pe (Eff.norm e) := by
    cases e with
    | mk a fs =>
      refine ⟨h.1, Ty.VarsInList.iff.mpr ?_, h.2.2⟩
      intro t ht
      exact Ty.VarsInList.iff.mp (Ty.normTys_rawVarsIn fs h.2.1) t (Order.mem_sortUnique.mp ht)
end

/-- `Ty.VarsIn` の範囲の変数の文脈 `nr` を、`nr` 個以上の閉じた範囲の具体化で 0 にする。 -/
theorem Ty.instR_varsIn_zero {nr n : Nat} {pe : Nat → Prop} {rs : List Scope.Domain.Range} (hn : nr ≤ rs.length)
    {t : Ty} (h : t.VarsIn nr n pe) : (t.instR rs).VarsIn 0 n pe :=
  Ty.norm_rawVarsIn _ (Ty.rawInstR_rawVarsIn hn t (Ty.VarsIn.raw t h))

/-- 計算の最上位の効果でも同じである。 -/
theorem Eff.instR_varsIn_zero {nr n : Nat} {pe : Nat → Prop} {rs : List Scope.Domain.Range} (hn : nr ≤ rs.length)
    {e : Eff} (h : Eff.VarsIn nr n pe e) : Eff.VarsIn 0 n pe (Eff.instR rs e) := by
  cases e with
  | mk a fs =>
    refine ⟨fun i hi => h.1 i (by simpa using hi), Ty.VarsInList.iff.mpr ?_, ?_⟩
    · intro t ht
      obtain ⟨u, hu, rfl⟩ := List.mem_map.mp ht
      exact Ty.instR_varsIn_zero hn (Ty.VarsInList.iff.mp h.2.1 u hu)
    · intro x hx
      obtain ⟨y, hy, rfl⟩ := (Eff.instAtoms_spec rs a x).mp hx
      exact Atom.instR_wf_zero (h.2.2 y hy) hn

/-- 列の全ての要素を変えない写像は、列を変えない。 -/
private theorem map_eq_self {α : Type} {f : α → α} : {l : List α} → (∀ x ∈ l, f x = x) → l.map f = l
  | [], _ => rfl
  | x :: xs, h => by
    simp only [List.map_cons, h x List.mem_cons_self,
      map_eq_self (fun y hy => h y (List.mem_cons_of_mem x hy))]

theorem Ty.RangesInList.iff {nr : Nat} {as : List Ty} : Ty.RangesInList nr as ↔ ∀ a ∈ as, Ty.RangesIn nr a := by
  induction as with
  | nil => simp [Ty.RangesInList]
  | cons a as ih => simp [Ty.RangesInList, ih]

/-! ## 署名の具体化の性質 -/

/-- 範囲の変数の番号の上限で読む `PrimSig.ScopedRanges` は、旧の定義と、範囲の位置が署名の範囲の変数の個数の
文脈を満たすことの組である。 -/
theorem PrimSig.scopedRanges_iff_old (s : PrimSig) : s.ScopedRanges ↔ s.ScopedOld ∧ s.RangesIn s.nranges := by
  unfold PrimSig.ScopedRanges PrimSig.ScopedOld PrimSig.RangesIn
  rw [Ty.varsInList_iff_old, Ty.varsIn_iff_old, Eff.varsIn_iff_old]
  constructor
  · rintro ⟨h1, ⟨h2, h2'⟩, ⟨h3, h3'⟩, ⟨h4, h4'⟩⟩; exact ⟨⟨h1, h2, h3, h4⟩, h2', h3', h4'⟩
  · rintro ⟨⟨h1, h2, h3, h4⟩, h2', h3', h4'⟩; exact ⟨h1, ⟨h2, h2'⟩, ⟨h3, h3'⟩, ⟨h4, h4'⟩⟩

/-- 範囲の変数のない項目（`nranges = 0`。旧の項目は `rkinds` が既定の空の列）では、範囲の変数の番号の上限で
読む `PrimSig.ScopedRanges` は `PrimSig.Scoped` と同じである。 -/
theorem PrimSig.scoped_iff_scopedRanges {s : PrimSig} (h : s.nranges = 0) : s.Scoped ↔ s.ScopedRanges := by
  constructor
  · intro hs; exact ⟨hs.1, hs.2.1, hs.2.2.1, hs.2.2.2.1⟩
  · rintro ⟨h1, h2, h3, h4⟩
    rw [h] at h2 h3 h4
    exact ⟨h1, by rw [h]; exact h2, by rw [h]; exact h3, by rw [h]; exact h4,
      fun p hp => Or.inr (Ty.VarsInList.iff.mp h2 p hp), fun _ _ => h3⟩

/-- 範囲の変数 0 の表（旧の項目だけの表を含む）では、範囲の変数の番号の上限で読む `sig_scoped` の内容は、
今の `sig_scoped`（文脈 0）と同値である（問 18 の行 4）。 -/
theorem sig_scopedRanges_iff (B : Builtins) (hB : ∀ b s, B.sig b = some s → s.nranges = 0) :
    (∀ b s, B.sig b = some s → s.ScopedRanges) ↔ (∀ b s, B.sig b = some s → s.Scoped) := by
  constructor
  · intro h b s hs; exact (PrimSig.scoped_iff_scopedRanges (hB b s hs)).mpr (h b s hs)
  · intro h b s hs; exact (PrimSig.scoped_iff_scopedRanges (hB b s hs)).mp (h b s hs)

/-- 同じ表では、範囲の変数の番号の上限で読む欄は、L20.2 の前の旧の欄とも同値である。 -/
theorem sig_scopedRanges_iff_old (B : Builtins)
    (hB : ∀ b s, B.sig b = some s → s.nranges = 0 ∧ s.RangesIn 0) :
    (∀ b s, B.sig b = some s → s.ScopedRanges) ↔ (∀ b s, B.sig b = some s → s.ScopedOld) := by
  rw [sig_scopedRanges_iff B (fun b s hs => (hB b s hs).1)]
  exact sig_scoped_iff_old_of_rangeFree B hB

/-- 範囲の変数の番号の上限は、範囲の変数を持つ項目でだけ効く。番号が個数以上の範囲の変数を置いた項目は拒否される
（既定の空の `rkinds` のまま `rvar` を書いた項目を含む。RV-PL10 軽3）。 -/
theorem PrimSig.not_scopedRanges_of_ret {s : PrimSig} {o : OpaqueName} {i : Nat} (hr : s.ret = .opaque o (.rvar i))
    (hi : s.nranges ≤ i) : ¬ s.ScopedRanges := by
  intro h
  have := ((Ty.varsIn_iff_old _ _ _ _).mp h.2.2.1).2
  rw [hr] at this
  exact Nat.lt_irrefl _ (Nat.lt_of_lt_of_le this hi)

/-- 署名の結果と効果の正規形の条件の下で、空の具体化は署名を変えない。 -/
theorem PrimSig.inst_nil_of_canonical {s : PrimSig} (hr : s.ret.Canonical) (he : ∀ t ∈ s.eff.fails, t.Canonical) :
    s.inst [] = s := by
  have hp : s.params.map (Ty.instTarget []) = s.params := map_eq_self (fun p _ => Ty.instTarget_nil p)
  have hret : s.ret.instR [] = s.ret := by rw [Ty.instR_nil]; exact hr
  have heff : Eff.instR [] s.eff = s.eff := by
    cases h : s.eff with
    | mk a fs =>
      rw [h] at he
      simp only [Eff.instR, Eff.instAtoms_nil]
      exact congrArg _ (map_eq_self (fun t ht => by rw [Ty.instR_nil]; exact he t ht))
  cases s
  simp only [PrimSig.inst] at hp hret heff ⊢
  rw [hp, hret, heff]

/-- 範囲の変数の番号の上限を満たす署名では、空の具体化は署名を変えない（RV-PL10 中5）。 -/
theorem PrimSig.inst_nil {s : PrimSig} (hs : s.ScopedRanges) : s.inst [] = s := by
  apply PrimSig.inst_nil_of_canonical
  · exact Ty.WF.canonical _ (Ty.VarsIn.wf _ hs.2.2.1)
  · intro t ht
    have hw := Eff.VarsIn.wf _ hs.2.2.2
    cases h : s.eff with
    | mk a fs =>
      rw [h] at hw ht
      exact Ty.WF.canonical _ (Ty.WFList.iff.mp hw t ht)

/-- 範囲の変数のない項目（`nranges = 0` の `PrimSig.Scoped`）では、空の具体化は署名を変えない。 -/
theorem PrimSig.inst_nil_of_scoped {s : PrimSig} (hs : s.Scoped) (h0 : s.nranges = 0) : s.inst [] = s :=
  PrimSig.inst_nil ((PrimSig.scoped_iff_scopedRanges h0).mp hs)

/-- 範囲の変数を持たない署名（`nranges = 0` の `PrimSig.Scoped`）は、どの具体化でも変わらない（旧の項目の具体化）。
前提 `nranges = 0` は L20.5 で加えた（`PrimSig.Scoped` が範囲の変数を `s.nranges` の文脈で読むため）。 -/
theorem PrimSig.inst_of_scoped {s : PrimSig} (hs : s.Scoped) (h0 : s.nranges = 0) (rs : List Scope.Domain.Range) :
    s.inst rs = s := by
  have hr0 : s.RangesIn 0 := ((PrimSig.scoped_iff_old s h0).mp hs).2
  have hp : s.params.map (Ty.instTarget rs) = s.params := map_eq_self (fun p hp =>
    Ty.instTarget_of_topRangeFree (Ty.TopRangeFree.of_opaqueRangesIn
      (Ty.RangesIn.opaque p (Ty.RangesInList.iff.mp hr0.1 p hp))) rs)
  have hret : s.ret.instR rs = s.ret :=
    Ty.instR_of_rangesIn hr0.2.1 (Ty.WF.canonical _ (Ty.VarsIn.wf _ hs.2.2.1)) rs
  have heff : Eff.instR rs s.eff = s.eff := by
    have hw := Eff.VarsIn.wf _ hs.2.2.2.1
    have hre := hr0.2.2
    cases h : s.eff with
    | mk a fs =>
      rw [h] at hw hre
      simp only [Eff.instR, Eff.instAtoms_of_wf_zero hre.1]
      exact congrArg _ (map_eq_self (fun t ht => Ty.instR_of_rangesIn (Ty.RangesInList.iff.mp hre.2 t ht)
        (Ty.WF.canonical _ (Ty.WFList.iff.mp hw t ht)) rs))
  cases s
  simp only [PrimSig.inst] at hp hret heff ⊢
  rw [hp, hret, heff]

theorem PrimSig.inst_params_getElem? (rs : List Scope.Domain.Range) (s : PrimSig) (i : Nat) :
    (s.inst rs).params[i]? = (s.params[i]?).map (Ty.instTarget rs) := by
  simp

/-- 具体化は、最上位の対象の位置でない引数の型を変えない。従って二つの具体化（`inst rs` と `inst [Top, …]`）の
引数の型は、最上位の対象の位置だけで違う（plan-l10-l50 の注「具体化の条件の置き場所」、RV-PL10 重大1）。 -/
theorem PrimSig.inst_params_agree_off_target {s : PrimSig} (rs rs' : List Scope.Domain.Range) {i : Nat} {p : Ty}
    (hp : s.params[i]? = some p) (hoff : ∀ o j, p ≠ .opaque o (.rvar j)) :
    (s.inst rs).params[i]? = some p ∧ (s.inst rs').params[i]? = some p := by
  simp [hp, Ty.instTarget_of_topRangeFree hoff]

/-- 最上位の対象の位置の引数は、範囲の位置だけを具体化する。 -/
theorem PrimSig.inst_params_target (rs : List Scope.Domain.Range) {s : PrimSig} {i : Nat} {o : OpaqueName}
    {ix : Scope.Signature.Ix} (hp : s.params[i]? = some (.opaque o ix)) :
    (s.inst rs).params[i]? = some (.opaque o (ix.inst rs)) := by
  simp [hp, Ty.instTarget]

/-- 引数の範囲の変数が最上位の対象の位置だけにある。具体化の後の引数の型が範囲の変数を持たないための条件である。
`PrimSig.Scoped` はこの条件を `Ty.VarsIn 0` の形で含む（`PrimSig.Scoped.targetRangesOnly`。L20.3 の後の推す案、停止の
表の例外）。`PrimSig.ScopedRanges` には含めない。 -/
def PrimSig.TargetRangesOnly (s : PrimSig) : Prop :=
  ∀ p ∈ s.params, (∃ o ix, p = .opaque o ix) ∨ Ty.RangesIn 0 p

/-- 結果と効果は、範囲の変数の個数以上の閉じた列で具体化すれば、範囲の変数の文脈 0 で整形式である。 -/
theorem PrimSig.inst_ret_eff_wf_zero {s : PrimSig} (hs : s.ScopedRanges) {rs : List Scope.Domain.Range}
    (hn : s.nranges ≤ rs.length) :
    Ty.WF 0 s.ntys (s.inst rs).ret ∧ Eff.WF 0 s.ntys (s.inst rs).eff :=
  ⟨Ty.instR_wf_zero hn (Ty.VarsIn.wf _ hs.2.2.1), Eff.instR_wf_zero hn (Eff.VarsIn.wf _ hs.2.2.2)⟩

/-- 個数の合う閉じた列で具体化した署名は、範囲の変数の文脈 0 で整形式である（`Ix.inst_wf_zero` の型への持ち上げ。
RV-PL10 中5）。引数の型については、範囲の変数が最上位の対象の位置だけにあること（`TargetRangesOnly`）を要する。 -/
theorem PrimSig.inst_wf_zero {s : PrimSig} (hs : s.ScopedRanges) (ht : s.TargetRangesOnly)
    {rs : List Scope.Domain.Range} (hn : s.nranges ≤ rs.length) :
    Ty.WFList 0 s.ntys (s.inst rs).params ∧ Ty.WF 0 s.ntys (s.inst rs).ret ∧ Eff.WF 0 s.ntys (s.inst rs).eff := by
  refine ⟨?_, PrimSig.inst_ret_eff_wf_zero hs hn⟩
  apply Ty.WFList.iff.mpr
  intro t htm
  rw [PrimSig.inst_params] at htm
  obtain ⟨p, hp, rfl⟩ := List.mem_map.mp htm
  have hw := Ty.WFList.iff.mp (Ty.VarsInList.wf _ hs.2.1) p hp
  rcases ht p hp with hop | hin
  · exact Ty.instTarget_wf_zero hn hw (Or.inl hop)
  · exact Ty.instTarget_wf_zero hn hw (Or.inr (Ty.RangesIn.opaque p hin))

/-- `PrimSig.Scoped`（`sig_scoped`・`hsig` が読む形）は、範囲の変数の番号の上限で読む `ScopedRanges` を含む。 -/
theorem PrimSig.Scoped.scopedRanges {s : PrimSig} (hs : s.Scoped) : s.ScopedRanges :=
  ⟨hs.1, hs.2.1, hs.2.2.1, hs.2.2.2.1⟩

/-- `PrimSig.Scoped` は、引数の範囲の変数が最上位の対象の位置だけにあること（`TargetRangesOnly`）を含む。 -/
theorem PrimSig.Scoped.targetRangesOnly {s : PrimSig} (hs : s.Scoped) : s.TargetRangesOnly := fun p hp =>
  (hs.2.2.2.2.1 p hp).imp id (fun h => ((Ty.varsIn_iff_old _ _ _ p).mp h).2)

/-- `PrimSig.Scoped` の分解。範囲の変数の番号の上限で読む `ScopedRanges`、引数の位置の条件 `TargetRangesOnly`、
組み込みの操作の結果の型の条件の三つの連言と同値である。`Scoped` の引数の位置の条件は `Ty.VarsIn 0` の形で書いて
あるが、`ScopedRanges` の範囲の変数の上限と合わせると `TargetRangesOnly`（`Ty.RangesIn 0`）と同じ内容になる。 -/
theorem PrimSig.scoped_iff (s : PrimSig) :
    s.Scoped ↔ s.ScopedRanges ∧ s.TargetRangesOnly ∧
      ∀ l, s.opEff = some l → Ty.VarsIn 0 s.ntys (· < s.neffs) s.ret := by
  constructor
  · intro hs
    exact ⟨hs.scopedRanges, hs.targetRangesOnly, hs.2.2.2.2.2⟩
  · rintro ⟨⟨h1, h2, h3, h4⟩, ht, hr⟩
    refine ⟨h1, h2, h3, h4, fun p hp => (ht p hp).imp id (fun hin => ?_), hr⟩
    exact (Ty.varsIn_iff_old _ _ _ p).mpr
      ⟨((Ty.varsIn_iff_old _ _ _ p).mp (Ty.VarsInList.iff.mp h2 p hp)).1, hin⟩

/-- `sig_scoped` の項目を、範囲の変数の個数以上の閉じた列で具体化した署名は、範囲の変数の文脈 0 で整形式である。 -/
theorem PrimSig.Scoped.inst_wf_zero {s : PrimSig} (hs : s.Scoped) {rs : List Scope.Domain.Range}
    (hn : s.nranges ≤ rs.length) :
    Ty.WFList 0 s.ntys (s.inst rs).params ∧ Ty.WF 0 s.ntys (s.inst rs).ret ∧ Eff.WF 0 s.ntys (s.inst rs).eff :=
  PrimSig.inst_wf_zero hs.scopedRanges hs.targetRangesOnly hn

/-- 名前だけの（Top の）原子一つの効果は、どの具体化でも変わらない。 -/
@[simp] theorem Eff.instR_single (rs : List Scope.Domain.Range) (l : EffName) :
    Eff.instR rs (Eff.single l) = Eff.single l := by
  simp only [Eff.single, Eff.ofAtoms, Eff.instR, List.map_nil]
  rw [Eff.instAtoms_of_wf_zero]
  intro x hx
  simp only [beq_iff_eq] at hx
  subst hx
  trivial

/-- 範囲の変数のない項目（`nranges = 0`）の `PrimSig.Scoped` は、範囲の変数の文脈 0 で署名の型を読む（表層が呼べる
項目。表層に範囲を入れるまでの中間状態）。 -/
theorem PrimSig.Scoped.vars_zero {s : PrimSig} (hs : s.Scoped) (h0 : s.nranges = 0) :
    Ty.VarsInList 0 s.ntys (· < s.neffs) s.params ∧ Ty.VarsIn 0 s.ntys (· < s.neffs) s.ret ∧
      Eff.VarsIn 0 s.ntys (· < s.neffs) s.eff := by
  have h := hs
  unfold PrimSig.Scoped at h
  rw [h0] at h
  exact ⟨h.2.1, h.2.2.1, h.2.2.2.1⟩

/-- `PrimSig.Scoped` の項目を範囲の変数の個数以上の閉じた列で具体化した署名は、範囲の変数の文脈 0 で、宣言した
型パラメータとエフェクト変数だけを使う（`Ty.VarsIn` の形。型代入の補題 `fnTy_substAt` の前提）。 -/
theorem PrimSig.Scoped.inst_varsIn_zero {s : PrimSig} (hs : s.Scoped) {rs : List Scope.Domain.Range}
    (hn : s.nranges ≤ rs.length) :
    Ty.VarsInList 0 s.ntys (· < s.neffs) (s.inst rs).params ∧ Ty.VarsIn 0 s.ntys (· < s.neffs) (s.inst rs).ret ∧
      Eff.VarsIn 0 s.ntys (· < s.neffs) (s.inst rs).eff := by
  refine ⟨Ty.VarsInList.iff.mpr ?_, Ty.instR_varsIn_zero hn hs.2.2.1, Eff.instR_varsIn_zero hn hs.2.2.2.1⟩
  intro t ht
  rw [PrimSig.inst_params] at ht
  obtain ⟨p, hp, rfl⟩ := List.mem_map.mp ht
  rcases hs.2.2.2.2.1 p hp with ⟨o, ix, rfl⟩ | h0
  · have hw : ix.WF s.nranges := Ty.VarsInList.iff.mp hs.2.1 _ hp
    exact Scope.Signature.Ix.inst_wf_zero hw hn
  · cases p with
    | «opaque» o ix =>
      simp only [Ty.instTarget, Ty.VarsIn] at h0 ⊢
      rw [Scope.Signature.Ix.inst_of_wf_zero h0]; exact h0
    | _ => simpa [Ty.instTarget] using h0

/-- 組み込みの操作の項目の結果の型は範囲の変数を持たないので、どの具体化でも変わらない（`E_OpPrim` の保存）。 -/
theorem PrimSig.Scoped.inst_ret_of_opEff {s : PrimSig} (hs : s.Scoped) {l : EffName} (hl : s.opEff = some l)
    (rs : List Scope.Domain.Range) : (s.inst rs).ret = s.ret := by
  have h0 := hs.2.2.2.2.2 l hl
  rw [PrimSig.inst_ret]
  exact Ty.instR_of_rangesIn ((Ty.varsIn_iff_old _ _ _ _).mp h0).2 (Ty.WF.canonical _ (Ty.VarsIn.wf _ h0)) rs

/-! ## 範囲の具体化の許容 -/

namespace Builtins.RangeAdmissible

variable {B : Builtins} {b : PrimName} {s : PrimSig} {rs : List Scope.Domain.Range}

theorem length (h : B.RangeAdmissible b s rs) : rs.length = s.nranges := h.1.length

theorem wf (h : B.RangeAdmissible b s rs) : ∀ r ∈ rs, r.WF := h.1.wf

theorem canonical (h : B.RangeAdmissible b s rs) : ∀ r ∈ rs, r.Canonical := h.2

theorem fits {i : Nat} {r : Scope.Domain.Range} {k : Scope.Domain.Kind} (h : B.RangeAdmissible b s rs)
    (hr : rs[i]? = some r) (hk : s.rkinds[i]? = some k) : r.FitsKind k := h.1.fits hr hk

/-- 許容される列は、全て Top の列か、表の項目の制約を満たす列である。 -/
theorem top_or_admitsR (h : B.RangeAdmissible b s rs) : (∀ r ∈ rs, r = .top) ∨ B.admitsR b rs := h.1.admits_of

/-- 範囲の変数の個数を満たす列は、範囲の変数の個数以上の具体化である（`PrimSig.inst_wf_zero` の前提）。 -/
theorem nranges_le (h : B.RangeAdmissible b s rs) : s.nranges ≤ rs.length := by rw [h.length]; exact Nat.le_refl _

end Builtins.RangeAdmissible

/-- 範囲の変数の種類の列に Top を並べた列は、種類に置ける。 -/
theorem fitsKinds_replicate_top (ks : List Scope.Domain.Kind) :
    Scope.Domain.Range.FitsKinds (List.replicate ks.length .top) ks := by
  induction ks with
  | nil => exact Scope.Domain.Range.fitsKinds_nil
  | cons k ks ih => exact ⟨Scope.Domain.Range.top_fitsKind k, ih⟩

/-- 全て Top の列（範囲の変数の個数の長さ）は、表の項目の制約によらず常に許す（RV-PL10 中4）。 -/
theorem Builtins.rangeAdmissible_tops (B : Builtins) (b : PrimName) (s : PrimSig) :
    B.RangeAdmissible b s (List.replicate s.nranges .top) := by
  refine ⟨⟨fitsKinds_replicate_top s.rkinds, ?_, Or.inl ?_⟩, ?_⟩
  · intro r hr; rw [List.eq_of_mem_replicate hr]; trivial
  · intro r hr; exact List.eq_of_mem_replicate hr
  · intro r hr; rw [List.eq_of_mem_replicate hr]; trivial

/-- 範囲の変数のない項目の具体化の許容は、空の列だけである（旧の項目の具体化）。 -/
theorem Builtins.rangeAdmissible_iff_nil {B : Builtins} {b : PrimName} {s : PrimSig} (h0 : s.nranges = 0)
    (rs : List Scope.Domain.Range) : B.RangeAdmissible b s rs ↔ rs = [] := by
  constructor
  · intro h; exact List.eq_nil_of_length_eq_zero (h.length.trans h0)
  · rintro rfl
    have := B.rangeAdmissible_tops b s
    rwa [h0, List.replicate_zero] at this

/-! ## 検査済みの対象の値（L20.4 の葉の場合の補題） -/

@[simp] theorem Val.target?_checked (t : Scope.Domain.Target) : (Val.checked t).target? = some t := rfl

/-- 検査済みの対象の値は、型代入・行代入（型の変数の移動を含む）で変わらない。 -/
@[simp] theorem Val.substTyAt_checked (c : Nat) (ts : List Ty) (es : List Eff) (t : Scope.Domain.Target) :
    (Val.checked t).substTyAt c ts es = .checked t := rfl

@[simp] theorem Val.substTy_checked (ts : List Ty) (es : List Eff) (t : Scope.Domain.Target) :
    (Val.checked t).substTy ts es = .checked t := rfl

/-- 値の変数の改名（値の変数の移動を含む）で変わらない。 -/
@[simp] theorem Val.rename_checked (ξ : Nat → Nat) (t : Scope.Domain.Target) :
    (Val.checked t).rename ξ = .checked t := rfl

/-- 値の代入で変わらない。 -/
@[simp] theorem Val.subst_checked (σ : Nat → Val) (ρ : Nat → LocalRef) (t : Scope.Domain.Target) :
    (Val.checked t).subst σ ρ = .checked t := rfl

@[simp] theorem Val.instantiate_checked (ws : List Val) (t : Scope.Domain.Target) :
    (Val.checked t).instantiate ws = .checked t := rfl

/-- 型と値の変数を持たないので、どの文脈でも変数の範囲の条件を満たす。 -/
@[simp] theorem Val.varsIn_checked (n : Nat) (pe : Nat → Prop) (depth : Nat) (t : Scope.Domain.Target) :
    Val.VarsIn n pe (.checked t) depth := trivial

/-! ## 例 -/

/-- `File.writeTextIn` の形の署名（モデル）。引数の最上位の対象の位置と効果に範囲の変数 0 を置く。 -/
private def writeTextInSig : PrimSig where
  tparams := []
  neffs := 0
  names := ["path", "text"]
  params := [.opaque "Scope.PathIn" (.rvar 0), .base .string]
  ret := .base .unit
  eff := Eff.ofAtoms (· == .name "File.Write" (.rvar 0))
  admits := fun _ _ => True
  kind := .io
  opEff := none
  rkinds := [.path]

private def dataTree : Scope.Domain.Range := .path (.tree ["data"])

/-- 具体化は引数の対象の位置と効果の範囲の変数を、同じ範囲で置き換える。 -/
example : (writeTextInSig.inst [dataTree]).params = [.opaque "Scope.PathIn" (.fixed dataTree), .base .string] := rfl

example : Eff.mem (writeTextInSig.inst [dataTree]).eff (.name "File.Write" (.fixed dataTree)) := by
  simp only [PrimSig.inst_eff, writeTextInSig, Eff.ofAtoms, Eff.instR, Eff.mem, Eff.test, Eff.atoms]
  rw [Eff.instAtoms_spec]
  exact ⟨.name "File.Write" (.rvar 0), by decide, rfl⟩

/-- 長さの足りない具体化は範囲の変数を残し、黙って Top に狭めない。 -/
example : (writeTextInSig.inst []).params = writeTextInSig.params := rfl

/-- 範囲の変数一つの項目は、範囲の変数の番号の上限と引数の位置の条件を満たし、`PrimSig.Scoped` を満たす。 -/
example : writeTextInSig.ScopedRanges ∧ writeTextInSig.Scoped := by
  have hr : writeTextInSig.ScopedRanges := by
    refine (PrimSig.scopedRanges_iff_old _).mpr ⟨?_, ?_⟩
    · refine ⟨⟨rfl, by decide⟩, ?_, ?_, ?_⟩
      · simp [writeTextInSig, Ty.VarsInListOld, Ty.VarsInOld]
      · simp [writeTextInSig, Ty.VarsInOld]
      · refine ⟨fun i h => by simp at h, trivial⟩
    · refine ⟨?_, ?_, ?_⟩
      · simp [writeTextInSig, PrimSig.nranges, Ty.RangesInList, Ty.RangesIn, Scope.Signature.Ix.WF]
      · simp [writeTextInSig, Ty.RangesIn]
      · refine ⟨fun x hx => ?_, trivial⟩
        simp only [beq_iff_eq] at hx
        subst hx
        simp [PrimSig.nranges, writeTextInSig, Scope.Signature.Ix.WF]
  refine ⟨hr, hr.1, hr.2.1, hr.2.2.1, hr.2.2.2, ?_, ?_⟩
  · intro p hp
    simp only [writeTextInSig, List.mem_cons, List.not_mem_nil, or_false] at hp
    rcases hp with rfl | rfl
    · exact Or.inl ⟨_, _, rfl⟩
    · exact Or.inr trivial
  · intro l hl; simp [writeTextInSig] at hl

/-- 引数の関数型の内側に範囲の変数を置いた項目は、`PrimSig.Scoped`（引数の位置の条件）で拒否される。 -/
example : ¬ ({ writeTextInSig with params := [.fn ["p"] [.opaque "Scope.PathIn" (.rvar 0)] (.base .unit) Eff.empty] } :
    PrimSig).Scoped := by
  rintro ⟨-, -, -, -, h, -⟩
  rcases h _ (List.mem_singleton_self _) with ⟨o, ix, he⟩ | h
  · cases he
  · simp [Ty.VarsIn, Ty.VarsInList, Scope.Signature.Ix.WF] at h

/-- 表の制約が全てを許す表。 -/
private def anyAdmits : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none, ioResponse := fun _ _ _ _ _ _ => False,
    releaseResponse := fun _ _ => False, isResource := fun _ => false, effects := fun _ => none,
    sat := fun _ _ _ => True, refGet := "get", refSet := "set", admitsR := fun _ _ => True }

/-- 全て Top の列は許される。 -/
example : anyAdmits.RangeAdmissible "File.writeTextIn" writeTextInSig [.top] :=
  Builtins.rangeAdmissible_tops _ _ _

/-- 表の制約が全てを許しても、種類の違う範囲（エンドポイント）は許されない。 -/
example (e : Scope.Domain.EndpointPattern) :
    ¬ anyAdmits.RangeAdmissible "File.writeTextIn" writeTextInSig [.endpoint e] := by
  intro h
  have := h.fits (i := 0) rfl rfl
  simp [Scope.Domain.Range.FitsKind, Scope.Domain.Range.kind?] at this

/-- 表の制約が全てを許しても、正規形でない範囲（最大長の prefix の CIDR）は許されない。 -/
example (n : Fin (2 ^ Scope.Domain.Family.v4.width)) :
    ¬ anyAdmits.RangeAdmissible "Http.send" { writeTextInSig with rkinds := [.host] }
      [.host (.ip (.cidr ⟨.v4, n, 32⟩))] := by
  intro h
  have := h.canonical _ List.mem_cons_self
  simp [Scope.Domain.Range.Canonical, Scope.Domain.HostPattern.Canonical, Scope.Domain.IPPattern.Canonical,
    Scope.Domain.Family.width] at this

/-- 範囲の変数のない項目は、空の具体化だけを許す。 -/
example : ¬ anyAdmits.RangeAdmissible "File.writeTextIn" { writeTextInSig with rkinds := [] } [.top] := by
  rw [Builtins.rangeAdmissible_iff_nil rfl]; simp

/-! ## 範囲の変数のない項目の V-Prim -/

/-- 範囲の変数のない項目（`nranges = 0`）の呼び出しは、空の範囲の列で、表の署名そのもので型付く（旧の V-Prim の
形。脱糖と交換が空の範囲の列を書く中間状態と、旧の像の表で使う）。 -/
theorem HasTypeVQ.V_PrimNil {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : List TParam}
    {Γ : List (Option Ty)} {b : PrimName} {s : PrimSig} {ts : List Ty} {es : List Eff}
    (hs : B.sig b = some s) (hsc : s.Scoped) (h0 : s.nranges = 0)
    (hn : NamesWF s.names s.params) (ha : PrimitiveAdmissible C s Q ts es) :
    HasTypeVQ P B Ψ Q C Γ (.prim b ts es []) (fnTy s.names s.params s.ret s.eff ts es) := by
  have hinst := PrimSig.inst_nil_of_scoped hsc h0
  have h := HasTypeVQ.V_Prim (P := P) (Ψ := Ψ) (Γ := Γ) (rs := []) hs
    ((Builtins.rangeAdmissible_iff_nil h0 []).mpr rfl) (by rw [hinst]; exact hn) (by rw [hinst]; exact ha)
  rw [hinst] at h
  exact h

end Benitoite.Release
