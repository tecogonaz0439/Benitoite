# L10 段末の独立レビュー依頼

2026-11-01。初回の段末独立レビューはRV-L10.mdに条件付き可として記録済みである。今回は中1〜5・軽1〜6の処置を取りまとめへ渡す。末尾の取りまとめの追記に従い、全体の再レビューは置かず修正箇所を確認する。実装担当の自己点検を修正の独立確認や設計者の受け入れ済みと記録しない。

## 対象と固定する入力

指定ブランチは `m014/l10.f`、B_WORK は `f4952052e9474f40ac9a257d260065cf8103cfaf`。L10.54まで取り込み済みという起動指示を受け、今回L10.55〜.58と.59の担当分を加えた。gitの状態を変える操作はしていない。初回F群からの本番の差分は6ファイル（Lean4・設計書2）である。今回の再開で変更した本番はLegacyInput.leanと01-12/07-04の3ファイルだけであり、Leanの変更は軽1の旧宣言入力と供給元の二補題に限る。l10/fと本依頼を更新し、RV-L10.mdとrv-f-t1〜t3は変更していない。[入力ハッシュ](../l10/f/inputs-sha256.json)で対象を識別する。

最初に [implementation-request](../implementation-request.md)、[detail](../l10/detail.md) の義務・.55〜.59・旧読者・前提・検査・転記、[plan](../plan.md) のL10完了条件・停止条件・2026-11-01の判断を読む。その後 [results](../l10/f/results.md)、[handoff](../l10/f/handoff.md)、[transfer](../l10/f/transfer.md) と、V/X/W/K/S1/S2/Aのresults・RV-L10.*の取りまとめの追記を照合する。

レビュー担当はファイルを書き換えず、所見へファイル・定義/定理/見出し・問題・根拠・修正案を付ける。定義から確定する誤りと、実行による再現を要する振る舞いを区別する。必要な補助入力は本番定義をimportし、定義を複製して妥当性を自己仮定しない。Leanの単一ファイルにも `-M 12288` を付ける。100,000バイト超の生出力は一時領域へ置き、大きさとSHA-256だけを記録する。

## 全完了条件の証拠と確認点

| L10の完了条件 | 実装・定理・記録 | 独立レビューで確認する点 |
|---|---|---|
| 外部呼出しの構文・遷移 | `Refinement/Syntax`の外部ID/宣言表、`Semantics.E_ExternalApply/E_External/E_ExternalErr`、`Step.step`、`ExternalResponse/ExternalConnection` | 全入れ子の専用型をopaque/Topで失わず、応答の三条件と受信後検査を分ける。全状態/実表の証明を完成扱いしていないか |
| σ | `ScopeSyntax.PathEnv`、`Preparation`、`AtPrepare`、`AtTyping`、`BuiltinResponse` | 一つの実行で固定、必要な束縛を明記、静的な判断にσを追加していないか |
| 範囲付き値と状態の全構成子 | `Typing.V_Checked/V_CheckedRequest/V_CheckedAt`、`RuntimeSyntax/StateTyping`、`HeldValues` | 同じ要求全体と端点、groundVal、valContent区分、Topでの保持、捕捉・K_Update注釈・腕の観測を保つか |
| 追加した構成子へのshift/subst/Covers/V_Sub/C_Subの追随 | `TypingShift`・`TypeShiftTyping`・`SubstTyping`・`Narrowing`・`EffectCover`。群Vの22規則と304枝、群S2の76構成子の証拠。今回の全宣言の公理依存 | 型/値移動、値置換と全本体の型置換を混同せず、主な十言明の前提と結論を維持しているか。Ordinaryが実際の型像から供給されるか |
| kind・旧入力・埋め込み | `LegacyKinds/LegacyDeclarations/LegacyInput/LegacyRegularity/LegacyTables/LegacyTableFacts/LegacyValues`、handoffの全署名と型検査 | constructor全欄のAnnotation/HasKind/SourceScopedと同名arity、全46局所規則の中間型・拡張Γ/R/Lを検査するか。旧→新のPatTy/PatTys/AltsTy/ExhaustiveがLegacyNodeTypesと表の条件を持つか。新型付けの結論を入力にしていないか |
| 宣言本体と状態の受渡し | handoffの七判断＋状態の契約、functionBodyInput/methodBodyInput/superBodyInputと全lookupのdeclarationBodyInputs | C/Q/Γ/R/効果/κが旧WellTypedのままか。七判断の帰納が∀Φで、空Φを系とし、weaken_conditionsのValueAssumptionsを追加していないか。メソッドのQは代入前か。LegacyDeclarationsInputで導出全体を代用していないか。未定義のLegacyStateInput/未証明の全埋め込みを明記しているか |
| 旧読者と局所文脈 | handoffの旧読者12件・closedArgs_of/ClosedArgs.single・別枠のnorm_legacy二件、LocalCtx.Shift.emptyを使うk=0の契約 | 新VarsInから非継続を結論していないか。raiseの像は結果型Tか。旧extend n []と新localExtend n []を等号で済ませず、ValueAssumptionsを新しい独立前提にしていないか |
| embedStepの撤回 | handoffのE_Funの旧instantiateと新Closure.mkの不一致 | 適格な型付けの片方向の埋め込みを維持し、単純一段可換性や無検査の実行関係を要求へ戻していないか |
| 幅/Byte/Decimal/Top/Requestと07-04 | SyntaxのConstOKコメント、01-12「篩を含むコア計算の形式化」、07-04「篩を含む形式化の範囲」と対応表/旧対象外行 | 数値の新前提・V_Bytesの別前提・Topの裸opaque除外・Request保持を区別するか。旧主定理の欠陥の修正という説明になっていないか |
| 変性・網羅性と内外 | `VarianceValidation/VarianceTransport/ProgramTyping/ProgramWellFormed`、`ValueMeaning/ValueMeaningInhabits/CoverageRefinement/Patterns`、01-12・07-04 | 提供されたmetadataの構造検査と原ソースの辞書制約/公開境界の収集を分け、後者がLean外であるか。意味を主定理の独立前提にせず、G09の全帰納と型付き入力からの全接続を残しているか |
| 有限支持・近似・foundation | `TypeSupport/FiniteSupport/FiniteCompare/FiniteFunctionView/Finite`、`Shared.Approximation`・両ApproxAdapter・`BudgetAnalyze`、foundation-check.json | 158=16+43+31+68、不要を実装済みと数えず115の存在照合と型の照合を分けるか。有限比較の支持前提、normal/returned/failedとmayFailの射影を区別するか |
| 二つの改名 | `Interval/Budget.lean`のprivate checkLimitと二補助、`Surface/ScopeState.lean`のBudget.checkLimit/checkLimit_ok/checkLimit_error、01-12/07-04 | checkLimitは担当案で、意味の変更がないか。逆改名後の開始時ハッシュ一致、旧Lean名0件、Rust不変をscope-checkと照合 |
| 既定ビルド・公理依存 | build-result.json：774ジョブ/終了0/sorryなし。axioms-result.json：197モジュール＋明示20件、20,067印字/20,057固有名 | 新旧主定理・モデル・都合の悪い例を既定importから外していないか。許可三公理だけか。標準公理の依存だけで定義と言明の妥当性を認定していないか |
| 全37義務・実績・後段への配分 | resultsのA12/B16/C6/D1/E2と残る段、transfer、effort-ledgerの群V〜A担当約327分・レビュー約102分 | 37行を義務全体の完了にしていないか。外側時間と能動時間を分け、29〜61の比をL20以降へ一律に掛けず、G10の全46規則＋状態13〜29時間を数え、L20の47〜109時間の案が上端80を越えると明記するか。既存移管5〜9時間の照合差を隠していないか |

## RV-L10の修正箇所の確認

全11所見の処置表はresults「RV-L10の所見ごとの処置」にある。取りまとめは以下を確認する。

| 所見 | 修正箇所と検証 | 未実装と区別する点 |
|---|---|---|
| 中1 | handoff.leanの七判断は∀Φ。handoffの帰納の経路はC_If/let/lam/腕の子のΦへ直接特殊化 | 全七判断の埋め込みの証明自体はG10 |
| 中2 | 条件付きのパターン/網羅性4契約と、rv-f-t2のrvarの反例の範囲 | checkedAt/atErrorを含む一般証明は未実装 |
| 中3 | handoff専用表のO037/O066/O138、transferの表層の行 | 同じ篩付き結果/効果、unknownで腕を除かず、暗黙の動的検査を足さない契約の受渡しであり、表層実装の完了ではない |
| 中4 | 三文書のCaptureWF/CaptureSorted/CaptureDeclared、ImageOk、close_wf/ground_term、L20最初の適合の確認 | CaptureWF→WFは偽。全正則性は未確認で、強いCtx.WFを足して閉じない |
| 中5 | transferのG10と4群の13〜29時間、G01〜G10と移管控除の積み上げ、L20の完了条件への追記文案 | 47〜109時間の提案は現行34〜80に収まらない。plan変更・起動・設計者への提示は取りまとめ |
| 軽1 | LegacyDeclarationsInputの操作の二条件と二補題、boundary.leanの受理/拒否、01-12/07-04の入力の写し | 旧プログラムの宣言の適格性は強まる。実装の辞書型kindの供給は既存条件の射影 |
| 軽2 | handoff/transferのVarianceValidによる観測の準備、union_support等の移植 | L30/L40/L70の実装は未実施 |
| 軽3 | 39件の#checkと印字。LocalCtx.Shift.emptyを一件含む一般の署名一覧 | パターンの4契約は定理ではない |
| 軽4 | O118のL10判定は一部（追加0、既存除去未実施）、comment-id-check.jsonの324行とScopeState2行、残る担当案 | 今回はコメント除去のために他のLeanを変更していない |
| 軽5 | sort-correspondence.mdの16行とmember/constructorIs/Booleanの4欄、O015の参照 | 定義の対応でありL30の全健全性の完成ではない |
| 軽6 | transfer末尾のP_Convert/HasData.widen/assume/use/Φの差の注記 | plan/detailは未編集、取りまとめが転記 |


## 主な定理の前提と結論の重点

初回は本番のコメントと二つの改名だけであった。今回の軽1はplan先頭が承認した主な定理の前提の中身の供給元を旧宣言入力へ足すもので、操作の不適格な辞書の宣言は新たに拒む。主な定理の宣言、Program.WellFormed/OpDecl.Scoped/ImplDecl.Scopedそのものは変更していない。新公理、提供範囲、利用者の書ける形、精密な外部状態の追加変更はない。段全体については、既にplanで承認された次の変更の実配置と、結論を弱めない接続を確認してほしい。

- P付きの変性とProgram.WellTyped/WellFormed、本体のTelBodyTy・kind/Annotation、metadataの検証の範囲。
- Ordinaryの最上位の条件、constructor kindとの区別、メソッドの代入前Q、signature/typeScopeから全型置換へ渡す未完の部分。
- 新しいStateTy、固定σ・必要束縛、型付き依存引数/結果/効果、数値の表現可能性、対象なしopaque除外、保持要求のgroundと端点の一致。
- CoreAssumptionsとTargetAgreement、外部三条件と受信後検査、旧20欄のうちsig_scopedだけが未移行であること。EffectsOk/state_effect/io_op/PathBasesShape/ref_get/ref_setを取り消していないこと。
- ValueMeaning→Inhabitsの証明と、型付け全体→ValueMeaningの未完を分けること。returned/failedの意味の接続をnormalやmayFailの複写で代用しないこと。

新体系の全状態のpreservation/progress/step_sound/effect_soundness、表層の型保存とchecker、全交換とRustの実装は今回の完了の対象ではない。それらはL20〜L70/R段の既存の配分であり、今回の局所定理をその全体の証拠にしない。

## 実行済みの証拠と未実施

再実行の入口は根で `python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/f/verify.py build handoff review-boundary review-t1 review-t2 review-t3 axioms`。Leanは4.34.1、メモリ上限は既定buildと単一ファイルでともに-M 12288。大きな生出力の大きさ・SHA-256は [large-records](../l10/f/large-records.md)、全名と依存はl10/f/axioms-names-*.jsonである。初回の表示オプション/空モジュールの失敗と、完全名の集計器の訂正もresultsに残した。

workと段末RSSは取りまとめが最後の同じ実行で行う。01-specのtextブロック24件は開始時と同一なので、今回spec_examplesの条件は発生していない。Rust全libとRust/Leanの全比較は実行していない。11所見の担当の処置は完了し、取りまとめによる修正箇所の確認、L20見込み/完了条件の転記と設計者への提示、受け入れ・取り込みが残る。これらの見込みは不明である。
