# plan へ転記する内容

2026-11-01。B_WORK `f4952052e9474f40ac9a257d260065cf8103cfaf` に対する L10.55〜.59 の担当分。これは取りまとめへの転記案であり、plan.md は変更していない。L10 の段末独立レビュー、所見の処置、work/RSS、受け入れを実施した後、取りまとめが状態を決める。今の時点で段全体の完了へ置き換えない。

## 段の表と完了の証拠

| 転記先 | 写す内容 | 証拠 |
|---|---|---|
| L10 の作業欄 | 定義・葉・共通基盤・kind表と全中間判断の旧入力、限定等号、二つの予算判定のcheckLimitへの改名、幅/Byte/Decimal/Top/Requestと07-04の同期を完了 | [results](results.md)「段の表のL10の完了条件との照合」。全導出/状態の埋め込みと全主定理の合成はL20/L70のまま |
| L10 の検査/受け入れ欄 | 担当の既定lake buildは774ジョブ・sorryなし、全対象の公理依存は許可三公理だけ。段末レビュー/最終work/RSS/受け入れは未実施 | build-result.json・axioms-result.json、RV-L10-request |
| L20 の前提 | handoffの七判断と状態の完全署名、全中間型の入力、constructor欄/arity、三種の親判断を受け取る | [handoff](handoff.md)、handoff.lean とその型検査 |
| L70 の旧判断の処置 | 旧Step一段可換性のembedStepは撤回。適格な旧型付け/状態の片方向の橋と、新Step/stepの一致・主定理・表層・全交換を分ける | handoff「embedStepの撤回」。無検査のLegacyRuntimeRelationを置かない |

## 見込みと算入先

| 段/算入先 | 現在の見込み | 転記案・根拠 |
|---|---:|---|
| L10本体 | 29〜61時間 | 実施済みの残りを0へ移すのは受け入れ後。実績はV〜Aの担当側外側約5時間27分＋今回F群で、能動時間未分離。レビュー約1時間42分は別欄。29〜61との比で他段を縮めない |
| TODO-294の相乗り枠 | .57は0.5〜1時間、相乗り残り5.5〜11時間 | 二つのLean名と読者だけの改名を実施。実績をL10本体へ二重計上しない。F群の能動時間を単位ごとに分離できないので、新しい単価を作らない |
| L20 | 34〜80時間 | 据置き。形成の基盤・Ordinaryの供給元がそろい、新しい定義の再作成は不要。全帰納と全旧埋め込みの実績なし |
| L40 | 15〜35時間 | 据置き。変性の利用側の葉とδ、独立評価のreturned/failedと数値の一致が残る |
| L70 | 24〜62時間 | 据置き。WellFormedの定義を再作成しない。収集の一致、有限支持の全利用先、深い経路の費用、全交換は未測定 |
| その他の段と待ち | 既定の見込みを継承、待ちは不明 | 今回の結果は数値を更新する能動時間の材料ではない。新しい言語機能/公理/精密な状態/提供の制限を追加していない |

S前半の同種19件は17件＋残2件で完了。A_17/c_gは待ちから分離できず未取得、当時のN_g=2から現在は0となった。同種の残りの見込みは0であり、L20/L40の別種の作業へ平均を掛けない。段の見込みの移動はdetailで確定したものを継承し、今回もう一度移動した扱いにはしない。群別の内訳と計画作成時間の別枠はresultsにある。

## G/H と既存の配分の追記

| 行/送り先 | L10で完了したもの | 後段に残す完了条件と見込み（各段の内数） |
|---|---|---|
| G03 | WFImages、実際の型引数のWF/Ordinaryの反転、raiseの結果型Tの像[T]、op/methodの具体化の代表 | 捕捉のある閉包と複数引数、全本体の型置換、tappのSorted/Declared、PatTy/AltsTy/Exhaustiveの型置換。入れ子の継続を持つ像を全状態へ接続。既定枠、追加時間は不明 |
| G04 | 四名前空間のWF/VarsIn/RowsIn/RangesScoped、像の条件付きのbind/subst、支持 | kind/ProperApply/Sorted/Declaredの全移送と旧読者12件の形成への接続。RawWF・旧同値・WF→Canonicalを復活させない。既定枠 |
| G06 | 正規化を読むPatTy/P_Refined/P_Convert、意味からInhabitsの入口 | v : a.normと成功からδ.map Ty.normの型付けを示す。rawへ戻す形成とRustの束縛型の照合。既定枠 |
| G07 | 計算できるfnViewWith?/foldFnWithと支持付きの一致 | その他の形成/置換/呼出し5〜12時間。支持前提なし版を追加するか判断し一般証明を閉じる。同じ決定手続きは再作成しない |
| G08 | Def/ImplDecl/Program.WellTyped、Qの一致、Program.WellFormed、kind表/旧入力/親判断 | PrimSig.Scoped/sig_scopedの全量化と実表の充足、ソースだけの宣言本体の入力と三親判断、全宣言/状態の旧埋め込み。既定の1〜3時間の配分を単純に完了扱いしない |
| G09 | ValueMeaningと観測の移送、正規化、D27の代表、型付け→意味→所属の契約 | 全型付けの帰納と全部分型/任意の腕・捕捉へ接続4〜8時間。意味を新しい主定理の仮定にしない |
| H02 | P付きdata変性、構造検証/欄の形成と単調性、非出現引数の不変 | 標準data/δ/canonical formsの利用側の葉1〜3時間 |
| H04 | 共有近似のWF/空判定、BaseApproxと実Reportの写し、七整数の写し | 独立評価からReleaseの正常/returned/failedの条件付き所属。J04のfailedの条件を確定し、mayFailの複写を健全性にしない。元の値との一致が要ればconstOK_toApproxへ補題を追加。既定枠 |
| 旧埋め込み | 七判断46局所規則と全中間判断、表・kind・構文入力、値の葉 | 全導出の入力の継承、全七判断/全状態の片方向の埋め込み、空の局所文脈のk=0の移送。ValueAssumptionsを独立の新前提にしない。L20の既定枠 |
| L70/R10b | 格納済みmetadataの構造検査、網羅性の代表、内外の説明 | 元の辞書制約/公開境界の全収集と変性の一致。公開境界に行変数を残すならMetadataScopedの行0個の条件と整合。Γ/Φからscrutineeの非空型を静的に合成。P_Var/P_Refined/P_Convertの束縛型を照合 |
| L70の有限API | 有限比較/正規化と一致、候補の支持の定義 | 注釈/型/行/Tel/Fail内部を覆う支持を全比較/正規化へ渡す。深いAtom.codeの費用は浅い入力から確認し、符号順を今回変更しない |

## 義務の担当と状態へ写す表

担当欄にL10が既にあるものは据置き、O005/O033/O079の追記済みの判断も重ねて変更しない。O037/O066/O138は後段への契約の引渡しの確認であり、L10を表層実装の担当として追加しない。次表はresultsの全37行と一対一である。「L10分完了・後段未完」を義務全体の完了へ置き換えない。独立レビューの結果による修正は取りまとめが追記する。

| 義務・分類 | L10 の段別判定・証拠 | L10 の後に残る段と理由 |
|---|---|---|
| O011・A | L10分完了：R/Syntax.ConstOK・Typing.V_Const/V_Bytes、LegacyValues.embed_const/embed_bytes、ApproxAdapter.constOK_toApprox。全幅・Byte・Decimal の前提と旧入力を確認し、Syntax/01-12/07-04を同期 | L40 の標準δ/正常結果の葉。新前提を置いただけでδを閉じない |
| O013・C | L10分完了：R/Syntax.ConstOK の valKind/valContent、LegacyValues.embed_checked_opaque/embed_checkedRequest_opaque と scoped_forget。ShapeOk.single は opaque を読み、scoped は忘却で渡す契約を確認 | 本体は L50：typed shapeAt・TargetAgreement・io_exists と三モデル。L10 が全モデルを閉じる配分を訂正する |
| O015・B | L10分完了：群Vの提供表（v/results.md）、R/ScopeSyntax.Sort/Measure と Context の HasSort/Sorted、TermSyntax.Source。全sortの既済み定義を継承 | L30 の有限規則・論理への接続、L50 の所属と具体化の意味 |
| O035・C | L10分完了：R/Typing.V_CheckedRequest、HeldValues.inv_checkedRequest/checkedRequest_widen、LegacyValues.embed_checkedRequest、ModelHttp.valueRun_request。同じ内容と端点を保つ入力を確認 | 本体は L40 のδ・節、L50 の全δ/拡大/対象一致と存在。構成子追加は既済み |
| O042・A | L10分完了：R/Le.embedLe/embedCovers、LegacyKinds.embedProgramWithKinds、LegacyValues の四葉、LegacyRegularity.LegacyOutputInput.old。既定importを維持。全導出はhandoffの未実装契約 | L20 の全導出・状態の埋め込み、L70 の読者切替 |
| O044・A | L10分完了：Syntax の ConstOK コメント、01-12「篩を含むコア計算の形式化」、07-04「篩を含む形式化の範囲」。旧抽象化からの変更と旧主定理の成立範囲を区別 | L50 の対象の葉、D10 の公開文書の最終照合 |
| O049・A | L10分完了：LegacyInput.LegacyHeldTypeInput と LegacyValueInput.checkedRequest、LegacyValues.embed_checkedRequest と scoped_forget。ground・reqTarget一致・同じ保持要求/Top拡大を保持 | L50 のσ/対象の具体化、L60 の全モデル。L00b.13 の葉を作り直さない |
| O050・B | L10分完了：群Vの提供表、R/Context の sort と ClosedEvaluation/ObservationOrder/ObservationSubstitution。関数/Reference/資源の等号を追加せず、評価失敗をNotの真へ変えない | L20 の観測と全置換の交換、L30 の規則の健全性 |
| O065・A | L10分完了：LegacyTables.constructorArity/constructorFields/constructorScope、LegacyNodeRegular と全46規則、TypeSupport/FiniteSupport/TypeBounds、LegacyValues.embed_normal_eq_iff。handoffに全前提・旧読者12件と追加二件を固定 | L20 sig_scoped/全文脈/全埋め込み、L40 変性の利用側の葉、L50/L60 表の充足。旧全域の同値は求めない |
| O076・A | L10分完了：07-04の旧Releaseの対象外行を保持し、Refinement.ConstOKの行と説明を追加。数値・Top・Request の抽象化の差を01-12と同期 | D10 の最終文書。旧名前空間の説明を誤って新規則へ書き換えない |
| O087・C | L10分完了：群Vの提供表、R/Syntax.ExternalTypeDecl/ExternalSignature/Program.externals、External.Program.ExternalWF。全入れ子と専用IDの定義を継承。実表の交換は未完 | 本体は L60/R50：実表、三条件、名目IDの交換と両除外0。L10へ実表実装を重ねない |
| O116・A | L10分完了：Interval/Budget.lean の private checkLimit と補助二件、Surface/ScopeState.lean の Budget.checkLimit/checkLimit_ok/checkLimit_error。旧名の全Lean読者0、01-12/07-04の参照一致、改名以外の差分0をscope-checkで確認 | L70 の最終切替と残る全読者検索 |
| O124・B | L10分完了：ConstOK/Shared.IntegerValue/Refinement.ApproxAdapter.constOK_toApprox、a/boundary.integer_endpoints/integer_endpoint_entry の14端点。群Aの証拠を継承 | L40→R10a/R10b/R40/R50→V10 の規則・実装・交換・CLI |
| O125・B | L10分完了：ConstOK.byte、Typing.V_Bytes、群VとAのByte境界。述語は共通integer sortを維持。IntKindの七種とByteを混同しない説明を追加 | L40→R10b/R40/R50→V10 |
| O126・B | L10分完了：群Vの提供表、R/Syntax.Const.character・TermSyntax.Term.character・ScopeSyntaxのcharacterCode。Charの値とsortを継承 | L40 の値域/比較の葉→R10b/R40/R50→V10 |
| O127・B | L10分完了：群Vの提供表、TermSyntax.Pred.charactersIn と Context/ClosedEvaluation。有限の文字範囲だけを継承 | L30/L40 の有限規則/葉→R10b/R40/R50→V10。正規表現の一般判定を足さない |
| O128・B | L10分完了：群Vの提供表、R/Syntax.Const.float64/float32、TermSyntaxの分類・比較とClosedEvaluation。整数の線形理論へ一般化しない | L40 の特殊値/比較の葉→R10b/R40/R50→V10。一般算術を実数線形にしない |
| O129・B | L10分完了：ConstOK.decimal、a/boundary.decimal_bounds/non_integer_other、constOK_toApproxの七整数への限定。係数両端/scale28/29とotherを継承 | L40 の正常結果/丸めの葉→R10b/R40/R50→V10 |
| O130・B | L10分完了：群Vの提供表、ScopeSyntax.Measure.stringBytes/stringCharacters とTermSyntax.Source。二つの長さを区別 | L30/L40 の関係と葉→R10b/R40/R50→V10 |
| O131・B | L10分完了：群Vの提供表、ScopeSyntax.Measure.listLength、TypeSupportの再帰条件、CoverageRefinement.length_refinement_coverage。List共変と観測不能slotを継承 | L30/L40 のmap/reverse/append/filter等の契約→R10b/R40/R50→V10 |
| O132・B | L10分完了：ScopeSyntax.Measure.bytesLength と Typing.V_Bytes。数学上の非負長と要素の255以下を別条件として継承 | L30/L40 の非負/標準契約→R10b/R40/R50→V10 |
| O133・B | L10分完了：群Vの提供表、Measure.mapSize、VarianceValidation/VarianceTransport のMap鍵の不変/値の共変と観測の重複縮約を継承 | L30/L40 の鍵の等値・大きさ/標準契約→R10b/R40/R50→V10 |
| O134・B | L10分完了：群Vの提供表、Measure.setSize と変性検証のSet要素の不変、重複縮約の観測を継承 | L30/L40 の鍵の等値・大きさ/標準契約→R10b/R40/R50→V10 |
| O135・B | L10分完了：R/Declared の FieldRef.Declared、VarianceFormation/VarianceTransport.variance_field_mono、TypeFormation の欄の形成。総称欄と型代入を継承 | L30/L40 の合同・data変性・decode契約→R10b/R40/R50→V10 |
| O144・B | L10分完了：Conjunction/RefinementNormalForm/Normalize、CoverageRefinement.empty_refinement_exhaustive、群Vの提供表。構造等号・true/空篩・有限の論理を継承 | L30/L40/L50→R20/R10b/R40/R50→V10。一般UF/SMT/量化/非線形/入れ子measureは追加しない |
| O159・A | L10分完了：ProgramTyping の Def/ImplDecl/Program.WellTyped と method_body、ProgramWellFormed.Program.WellFormed、P付き22規則と Patterns.Exhaustive/Inhabits、kind表。全構成子と後段の切替先をhandoffへ固定 | L70 の主定理/交換/規範の切替と旧互換の利用者の確定 |
| O160・D | L10分完了：s2/foundation-map.json と foundation-check.json。158=16+43+31+68、115対応先を今回の公理監査一覧へ再照合。S前半の最初17件と残2件の分離を継承 | L20/L40 の別種の追随は各段で更新。L00aの比とL00bの代表を重ねて掛けない |
| O167・B | L10分完了：v/results.md の DET-L01〜31 の表と提供表を継承。unusedを導入せず、Byte/七幅の述語比較を維持。表層の拒否・CLIを完了としない | L20/L30/L40/L70→R10a/R20/R10b/R40/R60→V10。比較連鎖等は表層、暗黙動的検査なしはRust/CLIで別判定 |
| O169・A | L10分完了：Shared.Approximation.possible_iff/not_possible_iff/wf、Interval.ApproxAdapter.normalToShared_iff/baseToShared_mem、BudgetAnalyze.Report.shared_normal、Refinement.ApproxAdapter.constOK_toApprox。returned/failedの所属は未完と明記 | L20/L40 の独立評価→Release/returned/failedの条件付き所属、L70 の合成→R10b/R50。mayFailの複写を失敗の健全性と呼ばない |
| O005・A | L10分完了：VarianceSyntax/VarianceValidation.Program.VarianceValid、VarianceTransport.Ty.LeQ.dataCore/variance_field_mono、Program.WellTyped.variance。非出現引数の不変と検証済み表を継承 | H02の利用側の葉、L20全保存。L70/R10bで辞書制約/公開境界の内外の照合。planのL10/L70追記は取りまとめ |
| O033・A | L10分完了：上記の変性の構造検査、VarianceFormation の欄の形成。07-04の内外の表に元の辞書制約・公開境界の全収集をLean外として明記 | L40標準data/δ。L70/R10bで元の辞書制約/公開境界の全収集と変性を照合し、R50で接続。planのL10/L70追記は取りまとめ |
| O016・E | L10分完了：l10/axioms.lean：197モジュール＋明示20件、20,065印字・20,055固有名。propext/Quot.sound/Classical.choiceだけ。段末の独立レビューは未実施 | 全Lの共通停止条件として各段で反復。独立レビューは取りまとめ |
| O084・E | L10分完了：本書の未完表とhandoff、07-04の名前空間/内外の区分、scope-check。TODO-250の例外を拡張せず、Rustの検査・全比較・主定理の合成を達成済みにしない | 全L/R/Kの例外台帳と最終受入。例外そのものは広げない |
| O037・C | L10分完了：handoffの七判断の全署名と CoverageRefinement.HasTypeVQ.nonempty_from_entails。同じ篩付き結果/効果を保つ契約だけを引渡し | 担当はL70のまま。全表層literal/checker/脱糖の証明をL10で完了としない |
| O066・C | L10分完了：Patterns.Exhaustiveがa.normを入口にすることとPatternSemanticsの反映、handoffの結果/効果の契約を引渡し | 担当はL70/R50のまま。表層/交換の全実証と消去の観測は後段 |
| O079・A | L10分完了：CoverageRefinement.month_exhaustive/empty_refinement_exhaustive/nonempty_exhaustive/length_refinement_coverage/CaptureOk.variable_coverage。unknownで腕を除かない代表と送り先を継承 | L70/R10bはΓのlen(l)=nとΦのn>0から静的にscrutineeを強める。L30は有限の論理の証明書、R50は受理/拒否の接続 |
| O138・C | L10分完了：handoffにΓのlen(l)=n・Φのn>0からの静的合成と、暗黙の動的検査を追加しない契約を記録。全表層は未実装 | L20/L40/L70/R10b/R50/V10の既存配分を保ち、L70/R10bに静的な合成の完了条件を追記 |


O027のRSSは取りまとめの最終workの担当に残す。O118の本番コメントの工程IDは、今回の担当差分に追加していないことと、全段の残りを分けて写す。両行はdetailの37行へ黙って加えない。

## 2026-11-01 の判断の継承

- Ordinaryの追加は、SignatureInstanceの型像の非継続を供給する承認済みの変更である。最上位だけで、入れ子の禁止へ強めない。旧NotContから閉じていない型列へも供給する。
- メソッド本体のQは代入前のQTel ms.telである。method_bodyのQsigへの接続を使い、detailの古いQTel t'へ戻さない。
- unusedは置かず、非出現引数は不変。辞書制約/公開境界の全収集はLean外。metadataのnone/空列の全称を完全性の証拠にしない。
- dataのP付き判断とValueMeaning/Exhaustiveの定義はL10で固定した。G09で全帰納を閉じるまで意味を主定理の前提にしない。
- L00bの見直し8件とguardの判断を取り消さず、旧20信頼欄のうちsig_scopedだけをG08へ残す。

