import Benitoite.Release.Lemmas.ContLemmas
import Benitoite.Release.TargetTable

/-!
# 節の添字の規則（L30.1）

捕捉した組み込みの操作の節は、操作の型を節の添字 S で具体化して型付ける（`opSigAt`）。S は保護本体の効果から
判断 11 の規則で選ぶ（`Eff.clauseRange`）。同名の閉じた原子がちょうど一つだけあればその範囲、複数の原子・同名の
Top・未確定の行の変数・同名の原子なしの場合は Top である。型付けは規則の値と Top を許す（`ClauseIxOk`。理由は
`ClauseSig.substAt`）。`handle` の枠の穴の効果は保護本体の効果のまま継続の型に残る（`ContTy.K_Handle`）。
保存の証明は、呼び出しの効果の名前の原子が穴の効果に届くこと（`ContTy.split`）から、S が Top でないとき呼び出しの
範囲の列が S の列に一致することを導く（`pres_op_common` の呼び出し側。設計書 01-12「ハンドラ」）。

本モジュールは、規則の性質、旧の像（範囲の変数を持たない表）での新旧の同値、具体の例を置く。
-/

namespace Benitoite.Release

open Scope.Domain (Range)

variable {P : Program} {B : Builtins}

/-! ## 規則の値 -/

/-- 規則の条件を満たす範囲は一つだけである。 -/
theorem Eff.ClauseRangeIs.unique {e : Eff} {l : EffName} {r r' : Range}
    (h : e.ClauseRangeIs l r) (h' : e.ClauseRangeIs l r') : r = r' := by
  have := h.2.2 _ h'.2.1
  cases this
  rfl

/-- 規則の条件を満たす範囲があれば、規則の値はその範囲である。 -/
theorem Eff.clauseRange_of {e : Eff} {l : EffName} {r : Range} (h : e.ClauseRangeIs l r) :
    e.clauseRange l = r := by
  have hex : ∃ r, e.ClauseRangeIs l r := ⟨r, h⟩
  unfold Eff.clauseRange
  split
  · next hex' => exact (Classical.choose_spec hex').unique h
  · contradiction

/-- 規則の値は、条件を満たす範囲か、条件を満たす範囲がないときの Top である。 -/
theorem Eff.clauseRange_spec (e : Eff) (l : EffName) :
    e.ClauseRangeIs l (e.clauseRange l) ∨ (e.clauseRange l = .top ∧ ∀ r, ¬ e.ClauseRangeIs l r) := by
  unfold Eff.clauseRange
  split
  · next hex => exact Or.inl (Classical.choose_spec hex)
  · next hex => exact Or.inr ⟨rfl, fun r hr => hex ⟨r, hr⟩⟩

/-- 条件を満たす範囲がなければ、規則の値は Top である。 -/
theorem Eff.clauseRange_of_not {e : Eff} {l : EffName} (h : ∀ r, ¬ e.ClauseRangeIs l r) :
    e.clauseRange l = .top := by
  rcases e.clauseRange_spec l with h' | ⟨h', -⟩
  · exact absurd h' (h _)
  · exact h'

/-- 未確定の行の変数を持つ保護本体の効果では、規則の値は Top である。 -/
theorem Eff.clauseRange_of_rho {e : Eff} {l : EffName} {i : Nat} (h : Eff.mem e (.rho i)) :
    e.clauseRange l = .top :=
  Eff.clauseRange_of_not fun _ hr => hr.1 i h

/-- 名前 l の原子を二つ（範囲の位置が違う）持つ保護本体の効果では、規則の値は Top である。 -/
theorem Eff.clauseRange_of_two {e : Eff} {l : EffName} {ix ix' : Scope.Signature.Ix}
    (h1 : Eff.mem e (.name l ix)) (h2 : Eff.mem e (.name l ix')) (hne : ix ≠ ix') :
    e.clauseRange l = .top :=
  Eff.clauseRange_of_not fun _ hr => hne ((hr.2.2 _ h1).trans (hr.2.2 _ h2).symm)

/-- 名前 l の原子を持たない保護本体の効果では、規則の値は Top である。 -/
theorem Eff.clauseRange_of_none {e : Eff} {l : EffName} (h : ∀ ix, ¬ Eff.mem e (.name l ix)) :
    e.clauseRange l = .top :=
  Eff.clauseRange_of_not fun _ hr => h _ hr.2.1

/-- 名前 l の Top の原子を持つ保護本体の効果では、規則の値は Top である。 -/
theorem Eff.clauseRange_of_top {e : Eff} {l : EffName} (h : Eff.mem e (.nameTop l)) :
    e.clauseRange l = .top := by
  rcases e.clauseRange_spec l with h' | ⟨h', -⟩
  · exact (Scope.Signature.Ix.fixed.inj (h'.2.2 _ h)).symm
  · exact h'

/-- 規則の値は節の添字として許される。 -/
theorem ClauseIxOk.rule {e : Eff} {b : PrimName} {s : PrimSig} {l : EffName}
    (hs : B.sig b = some s) (hl : s.opEff = some l) : ClauseIxOk B e (.prim b) (e.clauseRange l) := by
  rcases e.clauseRange_spec l with h | ⟨h, -⟩
  · exact Or.inr ⟨b, s, l, rfl, hs, hl, h⟩
  · exact Or.inl h

/-- 組み込みの操作の節の添字として許されるのは、Top と規則の値だけである。 -/
theorem ClauseIxOk.iff {e : Eff} {b : PrimName} {s : PrimSig} {l : EffName} {S : Range}
    (hs : B.sig b = some s) (hl : s.opEff = some l) :
    ClauseIxOk B e (.prim b) S ↔ S = .top ∨ S = e.clauseRange l := by
  constructor
  · rintro (h | ⟨b', s', l', hb, hs', hl', hr⟩)
    · exact Or.inl h
    · cases hb
      rw [hs] at hs'; cases hs'
      rw [hl] at hl'; cases hl'
      exact Or.inr (Eff.clauseRange_of hr).symm
  · rintro (rfl | rfl)
    · exact Or.inl rfl
    · exact ClauseIxOk.rule hs hl

/-- 行の変数を持つ保護本体の効果では、許される節の添字は Top だけである。 -/
theorem ClauseIxOk.top_of_rho {e : Eff} {o : OpRef} {S : Range} {i : Nat} (h : ClauseIxOk B e o S)
    (hi : Eff.mem e (.rho i)) : S = .top := by
  rcases h with h | ⟨_, _, _, _, _, _, hr⟩
  · exact h
  · exact absurd hi (hr.1 i)

/-! ## 旧の像での同値

範囲の変数を持たない表（旧の像。全ての項目で `nranges = 0`）では、節の操作の型は節の添字によらず `opSig` であり、
節の型付けは保護本体の効果によらない。旧の `handle` の枠の型付け（穴の効果が `εc ∪ handled(H)`）は新しい枠の
型付けの特別な場合であり、新しい継続の型付けは、穴の効果を広げて旧の形に戻せる。 -/

/-- 範囲の変数を持たない表では、節の添字によらず `opSigAt` は `opSig` である。 -/
theorem opSigAt_eq_opSig_of_rangeFree (hrf : ∀ b s, B.sig b = some s → s.nranges = 0)
    (S : Range) (o : OpRef) : opSigAt P B S o = opSig P B o := by
  cases o with
  | fail => rfl
  | user o => rfl
  | prim b =>
      cases hb : B.sig b with
      | none => simp [opSigAt, opSig, hb]
      | some s => simp [opSigAt, opSig, hb, PrimSig.topRanges, hrf b s hb]

/-- 範囲の変数を持たない表では、節の操作の型の前提（L30.1）は旧の前提 `opSig P B o = some sg` と同値である。 -/
theorem ClauseSig.iff_opSig_of_rangeFree (hrf : ∀ b s, B.sig b = some s → s.nranges = 0)
    {e : Eff} {o : OpRef} {sg : OpSig} : ClauseSig P B e o sg ↔ opSig P B o = some sg := by
  constructor
  · rintro ⟨S, -, h⟩
    rwa [opSigAt_eq_opSig_of_rangeFree hrf] at h
  · exact ClauseSig.of_opSig

/-- 範囲の変数を持たない表では、節の型付けは保護本体の効果によらない。 -/
theorem HasTypeClausesQ.sel_congr_of_rangeFree (hrf : ∀ b s, B.sig b = some s → s.nranges = 0)
    {Ψ Q C Γ R εb εb' t ε Δl} {cs : List Clause} (h : HasTypeClausesQ P B Ψ Q C Γ R εb cs t ε Δl) :
    HasTypeClausesQ P B Ψ Q C Γ R εb' cs t ε Δl := by
  induction cs with
  | nil => cases h; exact .nil
  | cons c cs ih =>
      cases h with
      | cons hsg hnames hn hk hew hbody hrest =>
          exact .cons ((ClauseSig.iff_opSig_of_rangeFree hrf).mpr ((ClauseSig.iff_opSig_of_rangeFree hrf).mp hsg))
            hnames hn hk hew hbody (ih hrest)

/-- 節の型付けは新しい関係で読む旧の形の継続の型付け。L30.1 の前の `ContTy` の字面どおりの写しではない。
`handle` の枠の穴の効果は L30.1 の前と同じ `εc ∪ handled(H)` であるが、節の型付けは新しい関係 `HasTypeClausesQ`
（節の操作の型を `ClauseSig` で読む）を、選択の効果を穴の効果にして使う。L30.1 の前の字面（節の操作の型を
`opSig P B o = some sg` で読む形）との同値は、範囲の変数のない表で `ClauseSig.iff_opSig_of_rangeFree`・
`HasTypeClausesQ.sel_congr_of_rangeFree` を合成して得るものであり、本定義はその合成を含まない（RV-L30 軽4）。
L30.1 の変更（穴の効果）だけを比べるため、節の効果と枠の下の継続の効果の関係は、新しい `ContTy` と同じ被覆にして
ある（L40.6c。旧の効果では被覆は構造上の包含と同じ。`Eff.covers_iff_sub_of_topAtoms`）。 -/
inductive ContTyOld (P : Program) (B : Builtins) (Ψ : StoreTy) :
    Option Ty → Eff → Cont → Ty → Ty → Eff → Option Ty → Prop
  | K_Empty {R ε a ε0} : Eff.Sub ε ε0 → Ty.WF 0 0 a → ContTyOld P B Ψ R ε [] a a ε0 R
  | K_Let {R ε n k a c b ε0 ε1 Re} :
      HasTypeC P B Ψ [] [some a] R n c ε1 → Ty.WF 0 0 a → Eff.Sub ε1 ε → ContTyOld P B Ψ R ε k c b ε0 Re →
      ContTyOld P B Ψ R ε (.letF n :: k) a b ε0 Re
  | K_Mark {R' ε k a b ε0 Re} :
      ContTyOld P B Ψ R' ε k a b ε0 Re → Ty.WF 0 0 a → ContTyOld P B Ψ (some a) ε (.mark :: k) a b ε0 Re
  | K_Update {R ε l k a b ε0 Re} :
      Ψ l = some (.lazy a) → ContTyOld P B Ψ R ε k a b ε0 Re →
      ContTyOld P B Ψ none ε (.update l :: k) a b ε0 Re
  | K_Release {R ε v o k a b ε0 Re} :
      HasTypeV P B Ψ [] [] v (.opaqueTop o) → B.isResource o = true → Eff.mem ε (.nameTop stateEff) →
      ContTyOld P B Ψ R ε k a b ε0 Re → ContTyOld P B Ψ R ε (.release v :: k) a b ε0 Re
  | K_Handle {R ε εc h k t b ε0 Re} :
      ContTyOld P B Ψ R ε k t b ε0 Re → Eff.Covers ε εc →
      HasTypeClauses P B Ψ.hideBuilders [] [] R (Eff.union εc (handled P B h)) h t εc → Ty.WF 0 0 t →
      ContTyOld P B Ψ R (Eff.union εc (handled P B h)) (.handleF h :: k) t b ε0 Re
  | K_Handle_Fail {R ε ec Rest E h k t b ε0 Re} :
      ContTyOld P B Ψ R ε k t b ε0 Re → Eff.Covers ε Rest → NoFail Qempty Rest →
      HasFailureClause P B Ψ.hideBuilders Qempty [] [] E R h t ec → Eff.Covers ε ec → Ty.WF 0 0 t →
      ContTyOld P B Ψ R (Eff.union (Eff.singleFail E) Rest) (.handleF h :: k) t b ε0 Re
  | K_Drop {R ε κ k a b ε0 Re b' t' ε' R'} :
      Ψ κ = some (.cont b' t' ε' R') → (Eff.mem ε' (.nameTop stateEff) → Eff.mem ε (.nameTop stateEff)) →
      ContTyOld P B Ψ R ε k a b ε0 Re →
      ContTyOld P B Ψ R ε (.drop κ :: k) a b ε0 Re
  | K_Guard {R ε v arms next body k a b ε0 Re ε1} :
      HasTypeC P B Ψ [] [] R (.match v arms) a ε1 → Eff.Sub ε1 ε →
      MatchPrefix v arms next → HasTypeC P B Ψ [] [] R body a ε1 →
      ContTyOld P B Ψ R ε k a b ε0 Re →
      ContTyOld P B Ψ none Eff.empty (.guardF v arms next body :: k) (.base .boolean) b ε0 Re
  | K_Sub {R ε k a a' b ε0 Re} :
      ContTyOld P B Ψ R ε k a' b ε0 Re → Ty.Le a a' → ContTyOld P B Ψ R ε k a b ε0 Re

/-- 旧の継続の型付けは新しい継続の型付けである（旧の K-Handle は穴の効果を `εc ∪ handled(H)` にした新しい
K-Handle）。 -/
theorem ContTyOld.toNew {Ψ R ε k a b ε0 Re} (h : ContTyOld P B Ψ R ε k a b ε0 Re) :
    ContTy P B Ψ R ε k a b ε0 Re := by
  induction h with
  | K_Empty hs hw => exact .K_Empty hs hw
  | K_Let hn hw hs _ ih => exact .K_Let hn hw hs ih
  | K_Mark _ hw ih => exact .K_Mark ih hw
  | K_Update hl _ ih => exact .K_Update hl ih
  | K_Release hv hr hs _ ih => exact .K_Release hv hr hs ih
  | K_Handle _ hs hc hw ih => exact .K_Handle ih hs (Eff.Sub.refl _) hc hw
  | K_Handle_Fail _ hr hn hc he hw ih => exact .K_Handle_Fail ih hr hn hc he hw
  | K_Drop hl hs _ ih => exact .K_Drop hl hs ih
  | K_Guard hm hs hp hb _ ih => exact .K_Guard hm hs hp hb ih
  | K_Sub _ hle ih => exact .K_Sub ih hle

/-- 範囲の変数を持たない表では、新しい継続の型付けは、穴の効果を広げて旧の継続の型付けに戻せる。 -/
theorem ContTy.toOld (hrf : ∀ b s, B.sig b = some s → s.nranges = 0) {Ψ R ε k a b ε0 Re}
    (h : ContTy P B Ψ R ε k a b ε0 Re) : ∃ ε', Eff.Sub ε ε' ∧ ContTyOld P B Ψ R ε' k a b ε0 Re := by
  induction h with
  | K_Empty hs hw => exact ⟨_, Eff.Sub.refl _, .K_Empty hs hw⟩
  | K_Let hn hw hs _ ih =>
      obtain ⟨ε', h1, h2⟩ := ih
      exact ⟨ε', h1, .K_Let hn hw (hs.trans h1) h2⟩
  | K_Mark _ hw ih =>
      obtain ⟨ε', h1, h2⟩ := ih
      exact ⟨ε', h1, .K_Mark h2 hw⟩
  | K_Update hl _ ih =>
      obtain ⟨ε', h1, h2⟩ := ih
      exact ⟨ε', h1, .K_Update hl h2⟩
  | K_Release hv hr hs _ ih =>
      obtain ⟨ε', h1, h2⟩ := ih
      exact ⟨ε', h1, .K_Release hv hr (h1.1 _ hs) h2⟩
  | K_Handle _ hs hbh hc hw ih =>
      obtain ⟨ε', h1, h2⟩ := ih
      exact ⟨_, hbh, .K_Handle h2 (h1.covers.trans hs) (HasTypeClausesQ.sel_congr_of_rangeFree hrf hc) hw⟩
  | K_Handle_Fail _ hr hn hc he hw ih =>
      obtain ⟨ε', h1, h2⟩ := ih
      exact ⟨_, Eff.Sub.refl _, .K_Handle_Fail h2 (h1.covers.trans hr) hn hc (h1.covers.trans he) hw⟩
  | K_Drop hl hs _ ih =>
      obtain ⟨ε', h1, h2⟩ := ih
      exact ⟨ε', h1, .K_Drop hl (fun h' => h1.1 _ (hs h')) h2⟩
  | K_Guard hm hs hp hb _ ih =>
      obtain ⟨ε', h1, h2⟩ := ih
      exact ⟨_, Eff.Sub.refl _, .K_Guard hm (hs.trans h1) hp hb h2⟩
  | K_Sub _ hle ih =>
      obtain ⟨ε', h1, h2⟩ := ih
      exact ⟨ε', h1, .K_Sub h2 hle⟩

/-- 範囲の変数を持たない表では、状態の型付け（`StateTyE`）とストアの継続の型付け（`CellOk`）が使う形
「計算の効果 ε1 を含む穴の効果の継続の型付けがある」は、新旧で同値である。 -/
theorem contTy_exists_iff_old (hrf : ∀ b s, B.sig b = some s → s.nranges = 0) {Ψ R ε1 k a b ε0 Re} :
    (∃ ε, Eff.Sub ε1 ε ∧ ContTy P B Ψ R ε k a b ε0 Re) ↔
      (∃ ε, Eff.Sub ε1 ε ∧ ContTyOld P B Ψ R ε k a b ε0 Re) := by
  constructor
  · rintro ⟨ε, h1, h2⟩
    obtain ⟨ε', h3, h4⟩ := h2.toOld hrf
    exact ⟨ε', h1.trans h3, h4⟩
  · rintro ⟨ε, h1, h2⟩
    exact ⟨ε, h1, h2.toNew⟩

/-! ## 例

L20.7 の表（`TargetTable.builtins`）の `File.writeTextIn`（効果 `File.Write[rvar 0]`、引数 `PathIn[rvar 0]`）で、
保護本体の効果から選ぶ節の添字と節の操作の型を確かめる。 -/

namespace ClauseIxExamples

open TargetTable

variable {delta : PrimName → List Ty → List Eff → List Range → List Val → Option Outcome}
  {ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → List Scope.Domain.Target → Prop}

/-- `/data/**`。 -/
def dataR : Range := .path (.tree ["data"])
/-- `/logs/**`。 -/
def logsR : Range := .path (.tree ["logs"])

/-- 保護本体の効果 `{File.Write[/data/**]}`。 -/
def bodyData : Eff := Eff.singleAt "File.Write" (.fixed dataR)

theorem sig_writeTextIn : (builtins delta ioResponse).sig "File.writeTextIn" = some writeTextIn := rfl

theorem bodyData_rule : bodyData.ClauseRangeIs "File.Write" dataR := by
  refine ⟨fun i h => ?_, (Eff.mem_singleAt _ _ _).mpr rfl, fun ix h => ?_⟩
  · rw [bodyData, Eff.mem_singleAt] at h; cases h
  · rw [bodyData, Eff.mem_singleAt] at h; cases h; rfl

/-- 同名の閉じた原子が一つだけなので、節の添字は `/data/**` である。 -/
example : bodyData.clauseRange "File.Write" = dataR := Eff.clauseRange_of bodyData_rule

/-- 二つの範囲の原子（`/data/**` と `/logs/**`）を持つ効果では Top である。 -/
example : (Eff.union bodyData (Eff.singleAt "File.Write" (.fixed logsR))).clauseRange "File.Write" = .top :=
  Eff.clauseRange_of_two (ix := .fixed dataR) (ix' := .fixed logsR)
    ((Eff.mem_union _ _ _).mpr (Or.inl ((Eff.mem_singleAt _ _ _).mpr rfl)))
    ((Eff.mem_union _ _ _).mpr (Or.inr ((Eff.mem_singleAt _ _ _).mpr rfl))) (by decide)

/-- 行の変数を持つ効果では Top である。 -/
example : (Eff.union bodyData (Eff.row 0)).clauseRange "File.Write" = .top :=
  Eff.clauseRange_of_rho (i := 0) ((Eff.mem_union _ _ _).mpr (Or.inr ((Eff.mem_row _ _).mpr rfl)))

/-- 同名の Top の原子（旧の `File.Write`）だけを持つ効果では Top である。 -/
example : (Eff.single "File.Write").clauseRange "File.Write" = .top :=
  Eff.clauseRange_of_top ((Eff.mem_single _ _).mpr rfl)

/-- 同名の原子を持たない効果では Top である。 -/
example : (Eff.singleAt "File.Read" (.fixed dataR)).clauseRange "File.Write" = .top :=
  Eff.clauseRange_of_none fun ix h => by rw [Eff.mem_singleAt] at h; simp at h

/-- 保護本体の効果が `{File.Write[/data/**]}` のとき、`File.writeTextIn` の節の操作の型の引数は
`[PathIn["/data/**"], String]` である（節の添字が Top でない節の型付け）。 -/
theorem clauseSig_data {P : Program} :
    ClauseSig P (builtins delta ioResponse) bodyData (.prim "File.writeTextIn")
      ⟨[], ["path", "text"], [.opaque "Scope.PathIn" (.fixed dataR), .base .string],
        resultTy (.base .unit) ioErrorTy, "File.Write"⟩ := by
  refine ⟨dataR, Or.inr ⟨"File.writeTextIn", writeTextIn, "File.Write", rfl, rfl, rfl, bodyData_rule⟩, ?_⟩
  simp [opSigAt, sig_writeTextIn, writeTextIn, ioIn, pathIn, PrimSig.nranges, Ty.instTarget,
    Scope.Signature.Ix.inst]

/-- 同じ節は Top の添字でも型付けられる（`ClauseIxOk` は Top を許す）。 -/
theorem clauseSig_top {P : Program} {e : Eff} :
    ClauseSig P (builtins delta ioResponse) e (.prim "File.writeTextIn")
      ⟨[], ["path", "text"], [.opaqueTop "Scope.PathIn", .base .string],
        resultTy (.base .unit) ioErrorTy, "File.Write"⟩ := by
  refine ⟨.top, Or.inl rfl, ?_⟩
  simp [opSigAt, sig_writeTextIn, writeTextIn, ioIn, pathIn, PrimSig.nranges, Ty.instTarget,
    Scope.Signature.Ix.inst]

/-- 行の変数を持つ保護本体の効果では、節の操作の型の引数は Top だけである（`/data/**` の型は選べない）。 -/
theorem not_clauseSig_data_rho {P : Program} :
    ¬ ClauseSig P (builtins delta ioResponse) (Eff.union bodyData (Eff.row 0)) (.prim "File.writeTextIn")
      ⟨[], ["path", "text"], [.opaque "Scope.PathIn" (.fixed dataR), .base .string],
        resultTy (.base .unit) ioErrorTy, "File.Write"⟩ := by
  rintro ⟨S, hS, h⟩
  have := hS.top_of_rho (i := 0) ((Eff.mem_union _ _ _).mpr (Or.inr ((Eff.mem_row _ _).mpr rfl)))
  subst this
  simp [opSigAt, sig_writeTextIn, writeTextIn, ioIn, pathIn, PrimSig.nranges, Ty.instTarget,
    Scope.Signature.Ix.inst, dataR] at h

end ClauseIxExamples

end Benitoite.Release
