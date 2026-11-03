# 群 H・I の実装結果

2026-11-03。指定ブランチ `m014/l30.h`、B_WORK `82a7f626e38b6e861f896ec5033e08e6acdfa435`。ブランチの切替・作成・コミット、plan・detail・README・レビュー記録・Rust処理系・旧Releaseの編集は行っていない。J30-2、案(ii) checkedAt、U03の決定を引き継いだ。担当の自己点検であり、独立レビューと設計者の受け入れは取りまとめの担当である。

## 完了条件の照合

| 単位 | 判定と本番の証拠 |
|---|---|
| L30.43 | 完了。群AのcarrierFactsを再利用。七整数型と Byte の16端点とDecimal一項を型付き定数、文脈、注釈へ接続 |
| L30.44 | 完了。carrierFacts_norm、assume_norm/refined/of_wf、二列の含意の同値と正規形の橋 |
| L30.45 | 完了。自己0を保つshift、lookupとopenの所属、extend/extendNone、文脈の正規化の事実の等号 |
| L30.46 | 完了。carrierFacts_rawBind/bindとassumeWithCarrier_bind、範囲・型移動の不変性、四名前空間のTransport.assumptions |
| L30.47 | 完了。Ty.LeQ.assumeが本番の部分型の帰納を受け持つ。四族22規則の構成子は維持 |
| L30.48 | 完了。最初の16読者のうち14読者の補助を準備し、2読者の保持理由を照合。旧assume/facts/ValueMeaningのまま既定ビルド成功 |
| L30.49 | 完了。ConstOK.representedから定数の事実を供給。並置の型付き事実の証明を本来のTypedFactsへ統合し、HasTypeVQ.carrierFactsを公開 |
| L30.50 | 完了。型付きの閉じた観測から自己モデルの型域を供給するcarrierFacts_meaning_closed。定数の意味の新入力と構成子の第三条件の供給元を確定 |
| L30.51 | 完了。Ty.assume/Ctx.factsとValueMeaningを同時に切替。直接・間接の捕捉、定義展開、全33場合、十移送、旧読者を含む既定ビルド成功 |
| L30.52 | 完了。ValueMeaning.assumeで型域と明示述語を供給。assumptions_meaning/valueMeaning_subの公開署名と辞書式帰納を保持。並置との重複した証明を統合 |
| L30.53 | 完了。Month・空篩・非空List・unknown、bindParams・match_extend・paths_evaluate、close_value_typedの既存読者を維持。型域の具体例も既定ビルドへ追加 |
| L30.54 | 完了。直接12構成、個別に追った間接構成・供給25宣言、元の全在庫とValueMeaning9ファイルを照合。捕捉への追加前提0、在庫の外で壊れた既存読者0 |

## 並置と切替

L30.43〜.50では旧Ty.assume/Ctx.facts/ValueMeaningを保持し、並置補助を置いた。並置の既定ビルドは終了0である。L30.51で、本来のTy.assumeにcarrierFactsを組み込み、Ctx.factsとCaptureOkの事実の欄へ反映した。ValueMeaning.mkは芯の形・明示述語の真・型域の事実の真の三条件になった。ValueShapeMeaningは23構成子、型付き意味の相互証明は33場合のままである。

Ty.assumeWithCarrier・Ctx.factsWithCarrierは本来の入口の略記であり、別の型付け判断を提供しない。範囲の移動・型の移動・bind・部分型・文脈の橋は、旧入口と並置入口が一つの証明を読む。型変数の置換像で増える型域は包含で扱い、等号で失わない。NumericRepresentedとConstOK.representedは同じ完全名・内容でSyntax直後のNumericRepresentedへ移し、TypedFactsからExternalObservationへの逆向きのimportを避けた。群Aの定数の意味の補題は再実装していない。

現在の新規・移動・変更の完全署名とValueMeaning.mkは[signatures.md](signatures.md)。内部の署名の変更は、assume_eq_predicatesからassume_eq_carrier_append、assume_of_wfの結論へのcarrierFactsの追加、entails_assume_iff_predicatesから二列のentails_assume_iff、const_meaningへのNumericRepresentedの追加、例のcontext_facts二件の事実列である。主な十移送、typed_value_meaning_closed、valueMeaning_sub、close_value_typed、Entails.bindの公開の量化と結論は変えていない。四つの十移送のファイル、Typing、Basicは開始時の控えとバイト単位で同じ。旧Releaseの110ソースも同じである（[contracts.json](contracts.json)）。型付けの規則の構成子の形を変えず、J30-2が採った判断と状態不変条件の定義だけを強めた。CoreAssumptionsへの欄追加、新しい公理、独立の信頼条件、精密な外部状態はない。

## 具体の受理と拒否

[CarrierFactsExamples](../../../../formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean)は既定importに含む。integer8_upper_subがInteger8からInteger8{self <= 127}の部分型を構成し、typed_integer8_upperが実際の変数の型付けへ適用する。closed_integer8_upperは同じ具体のP・Bで値127へ篩を付け、closed_integer8_carrierは閉じた型付き値から自己モデルの型域を得る。PのVarianceValidは再開1のvalidで証明し、closed_integer8_meaningが主定理の入口を読む、Bは既存の具体の組込み表であり、値の型付けに矛盾する外部仮定を受けない。

explicit_width_upper_unprovableは、変更前と同じ明示した篩だけの事実列ではx=1000のモデルが残るため上限127を導けないことを示す。width_128_unprovableは新しい文脈でも128 <= xを導けないことをx=127で示す。raw_1000_not_meaningは、新しい意味では生のInteger8(1000)を認めないことを示す。captured_decimalは同じP・Bの実定数Decimal(1,0)をCaptureOk.extendへ渡し、Decimalの型域を供給する。既存のLogicKernelExamples.captured_integer8は二つの実Integer8の四事実を新しいCaptureOkから供給する。

作成時の関門は、型付け・部分型・意味・捕捉の本来の入口を境界とした。型域をassumeから落とす退行は新しい受理例が、型域を広げる退行は意味と含意の拒否例が捕まえる。既存の例は並置の四事実までで、実際のV_Subによる受理と生の定数の意味の拒否を検査していなかった。テスト用の公開フラグ・差し込み口は追加しない。Rustのテストは追加・削除していない。

## 読者の件数と処分

[reader-dispositions.md](reader-dispositions.md)に直接12構成、間接25供給鎖、16読者、ValueMeaning9ファイル、定義展開16ファイルと元の全在庫を一行ずつ置いた。直接構成の12本文は保持し、共通の型付き事実と正規化・移送を直して新factsへ追随した。間接構成にも前提を加えていない。最初の16読者は14補助を変更し、ContextMapの2読者は一般の契約を保持した。変更不要の2読者を移植実績に加算しない。

初回の字句検索は、assumeが32ファイル187行、CaptureOkが52ファイル224行・一致した直前宣言145件、明示の定義展開が18ファイル29行、facts|assumeが62ファイル677行、ValueMeaningが10ファイルである。増分には群AのLogicKernelExamplesと今回の新しい適用例を含む。これを意味上の読者数として報告しない。生一覧は<tmp>へ置き、大きさとSHA-256は[initial-inventory-summary.json](initial-inventory-summary.json)に保存した。[records.py](records.py)が同じ検索を再生成する。

定義の簡約で実際に壊れた既存読者はOpenSubstitutionのcontext_facts/transport、SubstTypingObstructionのcontext_facts/transport/source_le等であり、全件を修正した。前者の加算の像には既存等式から値7へのEqProof.substitute_entailsを使い、型域を独立の仮定にしない。これらは広い元のfacts|assumeの在庫には含まれていたため、その外の新しい既存読者の発見は0。狭い展開検索だけでは足りなかったことを処分表へ記した。

## 初回の検査（再開1は末尾）

途中の局所検査はlake env lean -M 12288。既定lakefileも-M12288であり、上限を緩めていない。正確なコマンド・終了・外側の時間・生出力の大きさとSHA-256は[verification.json](verification.json)と[initial-audit-summary.json](initial-audit-summary.json)に置く。生出力と公理監査の対象名一覧は<tmp>、対象の再生成は[audit.lean](audit.lean)・[audit.py](audit.py)による。

| 検査 | 終了・外側の時間 | 内容 |
|---|---|---|
| 並置の既定lake build | 0、1.141秒 | 旧assume/factsと二条件のValueMeaningを保持した全既定ビルド |
| 切替時の既定lake build | 0、個別計時未採取 | 全935ジョブ。切替全体の観測枠は427.304秒 |
| 整理後の既定lake build | 0、130.261秒 | 全934ジョブ・既定8 targets。今回の空の中継モジュールをTypedFactsへ統合したため一つ減った。開始時からのimportの除外は0 |
| 公理監査 | 0、32.776秒 | 全Refinement350モジュールと旧主定理・主要十移送の25,520宣言。private・生成宣言を含む |
| 最後のwork | 0、7.962秒 | `scripts/check.sh --level work --base 82a7f626e38b6e861f896ec5033e08e6acdfa435`。--onlyなしで一度実行。仕様対応の自己検査・集計、仕様例7件成功（失敗・無視0）、既定Leanとsorry拒否。同じ指定のdry-runも0 |

公理の依存は、なし9,545、propextのみ6,461、許可三公理8,441、propextとQuot.soundが1,061、Classical.choiceのみ1、Classical.choiceとpropextが2、Quot.soundのみ9である。sorryAx・独自公理・未承認公理は0。生の公理出力は5,001,554バイト、SHA-256 `caff0d7a99daceac52983468e697baed01af7c762cc6b9c21a5c05dd841b85a3`、対象一覧は1,788,346バイト、SHA-256 `cf71963142d66ac1e8e3572847f5348b1c800b4beaf593c41effb534fcc51576`。監査の初回は全モジュールと明示した十移送の重複で台本が終了1となった。対象の和集合を重複除去して再実行し、全件を検査した。初回の失敗も[audit-first-summary.json](audit-first-summary.json)へ残した。

新しい証明の警告は0。既存のContext/Facts・CoverageRefinement・RangeSubst等の警告は保持し、警告を隠す設定は追加しない。正式RSSは未取得（計画上の非採取）。Rust/Leanの全比較は今回の対象外であり、実施済みとしない。

## 外側の時間と見込み

観測開始はUnix秒1793668101.205684であり、その前の資料読取りの冒頭は未採取。[times.json](times.json)に各単位の観測枠を置いた。.43〜.50の共通枠は514.560秒、.51の単独の観測枠は427.304秒である。.52〜.54の意味の整理・具体例・在庫・監査は共通枠で記録する。共通枠を単位ごとに足して総時間にしない。能動時間とビルド・調査待ちの分離はできず、一件当たりの能動時間を確定しない。同種群だけへの外挿にも使用せず、見込み10時間45分〜20時間10分を保つ。4時間と上限40時間20分には達していない。

単位ごとの独立した所要を取得できなかった点は記録上のずれである。後からファイルの更新時刻を使って能動時間を作っていない。

## 義務の一行ずつの判定

判定は今回のH・I分に限る。L30全体、Rust、独立レビュー、設計者の受け入れを閉じた行は0。

| 義務 | 今回の判定と証拠 | 残る担当 |
|---|---|---|
| O015 | 今回の担当単位なし。型域の供給を16sortの全接続と数えない | J/K、L40/L50 |
| O017 | 今回の担当単位なし。U03を引継ぎ、独立の上限を追加しない | L、R20/R50/R60 |
| O019 | 今回の担当単位なし。既存の証明書とEntails.bindを維持 | K、R20/R50 |
| O020 | 今回の担当単位なし。discard・Orの規則を変更しない | L、R20/R70 |
| O021 | 担当分完了。16読者の14補助と2保持、観測枠と分離不能を記録 | L/N、取りまとめの見込み転記 |
| O022 | 担当分完了。型域の有限列と型付き値からの構文・意味の供給 | J/K、L40/L50/L60 |
| O023 | 今回の担当単位なし。raw核の再生を重ねない | M、R50 |
| O026 | 今回の担当単位なし。任意整数モデルを実値と扱わない | J/L、R20/R60 |
| O034 | 今回の担当単位なし。型域を正常δの全契約と数えない | J/K、L40/L50/L60 |
| O043 | 今回の担当単位なし。Ty.LeQの規則の形と全移送を保持 | K、L40/L70 |
| O050 | 今回の担当単位なし。OpenSubstitutionは既存の安全な限定書換えを使用 | J、L40 |
| O054 | 今回の担当単位なし。Booleanの規則を変更しない | K、L40/L70/R10b |
| O071 | 今回の担当単位なし。探索の完全性・意味の独立仮定を追加しない | L、R20/D10 |
| O072 | 今回の担当単位なし。既存の等号と鍵の境界を保持 | J/K、R10b/R20 |
| O127 | 今回の変更なし。既存のHasTypeVQ.assumeが明示したcharactersInを保持することを既定ビルドで確認。新しい証拠による完了とは数えない | J/K、L40/R段/V10 |
| O130 | 今回の担当単位なし。String二長の供給を型域へ混ぜない | J/K、L40/R段/V10 |
| O131 | 今回の担当単位なし。既存の非空List/unknownの意味と網羅性を保持 | J/K、L40/R段/V10 |
| O132 | 今回の担当単位なし。Byteの型域とBytes長を区別 | J/K、L40/R段/V10 |
| O133 | 今回の担当単位なし。Map鍵の一般の等値は未担当 | J/K、L40/R段/V10 |
| O134 | 今回の担当単位なし。Set鍵の一般の等値は未担当 | J/K、L40/R段/V10 |
| O135 | 今回の担当単位なし。欄とdata変性の契約を保持 | J/K、L40/R40/R50/V10 |
| O136 | 今回の担当単位なし。十移送とcloseの公開署名の不変を確認 | K、L40/L70/R段/V10 |
| O137 | 担当分完了。七整数型と Byte・Decimalの型域を型付き事実と意味へ接続。Integer8の新受理と対照 | J/Kの正常算術、L40/R段/V10 |
| O144 | 今回の独立担当単位なし。型域を既存の有限論理へ供給し新しい理論を追加しない | J/K/M、L40/L50/R段/V10 |
| O158 | 今回の担当単位なし。独立unknownを追加しない | L、R20/R70/V10 |
| O161 | 今回の担当単位なし。保存幅128を型域の数学の補題へ固定しない | L、R20/R60/V10 |
| O167 | 今回の担当単位なし。新しい受理と不正な型域の意味の拒否はO137へ記録 | K/L、L40/L70/R段/V10 |
| O046 | 今回の担当単位なし。捕捉したif/guard/matchの葉を新factsで維持 | J/K、L40/L70 |
| O079 | 今回の担当単位なし。length証明書の合成は未担当 | K、L70/R10b/R50 |
| O138 | 今回の担当単位なし。Booleanの有限規則の意味を変更しない | K、L40/L70/R段/V10 |
| O143 | 今回の担当単位なし。正の長さの静的な合成を完了済みとしない | K、L40/L70/R段/V10 |
| O016 | 担当分完了。全350モジュール25,520宣言の公理依存、許可三公理のみ | 取りまとめの独立レビュー、N/L70 |
| O084 | 担当記録完了。並置・切替・型域の定義変更と量化の不変、記録上の限界を区別 | 独立レビューと受け入れ、M/N |
| O027 | 担当記録完了。-M12288、終了と外側の時間、正式RSSの非採取を記録 | Nの最後のworkで取りまとめが正式採取 |
| O118 | 担当分完了。01-12・07-04を実物の定義・前提と同時更新。絶対パス・工程ID・消える領域への参照なし | N、L70/R50/R60/D10/V10 |

## 計画との差と取りまとめへの申し送り

- 内部の補題の署名の変更は上記とsignaturesへ記録した。主な十移送の量化と結論、型付け規則の構成子、Entails.bindは不変。停止条件に当たる新しい前提・公理・提供範囲の削減・書ける形の制限は不要だった。
- 依頼の「lake buildは既定のまま」に反し、初期に一度だけ `lake build Benitoite.Release.Refinement.Transport` を実行した（終了1、NormalizationLogicの証明不足）。以後は既定のlake buildだけを使った。対象を絞った実行を完了の証拠にしない。
- 初期の編集台本は作業ディレクトリを誤って失敗し、変更は起きなかった。並置のビルドの途中にNumericRepresentedの配置と新しい例のimportを変えたため、古い成果物との同名宣言の衝突と例の成果物の不足が起きた。入力を固定した既定ビルドでやり直し、並置と切替の成功を別に確認した。
- 時間は共通の観測枠を持つ。個別の能動時間へ読み替えず、旧見込みを保つ。計測だけの作業や試作の作り直しは加えていない。
- 群Kは型域を含むassumptionsを使える。群FからのsameObservationの16分岐と入れ子の鍵の申し送りは変更せず、Kの.66に残す。群Jの実measure/算術/鍵、L40の実標準表とδ、L70の主定理の合成、Rustとの比較は今回の完了に含めない。

新しい方式・主定理・公理について取りまとめに判断を求める点はない。依頼の指定違反と時間の記録の限界を含め、担当分の独立レビューと受け入れへ渡す。取り込み・planへの転記・docs/todoの操作は取りまとめの担当である。

## 初回の受渡し状態

指定のworkは一度だけ実行し終了0となった。既定ビルド・監査・workの後に、本番Lean・写し・設定は変更していない。以後の変更は検査結果・入力ハッシュ・在庫・署名・時間の記録だけである。初回の入力34ファイルと全684形式化ソースの一覧のハッシュをinitial-inputs.jsonへ置き、inputs.pyで再生成できる。各記録は100 KB以下。

公理監査の全対象名一覧と各出力は台本で再生成できる。`audit.py --tmp <tmp>` を改造内の台本として実行し、単独Leanにも-M12288を指定する。`records.py --baseline <B_WORKのソースの控え> --tmp <tmp>` が署名・契約・字句の在庫を再生成する。基準の控えを現在の作業木から作り直さず、指定B_WORKのソースを使う。inputs.pyは既定の全ソースを読み、.lakeを除く。

H・Iの担当の義務は完了した。取りまとめの独立レビューと受け入れ、L30全体の閉鎖は未実施である。

## 再開1: RV-L30.h の軽1〜3と情報1・2の処置

2026-11-03。RV-L30.hは可（重0・中0・軽3、情報5）で、名前と記録の整理で済む軽の処置には再レビュー不要としている。以下は担当の処置と検査であり、取りまとめによる処置の確認・受け入れは別である。

| 所見 | 処置 |
|---|---|
| 軽1 | 並置名と本来の名が同じ言明を持つ16組を統合した。Ty.assume_*、Ctx.mem_facts*、Ctx.facts_map_norm、Ctx.NormEq.facts、Ty.LeQ.assume、Transport.assumptionsに本体を置き、別名を削除した。Transport.assumptionsだけが読むassumptionsWithCarrier_bindは本体へ統合し、読者を移したassumptionsWithCarrierも削除した |
| 軽1・名前と言明 | 固有のTy.entails_assumeWithCarrier_iffをTy.entails_assume_iff、Ty.carrierFacts_subset_assumeWithCarrierをTy.carrierFacts_subset_assumeへ改名し、言明も本来のassumeを読む形に統一した。Ty.LeQ.assumeWithCarrierはTy.LeQ.assumeへ統合し、旧名の別名は残さない。削除と行き先の全件はresume1-aliases.json、読者の処分はreader-dispositions.md |
| 軽1・略記の保持 | Ty.assumeWithCarrierとCtx.factsWithCarrierの略記自体は、既存のLogicKernelExamplesと01-12・07-04が読むため保持した。並置補題のWithCarrier名とassumptionsWithCarrierは本番の宣言・読者から除いた。既定importを除外せず、公開した型付けの入口・規則・主な言明は変えない |
| 軽2 | CarrierFactsExamplesの同じ具体のPについてprivateなvalidがVarianceValidを証明し、closed_integer8_meaningが同じP・Bのclosed_integer8_upperへtyped_value_meaning_closedを適用する。no_typed_1000は同じP・Bの生のInteger8(1000)の閉じた型付けを、主定理の入口と既存のraw_1000_not_meaningの合成で拒否する。元の定数・Decimal捕捉のP・Bは変更しない |
| 軽3・用語 | 記録の「八整数型」を「七整数型と Byte」へ訂正した。型域の端点・型数・本番の定義は変更しない |
| 軽3・O127 | 「今回の変更なし。既存のHasTypeVQ.assumeが明示したcharactersInを保持することを既定ビルドで確認」と改め、新しい証拠のない保持を担当分完了と数えない。O127全体の完了の扱いは取りまとめに委ねる |

後の群・L40への申し送り（情報1）: valueMeaning_subのfacts前提は字面を保つが、開いたΓでは型域の真も要求する。現在の本番の呼び手はΓ=[]であり、後の群とL40で開いた文脈を使うときは、型域を含む同じΓ.factsとΦの真を供給する。

後の群・L40への申し送り（情報2）: Transport.factsは型域の移送も要求する。型付きの値の像なら既存の供給を使えるが、算術の項を像にする移送では上下限を別に導く必要がある。OpenSubstitutionは経路の等式var 2 + 1 = 7から限定書換えで導いており、元の上下限だけから算術の像の型域を仮定しない。

作成時の関門は、同じ具体の宣言表の適格性と主定理の入口を境界にした。新しい正例はVarianceValidと閉じた型付けから実際の意味を得て、拒否例は意味の拒否が閉じた型付けの拒否にもなることを確かめる。独立の意味の仮定・新しい公理・テスト用の差し込み口は加えていない。既存のrawの対照と型域を供給する補題の読者は保持した。

主な十移送の四ファイル、Typing、Basicは再開の前後でバイト単位の一致を確認した。規則の形・量化と結論・Entails.bind・CaptureOkの前提は不変。定義の意味も変更しておらず、01-12・07-04の写しの二つの略記と三条件の記述は引き続き本番と一致するため、写しを編集していない。ブランチの切替・作成・コミット、plan・detail・README・レビュー・Rust処理系・旧Releaseの編集は0。

### 再開1の検査と外側の時間

| 検査 | 終了・外側の時間 | 内容 |
|---|---|---|
| 関係する単独Lean | 11件すべて0 | 各ファイルをlake env lean -M 12288で検査。並行した実行の時間を合算しない。新しい証明の警告0 |
| 既定lake build | 0、129.914秒 | 既定8 targets・全934ジョブ。対象の指定・importの除外・上限の変更なし。この再開で一度実行 |
| 公理監査 | 0、33.108秒 | audit.pyから既定Refinement350モジュールと旧主定理・十移送の25,506宣言。private・生成宣言を含む |
| 指定のdry-run | 0、0.118秒 | workと同じ水準・基準で選択を確認 |
| 作業末work | 0、4.213秒 | scripts/check.sh --level work --base 82a7f626e38b6e861f896ec5033e08e6acdfa435を--onlyなしで、この再開の末に一度実行。仕様対応の自己検査・集計、仕様例7件成功（失敗・無視0）、既定Leanとsorry拒否 |

公理の依存は、なし9,546、propextのみ6,455、許可三公理8,433、propextとQuot.soundが1,060、Classical.choiceのみ1、Classical.choiceとpropextが2、Quot.soundのみ9である。sorryAx・独自公理・未承認依存は0。対象の件数は初回の25,520から25,506になった。名前と重複の整理による減少であり、監査するモジュールを減らしていない。新しい適用例も同じ監査に含めた。

| 生の記録（保存先は<tmp>） | バイト | SHA-256 |
|---|---:|---|
| lake-build.log | 63502 | `c813bbe3e1811f44d8f4a55573c6d06c7fb5b77e24d844697d285e220c450edc` |
| axioms.log | 4999156 | `20085b1ee47fa9c67f38955f65f3f4954bb6384558a6ba07c8107261780eb419` |
| audit-targets.txt | 1787585 | `a2d7b98991cd48f912dd6cd5809ab70ebc00419fa3774f78705aa17f80081261` |
| work-dry-run.log | 759 | `d6408cb89a5331813d0910dd89420b00c57e00d5d9145b8b709dac34dddaaf6e` |
| work.log | 5757 | `696d26c6bd86146e63cd2a4aebe8a6fe751ddbf9ad386640db5b4411c5cf7c9e` |

単独Leanの-Mは12288、既定ビルドはlakefileの同じ上限である。正式RSSは未取得（計画上の非採取）。この再開の局所Lean・既定ビルド・監査・workの失敗は0。既存のRangeSubst等の警告は保持し、警告を隠す設定は加えていない。

開始の資料読取りの冒頭は未採取。控えを作ったUnix秒1793671041.637746から、完了記録の1793671587.869333までの外側の時間は546.232秒（約9.1分）である。能動時間と待ちを分離できず、見込みへの外挿に使わない。正確な区間と検査はresume1-summary.jsonとtimes.jsonに保存した。

現在の署名44件、字句の在庫、入力35ファイルと全684形式化ソースの一覧のハッシュを再生成した。古い監査・入力・署名・在庫・契約・検査の要約はinitial-*へ保持し、同名の現在の監査・入力・署名・在庫は再開1後の状態を表す。対象一覧と生出力はaudit.lean・audit.pyで、署名・契約・字句在庫はrecords.pyで再生成できる。各記録は100 KB以下。

再開の前後のLeanの差分は追加78行・削除119行、差し引き-41行。Rustのテストの追加・削除は0。主な十移送・型付け規則・Entails.bind・既定importは不変であり、検査の後に本番Lean・写し・設定を変更していない。

軽1〜3と情報1・2の担当の処置は完了した。レビューはこの範囲の整理に再レビュー不要としている。新しい設計判断を要する点はなく、取りまとめによる処置の確認と受け入れへ渡す。O127を新しい証明で完了したとは扱わない。

## 作業末の work

取りまとめが、RV-L30.h（可。所見は軽だけで、レビューは再レビューを要しないとした）の処置の後に、Refinement の生成物を消してから一度実行した。十移送の4ファイル・Typing.lean・Basic.lean が基準から変わっていないことも、取りまとめが差分で確かめた。

| コマンド | 終了状態 | 外側の時間 | 最大常駐量 |
|---|---|---:|---:|
| `scripts/check.sh --level work --base 82a7f626e38b6e861f896ec5033e08e6acdfa435` | 0 | 158.74秒 | 1,698,152,448 バイト |

選ばれた検査は、仕様対応の自己検査・集計、仕様例（7件成功・失敗0・無視0）、既定の Lean ビルドと `sorry` の拒否である。
