# L10 仕上げと段末への引渡しの結果

2026-11-01。段末のRV-L10は条件付き可（中5・軽6）であり、今回その11所見を処置した。**修正箇所の取りまとめによる確認、最終work/RSS、設計者の受け入れは未完であり、L10全体の受け入れ済みとはしない。** L10.54 まで取り込み済みという今回の起動指示を入口とした。各群の results に残る当時のレビュー待ちと、今回の処置後の受け入れの未実施を区別する。

指定ブランチは `m014/l10.f`、B_WORK は **`f4952052e9474f40ac9a257d260065cf8103cfaf`**。値は起動依頼から記し、git の読取り・変更操作はしていない。対象はこの基準に今回の担当差分を加えた状態である。初回開始時の入力は [before-sha256.json](before-sha256.json)、今回の再開時の入力は [review-before-sha256.json](review-before-sha256.json)、最終の対象は [inputs-sha256.json](inputs-sha256.json) で識別する。

軽1はplan先頭で、操作の辞書の先頭と実装の辞書型のkindを主な定理の前提の中身として明示することが承認された。今回はその供給元としてLegacyDeclarationsInputだけを強め、操作の辞書の添字と先頭を検査し、実装の辞書型のkindを既存入力から取り出す二補題を加えた。主な定理の宣言、Program.WellFormed/OpDecl.Scoped/ImplDecl.Scoped、型付け・遷移は変更していない。新公理・提供範囲・利用者の書ける形・精密な外部状態の変更はない。旧プログラムの宣言入力の範囲の変化は下の軽1の欄に記す。Rust・plan・detail・effort-ledger・既存レビューと rv-* は変更していない。依頼された新規の RV-L10-request.md だけを reviews に作成した。

## RV-L10の所見ごとの処置

再開の開始は2026-11-01 12:52:01 UTC。上限は3時間である。レビュー原本RV-L10.mdとrv-f-t1〜t3は変更していない。plan/detailも変更していない。軽1の本番変更はLegacyInput.leanだけである。取りまとめの追記の「全体の再レビューは置かず、修正箇所を取りまとめが確認する」に従い、以下の実装・記録・検査を渡す。

| 所見 | 処置と証拠 | 担当分の判定 |
|---|---|---|
| 中1 | 七判断の主たる帰納の結論を∀Φへ変更し、空Φを系とした。C_If/let/lam/腕/checkedRequestの子へ必要なΦを直接特殊化する。weaken_conditionsがValueAssumptions/store.WFを要することを明記し、その経路を撤回。handoff.leanの七契約を型検査 | 完了 |
| 中2 | LegacyNodeTypesと表の条件を持つ旧→新のPatTy/PatTys/AltsTy/Exhaustiveの完全署名を追加し型検査。rv-f-t2の無条件の含意の反例と、範囲深さ0の入力が拒むことを明記。全証明はG10 | 契約の受渡し完了。一般証明は未実装 |
| 中3 | handoffにO037/O066/O138専用の表を追加。同じ篩付き結果型/効果、unknownで腕を除かない、不可能腕の検査、暗黙の動的検査を足さない契約を明記しtransferへ写した | 完了 |
| 中4 | handoff/results/transferに捕捉の三条件、Ty.CaptureWFとWFの差、Ordinaryの回復とImageOk、close_wf/ground_termの試行を記録。L20最初の単位群で方式の適合を確かめ、全正則性は未確認とした | 受渡し完了。全正則性はG04で未実装 |
| 中5 | G10として全46規則＋状態の行を新設する案、13〜29時間の4群の積み上げ、L20完了条件の追記案をtransferに追加。現行34〜80の据置きを撤回し、47〜109の案と既存移管の照合差を提示 | 完了。見込み/配分の承認と転記は取りまとめ |
| 軽1 | LegacyDeclarationsInputの操作に辞書の添字の上限と先頭の一致を追加。op_dictionaryInputs/impl_dictionaryKindsを本番に追加。boundaryのbadOp/badIndexの拒否、正しい操作と実装の受理、実際のkind供給/クラスなしの拒否を検査。01-12/07-04にも入力の条件を反映 | 完了 |
| 軽2 | 観測の準備で同じPのVarianceValidを使うL30/L40の義務、L70のSurface/FiniteTools.union_support等の移植をhandoff/transferへ追加 | 完了 |
| 軽3 | 「局所文脈の37署名」を一般の署名一覧へ訂正。現行は39宣言（元の37＋軽1の二補題）でLocalCtx.Shift.emptyを一件含む。実際の#checkと印字を照合 | 完了 |
| 軽4 | O118をL10一部（追加0、既存の除去未実施）と明記。現行324行、ScopeState2行を再確認し、残りの担当案を記録 | 完了。既存コメントの除去そのものは未実施 |
| 軽5 | sort-correspondence.mdの全16行とmember/constructorIs/Booleanの表に、WF/Sorted/Source/意味を対応。O015の根拠を更新 | 完了 |
| 軽6 | P_Convert（予定10→実際11）、HasData.widen（4場合）、refinementPredicates/assume、useのnv、Φの一般化の差の注記をtransferへ追加 | 完了。detailへの転記は取りまとめ |

操作の辞書の先頭又は添字が不適格な旧プログラムのLegacyDeclarationsInputは新たに拒む。そのため旧プログラムの適格な宣言入力の範囲は強まる。旧七判断のLegacyOutputInputと個別の型付けの範囲は変更していない。実装の辞書型のkindは既存入力にあるので、補題の追加による範囲の変化はない。主な定理の前提の中身を明示する判断は今回のplan先頭の承認によるもので、新しい未承認の仮定ではない。合法なソースからの辞書挿入との全一致はG08/R10bに残す。

### 捕捉からの正則性の残り

rv-f-t1のk0はCaptureWFを満たしても潜在効果内のtvar 0のためWFを満たさない。緩い三条件CaptureWF/CaptureSorted/CaptureDeclaredから、単純にTy.bind_wfへ進む全正則性はまだ示していない。Ordinaryの束縛はTy.CaptureWF.ordinaryでWFへ戻し、継続の束縛はCaptureOkのImageOk（contLocの閉じたWF、contVarの型付き文脈の証拠等）から供給する方式をL20の最初の単位群で確認する。close_wf/ground_term/close_wf_groundはs2/rv-s2-t2の試行であり、本番の全正則性として数えない。CaptureOkへ強いCtx.WFや新しい独立の仮定を追加せず、必要な形成を導けなければ停止条件へ戻る。

### 全埋め込みの見込みの訂正

G10は七判断46規則7〜14時間、条件付きパターン/網羅性2〜5、∀Φとk=0/入力継承1〜3、状態入力/frame/store/StateTyEと三親判断への適用3〜7、計**13〜29時間**である。G08の宣言の入力/形成、G06の束縛の型保存、G09の全型付け→意味を再計上しない。規則群と依存からの見込みで、能動時間の実績は未取得である。

既存G01〜G09の行へL10の移動/訂正を反映すると39〜89時間となり、detailで合意したL00bへの移管5〜9を一度だけ控除すると現行34〜80と一致する。G10を加えた提案は**47〜109時間**であり、現行の上端80に収まらない。移管控除前の保守的な小計は52〜118時間。古いG表には移管の個別の割当が未記載なので、取りまとめがL20詳細化で既済み部分を対応させる。差を新G10の余裕へ流用しない。L20の完了条件へ七判断と状態の片方向の全埋め込みを追記する文案をtransferに書いた。上端を越える提案であり、今回L20を起動していない。

## 起動単位の判定

| 単位 | 担当分の判定 | 証拠 |
|---|---|---|
| L10.55 | 完了 | [handoff.md](handoff.md)。LegacyTables の全欄、LegacyNodeRegular/LegacyOutputInput、七判断＋状態の全署名、三種の親判断を lookup ごとに全称化。旧読者12件と追加二件、空の局所文脈とembedStep撤回を固定。[handoff.lean](handoff.lean) は命題の定義の型検査であり、未実装定理の証明ではない |
| L10.56 | 完了 | R/Syntax.lean のコメント、01-12・07-04。ConstOK、Byte/Decimal/bytes/Top/Requestと旧対象外を区別。辞書制約・公開境界の収集はLeanの外と明記。工程IDや将来の照合の予告を追加していない |
| L10.57 | 完了 | 二つのadmitをcheckLimitへ改名。関連補題・全Lean読者・01-12/07-04を更新。checkLimitはdetailに記された担当案である。[rename-counts.json](rename-counts.json) と [scope-check.json](scope-check.json) |
| L10.58 | 完了 | 本書の37義務・foundation158件・旧読者・見込み・前提、[transfer.md](transfer.md)。planへの転記と判断は取りまとめ |
| L10.59 の今回の担当分 | 完了 | [../axioms.lean](../axioms.lean) の実行と [axioms-result.json](axioms-result.json)、[段末レビュー依頼](../../reviews/RV-L10-request.md)。RV-L10の11所見は今回処置。修正箇所の確認・最終work/RSS・受け入れは取りまとめ |

R/ は `formal/Benitoite/Release/Refinement/`、I/ は `formal/Benitoite/Interval/`、旧は `formal/Benitoite/Release/` を表す。

## 段の表の L10 の完了条件との照合

plan の L10 行の三文を要素ごとに分け、detail の群と照合した。ここでの完了は担当分であり、レビュー受け入れの代行ではない。

| 完了条件の要素 | 判定とファイル・定理名 | 未完の区別 |
|---|---|---|
| 外部呼出しの構文 | 定義あり。R/Syntax の ExternalTypeDecl/ExternalSignature/Val.externalRef/Comp.externalCall、External.Program.ExternalWF | 実表・三モデルと全交換はL60/R50 |
| 外部呼出しの遷移 | 定義あり。R/Semantics の E_ExternalApply/E_External/E_ExternalErr、Step.step、ExternalConnection の受信後の型付け | 全状態のpreservation/progress/step_soundはL20/L70 |
| σ | 定義あり。R/ScopeSyntax.PathEnv、Preparation.Required/Ready/InitialPrepared、AtPrepare.groundVal。固定σを保つ | 全σの所属・必要束縛の準備はL50 |
| 範囲付き値 | 定義・葉あり。R/Typing.V_Checked/V_CheckedRequest/V_CheckedAt、LegacyValues.embed_checked/embed_checkedRequest、HeldValues.checkedRequest_widen | 全δ/対象の一致と存在はL40/L50/L60 |
| 状態の判断の全構成子 | 定義あり。R/RuntimeSyntax.State/Frame/Cell、StateTyping.StateTyE/StateTy/ContTy/CellOk/StoreOk。K_Updateの注釈・捕捉・腕の観測を保持 | 型付き状態の全埋め込みと全保存はL20。LegacyStateInput自体が未定義であることをhandoffに明記 |
| 追加構成子に対するshift | 追随済み。R/TypingShift の HasTypeVQ/HasTypeCQ.shift_values、TypeShiftTyping の同shift_types。Vの304枝とS2の76構成子の照合を継承し、全宣言の公理依存を今回確認 | 型置換の全本体の証明をこの値/型の移動と同一視しない |
| subst・Covers・V_Sub/C_Sub | 追随済み。R/SubstTyping の HasTypeVQ/HasTypeCQ.subst/subst_under_none、EffectCover のCovers.bind/Sub.bind、Narrowingのnarrow、P付きLeQ/TelLe/TypeArgsLe。Ordinaryの追随を維持 | 全型置換の形成・観測、sig_scoped、G09の全導出はL20 |
| 埋め込み | detailがL10へ割り当てた定義・入力・四葉と限定等号が完了。R/Le.embedLe/embedCovers、LegacyKinds/LegacyRegularity/LegacyTables/LegacyValues、handoffの全署名 | 適格な旧導出と状態の全埋め込みは未実装でL20。単純embedStepは撤回済み。段の表の語を無条件の全導出の完成とは読まない |
| 既定build | 成功。lake build 774ジョブ・sorryなし、moreLeanArgsの-M 12288。新旧の既定importを外していない | Rust/Leanの全比較の成功ではない |
| 幅/Byte/Decimal/Top/Requestの新前提と07-04の変更をレビュー | 担当の照合と依頼を完了。R/Syntax.ConstOK、01-12の写し、07-04の区分と内外の表、RV-L10-request | RV-L10で満たすと確認済み。今回の所見の修正箇所の確認と最終受け入れは取りまとめ |

## 37義務の段別判定

分類は detail の **A12/B16/C6/D1/E2、計37行** を維持する。以下の「L10分完了」は当該定義・葉・継承照合・受渡し又は担当検査の完了を意味する。Cの行は契約の引渡しだけである。**L10だけで義務全体を閉じた行は0。** RV-L10のレビュー結果と今回の処置は記録し、取りまとめの修正確認と受け入れを各行の完了に混ぜない。

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

全段共通の plan の行で、detail の37行の外にあるものも分けて確認した。

| 義務 | 今回の担当分と残り |
|---|---|
| O027（RSS） | 未取得（計画上の非採取）。最後のworkに付けるRSSは取りまとめの担当であり、今回のbuildで代用せず、追加の計測buildも行わない |
| O118（本番コメントの工程ID） | **L10は一部：段全体の追加0、既存の除去は未実施**。RV-L10の差分確認を継承し、現行の既存行324行（ScopeStateにL40.3c/L00.08の2行）を再検索した。Refinement/Sharedと本段のInterval変更ファイルは0。既存の除去はL70の切替時のコメント処置へ申し送り、Rustの期待位置R50/R60、文書D10、最終同候補の照合V10に分ける案。担当確定は取りまとめ |

## foundation158件と旧読者

[s2/foundation-map.json](../s2/foundation-map.json) の全158行を読み、今回の全宣言の公理監査で対応先115件を再照合した。[foundation-check.json](foundation-check.json) にID・完全名・元入力のSHA-256を保存した。privateのnormTys_sortUnique一件はNormalizeのモジュールと末尾名で一意に照合した。これは宣言の存在と依存の再確認であり、完全署名の照合は群Sの signatures の証拠と区別する。

| 処分 | 件数 | 証拠と判定 |
|---|---:|---|
| L10開始前に既済 | 16 | 新しい対応先を維持 |
| 旧言明のまま移さず不要 | 43 | 削除済み/実装済みの件数へ算入しない |
| S前半で対応 | 31 | TypeSupport/FiniteSupport/FiniteCompare/FiniteFunctionView/Finite。うち支持の同種19件は最初17＋残2に分離 |
| S後半で対応 | 68 | TypeRegularity/TypeBounds/TypeRows/TypeVariables/TypeShiftFacts/EffectFacts |
| 合計 | 158 | 16+43+31+68。L10のfoundation未実装0、他段への未記名移管0 |

不要43件を読む12種類の旧言明の読者と、closedArgs_of/ClosedArgs.singleの二読者は [handoff](handoff.md) に全て載せた。別枠のTy.norm_legacy/Eff.norm_legacyの読者も記録した。L20 G04/G08/G03とL70の読者の追随は未実装であり、115件の存在確認を全読者の移行済みと読まない。

## 主な定理の前提と見直しの対象

| 項目 | 継承した判断と今回の照合 | 残り |
|---|---|---|
| data変性 | P付きLeQ/TelLe、Program.WellTyped.variance、構造的VarianceValid。非出現引数は不変。任意のfield_monoやmetadata完全性の公理を追加しない | L20/L40/L70、辞書制約と公開境界の収集はL70/R10bのLean外 |
| 網羅性 | ExhaustiveにB/Γ/Φを追加せずa.normを読む。ValueMeaning→InhabitsとD27の代表を継承 | 型付けの全帰納→ValueMeaning、全valueMeaning_subはG09。意味を独立の主定理の前提にしない |
| Q | ImplDecl.WellTypedは代入前のQTel ms.tel。method_bodyでQsigへ接続。detailの古いQTel t'よりplanの2026-11-01の判断を優先 | 呼出し側NoFailの新前提なし |
| Ordinary | TypeArgsKinded/Atのvalue kindとV_Raiseの結果/エラー型へ追加済み。最上位の芯だけで、入れ子を禁止しない。旧NotContから開いた型列にも供給 | 捕捉・複数引数・全本体・tappの形成・入れ子の像の全状態での接続はG03 |
| CoreAssumptions/TargetAgreement/σ/external | 束を分け、固定したσ・必要な束縛、依存する型付き入力、carrierの受信後検査と外部三条件を維持 | 旧20欄のうち19対応・sig_scopedのみG08に残る。実表の充足L50/L60、全合成L70 |
| 旧導出 | 全中間型の入力、kind表/長さ、constructor欄/arity、表現可能性と保持対象/要求/端点を明記。型付けの片方向だけ。旧δ/IOの全量化の同値は足さない | 全導出と状態はL20。旧Step一段可換性は撤回 |
| 主定理の結論 | progress/preservation/effect_soundness/noLamNames/対象健全性/step_soundの結論を弱めない。旧主定理の署名は今回不変 | 新体系の全状態と表層・交換の合成L70 |

以上は承認済みの変更の継承であり、今回新たに設計者の判断を必要とする前提変更を加えた表ではない。L00bで了承された見直し8件とguardの偽の事実を後続へ渡さない判断も取り消していない。J04（failedの所属の入力条件と接続）はL20/L40で具体化する残件である。

### 2026-11-01の判断との照合

planの既存の同日の17行と、今回先頭へ足された軽1/G10/捕捉の適合の判断1行を読み、既存17行を次の対応で継承した。今回の1行は上の所見の処置とtransferに対応する。古い行の「io_opは後段」より、後のL00b.15の必須移行の判断を優先する。

| 判断の根拠 | 継承した内容・配置 | 今回の判定 |
|---|---|---|
| RV-L10.s2 | TypeArgsKinded/At・V_RaiseのOrdinary、TypeArgumentRegularityの供給 | 最上位だけの制限を維持 |
| RV-L10.w | ProgramTyping.ImplDecl.WellTyped/method_bodyの代入前Q | detailの旧式へ戻していない |
| L10詳細の確定 | 59単位・各段の更新済み見込み・O005/O033/O079の配分 | 転記表へ継承、plan未編集 |
| RV-L10-planの再レビュー | 非出現引数は不変、辞書制約/公開境界の収集はLean外 | unusedなし、07-04へ明記 |
| RV-L10-plan重1/重2 | P付き変性と網羅性の定義を先に固定、Byte/七幅の述語比較を維持 | V/Xの定義を再使用 |
| L00b末の再提示 | 状態代表は閉じた4・一部2、8件とguardの判断を了承済み | 一部の一般化を全保存へ繰り上げない |
| RV-L00b.15再中1 | release_exists/sat_unconstrained/admits_satの三欄を移行 | CoreAssumptionsへ既済19、sig_scopedだけG08 |
| RV-L00b.15中1 | io_opのShapeOk、PathBasesShapeの効果表への所属 | 新CoreAssumptionsとBuiltinEffectsの代表を維持 |
| RV-L00b.14e中1 | state_effectとProgram.EffectsOk、解放を伴う破棄の代表 | HandlerEffects/HandlerPreservationを維持 |
| RV-L00b.14d中1 | K_UpdateのAnnotation、任意セルへの書戻し | StateTyping/LazyPreservationを維持、全closeVal型保存はL20 |
| RV-L00b.14c中1 | ref_get/ref_setとStoreShapeのvalue kind、ReferencePrimitives | ConstraintAssumptions/ReferencePreservationを維持、実表はL60 |
| RV-L00b.14b-pathsの所見の処置 | matchのリテラル/範囲/非空/構成子/Orの事実 | MatchFactsを維持、Rustの同じ収集はO138後段 |
| L00b.14b-pathsの観測添字 | HasTypeArmsQのOption TermをC_Matchと共有 | 七判断の埋め込みの入口はnone、全接続はL20 |
| RV-L00b.14bの経路条件 | C_If/guard/match・短絡、K_Guardの変更 | PathConditions/MatchPathsを維持、一般合同はL30/L40 |
| RV-L00b.14a | 依存βの代表は開始の逆転を含まない同時構成 | DependentBetaの限定を維持 |
| RV-L00b.13 | groundTyのrefined分岐、AtPrepared/reqTarget/checkAtの三補題 | AtPrepareを維持、旧モデルを変更しない |
| RV-L00b.11 | 組み込み入力のTy.normTys/行norm、CellOk.valのa.norm | Semantics/Step/StateTypingを維持、型付き量化の意味を取り消さない |

## 検査と公理依存

再実行はリポジトリの根から `python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/f/verify.py build handoff axioms`。各コマンド・終了・外側の秒数・生出力の大きさとSHA-256はJSONにある。既定buildと単一ファイルはともに-M 12288である。

| 実体・formalでのコマンド | 結果 | 外側の時間と記録 |
|---|---|---|
| 既定全Lean・既定実行ファイル `lake build` | 終了0、774ジョブ、sorryなし | 4.109秒。[build-result.json](build-result.json)・[生出力](build-output.txt) |
| 受渡しの型・39宣言の署名 `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/f/handoff.lean` | 終了0 | 0.700秒。[handoff-result.json](handoff-result.json)・[全署名](handoff-output.txt) |
| 全対象の#print axioms `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/axioms.lean` | 終了0、197モジュール＋明示20件 | 17.862秒。[axioms-result.json](axioms-result.json)・分割した全名と依存 axioms-names-*.json |
| gitを使わない担当範囲・改名同一性・textブロックの検査 `python3 …/l10/f/check-scope.py`（根） | 終了0 | [scope-check.json](scope-check.json)。改名を逆に戻すと二つのLeanファイルが開始時のSHA-256と一致 |

公理依存の対象はRefinement全190モジュール、Shared三モジュール、Intervalの近似・実解析・予算の三モジュール、Surface.ScopeState一モジュールで計197。Exchangeだけはimportと空の名前空間のため宣言数0を確認し、それ以外の空集合を拒む。旧五主定理・旧三モデルと、値移動/型移動/値置換/Noneの下の置換/narrowingのV/C十定理、旧区間の正常値/警告二定理を明示した。定義・private・生成宣言も含む **20,067印字、20,057固有名** で、全依存の和集合は **propext・Quot.sound・Classical.choiceのみ**。sorryAx・独自公理・許可外依存は0件である。標準公理の依存だけで定義・言明・仮定の妥当性が確認できるとはしない。

初回F群のhandoffは未知の表示オプションpp.widthで終了1となり、オプションを削って成功した。初回の公理監査は空のExchangeを拒んで途中終了した。その時の最終のLean実行は終了0だが、集計器が完全名内のアポストロフィ3件を落として件数確認で失敗した。集計器を直して**同じ生出力**を再集計し、20,065件の一致を確認した。対象を削った修正ではない。初回・集計前・当時の最終の結果JSONを残した。今回の再開は修正済みの集計器で20,067件の一致を確認している。

Leanは4.34.1（arm64-apple-darwin24.6.0、commit 5045d0056413266e57c625dcd7c365b10e377c52）。buildは増分であり、RSSは未取得（計画上の非採取）。取りまとめの最終work/RSSとは別の既定buildである。work・Rust全lib・Rust/Lean全比較は依頼どおり未実行。01-specのtextブロック24件は開始時と同一であり、spec_examplesの追加実行の条件は発生していない。構文・生成Skillを変更していない。大きな生の記録は [large-records.md](large-records.md) に大きさとSHA-256だけを記録した。

### 今回の追加の検査と失敗の扱い

変更したLegacyInput.leanの局所検査は `lake env lean -M 12288 Benitoite/Release/Refinement/LegacyInput.lean` で終了0。既定buildはその後4.109秒で成功した。rv-f-t1〜t3はそれぞれ0.618/0.646/0.625秒で終了0、原本は不変。新しいboundary.leanは23宣言を監査し、0.747秒で終了0、sorryなし、依存は許可三公理のみだった。

境界は同じbadOpで先頭の不一致を拒み、badIndexで添字を拒み、正しい操作のLegacyDeclarationsInputから実際の新しい先頭の一致を取り出す。実装は実際の宣言入力から新dictTysの各要素のHasKindを取り出し、クラスなしの場合を拒む。型付けの結論を前提にした正例ではない。境界の初稿はshiftV_zeroの展開と型変数の0<1の証明が不足して失敗した。証明を直し、同じ本番の条件で成功した。初回の失敗出力を残した。

参考に旧群Kのboundary.lean全体も実行したが、193/309/464行でS2が加えたOrdinaryの欄がないため終了1となった。この入力は変更していない。今回の辞書の連言の変更で失敗した箇所はなく、古い入力のエラー回復が印字したsorryAxを成功の証拠にしない。現在のkind/Ordinaryの契約はS2の境界の証拠と、今回の全本番の公理依存で照合し、今回必要な宣言入力は新しいboundaryで受理/拒否を閉じた。旧群Kの入力の再利用時の追随は取りまとめへ申し送る。

初回F群の結果と生出力の控えはreview-beforeに残した。今回のbuild/署名/境界/公理監査のJSONと生出力を最終結果とする。公理監査は20,067印字・20,057固有名、許可外0。増加した二件はLegacyDeclarationsInputの二補題で、主な十言明・旧五主定理・旧三モデルは不変である。大きな生出力は引き続き一時領域へ置く。workとRSSは実行していない。

## 実績と見込みの比較

[effort-ledger.md](../../effort-ledger.md) の既存行を読み、編集していない。群V〜Aの初回7行は45+45+12+38+29+29+18=216分（約3時間36分）、修正8行は26+11+9+16+5+33+6+5=111分（約1時間51分）、計15行は **約327分＝5時間27分**。レビュー8行は15+20+14+14+15+15+3+6=102分（約1時間42分）。計画作成3行（15+63+60分）とそのレビュー2行（13+9分）は別枠であり、L10本体29〜61時間へ混ぜない。今回のF群と段末の独立レビューはこの既存15行に含まれない。

これらは通常記録の丸めた外側の時間であり、能動時間と検査・道具の待ちを分離していない。29〜61時間はL10本体の能動時間の見込みなので、5時間27分との差を能動時間の節約として確定しない。TODO-294の0.5〜1時間は相乗り294/315/317枠であり、本体へ二重計上しない。今回も.55/.56/.58/.59と.57を別の算入先として取りまとめへ渡すが、記録から作業別の能動時間を分離できない。

S前半の同種19件は最初17件を.33〜.36、残2件を.37で閉じた。A_17とc_gは待ちから分離できず未取得であり、当時N_g=2の見込み0.5〜1時間を維持した。その後N_g=0となったので同種の残りの見込みは0。これは本番追随の更新材料だが、L20/G09など別種の全帰納へ外挿する根拠ではない。Pの機械的な追随304枝、短い値の葉、代表の成功を新しい全相互証明の単価にしない。

| 段・配分 | 継承する能動時間の見込み | 更新の材料と判断 |
|---|---:|---|
| L20 | 現行34〜80→**47〜109時間の提案** | 全埋め込みG10の配分13〜29時間の欠けを訂正。捕捉の全正則性はG04の最初の単位群で確認。古いG表の行と既存の移管5〜9時間の照合差を明示し、据置きの提案を撤回 |
| L40 | 15〜35時間 | H02の変性の定義/単調性はL10で完了し、利用側の葉1〜3時間を残す。H04のfailed条件と数値の値一致は実証未完。数値は据置き |
| L70 | 24〜62時間 | Program.WellFormedの定義はL10で完了。収集の完全性・支持不変量・深い符号の費用・全交換は未計測。数値は据置き |
| G09（L20の内数） | 4〜8時間 | 意味を主定理の前提にせず全型付けから導く証明が残る。代表の比を掛けない |
| G07/G08（L20の内数） | 5〜12／1〜3時間 | fnViewの定義と三WellTypedを再作成しない。全形成・呼出し、PrimSig.Scoped/sig_scopedと全宣言の充足を残す |

初回F群の外側の時間は [timing.json](timing.json) を正とし、最初の時計確認12:16:52 UTCより前の読込みを含まない。今回の再開は [review-timing.json](review-timing.json) に開始/終了と外側の時間を記録した。能動時間と待ちは未分離で、今回の3時間の上限には達していない。更新の比を一律に掛ける材料はない。L40/L70の見込みは維持するが、L20は全埋め込みの配分漏れを積み上げ直し、上端80時間を越える提案を取りまとめへ渡す。根拠のある具体的な差分は [transfer.md](transfer.md) の配分表へ集めた。

## 残る検査・レビュー・受け入れ

| 残りの手順 | 担当と実体 | 見込み |
|---|---|---|
| 修正箇所の確認 | RV-L10と末尾の追記に従い、全体の再レビューは置かず取りまとめが11所見の修正箇所を確認 | 不明 |
| 最後のworkとRSS | 取りまとめ。B_WORKに対する変更分類・既定全Leanと必要な文書検査を行い、同じ実行にRSSを付ける。追加の計測buildを作らない | 不明（直近の群のworkは約100秒だが、最終の分類と修正次第） |
| 転記・受け入れ・取り込み | 取りまとめと設計者。37行の段別判定、見込み、残る全導出/実表/主定理/表層/全比較を確認し、L20の基準を固定 | 不明 |


## 段末の work

取りまとめが実行した。基準は `f4952052e9474f40ac9a257d260065cf8103cfaf`、コマンドは `scripts/check.sh --level work --base <基準>`、終了状態は 0、外側の時間は 101.53 秒、計測器が報告した最大常駐量は 1457127424 バイトである。実行の前に Refinement の生成物を消した。計測は sandbox の外の `/usr/bin/time -l` で、対象の機械は手元の macOS である。
