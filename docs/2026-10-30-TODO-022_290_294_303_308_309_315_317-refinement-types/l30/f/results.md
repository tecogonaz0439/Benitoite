# L30 群F・G: 有限な論理補題と検査器

2026-11-03。対象はL30.31〜.42である。指定ブランチは`m014/l30.f`、B_WORKは`9905c37924a87f93f78bdc1b87ea2272ea4b3090`。群A〜Eと案(ii)checkedAtの契約を引き継ぐ。既存の作業木にあった実装を点検し、不足を補って検査した。担当の自己点検と、取りまとめが行う独立レビュー・受け入れは区別する。

主な十言明の量化・結論、公開の`Entails.bind`、EqProofの9構成子、数学Intの係数を維持した。公理・独立の信頼条件・精密な外部状態・利用者の書ける形の制限・探索完全性の仮定の追加はない。旧Release、Rust、plan・detail・README・レビュー記録を編集せず、gitの状態を変える操作も行っていない。U03は決定済みの引継ぎであり、数学のIEEE補題の幅は引数のままである。

## 完了条件の照合

| 単位 | 判定と本番の証拠 |
|---|---|
| L30.31 | 担当分完了。`Pred.closedTrue`を同じ名前・型・定義でClosedEvaluationへ移した。`Pred.closedTrue_sound_at`は閉性とsortを検査成功から取り出し、既存`Pred.closed_sound_at`を使う。旧closed・lengthNonnegativeの成功は`PreparedLeaf.raw_of_check`で保存する |
| L30.32 | 担当分完了。`measure_nonnegative_at`は正常なmeasure結果に既存`Observation.measure_nonnegative`を使い、失敗時の整数0も分解する。受け手・ν・ηは任意。7種を同じraw入口で検査する |
| L30.33 | 担当分完了。Booleanの真偽の二方向を`boolean_apart_at`で証明。`observeAs_sort`で既定の射影も扱う。scalarの成功を前提とする順序則は.34と共有する |
| L30.34 | 担当分完了。補比較22、scalar順序30、Float二幅六分類を実際の比較・分類から証明。IEEEの指数部・仮数部の共通補題を二幅で使う。閉じた比較30・分類12の実評価を照合。有限端点の間からfiniteを導く`float_between`も既定の読者に置く |
| L30.35 | 担当分完了。`characters_subset_at`は同じStringの各文字と端点包含、`constructor_apart_at`は同じdataのtagと名の不一致を読む。`character_code_range_at`は`Char.valid`と実measure、`characterCompare_sound_at`は6比較を整数コードの比較へ対応させる |
| L30.36 | 担当分完了。`BuiltinSchema.candidates_sound_at`と`PreparedLeaf.raw_sound_at`で12種類を任意のνの上で合成。登録表100分岐をrawで受理。sameObservationの16sortは同じ項の代表の原子qについての`q → q`で論理を強めず、参照形は先行する原子のuseと同じである。構造の等号による原子の一致はEqProofのsubstitute（`substitute_sound_at`）が受け持つ |
| L30.37 | 担当分完了。`refute_sound_at`はRefutation9構成子の一回の帰納。Dの8局所補題と`builtin_sound_at`を使う。deriveでは`step`と`next`を明示する |
| L30.38 | 担当分完了。`Certificate.sound_at`で7構成子、恒等置換で`implication_sound`と`check_sound`を導く。`Legacy.success_preserved`は旧6構成子の成功を保存。`Certificate.checkIn`が最上位の鍵列の整数sort・宣言と途中の適格性を検査する |
| L30.39 | 担当分完了。`implication_sound_at`を既存`Pred.bind_implication_comp`へ適用する具体読者を置いた。`predBind_comp`でνの合成を行い、像ごとに新しい証明書を構成しない |
| L30.40 | 担当分完了。Entailsを18から19構成子へ拡張し、checkedは恒等置換の導出とした。weaken・cut・sound・bindへ各一場合を接続した |
| L30.41 | 担当分完了。既存のshiftV・under_none・hideConts、Le・Transport・TypedFacts・ReferenceStore・TypedMeaning・Captureの読者を既定ビルドで維持。型付けの76場合へ新しい仮定を足さない。Ty.assume・ValueMeaningの切替は群Iのままである |
| L30.42 | 担当分完了。`Certificate.refutation_entails`と生のΦを受ける既存`Certificate.sound`を接続。開いた線形、Boolean、負のList長をbuiltinで反証する例、整数等号による限定書換え、正負のrawと上層の例を既定importへ置いた。実行と核内証明を別に記録した |

## 12種類100分岐と本番定義の対応

| 登録種類 | 分岐 | 本番の根拠と読者 |
|---|---:|---|
| closed | 1 | `Pred.evalClosed_sound`と既存`Pred.closed_sound_at`。閉性・sort・some trueを再検査 |
| lengthNonnegative | 1 | 旧の閉じたList長の形とclosedTrue。旧checkからrawへの成功保存 |
| measureNonnegative | 7 | `Observation.measure_nonnegative`、失敗時0。String二長・List・Bytes・Map・Set・Character |
| booleanApart | 2 | `observeAs_sort`と`Observation.compare`のBoolean。true/falseの向き2種 |
| compareComplement | 22 | scalar七sortのeq/neの両向き14、Character・Decimalの`¬lt ↔ ge`・`¬le ↔ gt`の両向き8。Floatの順序反転は拒否 |
| charactersSubset | 1 | 同じStringの`List.all`と、下限・上限の包含 |
| constructorApart | 1 | 同じdata観測のconstructor名と、二名の不一致 |
| sameObservation | 16 | 同じ項の代表の原子qについての`q → q`で、論理を強めない。参照形は先行原子のuseと同じ。構造の等号による原子の一致はEqProofのsubstitute（`substitute_sound_at`）が受け持つ |
| scalarOrder | 30 | Character・Decimal・Float32/64の4sort×6則と、Boolean・String・Unitの3sort×2則。成功する比較を前提とする含意 |
| characterCodeRange | 1 | `Char.valid`、`Observation.measure`、0以上0x10ffff以下とサロゲート範囲外 |
| characterCompare | 6 | Characterのeq/ne/lt/le/gt/geと、characterCodeの整数eq/lt/leの双方向の対応 |
| floatCompareClass | 12 | 2幅×finite・NaN・正負Infinity・正負ゼロ。`ieeeClass`・`ieeeCompare`のbitsから導く |

合計は`1+1+7+2+22+1+1+16+30+1+6+12=100`。`BuiltinLogicExamples.registry_100`が各行の分岐数と全100行のraw成功を核内で証明する。`candidates_sound_at`は表の生成元と独立に本番の意味を証明し、任意のνとηで全行に適用する。登録表の存在や件数だけを真の根拠にしない。`registry`は`candidates`から葉を作るため、`registry_100`のraw成功は構成から成り立つ。件数と意味への接続には使えるが、raw成功だけでは検査器の退行を検出しない。

比較30はCharacter・Decimal・Float64・Float32各6、Boolean・String・Unit各2である。`closedComparisons`は等しくない二端点に対する期待値を明記し、Unitは等しい端点を使う。`comparisons_30`がこの30件を実際の`evalClosed`に照合する。再開1では数の4sortの等しい端点と逆向きの端点を`closedComparisonBoundaries`へ48件追加し、`comparison_boundaries_48`で同じ実評価へ照合した。比較の構文の30形と、実際に照合する計78件の入力を分けて数える。分類12は各幅のfinite・NaN・正負Infinity・正負ゼロの実bitsで、`classes_12`が実評価に照合する。NaNの自己等号が偽、正負ゼロの数としての等号が真という別の対照も持つ。

IEEEの共通証明は`ieeeRank_compare`・`ieeeCompare_rank`、`ieee_finite_parts`・`ieee_nan_parts`・`ieee_class_parts`・`ieee_partition`・`ieee_class_test`である。仮数部・指数部の幅はNat引数であり、UInt32/64の実bitsの上限を各適用で供給する。Decimalの順序の推移は正の10の冪の交差積と乗算の順序から証明する。非線形の自動判定は導入しない。

## 反証・証明書・Entails

refuteはRefutationSyntaxに置き、BuiltinLogicをimportする配置を選んだ。builtinは現在のfactsを述語へ写した列で葉を再検査し、葉の述語を同じkeysでNNFへ再計算してtodoへ加える。01-12・07-04の「builtinは拒否する」は実物どおりに更新した。Dの8補題の再実装はなく、追加はbuiltinの局所健全性と全反証の一回の帰納である。

Certificateのrefuteは生のΦの各連言を平坦化し、premise・goal・証明書から鍵を再計算する。`ConjunctionMeaning`は真理条件と平坦化の冪等性を供給する。`Pred.interpret_conjuncts`はCoverageRefinementから同じ完全名・型で下層へ移した。整数eqの参照を連言の文脈へ移す必要があるため、`EqProof.recontextualize`が実際の整数eqの所属から新しい位置を作る。これはEntails.bindのために証明書を置換し直す操作ではない。

| Entailsの帰納 | checkedAtの場合 |
|---|---|
| weaken | 同じν・同じ検査成功を保ち、子の帰納仮定を新しい仮定列へ適用 |
| cut | 同じν・同じ検査成功を保ち、子へ各仮定の導出を代入 |
| sound | 子の意味と`CertificateKernel.implication_sound_at`を合成 |
| bind | 元のνと外側のτを`fun i => (ν i).bind (termBind? τ)`へ合成し、`predBind_comp`で帰納仮定と結論を対応 |

`Entails.bind`は、元の導出と任意のObservationEnvから、仮定列と結論を同じ置換で写した導出を返す公開署名を維持した。`checked`は構成子ではない。下層KernelはRefinementのLogic・Le・Typing・ValueMeaning・Captureをimportしない。構文のEntailsへの変換と上層のsort・宣言照合をCertificateEntails・Certificateへ分けた。

`Certificate.checkIn`はraw成功、最上位の`c.keys (Pred.ofConjuncts Φ) goal`についての`KeyTable.checkIn`、goalと全仮定のSorted・Declared、全途中のAdmissibleInを検査する。substituteではEqProofの上層入口を使う。rawの全域整数射影での受理と、上層の非整数鍵・不適格な述語の拒否を対照にした。この上層のBoolは非計算的である。R50で実行比較できるrawの入口と、証明で照合する上層を区別する。

## 完全署名・宣言・既定の読者

完全署名は[signatures.md](signatures.md)、宣言の分類は[declarations.json](declarations.json)。[source-signatures.py](source-signatures.py)で本番から再生成できる。署名の在庫は再開1の適用例の追加を含む150宣言であり、既存の移動・変更と適用例も含むので、新規定理150件とは数えない。

| 新モジュール | 宣言の役割と既定の読者 |
|---|---|
| BuiltinFacts | closedTrueの意味、measure非負、sort射影、Boolean、文字と構成子。BuiltinSchema・BuiltinLogic |
| ScalarLogic | ScalarRule、IEEEの順序・分類、Decimalの交差積、補比較。BuiltinSchema・BuiltinLogic |
| BuiltinSchema | 12種の有限の候補、比較・分類の節と有限表。BuiltinLogic・二つの適用例 |
| BuiltinLogic | candidates_sound_at、PreparedLeaf.checkRaw/raw_sound_at、旧check。RefutationSyntax・RefutationSound・CertificateKernel・CertificateLegacy |
| CertificateData | Certificate7構成子と、実際の項からの鍵の再計算。CertificateKernel・Certificate |
| ConjunctionMeaning | 連言の列の意味と平坦化。CertificateKernel・CertificateEntails・CoverageRefinement |
| CertificateKernel | check・sound_at・implication_sound_at・恒等置換の二つの系。Logic・LogicSound・CertificateEntails |
| CertificateEntails | rawの葉・限定書換え・証明書から同じEntailsへの接続。Certificate |
| CertificateLegacy | 旧6場合の検査・埋め込みと成功の保存。CertificateKernelExamplesの六構成子を読む具体例 |
| EqProofTransport | 整数eqの参照の移送と、structuralの文脈非依存。CertificateEntails・CertificateLegacy |
| BuiltinLogicExamples | 100分岐・30比較・12分類・12種の正負の表。既定Benitoite importと実行の台本 |
| CertificateKernelExamples | 開いた線形・Boolean・measure、限定書換え、四つの像、上層、finiteの導出。既定Benitoite importと実行の台本 |

既存の内部補題の変更は次のとおりである。`observation_order_complement`と`orderComplement_sound_at`は左右を交換したle/ltの表示から、同じ二端点のge/gtの表示にした。補比較の8分岐を計画のlt/le/gt/geと直接対応させるためであり、S02・S03の公開契約は変えない。Pred.closedTrue・Pred.interpret_conjuncts・PreparedLeaf.checkの移動は完全名・型を保つ。Certificateの7構成子・substituteのmode・checkedAtは群Aで固定した拡張どおりである。

## 適用例の作成時の関門

`images`の例は、任意のνについての一般定理`twice_entails_at`を四つの像へ当てはめる読者である。像ごとの計算結果を個別に確かめた例とは数えない。

所有する境界はrawの葉・反証・証明書の公開入口と上層checkInである。100分岐の件数だけでなく、全件のraw成功、意味の一般証明への適用、期待値を明記した30比較と12分類を確認する。12種類の各結論をfalsityへ改竄した葉、Floatに不正な順序反転を使う葉、前方参照・異なる項を同じ観測とする葉を拒否する。

開いた線形の例は`x≤5`から`2*x≤10`を導く。結合の乗数だけを誤った証明書は拒否する。負のList長の例は開いたmeasureの非負をbuiltinで追加して閉じる。上層の受理例は、同じ具体のProgramのVarianceValidとInteger8の文脈を構成し、raw成功に加えて鍵・述語のsort・宣言を実際に供給する。rawで受理するBooleanの整数eqを上層が拒否する例は、鍵と述語の両方が不適格であると明記し、一方だけを切り分けた例とは数えない。旧の六構成子は一つの具体の旧証明書にまとめて成功保存を適用する。テストだけの差し込み口は増やしていない。

## 時間の記録と検査

単位ごとの厳密な作業時計は未採取である。次の表は引き継いだ新規ファイルの作成時刻・更新時刻とログから確認できる区間であり、実装の開始から完了までの所要時間を確定した値ではない。区間が重なるのは共通補題・登録表・適用例を共有するためである。単位の区間を足さず、能動時間や一件単価へ使わない。読み取り・初期の実装の時計を後から推定して埋めない。

| 単位 | 観測された区間（2026-11-03、+0900） | 外側の時間の扱い |
|---|---|---|
| .31 | 08:50:10〜09:07:05 | .32/.33/.35と共有する16分55秒の観測区間。開始前の読取りと後の修正は含まない |
| .32 | 08:50:10〜09:07:05 | .31と共有、単独の外側の時間は分離不能 |
| .33 | 08:50:10〜09:07:05 | .31と共有、単独の外側の時間は分離不能 |
| .34 | 08:51:47〜09:27:17 | .36の共通表・適用例を含む35分30秒の観測区間。その後のge/gt対応の修正は別 |
| .35 | 08:50:10〜09:07:05 | .31と共有、単独の外側の時間は分離不能 |
| .36 | 08:51:47〜09:27:17 | .34と共有、単独の外側の時間は分離不能 |
| .37 | RefutationSoundの最終更新09:05:41 | 開始未採取、単独の外側の時間は不明 |
| .38 | 09:07:05〜09:13:22 | Kernel・Legacy・上層の6分17秒の観測区間 |
| .39 | 09:10:23〜09:13:22 | .40/.41と共有する2分59秒の観測区間 |
| .40 | 09:10:23〜09:13:22 | .39と共有、単独の外側の時間は分離不能 |
| .41 | 09:10:23〜09:13:22 | .39と共有。全読者の検査待ちは既定ビルドへ別記 |
| .42 | 09:14:10〜09:27:17 | 適用例の13分7秒の観測区間。後の置換合成・旧6構成子の例の補足は別 |

09:32:48以後の点検で、ge/gtの直接の対応、既存closed_sound_atの再利用、検査済み含意への既存の置換合成補題の適用、旧六構成子を一つの証明書で読む具体例を補った。作業全体の能動時間を分離できないため、群F・Gの旧見込み7時間20分〜14時間40分を外挿で変更しない。4時間・上端2倍の停止時刻へ達したという証拠はない。

初回の検査の正確なコマンド・終了・時間と生記録の大きさ・SHA-256は[initial-verification.json](initial-verification.json)、[initial-audit-summary.json](initial-audit-summary.json)、[initial-work-summary.json](initial-work-summary.json)を正とする。再開1の検査は末尾に別記する。生の出力と対象名一覧は`<tmp>`に置き、改造へは要約だけを保存する。正式RSSは未取得（計画上の非採取）。既定lakefileと単独Leanの上限はいずれも`-M 12288`である。

| 最終の検査 | 終了・外側の時間 | 内容 |
|---|---|---|
| `lake build` | 0、136.496秒 | 既定の全8 targets、932ジョブ。ge/gt対応と最後の適用例を含む。先の既定ビルドも0、115.306秒であり、その後の修正により再実行した |
| raw核の実行 | 0、0.384秒 | `lake env lean -M 12288 --run`で[run-kernel.lean](run-kernel.lean)を実行。全8項目true。同じ100/30/12の表と証明書を既定の核内証明が読む |
| 全定数の公理依存 | 0、4.551秒 | 43モジュールの全定数と旧主定理・主要十移送の3,163宣言。private・生成宣言を含む |
| 最後のwork | 0、7.905秒 | `scripts/check.sh --level work --base 9905c37924a87f93f78bdc1b87ea2272ea4b3090`を`--only`なしで一度実行。先に同じ指定のdry-runを確認。仕様対応の自己検査・集計、仕様の例7件成功、既定Leanビルドとsorry拒否 |

公理依存の内訳は、なし1,148、propextのみ1,235、propextとQuot.soundが110、Quot.soundのみ1、許可三公理が669である。sorryAx・独自公理は0。既定ビルドには既存モジュールの警告がある。今回の新規・変更モジュールの新しい警告は0であり、既存警告を隠す設定は足していない。

生の`axioms.log`は642,333バイト、SHA-256は`14015e94383a94f611e32bc95d5f850aeef5f76bfbf8956e6fda5bb848cae95b`。`audit-targets.txt`は238,749バイト、SHA-256は`17a04aacd0a9373bc4c747e04610de1a5f14fe8cc745e18fb802862c1898a24a`である。[audit.lean](audit.lean)と[audit.py](audit.py)で一覧・公理の出力・要約を再生成できる。改造内に大きな一覧を写していない。

初回の[initial-inputs.json](initial-inputs.json)は本番・写し・設定の27入力と、形式化の全682ソースの一覧のハッシュを記録する。[inputs.py](inputs.py)で同じ規則の一覧を再生成できる。初回の検査後は記録だけを更新し、その後の再開1で加えた変更と検査は末尾に別記する。検査結果の別HEADからの引用は行っていない。

局所検査の初回、旧六構成子の具体例でPred.openの展開とtruth.closedTrueの証拠が不足し、終了1となった。predBindの展開と核内で確かめた閉じた真の証拠を補い、未使用のsimp引数を除いて再検査し終了0となった。先行する実行の台本にはExternalCheck.olean未生成による失敗もあった。この二つを成功の証拠へ混ぜず、最終の既定ビルド後の実行で確かめ直した。

## 義務の一行ずつの判定

判定は群F・Gの担当分に限る。L30全体、Rust実装、独立レビュー、設計者の受け入れを閉鎖した行はない。

| 義務 | 今回の判定・証拠 | 残る担当 |
|---|---|---|
| O015 | 一部。16sortの表の形と、Boolean・文字・構成子の有限規則。sameObservationは論理を強めない。観測の成功との接続は今回の完了に含めない | Kの.66で16sortの各行の供給元を照合、L40/L50の対象・所属 |
| O017 | 今回の担当単位なし。計上・版の契約を変えない | L、R20/R50/R60 |
| O019 | 担当分完了。Certificate7/Refutation9の全健全性、EqProof9の再利用、旧成功保存 | Kの上層の葉、Lの拒否理由、R20/R50 |
| O020 | 担当分完了。Dのdiscardと左右の独立を全反証の帰納へ合成 | L、R20/R70 |
| O021 | 今回の担当単位なし。重なる区間を外挿の単価にしない | H/L/N、取りまとめ |
| O022 | 担当分完了。有限12種類のraw検査と本番の比較・分類からの意味。sameObservationの16分岐は論理を強めない | H〜Kの入力・葉、L40/L50/L60 |
| O023 | 担当分完了。同じ証明書の核内のby decideと台本の実行を別記 | Mの全照合、R50 |
| O026 | 今回の担当単位なし。任意整数割当から実値を構成すると主張しない | J/L、R20/R60 |
| O034 | 今回の担当単位なし。数学の有限規則を実δの全契約と数えない | J/K、L40/L50/L60/R50 |
| O043 | 今回の担当単位なし。Ty.LeQの新しい葉の全接続は未実施 | K、L40/L70 |
| O050 | 担当分完了。.39のνの合成は限定書換えのν上の健全性を引継ぐ | Jの観測、L40の標準葉 |
| O054 | 担当分完了。Boolean二向き・scalar順序・Entails19場合の接続 | Kの実際のapart、L40/L70/R10b |
| O071 | 担当分完了。全反証と全証明書の健全性は検査成功だけを前提にする | L、R20の探索・unknown、D10 |
| O072 | 今回の新しい担当単位なし。既存の限定合同と鍵を再利用 | J/K、R10b/R20 |
| O127 | 担当分完了。charactersSubsetの有限区間包含 | I/J/K、L40/R段/V10 |
| O130 | 担当分完了。String二長を含む7measureの開いた非負 | J/Kの正常観測、L40/R段/V10 |
| O131 | 担当分完了。開いたList長の非負とbuiltinによる負の長さの反証 | J/Kの非空の葉と本体、L40/R段/V10 |
| O132 | 担当分完了。Bytes長の数学上の非負。機械幅やByteの範囲を混同しない | J/K、L40/R段/V10 |
| O133 | 今回の担当単位なし。Map鍵の一般の等値を完成済みとしない | J/K、L40/R段/V10 |
| O134 | 今回の担当単位なし。Set鍵の一般の等値を完成済みとしない | J/K、L40/R段/V10 |
| O135 | 今回の新しい担当単位なし。既存の欄の限定合同を使用 | J/K、L40/R40/R50/V10 |
| O136 | 担当分完了。.39の同じνの合成を既存補題とEntails.bindへ接続 | Kの依存端点、L40/L70/R段/V10 |
| O137 | 今回の担当単位なし。数学Intのsoundを機械整数の正常δの証明としない | I/J/K、L40/R段/V10 |
| O144 | 担当分完了。12種類100分岐と検査器・構文の導出の全接続。sameObservationの16分岐は論理を強めない | H〜Kの型・実観測、L40/L50/R段/V10 |
| O158 | 今回の担当単位なし。独立の上限を足さない | L、R20/R70/V10 |
| O161 | 今回の担当単位なし。保存幅128を数学の補題へ固定しない | L、R20/R60/V10 |
| O167 | 担当分完了。Floatの不正な反転、誤った結合、参照と上層の非整数の拒否を受理と対照 | K/L、L40/L70/R段/V10 |
| O046 | 担当分完了。既存の捕捉・評価の葉を維持し、Boolean・measureの有限規則を供給 | J/K、L40/L70 |
| O079 | 今回の担当単位なし | Kの非空List、L70/R10b/R50 |
| O138 | 担当分完了。開いたBooleanの相異を実証明書からEntailsへ接続 | Kの短絡・非空、L40/L70/R段/V10 |
| O143 | 今回の担当単位なし | Kのlength証明書、L40/L70/R段/V10 |
| O016 | 担当分完了。43モジュールの全定数と旧主定理・主要十移送を公理監査 | 独立レビュー、N/L70の全監査 |
| O084 | 担当分完了。今回の証明・検査と後段の未実施を分け、記録の時計の限界も明記 | M/N、取りまとめの独立レビューと受け入れ |
| O027 | 担当分完了。-M12288、検査の終了と外側の時間。正式RSSは非採取 | Nの最後の同じworkで取りまとめが採取 |
| O118 | 担当分完了。01-12/07-04を実物の規則・前提へ更新。工程ID・絶対パスを本番へ足さない | N、L70/R50/R60/D10/V10 |

## 計画との差と申し送り

公開のS02・S03の署名、Entails.bindと主要十移送の形を変える必要はなかった。全反証の帰納をFの後で一度閉じ、既存の線形化・NNF・Dの8規則・EqProof9構成子・一般の置換合成を再利用した。独立の探索器や外部状態を置いていない。

記録上のずれは、初期の単位別の外側の時間を厳密に分離できない点である。観測区間と未採取を明記し、外挿に使わない。後続の見込みを一律に下げる根拠にしない。

群Kは、rawで既に証明した12種類から、PreparedLeafのsort・宣言を読む上層と本番の三条件の葉を構成する。群Jは正常な観測・鍵・算術、群Iは型域と意味の切替を担当する。R50は計算可能なrawと非計算的な上層を区別する。A-Lの対象一覧は台本で再生成でき、anonymousなexampleは名前の一覧に入らないため、既定ビルドとsorry拒否で検査し、その使用定義・名前付き補題・private/生成宣言を公理監査へ含める。

取りまとめへ新しい方式・主定理・公理について判断を求める点はない。独立レビューと担当分の受け入れ、時間の記録の限界を踏まえた見込みの転記を取りまとめへ渡す。Rustとの全比較、実δの全契約、L30段全体の受け入れは未実施である。


## 再開1: RV-L30.fの中1・軽1〜3・情報の処置

2026-11-03。取りまとめが採った案(a)に従い、sameObservationの規則を作り直さず、写し・判定・適用例を訂正した。主な十言明、S02・S03、Entails.bind、型付けの規則、公理を変えていない。初回の監査・work・入力・検査・宣言のJSONはinitial-*.jsonに保持した。現在の同名の要約は再開1を表す。

| 所見 | 処置と根拠 |
|---|---|
| 中1・案(a) | 01-12・07-04・本書に、sameObservationの16分岐が同じ項の代表の原子qについての`q → q`で論理を強めず、参照形は先行原子のuseと同じであることを明記した。引数二項と参照先の原子の対応は要求されない。構造の等号による原子の一致はEqProofのsubstitute（`substitute_sound_at`）が受け持つ。O015のL30分を「一部」へ訂正し、観測の成功との接続を今回の完了から外した。O022・O144にも16分岐の意味の限界を併記した |
| 中1の補助入力 | 本番の読者がないため、新しい本番の定理は置かなかった。[same-observation.lean](same-observation.lean)に`sameObservation_tautology`と、原子と無関係な引数二項でも参照形を受理する例を保存した。formalから`lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l30/f/same-observation.lean`で再実行できる |
| 軽1 | 01-12と07-04のsubstituteに、goalと`p.open u`の構造一致を照合し、子の結論は`p.open t`であることを明記した。検査器の定義は変えていない |
| 軽2・近い改竄 | BuiltinLogicExamplesの`alteredLeaves`へ、包含しない境界、同じ構成子名、推移の結論の逆向き、等号だけのStringへの順序則、二つの参照、論理結合子への参照の6件を置いた。`altered_leaves_rejected`が実際のraw入口で全件の拒否を核内で検査する |
| 軽2・比較の入力 | 共通の`scalarEndpoints`から、従来の30件に加え、数の4sortの等しい端点と逆向きの端点×6比較の48件を構成した。`comparison_boundaries_48`は期待値を明記した全48件を実際のevalClosedへ照合する。比較の構文は30形、照合する入力は計78件である |
| 軽2・例の主張 | `registry_100`のraw成功はcandidatesからの構成により成り立つこと、`images`は任意のνについての一般定理の適用であり像ごとの計算結果の照合ではないことを本書へ明記した |
| 軽3 | 既定importのBuiltinLogicExamples・CertificateKernelExamplesの末尾の`#eval`を削除した。同じ内容は既存のregistry_100・comparisons_30・classes_12・registered_samples・twice_checked・negative_length_checkedとBooleanの`example`が`by decide`で検査する。重複する印字や新しい重複の検査は置かなかった |
| 情報4 | `floatZero`のdocstringに、negativeはこの定数の符号であり、positiveZeroの節は負のゼロとの等号、negativeZeroの節は正のゼロとの等号を示すことを明記した。定義と名前・型は維持した |

追加例の作成時の関門は、有限の葉の公開raw入口と閉じた評価を持ち主の境界として通した。6件の拒否は、各補題の条件や参照の制約を誤って緩めた退行で結果が変わる。正しい形の受理は既存のsamples・registryと対照にする。追加48件のうち、等しい端点の24件は等号と反射的な順序の分岐、逆向きの24件はgt/geとlt/leの向きを取り違える退行を検出する。期待値は比較器の出力から作らず表へ明記した。本番の差し込み口を増やしていない。

### 群Kへの申し送り

- O015はL30全体として一部である。.66で16sortの各行について、観測の成功との接続の供給元を照合する。sameObservationに意味のある形が要ると判明したときだけ、取りまとめの判断に従って作り直す。今回の16分岐を、別名や意味上の観測の一致を導く規則として扱わない。
- Certificate.checkInのKeyTable.checkInは最上位の`c.keys (Pred.ofConjuncts Φ) goal`だけを検査する。入れ子のrawのrefuteは、その位置のΦとgoalから鍵を再計算する。入れ子の鍵の最上位の鍵列への包含の補題はまだない。述語のSortedから鍵の整数sortが従うという見込みも未証明であり、確認済みの事実にしない。群Kで葉・途中の文脈と全sortを照合するとき、この境界を確認する。
- 情報2・3は既存の保存証明とimportの境界を確認した情報であり、追加の規則や仮定は要らない。旧6場合の保存は定義の写しに対する証明として維持し、下層へRefinementの型付け・意味・捕捉のimportを足していない。


### 再開1の検査・外側の時間

| 検査 | 終了・外側の時間 | 内容 |
|---|---|---|
| 局所Lean | 3件とも0、0.550秒・0.623秒・0.933秒 | 記録用same-observation、CertificateKernelExamples、BuiltinLogicExamplesをそれぞれ`lake env lean -M 12288`で検査。警告・エラー0。並行実行であり、時間を合算しない |
| 既定ビルド | 0、130.567秒 | formalで`lake build`を一度実行。全8 targets・932ジョブ。既存の警告はあり、今回の3変更モジュールの新しい警告は0 |
| 公理監査 | 0、4.517秒 | audit.pyから既定importの43モジュール・private/生成宣言・旧主定理・主要十移送を再実行。3,168宣言 |
| raw核の実行 | 0、0.361秒 | 更新したrun-kernel.leanを`lake env lean -M 12288 --run`で実行。追加の比較48件と改竄6件を含む全10項目true |
| 作業末work | 0、4.031秒 | `scripts/check.sh --level work --base 9905c37924a87f93f78bdc1b87ea2272ea4b3090`を`--only`なしで一度実行。同じ指定のdry-runを先に確認。仕様対応の自己検査・集計、仕様の例7件成功、既定ビルドとsorry拒否 |

既定ビルドとwork内の既定ビルドは、再開の依頼が両方を指定したため実行した。workの反復は0。局所Leanから最後のworkまで失敗は0である。単独Leanと既定lakefileの上限は12288 MiB。正式RSSは未取得（計画上の非採取）。

公理依存は、なし1,151、propextのみ1,235、propextとQuot.soundが110、Quot.soundのみ1、許可三公理が671で、合計3,168宣言。sorryAx・独自公理は0。元の3,163宣言から5件増えた。追加した名前付きの宣言は、共有するscalarEndpoints、closedComparisonBoundaries・comparison_boundaries_48、alteredLeaves・altered_leaves_rejectedであり、既存の本番定理の署名は変えていない。署名の在庫は150件へ再生成した。

| 生の記録（保存先は`<tmp>`） | バイト | SHA-256 |
|---|---:|---|
| lake-build.log | 64072 | `a091e021f29a2a84741d6d9b7eec4dd7acb19c5c6469e27be8fcfde770739f36` |
| axioms.log | 643454 | `05aa514af03a923fdd7d90d54656d42b72407f5cb53b6099788ba090a3cede3b` |
| audit-targets.txt | 239166 | `6c250387932097e64a32d9be39a7b4dd13dd0f9efa327311a6dab286dd8529dd` |
| run-kernel.log | 195 | `5a9c4480473cf8f9537e93183dae4d6dfcc1ce92b784d51ae78959ef560cd2cd` |
| work.log | 5757 | `69416ff971beb14cb90db9a6e3b1adec78189fe8e802ffc6cdd97dc13cb5303f` |

生の対象名一覧を改造へ写さず、audit.lean・audit.pyから再生成する。補助入力の内容・実行のコマンド・終了・大きさ・SHA-256はverification.jsonに、入力27件と全682ソースの一覧のハッシュはinputs.jsonに保存した。改造内の各記録は100 KB以下である。

計時開始は09:56:29、検査後の時計の取得は10:02:15（いずれも+0900）。この区間の外側の時間は346秒（5分46秒）で、資料読取り・修正・局所検査・既定ビルド・監査・workの待ちを含み、能動時間へ読み替えない。開始の時計より先行した冒頭の読取りの端数は未採取。最後の記録照合と報告はこの後である。正確な検査値と区間は[resume1-summary.json](resume1-summary.json)に保存した。

再開1の最終検査後の本番Lean・写し・設定の変更は0。以後は記録と入力ハッシュの照合だけを行う。担当の中1・軽1〜3・情報の処置は完了した。レビューは案(a)の記録の訂正であれば再レビュー不要としており、規則を作り直していない。取りまとめによる処置の確認・受け入れは未実施である。新しい判断を求める点はない。

## 作業末の work

取りまとめが、RV-L30.f（可。中1は記録と写しの訂正の案(a)で処置し、規則を作り直していないので、レビューの条件により再レビューを要しない）の処置の後に、Refinement の生成物を消してから一度実行した。

| コマンド | 終了状態 | 外側の時間 | 最大常駐量 |
|---|---|---:|---:|
| `scripts/check.sh --level work --base 9905c37924a87f93f78bdc1b87ea2272ea4b3090` | 0 | 157.16秒 | 1,533,427,712 バイト |

選ばれた検査は、仕様対応の自己検査・集計、仕様例（7件成功・失敗0・無視0）、既定の Lean ビルドと `sorry` の拒否である。
