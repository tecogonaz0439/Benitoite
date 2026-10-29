# 実行前の検査

> この文書は、`crates/benitoite/skill/references/inspection.md` の日本語の訳である。翻訳元は Benitoite 0.0.13 の英語版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

ハーネスは検査報告を使い、実行前に宣言したエフェクトを利用者へ説明する。編集中は通常の `benitoite check main.bnt` または実行しない `benitoite test --check tests/` を使い、診断を直す。検査を通ったら、確認の直前に一つの JSON 報告を得る。報告を調べ、Skill の確認の規則に従って宣言したエフェクトを利用者へ説明し、受理した集合を実行へ渡す。

```sh
benitoite --version=json
benitoite check --report=json main.bnt
benitoite run --allow-effects=Console.Write,Process.Exit main.bnt
benitoite test --check --report=json tests/
benitoite test --allow-effects=Assert.Check,File.Read tests/
```

上の許す集合は例であり、実際のプログラムを見直した集合を使う。純粋な実行には `benitoite run --allow-effects= pure.bnt` と書く。オプションを省略するとエフェクト上限を掛けない。`run` のオプションはスクリプトのパスより前に置き、後続の引数はスクリプトに渡す。`test` のオプションはパスの後にも置ける。

版の問い合わせは後続の引数を受けず、`schemaVersion: 1`、`kind: "version"`、`name`、`version`、`unicodeVersion`、`build`、`formats`、`loaderEnvironment` を持つ一つの JSON オブジェクトを返す。リリース番号から対応機能を推測せず、必要な形式のキーと理解できる整数の版を要求する。現在の形式のキーは `version`、`diagnostics`、`testResults`、`checkReport`、`testCheckReport`、`effectLimit`、`loaderEnvironment`、`skillList`、`skillDocument` で、testCheckReport と testResults は `[1,2]`、ほかは `[1]` を持つ。既存の診断とテスト結果の JSON Lines には、スキーマの欄や先頭の版の行を加えない。その形式には die の診断とテストの `failure.die` を含む。`effectLimit` はオプションとその診断の契約の版を表し、新しい出力オブジェクトではない。未知の形式・状態・エフェクトは未対応であり、成功や空集合として扱わない。

ビルドの欄は `commit`、`dirty`、`target`、`provenance: {commit, dirty}` である。コミットが不明なら `null`、dirty は真偽値または `null` であり、`null` は不明を表す。dirty は自動採取せず、ビルドの入力を省略した場合の由来は `notCollected` となる。ビルド時に明示した `BENITOITE_BUILD_COMMIT`（40 桁または 64 桁の完全な十六進 ID か `unknown`）と `BENITOITE_BUILD_DIRTY`（`true`、`false`、`unknown`）はそれぞれ独立に優先し、由来は `environment` となる。それ以外では、利用できる場合に Git でコミットを調べ、由来は `git` または `unknown` となる。target は Cargo から得る。実行時の環境変数の変更は、埋め込んだ情報を変えない。

コミットの自動採取では、存在する HEAD、ブランチの ref、packed-refs、HEAD の reflog のファイルを監視し、index や作業ファイルは監視しない。監視するファイル以外の変更は検知できない場合がある。必要なときは明示するビルドの入力を変えるか、パッケージを clean build して情報を再採取する。ビルドの commit と dirty の値は、ソース全体の同一性や実行ファイルの信頼性を証明しない。

二つの検査コマンドは、利用者の関数を実行せず、Benitoite のバイトコードを生成せず、VM を起動せずに検査する。ただし、コンパイル時の定数の評価と外部宣言の静的検査は行う。WASM のコンポーネントは検査のためにコンパイルすることがあるが、インスタンス化や呼び出しは行わない。検査報告は、後のコード生成がコンパイラの制限に収まることを証明しない。`check` は `main` を要求し、`test --check` は要求しない。テストの選択は実行する `test` と同じであり、選択された各入口で宣言されたテストだけを数え、取り込んだテストは数えない。直接指定したファイルは親を根とし、ディレクトリからの探索はそのディレクトリを共通の根として、`package.bnt` と入れ子のパッケージを飛ばし、ファイルの辞書順を使う。明示したパスの引数順と重複は保つ。

`--report=json` は `=` を必須とし、ほかの値を受けず、標準出力へ一つの UTF-8 の JSON オブジェクトと末尾の LF を書く。警告と認識した使い方の誤りを含め、診断はその中に入れ、標準エラー出力には重ねない。`--diagnostics=json` を加えても JSON Lines は増えず、明示した `--diagnostics=text` は報告モードと併用できない。報告を付けない `test --check` は、標準エラー出力に診断だけを書き、標準出力は空となる。`test --check` は、既定値の指定であっても、`--allow-effects`、`--max-call-stack`、すべての `--wasm-*` オプションを拒否する。`--check` のない `test --report=json`、および `run` や `fmt` での報告の指定は使い方の誤りとなる。

検査報告を確認済みの集合として使う前に、完全な単一の JSON オブジェクト、既知の `schemaVersion` と `kind`、`status: "ok"`、`complete: true`、終了状態 0 を要求する。各欄は次のように解釈する。

| 欄 | 意味 |
|---|---|
| `kind` | main では `checkReport`、テストでは `testCheckReport`。既定は `schemaVersion: 1`、test --doc は版 2 を使う。 |
| `producer` | `{name, version, build}`。版の問い合わせと同じ値。 |
| `executed` | 常に `false`。利用者の関数を実行していない。 |
| `targetsComplete` | 入口の選択または探索が完了した。これだけでは検査の成功を意味しない。 |
| `requestedTargets`, `targets` | 指定したパスとその番号、および `targetId`、`requestIndex`、`entry`、`root`、`sourceId`、`kind`、`status`、`complete` を持つ選択された入口。 |
| 対象上の `main`, `tests` | main のシンボル・位置・エフェクト・shell 参照、または宣言順のテスト関数の名前・説明・位置・エフェクトの一覧。失敗した契約や未検査の契約は `null`。 |
| `aggregateEffects` | main の宣言したエフェクト、または選択された全テストの宣言したエフェクトの和。検査全体が完全でなければ `null`。 |
| `sources`, `sourceSets` | ソースの ID・表示用パス・種類・ハッシュと、対象ごとにまとめたソース ID。 |
| `diagnostics`, `diagnosticTargets` | 診断のオブジェクトと対象への対応。探索全体の誤りと使い方の誤りには対象がない。 |
| 報告と各対象の `intervalAnalysis` | 後述の局所の区間解析の追加集計。`complete` や報告の受理と独立である。 |

Effects は任意の `bounds` 配列も持ち、その要素は `{name, scope}` である。`expanded` と同じ宣言上限を表し、`expanded` は引き続き範囲の構文を含まない名前の集合である。main、選択したテスト、文書の例、集計は同じ構造を使う。Top や未知の対象は `{kind: "all"}` であり、空配列ではない。既知の純粋な契約では、`expanded` と `bounds` の両配列が空になる。選んだ入口によらず、文書の `check` と `error` の例は、main や `@test` 関数にエフェクトを宣言していても、同じ空の Effects オブジェクトと `tests: []` を返す。この空の報告は、例の契約が純粋であることを意味しない。`check` と `error` の例は、実行の集計に加えない。

この実装は Effects オブジェクトを出力するときは常に `bounds` を含め、契約の解析が未完なら Effects を null にする。古い実装の報告など、`bounds` を持たない Effects は、`expanded` の各名前について、その種類のすべての対象を宣言しているものとして読む。この任意の情報は、既存の形式の版と報告の受理条件を保つ。完全に処理した利用者エフェクトが、上限や権限として再び現れることはない。追加の契約は処理系の[宣言した対象の上限](https://github.com/tecogonaz0439/Benitoite/blob/v0.0.13/docs/reference/benitoite.md#declared-target-bounds)、保証は[範囲付きのエフェクト](https://github.com/tecogonaz0439/Benitoite/blob/v0.0.13/docs/reference/benitoite.md#scoped-effects)で定める。

診断の注記は、宣言した上限とは別に検査した値の局所の由来を説明する。説明に挙げた利用者エフェクトを `expanded`、`bounds`、許可集合へ足したり、説明から上限を推論したりしない。ソース ID と内容のハッシュは検査したソースを識別するものであり、権限を追加せず、後の実行のソースを固定しない。

範囲の種類には、`path` を持つ `pathExact` と `pathTree`（ツリーの幹は `/**` を除く）、および `host` と `ports: {minimum, maximum}` を持つ `endpoint` がある。名前のホストには `kind: "exact"`、`"one"`、`"many"` と、ワイルドカードの接頭部を除いた `name` を使う。IP のホストには `kind: "exact"` または `"cidr"`、`family: "v4"` または `"v6"`、正規形の `address`、CIDR の `prefixLength` を使う。endpoint はホストとポートを制約し、HTTP と HTTPS の両方を含む。scheme、URL のパス、送信する内容は定めない。宣言した異なる原子は、ほかの原子に被覆されても `bounds` に残る。これらは静的に宣言した上限であり、推論した最小のエフェクト、実際の操作の観測、実行時の権限、情報フロー制御ではない。

Effects オブジェクトは `basis: "declaredUpperBound"` と `expanded` を持つ。`expanded` は、原子的な正規名を辞書順に並べた重複なしの配列である。本体の実行で到達するエフェクトだけでなく、使わない宣言も含む。`IO.All` は `Clock.Time`、`Console.Read`、`Console.Write`、`File.Read`、`File.Write`、`Process.Environment`、`Process.Exit`、`Process.Run`、`Random.Generate`、`State` に展開する。Log、HTTP のエフェクト、`Assert.Check` は `IO.All` に含まれない。Log は --allow-effects が受け付ける原子的な正規名である。無効なログのレベルから宣言上限の Log を取り除くことはない。テストの契約・その和・許す集合には `Assert.Check` を残す。`main` では禁じる（E0415）。処理されない `or die` には `Process.Exit` が必要であり、完全に処理して宣言上限から取り除いた終了は含まれない。裸の `try` と `or return` は終了のエフェクトを加えない。

純粋な成功は `expanded: []`、不明なエフェクトは `[]` ではなく `null` である。検査したテストなしのファイルは `tests: []`、不明なテストの一覧は `null` となる。空ディレクトリは、対象がなく集計が空である完全な成功となる。失敗したファイルがあっても、ほかの成功した契約は残すが、全体の `complete` は false、集計は null となる。探索に失敗したらどの入口も検査せずに止まり、探索済みの入口は不完全な参考情報として残る。使い方の誤りには検査した対象もソースもない。その中の診断だけは、`kind: "check"` と `code: null` を使う。この組み合わせは、通常の診断の JSON Lines を拡張しない。テストの説明を省略した場合は `null`、明示的に空の説明を書いた場合は `""` となる。

ファイル単位の `uses` は、検査済みの Scheme で個別の宣言と合併する。前述の規則で報告全体を受理した後、main では `targets[0].main.effects.expanded` と、存在すれば `bounds` を、テストでは選択した各テストのエフェクトとその集計を、宣言上限として示す。`bounds` がなければ、各名前を、そのすべての対象の上限として読む。空の本体にも共有の Console.Write や Log は残る。main のソースの行だけを読むと上限を見落としうる。報告を自動の許可に変えない。通常の `check` は標準出力に何も書かない。既存の必須欄と受理条件の正は処理系にあり、[v0.0.12 の英語リファレンス](https://github.com/tecogonaz0439/Benitoite/blob/v0.0.12/docs/reference/benitoite.md#inspection-reports)を参照する。checkReport 1・testCheckReport 1/2 を使う。上で参照した v0.0.13 のリファレンスは追加の上限を定める。旧版の固定参照は、既存の必須欄と受理条件だけに使う。後述の追加の `intervalAnalysis` 欄は、これらの版と規則を保つ。

未承認のエフェクトがファイルの宣言から加わった場合、E0512 はその位置も副ラベルに含める。共有の IO.All の W0501 は各関数と共有の由来を示し、ファイルの宣言への自動編集は付けない。個別の IO.All の編集はファイルが供給するエフェクトも考慮する。doc の例は独自の取り込みと契約を持ち、外側の宣言は適用しない。

`processShellReference` は `present`、`absent`、`unknown` のいずれかであり、`shellReferenceScope: "checkedProgram"` を伴う。main の契約内、またはテストの対象上に置き、個々のテスト関数には置かない。検査したプログラム全体にある標準の shell 関数の式の参照を対象とし、使わない関数、関数値、依存も含む。取り込み、コメント、文字列、ハンドラの操作名だけ、無関係な shell という名前の利用者の関数は数えない。到達性の解析ではない。`present` は呼び出しの証明ではなく、`absent` でも外部コマンドからシェルを起動できる。

ソースのハッシュは `{algorithm: "sha256", value: "<64 lowercase hexadecimal digits>"}` の形で、検査に使った元のバイト列全体を対象とする。BOM、元の改行、不正な UTF-8 も正規化せずに含める。ソースには設定・依存・埋め込みの prelude のソースを含めるが、WASM バイナリ、依存のハッシュの検証のためだけに読むファイル、存在しない設定、ディレクトリの観測、全バイト列を保持していないソースは含めない。ID は各報告内だけのもので、同じパスを繰り返しても別々に残す。表示用パスを OS のパスに常に戻せるとは限らない。これらのハッシュも検査報告も、後の実行に使うバイト列を固定しない。

検査は外部の関数の照合まで行う。検査報告の終了状態は `ok` なら 0、`checkError` または `usageError` なら 2、`internalError` なら 3、テストの検査で中断を観測したら 130 となる。`--deny-warnings` は警告を検査の誤りに昇格する。テストの検査は各ファイルの前に中断を確認するため、最後のファイルの検査中の要求は報告されない場合がある。main の検査は OS 既定のシグナル処理を保つ。テストの検査の状態は、中断、処理系の不具合、使い方の誤り、検査の誤りの順で優先する。書き込みや flush の失敗は 1 で終わり、出力が不完全な場合もある。初期化の失敗、abort、強制終了、報告の境界の外の失敗も、報告を返すとは限らない。不完全な応答を受理しない。

`--allow-effects` は、`State`、`Log`、`Assert.Check` を含む原子的な正規名のカンマ区切りの集合を一回受け付ける。`--allow-effects=<names>` と `--allow-effects <names>` のどちらも使える。オプションや名前の重複、空要素、空白、未知の名前や利用者定義名、取り込みの別名、`IO.All`、`*`、`File.Read["/data/**"]` などの範囲の引数は使い方の誤りとなる。許す各名前は、その名前の範囲付き原子も含め、その種類のすべての対象を許す。改めて検査した宣言上限は了承済みの集合に含まれなければならず、余分な許可はあってよい。先に生じた検査の誤りは比較より優先する。不足するエフェクトがあれば、違反する関数ごとに、不足するエフェクト・許す集合・位置を持つ E0512 を一つ出し、実行前に 2 で終わる。通常の診断は標準エラー出力に書き、`--diagnostics=json` では JSON Lines となる。

`run` は、上限を比較したものと同じ検査済みのプログラムを実行する。上限付き `test` は、すべての入口を準備・比較・コンパイルするまで、どのテストも開始しない。一つでも入口の準備に失敗すれば、一つも実行しない。探索が完了している場合、実行するテストの JSON Lines は `testSummary` だけを持ち、成功数と失敗数はゼロ、`filesNotRun` は開始しなかった全入口数（重複やテストなしのファイルも含む）、検査による拒否の `interrupted` は `false` となる。観測した中断は `interrupted: true` と終了状態 130、処理系の不具合は終了状態 3 を使う。探索・使い方の誤りや対象数が不明な外側の失敗では集計を書かない。成功数と失敗数だけでなく、終了状態、集計の有無、`filesNotRun`、`interrupted` を確かめる。実行するテストの終了状態は 130、3、2、1、0 の順で優先し、出力の失敗は 1 で終わる。非実行の検査は、テストの結果や集計の行を一切書かない。

エフェクト上限は静的な契約を比較するものであり、実行時の操作の制限や、意図した結果・停止性・IO の成功の保証はしない。同じ `File.Write` で別のパスや内容を書け、同じ `Process.Run` で別のコマンドを起動できる。準備中に異なるテストの入口が異なる依存の内容を読むこともあり、全入力のスナップショットの一貫性は保証しない。実際の操作とリソースの隔離はハーネスか OS で管理する。

文書をインストールせずに取得するには、次のようにする。

```sh
benitoite skill list --format=json
benitoite skill show --format=json references/stdlib/IO.Process.md
```

`list` は、`schemaVersion: 1`、`kind: "skillList"`、`producer`、および `{name, byteLength, contentHash}` を辞書順に並べた `documents` 配列を返す。`show` は、`schemaVersion: 1`、`kind: "skillDocument"`、`producer`、`name`、`byteLength`、`contentHash`、`text` を返す。長さは `SKILL.md` の版の置換後の UTF-8 バイト数を数え、SHA-256 のハッシュも同じバイト列を対象とする。`install` も同一の本文を書く。これらの問い合わせは埋め込みの文書を読み、`HOME`、作業ディレクトリ、インストール済みの写しを調べない。ライセンスを含め、名前は一覧と完全に一致し、`/` で区切った各成分は大文字小文字を区別する。空の名前、先頭の `/`、空成分、`.`、`..`、バックスラッシュ、コロンは不正であり、名前を OS のパスとして開くことはない。

既定の形式は text であり、`list` は一行に一つの名前、`show` は改行を追加せず文書だけを出す。JSON の問い合わせは一つのオブジェクトと末尾の LF を書く。`--format=text|json` は `=` を必須とし、一回だけ指定でき、show の名前の前後どちらにも置ける。`list` は名前を取らず、`show` は一つ要求する。これらの問い合わせはインストール用のオプションを拒否し、install/uninstall は `--format` を拒否する。成功は 0、不正な構文や未知の文書は 2 で終わる。これらの誤りでは JSON の問い合わせでも標準出力を空とし、標準エラー出力に説明を書く。処理系の不具合は 3、出力の失敗は 1 で終わる。出力がないことを空の文書と解釈しない。list と show が返す名前はすべて同じ規則を満たし、埋め込みの名前が不正または重複していれば、部分的な一覧ではなく処理系の不具合とする。


## 局所の区間解析

報告と各対象は、`basis: "localIntervals"` を持つ追加の `intervalAnalysis` オブジェクトを含む。局所の区間解析が対象とした範囲を示す。`complete` は引き続き型とエフェクトの検査と契約の抽出を表す。ハーネスは前述の報告の受理条件を保ち、`coverage` を受理条件に加えない。`complete: true` と `coverage: "some"`、または `complete: false` と `coverage: "all"` が同じ報告に現れることもある。警告がなく `all` でも安全とは限らず、実行時の検査は引き続き必要である。

ほかの受理条件を満たした検査に `coverage: "all"` を要求せず、失敗した検査を `all` によって受理しない。未知の値や未対応・未完の範囲は、この解析の限界として説明する。こうした限界は検査の誤りを加えず、それ自体を理由にコードの変更やエフェクトの宣言の拡大を求めるものでもない。診断は別に読む。局所の解析の注記を持つ W0401/W0402/W0404 は、報告した位置での条件付きの失敗を示し、プログラム全体の失敗は示さない。例、Range の成功値、追跡しない HTTP のフィールドは、[局所の区間解析の警告を説明する](idioms.md#局所の区間解析の警告を説明する)を参照する。

| `intervalAnalysis` の欄 | 意味 |
|---|---|
| `coverage` | 未対応・未完の範囲も無効な本体もなければ `all`。解析を開始したがそうした範囲が残る場合は `some` であり、有効な本体と無効な本体の混在も含む。解析前は `none` であり、型検査前の失敗や、一つ以上ある本体がすべて型検査で無効になった対象も含む。本体を一つも持たない検査済みの対象は、件数 0 の `all`。 |
| `inputDefinitions` | 型検査を通り、解析に渡した元定義の数。別に解析するラムダ・lazy・節の本体は加算しない。 |
| `unsupportedBodies` | 親または保存した独立入力に未対応の構文を含む本体出力の数。停止した出力も含め、各本体出力を一度だけ数える。 |
| `bodyBudgetExceeded` | 通常の本体予算の超過で停止した本体出力の数。番号未取得に分類した停止は除く。 |
| `wholeBudgetSkipped` | 検査全体の予算で未解析になった範囲の数。停止した出力、発見済みで保留中の本体、残る有効な元定義、発見や制御が未完の元定義を数える。未発見の入れ子の本体数は推計しない。 |
| `unidentifiedBodies` | 番号を付ける間に予算超過で停止した本体出力の数。本体と検査全体のどちらの上限による停止も含む。ほかの原因で番号が得られない停止は数えない。 |
| `phaseStops` | 入口の準備、発見、待ち行列、入れ子の本体の制御、検査全体の制御での停止事象。`exceeded` と `unidentified` はそれぞれ `bodyOperations`、`bodyItems`、`wholeOperations`、`wholeItems` を含む。`depth` と `other` は残る停止の種類を数える。事象の数であり、未解析の本体数ではない。 |
| `usage` | `operations`、`savedItems`、`peakItems`、`maxBodyOperations`、`maxBodyItems`。消費した操作数、保持する項目数、同時保持項目数の最大値、本体の操作数の最大値、本体の同時保持項目数の最大値を表す。解析予算の単位であり、確保したバイト数ではない。 |

件数と使用量は非負の JSON 整数である。本体出力を持たない入口・制御の停止は、`bodyBudgetExceeded` や `unidentifiedBodies` ではなく `phaseStops` に現れる。`wholeBudgetSkipped` は、同じ元定義の不完全な範囲を制御の停止ごとに重ねて数えず、番号未取得の出力を通常の超過にも加算しない。四つの本体・範囲の件数は、`inputDefinitions` を分割した数とは限らない。入れ子の本体は別の出力であり、停止した出力に未対応の構文も含まれうるためである。

`some` は、本体や段の停止、残る元入力、未準備の入口、未完の発見や待ち行列、発見済みで保留中の本体を含む。件数が 0 であることだけでは `all` と判断できない。テストの報告では、重複した入口も別々の検査として対象間の件数を合計する。すべての対象が `none` なら coverage は `none`、それ以外で `all` でない対象があれば `some`、残りは `all` になる。空の探索が成功すれば件数 0 の `all`、使い方や探索の失敗は `none` である。

main では、報告の集計と対象の集計は等しい。doc テストでは、各対象に通常の入口と、check/error を含むすべての生成した例を合わせる。例の探索が未完なら未検査の範囲が残る。check/error の例が実行のエフェクトに加わることはない。使用量の集計は `operations` と `savedItems` を合計し、`peakItems`、`maxBodyOperations`、`maxBodyItems` の最大値をとる。本体ごとの最大値は、出力を保存した本体だけを対象にする。元定義には入口、親の解析、発見、待ち行列の仕事量を含める。出力のない段停止で消費した量も、全体の使用量には残る。

`--deny-warnings` が警告を誤りにして検査を失敗させても、解析の集計は残る。無関係な定義の追加で検査全体の予算を使い切ると、後の区間の警告がなくなり、`--deny-warnings` での受理が変わりうる。既存の定数の警告と、既に得た区間の警告は残る。ハーネスは未対応や未解析の範囲を安全と説明しない。追加の集計は、main・通常のテストのスキーマの版 1、doc テストの版 2、既存の必須欄、状態、エフェクト報告の受理条件を保つ。

追加の欄と集計について処理系が定める内容は、[v0.0.12 の英語リファレンス](https://github.com/tecogonaz0439/Benitoite/blob/v0.0.12/docs/reference/benitoite.md#interval-analysis-coverage)を参照する。[局所の警告の規則](https://github.com/tecogonaz0439/Benitoite/blob/v0.0.12/docs/reference/benitoite.md#local-interval-warnings)は解析の範囲を定める。インストールした版の文書は、実行ファイルに埋め込んだ Skill から得られる。


文書の例には、検査と実行の両方に --doc を付ける。`benitoite test --doc --check --report=json tests/` を使い、その後 `benitoite test --doc --allow-effects=<了承した集合> tests/` を実行する。版の問い合わせで testCheckReport と testResults の版 2 を要求する。--doc を省略すると版 1 になる。未知の JSON Lines の種類を、版 1 の成功として無視しない。

版 2 は Target.tests を保ち、docExamples と ignoredDocBlocks を加える。例には自分自身の import と uses を書き、公開 API の境界を検査する。モードは test/check/error/run である。集計するエフェクトは通常のテストと実行する test/run の例だけで、check/error は実行の許可を加えない。期待した静的拒否は observedDiagnostics を持つ成功した error 例であり、最上位の診断の失敗ではない。不明なエフェクトとテストは null、成功した空の値は空配列とする。想定外の拒否や診断の不一致は検査を不完全にする。--check は main を実行せず、出力を検証しない。

実行前に、実行する全例の準備と許す集合の照合を終える。実行は docExample 行、発見したモード別の数と ignoredBlocks を持つ docSummary、最終の testSummary を出力する。最終集計は通常のテスト関数と完了した例を数え、複数の @test を含む例も一件と数える。取り込んだ文書や標準文書は再帰的に集めない。各例は独立した状態と空の標準入力で実行する。

Log は正規の原子的エフェクト名であり、--allow-effects に指定できる。IO.All、Console.Write、HTTP のどれにも含まれない。無効なログのレベルから宣言上限の Log を取り除くことはない。完全なハンドラで処理した後も、宣言した上限に従って許可を照合する。
