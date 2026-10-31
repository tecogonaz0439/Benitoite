# RV-L00b.02b-closures-r2: 群末レビューの所見への対応の再レビュー依頼

2026-10-31。前回の[独立レビュー](RV-L00b.02b-closures.md)は不可（重3・中1・軽5）であった。planの「計画の変更と取りまとめへの確認点」の先頭の判断と再開依頼に従い、本番を修正した。取り込み・次群への進行の前に、定義・前提・言明を再レビューしてほしい。独立レビューの実行と受け入れは取りまとめ・設計者の担当であり、この依頼を受け入れ済みの記録としない。

指定ブランチは`m014/l00b.02b-closures`、B_WORKは`1170a4a6d81d49a6d098d2f222ed33c8f22c9230`である。gitは照合も操作も行っていない。今回の[変更8ファイルのハッシュ](../l00b.02/02b-closures-r2-source-changes.json)はレビュー対応の再開時からの比較である。前回の群末で新設したClosureTyping/StateTypingも既存として数え、今回の新しい本番ファイルは0件である。

## 先に読むもの

1. 前回の[レビュー](RV-L00b.02b-closures.md)、planの上記の判断、[元の反例](../l00b.02/rv-02b-closures-closed-param.lean)。反例とレビューの記録は変更していない。元の負例は修正前の定義についての記録であり、修正後の受け入れ検査としては実行していない。
2. [signaturesの第8.2・24・30節](../l00b.02/signatures.md)、[resultsの「レビューの所見の対応」](../l00b.02/results.md)、[公開宣言の一覧](../l00b.02/02b-closures-r2-public-api.md)。
3. 本番の変更8件と、[境界の正例](../l00b.02/02b-closures-r2-boundary.lean)、[全宣言の公理依存の集計](../l00b.02/02b-closures-r2-axioms-summary.json)。必要に応じて前回の共通依頼文・正とする契約・旧Releaseを照合する。

## 修正の要点

- 重1：ClosureTyはソースの入力ssを`bindParams Γ ss`で検査し、添字のpsを`ss.map cap.closeTy`に結ぶ。K_Letの専用規則は増やしていない。`s1_typed`は元の`s1_untyped`と同じ状態の正例である。
- 重2：案aを採用した。CaptureViewは通常の場所の型を保ち、builderだけを捕捉値で閉じる。未束縛入力を残すときは`upSubst n cap.env`を使う。案bのStepの変更、案cの種類の値依存の禁止は採らなかった。`s3_typed`は元の`s3_untyped`と同じ状態の正例である。
- 重3：matchRunはソースの値vsと`v = closeVal cap vs`を保持する。v.Groundと、ソースの腕の捕捉の長さに対する閉性を分けた。K_Guardもソースのストアの見方を保持する。`match_transition`・`guard_false`は捕捉に依存するReference型を使い、腕の束縛値を同じ型の引数注釈を持つlambdaへ渡す。
- 中1：C_Handle/C_Handle_FailをEff.Subへ戻した。K_HandleはSubを維持した。Sub.bind/shiftV/shiftTypesと三族の該当の場合を閉じ直した。
- 軽1：ClosureTyの局所文脈をNoneだけの列まで広げ、NoBuilders.empty/localExtendを証明した。
- 軽2〜4：closeValの型付け、CaptureOkのhide、結果型のWF/Sorted、腕の結果・効果の拡大を第24節と第30.3節のL20の義務にした。一般の補題を今回完了とは扱っていない。
- 軽5の強化：resultsに23行の遷移の表を置いた。各行は前のStateTy、Step、先のStateTyの連言である。Frame7を各種類につき積む・外す例、場所の生成、resume、K_Handle_Failの経路を含む。継続の場所を作るE_OpFailと、枠を積むE_Handleは別々に確認した。

## 同じ原因から追加で直した補助判断

開いたΨsを持つだけでは、内側のletや腕で操作の種類だけが移動し、Ψsが固定される問題が残る。元のCQをそのまま使う案の障害を`old_nested_store_obstruction`で示した。このため、実行コード用のOpenCodeTy/OpenArmsTyを追加した。

ソースのHasTypeCQの規則を一括で改訂する案は採らず、捕捉を持つ実行コードの補助の範囲で処置した。束縛の下ではソースのbuilderの種類だけを`shiftBuilders`で移す。通常の場所の型は同じである。元のCQ/Armsを使うtypedの条件は、ソースのストアの閉じたWF、又はBuilderLocFreeである。この条件を省くと元の不一致を再導入するため、重点的に確認してほしい。関数・lazy・節の本体のbuilderの隠し方も照合してほしい。

OpenCodeTyは11、OpenArmsTyは4構成子である。ソースの判断71、ContTy10、Frame7/Cell6/LocTy4/State4、Step76は維持した。移動の2入口を別々に数えるとhandlerは2×4=8場合、論理上の三族では2×3=6場合を再検査した。捕捉済みのOpenCodeTyは外側の文脈操作で再利用する。`CaptureView.shift`、`nested_builder_new`、`input_builder_return`、`builder_match_transition`を追加の正例とした。

## レビューの観点

1. 重1〜3の修正が、捕捉前の注釈と閉じた契約を正しく区別し、前回の反例を反転できているか。特にssとps、ソースのΨsと実行時のΨ、vsとvの対応を確認してほしい。
2. CaptureViewの未束縛入力、shiftBuilders、OpenCodeTy/OpenArmsTyの束縛下の規則は正しいか。typedの条件が弱すぎないか。Sourceの全21場合のうち11場合をtypedへ接続できる理由と、残る10場合の専用構成子を照合してほしい。
3. K_Guardは元の実行時Ψに対応するソースのΨsを読み、guardとbodyで同じストアの見方・localExtendを使っているか。guardだけhideBuildersへ変えていないか。ソースのストアが閉じた場合はshiftBuilders_of_wfで元のΨと一致することも確認してほしい。
4. C_Handle/C_Handle_FailとK_Handleの構造上の包含が一致し、三族の置換・移動のSubの補題が正しいか。
5. 23行の正例が先のStateTyを仮定しておらず、依存する型・種類の問題を確認する入力になっているか。一般の保存の言明を今回完成と誤記していないか。
6. L20へ残した軽2〜4と実行コードの一般の保存の義務が、十分に具体的か。主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態に変更がないか。

## 実行済みの検査

[台本](../l00b.02/02b-closures-r2-validate.py)を実行し、以下が終了0である。Leanは各プロセスに`-M 12288`を付けた。既定ビルドの指定は既存のlakefileによる。

- 既定の`cd formal && lake build`：671 jobs、sorryなし。
- 境界の正例と全境界宣言の公理依存：336宣言。23行、19種類の遷移。
- 公開宣言の型の書き出し。
- 本番98モジュールの生成・非公開の宣言と旧の三モデル等7宣言：10,740宣言。公理はpropext・Quot.sound・Classical.choiceのみ、許可外0件。
- formalの428入力が検査前後で一致し、抜け道の語の検査は該当0ファイル。

[コマンドと時間](../l00b.02/02b-closures-r2-commands.json)、[検査の集計](../l00b.02/02b-closures-r2-validation.json)、[場合の数](../l00b.02/02b-closures-r2-case-inventory.json)を参照してほしい。workは依頼どおり実行していない。git、処理系、設計書、plan、effort-ledger、レビューの記録を変更していない。`.02c`へ進んでいない。

## ファイルの一覧

本番の変更はClosureTyping・EffectCover・Shift・StateTyping・TypeShiftContracts・TypeShiftTyping・Typing・TypingShiftの8ファイルである。改造の既存ファイルはsignatures.md、results.md、large-records.mdを変更した。

今回の新規ファイルは以下の17件である。

- [02b-closures-r2-artifact-inputs.json](../l00b.02/02b-closures-r2-artifact-inputs.json)
- [02b-closures-r2-axioms-summary.json](../l00b.02/02b-closures-r2-axioms-summary.json)
- [02b-closures-r2-axioms.lean](../l00b.02/02b-closures-r2-axioms.lean)
- [02b-closures-r2-boundary.lean](../l00b.02/02b-closures-r2-boundary.lean)
- [02b-closures-r2-boundary.log](../l00b.02/02b-closures-r2-boundary.log)
- [02b-closures-r2-build.log](../l00b.02/02b-closures-r2-build.log)
- [02b-closures-r2-case-inventory.json](../l00b.02/02b-closures-r2-case-inventory.json)
- [02b-closures-r2-commands.json](../l00b.02/02b-closures-r2-commands.json)
- [02b-closures-r2-inputs-final.json](../l00b.02/02b-closures-r2-inputs-final.json)
- [02b-closures-r2-lean-version.log](../l00b.02/02b-closures-r2-lean-version.log)
- [02b-closures-r2-public-api.lean](../l00b.02/02b-closures-r2-public-api.lean)
- [02b-closures-r2-public-api.md](../l00b.02/02b-closures-r2-public-api.md)
- [02b-closures-r2-source-changes.json](../l00b.02/02b-closures-r2-source-changes.json)
- [02b-closures-r2-start.json](../l00b.02/02b-closures-r2-start.json)
- [02b-closures-r2-validate.py](../l00b.02/02b-closures-r2-validate.py)
- [02b-closures-r2-validation.json](../l00b.02/02b-closures-r2-validation.json)
- 本依頼文 `reviews/RV-L00b.02b-closures-r2-request.md`

公理依存の全出力1,121,008バイトと公開型の出力104,637バイトは`<tmp>`に保存し、[large-records](../l00b.02/large-records.md)に大きさとSHA-256を残した。これらは改造へ置いた新規ファイルには含めない。
