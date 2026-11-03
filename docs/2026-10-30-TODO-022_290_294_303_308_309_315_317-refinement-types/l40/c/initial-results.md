# L40 群 C の実装結果（初回の履歴）

現在の判定は [results.md](results.md) の再開1を正とする。以下の完了/未完と検査結果は旧規則で停止した時点の記録である。

2026-11-03。**L40.12〜.14の局所の担当分を実装し、L40.15で停止した。群Cは未完であり、全開始から76葉への供給を完了とは判定しない。** 停止の反例と代案は下表、B15の全22行は [start-inputs.md](start-inputs.md)、76葉の現在値は [leaves.md](leaves.md)、義務の全64行は [obligations.md](obligations.md)に記す。確認は担当の自己点検であり、独立レビューと受け入れは取りまとめ・設計者の担当である。

基準 B_WORK は `4d27a9306e76b51f0686d04338a574053755dd4d`、指定ブランチは `m014/l40.c`。切替・作成・コミットその他のgit操作は行っていない。共通依頼文、detail全体、群Aの固定署名、群Bの確定した差・開始入力表、両群のレビューと取りまとめの追記、planの停止・外挿・先頭五判断、READMEの2026-11-03の決定を参照した。勧告は既存の2026-10-30の引継ぎどおりとし、依存・固定版の更新を相乗りしていない。

## 停止の反例と変更前の差

[obstruction.lean](obstruction.lean) は、任意の同じP・B・固定σについて次を核で証明する。

| 宣言 | 再現した事実 |
|---|---|
| `CaptureLambda.raw_typed` | 零引数でUnitを返す生の `lam [] [] (ret unit)` は現行の値型付けを持つ |
| `CaptureLambda.capture` | 空捕捉へこの同じ生lambdaを加えたものは現行のCaptureOkを満たす |
| `CaptureLambda.state` | その捕捉の `var 0` を零引数で呼ぶ閉包、空継続・空ストアは現行StateTyEを満たす |
| `CaptureLambda.direct_lambda_closes` | ソースに直接書いた同じlambdaはcloseValでclosureになる（正側） |
| `CaptureLambda.captured_lambda_remains`・`view` | 捕捉した値を `closeVal cap (var 0)` で読むと、生lambdaのままである |
| `CaptureLambda.no_runtime_closure` | 同じq.viewを `app (closure runtime body) ws` とする証人は存在しない |
| `CaptureLambda.formed_application` | WellFormed・WellTyped・CoreAssumptionsを受けると、既存app_inputsから同じ生lambdaのAnnotationと依存実引数列は得られる。F02の形成不足が原因ではない |
| `CaptureLambda.stateTy` | σ.Validの下では、空の末尾効果のBuiltinOnlyも満たすStateTyを作れる |
| `CaptureLambda.no_step` | 任意のevent・destについて、同じ状態からのStepは存在しない |

原因は `closeVal` のvar枝が捕捉値をそのまま返し、`ImageOk.ordinary` がその値の型付けを要求する一方で生lambdaを除かないことにある。`E_Lam` はclosureの構文だけを受ける。型付きの関数を八構文へ分けるcanonical_function自体はこの生lambdaを正しく返すが、そこからclosureの実行葉へ進む言明は成り立たない。`CaptureWF`から完全なCtx.WFを補う変更でも解消しない。

| 固定した内容・未証明の言明 | 反例との差 | 今回の扱い |
|---|---|---|
| detail F03の「実際のq.viewで生lam/dependentLamがclosureに変わる」接続 | 直接のlamは変わるが、型付き捕捉のvarから読むlamには変換がない | この全称の接続は証明できない。lam一例で十分であり、dependentLamの別反例の完成までは主張しない |
| L40.15の全開始を第6節76葉へ供給 | 上のStateTyE/StateTyに適用できるStepが76葉のどれにもない | B15-Capture/B15-Fn-lamと76葉の全供給を停止 |
| 主な十言明・F01〜F03・型付け・CaptureOk・Step | 問題を直す案はこの境界の一部へ触れる。独立の実行時値条件を勝手に足せない | 変更0。反例を根拠に取りまとめの判断へ戻す |
| 群Aで固定し群Bで改めたF02/F03 | app_inputsと元列のAnnotationは反例にも適用できる。F02の四前提の削減を戻す理由にはならない | 署名変更0、使わない前提の追加/削除0 |

| 代案 | 必要な変更と証明の範囲 | 所要・待ちの見込み | 実用への影響 |
|---|---|---|---|
| 実行時の値の条件を型付き捕捉・セル・応答に保持する | 生lam等をソースと実行時の値で区別し、CaptureOk/ImageOk/StateTyE等と閉じ方・保存の全読者を追随する。主定理が量化する判断の定義へ触れる | 未取得。まず30〜60分の影響調査で対象と本証明の見込みを作る。全追随・ビルド・レビュー待ちは不明 | ソースのlambdaは維持できる候補だが、許す内部状態を狭める。利用者の書ける形を狭めないことと抽象応答の量化の維持を別に確認する必要がある |
| 捕捉から読む際に実行用の形へ変換する | closeValのvar枝等の像を変更する。型付け、代入/閉じ方の交換、同じ値の保持、閉性・意味・継続・セルの読者を追随する | 未取得。まず30〜60分の影響調査。残りと検査/レビュー待ちは不明 | 関数呼出しを継続できる候補。任意の捕捉値の再閉鎖が型と意味を保つことは未証明 |
| 生lam/dependentLamの呼出しにも実行規則を用意する | 適切な空捕捉で実行する規則又は共通の適用関数を設計し、閉性・元契約・保存と実行関数との一致を証明する。76葉の固定表と後続署名の扱いを改める | 未取得。まず30〜60分で必要な規則と影響読者を調べる。全証明・レビュー待ちは不明 | ソースの受理範囲と任意の型付き開始を保つ候補だが、実行規則を増やす。今回の担当が無断で選べない |
| 到達可能な状態だけに主定理を限定する | StateTyEからの無条件の進行という量化を弱める。必要な到達不変条件を別に証明する | 未取得。独立レビューと設計者の判断が必要 | 宣言した保証の範囲に影響するため、既定の修正案として採らない |

所要の上表は本証明の見積りを装う数字を置かず、判断前の短い影響調査と未取得の範囲を分けた。どの代案も実装していない。L70へ未証明の仮定として押し込む申し送りはしない。取りまとめには、反例の独立レビュー、変更してよい境界と再開の署名の指定を求める。

## 単位の時刻と完了条件（UTC）

開始・終了は各時点でresults.mdへ追記した値である。読取り/準備と停止後の保存・検査はこの表の外であり、能動時間の集計ではない。

| 単位 | 開始 | 終了 | 外側の秒 | 現在の判定 |
|---|---|---|---:|---|
| L40.12 | 2026-11-03T09:41:22.906355+00:00 | 2026-11-03T09:44:56.583973+00:00 | 213.678 | 完了。scalar/List/data・atError・空篩と元導出の読者 |
| L40.13 | 2026-11-03T09:44:56.584036+00:00 | 2026-11-03T09:46:26.592945+00:00 | 90.009 | 完了。保持値/外部/PathBases/ScopePatternの直接前提 |
| L40.14 | 2026-11-03T09:46:26.593002+00:00 | 2026-11-03T09:49:09.258941+00:00 | 162.666 | 完了。場所2規則、全6セルと保存継続の入力 |
| L40.15 | 2026-11-03T09:49:09.258999+00:00 | 2026-11-03T09:55:55.394239+00:00 | 406.135 | 未完。型付きの生lambdaの実開始にStepがないため停止 |

RSSは未取得（計画上の非採取）。L40.12〜.14の完了は局所の逆転とその読者に限り、全開始の合成まで完了した意味ではない。canonical_function等の全形の読者の最終照合は.15の作業中と停止後の検査で補い、先の単位の時刻を遡って書き換えていない。

L40.15の50〜100分は、今回の起動依頼で指定されたB15全22行を含む枠として扱う。ただし、早期の反例で停止したため、この枠で全行を閉じられる実績は得ていない。群の2時間15分〜4時間25分、上限8時間50分とL40段の15〜35時間の枠は改めない。待ち/読取りを完全に分離できないのでc_V/c_Cは未取得である。旧同種残件はlocの1件を本番に供給し、計算9目的は下書きの局所検査までで、本番接続がないため `N_V=0/N_C=9/N_g=9` とする。

## 本番の変更と範囲

| 本番 | 追加した入口・利用した既存の証拠 | 現在の境界 |
|---|---|---|
| [CanonicalValues](../../../../formal/Benitoite/Release/Refinement/CanonicalValues.lean) | canonical_scalar/boolean/list/data、inv_atError、Inhabits.not_falsity。型付けの29構成子を場合分けし、V_Sub/Normal/Refineの鎖を処理。Listの元導出は既存inv_list、dataの元導出はinv_con/dataCore_sourceを利用 | 意味から構文を推測しない。全てのscalar tagを量化し、七幅/Byte/Character/Float二幅/Decimal/String/Boolean/UnitをConstの実形で分ける。不透明定数はHoldsの入口で別に扱う |
| 同上 | canonical_function/map/set/bytes/dict/external/pathBases/scopePattern/held。型の全21形と値の全25形を型付けの導出から分類。各公開入口を元規則の逆転と組み合わせる匿名の適用例 | 関数は八構文の選言であり、捕捉元の生lambdaを自動でclosureへ変換する定理にはしない |
| 同上 | inv_externalRef/externalHandle/pathBases/scopePattern。保持値3形はHeldValuesの既存逆転を利用し、atErrorは七欄と同じResultShape.Declaredを返す | 全有効σとIOの対象一致はL50、外部応答の存在/モデルはL60 |
| [ExternalStateLeaves](../../../../formal/Benitoite/Release/Refinement/ExternalStateLeaves.lean) | 非公開external_invの証明を公開inv_externalRefへ移し、既存external_applyの本番読者をそちらへ変更 | 独立の新しい信頼条件や応答条件を加えない |
| [CanonicalCells](../../../../formal/Benitoite/Release/Refinement/CanonicalCells.lean) | inv_locのref/lazyの直接二枝、StoreOk.ref_cell/lazy_cell/cont_cell/builder_cell、reference_cell_inputs | 同じΨ/μ/σ。Referenceはa.norm、Lazyは元内容とLeQを保つ。contはEndsWithHandle/ContTy又はused。builderの専用型と内容を保つ |
| [01-12](../../../design/01-spec/01-12-core-calculus.md)・[07-04](../../../design/07-quality/07-04-formal-semantics.md) | 本番に置いた2モジュールと前提・結論を反映 | 反例の経緯や未実装の修正候補を設計書へ書かない |

新しい公開術語は加えていない。CanonicalValues内のtypeCode/valueFormは非公開の証明用の有限分類であり、言語の型/構文/意味の定義ではない。

[computation-inputs-draft.lean](computation-inputs-draft.lean) は開始逆転の下書きである。match/lazy/use/handleの2規則/resumeの変数と場所の各2規則/meth/builderLet/builderOp/external/issuePathBases/checkAtについて直接前提・元結果LeQ・外効果Coversを返す12入口を局所Leanで検査した。**本番の新モジュールではない。** 76葉の読者をつなぐ前に停止したため、既定importや完了件数へ加えない。既に公開した入口を既定importから外した操作は行っていない。

## 署名と作成時の関門

群AのF01/F03と群BのF02/F03の確定署名を変更していない。今回の外部・PathBases・ScopePatternの逆転は固定署名どおり元の型からのLeQを返す。これらの値のtoTerm?はnoneなので、V_Refineの枝は観測項の等号と矛盾する。scalar/List/data/atErrorは芯の対応とfactsを分ける規約を保つ。セル4入口は群Aのsignature-extraの全引数と固定σを維持する。

適用例と反例にはtest-auditの作成時の関門を適用した。持ち主の境界は、型付き導出から取り出す値の構文・同じ実セルの契約・実際のStepへの接続である。意味だけのfn/map等の枝は任意の値を許すので、この構文上の逆転を代用できない。公開入口を元の逆転へ組み合わせる読者は、構文だけ返して元の直接前提を落とす退行を検査する。今回の停止の対照は、同じlambdaの直接の閉じ方と捕捉変数の閉じ方であり、別の型エラーによる拒否ではない。本番のテスト用の差し込み口は作っていない。

## 検査と公理依存

検査のコマンド・開始/終了・外側の秒・終了状態・生出力のbytes/SHA-256は [checks.json](checks.json) を正とする。生出力は `<tmp>/l40-c-checks/` に置き、改造内に大きなログを保存していない。局所検査の初回の型/存在束縛の誤り、contセルの四添字の等号の取り出し、BuilderCellOkの従属matchの展開を修正して再確認した。最初の記録器導入前の局所Leanと最初の既定buildの出力はツールの出力だけにあり、完全な生ログのhashは未取得である。その最初のbuildはCanonicalCellsで終了1、修正後のbuild-cellsとbuild-finalで終了0になった。

Leanは `leanprover/lean4:v4.34.1`、単独Leanは `lake env lean -M 12288`、既定ビルドはformal/から対象を指定しない `lake build` である。Pythonのpy_compileだけは環境の既定キャッシュ先への書込みが許されず終了1になった。台本の実行はリポジトリ内又は一時領域への明示した出力を使い、その後の検査で確かめる。

公理監査は [audit.py](audit.py) と [axioms.lean](axioms.lean) を用いる。全既定importの新旧宣言に加え、obstructionと計算逆転の下書きを同じ監査入力へ写し、private・生成宣言を含む名前を環境から再生成する。対象名の一覧とprint axiomsの一対一の一致、許可三公理だけへの依存を台本で確かめる。最終件数とhashは次の最終検査表とaudit-summary.jsonを正とする。

workは指定のB_WORKでdry-runを確認し、`--only`を付けず作業末に一度だけ実行した。内容は既定全Lean/sorry拒否と差分で選ばれる仕様対応・仕様例であり、Rust/Leanの全比較や新しい主定理の証明の代用にはしない。最終結果は次表のとおり終了0である。

## 完了条件の照合と残る判断

| 条件 | 判定 |
|---|---|
| .12のscalar/List/data、空篩、atErrorの分離 | 局所の担当分完了。全形の読者と空篩の所属の排除を本番へ置いた |
| .13の8形、同じ要求/端点/名目ID/snapshot | 局所の担当分完了。既存保持値3形を再証明せず元の前提を使う |
| .14の場所2規則・全6セル・7枠の保存した証拠 | 局所の担当分完了。継続は全7枠/10規則を保持するContTyのまま返し、捕捉の全位置を強めない |
| .15のB15全22行を一行ずつ判定 | start-inputs.mdへ記録。閉じた行0、反例で停止2、他の20行も未完として残す |
| 76葉へ全開始を供給 | 未完。E_Lamの前提へ進めない型付き状態を再現し、他の葉も全供給済みに繰り上げない |
| 主定理を閉じない/固定署名を変えない | 遵守。修正案は表に留め、変更していない |
| sorry・新公理・既存importの除外・旧Release/処理系の変更をしない | 本番2モジュールと外部の読者の範囲で点検。監査/verifyの最終結果を別記 |
| plan/detail/README/レビュー/群A・B記録を変えない | 遵守。追加記録はl40/cだけ |
| 01-12/07-04の写しと公開入口の読者 | 本番2モジュールを同じ変更で反映。未完の修正や計算下書きを写しに含めない |
| 記録各100KB以下、全名を再生成、全新モジュールの既定import | verify.pyとaudit.pyで照合し終了0 |
| 独立レビューと受け入れ | 未実施。取りまとめ・設計者の担当 |

停止は時間上限によるものではない。取りまとめには、上の反例を独立レビューし、任意の型付き開始という量化を保つ修正の境界を指定してから、L40.15の再開依頼を出す判断を求める。

## 最終の検査・宣言・記録の照合

| 検査 | 終了 | 外側の秒 | 内容 |
|---|---:|---:|---|
| 全canonicalの読者の局所Lean | 0 | 2.704 | 公開入口を元導出へ組み合わせる読者 |
| 全セルと場所の局所Lean | 0 | 1.150 | ref/lazy/cont/used/builderと同じσ |
| 保存した反例の単独Lean | 0 | 0.810 | StateTyE/StateTy、直接と捕捉の対照、formed_application、no_step |
| 既定ビルド | 0 | 17.867 | formal/から対象指定なしのlake build。新2モジュールも既定import |
| workの選択確認 | 0 | 0.114 | 基準4d27a930…、spec_tally/spec_examples/formal_build |
| 作業末のwork（一度） | 0 | 7.591 | 仕様対応の自己検査/集計、仕様例7件（失敗0/ignore0）、既定全Leanとsorry拒否 |
| 全公理監査 | 0 | 43.607 | 既定702モジュール、記録内64宣言を含む68,805対象 |

二つの新モジュールには環境上の宣言が133件ある（移設した外部逆転を含む）。内訳は公開の名前付き25、privateの名前付き13、匿名の適用例23、その他の生成宣言72である。変更したExternalStateLeavesは35宣言、反例と下書きのローカル宣言は別に64件である。[declarations.json](initial-declarations.json) は手書きの公開名、private/匿名の件数と生成分を台本で再生成した一覧である。監査対象そのものは台本がLean環境から再生成し、手書きの名前だけに限定していない。

| 出力 | bytes | SHA-256 |
|---|---:|---|
| 公理依存の生出力 | 12,040,543 | `5ae90b0eccafc164de0c93b5e7827d80690e46c68e68453e719f3b92b8bdf919` |
| 全対象名の一覧 | 4,173,462 | `c6f60b46d842d387e94418352cdf4c084f8aa02f95c1edaf0a946ec1ecd281c6` |
| 監査入力 | 29,224 | `d2855f4ff0de026394d7f9a426494b9d4ad6907634cf0949cfe9c516f94a7aa0` |
| workの生出力 | 5,847 | `10ee905fe91cf7efa7f023e63b066b220e451736d451cffdb79f993ebf3a5135` |

依存集合はpropext・Quot.sound・Classical.choiceの部分集合だけで、新しい公理0、sorryAx/ofReduceBool/監査のerrorは0である。workと公理監査の後に本番のLeanソースは変更していない。全比較・実CLI・独立レビュー・設計者の受け入れは実施していない。

| 継続の枠 | 今回保持する証拠 | 全開始で残ること |
|---|---|---|
| letF | cont_cellが返すContTy.K_LetのClosureTyと同じ入力型 | B15-Let |
| mark | 同じContTy.K_Markと戻り先 | B15-Escape、.35 |
| update | 同じlazy場所とK_Update、thunk/doneの元内容型 | B15-Lazy |
| release | K_Releaseの同じ型付き資源値とAdequate | B15-Use、L60の解放応答 |
| handleF | 通常K_HandleとK_Handle_Failの元CaptureOk/節 | B15-Handle |
| drop | K_Dropの同じcont場所と行 | B15-Resume |
| guardF | K_Guardの元捕捉・腕・GuardBodyTy・MatchPrefix | B15-Guard |

単位の記録を能動時間へ換算せず、停止後の保存・検査・報告の区間も別に扱う。ここまでの最終照合は実装担当の自己点検である。

