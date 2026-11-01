# RV-L00b.15: 再レビューの3欄の移行の確認依頼

2026-11-01。B_WORK は `8819025a0a35c9bac7e78fb97c7dff00829228db`、指定ブランチは `m014/l00b.15`。対象は [レビュー原本](RV-L00b.15.md) の「再レビュー」の再中1・再軽1〜3の処置である。原本と rv-15-t1/rv-15-t2 は変更していない。git 操作、work、L10 は実行していない。

## 読む順序と範囲

1. [results.md](../l00b.15/results.md) の新旧と所見ごとの処置。
2. [ConstraintAssumptions.lean](../../../formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean) の追加三欄。今回の本番の変更はこの三欄だけである。
3. [boundary.lean](../l00b.15/boundary.lean) の Boundary15Full と、[原本 rv-15-t2.lean](../l00b.15/rv-15-t2.lean)。[model-compatibility.lean](../l00b.15/model-compatibility.lean) の個数と全利用例。
4. [theorems.md](../l00b.15/theorems.md) の旧20欄、決定の記録、G05/G08/L50、見直し8件。[mapping.md](../l00b.15/mapping.md) と01-12・07-04の信頼条件。
5. 検査記録と保存入力の照合。

| 所見 | 確かめる点 |
|---|---|
| 再中1 | release_exists が新 HasTypeV の全資源値を量化し Ground/Adequate を足していないか。sat_unconstrained が WF 0 0 0 から t.norm の無制約の sat を要求するか。admits_sat が正規形列の admits から SatAll を個数も含めて結論するか。sig_scoped を追加していないか |
| 全欄の正例 | T2 の admits=True を個数0/1へ改めた差が記録され、改名・置換で個数を保って全欄を閉じたか。IO 応答は原本と同じ err だけで、標準表や三モデルの充足へ繰り上げていないか |
| 再軽1 | 旧 ShapeOk.inst_eff_mem 相当の `ShapeOk/BuiltinArgs/opEff → ∃ ix, e.mem (name l ix)` が G05・L20 に名指しされ、single の rvar 0 の具体化と、G07/L70 への依存を明記しているか。未証明の補題を設計書へ定理として追加していないか |
| 再軽2 | Boundary15Full.single_shape、assumptions、core_nonempty が sorry なしで閉じ、全欄が空虚でないことを示すか |
| 再軽3 | ShapeOk が scoped の署名引数を受理しないことと、opaque の宣言へ scoped_forget で値を渡すことが L50 の実表の義務にあるか |
| 記録 | 旧20欄が19移行済み（導出2を含む）・1必須未着手・不要0、見直し8件で一致するか。ContTy/StateTyE/型付け/遷移/Rust/plan/レビュー/rv-* が不変か |

## 検査の入口

[verification.json](../l00b.15/verification.json) は既定 lake build、267名の存在と定義元、公理依存、boundary とモデル利用例、根での cargo test --test spec_examples を記録する。全 Lean プロセスは -M 12288。公理の正は [axioms-summary.json](../l00b.15/axioms-summary.json)、文書の正は [document-check.json](../l00b.15/document-check.json) である。

リポジトリの根から `python3 <改造>/l00b.15/verify.py`、記録だけは同じ入口の `--finalize-only`、文書は `python3 <改造>/l00b.15/check-documents.py` で照合できる。比較の入力は改造に保存しており、初回の一時領域は不要である。生ログがない場合は欠落を記録し、内容を再検証したとはしない。大きな出力の大きさと SHA-256 は large-records.md にある。

| 残る手順 | 担当 | 見込み |
|---|---|---|
| 三欄と正例、4所見の処置の独立再レビュー | レビュー担当 | 不明 |
| 前提の差・見直し8件・O160 の再提示と受け入れ | 取りまとめ・設計者 | 不明 |

sig_scoped は L20 に残し、この作業で止めている。
