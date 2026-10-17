# 実行前の検査

> この文書は、`crates/benitoite/skill/references/inspection.md` の日本語の訳である。翻訳元は Benitoite 0.0.7 の英語版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

修正中は通常の `benitoite check main.bnt` または非実行の `benitoite test --check tests/` を使い、診断を直す。検査を通ったら、確認の直前に JSON 報告を一度取得する。その報告を確認し、Skill の確認の規則に従って宣言したエフェクトを利用者に説明してから、了承済みの集合を実行へ渡す。

```sh
benitoite --version=json
benitoite check --report=json main.bnt
benitoite run --allow-effects=Console.Write,Process.Exit main.bnt
benitoite test --check --report=json tests/
benitoite test --allow-effects=Assert.Check,File.Read tests/
```

上の許す集合は例であり、実際のプログラムを見直した集合を使う。純粋な実行には `benitoite run --allow-effects= pure.bnt` と書く。オプションを省略するとエフェクト上限を掛けない。`run` のオプションはスクリプトのパスより前に置き、後続の引数はスクリプトに渡す。`test` のオプションはパスの後にも置ける。

版の問い合わせは後続の引数を受けず、`schemaVersion: 1`、`kind: "version"`、`name`、`version`、`unicodeVersion`、`build`、`formats`、`loaderEnvironment` を持つ一つの JSON オブジェクトを返す。リリース番号から対応機能を推測せず、必要な形式のキーと理解できる整数の版を要求する。現在の形式のキーは `version`、`diagnostics`、`testResults`、`checkReport`、`testCheckReport`、`effectLimit`、`loaderEnvironment`、`skillList`、`skillDocument` で、いずれも `[1]` を持つ。既存の診断とテスト結果の JSON Lines には、スキーマの欄や先頭の版の行を加えない。その形式には die の診断とテストの `failure.die` を含む。`effectLimit` はオプションとその診断の契約の版を表し、新しい出力オブジェクトではない。未知の形式・状態・エフェクトは未対応であり、成功や空集合として扱わない。

ビルドの欄は `commit`、`dirty`、`target`、`provenance: {commit, dirty}` である。コミットが不明なら `null`、dirty は真偽値または `null` であり、`null` は不明を表す。dirty は自動採取せず、ビルドの入力を省略した場合の由来は `notCollected` となる。ビルド時に明示した `BENITOITE_BUILD_COMMIT`（40 桁または 64 桁の完全な十六進 ID か `unknown`）と `BENITOITE_BUILD_DIRTY`（`true`、`false`、`unknown`）はそれぞれ独立に優先し、由来は `environment` となる。それ以外では、利用できる場合に Git でコミットを調べ、由来は `git` または `unknown` となる。target は Cargo から得る。実行時の環境変数の変更は、埋め込んだ情報を変えない。

コミットの自動採取では、存在する HEAD、ブランチの ref、packed-refs、HEAD の reflog のファイルを監視し、index や作業ファイルは監視しない。監視するファイル以外の変更は検知できない場合がある。必要なときは明示するビルドの入力を変えるか、パッケージを clean build して情報を再採取する。ビルドの commit と dirty の値は、ソース全体の同一性や実行ファイルの信頼性を証明しない。

二つの検査コマンドは、利用者の関数を実行せず、Benitoite のバイトコードを生成せず、VM を起動せずに検査する。ただし、コンパイル時の定数の評価と外部宣言の静的検査は行う。WASM のコンポーネントは検査のためにコンパイルすることがあるが、インスタンス化や呼び出しは行わない。検査報告は、後のコード生成がコンパイラの制限に収まることを証明しない。`check` は `main` を要求し、`test --check` は要求しない。テストの選択は実行する `test` と同じであり、選択された各入口で宣言されたテストだけを数え、取り込んだテストは数えない。直接指定したファイルは親を根とし、ディレクトリからの探索はそのディレクトリを共通の根として、`package.bnt` と入れ子のパッケージを飛ばし、ファイルの辞書順を使う。明示したパスの引数順と重複は保つ。

`--report=json` は `=` を必須とし、ほかの値を受けず、標準出力へ一つの UTF-8 の JSON オブジェクトと末尾の LF を書く。警告と認識した使い方の誤りを含め、診断はその中に入れ、標準エラー出力には重ねない。`--diagnostics=json` を加えても JSON Lines は増えず、明示した `--diagnostics=text` は報告モードと併用できない。報告を付けない `test --check` は、標準エラー出力に診断だけを書き、標準出力は空となる。`test --check` は、既定値の指定であっても、`--allow-effects`、`--max-call-stack`、すべての `--wasm-*` オプションを拒否する。`--check` のない `test --report=json`、および `run` や `fmt` での報告の指定は使い方の誤りとなる。

検査報告を確認済みの集合として使う前に、完全な単一の JSON オブジェクト、既知の `schemaVersion` と `kind`、`status: "ok"`、`complete: true`、終了状態 0 を要求する。各欄は次のように解釈する。

| 欄 | 意味 |
|---|---|
| `kind` | main では `checkReport`、テストでは `testCheckReport`。どちらも `schemaVersion: 1` を使う。 |
| `producer` | `{name, version, build}`。版の問い合わせと同じ値。 |
| `executed` | 常に `false`。利用者の関数を実行していない。 |
| `targetsComplete` | 入口の選択または探索が完了した。これだけでは検査の成功を意味しない。 |
| `requestedTargets`, `targets` | 指定したパスとその番号、および `targetId`、`requestIndex`、`entry`、`root`、`sourceId`、`kind`、`status`、`complete` を持つ選択された入口。 |
| 対象上の `main`, `tests` | main のシンボル・位置・エフェクト・shell 参照、または宣言順のテスト関数の名前・説明・位置・エフェクトの一覧。失敗した契約や未検査の契約は `null`。 |
| `aggregateEffects` | main の宣言したエフェクト、または選択された全テストの宣言したエフェクトの和。検査全体が完全でなければ `null`。 |
| `sources`, `sourceSets` | ソースの ID・表示用パス・種類・ハッシュと、対象ごとにまとめたソース ID。 |
| `diagnostics`, `diagnosticTargets` | 診断のオブジェクトと対象への対応。探索全体の誤りと使い方の誤りには対象がない。 |

Effects オブジェクトは `basis: "declaredUpperBound"` と `expanded` を持つ。`expanded` は、原子的な正規名を辞書順に並べた重複なしの配列である。本体の実行で到達するエフェクトだけでなく、使わない宣言も含む。`IO.All` は `Clock.Time`、`Console.Read`、`Console.Write`、`File.Read`、`File.Write`、`Process.Environment`、`Process.Exit`、`Process.Run`、`Random.Generate`、`State` に展開する。HTTP のエフェクトと `Assert.Check` は `IO.All` に含まれない。テストの契約・その和・許す集合には `Assert.Check` を残す。`main` では禁じる（E0415）。処理されない `or die` には `Process.Exit` が必要であり、完全に処理して宣言上限から取り除いた終了は含まれない。裸の `try` と `or return` は終了のエフェクトを加えない。

純粋な成功は `expanded: []`、不明なエフェクトは `[]` ではなく `null` である。検査したテストなしのファイルは `tests: []`、不明なテストの一覧は `null` となる。空ディレクトリは、対象がなく集計が空である完全な成功となる。失敗したファイルがあっても、ほかの成功した契約は残すが、全体の `complete` は false、集計は null となる。探索に失敗したらどの入口も検査せずに止まり、探索済みの入口は不完全な参考情報として残る。使い方の誤りには検査した対象もソースもない。その中の診断だけは、`kind: "check"` と `code: null` を使う。この組み合わせは、通常の診断の JSON Lines を拡張しない。テストの説明を省略した場合は `null`、明示的に空の説明を書いた場合は `""` となる。

`processShellReference` は `present`、`absent`、`unknown` のいずれかであり、`shellReferenceScope: "checkedProgram"` を伴う。main の契約内、またはテストの対象上に置き、個々のテスト関数には置かない。検査したプログラム全体にある標準の shell 関数の式の参照を対象とし、使わない関数、関数値、依存も含む。取り込み、コメント、文字列、ハンドラの操作名だけ、無関係な shell という名前の利用者の関数は数えない。到達性の解析ではない。`present` は呼び出しの証明ではなく、`absent` でも外部コマンドからシェルを起動できる。

ソースのハッシュは `{algorithm: "sha256", value: "<64 lowercase hexadecimal digits>"}` の形で、検査に使った元のバイト列全体を対象とする。BOM、元の改行、不正な UTF-8 も正規化せずに含める。ソースには設定・依存・埋め込みの prelude のソースを含めるが、WASM バイナリ、依存のハッシュの検証のためだけに読むファイル、存在しない設定、ディレクトリの観測、全バイト列を保持していないソースは含めない。ID は各報告内だけのもので、同じパスを繰り返しても別々に残す。表示用パスを OS のパスに常に戻せるとは限らない。これらのハッシュも検査報告も、後の実行に使うバイト列を固定しない。

検査は外部の関数の照合まで行う。検査報告の終了状態は `ok` なら 0、`checkError` または `usageError` なら 2、`internalError` なら 3、テストの検査で中断を観測したら 130 となる。`--deny-warnings` は警告を検査の誤りに昇格する。テストの検査は各ファイルの前に中断を確認するため、最後のファイルの検査中の要求は報告されない場合がある。main の検査は OS 既定のシグナル処理を保つ。テストの検査の状態は、中断、処理系の不具合、使い方の誤り、検査の誤りの順で優先する。書き込みや flush の失敗は 1 で終わり、出力が不完全な場合もある。初期化の失敗、abort、強制終了、報告の境界の外の失敗も、報告を返すとは限らない。不完全な応答を受理しない。

`--allow-effects` は、`State` と `Assert.Check` を含む原子的な正規名のカンマ区切りの集合を一回受け付ける。`--allow-effects=<names>` と `--allow-effects <names>` のどちらも使える。オプションや名前の重複、空要素、空白、未知の名前や利用者定義名、取り込みの別名、`IO.All`、`*` は使い方の誤りとなる。改めて検査した宣言上限は了承済みの集合に含まれなければならず、余分な許可はあってよい。先に生じた検査の誤りは比較より優先する。不足するエフェクトがあれば、違反する関数ごとに、不足するエフェクト・許す集合・位置を持つ E0512 を一つ出し、実行前に 2 で終わる。通常の診断は標準エラー出力に書き、`--diagnostics=json` では JSON Lines となる。

`run` は、上限を比較したものと同じ検査済みのプログラムを実行する。上限付き `test` は、すべての入口を準備・比較・コンパイルするまで、どのテストも開始しない。一つでも入口の準備に失敗すれば、一つも実行しない。探索が完了している場合、実行するテストの JSON Lines は `testSummary` だけを持ち、成功数と失敗数はゼロ、`filesNotRun` は開始しなかった全入口数（重複やテストなしのファイルも含む）、検査による拒否の `interrupted` は `false` となる。観測した中断は `interrupted: true` と終了状態 130、処理系の不具合は終了状態 3 を使う。探索・使い方の誤りや対象数が不明な外側の失敗では集計を書かない。成功数と失敗数だけでなく、終了状態、集計の有無、`filesNotRun`、`interrupted` を確かめる。実行するテストの終了状態は 130、3、2、1、0 の順で優先し、出力の失敗は 1 で終わる。非実行の検査は、テストの結果や集計の行を一切書かない。

エフェクト上限は静的な契約を比較するものであり、実行時の操作の制限や、意図した結果・停止性・IO の成功の保証はしない。同じ `File.Write` で別のパスや内容を書け、同じ `Process.Run` で別のコマンドを起動できる。準備中に異なるテストの入口が異なる依存の内容を読むこともあり、全入力のスナップショットの一貫性は保証しない。実際の操作とリソースの隔離はハーネスか OS で管理する。

文書をインストールせずに取得するには、次のようにする。

```sh
benitoite skill list --format=json
benitoite skill show --format=json references/stdlib/IO.Process.md
```

`list` は、`schemaVersion: 1`、`kind: "skillList"`、`producer`、および `{name, byteLength, contentHash}` を辞書順に並べた `documents` 配列を返す。`show` は、`schemaVersion: 1`、`kind: "skillDocument"`、`producer`、`name`、`byteLength`、`contentHash`、`text` を返す。長さは `SKILL.md` の版の置換後の UTF-8 バイト数を数え、SHA-256 のハッシュも同じバイト列を対象とする。`install` も同一の本文を書く。これらの問い合わせは埋め込みの文書を読み、`HOME`、作業ディレクトリ、インストール済みの写しを調べない。ライセンスを含め、名前は一覧と完全に一致し、`/` で区切った各成分は大文字小文字を区別する。空の名前、先頭の `/`、空成分、`.`、`..`、バックスラッシュ、コロンは不正であり、名前を OS のパスとして開くことはない。

既定の形式は text であり、`list` は一行に一つの名前、`show` は改行を追加せず文書だけを出す。JSON の問い合わせは一つのオブジェクトと末尾の LF を書く。`--format=text|json` は `=` を必須とし、一回だけ指定でき、show の名前の前後どちらにも置ける。`list` は名前を取らず、`show` は一つ要求する。これらの問い合わせはインストール用のオプションを拒否し、install/uninstall は `--format` を拒否する。成功は 0、不正な構文や未知の文書は 2 で終わる。これらの誤りでは JSON の問い合わせでも標準出力を空とし、標準エラー出力に説明を書く。処理系の不具合は 3、出力の失敗は 1 で終わる。出力がないことを空の文書と解釈しない。list と show が返す名前はすべて同じ規則を満たし、埋め込みの名前が不正または重複していれば、部分的な一覧ではなく処理系の不具合とする。
