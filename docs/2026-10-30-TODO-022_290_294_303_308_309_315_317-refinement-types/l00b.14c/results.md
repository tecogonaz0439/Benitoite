# L00b.14c: Reference と StoreOk の代表の結果

2026-11-01。**分類は「閉じた（本書に記した代表の言明が閉じた）」である。** 新規作成・get・set・update の4種類について、開始の StateTyE を逆転して到達の StateTyE を導き、実際の Step と組にする入口まで閉じた。到達の閉包・状態の型付けを入力に仮定していない。レビューの t3 は旧 CoreAssumptions の不足による update の保存の反例であった。今回、承認された強化でその表を拒否し、型付き update の開始から展開を導いた。snapshot の Φ を閉じて保つ D19 の方式が破れる反例は得ていない。全状態の保存を完成したとはしない。

指定ブランチは `m014/l00b.14c`、B_WORK は `b5a00e9aed5eb80022b01e135aaffd6f7783ff01` である。起動依頼の値を記録し、git による HEAD の照合・切替・作成・コミットは行っていない。処理系・設計書・plan・既存のレビュー・rv-* は変更していない。作業末の work は指定どおり取りまとめに残し、L00b.14d は起動していない。

## 閉じた定義と補題

本番の新規モジュールは [ReferenceStore.lean](../../../formal/Benitoite/Release/Refinement/ReferenceStore.lean)・[ReferenceCalls.lean](../../../formal/Benitoite/Release/Refinement/ReferenceCalls.lean)・[ReferencePreservation.lean](../../../formal/Benitoite/Release/Refinement/ReferencePreservation.lean) の3本である。既存の変更は `formal/Benitoite.lean` の import 1行と、`Refinement/ConstraintAssumptions.lean` の承認済み強化である。新規3モジュールの公開宣言は定義2本・補題29本、完全署名は [public-api.log](public-api.log)、契約の採否は [signatures.md](signatures.md) にある。

| 群 | 閉じたものと役割 |
|---|---|
| ストア型の追加 | StoreTy.put・extends_put。既存の場所を保存して、新しい場所を加える |
| 既存の型付けの移送 | HasTypeVQ.store_extend・GuardBodyTy.store・ContTy.store・CellOk.store。既存の CaptureOk.store・ClosureTy.store を使う |
| StoreOk | write_reference・allocate_reference。有限性、WF、Declared、領域条件、全既存セルの移送を示す。割当ては実ストアとストア型の両方を広げる |
| 引数列の逆転 | HasTypeTelArgsQ.pullback。TelClosure の推移を含めて入力の反変と結果・効果の関係を取り出す。中間の型付けを仮定せず、補助の論理の Transport で tail の文脈を狭める |
| 呼出しの逆転 | HasTypeCQ.primitive_call・ClosureTy.pure_primitive。fn/dependentFn、V_Sub/V_Normal/V_Refine、C_Sub/C_Normal/C_Eff、空の捕捉に存在しうる Φ を扱う |
| 参照の型付き入力 | BuiltinArgs.reference_new/get/set/update。閉じた内容型と実引数、結果型・State の等号を返す |
| 状態の保存 | StateTyE.reference_new/get/set/update。開始のストア・継続を取り出し、同じ最終結果型・Eb へつなぐ。CellOk.val_write/val_read の正規化後等号を使う |
| 実際の遷移 | Closure.pure_primitive_view と4本の reference_*_transition。型・行引数を正規化した view で、実際の Step と保存を同じ開始入力から返す |
| 戻り先の閉じ方 | ClosureTy.pure_return。開始の pure 閉包のソースの R と閉じ方を再利用し、R の WF を新たに要求しない |
| snapshot と観測 | CaptureOk.reference_write_snapshot・reference_no_sort・reference_no_observation・reference_no_observed_fact。書込み後も同じ捕捉と閉じた事実を保つ |
| update の展開の型付け | ReferencePrimitives と Builtins.CoreAssumptions.reference_primitives。任意の閉じた適格な内容型について get/set の型付けを導き、update の保存の内部で使う。別仮定 hops と到達の型付けは受け取らない |

代表の呼出し元は `Closure.pure` である。new/set の保存だけの補題から未使用の hc を除いた。実際の Step と組にする入口は closeVal で実引数が変わらない実行時の値を扱い、get は読み出す値を制限しない。継続・既存ストア・最終の結果型・Eb は任意であり、内容型は篩を含んでよい。update の状態の代表は実行時の closure を関数値とする。展開先の計算の型付けは、内部の update_body で任意の関数値について閉じている。

## 場合の数の予定と実際

| 対象 | 予定 | 実際 |
|---|---:|---:|
| 参照の実際の Step | 4 | E_RefNew・E_RefGet・E_RefSet・E_RefUpdate の4場合。各々に開始 StateTyE からの保存と Step の組がある |
| Cell の移送 | 初回に7形と記した | 定義を照合して6形へ訂正。builder・val・thunk・done・cont・used をすべて扱う。構成子の増減ではない |
| builder の内容 | 上の内数 | string・bytes・list の3適合形と、不適合な組合せを扱う |
| ContTy | 10 | K_Sub と K_Guard を含む10構成子 |
| GuardBodyTy | 1 | mk の捕捉・ソースの本体・局所参照を移す |
| 引数列の逆転 | 開始の逆転の補助として追加 | 実引数の空/cons と、done/param。TelClosure の refl/tail をどちらの形でも扱う |
| 値 / 計算 / 相互三族 / Step | 29 / 24 / 76 / 76 を維持 | 同じ。監査入力が件数を照合した |
| 公開宣言 | 初回は群ごとの署名 | 定義2本・補題29本の31宣言 |
| 元の let の実行 | ref・get・set・返却の列 | let の分解と返却を含む9遷移 |
| 境界の公理依存 | 境界の全宣言 | 239宣言。非公開の補助と生成された宣言も含む |

## 境界の正例と負例

[boundary.lean](boundary.lean) は具体の宣言表・組み込み表を定義し、その CoreAssumptions を構成する。結論の型付けや事実を仮定していない。組み込み表は new/get/set/update のみを持つ。新しい ref_get/ref_set と value kind の条件を含めた CoreAssumptions を構成し、get/set の型付けは CoreAssumptions.reference_primitives からも導く。

| 入口 | 確認した内容 |
|---|---|
| program_typed・program_start・execution | `let r = ref(3); let x = get(r); set(r,9); x` のソースの型付け、開始の StateTyE、実際の9遷移。最後の view は ret 3、実ストアの現内容は9 |
| snapshot_capture・snapshot_write | get が返した3を捕捉する capX に、閉じた評価から `x < 8` の Φ を加える。同じ捕捉を CaptureOk.store で保ち、書込み後の StoreOk と閉じた事実を得る |
| body_reads_snapshot・body_needs_snapshot_fact・final_typed | Φ を使って返り値の Integer{self < 8} を導く。Φ を除くと同じ本体は型付かない。実際の最終状態をこの捕捉から型付ける |
| 元のソースの型と追加の Φ の区別 | program_start の結果型は Integer である。元の get が静的に self < 8 を推論したとはしない。追加の Φ は実際の snapshot 3 の閉じた評価から作る。全 let の途中状態の一括した保存は今回の代表の外である |
| pure_*_start・*_saved・new_pair/get_pair/set_pair/update_pair | 4代表の保存と遷移の組を、具体に構成した開始 StateTyE に適用する。update は型付きの恒等閉包を使う |
| reference_not_integer_observation・no_live_predicate | Reference の変数を整数として読んで現内容を述べようとする形は型付かない |
| RefField.value_typed・partial_observation | Reference と整数を欄に持つ名目 data を型付け、根を dataValue、参照欄を none、不変な整数欄を some 3 として観測する |
| RefField.missing_field・immutable_field・live_fact_fails・live_field_undeclared | 参照欄の観測は失敗し、隣の不変な欄は成功する。参照欄を整数と宣言する FieldRef は宣言と合わず、閉じた述語の評価も none になる |
| RefField.root_shape・actual_match・root_fact・root_exclusion | 型付きの同じ data から RootShape を構成する。実際の firstAlt の成功/失敗から、根の構成子の事実と後続の構成子の除外を導く。欠落の参照欄を補っていない |
| snapshot_match_step・snapshot_match_body・snapshot_matched_fact・match_snapshot_capture・match_body_reads_snapshot | セルを9へ変えた後も整数の snapshot 3 を match する。実際の成功から事実を閉じて捕捉へ加え、その等号を使う本体を型付ける |
| BoolSnapshot.get_step・if_after_set・select_old_true | Boolean の get の実際の遷移と、その結果の CaptureOk を構成する。セルを false にした後も snapshot は true のままであり、経路条件を使う真枝へ実際の Step と開始 StateTyE から進む |
| guard_cannot_set・guard_with_set_untyped | guard が要求する Eff.empty では State の set を直接行えない。後者は Boolean を返す let を対象とし、結果型の不一致を理由にしない |
| pending_after_write・extension_guard | 書込み後の保持は Ψ.Extends.refl による移送である。CaptureOk と GuardBodyTy は μ に依存しない。実質の検査は新セルの割当て後の extension_guard・extension_capture にある。guard は純粋であり、その本体の前に set が挟まる実行を主張しない |
| extension_store/capture/closure/value | 既存の参照と空でない Φ を持つ状態へ新しい参照を割り当て、既存の StoreOk・CaptureOk・ClosureTy・値の型付けを移す |
| raw_cell_write・raw_cell_read | 生の格納型 Unit{true} に対して、正規化後の Unit の読み書きを CellOk の契約で行う。StoreOk に Normal/Sorted の欄を追加していない |
| le_strengthen_fails・le_weaken_fails・le_under_false | Reference の内容型は強化も弱化もできず、矛盾した Φ でも変わらない |
| loc_not_small・nine_not_small・cell_rejects_nine・reference_var_no_sort | Integer のセルを篩のセルとして使えない。9 は self < 8 のセルへ格納できない。Reference の別名も述語のどの sort でも読めない |
| store_small・read_small・small_primitives | 空でない篩の内容型を持つセルの割当てと読出し、抽象の構成補題からの型付き get/set |
| small_get_pair・small_set_pair | Integer{self < 8} を内容型とする呼出しについて、具体に構成した開始 StateTyE から実際の Step と到達の保存まで示す。セルの水準に留めていない |
| raw_primitives | 非正規形の Integer{true} の型引数にも、正規化像の get/set を CoreAssumptions から導く |
| t3_not_core | rv-14c-t3 と同じ表は、新しい StoreShape の value kind 条件を満たさず、CoreAssumptions を持たない。条件の強化が反例を実際に除く |
| model_get_contract/model_set_contract・modeltargets_*・modelhttp_* | 旧3モデルの実表の Reference の存在・PrimKind と、embedTParam 後の value kind を6本で照合する |

境界の作成時の関門は signatures に記録した。セルの現内容を観測可能にする、data の全観測を落とす、ストアの移送で Φ を捨てる、既存セルの移送を落とす退行を、本番の判断・遷移・閉じた評価の入口で検査する。

## 補助の契約で決めたこと

| 採った案 | 理由と捨てた案 |
|---|---|
| 状態へ経路条件を追加しない | 閉じた事実は CaptureOk の構成にだけ使う。別の Φ や精密な外部状態を状態へ追加する案は採らない |
| ストア型と実ストアを対で拡張する | StoreOk の領域条件を満たす。実セルなしの型の追加だけを拡張の保存とはしない |
| 不変な捕捉は既存の store 補題で移す | facts の証拠を再利用し、可変セルの現内容を読まない |
| 閉じた呼出しの逆転を先に作る | 到達を仮定した同時構成では、今回の開始 StateTyE の要件を満たさない。論理の Transport を使って TelClosure の推移も扱う |
| CoreAssumptions の承認済み強化から get/set を導く | 存在と PrimKind の二欄だけでは不足するため、StoreShape の参照4種に型パラメータの value kind を加える。ReferencePrimitives の別仮定を残す案は採らない |
| update の関数値は実行時の closure とする | この代表では rename が値を変えず、閉性と Adequate を保つ。全 callable の改名の閉性は L20 に残す。利用者の記述や既存の型付け規則をこの形へ制限しない |
| 正規化した型引数で実際の view と照合する | 非正規形の生の ts を update の到達へ残す案では実際の Step と一致しない |
| R の閉じ方を開始の閉包から再利用する | ret のために現在の R の WF を追加要求する案は採らなかった |
| guard 内の直接の set は負例とする | 既存の guard は Eff.empty を要求する。例を通すために効果の規則を変更しない |

主な既存定理の前提の変更は、承認された CoreAssumptions の強化だけである。HasTypeVQ/HasTypeCQ の結論とほかの前提、新しい公理、提供範囲、利用者が書ける形、精密な外部状態は変更していない。

## 再開時の前提の変更とレビューの処置

| 対象 | 変更前 | 変更後 |
|---|---|---|
| CoreAssumptions | ref_get/ref_set の存在の欄なし | 旧 Assumptions と同じ形の二欄を追加 |
| StoreShape の参照4種 | 型パラメータの個数だけが1 | 加えて `s.tparams.map TParamDecl.kind = [.value]`。force は変更なし |
| reference_update / reference_update_transition | CoreAssumptions と別の ReferencePrimitives 入力 | 強化した CoreAssumptions と開始の型付けから導く。hops は除く |
| reference_new / reference_set | 保存だけの補題にも未使用の hc | 保存だけから除く。遷移と組にする入口には view の照合のために残す |

`reference_primitives` の注釈・Normal・Ordinary・value kind の条件は、任意の未型付けの型引数を認めるという意味ではない。型付き update の SignatureInstance・PrimitiveAdmissible が既に要求する条件であり、保存の定理に別の前提を加えていない。

Model・ModelTargets・ModelHttp は旧体系の Builtins を持つモデルであり、篩の Builtins へ表全体を埋め込む定義は現在ない。今回の6本はその実表の Reference の存在と追加した kind 条件の照合である。旧モデルの全 Assumptions と全利用先は既定ビルドで閉じ直し、公理監査にも残した。篩側では境界の4項目の表が強化した CoreAssumptions を実際に満たす。IO モデル全体の新しい体系への埋め込みを完成したとはしない。

| 所見 | 処置 |
|---|---|
| 中1 | 承認された存在欄と kind 条件を追加。抽象の B から ReferencePrimitives を導き、update の別仮定を除いた。t3_not_core で不正な表を拒否し、3モデルの実表の Reference 条件を照合した |
| 軽1 | t1 の不変性の負例7本と、その補助・セルの正例を boundary へ写した。rv-* の原本は変更なし |
| 軽2 | セルだけでなく small_get_pair・small_set_pair の呼出しの水準まで閉じた |
| 軽3 | 保存だけの new/set から _hc を除き、transition の hc の用途を署名に明記した |
| 軽4 | signatures の旧入力の記述と採否の表を更新し、旧方式を現在の契約として残さない |
| 軽5 | 書込み後の保持は refl、実質の検査はストア拡張であることを明記した |
| 軽6 | L20 の行で s4・s7 を名指しし、f の仮引数名 value の条件を L30 の Rust 照合へ送った |

## 残り・送り先・義務行

次の見込みは残る部分の案であり、新たな段の起動や計画の更新を指示するものではない。L20/L40 の既存の枠の内数とし、取りまとめが重複を確認する。

| 送り先 | 残る言明・依存 | 見込み時間 |
|---|---|---|
| L20 | 任意の捕捉を持つ呼出し元、特に s4 の `.mk capR` による get と s7 の `.mk capX` による set の closeVal の型保存、実際の view・Φ の閉じ方の合成。今回の pure の逆転を置き換える一般化 | 2〜4時間 |
| L20 | 全 callable の rename について閉性と Adequate を保ち、update の closure 代表を一般化する。計算の型付けの update_body は既に任意の f で閉じた | 1〜3時間 |
| L20/L40 | 全 let の途中状態・全状態の保存と進行へ合成する。今回の9遷移と始点/終点の型付けだけを全体の保存としない | 不明（既存の全状態の枠） |
| L30 | O054 の開いた Boolean の定数の相異と等号の合同。加えて形式側の update の f の仮引数名が value に限られる条件と、名前の異なる lambda を Rust が受け取るかを照合する。既存の形の差の入力であり、今回は Rust を変更・検査していない | 不明（既存の割当て） |
| L00b.14d | Lazy のセルは結果型が共変であり、Reference の正規化後等号による不変位置と区別する。CellOk.store と ContTy.store の thunk/done/K_Update の場合、既存の ClosureTy.store を使える | 次作業の1〜3時間の内数。本作業からは進まない |
| 独立レビュー・取りまとめ・受け入れ | 定義・言明・仮定、開始の逆転、代表の限定と残件、検査記録の確認。work は取りまとめが実施する | 不明（担当外） |

O051 の Reference/snapshot/StoreOk の代表は本書の範囲で閉じた。O046 は既存の閉じた評価を捕捉と match/if へ接続する代表を確認した。いずれも全状態の O 行全体を完了へ変更していない。O160 の分類と残りの再提示は取りまとめに残る。

計画からのずれは、開始の逆転に必要な引数列・primitive の補助を新規に閉じたこと、update の実際の正規化像を明記し、再開時の承認を受けて get/set の別仮定を CoreAssumptions からの導出へ置き換えたこと、Cell の初回の誤数を訂正したことである。未承認の信頼条件や結論の弱化によって埋めていない。

## ビルド・公理依存・時間

[verify.py](verify.py) を実行した。機械の記録は [verification.json](verification.json)、公理依存の集計は [axioms-summary.json](axioms-summary.json) である。既定の lakefile の Lean の上限は -M 12288、単独の Lean にも -M 12288 を付けた。

| 検査 | 終了・件数 | 外側の時間 |
|---|---|---:|
| cd formal && lake build | 終了0、既定725ジョブ。新規3モジュールを既定 import に含む | 0.154秒 |
| boundary.lean | 終了0、239宣言の公理依存も確認 | 2.446秒 |
| public-api.lean | 終了0、全31公開宣言の完全署名と2定義の本文 | 0.606秒 |
| axioms.lean | 終了0、144モジュール・15,160宣言の報告。新規3モジュール・変更した ConstraintAssumptions・集約の包含を台本で確認 | 13.000秒 |

許す propext・Quot.sound・Classical.choice 以外の依存はなく、sorryAx の依存もない。変更対象の本番ソースに sorry/admit/axiom の追加はない。既存のモデルの仮定充足、旧定義との限定対応、既存 Release の進行・保存・効果健全性も監査入力に残した。これは新しい全状態の主定理を完成したという意味ではない。

ビルドには既存モジュールの lint とリンカの環境の警告があり、境界には未使用の simp 引数の警告がある。新規の本番3モジュールの局所検査は警告なしで通した。検査を短くするための上限・対象・期待値の緩和は行っていない。

100 KB を超える公理依存の生出力は改造内に置かず、[large-records.md](large-records.md) に1,638,000バイトと SHA-256 を記録した。変更対象の5ソースのハッシュは [source-delta.json](source-delta.json)、Refinement・旧3モデルと Assumptions・ビルド設定の入力は [source-inputs.json](source-inputs.json)、境界・台本・変更しない rv 入力のハッシュは [boundary-inputs.json](boundary-inputs.json) にある。これらは git の差分を取得した記録ではない。

初回の作業の外側の時間は約42分であった。今回の再開は UTC 2026-10-31 21:59:44 から約12分である。途中の局所検査を含み、能動時間と待ちの完全な分離はしていない。正式な最大常駐量は未取得（計画上の非採取）。独立レビューと受け入れは担当外であり、本作業では実施していない。

再開前の source-inputs のハッシュと照合すると、既存の本番ソースの変更は ConstraintAssumptions と ReferencePreservation の2本だけであった。HasTypeVQ/HasTypeCQ の定義とその他の主な補題のソースは変わっていない。rv 入力のハッシュは verify.py で固定して照合し、境界へ写した負例は新しい条件の下で再検査した。旧条件を構成する rv-14c-t3 の原本を、新しい CoreAssumptions を満たす入力として再実行したとはしない。

## 作業末の work

取りまとめが実行した。基準は `b5a00e9aed5eb80022b01e135aaffd6f7783ff01`、コマンドは `scripts/check.sh --level work --base <基準>`、選ばれた単位は `formal_build` だけで、終了状態は 0、外側の時間は 78.21 秒である。実行の前に Refinement の生成物を消した。
