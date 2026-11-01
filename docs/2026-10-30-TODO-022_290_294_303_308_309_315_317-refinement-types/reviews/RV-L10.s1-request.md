# RV-L10.s1 レビュー依頼

L10.31〜L10.43（群S前半）の定義・言明・仮定と実装をレビューしてほしい。担当の実装と自己検査は完了した。初回の独立レビューは条件付き可となった。中1・軽1〜5の処置後の独立確認、work、受け入れ、取り込みは未実施である。

B_WORKは `78aa5cca81cf24a420c266e6b714934297ce434e`、指定ブランチは `m014/l10.s1`。担当はgitの状態を変える操作をしていない。L10.44には進んでいない。

## 読む順序と確認箇所

[detail](../l10/detail.md)のS・.31〜.43・foundationの処分・検査の割り当てと、[結果](../l10/s1/results.md)、[完全署名](../l10/s1/signatures.md)、新規5モジュール、[境界](../l10/s1/boundary.lean)を照合してほしい。plan/detail/reviews原本/rv-*は変更していない。

- 四支持族がrefined/dependentFn/external/Fail/Telを含むこと。述語の値参照のWFを原子の支持へ混ぜていないこと。
- 収集の完全性・健全性・支持同値と、norm/refineNorm/foldFn/移動の支持の保存・反映。一般置換で原子の像が変わる条件、SupportTransport.up、typeEnvAt/substAtの条件が十分で、主な型付け定理へ有限性の新前提を追加していないこと。
- 旧台帳の本番追随19件（17＋2）、棚卸し外13件、有限版12件を重ねて数えていないこと。A_17/c_gの未取得と初期時刻の概数を実測と誤認していないこと。
- 有限比較が既存ラベル順を保ち、新原子→旧rho符号の接点を証明していること。型全域の決定可能等号を導いていないこと。
- fnPartsの逆移動の往復、NamesWFの有限判定、再構築比較、成功時の等号と既存FnViewへの一致。依存と重複名を拒む実例の前提が結論を仮定していないこと。
- normWithの実行順と支持下の一致、支持/Canonical/冪等/支持独立、支持不足の負例。旧Legacy三橋を移していないこと。
- 実行依存11入口と、公理監査の全新規宣言614件・既存18件・署名105件・境界50件。境界の遅延生成の既存ライブラリの補助は使用側の推移的な依存で検査すること。
- 01-12・07-04・用語集との対応。主要HasTypeVQ/HasTypeCQの十言明、五つの境界、既存の定義の意味が変わっていないこと。

補助契約の決定一覧と、最初の局所検査・境界の失敗と修正は結果に記した。独自公理、結論の弱化、精密な外部状態は加えていない。実行の入口はs1/check.py。最終の既定ビルドは765ジョブで終了0、公理依存計787件は許可する三公理だけ、実行依存11入口は全成功である。RSSは計画上の非採取。

## 変更した既存ファイル

- `formal/Benitoite.lean`（新Finiteから5モジュールを既定importへ追加）
- `docs/design/01-spec/01-12-core-calculus.md`
- `docs/design/07-quality/07-04-formal-semantics.md`
- `docs/design/00-overview/00-04-glossary.md`

## 新規・同梱ファイルの全一覧

rv-s1-t1〜t11は取りまとめが追加した読み取り専用の参照入力であり、当方は変更していない。review-inputs.jsonとreview-before.jsonを今回追加した。以下は本依頼を含む全一覧である。

- `formal/Benitoite/Release/Refinement/TypeSupport.lean`
- `formal/Benitoite/Release/Refinement/FiniteSupport.lean`
- `formal/Benitoite/Release/Refinement/FiniteCompare.lean`
- `formal/Benitoite/Release/Refinement/FiniteFunctionView.lean`
- `formal/Benitoite/Release/Refinement/Finite.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/axioms-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/axioms-result.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/axioms.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/boundary-failure.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/boundary-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/boundary-result.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/boundary.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/build-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/build-result.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/check.py`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/execution-path-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/execution-path-result.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/execution-path.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/large-records.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/protected-inputs.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/results.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/review-before.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/review-inputs.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/rv-s1-t1.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/rv-s1-t10.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/rv-s1-t11.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/rv-s1-t2.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/rv-s1-t3.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/rv-s1-t4.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/rv-s1-t5.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/rv-s1-t6.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/rv-s1-t7.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/rv-s1-t8.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/rv-s1-t9.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/signatures-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/signatures-result.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/signatures.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/signatures.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s1/verification.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/reviews/RV-L10.s1-request.md`

## レビューと受け入れの残り

| 手順 | 担当 | 見込み |
|---|---|---|
| 定義・言明・仮定と境界の独立レビュー | 取りまとめが起動するレビュー担当 | 不明 |
| 指摘がある場合の同群内の修正と影響検査 | 実装担当 | 不明 |
| workの選択・実行、受け入れ、取り込みと次の基準 | 取りまとめ・設計者 | 不明 |

前群の控えとの照合でeffort-ledger.mdの差分を認めたが、担当は編集していない。既存の取りまとめの更新を上書きしていない。

## 修正後に確認してほしい点

中1は比較四族を構造再帰にし、rfl/decideの境界を追加した。軽1は候補をsへ縮め、viewSupportと補助二件を消した。軽3はp→qと行の支持からhaを導くtypeEnvAt_atomとof_imp/sameを計6補題追加した。軽5は署名の警告を初回77・現在83とし、boundary001の実例の説明と01-12の保存の向きを直した。

軽2の支持前提なしのfnViewの一致は、G07が一般証明と追加の判断を行う申し送りにした。軽4はAtom.codeの桁数と深い経路の費用、AtomsIn相当の支持の不変量を利用先が証明で持つことをL70へ申し送った。測定だけの実行は追加していない。

レビュー原本RV-L10.s1.mdとrv-s1-t*.leanはハッシュで保護し、変更していない。担当の修正と検査を、修正後の独立レビュー済みと扱わない。
