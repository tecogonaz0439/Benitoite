import Benitoite.Release.Lemmas.Membership

/-!
# 組み込みの呼び出しの範囲の列（L20.5）の旧の像での同値と小例

項 `.prim b ts es rs` は具体化した範囲の列 `rs` を持ち、V-Prim は署名を `s.inst rs` で具体化して型付ける（設計書
01-12「型付け規則」、問 5・問 18 の行 2・4・6）。本ファイルは次を置く。

- 範囲の具体化について量化した欄の一般形 `Builtins.FieldNew` と、範囲の変数のない表（旧の像の表）で旧の欄と同値で
  あること（`Builtins.fieldNew_iff_old`）、項目を足した表の欄の分解（`Builtins.fieldNew_extend`）。L00.03 の
  `fieldNew_iff_old`・`fieldNew_extend` の本番版である。
- `delta_typed`・`io_typed`・`io_exists` の三つの欄がこの形であり、旧の像の表で旧の欄と同値であること。旧の δ は
  範囲の列を受け取らないので、旧の欄の δ は空の範囲の列で読む。
- V-Prim の前提、`PrimSig.StoreShape`、操作の型 `opSig` の旧の像での同値。
- 問 22 の表の項目の形の署名が `PrimSig.Scoped`（引数の位置の条件と操作の結果の条件を含む）を満たすこと。
- 閉じた非 Top の値が組み込みへ渡る場合の小例（`E_Prim`・`E_IO`・`E_OpPrim`）。
-/

namespace Benitoite.Release

open Scope.Domain (Range)

/-! ## 量化した欄の一般形 -/

/-- 範囲の変数のない表（旧の像の表）。全ての項目が範囲の変数を持たない。 -/
def Builtins.RangeFree (B : Builtins) : Prop := ∀ b s, B.sig b = some s → s.nranges = 0

/-- 範囲の具体化について量化した欄の形。`F b s rs` は欄の本体（範囲の列 `rs` で具体化した項目の条件）。 -/
def Builtins.FieldNew (B : Builtins) (F : PrimName → PrimSig → List Range → Prop) : Prop :=
  ∀ b s, B.sig b = some s → ∀ rs, B.RangeAdmissible b s rs → F b s rs

/-- 旧の欄の形（範囲の具体化なし。空の範囲の列で読む）。 -/
def Builtins.FieldOld (B : Builtins) (F : PrimName → PrimSig → List Range → Prop) : Prop :=
  ∀ b s, B.sig b = some s → F b s []

/-- 範囲の変数のない表では、量化を広げた欄は旧の欄と同値である（L00.03 の `fieldNew_iff_old` の本番版）。 -/
theorem Builtins.fieldNew_iff_old {B : Builtins} {F : PrimName → PrimSig → List Range → Prop} (hB : B.RangeFree) :
    B.FieldNew F ↔ B.FieldOld F := by
  constructor
  · intro h b s hs
    exact h b s hs [] ((Builtins.rangeAdmissible_iff_nil (hB b s hs) []).mpr rfl)
  · intro h b s hs rs hrs
    obtain rfl := (Builtins.rangeAdmissible_iff_nil (hB b s hs) rs).mp hrs
    exact h b s hs

/-- 範囲の具体化の許容は、表の項目の制約 `admitsR b` だけを通して表を読む。 -/
theorem Builtins.rangeAdmissible_congr {B B' : Builtins} {b : PrimName} (h : B'.admitsR b = B.admitsR b)
    (s : PrimSig) (rs : List Range) : B'.RangeAdmissible b s rs ↔ B.RangeAdmissible b s rs := by
  unfold Builtins.RangeAdmissible; rw [h]

/-- 欄は項目ごとの条件の連言なので、表へ項目を一つ加えた表の欄は、元の表の欄と加えた項目の条件に分かれる
（L00.03 の `fieldNew_extend` の本番版）。 -/
theorem Builtins.fieldNew_extend {B B' : Builtins} {F : PrimName → PrimSig → List Range → Prop}
    {b0 : PrimName} {e0 : PrimSig}
    (hsig : ∀ b, B'.sig b = if b = b0 then some e0 else B.sig b)
    (hadm : ∀ b, b ≠ b0 → B'.admitsR b = B.admitsR b) (hfresh : B.sig b0 = none) :
    B'.FieldNew F ↔ B.FieldNew F ∧ ∀ rs, B'.RangeAdmissible b0 e0 rs → F b0 e0 rs := by
  constructor
  · intro h
    refine ⟨fun b s hb rs hR => ?_, fun rs hR => h b0 e0 (by simp [hsig]) rs hR⟩
    have hne : b ≠ b0 := by rintro rfl; simp [hfresh] at hb
    exact h b s (by simp [hsig, hne, hb]) rs ((Builtins.rangeAdmissible_congr (hadm b hne) s rs).mpr hR)
  · rintro ⟨h, h0⟩ b s hb rs hR
    by_cases hbe : b = b0
    · subst hbe; simp [hsig] at hb; subst hb; exact h0 rs hR
    · simp [hsig, hbe] at hb
      exact h b s hb rs ((Builtins.rangeAdmissible_congr (hadm b hbe) s rs).mp hR)

/-! ## 三つの欄 -/

/-- `delta_typed` の欄の本体（範囲の列で具体化した項目の条件）。 -/
def Builtins.DeltaTypedAt (P : Program) (B : Builtins) (b : PrimName) (s : PrimSig) (rs : List Range) : Prop :=
  ∀ Ψ ts es ws, s.kind = .pure → ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)) →
    ∃ o, B.delta b ts es rs ws = some o ∧ (∀ n, o ≠ .exit n) ∧ OutcomeTy P B Ψ o (Ty.subst ts es (s.inst rs).ret)

/-- `io_typed` の欄の本体。 -/
def Builtins.IOTypedAt (P : Program) (B : Builtins) (b : PrimName) (s : PrimSig) (rs : List Range) : Prop :=
  ∀ Ψ ts es ws o obs, (s.kind = .io ∨ s.kind = .exit) → ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)) →
    B.ioResponse b ts es ws o obs → OutcomeTy P B Ψ o (Ty.subst ts es (s.inst rs).ret)

/-- `io_exists` の欄の本体。 -/
def Builtins.IOExistsAt (P : Program) (B : Builtins) (b : PrimName) (s : PrimSig) (rs : List Range) : Prop :=
  ∀ Ψ ts es ws, (s.kind = .io ∨ s.kind = .exit) → ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)) → ∃ o obs, B.ioResponse b ts es ws o obs

/-- 三つの欄は、量化した欄の一般形である（欄の字面は `Builtins.Assumptions` のとおり）。 -/
theorem Builtins.CoreAssumptions.delta_typed_fieldNew {P : Program} {B : Builtins} (hb : B.CoreAssumptions P) :
    B.FieldNew (B.DeltaTypedAt P) :=
  fun b s hs rs hrs Ψ ts es ws hk htl hel had hargs => hb.delta_typed Ψ b s rs ts es ws hs hk hrs htl hel had hargs

theorem Builtins.CoreAssumptions.io_typed_fieldNew {P : Program} {B : Builtins} (hb : B.CoreAssumptions P) :
    B.FieldNew (B.IOTypedAt P) :=
  fun b s hs rs hrs Ψ ts es ws o obs hk htl hel had hargs hr =>
    hb.io_typed Ψ b s rs ts es ws o obs hs hk hrs htl hel had hargs hr

theorem Builtins.CoreAssumptions.io_exists_fieldNew {P : Program} {B : Builtins} (hb : B.CoreAssumptions P) :
    B.FieldNew (B.IOExistsAt P) :=
  fun b s hs rs hrs Ψ ts es ws hk htl hel had hargs => hb.io_exists Ψ b s rs ts es ws hs hk hrs htl hel had hargs

/-- 旧の `delta_typed`（L20.5 の前の字面。旧の δ は範囲の列を受け取らないので、空の範囲の列で読む）。 -/
def Builtins.DeltaTypedOld (P : Program) (B : Builtins) : Prop :=
  ∀ Ψ b s ts es ws, B.sig b = some s → s.kind = .pure →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    ∃ o, B.delta b ts es [] ws = some o ∧ (∀ n, o ≠ .exit n) ∧ OutcomeTy P B Ψ o (Ty.subst ts es s.ret)

/-- 旧の `io_typed`（範囲の列のない形）。観測は今の欄と同じく量化する。観測を捨てた形との同値は
`Builtins.ioTypedOld_iff_noObs`（`Release/Lemmas/Observation.lean`）。 -/
def Builtins.IOTypedOld (P : Program) (B : Builtins) : Prop :=
  ∀ Ψ b s ts es ws o obs, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    B.ioResponse b ts es ws o obs → OutcomeTy P B Ψ o (Ty.subst ts es s.ret)

/-- 旧の `io_exists`（範囲の列のない形）。観測は今の欄と同じく量化する（`Builtins.ioExistsOld_iff_noObs`）。 -/
def Builtins.IOExistsOld (P : Program) (B : Builtins) : Prop :=
  ∀ Ψ b s ts es ws, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    ∃ o obs, B.ioResponse b ts es ws o obs

/-- 旧の像の表（範囲の変数のない `PrimSig.Scoped` の項目だけの表）では、空の具体化は署名を変えない。 -/
theorem Builtins.RangeFree.inst_nil {B : Builtins} (hB : B.RangeFree) (hsc : ∀ b s, B.sig b = some s → s.Scoped)
    {b : PrimName} {s : PrimSig} (hs : B.sig b = some s) : s.inst [] = s :=
  PrimSig.inst_nil_of_scoped (hsc b s hs) (hB b s hs)

theorem Builtins.delta_typed_iff_old {P : Program} {B : Builtins} (hB : B.RangeFree)
    (hsc : ∀ b s, B.sig b = some s → s.Scoped) : B.FieldNew (B.DeltaTypedAt P) ↔ B.DeltaTypedOld P := by
  rw [Builtins.fieldNew_iff_old hB]
  constructor
  · intro h Ψ b s ts es ws hs hk htl hel had hargs
    have := h b s hs Ψ ts es ws hk htl hel had
    rw [hB.inst_nil hsc hs] at this
    exact this hargs
  · intro h b s hs Ψ ts es ws hk htl hel had hargs
    rw [hB.inst_nil hsc hs] at hargs ⊢
    exact h Ψ b s ts es ws hs hk htl hel had hargs

theorem Builtins.io_typed_iff_old {P : Program} {B : Builtins} (hB : B.RangeFree)
    (hsc : ∀ b s, B.sig b = some s → s.Scoped) : B.FieldNew (B.IOTypedAt P) ↔ B.IOTypedOld P := by
  rw [Builtins.fieldNew_iff_old hB]
  constructor
  · intro h Ψ b s ts es ws o obs hs hk htl hel had hargs hr
    have := h b s hs Ψ ts es ws o obs hk htl hel had
    rw [hB.inst_nil hsc hs] at this
    exact this hargs hr
  · intro h b s hs Ψ ts es ws o obs hk htl hel had hargs hr
    rw [hB.inst_nil hsc hs] at hargs ⊢
    exact h Ψ b s ts es ws o obs hs hk htl hel had hargs hr

theorem Builtins.io_exists_iff_old {P : Program} {B : Builtins} (hB : B.RangeFree)
    (hsc : ∀ b s, B.sig b = some s → s.Scoped) : B.FieldNew (B.IOExistsAt P) ↔ B.IOExistsOld P := by
  rw [Builtins.fieldNew_iff_old hB]
  constructor
  · intro h Ψ b s ts es ws hs hk htl hel had hargs
    have := h b s hs Ψ ts es ws hk htl hel had
    rw [hB.inst_nil hsc hs] at this
    exact this hargs
  · intro h b s hs Ψ ts es ws hk htl hel had hargs
    rw [hB.inst_nil hsc hs] at hargs
    exact h Ψ b s ts es ws hs hk htl hel had hargs

/-! ## V-Prim・StoreShape・opSig の旧の像 -/

/-- 旧の像の項目（範囲の変数のない `PrimSig.Scoped`）では、V-Prim の前提は、範囲の列が空であることと旧の V-Prim の
前提の組であり、型は表の署名の型である（問 18 の行 6 の旧の像での同値）。 -/
theorem PrimSig.vPrim_premises_iff_old {B : Builtins} {b : PrimName} {s : PrimSig} {C : List TParam} {Q : NoFailCtx}
    {ts : List Ty} {es : List Eff} {rs : List Range} {T : Ty} (hsc : s.Scoped) (h0 : s.nranges = 0) :
    (B.RangeAdmissible b s rs ∧ NamesWF (s.inst rs).names (s.inst rs).params ∧ PrimitiveAdmissible C (s.inst rs) Q ts es ∧
        T = fnTy (s.inst rs).names (s.inst rs).params (s.inst rs).ret (s.inst rs).eff ts es) ↔
      (rs = [] ∧ NamesWF s.names s.params ∧ PrimitiveAdmissible C s Q ts es ∧
        T = fnTy s.names s.params s.ret s.eff ts es) := by
  have hinst := PrimSig.inst_nil_of_scoped hsc h0
  constructor
  · rintro ⟨hr, h⟩
    obtain rfl := (Builtins.rangeAdmissible_iff_nil h0 rs).mp hr
    rw [hinst] at h
    exact ⟨rfl, h⟩
  · rintro ⟨rfl, h⟩
    rw [hinst]
    exact ⟨(Builtins.rangeAdmissible_iff_nil h0 []).mpr rfl, h⟩

/-- L20.5 の前の `PrimSig.StoreShape`（範囲の変数の条件なし）。比較のためだけに置く。 -/
def PrimSig.StoreShapeOld (s : PrimSig) : Prop :=
  match s.kind with
  | .refNew => s.names = ["value"] ∧ s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.tvar 0] ∧ s.ret = .reference (.tvar 0) ∧
      s.eff = Eff.single stateEff
  | .refGet => s.names = ["reference"] ∧ s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.reference (.tvar 0)] ∧ s.ret = .tvar 0 ∧
      s.eff = Eff.single stateEff
  | .refSet => s.names = ["reference", "value"] ∧ s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.reference (.tvar 0), .tvar 0] ∧
      s.ret = .base .unit ∧ s.eff = Eff.single stateEff
  | .refUpdate => s.names = ["reference", "f"] ∧ s.ntys = 1 ∧ s.neffs = 0 ∧
      s.params = [.reference (.tvar 0), .fn ["value"] [.tvar 0] (.tvar 0) Eff.empty] ∧
      s.ret = .base .unit ∧ s.eff = Eff.single stateEff
  | .force => s.names = ["value"] ∧ s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.lazy (.tvar 0)] ∧ s.ret = .tvar 0 ∧
      s.eff = Eff.empty
  | .pure => True
  | .io => True
  | .exit => True

/-- 範囲の変数のない項目では、`StoreShape` は旧の形と同値である（S3 の旧の像での同値）。 -/
theorem PrimSig.storeShape_iff_old {s : PrimSig} (h0 : s.rkinds = []) : s.StoreShape ↔ s.StoreShapeOld := by
  unfold PrimSig.StoreShape PrimSig.StoreShapeOld
  cases s.kind <;> simp [h0]

/-- L20.5 の前の `opSig`（組み込みの操作の型は表の署名のまま）。比較のためだけに置く。 -/
def opSigOld (P : Program) (B : Builtins) : OpRef → Option OpSig
  | .fail => none
  | .user o => (P.ops o).map fun od => ⟨od.tparams, od.names, od.params, od.ret, od.eff⟩
  | .prim b =>
      match B.sig b with
      | some s =>
          match s.opEff with
          | some l => some ⟨s.tparams, s.names, s.params, s.ret, l⟩
          | none => none
      | none => none

/-- 範囲の変数のない表では、節の操作の型（Top の列で具体化した署名）は旧の操作の型と同じである。 -/
theorem opSig_eq_old {P : Program} {B : Builtins} (hB : B.RangeFree) (o : OpRef) : opSig P B o = opSigOld P B o := by
  cases o with
  | fail => rfl
  | user o => rfl
  | prim b =>
    simp only [opSig, opSigOld]
    cases hs : B.sig b with
    | none => rfl
    | some s =>
      have hid : Ty.instTarget [] = id := funext Ty.instTarget_nil
      simp only [PrimSig.topRanges, hB b s hs, List.replicate_zero, hid, List.map_id]
      cases s.opEff <;> rfl

/-- `PrimitiveAdmissible.of_noRows` の具体化した署名の版。行の変数のない項目を、範囲の変数の個数以上の閉じた列で
具体化した署名は、行の像の条件を満たす。 -/
theorem PrimitiveAdmissible.of_noRows_inst {C : List TParam} {s : PrimSig} {rs : List Range} {Q : NoFailCtx}
    {ts : List Ty} (hs : s.Scoped) (hn : s.nranges ≤ rs.length) (hne : s.neffs = 0) (ht : ts.length = s.ntys)
    (had : s.admits C ts) (hw : ∀ t ∈ ts, Ty.WF 0 C.length t ∧ ∀ b r e, t ≠ .cont b r e) :
    PrimitiveAdmissible C (s.inst rs) Q ts [] := by
  have hv := hs.inst_varsIn_zero hn
  have hrows := Eff.VarsIn.rows _ hv.2.2
  have hqs := Qsig.varsIn_scoped hv.1 hv.2.1 hv.2.2
  rw [hne] at hrows hqs
  exact ⟨ht, had, hw, hne.symm, by simp, hrows, hqs, fun i hi => (Nat.not_lt_zero i (hqs i hi)).elim⟩

/-! ## 問 22 の表の項目の形と `PrimSig.Scoped` -/

namespace PrimRangeExamples

/-- `Scope.PathIn[rvar i]`。 -/
def pathIn (i : Nat) : Ty := .opaque "Scope.PathIn" (.rvar i)

/-- 単純な Result の型（誤り型は名前だけで表す）。 -/
def resultTy (a e : Ty) : Ty := .data "Result" [a, e]

def ioErrorTy : Ty := .opaqueTop "IOError"

/-- `File.writeTextIn` の形（io、操作 `File.Write`、引数の位置 0 が `PathIn[R]`、結果は範囲の変数を持たない）。効果は
L20.5 の時点の `io_op` に合わせて名前だけの原子にした（範囲付きの効果 `File.Write[R]` を持つ項目は `Release/TargetTable.lean` の `writeTextIn`。形の検査 `Builtins.ShapeOk` を通る）。 -/
def writeTextInSig : PrimSig where
  tparams := []
  neffs := 0
  names := ["path", "text"]
  params := [pathIn 0, .base .string]
  ret := resultTy (.base .unit) ioErrorTy
  eff := Eff.single "File.Write"
  admits := fun _ _ => True
  kind := .io
  opEff := some "File.Write"
  rkinds := [.path]

/-- `Scope.checkPathIn` の形（pure、範囲の変数は結果の型だけ）。 -/
def checkPathInSig : PrimSig where
  tparams := []
  neffs := 0
  names := ["pattern", "path"]
  params := [.base .string, .base .string]
  ret := resultTy (pathIn 0) (.opaqueTop "Scope.ScopeError")
  eff := Eff.empty
  admits := fun _ _ => True
  kind := .pure
  opEff := none
  rkinds := [.path]

/-- `Scope.widenPathIn` の形（pure、範囲の変数 2、引数の位置 0 と結果）。 -/
def widenPathInSig : PrimSig where
  tparams := []
  neffs := 0
  names := ["path"]
  params := [pathIn 0]
  ret := pathIn 1
  eff := Eff.empty
  admits := fun _ _ => True
  kind := .pure
  opEff := none
  rkinds := [.path, .path]

/-- `Scope.pathInValue` の形（pure、引数の位置 0）。 -/
def pathInValueSig : PrimSig where
  tparams := []
  neffs := 0
  names := ["path"]
  params := [pathIn 0]
  ret := .base .string
  eff := Eff.empty
  admits := fun _ _ => True
  kind := .pure
  opEff := none
  rkinds := [.path]

theorem writeTextIn_scoped : writeTextInSig.Scoped := by
  refine ⟨⟨rfl, by decide⟩, ?_, ?_, ?_, ?_, ?_⟩
  · simp [writeTextInSig, pathIn, Ty.VarsInList, Ty.VarsIn, Scope.Signature.Ix.WF, PrimSig.nranges]
  · simp [writeTextInSig, resultTy, ioErrorTy, Ty.VarsInList, Ty.VarsIn, Scope.Signature.Ix.WF]
  · refine ⟨fun i h => by simp at h, trivial, fun x hx => ?_⟩
    simp only [beq_iff_eq] at hx
    subst hx; trivial
  · intro p hp
    simp only [writeTextInSig, List.mem_cons, List.not_mem_nil, or_false] at hp
    rcases hp with rfl | rfl
    · exact Or.inl ⟨_, _, rfl⟩
    · exact Or.inr trivial
  · intro l _
    simp [writeTextInSig, resultTy, ioErrorTy, Ty.VarsInList, Ty.VarsIn, Scope.Signature.Ix.WF]

theorem checkPathIn_scoped : checkPathInSig.Scoped := by
  refine ⟨⟨rfl, by decide⟩, ?_, ?_, ?_, ?_, ?_⟩
  · simp [checkPathInSig, Ty.VarsInList, Ty.VarsIn]
  · simp [checkPathInSig, resultTy, pathIn, Ty.VarsInList, Ty.VarsIn, Scope.Signature.Ix.WF, PrimSig.nranges]
  · exact ⟨fun i h => by simp at h, trivial,
      fun x hx => by simp at hx⟩
  · intro p hp
    simp only [checkPathInSig, List.mem_cons, List.not_mem_nil, or_false] at hp
    rcases hp with rfl | rfl <;> exact Or.inr trivial
  · intro l hl; simp [checkPathInSig] at hl

theorem widenPathIn_scoped : widenPathInSig.Scoped := by
  refine ⟨⟨rfl, by decide⟩, ?_, ?_, ?_, ?_, ?_⟩
  · simp [widenPathInSig, pathIn, Ty.VarsInList, Ty.VarsIn, Scope.Signature.Ix.WF, PrimSig.nranges]
  · simp [widenPathInSig, pathIn, Ty.VarsIn, Scope.Signature.Ix.WF, PrimSig.nranges]
  · exact ⟨fun i h => by simp at h, trivial,
      fun x hx => by simp at hx⟩
  · intro p hp
    simp only [widenPathInSig, List.mem_cons, List.not_mem_nil, or_false] at hp
    subst hp; exact Or.inl ⟨_, _, rfl⟩
  · intro l hl; simp [widenPathInSig] at hl

theorem pathInValue_scoped : pathInValueSig.Scoped := by
  refine ⟨⟨rfl, by decide⟩, ?_, ?_, ?_, ?_, ?_⟩
  · simp [pathInValueSig, pathIn, Ty.VarsInList, Ty.VarsIn, Scope.Signature.Ix.WF, PrimSig.nranges]
  · simp [pathInValueSig, Ty.VarsIn]
  · exact ⟨fun i h => by simp at h, trivial,
      fun x hx => by simp at hx⟩
  · intro p hp
    simp only [pathInValueSig, List.mem_cons, List.not_mem_nil, or_false] at hp
    subst hp; exact Or.inl ⟨_, _, rfl⟩
  · intro l hl; simp [pathInValueSig] at hl

/-- 操作の結果に範囲の変数を置いた項目（S1 の反例の形）は、`PrimSig.Scoped` で拒否される。 -/
theorem not_scoped_opRet : ¬ ({ writeTextInSig with ret := pathIn 0 } : PrimSig).Scoped := by
  rintro ⟨-, -, -, -, -, h⟩
  have := h "File.Write" rfl
  simp [pathIn, Ty.VarsIn, Scope.Signature.Ix.WF] at this

/-! ## 閉じた非 Top の値が組み込みへ渡る場合の小例 -/

/-- 小例の表。`Scope.PathIn` に種類 path を与え、`File.writeTextIn` と `Scope.pathInValue` の形の項目を置く。範囲の
具体化の制約は何でも許す。仮定 `Builtins.Assumptions` を満たす実例ではない（範囲付きの項目を持つ実例は `Release/ModelTargets.lean`）。 -/
def builtins : Builtins :=
  { Model.builtins with
    sig := fun b => if b = "File.writeTextIn" then some writeTextInSig
      else if b = "Scope.pathInValue" then some pathInValueSig else Model.builtins.sig b
    delta := fun b _ _ _ ws => match b, ws with
      | "Scope.pathInValue", [_] => some (.val (.const (.string "/data/a.txt")))
      | _, _ => none
    ioResponse := fun b _ _ ws o obs => b = "File.writeTextIn" ∧ ws.length = 2 ∧ o = .val (.con "Ok" [] [.const .unit]) ∧
      obs = (match ws with | .checked t :: _ => [t] | _ => [])
    effects := fun l => if l = "File.Write" then some ["File.writeTextIn"] else Model.builtins.effects l
    valKind := fun o => if o = "Scope.PathIn" then some .path else none
    admitsR := fun _ _ => True }

def range : Range := MembershipExample.range
def target : Scope.Domain.Target := MembershipExample.target

theorem checked_typed {P : Program} {Ψ : StoreTy} :
    HasTypeV P builtins Ψ [] [] (.checked target) (.opaque "Scope.PathIn" (.fixed range)) :=
  .V_Checked rfl (by decide)

/-- 範囲の列 `[/data/**]` は許される（非 Top の具体化）。 -/
theorem range_admissible (b : PrimName) (s : PrimSig) (hs : s.rkinds = [.path]) :
    builtins.RangeAdmissible b s [range] := by
  refine ⟨⟨?_, ?_, Or.inr trivial⟩, ?_⟩
  · rw [hs]; exact ⟨by decide, Scope.Domain.Range.fitsKinds_nil⟩
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide

/-- 引数の型の具体化。`PathIn[rvar 0]` は `PathIn["/data/**"]` になり、Top の列では `PathIn[Top]` になる。 -/
example : (writeTextInSig.inst [range]).params = [.opaque "Scope.PathIn" (.fixed range), .base .string] := rfl
example : writeTextInSig.params.map (Ty.instTarget writeTextInSig.topRanges) =
    [.opaqueTop "Scope.PathIn", .base .string] := rfl

/-- 呼び出しの型付けに使う、具体化した署名の `PrimitiveAdmissible`（行の変数のない項目）。 -/
theorem pathInValue_admissible : PrimitiveAdmissible [] (pathInValueSig.inst [range]) Qempty [] [] :=
  PrimitiveAdmissible.of_noRows_inst pathInValue_scoped (by decide) rfl rfl trivial (by simp)

theorem writeTextIn_admissible : PrimitiveAdmissible [] (writeTextInSig.inst [range]) Qempty [] [] :=
  PrimitiveAdmissible.of_noRows_inst writeTextIn_scoped (by decide) rfl rfl trivial (by simp)

/-- 文字列の定数の値。 -/
theorem string_typed {P : Program} {Ψ : StoreTy} (x : String) :
    HasTypeV P builtins Ψ [] [] (.const (.string x)) (.base .string) := .V_Const

/-- E_Prim の場合（型付け）: 閉じた非 Top の値 `/data/a.txt`（`PathIn["/data/**"]`）を受け取る純粋な組み込みの
呼び出しが、署名を `[/data/**]` で具体化して型付く。 -/
theorem prim_typed {P : Program} {Ψ : StoreTy} {R : Option Ty} :
    HasTypeC P builtins Ψ [] [] R (.app (.prim "Scope.pathInValue" [] [] [range]) [.checked target])
      (.base .string) (Eff.substAt 0 [] [] (Eff.instR [range] Eff.empty)) := by
  have hv := HasTypeVQ.V_Prim (P := P) (B := builtins) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
    (b := "Scope.pathInValue") (s := pathInValueSig) (rs := [range]) (ts := []) (es := [])
    (by simp [builtins]) (range_admissible _ _ rfl) ⟨rfl, by decide⟩ pathInValue_admissible
  rw [fnTy_eq] at hv
  simp only [PrimSig.inst_params, PrimSig.inst_ret, PrimSig.inst_eff, PrimSig.inst_names, pathInValueSig, pathIn,
    List.map_cons, List.map_nil, Ty.instTarget, Scope.Signature.Ix.inst, Ty.subst_opaque] at hv
  have hr : Ty.subst [] [] ((Ty.base .string).instR [range]) = .base .string := by
    simp [Ty.instR, Ty.rawInstR, Ty.subst, Ty.substAt, Ty.norm]
  rw [hr] at hv
  exact .C_App hv (.cons checked_typed .nil)

/-- E_Prim の場合（遷移）: δ が範囲の列を受け取って進む。 -/
theorem prim_step {P : Program} {k : Cont} {σ : Store} :
    Step P builtins (.run (.app (.prim "Scope.pathInValue" [] [] [range]) [.checked target]) k σ) none
      (.run (.ret (.const (.string "/data/a.txt"))) k σ) :=
  .E_Prim (s := pathInValueSig) (by simp [builtins]) rfl rfl

/-- E_IO の場合（型付け）: 範囲付きの値型の引数を持つ IO の組み込みの呼び出しが、具体化した署名で型付く。 -/
theorem io_typed_example {P : Program} {Ψ : StoreTy} {R : Option Ty} :
    HasTypeC P builtins Ψ [] [] R
      (.app (.prim "File.writeTextIn" [] [] [range]) [.checked target, .const (.string "x")])
      (Ty.subst [] [] (writeTextInSig.inst [range]).ret) (Eff.substAt 0 [] [] (writeTextInSig.inst [range]).eff) := by
  have hv := HasTypeVQ.V_Prim (P := P) (B := builtins) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
    (b := "File.writeTextIn") (s := writeTextInSig) (rs := [range]) (ts := []) (es := [])
    (by simp [builtins]) (range_admissible _ _ rfl) ⟨rfl, by decide⟩ writeTextIn_admissible
  rw [fnTy_eq] at hv
  have hp : (writeTextInSig.inst [range]).params.map (Ty.subst [] []) =
      [.opaque "Scope.PathIn" (.fixed range), .base .string] := by
    simp [writeTextInSig, pathIn, Ty.instTarget, Scope.Signature.Ix.inst, Ty.subst, Ty.substAt]
  rw [hp] at hv
  exact .C_App hv (.cons checked_typed (.cons (string_typed "x") .nil))

/-- E_IO の場合（遷移）: 処理する節がなければ、応答の関係で進む。 -/
theorem io_step {P : Program} {σ : Store} :
    Step P builtins (.run (.app (.prim "File.writeTextIn" [] [] [range]) [.checked target, .const (.string "x")]) [] σ)
      (some (.io "File.writeTextIn" [.checked target, .const (.string "x")] (.val (.con "Ok" [] [.const .unit]))
        [target]))
      (.run (.ret (.con "Ok" [] [.const .unit])) [] σ) :=
  .E_IO (s := writeTextInSig) (by simp [builtins]) rfl (fun _ h => by cases h) ⟨rfl, rfl, rfl, rfl⟩

/-- E_OpPrim の場合: 節は操作の型を Top の列で具体化して型付ける（節の添字は Top）。 -/
theorem opSig_writeTextIn {P : Program} :
    opSig P builtins (.prim "File.writeTextIn") =
      some ⟨[], ["path", "text"], [.opaqueTop "Scope.PathIn", .base .string], resultTy (.base .unit) ioErrorTy,
        "File.Write"⟩ := by
  simp [opSig, builtins, writeTextInSig, pathIn, PrimSig.topRanges, PrimSig.nranges, Ty.instTarget,
    Scope.Signature.Ix.inst]

/-- E_OpPrim の場合（遷移）: 呼び出しを処理する節があれば、節の本体へ進む。 -/
theorem opPrim_step {P : Program} {σ : Store} {body : Comp} {κ : Nat} (hκ : σ κ = none) :
    Step P builtins
      (.run (.app (.prim "File.writeTextIn" [] [] [range]) [.checked target, .const (.string "x")])
        [.handleF [.mk (.prim "File.writeTextIn") 2 0 body]] σ) none
      (.run ((body.substTy [] []).instantiate ([.checked target, .const (.string "x")] ++ [.loc κ]))
        (.drop κ :: []) (σ.set κ (.cont ([] ++ [.handleF [.mk (.prim "File.writeTextIn") 2 0 body]])))) :=
by
  refine Step.E_OpPrim (s := writeTextInSig) (k1 := []) (k2 := []) (c := .mk (.prim "File.writeTextIn") 2 0 body)
    ?_ (Or.inl rfl) ⟨rfl, ?_, fun _ h => by cases h⟩ ?_ hκ
  · simp [builtins]
  · simp [handles, Clause.op]
  · simp [findClause, Clause.op]

/-- E_OpPrim の場合（保存の要の一歩）: 呼び出しの閉じた引数（`PathIn["/data/**"]` の検査済みの対象の値を含む）は、
節の操作の型の引数（`PathIn[Top]`）を持つ。保存の証明の `E_OpPrim` の腕が使う `widen_topRanges` の実例である。 -/
theorem opPrim_args_widened {P : Program} {Ψ : StoreTy} :
    HasTypeVs P builtins Ψ [] [] [.checked target, .const (.string "x")]
      ([.opaqueTop "Scope.PathIn", .base .string].map (Ty.subst [] [])) := by
  have hargs : HasTypeVs P builtins Ψ [] [] [.checked target, .const (.string "x")]
      ((writeTextInSig.inst [range]).params.map (Ty.subst [] [])) := by
    have hp : (writeTextInSig.inst [range]).params.map (Ty.subst [] []) =
        [.opaque "Scope.PathIn" (.fixed range), .base .string] := by
      simp [writeTextInSig, pathIn, Ty.instTarget, Scope.Signature.Ix.inst, Ty.subst, Ty.substAt]
    rw [hp]; exact .cons checked_typed (.cons (string_typed "x") .nil)
  have h := HasTypeVsQ.widen_topRanges writeTextIn_scoped rfl hargs
  simpa [writeTextInSig, pathIn, PrimSig.topRanges, PrimSig.nranges, Ty.instTarget, Scope.Signature.Ix.inst] using h

end PrimRangeExamples

end Benitoite.Release
