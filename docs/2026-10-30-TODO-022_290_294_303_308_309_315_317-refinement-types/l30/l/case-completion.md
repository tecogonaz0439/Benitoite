# 全場合と拒否の照合

2026-11-03、L30.77。全場合を覆うのは本番の帰納の証明であり、具体例の件数を無限の入力の全探索と数えない。A〜Kの群の結果・再開・取りまとめの追記と現在の本番の構成子/分岐を照合した。新旧全モジュールの包含と公理依存は段末のaxioms.leanで確認する。固定署名の検査はsignature-check.leanで行う。

## 全構成子と成功の証拠

| 対象と件数 | 一行ずつの構成子・場合 | 全場合の証拠と既定の読者 |
|---|---|---|
| Term 20 | var/integer/character/float64/float32/decimal/boolean/unitValue/string/listValue/bytesValue/mapValue/setValue/dataValue/targetValue/field/measure/add/neg/scale | TermStructuralEq.termEq_spec、linearize_sound_at。integer/add/neg/scaleを分解し、残る項は検査した鍵の整数射影。LinearizationExamplesの13形のsort拒否とvar/field/measureの適格性 |
| Pred 14×2＝28 | truth/falsity/eq/le/lt/compare/floatClass/decimalRepresented/charactersIn/member/constructorIs/and/or/not、それぞれ正負 | LogicNormalization.normalize_sound_atの一つの構造帰納。LogicNormalizationExamples.cases28、負の整数境界、入れ子De Morgan、Floatのnot lt、未解決の対象所属を保持 |
| LinearStep 2 | combine/round | LinearCombination.LinearStep.sound、非負結合・全係数の整除・正除数と負の床。RefutationExamplesの空和/零/複数/奇数等式の対照 |
| Refutation 9 | consume/cases/derive/closeLinear/closeAtom/split/discardTodo/discardFact/builtin | RefutationSound.refute_sound_atの一回の帰納。全9形を含むRefutationExamples/CertificateKernelExamples。builtinも葉を再検査してNNFを加え、常時falseの未実装枝ではない |
| consume内のNNF 6 | truth/falsity/linear/literal/and/or | consume_sound_atはOrを拒否し、casesがOrの左右を同じ元のfactsから検査。9構成子の件数へ6を足さない |
| EqProof 9 | refl/symm/trans/add/neg/scale/hyp/field/measure | structural_sound/integer_sound_at/substitute_sound_at、AdmissibleIn/checkIn。EqCertificateExamplesの両mode・欄/7measure・中間項・snapshotの対照。alias構成子なし |
| Certificate 7 | use/leaf/substitute/consume/cases/discard/refute | Certificate.sound_at/soundとimplication_sound_at。CertificateKernelExamplesの旧六形と新refute、上層・入れ子の鍵。refuteは鍵/NNFを内部再計算 |
| 旧Certificate 6 | use/leaf/substitute/consume/cases/discard | Certificate.Legacy.check/embed/success_preserved、legacySix。削除前の六規則の写しへの成功保存であり全旧Releaseの同値ではない |
| Entails 19、直接帰納4 | 旧18規則とcheckedAt一つ。weaken/cut/sound/bind | Logic/LogicSound/Basicが各一場合を追加。checkedは恒等置換の導出。bindはν合成、証明書再生成なし |
| 型域の8型・17項 | 七整数型とByte各2端点＝16、Decimal1項 | Context.carrierFacts/assume、Const.NumericRepresented.carrierFacts、TypedFacts/ValueFacts、ValueMeaningの第三条件。H/Iの16読者と全Captureの処分。Character/Float等へ独立の型域を追加しない |
| 型付き意味33場合 | ValueShapeMeaning23＋ValueMeaning1＋ValueMeanings2＋ValueMeaningEach2と型付け側の相互の33場合は役割を区分 | H/Iのtyped_meaning_aux/typed_entries、Kのopen_refinement_meaning。構成子数の和28を33の場合数と誤認しない。33はHasTypeVQ29＋Vs2＋Each2の相互の入力の場合 |
| measure 7 | stringBytes/stringCharacters/listLength/bytesLength/mapSize/setSize/characterCode | Observation.measure_exact/measure_machine_exact/measure_stable、ObservationContractsExamplesとHasTypeVQ.observed_measure。不正Bytes/Map/Setのnoneを成功にしない |
| sort 16 | integer/character/float64/float32/decimal/boolean/unit/string/list/bytes/map/set/data/target path/target host/target endpoint | PreparedSortExamples.observations_16/typed_observation、representedとVal.toTerm_observed。外側の成功と内部None、memberの解決成功を区別 |
| 算術21組＋負号4幅 | 整数七幅×add/sub/mul、符号付き四幅のneg | 既存Interval.checked*_normal_iffをNumericContractsが使用。ObservationContractsExamples.seven_integer_normal、NormalResultLeaves.binary_leafと実Integer8。中間Stopを正常へ戻さない |
| 鍵 成功11形 | integer/character/decimal/boolean/unit/string/bytes/list/map/set/data | KeyShape/KeySlots/KeyPairsの共有相互帰納、Key.code_of_shape/equal_of_shapes、Map/Set縮約、Decimalの正準化。型付き値から構造の供給はL40 |
| 鍵 対象外3形 | float64/float32/targetValue | Observation.key_unsupportedとNoneの対照。mapSizeが値を観測しない場合とMap自体の鍵化を区別 |
| 固定幅とsteps | read/save/add/sub/mul/neg/divide、一時積、Decimalの別域、work/create/destroy | LのProofContractExamples、22行の再生。used/reserved/remaining、destroy_once、rollback_all、三停止。数学の幅は引数、128は契約値 |

## BuiltinLemma 12種類・100分岐

| 種類 | 分岐 | 証拠と境界 |
|---|---:|---|
| closed | 1 | closedTrue_sound_at、閉性/sort/evalClosed=some true |
| lengthNonnegative | 1 | 旧の閉じたList長、旧成功保存 |
| measureNonnegative | 7 | 全measure、正常結果の非負と失敗時の整数射影0を区別 |
| booleanApart | 2 | Booleanの真/偽の両向き。Kのfalse_sideへ供給 |
| compareComplement | 22 | 七scalarのeq/ne両向き14、Character/Decimalの順序の補数8。Floatの順序反転なし |
| charactersSubset | 1 | 同じStringの有限区間包含、境界改竄を拒否 |
| constructorApart | 1 | 同じdataと異なるconstructor、同名を拒否 |
| sameObservation | 16 | 同じ構文の代表原子q→q、参照形はuse。同一性や観測成功を強めない |
| scalarOrder | 30 | 4sort×6則＋3sort×eq二則。成功した比較を前提とする |
| characterCodeRange | 1 | Char.validと実measure、Unicodeスカラー値の範囲 |
| characterCompare | 6 | 六比較と整数コードの対応 |
| floatCompareClass | 12 | 二幅×finite/NaN/±Infinity/±0。元のbitsから証明 |

BuiltinSchema.candidates_sound_at/PreparedLeaf.raw_sound_atが全12種類を証明する。registry_100のraw成功は候補自身から構成するため独立の退行検査とは数えない。比較30形、追加の等しい/逆端点48件、分類12件、近い改竄6件を別に照合する。

## 12種の不正証拠と受理の対照

| 拒否 | 本番の位置と、対応する受理 |
|---|---|
| 兄弟の参照 | RefutationExamplesのOr左右で追記を共有しない。両枝にfalsityがある受理との対照 |
| 将来の参照 | LinearStep.combineの位置2を二項しかないfactsで拒否。現在の0/1の結合は受理 |
| 循環の参照 | deriveのexpectedは検査成功後にだけ末尾へ追加し、その新しい位置を同じstep自身のsourceにできない。上の将来参照と同じ入力境界。循環を表すポインタは有限の構文にない |
| 範囲外の参照 | discardFactの削除後の旧index/範囲外、currentIdのindex=boundを拒否。新しい有効な0を受理 |
| sort違い | rawのBoolean整数射影の成功と、上層のSorted/鍵検査による拒否。整数のtyped_twiceは受理 |
| 期待式の改竄 | badTwiceの乗数と線形expectedの不一致、正常結果5→6の葉の拒否。twiceと正常5は受理 |
| 未知key | splitの範囲外番号とlinearizeの未登録鍵を拒否。登録済みの0を受理 |
| 宣言不一致 | EqCertificateExamples/FieldObservationExamplesのFieldRefの宣言・位置・sort。検証済み同じPの欄連鎖を受理 |
| 負の乗数 | combineの−1を拒否。零/正の乗数を受理 |
| 非正除数 | roundの0/−2を拒否。2で全係数の整除と負床が一致するものを受理 |
| 不正な丸め | bound=−3/d=2で−1を拒否し−2を受理。非整除の係数も拒否 |
| 片枝欠落 | casesの片側truth、splitの片側改竄を拒否。splitOddLeft/Rightが両側の追加事実を使って閉じるものを受理 |

拒否は有限検査の不一致によるものであり、数学の反例の存在を意味しない。表現外・steps超過も証明済みや反例の出力にはしない。利用者measure/一般UF/非線形/入れ子measure等の制限は、既存のSource/sort/WFの境界とR段の実CLI照合を区分して保持する。

新本番6モジュールと既定importへの追加にsorry・native_decide・新公理・信頼する外部実装・工程ID・手元の絶対パスはない。既存の工程コメントの残件はO118の後段の担当へ残す。匿名exampleは定数一覧へ登録されないため#print axiomsの件数へ含めず、既定ビルドとsorry拒否・禁止構文の点検で確認する。
