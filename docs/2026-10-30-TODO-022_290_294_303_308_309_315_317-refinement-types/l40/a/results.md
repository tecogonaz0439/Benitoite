# 群 A・F1 の実装結果

2026-11-03。基準 B_WORK は `2a2453825e956404fbe82d0a586d8776f323150a`、指定ブランチは `m014/l40.a`。担当から git コマンドを実行していない。ブランチ・HEAD の実値は起動依頼の指定を採用し、未コミットの本番入力と新規ファイルは [inventory.json](inventory.json) の SHA-256 で識別する。共通依頼文、detail 全節、plan の停止条件・外挿・先頭の判断、README の受け入れ、RV-L40-plan の再レビューと追記を引き継ぐ。依存・固定版の勧告は共通依頼文の2026-10-30の記録を継承し、更新を相乗りしていない。

初回の実装・方式・署名の判定はL40.01〜.05・.30〜.32を完了としたが、RV-L40.aでF1は可、群Aは要修正となった。群Aの再開1の処置と最終検査は末尾を正とする。単位ごとの初期実装の開始・終了の記録がないことは、下記の運用上の未達として残す。独立レビューと設計者の受け入れは未実施であり、取りまとめが受け持つ。L40 全体や主定理の閉鎖を意味しない。RSS は未取得（計画上の非採取）。外側の時間を能動時間とみなさない。

## 単位の完了条件と外側の時間

群全体の外側の時間は、effort-ledger.mdの2026-11-03の二行により、試行1が約66分（終わり近くで容量の誤りにより停止）、試行2が約15分（試行1の作業木を引き継ぐ）、合計約81分である。単位や群A/F1へ按分せず、能動時間として外挿しない。

初期の実装・検査の成果が既に作業ディレクトリにある状態から、入力・証明・署名・検査記録を照合して本書を仕上げた。初期実装を単位へ分割した時計の記録は残っていない。ファイルの更新時刻から実装時間を推定せず、単位ごとに未採取と記す。これにより、依頼の「単位ごとの外側の時間」は完全には満たせない。最終確認の検査時間は実測値であり、初期実装の時間とは分ける。

| 単位 | 担当分の完了判定と本番の証拠 | 初期実装の外側の時間 | 最終確認の外側の時間 |
|---|---|---|---|
| L40.01 | 済。C01〜20、全構成子、旧31逆転、56/60/64義務、76葉を records.py で照合 | 未採取。開始・終了を復元できない | 集合・入力の再生成0.37秒。後の文書照合は下記 |
| L40.02 | 済。TelBodyTy.narrow_input、TelLe.open_done、TelClosure.two_steps/from_function_norm の4代表を本番へ配置。F02の全列の署名を固定 | 未採取。同上 | Wの9.17秒を共有。単位へ按分しない |
| L40.03 | 済。同じ5代表について具体のTable、現行satB、Rustのsummary/型検査/IR検査を照合。F05を固定 | 未採取。同上 | Rustのコンパイルと5入力で1.35秒。LeanはWを共有 |
| L40.04 | 済。直接overflow、Booleanの短絡、return後の番兵、予算停止、Rangeの正常なError値を区別 | 未採取。同上 | 局所Lean4.71秒とWをF1と共有 |
| L40.05 | 済。F01〜07、S01〜36、23モジュール328 API、丸め5モード、末尾の内部契約を固定 | 未採取。同上 | 逆転の署名0.78秒、補足の署名0.66秒、Wを共有 |
| L40.30 | 済。演算自身の失敗・正常な子・引数列・標準評価からFailureCoveredへ | 未採取。同上 | 局所Lean4.71秒とWを共有 |
| L40.31 | 済。同じ失敗成分で制御・腕・Blockを処理し、独立評価109場合を網羅 | 未採取。同上 | 局所Lean4.71秒とWを共有 |
| L40.32 | 済。report/analyzeExpr/analyzeを通じ、任意Parametersのtracked_failure_soundを証明 | 未採取。同上 | 局所Lean4.71秒とWを共有。公理監査38.49秒は全体 |

初期の work は06:37:16〜06:37:31 UTC、14.43秒、終了0であり、[checks-initial.json](checks-initial.json) に保存した。結果の初期実装の時間の代わりにはしない。最終状態の work は06:59:21〜06:59:30 UTC、9.17秒、終了0である。最終確認の途中に生じた変更が理由で再実行したもので、同じ状態の一式を重ねてはいない。担当が明示的に実行した work は、最終状態に対するこの一回である。4時間・20時間40分の上限に達したと認める時計の記録はなく、未採取の時間を0時間とも見込み未満とも断定しない。

群Bは未着手であり、n_V=11/n_C=3の単価は取得していない。A/F1の時間を群Bや標準本体へ外挿せず、段の枠15〜35時間と起動依頼の見込みを維持する。今回の時間記録の不足を取りまとめへ報告する。

## L40.01：入口と控除

L20・L30 の段末は README の2026-11-03の決定により受け入れ済みである。C01〜C20 の宣言は既存の本番にあり、再証明しない。[inventory.json](inventory.json) に供給元の完全名を記録した。C16 の Ty.carrierFacts は Context にある。ret_value は控除表外の DependentBeta.HasTypeCQ.ret_value を使う。

旧 Inversion の34定理から fnTy_eq・fnRef_admissible・ret_value を除いた inv_ は31件。内訳は群Bの移植14（値11・計算3）、既済み7、後続10（値1・計算9）。dependentLam・raise は新2目的であり、旧移植の単価へ含めない。開始時の未処理は24、群B末の N_V=1、N_C=9。旧31行の行き先は [前段の一覧](../results.md#旧31逆転定理の行き先と同種の残件) を維持する。

Val25・Comp16（matchを含む）・State4・Frame7・Cell6、HasTypeVQ29＋列2＋Each2、HasTypeCQ24、LeQ14・TelLe2・TelClosure2・TypeArgsLe4、ContTy10、KeyShape11・KeySlots2・KeyPairs2、Step76を照合した。76葉はStepを返す60・到達型16である。義務はplan56行、L20/L30との和60行、共通4行を加え64行である。新しい義務や証明件数へ掛け直さない。[obligations.md](obligations.md) に担当分・証拠・残る単位と後段を64行とも一行ずつ判定した。義務全体を新たに閉鎖した行は0である。

## F01〜F07 の固定した署名

完全な引数・前提・存在量化・結論は [signatures.md](signatures.md) にある。88,041バイトで100KB以下である。元の直接規則と全328 APIの宣言を収め、逆転の各枝は [signatures.py](signatures.py) から [signature-check.lean](signature-check.lean) を再生成できる。元規則26値枝・21計算枝の型を確認したことと、後続の逆転の証明が済んだことを区別する。

| 署名 | 固定した入力と結論 | 今回の証拠／残る証明 |
|---|---|---|
| F01 | 元のHasTypeVQと同じ構文。直接規則の各前提を返し、関数ではfnCoreとTelClosure、Mapでは鍵の正規形等号と値のLeQ、Setでは要素の正規形等号を加える。var/const/con/list/atError/checked系は芯とfactsで読む | 47直接枝を型検査。一般の逆転は群B/C。V_Sub/Normal/Refineを出力の元規則にしない |
| F02 | P.WellFormed、CoreAssumptions、Ψ.WF、元文脈のCtx.WF、両dependentFnのAnnotation、TelClosure t u、uに対する同じwsのHasTypeTelArgsQから、tの実引数列、結果b≤a、Covers e fを返す | 本番の一引数の反変・narrowing・依存結果の束縛、二段tail、正規化の4代表。一般のTelClosure.applyはL40.11 |
| F03 | 閉Γのscalarと芯の等号から同じtagのConst/ConstOK。全値・計算の直接前提と結果/効果の到達関係。StoreOkと同じ場所の型からref/lazy/cont/builderの実セル | signature-extra.leanと47枝。閉文脈・同じストア・固定σの量化を明示。全開始入力の供給は群C |
| F04 | CoreAssumptions、pure署名、BuiltinArgs、実δと正常応答/toTerm?の等号から、結果型の最外の各事実のEntails [] | normal_reply_facts/normal_reply_facts_atを本番化し、同じ整数7の応答と任意の値置換へ適用。具体δの全充足とは区別 |
| F05 | 同じ有限宣言のTableとP.VarianceValid、B.sat成功からKeyObservation。HasTypeVsQ/EachQの列版からKeySlots | Table/carrier/KeyObservationとUnitのcodeへの読者、5代表を本番化。全有限値のkey_table_sound/key_values_sound/key_each_soundはL40.22 |
| F06 | 有限Rowはname/tparams/neffs/tel/body/implementation/relations。coreは同じtelのDef.WellTyped、pureは全Ψ/ts/es/rs/wsのBuiltinArgsから同じOutcome.Typed/AdequateResult | Row.definitionの再構成とtel等号を証明。同時に満たせるidentity本体を具体の読者へ。関係は正常な有限Steps/Runsから導き、返却の存在を要求しない。全標準表の証明は群D/E・L60 |
| F07 | Models、同じEvalPartial failed、TrackedFailureから、同じanalyze abstract input parametersのmayFail=true | tracked_failure_soundを本番で証明。全Parameters。F2のjoinV/normalF/returnF/seqF/joinF、局所所属とFirstFailureHandoffの完全定義は署名に固定し、証明は後続 |

F02の内部のopen_doneはCtx.WFと両依存列のAnnotationを使い、SubstOk.openValueのTransportから同じ実値による結果のLeQと効果のCoversを返す。再開1で元文脈のCtx.WFをF02にも追加した。開始の導出から形成を供給する一般の証明はL40.11で行う。供給できない場合は、独立の信頼条件に置き換えず停止する。元の関数のviewと依存列の正規化は既存InversionCoreを使う。

本番化した代表の境界はtest-auditの作成時の関門に従う。F3は反変入力と同じ値の具体化、鍵は同じ宣言の要約と実判定、H04は失敗を評価順に伝播する契約を守る。既存の正常値/警告のテストだけでは失敗成分を検査できない。新しい差し込み口は設けない。短絡の受理・拒否の対照は、同じBooleanの右辺について左のfalse/trueを変える。型を満たせない右辺を対照にしない。

## L40.03：鍵の具体表と現行判定の照合（J40-1）

本番 StandardKeyTyping.Table は、有限のdata宣言、data名/構成子名の重複なし、同じ構成子列とP.consの等号、計算したdataSummariesの収束、全C/a/pに対するB.satとsatBの等号を保持する。carrierはbase・bytes・tvar・data・List・Map・Setを保存し、篩を除き、その他を鍵不可の骨格へ写す。KeyObservationや全欄の鍵化はTableの入力欄にしない。

[5入力](keys/) はすべて同じ A/B/FunctionField/Phantom 宣言を持つ。AとBは相互再帰、B.EndだけがTの欄を持つ。FunctionField.Makeは関数の欄、Phantom.MakeはUnitだけを保持する。具体のLean表と同じ欄・型引数数・依存位置で比較した。

| 同じ入力の鍵型 | 具体Table/B.sat | 現行Release.satB | Rust型検査 | Rust IRのsatisfies |
|---|---|---|---|---|
| List[Decimal] | 受理 | true | 誤り0 | 誤り0 |
| Map[Integer8,List[Decimal]] | 受理 | true | 誤り0 | 誤り0 |
| A[Decimal]（A/B相互再帰） | 受理 | true | 誤り0 | 誤り0 |
| FunctionField（関数欄） | 拒否 | false | E0423を1件 | 同じ関数欄のADT表を復元したIRをKey違反で拒否 |
| Phantom[function(x:Unit)->Unit] | 受理 | true | 誤り0 | 誤り0 |

要約はLean/Rustで一致した。A/Bは等値・鍵ともalways=false、依存位置[0]。FunctionFieldは等値always=true・鍵always=false・依存なしであり、鍵判定でも等値を先に要求するため拒否する。Phantomは両要約がalways=false・依存なしなので、未使用の関数型引数を検査しない。関数欄を持つdataと、未使用の関数型引数を持つdataを区別する。

拒否入力は型検査を通らないため、そのまま脱糖したIRは得られない。IR側だけは同じ宣言IDの対応を照合し、Unitの欄で作ったIRへ元の関数欄のADT表を戻して、独立IR検査のKey拒否を確かめた。この補助の入力を表層から受理されたプログラムと呼ばない。受理4件は実際の型検査→脱糖→IR検査を通した。

代表の表ではB.satをsatBそのもので定義し、sat_eqはIff.rflである。表の二列は同じ計算であり、独立な照合はLeanのsatBとRustの型検査・IR検査である。一般のTableのsat_eqは入力条件であり、宣言収集からのB.satの構成との照合はL70/R10bに残る。

判定を計算する本体は typeck/decls.rs の summaries/summary、typeck/solve.rs の依存位置の鍵制約、ir/check.rs の satisfies を読んで対応づけた。[keys/key_probe.rs](keys/key_probe.rs) と [keys/run_probe.py](keys/run_probe.py) で再実行できる。実ライブラリ・実行ファイル・入力・道具の版とハッシュは [key-probe.json](key-probe.json) にある。生出力は2,142バイト、SHA-256 `d5fee19c1b92e3aab5cf4b1ff4ffd6edde36cab5c1d88283b04db2a1aa93e290`。最終の再実行でも同一だった。

**J40-1の差は、この5代表では検出していない。** 判定規則や一般のsatB、Rustの規則を足して合わせていない。key_table_soundの全値の証明、宣言から同じ表を収集するL70/R10bの接続、R50の全比較は未完であり、今回の5代表の一致に含めない。L40.22/R50は、篩付き鍵型・Float/Float32の拒否・非空Cの制約付き型変数・Set・Bytes・標準Option/Resultのdataを名指しして照合する。scoped・opaque・external・Reference・Lazy・その他の鍵不可の骨格への写しも、この5代表の外として照合する。

## L40.04・.30〜.32：H04第一候補（J40-2）

第一候補tracked_failure_soundを、指定した量化・前提・結論のまま証明した。FailureCoveredは `∀ r, outcome=.failed r → r≠unknown → approx.mayFail=true` である。内部はModelsとRangeState.Modelsを使い、実入口でresetRangesとそのModelsを供給する。公開入口へRangeStateの条件、limits/state/fuelの成功条件、独立のδの算術一致を追加していない。TrackedFailureの同じtraceの条件も指定どおり保持する。

| 独立評価の判断 | 場合数 | 失敗成分の供給元 |
|---|---:|---|
| EvalPartial | 69 | expr_failure。正常値だけの枝はfailedを構成できない。unknownFailed/matchOtherFailedはunknownの除外。演算自身は正常な両入力のContainsとchecked演算の拒否から供給 |
| EvalArguments | 4 | arguments_failureからarguments_typedで同じEvalTypedArgumentsへ。nil/consはabruptを構成せず、head/tailを保持 |
| EvalTypedArguments | 4 | typed_arguments_failure。headAbruptとtailAbruptを評価順で伝播 |
| EvalArms | 6 | armList_failure。skip/guardFalseは残り、body/guardTrueは選択した同じ本体、guardAbruptは条件の失敗 |
| EvalWidthArms | 6 | armListKind_failure。同じ幅の区間・選択した束縛を使用 |
| EvalResultArms | 6 | resultArmList_failure。同じResultのviewと保存したRangeのModelsを使用 |
| EvalBlock | 14 | block_failure。bind/discard/seq/pattern/builderの環境・順次・abruptを維持 |
| 合計 | 109 | 同じ失敗成分を、fuelで減少する相互の証明として構成 |
| EvalStandard（別母集団） | 7 | standard_nonfixedとfixed_success。Range Error値とfailedを区別 |

式・短絡・Block・三種の腕・型付き引数は一組の相互証明であり、既存の正常Containsの証明を正常な子へ適用する。通常の引数列は型付き引数列への既存の変換を利用し、同じ帰納を二度作らない。result_rejected、own_kind_failure/own_width_failure、neg_kind_failureは、演算自身の拒否を既存の区間のmay-overflowの健全性から導く。

report_failureは成功した解析のFailureCoveredを読み、停止時はreportが返すbaseUnknown.mayFail=trueを使う。analyzeExpr_failureは任意limits/state/fuelからこれを構成し、tracked_failure_soundが実際のBudgetAnalysis.analyzeへ上げる。未対応もunsupportedのbaseUnknownへ退く。既存Success/SuccessAt、NormalSoundness/WarningSoundness、旧Releaseは変更していない。

本番の5経路は、直接の最大Integer64+1、false/true短絡、return後のoverflow番兵、fuel0・操作数0・既消費の停止と未対応、Range.makeの全結果を同じ正常Resultへ戻すrange_errorである。さらに実際のoverflowのEvalPartial・trace・Models・TrackedFailureを構成し、任意Parametersに第一候補を適用する具体の読者を置いた。公理や仮の定理ではない。既定ビルドに#evalを置かず、有限な判定は#guardと定理の証明で検査する。

**J40-2：第一候補は成立した。** 第一候補は解析の失敗成分についての定理である。実δとの局所の一致、正常/returnedの二成分を実構成から作るF2、実行の最初の失敗の第二候補、親実行・全表層との合成を、この成功へ含めない。

## 標準契約・API・本番の追加（初回の記録）

S01〜S36はdetail第3節の36行を維持する。StandardContracts.Relationは同順の36構成子、ImplementationはpureDelta/core、Rowは有限な構文のデータであり、任意Propや未検査の証明の欄を置かない。数値/観測/縮約の原始葉→具体δ→通常core本体→型付けと有限の正常実行の順序で証明する。Row.definition_telが同じ依存列を持つDefの再構成を示す。StandardBodiesのidentityは同じP/Bについて本体の型付けとtelの等号を同時に満たす。

全23モジュール328公開APIは、追加関係207・通常結果のみ121に分け、どちらも元の完全な型署名をsignatures.mdに保存した。各@builtin先とcore本体の区分をその署名へ写した。Integer/Integer64、UnsignedInteger/UnsignedInteger64、Byte/UnsignedInteger8、Float/Float64は型の別名であり、名前付きAPI行の数と混同しない。S34の明示変換、S35の床除算、S36のabsolute/minimum/maximum/bitwise/shiftも含む。Noneは通常値、floorModuloの最小値mod−1は正常な0、shift countの域外は後続のStopの対象という区別を維持する。

DecimalのLean表はHalfToEven・HalfAwayFromZero・TowardZero・TowardNegativeInfinity・TowardPositiveInfinityの5モードとする。RoundingMode.bntとbase/decimal.rsの同じ5選択肢に対応させた。±2.5を整数へ丸める表と、数学上の係数の一回の丸め・placesの拒否・仮数の表現外をStandardScalarに置いた。これを実Rustの丸め全域の一致の証明とはしない。各具体δ/core本体の全関係の証明は群D/E、Model全欄はL60、実標準ソースとの全比較はR50に残す。

| 本番モジュール | 手書きの名前付き宣言数 | 主な追加 |
|---|---:|---|
| TelApplication | 10 | narrowing、同じ実値のbind、TelClosureの2代表とその具体例の準備 |
| StandardKeyTyping | 17 | carrier/有限宣言/Table/KeyObservation/code、Unitの読者、同じ5代表 |
| StandardContracts | 9 | Relation/Implementation/Row/definition/BodyTyped、再構成の等号、正常応答factsとその置換 |
| StandardScalar | 7 | 丸め5モード、increment、DecimalRoundResult/decimalRound、有限表 |
| StandardBodies | 5 | safeGet/safeHead/safeGet_equalLength、実際に型付けできるidentityの代表 |
| IntervalFailure | 49 | FailureCoveredと伝播、算術の拒否、相互の失敗成分、report/analyzeExpr/tracked_failure_sound、5経路と任意Parametersの読者 |
| 合計 | 97 | privateを含むソース上の名前付き宣言。匿名exampleや自動生成宣言をこの数へ足さない |

全97宣言の名前・所在・行・種類は [declarations.json](declarations.json) にある。生成宣言も含む新6モジュールの監査対象は460宣言（19/68/179/72/8/114）である。全体監査の68,367宣言とは母集団が異なる。すべての新モジュールはBenitoite.leanの既定importに入り、公開入口には同じ既定ビルド内の読者又は具体の適用例がある。01-12と07-04の写しは、本番化した定義・量化・前提と対応させた。未証明の全逆転・全標準契約・全returnedの定理を写しで実装済みとしていない。

内部補題の最終の署名変更は0件である。自己点検の途中にbinary_own_failure/binary_right_failure/shortCircuit_right_failureのrightStartを未使用と誤認して外したが、rekeyの既定引数がこの等式を暗黙に使用しており局所Leanが失敗した。元の署名と呼出しを戻し、3箇所のrekeyへrightStart.symmを明示して再検査した。新しい前提も結論の弱化もない。元の短絡の右辺を整数式からBoolean比較へ直し、同じ右辺のfalse/trueの対照を追加した。

## 検査・公理依存・入力の識別（初回の記録）

[checks.json](checks.json)、[local-checks.json](local-checks.json)、[signature-checks.json](signature-checks.json)、[key-probe.json](key-probe.json)、[audit-summary.json](audit-summary.json) がコマンド・終了・外側時間・生出力の大きさとSHA-256を保持する。生の出力・全公理対象名・全形式化ソースmanifestは一時領域へ置き、改造にはその識別を保存する。

| 検査 | 最終結果と範囲 |
|---|---|
| IntervalFailureの単独Lean | `lake env lean -M 12288 Benitoite/Release/Refinement/IntervalFailure.lean`。修正前は終了1・4.63秒、3つの開始キー等号の未解決。修正後は終了0・4.71秒、出力0バイト |
| 署名の型検査 | `lake env lean -M 12288`でsignature-check.leanとsignature-extra.lean。終了0、0.78秒と0.66秒。型検査を後続の証明の完成とは数えない |
| 鍵の実Rust入力 | keys/run_probe.py。コンパイル0、実行0、1.35秒、rustc 1.98.1。受理4/型検査拒否1と独立IR拒否を確認 |
| 最終dry-run | 終了0、0.11秒。spec_tally/spec_examples/formal_buildを選択。--onlyなし |
| 最終work | `scripts/check.sh --level work --base 2a2453825e956404fbe82d0a586d8776f323150a`。終了0、9.17秒。仕様の参照集計、仕様例7件、対象を指定しない既定lake buildとsorry拒否。Rustの全lib等を追加していない |
| 公理監査 | audit.py→axioms.lean。終了0、38.49秒。694モジュール、68,367宣言、private/生成宣言を含む。新公理0、sorryAx0、許可三公理だけ |
| 集合・入力の再生成 | records.py。終了0。705 Leanソース、109＋標準7、旧31、76葉、56/60/64義務、23モジュール328API、100KB制限を確認 |

公理監査の生出力は11,941,086バイト、SHA-256 `e30ea58af2926e3f2025022fb35c06a15db273d52e58bb09ac40aabb5aa413cf`。全対象名は4,137,130バイト、SHA-256 `096bcd99f12d7809157bd478700bf040f70596a543a8be0c130facc8943aaae9`。一覧は [audit.py](audit.py) と [axioms.lean](axioms.lean) で現在の既定importから再生成できる。監査用の一覧を固定して新宣言を取りこぼす形にしない。匿名exampleと#guardは定数の一覧に現れないため、既定ビルドとソースの禁止構文の確認を併用する。

再生成はリポジトリの根から次の台本を使う。単独Leanと監査の-Mは12288、既定ビルドはlakefileの同じ上限を使う。監査→recordsの順序は対象一覧への依存による。実行がjsonを書き換えるので、再実行した結果の件数と本書を照合する。

```sh
python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l40/a/audit.py --tmp <tmp>
python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l40/a/records.py --tmp <tmp>
python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l40/a/keys/run_probe.py --tmp <tmp>
```

検査の入力はinventory.jsonの本番6モジュール・import・設定・道具固定・写し・元計画と引継ぎ・入力群のハッシュで特定する。全形式化ソースのmanifestは705ファイルのハッシュを持ち、そのmanifest自体の大きさとSHA-256をinventory.jsonへ保存した。Rust側は当該manifest/lock/固定版/型検査/IR/数値/標準ソースを記録する。最終workと監査後の本番の変更はない。記録と署名の説明文だけを仕上げた。結果を引用する際はこれらの同一性を照合する。今回の記録は2026-11-03の担当の自己点検であり、独立レビューやRust/Leanの全比較の証拠に読み替えない。

文書と入力の最終照合は [verify_records.py](verify_records.py) で再生成し、[completion-check.json](completion-check.json) へ保存する。初回の補助照合はコード内の型引数をMarkdownリンクと誤認して終了1となった。コードブロックを除いてリンクを読むよう直した。経緯は [completion-history.json](completion-history.json) にあり、本番Leanの失敗とは区別する。

## 計画との差と取りまとめへの申し送り

停止条件に該当する主な十言明の変更・新公理・独立の信頼条件・書ける形の縮小・提供範囲の削減・精密な外部状態の新設は行っていない。J40-1の規則の差も、J40-2の反例も検出していない。旧Release、処理系、plan/detail/README、レビュー記録を編集していない。

計画との差は、単位ごとの初期実装の外側時間が未採取であること、自己点検の修正により初期work後に最終workを実行したこと、公理監査を段末だけでなく今回の群でも再生成したことである。誤って取り除いた開始キーの前提は元へ戻し、局所失敗と修正の両方を残した。証明の範囲を弱める対策は採っていない。

| 残る手順 | 検査・測定・レビュー・受け入れの内容 | 見込み |
|---|---|---|
| 群A/F1の独立レビュー | F02の方式と全署名、具体Tableと5代表、109場合の失敗成分、追加前提の有無、写し、時間記録の未達を確認 | 不明。取りまとめが依頼 |
| J40-3の見直し | 末尾の引数・結果をU02の公開名/字面の判断時に設計者へ示す | 不明。設計者が判断 |
| 群Bと以降の実装 | signatures.mdを固定した入口として使用。群Bの最初の16目的とN_V=1/N_C=9だけを通常の記録から見直す | 群Bは3時間5分〜6時間5分の旧幅を維持。後続全体はplanの旧幅 |
| 段末の検査・レビュー・受け入れ | G群の既定ビルド・公理監査・取りまとめの正式RSS・独立レビュー、設計者のL40段末受け入れ | 未実施。時間不明 |

内部契約は以下のとおり確定したため、J40-3の内部引数未確定を理由に群D/Eを停止する状態ではない。依存群を実際に起動する判断と独立レビューは取りまとめが行う。新しい公開名の承認やU02の回答を今回得たとは扱わない。

## L40.05末の安全な入口の内部契約（J40-3・設計者の見直しの対象）

公開名と字面はU02で決める。以下は通常の依存列として固定した内部契約である。`A{p}`は引数自身の篩、`NE[T]`は`nonemptyType T`の別名、`CI/CL/CX`は同じ元値と欄を保持するCheckedInteger/CheckedLength/CheckedIndexの型を表す。CIはminimum≤value≤maximum、CLはlength=List.length(values)かつminimum≤length≤maximum、CXは0≤index<List.length(values)を篩として持つ。これらは証拠を別の値引数にせず、受ける値の型の篩として要求する。

| 内部の入口 | 受ける値と篩・返す型 | Leanの依存列 | 型に加えてLeanの実行の補題で保つ関係 |
|---|---|---|---|
| safeHead | xs:NE[T] → T | safeHead T | 同じxsの先頭。NEの条件は0<length xs。有限列の補題のxs≠[]への橋は群C/E |
| safeGet | xs:List[T], i:Integer{0≤self ∧ self<length xs} → T | safeGet T | 同じxsのi番目。Natへの写しとgetElem?の等号は群C/E |
| safeTail | xs:NE[T] → List[T]{length self=length xs−1} | safeTail T | 同じxsの残りの列 |
| CheckedIndex.get | checked:CX[T] → T | checkedGet n T | 同じchecked.element。元Listとindexを保持 |
| 同長の別Listへの参照 | checked:CX[T], ys:List[U]{length self=length checked.values} → U | sameLengthGet n T U | ysのchecked.index番目。ysも引数の型で型付けし、保持elementと同一視しない |
| Range.minimum | checked:CI → Integer{self=checked.minimum} | checkedIntegerProjection n 0 | 同じminimum欄 |
| Range.maximum | checked:CI → Integer{self=checked.maximum} | checkedIntegerProjection n 1 | 同じmaximum欄 |
| Range.value | checked:CI → Integer{self=checked.value} | checkedIntegerProjection n 2 | 同じvalue欄。入力CIが上下限の関係を保持 |
| Range.lengthMinimum | checked:CL[T] → Integer{self=checked.minimum} | checkedLengthProjection n T 0 | 同じminimum欄 |
| Range.lengthMaximum | checked:CL[T] → Integer{self=checked.maximum} | checkedLengthProjection n T 1 | 同じmaximum欄 |
| Range.checkedLength | checked:CL[T] → Integer{self=checked.length ∧ self=length checked.values ∧ checked.minimum≤self≤checked.maximum} | checkedLength n T | 同じlength欄と元Listの長さ、両端の関係を結果にも明記 |
| Range.lengthValues | checked:CL[T] → List[T]{length self=checked.length ∧ checked.minimum≤length self≤checked.maximum} | checkedLengthValues n T | 同じ元List。列全体の同一性は型の整数述語に符号化しない |
| Range.indexValue | checked:CX[T] → Integer{self=checked.index ∧ 0≤self<length checked.values} | checkedIndexProjection n T | 同じindex欄 |
| Range.indexValues | checked:CX[T] → List[T]{length self=length checked.values} | checkedIndexValues n T | 同じ元List |
| NonEmptyList.fromList | xs:List[T] → Result[NE[T], EmptyListError] | nonemptyFromList n T | Okは同じxs、Error(EmptyListError.EmptyList)は正常値。成功する返却の存在は要求しない |
| NonEmptyList.toList | xs:NE[T] → List[T]{0<length self ∧ length self=length xs} | nonemptyToList T | 同じxs |
| NonEmptyList.head | xs:NE[T] → T | safeHead T | safeHeadと同じ先頭 |
| NonEmptyList.tail | xs:NE[T] → List[T]{length self=length xs−1} | safeTail T | safeTailと同じ残りの列 |
| NonEmptyList.map | xs:NE[T], f:(value:T)→U ! E → List[U]{0<length self ∧ length self=length xs} ! E | nonemptyMap T U E | 同じ型付きcallbackの正常な有限実行。順序・失敗・効果を保持 |

上表のLeanの完全な定義はsafe-contracts.leanにある。型パラメータT/UはTy、潜在効果EはEff、nは実際のdata名とrecord構成子名を保持するNamesである。各後続の値参照の番号とTy/Effの移動を定義に明示した。名前やFieldRefが同じ宣言を指すこと、Annotation・型付け・本体と実行の関係の証明は群D/Eとソース収集の担当が行う。今回通したのはTelとしての型検査であり、これらの意味の証明ではない。safeHead/get/同長の参照について既存StandardBodiesの有限列の補題が支える部分と、この依存列への接続を区別する。既存のOption・Result APIは保つ。

## 再開1：RV-L40.aの処置

2026-11-03。RV-L40.aとplan先頭の重1・中1・中2の判断に従った。計画・詳細・README・レビュー記録・処理系・旧Releaseは変更しない。基準とブランチの指定は初回の値を保つ。今回の処置は群Aの固定した署名と代表の修正であり、F1のtracked_failure_soundの言明と証明、Success/SuccessAt、主な十言明と型付けの規則は変えない。

| 所見 | 処置・証拠 | 後段と判断 |
|---|---|---|
| 重1 | 値の逆転8枝を芯とfactsへ変更。varは元lookup型aと到達芯bについてT.norm.core=bとLeQ a.norm.core b、listはEach/Annotation・Listの芯・要素のLeQを返す。ValueInversionのHasTypeVQ.inv_var/inv_list_coreを既定ビルドで証明。const/con/checked系は既存の正しい逆転の型を引用し、atErrorは宣言したerrorTypeの芯を返す。signatures.py・signature-check.lean・signatures.mdの冒頭の表と完全命題を同期 | 群Bは証明済みinv_varを継承し、再証明しない。初期の旧移植14のうち1件を前倒しし、残りは値10＋計算3の13件。群B末のN_V=1/N_C=9は同じ。listは既済みの一般逆転にAnnotationと芯の等号を明示した強い入口 |
| 重1の反例 | 同じ値5のmonth_typedから、新しいinv_constの芯とfactsを返す。旧の「元の型全体からTへのLeQ」の全称命題の否定も核で証明し、新しい芯の結論と同時に成立する具体例を置いた | 新しい署名では0を同じ篩に入れる部分型関係を結論しないため、レビューの矛盾を生じない。旧署名を型検査だけで固定したことは誤りだった |
| 中1 | TelLe.open_tail/open_twoと、xの実値7をyの型{Integer | self=x}へ反映する7/7の具体例を証明。Ctx.WFなしの補助試行では、他の公開前提を含めてもSubstOk.openValueへ渡す文脈形成を供給できなかった。F02にhΓ:Ctx.WF 0 C.length Γを追加し、signature-extra.leanでも全列の型を検査 | 「Ctx.WFなしの言明が偽」とは証明していない。今回、なしで証明を得られなかったため、取りまとめが認めた前提を加えた。閉Γは自明。開ΓでCtx.Regularを持つ呼出し側はwf欄を使い、全開始入力からの供給は.11で照合する。主な十言明の前提は変更しない |
| 中2 | safe-contracts.leanに19行の通常の依存列を定義して型検査。safe-contracts.mdを唯一の説明の表とし、results/signaturesへ同じ表を写した。証拠は引数の篩で受ける。safeHeadはnonemptyTypeの0<length、ysの型付けは同長の別Listの引数型、CheckedLengthの結果には元length/実長/両端を明記 | 本体・Annotation・宣言との同一性・型付け・正常実行の関係の証明は群D/E。値や列全体の同一性はLeanの実行の補題で保ち、Integerの述語で一般の列等号を表さない。公開名と字面はU02。設計者の見直しの対象は上の同一の19行の表 |
| 軽1 | 代表のB.satはsatBそのもので、sat_eqはIff.rflであることを表の直後に追記。二列を独立な検査と数えない | 宣言収集とB.satの構成を照合するL70/R10bの接続を残す |
| 軽2 | 5代表にない篩付き鍵型、Float/Float32、非空Cの制約付き型変数、Set、Bytes、Option/Result、scoped/opaque/external/Reference/Lazy等をL40.22/R50へ名指し | 今回の5代表だけの一致を全carrierの一致としない |
| 軽3 | signature-extra.leanにjoinV/normalF/returnF/seqF/joinFを具体のdefとして置き、その定義の局所規則の型を検査。normalFの規則も追加。任意の関数についての命題は除いた | 署名用の補助入力であり、既定importに実装済みのフローの健全性を足したものではない。.33で同じ定義を本番化し、左右Memと実構成の所属を証明する |
| 軽4 | stopped/range_errorをIntervalFailure直下へ移し、本番の読者を更新。decimal_collectionsのdocstringを「値側の鍵構造を持つListとMapのKeyShapeを構成する」へ修正 | 必要性を証明したという誤読を除いた |
| 軽5 | 01-12のTelApplicationを部分型の段落の後へ移し、二引数とCtx.WFの実前提を記す。StandardContracts/Scalar/Bodiesは「標準契約と数値の正常応答」へ移した。07-04の行も節名を明記。ValueInversionの本番の範囲を同時に追加 | 計画や未証明の内部APIを設計書の実装済み規則にしない |
| 軽6 | effort-ledger.mdの二行を出どころとし、試行1約66分（容量の誤りによる停止）＋試行2約15分＝約81分を群全体の外側時間として追記 | 単位と群A/F1へ按分せず、能動時間へ外挿しない。再開1の時間は別記 |
| 情報1 | IntervalFailureの局所のmaxHeartbeats 2000000/maxRecDepth 4096を維持し、引き上げていない | F2で相互証明を広げる最初に、同じ上限のまま通るかを確かめる |
| 情報2 | 直接overflow/短絡/return後の番兵/深さ0・予算0は#guard、第一候補の具体適用・stopped・range_errorは核で検査する証明と記録 | #guardの有限検査と、第一候補の一般の証明・核の具体例を区別して後続へ渡す |

### 再開1の署名と実装の境界

F01/F03の8枝は、型検査だけの旧の命題を残さず、芯の関係と同じ値のfactsを返す形へ変更した。varでは構造の共変・反変や範囲の拡大を許すため、元lookup型の芯から到達芯へのLeQを保持する。芯の子をすべて等しいとする変更ではない。constの芯は同じtag、listの要素はLeQ、conの引数はTypeArgsLe、checked系のHoldsは芯のscoped/opaqueの等号と被覆で読む。

この判断はplan先頭で了承された内部の署名の修正であり、V_RefineやLeQの規則を変更しない。F02も元文脈の形成を内部の適用補題へ加えたもので、CoreAssumptionsや主な十言明へ新しい独立の信頼条件を加えていない。

安全な入口の19行とF07の五つの定義は、型検査できる署名の入力として改造に置く。新しい公開APIの実装や、意味の健全性の証明を仮置きする定理ではない。証明を群D/E/F2へ渡すための完全な型・定義であり、sorryや新公理を使わない。signature-checkの47命題も、今回のvar/listと既存の供給元以外の全枝を証明済みと呼ばない。

### 再開1の検査と時間

最終結果はresume1-checks.json、局所試行・失敗・修正・既定ビルドの出力の識別はresume1-local.jsonへ記録する。生の出力は一時領域に置き、各記録は100KB以下に保つ。最終の公理監査・work・入力照合の件数と時間は以下へ追記する。

| 最終検査 | 終了 | 外側の時間 | 内容 |
|---|---:|---:|---|
| signature-check | 0 | 0.72秒 | F01/F03の47命題 |
| signature-extra | 0 | 0.67秒 | Ctx.WF付きF02、F03セル、具体のF07定義と局所規則 |
| safe-contracts | 0 | 0.64秒 | 安全な入口の19行の依存列 |
| audit | 0 | 38.57秒 | 全既定importの公理監査（台本全体） |
| dry-run | 0 | 0.12秒 | 指定基準での選択確認、--onlyなし |
| work | 0 | 3.81秒 | 仕様の参照集計・仕様例7件・既定全Leanとsorry拒否 |

単独の既定 `lake build` も対象指定なしで終了0（956 jobs）となった。外側時間はこの単独実行では別採取なしであり、最後のworkの計測と混ぜない。生成のログとSHA-256はresume1-local.jsonのbuild行にある。workは `scripts/check.sh --level work --base 2a2453825e956404fbe82d0a586d8776f323150a` を再開1の最後の状態へ一回実行し、onlyを追加していない。公理監査は内側のLeanの実行38.25秒、上表のaudit行はPythonの照合も含む外側の時間である。

現在の監査は **695モジュール・68,392宣言**、新公理0、依存はpropext・Quot.sound・Classical.choiceの部分集合だけである。新7モジュールの監査対象は485宣言（TelApplication27、StandardKeyTyping68、StandardContracts179、StandardScalar72、StandardBodies8、IntervalFailure114、ValueInversion17）。現在の手書きの名前付き宣言は106件、初回からの増分は9件（TelApplicationにopen_tail/open_twoと二引数の準備2件、ValueInversionにprivateの芯の補題2件・逆転2件・旧署名の否定1件）。匿名の具体例と自動生成宣言をこの手書きの数へ含めない。

全対象の生出力は11,947,085バイト、SHA-256 `deb8e4ce311f35c5237a83d149ed71d2f5a145cb8ace05b34df4c010b7f3b71c`。対象一覧は4,139,343バイト、SHA-256 `61130c308343361e9ed41fb54ef580f7bae9134ed21056dae112feb6eff2b34d`。audit.py/axioms.leanは新モジュールを含めて一覧を再生成する。全本番入力のmanifestは706 Leanソースを識別し、inventory.jsonへmanifest自体の大きさとハッシュを置く。declarations.jsonとobligations.mdも現在のソースから再生成した。初回の14/7/10という旧31の分類は配分の記録として保ち、前倒ししたvarを別欄で識別する。

再開1終了時のsignatures.mdは **85,941バイト**、47命題とAPI328行、安全な契約の19行、五つのフローの定義を含み、100KB以下である。直接規則の二重の写しを除き、完全命題の節を正とした。全記録の100KB制限、入力ハッシュ・リンク・既定import・本番の禁止構文、二文書の同じ安全な契約の表はverify_records.pyで照合する。最終workと監査後の本番の変更はない。

再開1の時計の区間は07:23:15〜07:50:28 UTC、外側約27.2分である。最初の時計取得前の読取りと、本記録の追記・最後の照合は区間の外であり、作業全体の厳密な時間とはしない。能動時間と待ちは未分離、単位へ按分しない。初回の群全体の約81分と再開1を別に記録し、RSSは未取得（計画上の非採取）とする。再開1の区間と出どころはresume1-time.jsonに保存した。

### 再開1の申し送り

重1・中1・中2・軽1〜6・情報1〜2の担当分を処置した。署名の修正は内部の補題の範囲であり、主な十言明・型付けの規則・旧Release・処理系は保った。群Bはvarの既済み分を控除し、群D/Eは上の依存列の引数と結果を正とする。今回の型検査をsafe APIの本体の証明に読み替えない。J40-3は同じ19行の表を設計者のU02の見直しへ渡す。独立再レビューと群の受け入れ、後続の起動は取りまとめ・設計者が行う。


## 再開2：NonEmptyList.fromListの内部契約の修正

2026-11-03。RV-L40.a末尾「再レビュー（再開1）」の新しい中1・軽1を対象とする。基準は `2a2453825e956404fbe82d0a586d8776f323150a`。本番のLean・処理系・既存APIの実装は変更しない。

| 所見 | 処置と判定 | 証拠・申し送り |
|---|---|---|
| 中1 | 処置済み。NonEmptyList.fromListの内部契約を `xs:List[T] → Result[NE[T], EmptyListError]` に修正。Namesのoptionをresult・emptyListErrorのdata名へ替え、nonemptyFromListの結果を二型引数のResultにした | 現行NonEmptyList.bntのResult.Ok/Result.Error(EmptyListError.EmptyList)に対応。safe-contracts.lean・safe-contracts.md・本書・signatures.mdの表と埋込み定義を同期。Okは同じxs、Errorは正常値として扱う。公開名と字面はU02に残す |
| 軽1 | 実装の処置は不要。申し送り済み | 群E（L40.26）の最初に、一つの具体のNamesについてAnnotation（WF・Sorted・Declared）と実際の宣言との対応を示す。今回のTelの型検査をこれらの証明と数えない |

### 再開2の検査と外側の時間

検査の終了・外側の時間・生出力の大きさとSHA-256はresume2-checks.jsonへ記録する。作業末のworkはchecks.jsonにも保存する。本番706 Leanソースは再開1のmanifestと全件同じハッシュであり、新たな宣言・公理・importの変更はない。依頼の条件に従い、独立のlake buildと公理監査は再実行せず、再開1の公理監査の記録を保つ。

| 検査 | 終了 | 外側の時間 | 内容 |
|---|---:|---:|---|
| safe-contracts | 0 | 0.67秒 | 安全な入口19行のTelを単独Lean（-M 12288）で型検査 |
| dry-run | 0 | 0.11秒 | 指定基準で自動選択を確認、--onlyなし |
| work | 0 | 3.72秒 | 仕様の参照集計・仕様例7件・既定全Leanビルドとsorry拒否 |

workは `scripts/check.sh --level work --base 2a2453825e956404fbe82d0a586d8776f323150a` を一度だけ実行し、終了0。指定基準からの既存差分によりformal_buildも選ばれた。単独のlake buildを追加したものではない。今回の修正後の公理監査の再実行はなく、保存した対象一覧と再開1のaudit-summary.jsonを使用する。全本番入力の同一性はmanifestのハッシュで再確認した。

signatures.mdは **86,041バイト**で100KB以下。safe-contracts.mdの同じ19行の表がresults.md/signatures.mdに含まれること、埋込み定義とsafe-contracts.leanの一致、入力ハッシュ・保管サイズ・リンク・禁止構文をverify_records.pyと再生成時の照合で確認する。検査の生出力は一時領域に置き、大きさとSHA-256をresume2-checks.jsonに保存した。

再開2の時計の区間は08:02:20〜08:03:59 UTC、外側99.47秒（約1.7分）。最初の時計取得前の読取りと、この追記後の最終照合は区間外。能動時間と待ちは未分離、RSSは未取得（計画上の非採取）。区間の出どころはresume2-time.json。依頼の2所見の担当分は処置済みで、追加の計画変更・設計者への新しい判断依頼はない。J40-3の設計者による見直しと公開名・字面のU02は従前のとおり残る。

## 作業末の work

取りまとめが、RV-L40.a の再レビュー（再開2）と並行して、Refinement の生成物を消してから、sandbox の外で macOS の `/usr/bin/time -l` を付けて一度実行した。

| コマンド | 終了状態 | 外側の時間 | 最大常駐量 |
|---|---|---:|---:|
| `scripts/check.sh --level work --base 2a2453825e956404fbe82d0a586d8776f323150a` | 0 | 163.44秒 | 1,539,276,800 バイト |

選ばれた検査は、仕様対応の自己検査・集計、仕様例（7件成功・失敗0・無視0）、既定の Lean ビルドと `sorry` の拒否である。機械は Apple M4・メモリ 32 GiB、OS は macOS 27.2。最大常駐量は `/usr/bin/time` が報告した、`check.sh` とその子のプロセスのうち最大のものの値であり、計測器自身の分と分けていない。
