# 作業 L25R の結果

着手（最初の時刻記録）: 2026-10-26 12:41:28 JST。終了: 2026-10-26 13:18:17 JST。所要時間: 0時間36分49秒。

**状態: L25R の指定範囲の実装と検査を完了した。** 基準 B_WORK と HEAD はともに `62949b1d91bd2cd0c8e5aa546deb79614274cbb6`、ブランチは `mod012/L25R` である。着手時の差分はなかった。C4 前の比較基準には `be57d4e92d7a48fb74dc33a4d3c3867b60207aeb` も使った。取りまとめによる独立レビューと受け入れを、この実装担当の点検で代用しない。

## 実装と設計書

| 対象 | 修正した内容 |
|---|---|
| `FixedDomain.lean`・`Eval.lean` | FixedDomainApi の役割を七種と Byte のシフトだけにした。processExit・httpListen と HttpListenNames を除いた。standardCallHead は直接の funName だけを認め、opName を rangeCallBinding の認定から外した。操作の call は既存の UnknownAt と unknownNormal/unknownFailed に戻る |
| `Eval.lean`・`EvalClosed.lean` | HttpRecordKind・HttpRecordDecl・fieldDomain・欄の読出し・構築・更新・Expand・HTTP の表層評価規則と閉じた評価器の分岐を除いた。シフトに必要な StandardBinding.argumentTypes・sourceTypes・EvalTypedArguments・fixedCallFailed/fixedCallAbrupt は保った |
| `RangeState.lean`・`FixedDomain.lean`・`Sound.lean` | HTTP の局所の事実と保存の関係、RangeLocalFact.httpRecord、BaseApprox.http、HttpModels と対応する補助証明を除いた。Range の result/checked と同じ成功値の対応は保った。各引数の正常値の対応は Contains だけで述べる |
| `BudgetAnalyze.lean`・`BudgetRange.lean`・`BudgetSelect.lean` と依存証明 | BudgetHttp を除き、record/update の httpBinding、整数でない局所参照ごとの rangeEntry、欄の複写の recordField 計上を除いた。rangeBind は Range の直接検査の Result だけを保存する。認定したシフトの引数を親と同じ環境でソース順に解析し、契約位置の値だけを保持する経路を保った |
| `SyntacticReach.lean`・`CallReach.lean` と位置・範囲・独立入力の証明 | concreteRule の record/update を false に戻し、子を親の範囲から除いた。CallReach の HTTP の gate と子の分岐を除いた。シフトの call 自身と認定した引数の範囲、算術の演算の同定、未認定 call の除外を保った |
| 独立例・既定 import | HTTP 専用の HttpRecordExamples・HttpUpdateExamples を除いた。DomainExamples・FixedDomainExamples をシフト中心に直し、操作の除外と未知の導出を加えた。SyntacticReachExamples に未認定 record/update の欄の除数0の例を加えた |
| 01-12・07-04 | HTTP の節・追跡・評価の説明を除き、Unmodeled/UnknownAt、固定域、閉じた評価器、警告範囲、Range の rangeCall の走査表と未知の形の振り分け表を Lean にそろえた。算術の系は「演算の同定を保つ」、未認定 call の内側の除外は WarningsInCallReach の定理が担うと書いた。A1 の限界に操作のハンドラによる差し替えを記した。具体計算の例は #guard の実行比較であり、カーネルの証明と区別した |

型・エフェクト・言語の規則は変えていない。Scope の既存の誤りと Option/Result の失敗の規則、Release の実行、Rust の処理系も変えていない。plan.md・decisions.md は取りまとめの担当として変更していない。

## 中心二命題と参照定義の差分の向き

[点検器](audit.py)と[詳細](audit.json)で、中心二命題の本文・量化・前提・結論、共有の Models・SlotModels・AbstractSlot・AbstractEnv、ConcreteValue・ConcreteValue.type・EvalInput・Reached のバイト一致を確認した。これらは B_WORK と C4 前の基準の両方に一致する。Interval の外の formal の261ファイルと lakefile.toml も両基準に一致する。

正常値・警告原因・位置・構文的な到達可能性・call reach・独立入力・閉じた評価器の公開入口について、B_WORK の26言明を照合し、一致した。C4 前の基準では24言明を照合した。L22 が既に一般化した式・本体の位置の補助定理2件（analyzeExpr_warning_located・analyzeBody_warning_located）は後述の承認済みの変更として別に扱い、その後に前提や結論を変えていない。ファイルの移動は同じ言明を移動先でも探して確認した。

| 定義・保証 | B_WORK からの差と、C4 前の基準に対する向き |
|---|---|
| NormalSoundness・WarningSoundness | 本文を含め両基準と一致する。環境・予算・正常評価・到達の条件を加えていない |
| ConcreteValue・ConcreteValue.type・EvalInput・Reached | 両基準と一致する。未知の other や整数の値の集合、同じキーと演算による到達を狭めない。原因一致を Reached の前提へ移さない |
| AbstractSlot・SlotModels・AbstractEnv・Models | 両基準と一致する。正常値の既知性、HTTP の内部表現、操作の成功を要求しない。標準束縛の二表の一致という既存の条件もそのままである |
| StandardRule・EvalStandard | fieldDomain と HTTP の結果規則を除く。Range と fixedDomain の既存規則は保つ。標準表の固定域の役割は FixedDomainApi のシフトだけとし、操作の既定の実装を表層評価の規則にしない |
| standardCallHead・rangeCallBinding | opName の認定を除く。操作は未知へ戻る。funName の固定域の認定と異種の引数型・ソース順・契約位置の照合を保つ。C4 前の Range の認定範囲は広げず、純粋なシフトだけを未知から具体規則へ接続する |
| EvalPartial・EvalTypedArguments・Unmodeled・UnknownAt | HTTP の具体規則を除き、record/update を常に Unmodeled とする。操作とレコードには型内の任意の正常値と未知の失敗の導出が残る。固定域の引数の失敗・return の伝播と、従来の EvalArguments との対応を保つ |
| RangeLocalFact・RangeState.Models | HTTP の事実と対応条件を除き、C4 前の result/checked の関係に戻る。公開 Models を強めない。入口で Range の内部条件を構成する既存の手順を保つ |
| targetOperationAt・WarningLocated | L22 の一般化をそのまま保つ。抽象環境の二表・元のキー・直接 call の宣言を同定する。位置の認定自体は funName/opName と標準規則一般を扱うが、固定域の警告の候補には WarningOperationSyntax と rangeCallBinding の限定が別に必要である。C4 前からの意味の拡張として報告する |
| arithmeticOperationAt | C4 前の targetOperationAt を改名したものと本文が一致する。arithmetic_target_at により、任意の二表とキーで算術の演算の同定を保つ |
| WarningOperationSyntax・concreteRule・syntacticReachChildren・InSyntacticReach | HTTP の根と子への拡張を取り消す。C4 前に対する拡張は、固定域の純粋なシフトの call 自身と引数だけである。構文だけの call の引数の候補は上界であり、未認定の内側の除外までをこの述語だけで主張しない |
| CallReach.exprTables・Scope.allows・WarningsInCallReach | HTTP の gate と子を除く。シフトの根には同じキーで認定した同じ束縛、引数には親の認定を要求する。既存の認定済み Range の引数の範囲を保つ。未認定 call・利用者関数・対象外の標準 call の内側を除外する |
| IndependentResult.Sound と式・本体・全体の公開の保証 | 定義の文面と入口の主定理の言明を保つ。参照する警告範囲は上のシフトの限定的拡張を受け、HTTP の範囲は除く。各独立入力自身の忘却後の環境と元のキーで保証し、未知の親の空 trace を根拠に子の失敗を主張しない |
| 算術の公開の系 | arithmeticOperationAt の等式による演算の同定を保つ。未認定 call の内側の除外は WarningsInCallReach の定理が担う |
| 解析・予算・本体/全体駆動 | HTTP の保持と走査を除く。Range とシフトの正常値・警告の証明を再接続する。予算の状態機械と本体/全体の順序は変えない。C4 前から残る型引数付き funName の標準表の照会の費用は、下の固定表の差へ明示する |
| EvalClosed | HTTP の構築・更新・欄の結果を除く。操作とレコードは none。シフトでは域外の outsideDomain、域内で許す unknown の失敗を選ぶ。evalClosed_sound の前提・結論は変えない。この unknown を実 VM の結果の予測に使わない |

B_WORK から言明が変わった名前付きの公開補助定理は5件である。baseValuesWith_models・baseValues_field・selectArguments_normal・expr_value_normal は、削除した HTTP の ValueModels を通常の Contains に戻した内部の合成補題であり、C4 前の基準には存在しない。concreteRule_known は、L24 で加えた recordKnown を除き、C4 前と同じ前提・結論に戻した。HTTP 専用の補助定理66件も除いた。公開入口の正常値・警告の主定理を弱める変更ではない。

[公理照会入力](axioms.lean)と[成功出力](axioms.log)で16宣言を照会した。依存は propext・Classical.choice・Quot.sound の範囲内であり、fixed_at_disjoint_failed は propext・Quot.sound である。sorry・独自公理・Builtins.Assumptions の追加、旧主定理の変更、native_decide の追加はない。D15 の停止条件に当たる必要は生じなかった。

## 独立例と作成時の関門

守る契約は、純粋なシフトだけの固定域の認定、不交差だけの W0404、引数のソース順、親へ返せる警告の範囲である。opName を固定域の認定に戻す、record の子を親の候補へ戻す、幅そのものを上端にする、交差・Top・Bottom に域外の候補を作る、後続の引数と親の事象を早く評価する変更で期待値と食い違う。

- DomainExamples の11組の #guard は、既存の全20シフト方向について2引数順×7区間の280解析と2引数順×4具体値の160評価、最大値の左シフト、二表の不在・偽装・元キーの違い、不正な位置、子の失敗・return、操作の認定の除外を確かめる。
- Process.exit(300) と port=65536 の Http.Listen.listen は W0404 を作らず、rangeCallBinding は none となる。opName は固定域の表を渡しても認定しない。任意の具体環境・型内の値について、操作の正常値と未知の失敗の表層導出を構成子から示す。
- SyntacticReachExamples の新しい #guard は、未認定 record/update の欄の除数0が親の警告にならず、独立入力自身には残ることを実際の analyzeExpr で確認する。concreteRule と構文だけの候補も子を除外する。
- FixedDomainExamples の5組の #guard と既存の局所証明は、七種と Byte の上端・存在しない rightUnsigned・交差と空区間・二表による位置の同定を保つ。targetOperationAt の一般の位置同定と、固定域の認定は区別する。

期待する整数・警告のキー・失敗種・候補の有無は独立に記述した。解析器・評価器の具体計算をカーネルへ展開せず #guard とした。評価関係の例は構成子の合成で示す。テスト専用の本番の引数・フラグ・公開範囲は加えていない。

削除した例は今回の対象から除いた操作の固定域と HTTP の追跡を確かめるものに限る。遅さや重複を理由にテストを消したものではない。BudgetAnalysisExamples は、削除した非整数の局所参照の追加走査に合わせて operationStop の上限15→14・numberingStop の上限18→17・期待操作数15→14を C4 前の値に戻した。同じ停止種別・警告保持・一時項目の返却を保ち、条件を外して通していない。

差分は、例のモジュールが追加79行・削除553行、例以外の formal が追加83行・削除2610行である（結果保存用のスクリプトと設計書を除く）。Rust の本体・テストの差分は0行である。

## 固定表への影響

[採取器](reference-impact.py)は、保存済みの A18a の実交換から解決済み Range 宣言を取り出し、元の budget-reference.lean と summary-reference.lean を**各一度だけ**、順に実行した。型欄 argumentTypes の既定値 [] を一時入力で明示しただけで、入力式と予算の選択規則は変えていない。budget-reference は70.342秒、summary-reference は17.070秒、どちらも終了0、-M 6144・300秒上限である。

[全差分](reference-impact.json)と、[body の採取結果](reference-output/body-new.tsv)・[whole の採取結果](reference-output/whole-new.tsv)・[summary の採取結果](reference-output/summary-new.tsv)を保存した。これらは L25R の記録であり、A11 の表そのものは書き換えていない。生成元・再生成器・README を含む7ファイルのバイト一致と SHA-256 は audit.json に保存した。

「変更」は同じ `(name, kind, cap)` の列が違う行、「追加」は元の選択規則による最小完走予算の変化で新しく選ばれる行である。削除は0行である。

| 表 | A18 後の保存済み行数 | L25R の選択行数 | 同じキーの変更 | 追加 |
|---|---:|---:|---:|---:|
| body | 18336 | 18350 | 492 | 14 |
| whole | 6304 | 6304 | 0 | 0 |
| summary | 6304 | 6304 | 0 | 0 |

| body の形 | 最小完走予算の旧→新（本体操作/本体保持/全体操作/全体保持） | 変更行 | 追加行 |
|---|---|---:|---:|
| call | 19/19/19/19 → 20/19/20/19 | 48 | 2 |
| s8_matchUnknown | 41/26/41/26 → 42/26/42/26 | 74 | 2 |
| s16_matchUnknown | 41/26/41/26 → 42/26/42/26 | 74 | 2 |
| s32_matchUnknown | 41/26/41/26 → 42/26/42/26 | 74 | 2 |
| u16_matchUnknown | 41/26/41/26 → 42/26/42/26 | 74 | 2 |
| u32_matchUnknown | 41/26/41/26 → 42/26/42/26 | 74 | 2 |
| u64_matchUnknown | 41/26/41/26 → 42/26/42/26 | 74 | 2 |

7形とも、変更する列は operations・saved・peak・next・stop・independent・unsupported であり、警告列そのものの差はない。小予算では停止位置と保存済みの内容も変わる。型引数のある直接の funName も standardCallHead で読むため、rangeCall が rangeStandardAt の出現表の一参照を行うことが残る差の原因である。L24 にあった非整数の局所参照と record/update の HTTP の追加走査による差は除かれた。他の103の body の形、whole と summary には差がない。

## A19〜A21 の枝の案

以下は取りまとめへの案であり、plan.md・decisions.md は変更していない。A20（HTTP の欄の追跡）は除く。「予算の固定表」と、シフトの契約を持つ「標準宣言の表」は区別する。

| 枝の案 | 範囲と完了の条件 | 検査・レビュー・受け入れ | 見込み |
|---|---|---|---|
| **A19a: 全入力の計上と予算の固定表** | 最初に、型引数付き funName も含む rangeCall の走査順・回数を新しい Lean とそろえる。opName は標準表の探索前に断る。非整数の局所参照に追加の rangeEntry を置かず、record/update に httpBinding を置かない。固定域の宣言のない入力でも、上の7形の費用と任意の小予算での停止・分類を一致させる。**この枝でだけ予算の固定表を新しい Lean から作り直す**。事後減算や予算境界の除外で合わせない | A19 の Rust の work（全統合・lib・fmt・examples 込み lint・生成物/仕様集計）。保存済み入力と全列の比較、独立レビューと受け入れ | 1〜3時間。work 10〜25分、レビューは不明 |
| A19b: シフトの標準宣言の表 | 読み込み済みの解決済み標準宣言だけから、七種と Byte の契約・型・引数名を作る。同じ役割を持つ別名の宣言も全て含める。Integer.shift* と Integer64.shift*、UnsignedInteger.shift* と UnsignedInteger64.shift*、UnsignedInteger8.shift* と Byte.shift* を省かない。現行の実在する27宣言を同定し、存在しない符号なし/Byte の rightUnsigned を作らない。構成にないモジュールをロードしない | A19 の Rust の work、宣言と名前解決の正負例、独立レビューと受け入れ | 1〜2時間。work 10〜25分、レビューは不明 |
| A19c: シフトの直接引数と候補 | standard_argument と署名を使い、解決済み宣言・元キー・引数の型と契約位置・ソース順をそろえる。BudgetScan.domainEntry/domainCallShape と selectArguments の計上を接続する。認定した引数を親で解析し、対象位置だけを保持する。未認定 call の独立入力・unsupported との違い、交差/Top/Bottom/先行失敗、全域外だけの候補を確かめる。予算の固定表はここでは再生成しない | A19 の Rust の work、名前付き引数と小予算の接続例、独立レビューと受け入れ | 1〜3時間。work 10〜25分、レビューは不明 |
| A21a: W0404 の直接引数の型板 | シフトの直接引数だけの主文・ラベル・inferred_range・allowed_range・local_analysis・origin と説明を登録する。D19 の field_message と欄用の文言を登録しない。説明の argument or field も直接引数の説明へそろえる。fix は付けない | A21 の Rust の work、診断の型板と生成参照、独立レビューと受け入れ | 1〜2時間。work 10〜25分、レビューは不明 |
| A21b: 診断・JSON・対象外の境界 | 不交差の候補だけを W0404 にし、一次位置・最大8補助位置・注記・JSON・重複の規則を既存 renderer へ接続する。操作には W0404 を作らず、RV-C4-response のハンドラで処理した Process.exit(300) を check と実 CLI で確かめる。HTTP の status/timeout の候補を作らない。未到達・子 Bottom・交差/Top を重ねない | A21 の Rust の work、CLI/診断の正負例、独立レビューと受け入れ | 1〜3時間。work 10〜25分、レビューは不明 |
| A21c: 文書・Skill と接続の閉鎖 | 02-05・02-10・03-06 と生成 Skill をシフトだけにそろえる。操作と HTTP の欄を対象にした03-07/03-09の追記は行わない。既存の E・Option/Result の規則を保つ。S-A4 と後続の交換へ渡す | 文書の work・生成参照、取りまとめがシフトに絞り直した接続の stage、独立レビューと受け入れ | 1〜2時間。文書 work 3〜10分、stage と受け入れの時間は割り当て後 |

走査の順序と回数の正は、BudgetRange.lean の **BudgetScan.rangeCall・rangeStandardAt・rangeStandard・domainCallShape**、BudgetDomainScan.lean の **domainEntry・domainExprsLength・domainPermutation・domainRange・domainIsPerm・domainContains・domainErase**、BudgetSelect.lean の **BudgetAnalysis.selectArguments・bindingArgument・selectedFixedOwn**、BudgetAnalyze.lean の **expr（local/call と未知の形への振り分け）・fixedOwn・saveWarnings** とする。既存の Range の借用の走査と保存は BudgetRangeBorrow と BudgetRange の各関数に従う。root の identify と expression、callee の skip、引数容器の classification、各子の順序と回数を含める。HTTP の追加走査を引き継がない。

L28・X03c は、シフトの域内で evalClosed が unknown の失敗を選んだ入力を、未知を含む入力として VM の実行比較から外す。域外のシフト量とその引数評価・到達の比較を残し、exit・listen・respond・send と HTTP の欄を比較対象へ戻さない。標準宣言の表と実ソース・VM の一致は引き続き A1 の信頼の範囲であり、今回の Lean の例で比較済みとはしない。

## 検査・途中の修正・計測

実行場所は `<repo>`、固定版は Lean 4.34.1・Rust 1.98.1である。lakefile.toml の moreLeanArgs の **-M 12288 は不変**である。[build.py](build.py)は依存順に一モジュールずつビルドし、Lake 内部に未ビルドの依存を並行起動させない。共通の排他ロックと、L23 の process-control.py による時間上限・プロセス群の終了回収を使った。試しの計算と例の直接検査は -M 6144、既存 Sound は175秒、既存 Examples と例の直接検査は25秒、その他は300秒を上限とした。時間上限・終了143・メモリ不足による停止、上限を上げた再試行はない。

| 検査 | 結果・時間 | 記録 |
|---|---|---|
| 依存順のビルド | Benitoite の依存255モジュールを直列に確認し、終了0。コメントと例の準備の訂正後も同じ順で終了0。Sound 32.737秒、BudgetNormal 13.145秒、BudgetSound 21.466秒、Examples 2.434秒 | [development-logs.zip](development-logs.zip)・[索引](development-logs-index.json) |
| 新しい例の直接検査 | DomainExamples 0.545秒、SyntacticReachExamples 0.481秒、-M 6144、終了0。最後のビルドでも成功 | domain-examples.log/json・record-examples.log/json |
| 公理照会16宣言 | 終了0、0.645秒。依存は上記の範囲 | axioms.lean・axioms.log/json |
| 既定ターゲットの事前確認 | `lake --no-build build`、終了0、0.144秒、既定の357 jobs が最新 | ready.log/json |
| 指定 work と同じ基準・指定の dry-run | 終了0、0.010秒。三単位だけを選択 | dry-run.log/json |
| 指定 work、一度 | **検査本体0、65.252秒。三単位成功。外側の計測器1、65.281秒** | work.log・work-check.json・work.json |
| work の仕様例と対応表 | 7件成功、失敗0、ignored 0、3.13秒。仕様集計の自己検査成功、初回リリースの未記入の完了条件 none | work.log |
| 最終点検の訂正後の formal_build のみの再確認 | 検査本体0、0.161秒。先に同じ基準・指定の dry-run を実施。既定ビルドと sorry 拒否を再確認。計測器は下記の制限で1 | formal.log・formal-check.json・formal.json・formal-dry-run.log/json |
| 主定理・参照定義・固定表・index の点検 | 成功。開始版と C4 前の基準を照合 | audit.py・audit.json |

指定 work は [work-check.py](work-check.py) から次のコマンドを一度実行し、外側を `/usr/bin/time -l` で包んだ。Cargo は既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。

```sh
scripts/check.sh --level work --base 62949b1d91bd2cd0c8e5aa546deb79614274cbb6 --only formal_build,spec_examples,spec_tally
```

**最大常駐量（maximum resident set size）はサンドボックスの制約で取得できなかった。** 検査本体の終了0の後、time が `sysctl kern.clockrate: Operation not permitted` を報告して終了1となった。real/user/sys は65.27 / 413.02 / 57.69秒である。未取得を0としていない。最終点検後の再確認も同じ制限で取得不能だった。

途中の失敗と修正も開発ログへ保存した（344ファイルの ZIP と SHA-256 の索引）。HTTP の宣言・構成子を除いた初回には、残る namespace、異常終了の構成子の共用した分岐、削除済みの走査を前提とする証明、HTTP の二条件を読む射影、HTTP 専用の公開補助定理への参照が残り、ビルドが失敗した。それらを除き、通常の Contains・Range の保存・走査のない合成へ接続して成功した。BudgetNormal の元からある maxRecDepth/maxHeartbeats の局所指定を編集時に落としたことで heartbeat の上限に達した試行は、元の指定を復元して閉じた。時間・メモリの上限を増やしたものではない。

BudgetAnalysisExamples の停止例は、HTTP の追加走査を除いたことで旧上限と停止種別が合わなくなり失敗し、上記の C4 前の値へ戻して成功した。公理照会の初回は存在しない analyzeBody_normal_sound を指定して失敗し、実在する analyzeBody_normal へ訂正した（axioms-first.log/json）。点検器の最初の二試行は、C4 前では arithmeticOperationAt が targetOperationAt という名前だったことと、承認済みの L22 の位置の補助定理の一般化を一律の文字列一致として扱って失敗した。改名後の定義の一致と、位置の補助定理2件を分けて照合し、実装や保証を変更せず成功した。

指定 work の後に、HTTP の追跡の説明が残ったコメント4箇所を訂正した。さらに、recordUpdate の新しい例の更新元を Unit から同じレコード型の未知の局所位置に替え、型検査済みの入力に対応する準備とした。新しい例の直接検査は -M 6144 で終了0、0.437秒である（record-input-final.log/json）。解析・評価・予算の実行定義は変わらず、固定表の計算を再実行していない。古くなった Lean のビルドだけを直列に確認し、formal_build と sorry 拒否を再実行した。仕様例と仕様集計は重ねていない。

## 申し送り

L25R の実装・写し・例・指定検査は閉じた。取りまとめには、D4・D15 の変更に対応する警告範囲、中心二命題と言明が参照する定義の差の向き、操作の未知の導出、固定表の差、上の A19〜A21 の案を独立にレビューして受け入れてもらう。コミット・取り込み、計画と判断の文書、docs/todo の更新・保管・公開は取りまとめの担当である。レビュー・受け入れの所要時間は不明である。

Rust の接続・交換・実 VM の比較・stage・change・release・性能測定は本枝の担当範囲に含めず、上表の担当と L28/X03 へ引き渡す。これらを実施済みと報告していない。private/ とそこを指すリンクは読まず、git の変更操作・担当の委任は行っていない。

## 取りまとめのレビュー（2026-10-26）

受け入れる（独立の再レビュー RV-C4R を続けて行う）。取りまとめも基準 `62949b1d` と作業ツリーを比べ、中心二命題・`AbstractSlot`・`AbstractEnv`・`SlotModels`・`Models` の定義の本文が一致し、sorry・公理・`decide +kernel` の追加がないことを確かめた。`standardCallHead` は `.funName` だけを認定し、`concreteRule` は record・recordUpdate を候補に含めない。番人の停止はなかった。固定表の差は body の 7 形（492 行の変更と 14 行の追加）だけで、A19〜A21 の枝は計画の変更（2026-10-26、L25R・L25S を受けて）でこの結果の案をもとに置き換えた。
