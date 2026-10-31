# RV-L00b.13: 所見の対応後の確認依頼

2026-11-01。RV-L00b.13 の中1・中2・軽1・軽3・軽5を直し、軽2・軽4・軽6・軽7を後続の義務へ記録した。指定ブランチは `m014/l00b.13`、B_WORK は `40311429fea38171b53f7e909096c63222ce06e5`。今回の開始は2026-10-31 16:22:19 UTCである。git と work は実行せず、L00b.14a は未着手である。

[results.md のレビュー対応](../l00b.13/results.md#rv-l00b13-の対応結果2026-11-01)と [signatures.md](../l00b.13/signatures.md) の対応契約を先に読み、以下を確認してほしい。レビュー本文と plan.md、提供された rv-* の入力は編集していない。独立レビュー済みとは記録していない。

## 今回の本番の変更

[review-source-delta.json](../l00b.13/review-source-delta.json) は今回の開始時とのハッシュの照合で、次の五ファイルに限る。

- [AtPrepare.lean](../../../formal/Benitoite/Release/Refinement/AtPrepare.lean): groundTy の refined の枝、groundTy_notContCore、groundTy_wf の場合、AtPrepared.request。非公開の末尾の検査を finishPreparation へ分け、準備の三段階を明示した Except.bind で記述した。
- [AtInput.lean](../../../formal/Benitoite/Release/Refinement/AtInput.lean): private な parseAuthority の成功の補題、parseUrlTarget_kind、Val.reqTarget_kind。
- [AtSound.lean](../../../formal/Benitoite/Release/Refinement/AtSound.lean): checkAt.absolute。
- [AtTyping.lean](../../../formal/Benitoite/Release/Refinement/AtTyping.lean): CheckedWitness.of_prepared_request。
- [ValueFacts.lean](../../../formal/Benitoite/Release/Refinement/ValueFacts.lean): HasTypeVQ.list_element_facts と field_facts_by_type。

今回新しい本番ファイルはない。初回の新規四ファイル（ValueFacts・HeldValues・TargetTable・ModelHttp）と既定 import は保っている。初回からの全差分は [source-delta.json](../l00b.13/source-delta.json) にあり、新規4・既存6である。正式な git の差分の照合は取りまとめが行う。

## 確認点

1. **中1**: groundTy は `.refined a p => groundTy a && decide (p.WF 1)` を読み、構成的な Pred.wfDecidable を使う。groundTy_wf の既存の署名と、groundVal_ground の向きを保ったか。旧 Release.ModelHttp の定義を変えず、groundTy_embed から valueRun_embed までの交換が成立するか。
2. **中1の正負**: review-ground-boundary の Pair[String{true},String] の要求が型付き・保持可能で、cap の var 0 を使う At の準備が成功するか。closeVal の正規化で生の型引数を消していないか。残る閉じた述語 `0 ≤ 1` の例でも同じ入口を通るか。この例は、その型引数に合う欄型の宣言を使い、data の共変は新設していない。var 1 を参照する開いた述語は、判定と At の invalidTarget の両方で拒むか。
3. **中2**: AtPrepared.request は groundVal の成功と固定 reqTarget、準備結果の absolute の等号を実際の定義から得るか。parseUrlTarget_kind/reqTarget_kind は解析成功から endpoint を得るか。checkAt.absolute が同じ対象を返すか。CheckedWitness.of_prepared_request は、これらの結果を別の仮定として受け取らず、既存の型付け・準備・所属検査の成功だけで保持証拠を作るか。
4. **E_AtOk**: review-ground-boundary の prepared_raw・checked_target・at_ok_step・witness_from_preparation・reached_value_leaf が実際の E_AtOk の前提と到達値を使うか。到達値の checkedAt を型付け、その同じ値へ L00b.13 の葉を適用しているか。外側の Result と全 StateTy の保存の完成を主張していないか。
5. **軽1・3・5**: E_IfT の説明を実際に合わせたか。List 要素と型の側の data 引数の facts の二補題は rv-13-w2 と同じ契約で本番へ移ったか。境界で空でない facts を得られるか。retained_fact は実観測の some を示して facts を使うか。
6. **残る義務**: 各幅の整数/Byte、通常の checked/PathIn の正例、valKind の並置、atError を L40/L50 へ明記したか。D20/D28 の新旧対照に ground 判定の受理範囲を含めたか。中1の三入力を L30 以降の Rust/Lean の比較へ送ったか。
7. **境界と公理**: 主な定理の言明、信頼条件の欄、新しい公理、提供範囲、精密な外部状態を変更していないか。利用者の書ける形を狭めていないか。既定ビルドと六検査の終了、14,087宣言の公理依存、入力のハッシュと保護対象の一致を照合する。

## 検査

[verify.py](../l00b.13/verify.py) は既定 lake build、初回の更新した境界、レビュー対応の境界、読み取り専用の rv-13-w2、公理依存、公開署名の六検査を行う。すべて終了0である。Lean は既定ビルド・単独のプロセスとも -M 12288 を使う。新しい公開補題8本、初回から合わせた55宣言、ground の意味の照合等を含む12宣言、旧モデルとの交換五本の型を public-api.log に列挙した。

公理依存は Refinement 全133モジュールと集約、旧モデル/主定理等、二つの境界の私有・生成宣言を含む。14,087宣言の依存は propext・Quot.sound・Classical.choice だけで、sorryAx と未監査のモジュールはない。rv-13-w3 の修正前の負例はそのまま保ち、新しいファイルで正例へ反転した。RSS は計画上の非採取である。Rust/Lean の比較は未実行である。

## 文書・入力・証拠の全一覧

本依頼自身 `reviews/RV-L00b.13-request.md` も対象である。l00b.13/ の全ファイルを下に列挙する。rv-13-w2.lean と rv-13-w3.lean は取りまとめが提供した読み取り専用の入力である。initial-* は初回の成功記録、first-* は初回の途中の失敗記録であり、今回の最終成功と区別する。

- [axiom-targets.txt](../l00b.13/axiom-targets.txt)
- [axioms-summary.json](../l00b.13/axioms-summary.json)
- [axioms.lean](../l00b.13/axioms.lean)
- [axioms.log](../l00b.13/axioms.log)
- [boundary.lean](../l00b.13/boundary.lean)
- [boundary.log](../l00b.13/boundary.log)
- [build.log](../l00b.13/build.log)
- [case-inventory.txt](../l00b.13/case-inventory.txt)
- [first-boundary.log](../l00b.13/first-boundary.log)
- [first-build.log](../l00b.13/first-build.log)
- [first-inputs-sha256.json](../l00b.13/first-inputs-sha256.json)
- [first-verification.json](../l00b.13/first-verification.json)
- [initial-axiom-targets.txt](../l00b.13/initial-axiom-targets.txt)
- [initial-axioms-summary.json](../l00b.13/initial-axioms-summary.json)
- [initial-boundary.log](../l00b.13/initial-boundary.log)
- [initial-build.log](../l00b.13/initial-build.log)
- [initial-inputs-sha256.json](../l00b.13/initial-inputs-sha256.json)
- [initial-large-records.md](../l00b.13/initial-large-records.md)
- [initial-public-api.log](../l00b.13/initial-public-api.log)
- [initial-source-delta.json](../l00b.13/initial-source-delta.json)
- [initial-verification.json](../l00b.13/initial-verification.json)
- [input-stability.json](../l00b.13/input-stability.json)
- [inputs-sha256.json](../l00b.13/inputs-sha256.json)
- [large-records.md](../l00b.13/large-records.md)
- [protected-inputs.json](../l00b.13/protected-inputs.json)
- [public-api.lean](../l00b.13/public-api.lean)
- [public-api.log](../l00b.13/public-api.log)
- [public-names.json](../l00b.13/public-names.json)
- [results.md](../l00b.13/results.md)
- [review-before-sha256.json](../l00b.13/review-before-sha256.json)
- [review-ground-boundary.lean](../l00b.13/review-ground-boundary.lean)
- [review-ground-boundary.log](../l00b.13/review-ground-boundary.log)
- [review-reference.log](../l00b.13/review-reference.log)
- [review-source-delta.json](../l00b.13/review-source-delta.json)
- [rv-13-w2.lean](../l00b.13/rv-13-w2.lean)
- [rv-13-w3.lean](../l00b.13/rv-13-w3.lean)
- [signatures.md](../l00b.13/signatures.md)
- [source-delta.json](../l00b.13/source-delta.json)
- [start-inputs.json](../l00b.13/start-inputs.json)
- [verification.json](../l00b.13/verification.json)
- [verify.py](../l00b.13/verify.py)

## 申し送り

L00b.14a は、新しい実観測の facts と、AtPrepared.request・reqTarget_kind・checkAt.absolute・CheckedWitness.of_prepared_request を使える。Ground は bool の成功から得る。外部応答では受信後の元の型付けを用いる。依存βには進んでいない。

| 残る手順 | 担当・範囲 | 見込み |
|---|---|---|
| 所見対応の再確認・受け入れ | 取りまとめ。上記の定義・前提・境界・全ファイルを照合する | 不明 |
| work・正式な基準版との差分照合・取り込み | 取りまとめ。担当は実行しない | 不明 |
| L00b.14a | 受け入れ後に別途起動する依存βの代表 | 計画の2〜4時間 |
