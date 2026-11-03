# レビュー申し送りの一件ずつの照合

2026-11-03、L30.75。担当の照合である。元レビューへの書込みや plan の担当変更は行わない。既存の処置は各群の results.md の再開と、レビュー末尾の取りまとめの追記を優先する。下表の「済」は L30 の担当分の処置であり、改造全体の閉鎖ではない。「転記」は理由を伴う後段への受渡しである。

集計は **63行＝済52・転記11**。初期の申し送り14行と、群のレビュー49行を別々に数えた。同じ内容が別の出どころに現れる場合も、出どころの照合行として保持する。件数を新しい課題の数とはしない。RV-L30.lの所見の処置はreview-response.mdへ別に記録し、過去の群の63行の集計へ加えない。

## 詳細化時からの14行

出どころの本文は [l30/results.md「レビュー申し送りの照合」](../results.md#レビュー申し送りの照合)。

| 出どころ | 判定 | 処置・本番の証拠・後段へ残す理由 |
|---|---|---|
| RV-L00b.05 軽2 | 済 | EqProof.checkIn/substituteIn、Certificate.AdmissibleIn、PreparedLeaf.checkInでsort・Declared・中間項を照合。E/G/Kの結果。旧checkSortedだけを根拠にしない |
| RV-L00b.05 軽3、l00b.15 比較 | 転記 | TermStructuralEqとrawの再生はB/Mで済。型・行の関数を含む全表は非計算的なため、R50が有限な交換表と上層の証拠を照合する |
| RV-L00b.05 軽4 | 済 | J/Kのmeasure・正常応答・型付き値の三条件の実読者。全モデルの外部条件の充足はL60の実表を必要とする |
| RV-L00b.05 軽6 | 済 | measure_nonnegative_atとmeasure_stable/field_measure_stable。開いた述語の不変を仮定せず、旧の閉じたstableを保持 |
| RV-L00b.04 鍵の等値 | 転記 | Key.code_of_shape/equal_of_shapesとDecimalの数の一致はJで済。型付き鍵からKeyShape/ClosedSlotsを供給するのは具体のBを持つL40、実表はR40、比較はR50 |
| RV-L00b.14b・paths apart | 済 | B04→apart_entails/false_sideで有限規則から相異を供給。比較の標準契約はL40、ソースからの構成はL70/R10b |
| RV-L00b.14c Reference.updateの引数名 | 転記 | L70/R10b/R50。Fnの引数名とRustのlambda受理の比較であり、線形証明書の規則ではない。未再現の不一致を確定した誤りとしない |
| RV-L00b.14d forceの共変性・格納・観測 | 転記 | L20の保存・closeValとJのsnapshotを継承。実標準表の結果の共変はL40、評価途中・別タスク待機/取消はL70/R30/R50。R20の探索に混ぜない |
| RV-L00b.14e・15 軽6 節・resume・used・解放 | 転記 | L20の一般葉とKの論理接続を継承。実表の入力/応答/効果はL40/L60、Rustの操作・解放はR30/R50。既済みの状態葉を再証明しない |
| RV-L00b.13 篩付きPairを持つRequestのAt | 転記 | L50/R30/R50。groundTyの修正を継承するが、型付き要求・Atの実行一致は未比較。算術の有限規則からは結論できない |
| RV-L00b.15 軽5 短絡 | 転記 | Kの真偽の含意は済。L70/R10bで脱糖と同じ型・効果へ接続する。Refinement.Compに独立の短絡構文を追加していない |
| RV-L10.v/RV-L10 sort反映 | 済 | EqCertificateTypingとFieldObservationExamplesが同じPのVarianceValidを供給。ソースmetadataの収集はL70/R10b/R50 |
| RV-L20-plan 並行・共有定義 | 済 | L20の受入済み基準を引き継ぎ、J30-2の変更はH/Iの一括切替。今回共有定義の再切替なし |
| L20群I/J/N O046/O079/O138/O143 | 済 | Kの長さ・Boolean、既定importのpattern_length_relationへの合成。実APIはL40、ソースの静的合成はL70/R10b、比較はR50 |

## 群 A〜K の49行

レビュー本文は [A](../../reviews/RV-L30.a.md)・[B/C](../../reviews/RV-L30.b.md)・[D/E](../../reviews/RV-L30.d.md)・[F/G](../../reviews/RV-L30.f.md)・[H/I](../../reviews/RV-L30.h.md)・[J/K](../../reviews/RV-L30.j.md)。処置の証拠は各群の results.md の「再開1」と本番の宣言である。

| 出どころ | 判定 | 処置・本番の証拠・後段へ残す理由 |
|---|---|---|
| A 軽1 | 済 | Const.NumericRepresented.carrierFactsとTypedMeaning.const_meaningの入力を一致。ConstOK.representedから供給 |
| A 軽2 | 済 | LogicKernelExamples.captured_integer8が捕捉の四事実を各々導出。H/Iの切替後も既定ビルドに残る |
| A 軽3 | 済 | a/comparison.mdへ検査器水準のcheckedAt代表を保存。B/C/Gが同じν上の全規則を証明 |
| A 軽4 | 済 | EqualityModeの独立とCertificateKernelBindの下層配置。Bの実物と依存順が一致 |
| A 軽5 | 済 | detailの重複控除後79単位・2,825〜5,515分を継承。補題の二重実装なし。時間の積上げは段末に記す |
| A 軽6 | 済 | EqProofは9構成子、alias表なし。reflで展開済みの実像を照合。ソース別名の実像生成はL70/R10b |
| A 軽7 | 済 | 01-12を実際の定義へ一致させた。現在はH/Iで切替済みの三条件の意味を記す |
| A 軽8 | 済 | a/inventoryとH/Iの9ファイル・全直接/間接捕捉・16読者の処分。既定ビルドで簡約依存の読者も確認 |
| A 軽9 | 済 | a/resultsのO020をAでは該当なしと訂正。捨てる規則の証拠はD/G |
| A 情報 U03 | 済 | READMEの2026-11-03の決定を継承し、CoefficientModel/StepAccountingへ反映 |
| B 軽1 | 済 | rawの整数射影とHasSortの性質を区分。E/G/KのcheckInが実際のsort・宣言を検査 |
| B 軽2 | 済 | Linear.toPred_sound(_at)とlinearTerm_integerAsから列長前提を除去。D/Gが再帰を追加せず利用 |
| B 軽3 | 済 | CertificateSyntaxの未使用EqualityMode importを削除。実読者はEqProofSyntax等 |
| B 軽4 | 済 | 宣言前提を返すだけの連言を除去、De Morganの実計算を追加。四つの像は健全性の適用と明記 |
| B 軽5 | 済 | O021のB/C担当外を訂正。Nが見込みと時間の精度を分けて集約 |
| B 情報 時間 | 済 | 共通区間の重複と読取りの未採取を保持。一件当たりの能動時間へ外挿しない |
| D 軽1 | 済 | RefutationExamplesのsplitOddLeft/Rightが分枝で追加した事実を実際に使用。片枝改竄・closeAtomの逆位置を拒否 |
| D 軽2 | 済 | Boolean中間のAdmissibleInの否定とΦの不適格を別々に記録。中間だけの拒否を誤称しない |
| D 軽3 | 済 | PreparedLeafのarguments/referencesの既定値を除去。四欄を明示 |
| D 軽4 | 済 | 未使用importを整理し、本番の読者を修正。後のGの上層接続は実際の使用として別記 |
| D 軽5 | 済 | LinearStep.soundの前提を現在のfactsの全線形葉のHoldsと写しへ明記 |
| D 情報1 | 済 | Gのrefute_sound_atのderiveでstepとnextを明示し、一回の帰納を閉じた |
| D 情報2 | 転記 | R50。rawだけを実行比較し、非計算的なcheckInのsort・宣言は有限表と証明で照合する |
| D 情報3 | 済 | 匿名exampleは定数の一覧に現れないことを監査資料に明記。既定ビルドのsorry拒否と禁止構文の点検を併用 |
| D 情報4 | 済 | RefutationSyntaxがBuiltinLogicをimportしてbuiltinを接続。写しの「builtinは拒否する」をGで更新 |
| F 中1 | 済 | 取りまとめの案(a)を継承。B08はq→q、参照形はuse。観測成功はKのVal.toTerm_observed/typed_observationが供給 |
| F 軽1 | 済 | substituteのgoal=p.open uと子のp.open tの検査を01-12へ反映 |
| F 軽2 | 済 | 近い改竄6件、等しい/逆端点48件を追加。候補から作るregistryの成功を独立の退行検査と数えない |
| F 軽3 | 済 | 本番の#evalを除去。Mは別のreplay.leanだけで実行再生する |
| F 情報1 | 済 | Kのkeys_checked_allとrefute_keys_sameが入れ子と平坦化後の実際の鍵列を覆う。推測でsort検査を省かない |
| F 情報2 | 済 | Certificate.Legacyは削除前の六規則の写しへの保存。旧Release全域の同値と呼ばない |
| F 情報3 | 済 | 下層CertificateKernelはRefinementのLogic/Le/Typing/ValueMeaning/Captureへ逆依存しない。段末で再点検 |
| F 情報4 | 済 | floatZeroの符号は比較相手の符号。±0の数の等号の節を保持し、bitsの同一視へ拡張しない |
| H 軽1 | 済 | 主要16読者の本体を旧名へ集約。h/resume1-aliases.jsonの処分と既定ビルドを継承 |
| H 軽2 | 済 | CarrierFactsExamples.valid/closed_integer8_meaning/no_typed_1000で同じP・Bと主定理の入口を使用 |
| H 軽3 | 済 | 「七整数型とByte」へ訂正。O127は変更なしの保持とし、新しい包含の証拠はF/K |
| H 情報1 | 済 | Kのopen_refinement_meaningが開いたΓの型域の真も供給。L40の新しい読者も同じ前提を必要とする |
| H 情報2 | 済 | Kのopen_refinement_bindが既存target_carrier_from_pathを使用。算術の像の型域を独立の仮定にしない |
| H 情報3 | 済 | Character/Floatの芯の事実は空列。Char.valid・bitsの有限規則から対応を供給し、S01を拡張しない |
| H 情報4 | 済 | Hの最終workと単独Leanによる内容の一致を継承。更新時刻だけから再ビルドの成否を推定しない |
| H 情報5 | 済 | 旧事実列と現行事実列の対照という境界を維持。旧LeQ全域の不可能性を証明したと書かない |
| J 中1 | 済 | 再開1のrefute_keys_sameとAllKeysCheckedの実鍵列、consume/cases下の例。再レビュー可を継承 |
| J 軽1 | 済 | 別名代表は構文の一致へ限定し、open_field_stableで開いた受け手の実際の置換を使用 |
| J 軽2 | 済 | arguments_only_rejectedが引数だけの拒否を切り分ける。元のBoolean例の注釈も訂正 |
| J 軽3 | 転記 | KeyShape/ClosedSlotsの供給をL40の具体のB・実標準表へ明記。satBと構造の並置を証明済みの橋と呼ばない |
| J 軽4 | 済 | byte_and_u16_representedへ改名。Byteと同じ数のUInt16の表現可能性だけを結論し、変換演算はL40 |
| J 情報1 | 済 | 長さ→非空→網羅性→pattern_length_relationの合成を既定PreparedLeafExamplesへ移動 |
| J 情報2 | 転記 | L40。前提を実際に読む長さの証明書をTy.LeQへ通し、p::assumptionsの順と形を検証する。Kのopen_refinementは無条件非負の葉 |
| J 情報3 | 転記 | L40。B04からのEntailsをPathConditionsの枝の型付けへ供給する。L30は有限の含意まで、ソース合成はL70/R10b |

後段へ転記する11行には、L40・L50・L60・L70・R10b・R20以外のR30/R40/R50が重なって現れる。R20へは別紙 [r20-contract.md](r20-contract.md) を渡す。全σ・外部三モデル・標準本体・VMの比較をR20の探索と一括りにしない。
