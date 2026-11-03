# 群 J・K の実装結果

2026-11-03。指定ブランチ `m014/l30.j`、B_WORK `65677215c04e632a397126f97fbb442ec6b0108c`。L30.55〜.66 の担当分を実装した。群 A〜I の署名、案(ii) checkedAt、J30-2 の切替後の Ty.assume・ValueMeaning、U03 の決定を引き継いだ。Git コマンドの直接実行・状態変更、plan・detail・README・レビュー記録・Rust 処理系・旧 Release の変更は行っていない。担当の自己点検であり、独立レビューと設計者の受け入れは取りまとめが行う。

## 完了条件の照合

| 単位 | 担当分の判定と証拠 |
|---|---|
| L30.55 | 完了。既存の measure_machine_exact・measure_stable を保持。Observation.measure_exact が全7種の実定義を同定し、ObservationContractsExamples.measures_machine_exact が「é」の2 byte/1文字、None を持つ List、Bytes、重複した Decimal 鍵の Map、Set、文字符号へ適用する。非負性に機械幅の上限を加えていない |
| L30.56 | 完了。field_measure_stable、FieldObservationExamples の二段の欄連鎖・上層の葉・検証済みの同じ P、None を保持する closeVal_observation の実読者。全sortの一般の情報の順序は既存 bind_observe_info を利用し、開いた述語の不変等号を要求しない |
| L30.57 | 完了。NumericContracts.integer_result/binary_normal/neg_normal。既存 checkedAdd/Sub/Mul/Neg_normal_iff から数の一致を取り出し、七幅の定数・toTerm?・NumericRepresented へ接続。七幅×三演算の実正常結果、符号付き四幅を受ける負号、Byte255と同じ数のUnsignedInteger16の表現可能性、Integer8のあふれを対照にした |
| L30.58 | 完了。compare_exact/float_class_exact/decimal_result が実観測・bits・ConstOK を読む。30比較・48境界・12分類の本番照合は既定の BuiltinLogicExamples を維持し、Character の実比較、NaN・負のゼロ、実 Decimal の型域の読者を置いた。Decimal の算術や Float の丸めを線形整数へ拡大しない |
| L30.59 | 完了。Observation.KeyShape/KeySlots/KeyPairs の相互帰納で成功11形から鍵コードを構成。Key.code_of_shape/equal_of_shapes が閉じた実観測と既存 Key.equal を結ぶ。Decimal の正準化の数の保存とコード一致時の数の等値を証明。元の鍵と後の値を保つ重複縮約の具体例、実制約表の成功、KeyShapeの証拠を別々に示した。型付きの鍵の値からのKeyShape・ClosedSlotsの供給は、具体のBと実標準表を持つL40が受け持つ |
| L30.60 | 完了。Key.map_measure/set_measure が既存 normalizeMap_length/normalizeSet_length を使用。Map のsizeは値なしでも成功し、Map自体の鍵化は値も必要という対照、Set の重複縮約、対象外3形とNoneの拒否を置いた。実標準表・δの境界は下記に明示 |
| L30.61 | 完了。PreparedLeafSyntax の四欄をそのまま使用。checkIn は Γ.facts++Φ を読む Certificate.leaf の上層と全引数の AdmissibleIn を検査する。任意Propや証明を欄へ加えていない |
| L30.62 | 完了。entailsIn/bind_entails は固定署名どおり。HasTypeVQ.observed_measure が既存 represented と実観測から三条件を構成する。閉じた旧入口は保持。NormalResultLeaves が正常算術から上層の葉と任意νの導出を作り、実 Integer8 の加算へ適用する |
| L30.63 | 完了。lengthCertificate が len(l)=n と 0<n から同じ l の非空を導く。length_positive/nonempty_from_length は任意の Γ/Φ で既存 nonempty_from_entails へ渡す。一要素 Unit List の実型付けと網羅性、別の List へ移せない実モデルの拒否を置いた。既存 pattern_length_relation との合成は再開1でPreparedLeafExamplesの既定ビルドの例へ移した |
| L30.64 | 完了。checked_refinement の固定署名を既存 LeQ.refine で実装。open_refinement_bind は型・行・範囲・算術の値像を持つ既存 OpenSubstitution.transport を使う。型域の像も元の経路の等式から供給する。open_refinement_meaning は開いた Γ の型域と経路を値7の実モデルで満たす |
| L30.65 | 完了。Boolean の上層で検査した B04 から偽側の Not、And、Or、bind を導く。偽 guard から真側を導けない実モデルを置いた。同じ閉じた項のmeasureの構造合同の反射と二段の正常観測を使い、到達しない右辺の事実を追加しない |
| L30.66 | 完了。下記16行で観測成功の供給元を照合。sameObservation の変更は不要と判定。CertificateKeys の一般の包含によって、入れ子の鍵の検査も群 K で閉じた。12種類100分岐の既存の証拠・拒否との対応を下記に記した |

公開入口は既定の import に含め、具体の適用例または本番の読者を持つ。新公理・sorry・native_decide・既定 import の除外はない。主な十移送、型付け規則、L20 の捕捉、群 H・I の構成への前提追加は0件である。開始時の既存 Lean 684ファイルのうち、変更は MeasureContracts と既定 import の2ファイルだけで、残る682ファイルはバイト単位で同じである。旧 Release の110ファイルも同じである。変更範囲と入力は [inputs.json](inputs.json) に記した。

## 本番から導いた三条件と実読者

| 事実 | machine_exact | stable | represented と実読者 |
|---|---|---|---|
| 七measure | Observation.measure_exact の本番の長さ・符号と既存 measure_machine_exact。部分観測の成功から全域の解釈も同じ整数になる | 既存 measure_stable と bind_observe_info。変数の OptionInfoLE と元の正常結果を読む | HasTypeVQ.observed_measure が既存 HasTypeVQ.represented を実際に呼び、入力sortと閉性を供給。PreparedSortExamples の実 String、全7種の正常観測、欄の葉が読む |
| 七整数と負号 | 既存 checked*_normal_iff を NumericContracts.binary_normal/neg_normal で使用し、結果の数を同定 | 正常結果の toTerm? は同じ閉じた整数。NormalResultLeaves.binary_entails_at が同じ葉の導出を Entails.bind で任意νへ写す | IntegerValue.toConst・embedConst を幅ごとに分解し NumericRepresented と toTerm? を得る。NormalResultLeaves.binary_leaf が上層検査と結び、実 Integer8 の 2+3=5 で読む。6を入れた葉は拒否 |
| Byte・Decimal・比較と分類 | byte_and_u16_represented、decimal_result、compare_exact、float_class_exact は本番の範囲・係数scale・bits・Charを読む | 閉じた定数の同じ像と、群 F の任意νでの原子の健全性を利用 | decimal_result は ConstOK.represented と NumericRepresented.carrierFacts を呼ぶ。Byte255と同じ数のUnsignedInteger16がともに表現可能であることを示す。変換の演算との一致はL40が受け持つ。Fの30比較・12分類・48境界はそのまま既定ビルドへ含む |
| Map・Set の鍵と大きさ | 閉じた項の実観測と KeyShape から keyCode? の成功を作る。Key.equal_of_shapes は得たコードを既存の鍵の等値の定義へ渡す。Key.map_measure/set_measure は実縮約後の長さを同定 | 既存 Observation.InfoLE.keyCode・SlotsInfoLE と measure_stable。整数射影の等号を snapshot の等号へ使わない | 構造の11形を共有の相互帰納で処理。Decimal の重複、元の鍵/後の値、値なしMapのsize、Mapの鍵化の失敗を対照にする。実制約表 satB の Map[Integer8,List[Decimal]] の成功と構造の証拠は別々に示しており、両者を結ぶ補題はない。型付きの鍵の値からのKeyShape・ClosedSlotsの供給は、具体のBと実標準表を持つL40が受け持つ |

Key.equal は閉じた鍵の正準コードの等値を返す本番の定義である。equal_of_shapes は、その成功を仮定する既存 equal_sound と逆向きに、実観測と有限構造から成功を構成する。Decimal は同じコードから交差積の数の等号まで別に証明した。実行時の任意の抽象 B.delta の等値処理と同じ、という前提は置いていない。B.sat が真でも鍵の観測が欠ける既存の型付き Map は維持している。型付き Map 全件の measure 成功を主張しない。

正常算術の葉は、既存 Interval の正常応答から構成する。型保存の条件だけから任意の抽象 B.delta の演算結果を同定しない。中間Stopを後の演算で正常結果へ変える補題もない。実δ・解決済み標準署名と実引数・正常応答、Listのmap/reverse/append/filter・Map/Set・record/decodeの標準本体との合成は L40、対象とσ・起点の解決は L50、三モデルの全欄は L60、Rustとの有限比較は R50 が受け持つ。

## PreparedLeaf と L40 へ渡す署名

完全署名は [signatures.md](signatures.md) を正とする。群 A の S05 四入口の量化・引数・結論は変更していない。再開1では補助byte_representedをbyte_and_u16_representedへ改名し、AllKeysCheckedのrefuteの条件を強めた。S05の四入口の署名は維持する。

| 入口 | 入力と結論、供給元 |
|---|---|
| PreparedLeaf.checkIn / entailsIn | P・C・Γ・Φと有限の葉の検査成功から Entails (Γ.facts++Φ) l.predicate。Certificate.checkIn は同じPのVarianceValid、述語と全仮定のsort・宣言、途中の適格性、鍵を検査する。checkInは引数列の全項もあるsortでのAdmissibleInと照合する |
| PreparedLeaf.bind_entails | 同じ検査成功と任意νから、仮定列と結論を同じ predBind ν で写した導出。元の証明書を再構成しない |
| checked_refinement | 基底の LeQ、自己のある p/q のSorted、p::assumptions Γ Φ a から q への CertificateKernel.check の成功から、本番の refined a p ≤ refined b q を構成 |
| HasTypeVQ.observed_measure | 閉じた型付き値、carrierの入力sort、値の実観測、正常なObservation.measureから、toTerm?・sort・閉性、同じ整数の部分観測/解釈・非負、OptionInfoLEに沿った置換後の対応を同時に構成 |
| NumericContracts.binary_normal / neg_normal | 七幅の実正常応答から数の一致と結果の表現可能性・toTerm?。負号は既存のsigned条件。加減算・乗算は既存 WidthBinary の該当三形だけ |
| NormalResultLeaves.binary_leaf / binary_entails_at | 同じPのVarianceValid、上記の実正常応答から、閉じた葉のcheckIn成功と任意νの構文の導出。探索や正常応答の存在は仮定・結論に含めない |
| Key.code_of_shape / equal_of_shapes / map_measure / set_measure | 閉じた実観測と有限の鍵の構造、または閉じたスロットと実縮約の成功から、鍵の等値の成功・実サイズを構成。型やsatから観測成功を推測しない |
| Certificate.checkIn_all_keys | 上層の検査成功から、入れ子の全位置の鍵のsort・宣言の検査へ進む。追加の信頼条件を呼び手へ渡さない |

open_refinement_bind は既存 OpenSubstitution.θ の篩付きの型像、複数原子とFailを持つ行像、範囲像、var2+1の値像を同時に含む。Transport.facts の型域の像は既存の target_carrier_from_path が等式から導く。PreparedLeafの成功のために独立の型域の仮定を追加していない。open_refinement_meaning は Γ の型域と経路の全事実が値7のモデルで真であることを示し、既存 valueMeaning_sub を呼ぶ。開いた Γ で型域の真が必要であることを省略しない。

PreparedLeafExamples の末尾の既定ビルドの例は、閉じた同じListの元の型付けから nonempty_from_length で得た型付けを inhabits_of_typed と網羅性へ渡し、その照合成功を既存 pattern_length_relation へ合成する。別の「閉じた非空型の型付け」の前提は必要ない。既存の網羅性が読む閉じた意味の入口の条件に合わせ、NoFail は Benitoite.Release.Qempty と明示する。handoff.lean はこの既定モジュールをimportするだけとし、重複する例を残さない。生の証明書のソースからの静的合成は L70/R10b に残る。

## 全16 sort の観測成功の照合と sameObservation

全行で既存 HasTypeVQ.represented が toTerm?・HasSort []・閉性を供給し、新規 Val.toTerm_observed が実際の外側の observe の成功と同じsortを供給する。PreparedSortExamples.typed_observation は両者と observe_sound を合成する。observations_16 は16個の具体の値のsnapshotで、内部のNoneを保った外側の観測成功を示す表であり、表だけを全値の型付けの証拠にはしない。

| sort | 実際に読む構成子と観測成功の供給元 | 原子・measure・残る境界 |
|---|---|---|
| integer | 七整数/ByteのConst→integer、represented、Val.toTerm_observed。NumericContractsで幅の値域を供給 | eq/le/ltと算術、measureの出力。長さの機械上限は導かない |
| character | Const.character→Observation.character、同じ型付き入口 | characterCodeはc.toNat。B10/B11と六比較、Char.validの既存証拠 |
| float64 | Const.float64→Observation.float64、bitsを保存 | 52/11の比較・分類。NaNや±0を全順序やビットの同一へ読み替えない |
| float32 | Const.float32→Observation.float32、bitsを保存 | 23/8の比較・分類。同じ幅の既存の有限規則を使う |
| decimal | Const.decimal→Observation.decimal、ConstOK.represented/decimal_result | 係数96bits/scale28の型域、交差積の比較、decimalNormalの数の保存 |
| boolean | Const.boolean→Observation.boolean、同じ型付き入口 | B04を上層で検査しfalse_sideを導く。比較はeq/ne、And/Or/Notは論理規則 |
| unit | Const.unit→Observation.unitValue、同じ型付き入口 | eq/neの既存二値。数値の射影へ転用しない |
| string | Const.string→Observation.string、同じ型付き入口 | UTF-8二byte/一文字の実例、二measure、charactersInの受理/拒否とB06 |
| list | Val.list→listValue(toTermSlots)、外側の観測成功 | 内部Noneも長さに数える。len(l)=nかつn>0の同じlへの証明書。標準本体はL40 |
| bytes | Val.bytesV→bytesValue、外側の観測成功 | bytesLengthは全byte≤255の正常分だけ。Byteの値域と区別 |
| map | Val.mapV→mapValue、外側の観測成功 | mapSizeの成功は別に鍵の構造から構成。値なしも許す。鍵化は値も要求 |
| set | Val.setV→setValue、外側の観測成功 | setSizeは鍵の正常コードと重複縮約を別に検査。Noneは成功でない |
| data | Val.con/atError→dataValue、外側の観測成功 | constructorIsと宣言した欄。欄連鎖は同じPのVarianceValidとDeclaredを供給。decode等はL40 |
| target path | checked/checkedRequest/checkedAt→targetValue、target.kindと同じsort | memberは同じsnapshotを読む。絶対Topの成功とcwd未解決のnoneを対照。全σと起点はL50 |
| target host | 同じ保持対象の入口→targetValue、kind=host | 外側の観測成功とmemberReadyの解決成功は別。全σ・具体化はL50 |
| target endpoint | 同じ保持対象の入口→targetValue、kind=endpoint | 型付けが検査する要求・保持端点と同じ観測。memberの全接続はL50 |

sameObservation は変更不要である。観測の成功は上記の型付き値・値の構造・実観測の補題が供給し、原子の同じ像への移送は、structuralのEqProofと任意のPredを受ける既存 EqProof.substitute_entails/substitute_sound_at が供給する。PreparedSortExamplesに任意の原子への適用も置いた。失敗する観測を真へ変える用途や、異なる構造を意味の上で同一視する新規則は必要ない。B08の16分岐は同じ項の代表の原子qについてのq→q、参照形はuseと同じという既存の説明を保つ。O015の観測成功をB08の分岐数だけで完了としていない。

## 12種類100分岐と受理・拒否の対応

| 種類 | 既存の証拠と今回の接続・拒否 |
|---|---|
| B01 closed | closedTrue_sound_atと旧入口を保持。NormalResultLeavesで正常演算から葉を構成し、結果5を6に改竄すると拒否 |
| B02 lengthNonnegative | 旧の閉じたList長の成功を保持。全7measureの実読者と非空の入口へ接続 |
| B03 measureNonnegative | 既存7場合を再実装しない。上層の長さ・不変欄の葉と、正常観測/不正Bytes/未観測Map/Setの対照 |
| B04 booleanApart | 既存二向き。apart_checked→false_side、真側を導けない実モデル、述語と引数の両方を整数に変えた葉の述語のsortによる拒否、述語を変えない別の葉の引数の照合だけによる拒否 |
| B05 compareComplement | 既存22分岐とFloat順序の反転の拒否を保持。実比較の接続はcompare_exact |
| B06 charactersSubset | 既存の包含と近い境界改竄の拒否を保持。実StringのcharactersInの成功/偽を照合 |
| B07 constructorApart | 既存の異なる構成子の証拠と同名への改竄の拒否を保持。dataの観測と宣言した欄の入口を照合 |
| B08 sameObservation | 既存16分岐を保持。意味の追加はない。全sortの成功は上記の別の証拠、任意の原子の移送は既存のstructural substitute |
| B09 scalarOrder | 既存30分岐、誤った推移の向きと等号専用sortへの順序則の拒否を保持 |
| B10 characterCodeRange | 既存一分岐とCharの実範囲。全measureのcharacterCodeの実例と、Character型付き観測の読者 |
| B11 characterCompare | 既存六分岐。実compare_exactとcharacterCodeの実結果へ接続 |
| B12 floatCompareClass | 既存12分岐と12分類。実bitsをfloat_class_exactで読む。非線形算術・丸めの保証を追加しない |

100分岐の件数と本番の定義の健全性は、既定importの BuiltinLogicExamples.registry_100、candidates_sound_at/raw_sound_at と全Certificateの健全性を保持して使用する。候補自身から作るregistryのraw成功を独立の退行検査とは数えない。今回の新しい対照は、近い数値改竄、Booleanのsort、不正byte、Noneの鍵、Mapのsizeと鍵化の違い、別のList、偽guardである。

## 入れ子の鍵と既存の型域の申し送り

入れ子の鍵について、consume・cases・discard・substitute の位置の包含に加え、再開1でrefuteが実際に使う平坦化した仮定の鍵列を閉じた。CertificateKeys.ofConjuncts_keysとconjuncts_keysは、連言を平坦化する前後で整数の鍵が変わらないことを示す。Certificate.refute_keys_sameは、refuteがPred.ofConjuncts (Φ.flatMap Pred.conjuncts)から作る鍵列と、上層のPred.ofConjuncts Φから作る鍵列のリストの等号である。AllKeysCheckedのrefuteの腕は前者の実際の鍵列の検査を要求し、keys_checked_allのrefuteの場合はこの等号を使用する。refuteの内部では、その位置で得た同じ鍵列を使い続ける。checkIn_all_keysは上層の成功から全位置の実際の鍵の検査を得る。既存typed_twice、外側のdiscard、consume・casesの下のrefuteの具体例を既定ビルドで読む。Sortedだけから鍵検査が不要になる、という未証明の推測は使っていない。

RV-L30.h情報1・2は上記open_refinement_meaning/open_refinement_bindで処置した。開いたΓの型域の真を明示して既存valueMeaning_subへ渡し、算術の値像の型域は経路からの既存証明で供給した。主要十移送やSubstOk/CaptureOkへの新前提はない。

## 追加した宣言と既定の読者

| モジュール | 内容と本番の読者 |
|---|---|
| MeasureContracts（既存に追記） | measure_exact、observeSlots_length、field_measure_stable。ObservationContractsExamples・PreparedLeaf・FieldObservationExamples |
| NumericContracts | integer_result、binary_normal、neg_normal、rejected_not_normal、byte_and_u16_represented、compare_exact、float_class_exact、decimal_result。NormalResultLeaves・ObservationContractsExamples |
| KeyContracts | KeyShape/KeySlots/KeyPairsと共有の成功の証明、mapKeys、code_of_shape/equal_of_shapes、decimalNormal_value/decimal_key_compare、map_measure/set_measure、対象外の三形。ObservationContractsExamples |
| PreparedLeaf | checkIn/entailsIn/bind_entails/checked_refinement、Val.toTerm_observed、HasTypeVQ.observed_measure。NormalResultLeavesと三つの上層の適用例 |
| CertificateKeys | refute_keys_same、AllKeysChecked、keys_checked_all、checkIn_all_keys。PreparedSortExamplesの具体の上層/入れ子の読者 |
| NormalResultLeaves | expression/leaf、binary_leaf/binary_entails_at。PreparedLeafExamplesの実正常算術と改竄の拒否 |
| ObservationContractsExamples | 七measure、七幅三演算と符号付き負号、Byte・Decimal・bits、鍵の実制約と重複/Noneの対照。既定import |
| PreparedLeafExamples | 開いた長さの証明書、本番の非空型/網羅性、四つの置換像、開いた型域の意味、Boolean、正常算術。既定import |
| FieldObservationExamples | 同じPの宣言・VarianceValid、二段の不変欄、上層の葉と正常結果、開いた欄の受け手を置換するopen_field_stable、Noneを保つ捕捉。既定import |
| PreparedSortExamples | 16個の実値の外側の観測と一般の型付き観測、実Stringの三条件、構造の等号による任意の原子の移送、memberの解決成功/none、入れ子の鍵。既定import |

既存の補助と同じ帰納を重ねて作っていない。新しいKeyShapeの相互帰納はMap/Set/List/dataで共有し、正常な七整数は既存Intervalの補題を一度適用する。既存の全型置換、捕捉、状態の葉、比較・分類の有限規則の再証明は0件である。

作成時の関門は、型付きの上層と実観測・正常応答・同じ値の網羅性を境界にした。上層とrawの違い、値なしMapとMapの鍵化の違い、別のListへの取り違えは、それぞれの入口で初めて捕まる独立の契約である。新しいフラグやテスト専用の差し込み口はない。Rustのテストの追加・削除は0件である。

## 初回の検査と公理依存（再開1は末尾）

[verification.json](verification.json) にコマンド・終了・外側の時間・生出力の大きさとSHA-256を置いた。生出力は<tmp>に保存し、改造へ大きな生ログを写していない。正式RSSは未取得（計画上の非採取）。単独Leanは全て -M 12288、既定lakefileの値も12288である。

| 検査 | 結果 | 中身 |
|---|---|---|
| 完了状態の既定lake build | 終了0、1.352秒、943ジョブ | 全既定target。新規9モジュールと全既存importを含む |
| 公理監査 | 終了0、32.970秒 | Refinement359モジュール、旧主定理・三モデル・主要十移送を含む26,059宣言。private・生成宣言を含む |
| workのdry-run | 終了0、0.112秒 | B_WORK、--onlyなし。仕様対応の自己検査/集計、仕様例、既定Leanを選択 |
| 作業末のwork | 終了0、9.678秒 | `scripts/check.sh --level work --base 65677215c04e632a397126f97fbb442ec6b0108c` を一度実行。仕様対応の自己検査/集計、仕様例7件成功・失敗/無視0、既定Leanとsorry拒否 |
| 長さと照合の受渡しの局所入力 | 終了0、0.664秒 | handoff.lean。作業末work後の記録の照合として実行。本番Lean・写し・設定の変更は伴わない |

公理の集合は、なし9,810、propextのみ6,645、許可三公理8,528、propext+Quot.soundが1,064、Classical.choiceのみ1、Classical.choice+propextが2、Quot.soundのみ9である。sorryAx・独自公理・未承認依存は0。生出力は5,133,277バイト、SHA-256 `4a4b5285ad0bb0b594b690d12597e0d0f1514c5bf4a8fccfbd6f371a11bb2bb7`。対象名一覧は1,840,553バイト、SHA-256 `f375a9dc4bfd2d4f715db1c09ce6d3a4a6d8ad64033068a500a8ec71679cc9d2`。[audit.lean](audit.lean)・[audit.py](audit.py)で同じ一覧と監査を再生成できる。

実装途中の最初の既定ビルドは具体例の証明不足で終了1、sort-buildは入れ子の鍵の適用例の暗黙引数不足で終了1となった。修正後の既定ビルドとworkはともに成功した。handoffの初回の入力は別の閉じた非空の型付けを受ける形で書き始めたが、その前提は不要なので、元の閉じた型付けから得た結果自身を使う形へ整理した。NoFailを暗黙の変数名で書いたことによる失敗も、既存のRelease.Qemptyを明示して解消した。これらは本番の言明や型付けの規則を変える必要を示す失敗ではない。

新規・追記した本番Leanの警告は0件。既存ファイルの警告を隠す設定は加えていない。検査方針の集計に出る既存の仕様節の未参照一覧を、今回の検査不合格と読み替えない。Rust/Leanの全比較、全標準表の契約、独立レビューは今回の成功に含めない。

## 時間と計画との差

[times.json](times.json) に12単位の外側の観測枠を一行ずつ記した。.55/.56、.58/.59、.60〜.62、.64/.65はそれぞれ共通の枠を持つ。単位間に準備と読者がまたがるため、重なりを合算して総時間や一件当たりの時間にしない。資料読取りの開始は2026-11-03 02:10:58 UTCで記録した。能動時間とビルド・調査の待ちを全て分離できないので、見込み7時間〜13時間40分をこの結果の比で一律に下げない。4時間と上限27時間20分には達していない。

外側の全観測枠は約46分である。次表は各単位の観測区間の長さであり、単位に専有した所要時間ではない。後の単位で追加した実読者は、その追加時の共通枠へ含めた。

| 単位 | 外側の観測枠 | 重なりと範囲 |
|---|---:|---|
| L30.55 | 86.051秒 | L30.56 の field_measure_stable の準備を含む共通枠。分離不能。 |
| L30.56 | 86.051秒 | L30.55 と同じ枠。合算しない。 |
| L30.57 | 32.399秒 | その単位の観測枠。待ちの分離なし。 |
| L30.58 | 160.957秒 | 本番比較・分類・Decimalの接続と .59 の鍵構造の共通準備。分離不能。 |
| L30.59 | 160.957秒 | L30.58 と同じ枠。合算しない。 |
| L30.60 | 381.089秒 | Map/Set の共通読者・既定ビルド、.61/.62 の上層の接続と全 sort の観測補助の共通枠。分離不能。 |
| L30.61 | 381.089秒 | L30.60 と同じ枠。合算しない。 |
| L30.62 | 381.089秒 | L30.60 と同じ枠。合算しない。 |
| L30.63 | 121.859秒 | その単位の観測枠。待ちの分離なし。 |
| L30.64 | 625.19秒 | 四名前空間・開いた型域の意味、.65 の Boolean と不変欄、.66 の入れ子の鍵の補題の共通枠。分離不能。 |
| L30.65 | 625.19秒 | L30.64 と同じ枠。合算しない。 |
| L30.66 | 592.611秒 | 16sort の照合、正常算術から葉の接続、写し・署名・既定ビルド・監査・workを含む。後段の能動時間とは分離不能。 |

計画の配置案からは、入れ子の鍵の補題をCertificateKeys、正常算術から葉の構成をNormalResultLeaves、具体例を四つの専用モジュールへ分けた。S05の固定署名は不変であり、主な十言明、新しい公理、独立の信頼条件、利用者の形の制限、提供範囲、精密な外部状態の変更は不要だった。単位ごとの外側の時間を独立に分離できなかった点と、最初の既定ビルドの生出力を計時付きの台本へ保存しなかった点は記録上のずれである。後から能動時間を作っていない。台本導入前の局所Leanの生出力・個別計時も未保存であり、最終の既定ビルドを成功の根拠とする。保存した後のビルド・監査・work・局所入力はverificationに残した。

## 担当の義務の一行ずつの判定

今回のJ・K分だけの判定である。L30全体・改造全体を閉じた行は0件である。

| 義務 | 今回の判定と証拠 | 残る担当 |
|---|---|---|
| O015 | 担当分完了。上記16行の型付き観測成功と有限規則。sameObservationには依存しない | L40の標準葉、L50の所属・全σ |
| O017 | 担当単位なし。U03を引継ぎ、数学の幅へ保存幅を固定しない | L、R20/R50/R60 |
| O019 | 担当分完了。PreparedLeafの上層と構文の導出、入れ子の鍵の包含。refute_keys_sameとAllKeysCheckedのrefuteの腕により、仮定を平坦化した核の実際の鍵列も検査する | R20の検査器、R50の比較 |
| O020 | 担当単位なし。既存discard/Orのsoundを維持 | L、R20/R70 |
| O021 | 担当単位なし。外側の時間を記録。全79単位の見込み変更は行わない | L/N、取りまとめ |
| O022 | 担当分完了。実観測・正常結果・鍵の構造から葉と三条件を構成。別名の代表は同じ閉じた項の反射に限り、EqProof.checkの成功は構文の一致を与える。stableには開いた受け手を置換する実読者を追加 | L40/L50/L60の実表・本体 |
| O023 | 担当単位なし。既存rawの核内証明を維持。実行再生の一式を追加しない | M、R50 |
| O026 | 担当分完了。数値モデルの候補と実観測成功を区分。負の長さを実反例と呼ばない | Lの停止理由、R20/R60の実現確認 |
| O034 | 担当分完了。七measure・正常算術・型付き閉値・閉じた鍵の実読者 | L40の全契約、L50/L60、R50 |
| O043 | 担当分完了。checked_refinementと本番Ty.LeQ.bind、四つの像を含むTransport | L40の全部分型・正常δ、L70 |
| O050 | 担当分完了。既存観測交換、欄の正常結果、None保持、危険な整数等号の境界を維持 | L40の標準葉 |
| O054 | 担当分完了。上層で検査したB04からfalse_side、And/Or/Not、bindの実読者 | L40の標準比較、L70/R10bのソース合成 |
| O071 | 担当単位なし。探索完全性や実現可能性を新たに仮定しない | L、R20/D10 |
| O072 | 担当分完了。宣言した欄連鎖と四つの像。別名の代表は反射と構文の一致に限定する。開いた欄の受け手のstableはopen_field_stableで確認 | R10bのソース展開、R20の鍵管理 |
| O127 | 担当分完了。型付きStringの観測、実charactersInの成功/偽、既存の包含規則を保持 | L40の標準葉、R段/V10 |
| O130 | 担当分完了。二つのString長を実「é」で区別し上層・置換後へ接続 | L40、R段/V10 |
| O131 | 担当分完了。Noneを含むList長、開いた同じ長さの証明書と非空の入口 | map/reverse/append/filterはL40、R段/V10 |
| O132 | 担当分完了。Bytesの正常長と不正byteのnone、Byteの別の値域 | L40、R段/V10 |
| O133 | 担当分完了。実鍵の構造とKey.equal、Decimalの数の等値、Map重複と後の値、sizeと鍵化の区分 | L40の具体のBと実標準表からのKeyShape・ClosedSlotsの供給、値の変性、R段/V10 |
| O134 | 担当分完了。Setの鍵の構造と重複縮約、正常sizeとNoneの区別 | L40の具体のBと実標準表からのKeyShape・ClosedSlotsの供給、不変、R段/V10 |
| O135 | 担当分完了。同じPのVarianceValid、宣言した二段の欄とmeasureの葉 | L40/R40のdata/decode、R50/V10 |
| O136 | 担当分完了。外側に依存する述語、型・行・範囲・算術の値像を同じLeQで移送 | L40/L70、R段/V10 |
| O137 | 担当分完了。七幅の正常算術と四幅の負号、Byte/Decimalの表現、あふれの拒否、正常応答から葉 | L40の全δとH04、R段/V10 |
| O144 | 担当分完了。既存の有限規則を実観測・上層・型へ接続。新しい理論は追加しない | L40/L50、M/N、R段/V10 |
| O158 | 担当単位なし。独立のunknown/上限は追加しない | L、R20/R70/V10 |
| O161 | 担当単位なし。保存幅/一時幅の契約を変更しない | L、R20/R60/V10 |
| O167 | 担当分完了。観測不能・不正byte・別のList・偽guard・数値改竄・Booleanのsortを受理と対照。既存のUF等の拒否を維持 | L/L40/L70、R段/V10 |
| O046 | 担当分完了。既存捕捉・条件分岐の前提を保ち、Boolean/lengthを実際の導出へ供給 | L40のδ/標準facts、L70 |
| O079 | 担当分完了。同じListのlen=n、n>0の証明書と網羅性 | L70/R10bの静的強化、R50 |
| O138 | 担当分完了。Booleanの偽側と非空の有限証明書 | L40の標準facts、L70/R10b、R50/V10 |
| O143 | 担当分完了。同じ長さの開いた証明書、既存pattern_length_relationとの合成。任意の同長の別Listへ移す実APIの契約は含めない | L40の標準契約、L70、R段/V10 |
| O016 | 担当分完了。初回26,059宣言、再開1で26,068宣言の公理監査。許可三公理のみ、sorryなし | 取りまとめの追加部分の独立レビュー、N/L70 |
| O084 | 担当記録完了。実観測・上層の証明と、実δ/全σ/実装比較の残りを分離 | 独立レビューと受け入れ、M/N |
| O027 | 担当記録完了。-M12288、外側の時間、正式RSSの非採取を記録 | N末の同じworkで取りまとめが正式採取 |
| O118 | 担当分完了。01-12・07-04を実物の前提・規則と同時更新。工程ID・手元の絶対パスを本番へ追加しない | M/N、L70/R50/R60/D10/V10 |

## 初回の受渡しの状態

初回の受渡しでは、本番Lean・01-12・07-04・lakefile・既定importを、初回の完了ビルド・公理監査・作業末workの後に変更していない。再開1で行った変更と検査は次節に記す。その後の変更は本結果・署名・入力と検査の記録、および局所の受渡しの検査入力だけである。records.pyは同じ本番の入力ハッシュと署名を再生成する。開始時のソースのハッシュの控えは<tmp>に置き、ファイル数・大きさ・SHA-256をinputsへ残した。

初回の受渡し時点では、新しい方式・主定理・公理について取りまとめに判断を求める点はなく、独立レビューと受け入れは未実施だった。取り込み・planへの転記・docs/todoの操作は取りまとめが受け持つ。

## 再開1: RV-L30.j の中1・軽1〜4・情報1の処置

2026-11-03。RV-L30.jは可（重0・中1・軽4・情報3）であり、中1について取りまとめが選んだ補題の追加を実施した。以下は実装担当の処置と自己点検である。レビューが求めた追加部分の再レビューと受け入れは、取りまとめが受け持つ。

| 所見 | 処置と確認 |
|---|---|
| 中1 | Certificate.refute_keys_sameを本番へ追加。AllKeysCheckedのrefuteの腕は核が読む平坦化した仮定からの鍵列の検査を要求し、keys_checked_allのrefuteの場合でこの等号を使う。consume・casesの下のrefuteについて、核の検査成功とAllKeysCheckedをともに示す既定の例を追加した。注釈・01-12・07-04・O019を同じ内容へ修正した |
| 軽1 | O022・O072の別名合同を、同じ閉じた項の反射、EqProof.checkの成功から得る構文の一致へ限定した。既存の閉じた項の例はそのまま保持した。open_field_stableを追加し、開いた欄の受け手var0を閉じた構成子の像へ置換し、置換後のstringBytes=2を既存field_measure_stableから導く読者を置いた |
| 軽2 | arguments_only_rejectedを追加。同じ述語でCertificate.leafの上層検査が成功することと、引数を未宣言のvar9だけに変えたPreparedLeafのcheckInが失敗することを同時に示す。従来のBoolean改竄例は述語と引数を整数へ変えており、述語のsortで拒否する例として注釈を訂正した |
| 軽3 | satBの成功とKeyShapeの証拠を別々に示しており、両者を結ぶ補題はないことを明記した。型付きの鍵の値からKeyShape・ClosedSlotsを供給する段は、具体のBと実標準表を持つL40である。今回この橋を追加せず、条件付きのL30の結論とL40の供給責務を明示した。O133・O134と受渡し表も修正した |
| 軽4 | byte_representedをbyte_and_u16_representedへ改名し、注釈・01-12・07-04・本記録を「255以下のByteと同じ数のUnsignedInteger16の表現可能性」へ訂正した。名前以外の型と証明は不変。変換演算との一致を証明したとは記していない |
| 情報1 | handoff.leanの長さから非空・網羅性を経てpattern_length_relationへ至る合成例を、既定のPreparedLeafExamplesの末尾へ移した。元の閉じたListの型付けから得た結果自身を使い、新しい前提を足していない。handoff.leanは同じ既定モジュールのimportだけとした |
| 情報2 | L40への申し送り。open_refinementの読者はouterLengthやassumptionsを使わない葉であるため、L40では前提を読む長さの証明書をTy.LeQへ通し、前提列の順と形を既定ビルドで検証する |
| 情報3 | L40への申し送り。false_side等はEntailsの接続までであり、PathConditionsが構成する分岐の型付けへの接続はL40で行う。PreparedLeafExamplesの未使用の直接importは整理したが、PathConditions本体と既定ビルドへの包含は維持した |

中1の公開した補題の完全署名は次のとおりである。名前空間はBenitoite.Release.Refinementである。

```lean
theorem Certificate.refute_keys_same (Φ : List Pred) (goal : Pred) (r : Refutation) :
    (Certificate.refute r).keys (Pred.ofConjuncts (Φ.flatMap Pred.conjuncts)) goal =
      (Certificate.refute r).keys (Pred.ofConjuncts Φ) goal
```

証明は既存ofConjuncts_keysと、追加したprivateのconjuncts_keys（p.conjuncts.flatMap Pred.linearKeys = p.linearKeys）を用いる。AllKeysCheckedのrefuteの腕は次の検査を要求する。上層の鍵だけを読む定義のままという記述は残していない。

```lean
| .refute r => KeyTable.checkIn P C Γ
    ((Certificate.refute r).keys (Pred.ofConjuncts (Φ.flatMap Pred.conjuncts)) goal) = true
```

追加した名前付きの証明は、この二補題とFieldObservationExamples.open_field_stable、PreparedLeafExamples.arguments_only_rejectedである。後二者の入力に使うprivateのreceiverImage・receiverModel・badArgumentsも追加した。完全署名と定義は[signatures.md](signatures.md)に本番から再抽出した。新しいLeanファイルは0本、再開時点から変更したLeanは6本である。[resume1-changes.json](resume1-changes.json)に再開前後のSHA-256を残した。初回の入力・監査の控えは[initial-inputs.json](initial-inputs.json)・[initial-audit-summary.json](initial-audit-summary.json)、現在の入力は[inputs.json](inputs.json)に置いた。

作成時の関門として、引数だけの拒否はCertificateの成功とPreparedLeafの失敗を分ける契約を対象にした。既存の改竄例はこの差を捕まえられない。開いた欄の例はvar0を実際に異なる構文の閉じた受け手へ置換するため、閉じた項への恒等の置換だけでは検査できないstableの適用を持つ。長さと照合の合成は公開入口の境界を既定ビルドで検査する。既存補題の再実装やRustのテストの変更はない。

### 再開1の検査と公理依存

| 検査 | 結果 | 中身 |
|---|---|---|
| 最終の既定lake build | 終了0、1.471秒、943ジョブ | 全既定target。追加・変更部分の警告0。既存の警告を抑制する変更なし |
| 公理監査の再実行 | 終了0、33.278秒 | 359モジュール・26,068宣言。private・生成宣言と旧主定理・三モデル・主要十移送を含む |
| workのdry-run | 終了0、0.118秒 | 指定B_WORK、--onlyなし。仕様対応の自己検査・集計、仕様例、既定Leanを選択 |
| 再開1の作業末work | 終了0、3.760秒 | `scripts/check.sh --level work --base 65677215c04e632a397126f97fbb442ec6b0108c`を今回一度実行。仕様対応の自己検査・集計、仕様例7件成功・失敗/無視0、既定Lean全ビルドとsorry拒否 |

コマンド・終了・計時・生出力の情報は[resume1-verification.json](resume1-verification.json)、監査は[resume1-audit-summary.json](resume1-audit-summary.json)に保存した。生出力は<tmp>に置いた。最終ビルドの生出力は43,382バイト、SHA-256 `655225dfd384167abce11b385f30078be9578668912fd5e5c3c7794e1675f411`。workは5,757バイト、SHA-256 `18213ad2fbd3e257d2791fd6dce309e16f42c54bab2beed69e632c0960f98965`である。

公理の集合は、なし9,813、propextのみ6,648、許可三公理8,530、propext+Quot.soundが1,065、Classical.choiceのみ1、Classical.choice+propextが2、Quot.soundのみ9である。sorryAx・独自公理・未承認依存は0件。生出力は5,135,713バイト、SHA-256 `f01aaadc19711b6495f471b3ba08c2d99fe683f67eedb4cd5678040e6a2a88b5`。対象名一覧は1,841,533バイト、SHA-256 `e25d176e7c29b1d8d95a3ef6c8b722585363bba9a593d372ba63fce5df75674c`。[audit.lean](audit.lean)・[audit.py](audit.py)で対象名一覧と監査を再生成できる。正式RSSは今回も非採取である。

最初の既定ビルドも成功したが、追加例のunusedSimpArgsが1件あったため除去し、上表の最終ビルドで警告0を確認した。単独Leanの途中の暗黙引数の不足は明示して修正し、最終ビルドで検証した。検査後に本番Lean・01-12・07-04・設定を変えていない。

### 再開1の外側の時間と受渡し

外側の開始は2026-11-03 03:09:25 UTC、記録の最終照合まで873.175秒（約14分33秒）である。資料読取り、実装、検査、記録の最終照合を含む終了時刻と区間ごとの秒数は[resume1-times.json](resume1-times.json)に置いた。能動時間と待ちを分離していない。4時間の途中報告条件と上限27時間20分には達していない。今回の処置はL30.55〜.66のレビューへの補正であり、12単位の初回の時間と重複して合算しない。

S05の四入口、主要十移送、型付けの規則、L20・群H・Iの構成への新前提は0件である。旧Releaseの110ファイルは不変。新公理、利用者の形の制限、提供範囲の削減、精密な外部状態の新設はない。補助の名前変更とAllKeysCheckedのrefuteの条件の強化は上記のとおりであり、新たな設計判断を求める点はない。取りまとめに残るのは、中1の追加部分の再レビューと受け入れ、およびL40への三点の申し送り（型付き鍵からのKeyShape・ClosedSlots、前提を読むLeQの例、分岐の型付けへの接続）である。

## 作業末の work

取りまとめが、RV-L30.j の再レビュー（再開1、可）の後に、Refinement の生成物を消してから一度実行した。

| コマンド | 終了状態 | 外側の時間 | 最大常駐量 |
|---|---|---:|---:|
| `scripts/check.sh --level work --base 65677215c04e632a397126f97fbb442ec6b0108c` | 0 | 158.03秒 | 1,535,393,792 バイト |

選ばれた検査は、仕様対応の自己検査・集計、仕様例（7件成功・失敗0・無視0）、既定の Lean ビルドと `sorry` の拒否である。
