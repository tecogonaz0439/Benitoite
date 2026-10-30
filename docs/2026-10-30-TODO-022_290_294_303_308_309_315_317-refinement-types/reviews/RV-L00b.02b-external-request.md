# RV-L00b.02b-external：外部と依存する実引数列の群末レビュー依頼

2026-10-31。`.02b-external`の本番定義・言明・前提・証明と補助契約を独立に確認してほしい。自己点検と検査を終えた状態であり、独立レビュー済み・受け入れ済みとはしていない。次のσ/Atの群は起動していない。

## 基準と範囲

- B_WORK：`9184a3ced427d4897fcb234d2ac277f95b60ac0f`。指定ブランチ：`m014/l00b.02b-external`。担当はgitの照合・操作・コミットを行っていない。
- 前の群08f9ac72・f42ab9aaは取り込み済みという起動依頼の指定に従った。処理系・現行設計書・plan.md・旧Release本体は変更していない。
- 範囲はsignatures第12.2節のexternalの行、前の群の申し送り、第19〜24節の関係する判断である。5導出・三族の追加5場合・TypedFactsの全入口・TelArgsのup/bindと逐次具体化・3つの無事象遷移を同じ群で閉じた。
- 補助契約の採用案・理由・捨てた案は [signatures第25節](../l00b.02/signatures.md) にある。主な定理の前提・結論、新公理、提供範囲、利用者の書ける形、精密な外部状態への変更はないという担当の判断も、このレビューで確認してほしい。

## 先に読む資料

1. [共通依頼文](../implementation-request.md)、planの「計画の変更と取りまとめへの確認点」の2026-10-31の行（特に補助契約の委任、案A、RV-values後の判断）。
2. [signatures](../l00b.02/signatures.md)の第5/7/9/12/19〜25節、[resultsの今回の節](../l00b.02/results.md)、[公開宣言の一覧](../l00b.02/02b-external-public-api.md)。
3. [RV-L00b.02b-values](RV-L00b.02b-values.md)、第24節の義務の対応、[contracts](../l00a.06a/contracts.md)、[lemmas](../l00a.16a/lemmas.md)、改造READMEの設計者の決定とdecisions D28/D29/D66/D67。
4. 下の本番の新規4ファイルと既存の変更、補助入力、検査記録。旧の型付け・Stepと対照し、構成子を除いていないかも見てほしい。

## 本番の新規ファイル（全4件）

| ファイル | 内容 |
|---|---|
| [External.lean](../../../formal/Benitoite/Release/Refinement/External.lean) | 外部の受渡し型・Map鍵・全入れ子の出現・borrow/own・署名の効果/適格性・有限表の適格性とlookup補題・呼出しの許容 |
| [ExternalResponse.lean](../../../formal/Benitoite/Release/Refinement/ExternalResponse.lean) | ExternalSignature.instantiate、ExternalArgs、Outcome.Typed、Builtins.ExternalAssumptionsの三欄とno-exit |
| [Ground.lean](../../../formal/Benitoite/Release/Refinement/Ground.lean) | 全値/計算/腕/節/捕捉環境/閉包の自由変数の検査とVal.Ground |
| [TelTyping.lean](../../../formal/Benitoite/Release/Refinement/TelTyping.lean) | TelArgsのnormal/instantiate/length/arguments、外部署名の具体化との接続 |

既存の変更20ファイルは、RefinementのCapture、ConstraintAssumptions、Declared、DeclaredTransport、Embedding、MethodArguments、Narrowing、NarrowingObstruction、Semantics、Step、Subst、SubstTyping、SubstTypingObstruction、Syntax、TypedFacts、Typing、TypingDeclared、TypingShift、ValueBindingの19と、集約のBenitoite.leanである。全24ファイルのSHA-256・新規/既存・前後の行数は [source-changes.json](../l00b.02/02b-external-source-changes.json)、差分は [production.patch](../l00b.02/02b-external-production.patch) にある。

## 特に確認してほしい点

1. **宣言表と名目性。** Program.externalsが有限列であり、ExternalKeyの重複と宣言内IDの一致をExternalWFで検査すること。Ty.Declaredのexternalもlookup・宣言内ID・arity・型引数を検査し、全入れ子・値置換・正規化で保持すること。同じ表示名でも別ID、同じNatでも型IDと関数IDを相互使用しないこと。
2. **borrow/ownと効果。** ExternalOccurrence/ExternalUseAtがList/Map/dataの具体化した全欄を読み、uses_exactが全出現と過不足なく対応すること。引数borrow/結果own、component/resource、外部型を実際に含む場合だけStateを要求すること。通常の資源やIOへ自動追加していないこと。
3. **受渡し型の補助判断と提供範囲。** ExternalValueTypeの有限な導出と構成子一覧が、再帰する無限のABIを通さず、有限の同名の入れ子を不必要に拒まないこと。Map鍵の篩のcarrierを保つこと。dataのUnitを含む補助の上限と、ソース/WITの具体的なABI照合を区別しており、提供範囲を広げたことにも狭めたことにもしていないか。PathBases/Scopeの保持値を作れない構造を、後のexternal_adequateへ使えるか。
4. **許容と葉の正則性。** 外部署名の単相・arity 0をWFで検査し、count/kind/SatAll/Annotationから現在の空の型引数を導くこと。一般の型引数の外部型・篩・外側の値依存を除いていないこと。V_ExternalRefのSignatureInstance、V_ExternalHandleの追加Annotation、C_ExternalとTelArgsからのDeclaredの供給が表層の書ける形を狭めないか。
5. **TelArgsと相互証明。** 各実引数を同じΓ/Φで検査した後にrestへbindすること。Tel.open_shiftのc+1、Tel.open_substのupと部分観測のnone、逐次具体化の交換が正しいこと。三族V20/C13/Vs2/Each2/TelArgs2=各39、三族合計117であること。Rを持たないTelArgsのsubst/narrow/hide/None版を後送していないこと。
6. **閉性と三つの信頼条件。** Val.Groundが型・行・範囲・値の自由変数を検査していること。ExternalArgsが空C/Γ/Φの型付き実引数を持ち、正常応答の存在を前提へ入れていないこと。CoreAssumptionsが三欄を含み、external_typedのno-exitを保つこと。第四の外部仮定や外部の精密な状態を加えていないこと。
7. **意味論と実行。** 既存68遷移を保ち、E_ExternalApply/External/ExternalErrをnoneラベルで加えたこと。直接のexternalCallも捕捉環境で型/値引数を閉じ、ExternalOracleを使うこと。トラップはerror、exitの不適格oracleは非遷移であり、Event.external/E_ExternalExitがないこと。effect_soundnessの既定の結論を変える必要がないか。
8. **既存の境界と申し送り。** TypedFactsのobservation/assume各20と補助88場合、Declared正則性、既存の障害例の言明を保ったこと。第24節の全7所見をexternalで完了と数えず、kind表付き埋め込み・関数型の対応・場所のDeclared・骨格のエフェクト・旧lamのNamesWFを既定の担当へ残していること。

## 検査済みの範囲と残り

最終の既定 `cd formal && lake build` は終了0、640 jobs。Lean4.34.1、既定・単独とも-M 12288。A-Lは67モジュールのprivate/生成宣言と、旧の三モデル・限定互換性の指定7宣言、計8,019宣言を照合し、許すpropext/Quot.sound/Classical.choiceだけだった。sorryAxと独自公理はなく、本番の抜け道の語の検査も0件だった。構成子数と旧68遷移の名前・順序の維持も照合した。

新しい境界はpureの型付け・無事象遷移とstep、トラップ、no-exit（型付き入力にexitを返す表の拒否も含む）、名目ID・未知/重複/arity/component、入れ子のborrow/own、開いた型注釈の非Ground、依存する結果の逐次具体化とTelArgs、有限Boxの同名の入れ子・篩付きMap鍵を確かめる。既存のNone/cont/snapshot/kind、値の葉・Mapの重複・場所の削除・捕捉環境の入力も通した。前の値の群の入力の写しには、新構成子の不可能な場合だけを追加した。失敗した途中の回復用sorryAxを成功に数えていない。

三モデルの外部三条件の充足とexternal_adequateはL60/L70、Program.WellTypedと外側kindは`.03`、σ/At・handlers・closuresは次の既定の群、全状態の保存とstep_sound/effect_soundnessの合成はL20/L60/L70へ残る。今回の範囲の5導出・39場合・TypedFacts・TelArgsの交換をその未完の範囲へ送ってはいない。work・RSS・Rustのテスト・全比較は今回実施していない。

## 改造内の新規ファイルと証拠

- `l00b.02/02b-external-boundary.lean`：今回の境界入力。
- `l00b.02/02b-external-values-boundary.lean`：前の値の群の境界を今回の構成子へ追随した写し。
- `l00b.02/02b-external-axioms.lean`：構成子数・既定import・公理依存の入力。
- `l00b.02/02b-external-validate.py`：入力ハッシュ・差分・既定ビルド・境界・A-L・件数・抜け道の記録用台本。
- `l00b.02/02b-external-public-api.md`：追加した公開62宣言の一覧。
- `l00b.02/02b-external-start.json` と `02b-external-delivery.json`：時計の取得・受け渡しの記録。
- `l00b.02/02b-external-inputs-final.json`、`02b-external-source-changes.json`、`02b-external-production.patch`、`02b-external-artifact-inputs.json`：入力・差分・ハッシュ。
- `l00b.02/02b-external-build.log`、`02b-external-boundary.log`、`02b-external-previous-boundary.log`、`02b-external-kind-boundary.log`、`02b-external-values-boundary.log`、`02b-external-lean-version.log`：最終の検査出力。
- `l00b.02/02b-external-commands.json`、`02b-external-axioms-summary.json`、`02b-external-step-coverage.json`、`02b-external-validation.json`：最終のコマンド・集計・照合。
- `l00b.02/02b-external-first-commands.json`、`02b-external-first-values-boundary.log`：前の群の入力をそのまま実行した初回の不足と、修正前の記録。
- `l00b.02/02b-external-scope-check.json`：担当範囲・禁止した範囲・相対リンク・100 KBの上限の照合。
- `reviews/RV-L00b.02b-external-request.md`：本依頼。

既存の変更文書は `l00b.02/signatures.md`、`results.md`、`large-records.md` の3件だけである。100 KBを超える公理依存の生の出力は一時領域に置き、改造にはlarge-recordsの大きさとSHA-256だけを残した。新規ファイルの照合はscope-checkの一覧も参照してほしい。
