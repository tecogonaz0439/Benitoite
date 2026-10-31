# L00b.05: 証明書の葉と外部受信検査の結果

2026-10-31。B_WORK は `0f771fa1789728aa00dc35b1eb6db9ac6345833e`、指定ブランチは `m014/l00b.05` である。git の照合・切替・作成・コミットは行っていない。[完全署名](signatures.md)を本番の編集前に作り、同じ起動で実装と境界例を閉じた。**本作業の葉の代表と外部受信の接続は閉じた。全sortの証明書と全状態の保存の完成は主張しない。** L00b.11には進んでいない。

## 定義と閉じた補題

初回実装での本番の新規は3ファイル、既存の変更は5ファイルである。当時選んだ45公開名の省略なしの型を[public-api.log](public-api.log)、対象名を[public-targets.txt](public-targets.txt)に保存した。private・生成宣言を含む当時の公理依存の全対象は[axiom-targets.txt](axiom-targets.txt)にある。レビュー対応の追加と検査は末尾に記す。

| 本番のファイル | 実装した内容 |
|---|---|
| [Certificate.lean](../../../formal/Benitoite/Release/Refinement/Certificate.lean)（新規） | traceを持たない有限のCertificate、EqProof、BuiltinLemma、PreparedLeaf。枝の仮定列のlookup、consume/cases/discard、検査した構文等号によるsubstituteとsound。文脈を受けるcheckSortedは全仮定と結論のsortを検査し、適格性とEntailsを返す。閉じた長さの非負と欄のlengthの一致を空でない葉からEntailsへ接続した |
| [ExternalObservation.lean](../../../formal/Benitoite/Release/Refinement/ExternalObservation.lean)（新規） | Ty.sort_carrier、HasTypeVQ.closed_observation/argumentsEnv_observation/represented。型付きのsortを持つ値のtoTerm?のsome・sort・閉性を示し、Tel.argumentsEnvの0番とtermBindの実際の項へ接続する。Const.NumericRepresented/ConstOK.representedで数値の範囲を分ける |
| [ExternalConnection.lean](../../../formal/Benitoite/Release/Refinement/ExternalConnection.lean)（新規） | externalReceive_of_args、ExternalAssumptions.receive/external_adequate、Step.external_accept/reject。実引数列による結果型の具体化と受信後の型付け・no-exit・obs=[]を照合し、成功/違反を二つの規則へ接続する |
| [ExternalCheck.lean](../../../formal/Benitoite/Release/Refinement/ExternalCheck.lean) | Outcome.Typedを移してimportの循環を避けた。ExternalCarrier/Each/Fields.adequateを8/2/2場合で証明し、外部の値構造は任意のσで適格であることを示す。述語の真や受信検査の成功を適格性の前提にしていない |
| [ExternalResponse.lean](../../../formal/Benitoite/Release/Refinement/ExternalResponse.lean) | external_typedの正常結果をOutcome.Carrierへ弱めた。exists/no_targetsとno-exitの量化を維持した。externalCheckedOutcome_typedから元の篩付き型付けを戻すchecked_typedと、宣言のinstantiateを使うexternalReceiveを置いた |
| [Semantics.lean](../../../formal/Benitoite/Release/Refinement/Semantics.lean) | E_External/E_ExternalErrが生の応答を受け、externalReceiveのval/errを検査する。拒否したvalはExternalRefinementのerrとして後者を使う。二規則とも無事象で同じσ・ストア・継続を保つ |
| [Step.lean](../../../formal/Benitoite/Release/Refinement/Step.lean) | 同じexternalReceiveを呼び、val/errだけを対応する到達先へ写す。exitと具体化の失敗には遷移しない |
| [集約import](../../../formal/Benitoite.lean) | CertificateとExternalConnectionを既定へ追加した。ExternalObservationも後者から既定に入る |

Outcome.Carrierは元の型を添字に持ち、名目dataの宣言欄まで再帰する値構造である。`HasTypeV v a.carrier`とは異なる。受信の接続はTy.carrierを使わない。Ty.sort_carrierを読むHasTypeVQ.representedはL30の利用に備えて置いた補題であり、現時点の本番と境界に呼び手はない。L30で使わなければ削除する。成功後の元の型付けは、.04のExternalCarrier.checked_typedと今回の三欄の改訂から得る。

閉じた葉のmachine_exactは、実際にevalClosedが成功したときのinterpretとの一致である。stableは閉じた述語の任意の値置換での不変である。representedは既存のConstOKの数値範囲と、型付き値の観測の成功として明記した。Observation.measure_nonnegativeは全7 measureの正常な整数結果に対する数学上の非負を示す。これらを実δとの全入力での一致や、長さが機械のIntegerへ収まることと同一視しない。

## 外部の前提・結論の照合

| 箇所 | 維持・改訂した契約 |
|---|---|
| external_typed | 宣言表WF、同じ関数lookup、型付き・groundの実引数と具体化結果を持つExternalArgs、生のexternalResponseを前提とする。結論だけをOutcome.Carrierへ改め、全Intの終了コードに対するno-exitは維持した。承認済みD28の意味の変更である |
| external_exists | 同じWF/lookup/ExternalArgsから生の応答の存在を返す。正常結果の存在や決定性は足していない |
| external_no_targets | 同じ入力と応答についてobs=[]を返す。新しい事象を足していない |
| receive/checked_typed | 同じ具体化結果の型で全入れ子を検査し、成功なら元の型とGround、違反ならerrを返す。受信後にもno-exitとobs=[]を保つ |
| external_adequate | carrierから全σで導く補題であり、第四の信頼条件ではない。保持対象を外部の値構造が生じないことを使い、精密な外部状態や所有権ヒープを加えていない |
| Step/step | 宣言のinstantiateが選んだ同じ結果型と同じ受信検査を使う。raw valの成功と拒否、raw err、exitの拒否を同じ分岐で扱う。受信の二規則のラベルはnone |
| 保存との接続 | checked_typedがcarrierから元の型付けへ戻す一般の葉である。境界で、成功と違反の両方のStateTy→Step→StateTyとstepの選択を構成した。全状態の反転・捕捉・継続を合成する保存の一般定理はL20/L70へ残る |

述語は.04の強いKleeneの三値をそのまま使い、some trueだけを受理する。unknownが結果に影響する場合、sort不適格、toTerm?の根がnoneの場合を受理しない。根のgetD(integer 0)は全域関数の定義として残るが、sortを持つ型付きの閉じた値ではsomeの実観測へ到達する。snapshotの欠落はslotBindでnoneのまま保つ。

## 場合の数と境界入力

[axioms.lean](axioms.lean)はLeanの環境から構成子数を取り出し、期待値との一致を要求する。[case-inventory.txt](case-inventory.txt)はその件数の記録である。

| 対象 | 予定 | 実際・証明の範囲 |
|---|---:|---|
| EqProof | 4 | 4。refl/symm/trans/addとsound。一般の意味上の別名の等号は未実装 |
| BuiltinLemma | 2 | 2。closed/lengthNonnegative。葉の検査成功はgroundへ接続 |
| Certificate | 6 | 6。use/leaf/substitute/consume/cases/discardとsound |
| PreparedLeaf | 1 | 1。検査、Entails、閉じたmachine_exact/stable |
| ExternalCarrier/Each/Fields | 8/2/2 | 8/2/2のまま。adequateの相互証明を追加 |
| Ty.sort_carrier / ConstOK.represented | Ty21/Const16 | 21/16。既存の型付けの全場合を再証明していない |
| measure_nonnegative | Measure7/Observation14 | 7×14の組合せを検査し、正常結果のある7組で非負を証明 |
| Step | 76を維持 | 76。外部の二規則を改訂し、新しい遷移を加えていない |
| Entails / HasTypeVQ / HasTypeCQ | 18/28/21を維持 | 18/28/21。三族71・TypedFacts56の構成子を増やしていない |

初回実装の[boundary.lean](boundary.lean)には39の公開定理を置いた。主な入口は次のとおりである。

- `before/accepted_step/after_accept`、`before/rejected_step/after_reject`は、篩付きの外部署名と具体的な7/−1の応答を使う。成功と違反の両方にcarrierがあり、違反値が篩に属することを仮定しない。型付きの呼出し、受信のStep、到達先のStateTyを構成する。σにはValidだけを要求する。
- `step_accept/step_reject/exit_rejected`は計算関数の実際の選択を照合する。
- `seven_observation/missing_slot_preserved/unrepresented`は、具体化の実観測、slotのnone、根の全域化、幅の外の数値の拒否を分ける。
- `length_certificate/length_entails`、`branched/branched_entails`、`substituted_certificate/substituted_entails`、`field_length/field_length_entails`は、空でない証明書を実際のEntailsへ接続する。長さには観測しないnoneの要素も含む。
- `out_of_range/sibling_reference/corrupt_leaf/wrong_sort/corrupt_eq/wrong_builtin/malformed_assumption`は、それぞれ参照・葉・sort・等号・登録した補題の形の破損を拒否する。`sorted_certificate`はsortを検査する入口の正例である。

test-auditの作成時の関門を適用した。持ち主の境界は、新しい証明書の受理と、受信後のStep/step/StateTyの接続である。旧の評価器単体の例は、external_typedが篩まで信頼したままの場合や、stepだけが受信検査を通らない場合を捕まえない。今回の正負の入力はその接続を検査する。篩違反の応答を返す外部の表は抽象的な外部依存であり、所属検査を表の側で実装していない。結論を仮定する正例や、テスト専用の本番のフラグ・差し込み口を加えていない。初回実装の本番の新規3ファイルは計261行、境界入力は218行であった。既存のテストは削除していない。

## 補助の契約で決めたことと計画との差

| 論点 | 採った案・理由・捨てた案 |
|---|---|
| 結果型の選択 | 宣言と実引数のinstantiateから一意に選ぶ。oracleが結果型を指定する案は信頼を増やすので捨てた |
| importの向き | Outcome.TypedをExternalCheckへ移した。既存の完全名は保ち、ExternalResponseを読む側からも使える。検査と三条件の相互importは捨てた |
| carrierの使い分け | 応答はOutcome.Carrierとした。Ty.carrierとそのsortの保存は受信の接続では使わず、L30で利用箇所を確認する。元の宣言欄の篩を消せないHasTypeV v a.carrierへの置換は捨てた |
| 適格性 | 外部の値構造から導出した。第四の条件を信頼する案を捨てた |
| sortの入口 | 論理の再生とsortを検査するcheckSortedを分け、その成功が両方を返すようにした。hypだけでsort不適格な仮定を受理する入口は捨てた |
| EqProofの現在の範囲 | 構文等号を検査する有限木とその置換を置いた。全sortの別名・欄・measureの合同性はL30へ固定した。意味上の任意の等号やEntailsを入力に渡す案は捨てた |
| builtinの代表 | 閉じた評価から長さ非負と欄の一致を構成した。実δとの一致を評価器だけで済ませる案は捨てた |
| 根とslotの欠落 | 型付きのsortから根のsomeを導き、slotのnoneは保持した。欠落を一律に整数0へ写す案は捨てた |

計画の提供範囲・主定理の結論・新しい公理の追加はない。署名の補助の細部の確定、adequateの一般の補題、sortの入口をこの作業の内数で追加した。全sortをL30へ残す計画は保ち、未証明の一般化を今回の代表の完成に含めていない。

## 初回実装の検査の結果と証拠

検査時の入力は[inputs-sha256.json](inputs-sha256.json)、実行順・コマンド・終了・開始UTC・外側の秒数・出力のハッシュは[verification.json](verification.json)にある。[verify.py](verify.py)はリポジトリ内の相対パスから再実行できる。設定はformal/lean-toolchainのLean 4.34.1と、lakefileの`-M 12288`である。単独のLeanにも同じ上限を明示した。

| 検査 | 終了 | 外側の時間 | 証拠 |
|---|---:|---:|---|
| `formal/`で既定の`lake build`。旧/並置/全既定ターゲット | 0 | 4.092秒 | [build.log](build.log)。697 jobs。増分ビルド。既存Intervalのlintとリンカの探索先の警告は残るが、新規・変更したLeanの警告はない |
| `lake env lean -M 12288`で境界入力 | 0 | 1.285秒 | [boundary.log](boundary.log)。診断出力なし |
| 同じ入口で全宣言の公理依存と構成子数 | 0 | 1.408秒 | [集計](axioms-summary.json)、[全対象](axiom-targets.txt)。7モジュールのprivate・生成を含む764宣言と、旧モデルの充足・限定同値・主定理12宣言、計776 |
| 同じ入口で45公開名の完全署名 | 0 | 0.737秒 | [public-api.log](public-api.log) |

公理依存は`propext`・`Quot.sound`・`Classical.choice`だけであり、sorryAxと未承認公理はない。148,307バイトの公理依存の生の記録は`<tmp>`へ置き、[large-records.md](large-records.md)に大きさとSHA-256を記録した。小さい出力は改造内に保存した。

途中の局所検査では、carrierの適格性の相互再帰の書き方、証明書の枝の弱化と定理の引数の推論、境界入力のAnnotationの組立て、構文の等号の簡約で失敗した。各々を明示した構成子による再帰・枝内の仮定の写し・元の注釈・構文等号の簡約で直した。measureの非負の最初の証明は、Option内で既にIntへ写していた点を見落としたため失敗し、7×14の場合を直接照合する証明へ直した。新しい公理や未証明の前提で埋めず、上表の最終実行で関係する箇所を再確認した。

作業末のworkは指示どおり取りまとめへ委ね、実行していない。RSSは未取得（計画上、この作業では非採取）。Rust/Leanの全比較、独立レビュー、受け入れは初回実装時には実施していない。群末レビューの結果と対応は末尾に記す。旧主定理の公理依存を確認したことを、新しい全状態の保存の完成とは呼ばない。

## 閉じた義務と送り先

| 義務・出どころ | 今回の判定と証拠 | 残りと担当 |
|---|---|---|
| O019・L00b.05 | traceなしの有限列と枝、EqProof/substitute/builtinLemma/sort/discardの入口と代表を固定しsoundを証明。Certificateと境界入力 | L30は否定標準形・線形化・derive/round/split/close、全sortの合同と本番の有限表を完成する。R20は探索・独立検査へ接続する |
| O022・L00b.05 | 閉じたmachine_exact/stable、型付きのrepresented、全measureの正常結果の非負、長さと欄の代表を固定・証明 | L30/L50は型/行/範囲/値を量化した実δとの一致、鍵の成功・重複縮約・別名・欄連鎖、三モデルの充足を完成する。完全署名末尾に各条件を固定した |
| RV-external中1・第12.2節の.05 | external_typedのOutcome.Carrier化、E_External/E_ExternalErr/stepを同時改訂。carrierから元の篩付き型付けと違反時のerrを構成 | L60は三モデルで三条件を充足し、R50/L70は実装・表層・交換を照合する |
| .04軽1 | Ty.carrierとOutcome.Carrierを区別した。受信の接続にTy.carrierは使わない | L30でrepresented等の利用箇所を確認し、使わなければ削除する（RV-L00b.05軽4） |
| .04軽5 | 閉じた型付き値の実観測→Tel.argumentsEnv→termBindを証明。snapshotのnoneと根の全域化を境界で分けた | この作業への残りなし。全捕捉・置換での利用は既定のL20 |
| .04の三値の申し送り | some trueだけを受信検査から遷移へ接続し、強いKleeneの評価を保つ | R50/L70は左右対称なAnd/OrとNotのunknown保存を実装・交換で照合する |
| O016・当該L作業 | 776宣言の公理依存と既定buildを実行し、許可一覧内 | L00b末以降の各段とL70のA-Lは予定どおり残る |

L00b.11への申し送りは、既定importに追加した3モジュール、改訂したE_External/E_ExternalErrとexternal_typed、元の型を保つcarrierの使い分けである。HasTypeの構成子とTy.LeQの規則は増やしていない。新しい外部の葉を正規化・逆転へ写すときは、受信前のcarrierと受信後のHasTypeVを混同しない。正規化の平坦化/true消去、F3、dataの変性、不変位置のnorm後等号はこの作業では着手していない。

## 外側の時間

開始時の記録は2026-10-31 09:20:08 UTCである。結果の文書とレビュー依頼までを含む09:34:18 UTCまでの外側の時間は約14分10秒（能動時間を分離していない上限）である。上表の最終4検査の待ちは計7.522秒で、途中の局所ビルド・再確認の待ちは分離していない。1〜3時間の見込みの上端や停止条件の6時間には達していない。独立レビュー・設計者の回答待ちは今回の時間に含めない。

初回実装の最終の文書の照合で、検査時の15入力のSHA-256が一致すること、レビュー依頼が当時の新規ファイルを全て列挙すること、改造内の全ファイルが100 KB以下であること、今回の文書の相対リンクが存在することを確認した。その後、以下のレビュー対応で本番のLeanと境界入力を変更し、別の記録で再検査した。

## レビューの所見の対応

2026-10-31。[群末レビュー](../reviews/RV-L00b.05.md)は可（重なし・中なし・軽6）であった。取りまとめの指定に従い、軽1・軽4をこの再開で直し、軽2・軽3・軽5・軽6を後続の義務に記録した。レビュー記録とrv-*は変更していない。

| 所見 | 対応と証拠 | 残り・送り先 |
|---|---|---|
| 軽1 | boundary.leanのDependentに、引数xを読む結果型の宣言、ExternalArgs、受信の成功・拒否・生のerrのStepとstepを追加した。x=5をTel.argumentsEnvで結果型へ代入し、5 ≤ rで7を受理、3を拒否する。生のerrは理由の文字列trapを保つ。two_instantiateは二つの実引数の順序を検査する | この所見への残りなし。全状態の一般の保存は既定のL20 |
| 軽2 | signatures.mdの「群末レビューの対応と残りの義務」に一行を追加した。EqProof.checkSortedは証明書の検査から呼ばれず、substituteの項と途中の述語のsortを検査していないことを明記した | L30。意味上の等号へ拡張するときに、sort・文脈・途中の述語の検査を接続する |
| 軽3 | 同じ表に一行を追加した。Term/Predの等号は古典的で、Certificate.check/EqProof.checkの比較はLeanの中で計算できない。現在の境界ではsimpで等号を証明している | L30/R20。Rustとの差分試験にLeanの実行を使うかを判断し、使うなら構成的な等号を用意する |
| 軽4 | ExternalConnectionにBuiltins.ExternalAssumptions.received_value/receive_no_exitを置いた。前者は受信のvalを反転し、三条件・WF・lookup・ExternalArgs・生の応答から元の型付け・Ground・任意のσでのAdequateを返す。後者は受信後のexitを排除する。Ty.carrierの「実際の使用」の説明を本文と義務の表で修正した | Ty.sort_carrier/represented等はL30で利用を確認し、使わなければ削除する。external_adequateにはreceived_valueからの呼び手ができた |
| 軽5 | signatures.mdに一行を追加し、既存のargumentsEnv_observationが根のvar 0の一段だけを扱うことを明記した | L20。Sortedな述語と型付き実引数で観測する項のtermBind?の成功とgetDの非到達を一般の補題にする |
| 軽6 | 同じ表に一行を追加し、lengthNonnegativeがclosedTrueを要求する閉じた代表であることを明記した | L30。measure_nonnegativeを使う開いた葉を置き、PreparedLeafの検査とstableの言明を改める |

追加した一般の補題は、レビューのgeneral_val/general_no_exitに対応する。既存の三条件と受信の結果を前提とし、受信前の応答がvalであることや結論の型付けを仮定しない。主定理の前提・結論、外部の条件、遷移の規則、提供範囲は変えていない。補題の完全な署名は[r2-axioms.log](r2-axioms.log)の先頭にある。

test-auditの作成時の関門では、追加する境界を「型付き実引数による結果型の具体化から受信後の選択まで」とした。既存の引数なしの例ではTel.argumentsEnvを一度も通らず、生のerrも通らなかった。引数の値を無視する退行、拒否したvalを返す退行、生のerrの理由を置き換える退行をそれぞれこの境界で検出する。外部の表は結果だけを返し、検査を代行していない。本番の差し込み口は追加していない。公開の境界定理は39から53へ増えた（追加14）。

最終検査は次のとおりである。初回のログ・集計・入力ハッシュはその実行時点の証拠として保ち、今回の結果はr2-*へ分けた。

| 検査 | 終了 | 外側の時間 | 証拠 |
|---|---:|---:|---|
| formal/で既定のlake build。旧体系・並置体系・全既定ターゲット | 0 | 0.782秒 | [r2-build.log](r2-build.log)。増分697 jobs。既存Intervalのlint等は残るが、今回変更したLeanの警告はない |
| lake env lean -M 12288で境界入力 | 0 | 1.503秒 | [r2-boundary.log](r2-boundary.log)。既存の39定理と追加14定理を検査し、追加した名前空間の生成宣言を含む41宣言の公理依存も出力した |
| 同じ入口でExternalConnectionの全宣言と追加2名の署名 | 0 | 0.778秒 | [r2-axioms.log](r2-axioms.log)。同モジュールの生成宣言を含む8宣言を照合した |

公理依存は計49宣言で、propext・Quot.sound・Classical.choiceだけである。sorryAxと未承認公理はない。[対象名](r2-axiom-targets.txt)、[集計](r2-axioms-summary.json)、[実行記録](r2-verification.json)、[8入力のSHA-256](r2-inputs-sha256.json)、[再実行の台本](r2-verify.py)を保存した。既定ビルドはlakefileの-M 12288、単独のLeanも-M 12288を明示した。今回の生のログはすべて100 KB以下であり、改造内に置いた。

今回の変更はExternalConnection.lean、boundary.lean、signatures.md、results.mdである。新規の証拠はr2-axioms.lean、r2-verify.py、r2-inputs-sha256.json、r2-verification.json、r2-build.log、r2-boundary.log、r2-axioms.log、r2-axioms-summary.json、r2-axiom-targets.txtの9ファイルである。レビュー依頼を含む既存のレビュー記録、rv-*、plan.md、処理系のRust、現行設計書は変更していない。gitの操作とworkは実行せず、L00b.11には進んでいない。

局所確認ではdep_step_rejectの書き換えだけで結論が閉じており、その後に置いたrflが「No goals to be solved」となった。余分なrflを除き、上表の最終検査で再確認した。再開の開始記録は09:44:45 UTC、文書を含む外側の時間は約5分である。最終検査の待ちは計3.063秒、途中の確認の待ちは能動時間と分離していない。RSSは未取得（計画上の非採取）である。

## 作業末の work

取りまとめが sandbox の外で実行した。基準は `0f771fa1789728aa00dc35b1eb6db9ac6345833e`。Refinement の生成物を消してから `/usr/bin/time -l scripts/check.sh --level work --base 0f771fa1789728aa00dc35b1eb6db9ac6345833e` を実行した。選ばれたのは `formal_build` だけで、終了0、外側の時間 63.61 秒、最大常駐量 1159430144 B である。
