# ハーネス向け検査インターフェースの詳しい設計

## 目的と範囲

TODO-254 の六機能を 0.0.7 にまとめて提供するための設計である。Q1〜Q14 の推す案は、2026-10-17 に設計者とハーネスの担当が了承した。追加回答は [answers.md](answers.md)、細部を補う問いは [decisions.md](decisions.md) の R1 以降に記す。本書は実装前の契約であり、現行の設計書へ実装済みの仕様として先に写さない。

基準は Benitoite `f31dacd3bddadfb692abd0b2ea31002128f64c4f` と現在の `mod254/design` の処理系である。構文、型の受理規則、エフェクトの推論、脱糖、形式化は変えない。静的に検査した契約の報告と照合、ホストへ渡す入力の制約を加える。OS のサンドボックス、実行時の権限制御、ハーネス自体は対象外である。

## 段 1: 版の情報と共通の部分

### CLI の問い合わせと形式の版

`benitoite --version=json` は標準出力へ UTF-8 の単一 JSON と末尾の LF を書く。最初の引数に限り、後続の引数を許さない。従来の `--version` の二行は保つ。新しい `version` サブコマンドは作らない。

```json
{
  "schemaVersion": 1,
  "kind": "version",
  "name": "benitoite",
  "version": "0.0.7",
  "unicodeVersion": "17.0.0",
  "build": {
    "commit": null,
    "dirty": null,
    "target": "aarch64-apple-darwin",
    "provenance": {"commit": "unknown", "dirty": "notCollected"}
  },
  "formats": {
    "version": [1],
    "diagnostics": [1],
    "testResults": [1],
    "checkReport": [1],
    "testCheckReport": [1],
    "effectLimit": [1],
    "loaderEnvironment": [1],
    "skillList": [1],
    "skillDocument": [1]
  },
  "loaderEnvironment": {
    "schemaVersion": 1,
    "mode": "always",
    "deniedPrefixes": ["DYLD_", "LD_"],
    "nameComparison": "asciiCaseInsensitive",
    "inherited": "unchanged",
    "errorKind": "InvalidInput"
  }
}
```

`name`・`version`・`unicodeVersion`・`build.target` は文字列、`schemaVersion` は整数である。Unicode の数値は例であり、実際は `char::UNICODE_VERSION` から作る。`commit` は完全な Git オブジェクト ID の小文字十六進文字列または null、`dirty` は真偽値または null である。null は不明を表し、変更なしとは扱わない。`provenance.commit` は `environment`・`git`・`unknown`、`provenance.dirty` は `environment`・`notCollected` のいずれかである。dirty の未指定時は自動採取をしないことを `notCollected` で示す。明示的に不明を指定した場合は値が null でも `environment` とする。

`formats` は形式名から対応する整数の配列へのオブジェクトである。能力の有無はキーと既知の整数の両方で判定する。途中の実装は `version`・`diagnostics`・`testResults` から始め、完了した機能だけキーを追加する。`loaderEnvironment` のポリシー欄も、その能力を提供してから出す。空の配列や未実装のキーは出さない。

`diagnostics: [1]` と `testResults: [1]` は、0.0.6 の `kind: "die"`、`code: null`、テストの `failure.die` を含む既存の JSON Lines の形式を指す。新しい報告の usageError に限る `kind:"check", code:null` は checkReport/testCheckReport 形式1の契約として別に定める（R5）。既存の行に `schemaVersion` や開始行を追加しない。`effectLimit` は出力オブジェクトの名前ではなく、引数・包含の判定・E0512 の契約の版である。

欄の削除、型・必須性・意味の変更、成功判定に新しい解釈を必要とする分類の追加では該当形式の版を上げる。無視しても意味の変わらない任意欄だけの追加は同じ版でよい。未知の形式、status、エフェクト名を空集合や成功へ読み替えない。

### build.rs の入力と採取

`crates/benitoite/build.rs` を追加し、標準ライブラリだけで実装する。Git はビルド時の commit の自動採取でだけ使い、実行時の依存にしない。入力の誤りなどの文言は build.rs 内の `text` 子モジュールの定数へまとめる。生成先は `OUT_DIR` に限り、ソースと Git の管理データを書き換えない。`TARGET` をそのまま埋め込み、ホストの `cfg!` から推測しない。

| 入力 | 受け付ける値 | 未指定時 |
|---|---|---|
| `BENITOITE_BUILD_COMMIT` | ASCII の十六進 40 桁または 64 桁（小文字へ正規化）、`unknown` | Git から採取 |
| `BENITOITE_BUILD_DIRTY` | `true`・`false`・`unknown` | null、由来は `notCollected` |

空、前後の空白、短縮 ID、非 UTF-8、不正値はビルドを終了状態 1 で止め、入力名と許す構文をビルドの標準エラー出力に書く。値の不正を Git の値で補わない。欄ごとに明示値を優先する。例えば commit だけ指定した場合、dirty は null・`notCollected` になる。commit を明示すれば dirty の指定にかかわらず Git を起動しない。`unknown` は Git の自動取得を意図して止める指定でもある。

自動採取の根は `CARGO_MANIFEST_DIR` の二つ上を候補にする。その直下に `.git`（ディレクトリまたは worktree のファイル）、ワークスペースの `Cargo.toml`、候補と同じ実体の `crates/benitoite` があることを確かめる。`git -C <候補> rev-parse --show-toplevel` の実パスも候補と一致しなければ採取しない。アーカイブを別の Git リポジトリの下に展開しても、親の `.git` を探し上がらない。

Git の呼び出しは引数配列で行い、シェルを使わない。リポジトリの選択を変える `GIT_DIR`・`GIT_WORK_TREE`・`GIT_COMMON_DIR`・`GIT_INDEX_FILE`・`GIT_OBJECT_DIRECTORY`・`GIT_ALTERNATE_OBJECT_DIRECTORIES` はこの子の環境から除く。`--no-optional-locks` と `-c core.fsmonitor=false` を付け、commit は `rev-parse --verify HEAD^{commit}` で得る。dirty は自動採取せず、status や index を読まない。作業ツリーの編集だけを理由にビルド情報を更新しない。

Git 不在、Git の失敗、根の不一致、HEAD 不在、出力の不正では commit を null・`unknown` とし、ビルドを続ける。dirty の明示値はこの失敗に影響されない。worktree の管理ディレクトリを `.git/HEAD` と決め打ちしない。タグ名や現在時刻から値を捏造しない。採取中にソースが変わることまで固定する保証はない。

### ビルド情報の再採取と生成データ

再採取は、build.rs 自体の変更、二つの明示入力の変更、commit を自動採取する場合の Git の HEAD・参照中のブランチの ref・packed-refs・HEAD の reflog（`logs/HEAD`）の変更に限る（R2・R11）。`cargo::rerun-if-changed=build.rs` と二つの `cargo::rerun-if-env-changed` を常に出す。`TARGET` は Cargo のビルド単位から来るので `rerun-if-env-changed=TARGET` は出さない。毎回の再実行を起こす欠けた監視パスは使わない。

Git の監視先は、根を検証した後に `git rev-parse --path-format=absolute --git-dir` と `--git-common-dir` で実際の管理場所を求める。HEAD と `logs/HEAD` は git-dir 側、packed-refs は common-dir 側とする。symbolic HEAD が指す ref は `git symbolic-ref -q HEAD` で得て、`git rev-parse --path-format=absolute --git-path <ref>` で実際のパスへ解決する。detached HEAD ならブランチの ref は監視しない。存在するファイルだけを登録し、index、作業ツリー、リポジトリ全体のディレクトリは監視しない。commit を明示した場合は Git の監視も不要である。

HEAD の監視が登録できない場合、symbolic HEAD の ref と packed-refs のどちらの監視も登録できない場合、管理場所や ref のパスが解決できない場合、common-dir に `reftable` がある場合は commit を null・由来 `unknown` とする。

存在しないパスの登録は毎回の再実行を起こす（[Cargo FAQ](https://doc.rust-lang.org/cargo/faq.html#why-is-cargo-rebuilding-my-code)、2026-10-17確認）。このため、ファイルだけの監視には限界がある。HEAD の reflog がない状態で packed ref から loose ref が新設される場合や、commit のないブランチに最初のコミットを作る場合など、登録済みのファイルが変わらない変更は検知できない。Git の導入、アーカイブへの Git 管理の追加も自動検知の対象外とする。この条件では明示入力を変更するか、そのパッケージを clean build してから情報を採る。commit はそのビルドで採取した自己申告であり、毎回の Git 状態との一致を保証しない。V1b はこの限界も観測し、監視対象の不在を dirty=false へ読み替えない。

Cargo の監視とパッケージの再コンパイルは [Cargo Book](https://doc.rust-lang.org/cargo/reference/build-scripts.html#change-detection) を根拠とする（2026-10-17 再確認）。以前の案の「欠けたパスで毎回再採取」は採らない。V1a では変更なしで同じ `cargo test` を二回実行し、二回目に lib を作り直さず `Compiling benitoite` が出ないことを固定ツールチェーンで確認する。

build.rs は `BENITOITE_EMBEDDED_BUILD_COMMIT`（不明は空文字列）、`BENITOITE_EMBEDDED_BUILD_DIRTY`（true/false/unknown）、`BENITOITE_EMBEDDED_BUILD_TARGET`、`BENITOITE_EMBEDDED_COMMIT_PROVENANCE`、`BENITOITE_EMBEDDED_DIRTY_PROVENANCE` を `cargo::rustc-env` で渡す。入力の検証を終えてから出力するため改行を命令に混入させない。実行時のモジュールは V2 で利用する時に追加し、`env!` で読み、入力名の実行時環境を読まない。

Git の根、HEAD、管理場所、ref のパスの取得は [git-rev-parse](https://git-scm.com/docs/git-rev-parse)、symbolic HEAD は [git-symbolic-ref](https://git-scm.com/docs/git-symbolic-ref) を根拠とする。ビルド情報はバイナリのハッシュや信頼の証明ではない。

### 共通の所有データと変更する型

新しいモジュールは `cli/build_info.rs`（埋め込み情報と producer）、`cli/inspection.rs`（検査した契約の所有データ）、`cli/check_report.rs`（報告の組み立てと書き込み）、`cli/effect_limit.rs`（上限の構文と比較）とする。必要な子のモジュールへの分割は同じ責務の中で行ってよい。公開の Options/PathArgs の欄に使う `ReportFormat`・`EffectLimit` は `pub` とし、CLI から参照できるように再公開する。EffectLimit の内部の集合と、解析・比較の補助関数は非公開または `pub(crate)` に留める。その他の新しい型・関数も利用箇所に必要な範囲だけ公開する。定数の表は持ってよいが、可変な大域の値・キャッシュ・新しい開発用の環境変数は作らない。

| 現在の型・関数 | 変更後の契約 |
|---|---|
| `cli::Command::Version` | 既存の variant を残し、`VersionJson` を加える |
| `cli::Options` | `report: Option<ReportFormat>`、`allow_effects: Option<EffectLimit>` を追加。どちらも既定 None。`ReportFormat` は Json のみ |
| `cli::tools::args::PathArgs` | `check` を test でも使用。上と同じ `report`・`allow_effects` を追加。fmt は両方拒否 |
| `parse_args(Vec<OsString>) -> Result<Command, String>` | 公開シグネチャは保つ。内部の `parse_invocation(Vec<OsString>) -> Result<Command, CliParseError>` を共通の本体とし、公開入口は detail へ写す |
| 内部 `parse_test_invocation`（新規） | `fn parse_test_invocation(args: Vec<OsString>) -> Result<(PathArgs, WasmOptions), TestParseError>`。tools の test 分岐で使用。TestParseError は detail・report: Option<ReportFormat>・paths: Vec<PathBuf> を持つ（R18） |
| `parse_test_args(Vec<OsString>) -> Result<(PathArgs, WasmOptions), String>` | 呼び出す既存の入口は保ち、報告の認識状態を持つ内部入口を tools が使う。Wasm オプションを先に消す現構成は、`--check` との併用を消失させない形に改める |
| `CliParseError`（新規、CLI 内） | `detail: String`、`report: Option<ReportKind>`、`script: Option<PathBuf>`。使い方の誤りを報告へ包み、解析済みの指定パスを残すための一回分の所有データ（R13） |
| `CheckedProgram`・`CheckResult`・`TypeckOutput`・`Scheme` | 型・欄・型検査の意味を変えない。表を借用して CLI が情報を抽出する |
| `test_runner::collect_tests` | `fn collect_tests(checked: &CheckedProgram, entry: FileId) -> Result<Vec<TestFn>, InternalError>` に変更。検査成功後の束縛・型の欠落を黙って飛ばさず、不具合として返す。全呼び出し元を同時に更新 |
| `test_runner::TestFn` | 既存の欄を保つ。エフェクトは別の `FunctionContract` と binding で対応させ、実行結果の JSON に足さない |
| `test_runner::Prepared`（非公開） | `result`（program は None）、`inspection: Option<Result<TestInspection, InternalError>>`（TestInspection は ProgramInspection と同じ collect_tests の所有する Vec<TestFn>。R19）、`compiled: Option<Result<Compiled, PrepareError>>` を持つ |
| `test_runner::Summary` | 欄・型・既存 JSON を変更しない。事前検査で全体を拒否した場合の数え方を定める |
| `test_runner::Runner::run_file` | 準備と実行へ分ける。`run_prepared(&mut self, entry: &EntrySpec, prepared: Prepared) -> Flow` がソースを開き直さずに実行 |
| `test_runner::prepare` | `fn prepare(entry: &EntrySpec, deny_warnings: bool, mode: PrepareMode) -> Prepared`。Inspect/Execute/ExecuteLimited(EffectLimit) を区別 |
| `process::execute`・`read_command`・言語の `Process.Command` | シグネチャと欄は変更しない |
| `skill::SkillFile`・`files()`・`install_dir`・`run_skill` | シグネチャを保つ。既存 run_skill は受け取った home を使用し、新しい CLI 用の内部入口だけが install/uninstall で HOME を取得する。解析・実行・本文の置換は共有する（R6） |

抽出する所有データの最終形は次のとおりである。ここで示す Rust は受け渡しの設計であり、実装の仮置きを作る指示ではない。FunctionContract.binding はテストとの照合で読む T2b、ProgramInspection.tests と inspect_tests は T2b、EffectLimit は A1 で初めて追加する。ShellReference::Unknown も、失敗したテスト入口の processShellReference を出す T2b で追加する。C1b では main:null が未確定を表すため、Present/Absent だけを使う。未使用の variant や欄を先に置かない（R7）。

```rust
struct FunctionContract {
    binding: BindingId,
    name: String,
    location: Span,
    effects: Vec<BuiltinEffectId>, // 正規名の辞書順
}
struct ProgramInspection {
    main: Option<FunctionContract>,
    tests: Vec<FunctionContract>,
    process_shell_reference: ShellReference,
}
enum ShellReference { Present, Absent, Unknown }
pub struct EffectLimit(BTreeSet<BuiltinEffectId>); // 内部の集合は非公開（R23）
```

`inspection::function_contract(checked: &CheckedProgram, binding: BindingId, name: &str, location: Span) -> Result<FunctionContract, InternalError>`、`inspection::inspect_main(checked: &CheckedProgram) -> Result<ProgramInspection, InternalError>`、`inspection::inspect_tests(checked: &CheckedProgram, tests: &[TestFn]) -> Result<ProgramInspection, InternalError>` を設ける。main 宣言の照合と AST の破棄は既存の段の大きなスタック内で行う。shell の判定は refs の値と expr_types のノードの照合を用いる（R15）。契約表の欠落、エフェクト変数、利用者エフェクト、IO.All の未展開、未知の組み込み番号は処理系の不具合として返す。空集合へ補わない。

報告用の位置と診断は SourceTable が使える間に所有する JSON 値へ変換する。`check_report::diagnostic_value(diag: &Diagnostic, sources: &SourceTable) -> Result<serde_json::Value, InternalError>` は既存の `render_json_line` の結果を JSON 値として読み込む。二つ目の診断レンダラを作らず、失敗したら内部エラーにする。位置も既存の `render::json_location` の形を再利用する。既存のレンダラの公開シグネチャは変えない。

新しい `check_report::sources(sources: &SourceTable, target_id: &str) -> Vec<SourceRecord>` は元の `Source::text()` を SHA-256 にする。最終報告の JSON 値と文字列・整数は所有データであり、AST や型表の参照を残さない。`cli::execute_script` と test の prepare は、深い AST・コア IR の破棄まで段のスレッドで終え、外へはソース、診断、抽出した小さな情報、必要なコンパイル済み成果物だけを返す。新しい検査のために型検査や標準ライブラリの読み込みをもう一度行わない。

## 段 2: 機能 1・2 の非実行の検査報告

### オプションと使い方の誤り

```text
benitoite check [--diagnostics=json] [--deny-warnings] --report=json <script>
benitoite test --check [--diagnostics=text|json] [--deny-warnings] <path>...
benitoite test --check --report=json [--diagnostics=json] [--deny-warnings] <path>...
```

`--report` は `--report=json` だけを受け、分離した `--report json` は受けない。test の `--check` は値を取らない。run/check のオプションはスクリプトより前、test のオプションは従来どおりパスの前後で受ける。test には一つ以上のパスを要求する。既存の `--` とパスの解釈を拡張しない。

| 組み合わせ・入力 | detail の英語案 |
|---|---|
| test で report だけ | `` `--report=json` requires `test --check` `` |
| report と明示した diagnostics=text | `` `--report=json` cannot be combined with `--diagnostics=text` `` |
| test --check と実行専用オプション | `` option `{name}` is not accepted with `test --check` `` |
| check で allow-effects、run で report、fmt で report/allow | `` option `{name}` is not accepted by `{command}` `` |
| report の未知の値・値なし | 既存の `` invalid value `{value}` for `{name}` `` |
| 同じオプションを二回 | 既存の `` option `{name}` may only be specified once `` |
| version=json の後に引数 | 既存の `` unexpected argument `{value}` `` |

test --check は `--max-call-stack`、すべての `--wasm-*`、`--allow-effects` を拒否する。明示した diagnostics=json は report と併記でき、同じ診断を標準エラー出力に再送しない。省略した diagnostics=text の既定値は併用の誤りにしない。明示指定かどうかは解析中の seen で判定する。

解析では、処理系のオプションの範囲を最後まで走査してから報告モードを決める。途中の使い方の誤りは記録して走査を続け、範囲内に有効な `--report=json` が一つでもあれば、その誤りを usageError の報告へ包む。check はスクリプトより前まで、test は従来受ける全オプションの範囲を対象にする。コマンドの語を選ぶ走査にも分離値の消費を適用する。値を取る既知のオプションの分離値は同じ走査で消費し、値やスクリプト引数の字面を report 指定と取り違えない（R3）。run/check の分離値の指定そのものは従来どおり拒否し、受理する構文は広げない（R13）。

`check --diagnostics=text --report=json <script>` と逆順はともに checkReport の usageError、`check --bogus --report=json <script>` も同じ kind の usageError とする。`test --report=json <path>` は --check がなくても testCheckReport の usageError（状態2）とし、テストを実行しない。有効な report がない場合は従来の文章による使い方の誤りを返す。範囲内の認識可能な誤りの選択は従来の先頭の誤りを基本とし、走査後に併用条件を判定する。オプションの境界自体を確定できない入力、初期化の失敗、外側の panic、abort、強制終了は完成した報告の保証外である。

### エフェクトと shell の抽出

main は `types.main` の MainInfo.binding を使い、対応するトップレベルの関数宣言を resolved.decls で照合して名前の Span を得る。型表と宣言の対応がなければ内部エラーにする。テストは既存の `collect_tests` が選んだ binding から `types.decl_types` を引き、検査済みの `Scheme.effects` を使う。宣言した上限であり、本体の最小の集合へ絞らない。IO.All は次の十個へ既に開かれていることを確認する。

```text
Clock.Time, Console.Read, Console.Write, File.Read, File.Write,
Process.Environment, Process.Exit, Process.Run, Random.Generate, State
```

Http.Connect・Http.Listen・Assert.Check は IO.All に含めないが、原子的な正規名として使える。名前の一覧は `types::builtin::BUILTIN_EFFECTS` から作り、IO/Network の名前空間を外した現行の表記に揃える。State と Assert.Check を例外的に落とさない。報告・上限の解析・診断の型表示は `types::builtin::effect_name` の変換を使う。型表示では `IO.All` の名前も返し、報告と上限の解析では未展開の `IO.All` を拒否する（R16）。

`or die` の Process.Exit は型検査の集合から得る。完全なハンドラで処理し uses に残さなければ消え、uses に残せば報告にも残る。or return と裸の try だけでは足さない。AST から Exit を後付けしない。

shell は `resolved.stdlib("Benitoite.IO.Process.shell")` の束縛と、`resolved.refs.iter()` の全件の値を比較し、一致するノードが `types.expr_types` にもあれば present、なければ absent とする。AST の式の再走査は行わない。理由: refs と式の型の表を使えば、新しい式の variant を報告側の走査へ加え忘れる危険を避けながら、式以外の参照を除ける。import の参照はモジュールの束縛なので一致しない。shell は組み込みの操作であり、ハンドラ case の操作名にも同じ束縛が記録されるが、式の型を持たないため除く（R15）。ハンドラの本体にある式の参照は含める。

検査した全プログラム（入口、依存、標準ソース）を対象とし、到達しない関数も含める。標準の宣言そのものは参照ではない。同名の利用者定義、文字列・コメントには反応しない。checkReport では検査失敗を `main: null` で表し、shell の参照も未確定とする。`unknown` は testCheckReport の Target で返す。検査成功時に IO.Process が読み込まれていなければ absent とする。読まれたかどうかは `checked.modules` の標準モジュールの種類と完全なモジュール名で判定し、shell の索引がないことだけで判断しない。import と構文による内部依存の双方を含め、IO.Process が読まれているのに shell の束縛がなければ内部エラーとする。判定のための追加の import は行わない。main やテストからの到達性は解析しない。

### 報告の共通欄と null

以下は形式 1 の必須欄である。整数は負でなく、順序を持つ配列は記載した順を保つ。オブジェクトのキーの順序と JSON の空白は契約にしない。

| 欄 | 型と意味 |
|---|---|
| `schemaVersion`, `kind` | 整数 1、`checkReport` または `testCheckReport` |
| `producer` | `{name: string, version: string, build: BuildInfo}`。版問い合わせと同じ値 |
| `status` | ok / checkError / usageError / internalError。test では interrupted もある |
| `complete` | boolean。status が ok で、探索と全対象の検査・情報抽出が成功した場合だけ true |
| `targetsComplete` | boolean。入口の選択または test の探索を最後まで終えた場合 true。型検査成功とは独立 |
| `executed` | boolean の false 固定。利用者の関数を実行していない |
| `requestedTargets` | `[{requestIndex: integer, path: string}]`。0 始まり、指定順、誤った指定も保持 |
| `targets` | 下記 Target の配列。探索順（test は明示指定順と各ディレクトリ内の辞書順） |
| `sources` | `[{sourceId: string, displayPath: string, kind: user/prelude, contentHash: Hash}]` |
| `sourceSets` | `[{targetId: string, sourceIds: string[]}]`。SourceTable の FileId 順 |
| `aggregateEffects` | Effects または null。全体が complete の場合だけ main または全 @test の和 |
| `diagnostics` | 既存と同じ欄を持つ診断の配列。checkReport の標準ソース内の誤りでは通常の check と同じ内部エラー一件だけを返す。報告内の usageError にだけ kind:check・code:null を認め、primary:null も許す（R5） |
| `diagnosticTargets` | `[{diagnosticIndex: integer, targetId: string|null}]`。診断一件に一行。探索全体・使い方の誤りは null |

Effects は `{basis: "declaredUpperBound", expanded: string[]}`、Hash は `{algorithm: "sha256", value: string}` である。value は 64 桁の小文字の十六進数である。純粋な成功は expanded が空、不明は Effects 自体が null となる。sources にある項目の contentHash は必須であり null にしない。完全なバイト列を持たない入力は sources に作らず診断へ残す。

Target の共通欄は `targetId: string`、`requestIndex: integer`、`entry: string`（表示名）、`root: string`（表示用）、`sourceId: string|null`（入口を読めなかった場合 null）、`kind: "main"|"tests"`、`status`、`complete: boolean` である。main の Target は `main: Main|null`、tests の Target は `tests: Test[]|null` と `processShellReference`・`shellReferenceScope` を持つ。別種の欄は出さない。未着手の入口も Target に残し status は中止原因の internalError/interrupted、complete は false、main/tests は null とする。

Main は `symbol: "main"`、`location`、`effects`、`processShellReference: "present"|"absent"|"unknown"`、`shellReferenceScope: "checkedProgram"` を持つ。Test は `function: string`、`description: string|null`、`location`、`effects` を持つ。description の null は @test の説明省略、空文字列は明示した空の説明である。関数一覧を確定できなければ main/tests 全体を null とし、既知の成功を装った空配列を作らない。location は既存のテストの位置と同じ `{file,start:{line,column,offset},end:{line,column,offset},label}` で、行・列は 1 始まり、offset は元のバイト列の0始まりの位置、label は空文字列とする。成功した関数に位置がない場合は内部エラーとする。main が null の場合は shell の参照も未確定という意味であり、absent を推定しない。

targetId は t0, t1, …、sourceId は `t0:s0` のように入口と FileId の組から作る。ID は報告内だけで一意とし、別の実行との同一性の証明にしない。同じファイルを二回指定した場合も Target とその SourceTable を分ける。同名の表示パスや同じ標準ソースのハッシュがあってもまとめない。sources は Target 順・FileId 順とし、sourceSets は失敗・未着手の Target にも一行を持つ（未着手は空配列）。

ハッシュは診断と検査に使った同じ SourceTable の元の全バイト列から計算し、BOM・改行・不正 UTF-8 を正規化しない。package.bnt、依存、prelude を含める。Wasm バイナリ、ハッシュ検証だけの読み取り、存在しなかった設定ファイル、ディレクトリの観測は含めない。表示パスは OS のパスの可逆な符号化ではなく、受け手へのファイル読み取り指示でもない。

### main の成功例と失敗例

次のハッシュは例示用であり、実ファイルを指さない。例の sources を一件に縮めたのは形の説明のためである。実装は読み込んだ標準ソースも全件出す。

```json
{
  "schemaVersion": 1,
  "kind": "checkReport",
  "producer": {"name":"benitoite","version":"0.0.7","build":{"commit":null,"dirty":null,"target":"aarch64-apple-darwin","provenance":{"commit":"unknown","dirty":"notCollected"}}},
  "status": "ok", "complete": true, "targetsComplete": true, "executed": false,
  "requestedTargets": [{"requestIndex":0,"path":"main.bnt"}],
  "targets": [{"targetId":"t0","requestIndex":0,"entry":"main.bnt","root":".","sourceId":"t0:s0","kind":"main","status":"ok","complete":true,"main":{"symbol":"main","location":{"file":"main.bnt","start":{"line":2,"column":10,"offset":10},"end":{"line":2,"column":14,"offset":14},"label":""},"effects":{"basis":"declaredUpperBound","expanded":["Console.Write","Process.Exit"]},"processShellReference":"absent","shellReferenceScope":"checkedProgram"}}],
  "sources": [{"sourceId":"t0:s0","displayPath":"main.bnt","kind":"user","contentHash":{"algorithm":"sha256","value":"0000000000000000000000000000000000000000000000000000000000000000"}}],
  "sourceSets": [{"targetId":"t0","sourceIds":["t0:s0"]}],
  "aggregateEffects": {"basis":"declaredUpperBound","expanded":["Console.Write","Process.Exit"]},
  "diagnostics": [], "diagnosticTargets": []
}
```

オプションの範囲の走査で report が確定し、パスがなかった場合は次の形となる。構文・名前・型の誤り、E0414（main なし）、E0101（読み取り）は同じ共通欄を持ち、status が checkError、分かった入口と sources と既存の診断を残す。検査失敗で main は null となる。

```json
{
  "schemaVersion":1,"kind":"checkReport",
  "producer":{"name":"benitoite","version":"0.0.7","build":{"commit":null,"dirty":null,"target":"aarch64-apple-darwin","provenance":{"commit":"unknown","dirty":"notCollected"}}},
  "status":"usageError","complete":false,"targetsComplete":false,"executed":false,
  "requestedTargets":[],"targets":[],"sources":[],"sourceSets":[],"aggregateEffects":null,
  "diagnostics":[{"kind":"check","severity":"error","code":null,"message":"missing script path","primary":null,"secondary":[],"notes":[],"helps":[]}],
  "diagnosticTargets":[{"diagnosticIndex":0,"targetId":null}]
}
```

usageError の `kind:"check", code:null` は、新しい報告の diagnostics 内にだけ現れる組み合わせである。既存の診断形式1の JSON Lines には追加しない。02-10「JSON の形式」の表と「使い方の誤りは常に文章」の記述は、C2a で報告内だけの例外として更新する。形式の判断は R5 に記す。

報告の専用関数は `check_report::run_check(options: Options, script: PathBuf, env: CliEnv) -> u8` とする。require_main=true の既存の検査を一度行い、段の中で情報を抽出する。report なしの check/run とは出力の分岐を先に分ける。`prelude_error` が見つける標準ソース内の誤りは従来どおり internalError とする。`--deny-warnings` で拒否した場合も checkError・complete=false とし、警告昇格後の診断をそのまま返す。

報告モード確定後の入口の選択から検査・抽出・組立・JSON の直列化までを捕捉の範囲とし、内部エラーを単一報告へ収める。確定した入口と持ち出し済みの SourceTable だけを使い、検査段の巻き戻しで持ち出せなかったソースは再読しない。入口選択済みなら targetsComplete=true とし、ソースを保持できなければ sources とその Target の sourceIds は空配列、sourceId は null とする。main・aggregateEffects は null、complete=false とする（R14）。書き込みは直列化後に一度だけ行い、書き込み・flush の失敗は1で終え、別の報告を送らない。失敗報告自身の組立の失敗と境界外の panic は完成した報告の保証外である。

### テストの報告と実行との共通化

`test_entries` と `collect_tests` を唯一の対象選択にする。直接指定・ディレクトリ指定による root の違い、下位パッケージを除く規則、明示パスの重複、リンクの扱いを保つ。`test_entries` は公開シグネチャを保ち、内部の共通の探索関数 `fn select_test_entries(paths: &[PathBuf]) -> EntrySelection` を使う。通常の実行と非実行の報告も同じ内部入口を使う。探索失敗時はそれまでの発見結果を参考に残せるが、全体と保持した各 Target を checkError・complete=false とし、targetsComplete=false、tests=null、shell=unknown、空の sourceIds を返す。探索全体の E0101 の targetId は null とし、検査も実行も始めない（R20）。既存入口は failure を従来の Err へ写す。

```rust
struct EntrySelection {
    entries: Vec<SelectedEntry>,
    completion: Result<(), SelectionFailure>,
}
struct SelectedEntry {
    request_index: usize,
    entry: EntrySpec,
}
struct SelectionFailure {
    request_index: usize,
    path: PathBuf,
    error: std::io::Error,
}
```

完了と失敗は `completion` の `Ok(())` と `Err(failure)` で区別し、報告の `targetsComplete` をそこから求める（R17）。T2a では `entries: Vec<EntrySpec>` と `completion: Result<(), (PathBuf, std::io::Error)>` を使う。失敗前に選び終えた指定パスの入口は保持するが、走査に失敗したディレクトリ内の部分一覧は返さない。request_index と上記の SelectedEntry/SelectionFailure は、報告で使う T2b で加える。

`PrepareMode::Inspect` は require_main=false の検査と情報抽出だけを行う。AssertTable の構築、脱糖、コンパイル、VM、RuntimeParts の生成、外部関数の実行へ進まない。型検査の既存の定数の計算と外部宣言の静的な確認は行う。`test --check` はコンパイルの制限まで検査したとは保証しない。

報告モードでは入口ごとの準備の直後に sources の識別情報とハッシュ・診断・tests を JSON にし、SourceTable の本文と行表は次の入口へ進む前に捨てる。各 Target が保持するのは、この JSON とソースの識別子・状態・エフェクトであり、入口ごとの CheckResult は保持しない。内部の状態は enum で表し、報告の文字列と終了状態はそれぞれ網羅する match で求める。

通常の検査の誤りがあっても他の入口を検査し、対象ごとの診断を保持する。探索失敗は停止してよく、処理系の不具合と中断では未着手の Target を不完全として終える。テストなしの有効なファイルは tests=[]、空ディレクトリは targets=[]・targetsComplete=true・complete=true・空の aggregateEffects である。main は要求せず、取り込んだモジュールの @test は実行対象へ加えない。

```json
{
  "schemaVersion":1,"kind":"testCheckReport",
  "producer":{"name":"benitoite","version":"0.0.7","build":{"commit":null,"dirty":null,"target":"aarch64-apple-darwin","provenance":{"commit":"unknown","dirty":"notCollected"}}},
  "status":"ok","complete":true,"targetsComplete":true,"executed":false,
  "requestedTargets":[{"requestIndex":0,"path":"tests/math.bnt"}],
  "targets":[{"targetId":"t0","requestIndex":0,"entry":"tests/math.bnt","root":"tests","sourceId":"t0:s0","kind":"tests","status":"ok","complete":true,"processShellReference":"absent","shellReferenceScope":"checkedProgram","tests":[{"function":"sum","description":null,"location":{"file":"tests/math.bnt","start":{"line":2,"column":10,"offset":10},"end":{"line":2,"column":13,"offset":13},"label":""},"effects":{"basis":"declaredUpperBound","expanded":["Assert.Check"]}}]}],
  "sources":[{"sourceId":"t0:s0","displayPath":"tests/math.bnt","kind":"user","contentHash":{"algorithm":"sha256","value":"0000000000000000000000000000000000000000000000000000000000000000"}}],
  "sourceSets":[{"targetId":"t0","sourceIds":["t0:s0"]}],
  "aggregateEffects":{"basis":"declaredUpperBound","expanded":["Assert.Check"]},
  "diagnostics":[],"diagnosticTargets":[]
}
```

途中に失敗したファイルがあれば全体の status は checkError、complete は false、aggregateEffects は null となる。成功した Target の tests と effects は残す。Assert.Check は各テストの報告、和、上限との比較のすべてに含める。ハーネスが確認画面で省くことは処理系の集合を小さくする理由にしない。

report なしの `test --check` は診断だけを書き、成功時も標準出力は空とする。警告があれば標準エラー出力へ出す。どちらの非実行モードも kind:test/testSummary を出さない。report の test は tools::run_body の捕捉済みの panic（DEV_PANIC=tool を含む）も専用の失敗報告へ渡し、kind:testCheckReport・internalError・complete=false とする。認識後の panic を既存の標準エラー出力だけの境界に吸い込ませない。report ありの中断を捕捉できた場合は interrupted・complete=false と一個の報告を返す。中断の確認は既存の「ファイルを始める前」の読み口だけで行い、ファイルの後や最終報告の直前には新しい読み取りを加えない（R8）。型検査の途中で即時に停止できる保証は加えず、最後のファイルの検査中の要求は報告へ反映できない場合がある。

### 終了状態と書き込み

| モード | 終了状態 |
|---|---|
| check の報告 | ok=0、checkError/usageError=2、internalError=3 |
| test の非実行の検査 | ok=0、checkError/usageError=2、internalError=3、捕捉した interrupted=130 |
| version の問い合わせ | 成功=0、使い方の誤り=2、不具合=3 |
| 上記の機械向け標準出力の書き込み失敗 | 1。完成した JSON を返した扱いにしない |

test の複数の原因は interrupted > internalError > usageError > checkError > ok の順で全体に反映する。診断の順序は入口順、その中は既存の段・位置順とする。探索・使い方の診断を先に置き、診断配列と diagnosticTargets の対応を崩さない。機械向け出力は全体をメモリ上で直列化してから一回の出力処理に渡すが、OS の書き込み自体の不可分性は保証しない。正常に返すはずの結果が何であっても出力に失敗したら 1 とする。受け手は終了状態と完成した JSON の両方を見る。

## 段 3: 機能 3 の実行前の照合

### 許す集合の構文

```text
benitoite run --allow-effects=Console.Write,Process.Exit <script> [args...]
benitoite --allow-effects= <script>
benitoite test --allow-effects=Assert.Check,File.Read <path>...
```

`--allow-effects=<値>` と `--allow-effects <値>` を一回だけ受ける。空文字列は空集合、カンマ区切りの正規名は順序自由である。重複、空の要素、前後を含む空白、未知名、IO.All、利用者定義名、import の別名、`*` は使い方の誤り（2）とする。値を勝手に trim しない。13 個の原子的な組み込み名を受ける。チェック専用モードは受けない。オプションなしでは現在の動作を保つ。

detail の案は `` invalid effect name `{name}` in `--allow-effects`; use atomic names from `expanded` ``、`` duplicate effect name `{name}` in `--allow-effects` ``、`` empty effect name in `--allow-effects` `` とする。二回のオプションは既存の DUPLICATE_OPTION、値なしは MISSING_OPTION_VALUE にする。run のスクリプト以後の同名引数はスクリプト引数である。分離値を先にコマンド名やパスと誤認しないよう解析器を直す（R3）。

### E0512 と包含の判定

`effect_limit::parse(value: &str) -> Result<EffectLimit, String>` と `effect_limit::check(contract: &FunctionContract, allowed: &EffectLimit) -> Option<Diagnostic>` を共通に使う。`required ⊆ allowed` を組み込み ID で判定し、不足があれば対象関数ごとに一件を返す。余分な許可は誤りにしない。Assert.Check も同じ扱いである。

新しい番号は E0512 とする。2026-10-17 の `diag/codes.rs` の E05 系は E0511 までであり、現行の enum・表に E0512 はない。study や今回の提案中に現れる文字列は既存の割り当てとは区別した。実装開始時に再検索し、衝突していれば黙って番号を変えず判断を記録する。

| 項目 | 英語の文言の案 |
|---|---|
| 主文 | `` effects of `{function}` exceed `--allow-effects` `` |
| 主位置のラベル | `effect limit checked for this function` |
| note（不足） | `effects not allowed: {missing}` |
| note（許可） | `allowed effects: {allowed}` |
| help | `review the required effects before changing --allow-effects` |

集合の表示は正規名の辞書順、カンマと空白で区切り、空は `(none)` とする。型板は `diag::codes` に集め、CLI の使い方の文は `cli::text` に置く。値を埋める処理に英語の文を直書きしない。gen_skill の診断を同じ作業で生成する。

```json
{
  "kind":"check","severity":"error","code":"E0512",
  "message":"effects of `main` exceed `--allow-effects`",
  "primary":{"file":"main.bnt","start":{"line":2,"column":10,"offset":10},"end":{"line":2,"column":14,"offset":14},"label":"effect limit checked for this function"},
  "secondary":[],
  "notes":["effects not allowed: File.Write","allowed effects: Console.Write"],
  "helps":[{"message":"review the required effects before changing --allow-effects","edits":[]}]
}
```

`--diagnostics=json` ではこの形を標準エラー出力へ一行で書き、標準出力へ許可判定の JSON は書かない。E0512 は実行時エラーではなく検査の拒否であり終了状態は 2 である。

### run と test の所有と開始条件

run は検査成功後、同じ段の中で main の契約を抽出して比較し、通った場合だけその CheckedProgram を脱糖・コンパイルする。E0512 なら compilation は作らず返す。検査失敗や標準ソースの不具合が先にあれば、その診断を優先し不明な契約を比較しない。照合の後でソースを読み直さない。

上限を指定した test は、全入口の選択、検査、契約の比較、コンパイル、AssertTable と実行対象の原型の存在確認を済ませるまで一つもテストを始めない。通常の検査失敗は集め続ける。不足した関数は入口順・宣言順に E0512 を出す。その入口のコンパイルは省略してよいが、後の入口の検査を省いて全体成功にしてはならない。不具合・中断は止めてよい。

`Vec<(EntrySpec, Prepared)>` がコンパイル済みプログラム、ソース、テスト一覧、AssertTable を所有する。AST とコア IR は入口ごとの段の中で捨てる。全体成功後に Vec を順に消費して既存のテストごとの新しい RunEnv で動かす。再探索・再検査・再コンパイルをせず、各プログラムと比較済み契約を別のプログラムへ取り違えない。run_input の作成で処理系の不具合になりうる準備も、全体開始前に済ませる。通常の上限なし test はこの全保持を行わず、従来の逐次実行を保つ。

前後の入口で依存ファイルが変われば、各入口の成果物は異なる内容を持ちうる。その各成果物の契約を照合するが、全対象の一時点のスナップショットは保証しない。準備中の追加ファイルを途中から実行対象へ加えない。

### 一つも開始しなかった場合の形式（R1）

E0512・検査失敗・コンパイルの制限で全体を拒否し、探索が完了して N 個（N>0）の入口が分かっている場合、test の JSON Lines は kind:test を一行も出さず、既存の次の集計だけを標準出力へ書く。`filesNotRun` は失敗した入口数でなく、全体の拒否によって開始しなかった全入口数である。テストのない入口と明示パスの重複も入口として数える。通常の上限なし test の数え方は保つ。

```json
{"kind":"testSummary","passed":0,"failed":0,"filesNotRun":2,"interrupted":false}
```

診断は標準エラー出力、終了状態は 2 とする。文章の集計も既存の `files_not_run > 0` の規則で FAILED となる。件数の文言は `; {count} files not run` に変更し、従来の `due to errors` を外す（R9）。全体拒否では誤りのない入口や中断で開始しなかった入口も数えるためである。通常の上限なし test にも同じ中立的な文言を用い、件数と JSON は保つ。中断なら interrupted=true・130、不具合なら 3 とし、既知の対象で安全に集計を書ける境界では同じ非実行数を示す。

探索失敗、使い方の誤り、対象数を確定できない外側の不具合は集計を書かない。中断前に N が分からない場合も同様である。完全な成功の空の検査・テストだけが、終了状態 0 と `filesNotRun:0, interrupted:false` の 0/0 を返せる。`test --check` は元から集計行を出さない。件数を u32 に収められない場合に飽和させて偽の件数を返さず内部エラーにする。

これは Q9 の行の欄・型・意味を保ち、新しいオプションに対して「全体を開始しなかった」という既存の filesNotRun の値を定めるものである。形式 1 の変更は不要と判断する。受け手は passed/failed だけで成功を決めず、終了状態、filesNotRun、interrupted、集計行の有無を確認する。

実行が始まった後の test の終了状態は既存の優先順位（中断130、不具合3、検査拒否2、テスト失敗1、成功0）を保つ。run の Process.exit の指定値、die の状態1、通常の報告順も変えない。

## 段 4: 機能 5・6

### Command.environment の拒否

`builtins/funcs/process.rs::execute` の既存の NUL・空名・`=` の検査の直後に加える。ASCII の大小を区別せず `DYLD_` または `LD_` で始まる明示した変数名を探し、元の名前の辞書順で最初の一件を返す。値、親の環境は読まない。パスの絶対化、Command::new、spawn、パイプの仕事より前に完了する。

返すのは `io::ErrorKind::InvalidInput` から既存の `file::IoFailure` へ変換した失敗である。言語からは `Result.Error(IOError(kind=InvalidInput,...))` となり、値として処理できる。read_command の Stop にしない。新しい診断コード、CLI オプション、Command の欄は加えない。

message の案は `` environment variable `{name}` cannot be set in Command.environment: names starting with DYLD_ or LD_ are not accepted `` とし、process の text 子モジュールへ置く。拒否した名前だけを含め、値を出さない。通常の入力検査と禁止名の両方に違反すれば、既存の不正入力の診断を先にする。

run と runAttached は共通の execute を通るので両方に適用する。同じ値の再設定、空値、小文字の名前、`LD_RUN_PATH` のようなビルドの道具が読む変数も拒否する。親からの同名の変数はそのまま継承し、shell は明示 environment が空なので継承を続ける。Windows 含め入力規則は共通とし、Windows の DLL 探索を制御できる保証はしない。docs/todo の TODO-058 の継承・削除の API は加えない。

### skill list/show の CLI と形式

```text
benitoite skill list [--format=text|json]
benitoite skill show [--format=text|json] <logical-name>
```

format は `=` の形だけを受け、省略は text とする。show の論理名と format の順序は自由、余分な論理名や list の引数は拒否する。install/uninstall の scope/agent オプションを list/show に受け付けず、その逆も拒否する。未知の動詞・値・重複は既存の使い方の誤り（2）。不正な論理名の detail は `` invalid Skill document name `{name}` ``、未知名は `` unknown Skill document `{name}`; use `benitoite skill list` `` とする。JSON の失敗に空の成功文書を返さず、標準出力を空、説明を標準エラー出力とする。

`bundle::FILES` の論理名を唯一の一覧とし、`/` 区切りで大文字小文字を区別する。SKILL.md、references/stdlib/IO.File.md、LICENSE-MIT などすべての項目を含める。空名、先頭 `/`、空成分、`.`、`..`、バックスラッシュ、コロン（ドライブ指定を含む）を拒否し、一覧の完全一致以外は受けない。OS のパスに変換して開かず、HOME、作業ディレクトリ、インストール先を調べない。tools は新しい `skill::run_skill_cli(args, env)`（`pub(super)`）を呼ぶ。ここで共通の解析を行い、install/uninstall の分岐だけが HOME を取得する。公開の `run_skill(args, env, home)` は既存のシグネチャを保ち、共通の解析と実行の内部関数を呼び、渡された home を用いる（R6）。list/show はどちらの入口でも HOME を調べない。

非公開の `render_document(file: &SkillFile, version: &str) -> String` を install と show で共有し、SKILL.md の `{{benitoite-version}}` を処理系の版へ置換する。既存のほかの文書の置換の有無も install に合わせる。JSON の byteLength はこの UTF-8 本文のバイト数、contentHash は同じ本文の SHA-256 である。埋め込み一覧の重複・不正名は処理系の不具合（3）とし、一覧の一部だけを成功として返さない。

text の list は辞書順の名前を一行ずつ LF で終えて出す。text の show は本文だけを出し、末尾改行を補わない。JSON は単一オブジェクトに末尾 LF を付ける。出力失敗は 1、成功 0 である。producer と Hash は報告の共通定義と同じであり、null の文書や未置換の成功文書はない。

```json
{
  "schemaVersion":1,"kind":"skillList",
  "producer":{"name":"benitoite","version":"0.0.7","build":{"commit":null,"dirty":null,"target":"aarch64-apple-darwin","provenance":{"commit":"unknown","dirty":"notCollected"}}},
  "documents":[{"name":"LICENSE-MIT","byteLength":0,"contentHash":{"algorithm":"sha256","value":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"}}]
}
```

```json
{
  "schemaVersion":1,"kind":"skillDocument",
  "producer":{"name":"benitoite","version":"0.0.7","build":{"commit":null,"dirty":null,"target":"aarch64-apple-darwin","provenance":{"commit":"unknown","dirty":"notCollected"}}},
  "name":"LICENSE-MIT","byteLength":0,
  "contentHash":{"algorithm":"sha256","value":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
  "text":""
}
```

この二例は本文を空にした形式説明用の仮データである。実際の LICENSE-MIT は空ではなく、list は全埋め込み文書を返す。show と list と install の本文の一致を実際の文書で検査する。

## 段 5: 文書・移行・版・公開の整合

### 実装と同時に直す現行文書

各機能の契約は実装する作業で該当章へ反映し、文書専用の段では章間の漏れを照合する。未接続の記述を後まで残さない。章の追加・改名は予定しない。既存見出しを変える場合は参照と spec 印を検索して直す。

| 章・文書 | 反映する内容 |
|---|---|
| 02-01 pipeline、02-11 スクリプト実行と埋め込み | 段内での抽出と破棄、run の同じ成果物の照合、test の事前準備と全保持、上限なしの逐次実行 |
| 02-02 ソースと位置、02-10 diagnostics | 読んだ SourceTable の生バイトハッシュと表示パスの限界、E0512、診断形式1と報告中への埋め込み、報告内の usageError だけに現れる kind:check・code:null の例外（既存 JSON Lines は変更しない） |
| 03-07 IO modules | Command.environment の二接頭辞、ASCII 比較、InvalidInput、非起動、継承の限界 |
| 05-01 distribution | build.rs の採取・環境変数・アーカイブ・worktree・監視条件と検知の限界、形式の版とリリース版の区別 |
| 06-01 CLI | 全構文・組み合わせ・出力先の明示例外・終了状態と優先順位・formats・各 JSON の形 |
| 06-04 test runner | 非実行の検査、対象選択の共有、部分成功と全体の完全性、全体拒否の filesNotRun と集計なし |
| 06-06 Agent Skills | list/show、論理名・置換・JSON、確認前の検査報告と上限の利用。既存の「表示しない」記述を API と矛盾させない |
| 06-09 packages、01-03 names/modules | 0.0.7 の互換性の変更の登録、E0908、通常入力と依存の移行。CLI の JSON を01-specへ書かない |
| 07-01 security | 静的な上限比較と OS の隔離の区別、同じエフェクトの対象・内容は固定しないこと |
| 07-03 testing | build.rs の rust 分類を確認。新しい検査名は増やさず、既存の分類表と実態を照合 |
| 英語 `docs/reference/benitoite.md` | CLI の使用法、形式と終了状態、Assert.Check、ローダ制約、language 0.0.7 と移行参照 |
| 英語 `docs/reference/install.md` | 対象版、版の問い合わせ、ビルド情報の不明・明示指定、再インストールの説明 |
| Skill の SKILL.md・手書き references | 検査報告と上限を使う手順、実行の保証の限界、environment の失敗の直し方。placeholder と実例の版を区別 |
| gen_skill の生成元・生成物 | E0512 の diag::codes、Process の標準ソースの文書コメント、必要なら generate.rs の手書きテンプレート。references/grammar.md・diagnostics.md・stdlib/*.md と bundle.rs は生成し直す |
| `docs/ja/reference/`、`docs/ja/skill/` | 英語の正を変更し終えてから既存の六組を訳し直す。コードブロック・表・版・終了状態の意味を対照確認。訳を Skill の配布先へ入れない |
| CHANGELOG.md | 六機能、全 formats、E0512、全体拒否、環境の破壊的変更と移行手順 |

### 形式化の判定

07-04「01-12 との対応」は、構文・型の規則・脱糖を変える改造に対応表への記録を要求している。今回の CLI の静的集合の読み出し・包含比較は型付けの受理規則を変えず、環境入力の拒否も既存の Result[_, IOError] の値を変えるだけである。したがって表の追加は必須ではなく、07-04・01-12・formal/ を変更しないと判断する（R4）。対象外という判定と理由は本節と実装結果の記録へ残す。型表の生成や推論を変える実装に広がればこの判定を再利用せず、先に対応表と Lean の要否を見直す。

### E0908 の変更表と 0.0.7

`modules/package.rs::BREAKING_CHANGES` の末尾に Version(0,0,7) と `modules/text.rs` の次の型板を登録する。E0908 の既存の `declared < change <= current` の全件列挙と版順は保つ。

| 定数の案 | 文言の案 |
|---|---|
| `LOADER_ENVIRONMENT_CHANGE` | `Command.environment rejects names starting with DYLD_ or LD_ (ASCII case-insensitive), including build-tool variables such as LD_RUN_PATH` |
| `LOADER_ENVIRONMENT_MIGRATION` | `review explicit settings of DYLD_ and LD_ variables, including LD_RUN_PATH used by build tools; run and runAttached return IOErrorKind.InvalidInput before starting a child; inherited variables are unchanged; update the language declaration to the current version after reviewing the script, update dependency hashes, and see CHANGELOG.md for migration details` |

environment の拒否は E0908 そのものではない。E0908 は旧い language 宣言で意味の変更を見落とさせないための入口である。宣言なしの入力は現行規則で読み、旧宣言で制約を解除しない。純粋な入力でも `language "0.0.6"` は E0908 となる。0.0.7 は受理、将来の 0.0.8 などは E0907 とする。

版は最終段で一度だけ `crates/benitoite/Cargo.toml` とルート Cargo.lock の自身の項目を 0.0.7 へ上げる。同じ作業で通常入力、文書の言語宣言と公開版、依存パッケージの必須宣言、生成元と固定ハッシュを更新する。旧版・未来版・不正な版の負の検査、記法の検査、歴史資料は一律置換しない。未来版の検査が 0.0.7 を使っていれば 0.0.8 以上へ変え、意図を保つ。旧版の期待値は note/help を全文で更新し、assert を部分一致へ緩めない。

固定ハッシュは `testdata/packages/hash-match`、`modules/tests.rs`、`tests/package_command.rs` を少なくとも含めて全追跡ファイルを検索し、入力の編集から影響をたどる。正のハッシュは `modules/hash.rs` が定めるパッケージのアルゴリズムを独立した Python hashlib の計算で検算する。報告用の単一ソースの SHA-256 と混同しない。意図的な不一致のゼロのハッシュは残す。パッケージの更新操作の出力の期待値、同じ内容を持つ Rust の文字列、tools の参照解、Markdown の `benitoite test` fence も調べる。

CHANGELOG の先頭には M1 で `## Unreleased` を新設し、M2b の一度の版の更新で `## 0.0.7 (San Benito)` へ改める。LD_RUN_PATH を含む LD_ 全体を拒むこと、名前の大小を区別しないこと、明示的な同値上書き・空値も失敗すること、継承を変えないことを破壊的変更の表と移行手順に書く。共有ライブラリの設定だけに狭めて説明しない。六機能を全件照合し、公開 API の記載漏れを防ぐ。拒否した値を親の環境へ移す回避方法は勧めない。

### check.sh の分類と検査の分担

現行の `classify` は `crates/*` で rust を選ぶため、新しい `crates/benitoite/build.rs` と CLI のファイルは分類外にならない。`scripts/check.sh` の分類を変える必要はない。rust は fmt、二構成の clippy、mark-sweep の全テスト、gc-stress、規約の検索、Skill、spec coverage を含む。default_lib は自動では選ばれないので段末で名指しする。`cargo clippy --all-targets` と Cargo のビルドスクリプトの対象化を V1a で確かめる。

ビルド情報の独立した検査は `tests/build_info.rs` に置き、`#[ignore = "long: ..."]` を付ける。小さい一時 Cargo プロジェクトへ本番の build.rs をコピーし、同じスクリプトによる埋め込み値と増分ビルドを観測する。巨大な Benitoite を入れ子にビルドせず、ネットワークや実リポジトリの checkout を使わない。通常の rust 検査では ignore として見えるようにし、V1a/V1b と V2 の段末では `cargo test -p benitoite --test build_info -- --include-ignored` を明示して実施する。公開前 full の long でも走る。所要時間は未測定なので実施前に見積もって知らせる。

子の Cargo には毎回、一時ディレクトリ内の絶対パスを `--target-dir` で与える。親の `CARGO_TARGET_DIR` と `BENITOITE_BUILD_*` は子の環境から除き、必要な明示値だけをケースごとに設定する。Git の準備と build.rs が起動する Git には `GIT_CONFIG_GLOBAL=/dev/null`・`GIT_CONFIG_NOSYSTEM=1` を渡し、署名・hooks などの利用者設定を引き継がない。テスト用 repo の local 設定もテスト側で管理する。

Git 不在の条件では `/usr/bin` 全体を PATH から落とさない。Cargo/Rustc は固定ツールチェーンの実体の絶対パスで指定し、先頭の一時 PATH ディレクトリに採取失敗を返す git の代用品を置く。これは Git を利用できない条件の代用であり、OS の実行ファイル不在そのものを再現したとは扱わない。後続の PATH は保ち、cc とその下位のリンカ・SDK の道具を使えるようにする。この代用品が選ばれ、Git の採取が失敗してもリンクとビルドは成功することを観測する。親の PATH は変えない。

各作業は実施前に検査の名前を知らせ、dry-run の選択と理由を記録する。段末の `--only` でも `--dry-run` を先に行う。scripts/check.sh の `== stop:` が出たら該当ファイルとともに設計者へ選択を求め、推測で full を始めない。`--full`、long、heap を含む検査は事前に時間を見積もって知らせる。今回の設計作成ではこれらの処理系の検査を走らせない。

### ハーネスへの契約と残る危険

外部へ渡す契約は [harness-response.md](harness-response.md) にまとめ、実装中に引数・JSON・終了状態が変われば同時に直す。0.0.7 のタグは公開後に実在する値を伝える。今回の設計、後の実装完了、タグの作成、公開は別の状態であり、完了報告で混同しない。

ソースのハッシュとエフェクトの上限は、実行する中身を固定しない。同じ File.Write のまま書く先・内容が変わる場合、同じ Process.Run のまま shell の参照や起動先が変わる場合は拒めない。ハッシュ照合によるスナップショットの API は提供しない。Process.Run を許すと、env コマンドやシェルを通じてローダ変数を設定することもできる。Command.environment の拒否だけではそれを防げない。環境の継承、孫プロセス、PATH、外部関数、利用者が許した操作の対象は OS の隔離などに委ねる。

上限付き test の全保持は入口数に応じてメモリと開始前の時間を増やす。commit の自動採取には監視条件による検知の限界があり、dirty は明示しなければ不明となる。報告は標準ソースも繰り返して持つため大きくなる。これらの代償を誤って避けるために、検査やソースの項目を省略した成功、成果物の再読み込み、テストの時間制限の緩和へ替えない。
