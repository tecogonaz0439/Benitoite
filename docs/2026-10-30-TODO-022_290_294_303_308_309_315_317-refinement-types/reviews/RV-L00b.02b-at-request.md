# RV-L00b.02b-at：σ/Atと保持値の群末レビュー依頼

2026-10-31。`.02b-at`の定義・言明・前提・証明と、委任された補助契約の判断を独立に確認してほしい。自己点検と検査を終えた状態であり、独立レビュー済み・受け入れ済みではない。次の腕・節・ハンドラの型付けの群へは進んでいない。

## 基準と範囲

- B_WORK：`1874fe91aa3684662dca4c69b284ea9614b9fb56`。指定ブランチ：`m014/l00b.02b-at`。gitの照合・操作・切替・作成・コミットをしていない。
- 08f9ac72・f42ab9aa・5ed7029bは取り込み済みという起動依頼の指定値を使った。処理系・現行設計書・plan.md・旧Release本体を変更していない。
- 範囲はsignatures第12.2節の`.02b-at`の行と前群の申し送りである。Val25/Comp16/Event3/Step76、値の六導出・計算の二導出・CheckedWitness二導出、三族・TypedFacts・Ground・捕捉・全既存構文操作・Declaredの正則性を同じ群で処理した。
- 補助契約の採用案・理由・捨てた案は[signatures第26節](../l00b.02/signatures.md)にある。主な定理の前提・結論、新公理、提供範囲、利用者の書ける形、精密な外部状態を変えていないという担当の判断も、確認してほしい。

## 先に読む資料

1. [共通依頼文](../implementation-request.md)、planの2026-10-31の判断の全行。補助契約の委任、案A、RV-values/RV-externalへの判断を含む。
2. [signatures](../l00b.02/signatures.md)の第4・6〜9・12・19〜26節、[resultsの今回の節](../l00b.02/results.md)、[公開名107名](../l00b.02/02b-at-public-api.md)。第24節の送り先は今回閉じていない。
3. [RV-L00b.02b-external](RV-L00b.02b-external.md)、前群resultsの申し送り、[contracts](../l00a.06a/contracts.md)、[lemmas](../l00a.16a/lemmas.md)、改造READMEの設計者の決定とdecisions。特にD20/D28/D54〜D61/D66/D67を対照してほしい。
4. 下の新規本番10ファイル、既存22ファイル、境界とA-Lの記録。旧の型付け・保持要求・Stepも比較してほしい。

## 本番の新規ファイル（全10件）

| ファイル | 内容 |
|---|---|
| [Adequate.lean](../../../formal/Benitoite/Release/Refinement/Adequate.lean) | 固定σに対する全有限保持箇所の適格性と、snapshotから現在の所属への橋 |
| [AtContracts.lean](../../../formal/Benitoite/Release/Refinement/AtContracts.lean) | 標準Scope.ScopeErrorとResultの宣言・arity・欄の照合、エラーの観測の宣言照合 |
| [AtInput.lean](../../../formal/Benitoite/Release/Refinement/AtInput.lean) | 有限の純粋な文字列と要求の端点の入口、homeとcwdの区別 |
| [AtPrepare.lean](../../../formal/Benitoite/Release/Refinement/AtPrepare.lean) | 計算できるgroundValとGround、AtPrepare/AtPreparedとindexの補題 |
| [AtSound.lean](../../../formal/Benitoite/Release/Refinement/AtSound.lean) | checkAtの成功から両方の範囲のSnapshotMemを導く補題 |
| [AtTyping.lean](../../../formal/Benitoite/Release/Refinement/AtTyping.lean) | 絶対保持値の旧opaqueへの互換、CheckedWitnessの所属、AtCallのindex、エラーの欄の型付け |
| [BuiltinResponse.lean](../../../formal/Benitoite/Release/Refinement/BuiltinResponse.lean) | BuiltinArgs・δ/IOの型付き入力とAdequateResult・TargetAgreement |
| [PathResolution.lean](../../../formal/Benitoite/Release/Refinement/PathResolution.lean) | PathEnv.Valid/Binds、有限の解決・所属・checkAtと各失敗 |
| [Preparation.lean](../../../formal/Benitoite/Release/Refinement/Preparation.lean) | 構文と既知契約を有限の導出で辿るRequired/Ready/InitialPrepared |
| [Source.lean](../../../formal/Benitoite/Release/Refinement/Source.lean) | 表層から作る値と実行時だけの内部値の区別 |

既存の変更は22ファイルである。`Admissible`、`Capture`、`ConstraintAssumptions`、`Embedding`、`Ground`、`Narrowing`、`NarrowingObstruction`、`RuntimeMatch`、`RuntimeSyntax`、`ScopeSyntax`、`Semantics`、`Step`、`Subst`、`SubstTyping`、`SubstTypingObstruction`、`Syntax`、`TypedFacts`、`Typing`、`TypingDeclared`、`TypingShift`、`ValueBinding`、`Benitoite`。Benitoite.leanは既定importの集約であり、ほかはRefinementの下にある。[変更一覧](../l00b.02/02b-at-source-changes.json)に全名・新規/既存・SHA-256・前後の行数を置いた。差分は101,245バイトのため一時領域へ置き、[large-records](../l00b.02/large-records.md)の大きさとSHA-256で照合する。改造内へ古い差分の写しを最終差分として残していない。

## 特に確認してほしい点

1. **静的な判断とσ。** 型付け・LeQ等に実行のσを加えず、V_PathBasesの有限なsnapshotのValidと、実行側のAdequateの同じσの等式を分けているか。someのcheckedAtは同じσ、noneはabsoluteに限り、要求全体も再帰して適格であること。全code・capture・frame・cellへ到達し、場所からストアを無限に追わないこと。Readyを保存の新しい前提にしていないか。
2. **既知の契約の準備。** Requiredが有限の帰納的な到達の証拠であり、全Program.defsの列挙を要求しないこと。篩のmember、名目型に属する全構成子の欄、関数・クラス・実装・外部・組込み署名を辿ること。Bを加えた補助署名で固定起点を見落とさないこと。動的ScopePatternを静的な必須起点へ混ぜず、未指定secretsと明示空一覧を区別すること。
3. **Atの補助の前提。** AtCallAdmissibleがHasTypeVQと同じ正の相互帰納であり、token・pattern・String/要求の入力を実際に型付けること。valContentの宣言型の閉じたWFが移送に必要であり、利用者の値依存型まで制限していないか。index.WF 0と範囲のWF/Canonical/種類を検査し、AtPrepared.fixed_indexとAtPrepare.no_staticIndexを型付き状態へ適用できるか。
4. **保持要求と旧の絶対形。** CheckedWitness.requestとV_CheckedRequestに空C/Γ/ΦのHasTypeV・Ground・reqTargetの一致があること。裸のRequestInや要求なしのcheckedAtを許さないこと。旧checked/checkedRequestと新checkedAtの要求を改名・値置換・型置換・捕捉でそのまま保ち、storeの移送とhideだけは相互のshift_valuesで閉じること。旧opaqueへの互換がscoped_forgetからの導出であること。
5. **補助署名の三つの差。** Required/Ready/InitialPreparedへのB、BuiltinArgsへのb、TargetInputのhomePathの追加が、委任された補助の具体化の範囲に収まっているか。homePathは既定の~と~/をhomeとして保つためであり、relativePathはcwdのまま、新しい変数展開を加えていないこと。未解決のパターンの字句WFを検査し、起点に含まれるリテラルの*を拒まないこと。
6. **標準エラーの整合。** Resultのarity2とOk/Errorの引数位置、閉じたScope.ScopeErrorのarity0と内部構成子Scope.ScopeError.Atの七つのString欄を照合しているか。AtError.textFields/values/toTerm?、TypedFacts、RuntimeMatchとvalues_typedが同じ七欄を使うか。最初のnone七欄の下書きは撤回済みである。保持データを切り詰めず、内部reprStrと公開のScopeErrorの構成子/Showの対応がL50/L70に残ることを確認してほしい。
7. **組込みの信頼条件。** BuiltinArgsが長さだけでなくPrimitiveAdmissible/RangeAdmissible/SignatureInstance/TelArgs/Ground/閉じたWFとCanonicalを持つこと。bの追加で別名のadmitsRを取り違えないこと。delta_typed/io_typedは同じoutに対する全有効σのAdequateResultを持つこと。io_kind/io_existsとTargetAgreementも同じ型付き入力を使い、正常応答の存在を強めず、外部の第四の仮定や精密な外部状態を加えていないこと。CoreAssumptionsの全旧条件の最終接続を今回完了と扱っていないこと。
8. **三族と場合数。** 判断の49構成子とAtCall補助1を区別してほしい。移動はV26/C15/Vs2/Each2/TelArgs2/Witness2=49、AtCallを含め50。置換とnarrowingの実際の根は各47+AtCall1=48であり、空文脈・同じストア・そのままの保持要求のWitnessを再利用している。その再利用に欠落がないか。TypedFactsの主な52と補助112、DeclaredのV26/C15、hide/None版、既存障害例の言明も対照してほしい。
9. **遷移と実行器。** 旧68の名前・順序、外部3を保ち、今回5でStep76/Event3であること。発行は通常のhandler経路を通り、無handlerの専用発行だけがEvent.pathBasesを出すこと。Atは準備失敗もResult.Errorへ進み、すべてnoneラベルで、実行のσを暗黙に読まないこと。別σのtokenを使うAt成功は適格な状態から到達しない道筋があるか。
10. **残る義務の範囲。** 第24節のRV-values全7行・RV-external全5行の担当を変えず、外部の受信後の篩の検査を`.04`/`.05`に残していること。handlersのR0/ImageOk/up/多相節と、closuresの固定σ/Eb/場所のDeclared、L50/L60のモデル・対象健全性、L20/L70の全保存を、今回の構文と移送の完了と混同していないか。

## 検査済みの範囲

最終の既定`cd formal && lake build`は終了0、650 jobs。Lean4.34.1、既定と単独の双方で-M 12288を使った。A-Lは77モジュールのprivate/生成宣言と旧の指定7宣言、計8,944宣言を照合し、使用はpropext/Quot.sound/Classical.choiceだけだった。sorryAx・独自公理・本番の抜け道の語の検出はない。最終407入力のハッシュは検査前後で一致した。

今回の境界は、別σのtoken・同じσの保持対象、Requestの実際の型付きレコードのGroundと端点一致、要求なし/開いた要求/異なる端点の拒否、動的条件/静的添字、secretsの未指定と明示空、At準備のindex、C_CheckAt、既知の未束縛起点、名目型から宣言された欄の到達、Stepとstep、エラーのString観測・パターンへの束縛を検査した。長い字句の例は実行で照合し、その真偽を形式的な証拠の公理にしていない。前群のr4/r5・値の葉・外部の境界も通した。失敗した途中の入力のLeanの回復用sorryAxを、最終の成功の証拠にしていない。

全有効σに対するCoversの健全性・IO対象と三モデル・解析器や公開ScopeErrorとの対応はL50、外部の三条件の充足はL60、全状態と主定理はclosures/`.14`/L20/L70へ残る。今回の値・計算・保持の証拠と移送をその未完の範囲へ送ってはいない。work/RSS/Rustのテスト/全比較/独立レビューは今回実施していない。

## 改造内の新規ファイル（全一覧）

本番の新規10ファイルは上の表にすべて挙げた。改造内の新規ファイルは次のとおりである。100 KB超の生の差分と公理依存の全出力は含めず、large-recordsとvalidationの大きさ・ハッシュで照合する。

- `l00b.02/02b-at-artifact-inputs.json`
- `l00b.02/02b-at-axioms-summary.json`
- `l00b.02/02b-at-axioms.lean`
- `l00b.02/02b-at-boundary.lean`
- `l00b.02/02b-at-boundary.log`
- `l00b.02/02b-at-build.log`
- `l00b.02/02b-at-commands.json`
- `l00b.02/02b-at-delivery.json`
- `l00b.02/02b-at-development-checks.json`
- `l00b.02/02b-at-external-boundary.log`
- `l00b.02/02b-at-first-boundary.log`
- `l00b.02/02b-at-first-build.log`
- `l00b.02/02b-at-inputs-final.json`
- `l00b.02/02b-at-kind-boundary.log`
- `l00b.02/02b-at-lean-version.log`
- `l00b.02/02b-at-previous-boundary.log`
- `l00b.02/02b-at-public-api.md`
- `l00b.02/02b-at-scope-check.json`
- `l00b.02/02b-at-source-changes.json`
- `l00b.02/02b-at-start.json`
- `l00b.02/02b-at-step-coverage.json`
- `l00b.02/02b-at-validate.py`
- `l00b.02/02b-at-validation.json`
- `l00b.02/02b-at-values-boundary.lean`
- `l00b.02/02b-at-values-boundary.log`
- `reviews/RV-L00b.02b-at-request.md`：本依頼。

既存の変更文書は`l00b.02/signatures.md`、`results.md`、`large-records.md`の3件である。全新規ファイルとハッシュ・相対リンク・100 KBの上限・本番入力の一致は[範囲の照合](../l00b.02/02b-at-scope-check.json)にも記録する。レビューの結果は`reviews/RV-L00b.02b-at.md`へ置き、取り込み・受け入れは取りまとめ・設計者が行う。
