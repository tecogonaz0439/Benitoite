# RV-L20.a1: 形式化の群 L20 A1 の独立レビュー

対象: `m014/l20.a1` の未コミットの差分（基準 `67135be2`）、`l20/a1/`。基準: `l20/detail.md` の S00 と L20.01〜.03、依頼文。2026-11-02。

## 総合判定

**条件付き可**（重0・中1・軽2、計3件）。S00 の定義、ストアの全追随、署名の変更、公理は正しい。条件は、`.used` の形成の公開定理が S01 の入力の形になっていない中1の処置である。A1 で足すか、L20.04/.05 の完了条件へ明示して送るかを取りまとめが選ぶ。

## 所見

### 中1: 形成の公開定理が `StoreOk` を前提とし、S01 の motive と隠したストアで使えない（読めば確定。三条件の版は Lean で確認）

- 箇所: `formal/Benitoite/Release/Refinement/StateTyping.lean` の `StoreOk.cont_result_annotation`（220行）、`StoreOk.cont_annotation`（226行）、`StoreOk.reference_annotation`（211行）、`StoreOk.lazy_annotation`（215行）。`l20/a1/results.md`「公開定理と境界」。
- 問題: 結論は任意の `C`・`Γ` の `Ty.Annotation` で正しい。一方、`detail.md` S01 の `open_comp_annotation`・`capture_comp_annotation` は `Ψ.WF → Ψ.Sorted → StoreTy.Declared P Ψ` だけを受け、`StoreOk` を持たない。S00 も「捕捉への系はWF/Sorted/Declaredの三つだけを受ける」と定める。本体の導出のストアは `hideBuilders Ψ`（`V_Lam`・`C_Lazy`・`HasFailureClause.one` など）であり、`hide_builder_boundary` のとおり builder が残れば `StoreOk` は成り立たない。したがって S01 の `C_ResumeL`・`C_ResumeLNorm`・`V_LocRef`・`V_LocLazy` の枝はこれらの定理を呼べず、同じ射影を書き直すことになる。`ImageOk.contLoc` が読む `.cont b t e` 全体の形成の補題もない。S01a の「locref_annotation/used_annotation で確認」の入力は本番に残っていない。
- 確認: 末尾の入力の `cont_result_three`・`resumeL_hidden`・`cont_ty` が通る。定義の変更なしに三条件から閉じる。
- 修正案: `StoreTy.reference_annotation`・`lazy_annotation`・`cont_result_annotation`・`cont_annotation`（と `cont` 全体の形成）を `hw hs hd hl` を受ける形で公開し、`StoreOk` の四定理はその包装にする。境界に、隠したストアの場所から任意の `C`・`Γ` の注釈を得る正例を足す。追加は十数行で、既存の署名は変えない。L20.05 へ送るなら完了条件に名指しで書く。

### 軽1: 負例が `t` だけで、`.builder (.list a)` の欄は本番の読者も境界もない（読めば確定）

- 箇所: `l20/a1/boundary.lean` の `rejected_used`。`formal/.../StoreTransport.lean` の `LocTy.Sorted`。
- 問題: `ref`・`lazy`・cont の `e` の欄を落とすと accessor のビルドが壊れ、cont の `b` の欄を落とすと割当ての組立てが壊れる。`.builder (.list a)` の枝を `True` へ弱めても、本番のビルドと境界は通る（推論。変異は実行していない）。E_BuilderNew の後続の入力だけが検出する。
- 確認: 末尾の `no_b`・`no_ref`・`no_lazy`・`no_list` のとおり、今の定義はこれらを拒む。実害はない。
- 修正案: 境界に末尾の四つの負例と、`e` の負例を加える。

### 軽2: 設計書に変更の経緯の文がある（読めば確定）

- 箇所: `docs/design/07-quality/07-04-formal-semantics.md` 100行の末尾「型付け規則と主な十の移送の言明の字面は変えていない。」
- 問題: 設計書は今の内容を書く。この文は改造の前後の比較であり、`results.md` に記録済みである。
- 修正案: 文を消す。

## 観点ごとの確認

| 観点 | 結果 |
|---|---|
| 1. 定義 | `LocTy.Sorted`・`StoreTy.Sorted`・`StoreOk` は S00 と字面が一致する（改行のみ差）。`r` は含まない。`StoreTy.Sorted.hide`・`StoreTy.Declared.hide` の言明も S00 と一致する |
| 2. 前提と境界 | 中1のほかに過強の前提はない。`Γ` は任意である。`cont_annotation` も `Ty.Annotation.closed_context` で任意の文脈へ移る（`cont_annotation_any`）。`accepted_unsorted_return` は全欄を証明した実際の `StoreOk` である。`rejected_used` はレビュー重1と同じ `badT`・使用済みセル・コードで、`counterexample_other_fields`・`counterexample_code_typed` が拒否の理由を新しい欄へ切り分ける。`boundary.lean` を再実行し終了0 |
| 3. 割当て | 署名の変更は `allocate_continuation` の三引数だけ（差分を通読）。`allocate_reference`・`allocate_lazy` は既存の `ht.sorted` を使い、Sorted の仮定を足していない。`operation_one` は割当て前の `hra`・`han` から供給する。E_OpFail の e は `opfail_row`（`CaptureOk` と `RowAnnotations`）、b は `opfail_input`（`V_Raise` の注釈）で形を確認した。閉じた注釈を raise の導出から取り出す経路と E_OpPrim の b は未証明で、`hw` が同じ注釈を要るので形は同じという読みに留まる（推測、.103/.104 の範囲） |
| 4. 言明と公理 | 十言明の4ファイルと `Typing.lean` は差分なし。`SubstTyping.lean` の SHA-256 は `ten-statements.json` と一致する。`sorry`・`axiom` の宣言は `formal/Benitoite` に0件。`lake build` は774ジョブで成功。新規と主要の36宣言の `#print axioms` は `propext`・`Classical.choice`・`Quot.sound` だけ。`lakefile.toml`・`Benitoite.lean` は不変で、`import Benitoite` から全対象が見える |
| 5. 設計書 | 01-12・07-04 の記述は Lean と一致し、処理系の未実装を断定していない。軽2を除き規約に合う |
| 6. 規約 | `l20/a1/` に手元の絶対パス、docs/todo へのリンク、`work/` の参照、「費用」なし。100 KB を超えるファイルなし。設計書の差分も同じ。新しい Lean のコメントに作業の ID なし |

宣言の数（新規17・既存変更22）と本番の増分97行は差分と一致する。

## 補助の入力（`lake env lean -M 12288`、終了0）

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace RV
noncomputable section
/-- 三条件だけの版（S01 の motive の入力の形） -/
theorem cont_result_three {P : Program} {Ψ : StoreTy} {l b t e r C Γ}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.cont b t e r)) : Ty.Annotation P C Γ t :=
  (show Ty.Annotation P [] [] t from
    ⟨(hw l _ hl).2.1, (hs l _ hl).2.1, (hd l _ hl).2.1⟩).closed_context

theorem resumeL_hidden {P : Program} {B σ Ψ μ l b t e r} {C Γ}
    (hs : StoreOk P B σ Ψ μ)
    (hl : hideBuilders Ψ l = some (.cont b t e r)) : Ty.Annotation P C Γ t :=
  cont_result_three hs.wf.hide hs.sorted.hide hs.declared.hide hl

/-- 閉じた潜在効果の注釈は任意の文脈へ移せる -/
theorem cont_annotation_any {P : Program} {B σ Ψ μ l b t e r C Γ}
    (hs : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.cont b t e r)) :
    Ty.Annotation P C Γ (.dependentFn (.done t e)) :=
  (hs.cont_annotation hl).closed_context

/-- contLoc が読む cont 型全体 -/
theorem cont_ty {P : Program} {B σ Ψ μ l b t e r}
    (hs : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.cont b t e r)) :
    (Ty.cont b t e).Sorted [] := by
  have h := hs.sorted l _ hl
  exact ⟨h.1, h.2.1, h.2.2⟩

/-- E_OpFail の e: failure.one の行注釈を元の捕捉で閉じる -/
theorem opfail_row {P B Ψ R Γ Φ cap ecs}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (he : RowAnnotations P [] Γ [ecs]) :
    sortedEff [] (cap.closeEff ecs) := by
  exact (hc.substOk.annotation (he ecs (by simp))).sorted.2.2

/-- E_OpFail の b: raise の fn 注釈の結果 -/
theorem opfail_input {P : Program} {t e : Ty}
    (h : Ty.Annotation P [] [] (.fn ["error"] [e] t (Eff.singleFail e))) : t.Sorted [] :=
  h.sorted.2.1

/-- 新しい不変条件の残りの欄の負例。b・e・ref・lazy・builder list。 -/
def badT : Ty := .refined (.base .integer) (.eq (.boolean true) (.boolean true))
theorem bad_unsorted : ¬ badT.Sorted [] := by
  simp [badT, Ty.Sorted, Pred.Sorted, Term.HasSort, Term.Shape]
theorem no_b {P B σ Ψ μ l t e r} (hl : Ψ l = some (.cont badT t e r)) : ¬ StoreOk P B σ Ψ μ :=
  fun h => bad_unsorted (h.sorted l _ hl).1
theorem no_ref {P B σ Ψ μ l} (hl : Ψ l = some (.ref badT)) : ¬ StoreOk P B σ Ψ μ :=
  fun h => bad_unsorted (h.sorted l _ hl)
theorem no_lazy {P B σ Ψ μ l} (hl : Ψ l = some (.lazy badT)) : ¬ StoreOk P B σ Ψ μ :=
  fun h => bad_unsorted (h.sorted l _ hl)
theorem no_list {P B σ Ψ μ l} (hl : Ψ l = some (.builder (.list badT))) : ¬ StoreOk P B σ Ψ μ :=
  fun h => bad_unsorted (h.sorted l _ hl)

/-- hide の逆向きの空虚でないこと: hide は cont を保ち builder だけ隠す -/
example (Ψ : StoreTy) (l b t e r) (h : Ψ l = some (.cont b t e r)) :
    hideBuilders Ψ l = some (.cont b t e r) := by simp [hideBuilders, h]
end
end RV
```

## 取りまとめの追記

中1・軽1・軽2は群 A1 の再開で直した。中1は L20.04 へ送らず、S01 の入力の形を先に固定するためこの群で閉じた。
