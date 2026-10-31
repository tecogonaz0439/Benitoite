# RV-L00b.03: 文脈の群末レビュー依頼

2026-10-31。実装担当 Codex から取りまとめへのレビュー入力である。独立レビューと受け入れは未実施である。指定ブランチは `m014/l00b.03`、B_WORK は `5016f55febc6973855c37dc22fda24a6317e2b28`。git と作業末の work は実行していない。

[完全署名](../l00b.03/signatures.md)、[結果](../l00b.03/results.md)、[公開型](../l00b.03/public-api.md)、[検査の集計](../l00b.03/validation.json)、[公理依存](../l00b.03/axioms-summary.json)を読む。plan の同日の全変更行と、前群の signatures 第24節・第30〜33節を前提とする。処理系・設計書・plan・rv-* のファイルは変更していない。

## 確認してほしいこと

1. outer と Ordered が、self と Tel の内部束縛を保ち、通常値の外側の参照だけを許すか。長さの上限だけで循環・後方参照を通していないか。
2. Ctx.Regular と捕捉用 CaptureWF の区別が保たれているか。CaptureOk.extend/extendNone/extendTel が、非正準のソース継続の行にも Ctx.WF を要求していないか。
3. facts と Φ の再構成が型付きの値と元の事実から導かれ、拡張後の事実や意味上の全値の所属を前提へ移していないか。部分観測と None の番号を保つか。
4. Tel の宣言順と一引数の具体化から各 Annotation を供給できるか。境界の依存βは本体・実引数列・閉包・呼出し・E_Lam と遷移先の CaptureOk を実際に作っているか。
5. TypeArgsKindedAt/SignatureInstanceAt が宣言の kind 列を固定し、既存の型付けへ渡すか。既存の存在量化した K を宣言の kind 列へ同定したと誤認していないか。全本体の検査と最終 Program.WellTyped への組込みは L20/L70 に残る。
6. Program/組込みの操作の正則性が実際の opSigAt/ClauseSig と結び付くか。TargetWF は instTarget が具体化する最上位の対象とその他の型注釈を分けているか。範囲の番号の WF だけで RangeExpr の内容・kind・Canonical も検査したと主張していないか。
7. 定義・前提・結論・提供範囲の変更がないか。新規・生成・非公開の宣言と旧主定理の A-L に許可外がないか。O029/O039/O053 の本群の部分と後の全状態への組込みを区別しているか。

境界入力は名前付き定理54、準備・生成宣言込み110宣言である。初回のコンパイルの失敗と修正後の成功を結果へ記録した。新しい本番4モジュールは公開定義18・公開定理69・非公開補助8、A-L の生成宣言込み247宣言である。既定ビルドは687 jobsで終了0・sorryなし。A-L は113モジュールと既存7確認対象の12,435宣言、旧主定理の追加5宣言の計12,440宣言と、境界入力を照合し、許す三公理以外の依存は0件であった。前群の閉包 API と共有層 API の出力はともに同一である。

## 変更した既存ファイル

- [formal/Benitoite.lean](../../../formal/Benitoite.lean): 既存 import を保ち、新規4モジュールを追加した。

## 新規の本番ファイル（全件）

- [formal/Benitoite/Release/Refinement/Context/WF.lean](../../../formal/Benitoite/Release/Refinement/Context/WF.lean)
- [formal/Benitoite/Release/Refinement/Context/Facts.lean](../../../formal/Benitoite/Release/Refinement/Context/Facts.lean)
- [formal/Benitoite/Release/Refinement/Context/Declarations.lean](../../../formal/Benitoite/Release/Refinement/Context/Declarations.lean)
- [formal/Benitoite/Release/Refinement/Context/Capture.lean](../../../formal/Benitoite/Release/Refinement/Context/Capture.lean)

## 新規の改造ファイル（全件）

- [l00b.03/axioms-summary.json](../l00b.03/axioms-summary.json)
- [l00b.03/axioms.lean](../l00b.03/axioms.lean)
- [l00b.03/boundary-extra-first.log](../l00b.03/boundary-extra-first.log)
- [l00b.03/boundary-first.log](../l00b.03/boundary-first.log)
- [l00b.03/boundary-inventory.json](../l00b.03/boundary-inventory.json)
- [l00b.03/boundary.lean](../l00b.03/boundary.lean)
- [l00b.03/boundary.log](../l00b.03/boundary.log)
- [l00b.03/build.log](../l00b.03/build.log)
- [l00b.03/case-inventory.txt](../l00b.03/case-inventory.txt)
- [l00b.03/closures-compat.log](../l00b.03/closures-compat.log)
- [l00b.03/commands.json](../l00b.03/commands.json)
- [l00b.03/declaration-counts.json](../l00b.03/declaration-counts.json)
- [l00b.03/delivery.json](../l00b.03/delivery.json)
- [l00b.03/final-check.json](../l00b.03/final-check.json)
- [l00b.03/final-check.py](../l00b.03/final-check.py)
- [l00b.03/inputs-final.json](../l00b.03/inputs-final.json)
- [l00b.03/large-records.md](../l00b.03/large-records.md)
- [l00b.03/lean-version.log](../l00b.03/lean-version.log)
- [l00b.03/old-axioms.lean](../l00b.03/old-axioms.lean)
- [l00b.03/old-main-axioms.log](../l00b.03/old-main-axioms.log)
- [l00b.03/public-api.lean](../l00b.03/public-api.lean)
- [l00b.03/public-api.log](../l00b.03/public-api.log)
- [l00b.03/public-api.md](../l00b.03/public-api.md)
- [l00b.03/public-targets.txt](../l00b.03/public-targets.txt)
- [l00b.03/results.md](../l00b.03/results.md)
- [l00b.03/shared-compat.log](../l00b.03/shared-compat.log)
- [l00b.03/signatures.md](../l00b.03/signatures.md)
- [l00b.03/source-changes.json](../l00b.03/source-changes.json)
- [l00b.03/validate.py](../l00b.03/validate.py)
- [l00b.03/validation.json](../l00b.03/validation.json)

- [reviews/RV-L00b.03-request.md](RV-L00b.03-request.md): 本依頼。

100 KBを超える生の記録は改造内に置いていない。[large-records.md](../l00b.03/large-records.md)に `<tmp>` の記録名・大きさ・SHA-256 を残した。

## 残る担当と手順

| 手順 | 担当・内容 | 見込み時間 |
|---|---|---|
| 群末の独立レビュー | 取りまとめ。上の定義・言明・仮定と境界の入口を確認する | 不明 |
| 指摘への対応 | 実装担当。五つの境界を変える必要があれば起動依頼の停止条件を適用する | 指摘の内容による |
| 作業末の work・受け入れ・取り込み | 取りまとめ・設計者。B_WORK を固定した formal の検査と、残る義務を照合する | 不明 |
| 次の L00b.04 | 別の起動依頼で始める。閉じた評価・外部受信後の検査は本群で実装していない | 不明 |
