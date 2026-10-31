# L00b.11: 正規化と構文の逆転の実装結果（RV対応済み）

2026-10-31。B_WORK は `5fd3664ed92b4eb20de0ba422e9e55c825019aff`、指定ブランチは `m014/l00b.11` である。git の操作は行っていない。OS 再起動前の差分を保持して再開し、中断した移行を完了した。

D07 の篩の平坦化・truth の除去・非依存 dependentFn と fn の接続を本番へ入れ、三族、TypedFacts、閉包、Sorted/Declared/References と全利用先を閉じ直した。既定の `cd formal && lake build` は711 jobsで成功した。O001・O007 の本作業の実装は完了であり、独立レビューと受け入れは取りまとめへ残す。L00b.13 は未着手である。

## 変えた定義と閉じた補題

完全署名と判断は [signatures.md](signatures.md)、公開する全宣言の完全署名は [public-api.lean](public-api.lean) と [public-api.log](public-api.log) にある。

| 範囲 | 定義と閉じた内容 |
|---|---|
| 篩と連言 | Pred.conjuncts/ofConjuncts/conjNorm、Ty.core/refinementPredicates/packRefinements/refineNorm。芯から外への順序を保ち truth を除去して一定の括り方で再構成する。順序・重複・falsity は保持する |
| 関数の正規形 | NamesWF を持つ FnView、toTel の単射性、fnView?、foldFn。toTel の像である非依存の dependentFn を fn へ畳む |
| 正規化 | Ty/Tel/Eff.norm_idem、norm_refined_truth、norm_toTel、norm_reconstruct、norm_refineNorm、norm_foldFn。Normal は WF とは別の固定点の判断である |
| rawApply | refined の下へ再帰する。rawApply_packRefinements/core/predicates/norm、移動・置換・範囲写像と rawApply_ordinary を帰納で閉じた。型引数は移動せず保持する |
| 交換 | Ty/Tel/Eff.norm_rawBind、norm_shiftV/norm_shiftTypes、bind_sameTypes、無制限の subst_norm_images/typeImages/rowImages/allImages、埋め込みの embedTy_norm/embedEff_norm、比較順。Ty.bind は rawBind の後に norm を行う |
| 構文の逆転 | listCore/fnCore/refCore、LeQ の左右の逆転、TelLe.of_norm_eq、TelClosure.trans、names_eq、canonical の inv_list/inv_closure/canonical_ref。推移・篩・V_Sub/V_Normal の連鎖から実際の情報を得る |
| 不変位置 | Reference の内容と Fail の型は norm 後の構造等号を返す。要素型間の LeQ だけに置き換えない |
| 適格性 | WF/Sorted/Declared/References の norm・移動・置換保存、Ty.Annotation.norm、Ty.WF/Tel.WF/Eff.WF の境界の拡大、Ty.assume_of_wf。ValueRegularity・DeclaredTransport を含む全利用先を更新した |
| 型付けの保存 | TypeShiftContracts/TypeShiftTyping、TypingShift、SubstTyping、Narrowing、TypedFacts の全場合。公開する主な移動・値の相互置換・narrowing の定理の前提と結論を保った |
| 閉包と文脈 | SubstOk.telAnnotation、of_arguments、Capture/ClosureTyping、Context/WF/Facts/Declarations/Capture、Sorted/Declared、HandlerAlgebra/HandlerTyping。元の注釈の位置と実行時の格納データを保ち、静的な比較を norm へ揃えた |

## 取りまとめの第三案

rawApply は `refined a p => refined (rawApply a as) p` を使う。篩の束縛は述語だけに及ぶため、as の移動は不要である。rawApply_norm と、型の像の正規化に対する置換の合同性は、ProperApply や kind の限定なしで証明した。kind は適切な適用を逆転する入口で使う。SignatureInstance・V_Con・V_Dict に前提を足していない。

型付けの制約は正規形に対する判断へ揃えた。SatAll の各型、V_Map/V_Set と ExternalCarrierEach の鍵は norm、PrimitiveAdmissible.admits の型列は normTys を読む。sat_shiftTypes_raw/admits_shiftTypes_raw/SatAll.shiftTypes と値の置換は、既存の信頼条件、Annotation.norm、norm と各変換の交換から導いた。Builtins と ValueAssumptions/TypeAssumptions/SubstitutionAssumptions の信頼条件の欄は強めていない。欄が量化する判断の意味の変更は、RV対応の節に示す L00b.15 の新旧対照で扱う。

B.valContent も生の型を返すため、V_CheckedRequest、CheckedWitness.request、AtCallAdmissible の静的な入力の照合を同じく norm へ揃えた。表の欄は保ち、元の入力の導出は V_Normal により新しい読み手で利用できる。Val.subst・Val.shiftEAt などの項の変換の意味、実行時の受信値、外部状態の定義は変更していない。

[source-kind-contract.md](source-kind-contract.md) の二案と [type-shift-contract.md](type-shift-contract.md) の二候補はいずれも不採用である。ソース kind の新しい検査で導出を制限する案、生の値置換で項の型引数を変える案、TypeAssumptions を強める案、Val.shiftEAt を正規化する案は採らなかった。判断待ちの項目は残っていない。

## 規則の必要性と場合の数

| 対象 | 必要な箇所と、既存の部分型変換では足りない理由 | 実装 |
|---|---|---|
| V_Normal | V_Var・型付き像・生の閉じた場所の型を正規化する。V_Sub は行き先の WF/Sorted/Declared を要求し、元の変数の導出や WF だけからは Sorted が出ない | 帰納的規則を1個追加 |
| C_Normal | 一般の計算結果を正規化する。元の C_Resume 等は結果の Sorted を要求せず、C_Sub の行き先の Annotation を一般には作れない | 帰納的規則を1個追加 |
| C_DependentAppNorm | 正規化で fn へ畳まれた関数を適用する。TelArgs の終端から結果の Annotation を取得できるため、既存の C_App/C_DependentApp と C_Sub/LeQ.convert で導出可能 | 独立した構成子を削除。同名の補題と dependentApp_normalized を置いた。FnView の有無の2場合を閉じた |
| C_ResumeNorm | 生の cont 束縛を保つ移動・up/params・narrowing の後で b.norm の入力を読む。b の Annotation がない位置では、入力を生の b へ戻せない。C_Normal は入力の照合を変えない | 帰納的規則を1個追加。結果と効果は t.norm/e.norm、Declared も t.norm を検査 |
| C_ResumeLNorm | 生のストアの cont と置換後の R を照合する。C_Sub/C_Normal は R を変えない。閉じた R の値置換も R.norm になり、生の格納 R と一致しないことがある | 帰納的規則を1個追加。実際の格納 R' を保持し R'.map norm=R.map norm を検査 |

[normalized-rules-boundary.lean](normalized-rules-boundary.lean) は、元の導出と、変換先が Sorted でないことを同時に示す。結論の型付けや逆転の結論を前提にしていない。再開の変数版には、入力の生の Annotation を持たず正規形で読める例を置いた。[resume-return-contract-obstruction.lean](resume-return-contract-obstruction.lean) は、場所版の新規則の正例に加え、元の C_ResumeL の導出、Builtins の全置換仮定、StoreTy.WF、SubstOk、経路条件、局所置換を独立に構成して、同じ正規化した R を置換主定理から得る。

| 判断・族 | 予定の基準 | 最終 | 増分 |
|---|---:|---:|---:|
| Ty | 21 | 21 | 0 |
| Ty.LeQ | 12 | 13 | convert 1 |
| TelLe / TelClosure | 2 / 2 | 2 / 2 | 0 |
| HasTypeVQ | 28 | 29 | V_Normal 1 |
| HasTypeCQ | 21 | 24 | C_Normal と再開の2規則で3 |
| ImageOk | 3 | 4 | hidden 1 |
| 三族の対象の合計 | 71 | 76 | 各族で5。値1＋計算3＋ImageOk1 |
| LocalRef.HasKind | 2 | 3 | normal 1。71の場合表の外 |
| ProperApply | 7 | 7 | 0 |

これらは [axioms.lean](axioms.lean) が Lean の構成子情報から検査する。移動・値の相互置換・narrowing の各族を76場合に追随させた。TypedFacts の観測・事実・参照・宣言照合・data の逆転も、V_Normal と LeQ.convert の場合を閉じた。

型の健全性に必要な適格性は、元の規則の判断に従って保存した。V_Normal/C_Normal は元の Annotation があるとき Annotation.norm を使える。再開の結果 t.norm の WF は Ctx.WF または StoreTy.WF の lookup と Ty.wf_norm から得る。Declared は新規則の前提で検査し、Sorted が元にあるときは Ty.sorted_norm で保存する。元の規則が Sorted を要求しない位置で、無条件の Annotation を主張したものではない。新しい規則のために主な三族の定理へ適格性の前提を足していない。

## 補助契約で決めたこと

1. 連言は芯から外へ順序を保つ有限列とし、truth だけを除去する。falsity・順序・重複は残す。論理同値や並べ替えを型の等号へ入れない。
2. fn の NamesWF を保つ FnView の像だけを fn へ畳む。条件を満たさない dependentFn はその構造を保つ。
3. ImageOk.contVar は実際の cont の lookup と正規化後の等号を保持する。一般の up/params へ新たな WF や Normal の前提を足さない。
4. ImageOk.hidden は ¬Ordinary かつ生の cont でもない読めない束縛を表す。WF と hidden が両立しないことを証明した。実際の継続や通常値にこの枝を使えない。
5. Ordinary・assume・hideConts を cont の芯の扱いに揃える。assume は順序付きの原子的連言の列であり、norm の前後で一致する。WF な型の assume は refinementPredicates と等しい。元の述語と列の事実は Entails で相互に導く。
6. narrowing の私有 ContImages は、生の同じ束縛か、実際の cont・正規形の等号・元の型の Annotation を保持する。元の Annotation は Narrows.here の既存の前提から得る。主定理の元の結果へ C_Sub で戻せるため、公開の narrowing の言明を変えない。
7. SubstOk.telAnnotation は、型全体を fn に畳んだ注釈と、Tel.bind の外側に生の dependentFn を付ける注釈を区別して保存する。
8. 閉じた型の bind/close も norm を返す。固定点が必要な補助の入口にだけ Normal を明記し、一般の型付け・署名の入力には課さない。
9. 継続場所の R は正規化後の等号で照合する。ストアに保持した元の R を書き換えない。生の等号を返す旧補助補題が偽であることを示し、正規化後の等号を返す補題へ改訂した。
10. 受信前の Outcome.Carrier と、受信後の元の型を持つ HasTypeV の区別を保つ。今回の正規化を理由として受信検査の証拠を省略しない。

## 撤回と訂正

取りまとめが撤回を認めた WF の固定点に加え、その固定点を根拠にしていた偽の補助補題は具体的な否定を Lean で示して訂正した。三族の主定理を撤回していない。

| 旧主張 | 訂正 | 否定の入力・補題 |
|---|---|---|
| 任意の WF 型・型列は正規化の固定点 | Normal と norm_idem | normalization-obstruction、raw_not_normal |
| 閉じた WF 型・構築器・Tel の置換は生のまま | 型/Tel/構築器の norm を返す | closed_value_subst_not_raw、closed_builder_subst_not_raw、closed_tel_bind_not_raw |
| instantiatedTel の dependentFn の像は生の dependentFn | norm 後の等号、Tel.bind の等号 | instantiatedTel_raw_equality_false |
| renameTypes と生の shiftTypes の等号 | shiftTypes の後の norm | raw_renameTypes_not_raw_shift |
| TelArgs.normal/instantiate/arguments と逆向きの of_arguments は任意の生の Tel で同じ結果を返す | 固定点が必要な補助に Tel.Normal を明記 | done raw empty による tel_normal_without_premise_false、tel_instantiate_raw_result_false、tel_arguments_raw_result_false、of_arguments_without_normal_false |
| ClosureTy.pure は a/R が非正規形でも生の結果・R を返せる | a.Normal と R の内容の Normal を明記 | pure_without_normal_false、pure_without_return_normal_false。ClosureTy の結果と R が Normal であることから否定 |
| contView は LeQ から生の成分の等号を返せる | norm 後の等号 | continuation_raw_components_differ |
| resume_location_contract は格納 R と結論 R の生の一致を返す | 実際の格納 R' と R'.map norm=R.map norm を返す | old_resume_location_contract_false。WF なストアと元の置換主定理の全前提も満たす |
| 不適格な refined-cont の変数・truth の fact を使う古い境界例 | source_variable_untypable と空の fact に訂正 | NarrowingObstruction。元の例は b_not_wf も満たす不適格な型に限られる |

rawApply_norm、subst_norm_images の無制限の形は撤回していない。以前の ProperApply/kind の限定版は第三案で不要となったため消した。型移動の旧反例も正例へ反転し、判断待ちとして残していない。

## 境界入力

| 入力 | 確認した内容 |
|---|---|
| [boundary.lean](boundary.lean) | V_Sub の連鎖から List の要素と LeQ、閉包から TelClosure と names_eq、実際の closeVal(.lam) を fn で読む導出と逆転、Reference と Fail の等号、kind の適切な適用の逆転、偽の共変性や名前変更の拒否 |
| [normalization-boundary.lean](normalization-boundary.lean) | T{true}=T、篩と連言の括り方の一致、並べ替えの不一致、falsity・重複の保持、ソースと像の双方に篩がある置換の括り方の一致 |
| [normalization-obstruction.lean](normalization-obstruction.lean) | 新定義で解消する旧反例を正例へ反転し、WF の固定点等の偽の旧主張の否定を保持 |
| [normalization-contract-obstruction.lean](normalization-contract-obstruction.lean) | 無制限の subst_norm_images の正例、篩付きの頭での rawApply の型引数の保持 |
| [typing-normalization-obstruction.lean](typing-normalization-obstruction.lean) | 前回の full_substitution_counterexample の元の導出が現在は成立しないこと、値 kind の篩付きの像と適切な構成子適用の正例。V_Normal を含む全29場合 |
| [type-shift-normalization-obstruction.lean](type-shift-normalization-obstruction.lean) | 同じ生の型引数 Unit{true} の操作値を、元の導出と shift_types の全前提から移動する正例。Unit と制約が同じこと、残る述語は別の型であること。生の sat/admits の保存の否定自体は保持 |
| [normalization-retractions.lean](normalization-retractions.lean) | 撤回した閉じた補助署名の具体的な否定。結論の型付けを仮定しない |
| [normalized-rules-boundary.lean](normalized-rules-boundary.lean) | 新規則の入口、Sorted がないため V_Sub/C_Sub に渡せない型、導出可能な関数適用、適格性の保存、hidden と WF の非両立 |
| [resume-return-contract-obstruction.lean](resume-return-contract-obstruction.lean) | 正規形の等しい R の場所の再開、旧の生の R の等号の否定、元の C_ResumeL の導出に全前提付きの置換主定理を適用する正例 |

## ビルド、公理依存、記録

検査は [verify.py](verify.py) で再現できる。既定の lake build、関係モジュール、元の9入力とRV対応で追加した入力、全モジュールの公理依存、公開署名を検査する。すべての Lean プロセスには `-M 12288` を付ける。既定ビルドは lakefile.toml の同じ設定を使う。

RV対応前の最終13検査はすべて終了0であった。その時点で公理依存を確認した宣言は13,760個で、依存は propext・Quot.sound・Classical.choice だけであり、sorryAx はない。全130対象モジュールを監査でき、未コンパイル・対象外の候補はない。

RV対応前の既定ビルドは0.155255秒、最大常駐量73,596,928バイト（約70.2 MiB）であった。公理監査は11.677410秒・1,681,588,224バイト、公開署名の列挙は19.980666秒・1,699,840,000バイトであった。これらは再起動後に全移行を閉じた後の最終再検査の値である。

検査の終了コード・実時間・最大常駐量は [verification.json](verification.json)、公理依存の集計は [axioms-summary.json](axioms-summary.json) にある。公理監査は差分候補をすべて含む Refinement 全129モジュールと Benitoite の集約モジュールの全宣言を対象にし、私有・生成宣言も省かない。境界入力の宣言も監査する。許す依存は propext・Quot.sound・Classical.choice だけである。

資源計測の最初の試行では `/usr/bin/time -l` が sandbox 内の sysctl を読めず、ビルド成功の後に計測用のプロセスが終了1となった。その記録は [time-wrapper.log](time-wrapper.log) に分けた。最終検査は wait4 の ru_maxrss で対象プロセスの資源統計と本体の終了コードを記録する。最終の既定ビルドは増分ビルドであり、以前の方式との同条件の全面再ビルドの性能比較ではない。再起動前の同条件の最大常駐量も不明なため、増減を断定しない。

ソースの実差分の記録は74ファイル（既存60・新規14）を [source-delta.json](source-delta.json) に列挙した。再起動後に以前の控えが残っていなかった追加分の以前の SHA-256 は null とし、基準版との正式な照合は取りまとめへ残す。公理検査は候補の漏れを防ぐため全129モジュールへ広げた。検査したソース・入力・台本のハッシュは [inputs-sha256.json](inputs-sha256.json) にある。100 KBを超える生の記録は `<tmp>` に置き、[large-records.md](large-records.md) に大きさと SHA-256 を記録した。

## 義務と後続への申し送り

| 義務 | 実装の判定 | レビュー・後続 |
|---|---|---|
| O001 | 完了。List・fn/dependentFn の逆転、推移・篩・V_Sub/V_Normal の連鎖、TelClosure・names_eq、実際の閉包を fn で読む正例、三族と全利用先を閉じた | 独立レビューで正規化と規則の追加を確認する。全 canonical forms は当初の L40 の範囲 |
| O007 | 完了。Reference/Fail の不変位置を、新しい norm 後の構造等号で一般化し正負の入力を検査した | L00b.13 以降は生の型の等号や意味上の包含へ読み替えず、この等号を使う |

L00b.13 は、値29・計算24・ImageOk4、三族76場合を前提にする。LocalRef.HasKind の normal と LeQ.convert も扱う。Builtins の制約は正規形で読み、表と項の生の型引数は保持する。継続の入力と R の比較、および valContent の静的な読み手も正規形に揃える。今回の D07 の本体や三族の証明を後の段へ送らない。

L20 の Rust の検査器には、順序・重複を保つ篩の正規形、非依存 dependentFn と fn の接続、rawApply の refined の枝、正規形に対する sat/admits/鍵/valContent の照合を対応させる義務が増える。新しい四規則を同じ条件で読み、C_DependentAppNorm を独立の規則として数えない。継続の格納型は元のまま持ち、型付けは正規化後の R の等号を検査する。後続の状態の保存では、StoreOk の下で生の R の等号を導いて連結に使う。ContTy.end_normal・ClosureTy.return_normal・resume_raw_return により、その等号を作れる。受信前の Carrier と受信後の元の型の証拠は区別する。

| 残る手順 | 担当・範囲 | 見込み |
|---|---|---|
| 独立レビュー | RV-L00b.11-request。完全署名、規則の必要性、撤回した偽の補助補題、全差分と検査記録 | 不明 |
| 基準版との正式な差分照合、work、取り込み、受け入れ | 取りまとめ。担当は git と work を実行しない | 不明 |
| L00b.13 以降 | 受け入れ後に取りまとめが起動する。本作業では着手しない | 不明 |

処理系・設計書・plan.md・既存のレビュー記録・rv-* は変更していない。許可された contracts.md の rawApply_norm とレビュー依頼を更新した。主な定理の結論・信頼条件の欄・提供範囲・精密な外部状態は変更せず、新しい公理も置いていない。補助契約の変更と偽の補助補題の訂正は上の一覧のとおりである。

## 外側の時間

今回の再開は2026-10-31 13:56:00 UTCである。最終の検査時刻と今回の経過は末尾の最終照合欄に記す。中断前の r3 は12:19:34 UTCに始まったが、中断時刻と実行中だった資源計測は再起動後には確定できないため、今回の時間へ合算しない。それ以前の11:31:33〜12:17:01 UTCの45分28秒とも分ける。能動時間と待ち時間は分離していない。


RV対応前の最終照合: 2026-10-31 14:56:39 UTC。前回の外側の時間は1時間00分39秒であった。開始から10時間の上限以内で実装と検査を完了した。今回のレビュー対応の時間と検査結果は次節に分ける。


## RV-L00b.11 の対応（2026-11-01）

[レビュー](../reviews/RV-L00b.11.md)の取りまとめの追記と、plan の2026-11-01の判断を適用した。中1・中2を本番へ入れ、軽1・軽2・軽3・軽5・軽6を補題・境界・義務の記録で対応した。軽4の全面ビルドの時間の確認は、指定どおり取りまとめが work で行う。本担当は work を実行しない。

### 中1: 組込みの遷移の入力

Semantics の delta 2規則（E_Prim/E_Err）と ioResponse 3規則（E_IO/E_IOErr/E_Exit）、Step の delta と IO oracle の入力を、`Ty.normTys ts` と `es.map Eff.norm` にした。項の `.prim b ts es rs` と rs は保つ。BuiltinArgs の Canonical の欄、Builtins、ResponseAssumptions の欄、Val.subst、Val.shiftEAt を変えていない。

本番の instantiatedTel_norm_images は型・行の像の正規化で具体化後の Tel が変わらないことを無条件に示す。PrimitiveAdmissible.norm、TypeArgsKinded.norm、SignatureInstance.norm_images、NoFail.norm、HasTypeTelArgsQ.effect_wf を補助とし、BuiltinArgs.normalized が raw の許容・署名・実引数列・Ground から、正規化した型・行引数の BuiltinArgs を作る。Canonical を外す変更はない。

step と Step の対応は、影響を受ける5場合の step_prim_val/step_prim_err/step_io_val/step_io_err/step_io_exit を本番で閉じた。各補題は raw の q.view を保ち、正規化した delta または IO oracle/応答から、step の計算結果と Step を同時に返す。NoHandler.splitHandler_none を併用する。旧体系の主定理や、Refinement 全体の step_sound の言明は変更していない。

[review-builtins-boundary.lean](review-builtins-boundary.lean) の original_args_normalized は、レビューと同じ delta=none の表と `.prim "p" [raw] [] []` の入力から、正規化した BuiltinArgs を構成する。元の rv-11-primraw の args_rejected も負の入力として通る。

delta_entry/io_entry は、同じ値について型付けを構成し、delta_typed/io_exists の応答を Step と step に使う。こちらは応答仮定の全欄を実際に構成した表を使い、delta=none の表へ成立しない応答仮定を置いていない。非空の行引数を使う instantiatedTel_norm_images の正例も含む。これらの正例は遷移や型付けの結論を仮定しない。

### 中2: 参照のセルの読み書き

StateTyping の CellOk.val を `HasTypeV P B Ψ [] [] [] v a.norm` にした。StoreOk に Sorted/Normal を足していない。CellOk の done/thunk/cont/used と、実行時のセルの定義は保つ。

本番に CellOk.val_write、CellOk.val_read、StoreOk.reference_read を置いた。元の値の型付け・Adequate と lookup に加え、canonical_ref が返す `b.norm=a.norm` と、値の型の a.Normal だけで照合できる。格納型 b の Sorted、Normal、Annotation は要求しない。

[review-store-boundary.lean](review-store-boundary.lean) は、格納型が Unit{true} の参照を持つ StoreOk を構成する。格納型が Normal でないことも示す。同じ参照の canonical_ref から得た等号で書き込みの CellOk を作り、StoreOk.reference_read で Unit の値を読み出した。新しい反例や停止を要する前提の追加はなかった。

### 軽の対応

| 所見 | 対応 |
|---|---|
| 軽1 | レビューの ContTy.end_normal と resume_raw_return、および補助の closeR_normal/ContTy.empty_ret を StateTyping に移した。Capture.closeRAt_normal/ClosureTy.return_normal も本番に置いた。申し送りを「StoreOk の下で生の等号を導いて連結に使う」へ具体化した。R を付け替える76場合の補題は不要 |
| 軽2 | signatures に L00b.15 の新旧対照と L60 の義務を追加した。制約の読み手、導出の増加、遷移の型・行入力の正規化、CellOk.val の変更を対照する。欄名が同じことだけを意味の維持と呼ばない。実表の sat/admits を正規形の上で定める義務を明記した |
| 軽3 | [review-lambda-boundary.lean](review-lambda-boundary.lean) に rv-11-lam の引数付きの閉包の正例を保存した。実際の closeVal(.lam ["x"] [Unit{true}] body) を fn ["x"] [Unit] Unit で読み inv_closure で逆転する。DependentClosureTy.normal を本番に置いた |
| 軽4 | 全面ビルドの時間は取りまとめが work で確認する。既存の探索上限を今回さらに広げていない。本担当の最終計測は増分ビルドとして記録する |
| 軽5 | 全28場合を29へ訂正し、Ty.Normal を Ty.Canonical の別名にした。旧「既存57」は BindCongr を含む候補数で、レビューの実差分は56であった。BindCongr を一覧から外し、今回新たに変更した BuiltinResponse/Semantics/Step/StateTyping の4件を加え、現在の既存60・新規14へ訂正した |
| 軽6 | L20 に fnView? の決定手続きと Lean の存在の定義との一致を示す義務を明記した。移動を戻す手続き、NamesWF、一意性を照合する |

今回の変更で構成子は増減していない。HasTypeVQ29、HasTypeCQ24、ImageOk4、三族76、Step76 を再検査した。新しい本番ファイルはない。主な定理の言明、信頼条件の欄、提供範囲、利用者の書ける形、精密な外部状態を変更していない。

[review-contracts.json](review-contracts.json) は、BuiltinArgs/ResponseAssumptions の欄、Builtins を含む Syntax、信頼条件、Val.subst/Val.shiftEAt を含むファイルがレビュー対応前と一致することと、CellOk では val だけが承認どおり変わったことの照合である。レビューから写された rv-11-* の入力・台本と既存のレビュー記録は編集していない。git を使う rv-11-sigdiff.py は実行していない。

### 検査と申し送り

verify.py に今回の3つの境界、rv-11-primraw と rv-11-count を追加した。元の9境界と合わせて14入力、既定ビルド・関係モジュール・公理監査・公開署名の計18検査を行う。全130モジュールの私有・生成宣言も引き続き監査する。rv-11-ret は本番へ移した同名の宣言を含むため原本を再定義せず、本番のビルドと公理監査で確認する。rv-11-* の原本は入力のハッシュへ含めた。

L00b.13 は未着手である。L00b.13/L20/L40 は、新しい CellOk.val の読み書きと、StoreOk からの生の R の等号の導出を使う。L00b.15 は制約・導出・遷移・CellOk の新旧対照と01-12への反映を受け持つ。L60 は正規形に対する実表の sat/admits と応答条件の充足を、L20 の Rust の検査器への対応は fnView? の決定手続きとの一致を受け持つ。

| 残る手順 | 担当・範囲 | 見込み |
|---|---|---|
| 再レビュー・受け入れ | 取りまとめ。中2件の正例と補題、軽の記録を照合する | 不明 |
| work と全面ビルドの時間の確認、取り込み | 取りまとめ。担当は実行しない | 不明 |
| L00b.13 以降 | 受け入れ後に別途起動する | 不明 |


RV対応の最終検査: 18検査はすべて終了0。既定の lake build は711 jobsで成功した。全130対象モジュールと追加境界を含む13,948宣言の公理依存は propext・Quot.sound・Classical.choice だけであり、sorryAx と未監査の対象はない。

最終の増分ビルドは0.154717秒、最大常駐量71,909,376バイトである。公理監査は11.610920秒・1,684,078,592バイト、公開署名の列挙は20.159404秒・1,700,397,056バイトであった。既存の探索上限を含む全面ビルドの時間の評価は取りまとめへ残す。

今回の所見対応は2026-10-31 15:16:11 UTC（2026-11-01 00:16:11 JST）に開始し、最終照合は15:35:51 UTCであった。外側の時間は19分40秒で、4時間の上限以内である。前回の作業時間とは分け、能動時間と待ち時間は分離していない。

## 作業末の work

取りまとめが sandbox の外で実行した。基準は `5fd3664ed92b4eb20de0ba422e9e55c825019aff`。Refinement の生成物を消してから `/usr/bin/time -l scripts/check.sh --level work --base 5fd3664ed92b4eb20de0ba422e9e55c825019aff` を実行した。選ばれたのは `formal_build` だけで、終了0、外側の時間 64.09 秒、最大常駐量 1163132928 B である。L00b.05 の作業末の 63.61 秒・1159430144 B と比べて増加は小さいので、RV-L00b.11 の軽4の file 単位の探索の上限は宣言へ絞らない。
