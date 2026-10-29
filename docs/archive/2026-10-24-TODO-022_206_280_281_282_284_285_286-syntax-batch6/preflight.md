# 第6弾の計画全体の事前点検（下書き）

2026-10-24、P1R（RV-P1対応）。対象は[判断](decisions.md)・[共通依頼文](implementation-request.md)・[計画](plan.md)とREADMEの文書一覧である。これは読み取りによる事前点検であり、実装の成功や独立レビューの受け入れの記録ではない。担当を起動する取りまとめは、取り込み後の実際のインターフェースへ再照合する。

## 条件と実施した範囲

P1の確認記録では、AGENTS.mdと00-01を読み、private/とそこを指すスキルのリンクは読まなかった。公開のjapanese-tech-writing、rtk、test-audit、benchmark、git-workflowを読んで計画へ適用した。READMEの二つの設計者の決定、studyの二本文と二つの問い、RV-S1/S2とresponse、riders-probesの入力/保存出力/確認記録を読んだ。docs/todoの022/206/280/281/282の当該内容を読み、実装に必要な範囲を判断と計画へ写した。過去の第5弾の四文書は形・粒度・過去の失敗の記録としてだけ参照し、現行実装の根拠にしなかった。

P1の読み取りにはrg・Python・sedを使った。gitコマンドは起動せず、.git/HEADとrefsの本文だけからブランチsan_benito・HEAD `706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8`を確認した。cargoのビルド/テスト、scripts/check*.sh（dry-runを含む）、lake、処理系のcheck/run、ベンチマーク、LLM評価は実行していない。P1が書いたのは指定の四文書とREADMEの文書一覧だけである。以下の現行契約の表は、このP1の確認記録を引き継ぎ、P1Rで指摘された箇所を再照合して更新したものである。

P1RではAGENTS.md・00-01・japanese-tech-writing・rtkを読み、RV-P1とP1依頼、対象文書、診断表、報告の所在、検査スクリプト、Surfaceの構成子を読み直した。private/とそこを指すリンクは読んでいない。.git/HEADとrefsの本文から開始版が同じであることを確認した。gitの変更操作はしていない。許可されたscripts/check.shのdry-run以外のビルド・検査・測定・LLM評価は行っていない。dry-run内部のgitは差分等の読み取りであり、選択したコマンドは表示だけで実行されない。用語は外部の一次資料も確認し、URLと確認日をdecisionsの「設計者の選択」に記した。

## 現行の契約との照合

| 対象・読む根拠 | 現行の形と点検結果 | 計画への反映 |
|---|---|---|
| READMEとstudy/questions | studyは案IIを主案とし、質問は未回答のまま。READMEの後の決定は全三案・A1・警告流用、相乗りの承認と測定後の選択を確定している | D1〜D14を決定として記録。Range/HTTPの費用と作業を省かず、TODO-281の測定をもう一度要求しない |
| typeck/mod.rs:141〜188 | TypeckOutputの型表は具体化済み、typecheckの公開署名はmodules/asts/sources/resolved/require_mainから出力と診断の組を返す | 公開署名は保ち、内部のBodyInput/BodyAnalysisと予算状態を追加。A01/A02/A12で集計の提供側/読者を定めた |
| generate.rs:112〜164、context.rs:584以降 | solve・型上限・到達性→valid→consts::warnings→finish→checked_args。finishはE0208で型表を写す前に戻る | 草稿のfinish後を読む案を修正し、study 2.3の既定どおりfinish前・同じvalidで実行。operand_types/expr_typesはsolver.finalizeして読む。後段表の未転記を正常な未知と混同しない |
| consts.rs:178以降・591以降、checked_args.rs:73以降 | std_callは解決済みBindingId、standard_argumentは位置/名前を区別する。checked_argsはfinish後にCallPlanを要求する別の入口 | Range/固定域はstd_callとstandard_argumentを使う。CallPlan必須の草稿を直した。穴/パイプ/関数値を除外し、既存Regex/ScopeのEを局所区間へ広げない |
| consts.rs:1167〜1285、diag/codes.rs:1295〜1302、01-04/02-05 | 標準本体の警告を抑制、W0401/W0402のhelpは定数式のみを説明。W0403は重複キー。幅付きabsolute/floorDivide/floorModuloも現行警告の対象 | 同じ標準境界と旧定数警告を保持し、新候補だけ重複抑制。D7の既存文書訂正と新解析の条件拡張を分けた。W0404を未使用の次番号としてD19に割り当てた |
| Surface/Syntax.lean:300〜430 | Expr53構成子、Exprs/HoleArgs/Arms/Clauses/Blockと相互帰納。局所はde Bruijn、builderも番号に影響する | 全構成子の分類表、未知の共通規則・捕捉境界・通常/専用位置の対応をL02/L03へ割り当て、短絡とmatchを後で閉じる |
| Surface/Theorems.lean、Release/Assumptions.lean、07-04 | 既存のdesugar_typedは型保存。抽象δの型の仮定から具体的な算術の意味は得られない。既存Surface評価器はない | A1のEvalPartial/evalClosed・正常値/警告の二定理を新設する。主定理/公理/Assumptionsの変更を必要としたら停止。A2への模倣定理を計画へ紛れ込ませない |
| Checked/Range.lean、Range.bnt:69〜100、03-06 | 小モデルはIntでmake_ok・erase_make・project_valueを証明。Range.bntはInteger三欄、逆転を先に返し、valueは保存値の射影 | D18/L18で表現可能性・標準同定・同じ成功束縛・三欄保存・失敗優先を新しい評価関係の定義として明示。中心定理やδの前提にしない。A18/X03で実本体との比較。公理/主定理へ追加せず、小モデルだけで一致を結論しない |
| builtinのinteger/width_bits/byte/process/http_server/http_client、標準Network/Http.bnt | シフト量はInteger、幅ごとの上限。exitはu8、listenはu16へ検査付き変換。statusは200〜599、timeoutは1以上で大きい値は丸める。Response/ClientRequestの欄は整数 | 案IIIの表をこれらの宣言/型に合わせた。HTTP二欄は構築・局所保存・明示更新の別作業。正しいパスはNetwork/Http.bntでありIO/Http.bntというパスは使わない |
| Exchange/Syntax.lean/Version.lean、tests/desugar_export/exchange.rs | 既存corpus14/sidecar6には区間や式のソース位置がない。Surface出力は統合テスト側にあり、通常型検査から呼べない | interval-corpus v1と識別規則を独立に新設。A01の正規化訪問とX01の実Surfaceの対応を照合し、テスト側exporterを本番依存へしない。対応未定の合成節点は明示し、番号のずれを無視しない |
| formal/lakefile.toml、Benitoite.lean | 既定ターゲットに既存六実行器/ライブラリ。Checkedモデルも既定importに含む | Interval定義を各作業で既定importし、intervalDiffも既定ターゲットへ加える。部分的なlake buildだけを先行条件にしない |
| scripts/check-formal.sh | formal_build以外に全件Rust書き出し・独立交換・六入口・manifest照合を行う | X04で独立interval入口を全体へ追加。K1は接続時、K2は最終の関係状態。先行Leanだけの成功を全比較として記録しない |
| cli/check_report.rs、test_runner/check_report.rs、pipeline.rs、06-01 | deny-warningsではCheckResult.programがNone。main/通常testはschema1、doc testはschema2。completeは型検査/契約抽出の成功 | 集計はprogramからだけ取り出さずCheckResultへ保持する。草稿の一律schema1を修正し、各Targetと全体への追加欄だけにする。既存の必須欄/completeを変えず、厳密な読者と破壊が要るなら取りまとめへ戻す |
| Log.bnt:158〜197、builtins/funcs/log.rs | formatRecordは既存の純粋builtin宣言で非公開。三ハンドラは通常の規則で書かれ、出力先の効果が残る | R05でpublic/docだけを追加し同じ名前/型を保つ。Log→Json依存や専用ハンドラを足さない。公開後の生成参照/六入口を確認する |
| riders-probes、tests/doc_examples/mod.rs:131〜190 | ファイル/JSON例の成功は保存記録にあるが、テキスト例はmessageだけ。文書例はstdout/stderr/終了を比較し、書いたファイルは直接比較しない | messageだけの例をそのまま採用せずformatRecordを使う。解放後にFile.readTextで読み戻す。検査用mainにはFile.Read/Console.Writeを加える。JSONの属性配列/u64文字列/非有限数は利用側の形式とする |
| FloatのAPIと保存した初回失敗 | Float.isInfiniteは存在しない。保存した成功例はFloat.isNaN(n-n)を使い、正負無限大の実行は未確認 | R06の使用関数を実在する形へ固定。正負無限大を載せる場合は局所実行で確認し、現時点で確認済みと書かない |
| derive.py:24〜29・1009以降、test_derive.py:158以降、inventory README | generator3.1.0-syntax-batch5、inventory/manifest等3。fileUses原文/位置が既にあり、prepare共通入口が計画を作る。既存テストはProperty生成後のE0401を観察 | R02/R03で既存表を事前拒否/非書き込みへ変更。Show/Orderはimplementだけなので受理。受理入力の本文/意味ハッシュ/記録の一致とreceipt復旧を確認する。inventoryの新しい欄は不要 |
| deriveのsourceと宣言元 | inventoryは生成対象の宣言元とsourceの一致を要求する | 対処は個別uses、または型定義と対象を純粋なモデルモジュールへ移す。「生成先だけ変更」の誤案内をしない |
| scripts/check.sh:424〜449・541以降、test_policy.py、07-03 | 新lint_defaultはlib/tests、旧経路は別。stageの明示tests_relatedは--test必須。migrate_selftestsはderiveを含まない | R01で新経路だけexamplesを追加。旧固定記録は保つ。stage全行へ実ターゲットを指定し、deriveはT-D/G01へ別に割り当てた |
| desugar_export/batch3.rs:export_batch4_log_standard、check_batch3.py | Logの既存局所入力はg2、既定出力はtarget/formal-batch3/g2。check_batch3.pyは--rust-dir/--reportを受けて六入口を比べる | T-Lの曖昧な「既存経路を起動時に決める」を除き、実在するフィルタと具体コマンドへ直した。manifestの件数が変われば入力と一緒に直す |
| 01-03と06-09、modules/package.rs/text.rs | 版別説明が重複し、0.0.6/7だけCHANGELOGの節を名指ししない等の違いがある | R07へ移動と参照の更新を割り当てた。D11と合わせて新E0908登録は増やさず、過去移行節を保つ |
| tools/bench/compare/run.pyとscenarios | --tier short/--state/--quick/--estimate-fromが存在。既存functions/constraintsへ入力を足せる | M01をA02より前に置き、正常域のcheck入力で局所束縛/分岐/幅/Range/HTTP欄の費用を見る。専用測定器を作らず、targets/fullは依頼範囲へ加えない |

## 担当外の影響と構成の境界

解析の新しい依存は型付きASTと宣言の読み取りであり、VM/ランタイムの値を保持しない。ネットワーク・暗号・Wasmtimeを中核へリンクせず、存在する標準宣言の固定表だけを使う。含まれないモジュールは元の検査で拒否する。LogのJSON変換は利用側の通常関数に置き、preludeからJsonへ依存させない。これらをA19とR06の完了条件へ入れた。現在の構成を超える任意のCargo機能分割を今回の相乗りとして始めない。

整数の値域はホストのusize/isizeでは決めない。符号付きの中間値はi128、u64の定数倍はu128で比較し、値域と比べる前にi128へ変換しない。補助記憶はD16の保持項目数で数え、Leanと同じ定義と検査付きカウンタを使う。予算定数は32ビットで表現可能な値にする。JSON端点は十進文字列である。32ビット向けビルド・実行は今回行っておらず、その成功は受け入れの証拠として挙げない。実装時にクロス対象/環境を使えるかは事前点検で確認し、使えなければ型幅の静的点検と未実施を記録する。

影響する読者は型検査の全統合テスト、examplesの道具、元AST/Surfaceの交換、CLIのmain/test/doc報告、文書例の抽出、Skillの生成、deriveの本体検査、仕様の網羅集計である。A作業のworkは全統合にし、前回のnamed_argumentsの見落としを避けた。新警告で壊れた当該作業の期待値はその場で直し、U01では全領域/strict入力の最終棚卸しを行う。性能の記録はCHANGELOGへ書かない。

利用者向け文書はハーネス経由の検査報告と結果の確認を中心とする。警告なし・coverage: some/noneを安全の証明と表示しない。ハーネス自身の許可/実行手順は写さず、処理系の該当版の参照を使う。サーバモードの実行時許可は今回実装したように書かない。

## 検査・測定の割り当ての点検

workは各97作業へ割り当てた。Leanのみ/Pythonのみ/文書のみにはRust全libを足さない。型検査・診断を広く変えるA作業は統合全ターゲット、Rの公開APIと文書の例はskill_examples・reference_examplesの共有doc_examplesを含め、Xの交換はRust変更時の全統合とそれ以外を分けて読者を明示、stageは新しい接続だけを名指す。changeはG01で改造全体に一度、releaseはZ01の実候補に一度とし、release_stackの成功10件と実CLI/版/生成物/同梱物/移行/配布の手動照合を別に要求する。

check-formal全体はX05a/K1とZ01b/K2へ割り当てた。引用条件の全欄を満たす同じ最終関係状態だけは再実行の代わりに引用できる。既定lake buildを全比較の代わりにしない。gc-stressはchangeに含め、新しい意味の境界値を縮めず、数個の値で具体比較する。予算を確かめる解析だけの大入力は必要ならlongへ分ける。現計画はヒープ不変条件や安全点を変えないため局所Miriは対象外とし、広がった場合の前倒し条件を記した。

shortはB0と処理系の取り込み後を比べ、少なくとも各処理系区切りで、全体検査と候補準備の前に実行する。初回ビルドと新解析の増分は不明であり、quick/代表入力から更新する。targets/fullは性能目標を約束しないソースだけの候補で、別の了承を要するため入れない。長い検査の仮時間と更新手順、2倍超過時の報告を一つの残り手順表へまとめた。

## 草稿で見つけ、直した食い違い

1. finish後の型表/CallPlanを新解析の必須入力とした草稿は、E0208時の未転記とstudy 2.3の既定に合わなかった。finish前・同じvalid・solver.finalize・std_call/standard_argumentへ計画全体を直した。
2. 検査報告の形式番号を一律1とした草稿を、main/通常testは1、doc testは2へ直した。programがNoneでも予算/未対応を集計できる渡し方も固定した。
3. 相乗りの局所の六入口比較のコマンドが未確定だったため、実在するg2出力とcheck_batch3.pyの引数へ具体化した。既存の全比較を局所の名目で先取りしない。
4. migrate_selftestsをderiveの検査と取り違えないよう、T-DとG01へ独立した実reader/formatterの自己検査を追加した。
5. check費用の新しい入力の担当が曖昧だったため、M01を独立作業にし、A02より前という依存を追加した。
6. 旧テキスト例はmessageだけで、既定書式/水準/位置の例にならない。formatRecordの公開と、解放後の読み戻しをR05/R06へ割り当てた。
7. 新警告の修正をU01まで待つと途中のworkが失敗したままになる。当該作業で差分を確認して修正し、U01は全領域の最後の棚卸しとする条件を加えた。

## 実行して初めて分かる点と取りまとめの判断

| 点 | 現在分かる範囲 | 実装時の担当/停止条件 |
|---|---|---|
| 証明と97作業の大きさ | studyの費用は実測ではない。着手枠の和と完了までの見込みを区別した | 取りまとめは最初の短い試行で再分割/再見積もりする。主定理/仮定/公理の変更が要れば当該作業を止める。拡張のLが見込みの2倍を超えた場合も、設計者へ閉じた範囲で処理系へ進むかを尋ねる |
| 正常値/警告とVMの到達 | A1の意味保存は未証明。比較用標識ソースの実行比較自体も未実装 | X03は標識を除いた元式との対応、子失敗/未到達を照合する。未知の呼び出しを具体実行比較の成功件数へ入れない |
| 解析の予算値/時間 | 初期値は操作10万/100万回、保持項目数は本体10万項/全体同時100万項、性能増分は不明 | A11・U01bで最大消費と上限到達0件を記録し、M01とshortで費用を確認し、根拠付きで調整。保証・範囲を変える場合は設計者へ戻す |
| 新警告の総数/strict拒否 | 未取得。標準本体の抑制と文書の抽出例は別である | 当該A作業とU01。件数を0と仮定しない |
| derive JSONの実生成の反例 | 保存レビューの類例E0401と生成器の読み取りからの推論であり、derive適用自体は未再現 | R02で旧動作を再現してから拒否を追加。受理本文/意味ハッシュ/記録が変わればD11の条件不成立として版を再判断 |
| 追加報告欄の読者 | 既存必須欄は保つが全外部読者を確認したわけではない | A12a/A12bで既存読者と照合。破壊が必要なら形式番号を独断で上げず取りまとめへ報告 |
| Range/固定域の構成不在 | 解決済み宣言の表だけで扱える設計 | A16/A19/X02で不在・偽装を確認。モジュールの追加ロード/中核への実装依存が必要なら戻す |
| 長い検査・測定 | 90〜150分のchange等は仮見込み、初回ビルドや最終の全比較は不明 | 短い局所一回から更新。既に割り当てた検査/shortを進め、追加のtargets/fullやLLM評価は了承なしに始めない |
| 最終受け入れと公開 | 全三案を含む0.0.12候補を準備する範囲は決定済み | 計画の独立レビュー、各区切りのレビューと全体受け入れを取りまとめが手配する。TODO残件の扱い/保管/履歴集約/タグ/正式アーカイブ/pushは設計者の指示待ち |

設計者の機能範囲の決定を問い直す未決事項はない。用語の二点は2026-10-24に設計者が選び、decisions末尾に記した。計画で決めたW0404、予算の初期値、独立交換の形、追加報告欄、標識での到達観測は、取りまとめが計画レビューで確認する点である。機能範囲や保証を変える必要が見つかった場合だけ、新しい判断として報告する。

## P1Rで再照合した所在と変更

| 読み取りの対象 | 再確認した箇所 | 修正先 |
|---|---|---|
| 02-10 | 255行のcheckReport/testCheckReportと386行の報告境界 | A12b・U02b。02-02を対象から外した |
| 06-01 | 296行以降のmainの報告、346行以降のtestの報告、342行の受け入れ条件 | D21・契約表・A12a/A12b |
| 06-04 | 177行以降の非実行の検査 | A12b・U02b |
| 06-06 | 41行の手書きinspection、133/139行の受け入れ、156行のdocの報告 | A12b・U02b・U03a |
| skill/references/inspection.mdとSKILL.md | inspectionの25〜43行、SKILLの39/50/61行の受け入れ規則 | A12b・U03a。coverageはcompleteの判定に関わらないと明記する |
| tests/skill_examples.rs・reference_examples.rs | 両入口がtests/doc_examplesを共有する。doc_examplesは統合ターゲット名ではない | R04/R05/R06・文書枝・U02/U03のworkへ両入口を割り当てた |
| scripts/check.sh | work_names、tests_relatedと--testの検証、crates/formal/scripts/docsの分類 | X01〜X05のworkをRust変更の有無で分け、X04/X05の不要な--testを除いた |
| diag/codes.rs | E1010の100,000/1,000,000節点の予算、W0401/W0402の行、R0701のout of range | D16の根拠と超過の非診断、D19の全型板 |
| Surface/Syntax.lean | Expr53構成子とBlockのbind/lastBind等 | L05でintDivを名指しし、土台に全Block形の順序と局所束縛を含めた |

これらはrg・sedによる所在の確認であり、新しい報告欄や新警告の動作確認ではない。Rangeと固定域APIの評価規則はA1の信頼の範囲に置く。X03cでHttp.respondなどの未比較を固定して07-04へ記す。Q4はR07へ移し、R01をA01の依存へ加えた。枝分割・依存・時間の変更はplanの枝の表と末尾の一つの時間表を正とする。

## workのdry-runの記録

2026-10-24、基準は仮の706d7ca3である。各work行の指定へ--dry-runを付け、同じコマンド形はまとめて一回確認した。97行の全workを9種類のwork指定で覆い、修正したS-R2も別に一回確認した。いずれも終了0であり、指定の誤りによる終了2はなかった。検査の実行成功を示す記録ではない。

自動workは、この時点の文書だけの差分に対して「nothing to check: only documents changed」であった。将来のRust差分やX04aのスクリプト差分は作っていないため、将来の自動選択は未確認である。X04aでpolicy_selftestとformal_buildが選ばれる見込みは、classifyとworkへの対応表の読み取りによる。実装担当は実際の差分とB_WORKでdry-runをやり直す。

下表の「追加指定」は、共通の`scripts/check.sh --level work --base 706d7ca3`へ加え、最後に`--dry-run`を付けたものである。S-R2だけはlevelをstageとする。出力は手元の絶対パスを残さず、必要なら<repo>・<home>へ伏せた。指定と表示全文は[dryrun.json](work-copies/m012/scratch/p1r/dryrun.json)にも保存した。

| 番号 | 確かめた行 | 追加指定 | 選ばれた単位・表示 | 終了 |
|---|---|---|---|---|
| 1 | L01・L02・L03・L04・L05・L06・L07a・L07b・L08・L09・L10a・L10b・L11・L12a・L12b・L13・L14・L15・L16・L17・L18・L19・L20・L21・L22・L23・L24・L25・L26・L27a・L27b・L28・L29 | `--only formal_build,spec_examples,spec_tally` | spec_tally・spec_examples・formal_build | 0 |
| 2 | M01・R02・R03 | `--only python_syntax` | python_syntax | 0 |
| 3 | R01 | `--only policy_selftest` | policy_selftest | 0 |
| 4 | R04・R06 | `--only reference_examples,skill_docs,skill_generated,tests_related --test skill_examples` | tests_related・skill_generated・reference_examples・skill_docs。tests_relatedはskill_examples | 0 |
| 5 | R05・R08・A01a・A01b・A02・A03・A04・A05・A06・A07・A08・A09・A10・A11・A12a・A13a・A13b・A14a・A14b・A15a・A16a・A16b・A17a・A17b・A18a・A19a・A19b・A19c・A20a・A20b・A20c・A21a・A21b・X01a・X01b・X02a・X02b・X03a・X03b・X03c・X04a・X04b・X05a・X05b・U01a・U01b・G01・Z01b | `追加なし` | 対象なし（文書だけの現在の差分） | 0 |
| 6 | R07 | `--only spec_examples,spec_tally` | spec_tally・spec_examples | 0 |
| 7 | R08・A12b・A15b・A18b・A21c・U02a・U02b・U03a・U03b・Z01a | `--only spec_examples,spec_tally,reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --test stdlib_doc_examples` | tests_related・skill_generated・spec_tally・spec_examples・reference_examples・skill_docs。tests_relatedはskill_examples・stdlib_doc_examples | 0 |
| 8 | X01a・X01b・X02a・X02b・X03a・X03b・X03c | `--only formal_build,python_syntax` | python_syntax・formal_build | 0 |
| 9 | R06（Log.bntのdocを変える場合） | `--only reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --test stdlib_doc_examples` | tests_related・skill_generated・reference_examples・skill_docs。tests_relatedはskill_examples・stdlib_doc_examples | 0 |
| 10 | S-R2 | `--only tests_related --test property_library --test reference_examples --test skill_docs --test skill_examples --test spec_examples` | tests_related。tests_relatedはproperty_library・reference_examples・skill_docs・skill_examples・spec_examples | 0 |

## P1Rの文書の静的確認

対象は四文書・READMEの文書一覧・RV-P1-responseである。作業の親ID69件を、枝のない45件と枝52件に分け、実行する作業97件とwork97行を一対一で照合する。Lが33件・Rが8件・Aが35件・Xが11件・Uが6件・Mが1件・Gが1件・Zが2件、着手枠72時間45分〜97時間、実装/記録129〜238時間である。枝の実装/記録の上端は3時間以下とし、検査・レビューと待ち時間は別に見込む。P1よりworkと独立レビューの回数は28回増える。

相対リンクと参照アンカー、IDと依存、D1〜D22、フェンス・末尾空白・絶対パス・公開文書からdocs/todoへのリンク不在を、読み取りのPythonで確認した。READMEは文書の一覧だけを変更し、設計者の決定の二節は原文を保った。これは文書の整合の確認であり、証明・実装・予算消費・診断件数を実証するものではない。


## P2 セキュリティの項目の事前点検（2026-10-24）

P2時点の対象はTODO-284・285・286のD23〜D30とS01/S02a/S02b/S03/S04である。照合の実行記録はそのまま保存し、運用案は下記と末尾のP2Rの点検へ更新した。AGENTS.md、READMEの設計者の全決定、既存の判断・計画・共通依頼文、docs/todoのplatform-and-toolingの三項目、00-01、公開のjapanese-tech-writing・rtk・git-workflow・benchmark・test-auditを読んだ。private/とそこを指すリンクは読んでいない。git-workflowの実体は公開の`.claude/skills/git-workflow/SKILL.md`である。P2は判断・計画・本点検と、依頼文の先行条件だけを変更し、READMEの文書一覧は新しい文書を作らないため変更しない。

P2ではgitの変更操作、Cargoのビルド・テスト・update、lake、測定、checkスクリプトの実検査を実行していない。勧告照合のcargo-denyと版/引数のhelp、scripts/check.shのdry-run、読み取りと文書の静的確認だけを行った。`formal/`・01-12・07-04はP2の変更対象外であり、Lean担当の作業と証明を再評価しない。

`.git/HEAD`の本文は点検時に`ref: refs/heads/mod012/L07b`だった。依頼に記されたsan_benitoと異なるが、同じ作業ツリーでの並行作業という条件に従い、ブランチを切り替えず文書だけを編集した。S担当へ渡すB_WORKと実際の作業ブランチは取りまとめが起動前に固定する。P1R以降にplanへ加わっていたL07c/dの節は保ち、P2の全体件数ではその二件を別に加算した。Leanの作業本文やwork行をP2の都合で変更しない。

### 現行の版・機能・APIとの照合

| 対象 | 読み取りで確認した現状 | 計画の前提・実装時の確認 |
|---|---|---|
| 根のCargo.toml | workspaceはcrates/benitoiteだけでfuzzを除外。devでWasmtime/Cranelift等を個別に最適化。Rust最低版1.98、rust-toolchain.tomlの固定は1.98.1 | S01/S02aはクレートのmanifestと二lockを更新する。根のmanifestの版を変更する作業ではない。依存の機能や最適化構成を広げない |
| crates/benitoite/Cargo.toml | rustls `=0.23.45`、既定機能なしstd/tls12。ureq `=3.4.2`はrustls-no-provider/platform-verifier、rustls-graviola `=0.4.0`。Wasmtime `=49.0.2`は既定機能なしruntime/component-model/std/cranelift | D23/D24の修正版固定へ変更。async/component-model-async/WASIやbrotliを追加しない |
| Cargo.lockとfuzz/Cargo.lock | 両方ともrustls 0.23.45、rustls-webpki 0.103.15、webpki-root-certs 1.0.9、rustls-platform-verifier 0.7.1、wasmtime 49.0.2、cranelift-codegen 0.136.2。全外部sourceはregistry+https://github.com/rust-lang/crates.io-index | S01/S02aの両方にfuzzを明示。間接依存も実lockで照合。source制限を既に実装したとは書かない |
| deny.toml | licenses.allowとgraph.targetsだけ。対象はaarch64-apple-darwin、x86_64-unknown-linux-musl、aarch64-unknown-linux-musl。advisories/sourcesなし | S03でadvisoriesを追加し、同じ設定をルート/fuzzへ明示。sourcesは今回追加しない |
| HTTP clientの実装 | http_client.rsはrustls-graviolaのCryptoProviderをureqへ設定。rustls::Errorを包むIOの分類と、実際の証明書エラー型から完了値を確認する既存libテストがある。ソース全体にClientSessionStoreの実装とEchModeの設定は見当たらない | TLS勧告四件のうち三件の非到達は機能/APIの読み取りによる見込み。認証前ServerHelloの影響を実再現したわけではない。S01の既存検査と勧告の解消を分けて記録 |
| external/mod.rsのengine_config | consume_fuel/epoch_interruption/component_model_map、WASMスタック512 KiB、backtrace設定。wasm_exceptionsの明示設定なし | D29は既定維持。例外ゲストの受理と非同期機能の検証拒否はS02aで実行して確かめる |
| external/runtime.rsのnew_store/reset_limits | Store生成の共通入口でResourceLimiterを設定し燃料/hostcall fuel/epochを設定。現行にset_max_component_handlesなし。線形メモリ64 MiB、転送256 MiB、表10,000要素、コアの数16 | 49.0.3以降のStore単位の取っ手の上限は別単位。S02bで共通入口へ100,000を明示し、statefulの生存数を呼び出しごとに消さない |
| runtime.rsのfailure/has_priority_failureとtext.rs | 専用メモリ/表のエラー型、燃料と中断、adapterの報告、非公開HostcallFuelExhaustedの完全一致、コアの数の接頭辞と整数から分類。取っ手の原因の分類なし | 現行コードの読み取りだけでは49.0.4の超過がR0906かR0601かは確定しない。S02aで既存分類、S02bで実ゲストによる取っ手の超過を確認。必要数を捏造しない |
| runtime/mod.rs・runtime/report.rs・external/stats.rs | ExternalObjectsはsizeとlimitを必須にする。statsは既知の四資源名だけを認め、未知ならInternalになる | S02bは必要数の取得不能を隠さず、診断契約の変更が要れば取りまとめへ戻す。取っ手の資源名を統計のcomponent_handlesへ接続し、統計あり/なしで停止分類を維持する |
| 03-01・02-09・03-10、text.rs | 現在の版が49.0.2。v49.0.2のAPI/内部文言/C例外/シグナル/ABIの出典が複数ある。02-09には49.0.2での過去の燃料の実測もある | S02aは主張とタグ付きソースを再照合して更新、S04が横断確認。過去の実測の版はそのまま保つ。02-10のR0906の範囲もS02bでそろえる |
| scripts/check.sh | licensesだけがcargo denyを実行。work/changeの依存差分はrust/licenses、fuzz配下は汎用のrust分類。releaseはrelease_stackのみ。既にlint_defaultの表示はexamplesを含む | S03で表示だけのadvisories単位、fuzzのmanifest/lockの分類、change/releaseで常時選択、workは依存変更時の選択、検出/0件/未照合と終了状態を接続。R01の済んだ変更を巻き戻さない |
| scripts/check/test_policy.py・07-03 | 旧集合の固定記録、work/changeの選択、release_stackだけという期待と説明が存在する | S03で新水準の選択と表示・終了の期待を07-03・AGENTS・共通雛形へそろえ、S04で最初の照合の手順を加える。旧only/fullとlegacy記録は維持する。既存の自己検査へケースを追加し、ネットワークはダブルの外へ出さない |
| 公開git-workflowのソースだけのリリース | 候補のCLI/版/同梱物と証拠・レビュー・受け入れの手順はあるが、ツールチェーンの勧告の照合先はない | S04で候補の再照合・記録/報告を加え、S05のスキルへD30の照合先と評価手順を集める。Z01bで固定版に実施し、新しい勧告は表示・記録・報告にとどめる。今回LeanやRustの固定版を上げない |

上流の一次資料は2026-10-24に確認した。rustlsの修正版は[RUSTSEC-2026-0349](https://rustsec.org/advisories/RUSTSEC-2026-0349.html)、経路拒否の版は[0382](https://rustsec.org/advisories/RUSTSEC-2026-0382.html)、root-certsは[0383](https://rustsec.org/advisories/RUSTSEC-2026-0383.html)、Wasmtime 49.0.4の修正範囲は[0379](https://rustsec.org/advisories/RUSTSEC-2026-0379.html)を参照した。取っ手のStore単位100,000と設定APIは[Wasmtimeの勧告](https://github.com/bytecodealliance/wasmtime/security/advisories/GHSA-q554-3cjc-rx7p)で確認した。APIをBenitoiteでコンパイル/実行した確認ではない。49.0.4の公開ドキュメントとcomponentのソースの一部は取得できず、上限の誤りの公開型と文言は未確認のままS02bへ渡す。

cargo-denyの[現行のWeb設定文書](https://embarkstudios.github.io/cargo-deny/checks/advisories/cfg.html)と[0.20.2の設定の実装](https://github.com/EmbarkStudios/cargo-deny/blob/0.20.2/src/advisories/cfg.rs)も照合した。0.20.2のignore項目はidとreasonであり、現行Web文書にあるexpiryは使えない。P2はreasonへ再確認日を書く案だったが、P2Rではignoreの例外運用を新設せず空に保つ案へ改めた。対応状況と次の判断は記録とdocs/todoの項目へ残す。sourcesは[別の検査](https://embarkstudios.github.io/cargo-deny/checks/sources/cfg.html)なので、節だけを追加して有効になった扱いにしない。

### 第6弾の最初の依存の勧告照合（P2、2026-10-24）

この照合の19件はTODO-284・285に一致し、設計者はその対応を第6弾へ組み込むと決めた。以後のS01〜S05はその判断に従う。以下の終了1は当時の生のcargo-denyの状態であり、S03で計画する表示だけのadvisories単位の終了ではない。

`cargo deny --version`は終了0、表示は`cargo-deny 0.20.2`（外側0.03秒）だった。最初の指定どおりの二照合はDBロックの取得前に終了1で止まった。要点は`failed to acquire advisory database lock`と`<home>/.cargo/advisory-dbs/db.lock`への`exclusive lock on a read-only path`である。ワークスペース0.26秒、fuzz 2.96秒。勧告の判定をしていないので、この失敗を0件と数えない。

その後、元のdeny.tomlを一時領域へ写し、`[advisories]`のdb-pathだけを書き込み可能な一時領域へ変えて再試行した。追跡するdeny.tomlは変更していない。`--config`をcheckの後に置いた最初の再試行は両方終了2だったため、helpで位置を確認し、cargo-deny全体の引数へ直した。再試行では`--locked`も加えてlockの不変を要求した。

| 対象 | 実行した指定（手元の絶対パスは伏せた） | 検出した一意のID数 | 終了 | 外側の時間 |
|---|---|---:|---:|---:|
| ワークスペース | `cargo deny --config <scratch>/deny.toml --locked check advisories` | 19 | 1（脆弱性） | 1.19秒 |
| fuzz | `cargo deny --manifest-path fuzz/Cargo.toml --config <scratch>/deny.toml --locked check advisories` | 19 | 1（脆弱性） | 1.00秒 |

DBは`https://github.com/RustSec/advisory-db`から取得し、両照合でコミット`1645308cb4766561b0b274d8c93f7033a766fc96`を使用した。取得・照合日は2026-10-24。設定のgraph.targetsは元の三構成のまま、ignoreは加えていない。二つの結果は同じ19 IDであり、二lockでの重複を足した38件とは数えない。勧告のerror[vulnerability]以外の新しい警告は出なかった。

| 系統 | 検出ID（RUSTSEC-2026-の後ろ） | 一方の照合の件数 | TODOとの差 |
|---|---|---:|---|
| rustls | 0346・0347・0348・0349 | 4 | 既知 |
| rustls-webpki | 0382 | 1 | 既知 |
| Wasmtime | 0353〜0364・0378・0379 | 14 | 既知 |
| 合計 | 上記19 ID | 19 | TODOの19件以外に新しいIDはない |

webpki-root-certsの0383は対象構成から外れるため検出されなかった。ロックに1.0.9が残ることは別に確認しており、S01で1.0.10以降へ更新する。cargo-denyの検出から除かれることと、すべての構成で影響がないことを同一視しない。現在の版で19件が検出されることを確認した記録であり、更新後の解消や各勧告の攻撃入力を再現した証拠ではない。

入力のSHA-256は次のとおりである。後の依存更新はこの記録と異なる入力になる。

| 入力 | SHA-256 |
|---|---|
| crates/benitoite/Cargo.toml | `2e154d42ff04dafbc4018e563737322a9599b0677dd4aeeb274afad28c18e359` |
| Cargo.lock | `1e927633cff09381e6947b65130b7c897d7df07c3124686d98e8cc1077d07b84` |
| fuzz/Cargo.lock | `b8876de35ae690e2b0c8aa366b58549f1b52b0b1d77ff27f2f90ed76c1373798` |
| deny.toml | `810721145d1a767d1011e2359a6d38460a075f9f911d3923c7e1b92d4c65cde1` |

### P2のdry-runと検査割り当ての限界

`scripts/check.sh --level work --base 706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8 --dry-run`を一度実行し、終了0だった。206ファイルの既存差分からfmt・lint_default・lib_default・tests_related（全統合）・source_rules・skill_generated・spec_tally・python_syntax・migrate_selftests・policy_selftest・formal_buildを表示した。tests_relatedが包含するspec_examples/reference_examplesは省略の表示だった。既に並行作業の差分を含むので、Sだけの将来の自動分類の確認ではない。表示されたCargo/lake/自己検査は実行していない。

Cargo.lock/manifest/deny.tomlの現行分類を読むとrustとlicensesが選ばれ、Rustのworkのlib全件・全統合・clippy/fmt等に接続する。S01/S02a/S02bはこの自動workを使い、HTTPクライアントとWASMの全読者を含める。新しいadvisoriesの名前・選択・二manifest/共通設定・ネットワークの失敗の扱いはまだ実装していないので、S03の実装後に同じ基準でdry-runと自己検査を行う。P2のdry-runで新単位が通ったとは書かない。

P2R後のS作業は6件、実装/記録は計9.5〜17時間、work6回と独立レビュー6回、S02b後のshortを1回追加する。各見込みとZ01bでのツールチェーンの勧告の照合はplan末尾の一つの全体表へ反映した。取りまとめが確認する実装案はD25/D26の自動選択と表示・終了の区別、D30のスキル名と記録・呼び出し方法である。D28の取っ手の専用上限/診断とD29の例外対応の維持も引き続き計画レビューで確認する。勧告の検出で最後の検査を不合格にしないこととスキルの追加自体は設計者の決定であり、問い直さない。今日のP2ではビルド・テスト・性能比較も、Rust/Leanツールチェーンの新しい勧告の網羅的な照合も行っていない。


### P2の文書の静的確認

D23〜D30の連番、S01/S02a/S02b/S03/S04の5行のwork、C1/L26→S→A01の依存、各実装/検査/short/レビュー/受け入れの割り当てを照合した。相対リンクの参照先の存在、Markdownのフェンス、末尾空白、手元の絶対パスがないこと、docs/todoへのリンクがないことを読み取りのPythonで確認した。READMEは編集前と同じで、並行作業で加わったplanのL07c/dの節も編集前と同じである。manifest・二lock・deny.tomlのハッシュは勧告照合時から変わっていない。P2が書いたのは本改造のdecisions/plan/preflight/implementation-requestの四文書だけであり、依存の更新や処理系の検査の成功を示す記録ではない。


## P2R 勧告の照合の扱いの再点検（2026-10-24）

P2RはAGENTS.md、00-01、公開のjapanese-tech-writingとrtk、P2の依頼と報告、本改造の四文書、公開の共通雛形、検査スクリプトの分類を読んだ。privateとそこを指すスキルのリンクは読まず、git操作・勧告の再照合・ビルド・テスト・checkスクリプト（dry-runを含む）・lake・測定は実行していない。変更対象は本改造のdecisions.md・plan.md・preflight.md・implementation-request.mdだけである。公開のAGENTS.md・共通雛形・公開スキルの実際の更新はS03〜S05へ割り当てた。formal/・01-12・07-04・l07b/は変更対象外である。

| 点検した事項 | 改めた判断・割り当て | 実装時に確かめる点 |
|---|---|---|
| 改造の最初の照合 | D25/S04。AGENTSの改造の進め方、共通planの前提と最初の段、共通依頼文の起動前確認に加える | 依存とツールチェーンの照合・影響の評価・設計者の組み込み/別対応の判断が範囲の確定前にあること。privateのorchestrationは変更しない |
| 第6弾の初回の結果と判断 | P2が2026-10-24に同じ19件を検出し、TODO-284・285に一致。設計者は組み込むと決定済み | P2の実行結果と入力を参照する。ツールチェーンまで網羅したという記録へ広げない |
| advisoriesの選択 | D25/S03。change/releaseは常時、workは依存manifest/二lock/deny変更時を推す | 新単位の二対象と共通設定、名指し、旧集合、dry-runの表示を方針自己検査で確かめる |
| 検出と取得不能の扱い | D26/S03。勧告あり・照合済み0件・取得不能/照合不能を目立つ見出しで表示し、単位は終了0とする案 | 生のcargo-denyの終了と単位の終了を分ける。道具不在も未照合。設定ミス/実行器の不具合は終了1。片方の未照合を全体0件にしない |
| 最後に新しい勧告が出た場合 | D26/S04/G01/Z01b。表示・結果への記録・取りまとめから設計者への報告を行い、次の改造の最初の判断へ引き継ぐ | change/releaseの不合格条件や候補の停止条件にしない。最初に組み込むと決めたS01/S02の完了条件は維持する |
| ignoreの旧案 | D26/S03。例外の運用は新設せずignoreは空とする | 勧告を表示から消さず、到達性と対応状況は記録/docs/todoへ残す。期限で候補を止める規則を残さない |
| 改造がない時の対応 | D30/S05。security-advisoriesスキル、相対リンク、AGENTSの表を追加する | 二lockと四ツールの照合、構成・機能/APIの評価、docs/todoの追加/追記、設計者の判断、記録の置き場所が揃うこと |
| 周期的・手動の呼び出し | D30/S05。Claude Codeの/loopとDesktopのScheduled tasksを例示する | 下記の公式資料で確認した説明と、手元で未確認の利用可否・実動作を区別する。今回の定期登録とLLMの実呼び出しは行わない |
| 作業と検査の接続 | S03は方針自己検査と実二照合。S04/S05は文書だけのworkと静的確認。C1/L26→S01→S02a→S02b→S03→S04→S05→A01 | S05末で公開手順とスキルの参照を閉じる。短い性能比較はS02b後の1回を維持し、文書だけのS03〜S05へ追加しない |

周期的な呼び出しの一次資料は[Claude Codeの/loop](https://code.claude.com/docs/en/scheduled-tasks)と[DesktopのScheduled tasks](https://code.claude.com/docs/en/desktop-scheduled-tasks)を2026-10-24に確認した。前者はスキルを間隔付きで実行でき、開いたセッションを要する。後者はローカルフォルダ・指示・周期を設定し、起動中のアプリと起きている端末で実行する。手元の版での利用可否や実動作は未確認であり、これらを試した記録とはしない。

P2Rの静的確認では、四文書の相対リンクの参照先、Markdownのフェンス、末尾空白、手元の絶対パスとdocs/todoへのリンクの不在、Sの6行のworkと依存順・見込みの一致を確認した。退避した編集前の本文と比べ、planのLean作業群の本文とdecisionsのD23・D24・D27〜D29は変更していない。これは文書の整合の確認であり、advisoriesの実装・検査・スキルの実動作の成功を示すものではない。


## S03 の実装結果（2026-10-25）

S03は表示だけのadvisories単位を実装し、workの依存差分、差分の有無によらないchange/release、全水準の名指しへ接続した。ルートとfuzzへ共通設定と--lockedを渡し、二対象を順に試す。JSONの診断・完了要約・生の終了を照合し、勧告あり・照合済み0件・未照合を区別する。設定と実行器の誤りは終了1、勧告あり・取得不能・道具不在は表示と記録を伴う終了0とした。ignoreは空、sources検査と旧only/fullの集合・legacy固定記録は変更していない。07-03・AGENTS・公開の共通雛形もこの状態へそろえた。上のP2/P2Rは実装前の点検記録として保つ。

基準661dbdd34a27576a3ddbc982d1f0f6bf8c5bdbf0に対する名指しのworkで、方針自己検査25件と実二照合が成功した。二照合はcargo-deny 0.20.2、DBコミット21d909e4c8bd4e14c7aea58bf980c881a0053ab1で検出0件、生の終了も各0だった。サンドボックスに合わせた共通設定の写しへdb-pathだけを加え、追跡する二lockのハッシュは前後で同じだった。/usr/bin/time -lはsysctlの拒否で最大常駐量を取得できず、検査本体の終了0と計時の終了1を分けて記録した。実装・失敗修正・生の出力と入力の識別は[s03/results.md](s03/results.md)と同階層の記録に残した。独立レビューと受け入れは取りまとめが行う。S04の最初と最後の公開手順、S05の独立スキル、ツールチェーン全体の照合はこの結果へ含めない。
