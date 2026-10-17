# Benitoite 0.0.7 向けの連携インターフェースの回答

2026-10-17。BH-022〜BH-027 の六機能は **0.0.7 向けに実装し、公開前の全体検査を完了しました**。**0.0.7 は未公開・タグなしです。** 実装の最終確認の基準はコミット `265505bbd2f80381a697f39192b3168165ce1a20` です。下記の出力例はコミット `b2b7fe383b192efadc77d8bf3556e84f2ba413b2` からの作業ツリーで採取した値を保持し、最終確認のコミットへ数字だけを置き換えてはいません。最終実装も、以下の引数・形式・診断・終了状態の契約を保っています。公開後に、実際のタグをお知らせします。

出力例は、採取時点の文書と同梱 Skill の修正を含む作業ツリーをビルドして実行した結果です。ビルド情報の commit は下記の採取規則に従う値です。JSON は読みやすく整形しています。現在の実行ファイルが返す `version` と `producer.version` は `0.0.7` であり、例もこの実出力に揃えています。dirty は明示せず、実出力の null・notCollected を保っています。実装の版を更新した状態であり、タグの作成や公開を示すものではありません。Skill 本文中の版・本文の長さとハッシュ、標準ソースのハッシュも、提供する版の実際の出力を使ってください。抜粋と明記した例では、示した欄・値だけを取り出しています。

（公開時の追記）この回答の後、0.0.7 を軽量タグ `v0.0.7` として公開しました。冒頭の「未公開・タグなし」は回答の時点の状態です。

配列の順序は各節の規定に従います。保証の範囲と JSON の欄の順序の扱いは、末尾の「保証の限界」にまとめています。

## BH-025: 版・ビルド・対応する形式の問い合わせ

`benitoite --version=json` を追加します。最初の引数にだけ指定でき、後ろに余分な引数を付けると使い方の誤りです。標準出力へ単一の UTF-8 JSON と末尾改行を出します。従来の `benitoite --version` の二行は保ちます。

```json
{
  "build": {"commit":"b2b7fe383b192efadc77d8bf3556e84f2ba413b2","dirty":null,"provenance":{"commit":"git","dirty":"notCollected"},"target":"aarch64-apple-darwin"},
  "formats": {"checkReport":[1],"diagnostics":[1],"effectLimit":[1],"loaderEnvironment":[1],"skillDocument":[1],"skillList":[1],"testCheckReport":[1],"testResults":[1],"version":[1]},
  "kind": "version",
  "loaderEnvironment": {"deniedPrefixes":["DYLD_","LD_"],"errorKind":"InvalidInput","inherited":"unchanged","mode":"always","nameComparison":"asciiCaseInsensitive","schemaVersion":1},
  "name": "benitoite",
  "schemaVersion": 1,
  "unicodeVersion": "17.0.0",
  "version": "0.0.7"
}
```

この問い合わせは終了状態0、標準エラー出力は空でした。Unicode と target はこのビルドの実測値です。build.commit は完全なコミット ID の文字列または null、dirty は boolean または null です。null は「不明」であり、「変更なし」ではありません。provenance.commit は environment/git/unknown、provenance.dirty は environment/notCollected を返します。dirty は自動採取せず、未指定の null を notCollected で示します。ビルド時に明示的に不明を指定した場合は、値が null、由来が environment になります。

Git が利用できるソースのビルドでは、commit だけを自動採取します。dirty は自動採取せず、明示値がなければ null です。ソースのアーカイブや Git がない環境では commit も null です。管理場所や ref のパスを解決できない場合、HEAD の監視を登録できない場合、symbolic HEAD の ref と packed-refs のどちらの監視も登録できない場合も、commit は null、由来は unknown です。共通の管理場所に reftable がある場合も、Git から採取せず同じ扱いとします。ビルド時の `BENITOITE_BUILD_COMMIT` と `BENITOITE_BUILD_DIRTY` で明示できます。実行時の同名環境変数では値を変えません。ビルド情報の保証の範囲は末尾に示します。

ビルド情報の再採取は、ビルドスクリプト自体、Git の HEAD・参照中のブランチの ref・packed-refs・HEAD の reflog（logs/HEAD）のファイル、明示入力の変化で行います。管理場所は Git から求め、HEAD と logs/HEAD は --git-dir の側を使います。作業ツリーの編集だけでは採取を起こしません。存在しない監視パスは登録しないため、HEAD の reflog がない状態で packed ref から loose ref が新設される場合、commit のないブランチに最初のコミットを作る場合、Git の導入やアーカイブへの Git 管理の追加など、登録済みのファイルが変わらない変更は検知できません。その場合は明示入力の変更か clean build が必要です。

使える機能は、version の数の大小で判断せず、`formats.<名前>` にハーネスが理解する整数が含まれるかで判定してください。未実装の機能のキーは出しません。例えば、checkReport に 1 があれば下記の main の報告を、testCheckReport に 1 があればテストの報告を使えます。effectLimit は実行前の照合の引数・診断の契約、loaderEnvironment は後述のローダ変数の拒否のポリシーの契約です。

既存の diagnostics と testResults の形式 1 は、0.0.6 の `kind: "die"`・`code: null` とテストの failure.die を含む形です。既存の一行へ schemaVersion を追加せず、開始の版情報の行も加えません。版問い合わせで対応する形式を示します。`--version=json` がない旧版について、処理系が形式を自己申告したとは扱わないでください。

問い合わせの終了状態は成功0、使い方の誤り2、処理系の不具合3、出力の書き込み失敗1です。新しい診断コードは設けません。失敗の説明は標準エラー出力へ書き、成功の空オブジェクトを返しません。

依頼からの選択は、コミットと dirty を独立した不明値にできる形と、既存の JSON Lines を変えず問い合わせから形式を得る形です。了承済みの案から変えた点は、dirty を自動では採取しないことです。自動採取すると作業ツリーの変更のたびに処理系が作り直されるためです。普通のビルドでは dirty は null、由来は notCollected になります。

## BH-022・BH-023 に共通する報告の読み方

報告は JSON Lines ではなく、標準出力の単一 JSON です。明示した `--report=json` のときだけ出します。診断も同じオブジェクトへ入れ、同じ診断を標準エラー出力に重ねません。report を指定しない run/check の標準出力や既存の診断の形式は保ちます。

| 欄 | 型・意味 |
|---|---|
| schemaVersion | integer。初版は1 |
| kind | checkReport または testCheckReport |
| producer | name、version、build。上記の問い合わせと同じ値 |
| status | ok / checkError / usageError / internalError。test には interrupted もあります |
| complete | boolean。対象の選択と全検査・情報の確定が成功した場合だけ true |
| targetsComplete | boolean。入口の選択またはテストの探索を最後まで終えたか。検査成功とは別です |
| executed | false 固定。利用者の関数を実行していません |
| requestedTargets | requestIndex と表示用 path の配列。0始まりの番号と指定順を保ちます |
| targets | 入口ごとの結果。targetId、requestIndex、entry、root、sourceId、kind、status、complete と関数の情報 |
| sources | sourceId、displayPath、kind（user/prelude）、contentHash の配列 |
| sourceSets | targetId と、その検査で読んだ sourceIds の配列 |
| aggregateEffects | 宣言した上限の和のオブジェクト。全体が不完全なら null |
| diagnostics | 既存と同じ欄を持つ診断の配列。報告内の usageError にだけ kind:check・code:null の組み合わせを認め、primary:null もあり得ます |
| diagnosticTargets | diagnosticIndex と targetId の対応。全体の誤りでは targetId:null |

エフェクトは `{"basis":"declaredUpperBound","expanded":["Console.Write"]}` の形です。expanded は重複なし、正規名の辞書順です。IO.All は十個に開きます。最小限のエフェクトの推論結果ではなく、検査に成功した関数が宣言する上限です。使わないエフェクトを宣言に残せば報告にも残ります。

IO.All の十個は Clock.Time、Console.Read、Console.Write、File.Read、File.Write、Process.Environment、Process.Exit、Process.Run、Random.Generate、State です。Http.Connect・Http.Listen・Assert.Check は IO.All に含まれません。

Target の共通欄は targetId・entry・root（文字列）、requestIndex（0始まりの整数）、sourceId（文字列または null）、kind（main/tests）、status（ok/checkError/internalError/interrupted）、complete（boolean）です。root は、ファイルの直接指定ではその親ディレクトリ、ディレクトリ経由では指定したディレクトリです。main の Target は main、tests の Target は tests と processShellReference・shellReferenceScope を持ちます。main は symbol・location・effects・processShellReference・shellReferenceScope、個々のテストは function・description・location・effects を持ちます。これらの形は後の実出力例にも示します。

targets は指定順と各ディレクトリ内の辞書順、tests は宣言順です。sources は Target 順、その中では検査で割り当てたソース番号の順です。sourceSets は Target ごとに一件あり、sourceIds も同じソース番号順です。失敗・未着手の Target にも対応を残し、ソースを保持していなければ空配列にします。diagnostics は入口順、その中は既存の検査段・位置順で、探索・使い方の誤りを先に置きます。diagnosticTargets は各診断に一件ずつ対応します。

内容のハッシュは `{"algorithm":"sha256","value":"64桁の小文字の十六進数"}` の形です。検査で読んだ元のバイト列全体から取り、BOMや改行を正規化しません。入口、依存、package.bnt、埋め込みの標準ソースも含みます。Wasm バイナリ、パッケージのハッシュ検証だけの読み取り、存在しなかったファイル、ディレクトリの観測は一覧に含めません。

位置は既存の診断・テストの位置と同じ形です。file は表示名、start/end は line・column・offset を持ちます。行・列は1始まり、offset は元のソース内の0始まりのバイト位置です。label は関数の報告では空文字列です。表示用パスは、親が追加のファイルを開く指示として扱わないでください。

純粋な成功は expanded:[]、不明な集合は effects または aggregateEffects 自体が null です。検査が失敗して関数一覧を確定できなければ main/tests も null です。有効なテストなしのファイルは tests:[]、空ディレクトリも成功した空の結果です。説明の省略は description:null、明示した空の説明は description:"" です。

sourceId と targetId は一つの報告内だけの識別子です。同じパスを二回指定しても別の targetId を返し、別々の検査のソースをまとめません。別の check/run の同じ ID を、同じ内容の証明には使えません。

確定した集合として使えるのは、**構文が完全な一個の JSON、既知の schemaVersion と kind、status:ok、complete:true、終了状態0**をすべて満たす結果です。不完全な JSON、未知の状態・形式・エフェクト、null、非0終了を空集合へ読み替えないでください。欄の削除、型・必須性・意味の変更、成功の判定に新しい解釈が要る分類の追加では該当形式の版を上げます。無視しても意味が変わらない任意欄の追加は同じ版でよいため、未知の任意欄は無視して構いません。

## BH-022: main の非実行の検査

次の形で使えます。

```text
benitoite check --report=json <script>
benitoite check --diagnostics=json --deny-warnings --report=json <script>
```

script は既存どおりファイル、または main.bnt のあるディレクトリです。report は `--report=json` だけを受けます。`--diagnostics=json` の併記は構いませんが、明示した `--diagnostics=text` は使い方の誤りです。オプションは script より前に置いてください。

次の内容を UTF-8・LF・末尾改行ありの `main.bnt` に保存し、`benitoite check --report=json main.bnt` を実行しました。終了状態0、標準エラー出力は空で、関数内の文字列も出力されません。

```bnt
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Process
function main() -> Unit uses Console.Write, Process.Exit
  Console.writeLine("must not execute")
  bind value: Unit <- try Option.None or die("must not execute")
end function
```

次は実出力から `sources` と `sourceSets` だけを省いた抜粋です。この二欄も実際には必須であり、省略されません。

```json
{
  "aggregateEffects": {"basis":"declaredUpperBound","expanded":["Console.Write","Process.Exit"]},
  "complete": true,
  "diagnosticTargets": [],
  "diagnostics": [],
  "executed": false,
  "kind": "checkReport",
  "producer": {"build":{"commit":"b2b7fe383b192efadc77d8bf3556e84f2ba413b2","dirty":null,"provenance":{"commit":"git","dirty":"notCollected"},"target":"aarch64-apple-darwin"},"name":"benitoite","version":"0.0.7"},
  "requestedTargets": [{"path":"main.bnt","requestIndex":0}],
  "schemaVersion": 1,
  "status": "ok",
  "targets": [{"complete":true,"entry":"main.bnt","kind":"main","main":{"effects":{"basis":"declaredUpperBound","expanded":["Console.Write","Process.Exit"]},"location":{"end":{"column":14,"line":3,"offset":91},"file":"main.bnt","label":"","start":{"column":10,"line":3,"offset":87}},"processShellReference":"absent","shellReferenceScope":"checkedProgram","symbol":"main"},"requestIndex":0,"root":".","sourceId":"t0:s0","status":"ok","targetId":"t0"}],
  "targetsComplete": true
}
```

実出力の `sources` は44件でした。うち `main.bnt` の一件は次のとおりです。このハッシュは上の入力の全バイト列と一致します。残り43件の標準ソースも実出力に含まれ、`sourceSets` は44件すべての ID を対応させます。

```json
{
  "contentHash": {"algorithm":"sha256","value":"3188326b991dc2cca09fffbd94f7d217e452e075a4998f459d0c46808627768b"},
  "displayPath": "main.bnt",
  "kind": "user",
  "sourceId": "t0:s0"
}
```

`or die` の Process.Exit は通常の型検査と同じ規則で含めます。完全なハンドラで処理し、関数の契約からも外せば含まれません。uses に残せば含まれます。or return と裸の try だけで Process.Exit を加えることはありません。

shell の参照は present/absent/unknown の三状態として扱い、shellReferenceScope は checkedProgram です。名前解決した標準 Process.shell の式の参照を、入口と依存を含む検査したプログラム全体で探します。到達しない関数も含め、ハンドラ case の操作名だけは数えません。IO.Process が読み込まれていなければ absent です。読み込まれているのに標準 shell の束縛が欠ければ内部エラーとします。checkReport では検査失敗を `main: null` で表し、shell の参照も未確定とします。`unknown` は testCheckReport の Target で返します。到達性についての限界は末尾に示します。

終了状態は成功0、検査・読み取り・使い方の誤り2、処理系の不具合3、報告の書き込み失敗1です。main なしは E0414、読み取り失敗は E0101 など既存のコードを使います。報告専用の新しい E コードはありません。checkReport の標準ソース内の誤りでは、通常の check と同じく内部エラーの診断一件だけを返します。処理系のオプションの範囲を最後まで走査して report モードを決めるため、途中の使い方の誤りも status:usageError の報告へ包みます。`check --diagnostics=text --report=json <script>` と逆順、`check --bogus --report=json <script>` はすべて checkReport の usageError です。script より後の同名引数や、既知のオプションの分離値はモードの指定にしません。分離値の消費はコマンドの語を選ぶ走査にも適用します。オプションの境界自体を確定できない入力、初期化失敗、外側の panic、強制終了などは完成した報告の保証外です。

usageError の診断は kind:check・code:null・必要なら primary:null です。この組み合わせは新しい checkReport/testCheckReport の diagnostics 内だけの契約であり、既存の診断形式1の JSON Lines へは追加しません。処理系側の診断の仕様も、報告内だけの例外として定めています。既存形式の版は上げず、新しい報告の初版1でこの例外を定めます。

例えば `benitoite check --report=json`（パスなし）は終了状態2、標準エラー出力は空で、次の完全な報告を返します。

```json
{
  "aggregateEffects": null,
  "complete": false,
  "diagnosticTargets": [{"diagnosticIndex":0,"targetId":null}],
  "diagnostics": [{"code":null,"helps":[],"kind":"check","message":"missing script path","notes":[],"primary":null,"secondary":[],"severity":"error"}],
  "executed": false,
  "kind": "checkReport",
  "producer": {"build":{"commit":"b2b7fe383b192efadc77d8bf3556e84f2ba413b2","dirty":null,"provenance":{"commit":"git","dirty":"notCollected"},"target":"aarch64-apple-darwin"},"name":"benitoite","version":"0.0.7"},
  "requestedTargets": [],
  "schemaVersion": 1,
  "sourceSets": [],
  "sources": [],
  "status": "usageError",
  "targets": [],
  "targetsComplete": false
}
```

main の報告では、報告モードの確定後、入口の選択から検査・抽出・JSON の直列化までに捕捉した不具合を internalError・complete:false・終了状態3の単一報告へ収めます。main と aggregateEffects は null です。選択済みの入口は残しますが、検査段の巻き戻しで持ち出せなかったソースは再読せず、sources と該当の sourceIds は空配列、sourceId は null になり得ます。targetsComplete は入口の選択の完了だけを示します。書き込みか flush に失敗したら終了状態1とし、二つ目の報告は送りません。失敗報告自身の組立が失敗した場合も、完成した報告の保証外です。

依頼からの選択は、宣言した上限を報告し、shell の参照をプログラム単位で示すことです。

## BH-023: テストを実行しない検査

```text
benitoite test --check --report=json <path>...
```

`test` と同じ処理で対象を選びます。ファイルとディレクトリ、下位の package.bnt を持つパッケージの除外、直接指定とディレクトリ経由の根の違い、明示パスの重複を保ちます。ハーネス側で重複を取り除いて渡して構いません。main は要求せず、入口のトップレベルの @test だけを宣言順で報告します。

次の `tests/math.bnt` を `benitoite test --check --report=json tests/math.bnt` で検査しました。終了状態0、標準エラー出力は空です。

```bnt
@test
function sum() -> Unit uses Assert.Check
  Assert.equal(actual: 1 + 1, expected: 2)
end function
```

次は実出力から `sources` と `sourceSets` だけを省いた抜粋です。実出力には入口と標準ソースの計41件、およびその全 ID の対応が含まれます。

```json
{
  "aggregateEffects": {"basis":"declaredUpperBound","expanded":["Assert.Check"]},
  "complete": true,
  "diagnosticTargets": [],
  "diagnostics": [],
  "executed": false,
  "kind": "testCheckReport",
  "producer": {"build":{"commit":"b2b7fe383b192efadc77d8bf3556e84f2ba413b2","dirty":null,"provenance":{"commit":"git","dirty":"notCollected"},"target":"aarch64-apple-darwin"},"name":"benitoite","version":"0.0.7"},
  "requestedTargets": [{"path":"tests/math.bnt","requestIndex":0}],
  "schemaVersion": 1,
  "status": "ok",
  "targets": [{"complete":true,"entry":"tests/math.bnt","kind":"tests","processShellReference":"absent","requestIndex":0,"root":"tests","shellReferenceScope":"checkedProgram","sourceId":"t0:s0","status":"ok","targetId":"t0","tests":[{"description":null,"effects":{"basis":"declaredUpperBound","expanded":["Assert.Check"]},"function":"sum","location":{"end":{"column":13,"line":2,"offset":18},"file":"tests/math.bnt","label":"","start":{"column":10,"line":2,"offset":15}}}]}],
  "targetsComplete": true
}
```

Assert.Check は個々の報告・aggregateEffects・後述の上限との比較のすべてに含めます。確認の画面で省く場合も、処理系へ戻す許す集合から落とさないでください。

一つのファイルに検査の誤りがあっても他のファイルの結果を集めます。失敗した入口は status:checkError・complete:false・tests:null、成功した入口の結果は残ります。ただし全体は complete:false、aggregateEffects:null です。探索が終わっていれば targetsComplete:true のままですが、これだけで全体の検査成功とは判断できません。不具合・中断で検査していない入口も不完全として残します。探索に失敗した場合は、先に選び終えた入口だけを参考に残し、どの入口も検査しません。全体と保持した Target は checkError・complete:false、targetsComplete は false、tests は null、processShellReference は unknown、sourceIds は空配列です。探索全体の E0101 の diagnosticTargets は targetId:null です。

テストや利用者の補助関数を一切実行せず、利用者コードによる出力やファイルの変更を起こしません。外部の関数の照合までの報告であり、脱糖・コンパイルの制限がないことまでは保証しません。通常の test で後のコード生成に失敗する可能性は残ります。

`test --check` だけなら、非実行の検査をして既存形式の診断だけを返し、成功時も標準出力は空です。警告があれば標準エラー出力へ出します。`test --report=json <path>` は --check がなくても testCheckReport の usageError・終了状態2を返し、テストを実行しません。test の既存のオプション範囲を最後まで走査するため、diagnostics=text や未知オプションと report の前後関係で報告モードは変わりません。--check では --deny-warnings と診断の指定を受け、--max-call-stack・--wasm-*・--allow-effects は受けません。どちらの非実行モードも kind:test/testSummary を出しません。実行する test の集計の読み方は次節のとおりです。

終了状態は成功0、検査・入力・使い方の誤り2、不具合3、捕捉した中断130、報告の書き込み失敗1です。中断の要求はファイルを始める前の既存の確認点で読みます。ファイルの後や報告直前には読まないため、最後のファイルの検査中の要求が報告へ反映されない場合があります。複数の原因では中断、不具合、使い方、検査の誤りの順で優先します。ただし、報告の書き込みの失敗による終了状態1は、報告の status の値より優先します。E0806 など既存の診断を用い、新しい E コードは設けません。能力判定は formats.testCheckReport の1です。

依頼からの選択は、実行結果の JSON Lines と異なる kind の単一 JSON とすることと、検査の成功を実行可能の保証へ広げないことです。

## BH-027: run/test の実行前に許す集合を照合

```text
benitoite run --diagnostics=json --allow-effects=Console.Write,File.Read <script> [args...]
benitoite test --diagnostics=json --allow-effects=Assert.Check,File.Read <path>...
benitoite run --allow-effects= <pure-script>
```

`--allow-effects=<値>` と `--allow-effects <値>` を一回だけ受けます。run は script より前、test はパスの前後どちらでも構いません。サブコマンド省略の run にも使えます。指定しなければ上限を掛けません。

0.0.7 で提供します。能力は `formats.effectLimit` に1が含まれることで判定できます。上限付き test は全入口の準備が成功するまで実行を始めず、拒否時は全入口数を filesNotRun に入れます。check・test --check・fmt は上限を受け付けません。集計の共通文言は `; {count} files not run` とします。分離値はコマンド名を選ぶときも一引数として消費し、値の字面をパスや報告の指定と解釈しません。例えば `check --allow-effects --report=json main.bnt` は allow-effects を受け付けない文章による使い方の誤りになり、`check --allow-effects State --report=json main.bnt` は checkReport の usageError になります。run のスクリプト以後の同名引数はスクリプトに渡します。

値は報告の expanded と同じ原子的な正規名のカンマ区切りで、空文字列は空集合です。順序は自由ですが、重複名、空要素、空白、未知名、IO.All、import の別名、利用者定義名、`*` は使い方の誤りです。許す名前は State、Console.Read/Write、File.Read/Write、Process.Run/Exit/Environment、Clock.Time、Random.Generate、Http.Connect/Listen、Assert.Check です。

実際に検査した main または @test の宣言した上限が、渡された集合に含まれるかを比較します。余分な許可は拒否せず、不足した場合は E0512・終了状態2で開始を断ります。--diagnostics=json なら標準エラー出力へ既存の診断形式1で出します。許可判定の専用 JSON を標準出力へ出す機能は設けません。formats.effectLimit の1でこの契約を判定できます。

上記の `main.bnt` を `benitoite run --diagnostics=json --allow-effects=Console.Write main.bnt` で実行しようとすると、Process.Exit が不足するため終了状態2、標準出力は空になります。次は標準エラー出力の一行を整形したものです。

```json
{
  "kind": "check",
  "severity": "error",
  "code": "E0512",
  "message": "effects of `main` exceed `--allow-effects`",
  "primary": {"file":"main.bnt","start":{"line":3,"column":10,"offset":87},"end":{"line":3,"column":14,"offset":91},"label":"effect limit checked for this function"},
  "secondary": [],
  "notes": ["effects not allowed: Process.Exit","allowed effects: Console.Write"],
  "helps": [{"message":"review the required effects before changing --allow-effects","edits":[]}]
}
```

主位置は関数の名前です。不足した名前と許す集合を notes に入れます。notes は人が読むための文言であり、その形は安定した契約に含めません。不足した名前は、ハーネスが報告の expanded と許す集合の差から求めてください。code:E0512 と状態2で検査の拒否を判定できます。ほかの検査失敗を E0512 に読み替えず、元の診断を返します。

上限付き test は、全対象の検査・比較・コンパイルが成功するまで一つ目のテストを始めません。検査失敗やコード生成の制限でも全体を開始しません。比較したコンパイル済み成果物を保持し、その同じ成果物を実行します。許可判定後のファイルの再読はしません。上限なしの test は従来の、誤りのあるファイルだけ飛ばして続ける動作を保ちます。

全体を拒否して一つも開始せず、N>0個の入口が確定している場合は、test の出力は kind:test を含まず、次の既存形式の集計だけとなります。例は上記の `tests/math.bnt` と、テストのない有効な `no-main.bnt` を `benitoite test --diagnostics=json --allow-effects= tests/math.bnt no-main.bnt` へ渡した実出力です。Assert.Check の不足を理由に全体を拒否します。filesNotRun は全体の拒否により開始しなかった全入口数であり、その入口自体に誤りがなくても数えます。テストのない入口と明示パスの重複も数えます。文章の集計は `; {count} files not run` とし、通常 test もこの文言に揃えます。JSON の件数と形式は保ちます。

```json
{
  "kind": "testSummary",
  "passed": 0,
  "failed": 0,
  "filesNotRun": 2,
  "interrupted": false
}
```

終了状態は2、診断は標準エラー出力です。passed/failed がともに0でも成功ではありません。探索失敗や引数の誤りなどで対象数が分からない場合は集計行も出しません。中断なら130、不具合なら3を優先し、既知の対象で集計を書ける場合は未実行数と interrupted を反映します。0/0 を成功とみなせるのは、集計行があり、終了状態0・filesNotRun:0・interrupted:false を満たす場合だけです。テストのない有効なファイルや空ディレクトリがこれに当たります。集計行の欄と型は形式1のままです。件数が u32 に収まらない場合は内部エラーとなり、飽和させた件数は返しません。実行開始後も、捕捉した中断130・不具合3・検査拒否2・テスト失敗1・成功0の優先順位を保ちます。

依頼から外した機能はありません。上限付き test は入口数に応じて保持する成果物と開始前の時間が増えます。入力の固定と隔離に関する限界は末尾にまとめます。

## BH-026: Command.environment のローダ変数

CLI の指定によらず、すべての実行で適用します。Command.environment に明示した名前が DYLD_ または LD_ で始まる場合、ASCII の大文字小文字を区別せず、子を起動する前に拒否します。run と runAttached の両方が対象です。

0.0.7 で提供します。能力は `formats.loaderEnvironment` に1が含まれることと、版情報の `loaderEnvironment` のポリシー欄で判定できます。loaderEnvironment のポリシー欄の値と意味は次のとおりです。

| 欄 | 値と意味 |
|---|---|
| schemaVersion | 整数1 |
| mode | always。CLI の指定によらず、すべての実行に適用 |
| deniedPrefixes | ["DYLD_", "LD_"]。Command.environment に明示した変数名の禁止接頭辞 |
| nameComparison | asciiCaseInsensitive。ASCII の大文字小文字を区別しない |
| inherited | unchanged。親から継承した変数は変更・除去しない |
| errorKind | InvalidInput。言語の Result.Error(IOError) として返す失敗の種類 |

Result.Error の IOError として IOErrorKind.InvalidInput を返します。メッセージには拒否した変数名を入れ、値を入れません。文言は次の形です。

```text
environment variable `LD_RUN_PATH` cannot be set in Command.environment: names starting with DYLD_ or LD_ are not accepted
```

複数あれば元の名前の辞書順で最初の一件を示します。通常の NUL や不正な名前の検査に先に失敗した場合は、その既存の不正入力の失敗を返します。新しい E コードや専用の終了状態は設けず、言語の値として処理できます。or die で伝える場合は既存の kind:die・code:null・終了状態1になります。

この文言は `Process.run` の失敗を処理して `IOError.kind(error) = IOErrorKind.InvalidInput` を確認し、`IOError.message(error)` を表示した実出力です。子に `printf started > marker` を渡しましたが、marker は作られませんでした。呼び出し側で失敗を処理したため、この確認用スクリプトの終了状態は0です。

明示した空値や同じ値の上書きも拒否します。LD_PRELOAD など特定の一覧だけに限らず、**ビルドの道具が読む LD_RUN_PATH も含む LD_ 全体**を拒否します。これは互換性の変更として CHANGELOG と E0908 の移行案内に記載します。

依頼からの選択は、オプション化せず無条件の規則とすること、個別一覧より広い二接頭辞にすることです。環境の継承と外部コマンドに関する限界は末尾に示します。

## BH-024: 同梱の Skill の一覧・取得

`skill list` と `skill show <論理名>`、`--format=text|json`、置換後の本文の長さとハッシュを 0.0.7 で提供します。能力は `formats.skillList` と `formats.skillDocument` のそれぞれに1が含まれることで判定できます。

```text
benitoite skill list
benitoite skill list --format=json
benitoite skill show SKILL.md
benitoite skill show --format=json references/stdlib/IO.File.md
```

format は --format=text|json の形だけを受け、省略時は text です。show の名前と format の順序は自由です。install/uninstall 用の --user/--project/--agent は受けません。一覧は埋め込みの全項目を論理名の辞書順で返し、SKILL.md、手書き・生成された references、LICENSE-MIT なども含みます。

text の list は名前を一行ずつ、text の show は本文だけを出します。show の末尾に改行を足しません。SKILL.md の `{{benitoite-version}}` は実行した処理系の版に置き換え、install と同じ本文を返します。HOME やインストール先を参照せず、ファイルを書きません。

JSON の list は schemaVersion:1・kind:skillList・producer・documents、show は schemaVersion:1・kind:skillDocument・producer・name・byteLength・contentHash・text を持ちます。documents の各項目は name・byteLength・contentHash です。byteLength は置換後の UTF-8 本文のバイト数、contentHash は同じ本文の SHA-256 です。

`benitoite skill list --format=json` は終了状態0、標準エラー出力は空でした。次は実出力から、documents の LICENSE-MIT の一件を取り出した抜粋です。実際の一覧は全62件を返します。

```json
{
  "documents": [{"byteLength":1093,"contentHash":{"algorithm":"sha256","value":"210f96e8b67c1949d65d644ee088e26e619ff4c83c2aaf67e598670b15cfee25"},"name":"LICENSE-MIT"}],
  "kind": "skillList",
  "producer": {"build":{"commit":"b2b7fe383b192efadc77d8bf3556e84f2ba413b2","dirty":null,"provenance":{"commit":"git","dirty":"notCollected"},"target":"aarch64-apple-darwin"},"name":"benitoite","version":"0.0.7"},
  "schemaVersion": 1
}
```

`benitoite skill show --format=json LICENSE-MIT` は次の完全な出力を返しました。終了状態0、標準エラー出力は空です。text の UTF-8 バイト数と SHA-256 は list と一致し、`benitoite skill show LICENSE-MIT` の出力も同じ本文でした。

```json
{
  "byteLength": 1093,
  "contentHash": {"algorithm":"sha256","value":"210f96e8b67c1949d65d644ee088e26e619ff4c83c2aaf67e598670b15cfee25"},
  "kind": "skillDocument",
  "name": "LICENSE-MIT",
  "producer": {"build":{"commit":"b2b7fe383b192efadc77d8bf3556e84f2ba413b2","dirty":null,"provenance":{"commit":"git","dirty":"notCollected"},"target":"aarch64-apple-darwin"},"name":"benitoite","version":"0.0.7"},
  "schemaVersion": 1,
  "text": "MIT License\n\nCopyright (c) 2026 tecogonaz and Benitoite contributors\n\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof this software and associated documentation files (the \"Software\"), to deal\nin the Software without restriction, including without limitation the rights\nto use, copy, modify, merge, publish, distribute, sublicense, and/or sell\ncopies of the Software, and to permit persons to whom the Software is\nfurnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all\ncopies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\nIMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\nFITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\nAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\nLIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\nOUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\nSOFTWARE.\n"
}
```

名前は埋め込みの相対名と完全一致し、大文字小文字を区別します。拡張子を省く別名は設けません。絶対名、空成分、`.`、`..`、バックスラッシュ、コロンを受けず、名前をファイルシステムのパスとして開きません。list と show が返す名前は、すべて同じ規則を満たし、`..` の成分や絶対パスを含みません。満たさない埋め込みがあれば一覧を返さず、終了状態3とします。不正・未知の名前、重複オプション、余分な引数は状態2です。JSON 指定時も失敗の stdout は空であり、成功の空文書にはしません。

成功0、使い方の誤り2、埋め込みの不整合などの不具合3、出力の書き込み失敗1です。新しい E コードはありません。能力は formats.skillList と formats.skillDocument のそれぞれの1で判定できます。依頼から外した機能はありません。圧縮・全体アーカイブは追加しません。

## 保証の限界

- エフェクトは宣言した上限です。ソースのハッシュと `--allow-effects` は、後の実行の中身を固定しません。同じ File.Write のまま書く先や内容が変わる場合、同じ Process.Run のまま起動先や shell の参照が変わる場合は拒否しません。ハーネスの検査後に入力が変わっても、実行時に改めて検査した契約が許す集合に収まれば実行できます。ハッシュ照合で入力を固定するオプションはありません。複数入口の準備中に依存が変われば、各成果物は異なる時点の内容になり得ます。全対象の同時点のスナップショットは保証しません。
- ローダ変数の拒否は Command.environment に明示した設定だけに適用します。親から引き継いだ環境変数は変更も除去もせず、shell も継承を続けます。処理系を起動する前の環境の構築、PATH、コマンド固有の設定、孫プロセスはこの制約の対象外です。Process.Run を許すと、env コマンドやシェル経由でローダ変数を設定することもできます。Windows でも同じ入力規則ですが、Windows の DLL 探索全体を制御する保証はありません。
- shell の参照は検査したプログラム全体で調べ、main やテストからの到達性は解析しません。present は呼び出しの実行を保証せず、absent も別のコマンド経由でシェルや別の処理系を起動できないことを保証しません。
- JSON オブジェクトの欄の順序と空白は契約に含めません。ハーネスは JSON を解析して欄と値を読み、文字列全体では比較しないでください。配列の順序は本文の規定に従います。
- 上限を指定した test は、全対象のコンパイル済みプログラム・ソース・テスト一覧などを、全体の準備が終わるまで保持します。入口数に応じてメモリ使用量と開始前の時間が増えます。上限を指定しない通常の test は従来どおりファイルごとに準備・実行します。
- ビルド情報は実行ファイルの自己申告です。同一バイナリ、ソース全体の同一性、信頼性、各起動時の作業ツリーの状態の証明には使えません。dirty が null なら変更の有無は不明です。監視していない Git 管理ファイルだけが変わった場合、由来が git のまま古い commit を返すことがあります。

これらの機能は静的な契約の照合と入力の制約です。実行時の権限制御、外部コマンドとその子孫、許した操作の対象の制限は OS のサンドボックスなどに委ねます。

## 0.0.7 への移行と提供時の連絡

ローダ変数の無条件拒否を互換性の変更として登録するため、`language "0.0.6"` を明示した入力は0.0.7で E0908 になります。スクリプトの設定を見直して `language "0.0.7"` へ更新してください。依存の `language` を上げると内容が変わるため、ハッシュを記録した依存は、すべての依存の内容を確定した後に `benitoite package update` で記録し直してください。純粋なスクリプトでも旧い宣言は同じ扱いです。宣言なしのファイルへ新しく宣言を必須にはしません。将来の版を要求する宣言は既存の E0907 で拒否します。破壊的変更と E0908 の移行手順は、リポジトリの `CHANGELOG.md` の0.0.7の節と `docs/reference/benitoite.md` の「20. Compatibility」にも記載しています。

この回答の時点の0.0.7の実装では、構文・型の規則・脱糖、main の uses が組み込みエフェクトだけである制約、組み込みのエフェクトを宣言するモジュールの別名禁止は変えません。通常の終了状態0・1・2・3・130、Process.exit の指定値、die の診断も保ちます。

公開前の検査は、上記の最終確認のコミットで実施しました。`scripts/check.sh --full` は終了状態0、68分で成功しました。format、両構成の lint、mark-sweep のテスト、gc-stress、既定構成の lib、長いテスト、release のスタックの検査、ライセンス、仕様・リファレンスの例、生成した Skill、仕様の網羅性、道具の自己検査を含みます。既定構成の `cargo test --workspace --all-targets` は2631 passed・0 failed・49 ignored、mark-sweep/heap-verify 構成は2645 passed・0 failed・49 ignoredで、全体で87分でした。LLM を呼ぶ Skill の評価は了承を得ていないため実施しておらず、手順を変更した効果を評価するかは設計者の判断に委ねています。

提供時には、実際のタグと、この回答から引数・形式・診断に変更があればその内容をお伝えします。今回の回答の受領を、リリース済みという意味では扱わないでください。ハーネスを組み込んだ試験は処理系の完了条件に含めず、ハーネス側の接続確認は提供後に行う分担です。
