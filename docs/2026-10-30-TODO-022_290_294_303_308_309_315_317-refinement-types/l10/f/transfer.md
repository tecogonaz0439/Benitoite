# plan へ転記する内容

2026-11-01。B_WORK `f4952052e9474f40ac9a257d260065cf8103cfaf` に対する L10.55〜.59 の担当分。これは取りまとめへの転記案であり、plan.md は変更していない。段末のRV-L10は実施済みで、11所見の担当の処置を本書へ反映した。取りまとめが修正箇所を確認し、work/RSSと受け入れを終えて状態を決める。今の時点で段全体の完了へ置き換えない。

## 段の表と完了の証拠

| 転記先 | 写す内容 | 証拠 |
|---|---|---|
| L10 の作業欄 | 定義・葉・共通基盤・kind表と全中間判断の旧入力、限定等号、二つの予算判定のcheckLimitへの改名、幅/Byte/Decimal/Top/Requestと07-04の同期を完了 | [results](results.md)「段の表のL10の完了条件との照合」。全導出/状態の埋め込みと全主定理の合成はL20/L70のまま |
| L10 の検査/受け入れ欄 | 担当の既定lake buildは774ジョブ・sorryなし、全対象の公理依存は許可三公理だけ。RV-L10は条件付き可、11所見の担当処置済み。修正箇所の確認/最終work/RSS/受け入れは未実施 | build-result.json・axioms-result.json、RV-L10-request |
| L20 の前提 | handoffの七判断と状態の完全署名、全中間型の入力、constructor欄/arity、三種の親判断を受け取る | [handoff](handoff.md)、handoff.lean とその型検査 |
| L70 の旧判断の処置 | 旧Step一段可換性のembedStepは撤回。適格な旧型付け/状態の片方向の橋と、新Step/stepの一致・主定理・表層・全交換を分ける | handoff「embedStepの撤回」。無検査のLegacyRuntimeRelationを置かない |

## 見込みと算入先

| 段/算入先 | 現在の見込み | 転記案・根拠 |
|---|---:|---|
| L10本体 | 29〜61時間 | 実施済みの残りを0へ移すのは受け入れ後。実績はV〜Aの担当側外側約5時間27分＋今回F群で、能動時間未分離。レビュー約1時間42分は別欄。29〜61との比で他段を縮めない |
| TODO-294の相乗り枠 | .57は0.5〜1時間、相乗り残り5.5〜11時間 | 二つのLean名と読者だけの改名を実施。実績をL10本体へ二重計上しない。F群の能動時間を単位ごとに分離できないので、新しい単価を作らない |
| L20 | 現行34〜80時間→**47〜109時間の提案** | G10の全46規則＋状態13〜29時間を追加。下のG表と既存の移管控除を積み上げる。上端80時間に収まらないため、据置きの提案を撤回 |
| L40 | 15〜35時間 | 据置き。変性の利用側の葉とδ、独立評価のreturned/failedと数値の一致が残る |
| L70 | 24〜62時間 | 据置き。WellFormedの定義を再作成しない。収集の一致、有限支持の全利用先、深い経路の費用、全交換は未測定 |
| その他の段と待ち | 既定の見込みを継承、待ちは不明 | 既存の速さの比で他段を縮める能動時間の材料はない。L20の追加は全埋め込みの配分漏れを数え直したものである。新しい言語機能/公理/精密な状態/提供の制限を追加していない |

S前半の同種19件は17件＋残2件で完了。A_17/c_gは待ちから分離できず未取得、当時のN_g=2から現在は0となった。同種の残りの見込みは0であり、L20/L40の別種の作業へ平均を掛けない。段の見込みの移動はdetailで確定したものを継承し、今回もう一度移動した扱いにはしない。群別の内訳と計画作成時間の別枠はresultsにある。

## G/H と既存の配分の追記

| 行/送り先 | L10で完了したもの | 後段に残す完了条件と見込み（各段の内数） |
|---|---|---|
| G03 | WFImages、実際の型引数のWF/Ordinaryの反転、raiseの結果型Tの像[T]、op/methodの具体化の代表 | 捕捉のある閉包と複数引数、全本体の型置換、tappのSorted/Declared、PatTy/AltsTy/Exhaustiveの型置換。入れ子の継続を持つ像を全状態へ接続。既定枠、追加時間は不明 |
| G04 | 四名前空間のWF/VarsIn/RowsIn/RangesScoped、像の条件付きのbind/subst、支持 | 捕捉の緩い三条件から結果のWF/Sorted/Declared。OrdinaryはTy.CaptureWF.ordinaryからWFへ、継続はImageOkから供給する方式を最初の単位群で確認。close_wf/ground_termは試行の入力で全正則性は未確認。kind/ProperApply/Sorted/Declaredの全移送と旧読者12件も含む。CaptureOkへ強いCtx.WFを足さない。4〜10時間（最初の0.5〜1時間の確認も内数） |
| G06 | 正規化を読むPatTy/P_Refined/P_Convert、意味からInhabitsの入口 | v : a.normと成功からδ.map Ty.normの型付けを示す。rawへ戻す形成とRustの束縛型の照合。既定枠 |
| G07 | 計算できるfnViewWith?/foldFnWithと支持付きの一致 | その他の形成/置換/呼出し5〜12時間。支持前提なし版を追加するか判断し一般証明を閉じる。同じ決定手続きは再作成しない |
| G08 | Def/ImplDecl/Program.WellTyped、Qの一致、Program.WellFormed、kind表/旧入力/親判断 | PrimSig.Scoped/sig_scopedの全量化と実表の充足、ソースだけの宣言本体の入力と三親判断を供給。操作の辞書の先頭/添字はLegacyDeclarationsInput.op_dictionaryInputs、実装の辞書型のkindは同impl_dictionaryKindsを使用。全七判断/状態の埋め込みはG10へ分離。1〜3時間 |
| G09 | ValueMeaningと観測の移送、正規化、D27の代表、型付け→意味→所属の契約 | 全型付けの帰納と全部分型/任意の腕・捕捉へ接続4〜8時間。意味を新しい主定理の仮定にしない |
| H02 | P付きdata変性、構造検証/欄の形成と単調性、非出現引数の不変 | 標準data/δ/canonical formsの利用側の葉1〜3時間 |
| H04 | 共有近似のWF/空判定、BaseApproxと実Reportの写し、七整数の写し | 独立評価からReleaseの正常/returned/failedの条件付き所属。J04のfailedの条件を確定し、mayFailの複写を健全性にしない。元の値との一致が要ればconstOK_toApproxへ補題を追加。既定枠 |
| **G10・全埋め込み（新しい行の案）** | 七判断46局所規則と全中間判断、表・kind・構文入力、値の葉 | **13〜29時間**。全七判断を∀Φで帰納し、条件付きPatTy/PatTys/AltsTy/Exhaustive、空の局所文脈のk=0、LegacyStateInputとframe/store/状態、三親判断への適用を閉じる。ValueAssumptionsを独立の新前提にしない |
| L70/R10b | 格納済みmetadataの構造検査、網羅性の代表、内外の説明 | 元の辞書制約/公開境界の全収集と変性の一致。公開境界に行変数を残すならMetadataScopedの行0個の条件と整合。Γ/Φからscrutineeの非空型を静的に合成。O037/O066はchecker/脱糖が同じ篩付き結果型と効果を保つ契約、O138はunknownで腕を除かず暗黙の動的検査を足さない契約として全表層/交換を照合。P_Var/P_Refined/P_Convertの束縛型も照合 |
| L30/L40の観測の準備 | 群Vのsort_reflect_auxとVarianceValid | Declaredだけでは欄のsortを元へ反映できない。検証済みの同じPのVarianceValidを供給 |
| L70の有限API | 有限比較/正規化と一致、候補の支持の定義 | 旧Surface/FiniteToolsのunion_support等の効果を構成する補助を移植し、注釈/型/行/Tel/Fail内部を覆う支持を全比較/正規化へ渡す。深いAtom.codeの費用は浅い入力から確認し、符号順を今回変更しない |

## L20のG表の積み上げ案

前回の「全埋め込みは既定枠」は配分先がなく誤りだった。G08の1〜3時間は宣言の入力と充足の供給であり、46規則の相互帰納と状態の証明の時間ではない。G10を独立に加える。以下は能動時間の見込みで、実績のない作業は規則群と依存の数を根拠とする幅である。検査/build/レビュー/設計者の判断の待ちは別で、不明である。

| G行 | 作業 | 見込み（時間） | 算入の根拠と重複を避ける範囲 |
|---|---|---:|---|
| G01 | 任意のcloseValの型保存・view/契約・Adequate | 4〜9 | theoremsの配分を継承。G10の旧構文の写しと別 |
| G02 | 零/多引数、捕捉Γ/Φ/局所参照、Closure.apply/Tel.instantiate | 4〜8 | 既存配分を継承 |
| G03 | 型/行/範囲のコードの全置換、tapp、入れ子の継続の像 | 8〜18 | Ordinaryの供給元は閉じたが全帰納は未実施。PatTy等の型置換はここ、旧→新の写しはG10 |
| G04 | 捕捉の三条件からの全正則性・hide・局所構築器・Regular | 4〜10 | 最初の単位群で方式の適合を確認する0.5〜1時間も内数。CaptureWFから継続の潜在効果のWFは得られず、ImageOkの証拠を使う。全正則性は未確認 |
| G05 | 全handler/節/resume/used/dropの保存 | 6〜14 | 全状態の遷移の保存。旧導出の型付けの写しとは別 |
| G06 | 任意のパターン束縛、CaptureOkの延長、MatchBody/Guard | 3〜7 | δ.map Ty.normへの束縛の型保存。旧→新PatTy/AltsTy/Exhaustiveの移送はG10へ一度だけ算入 |
| G07 | StoreOk/ContTy/状態の全葉とstep選択への合成 | 5〜12 | 旧6〜14からfnView定義1〜2をL10へ移した残り |
| G08 | 宣言・準備・外部・解放の入力、sig_scoped | 1〜3 | 旧2〜5からWellTyped定義1〜2をL10へ移した残り。G10へ供給する入力まで |
| G09 | 全型付け→ValueMeaning→Inhabits、任意の腕/捕捉 | 4〜8 | detailで訂正済みの配分。意味の全帰納を主定理の独立仮定にしない |
| G01〜G09の行の小計 | 旧theoremsの行へL10の移動とG09の訂正を反映 | **39〜89** | 39〜90−(G07/G08/G09の3〜6)+(G09の3〜5) |
| 既に合意されたL00bへの移動の照合差 | L00b.02へ移した5〜9時間 | **−5〜−9** | detailの移動の合計を継承。古いG表では個別の行への割当が未記載なので、取りまとめがL20の詳細化でどの部分が済んだか対応を付ける。今回新しく減らす額ではない |
| 現行のG01〜G09の段の見込みへの照合 | 上の小計から既存の移動を一度だけ控除 | **34〜80** | plan/detailの現行の段の数値と一致 |
| **G10** | **適格な旧導出の全46規則と状態の片方向の埋め込み** | **13〜29** | 下の4群の積み上げ。G08やG09の内数へ隠さない |
| **提案するL20合計** | **34〜80＋13〜29** | **47〜109** | **現行の上端80時間に収まらない。前回の据置きを撤回する** |

G表の行の小計だけにG10を足す保守的な合計は52〜118時間である。そこから既に了承された移管5〜9を一度だけ控除した案が47〜109時間となる。個別の移管先の対応が確定するまで、差5〜9時間を新しいG10の余裕と見なさない。これを根拠なくG01〜G09の各行へ割り振って短縮した表は作らない。取りまとめは対応表とG10の新配分を合わせて設計者へ提示する。

| G10の内訳 | 件数/範囲 | 見込み（時間） | 根拠 |
|---|---|---:|---|
| 七判断の相互帰納 | 値19、値列/同型値列4、計算17、腕/節/失敗節6＝46規則 | 7〜14 | 群ごとの配分は2〜4、0.5〜1、3〜6、1.5〜3。既存の値の葉を再実装せず、署名/構文の置換・形成をG03/G04から受け取る。単純な規則数の一律単価ではない |
| 旧→新パターンと網羅性 | PatTy/PatTys/AltsTy/Exhaustive、checkedAt/atErrorと入れ子 | 2〜5 | 無条件の網羅性の含意は偽。LegacyNodeTypesと表の条件から全場合の橋を構成する。G06の束縛型保存やG09の型付け→意味を重ねて数えない |
| Φ・局所文脈・入力の継承 | ∀Φの帰納、k=0の局所文脈、全中間判断の子への入力 | 1〜3 | 既存weaken_conditionsに頼らず、局所文脈の移送も必要。必要な補助を一度だけ数える |
| 状態の入力と埋め込み | LegacyStateInput、全frame/store内のコードと保持値、StateTyE、三親判断への適用 | 3〜7 | 状態/継続/セルを再帰的に検査し、新StateTyの導出を結論として証明する。新型付けを入力の欄にしない |
| 合計 | 上の4群 | **13〜29** | 能動時間の実績は未取得。最初の通常単位で更新 |

捕捉の全正則性（中4）と入れ子の継続はG03/G04の未確認の仕事であり、解決済みと扱って減額しない。方式の適合の確認で新しい仮定や表現の変更が必要になれば、別の増分をこの幅に隠さず停止条件へ戻す。今回L20を起動していないので、現行枠を越えたまま実装を開始しない。

L20の完了条件へ追記する文案:

> 宣言のkind表・全中間判断の正則性・constructor欄とarity・表の対応・表現可能性と保持対象/要求/端点を満たす適格な旧導出について、七判断46規則を任意のΦで新判断へ片方向に埋め込む。条件付きのPatTy/PatTys/AltsTy/Exhaustive、空の局所文脈の橋、三種の宣言本体の親判断、全frame/store内のコードを検査するLegacyStateInputとStateTyEの埋め込みを閉じる。旧Stepの単純な一段可換性は要求しない。L20の最初の単位群で捕捉の三条件とImageOkからの全正則性の方式の適合を確認し、必要な条件を導けなければ独立の信頼条件を追加せず停止する。

## 義務の担当と状態へ写す表

担当欄にL10が既にあるものは据置き、O005/O033/O079の追記済みの判断も重ねて変更しない。O037/O066/O138は後段への契約の引渡しの確認であり、L10を表層実装の担当として追加しない。次表はresultsの全37行と一対一である。「L10分完了・後段未完」を義務全体の完了へ置き換えない。独立レビューの結果による修正は取りまとめが追記する。

| 義務・分類 | L10 の段別判定・証拠 | L10 の後に残る段と理由 |
|---|---|---|
| O011・A | L10分完了：R/Syntax.ConstOK・Typing.V_Const/V_Bytes、LegacyValues.embed_const/embed_bytes、ApproxAdapter.constOK_toApprox。全幅・Byte・Decimal の前提と旧入力を確認し、Syntax/01-12/07-04を同期 | L40 の標準δ/正常結果の葉。新前提を置いただけでδを閉じない |
| O013・C | L10分完了：R/Syntax.ConstOK の valKind/valContent、LegacyValues.embed_checked_opaque/embed_checkedRequest_opaque と scoped_forget。ShapeOk.single は opaque を読み、scoped は忘却で渡す契約を確認 | 本体は L50：typed shapeAt・TargetAgreement・io_exists と三モデル。L10 が全モデルを閉じる配分を訂正する |
| O015・B | L10分完了：[sort-correspondence.md](sort-correspondence.md)で13個の引数なしのsort＋target三種類の16行と、member/constructorIs/Booleanを列挙。WF/Sorted/Source/意味の定義の実在と対応を照合。L30の全健全性とは分ける | L30 の有限規則・論理への接続、L50 の所属と具体化の意味 |
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
| O016・E | L10分完了：l10/axioms.lean：197モジュール＋明示20件、20,067印字・20,057固有名。propext/Quot.sound/Classical.choiceだけ。RV-L10は条件付き可、11所見は担当処置済み。取りまとめの修正確認待ち | 全Lの共通停止条件として各段で反復。独立レビューは取りまとめ |
| O084・E | L10分完了：本書の未完表とhandoff、07-04の名前空間/内外の区分、scope-check。TODO-250の例外を拡張せず、Rustの検査・全比較・主定理の合成を達成済みにしない | 全L/R/Kの例外台帳と最終受入。例外そのものは広げない |
| O037・C | L10分完了：handoffの七判断の全署名と CoverageRefinement.HasTypeVQ.nonempty_from_entails。同じ篩付き結果/効果を保つ契約だけを引渡し | 担当はL70のまま。全表層literal/checker/脱糖の証明をL10で完了としない |
| O066・C | L10分完了：Patterns.Exhaustiveがa.normを入口にすることとPatternSemanticsの反映、handoffの結果/効果の契約を引渡し | 担当はL70/R50のまま。表層/交換の全実証と消去の観測は後段 |
| O079・A | L10分完了：CoverageRefinement.month_exhaustive/empty_refinement_exhaustive/nonempty_exhaustive/length_refinement_coverage/CaptureOk.variable_coverage。unknownで腕を除かない代表と送り先を継承 | L70/R10bはΓのlen(l)=nとΦのn>0から静的にscrutineeを強める。L30は有限の論理の証明書、R50は受理/拒否の接続 |
| O138・C | L10分完了：handoff「表層の結果型・効果と静的な分岐の契約」に、Γ/Φからの静的合成、unknownで腕を除かないこと、不可能腕の検査、暗黙の動的検査を追加しないことを明記。全表層は未実装 | L20/L40/L70/R10b/R50/V10の既存配分を保ち、L70/R10bに静的な合成の完了条件を追記 |


O027のRSSは取りまとめの最終workの担当に残す。O118は「L10: 段全体の追加0、既存の除去は未実施（一部）」と写す。現行の既存行は全Leanで324行、L10が触ったScopeStateにも2行残る。Refinement/Sharedと今回のInterval変更ファイルの残存は0。残存の除去はL70の切替時の既存コメントの処置へ申し送り、Rustの期待位置はR50/R60、文書はD10、同候補の照合はV10で行う案とする（割当の確定は取りまとめ）。両行はdetailの37行へ黙って加えない。

## 2026-11-01 の判断の継承

- Ordinaryの追加は、SignatureInstanceの型像の非継続を供給する承認済みの変更である。最上位だけで、入れ子の禁止へ強めない。旧NotContから閉じていない型列へも供給する。
- メソッド本体のQは代入前のQTel ms.telである。method_bodyのQsigへの接続を使い、detailの古いQTel t'へ戻さない。
- unusedは置かず、非出現引数は不変。辞書制約/公開境界の全収集はLean外。metadataのnone/空列の全称を完全性の証拠にしない。
- dataのP付き判断とValueMeaning/Exhaustiveの定義はL10で固定した。G09で全帰納を閉じるまで意味を主定理の前提にしない。
- L00bの見直し8件とguardの判断を取り消さず、旧20信頼欄のうちsig_scopedだけをG08へ残す。


## detail・planへ加える差の注記

| 定義/工程 | detailの下書きとの差と実装の正 | 根拠と転記先 |
|---|---|---|
| P_Convert | PatTy/PatTysは予定10規則から実際は9+2=11規則。P_Convertは正規形の構造等号で入力型を移し、束縛列をnormへ写す補助規則 | 群X/RV-L10.xで妥当と確認。01-12/07-04へ反映済み。detail Xの規則数と正規化の説明へ注記 |
| Term.HasData.widen | 部分型とDataObservationLeの証拠を保持するwidenを追加し、HasDataは4場合。元のdata引数との等号だけに依存しない | 群V/RV-L10.vで妥当と確認。新公理や主な十言明/提供範囲の変更ではない判断をplanの注記へ写す |
| ValueMeaningの述語列 | a.norm.assumeでなくa.norm.refinementPredicatesを読む。normは不適格な継続型上の篩を消さず、assumeだけがその事実を空にする。適格な篩では両列は一致 | x/resultsの差の記録をdetail X1へ注記。元の定義を変更しない |
| useの値の深さ | 本体は値を束縛せずnvを増やさない。detailのnv+1は誤り | RV-L10.kの取りまとめの追記。detailの旧入力表へ注記 |
| Φの一般化 | 七判断の帰納は∀Φ、空Φはその系。既存のweaken_conditionsへ依存しない | RV-L10中1、handoffの更新。detail Eの旧弱化の一文を訂正 |
| 宣言の辞書 | 操作の辞書の先頭/添字と実装の辞書型のkindを明示。旧入力へ供給元を追加 | plan先頭の承認、LegacyDeclarationsInputの二補題。主な定理の前提の中身の見直しとして記録済み |

この表は取りまとめへの注記案で、今回detail.md・plan.mdは編集していない。
