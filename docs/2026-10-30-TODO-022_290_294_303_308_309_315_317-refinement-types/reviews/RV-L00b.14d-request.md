# RV-L00b.14d の独立レビュー依頼（所見の処置後）

2026-11-01。RV-L00b.14d の中1・軽1〜5を処置したため、定義・言明・仮定と残件の再確認を依頼する。指定ブランチは m014/l00b.14d、B_WORK は `66c302eaec9d442d32073515772a0f036fd66762` である。git の操作はしていない。レビュー報告と rv-* は変更していない。

## 分類と変更の新旧

分類は plan の先頭の指定どおり「一部」である。[結果](../l00b.14d/results.md) と [完全署名](../l00b.14d/signatures.md) を読む。現在のセルを限定しない書戻しと、エラー・終了での更新枠の破棄を閉じた。Lazy に残る二つの一般化は、任意の ret の view の closeVal の型保存と、捕捉を持つ force の呼出し元である。どちらも L20 の全ストア・閉包・継続の保存の枠で一度だけ数え、個別の追加見込みを計上しない。

承認済みの変更は K_Update へ Ty.Annotation P [] [] a を足すことである。StateTyE が量化する ContTy は形式上強くなる。force_thunk_transition は hbody.annotation から新しい入力を渡し、ContTy.store と end_normal、update_inv と利用先を閉じ直した。StateTyE に新しい欄は加えず、遷移と既存の主定理の結論も変えない。L00b 末の再提示と、L00b.15 による01-12の写しへの反映は残る。

| 所見 | 処置 |
|---|---|
| 中1 | update_inv が Annotation を返し、lazy_update_any_cell を m/hlcell/hS なしで閉じた。旧 lazy_update_transition をこの名前へ置き換え、定数の入口からも m/hlcell を除いた。done への書戻しと2〜4時間の見込みを残件から削除 |
| 軽1 | ClosureTy.return_const と専用の private isRet を削除。既存の ret_const hA.substitutions を使う |
| 軽2 | lazy_update_pop_error/lazy_update_pop_exit を追加。E_ErrPopUpdate/E_ExitPopUpdate を含む6種類に修正 |
| 軽3 | 01-12 のソースからの到達不能と02-08の同じタスクの再入を不具合とする扱いを引いた。VM の「評価の途中」・別タスクの待機・取消と終了時の戻し方を L30 の照合へ追加 |
| 軽4 | force は呼出しを合成せず抽象の B で既存の前提から閉じるため、StoreShape.force に kind を追加しない理由を記録した |
| 軽5 | 二つの一般化を全保存の既存枠に統合し、重ねた見込みを削除した |

## 重点

1. K_Update の注釈の追加が承認の範囲内に収まるか。force の構成で追加の前提が thunk の本体から得られ、全利用先が追随しているか。.. の場合分けも含めて確認する。
2. any_cell は開始の StateTyE と closeVal の一致だけを受け取り、格納型の注釈・Sorted・現在のセルの型付けを結論として仮定していないか。
3. normal_return_tail を返り値の型 a で呼び、格納型 x の Normal を要求していないか。最終の結果型と Eb は同じか。
4. 定数の入口が既存の ret_const を使い、空でない捕捉と Φ の証拠を保つか。重複補題を別名で残していないか。
5. 更新枠を降ろす2補題が実ストアを変えず、thunk を done にしないか。UpdateCases.error_pop/exit_pop/pops_keep_thunk を確認する。
6. UpdateCases.overwrite_done が done(3) を別の適合する4へ実際に上書きする入口を使い、old_and_new_contracts が先に保持した3の型と事実を同時に保持するか。
7. 再入の抽象状態の量化を、ソースからの到達可能性と混同していないか。L30 の VM の途中の状態の照合を省いていないか。
8. 初回の共変性、Reference の不変性、契約を外した force の否定、set 後の捕捉、部分的な像と RootShape が、新しい判断でも保たれているか。
9. 全状態の保存と進行を完了へ繰り上げず、L20 の二つの一般化を既存枠で一度だけ数えているか。

## 新規ファイルの全一覧

初回からの作業用の新規ファイルと、今回加えたハッシュ・初回の記録の写しを含む。git による追跡状態の照合は行っていない。

- `formal/Benitoite/Release/Refinement/LazyInversion.lean`
- `formal/Benitoite/Release/Refinement/LazyStore.lean`
- `formal/Benitoite/Release/Refinement/LazyPreservation.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/aggregate-before.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/axioms-summary-initial.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/axioms-summary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/axioms.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/boundary-first.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/boundary-inputs-initial.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/boundary-inputs.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/boundary.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/boundary.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/build.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/large-records-initial.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/large-records.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/protected-inputs.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/public-api-second.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/public-api.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/public-api.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/results.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/resume-before.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/review-t3.log`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/signatures.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/source-delta-initial.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/source-delta.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/source-inputs-initial.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/source-inputs.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/verification-first.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/verification-initial.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/verification-second.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/verification.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14d/verify.py`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/reviews/RV-L00b.14d-request.md`

既存の本番の変更は `formal/Benitoite.lean` の初回の import 1行と、今回の `Refinement/StateTyping.lean`・`ReferenceStore.lean` である。今回変更した新規モジュールは LazyStore・LazyPreservation であり、LazyInversion は初回のままである。

指定された補助入力 `l00b.14d/rv-14d-t1.lean`・`t2.lean`・`t3.lean`・`rv-14d-k-update.patch` は取りまとめが置いた読み取り専用の入力である。レビュー報告と合わせて [protected-inputs.json](../l00b.14d/protected-inputs.json) の5本のハッシュが一致する。t1/t2 とパッチは旧署名での検討の参照とし、改変していない。t3 は本番の新しい any_cell に対してそのまま実行した。

## 検査と入力の証拠

[verify.py](../l00b.14d/verify.py) が再実行の入口、[verification.json](../l00b.14d/verification.json) が現在の結果である。

| 検査 | 結果 |
|---|---|
| 既定 lake build | 終了0、728ジョブ |
| boundary.lean | 終了0、186宣言の公理依存も確認 |
| public-api.lean | 終了0、公開20宣言と K_Update の新署名 |
| 指定された rv-14d-t3.lean | 終了0、any_cell の署名と公理依存 |
| 全差分の公理監査 | 終了0、147モジュール・15,277宣言。StateTyping/ReferenceStore を含む |

Lean のプロセスは既定ビルドと単独検査の両方で -M 12288。現在の本番・境界の依存は propext・Quot.sound・Classical.choice だけであり、sorryAx はない。大きな生出力の大きさと SHA-256 は [large-records.md](../l00b.14d/large-records.md) に初回分と今回分を区別して残した。現在の本番の入力と境界のハッシュは source-delta/source-inputs/boundary-inputs.json、再開前の本番4ファイルは resume-before.json にある。末尾が initial の記録は現在の証拠として使わない。

work、独立レビュー、取り込み・受け入れ、L00b末の再提示、L00b.15の写しは取りまとめに残す。実装担当は L00b.14e を起動せず、この再開の末で止める。自己点検を独立レビュー済みとはしない。
