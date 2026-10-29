import Benitoite.Surface.Theorems
import Benitoite.Surface.ScopeAccept
import Benitoite.Surface.PrimRange
import Benitoite.Surface.ClauseIxRule

/-!
# 脱糖と同じ範囲（L40.5）

表層の型検査器が選んだ範囲を、脱糖がそのままコアへ渡すことを示す（設計書 01-12「表層からの脱糖」「型の情報を付けた
表層の構文と型付け」）。

- 組み込みの呼び出しの範囲の列: 脱糖は表層の組み込みの名前の範囲の列 `rs` をコアの項 `.prim b ts es rs` へ写す
  （`desugar_primName`）。検査の規則を持つ呼び出しでは、受理した列の位置 0 の範囲は、規則の `index` が抽象の結果の由来の
  添字と同じであること（`ScopeState.checkRule_index_agrees`）から、その添字を覆う（`desugar_checkRule_index`）。受理は
  等号でなく被覆を求める（契約の範囲を広く書くことを許す）。コアの検査の δ は具体化した範囲そのものへの所属を確かめる
  ので（`ScopeState.checkDelta_ok_mem`）、成功値の型の添字はコアの項の範囲の列で正しい。
- 節の添字: 表層の節の型付けは、保護本体の効果 `εb` から規則の値 `clauseIx B εb o` を一つ選ぶ。脱糖は同じ `εb` を
  コアの保護本体の効果として渡し（`handle_desugar_same_body_effect`）、その添字はコアの規則の値 `Eff.clauseRange` で
  ある（`HasClausesQ.cons_prim_rule`）。コアの型付けは Top も許すが、表層の型付けと検査器は規則の値だけを選ぶ
  （`HasClausesQ.cons_sig_unique`、検査器は `clauseOpSigIn_eq`）。範囲の変数を持たない表（旧の像）では、節の型付けは
  L40.5 の前の規則と同値である（`clauseSig_iff_old_of_rangeFree`・`HasClausesQ.sel_congr_of_rangeFree`）。
- 範囲の変数: 脱糖したプログラムの定義と操作の型は範囲の変数を持たない（問 3 の P5 を P1 と併用する部分。
  `desugar_rangeFree`）。
-/

namespace Benitoite.Surface

open Benitoite.Release
open Benitoite.Scope.Inference
open Benitoite.Surface.ScopeState
open Benitoite.Surface.ScopeLower
open Benitoite.Surface.ScopeAccept
open Scope.Domain (Range)

/-! ## 組み込みの呼び出しの範囲の列 -/

/-- `ScopeState.checkRule_index_agrees` の本番版。型検査器が受理した検査の呼び出しの範囲の列は、脱糖でそのままコアの
項の範囲の列になり、規則の `index` は抽象の結果の由来の添字だけからなり、列の位置 0 の範囲はその添字を覆う。記録の
全ての状態について成り立つ（`acceptCall_sound`）。 -/
theorem desugar_checkRule_index {T : ScopeTable Release.Val} {records : Records} {exceeded : Bool} {k : Key}
    {xs : List Arg} {rs : List Range} {C : CheckSpec} {run : List Range → List Release.Val → Option Release.Val}
    (h : acceptCall T records exceeded k xs rs = .ok ()) (hrule : T.ruleAt k = some (checkRule C run))
    {st : ScopeState} (hst : (k, st) ∈ records) {key : Key} {o : Origin}
    (htr : (checkRule C run).transfer key (xs.map (absArg T st)) = some (.result o))
    (op : OpPrim) (pos : Position) (b : PrimName) (ts : List Ty) (es : List Eff) :
    desugarExpr op pos (.primName b ts es rs) = .ret (.prim b ts es rs) ∧
      (checkRule C run).index (xs.map (absArg T st)) = [o.bound.index] ∧
      ∀ S, rs[0]? = some S → S.Covers o.bound.index := by
  have hidx := checkRule_index_agrees htr
  refine ⟨desugar_primName op pos b ts es rs, hidx, fun S hS => ?_⟩
  exact acceptCall_sound h hrule st hst 0 S _ hS (by rw [hidx]; rfl)

/-- 被覆で足りる理由。検査の δ が `Ok` を返すなら、成功値はコアの項の範囲 S そのものに属する（受理が等号を求めなくても、
具体化した型の添字への所属は δ の確かめから得る）。 -/
theorem desugar_checkDelta_mem {ok err : Release.ConName} (hne : ok ≠ err) {tys : Range → List Ty}
    {failure : Release.Val} {okVal : List Release.Val → Scope.Domain.Target → Release.Val} {C : CheckSpec} {S : Range}
    {vs : List Release.Val} {v w : Release.Val}
    (hrun : checkDelta ok err tys failure okVal C [S] vs = some v) (hw : okPayload ok v = some w) :
    ∃ t, w = okVal vs t ∧ t.kind = C.kind ∧ S.Mem t :=
  checkDelta_ok_mem hne hrun hw

/-! ## 節の添字 -/

/-- 表層の節の型付けで、範囲を持ちうる組み込みの操作の節の操作の型は、保護本体の効果の Release の規則の値
`Eff.clauseRange` で具体化した型である（判断 11）。 -/
theorem HasClausesQ.cons_prim_rule {D : Declarations} {B : Builtins} {op : OpPrim} {Q : NoFailCtx} {Δ : BuilderCtx}
    {C : List TParam} {Γ : List (Option Ty)} {R : Option Ty} {εb : Eff} {b : PrimName} {n ntys : Nat} {body : Block}
    {cs : Clauses} {t : Ty} {ε : Eff} {nd : Nat} {s : PrimSig} {l : EffName}
    (h : HasClausesQ D B op Q Δ C Γ R εb (.cons (.prim b) n ntys body cs nd) t ε)
    (hs : B.sig b = some s) (hl : s.opEff = some l) :
    ∃ sg, opSigAt D.patternProgram B (εb.clauseRange l) (.prim b) = some sg ∧
      sg.params = s.params.map (Ty.instTarget (List.replicate s.nranges (εb.clauseRange l))) := by
  cases h with
  | cons hop _ _ _ _ _ _ =>
    rw [clauseIx_prim hs hl] at hop
    refine ⟨_, hop, ?_⟩
    simp only [opSigAt, hs, hl, Option.some.injEq] at hop
    rw [← hop]

/-- 表層の節の型付けの操作の型は、保護本体の効果から一つに決まる（判断 11 の「一意に選ぶ」）。コアの型付けは
同じ節を規則の値と Top の二つの添字で型付けうる（`Release.ClauseIxExamples.clauseSig_data`・`clauseSig_top`）が、
表層の型付けは同じ保護本体の効果のもとで同じ操作の型しか使わない。 -/
theorem HasClausesQ.cons_sig_unique {D : Declarations} {B : Builtins} {εb : Eff} {o : OpRef} {sg sg' : OpSig}
    (h : opSigAt D.patternProgram B (clauseIx B εb o) o = some sg)
    (h' : opSigAt D.patternProgram B (clauseIx B εb o) o = some sg') : sg = sg' :=
  Option.some.inj (h.symm.trans h')

/-- 表層の `handle` の型付けの前提から脱糖すると、コアの保護本体の型付けの効果は、表層の節の添字を選んだ効果
`εbody` と同じであり、節はその効果のもとで型付く（C-Handle の `εm` が `εbody`）。従って節の添字はコアの保護本体の
効果の規則の値である（`HasClausesQ.cons_prim_rule`）。 -/
theorem handle_desugar_same_body_effect {p : Program} {view : CoverageView} {B : Builtins} {op : OpPrim}
    {Q : NoFailCtx} {Δb : BuilderCtx} {C : List TParam} {Γ : List (Option Ty)} {R : Option Ty} {body : Block}
    {cs : Clauses} {t : Ty} {εbody ε : Eff} {pe : Nat → Prop}
    (hAlign : BuilderCtx.Aligned Γ Δb) (hΔ : BuilderCtx.Clean C.length Δb) (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped)
    (hb : HasBlockQ (p.declarationsFor view) B op Q Δb C Γ R .other body t εbody)
    (hc : HasClausesQ (p.declarationsFor view) B op Q Δb C Γ R εbody cs t ε)
    (sc : (Expr.handleE body cs).Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γ R (desugarBlock op .other body) t εbody Δb.toLocal ∧
      HasTypeClausesQ (desugarProgram op p) B StoreTy.empty Q C Γ R εbody (desugarClauses op cs) t ε
        Δb.toLocal :=
  ⟨HasBlockQ.desugar hAlign hΔ hwf hsig hb sc.1 hΓ hR,
    HasClausesQ.desugar hAlign hΔ hwf hsig hc sc.2 hΓ hR (HasBlockQ.clean hΔ hwf hsig hb sc.1 hΓ hR)⟩

/-! ### 旧の像での同値

範囲の変数を持たない表（全ての項目で `nranges = 0`）では、節の操作の型は添字によらず `opSig` であり（L40.5 の前の
表層の規則の前提）、表層の節の型付けは保護本体の効果によらない。 -/

/-- 旧の像では、表層の節の操作の型の前提は、L40.5 の前の前提 `opSig D.patternProgram B o = some sg` と同値である。 -/
theorem clauseSig_iff_old_of_rangeFree {D : Declarations} {B : Builtins}
    (hrf : ∀ b s, B.sig b = some s → s.nranges = 0) {εb : Eff} {o : OpRef} {sg : OpSig} :
    opSigAt D.patternProgram B (clauseIx B εb o) o = some sg ↔ opSig D.patternProgram B o = some sg := by
  rw [opSigAt_eq_opSig_of_rangeFree (P := D.patternProgram) hrf]

/-- 旧の像では、表層の節の型付けは保護本体の効果によらない（L40.5 の前の、保護本体の効果を持たない規則と同じ導出）。 -/
theorem HasClausesQ.sel_congr_of_rangeFree {D : Declarations} {B : Builtins} {op : OpPrim} {Q : NoFailCtx}
    (hrf : ∀ b s, B.sig b = some s → s.nranges = 0) {Δ : BuilderCtx} {C : List TParam} {Γ : List (Option Ty)}
    {R : Option Ty} {εb εb' : Eff} {cs : Clauses} {t : Ty} {ε : Eff}
    (h : HasClausesQ D B op Q Δ C Γ R εb cs t ε) : HasClausesQ D B op Q Δ C Γ R εb' cs t ε := by
  match h with
  | .nil => exact .nil
  | .cons hop h1 h2 h3 h4 h5 h6 =>
    exact .cons ((clauseSig_iff_old_of_rangeFree hrf).mpr ((clauseSig_iff_old_of_rangeFree hrf).mp hop))
      h1 h2 h3 h4 h5 (HasClausesQ.sel_congr_of_rangeFree hrf h6)

/-! ## 脱糖の出力の型に範囲の変数がない（問 3 の P5 の併用） -/

/-- コアの定義の整形式性は、定義の型に範囲の変数を置かせない（P1）。 -/
theorem coreDef_rangeFree {d : Release.Def} (h : d.Scoped) :
    Ty.RangesInList 0 d.params ∧ Ty.RangesIn 0 d.ret ∧ Eff.RangesIn 0 d.eff :=
  ⟨((Ty.varsInList_iff_old _ _ _ _).mp h.2.1).2, ((Ty.varsIn_iff_old _ _ _ _).mp h.2.2.1).2,
    ((Eff.varsIn_iff_old _ _ _ _).mp h.2.2.2.1).2⟩

/-- 脱糖したプログラムの定義の型は範囲の変数を持たない（P5）。表層の整形式性（P1）と脱糖の整形式性の保存から得る。
脱糖が書く組み込みの呼び出しの範囲の列は閉じた範囲の列（`List Range`）であり、範囲の変数を持たない。 -/
theorem desugar_rangeFree {p : Program} {B : Builtins} {op : OpPrim} (hwf : p.WellFormed) (hwt : p.WellTyped B op)
    {f : FunName} {d : Release.Def} (hd : (desugarProgram op p).defs f = some d) :
    Ty.RangesInList 0 d.params ∧ Ty.RangesIn 0 d.ret ∧ Eff.RangesIn 0 d.eff :=
  coreDef_rangeFree ((desugar_wellFormed hwf hwt).1 f d hd)

end Benitoite.Surface
