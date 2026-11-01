# L00b.15: 再レビューの3欄の移行の結果

**旧20欄で移行が必須かつ未着手なのは sig_scoped の1欄だけである。** release_exists・sat_unconstrained・admits_sat を新しい判断で CoreAssumptions に移した。sig_scoped は足していない。Refinement に PrimSig.Scoped がなく、依存列と型・範囲・値の束縛に合う形を定める L20・G08 の義務として残す。

2026-11-01。B_WORK は `8819025a0a35c9bac7e78fb97c7dff00829228db`、指定ブランチは `m014/l00b.15` である。レビュー原本の「再レビュー」と末尾の追記、plan の先頭の判断、補助入力 rv-15-t2.lean を読んで処置した。git の照合・操作はしていない。今回の本番 Lean の変更は ConstraintAssumptions.lean の三欄だけで、ContTy・StateTyE・型付け・遷移の規則、Rust、plan、レビュー原本と rv-* は変更していない。work と L10 は実行していない。

## 前提の新旧と決定の差

| 欄 | 旧 Release | 今回の Refinement |
|---|---|---|
| release_exists | 空の型・値文脈で opaqueTop o の型を持つ全資源値について、解放応答が存在 | 新 HasTypeV P B Ψ [] [] [] v (opaque o (fixed Top)) と isResource o=true から同じ存在。空の事実文脈を加えた新判断を使い、Ground/Adequate/Normal で量化を狭めない |
| sat_unconstrained | Ty.WF 0 0 t から B.sat [] t {} | 値の名前空間を加えた Ty.WF 0 0 0 t から B.sat [] t.norm {}。新 SatAll の正規形読みと合わせ、Annotation 等の追加条件なし |
| admits_sat | lookup と s.admits C ts から SatAll B C ts s.tparams | lookup と s.admits C (Ty.normTys ts) から SatAll B C ts (s.tparams.map TParamDecl.constraints)。個数も結論し、別の個数の前提で弱めない |

決定の理由と使用先は [theorems.md](theorems.md#3欄の移行の決定の記録) にある。三欄の言明を移したことと、それを使う全状態の保存・進行を証明したことを区別する。新しい全状態の主定理はまだない。

## 所見ごとの処置と閉じた正例

| 所見 | 処置 |
|---|---|
| 再中1 | 三欄を本番へ追加。rv-15-t2.lean の定義と全欄の正例を boundary.lean の Boundary15Full へ移し、追加欄を満たす形に閉じ直した。sig_scoped は L20 に残した |
| 再軽1 | 旧 ShapeOk.inst_eff_mem 相当を **G05・L20** の義務として名指し。ShapeOk と BuiltinArgs、opEff=some l から具体化後 e に同じ名前の原子があることを述べ、single の rvar 0 は rs で置き換わると明記。本番には未追加 |
| 再軽2 | `.single` の single_shape と CoreAssumptions 全欄の assumptions、存在を明示する core_nonempty を boundary.lean に置いた |
| 再軽3 | ShapeOk.single の署名の対象引数は opaque o (rvar 0) で、scoped の宣言を受理しないことを **L50 の実表の義務**へ追加。checkedAt 等の値は scoped_forget で opaque へ渡す |

[boundary.lean](boundary.lean) の新しい三つの定理は次のとおりである。

| 名前（Refinement.Boundary15Full） | 結論 |
|---|---|
| assumptions | untargeted・single・PathBases・get/set を持つ具体的な表の全 CoreAssumptions |
| single_shape | opaque PathIn (rvar 0) を引数に持つ single の ShapeOk |
| core_nonempty | ∃ P B, Builtins.CoreAssumptions P B |

IO の応答は補助入力と同じ err だけである。成功値を含む任意の標準表や三モデルの充足を示したものではない。前回本番に閉じた IO/PathBases の事象の被覆と handled の非所属の7補題は、強めた CoreAssumptions の下でも既定ビルドと公理依存の検査で閉じている。今回、別の本番補題は追加していない。

新 admits_sat の結論の SatAll は個数も要求するため、原本の admits=True のままでは、型引数の個数が違う列にも SatAll を要求してしまう。境界へ移した表では型パラメータなしの三署名は個数0、get/set は個数1を admits に要求した。[model-compatibility.lean](model-compatibility.lean) の旧正例も個数1を要求するように直し、改名・値置換・型置換で個数が保たれることから欄と全利用例を閉じ直した。sat=True、署名の型・kind・効果、IO と解放の応答は保った。原本 rv-15-t2.lean は変更していない。

## 旧20欄と残り

| 分類 | 件数 | 内容 |
|---|---:|---|
| 移行済み | **19** | sat_local/admits_local の補題による導出2件を含む。今回の追加は #4 sat_unconstrained、#5 admits_sat、#20 release_exists |
| 必須で未着手 | **1** | #1 sig_scoped。L20・G08。旧 PresBase/TySubstMain/Regularity/PresMain の使用先を theorems に保持 |
| 不要 | **0** | 不要と判定した欄なし |
| 合計 | **20** | TargetAgreement は別構造体なので数えない |

代表の分類は、.14a/.14b/.14b-paths/.14c が「閉じた」、.14d/.14e が「一部」のままである。.14a/.14b は共通の本体から両状態の型付けと遷移を構成し、開始の StateTyE の逆転を含まない。ほかの四つは開始の StateTyE を入力に取る。

残りは、sig_scoped、ShapeOk.inst_eff_mem 相当とその継続末尾への伝播、三欄を使う E_OpFail/E_OpPrim の保存・解放の進行への接続、および既存 G/H の一般化である。L50/L60 は追加した三欄と ShapeOk の対象引数を実表で照合し、L70 は主定理へ合成する。

L20 の39〜90時間、L40 の18〜42時間、合計57〜132時間は、引き続き既存枠へ合わせた確度のない配分である。三欄を移した所要を差し引いて確かな残時間に見せる再見積りはしていない。レビュー・処置・設計者の判断の待ちを含まない。Nat/WF・捕捉環境・閉じた評価の方式を変える根拠は今回も見つからず、旧前提の移行と方式の適否を区別する。

設計者の見直し対象は次の8件になった。各境界・影響・取消時の手戻りを theorems の表へ記した。

1. release_exists・sat_unconstrained・admits_sat の復帰。
2. io_op/ShapeOk と PathBases の所属。
3. state_effect と EffectsOk の復帰。
4. K_Update の結果型 Annotation。
5. ref_get/ref_set と StoreShape の kind。
6. HasTypeArmsQ の観測の添字。
7. .14b-paths の追加と D16 の前倒し。
8. groundTy の refined の枝。

## 変えた文書と照合

| ファイル | 変更した節・内容 |
|---|---|
| 01-12 | 「篩を含む状態の型付け」へ三欄の全言明を写し、正規形読み・SatAll の個数・全資源値の量化を説明。既存の見出しは変更していない |
| 07-04 | 「篩を含む形式化の信頼条件」へ三欄を追加し、19欄の対応と未移行 sig_scoped を区別 |
| theorems.md | 旧20欄の19/1/0、三欄の決定の記録、正例の個数の差、G05 の inst_eff_mem 相当、L50 の scoped の義務、見直し8件 |
| mapping.md・json・lean・mapping-origins.lean | 三欄を加え **64行267名**。境界の正例と本番未追加の補題の区別 |
| boundary.lean / model-compatibility.lean | 全欄の正例と既存利用例の追随、追加した境界の全宣言の公理依存の列挙 |
| check-documents.py と検査記録 | 見直し8件の照合。今回開始時の入力を保護し、検査を再実行 |
| RV-L00b.15-request.md | 再中1・再軽1〜3の再レビュー範囲と検査の入口 |

## 検査の結果

| 検査 | 結果 | 記録 |
|---|---|---|
| build | 終了0。既定 lake build、737ジョブ成功、sorry なし | [build の出力](build-resume-1xl_dsan.log)、6.705秒 |
| mapping | 終了0。267名の存在と型を確認 | [検査一覧](verification.json)、0.781秒 |
| mapping-origins | 終了0。同じ267名の定義元モジュールが一致 | [mapping-origins の出力](mapping-origins-resume-1xl_dsan.log)、0.723秒 |
| axioms | 終了0。164モジュール・16,190報告。propext/Quot.sound/Classical.choice のみ。sorryAx・独自公理なし | [公理の集計](axioms-summary.json)、14.694秒 |
| boundary | 終了0。全宣言と明示した定理で64報告。許可の三公理のみ。sorryAx・独自公理なし | [boundary の出力](boundary-resume-1xl_dsan.log)、1.105秒 |
| model-compatibility | 終了0。全利用例が成功、155報告。許可の三公理のみ。sorryAx・独自公理なし | [model-compatibility の出力](model-compatibility-resume-1xl_dsan.log)、1.465秒 |
| spec-examples | 終了0。根で cargo test --test spec_examples、7件成功 | [spec-examples の出力](spec-examples-resume-1xl_dsan.log)、3.375秒 |
| 文書と保護入力 | 見出しの改名/削除0、見直し8件、相対リンク成功、6489ファイルの指紋が一致 | [文書](document-check.json)・[保護入力](protected-check.json) |
| 今回の本番の変更範囲 | ConstraintAssumptions.lean だけ。他の本番 Lean、規則、plan・レビュー・rv-* は不変 | [照合](source-delta.json) |

結果の正は [verification.json](verification.json)、公理依存は [axioms-summary.json](axioms-summary.json)、文書検査は [document-check.json](document-check.json) にある。全 Lean プロセスは lakefile 又は単独実行の -M 12288 を用いた。検査後の入力は verification-inputs.json と照合し、一時ログがない場合も記録の照合は可能である。失われた生ログの内容を再検証したという意味にはしない。

再実行はリポジトリの根から `python3 <改造>/l00b.15/verify.py`、保存記録だけの照合は同じ入口の `--finalize-only`、文書検査は `python3 <改造>/l00b.15/check-documents.py` を使う。100 KB を超える生の出力又は手元のパスを含む出力は [large-records.md](large-records.md) に大きさと SHA-256 を記した。今回開始後の保護対象6489ファイルの指紋と、plan・レビュー・rv-* のハッシュを照合した。

前回の処置と記録は [resume1/README.md](resume1/README.md)、初回の記録は [initial/README.md](initial/README.md) に区別して保つ。

## 外側の時間と受け渡し

今回の開始は **2026-11-01 01:01:16 UTC**、最後の照合時刻は **2026-11-01 01:09:52 UTC**、外側の時間は **8分36秒** である。上限3時間以内で止めた。能動時間と局所検査の待ちは完全には分離していない。初回24分15秒、最初の再開18分37秒、今回の時間は別に記録し、その間のレビュー・取りまとめの待ちを担当の能動時間へ加えていない。

| 残る手順 | 担当 | 見込み |
|---|---|---|
| 三欄の言明・正例・規則の不変・4所見の処置の独立再レビュー | レビュー担当 | 不明 |
| 前提の新旧と見直し8件、O160 の再提示と受け入れ | 取りまとめ・設計者 | 不明 |
| sig_scoped と G/H の一般化・実表の照合 | L20/L40/L50/L60/L70 | 各既存枠の内数。確かな再見積りは未実施 |

この処置までで止め、L10 に進んでいない。

## 作業末の work

取りまとめが実行した。基準は `8819025a0a35c9bac7e78fb97c7dff00829228db`、コマンドは `scripts/check.sh --level work --base <基準>`、選ばれた単位は `spec_tally`・`spec_examples`・`formal_build` で、終了状態は 0、外側の時間は 90.59 秒である。実行の前に Refinement の生成物を消した。
