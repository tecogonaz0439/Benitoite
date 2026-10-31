# RV-L00b.14c: Reference と StoreOk の代表の再レビュー依頼

2026-11-01。中1・軽1〜6の処置を終えたため、再レビューを依頼する。分類は「閉じた（列挙した代表の言明）」である。全状態の保存の完成とは区別する。指定ブランチは `m014/l00b.14c`、B_WORK は `b5a00e9aed5eb80022b01e135aaffd6f7783ff01` である。git の操作・照合、work、既存のレビュー報告の編集、L00b.14d の起動は行っていない。

## 読むもの

1. [共通依頼文](../implementation-request.md)、plan の先頭の承認済み判断、L00b.14c・分類・O051・O046。
2. [初回の独立レビューと取りまとめの追記](RV-L00b.14c.md)。報告の原本は変更していない。
3. [完全署名と補助契約の採否](../l00b.14c/signatures.md)、[結果・所見ごとの処置・残件](../l00b.14c/results.md)、[最終の全公開署名と強化した条件](../l00b.14c/public-api.log)。
4. 下記の本番ソースと [境界](../l00b.14c/boundary.lean)。CellOk.val_write/val_read、CaptureOk.store、GuardBodyTy、RootShape、CapturedFacts、ClosedCapture、MatchPaths と照合する。

## レビューする変更

新規の本番ファイルは次の3本である。

- [ReferenceStore.lean](../../../formal/Benitoite/Release/Refinement/ReferenceStore.lean)
- [ReferenceCalls.lean](../../../formal/Benitoite/Release/Refinement/ReferenceCalls.lean)
- [ReferencePreservation.lean](../../../formal/Benitoite/Release/Refinement/ReferencePreservation.lean)

既存の本番の変更は、集約 `formal/Benitoite.lean` の import 1行と [ConstraintAssumptions.lean](../../../formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean) の承認済み強化である。後者は CoreAssumptions の ref_get/ref_set と StoreShape の参照4種の value kind 条件である。HasTypeVQ/HasTypeCQ の結論とほかの前提は変えていない。前回の入力ハッシュと比べた再開時の本番の変更は ConstraintAssumptions・ReferencePreservation の2本である。

改造内の作業のファイルは、漏れなく次のとおりである。

| 場所 | ファイル |
|---|---|
| l00b.14c/ | signatures.md、results.md |
| l00b.14c/ | boundary.lean、public-api.lean、axioms.lean、verify.py |
| l00b.14c/ | build.log、boundary.log、public-api.log |
| l00b.14c/ | verification.json、axioms-summary.json、large-records.md |
| l00b.14c/ | source-delta.json、source-inputs.json、boundary-inputs.json |
| reviews/ | 本依頼 RV-L00b.14c-request.md |
| l00b.14c/（レビュー側の入力、今回変更なし） | rv-14c-t1.lean、rv-14c-t3.lean |

今回の再開で新規のファイルは追加していない。公理依存の大きな生出力は改造内にはなく、large-records.md が `<tmp>` の保存先・大きさ・SHA-256 を記録する。再実行には verify.py を使える。rv 入力のハッシュは同台本が固定して照合する。単独の Lean は -M 12288 を付け、既定ビルドも lakefile の同じ上限を使う。work は取りまとめの担当である。

## 所見ごとの重点

| 所見 | 処置と確認してほしい点 |
|---|---|
| 中1 | CoreAssumptions から reference_primitives を任意の閉じた適格な内容型について構成する。存在・PrimKind だけで型付けたことにせず、追加の kind 条件、store_admits、SignatureInstance を使う。update の保存・遷移の入力から hops を除いた。t3_not_core が constructor kind の get を持つ反例の表を拒否するか |
| 中1のモデル | 旧 Model・ModelTargets・ModelHttp の実表の get/set について、存在・PrimKind・embedTParam 後の value kind の6正例を確認する。旧モデル全体の篩側への埋め込みを完成したと記録していない。旧 Assumptions と全利用先は既定ビルドと監査に残す |
| 軽1 | 強化・弱化・矛盾した Φ の下での Reference の不変性、場所の型変更、違反値9の格納、別名の観測を否定する境界を写したか |
| 軽2 | small_get_pair・small_set_pair が Integer{self < 8} の内容型について、結論を仮定せず、開始 StateTyE から実際の Step と保存まで閉じるか |
| 軽3 | 保存だけの new/set から未使用の hc を除き、遷移と組にする入口にだけ view の条件として残したか |
| 軽4 | signatures の旧方式・別入力の記述を現在の契約として残していないか |
| 軽5 | 書込み後の CaptureOk/GuardBodyTy の保持は refl であり、実質の検査がストア拡張にあることを明記したか |
| 軽6 | L20 の残件に s4 の mk capR による get と s7 の mk capX による set を名指ししたか。update の f の仮引数名 value の条件を L30 の Rust 照合へ送ったか |

## 初回から引き続き確かめる点

4本の保存は開始の StateTyE を逆転し、同じ最終結果型・Eb と継続へ戻る。到達の型付けを入力に含めない。実際の Step は正規化した型引数の view と一致する。CellOk の内容型の照合は正規化後等号を使い、allocation は全既存セル・継続・捕捉も移す。

snapshot の Φ とセルの現内容を区別し、data の参照欄を none としたまま根の RootShape・match の事実を構成する。guard 内の set は既存の Eff.empty により型付かない。program_start の結果型 Integer と、閉じた snapshot の評価の Φ による final_typed の篩を区別する。9遷移の実行を全 let の保存の完成と数えない。

## 検査の結果

既定の `cd formal && lake build` は725ジョブで終了0。境界は239宣言、公開署名は新規3モジュールの31宣言と強化した CoreAssumptions/StoreShape、公理依存は144モジュール・15,160報告で終了0。変更した ConstraintAssumptions と新規3モジュール、集約を監査集合に含めた。依存は propext・Quot.sound・Classical.choice だけであり、sorryAx はない。

詳細は verification.json・axioms-summary.json と results.md にある。独立レビューを自己点検で代用したとは記録していない。
