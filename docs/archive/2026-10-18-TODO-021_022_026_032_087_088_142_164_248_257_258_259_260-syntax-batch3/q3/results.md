# Q3: 0.0.9 公開候補の release 手動照合（再実施）

2026-10-19、Codexが計画の「releaseの手動照合」の五項目を最初から実施した。**五項目とも一致**と判定した。保存例の読み替えと補助入力の修正は後述する。候補の処理系・標準ソース・文書・Skillは変更していない。自動のrelease検査は本作業の対象外であり、公開の受け入れ判断は設計者に渡す。

## 候補・基準・記録の読み方

- 開始時のブランチは `mod009/Q3`。`git rev-parse HEAD san_benito`（終了0）の両方が `92120a2f3aa6cc7c7aeb7044341fe0a23da3f921` であった。この完全IDを候補とする。
- 開始時の `git status --short` は終了0・出力なし。実CLI・生成の照合を終え、記録を書き始める直前も出力なしであった。
- `$REPO` = `/Users/tecogonaz/src/Benitoite`、`$CLI` = `$REPO/target/release/benitoite`、`$TMP` = `/private/tmp/benitoite-q3-redo-c3d5eix9`、`$I` = `$TMP/inputs`、`$A` = `$TMP/archive` とする。実CLIの作業ディレクトリは原則 `$I`。
- `$TOOL` = `python3 -B $REPO/tools/derive/derive.py`。`$D` = `$TMP/derive-examples`、`$C` = `$D/derive.json`、`$M` = `$TMP/review/manifest.json`。生成コマンドの共通引数 `--root $D --config $C` は表中で「共通引数」と略記する。
- `cargo build --release -p benitoite` は既定機能、終了0（Cargo表示39.10秒）。生成readerとformatterの準備の `cargo build -p benitoite --example derive_inventory --bin benitoite` も終了0（Cargo表示8.90秒）。この二コマンドの外側の時間は計時していない。その他のCLI・生成操作の外側の時間は証拠に保存した。
- [evidence.json](evidence.json) に各コマンドの完全なargv・実行場所・終了状態・外側の時間・stdout/stderrと、入力、補助手順、manifest、生成差分、生成記録を保存した。表の複数ファイルの指定は、それぞれを独立に呼んだコマンドの組である。原則として代表例はdesign.md第15節から抽出し、独立した例を別ファイルにした。過去のV1/G4や一度目のQ3の成功を引用して代用していない。

## 1. 版・language・doctestの報告形式

| コマンド | 終了状態 | 見た出力の要点 | 判定 |
|---|---:|---|---|
| `$CLI --version=json` | 0 | version=0.0.9、commit=候補の完全ID、target=aarch64-apple-darwin。dirty=null、provenance.dirty=notCollected。formatsのtestCheckReport/testResultsは[1,2]、ほかは[1]。完全な出力は末尾 | 一致 |
| `$CLI check $I/lang-0.0.9.bnt` | 0 | `language "0.0.9"` を受理 | 一致 |
| `$CLI check $I/lang-0.0.8.bnt` | 2 | E0908。Regex E0457/E0458、Scope E0459〜E0462、動的な引数でResult.Errorを試す方法、language・依存ハッシュの更新とCHANGELOGを案内 | 一致 |
| `$CLI check $I/lang-0.0.10.bnt` | 2 | E0907。必要版0.0.10と実行版0.0.9を表示 | 一致 |
| `$CLI check $I/lang-0.0.x.bnt` | 2 | E0905。三つの数をピリオドで区切る形式を案内 | 一致 |
| `$CLI test --check --report=json $I/scope.bnt` | 0 | testCheckReport、schemaVersion=1。通常Target.tests、complete=true、executed=false | 一致（R109の通常版1） |
| `$CLI test --doc --check --report=json $I/docs.bnt` | 0 | schemaVersion=2。通常testsは空、docExamplesはtest/errorの二件。期待E0401を例内observedDiagnosticsへ保存し、全体diagnosticsは空。元location・仮想sourceId・sources/sourceSetsあり | 一致（R109の版2） |
| `$CLI test --doc --check --report=json $I/doc-four.bnt`（補助入力修正後） | 0 | 通常@test一件、test/check/error/runの四例。test例内の@testは二件。各例にid/mode/location/sourceId/status/complete/effects/tests/expectedDiagnosticCodes/observedDiagnosticsあり。成功した空配列は[]。全体complete=true。check例のStateは実行権限へ足さず、aggregateEffectsはAssert.CheckとConsole.Write | 一致 |
| `$CLI test --doc --diagnostics=json $I/docs.bnt` | 0 | docExample二行→docSummary→最後にtestSummary。passed=2、failed=0。JSON LinesへschemaVersion・開始行を追加しない | 一致 |
| `$CLI test --doc --diagnostics=json --allow-effects=Assert.Check,Console.Write $I/doc-four.bnt` | 0 | 通常test一件とdocExample四件。docSummaryは各モード一件、最後のtestSummaryはpassed=5。複数@testの例を一例と数える。stdout/stderr/failure/testsあり | 一致 |
| `$CLI test --diagnostics=json $I/scope.bnt` | 0 | 従来のtest→testSummaryだけ。docの行を追加しない | 一致（通常版1） |
| `$CLI test --report=json $I/scope.bnt` | 2 | --checkなしをusageErrorとして拒否、complete=false、aggregateEffects=null。実行なし | 一致 |

`dirty:null`はcleanの表明ではない。作業ツリーのcleanはGitの実測で確認した。版2の補助入力に誤ったimportを書いたときの報告でも、未確定のeffects/testsがnull、例・対象・全体complete=false、diagnosticTargetsがdocExampleIdと対象を指すことを観察した。補助入力を直した成功報告と区別して証拠に残した。

## 2. 実CLI・保存した代表例・権限・Skill

| コマンド | 終了状態 | 見た出力の要点 | 判定 |
|---|---:|---|---|
| `$CLI check $I/small.bnt`、`$CLI run $I/small.bnt` | 各0 | 15.10の小さな関数を検査・実行できる | 一致 |
| `$CLI test --check $I/scope.bnt` | 0 | 実行結果を出さず検査成功 | 一致 |
| `$CLI test $I/scope.bnt`、`$I/endpoint.bnt` | 各0 | 各一件成功。ホスト小文字化・保持したpattern・パス境界・Endpoint・動的Error | 一致（15.1） |
| `$CLI test $I/scope-{pattern,target,outside,path}.bnt` | 各2 | 順にE0459/E0460/E0462/E0462。pathは後述の読み替え後の独立した呼び出し | 一致 |
| `$CLI test $I/endpoint-{bounds,port,outside}.bnt` | 各2 | 順にE0461/E0461/E0462 | 一致 |
| `$CLI test $I/positive-public.bnt` | 0 | `Option[Positive.Positive]`、公開make/valueを使った一件が成功 | 一致 |
| `$CLI test $I/opaque-{scope,construct,update,accessor,pattern}.bnt` | 各2 | 宣言元外の構築・更新・自動アクセサ・レコードパターンをE0340で拒否 | 一致 |
| `$CLI test $I/range.bnt` | 0 | 上端の成功、逆転のInvalidBounds、範囲外のOutOfRangeを通常のResultとして照合、一件成功 | 一致（15.2） |
| `$CLI test $I/edges.bnt` | 0 | Scopeの頂点拒否、**の一段/多段、四数字ラベル拒否、localhost、/**と根、..拒否。RangeのInteger両端・一点区間・端点取得と再検査、一件成功 | 一致 |
| `$CLI test $I/range-{construct,update,accessor,pattern}.bnt` | 各2 | 不透明なCheckedIntegerの外部利用をE0340で拒否 | 一致 |
| `$CLI test $I/regex.bnt` | 0 | constの結合を受理、動的な`"["`はResult.Error、一件成功 | 一致（修正済み15.3） |
| `$CLI test $I/regex-invalid.bnt`、`$I/regex-const.bnt` | 各2 | 順にE0457、E0433 | 一致 |
| `$CLI check $I/regex-limit.bnt` | 2 | E0458、実行時のコンパイル上限10485760 bytes | 一致 |
| `$CLI test --check --report=json $I/regex-const-location.bnt` | 2 | E0457の一次位置は6行24列の引数stem、補助位置は3行7列のconst | 一致 |
| `$CLI test $I/monad2.bnt` | 0 | 上位Functor2経由のtwiceでOk(6)/Error("bad")、一件成功 | 一致（15.4） |
| `$CLI test $I/monad2-wrong.bnt`、`$I/monad2-arity.bnt` | 各2 | Xの不一致E0401、一引数Monadへの二引数FはE0427 | 一致 |
| `$CLI test $I/builders.bnt` | 0 | Stringのcopy前後の独立、List、Bytesの結果4142、一件成功 | 一致（15.5） |
| `$CLI test $I/builder-{alias,capture,method,partial,annotation,effect}.bnt` | 各2 | E0464/E0465/E0466/E0466/E0463/E0501 | 一致 |
| `$CLI test --allow-effects=State,Assert.Check $I/builders.bnt` | 0 | 一件成功 | 一致 |
| `$CLI test --allow-effects=Assert.Check $I/builders.bnt` | 2 | E0512、0 passed、0 failed、1 files not run。builderExampleを実行しない | 一致 |
| `$CLI test $I/docs.bnt` | 0 | 通常testはdoc例を実行せず0 passed | 一致（15.6） |
| `$CLI test --doc $I/docs.bnt`、`test --doc --check $I/docs.bnt` | 各0 | 実行時は二例成功。--checkは実行結果行なし | 一致 |
| `$CLI test --doc $I/doc-missing.bnt` | 2 | diagnosticフェンスの欠落E0260 | 一致 |
| `$CLI test --doc $I/doc-mismatch.bnt` | 1 | 期待E0402に替えたerror例だけ失敗。test例は成功、後続の集計まで出る | 一致 |
| `$CLI test --doc --check --report=json $I/doc-unicode.bnt` | 0 | 期待E0401の位置は元コメント9行14〜18列。offsetで切った元UTF-8バイト列が`"誤り"`と一致 | 一致 |
| `$CLI test --doc --check $I/doc-private.bnt`、`$I/doc-opaque.bnt` | 各2 | private暗黙参照はE0301、外部opaque構築はE0340。元コメントへ位置を戻す | 一致 |
| `$CLI test --doc --check $I/doc-false.bnt`、`test --doc $I/doc-false.bnt` | 0 / 1 | Assertの期待を意図的に違えた補助例は--checkで実行せず、実行時に失敗する | 一致 |
| `$CLI test --doc --diagnostics=json --allow-effects=Assert.Check $I/doc-four.bnt` | 2 | 後続run例のConsole.WriteをE0512で拒否。通常test/docExampleの結果行はなく、最後は0 passed/0 failed/1 files not run。前の例も未実行 | 一致 |
| `$CLI run --allow-effects=Console.Write $I/console.bnt`、`run --allow-effects= $I/console.bnt` | 0 / 2 | 許可時だけreadyを出力。不足時はE0512で出力なし | 一致 |
| `$CLI test $I/failure.bnt` | 0 | toResultでError("bad")を取得、一件成功 | 一致（15.7） |
| `$CLI check $I/fail-main.bnt`、`test $I/fail-test.bnt` | 各2 | E0506。handleとFailure.toResultの両help | 一致 |
| `$CLI check $I/log-unhandled.bnt`、`run $I/log-reference.bnt`、`run $I/log-reference-ja.bnt` | 2 / 0 / 0 | 一般LogのE0506にはhandleだけ、toResultなし。英語11節のLog例は `log: items: 3` と `total: 500`。日本語11節も実CLIで同じ出力 | 一致 |
| `$CLI check $I/small-wrong.bnt` | 2 | 15.10のreturnをStringへ替えた拒否はE0401、3行10列 | 一致 |
| `$CLI test $I/higher.bnt`、`$I/higher-result.bnt` | 各0 | 前者は関数の検査（0テスト）。後者はsuccessful()=3を実行し一件成功 | 一致 |
| `$CLI skill list --format=json` | 0 | skillList版1、producer.version=0.0.9、70文書 | 一致 |
| `$CLI skill show --format=json SKILL.md`ほか一覧の全70名 | 全て0 | 実埋め込み文書と候補の実ファイルが一致。詳細は第4項 | 一致 |

## 3. 生成の往復・拒否と復旧・Show/Order・Property

`tools/derive/examples`を`$TMP`へ複写して使用した。リポジトリの例を編集していない。具体的な差分を得るため、複写した設定のAddressのJSONキーをcity→townにした。previewの差分はAddressのencodeのField/キー、decodeField、rejectExtraだけであり、型・欄名city・Property・Show/Orderは保たれていた。新記録の設定・出力ハッシュの変更と、版2/inventory2/hash2/generatorVersionを確認してから次のツール呼び出しでapplyした。実行入力fixtureのキーを新設定に合わせる必要があった経緯は後述する。

| コマンド | 終了状態 | 見た出力の要点 | 判定 |
|---|---:|---|---|
| `$TOOL check`＋共通引数（設定変更前） | 0 | 候補の生成本文と生成記録が一致 | 一致 |
| `$TOOL preview`＋共通引数＋`--out $TMP/review` | 0 | Address.bntの具体的な差分と版2の新記録を出力。manifestのSHA-256=`d11d7864aa8ce6007001fb1fb1a7a607612af40ff576e4d35b53aa8cb6e9f660` | 一致 |
| `$TOOL apply`＋共通引数＋`--manifest $M --manifest-sha256 d11d7864aa8ce6007001fb1fb1a7a607612af40ff576e4d35b53aa8cb6e9f660` | 0 | applied 1 source file(s)。receiptあり | 一致 |
| `$CLI check $D/People.bnt`、`test $D/People.bnt`（fixture修正後）、`$TOOL check`＋共通引数 | 各0 | 通常check成功、jsonRoundtrip/generatedJsonRoundtripの二件成功、generated regions and records match。fixture修正後にも通常checkを実施 | 一致 |
| `$TOOL preview`＋共通引数＋`--out $TMP/review-second` | 0 | changes.diffは0 bytes、提案した記録は現生成記録とバイト一致 | 一致 |
| `$TOOL apply`＋共通引数＋`--manifest $TMP/old-manifest.json --manifest-sha256 <当該実ファイルのSHA-256>` | 1 | version=1にした拒否確認用manifest。正確なハッシュでもderive.incompatible_manifest。旧承認を流用しない | 一致 |
| `$TOOL check`＋共通引数、`preview`＋共通引数＋`--out $TMP/review-modified`（本文一文字改変） | 各1 | derive.modified_region、Address.addressの管理領域を指定。本文を上書きしない | 一致 |
| 正確な元バイトへ復旧後の`$TOOL check`＋共通引数 | 0 | generated regions and records match | 一致 |
| `$TOOL preview --root $TMP/traits --config $TMP/traits/derive.json --out $TMP/traits-review` | 0 | 15.8のPersonに通常のShow/Orderを生成。name→ageの欄順、StringのShow、後続比較はEqual後だけ。manifest SHA-256=`8ad80d5ffc3220df98bb23bb81cfd36e295bad2052e00f461f32f560f7d2fb3b` | 一致 |
| `$TOOL apply --root $TMP/traits --config $TMP/traits/derive.json --manifest $TMP/traits-review/manifest.json --manifest-sha256 8ad80d5ffc3220df98bb23bb81cfd36e295bad2052e00f461f32f560f7d2fb3b` | 0 | 確認済みハッシュで一ファイル適用 | 一致 |
| `$CLI test $TMP/traits/Traits.bnt`、traitsの`$TOOL check` | 各0 | Showは`Person(name: "Ada", age: 7)`、Orderはage差のLess・同値Equal・name先行のGreater。一件成功、生成記録一致 | 一致 |
| 同じtraits manifest・同じSHA-256で再apply | 0 | already applied; inputs match receipt | 一致 |
| 未変更の別コピー`$TMP/derive-original`で`$CLI check People.bnt`、`test People.bnt`、`$TOOL check --root ... --config .../derive.json` | 各0 | 候補そのままの二件成功と生成記録一致。変更したfixtureの成功だけで代用しない | 一致 |
| `$TMP/derive-migration`の旧版記録確認入力で`$TOOL check --root ... --config .../derive.json` | 1 | derive.migration_required | 一致 |
| 同入力で`$TOOL preview ... --out $TMP/migration-review` | 0 | previousRecordを保持、semanticHashesComparable=false。記録だけの差分でソース差分は空、提案記録は候補の版2記録と一致 | 一致 |
| 同入力の本文一文字改変で`preview ... --out $TMP/migration-modified` | 1 | 移行前でもderive.modified_region。旧outputSha256の照合を省かない | 一致 |
| 本文復旧後、`apply ... --manifest $TMP/migration-review/manifest.json --manifest-sha256 5ac5d3517e50d4fd92a266f98b97640832c48b120b8c9906c7836d482ba73f70`、通常check/test、derive check | 全て0 | 確認した新manifestで記録だけを移行（applied 0 source file(s)）、二テスト成功、生成記録一致 | 一致 |
| `$CLI test $I/property.bnt` | 0 | 15.11の失敗Resultの期待、一件成功 | 一致 |
| `$CLI test $I/property-replay.bnt` | 0 | 仕事予算0/1/1000、負数のInvalidConfig、maxShrinks=1の上限、同一configで同じCounterexample、一件成功 | 一致 |
| `$CLI run $I/property-replay.bnt` | 0 | 下表の反例・仕事量・版・再現設定・メッセージを実出力で確認 | 一致 |
| `$CLI test $I/property-oldconfig.bnt`、`$I/property-oldshrink.bnt` | 各2 | maxShrinkWork欠落E0428、Listを返す旧ShrinkerはE0401 | 一致 |

旧manifest/旧記録の拒否入力は、候補のmanifest/記録を複写して上位versionを1にした補助入力である。旧記録入力のgeneratorVersionも1.0.0にした。過去の実行記録や過去版の全コードを再現したとは扱わない。記録の拒否・旧本文ハッシュ認証・新manifestでの記録移行を実ファイルで照合したものである。

| Propertyの実出力（seed=1/trials=1/size=1/maxShrinks=20） | shrinks | shrinkWork | reduced | limitReached | 判定 |
|---|---:|---:|---|---|---|
| maxShrinkWork=0 | 0 | 0 | [1, 2, 3] | true | 一致 |
| maxShrinkWork=1 | 0 | 1 | [1, 2, 3] | true | 一致 |
| maxShrinkWork=1000 | 7 | 30 | [0] | false | 一致 |

各出力のlibraryVersionは2.0.0、originalは[1, 2, 3]、originalMessage/messageはnonempty、trialは1。configの五欄・shrinks・shrinkWork・limitReached・元と縮小後の値/説明をformatFailureで確認した。再現に必要なconfigと具体的反例、手書きソース、generatorVersionと生成設定ハッシュは証拠に保存した。seedだけで異なる版を再現できるとの判定はしていない。

## 4. 英語・訳・移行案内・Skill・標準ソース・生成記録の版

`rg -n`で版と報告形式を実ファイルから抽出した。完全なコマンドと行の出力はevidence.jsonの`version strings`・`translated skill versions`にある。文書の過去版の履歴、旧例からの移行の対比、設定の版1は、それぞれの対象を区別して確認した。

| 対象・実ファイル | 収集・照合した版と内容 | 判定 |
|---|---|---|
| README.md、crates/benitoite/Cargo.toml、Cargo.lockのbenitoite | 0.0.9、ソースだけのリリース | 一致 |
| docs/reference/benitoite.md、docs/ja/reference/benitoite.md | 本文の対象版・訳の翻訳元は0.0.9。language受理/旧版E0908/未来E0907、R109の版1/2と[1,2]、Property 2.0.0、0.0.9移行案内 | 一致 |
| docs/reference/install.md、docs/ja/reference/install.md | 対象版0.0.9、ソースからのビルド、0.0.8→0.0.9の移行、Skill再インストール、生成/Propertyの一括移行。実行ファイル配布は0.1.0以後 | 一致 |
| CHANGELOG.mdの0.0.9節と、英日reference/installの移行案内 | E0457/E0458、Scope/Range、opaque、builder、doctest版2、inventory/記録/hash版2、設定版1、Property 2.0.0、generator 2.0.0-syntax-batch3、正確なmanifestハッシュ、通常check/test＋derive check | 一致 |
| 手書きcrates/benitoite/skill/SKILL.mdとdocs/ja/skill/SKILL.md | 元ファイルの版置換印は`{{benitoite-version}}`、訳は0.0.9の翻訳元と印を残す理由を明記。CLIの表示ではmetadata.benitoite-version=0.0.9。二引数クラスの汎用関数と具体Result API、版2/Property移行の案内 | 一致 |
| 手書きreferences/inspection.mdと日本語訳、ほか手書き参照の訳 | 各訳の翻訳元0.0.9。testCheckReport/testResultsは[1,2]、--docのみ版2。Propertyの仕事予算と再現情報も一致 | 一致 |
| 生成references/grammar.md、diagnostics.md、stdlib/{Scope,Range,Regex,Trait,StringBuilder,ListBuilder,BytesBuilder,Test.Property}.mdなど | 候補の生成物。opaque・各診断・Functor2/Applicative2/Monad2・構築器・ShrinkStep/Config/Counterexampleの公開APIを収録。E0506はhandle/to_resultの文言を収録し、実CLIのFailのみのhelpと対応 | 一致 |
| 標準ソースTest/Property.bnt、Trait.bntほかと生成参照 | PropertyのCounterexample.libraryVersion=2.0.0。ShrinkStep、maxShrinkWork、shrinkWorkを標準ソース・生成API・実CLI反例で照合。他の標準ソースと生成APIは再生成とbundleの全照合で確認 | 一致 |
| tools/derive/README.md、derive.py、examples/derive.json、derive.generated.json、People.bnt/Address.bnt、derive_inventory/README.md | config=1、inventory/manifest/記録/hash=2、GENERATOR_VERSION=2.0.0-syntax-batch3、Property=2.0.0、templatesはProperty=2・Show/Order=1。例はPerson Show、Address Show/Order。実生成checkと通常テストでも一致 | 一致 |
| `$CLI skill list --format=json`と全70文書の`skill show --format=json <name>` | bundleの名前集合が候補のSkill全ファイル＋二ライセンスに一致。各文書のtext/UTF-8 byteLength/SHA-256が元ファイル（版置換後）と一致し、list/show相互も一致。producerの版とcommitは候補。bundleに日本語訳なし | 一致 |
| `$REPO`で`cargo run -p benitoite --example gen_skill`、直後の`git status --short` | 両方終了0、status出力なし。生成参照とbundleに差分なし | 一致 |

## 5. 追跡対象だけの候補ディレクトリ

開始時のcleanなHEADから、Pythonのsubprocessで`git archive HEAD`を取得し、`$TMP/candidate.tar`へ保存した。Gitが作った同じtarを`tarfile.extractall`で`$A`に展開した（この環境で非対応のfilter引数は指定していない）。レビューされていない候補差分を含めていない。

| コマンド・実ファイルの照合 | 終了状態 | 見た出力の要点 | 判定 |
|---|---:|---|---|
| `git archive HEAD`とtar展開 | 0 | .gitなし、docs/todoなし。tools/derive/derive.py、例の二.bnt・設定・生成記録を含む | 一致 |
| `$A`で`cargo build --release -p benitoite --locked`（既定機能） | 0 | 外側76.982秒。アーカイブ内のCargo.lockとソースでビルド成功 | 一致 |
| `$A/target/release/benitoite --version=json` | 0 | 0.0.9、target=aarch64-apple-darwin、formats一致。commit/dirtyはnull、provenance.commit=unknown、dirty=notCollected。Git情報のないソース配布であり、候補のIDを自動採取したとは扱わない | 一致 |
| `$A`で`cargo run -p benitoite --example gen_skill` | 0 | 再生成前後の全SkillファイルのSHA-256辞書が一致 | 一致 |
| `$A`で`cargo build -p benitoite --example derive_inventory --bin benitoite` | 0 | reader/formatterもアーカイブ内のソースからビルド | 一致 |
| `$A`で`python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json`（実際は同じパスの絶対指定） | 0 | generated regions and records match。元リポジトリの生成readerを使わない | 一致 |
| tar内の全通常ファイルと生成後の展開先をPythonでバイト比較 | 0 | 7,131通常ファイルが全て一致。元ファイルを変更せずビルド・生成checkできた | 一致 |

ビルドにはこの環境のRust/Cargo・Pythonと公開依存クレートのキャッシュを用いた。秘密の参照資料、docs/todo、リポジトリの未追跡ファイルはアーカイブへ入れておらず、生成の入力にも指定していない。「追跡対象だけ」はプロジェクト入力の範囲を指し、Rustツールチェーンや公開の外部依存を同梱したという意味ではない。

## 保存例の読み替え・補助入力の修正・申し送り

| 箇所 | 初めの観察 | 読み替え・修正と再照合 | 扱い |
|---|---|---|---|
| design.md 15.1の「同じ位置のcheckHostを以下へ替える」の第4行 | checkPathへ一行だけ替えると、後続Scope.host/hostPatternがCheckedHostを要求するためE0401。静的Scope検査へ到達しない | 英語reference「Scope」のcheckPathはResult[CheckedPath, ScopeError]、日本語「Scope」も同じ。保存されたcheckPath呼び出しを独立の関数内で`bind _ <- ...`として照合し、期待のE0462になった | 依頼で許可された保存例だけの書き損じの読み替え。候補の文書は未変更。オーケストレータへこの指定の明確化を申し送る |
| 生成の差分を作るためのAddress JSONキー変更 | city→townの新生成物に、旧cityキーの手書き入力fixtureを渡したためjsonRoundtripだけ終了1。生成した値の往復テストは成功 | `$TMP/derive-examples/People.bnt`の入力fixtureのキー一箇所をtownへ対応させた。既存のassertと期待値はそのまま。二件成功、通常checkとderive check成功。別コピーの未変更候補例も二件成功 | 補助入力の整合の修正。候補のテスト・期待を変更/緩和していない |
| 四モードの補助doc例とrun用補助ファイルのConsole import | 自分で作った入力にBenitoite.IO.Consoleを指定しE0321 | 英日referenceのBenitoite.Unofficial.IO.Consoleへ直し、四モード/許可/出力を再照合 | 保存例・処理系の不一致ではない |
| Propertyの追加観察用入力 | 自分で書いたfor構文、callbackの引数名、入れ子lambdaの同名によりE0201/E0213、E0454、E0338 | 英語referenceのループなし/List.forEach、公開引数名value、別のshowList関数を用いる形へ直し、予算・反例・再現を照合 | 補助入力の書き損じ。失敗出力も証拠に残した |
| Python補助手順の準備 | 文字列の引用符の誤りでSyntaxErrorとなった呼び出しがあった | /private/tmp内の補助手順だけ修正してから実行 | 候補CLIの実行前の誤り。候補ファイルは変更していない |

記録を書いた後に`git diff --check`（終了0）で空白の不備がないこと、`git status --short`で変更がq3/results.mdとq3/evidence.jsonだけであることを確認した。

一度目のR191は候補に取り込み済みであり、今回の15.3は修正後のimportをそのまま使った。独立モジュールの連結、tarfileのfilter引数、language不正宣言の診断E0905についても一度目の申し送りに従った。保存例の読み替えは依頼の明示した範囲内であり、新しい設計判断やR番号の追加はしていない。

変更は本記録とevidence.jsonだけである。Rustのテスト、scripts/check.sh、LLMを呼ぶ評価は実行していない。処理系・テスト・標準ソース・文書・Skillの修正、タグ、push、TODOの変更、archiveへの移動、コミットも行っていない。自動release_stackの結果は改造のresults.mdにあるオーケストレータの記録を参照する。本記録はその再実行や、別の候補への回帰結果の引用を行うものではない。

## 候補と実行ファイルの識別

候補の完全ID: `92120a2f3aa6cc7c7aeb7044341fe0a23da3f921`。

実際の`$CLI --version=json`の出力（終了0）:

```json
{"build":{"commit":"92120a2f3aa6cc7c7aeb7044341fe0a23da3f921","dirty":null,"provenance":{"commit":"git","dirty":"notCollected"},"target":"aarch64-apple-darwin"},"formats":{"checkReport":[1],"diagnostics":[1],"effectLimit":[1],"loaderEnvironment":[1],"skillDocument":[1],"skillList":[1],"testCheckReport":[1,2],"testResults":[1,2],"version":[1]},"kind":"version","loaderEnvironment":{"deniedPrefixes":["DYLD_","LD_"],"errorKind":"InvalidInput","inherited":"unchanged","mode":"always","nameComparison":"asciiCaseInsensitive","schemaVersion":1},"name":"benitoite","schemaVersion":1,"unicodeVersion":"17.0.0","version":"0.0.9"}
```

| 対象 | 値 |
|---|---|
| 実行ファイル | `/Users/tecogonaz/src/Benitoite/target/release/benitoite` |
| SHA-256（実ファイルのPython hashlib.sha256） | `73d27df6af206b0696997e5ec6a3fc18584f0244e6d86225d227a7059a8ac8fb` |
| 大きさ（statのst_size） | 31,115,376 bytes |
