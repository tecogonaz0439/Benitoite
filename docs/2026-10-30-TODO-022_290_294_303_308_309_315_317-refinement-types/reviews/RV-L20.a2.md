# RV-L20.a2: 形式化の群 L20 A2（方式の関門 (a)）の独立レビュー

対象: `m014/l20.a2` の未コミットの差分（基準 `3cdec156`）、`formal/Benitoite/Release/Refinement/CaptureRegularity.lean`、`l20/a2/`。基準: `l20/detail.md` の S01・S01a・S01b と関門 (a)、`reviews/RV-L20-plan.md` の重1・重2・中2・中9、依頼文。2026-11-02。

## 総合判定

**条件付き可**（重0・中2・軽4、計6件）。**関門 (a) の通過の判定に同意する。**

同意の根拠は実装側の判定ではなく、次の Lean である。実際の `E_Handle`（`C_Handle`・`C_Handle_Fail` の両方、`C_Sub`・`C_Eff`・`C_Normal` を通す）と `E_Let` の前の状態から、行先の `ClosureTy`・包含・`ContTy` を、A2 の本番の補題と既存の補題だけで組み立てた（`e_handle_post`・`e_let_post`。公理は propext・Classical.choice・Quot.sound のみ）。E_Lam の値依存の除去も、非依存・依存の両方の効果の注釈を確かめた。独立の仮定、定義の変更、`CaptureWF` の強化は要らなかった。全遷移の保存を示したものではない。

条件は二つである。100 KB を超える生の記録を改造の外へ移すこと（中1）。元の全体効果から `capture_handle_body_annotation` の前提へ至る逆転と被覆の段を、本番に足すか L20.101 の完了条件に書くこと（中2）。どちらも定理の成立を変えない。

## 所見の分類

| 種類 | 所見 |
|---|---|
| Lean で確かめた | 中2、軽1、軽2、軽3 |
| 読めば確定する誤り | 中1、軽4 |
| 実行しないと分からない推測 | なし |

## 中

### 中1: 100 KB を超える生の記録が改造の中にある（読めば確定）

- 箇所: `l20/a2/axioms-summary.json`（308,349 バイト、SHA-256 の先頭 `598a7e338e80aace`）、`l20/a2/axioms.log`（212,662 バイト、同 `69b1c7b7dfa1cf62`）。`artifact-manifest.json`、`results.md` の 14 行と 67 行が参照する。
- 問題: AGENTS.md の `work/` の行は「大きな生の記録は大きさと SHA-256 だけを残す」と定める。L00b.03 と L10.w は `large-records.md` で扱い、L20.a1 に 100 KB を超えるファイルはない。
- 修正案: 二つのファイルをリポジトリの外へ移し、`l20/a2/large-records.md` に大きさ・SHA-256・作り方（`axioms.lean`）・集計（1,820 印字／1,810 固有宣言、公理の和集合）を書く。`results.md` と `artifact-manifest.json` の参照を直す。入力の `axioms.lean` は残す。

### 中2: 元の全体効果から本体の効果への段が本番にない。表の「元全体の閉じた done 注釈」は `ec` と外側の `e` を同一視している（読めば確定。閉じることは Lean で確認）

- 箇所: `CaptureRegularity.lean` 351 行 `capture_handle_body_annotation`、`annotation-sources.md`「S01b の効果の全供給」の E_Handle の行、`gate.md`「閉じた枝と残り」の E_Handle の行、`results.md`「E_Handle は、元 ClosureTy の閉じた全体の効果注釈と」の段落。
- 問題: 補題の前提は `done (cap.closeTy t) (cap.closeEff ec)` であり、`ec` は `C_Handle` の結論の効果である。`ClosureTy.annotation` が与えるのは閉包全体の効果 `es` である。`.handle` の導出が `C_Eff`・`C_Sub`・`C_Normal` で終わると、`es ≠ ec`、`as ≠ t` になる。この場合に補題の前提を作る段（`.handle` の逆転、`Eff.Covers` の閉じた移送、`capture_comp_annotation` による内側の `t` の注釈の差し替え）は本番にない。文書の「元全体の注釈から」は、この段を飛ばしている。計画レビューの中9が問うた箇所なので、関門の証拠に含めるのが正しい。
- 再現: 付録 `inv1.lean`。`handle_inv`（逆転）、`done_inner`（被覆と内側の結果の注釈から `done` を作る）、`e_handle_supply`、`e_handle_post` が終了0、`sorryAx` なし。新しい仮定は要らない。計画の単位では L20.101 が受け持つ E_Handle の葉の入口に当たる。
- 修正案: `handle_inv` と `done_inner` を本番に足す。足さないなら、`annotation-sources.md` の E_Handle の行へ「`C_Sub`/`C_Eff`/`C_Normal` は逆転の後に `ec` へ移す。既存の `Eff.Covers.bind`・`done_annotation_of_covers` で閉じる」と書き、L20.101 の完了条件に名指しする。`E_Let` は逆転の形が違う（次の軽2）ので、同じ段に並べて書く。

## 軽

### 軽1: S01b の「新しい continuation 場所の e」の Fail の供給が `split_fail` から得られない（読めば確定。修正は Lean で確認）

- 箇所: `annotation-sources.md` の同じ行、`gate.md` 冒頭「S01b の効果供給も閉じた」。`HandlerFailure.lean` `ContTy.split_fail`。
- 問題: `split_handle` は `HandlerFrameTy` で `done t ec` の注釈を返す。`split_fail` が返すのは継続の型付き・被覆・包含だけであり、`done t ec` を返さない。`K_Handle_Fail` も `t` の注釈だけを持つ。よって E_OpFail で新しい場所を割り当てるとき、表の「`capture_result_effect`」を直接呼ぶ入力（`hcap`・`hcs`）が `split_fail` の外へ出てこない。証拠は `[]` の枝の内側にある。
- 再現: 付録 `rest.lean` の `split_fail_annotated`。結論に `Ty.Annotation P [] [] (.dependentFn (.done t ec))` を足し、`[]` の枝で `HasFailureClause.capture_result_effect` を呼ぶと閉じる。新しい仮定は要らない。
- 修正案: 表の行は「供給元確定、`split_fail` の結論に注釈を一つ足す」と書く。L20.104 の完了条件へ入れる。`gate.md` の「閉じた」は S01b の第6行の「供給元確定」と語を揃える。

### 軽2: `capture_let_effect_annotations` の呼び方に、文書にない二つの手順が要る（Lean で確認）

- 箇所: `annotation-sources.md` の E_Let/K_Let の行。
- 問題: 第一に、`K_Let` と `StateTyE` は `Eff.Sub` を要るが、`C_Eff`・`C_Sub` が与えるのは `Eff.Covers` である。このため E_Handle と違い、内側の `ε` へ下りるのではなく、`m` と `n` を `C_Eff` で外側の `e` へ広げてから補題を呼ぶ（`n` は `Eff.Covers.shiftV`）。第二に、`K_Let` は `R.map (Ty.shiftV 1 0)` を要り、`ClosureTy.mk` の `R` は `CaptureOk` の `R` と同じなので、`R` の閉性が要る。`CaptureOk` にも `Rs` の `Declared` にもこの条件はない。
- 再現: 付録 `let1.lean`。`cont_R_wf`（`ContTy` の `Re = none` から `R` の `WF 0 0 0` を帰納で導く）と `e_let_post` が閉じる。新しい仮定は要らない。
- 修正案: 表の行へ二点を書く。`cont_R_wf` は E_Let を受け持つ単位へ渡す。

### 軽3: 境界に実際の閉包がない（Lean で確認）

- 箇所: `boundary.lean`。
- 問題: 実際の型付けを使う例の文脈は空の Γ か、`CaptureOk` のない `weak_context_resume` だけである。`S01` の主な用途である「`CaptureOk` から `contextRegular` を経る」経路と、`hideBuilders`・`hideConts` の下の適用が、境界にない。定理の成立には影響しない。
- 再現: 付録 `rest.lean`。`rv_real_closure` は、通常の値と Fail を持つ継続の場所を実際に捕捉した非空の `CaptureOk`（`CaptureOk.extend`・`extendCont`）から、`capture_comp_annotation` と `continuation_result_effect` を呼ぶ。`rv_thunk_body` は `CaptureOk.store`・`hideConts_any`・三条件の hide を合成して thunk の本体へ適用する。`rv_hideConts_regular` は開いた形の `hideConts` の保存を示す。すべて終了0。
- 修正案: `rv_real_closure` と `rv_thunk_body` を `boundary.lean` へ足す。

### 軽4: 使われない前提と宣言、07-04 の経緯の文（読めば確定）

- `open_value_annotation`・`open_comp_annotation` の `_hp _ht _hA` は使われない。`gate.md` に記載があり、S01 の指定の署名なので誤りではない。呼び出し側の負担が増えるので、後続の接続で要らないと確定したら署名の変更として外す。
- `handle_body_normalize`・`failure_body_widen`・`HasTypeClausesQ.same_input_atoms` は、`e_handle_post` に要らなかった。L20.101 でも使わないなら除く。
- `docs/design/07-quality/07-04-formal-semantics.md` 102 行「捕捉の条件や主な定理へ新しい独立の信頼条件を追加していない」は、変更の経緯の文である（RV-L20.a1 軽2 と同じ）。「前提は捕捉元の三条件と場所の三条件である」のように現在の内容へ改める。

## 観点ごとの確認

| 観点 | 結果 |
|---|---|
| 1. 開いた motive の前提 | 強すぎない。`CaptureOk.contextRegular` は `CaptureOk` の三つの欄の射影であり、`Ψ` の三条件は `StoreOk` の射影と `.hide` で届く。`K_Handle` の `CaptureOk (hideBuilders Ψ)` は `CaptureOk.store` で作れる（`e_handle_post`）。thunk・lambda の本体は `hideConts_any` を経て適用できる（`rv_thunk_body`）。`CaptureWF` が読まない潜在効果は仮定していない。`C_Resume` の枝は入力と結果だけを読み、潜在効果は `ImageOk.contLoc` と場所の三条件から別に得る。`rv_real_closure` で非空の実際の捕捉から確認した。motive が節・腕の本体・lambda の本体へ下りないので、`bindParams` と `sg.context` の開いた保存は要らない |
| 2. 結論の形 | 弱められていない。結論は導出の型 `a` の `Ty.Annotation` そのものなので、規則ごとに弱める余地がない。弱い5枝、`C_ResumeNorm`・`C_ResumeLNorm`・`C_Normal`・`V_Normal`（`t.norm` を証明）、`C_Sub`・`V_Sub`、`V_Refine`、`V_Super`、`C_CheckAt`、`C_BuilderOp`、腕・Each・TelArgs・Vs の全枝を読んだ。`Ty.Annotation` は `WF`・`Sorted`・`Declared` の三つで、`fn`・`dependentFn`・`cont` の型は潜在効果を含む。効果の注釈の条件は Fail の型と Canonical であり、原子の名前と範囲は含まない（表の末尾の記述のとおり）。S01b の7行のうち E_Let・E_Lam・E_Handle・E_Handle_Fail・C_Resume・任意 e の6行は閉じた。第6行は軽1 |
| 3. E_Handle の効果 | 中9は解消した。`handled` の形成は要らず、Fail 列が空であることだけを使う。`Eff.Sub`・`NoFail`・`K_Handle`・`K_Handle_Fail` の前提は `e_handle_post` で全部満たした。`NoFail Qempty (closeEff rest)` は `C_Handle_Fail` の `NoFail` を `NoFail.subst_values` で移す。`ClosureTy` の注釈は `ClosureTy.capture_resolved_closed` の形に合う。`K_Handle` の `Eff.Covers` と `Eff.Sub` は `Eff.Covers.bind`・`substEffValues_union`・`handled_subst_values` で作れる。`eb.norm` の経路は要らなかった。段の欠けは中2 |
| 3. E_Let・E_Lam | `e_let_post` が閉じた（手順は軽2）。E_Lam は `lam_body_effect`（`.fn`。`cap.extendMany ws` の下で `r`・`e` の shift が消えることを `env_many` で示す）、`dep_body_effect`（`capture_tel_annotation` の出力と `of_arguments`・`open_telArgs_annotation`）が閉じた。`.fn` の多引数の shift の消去は `Capture.closeTy_shift` が一引数だけなので、付録の `env_many`・`eff_shift_env` を後続の単位で使える。全β保存は対象外であり、表の記述どおり |
| 4. 表と本体 | 53行の集合と順序は `Typing.lean` の V29・CQ24 と機械照合で一致した。分類の件数も一致する。全53名が本体の `match` に現れる。V_Const の16構成子を含め、上の抜き取りで表と本体の不一致はない。Lean の網羅検査が全枝を保証する |
| 5. 公理など | `CaptureRegularity.lean` に `sorry`・`native_decide`・`axiom`・`unsafe`・`implemented_by` はない。`private` は8件で、仮定を隠す宣言はない。`axioms.lean` を自分で実行し、全印字の公理は propext・Quot.sound・Classical.choice のみだった。`git status` で formal の変更は `Benitoite.lean` の import 1件と新規ファイルだけなので、主な10言明と既存の定理は変わらない。`lake build` は終了0（775 jobs）。`boundary.lean` は終了0 |
| 6. 設計書 | 01-12・07-04 の記述は Lean と一致する。処理系の未実装を断定していない。見出しは変わらない。軽4の一文を除き規約に合う |
| 7. 規約 | 手元の絶対パス、docs/todo へのリンク、`work/` を出どころとする参照、「費用」の語はない（`results.md` の「docs/todo」は編集しなかった旨の文字だけ）。100 KB を超えるファイルは中1 |

## 計画レビューの所見の確認

| 所見 | 判定 |
|---|---|
| 重1 | 解消。`C_ResumeL` は場所の三条件から閉じ、`used` の `CellOk` を使わない |
| 重2 | 解消。`CaptureOk` を要求しない開いた motive が `C_Let`・`C_BuilderLet`・`C_If` を通る。`boundary.false_path_let` も偽の Φ で適用する |
| 中2 | 解消。成果物が判定できる形で揃い、全53枝まで閉じた |
| 中9 | 解消。条件は中2の段を本番か後続の完了条件へ入れること |

## 残る範囲

`e_handle_post` の `Frame.Adequate` は引数とした。`e_let_post` の `Closure.Adequate` も同じである。`StoreOk`・`Closed`・`Adequate` を含む状態全体の保存は証明していない。

## 再現の入力

`<tmp>` に次の四つを置き、`formal/` で `lake env lean -M 12288 <tmp>/<名前>` を実行した。全部終了0、`sorry` なし、公理は propext・Classical.choice・Quot.sound。

### inv1.lean

```lean
import Benitoite.Release.Refinement.CaptureRegularity
import Benitoite.Release.Refinement.MatchPaths

namespace RVL20A2
open Benitoite.Release.Refinement
noncomputable section

theorem cover_close {Γ Φ outer inner} (cap : Capture) (h : Eff.Covers Γ Φ outer inner) :
    Eff.Covers [] [] (cap.closeEff outer) (cap.closeEff inner) := h.bind (valEnv cap.env)

/-- 外側の注釈・被覆・内側の結果の注釈から、内側の閉じた done の注釈を得る。 -/
theorem done_inner {P cap Γ Φ a b outer inner}
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a (Capture.closeEff cap outer))))
    (hb : Ty.Annotation P [] [] b) (hc : Eff.Covers Γ Φ outer inner) :
    Ty.Annotation P [] [] (.dependentFn (.done b (Capture.closeEff cap inner))) := by
  have h1 : Ty.Annotation P [] [] (.dependentFn (.done b (Capture.closeEff cap outer))) :=
    ⟨⟨hb.wf, ha.wf.2⟩, ⟨hb.sorted, ha.sorted.2⟩, ⟨hb.declared, ha.declared.2⟩⟩
  exact done_annotation_of_covers h1 (cover_close cap hc) (Eff.norm_idem _)

/-- C_Sub/C_Eff/C_Normal を通す .handle の逆転。 -/
theorem handle_inv {P B Ψ Q C Γ Φ Rs code m h a e L}
    (hm : HasTypeCQ P B Ψ Q C Γ Φ Rs code a e L) (hcode : code = .handle m h) :
    (∃ t εm ε, HasTypeCQ P B Ψ Q C Γ Φ Rs m t εm L ∧
      Eff.Sub εm (Eff.union ε (handled P B h)) ∧
      HasTypeClausesQ P B Ψ Q C Γ Φ Rs εm h t ε L ∧
      Eff.Covers Γ Φ e ε ∧ Ty.LeQ P Γ Φ t a) ∨
    (∃ t E eb rest ec, HasTypeCQ P B Ψ Q C Γ Φ Rs m t eb L ∧
      Eff.Sub eb (Eff.union (Eff.singleFail E) rest) ∧ NoFail Q rest ∧
      HasFailureClause P B Ψ Q C Γ Φ E Rs h t ec L ∧
      Eff.Covers Γ Φ e (Eff.union rest ec) ∧ Ty.LeQ P Γ Φ t a) := by
  match hm with
  | .C_Handle hb hsub hcl =>
    cases hcode
    exact .inl ⟨_, _, _, hb, hsub, hcl, Eff.Covers.refl _ _ _, .refl⟩
  | .C_Handle_Fail hb hsub hn hf =>
    cases hcode
    exact .inr ⟨_, _, _, _, _, hb, hsub, hn, hf, Eff.Covers.refl _ _ _, .refl⟩
  | .C_Normal hh =>
    rcases handle_inv hh hcode with ⟨t, εm, ε, h1, h2, h3, h4, h5⟩ | ⟨t, E, eb, rest, ec, h1, h2, h3, h4, h5, h6⟩
    · exact .inl ⟨t, εm, ε, h1, h2, h3, h4, .trans h5 (.convert (Ty.norm_idem _).symm)⟩
    · exact .inr ⟨t, E, eb, rest, ec, h1, h2, h3, h4, h5, .trans h6 (.convert (Ty.norm_idem _).symm)⟩
  | .C_Sub hh hle hcov _ _ _ =>
    rcases handle_inv hh hcode with ⟨t, εm, ε, h1, h2, h3, h4, h5⟩ | ⟨t, E, eb, rest, ec, h1, h2, h3, h4, h5, h6⟩
    · exact .inl ⟨t, εm, ε, h1, h2, h3, hcov.trans h4, .trans h5 hle⟩
    · exact .inr ⟨t, E, eb, rest, ec, h1, h2, h3, h4, hcov.trans h5, .trans h6 hle⟩
  | .C_Eff hh hcov =>
    rcases handle_inv hh hcode with ⟨t, εm, ε, h1, h2, h3, h4, h5⟩ | ⟨t, E, eb, rest, ec, h1, h2, h3, h4, h5, h6⟩
    · exact .inl ⟨t, εm, ε, h1, h2, h3, hcov.trans h4, h5⟩
    · exact .inr ⟨t, E, eb, rest, ec, h1, h2, h3, h4, hcov.trans h5, h6⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hcode
termination_by structural hm

/-- 実際の E_Handle の前の状態: run q k μ を型付けし q.view = .handle のとき、
ClosureTy の全体効果の注釈だけから、本体の結果と行の閉じた注釈と節の行の注釈を得る。 -/
theorem e_handle_supply {P B Ψ R q m h a e1}
    (hp : P.WellFormed) (ht : P.WellTyped B) (hA : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e1) (hv : q.view = .handle m h) :
    ∃ cap Γ Φ Rs m0 h0 L ρ, q = .mk cap (Comp.handle m0 h0 |>.resolveLocals ρ) ∧
      CaptureOk P B Ψ R Γ Φ cap ∧ CaptureLocals Ψ cap.env L ρ ∧
      ((∃ t εm ε, HasTypeCQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs m0 t εm L ∧
          Eff.Sub εm (Eff.union ε (handled P B h0)) ∧
          HasTypeClausesQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs εm h0 t ε L ∧
          Eff.Covers [] [] e1 (cap.closeEff ε) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ε))) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff εm)))) ∨
       (∃ t E eb rest ec, HasTypeCQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs m0 t eb L ∧
          Eff.Sub eb (Eff.union (Eff.singleFail E) rest) ∧ NoFail Benitoite.Release.Qempty rest ∧
          HasFailureClause P B Ψ Benitoite.Release.Qempty [] Γ Φ E Rs h0 t ec L ∧
          Eff.Covers [] [] e1 (cap.closeEff (Eff.union rest ec)) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ec))) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff eb))))) := by
  have hann := hq.annotation
  simp only [bindParams, List.reverse_nil, List.map_nil, List.nil_append] at hann
  obtain ⟨cap, Γ, Φ, Rs, code0, as, es, L, ρ, rfl, hc, hb, hL, hR, rfl, rfl, hrs⟩ := hq.open_zero
  have hform : ∃ m0 h0, code0 = .handle m0 h0 := by
    cases code0
    case handle => exact ⟨_, _, rfl⟩
    case checkAt _ _ _ bs _ _ _ =>
      exfalso; cases bs <;> (simp only [Comp.resolveLocals] at hv; injection hv)
    all_goals (exfalso; simp only [Comp.resolveLocals] at hv; injection hv)
  obtain ⟨m0, h0, rfl⟩ := hform
  refine ⟨cap, Γ, Φ, Rs, m0, h0, L, ρ, rfl, hc, hL, ?_⟩
  rcases handle_inv hb rfl with ⟨t, εm, ε, h1, h2, h3, h4, _⟩ | ⟨t, E, eb, rest, ec, h1, h2, h3, h4, h5, _⟩
  · have ha := capture_comp_annotation hp ht hA hw hs hd hc h1
    have hε := done_inner hann ha h4
    exact .inl ⟨t, εm, ε, h1, h2, h3, cover_close cap h4, hε, capture_handle_body_annotation hε h2⟩
  · have hec := h4.capture_result_effect hc
    exact .inr ⟨t, E, eb, rest, ec, h1, h2, h3, h4, cover_close cap h5, hec,
      capture_failure_body_annotation hc h4 h3 h2⟩


theorem hide_idem (Ψ : StoreTy) : hideBuilders (hideBuilders Ψ) = hideBuilders Ψ := by
  funext l
  unfold hideBuilders
  cases hl : Ψ l with
  | none => simp
  | some x => cases x <;> simp

theorem clauses_hide {P B Ψ Q C Γ Φ R eb h t ε L}
    (hc : HasTypeClausesQ P B Ψ Q C Γ Φ R eb h t ε L) :
    HasTypeClausesQ P B (hideBuilders Ψ) Q C Γ Φ R eb h t ε [] := by
  match hc with
  | .nil => exact .nil
  | .cons hsg hn hp hk hw hb hs =>
    exact .cons hsg hn hp hk hw (by rw [hide_idem]; exact hb) (clauses_hide hs)
termination_by structural hc

theorem failure_hide {P B Ψ Q C Γ Φ E R h t ε L}
    (hc : HasFailureClause P B Ψ Q C Γ Φ E R h t ε L) :
    HasFailureClause P B (hideBuilders Ψ) Q C Γ Φ E R h t ε [] := by
  cases hc with
  | one hE ht hr hb => exact .one hE ht hr (by rw [hide_idem]; exact hb)

/-- 開いた注釈なしで、閉じた注釈だけから ss=[] の閉包の型付けを作る。 -/
theorem closure_of_closed {P B Ψ R Rs Γ Φ cap body a e L ρ}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hb : HasTypeCQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs body a e L)
    (hl : CaptureLocals Ψ cap.env L ρ)
    (ht : Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy a) (cap.closeEff e))))
    (hR : cap.closeR Rs = R) (hr : ∀ r, Rs = some r → r.Declared P [] Γ) :
    ClosureTy P B Ψ [] R (.mk cap (body.resolveLocals ρ)) (cap.closeTy a) (cap.closeEff e) := by
  have hr' : ∀ r, R = some r → r.Declared P [] [] := by
    intro r hh
    cases hs : Rs with
    | none => simp [Capture.closeR,hs] at hR; rw [←hR] at hh; cases hh
    | some rs =>
      have he : cap.closeTy rs = r := by simpa [Capture.closeR,hs,hh] using hR
      rw [←he]; exact (hr rs hs).bind_values hc.substOk.declaration
  have hb' : HasTypeCQ P B Ψ Benitoite.Release.Qempty [] (bindParams Γ []) (liftMany 0 Φ) Rs body a e L := by
    simpa only [bindParams,List.reverse_nil,List.map_nil,List.nil_append,List.length_nil,liftMany_eq,
      show Pred.shiftV 0 0 = id from funext (fun p => p.shiftV_zero 0),
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hb
  have hh := ClosureTy.mk (ss := []) (Rs := Rs) (a := a) (e := e) hc hb'
    (by simpa only [List.length_nil,upSubst_zero] using hl) rfl
    (by simp [TypeAnnotations]) (by simp [TypeAnnotations])
    (by simpa [Capture.closeRAt,Capture.closeR,Capture.closeTyAt,Capture.closeTy,upSubst_zero] using hR)
    (by simpa only [List.map_nil,List.length_nil,bindParams,List.reverse_nil,List.nil_append,Capture.closeTyAt,Capture.closeTy,upSubst_zero]
        using (show Ty.Annotation P [] [] (cap.closeTy a) from ⟨ht.wf.1,ht.sorted.1,ht.declared.1⟩))
    (by simpa only [List.map_nil,List.length_nil,bindParams,List.reverse_nil,List.nil_append,Capture.closeTyAt,Capture.closeEffAt,Capture.closeTy,Capture.closeEff,upSubst_zero] using ht)
    (by simpa only [bindParams,List.reverse_nil,List.map_nil,List.nil_append,List.length_nil,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hr) hr'
  simpa only [List.map_nil,List.length_nil,Capture.closeTyAt,Capture.closeEffAt,Capture.closeTy,Capture.closeEff,upSubst_zero] using hh

theorem sub_union_left (e f : Eff) : Eff.Sub e (Eff.union e f) := by
  cases e with
  | mk a fs => cases f with
    | mk b gs =>
      refine ⟨fun x hx => ?_, fun x hx => ?_⟩
      · exact (Eff.mem_norm _ _).mpr (show (a x || b x) = true by simp [show a x = true from hx])
      · obtain ⟨y, hy, he⟩ := hx
        exact (Eff.norm_memFail _ _).mpr ⟨y, List.mem_append_left _ hy, he⟩

theorem sub_union_right (e f : Eff) : Eff.Sub f (Eff.union e f) := by
  cases e with
  | mk a fs => cases f with
    | mk b gs =>
      refine ⟨fun x hx => ?_, fun x hx => ?_⟩
      · exact (Eff.mem_norm _ _).mpr (show (a x || b x) = true by simp [show b x = true from hx])
      · obtain ⟨y, hy, he⟩ := hx
        exact (Eff.norm_memFail _ _).mpr ⟨y, List.mem_append_right _ hy, he⟩

/-- 実際の E_Handle の一歩: 前の状態の ClosureTy・包含・ContTy から、行先の ClosureTy・包含・ContTy を作る
（Frame.Adequate は引数）。C_Handle と C_Handle_Fail の両方。 -/
theorem e_handle_post {P B σ Ψ R q m h a e1 e k b Eb}
    (hp : P.WellFormed) (ht : P.WellTyped B) (hA : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e1) (hsub : Eff.Sub e1 e)
    (hk : ContTy P B σ Ψ R e k a b Eb none)
    (hv : q.view = .handle m h) (hf : Frame.Adequate σ (.handleF q.capture h)) :
    ∃ t e1' e', ClosureTy P B Ψ [] R (.mk q.capture m) t e1' ∧ Eff.Sub e1' e' ∧
      ContTy P B σ Ψ R e' (.handleF q.capture h :: k) t b Eb none := by
  have hann := hq.annotation
  simp only [bindParams, List.reverse_nil, List.map_nil, List.nil_append] at hann
  obtain ⟨cap, Γ, Φ, Rs, code0, as, es, L, ρ, rfl, hc, hb, hL, hR, rfl, rfl, hrs⟩ := hq.open_zero
  have hform : ∃ m0 h0, code0 = .handle m0 h0 := by
    cases code0
    case handle => exact ⟨_, _, rfl⟩
    case checkAt _ _ _ bs _ _ _ =>
      exfalso; cases bs <;> (simp only [Comp.resolveLocals] at hv; injection hv)
    all_goals (exfalso; simp only [Comp.resolveLocals] at hv; injection hv)
  obtain ⟨m0, h0, rfl⟩ := hform
  have hv' : m = m0.resolveLocals ρ ∧ h = Clause.resolveLocalsList ρ h0 := by
    simp only [Comp.resolveLocals] at hv
    injection hv with h1 h2
    exact ⟨h1.symm, h2.symm⟩
  obtain ⟨rfl, rfl⟩ := hv'
  have hcov : Eff.Covers [] [] e (cap.closeEff es) := hsub.covers
  have hhide : CaptureOk P B (hideBuilders Ψ) R Γ Φ cap :=
    hc.store hA.values hw (StoreTy.preserves_hide Ψ)
  rcases handle_inv hb rfl with ⟨t, εm, ε, h1, h2, h3, h4, h5⟩ | ⟨t, E, eb, rest, ec, h1, h2, h3, h4, h5, h6⟩
  · have ha := capture_comp_annotation hp ht hA hw hs hd hc h1
    have hε := done_inner hann ha h4
    have hbody := capture_handle_body_annotation hε h2
    have hq' := closure_of_closed hc h1 hL hbody hR hrs
    have hle : Ty.LeQ P [] [] (cap.closeTy t) (cap.closeTy as) := h5.bind (valEnv cap.env) hc.transport
    have hopen := open_comp_annotation hp ht hA hw hs hd hc.contextRegular h1
    have hsub' : Eff.Sub (cap.closeEff εm) (Eff.union (cap.closeEff ε) (handled P B h0)) := by
      simpa only [Capture.closeEff, ← substEffValues_eq_bind, substEffValues_union, handled_subst_values]
        using h2.bind (valEnv cap.env)
    rw [HasTypeClausesQ.resolve_id h3 ρ]
    rw [HasTypeClausesQ.resolve_id h3 ρ] at hf
    exact ⟨_, _, _, hq', ⟨fun _ x => x, fun _ x => x⟩, .K_Handle (.K_Sub hk hle) (hcov.trans (cover_close cap h4)) hsub' hhide
      (clauses_hide h3) hR rfl rfl rfl hε hopen hrs hf⟩
  · have ha := capture_comp_annotation hp ht hA hw hs hd hc h1
    have hbody := capture_failure_body_annotation hc h4 h3 h2
    have hq' := closure_of_closed hc h1 hL hbody hR hrs
    have hle : Ty.LeQ P [] [] (cap.closeTy t) (cap.closeTy as) := h6.bind (valEnv cap.env) hc.transport
    have hsub' : Eff.Sub (cap.closeEff eb) (Eff.union (Eff.singleFail (cap.closeTy E)) (cap.closeEff rest)) := by
      simpa only [Capture.closeEff, Capture.closeTy, ← substEffValues_eq_bind, substEffValues_union, substEffValues_singleFail]
        using h2.bind (valEnv cap.env)
    have hun : Eff.Sub (cap.closeEff rest) (cap.closeEff (Eff.union rest ec)) ∧
        Eff.Sub (cap.closeEff ec) (cap.closeEff (Eff.union rest ec)) := by
      have hu : cap.closeEff (Eff.union rest ec) = Eff.union (cap.closeEff rest) (cap.closeEff ec) :=
        substEffValues_union rest ec cap.env
      rw [hu]
      exact ⟨sub_union_left _ _, sub_union_right _ _⟩
    rw [HasFailureClause.resolve_id h4 ρ]
    rw [HasFailureClause.resolve_id h4 ρ] at hf
    exact ⟨_, _, _, hq', hsub', .K_Handle_Fail (.K_Sub hk hle)
      (hcov.trans (hun.1.covers |> (cover_close cap h5).trans))
      (h3.subst_values cap.env) (hhide) (failure_hide h4) hR rfl rfl rfl hrs
      (hcov.trans (hun.2.covers |> (cover_close cap h5).trans)) ⟨ha.wf, ha.sorted, ha.declared⟩ hf⟩

end
end RVL20A2
#print axioms RVL20A2.e_handle_supply
#print axioms RVL20A2.e_handle_post
```

### let1.lean

```lean
import Benitoite.Release.Refinement.CaptureRegularity
import Benitoite.Release.Refinement.MatchPaths

namespace RVL20A2L
open Benitoite.Release.Refinement
noncomputable section

theorem let_inv {P B Ψ Q C Γ Φ Rs code m n a e L}
    (hm : HasTypeCQ P B Ψ Q C Γ Φ Rs code a e L) (hcode : code = .letIn m n) :
    ∃ a0 b ε, HasTypeCQ P B Ψ Q C Γ Φ Rs m a0 ε L ∧
      HasTypeCQ P B Ψ Q C (Γ.extend a0) (Φ.map Pred.lift) (Rs.map (Ty.shiftV 1 0))
        n (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 L) ∧
      Ty.Declared P C Γ b ∧ HasTypeCQ P B Ψ Q C Γ Φ Rs (.letIn m n) b ε L ∧
      Eff.Covers Γ Φ e ε ∧ Ty.LeQ P Γ Φ b a := by
  match hm with
  | hh@(.C_Let h1 h2 h3) =>
    cases hcode
    exact ⟨_, _, _, h1, h2, h3, hh, Eff.Covers.refl _ _ _, .refl⟩
  | .C_Normal hh =>
    obtain ⟨a0, b, ε, h1, h2, h3, h4, h5, h6⟩ := let_inv hh hcode
    exact ⟨a0, b, ε, h1, h2, h3, h4, h5, .trans h6 (.convert (Ty.norm_idem _).symm)⟩
  | .C_Sub hh hle hcov _ _ _ =>
    obtain ⟨a0, b, ε, h1, h2, h3, h4, h5, h6⟩ := let_inv hh hcode
    exact ⟨a0, b, ε, h1, h2, h3, h4, hcov.trans h5, .trans h6 hle⟩
  | .C_Eff hh hcov =>
    obtain ⟨a0, b, ε, h1, h2, h3, h4, h5, h6⟩ := let_inv hh hcode
    exact ⟨a0, b, ε, h1, h2, h3, h4, hcov.trans h5, h6⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hcode
termination_by structural hm

theorem Ty_bind_up (a : Ty) (cap : Capture) :
    substTyValues (upSubst 1 cap.env) (a.shiftV 1 0) = (cap.closeTy a).shiftV 1 0 := by
  exact Ty.bind_shiftV_values a 1 cap.env

theorem Eff_bind_up (e : Eff) (cap : Capture) :
    substEffValues (upSubst 1 cap.env) (e.shiftV 1 0) = (cap.closeEff e).shiftV 1 0 := by
  exact Eff.bind_shiftV_values e 1 cap.env

theorem cont_R_wf {P B σ Ψ R ε k a b Eb Re} (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (hRe : Re = none) : ∀ r, R = some r → r.WF 0 0 0 := by
  induction h with
  | K_Empty => subst hRe; intro r hr; cases hr
  | K_Mark _ ha _ => intro r hr; cases hr; exact ha.wf
  | K_Update | K_Guard => intro r hr; cases hr
  | K_Let _ _ _ _ _ ih | K_Release _ _ _ _ _ ih | K_Drop _ _ _ ih | K_Sub _ _ ih => exact ih hRe
  | K_Handle _ _ _ _ _ _ _ _ _ _ _ _ _ ih => exact ih hRe
  | K_Handle_Fail _ _ _ _ _ _ _ _ _ _ _ _ _ ih => exact ih hRe

/-- 実際の E_Let の一歩。前半は広げた全体効果で、後半は一束縛の閉包で型付ける。 -/
theorem e_let_post {P B σ Ψ R q m n a e1 e k b Eb}
    (hp : P.WellFormed) (ht : P.WellTyped B) (hA : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e1) (hsub : Eff.Sub e1 e)
    (hk : ContTy P B σ Ψ R e k a b Eb none)
    (hv : q.view = .letIn m n) (had : (Closure.mk q.capture n).Adequate σ) :
    ∃ a' e1', ClosureTy P B Ψ [] R (.mk q.capture m) a' e1' ∧ Eff.Sub e1' e ∧
      ContTy P B σ Ψ R e (.letF (.mk q.capture n) :: k) a' b Eb none := by
  have hann := hq.annotation
  simp only [bindParams, List.reverse_nil, List.map_nil, List.nil_append] at hann
  obtain ⟨cap, Γ, Φ, Rs, code0, as, es, L, ρ, rfl, hc, hb, hL, hR, rfl, rfl, hrs⟩ := hq.open_zero
  have hform : ∃ m0 n0, code0 = .letIn m0 n0 := by
    cases code0
    case letIn => exact ⟨_, _, rfl⟩
    case checkAt _ _ _ bs _ _ _ =>
      exfalso; cases bs <;> (simp only [Comp.resolveLocals] at hv; injection hv)
    all_goals (exfalso; simp only [Comp.resolveLocals] at hv; injection hv)
  obtain ⟨m0, n0, rfl⟩ := hform
  simp only [Comp.resolveLocals] at hv
  injection hv with hv1 hv2
  subst hv1; subst hv2
  obtain ⟨a0, c, ε, h1, h2, hdc, hlet, hcov, hle⟩ := let_inv hb rfl
  have hle' : Ty.LeQ P [] [] (cap.closeTy c) (cap.closeTy as) := hle.bind (valEnv cap.env) hc.transport
  have hcc := capture_comp_annotation hp ht hA hw hs hd hc hlet
  have hup : Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy c) (cap.closeEff es))) :=
    ⟨⟨hcc.wf, hann.wf.2⟩, ⟨hcc.sorted, hann.sorted.2⟩, ⟨hcc.declared, hann.declared.2⟩⟩
  -- 前半を全体効果へ広げる
  have h1' : HasTypeCQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs m0 a0 es L := .C_Eff h1 hcov
  have h2' := HasTypeCQ.C_Eff h2 (hcov.shiftV 1 0 (Δ := Γ.extend a0) (Ψ := Φ.map Pred.lift))
  obtain ⟨hfront, hback⟩ := capture_let_effect_annotations hp ht hA hw hs hd hc h1' hup
  have hq1 := ClosureTy.capture_resolved_closed hc h1' hL hfront hR hrs
  have hopen := open_comp_annotation hp ht hA hw hs hd hc.contextRegular h1
  have hclosea := capture_comp_annotation hp ht hA hw hs hd hc h1
  have hRw := cont_R_wf hk rfl
  have hRid : R.map (Ty.shiftV 1 0) = R := by
    cases R with
    | none => rfl
    | some r => simp only [Option.map_some]; rw [Ty.shiftV_of_wf_zero (hRw r rfl)]
  have hrc : cap.closeRAt 1 (Rs.map (Ty.shiftV 1 0)) = R := by
    rw [←hRid]
    subst hR
    cases Rs with
    | none => rfl
    | some r0 =>
      simp only [Capture.closeRAt, Capture.closeR, Option.map_some, Capture.closeTyAt, Capture.closeTy]
      congr 1
      exact Ty_bind_up r0 cap
  have hbody := ClosureTy.mk (ss := [a0]) (Rs := Rs.map (Ty.shiftV 1 0)) (a := c.shiftV 1 0)
    (e := Eff.shiftV 1 0 es) (L := localExtend 1 L) hc
    (by simpa only [bindParams_single, List.length_cons, List.length_nil, Nat.zero_add, liftMany_one] using h2')
    (by simpa only [List.length_cons, List.length_nil, Nat.zero_add] using hL.localExtend hw) rfl
    (by intro t ht; cases List.mem_singleton.mp ht; exact hopen)
    (by intro t ht; cases List.mem_singleton.mp (by simpa using ht); exact hclosea)
    hrc
    (by simpa only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add] using
      (show Ty.Annotation P [] (bindParams [] [cap.closeTy a0]) (cap.closeTyAt 1 (c.shiftV 1 0)) from
        ⟨hback.wf.1, hback.sorted.1, hback.declared.1⟩))
    (by simpa only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add] using hback)
    (by
      intro r hr
      obtain ⟨r0, h0, rfl⟩ := Option.map_eq_some_iff.mp hr
      exact (ShiftMap.outerValue Γ (some (a0.shiftV 1 0))).declared (hrs r0 h0))
    (by
      intro r hr
      have hd0 : r.Declared P [] [] := by
        cases hx : Rs with
        | none => simp [Capture.closeR, hx] at hR; rw [←hR] at hr; cases hr
        | some rs =>
          have he : cap.closeTy rs = r := by simpa [Capture.closeR, hx, hr] using hR
          rw [←he]; exact (hrs rs hx).bind_values hc.substOk.declaration
      have := (ShiftMap.outerValue [] (some ((cap.closeTy a0).shiftV 1 0))).declared hd0
      rw [Ty.shiftV_of_wf_zero (hRw r hr)] at this
      simpa [Ctx.extend, bindParams] using this)
  have h3 := Ty_bind_up c cap
  have h4 := Eff_bind_up es cap
  have hbody' := hbody
  simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
    Capture.closeTyAt, Capture.closeEffAt, h3, h4] at hbody'
  conv at hbody' => arg 5; rw [←hRid]
  exact ⟨_, _, hq1, hsub, ContTy.K_Let hbody' had ⟨hclosea.wf, hclosea.sorted, hclosea.declared⟩ hsub (.K_Sub hk hle')⟩

end
end RVL20A2L
#print axioms RVL20A2L.e_let_post
```

### lam1.lean

```lean
import Benitoite.Release.Refinement.CaptureRegularity

namespace RVL20A2M
open Benitoite.Release.Refinement
noncomputable section

theorem env_many (ws : List Val) (cap : Capture) (i : Nat) :
    (cap.extendMany ws).env (i + ws.length) = cap.env i := by
  induction ws generalizing cap i with
  | nil => rfl
  | cons w ws ih =>
    have := ih (cap.extend w) (i+1)
    simp only [Capture.extendMany, List.foldl_cons, List.length_cons] at this ⊢
    rw [show i + (ws.length + 1) = i + 1 + ws.length by omega]
    exact this

theorem ty_shift_env (ν μ : Nat → Val) (k : Nat) (h : ∀ i, ν (i+k) = μ i) (a : Ty) :
    substTyValues ν (a.shiftV k 0) = substTyValues μ a := by
  simp only [substTyValues, Ty.bind, ← Ty.rawSubstV_eq_rawBind, valEnv,
    Ty.shiftV_eq_renameTy, renameTy_eq_rawSubstV, Ty.rawSubstV_comp]
  congr 2
  funext i
  simp [shiftIndex, termBind?, h]

theorem eff_shift_env (ν μ : Nat → Val) (k : Nat) (h : ∀ i, ν (i+k) = μ i) (e : Eff) :
    substEffValues ν (Eff.shiftV k 0 e) = substEffValues μ e := by
  simp only [substEffValues, Eff.bind, ← Eff.rawSubstV_eq_rawBind, valEnv,
    Eff.shiftV_eq_renameEff, renameEff_eq_rawSubstV, Eff.rawSubstV_comp]
  congr 2
  funext i
  simp [shiftIndex, termBind?, h]

/-- 非依存の関数: 明示の fn 注釈だけで、全実引数を捕捉した本体の結果と効果の閉じた注釈を得る。 -/
theorem lam_body_effect {P B Ψ R Γ Φ cap ns ps r e} (ws : List Val)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (ha : Ty.Annotation P [] Γ (.fn ns ps r e)) :
    Ty.Annotation P [] [] (.dependentFn (.done
      ((cap.extendMany ws).closeTy (r.shiftV ws.length 0))
      ((cap.extendMany ws).closeEff (Eff.shiftV ws.length 0 e)))) := by
  have h := capture_function_result_effect hc ha
  have h1 : (cap.extendMany ws).closeTy (r.shiftV ws.length 0) = cap.closeTy r :=
    ty_shift_env _ _ _ (env_many ws cap) r
  have h2 : (cap.extendMany ws).closeEff (Eff.shiftV ws.length 0 e) = cap.closeEff e :=
    eff_shift_env _ _ _ (env_many ws cap) e
  rw [h1, h2]; exact h

/-- 依存列: 閉じた依存列の注釈と全実引数の型付けから、値を具体化した done の注釈を得る。 -/
theorem dep_body_effect {P B Ψ} {cap : Capture} {t vs as a e}
    (ht : Ty.Annotation P [] [] (.dependentFn (cap.closeTel t)))
    (hargs : Tel.arguments (cap.closeTel t) vs = some (as, a, e))
    (hvs : HasTypeVsQ P B Ψ Benitoite.Release.Qempty [] [] [] vs as) :
    Ty.Annotation P [] [] (.dependentFn (.done a e)) :=
  open_telArgs_annotation
    (HasTypeTelArgsQ.of_arguments hargs hvs ht (by intro i a hi; cases hi) (Tel.norm_idem _))

end
end RVL20A2M
#print axioms RVL20A2M.lam_body_effect
#print axioms RVL20A2M.dep_body_effect
```

### rest.lean

```lean
import Benitoite.Release.Refinement.CaptureRegularity
import Benitoite.Release.Refinement.MatchPaths
import Benitoite.Release.Refinement.DependentBeta
import Benitoite.Release.Refinement.HandlerFailure

namespace Benitoite.Release.Refinement
noncomputable section

theorem split_fail_annotated {P B σ Ψ R ε k a b Eb Re cap E0 body k1 k2}
    (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (he : k = k1 ++ .handleF cap [.fail E0 body] :: k2) :
    ∃ t ec et Rh, ContTy P B σ Ψ R ε (k1 ++ [.handleF cap [.fail E0 body]]) a t (.mk et.atoms ec.fails) Rh ∧
      ContTy P B σ Ψ Rh et k2 t b Eb Re ∧ Eff.Covers [] [] et ec ∧ Eff.Sub (.mk et.atoms ec.fails) et ∧
        Ty.Annotation P [] [] (.dependentFn (.done t ec)) := by
  induction h generalizing k1 with
  | K_Empty _ _ => cases k1 <;> simp at he
  | K_Sub _ hl ih =>
    obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
    exact ⟨t,ec,et,Rh,.K_Sub h1 hl,h2,h3,h4,h5⟩
  | K_Let hq had ha hs _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Let hq had ha hs h1,h2,h3,h4,h5⟩
  | K_Mark _ ha ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Mark h1 ha,h2,h3,h4,h5⟩
  | K_Update hl ha _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Update hl ha h1,h2,h3,h4,h5⟩
  | K_Release hv had hr hs _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Release hv had hr hs h1,h2,h3,h4,h5⟩
  | K_Drop hl hs _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Drop hl hs h1,h2,h3,h4,h5⟩
  | K_Guard hc hv ho hs hL har hr hx heq hR ht hef hb hsub hp _ had ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Guard hc hv ho hs hL har hr hx heq hR ht hef hb hsub hp h1 had,h2,h3,h4,h5⟩
  | K_Handle ht hc hb hcap hcs hR hty hec heb ha has hr had ih =>
    cases k1 with
    | nil => cases he; cases hcs
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Handle h1 hc hb hcap hcs hR hty hec heb ha has hr had,h2,h3,h4,h5⟩
  | @K_Handle_Fail R0 ε0 ec0 rest E cap0 cs0 tail t0 b0 E0' Re0 Γ Φ Rs ts ecs Es
      ht hc hnf hcap hcs hR hty hec hE hr hcov ha had ih =>
    cases k1 with
    | nil =>
      cases he
      have hsub : Eff.Sub (.mk ε0.atoms ec0.fails) (.mk ε0.atoms ec0.fails) := ⟨fun _ h => h,fun _ h => h⟩
      have hcsa := hcs
      refine ⟨_,ec0,ε0,_,?_,ht,hcov,hcov.widen_atoms.2,?_⟩
      refine .K_Handle_Fail (ε := .mk ε0.atoms ec0.fails) (rest := rest) (ec := ec0) (.K_Empty hsub ha) ?_ hnf hcap hcs hR hty hec hE hr ?_ ha had
      · exact ⟨fun a ha => hc.1 a ha,fun t ht => by obtain ⟨_,hx,_⟩ := ht; rw [hnf.1] at hx; cases hx⟩
      · exact ⟨fun a ha => hcov.1 a ha,fun _ h => h⟩
      · rw [←hty,←hec]; exact hcsa.capture_result_effect hcap
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Handle_Fail h1 hc hnf hcap hcs hR hty hec hE hr hcov ha had,h2,h3,h4,h5⟩

/-- 実際の hide の下: 閉包の捕捉から thunk の本体へ適用する。 -/
theorem rv_thunk_body {P B Ψ R Γ Φ cap m a e L}
    (hp : P.WellFormed) (ht : P.WellTyped B) (hA : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hm : HasTypeCQ P B (hideBuilders Ψ) Benitoite.Release.Qempty [] (hideConts Γ) Φ none m a e L) :
    Ty.Annotation P [] [] (cap.closeTy a) :=
  capture_comp_annotation hp ht hA hw.hide hs.hide hd.hide
    ((hc.store hA.values hw (StoreTy.preserves_hide Ψ)).hideConts_any (R' := none)) hm

/-- 閉じた捕捉を介さない開いた形の hideConts の保存。 -/
theorem rv_hideConts_regular {P C Γ} (h : CaptureContextRegular P C Γ) :
    CaptureContextRegular P C (hideConts Γ) := by
  have hm : ShiftMap 0 0 Γ (hideConts Γ) := by
    refine ⟨by simp [hideConts], ?_⟩
    intro i a hi ho
    simpa [shiftIndex_zero, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi, ho⟩
  have hlen : (hideConts Γ).length = Γ.length := by simp [hideConts]
  constructor
  · intro i a hi
    rw [hlen]; exact h.1 i a (hideConts_lookup.mp hi).1
  · intro i a hi
    have hh := h.2 i a (hideConts_lookup.mp hi).1
    simpa only [Ty.shiftV_zero] using And.intro (hm.captureSorted hh.1) (hm.captureDeclared hh.2)

/-- K_Handle の節の本体: sg.context の開いた三条件は Γ の三条件と注釈から作れるか（C=[] 版）。 -/
theorem rv_K_Handle_regular_premise {P B Ψ R Γ Φ cap}
    (h : CaptureOk P B (hideBuilders Ψ) R Γ Φ cap) (hw : Ψ.WF) (hs : Ψ.Sorted)
    (hd : StoreTy.Declared P Ψ) : CaptureContextRegular P [] Γ ∧ (hideBuilders Ψ).WF ∧
      (hideBuilders Ψ).Sorted ∧ StoreTy.Declared P (hideBuilders Ψ) :=
  ⟨h.contextRegular, hw.hide, hs.hide, hd.hide⟩

/-- 実際の閉包: 通常の値と Fail を持つ継続の場所を捕捉した環境。 -/
def rvE : Eff := Eff.singleFail (.base .string)
def rvK : Ty := .cont (.base .unit) (.base .boolean) rvE
def rvΨ : StoreTy := fun l => if l = 0 then some (.cont (.base .unit) (.base .boolean) rvE none) else none

theorem rvE_canon : rvE.Canonical := by
  simp [rvE, Eff.Canonical, Eff.singleFail, Eff.norm, Ty.normTys, Ty.norm_idem]

theorem rvE_wf : Eff.WF 0 0 0 rvE := ⟨trivial, trivial⟩

theorem rvK_wf : rvK.WF 0 0 0 := ⟨trivial, trivial, rvE_wf, rvE_canon⟩

theorem rvK_close (cap : Capture) : cap.closeTy rvK = rvK := by
  have h := Ty.substV_of_wf_zero rvK_wf (valEnv cap.env).values
  have hn : rvK.norm = rvK := by
    have hc : rvE.norm = rvE := rvE_canon
    simp [rvK, Ty.norm, hc]
  exact h.trans hn

theorem rv_store : rvΨ.WF ∧ rvΨ.Sorted ∧ ∀ P, StoreTy.Declared P rvΨ := by
  refine ⟨?_, ?_, ?_⟩
  · intro l x hl
    simp only [rvΨ] at hl
    split at hl
    · cases hl; exact ⟨trivial, trivial, rvE_wf, rvE_canon, by simp⟩
    · cases hl
  · intro l x hl
    simp only [rvΨ] at hl
    split at hl
    · cases hl; exact ⟨trivial, trivial, trivial, trivial⟩
    · cases hl
  · intro P l x hl
    simp only [rvΨ] at hl
    split at hl
    · cases hl; exact ⟨trivial, trivial, ⟨trivial, trivial⟩, by simp⟩
    · cases hl

theorem rv_real_closure (P : Program) (B : Builtins)
    (hp : P.WellFormed) (ht : P.WellTyped B) (hA : B.CoreAssumptions P)
    (hc : ConstOK B .unit) :
    ∃ Γ cap, Γ ≠ [] ∧ CaptureOk P B rvΨ none Γ [] cap ∧
      Ty.Annotation P [] [] (cap.closeTy (.base .boolean)) ∧
      Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy (.base .boolean)) (cap.closeEff (Eff.shiftV 1 0 rvE)))) := by
  obtain ⟨hw, hs, hd⟩ := rv_store
  have hc0 := CaptureOk.empty P B rvΨ none
  have hv : HasTypeVQ P B rvΨ Benitoite.Release.Qempty [] [] [] (.const .unit)
      (Capture.empty.closeTy (.base .unit)) := .V_Const hc
  have hc1 := hc0.extend (a := .base .unit) ⟨trivial, trivial, trivial⟩ hv trivial
  have hc2 := hc1.extendCont (b := .base .unit) (t := .base .boolean) (e := rvE)
    (b' := .base .unit) (t' := .base .boolean) (e' := rvE) (l := 0)
    ⟨trivial, trivial⟩ ⟨trivial, trivial⟩ ⟨trivial, trivial⟩ (rvK_close _)
    (by rw [show Capture.closeTy _ (Ty.cont _ _ _) = rvK from rvK_close _]; exact rvK_wf)
    (by simp [rvΨ]) (by intro r hr; cases hr)
  have hb : HasTypeCQ P B rvΨ Benitoite.Release.Qempty [] (Ctx.extend (Ctx.extend [] (.base .unit)) rvK) [] none
      (.resume (.var 0) (.const .unit)) (.base .boolean) (Eff.shiftV 1 0 rvE) [] :=
    .C_Resume (b := .base .unit) (by rfl) (.V_Const hc) trivial
  exact ⟨_, _, by simp [Ctx.extend], hc2, capture_comp_annotation hp ht hA hw hs (hd P) hc2 hb,
    hc2.continuation_result_effect hw hs (hd P) (i := 0) (b := .base .unit) rfl⟩

end
end Benitoite.Release.Refinement
#print axioms Benitoite.Release.Refinement.split_fail_annotated
#print axioms Benitoite.Release.Refinement.rv_thunk_body
#print axioms Benitoite.Release.Refinement.rv_real_closure
#print axioms Benitoite.Release.Refinement.rv_hideConts_regular
```

## 取りまとめの追記

中2件と軽4件を群 A2 の再開で直した。関門 (a) は通過とする。これは結果の形成の供給についての判定であり、状態全体の保存は後続の群に残る。
