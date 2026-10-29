import Benitoite.Scope.Domain

import Benitoite.Scope.Signature

/-!
# 署名表と信頼条件のモデル（L00.03 のモデル）

0.0.13 の L00.03 のモデルである。既存の定義（`Benitoite.Release` の署名・型付け・`Builtins.Assumptions`）を変えず、
範囲付きの署名表と信頼条件の分け方を小さく写す。L00.08 で、格納方式によらない部分（範囲の位置 `Ix`、IO の形
`IOShape`、観測の条件 `ShapeTargets`、具体化の許容 `RangeAdmissible`）を採用定義 `Scope.Signature` へ移し、
本モデルはそれを直接使う。本モデルの値・型・原子・表・信頼条件の構造体（`Val`・`VTy`・`Atom`・`HasTypeV`・
`Table`・`CoreAssumptions`・`TargetAgreement`・`shapeOk`・`clauseIndex` など）は、本番の型の上で L10〜L30 が
置き換えるモデルだけの定義であり、採用定義ではない（`l00.08/placement.md`）。

三つの契約を別々に置く。

- 元の操作 b: 表の鍵（操作の名前）。範囲の数だけ鍵を増やさない。表の項目は範囲の変数（`Ix.rvar`）を
  含む元の署名である。
- 閉じた範囲 R: 呼び出しごとの具体化の引数（`rs`）。型引数・エフェクト引数と同じく呼び出しが選ぶ。
- 具体化した署名と実対象の一致: `TargetAgreement.io_target`（計画済みの信頼条件）。入力の所属は値の
  型付け、事象の対象の上限への所属は両者から証明する（`target_sound`）。上限の所属は名前の種類に相対的である
  （`EffAllows`。RV-L00 中2）。

公開名（DET-03）は L00.08 の一括の問い（問 22）の表のとおりである。誤り型の構成子（DET-04）はモデルでは `unit` で表す。
-/

namespace Benitoite.Scope.SignatureExamples

open Benitoite.Scope.Domain
open Benitoite.Scope.Signature

/-! ## 範囲の位置と型 -/

/-- 比較に要る型の部分。不透明型は名前と範囲の位置を持つ。添字を持たない旧の不透明型（資源の型を含む）は
`opaque o Ix.top` である（構成子を増やさない。language-rules B1 の (iii) を採らない）。 -/
inductive VTy where
  | string
  | int
  | unit
  | bytes
  | response
  | opaque (o : String) (ix : Ix)
  | result (ok err : VTy)
  deriving DecidableEq, Repr

def VTy.inst (rs : List Range) : VTy → VTy
  | .opaque o ix => .opaque o (ix.inst rs)
  | .result a e => .result (a.inst rs) (e.inst rs)
  | t => t

/-- 効果の原子。名前の原子は範囲の位置を持つ。旧の名前だけの原子は `name l Ix.top` である。 -/
inductive Atom where
  | name (l : String) (ix : Ix)
  | rho (i : Nat)
  deriving DecidableEq, Repr

def Atom.inst (rs : List Range) : Atom → Atom
  | .name l ix => .name l (ix.inst rs)
  | .rho i => .rho i

/-- 旧の名前だけの原子（`Eff.single l` の原子）。 -/
def Atom.ofOld (l : String) : Atom := .name l Ix.top

/-! ## 値と値の型付け -/

/-- 比較に要る値。`checked t` は範囲付きの標準値型の値で、検査した対象 t を保持する
（`RequestIn` では同じ要求も保持するが、本モデルは対象だけを写す）。`handle` は添字のない不透明値。 -/
inductive Val where
  | str (s : String)
  | int (i : Int)
  | unit
  | bytes
  | response
  | checked (t : Target)
  | handle (n : Nat)
  | ok (v : Val)
  | err (v : Val)
  deriving DecidableEq, Repr

/-- 値の型付け。`K o` は不透明型の名前 o が範囲付きの標準値型なら、その対象の種類を返す。
範囲付きの値型の所属の不変条件（`HasTypeV` が持つ）は、対象の種類の一致と範囲への所属である。 -/
def HasTypeV (K : String → Option Kind) : Val → VTy → Prop
  | .str _, .string => True
  | .int _, .int => True
  | .unit, .unit => True
  | .bytes, .bytes => True
  | .response, .response => True
  | .checked t, .opaque o (.fixed r) => K o = some t.kind ∧ r.Mem t
  | .handle _, .opaque o (.fixed .top) => K o = none
  | .ok v, .result a _ => HasTypeV K v a
  | .err v, .result _ e => HasTypeV K v e
  | _, _ => False

inductive HasTypeVs (K : String → Option Kind) : List Val → List VTy → Prop
  | nil : HasTypeVs K [] []
  | cons {v vs a as} : HasTypeV K v a → HasTypeVs K vs as → HasTypeVs K (v :: vs) (a :: as)

theorem HasTypeVs.getElem? {K : String → Option Kind} {ws : List Val} {as : List VTy}
    (h : HasTypeVs K ws as) {p : Nat} {a : VTy} (ha : as[p]? = some a) :
    ∃ w, ws[p]? = some w ∧ HasTypeV K w a := by
  induction h generalizing p with
  | nil => simp at ha
  | cons hv _ ih =>
    cases p with
    | zero => simp at ha; subst ha; exact ⟨_, rfl, hv⟩
    | succ p => simpa using ih (by simpa using ha)

/-- 明示拡大と節の添字に使う所属の補題。値の型付けだけから従い、組み込みの信頼条件を使わない。 -/
theorem HasTypeV.widen {K : String → Option Kind} {v : Val} {o : String} {k : Kind} {r s : Range}
    (hk : K o = some k) (h : HasTypeV K v (.opaque o (.fixed r))) (hs : Range.Sub r s) :
    HasTypeV K v (.opaque o (.fixed s)) := by
  cases v with
  | checked t => exact ⟨h.1, hs t h.2⟩
  | handle n =>
    cases r with
    | top => simp [HasTypeV] at h; simp [h] at hk
    | _ => simp [HasTypeV] at h
  | _ => simp [HasTypeV] at h

/-! ## IOShape と表の項目 -/

inductive PKind where
  | pure
  | io
  | exit
  deriving DecidableEq, Repr

/-- 表の項目（元の操作 b の署名）。範囲の変数ごとの対象の種類 `rkinds`（その長さが範囲の変数の数 `nranges`）は、
型パラメータの数・エフェクト変数の数 `neffs` と並ぶ具体化の引数である。IO を行わない関数の `shape` は使わない。 -/
structure Entry where
  names : List String
  params : List VTy
  ret : VTy
  eff : List Atom
  kind : PKind
  opEff : Option String
  shape : IOShape
  neffs : Nat := 0
  rkinds : List Kind := []
  deriving DecidableEq, Repr

/-- 範囲の変数の数。 -/
def Entry.nranges (e : Entry) : Nat := e.rkinds.length

/-- 具体化した署名。入力・結果・効果の範囲の変数を同じ `rs` で置き換える。名前と `opEff` は変えない。 -/
def Entry.inst (rs : List Range) (e : Entry) : Entry :=
  { e with params := e.params.map (VTy.inst rs), ret := e.ret.inst rs, eff := e.eff.map (Atom.inst rs) }

theorem Entry.inst_names (rs : List Range) (e : Entry) : (e.inst rs).names = e.names := rfl
theorem Entry.inst_opEff (rs : List Range) (e : Entry) : (e.inst rs).opEff = e.opEff := rfl
theorem Entry.inst_kind (rs : List Range) (e : Entry) : (e.inst rs).kind = e.kind := rfl
theorem Entry.inst_shape (rs : List Range) (e : Entry) : (e.inst rs).shape = e.shape := rfl
theorem Entry.inst_neffs (rs : List Range) (e : Entry) : (e.inst rs).neffs = e.neffs := rfl
theorem Entry.inst_params_length (rs : List Range) (e : Entry) :
    (e.inst rs).params.length = e.params.length := by simp [Entry.inst]

@[simp] theorem VTy.inst_nil (t : VTy) : t.inst [] = t := by
  induction t <;> simp_all [VTy.inst]

@[simp] theorem Atom.inst_nil (a : Atom) : a.inst [] = a := by cases a <;> simp [Atom.inst]

/-- 範囲の変数を持たない旧の項目は、空の具体化で変わらない。 -/
@[simp] theorem Entry.inst_nil (e : Entry) : e.inst [] = e := by
  cases e
  simp only [Entry.inst, VTy.inst_nil, Entry.mk.injEq, true_and, and_true]
  constructor
  · exact (List.map_congr_left (fun t _ => VTy.inst_nil t)).trans (List.map_id _)
  · exact (List.map_congr_left (fun a _ => Atom.inst_nil a)).trans (List.map_id _)

/-- 組み込みの表。鍵は元の操作の名前。範囲によらずエフェクトの操作の一覧・種類・資源を名前で引く。 -/
structure Table where
  sig : String → Option Entry
  effects : String → Option (List String)
  /-- エフェクトの名前の対象の種類。対象のないエフェクト（Console など）は `none`。 -/
  effKind : String → Option Kind
  /-- 不透明型の名前が範囲付きの標準値型なら、その対象の種類。 -/
  valKind : String → Option Kind
  isResource : String → Bool
  /-- 範囲の具体化の制約（型引数の `admits` に当たる）。明示拡大の被覆などを置く。 -/
  admitsR : String → List Range → Prop
  delta : String → List Range → List Val → Option Val
  /-- IO の応答と、観測した対象の有限列。観測の表し方は L00.04 で決める。 -/
  ioResponse : String → List Range → List Val → Val → List Target → Prop

/-- 範囲の具体化の許容。採用定義の `Signature.RangeAdmissible` に項目の範囲の変数の種類と表の制約を渡す。 -/
def RangeAdmissible (T : Table) (b : String) (e : Entry) (rs : List Range) : Prop :=
  Signature.RangeAdmissible e.rkinds (T.admitsR b) rs

/-- 資源の型の判定。範囲付きの添字を持つ型は資源にならない（申し送り 3。判定の定義で決め、信頼条件の
欄を増やさない）。 -/
def Table.isResourceTy (T : Table) : VTy → Bool
  | .opaque o (.fixed .top) => T.isResource o
  | _ => false

theorem Table.isResourceTy_eq_top {T : Table} {t : VTy} (h : T.isResourceTy t = true) :
    ∃ o, t = .opaque o (.fixed .top) ∧ T.isResource o = true := by
  match t, h with
  | .opaque o (.fixed .top), h => exact ⟨o, rfl, h⟩

/-! ## io_op の内容の変更: 形ごとの条件 -/

def opListed (T : Table) (l b : String) : Bool :=
  match T.effects l with
  | some ops => ops.contains b
  | none => false

/-- 具体化の前の項目の形の検査（`io_op` の新しい内容の候補）。元の操作の名前、`opEff`、`neffs = 0`、
操作の一覧への所属を全ての形で保ち、対象の位置・入力の添字・効果の原子の一致を形ごとに求める。 -/
def shapeOk (T : Table) (b : String) (e : Entry) : Bool :=
  match e.opEff with
  | none => false
  | some l =>
    opListed T l b && e.neffs == 0 &&
    match e.shape with
    | .untargeted => T.effKind l == none && e.rkinds == [] && e.eff == [Atom.ofOld l]
    | .topTargeted k => T.effKind l == some k && e.rkinds == [] && e.eff == [Atom.ofOld l]
    | .single k p =>
        T.effKind l == some k && e.rkinds == [k] && e.eff == [.name l (.rvar 0)] &&
        match e.params[p]? with
        | some (.opaque o (.rvar 0)) => T.valKind o == some k
        | _ => false

/-- 旧の形の項目は、旧 `io_op` の内容（`opEff = some l`・効果は名前だけ・`neffs = 0`・一覧への所属）を満たす。 -/
theorem shapeOk_old {T : Table} {b : String} {e : Entry} (h : shapeOk T b e = true)
    (hs : ∀ k p, e.shape ≠ .single k p) :
    ∃ l, e.opEff = some l ∧ e.eff = [Atom.ofOld l] ∧ e.neffs = 0 ∧ e.rkinds = [] ∧ opListed T l b = true := by
  unfold shapeOk at h
  cases hl : e.opEff with
  | none => simp [hl] at h
  | some l =>
    rw [hl] at h
    cases hsh : e.shape with
    | untargeted =>
      simp only [hsh, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨h1, h2⟩, ⟨-, h4⟩, h5⟩ := h
      exact ⟨l, rfl, h5, h2, h4, h1⟩
    | topTargeted k =>
      simp only [hsh, Bool.and_eq_true, beq_iff_eq] at h
      obtain ⟨⟨h1, h2⟩, ⟨-, h4⟩, h5⟩ := h
      exact ⟨l, rfl, h5, h2, h4, h1⟩
    | single k p => exact absurd hsh (hs k p)

/-- 新しい単一の対象の項目から得る事実。 -/
theorem shapeOk_single {T : Table} {b : String} {e : Entry} {k : Kind} {p : Nat}
    (h : shapeOk T b e = true) (hs : e.shape = .single k p) :
    ∃ l o, e.opEff = some l ∧ e.eff = [.name l (.rvar 0)] ∧ e.neffs = 0 ∧ e.rkinds = [k] ∧
      opListed T l b = true ∧ T.effKind l = some k ∧ e.params[p]? = some (.opaque o (.rvar 0)) ∧
      T.valKind o = some k := by
  unfold shapeOk at h
  cases hl : e.opEff with
  | none => simp [hl] at h
  | some l =>
    rw [hl, hs] at h
    simp only [Bool.and_eq_true, beq_iff_eq] at h
    obtain ⟨⟨h1, h2⟩, ⟨⟨h3, h4⟩, h5⟩, h6⟩ := h
    split at h6
    · next o hp => exact ⟨l, o, rfl, h5, h2, h4, h1, h3, hp, by simpa using h6⟩
    · simp at h6

/-- Top の対応: 新しい単一の対象の項目を Top で具体化した効果は、旧の名前だけの効果と同じである。 -/
theorem single_inst_top_eff {T : Table} {b : String} {e : Entry} {k : Kind} {p : Nat}
    (h : shapeOk T b e = true) (hs : e.shape = .single k p) :
    ∃ l, e.opEff = some l ∧ (e.inst [.top]).eff = [Atom.ofOld l] := by
  obtain ⟨l, _, hl, he, -⟩ := shapeOk_single h hs
  exact ⟨l, hl, by simp [Entry.inst, he, Atom.inst, Ix.inst, Atom.ofOld]⟩

/-- 非 Top の具体化: 入力の添字と効果の原子が同じ R を指す。 -/
theorem single_inst_same_range {T : Table} {b : String} {e : Entry} {k : Kind} {p : Nat}
    (h : shapeOk T b e = true) (hs : e.shape = .single k p) (R : Range) :
    ∃ l o, (e.inst [R]).eff = [.name l (.fixed R)] ∧ (e.inst [R]).params[p]? = some (.opaque o (.fixed R)) ∧
      T.valKind o = some k := by
  obtain ⟨l, o, -, he, -, -, -, -, hp, hk⟩ := shapeOk_single h hs
  refine ⟨l, o, by simp [Entry.inst, he, Atom.inst, Ix.inst], ?_, hk⟩
  simp [Entry.inst, hp, VTy.inst, Ix.inst]

/-! ## 信頼条件の分け方 -/

def Val.target? : Val → Option Target
  | .checked t => some t
  | _ => none

/-- 旧の条件（量化を範囲の具体化へ広げた形）。主定理（進行・保存・効果の健全性）はこちらだけに依存する。 -/
structure CoreAssumptions (T : Table) : Prop where
  delta_typed : ∀ b e rs ws, T.sig b = some e → e.kind = .pure → RangeAdmissible T b e rs →
    HasTypeVs T.valKind ws (e.inst rs).params →
    ∃ v, T.delta b rs ws = some v ∧ HasTypeV T.valKind v (e.inst rs).ret
  io_typed : ∀ b e rs ws v obs, T.sig b = some e → e.kind ≠ .pure → RangeAdmissible T b e rs →
    HasTypeVs T.valKind ws (e.inst rs).params → T.ioResponse b rs ws v obs →
    HasTypeV T.valKind v (e.inst rs).ret
  io_exists : ∀ b e rs ws, T.sig b = some e → e.kind ≠ .pure → RangeAdmissible T b e rs →
    HasTypeVs T.valKind ws (e.inst rs).params → ∃ v obs, T.ioResponse b rs ws v obs
  /-- 内容を変えた `io_op`。形の検査を通る。 -/
  io_op : ∀ b e, T.sig b = some e → e.kind ≠ .pure → shapeOk T b e = true

/-- 計画済みの新しい信頼条件。具体化した署名と型の付いた引数について、実装が報告する対象が形の条件を満たす。
入力が範囲に属することは仮定しない（値の型付けから示す）。 -/
structure TargetAgreement (T : Table) : Prop where
  io_target : ∀ b e rs ws v obs, T.sig b = some e → e.kind ≠ .pure → RangeAdmissible T b e rs →
    HasTypeVs T.valKind ws (e.inst rs).params → T.ioResponse b rs ws v obs → ShapeTargets Val.target? e.shape ws obs

/-- 全体の仮定は二つを明示して含む。 -/
structure Assumptions (T : Table) : Prop where
  core : CoreAssumptions T
  target : TargetAgreement T

/-- 効果の上限が名前 l の操作の対象を許す: l の対象の種類 k について、同じ名前の閉じた原子の範囲に、種類に
相対的に対象が属する（Top は種類 k の全対象を覆い、他の種類を覆わない。RV-L00 中2）。 -/
def EffAllows (K : String → Option Kind) (eff : List Atom) (l : String) (t : Target) : Prop :=
  ∃ k R, K l = some k ∧ Atom.name l (.fixed R) ∈ eff ∧ R.MemK k t

/-- 一段の対象の健全性（モデル）。観測した全ての対象は、具体化した署名の効果の同じ名前の原子に属する。
所属は値の型付けから、同じ対象であることは `io_target` から、上限への所属は両者から導く。 -/
theorem target_sound {T : Table} (hA : Assumptions T) {b : String} {e : Entry} {rs : List Range}
    {ws : List Val} {v : Val} {obs : List Target}
    (hb : T.sig b = some e) (hk : e.kind ≠ .pure) (hR : RangeAdmissible T b e rs)
    (hw : HasTypeVs T.valKind ws (e.inst rs).params) (hr : T.ioResponse b rs ws v obs) :
    ∃ l, e.opEff = some l ∧ ∀ t ∈ obs, EffAllows T.effKind (e.inst rs).eff l t := by
  have hshape := hA.core.io_op b e hb hk
  have htgt := hA.target.io_target b e rs ws v obs hb hk hR hw hr
  cases hs : e.shape with
  | single k p =>
    obtain ⟨l, o, hl, he, -, hn, -, hek, hp, hko⟩ := shapeOk_single hshape hs
    refine ⟨l, hl, ?_⟩
    obtain ⟨R, rfl⟩ : ∃ R, rs = [R] := by
      have hlen := hR.length; rw [hn] at hlen
      match rs, hlen with
      | [R], _ => exact ⟨R, rfl⟩
    rw [hs] at htgt
    have hpi : (e.inst [R]).params[p]? = some (.opaque o (.fixed R)) := by
      simp [Entry.inst, hp, VTy.inst, Ix.inst]
    obtain ⟨w, hwp, hwt⟩ := hw.getElem? hpi
    have hmem := ShapeTargets.single_memK (R := R) htgt (fun t ht => by
      rw [hwp] at ht
      cases w with
      | checked t0 =>
        simp only [Option.bind_some, Val.target?, Option.some.injEq] at ht
        subst ht
        refine ⟨?_, hwt.2⟩
        have h1 := hwt.1
        rw [hko] at h1
        exact (Option.some.inj h1).symm
      | _ => simp [Val.target?] at ht)
    intro t ht
    exact ⟨k, R, hek, by simp [Entry.inst, he, Atom.inst, Ix.inst], hmem t ht⟩
  | untargeted =>
    obtain ⟨l, hl, -⟩ := shapeOk_old hshape (by intro k p h; rw [hs] at h; cases h)
    refine ⟨l, hl, ?_⟩
    rw [hs] at htgt
    rw [ShapeTargets.untargeted_nil htgt]
    simp
  | topTargeted k =>
    obtain ⟨l, hl, he, -⟩ := shapeOk_old hshape (by intro k p h; rw [hs] at h; cases h)
    have hek : T.effKind l = some k := by
      unfold shapeOk at hshape
      simp only [hl, hs, Bool.and_eq_true, beq_iff_eq] at hshape
      exact hshape.2.1.1
    rw [hs] at htgt
    refine ⟨l, hl, fun t ht => ⟨k, .top, hek, ?_, ShapeTargets.topTargeted_memK htgt t ht⟩⟩
    simp [Entry.inst, he, Atom.ofOld, Atom.inst, Ix.inst, Ix.top]

/-- 応答の型は旧の条件だけで得られる（主定理が `TargetAgreement` に依存しないことのモデル）。 -/
theorem io_response_typed {T : Table} (hC : CoreAssumptions T) {b : String} {e : Entry} {rs : List Range}
    {ws : List Val} {v : Val} {obs : List Target}
    (hb : T.sig b = some e) (hk : e.kind ≠ .pure) (hR : RangeAdmissible T b e rs)
    (hw : HasTypeVs T.valKind ws (e.inst rs).params) (hr : T.ioResponse b rs ws v obs) :
    HasTypeV T.valKind v (e.inst rs).ret :=
  hC.io_typed b e rs ws v obs hb hk hR hw hr

/-! ## 申し送り 1: 既存の欄の量化の比較 -/

/-- 範囲の具体化へ量化を広げた欄の形。`P` は欄の本体（`delta_typed` などの結論）。 -/
def FieldNew (T : Table) (P : String → Entry → List Range → Entry → Prop) : Prop :=
  ∀ b e, T.sig b = some e → ∀ rs, RangeAdmissible T b e rs → P b e rs (e.inst rs)

/-- 旧の欄の形（範囲の具体化なし）。 -/
def FieldOld (T : Table) (P : String → Entry → List Range → Entry → Prop) : Prop :=
  ∀ b e, T.sig b = some e → P b e [] e

/-- 全ての項目が範囲の変数を持たない表では、量化を広げた欄は旧の欄と同値である。量化の変更が意味を
変えるのは、範囲の変数を持つ項目（新しい項目）についてだけである。 -/
theorem fieldNew_iff_old {T : Table} {P : String → Entry → List Range → Entry → Prop}
    (hold : ∀ b e, T.sig b = some e → e.rkinds = [] ∧ T.admitsR b []) :
    FieldNew T P ↔ FieldOld T P := by
  constructor
  · intro h b e hb
    have hR : RangeAdmissible T b e [] := by
      unfold RangeAdmissible; rw [(hold b e hb).1]
      exact Signature.RangeAdmissible.nil_iff.mpr ⟨rfl, (hold b e hb).2⟩
    simpa using h b e hb [] hR
  · intro h b e hb rs hR
    unfold RangeAdmissible at hR; rw [(hold b e hb).1] at hR
    obtain ⟨rfl, -⟩ := Signature.RangeAdmissible.nil_iff.mp hR
    simpa using h b e hb

/-- 欄は項目ごとの条件の連言なので、表へ項目を加えた表の欄は、元の表の欄と加えた項目の条件に分かれる。 -/
theorem fieldNew_extend {T T' : Table} {P : String → Entry → List Range → Entry → Prop} {b0 : String} {e0 : Entry}
    (hsig : ∀ b, T'.sig b = if b = b0 then some e0 else T.sig b)
    (hadm : ∀ b, b ≠ b0 → T'.admitsR b = T.admitsR b) (hfresh : T.sig b0 = none) :
    FieldNew T' P ↔ FieldNew T P ∧ ∀ rs, RangeAdmissible T' b0 e0 rs → P b0 e0 rs (e0.inst rs) := by
  constructor
  · intro h
    refine ⟨fun b e hb rs hR => ?_, fun rs hR => h b0 e0 (by simp [hsig]) rs hR⟩
    have hne : b ≠ b0 := by rintro rfl; simp [hfresh] at hb
    exact h b e (by simp [hsig, hne, hb]) rs ⟨hR.1, hR.2.1, by rw [hadm b hne]; exact hR.2.2⟩
  · rintro ⟨h, h0⟩ b e hb rs hR
    by_cases hbe : b = b0
    · subst hbe; simp [hsig] at hb; subst hb; exact h0 rs hR
    · simp [hsig, hbe] at hb
      exact h b e hb rs ⟨hR.1, hR.2.1, by rw [← hadm b hbe]; exact hR.2.2⟩

/-! ## 申し送り 4: 捕捉した操作の節の添字 S -/

/-- 節の添字 S。保護本体の効果に同名の閉じた原子がちょうど一つあればその範囲、それ以外（複数、同名の
Top、行変数、同名なし）は Top（判断 11）。節の本体や期待される出力から逆算しない。 -/
def clauseIndex (l : String) (bodyEff : List Atom) : Range :=
  if bodyEff.any (fun a => match a with | .rho _ => true | _ => false) then .top
  else
    match bodyEff.filter (fun a => match a with | .name m _ => m == l | .rho _ => false) with
    | [.name _ (.fixed s)] => s
    | _ => .top

/-- 節の引数の型付け: 保護本体で行った操作の値が R に属し、本体の効果の同名の原子が R を意味で覆えば、
その値は節の添字 S の型を持つ。値の型付けと範囲の包含だけを使い、新しい信頼条件を要しない。 -/
theorem clause_arg_typed {K : String → Option Kind} {v : Val} {o l : String} {k : Kind} {R : Range}
    {bodyEff : List Atom} (hk : K o = some k) (hv : HasTypeV K v (.opaque o (.fixed R)))
    (hcov : ∃ s', Atom.name l (.fixed s') ∈ bodyEff ∧ Range.Sub R s') :
    HasTypeV K v (.opaque o (.fixed (clauseIndex l bodyEff))) := by
  have htop : HasTypeV K v (.opaque o (.fixed .top)) := hv.widen hk (fun _ _ => trivial)
  unfold clauseIndex
  split
  · exact htop
  · split
    · next s hf =>
      obtain ⟨s', hs', hsub⟩ := hcov
      have hmem : Atom.name l (.fixed s') ∈ bodyEff.filter
          (fun a => match a with | .name m _ => m == l | .rho _ => false) := by
        simp [List.mem_filter, hs']
      rw [hf] at hmem
      simp at hmem
      obtain ⟨-, rfl⟩ := hmem
      exact hv.widen hk hsub
    · exact htop

/-! ## 例の表: 純粋な検査・明示拡大・射影・七つの IO・旧の操作 -/

def pathInName : String := "Scope.PathIn"
def requestInName : String := "Http.RequestIn"

def pathIn (ix : Ix) : VTy := .opaque pathInName ix
def requestIn (ix : Ix) : VTy := .opaque requestInName ix

/-- 誤り型の構成子は DET-04 の未決。モデルでは誤りの値を `unit` で表す。 -/
def errTy : VTy := .unit

/-- 範囲付きのファイルの IO の項目。対象の位置は 0。 -/
def fileIn (l : String) (names : List String) (extra : List VTy) (ret : VTy) : Entry :=
  { names := "path" :: names, params := pathIn (.rvar 0) :: extra, ret := .result ret errTy,
    eff := [.name l (.rvar 0)], kind := .io, opEff := some l, shape := .single .path 0, rkinds := [.path] }

def readTextIn : Entry := fileIn "File.Read" [] [] .string
def readBytesIn : Entry := fileIn "File.Read" [] [] .bytes
def writeTextIn : Entry := fileIn "File.Write" ["text"] [.string] .unit
def appendTextIn : Entry := fileIn "File.Write" ["text"] [.string] .unit
def writeBytesIn : Entry := fileIn "File.Write" ["content"] [.bytes] .unit
def appendBytesIn : Entry := fileIn "File.Write" ["content"] [.bytes] .unit

def sendIn : Entry :=
  { names := ["request"], params := [requestIn (.rvar 0)], ret := .result .response errTy,
    eff := [.name "Http.Connect" (.rvar 0)], kind := .io, opEff := some "Http.Connect",
    shape := .single .endpoint 0, rkinds := [.endpoint] }

/-- 旧の文字列の書き込み（旧の対象あり、Top）。 -/
def writeText : Entry :=
  { names := ["path", "text"], params := [.string, .string], ret := .result .unit errTy,
    eff := [Atom.ofOld "File.Write"], kind := .io, opEff := some "File.Write", shape := .topTargeted .path }

/-- 旧の対象なしの IO。 -/
def printLine : Entry :=
  { names := ["text"], params := [.string], ret := .unit,
    eff := [Atom.ofOld "Console"], kind := .io, opEff := some "Console", shape := .untargeted }

/-- 純粋な検査。入力は文字列、結果は範囲付きの値型。範囲は呼び出しが具体化する。 -/
def checkPathIn : Entry :=
  { names := ["pattern", "path"], params := [.string, .string], ret := .result (pathIn (.rvar 0)) errTy,
    eff := [], kind := .pure, opEff := none, shape := .untargeted, rkinds := [.path] }

/-- 明示拡大。入力の添字 R（変数 0）と結果の添字 S（変数 1）。被覆は `admitsR` が求める。 -/
def widenPathIn : Entry :=
  { names := ["path"], params := [pathIn (.rvar 0)], ret := pathIn (.rvar 1),
    eff := [], kind := .pure, opEff := none, shape := .untargeted, rkinds := [.path, .path] }

/-- 射影。結果は普通の文字列。 -/
def pathInValue : Entry :=
  { names := ["path"], params := [pathIn (.rvar 0)], ret := .string,
    eff := [], kind := .pure, opEff := none, shape := .untargeted, rkinds := [.path] }

/-- 表の項目の追加だけで新しい入口を加えた例の表。δ と応答はモデルでは与えない（形の検査と具体化の例に使う）。 -/
def exampleTable : Table where
  sig
    | "Console.printLine" => some printLine
    | "File.writeText" => some writeText
    | "File.readTextIn" => some readTextIn
    | "File.readBytesIn" => some readBytesIn
    | "File.writeTextIn" => some writeTextIn
    | "File.appendTextIn" => some appendTextIn
    | "File.writeBytesIn" => some writeBytesIn
    | "File.appendBytesIn" => some appendBytesIn
    | "Http.sendIn" => some sendIn
    | "Scope.checkPathIn" => some checkPathIn
    | "Scope.widenPathIn" => some widenPathIn
    | "Scope.pathInValue" => some pathInValue
    | _ => none
  effects
    | "Console" => some ["Console.printLine"]
    | "File.Read" => some ["File.readText", "File.readTextIn", "File.readBytesIn"]
    | "File.Write" => some ["File.writeText", "File.writeTextIn", "File.appendTextIn",
        "File.writeBytesIn", "File.appendBytesIn"]
    | "Http.Connect" => some ["Http.send", "Http.sendIn"]
    | _ => none
  effKind
    | "File.Read" | "File.Write" => some .path
    | "Http.Connect" => some .endpoint
    | _ => none
  valKind
    | "Scope.PathIn" => some .path
    | "Http.RequestIn" => some .endpoint
    | _ => none
  isResource
    | "File.Reader" | "File.Writer" => true
    | _ => false
  admitsR
    | "Scope.widenPathIn", rs => ∃ r s, rs = [r, s] ∧ Range.Sub r s
    | _, _ => True
  delta _ _ _ := none
  ioResponse _ _ _ _ _ := False

-- 七つの IO と旧の二つの IO は、形の検査を通る。
#guard shapeOk exampleTable "File.readTextIn" readTextIn
#guard shapeOk exampleTable "File.readBytesIn" readBytesIn
#guard shapeOk exampleTable "File.writeTextIn" writeTextIn
#guard shapeOk exampleTable "File.appendTextIn" appendTextIn
#guard shapeOk exampleTable "File.writeBytesIn" writeBytesIn
#guard shapeOk exampleTable "File.appendBytesIn" appendBytesIn
#guard shapeOk exampleTable "Http.sendIn" sendIn
#guard shapeOk exampleTable "File.writeText" writeText
#guard shapeOk exampleTable "Console.printLine" printLine
-- 誤った形は通らない: 効果の範囲が入力の添字と別、対象のある操作を対象なしとして登録、
-- 一覧にない名前、入力の添字の種類が効果の種類と違う。
#guard !shapeOk exampleTable "File.writeTextIn" { writeTextIn with eff := [Atom.ofOld "File.Write"] }
#guard !shapeOk exampleTable "File.writeText" { writeText with shape := .untargeted }
#guard !shapeOk exampleTable "File.writeTextX" writeTextIn
#guard !shapeOk exampleTable "File.writeTextIn" { writeTextIn with params := [requestIn (.rvar 0), .string] }
#guard !shapeOk exampleTable "File.writeTextIn" { writeTextIn with neffs := 1 }

def dataTree : Range := .path (.tree ["data"])
def dataA : Range := .path (.exact ["data", "a.txt"])

-- 非 Top の具体化。入力の添字と効果の原子が同じ R を指し、名前と opEff は変わらない。
#guard (writeTextIn.inst [dataTree]).params == [pathIn (.fixed dataTree), .string]
#guard (writeTextIn.inst [dataTree]).eff == [.name "File.Write" (.fixed dataTree)]
#guard (sendIn.inst [.top]).eff == [Atom.ofOld "Http.Connect"]
#guard (widenPathIn.inst [dataA, dataTree]).params == [pathIn (.fixed dataA)]
#guard (widenPathIn.inst [dataA, dataTree]).ret == pathIn (.fixed dataTree)
-- 長さの足りない具体化は変数を残し、黙って Top にしない。
#guard (writeTextIn.inst []).eff == [.name "File.Write" (.rvar 0)]
-- 節の添字。
#guard clauseIndex "File.Write" [.name "File.Write" (.fixed dataTree)] == dataTree
#guard clauseIndex "File.Write" [.name "File.Write" (.fixed dataTree), .name "File.Write" (.fixed dataA)] == .top
#guard clauseIndex "File.Write" [.name "File.Write" (.fixed dataTree), .rho 0] == .top
#guard clauseIndex "File.Write" [.name "File.Read" (.fixed dataTree)] == .top
-- 資源の判定は Top の添字だけ。
#guard exampleTable.isResourceTy (.opaque "File.Reader" Ix.top)
#guard !exampleTable.isResourceTy (.opaque "File.Reader" (.fixed dataTree))

/-! ## 小補題: 非 Top の署名の例と Top の対応 -/

theorem writeTextIn_shapeOk : shapeOk exampleTable "File.writeTextIn" writeTextIn = true := by decide

theorem writeTextIn_inst_nonTop :
    (writeTextIn.inst [dataTree]).eff = [.name "File.Write" (.fixed dataTree)] ∧
      (writeTextIn.inst [dataTree]).params = [pathIn (.fixed dataTree), .string] := ⟨rfl, rfl⟩

/-- Top で具体化した新しい書き込みの効果は、旧の書き込みの効果と同じ原子である。 -/
theorem writeTextIn_inst_top_eq_old : (writeTextIn.inst [.top]).eff = writeText.eff := rfl

/-- 範囲を変えても表の鍵と操作の一覧は一つのまま（範囲の数だけ操作 ID を発行しない）。 -/
theorem writeTextIn_key_independent (R S : Range) :
    (writeTextIn.inst [R]).opEff = (writeTextIn.inst [S]).opEff ∧
      (writeTextIn.inst [R]).names = (writeTextIn.inst [S]).names := ⟨rfl, rfl⟩

theorem dataA_mem : dataA.Mem (.path ["data", "a.txt"]) := rfl

theorem dataA_sub_dataTree : Range.Sub dataA dataTree := by
  intro t ht
  cases t with
  | path w =>
    simp only [dataA, Range.Mem, PathPattern.Matches] at ht
    subst ht
    exact ⟨["a.txt"], rfl⟩
  | host _ => exact ht.elim
  | endpoint _ => exact ht.elim

/-- 非 Top の値の明示拡大: `/data/a.txt` の値は `/data/**` の型を持つ。 -/
theorem widen_example :
    HasTypeV exampleTable.valKind (.checked (.path ["data", "a.txt"])) (pathIn (.fixed dataTree)) :=
  HasTypeV.widen (k := .path) rfl ⟨rfl, dataA_mem⟩ dataA_sub_dataTree

/-- 範囲付きの値型は資源にならない（申し送り 3）。 -/
theorem isResourceTy_indexed (T : Table) (o : String) (R : Range) (hR : R ≠ .top) :
    T.isResourceTy (.opaque o (.fixed R)) = false := by
  cases R with
  | top => exact absurd rfl hR
  | _ => rfl

/-- 種類の違う範囲では具体化を許さない。表の制約 `admitsR` を自明にしても、範囲の変数の種類で断る（RV-L00 軽7）。 -/
theorem writeTextIn_not_endpoint (T : Table) (b : String) (e : EndpointPattern) :
    ¬ RangeAdmissible T b writeTextIn [.endpoint e] := by
  intro h
  have := h.fits (i := 0) rfl rfl
  simp [Range.FitsKind, Range.kind?] at this

/-! ## 純粋な検査と明示拡大が `delta_typed` の欄を満たす例 -/

/-- 検査の δ の例。パターンと対象の解析は形式化の外側（`parsePat`・`parseTarget`）。成功は種類の一致と、
動的なパターンと具体化した R の両方への所属を確かめたときだけ。 -/
def checkPathDelta (parsePat : String → Option Range) (parseTarget : String → Option Target) :
    List Range → List Val → Option Val
  | [r], [.str pat, .str raw] =>
      some <| match parsePat pat, parseTarget raw with
        | some q, some t => if t.kind = .path ∧ q.Mem t ∧ r.Mem t then .ok (.checked t) else .err .unit
        | _, _ => .err .unit
  | _, _ => none

theorem checkPathIn_delta_typed (parsePat : String → Option Range) (parseTarget : String → Option Target)
    (rs : List Range) (ws : List Val) (hlen : rs.length = checkPathIn.nranges)
    (hw : HasTypeVs exampleTable.valKind ws (checkPathIn.inst rs).params) :
    ∃ v, checkPathDelta parsePat parseTarget rs ws = some v ∧
      HasTypeV exampleTable.valKind v (checkPathIn.inst rs).ret := by
  match rs, hlen with
  | [r], _ =>
    simp only [checkPathIn, Entry.inst, List.map, VTy.inst] at hw ⊢
    cases hw with
    | cons h1 hw =>
      cases hw with
      | cons h2 hw =>
        cases hw
        rename_i w1 w2
        cases w1 <;> simp [HasTypeV] at h1
        cases w2 <;> simp [HasTypeV] at h2
        refine ⟨_, rfl, ?_⟩
        split
        · next q t _ _ =>
          split
          · next hc =>
            exact ⟨by simp [exampleTable, pathInName, hc.1], by simpa [Ix.inst] using hc.2.2⟩
          · trivial
        · trivial

/-- 明示拡大の δ の例。同じ値を返す。 -/
def widenDelta : List Range → List Val → Option Val
  | [_, _], [v] => some v
  | _, _ => none

theorem widenPathIn_delta_typed (rs : List Range) (ws : List Val)
    (hR : RangeAdmissible exampleTable "Scope.widenPathIn" widenPathIn rs)
    (hw : HasTypeVs exampleTable.valKind ws (widenPathIn.inst rs).params) :
    ∃ v, widenDelta rs ws = some v ∧ HasTypeV exampleTable.valKind v (widenPathIn.inst rs).ret := by
  obtain ⟨r, s, rfl, hsub⟩ : ∃ r s, rs = [r, s] ∧ Range.Sub r s := hR.admits_of
  simp only [widenPathIn, Entry.inst, List.map, VTy.inst, pathIn, Ix.inst] at hw ⊢
  cases hw with
  | cons h1 hw =>
    cases hw
    exact ⟨_, rfl, HasTypeV.widen (k := .path) rfl (by simpa using h1) hsub⟩

end Benitoite.Scope.SignatureExamples
