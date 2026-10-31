# RV-L00b.02b-closures-r3: 再レビューの所見への対応の確認依頼

2026-10-31。[再レビュー](RV-L00b.02b-closures-r2.md)の条件付き可（重なし・中3・軽3）と、planの「計画の変更と取りまとめへの確認点」の先頭の判断に従って修正した。取り込みと次群への進行の前に、補助の定義・前提・言明・代表遷移を再レビューしてほしい。レビューと受け入れは取りまとめ・設計者の担当である。

指定ブランチは`m014/l00b.02b-closures`、B_WORKは`1170a4a6d81d49a6d098d2f222ed33c8f22c9230`である。gitの照合・操作はしていない。[本番の変更6件のハッシュ](../l00b.02/02b-closures-r3-source-changes.json)は今回の再開時との差であり、新規2件を含む。

## 読むもの

1. [RV-L00b.02b-closures-r2](RV-L00b.02b-closures-r2.md)、planの先頭の判断、レビューの`rv-02b-closures-r2-*.lean`。これらの記録は変更していない。
2. [signaturesの第8.2・24・30節](../l00b.02/signatures.md)、[resultsの「再レビューの所見の対応」](../l00b.02/results.md)、[公開宣言](../l00b.02/02b-closures-r3-public-api.md)。
3. `formal/Benitoite/Release/Refinement/`の変更6件と、[共通の境界入力](../l00b.02/02b-closures-r3-boundary.lean)、[追加の境界入力](../l00b.02/02b-closures-r3-extra.lean)。前者の名前空間はClosureR3、後者はClosureR3Extraである。

## 修正と重点の観点

- 中2：OpenCodeTy・OpenArmsTy・CaptureView・shiftBuilders・BuilderLocFree・NoBuildersと、それらに依存する補題・typedの条件を除いた。ClosureTyは元の`code0`・`L`・`ρ`を保持し、同じ閉じた実行時ΨのHasTypeCQで型付ける。通常の場所は同じΨを読み、局所構築器の場所だけを`CaptureLocals Ψ (upSubst ss.length cap.env) L ρ`で捕捉した種類の像に結ぶ。この前提が未束縛入力、内側のlet、パターン束縛の下でも一致するかを確認してほしい。
- 中2の構文：`resolveLocals`は型・効果の注釈を変えない。Comp.substとの交換はVal/Comp/Arm/Clauseの相互帰納で示した。`subst_resolveLocals`の置換の合成と、`resolveLocals_builderSubst`・`Comp.builderBody_resolve`・`HasTypeCQ.builderBody_keepsBound`の役割の違いを照合してほしい。実行の構築器生成で生じる正規化を、元のコードとの無条件の構文の等号で消していないかも確認してほしい。
- 中1：K_Guardからソースのdone型のDeclaredを除き、K_Handleのソースのdone型のAnnotationとdeclaredEff ebsを、閉じたdone(t,ec)のAnnotationへ置き換えた。旧ReleaseのK_HandleはTy.WF 0 0 tだけであった。C_HandleにEff.WFを追加していない。
- 中3：既存23行を組み直し、7行を加えて30行・23種類の遷移を検査した。非空の節を持つ通常handlerは、結果R(0)と操作の型引数R(0)を捕捉でrefTyへ閉じ、E_Handle/E_Op/E_Resume/E_HRetの連鎖を実際に型付ける。構築器へのappend、matchState 1からのE_MatchBody、trueのE_GuardTも加えた。各行は前StateTy・Step・後StateTyの連言で、後状態の型付けを前提にしていない。
- 軽1：K_Guardも元のarms0・L・ρを保持する。guardとbodyは元のHasTypeArmsQの同じΨ/localExtendを使い、実行の腕との関係を局所参照だけの解決で表す。
- 軽2：ClosureTyを相互帰納の直後へ出した。相互帰納は17型から14型へ減り、ソースの71構成子は不変である。ClosureTy.storeは相互の証明の外で再構成する。
- 軽3：第30.2節に採用案・理由と撤回したOpenCodeTy案を記録し、第24・30.3節に元のCQ/Armsと交換補題の適用の残りを記録した。closeValの型付け・CaptureOkのhide・結果のWF/Sorted・腕の効果拡大・全状態の保存はL20に残る。この具体性が十分か、一般の保存を今回完成と扱っていないかを確認してほしい。

`s1_typed`・`s3_typed`は最初の反例と同じ状態の反転した正例として維持した。内側のletとパターン束縛の下の構築器の例も保持した。mark/update/release/dropの枠とrefの場所の「依存なし」の行は、それらが捕捉したコードの型注釈を読まないため追加の依存を省く旨をresultsの表に明記した。

主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態を変更していない。Step/step、処理系、設計書、plan、effort-ledger、レビューの記録、rv-*を変更していない。workとgitは実行せず、`.02c`へ進んでいない。

## 実行済みの検査

[検査台本](../l00b.02/02b-closures-r3-validate.py)・[コマンド](../l00b.02/02b-closures-r3-commands.json)・[集計](../l00b.02/02b-closures-r3-validation.json)を参照してほしい。

| 検査 | 結果 |
|---|---|
| 既定のcd formal && lake build | 終了0、673 jobs、sorryなし |
| 共通の境界入力 | 終了0、341宣言・24行 |
| 追加の境界入力 | 終了0、88宣言・6行 |
| 本番100モジュールと既存7確認対象の公理依存 | 10,891宣言、許可したpropext・Quot.sound・Classical.choiceのみ |
| 件数と削除の確認 | 相互14型・ClosureTy単独1型・ソース71構成子・Step76。撤回した補助6件の名前が環境にない |
| 入力の固定 | formalの430入力が検査前後で一致。Refinementの抜け道の語は該当0ファイル |

Leanは単体検査も既定ビルドもプロセスごとに-M 12288を指定する。共通の境界入力は検査専用のモジュールとして`.lake`でコンパイルし、追加入力からimportする。台本が毎回コピーを作り、コピーの入力ハッシュを残す。本番のimportに検査専用の宣言を含めていない。

## ファイルの一覧

本番の変更は`Typing.lean`・`TypingShift.lean`・`ClosureTyping.lean`・`StateTyping.lean`の4件と、新規の2件である。

- `formal/Benitoite/Release/Refinement/LocalResolve.lean`
- `formal/Benitoite/Release/Refinement/LocalResolveLemmas.lean`

改造の既存ファイルは`l00b.02/signatures.md`・`results.md`・`large-records.md`を変更した。改造の新規ファイルを以下に列挙する。大きな公理依存の生の出力は含めず、`<tmp>`の大きさとSHA-256を[large-records](../l00b.02/large-records.md)へ記録した。

- [02b-closures-r3-artifact-inputs.json](../l00b.02/02b-closures-r3-artifact-inputs.json)
- [02b-closures-r3-axioms-summary.json](../l00b.02/02b-closures-r3-axioms-summary.json)
- [02b-closures-r3-axioms.lean](../l00b.02/02b-closures-r3-axioms.lean)
- [02b-closures-r3-boundary.lean](../l00b.02/02b-closures-r3-boundary.lean)
- [02b-closures-r3-boundary.log](../l00b.02/02b-closures-r3-boundary.log)
- [02b-closures-r3-build.log](../l00b.02/02b-closures-r3-build.log)
- [02b-closures-r3-case-inventory.json](../l00b.02/02b-closures-r3-case-inventory.json)
- [02b-closures-r3-commands.json](../l00b.02/02b-closures-r3-commands.json)
- [02b-closures-r3-delivery.json](../l00b.02/02b-closures-r3-delivery.json)
- [02b-closures-r3-extra.lean](../l00b.02/02b-closures-r3-extra.lean)
- [02b-closures-r3-extra.log](../l00b.02/02b-closures-r3-extra.log)
- [02b-closures-r3-final-check.json](../l00b.02/02b-closures-r3-final-check.json)
- [02b-closures-r3-inputs-final.json](../l00b.02/02b-closures-r3-inputs-final.json)
- [02b-closures-r3-lean-version.log](../l00b.02/02b-closures-r3-lean-version.log)
- [02b-closures-r3-public-api.lean](../l00b.02/02b-closures-r3-public-api.lean)
- [02b-closures-r3-public-api.log](../l00b.02/02b-closures-r3-public-api.log)
- [02b-closures-r3-public-api.md](../l00b.02/02b-closures-r3-public-api.md)
- [02b-closures-r3-source-changes.json](../l00b.02/02b-closures-r3-source-changes.json)
- [02b-closures-r3-start.json](../l00b.02/02b-closures-r3-start.json)
- [02b-closures-r3-step-coverage.json](../l00b.02/02b-closures-r3-step-coverage.json)
- [02b-closures-r3-validate.py](../l00b.02/02b-closures-r3-validate.py)
- [02b-closures-r3-validation.json](../l00b.02/02b-closures-r3-validation.json)
- 本依頼文 `reviews/RV-L00b.02b-closures-r3-request.md`
