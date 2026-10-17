# TODO-254 の実装プラン

## 実装の条件と共通の関門 K

本書は [design.md](design.md) と、回答を追記した [decisions.md](decisions.md) を前提にした実装プランである。以前の段と作業量の見込みを置き換える。今回は文書の作成までであり、以下の実装・取り込み・公開を行わない。

後の実装は Codex がメインの作業ディレクトリで一つずつ行う。各作業はそれぞれ完了した状態で san_benito に取り込める単位とし、作業の後にクレートのコンパイルと関係する検査が通る。別の作業の仮置きに依存して取り込まない。ID の Z は後のレビューで見つかった問題の修正用に空ける。本書はサブエージェントの起動を指示しない。

共通の関門 K は全作業に適用する。各作業の「K」は次の全項目を指す。

1. **テストを弱めない。** 既存の assert を消さず、期待値を緩めず、ignore にしない。意図して契約が変わる期待値は変更前後・理由を記録し、同じ厳密さで比較する。負の入力を別の理由で拒否する入力へ変えない。テストの削除が必要に見えたら本作業と分けて報告する。
2. **test-audit の作成時の関門を通す。** 守る観測可能な契約、現実的な退行、既存テストで捕まらない理由、テスト専用の本番 API が不要であることを作業記録に短く示す。同じ契約を複数の層で重ねず、既存の表へ対照例を加える。低価値の文字列検索だけをテストにしない。
3. **規約と受け渡しを保つ。** 文言は diag::codes、cli::text、または規約が許す当該モジュールの text にまとめる。大域の可変状態、テスト専用の本番フラグ、不要な公開 API、unsafe、unwrap/expect、実行時の添字を加えない。AST の走査と破棄は段のスタックで行う。所有データだけを持ち出し、検査・コンパイルの再実行やソースの再読によって報告と成果物をずらさない。
4. **実装と文書を同じ状態にする。** 該当する docs/design の章は機能を実装した作業で直す。未実装・未接続の内容を先に書かない。診断表・標準ソースの説明・生成元を変えたら同じ作業で `cargo run -p benitoite --example gen_skill` を実行し、生成物を手で直さない。harness-response.md の公開契約を変えたら同時に更新し、判断を R に残す。
5. **各作業の検査。** Rust・ビルドスクリプト・埋め込み内容を変える作業は、個別に挙げる関連テストに加え、`cargo test -p benitoite --lib`、`cargo clippy --workspace --all-targets`、`cargo fmt --all --check` を通す。これを K-R と呼ぶ。文書だけの P1/P2/M2a/M3a/F2 は Rust の検査を重ねず、リンク・JSON・表・差分を確かめる。文書のコード例を変える D/M は指定した文書テストも行う。
6. **選ばれた検査を省かない。** 実施前に検査名を知らせ、`scripts/check.sh --dry-run` の選択・理由を確かめてから、選ばれた検査を行う。長いテスト、heap、full の場合は見込み時間も先に知らせる。段末の明示 `--only` は追加の段全体の確認であり、各作業の選択の検査の代わりではない。同じツリーで既に通った検査は結果を引用できるが、古いコミットの結果を修正後の結果にしない。
7. **未達を隠さない。** `== stop:` で分類外になった場合は、該当ファイルを示し、AGENTS.md の指定どおり full/only/none を設計者に尋ねる。既知の基準の失敗と今回生じた失敗は、変更前後で再現して区別する。未実施の検査は担当と実施条件を明記し、段を完了扱いにしない。
8. **取り込みに渡す記録。** `<小文字ID>/results.md` に目的、変更ファイル、型・契約の変更、検査のコマンドと構成・結果、残件を記す。処理本体のコードは作業 ID を根拠のコメントにせず、現行設計の章を引く。docs/todo の更新や保管・コミットは別の指示に従う。今回の文書作成中は一切行わない。

実装本体は、下記の「分割の限界」「分割できない理由」がある作業を除き各 30〜60 分を目安とし、K と段末の検査待ちは別に見積もる。作業の途中で60分を超える見込みが分かったら、現在の動く状態で止め、同じ接頭辞の枝番で本番に接続した単位へ分けて記録する。無意味な仮置きやテスト専用の受け入れ口で分割しない。R7 に従い、以下の枝番を最初から実施単位とする。各枝番の後も dead_code なしでコンパイルできなければならず、欄・型・variant は読む本番処理と同時に加える。V1 に実行時の build_info、C1 に未使用の binding/tests、T1 に未接続の report、A1 に PathArgs.allow_effects を先置きしない。

## 作業とレビューのまとまり

| レビュー | 作業 | 焦点 |
|---|---|---|
| G1 | P1・P2・V1a・V1b・V2（5） | 基準、型・CLI の変更範囲、Git/アーカイブ/worktree、再採取、未提供の formats を出さないこと |
| G2 | C1a・C1b・C2a・C2b・C3（5） | main の報告、失敗と null、生バイトのハッシュ、shell の式の参照、既存の出力 |
| G3 | T1a・T1b・T1c・T2a・T2b・T3（6） | test の同じ対象選択、非実行、部分結果、Assert.Check、空と重複 |
| G4 | A1・A2a・A2b・A3・A4（5） | 正規名の包含、E0512、run の同じ成果物、test 全体の拒否と保持、集計の非実行 |
| G5 | E1・S1・S2（3） | InvalidInput と非起動、継承の区別、Skill の置換・論理名・JSON |
| G6 | D1・D2a・D2b・D3（4） | 各章・英語文書・Skill・生成物と外部へ渡す契約の一致、過大な保証がないこと |
| G7 | M1・M2a・M2b・M3a・M3b・F1・F2（7） | E0908、版の負の検査の保持、固定ハッシュ、訳、全ターゲット、完了記録 |

実施 ID は合計35件である。旧 C1/C2/T1/T2/A2/D2/M2/M3/V1 の結果ディレクトリは作らず、枝番ごとの小文字 ID を使う。G1〜G7 はレビューの依頼単位の提案であり、今回実施したレビューではない。各段は担当作業と段末検査の記録を揃えてから閉じる。指摘が実装を変えた場合は Z の修正作業を作り、影響する検査を再実施する。G7 のレビュー後の修正があれば、F2 の最終状態の記録も直す。

| 段の終わり | `scripts/check.sh --only` の名前 | 目的と追加の確認 |
|---|---|---|
| V2 | `rust,default_lib,skill` | ビルドスクリプトと二構成の既存 CLI。通常の rust では build_info は ignore。段末に `cargo test -p benitoite --test build_info -- --include-ignored` を別に実施する |
| C3 | `rust,default_lib,skill` | main 報告と既存の run/check。両構成の all-targets を一度実行 |
| T3 | `rust,default_lib,skill` | 非実行と通常 test、共有した探索の fmt への影響 |
| A4 | `rust,default_lib,skill` | 全体拒否・die・割り込み・終了状態。両構成の all-targets |
| S2 | `rust,default_lib,reference_examples,skill` | 環境入力・Skill。拒否に long/heap は不要 |
| D3 | `rust,default_lib,spec_examples,reference_examples,skill,spec_coverage` | 各章の例と生成元の対応。生成を二回して差が増えないこと |
| M3b/F1 | `rust,default_lib,spec_examples,reference_examples,skill,spec_coverage,skill_eval,python,licenses` | 最終版と訳・全統合入力・道具の自己検査。両構成の all-targets |

段末表の --only 自体は long/release_stack/heap/formal を加えない通常の検査である。ただし V1b と V2 の段末には build_info の長いテストだけを名指しし、事前に所要時間を見積もって知らせる。全 long を各段末に加える意味ではない。rust 自体は gc-stress と統合テストを含み、数分で終わるという意味ではない。前回の段末は約34〜35分だったため、開始時点の環境で見積もり直す。文書の個別テストだけを通して rust が通ったとは扱わない。

「両構成の all-targets」は `cargo test --workspace --all-targets` と `cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify --all-targets` である。既存の ignore を含めない。前回の runtime_builtins.rs の入力移行漏れを踏まえ、通常の個別テストだけで段全体を閉じない。release の長いスタック試験、全 long、heap は通常段末に加えない。build_info の名指しの実施は上表の例外である。公開前には設計者へ所要時間を知らせて `--full --dry-run`、`--full` を行う。今回の範囲では check-formal と lake build は必須でない。

## 準備

### P1 基準と入力・出力の一覧

- 目的: 実装開始時の差分を識別し、後で更新対象を探し直して漏らさない。
- 触るファイル: 改造ディレクトリ内の p1/results.md と入力・契約の確認表だけ。
- 手順: HEAD、ブランチ、dirty と study の根拠を照合する。README/request/answers と Q/R を読む。現行の CLI、通常の stdout/stderr、終了状態、die の code:null と test.failure.die、testSummary、Skill の置換を一覧にする。全追跡ファイルの版・language・sha256・環境設定を rg で調べ、通常入力、旧/未来/不正版の検査、構文だけの例、生成元、生成物、歴史資料、今回の契約例へ分類する。tests/runtime_builtins.rs、package_command.rs、testdata、tools の参照解、Markdown の benitoite test fence、docs/ja も対象にする。archives/reference は変更候補にしない。
- 完了の条件・検査: K。書き換える候補と意図して残す候補の双方に理由がある。前回の plan/results/reviews の漏れが本書の作業へ対応する。文書の差分・リンクを確認し、選択の検査は dry-run で文書のみと確認する。Rust の検査は不要。
- 依存: 後の実装開始の指示。

### P2 インターフェースと受け入れ条件の照合

- 目的: 型変更・失敗の処理・所有関係を実装前に確定する。
- 触るファイル: p2/results.md、型の使用箇所と受け入れ条件の確認表。必要な訂正は design/decisions/plan/harness-response。
- 手順: Options/PathArgs/Command/Prepared/TestFn/Summary の構築と全 match を rg で列挙する。execute_script、prepare、run_body、invoke の panic 境界と報告の認識後の失敗を図示する。E0512 の割り当て、13 原子的エフェクト、source の全バイト、IO.Process の未読と束縛欠落の区別、refs の全件比較を現 HEAD で再確認する。build.rs が crates/* から rust に分類されることと、現在の check 名を読む。通常 test の流れと上限付きの全保持・破棄を照合する。07-04 を変更しない R4 を再判定する。
- 完了の条件・検査: K。変更する型と全呼び出し元の対応、Q/R と受け入れ条件の対応に空欄がない。予期しない公開シグネチャの変更が必要なら先に判断を記録する。文書の確認のみで Rust の検査は不要。
- 依存: P1。

## 段 1: 版の情報と共通の部分

### V1a build.rs の明示入力と commit の採取・監視

- 目的: クレートの毎回の作り直しを起こさず、不明を推測で埋めない情報をビルド時に渡す。
- 触るファイル: 新規 crates/benitoite/build.rs、tests/build_info.rs、v1a/results.md。実行時モジュールとその宣言は作らず、05-01 の実行時の説明も V2 に渡す。
- 手順: design の明示入力・Git の根の検証・TARGET・埋め込み変数を実装する。dirty は未指定なら null 相当の unknown と provenance=notCollected を出し、status を採らない。文言は build.rs 内の text 子モジュールへまとめる。build.rs、二つの BENITOITE_BUILD_*、存在する HEAD/ref/packed-refs だけを監視する。管理場所は --git-dir/--git-common-dir、ref は --git-path で求める。欠けたパスや index・作業ツリーは監視しない。明示値の正常・不正と通常の Git 採取を一つの独立した表に接続する。
- 検査の環境: 本番 build.rs をコピーした小さい一時クレートを使い、本体を入れ子にビルドしない。実ビルドをするテストには `#[ignore = "long: ..."]` を付ける。子の Cargo へ一時ディレクトリ内の絶対 --target-dir を渡し、親の CARGO_TARGET_DIR・BENITOITE_BUILD_* を除いてケースごとの入力だけ設定する。Git の準備と子のビルドに GIT_CONFIG_GLOBAL=/dev/null・GIT_CONFIG_NOSYSTEM=1 を渡し、repo の local 設定も管理する。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test build_info -- --include-ignored`（長いテスト、時間は実施前に見積もって知らせる）。dirty=false は明示値からだけ出る。変更なしで同じ `cargo test -p benitoite --lib` を二回実行し、二回目で lib を作り直さず `Compiling benitoite` が出ないことを、生の Cargo 出力で確かめる。build.rs の clippy 対象化と check.sh の rust 分類を記録する。V1a 後に未使用の実行時定数を置かない。
- 依存: P2。

### V1b 独立した Git 状態・監視条件の受け入れ表

- 目的: worktree、アーカイブ、Git 採取失敗と監視の限界を実ビルドで確認する。
- 触るファイル: tests/build_info.rs、必要な build.rs の訂正、v1b/results.md。
- 手順: V1a の同じ長いテストの表へ detached・worktree・packed refs・Git 採取失敗・親が別 repo のアーカイブ・明示値の混在を加える。Git 不在の代用は一時 PATH の先頭に起動失敗を返す git を置き、後続 PATH と cc・リンカ・SDK の道具を保つ。Cargo/Rustc は固定ツールチェーンの実体の絶対パスを使い、親の PATH は変えない。子の環境・target の分離は V1a と同じにする。
- 監視の対照: 同じ構成で HEAD の切替、既存の参照中 ref の更新、packed-refs の更新、二つの明示値の変更による再採取を確認する。ステージ・通常ファイル・未追跡・無視されたファイルの編集は build.rs の再採取を起こさず、dirty は null のままである。Rust ソース自身の変更による通常の再コンパイルとは区別する。存在しない ref/packed-refs を登録しないこと、packed-only から loose ref が新設され登録済みのファイルが変わらない場合には明示入力の変更か clean build が必要なことも観測する。実リポジトリの checkout と環境は変えない。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test build_info -- --include-ignored`（長いテスト、所要時間を先に知らせる）。Git 採取失敗でもリンクを含めて成功する。アーカイブで親の commit を拾わない。変更なしの二回実行は既存の loose ref がある場合と packed-only の場合の双方で再採取を起こさない。
- 依存: V1a。

### V2 version JSON と提供済み形式の表

- 目的: 既存の版表示を保ち、能力を版の大小から推測しなくて済むようにする。
- 触るファイル: cli/mod.rs、build_info.rs、cli/text または同ファイルの text、tests/cli_process.rs、06-01、05-01、v2/results.md。
- 手順: この作業で初めて cli/build_info.rs と mod 宣言を作り、埋め込みの commit・dirty・target・provenance をすべて JSON の実際の出力へ接続する。VersionJson と `--version=json` の最初の引数だけの受理を実装する。BuildInfo の JSON 値を返す関数を実際の version JSON へ接続する。producer の関数は C1b で使う時に加える。最初の formats は version/diagnostics/testResults のみとし、0.0.6 の die を含む形式1を明記する。未知の値、余分な引数、通常の二行、出力先失敗を既存の CLI テストへまとめる。旧い --version の引数の扱いをこの機会に変更しない。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test cli_process --test test_command`。新モードだけ単一 JSON、既存の診断・test の行へ版の欄や開始行が増えない。V2 の段末検査と build_info の長いテストの明示実施、G1 の資料を揃える。dirty の notCollected と R2 の再採取条件・検知の限界を05-01へ反映する。
- 依存: V1b。

## 段 2a: main の検査報告

### C1a run/check の段の準備処理の共有

- 目的: 既存の run/check を同じ処理で動かし、報告の情報を抽出できる位置を準備する。
- 触るファイル: cli/mod.rs と必要な非公開の子モジュール、tests/cli_process.rs、02-01、c1a/results.md。
- 手順: execute_script 内の検査・任意のコンパイル・深い AST の破棄と panic 境界を、既存の run/check が呼ぶ非公開の準備関数へ移す。現に返す CheckResult・compilation・verb だけを所有して返す。まだ report/inspection の型・欄・関数は置かない。require_main、prelude_error、deny_warnings、既存の表示と終了状態を保つ。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test cli_process --test interrupt_process`。通常 run/check が新しい共通処理を使い、未使用の補助を作らない。型検査の回数・所有・破棄の位置が変わらない。
- 依存: V2。

### C1b main の完全な初回の報告への接続

- 目的: 一回の検査から、ソースと契約を持つ単一報告を返す。
- 触るファイル: 新規 cli/inspection.rs・check_report.rs、cli/mod.rs、tests/cli_process.rs、06-01/02-01/02-02、c1b/results.md。
- 手順: pub な ReportFormat と Options.report を解析・実行と同時に加える。FunctionContract は name/location/effects、ProgramInspection は main/process_shell_reference だけから始め、binding/tests/inspect_tests は T2b に渡す。Scheme.effects の正規名、IO.Process の未読なら absent・既読の束縛欠落なら内部エラーという区別、refs 全件の値と shell の束縛の照合を実装する。SourceTable の全バイトのハッシュ、既存の診断 renderer と位置を使い、design の共通欄・null を持つ成功/検査失敗の報告へつなぐ。失敗時は main:null で未確定を表し、ShellReference::Unknown は出力で使う T2b まで加えない。C1a の段の中で抽出と AST の破棄を済ませる。通常の check の分岐を保ち、formats は C3 まで宣言しない。
- 分割の限界: 最初に公開する報告は必須欄が揃う必要があるため、契約・ソース・診断の組立と接続を本作業にまとめる。空の成功報告や未使用の API を先に置く分割は採らない。C1a で段の作り直しを分け、広い受け入れ表は C3、解析と panic の補強は C2a/C2b へ分ける。それでも60分を超える場合は、不完全な報告を公開する前にさらに分割案を記録する。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test cli_process`。純粋/複数エフェクトの main、IO.Process 未読と import だけ、E0414・読み取り・構文失敗を観測する。標準 shell の索引を追加 import で作らず、検査しない成功を返さない。非実行と通常 check の標準出力が空である契約を保つ。
- 依存: C1a。

### C2a オプションの範囲と報告する使い方の誤り

- 目的: 引数順で報告モードを変えず、公開 parse_args のシグネチャを保つ。
- 触るファイル: cli/mod.rs の parse_invocation/invoke、check_report.rs、cli::text、tests/cli_process.rs、02-10/06-01、c2a/results.md。
- 手順: CliParseError と共通の内部解析を実際の入口へ接続する。ReportKind はこの時点で読む Check だけを加え、Test は T2b で加える。途中の誤りを記録して check のスクリプトより前のオプションの範囲を最後まで走査し、その後に有効な report の有無でモードを決める。既知の分離値はその場で消費する。明示 diagnostics=text と既定を区別し、重複・未知値・パスなし・ディレクトリに main.bnt なしを接続する。usageError 内だけに kind:check・code:null を認めることを02-10の表と例外の説明へ反映し、R5に従い既存 diagnostics 形式1の JSON Lines は変えない。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test cli_process`。diagnostics=text/report と未知オプション/report の正逆順、report のない誤り、スクリプト引数や分離値の字面の対照を表にする。順序によらず checkReport の usageError・2となり、範囲外の字面でモードを拾わない。
- 依存: C1b。

### C2b 報告の panic 境界と書き込み失敗

- 目的: 内部の失敗を成功や空集合へ変換しない。
- 触るファイル: cli/mod.rs の invoke/execute_script、check_report.rs、cli::text、tests/cli_process.rs、02-10/06-01、c2b/results.md。
- 手順: DEV_PANIC の既存の CLI 入口で、報告を確定した後の捕捉できる不具合と保証外の外側の境界を確認する。報告途中の二重書き込みを避け、出力失敗は1にする。通常の prelude_error と deny_warnings の分類も確認する。test 側の接続は T2b で行い、使わない tools の補助関数を先に置かない。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test cli_process --test interrupt_process`。usageError/checkError/internalError を区別し、不明の null を成功の空集合と混同しない。外側の失敗に完成した報告を約束しない。
- 依存: C2a。

### C3 エフェクト・shell・ソースの受け入れ表と機能宣言

- 目的: 報告の意味と入力の記録が依頼の例を満たすことを確かめる。
- 触るファイル: tests/cli_process.rs の受け入れ表、必要な testdata、inspection/check_report の不足箇所、build_info の formats、06-01/02-02、c3/results.md。
- 手順: IO.All、コメントと文字列の uses、有効な利用者 import の別名、不正な組み込みモジュールの別名、未処理の die、Exit を完全に処理して契約から外す場合と残す場合、裸の try/or return を対照にする。IO.Process 未読・import だけ・shell の直接呼び出し・値の取得・補助モジュール・到達しない関数・同名の利用者定義・ハンドラの操作名だけを確認する。import/package.bnt/BOM/LF/CRLF/不正UTF-8 のハッシュを独立した sha256 と比べ、読み込めないソースを成功項目に作らない。全体成功時だけ aggregateEffects を返す。最後に formats.checkReport=[1] を宣言する。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test cli_process --test package_command --test golden`。不足を各層で重複して試さず、CLI 境界の表にまとめる。C3 の段末・両構成の all-targets と G2 を準備する。
- 依存: C2b。

## 段 2b: テストの非実行の検査

### T1a collect_tests の欠落を Result で伝える

- 目的: 検査成功後の型・束縛の欠落を黙って飛ばさない。
- 触るファイル: test_runner/mod.rs と全呼び出し元、関係する既存テスト、06-04、t1a/results.md。
- 手順: collect_tests を Result<Vec<TestFn>, InternalError> へ変え、compile_tests を含む全呼び出し元を同時に更新する。欠落を内部エラーへ写し、通常のテストの順序・選択は保つ。報告専用の欄はまだ足さない。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test test_command`。既存の呼び出し箇所がすべて失敗を扱い、対象の黙った除外が残らない。
- 依存: C3。

### T1b 通常 test の prepare と run_prepared の分離

- 目的: 再読せず実行できる所有関係を、既存の実行で使う。
- 触るファイル: test_runner/mod.rs、tests/test_command.rs、02-11/06-04、t1b/results.md。
- 手順: run_file を prepare と run_prepared に分け、通常 test が一入口ずつ両者を呼ぶよう接続する。今ある result/compiled だけを保持し、まだ Inspect/inspection/ExecuteLimited を置かない。段内の AST/IR の破棄、検査の失敗ファイルだけを飛ばす動作、集計を保つ。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test test_command --test interrupt_process`。通常の出力・終了状態・逐次実行が一致し、ソースを開き直さない。
- 依存: T1a。

### T1c report なしの test --check

- 目的: 共通の準備を使って、テストを実行せず型検査までで終える。
- 触るファイル: args.rs とその tests、tools.rs、test_runner/mod.rs、tests/test_command.rs、06-01/06-04/02-11、t1c/results.md。
- 手順: 既存 PathArgs.check を test でも受け、PrepareMode::Inspect/Execute を使う分岐とともに加える。Inspect は AssertTable・脱糖・compile_tests・VM・RuntimeParts の生成へ進めない。report と PathArgs.report は T2b、allow_effects は A2b まで加えず、fmt に漏らさない。--max-call-stack と全 --wasm-* の明示を消失させず、--check との併用を拒否する。中断は R8 の既存のファイル開始前の読み口だけで確認し、後や報告直前に読み足さない。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test test_command --test fmt_command`。main なしの正しいテストを検査でき、成功時も標準出力は空、警告は標準エラー出力に出る。利用者コードを実行せず、通常 test と fmt の契約を保つ。
- 依存: T1b。

### T2a 通常 test と非実行で共有する探索結果

- 目的: 対象を選ぶ処理を一つに保ち、探索失敗と完了を区別する。
- 触るファイル: test_runner の探索部分と全呼び出し元、tests/test_command.rs、06-04、t2a/results.md。
- 手順: 内部 select_test_entries と EntrySelection を作り、通常 test・test --check・公開 test_entries が使うよう接続する。この段階では既存の入口一覧と探索の完了・失敗だけを返し、全呼び出し元がそれを読んで既存の失敗へ写す。失敗前の部分結果を捨てるか保持するかは呼び出し元で決める。request_index と SelectedEntry は報告で使う T2b で追加する。直接指定/ディレクトリの根・下位パッケージの除外・順序・重複を保つ。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test test_command --test fmt_command`。通常の対象と出力を変えず、探索を二重に走らせない。公開 test_entries のシグネチャを保つ。
- 依存: T1c。

### T2b testCheckReport と部分結果の接続

- 目的: 実行対象の @test と契約を全体の完全性と分けて報告する。
- 触るファイル: test_runner/mod.rs、args.rs、tools.rs、inspection/check_report、tests/test_command.rs、06-01/06-04/02-11、t2b/results.md。
- 手順: PathArgs.report と内部 parse_test_invocation、testCheckReport の経路を同時に追加する。オプションの範囲を最後まで走査し、--check のない test --report=json も usageError・2に包む。正逆順の diagnostics=text/report と未知オプション/report を同じモードへ写す。tools::run_body の DEV_PANIC=tool も専用の失敗報告へ渡す。失敗した入口の shell の unknown を出す箇所で ShellReference::Unknown を追加する。collect_tests との対応を読む箇所で初めて FunctionContract.binding、ProgramInspection.tests と inspect_tests、Prepared.inspection を加える。T2a に request_index と SelectedEntry/SelectionFailure の対応を加え、description の省略と空、位置、プログラム単位の shell、sources/sourceSets/診断の添字を一つの報告へ接続する。通常の検査失敗後も続け、未確定 tests と全体の和は null、成功したテストなしは [] にする。Assert.Check を集合に残す。
- 分割の限界: 対象・ソース・診断・完全性は一つの報告の必須欄なので、接続は一体とする。探索の作り直しを T2a、既存実行の分離を T1a/T1b/T1c、広い対照の検証を T3 へ分けておく。必須欄を欠く仮の成功は出さない。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test test_command --test cli_process`。成功・部分失敗・探索失敗・既存の確認点で捕捉した中断・使い方の誤りで status と終了状態が一致する。診断の stderr への重複と kind:test/testSummary がない。
- 依存: T2a。

### T3 対象の一致と一切実行しないことの検証

- 目的: ハーネスが確認する対象と test が実行する対象のずれを防ぐ。
- 触るファイル: tests/test_command.rs の共有 fixture と表、必要な testdata、formats、06-04、t3/results.md。
- 手順: 直接指定・ディレクトリ経由・重複・別の根で同じ表示パス・下位パッケージ・リンク・ないパス・空ディレクトリ・テストなし・import 先の @test を比較する。Console に書く関数と目印ファイルに書く関数を --check で調べ、どちらの出力・変更も生じないことを観測する。通常 test ではその同じ入口の関数が対象になることを対照にする。遅延や時間待ちで非実行を判定しない。最後に formats.testCheckReport=[1] を出す。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test test_command --test fmt_command`。T3 の段末と G3 の対象・結果対応を用意する。Assert.Check を確認画面向けに処理系で省く経路がない。
- 依存: T2b。

## 段 3: 実行前のエフェクトの照合

### A1 上限の構文・E0512・run の接続

- 目的: 新しい診断を未使用のまま置かず、run の実際の拒否まで一単位で接続する。
- 触るファイル: cli/effect_limit.rs、Options と引数解析、cli::text、diag/codes.rs、execute_script、tests/cli_process.rs、02-10/06-01/02-11 と生成 Skill、a1/results.md。
- 手順: pub な EffectLimit と Options.allow_effects を解析・比較の本番経路と同時に追加する。PathArgs.allow_effects は A2b まで加えない。正規名から ID への変換、包含、不足と許可のソート済み表示を作る。--allow-effects の両構文を受け、一回の走査で分離値を消費する。main の検査後・脱糖前に比較する。E0512 の未使用を再確認して登録し、関数の位置と note/help を生成する。空集合、収まる集合、不足、重複名、IO.All、未知名、空白、空要素を既存の解析/CLI の表に追加する。gen_skill を同時に実行する。effectLimit の形式宣言は A4 まで出さない。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test cli_process --test skill_docs`。不足時は stdout と目印ファイルに変更なし、E0512・2。通常の検査の誤りと不具合は E0512 に置き換わらない。サブコマンド省略と script 引数を保つ。
- 依存: T3。

### A2a 実行前に済ませる run_input とテスト原型の確認

- 目的: コンパイル後の実行準備を、保持して消費できる形にする。
- 触るファイル: test_runner/mod.rs と実行準備の内部型、tests/test_command.rs、02-11/06-04、a2a/results.md。
- 手順: T1b の通常実行で、run_input の作成と全 TestFn の原型の存在確認を、その入口の最初のテストより前に完了する。必要な非公開の実行準備の型・欄は、それを通常の run_prepared が消費する箇所と同時に作る。実行ごとの RunEnv/RuntimeParts は依然テストごとに作り、CheckedProgram や IR を外へ保持しない。まだ上限のオプションを test に受け付けない。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test test_command`。通常の順と出力を保ち、実行開始後に遅れて run_input/原型の欠落を見つける経路がない。非公開の実行準備は通常の本番処理で使われる。
- 依存: A1。

### A2b test の上限比較・全保持・全体拒否への接続

- 目的: 後の入口の拒否が分かる前に先のテストを実行しない。
- 触るファイル: args.rs、test_runner/mod.rs、tools.rs、tests/test_command.rs、06-04/02-01/02-11、a2b/results.md。
- 手順: PathArgs.allow_effects と PrepareMode::ExecuteLimited を実際の分岐とともに追加する。上限付きだけ全入口の prepare と関数ごとの比較を行い、成功したコンパイル済み成果物と A2a の実行準備を保持する。検査失敗・不足・コンパイル制限の入口があれば一つも始めず、R1 の filesNotRun と非0終了をこの接続時点から返す。不具合・中断も高い優先順位で止める。全成功の Vec を順に消費し、ソース・探索・検査・コンパイルを再実行しない。AST/IR は段で捨て、上限なしの逐次実行を保つ。
- 分割の限界: 上限の受理と全体の開始条件は同時に接続する。先に一入口だけの照合を公開する案は、後の拒否前に実行しない契約に反するため採らない。A3 はこの基本の拒否を後回しにせず、件数・終了状態の広い対照と共通文言を補う。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test test_command --test cli_process`。先頭に書き込み、末尾に不足・検査失敗・コンパイル制限を置いた場合、先頭も開始しない。全成功の順と結果は通常 test と一致する。
- 依存: A2a。

### A3 非実行の集計と終了状態の優先順位

- 目的: 0 passed/0 failed を全体の成功へ誤読できない結果を返す。
- 触るファイル: test_runner/mod.rs・report.rs（必要な接続だけ）、tests/test_command.rs、06-01/06-04、harness-response、a3/results.md。
- 手順: R1 に従い既知の全入口数を filesNotRun へ入れ、test 行を作らない。探索未完了・使い方の誤りで対象数が分からない場合は集計を書かない。成功した空と、不具合・中断・検査拒否・失敗したテストの優先順位を既存の表へ追加する。JSON の既存の欄・型・kind を保ち、文章の集計も FAILED になることを確認する。R9 に従い共通の FILES_NOT_RUN を `; {count} files not run` へ改め、通常 test の全文の期待値も同じ厳密さで更新する。誤りのない入口も数える理由を06-04へ記す。件数の checked conversion を行い、飽和で通さない。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test test_command --test interrupt_process --test cli_process`。N>0 で全体拒否なら filesNotRun=N、状態2、集計の0/0だけで成功を表さない。不具合3と中断130も保持し、通常の test の形式1が変わらない。
- 依存: A2b。

### A4 検査後の変更と同じ成果物の最終照合

- 目的: 確認していない種類のエフェクトの追加を実行前に拒否し、保証の限界も確認する。
- 触るファイル: tests/cli_process.rs・test_command.rs の実ファイルの対照、formats、07-01/06-01、a4/results.md。
- 手順: 報告を受けた後に main/import/テストをそれぞれ追加のエフェクトへ変え、古い expanded を渡して実行し、何も開始しないことを観測する。テストには Assert.Check の不足と余分な許可を含める。die と Exit の処理を報告と同じ規則で比較する。同一実行中の成果物の保持は所有・呼び出し元をレビューし、時間待ちの競合試験やテスト用の本番フックを加えない。同じ集合で書き込み先だけを変えた場合は拒めないことを契約に記す。formats.effectLimit=[1] を追加する。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test cli_process --test test_command --test golden`。A4 の段末・両構成の all-targets と G4 を揃える。run の exit 指定値、die の1とcode:null、test.failure.die を保持する。
- 依存: A3。

## 段 4: 環境変数と Skill の取得

### E1 明示したローダ変数の拒否

- 目的: 子を起動する前に禁止入力を値として返す。
- 触るファイル: builtins/funcs/process.rs の execute/text、tests/l10_console_clock_process.rs または l13_external_commands.rs の適切な既存表、runtime_builtins.rs の関係する入力、prelude/stdlib/IO/Process.bnt の説明、formats とポリシー欄、03-07/07-01、生成 Skill、e1/results.md。
- 手順: 既存の不正入力検査の後、絶対化と spawn より前に二接頭辞を ASCII 大小を区別せず拒否する。辞書順最初の名前だけを InvalidInput に入れ値を出さない。run/runAttached、追加・同値上書き・空値・小文字・LD_RUN_PATH を表にし、子の目印が作られないことを見る。通常変数の追加と上書き、親のダミー変数の継承を対照にする。親の環境をテスト中に大域変更せず、プロセスの env へ渡す。実際の注入ライブラリや秘密を使わない。formats.loaderEnvironment とポリシー欄を同時に宣言する。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test l10_console_clock_process --test l13_external_commands --test runtime_builtins --test skill_docs`。IOError の kind/message、非起動、通常の継承を観測する。read_command の Stop や新しい E コードへ変わらない。
- 依存: A4（実装の順序）。

### S1 Skill の論理名と text の一覧・取得

- 目的: 書き込み先を作らず同梱文書を返す。
- 触るファイル: cli/tools/skill/mod.rs、tools.rs、tests/cli_process.rs・skill_docs.rs の適した既存表、06-01/06-06、s1/results.md。
- 手順: list/show の動詞を追加し、install と同じ render_document で版の置換を共有する。FILES の全件の論理名を検証し、辞書順の list と raw show を実装する。絶対名・..・.・空成分・バックスラッシュ・コロン・未知名を拒否し、入力を OS パスとして開かない。R6 に従い内部の run_skill_cli を tools の呼び先にし、共通解析の install/uninstall 分岐でだけ HOME を取得する。公開 run_skill(args, env, home) は渡された home を共通の実行へ渡す既存シグネチャを保つ。既存 install の本文と取得した SKILL.md を同じ版で比べ、末尾改行を勝手に足さない。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test cli_process --test skill_docs --test skill_examples`。HOME なし・書き込み不可の場所でも取得でき、文書数・内容は実際の埋め込み一覧に一致する。install/uninstall の出力と保護を維持する。
- 依存: E1。

### S2 Skill JSON とハッシュ

- 目的: 置換後の本文と長さ・ハッシュを機械向けに返す。
- 触るファイル: skill/mod.rs または取得用の子モジュール、共通の Hash/producer、formats、tests/cli_process.rs・skill_docs.rs、06-01/06-06、s2/results.md。
- 手順: --format=text|json の解析と skillList/skillDocument を接続する。list の各 name の本文を show で得て、独立に UTF-8 の byteLength と sha256 を計算する。非ASCII本文、版の置換、未知の名前、format の重複、余分な引数、埋め込みの不整合の扱いを確認する。不整合を作るためだけの本番フラグは作らず、一覧の検証の持ち主で確認する。formats.skillList/skillDocument=[1] を出す。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test cli_process --test skill_docs --test skill_examples`。失敗時の stdout は空で、成功の空文書を返さない。S2 の段末と G5 を用意する。
- 依存: S1。

## 段 5: 文書と外部の契約

### D1 現行の設計書の章間の照合

- 目的: 個別の実装で直した章の間の漏れと古い記述を除く。
- 触るファイル: design の文書対応表に挙げた docs/design の章、必要な目次・リンク、d1/results.md。
- 手順: 出力先・診断形式・完全性・終了状態・環境の制約・Skill を実装から表へ照合する。前回 G3/G5/G6 を踏まえ「未接続」「表示しない」「旧い制約」の断定を検索し、現行仕様と一致するかを読む。01-spec に CLI やビルドの事情を混ぜない。07-04 の表を変えない判定を記録し、構文・型・脱糖が変わっていないことを差分で確認する。見出しの変更があれば spec 印・gen_skill の参照を更新する。
- 完了の条件・検査: K、`cargo test -p benitoite --test spec_examples --test reference_examples --test skill_docs`、K-R。リンクと目次、JSON と状態の表が一致する。形式化の範囲を変えた差分があれば本作業を完了せず、先に対応を再設計する。
- 依存: S2 と G1〜G5 の重大・中の指摘の処置。

### D2a 英語リファレンスと導入の手順

- 目的: 利用者に公開する CLI と保証の説明を実装へ揃える。
- 触るファイル: docs/reference/benitoite.md・install.md、d2a/results.md。
- 手順: 全 CLI と報告、usageError 内だけの kind:check・code:null、Assert.Check、dirty の notCollected と commit の監視の限界、LD_RUN_PATH を含む拒否と継承を説明する。Process.Run を許すと env やシェルでローダ変数を設定できる限界も07-01と揃える。同じエフェクトでも操作内容は固定しないことを記す。版の一斉更新は M2b へ渡す。コード例を抽出器の読む fence と照合し、benitoite test fence を説明用と誤分類しない。
- 完了の条件・検査: K、`cargo test -p benitoite --test reference_examples --test spec_examples`。引数・形式・状態と本文が一致し、文書の現在の版を先に上げない。Rust や埋め込みを変えていなければ K-R は不要。
- 依存: D1。

### D2b Skill の手書き文書と生成物

- 目的: LLM に渡す埋め込み文書を実装と英語リファレンスに揃える。
- 触るファイル: Skill の SKILL.md と手書き三文書、標準ソースの文書コメント、必要なら skill/generate.rs、生成 references と bundle.rs、d2b/results.md。
- 手順: D2a と同じ公開契約を Skill の使用手順へ反映する。生成元を修正して gen_skill を実行し、references と bundle.rs を手で直さない。置換用 placeholder とコード例の版を区別し、版の一斉更新は M2b に渡す。生成を二回して差が増えないことを確かめる。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test reference_examples --test skill_docs --test skill_examples --test spec_examples`、gen_skill。英語正と取得する Skill が同じ機能・限界を説明する。
- 依存: D2a。

### D3 ハーネスへの回答と六機能の照合

- 目的: 外部へ伝える契約に、内部の作業の都合や過大な保証を混ぜない。
- 触るファイル: harness-response.md、design.md の必要な訂正、d3/results.md と契約の確認表。
- 手順: BH-022〜027 の各節と実際の CLI の JSON/終了状態を対応させる。formats の全キー、失敗時の扱い、依頼からの限定、Assert.Check、環境の継承、到達性なし、同じ集合内の内容の変更を確認する。リリース前なので実在しないタグを公開済みと書かない。内部 ID や docs/todo へのリンクを出さない。新しい問いが出れば推す案を R へ記録し回答文も直す。
- 完了の条件・検査: K、JSON の例・ローカルリンク・契約表を検証し、D3 の段末と G6 を用意する。処理系を変えた場合は K-R と関係する cargo test も行う。
- 依存: D2b。

## 段 6: 移行と一度の版の更新

### M1 移行対象と E0908 の変更表の準備

- 目的: 版を上げてから大量の入力の E0908 を見つけることを防ぐ。
- 触るファイル: modules/package.rs・text.rs と既存の合成版のテスト、CHANGELOG.md に新設する `## Unreleased`、m1/results.md と移行の確認表。
- 手順: P1 の候補を最新ツリーへ照合し、0.0.7 の summary/help を BREAKING_CHANGES へ登録する。現在は0.0.6なので0.0.7の変更をまだ適用しないことを確認する。合成の current=0.0.7 の境界で古い0.0.4/5/6・現在0.0.7・未来0.0.8の note/help 全文と順序を検証する。CHANGELOG の先頭へ `## Unreleased` を新設し、六機能、E0512、全体の非実行、二接頭辞・大小・InvalidInput・LD_RUN_PATH・継承・language の移行を記す。ハッシュの影響元と期待値を更新する順序を確認表へ書く。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test package_command --test golden --test cli_process --test skill_docs`、gen_skill。実際の0.0.6の通常入力が通り、0.0.7の合成検査で全変更を厳密に列挙する。移行候補に未分類がない。
- 依存: D3 と G6。

### M2a 最終の移行一覧と適用順の確定

- 目的: 版を上げる一単位の編集を機械的に確認できる一覧へ絞る。
- 触るファイル: m2a/results.md と移行の確認表だけ。処理系・入力・公開文書の内容はまだ変えない。
- 手順: M1 と P1 の全候補を最新ツリーへ再照合し、変更する通常入力・負の検査・固定ハッシュ・生成元・生成物・版の期待値をファイルごとに確定する。適用順と独立計算するハッシュの組を示す。歴史資料・reference・意図的な旧版や不一致は残す理由を書く。M2b で `## Unreleased` を `## 0.0.7 (San Benito)` へ改めることも一覧に含める。
- 完了の条件・検査: K（文書の確認）、リンク・一覧・差分の確認。未分類がなく、M2b の編集を始める前に一度の版更新の範囲が確定している。
- 依存: M1。

### M2b 0.0.7・通常入力・固定ハッシュの同時更新

- 目的: 途中にコンパイルはできても関係するテストが壊れる取り込みを作らない。
- 触るファイル: crates/benitoite/Cargo.toml、ルート Cargo.lock の自身の版、通常入力の language と依存宣言、tests/modules/CLI の入力・厳密な期待値、正の固定ハッシュ、英語文書の版、Skill の生成元と生成物、CHANGELOG、m2b/results.md と確認表。
- 手順: M2a の確定した一覧を一単位で適用し一度だけ版を上げる。CHANGELOG の `## Unreleased` を `## 0.0.7 (San Benito)` へ改める。旧版・未来版・不正な版の検査を一律置換せず、未来0.0.7は未来0.0.8へ、旧版の全文診断は追加の変更の説明を含む期待へ直す。全追跡ファイルを検索して通常入力の0.0.6を再確認する。Rust の生文字列・format生成入力、runtime_builtins.rs、tools の参照解、Markdown fence も移行する。hash-match と modules/tests.rs と package_command.rs を含む正の固定ハッシュは影響する入力を変え終えてから独立計算し、意図した不一致は残す。Cargo.lock の無関係な再解決はしない。生成元から gen_skill を実行する。アーカイブ・reference は触らず、fuzz の既知の旧 lock は別件と明記して勝手に再解決しない。
- 完了の条件・検査: K-R、`cargo test -p benitoite --test package_command --test golden --test cli_process --test test_command --test runtime_builtins --test reference_examples --test skill_docs --test skill_examples --test spec_examples`、両構成の all-targets、gen_skill。0.0.6明示はE0908・2、0.0.7は受理、未来はE0907、無宣言も従来どおり。未分類と通常入力の取り残し0件、固定ハッシュは全組一致、負の入力の意図を保持する。
- 分割できない理由: 版だけを先に上げると通常入力と旧版の期待値が失敗し、入力だけを先に上げると未来版の拒否になる。固定ハッシュも入力の変更と一体である。M2a で調査を先に終え、適用と生成を本作業にまとめる。60分を超えても、関係する検査が壊れた中間状態を別の取り込み単位にしない。
- 依存: M2a。

### M3a 日本語リファレンスと導入の訳

- 目的: 利用者文書の英語の正と設計者が読む訳を最終版へ揃える。
- 触るファイル: docs/ja/reference の二文書、m3a/results.md。
- 手順: 英語正の全差分を訳し直し、見出し・表・コード・inline code・版・状態・保証の範囲を対照する。取得する Skill の翻訳には進まず、英語正の訂正が必要なら対応する作業へ返す。
- 完了の条件・検査: K（文書の確認）。訳のコードが正と一致し、リンクが有効である。Rust と埋め込みを変えないので K-R は不要。
- 依存: M2b。

### M3b Skill の日本語訳と最終の公開情報

- 目的: 残る四組の訳と最終の回答・移行参照を揃える。
- 触るファイル: docs/ja/skill/SKILL.md と手書き三文書、harness-response、m3b/results.md。
- 手順: 英語正の全差分を訳し直し、SKILL の frontmatter の訳の説明ブロックと実コードを区別する。E0512・InvalidInput・終了状態・environment の限界を照合する。CHANGELOG の0.0.7見出し、六機能、破壊的変更とE0908の参照を確かめ、回答の producer の版と不明値を実CLIへ揃える。タグ未作成の状態を維持する。
- 完了の条件・検査: K、`cargo test -p benitoite --test reference_examples --test skill_docs --test skill_examples --test spec_examples`。六組全体のコード・表・リンクを最終照合する。英語正や埋め込みも直す必要が生じたら別作業で K-R と生成を行い、結果を反映する。
- 依存: M3a。

## 段 7: 最後の照合

### F1 全機能・全入力・通常段末の検査

- 目的: 個別検査では出ない統合入力の移行漏れと検査の選択漏れを検出する。
- 触るファイル: f1/results.md と全体の契約/入力/検査対応表。見つかった修正は Z へ分ける。
- 手順: P1 の分類の全項目を最終差分へ対応付ける。型変更・公開CLI・全formats・JSON例・通常出力・終了状態・失敗時に非実行を照合する。main/test の集合からAssert.Checkを落としていないこと、Environment の継承を変えていないことを確かめる。版・language・正負のハッシュ・生成元・訳の残存値を検索し、意図した旧値だけを残す。check.sh の選択と M3b/F1 の --only、両構成の all-targets を実行し、全ターゲットとgc-stressを確認する。skill_eval は自己検査だけを行いLLMを呼ばない。通常の検査が改造の作業記録・manifest・一時入力を読んでいないことを確かめる。
- 完了の条件・検査: K、上表のM3b/F1の検査、両構成のall-targets、`git diff --check`。未実施の段末検査がない。--onlyの成功をfullの成功に読み替えない。変更があればZで修正し対応する検査をやり直す。
- 依存: M3b、各Gの指摘の処置。

### F2 完了と公開前の状態の記録

- 目的: 設計・実装・検査・公開の状態を区別して設計者へ渡す。
- 触るファイル: 今回の README.md、results.md、harness-response の提供状態、f2/results.md。
- 手順: 全作業・G1〜G7・Zの処置と最終ツリーの検査結果を集約する。未実施・既知の基準の失敗・今回の残件を区別する。構文/型/脱糖/formalの無変更と07-04の判定を再確認する。メモリの全保持、commit の監視と検知の限界、未指定の dirty は不明であること、同じ集合内の内容の変更、環境の継承の限界を報告する。公開前のfullを行う段階なら、long約15分追加・release_stack約5分追加を含む現時点の総所要時間を知らせ、`scripts/check.sh --full --dry-run` の後に `--full` を実行する。公開前fullをまだ行わない指示なら「通常検査完了、公開前full未実施」と明示する。タグ・公開・保管・docs/todoの閉鎖は別の明示指示に委ね、実在しないタグを記録しない。
- 完了の条件・検査: K（文書の確認）。最終README・結果・回答文の状態が一致し、G7のレビューへ渡せる。後でタグを付けたら実際のタグを回答へ追記する。今回の設計作成から公開の許可を推測しない。
- 依存: F1。

## 前回のレビューから引き継ぐ防止策

| 前回の漏れ・問題 | 今回の手当て |
|---|---|
| G1/G3: 診断・属性の説明が複数章で旧いまま | 各作業で実装済みの章を直し、D1で全章を照合。01-specへ実装事情を混ぜない |
| G3/G5: 個別検査だけ実施して段末のcheck/gc-stressが未実施 | K6/K7と段末表、F1で全結果を最終ツリーへ対応。未実施を完了扱いにしない |
| G5b: 読み込みの退行を既存の失敗と誤認 | 一回の検査と所有の規約、変更前後の再現。標準ライブラリの依存や暗黙importを増やさない |
| G6: 手本・helpと組み込み別名禁止の矛盾 | C3の有効/不正の別名の対照、D1/D2a/D2bの実CLIと説明の照合 |
| G7: benitoite test fenceが「記法」に紛れる | P1/D2a/M2bの全fence確認。実行用の断片は解析・検査の対象とする |
| 前回の全ターゲットで runtime_builtins.rs の旧入力を検出 | P1/M2a/M2bでRust文字列まで列挙、C3/A4/M2b/F1で両構成のall-targets |
| G8: 固定ハッシュ・language・未来版・CHANGELOG・訳の漏れ | M1で一覧と期待差、M2bで一単位の更新、M3b/F1で全文・全件照合 |
| check.sh のpythonが特定の自己検査しか走らせない | V1a/V1b の独立した実ビルドを長い Rust テストへ登録し、V2 段末でも明示実施。今回新しい道具の未接続を作らず、F1で検査の実際の呼び出しを読む |

前回の記録は作業の分け方と漏れの参考として用いた。今回の仕様の根拠は現行設計・コードとQ/Rの判断であり、保管した実装プランを規範として復活させない。
