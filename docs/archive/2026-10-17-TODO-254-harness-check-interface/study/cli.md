# 現在の CLI と出力の契約

## 調査の根拠

現行の [06-01「CLI」](../../../design/06-tooling/06-01-cli.md)、[06-04「利用者プログラムのテスト」](../../../design/06-tooling/06-04-test-runner.md)、[02-10「診断エンジン」](../../../design/02-impl/02-10-diagnostics.md) と、`crates/benitoite/src/cli/` を照合した。以下のソースのパスはリポジトリの根から記す。

## 命令と担当箇所

| 命令 | 現在の振る舞いと実装 |
|---|---|
| check | `cli/mod.rs::parse_args`・`execute_script`。`pipeline::check` に `require_main: true` を渡し、型検査まで行う。脱糖・コード生成・実行はしない。main がなければ E0414 |
| run とサブコマンド省略 | 同じ `execute_script`。検査に成功した CheckedProgram を同じ段の中で脱糖・コンパイルし、その成果物を実行する。ソースをもう一度読んでコンパイルする構成ではない |
| test | `cli/tools.rs` から `tools/args.rs::parse_test_args`、`tools/test_runner/mod.rs::run_test_with_externals`。入口は main を要求せず検査する。現在は一つのファイルを検査・コンパイル・実行してから次へ進む |
| --version | `cli/mod.rs` の `Command::Version` と `text::VERSION`。`benitoite 0.0.6`、`Unicode …` の二行を標準出力に書く。版は `env!("CARGO_PKG_VERSION")`。コミットと形式の情報はない |
| package add/update | `cli/tools/package/`。公開宣言の契約のエフェクトを `effects.rs::Summary` が AST から集計し、変更の結果とともに文章で標準出力へ書く。update は保存済みの集合との増減も示す |
| skill install/uninstall | `cli/tools/skill/mod.rs`。埋め込みの一覧から配置・削除し、結果を標準出力へ書く。既存の Skill が自身の書いたものかを metadata で確かめる。取得だけの命令はない |

run/check の処理系のオプションはスクリプトのパスより前に置く。run のパスより後はすべてスクリプトの引数となる。新しいサブコマンドを増やすと、サブコマンド省略時に同名のファイルを起動する意味も変わるため、既存命令のオプションと skill の動詞を増やす案を推す。

## 標準出力と標準エラー出力

run/check の標準出力は、help/version/licenses の表示を除けばスクリプトが書いたものだけである。check は通常、標準出力に何も書かない。診断・実行時の報告・使い方の誤りは標準エラー出力に置く。main の Result.Error の文字列も標準エラー出力であり、`--diagnostics=json` を指定しても文章のままである。

test の結果と最後の集計は標準出力、検査の診断と処理系の不具合は標準エラー出力である。テストが書く出力は捕らえ、失敗したテストの報告に入れる。fmt は標準出力に書かない。package と skill はそれぞれの結果を標準出力に書く。

新しい報告は明示した `--report=json` だけで標準出力へ出す案とする。通常の check の契約を保ち、例外を 06-01 に明記する必要がある。run の標準出力へ機械向けの許可判定の結果を加える案は採らない。

## 診断の JSON とテストの JSON Lines

`diag/render.rs::render_json_line` が一件を一行の JSON にする。基本の欄は `kind`・`severity`・`code`・`message`・`primary`・`secondary`・`notes`・`helps` であり、必要に応じて `trace`・`traceOmitted`・`taskOrigins`・`waitingTasks`・`backtrace` を加える。primary などはファイルの表示名と位置を含む。code は処理系の不具合や die では null となりうる。診断の共通形式の版を示す欄はない。

使い方の誤りと確保失敗の abort は JSON の診断にはならない。新しい report のモードで使い方の誤りも結果に収めるには、そのモードを認識した後のエラー処理を別に接続する必要がある。引数を認識する前の失敗や OS による強制終了まで JSON の完成を保証することはできない。

`cli/tools/test_runner/report.rs` は `kind: "test"` の行と、最後の `kind: "testSummary"` の行を作る。前者は file/name/function/location/outcome/failure/stdout/stderr、後者は passed/failed/filesNotRun/interrupted を持つ。failure.reason は assert/error/runtime/exit である。exit は exitCode と notes を持ち、0.0.6 では明示的な失敗終了にだけ `die` の診断オブジェクトを加える。新しい非実行の報告にはこの二つの kind を使わない。

## 終了状態

| 値 | run/check | test | skill |
|---|---|---|---|
| 0 | 検査または実行の成功 | 検査の誤りも失敗したテストもない | 成功 |
| 1 | スクリプトの失敗・実行時エラー・資源不足など | 失敗したテストがある | 書き込み・削除の失敗や置き換えの拒否 |
| 2 | 検査の誤り、入力の読み取り失敗、使い方の誤り、deny-warnings による拒否、処理系の制限 | 同左。検査で実行しないファイルがあればテストの失敗より優先 | 使い方の誤り |
| 3 | 処理系の不具合 | 同左 | 同左 |
| 130 | run が中断の要求を受けて終了 | 中断。他の値より優先 | 独自の中断処理はない |

run の Process.exit は 0〜255 の指定値で終了し、上表と重なりうる。`or die` の失敗は状態 1 と kind: die の報告となる。check はシグナルを特別に処理しない。確保失敗の abort と OS の強制終了は表の保証の外である。package は成功 0、検査・読み書き・使い方の誤り 2、不具合 3 であり、失敗を 1 に割り当てない。

## テストの対象を選ぶ共通の処理

`cli/tools/test_runner/mod.rs::test_entries` が入口と根を作る。ディレクトリでは `test_files` から `cli/tools/args.rs::collect_bnt_files(root, true)` を呼び、.bnt を辞書順に並べる。package.bnt 自体と、直下に package.bnt を持つ下位ディレクトリ全体を除く。走査中のシンボリックリンクは辿らず、設定ファイルの存在判定にはリンクの項目も使う。指定したディレクトリ自身は除外しない。

直接指定したファイルは `pipeline::entry_spec` で扱い、根はその親となる。ディレクトリ経由の同じファイルとは根が異なることがある。明示パスの順を保ち、現在の `test_entries` は重複する指定を除かない。新しい検査だけで重複を取り除くと実行とずれる。報告には入口ごとの通し番号と根を持たせ、同じパスでも別の対象として表せる案とする。

`collect_tests(checked, entry)` は入口の AST のトップレベルの @test だけを宣言順に選び、取り込んだモジュールのテストは選ばない。BindingId と decl_types から戻り値の形を決めるが、TestFn にエフェクトの欄はない。新しい検査は、この選択結果に型表の Scheme.effects を対応させればよい。`prepare` は現在コンパイルまで行うため、非実行の検査には検査と情報抽出だけの部分を共通化する。

通常の test は検査の誤りがあるファイルを飛ばして残りを実行する。機能 3 を指定した場合は、全対象を検査・コンパイルしてから一つ目を開始する形が必要になる。検査済みまたはコンパイル済みの成果物を保持して実行し、許可判定の後でソースを読み直さない。保持量の増加は実装時に確認する課題である。
