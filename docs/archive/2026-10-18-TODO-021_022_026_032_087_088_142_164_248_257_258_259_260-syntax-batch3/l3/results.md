# L3 実装結果

2026-10-18、Codex。作業L3を完了した。基準は `4a57e1fd21bcebcea629626e8191b25653e051b5`、ブランチは `mod009/L3`。開始時の作業ツリーはクリーンだった。

## 変更と完了条件

- `Surface/BuilderSyntax.lean`: BuilderKind・BuilderOp・BuilderCtx/kindAt・contents/cell、種類別BuilderRefsと具体化する型引数。既存のSyntaxからimportする。通常の型へ構築器を追加していない。
- `Surface/Builders.lean`: Aligned/Clean/AtomsIn/Singleと空Δ・通常/専用束縛の保存、fillBuildersの長さ・lookup・先頭追加・複数束縛・空Δ・RenOk・hideContsとの交換。Refs.Okは対象の種類と、宣言の存在・種類・契約名・範囲・行数0・型引数・admits/SatAll・SingleTy・具体化後の型と効果を照合する。通常関数は辞書なしを検査する。PrimitiveAdmissible/Admissibleの行の条件はScopedと行数0から任意Qについて導く。
- `Surface/Lemmas/Builders.lean`: 四条件の境界と複数束縛、セル環境へのEnvClean/AtomsIn/SingleTyの保存とセルの型付け。表層のE_Prim/E_Fun、コアのV_Prim/V_Fun・C_Appから全参照と呼び出しの型付けを導く。通常関数はfunDecl_desugaredで接続する。
- 54件の新規補題を証明した。3モジュールを既定のimportへ含め、01-12「構築器の分類と環境の対応」と07-04の説明・対応表へ写した。

専用のExpr/Blockはまだ追加していない。七判断・検査器・脱糖はこの基盤をまだ使わず、捕捉禁止や専用構文の型保存・Rustとの接続を完了したとは扱わない。

## 検査

最終のコマンド・終了状態・外側の時間は [check-times.json](check-times.json)、dry-runとworkの出力は [work-dry-run.txt](work-dry-run.txt) と [work.txt](work.txt) に保存した。作業末のworkは計画の `formal_build,spec_examples,spec_tally` のみを一度実行した。

| 検査 | 終了状態・外側の時間 | 結果 |
|---|---|---|
| 計画指定のworkに`--dry-run`を追加 | 0、0.010秒 | 指定の三単位だけを選択 |
| 同じ指定から`--dry-run`を除いたwork | 0、85.729秒 | spec_tallyの自己検査・集計、spec_examples 7件成功・失敗0・ignore 0、既定のlake build成功・sorryなし |
| `lake env lean <D>/l3/axioms.lean`（formal/） | 0、0.667秒 | 既存30件の[出力](axioms.txt)はL1開始時・L1完了時・L2の出力とバイト単位で一致 |
| `lake env lean <D>/l3/new-axioms.lean`（formal/） | 0、0.647秒 | [新規54補題](new-axioms.txt)は標準三公理の範囲内。sorryAx・Lean.ofReduceBoolなし |
| `git diff --check`、新規ソース・既存の定義の差分・文書の対応の確認 | 0 | 差分に問題なし。新規ソースにsorry/axiom/native_decideなし |

`<D>`は本改造のディレクトリであり、完全な実行コマンドはcheck-times.jsonに記録した。spec_tallyの新節の表示は他の01-12の節と同様に「テスト参照なし」で、終了0である。新しい契約はLeanの一般の補題で検査し、Rustのspec印だけを足していない。Rustを変更していないため、lib全件・clippy・fmt、全統合・特殊構成・check-formal全体は実行していない。

途中は `lake env lean Benitoite/Surface/Builders.lean`・`lake env lean Benitoite/Surface/Lemmas/Builders.lean` と、依存する対象だけの `lake build Benitoite.Surface.Builders`・`lake build Benitoite.Surface.Lemmas.Builders` を実行した。最終の局所確認は終了0である。途中の外側の時間は未集計。失敗は、TyOK/AtomsInのimport位置、既約な命題へのフィールド記法、Natの添字の推論、hideContsの展開順、予約語scopedの欄名、Option.mapの等式の書き換え、および一度の作業ディレクトリの取り違えによるものだった。支持をTy.Supportで表し、型注釈・関数適用・等式の書き換えとモジュールの配置を直して解消した。

## 関門・計画との差

- K契約/K接続: 共有番号、Γの専用位置のnone、Stateと既存Referenceの規則を保つ。new/get/setと純粋な合成のラベルはdesign 7.3と既存標準ソースに合わせた。newの存在を組み込みの仮定へ追加していない。参照先の型付けは既存の導出から得ており、変換後の検査で代用していない。
- K形式化: Core/Release、既存の七判断・checker・主定理・WellTyped/WellFormed/Input.Sound・Builtins.Assumptionsの定義は変更していない。既存Syntaxの差分はimport一行だけである。
- K文書: 基盤までの到達範囲と未接続を写した。構文の章・標準ソース・診断表は変更していないためgen_skillの再生成は不要。Rust・VM・GC・性能測定・公開境界・Scope/Rangeは変更対象外である。
- R147に、後続のExpr/Blockと循環importを作らないモジュール分割と、参照先の表現の具体化を記録した。計画の保証範囲の変更や停止条件に当たる変更はない。
- 既存のテスト・例・assert・期待値の変更と削除、ignoreの追加は0件である。テスト用の差し込み口や本番で不要な公開範囲は追加していない。有限の準備データを写すテストは足さず、この作業の契約は一般の環境・宣言表に対する補題と既定ビルドで確かめる。

## 後の作業へ

次はL4a。七判断へQ直後のΔを通す際は、`Builders`の定義を利用できる。Syntaxに必要なデータは`BuilderSyntax`、既存判断に依存する補題は`Lemmas/Builders`に分けてある。L4b/L4cではfillBuildersと四条件を帰納の内部へ通し、公開入口で空Δの条件を閉じる。専用操作と局所宣言、捕捉禁止、交換形式、Rustは計画どおり後の作業で接続する。

公理比較の再実行には [axioms.lean](axioms.lean) と [new-axioms.lean](new-axioms.lean) を使える。コミット、取り込み、docs/todoの変更は行っていない。
