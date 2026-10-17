# P2 判断と受け入れ条件の対応表

## 照合の範囲

[型・所有関係の確認表](interfaces.md) と同じ HEAD で、[design.md](../design.md)、[decisions.md](../decisions.md) の Q1〜Q14・R1〜R10・R12、[answers.md](../answers.md)、[harness-response.md](../harness-response.md) を照合した。本書は後続作業の受け入れ条件の確認表であり、新機能の検査が実施済みという意味ではない。現在の出力の基準は [P1 の契約表](../p1/contracts.md)、版・入力・固定ハッシュの基準は [P1 の入力表](../p1/inputs.md) を引き継ぐ。

## Q と受け入れ条件

| 判断 | 守る観測可能な契約と対照例 | 主な担当・検査の境界 |
|---|---|---|
| Q1 main の報告 | check --report=json は単一 JSON+LF、実行なし、診断の stderr 重複なし。report なしの出力を維持。純粋/複数エフェクトの成功0、E0414/E0101/構文/名前解決の失敗2、不具合3、出力失敗1 | C1a/C1b/C2a/C2b/C3、tests/cli_process.rs |
| Q2 エフェクト・shell | Scheme.effects の宣言上限、IO.All の10個、原子的な13名、辞書順・重複なし。Assert.Check を保持。die の未処理/完全処理/usesに残す、裸の try/or return を対照。shell は未読/importだけ/直接呼出し/値の取得/依存/到達しない関数/利用者の同名/文字列・コメント/操作名だけを対照にし、検査失敗は不明 | C1b/C3/T2b、CLI の報告。契約表の欠落は抽出の持ち主で内部エラーとして扱う |
| Q3 共通報告 | 全必須欄・型、status/complete/targetsComplete/executed=false、requestedTargets と診断添字、全体不完全時 aggregateEffects=null。純粋な [] と不明の null、testsなし [] と未確定 null、description省略 null と空文字を区別 | C1b/C2/T2b/T3、cli_process/test_command。共通構築器の同じ契約を両方で重複して試さない |
| Q3 ソースと位置 | 読んだ同じ全バイトを SHA-256。BOM/LF/CRLF/不正UTF-8、import/package.bnt/依存/prelude を対照。読み取れないものを成功項目へ作らない。sourceId は targetId+FileId、同じ表示パスも統合しない。位置は既存 renderer、パスの復元は保証外 | C3 にバイト列と独立した sha256 の比較、T2b/T3 に入口と sourceSets の対応。Wasm・ハッシュ検証だけの入力・未存在設定は対象外 |
| Q4 非実行の test | 通常 test と対象・順序・重複・根・パッケージ境界・リンクが同じ。main不要、import先@testは追加しない。通常の検査失敗後も継続、部分成功を残し全体の和は null。空ディレクトリ/テストなし成功と未確定を区別。Console出力・目印書込みの両方を起こさず、test/testSummary行なし | T1a〜T3、test_command/fmt_command。通常 test の同じ fixture を対照にする。非実行は時間待ちで判定しない |
| Q4 引数 | reportだけは testCheckReport usageError・2で非実行。check単独はstdout空・診断だけ。checkとmax-call-stack/全wasm/allowは拒否。fmtへreport/allowを漏らさない | T1c/T2b、args の既存表と公開 CLI |
| Q5 上限 | 両構文、空集合、順序自由、余分な許可を受理。不足は関数名位置・辞書順の不足/許可・E0512・2、stdoutと目印は変更なし。二回指定/重複名/空要素/空白/未知/IO.All/別名/利用者名/*を拒否。runのscript後は引数 | A1/A4、解析の持ち主と cli_process。Assert.Check の不足と余分な許可も比較 |
| Q6 test全体の開始 | 後ろに不足/検査失敗/コンパイル制限があれば先頭の書込みも開始しない。全成功なら通常と順序・結果が一致。同じ成果物を消費し再読・再検査なし、全体の一時点のスナップショットは保証外 | A2a/A2b/A3/A4、test_command と所有・呼び出し元のレビュー。競合を作るフック不要 |
| Q7 問い合わせ | --version=json は最初の引数のみ、余分/未知値を拒否。単一JSON+LF、Unicodeは実ビルドの値、旧二行は維持。formatsは提供済みキーと整数の双方で能力を示す | V2/C3/T3/A4/E1/S2、cli_process。後述の公開時点の表と照合 |
| Q8 ビルド情報 | commit/dirtyの不明はnull、明示unknownの由来はenvironment。未指定dirtyはnotCollected、Gitを起動するのはcommit自動採取だけ。アーカイブが親repoの値を採らない。TARGETを使用、実行時環境とGitに依存しない | V1a/V1b/V2、独立した実ビルドとcli_process。R2/R10を優先 |
| Q9 既存形式1 | diagnostics/testResults は0.0.6のdie/code:null/failure.dieを含む形。行の欄・型・開始行を増やさない。無視できない意味変更には形式の版が必要。不明を空や成功へ補わない | V2/C3/A3/A4、cli_process/test_command/golden とP1表。usageErrorだけの例外はR5 |
| Q10 明示環境の拒否 | 全実行のrun/runAttached、DYLD_/LD_のASCII大小無視。追加/同値上書き/空値/小文字/LD_RUN_PATHをInvalidInputで拒否。元の名前の辞書順の先頭だけを示し値は出さない。既存不正入力が先、子の目印なし | E1、l10_console_clock_process/l13_external_commands/runtime_builtins の適した既存表。read_commandのStop・新しいEへ置き換えない |
| Q11 継承 | 親のダミー変数と通常の追加・上書きは継続。子プロセスのenvへ渡して対照とし、親プロセスの環境を大域変更しない。shellの継承、envやshell経由の設定、PATH・孫は本制約の保証外 | E1/D1〜D3、実プロセスの境界と文書。継承/削除のAPIは追加しない |
| Q12 Skill | FILES全件を論理名の辞書順でlist。showはSKILL.mdだけの版置換をinstallと共有、末尾改行を追加しない。HOMEなし/書込み不可でも取得。絶対名/空成分/./../バックスラッシュ/コロン/未知名/引数過剰/format重複・未知値を拒否。showの名前とformatは両順序、list/showとinstall/uninstallの専用オプションは相互に拒否 | S1/S2、cli_process/skill_docs/skill_examples。不整合は一覧検証の持ち主、外部入力は公開CLI |
| Q12 JSON | skillList/skillDocument とproducer。置換後のUTF-8のbyteLength・独立したsha256・textが一致。非ASCIIを含めてlist/show/installを比較。失敗stdout空、成功の空文書を作らない、出力失敗1 | S2、同上。本文や一覧の単なる写しだけをテストにしない |
| Q13 順序と移行 | 版はM2bで一回だけ0.0.7へ。環境拒否をBREAKING_CHANGESとE0908のsummary/helpへ登録。純粋でも旧宣言をE0908、0.0.7受理/未来E0907/不正構文は元の理由。宣言なしへ新しい必須条件なし。固定ハッシュ・通常入力・生成元・訳・CHANGELOGを揃える | M1/M2a/M2b/M3a/M3b、package_command/modulesの既存検査とP1入力表。R12の正のハッシュも含む |
| Q14 既存保証 | 通常run/checkのstdout、dieの1/code:null、test.failure.die、0/1/2/3/130、Process.exit指定値、mainは組込みだけ、組込みモジュール別名禁止を維持。報告後のmain/import/testへの追加エフェクトを拒否し、同じ集合で対象だけの変更は拒めない | C3/A4/D1〜D3/F1/F2、公開CLIと既存型検査の境界。ハーネス組込み試験や未作成タグの公開を完了条件へ混ぜない |

## R と受け入れ条件

| 判断 | 追加・置き換えた条件 | 担当と確認方法 |
|---|---|---|
| R1 非実行の集計 | 全探索済みN>0ならtest行なし・passed=failed=0・filesNotRun=N。誤りのない入口、テストなし、明示重複もNに含む。探索失敗/未知件数は集計なし。中断130/不具合3/拒否2、既知で安全な境界だけ集計、件数の飽和なし | A2bで基本動作、A3で対照表。test_command、Summaryの既存形式を保持 |
| R2 再採取 | build.rs/二つの明示入力/存在するHEAD・参照中ref・packed-refsのみ監視。実際のgit-dir/common-dir/git-pathを使う。dirtyは自動採取しない。明示commitならGitの起動・監視なし。不正明示値はビルド失敗 | V1a/V1b、tests/build_info.rs。通常/detached/worktree/packed/アーカイブ/採取失敗/明示値を同じ表で確認 |
| R2 監視の対照 | HEAD/ref/packed-refs/明示値変更は再採取、通常/ステージ/未追跡/無視の編集だけでは再採取なし。loose refありとpacked-onlyで同じ構成の二回目に再コンパイルなし。packed-onlyからloose新設など未登録ファイルの変化は検知保証外、明示入力の変更かclean buildが必要 | V1a/V1b/V2、実ビルドの生Cargo出力。ソース変更の通常再コンパイルと区別。05-01と回答文にも限界を記す |
| R3 モードの認識 | diagnostics=text/report・未知オプション/reportの正逆順とも同じkindのusageError・2。testはcheckなしでも包む。スクリプト引数/既知の分離値としてのreport字面をモードと誤認しない | C2a/T2b/A1、CLI表。公開parse_argsはStringの契約を維持 |
| R4 形式化 | 既存Schemeの読取り・包含、既存IOErrorの入力条件に留め、構文・型の受理・脱糖を変えない | P2で現実装と07-04を再判定済み。D1/F1で差分を再確認。広がれば実装前に再設計 |
| R5 usageError | kind:check/code:nullは新報告内だけ、severity:error、無位置primary:null。既存diagnostics形式1のJSON Linesへ追加せず、報告の初版1へ含める | C2a/T2b、02-10の表と例外、報告/既存出力の対照 |
| R6 HOMEの遅延 | toolsはrun_skill_cliへ。共通解析後install/uninstallだけでHOME取得。公開run_skillの引数・渡されたhomeの意味を保つ | S1、HOMEなしの取得と既存install/uninstallの保護・出力を対照 |
| R7 実施単位 | 未使用の欄・variant・APIを先置きしない。V1はbuild.rsと独立テスト、V2で実行時build_info、C1bでreport、T2bでbinding/tests/Unknown、A2bでPathArgs.allow_effects | 全Rust作業のClippy。interfacesの表と作業の枝番を照合。M2bの版・入力・ハッシュは同時更新 |
| R8 中断の読み口 | ファイル開始前だけ。ファイル後/報告直前に増やさない。最後のファイル中の要求を必ず報告するとは書かない | T1c/T2b、既存InterruptSourceと呼び出し元のレビュー、test_commandの既存中断境界 |
| R9 集計の文言 | 通常も上限付きも `; {count} files not run`。FAILEDの判定・件数・JSONは維持 | A3、reportの既存表とtest_commandの全文期待値を同じ厳密さで更新し、変更前後と理由を記録 |
| R10 独立した実ビルド | 本番build.rsを小さい一時クレートへコピー、絶対target-dir・子の環境分離・固定Cargo/Rustc。失敗gitをPATH先頭に置き、cc/リンカ/SDKを維持。longで明示実施、通常テストのignoreを成功と読み替えない | V1a/V1b/V2、build_info --include-ignored。実施前に見込み時間を知らせる |
| R12 固定ハッシュ | modules/tests.rsに加えmodules/hash.rsのFIXED/CONFIGも対象。三組の正の値を入力更新後に独立したPython hashlibで検算。ゼロの負のハッシュは保持 | M2a/M2b、P1 inputsの確認表を更新 |

## 本番へ接続する時点と formats

| 作業 | 初めて使うデータ・入口 | その時点で宣言する formats |
|---|---|---|
| V1a/V1b | ビルド時の埋込み変数、独立テストのみ。実行時モジュールなし | まだversion JSONなし |
| V2 | build_infoのJSONとVersionJson | version/diagnostics/testResults のみ |
| C1b | ReportFormat、Options.report、FunctionContractのname/location/effects、ProgramInspectionのmain/shell、checkReport | C3の対照までcheckReportキーを出さない |
| C2a/C2b/C3 | CliParseError/ReportKind::Check、認識後の失敗の接続 | C3でcheckReport |
| T1a/T1b/T1c/T2a | collect_testsのResult、run_prepared、Inspect/Execute、共有探索 | testCheckReportキーなし。inspectionの欄はT2b |
| T2b/T3 | PathArgs.report、ReportKind::Test、FunctionContract.binding、ProgramInspection.tests、ShellReference::Unknown、Prepared.inspection、request_index | T3でtestCheckReport |
| A1/A2a/A2b/A3/A4 | Options.allow_effectsとEffectLimit、実行準備、PathArgs.allow_effectsとExecuteLimited、全保持/全体拒否 | A4でeffectLimit |
| E1 | executeのInvalidInputと版情報のポリシー欄 | loaderEnvironment |
| S1/S2 | list/showと共通render_document、JSON取得 | S2でskillList/skillDocument |

design の「共通の所有データと変更する型」は最終形であり、先置きの指示ではない。inspection欄とrequest_indexを加える実施単位は、plan のT2bとR7を用いる。形式の完成と、0.0.7への版の更新・タグの作成・公開も別の状態として記録する。

## test-audit の作成時の関門

P2ではテストを新設・変更しない。後続作業で不足する検査は、既存の表へ対照例を加えることを基本とする。次の対応により、単なる実装の写しを増やさずに契約の検査を置ける。

| 独立した契約 | 現実的な退行 | 既存だけでは足りない理由と主な境界 | 本番の差し込み口 |
|---|---|---|---|
| 単一報告・完全性・null・入力バイト | 途中失敗を空の成功へする、loss化/再読でハッシュがずれる、認識したreportをpanic境界で失う | 既存cli_processは報告オプションを持たず、従来のstderr/終了状態だけを守る。新モードのCLI表で確認 | 不要。実ファイルと既存DEV_PANIC、既存出力先を使う |
| testの同じ対象と非実行 | 別の探索、import先の@test混入、Inspectからcompile/VMへ進む | test_commandの順序/探索/部分失敗のfixtureは通常実行の契約。新モードと同じfixtureで対照が必要 | 不要。Consoleと目印ファイルの観測を使う |
| 全体開始の条件と同じ成果物 | 末尾拒否前に先頭を実行、照合後にソースを開き直す | 既存通常testは失敗入口だけ飛ばす契約であり、全体拒否を守らない。CLIの先頭書込み/末尾失敗と所有のレビューで確認 | 不要。変更後に古いexpandedを渡す対照と、所有・呼び出し元をレビューする |
| ビルド情報の監視と不明 | 親repoの情報を拾う、dirty=falseを捏造、毎回再ビルド | 現在build.rsとbuild_infoテストがない。独立した実ビルドで挙動を確認 | 不要。本番build.rsをそのまま使い外部Gitだけ準備する |
| 明示環境のInvalidInputと非起動 | 入力検査をspawn後へ移す、read_commandのStopへ変える、値を診断へ出す | 既存外部コマンドのテストには新しい拒否契約がない。実プロセスの起動前とIOErrorを同時に観測 | 不要。安全なダミー環境と目印を使う |
| 埋込みSkillの取得・置換・ハッシュ | 未置換のSKILLを返す、インストール済み本文を読む、長さを文字数にする | skill_docsの生成済み検査とinstallの保護だけでは公開取得口を守らない。CLI取得とinstall本文を比較 | 不要。一覧の不整合は検証の持ち主で確認し、大域の故障フラグを追加しない |

今回削除したテストはなく、本番コードとテストの行数の増減はいずれも0である。上記は新機能の受け入れ設計であり、不具合修正の退行テストが変更前に失敗したという実績にはしない。
