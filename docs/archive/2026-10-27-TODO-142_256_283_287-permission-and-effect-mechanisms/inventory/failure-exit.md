# IF20.05: 失敗・テストの失敗・診断・終了状態の棚卸し

IF20.07 で RV-IF20 への対応を反映した。修正の基準 B_WORK は `d94d970baca8b21c2d33a62f3380c3562fb0cc57`、変更点と再集計は [IF20.07 の結果](../if20.07/results.md)に記す。以下の枝ごとの HEAD と B_WORK は当初の調査時点を示す。

## 対象と読み方

表の欄と数え方は [File の棚卸し](file.md#表の欄と数え方)に従う。本書は現行の設計書とソースの読解であり、0.0.14 の情報フロー制御（information-flow control）の扱いはすべて候補である。[IFC-D3・D4・D6・D8](../decisions.md#情報フロー制御の設計者への問い)の回答前に分類を確定しない。候補を採択した記録、実行による再現、現行の非干渉性の保証を示すものではない。

B_WORK と読解対象の HEAD はともに `37784a8c5ac62cb3efa0f972727765931d3ad5db` である。A 表は明示的な操作の宣言、C/S/T/D/H 表は構文・停止・ホスト報告等の補助経路である。die は独立の関数でなく `try ... or die` の処置であり、関数の件数へ加えない。Process.exit は IF20.03 と重ねて操作に数えず、C12 で終了への接続だけを記す。A06 は IF20.04 の Property.formatFailure と同じ宣言であり、枝を通した総数では重ねない。Assert の四操作は公開 effect Check のメンバーの明示的な関数宣言であり、BA の四登録と二重に数えない。Failure の二つのラッパーも明示的な宣言として数えるが、コンパイラが認定する Fail/raise は C13 の補助経路に分ける。Property の生成器・縮小器や任意の純粋な変換全件の棚卸しは IF20.06 の一般の派生へ引き継ぐ。

方向は表が数える段階に合わせる。A の Assert は既定の実行器が処理して外へ報告する場合を出口とし、言語のハンドラで処理する場合は IF20.06 へ分ける。S の外部の誤りの取り込みと報告は別行である。C12 の終了コードを含め、終了状態はホストや呼出側が読む情報として出口へ数える。診断の描画だけを数える行は出口とし、その材料の読み込みは D01 に数える。内部で値を作るだけの Property や Result は内部の派生とする。

「契約を設ける」は秘密に依存する失敗を常に許す意味ではない。文言・値・成否・位置・pc と受け手の条件を満たさない公開報告は拒否する候補である。資源や Task の発生元を拒否する候補と、その値を報告する際の契約を分ける。一般入力の文言・成否を保守的に秘密の結びとする候補は、完全性を信頼済みへ変える意味でもない。非機密化（declassification）とエンドースメント（endorsement。信頼の付与、または完全性レベルの引き上げ）の承認は別に要る。

## 入力とソースの略記

判断は [README](../README.md)、[decisions の表記と判断8・19・21](../decisions.md)、[plan の IF20](../plan.md#本番を変えない並行作業)を正とした。[questions](../study/questions.md) の D3/D4/D6/D8、[synthesis](../study/synthesis.md) の情報フロー制御の判断、[information-flow](../study/information-flow.md) のテスト・失敗と正常／異常の制御、[usage-and-flow](../study/usage-and-flow.md) §5 を読み、古い版の割り振り・訳語・API の案を現在の決定や構文とは扱わなかった。

前枝の [File](file.md)・[Http](http.md)・[Console/Process](console-process.md)・[表示/JSON/ログ](display-json-log.md) と、[IF20.01](../if20.01/results.md)・[.02](../if20.02/results.md)・[.03](../if20.03/results.md)・[.04](../if20.04/results.md)の申し送りを受ける。IOError/NetworkError/Json/Csv/Time/Scope/Range/Codec 等の文言の生成・表示は前枝を参照し、本書ではそれらが入口の Error、die、テスト、ホストの報告へ到達する段階を数える。

現行設計書は [00-01](../../../design/00-overview/00-01-goals.md)、[01-07 の IO の失敗と入口](../../../design/01-spec/01-07-effects.md#io-の失敗)、[01-08 の停止](../../../design/01-spec/01-08-evaluation.md#実行時エラーによる停止)、[01-09 の die](../../../design/01-spec/01-09-errors.md#失敗時に終了する処置)、[02-09 の停止・panic 境界・実行](../../../design/02-impl/02-09-runtime.md)、[02-10 の診断](../../../design/02-impl/02-10-diagnostics.md)、[06-01 の終了状態](../../../design/06-tooling/06-01-cli.md#終了状態)、[06-04 のテストの報告](../../../design/06-tooling/06-04-test-runner.md#結果の報告)、[07-01](../../../design/07-quality/07-01-security-model.md#各機構が保証すること)を照合した。

| 略記 | ファイルと役割 |
|---|---|
| A | [crates/benitoite/src/prelude/stdlib/Assert.bnt](../../../../crates/benitoite/src/prelude/stdlib/Assert.bnt)。四つの操作の宣言 |
| BA | [crates/benitoite/src/builtins/funcs/assert.rs](../../../../crates/benitoite/src/builtins/funcs/assert.rs)。Assert 四操作の登録。本体へ到達すれば Internal |
| FL | [crates/benitoite/src/prelude/stdlib/Failure.bnt](../../../../crates/benitoite/src/prelude/stdlib/Failure.bnt)。fromResult・toResult。Fail/raise はコンパイラの認定操作 |
| TE | [crates/benitoite/src/typeck/effects/declarations.rs](../../../../crates/benitoite/src/typeck/effects/declarations.rs)。入口に残る Fail と利用者のエフェクトの拒否 |
| RA | [crates/benitoite/src/runtime/assert.rs](../../../../crates/benitoite/src/runtime/assert.rs)。evaluate・failed_with・render_value |
| P | [crates/benitoite/src/prelude/stdlib/Test/Property.bnt](../../../../crates/benitoite/src/prelude/stdlib/Test/Property.bnt)。check・反例・縮小・formatFailure |
| IR | [crates/benitoite/src/ir/desugar/effects.rs](../../../../crates/benitoite/src/ir/desugar/effects.rs)。try と die の脱糖 |
| VI | [crates/benitoite/src/vm/dispatch/tasks/io.rs](../../../../crates/benitoite/src/vm/dispatch/tasks/io.rs)。own_exit_report・serve_inner |
| VD | [crates/benitoite/src/vm/dispatch.rs](../../../../crates/benitoite/src/vm/dispatch.rs)。main_outcome |
| VM | [crates/benitoite/src/vm/mod.rs](../../../../crates/benitoite/src/vm/mod.rs)。StopInfo・DieFailure・終了の型 |
| VU | [crates/benitoite/src/vm/dispatch/unwinding.rs](../../../../crates/benitoite/src/vm/dispatch/unwinding.rs)。停止・継続の破棄・解放の辿り |
| VR | [crates/benitoite/src/vm/dispatch/resource.rs](../../../../crates/benitoite/src/vm/dispatch/resource.rs)。資源の解放失敗 |
| R0 | [crates/benitoite/src/runtime/mod.rs](../../../../crates/benitoite/src/runtime/mod.rs)。RuntimeError・ResourceError・Stop の全構成子 |
| R | [crates/benitoite/src/runtime/run.rs](../../../../crates/benitoite/src/runtime/run.rs)。実行結果・終了の優先・最終転送 |
| RR | [crates/benitoite/src/runtime/report.rs](../../../../crates/benitoite/src/runtime/report.rs)。停止・die・解放・不具合の診断 |
| RP | [crates/benitoite/src/runtime/panic.rs](../../../../crates/benitoite/src/runtime/panic.rs)。panic hook と捕捉 |
| RI | [crates/benitoite/src/runtime/run/interrupt.rs](../../../../crates/benitoite/src/runtime/run/interrupt.rs)。シグナルの登録 |
| CL | [crates/benitoite/src/cli/mod.rs](../../../../crates/benitoite/src/cli/mod.rs)。main・write_run_reports・write_report_to・report_check |
| CR | [crates/benitoite/src/cli/check_report.rs](../../../../crates/benitoite/src/cli/check_report.rs)。非実行の単一 JSON 報告と出力 |
| TM | [crates/benitoite/src/cli/tools/test_runner/mod.rs](../../../../crates/benitoite/src/cli/tools/test_runner/mod.rs)。準備・failure_of・execute_test・finish |
| TR | [crates/benitoite/src/cli/tools/test_runner/report.rs](../../../../crates/benitoite/src/cli/tools/test_runner/report.rs)。文章・JSON Lines のテスト報告 |
| TD | [crates/benitoite/src/cli/tools/test_runner/docs/execute.rs](../../../../crates/benitoite/src/cli/tools/test_runner/docs/execute.rs)。doc の期待と出力・診断の比較 |
| DR | [crates/benitoite/src/diag/render.rs](../../../../crates/benitoite/src/diag/render.rs)。文章の抜粋・位置・JSON・修正案・履歴 |
| DE | [crates/benitoite/src/diag/render/excerpt.rs](../../../../crates/benitoite/src/diag/render/excerpt.rs)。修正案を当てた行 |
| ML | [crates/benitoite/src/modules/load.rs](../../../../crates/benitoite/src/modules/load.rs)。読み込みの誤りのパスと理由 |
| LX | [crates/benitoite/src/syntax/lexer.rs](../../../../crates/benitoite/src/syntax/lexer.rs)。不正な数値の字面と escape の文言 |
| TC | [crates/benitoite/src/typeck/interval/diagnostics.rs](../../../../crates/benitoite/src/typeck/interval/diagnostics.rs)。推定した区間の警告 |
| BP | [crates/benitoite/src/builtins/funcs/process.rs](../../../../crates/benitoite/src/builtins/funcs/process.rs)。exit の実装 |
| HS | [crates/benitoite/src/builtins/funcs/http_server.rs](../../../../crates/benitoite/src/builtins/funcs/http_server.rs)。accept の警告の出力 |
| HI | [crates/benitoite/src/runtime/io/http.rs](../../../../crates/benitoite/src/runtime/io/http.rs)。資源不足での再試行と警告 |
| IO | [crates/benitoite/src/runtime/io/services.rs](../../../../crates/benitoite/src/runtime/io/services.rs)。標準出力・標準エラーと出力の失敗 |

表中の Process.bnt は [IO/Process.bnt](../../../../crates/benitoite/src/prelude/stdlib/IO/Process.bnt)、Result.bnt は [Result.bnt](../../../../crates/benitoite/src/prelude/stdlib/Result.bnt)、pipeline は [pipeline.rs](../../../../crates/benitoite/src/pipeline.rs) を指す。doc の探索と集計は [test_runner/docs.rs](../../../../crates/benitoite/src/cli/tools/test_runner/docs.rs)、WASM の統計は [cli/wasm.rs](../../../../crates/benitoite/src/cli/wasm.rs) を参照する。

## 明示的な操作の表

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| A01 `Assert.equal` | A `Check.equal`、RA `evaluate / render_value` | 出口 | actual・expected と比較の合否→失敗時に両値・位置・履歴、成功してもテスト単位の合否（T10）に反映される。呼んだ条件も後続を変える | `Assert.Check` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 比較結果と値の表示の双方を出口の契約に含める必要があるためである。 |
| A02 `Assert.notEqual` | A `Check.notEqual`、RA `evaluate / render_value` | 出口 | actual・expected が等しいと失敗し両値を表示する。成功してもテスト単位の合否（T10）に反映される | `Assert.Check` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 失敗時だけ表示する値にも、合否を決めた値と pc の依存があるためである。 |
| A03 `Assert.isTrue` | A `Check.isTrue`、RA `evaluate / failed_with` | 出口 | condition→合否、false のとき message→報告。true でもテスト単位の合否（T10）に反映される | `Assert.Check` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | message を定数にしても condition の一ビットを出すためである。 |
| A04 `Assert.fail` | A `Check.fail`、RA `evaluate / failed_with` | 出口 | message と呼ぶ条件→失敗報告、テストの残りを実行しない | `Assert.Check` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 引数の文言と非再開による後続の有無をともに照合する必要があるためである。 |
| A05 `Property.check` | P:431 `check / trials / reduce / tryCandidates` | 内部の派生 | Config・生成器・縮小器・property と捕捉値→Ok/InvalidConfig/Falsified、元／縮小後の値・文言・回数・予算到達。自動では表示しない | なし。コールバックも純粋 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 純粋な比較・縮小でも合否・反例・制御依存を結果へ保ち、報告時の分類に接続する必要があるためである。 |
| A06 `Property.formatFailure` | P:501 `formatFailure`。IF20.04 D117 と同じ宣言 | 内部の派生 | CheckFailure と show→設定・seed・trial・shrinks・shrinkWork・limitReached・版、original/reduced と両文言を含む String | なし | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 呼び出し側の show と捕捉値を含め分類を保ち、生成した文字列を公開とみなさないためである。 |
| A07 `Failure.fromResult` | FL `fromResult` | 内部の派生 | Result.Ok を取り出し、Error(e) は元の e を Failure.raise へ渡す。Show を要求せず、既定のホスト報告を作らない | `Failure.Fail[E]` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | Error の内容と成否の依存を型付きの失敗へ保ち、変換を公開への変更にしないためである。 |
| A08 `Failure.toResult` | FL `toResult` | 内部の派生 | body を一度実行し、raise(error) の節は再開せず Result.Error(error) へ変換する。ほかのエフェクトと実行時の停止は残す | `Rest`。処理した `Failure.Fail[E]` を除く | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 標準の変換でも失敗・非再開の依存を結果と後続へ残す要約が必要で、Fail を除いたことを非機密化と扱えないためである。 |

## die・Result と正常／異常の制御

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| C01 `try ... or die(message)` の説明の評価 | IR `die_failure`、01-09「失敗時に終了する処置」 | 内部の派生 | 失敗時だけ message を評価する。説明なしと空文字列は別。説明の停止・発散なら die に到達しない | 説明は純粋、全体は `Process.Exit` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 説明の値だけでなく評価した条件と正常／異常の続きの依存が要るためである。 |
| C02 Result の die の原因を作る | IR `die_failure` | 内部の派生 | Result.Error(e)→選ばれた `Show.show(e)` の String。String の引用とエスケープも保持。Show の停止ならその停止を採用 | Show は純粋、全体は `Process.Exit` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | Show の分類・捕捉値・成否を失敗原因へ保持する必要があるためである。 |
| C03 Option の die の原因を作る | IR `die_failure` の `OPTION_NONE` | 内部の派生 | None→固定文 `expected a value, got Option.None`。Some/None の選択と呼ぶ条件は元の入力に依存 | `Process.Exit` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 定数の原因でも None で終える事実を観測できるためである。 |
| C04 die の任意の説明の報告 | VI `own_exit_report` → RR `die_diagnostic` → CL `write_run_reports` | 出口 | 所有した message→stderr の message 注記、JSON の notes。最後の出力転送の後に一度出す | `Process.Exit`、`Console.Write` 不要 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | ホストの出口にも説明と pc の分類・受け手の契約が必要だからである。 |
| C05 die の原因の報告 | VI `own_exit_report` → RR `die_diagnostic` | 出口 | Show 由来の cause→stderr の cause 注記、JSON の notes。説明を省いても必ず原因を残す | `Process.Exit`、`Console.Write` 不要 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | IOError/NetworkError の生の文言や利用者の Show の情報も原因へ入るためである。 |
| C06 die の発生位置とソースの抜粋 | VM `DieFailure`、RR `die_diagnostic`、DR | 出口 | try の span→stderr のパス・行・列と文章のソース行、JSON の primary。die 専用の call trace は付かない | `Process.Exit`、ホストの描画 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | どこで失敗したかとその行の別のリテラルも観測できるためである。 |
| C07 die の終了状態と発生の有無 | VI `serve_inner`、R `step_end` | 出口 | 失敗したか・既定 exit(1) が採用されたか→状態1と die 報告の有無、後続の非実行。成功時には説明・Show を評価しない | `Process.Exit` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 本文を伏せても終了・後続の違いが残り、SD の公開 pc の条件との接続が要るためである。 |
| C08 終了ハンドラによる置換と非再開 | IR `die_failure`、VI `own_exit_report / serve_inner`、07-01 | 内部の派生 | Process.Exit を処理すれば既定の終了・報告なし。置換した原因を後の独立 exit へ持ち越さない。継続を捨てると後続の作用が変わる | 処理された `Process.Exit` は型から除く | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 一般の節・捕捉・再開・破棄の依存は SD の最小の非再開モデルから導けず、契約が未接続だからである。 |
| C09 通常の Result.Error と Fail/try の伝播 | Result.bnt、IR `try_expr`、01-09「型付きの失敗と Result の変換」 | 内部の派生 | Error(e) は通常の値。match/mapError/try/or return と Fail の処理で値・正常／異常の続きが変わる。単に Error を作るだけではホストへ例外を投げない | 元の式・関数のエフェクト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 伝播中の失敗の印を保存し、入口の戻り値・die・明示出力へ到達したときに出口を照合する必要があるためである。 |
| C10 main の未処理の Error の文字列 | VD `main_outcome` → R `step_end` → CL `write_run_reports` | 出口 | Result[Unit,String].Error(msg)→msg と LF を素の stderr へ。`--diagnostics=json` でも JSON 化・端末文字の逃がしをしない | main は純粋でも可。`Console.Write` 不要 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 診断レンダラを通らない利用者出力として、msg と pc の分類を別途照合する必要があるためである。 |
| C11 main の Ok/Error と正常終了 | VD `main_outcome`、R `step_end / flush_failure` | 出口 | Unit/Ok→0、Error→1。空の msg でも LF と状態1。最後の転送失敗なら正常な戻りでも1へ、中断なら130へ変わる | main の uses だけでは終了の依存を表さない | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 正常／失敗の一ビットと報告の有無も情報フロー制御の対象候補だからである。 |
| C12 終了操作の値と発生条件 | Process.bnt `exit`、BP `exit`、R `step_end`。IF20.03 P05/X25 の再掲 | 出口 | code (0..255) と pc→CLI の終了状態。1/2/3 はホストの分類と重なる。範囲外なら R0701 | `Process.Exit` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 定数 code でも秘密で終了を選べ、状態だけでは die・実行時エラー・不具合を区別できないためである。 |
| C13 型付きの非再開の失敗 `Failure.raise` | FL、TE `check_entries`、01-09「型付きの失敗と Result の変換」 | 内部の派生 | コンパイラが認定する操作へ error を渡し、最寄りの Fail の節で処理する。言語の非再開と解放があり、入口に残すことは E0506 で拒否する | `Failure.Fail[E]` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 一般の未捕捉例外の出口を仮定せず、標準の変換と利用者のハンドラへ値・正常／異常の依存を保つ必要があるためである。 |

## 外部の失敗の入力と全停止種別・位置・履歴

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| S01 IOError の外部入力 | File/Console/Process の完了、IOError.message/kind。前枝の F・S・X 表 | 入口 | OS の種類と to_string、UTF-8 の成否、存在・EOF・起動/パイプ等→Result と分岐。子の非ゼロ終了は通常 Ok の exitCode | 元の File/Console/Process 等 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | D4 の一般入力の候補を失敗でも保ち、OS の文言を公開と仮定できないためである。 |
| S02 NetworkError の外部入力 | Http client/server の完了。http.md C12〜C20 | 入口 | 接続・DNS・TLS・時間切れ・解析等→種類・文言・Ok/Error。4xx/5xx は Ok、TimedOut は値 | `Http.Connect / Http.Listen` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 認証応答の値だけの D3 の契約を、一般の誤り・成否へ拡張できないためである。 |
| S03 0 による除算 | R0 `RuntimeError::DivisionByZero / R0101`、RR `stop_diagnostic` | 出口 | 除数と pc→停止の事実、固定の主文。被除数・除数の実値を報告の引数には入れない。位置・履歴は S29/S30 へ | なしでも起きる | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 純粋な部分演算の失敗から公開の報告・後続の非実行へ依存が出るためである。 |
| S04 整数の溢れ | R0 `RuntimeError::IntegerOverflow / R0102`、RR `stop_diagnostic` | 出口 | 整数の幅・演算結果と pc→停止。演算の実値を報告へ入れない。位置・履歴は S29/S30 へ | なしでも起きる | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 純粋な部分演算の失敗から公開の報告・後続の非実行へ依存が出るためである。 |
| S05 Decimal の溢れ | R0 `RuntimeError::DecimalOverflow / R0103`、RR `stop_diagnostic` | 出口 | 演算の結果と pc→停止。演算の実値を報告へ入れない。位置・履歴は S29/S30 へ | なしでも起きる | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 純粋な部分演算の失敗から公開の報告・後続の非実行へ依存が出るためである。 |
| S06 標準出力・標準エラーの書き込み失敗の入力 | IO `output_write_failure`、R `OutputPort.finish` の受理 | 入口 | OS の write/flush の成否・reason→WriteFailed。遅れて検出し、それまでの評価と IO は戻さない | 元の Console/Log/Http 等と終了手順 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 読み手の切断と文言も外部状態の入力だからである。 |
| S07 WriteFailed と最終転送失敗の報告 | RR `write_failed / add_flush_failure`、R `flush_failure` | 出口 | stream→R0201/R0202、reason→stderr/JSON の注記。位置・履歴なし。停止中は先の診断へ追記、exit/中断は別報告で状態を維持 | ホスト。`Console.Write` 不要 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 位置がなくても出力先・文言・報告有無を保護する必要があるためである。 |
| S08 暗黙の解放失敗の入力 | R0 `ReleaseFailure`、VR `release_failure` | 入口 | 外部の解放の kind・reason・opened_at→失敗の保存。通常復帰なら ReleaseFailed、停止途中なら補足。Exchange の暗黙の失敗は報告しない | `State` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 外部由来の理由と資源の依存を失敗の保存から落とせないためである。 |
| S09 ReleaseFailed と停止中の解放の報告 | RR `release_builder / add_release_failures / release_report` | 出口 | R0401、資源型・開いた位置・reason→stderr/JSON。通常の停止の注記、exit(code)/中断で止める理由の注記を分ける | `State` とホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 資源を取得・解放する操作の拒否候補とは別に、報告へ同じ分類を保つ契約が要るためである。 |
| S10 解放した資源の使用 | R0 `ReleasedResourceUsed`、RR R0402 | 出口 | 資源の型→主文、使用した位置・履歴。何をいつ閉じたかで失敗が変わる | 元の資源操作 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 資源の取得・閉鎖の依存を保持する契約が閉じておらず、File/Http の保持の拒否候補とそろえるためである。 |
| S11 継続の二度目の再開 | R0 `ContinuationResumedTwice`、RR R0501 | 出口 | 二度目を実行した事実・位置・履歴→報告、停止 | 元の関数・節 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 一般の再開・非再開と正常／異常の依存は最初の制限された契約へまだ接続していないためである。 |
| S12 引き継いだハンドラの節の誤り | R0 `InheritedHandlerClause`、RR R0502 | 出口 | operation の修飾名・位置・履歴・help→報告、停止 | Task と元の操作 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | Task に渡るハンドラと pc の一般の接続が未設計だからである。 |
| S13 引数が定義域の外 | R0 `ArgumentOutOfDomain`、RR R0701 | 出口 | function と1始まりの引数位置→主文。引数の実値そのものは渡さない。File.readChunk・Process.exit・HTTP等の要求検査も含む | 元の関数。純粋でも起きる | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 引数を伏せても定義域内かと失敗位置で秘密が区別できるためである。 |
| S14 HTTP 応答の二度目の送信 | R0 `ResponseSentTwice`、RR R0801 | 出口 | 二度目を実行した事実・位置・履歴→報告、停止 | `Http.Listen` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | Exchange に残る送信履歴と制御依存の契約がないためである。 |
| S15 タスクの待ち合いの行き詰まり | R0 `TaskDeadlock`、RR `deadlock_diagnostic` R1001 | 出口 | 進行不能→報告、停止。主位置なし、待つ一覧は S32 | Task / Lazy / ハンドラ等 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 待ちの成否も pc と捕捉値に依存し、Task を含む一般の接続が未完だからである。 |
| S16 取り消したタスクの結果待ち | R0 `AwaitedTaskCancelled`、RR R1002 | 出口 | 取り消されたか・await を実行したか→報告、位置・履歴、全体の停止 | Task の操作 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 取消し・待ちの分類は成功値だけでは表せず、最初の範囲の外とする候補だからである。 |
| S17 外部の関数のトラップ | R0 `ExternalTrap`、RR R0601 | 出口 | function・component の表示パス・export・trap 文字列、位置・履歴→報告 | 外部宣言は純粋または `State` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | ゲストが入力を文言へ反映するかと共有状態を含む分類契約が未接続だからである。 |
| S18 呼び出しの入れ子の上限 | R0 `CallStackTooDeep`、RR R0901 | 出口 | frames の数・発生位置・履歴・上限を上げる help→報告、停止 | 純粋でも起きる | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 明示的に書く frames と停止の事実は物理時間の保証外という理由で除外できないためである。 |
| S19 一操作で作る値の上限 | R0 `ValueTooLarge`、RR R0902 | 出口 | function・size・unit・limit→報告。size は要求した結果の量であり、本文を返さなくても派生値である | 元の関数。純粋でも起きる | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 秘密の長さから決まる size・停止を出口に含める必要があるためである。 |
| S20 大きさが決まらない入力の上限 | R0 `InputTooLarge`、RR R0903 | 出口 | function・unit・limit と超えた事実→報告。最終入力サイズの欄は持たない | 元の File/Console/Http/Process 等 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 結果の量を出さなくても入力の閾値判定と位置が公開の観測になるためである。 |
| S21 論理長の範囲内の確保予約の失敗 | R0 `AllocationFailed`、RR R0907 | 出口 | function・requested_bytes と確保不能→報告。全ヒープ量ではない | 元の関数 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 要求量には入力の依存、確保不能には実行環境の依存があり、公開とする根拠がないためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |
| S22 外部の燃料 | R0 `ExternalFuel`、RR `R0904` の分岐 | 出口 | function・component・limit と超過→stderr/JSON、停止 | 外部宣言は純粋または `State` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 外部の入力・状態・成否から報告への契約が未接続で、外部呼び出しの拒否候補を引き継ぐためである。 |
| S23 外部の線形メモリ | R0 `ExternalMemory`、RR `R0905` の分岐 | 出口 | function・component・limit と total guest linear-memory の区分→stderr/JSON、停止 | 外部宣言は純粋または `State` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 外部の入力・状態・成否から報告への契約が未接続で、外部呼び出しの拒否候補を引き継ぐためである。 |
| S24 外部の補助の確保器 | R0 `ExternalAdapterMemory`、RR `R0905` の分岐 | 出口 | function・component・requested/memory32_limit/allocated/store_limit の存在と取得できた量。確保失敗と memory32 超過を区別→stderr/JSON、停止 | 外部宣言は純粋または `State` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 外部の入力・状態・成否から報告への契約が未接続で、外部呼び出しの拒否候補を引き継ぐためである。 |
| S25 外部の受け渡しの予算 | R0 `ExternalTransfer`、RR `R0905` の分岐 | 出口 | function・component・limit と host value-transfer の区分→stderr/JSON、停止 | 外部宣言は純粋または `State` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 外部の入力・状態・成否から報告への契約が未接続で、外部呼び出しの拒否候補を引き継ぐためである。 |
| S26 外部の表とコア資源の数 | R0 `ExternalObjects`、RR `R0906` の分岐 | 出口 | function・component・resource・size・limit→stderr/JSON、停止 | 外部宣言は純粋または `State` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 外部の入力・状態・成否から報告への契約が未接続で、外部呼び出しの拒否候補を引き継ぐためである。 |
| S27 外部のコンポーネントハンドル | R0 `ExternalComponentHandles`、RR `R0906` の分岐 | 出口 | function・component・limit と超過。必要数は持たない→stderr/JSON、停止 | 外部宣言は純粋または `State` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 外部の入力・状態・成否から報告への契約が未接続で、外部呼び出しの拒否候補を引き継ぐためである。 |
| S28 外部の戻り値から作る値の上限 | R0 `ExternalValueTooLarge`、RR `R0902` の分岐 | 出口 | function・size・unit・limit→stderr/JSON、停止 | 外部宣言は純粋または `State` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 外部の入力・状態・成否から報告への契約が未接続で、外部呼び出しの拒否候補を引き継ぐためである。 |
| S29 実行時エラーの主位置 | RR `user_location / stop_diagnostic`、DR | 出口 | 命令の由来と残る枠→最内の利用者の位置。文章はソース行、JSON は primary。失敗した場所の選択も依存を持つ | ホストの報告 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 同じ固定文の停止でもどちらの式で起きたかを区別できるためである。 |
| S30 呼び出しの履歴と省略件数 | VM `StopInfo`、RR `call_trace / frame_name`、DR | 出口 | 残る関数名・lambda/handle/case の位置・呼出位置・省略数→trace/traceOmitted。末尾で離れた関数は残らない | ホストの報告 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 値を出さない履歴にも選んだ関数と制御の依存が残るためである。 |
| S31 タスクの起動の履歴 | RR `task_origins / spawn_frame` | 出口 | 起動操作名・起動位置・親の履歴・main/テスト関数名→taskOrigins | ホスト、Task | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | Task の生成・捕捉・取消しの分類を含めた契約が未接続だからである。 |
| S32 行き詰まりで待つタスクの一覧 | RR `deadlock_diagnostic`、DR `append_waiting / render_json_line` | 出口 | task・waitsFor・location、一覧の長さと有無→waitingTasks 等 | ホスト、Task/Lazy/handle | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 待ち関係と一覧だけでも秘密の制御を表せ、一般の待ちの契約がないためである。 |
| S33 停止による後続の非実行と既存出力の転送 | VU の停止処理、R `run_entry` | 出口 | 失敗の有無→後続の評価・要求を打ち切る。既存の stdout/stderr を順に転送、開始済みの外部作用は戻らない | 元の操作とホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 報告の内容を隠しても後続の出力の有無・列が変わるため、SD の失敗の観測に対応付ける必要があるためである。 |
| S34 停止・非再開時の解放の作用 | VU、VR、File/Http の資源解放。前枝の補助表 | 出口 | どの with を抜けるか→Writer の flush、Listener の閉鎖、Exchange の停止中の切断。解放を省いて秘密を隠さない | `State` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 資源に残る本文・宛先・pc と停止原因を解放へ保つ契約が未完だからである。 |

## テストの報告と合否・集計

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| T01 比較失敗の actual | RA `render_value` → TR `text_failure / json_failure` | 出口 | left→stdout の left 行／JSON left。構成子・レコードの欄・要素、未知型の構成子番号、最大4096バイトと省略印 | ホストの `Assert.Check` 処理 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 利用者の Show を呼ばない内部表示にも値と形の分類が要るためである。 |
| T02 比較失敗の expected | RA `render_value` → TR `text_failure / json_failure` | 出口 | right→stdout の right 行／JSON right。同じ4096バイト上限。expected 自体も取得した秘密になりうる | 同上 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 期待値を固定の公開値と仮定できず、actual と別の引数の由来を保つ必要があるためである。 |
| T03 isTrue/fail の文言 | RA `failed_with` → TR | 出口 | message→stdout の message 行／failure.message。condition・呼出条件で表示と失敗が決まる | 同上 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 固定の文言も失敗の発生条件を伝え、任意の文言には実値も入りうるためである。 |
| T04 失敗の位置・履歴・解放の注記 | TM `failure_of` → TR | 出口 | CheckFailure の at/frames/spawns、解放失敗→primary/trace/taskOrigins/notes と文章の位置。末尾呼び出しの注記も付く | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | Assert で止めた制御と資源の理由を診断と同じ分類へ接続する必要があるためである。 |
| T05 テストが返した Result.Error | R `MainOutcome` → TM `failure_of` → TR | 出口 | Result[Unit,String].Error(message)→stdout の returned error 文／failure.reason=error,message | テストの uses。`Console.Write` 不要 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 普通の Error の伝播がテストの入口を出ると値・成否の報告になるためである。 |
| T06 テストの実行時エラー・資源不足 | TM `failure_of`、TR `Failure::Runtime` | 出口 | S 表の診断→stdout の失敗詳細／reason=runtime の各欄。ほかのテストは続く | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | プロセスを続ける場合も一つのテストの失敗・位置・値が公開の観測になるためである。 |
| T07 テストの exit と die | TM `failure_of`、TR `Failure::Exit` | 出口 | 任意の code（0も失敗）・die の原因/説明/位置・補足報告→stdout。JSON は exitCode と必要なら die、補足の notes | `Process.Exit` とホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 終了コード0でもテストの合否が変わり、通常 run の成功と同じ意味にはならないためである。 |
| T08 文章形式の捕捉 stdout と stderr | TM `execute_test / write_summary`、TR `text_failure` | 出口 | 失敗したテストの捕捉出力だけ→stdout の各見出しと本文。成功時は表示しない。不正UTF-8は置換 | 元の Console/Log 等、転送はホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 失敗という条件に依存する本文の転送を、元の stderr の受け手と同じと仮定できないためである。 |
| T09 JSON Lines の捕捉 stdout と stderr | TR `json_test` | 出口 | 成功・失敗とも捕捉した両出力→stdout の stdout/stderr 欄。UTF-8 の置換後に JSON 引用 | 元の操作、転送はホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 診断の形式を JSON に変えると成功テストの内容も外へ出るため、出力経路を別に照合する必要があるためである。 |
| T10 テストの名前・説明・成否 | TR `text_line / json_test` | 出口 | file/name/function/location と passed/failed、failure の null/非null→stdout。宣言順に報告 | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 合否の一ビット、どのテストか、出力したかも秘密依存になりうるためである。 |
| T11 集計・未実行・中断と終了状態 | TM `finish / write_summary / execute_prepared`、TR | 出口 | passed/failed/filesNotRun/interrupted→stdout。通常の優先は中断130、未実行2、失敗1、成功0。不具合は直ちに3 | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 本文と値を伏せても件数・終端・途中まで報告した範囲が残るためである。 |
| T12 探索・準備の失敗と実行しない対象 | TM `select_test_entries / prepare / validate_prepared` | 両方 | 外部のディレクトリ/ファイルの成否→E0101 等の stderr。探索失敗なら開始しない。上限指定時は全入口を先に準備し、不足・検査誤りなら結果行なし | ホストの読み込み・検査 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | ファイル集合・成否・非実行数も外部入力に由来し、コードを走らせないだけでは公開にできないためである。 |
| T13 doc の静的誤りの期待と実際の診断 | TD `execute_example` の `Expectation::Error` | 出口 | expected の行と observedDiagnostics→diagnosticMismatch。JSON は stdout、文章の失敗詳細にも JSON を入れる | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | コメントに埋めた期待とソース由来の診断にも入力ソースの分類を保つ必要があるためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |
| T14 doc の実行出力・終了状態の不一致 | TD `Expectation::Run` | 出口 | expectedStdout/expectedStderr、実際の stdout/stderr・exit、mainError・diagnostics→docExample と outputMismatch。die_failure はこの不一致オブジェクトに直接入れない | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 期待と実際の内容・終了の比較を出口として扱い、通常テストと異なる保持欄を落とさない必要があるためである。 |
| T15 doc の内側のテスト・位置・集計 | TD `map_result / execute_example`、TM docs `write_counts` | 出口 | 内側の json_test と合成した捕捉出力、例の id/mode/location/outcome、集計→stdout。実行時の位置を元コメントへ写す | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | doc も実テストの値・合否を再報告し、元コメントの位置と例の有無に依存するためである。 |
| T16 Property の反例・縮小・設定の報告への接続 | P `Counterexample / formatFailure` → Assert.fail/Result.Error/明示出力 | 内部の派生 | original/reduced、originalMessage/message、seed・回数・予算の終了→文字列やレコード→T/C の出口。Property.check 単独では実行器へ通知しない | 純粋、実際の出口で uses を持つ | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 反例の縮小や message の定数化でも合否・回数・形を公開へ落とせないためである。 |

## 実行前の検査と診断

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| D01 読み込むソース・設定と読めたか | ML `load`、CL `prepare_script`、TM | 入口 | スクリプト・import・package・doc の内容、表示パス、読めたか・ハッシュ等の照合→診断の材料。実行時の Secret 取得とは別の入口 | ホストの読み込み | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | ソースと設定自体が秘密を含みうるため、実行前という理由では公開にできないためである。 |
| D02 ソース行の抜粋 | DR `append_primary_excerpt / append_secondary_excerpt` | 出口 | primary/secondary の行全体→stderr の文章。span 外の同じ行にある秘密のリテラルやコメントも表示しうる | ホスト。プログラムを実行しない | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | ソースの内容を直接表示し、型エラーの式だけに出力を限定していないためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |
| D03 診断の本文・ラベル・注記 | LX の数値/escape、ML `io_error`、TC `diagnostic`、DR | 出口 | 不正な字面・escape、名前・型・パス・OS の理由、推定した数値区間→stderr の主文/label/notes。JSON にも同じ材料 | ホストの字句解析・解決・型検査等 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 実行時の値を評価しなくても、ソースの実値の断片や解析した値域を含むためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |
| D04 修正案を当てた後の行 | DR と DE `prepare_edits` | 出口 | 元ソースと replacement→stderr に修正後のソース行と印を表示する | ホストの診断 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 修正した断片以外の元ソースも再表示するため、編集を案内するだけでは公開とならないためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |
| D05 JSON の位置・置換と文言 | DR `render_json_line / append_json_span / append_json_edit` | 出口 | file/start/end/offset/label、helps.edits.replacement、notes→stderr の JSON Lines。ソース行専用の欄はない | ホストの診断 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 文章の抜粋がなくても置換文字列や文言へソースの内容が入るためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |
| D06 警告・件数・打ち切りと検査の成否 | DR `render_check_text`、CL `report_check` | 出口 | 誤り/警告の有無・数・順序と50件を超えた省略数→stderr。JSON Linesは全件。警告のみは通常0、deny-warningsなら2・非実行 | ホストの検査 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 件数と診断した場所もソース・解析へ依存し、値を出さない集計も観測できるためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |
| D07 処理系の制限の診断 | CL `CompileError::Limit`、pipeline の制限の診断、DR | 出口 | L の種類・位置・上限とコンパイル不能→stderr/JSON、終了2。実行時の資源不足 R09 と区別する | ホストの検査/コンパイル | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 入力ソースの形と規模が実行前の停止・報告を決めるためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |
| D08 エフェクト上限の不足 | CL `report_check`、02-10 の E0512、TM の準備 | 出口 | 関数名と位置、missing/allowed の集合と help→stderr/JSON、終了2・実行なし | ホスト、`--allow-effects` | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 実行を拒否する条件と関数の契約がソース由来の情報であり、権限の照合を値の情報フロー制御と混同できないためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |
| D09 単一の非実行 JSON 報告 | CR `value / run_check`、TM `check_report`。IF20.04 C09〜C14 | 出口 | diagnostics、status/complete/targetsComplete/executed、source のパス/hash/集合、宣言契約・解析件数→単一 JSON の stdout | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 診断の stderr と別の受け手に同じ材料とソースの識別情報を出すためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |
| D10 CLI の使い方・開発用設定の誤り | CL `usage_error / bad_environment`、CR `usage_error`、tools | 両方 | argv・環境の名前/不正値・パス→文章の stderr と終了2。report 認識時は単一 JSON の message に収める場合がある | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 言語へ値として渡す前の引数・環境の字面も報告へ混ざるためである。 |
| D11 非 UTF-8 のスクリプト引数の報告 | R `check_args` → CL `write_report` | 出口 | IF20.03/E02 の argv の UTF-8 検査結果→R0301、1始まりの位置、終了1・main 非実行。生の不正引数値は渡さない | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 入口の分類は IF20.03/E02 に保ち、同 E03 と同じ報告の出口として位置・開始の有無・終了状態と受け手を照合する必要があるためである。 |
| D12 入口に残った Fail・利用者エフェクト | TE `check_entries` の E0506、DR | 出口 | main/テスト関数の名前、残った effect、uses の位置と処理の案内→stderr/JSON、終了2・非実行。失敗の実値を実行して得る処理はない | ホストの検査 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 未処理の Fail は実行前の診断へ出るため、Result の文字列の報告と区別しソース由来の分類を保つ必要があるためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |

## 処理系の不具合・報告の失敗・ホストの終了

| ID・操作 | 宣言・実装の位置 | 方向 | 流れる値・成否と暗黙の流れ | エフェクト | 範囲付き IO との関係 | 0.0.14 の扱いの候補 | 根拠 |
|---|---|---|---|---|---|---|---|
| H01 起動・実行準備のホストの失敗 | CL `main / run_script`、R `run_entry` | 両方 | cwd/canonicalize/シグナル登録/OS乱数/イベントループ/出力スレッド等の成否と理由→internal 報告、終了3・開始しない | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 通常の言語の Result と別に OS・配置・環境に由来する文言と成否が外へ出るためである。 |
| H02 `Stop::Internal` と段の InternalError | R0、R `internal_end`、RR `internal_diagnostic`、CL `write_internal` | 出口 | 任意の説明文字列・版・段・報告を求める文→stderr/JSON、終了3。panic なしならスレッド注記・backtrace は付けない | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 処理系の不具合の文字列が実値やパスを含まないという契約が現行にはないためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |
| H03 捕捉した panic の内容 | RP `record / catch`、RR `internal_diagnostic` | 出口 | 文字列 payload（非文字列なら固定表示）、Rust ソース位置、スレッド区分、版・段→stderr/JSON。hook 自体は書かない | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | payload の全文を失敗の注記へ保持し、実装の不具合でも秘密が混ざらないと仮定できないためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |
| H04 バックトレースの設定と内容 | RP `Backtrace::capture`、RR/DR | 両方 | RUST_BACKTRACE に従う採取→backtrace の有無・文字列→stderr/JSON。Rust のフレームやソースの場所を含みうる | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 報告の有無を変える外部設定と捕捉した文字列にも分類と受け手の条件が必要だからである。 |
| H05 作業用・出力用スレッドの panic と報告順 | R `record_internal_panic / run_entry`、RR | 出口 | worker/writer/VM の不具合の区分・記録→転送後の報告、終了3。同じ記録の重複をまとめ、別の不具合は残す | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | どの処理まで進んだかと複数報告の有無・順序が実行に依存するためである。 材料の入力の結びを保ち、受け手の照合は IF30 へ送る。 |
| H06 標準報告自体の書き込み失敗 | R `OutputTarget.write_bytes`、CL `write_report_to / write_run_reports`、TM `write_result / write_summary` | 入口 | write_all/flush/capture の失敗→呼出側へ IO error。通常の診断・main_error・通常test報告では `_result` を捨てる。必ず状態1へ変えるとはいえない | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 読み手が受け取った報告の欠落も観測であり、R のバッファ転送失敗と同じ制御とみなせないためである。 |
| H07 単一報告・版の問い合わせの出力失敗 | CR `write_message`、CL `write_plain` | 両方 | stdout の書き込み/flush の成否→単一報告が完成したか、終了1が本来の status の値より優先 | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | 内容だけでなく報告の完成・外部の受理と終了の対応を契約に含める必要があるためである。 |
| H08 一度目の中断の要求 | RI `register`、R `run_entry / step_end`、TM | 両方 | SIGINT/SIGTERM→取消し・解放・転送後に130。値で終わった後の印でも130、main_error を出さずテスト結果を数えない場合がある | ホスト | 七操作に対応なし。範囲の型だけでは報告を制御しない | 保守的（秘密の結びとする） | 外部の要求が報告・結果数・終端を変え、実行との競合も未確認だからである。 |
| H09 二度目の中断と捕捉外の終了 | RI `register_conditional_default`、06-01「終了状態」、RP | 両方 | 二度目のシグナル・abort・実際のメモリ不足等→OS の終了、部分出力・独立の stderr。内部の kind/status と同じ形式とは限らない | ホスト/OS | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未確認 | 既定動作を登録する境界は読めたが、OS ごとの全文・終了値・切断の実挙動は実行していないためである。 |
| H10 統計の明示的な出力 | CL `dev_alloc_stats`、cli/wasm.rs `WasmOptions::report`。IF20.04 C26/C27 | 出口 | 確保数・bytes・collections、外部の呼出数/転送量/上限/fallback→stderr。失敗・exit 後にも出る場合がある | ホストの任意の報告 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | 明示的な派生数値の出力を物理資源量の保証外へ一括して除外できず、最初の分類契約が未接続だからである。 |
| H11 HTTP accept の自動警告 | HS `accept`、HI `Listener::retry`、IO `write_output_if_room` | 両方 | OS の資源不足の reason→一連の最初の警告と LF を stderr へ。余地がなければ捨てる。出力自体の失敗は停止にもなる | `Http.Listen` 内、`Console.Write` 不要 | 七操作に対応なし。範囲の型だけでは報告を制御しない | 未対応で拒否 | サーバ資源・再試行・出力余地に依存する出口であり、言語の明示表示だけを照合しても閉じないためである。 |
| H12 CLI と埋め込みでの終了結果の受け渡し | R `RunEnd / TestEnd`、CL `main`、main.rs | 出口 | exit_code/end/main_error/die_failure/reports→CLI の ExitCode、または呼出側へ返る構造体。埋め込みはそのままプロセスを終えない | ホストの API | 七操作に対応なし。範囲の型だけでは報告を制御しない | 契約を設ける | ホストへ返した値の後の表示・保存・再送を、CLI の契約だけで保証できないためである。 |

## SD の小モデルとの対応と保証の境界

[SD §3](../spikes/SD/findings.md#3-失敗と非再開の条件)は `done / failed / aborted` と送信列を持ち、`observeResult` は終了状態を隠さない。`fail` と非再開を `pc ⊑ ⊥`、失敗しうる宛先検査を `pc ⊔ label(raw) ⊑ ⊥` に限った。秘密に依存する停止が、定数の報告や後続の送信の有無を変えるためである。C07/C11、S33、T10/T11 はこの失敗・終端の観測へ対応させる対象である。終了コードだけをそろえても、SD の `abortLeak` のように handle 内の送信が消え、handle 外では正常に続く違いが残る。

ただし SD は一般の IO の成否を持たず、操作の引数・節の捕捉・再開する継続・with の解放も省いた。現行の die の説明と Show、Result/Fail の伝播、算術エラー、出力・解放の失敗、テスト・診断・panic の報告を SD で証明済みとしない。C08、S10〜S12・S14〜S17・S22〜S28・S31/S32/S34 が含む一般の非再開・Task・資源の接続は別の仕事である。公開 pc に制限する十分条件か、失敗と正常の継続に依存を保つ精密な条件かは未採択である。機密性と完全性の積で SD の最小元をそのまま要求すると、公開だが未信頼の入力まで拒否しうる点も残る。

停止しないこと・物理時間・OS の資源枯渇に関する保証の境界と、明示的に出す失敗・上限・件数・終了状態の分類を分ける。前者を保証しないことを、S18/S19/S20 や H10 の数値・報告の無条件な公開の根拠にしない。H09 の捕捉外の異常終了は未確認へ分ける。現行の処理系が宣言する型・エフェクトの保証を本書で変えない。

## 未確認の表

候補の未採択と、事実・規則の接続・再現の不足を分ける。次の事項を再現済みの不具合とは扱わない。

| ID | 未確認の点 | 確認できた境界と必要な確認 | 後続 |
|---|---|---|---|
| U-FE01 | 出口の受け手とソース・設定の分類 | stdout/stderr・テスト捕捉・単一JSON・埋め込みの送り先を確認した。各受け手・ハーネス・コード/設定の入力所有者と分類は未設計である。端末の逃がしと4096バイトの省略を非機密化とはしない。 | IF10/IF30、IFC-D3・D4・D6・D8 |
| U-FE02 | 一般の失敗・停止・非再開の pc の接続 | 通常の停止と報告の組立は確認した。SD は公開 pc に限った最小モデルであり、一般の Fail/try/return/ハンドラ/Show の異常と正常の依存を追う本番の判定・証明はない。 | IF20.06、0.0.14 の設計と形式化 |
| U-FE03 | OS・依存・panic payload の全内容 | kind/reason/trap/message/backtrace を保存して出す境界を確認した。全API・全失敗条件でパス・URL・入力・環境の断片が混ざるかは網羅も実行もしていない。IF20.07 でも保存・転送の境界を再読した。確認箇所と全文を未確認に残す範囲は [ソース読解の補足](../if20.07/source-findings.md)に記す。 | 前枝 U-F02・U-H04・U-CP04・U-D02 の残り。実装時の再現 |
| U-FE04 | Task・資源・解放と実 IO の成否 | 位置・起動履歴・待つ一覧、停止時の補足と出力転送を確認した。開始済みの外部作用、取消し・時間切れ・資源状態・失敗の保存を二つの実行（公開の入力をそろえ、秘密などの違いによる観測の差を調べる比較対象）で対応付ける契約は未接続である。 | IF20.06、接続を閉じる改造 |
| U-FE05 | 報告の出力失敗・中断・panic の実挙動 | 通常診断/test の _result の破棄と、単一報告の終了1を区別した。パイプ切断・短い書き込み・最終flush・中断との競合・複数panic・0件の集計の実 CLI を再現していない。ソース上の差を不具合と断定しない。 | 0.0.14 の実装・レビュー担当、必要な構成の再現 |
| U-FE06 | 捕捉外の abort・OS・埋め込みの独立出力 | 既定シグナルの登録と捕捉範囲、06-01 の保証範囲を読んだ。OOM・abort の全文/終了状態、別のホストが使うpanic hook・ログ・再送の全経路は未確認である。 | H09、IF20.06、実行側の保証の境界 |
| U-FE07 | doc の die の情報と位置の対応 | TD の map_result は Exit.reports を写すが die_failure を明示的には写さず、run の不一致にも直接入れない。通常テストと異なる欄は表へ記した。元コメントへの位置対応と出力内容の実際は未確認であり、修正は実装時の再現後とする。 | IF20.06 に申し送り、必要なら取りまとめが後続へ割り当てる |
| U-FE08 | 特殊構成・OS差と統計の分類 | 全 Stop 構成子と報告の分岐をソースで照合しただけである。32ビット・機能を外した構成・各OS・WASM統計の実出力と、将来の範囲付きIOの取り込み後の失敗契約は確認していない。 | 判断21、R30/V10、0.0.14 の担当 |

## 件数と IF20.06 への申し送り

| 母集団 | 件数・方向・扱いの候補 |
|---|---|
| A | 8件。方向: 出口 4、内部の派生 4。候補: 契約を設ける 8 |
| 補助経路 | 87件。方向: 内部の派生 7、出口 66、入口 6、両方 8。候補: 契約を設ける 41、未対応で拒否 20、保守的（秘密の結びとする） 25、未確認 1 |
| 未確認事項 | U-FE01〜08 の8件。H09 の扱いの候補「未確認」とは別の集計である |

A の8件と補助経路は合算して操作件数とは呼ばない。A は Assert の4件と通常の関数4件であり、Assert の組み込み登録4件を加算しない。各補助表は同じ停止の値・位置・終端や表示形式を分けた件数である。R0 の RuntimeError 13種・ResourceError 11種と Stop::Internal は S/H 表で照合した。Result.Error は通常の値であり、型検査を通る入口から任意の IOError を未処理の例外として外へ投げる経路はない。main と通常テストが外へ返せる失敗は Result[Unit,String] であり、ほかの Error は表示・変換・die 等を経る。

IF20.06 は、(1) 正常／異常の継続、任意のハンドラの非再開・再送、(2) Task・Lazy・Reference の状態と待ち、(3) Writer/Exchange と停止・解放・開始済みの IO、(4) 外部コマンド/WASM/埋め込み・ハーネスの独立出力、(5) doc の die の情報・元コメント位置の未確認、を引き継ぐ。汎用 Process は子の非ゼロ終了を Error にせず、Task の時間切れの None と HTTP の TimedOut も区別する。

三つの典型例では、公開 CSV の集計にも失敗の文言・入力の上限・終了状態、認証付き取得の件数表示にも承認した値とは別の認証の成否と通信の誤り、機密ファイルの固定 API 送信にも送れたか・die の原因・ログ・テスト報告を照合する。許した送信先へ本文を送れることから、stderr や報告の受け手への開示を導かない。一般のファイルや HTTP の失敗を、典型例のために公開へ落とさない。
