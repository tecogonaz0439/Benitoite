import Benitoite.Surface.CheckTools
import Benitoite.Release.RangeInst

/-!
# 検査器の範囲の具体化（L40.4）

表層の検査器が、組み込みの名前 `primName b ts es rs` の範囲の列 `rs` を確かめ、具体化した署名 `s.inst rs` を
計算する道具を置く（設計書 01-12「型の情報を付けた表層の構文と型付け」）。`PrimSig.inst` は正規化 `Ty.norm` を使うので
計算できない。検査器は、候補の原子の集合 `atoms` の上の計算できる正規化 `Ty.normWith` で同じ型を計算する
（`instSig_eq`）。そのために、署名に現れる原子の具体化の像が候補の集合に入ること（`instClosed`）を確かめる。

範囲の具体化の許容 `Builtins.RangeAdmissible` の項目ごとの制約 `admitsR` は命題なので、検査器は表と合う判定
`admitsRDec` を入力に持つ（型引数の `admitsDec` と同じ扱い）。
-/

namespace Benitoite.Surface.CheckRanges

open Benitoite.Release
open Scope.Domain (Range)

/-! ## 支持の保存 -/

mutual
  /-- 原子の具体化の像が q を満たすなら、具体化した型の原子も q を満たす。 -/
  theorem Ty.support_rawInstR {p q : Atom → Prop} (rs : List Range) (hpq : ∀ y, p y → q (y.instR rs)) (t : Ty)
      (h : t.Support p) : (t.rawInstR rs).Support q := by
    cases t <;> simp only [Ty.Support, Ty.rawInstR] at h ⊢
    all_goals first
      | trivial
      | exact Ty.support_rawInstR rs hpq _ h
      | exact Ty.supportList_rawInstRTys rs hpq _ h
      | skip
    case fn ns ps r e =>
      exact ⟨Ty.supportList_rawInstRTys rs hpq ps h.1, Ty.support_rawInstR rs hpq r h.2.1,
        Eff.support_rawInstR rs hpq e h.2.2⟩
    case cont a b e =>
      exact ⟨Ty.support_rawInstR rs hpq a h.1, Ty.support_rawInstR rs hpq b h.2.1, Eff.support_rawInstR rs hpq e h.2.2⟩
    case map a b => exact ⟨Ty.support_rawInstR rs hpq a h.1, Ty.support_rawInstR rs hpq b h.2⟩

  theorem Ty.supportList_rawInstRTys {p q : Atom → Prop} (rs : List Range) (hpq : ∀ y, p y → q (y.instR rs))
      (as : List Ty) (h : Ty.SupportList p as) : Ty.SupportList q (Ty.rawInstRTys rs as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.support_rawInstR rs hpq a h.1, Ty.supportList_rawInstRTys rs hpq as h.2⟩

  theorem Eff.support_rawInstR {p q : Atom → Prop} (rs : List Range) (hpq : ∀ y, p y → q (y.instR rs)) (e : Eff)
      (h : e.Support p) : (Eff.rawInstR rs e).Support q := by
    cases e with
    | mk a fs =>
      simp only [Eff.Support, Eff.rawInstR] at h ⊢
      refine ⟨fun x hx => ?_, Ty.supportList_rawInstRTys rs hpq fs h.2⟩
      obtain ⟨y, hy, rfl⟩ := (Eff.instAtoms_spec rs a x).mp hx
      exact hpq y (h.1 y hy)
end

/-- 引数の型の具体化は不透明型の範囲の位置だけを変えるので、原子の支持を変えない。 -/
theorem Ty.support_instTarget {p : Atom → Prop} (rs : List Range) {t : Ty} (h : t.Support p) :
    (Ty.instTarget rs t).Support p := by
  cases t <;> simp_all [Ty.instTarget, Ty.Support]

theorem Tys.support_instTarget {p : Atom → Prop} (rs : List Range) {ts : List Ty} (h : Ty.SupportList p ts) :
    Ty.SupportList p (ts.map (Ty.instTarget rs)) :=
  Ty.SupportList.iff.mpr fun t ht => by
    obtain ⟨u, hu, rfl⟩ := List.mem_map.mp ht
    exact Ty.support_instTarget rs (Ty.SupportList.iff.mp h u hu)

/-! ## 計算できる具体化 -/

/-- 型の具体化 `Ty.instR` の計算できる版。 -/
def instTy (atoms : List Atom) (rs : List Range) (t : Ty) : Ty := (t.rawInstR rs).normWith atoms

/-- 計算の最上位の効果の具体化 `Eff.instR` の計算できる版。 -/
def instEff (atoms : List Atom) (rs : List Range) : Eff → Eff
  | .mk a fs => .mk (Eff.instAtoms rs a) (fs.map (instTy atoms rs))

/-- 署名の具体化 `PrimSig.inst` の計算できる版。 -/
def instSig (atoms : List Atom) (rs : List Range) (s : PrimSig) : PrimSig :=
  { s with params := s.params.map (Ty.instTarget rs), ret := instTy atoms rs s.ret, eff := instEff atoms rs s.eff }

/-- 署名に現れる原子（候補の集合の中で）の具体化の像が、候補の集合に入る。 -/
def instClosed (atoms : List Atom) (rs : List Range) (s : PrimSig) : Bool :=
  ((Ty.fn s.names s.params s.ret s.eff).collectAtoms atoms).all (fun y => decide (y.instR rs ∈ atoms))

theorem instClosed_spec {atoms : List Atom} {rs : List Range} {s : PrimSig}
    (h : instClosed atoms rs s = true) :
    ∀ y ∈ (Ty.fn s.names s.params s.ret s.eff).collectAtoms atoms, y.instR rs ∈ atoms := by
  intro y hy
  simpa using List.all_eq_true.mp h y hy

theorem instTy_eq {atoms : List Atom} {rs : List Range} {t : Ty} (h : (t.rawInstR rs).Support (· ∈ atoms)) :
    instTy atoms rs t = t.instR rs :=
  Ty.normWith_eq_norm _ _ h

theorem instEff_eq {atoms : List Atom} {rs : List Range} {e : Eff} (h : (Eff.rawInstR rs e).Support (· ∈ atoms)) :
    instEff atoms rs e = Eff.instR rs e := by
  cases e with
  | mk a fs =>
    simp only [Eff.rawInstR, Eff.Support, Ty.rawInstRTys_eq_map] at h
    simp only [instEff, Eff.instR]
    congr 1
    apply List.map_congr_left
    intro t ht
    exact instTy_eq (Ty.SupportList.iff.mp h.2 _ (List.mem_map_of_mem ht))

/-- 署名の型の原子が候補の集合にあり、その具体化の像も候補の集合にあるなら、具体化した署名の原子も候補の集合にある。 -/
theorem inst_rawSupport {atoms : List Atom} {rs : List Range} {s : PrimSig}
    (hs : Ty.AtomsIn atoms (.fn s.names s.params s.ret s.eff)) (hc : instClosed atoms rs s = true) :
    (s.ret.rawInstR rs).Support (· ∈ atoms) ∧ (Eff.rawInstR rs s.eff).Support (· ∈ atoms) := by
  have hall := Ty.collectAtoms_complete atoms _ hs
  simp only [Ty.Support] at hall
  have hpq : ∀ y, y ∈ (Ty.fn s.names s.params s.ret s.eff).collectAtoms atoms → y.instR rs ∈ atoms :=
    instClosed_spec hc
  exact ⟨Ty.support_rawInstR rs hpq _ hall.2.1, Eff.support_rawInstR rs hpq _ hall.2.2⟩

/-- 検査器の具体化は、署名の具体化 `s.inst rs` と同じ署名を与える。 -/
theorem instSig_eq {atoms : List Atom} {rs : List Range} {s : PrimSig}
    (hs : Ty.AtomsIn atoms (.fn s.names s.params s.ret s.eff)) (hc : instClosed atoms rs s = true) :
    instSig atoms rs s = s.inst rs := by
  obtain ⟨hr, he⟩ := inst_rawSupport hs hc
  simp only [instSig, PrimSig.inst, instTy_eq hr, instEff_eq he]

/-- 具体化した署名の型の原子も候補の集合にある（検査器の後続の計算の前提）。 -/
theorem inst_atoms {atoms : List Atom} {rs : List Range} {s : PrimSig}
    (hs : Ty.AtomsIn atoms (.fn s.names s.params s.ret s.eff)) (hc : instClosed atoms rs s = true) :
    Tys.AtomsIn atoms (s.inst rs).params ∧ (s.inst rs).ret.AtomsIn atoms ∧ (s.inst rs).eff.AtomsIn atoms := by
  obtain ⟨hr, he⟩ := inst_rawSupport hs hc
  refine ⟨Tys.support_instTarget rs hs.1, Ty.norm_support _ hr, ?_⟩
  rw [PrimSig.inst_eff]
  cases h : s.eff with
  | mk a fs =>
    rw [h] at he
    simp only [Eff.rawInstR, Eff.Support, Ty.rawInstRTys_eq_map] at he
    simp only [Eff.instR, Eff.Support]
    refine ⟨he.1, Ty.SupportList.iff.mpr fun t ht => ?_⟩
    obtain ⟨u, hu, rfl⟩ := List.mem_map.mp ht
    exact Ty.norm_support _ (Ty.SupportList.iff.mp he.2 _ (List.mem_map_of_mem hu))

/-! ## 範囲の具体化の許容の判定 -/

/-- 項目の制約 `admitsR` の判定の、表との契約。 -/
def AdmitsRDecSound (B : Builtins) (admitsRDec : PrimName → List Range → Bool) : Prop :=
  ∀ b rs, admitsRDec b rs = true → B.admitsR b rs

/-- `Builtins.RangeAdmissible` の判定。項目の制約だけを表と合う判定 `admitsRDec` に任せる。 -/
def rangeAdmissibleCheck (admitsRDec : PrimName → List Range → Bool) (b : PrimName) (s : PrimSig)
    (rs : List Range) : Bool :=
  decide (Range.FitsKinds rs s.rkinds) && rs.all (fun r => decide r.WF) &&
    (rs.all (fun r => decide (r = .top)) || admitsRDec b rs) && rs.all (fun r => decide r.Canonical)

theorem rangeAdmissibleCheck_sound {B : Builtins} {admitsRDec : PrimName → List Range → Bool}
    (had : AdmitsRDecSound B admitsRDec) {b : PrimName} {s : PrimSig} {rs : List Range}
    (h : rangeAdmissibleCheck admitsRDec b s rs = true) : B.RangeAdmissible b s rs := by
  simp only [rangeAdmissibleCheck, Bool.and_eq_true, Bool.or_eq_true, decide_eq_true_eq, List.all_eq_true] at h
  obtain ⟨⟨⟨hk, hw⟩, ha⟩, hc⟩ := h
  refine ⟨⟨hk, hw, ?_⟩, hc⟩
  rcases ha with ht | ha
  · exact Or.inl ht
  · exact Or.inr (had b rs ha)

/-- 範囲の変数のない項目の空の列は、判定を通る（旧の像）。 -/
theorem rangeAdmissibleCheck_nil (admitsRDec : PrimName → List Range → Bool) (b : PrimName) {s : PrimSig}
    (h0 : s.nranges = 0) : rangeAdmissibleCheck admitsRDec b s [] = true := by
  have : s.rkinds = [] := List.eq_nil_of_length_eq_zero h0
  simp [rangeAdmissibleCheck, this, Range.FitsKinds]

/-- 空の列の判定は、範囲の変数のない項目でだけ通る（旧の検査器の `s.nranges = 0` の要求と同じ）。 -/
theorem rangeAdmissibleCheck_nil_iff (admitsRDec : PrimName → List Range → Bool) (b : PrimName) (s : PrimSig) :
    rangeAdmissibleCheck admitsRDec b s [] = true ↔ s.nranges = 0 := by
  constructor
  · intro h
    simp only [rangeAdmissibleCheck, Bool.and_eq_true, decide_eq_true_eq] at h
    have := h.1.1.1.length
    simpa [PrimSig.nranges] using this.symm
  · exact rangeAdmissibleCheck_nil admitsRDec b

/-- 空の列の具体化の像は元の原子なので、署名の原子の閉包の判定はいつも通る。 -/
theorem instClosed_nil (atoms : List Atom) (s : PrimSig) (hs : Ty.AtomsIn atoms (.fn s.names s.params s.ret s.eff)) :
    instClosed atoms [] s = true := by
  simp only [instClosed, List.all_eq_true, Atom.instR_nil, decide_eq_true_eq]
  exact Ty.collectAtoms_sound atoms _ hs

/-- 正規形の署名では、空の列の検査器の具体化は署名を変えない（旧の検査器と同じ型を計算する）。 -/
theorem instSig_nil {atoms : List Atom} {s : PrimSig} (hs : Ty.AtomsIn atoms (.fn s.names s.params s.ret s.eff))
    (hr : s.ret.Canonical) (he : ∀ t ∈ s.eff.fails, t.Canonical) : instSig atoms [] s = s := by
  rw [instSig_eq hs (instClosed_nil atoms s hs)]
  exact PrimSig.inst_nil_of_canonical hr he

end Benitoite.Surface.CheckRanges
